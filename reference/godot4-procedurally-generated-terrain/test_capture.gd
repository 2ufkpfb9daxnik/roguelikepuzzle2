extends Node3D

@onready var main_scene = preload("res://main.tscn")

func _ready():
	print("Test started")
	var main = main_scene.instantiate()
	get_tree().root.add_child(main)
	print("Main instantiated")
	
	# Wait for generation
	while main.get_node("terrain").is_generating:
		await get_tree().process_frame
		
	print("Terrain generated")
	
	var player = main.player_node
	var t = main.get_node("terrain")
	var found = false
	for y in range(10, 25):
		if found: break
		for x in range(t.worldh/2 - 50, t.worldh/2 + 50):
			if found: break
			for z in range(t.worldw/2 - 50, t.worldw/2 + 50):
				var idx = y * t.worldh * t.worldw + x * t.worldw + z
				if t._map3dnum_flat[idx] == -1:
					var idx_down = (y-1) * t.worldh * t.worldw + x * t.worldw + z
					if t._map3dnum_flat[idx_down] != -1:
						player.global_position = Vector3(x, y + 1.0, z)
						found = true
						print("Found cave at: ", player.global_position)
						break
						
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("debug"):
		dir.make_dir("debug")
		
	var vp_ground = main.minimap_container.get_node("MapViewport")
	var vp_under = main.minimap_container_under.get_node("MapViewportUnder")
	
	if vp_ground: vp_ground.get_texture().get_image().save_png("res://debug/ground.png")
	if vp_under: vp_under.get_texture().get_image().save_png("res://debug/under.png")
	
	print("Saved images to res://debug/")
	get_tree().quit()
