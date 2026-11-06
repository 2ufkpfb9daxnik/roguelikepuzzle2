extends CharacterBody3D

#==> EXPORT <==#
@export var speed: float = 10.0
@export var sprint_speed: float = 16.0
@export var jump_speed: float = 10.0
@export var mouse_sensitivity: float = 2.0
var torch_light: OmniLight3D
var isbattle: bool = false
var money: int = 0
var movement_enabled: bool = true
var safe_respawn_position: Vector3 = Vector3(0, 10, 0)
var safe_pos_timer: float = 0.0
var _last_land_position: Vector3 = Vector3.ZERO
var _has_land_position: bool = false
var player_model_root: Node3D = null
var camera_mode: int = 0 # 0: 一人称, 1: 三人称
var _first_person_camera_pos := Vector3(0, 0.7, 0)
var _procedural_walk_time := 0.0
var _last_on_floor := true

#==> OTHER <==#
var gravity: float = 9.8
var time_passed: float = 0.0
@onready var camera: Camera3D = $Camera3D
var normal_fov: float = 75.0
var sprint_fov: float = 83.0

#==> CODE <==#
func set_movement_enabled(enabled: bool) -> void:
	movement_enabled = enabled
	if not enabled:
		velocity.x = 0.0
		velocity.z = 0.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	torch_light = OmniLight3D.new()
	torch_light.light_color = Color(1.0, 0.85, 0.6)
	torch_light.light_energy = 2.5
	torch_light.omni_range = 25.0
	torch_light.shadow_enabled = true
	add_child(torch_light)
	torch_light.position = Vector3(1.5, 1.5, 1.5)

	if camera:
		camera.fov = normal_fov
		_first_person_camera_pos = camera.position
	_setup_player_model()

func _setup_player_model() -> void:
	var model_path := "res://model/businessman 3d model.glb"
	if not ResourceLoader.exists(model_path):
		model_path = "res://model/businessman (1).glb"
	if not ResourceLoader.exists(model_path):
		return
	var scene_res = load(model_path)
	if not (scene_res is PackedScene):
		return
	player_model_root = Node3D.new()
	player_model_root.name = "BusinessmanModel"
	add_child(player_model_root)
	var model = scene_res.instantiate()
	model.rotation.y = PI
	player_model_root.add_child(model)
	player_model_root.visible = camera_mode == 1

func _physics_process(delta: float):
	# 戦闘中はプレイヤーの物理演算・重力・衝突を完全停止
	if isbattle:
		velocity = Vector3.ZERO
		return

	# 奈落落下フェールセーフ（ワールドの端や地形の穴から落ちた際の安全復帰）
	if global_position.y < -15.0:
		global_position = safe_respawn_position + Vector3(0, 2.0, 0)
		velocity = Vector3.ZERO
		return

	# 地上にいるときは定期的に安全復帰地点を更新
	if is_on_floor():
		safe_pos_timer += delta
		if safe_pos_timer >= 1.0:
			safe_pos_timer = 0.0
			safe_respawn_position = global_position

	if not movement_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y -= gravity * delta
		move_and_slide()
		return

	# 万が一チャンク読み込み遅延等で地面ブロック内部に埋まった場合の自動脱出フェールセーフ
	var parent_node = get_parent()
	if parent_node:
		var t_node = parent_node.get_node_or_null("terrain")
		if t_node and not t_node.is_generating and t_node.has_method("get_map3dnum"):
			var bx = int(round(global_position.x))
			var by_foot = int(round(global_position.y - 0.35))
			var bz = int(round(global_position.z))
			if t_node.get_map3dnum(bx, by_foot, bz) > 1:
				var gy = t_node.get_ground_y(bx, by_foot + 4, bz)
				if gy >= 0:
					global_position.y = float(gy) + 1.5
					velocity.y = 0.0

	velocity.y -= gravity * delta

	# ダッシュ（Sprint）判定
	var is_sprinting = Input.is_key_pressed(KEY_SHIFT) and is_on_floor()
	var cur_speed = sprint_speed if is_sprinting else speed

	var input = Vector2.ZERO
	if InputMap.has_action("a") and InputMap.has_action("d") and InputMap.has_action("w") and InputMap.has_action("s"):
		input = Input.get_vector("a", "d", "w", "s")
	if input == Vector2.ZERO:
		var ix = (1.0 if (Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) else 0.0) - (1.0 if (Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)) else 0.0)
		var iy = (1.0 if (Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) else 0.0) - (1.0 if (Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) else 0.0)
		input = Vector2(ix, iy).limit_length(1.0)

	if input.length_squared() > 0.01 and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var movement_dir = transform.basis * Vector3(input.x, 0, input.y)
	velocity.x = movement_dir.x * cur_speed
	velocity.z = movement_dir.z * cur_speed

	move_and_slide()
	_block_ocean_walk()

	# 段差（高さ1）の自動踏破（ステップアップ）
	if is_on_wall():
		_try_step_up(movement_dir)

	if is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_speed

	# ダッシュ時のカメラFOVスムーズ補間
	if camera:
		var target_fov = sprint_fov if (is_sprinting and input.length_squared() > 0.01) else normal_fov
		camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	_update_player_model(delta)
	_last_on_floor = is_on_floor()
	time_passed += delta

func _block_ocean_walk() -> void:
	var parent_node = get_parent()
	if parent_node == null:
		return
	var t_node = parent_node.get_node_or_null("terrain")
	if t_node == null or not t_node.has_method("get_map3dnum"):
		return
	if "is_generating" in t_node and t_node.is_generating:
		return
	var sea_height := 30.0
	if "SEAHEIGHT" in t_node:
		sea_height = float(t_node.SEAHEIGHT)
	if global_position.y > sea_height + 3.0:
		# 海面より十分高い場所は対象外。
		if is_on_floor():
			_last_land_position = global_position
			_has_land_position = true
		return
	var bx := int(round(global_position.x))
	var bz := int(round(global_position.z))
	var by := int(round(global_position.y - 0.55))
	var cell := int(t_node.get_map3dnum(bx, by, bz))
	var below := int(t_node.get_map3dnum(bx, by - 1, bz))
	if cell == 1 or below == 1:
		if _has_land_position:
			global_position = _last_land_position
		else:
			global_position = safe_respawn_position + Vector3(0, 2.0, 0)
		velocity = Vector3.ZERO
		return
	if is_on_floor():
		_last_land_position = global_position
		_has_land_position = true

func _toggle_camera_mode() -> void:
	if isbattle:
		return
	camera_mode = 1 - camera_mode
	if camera == null:
		return
	if camera_mode == 1:
		camera.position = Vector3(0, 2.35, 4.6)
		camera.rotation.x = -0.12
	else:
		camera.position = _first_person_camera_pos
		camera.rotation.x = 0.0
	if player_model_root:
		player_model_root.visible = camera_mode == 1
	print("Camera mode: ", "THIRD" if camera_mode == 1 else "FIRST")

func _update_player_model(delta: float) -> void:
	if player_model_root == null or not is_instance_valid(player_model_root):
		return
	if isbattle:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var on_floor := is_on_floor()
	var target_pos := Vector3.ZERO
	var target_rot := Vector3.ZERO
	var target_scale := Vector3.ONE
	if not on_floor:
		# ジャンプ中: 少し前傾＋縦に伸ばす。
		target_rot.x = -0.22
		target_scale = Vector3(0.96, 1.08, 0.96)
		target_pos.y = 0.05
	elif horizontal_speed > 0.5:
		_procedural_walk_time += delta * (6.0 + horizontal_speed * 0.7)
		target_pos.y = absf(sin(_procedural_walk_time)) * 0.10
		target_rot.z = sin(_procedural_walk_time) * 0.06
		target_rot.x = -0.05
	else:
		_procedural_walk_time += delta * 2.0
		target_pos.y = sin(_procedural_walk_time) * 0.025
	player_model_root.position = player_model_root.position.lerp(target_pos, minf(1.0, delta * 12.0))
	player_model_root.rotation = player_model_root.rotation.lerp(target_rot, minf(1.0, delta * 12.0))
	player_model_root.scale = player_model_root.scale.lerp(target_scale, minf(1.0, delta * 10.0))

func _try_step_up(movement_dir: Vector3) -> void:
	if not is_on_floor() or movement_dir.length_squared() < 0.01:
		return

	var step_height: float = 1.15
	var step_offset: Vector3 = movement_dir.normalized() * 0.35

	# 1. 頭上に障害物がないか
	if test_move(global_transform, Vector3(0, step_height, 0)):
		return

	# 2. 上の位置から前方に進めるか
	var up_xform = global_transform.translated(Vector3(0, step_height, 0))
	if test_move(up_xform, step_offset):
		return

	# 3. 前方の位置から下向きに床（足場）があるか
	var fwd_xform = up_xform.translated(step_offset)
	if not test_move(fwd_xform, Vector3(0, -step_height, 0)):
		return

	# 高さ1の段差をスムーズに乗り越える
	global_position.y += 1.05
	global_position += step_offset * 0.5

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity / 1000.0)
		if camera:
			camera.rotate_x(-event.relative.y * mouse_sensitivity / 1000.0)
			camera.rotation.x = clampf(camera.rotation.x, -deg_to_rad(70), deg_to_rad(70))

	# マウスクリックでキャプチャ復帰（UI非表示時）
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			var main_node = get_parent()
			var ui_open = false
			if main_node:
				if ("isshoping" in main_node and main_node.isshoping):
					ui_open = true
				var pm = main_node.get_node_or_null("PauseMenu")
				if pm and pm.visible:
					ui_open = true
			if not ui_open and not isbattle:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			var map_rect = get_node_or_null("../CanvasLayer/map/TextureRect")
			if map_rect:
				map_rect.visible = !map_rect.visible

		elif event.keycode == KEY_V:
			_toggle_camera_mode()

		elif event.keycode == KEY_ESCAPE:
			var main_node = get_parent()
			if main_node and main_node.has_method("toggle_pause_menu"):
				main_node.toggle_pause_menu()
			elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_terrain_map_ready():
	gravity = 9.8
