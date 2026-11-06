extends Node

# ============================================================
# 設定マネージャー（Autoload: SettingsManager）
#  - roguelikepuzzle（2D）と roguelikepuzzle2（3D）の設定項目を統合
#  - 音量 / ゲーム速度 / 難易度 / フルスクリーン / 地形サイズ / 画質
#  - タイトルとポーズメニューの両方から同じ設定画面を開ける
# ============================================================

const SETTINGS_PATH := "user://game_settings.json"
const SPEED_MIN := 0.5
const SPEED_MAX := 3.0
const TERRAIN_MIN := 5
const TERRAIN_MAX := 8
const BGM_BUS := "BGM"
const SE_BUS := "SE"

enum Difficulty { EASY = 0, NORMAL = 1, HARD = 2 }

const DIFFICULTY_NAMES := {
	Difficulty.EASY: "EASY",
	Difficulty.NORMAL: "NORMAL",
	Difficulty.HARD: "HARD"
}
const DIFFICULTY_DESCS := {
	Difficulty.EASY: "敵の体力・攻撃力・スキル強度が約25%低下。初心者向け。",
	Difficulty.NORMAL: "標準的な難易度。通常のゲームバランス。",
	Difficulty.HARD: "敵の体力+40%、攻撃力+35%、スキル強度+35%。上級者向け。"
}
const DIFFICULTY_HP_MULTS := {
	Difficulty.EASY: 0.75,
	Difficulty.NORMAL: 1.0,
	Difficulty.HARD: 1.40
}
const DIFFICULTY_ATK_MULTS := {
	Difficulty.EASY: 0.75,
	Difficulty.NORMAL: 1.0,
	Difficulty.HARD: 1.35
}
const DIFFICULTY_SKILL_MULTS := {
	Difficulty.EASY: 0.70,
	Difficulty.NORMAL: 1.0,
	Difficulty.HARD: 1.35
}
const BGM_KEYWORDS := ["bgm", "music", "field", "boss", "maou", "ending", "title"]

var master_volume: float = 0.6
var bgm_volume: float = 0.5
var se_volume: float = 0.5
var game_speed: float = 1.0
var difficulty: int = Difficulty.NORMAL
var fullscreen: bool = false
var terrain_size: int = 6
var graphics_quality: int = 1

var _canvas: CanvasLayer
var _root: Control
var _panel: PanelContainer

var _master_slider: HSlider
var _bgm_slider: HSlider
var _se_slider: HSlider
var _speed_slider: HSlider
var _terrain_slider: HSlider
var _master_value: Label
var _bgm_value: Label
var _se_value: Label
var _speed_value: Label
var _terrain_value: Label
var _difficulty_desc: Label
var _difficulty_buttons: Array[Button] = []
var _fullscreen_check: CheckButton
var _graphics_option: OptionButton
var _title_button: Button
var _last_value_label: Label = null

var _is_open := false
var _was_tree_paused := false
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _player_input_node: Node = null
var _player_input_was_enabled := true
var _base_pitches: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_ensure_audio_buses()
	_apply_all()
	if get_tree():
		if not get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.connect(_on_node_added)
		call_deferred("_apply_audio_tree")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			set_fullscreen(not fullscreen)
			if get_viewport():
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _is_open:
			close_settings()
			if get_viewport():
				get_viewport().set_input_as_handled()

# ============================================================
# 公開 API
# ============================================================
func is_open() -> bool:
	return _is_open

func get_difficulty_hp_mult() -> float:
	return float(DIFFICULTY_HP_MULTS.get(difficulty, 1.0))

func get_difficulty_atk_mult() -> float:
	return float(DIFFICULTY_ATK_MULTS.get(difficulty, 1.0))

func get_difficulty_skill_mult() -> float:
	return float(DIFFICULTY_SKILL_MULTS.get(difficulty, 1.0))

func get_difficulty_name() -> String:
	return str(DIFFICULTY_NAMES.get(difficulty, "NORMAL"))

func open_settings() -> void:
	if _is_open:
		return
	if _canvas == null:
		_build_ui()
	_refresh_ui()
	_canvas.visible = true
	_is_open = true
	_was_tree_paused = get_tree().paused
	_previous_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var scene := get_tree().current_scene
	if scene:
		_player_input_node = scene.find_child("CharacterBody3D", true, false)
		if _player_input_node:
			_player_input_was_enabled = _player_input_node.is_processing_input()
			_player_input_node.set_process_input(false)

func close_settings() -> void:
	if not _is_open:
		return
	_is_open = false
	_canvas.visible = false
	get_tree().paused = _was_tree_paused
	Input.mouse_mode = _previous_mouse_mode
	if is_instance_valid(_player_input_node):
		_player_input_node.set_process_input(_player_input_was_enabled)
	_player_input_node = null
	_save_settings()

func set_master_volume(value: float, save: bool = true) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volumes()
	if save:
		_save_settings()

func set_bgm_volume(value: float, save: bool = true) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volumes()
	if save:
		_save_settings()

func set_se_volume(value: float, save: bool = true) -> void:
	se_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volumes()
	if save:
		_save_settings()

func set_game_speed(value: float, save: bool = true) -> void:
	game_speed = clampf(value, SPEED_MIN, SPEED_MAX)
	Engine.time_scale = game_speed
	_apply_audio_tree()
	if save:
		_save_settings()

func set_difficulty(value: int, save: bool = true) -> void:
	difficulty = clampi(value, Difficulty.EASY, Difficulty.HARD)
	_refresh_difficulty_ui()
	if save:
		_save_settings()

func set_fullscreen(enabled: bool, save: bool = true) -> void:
	fullscreen = enabled
	if DisplayServer.get_name() != "headless":
		if enabled:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1600, 900))
			var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			var pos := screen.position + (screen.size - Vector2i(1600, 900)) / 2
			DisplayServer.window_set_position(pos)
	if _fullscreen_check:
		_fullscreen_check.set_pressed_no_signal(fullscreen)
	if save:
		_save_settings()

func set_terrain_size(value: int, save: bool = true) -> void:
	terrain_size = clampi(value, TERRAIN_MIN, TERRAIN_MAX)
	var global_settings := get_node_or_null("/root/GlobalSettings")
	if global_settings:
		global_settings.set("map_size_exp", terrain_size)
	if save:
		_save_settings()

func set_graphics_quality(value: int, save: bool = true) -> void:
	graphics_quality = clampi(value, 0, 2)
	var global_settings := get_node_or_null("/root/GlobalSettings")
	if global_settings:
		global_settings.set("graphics_level", graphics_quality)
	apply_graphics_quality()
	if save:
		_save_settings()

func apply_graphics_quality() -> void:
	var vp := get_viewport()
	if vp:
		match graphics_quality:
			2:
				vp.msaa_3d = Viewport.MSAA_8X
				vp.use_taa = true
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			1:
				vp.msaa_3d = Viewport.MSAA_2X
				vp.use_taa = false
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			_:
				vp.msaa_3d = Viewport.MSAA_DISABLED
				vp.use_taa = false
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	var tree := get_tree()
	if tree == null:
		return
	for light in tree.root.find_children("*", "DirectionalLight3D", true, false):
		if light is DirectionalLight3D:
			light.shadow_enabled = graphics_quality > 0
			if graphics_quality >= 2:
				light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			elif graphics_quality == 1:
				light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS

# ============================================================
# 永続化
# ============================================================
func _load_settings() -> void:
	var data := {}
	if FileAccess.file_exists(SETTINGS_PATH):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				data = parsed
	master_volume = clampf(float(data.get("master_volume", data.get("master", 0.6))), 0.0, 1.0)
	bgm_volume = clampf(float(data.get("bgm_volume", data.get("bgm", 0.5))), 0.0, 1.0)
	se_volume = clampf(float(data.get("se_volume", data.get("se", 0.5))), 0.0, 1.0)
	game_speed = clampf(float(data.get("game_speed", data.get("speed", 1.0))), SPEED_MIN, SPEED_MAX)
	difficulty = clampi(int(data.get("difficulty", Difficulty.NORMAL)), Difficulty.EASY, Difficulty.HARD)
	fullscreen = bool(data.get("fullscreen", false))
	terrain_size = clampi(int(data.get("terrain_size", data.get("exp", 6))), TERRAIN_MIN, TERRAIN_MAX)
	graphics_quality = clampi(int(data.get("graphics_quality", data.get("gfx", 1))), 0, 2)

func _save_settings() -> void:
	var data := {
		"master_volume": master_volume,
		"bgm_volume": bgm_volume,
		"se_volume": se_volume,
		"game_speed": game_speed,
		"difficulty": difficulty,
		"fullscreen": fullscreen,
		"terrain_size": terrain_size,
		"graphics_quality": graphics_quality,
		# 旧形式との互換（title_screen / terrain が参照）
		"master": master_volume,
		"bgm": bgm_volume,
		"se": se_volume,
		"speed": game_speed,
		"exp": terrain_size,
		"gfx": graphics_quality
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func _apply_all() -> void:
	Engine.time_scale = game_speed
	_apply_bus_volumes()
	_apply_audio_tree()
	apply_graphics_quality()
	if fullscreen:
		set_fullscreen(true, false)

# ============================================================
# オーディオ
# ============================================================
func _ensure_audio_buses() -> void:
	_ensure_bus(BGM_BUS)
	_ensure_bus(SE_BUS)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")

func _apply_bus_volumes() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume(BGM_BUS, bgm_volume)
	_set_bus_volume(SE_BUS, se_volume)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))

func _on_node_added(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		_configure_audio_node(node)

func _apply_audio_tree() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.root.find_children("*", "AudioStreamPlayer", true, false):
		_configure_audio_node(node)
	for node in tree.root.find_children("*", "AudioStreamPlayer2D", true, false):
		_configure_audio_node(node)

func _configure_audio_node(node: Node) -> void:
	var bus_name := BGM_BUS if _is_bgm_node(node) else SE_BUS
	var key := node.get_instance_id()
	if node is AudioStreamPlayer:
		node.bus = bus_name
		if not _base_pitches.has(key):
			_base_pitches[key] = node.pitch_scale
		node.pitch_scale = float(_base_pitches[key]) * game_speed
	elif node is AudioStreamPlayer2D:
		node.bus = bus_name
		if not _base_pitches.has(key):
			_base_pitches[key] = node.pitch_scale
		node.pitch_scale = float(_base_pitches[key]) * game_speed

func _is_bgm_node(node: Node) -> bool:
	var lower := String(node.name).to_lower()
	for keyword in BGM_KEYWORDS:
		if lower.contains(keyword):
			return true
	return false

# ============================================================
# 設定画面 UI
# ============================================================
func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "SettingsScreen"
	_canvas.layer = 200
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)

	_root = Control.new()
	_root.name = "SettingsRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.74)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -520
	_panel.offset_top = -360
	_panel.offset_right = 520
	_panel.offset_bottom = 360
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.06, 0.10, 0.98)
	style.border_color = Color(0.30, 0.45, 0.72, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "設定 / SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	box.add_child(title)

	_master_slider = _add_slider_row(box, "マスター音量", 0, 100, 1, master_volume * 100.0, "%", _on_master_changed)
	_master_value = _last_value_label
	_bgm_slider = _add_slider_row(box, "BGM 音量", 0, 100, 1, bgm_volume * 100.0, "%", _on_bgm_changed)
	_bgm_value = _last_value_label
	_se_slider = _add_slider_row(box, "SE 音量", 0, 100, 1, se_volume * 100.0, "%", _on_se_changed)
	_se_value = _last_value_label

	_speed_slider = _add_slider_row(box, "ゲーム速度", SPEED_MIN, SPEED_MAX, 0.1, game_speed, "x", _on_speed_changed)
	_speed_value = _last_value_label

	var speed_presets := HBoxContainer.new()
	speed_presets.add_theme_constant_override("separation", 8)
	box.add_child(speed_presets)
	for preset in [0.5, 1.0, 1.5, 2.0, 3.0]:
		var button := Button.new()
		button.text = "%.1fx" % preset
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(func() -> void:
			_speed_slider.set_value_no_signal(preset)
			set_game_speed(preset, false)
			_speed_value.text = "%.1fx" % preset
		)
		speed_presets.add_child(button)

	var diff_title := Label.new()
	diff_title.text = "ゲーム難易度"
	diff_title.add_theme_font_size_override("font_size", 20)
	box.add_child(diff_title)

	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 10)
	box.add_child(diff_row)
	_difficulty_buttons.clear()
	for diff in [Difficulty.EASY, Difficulty.NORMAL, Difficulty.HARD]:
		var button := Button.new()
		button.text = str(DIFFICULTY_NAMES[diff])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(func() -> void: set_difficulty(diff, false))
		diff_row.add_child(button)
		_difficulty_buttons.append(button)

	_difficulty_desc = Label.new()
	_difficulty_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty_desc.add_theme_font_size_override("font_size", 14)
	_difficulty_desc.add_theme_color_override("font_color", Color(0.72, 0.80, 0.92))
	box.add_child(_difficulty_desc)

	var full_row := HBoxContainer.new()
	full_row.add_theme_constant_override("separation", 16)
	box.add_child(full_row)
	var full_label := Label.new()
	full_label.text = "画面モード"
	full_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	full_label.add_theme_font_size_override("font_size", 20)
	full_row.add_child(full_label)
	_fullscreen_check = CheckButton.new()
	_fullscreen_check.text = "全画面"
	_fullscreen_check.add_theme_font_size_override("font_size", 18)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	full_row.add_child(_fullscreen_check)

	_terrain_slider = _add_slider_row(box, "地形サイズ（次回生成から）", TERRAIN_MIN, TERRAIN_MAX, 1, terrain_size, "", _on_terrain_changed)
	_terrain_value = _last_value_label

	var graphics_row := HBoxContainer.new()
	graphics_row.add_theme_constant_override("separation", 16)
	box.add_child(graphics_row)
	var graphics_label := Label.new()
	graphics_label.text = "画質"
	graphics_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics_label.add_theme_font_size_override("font_size", 20)
	graphics_row.add_child(graphics_label)
	_graphics_option = OptionButton.new()
	_graphics_option.add_item("Low", 0)
	_graphics_option.add_item("Medium", 1)
	_graphics_option.add_item("High", 2)
	_graphics_option.custom_minimum_size = Vector2(180, 40)
	_graphics_option.add_theme_font_size_override("font_size", 18)
	_graphics_option.item_selected.connect(_on_graphics_selected)
	graphics_row.add_child(_graphics_option)

	var hint := Label.new()
	hint.text = "F11 / Alt+Enter でも全画面を切り替えられます"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.62, 0.70, 0.82))
	box.add_child(hint)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	box.add_child(action_row)

	_title_button = Button.new()
	_title_button.text = "タイトルへ戻る"
	_title_button.custom_minimum_size = Vector2(0, 52)
	_title_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_button.add_theme_font_size_override("font_size", 20)
	_title_button.pressed.connect(_on_title_button_pressed)
	action_row.add_child(_title_button)

	var close_button := Button.new()
	close_button.text = "閉じる / CLOSE"
	close_button.custom_minimum_size = Vector2(0, 52)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.pressed.connect(close_settings)
	action_row.add_child(close_button)

	_refresh_ui()

func _add_slider_row(parent: VBoxContainer, label_text: String, min_value: float, max_value: float, step: float, value: float, suffix: String, callback: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(280, 0)
	label.add_theme_font_size_override("font_size", 19)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(80, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.text = _format_value(value, suffix, max_value <= 8.0 and min_value >= 5.0)
	row.add_child(value_label)
	_last_value_label = value_label

	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = _format_value(v, suffix, max_value <= 8.0 and min_value >= 5.0)
		callback.call(v)
	)
	return slider

func _format_value(value: float, suffix: String, is_terrain: bool) -> String:
	if is_terrain:
		var names := {5: "Small", 6: "Normal", 7: "Large", 8: "Huge"}
		return "%d (%s)" % [int(value), str(names.get(int(value), ""))]
	if suffix == "x":
		return "%.1fx" % value
	return "%d%s" % [int(value), suffix]

func _refresh_ui() -> void:
	if _master_slider == null:
		return
	_master_slider.set_value_no_signal(master_volume * 100.0)
	_bgm_slider.set_value_no_signal(bgm_volume * 100.0)
	_se_slider.set_value_no_signal(se_volume * 100.0)
	_speed_slider.set_value_no_signal(game_speed)
	_terrain_slider.set_value_no_signal(terrain_size)
	if _master_value:
		_master_value.text = "%d%%" % int(master_volume * 100.0)
	if _bgm_value:
		_bgm_value.text = "%d%%" % int(bgm_volume * 100.0)
	if _se_value:
		_se_value.text = "%d%%" % int(se_volume * 100.0)
	if _speed_value:
		_speed_value.text = "%.1fx" % game_speed
	if _terrain_value:
		_terrain_value.text = _format_value(terrain_size, "", true)
	if _fullscreen_check:
		_fullscreen_check.set_pressed_no_signal(fullscreen)
	if _graphics_option:
		_graphics_option.select(graphics_quality)
	if _title_button:
		var scene := get_tree().current_scene if get_tree() else null
		_title_button.visible = not (scene and scene.name == "TitleScreen")
	_refresh_difficulty_ui()

func _refresh_difficulty_ui() -> void:
	for i in range(_difficulty_buttons.size()):
		var selected := i == difficulty
		_difficulty_buttons[i].text = ("● " if selected else "") + str(DIFFICULTY_NAMES[i])
		_difficulty_buttons[i].modulate = Color(1, 1, 1, 1) if selected else Color(0.72, 0.78, 0.88, 1)
	if _difficulty_desc:
		_difficulty_desc.text = str(DIFFICULTY_DESCS.get(difficulty, ""))

func _on_master_changed(value: float) -> void:
	set_master_volume(value / 100.0, false)

func _on_bgm_changed(value: float) -> void:
	set_bgm_volume(value / 100.0, false)

func _on_se_changed(value: float) -> void:
	set_se_volume(value / 100.0, false)

func _on_speed_changed(value: float) -> void:
	set_game_speed(value, false)

func _on_terrain_changed(value: float) -> void:
	set_terrain_size(int(round(value)), false)

func _on_fullscreen_toggled(enabled: bool) -> void:
	set_fullscreen(enabled, false)

func _on_graphics_selected(index: int) -> void:
	set_graphics_quality(index, false)

func _on_title_button_pressed() -> void:
	close_settings()
	var scene := get_tree().current_scene if get_tree() else null
	if scene and scene.name == "TitleScreen":
		return
	var next_scene: PackedScene = load("res://title_screen.tscn")
	if next_scene == null:
		next_scene = load("res://reference/godot4-procedurally-generated-terrain/title_screen.tscn")
	if next_scene:
		get_tree().change_scene_to_packed(next_scene)
