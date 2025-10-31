extends CharacterBody3D

@export var health: int = 100
@export var speed: float = 2.5
@export var gravity: float = 9.8
@export var detection_range: float = 12.0 # プレイヤーを検知する距離
@export var chase_speed_multiplier: float = 2.0 # 追跡時の速度倍率

var player: Node3D = null

# ===== 状態管理 =====
enum State { IDLE, MOVE, DETECTED, CHASE }
var state: State = State.IDLE
var state_timer: float = 0.0
var target_time: float = 0.0
var random_direction: Vector3 = Vector3.ZERO

# ===== アニメーション管理 =====
var animation_player: AnimationPlayer
var current_animation_name: String = ""
var animation_model_paths: Dictionary = {}
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
	if not get_node_or_null("CollisionShape3D"):
		var new_collision = CollisionShape3D.new()
		var shape = CapsuleShape3D.new()
		shape.radius = 0.5
		shape.height = 1.5
		new_collision.shape = shape
		new_collision.name = "CollisionShape3D"
		add_child(new_collision)

	current_visual_model_root = get_node_or_null("VisualModelRoot")
	if current_visual_model_root:
		current_visual_model_root.position.y = -1.2
	else:
		push_warning("No 'VisualModelRoot' found in enemy instance.")
		return

	animation_player = current_visual_model_root.get_node_or_null("AnimationPlayer")
	if animation_player:
		play_animation("Animation_Idle_withSkin")

	# ビックリマークをセット
	_create_exclamation_icon()

	state = State.IDLE
	_set_random_idle_duration()

	# プレイヤー探索
	var parent = get_parent()
	if parent:
		player = parent.get_node_or_null("CharacterBody3D")

# ===============================
#       毎フレーム処理
# ===============================
func _physics_process(delta):
	# 重力適用
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if player:
		var dist_to_player = global_position.distance_to(player.global_position)
		match state:
			State.IDLE, State.MOVE:
				if dist_to_player <= detection_range:
					state = State.DETECTED
					_play_detection()
			State.DETECTED:
				_process_detected(delta)
			State.CHASE:
				if dist_to_player > detection_range * 1.5:
					# 見失ったらIDLEへ戻る
					state = State.IDLE
					play_animation("Animation_Idle_withSkin")
				else:
					_process_chase(delta)
	else:
		match state:
			State.IDLE:
				_process_idle(delta)
			State.MOVE:
				_process_move(delta)

	move_and_slide()

	if exclamation_ui:
		_update_exclamation(delta)

# ===============================
#        状態ごとの処理
# ===============================

func _process_idle(delta: float) -> void:
	state_timer += delta
	if state_timer >= target_time:
		state = State.MOVE
		play_animation("Animation_Walking_withSkin")
		state_timer = 0.0
		target_time = randf_range(1.5, 3.0)
		random_direction = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
		var target_rotation = atan2(random_direction.x, random_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 1.0)

func _process_move(delta: float) -> void:
	state_timer += delta
	var forward = Vector3(sin(rotation.y), 0, cos(rotation.y))
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed

	if state_timer >= target_time:
		state = State.IDLE
		play_animation("Animation_Idle_withSkin")
		velocity.x = 0.0
		velocity.z = 0.0
		state_timer = 0.0
		_set_random_idle_duration()

func _process_detected(delta: float) -> void:
	exclamation_time += delta
	if exclamation_time >= exclamation_duration:
		state = State.CHASE
		play_animation("Animation_Running_withSkin")

func _process_chase(delta: float) -> void:
	if not player: return
	var direction = (player.global_position - global_position).normalized()
	var target_rot = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_rot, delta * 5.0)
	var forward = Vector3(sin(rotation.y), 0, cos(rotation.y))
	velocity.x = forward.x * speed * chase_speed_multiplier
	velocity.z = forward.z * speed * chase_speed_multiplier

# ===============================
#     アニメーション管理
# ===============================

func set_animation_model_paths(paths_array: Array):
	animation_model_paths.clear()
	for path in paths_array:
		var file_name_with_ext = path.get_file()
		var animation_name = file_name_with_ext.get_basename()
		animation_model_paths[animation_name] = path

func play_animation(anim_name: String):
	if current_animation_name == anim_name:
		return
	if not animation_model_paths.has(anim_name):
		push_warning("Animation '" + anim_name + "' not found for this enemy.")
		return

	var new_model_path = animation_model_paths[anim_name]
	if is_instance_valid(current_visual_model_root):
		current_visual_model_root.queue_free()
		current_visual_model_root = null

	var loaded_model = load(new_model_path)
	var new_visual_root: Node3D = null
	if loaded_model is PackedScene:
		new_visual_root = loaded_model.instantiate()
	elif loaded_model is Mesh:
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = loaded_model
		new_visual_root = mesh_inst
	else:
		push_warning("Unsupported resource type: " + new_model_path)
		return

	if new_visual_root:
		new_visual_root.name = "VisualModelRoot"
		add_child(new_visual_root)
		current_visual_model_root = new_visual_root
		animation_player = current_visual_model_root.get_node_or_null("AnimationPlayer")
		if animation_player:
			var animations = animation_player.get_animation_list()
			if not animations.is_empty():
				var real_anim = animations[0]
				var anim = animation_player.get_animation(real_anim)
				anim.set_loop_mode(Animation.LOOP_LINEAR)
				animation_player.play(real_anim)
				current_animation_name = anim_name

# ===============================
#     IDLE時間設定
# ===============================
func _set_random_idle_duration():
	target_time = randf_range(2.0, 4.5)

# ===============================
#     ビックリマーク管理
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
	exclamation_alpha = 0.0

func _play_detection():
	exclamation_state = "fade_in"
	exclamation_alpha = 0.0
	exclamation_ui.position = Vector3(0, 0.5, 0)
	exclamation_time = 0.0
	if animation_player:
		animation_player.stop() # アニメーションを静止
	velocity = Vector3.ZERO

func _update_exclamation(delta: float):
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
