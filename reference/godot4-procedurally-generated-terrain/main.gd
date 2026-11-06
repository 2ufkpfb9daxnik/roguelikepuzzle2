extends Node3D

@onready var shop_ui = get_node_or_null("ShopUi") if has_node("ShopUi") else get_node_or_null("CanvasLayer/ShopUI")
@onready var player_node: CharacterBody3D = $CharacterBody3D
@onready var terrain_node: Node3D = get_node_or_null("terrain")

# ==============================
# パーティデータ管理 (CharacterData による一元管理)
# ==============================
var party: Array[CharacterData] = []
var isshoping: bool = false
var money: int = 500
const MAX_PARTY_SIZE: int = 3
var minimap_root: Control
var minimap_container: SubViewportContainer
var minimap_viewport: SubViewport
var minimap_camera: Camera3D
var minimap_local_zoom: float = 55.0
var minimap_big_zoom_mult: float = 1.05
var _is_underground_cached: bool = false
var underground_texture_rect: TextureRect
var underground_image: Image
var underground_tex: ImageTexture
var player_marker: ColorRect
var castle_texture_rect: TextureRect
var poi_container: Control
var poi_marker_nodes: Dictionary = {}
var _minimap_render_timer: float = 0.0
var _last_hud_money: int = -999999
var _last_hud_biome: String = ""

# 全キャラクターのマスター定義
# [base_hp, base_atk, base_def, type, model_path, price]
var all_characters: Dictionary = {
	"aquatic_guardian": [80, 15, 25, 0, "res://model/enemy/have_animation/aquatic_guardian/", 300],
	"bee": [25, 45, 5, 8, "res://model/enemy/have_animation/bee/", 500],
	"blue_dragon": [155, 75, 65, 4, "res://model/enemy/have_animation/blue_dragon/", 50000],
	"cave_dragon": [155, 75, 65, 8, "res://model/enemy/have_animation/cave_dragon/", 15000],
	"demon": [475, 125, 135, 10, "res://model/enemy/have_animation/demon/", 1000000],
	"enigmatic_sorcerer": [75, 45, 15, 10, "res://model/enemy/have_animation/enigmatic_sorcerer/", 100000],
	"fantasy_wolf": [95, 45, 35, 4, "res://model/enemy/have_animation/fantasy_wolf/", 1500],
	"kurione": [65, 15, 5, 0, "res://model/enemy/have_animation/kurione/", 150000],
	"mushroom_man": [170, 35, 345, 0, "res://model/enemy/have_animation/mushroom_man/", 7000],
	"mysterious_mummy": [90, 25, 35, 4, "res://model/enemy/have_animation/mysterious_mummy/", 5000],
	"octopus": [100, 15, 25, 10, "res://model/enemy/have_animation/octopus/", 250000],
	"rainbow_snake_dragon": [76, 75, 65, 8, "res://model/enemy/have_animation/rainbow_snake_dragon/", 150000],
	"red_magician": [155, 65, 54, 10, "res://model/enemy/have_animation/red_magician/", 350000],
	"scorpion": [95, 45, 35, 8, "res://model/enemy/have_animation/scorpion/", 10000],
	"sea_dragon": [155, 75, 85, 10, "res://model/enemy/have_animation/sea_dragon/", 1200],
	"snake_head": [75, 35, 25, 8, "res://model/enemy/have_animation/snake_head/", 10000],
	"spider": [45, 35, 15, 4, "res://model/enemy/have_animation/spider/", 7000],
	"skeleton": [150, 80, 50, 4, "res://model/enemy/have_animation/skeleton/", 8000],
	"stone_guardian": [95, 55, 95, 4, "res://model/enemy/have_animation/stone_guardian/", 2000],
	"swamp_guardian": [85, 55, 95, 0, "res://model/enemy/have_animation/swamp_guardian/", 6000],
	"wood_monster": [75, 45, 55, 10, "res://model/enemy/have_animation/wood_monster/", 30000],
	"wolf": [120, 55, 45, 4, "res://model/enemy/have_animation/wolf/", 2500]
}

# ==============================
# ショップバフ（戦闘・盤面に反映）
# ==============================
var shop_buff_catalog: Array[Dictionary] = [
	{"id": "attack", "name": "攻撃強化", "description": "味方全員の攻撃力が Lv ごとに +15% される。", "base_cost": 80, "cost_growth": 1.60, "max_level": 10},
	{"id": "defense", "name": "防御強化", "description": "味方全員の防御力が Lv ごとに +15% される。", "base_cost": 80, "cost_growth": 1.60, "max_level": 10},
	{"id": "heal", "name": "回復強化", "description": "回復マッチと回復スキルの回復量が Lv ごとに +20% される。", "base_cost": 60, "cost_growth": 1.55, "max_level": 10},
	{"id": "money", "name": "獲得金額強化", "description": "コインで獲得するお金が Lv ごとに +25% される。", "base_cost": 100, "cost_growth": 1.60, "max_level": 10},
	{"id": "max_hp", "name": "最大HP強化", "description": "味方全員の最大HPが Lv ごとに +12% される（次回戦闘から）。", "base_cost": 120, "cost_growth": 1.65, "max_level": 10},
	{"id": "potion", "name": "ポーション強化", "description": "フィーバーゲージ獲得量 +25%/Lv、フィーバー倍率 +0.25/Lv。", "base_cost": 90, "cost_growth": 1.60, "max_level": 10},
	{"id": "start_shield", "name": "開始シールド", "description": "戦闘開始時にパーティシールドが +5/Lv される。", "base_cost": 70, "cost_growth": 1.55, "max_level": 10},
	{"id": "combo", "name": "コンボ強化", "description": "コンボ倍率の上昇量が +0.05/Lv される。", "base_cost": 150, "cost_growth": 1.70, "max_level": 10},
	{"id": "sword_extra", "name": "剣の追撃", "description": "剣をマッチした時、Lv 個のランダムな駒を追加で消す。", "base_cost": 200, "cost_growth": 1.80, "max_level": 5},
	{"id": "food_extra", "name": "食料の追撃", "description": "回復駒をマッチした時、Lv 個のランダムな駒を追加で消す。", "base_cost": 150, "cost_growth": 1.75, "max_level": 5},
	{"id": "coin_extra", "name": "コインの追撃", "description": "コインをマッチした時、Lv 個のランダムな駒を追加で消す。", "base_cost": 150, "cost_growth": 1.75, "max_level": 5},
	{"id": "shield_extra", "name": "盾の追撃", "description": "盾をマッチした時、Lv 個のランダムな駒を追加で消す。", "base_cost": 150, "cost_growth": 1.75, "max_level": 5}
]
var shop_buff_levels: Dictionary = {}

func get_shop_buff_catalog() -> Array:
	return shop_buff_catalog

func get_shop_buff_definition(id: String) -> Dictionary:
	for info in shop_buff_catalog:
		if str(info["id"]) == id:
			return info
	return {}

func get_shop_buff_level(id: String) -> int:
	return int(shop_buff_levels.get(id, 0))

func get_shop_buff_cost(id: String) -> int:
	var info = get_shop_buff_definition(id)
	if info.is_empty():
		return 0
	var lvl = get_shop_buff_level(id)
	return int(int(info["base_cost"]) * pow(float(info["cost_growth"]), lvl))

func purchase_shop_buff(id: String) -> Dictionary:
	var info = get_shop_buff_definition(id)
	if info.is_empty():
		return {"ok": false, "reason": "unknown"}
	var lvl = get_shop_buff_level(id)
	if lvl >= int(info["max_level"]):
		return {"ok": false, "reason": "max", "level": lvl}
	var cost = get_shop_buff_cost(id)
	if not spend_money(cost):
		return {"ok": false, "reason": "money", "cost": cost}
	shop_buff_levels[id] = lvl + 1
	return {"ok": true, "cost": cost, "level": lvl + 1}

func get_board_buff_config() -> Dictionary:
	return {
		"sword_extra": get_shop_buff_level("sword_extra"),
		"food_extra": get_shop_buff_level("food_extra"),
		"coin_extra": get_shop_buff_level("coin_extra"),
		"shield_extra": get_shop_buff_level("shield_extra")
	}

# ==============================
# 後方互換用プロパティ（外部スクリプトの直接参照用）
# ==============================
var allies: Array:
	get:
		var arr = []
		for c in party: arr.append(c.model_path)
		return arr
	set(v):
		_sync_from_legacy_arrays("allies", v)

var allies_name: Array:
	get:
		var arr = []
		for c in party: arr.append(c.name)
		return arr
	set(v):
		_sync_from_legacy_arrays("allies_name", v)

var allies_type: Array:
	get:
		var arr = []
		for c in party: arr.append(c.type)
		return arr
	set(v):
		_sync_from_legacy_arrays("allies_type", v)

var allies_level: Array:
	get:
		var arr = []
		for c in party: arr.append(c.level)
		return arr
	set(v):
		_sync_from_legacy_arrays("allies_level", v)

var allies_base_health: Array:
	get:
		var arr = []
		for c in party: arr.append(c.base_health)
		return arr
	set(v):
		_sync_from_legacy_arrays("allies_base_health", v)

var allies_base_attack: Array:
	get:
		var arr = []
		for c in party: arr.append(c.base_attack)
		return arr
	set(v):
		_sync_from_legacy_arrays("allies_base_attack", v)

var allies_base_defense: Array:
	get:
		var arr = []
		for c in party: arr.append(c.base_defense)
		return arr
	set(v):
		_sync_from_legacy_arrays("allies_base_defense", v)

var allies_cur_health: Array:
	get:
		var arr = []
		for c in party: arr.append(c.cur_health)
		return arr
	set(v):
		_sync_from_legacy_arrays("allies_cur_health", v)

func _sync_from_legacy_arrays(prop_name: String, values: Array) -> void:
	# 外部からの個別代入（例: allies_cur_health[i] = ...）に対応
	for i in range(min(party.size(), values.size())):
		match prop_name:
			"allies_level": party[i].level = values[i]
			"allies_cur_health": party[i].cur_health = values[i]
			"allies_base_health": party[i].base_health = values[i]
			"allies_base_attack": party[i].base_attack = values[i]
			"allies_base_defense": party[i].base_defense = values[i]

func _ready() -> void:
	if not terrain_node:
		terrain_node = get_node_or_null("terrain")
	# 初期パーティ登録（red_magician）
	add_character_by_id("red_magician")
	_setup_hud()
	_setup_pause_menu()
	_setup_loading_screen()
	_setup_minimap()
	_setup_fill_light()
	_setup_shop_signals()

func _setup_shop_signals() -> void:
	# 各ショップの Area3D は player_entered_shop を発行するだけなので、
	# メイン側で接続してショップ UI を開く。
	for child in get_children():
		var shop_area := child.get_node_or_null("Area3D") as Area3D
		if shop_area:
			_connect_shop_signals_instance(shop_area)

func _setup_fill_light() -> void:
	if player_node == null:
		return
	# 進行方向の地形が真っ黒にならないよう、視界側から当たる補助光を付ける。
	if player_node.get_node_or_null("ViewFillLight") == null:
		var fill := DirectionalLight3D.new()
		fill.name = "ViewFillLight"
		fill.light_color = Color(0.72, 0.82, 1.0)
		fill.light_energy = 0.85
		fill.shadow_enabled = false
		fill.rotation_degrees = Vector3(-28, 0, 0)
		player_node.add_child(fill)
	# 足元の崖や建物を回り込んで照らす弱い環境光。
	if player_node.get_node_or_null("SurfaceFillLight") == null:
		var player_light := OmniLight3D.new()
		player_light.name = "SurfaceFillLight"
		player_light.light_color = Color(0.78, 0.84, 1.0)
		player_light.light_energy = 0.85
		player_light.omni_range = 24.0
		player_light.shadow_enabled = false
		player_light.position = Vector3(0, 2.0, 0)
		player_node.add_child(player_light)

func _process(delta: float) -> void:
	if not terrain_node:
		terrain_node = get_node_or_null("terrain")

	# 戦闘中はフィールド HUD / ミニマップの更新を停止して負荷を下げる。
	if player_node and "isbattle" in player_node and player_node.isbattle:
		if minimap_root and minimap_root.visible:
			minimap_root.visible = false
		return

	var is_castle = false
	var castle_floor = 0
	var player_pos = Vector3.ZERO
	if player_node:
		player_pos = player_node.global_position
		if terrain_node and terrain_node.has_method("is_player_in_castle"):
			is_castle = terrain_node.is_player_in_castle(player_pos)
			if is_castle:
				castle_floor = terrain_node.get_castle_floor(player_pos)

	_update_hud(player_pos, is_castle, castle_floor)
	
	# メインカメラがマップ用マーカー(レイヤー2)を映さないようにする
	if player_node:
		var in_battle = false
		if "isbattle" in player_node:
			in_battle = player_node.isbattle
			
		if minimap_root:
			if in_battle or map_mode == 2:
				minimap_root.visible = false
			else:
				minimap_root.visible = true
				
				var is_under = false
				if not is_castle and terrain_node and terrain_node.has_method("check_dirt_above"):
					var px = int(round(player_pos.x))
					var pz = int(round(player_pos.z))
					var py = int(round(player_pos.y))
					is_under = terrain_node.check_dirt_above(px, py + 2, pz)
				
				_is_underground_cached = is_under
				if "torch_light" in player_node and player_node.torch_light:
					player_node.torch_light.visible = (is_castle or is_under)
				
				if is_castle:
					minimap_container.modulate.a = 0.3
					if underground_texture_rect:
						underground_texture_rect.visible = false
					if castle_texture_rect:
						castle_texture_rect.visible = true
						if terrain_node and "castle_map_textures" in terrain_node and castle_floor < terrain_node.castle_map_textures.size():
							castle_texture_rect.texture = terrain_node.castle_map_textures[castle_floor]
				elif _is_underground_cached:
					minimap_container.modulate.a = 0.3
					if castle_texture_rect:
						castle_texture_rect.visible = false
					if underground_texture_rect:
						underground_texture_rect.visible = true
						underground_texture_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
				else:
					minimap_container.modulate.a = 1.0
					if underground_texture_rect:
						underground_texture_rect.visible = false
					if castle_texture_rect:
						castle_texture_rect.visible = false
					
		if minimap_camera and minimap_root and minimap_root.visible:
			if map_mode == 1:
				if terrain_node:
					minimap_camera.global_position = Vector3(terrain_node.worldh / 2.0, 200, terrain_node.worldw / 2.0)
			else:
				minimap_camera.global_position = player_pos + Vector3(0, 80, 0)
			minimap_camera.rotation_degrees = Vector3(-90, 0, 0)

			# SubViewportの3D再描画を間引き(20Hz)してGPU・CPU負荷を大幅軽減（マーカー類は毎フレーム滑らかに更新）
			if minimap_viewport:
				_minimap_render_timer += delta
				if _minimap_render_timer >= 0.05:
					_minimap_render_timer = 0.0
					minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			
			var current_map_size = minimap_root.size
			var current_scale_factor = current_map_size.y / minimap_camera.size
			var center = current_map_size / 2.0
			var cam_pos = minimap_camera.global_position
			var cam_x = cam_pos.x
			var cam_z = cam_pos.z
			var diff_x = 0.0 - cam_x
			var diff_z = 0.0 - cam_z
			var offset_x = diff_x * current_scale_factor
			var offset_y = diff_z * current_scale_factor
			
			if underground_texture_rect and underground_texture_rect.visible and terrain_node:
				if underground_texture_rect.texture == null and "underground_map_texture" in terrain_node:
					underground_texture_rect.texture = terrain_node.underground_map_texture
					
				underground_texture_rect.size = Vector2(terrain_node.worldh, terrain_node.worldw) * current_scale_factor
				underground_texture_rect.position = center + Vector2(offset_x, offset_y)

			if castle_texture_rect and castle_texture_rect.visible and terrain_node:
				castle_texture_rect.size = Vector2(terrain_node.worldh, terrain_node.worldw) * current_scale_factor
				castle_texture_rect.position = center + Vector2(offset_x, offset_y)

			_update_poi_markers(cam_pos, center, current_scale_factor, current_map_size, is_castle, castle_floor)
			
			if player_marker and minimap_camera:
				var p_diff_x = player_pos.x - cam_pos.x
				var p_diff_z = player_pos.z - cam_pos.z
				
				var screen_x = center.x + (p_diff_x * current_scale_factor)
				var screen_y = center.y + (p_diff_z * current_scale_factor)
				
				screen_x = clamp(screen_x, 4, current_map_size.x - 12)
				screen_y = clamp(screen_y, 4, current_map_size.y - 12)
				
				player_marker.position = Vector2(screen_x, screen_y) - player_marker.size / 2.0
# ==============================
# HUD
# ==============================
var hud_layer: CanvasLayer = null
var hud_money_label: Label = null
var hud_biome_label: Label = null
var hud_guide_panel: PanelContainer = null

func _setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	add_child(hud_layer)

	# 画面右上: 所持金
	hud_money_label = Label.new()
	hud_money_label.name = "HUDMoneyLabel"
	hud_money_label.text = "💰 Money: 0"
	hud_money_label.anchors_preset = Control.PRESET_TOP_RIGHT
	hud_money_label.offset_left = -220
	hud_money_label.offset_top = 20
	hud_money_label.offset_right = -20
	hud_money_label.offset_bottom = 60
	hud_money_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud_money_label.add_theme_font_size_override("font_size", 22)
	hud_money_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	hud_layer.add_child(hud_money_label)

	# 画面上部中央: 現在地バイオーム
	hud_biome_label = Label.new()
	hud_biome_label.name = "HUDBiomeLabel"
	hud_biome_label.text = "📍 平原 (Plains)"
	hud_biome_label.anchors_preset = Control.PRESET_CENTER_TOP
	hud_biome_label.offset_left = -150
	hud_biome_label.offset_top = 20
	hud_biome_label.offset_right = 150
	hud_biome_label.offset_bottom = 60
	hud_biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_biome_label.add_theme_font_size_override("font_size", 20)
	hud_biome_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.8))
	hud_layer.add_child(hud_biome_label)

	# 画面左上: 操作ガイド
	hud_guide_panel = PanelContainer.new()
	hud_guide_panel.name = "HUDGuidePanel"
	hud_guide_panel.anchors_preset = Control.PRESET_TOP_LEFT
	hud_guide_panel.offset_left = 20
	hud_guide_panel.offset_top = 20
	hud_guide_panel.offset_right = 380
	hud_guide_panel.offset_bottom = 180
	hud_guide_panel.grow_vertical = Control.GROW_DIRECTION_END

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.6)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	hud_guide_panel.add_theme_stylebox_override("panel", style)

	var guide_label = Label.new()
	guide_label.text = "[W][A][S][D] 移動\n[Shift] 走る (Sprint)\n[Space] ジャンプ\n[マウス] 視点操作\n[M] ミニマップ切替\n[+][-] マップ拡大縮小\n[Esc] メニュー・設定"
	guide_label.add_theme_font_size_override("font_size", 14)
	guide_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
	hud_guide_panel.add_child(guide_label)
	hud_layer.add_child(hud_guide_panel)

func _update_hud(ppos: Vector3, is_castle: bool, castle_floor: int) -> void:
	if hud_money_label and money != _last_hud_money:
		_last_hud_money = money
		hud_money_label.text = "💰 Money: %d" % money

	# プレイヤー位置に応じたバイオーム表示（変化時のみLabelを更新）
	if hud_biome_label and player_node:
		var biome_str = "📍 平原 (Plains)"
		if terrain_node and "desert_start_h" in terrain_node:
			if ppos.x >= terrain_node.desert_start_h and ppos.x <= terrain_node.desert_start_h + terrain_node.h and ppos.z >= terrain_node.desert_start_w and ppos.z <= terrain_node.desert_start_w + terrain_node.w:
				biome_str = "📍 砂漠 (Desert)"
			elif ppos.x >= terrain_node.cave_start_h and ppos.x <= terrain_node.cave_start_h + terrain_node.h and ppos.z >= terrain_node.cave_start_w and ppos.z <= terrain_node.cave_start_w + terrain_node.w:
				biome_str = "📍 洞窟 (Cave)"
			elif ppos.x >= terrain_node.castle_start_h and ppos.x <= terrain_node.castle_start_h + terrain_node.h and ppos.z >= terrain_node.castle_start_w and ppos.z <= terrain_node.castle_start_w + terrain_node.w:
				if is_castle:
					var flr = castle_floor + 1
					biome_str = "📍 魔王城 %dF (Demon Castle %dF)" % [flr, flr]
				else:
					biome_str = "📍 魔王城 (Castle)"
		if biome_str != _last_hud_biome:
			_last_hud_biome = biome_str
			hud_biome_label.text = biome_str

# ==============================
# ポーズメニュー（Pause Menu）
# ==============================
var pause_layer: CanvasLayer = null
var pause_panel: Control = null

func _setup_pause_menu() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.name = "PauseMenu"
	pause_layer.layer = 100
	pause_layer.visible = false
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)

	var bg = ColorRect.new()
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.color = Color(0, 0, 0, 0.65)
	pause_layer.add_child(bg)

	# 固定サイズの VBox を中央に置くと小さい画面でボタンがはみ出すため、
	# 画面中央の CenterContainer + 内容に合わせて伸縮するパネルにする。
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(center)

	pause_panel = PanelContainer.new()
	pause_panel.name = "PausePanel"
	pause_panel.custom_minimum_size = Vector2(420, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.06, 0.10, 0.97)
	panel_style.border_color = Color(0.30, 0.45, 0.72, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 30
	panel_style.content_margin_right = 30
	panel_style.content_margin_top = 26
	panel_style.content_margin_bottom = 26
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 12
	pause_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(pause_panel)

	var menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 14)
	pause_panel.add_child(menu)

	var title = Label.new()
	title.text = "PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	menu.add_child(title)

	var hint = Label.new()
	hint.text = "ESC で閉じる"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.65, 0.73, 0.86))
	menu.add_child(hint)

	var resume_btn = Button.new()
	resume_btn.text = "再開 (Resume)"
	resume_btn.custom_minimum_size = Vector2(0, 48)
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_btn.pressed.connect(func(): toggle_pause_menu())
	menu.add_child(resume_btn)

	var inventory_btn = Button.new()
	inventory_btn.text = "インベントリ / スキルツリー"
	inventory_btn.custom_minimum_size = Vector2(0, 48)
	inventory_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_btn.pressed.connect(_open_inventory_from_pause)
	menu.add_child(inventory_btn)

	var settings_btn = Button.new()
	settings_btn.text = "設定 (Settings)"
	settings_btn.custom_minimum_size = Vector2(0, 48)
	settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_btn.pressed.connect(_open_settings_from_pause)
	menu.add_child(settings_btn)

	var quit_btn = Button.new()
	quit_btn.text = "ゲーム終了 (Quit)"
	quit_btn.custom_minimum_size = Vector2(0, 48)
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_btn.pressed.connect(func(): get_tree().quit())
	menu.add_child(quit_btn)

func _open_inventory_from_pause() -> void:
	if pause_layer:
		pause_layer.visible = false
	if shop_ui and shop_ui.has_method("open_shop"):
		shop_ui.open_shop()
		if "tabs" in shop_ui and shop_ui.tabs:
			shop_ui.tabs.current_tab = 2

func _open_settings_from_pause() -> void:
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager and settings_manager.has_method("open_settings"):
		settings_manager.open_settings()

func toggle_pause_menu() -> void:
	if not pause_layer:
		return
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager and settings_manager.has_method("is_open") and settings_manager.is_open():
		return
	if isshoping:
		return # ショップ中はショップ操作優先

	var will_open = !pause_layer.visible
	pause_layer.visible = will_open
	if player_node and player_node.has_method("set_movement_enabled"):
		player_node.set_movement_enabled(!will_open)

	if will_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		var in_battle = player_node and "isbattle" in player_node and player_node.isbattle
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if in_battle else Input.MOUSE_MODE_CAPTURED)

# ==============================
# ローディング画面（Loading Screen）
# ==============================
var loading_layer: CanvasLayer = null

func _setup_loading_screen() -> void:
	loading_layer = CanvasLayer.new()
	loading_layer.name = "LoadingScreen"
	loading_layer.layer = 120
	add_child(loading_layer)

	var bg = ColorRect.new()
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.color = Color(0.08, 0.08, 0.1, 1.0)
	loading_layer.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_CENTER
	vbox.offset_left = -200
	vbox.offset_top = -60
	vbox.offset_right = 200
	vbox.offset_bottom = 60
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	loading_layer.add_child(vbox)

	var title = Label.new()
	title.text = "NOW LOADING..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "世界と地形を生成中..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(subtitle)

	# 1.5秒後にスムーズにフェードアウト
	var tween = create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(bg, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(vbox, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func():
		if is_instance_valid(loading_layer):
			loading_layer.queue_free()
	)

func add_character_by_id(char_id: String, starting_level: int = 1) -> CharacterData:
	if not all_characters.has(char_id):
		push_warning("Unknown character id: " + char_id)
		return null
	if party.size() >= MAX_PARTY_SIZE:
		return null
	for existing in party:
		if existing.id == char_id:
			return null
	var config = all_characters[char_id]
	var data = CharacterData.create_from_config(char_id, config, starting_level)
	party.append(data)
	return data

func can_recruit_more() -> bool:
	return party.size() < MAX_PARTY_SIZE

func spend_money(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	money -= amount
	return true

func add_money(amount: int) -> void:
	money = max(0, money + amount)

func add_exp_to_party(amount: int) -> void:
	for c in party:
		c.add_exp(amount)

# 戦闘勝利時に敵が低確率で起き上がり、仲間になる処理。
func try_recruit_enemy(enemy_name: String, model_path: String = "", enemy_type: int = 4, base_hp: int = 80, base_atk: int = 20, base_def: int = 10) -> CharacterData:
	if party.size() >= MAX_PARTY_SIZE:
		return null
	if all_characters.has(enemy_name):
		return add_character_by_id(enemy_name)

	var path := model_path
	if path.get_extension().to_lower() in ["glb", "gltf", "tscn"]:
		path = path.get_base_dir() + "/"
	elif path == "":
		path = "res://model/enemy/have_animation/%s/" % enemy_name

	var config := [
		max(1, base_hp),
		max(1, base_atk),
		max(1, base_def),
		enemy_type,
		path,
		800
	]
	var data := CharacterData.create_from_config(enemy_name, config, 1)
	party.append(data)
	return data

func calculate_status(base: float, lvl: int, power: float = 2.0 / 3.0) -> int:
	return CharacterData.calculate_status(base, lvl, power)

func generate_allies_to_spawn() -> Array:
	var allies_to_spawn = []
	var atk_mult = 1.0 + 0.15 * get_shop_buff_level("attack")
	var def_mult = 1.0 + 0.15 * get_shop_buff_level("defense")
	var hp_mult = 1.0 + 0.12 * get_shop_buff_level("max_hp")
	var start_shield = 5 * get_shop_buff_level("start_shield")
	for i in range(min(party.size(), MAX_PARTY_SIZE)):
		var char_data = party[i]
		var info: Dictionary = char_data.get_spawn_info()
		info["attack"] = int(round(float(info["attack"]) * atk_mult))
		info["defense"] = int(round(float(info["defense"]) * def_mult))
		var new_max = int(round(float(info["max_health"]) * hp_mult))
		info["max_health"] = new_max
		info["health"] = min(int(info["health"]), new_max)
		info["start_shield"] = start_shield
		allies_to_spawn.append(info)
	return allies_to_spawn

# 戦闘終了時に HP / EXP / スキルゲージを本体データへ戻す。
func apply_battle_results(results: Array) -> void:
	for result in results:
		var idx: int = int(result.get("index", -1))
		if idx < 0 or idx >= party.size():
			continue
		var c := party[idx]
		c.cur_health = int(result.get("hp", c.cur_health))
		if c.cur_health <= 0:
			# 全滅寸前で次戦に持ち越さない。勝利時は 1 で蘇生する。
			c.cur_health = 1
		c.ult_charge = int(result.get("ult_charge", 0))

# ==============================
# ショップ連携
# ==============================
func _connect_shop_signals_instance(shop_area: Area3D):
	var enter_callable := Callable(self, "_on_player_entered_shop")
	if shop_area.has_signal("player_entered_shop") and not shop_area.is_connected("player_entered_shop", enter_callable):
		shop_area.player_entered_shop.connect(enter_callable)
	var exit_callable := Callable(self, "_on_player_exited_shop")
	if shop_area.has_signal("player_exited_shop") and not shop_area.is_connected("player_exited_shop", exit_callable):
		shop_area.player_exited_shop.connect(exit_callable)

func _on_player_entered_shop(_shop_root_node: Node3D):
	if shop_ui and shop_ui.visible:
		return

	if player_node and player_node.has_method("set_movement_enabled"):
		player_node.set_movement_enabled(false) 

	if shop_ui and shop_ui.has_method("open_shop"):
		shop_ui.open_shop()
	elif shop_ui:
		shop_ui.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_player_exited_shop(_shop_root_node: Node3D):
	pass

var map_mode: int = 0 # 0: ミニマップ, 1: 全体マップ, 2: 非表示

func _setup_minimap() -> void:
	minimap_root = Control.new()
	minimap_root.name = "MinimapRoot"
	minimap_root.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	minimap_root.size = Vector2(256, 256)
	minimap_root.position = Vector2(20, get_viewport().get_visible_rect().size.y - 336)
	
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color(0.2, 0.2, 0.2, 1.0)
	border.size = Vector2(264, 264)
	border.position = Vector2(-4, -4)
	minimap_root.add_child(border)
	
	var solid_bg = ColorRect.new()
	solid_bg.name = "SolidBG"
	solid_bg.color = Color(0.05, 0.1, 0.15, 1.0)
	solid_bg.size = Vector2(256, 256)
	solid_bg.position = Vector2(0, 0)
	minimap_root.add_child(solid_bg)
	
	var map_clip = Control.new()
	map_clip.name = "MapClip"
	map_clip.size = Vector2(256, 256)
	map_clip.position = Vector2(0, 0)
	map_clip.clip_contents = true
	minimap_root.add_child(map_clip)
	
	minimap_container = SubViewportContainer.new()
	minimap_container.name = "MinimapContainer"
	minimap_container.size = Vector2(256, 256)
	minimap_container.position = Vector2(0, 0)
	minimap_container.stretch = true
	
	minimap_viewport = SubViewport.new()
	minimap_viewport.name = "MapViewport"
	minimap_viewport.size = Vector2i(256, 256)
	minimap_viewport.transparent_bg = true
	minimap_viewport.msaa_3d = Viewport.MSAA_DISABLED
	minimap_viewport.positional_shadow_atlas_size = 0
	minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	minimap_camera = Camera3D.new()
	minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	minimap_camera.size = 150.0
	minimap_camera.current = false
	minimap_camera.cull_mask = 0xFFFFFFFF
	
	var map_env = Environment.new()
	map_env.background_mode = Environment.BG_COLOR
	map_env.background_color = Color(0.05, 0.1, 0.15, 0.8)
	map_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	map_env.ambient_light_color = Color(1, 1, 1)
	map_env.fog_enabled = false
	minimap_camera.environment = map_env
	
	minimap_viewport.add_child(minimap_camera)
	minimap_container.add_child(minimap_viewport)
	map_clip.add_child(minimap_container)
	
	underground_texture_rect = TextureRect.new()
	underground_texture_rect.name = "UndergroundTextureRect"
	underground_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underground_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	underground_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	underground_texture_rect.visible = false
	map_clip.add_child(underground_texture_rect)

	castle_texture_rect = TextureRect.new()
	castle_texture_rect.name = "CastleTextureRect"
	castle_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	castle_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	castle_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	castle_texture_rect.visible = false
	map_clip.add_child(castle_texture_rect)

	poi_container = Control.new()
	poi_container.name = "POIContainer"
	poi_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_clip.add_child(poi_container)
	
	player_marker = ColorRect.new()
	player_marker.name = "PlayerMarker"
	player_marker.color = Color(1.0, 0.2, 0.2, 1.0)
	player_marker.size = Vector2(8, 8)
	map_clip.add_child(player_marker)
	
	if hud_layer:
		hud_layer.add_child(minimap_root)
	else:
		add_child(minimap_root)

	_update_map_mode()
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			map_mode = (map_mode + 1) % 3
			_update_map_mode()
		elif event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS or event.keycode == KEY_KP_ADD:
			_zoom_map(-1.0)
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			_zoom_map(1.0)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_map(-1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_map(1.0)

func _zoom_map(direction: float) -> void:
	if map_mode == 0:
		minimap_local_zoom = clamp(minimap_local_zoom + direction * 5.0, 25.0, 120.0)
		if minimap_camera:
			minimap_camera.size = minimap_local_zoom
		if minimap_viewport:
			minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	elif map_mode == 1:
		minimap_big_zoom_mult = clamp(minimap_big_zoom_mult + direction * 0.08, 0.35, 1.8)
		_update_map_mode()

func _update_map_mode() -> void:
	if not minimap_root: return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var border = minimap_root.get_node_or_null("Border")
	var solid_bg = minimap_root.get_node_or_null("SolidBG")
	var map_clip = minimap_root.get_node_or_null("MapClip")
	
	match map_mode:
		0:
			# Enlarged, zoomed-in local minimap for close navigation
			minimap_root.show()
			var m_size = Vector2(288, 288)
			minimap_root.size = m_size
			minimap_root.position = Vector2(20, viewport_size.y - 368)
			if border: border.size = m_size + Vector2(8, 8)
			if solid_bg: solid_bg.size = m_size
			if map_clip: map_clip.size = m_size
			if minimap_container:
				minimap_container.size = m_size
			if minimap_camera: minimap_camera.size = minimap_local_zoom
			if minimap_viewport: minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		1:
			# Grand full-screen Big Map fitting world dimensions perfectly
			minimap_root.show()
			var max_w = viewport_size.x - 40.0
			var max_h = viewport_size.y - 40.0
			var map_w = min(max_w, max_h * 1.25)
			var map_h = max_h
			var map_size = Vector2(map_w, map_h)
			minimap_root.size = map_size
			minimap_root.position = (viewport_size - map_size) / 2.0
			if border: border.size = map_size + Vector2(8, 8)
			if solid_bg: solid_bg.size = map_size
			if map_clip: map_clip.size = map_size
			if minimap_container:
				minimap_container.size = map_size
			
			var world_h = 258.0
			var world_w = 516.0
			if terrain_node:
				world_h = float(terrain_node.worldh)
				world_w = float(terrain_node.worldw)
			var aspect = map_w / map_h
			var req_cam_v = world_w * 1.05
			var req_cam_h = (world_h * 1.05) / aspect
			var fit_cam_size = max(req_cam_v, req_cam_h)
			if minimap_camera:
				minimap_camera.size = fit_cam_size * minimap_big_zoom_mult
			if minimap_viewport: minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		2:
			minimap_root.hide()
func _update_underground_map():
	pass

func _update_poi_markers(cam_pos: Vector3, center: Vector2, current_scale_factor: float, current_map_size: Vector2, is_castle: bool, castle_floor: int) -> void:
	if not poi_container:
		return
	if not terrain_node or not ("poi_data" in terrain_node) or terrain_node.poi_data.size() == 0:
		return

	var current_context = "surface"
	if is_castle:
		current_context = "castle_" + str(castle_floor)
	elif _is_underground_cached:
		current_context = "underground"

	var active_ids = {}
	var pulse_scale = Vector2.ONE
	var pulse_computed = false

	for poi in terrain_node.poi_data:
		var p_id = poi.get("id", "")
		var p_context = poi.get("context", "surface")
		
		# Context filtering
		if map_mode == 0:
			# Local minimap: strictly show POIs corresponding to the current environment
			if p_context != current_context:
				continue
		elif map_mode == 1:
			# Full map view
			if is_castle:
				if p_context != current_context:
					continue
			else:
				if p_context != "surface" and p_context != "underground":
					continue

		var pos: Vector3 = poi.get("pos", Vector3.ZERO)
		var diff_x = pos.x - cam_pos.x
		var diff_z = pos.z - cam_pos.z
		var screen_x = center.x + (diff_x * current_scale_factor)
		var screen_y = center.y + (diff_z * current_scale_factor)

		# Screen boundary check
		if screen_x < -20 or screen_x > current_map_size.x + 20 or screen_y < -20 or screen_y > current_map_size.y + 20:
			continue

		active_ids[p_id] = true

		var marker: Control = poi_marker_nodes.get(p_id)
		if not marker:
			marker = _create_poi_marker(poi)
			poi_marker_nodes[p_id] = marker
			poi_container.add_child(marker)

		marker.visible = true
		marker.position = Vector2(screen_x, screen_y) - marker.size / 2.0

		# Name tag visibility based on map mode
		var name_tag: Control = marker.get_meta("name_tag") if marker.has_meta("name_tag") else marker.get_node_or_null("NameTag")
		if name_tag:
			name_tag.visible = (map_mode == 1)

		# Pulsing animation for Boss and Stairs
		var p_type = poi.get("type", "")
		if p_type == "boss" or p_type == "stair_up" or p_type == "stair_down":
			if not pulse_computed:
				var pulse = 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
				pulse_scale = Vector2(pulse, pulse)
				pulse_computed = true
			marker.scale = pulse_scale
			marker.pivot_offset = marker.size / 2.0
		else:
			marker.scale = Vector2.ONE

	# Hide markers that are currently filtered out
	for id in poi_marker_nodes.keys():
		if not active_ids.has(id):
			poi_marker_nodes[id].visible = false

func _create_poi_marker(poi: Dictionary) -> Control:
	var m = Control.new()
	m.name = "POI_" + str(poi.get("id", "marker"))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz = Vector2(18, 18)
	m.size = sz

	var bg = ColorRect.new()
	bg.name = "BG"
	bg.size = sz
	bg.color = poi.get("color", Color.WHITE)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(bg)

	var border = ReferenceRect.new()
	border.name = "Border"
	border.size = sz
	border.border_color = Color(0, 0, 0, 0.9)
	border.border_width = 1.5
	border.editor_only = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(border)

	var lbl = Label.new()
	lbl.name = "Symbol"
	lbl.text = poi.get("symbol", "•")
	lbl.size = sz
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(lbl)

	var name_lbl = Label.new()
	name_lbl.name = "NameTag"
	name_lbl.text = poi.get("name", "")
	name_lbl.position = Vector2(-30, 19)
	name_lbl.size = Vector2(78, 14)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	name_lbl.add_theme_constant_override("shadow_offset_x", 1)
	name_lbl.add_theme_constant_override("shadow_offset_y", 1)
	name_lbl.visible = false
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(name_lbl)
	m.set_meta("name_tag", name_lbl)

	return m
