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
func spawn_enemy(pos:Vector3i):
	var enemy_key = ""
	if pos.x >= plane_range_hl and pos.x <= plane_range_hr and pos.y >= plane_range_dl and pos.y <= plane_range_dr and pos.z >= plane_range_wl and pos.z <= plane_range_wr:
		if stage_enemy[0].size() == 0:
			return
		enemy_key = stage_enemy[0].pick_random()
	elif pos.x >= cave_range_hl and pos.x <= cave_range_hr and pos.y >= cave_range_dl and pos.y <= cave_range_dr and pos.z >= cave_range_wl and pos.z <= cave_range_wr:
		if stage_enemy[1].size() == 0:
			return
		enemy_key = stage_enemy[1].pick_random()
	elif pos.x >= desert_range_hl and pos.x <= desert_range_hr and pos.y >= desert_range_dl and pos.y <= desert_range_dr and pos.z >= desert_range_wl and pos.z <= desert_range_wr:
		if stage_enemy[2].size() == 0:
			return
		enemy_key = stage_enemy[2].pick_random()
	elif pos.x >= snow_range_hl and pos.x <= snow_range_hr and pos.y >= snow_range_dl and pos.y <= snow_range_dr and pos.z >= snow_range_wl and pos.z <= snow_range_wr:
		if stage_enemy[3].size() == 0:
			return
		enemy_key = stage_enemy[3].pick_random()
	elif pos.x >= castle_range_hl and pos.x <= castle_range_hr and pos.y >= castle_range_dl and pos.y <= castle_range_dr and pos.z >= castle_range_wl and pos.z <= castle_range_wr:
		if stage_enemy[4].size() == 0:
			return
		enemy_key = stage_enemy[4].pick_random()
	else:
		return
	
	# ======= モデル情報取得 =======
	var enemy_info = enemy_data.get(enemy_key)
	if enemy_info == null:
		push_warning("Enemy info not found for key: " + enemy_key)
		return

	var model_name = enemy_info[0]
	var model_path = "res://model/enemy/have_animation/" + model_name

	if not ResourceLoader.exists(model_path):
		push_warning("Enemy model not found: " + model_path)
		return

	# ======= モデル読み込み =======
	var model_scene = load(model_path)
	var enemy_instance

	if model_scene is PackedScene:
		enemy_instance = model_scene.instantiate()
	else:
		enemy_instance = Node3D.new()
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = model_scene
		enemy_instance.add_child(mesh_instance)

	# ======= 🔹 enemy.gdをアタッチ =======
	var enemy_script = load("res://enemy/enemy.gd")
	enemy_instance.set_script(enemy_script)

	# ======= 🔹 enemy.gdに必要な情報を渡す =======
	enemy_instance.mesh_path = model_path
	enemy_instance.pos = Vector3(pos.x, pos.y, pos.z)
	enemy_instance.health = 100
	enemy_instance.speed = 5.0

	# ======= シーンに追加 =======
	get_tree().current_scene.add_child(enemy_instance)
func list_enemy_in_folder(path:String):
	var dir = DirAccess.open(path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			enemy_data[file_name] = [file_name,[]]
		file_name = dir.get_next()
	dir.list_dir_end()
	for key in enemy_data.keys():
		if key=="fantasy_wolf" or key=="stone_guardian" or key=="swamp_guardian" or key=="bee":
			enemy_data[key][1].append(0)
		elif key=="mushroom_man" or key=="mysterious_mummy" or key=="aquatic_guardian":
			enemy_data[key][1].append(1)
		elif key=="skeleton" or key=="enigmatic_sorcerer":
			enemy_data[key][1].append(4)
	for key in enemy_data.keys():
		for i in range(enemy_data[key][1].size()):
			stage_enemy[enemy_data[key][1][i]].append(key)
	
func _ready() -> void:
	h = get_parent().get_node("terrain").h
	w = get_parent().get_node("terrain").w
	d = get_parent().get_node("terrain").d
	plane_start_h = get_parent().get_node("terrain").plane_start_h
	plane_start_w = get_parent().get_node("terrain").plane_start_w
	desert_start_h = get_parent().get_node("terrain").desert_start_h
	desert_start_w = get_parent().get_node("terrain").desert_start_w
	cave_start_h = get_parent().get_node("terrain").cave_start_h
	cave_start_w = get_parent().get_node("terrain").cave_start_w
	castle_start_h = get_parent().get_node("terrain").castle_start_h
	castle_start_w = get_parent().get_node("terrain").castle_start_w
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
	desert_range_dl = 42
	desert_range_dr = d-1
	cave_range_hl = plane_start_h
	cave_range_hr = plane_start_h+h-1
	cave_range_wl = plane_start_w
	cave_range_wr = plane_start_w+w-1
	cave_range_dl = 29
	cave_range_dr = 0
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
	castle_range_dl = 42
	castle_range_dr = d-1
	list_enemy_in_folder("res://model/enemy/have_animation/")
