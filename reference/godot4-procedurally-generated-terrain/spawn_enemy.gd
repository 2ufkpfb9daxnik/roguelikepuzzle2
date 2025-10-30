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

# ======================================================================
# ▼▼▼ 修正箇所 1: spawn_enemy 関数 ▼▼▼
# ======================================================================
func spawn_enemy(pos:Vector3): # Vector3iからVector3に変更
	var enemy_key = ""
	var spawn_pos_int = Vector3i(round(pos.x), round(pos.y), round(pos.z))

	# バイオーム判定 (posのVector3i版を使用)
	if spawn_pos_int.x >= plane_range_hl and spawn_pos_int.x <= plane_range_hr and spawn_pos_int.z >= plane_range_wl and spawn_pos_int.z <= plane_range_wr:
		if spawn_pos_int.y >= plane_range_dl and spawn_pos_int.y <= plane_range_dr:
			if stage_enemy[0].is_empty(): return
			enemy_key = stage_enemy[0].pick_random()
	elif spawn_pos_int.x >= cave_range_hl and spawn_pos_int.x <= cave_range_hr and spawn_pos_int.z >= cave_range_wl and spawn_pos_int.z <= cave_range_wr:
		if spawn_pos_int.y >= cave_range_dl and spawn_pos_int.y <= cave_range_dr:
			if stage_enemy[1].is_empty(): return
			enemy_key = stage_enemy[1].pick_random()
	elif spawn_pos_int.x >= desert_range_hl and spawn_pos_int.x <= desert_range_hr and spawn_pos_int.z >= desert_range_wl and spawn_pos_int.z <= desert_range_wr:
		if spawn_pos_int.y >= desert_range_dl and spawn_pos_int.y <= desert_range_dr:
			if stage_enemy[2].is_empty(): return
			enemy_key = stage_enemy[2].pick_random()
	elif spawn_pos_int.x >= snow_range_hl and spawn_pos_int.x <= snow_range_hr and spawn_pos_int.z >= snow_range_wl and spawn_pos_int.z <= snow_range_wr:
		if spawn_pos_int.y >= snow_range_dl and spawn_pos_int.y <= snow_range_dr:
			if stage_enemy[3].is_empty(): return
			enemy_key = stage_enemy[3].pick_random()
	elif spawn_pos_int.x >= castle_range_hl and spawn_pos_int.x <= castle_range_hr and spawn_pos_int.z >= castle_range_wl and spawn_pos_int.z <= castle_range_wr:
		if spawn_pos_int.y >= castle_range_dl and spawn_pos_int.y <= castle_range_dr:
			if stage_enemy[4].is_empty(): return
			enemy_key = stage_enemy[4].pick_random()
	
	if enemy_key == "":
		return

	# ======= モデル情報取得 =======
	var enemy_info = enemy_data.get(enemy_key)
	if enemy_info == null:
		push_warning("Enemy info not found for key: " + enemy_key)
		return

	# ★★★ 修正点: model_pathは enemy_info[0] に完全なパスとして保存されている
	var model_path = enemy_info[0]

	if not ResourceLoader.exists(model_path):
		push_warning("Enemy model file not found at path: " + model_path)
		return

	# ======= モデル読み込み =======
	var model_scene = load(model_path)
	var enemy_instance: CharacterBody3D

	if model_scene is PackedScene:
		enemy_instance = model_scene.instantiate()
	else:
		enemy_instance = CharacterBody3D.new()
		var mesh_instance = MeshInstance3D.new()
		if model_scene is Mesh: # 読み込んだのがMeshリソースの場合
			mesh_instance.mesh = model_scene
			enemy_instance.add_child(mesh_instance)
		else:
			push_error("Loaded resource is not a PackedScene or Mesh: " + model_path)
			return

	# ======= 🔹 enemy.gdをアタッチ =======
	var enemy_script = load("res://enemy.gd")
	enemy_instance.set_script(enemy_script)

	# ======= 🔹 enemy.gdに必要な情報を渡す (元のコードにあった `mesh_path`は不要) =======
	enemy_instance.global_position = pos # posはすでにVector3
	enemy_instance.health = 100
	enemy_instance.speed = 5.0
	
	# ======= シーンに追加 =======
	get_tree().current_scene.add_child(enemy_instance)


# ======================================================================
# ▼▼▼ 修正箇所 2: list_enemy_in_folder 関数 ▼▼▼
# ======================================================================
func list_enemy_in_folder(path: String):
	# フォルダの存在を確認
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("Enemy Spawner Error: Directory not found at path: '" + path + "'.")
		return

	dir.list_dir_begin()
	var item_name = dir.get_next()
	while item_name != "":
		# '.' と '..' は現在のフォルダと親フォルダなので無視
		if item_name == "." or item_name == "..":
			item_name = dir.get_next()
			continue

		var full_path = path.path_join(item_name)

		# ★アイテムがフォルダなら、その中をスキャンする
		if dir.current_is_dir():
			var sub_dir = DirAccess.open(full_path)
			if sub_dir:
				sub_dir.list_dir_begin()
				var file_name = sub_dir.get_next()
				while file_name != "":
					if not sub_dir.current_is_dir():
						# ★3Dモデルの拡張子を持つファイルを探す
						var extension = file_name.get_extension().to_lower()
						if extension in ["glb", "gltf", "tscn"]:
							# キーにはフォルダ名（敵の名前）を使用
							var enemy_name_key = item_name 
							# 値には、モデルファイルへの完全なパスを保存
							var model_file_path = full_path.path_join(file_name)
							
							enemy_data[enemy_name_key] = [model_file_path, []]
							# モデルを1つ見つけたら、このサブフォルダのスキャンは終了
							break 
					file_name = sub_dir.get_next()
		
		item_name = dir.get_next()

	# デバッグ用に、見つかった敵の数と名前を出力
	print("Found " + str(enemy_data.size()) + " enemy models from subfolders.")
	for key in enemy_data.keys():
		print("- Enemy: '" + key + "', Path: '" + enemy_data[key][0] + "'")

	# ★キー（フォルダ名）でバイオームを割り当てる
	for key in enemy_data.keys():
		if key == "fantasy_wolf" or key == "stone_guardian" or key == "swamp_guardian" or key == "bee":
			enemy_data[key][1].append(0)
		elif key == "mushroom_man" or key == "mysterious_mummy" or key == "aquatic_guardian":
			enemy_data[key][1].append(1)
		elif key == "skeleton" or key == "enigmatic_sorcerer":
			enemy_data[key][1].append(4)
			
	for key in enemy_data.keys():
		for i in range(enemy_data[key][1].size()):
			# stage_enemyにはフォルダ名（敵の名前）を追加する
			stage_enemy[enemy_data[key][1][i]].append(key)
			
# ======================================================================
# ▼▼▼ _process と _ready は変更なし ▼▼▼
# ======================================================================
func _process(delta):
	# 安全のため、playerとnearest_groundが存在するかチェック
	if not is_instance_valid(player) or nearest_ground == null or nearest_ground.is_empty():
		return

	var cur_pos = player.global_transform.origin
	for i in range(-spawn_range,spawn_range+1):
		for j in range(-spawn_range,spawn_range+1):
			# 範囲外アクセスをより安全にチェック
			var check_x = int(cur_pos.x) - i
			var check_y = int(cur_pos.y)
			var check_z = int(cur_pos.z) - j
			
			if check_y < 0 or check_y >= nearest_ground.size(): continue
			if check_x < 0 or check_x >= nearest_ground[0].size(): continue
			if check_z < 0 or check_z >= nearest_ground[0][0].size(): continue
			
			if i*i + j*j <= spawn_range*spawn_range:
				if check_x % 4 == 0 and check_z % 4 == 0 and check_y % 4 == 0:
					if isspawned[check_y][check_x][check_z] == 0:
						isspawned[check_y][check_x][check_z] = 1
						var ground_y = nearest_ground[check_y][check_x][check_z]
						if ground_y < 0: continue # 地面がない場所にはスポーンしない
						spawn_enemy(Vector3(float(check_x), ground_y + 1.0, float(check_z)))

func _ready() -> void:
	# _ready内で get_parent().get_node() を使うのは、シーン構造に強く依存するため
	# 実行順序の問題が起きやすい。可能なら main.gd から設定するのが望ましいが、
	# 現在のコードを維持する。
	# ただし、ノードが見つからない場合のエラーハンドリングを追加。
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
		
	isspawned = nearest_ground.duplicate(true)
	for k in range(nearest_ground.size()):
		for i in range(nearest_ground[0].size()):
			# jのループ範囲が間違っていたので修正
			for j in range(nearest_ground[0][0].size()): 
				isspawned[k][i][j] = 0
	
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
