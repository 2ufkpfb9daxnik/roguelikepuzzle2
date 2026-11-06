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

var _shared_detect_sphere: SphereShape3D = null
var _shared_boss_sphere: SphereShape3D = null

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
	var spawn_pos_int = Vector3i(round(pos.x), round(pos.y), round(pos.z))
	var biome_type: int = _biome_for_position(pos)
	if stage_enemy[biome_type].is_empty():
		return
	enemy_key = stage_enemy[biome_type].pick_random()

	var enemy_info = enemy_data.get(enemy_key)
	if enemy_info == null:
		return

	var all_animation_model_paths: Array = enemy_info[1]

	var enemy_instance = Enemy.new()
	enemy_instance.name = enemy_key
	enemy_instance.position = pos
	enemy_instance.health = 100
	enemy_instance.max_health = 100
	enemy_instance.speed = 5.0
	enemy_instance.biome_type = biome_type
	enemy_instance.state = State.IDLE
	enemy_instance.enemy_name = enemy_key

	# Detection Area (共有SphereShape3Dでリソース生成コストを削減)
	var detection_area = Area3D.new()
	detection_area.name = "DetectionArea"
	detection_area.monitoring = true
	detection_area.monitorable = true
	var area_shape = CollisionShape3D.new()
	if not _shared_detect_sphere:
		_shared_detect_sphere = SphereShape3D.new()
		_shared_detect_sphere.radius = 1.5
	area_shape.shape = _shared_detect_sphere
	detection_area.add_child(area_shape)
	enemy_instance.add_child(detection_area)

	enemy_instance.set_animation_model_paths(all_animation_model_paths)
	enemy_instance.assign_battle_idle_anim()

	get_tree().current_scene.add_child(enemy_instance)
	enemy_instance.global_position = pos
	enemy_instance.set_spawn_origin(pos)
	spawned_enemies.append(enemy_instance)

func list_enemy_in_folder(path: String, overwrite: bool = true) -> void:
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

				if not anim_paths.is_empty() and (overwrite or not enemy_data.has(item_name)):
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
			if not stage_enemy[stage_idx].has(key):
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
	var cur_pos = player.global_transform.origin
	var biome := _biome_at_player(cur_pos)
	var tight_quarters := biome == 1 or biome == 4
	var spawn_interval := 0.65 if tight_quarters else 1.2
	if spawn_time < spawn_interval:
		return
	spawn_time = 0.0
	spawned_enemies = spawned_enemies.filter(func(e): return is_instance_valid(e))
	var max_spawned := 24 if tight_quarters else 18
	if spawned_enemies.size() >= max_spawned:
		return
	var ground_y_size = d
	var ground_x_size = terrain_node.worldh
	var ground_z_size = terrain_node.worldw

	# 洞窟・城は狭いので近距離で細かく、屋外はやや広めに探索する。
	var sample_count := 28 if tight_quarters else 12
	var sample_min := 8.0 if tight_quarters else 20.0
	var sample_max := 30.0 if tight_quarters else 55.0
	var snap_size := 4.0 if tight_quarters else 8.0
	var check_y = int(cur_pos.y)
	if check_y < 0 or check_y >= ground_y_size:
		return
	for _s in range(sample_count):
		var angle = randf() * PI * 2.0
		var dist = randf_range(sample_min, sample_max)
		var raw_x = cur_pos.x + cos(angle) * dist
		var raw_z = cur_pos.z + sin(angle) * dist
		var check_x = int(round(raw_x / snap_size)) * int(snap_size)
		var check_z = int(round(raw_z / snap_size)) * int(snap_size)

		if check_x < 0 or check_x >= ground_x_size: continue
		if check_z < 0 or check_z >= ground_z_size: continue

		var dx = float(check_x) - cur_pos.x
		var dz = float(check_z) - cur_pos.z
		var d_sq = dx * dx + dz * dz
		if d_sq < sample_min * sample_min or d_sq > sample_max * sample_max:
			continue

		var ground_y = terrain_node.get_ground_y(check_x, check_y, check_z)
		if ground_y < 0: continue
		if biome == 4:
			# 城内の範囲内だけをスポーン対象にする（フロアのY判定は地形に任せる）。
			if check_x < castle_range_hl or check_x > castle_range_hr:
				continue
			if check_z < castle_range_wl or check_z > castle_range_wr:
				continue

		var spawn_coord = Vector3i(check_x, ground_y, check_z)
		if not isspawned.has(spawn_coord):
			isspawned[spawn_coord] = true
			_spawn_queue.append(Vector3(float(check_x), float(ground_y) + 0.6, float(check_z)))
			break # 1回のチェック処理で最大1体だけキューに入れる（分散させる）

func _biome_at_player(pos: Vector3) -> int:
	return _biome_for_position(pos)

# バイオーム矩形は境界が重なるため、X/Z と高さ（Y）を組み合わせて判定する。
func _biome_for_position(pos: Vector3) -> int:
	var px := int(round(pos.x))
	var pz := int(round(pos.z))
	var py := int(round(pos.y))
	# 洞窟は地下（Y<=30）を優先。
	if py <= cave_range_dr:
		if px >= cave_range_hl and px <= cave_range_hr and pz >= cave_range_wl and pz <= cave_range_wr:
			return 1
		return 1
	# 魔王城内は城内判定を優先。
	if terrain_node and terrain_node.has_method("is_player_in_castle") and terrain_node.is_player_in_castle(pos):
		return 4
	if px >= castle_range_hl and px <= castle_range_hr and pz >= castle_range_wl and pz <= castle_range_wr and py >= castle_range_dl:
		return 4
	# 砂漠は低地（Y31〜41）。
	if px >= desert_range_hl and px <= desert_range_hr and pz >= desert_range_wl and pz <= desert_range_wr and py >= desert_range_dl and py <= desert_range_dr:
		return 2
	# 草原・雪原は同じX/Z帯で、Yの高さで分かれる。
	if px >= plane_range_hl and px <= plane_range_hr and pz >= plane_range_wl and pz <= plane_range_wr:
		if py >= snow_range_dl:
			return 3
		return 0
	# フォールバック: 最も近い中心。
	var centers := {
		0: Vector2(float(plane_start_h) + float(h) * 0.5, float(plane_start_w) + float(w) * 0.5),
		1: Vector2(float(cave_start_h) + float(h) * 0.5, float(cave_start_w) + float(w) * 0.5),
		2: Vector2(float(desert_start_h) + float(h) * 0.5, float(desert_start_w) + float(w) * 0.5),
		3: Vector2(float(plane_start_h) + float(h) * 0.5, float(plane_start_w) + float(w) * 0.5),
		4: Vector2(float(castle_start_h) + float(h) * 0.5, float(castle_start_w) + float(w) * 0.5)
	}
	var flat := Vector2(pos.x, pos.z)
	var best_biome := 0
	var best_dist := INF
	for biome in centers.keys():
		var dist := flat.distance_squared_to(centers[biome])
		if dist < best_dist:
			best_dist = dist
			best_biome = int(biome)
	return best_biome

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
	# アニメーション無しモデルも、プロシージャル演出で登場させる。
	list_enemy_in_folder("res://model/enemy/no_animation/", false)


func spawn_boss(enemy_key: String, pos: Vector3, scale_mult: float = 3.0, biome: int = 4) -> Node3D:
	if not enemy_data.has(enemy_key):
		# 地形生成との順序ずれに備えて、ボス生成直前にもう一度スキャンする。
		list_enemy_in_folder("res://model/enemy/have_animation/")
	if not enemy_data.has(enemy_key):
		push_error("Boss enemy key not found: " + enemy_key)
		return null
		
	var enemy_info = enemy_data[enemy_key]
	var all_animation_model_paths: Array = enemy_info[1]

	var enemy_instance = Enemy.new()
	enemy_instance.name = enemy_key + "_Boss"
	enemy_instance.is_boss = true
	enemy_instance.position = pos
	enemy_instance.health = 5000
	enemy_instance.max_health = 5000
	enemy_instance.speed = 3.0
	enemy_instance.biome_type = biome
	enemy_instance.state = 0 # IDLE
	enemy_instance.enemy_name = enemy_key

	# Detection Area (boss has scale_mult applied to node, so compensate the area scale
	# to keep the world-space trigger radius tight)
	var detection_area = Area3D.new()
	detection_area.name = "DetectionArea"
	detection_area.monitoring = true
	detection_area.monitorable = true
	detection_area.scale = Vector3(1.0 / maxf(scale_mult, 0.001), 1.0 / maxf(scale_mult, 0.001), 1.0 / maxf(scale_mult, 0.001))
	var area_shape = CollisionShape3D.new()
	if not _shared_boss_sphere:
		_shared_boss_sphere = SphereShape3D.new()
		_shared_boss_sphere.radius = 2.0
	area_shape.shape = _shared_boss_sphere
	detection_area.add_child(area_shape)
	enemy_instance.add_child(detection_area)

	enemy_instance.set_animation_model_paths(all_animation_model_paths)
	enemy_instance.assign_battle_idle_anim()
	enemy_instance.scale = Vector3(scale_mult, scale_mult, scale_mult)

	var target_scene = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_parent()
	if target_scene:
		target_scene.add_child(enemy_instance)
	var final_pos := pos
	var terrain = get_parent().get_node_or_null("terrain") if get_parent() else null
	if terrain and terrain.has_method("get_ground_y"):
		var gy := int(terrain.get_ground_y(int(round(pos.x)), int(round(pos.y)) + 8, int(round(pos.z))))
		if gy >= 0:
			final_pos.y = float(gy) + 1.0
	enemy_instance.global_position = final_pos
	enemy_instance.set_spawn_origin(final_pos)
	# 各ボスがひと目で分かるよう、頭上にボス名を表示する。
	var boss_label := Label3D.new()
	boss_label.text = "BOSS  " + enemy_key.replace("_", " ").capitalize()
	boss_label.font_size = 48
	boss_label.modulate = Color(1.0, 0.35, 0.30)
	boss_label.outline_size = 10
	boss_label.outline_modulate = Color(0, 0, 0, 0.95)
	boss_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	boss_label.pixel_size = 0.01
	boss_label.position = Vector3(0, 3.5 / maxf(scale_mult, 0.001), 0)
	enemy_instance.add_child(boss_label)
	spawned_enemies.append(enemy_instance)
	return enemy_instance
