extends Area3D

@onready var shop_ui = get_parent().get_parent().get_node("ShopUi")
func _on_body_entered(body: Node3D) -> void:
	if get_parent().get_parent().isshoping:
		return
	if body and body.name == "CharacterBody3D":
		shop_ui.visible = true
		shop_ui.get_node("MoneyLabel").text = "Money:"+str(get_parent().get_parent().money)
		get_parent().get_parent().isshoping = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
