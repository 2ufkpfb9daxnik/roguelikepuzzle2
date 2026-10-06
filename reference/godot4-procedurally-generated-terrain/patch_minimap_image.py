import re

with open('main.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 変数宣言の変更
content = content.replace("var minimap_container_under: SubViewportContainer", "var minimap_container_under: TextureRect")
content = content.replace("var minimap_camera_under: Camera3D\n", "")

# 2. _setup_minimap の変更
setup_old = '''	# Under minimap setup
	minimap_container_under = SubViewportContainer.new()
	minimap_container_under.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	minimap_container_under.size = Vector2(256, 256)
	minimap_container_under.position = Vector2(20, get_viewport().get_visible_rect().size.y - 276)
	minimap_container_under.modulate = Color(1, 1, 1, 1.0)
	
	var minimap_viewport_under = SubViewport.new()
	minimap_viewport_under.name = "MapViewportUnder"
	minimap_viewport_under.size = Vector2i(256, 256)
	minimap_viewport_under.transparent_bg = true
	minimap_viewport_under.world_3d = get_viewport().world_3d
	
	minimap_camera_under = Camera3D.new()
	minimap_camera_under.projection = Camera3D.PROJECTION_ORTHOGONAL
	minimap_camera_under.size = 150.0
	minimap_camera_under.current = false
	minimap_camera_under.cull_mask = 0xFFFFFFFF
	
	var map_env_under = Environment.new()
	map_env_under.background_mode = Environment.BG_COLOR
	map_env_under.background_color = Color(0, 0, 0, 0)
	map_env_under.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	map_env_under.ambient_light_color = Color(1, 1, 1)
	map_env_under.fog_enabled = false
	minimap_camera_under.environment = map_env_under
	
	minimap_viewport_under.add_child(minimap_camera_under)
	minimap_container_under.add_child(minimap_viewport_under)
	minimap_container_under.hide()'''

setup_new = '''	# Under minimap setup
	minimap_container_under = TextureRect.new()
	minimap_container_under.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	minimap_container_under.size = Vector2(256, 256)
	minimap_container_under.position = Vector2(20, get_viewport().get_visible_rect().size.y - 276)
	minimap_container_under.modulate = Color(1, 1, 1, 1.0)
	minimap_container_under.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap_container_under.stretch_mode = TextureRect.STRETCH_SCALE
	minimap_container_under.hide()'''
content = content.replace(setup_old, setup_new)

# 3. _process のデバッグログ出力の置き換え
process_old = '''					if not has_meta("_debug_under_timer"):
						set_meta("_debug_under_timer", 0.0)
					var t = get_meta("_debug_under_timer")
					t -= _delta
					if t <= 0.0:
						t = 0.5
						var vp = minimap_container_under.get_node_or_null("MapViewportUnder")
						var cam = minimap_camera_under
						var out = "\\n=== UNDERGROUND MAP DEBUG ===\\n"
						if vp:
							out += "SubViewport: size=" + str(vp.size)
							out += ", update_mode=" + str(vp.render_target_update_mode)
							out += ", world_3d_match=" + str(vp.world_3d == get_viewport().world_3d)
							out += ", transparent_bg=" + str(vp.transparent_bg) + "\\n"
						
						if cam:
							out += "Camera3D: parent=" + str(cam.get_parent().name) if cam.get_parent() else "null"
							out += ", current=" + str(cam.current) + ", proj=" + str(cam.projection)
							out += ", size=" + str(cam.size) + "\\n"
							out += "Camera Pos: " + str(cam.global_position) + ", near=" + str(cam.near) + ", far=" + str(cam.far)
							out += ", cull_mask=" + str(cam.cull_mask) + "\\n"
							out += "Near < Far: " + str(cam.near < cam.far) + "\\n"
						
						var px = int(round(player_node.global_position.x))
						var pz = int(round(player_node.global_position.z))
						var floor_y = 10.0
						var ceil_y = -1.0
						var terrain_node = get_node_or_null("terrain")
						if terrain_node:
							for y in range(int(player_node.global_position.y), int(player_node.global_position.y) + 20):
								if terrain_node.get_map3dnum(px, y, pz) != -1:
									ceil_y = float(y)
									break
						
						out += "Player Pos: " + str(player_node.global_position) + "\\n"
						out += "Est Ceiling Y: " + str(ceil_y) + ", Est Floor Y: " + str(floor_y) + "\\n"
						if cam:
							var dist_to_floor = cam.global_position.y - floor_y
							out += "Cam to Floor Dist: " + str(dist_to_floor) + " (In range? " + str(dist_to_floor >= cam.near and dist_to_floor <= cam.far) + ")\\n"
							var dist_to_ceil = cam.global_position.y - ceil_y
							out += "Cam to Ceil Dist: " + str(dist_to_ceil) + " (Should be < near to be culled)\\n"
						
						if minimap_container_under and minimap_container:
							out += "Container: class=" + str(minimap_container_under.get_class())
							out += ", vis=" + str(minimap_container_under.visible)
							out += ", mod.a=" + str(minimap_container_under.modulate.a)
							out += ", size=" + str(minimap_container_under.size) + "\\n"
							out += "Draw Order: Main=" + str(minimap_container.get_index()) + " Under=" + str(minimap_container_under.get_index())
							if minimap_container_under.get_index() > minimap_container.get_index():
								out += " (Under is drawn ON TOP)\\n"
							else:
								out += " (Under is drawn BEHIND)\\n"
							
						print(out)
						
					set_meta("_debug_under_timer", t)'''

process_new = '''					if not has_meta("_under_update_timer"):
						set_meta("_under_update_timer", 0.0)
					var t = get_meta("_under_update_timer")
					t -= _delta
					if t <= 0.0:
						t = 0.4
						var start_time = Time.get_ticks_usec()
						_update_underground_minimap()
						var elapsed = Time.get_ticks_usec() - start_time
						print("Underground minimap update took " + str(elapsed) + " usec")
					set_meta("_under_update_timer", t)'''
content = content.replace(process_old, process_new)

# 4. _process のカメラ同期部分の削除
camera_sync1 = '''					if minimap_camera_under:
						minimap_camera_under.global_position = minimap_camera.global_position
						minimap_camera_under.global_position.y = player_node.global_position.y + 3.0
						minimap_camera_under.near = 0.1
						minimap_camera_under.far = 30.0\n'''
content = content.replace(camera_sync1, "")

camera_sync2 = '''				if minimap_camera_under:
					minimap_camera_under.global_position = minimap_camera.global_position
					minimap_camera_under.global_position.y = player_node.global_position.y + 3.0
					minimap_camera_under.near = 0.1
					minimap_camera_under.far = 30.0\n'''
content = content.replace(camera_sync2, "")

camera_sync3 = '''			if minimap_camera_under:
				minimap_camera_under.rotation_degrees = Vector3(-90, 0, 0)\n'''
content = content.replace(camera_sync3, "")

# 5. _update_map_mode に minimap_container_under のサイズ同期を追加
mapmode_old = '''	match map_mode:
		0: # 繝溘ル繝槭ャ繝・(蟾ｦ荳・
			minimap_container.show()
			minimap_container.size = Vector2(256, 256)
			minimap_container.position = Vector2(20, viewport_size.y - 276)
			if border: border.size = Vector2(264, 264)
			if solid_bg: solid_bg.size = Vector2(256, 256)
			if vp: vp.size = Vector2i(256, 256)
			if minimap_camera: minimap_camera.size = 150.0 # 蜊雁ｾ・5繝槭せ遞句ｺｦ
		1: # 蜈ｨ菴薙・繝・・ (荳ｭ螟ｮ)
			minimap_container.show()
			var map_size = min(viewport_size.x, viewport_size.y) - 80
			minimap_container.size = Vector2(map_size, map_size)
			minimap_container.position = (viewport_size - Vector2(map_size, map_size)) / 2.0
			if border: border.size = Vector2(map_size + 8, map_size + 8)
			if solid_bg: solid_bg.size = Vector2(map_size, map_size)
			if vp: vp.size = Vector2i(map_size, map_size)
			if minimap_camera: minimap_camera.size = 150.0'''

mapmode_new = '''	match map_mode:
		0: # ミニマップ
			minimap_container.show()
			minimap_container.size = Vector2(256, 256)
			minimap_container.position = Vector2(20, viewport_size.y - 276)
			if minimap_container_under:
				minimap_container_under.size = minimap_container.size
				minimap_container_under.position = minimap_container.position
			if border: border.size = Vector2(264, 264)
			if solid_bg: solid_bg.size = Vector2(256, 256)
			if vp: vp.size = Vector2i(256, 256)
			if minimap_camera: minimap_camera.size = 150.0
		1: # 全体マップ
			minimap_container.show()
			var map_size = min(viewport_size.x, viewport_size.y) - 80
			minimap_container.size = Vector2(map_size, map_size)
			minimap_container.position = (viewport_size - Vector2(map_size, map_size)) / 2.0
			if minimap_container_under:
				minimap_container_under.size = minimap_container.size
				minimap_container_under.position = minimap_container.position
			if border: border.size = Vector2(map_size + 8, map_size + 8)
			if solid_bg: solid_bg.size = Vector2(map_size, map_size)
			if vp: vp.size = Vector2i(map_size, map_size)
			if minimap_camera: minimap_camera.size = 150.0'''
content = content.replace(mapmode_old, mapmode_new)

# 6. 新しい関数 _update_underground_minimap の追加
new_func = '''
func _update_underground_minimap() -> void:
	if not minimap_container_under: return
	var terrain_node = get_node_or_null("terrain")
	if not terrain_node: return
	if not player_node: return
	
	var img = Image.create(151, 151, false, Image.FORMAT_RGBA8)
	var px = int(round(player_node.global_position.x))
	var pz = int(round(player_node.global_position.z))
	var py = int(round(player_node.global_position.y))
	
	for dz in range(-75, 76):
		for dx in range(-75, 76):
			var dist_sq = dx*dx + dz*dz
			if dist_sq > 48*48:
				# 範囲外は透明
				img.set_pixel(dx + 75, dz + 75, Color(0, 0, 0, 0))
				continue
				
			var tx = px + dx
			var tz = pz + dz
			var block_here = terrain_node.get_map3dnum(tx, py, tz)
			var block_above = terrain_node.get_map3dnum(tx, py + 1, tz)
			
			var c = Color(0, 0, 0, 0)
			if dx == 0 and dz == 0:
				c = Color(1.0, 0.0, 0.0, 1.0) # プレイヤー位置(赤)
			elif block_here == -1 and block_above == -1:
				c = Color(0.8, 0.8, 0.8, 0.9) # 通路
			elif block_here != -1:
				c = Color(0.2, 0.1, 0.0, 0.9) # 壁
			else:
				var found_space = false
				for y_off in range(-3, 4):
					if y_off == 0: continue
					if terrain_node.get_map3dnum(tx, py + y_off, tz) == -1 and terrain_node.get_map3dnum(tx, py + y_off + 1, tz) == -1:
						found_space = true
						break
				if found_space:
					c = Color(0.5, 0.5, 0.5, 0.7) # 上下±3の空間
					
			img.set_pixel(dx + 75, dz + 75, c)
			
	var tex = ImageTexture.create_from_image(img)
	minimap_container_under.texture = tex
'''
content += new_func

with open('main.gd', 'w', encoding='utf-8') as f:
    f.write(content)

print("Patch applied successfully.")
