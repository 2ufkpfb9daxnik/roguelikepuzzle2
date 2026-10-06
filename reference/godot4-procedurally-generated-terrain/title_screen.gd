extends Control

var isclicked = false
var interval = 0

func _ready() -> void:
	get_node("titlebgm").play()
	
	# Connect buttons
	if has_node("VBoxContainer/Button"):
		get_node("VBoxContainer/Button").pressed.connect(_on_button_pressed)
	if has_node("VBoxContainer/SettingsButton"):
		get_node("VBoxContainer/SettingsButton").pressed.connect(_on_settings_pressed)
	if has_node("SettingsPanel/VBoxContainer/CloseSettings"):
		get_node("SettingsPanel/VBoxContainer/CloseSettings").pressed.connect(_on_close_settings_pressed)
		
	if has_node("SettingsPanel/VBoxContainer/VolumeSlider"):
		var slider = get_node("SettingsPanel/VBoxContainer/VolumeSlider")
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
		slider.value_changed.connect(_on_volume_changed)
		
	if has_node("SettingsPanel/VBoxContainer/GraphicsCheck"):
		var check = get_node("SettingsPanel/VBoxContainer/GraphicsCheck")
		check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		check.toggled.connect(_on_graphics_toggled)
		
	var s = _load_settings()
	if has_node("SettingsPanel/VBoxContainer/MapSizeSlider"):
		var map_slider = get_node("SettingsPanel/VBoxContainer/MapSizeSlider")
		map_slider.value = s.exp
		map_slider.value_changed.connect(_on_map_size_changed)
		
	if has_node("SettingsPanel/VBoxContainer/GraphicsOption"):
		var gfx_opt = get_node("SettingsPanel/VBoxContainer/GraphicsOption")
		gfx_opt.selected = s.gfx
		gfx_opt.item_selected.connect(_on_graphics_level_selected)

func _on_button_pressed() -> void:
	if(isclicked):
		return
	print("pressed")
	if has_node("click"):
		get_node("click").play()
	isclicked = true

func _on_settings_pressed() -> void:
	get_node("SettingsPanel").visible = true

func _on_close_settings_pressed() -> void:
	get_node("SettingsPanel").visible = false

func _on_volume_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	if value == 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)

func _on_graphics_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _save_settings(exp_val, gfx_val):
	var file = FileAccess.open("user://game_settings.json", FileAccess.WRITE)
	if file:
		var data = {"exp": exp_val, "gfx": gfx_val}
		file.store_string(JSON.stringify(data))

func _load_settings():
	var file = FileAccess.open("user://game_settings.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if typeof(json) == TYPE_DICTIONARY:
			return json
	return {"exp": 6, "gfx": 1}

func _on_map_size_changed(value: float) -> void:
	var s = _load_settings()
	_save_settings(int(value), s.gfx)

func _on_graphics_level_selected(index: int) -> void:
	var s = _load_settings()
	_save_settings(s.exp, index)

func _process(delta: float) -> void:
	if(isclicked):
		if(interval<30):
			if has_node("anten"):
				get_node("anten").color.a += 0.03
		elif(interval>=40):
			if has_node("anten"):
				get_node("anten").color.a = 0
			isclicked = false
			var next_scene = load("res://reference/godot4-procedurally-generated-terrain/main.tscn")
			if not next_scene:
				next_scene = load("res://main.tscn")
			get_tree().change_scene_to_packed(next_scene)
		interval += 1
