extends Node
var h
var w
var d
var plane_start_h
var plane_start_w
var desert_start_h
var desert_start_w
var cave_start_h
var cave_start_w
var castle_start_h
var castle_start_w
var plane_range_hl:int
var plane_range_hr:int
var plane_range_wl:int
var plane_range_wr:int
var plane_range_dl:int
var plane_range_dr:int
var desert_range_hl:int
var desert_range_hr:int
var desert_range_wl:int
var desert_range_wr:int
var desert_range_dl:int
var desert_range_dr:int
var cave_range_hl:int
var cave_range_hr:int
var cave_range_wl:int
var cave_range_wr:int
var cave_range_dl:int
var cave_range_dr:int
var snow_range_hl:int
var snow_range_hr:int
var snow_range_wl:int
var snow_range_wr:int
var snow_range_dl:int
var snow_range_dr:int
var castle_range_hl:int
var castle_range_hr:int
var castle_range_wl:int
var castle_range_wr:int
var castle_range_dl:int
var castle_range_dr:int
var enemy_data = {}
var stage_enemy = [[],[],[],[],[]]
var nearest_ground
var isspawned
var player:Node3D
var spawn_range = 5
var can_spawn = true
var spawned_enemies = []
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
func spawn_enemy(pos:Vector3): # Vector3iからVector3に変更
	var enemy_key = ""
	var biome_type
	var spawn_pos_int = Vector3i(round(pos.x), round(pos.y), round(pos.z))

	# バイオーム判定 (posのVector3i版を使用)
	if spawn_pos_int.x >= plane_range_hl and spawn_pos_int.x <= plane_range_hr and spawn_pos_int.z >= plane_range_wl and spawn_pos_int.z <= plane_range_wr:
		if spawn_pos_int.y >= plane_range_dl and spawn_pos_int.y <= plane_range_dr:
			if stage_enemy[0].is_empty(): return
			enemy_key = stage_enemy[0].pick_random()
			biome_type =0
	elif spawn_pos_int.x >= cave_range_hl and spawn_pos_int.x <= cave_range_hr and spawn_pos_int.z >= cave_range_wl and spawn_pos_int.z <= cave_range_wr:
		if spawn_pos_int.y >= cave_range_dl and spawn_pos_int.y <= cave_range_dr:
			if stage_enemy[1].is_empty(): return
			enemy_key = stage_enemy[1].pick_random()
			biome_type = 1
	elif spawn_pos_int.x >= desert_range_hl and spawn_pos_int.x <= desert_range_hr and spawn_pos_int.z >= desert_range_wl and spawn_pos_int.z <= desert_range_wr:
		if spawn_pos_int.y >= desert_range_dl and spawn_pos_int.y <= desert_range_dr:
			if stage_enemy[2].is_empty(): return
			enemy_key = stage_enemy[2].pick_random()
			biome_type = 2
	elif spawn_pos_int.x >= snow_range_hl and spawn_pos_int.x <= snow_range_hr and spawn_pos_int.z >= snow_range_wl and spawn_pos_int.z <= snow_range_wr:
		if spawn_pos_int.y >= snow_range_dl and spawn_pos_int.y <= snow_range_dr:
			if stage_enemy[3].is_empty(): return
			enemy_key = stage_enemy[3].pick_random()
			biome_type = 3
	elif spawn_pos_int.x >= castle_range_hl and spawn_pos_int.x <= castle_range_hr and spawn_pos_int.z >= castle_range_wl and spawn_pos_int.z <= castle_range_wr:
		if spawn_pos_int.y >= castle_range_dl and spawn_pos_int.y <= castle_range_dr:
			if stage_enemy[4].is_empty(): return
			enemy_key = stage_enemy[4].pick_random()
			biome_type = 4
	if enemy_key == "":
		return

	# ======= モデル情報取得 =======
	var enemy_info = enemy_data.get(enemy_key)
	if enemy_info == null:
		push_warning("Enemy info not found for key: " + enemy_key)
		return

	var default_model_path = enemy_info[0]
	var all_animation_model_paths = enemy_info[1]
	
	if not ResourceLoader.exists(default_model_path):
		push_warning("Default enemy model file not found at path: " + default_model_path)
		return
	
	# ======= モデル読み込み =======
	var enemy_instance = CharacterBody3D.new()
	enemy_instance.name = enemy_key
	var enemy_script_resource = load("res://enemy.gd")
	if enemy_script_resource is GDScript:
		enemy_instance.set_script(enemy_script_resource)
	else:
		push_error("Failed to load enemy.gd script at res://enemy.gd")
		enemy_instance.queue_free()
		return
	var loaded_default_model_scene = load(default_model_path)
	var visual_model_root_instance: Node3D = null

	if loaded_default_model_scene is PackedScene:
		visual_model_root_instance = loaded_default_model_scene.instantiate()
	elif loaded_default_model_scene is Mesh:
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = loaded_default_model_scene
		visual_model_root_instance = mesh_inst
	else:
		push_warning("Unsupported model resource type for default model: " + default_model_path)
		enemy_instance.queue_free()
		return

	if visual_model_root_instance:
		visual_model_root_instance.name = "VisualModelRoot" # 後で enemy.gd から参照しやすいように名前を付ける
		enemy_instance.add_child(visual_model_root_instance)
		# モデルのスケールや位置調整が必要な場合はここで行う
		# visual_model_root_instance.scale = Vector3(0.01, 0.01, 0.01) # 例
		# visual_model_root_instance.position = Vector3(0, -0.5, 0) # 例
	
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.5 # モデルに合わせて調整してください
	collision.shape = shape
	collision.name = "CollisionShape3D" # enemy.gdから参照できるように名前を付ける
	enemy_instance.add_child(collision)
	var area_radius := 2.5
	var detection_area = Area3D.new()
	detection_area.name = "DetectionArea"
	detection_area.monitoring = true
	detection_area.monitorable = true
	var area_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = area_radius
	area_shape.shape = sphere
	detection_area.add_child(area_shape)
	enemy_instance.add_child(detection_area)
	# 安全に取得できない場合はデフォルト 2.5 を使う
	# ======= enemy.gdに必要な情報を渡す =======
	enemy_instance.global_position = pos
	enemy_instance.health = 100
	enemy_instance.speed = 5.0
	enemy_instance.biome_type = biome_type
	enemy_instance.state = State.IDLE
	# 全てのアニメーションモデルのパスを enemy.gd に渡す
	# enemy_instance が `enemy.gd` スクリプトを持つインスタンスであることを確認
	if enemy_instance.has_method("set_animation_model_paths"):
		enemy_instance.set_animation_model_paths(all_animation_model_paths)
	else:
		push_warning("Enemy instance does not have 'set_animation_model_paths' method.")

	# ======= シーンに追加 =======
	get_tree().current_scene.add_child(enemy_instance)
	spawned_enemies.append(enemy_instance)
	if visual_model_root_instance:
		visual_model_root_instance.name = "VisualModelRoot"
		enemy_instance.add_child(visual_model_root_instance)
		enemy_instance.current_visual_model_root = visual_model_root_instance

	# 追加: 足元補正
	if enemy_instance.has_method("adjust_model_to_ground"):
		enemy_instance.adjust_model_to_ground()
func list_enemy_in_folder(path: String):
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("Enemy Spawner Error: Directory not found at path: '" + path + "'.")
		return

	dir.list_dir_begin()
	var item_name = dir.get_next()
	while item_name != "":
		if item_name == "." or item_name == "..":
			item_name = dir.get_next()
			continue

		var full_item_path = path.path_join(item_name)

		if dir.current_is_dir(): # 敵の種類ごとのフォルダ（例: fantasy_wolf/）
			var sub_dir = DirAccess.open(full_item_path)
			if sub_dir:
				var animation_model_paths_for_enemy = []
				var default_model_path_for_enemy = "" # "idle.glb"など、初期表示用

				sub_dir.list_dir_begin()
				var file_name = sub_dir.get_next()
				while file_name != "":
					if not sub_dir.current_is_dir():
						var extension = file_name.get_extension().to_lower()
						if extension in ["glb", "gltf", "tscn"]:
							var model_file_path = full_item_path.path_join(file_name)
							animation_model_paths_for_enemy.append(model_file_path)

							# "idle"を含むファイルをデフォルトとする
							if file_name.to_lower().contains("idle") and default_model_path_for_enemy == "":
								default_model_path_for_enemy = model_file_path
					file_name = sub_dir.get_next()
				sub_dir.list_dir_end()
				
				# デフォルトモデルが設定されていない場合、最初に見つけたものを採用
				if default_model_path_for_enemy == "" and not animation_model_paths_for_enemy.is_empty():
					default_model_path_for_enemy = animation_model_paths_for_enemy[0]

				if not animation_model_paths_for_enemy.is_empty():
					# enemy_data の形式: [デフォルトモデルパス, 全アニメーションモデルパスのリスト, [ステージ番号]]
					enemy_data[item_name] = [default_model_path_for_enemy, animation_model_paths_for_enemy, []]
				else:
					push_warning("No suitable model files found in enemy folder: " + full_item_path)
			else:
				push_warning("Could not open sub-directory: " + full_item_path)
		
		item_name = dir.get_next()
	dir.list_dir_end()

	print("Found " + str(enemy_data.size()) + " enemy types.")
	for key in enemy_data.keys():
		print(("- Enemy: '%s', Default Model: '%s', Total Animations: %d") % [key, enemy_data[key][0], enemy_data[key][1].size()])

	# ★キー（フォルダ名）でバイオームを割り当てる
	for key in enemy_data.keys():
		# enemy_data[key][2] がステージのリスト
		if key=="fantasy_wolf" or key=="stone_guardian" or key=="swamp_guardian" or key=="bee":
			enemy_data[key][2].append(0) # Plane
		elif key=="mushroom_man" or key=="mysterious_mummy" or key=="aquatic_guardian":
			enemy_data[key][2].append(1) # Cave
		elif key=="skeleton" or key=="enigmatic_sorcerer":
			enemy_data[key][2].append(4) # Castle
		# Desertは現在空だが、必要に応じて追加
		# Snowは現在空だが、必要に応じて追加
			
	for key in enemy_data.keys():
		for i in range(enemy_data[key][2].size()):
			# stage_enemyにはフォルダ名（敵の名前）を追加する
			stage_enemy[enemy_data[key][2][i]].append(key)
			
func _process(delta):
	if not is_instance_valid(player) or nearest_ground == null or nearest_ground.is_empty():
		return
	if not can_spawn:
		return
	var cur_pos = player.global_transform.origin
	for i in range(-spawn_range,spawn_range+1):
		for j in range(-spawn_range,spawn_range+1):
			var check_x = int(cur_pos.x) - i
			var check_y = int(cur_pos.y)
			var check_z = int(cur_pos.z) - j
			
			if check_y < 0 or check_y >= nearest_ground.size(): continue
			if check_x < 0 or check_x >= nearest_ground[0].size(): continue
			if check_z < 0 or check_z >= nearest_ground[0][0].size(): continue
			
			if i*i + j*j <= spawn_range*spawn_range:
				# スポーン頻度を調整する条件（例: 4マスごとに1体）
				if check_x % 10 == 0 and check_z % 10 == 0: # Y座標のチェックは地形に依存するため、ここでは外す
					var ground_y = nearest_ground[check_y][check_x][check_z]
					if ground_y < 0: continue
					if isspawned[ground_y][check_x][check_z] == 0:
						# Y座標は地面の高さ+オフセットを使用
						if ground_y < 0: continue # 地面がない場所にはスポーンしない
						isspawned[ground_y][check_x][check_z] = 1 # スポーン済みにする
						spawn_enemy(Vector3(float(check_x), ground_y + 1.0, float(check_z))) # 地面から1.0上のY座標
func _ready() -> void:
	var parent = get_parent()
	if not is_instance_valid(parent):
		push_error("Spawner's parent is not ready.")
		return
		
	player = parent.get_node_or_null("CharacterBody3D")
	var terrain_node = parent.get_node_or_null("terrain")

	if not is_instance_valid(player) or not is_instance_valid(terrain_node):
		push_error("Spawner could not find Player or Terrain node.")
		return
		
	h = terrain_node.h
	w = terrain_node.w
	d = terrain_node.d
	plane_start_h = terrain_node.plane_start_h
	plane_start_w = terrain_node.plane_start_w
	desert_start_h = terrain_node.desert_start_h
	desert_start_w = terrain_node.desert_start_w
	cave_start_h = terrain_node.cave_start_h
	cave_start_w = terrain_node.cave_start_w
	castle_start_h = terrain_node.castle_start_h
	castle_start_w = terrain_node.castle_start_w
	nearest_ground = terrain_node.nearest_ground
	
	if nearest_ground == null or nearest_ground.is_empty():
		push_warning("Terrain has not generated 'nearest_ground' data yet.")
		return
		
	var nearest_ground_y_size = nearest_ground.size()
	var nearest_ground_x_size = 0
	var nearest_ground_z_size = 0

	if nearest_ground_y_size > 0:
		nearest_ground_x_size = nearest_ground[0].size()
	if nearest_ground_x_size > 0:
		nearest_ground_z_size = nearest_ground[0][0].size()

	isspawned = []
	for k_y in range(nearest_ground_y_size): # Y軸 (最も外側の次元)
		isspawned.append([])
		for i_x in range(nearest_ground_x_size): # X軸 (2番目の次元)
			isspawned[k_y].append([])
			for j_z in range(nearest_ground_z_size): # Z軸 (最も内側の次元)
				isspawned[k_y][i_x].append(0) # 0で初期化

	plane_range_hl = plane_start_h
	plane_range_hr = plane_start_h+h-1
	plane_range_wl = plane_start_w
	plane_range_wr = plane_start_w+w-1
	plane_range_dl = 31
	plane_range_dr = 41
	desert_range_hl = desert_start_h
	desert_range_hr = desert_start_h+h-1
	desert_range_wl = desert_start_w
	desert_range_wr = desert_start_w+w-1
	desert_range_dl = 31
	desert_range_dr = 41
	cave_range_hl = cave_start_h
	cave_range_hr = cave_start_h+h-1
	cave_range_wl = cave_start_w
	cave_range_wr = cave_start_w+w-1
	cave_range_dl = 0
	cave_range_dr = 30
	snow_range_hl = plane_start_h
	snow_range_hr = plane_start_h+h-1
	snow_range_wl = plane_start_w
	snow_range_wr = plane_start_w+w-1
	snow_range_dl = 42
	snow_range_dr = d-1
	castle_range_hl = castle_start_h
	castle_range_hr = castle_start_h+h-1
	castle_range_wl = castle_start_w
	castle_range_wr = castle_start_w+w-1
	castle_range_dl = 31
	castle_range_dr = d-1
	
	list_enemy_in_folder("res://model/enemy/have_animation/")
