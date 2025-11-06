extends Control

# ===============================
#      ノード参照
# ===============================
@onready var battlefield = $Battle3DViewport
@onready var enemies_root = $Battle3DViewport/SubViewport/Enemies
@onready var ui_root = $UI
@onready var fade_manager = $FadeManager
@onready var battle_camera = $Battle3DViewport/SubViewport/Camera3D
@onready var puzzle_board = $UI/PuzzleBoard
@onready var battle_start_label = $UI/BattleStartLabel
@onready var your_turn_label = $UI/YourTurnLabel
@onready var enemy_turn_label = $UI/EnemyTurnLabel
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

	# プレイヤーをバトル位置に移動
	battle_camera.rotation = Vector3(deg_to_rad(-20),deg_to_rad(270),deg_to_rad(0))
	battle_camera.position = Vector3(0,2,5)
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
			battle_start_label.visible = true
			await get_tree().create_timer(1.5).timeout # 1.5秒表示
			battle_start_label.visible = false
			
			# 次のステートへ
			battle_state = BattleState.PLAYER_TURN_START
			_process_battle_state()

		BattleState.PLAYER_TURN_START:
			# "Your Turn" UI表示
			your_turn_label.visible = true
			await get_tree().create_timer(1.0).timeout # 1秒表示
			your_turn_label.visible = false
			
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
			# "Enemy Turn" UI表示
			enemy_turn_label.visible = true
			await get_tree().create_timer(1.0).timeout # 1秒表示
			enemy_turn_label.visible = false

			# 次のステートへ
			battle_state = BattleState.ENEMY_TURN
			_process_battle_state()

		BattleState.ENEMY_TURN:
			# 敵が順番に攻撃
			for enemy in spawned_enemies:
				print(enemy)
				# 生きている敵だけが攻撃
				if enemy and enemy.is_inside_tree() and enemy.state != enemy.State.DEAD:
					
					# enemy.gd の start_attack() を呼び出す
					if enemy.has_method("start_attack"):
						enemy.start_attack()
						
						# 敵の攻撃アニメーションを待つ (時間は enemy.gd の実装に合わせる)
						# ここでは仮に2.5秒待つ
						await get_tree().create_timer(2.5).timeout 
			
			# TODO: 味方が全滅したかのチェック
			
			# 全員の攻撃が終わったらプレイヤーのターンに戻る
			battle_state = BattleState.PLAYER_TURN_START
			_process_battle_state()

		BattleState.VICTORY:
			print("バトル勝利！")
			end_battle()


func _on_puzzle_complete(score: Array):
	if battle_state != BattleState.PLAYER_TURN:
		return

	battle_state = BattleState.PLAYER_ATTACK

	# score配列 ( [bread, coin, potion, shield, sword] のスコア) に基づいて攻撃
	# 仮に score[i] * 10 のダメージとする
	var base_damage_per_point = 10 
	
	for i in range(score.size()):
		var damage_amount = score[i] * base_damage_per_point
		# ダメージがあれば攻撃
		if damage_amount > 0:
			# "ランダムに敵を決め"
			var target_enemy = _get_random_living_enemy()
			if not target_enemy:
				continue 
			# "ジャンプして移動" -> 
			# (プレイヤーモデルが非表示のため、ここではダメージ処理のみ)

			# 敵の少し上にダメージ量を表示
			_show_damage_number(damage_amount, target_enemy.global_position + Vector3(0, 1.5, 0))

			# "enemyのHPなどを減らす"
			if target_enemy.has_method("receive_damage"):
				target_enemy.receive_damage(damage_amount)
			
			# 攻撃ごと少し待つ
			await get_tree().create_timer(0.4).timeout

	# 全ての攻撃が終わったかチェック
	if _are_all_enemies_dead():
		battle_state = BattleState.VICTORY
		_process_battle_state()
	else:
		# 敵のターンへ
		battle_state = BattleState.ENEMY_TURN_START
		_process_battle_state()


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
	
	# RichTextLabel は size プロパティが即時反映されないため、
	# センタリングのために少し待つか、固定サイズにする必要があります。
	# ここでは fit_content を使っているので、position設定を工夫します。
	
	# unproject_position はビューポート左上基準なので、
	# RichTextLabel の Pivot Offset を中心にして配置します
	rich_label.global_position = screen_pos
	
	# ※ RichTextLabel の中央揃えは少しクセがあります。
	# 期待通りに中央表示されない場合は、
	# Label を使った元の実装（modulate + theme_override）の方が
	# アニメーション制御は簡単な可能性があります。

	# 1秒かけて上に移動しながらフェードアウトするアニメーション
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

func _are_all_enemies_dead() -> bool:
	return _get_random_living_enemy() == null
