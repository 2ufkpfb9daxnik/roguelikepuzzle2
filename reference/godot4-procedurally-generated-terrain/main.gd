extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var new_scene = load("res://title_screen.tscn")
	get_tree().change_scene_to_packed(new_scene)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
