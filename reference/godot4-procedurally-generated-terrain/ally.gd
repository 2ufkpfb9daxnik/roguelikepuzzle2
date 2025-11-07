extends CharacterBody3D

# ==============================
# 状態定義
# ==============================
enum State {
	BATTLE_IDLE,
	BATTLE_MOVE,
	ATTACK_ALL,
	ATTACK_SINGLE,
	DOWN,
	DEAD
}

# ==============================
# パラメータ設定
# ==============================
@export var attack: int = 10
@export var health: int = 100
@export var max_health: int = 100
@export var type: int = 0
@export var gravity: float = 9.8

# 外部アクセス対応用プロパティ
var hp: int:
	get:
		return health
	set(value):
		health = clamp(value, 0, max_health)
		_update_hp_billboard() # ← HP変更時にバー更新

var max_hp: int:
	get:
		return max_health
	set(value):
		max_health = value
		_update_hp_billboard() # ← 最大HP変更時も更新

# ==============================
# 内部状態
# ==============================
var state: State = State.BATTLE_IDLE
var state_timer: float = 0.0
var isanim: bool = false

# ==============================
# アニメーション関連
# ==============================
var animation_model_paths: Dictionary = {}
var animation_models: Dictionary = {}        # anim_name -> path
var loaded_models: Dictionary = {}            # anim_name -> instantiated Node
var animation_player: AnimationPlayer = null
var current_visual_model_root: Node3D = null
var current_animation_name: String = ""
var battle_idle_anim: String = ""

# ==============================
# HPビルボード関連（追加）
# ==============================
var hp_viewport: Viewport
var hp_progress: ProgressBar
var hp_label_control: Label
var hp_sprite: Sprite3D
var hp_camera: Camera3D

# ==============================
# 初期化
# ==============================
func _ready():
	_create_collision_shape()
	_setup_visual_model()
	assign_battle_idle_anim()
	state = State.BATTLE_IDLE

	# HPビルボード作成
	_create_hp_billboard()
	_update_hp_billboard()

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	match state:
		State.BATTLE_IDLE:
			_process_battle_idle(delta)
		State.BATTLE_MOVE:
			_process_battle_move(delta)
		State.ATTACK_ALL:
			_process_attack_all(delta)
		State.ATTACK_SINGLE:
			_process_attack_single(delta)
		State.DOWN:
			_process_down(delta)
		State.DEAD:
			pass

	move_and_slide()

# ==============================
# 初期設定
# ==============================
func _create_collision_shape():
	if get_node_or_null("CollisionShape3D"):
		return
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.8
	shape.height = 1.5
	col.shape = shape
	add_child(col)

func _setup_visual_model():
	current_visual_model_root = get_node_or_null("VisualModelRoot")
	if not current_visual_model_root:
		current_visual_model_root = Node3D.new()
		current_visual_model_root.name = "VisualModelRoot"
		add_child(current_visual_model_root)

# ==============================
# アニメーションモデル設定
# ==============================
func set_animation_model_paths(paths: Dictionary) -> void:
	animation_model_paths = paths
	animation_models.clear()
	for key in animation_model_paths.keys():
		var p = animation_model_paths[key]
		if typeof(p) != TYPE_STRING:
			continue
		var fname = p.get_file().get_basename()
		animation_models[fname] = p

func assign_battle_idle_anim():
	var idle_anim = []
	for key in animation_models.keys():
		if "Idle" in key or "Alert" in key or "Dance" in key:
			idle_anim.append(key)
	if idle_anim.size() > 0:
		battle_idle_anim = idle_anim.pick_random()

# ==============================
# 戦闘ステート処理
# ==============================
func _process_battle_idle(delta):
	if not isanim:
		if battle_idle_anim != "":
			_play_animation(battle_idle_anim)
		else:
			_play_any_idle_animation()
		isanim = true

func _process_battle_move(delta):
	if isanim:
		return
	_play_animation("Animation_Running_withSkin")
	isanim = true

func _process_attack_all(delta):
	if isanim:
		return
	_play_animation("Animation_Skill_01_withSkin")
	isanim = true

func _process_attack_single(delta):
	if isanim:
		return
	_play_animation("Animation_Skill_03_withSkin")
	isanim = true

func _process_down(delta):
	state_timer += delta
	if state_timer >= 1.0 and state_timer < 2.0:
		if isanim:
			return
		isanim = true
		_play_animation("Animation_Arise_withSkin")
	if state_timer >= 2.0:
		state_timer = 0.0
		isanim = false
		state = State.BATTLE_IDLE

func receive_damage(amount: int):
	health -= amount
	if hp_progress:
		hp_progress.value = health
	if health <= 0:
		health = 0
		_transition_to_dead()
	else:
		state = State.DOWN
		isanim = false
		_play_animation("Animation_BeHit_FlyUp_withSkin")
		_update_hp_billboard() # ← ダメージ受けた時に更新

func _transition_to_dead():
	state = State.DEAD
	_play_animation("Animation_Dead_withSkin")
	await get_tree().create_timer(2.0).timeout
	queue_free()

# ==============================
# アニメーション制御
# ==============================
func _play_any_idle_animation():
	for key in animation_models.keys():
		if "Idle" in key:
			_play_animation(key)
			return
	if animation_models.size() > 0:
		_play_animation(animation_models.keys()[0])

func _play_animation(anim_name: String) -> void:
	if not animation_models.has(anim_name):
		push_warning("❌ Animation not found in dictionary: " + anim_name)
		return

	if current_visual_model_root:
		for child in current_visual_model_root.get_children():
			child.queue_free()
		await get_tree().process_frame

	var model_path = animation_models[anim_name]
	if not ResourceLoader.exists(model_path):
		push_warning("❌ GLB not found: " + model_path)
		return

	var scene_res = load(model_path)
	if not (scene_res and scene_res is PackedScene):
		push_warning("❌ Failed to load GLB at: " + model_path)
		return

	var inst = scene_res.instantiate()
	current_visual_model_root.add_child(inst)
	loaded_models.clear()
	loaded_models[anim_name] = inst

	var ap = inst.get_node_or_null("AnimationPlayer")
	if not ap:
		ap = inst.find_child("AnimationPlayer", true, false)
	if not ap:
		push_warning("❌ No AnimationPlayer found inside: " + anim_name)
		return

	var play_name = anim_name
	var ap_anims = ap.get_animation_list()
	if not (anim_name in ap_anims) and ap_anims.size() > 0:
		play_name = ap_anims[0]

	ap.play(play_name)
	var anim_res = ap.get_animation(play_name)
	if anim_res:
		anim_res.loop = true

	animation_player = ap
	current_animation_name = play_name


# ==============================
# 🎯 HPビルボード関連関数（追加）
# ==============================

# HPバー生成
func _create_hp_billboard():
	# hp_camera はバトル生成時に battle_scene.gd からセットするのが確実です。
	# （自動取得も試みますが、SubViewport構成によっては正しく取れないため）
	if not hp_camera:
		# 可能なら現在の Viewport のカメラを使ってみる（フォールバック）
		var cam_try = get_viewport().get_camera_3d()
		if cam_try:
			hp_camera = cam_try

	# SubViewport を使って 2D をレンダリングする（Viewport は抽象のため不可）
	hp_viewport = SubViewport.new()
	hp_viewport.disable_3d = true
	hp_viewport.transparent_bg = true
	# 更新モードを常時更新に（SubViewport の列挙子を使用）
	# 注：SubViewport.UPDATE_ALWAYS が存在する Godot 4.x の想定
	hp_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	hp_viewport.size = Vector2i(256, 64)
	add_child(hp_viewport)

	# 2D Control ルート（サイズを明示）
	var root = Control.new()
	root.set_size(Vector2(hp_viewport.size))
	root.set_custom_minimum_size(Vector2(hp_viewport.size))
	hp_viewport.add_child(root)

	# 半透明背景（任意）
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.4)
	bg.set_size(Vector2(hp_viewport.size))
	bg.anchor_left = 0
	bg.anchor_top = 0
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	root.add_child(bg)

	# ProgressBar（HPバー）
	hp_progress = ProgressBar.new()
	hp_progress.min_value = 0
	hp_progress.max_value = max_health
	hp_progress.value = health
	hp_progress.show_percentage = false
	# レイアウトはアンカー／マージンで調整
	hp_progress.anchor_left = 0.05
	hp_progress.anchor_right = 0.95
	hp_progress.anchor_top = 0.4
	hp_progress.anchor_bottom = 0.7
	root.add_child(hp_progress)

	# Label（HP数値） — グローバル整列定数を使用
	hp_label_control = Label.new()
	hp_label_control.text = str(health)
	hp_label_control.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label_control.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label_control.anchor_left = 0
	hp_label_control.anchor_right = 1
	hp_label_control.anchor_top = 0
	hp_label_control.anchor_bottom = 1
	root.add_child(hp_label_control)

	# Sprite3D に ViewportTexture を割り当てて頭上に配置
	hp_sprite = Sprite3D.new()
	hp_sprite.texture = hp_viewport.get_texture()
	# pixel_size は存在するバージョンでは有効（無ければ無視）
	if "pixel_size" in hp_sprite:
		hp_sprite.pixel_size = 0.005
	# ビルボードの定数を使わない：代わりに _process() で毎フレーム look_at する
	hp_sprite.position = Vector3(0, 3, 0) # 必要に応じて調整
	add_child(hp_sprite)

# HPバー更新
func _update_hp_billboard():
	if hp_progress:
		hp_progress.max_value = max_health
		hp_progress.value = health
	if hp_label_control:
		hp_label_control.text = str(health)

# カメラ追従
func _process(delta):
	if hp_sprite:
		# 明示的にセットされたカメラがあればそれを使う（推奨）
		if hp_camera and hp_camera.is_inside_tree():
			hp_sprite.look_at(hp_camera.global_transform.origin, Vector3.UP)
		else:
			# フォールバック：現在の viewport のカメラ（存在すれば）
			var cam_try = get_viewport().get_camera_3d()
			if cam_try:
				hp_sprite.look_at(cam_try.global_transform.origin, Vector3.UP)
