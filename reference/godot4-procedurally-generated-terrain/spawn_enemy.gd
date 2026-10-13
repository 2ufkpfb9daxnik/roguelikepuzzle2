extends Node

var h: int
var w: int
var d: int
var plane_start_h: int
var plane_start_w: int
var desert_start_h: int
var desert_start_w: int
var cave_start_h: int
var cave_start_w: int
var castle_start_h: int
var castle_start_w: int

var plane_range_hl: int
var plane_range_hr: int
var plane_range_wl: int
var plane_range_wr: int
var plane_range_dl: int
var plane_range_dr: int

var desert_range_hl: int
var desert_range_hr: int
var desert_range_wl: int
var desert_range_wr: int
var desert_range_dl: int
var desert_range_dr: int

var cave_range_hl: int
var cave_range_hr: int
var cave_range_wl: int
var cave_range_wr: int
var cave_range_dl: int
var cave_range_dr: int

var snow_range_hl: int
var snow_range_hr: int
var snow_range_wl: int
var snow_range_wr: int
var snow_range_dl: int
var snow_range_dr: int

var castle_range_hl: int
var castle_range_hr: int
var castle_range_wl: int
var castle_range_wr: int
var castle_range_dl: int
var castle_range_dr: int

var enemy_data: Dictionary = {}
var stage_enemy: Array = [[], [], [], [], []]
var nearest_ground = []
var isspawned: Dictionary = {}          # 巨大3次元配列から Dictionary に最適化
var player: Node3D = null
var terrain_node: Node3D = null
var min_spawn_range: int = 40
var max_spawn_range: int = 60
var can_spawn: bool = true
var spawned_enemies: Array = []
var spawn_time: float = 0.0

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

func reset_spawn_state() -> void:
	isspawned.clear()
	spawn_time = 0.0

func delete_enemy() -> void:
	while spawned_enemies.size() > 0:
		var enemy = spawned_enemies.pop_back()
		if is_instance_valid(enemy):
			enemy.queue_free()

func spawn_enemy(pos: Vector3) -> void:
	var enemy_key: String = ""
	var biome_type: int = 0
	var spawn_pos_int = Vector3i(round(pos.x), round(pos.y), round(pos.z))

	# バイオーム判定
	if spawn_pos_int.x >= plane_range_hl and spawn_pos_int.x <= plane_range_hr and spawn_pos_int.z >= plane_range_wl and spawn_pos_int.z <= plane_range_wr:
		var mat = 4
		if is_instance_valid(terrain_node):
			var check_y = spawn_pos_int.y
			while check_y >= 0 and check_y < 90:
				var m = terrain_node.get_map3dnum(spawn_pos_int.x, check_y, spawn_pos_int.z)
				if m != -1:
					mat = m
					break
				check_y -= 1
		# マテリアル 3 は雪、それ以外 (4:草, 5:土, 2:岩) は草原
		if mat == 3 and not stage_enemy[3].is_empty():
			enemy_key = stage_enemy[3].pick_random()
			biome_type = 3
		else:
			if stage_enemy[0].is_empty(): return
			enemy_key = stage_enemy[0].pick_random()
			biome_type = 0
	elif spawn_pos_int.x >= cave_range_hl and spawn_pos_int.x <= cave_range_hr and spawn_pos_int.z >= cave_range_wl and spawn_pos_int.z <= cave_range_wr:
		if stage_enemy[1].is_empty(): return
		enemy_key = stage_enemy[1].pick_random()
		biome_type = 1
	elif spawn_pos_int.x >= desert_range_hl and spawn_pos_int.x <= desert_range_hr and spawn_pos_int.z >= desert_range_wl and spawn_pos_int.z <= desert_range_wr:
		if stage_enemy[2].is_empty(): return
		enemy_key = stage_enemy[2].pick_random()
		biome_type = 2
	elif spawn_pos_int.x >= castle_range_hl and spawn_pos_int.x <= castle_range_hr and spawn_pos_int.z >= castle_range_wl and spawn_pos_int.z <= castle_range_wr:
		if stage_enemy[4].is_empty(): return
		enemy_key = stage_enemy[4].pick_random()
		biome_type = 4

	if enemy_key == "":
		return

	var enemy_info = enemy_data.get(enemy_key)
	if enemy_info == null:
		return

	var default_model_path: String = enemy_info[0]
	var all_animation_model_paths: Array = enemy_info[1]

	var enemy_instance = Enemy.new()
	enemy_instance.name = enemy_key
	enemy_instance.global_position = pos
	enemy_instance.health = 100
	enemy_instance.max_health = 100
	enemy_instance.speed = 5.0
	enemy_instance.biome_type = biome_type
	enemy_instance.state = State.IDLE
	enemy_instance.enemy_name = enemy_key

	# Detection Area
	var detection_area = Area3D.new()
	detection_area.name = "DetectionArea"
	detection_area.monitoring = true
	detection_area.monitorable = true
	var area_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 2.5
	area_shape.shape = sphere
	detection_area.add_child(area_shape)
	enemy_instance.add_child(detection_area)

	enemy_instance.set_animation_model_paths(all_animation_model_paths)
	enemy_instance.assign_battle_idle_anim()

	get_tree().current_scene.add_child(enemy_instance)
	enemy_instance.global_position = pos
	spawned_enemies.append(enemy_instance)

func list_enemy_in_folder(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("Enemy Spawner Error: Directory not found at: " + path)
		return

	dir.list_dir_begin()
	var item_name = dir.get_next()
	while item_name != "":
		if item_name == "." or item_name == "..":
			item_name = dir.get_next()
			continue

		var full_item_path = path.path_join(item_name)
		if dir.current_is_dir():
			var sub_dir = DirAccess.open(full_item_path)
			if sub_dir:
				var anim_paths = []
				var def_model_path = ""
				sub_dir.list_dir_begin()
				var file_name = sub_dir.get_next()
				while file_name != "":
					if not sub_dir.current_is_dir():
						var ext = file_name.get_extension().to_lower()
						if ext in ["glb", "gltf", "tscn"]:
							var model_file = full_item_path.path_join(file_name)
							anim_paths.append(model_file)
							if file_name.to_lower().contains("idle") and def_model_path == "":
								def_model_path = model_file
					file_name = sub_dir.get_next()
				sub_dir.list_dir_end()

				if def_model_path == "" and not anim_paths.is_empty():
					def_model_path = anim_paths[0]

				if not anim_paths.is_empty():
					enemy_data[item_name] = [def_model_path, anim_paths, []]
		item_name = dir.get_next()
	dir.list_dir_end()

	for key in enemy_data.keys():
		if key in ["fantasy_wolf", "stone_guardian", "swamp_guardian", "bee", "wood_monster"]:
			enemy_data[key][2].append(0) # Plane
		elif key in ["mushroom_man", "mysterious_mummy", "aquatic_guardian", "cave_dragon"]:
			enemy_data[key][2].append(1) # Cave
		elif key in ["scorpion", "spider", "snake_head", "octopus"]:
			enemy_data[key][2].append(2) # Desert
		elif key in ["wolf", "blue_dragon", "kurione"]:
			enemy_data[key][2].append(3) # Snow
		elif key in ["skeleton", "enigmatic_sorcerer", "demon", "red_magician"]:
			enemy_data[key][2].append(4) # Castle

	for key in enemy_data.keys():
		for stage_idx in enemy_data[key][2]:
			stage_enemy[stage_idx].append(key)

var _spawn_queue: Array = []  # キュー: [Vector3] のリスト

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(terrain_node):
		return
	if terrain_node.is_generating:
		return
	if not can_spawn:
		return
	if "isbattle" in player and player.isbattle:
		return

	# キューから1フレームに1体だけスポーン（フリーズ防止）
	if not _spawn_queue.is_empty():
		var pos = _spawn_queue.pop_front()
		spawn_enemy(pos)
		return  # スポーンしたフレームはスキャンしない

	spawn_time += delta
	if spawn_time >= 2.0:
		spawn_time = 0.0
		spawned_enemies = spawned_enemies.filter(func(e): return is_instance_valid(e))
		var cur_pos = player.global_transform.origin
		var ground_y_size = d
		var ground_x_size = terrain_node.worldh
		var ground_z_size = terrain_node.worldw
		
		

		# 計算負荷（14000回ループによるカクつき）を無くすため、ランダムサンプリング方式に変更
		var sample_count = 30
		for _s in range(sample_count):
			# ランダムな角度と距離でドーナツ状の範囲から座標を取得
			var angle = randf() * PI * 2.0
			var dist = randf_range(min_spawn_range, max_spawn_range)
			var i = int(cos(angle) * dist)
			var j = int(sin(angle) * dist)
			
			var check_x = int(cur_pos.x) + i
			var check_y = int(cur_pos.y)
			var check_z = int(cur_pos.z) + j

			if check_y < 0 or check_y >= ground_y_size: continue
			if check_x < 0 or check_x >= ground_x_size: continue
			if check_z < 0 or check_z >= ground_z_size: continue

			if check_x % 12 == 0 and check_z % 12 == 0:
				var ground_y = terrain_node.get_ground_y(check_x, check_y, check_z)
				if ground_y <= 30: continue
				
				var spawn_coord = Vector3i(check_x, ground_y, check_z)
				if not isspawned.has(spawn_coord):
					isspawned[spawn_coord] = true
					_spawn_queue.append(Vector3(float(check_x), float(ground_y) + 0.6, float(check_z)))
					break # 1回のチェック処理で最大1体だけキューに入れる（分散させる）

func _ready() -> void:
	var parent = get_parent()
	if not is_instance_valid(parent):
		return

	player = parent.get_node_or_null("CharacterBody3D")
	terrain_node = parent.get_node_or_null("terrain")
	if not is_instance_valid(player) or not is_instance_valid(terrain_node):
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

	isspawned.clear()

	plane_range_hl = plane_start_h
	plane_range_hr = plane_start_h + h - 1
	plane_range_wl = plane_start_w
	plane_range_wr = plane_start_w + w - 1
	plane_range_dl = 31
	plane_range_dr = 41

	desert_range_hl = desert_start_h
	desert_range_hr = desert_start_h + h - 1
	desert_range_wl = desert_start_w
	desert_range_wr = desert_start_w + w - 1
	desert_range_dl = 31
	desert_range_dr = 41

	cave_range_hl = cave_start_h
	cave_range_hr = cave_start_h + h - 1
	cave_range_wl = cave_start_w
	cave_range_wr = cave_start_w + w - 1
	cave_range_dl = 0
	cave_range_dr = 30

	snow_range_hl = plane_start_h
	snow_range_hr = plane_start_h + h - 1
	snow_range_wl = plane_start_w
	snow_range_wr = plane_start_w + w - 1
	snow_range_dl = 42
	snow_range_dr = d - 1

	castle_range_hl = castle_start_h
	castle_range_hr = castle_start_h + h - 1
	castle_range_wl = castle_start_w
	castle_range_wr = castle_start_w + w - 1
	castle_range_dl = 31
	castle_range_dr = d - 1

	list_enemy_in_folder("res://model/enemy/have_animation/")


func spawn_boss(enemy_key: String, pos: Vector3, scale_mult: float = 3.0, biome: int = 4) -> Node3D:
	if not enemy_data.has(enemy_key):
		push_error("Boss enemy key not found: " + enemy_key)
		return null
		
	var enemy_info = enemy_data[enemy_key]
	var all_animation_model_paths: Array = enemy_info[1]

	var enemy_instance = Enemy.new()
	enemy_instance.name = enemy_key + "_Boss"
	enemy_instance.is_boss = true
	enemy_instance.global_position = pos
	enemy_instance.health = 5000
	enemy_instance.max_health = 5000
	enemy_instance.speed = 3.0
	enemy_instance.biome_type = biome
	enemy_instance.state = 0 # IDLE
	enemy_instance.enemy_name = enemy_key

	# Detection Area (boss has scale_mult applied to node, so 3.5 becomes 10.5m~17.5m in world space)
	var detection_area = Area3D.new()
	detection_area.name = "DetectionArea"
	detection_area.monitoring = true
	detection_area.monitorable = true
	var area_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 3.5
	area_shape.shape = sphere
	detection_area.add_child(area_shape)
	enemy_instance.add_child(detection_area)

	enemy_instance.set_animation_model_paths(all_animation_model_paths)
	enemy_instance.assign_battle_idle_anim()
	enemy_instance.scale = Vector3(scale_mult, scale_mult, scale_mult)

	var target_scene = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_parent()
	if target_scene:
		target_scene.add_child(enemy_instance)
	enemy_instance.global_position = pos
	spawned_enemies.append(enemy_instance)
	return enemy_instance
