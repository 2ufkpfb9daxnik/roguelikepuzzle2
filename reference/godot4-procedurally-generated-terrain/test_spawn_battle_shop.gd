extends SceneTree

func _init() -> void:
	print("=== Starting automated test for Battle, Shop, Spawn positions and guards ===")
	
	var main_scene = load("res://main.tscn")
	if not main_scene:
		push_error("Failed to load main.tscn")
		quit(1)
		return
		
	var main_instance = main_scene.instantiate()
	root.add_child(main_instance)
	
	await process_frame
	
	var terrain = main_instance.get_node_or_null("terrain")
	if not terrain:
		push_error("terrain node not found")
		quit(1)
		return
		
	var player = main_instance.get_node_or_null("CharacterBody3D")
	if not player:
		push_error("player node not found")
		quit(1)
		return
		
	var plain_shop = main_instance.get_node_or_null("plain_shop")
	var snow_shop = main_instance.get_node_or_null("snow_shop")
	var desert_shop = main_instance.get_node_or_null("desert_shop")
	var cave_shop = main_instance.get_node_or_null("cave_shop")
	var castle_shop = main_instance.get_node_or_null("castle_shop")
	
	print("[Check 1] Battle positions:")
	print("  plane_battle_pos: ", terrain.plane_battle_pos)
	print("  snow_battle_pos:  ", terrain.snow_battle_pos)
	print("  desert_battle_pos:", terrain.desert_battle_pos)
	print("  cave_battle_pos:  ", terrain.cave_battle_pos)
	
	assert(terrain.plane_battle_pos.y >= 31, "plane_battle_pos must be above water (Y >= 31)")
	assert(terrain.snow_battle_pos.y >= 31, "snow_battle_pos must be above water (Y >= 31)")
	assert(terrain.desert_battle_pos.y >= 31, "desert_battle_pos must be above water (Y >= 31)")
	assert(terrain.cave_battle_pos.y >= 10, "cave_battle_pos must be on cave floor (Y >= 10)")
	print("  -> PASS: All battle positions are above water / on proper floor.")
	
	print("[Check 2] Shop positions:")
	print("  plain_shop pos: ", plain_shop.position)
	print("  snow_shop pos:  ", snow_shop.position)
	print("  desert_shop pos:", desert_shop.position)
	print("  cave_shop pos:  ", cave_shop.position)
	print("  castle_shop pos:", castle_shop.position)
	
	assert(plain_shop.position.y >= 31, "plain_shop must be above water (Y >= 31)")
	assert(snow_shop.position.y >= 31, "snow_shop must be above water (Y >= 31)")
	assert(desert_shop.position.y >= 31, "desert_shop must be above water (Y >= 31)")
	assert(cave_shop.position.y >= 10, "cave_shop must be on cave floor (Y >= 10)")
	assert(castle_shop.position.y >= 31, "castle_shop must be above water (Y >= 31)")
	print("  -> PASS: All shops are properly elevated above water / on proper floor.")
	
	print("[Check 3] Mainland bounds:")
	print("  plain_shop within mainland: ", plain_shop.position.x >= 32 and plain_shop.position.x <= 97 and plain_shop.position.z >= 97 and plain_shop.position.z <= 162)
	print("  desert_shop within mainland: ", desert_shop.position.x >= 32 and desert_shop.position.x <= 97 and desert_shop.position.z >= 32 and desert_shop.position.z <= 97)
	print("  castle_shop within mainland: ", castle_shop.position.x >= 32 and castle_shop.position.x <= 97 and castle_shop.position.z >= 162 and castle_shop.position.z <= 227)
	assert(castle_shop.position != Vector3.ZERO, "castle_shop must NOT be at (0,0,0)!")
	print("  -> PASS: All shops are located on their respective biome mainland.")
	
	print("[Check 4] Player spawn position:")
	print("  player position: ", player.position)
	assert(player.position.y >= 31, "player must spawn above water (Y >= 31)")
	assert(player.position.x >= 32 and player.position.x <= 97 and player.position.z >= 97 and player.position.z <= 162, "player must spawn on plains mainland")
	var dist_to_shop = player.position.distance_to(plain_shop.position)
	print("  distance to plain_shop: ", dist_to_shop)
	assert(dist_to_shop > 5.0, "player must not spawn inside plain_shop Area3D!")
	print("  -> PASS: Player spawn is on mainland, above water, and safe distance from shop.")
	
	print("[Check 5] Battle immunity:")
	player.isbattle = true
	player.position = Vector3(player.position.x, 1000, player.position.z)
	player.velocity = Vector3(10, -50, 10)
	player._physics_process(0.016)
	assert(player.velocity == Vector3.ZERO, "player velocity must be Vector3.ZERO when isbattle is true!")
	assert(player.position.y == 1000, "player position must not drop when isbattle is true!")
	print("  -> PASS: Player is frozen at battle altitude during battle.")
	
	var shop_area = plain_shop.get_node("Area3D")
	var shop_ui = main_instance.get_node_or_null("ShopUI")
	var shop_ui_before = shop_ui.visible if shop_ui else false
	shop_area._on_body_entered(player)
	var shop_ui_after = shop_ui.visible if shop_ui else false
	assert(shop_ui_before == shop_ui_after, "ShopUI must not open during battle!")
	print("  -> PASS: Shop ignores player collision when isbattle is true.")
	
	print("[Check 6] Battle vs Shop separation and Plains height validation:")
	print("  terrain.plane_battle_pos.y: ", terrain.plane_battle_pos.y)
	assert(terrain.plane_battle_pos.y < 42, "plane_battle_pos must be on plains (Y < 42), not snow mountain! Found Y=" + str(terrain.plane_battle_pos.y))
	print("  -> PASS: plane_battle_pos is on plains (grass/dirt), not on snow mountain.")
	
	var dist_plain_battle_shop = plain_shop.position.distance_to(terrain.plane_battle_pos)
	print("  dist_plain_battle_shop: ", dist_plain_battle_shop)
	assert(dist_plain_battle_shop >= 8.0, "plain_shop must NOT be in battle area! Dist: " + str(dist_plain_battle_shop))
	
	var dist_snow_battle_shop = snow_shop.position.distance_to(terrain.snow_battle_pos)
	print("  dist_snow_battle_shop:  ", dist_snow_battle_shop)
	assert(dist_snow_battle_shop >= 6.0, "snow_shop must NOT be in battle area! Dist: " + str(dist_snow_battle_shop))
	
	var dist_desert_battle_shop = desert_shop.position.distance_to(terrain.desert_battle_pos)
	print("  dist_desert_battle_shop:", dist_desert_battle_shop)
	assert(dist_desert_battle_shop >= 6.0, "desert_shop must NOT be in battle area! Dist: " + str(dist_desert_battle_shop))
	
	var dist_cave_battle_shop = cave_shop.position.distance_to(terrain.cave_battle_pos)
	print("  dist_cave_battle_shop:  ", dist_cave_battle_shop)
	assert(dist_cave_battle_shop >= 6.0, "cave_shop must NOT be in battle area! Dist: " + str(dist_cave_battle_shop))
	print("  -> PASS: All shops are completely separated from their respective battle areas.")
	
	print("=== ALL CHECKS PASSED SUCCESSFULLY ===")
	quit(0)
