extends CanvasLayer

# ============================================================
# ショップ / インベントリ
#  - コイン: レベルアップ、仲間の購入
#  - スキルポイント: キャラごとのスキルツリー解放
#  - レリックとスキル進化は同じツリーに統合
# UI はコードで構築し、データは main.party / CharacterData を直接参照する。
# ============================================================

var selected_char_index: int = 0
var recruit_stock: Array = []
var message_text: String = ""

var root_control: Control
var money_label: Label
var message_label: Label
var tabs: TabContainer
var level_box: VBoxContainer
var recruit_box: VBoxContainer
var inventory_root: VBoxContainer
var detail_label: Label

const COL_BG := Color(0.045, 0.06, 0.10, 0.97)
const COL_PANEL := Color(0.09, 0.11, 0.17, 0.98)
const COL_BORDER := Color(0.30, 0.45, 0.72, 0.85)
const COL_TEXT := Color(0.92, 0.95, 1.0)
const COL_SUBTEXT := Color(0.65, 0.73, 0.86)
const COL_GOLD := Color(1.0, 0.84, 0.28)

func _ready() -> void:
	layer = 50
	visible = false
	_build_ui()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()

func get_main_node() -> Node:
	var curr: Node = self
	while curr:
		if curr.name == "main":
			return curr
		curr = curr.get_parent()
	curr = get_tree().current_scene
	if curr and curr.name == "main":
		return curr
	return curr

# ============================================================
# UI 構築
# ============================================================
func _build_ui() -> void:
	root_control = Control.new()
	root_control.name = "ShopRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.01, 0.02, 0.04, 0.82)
	root_control.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 70)
	margin.add_theme_constant_override("margin_right", 70)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	root_control.add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(COL_BG, COL_BORDER, 14))
	margin.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	outer.add_child(header)

	var title := _label("SHOP / INVENTORY", 34, COL_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	money_label = _label("", 26, COL_GOLD)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(money_label)

	var close_button := Button.new()
	close_button.text = "閉じる ✖"
	close_button.custom_minimum_size = Vector2(120, 46)
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(_on_close_button_pressed)
	header.add_child(close_button)

	message_label = _label("", 16, Color(0.7, 0.9, 1.0))
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	outer.add_child(message_label)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 20)
	outer.add_child(tabs)

	level_box = _add_tab("レベルアップ")
	recruit_box = _add_tab("仲間を雇う")
	inventory_root = _add_tab("インベントリ / スキルツリー")

func _add_tab(tab_title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(scroll)

	var box := VBoxContainer.new()
	box.name = "Content"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	return box

func _label(text: String, font_size: int = 16, color: Color = COL_TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _style(bg: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _clear(box: VBoxContainer) -> void:
	for child in box.get_children():
		child.queue_free()

# ============================================================
# 開閉
# ============================================================
func open_shop() -> void:
	visible = true
	var main_node := get_main_node()
	if main_node:
		main_node.isshoping = true
		if "player_node" in main_node and main_node.player_node and main_node.player_node.has_method("set_movement_enabled"):
			main_node.player_node.set_movement_enabled(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	message_text = ""
	_ensure_recruit_stock()
	_refresh_all()
	if tabs:
		tabs.current_tab = 0

func _on_close_button_pressed() -> void:
	visible = false
	var main_node := get_main_node()
	if main_node:
		main_node.isshoping = false
		if "player_node" in main_node and main_node.player_node and main_node.player_node.has_method("set_movement_enabled"):
			main_node.player_node.set_movement_enabled(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _refresh_all() -> void:
	var main_node := get_main_node()
	if main_node and money_label:
		money_label.text = "コイン: %d" % int(main_node.money)
	if message_label:
		message_label.text = message_text
	_populate_levelup()
	_populate_recruit()
	_populate_inventory()

# ============================================================
# レベルアップ
# ============================================================
func _populate_levelup() -> void:
	_clear(level_box)
	var main_node := get_main_node()
	if not main_node:
		return
	var party: Array = main_node.party
	level_box.add_child(_label("コインを使ってキャラクターをレベルアップ。レベルアップでスキルポイント +1。", 15, COL_SUBTEXT))
	for i in range(party.size()):
		var c: CharacterData = party[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(COL_PANEL, c.get_element_color().darkened(0.2)))
		level_box.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		row.add_child(info)

		info.add_child(_label("%s  Lv.%d  [%s / %s]  SP:%d" % [
			_display(c.id), c.level, c.get_element_name(), c.get_skill_attribute_name(), c.skill_points
		], 22, c.get_element_color()))
		info.add_child(_label("HP %d  ATK %d  DEF %d" % [c.get_max_health(), c.get_attack(), c.get_defense()], 16, COL_SUBTEXT))

		var exp_bar := ProgressBar.new()
		exp_bar.custom_minimum_size = Vector2(0, 16)
		exp_bar.max_value = c.get_exp_to_next()
		exp_bar.value = c.exp
		exp_bar.show_percentage = false
		info.add_child(exp_bar)
		info.add_child(_label("EXP %d / %d" % [c.exp, c.get_exp_to_next()], 13, COL_SUBTEXT))

		var cost := c.get_levelup_cost()
		var button := Button.new()
		button.text = "Lv.UP\n%d コイン" % cost
		button.custom_minimum_size = Vector2(150, 76)
		button.add_theme_font_size_override("font_size", 17)
		button.disabled = int(main_node.money) < cost
		button.pressed.connect(_on_levelup.bind(i))
		row.add_child(button)

func _on_levelup(index: int) -> void:
	var main_node := get_main_node()
	if not main_node or index < 0 or index >= main_node.party.size():
		return
	var c: CharacterData = main_node.party[index]
	var cost := c.get_levelup_cost()
	if not main_node.spend_money(cost):
		message_text = "コインが足りません。"
		_refresh_all()
		return
	c.level_up_with_coin()
	message_text = "%s が Lv.%d になった！ スキルポイント +1" % [_display(c.id), c.level]
	_ensure_recruit_stock()
	_refresh_all()

# ============================================================
# 仲間の購入
# ============================================================
func _ensure_recruit_stock() -> void:
	var main_node := get_main_node()
	if not main_node or not ("all_characters" in main_node):
		return
	var party_ids := {}
	for c in main_node.party:
		party_ids[c.id] = true
	var candidates: Array = []
	for id in main_node.all_characters.keys():
		if not party_ids.has(id):
			candidates.append(id)
	# 全候補を価格順に並べる。ランダムに6人だけ出すと、所持金で
	# 雇えるキャラが候補にいないことがあるため、常に全員から選べるようにする。
	candidates.sort_custom(func(a, b):
		var ca: Array = main_node.all_characters.get(a, [])
		var cb: Array = main_node.all_characters.get(b, [])
		var pa := int(ca[5]) if ca.size() > 5 else 999999
		var pb := int(cb[5]) if cb.size() > 5 else 999999
		if pa == pb:
			return str(a) < str(b)
		return pa < pb
	)
	recruit_stock = candidates

func _populate_recruit() -> void:
	_clear(recruit_box)
	var main_node := get_main_node()
	if not main_node:
		return
	var party_size: int = main_node.party.size()
	recruit_box.add_child(_label("パーティは最大3体。倒した敵が低確率で仲間になることもあります。 (%d/3)" % party_size, 15, COL_SUBTEXT))
	if party_size >= GameData.MAX_PARTY_SIZE:
		recruit_box.add_child(_label("パーティが満員です。これ以上は雇えません。", 18, Color(1.0, 0.55, 0.45)))
		return

	var visible_count := 0
	for id in recruit_stock:
		if not main_node.all_characters.has(id):
			continue
		var already_owned := false
		for c in main_node.party:
			if c.id == id:
				already_owned = true
				break
		if already_owned:
			continue
		visible_count += 1
		var config: Array = main_node.all_characters[id]
		var level := 1
		var hp := CharacterData.calculate_status(config[0], level)
		var atk := CharacterData.calculate_status(config[1], level)
		var def := CharacterData.calculate_status(config[2], level)
		var element := GameData.element_for_character(id, int(config[3]))
		var price := int(config[5]) if config.size() > 5 else 1000

		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(COL_PANEL, GameData.element_color(element).darkened(0.2)))
		recruit_box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(_label("%s  [%s / スキル:%s]" % [
			_display(id), GameData.element_name(element), GameData.skill_attribute_name(GameData.skill_attribute_for_type(int(config[3])))
		], 22, GameData.element_color(element)))
		info.add_child(_label("Lv.1  HP %d  ATK %d  DEF %d" % [hp, atk, def], 16, COL_SUBTEXT))
		info.add_child(_label("属性: %s  カテゴリ: %s" % [GameData.element_name(element), GameData.category_name(GameData.element_category(element))], 13, COL_SUBTEXT))

		var button := Button.new()
		button.text = "雇う\n%d コイン" % price
		button.custom_minimum_size = Vector2(150, 76)
		button.add_theme_font_size_override("font_size", 17)
		button.disabled = int(main_node.money) < price
		button.pressed.connect(_on_buy_character.bind(id, price))
		row.add_child(button)

	if visible_count == 0:
		recruit_box.add_child(_label("現在雇える仲間はいません。", 18, COL_SUBTEXT))
	else:
		recruit_box.add_child(_label("候補は価格の安い順に表示しています。コインが足りないキャラはボタンが無効です。", 13, COL_SUBTEXT))

func _on_buy_character(char_id: String, price: int) -> void:
	var main_node := get_main_node()
	if not main_node:
		return
	if not main_node.can_recruit_more():
		message_text = "パーティが満員です。"
		_refresh_all()
		return
	if int(main_node.money) < price:
		message_text = "コインが足りません。"
		_refresh_all()
		return
	var new_member: CharacterData = main_node.add_character_by_id(char_id)
	if new_member == null:
		message_text = "仲間にできませんでした。"
		_refresh_all()
		return
	main_node.spend_money(price)
	recruit_stock.erase(char_id)
	message_text = "%s が仲間になった！" % _display(char_id)
	_refresh_all()

# ============================================================
# スキルツリー / インベントリ
# ============================================================
func _populate_inventory() -> void:
	_clear(inventory_root)
	var main_node := get_main_node()
	if not main_node or main_node.party.is_empty():
		inventory_root.add_child(_label("キャラクターがいません。", 18, COL_SUBTEXT))
		return

	selected_char_index = clampi(selected_char_index, 0, main_node.party.size() - 1)
	var party: Array = main_node.party
	var selected: CharacterData = party[selected_char_index]

	inventory_root.add_child(_label("キャラクター", 16, COL_SUBTEXT))
	var selector := HBoxContainer.new()
	selector.add_theme_constant_override("separation", 10)
	inventory_root.add_child(selector)
	for i in range(party.size()):
		var c: CharacterData = party[i]
		var button := Button.new()
		button.text = "%s\nLv.%d [%s]" % [_display(c.id), c.level, c.get_element_name()]
		button.custom_minimum_size = Vector2(0, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		button.disabled = i == selected_char_index
		button.pressed.connect(_on_select_character.bind(i))
		selector.add_child(button)

	# 選択中キャラクターのステータス
	var status_panel := PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel", _style(COL_PANEL, selected.get_element_color().darkened(0.15)))
	inventory_root.add_child(status_panel)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 28)
	status_panel.add_child(status_row)

	var basic := VBoxContainer.new()
	basic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	basic.add_theme_constant_override("separation", 4)
	status_row.add_child(basic)

	basic.add_child(_label("%s  Lv.%d  [%s / %s]  %s" % [
		_display(selected.id), selected.level, selected.get_element_name(),
		selected.get_skill_attribute_name(),
		GameData.category_name(GameData.element_category(selected.element))
	], 24, selected.get_element_color()))

	var max_hp := selected.get_max_health()
	var cur_hp := selected.cur_health if selected.cur_health >= 0 else max_hp
	basic.add_child(_label("HP %d / %d    ATK %d    DEF %d" % [
		clampi(cur_hp, 0, max_hp), max_hp, selected.get_attack(), selected.get_defense()
	], 16, COL_TEXT))

	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 16)
	hp_bar.max_value = max_hp
	hp_bar.value = clampi(cur_hp, 0, max_hp)
	hp_bar.show_percentage = false
	basic.add_child(hp_bar)

	var exp_bar := ProgressBar.new()
	exp_bar.custom_minimum_size = Vector2(0, 12)
	exp_bar.max_value = selected.get_exp_to_next()
	exp_bar.value = selected.exp
	exp_bar.show_percentage = false
	basic.add_child(exp_bar)
	basic.add_child(_label("EXP %d / %d" % [selected.exp, selected.get_exp_to_next()], 13, COL_SUBTEXT))

	var points_box := VBoxContainer.new()
	points_box.custom_minimum_size = Vector2(230, 0)
	points_box.add_theme_constant_override("separation", 3)
	status_row.add_child(points_box)
	points_box.add_child(_label("スキルポイント", 14, COL_SUBTEXT))
	points_box.add_child(_label("%d SP" % selected.skill_points, 30, COL_GOLD))
	points_box.add_child(_label("解放ノード: %d / %d" % [_unlocked_count(selected), selected.get_skill_tree().size()], 14, COL_TEXT))
	points_box.add_child(_label("スキルゲージ: %d%%" % selected.ult_charge, 14, COL_TEXT))

	# 所持品（習得済みスキル・パーティ共通レリック）
	inventory_root.add_child(_label("所持品 / レリック", 22, COL_GOLD))
	var inventory_row := HBoxContainer.new()
	inventory_row.add_theme_constant_override("separation", 12)
	inventory_root.add_child(inventory_row)
	inventory_row.add_child(_create_owned_nodes_panel(selected))
	inventory_row.add_child(_create_relic_overview_panel(main_node))

	# スキルツリー
	inventory_root.add_child(_label("スキルツリー", 22, COL_GOLD))
	inventory_root.add_child(_label("ノードを解放すると能力が上がる。オレンジ枠はレリック、紫枠はスキル進化（同じ分岐から1つだけ）。", 14, COL_SUBTEXT))

	var tree_row := HBoxContainer.new()
	tree_row.add_theme_constant_override("separation", 12)
	tree_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_root.add_child(tree_row)

	for branch in ["offense", "guard", "fortune"]:
		var column := PanelContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_stylebox_override("panel", _style(Color(0.055, 0.07, 0.11, 0.95), COL_BORDER.darkened(0.3)))
		tree_row.add_child(column)
		var column_box := VBoxContainer.new()
		column_box.add_theme_constant_override("separation", 6)
		column.add_child(column_box)
		column_box.add_child(_label(GameData.branch_label(branch), 19, COL_GOLD))

		for node in GameData.get_branch_nodes(selected.element, branch):
			var button := _create_node_button(selected, node)
			column_box.add_child(button)

func _create_owned_nodes_panel(character: CharacterData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color(0.055, 0.07, 0.11, 0.95), character.get_element_color().darkened(0.35)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	box.add_child(_label("%s の習得済みスキル" % _display(character.id), 17, character.get_element_color()))

	var shown := 0
	for node in character.get_skill_tree():
		var node_id := str(node.get("id", ""))
		var level := character.get_node_level(node_id)
		if level <= 0:
			continue
		shown += 1
		var type := str(node.get("type", "skill"))
		var prefix := ""
		var color := COL_TEXT
		if type == "relic":
			prefix = "◆ "
			color = Color(1.0, 0.72, 0.32)
		elif type == "evolution":
			prefix = "★ "
			color = Color(0.82, 0.58, 1.0)
		box.add_child(_label("%s%s  Lv.%d/%d" % [
			prefix, str(node.get("name", node_id)), level, int(node.get("max_level", 1))
		], 14, color))

	if shown == 0:
		box.add_child(_label("まだスキルを習得していません。", 14, COL_SUBTEXT))
	return panel

func _create_relic_overview_panel(main_node: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color(0.055, 0.07, 0.11, 0.95), Color(1.0, 0.62, 0.20).darkened(0.35)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	box.add_child(_label("パーティ共通レリック", 17, Color(1.0, 0.72, 0.32)))

	var relic_lines := _party_relic_lines(main_node.party)
	if relic_lines.is_empty():
		box.add_child(_label("レリック未所持（スキルツリーの橙枠ノードで取得）", 14, COL_SUBTEXT))
	else:
		for line in relic_lines:
			box.add_child(_label(str(line), 14, Color(1.0, 0.84, 0.45)))

	box.add_child(_label("合計効果: %s" % _modifier_summary(GameData.collect_party_relic_modifiers(main_node.party)), 13, COL_SUBTEXT))
	return panel

func _party_relic_lines(party: Array) -> Array:
	var lines: Array = []
	for character in party:
		if character == null:
			continue
		var owned: Array = []
		for node_id in character.skill_nodes.keys():
			var level := int(character.skill_nodes[node_id])
			if level <= 0:
				continue
			var node := GameData.get_skill_node(character.element, str(node_id))
			if node.is_empty() or str(node.get("type", "")) != "relic":
				continue
			owned.append("%s Lv.%d" % [str(node.get("name", node_id)), level])
		if not owned.is_empty():
			lines.append("%s: %s" % [_display(character.id), " / ".join(PackedStringArray(owned))])
	return lines

func _modifier_summary(mods: Dictionary) -> String:
	var percent_labels := {
		"skill_power": "スキル駒威力",
		"ult_power": "スキル威力",
		"ult_heal": "スキル回復",
		"damage_reduction": "被ダメ軽減",
		"coin_bonus": "コイン獲得",
		"exp_bonus": "EXP獲得",
		"element_bonus": "属性ダメージ",
		"crit_chance": "クリティカル率"
	}
	var flat_labels := {
		"attack": "攻撃力",
		"defense": "防御力",
		"max_health": "最大HP",
		"skill_shield": "スキル駒シールド",
		"start_shield": "開始シールド"
	}
	var parts: Array = []
	for key in percent_labels.keys():
		var value := float(mods.get(key, 0.0))
		if absf(value) >= 0.001:
			parts.append("%s +%d%%" % [percent_labels[key], int(round(value * 100.0))])
	for key in flat_labels.keys():
		var value := float(mods.get(key, 0.0))
		if absf(value) >= 0.001:
			parts.append("%s +%d" % [flat_labels[key], int(round(value))])
	if parts.is_empty():
		return "なし"
	return " / ".join(PackedStringArray(parts))

func _create_node_button(character: CharacterData, node: Dictionary) -> Button:
	var node_id: String = str(node.get("id", ""))
	var level := character.get_node_level(node_id)
	var max_level := int(node.get("max_level", 1))
	var type: String = str(node.get("type", "skill"))
	var prefix := ""
	var border := GameData.element_color(character.element)
	if type == "relic":
		prefix = "◆レリック  "
		border = Color(1.0, 0.62, 0.20)
	elif type == "evolution":
		prefix = "★進化  "
		border = Color(0.78, 0.45, 1.0)

	var state_text := ""
	if level >= max_level:
		state_text = "習得済み Lv.%d" % level
	elif level > 0:
		state_text = "Lv.%d / %d  （さらに強化可）" % [level, max_level]
	else:
		state_text = "未習得 / %d" % max_level

	var button := Button.new()
	button.text = "%s%s\n%s\n%s  SP:%d" % [
		prefix, str(node.get("name", "")), str(node.get("desc", "")), state_text, int(node.get("cost", 1))
	]
	button.custom_minimum_size = Vector2(0, 108)
	button.add_theme_font_size_override("font_size", 13)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.tooltip_text = _node_requirement_text(character, node)
	button.disabled = not character.can_unlock_node(node)
	button.add_theme_stylebox_override("normal", _style(COL_PANEL, border.darkened(0.15)))
	button.add_theme_stylebox_override("hover", _style(COL_PANEL.lightened(0.08), border))
	button.add_theme_stylebox_override("disabled", _style(Color(0.06, 0.07, 0.09, 0.85), Color(0.18, 0.20, 0.26)))
	button.pressed.connect(_on_unlock_node.bind(node_id))
	return button

func _node_requirement_text(character: CharacterData, node: Dictionary) -> String:
	var lines: Array = []
	var required_level := int(node.get("char_level", 1))
	if character.level < required_level:
		lines.append("必要キャラLv: %d" % required_level)
	var required: Array = node.get("requires", [])
	for req_id in required:
		if character.get_node_level(str(req_id)) <= 0:
			var req_node := GameData.get_skill_node(character.element, str(req_id))
			lines.append("前提: %s" % str(req_node.get("name", req_id)))
	var any_req: Array = node.get("requires_any", [])
	if not any_req.is_empty():
		var any_ok := false
		for req_id in any_req:
			if character.get_node_level(str(req_id)) > 0:
				any_ok = true
		if not any_ok:
			lines.append("前提: 進化ノードのいずれか")
	if character.skill_points < int(node.get("cost", 1)):
		lines.append("スキルポイント不足")
	if lines.is_empty():
		return "解放可能"
	return "\n".join(lines)

func _on_select_character(index: int) -> void:
	selected_char_index = index
	_populate_inventory()

func _on_unlock_node(node_id: String) -> void:
	var main_node := get_main_node()
	if not main_node or selected_char_index >= main_node.party.size():
		return
	var c: CharacterData = main_node.party[selected_char_index]
	if c.unlock_skill_node(node_id):
		var node := GameData.get_skill_node(c.element, node_id)
		message_text = "%s を解放した！" % str(node.get("name", node_id))
	else:
		message_text = "条件を満たしていません。"
	_refresh_all()

func _unlocked_count(character: CharacterData) -> int:
	var total := 0
	for node_id in character.skill_nodes.keys():
		if int(character.skill_nodes[node_id]) > 0:
			total += 1
	return total

func _display(id) -> String:
	var text := str(id)
	if text == "":
		return "?"
	return text.replace("_", " ").capitalize()
