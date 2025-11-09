extends Node3D
@onready var shop_ui: Control = $CanvasLayer/ShopUI 
@onready var player_node: CharacterBody3D = $CharacterBody3D
var allies = ["res://model/enemy/have_animation/red_magician/"]
var allies_name = ["red_magician"]
var allies_type = [10]
var allies_level = [1]
var allies_base_health = [80]
var allies_base_attack = [15]
var allies_base_defense = [20]
var allies_cur_health = [-1]
var isshoping = false
var money:int = 0
var all_characters: Dictionary = {"aquatic_guardian":[80,15,25,0,"res://model/enemy/have_animation/aquatic_guardian",300],
"bee":[25,45,5,8,"res://model/enemy/have_animation/bee",500],
"blue_dragon":[155,75,65,4,"res://model/enemy/have_animation/blue_dragon",50000],
"cave_dragon":[155,75,65,8,"res://model/enemy/have_animation/cave_dragon",15000],
"demon":[475,125,135,10,"res://model/enemy/have_animation/demon",1000000],
"enigmatic_sorcerer":[75,45,15,10,"res://model/enemy/have_animation/enigmatic_sorcerer",100000],
"fantasy_wolf":[95,45,35,4,"res://model/enemy/have_animation/fantasy_wolf",1500],
"kurione":[65,15,5,0,"res://model/enemy/have_animation/kurione",150000],
"mushroom_man":[170,35,345,0,"res://model/enemy/have_animation/mushroom_man",7000],
"mysterious_mummy":[90,25,35,4,"res://model/enemy/have_animation/mysterious_mummy",5000],
"octopus":[100,15,25,10,"res://model/enemy/have_animation/octopus",250000],
"rainbow_snake_dragon":[76,75,65,8,"res://model/enemy/have_animation/rainbow_snake_dragon",150000],
"red_magician":[155,65,54,10,"res://model/enemy/have_animation/red_magician",350000],
"scorpion":[95,45,35,8,"res://model/enemy/have_animation/scorpion",10000],
"sea_dragon":[155,75,85,10,"res://model/enemy/have_animation/sea_dragon",1200],
"snake_head":[75,35,25,8,"res://model/enemy/have_animation/snake_head",10000],
"spider":[45,35,15,4,"res://model/enemy/have_animation/spider",7000],
"stone_guardian":[95,55,95,4,"res://model/enemy/have_animation/stone_guardian",2000],
"swamp_guardian":[85,55,95,0,"res://model/enemy/have_animation/swamp_guardian",6000],
"wood_monster":[75,45,55,10,"res://model/enemy/have_animation/wood_monster",30000]}

func calculate_status(base: float, level: int, power: float = 2.0/3.0) -> int:
	return int(base + level * pow(base, power))
func generate_allies_to_spawn() -> Array:
	var allies_to_spawn = []
	for i in range(allies_level.size()):
		if allies_cur_health[i] == -1:
			var level = allies_level[i]
			var info = {
				"name": allies_name[i],
				"path": allies[i],
				"type": allies_type[i],
				"attack": calculate_status(allies_base_attack[i], level),
				"max_health": calculate_status(allies_base_health[i], level),
				"health": calculate_status(allies_base_health[i], level),
				"defense": calculate_status(allies_base_defense[i], level)
			}
			allies_to_spawn.append(info)
		else:
			var level = allies_level[i]
			var info = {
				"name": "hero%d" % (i + 1),
				"path": allies[i],
				"type": allies_type[i],
				"attack": calculate_status(allies_base_attack[i], level),
				"max_health": calculate_status(allies_base_health[i], level),
				"health": allies_cur_health[i],
				"defense": calculate_status(allies_base_defense[i], level)
			}
			allies_to_spawn.append(info)
	return allies_to_spawn
# terrain.gd から Shopが追加された時に呼び出される接続関数
func _connect_shop_signals_instance(shop_area: Area3D):
	# shop_area.gd がアタッチされているので、定義されたカスタムシグナルを接続
	if shop_area.has_signal("player_entered_shop"):
		shop_area.player_entered_shop.connect(_on_player_entered_shop)
	if shop_area.has_signal("player_exited_shop"):
		shop_area.player_exited_shop.connect(_on_player_exited_shop)
	print("ShopArea custom signals connected.")


# Shopに入った時に ShopUI を開く関数 (シグナルコールバック)
func _on_player_entered_shop(shop_root_node: Node3D):
	if shop_ui.visible:
		return
		
	print("Player entered the shop! Opening UI.")
	
	# プレイヤーの移動を停止
	if player_node.has_method("set_movement_enabled"):
		player_node.set_movement_enabled(false) 
	
	shop_ui.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Shopから出た時に UI を自動で閉じる関数
func _on_player_exited_shop(shop_root_node: Node3D):
	# 自動で閉じずに、UIが完全に閉じた後に操作を再開するロジックを推奨します。
	pass
