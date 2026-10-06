class_name CharacterData
extends RefCounted

var id: String = ""
var name: String = ""
var model_path: String = ""
var type: int = 0
var level: int = 1
var cur_health: int = -1
var base_health: int = 100
var base_attack: int = 10
var base_defense: int = 10
var price: int = 100

static func calculate_status(base: float, lvl: int, power: float = 2.0 / 3.0) -> int:
	return int(base + lvl * pow(base, power))

func get_max_health() -> int:
	return calculate_status(base_health, level)

func get_attack() -> int:
	return calculate_status(base_attack, level)

func get_defense() -> int:
	return calculate_status(base_defense, level)

func get_levelup_cost() -> int:
	var base_cost = 10.0
	return int(base_cost * pow(1.3, level - 1))

func level_up() -> void:
	level += 1

func get_spawn_info() -> Dictionary:
	var max_hp = get_max_health()
	var hp = cur_health if cur_health >= 0 else max_hp
	return {
		"name": name,
		"path": model_path,
		"type": type,
		"attack": get_attack(),
		"max_health": max_hp,
		"health": hp,
		"defense": get_defense(),
		"level": level
	}

static func create_from_config(char_id: String, config: Array, char_level: int = 1, cur_hp: int = -1) -> CharacterData:
	var data = CharacterData.new()
	data.id = char_id
	data.name = char_id
	data.base_health = config[0]
	data.base_attack = config[1]
	data.base_defense = config[2]
	data.type = config[3]
	data.model_path = config[4]
	data.price = config[5] if config.size() > 5 else 1000
	data.level = char_level
	data.cur_health = cur_hp
	return data
