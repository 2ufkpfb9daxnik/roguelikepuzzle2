extends CharacterBody3D

# ==============================
# 状態定義
# ==============================
enum State {
	BATTLE_IDLE,
	ATTACK_PREPARE,
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

var max_hp: int:
	get:
		return max_health
	set(value):
		max_health = value

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
# 初期化
# ==============================
func _ready():
	_create_collision_shape()
	_setup_visual_model()
	assign_battle_idle_anim()
	state = State.BATTLE_IDLE

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	match state:
		State.BATTLE_IDLE:
			_process_battle_idle(delta)
		State.ATTACK_PREPARE:
			_process_attack_prepare(delta)
		State.ATTACK_ALL:
			_process_attack_all(delta)
		State.ATTACK_SINGLE:
			_process_attack_single(delta)
		State.DOWN:
			pass
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
		isanim = true
		if battle_idle_anim != "":
			_play_animation(battle_idle_anim)
		else:
			_play_any_idle_animation()

func _process_attack_prepare(delta):
	if animation_player and not animation_player.is_playing():
		if randi() % 2 == 0:
			state = State.ATTACK_ALL
			_play_animation("Animation_Skill_01_withSkin")
		else:
			state = State.ATTACK_SINGLE
			_play_animation("Animation_Skill_03_withSkin")

func _process_attack_all(delta):
	if animation_player and not animation_player.is_playing():
		state = State.BATTLE_IDLE
		isanim = false

func _process_attack_single(delta):
	if animation_player and not animation_player.is_playing():
		state = State.BATTLE_IDLE
		isanim = false

# ==============================
# 行動遷移関数
# ==============================
func start_attack():
	state = State.ATTACK_PREPARE
	_play_animation("Animation_Boxing_Practice_withSkin")

func receive_damage(amount: int):
	health -= amount
	if health <= 0:
		health = 0
		_transition_to_dead()
	else:
		_transition_to_down()

func _transition_to_dead():
	state = State.DEAD
	_play_animation("Animation_Dead_withSkin")
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _transition_to_down():
	state = State.DOWN
	_play_animation("Animation_BeHit_FlyUp_withSkin",false)
	if animation_player:
		await animation_player.animation_finished
	_play_animation("Animation_Arise_withSkin",false)
	if animation_player:
		await animation_player.animation_finished
	state = State.BATTLE_IDLE
	isanim = false
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

func _play_animation(anim_name: String,isloop: bool = true) -> void:
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
		if "loop" in anim_res:
			anim_res.loop = isloop

	animation_player = ap
	current_animation_name = play_name
