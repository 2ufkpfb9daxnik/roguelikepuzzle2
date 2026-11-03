extends SceneTree

func _init() -> void:
	print("=== Running Comprehensive Verification Test for Castle & POI System ===")
	
	var main_scene = load("res://main.tscn")
	if not main_scene:
		push_error("Failed to load main.tscn")
		quit(1)
		return
		
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	current_scene = main_node
	
	var terrain_node = main_node.get_node_or_null("terrain")
	if not terrain_node:
		push_error("Failed to find terrain node")
		quit(1)
		return

	# Wait for async generation to finish
	print("Waiting for terrain generation to complete...")
	var timeout = 30.0
	var timer = 0.0
	while terrain_node.is_generating:
		await process_frame
		timer += 0.016
		if timer > timeout:
			push_error("Timeout waiting for terrain generation")
			quit(1)
			return

	print("Terrain generation finished! Running verifications...")
	var initial_player_pos = main_node.player_node.position

	print("\n--- Check 0: Player Initial Spawn Physics & Movement Simulation ---")
	var p = main_node.player_node
	var start_test_pos = p.global_position
	for f in range(40):
		if f >= 5:
			Input.action_press("w")
		await physics_frame
		await process_frame
		if f < 10 or f % 10 == 0:
			var px = int(p.global_position.x / terrain_node.rh)
			var pz = int(p.global_position.z / terrain_node.rw)
			var c_st = terrain_node.chunk_state[px][pz]
			var col_st = terrain_node.chunk_col_state[px][pz]
			print("  Frame %d: pos=%s, proc_mode=%d, mov_en=%s, on_floor=%s, chunk=(%d,%d)[m=%d,c=%d]" % [
				f, p.global_position, p.process_mode, p.movement_enabled, p.is_on_floor(), px, pz, c_st, col_st
			])
	Input.action_release("w")
	var moved_dist = Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(start_test_pos.x, start_test_pos.z))
	print("  Horizontal distance moved on 'w' press: %.2fm" % moved_dist)
	assert(moved_dist > 2.0, "Player must be able to move freely from initial position! Moved: %.2fm" % moved_dist)
	p.global_position = initial_player_pos
	p.velocity = Vector3.ZERO

	# --- Check 1: Castle Map Textures ---
	print("\n--- Check 1: Castle Map Textures ---")
	assert(terrain_node.castle_map_textures.size() == 3, "castle_map_textures must contain 3 textures (1F, 2F, 3F)")
	for i in range(3):
		var tex = terrain_node.castle_map_textures[i]
		assert(tex != null, "Texture for floor %d must not be null" % (i + 1))
		var img = tex.get_image()
		assert(img.get_width() == terrain_node.worldh, "Texture width must equal worldh")
		assert(img.get_height() == terrain_node.worldw, "Texture height must equal worldw")
		print("  Floor %dF texture OK: %dx%d" % [i + 1, img.get_width(), img.get_height()])
	print("-> PASS: Castle map textures created successfully.")

	# --- Check 2: Castle Floor & Entrance Matching ---
	print("\n--- Check 2: Castle Floor and Stair Matching ---")
	var base_y = int(floor(terrain_node.baseheightma / 0.1))
	var sth = terrain_node.castle_sth
	var stw = terrain_node.castle_stw
	var door_center_x = sth + 10 + int((terrain_node.castle_height_length - 19 - 4) / 2) + 2
	var center_x = sth + int(terrain_node.castle_height_length / 2)
	var center_z = stw + int(terrain_node.castle_width_length / 2)
	print("  Castle coordinates: sth=%d, stw=%d, base_y=%d, door_center_x=%d" % [sth, stw, base_y, door_center_x])

	# Check entrance stairway voxels at door_center_x:
	# Outside plateau floor (stw - 1)
	var plateau_voxel = terrain_node._map3dnum_flat[base_y * terrain_node.worldh * terrain_node.worldw + door_center_x * terrain_node.worldw + (stw - 1)]
	print("  Plateau ground voxel at door center (stw-1): %d" % plateau_voxel)
	assert(plateau_voxel == 2, "Plateau in front of stairs must be solid stone (2)")

	# Top landing (stw + 6)
	var terrace_voxel = terrain_node._map3dnum_flat[(base_y + 3) * terrain_node.worldh * terrain_node.worldw + door_center_x * terrain_node.worldw + (stw + 6)]
	print("  Terrace landing floor at door center (stw+6): %d" % terrace_voxel)
	assert(terrace_voxel == 5, "Terrace landing must be castle stone (5)")

	# Gateway passage (stw + 8)
	var doorway_floor = terrain_node._map3dnum_flat[(base_y + 3) * terrain_node.worldh * terrain_node.worldw + door_center_x * terrain_node.worldw + (stw + 8)]
	var doorway_air = terrain_node._map3dnum_flat[(base_y + 4) * terrain_node.worldh * terrain_node.worldw + door_center_x * terrain_node.worldw + (stw + 8)]
	print("  Doorway floor (stw+8, base_y+3): %d, doorway air (stw+8, base_y+4): %d" % [doorway_floor, doorway_air])
	assert(doorway_floor == 5, "Doorway floor must be 5")
	assert(doorway_air == -1, "Doorway passage must be open air (-1)")

	# Gateway entrance into dungeon (stw + 10)
	var dungeon_entry_air = terrain_node._map3dnum_flat[(base_y + 4) * terrain_node.worldh * terrain_node.worldw + door_center_x * terrain_node.worldw + (stw + 10)]
	print("  Dungeon 1F corridor (stw+10, base_y+4): %d" % dungeon_entry_air)
	assert(dungeon_entry_air == -1, "Dungeon 1F corridor must be open air (-1)")

	# Verify castle_instance terrace alignment with entrance
	assert(terrain_node.castle_instance != null, "castle_instance must be spawned")
	var c_pos = terrain_node.castle_instance.position
	var c_scale = terrain_node.castle_instance.scale
	var model_terrace_y = c_pos.y - 0.393 * c_scale.y
	print("  Castle model terrace Y: %.2f (target: base_y + 3 = %d)" % [model_terrace_y, base_y + 3])
	assert(abs(model_terrace_y - (base_y + 3.0)) < 0.5, "Castle model terrace must be aligned with entrance stairs at base_y + 3!")
	print("-> PASS: Castle model and entrance stairs match perfectly without upward shift!")

	# --- Check 3: Castle Player Query & Floor Detection ---
	print("\n--- Check 3: Castle Player In-Castle and Floor Query ---")
	var outside_pos = Vector3(door_center_x, base_y + 2, stw - 5)
	assert(not terrain_node.is_player_in_castle(outside_pos), "Outside position must not be inside castle")

	var f1_pos = Vector3(center_x, base_y + 4, center_z)
	assert(terrain_node.is_player_in_castle(f1_pos), "1F position must be inside castle")
	assert(terrain_node.get_castle_floor(f1_pos) == 0, "Floor at base_y + 4 must be 1F (0)")

	var f2_pos = Vector3(center_x, base_y + 11, center_z)
	assert(terrain_node.is_player_in_castle(f2_pos), "2F position must be inside castle")
	assert(terrain_node.get_castle_floor(f2_pos) == 1, "Floor at base_y + 11 must be 2F (1)")

	var f3_pos = Vector3(center_x, base_y + 17, center_z)
	assert(terrain_node.is_player_in_castle(f3_pos), "3F position must be inside castle")
	assert(terrain_node.get_castle_floor(f3_pos) == 2, "Floor at base_y + 17 must be 3F (2)")
	print("-> PASS: is_player_in_castle and get_castle_floor work accurately.")

	# --- Check 4: POI Data Registration ---
	print("\n--- Check 4: POI Data Registration ---")
	print("  Total registered POIs: %d" % terrain_node.poi_data.size())
	assert(terrain_node.poi_data.size() >= 12, "Must have at least 12 POIs registered")

	var poi_map = {}
	for poi in terrain_node.poi_data:
		poi_map[poi.id] = poi
		print("  - POI [%s]: '%s' (type: %s, context: %s, symbol: %s, pos: %s)" % [poi.id, poi.name, poi.type, poi.context, poi.symbol, poi.pos])

	# Check all required POIs
	var required_ids = [
		"shop_plane", "shop_cave", "shop_desert", "shop_snow",
		"cave_entrance", "cave_exit", "maze_entrance", "maze_exit",
		"boss_plain", "boss_cave", "boss_desert", "boss_snow", "boss_castle",
		"castle_exit", "stair_1f_up", "stair_2f_down", "stair_2f_up", "stair_3f_down"
	]
	for req_id in required_ids:
		assert(poi_map.has(req_id), "POI '%s' must be present in poi_data" % req_id)
		assert(poi_map[req_id].pos != Vector3.ZERO, "POI '%s' position must not be ZERO" % req_id)
	print("-> PASS: All required POIs (Cave IN/OUT, Maze IN/OUT, 5 Bosses, Shops, Castle Stairs) are registered.")

	# --- Check 5: Minimap Node Integration ---
	print("\n--- Check 5: Minimap Nodes in main.gd ---")
	assert(main_node.castle_texture_rect != null, "castle_texture_rect must exist")
	assert(main_node.poi_container != null, "poi_container must exist")
	assert(main_node.underground_texture_rect != null, "underground_texture_rect must exist")
	assert(main_node.player_marker != null, "player_marker must exist")

	# Test entering castle updates minimap
	main_node.player_node.global_position = f1_pos
	await process_frame
	# Run one main._process step by simulating frame
	main_node._process(0.016)
	assert(main_node.castle_texture_rect.visible == true, "castle_texture_rect must become visible inside castle")
	assert(main_node.castle_texture_rect.texture == terrain_node.castle_map_textures[0], "castle_texture_rect must show 1F texture")
	assert(main_node.underground_texture_rect.visible == false, "underground_texture_rect must be hidden inside castle")

	# Test entering 2F updates texture
	main_node.player_node.global_position = f2_pos
	main_node._process(0.016)
	assert(main_node.castle_texture_rect.texture == terrain_node.castle_map_textures[1], "castle_texture_rect must show 2F texture")

	# Test entering 3F updates texture
	main_node.player_node.global_position = f3_pos
	main_node._process(0.016)
	assert(main_node.castle_texture_rect.texture == terrain_node.castle_map_textures[2], "castle_texture_rect must show 3F texture")

	# Test moving outside hides castle overlay
	main_node.player_node.global_position = outside_pos
	main_node._process(0.016)
	assert(main_node.castle_texture_rect.visible == false, "castle_texture_rect must be hidden outside castle")

	print("-> PASS: Minimap overlay smoothly switches floors and hides appropriately.")

	# --- Check 6: Castle Stairs Step-by-Step Traversal & Clearance ---
	print("\n--- Check 6: Castle Stairs Integrity and Headroom Clearance ---")
	var s0_1f = terrain_node.stair_0_pos_1f
	var s0_2f = terrain_node.stair_0_pos_2f
	print("  1F->2F Stair Start: %s, Arrival: %s" % [s0_1f, s0_2f])
	assert(s0_1f.y == base_y + 4, "1F stair start Y must be base_y + 4")
	assert(s0_2f.y == base_y + 10, "2F stair arrival Y must be base_y + 10")
	
	# Verify headroom along 1F->2F stair line
	var s0_dist = int(max(abs(s0_2f.x - s0_1f.x), abs(s0_2f.z - s0_1f.z)))
	var s0_dx = sign(s0_2f.x - s0_1f.x)
	var s0_dz = sign(s0_2f.z - s0_1f.z)
	for step in range(s0_dist + 1):
		var cur_x = int(s0_1f.x + s0_dx * step)
		var cur_z = int(s0_1f.z + s0_dz * step)
		var step_floor_y = int(base_y + 4 + step)
		var v_step = terrain_node._map3dnum_flat[step_floor_y * terrain_node.worldh * terrain_node.worldw + cur_x * terrain_node.worldw + cur_z]
		var v_head1 = terrain_node._map3dnum_flat[(step_floor_y + 1) * terrain_node.worldh * terrain_node.worldw + cur_x * terrain_node.worldw + cur_z]
		var v_head2 = terrain_node._map3dnum_flat[(step_floor_y + 2) * terrain_node.worldh * terrain_node.worldw + cur_x * terrain_node.worldw + cur_z]
		assert(v_step == 5, "Step %d floor at (%d,%d,%d) must be solid stone (5), got %d" % [step, cur_x, step_floor_y, cur_z, v_step])
		assert(v_head1 == -1, "Step %d headroom at Y=%d must be air (-1), got %d" % [step, step_floor_y + 1, v_head1])
		assert(v_head2 == -1, "Step %d headroom at Y=%d must be air (-1), got %d" % [step, step_floor_y + 2, v_head2])

		# Verify upper ceiling is closed solid stone (5) - NO HOLLOWED-OUT HOLES!
		var v_ceil2f = terrain_node._map3dnum_flat[(base_y + 15) * terrain_node.worldh * terrain_node.worldw + cur_x * terrain_node.worldw + cur_z]
		assert(v_ceil2f == 5, "2F ceiling above 1F->2F stair at (%d,%d) must be solid stone (5), got %d" % [cur_x, cur_z, v_ceil2f])

		# Steps 0 & 1 must keep lower ceiling (base_y + 9) solid
		if step < 2:
			var v_lower_ceil = terrain_node._map3dnum_flat[(base_y + 9) * terrain_node.worldh * terrain_node.worldw + cur_x * terrain_node.worldw + cur_z]
			assert(v_lower_ceil == 5, "1F ceiling above step %d at (%d,%d) must be solid stone (5), got %d" % [step, cur_x, cur_z, v_lower_ceil])
	print("  1F->2F Stair verified: 6-step rise is continuous, headroom is open, and ceiling is 100% solid stone.")

	var s1_2f = terrain_node.stair_1_pos_2f
	var s1_3f = terrain_node.stair_1_pos_3f
	print("  2F->3F Stair Start: %s, Arrival: %s" % [s1_2f, s1_3f])
	assert(s1_2f.y == base_y + 10, "2F stair start Y must be base_y + 10")
	assert(s1_3f.y == base_y + 16, "3F stair arrival Y must be base_y + 16")
	
	var s1_dist = int(max(abs(s1_3f.x - s1_2f.x), abs(s1_3f.z - s1_2f.z)))
	var s1_dx = sign(s1_3f.x - s1_2f.x)
	var s1_dz = sign(s1_3f.z - s1_2f.z)
	for step in range(s1_dist + 1):
		var cur_x = int(s1_2f.x + s1_dx * step)
		var cur_z = int(s1_2f.z + s1_dz * step)
		var step_floor_y = int(base_y + 10 + step)
		var v_step = terrain_node._map3dnum_flat[step_floor_y * terrain_node.worldh * terrain_node.worldw + cur_x * terrain_node.worldw + cur_z]
		var v_head1 = terrain_node._map3dnum_flat[(step_floor_y + 1) * terrain_node.worldh * terrain_node.worldw + cur_x * terrain_node.worldw + cur_z]
		var v_head2 = terrain_node._map3dnum_flat[(step_floor_y + 2) * terrain_node.worldh * terrain_node.worldw + cur_x * terrain_node.worldw + cur_z]
		assert(v_step == 5, "2F->3F Step %d floor must be solid stone (5), got %d" % [step, v_step])
		assert(v_head1 == -1, "2F->3F Step %d headroom at Y=%d must be air (-1), got %d" % [step, step_floor_y + 1, v_head1])
		assert(v_head2 == -1, "2F->3F Step %d headroom at Y=%d must be air (-1), got %d" % [step, step_floor_y + 2, v_head2])

		# Verify 3F ceiling above 2F->3F stair is closed solid stone (5) - NO HOLLOWED-OUT HOLES!
		var v_ceil3f = terrain_node._map3dnum_flat[(base_y + 21) * terrain_node.worldh * terrain_node.worldw + cur_x * terrain_node.worldw + cur_z]
		assert(v_ceil3f == 5, "3F ceiling above 2F->3F stair at (%d,%d) must be solid stone (5), got %d" % [cur_x, cur_z, v_ceil3f])

	# Verify 2F->3F stair forward landing does not carve walls on 3F
	var stair1_info = terrain_node.stair[1]
	var sti2_3f = stair1_info[2]
	var stj2_3f = stair1_info[3]
	var di_3f = sign(sti2_3f - stair1_info[0])
	var dj_3f = sign(stj2_3f - stair1_info[1])
	for extra in range(1, 4):
		var check_i = sti2_3f + di_3f * extra
		var check_j = stj2_3f + dj_3f * extra
		if check_i >= 0 and check_i < terrain_node.castle_height_length - 19 and check_j >= 0 and check_j < terrain_node.castle_width_length - 19:
			var orig_map_val = terrain_node.castle[2][check_i][check_j]
			var wx_chk = terrain_node.castle_sth + 10 + check_i
			var wz_chk = terrain_node.castle_stw + 10 + check_j
			var vox_at_wall = terrain_node._map3dnum_flat[(base_y + 16) * terrain_node.worldh * terrain_node.worldw + wx_chk * terrain_node.worldw + wz_chk]
			if orig_map_val == 5:
				assert(vox_at_wall == 5, "Forward wall at (%d, %d) must NOT be carved into air! Must remain solid (5)" % [check_i, check_j])
	print("  2F->3F Stair landing verified: forward walls are intact and not carved out.")
	print("  2F->3F Stair verified: rise is continuous, headroom is open, and 3F ceiling is 100% solid stone.")
	print("-> PASS: Castle stairs (1F->2F and 2F->3F) are structurally sound with full headroom, solid ceilings, and intact forward walls.")

	# --- Check 7: 3F Central Boss Room & Dungeon Connection ---
	print("\n--- Check 7: 3F Central Boss Room & Dungeon Connection ---")
	var boss_poi = poi_map["boss_castle"]
	var boss_pos = boss_poi.pos
	print("  3F Boss (Demon) Position: %s" % boss_pos)
	assert(boss_poi.context == "castle_2", "Boss context must be castle_2 (3F)")
	assert(boss_pos.y == base_y + 16, "Demon must be standing on 3F floor at Y=%d" % (base_y + 16))

	# Verify Boss Room floor is solid and air is open
	var bx = int(boss_pos.x)
	var bz = int(boss_pos.z)
	var boss_floor = terrain_node._map3dnum_flat[(base_y + 15) * terrain_node.worldh * terrain_node.worldw + bx * terrain_node.worldw + bz]
	var boss_air = terrain_node._map3dnum_flat[(base_y + 16) * terrain_node.worldh * terrain_node.worldw + bx * terrain_node.worldw + bz]
	assert(boss_floor == 5, "Boss room floor slab must be solid stone (5)")
	assert(boss_air == -1, "Boss room foot level must be open air (-1)")

	# Verify uniform ceiling height (5 blocks clear height, ceiling slab at base_y + 21 is solid stone (5))
	for test_y in range(base_y + 16, base_y + 21):
		var v = terrain_node._map3dnum_flat[test_y * terrain_node.worldh * terrain_node.worldw + bx * terrain_node.worldw + bz]
		assert(v == -1, "Boss room interior at Y=%d must be air (-1)" % test_y)
	var boss_ceiling = terrain_node._map3dnum_flat[(base_y + 21) * terrain_node.worldh * terrain_node.worldw + bx * terrain_node.worldw + bz]
	assert(boss_ceiling == 5, "Boss room ceiling slab at Y=%d must be solid stone (5) completely sealing against sky light" % (base_y + 21))
	print("  Boss Room Uniform Ceiling verified: Sealed with solid stone slab at Y=%d matching 3F dungeon." % (base_y + 21))

	# Verify Boss Room is massively expanded (wide open hall check across +/- 14 blocks)
	var test_offsets = [Vector2i(-14, 0), Vector2i(14, 0), Vector2i(0, -14), Vector2i(0, 14), Vector2i(-12, -12), Vector2i(12, 12)]
	for off in test_offsets:
		var ox = bx + off.x
		var oz = bz + off.y
		var ofloor = terrain_node._map3dnum_flat[(base_y + 15) * terrain_node.worldh * terrain_node.worldw + ox * terrain_node.worldw + oz]
		var oair = terrain_node._map3dnum_flat[(base_y + 16) * terrain_node.worldh * terrain_node.worldw + ox * terrain_node.worldw + oz]
		assert(ofloor == 5, "Boss room expanded floor at (%d,%d) must be solid stone" % [ox, oz])
		assert(oair == -1, "Boss room expanded interior at (%d,%d) must be open air" % [ox, oz])
	print("  Boss Room Wide Dimensions verified: Hall spans over 30+ blocks wide (checked +/- 14 radius points).")
	print("-> PASS: 3F Central Boss Room is created with grand wide proportions, open hall, and uniform sunlight-sealed ceiling.")

	# --- Check 8: Player Spawn Safety & Biome Verification ---
	print("\n--- Check 8: Player Spawn Safety & Biome Verification ---")
	print("  Player initial spawn position: %s" % initial_player_pos)
	var snow_boss = poi_map["boss_snow"].pos
	var plain_boss = poi_map["boss_plain"].pos
	var plain_shop = poi_map["shop_plane"].pos
	
	var dist_snow_boss = initial_player_pos.distance_to(snow_boss)
	var dist_plain_boss = initial_player_pos.distance_to(plain_boss)
	var dist_plain_shop = initial_player_pos.distance_to(plain_shop)
	
	print("  Distance to Snow Boss (Blue Dragon, radius 14m): %.2fm (Required: > 20m)" % dist_snow_boss)
	print("  Distance to Plain Boss (Wolf, radius 10.5m): %.2fm (Required: > 18m)" % dist_plain_boss)
	print("  Distance to Plains Shop: %.2fm (Required: < 15m)" % dist_plain_shop)
	
	assert(dist_snow_boss > 20.0, "Player must spawn at least 20m away from Snow Boss! Got: %.2fm" % dist_snow_boss)
	assert(dist_plain_boss > 18.0, "Player must spawn at least 18m away from Plains Boss! Got: %.2fm" % dist_plain_boss)
	assert(dist_plain_shop < 15.0, "Player must spawn near Plains Shop! Got: %.2fm" % dist_plain_shop)
	
	# Verify voxel below player is strictly Plains Grass (4) or Dirt (5)
	var pi = int(initial_player_pos.x - terrain_node.plane_start_h)
	var pj = int(initial_player_pos.z - terrain_node.plane_start_w)
	var mat_at_spawn = terrain_node.assignnum[pi][pj]
	print("  Ground block type at player spawn: %d (4=Grass, 5=Dirt)" % mat_at_spawn)
	assert(mat_at_spawn == 4 or mat_at_spawn == 5, "Player must spawn on Plains Grass (4) or Dirt (5)! Got: %d" % mat_at_spawn)
	print("-> PASS: Player spawns safely on Plains near shop, far outside any boss detection sphere!")

	print("\n=======================================================")
	print("ALL VERIFICATION CHECKS PASSED SUCCESSFULLY!")
	print("=======================================================")
	quit(0)
