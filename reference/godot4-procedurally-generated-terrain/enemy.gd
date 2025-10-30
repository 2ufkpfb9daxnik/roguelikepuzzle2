extends CharacterBody3D

@export var health: int = 100
@export var speed: float = 5.0
@export var mesh_path: String = ""
@export var pos: Vector3 = Vector3.ZERO
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var animation_player: AnimationPlayer
var current_animation: String = ""
var animations: Array = []
var player: CharacterBody3D
var nav_agent: NavigationAgent3D
func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = find_animation_player(child)
		if found:
			return found
	return null
func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	var next_pos = global_position
	if player and nav_agent:
		# プレイヤーを追跡する
		nav_agent.target_position = player.global_position
		next_pos = nav_agent.get_next_path_position()
	
	var dir = (next_pos - global_position).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	
	if dir != Vector3.ZERO:
		look_at(global_position + dir, Vector3.UP)
		
	move_and_slide()

func _ready():
	player = get_parent().get_node("CharacterBody3D")
	nav_agent = NavigationAgent3D.new()
	add_child(nav_agent)
	animation_player = find_animation_player(self)
	if animation_player:
		animations = animation_player.get_animation_list()
		# "Walk"や"Run"などのアニメーションがあれば再生する
		var anim_to_play = "Animation_Casual_Walk_withSkin"
		if not animations.has(anim_to_play):
			anim_to_play = "Animation_Running_withSkin"
		if not animations.has(anim_to_play) and animations.size() > 0:
			anim_to_play = animations[0] # フォールバック

		if animations.has(anim_to_play):
			animation_player.play(anim_to_play)
			
	else:
		push_warning("No AnimationPlayer found in enemy instance.")
	if not find_child("CollisionShape3D", true, false):
		var collision = CollisionShape3D.new()
		# 敵のサイズに合わせてShapeを調整する (CapsuleShape3Dが人型には適している)
		var shape = CapsuleShape3D.new()
		shape.radius = 0.5
		shape.height = 2.0
		collision.shape = shape
		add_child(collision)
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
