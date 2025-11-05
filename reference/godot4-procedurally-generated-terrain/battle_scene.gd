extends Control

# ===============================
#      ノード参照
# ===============================
@onready var battlefield = $Battle3DViewport
@onready var enemies_root = $Battle3DViewport/SubViewport/Enemies
@onready var ui_root = $UI
@onready var fade_manager = $FadeManager
@onready var battle_camera = $Battle3DViewport/SubViewport/Camera3D

var main_world_env: WorldEnvironment
var spawned_enemies: Array = []  # 既に生成された敵を管理

# ===============================
#      データ
# ===============================
var biome_type: int
var encountered_enemy_name: String
var stage_enemy = [[],[],[],[],[]] 
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

var plane_battle_pos: Vector3
var cave_battle_pos: Vector3
var desert_battle_pos: Vector3
var snow_battle_pos: Vector3
var enemy_data
var charactercamera: Camera3D
# ===============================
#      初期化
# ===============================
func _ready():
	battle_camera.current = true
	if main_world_env == null:
		battle_camera.environment = Environment.new()
		battle_camera.environment.background_mode = Environment.BG_COLOR
		battle_camera.environment.background_color = Color(0, 0, 0)
	else:
		battle_camera.environment = main_world_env

# ===============================
#      設定
# ===============================
func set_battle_info(biome: int, enemy_name: String):
	biome_type = biome
	encountered_enemy_name = enemy_name

func set_world_environment(env: WorldEnvironment):
	main_world_env = env

# ===============================
#      バトル準備
# ===============================
func prepare_battle(player: Node3D, touched_enemy: Node3D, existing_enemies: Array):
	# 既存の敵を全削除
	for e in existing_enemies:
		if e and e.is_inside_tree():
			e.queue_free()
	existing_enemies.clear()
	spawned_enemies.clear()

	# プレイヤーをバトル位置に移動
	battle_camera.rotation = Vector3(deg_to_rad(-20),deg_to_rad(270),deg_to_rad(0))
	battle_camera.position = Vector3(4,2,5)
	battle_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.isbattle = true
	player.position.y += 1000
	if biome_type == 0:
		battle_camera.position += plane_battle_pos
	elif biome_type == 1:
		battle_camera.position += cave_battle_pos
	elif biome_type == 2:
		battle_camera.position += desert_battle_pos
	elif biome_type == 3:
		battle_camera.position += snow_battle_pos
	
	# 接触した敵＋ランダム0～2体を生成
	var enemies_to_spawn = [touched_enemy.enemy_name]
	var available_enemies = stage_enemy[biome_type]
	available_enemies.shuffle()
	for e_name in available_enemies:
		print(e_name)
		if e_name != touched_enemy.enemy_name and enemies_to_spawn.size() < 3:
			if randi() % 2 == 0:
				enemies_to_spawn.append(e_name)

	# 敵を生成して BattleIdle に設定
	var spacing = 10/(enemies_to_spawn.size()+1)
	for i in range(enemies_to_spawn.size()):
		var name = enemies_to_spawn[i]
		var path = "res://model/enemy/have_animation/%s/Animation_Alert_withSkin.glb" % name
		var scene = load(path)
		var enemy_instance = CharacterBody3D.new()
		enemy_instance.name = name
		var enemy_script_resource = load("res://enemy.gd")
		if enemy_script_resource is GDScript:
			enemy_instance.set_script(enemy_script_resource)
		else:
			push_error("Failed to load enemy.gd script at res://enemy.gd")
			enemy_instance.queue_free()
			continue
		var enemy_info = enemy_data.get(name)
		var loaded_default_model_scene = load(enemy_info[0])
		var visual_model_root_instance: Node3D = null

		if loaded_default_model_scene is PackedScene:
			visual_model_root_instance = loaded_default_model_scene.instantiate()
		elif loaded_default_model_scene is Mesh:
			var mesh_inst = MeshInstance3D.new()
			mesh_inst.mesh = loaded_default_model_scene
			visual_model_root_instance = mesh_inst
		else:
			push_warning("Unsupported model resource type for default model: " + enemy_info[0])
			enemy_instance.queue_free()
			return
		if visual_model_root_instance:
			visual_model_root_instance.name = "VisualModelRoot" # 後で enemy.gd から参照しやすいように名前を付ける
			enemy_instance.add_child(visual_model_root_instance)
		if biome_type == 0:
			enemy_instance.position = Vector3(plane_battle_pos.x+8,plane_battle_pos.y+0.6,plane_battle_pos.z+(i+1)*spacing)
		elif biome_type == 1:
			enemy_instance.position = Vector3(cave_battle_pos.x+8,cave_battle_pos.y+0.6,cave_battle_pos.z+(i+1)*spacing)
		elif biome_type == 2:
			enemy_instance.position = Vector3(desert_battle_pos.x+8,desert_battle_pos.y+0.6,desert_battle_pos.z+(i+1)*spacing)
		elif biome_type == 3:
			enemy_instance.position = Vector3(snow_battle_pos.x+8,snow_battle_pos.y+0.6,snow_battle_pos.z+(i+1)*spacing)
		enemy_instance.rotation = Vector3(deg_to_rad(0),deg_to_rad(-90),deg_to_rad(0))
		enemy_instance.set_animation_model_paths(enemy_info[1])
		enemy_instance.assign_battle_idle_anim()
		enemy_instance.state = State.BATTLE_IDLE
		if enemy_instance.has_method("adjust_model_to_ground"):
			enemy_instance.adjust_model_to_ground()
		print(name)
		enemies_root.add_child(enemy_instance)
		spawned_enemies.append(enemy_instance)
		charactercamera.current = false
		# State を BattleIdle にする

# ===============================
#      UI 設定
# ===============================
func _setup_ui():
	# 中央に味方情報、下部にパズル表示
	# 実際には Control ノードや Viewport で UI を配置
	pass

# ===============================
#      バトル開始
# ===============================
func start_battle():
	_setup_ui()
	print("Battle started with", enemies_root.get_child_count(), "enemies")

# ===============================
#      バトル終了
# ===============================
func end_battle():
	await fade_manager.fade_out(1.0)
	queue_free()
