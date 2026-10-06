import re

with open('main.gd', 'r', encoding='utf-8') as f:
    text = f.read()

old_logic = '''				var is_underground = player_node.global_position.y < 20.0
				if is_underground and minimap_container_under:
					minimap_container.modulate.a = 0.3
					minimap_container_under.visible = true
					if player_marker.get_parent() != minimap_container_under:
						player_marker.get_parent().remove_child(player_marker)
						minimap_container_under.add_child(player_marker)
				elif not is_underground and minimap_container:
					minimap_container.modulate.a = 1.0
					if minimap_container_under: minimap_container_under.visible = false
					if player_marker.get_parent() != minimap_container:
						player_marker.get_parent().remove_child(player_marker)
						minimap_container.add_child(player_marker)'''

new_logic = '''				var is_underground = _is_underground_cached
				if is_underground and minimap_container_under:
					if player_marker.get_parent() != minimap_container_under:
						player_marker.get_parent().remove_child(player_marker)
						minimap_container_under.add_child(player_marker)
				elif not is_underground and minimap_container:
					if player_marker.get_parent() != minimap_container:
						player_marker.get_parent().remove_child(player_marker)
						minimap_container.add_child(player_marker)
						
	if not _debug_capture_done and get_node_or_null("terrain") and not get_node("terrain").is_generating:
		_debug_capture_done = true
		_run_debug_capture()'''

text = text.replace(old_logic, new_logic)

with open('main.gd', 'w', encoding='utf-8') as f:
    f.write(text)

print("Updated duplicate is_underground logic.")
