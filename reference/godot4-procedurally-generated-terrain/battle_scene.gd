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
@onready var EffectManager = $EffectManager
var main_world_env: WorldEnvironment
var spawned_enemies: Array = [] 
var enemies_start_pos: Array = []
var spawned_allies: Array = []
var allies_start_pos: Array = []
var player_ref: Node3D = null
var field_camera: Camera3D = null
var player_original_position: Vector3
var camera_original_transform: Transform3D
var money:int = 0
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
var allies_to_spawn = []
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
	_process_battle_state()
func prepare_battle(player: Node3D, touched_enemy: Node3D, existing_enemies: Array,allies_data: Array):
	player_ref = player
	player_original_position = player.global_position
	allies_to_spawn = allies_data
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
		ally_instance.attack = info.attack
		ally_instance.defense = info.defense
		ally_instance.hp = info.health
		ally_instance.max_hp = info.max_health
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
		enemy_instance.health = get_parent().all_characters[name][0]
		enemy_instance.max_health = get_parent().all_characters[name][0]
		enemy_instance.attack = get_parent().all_characters[name][1]
		enemy_instance.defense = get_parent().all_characters[name][2]
		enemy_instance.type = get_parent().all_characters[name][3]
		enemy_instance.health *= pow(10,biome_type)
		enemy_instance.attack *= pow(2,biome_type)
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
	var resallies = get_parent().allies
	var resallies_name = get_parent().allies_name
	var resallies_cur_health = get_parent().allies_cur_health
	var restype = get_parent().allies_type
	var resallies_level = get_parent().allies_level
	var resallies_base_health = get_parent().allies_base_health
	var resallies_base_attack = get_parent().allies_base_attack
	var resallies_base_defense = get_parent().allies_base_defense
	get_parent().allies = []
	get_parent().allies_name = []
	get_parent().allies_cur_health = []
	get_parent().allies_type = []
	get_parent().allies_level = []
	get_parent().allies_base_health = []
	get_parent().allies_base_attack = []
	get_parent().allies_base_defense = []
	for i in range(spawned_allies.size()):
		resallies_cur_health[i] = spawned_allies[i].hp
	for i in range(spawned_allies.size()):
		var ally = spawned_allies[i]
		if ally != null:
			get_parent().allies.append(resallies[i])
			get_parent().allies_name.append(resallies_name[i])
			get_parent().allies_cur_health.append(resallies_cur_health[i])
			get_parent().allies_type.append(restype[i])
			get_parent().allies_level.append(resallies_level[i])
			get_parent().allies_base_health.append(resallies_base_health[i])
			get_parent().allies_base_attack.append(resallies_base_attack[i])
			get_parent().allies_base_defense.append(resallies_base_defense[i])
			
		
	await fade_manager.fade_in(1.0)
	if player_ref:
		player_ref.global_position = player_original_position
		player_ref.isbattle = false

	# カメラ復帰
	if field_camera:
		field_camera.global_transform = camera_original_transform
		field_camera.current = true  # 再び探索カメラを有効化

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_parent().money += money
	var d = get_parent().get_node("spawn_enemy").isspawned.size()
	var h = get_parent().get_node("spawn_enemy").isspawned[0].size()
	var w = get_parent().get_node("spawn_enemy").isspawned[0][0].size()
	for k in range(d):
		for i in range(h):
			for j in range(w):
				get_parent().get_node("spawn_enemy").isspawned[k][i][j] = 0
	# バトルシーン削除
	queue_free()
# --- バトルステートマシン本体 ---
func _process_battle_state():
	match battle_state:
		BattleState.INTRO:
			await _show_label(battle_start_label, 1.0)
			# 次のステートへ
			battle_state = BattleState.PLAYER_TURN_START
			_process_battle_state()

		BattleState.PLAYER_TURN_START:
			# "Your Turn" UI表示
			for i in range(spawned_allies.size()):
				get_parent().allies_cur_health[i] = spawned_allies[i].hp
			
			await _show_label(your_turn_label, 1.0)
			puzzle_board.canmove = true
			# 次のステートへ
			battle_state = BattleState.PLAYER_TURN
			_process_battle_state()

		BattleState.PLAYER_TURN:
			# パズルボードの操作を許可
			
			puzzle_board.canmove = true
			# ここでステートは待機。_on_puzzle_complete シグナルで次に進む

		BattleState.PLAYER_ATTACK:
			await get_tree().create_timer(0.3).timeout
			if score[3] > 0:
				for i in range(spawned_allies.size()):
					var info = allies_to_spawn[i]
					var ally = spawned_allies[i]
					EffectManager.show_effect("shield", ally.position + Vector3(0, 1, 0))
					ally.defense += info.defense*score[3]
			money += score[1]
			await get_tree().create_timer(1.0).timeout
			battle_state = BattleState.PLAYER_ATTACK
			await _player_turn_sequence(score)
			# 全ての攻撃が終わったかチェック
			if _are_all_enemies_dead():
				battle_state = BattleState.VICTORY
			else:
				# 敵のターンへ
				battle_state = BattleState.ENEMY_TURN_START
				
			_process_battle_state()

		BattleState.ENEMY_TURN_START:
			await _show_label(enemy_turn_label, 2.0)
			await _enemy_turn_sequence()
			battle_state = BattleState.PLAYER_TURN_START
			_process_battle_state()
			
		BattleState.VICTORY:
			print("バトル勝利！")
			enemy_turn_label.visible = false
			victory_label.visible = true
			await get_tree().create_timer(2.0).timeout
			victory_label.visible = false
			end_battle()
func _enemy_turn_sequence():
	for i in range(spawned_enemies.size()):
		var enemy = spawned_enemies[i]
		if not enemy:
			continue
		if enemy.state == enemy.State.DEAD:
			continue
			
		var dmg = enemy.attack
		var isall = false
		var effect
		print(enemy.type)
		if enemy.type == 4:
			if randi() % 2 == 0:
				effect = "slash_hit"
			else:
				isall = true
				effect = "shock_wave"
		if enemy.type == 8:
			if randi() % 2 == 0:
				effect = "impact_smash"
			else:
				isall = true
				effect = "arrow_storm"
		if enemy.type == 10:
			if randi() % 2 == 0:
				effect = "magic_burst"
			else:
				isall = true
				effect = "magic_circle_burst"
		if enemy.type == 0:
			if randi() % 2 == 0:
				await _enemy_single_heal(enemy,i,dmg)
			else:
				isall = true
				await _enemy_all_heal(enemy,dmg)
			continue
		if dmg <= 0:
			continue
		if !isall:
			await _enemy_single_attack(enemy,i,effect,dmg)
		else:
			await _enemy_all_attack(enemy,effect,dmg)
func _enemy_single_attack(enemy,cnt,effect,dmg):
	var target = _get_random_living_ally()
	if not target: return
	await _move_to_target(enemy,target,1)
	enemy.state = State.ATTACK_SINGLE
	enemy.isanim = false
	EffectManager.show_effect(effect, target.position)
	await get_tree().create_timer(1.5).timeout
	_show_damage_number(dmg, target.position + Vector3(0, 2, 0),0,target)
	target.receive_damage(dmg)
	await _move_to_start(enemy,cnt,1)

func _enemy_all_attack(enemy,effect,dmg):
	dmg *= 0.4
	enemy.state = State.ATTACK_ALL
	enemy.isanim = false
	for ally in spawned_allies:
		if not ally or ally.state == ally.State.DEAD: continue
		EffectManager.show_effect(effect, ally.position)
	await get_tree().create_timer(1.5).timeout
	for ally in spawned_allies:
		if not ally or ally.state == ally.State.DEAD: continue
		_show_damage_number(int(dmg),ally.position + Vector3(0, 2, 0),0,ally)
		ally.receive_damage(int(dmg))
	await get_tree().create_timer(1.0).timeout
	enemy.state = State.BATTLE_IDLE
	enemy.isanim = false
func _player_single_attack(ally,cnt,effect,dmg):
	var target = _get_random_living_enemy()
	if not target: return

	await _move_to_target(ally,target,0)
	ally.state = State1.ATTACK_SINGLE
	ally.isanim = false
	EffectManager.show_effect(effect, target.position)
	await get_tree().create_timer(1.5).timeout
	_show_damage_number(dmg, target.position + Vector3(0, 2, 0),1,target)
	target.receive_damage(dmg)
	await _move_to_start(ally,cnt,0)

func _player_all_attack(ally,effect,dmg):
	dmg *= 0.4
	ally.state = State1.ATTACK_ALL
	ally.isanim = false
	for enemy in spawned_enemies:
		if not enemy or enemy.state == enemy.State.DEAD: continue
		EffectManager.show_effect(effect, enemy.position)
	await get_tree().create_timer(1.5).timeout
	for enemy in spawned_enemies:
		if not enemy or enemy.state == enemy.State.DEAD: continue
		_show_damage_number(int(dmg),enemy.position + Vector3(0, 2, 0),1,enemy)
		enemy.receive_damage(int(dmg))
	await get_tree().create_timer(1.0).timeout
	ally.state = State1.BATTLE_IDLE
	ally.isanim = false

func _player_single_heal(ally,cnt,heal):
	var target = _get_random_living_ally()
	if not target: return
	
	await get_tree().create_timer(1.0).timeout
	ally.state = State1.ATTACK_SINGLE
	ally.isanim = false
	await get_tree().create_timer(1.7).timeout
	EffectManager.show_effect("heal", target.position + Vector3(2, 0, 0))
	_show_heal_number(heal, target.global_position + Vector3(0, 2, 0),0)
	target.receive_heal(heal)
	ally.state = State1.BATTLE_IDLE
	ally.isanim = false
func _player_all_heal(ally,heal):
	var target = _get_random_living_ally()
	if not target: return
	heal *= 0.4
	
	await get_tree().create_timer(1.0).timeout
	ally.state = State1.ATTACK_ALL
	ally.isanim = false
	await get_tree().create_timer(1.7).timeout
	for ally1 in spawned_allies:
		EffectManager.show_effect("heal", ally1.position + Vector3(2, 0, 0))
		_show_heal_number(heal, ally1.global_position + Vector3(0, 2, 0),0)
	target.receive_heal(heal)
	ally.state = State1.BATTLE_IDLE
	ally.isanim = false

func _enemy_single_heal(enemy,cnt,heal):
	var target = _get_random_living_enemy()
	if not target: return
	
	await get_tree().create_timer(1.0).timeout
	enemy.state = State.ATTACK_SINGLE
	enemy.isanim = false
	await get_tree().create_timer(1.7).timeout
	EffectManager.show_effect("heal", target.position + Vector3(2, 0, 0))
	_show_heal_number(heal, target.global_position + Vector3(0, 2, 0),0)
	target.receive_heal(heal)
	enemy.state = State.BATTLE_IDLE
	enemy.isanim = false
func _enemy_all_heal(enemy,heal):
	heal *= 0.4
	
	await get_tree().create_timer(1.0).timeout
	enemy.state = State.ATTACK_ALL
	enemy.isanim = false
	await get_tree().create_timer(1.7).timeout
	for enemy1 in spawned_enemies:
		if not enemy1:
			continue
		EffectManager.show_effect("heal", enemy1.global_position + Vector3(2, 0, 0))
		_show_heal_number(heal, enemy1.global_position + Vector3(0, 2, 0),0)
		enemy1.receive_heal(heal)
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
func _player_turn_sequence(score: Array):
	for i in range(spawned_allies.size()):
		var ally = spawned_allies[i]
		if not ally:
			continue
		if ally.state == ally.State.DEAD:
			continue
			
		var dmg
		var isall = false
		var effect
		if ally.type == 4:
			if score[4] >= score[7]:
				dmg = int(score[4]) * int(ally.attack)
				effect = "slash_hit"
			else:
				isall = true
				dmg = int(score[7]) * int(ally.attack)
				effect = "shock_wave"
		if ally.type == 8:
			if score[8] >= score[5]:
				dmg = int(score[8]) * int(ally.attack)
				effect = "impact_smash"
			else:
				isall = true
				dmg = int(score[5]) * int(ally.attack)
				effect = "arrow_storm"
		if ally.type == 10:
			if score[10] >= score[9]:
				dmg = int(score[10]) * int(ally.attack)
				effect = "magic_burst"
			else:
				isall = true
				dmg = int(score[9]) * int(ally.attack)
				effect = "magic_circle_burst"
		if ally.type == 0:
			if score[0] >= score[6]:
				dmg = int(score[0]) * int(ally.attack)
				await _player_single_heal(ally,i,dmg)
			else:
				isall = true
				dmg = int(score[6]) * int(ally.attack)	
				await _player_all_heal(ally,dmg)
			continue
		if dmg <= 0:
			continue
		if !isall:
			await _player_single_attack(ally,i,effect,dmg)
		else:
			await _player_all_attack(ally,effect,dmg)
func _show_label(label: Control, duration: float):
	await get_tree().create_timer(duration).timeout
	label.visible = true
	await get_tree().create_timer(duration).timeout
	label.visible = false
# --- ヘルパー関数 (ダメージ表示) ---
func _show_damage_number(amount: int,world_pos: Vector3,team: int,char:CharacterBody3D):
	var dmg_label = Label3D.new()
	var damage = int(amount * (100.0 / (100.0 + char.defense)))
	damage = max(1, damage)
	dmg_label.text = str(damage)
	dmg_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dmg_label.modulate = Color(1,0,0)
	if team == 0:
		dmg_label.position = world_pos + Vector3(2,0,-0.5)
	else:
		dmg_label.position = world_pos + Vector3(-2,0,-0.5)
	get_tree().current_scene.add_child(dmg_label)

	var tween = create_tween()
	tween.tween_property(dmg_label, "translation:y", dmg_label.position.y + 1.5, 1.0)
	tween.tween_property(dmg_label, "modulate:a", 0.0, 1.0)
	await tween.finished
	dmg_label.queue_free()
func _show_heal_number(amount: int,world_pos: Vector3,team: int):
	var dmg_label = Label3D.new()
	dmg_label.text = str(amount)
	dmg_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dmg_label.modulate = Color(0,1,0)
	if team == 0:
		dmg_label.position = world_pos + Vector3(2,0,-0.5)
	else:
		dmg_label.position = world_pos + Vector3(-2,0,-0.5)
	get_tree().current_scene.add_child(dmg_label)

	var tween = create_tween()
	tween.tween_property(dmg_label, "translation:y", dmg_label.position.y + 1.5, 1.0)
	tween.tween_property(dmg_label, "modulate:a", 0.0, 1.0)
	await tween.finished
	dmg_label.queue_free()
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
