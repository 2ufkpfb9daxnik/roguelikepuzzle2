extends Control
var parse_int_to_png :Dictionary = {}
var board = []
var board_height = 6
var board_width = 11
var frame_count = 30
var cell_size = 0.08
func _ready():
	parse_int_to_png[0] = load("res://texture/cell/bread.png")
	parse_int_to_png[1] = load("res://texture/cell/coin.png")
	parse_int_to_png[2] = load("res://texture/cell/potion.png")
	parse_int_to_png[3] = load("res://texture/cell/shield.png")
	parse_int_to_png[4] = load("res://texture/cell/sword.png")
	parse_int_to_png[5] = load("res://texture/cell/bread_coin.png")
	parse_int_to_png[6] = load("res://texture/cell/bread_potion.png")
	parse_int_to_png[7] = load("res://texture/cell/bread_shield.png")
	parse_int_to_png[8] = load("res://texture/cell/bread_sword.png")
	parse_int_to_png[9] = load("res://texture/cell/coin_potion.png")
	parse_int_to_png[10] = load("res://texture/cell/coin_shield.png")
	parse_int_to_png[11] = load("res://texture/cell/coin_sword.png")
	parse_int_to_png[12] = load("res://texture/cell/potion_shield.png")
	parse_int_to_png[13] = load("res://texture/cell/potion_sword.png")
	parse_int_to_png[14] = load("res://texture/cell/shield_sword.png")
	for i in range(board_height*frame_count):
		var arrw = []
		for j in range(board_width):
			arrw.append(-1)
		board.append(arrw)
	for i in range(board.size()):
		if i%frame_count != 0:
			continue
		for j in range(board[0].size()):
			var candidate = []
			for k in range(15):
				if i-2*frame_count >= 0:
					if board[i-2*frame_count][j] == board[i-1*frame_count][j] and k == board[i-1*frame_count][j]:
						continue
				if j-2 >= 0:
					if board[i][j-2] == board[i][j-1] and k == board[i][j-1]:
						continue
				candidate.append(k)
			board[i][j] = candidate.pick_random()
	_draw_board()

func _draw_board():
	for c in get_children():
		if c is TextureRect:
			c.queue_free()

	for i in range(board_height*frame_count):
		for j in range(board_width):
			if board[i][j] == -1:
				continue
			var tex_rect = TextureRect.new()
			tex_rect.texture = parse_int_to_png[board[i][j]]
			tex_rect.position = Vector2i(j*cell_size*530,int(i/30)*cell_size*530)
			print(tex_rect.position)
			tex_rect.z_index = 1
			tex_rect.scale = Vector2(cell_size,cell_size)
			tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
			add_child(tex_rect)
			move_child(tex_rect, get_child_count() - 1)
