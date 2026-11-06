extends SceneTree

func _init() -> void:
	print("=== new system smoke test ===")
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
	assert(first.element > 0)

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
	assert(second != null and third != null)
	assert(fourth == null)
	assert(main_instance.party.size() == 3)
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
	assert(shop.tabs.get_tab_count() == 3)
	var money_before: int = main_instance.money
	var level_before: int = first.level
	shop._on_levelup(0)
	await process_frame
	print("levelup: money ", money_before, "->", main_instance.money, " lv ", level_before, "->", first.level)
	assert(main_instance.money < money_before)
	assert(first.level > level_before)
	shop.selected_char_index = 0
	first.skill_points = 8
	shop._on_unlock_node("guard_1")
	await process_frame
	print("guard_1 level: ", first.get_node_level("guard_1"), " max hp: ", first.get_max_health())
	assert(first.get_node_level("guard_1") == 1)
	shop._on_close_button_pressed()
	await process_frame
	assert(not shop.visible)

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
	battle.start_battle()
	await create_timer(1.2).timeout
	print("battle state: finished=", battle.battle_finished, " turn=", battle.turn_number, " canmove=", battle.puzzle_board.canmove)
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
	if is_instance_valid(battle):
		battle.queue_free()
	await create_timer(1.0).timeout
	main_instance.queue_free()
	await process_frame
	print("=== ALL SMOKE CHECKS PASSED ===")
	quit(0)
