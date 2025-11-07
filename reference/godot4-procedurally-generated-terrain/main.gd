extends Node3D

<<<<<<< HEAD
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var new_scene = load("res://title_screen.tscn")
	get_tree().change_scene_to_packed(new_scene)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
=======
var allies = ["res://model/enemy/have_animation/red_magician/"]
var allies_type = [4]
var allies_level = [1]
var allies_base_health = [80]
var allies_base_attack = [15]
var allies_base_defense = [20]
var allies_cur_health = [80]
func calculate_status(base: float, level: int, power: float = 2.0/3.0) -> int:
	return int(base + level * pow(base, power))
func generate_allies_to_spawn() -> Array:
	var allies_to_spawn = []
	for i in range(allies_level.size()):
		var level = allies_level[i]
		var info = {
			"name": "hero%d" % (i + 1),
			"path": allies[i],
			"type": allies_type[i],
			"attack": calculate_status(allies_base_attack[i], level),
			"max_health": calculate_status(allies_base_health[i], level),
			"health": calculate_status(allies_cur_health[i], level),
			"defense": calculate_status(allies_base_defense[i], level)
		}
		allies_to_spawn.append(info)
	return allies_to_spawn
>>>>>>> bfa88a3f48211b3ab65514f91d764807b512530a
