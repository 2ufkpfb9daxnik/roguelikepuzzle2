extends CharacterBody3D

# ===== 状態管理 =====
enum State {
	IDLE,
	MOVE,
	DETECT,
	CHASE,
	BATTLE_IDLE,
	BATTLE_MOVE,
	ATTACK_PREPARE,
	ATTACK_ALL,
	ATTACK_SINGLE,
	DOWN,
	DEAD
}

@onready var detection_area = $DetectionArea
@export var health: int = 100
@export var attack: int = 10
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
var enemy_name: String = ""

# アニメーション関連
var animation_model_paths: Array = []        # spawn_enemy から渡される GLB パス配列
var animation_models: Dictionary = {}        # anim_name -> path （basename をキーにする）
var loaded_models: Dictionary = {}           # anim_name -> instantiated Node (GLB のルート)
var animation_player: AnimationPlayer = null
var current_animation_name: String = ""
var current_visual_model_root: Node3D = null
var battle_idle_anim
var isanim = false
# ビックリマーク
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
	# Detection area の signal を接続（存在チェック）
	if detection_area:
		# Godot4 の場合 .body_entered は Signal の名前。接続時は `connect` を使う。
		if not detection_area.is_connected("body_entered", Callable(self, "_on_body_entered")):
			detection_area.connect("body_entered", Callable(self, "_on_body_entered"))

	_create_collision_shape()
	_setup_visual_model()
	_create_exclamation_icon()
	
	var parent = get_parent()
	if parent:
		player = parent.get_node_or_null("CharacterBody3D")

	_set_random_idle_duration()
func assign_battle_idle_anim():
	var idle_anim = []
	print(animation_models.keys())
	for key in animation_models.keys():
		if key == "Animation_Alert_withSkin":
			idle_anim.append("Animation_Alert_withSkin")
		if key == "Animation_All_Night_Dance_withSkin":
			idle_anim.append("Animation_All_Night_Dance_withSkin")
		if key == "Animation_Boom_Dance_withSkin":
			idle_anim.append("Animation_Boom_Dance_withSkin")
	if idle_anim.size() > 0:
		battle_idle_anim = idle_anim.pick_random()
func _physics_process(delta):
	# 重力処理
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

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
	if get_node_or_null("CollisionShape3D"):
		return
	var new_collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 1.0
	shape.height = 1.0
	new_collision.shape = shape
	add_child(new_collision)

# spawn_enemy から GLB パス配列を受け取る
func set_animation_model_paths(paths: Array) -> void:
	animation_model_paths = paths.duplicate()
	animation_models.clear()
	for p in animation_model_paths:
		# p は "res://.../Animation_Idle_withSkin.glb" のような文字列を期待
		if typeof(p) != TYPE_STRING:
			continue
		var fname = p.get_file().get_basename() # "Animation_Idle_withSkin"
		animation_models[fname] = p

func _setup_visual_model():
	current_visual_model_root = get_node_or_null("VisualModelRoot")
	if not current_visual_model_root:
		push_warning("VisualModelRoot not found in enemy '" + str(enemy_name) + "'. Make sure spawn_enemy added VisualModelRoot.")
		return
	# 少し持ち上げて地中に埋まらないように
	current_visual_model_root.position.y = -0.4

func _set_random_idle_duration():
	target_time = randf_range(2.0, 4.5)

# ===============================
#   探索モード（簡易）
# ===============================
func _process_idle(delta):
	state_timer += delta
	if state_timer >= target_time:
		state = State.MOVE
		_play_animation("Animation_Walking_withSkin")
		state_timer = 0.0
		target_time = randf_range(1.5, 3.0)
		random_direction = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
		var target_rotation = atan2(random_direction.x, random_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 1.0)
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
		velocity.x = 0.0
		velocity.z = 0.0
		state_timer = 0.0
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
	var target_rot = atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_rot, delta * 5.0)
	var forward = Vector3(sin(rotation.y), 0, cos(rotation.y))
	velocity.x = forward.x * speed * chase_speed_multiplier
	velocity.z = forward.z * speed * chase_speed_multiplier

	if global_position.distance_to(player.global_position) > detection_range * 1.5:
		state = State.IDLE
		_play_animation("Animation_Idle_withSkin")

# ===============================
#   バトルモード（IDLEでランダムにループ）
# ===============================
func _process_battle_idle(delta):
	# animation_player があればそれのアニメ数を使う
	if isanim:
		return
	else:
		isanim = true
		if battle_idle_anim != null:
			_play_animation(battle_idle_anim)
func _process_battle_move(delta):
	# animation_player があればそれのアニメ数を使う
	if isanim:
		return
	_play_animation("Animation_Idle_withSkin")
func start_attack():
	state = State.ATTACK_PREPARE
	_play_animation("Animation_Boxing_Practice_withSkin")

func _process_attack_prepare(delta):
	# 攻撃モーションが終わったら次の攻撃へ
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

func receive_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		_transition_to_dead()
	else:
		_transition_to_down()

func _transition_to_dead() -> void:
	state = State.DEAD
	_play_animation("Animation_Dead_withSkin")
	await get_tree().create_timer(2.0).timeout
	queue_free()

func _transition_to_down() -> void:
	state = State.DOWN
	_play_animation("Animation_BeHit_FlyUp_withSkin",false)
	# animation_player があるなら完了を待つ
	if animation_player:
		await animation_player.animation_finished
	_play_animation("Animation_Arise_withSkin",false)
	if animation_player:
		await animation_player.animation_finished
	state = State.BATTLE_IDLE
	print("a")
# ===============================
#   アニメーション再生（GLB 分割アニメ対応）
# ===============================
func _play_animation(anim_name: String,isloop: bool = true) -> void:
	if not animation_models.has(anim_name):
		push_warning("❌ Animation not found in dictionary: " + anim_name)
		return

	# ====== ✅ まず、VisualModelRoot の中を完全クリーンにする ======
	if current_visual_model_root:
		for child in current_visual_model_root.get_children():
			child.queue_free()
		await get_tree().process_frame  # queue_free の反映を待つ
	else:
		push_warning("❌ VisualModelRoot is missing.")
		return

	# ====== GLBロード ======
	var model_path = animation_models[anim_name]
	if not ResourceLoader.exists(model_path):
		push_warning("❌ GLB not found at path: " + model_path)
		return

	var scene_res = load(model_path)
	if not scene_res or not (scene_res is PackedScene):
		push_warning("❌ Failed to load GLB at: " + model_path)
		return

	var inst = scene_res.instantiate()
	current_visual_model_root.add_child(inst)
	inst.visible = true
	loaded_models.clear()
	loaded_models[anim_name] = inst

	# ====== アニメーションプレイヤー取得 ======
	var ap: AnimationPlayer = inst.get_node_or_null("AnimationPlayer")
	if not ap:
		ap = inst.find_child("AnimationPlayer", true, false)
	if not ap:
		push_warning("❌ No AnimationPlayer found inside: " + anim_name)
		return

	# ====== 再生準備 ======
	var play_name = anim_name
	var ap_anims = ap.get_animation_list()
	if not (anim_name in ap_anims):
		if ap_anims.size() > 0:
			play_name = ap_anims[0]
		else:
			push_warning("❌ No animations found in GLB: " + model_path)
			return

	# ====== 再生 ======
	ap.play(play_name)
	var anim_res = ap.get_animation(play_name)
	if anim_res:
		if "loop" in anim_res:
			anim_res.loop = isloop

	animation_player = ap
	current_animation_name = play_name



# ===============================
#   アニメーション停止（全て）
# ===============================
func _stop_all_animations() -> void:
	if not current_visual_model_root:
		return
	for child in current_visual_model_root.get_children():
		# child が複数 GLB の root である想定
		if child is Node:
			var ap = child.get_node_or_null("AnimationPlayer")
			if not ap:
				ap = child.find_child("AnimationPlayer", true, false)
			if ap:
				ap.stop()

# ===============================
#   ビックリマーク処理
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
#   接触 -> 戦闘遷移
# ===============================
func _on_body_entered(body):
	# Player 側のノード名が実際に "CharacterBody3D" なら OK。違うなら body.is_in_group("player") 等を使う。
	if body and body.name == "CharacterBody3D":
		print("Player touched enemy in biome:", biome_type)
		await _transition_to_battle(biome_type, enemy_name)
	get_parent().get_node("spawn_enemy").delete_enemy
func _transition_to_battle(biome: int, encountered_enemy: String):
	var battle_scene = preload("res://battle_scene.tscn").instantiate()
	if not battle_scene:
		push_warning("Battle scene not found!")
		return
	battle_scene.set_battle_info(biome, encountered_enemy)
	# 必要な情報を渡す（spawn_enemy などが持つ構造を前提）
	var parent = get_parent()
	if parent:
		var spawn_node = parent.get_node_or_null("spawn_enemy")
		if spawn_node:
			battle_scene.enemy_data = spawn_node.enemy_data
			battle_scene.stage_enemy = spawn_node.stage_enemy
	battle_scene.plane_battle_pos = parent.get_node("terrain").plane_battle_pos if parent else Vector3.ZERO
	battle_scene.cave_battle_pos = parent.get_node("terrain").cave_battle_pos if parent else Vector3.ZERO
	battle_scene.desert_battle_pos = parent.get_node("terrain").desert_battle_pos if parent else Vector3.ZERO
	battle_scene.snow_battle_pos = parent.get_node("terrain").snow_battle_pos if parent else Vector3.ZERO
	battle_scene.charactercamera = parent.get_node("CharacterBody3D/Camera3D")
	var main_env = parent.get_node_or_null("WorldEnvironment") if parent else null
	if main_env:
		battle_scene.set_world_environment(main_env)

	# シーン追加してフレーム待ち（準備のため）
	get_parent().add_child(battle_scene)
	await get_tree().process_frame

	# プレイヤーノードと既存敵を渡して準備開始
	var player_node = parent.get_node_or_null("CharacterBody3D") if parent else null
	var existing_enemies: Array = get_parent().get_node("spawn_enemy").spawned_enemies
	battle_scene.prepare_battle(player_node, self, existing_enemies)
	battle_scene.start_battle()
