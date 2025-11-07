extends Control

var isclicked = false
var interval = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_node("titlebgm").play()
	pass # Replace with function body.
func _on_button_pressed() -> void:
	if(isclicked):
		return
	print("pressed")
	get_node("click").play()
	isclicked = true
	pass # Replace with function body.
func _process(delta: float) -> void:
	if(isclicked):
		if(interval<30):
			get_node("anten").color.a += 0.03
		elif(interval>=40):
			get_node("anten").color.a = 0
			isclicked = false
			var next_scene = load("res://terrain.tscn")
			get_parent().change_scene_to_packed(next_scene)
		interval += 1
