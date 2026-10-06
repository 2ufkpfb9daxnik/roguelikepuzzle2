class_name UnitBase
extends CharacterBody3D

# ==============================
# 共通ステート
# ==============================
enum UnitState {
	IDLE,
	MOVE,
	DETECT,
	CHASE,
	BATTLE_IDLE,
	BATTLE_MOVE,
	ATTACK_ALL,
	ATTACK_SINGLE,
	DOWN,
	DEAD
}

# ==============================
# 共通パラメータ
# ==============================
@export var health: int = 100
@export var max_health: int = 100
@export var attack: int = 10
@export var defense: int = 10
@export var type: int = 0
@export var speed: float = 2.5
@export var gravity: float = 9.8

var state: int = UnitState.IDLE
var state_timer: float = 0.0
var isanim: bool = false

# 外部アクセス用プロパティ
var hp: int:
	get:
		return health
	set(value):
		health = clamp(value, 0, max_health)
		_update_hp_billboard()

var max_hp: int:
	get:
		return max_health
	set(value):
		max_health = value
		_update_hp_billboard()

# ==============================
# モデル・アニメーション キャッシュ機構
# ==============================
# staticキャッシュ: 全ユニットで PackedScene を共有（同一モデルの重複ロード防止）
static var packed_scene_cache: Dictionary = {}
static var _loading_paths: Dictionary = {}

static func preload_model_async(path: String) -> void:
	if not packed_scene_cache.has(path) and not _loading_paths.has(path):
		_loading_paths[path] = true
		ResourceLoader.load_threaded_request(path, "PackedScene", true)

var animation_model_paths: Array = []
var animation_models: Dictionary = {}        # anim_name -> path
var loaded_models: Dictionary = {}           # anim_name -> instantiated Node
var animation_player: AnimationPlayer = null
var current_visual_model_root: Node3D = null
var current_animation_name: String = ""
var battle_idle_anim: String = ""

# ==============================
# HPバー ビルボード
# ==============================
var hp_viewport: SubViewport
var hp_sprite: Sprite3D
var hp_progress: ProgressBar
var hp_label_control: Label
var hp_camera: Camera3D

# ==============================
# 初期化
# ==============================
func _setup_unit_base():
	_create_collision_shape()
	_setup_visual_model()

func setup_hp_bar_for_battle():
	_create_hp_billboard()
	_update_hp_billboard()


func _create_collision_shape():
	if get_node_or_null("CollisionShape3D"):
		return
	var new_collision = CollisionShape3D.new()
	new_collision.name = "CollisionShape3D"
	var shape = SphereShape3D.new()
	shape.radius = 0.5
	new_collision.shape = shape
	add_child(new_collision)

func _setup_visual_model():
	current_visual_model_root = get_node_or_null("VisualModelRoot")
	if not current_visual_model_root:
		current_visual_model_root = Node3D.new()
		current_visual_model_root.name = "VisualModelRoot"
		add_child(current_visual_model_root)
	current_visual_model_root.position.y = -0.4

func set_animation_model_paths(paths) -> void:
	animation_models.clear()
	if paths is Array:
		animation_model_paths = paths.duplicate()
		for p in animation_model_paths:
			if typeof(p) != TYPE_STRING:
				continue
			var fname = p.get_file().get_basename()
			animation_models[fname] = p
	elif paths is Dictionary:
		animation_models = paths.duplicate()
		animation_model_paths = paths.values()

func assign_battle_idle_anim():
	var idle_anim = []
	for key in animation_models.keys():
		if key in ["Animation_Alert_withSkin", "Animation_All_Night_Dance_withSkin", "Animation_Boom_Dance_withSkin"]:
			idle_anim.append(key)
	if idle_anim.size() > 0:
		battle_idle_anim = idle_anim.pick_random()
	elif animation_models.size() > 0:
		battle_idle_anim = animation_models.keys().pick_random()

# ==============================
# アニメーション再生（キャッシュ活用）
# ==============================
func play_unit_animation(anim_name: String) -> void:
	if animation_models.is_empty():
		return

	var target_key: String = ""
	if animation_models.has(anim_name):
		target_key = anim_name
	else:
		# 部分一致・小文字検索
		var l_req = anim_name.to_lower()
		for k in animation_models.keys():
			var l_k = k.to_lower()
			if l_req in l_k or l_k in l_req:
				target_key = k
				break
		# フォールバック（最初のモデル）
		if target_key == "" and animation_models.size() > 0:
			target_key = animation_models.keys()[0]

	if target_key == "":
		return

	if current_animation_name == target_key and isanim:
		return

	if not current_visual_model_root:
		_setup_visual_model()

	# 既存の表示モデルを非表示にする（破棄しないことでスパイク防止）
	for child in current_visual_model_root.get_children():
		if "visible" in child:
			child.visible = false

	# すでにインスタンス化されているか確認
	var inst: Node3D = null
	if loaded_models.has(target_key) and is_instance_valid(loaded_models[target_key]):
		inst = loaded_models[target_key]
		if "visible" in inst:
			inst.visible = true
	else:
		var model_path = animation_models[target_key]
		if not ResourceLoader.exists(model_path):
			push_warning("Model not found at: " + model_path)
			return

		# Static キャッシュから PackedScene を取得
		var scene_res: PackedScene = null
		if packed_scene_cache.has(model_path):
			scene_res = packed_scene_cache[model_path]
		else:
			var load_status = ResourceLoader.load_threaded_get_status(model_path)
			if load_status == ResourceLoader.THREAD_LOAD_LOADED:
				scene_res = ResourceLoader.load_threaded_get(model_path)
				if scene_res is PackedScene:
					packed_scene_cache[model_path] = scene_res
			else:
				# 非同期ロードが間に合わなかった・失敗した場合は同期ロード
				scene_res = load(model_path)
				if scene_res is PackedScene:
					packed_scene_cache[model_path] = scene_res

		if not scene_res or not (scene_res is PackedScene):
			push_warning("Failed to load PackedScene: " + model_path)
			return

		inst = scene_res.instantiate()
		current_visual_model_root.add_child(inst)
		if "visible" in inst:
			inst.visible = true
		loaded_models[target_key] = inst

	current_animation_name = target_key
	isanim = true

	# AnimationPlayer を取得して再生
	var ap: AnimationPlayer = inst.get_node_or_null("AnimationPlayer")
	if not ap:
		ap = inst.find_child("AnimationPlayer", true, false)
	
	if ap:
		animation_player = ap
		var play_name = ""
		var ap_anims = ap.get_animation_list()
		if ap_anims.size() > 0:
			if target_key in ap_anims:
				play_name = target_key
			else:
				var l_target = target_key.to_lower()
				for a in ap_anims:
					if l_target in a.to_lower() or a.to_lower() in l_target:
						play_name = a
						break
				if play_name == "":
					play_name = ap_anims[0]

		if play_name != "":
			var anim_res = ap.get_animation(play_name)
			if anim_res:
				anim_res.loop_mode = Animation.LOOP_LINEAR
			ap.play(play_name)

# ==============================
# HPバー（Sprite3D + SubViewport）
# ==============================
func _create_hp_billboard():
	if get_node_or_null("HP_Sprite"):
		return

	hp_viewport = SubViewport.new()
	hp_viewport.name = "HP_SubViewport"
	hp_viewport.size = Vector2i(120, 20)
	hp_viewport.transparent_bg = true

	hp_progress = ProgressBar.new()
	hp_progress.name = "HP_ProgressBar"
	hp_progress.custom_minimum_size = Vector2(120, 20)
	hp_progress.min_value = 0
	hp_progress.max_value = max_health
	hp_progress.value = health
	hp_progress.show_percentage = false

	# HPバースタイル設定
	var style_box_bg = StyleBoxFlat.new()
	style_box_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style_box_bg.corner_radius_top_left = 3
	style_box_bg.corner_radius_top_right = 3
	style_box_bg.corner_radius_bottom_left = 3
	style_box_bg.corner_radius_bottom_right = 3

	var style_box_fill = StyleBoxFlat.new()
	style_box_fill.bg_color = Color(0.1, 0.8, 0.1, 1.0)
	style_box_fill.corner_radius_top_left = 3
	style_box_fill.corner_radius_top_right = 3
	style_box_fill.corner_radius_bottom_left = 3
	style_box_fill.corner_radius_bottom_right = 3

	hp_progress.add_theme_stylebox_override("background", style_box_bg)
	hp_progress.add_theme_stylebox_override("fill", style_box_fill)

	hp_label_control = Label.new()
	hp_label_control.text = "%d/%d" % [health, max_health]
	hp_label_control.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label_control.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label_control.set_anchors_preset(Control.PRESET_FULL_RECT)

	hp_viewport.add_child(hp_progress)
	hp_viewport.add_child(hp_label_control)
	add_child(hp_viewport)

	hp_sprite = Sprite3D.new()
	hp_sprite.name = "HP_Sprite"
	hp_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_sprite.position = Vector3(0, 1.8, 0)
	hp_sprite.pixel_size = 0.01
	hp_sprite.texture = hp_viewport.get_texture()
	add_child(hp_sprite)

func _update_hp_billboard():
	if hp_progress:
		hp_progress.max_value = max_health
		hp_progress.value = health
	if hp_label_control:
		hp_label_control.text = "%d/%d" % [health, max_health]

# ==============================
# ダメージ＆回復処理
# ==============================
func take_damage(amount: int) -> int:
	var damage = int(amount * (100.0 / (100.0 + defense)))
	damage = max(1, damage)
	self.hp -= damage
	_show_damage_popup(damage)
	if health <= 0:
		_transition_to_dead()
	else:
		state = UnitState.DOWN
		isanim = false
		if animation_models.has("Animation_BeHit_FlyUp_withSkin"):
			play_unit_animation("Animation_BeHit_FlyUp_withSkin")
		elif battle_idle_anim != "":
			play_unit_animation(battle_idle_anim)
	return damage

func receive_heal(amount: int) -> void:
	self.hp += amount

func _show_damage_popup(amount: int):
	var label = Label3D.new()
	label.text = str(amount)
	label.font_size = 32
	label.modulate = Color.RED
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = position + Vector3(0, 1.5, 0)
	if get_parent():
		get_parent().add_child(label)
		var tween = create_tween()
		tween.tween_property(label, "position:y", label.position.y + 0.8, 0.6)
		tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
		tween.finished.connect(func(): label.queue_free())

func _transition_to_dead():
	state = UnitState.DEAD
	isanim = false
	if animation_models.has("Animation_Dead_withSkin"):
		play_unit_animation("Animation_Dead_withSkin")
	elif battle_idle_anim != "":
		play_unit_animation(battle_idle_anim)
	await get_tree().create_timer(2.0).timeout
	queue_free()
