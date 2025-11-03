extends CharacterBody3D

# ===== 状態管理 =====
enum State {
	IDLE,
	MOVE,
	DETECT,
	CHASE,
	BATTLE_IDLE,
	ATTACK_PREPARE,
	ATTACK_ALL,
	ATTACK_SINGLE,
	DOWN,
	DEAD
}

@export var health: int = 100
@export var speed: float = 2.5
@export var gravity: float = 9.8
@export var detection_range: float = 12.0
@export var chase_speed_multiplier: float = 2.0
@export var biome_type: int = 0

var player: Node3D = null
var state: State = State.IDLE
var state_timer: float = 0.0
var target_time: float = 0.0
var random_direction: Vector3 = Vector3.ZERO

# ===== アニメーション関連 =====
var animation_player: AnimationPlayer
var current_animation_name: String = ""
var current_visual_model_root: Node3D = null

# ===== ビックリマーク管理 =====
var exclamation_ui: Sprite3D = null
var exclamation_alpha: float = 0.0
var exclamation_rise_height: float = 2.5
var exclamation_time: float = 0.0
var exclamation_duration: float = 2.0
var exclamation_state: String = "hidden" # "fade_in" / "stay" / "fade_out"

# ===============================
#       初期化
# ===============================
func _ready():
	connect("body_entered", _on_body_entered)
	_create_collision_shape()
	_setup_visual_model()
	_create_exclamation_icon()

	var parent = get_parent()
	if parent:
		player = parent.get_node_or_null("CharacterBody3D")

	_set_random_idle_duration()
	state = State.IDLE

func _physics_process(delta):
	# 重力
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	match state:
		State.IDLE:
			_process_idle(delta)
		State.MOVE:
			_process_move(delta)
		State.DETECT:
			_process_detect(delta)
		State.CHASE:
			_process_chase(delta)
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

	if exclamation_ui:
		_update_exclamation(delta)

# ===============================
#   初期化関数
# ===============================
func _create_collision_shape():
	if get_node_or_null("CollisionShape3D"): return
	var new_collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 1.0
	shape.height = 1.5
	new_collision.shape = shape
	add_child(new_collision)

func _setup_visual_model():
	current_visual_model_root = get_node_or_null("VisualModelRoot")
	if current_visual_model_root:
		current_visual_model_root.position.y = -0.2
		animation_player = current_visual_model_root.get_node_or_null("AnimationPlayer")
		if animation_player:
			_play_animation("Animation_Idle_withSkin")

	# 探索時初期アニメーションを再生
	_play_animation("Animation_Idle_withSkin")
func _set_random_idle_duration():
	target_time = randf_range(2.0, 4.5)

# ===============================
#   探索モード
# ===============================
func _process_idle(delta):
	state_timer += delta
	if state_timer >= target_time:
		state = State.MOVE
		_play_animation("Animation_Walking_withSkin")
		state_timer = 0
		target_time = randf_range(1.5, 3.0)
		random_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		rotation.y = atan2(random_direction.x, random_direction.z)
	else:
		if player and global_position.distance_to(player.global_position) <= detection_range:
			state = State.DETECT
			_play_detection()

func _process_move(delta):
	state_timer += delta
	var forward = Vector3(sin(rotation.y), 0, cos(rotation.y))
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed

	if state_timer >= target_time:
		state = State.IDLE
		_play_animation("Animation_Idle_withSkin")
		velocity = Vector3.ZERO
		state_timer = 0
		_set_random_idle_duration()
	elif player and global_position.distance_to(player.global_position) <= detection_range:
		state = State.DETECT
		_play_detection()

func _process_detect(delta):
	exclamation_time += delta
	if exclamation_time >= exclamation_duration:
		state = State.CHASE
		_play_animation("Animation_Running_withSkin")

func _process_chase(delta):
	if not player: return
	var dir = (player.global_position - global_position).normalized()
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 5.0)
	var forward = Vector3(sin(rotation.y), 0, cos(rotation.y))
	velocity.x = forward.x * speed * chase_speed_multiplier
	velocity.z = forward.z * speed * chase_speed_multiplier

	if global_position.distance_to(player.global_position) > detection_range * 1.5:
		state = State.IDLE
		_play_animation("Animation_Idle_withSkin")

# ===============================
#   バトルモード
# ===============================
func _process_battle_idle(delta):
	if animation_player and not animation_player.is_playing():
		var idle_anims = ["Animation_Alert_withSkin", "Animation_All_Night_Dance_withSkin", "Animation_Boom_Dance_withSkin"]
		_play_animation(idle_anims[randi() % idle_anims.size()])

func start_attack():
	state = State.ATTACK_PREPARE
	_play_animation("Animation_Boxing_Practice_withSkin")
	animation_player.seek(40/60.0, true)
	animation_player.play()

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

func _process_attack_single(delta):
	if animation_player and not animation_player.is_playing():
		state = State.BATTLE_IDLE

func receive_damage(amount: int):
	health -= amount
	if health <= 0:
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
	_play_animation("Animation_BeHit_FlyUp_withSkin")
	await animation_player.animation_finished
	_play_animation("Animation_Arise_withSkin")
	await animation_player.animation_finished
	state = State.BATTLE_IDLE

# ===============================
#   汎用アニメーション再生
# ===============================
func _play_animation(anim_name: String):
	if not animation_player:
		push_warning("No AnimationPlayer found")
		return
	if current_animation_name == anim_name:
		return
	if not animation_player.has_animation(anim_name):
		push_warning("Animation not found: " + anim_name)
		return
	current_animation_name = anim_name
	animation_player.play(anim_name)

# ===============================
#   ビックリマーク管理
# ===============================
func _create_exclamation_icon():
	exclamation_ui = Sprite3D.new()
	exclamation_ui.texture = preload("res://ui/exclamation_icon.png")
	exclamation_ui.modulate.a = 0.0
	exclamation_ui.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	exclamation_ui.scale = Vector3(0.5, 0.5, 0.5)
	exclamation_ui.position = Vector3(0, 1.5, 0)
	add_child(exclamation_ui)
	exclamation_state = "hidden"

func _play_detection():
	exclamation_state = "fade_in"
	exclamation_alpha = 0.0
	exclamation_ui.position = Vector3(0, 0.5, 0)
	exclamation_time = 0.0
	if animation_player:
		animation_player.stop()
	velocity = Vector3.ZERO

func _update_exclamation(delta):
	match exclamation_state:
		"fade_in":
			exclamation_alpha += delta * 2.0
			exclamation_ui.modulate.a = clamp(exclamation_alpha, 0, 1)
			exclamation_ui.position.y = lerp(exclamation_ui.position.y, exclamation_rise_height, delta * 2.0)
			if exclamation_alpha >= 1.0:
				exclamation_state = "stay"
				exclamation_time = 0.0
		"stay":
			exclamation_time += delta
			if exclamation_time >= exclamation_duration:
				exclamation_state = "fade_out"
		"fade_out":
			exclamation_alpha -= delta
			exclamation_ui.modulate.a = clamp(exclamation_alpha, 0, 1)
			if exclamation_alpha <= 0:
				exclamation_state = "hidden"

# ===============================
#   プレイヤー接触
# ===============================
func _on_body_entered(body):
	if body.name == "Player":
		print("Player touched enemy in biome:", biome_type)
		_transition_to_battle(biome_type,name)

# ===============================
#   戦闘シーン遷移
# ===============================
func _transition_to_battle(biome: int, encountered_enemy: String):
	# PackedScene 自体を渡す
	var battle_scene = preload("res://battle_scene.tscn").instantiate()
	battle_scene.biome_type = biome_type
	battle_scene.encountered_enemy_name = name
	get_tree().change_scene_to_packed(battle_scene)
