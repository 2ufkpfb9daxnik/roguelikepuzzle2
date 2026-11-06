class_name GameData
extends RefCounted

# ============================================================
# 属性・駒・成長の共通データ
# 戦闘 / ショップ / スキルツリーのすべてがここを参照する。
# 数値はデータとして分離し、バランス調整をコードから切り離す。
# ============================================================

enum Element {
	NONE = 0,
	FIRE = 1,
	WATER = 2,
	WIND = 3,
	THUNDER = 4,
	LIGHT = 5,
	DARK = 6,
	POISON = 7,
	ICE = 8,
	WOOD = 9,
	EARTH = 10
}

enum Piece {
	SHIELD = 0,
	SWORD = 1,
	COIN = 2,
	POTION = 3,
	FOOD = 4
}

const BASE_PIECE_COUNT := 5
const SKILL_PIECE_OFFSET := 4
const MAX_PARTY_SIZE := 3
const RECRUIT_CHANCE := 0.12

const ELEMENT_INFO := {
	Element.FIRE: {
		"key": "fire", "name": "火", "category": "force",
		"color": Color(1.0, 0.42, 0.20), "piece_name": "紅蓮",
		"ult": "紅蓮爆裂"
	},
	Element.WATER: {
		"key": "water", "name": "水", "category": "nature",
		"color": Color(0.30, 0.62, 1.0), "piece_name": "清流",
		"ult": "清流治癒"
	},
	Element.WIND: {
		"key": "wind", "name": "風", "category": "nature",
		"color": Color(0.40, 0.90, 0.45), "piece_name": "疾風",
		"ult": "疾風連刃"
	},
	Element.THUNDER: {
		"key": "thunder", "name": "雷", "category": "force",
		"color": Color(0.95, 0.90, 0.20), "piece_name": "雷電",
		"ult": "雷鳴落雷"
	},
	Element.LIGHT: {
		"key": "light", "name": "光", "category": "mystic",
		"color": Color(1.0, 0.92, 0.62), "piece_name": "聖光",
		"ult": "聖光降臨"
	},
	Element.DARK: {
		"key": "dark", "name": "闇", "category": "mystic",
		"color": Color(0.62, 0.35, 0.88), "piece_name": "冥影",
		"ult": "冥府吸収"
	},
	Element.POISON: {
		"key": "poison", "name": "毒", "category": "mystic",
		"color": Color(0.68, 0.32, 0.76), "piece_name": "瘴気",
		"ult": "腐蝕毒霧"
	},
	Element.ICE: {
		"key": "ice", "name": "氷", "category": "nature",
		"color": Color(0.55, 0.86, 1.0), "piece_name": "氷晶",
		"ult": "絶対零度"
	},
	Element.WOOD: {
		"key": "wood", "name": "木", "category": "nature",
		"color": Color(0.32, 0.82, 0.38), "piece_name": "生命",
		"ult": "生命の大樹"
	},
	Element.EARTH: {
		"key": "earth", "name": "地", "category": "force",
		"color": Color(0.82, 0.63, 0.32), "piece_name": "岩盤",
		"ult": "岩盤崩落"
	}
}

const CATEGORY_INFO := {
	"nature": {"name": "自然・生命", "elements": [Element.WATER, Element.ICE, Element.WOOD, Element.WIND]},
	"force": {"name": "元素・破壊", "elements": [Element.FIRE, Element.THUNDER, Element.EARTH]},
	"mystic": {"name": "神秘・冥術", "elements": [Element.POISON, Element.LIGHT, Element.DARK]}
}

# 敵味方の属性相性。ガイドの倍率をそのまま使用。
const STRONG_AGAINST := {
	Element.FIRE: [Element.WIND, Element.POISON],
	Element.WATER: [Element.FIRE],
	Element.WIND: [Element.THUNDER],
	Element.THUNDER: [Element.WATER],
	Element.LIGHT: [Element.DARK, Element.POISON],
	Element.DARK: [Element.LIGHT],
	Element.POISON: [Element.WATER, Element.WIND]
}

const WEAK_AGAINST := {
	Element.FIRE: [Element.WATER],
	Element.WATER: [Element.THUNDER, Element.POISON],
	Element.WIND: [Element.FIRE, Element.POISON],
	Element.THUNDER: [Element.WIND],
	Element.LIGHT: [],
	Element.DARK: [],
	Element.POISON: [Element.FIRE, Element.LIGHT]
}

# ============================================================
# 属性ヘルパー
# ============================================================
static func element_name(element: int) -> String:
	if ELEMENT_INFO.has(element):
		return ELEMENT_INFO[element]["name"]
	return "無"

static func element_key(element: int) -> String:
	if ELEMENT_INFO.has(element):
		return ELEMENT_INFO[element]["key"]
	return "none"

static func element_color(element: int) -> Color:
	if ELEMENT_INFO.has(element):
		return ELEMENT_INFO[element]["color"]
	return Color(0.7, 0.7, 0.7)

static func element_category(element: int) -> String:
	if ELEMENT_INFO.has(element):
		return ELEMENT_INFO[element]["category"]
	return ""

static func category_name(category: String) -> String:
	if CATEGORY_INFO.has(category):
		return CATEGORY_INFO[category]["name"]
	return "なし"

static func element_ult_name(element: int) -> String:
	if ELEMENT_INFO.has(element):
		return ELEMENT_INFO[element]["ult"]
	return "スキル"

static func piece_id_for_element(element: int) -> int:
	return SKILL_PIECE_OFFSET + element

static func element_for_piece(piece_id: int) -> int:
	if piece_id > SKILL_PIECE_OFFSET:
		return clampi(piece_id - SKILL_PIECE_OFFSET, 1, 10)
	return Element.NONE

static func is_skill_piece(piece_id: int) -> bool:
	return piece_id > SKILL_PIECE_OFFSET

static func base_piece_name(piece_id: int) -> String:
	match piece_id:
		Piece.SHIELD: return "shield"
		Piece.SWORD: return "sword"
		Piece.COIN: return "coin"
		Piece.POTION: return "potion"
		Piece.FOOD: return "bread"
	return ""

static func base_piece_label(piece_id: int) -> String:
	match piece_id:
		Piece.SHIELD: return "盾"
		Piece.SWORD: return "剣"
		Piece.COIN: return "コイン"
		Piece.POTION: return "ポーション"
		Piece.FOOD: return "回復"
	return "スキル"

# キャラクターのスキル属性（どの駒でスキルゲージが溜まるか）
static func skill_attribute_for_type(type: int) -> int:
	match type:
		0:
			return Piece.FOOD
		10:
			return Piece.SHIELD
		_:
			return Piece.SWORD

static func skill_attribute_name(attribute: int) -> String:
	match attribute:
		Piece.SHIELD:
			return "盾"
		Piece.FOOD:
			return "回復"
		_:
			return "剣"

static func skill_attribute_color(attribute: int) -> Color:
	match attribute:
		Piece.SHIELD:
			return Color(0.42, 0.68, 1.0)
		Piece.FOOD:
			return Color(0.45, 0.95, 0.55)
		_:
			return Color(1.0, 0.58, 0.30)

static func skill_attribute_piece(attribute: int) -> int:
	match attribute:
		Piece.SHIELD:
			return Piece.SHIELD
		Piece.FOOD:
			return Piece.FOOD
		_:
			return Piece.SWORD

static func damage_multiplier(attack_element: int, defense_element: int) -> float:
	if attack_element == Element.NONE or defense_element == Element.NONE:
		return 1.0
	if STRONG_AGAINST.get(attack_element, []).has(defense_element):
		return 1.5
	if WEAK_AGAINST.get(attack_element, []).has(defense_element):
		return 0.5
	return 1.0

# ============================================================
# キャラクター属性
# ============================================================
static func element_for_character(character_id: String, fallback_type: int = 4) -> int:
	var key := character_id.to_lower()
	match key:
		"aquatic_guardian", "kurione", "octopus", "sea_dragon":
			return Element.WATER
		"blue_dragon", "cave_dragon":
			return Element.ICE
		"wood_monster", "mushroom_man", "swamp_guardian":
			return Element.WOOD
		"stone_guardian", "skeleton":
			return Element.EARTH
		"bee", "rainbow_snake_dragon":
			return Element.WIND
		"scorpion", "spider", "snake_head":
			return Element.POISON
		"demon", "mysterious_mummy":
			return Element.DARK
		"enigmatic_sorcerer", "red_magician":
			return Element.FIRE
		"fantasy_wolf", "wolf":
			return Element.FIRE
		"plain_shop", "snow_shop":
			return Element.ICE
	# 既存の type は 0=回復, 4=単体, 8=全体, 10=魔法
	match fallback_type:
		0: return Element.WATER
		8: return Element.WIND
		10: return Element.DARK
		_: return Element.FIRE

# ============================================================
# 経験値・レベル
# ============================================================
static func exp_to_next_level(level: int) -> int:
	return int(20.0 + max(0, level - 1) * 16.0 + pow(max(0, level - 1), 1.35) * 4.0)

static func levelup_coin_cost(level: int) -> int:
	return int(50.0 * pow(1.28, max(0, level - 1)))

# ============================================================
# スキルツリー
# 各属性で名称と説明だけを差し替え、効果は共通構造にする。
# レリックノードも同じツリーに含める（レリックと進化の統一）。
# ============================================================
static func get_skill_tree(element: int) -> Array:
	var e := element_name(element)
	var info: Dictionary = ELEMENT_INFO.get(element, ELEMENT_INFO[Element.FIRE])
	var piece_name: String = info.get("piece_name", "属性")
	return [
		{
			"id": "offense_1", "branch": "offense", "type": "skill",
			"name": "%sの心得" % e,
			"desc": "攻撃力 +4 / Lv",
			"max_level": 3, "cost": 1, "requires": [], "requires_any": [],
			"char_level": 1, "exclusive_group": "",
			"effect": {"attack": 4}
		},
		{
			"id": "offense_2", "branch": "offense", "type": "skill",
			"name": "%s駒の研鑽" % piece_name,
			"desc": "スキル駒の威力 +12% / Lv",
			"max_level": 3, "cost": 1, "requires": ["offense_1"], "requires_any": [],
			"char_level": 3, "exclusive_group": "",
			"effect": {"skill_power": 0.12}
		},
		{
			"id": "evo_a", "branch": "offense", "type": "evolution",
			"name": "%s・極" % e,
			"desc": "進化: スキル駒の攻撃力 +50%、スキル威力 +20%",
			"max_level": 1, "cost": 2, "requires": ["offense_2"], "requires_any": [],
			"char_level": 6, "exclusive_group": "evolution",
			"effect": {"skill_power": 0.5, "ult_power": 0.2}
		},
		{
			"id": "evo_b", "branch": "offense", "type": "evolution",
			"name": "%s・護" % e,
			"desc": "進化: スキル駒消去時シールド +30、スキルで味方回復",
			"max_level": 1, "cost": 2, "requires": ["offense_2"], "requires_any": [],
			"char_level": 6, "exclusive_group": "evolution",
			"effect": {"skill_shield": 30, "ult_heal": 0.18}
		},
		{
			"id": "offense_3", "branch": "offense", "type": "skill",
			"name": "%sの極意" % e,
			"desc": "スキル威力 +25% / Lv",
			"max_level": 2, "cost": 2, "requires": [], "requires_any": ["evo_a", "evo_b"],
			"char_level": 8, "exclusive_group": "",
			"effect": {"ult_power": 0.25}
		},
		{
			"id": "guard_1", "branch": "guard", "type": "skill",
			"name": "生命の器",
			"desc": "最大HP +30 / Lv",
			"max_level": 3, "cost": 1, "requires": [], "requires_any": [],
			"char_level": 1, "exclusive_group": "",
			"effect": {"max_health": 30}
		},
		{
			"id": "guard_2", "branch": "guard", "type": "skill",
			"name": "堅牢なる守り",
			"desc": "防御力 +3 / Lv",
			"max_level": 3, "cost": 1, "requires": ["guard_1"], "requires_any": [],
			"char_level": 3, "exclusive_group": "",
			"effect": {"defense": 3}
		},
		{
			"id": "guard_relic", "branch": "guard", "type": "relic",
			"name": "古の守護像",
			"desc": "レリック: 戦闘開始時、味方全員にシールド +80 / Lv",
			"max_level": 2, "cost": 2, "requires": ["guard_2"], "requires_any": [],
			"char_level": 4, "exclusive_group": "",
			"effect": {"start_shield": 80}
		},
		{
			"id": "guard_3", "branch": "guard", "type": "skill",
			"name": "不壊の意志",
			"desc": "受けるダメージ -5% / Lv",
			"max_level": 2, "cost": 2, "requires": ["guard_relic"], "requires_any": [],
			"char_level": 7, "exclusive_group": "",
			"effect": {"damage_reduction": 0.05}
		},
		{
			"id": "fortune_1", "branch": "fortune", "type": "skill",
			"name": "商才",
			"desc": "獲得コイン +10% / Lv",
			"max_level": 3, "cost": 1, "requires": [], "requires_any": [],
			"char_level": 1, "exclusive_group": "",
			"effect": {"coin_bonus": 0.1}
		},
		{
			"id": "fortune_relic", "branch": "fortune", "type": "relic",
			"name": "経験の書",
			"desc": "レリック: 全員の獲得EXP +15% / Lv",
			"max_level": 2, "cost": 2, "requires": ["fortune_1"], "requires_any": [],
			"char_level": 3, "exclusive_group": "",
			"effect": {"exp_bonus": 0.15}
		},
		{
			"id": "element_relic", "branch": "fortune", "type": "relic",
			"name": "属性共鳴のレリック",
			"desc": "レリック: 味方全員の属性ダメージ +12% / Lv",
			"max_level": 2, "cost": 2, "requires": ["fortune_1"], "requires_any": [],
			"char_level": 5, "exclusive_group": "",
			"effect": {"element_bonus": 0.12}
		},
		{
			"id": "fortune_2", "branch": "fortune", "type": "skill",
			"name": "幸運の追い風",
			"desc": "クリティカル率 +4% / Lv",
			"max_level": 2, "cost": 2, "requires": [], "requires_any": ["fortune_relic", "element_relic"],
			"char_level": 8, "exclusive_group": "",
			"effect": {"crit_chance": 0.04}
		}
	]

static func get_skill_node(element: int, node_id: String) -> Dictionary:
	for node in get_skill_tree(element):
		if node["id"] == node_id:
			return node
	return {}

static func get_branch_nodes(element: int, branch: String) -> Array:
	var result: Array = []
	for node in get_skill_tree(element):
		if node["branch"] == branch:
			result.append(node)
	return result

static func branch_label(branch: String) -> String:
	match branch:
		"offense": return "攻撃・進化"
		"guard": return "守護・生命"
		"fortune": return "レリック・幸運"
	return branch

# キャラ固有ノードの効果（レリック以外）を合計する。
static func collect_character_modifiers(skill_nodes: Dictionary) -> Dictionary:
	var result := _empty_modifiers()
	for node_id in skill_nodes.keys():
		var level: int = int(skill_nodes[node_id])
		if level <= 0:
			continue
		var node := _find_node_anywhere(node_id)
		if node.is_empty() or node.get("type", "") == "relic":
			continue
		_add_effect(result, node.get("effect", {}), level)
	return result

# レリックノードは所持している全キャラ分を合算し、パーティ全体へ適用する。
static func collect_party_relic_modifiers(party: Array) -> Dictionary:
	var result := _empty_modifiers()
	for character in party:
		if character == null:
			continue
		var nodes: Dictionary = character.skill_nodes if "skill_nodes" in character else {}
		for node_id in nodes.keys():
			var level: int = int(nodes[node_id])
			if level <= 0:
				continue
			var node := _find_node_anywhere(node_id)
			if node.is_empty() or node.get("type", "") != "relic":
				continue
			_add_effect(result, node.get("effect", {}), level)
	return result

static func _find_node_anywhere(node_id: String) -> Dictionary:
	for element in ELEMENT_INFO.keys():
		var node := get_skill_node(element, node_id)
		if not node.is_empty():
			return node
	return {}

static func _empty_modifiers() -> Dictionary:
	return {
		"attack": 0.0,
		"defense": 0.0,
		"max_health": 0.0,
		"skill_power": 0.0,
		"ult_power": 0.0,
		"skill_shield": 0.0,
		"ult_heal": 0.0,
		"start_shield": 0.0,
		"damage_reduction": 0.0,
		"coin_bonus": 0.0,
		"exp_bonus": 0.0,
		"element_bonus": 0.0,
		"crit_chance": 0.0
	}

static func _add_effect(target: Dictionary, effects: Dictionary, level: int) -> void:
	for key in effects.keys():
		if target.has(key):
			target[key] += float(effects[key]) * level
		else:
			target[key] = float(effects[key]) * level
