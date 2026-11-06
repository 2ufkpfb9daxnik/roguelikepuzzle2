extends SceneTree

func _init() -> void:
	print("=== new system smoke test ===")
	var bgm_manager = root.get_node_or_null("BGMManager")
	if bgm_manager == null:
		# --script 実行では Autoload が生成されないため、直接テスト用に生成する。
		bgm_manager = Node.new()
		bgm_manager.name = "BGMManagerTest"
		bgm_manager.set_script(load("res://bgm_manager.gd"))
		root.add_child(bgm_manager)
		await process_frame
	assert(bgm_manager != null)
	assert(bgm_manager.players.size() == 7)
	print("BGM tracks: ", bgm_manager.players.size())
	var main_scene := load("res://main.tscn")
	if main_scene == null:
		push_error("main.tscn load failed")
		quit(1)
		return
	var main_instance = main_scene.instantiate()
	root.add_child(main_instance)
	await process_frame
	await process_frame

	print("party size: ", main_instance.party.size())
	assert(main_instance.party.size() == 1)
	var first: CharacterData = main_instance.party[0]
	print("first: ", first.id, " element=", first.get_element_name(), " lv=", first.level)
	assert(first.id == "businessman")
	assert(first.element > 0)
	assert(first.get_elements().size() >= 1)

	first.add_exp(200)
	print("after exp: lv=", first.level, " sp=", first.skill_points)
	assert(first.level >= 2)

	first.skill_points = 10
	var unlocked := first.unlock_skill_node("offense_1")
	print("unlock offense_1: ", unlocked)
	assert(unlocked)
	print("attack=", first.get_attack())

	var second = main_instance.add_character_by_id("fantasy_wolf")
	var third = main_instance.add_character_by_id("bee")
	var fourth = main_instance.add_character_by_id("skeleton")
	var fifth = main_instance.add_character_by_id("spider")
	assert(second != null and third != null and fourth != null)
	assert(fifth != null)
	assert(main_instance.party.size() == 5)
	assert(main_instance.get_battle_party().size() == 3)
	var roster: Array = main_instance.get_roster()
	assert(roster.size() == 4)
	assert(main_instance.toggle_battle_member(roster[0].id))
	assert(main_instance.toggle_battle_member(roster[3].id))
	assert(main_instance.get_battle_party().size() == 3)
	assert(main_instance.is_battle_member(roster[3].id))
	print("party elements: ", first.get_element_name(), ", ", second.get_element_name(), ", ", third.get_element_name())

	var shop = main_instance.get_node_or_null("ShopUi")
	# 盤面の実スワップ / マッチ / 連鎖処理も検証する。
	var board_control := Control.new()
	board_control.set_script(load("res://puzzle_board.gd"))
	root.add_child(board_control)
	await process_frame
	await process_frame
	board_control.configure(GameData.Element.WATER, 3)
	assert(board_control.board.size() == 13)
	assert(board_control.board[0].size() == 13)
	var resolved := {"done": false, "combo": 0}
	board_control.turn_resolved.connect(func(result):
		resolved["done"] = true
		resolved["combo"] = int(result.get("combo", 0))
	)
	board_control.board[0] = [0, 1, 0, 0, 2, 3, 4, 0, 1, 2, 3, 4, 0]
	board_control.canmove = true
	board_control._try_swap(Vector2i(0, 0), Vector2i(1, 0))
	await create_timer(2.5).timeout
	print("board turn resolved: ", resolved["done"], " combo=", resolved["combo"])
	assert(resolved["done"])
	assert(int(resolved["combo"]) >= 1)
	board_control.queue_free()
	await process_frame
	assert(shop != null)
	shop.open_shop()
	await process_frame
	print("shop visible: ", shop.visible, " tabs=", shop.tabs.get_tab_count())
	assert(shop.visible)
	assert(shop.tabs.get_tab_count() == 4)
	var money_before: int = main_instance.money
	var level_before: int = first.level
	shop._on_levelup(0)
	await process_frame
	print("levelup: money ", money_before, "->", main_instance.money, " lv ", level_before, "->", first.level)
	assert(main_instance.money < money_before)
	assert(first.level > level_before)
	# コインでショップバフを購入できることを確認。
	var money_before_buff: int = main_instance.money
	shop._on_buy_buff("attack")
	await process_frame
	print("shop buff attack: lv=", main_instance.get_shop_buff_level("attack"), " money ", money_before_buff, "->", main_instance.money)
	assert(main_instance.get_shop_buff_level("attack") == 1)
	assert(main_instance.money < money_before_buff)
	shop.selected_char_index = 0
	main_instance.potions = 10000
	var potions_before_unlock: int = main_instance.potions
	shop._on_unlock_node("guard_1")
	await process_frame
	var roster_first: CharacterData = main_instance.get_roster()[0] if not main_instance.get_roster().is_empty() else null
	print("guard_1 level: ", roster_first.get_node_level("guard_1") if roster_first else -1, " potions: ", potions_before_unlock, "->", main_instance.potions, " max hp: ", roster_first.get_max_health() if roster_first else 0)
	assert(roster_first != null and roster_first.get_node_level("guard_1") == 1)
	assert(main_instance.potions < potions_before_unlock)
	# 各ショップはそのバイオームに出現するキャラだけを販売する。
	var shop_spawner = main_instance.get_node("spawn_enemy")
	shop.open_shop(0)
	await process_frame
	var stock_ok := true
	for id in shop.recruit_stock:
		if not shop_spawner.stage_enemy[0].has(id):
			stock_ok = false
	print("shop stage stock (plains): ", shop.recruit_stock.size(), " ids=", shop.recruit_stock)
	assert(stock_ok)
	shop._on_close_button_pressed()
	await process_frame
	shop._on_close_button_pressed()
	await process_frame
	print("shop closed: ", not shop.visible)
	if shop.visible:
		shop._on_close_button_pressed()
		await process_frame

	var battle = load("res://battle_scene.tscn").instantiate()
	main_instance.add_child(battle)
	await process_frame
	var enemy_stub := Enemy.new()
	enemy_stub.enemy_name = "fantasy_wolf"
	battle.set_battle_info(0, "fantasy_wolf")
	var spawner = main_instance.get_node("spawn_enemy")
	battle.enemy_data = spawner.enemy_data
	battle.stage_enemy = spawner.stage_enemy
	var player = main_instance.get_node("CharacterBody3D")
	await battle.prepare_battle(player, enemy_stub, [], main_instance.generate_allies_to_spawn())
	await process_frame
	print("spawned allies: ", battle.spawned_allies.size(), " enemies: ", battle.spawned_enemies.size())
	assert(battle.spawned_allies.size() == 3)
	assert(battle.spawned_enemies.size() >= 1)
	var avatar = battle.allies_root.get_node_or_null("PlayerAvatar_Businessman")
	assert(avatar != null)
	print("businessman avatar procedural=", avatar.procedural_animation_enabled, " idle=", avatar.battle_idle_anim)
	assert(avatar.procedural_animation_enabled)
	assert(avatar.battle_idle_anim == "procedural_idle")
	battle.start_battle()
	await create_timer(1.2).timeout
	print("battle state: finished=", battle.battle_finished, " turn=", battle.turn_number, " canmove=", battle.puzzle_board.canmove)

	# パーティ構成に応じて4マッチで生まれるスキル駒が変わることを確認。
	var board = battle.puzzle_board
	var party_elements: Array = []
	for c in battle.party:
		for raw_element in c.get_elements():
			if not party_elements.has(int(raw_element)):
				party_elements.append(int(raw_element))
	assert(not board.party_skill_map.is_empty())
	for c in battle.party:
		var attribute: int = c.get_skill_attribute()
		assert(board.party_skill_map.has(attribute))
		for raw_element in c.get_elements():
			assert(board.party_skill_map[attribute].has(int(raw_element)))
	for c in range(4):
		board.board[0][c] = GameData.Piece.SWORD
	var matched_cells: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	var special: Dictionary = board._select_special_spawn(matched_cells)
	assert(not special.is_empty())
	var spawned_element: int = int(special.get("element", 0))
	assert(party_elements.has(spawned_element))
	print("party skill spawn: base=", special.get("base"), " element=", GameData.element_name(spawned_element))

	# スキル駒を消すと属性値へ加算されることを確認。
	board.element_hits.clear()
	board._accumulate_score(int(special["piece_id"]))
	assert(int(board.element_hits.get(spawned_element, 0)) == 1)

	# 攻撃フェーズ: 属性値 / パーティ人数 > 0 のキャラが敵全体へスキルを発動。
	for e in battle.spawned_enemies:
		if is_instance_valid(e):
			e.max_health = 99999
			e.hp = 99999
	battle.party[0].element = GameData.Element.POISON
	battle._refresh_active_character()
	battle.turn_element_values = {GameData.Element.POISON: 3}
	var before_skill_hp := 0
	for e in battle.spawned_enemies:
		if is_instance_valid(e):
			before_skill_hp += e.hp
	await battle._party_attack_phase({"score": [0, 0, 0, 0, 0, 0]}, 1.0)
	var after_skill_hp := 0
	var poisoned_count := 0
	for e in battle.spawned_enemies:
		if is_instance_valid(e):
			after_skill_hp += e.hp
			if int(battle._get_enemy_status(e).get("poison", 0)) > 0:
				poisoned_count += 1
	print("element skill: hp ", before_skill_hp, "->", after_skill_hp, " poisoned=", poisoned_count)
	assert(after_skill_hp < before_skill_hp)
	assert(poisoned_count >= 1)

	# 各キャラの攻撃値 = そのターンの剣の値 × キャラの攻撃力。
	battle.turn_element_values = {}
	var before_attack_hp := 0
	for e in battle.spawned_enemies:
		if is_instance_valid(e):
			before_attack_hp += e.hp
	await battle._party_attack_phase({"score": [0, 2, 0, 0, 0, 0]}, 1.0)
	var after_attack_hp := 0
	for e in battle.spawned_enemies:
		if is_instance_valid(e):
			after_attack_hp += e.hp
	print("party physical: hp ", before_attack_hp, "->", after_attack_hp)
	assert(after_attack_hp < before_attack_hp)
	battle.turn_element_values.clear()

	var before_hp := 0
	for e in battle.spawned_enemies:
		if is_instance_valid(e):
			before_hp += e.hp
	battle.party[0].element = GameData.Element.POISON
	battle._refresh_active_character()
	battle.puzzle_board.board[0][0] = GameData.piece_id_for_element(GameData.Element.POISON)
	battle._on_turn_resolved({"score": [2, 0, 0, 0, 0, 0], "combo": 1, "element_hits": {}, "active_element": GameData.Element.POISON})
	await create_timer(5.0).timeout
	if is_instance_valid(battle) and not battle.battle_finished:
		battle.party[0].ult_charge = 100
		battle._on_skill_pressed()
		await create_timer(4.0).timeout
		print("ultimate turn check: finished=", battle.battle_finished, " turn=", battle.turn_number)
		var fever_frames = battle._get_fever_dance_frames()
		assert(fever_frames != null and fever_frames.get_frame_count("dance") > 0)
		await battle._activate_fever()
		await process_frame
		print("fever: turns=", battle.fever_turns, " 2d_dancers=", battle.fever_dancers.size(), " 3d_dancers=", battle._fever_dance_3d.size(), " frames=", fever_frames.get_frame_count("dance"))
		assert(battle.fever_turns == 5)
		assert(battle.fever_dancers.size() >= 1 or battle._fever_dance_3d.size() >= 1)
		battle._hide_fever_dancers()
	if is_instance_valid(battle):
		battle.queue_free()
	await create_timer(1.0).timeout
	main_instance.queue_free()
	await process_frame
	print("=== ALL SMOKE CHECKS PASSED ===")
	quit(0)
