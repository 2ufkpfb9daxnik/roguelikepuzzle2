import re

with open('main.gd', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. 変数の復活
text = text.replace("var minimap_container_under: TextureRect", "var minimap_container_under: SubViewportContainer\nvar minimap_camera_under: Camera3D")

# 2. _setup_minimapの復元
setup_old = '''	# Under minimap setup
	minimap_container_under = TextureRect.new()
	minimap_container_under.size = Vector2(256, 256)
	minimap_container_under.position = Vector2(20, get_viewport().get_visible_rect().size.y - 276)
	minimap_container_under.modulate = Color(1, 1, 1, 1.0)
	minimap_container_under.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap_container_under.stretch_mode = TextureRect.STRETCH_SCALE
	minimap_container_under.hide()'''

setup_new = '''	# Under minimap setup
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
text = text.replace(setup_old, setup_new)

# 3. _process のタイマー処理削除と同期処理追加
proc_old = '''					if not has_meta("_under_update_timer"):
						set_meta("_under_update_timer", 0.0)
					var t = get_meta("_under_update_timer")
					t -= _delta
					if t <= 0.0:
						t = 0.4
						var start_time = Time.get_ticks_usec()
						_update_underground_minimap()
						var elapsed = Time.get_ticks_usec() - start_time

					set_meta("_under_update_timer", t)'''
					
proc_new = '''					if minimap_camera_under:
						minimap_camera_under.global_position = minimap_camera.global_position
						minimap_camera_under.global_position.y = player_node.global_position.y + 3.0
						minimap_camera_under.near = 0.1
						minimap_camera_under.far = 30.0'''
text = text.replace(proc_old, proc_new)

# 4. _process のもうひとつの同期部分追加 (map_mode 変更時などの同期)
# もともとのコードには、camera の位置や回転を同期する部分があった。
camera_sync_str = '''			if minimap_camera:
				minimap_camera.global_position = player_node.global_position + Vector3(0, 50, 0)
				minimap_camera.rotation_degrees = Vector3(-90, 0, 0)'''
camera_sync_new = '''			if minimap_camera:
				minimap_camera.global_position = player_node.global_position + Vector3(0, 50, 0)
				minimap_camera.rotation_degrees = Vector3(-90, 0, 0)
			if minimap_camera_under:
				minimap_camera_under.global_position = player_node.global_position + Vector3(0, 3.0, 0)
				minimap_camera_under.rotation_degrees = Vector3(-90, 0, 0)
				minimap_camera_under.near = 0.1
				minimap_camera_under.far = 30.0'''
text = text.replace(camera_sync_str, camera_sync_new)

# 5. _update_underground_minimap の削除
text = re.sub(r'func _update_underground_minimap\(\) -> void:.*', '', text, flags=re.DOTALL)

with open('main.gd', 'w', encoding='utf-8') as f:
    f.write(text)

print("Reverted to Camera3D approach (Method A).")
