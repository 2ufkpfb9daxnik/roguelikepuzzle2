extends Control

# ============================================================
# パズル盤面（ロジック + 2D表示）
# 5種類の基本駒 + 操作中キャラクターの属性スキル駒で構成する。
# 1ターン = 1スワップ。マッチが成立しないスワップは消費しない。
# ============================================================

signal turn_resolved(result: Dictionary)
signal combo_changed(combo: int)

const BOARD_HEIGHT := 13
const BOARD_WIDTH := 13
const CELL_SIZE := 60.0
const SPACING := 2.0
const BOARD_OFFSET := Vector2(6, 6)
const PIECE_SCALE := 0.86
const PIECE_SIZE := CELL_SIZE * PIECE_SCALE
const PIECE_PADDING := (CELL_SIZE - PIECE_SIZE) * 0.5

var board: Array = []
var cells: Array = []
var piece_textures: Dictionary = {}
var skill_texture: Texture2D = null
var grid_overlay: Control = null
var hovered_cell := Vector2i(-1, -1)

var canmove: bool = false
var is_animating: bool = false
var ispressed: bool = false
var curpos: Vector2i = Vector2i(-1, -1)
var dragging_piece: TextureRect = null
var dragging_original_pos: Vector2 = Vector2.ZERO
var turn_active := false

var active_element: int = GameData.Element.FIRE
var active_level: int = 1
var active_skill_attribute: int = GameData.Piece.SWORD
var skill_piece_id: int = 0
var allow_skill_pieces := false
var piece_pool: Array = []

var score: Array = [0, 0, 0, 0, 0, 0]
var combocount: int = 0
var element_hits: Dictionary = {}

func _ready() -> void:
	_init_piece_definitions()
	_init_board_data()
	_generate_initial_board()
	_create_ui_nodes()
	queue_redraw()

func configure(element: int, level: int, skills_unlocked: bool = false, skill_attribute: int = -1) -> void:
	var old_skill_piece := skill_piece_id
	var old_skill_attribute := active_skill_attribute
	active_element = element if element > 0 else GameData.Element.FIRE
	active_level = max(1, level)
	if skill_attribute >= 0:
		active_skill_attribute = skill_attribute
	skill_piece_id = GameData.piece_id_for_element(active_element)
	allow_skill_pieces = skills_unlocked
	_rebuild_pool()
	if old_skill_piece == 0:
		# 初回設定時は、解禁状況に応じた盤面を作り直す。
		if not board.is_empty():
			_generate_initial_board()
			_refresh_all_piece_visuals()
	elif old_skill_piece != skill_piece_id and allow_skill_pieces:
		_convert_existing_skill_pieces()
	elif not allow_skill_pieces:
		_remove_existing_skill_pieces()
	elif old_skill_attribute != active_skill_attribute:
		_refresh_all_piece_visuals()

func _refresh_all_piece_visuals() -> void:
	for r in range(board.size()):
		for c in range(board[r].size()):
			var node: TextureRect = cells[r][c]
			if node and is_instance_valid(node):
				_apply_piece_visual(node, int(board[r][c]))

func _convert_existing_skill_pieces() -> void:
	for r in range(board.size()):
		for c in range(board[r].size()):
			var piece_id: int = board[r][c]
			if not GameData.is_skill_piece(piece_id):
				continue
			board[r][c] = skill_piece_id
			var node: TextureRect = cells[r][c]
			if node and is_instance_valid(node):
				_apply_piece_visual(node, skill_piece_id)

func _rebuild_pool() -> void:
	# スキル駒は初期配置・補充では出さず、4個以上のマッチからのみ生成する。
	piece_pool = [0, 1, 2, 3, 4]

func _remove_existing_skill_pieces() -> void:
	for r in range(board.size()):
		for c in range(board[r].size()):
			if not GameData.is_skill_piece(int(board[r][c])):
				continue
			var replacement := randi_range(0, 4)
			board[r][c] = replacement
			var node: TextureRect = cells[r][c]
			if node and is_instance_valid(node):
				_apply_piece_visual(node, replacement)

func _init_piece_definitions() -> void:
	piece_textures.clear()
	for piece_id in range(5):
		var piece_name := GameData.base_piece_name(piece_id)
		var tex_path := "res://texture/cell/%s.png" % piece_name
		if ResourceLoader.exists(tex_path):
			piece_textures[piece_id] = load(tex_path)
	if ResourceLoader.exists("res://texture/cell/wand.png"):
		skill_texture = load("res://texture/cell/wand.png")
	elif ResourceLoader.exists("res://texture/cell/magicCircle.png"):
		skill_texture = load("res://texture/cell/magicCircle.png")
	elif ResourceLoader.exists("res://texture/cell/coin.png"):
		skill_texture = load("res://texture/cell/coin.png")
	_rebuild_pool()

func _init_board_data() -> void:
	board.clear()
	cells.clear()
	for r in range(BOARD_HEIGHT):
		var b_row := []
		var c_row := []
		for c in range(BOARD_WIDTH):
			b_row.append(-1)
			c_row.append(null)
		board.append(b_row)
		cells.append(c_row)

func _generate_initial_board() -> void:
	for r in range(BOARD_HEIGHT):
		for c in range(BOARD_WIDTH):
			var candidates := []
			for piece in piece_pool:
				if not _would_cause_match(r, c, piece):
					candidates.append(piece)
			if candidates.is_empty():
				board[r][c] = piece_pool.pick_random()
			else:
				board[r][c] = candidates.pick_random()

func _would_cause_match(r: int, c: int, piece_id: int) -> bool:
	if c >= 2 and board[r][c - 1] == piece_id and board[r][c - 2] == piece_id:
		return true
	if r >= 2 and board[r - 1][c] == piece_id and board[r - 2][c] == piece_id:
		return true
	return false

# ============================================================
# 表示
# ============================================================
func _create_ui_nodes() -> void:
	if grid_overlay and is_instance_valid(grid_overlay):
		grid_overlay.queue_free()
	for child in get_children():
		if child is TextureRect:
			child.queue_free()
	_create_grid_overlay()
	for r in range(BOARD_HEIGHT):
		for c in range(BOARD_WIDTH):
			var node := _create_piece_node(board[r][c])
			node.position = get_piece_position(r, c)
			add_child(node)
			cells[r][c] = node

func _create_grid_overlay() -> void:
	grid_overlay = Control.new()
	grid_overlay.name = "GridOverlay"
	grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_overlay.z_index = 5
	grid_overlay.size = Vector2(
		BOARD_OFFSET.x * 2.0 + BOARD_WIDTH * (CELL_SIZE + SPACING),
		BOARD_OFFSET.y * 2.0 + BOARD_HEIGHT * (CELL_SIZE + SPACING)
	)
	grid_overlay.draw.connect(_draw_grid_overlay.bind(grid_overlay))
	add_child(grid_overlay)
	grid_overlay.queue_redraw()

func _create_piece_node(piece_id: int) -> TextureRect:
	var tex_rect := TextureRect.new()
	_apply_piece_visual(tex_rect, piece_id)
	var texture_size: float = float(CELL_SIZE)
	if tex_rect.texture:
		texture_size = float(maxi(tex_rect.texture.get_width(), 1))
	var display_scale := PIECE_SIZE / texture_size
	tex_rect.scale = Vector2(display_scale, display_scale)
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex_rect

func _apply_piece_visual(node: TextureRect, piece_id: int) -> void:
	node.texture = _get_texture_for_piece(piece_id)
	if GameData.is_skill_piece(piece_id):
		node.self_modulate = GameData.element_color(GameData.element_for_piece(piece_id)).lerp(GameData.skill_attribute_color(active_skill_attribute), 0.55)
	else:
		node.self_modulate = Color.WHITE

func _get_texture_for_piece(piece_id: int) -> Texture2D:
	if GameData.is_skill_piece(piece_id):
		var attribute_texture: Texture2D = piece_textures.get(active_skill_attribute, null)
		if attribute_texture:
			return attribute_texture
		return skill_texture
	return piece_textures.get(piece_id, null)

func place_skill_piece() -> bool:
	if skill_piece_id <= GameData.SKILL_PIECE_OFFSET:
		return false
	var candidates: Array = []
	for r in range(BOARD_HEIGHT):
		for c in range(BOARD_WIDTH):
			var current: int = int(board[r][c])
			if current >= 0 and not GameData.is_skill_piece(current):
				candidates.append(Vector2i(c, r))
	if candidates.is_empty():
		return false
	candidates.shuffle()
	var chosen := Vector2i(-1, -1)
	# 盤面に即時の3マッチを作らないセルを優先する。
	for coord in candidates:
		var old_piece: int = int(board[coord.y][coord.x])
		board[coord.y][coord.x] = skill_piece_id
		if cell_matching().is_empty():
			chosen = coord
			break
		board[coord.y][coord.x] = old_piece
	if chosen.x < 0:
		chosen = candidates[0]
		board[chosen.y][chosen.x] = skill_piece_id
	var node: TextureRect = cells[chosen.y][chosen.x]
	if node and is_instance_valid(node):
		_apply_piece_visual(node, skill_piece_id)
		var base_scale := node.scale
		node.scale = base_scale * 0.2
		var tween := create_tween()
		tween.tween_property(node, "scale", base_scale, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return true

func get_cell_position(r: int, c: int) -> Vector2:
	return Vector2(BOARD_OFFSET.x + c * (CELL_SIZE + SPACING), BOARD_OFFSET.y + r * (CELL_SIZE + SPACING))

func get_piece_position(r: int, c: int) -> Vector2:
	return get_cell_position(r, c) + Vector2(PIECE_PADDING, PIECE_PADDING)

func _draw() -> void:
	var total_width := BOARD_WIDTH * (CELL_SIZE + SPACING)
	var total_height := BOARD_HEIGHT * (CELL_SIZE + SPACING)
	var board_rect := Rect2(
		BOARD_OFFSET - Vector2(SPACING * 0.5, SPACING * 0.5),
		Vector2(total_width, total_height)
	)

	# 盤面の外枠（影 + 角丸パネル）
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.01, 0.02, 0.04, 0.95)
	shadow.set_corner_radius_all(18)
	shadow.shadow_color = Color(0, 0, 0, 0.6)
	shadow.shadow_size = 12
	shadow.shadow_offset = Vector2(0, 5)
	draw_style_box(shadow, board_rect.grow(10.0))

	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.035, 0.055, 0.095, 0.98)
	frame.border_color = Color(0.34, 0.55, 0.90, 0.95)
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(16)
	draw_style_box(frame, board_rect)

	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0.05, 0.075, 0.12, 0.98)
	inner.border_color = Color(0.22, 0.36, 0.60, 0.55)
	inner.set_border_width_all(1)
	inner.set_corner_radius_all(10)
	draw_style_box(inner, board_rect.grow(-6.0))

	# 市松模様のセル
	for r in range(BOARD_HEIGHT):
		for c in range(BOARD_WIDTH):
			var pos := get_cell_position(r, c)
			var cell_rect := Rect2(pos, Vector2(CELL_SIZE, CELL_SIZE))
			var even := (r + c) % 2 == 0
			var tile_color := Color(0.075, 0.11, 0.17, 0.98) if even else Color(0.10, 0.14, 0.21, 0.98)
			draw_rect(cell_rect, tile_color, true)
			draw_line(
				Vector2(cell_rect.position.x + 3.0, cell_rect.position.y + 2.0),
				Vector2(cell_rect.end.x - 3.0, cell_rect.position.y + 2.0),
				Color(1, 1, 1, 0.05), 1.0
			)
			draw_line(
				Vector2(cell_rect.position.x + 3.0, cell_rect.end.y - 2.0),
				Vector2(cell_rect.end.x - 3.0, cell_rect.end.y - 2.0),
				Color(0, 0, 0, 0.28), 1.0
			)

func _draw_grid_overlay(overlay: Control) -> void:
	var total_width := BOARD_WIDTH * (CELL_SIZE + SPACING)
	var total_height := BOARD_HEIGHT * (CELL_SIZE + SPACING)
	var left := BOARD_OFFSET.x - SPACING * 0.5
	var top := BOARD_OFFSET.y - SPACING * 0.5
	var right := left + total_width
	var bottom := top + total_height
	var line_color := Color(0.38, 0.64, 1.0, 0.30)
	var outer_color := Color(0.58, 0.80, 1.0, 0.80)

	for i in range(BOARD_HEIGHT + 1):
		var y := top + i * (CELL_SIZE + SPACING)
		overlay.draw_line(Vector2(left, y), Vector2(right, y), line_color, 1.0)
	for j in range(BOARD_WIDTH + 1):
		var x := left + j * (CELL_SIZE + SPACING)
		overlay.draw_line(Vector2(x, top), Vector2(x, bottom), line_color, 1.0)

	overlay.draw_rect(Rect2(Vector2(left, top), Vector2(right - left, bottom - top)), outer_color, false, 2.0)
	overlay.draw_rect(Rect2(Vector2(left, top), Vector2(right - left, bottom - top)).grow(3.0), Color(0.28, 0.48, 0.82, 0.30), false, 1.0)

	if hovered_cell.x >= 0 and hovered_cell.y >= 0:
		var pos := get_cell_position(hovered_cell.y, hovered_cell.x)
		var hover_rect := Rect2(
			pos - Vector2(SPACING * 0.5, SPACING * 0.5),
			Vector2(CELL_SIZE + SPACING, CELL_SIZE + SPACING)
		)
		overlay.draw_rect(hover_rect, Color(0.70, 0.92, 1.0, 0.70), false, 2.0)
		overlay.draw_rect(hover_rect.grow(1.5), Color(0.35, 0.70, 1.0, 0.22), false, 3.0)

# ============================================================
# 入力
# ============================================================
func _process(_delta: float) -> void:
	_update_hovered_cell()
	if not canmove or is_animating or turn_active:
		return
	var mouse_pos := get_local_mouse_position()
	if Input.is_action_just_pressed("click"):
		_on_mouse_pressed(mouse_pos)
	elif Input.is_action_pressed("click") and ispressed:
		_on_mouse_drag(mouse_pos)
	elif Input.is_action_just_released("click") and ispressed:
		_on_mouse_released(mouse_pos)

func _update_hovered_cell() -> void:
	var next := Vector2i(-1, -1)
	if canmove and not is_animating and not turn_active:
		var local_pos := get_local_mouse_position() - BOARD_OFFSET
		if local_pos.x >= 0.0 and local_pos.y >= 0.0:
			var c := int(local_pos.x / (CELL_SIZE + SPACING))
			var r := int(local_pos.y / (CELL_SIZE + SPACING))
			if r >= 0 and c >= 0 and r < BOARD_HEIGHT and c < BOARD_WIDTH:
				next = Vector2i(c, r)
	if next != hovered_cell:
		hovered_cell = next
		if grid_overlay and is_instance_valid(grid_overlay):
			grid_overlay.queue_redraw()

func _on_mouse_pressed(mouse_pos: Vector2) -> void:
	var local_pos := mouse_pos - BOARD_OFFSET
	var c := int(local_pos.x / (CELL_SIZE + SPACING))
	var r := int(local_pos.y / (CELL_SIZE + SPACING))
	if r < 0 or c < 0 or r >= BOARD_HEIGHT or c >= BOARD_WIDTH:
		return
	curpos = Vector2i(c, r)
	ispressed = true
	dragging_piece = cells[r][c]
	if dragging_piece:
		dragging_original_pos = dragging_piece.position
		dragging_piece.z_index = 10

func _on_mouse_drag(mouse_pos: Vector2) -> void:
	if dragging_piece:
		dragging_piece.position = mouse_pos - Vector2(PIECE_SIZE * 0.5, PIECE_SIZE * 0.5)

func _on_mouse_released(mouse_pos: Vector2) -> void:
	if not ispressed or curpos.x == -1:
		_reset_drag()
		return
	var local_pos := mouse_pos - BOARD_OFFSET
	var target_c := int(local_pos.x / (CELL_SIZE + SPACING))
	var target_r := int(local_pos.y / (CELL_SIZE + SPACING))

	if target_r < 0 or target_c < 0 or target_r >= BOARD_HEIGHT or target_c >= BOARD_WIDTH:
		_cancel_drag()
		return
	var dist := absi(target_c - curpos.x) + absi(target_r - curpos.y)
	if dist != 1:
		_cancel_drag()
		return

	var src := Vector2i(curpos.x, curpos.y)
	var dst := Vector2i(target_c, target_r)
	_reset_drag()
	_try_swap(src, dst)

func _cancel_drag() -> void:
	if dragging_piece and is_instance_valid(dragging_piece):
		dragging_piece.position = dragging_original_pos
	_reset_drag()

func _reset_drag() -> void:
	if dragging_piece and is_instance_valid(dragging_piece):
		dragging_piece.z_index = 0
	ispressed = false
	curpos = Vector2i(-1, -1)
	dragging_piece = null

func _try_swap(src: Vector2i, dst: Vector2i) -> void:
	is_animating = true
	_swap_cells(src.y, src.x, dst.y, dst.x)
	await get_tree().create_timer(0.12).timeout
	if cell_matching().is_empty():
		_swap_cells(src.y, src.x, dst.y, dst.x)
		await get_tree().create_timer(0.12).timeout
		is_animating = false
		return
	turn_active = true
	combocount = 0
	element_hits.clear()
	await _process_matches_loop()
	_finish_turn()

func _swap_cells(r1: int, c1: int, r2: int, c2: int) -> void:
	var tmp: int = board[r1][c1]
	board[r1][c1] = board[r2][c2]
	board[r2][c2] = tmp
	var node1: TextureRect = cells[r1][c1]
	var node2: TextureRect = cells[r2][c2]
	cells[r1][c1] = node2
	cells[r2][c2] = node1
	if node1 and is_instance_valid(node1):
		node1.position = get_piece_position(r2, c2)
	if node2 and is_instance_valid(node2):
		node2.position = get_piece_position(r1, c1)

# ============================================================
# マッチ / 連鎖
# ============================================================
func _process_matches_loop() -> void:
	while true:
		var matched := cell_matching()
		if matched.is_empty():
			break
		var special_cell := _select_special_spawn_cell(matched)
		combocount += 1
		combo_changed.emit(combocount)
		await _break_matches(matched, special_cell)
		await _apply_gravity_and_refill()

func _select_special_spawn_cell(matched: Array) -> Vector2i:
	if not allow_skill_pieces or skill_piece_id <= 4:
		return Vector2i(-1, -1)
	var matched_set: Dictionary = {}
	for coord in matched:
		matched_set[coord] = true
	var best_run: Array = []
	# 横方向の4個以上の並び
	for r in range(BOARD_HEIGHT):
		var c := 0
		while c < BOARD_WIDTH:
			var piece_id: int = board[r][c]
			if piece_id < 0 or piece_id >= 5 or not matched_set.has(Vector2i(c, r)):
				c += 1
				continue
			var start := c
			while c + 1 < BOARD_WIDTH and board[r][c + 1] == piece_id and matched_set.has(Vector2i(c + 1, r)):
				c += 1
			var run_length := c - start + 1
			if run_length >= 4 and run_length > best_run.size():
				best_run.clear()
				for x in range(start, c + 1):
					best_run.append(Vector2i(x, r))
			c += 1
	# 縦方向の4個以上の並び
	for c in range(BOARD_WIDTH):
		var r := 0
		while r < BOARD_HEIGHT:
			var piece_id: int = board[r][c]
			if piece_id < 0 or piece_id >= 5 or not matched_set.has(Vector2i(c, r)):
				r += 1
				continue
			var start := r
			while r + 1 < BOARD_HEIGHT and board[r + 1][c] == piece_id and matched_set.has(Vector2i(c, r + 1)):
				r += 1
			var run_length := r - start + 1
			if run_length >= 4 and run_length > best_run.size():
				best_run.clear()
				for y in range(start, r + 1):
					best_run.append(Vector2i(c, y))
			r += 1
	if best_run.is_empty():
		return Vector2i(-1, -1)
	return best_run[best_run.size() >> 1]

func _break_matches(matched: Array, special_cell: Vector2i = Vector2i(-1, -1)) -> void:
	var tween := create_tween().set_parallel(true)
	var spawned_special := false
	for coord in matched:
		var r: int = coord.y
		var c: int = coord.x
		if not spawned_special and coord == special_cell:
			# 4個以上のマッチの中央をスキル駒へ進化させる。
			board[r][c] = skill_piece_id
			var special_node: TextureRect = cells[r][c]
			if special_node and is_instance_valid(special_node):
				_apply_piece_visual(special_node, skill_piece_id)
				special_node.modulate = Color.WHITE
			spawned_special = true
			continue
		var piece_id: int = board[r][c]
		if piece_id >= 0:
			_accumulate_score(piece_id)
			board[r][c] = -1
		var node: TextureRect = cells[r][c]
		if node and is_instance_valid(node):
			tween.tween_property(node, "modulate:a", 0.0, 0.18)
			tween.parallel().tween_property(node, "scale", Vector2.ZERO, 0.18)
	await tween.finished
	for coord in matched:
		if coord == special_cell and spawned_special:
			continue
		var node: TextureRect = cells[coord.y][coord.x]
		if node and is_instance_valid(node):
			node.queue_free()
			cells[coord.y][coord.x] = null

func _accumulate_score(piece_id: int) -> void:
	if GameData.is_skill_piece(piece_id):
		score[5] += 1
		var element := GameData.element_for_piece(piece_id)
		element_hits[element] = int(element_hits.get(element, 0)) + 1
		return
	if piece_id >= 0 and piece_id < 5:
		score[piece_id] += 1

func count_element_pieces(element: int) -> int:
	var count := 0
	for r in range(board.size()):
		for c in range(board[r].size()):
			if GameData.element_for_piece(int(board[r][c])) == element:
				count += 1
	return count

func has_element_piece(element: int) -> bool:
	return count_element_pieces(element) > 0

func cell_matching() -> Array:
	var matched: Dictionary = {}
	for r in range(BOARD_HEIGHT):
		for c in range(BOARD_WIDTH - 2):
			var p1: int = board[r][c]
			var p2: int = board[r][c + 1]
			var p3: int = board[r][c + 2]
			if p1 >= 0 and p1 == p2 and p2 == p3:
				matched[Vector2i(c, r)] = true
				matched[Vector2i(c + 1, r)] = true
				matched[Vector2i(c + 2, r)] = true
	for r in range(BOARD_HEIGHT - 2):
		for c in range(BOARD_WIDTH):
			var p1: int = board[r][c]
			var p2: int = board[r + 1][c]
			var p3: int = board[r + 2][c]
			if p1 >= 0 and p1 == p2 and p2 == p3:
				matched[Vector2i(c, r)] = true
				matched[Vector2i(c, r + 1)] = true
				matched[Vector2i(c, r + 2)] = true
	return matched.keys()

func _apply_gravity_and_refill() -> void:
	var fall_tween := create_tween().set_parallel(true)
	for c in range(BOARD_WIDTH):
		var write_r := BOARD_HEIGHT - 1
		for read_r in range(BOARD_HEIGHT - 1, -1, -1):
			if board[read_r][c] != -1:
				if write_r != read_r:
					board[write_r][c] = board[read_r][c]
					cells[write_r][c] = cells[read_r][c]
					board[read_r][c] = -1
					cells[read_r][c] = null
					var moving: TextureRect = cells[write_r][c]
					if moving and is_instance_valid(moving):
						fall_tween.tween_property(moving, "position", get_piece_position(write_r, c), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				write_r -= 1

		var spawn_offset := 1
		while write_r >= 0:
			var new_piece: int = piece_pool.pick_random()
			board[write_r][c] = new_piece
			var node := _create_piece_node(new_piece)
			var target_pos := get_piece_position(write_r, c)
			node.position = target_pos - Vector2(0, (CELL_SIZE + SPACING) * spawn_offset)
			add_child(node)
			cells[write_r][c] = node
			fall_tween.tween_property(node, "position", target_pos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			write_r -= 1
			spawn_offset += 1
	await fall_tween.finished

func _finish_turn() -> void:
	var result := {
		"score": score.duplicate(),
		"combo": combocount,
		"element_hits": element_hits.duplicate(),
		"active_element": active_element
	}
	score = [0, 0, 0, 0, 0, 0]
	element_hits.clear()
	combocount = 0
	turn_active = false
	is_animating = false
	canmove = false
	turn_resolved.emit(result)
