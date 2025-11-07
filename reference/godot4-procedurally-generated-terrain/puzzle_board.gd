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
var same_cells = []
var canmove = true
var matching = false
var falling = false
var score = [0,0,0,0,0,0,0,0,0,0,0]
var base_names = [
	"bread",
	"coin",
	"potion",
	"shield",
	"sword",
	"arrow",
	"heal",
	"axe",
	"club",
	"magicCircle",
	"wand"
]
enum BattleState {
	INTRO,			 
	PLAYER_TURN_START, 
	PLAYER_TURN,	   
	PLAYER_ATTACK,	
	ENEMY_TURN_START,  
	ENEMY_TURN,		
	VICTORY,		   
	DEFEAT			 
}
signal battle_state_requested(new_state: String)
func _ready():
	for i in range(58):
		same_cells.append([])
	for i in base_names.size():
		var name = base_names[i]
		parse_int_to_png[i] = load("res://texture/cell/%s.png" % name)
		same_cells[i] = [i]

	# === 複数駒を自動登録 ===
	var combo_index = base_names.size()
	var texture_dir = "res://texture/cell/"

	var dir = DirAccess.open(texture_dir)
	if dir:
		for file_name in dir.get_files():
			if not file_name.ends_with(".png"):
				continue
			var base_name = file_name.get_basename()
			# 「_」を含むファイル名のみ処理
			if "_" in base_name:
				var parts = base_name.split("_")
				var cell_list = []
				for part in parts:
					var idx = base_names.find(part)
					if idx != -1:
						cell_list.append(idx)
				if cell_list.size() > 0:
					parse_int_to_png[combo_index] = load(texture_dir + file_name)
					same_cells[combo_index] = cell_list
					combo_index += 1
	
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
			for k in range(12,same_cells.size()):
				var ok = true
				for l in range(same_cells[k].size()):
					var cur = same_cells[k][l]
					# --- 縦方向の3連防止 ---
					if i - 2 * frame_count >= 0:
						var a = board[i - frame_count][j]
						var b = board[i - 2 * frame_count][j]
						var ok1 = true
						var ok2 = true
						for m in range(same_cells[a].size()):
							if cur == same_cells[a][m]:
								ok1 = false
						for m in range(same_cells[b].size()):
							if cur == same_cells[b][m]:
								ok2 = false
						if !ok1 and !ok2:
							ok = false

					# --- 横方向の3連防止 ---
					if j - 2 >= 0:
						var a = board[i][j - 1]
						var b = board[i][j - 2]
						var ok1 = true
						var ok2 = true
						for m in range(same_cells[a].size()):
							if cur == same_cells[a][m]:
								ok1 = false
						for m in range(same_cells[b].size()):
							if cur == same_cells[b][m]:
								ok2 = false
						if !ok1 and !ok2:
							ok = false
				if ok:
					candidates.append(k)

			# 候補が空になることは稀だが、その場合はランダムで埋める
			if candidates.is_empty():
				board[i][j] = randi() % (same_cells.size()-11)+11
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
			var y = board_offset.y + (float(i)/float(30) * (cell_size + spacing))
			tex_rect.position = Vector2(x, y)
			# ============================================

			tex_rect.scale = Vector2(0.04, 0.04)
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
	print("moved:",curpos,"to",Vector2(target_j,target_i))
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
			
			# --- 縦方向のチェック ---
			var ok_v = true # 縦チェック用の変数
			if i + 2 < board_height: # 縦に3マスあるか
				var a = board[(i + 1) * frame_count][j]
				var b = board[(i + 2) * frame_count][j]
				
				# -1 (空マス) があればマッチしない
				if a != -1 and b != -1:
					for l in range(same_cells[cell].size()):
						var cur = same_cells[cell][l]
						var ok1 = true
						var ok2 = true
						for m in range(same_cells[a].size()):
							if cur == same_cells[a][m]:
								ok1 = false
						for m in range(same_cells[b].size()):
							if cur == same_cells[b][m]:
								ok2 = false
						if !ok1 and !ok2:
							ok_v = false # マッチ！
							break # 1つでもマッチタイプが見つかればループを抜ける
			
			if !ok_v:
				pop_cells.append([Vector2i(j, i), 1]) # 縦フラグ 1
			
			# --- 横方向のチェック ---
			var ok_h = true # 横チェック用の変数
			if j + 2 < board_width: # 横に3マスあるか
				var a = board[i * frame_count][j + 1]
				var b = board[i * frame_count][j + 2]
				
				if a != -1 and b != -1:
					for l in range(same_cells[cell].size()):
						var cur = same_cells[cell][l]
						var ok1 = true
						var ok2 = true
						for m in range(same_cells[a].size()):
							if cur == same_cells[a][m]:
								ok1 = false
						for m in range(same_cells[b].size()):
							if cur == same_cells[b][m]:
								ok2 = false
						if !ok1 and !ok2:
							ok_h = false
							break
			
			if !ok_h:
				pop_cells.append([Vector2i(j, i), 0])
				
	return pop_cells
func fall_cell() -> bool:
	var did_fall = false
	for j in range(board[0].size()):
		for i in range(board.size()-1,-1,-1):
			var f = true
			for k in range(1,frame_count+1):
				if i+k >= board_height*frame_count:
					f = false
					break
				if board[i+k][j] != -1:
					f = false
					break
			if f:
				board[i+1][j] = board[i][j]
				board[i][j] = -1
				cells[i+1][j] = cells[i][j]
				cells[i][j] = null
				did_fall = true
	for j in range(board_width):
		var f = true
		for k in range(0,frame_count):
			if board[k][j] != -1:
				f = false
				break
		if f:
			board[0][j] = randi() % (same_cells.size()-11)+11
			did_fall = true
	return did_fall
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
		if pop_cell.size() == 0:
			emit_signal("battle_state_requested",score,BattleState.PLAYER_ATTACK)
			for i in range(11):
				score[i] = 0
			matching = false
			return
		for k in range(pop_cell.size()):
			if pop_cell[k][1] == 0:
				for j in range(3):
					for l in range (same_cells[board[pop_cell[k][0].y*frame_count][pop_cell[k][0].x+j]].size()):
						score[same_cells[board[pop_cell[k][0].y*frame_count][pop_cell[k][0].x+j]][l]] += 1
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
		matching = false
		falling = true
	if falling:
		falling = fall_cell()
		if !falling:
			matching = true
		_draw_board()
	
