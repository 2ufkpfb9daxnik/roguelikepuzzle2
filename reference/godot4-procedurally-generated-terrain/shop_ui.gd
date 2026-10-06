extends CanvasLayer

var party: Array = []
@onready var money_label: Label = $MoneyLabel
@onready var levelup_screen: Control = $LevelUpScreen
@onready var buy_character_screen: Control = $BuyCharacterScreen
@onready var buy_buff_screen: Control = $BuyBuffScreen

var type_to_img: Dictionary = {
	0: "res://texture/cell/bread.png",
	1: "res://texture/cell/coin.png",
	2: "res://texture/cell/potion.png",
	3: "res://texture/cell/shield.png",
	4: "res://texture/cell/sword.png",
	5: "res://texture/cell/arrow.png",
	6: "res://texture/cell/heal.png",
	7: "res://texture/cell/axe.png",
	8: "res://texture/cell/club.png",
	9: "res://texture/cell/magicCircle.png",
	10: "res://texture/cell/wand.png"
}

var char_scene = preload("res://LevelUpChar.tscn")
var char_scene1 = preload("res://BuyCharacterScreen.tscn")

func _ready() -> void:
	visible = false
	if has_node("MainMenu"):
		$MainMenu.visible = true
	if levelup_screen: levelup_screen.visible = false
	if buy_character_screen: buy_character_screen.visible = false
	if buy_buff_screen: buy_buff_screen.visible = false

func open_shop() -> void:
	visible = true
	if has_node("MainMenu"):
		$MainMenu.visible = true
	if levelup_screen: levelup_screen.visible = false
	if buy_character_screen: buy_character_screen.visible = false
	if buy_buff_screen: buy_buff_screen.visible = false
	var main_node = get_main_node()
	if main_node:
		main_node.isshoping = true
		if has_node("MoneyLabel") and money_label:
			money_label.text = "Money:" + str(main_node.money)
		if "player_node" in main_node and main_node.player_node and main_node.player_node.has_method("set_movement_enabled"):
			main_node.player_node.set_movement_enabled(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func get_main_node() -> Node:
	var curr: Node = self
	while curr:
		if curr.name == "main":
			return curr
		curr = curr.get_parent()
	return get_tree().current_scene

# =====================
# キャラレベルアップ画面生成
# =====================
func populate_levelup_characters() -> void:
	var vbox = levelup_screen.get_node("ScrollContainer/VBoxContainer")
	for child in vbox.get_children():
		child.queue_free()

	for char_data in get_friendly_characters():
		var char_instance = char_scene.instantiate()

		if ResourceLoader.exists(char_data["image_path"]):
			char_instance.get_node("ColorRect/Image").texture = load(char_data["image_path"])
		char_instance.get_node("ColorRect/Name").text = char_data["name"]
		char_instance.get_node("ColorRect/Type_single").texture = char_data["type_image_single"]
		char_instance.get_node("ColorRect/Type_all").texture = char_data["type_image_all"]
		char_instance.get_node("ColorRect/Money").text = "Money" + str(char_data["levelup_cost"])
		char_instance.get_node("ColorRect/Level").text = "Lv." + str(char_data["level"])
		char_instance.get_node("ColorRect/hp").text = "HP:" + str(char_data["hp"])
		char_instance.get_node("ColorRect/atk").text = "ATK:" + str(char_data["atk"])
		char_instance.get_node("ColorRect/def").text = "DEF:" + str(char_data["def"])

		char_instance.get_node("ColorRect/Levelup").pressed.connect(func() -> void:
			_on_levelup_pressed(char_data, char_instance, char_data["cnt"])
		)

		vbox.add_child(char_instance)

func _on_levelup_pressed(char_data: Dictionary, char_instance: Node, idx: int) -> void:
	var main_node = get_main_node()
	if not main_node: return

	if main_node.money >= char_data["levelup_cost"]:
		main_node.money -= char_data["levelup_cost"]

		if "party" in main_node and idx < main_node.party.size():
			main_node.party[idx].level_up()
			var c = main_node.party[idx]
			char_data["level"] = c.level
			char_data["levelup_cost"] = c.get_levelup_cost()
			char_data["hp"] = c.get_max_health()
			char_data["atk"] = c.get_attack()
			char_data["def"] = c.get_defense()
		else:
			char_data["level"] += 1
			char_data["levelup_cost"] = int(char_data["levelup_cost"] * 1.3)
			if "allies_level" in main_node and idx < main_node.allies_level.size():
				main_node.allies_level[idx] += 1
			char_data["hp"] = CharacterData.calculate_status(char_data["base_hp"], char_data["level"])
			char_data["atk"] = CharacterData.calculate_status(char_data["base_atk"], char_data["level"])
			char_data["def"] = CharacterData.calculate_status(char_data["base_def"], char_data["level"])

		char_instance.get_node("ColorRect/hp").text = "HP:" + str(char_data["hp"])
		char_instance.get_node("ColorRect/atk").text = "ATK:" + str(char_data["atk"])
		char_instance.get_node("ColorRect/def").text = "DEF:" + str(char_data["def"])
		char_instance.get_node("ColorRect/Money").text = "Money" + str(char_data["levelup_cost"])
		char_instance.get_node("ColorRect/Level").text = "Lv." + str(char_data["level"])

		if has_node("MoneyLabel"):
			money_label.text = "Money:" + str(main_node.money)

# =====================
# キャラ購入画面生成
# =====================
func populate_buy_characters() -> void:
	var vbox = buy_character_screen.get_node("ScrollContainer/VBoxContainer")
	for child in vbox.get_children():
		child.queue_free()

	for char_data in get_all_characters():
		var char_instance = char_scene1.instantiate()

		if ResourceLoader.exists(char_data["image_path"]):
			char_instance.get_node("ColorRect/Image").texture = load(char_data["image_path"])
		char_instance.get_node("ColorRect/Name").text = char_data["name"]
		char_instance.get_node("ColorRect/Type_single").texture = char_data["type_image_single"]
		char_instance.get_node("ColorRect/Type_all").texture = char_data["type_image_all"]
		char_instance.get_node("ColorRect/Money").text = "Money" + str(char_data["price"])
		char_instance.get_node("ColorRect/Level").text = "Lv." + str(char_data["level"])
		char_instance.get_node("ColorRect/hp").text = "HP:" + str(char_data["hp"])
		char_instance.get_node("ColorRect/atk").text = "ATK:" + str(char_data["atk"])
		char_instance.get_node("ColorRect/def").text = "DEF:" + str(char_data["def"])

		char_instance.get_node("ColorRect/Buy").pressed.connect(func() -> void:
			_on_buy_character_pressed(char_data)
		)

		vbox.add_child(char_instance)

func _on_buy_character_pressed(char_data: Dictionary) -> void:
	var main_node = get_main_node()
	if not main_node: return

	var current_party_size = main_node.party.size() if "party" in main_node else main_node.allies.size()
	if current_party_size >= 3:
		return

	if main_node.money >= char_data["price"]:
		main_node.money -= char_data["price"]
		if has_node("MoneyLabel"):
			money_label.text = "Money:" + str(main_node.money)
		add_character_to_party(char_data)

# =====================
# バフ購入画面生成
# =====================
func populate_buffs() -> void:
	var vbox = buy_buff_screen.get_node("ScrollContainer/VBoxContainer")
	for child in vbox.get_children():
		child.queue_free()

	for buff in get_all_buffs():
		var vbox_buff = VBoxContainer.new()
		var name_label = Label.new()
		name_label.text = buff["name"]
		var desc_label = Label.new()
		desc_label.text = buff["description"]
		var money_lbl = Label.new()
		money_lbl.text = str(buff["price"])
		var button = Button.new()
		button.text = "Buy"
		button.pressed.connect(func() -> void:
			_on_buy_buff_pressed(buff)
		)
		vbox_buff.add_child(name_label)
		vbox_buff.add_child(desc_label)
		vbox_buff.add_child(money_lbl)
		vbox_buff.add_child(button)
		vbox.add_child(vbox_buff)

func _on_buy_buff_pressed(buff: Dictionary) -> void:
	var main_node = get_main_node()
	if not main_node: return

	if main_node.money >= buff["price"]:
		main_node.money -= buff["price"]
		apply_buff(buff)
		if has_node("MoneyLabel"):
			money_label.text = "Money:" + str(main_node.money)

func get_type_images(ally_type: int) -> Array:
	var single_img = load(type_to_img.get(ally_type, "res://texture/cell/bread.png"))
	var all_img = null
	if ally_type == 0:
		all_img = load(type_to_img[6])
	elif ally_type == 4:
		all_img = load(type_to_img[7])
	elif ally_type == 8:
		all_img = load(type_to_img[5])
	else:
		all_img = load(type_to_img[9])
	return [single_img, all_img]

func get_friendly_characters() -> Array:
	var main_node = get_main_node()
	if not main_node: return []

	var res = []
	if "party" in main_node and main_node.party.size() > 0:
		for i in range(main_node.party.size()):
			var c: CharacterData = main_node.party[i]
			var img_path = "res://model/enemy/元画像/" + c.name + ".png"
			var type_imgs = get_type_images(c.type)
			res.append({
				"name": c.name,
				"image_path": img_path,
				"type_image_single": type_imgs[0],
				"type_image_all": type_imgs[1],
				"levelup_cost": c.get_levelup_cost(),
				"level": c.level,
				"hp": c.get_max_health(),
				"atk": c.get_attack(),
				"def": c.get_defense(),
				"cnt": i,
				"base_atk": c.base_attack,
				"base_hp": c.base_health,
				"base_def": c.base_defense
			})
	else:
		var ally_name = main_node.allies_name
		var ally_type = main_node.allies_type
		var ally_level = main_node.allies_level
		var ally_base_hp = main_node.allies_base_health
		var ally_base_atk = main_node.allies_base_attack
		var ally_base_def = main_node.allies_base_defense
		for i in range(ally_name.size()):
			var img_path = "res://model/enemy/元画像/" + ally_name[i] + ".png"
			var type_imgs = get_type_images(ally_type[i])
			var cost = int(10.0 * pow(1.3, ally_level[i] - 1))
			var hp = CharacterData.calculate_status(ally_base_hp[i], ally_level[i])
			var atk = CharacterData.calculate_status(ally_base_atk[i], ally_level[i])
			var def = CharacterData.calculate_status(ally_base_def[i], ally_level[i])
			res.append({
				"name": ally_name[i],
				"image_path": img_path,
				"type_image_single": type_imgs[0],
				"type_image_all": type_imgs[1],
				"levelup_cost": cost,
				"level": ally_level[i],
				"hp": hp,
				"atk": atk,
				"def": def,
				"cnt": i,
				"base_atk": ally_base_atk[i],
				"base_hp": ally_base_hp[i],
				"base_def": ally_base_def[i]
			})
	return res

func get_all_characters() -> Array:
	var main_node = get_main_node()
	if not main_node or not ("all_characters" in main_node): return []

	var chardict = main_node.all_characters
	var res = []
	for key in chardict.keys():
		var img_path = "res://model/enemy/元画像/" + key + ".png"
		var ally_type = chardict[key][3]
		var ally_level = 1
		var hp = CharacterData.calculate_status(chardict[key][0], ally_level)
		var atk = CharacterData.calculate_status(chardict[key][1], ally_level)
		var def = CharacterData.calculate_status(chardict[key][2], ally_level)
		var type_imgs = get_type_images(ally_type)
		res.append({
			"name": key,
			"image_path": img_path,
			"type_image_single": type_imgs[0],
			"type_image_all": type_imgs[1],
			"price": chardict[key][5],
			"hp": hp,
			"atk": atk,
			"def": def,
			"level": ally_level,
			"path": chardict[key][4],
			"type": ally_type,
			"key": key
		})
	return res

func get_all_buffs() -> Array:
	return [
		{"name": "Power Up", "description": "Increase attack", "price": 200},
		{"name": "Defense Up", "description": "Increase defense", "price": 150}
	]

func add_character_to_party(char_data: Dictionary) -> void:
	var main_node = get_main_node()
	if not main_node: return

	if main_node.has_method("add_character_by_id") and char_data.has("key"):
		main_node.add_character_by_id(char_data["key"])
	else:
		main_node.allies.append(char_data["path"])
		main_node.allies_name.append(char_data["name"])
		main_node.allies_type.append(char_data["type"])
		main_node.allies_level.append(char_data["level"])
		main_node.allies_base_health.append(char_data["hp"])
		main_node.allies_base_attack.append(char_data["atk"])
		main_node.allies_base_defense.append(char_data["def"])
		main_node.allies_cur_health.append(-1)

func apply_buff(buff: Dictionary) -> void:
	print("Buff applied: ", buff["name"])

# =====================
# メインメニュー遷移
# =====================
func _on_level_up_button_pressed() -> void:
	if has_node("MainMenu"): $MainMenu.visible = false
	levelup_screen.visible = true
	populate_levelup_characters()

func _on_buy_character_button_pressed() -> void:
	if has_node("MainMenu"): $MainMenu.visible = false
	buy_character_screen.visible = true
	populate_buy_characters()

func _on_buy_buff_button_pressed() -> void:
	if has_node("MainMenu"): $MainMenu.visible = false
	buy_buff_screen.visible = true
	populate_buffs()

func _on_close_button_pressed() -> void:
	# サブ画面が開いている場合はメインメニューに戻る
	if (levelup_screen and levelup_screen.visible) or (buy_character_screen and buy_character_screen.visible) or (buy_buff_screen and buy_buff_screen.visible):
		if levelup_screen: levelup_screen.visible = false
		if buy_character_screen: buy_character_screen.visible = false
		if buy_buff_screen: buy_buff_screen.visible = false
		if has_node("MainMenu"): $MainMenu.visible = true
		return

	# メインメニュー表示時はショップを閉じる
	if has_node("MainMenu"): $MainMenu.visible = true
	if levelup_screen: levelup_screen.visible = false
	if buy_character_screen: buy_character_screen.visible = false
	if buy_buff_screen: buy_buff_screen.visible = false
	visible = false

	var main_node = get_main_node()
	if main_node:
		main_node.isshoping = false
		if "player_node" in main_node and main_node.player_node and main_node.player_node.has_method("set_movement_enabled"):
			main_node.player_node.set_movement_enabled(true)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
