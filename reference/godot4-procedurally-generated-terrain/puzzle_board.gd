extends Control

# ==============================
# パズル設定
# ==============================
var board_height: int = 5
var board_width: int = 12
var cell_size: float = 37.6
var spacing: float = 4.0
var board_offset: Vector2 = Vector2(4, 8)

# ==============================
# 盤面データ
# ==============================
var board: Array = []           # 5 x 12 の整数配列 (駒ID)
var cells: Array = []           # 5 x 12 の TextureRect 配列 (UIノードプール)
var parse_int_to_png: Dictionary = {}
var same_cells: Array = []
var base_names: Array = [
	"bread", "coin", "potion", "shield", "sword",
	"arrow", "heal", "axe", "club", "magicCircle", "wand"
]
var score: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

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

signal battle_state_requested(new_score: Array, new_state: int)

# ==============================
# 操作ステート
# ==============================
var canmove: bool = true
var is_animating: bool = false
var ispressed: bool = false
var curpos: Vector2i = Vector2i(-1, -1)
var dragging_piece: TextureRect = null
var dragging_original_pos: Vector2 = Vector2.ZERO

# ==============================
# 初期化
# ==============================
func _ready() -> void:
	_init_piece_definitions()
	_init_board_data()
	_generate_initial_board()
	_create_ui_nodes()
	queue_redraw()

func _init_piece_definitions() -> void:
	same_cells.clear()
	for i in range(70):
		same_cells.append([])

	for i in range(base_names.size()):
		var piece_name = base_names[i]
		var tex_path = "res://texture/cell/%s.png" % piece_name
		if ResourceLoader.exists(tex_path):
			parse_int_to_png[i] = load(tex_path)
		same_cells[i] = [i]

	var combo_index = base_names.size()
	var texture_dir = "res://texture/cell/"
	var dir = DirAccess.open(texture_dir)
	if dir:
		for file_name in dir.get_files():
			if not file_name.ends_with(".png"):
				continue
			var base_name = file_name.get_basename()
			if "_" in base_name:
				var parts = base_name.split("_")
				var cell_list = []
				for part in parts:
					var idx = base_names.find(part)
					if idx != -1:
						cell_list.append(idx)
				if cell_list.size() > 0:
					var path = texture_dir + file_name
					parse_int_to_png[combo_index] = load(path)
					same_cells[combo_index] = cell_list
					combo_index += 1

func _init_board_data() -> void:
	board.clear()
	cells.clear()
	for r in range(board_height):
		var b_row = []
		var c_row = []
		for c in range(board_width):
			b_row.append(-1)
			c_row.append(null)
		board.append(b_row)
		cells.append(c_row)

func _generate_initial_board() -> void:
	var min_idx = 11
	var max_idx = max(min_idx + 1, same_cells.size())
	for r in range(board_height):
		for c in range(board_width):
			var candidates = []
			for k in range(min_idx, max_idx):
				if not same_cells[k].is_empty() and not _would_cause_match(r, c, k):
					candidates.append(k)
			if candidates.is_empty():
				board[r][c] = randi_range(min_idx, max_idx - 1)
			else:
				board[r][c] = candidates.pick_random()

func _would_cause_match(r: int, c: int, piece_id: int) -> bool:
	var piece_types = same_cells[piece_id]
	# 横方向チェック (左2マス)
	if c >= 2:
		var p1 = board[r][c - 1]
		var p2 = board[r][c - 2]
		if p1 >= 0 and p2 >= 0:
			for t in piece_types:
				if t in same_cells[p1] and t in same_cells[p2]:
					return true
	# 縦方向チェック (上2マス)
	if r >= 2:
		var p1 = board[r - 1][c]
		var p2 = board[r - 2][c]
		if p1 >= 0 and p2 >= 0:
			for t in piece_types:
				if t in same_cells[p1] and t in same_cells[p2]:
					return true
	return false

# ==============================
# UIノードプール（TextureRect再利用）
# ==============================
func _create_ui_nodes() -> void:
	for child in get_children():
		if child is TextureRect:
			child.queue_free()

	for r in range(board_height):
		for c in range(board_width):
			var tex_rect = TextureRect.new()
			var piece_id = board[r][c]
			if parse_int_to_png.has(piece_id):
				tex_rect.texture = parse_int_to_png[piece_id]
			tex_rect.position = get_cell_position(r, c)
			tex_rect.scale = Vector2(0.04, 0.04)
			tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tex_rect)
			cells[r][c] = tex_rect

func get_cell_position(r: int, c: int) -> Vector2:
	var x = board_offset.x + c * (cell_size + spacing)
	var y = board_offset.y + r * (cell_size + spacing)
	return Vector2(x, y)

# ==============================
# 描画（グリッド）
# ==============================
func _draw() -> void:
	var total_width = board_width * (cell_size + spacing)
	var total_height = board_height * (cell_size + spacing)
	var color = Color(0.8, 0.8, 0.8, 0.6)

	for i in range(board_height + 1):
		var y = board_offset.y + i * (cell_size + spacing) - spacing / 2.0
		draw_line(Vector2(board_offset.x - spacing / 2.0, y), Vector2(board_offset.x + total_width - spacing / 2.0, y), color, 1.5)

	for j in range(board_width + 1):
		var x = board_offset.x + j * (cell_size + spacing) - spacing / 2.0
		draw_line(Vector2(x, board_offset.y - spacing / 2.0), Vector2(x, board_offset.y + total_height - spacing / 2.0), color, 1.5)

# ==============================
# マウス入力・操作
# ==============================
func _process(_delta: float) -> void:
	if canmove and not is_animating:
		var mouse_pos = get_local_mouse_position()
		if Input.is_action_just_pressed("click"):
			_on_mouse_pressed(mouse_pos)
		elif Input.is_action_pressed("click") and ispressed:
			_on_mouse_drag(mouse_pos)
		elif Input.is_action_just_released("click") and ispressed:
			_on_mouse_released(mouse_pos)

func _on_mouse_pressed(mouse_pos: Vector2) -> void:
	var local_pos = mouse_pos - board_offset
	var c = int(local_pos.x / (cell_size + spacing))
	var r = int(local_pos.y / (cell_size + spacing))
	if r < 0 or c < 0 or r >= board_height or c >= board_width:
		return

	curpos = Vector2i(c, r)
	ispressed = true
	dragging_piece = cells[r][c]
	if dragging_piece:
		dragging_original_pos = dragging_piece.position
		dragging_piece.z_index = 10

func _on_mouse_drag(mouse_pos: Vector2) -> void:
	if dragging_piece:
		dragging_piece.position = mouse_pos - Vector2(cell_size * 0.5, cell_size * 0.5)

func _on_mouse_released(mouse_pos: Vector2) -> void:
	if not ispressed or curpos.x == -1:
		_reset_drag()
		return

	var local_pos = mouse_pos - board_offset
	var target_c = int(local_pos.x / (cell_size + spacing))
	var target_r = int(local_pos.y / (cell_size + spacing))

	if target_r < 0 or target_c < 0 or target_r >= board_height or target_c >= board_width or (target_c == curpos.x and target_r == curpos.y):
		if dragging_piece:
			dragging_piece.position = dragging_original_pos
		_reset_drag()
		return

	# スワップ実行
	var src_r = curpos.y
	var src_c = curpos.x
	_swap_cells(src_r, src_c, target_r, target_c)
	_reset_drag()

	# 連鎖・マッチ判定の開始
	canmove = false
	is_animating = true
	_process_matches_loop()

func _reset_drag() -> void:
	if dragging_piece:
		dragging_piece.z_index = 0
	ispressed = false
	curpos = Vector2i(-1, -1)
	dragging_piece = null

func _swap_cells(r1: int, c1: int, r2: int, c2: int) -> void:
	var tmp_id = board[r1][c1]
	board[r1][c1] = board[r2][c2]
	board[r2][c2] = tmp_id

	var node1 = cells[r1][c1]
	var node2 = cells[r2][c2]
	cells[r1][c1] = node2
	cells[r2][c2] = node1

	if node1:
		node1.position = get_cell_position(r2, c2)
	if node2:
		node2.position = get_cell_position(r1, c1)

# ==============================
# 高速マッチング＆カスケード落下処理
# ==============================
func _process_matches_loop() -> void:
	var matched_coords = cell_matching()
	if matched_coords.is_empty():
		# マッチなし -> ターン終了。攻撃リクエストを送信
		is_animating = false
		canmove = true
		emit_signal("battle_state_requested", score.duplicate(), BattleState.PLAYER_ATTACK)
		for i in range(score.size()):
			score[i] = 0
		return

	# マッチしたセルを消去アニメーション
	var tween = create_tween().set_parallel(true)
	for coord in matched_coords:
		var r = coord.y
		var c = coord.x
		var piece_id = board[r][c]
		if piece_id >= 0:
			for t in same_cells[piece_id]:
				score[t] += 1
			board[r][c] = -1

		var node = cells[r][c]
		if node and is_instance_valid(node):
			tween.tween_property(node, "modulate:a", 0.0, 0.2)
			tween.parallel().tween_property(node, "scale", Vector2.ZERO, 0.2)

	await tween.finished

	# 消去したノードを非表示にしてリセット
	for coord in matched_coords:
		var r = coord.y
		var c = coord.x
		var node = cells[r][c]
		if node and is_instance_valid(node):
			node.visible = false
			cells[r][c] = null

	# 落下＆新規駒補充
	await _apply_gravity_and_refill()

	# 再度マッチを検査（連鎖）
	_process_matches_loop()

func cell_matching() -> Array:
	var matched = {}

	# 横方向のチェック
	for r in range(board_height):
		for c in range(board_width - 2):
			var p1 = board[r][c]
			var p2 = board[r][c + 1]
			var p3 = board[r][c + 2]
			if p1 >= 0 and p2 >= 0 and p3 >= 0:
				for t in same_cells[p1]:
					if t in same_cells[p2] and t in same_cells[p3]:
						matched[Vector2i(c, r)] = true
						matched[Vector2i(c + 1, r)] = true
						matched[Vector2i(c + 2, r)] = true
						break

	# 縦方向のチェック
	for r in range(board_height - 2):
		for c in range(board_width):
			var p1 = board[r][c]
			var p2 = board[r + 1][c]
			var p3 = board[r + 2][c]
			if p1 >= 0 and p2 >= 0 and p3 >= 0:
				for t in same_cells[p1]:
					if t in same_cells[p2] and t in same_cells[p3]:
						matched[Vector2i(c, r)] = true
						matched[Vector2i(c, r + 1)] = true
						matched[Vector2i(c, r + 2)] = true
						break

	return matched.keys()

func _apply_gravity_and_refill() -> void:
	var fall_tween = create_tween().set_parallel(true)
	var min_idx = 11
	var max_idx = max(min_idx + 1, same_cells.size())

	# 列ごとに下から詰める
	for c in range(board_width):
		var write_r = board_height - 1
		for read_r in range(board_height - 1, -1, -1):
			if board[read_r][c] != -1:
				if write_r != read_r:
					board[write_r][c] = board[read_r][c]
					cells[write_r][c] = cells[read_r][c]
					board[read_r][c] = -1
					cells[read_r][c] = null

					var node = cells[write_r][c]
					if node:
						var target_pos = get_cell_position(write_r, c)
						fall_tween.tween_property(node, "position", target_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				write_r -= 1

		# 空いた上部のマスに新規駒を生成
		var spawn_offset = 1
		while write_r >= 0:
			var new_piece = randi_range(min_idx, max_idx - 1)
			board[write_r][c] = new_piece

			# ノードを新規またはプールから再生成
			var node = TextureRect.new()
			if parse_int_to_png.has(new_piece):
				node.texture = parse_int_to_png[new_piece]
			var target_pos = get_cell_position(write_r, c)
			node.position = target_pos - Vector2(0, (cell_size + spacing) * spawn_offset)
			node.scale = Vector2(0.04, 0.04)
			node.stretch_mode = TextureRect.STRETCH_SCALE
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(node)
			cells[write_r][c] = node

			fall_tween.tween_property(node, "position", target_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			write_r -= 1
			spawn_offset += 1

	await fall_tween.finished
