extends Node3D

@export var health: int = 100
@export var speed: float = 5.0
@export var mesh_path: String = ""
@export var pos: Vector3 = Vector3.ZERO

var animation_player: AnimationPlayer
var current_animation: String = ""
var animations: Array = []

func _ready():
	if mesh_path == "":
		push_warning("No mesh_path set for enemy.")
		return
	var packed_scene = load(mesh_path)
	if packed_scene == null:
		push_error("Failed to load enemy model: " + mesh_path)
		return
	var model_scene = load(mesh_path)
	var model_instance
	
	if model_scene is PackedScene:
		model_instance = model_scene.instantiate()
	else:
		model_instance = MeshInstance3D.new()
		model_instance.mesh = model_scene
	
	add_child(model_instance)
	global_position = pos
	# アニメーションプレイヤーを探索
	animation_player = model_instance.get_node_or_null("AnimationPlayer")
	if animation_player:
		animations = animation_player.get_animation_list()
		if animations.size() > 0:
			current_animation = animations[0]
			animation_player.play(current_animation)
	else:
		push_warning("No AnimationPlayer found in enemy model: " + mesh_path)

	# コリジョン設定
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.5
	collision.shape = shape
	add_child(collision)

	# 位置設定
	position = pos
func _process(delta):
	translate(Vector3.FORWARD*speed*delta)
