extends CanvasLayer

var money = 1000
var party = []
@onready var money_label = $MoneyLabel
@onready var levelup_screen = $LevelUpScreen
@onready var buy_character_screen = $BuyCharacterScreen
@onready var buy_buff_screen = $BuyBuffScreen

var type_to_img: Dictionary = {0:"res://texture/cell/bread.png",
1:"res://texture/cell/coin.png",2:"res://texture/cell/potion.png",
3:"res://texture/cell/shield.png",4:"res://texture/cell/sword.png",
5:"res://texture/cell/arrow.png",6:"res://texture/cell/heal.png",
7:"res://texture/cell/axe.png",8:"res://texture/cell/club.png",
9:"res://texture/cell/magicCircle.png",10:"res://texture/cell/wand.png"}
var char_scene = preload("res://LevelUpChar.tscn")
func _ready():
	$MainMenu.visible = true
	levelup_screen.visible = false
	buy_character_screen.visible = false
	buy_buff_screen.visible = false


# =====================
# キャラレベルアップ画面生成
# =====================
func populate_levelup_characters():
	var vbox = levelup_screen.get_node("ScrollContainer/VBoxContainer")
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()
	for char_data in get_friendly_characters():
		var char_instance = char_scene.instantiate()

		# 画像
		char_instance.get_node("ColorRect/Image").texture = char_data["image"]
		# 名前
		char_instance.get_node("ColorRect/Name").text = char_data["name"]
		# タイプ
		char_instance.get_node("ColorRect/Type_single").texture = char_data["type_image_single"]
		char_instance.get_node("ColorRect/Type_all").texture = char_data["type_image_all"]
		# お金
		char_instance.get_node("ColorRect/Money").text = str(char_data["levelup_cost"])
		# レベル
		char_instance.get_node("ColorRect/Level").text = str(char_data["level"])
		# ボタン押下時
		char_instance.get_node("ColorRect/Levelup").pressed.connect(func() -> void:
			_on_levelup_pressed(char_data)
		)

		vbox.add_child(char_instance)

func _on_levelup_pressed(char_data):
	if money >= char_data.levelup_cost:
		money -= char_data.levelup_cost
		char_data.level += 1
		money_label.text = str(money)

# =====================
# キャラ購入画面生成
# =====================
func populate_buy_characters():
	var vbox = buy_character_screen.get_node("ScrollContainer/VBoxContainer")
	vbox.clear()
	for char_data in get_all_characters():
		var hbox = HBoxContainer.new()
		# 左: キャラ画像
		var tex = TextureRect.new()
		tex.texture = char_data.image
		hbox.add_child(tex)

		# 中央: 名前・タイプ
		var vbox_center = VBoxContainer.new()
		var name_label = Label.new()
		name_label.text = char_data.name
		var type_img = TextureRect.new()
		type_img.texture = char_data.type_image
		vbox_center.add_child(name_label)
		vbox_center.add_child(type_img)
		hbox.add_child(vbox_center)

		# 右: 購入money・ボタン
		var vbox_right = VBoxContainer.new()
		var money_label_char = Label.new()
		money_label_char.text = str(char_data.price)
		var button = Button.new()
		button.text = "Buy"
		button.pressed.connect(func() -> void:
			_on_buy_character_pressed(char_data)
		)
		vbox_right.add_child(money_label_char)
		vbox_right.add_child(button)
		hbox.add_child(vbox_right)

		vbox.add_child(hbox)

func _on_buy_character_pressed(char_data):
	if money >= char_data.price:
		money -= char_data.price
		add_character_to_party(char_data)
		money_label.text = str(money)

# =====================
# バフ購入画面生成
# =====================
func populate_buffs():
	var vbox = buy_buff_screen.get_node("ScrollContainer/VBoxContainer")
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()
	for buff in get_all_buffs():
		var vbox_buff = VBoxContainer.new()
		var name_label = Label.new()
		name_label.text = buff.name
		var desc_label = Label.new()
		desc_label.text = buff.description
		var money_label_buff = Label.new()
		money_label_buff.text = str(buff.price)
		var button = Button.new()
		button.text = "Buy"
		button.pressed.connect(func() -> void:
			_on_buy_buff_pressed(buff)
		)
		vbox_buff.add_child(name_label)
		vbox_buff.add_child(desc_label)
		vbox_buff.add_child(money_label_buff)
		vbox_buff.add_child(button)
		vbox.add_child(vbox_buff)

func _on_buy_buff_pressed(buff):
	if money >= buff.price:
		money -= buff.price
		apply_buff(buff)
		money_label.text = str(money)
func get_levelup_cost(level: int) -> int:
	var base_cost = 10  # 初期コスト
	var cost = base_cost * pow(1.3, level - 1)
	return int(round(cost))
func get_friendly_characters():
	var res = []
	var ally_name = get_parent().allies_name
	var ally_type = get_parent().allies_type
	var ally_level = get_parent().allies_level
	for i in range(ally_name.size()):
		var image = load("res://model/enemy/元画像/"+ally_name[i]+".png")
		var type_image_single = load(type_to_img[ally_type[i]])
		var type_image_all
		if ally_type[i] == 0:
			type_image_all = load(type_to_img[6])
		elif ally_type[i] == 4:
			type_image_all = load(type_to_img[7])
		elif ally_type[i] == 8:
			type_image_all = load(type_to_img[5])
		else:
			type_image_all = load(type_to_img[9])
		var levelupcost = get_levelup_cost(ally_level[i])
		res.append({"name":ally_name[i], "image":image, "type_image_single":type_image_single, "type_image_all":type_image_all,"levelup_cost":levelupcost, "level":ally_level[i]})
	return res

func get_all_characters():
	var chardict = get_parent().all_characters
	var res = []
	for key in chardict.keys():
		var image = load("res://model/enemy/元画像/"+key+".png")
		var type_image = load(type_to_img[chardict[key][3]])
		res.append({"name":key, "image":image, "type_image":type_image, "price":chardict[key][5]})
	return res

func get_all_buffs():
	return [
		{"name":"Power Up", "description":"Increase attack", "price":200},
		{"name":"Defense Up", "description":"Increase defense", "price":150},
	]

func add_character_to_party(char_data):
	party.append(char_data)

func apply_buff(buff):
	# 仮に適用処理
	print("Buff applied: ", buff.name)
# =====================
# メインメニュー遷移
# =====================

func _on_level_up_button_pressed() -> void:
	print("a")
	$MainMenu.visible = false
	levelup_screen.visible = true
	populate_levelup_characters()


func _on_buy_character_button_pressed() -> void:
	print("b")
	$MainMenu.visible = false
	buy_buff_screen.visible = true
	populate_buffs()



func _on_buy_buff_button_pressed() -> void:
	print("c")
	$MainMenu.visible = true
	levelup_screen.visible = false
	buy_character_screen.visible = false
	buy_buff_screen.visible = false


func _on_close_button_pressed() -> void:
	get_node("CloseButton").get_parent().visible = false
	get_parent().isshoping = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
