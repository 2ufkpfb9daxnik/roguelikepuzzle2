import re

with open('main.gd', 'r', encoding='utf-8') as f:
    text = f.read()

# _update_map_mode に minimap_container_under の更新を追加
old_0 = '''		0:
			minimap_container.show()
			minimap_container.size = Vector2(256, 256)
			minimap_container.position = Vector2(20, viewport_size.y - 276)'''

new_0 = '''		0:
			minimap_container.show()
			minimap_container.size = Vector2(256, 256)
			minimap_container.position = Vector2(20, viewport_size.y - 276)
			if minimap_container_under:
				minimap_container_under.size = minimap_container.size
				minimap_container_under.position = minimap_container.position'''
text = text.replace(old_0, new_0)

old_1 = '''		1:
			minimap_container.show()
			var map_size = min(viewport_size.x, viewport_size.y) - 80
			minimap_container.size = Vector2(map_size, map_size)
			minimap_container.position = (viewport_size - Vector2(map_size, map_size)) / 2.0'''

new_1 = '''		1:
			minimap_container.show()
			var map_size = min(viewport_size.x, viewport_size.y) - 80
			minimap_container.size = Vector2(map_size, map_size)
			minimap_container.position = (viewport_size - Vector2(map_size, map_size)) / 2.0
			if minimap_container_under:
				minimap_container_under.size = minimap_container.size
				minimap_container_under.position = minimap_container.position'''
text = text.replace(old_1, new_1)

with open('main.gd', 'w', encoding='utf-8') as f:
    f.write(text)

print("Updated _update_map_mode.")
