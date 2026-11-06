class_name CharacterData
extends RefCounted

# ============================================================
# 1キャラクター分のラン状態
# レベル / 経験値 / 属性 / スキルツリー / スキルゲージを保持する。
# ============================================================

var id: String = ""
var name: String = ""
var model_path: String = ""
var type: int = 0
var element: int = GameData.Element.FIRE
var level: int = 1
var exp: int = 0
var skill_points: int = 1
var skill_nodes: Dictionary = {}
var ult_charge: int = 0

var cur_health: int = -1
var base_health: int = 100
var base_attack: int = 10
var base_defense: int = 10
var price: int = 100

static func calculate_status(base: float, lvl: int, power: float = 2.0 / 3.0) -> int:
	return int(base + lvl * pow(base, power))

func get_character_modifiers() -> Dictionary:
	return GameData.collect_character_modifiers(skill_nodes)

func get_total_attack() -> int:
	var mods := get_character_modifiers()
	return max(1, calculate_status(base_attack, level) + int(mods.get("attack", 0.0)))

func get_total_defense() -> int:
	var mods := get_character_modifiers()
	return max(0, calculate_status(base_defense, level) + int(mods.get("defense", 0.0)))

func get_total_max_health() -> int:
	var mods := get_character_modifiers()
	return max(1, calculate_status(base_health, level) + int(mods.get("max_health", 0.0)))

# 既存コードとの互換 API
func get_max_health() -> int:
	return get_total_max_health()

func get_attack() -> int:
	return get_total_attack()

func get_defense() -> int:
	return get_total_defense()

func get_skill_power() -> float:
	var mods := get_character_modifiers()
	return 1.0 + float(mods.get("skill_power", 0.0))

func get_ult_power() -> float:
	var mods := get_character_modifiers()
	return 1.0 + float(mods.get("ult_power", 0.0))

func get_crit_chance() -> float:
	var mods := get_character_modifiers()
	return clampf(float(mods.get("crit_chance", 0.0)), 0.0, 0.75)

func get_element_name() -> String:
	return GameData.element_name(element)

func get_element_color() -> Color:
	return GameData.element_color(element)

func get_skill_attribute() -> int:
	return GameData.skill_attribute_for_type(type)

func get_skill_attribute_name() -> String:
	return GameData.skill_attribute_name(get_skill_attribute())

func get_skill_attribute_color() -> Color:
	return GameData.skill_attribute_color(get_skill_attribute())

func get_levelup_cost() -> int:
	return GameData.levelup_coin_cost(level)

func get_exp_to_next() -> int:
	return GameData.exp_to_next_level(level)

# ============================================================
# 経験値 / レベル
# ============================================================
func add_exp(amount: int) -> int:
	if amount <= 0:
		return 0
	exp += amount
	var gained := 0
	while exp >= get_exp_to_next():
		exp -= get_exp_to_next()
		level_up()
		gained += 1
	return gained

func level_up() -> void:
	var old_max := get_total_max_health()
	level += 1
	skill_points += 1
	var new_max := get_total_max_health()
	if cur_health >= 0:
		cur_health = clampi(cur_health + max(0, new_max - old_max), 0, new_max)

# ショップでコインを払って即時レベルアップしたときに使う。
func level_up_with_coin() -> void:
	level_up()

# ============================================================
# スキルツリー
# ============================================================
func get_skill_tree() -> Array:
	return GameData.get_skill_tree(element)

func get_node_level(node_id: String) -> int:
	return int(skill_nodes.get(node_id, 0))

func can_unlock_node(node: Dictionary) -> bool:
	if node.is_empty():
		return false
	var node_id: String = str(node.get("id", ""))
	if node_id == "":
		return false
	if get_node_level(node_id) >= int(node.get("max_level", 1)):
		return false
	if level < int(node.get("char_level", 1)):
		return false
	if skill_points < int(node.get("cost", 1)):
		return false

	var requirements: Array = node.get("requires", [])
	for req in requirements:
		if get_node_level(str(req)) <= 0:
			return false

	var any_requirements: Array = node.get("requires_any", [])
	if not any_requirements.is_empty():
		var any_ok := false
		for req in any_requirements:
			if get_node_level(str(req)) > 0:
				any_ok = true
				break
		if not any_ok:
			return false

	var group: String = str(node.get("exclusive_group", ""))
	if group != "":
		for other_id in skill_nodes.keys():
			if other_id == node_id or int(skill_nodes[other_id]) <= 0:
				continue
			var other := GameData.get_skill_node(element, str(other_id))
			if not other.is_empty() and str(other.get("exclusive_group", "")) == group:
				return false
	return true

func unlock_skill_node(node_id: String) -> bool:
	var node := GameData.get_skill_node(element, node_id)
	if not can_unlock_node(node):
		return false
	skill_points -= int(node.get("cost", 1))
	skill_nodes[node_id] = get_node_level(node_id) + 1
	return true

func get_unlocked_branch_counts() -> Dictionary:
	var counts := {"offense": 0, "guard": 0, "fortune": 0}
	for node_id in skill_nodes.keys():
		if int(skill_nodes[node_id]) <= 0:
			continue
		var node := GameData.get_skill_node(element, str(node_id))
		if node.is_empty():
			continue
		var branch: String = str(node.get("branch", ""))
		if counts.has(branch):
			counts[branch] += int(skill_nodes[node_id])
	return counts

# ============================================================
# 生成 / シリアライズ
# ============================================================
static func create_from_config(char_id: String, config: Array, char_level: int = 1, cur_hp: int = -1, element_override: int = -1) -> CharacterData:
	var data = CharacterData.new()
	data.id = char_id
	data.name = char_id
	data.base_health = int(config[0])
	data.base_attack = int(config[1])
	data.base_defense = int(config[2])
	data.type = int(config[3])
	data.model_path = str(config[4])
	data.price = int(config[5]) if config.size() > 5 else 1000
	data.level = max(1, char_level)
	data.cur_health = cur_hp
	data.element = element_override if element_override > 0 else GameData.element_for_character(char_id, data.type)
	data.exp = 0
	data.skill_points = max(1, data.level)
	return data

func get_spawn_info() -> Dictionary:
	var max_hp := get_max_health()
	var hp := cur_health if cur_health >= 0 else max_hp
	return {
		"id": id,
		"name": name,
		"path": model_path,
		"type": type,
		"element": element,
		"level": level,
		"exp": exp,
		"skill_nodes": skill_nodes.duplicate(true),
		"ult_charge": ult_charge,
		"attack": get_attack(),
		"max_health": max_hp,
		"health": clampi(hp, 0, max_hp),
		"defense": get_defense()
	}

func serialize() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"model_path": model_path,
		"type": type,
		"element": element,
		"level": level,
		"exp": exp,
		"skill_points": skill_points,
		"skill_nodes": skill_nodes.duplicate(true),
		"cur_health": cur_health,
		"base_health": base_health,
		"base_attack": base_attack,
		"base_defense": base_defense,
		"price": price
	}

static func deserialize(data: Dictionary) -> CharacterData:
	var c = CharacterData.new()
	c.id = str(data.get("id", ""))
	c.name = str(data.get("name", c.id))
	c.model_path = str(data.get("model_path", ""))
	c.type = int(data.get("type", 0))
	c.element = int(data.get("element", GameData.Element.FIRE))
	c.level = int(data.get("level", 1))
	c.exp = int(data.get("exp", 0))
	c.skill_points = int(data.get("skill_points", 1))
	c.skill_nodes = data.get("skill_nodes", {}).duplicate(true)
	c.cur_health = int(data.get("cur_health", -1))
	c.base_health = int(data.get("base_health", 100))
	c.base_attack = int(data.get("base_attack", 10))
	c.base_defense = int(data.get("base_defense", 10))
	c.price = int(data.get("price", 100))
	return c
