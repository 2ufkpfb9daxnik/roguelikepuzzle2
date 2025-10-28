extends Node
var h = get_parent().get_node("terrain").h
var w = get_parent().get_node("terrain").w
var d = get_parent().get_node("terrain").d
var plane_start_h = get_parent().get_node("terrain").plane_start_h
var plane_start_w = get_parent().get_node("terrain").plane_start_w
var desert_start_h = get_parent().get_node("terrain").desert_start_h
var desert_start_w = get_parent().get_node("terrain").desert_start_w
var cave_start_h = get_parent().get_node("terrain").cave_start_h
var cave_start_w = get_parent().get_node("terrain").cave_start_w
var castle_start_h = get_parent().get_node("terrain").castle_start_h
var castle_start_w = get_parent().get_node("terrain").castle_start_w
var plane_range_hl:int = plane_start_h
var plane_range_hr:int = plane_start_h+h-1
var plane_range_wl:int = plane_start_w
var plane_range_wr:int = plane_start_w+w-1
var plane_range_dl:int = 31
var plane_range_dr:int = 41
var desert_range_hl:int = desert_start_h
var desert_range_hr:int = desert_start_h+h-1
var desert_range_wl:int = desert_start_w
var desert_range_wr:int = desert_start_w+w-1
var desert_range_dl:int = 42
var desert_range_dr:int = d-1
var cave_range_hl:int = plane_start_h
var cave_range_hr:int = plane_start_h+h-1
var cave_range_wl:int = plane_start_w
var cave_range_wr:int = plane_start_w+w-1
var cave_range_dl:int = 29
var cave_range_dr:int = 0
var snow_range_hl:int = plane_start_h
var snow_range_hr:int = plane_start_h+h-1
var snow_range_wl:int = plane_start_w
var snow_range_wr:int = plane_start_w+w-1
var snow_range_dl:int = 42
var snow_range_dr:int = d-1
var castle_range_hl:int = castle_start_h
var castle_range_hr:int = castle_start_h+h-1
var castle_range_wl:int = castle_start_w
var castle_range_wr:int = castle_start_w+w-1
var castle_range_dl:int = 42
var castle_range_dr:int = d-1
func spawn_enemy(pos:Vector3i):
	if pos.x >= plane_range_hl and pos.x <= plane_range_hr and pos.y >= plane_range_dl and pos.y <= plane_range_dr and pos.z >= plane_range_wl and pos.z <= plane_range_wr:
		pass
	elif pos.x >= cave_range_hl and pos.x <= cave_range_hr and pos.y >= cave_range_dl and pos.y <= cave_range_dr and pos.z >= cave_range_wl and pos.z <= cave_range_wr:
		pass
	elif pos.x >= desert_range_hl and pos.x <= desert_range_hr and pos.y >= desert_range_dl and pos.y <= desert_range_dr and pos.z >= desert_range_wl and pos.z <= desert_range_wr:
		pass
	elif pos.x >= snow_range_hl and pos.x <= snow_range_hr and pos.y >= snow_range_dl and pos.y <= snow_range_dr and pos.z >= snow_range_wl and pos.z <= snow_range_wr:
		pass
	elif pos.x >= castle_range_hl and pos.x <= castle_range_hr and pos.y >= castle_range_dl and pos.y <= castle_range_dr and pos.z >= castle_range_wl and pos.z <= castle_range_wr:
		pass
