extends Area3D

signal player_entered_shop(shop_node: Node3D)
signal player_exited_shop(shop_node: Node3D)

# ショップ展開は「近づいて E キー」に変更。
# 接触しただけでは開かず、中心からの距離・移動速度・戦闘状態も確認する。
@export var interact_distance: float = 7.0
@export var max_open_speed: float = 12.0

var _ready_delay: float = 0.0
var _is_ready: bool = false
var _player_inside: Node3D = null
var _prompt_label: Label3D = null


func _ready() -> void:
	_create_prompt()
	var exit_callable := Callable(self, "_on_body_exited")
	if not body_exited.is_connected(exit_callable):
		body_exited.connect(exit_callable)

func _create_prompt() -> void:
	_prompt_label = Label3D.new()
	_prompt_label.name = "ShopInteractPrompt"
	_prompt_label.text = "[E] ショップ"
	_prompt_label.font_size = 48
	_prompt_label.modulate = Color(1.0, 0.90, 0.45)
	_prompt_label.outline_size = 8
	_prompt_label.outline_modulate = Color(0, 0, 0, 0.9)
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.pixel_size = 0.005
	_prompt_label.position = Vector3(0, 3.2, 0)
	_prompt_label.visible = false
	add_child(_prompt_label)

func _process(delta: float) -> void:
	if not _is_ready:
		_ready_delay += delta
		if _ready_delay >= 2.0:
			_is_ready = true
			for body in get_overlapping_bodies():
				if body and body.name == "CharacterBody3D":
					_player_inside = body
					break
			return
	_update_prompt()

func _update_prompt() -> void:
	if _prompt_label == null or not is_instance_valid(_prompt_label):
		return
	var show_prompt := false
	if _is_ready and _player_inside != null and is_instance_valid(_player_inside):
		show_prompt = _can_interact(_player_inside)
	_prompt_label.visible = show_prompt

func _can_interact(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if "isbattle" in body and body.isbattle:
		return false
	var main_node = _find_main_node()
	if main_node:
		if "isbattle" in main_node and main_node.isbattle:
			return false
		if "isshoping" in main_node and main_node.isshoping:
			return false
		if main_node.find_child("battle_scene", true, false) != null or main_node.find_child("BattleScene", true, false) != null:
			return false
	if global_position.distance_to(body.global_position) > interact_distance:
		return false
	if body is CharacterBody3D and body.velocity.length() > max_open_speed:
		return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not _is_ready or _player_inside == null:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode != KEY_E:
		return
	if not _can_interact(_player_inside):
		return
	get_viewport().set_input_as_handled()
	emit_signal("player_entered_shop", self)

func _on_body_entered(body: Node3D) -> void:
	if not _is_ready:
		return
	if not body or body.name != "CharacterBody3D":
		return
	_player_inside = body
	_update_prompt()

func _on_body_exited(body: Node3D) -> void:
	if body == _player_inside:
		_player_inside = null
		_update_prompt()

func _find_main_node() -> Node:
	var curr: Node = self
	while curr:
		if curr.name == "main":
			return curr
		curr = curr.get_parent()
	return null
