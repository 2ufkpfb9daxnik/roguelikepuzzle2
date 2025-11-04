extends Node3D

# ===============================
#      ノード参照
# ===============================
@onready var battlefield = $BattleField
@onready var enemies_root = $BattleField/EnemiesRoot
@onready var ui_root = $UI
@onready var fade_manager = $FadeManager
@onready var battle_camera = $Camera3D

var main_world_env: WorldEnvironment
var spawned_enemies: Array = []  # 既に生成された敵を管理

# ===============================
#      データ
# ===============================
var biome_type: int
var encountered_enemy_name: String
var stage_enemy: Dictionary = {} # 例: {0: ["Goblin","Orc"], 1: ["Bat","Slime"]}

var plane_battle_pos: Vector3
var cave_battle_pos: Vector3
var desert_battle_pos: Vector3
var snow_battle_pos: Vector3

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
			print(e)
			e.queue_free()
	existing_enemies.clear()
	spawned_enemies.clear()

	# プレイヤーをバトル位置に移動
	battle_camera.rotation = Vector3(deg_to_rad(-10),deg_to_rad(270),deg_to_rad(0))
	battle_camera.position = Vector3(0,3,5)
	player.global_position = Vector3(0,0,5)
	if biome_type == 0:
		player.global_position += plane_battle_pos
		battle_camera.position += plane_battle_pos
	elif biome_type == 1:
		player.global_position += cave_battle_pos
		battle_camera.position += cave_battle_pos
	elif biome_type == 2:
		player.global_position += desert_battle_pos
		battle_camera.position += desert_battle_pos
	elif biome_type == 3:
		player.global_position += snow_battle_pos
		battle_camera.position += snow_battle_pos
	
	# 接触した敵＋ランダム0～2体を生成
	var enemies_to_spawn = [touched_enemy.name]
	var available_enemies = stage_enemy.get(biome_type, [])
	available_enemies.shuffle()
	for e_name in available_enemies:
		if e_name != touched_enemy.name and enemies_to_spawn.size() < 3:
			if randi() % 2 == 0:
				enemies_to_spawn.append(e_name)

	# 敵を生成して BattleIdle に設定
	var spacing = 3.0
	for i in range(enemies_to_spawn.size()):
		var name = enemies_to_spawn[i]
		var path = "res://model/enemy/have_animation/%s/Animation_Alert_withSkin.glb" % name
		var scene = load(path)
		var inst: Node3D = Node3D.new()
		if scene is PackedScene:
			inst = scene.instantiate()
		if biome_type == 0:
			inst.position = Vector3(plane_battle_pos.x+5,plane_battle_pos.y+1,plane_battle_pos.z+i*spacing+2)
		elif biome_type == 1:
			inst.position = Vector3(cave_battle_pos.x+5,cave_battle_pos.y+1,cave_battle_pos.z+i*spacing+2)
		elif biome_type == 2:
			inst.position = Vector3(desert_battle_pos.x+5,desert_battle_pos.y+1,desert_battle_pos.z+i*spacing+2)
		elif biome_type == 3:
			inst.position = Vector3(snow_battle_pos.x+5,snow_battle_pos.y+1,snow_battle_pos.z+i*spacing+2)
		enemies_root.add_child(inst)
		spawned_enemies.append(inst)
		# State を BattleIdle にする
		if inst.has_method("set_state"):
			inst.set_state("BATTLE_IDLE")

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
