extends Control

# ===============================
#      ノード参照
# ===============================
@onready var ally_viewport = $AllyViewport/SubViewport
@onready var enemy_viewport = $EnemyViewport/SubViewport
@onready var ally_camera = $AllyViewport/SubViewport/AllyCamera
@onready var enemy_camera = $EnemyViewport/SubViewport/EnemyCamera
@onready var enemies_root = $EnemyViewport/SubViewport/Enemies
@onready var allies_root = $AllyViewport/SubViewport/Allies
@onready var ui_root = $UI
@onready var fade_manager = $FadeManager
@onready var puzzle_board = $UI/PuzzleBoard
@onready var battle_start_label = $UI/Battle_Start
@onready var your_turn_label = $UI/YourTurn
@onready var enemy_turn_label = $UI/EnemyTurn
@onready var victory_label = $UI/Victory
var main_world_env: WorldEnvironment
var spawned_enemies: Array = [] 
var enemies_start_pos: Array = []
var spawned_allies: Array = []
var allies_start_pos: Array = []
var player_ref: Node3D = null
var field_camera: Camera3D = null
var player_original_position: Vector3
var camera_original_transform: Transform3D
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
	BATTLE_MOVE,
	ATTACK_ALL,
	ATTACK_SINGLE,
	DOWN,
	DEAD
}
enum State1 {
	BATTLE_IDLE,
	BATTLE_MOVE,
	ATTACK_ALL,
	ATTACK_SINGLE,
	DOWN,
	DEAD
}
enum BattleState {
	INTRO,			 
	PLAYER_TURN_START, 
	PLAYER_TURN,	   
	PLAYER_ATTACK,	
	ENEMY_TURN_START,  
	ENEMY_TURN,		
	VICTORY,		   
	DEFEAT			 
}
var battle_state = BattleState.INTRO
var plane_battle_pos: Vector3
var cave_battle_pos: Vector3
var desert_battle_pos: Vector3
var snow_battle_pos: Vector3
var enemy_data
var charactercamera: Camera3D
var score
# ===============================
#      初期化
# ===============================
func _ready():
	puzzle_board.battle_state_requested.connect(_on_battle_state_requested)
	if main_world_env == null:
		ally_camera.environment = Environment.new()
		ally_camera.environment.background_mode = Environment.BG_COLOR
		ally_camera.environment.background_color = Color(0, 0, 0)
		enemy_camera.environment = Environment.new()
		enemy_camera.environment.background_mode = Environment.BG_COLOR
		enemy_camera.environment.background_color = Color(0, 0, 0)
	else:
		ally_camera.environment = main_world_env
		enemy_camera.environment = main_world_env
	
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
func _on_battle_state_requested(newscore:Array,newstate:State):
	score = newscore.duplicate(true)
	battle_state =  newstate
	print("get")
	_process_battle_state()
func prepare_battle(player: Node3D, touched_enemy: Node3D, existing_enemies: Array):
	print("prepare_battle called")
	player_ref = player
	player_original_position = player.global_position
	# 探索時カメラの参照を取得して記録
	field_camera = player.get_node("Camera3D")
	if field_camera:
		camera_original_transform = field_camera.global_transform
		field_camera.current = false
	# 既存の敵を全削除
	for e in existing_enemies:
		if e and e.is_inside_tree():
			e.queue_free()
	existing_enemies.clear()
	spawned_enemies.clear()
	enemy_camera.rotation = Vector3(deg_to_rad(-20),deg_to_rad(270),deg_to_rad(0))
	enemy_camera.position = Vector3(4,4,4)
	enemy_camera.current = true
	ally_camera.rotation = Vector3(deg_to_rad(-20),deg_to_rad(90),deg_to_rad(0))
	ally_camera.position = Vector3(6,4,4)
	ally_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.isbattle = true
	player.position.y += 1000
	if biome_type == 0:
		ally_camera.position += plane_battle_pos
		enemy_camera.position += plane_battle_pos
	elif biome_type == 1:
		ally_camera.position += cave_battle_pos
		enemy_camera.position += cave_battle_pos
	elif biome_type == 2:
		ally_camera.position += desert_battle_pos
		enemy_camera.position += desert_battle_pos
	elif biome_type == 3:
		ally_camera.position += snow_battle_pos
		enemy_camera.position += snow_battle_pos
	spawned_allies.clear()
	var allies_to_spawn = [
		{"name": "hero1", "path": "res://model/enemy/have_animation/red_magician/", "type": 4, "attack": 20},
		{"name": "hero2", "path": "res://model/enemy/have_animation/mushroom_man/", "type": 4, "attack": 20},
		{"name": "hero3", "path": "res://model/enemy/have_animation/kurione/", "type": 4, "attack": 20}
	]
	var spacing1 = 10/(allies_to_spawn.size()+1)
	for i in range(allies_to_spawn.size()):
		var info = allies_to_spawn[i]
		var ally_instance = CharacterBody3D.new()
		ally_instance.name = info.name
		
		var ally_script = load("res://ally.gd")
		if ally_script is GDScript:
			ally_instance.set_script(ally_script)
		else:
			push_error("Failed to load ally.gd")
			continue 
		var dir = DirAccess.open(info.path)
		var model_paths: Dictionary = {}
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".glb"):
					var full_path = info.path + file_name
					model_paths[file_name.get_basename()] = full_path
				file_name = dir.get_next()
			dir.list_dir_end()
		else:
			push_error("Failed to open ally dir: " + info.path)
		ally_instance.set_animation_model_paths(model_paths)
		if model_paths.size() > 0:
			var first_path = model_paths.values()[0]
			var scene_res = load(first_path)
			if scene_res is PackedScene:
				var visual = scene_res.instantiate()
				visual.name = "VisualModelRoot"
				ally_instance.add_child(visual)
				var anim_player = visual.get_node_or_null("AnimationPlayer")
				if anim_player:
					var anims = anim_player.get_animation_list()
					if anims.size() > 0:
						anim_player.play(anims[randi() % anims.size()])
		ally_instance.type = info.type
		print("ally_type:",ally_instance.type)
		ally_instance.attack = info.attack
		ally_instance.hp = 100
		ally_instance.max_hp = 100
		ally_instance.state = State.BATTLE_IDLE
		if biome_type == 0:
			ally_instance.position = Vector3(plane_battle_pos.x+1,plane_battle_pos.y+0.6,plane_battle_pos.z+(i+1)*spacing1)
		elif biome_type == 1:
			ally_instance.position = Vector3(cave_battle_pos.x+1,cave_battle_pos.y+0.6,cave_battle_pos.z+(i+1)*spacing1)
		elif biome_type == 2:
			ally_instance.position = Vector3(desert_battle_pos.x+1,desert_battle_pos.y+0.6,desert_battle_pos.z+(i+1)*spacing1)
		elif biome_type == 3:
			ally_instance.position = Vector3(snow_battle_pos.x+1,snow_battle_pos.y+0.6,snow_battle_pos.z+(i+1)*spacing1)
		ally_instance.rotation = Vector3(0, deg_to_rad(90), 0)
		allies_root.add_child(ally_instance)
		spawned_allies.append(ally_instance)
		allies_start_pos.append(ally_instance.position)
		ally_instance.hp_camera = ally_camera
	# 接触した敵＋ランダム0～2体を生成
	var enemies_to_spawn = [touched_enemy.enemy_name]
	var available_enemies = stage_enemy[biome_type]
	available_enemies.shuffle()
	for e_name in available_enemies:
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
			enemy_instance.position = Vector3(plane_battle_pos.x+9,plane_battle_pos.y+0.6,plane_battle_pos.z+(i+1)*spacing)
		elif biome_type == 1:
			enemy_instance.position = Vector3(cave_battle_pos.x+9,cave_battle_pos.y+0.6,cave_battle_pos.z+(i+1)*spacing)
		elif biome_type == 2:
			enemy_instance.position = Vector3(desert_battle_pos.x+9,desert_battle_pos.y+0.6,desert_battle_pos.z+(i+1)*spacing)
		elif biome_type == 3:
			enemy_instance.position = Vector3(snow_battle_pos.x+9,snow_battle_pos.y+0.6,snow_battle_pos.z+(i+1)*spacing)
		enemy_instance.rotation = Vector3(deg_to_rad(0),deg_to_rad(-90),deg_to_rad(0))
		enemy_instance.set_animation_model_paths(enemy_info[1])
		enemy_instance.assign_battle_idle_anim()
		enemy_instance.state = State.BATTLE_IDLE
		if enemy_instance.has_method("adjust_model_to_ground"):
			enemy_instance.adjust_model_to_ground()
		enemies_root.add_child(enemy_instance)
		spawned_enemies.append(enemy_instance)
		enemies_start_pos.append(enemy_instance.position)
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
	battle_state = BattleState.INTRO
	_process_battle_state()

# ===============================
#      バトル終了
# ===============================
func end_battle():
	await fade_manager.fade_in(1.0)
	if player_ref:
		player_ref.global_position = player_original_position
		player_ref.isbattle = false

	# カメラ復帰
	if field_camera:
		field_camera.global_transform = camera_original_transform
		field_camera.current = true  # 再び探索カメラを有効化

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# バトルシーン削除
	queue_free()
# --- バトルステートマシン本体 ---
func _process_battle_state():
	match battle_state:
		BattleState.INTRO:
			print("INTRO")
			await _show_label(battle_start_label, 1.0)
			# 次のステートへ
			battle_state = BattleState.PLAYER_TURN_START
			_process_battle_state()

		BattleState.PLAYER_TURN_START:
			print("PLAYER_TURN_START")
			# "Your Turn" UI表示
			await _show_label(your_turn_label, 1.0)
			puzzle_board.canmove = true
			# 次のステートへ
			battle_state = BattleState.PLAYER_TURN
			_process_battle_state()

		BattleState.PLAYER_TURN:
			print("PLAYER_TURN")
			# パズルボードの操作を許可
			
			puzzle_board.canmove = true
			# ここでステートは待機。_on_puzzle_complete シグナルで次に進む

		BattleState.PLAYER_ATTACK:
			print("PLAYER_ATTACK")

			battle_state = BattleState.PLAYER_ATTACK
			await _player_attack_sequence(score)
			# 全ての攻撃が終わったかチェック
			if _are_all_enemies_dead():
				battle_state = BattleState.VICTORY
			else:
				# 敵のターンへ
				battle_state = BattleState.ENEMY_TURN_START
				
			_process_battle_state()

		BattleState.ENEMY_TURN_START:
			print("ENEMY_TURN_START")
			await _show_label(enemy_turn_label, 2.0)
			await _enemy_turn_sequence()
			battle_state = BattleState.PLAYER_TURN_START
			_process_battle_state()
			
		BattleState.VICTORY:
			print("VICTORY")
			print("バトル勝利！")
			enemy_turn_label.visible = false
			victory_label.visible = true
			await get_tree().create_timer(2.0).timeout
			victory_label.visible = false
			end_battle()
func _enemy_turn_sequence():
	for i in range(spawned_enemies.size()):
		var enemy = spawned_enemies[i]
		if not enemy or enemy.state == enemy.State.DEAD:
			continue
		
		if randi() % 2 == 0:
			await _enemy_single_attack(enemy,i)
		else:
			await _enemy_all_attack(enemy)
func _enemy_single_attack(enemy,cnt):
	var target = _get_random_living_ally()
	if not target: return
	var dmg = enemy.attack

	await _move_to_target(enemy,target,1)
	enemy.state = State.ATTACK_SINGLE
	enemy.isanim = false
	await get_tree().create_timer(1.7).timeout
	_show_damage_number(dmg, target.global_position + Vector3(0, 2, 0))
	target.receive_damage(dmg)
	await _move_to_start(enemy,cnt,1)

func _enemy_all_attack(enemy):
	var dmg = enemy.attack * 0.8
	enemy.state = State.ATTACK_ALL
	enemy.isanim = false
	await get_tree().create_timer(1.5).timeout
	for ally in spawned_allies:
		if not ally or ally.state == ally.State.DEAD: continue
		_show_damage_number(int(dmg),ally.global_position + Vector3(0, 2, 0))
		ally.receive_damage(int(dmg))
	enemy.state = State.BATTLE_IDLE
	enemy.isanim = false
func _move_to_target(actor: CharacterBody3D, target: Node3D,team: int):
	if team == 0:
		actor.state = State1.BATTLE_MOVE
	else:
		actor.state = State.BATTLE_MOVE
	actor.isanim = false
	var tween = create_tween()
	if team == 0:
		tween.tween_property(actor, "position", target.position + Vector3(-1, 0, 0), 1.0)
	else:
		tween.tween_property(actor, "position", target.position + Vector3(1, 0, 0), 1.0)
	await tween.finished

func _move_to_start(actor: CharacterBody3D,cnt: int,team: int):
	var start_pos
	if team == 0:
		start_pos = allies_start_pos[cnt]
		actor.state = State1.BATTLE_MOVE
	else:
		start_pos = enemies_start_pos[cnt]
		actor.state = State.BATTLE_MOVE
	actor.isanim = false
	var tween = create_tween()
	tween.tween_property(actor, "position", start_pos, 1.0)
	await tween.finished
	if team == 0:
		actor.state = State1.BATTLE_IDLE
	else:
		actor.state = State.BATTLE_IDLE
	actor.isanim = false
func _player_attack_sequence(score: Array):
	for i in range(spawned_allies.size()):
		var ally = spawned_allies[i]
		if not ally:
			continue
		if ally.state == ally.State.DEAD:
			continue

		# 現在の敵一覧とHPをログ
		var enemies_info = []
		for e in spawned_enemies:
			if e:
				var hp_val = "unknown"
				if e.has_method("health"):
					hp_val = str(e.health)
				enemies_info.append(e.name + ":" + hp_val)
		print("   enemies:", enemies_info)

		var target = _get_random_living_enemy()
		if not target:
			continue

		# ダメージ算出（安全に）
		var dmg = int(score[ally.type]) * int(ally.attack)
		if dmg <= 0:
			continue

		print("ally_type:",ally.type," ",score[ally.type])

		await _move_to_target(ally, target,0)
		ally.state = State1.ATTACK_SINGLE
		ally.isanim = false


		print("   attack applied -> target_hp_after:", target.health if target.has_method("health") else "n/a")

		await get_tree().create_timer(1.7).timeout
		_show_damage_number(dmg, target.global_position + Vector3(0, 2, 0))
		target.receive_damage(dmg)
		
		await _move_to_start(ally, i, 0)
		print("   ally returned to start index:", i)
	print("PLAYER_ATTACK SEQUENCE END")
func _show_label(label: Control, duration: float):
	await get_tree().create_timer(duration).timeout
	label.visible = true
	await get_tree().create_timer(duration).timeout
	label.visible = false
# --- ヘルパー関数 (ダメージ表示) ---
func _show_damage_number(amount: int,world_pos: Vector3):
	var dmg_label = Label3D.new()
	dmg_label.text = str(amount)
	dmg_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dmg_label.modulate = Color(1,0,0)
	dmg_label.position = world_pos + Vector3(0,2,0)
	get_tree().current_scene.add_child(dmg_label)

	var tween = create_tween()
	tween.tween_property(dmg_label, "translation:y", dmg_label.position.y + 1.5, 1.0)
	tween.tween_property(dmg_label, "modulate:a", 0.0, 1.0)

# --- ヘルパー関数 (敵の生存確認) ---
func _get_random_living_enemy() -> CharacterBody3D:
	var living_enemies = []
	for enemy in spawned_enemies:
		if enemy and enemy.is_inside_tree() and enemy.state != enemy.State.DEAD:
			living_enemies.append(enemy)
	
	if living_enemies.is_empty():
		return null
	else:
		return living_enemies.pick_random()
func _get_random_living_ally() -> CharacterBody3D:
	var living_allies = []
	for ally in spawned_allies:
		if ally and ally.is_inside_tree() and ally.state != ally.State.DEAD:
			living_allies.append(ally)
	
	if living_allies.is_empty():
		return null
	else:
		return living_allies.pick_random()
func _are_all_enemies_dead() -> bool:
	return _get_random_living_enemy() == null
