extends Node3D

@onready var shop_ui = get_node_or_null("ShopUi") if has_node("ShopUi") else get_node_or_null("CanvasLayer/ShopUI")
@onready var player_node: CharacterBody3D = $CharacterBody3D

# ==============================
# パーティデータ管理 (CharacterData による一元管理)
# ==============================
var party: Array[CharacterData] = []
var isshoping: bool = false
var money: int = 0
var minimap_root: Control
var minimap_container: SubViewportContainer
var minimap_camera: Camera3D
var _is_underground_cached: bool = false
var underground_texture_rect: TextureRect
var underground_image: Image
var underground_tex: ImageTexture
var _underground_update_timer: float = 0.0
var player_marker: ColorRect

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
	# 初期パーティ登録（red_magician）
	add_character_by_id("red_magician")
	_setup_hud()
	_setup_pause_menu()
	_setup_loading_screen()
	_setup_minimap()
	
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
				var terrain_node = get_node_or_null("terrain")
				if terrain_node and terrain_node.has_method("check_dirt_above"):
					var px = int(round(player_node.global_position.x))
					var pz = int(round(player_node.global_position.z))
					var py = int(round(player_node.global_position.y))
					# O(1) check using the precomputed underground map.
					is_under = terrain_node.check_dirt_above(px, py + 2, pz)
				
				_is_underground_cached = is_under
				
				if _is_underground_cached:
					# Fade surface map only. Player marker stays solid and bright!
					minimap_container.modulate.a = 0.3
					if underground_texture_rect:
						underground_texture_rect.visible = true
						underground_texture_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
				else:
					minimap_container.modulate.a = 1.0
					if underground_texture_rect:
						underground_texture_rect.visible = false
	underground_texture_rect.flip_v = true
					
		if minimap_camera and minimap_root and minimap_root.visible:
			if map_mode == 1:
				var terrain_node = get_node_or_null("terrain")
				if terrain_node:
					minimap_camera.global_position = Vector3(terrain_node.worldh / 2.0, 200, terrain_node.worldw / 2.0)
			else:
				minimap_camera.global_position = player_node.global_position + Vector3(0, 80, 0)
			minimap_camera.rotation_degrees = Vector3(-90, 0, 0)
			
			var current_map_size = minimap_root.size
			var current_scale_factor = current_map_size.y / minimap_camera.size
			
			if underground_texture_rect and underground_texture_rect.visible:
				var terrain_node = get_node_or_null("terrain")
				if terrain_node:
					if underground_texture_rect.texture == null and "underground_map_texture" in terrain_node:
						underground_texture_rect.texture = terrain_node.underground_map_texture
						
					underground_texture_rect.size = Vector2(terrain_node.worldh, terrain_node.worldw) * current_scale_factor
					
					var cam_x = minimap_camera.global_position.x
					var cam_z = minimap_camera.global_position.z
					
					var diff_x = 0.0 - cam_x
					# In Godot, Camera3D looking down (-90,0,0) has Up vector along +Z.
					# Therefore Screen Y goes down as 3D Z goes down.
					# With flip_v=true, top of texture is worldw, bottom is 0.
					var diff_z = float(terrain_node.worldw) - cam_z
					
					var center = current_map_size / 2.0
					var offset_x = diff_x * current_scale_factor
					var offset_y = -diff_z * current_scale_factor
					
					underground_texture_rect.position = center + Vector2(offset_x, offset_y)
			
			if player_marker and minimap_camera:
				var cam_pos = minimap_camera.global_position
				var player_pos = player_node.global_position
				
				var diff_x = player_pos.x - cam_pos.x
				var diff_z = player_pos.z - cam_pos.z
				
				var center = current_map_size / 2.0
				
				var screen_x = center.x + (diff_x * current_scale_factor)
				# Subtract diff_z because 3D +Z corresponds to 2D Screen UP (-Y)!
				var screen_y = center.y - (diff_z * current_scale_factor)
				
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

	# 画面左下: 操作ガイド
	hud_guide_panel = PanelContainer.new()
	hud_guide_panel.name = "HUDGuidePanel"
	hud_guide_panel.anchors_preset = Control.PRESET_BOTTOM_LEFT
	hud_guide_panel.offset_left = 20
	hud_guide_panel.offset_top = -140
	hud_guide_panel.offset_right = 320
	hud_guide_panel.offset_bottom = -20
	hud_guide_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.6)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	hud_guide_panel.add_theme_stylebox_override("panel", style)

	var guide_label = Label.new()
	guide_label.text = "[W][A][S][D] 移動\n[Shift] 走る (Sprint)\n[Space] ジャンプ\n[M] ミニマップ\n[Esc] ポーズメニュー"
	guide_label.add_theme_font_size_override("font_size", 14)
	guide_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
	hud_guide_panel.add_child(guide_label)
	hud_layer.add_child(hud_guide_panel)

func _update_hud() -> void:
	if hud_money_label:
		hud_money_label.text = "💰 Money: %d" % money

	# プレイヤー位置に応じたバイオーム表示
	if hud_biome_label and player_node:
		var ppos = player_node.global_position
		var biome_str = "📍 平原 (Plains)"
		var terrain_node = get_node_or_null("terrain")
		if terrain_node:
			if ppos.x >= terrain_node.desert_start_h and ppos.x <= terrain_node.desert_start_h + terrain_node.h and ppos.z >= terrain_node.desert_start_w and ppos.z <= terrain_node.desert_start_w + terrain_node.w:
				biome_str = "📍 砂漠 (Desert)"
			elif ppos.x >= terrain_node.cave_start_h and ppos.x <= terrain_node.cave_start_h + terrain_node.h and ppos.z >= terrain_node.cave_start_w and ppos.z <= terrain_node.cave_start_w + terrain_node.w:
				biome_str = "📍 洞窟 (Cave)"
			elif ppos.x >= terrain_node.castle_start_h and ppos.x <= terrain_node.castle_start_h + terrain_node.h and ppos.z >= terrain_node.castle_start_w and ppos.z <= terrain_node.castle_start_w + terrain_node.w:
				biome_str = "📍 城 (Castle)"
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

	var center = VBoxContainer.new()
	center.anchors_preset = Control.PRESET_CENTER
	center.offset_left = -150
	center.offset_top = -160
	center.offset_right = 150
	center.offset_bottom = 160
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 20)
	pause_layer.add_child(center)

	var title = Label.new()
	title.text = "PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	center.add_child(title)

	var resume_btn = Button.new()
	resume_btn.text = "再開 (Resume)"
	resume_btn.custom_minimum_size = Vector2(200, 45)
	resume_btn.pressed.connect(func(): toggle_pause_menu())
	center.add_child(resume_btn)

	var quit_btn = Button.new()
	quit_btn.text = "ゲーム終了 (Quit)"
	quit_btn.custom_minimum_size = Vector2(200, 45)
	quit_btn.pressed.connect(func(): get_tree().quit())
	center.add_child(quit_btn)

func toggle_pause_menu() -> void:
	if not pause_layer:
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
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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

func add_character_by_id(char_id: String) -> CharacterData:
	if not all_characters.has(char_id):
		push_warning("Unknown character id: " + char_id)
		return null
	var config = all_characters[char_id]
	var data = CharacterData.create_from_config(char_id, config)
	party.append(data)
	return data

func calculate_status(base: float, lvl: int, power: float = 2.0 / 3.0) -> int:
	return CharacterData.calculate_status(base, lvl, power)

func generate_allies_to_spawn() -> Array:
	var allies_to_spawn = []
	for i in range(party.size()):
		var char_data = party[i]
		var info = char_data.get_spawn_info()
		if char_data.cur_health != -1:
			info["name"] = "hero%d" % (i + 1)
		allies_to_spawn.append(info)
	return allies_to_spawn

# ==============================
# ショップ連携
# ==============================
func _connect_shop_signals_instance(shop_area: Area3D):
	if shop_area.has_signal("player_entered_shop"):
		shop_area.player_entered_shop.connect(_on_player_entered_shop)
	if shop_area.has_signal("player_exited_shop"):
		shop_area.player_exited_shop.connect(_on_player_exited_shop)

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
	minimap_root.position = Vector2(20, get_viewport().get_visible_rect().size.y - 276)
	minimap_root.clip_contents = true
	
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color(0.2, 0.2, 0.2, 1.0)
	border.size = Vector2(264, 264)
	border.position = Vector2(-4, -4)
	border.show_behind_parent = true
	
	var solid_bg = ColorRect.new()
	solid_bg.name = "SolidBG"
	solid_bg.color = Color(0.05, 0.1, 0.15, 1.0)
	solid_bg.size = Vector2(256, 256)
	solid_bg.position = Vector2(0, 0)
	solid_bg.show_behind_parent = true
	minimap_root.add_child(solid_bg)
	
	minimap_container = SubViewportContainer.new()
	minimap_container.name = "MinimapContainer"
	minimap_container.size = Vector2(256, 256)
	minimap_container.position = Vector2(0, 0)
	
	var minimap_viewport = SubViewport.new()
	minimap_viewport.name = "MapViewport"
	minimap_viewport.size = Vector2i(256, 256)
	minimap_viewport.transparent_bg = true
	
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
	minimap_root.add_child(minimap_container)
	
	underground_texture_rect = TextureRect.new()
	underground_texture_rect.name = "UndergroundTextureRect"
	underground_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underground_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	underground_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	underground_texture_rect.visible = false
	underground_texture_rect.flip_v = true
	minimap_root.add_child(underground_texture_rect)
	
	player_marker = ColorRect.new()
	player_marker.name = "PlayerMarker"
	player_marker.color = Color(1.0, 0.2, 0.2, 1.0)
	player_marker.size = Vector2(8, 8)
	minimap_root.add_child(player_marker)
	
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

func _update_map_mode() -> void:
	if not minimap_root: return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var border = minimap_root.get_node_or_null("Border")
	var solid_bg = minimap_root.get_node_or_null("SolidBG")
	var vp = minimap_container.get_node_or_null("MapViewport") if minimap_container else null
	
	match map_mode:
		0:
			minimap_root.show()
			minimap_root.size = Vector2(256, 256)
			minimap_root.position = Vector2(20, viewport_size.y - 276)
			if minimap_container: minimap_container.size = Vector2(256, 256)
			if border: border.size = Vector2(264, 264)
			if solid_bg: solid_bg.size = Vector2(256, 256)
			if vp: vp.size = Vector2i(256, 256)
			if minimap_camera: minimap_camera.size = 150.0
		1:
			minimap_root.show()
			var map_size = min(viewport_size.x, viewport_size.y) - 80
			minimap_root.size = Vector2(map_size, map_size)
			minimap_root.position = (viewport_size - Vector2(map_size, map_size)) / 2.0
			if minimap_container: minimap_container.size = Vector2(map_size, map_size)
			if border: border.size = Vector2(map_size+8, map_size+8)
			if solid_bg: solid_bg.size = Vector2(map_size, map_size)
			if vp: vp.size = Vector2i(int(map_size), int(map_size))
			if minimap_camera: minimap_camera.size = 1100.0
		2:
			minimap_root.hide()
func _update_underground_map():
	pass
