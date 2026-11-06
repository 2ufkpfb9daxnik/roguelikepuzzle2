extends Control

# ============================================================
# 戦闘シーン
#  - 手前に味方（最大3）、奥に敵（最大3）を同一ビューポートに配置
#  - 下段のパズル盤面でリソースを獲得し、ターン制で戦闘
#  - 属性はキャラクターごとに固定。操作キャラの属性でスキル駒が変化
# ============================================================

@onready var battle_viewport: SubViewport = $BattleViewport/SubViewport
@onready var battle_camera: Camera3D = $BattleViewport/SubViewport/BattleCamera
@onready var battle_stage: Node3D = $BattleViewport/SubViewport/BattleStage
@onready var allies_root: Node3D = $BattleViewport/SubViewport/BattleStage/Allies
@onready var enemies_root: Node3D = $BattleViewport/SubViewport/BattleStage/Enemies
@onready var ui_root: CanvasLayer = $UI
@onready var puzzle_board: Control = $UI/PuzzleBoard
@onready var fade_manager = $FadeManager

var ally_z := 5.4
var enemy_z := -5.4
var slot_spacing := 3.1
var battle_center := Vector3.ZERO

var main_ref: Node = null
var player_ref: Node3D = null
var field_camera: Camera3D = null
var player_original_position: Vector3
var camera_original_transform: Transform3D
var main_world_env: WorldEnvironment = null
var _paused_terrain: Node = null
var _terrain_process_was_enabled := true
var battle_fill_light: OmniLight3D = null

# 外部から設定される戦闘情報（enemy.gd / spawn_enemy.gd との互換）
var enemy_data: Dictionary = {}
var stage_enemy: Array = [[], [], [], [], []]
var plane_battle_pos: Vector3
var cave_battle_pos: Vector3
var desert_battle_pos: Vector3
var snow_battle_pos: Vector3
var castle_battle_pos: Vector3
var charactercamera: Camera3D = null

var biome_type: int = 0
var encountered_enemy_name: String = ""
var party: Array = []
var allies_to_spawn: Array = []
var spawned_allies: Array = []
var spawned_enemies: Array = []
var enemy_records: Array = []
var ally_start_positions: Array = []
var enemy_start_positions: Array = []
var active_index: int = 0
var battle_coin: int = 0
var party_shield: float = 0.0
var turn_number: int = 0
var battle_finished: bool = false
var resolving: bool = false

# HUD
var hud_root: Control
var title_label: Label
var banner_label: Label
var combo_label: Label
var log_label: Label
var coin_label: Label
var active_label: Label
var enemy_count_label: Label
var board_element_label: Label
var skill_help_label: Label
var fever_label: Label
var fever_bar: ProgressBar
var resource_labels: Array = []
var battle_divscore: Array = [0, 0, 0, 0, 0, 0]
var party_cards: Array = []
var party_relic_mods: Dictionary = {}
var enemy_intent_labels: Dictionary = {}
var enemy_statuses: Dictionary = {}
var fever_charge: int = 0
var fever_turns: int = 0
var shop_attack_mult: float = 1.0
var shop_defense_mult: float = 1.0
var shop_heal_mult: float = 1.0
var shop_money_mult: float = 1.0
var shop_shield_mult: float = 1.0
var shop_max_hp_mult: float = 1.0
var shop_combo_bonus: float = 0.0
var shop_potion_mult: float = 1.0
var shop_fever_mult: float = 2.0
var shop_start_shield: float = 0.0

# 画面レイアウト（論理解像度 1920x1080、CanvasLayer 側で拡縮される）
const HUD_MARGIN := 24.0
const BOTTOM_PANEL_HEIGHT := 528.0
const RIGHT_PANEL_WIDTH := 440.0
const BOARD_PANEL_WIDTH := 834.0
const BATTLE_ANIMATION_KEYWORDS := ["idle", "alert", "attack", "combo", "skill", "behit", "dead", "arise", "running", "runfast", "walk"]

# ============================================================
# 初期化
# ============================================================
func _ready() -> void:
	puzzle_board.turn_resolved.connect(_on_turn_resolved)
	puzzle_board.combo_changed.connect(_on_combo_changed)
	# フィールドと同じ World3D を使い、実際の地形の上で戦闘する。
	battle_viewport.own_world_3d = false

func set_battle_info(biome: int, enemy_name: String) -> void:
	biome_type = biome
	encountered_enemy_name = enemy_name

func set_world_environment(env: WorldEnvironment) -> void:
	main_world_env = env

func _battle_arena_marker() -> Vector3:
	# 地形生成時に各バイオームへ 10x10 の平坦な戦場を確保してある。
	match biome_type:
		0: return plane_battle_pos
		1: return cave_battle_pos
		2: return desert_battle_pos
		3: return snow_battle_pos
		4: return castle_battle_pos
	return Vector3.ZERO

func _get_battle_center() -> Vector3:
	var marker := _battle_arena_marker()
	if marker != Vector3.ZERO:
		# マーカーは戦場の左上。10x10 の中央へ合わせる。
		return marker + Vector3(5.0, 0.0, 5.0)
	# マーカー未設定時のみ、接触地点の地面へフォールバックする。
	var base := player_original_position
	var found_ground := false
	if main_ref:
		var terrain = main_ref.get_node_or_null("terrain")
		if terrain and terrain.has_method("get_ground_y"):
			var gy: int = terrain.get_ground_y(int(round(base.x)), int(base.y) + 2, int(round(base.z)))
			if gy >= 0:
				base.y = float(gy)
				found_ground = true
	if not found_ground:
		base.y -= 1.5
	return base

func _setup_battle_layout() -> void:
	battle_center = _get_battle_center()
	if battle_stage:
		battle_stage.global_position = battle_center
	if biome_type == 1:
		# 洞窟は天井が低いため、隊列とカメラをコンパクトにする。
		ally_z = 2.5
		enemy_z = -2.5
		slot_spacing = 2.0
	else:
		# 地表と城内ボス部屋は 10x10 の平坦戦場に収まる隊列幅。
		ally_z = 3.2
		enemy_z = -3.2
		slot_spacing = 3.0
	# 実際の地形は日陰だと暗いため、戦闘中だけ足元を照らす補助光を置く。
	if battle_fill_light == null:
		battle_fill_light = OmniLight3D.new()
		battle_fill_light.name = "BattleFillLight"
		battle_fill_light.light_color = Color(1.0, 0.95, 0.85)
		battle_fill_light.shadow_enabled = false
		battle_stage.add_child(battle_fill_light)
	battle_fill_light.global_position = battle_center + Vector3(0, 8.0, 0)
	if biome_type == 1 or biome_type == 4:
		battle_fill_light.light_energy = 1.3
		battle_fill_light.omni_range = 16.0
	else:
		battle_fill_light.light_energy = 1.8
		battle_fill_light.omni_range = 42.0

# ============================================================
# 戦闘準備
# ============================================================
func _setup_shop_battle_buffs() -> void:
	shop_attack_mult = 1.0
	shop_defense_mult = 1.0
	shop_heal_mult = 1.0
	shop_money_mult = 1.0
	shop_shield_mult = 1.0
	shop_max_hp_mult = 1.0
	shop_combo_bonus = 0.0
	shop_potion_mult = 1.0
	shop_fever_mult = 2.0
	shop_start_shield = 0.0
	if main_ref and main_ref.has_method("get_shop_buff_level"):
		shop_attack_mult = 1.0 + 0.15 * main_ref.get_shop_buff_level("attack")
		shop_defense_mult = 1.0 + 0.15 * main_ref.get_shop_buff_level("defense")
		shop_heal_mult = 1.0 + 0.20 * main_ref.get_shop_buff_level("heal")
		shop_money_mult = 1.0 + 0.25 * main_ref.get_shop_buff_level("money")
		shop_shield_mult = 1.0 + 0.15 * main_ref.get_shop_buff_level("defense")
		shop_max_hp_mult = 1.0 + 0.12 * main_ref.get_shop_buff_level("max_hp")
		shop_combo_bonus = 0.05 * main_ref.get_shop_buff_level("combo")
		var potion_lv = main_ref.get_shop_buff_level("potion")
		shop_potion_mult = 1.0 + 0.25 * potion_lv
		shop_fever_mult = 2.0 + 0.25 * potion_lv
		shop_start_shield = 5.0 * main_ref.get_shop_buff_level("start_shield")
		party_relic_mods["start_shield"] = float(party_relic_mods.get("start_shield", 0.0)) + shop_start_shield
	if main_ref and main_ref.has_method("get_board_buff_config") and puzzle_board and puzzle_board.has_method("set_battle_buffs"):
		puzzle_board.set_battle_buffs(main_ref.get_board_buff_config())

func prepare_battle(player: Node3D, touched_enemy: Node3D, existing_enemies: Array, allies_data: Array) -> void:
	main_ref = get_parent()
	player_ref = player
	battle_coin = 0
	party_shield = 0.0
	turn_number = 0
	battle_finished = false
	resolving = false
	battle_divscore = [0, 0, 0, 0, 0, 0]
	fever_charge = 0
	fever_turns = 0
	player_original_position = player.global_position
	allies_to_spawn = allies_data
	party = main_ref.party if main_ref and "party" in main_ref else []
	party_relic_mods = GameData.collect_party_relic_modifiers(party)
	_setup_shop_battle_buffs()

	# 触れた敵はこの直後に existing_enemies として解放される。
	# 解放後は参照できなくなるため、名前だけを先に控えておく。
	var touched_enemy_name := ""
	if is_instance_valid(touched_enemy):
		touched_enemy_name = str(touched_enemy.enemy_name)
		# 戦場ロード中にプレイヤーを遠くへ退避させるため、距離による
		# 自動デスポーンで接触した敵（呼び出し元）が消えないようにする。
		touched_enemy.set_physics_process(false)
	if touched_enemy_name == "":
		touched_enemy_name = encountered_enemy_name

	field_camera = player.get_node_or_null("Camera3D") as Camera3D
	if field_camera:
		camera_original_transform = field_camera.global_transform
		field_camera.current = false

	# 触れた敵のスクリプトが prepare_battle の await 後に処理を続けられるよう、
	# 実際の解放は戦場のロード待ちが終わるまで遅らせる。
	var enemies_to_free: Array = []
	for e in existing_enemies:
		if e and is_instance_valid(e) and e.is_inside_tree():
			enemies_to_free.append(e)
	existing_enemies.clear()
	spawned_enemies.clear()
	spawned_allies.clear()
	enemy_records.clear()
	enemy_statuses.clear()

	player.isbattle = true
	# 盤面操作と UI クリックのためにカーソルを解放する。
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# フィールド HUD（ミニマップを含む）は戦闘中は隠す。
	if main_ref and "hud_layer" in main_ref:
		var main_hud = main_ref.get("hud_layer")
		if main_hud:
			main_hud.visible = false

	_paused_terrain = main_ref.get_node_or_null("terrain") if main_ref else null

	_setup_battle_layout()
	# 生成済み戦場のチャンクを読み込ませるため、プレイヤーを非表示のまま戦場へ移動する。
	_move_player_to_battle_area()
	await _wait_for_battle_area_ready()
	if _paused_terrain and not _paused_terrain.is_generating:
		_terrain_process_was_enabled = _paused_terrain.is_processing()
		_paused_terrain.set_process(false)

	for e in enemies_to_free:
		if is_instance_valid(e):
			e.queue_free()

	_setup_camera()
	_spawn_allies()
	_spawn_enemies(touched_enemy_name)
	_build_hud()
	_apply_start_relics()
	_refresh_active_character()
	_update_hud()

func _move_player_to_battle_area() -> void:
	if player_ref == null:
		return
	# プレイヤー本体は +1000 上へ退避させたまま、ストリーミング中心だけ戦場へ移す。
	player_ref.global_position = Vector3(
		battle_center.x,
		player_original_position.y + 1000.0,
		battle_center.z
	)

func _wait_for_battle_area_ready() -> void:
	if main_ref == null:
		return
	var terrain = main_ref.get_node_or_null("terrain")
	if terrain == null or not ("chunk_state" in terrain) or not ("chunk_col_state" in terrain):
		return
	if terrain.chunk_state.is_empty() or terrain.chunk_state[0].is_empty():
		return
	var chunk_x: int = int(battle_center.x / terrain.rh)
	var chunk_z: int = int(battle_center.z / terrain.rw)
	for _frame in range(600):
		var ready := true
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var cx: int = chunk_x + dx
				var cz: int = chunk_z + dz
				if cx < 0 or cz < 0 or cx >= terrain.chunk_state.size() or cz >= terrain.chunk_state[0].size():
					continue
				if int(terrain.chunk_state[cx][cz]) != 2 or int(terrain.chunk_col_state[cx][cz]) != 2:
					ready = false
					break
			if not ready:
				break
		if ready:
			await get_tree().process_frame
			return
		await get_tree().process_frame
	push_warning("Battle arena chunks did not finish loading in time.")

func _setup_camera() -> void:
	# 平坦な生成済み戦場なので、固定カメラで十分に収まる。
	var offset := Vector3(0, 12.5, 10.5)
	var fov := 46.0
	if biome_type == 1:
		offset = Vector3(0, 3.8, 7.0)
		fov = 62.0
	elif biome_type == 4:
		# 城内ボス部屋は広いが天井が低いので、高さを抑えて後方から見る。
		offset = Vector3(0, 4.5, 11.0)
		fov = 55.0
	battle_camera.global_position = battle_center + offset
	# 左下のパズル盤面に隠れないよう、注視点を少し左へずらして戦場を右寄りに表示する。
	battle_camera.look_at(battle_center + Vector3(-2.4, 1.2, 0), Vector3.UP)
	battle_camera.fov = fov
	battle_camera.current = true

func _spawn_allies() -> void:
	var spawn_count: int = mini(allies_to_spawn.size(), GameData.MAX_PARTY_SIZE)
	for i in range(spawn_count):
		var info: Dictionary = allies_to_spawn[i]
		var ally_instance := CharacterBody3D.new()
		ally_instance.name = "Ally_%d_%s" % [i, str(info.get("id", info.get("name", "ally")))]
		var ally_script = load("res://ally.gd")
		if ally_script is GDScript:
			ally_instance.set_script(ally_script)
		else:
			continue

		var model_paths := _list_model_paths(str(info.get("path", "")))
		var battle_model_paths := _filter_battle_animations(model_paths)
		ally_instance.set_animation_model_paths(battle_model_paths if not battle_model_paths.is_empty() else model_paths)
		ally_instance.preload_battle_animations()
		_attach_first_model(ally_instance, model_paths)

		ally_instance.type = int(info.get("type", 4))
		ally_instance.element = int(info.get("element", GameData.Element.FIRE))
		ally_instance.character_index = i
		ally_instance.character_name = str(info.get("id", info.get("name", "")))
		ally_instance.level = int(info.get("level", 1))
		ally_instance.attack = int(info.get("attack", 10))
		ally_instance.defense = int(info.get("defense", 10))
		ally_instance.max_health = int(info.get("max_health", 100))
		ally_instance.health = int(info.get("health", ally_instance.max_health))
		ally_instance.skill_power = party[i].get_skill_power() if i < party.size() else 1.0
		ally_instance.state = UnitBase.UnitState.BATTLE_IDLE
		var pos := _slot_position(true, i, spawn_count)
		ally_instance.position = pos
		ally_instance.rotation = Vector3(0, PI, 0)
		allies_root.add_child(ally_instance)
		ally_instance.hp_camera = battle_camera
		ally_instance.setup_hp_bar_for_battle()
		_add_unit_name_label(ally_instance, _display_name(info.get("id", "?")), int(info.get("element", 1)), Vector3(0, 2.5, 0))
		spawned_allies.append(ally_instance)
		ally_start_positions.append(pos)
		_try_play_idle(ally_instance)

func _spawn_enemies(touched_name: String) -> void:
	var names: Array = []
	if touched_name != "":
		names.append(touched_name)
	var pool: Array = []
	if biome_type >= 0 and biome_type < stage_enemy.size():
		pool = stage_enemy[biome_type].duplicate()
	pool.shuffle()
	for candidate in pool:
		if names.size() >= 3:
			break
		if str(candidate) == touched_name:
			continue
		if randf() < 0.5:
			names.append(str(candidate))
	if names.is_empty() and touched_name != "":
		names.append(touched_name)

	var spawn_count := mini(names.size(), 3)
	for i in range(spawn_count):
		var enemy_name: String = str(names[i])
		var enemy_instance := CharacterBody3D.new()
		enemy_instance.name = "Enemy_%d_%s" % [i, enemy_name]
		var enemy_script = load("res://enemy.gd")
		if enemy_script is GDScript:
			enemy_instance.set_script(enemy_script)
		else:
			continue

		var info = enemy_data.get(enemy_name, {})
		var model_path: String = "res://model/enemy/have_animation/%s/Animation_Alert_withSkin.glb" % enemy_name
		var anim_paths: Array = [model_path]
		if info is Dictionary:
			model_path = str(info.get("model_path", model_path))
			anim_paths = info.get("anim_paths", [model_path])
		elif info is Array and info.size() > 0:
			model_path = str(info[0])
			if info.size() > 1 and info[1] is Array:
				anim_paths = info[1]
			else:
				anim_paths = [model_path]
		var battle_anim_paths := _filter_battle_animation_array(anim_paths)
		enemy_instance.set_animation_model_paths(battle_anim_paths if not battle_anim_paths.is_empty() else anim_paths)
		enemy_instance.preload_battle_animations()
		_attach_first_model(enemy_instance, {model_path.get_file().get_basename(): model_path})

		var config: Array = []
		if main_ref and "all_characters" in main_ref:
			config = main_ref.all_characters.get(enemy_name, [])
		var base_hp: int = int(config[0]) if config.size() > 0 else 120
		var base_atk: int = int(config[1]) if config.size() > 1 else 22
		var base_def: int = int(config[2]) if config.size() > 2 else 12
		var enemy_type: int = int(config[3]) if config.size() > 3 else 4

		var diff_hp := 1.0
		var diff_atk := 1.0
		var settings = get_node_or_null("/root/SettingsManager")
		if settings:
			diff_hp = settings.get_difficulty_hp_mult()
			diff_atk = settings.get_difficulty_atk_mult()
		enemy_instance.enemy_name = enemy_name
		enemy_instance.type = enemy_type
		enemy_instance.element = GameData.element_for_character(enemy_name, enemy_type)
		enemy_instance.max_health = max(1, int(base_hp * pow(10.0, biome_type) * diff_hp))
		enemy_instance.health = enemy_instance.max_health
		enemy_instance.attack = max(1, int(base_atk * pow(2.0, biome_type) * diff_atk))
		enemy_instance.defense = base_def
		enemy_instance.state = UnitBase.UnitState.BATTLE_IDLE
		var pos := _slot_position(false, i, spawn_count)
		enemy_instance.position = pos
		enemy_instance.rotation = Vector3.ZERO
		enemies_root.add_child(enemy_instance)
		enemy_instance.hp_camera = battle_camera
		enemy_instance.setup_hp_bar_for_battle()
		if enemy_instance.has_method("adjust_model_to_ground"):
			enemy_instance.adjust_model_to_ground()
		enemy_instance.state = UnitBase.UnitState.BATTLE_IDLE
		_add_unit_name_label(enemy_instance, _display_name(enemy_name), enemy_instance.element, Vector3(0, 2.5, 0))
		var intent_label := Label3D.new()
		intent_label.text = ""
		intent_label.font_size = 26
		intent_label.modulate = Color(1.0, 0.45, 0.35)
		intent_label.outline_size = 6
		intent_label.outline_modulate = Color(0, 0, 0, 0.9)
		intent_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		intent_label.position = Vector3(0, 3.0, 0)
		intent_label.pixel_size = 0.004
		enemy_instance.add_child(intent_label)
		enemy_intent_labels[enemy_instance.get_instance_id()] = intent_label
		spawned_enemies.append(enemy_instance)
		enemy_start_positions.append(pos)
		enemy_records.append({
			"name": enemy_name,
			"model_path": model_path,
			"type": enemy_type,
			"base_hp": base_hp,
			"base_atk": base_atk,
			"base_def": base_def
		})
		_try_play_idle(enemy_instance)

func _slot_position(ally: bool, index: int, count: int) -> Vector3:
	var center_offset := (count - 1) * 0.5
	var x := (index - center_offset) * slot_spacing
	# 戦場の地面は 10x10 で平坦。少し上から落として接地させる。
	return Vector3(x, 1.5, ally_z if ally else enemy_z)

func _is_battle_animation(anim_name: String) -> bool:
	var lower := anim_name.to_lower()
	for keyword in BATTLE_ANIMATION_KEYWORDS:
		if keyword in lower:
			return true
	return false

func _filter_battle_animations(paths: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in paths.keys():
		if _is_battle_animation(str(key)):
			result[key] = paths[key]
	return result

func _filter_battle_animation_array(paths: Array) -> Array:
	var result: Array = []
	for p in paths:
		if _is_battle_animation(str(p).get_file().get_basename()):
			result.append(p)
	return result

func _list_model_paths(path: String) -> Dictionary:
	var result: Dictionary = {}
	if path == "":
		return result
	if path.get_extension().to_lower() in ["glb", "gltf", "tscn"]:
		result[path.get_file().get_basename()] = path
		return result
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension().to_lower() in ["glb", "gltf", "tscn"]:
				result[file_name.get_basename()] = path.path_join(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	return result

func _attach_first_model(unit: Node3D, model_paths: Dictionary) -> void:
	if model_paths.is_empty():
		return
	var chosen_key: String = str(model_paths.keys()[0])
	for key in model_paths.keys():
		var lower := str(key).to_lower()
		if "idle" in lower or "alert" in lower:
			chosen_key = str(key)
			break
	var first_path: String = str(model_paths[chosen_key])
	if not ResourceLoader.exists(first_path):
		return
	var scene_res = load(first_path)
	if scene_res is PackedScene:
		var container := Node3D.new()
		container.name = "VisualModelRoot"
		unit.add_child(container)
		var visual = scene_res.instantiate()
		container.add_child(visual)
		var loaded = unit.get("loaded_models")
		if loaded is Dictionary:
			loaded[chosen_key] = visual

func _try_play_idle(unit: Node3D) -> void:
	if unit.has_method("assign_battle_idle_anim"):
		unit.assign_battle_idle_anim()
	if unit.has_method("_play_any_idle_animation"):
		unit._play_any_idle_animation()

func _add_unit_name_label(unit: Node3D, text: String, element: int, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 34
	label.modulate = GameData.element_color(element)
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	label.pixel_size = 0.004
	unit.add_child(label)

func _display_name(id) -> String:
	var text := str(id)
	if text == "":
		return "?"
	return text.replace("_", " ").capitalize()

# ============================================================
# HUD 構築
# ============================================================
func _build_hud() -> void:
	if hud_root and is_instance_valid(hud_root):
		hud_root.queue_free()
	hud_root = Control.new()
	hud_root.name = "BattleHUD"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hud_root)

	# 左上: 戦闘情報と 5 種類の蓄積値（ガイド 12.1 / 12.2）
	var top_left_panel := PanelContainer.new()
	top_left_panel.position = Vector2(HUD_MARGIN - 10.0, 14.0)
	top_left_panel.custom_minimum_size = Vector2(700, 0)
	top_left_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.06, 0.11, 0.72), Color(0.30, 0.45, 0.72, 0.65)))
	hud_root.add_child(top_left_panel)

	var top_left := VBoxContainer.new()
	top_left.add_theme_constant_override("separation", 4)
	top_left_panel.add_child(top_left)

	title_label = Label.new()
	title_label.text = "BATTLE  %s" % _biome_name()
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title_label.add_theme_constant_override("outline_size", 6)
	top_left.add_child(title_label)

	var resource_row := HBoxContainer.new()
	resource_row.add_theme_constant_override("separation", 18)
	top_left.add_child(resource_row)
	resource_labels.clear()
	var resource_names := ["盾", "剣", "コイン", "ポーション", "回復"]
	var resource_colors := [
		Color(0.55, 0.78, 1.0), Color(1.0, 0.55, 0.45), Color(1.0, 0.86, 0.30),
		Color(0.82, 0.55, 1.0), Color(0.55, 0.95, 0.60)
	]
	for i in range(resource_names.size()):
		var resource_label := Label.new()
		resource_label.text = "%s 0" % resource_names[i]
		resource_label.add_theme_font_size_override("font_size", 19)
		resource_label.add_theme_color_override("font_color", resource_colors[i])
		resource_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		resource_label.add_theme_constant_override("outline_size", 4)
		resource_row.add_child(resource_label)
		resource_labels.append(resource_label)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 22)
	top_left.add_child(status_row)

	coin_label = Label.new()
	coin_label.add_theme_font_size_override("font_size", 20)
	coin_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
	status_row.add_child(coin_label)

	enemy_count_label = Label.new()
	enemy_count_label.add_theme_font_size_override("font_size", 18)
	enemy_count_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.55))
	status_row.add_child(enemy_count_label)

	board_element_label = Label.new()
	board_element_label.add_theme_font_size_override("font_size", 16)
	board_element_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	board_element_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	board_element_label.add_theme_constant_override("outline_size", 4)
	top_left.add_child(board_element_label)

	var fever_row := HBoxContainer.new()
	fever_row.add_theme_constant_override("separation", 10)
	fever_label = Label.new()
	fever_label.text = "FEVER 0%"
	fever_label.add_theme_font_size_override("font_size", 16)
	fever_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.85))
	fever_row.add_child(fever_label)
	fever_bar = ProgressBar.new()
	fever_bar.custom_minimum_size = Vector2(280, 16)
	fever_bar.max_value = 100
	fever_bar.value = 0
	fever_bar.show_percentage = false
	var fever_bg := StyleBoxFlat.new()
	fever_bg.bg_color = Color(0.12, 0.07, 0.13, 0.9)
	fever_bg.set_corner_radius_all(5)
	var fever_fill := StyleBoxFlat.new()
	fever_fill.bg_color = Color(1.0, 0.35, 0.72, 0.95)
	fever_fill.set_corner_radius_all(5)
	fever_bar.add_theme_stylebox_override("background", fever_bg)
	fever_bar.add_theme_stylebox_override("fill", fever_fill)
	fever_row.add_child(fever_bar)
	top_left.add_child(fever_row)

	# 右側: パーティ / スキル（ガイド 12.1 の右カラム）
	var right_panel := PanelContainer.new()
	right_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right_panel.offset_left = -RIGHT_PANEL_WIDTH - HUD_MARGIN
	right_panel.offset_top = -BOTTOM_PANEL_HEIGHT - 12.0
	right_panel.offset_right = -HUD_MARGIN
	right_panel.offset_bottom = -12.0
	right_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.08, 0.13, 0.92), Color(0.35, 0.52, 0.85, 0.8)))
	hud_root.add_child(right_panel)

	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_box)

	active_label = Label.new()
	active_label.add_theme_font_size_override("font_size", 20)
	active_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	right_box.add_child(active_label)

	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 5)
	card_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(card_box)
	party_cards.clear()
	for i in range(GameData.MAX_PARTY_SIZE):
		var card := _create_party_card(i)
		card_box.add_child(card["panel"])
		party_cards.append(card)

	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 10)
	right_box.add_child(lower)

	skill_help_label = Label.new()
	skill_help_label.text = "剣・盾・回復の一致駒でスキルゲージ増加\n満タンで属性スキル駒を自動配置"
	skill_help_label.add_theme_font_size_override("font_size", 12)
	skill_help_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	skill_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_child(skill_help_label)

	combo_label = Label.new()
	combo_label.set_anchors_preset(Control.PRESET_CENTER)
	combo_label.offset_left = -300
	combo_label.offset_top = -220
	combo_label.offset_right = 300
	combo_label.offset_bottom = -150
	combo_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	combo_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 42)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	combo_label.add_theme_constant_override("outline_size", 8)
	combo_label.visible = false
	hud_root.add_child(combo_label)

	log_label = Label.new()
	log_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	log_label.offset_left = BOARD_PANEL_WIDTH + HUD_MARGIN * 2.0
	log_label.offset_top = -46
	log_label.offset_right = -RIGHT_PANEL_WIDTH - HUD_MARGIN * 2.0
	log_label.offset_bottom = -14
	log_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_label.add_theme_font_size_override("font_size", 15)
	log_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	log_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	log_label.add_theme_constant_override("outline_size", 4)
	hud_root.add_child(log_label)

	banner_label = Label.new()
	banner_label.set_anchors_preset(Control.PRESET_CENTER)
	banner_label.offset_left = -620
	banner_label.offset_top = -310
	banner_label.offset_right = 620
	banner_label.offset_bottom = -180
	banner_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 64)
	banner_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	banner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	banner_label.add_theme_constant_override("outline_size", 12)
	banner_label.visible = false
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(banner_label)

func _create_party_card(index: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 120)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.12, 0.18, 0.95), Color(0.25, 0.35, 0.55, 0.7)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var stripe := ColorRect.new()
	stripe.custom_minimum_size = Vector2(7, 0)
	stripe.color = Color(0.8, 0.8, 0.8)
	row.add_child(stripe)

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 2)
	row.add_child(info_box)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 17)
	info_box.add_child(name_label)

	var hp_label := Label.new()
	hp_label.add_theme_font_size_override("font_size", 12)
	info_box.add_child(hp_label)

	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 14)
	hp_bar.show_percentage = false
	hp_bar.max_value = 100
	info_box.add_child(hp_bar)

	var ult_label := Label.new()
	ult_label.add_theme_font_size_override("font_size", 13)
	info_box.add_child(ult_label)

	var ult_bar := ProgressBar.new()
	ult_bar.custom_minimum_size = Vector2(0, 18)
	ult_bar.show_percentage = false
	ult_bar.max_value = 100
	var gauge_bg := StyleBoxFlat.new()
	gauge_bg.bg_color = Color(0.07, 0.08, 0.12, 0.95)
	gauge_bg.set_corner_radius_all(4)
	ult_bar.add_theme_stylebox_override("background", gauge_bg)
	info_box.add_child(ult_bar)

	var select_button := Button.new()
	select_button.text = "交代"
	select_button.custom_minimum_size = Vector2(72, 64)
	select_button.add_theme_font_size_override("font_size", 14)
	select_button.pressed.connect(_on_select_character.bind(index))
	row.add_child(select_button)

	return {
		"panel": panel,
		"stripe": stripe,
		"name": name_label,
		"hp_label": hp_label,
		"hp_bar": hp_bar,
		"ult_label": ult_label,
		"ult_bar": ult_bar,
		"button": select_button
	}

func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _biome_name() -> String:
	match biome_type:
		0: return "草原"
		1: return "洞窟"
		2: return "砂漠"
		3: return "雪原"
		4: return "魔王城"
	return "戦場"

# ============================================================
# 戦闘開始 / ターン進行
# ============================================================
func _apply_start_relics() -> void:
	var shield_amount := int(party_relic_mods.get("start_shield", 0.0))
	if shield_amount > 0:
		party_shield += shield_amount
		_log("レリック: 戦闘開始シールド +%d" % shield_amount)

func start_battle() -> void:
	battle_finished = false
	await _banner("Battle Start!", 0.9)
	_start_player_turn()

func _start_player_turn() -> void:
	if battle_finished:
		return
	if _living_allies().is_empty():
		_finish_defeat()
		return
	if _living_enemies().is_empty():
		_finish_victory()
		return
	turn_number += 1
	resolving = false
	_refresh_active_character()
	_deploy_ready_skill_piece()
	_update_enemy_intents()
	puzzle_board.canmove = true
	_update_hud()
	_log("Turn %d - パズルを操作してください" % turn_number)

func _deploy_ready_skill_piece() -> void:
	if party.is_empty() or active_index < 0 or active_index >= party.size():
		return
	var active_char: CharacterData = party[active_index]
	if active_char.ult_charge < 100:
		return
	if not puzzle_board.place_skill_piece():
		_log("スキル駒を置ける空きがありません。")
		return
	active_char.ult_charge = 0
	_log("%s の%sスキル駒が盤面に配置された！" % [
		_display_name(active_char.id), active_char.get_skill_attribute_name()
	])
	_banner("%sスキル！" % active_char.get_skill_attribute_name(), 0.65)
	_update_hud()

func _update_enemy_intents() -> void:
	for enemy in spawned_enemies:
		if not is_instance_valid(enemy) or enemy.hp <= 0:
			continue
		var label: Label3D = enemy_intent_labels.get(enemy.get_instance_id())
		if label == null:
			continue
		var intent := "攻撃"
		if enemy.type == 0:
			intent = "回復" if randf() < 0.5 else "攻撃"
		elif enemy.type in [8, 10] and randf() < 0.35:
			intent = "全体攻撃"
		var status_text := _status_text(enemy)
		if status_text != "":
			label.text = "次: %s\n%s" % [intent, status_text]
		else:
			label.text = "次: %s" % intent

func _status_text(enemy: Node3D) -> String:
	var status := _get_enemy_status(enemy)
	var parts: Array = []
	if int(status["poison"]) > 0 and int(status["poison_turns"]) > 0:
		parts.append("毒×%d" % int(status["poison"]))
	if int(status["burn"]) > 0 and int(status["burn_turns"]) > 0:
		parts.append("燃焼 %dT" % int(status["burn_turns"]))
	if int(status["freeze"]) > 0:
		parts.append("凍結")
	if int(status["stun"]) > 0:
		parts.append("感電")
	return " ".join(parts)

func _on_turn_resolved(result: Dictionary) -> void:
	if battle_finished or resolving:
		return
	resolving = true
	var turn_scores: Array = result.get("score", [])
	for i in range(mini(battle_divscore.size(), turn_scores.size())):
		battle_divscore[i] = int(battle_divscore[i]) + int(turn_scores[i])
	await _resolve_player_actions(result)
	if battle_finished:
		return
	if _living_enemies().is_empty():
		await _finish_victory()
		return
	await _enemy_turn()
	if battle_finished:
		return
	if _living_allies().is_empty():
		await _finish_defeat()
		return
	await _tick_enemy_statuses()
	if battle_finished:
		return
	if _living_enemies().is_empty():
		await _finish_victory()
		return
	if fever_turns > 0:
		fever_turns -= 1
		if fever_turns == 0:
			_log("フィーバー終了")
	_start_player_turn()

func _resolve_player_actions(result: Dictionary) -> void:
	var scores: Array = result.get("score", [])
	var combo: int = int(result.get("combo", 1))
	var element_hits: Dictionary = result.get("element_hits", {})
	var combo_mult: float = 1.0 + max(0, combo - 1) * (0.25 + shop_combo_bonus)
	var shield_count := int(scores[0]) if scores.size() > 0 else 0
	var sword_count := int(scores[1]) if scores.size() > 1 else 0
	var coin_count := int(scores[2]) if scores.size() > 2 else 0
	var potion_count := int(scores[3]) if scores.size() > 3 else 0
	var food_count := int(scores[4]) if scores.size() > 4 else 0
	var skill_count := int(scores[5]) if scores.size() > 5 else 0
	var fever_mult: float = shop_fever_mult if fever_turns > 0 else 1.0
	var active_char: CharacterData = party[active_index] if active_index < party.size() else null

	if coin_count > 0:
		var coin_mod: float = 1.0 + float(party_relic_mods.get("coin_bonus", 0.0))
		if active_char:
			coin_mod += float(active_char.get_character_modifiers().get("coin_bonus", 0.0))
		var gain := int(coin_count * 8 * coin_mod * fever_mult * shop_money_mult)
		battle_coin += gain
		_log("コイン +%d" % gain)

	if food_count > 0:
		var heal := int((food_count * 24 + 8) * combo_mult * fever_mult * shop_heal_mult)
		_heal_lowest_ally(heal)

	if shield_count > 0:
		var shield := int(shield_count * 32 * combo_mult * fever_mult * shop_shield_mult)
		party_shield += shield
		_log("シールド +%d" % shield)

	if potion_count > 0:
		if fever_turns > 0:
			_log("フィーバー中：ポーションは次回分として蓄積されません")
		else:
			var fever_gain := mini(100, int(potion_count * 18 * combo_mult * shop_potion_mult))
			fever_charge = clampi(fever_charge + fever_gain, 0, 100)
			_log("フィーバーゲージ +%d" % fever_gain)
			if fever_charge >= 100:
				_activate_fever()

	if active_char == null:
		_update_hud()
		await get_tree().create_timer(0.15).timeout
		return

	# 操作キャラのスキル属性と一致する駒を消すとスキルゲージが溜まり、
	# ついでにキャラ属性のスキル攻撃が発動する。
	var attr_piece: int = active_char.get_skill_attribute()
	var attr_count := int(scores[attr_piece]) if attr_piece >= 0 and attr_piece < scores.size() else 0
	if attr_count > 0:
		var skill_gain := int(attr_count * 10 * combo_mult * fever_mult)
		active_char.ult_charge = clampi(active_char.ult_charge + skill_gain, 0, 100)
		_log("%sゲージ +%d" % [active_char.get_skill_attribute_name(), skill_gain])
		await _trigger_element_skill(active_char, attr_count, combo_mult * fever_mult, active_char.element)

	if skill_count > 0:
		party_shield += float(active_char.get_character_modifiers().get("skill_shield", 0.0))
		await _use_skill_pieces(active_char, skill_count, element_hits, combo_mult * fever_mult)

	if sword_count > 0:
		await _party_physical_attack(active_char, sword_count, combo_mult * fever_mult)

	_update_hud()
	if sword_count == 0 and skill_count == 0:
		_log("攻撃リソースなし")
	await get_tree().create_timer(0.15).timeout

func _activate_fever() -> void:
	fever_turns = 3
	fever_charge = 0
	_log("FEVER!! 3ターンの間、獲得リソースとスキル効果が2倍！")
	_banner("FEVER!", 0.9)

func _party_physical_attack(active_char: CharacterData, sword_count: int, combo_mult: float) -> void:
	var living := _living_enemies()
	if living.is_empty():
		return
	var attackers := _living_allies()
	for ally in attackers:
		if _living_enemies().is_empty():
			break
		var target = _living_enemies().pick_random()
		var char_index: int = ally.character_index
		var char_data: CharacterData = party[char_index] if char_index >= 0 and char_index < party.size() else active_char
		var attack_stat := float(ally.attack)
		var raw := int(sword_count * (attack_stat + 10.0) * 0.55 * combo_mult)
		await _animate_lunge(ally, target)
		var dealt := _damage_enemy(target, raw, char_data.element, char_data)
		_log("%s の攻撃: %d" % [_display_name(char_data.id), dealt])
		await get_tree().create_timer(0.08).timeout

func _use_skill_pieces(active_char: CharacterData, skill_count: int, element_hits: Dictionary, combo_mult: float) -> void:
	if skill_count <= 0:
		return
	var hit_element: int = active_char.element
	if not element_hits.is_empty():
		hit_element = int(element_hits.keys()[0])
	await _trigger_element_skill(active_char, skill_count, combo_mult, hit_element)

# キャラ属性に対応するスキル攻撃。
# 直接ダメージに加えて、属性ごとの状態異常・支援効果を付与する。
func _trigger_element_skill(active_char: CharacterData, count: int, combo_mult: float, element: int) -> void:
	if count <= 0:
		return
	var actor: Node3D = _ally_for_index(active_index)
	if actor:
		await _animate_actor_forward(actor)

	var base := int((count * (18 + active_char.level * 5)) * active_char.get_skill_power() * combo_mult * shop_attack_mult)
	var targets := _living_enemies()
	for target in targets:
		if is_instance_valid(target):
			_damage_enemy(target, base, element, active_char)

	match element:
		GameData.Element.POISON:
			for target in targets:
				if not is_instance_valid(target) or target.hp <= 0:
					continue
				var status := _get_enemy_status(target)
				status["poison"] = int(status["poison"]) + count
				status["poison_turns"] = 99
			_log("%sスキル：敵を毒状態にした（盤面に毒がある間、継続ダメージ）" % GameData.element_name(element))
		GameData.Element.FIRE:
			for target in targets:
				if not is_instance_valid(target) or target.hp <= 0:
					continue
				var status := _get_enemy_status(target)
				status["burn"] = int(status["burn"]) + count * (4 + active_char.level)
				status["burn_turns"] = maxi(int(status["burn_turns"]), 2)
			_log("%sスキル：敵を燃焼状態にした" % GameData.element_name(element))
		GameData.Element.ICE:
			for target in targets:
				if not is_instance_valid(target) or target.hp <= 0:
					continue
				var status := _get_enemy_status(target)
				status["freeze"] = maxi(int(status["freeze"]), 1)
			_log("%sスキル：敵を凍結させた" % GameData.element_name(element))
		GameData.Element.THUNDER:
			for target in targets:
				if not is_instance_valid(target) or target.hp <= 0:
					continue
				if randf() < 0.45:
					var status := _get_enemy_status(target)
					status["stun"] = maxi(int(status["stun"]), 1)
			_log("%sスキル：敵に感電を付与した" % GameData.element_name(element))
		GameData.Element.WATER, GameData.Element.WOOD:
			var heal := int(count * (8 + active_char.level * 3) * combo_mult * shop_heal_mult)
			for ally in _living_allies():
				ally.receive_heal(heal)
				_sync_ally_to_party(ally)
			_log("%sスキル：味方全員を %d 回復" % [GameData.element_name(element), heal])
		GameData.Element.LIGHT:
			var heal := int(count * (10 + active_char.level * 3) * combo_mult * shop_heal_mult)
			for ally in _living_allies():
				ally.receive_heal(heal)
				_sync_ally_to_party(ally)
			for target in targets:
				if is_instance_valid(target):
					var status := _get_enemy_status(target)
					status["poison"] = 0
					status["burn"] = 0
			_log("%sスキル：味方を回復し、敵の状態異常を浄化" % GameData.element_name(element))
		GameData.Element.DARK:
			var heal := int(base * 0.35 * shop_heal_mult)
			if actor and is_instance_valid(actor):
				actor.receive_heal(heal)
				_sync_ally_to_party(actor)
			_log("%sスキル：与えたダメージの一部を吸収" % GameData.element_name(element))
		GameData.Element.EARTH:
			var shield_gain := int(count * (24 + active_char.level * 5) * combo_mult * shop_shield_mult)
			party_shield += shield_gain
			_log("%sスキル：シールド +%d" % [GameData.element_name(element), shield_gain])
		GameData.Element.WIND:
			var shield_gain := int(count * (14 + active_char.level * 3) * combo_mult * shop_shield_mult)
			party_shield += shield_gain
			_log("%sスキル：風の護りでシールド +%d" % [GameData.element_name(element), shield_gain])
		_:
			pass

	_update_enemy_intents()
	await get_tree().create_timer(0.15).timeout
	if actor and is_instance_valid(actor):
		await _return_actor(actor, active_index, true)

func _get_enemy_status(enemy: Node3D) -> Dictionary:
	var key := enemy.get_instance_id()
	if not enemy_statuses.has(key):
		enemy_statuses[key] = {
			"poison": 0,
			"poison_turns": 0,
			"burn": 0,
			"burn_turns": 0,
			"freeze": 0,
			"stun": 0
		}
	return enemy_statuses[key]

# ターン終了時の状態異常処理。毒は「盤面に毒スキル駒がある間」だけ継続する。
func _tick_enemy_statuses() -> void:
	if _living_enemies().is_empty():
		return
	var poison_on_board: bool = puzzle_board.has_element_piece(GameData.Element.POISON)
	var active_char: CharacterData = party[active_index] if active_index < party.size() else null
	var poison_power: int = 4
	if active_char:
		poison_power += active_char.level * 2
	for enemy in _living_enemies():
		if not is_instance_valid(enemy):
			continue
		var status := _get_enemy_status(enemy)
		if poison_on_board and int(status["poison"]) > 0 and int(status["poison_turns"]) > 0:
			var poison_damage := int(status["poison"]) * poison_power
			_damage_enemy(enemy, poison_damage, GameData.Element.POISON, null)
			_log("毒ダメージ %d（盤面に毒が残っている）" % poison_damage)
			await get_tree().create_timer(0.12).timeout
		if is_instance_valid(enemy) and enemy.hp > 0 and int(status["burn"]) > 0 and int(status["burn_turns"]) > 0:
			var burn_damage := int(status["burn"])
			_damage_enemy(enemy, burn_damage, GameData.Element.FIRE, null)
			status["burn_turns"] = int(status["burn_turns"]) - 1
			if int(status["burn_turns"]) <= 0:
				status["burn"] = 0
			_log("燃焼ダメージ %d" % burn_damage)
			await get_tree().create_timer(0.12).timeout
	_update_enemy_intents()
	_update_hud()

func _damage_enemy(target: Node3D, raw: int, attack_element: int, source: CharacterData) -> int:
	if not is_instance_valid(target) or target.hp <= 0:
		return 0
	var multiplier := GameData.damage_multiplier(attack_element, target.element)
	var element_bonus := float(party_relic_mods.get("element_bonus", 0.0))
	var damage := int(raw * multiplier * (1.0 + element_bonus))
	var crit := false
	if source and randf() < source.get_crit_chance():
		damage = int(damage * 1.6)
		crit = true
	if GameData.damage_multiplier(attack_element, target.element) > 1.0:
		_log("属性有利！")
	var dealt: int = target.take_damage(max(1, damage))
	if crit:
		_log("クリティカル！")
	return dealt

func _heal_lowest_ally(amount: int) -> void:
	var living := _living_allies()
	if living.is_empty():
		return
	living.sort_custom(func(a, b): return a.hp < b.hp)
	var target = living[0]
	target.receive_heal(amount)
	_sync_ally_to_party(target)
	_log("回復 +%d" % amount)

func _sync_ally_to_party(ally: Node3D) -> void:
	if not is_instance_valid(ally):
		return
	var idx: int = ally.character_index
	if idx >= 0 and idx < party.size():
		party[idx].cur_health = ally.hp

# ============================================================
# スキル
# ============================================================
func _on_select_character(index: int) -> void:
	if battle_finished or resolving or index < 0 or index >= party.size():
		return
	if puzzle_board.is_animating or puzzle_board.turn_active:
		return
	var ally = _ally_for_index(index)
	if ally == null or ally.hp <= 0:
		return
	active_index = index
	_refresh_active_character()
	_update_hud()
	_log("操作キャラを %s に変更" % _display_name(party[index].id))

func _on_skill_pressed() -> void:
	# 通常はターン開始時に自動配置される。デバッグ用の手動配置。
	if battle_finished or resolving:
		return
	_deploy_ready_skill_piece()

# ============================================================
# 敵ターン
# ============================================================
func _enemy_turn() -> void:
	_log("敵のターン")
	var enemies := _living_enemies()
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.hp <= 0:
			continue
		if _living_allies().is_empty():
			break
		var enemy_status := _get_enemy_status(enemy)
		if int(enemy_status["freeze"]) > 0:
			enemy_status["freeze"] = int(enemy_status["freeze"]) - 1
			_log("%s は凍結して動けない" % _display_name(enemy.enemy_name))
			await get_tree().create_timer(0.35).timeout
			continue
		if int(enemy_status["stun"]) > 0:
			enemy_status["stun"] = int(enemy_status["stun"]) - 1
			_log("%s は感電して動けない" % _display_name(enemy.enemy_name))
			await get_tree().create_timer(0.35).timeout
			continue
		await get_tree().create_timer(0.25).timeout
		if enemy.type == 0 and randf() < 0.5:
			await _enemy_heal(enemy)
			continue
		if enemy.type in [8, 10] and randf() < 0.35:
			await _enemy_all_attack(enemy)
		else:
			await _enemy_single_attack(enemy)
	party_shield = 0.0
	_update_hud()
	await get_tree().create_timer(0.2).timeout

func _enemy_single_attack(enemy: Node3D) -> void:
	var targets := _living_allies()
	if targets.is_empty():
		return
	var target = targets.pick_random()
	await _animate_enemy_lunge(enemy, target)
	var raw := int(enemy.attack * randf_range(0.85, 1.2))
	var dealt := _damage_ally(target, raw)
	_log("%s の攻撃: %d" % [_display_name(enemy.enemy_name), dealt])
	if is_instance_valid(enemy):
		enemy.position = _enemy_home_position(enemy)
	await get_tree().create_timer(0.12).timeout

func _enemy_all_attack(enemy: Node3D) -> void:
	await _animate_actor_forward(enemy)
	for target in _living_allies():
		_damage_ally(target, int(enemy.attack * 0.55))
	_log("%s の全体攻撃" % _display_name(enemy.enemy_name))
	if is_instance_valid(enemy):
		enemy.position = _enemy_home_position(enemy)
	await get_tree().create_timer(0.2).timeout

func _enemy_heal(enemy: Node3D) -> void:
	var living := _living_enemies()
	if living.is_empty():
		return
	living.sort_custom(func(a, b): return a.hp < b.hp)
	var heal := int(enemy.attack * 1.5)
	living[0].receive_heal(heal)
	_log("%s が仲間を回復" % _display_name(enemy.enemy_name))
	await get_tree().create_timer(0.3).timeout

func _damage_ally(target: Node3D, raw: int) -> int:
	if not is_instance_valid(target) or target.hp <= 0:
		return 0
	var reduction := clampf(float(party_relic_mods.get("damage_reduction", 0.0)), 0.0, 0.5)
	var ally_index: int = -1
	var raw_index = target.get("character_index")
	if raw_index != null:
		ally_index = int(raw_index)
	if ally_index >= 0 and ally_index < party.size():
		reduction += float(party[ally_index].get_character_modifiers().get("damage_reduction", 0.0))
	reduction = clampf(reduction, 0.0, 0.5)
	var remaining := float(raw) * (1.0 - reduction)
	if party_shield > 0.0:
		var blocked: float = min(party_shield, remaining)
		party_shield -= blocked
		remaining -= blocked
		if blocked > 0:
			_log("シールドが %d 軽減" % int(blocked))
	if remaining <= 0:
		_update_hud()
		return 0
	var dealt: int = target.take_damage(int(remaining))
	_sync_ally_to_party(target)
	if target.hp <= 0:
		var fallen_name := str(target.get("character_name"))
		if fallen_name == "":
			fallen_name = str(target.name)
		_log("%s は倒れた" % _display_name(fallen_name))
	_update_hud()
	return dealt

# ============================================================
# 勝敗 / 終了
# ============================================================
func _finish_victory() -> void:
	if battle_finished:
		return
	battle_finished = true
	puzzle_board.canmove = false
	resolving = true
	await _banner("YOU WIN!", 1.0)
	_log_turn_end()

	var exp_gain := int((16 + biome_type * 12) * (1.0 + float(party_relic_mods.get("exp_bonus", 0.0))))
	if main_ref and main_ref.has_method("add_exp_to_party"):
		main_ref.add_exp_to_party(exp_gain)
		_log("EXP +%d" % exp_gain)

	# 倒した敵が低確率で起き上がり、仲間になる。
	var recruited_names: Array = []
	for record in enemy_records:
		if main_ref == null or not main_ref.has_method("can_recruit_more") or not main_ref.can_recruit_more():
			break
		if randf() >= GameData.RECRUIT_CHANCE:
			continue
		var new_member: CharacterData = null
		if main_ref.has_method("try_recruit_enemy"):
			new_member = main_ref.try_recruit_enemy(
				str(record.get("name", "")),
				str(record.get("model_path", "")),
				int(record.get("type", 4)),
				int(record.get("base_hp", 80)),
				int(record.get("base_atk", 20)),
				int(record.get("base_def", 10))
			)
		if new_member:
			recruited_names.append(new_member.id)
			_log("%s が仲間になった！" % _display_name(new_member.id))
			await _banner("%s が仲間になった！" % _display_name(new_member.id), 1.2)

	await get_tree().create_timer(1.0).timeout
	end_battle()

func _finish_defeat() -> void:
	if battle_finished:
		return
	battle_finished = true
	puzzle_board.canmove = false
	resolving = true
	await _banner("GAME OVER", 1.2)
	_log_turn_end()
	await get_tree().create_timer(0.8).timeout
	end_battle()

func _log_turn_end() -> void:
	if main_ref and main_ref.has_method("add_money"):
		main_ref.add_money(battle_coin)
		battle_coin = 0

func end_battle() -> void:
	var results: Array = []
	for ally in spawned_allies:
		if not is_instance_valid(ally):
			continue
		var ult_value := 0
		if ally.character_index >= 0 and ally.character_index < party.size():
			ult_value = party[ally.character_index].ult_charge
		results.append({
			"index": ally.character_index,
			"hp": ally.hp,
			"ult_charge": ult_value
		})
	for i in range(party.size()):
		var found := false
		for result in results:
			if int(result["index"]) == i:
				found = true
				break
		if not found:
			results.append({"index": i, "hp": party[i].cur_health, "ult_charge": party[i].ult_charge})
	if main_ref and main_ref.has_method("apply_battle_results"):
		main_ref.apply_battle_results(results)

	if main_ref and main_ref.has_method("add_money"):
		main_ref.add_money(battle_coin)
	battle_coin = 0

	if fade_manager:
		await fade_manager.fade_in(0.8)
	if player_ref:
		player_ref.global_position = player_original_position
		player_ref.isbattle = false
	if field_camera:
		field_camera.global_transform = camera_original_transform
		field_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var spawn_node = main_ref.get_node_or_null("spawn_enemy") if main_ref else null
	if spawn_node:
		if spawn_node.has_method("reset_spawn_state"):
			spawn_node.reset_spawn_state()
		else:
			spawn_node.isspawned.clear()
			spawn_node.spawn_time = 0.0
	if main_ref and "hud_layer" in main_ref:
		var main_hud = main_ref.get("hud_layer")
		if main_hud:
			main_hud.visible = true
	if is_instance_valid(_paused_terrain):
		_paused_terrain.set_process(_terrain_process_was_enabled)
	_paused_terrain = null
	queue_free()

# ============================================================
# HUD 更新
# ============================================================
func _refresh_active_character() -> void:
	if party.is_empty():
		return
	if active_index < 0 or active_index >= party.size():
		active_index = 0
	if _ally_for_index(active_index) == null:
		for i in range(party.size()):
			if _ally_for_index(i) != null:
				active_index = i
				break
	var active_char: CharacterData = party[active_index]
	var skills_unlocked := active_char.get_node_level("offense_1") > 0 or active_char.get_skill_power() > 1.0
	puzzle_board.configure(active_char.element, active_char.level, skills_unlocked, active_char.get_skill_attribute())
	if board_element_label:
		if skills_unlocked:
			board_element_label.text = "操作属性: %s  /  スキル属性: %s  /  スキル駒: %s" % [
				active_char.get_element_name(), active_char.get_skill_attribute_name(),
				GameData.element_name(active_char.element)
			]
		else:
			board_element_label.text = "操作属性: %s  /  スキル属性: %s  /  スキル駒: 未解禁" % [
				active_char.get_element_name(), active_char.get_skill_attribute_name()
			]
		board_element_label.add_theme_color_override("font_color", active_char.get_element_color())

func _update_hud() -> void:
	if not coin_label:
		return
	if title_label:
		title_label.text = "BATTLE  %s   TURN %d" % [_biome_name(), maxi(turn_number, 1)]
	var resource_names := ["盾", "剣", "コイン", "ポーション", "回復"]
	for i in range(resource_labels.size()):
		var value := int(battle_divscore[i]) if i < battle_divscore.size() else 0
		resource_labels[i].text = "%s %d" % [resource_names[i], value]
	coin_label.text = "コイン: %d" % ((main_ref.money if main_ref else 0) + battle_coin)
	var living_enemy_count := _living_enemies().size()
	enemy_count_label.text = "敵: %d　シールド: %d" % [living_enemy_count, int(party_shield)]
	if active_index < party.size():
		var active_char: CharacterData = party[active_index]
		active_label.text = "操作中: %s  [%s / %s]  スキルチャージ %d%%" % [
			_display_name(active_char.id), active_char.get_element_name(),
			active_char.get_skill_attribute_name(), active_char.ult_charge
		]
		active_label.add_theme_color_override("font_color", active_char.get_element_color())
	for i in range(party_cards.size()):
		var card: Dictionary = party_cards[i]
		var panel: PanelContainer = card["panel"]
		if i >= party.size():
			panel.visible = false
			continue
		panel.visible = true
		var c: CharacterData = party[i]
		var ally = _ally_for_index(i)
		var max_hp: int = int(ally.max_hp) if ally else int(c.get_max_health() * shop_max_hp_mult)
		var hp: int = ally.hp if ally else (c.cur_health if c.cur_health >= 0 else max_hp)
		var shown_atk: int = int(ally.attack) if ally else int(c.get_attack() * shop_attack_mult)
		var shown_def: int = int(ally.defense) if ally else int(c.get_defense() * shop_defense_mult)
		var border_color := c.get_element_color()
		if i == active_index:
			panel.add_theme_stylebox_override("panel", _panel_style(Color(0.14, 0.17, 0.26, 0.98), border_color))
		else:
			panel.add_theme_stylebox_override("panel", _panel_style(Color(0.09, 0.11, 0.16, 0.92), border_color.darkened(0.35)))
		card["stripe"].color = border_color
		card["name"].text = "%s  Lv.%d  [%s / %s]" % [
			_display_name(c.id), c.level, c.get_element_name(), c.get_skill_attribute_name()
		]
		card["hp_label"].text = "HP %d / %d   ATK %d   DEF %d   EXP %d/%d" % [
			hp, max_hp, shown_atk, shown_def, c.exp, c.get_exp_to_next()
		]
		card["hp_bar"].max_value = max_hp
		card["hp_bar"].value = hp
		card["ult_label"].text = "スキルチャージ %d / 100  [%s駒]" % [c.ult_charge, c.get_skill_attribute_name()]
		card["ult_label"].add_theme_color_override("font_color", c.get_element_color())
		card["ult_bar"].value = c.ult_charge
		var gauge_fill := StyleBoxFlat.new()
		gauge_fill.bg_color = c.get_element_color() if c.ult_charge < 100 else Color(1.0, 0.88, 0.32)
		gauge_fill.set_corner_radius_all(4)
		card["ult_bar"].add_theme_stylebox_override("fill", gauge_fill)
		card["button"].disabled = (ally == null or i == active_index)
	if skill_help_label:
		if not party.is_empty() and active_index < party.size():
			var active_char: CharacterData = party[active_index]
			skill_help_label.text = "%s駒を消すとスキルチャージ増加 + %sスキル攻撃\n満タンで%sスキル駒を自動配置" % [
				active_char.get_skill_attribute_name(), active_char.get_element_name(), active_char.get_skill_attribute_name()
			]
		else:
			skill_help_label.text = "スキルゲージが満タンになると属性スキル駒を自動配置"
	if fever_bar and fever_label:
		if fever_turns > 0:
			fever_label.text = "FEVER!! 残り%dターン" % fever_turns
			fever_bar.value = 100
		else:
			fever_label.text = "FEVER %d%%" % fever_charge
			fever_bar.value = fever_charge

func _on_combo_changed(combo: int) -> void:
	if combo <= 1:
		combo_label.visible = false
		return
	combo_label.text = "COMBO %d!" % combo
	combo_label.visible = true
	combo_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(combo_label, "modulate:a", 0.0, 0.4)

func _banner(text: String, duration: float) -> void:
	if not banner_label:
		return
	banner_label.text = text
	banner_label.visible = true
	banner_label.modulate.a = 1.0
	await get_tree().create_timer(duration).timeout
	banner_label.visible = false

func _log(text: String) -> void:
	if log_label:
		log_label.text = text
	print("[Battle] ", text)

# ============================================================
# 3D 演出ヘルパー
# ============================================================
func _living_allies() -> Array:
	var result: Array = []
	for ally in spawned_allies:
		if is_instance_valid(ally) and ally.hp > 0:
			result.append(ally)
	return result

func _living_enemies() -> Array:
	var result: Array = []
	for enemy in spawned_enemies:
		if is_instance_valid(enemy) and enemy.hp > 0:
			result.append(enemy)
	return result

func _ally_for_index(index: int) -> Node3D:
	for ally in spawned_allies:
		if is_instance_valid(ally) and ally.character_index == index and ally.hp > 0:
			return ally
	return null

func _animate_lunge(actor: Node3D, target: Node3D) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(target):
		return
	actor.state = UnitBase.UnitState.BATTLE_MOVE
	var start := actor.position
	var target_pos := target.position + Vector3(0, 0, 1.2)
	var tween := create_tween()
	tween.tween_property(actor, "position", target_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	actor.state = UnitBase.UnitState.ATTACK_SINGLE
	await get_tree().create_timer(0.1).timeout
	var back := create_tween()
	back.tween_property(actor, "position", start, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await back.finished
	if is_instance_valid(actor):
		actor.state = UnitBase.UnitState.BATTLE_IDLE
		actor.isanim = false
		actor.current_animation_name = ""

func _animate_actor_forward(actor: Node3D) -> void:
	if not is_instance_valid(actor):
		return
	var start := actor.position
	var toward := Vector3(start.x * 0.6, start.y, start.z + (-1.2 if start.z > 0 else 1.2))
	var tween := create_tween()
	tween.tween_property(actor, "position", toward, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

func _return_actor(actor: Node3D, index: int, ally: bool) -> void:
	if not is_instance_valid(actor):
		return
	var start_pos := Vector3.ZERO
	if ally and index >= 0 and index < ally_start_positions.size():
		start_pos = ally_start_positions[index]
	elif not ally and index >= 0 and index < enemy_start_positions.size():
		start_pos = enemy_start_positions[index]
	var tween := create_tween()
	tween.tween_property(actor, "position", start_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(actor):
		actor.state = UnitBase.UnitState.BATTLE_IDLE
		actor.isanim = false
		actor.current_animation_name = ""

func _animate_enemy_lunge(enemy: Node3D, target: Node3D) -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(target):
		return
	enemy.state = UnitBase.UnitState.BATTLE_MOVE
	var start := enemy.position
	var tween := create_tween()
	tween.tween_property(enemy, "position", start + Vector3(0, 0, 2.4), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	enemy.state = UnitBase.UnitState.ATTACK_SINGLE
	await get_tree().create_timer(0.1).timeout
	var back := create_tween()
	back.tween_property(enemy, "position", start, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await back.finished
	if is_instance_valid(enemy):
		enemy.state = UnitBase.UnitState.BATTLE_IDLE
		enemy.isanim = false
		enemy.current_animation_name = ""

func _enemy_home_position(enemy: Node3D) -> Vector3:
	var index := spawned_enemies.find(enemy)
	if index >= 0 and index < enemy_start_positions.size():
		return enemy_start_positions[index]
	return enemy.position
