extends Area3D

signal player_entered_shop(shop_node: Node3D)
signal player_exited_shop(shop_node: Node3D)

var _ready_delay: float = 0.0
var _is_ready: bool = false

func _process(delta: float) -> void:
	if not _is_ready:
		_ready_delay += delta
		if _ready_delay >= 2.0:
			_is_ready = true
			set_process(false)

func _on_body_entered(body: Node3D) -> void:
	if not _is_ready:
		return
	if body and body.name == "CharacterBody3D":
		# 戦闘中はショップ判定を完全に遮断
		if "isbattle" in body and body.isbattle:
			return

		var main_node = _find_main_node()
		if main_node:
			if ("isbattle" in main_node and main_node.isbattle) or main_node.find_child("battle_scene", true, false) != null or main_node.find_child("BattleScene", true, false) != null:
				return
			if "isshoping" in main_node and main_node.isshoping:
				return

		emit_signal("player_entered_shop", self)

func _on_body_exited(body: Node3D) -> void:
	if body and body.name == "CharacterBody3D":
		emit_signal("player_exited_shop", self)

func _find_main_node() -> Node:
	var curr: Node = self
	while curr:
		if curr.name == "main":
			return curr
		curr = curr.get_parent()
	return null
