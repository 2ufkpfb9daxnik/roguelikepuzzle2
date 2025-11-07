extends Control

# ===============================
#      ノード参照
# ===============================
@onready var battlefield = $Battle3DViewport
@onready var enemies_root = $Battle3DViewport/SubViewport/Enemies
@onready var allies_root = $Battle3DViewport/SubViewport/Allies
@onready var ui_root = $UI
@onready var fade_manager = $FadeManager
@onready var battle_camera = $Battle3DViewport/SubViewport/Camera3D
@onready var puzzle_board = $UI/PuzzleBoard
@onready var battle_start_label = $UI/BattleStartLabel
@onready var your_turn_label = $UI/YourTurnLabel
@onready var enemy_turn_label = $UI/EnemyTurnLabel
var main_world_env: WorldEnvironment
var spawned_enemies: Array = [] 
var spawned_allies: Array = []
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
	if puzzle_board:
		puzzle_board.connect("puzzle_complete",_on_puzzle_complete)
	
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
	battle_camera.rotation = Vector3(deg_to_rad(-90),deg_to_rad(270),deg_to_rad(0))
	battle_camera.position = Vector3(2,15,5)
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
	spawned_allies.clear()
	var allies_to_spawn = [
		{"name": "hero1", "path": "res://model/enemy/have_animation/red_magician/", "type": 4, "attack": 15},
		{"name": "hero2", "path": "res://model/enemy/have_animation/mushroom_man/", "type": 3, "attack": 10},
		{"name": "hero3", "path": "res://model/enemy/have_animation/kurione/", "type": 2, "attack": 5}
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
		ally_instance.attack = info.attack
		ally_instance.hp = 100
		ally_instance.max_hp = 100
		ally_instance.position = Vector3(-3, 0.6, (i - 1) * 2)
		if biome_type == 0:
			ally_instance.position = Vector3(plane_battle_pos.x+2,plane_battle_pos.y+0.6,plane_battle_pos.z+(i+1)*spacing1)
		elif biome_type == 1:
			ally_instance.position = Vector3(cave_battle_pos.x+2,cave_battle_pos.y+0.6,cave_battle_pos.z+(i+1)*spacing1)
		elif biome_type == 2:
			ally_instance.position = Vector3(desert_battle_pos.x+2,desert_battle_pos.y+0.6,desert_battle_pos.z+(i+1)*spacing1)
		elif biome_type == 3:
			ally_instance.position = Vector3(snow_battle_pos.x+2,snow_battle_pos.y+0.6,snow_battle_pos.z+(i+1)*spacing1)
		ally_instance.rotation = Vector3(0, deg_to_rad(90), 0)
		allies_root.add_child(ally_instance)
		spawned_allies.append(ally_instance)
	
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
	battle_state = BattleState.INTRO
	_process_battle_state()

# ===============================
#      バトル終了
# ===============================
func end_battle():
	await fade_manager.fade_out(1.0)
	queue_free()
# --- バトルステートマシン本体 ---
func _process_battle_state():
	match battle_state:
		BattleState.INTRO:
			# "battle_start" UI表示
			await _show_label(battle_start_label, 2.0)
			# 次のステートへ
			battle_state = BattleState.PLAYER_TURN_START
			_process_battle_state()

		BattleState.PLAYER_TURN_START:
			# "Your Turn" UI表示
			await _show_label(your_turn_label, 2.0)
			puzzle_board.canmove = true
			# 次のステートへ
			battle_state = BattleState.PLAYER_TURN
			_process_battle_state()

		BattleState.PLAYER_TURN:
			# パズルボードの操作を許可
			
			puzzle_board.canmove = true
			# ここでステートは待機。_on_puzzle_complete シグナルで次に進む

		BattleState.PLAYER_ATTACK:
			# _on_puzzle_complete から呼び出される
			# 攻撃処理はシグナルハンドラで行う
			pass

		BattleState.ENEMY_TURN_START:
			await _show_label(enemy_turn_label, 2.0)
			await _enemy_turn_sequence()
			battle_state = BattleState.PLAYER_TURN_START
			_process_battle_state()
			
		BattleState.VICTORY:
			print("バトル勝利！")
			end_battle()
func _enemy_turn_sequence():
	for enemy in spawned_enemies:
		if not enemy or enemy.state == enemy.State.DEAD:
			continue

		if randi() % 2 == 0:
			await _enemy_single_attack(enemy)
		else:
			await _enemy_all_attack(enemy)
			
func _enemy_single_attack(enemy):
	var target = _get_random_living_ally()
	if not target: return
	var dmg = enemy.attack

	await _move_to_target(enemy, target)
	_show_damage_number(dmg, target.global_position + Vector3(0, 2, 0))
	target.receive_damage(dmg)
	await get_tree().create_timer(1.0).timeout
	await _move_to_start(enemy)

func _enemy_all_attack(enemy):
	var dmg = enemy.attack * 0.8
	for ally in spawned_allies:
		if not ally or ally.state == ally.State.DEAD: continue
		_show_damage_number(int(dmg), ally.global_position + Vector3(0, 2, 0))
		ally.receive_damage(int(dmg))
	await get_tree().create_timer(1.5).timeout
func _move_to_target(actor: Node3D, target: Node3D):
	var tween = create_tween()
	tween.tween_property(actor, "position", target.position + Vector3(-1, 0, 0), 0.3)
	await tween.finished

func _move_to_start(actor: Node3D):
	var start_pos = actor.get_meta("start_pos")
	if not start_pos:
		start_pos = actor.position
	var tween = create_tween()
	tween.tween_property(actor, "position", start_pos, 0.3)
	await tween.finished

func _on_puzzle_complete(score: Array):
	if battle_state != BattleState.PLAYER_TURN:
		return

	battle_state = BattleState.PLAYER_ATTACK
	await _player_attack_sequence(score)
	battle_state = BattleState.ENEMY_TURN_START
	_process_battle_state()
	# 全ての攻撃が終わったかチェック
	if _are_all_enemies_dead():
		battle_state = BattleState.VICTORY
		_process_battle_state()
	else:
		# 敵のターンへ
		battle_state = BattleState.ENEMY_TURN_START
		_process_battle_state()
func _player_attack_sequence(score: Array):
	for ally in spawned_allies:
		if not ally or ally.state == ally.State.DEAD:
			continue

		#ランダム敵を選択
		var target = _get_random_living_enemy()
		if not target: break

		#ダメージ算出
		var dmg = score[ally.type] * ally.attack
		if dmg <= 0: continue

		#アニメーション：前に出る
		await _move_to_target(ally, target)

		#ダメージ表示
		_show_damage_number(dmg, target.global_position + Vector3(0, 2, 0))
		target.receive_damage(dmg)
		await get_tree().create_timer(1.0).timeout

		#元の位置に戻る
		await _move_to_start(ally)
func _show_label(label: Control, duration: float):
	label.visible = true
	await get_tree().create_timer(duration).timeout
	label.visible = false
# --- ヘルパー関数 (ダメージ表示) ---
func _show_damage_number(amount: int, world_pos: Vector3):
	# Node を RichTextLabel で作成
	var rich_label = RichTextLabel.new()
	rich_label.bb_code_enabled = true
	rich_label.fit_content = true # テキストに合わせてサイズを自動調整
	rich_label.scroll_active = false # スクロールバーを非表示

	# BBCode でスタイルを指定
	# (影はRichTextLabelの機能では少し面倒なので、font_size と color だけ指定)
	# (影もこだわる場合は、Label + theme_override の方が簡単な場合もあります)
	rich_label.text = "[center][font_size=32][color=yellow]" + str(amount) + "[/color][/font_size][/center]"

	# 3D座標を2Dスクリーン座標に変換
	var screen_pos = battle_camera.unproject_position(world_pos)
	
	# UIルートに追加
	ui_root.add_child(rich_label)
	rich_label.global_position = screen_pos
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(rich_label, "global_position", rich_label.global_position - Vector2(0, 60), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(rich_label, "modulate:a", 0.0, 1.0).set_delay(0.3)
	
	# アニメーションが終わったらラベルを削除
	tween.chain().tween_callback(rich_label.queue_free)
	
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
