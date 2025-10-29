extends Node3D
var ScriptA = preload("res://terrain.gd")
var ScriptB = preload("res://spawn_enemy.gd")

func _ready():
	var a = ScriptA.new()
	var b = ScriptB.new()
	add_child(a)
	add_child(b)
