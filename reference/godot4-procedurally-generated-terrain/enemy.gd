class_name Enemy
extends UnitBase

# 既存互換用ステート定義 (UnitBase.UnitState と同一)
enum State {
	IDLE = UnitState.IDLE,
	MOVE = UnitState.MOVE,
	DETECT = UnitState.DETECT,
	CHASE = UnitState.CHASE,
	BATTLE_IDLE = UnitState.BATTLE_IDLE,
	BATTLE_MOVE = UnitState.BATTLE_MOVE,
	ATTACK_ALL = UnitState.ATTACK_ALL,
	ATTACK_SINGLE = UnitState.ATTACK_SINGLE,
	DOWN = UnitState.DOWN,
	DEAD = UnitState.DEAD
}

@export var detection_range: float = 12.0
@export var chase_speed_multiplier: float = 2.0
@export var biome_type: int = 0

var player: Node3D = null
var terrain_node: Node3D = null
var main_node: Node = null
var target_time: float = 0.0
var random_direction: Vector3 = Vector3.ZERO
var enemy_name: String = ""

# ビックリマーク
var exclamation_ui: Sprite3D = null
var exclamation_alpha: float = 0.0
var exclamation_rise_height: float = 2.5
var exclamation_time: float = 0.0
var exclamation_duration: float = 2.0

var exclamation_state: String = "hidden"
var is_boss: bool = false



func _ready() -> void:
	if name.ends_with("_Boss"):
		is_boss = true

	_setup_unit_base()

	# main.tscn の空ダミー enemy ノードの安全な除去
	if animation_models.is_empty() and get_parent() and get_parent().name == "main" and name == "enemy":
		queue_free()
		return

	_create_exclamation_icon()

	var detection_area = get_node_or_null("DetectionArea")
	if detection_area and not detection_area.is_connected("body_entered", Callable(self, "_on_body_entered")):
		detection_area.connect("body_entered", Callable(self, "_on_body_entered"))

	main_node = get_parent()
	if main_node:
		player = main_node.get_node_or_null("CharacterBody3D")
		terrain_node = main_node.get_node_or_null("terrain")

	_set_random_idle_duration()
	_play_best_anim(["Idle", "Animation_Idle_withSkin"])

func _physics_process(delta: float) -> void:
	if terrain_node and terrain_node.is_generating:
		velocity = Vector3.ZERO
		return

	# 探索モード時、プレイヤーから一定距離（60m）以上離れたら自動デスポーンして負荷軽減（ボスは除外）
	if player and not is_boss and state <= State.CHASE:
		if global_position.distance_squared_to(player.global_position) > 3600.0:
			queue_free()
			return

	if is_boss:
		# ボスは指定座標で待機（地形チャンク未読み込みによる落下を防ぐ）
		velocity = Vector3.ZERO
		return

	var on_floor = is_on_floor()
	if not on_floor:
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5

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

	if not on_floor or velocity.x != 0.0 or velocity.z != 0.0:
		move_and_slide()

		# 段差（高さ1）の自動踏破（ステップアップ）
		if is_on_wall() and (state == State.MOVE or state == State.CHASE):
			var fwd = Vector3(velocity.x, 0, velocity.z)
			if fwd.length_squared() > 0.01:
				_try_step_up(fwd)

	if exclamation_ui and exclamation_state != "hidden":
		_update_exclamation(delta)

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

func _set_random_idle_duration() -> void:
	target_time = randf_range(2.0, 4.5)

# ===============================
#   探索モード（AI）
# ===============================
func _process_idle(delta: float) -> void:
	if is_boss:
		velocity.x = 0
		velocity.z = 0
		return
	state_timer += delta
	if state_timer >= target_time:
		state = State.MOVE
		_play_best_anim(["Walking", "Walk", "Run"])
		state_timer = 0.0
		target_time = randf_range(1.5, 3.0)
		random_direction = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
		var target_rotation = atan2(random_direction.x, random_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 1.0)
	else:
		if player and global_position.distance_squared_to(player.global_position) <= detection_range * detection_range:
			state = State.DETECT
			_play_detection()

func _process_move(delta: float) -> void:
	if is_boss:
		state = State.IDLE
		return
	if main_node and "isshoping" in main_node and main_node.isshoping:
		return

	state_timer += delta
	var forward = Vector3(sin(rotation.y), 0, cos(rotation.y))
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed

	if state_timer >= target_time:
		state = State.IDLE
		_play_best_anim(["Idle", "Animation_Idle_withSkin"])
		velocity.x = 0.0
		velocity.z = 0.0
		state_timer = 0.0
		_set_random_idle_duration()
	elif player and global_position.distance_squared_to(player.global_position) <= detection_range * detection_range:
		state = State.DETECT
		_play_detection()

func _process_detect(delta: float) -> void:
	if is_boss:
		state = State.IDLE
		return
	if main_node and "isshoping" in main_node and main_node.isshoping:
		return

	exclamation_time += delta
	if exclamation_time >= exclamation_duration:
		state = State.CHASE
		_play_best_anim(["RunFast", "Running", "Run", "Walking"])

func _process_chase(delta: float) -> void:
	if is_boss:
		state = State.IDLE
		return
	if main_node and "isshoping" in main_node and main_node.isshoping:
		return
	if not player:
		return

	var dir = (player.global_position - global_position).normalized()
	var target_rot = atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_rot, delta * 5.0)
	var forward = Vector3(sin(rotation.y), 0, cos(rotation.y))
	velocity.x = forward.x * speed * chase_speed_multiplier
	velocity.z = forward.z * speed * chase_speed_multiplier

	var lose_dist = detection_range * 1.5
	if global_position.distance_squared_to(player.global_position) > lose_dist * lose_dist:
		state = State.IDLE
		velocity.x = 0.0
		velocity.z = 0.0
		_play_best_anim(["Idle", "Animation_Idle_withSkin"])

# ===============================
#   バトルモード
# ===============================
func _process_battle_idle(_delta: float) -> void:
	if isanim:
		return
	isanim = true
	_play_best_anim([])

func _process_battle_move(_delta: float) -> void:
	if isanim:
		return
	isanim = true
	_play_best_anim(["Running", "Run", "Walking"])

func _process_attack_all(_delta: float) -> void:
	if isanim:
		return
	isanim = true
	_play_best_anim(["Skill_01", "Attack", "Boxing"])

func _process_attack_single(_delta: float) -> void:
	if isanim:
		return
	isanim = true
	_play_best_anim(["Skill_03", "Attack", "Triple"])

func _process_down(delta: float) -> void:
	state_timer += delta
	if state_timer >= 1.0 and state_timer < 2.0:
		if not isanim:
			isanim = true
			_play_best_anim(["Arise", "Idle"])
	elif state_timer >= 2.0:
		state_timer = 0.0
		isanim = false
		state = State.BATTLE_IDLE

func _play_best_anim(preferred_names: Array) -> void:
	# 1. 完全一致
	for anim in preferred_names:
		if animation_models.has(anim):
			play_unit_animation(anim)
			return

	# 2. キーワードによる部分一致検索
	for anim in preferred_names:
		var l_kw = anim.to_lower()
		for k in animation_models.keys():
			var l_k = k.to_lower()
			if l_kw in l_k or l_k in l_kw:
				play_unit_animation(k)
				return

	# 3. フォールバック
	if battle_idle_anim != "" and animation_models.has(battle_idle_anim):
		play_unit_animation(battle_idle_anim)
	elif animation_models.size() > 0:
		play_unit_animation(animation_models.keys()[0])

# 既存コードとの互換メソッド
func receive_damage(amount: int) -> void:
	take_damage(amount)

# ===============================
#   ビックリマーク処理
# ===============================
func _create_exclamation_icon() -> void:
	var tex_path = "res://ui/exclamation_icon.png"
	if not ResourceLoader.exists(tex_path):
		return
	exclamation_ui = Sprite3D.new()
	exclamation_ui.texture = load(tex_path)
	exclamation_ui.modulate.a = 0.0
	exclamation_ui.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	exclamation_ui.scale = Vector3(0.5, 0.5, 0.5)
	exclamation_ui.position = Vector3(0, 1.5, 0)
	add_child(exclamation_ui)
	exclamation_state = "hidden"

func _play_detection() -> void:
	if not exclamation_ui:
		return
	exclamation_state = "fade_in"
	exclamation_alpha = 0.0
	exclamation_ui.position = Vector3(0, 0.5, 0)
	exclamation_time = 0.0
	if animation_player:
		animation_player.stop()
	velocity = Vector3.ZERO

func _update_exclamation(delta: float) -> void:
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
#   接触 -> 戦闘遷移
# ===============================
func _on_body_entered(body: Node3D) -> void:
	if body and body.name == "CharacterBody3D":
		var parent = main_node if main_node else get_parent()
		if parent:
			var t_node = terrain_node if terrain_node else parent.get_node_or_null("terrain")
			if t_node and "is_generating" in t_node and t_node.is_generating:
				return
			var player_node = player if player else parent.get_node_or_null("CharacterBody3D")
			if player_node and "isbattle" in player_node and player_node.isbattle:
				return
			if parent.has_node("battle_scene"):
				return
		print("Player touched enemy in biome:", biome_type)
		await _transition_to_battle(biome_type, enemy_name)

func _transition_to_battle(biome: int, encountered_enemy: String) -> void:
	var parent = main_node if main_node else get_parent()
	if not parent:
		return
	if "isshoping" in parent and parent.isshoping:
		return

	var t_node = terrain_node if terrain_node else parent.get_node_or_null("terrain")
	if t_node and "is_generating" in t_node and t_node.is_generating:
		return

	var player_node = player if player else parent.get_node_or_null("CharacterBody3D")
	if player_node and "isbattle" in player_node and player_node.isbattle:
		return

	if parent.has_node("battle_scene"):
		return

	var battle_scene_res = load("res://battle_scene.tscn")
	if not battle_scene_res:
		push_warning("Battle scene not found!")
		return

	var battle_scene = battle_scene_res.instantiate()
	battle_scene.set_battle_info(biome, encountered_enemy)

	if parent:
		var spawn_node = parent.get_node_or_null("spawn_enemy")
		if spawn_node:
			battle_scene.enemy_data = spawn_node.enemy_data
			battle_scene.stage_enemy = spawn_node.stage_enemy

		if t_node:
			battle_scene.plane_battle_pos = t_node.plane_battle_pos
			battle_scene.cave_battle_pos = t_node.cave_battle_pos
			battle_scene.desert_battle_pos = t_node.desert_battle_pos
			battle_scene.snow_battle_pos = t_node.snow_battle_pos

		battle_scene.charactercamera = parent.get_node_or_null("CharacterBody3D/Camera3D")

		var main_env = parent.get_node_or_null("WorldEnvironment")
		if main_env:
			battle_scene.set_world_environment(main_env)

		parent.add_child(battle_scene)
		await get_tree().process_frame

		if not player_node:
			player_node = parent.get_node_or_null("CharacterBody3D")
		var existing_enemies: Array = []
		if spawn_node:
			existing_enemies = spawn_node.spawned_enemies
		var spawned_allies = parent.generate_allies_to_spawn() if parent.has_method("generate_allies_to_spawn") else []
		battle_scene.prepare_battle(player_node, self, existing_enemies, spawned_allies)
		battle_scene.start_battle()
