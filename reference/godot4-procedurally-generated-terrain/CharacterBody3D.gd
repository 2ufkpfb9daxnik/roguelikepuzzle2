extends CharacterBody3D

#==> EXPORT <==#
@export var speed = 20
@export var jump_speed = 25
@export var mouse_sensitivity = 2
var torch_light: OmniLight3D
var isbattle = false
#==> OTHER <==#
var gravity = 9.8
var time_passed = 0.0
#==> CODE <==#
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	torch_light = OmniLight3D.new()
	torch_light.light_color = Color(1.0, 0.8, 0.5)  # 暖かい橙色
	torch_light.light_energy = 5.0                # 明るさ（調整可能）
	torch_light.omni_range = 30.0                    # 光が届く距離
	torch_light.shadow_enabled = true               # 影を有効にする
	add_child(torch_light)
	
	torch_light.position = Vector3(1.5, 1.5, 1.5)
func _physics_process(delta):
	if isbattle:
		return
	velocity.y += -gravity * delta
	var input = Input.get_vector("a", "d", "w", "s")
	var movement_dir = transform.basis * Vector3(input.x, 0, input.y)
	velocity.x = movement_dir.x * speed
	velocity.z = movement_dir.z * speed
	move_and_slide()
	if is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_speed
	time_passed += delta
	#if torch_light:
		#var base_energy = 5.0
		#var flicker_amount = 10.0
		#torch_light.light_energy = base_energy + sin(time_passed * 10.0) * flicker_amount
		#torch_light.position.y = 1.5 + sin(time_passed * 7.0) * 0.05

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity/1000)
		$Camera3D.rotate_x(-event.relative.y * mouse_sensitivity/1000)
		$Camera3D.rotation.x = clampf($Camera3D.rotation.x, -deg_to_rad(70), deg_to_rad(70))
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			print("Mキーが押されました")
			get_parent().get_node("CanvasLayer/map/TextureRect").visible = !get_parent().get_node("CanvasLayer/map/TextureRect").visible
		
func _on_terrain_map_ready():
	gravity = 9.8
