extends Control

var parse_int_to_png: Dictionary = {}
var board = []
var board_height = 5
var board_width = 12
var frame_count = 30
var cell_size = 37.6 # ← pixel単位で統一
var spacing = 4      # ← 駒間スペーシング
var board_offset = Vector2(4, 8) # ← 左上の基準位置を設定
var cells = []
var curpos: Vector2i = Vector2i(-1, -1)
var ispressed = false
var dragging_piece: TextureRect = null
var same_cells = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]
var canmove = true
var matching = false
func _ready():
	parse_int_to_png[0] = load("res://texture/cell/bread.png")
	same_cells[0].append(0)
	parse_int_to_png[1] = load("res://texture/cell/coin.png")
	same_cells[1].append(1)
	parse_int_to_png[2] = load("res://texture/cell/potion.png")
	same_cells[2].append(2)
	parse_int_to_png[3] = load("res://texture/cell/shield.png")
	same_cells[3].append(3)
	parse_int_to_png[4] = load("res://texture/cell/sword.png")
	same_cells[4].append(4)
	parse_int_to_png[5] = load("res://texture/cell/bread_coin.png")
	same_cells[0].append(5)
	same_cells[1].append(5)
	same_cells[5].append(0)
	same_cells[5].append(1)
	same_cells[5].append(5)
	same_cells[5].append(6)
	same_cells[5].append(7)
	same_cells[5].append(8)
	same_cells[5].append(9)
	same_cells[5].append(10)
	same_cells[5].append(11)
	parse_int_to_png[6] = load("res://texture/cell/bread_potion.png")
	same_cells[0].append(6)
	same_cells[2].append(6)
	same_cells[6].append(0)
	same_cells[6].append(2)
	same_cells[6].append(5)
	same_cells[6].append(6)
	same_cells[6].append(7)
	same_cells[6].append(8)
	same_cells[6].append(9)
	same_cells[6].append(12)
	same_cells[6].append(13)
	parse_int_to_png[7] = load("res://texture/cell/bread_shield.png")
	same_cells[0].append(7)
	same_cells[3].append(7)
	same_cells[7].append(0)
	same_cells[7].append(3)
	same_cells[7].append(5)
	same_cells[7].append(6)
	same_cells[7].append(7)
	same_cells[7].append(8)
	same_cells[7].append(10)
	same_cells[7].append(12)
	same_cells[7].append(14)
	parse_int_to_png[8] = load("res://texture/cell/bread_sword.png")
	same_cells[0].append(8)
	same_cells[4].append(8)
	same_cells[8].append(0)
	same_cells[8].append(4)
	same_cells[8].append(5)
	same_cells[8].append(6)
	same_cells[8].append(7)
	same_cells[8].append(8)
	same_cells[8].append(11)
	same_cells[8].append(13)
	same_cells[8].append(14)
	parse_int_to_png[9] = load("res://texture/cell/coin_potion.png")
	same_cells[1].append(9)
	same_cells[2].append(9)
	same_cells[9].append(1)
	same_cells[9].append(2)
	same_cells[9].append(5)
	same_cells[9].append(6)
	same_cells[9].append(9)
	same_cells[9].append(10)
	same_cells[9].append(11)
	same_cells[9].append(12)
	same_cells[9].append(13)
	parse_int_to_png[10] = load("res://texture/cell/coin_shield.png")
	same_cells[1].append(10)
	same_cells[3].append(10)
	same_cells[10].append(1)
	same_cells[10].append(3)
	same_cells[10].append(5)
	same_cells[10].append(7)
	same_cells[10].append(9)
	same_cells[10].append(10)
	same_cells[10].append(11)
	same_cells[10].append(12)
	same_cells[10].append(14)
	parse_int_to_png[11] = load("res://texture/cell/coin_sword.png")
	same_cells[1].append(11)
	same_cells[4].append(11)
	same_cells[11].append(1)
	same_cells[11].append(4)
	same_cells[11].append(5)
	same_cells[11].append(8)
	same_cells[11].append(9)
	same_cells[11].append(10)
	same_cells[11].append(11)
	same_cells[11].append(13)
	same_cells[11].append(14)
	parse_int_to_png[12] = load("res://texture/cell/potion_shield.png")
	same_cells[2].append(12)
	same_cells[3].append(12)
	same_cells[12].append(2)
	same_cells[12].append(3)
	same_cells[12].append(6)
	same_cells[12].append(7)
	same_cells[12].append(9)
	same_cells[12].append(10)
	same_cells[12].append(12)
	same_cells[12].append(13)
	same_cells[12].append(14)
	parse_int_to_png[13] = load("res://texture/cell/potion_sword.png")
	same_cells[2].append(13)
	same_cells[4].append(13)
	same_cells[13].append(2)
	same_cells[13].append(4)
	same_cells[13].append(6)
	same_cells[13].append(8)
	same_cells[13].append(9)
	same_cells[13].append(11)
	same_cells[13].append(12)
	same_cells[13].append(13)
	same_cells[13].append(14)
	parse_int_to_png[14] = load("res://texture/cell/shield_sword.png")
	same_cells[3].append(14)
	same_cells[4].append(14)
	same_cells[14].append(3)
	same_cells[14].append(4)
	same_cells[14].append(7)
	same_cells[14].append(8)
	same_cells[14].append(10)
	same_cells[14].append(11)
	same_cells[14].append(12)
	same_cells[14].append(13)
	same_cells[14].append(14)
	for i in range(board_height*frame_count):
		var arrw = []
		for j in range(board_width):
			arrw.append(-1)
		board.append(arrw)
	for i in range(board_height*frame_count):
		var arrw = []
		for j in range(board_width):
			arrw.append(null)
		cells.append(arrw)
	_generate_board()
	_draw_board()
func _generate_board():
	for i in range(board_height * frame_count):
		if i % frame_count != 0:
			continue
		for j in range(board_width):
			var candidates = []
			for k in range(15):
				var ok = true
				# --- 縦方向の3連防止 ---
				if i - 2 * frame_count >= 0:
					var a = board[i - frame_count][j]
					var b = board[i - 2 * frame_count][j]
					var ok1 = true
					var ok2 = true
					for l in range(same_cells[k].size()):
						if a == same_cells[k][l]:
							ok1 = false
						if b == same_cells[k][l]:
							ok2 = false
					if !ok1 and !ok2:
						ok = false

				# --- 横方向の3連防止 ---
				if j - 2 >= 0:
					var a = board[i][j-1]
					var b = board[i][j-2]
					var ok1 = true
					var ok2 = true
					for l in range(same_cells[k].size()):
						if a == same_cells[k][l]:
							ok1 = false
						if b == same_cells[k][l]:
							ok2 = false
					if !ok1 and !ok2:
						ok = false
				if ok:
					candidates.append(k)

			# 候補が空になることは稀だが、その場合はランダムで埋める
			if candidates.is_empty():
				board[i][j] = randi() % 15
			else:
				board[i][j] = candidates.pick_random()
func is_same_group(a: int, b: int) -> bool:
	if a == -1 or b == -1:
		return false
	if a == b:
		return true
	return b in same_cells[a] or a in same_cells[b]
func _draw_board():
	# 既存のTextureRectを削除
	for c in get_children():
		if c is TextureRect:
			c.queue_free()
	for i in range(board_height*frame_count):
		for j in range(board_width):
			if board[i][j] == -1:
				continue
			var tex_rect = TextureRect.new()
			tex_rect.texture = parse_int_to_png[board[i][j]]

			# === スペーシング + オフセットを考慮した配置 ===
			var x = board_offset.x + j * (cell_size + spacing)
			var y = board_offset.y + int(i/30) * (cell_size + spacing)
			tex_rect.position = Vector2(x, y)
			# ============================================

			tex_rect.scale = Vector2(0.08, 0.08)
			tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tex_rect)
			cells[i][j] = tex_rect

	# グリッドを描画
	queue_redraw()


func _draw():  # Controlクラスの描画用コールバック
	draw_grid()


func draw_grid():
	var total_width = board_width * (cell_size + spacing)
	var total_height = board_height * (cell_size + spacing)
	var color = Color(0.8, 0.8, 0.8, 0.6) # 半透明グレー

	# 横線
	for i in range(board_height + 1):
		var y = board_offset.y + i * (cell_size + spacing) - spacing / 2
		draw_line(
			Vector2(board_offset.x - spacing / 2, y),
			Vector2(board_offset.x + total_width - spacing / 2, y),
			color,
			1.5
		)

	# 縦線
	for j in range(board_width + 1):
		var x = board_offset.x + j * (cell_size + spacing) - spacing / 2
		draw_line(
			Vector2(x, board_offset.y - spacing / 2),
			Vector2(x, board_offset.y + total_height - spacing / 2),
			color,
			1.5
		)


func _on_mouse_pressed(mouse_pos: Vector2):
	# ボードオフセットを考慮してクリック位置を補正
	var local_pos = mouse_pos - board_offset
	var j = int(local_pos.x / (cell_size + spacing))
	var i = int(int(local_pos.y) / (cell_size + spacing))*frame_count
	if i < 0 or j < 0 or i >= board_height*frame_count or j >= board_width:
		return
	curpos = Vector2i(j, i)
	ispressed = true
	dragging_piece = cells[i][j]


func _on_mouse_drag(mouse_pos: Vector2):
	if dragging_piece:
		dragging_piece.position = mouse_pos - Vector2(cell_size / 2, cell_size / 2)


func _on_mouse_released(mouse_pos: Vector2):
	if not ispressed or curpos.x == -1:
		return

	var local_pos = mouse_pos - board_offset
	var target_j = int(local_pos.x / (cell_size + spacing))
	var target_i = int(local_pos.y / (cell_size + spacing))*frame_count
	# 範囲チェック
	if target_i < 0 or target_j < 0 or target_i >= board_height*frame_count or target_j >= board_width:
		_draw_board()
		_reset_drag()
		return
	if curpos.y == target_i and curpos.x == target_j:
		_reset_drag()
		return
	# 入れ替え
	var tmp = board[curpos.y][curpos.x]
	board[curpos.y][curpos.x] = board[target_i][target_j]
	board[target_i][target_j] = tmp
	canmove = false
	matching = true
	_draw_board()
	_reset_drag()


func _reset_drag():
	ispressed = false
	curpos = Vector2i(-1, -1)
	dragging_piece = null
func cell_matching() -> Array:
	var pop_cells: Array = []

	for i in range(board_height):
		for j in range(board_width):
			var cell = board[i * frame_count][j]
			if cell == -1:
				continue
			if j + 2 < board_width:
				var right1 = board[i * frame_count][j + 1]
				var right2 = board[i * frame_count][j + 2]
				var ok1 = false
				var ok2 = false
				for l in range(same_cells[board[i * frame_count][j]].size()):
					if right1 == same_cells[board[i * frame_count][j]][l]:
						ok1 = true
				for l in range(same_cells[board[i * frame_count][j]].size()):
					if right2 == same_cells[board[i * frame_count][j]][l]:
						ok2 = true
				if ok1 and ok2:
					pop_cells.append([Vector2i(j, i),0])
			if i + 2 < board_height:
				var down1 = board[(i + 1) * frame_count][j]
				var down2 = board[(i + 2) * frame_count][j]
				var ok1 = false
				var ok2 = false
				for l in range(same_cells[board[i * frame_count][j]].size()):
					if down1 == same_cells[board[i * frame_count][j]][l]:
						ok1 = true
				for l in range(same_cells[board[i * frame_count][j]].size()):
					if down2 == same_cells[board[i * frame_count][j]][l]:
						ok2 = true
				if ok1 and ok2:
					pop_cells.append([Vector2i(j, i),1])
	return pop_cells

func _process(delta):
	if canmove:
		var mouse_pos = get_local_mouse_position()
		if Input.is_action_just_pressed("click"):
			_on_mouse_pressed(mouse_pos)
		elif Input.is_action_pressed("click") and ispressed:
			_on_mouse_drag(mouse_pos)
		elif Input.is_action_just_released("click") and ispressed:
			_on_mouse_released(mouse_pos)
	if matching:
		var pop_cell = cell_matching()
		for k in range(pop_cell.size()):
			if pop_cell[k][1] == 0:
				for j in range(3):
					board[pop_cell[k][0].y*frame_count][pop_cell[k][0].x+j] = -1
					if cells[pop_cell[k][0].y*frame_count][pop_cell[k][0].x+j] != null:
						cells[pop_cell[k][0].y*frame_count][pop_cell[k][0].x+j].queue_free()
						cells[pop_cell[k][0].y*frame_count][pop_cell[k][0].x+j] = null
			if pop_cell[k][1] == 1:
				for i in range(3):
					board[(pop_cell[k][0].y+i)*frame_count][pop_cell[k][0].x] = -1
					if cells[(pop_cell[k][0].y+i)*frame_count][pop_cell[k][0].x] != null:
						cells[(pop_cell[k][0].y+i)*frame_count][pop_cell[k][0].x].queue_free()
						cells[(pop_cell[k][0].y+i)*frame_count][pop_cell[k][0].x] = null
		pass
	
	
