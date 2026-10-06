import re

with open('main.gd', 'r', encoding='utf-8') as f:
    text = f.read()

old_vp0 = '''			if vp: vp.size = Vector2i(256, 256)'''
new_vp0 = '''			if vp: vp.size = Vector2i(256, 256)
			var vp_under = minimap_container_under.get_node_or_null("MapViewportUnder") if minimap_container_under else null
			if vp_under: vp_under.size = Vector2i(256, 256)'''
text = text.replace(old_vp0, new_vp0)

old_vp1 = '''			if vp: vp.size = Vector2i(int(map_size), int(map_size))'''
new_vp1 = '''			if vp: vp.size = Vector2i(int(map_size), int(map_size))
			var vp_under = minimap_container_under.get_node_or_null("MapViewportUnder") if minimap_container_under else null
			if vp_under: vp_under.size = Vector2i(int(map_size), int(map_size))'''
text = text.replace(old_vp1, new_vp1)

with open('main.gd', 'w', encoding='utf-8') as f:
    f.write(text)

print("Updated viewport size sync.")
