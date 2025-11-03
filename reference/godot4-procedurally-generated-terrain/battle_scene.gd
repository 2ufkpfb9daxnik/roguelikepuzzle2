extends Node3D

# ===============================
#      ノード参照
# ===============================
@onready var battlefield = $BattleField
@onready var enemies_root = $BattleField/EnemiesRoot
@onready var ui_root = $UI
@onready var fade_manager = $FadeManager

# ===============================
#      データ
# ===============================
var biome_type: int
var encountered_enemy_name: String
var enemy_data: Dictionary = {}  # 例: {"Goblin": {"idle": [...], "attack": [...], ...}}
var stage_enemy: Dictionary = {} # 例: {0: ["Goblin","Orc"], 1: ["Bat","Slime"]}

# ===============================
#      初期化
# ===============================
func _ready():
	await fade_manager.fade_in(1.0)
	_init_field()
	_spawn_enemies()

func set_battle_info(biome: int, enemy_name: String) -> void:
	biome_type = biome
	encountered_enemy_name = enemy_name

func _init_field():
	# 地形や背景を設定
	print("Battle field initialized for biome:", biome_type)

# ===============================
#      敵生成
# ===============================
func _spawn_enemies():
	var enemies_to_spawn: Array = []

	# 接触した敵は必ず出現
	enemies_to_spawn.append(encountered_enemy_name)

	# 追加でランダムに生成（1体以上になるよう調整）
	var available_enemies = stage_enemy.get(biome_type, [])
	for e_name in available_enemies:
		if e_name != encountered_enemy_name and randi() % 2 == 0:
			enemies_to_spawn.append(e_name)

	var count = enemies_to_spawn.size()
	var spacing = 3.0
	var start_x = -spacing * (count - 1) / 2.0

	for i in range(count):
		var enemy_name = enemies_to_spawn[i]
		var enemy_scene_path = _get_random_idle_animation_path(enemy_name)
		var enemy_scene = load(enemy_scene_path)
		var enemy_instance = null
		if enemy_scene is PackedScene:
			enemy_instance = enemy_scene.instantiate()
		else:
			enemy_instance = Node3D.new() # 仮のフォールバック
		enemy_instance.position = Vector3(start_x + i * spacing, 0, 0)
		enemies_root.add_child(enemy_instance)

# ===============================
#      アニメーション選択
# ===============================
func _get_random_idle_animation_path(enemy_name: String) -> String:
	var anim_options = [
		"res://model/enemy/%s/Animation_Alert_withSkin.glb" % enemy_name,
		"res://model/enemy/%s/Animation_All_Night_Dance_withSkin.glb" % enemy_name,
		"res://model/enemy/%s/Animation_Boom_Dance_withSkin.glb" % enemy_name
	]
	var index = randi() % anim_options.size()
	return anim_options[index]

# ===============================
#      画面レイアウト（仮）
# ===============================
func _setup_ui():
	# 中央に味方情報、下部にパズル表示
	# 実際にはControlノードやViewportでUIを配置
	pass

# ===============================
#      バトル開始
# ===============================
func start_battle():
	# 必要に応じてBGMやカメラを切り替え
	_setup_ui()
	print("Battle started with", enemies_root.get_child_count(), "enemies")
