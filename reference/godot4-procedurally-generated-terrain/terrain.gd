extends Node3D

@export var player : Node3D
@export var material_snow : Material = preload("res://texture/snow/material_snow.tres")
@export var material_rock : Material = preload("res://texture/rock/material_rock.tres")
@export var material_grass : Material = preload("res://texture/grass/material_grass.tres")
@export var material_dirt : Material = preload("res://texture/dirt/material_dirt.tres")

var exp = 9
var h = pow(2, exp) + 1
var w = pow(2, exp) + 1
var map = []
var aroundheightmin = []
var boxmap = []
var playerpos
var visibility_update_threshold = 4.0  # プレイヤーが移動したとみなす距離の2乗
var visibility_radius_squared = 2500.0  # 可視範囲の半径の2乗（距離50相当）
var max_height = 1.0 # 地形全体の最大高さを格納する変数

# パフォーマンス向上のため、FastNoiseLiteは一度だけ初期化する
var noise = FastNoiseLite.new()

func diamondsquare(amplitude=5.0):
	map[0][0] = randf_range(-1, 1) * amplitude
	map[0][w - 1] = randf_range(-1, 1) * amplitude
	map[h - 1][0] = randf_range(-1, 1) * amplitude
	map[h - 1][w - 1] = randf_range(-1, 1) * amplitude
	var size = h - 1
	amplitude *= 0.9
	while size > 1:
		for y in range(0, h - 1, size):
			for x in range(0, w - 1, size):
				var average = (map[y][x] + map[y][x + size] + map[y + size][x] + map[y + size][x + size]) / 4.0
				var mx = x + size / 2
				var my = y + size / 2
				map[my][mx] = average + randf_range(-1, 1) * amplitude

		for y in range(0, h, size):
			for x in range(0, w - 1, size):
				var mx = x + size / 2
				var add = 2
				map[y][mx] = map[y][x] + map[y][x + size]
				if y > 0:
					map[y][mx] += map[y - size / 2][mx]
					add += 1
				if y < h - 1:
					map[y][mx] += map[y + size / 2][mx]
					add += 1
				map[y][mx] = map[y][mx] / add + randf_range(-1, 1) * amplitude

		for x in range(0, w, size):
			for y in range(0, h - 1, size):
				var my = y + size / 2
				var add = 2
				map[my][x] = map[y][x] + map[y + size][x]
				if x > 0:
					map[my][x] += map[my][x - size / 2]
					add += 1
				if x < w - 1:
					map[my][x] += map[my][x + size / 2]
					add += 1
				map[my][x] = map[my][x] / add + randf_range(-1, 1) * amplitude

		size /= 2
		amplitude *= 0.5

func get_slope(i: int, j: int) -> float:
	# 勾配計算 (変更なし)
	var dx = 0.0
	var dz = 0.0
	if i > 0 and i < h - 1:
		dx = (map[i + 1][j] - map[i - 1][j]) / 2.0
	elif i == 0 and h > 1:
		dx = map[i + 1][j] - map[i][j]
	elif i == h - 1 and h > 1:
		dx = map[i][j] - map[i - 1][j]
	if j > 0 and j < w - 1:
		dz = (map[i][j + 1] - map[i][j - 1]) / 2.0
	elif j == 0 and w > 1:
		dz = map[i][j + 1] - map[i][j]
	elif j == w - 1 and w > 1:
		dz = map[i][j] - map[i][j - 1]
	return sqrt(dx * dx + dz * dz)

# -----------------------------------------------------------------------------
# ▼▼▼ 修正されたマテリアル割り当て関数 ▼▼▼
# -----------------------------------------------------------------------------
func assign_material_by_complex_logic(i: int, j: int, current_height: float, box: Node3D):
	var mesh = box.get_node_or_null("MeshInstance3D")
	if not mesh:
		return

	# --- パラメータ (ここで地形の見た目を調整) ---
	# 雪 (Snow) の設定
	var SNOW_START_HEIGHT = 0.75  # 雪が降り始める正規化された高さ (0.0 - 1.0)
	var SNOW_SLOPE_MAX = 0.3      # 雪が積もる最大勾配。これより急だと岩になる

	# 岩 (Rock) の設定
	var ROCK_SLOPE_MIN = 0.55     # 岩肌が露出し始める基本勾配
	var ROCK_HEIGHT_FACTOR = 0.3  # 高さが上がるほど岩になりやすくなる度合い

	# 草 (Grass) と 土 (Dirt) の設定
	var GRASS_SLOPE_MAX = 0.6     # 草が生える最大勾配。これより急だと土になる
	var GRASS_BAND_LOW = 0.1      # 草が生え始める下限の高さ
	var GRASS_BAND_PEAK = 0.4     # 草が最も密集する高さ
	var GRASS_BAND_HIGH = 0.8     # 草が生えなくなる上限の高さ
	
	# --- 準備 ---
	var slope = get_slope(i, j)
	var normalized_height = current_height / max_height if max_height > 0 else 0.0
	
	# --- マテリアル割り当てロジック (優先順位を考慮) ---

	# 1.【最優先】急勾配は「岩」にする
	# 高い場所ほど、より緩やかな勾配でも岩になるように調整
	var rock_slope_threshold = ROCK_SLOPE_MIN - (normalized_height * ROCK_HEIGHT_FACTOR)
	if slope > rock_slope_threshold:
		mesh.material_override = material_rock
		return # マテリアルが確定したので処理を終了

	# 2. 高く、緩やかな場所は「雪」にする
	if normalized_height > SNOW_START_HEIGHT and slope < SNOW_SLOPE_MAX:
		mesh.material_override = material_snow
		return

	# 3.「草」と「土」の分布を決定する
	#    - 草は特定の標高帯(中腹)で最もよく育つ
	#    - ノイズを使って自然な斑模様を生成する
	#    - 麓や、草が生える条件に合わない場所は「土」になる
	
	# 植生が生えるには勾配が緩やかである必要がある
	if slope > GRASS_SLOPE_MAX:
		mesh.material_override = material_dirt
		return

	# 標高に基づいて、草が生える可能性(0.0～1.0)を計算する
	# smoothstepを使い、GRASS_BANDで定義した帯状の領域で値が1に近づくようにする
	var grass_potential = smoothstep(GRASS_BAND_LOW, GRASS_BAND_PEAK, normalized_height) * \
						  (1.0 - smoothstep(GRASS_BAND_PEAK, GRASS_BAND_HIGH, normalized_height))

	# ノイズ値を取得 (-1.0～1.0なので0.0～1.0に変換)
	var n = (noise.get_noise_2d(float(i), float(j)) + 1.0) / 2.0

	# ノイズ値が草の生える可能性を下回ったら「草」を配置
	if n < grass_potential:
		mesh.material_override = material_grass
	else:
		# それ以外（麓、標高が高すぎる、ノイズの範囲外）は「土」を配置
		mesh.material_override = material_dirt

# -----------------------------------------------------------------------------
# ▲▲▲ 修正されたマテリアル割り当て関数 ▲▲▲
# -----------------------------------------------------------------------------

func _process(delta):
	var cur_pos = player.global_transform.origin
	if playerpos.distance_squared_to(cur_pos) >= visibility_update_threshold:
		playerpos = cur_pos
		update_visibility(cur_pos)

func update_visibility(center_pos: Vector3):
	var px = int(center_pos.x)
	var pz = int(center_pos.z)
	var r = int(sqrt(visibility_radius_squared))

	for i in range(max(0, px - r), min(w, px + r + 1)):
		for j in range(max(0, pz - r), min(h, pz + r + 1)):
			var current_height_map_value = map[i][j]
			var height = int(floor(current_height_map_value / 0.1))
			var around = int(floor(aroundheightmin[i][j] / 0.1))
			var diff = height - around
			var y_start = height - diff if diff * 0.1 >= 0.2 else height
			var y_end = height + 1

			for y in range(y_start, y_end):
				var block_pos = Vector3(i, y, j)
				if center_pos.distance_squared_to(block_pos) <= visibility_radius_squared:
					if boxmap[i][j].size() == 0:
						if diff * 0.1 >= 0.2:
							for k in range(diff + 1):
								var static_body = get_parent().get_node("StaticBody3D")
								if static_body:
									var static_body_copy = static_body.duplicate(true)
									static_body_copy.position = Vector3(i, height - k, j)
									assign_material_by_complex_logic(i, j, current_height_map_value, static_body_copy)
									get_parent().get_node("cube").add_child(static_body_copy)
									boxmap[i][j].append(static_body_copy)
						else:
							var static_body = get_parent().get_node("StaticBody3D")
							if static_body:
								var static_body_copy = static_body.duplicate(true)
								static_body_copy.position = Vector3(i, height, j)
								assign_material_by_complex_logic(i, j, current_height_map_value, static_body_copy)
								get_parent().get_node("cube").add_child(static_body_copy)
								boxmap[i][j].append(static_body_copy)
					
					for box_node in boxmap[i][j]:
						if center_pos.distance_squared_to(box_node.global_transform.origin) <= visibility_radius_squared:
							box_node.visible = true
						else:
							box_node.visible = false
				else:
					for box_node in boxmap[i][j]:
						box_node.visible = false

func _ready():
	if not player:
		push_error("Player is not defined. Check terrain right panel to set player.")
		queue_free()
		return
	
	# ノイズのプロパティをここで一度だけ設定
	noise.seed = randi() # 毎回違う地形を生成するためにseedをランダムに
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.02 # ノイズの細かさ。値を小さくすると、より大きな模様が生成される
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0

	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append([])
		boxmap.append(arrw)

	for i in range(h):
		var row_map = []
		var row_around = []
		for j in range(w):
			row_map.append(0.0)
			row_around.append(999999.0)
		map.append(row_map)
		aroundheightmin.append(row_around)

	diamondsquare()
	
	var minheight_val = 1e9
	var maxheight_val = -1e9
	for i in range(h):
		for j in range(w):
			minheight_val = min(minheight_val, map[i][j])
	
	for i in range(h):
		for j in range(w):
			map[i][j] -= minheight_val
			maxheight_val = max(maxheight_val, map[i][j])
	
	max_height = maxheight_val if maxheight_val > 0 else 1.0
	
	for i in range(h):
		for j in range(w):
			if i - 1 >= 0 and j - 1 >= 0:
				aroundheightmin[i][j] = min(aroundheightmin[i][j], map[i - 1][j - 1])
			if i - 1 >= 0:
				aroundheightmin[i][j] = min(aroundheightmin[i][j], map[i - 1][j])
			if i - 1 >= 0 and j + 1 < w:
				aroundheightmin[i][j] = min(aroundheightmin[i][j], map[i - 1][j + 1])
			if j + 1 < w:
				aroundheightmin[i][j] = min(aroundheightmin[i][j], map[i][j + 1])
			if i + 1 < h and j + 1 < w:
				aroundheightmin[i][j] = min(aroundheightmin[i][j], map[i + 1][j + 1])
			if i + 1 < h:
				aroundheightmin[i][j] = min(aroundheightmin[i][j], map[i + 1][j])
			if i + 1 < h and j - 1 >= 0:
				aroundheightmin[i][j] = min(aroundheightmin[i][j], map[i + 1][j - 1])
			if j - 1 >= 0:
				aroundheightmin[i][j] = min(aroundheightmin[i][j], map[i][j - 1])
			aroundheightmin[i][j] = min(map[i][j], aroundheightmin[i][j])
	playerpos = player.global_transform.origin
