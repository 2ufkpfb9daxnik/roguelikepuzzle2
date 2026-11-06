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
var fever_started_this_turn := false
var fever_title_label: Label = null
var fever_dance_layer: Node2D = null
var fever_dancers: Array = []
var _fever_dance_3d: Array = []
var _fever_dance_scene: PackedScene = null
var _fever_dance_load_started := false
var fever_dance_frames: SpriteFrames = null
var fever_se_player: AudioStreamPlayer = null
var battle_action_label: Label = null
var turn_element_values: Dictionary = {}
var battle_potions: int = 0
var is_boss_battle: bool = false
var is_final_boss: bool = false
var battle_lost: bool = false
var element_value_labels: Dictionary = {}
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
		shop_fever_mult += float(party_relic_mods.get("fever_bonus", 0.0))
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
	fever_started_this_turn = false
	_hide_fever_dancers()
	turn_element_values.clear()
	battle_potions = 0
	is_boss_battle = false
	is_final_boss = false
	battle_lost = false
	player_original_position = player.global_position
	allies_to_spawn = allies_data
	if main_ref and main_ref.has_method("get_battle_party"):
		party = main_ref.get_battle_party()
	else:
		party = main_ref.party if main_ref and "party" in main_ref else []
	party_relic_mods = GameData.collect_party_relic_modifiers(party)
	_setup_shop_battle_buffs()
	_start_fever_dance_preload()

	# 触れた敵はこの直後に existing_enemies として解放される。
	# 解放後は参照できなくなるため、名前だけを先に控えておく。
	var touched_enemy_name := ""
	if is_instance_valid(touched_enemy):
		touched_enemy_name = str(touched_enemy.enemy_name)
		is_boss_battle = bool(touched_enemy.get("is_boss"))
		is_final_boss = is_boss_battle and biome_type == 4
		# 戦場ロード中にプレイヤーを遠くへ退避させるため、距離による
		# 自動デスポーンで接触した敵（呼び出し元）が消えないようにする。
		touched_enemy.set_physics_process(false)
	if touched_enemy_name == "":
		touched_enemy_name = encountered_enemy_name
	if touched_enemy_name in ["blue_dragon", "cave_dragon", "demon", "rainbow_snake_dragon", "sea_dragon"]:
		is_boss_battle = true
		is_final_boss = biome_type == 4

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
	_spawn_businessman_avatar()

func _spawn_businessman_avatar() -> void:
	if main_ref == null or allies_root == null:
		return
	var config: Array = []
	if "all_characters" in main_ref:
		config = main_ref.all_characters.get("businessman", [])
	var model_path := "res://model/businessman 3d model.glb"
	if config.size() > 4 and str(config[4]) != "":
		model_path = str(config[4])
	var model_paths := _list_model_paths(model_path)
	var battle_paths := _filter_battle_animations(model_paths)
	var avatar := Ally.new()
	avatar.name = "PlayerAvatar_Businessman"
	avatar.character_index = -1
	avatar.character_name = "businessman"
	avatar.element = GameData.Element.LIGHT
	avatar.level = 1
	avatar.attack = 0
	avatar.defense = 0
	avatar.max_health = 9999
	avatar.health = 9999
	avatar.set_animation_model_paths(battle_paths if not battle_paths.is_empty() else model_paths)
	avatar.state = UnitBase.UnitState.BATTLE_IDLE
	allies_root.add_child(avatar)
	avatar.position = Vector3(0, 1.5, ally_z + 2.6)
	avatar.rotation = Vector3(0, PI, 0)
	_add_unit_name_label(avatar, "ビジネスマン", GameData.Element.LIGHT, Vector3(0, 2.8, 0))
	_try_play_idle(avatar)

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
		enemy_instance.set_spawn_origin(pos)
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

	# スキル駒を消して得た属性値。攻撃フェーズで「属性値 / パーティ人数」が
	# 0 より大きいキャラだけが属性スキルを発動する。
	var element_row := HBoxContainer.new()
	element_row.add_theme_constant_override("separation", 14)
	top_left.add_child(element_row)
	element_value_labels.clear()
	var seen_elements: Array = []
	for c in party:
		if c == null:
			continue
		for raw_element in c.get_elements():
			var element_value := int(raw_element)
			if seen_elements.has(element_value):
				continue
			seen_elements.append(element_value)
			var element_label := Label.new()
			element_label.text = "%s 0" % GameData.element_name(element_value)
			element_label.add_theme_font_size_override("font_size", 18)
			element_label.add_theme_color_override("font_color", GameData.element_color(element_value))
			element_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			element_label.add_theme_constant_override("outline_size", 4)
			element_row.add_child(element_label)
			element_value_labels[element_value] = element_label

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

	# フィーバー突入時の大バナー。SE 後にダンサーへ切り替わる。
	fever_title_label = Label.new()
	fever_title_label.set_anchors_preset(Control.PRESET_CENTER)
	fever_title_label.offset_left = -700
	fever_title_label.offset_top = -260
	fever_title_label.offset_right = 700
	fever_title_label.offset_bottom = -60
	fever_title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fever_title_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	fever_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fever_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fever_title_label.add_theme_font_size_override("font_size", 86)
	fever_title_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.82))
	fever_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
	fever_title_label.add_theme_constant_override("outline_size", 16)
	fever_title_label.visible = false
	fever_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(fever_title_label)

	# 各キャラの行動名を画面下中央にも表示する。
	battle_action_label = Label.new()
	battle_action_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	battle_action_label.offset_left = -520
	battle_action_label.offset_top = -170
	battle_action_label.offset_right = 520
	battle_action_label.offset_bottom = -112
	battle_action_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	battle_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_action_label.add_theme_font_size_override("font_size", 30)
	battle_action_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	battle_action_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	battle_action_label.add_theme_constant_override("outline_size", 8)
	battle_action_label.modulate.a = 0.0
	battle_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(battle_action_label)

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
	_play_battle_bgm()
	await _banner("Battle Start!", 0.9)
	_start_player_turn()

func _bgm_manager() -> Node:
	return get_node_or_null("/root/BGMManager")

func _play_battle_bgm() -> void:
	var bgm := _bgm_manager()
	if bgm and bgm.has_method("play_battle"):
		bgm.play_battle(is_boss_battle, is_final_boss)

func _play_fever_bgm() -> void:
	var bgm := _bgm_manager()
	if bgm and bgm.has_method("play_fever"):
		bgm.play_fever()

func _play_ending_bgm() -> void:
	var bgm := _bgm_manager()
	if bgm and bgm.has_method("play_ending"):
		bgm.play_ending()

func _play_field_bgm() -> void:
	var bgm := _bgm_manager()
	if bgm and bgm.has_method("play_field"):
		bgm.play_field()

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
	turn_element_values.clear()
	_refresh_active_character()
	_update_enemy_intents()
	puzzle_board.canmove = true
	_update_hud()
	_log("Turn %d - パズルを操作してください" % turn_number)

func _deploy_ready_skill_piece() -> void:
	if party.is_empty() or active_index < 0 or active_index >= party.size():
		return
	var active_char: CharacterData = party[active_index]
	var active_elements := active_char.get_elements()
	if active_elements.is_empty():
		return
	var piece_id := GameData.piece_id_for_element(int(active_elements.pick_random()))
	if not puzzle_board.place_skill_piece(piece_id):
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
	turn_element_values = result.get("element_hits", {}).duplicate()
	await _resolve_player_actions(result)
	turn_element_values.clear()
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
		if fever_started_this_turn:
			fever_started_this_turn = false
		else:
			fever_turns -= 1
			if fever_turns == 0:
				_log("フィーバー終了")
				_hide_fever_dancers()
				_play_battle_bgm()
	_start_player_turn()

func _resolve_player_actions(result: Dictionary) -> void:
	var scores: Array = result.get("score", [])
	var combo: int = int(result.get("combo", 1))
	var combo_mult: float = 1.0 + max(0, combo - 1) * (0.25 + shop_combo_bonus + float(party_relic_mods.get("combo_bonus", 0.0)))
	var coin_count := int(scores[2]) if scores.size() > 2 else 0
	var potion_count := int(scores[3]) if scores.size() > 3 else 0
	var fever_mult: float = shop_fever_mult if fever_turns > 0 else 1.0
	var active_char: CharacterData = party[active_index] if active_index < party.size() else null

	if coin_count > 0:
		var coin_mod: float = 1.0 + float(party_relic_mods.get("coin_bonus", 0.0))
		if active_char:
			coin_mod += float(active_char.get_character_modifiers().get("coin_bonus", 0.0))
		var gain := int(coin_count * 8 * coin_mod * fever_mult * shop_money_mult)
		battle_coin += gain
		_log("コイン +%d" % gain)

	if potion_count > 0:
		if fever_turns > 0:
			_log("フィーバー中：ポーションは次回分として蓄積されません")
		else:
			var fever_gain := mini(100, int(potion_count * 18 * combo_mult * shop_potion_mult))
			fever_charge = clampi(fever_charge + fever_gain, 0, 100)
			_log("フィーバーゲージ +%d" % fever_gain)
			if fever_charge >= 100:
				await _activate_fever()
		# ポーションはインベントリのスキル強化通貨にもなる。
		var potion_gain := int(potion_count * 8 * combo_mult * shop_potion_mult)
		battle_potions += potion_gain
		if main_ref and main_ref.has_method("add_potions"):
			main_ref.add_potions(potion_gain)
		_log("ポーション +%d" % potion_gain)

	if active_char == null:
		_update_hud()
		await get_tree().create_timer(0.15).timeout
		return

	await _party_attack_phase(result, combo_mult * fever_mult)
	_update_hud()
	await get_tree().create_timer(0.15).timeout

# 攻撃フェーズ:
#  - 各キャラの攻撃値 = そのターンに獲得した剣の値 × そのキャラの攻撃力
#  - スキル駒を消して得た属性値 / パーティ人数 > 0 なら、そのキャラの属性スキルを敵全体へ発動
func _party_attack_phase(result: Dictionary, combo_mult: float) -> void:
	var scores: Array = result.get("score", [])
	var shield_count := int(scores[0]) if scores.size() > 0 else 0
	var sword_count := int(scores[1]) if scores.size() > 1 else 0
	var food_count := int(scores[4]) if scores.size() > 4 else 0
	var party_count: int = maxi(1, party.size())
	var acted := false
	for char_index in range(party.size()):
		if _living_enemies().is_empty():
			break
		var char_data: CharacterData = party[char_index]
		var ally = _ally_for_index(char_index)
		if ally == null:
			continue

		var role := char_data.get_skill_attribute()
		if role == GameData.Piece.SWORD and sword_count > 0:
			var target = _living_enemies().pick_random()
			if target:
				var attack_power := int(ally.attack)
				var sword_bonus := 1.0 + float(party_relic_mods.get("sword_bonus", 0.0)) + float(char_data.get_character_modifiers().get("sword_bonus", 0.0))
				var attack_value := int(sword_count * attack_power * 0.55 * combo_mult * sword_bonus)
				var attack_element := _best_attack_element(char_data, target)
				_show_action_focus(ally, "剣攻撃", GameData.element_color(attack_element))
				await _animate_lunge(ally, target)
				var dealt := _damage_enemy(target, max(1, attack_value), attack_element, char_data)
				_log("%s の剣攻撃: %d（剣%d × 攻撃力%d / %s）" % [
					_display_name(char_data.id), dealt, sword_count, attack_power,
					GameData.element_name(attack_element)
				])
				acted = true
				await get_tree().create_timer(0.08).timeout
		elif role == GameData.Piece.SHIELD and shield_count > 0:
			var shield_bonus := 1.0 + float(party_relic_mods.get("shield_bonus", 0.0)) + float(char_data.get_character_modifiers().get("shield_bonus", 0.0))
			var shield_gain := int(shield_count * (float(ally.defense) + 5.0) * 0.8 * combo_mult * shop_shield_mult * shield_bonus)
			party_shield += float(shield_gain)
			_show_action_focus(ally, "盾防御", GameData.element_color(char_data.element))
			_log("%s の盾防御: シールド +%d（盾%d × 防御力%d）" % [
				_display_name(char_data.id), shield_gain, shield_count, int(ally.defense)
			])
			acted = true
			await get_tree().create_timer(0.2).timeout
		elif role == GameData.Piece.FOOD and food_count > 0:
			var heal_bonus := 1.0 + float(party_relic_mods.get("heal_bonus", 0.0)) + float(char_data.get_character_modifiers().get("heal_bonus", 0.0))
			var heal := int(food_count * (float(ally.attack) * 0.5 + 10.0) * combo_mult * shop_heal_mult * heal_bonus)
			for target_ally in _living_allies():
				target_ally.receive_heal(heal)
				_sync_ally_to_party(target_ally)
			_show_action_focus(ally, "回復", Color(0.45, 0.95, 0.55))
			_log("%s の回復: 味方全員 +%d（回復%d）" % [
				_display_name(char_data.id), heal, food_count
			])
			acted = true
			await get_tree().create_timer(0.2).timeout

		# 二属性キャラは、属性ごとに属性値が条件を満たせばそれぞれスキルを発動する。
		for raw_element in char_data.get_elements():
			if _living_enemies().is_empty():
				break
			var skill_element := int(raw_element)
			var element_value := int(turn_element_values.get(skill_element, 0))
			var share := float(element_value) / float(party_count)
			if share > 0.0:
				await _trigger_element_skill_for(char_data, char_index, share, combo_mult, skill_element)
				acted = true

	if not acted:
		_log("攻撃リソースなし")

func _best_attack_element(char_data: CharacterData, target: Node3D) -> int:
	var best_element: int = char_data.element
	var best_mult := -1.0
	for raw_element in char_data.get_elements():
		var candidate := int(raw_element)
		var mult := GameData.damage_multiplier(candidate, target.element)
		if mult > best_mult:
			best_mult = mult
			best_element = candidate
	return best_element

func _activate_fever() -> void:
	if fever_turns > 0:
		return
	fever_turns = 5
	fever_started_this_turn = true
	fever_charge = 0
	_log("★ FEVER TIME!! ★ 5手の間、獲得リソースとスキル効果が2倍！")
	# 元ゲームと同じく、突入時はBGMを止めて専用SEを鳴らし、
	# SE が終わってからフィーバーダンスとフィーバーBGMへ移る。
	var bgm := _bgm_manager()
	if bgm and bgm.has_method("stop_all"):
		bgm.stop_all()
	_show_fever_title()
	var wait_time := _play_fever_intro_se()
	await get_tree().create_timer(wait_time).timeout
	if battle_finished:
		return
	_hide_fever_title()
	await _show_fever_dancers()
	if battle_finished:
		return
	_play_fever_bgm()
	_update_hud()

func _play_fever_intro_se() -> float:
	if fever_se_player == null:
		fever_se_player = AudioStreamPlayer.new()
		fever_se_player.name = "FeverIntroSE"
		fever_se_player.bus = "SE" if AudioServer.get_bus_index("SE") != -1 else "Master"
		add_child(fever_se_player)
	var se_path := "res://sound/se/patinko/THROUGHOUT_BOUNS継続音.mp3"
	if fever_se_player.stream == null and ResourceLoader.exists(se_path):
		fever_se_player.stream = load(se_path)
	if fever_se_player.stream == null:
		return 1.6
	fever_se_player.play()
	return clampf(fever_se_player.stream.get_length(), 0.8, 6.0)

func _show_fever_title() -> void:
	if fever_title_label == null:
		return
	fever_title_label.text = "★ FEVER TIME!! ★\n残り%d手" % fever_turns
	fever_title_label.visible = true
	fever_title_label.modulate.a = 1.0
	fever_title_label.scale = Vector2(0.4, 0.4)
	fever_title_label.pivot_offset = fever_title_label.size * 0.5
	var tween := create_tween()
	tween.tween_property(fever_title_label, "scale", Vector2(1.12, 1.12), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(fever_title_label, "scale", Vector2.ONE, 0.12)

func _hide_fever_title() -> void:
	if fever_title_label == null or not fever_title_label.visible:
		return
	var tween := create_tween()
	tween.tween_property(fever_title_label, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if is_instance_valid(fever_title_label):
			fever_title_label.visible = false
	)

func _get_fever_dance_frames() -> SpriteFrames:
	if fever_dance_frames != null:
		return fever_dance_frames
	var tres_path := "res://texture/fever_dance/fever_dance_frames.tres"
	if ResourceLoader.exists(tres_path):
		var res = load(tres_path)
		if res is SpriteFrames:
			fever_dance_frames = res
			return fever_dance_frames
	fever_dance_frames = SpriteFrames.new()
	fever_dance_frames.add_animation("dance")
	fever_dance_frames.set_animation_loop("dance", true)
	fever_dance_frames.set_animation_speed("dance", 24.0)
	for i in range(256):
		var path := "res://texture/fever_dance/frames/frame_%04d.png" % i
		if not ResourceLoader.exists(path):
			break
		fever_dance_frames.add_frame("dance", load(path))
	return fever_dance_frames

func _ensure_fever_dance_layer() -> void:
	if fever_dance_layer != null and is_instance_valid(fever_dance_layer):
		return
	fever_dance_layer = Node2D.new()
	fever_dance_layer.name = "FeverDanceLayer"
	fever_dance_layer.z_index = 25
	ui_root.add_child(fever_dance_layer)

func _start_fever_dance_preload() -> void:
	if _fever_dance_load_started:
		return
	_fever_dance_load_started = true
	var path := "res://model/fever_dance.glb"
	if ResourceLoader.exists(path):
		ResourceLoader.load_threaded_request(path, "PackedScene")

func _get_fever_dance_scene_async() -> PackedScene:
	if _fever_dance_scene != null:
		return _fever_dance_scene
	_start_fever_dance_preload()
	var path := "res://model/fever_dance.glb"
	if not ResourceLoader.exists(path):
		return null
	var status := ResourceLoader.load_threaded_get_status(path)
	var waited := 0
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and waited < 900:
		await get_tree().process_frame
		waited += 1
		status = ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var res = ResourceLoader.load_threaded_get(path)
		if res is PackedScene:
			_fever_dance_scene = res
	return _fever_dance_scene

func _show_fever_dance_3d(scene: PackedScene) -> bool:
	if scene == null or battle_stage == null:
		return false
	if _fever_dance_3d.is_empty():
		var placements := [
			{"pos": Vector3(-3.6, 0.05, -6.8), "scale": 1.8, "flip": false},
			{"pos": Vector3(0.0, 0.05, -7.8), "scale": 2.1, "flip": false},
			{"pos": Vector3(3.6, 0.05, -6.8), "scale": 1.8, "flip": true}
		]
		for i in range(placements.size()):
			var info: Dictionary = placements[i]
			var dancer: Node3D = scene.instantiate()
			dancer.name = "FeverDancer3D_%d" % i
			battle_stage.add_child(dancer)
			var spawn_pos: Vector3 = info["pos"]
			dancer.position = spawn_pos
			var s := float(info["scale"])
			dancer.scale = Vector3(s, s, s)
			dancer.rotation = Vector3(0, 0 if not bool(info["flip"]) else 0.35, 0)
			var ap: AnimationPlayer = dancer.find_child("AnimationPlayer", true, false)
			var clip := ""
			if ap:
				var clips: Array = []
				for anim_name in ap.get_animation_list():
					var anim_res := ap.get_animation(anim_name)
					if anim_res and anim_res.length > 2.0:
						clips.append(anim_name)
				if not clips.is_empty():
					clip = str(clips[i % clips.size()])
					ap.play(clip)
					ap.animation_finished.connect(_on_fever_dancer_anim_finished.bind(ap, dancer, clip))
			_fever_dance_3d.append({"node": dancer, "anim": ap, "clip": clip})
	for entry in _fever_dance_3d:
		var node: Node3D = entry.get("node", null)
		if node != null and is_instance_valid(node):
			node.visible = true
			var ap: AnimationPlayer = entry.get("anim", null)
			var clip: String = str(entry.get("clip", ""))
			if ap and clip != "":
				ap.play(clip)
	return true

func _on_fever_dancer_anim_finished(_anim_name: String, ap: AnimationPlayer, dancer: Node3D, clip: String) -> void:
	if is_instance_valid(ap) and is_instance_valid(dancer) and dancer.visible and clip != "":
		ap.play(clip)

func _show_fever_dancers() -> void:
	# GLB にダンスアニメーションが含まれているため、まず3D上に配置する。
	var scene := await _get_fever_dance_scene_async()
	if _show_fever_dance_3d(scene):
		return
	_ensure_fever_dance_layer()
	var frames := _get_fever_dance_frames()
	if frames == null or frames.get_frame_count("dance") == 0:
		_log("フィーバーダンス画像が見つかりません。")
		return
	if fever_dancers.is_empty():
		var placements := [
			{"pos": Vector2(250, 300), "scale": 0.28, "flip": false},
			{"pos": Vector2(1670, 300), "scale": 0.28, "flip": true},
			{"pos": Vector2(250, 830), "scale": 0.36, "flip": false},
			{"pos": Vector2(1670, 830), "scale": 0.36, "flip": true},
			{"pos": Vector2(960, 900), "scale": 0.30, "flip": false}
		]
		for info in placements:
			var dancer := AnimatedSprite2D.new()
			var spawn_pos: Vector2 = info["pos"]
			dancer.sprite_frames = frames
			dancer.animation = "dance"
			dancer.position = spawn_pos
			dancer.scale = Vector2(0.05, 0.05)
			dancer.flip_h = bool(info["flip"])
			dancer.modulate.a = 0.0
			dancer.z_index = 25
			fever_dance_layer.add_child(dancer)
			fever_dancers.append({"sprite": dancer, "target_scale": float(info["scale"])})
	var tween := create_tween()
	tween.set_parallel(true)
	for entry in fever_dancers:
		var dancer: AnimatedSprite2D = entry["sprite"]
		if dancer == null or not is_instance_valid(dancer):
			continue
		dancer.visible = true
		dancer.scale = Vector2(0.05, 0.05)
		dancer.modulate.a = 0.0
		dancer.play("dance")
		var target_scale := float(entry["target_scale"])
		tween.tween_property(dancer, "scale", Vector2(target_scale, target_scale), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(dancer, "modulate:a", 1.0, 0.18)

func _hide_fever_dancers() -> void:
	for entry in fever_dancers:
		var dancer: AnimatedSprite2D = entry.get("sprite", null)
		if dancer != null and is_instance_valid(dancer):
			dancer.stop()
			dancer.visible = false
	for entry in _fever_dance_3d:
		var node: Node3D = entry.get("node", null)
		var ap: AnimationPlayer = entry.get("anim", null)
		if node != null and is_instance_valid(node):
			node.visible = false
		if ap != null and is_instance_valid(ap):
			ap.stop()

func _party_physical_attack(active_char: CharacterData, sword_count: int, combo_mult: float) -> void:
	# 互換用: 攻撃フェーズ本体は _party_attack_phase。
	var result := {"score": [0, sword_count, 0, 0, 0, 0], "combo": 1, "element_hits": {}}
	await _party_attack_phase(result, combo_mult)

func _use_skill_pieces(active_char: CharacterData, skill_count: int, element_hits: Dictionary, combo_mult: float) -> void:
	if skill_count <= 0:
		return
	var hit_element: int = active_char.element
	if not element_hits.is_empty():
		hit_element = int(element_hits.keys()[0])
	await _trigger_element_skill(active_char, skill_count, combo_mult, hit_element)

# キャラ属性に対応するスキル攻撃。
# 直接ダメージに加えて、属性ごとの状態異常・支援効果を敵全体へ付与する。
func _trigger_element_skill(active_char: CharacterData, count: float, combo_mult: float, element: int) -> void:
	await _trigger_element_skill_for(active_char, party.find(active_char), count, combo_mult, element)

func _trigger_element_skill_for(active_char: CharacterData, char_index: int, count: float, combo_mult: float, element: int) -> void:
	if count <= 0.0:
		return
	var actor: Node3D = _ally_for_index(char_index)
	if actor:
		_show_action_focus(actor, "%sスキル発動" % GameData.element_name(element), GameData.element_color(element))
		await _animate_actor_forward(actor)

	var stacks: int = maxi(1, int(ceil(count)))
	var attack_power := int(actor.attack) if actor else active_char.get_attack()
	var base := int((count * (10.0 + attack_power * 0.35)) * active_char.get_skill_power() * combo_mult * shop_attack_mult)
	var targets := _living_enemies()
	for target in targets:
		if is_instance_valid(target):
			_damage_enemy(target, max(1, base), element, active_char)

	match element:
		GameData.Element.POISON:
			for target in targets:
				if not is_instance_valid(target) or target.hp <= 0:
					continue
				var status := _get_enemy_status(target)
				status["poison"] = int(status["poison"]) + stacks
				status["poison_turns"] = 99
			_log("%sスキル：敵全体を毒状態にした（属性値 %.1f / パーティ%d）" % [
				GameData.element_name(element), count, party.size()
			])
		GameData.Element.FIRE:
			for target in targets:
				if not is_instance_valid(target) or target.hp <= 0:
					continue
				var status := _get_enemy_status(target)
				status["burn"] = int(status["burn"]) + stacks * (4 + active_char.level)
				status["burn_turns"] = maxi(int(status["burn_turns"]), 2)
			_log("%sスキル：敵全体を燃焼状態にした" % GameData.element_name(element))
		GameData.Element.ICE:
			for target in targets:
				if not is_instance_valid(target) or target.hp <= 0:
					continue
				var status := _get_enemy_status(target)
				status["freeze"] = maxi(int(status["freeze"]), 1)
			_log("%sスキル：敵全体を凍結させた" % GameData.element_name(element))
		GameData.Element.THUNDER:
			for target in targets:
				if not is_instance_valid(target) or target.hp <= 0:
					continue
				if randf() < 0.45:
					var status := _get_enemy_status(target)
					status["stun"] = maxi(int(status["stun"]), 1)
			_log("%sスキル：敵全体に感電を付与した" % GameData.element_name(element))
		GameData.Element.WATER, GameData.Element.WOOD:
			var heal_bonus := 1.0 + float(party_relic_mods.get("heal_bonus", 0.0)) + float(active_char.get_character_modifiers().get("heal_bonus", 0.0))
			var heal := int(count * (8 + active_char.level * 3) * combo_mult * shop_heal_mult * heal_bonus)
			for ally in _living_allies():
				ally.receive_heal(heal)
				_sync_ally_to_party(ally)
			_log("%sスキル：味方全員を %d 回復" % [GameData.element_name(element), heal])
		GameData.Element.LIGHT:
			var heal_bonus := 1.0 + float(party_relic_mods.get("heal_bonus", 0.0)) + float(active_char.get_character_modifiers().get("heal_bonus", 0.0))
			var heal := int(count * (10 + active_char.level * 3) * combo_mult * shop_heal_mult * heal_bonus)
			for ally in _living_allies():
				ally.receive_heal(heal)
				_sync_ally_to_party(ally)
			for target in targets:
				if is_instance_valid(target):
					var status := _get_enemy_status(target)
					status["poison"] = 0
					status["burn"] = 0
			_log("%sスキル：味方を回復し、敵全体の状態異常を浄化" % GameData.element_name(element))
		GameData.Element.DARK:
			var heal_bonus := 1.0 + float(party_relic_mods.get("heal_bonus", 0.0)) + float(active_char.get_character_modifiers().get("heal_bonus", 0.0))
			var heal := int(base * 0.35 * shop_heal_mult * heal_bonus)
			if actor and is_instance_valid(actor):
				actor.receive_heal(heal)
				_sync_ally_to_party(actor)
			_log("%sスキル：敵全体から与えたダメージの一部を吸収" % GameData.element_name(element))
		GameData.Element.EARTH:
			var shield_bonus := 1.0 + float(party_relic_mods.get("shield_bonus", 0.0)) + float(active_char.get_character_modifiers().get("shield_bonus", 0.0))
			var shield_gain := int(count * (24 + active_char.level * 5) * combo_mult * shop_shield_mult * shield_bonus)
			party_shield += shield_gain
			_log("%sスキル：シールド +%d" % [GameData.element_name(element), shield_gain])
		GameData.Element.WIND:
			var shield_bonus := 1.0 + float(party_relic_mods.get("shield_bonus", 0.0)) + float(active_char.get_character_modifiers().get("shield_bonus", 0.0))
			var shield_gain := int(count * (14 + active_char.level * 3) * combo_mult * shop_shield_mult * shield_bonus)
			party_shield += shield_gain
			_log("%sスキル：風の護りでシールド +%d" % [GameData.element_name(element), shield_gain])
		_:
			pass

	_update_enemy_intents()
	await get_tree().create_timer(0.15).timeout
	if actor and is_instance_valid(actor):
		await _return_actor(actor, char_index, true)

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
	if source:
		element_bonus += float(source.get_character_modifiers().get("element_bonus", 0.0))
	var damage := int(raw * multiplier * (1.0 + element_bonus))
	var crit := false
	var crit_chance := float(party_relic_mods.get("crit_chance", 0.0))
	if source:
		crit_chance += source.get_crit_chance()
	if randf() < crit_chance:
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
	if is_final_boss:
		_play_ending_bgm()
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
	battle_lost = true
	puzzle_board.canmove = false
	resolving = true
	var bgm := _bgm_manager()
	if bgm and bgm.has_method("stop_all"):
		bgm.stop_all()
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
	_hide_fever_dancers()
	if fever_title_label and is_instance_valid(fever_title_label):
		fever_title_label.visible = false
	if battle_lost:
		var bgm := _bgm_manager()
		if bgm and bgm.has_method("stop_all"):
			bgm.stop_all()
	elif is_final_boss:
		_play_ending_bgm()
	else:
		_play_field_bgm()
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
	var any_skill_unlocked := false
	for c in party:
		if c != null and (c.get_node_level("offense_1") > 0 or c.get_skill_power() > 1.0):
			any_skill_unlocked = true
			break
	puzzle_board.set_party_skills(party)
	puzzle_board.configure(active_char.element, active_char.level, any_skill_unlocked, active_char.get_skill_attribute(), party)
	if board_element_label:
		if puzzle_board.allow_skill_pieces:
			var piece_elements: Array = []
			for element in puzzle_board.party_skill_elements:
				piece_elements.append(GameData.element_name(int(element)))
			board_element_label.text = "操作属性: %s  /  出現スキル駒: %s" % [
				active_char.get_element_name(), " / ".join(PackedStringArray(piece_elements))
			]
		else:
			board_element_label.text = "操作属性: %s  /  スキル駒: 未解禁" % active_char.get_element_name()
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
	coin_label.text = "コイン: %d　ポーション: %d" % [
		(main_ref.money if main_ref else 0) + battle_coin,
		(main_ref.potions if main_ref and "potions" in main_ref else 0)
	]
	for element in element_value_labels.keys():
		var label: Label = element_value_labels[element]
		if label and is_instance_valid(label):
			label.text = "%s %d" % [GameData.element_name(int(element)), int(turn_element_values.get(element, 0))]
	var living_enemy_count := _living_enemies().size()
	enemy_count_label.text = "敵: %d　シールド: %d" % [living_enemy_count, int(party_shield)]
	if active_index < party.size():
		var active_char: CharacterData = party[active_index]
		var active_values: Array = []
		for raw_element in active_char.get_elements():
			var element_value := int(raw_element)
			active_values.append("%s %d" % [GameData.element_name(element_value), int(turn_element_values.get(element_value, 0))])
		active_label.text = "操作中: %s  [%s]  %s / パーティ%d" % [
			_display_name(active_char.id), active_char.get_element_names(),
			" / ".join(PackedStringArray(active_values)), maxi(1, party.size())
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
		var element_parts: Array = []
		var max_share := 0.0
		for raw_element in c.get_elements():
			var element_value := int(raw_element)
			var value := int(turn_element_values.get(element_value, 0))
			var share := float(value) / float(maxi(1, party.size()))
			max_share = maxf(max_share, share)
			element_parts.append("%s %d/%d=%.1f" % [
				GameData.element_name(element_value), value, maxi(1, party.size()), share
			])
		card["ult_label"].text = "%s%s" % [
			"  ".join(PackedStringArray(element_parts)),
			"  発動" if max_share > 0.0 else ""
		]
		card["ult_label"].add_theme_color_override("font_color", c.get_element_color())
		card["ult_bar"].value = clampi(int(max_share * 100.0), 0, 100)
		var gauge_fill := StyleBoxFlat.new()
		gauge_fill.bg_color = c.get_element_color() if max_share <= 0.0 else Color(1.0, 0.88, 0.32)
		gauge_fill.set_corner_radius_all(4)
		card["ult_bar"].add_theme_stylebox_override("fill", gauge_fill)
		card["button"].disabled = (ally == null or i == active_index)
	if skill_help_label:
		skill_help_label.text = "パーティ全員のスキル属性駒が4マッチで出現\n消した属性値 / パーティ%d が0超で全員分の属性スキル発動" % maxi(1, party.size())
	if fever_bar and fever_label:
		if fever_turns > 0:
			fever_label.text = "★ FEVER TIME ★ 残り%d手" % fever_turns
			fever_bar.value = clampi(int(float(fever_turns) / 5.0 * 100.0), 0, 100)
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

func _show_action_focus(actor: Node3D, action_text: String, color: Color) -> void:
	if not is_instance_valid(actor):
		return
	var character_name := _display_name(actor.character_name if "character_name" in actor else "?")
	# 3D: 頭上に行動名を出し、足元に属性色のリングと補助光を追加する。
	var action_label := Label3D.new()
	action_label.text = action_text
	action_label.font_size = 42
	action_label.modulate = color.lightened(0.25)
	action_label.outline_size = 10
	action_label.outline_modulate = Color(0, 0, 0, 0.95)
	action_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	action_label.pixel_size = 0.0045
	action_label.position = Vector3(0, 3.3, 0)
	actor.add_child(action_label)

	var focus_light := OmniLight3D.new()
	focus_light.light_color = color
	focus_light.light_energy = 2.2
	focus_light.omni_range = 6.0
	focus_light.shadow_enabled = false
	focus_light.position = Vector3(0, 1.8, 0)
	actor.add_child(focus_light)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 1.15
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	ring.position = Vector3(0, 0.08, 0)
	ring.rotation_degrees = Vector3(90, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	actor.add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(action_label, "position:y", 4.4, 0.95)
	tween.tween_property(action_label, "modulate:a", 0.0, 0.95)
	tween.tween_property(focus_light, "light_energy", 0.0, 0.75)
	tween.tween_property(ring, "scale", Vector3(1.9, 1.0, 1.9), 0.55)
	tween.tween_property(ring, "transparency", 1.0, 0.55)
	tween.finished.connect(func():
		if is_instance_valid(action_label):
			action_label.queue_free()
		if is_instance_valid(focus_light):
			focus_light.queue_free()
		if is_instance_valid(ring):
			ring.queue_free()
	)

	# HUD 下中央にも「誰が何をするか」を表示する。
	if battle_action_label:
		battle_action_label.text = "%s：%s" % [character_name, action_text]
		battle_action_label.modulate.a = 1.0
		var hud_tween := create_tween()
		hud_tween.tween_interval(0.55)
		hud_tween.tween_property(battle_action_label, "modulate:a", 0.0, 0.45)

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
