extends Node3D

@export var player : Node3D
@export var material_snow : Material = preload("res://texture/snow/material_snow.tres")
@export var material_rock : Material = preload("res://texture/rock/material_rock.tres")
@export var material_grass : Material = preload("res://texture/grass/material_grass.tres")
@export var material_dirt : Material = preload("res://texture/dirt/material_dirt.tres")
@export var material_water : Material = preload("res://texture/water/material_water.tres")

var exp = 6
var h = pow(2, exp) + 1
var w = pow(2, exp) + 1
var map = []
var map3d = []
<<<<<<< HEAD
var collisiondata = []
var map3dnum = []
=======
>>>>>>> ba02b9fdd8400b1ed783049398999d8e24a0759f
var assignnum = []
var aroundheightmin = []
var boxmap = []
var multimesharr = []
var playerpos
var visibility_update_threshold = 4.0  # プレイヤーが移動したとみなす距離の2乗
var visibility_radius_squared = 2500.0  # 可視範囲の半径の2乗（距離50相当）
var max_height = 1.0 # 地形全体の最大高さを格納する変数
var SNOWHEIGHT = 0.75
var SEAHEIGHT = 0.0
var snowseparation = 1
# パフォーマンス向上のため、FastNoiseLiteは一度だけ初期化する
var noise = FastNoiseLite.new()
var collcnt = 0
#地形生成
func diamondsquare(amplitude=1.5):
	var size = h - 1
	
	for i in range(h):
		for j in range(w):
			map[i][j] = 0.0

	map[0][0] = -1.5
	map[0][w - 1] = -1.5
	map[h - 1][0] = -1.5
	map[h - 1][w - 1] = -1.5
	map[size/2][0] = 2
	map[size/2][size/8] = 2
	map[size/2][size/4] = 2
	map[size/2][size*3/8] = 2
	map[size/2][size/2] = 2
	amplitude *= 0.65
	size/=2
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
		amplitude *= 0.65

# --- [新規追加] 地形のなだらかな部分を平坦化する関数 ---
func smooth_terrain(passes: int, threshold: float):
	for p in range(passes):
		var read_map = []
		for i in range(h):
			read_map.append(map[i].duplicate())

		for i in range(1, h - 1):
			for j in range(1, w - 1):
				var neighbors = [
					read_map[i - 1][j - 1],read_map[i - 1][j],read_map[i - 1][j + 1],
					read_map[i][j - 1],read_map[i][j],read_map[i][j + 1],
					read_map[i + 1][j - 1],read_map[i + 1][j], read_map[i + 1][j + 1]
				]

				var max_neighbor_height = neighbors[0]
				var min_neighbor_height = neighbors[0]
				for height_val in neighbors:
					if height_val > max_neighbor_height:
						max_neighbor_height = height_val
					if height_val < min_neighbor_height:
						min_neighbor_height = height_val
				
				var height_difference = max_neighbor_height - min_neighbor_height

				if height_difference < threshold:
					var average_height = 0.0
					for height_val in neighbors:
						average_height += height_val
					map[i][j] = average_height / 9.0

func get_slope(i: int, j: int) -> float:
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

### 変更: マテリアル割り当て関数を修正
#マテリアル割り当て
<<<<<<< HEAD
func assign_material(i:int,j:int,k:int,multimesh:MultiMeshInstance3D):
	# --- マテリアル割り当てロジック (優先度順) ---
	# 1. 海
	if map3dnum[k][i][j] == 1:
		multimesh.material_override = material_water
		return

	# 2. 岩
	if map3dnum[k][i][j] == 2:
		multimesh.material_override = material_rock
		return

	# 3. 雪
	if map3dnum[k][i][j] == 3:
		multimesh.material_override = material_snow
		return

	# 4. 草
	if map3dnum[k][i][j] == 4:
		multimesh.material_override = material_grass
		
	# 5. 土
	if map3dnum[k][i][j] == 5:
		multimesh.material_override = material_dirt
=======
func assign_material(i: int, j: int, current_height: float, box: Node3D, snowheight: float):
	var mesh = box.get_node_or_null("MeshInstance3D")
	if not mesh:
		return

	# --- パラメータ ---
	var SNOW_START_HEIGHT = snowheight
	var ROCK_SLOPE_MIN = 0.55
	var ROCK_HEIGHT_FACTOR = 0.3
	
	# --- 準備 ---
	var slope = get_slope(i, j)
	var normalized_height = current_height / max_height if max_height > 0 else 0.0
	
	# --- マテリアル割り当てロジック (優先度順) ---
	
	# 1.【最優先】海
	if assignnum[i][j] == 1:
		mesh.material_override = material_water
		return

	# 2. 急な勾配は「岩」
	if assignnum[i][j] == 2:
		mesh.material_override = material_rock
		return

	# 3. 高い場所は「雪」
	if assignnum[i][j] == 3:
		mesh.material_override = material_snow
		return

	# ノイズを使い、草と土を50/50の割合でまだら模様に配置する
	if assignnum[i][j] == 4:
		mesh.material_override = material_grass
	if assignnum[i][j] == 5:
		mesh.material_override = material_dirt
>>>>>>> ba02b9fdd8400b1ed783049398999d8e24a0759f

#マップ生成
func assign_map(snowheight:float):
	# --- パラメータ ---
	var SNOW_START_HEIGHT = snowheight
	var ROCK_SLOPE_MIN = 0.55
	var ROCK_HEIGHT_FACTOR = 0.3
	
	var image = Image.create(w/2, h/2, false, Image.FORMAT_RGB8)
	for k in range(h/2):
		for l in range(w/2):
			var dirtcount = 0
			var grasscount = 0
			var rockcount = 0
			var snowcount = 0
			var watercount = 0
			var avgheight = 0.0
			
			for i in range(2):
				for j in range(2):
					var world_i = k * 2 + i
					var world_j = l * 2 + j
					var current_height = map[world_i][world_j]
					
					var slope = get_slope(world_i, world_j)
					var normalized_height = current_height / max_height if max_height > 0 else 0.0
					avgheight += normalized_height
					
					# --- マテリアル割り当てロジック (優先度順) ---
					# 1. 海
					if current_height == 0.0:
						watercount += 1
						assignnum[world_i][world_j] = 1
						continue
					
					# 2. 岩
					var rock_slope_threshold = ROCK_SLOPE_MIN - (normalized_height * ROCK_HEIGHT_FACTOR)
					if slope > rock_slope_threshold:
						rockcount += 1
						assignnum[world_i][world_j] = 2
						continue

					# 3. 雪
					if normalized_height > SNOW_START_HEIGHT:
						snowcount += 1
						assignnum[world_i][world_j] = 3
						continue

					### 変更: 残りのエリアを草と土で1:1に分割
					var n = (noise.get_noise_2d(float(world_i), float(world_j)) + 1.0) / 2.0
					if n < 0.5:
						grasscount += 1
						assignnum[world_i][world_j] = 4
					else:
						dirtcount += 1
						assignnum[world_i][world_j] = 5

			var color : Color
			avgheight /= 4
			# 最も多い種類のブロックの色をピクセルに設定
			if watercount >= max(snowcount, rockcount, grasscount, dirtcount):
				color = Color8(0, 0, 200)
			elif snowcount >= max(rockcount, grasscount, dirtcount):
				color = Color8(240, 240, 240)
			elif rockcount >= max(grasscount, dirtcount):
				color = Color8(100, 100, 100)
			elif grasscount >= dirtcount:
				color = Color8(0, 160, 0)
			else:
				color = Color8(110, 80, 50)
			
			color.a *= avgheight
			image.set_pixel(l, k, color)

	var tex = ImageTexture.create_from_image(image)
	var texture_rect = get_parent().get_node("CanvasLayer/map/TextureRect") as TextureRect
	texture_rect.texture = tex
	texture_rect.scale *= 2
	texture_rect.position = Vector2(300,100)

func _process(delta):
	var cur_pos = player.global_transform.origin
	if playerpos.distance_squared_to(cur_pos) >= visibility_update_threshold:
		playerpos = cur_pos
		#update_visibility(cur_pos)

func update_visibility(center_pos: Vector3):
	var px = int(center_pos.x)
	var py = int(center_pos.y)
	var pz = int(center_pos.z)
	var r = int(sqrt(visibility_radius_squared))
	for i in range(max(0, px - r), min(w, px + r + 1)):
		for j in range(max(0, pz - r), min(h, pz + r + 1)):
			for k in range(max(0,py - r), min(50, py + r + 1)):
				if(map3d[k][i][j]!=-1):
					boxmap[map3d[k][i][j]].visible = true

<<<<<<< HEAD
# あなたのコードのロジックを尊重し、バグ修正と高速化を行ったバージョン
func create_collision_body(voxel_data: Array) -> StaticBody3D:
	var static_body = StaticBody3D.new()
	var max_k = voxel_data.size()
	var max_i = voxel_data[0].size()
	var max_j = voxel_data[0][0].size()
	
	var mask = []
	for k in range(max_k):
		var plane_i = []
		for i in range(max_i):
			var row_j = []
			row_j.resize(max_j)
			row_j.fill(false) # false = 未処理
			plane_i.append(row_j)
		mask.append(plane_i)
		
	for k in range(max_k):
		for i in range(max_i):
			for j in range(max_j):
				if not mask[k][i][j] and voxel_data[k][i][j] != -1:
					var current_material = voxel_data[k][i][j]
					var depth = 1
					while j + depth < max_j and not mask[k][i][j + depth] and voxel_data[k][i][j + depth] == current_material:
						depth += 1
						
					var width = 1
					var done = false
					while i + width < max_i and not done:
						for l in range(depth):
							if mask[k][i + width][j + l] or voxel_data[k][i + width][j + l] != current_material:
								done = true
								break
						if not done:
							width += 1
					var height = 1
					done = false
					while k + height < max_k and not done:
						for m in range(width):
							for l in range(depth):
								if mask[k + height][i + m][j + l] or voxel_data[k + height][i + m][j + l] != current_material:
									done = true
									break
							if done: break
						if not done:
							height += 1
							
					var shape = BoxShape3D.new()
					shape.size = Vector3(width, height, depth) 
					var cshape = CollisionShape3D.new()
					cshape.shape = shape
					
					cshape.position = Vector3(i + width / 2.0,k + height / 2.0,j + depth / 2.0)
					cshape.position -= Vector3(0.5, 0.5, 0.5)
					static_body.add_child(cshape)
					for ik in range(height):
						for ii in range(width):
							for ij in range(depth):
								mask[k + ik][i + ii][j + ij] = true
	return static_body
=======
			for y in range(y_start, y_end):
				var block_pos = Vector3(i, y, j)
				if center_pos.distance_squared_to(block_pos) <= visibility_radius_squared:
					if boxmap[i][j].size() == 0:
						if diff * 0.1 >= 0.2:
							var static_body = get_parent().get_node("StaticBody3D")
							if static_body:
								var static_body_copy = static_body.duplicate(true)
								static_body_copy.position = Vector3(i, height, j)
								assign_material(i, j, current_height_map_value, static_body_copy,SNOWHEIGHT)
								get_parent().get_node("cube").add_child(static_body_copy)
								boxmap[i][j].append(static_body_copy)
							for k in range(diff):
								if static_body:
									var static_body_copy1 = static_body.duplicate(true)
									static_body_copy1.position = Vector3(i, height - k - 1, j)
									assign_material(i, j, current_height_map_value, static_body_copy1,SNOWHEIGHT)
									var mesh = static_body_copy1.get_node_or_null("MeshInstance3D")
									if(mesh.material_override == material_snow):
										mesh.material_override = material_rock
									get_parent().get_node("cube").add_child(static_body_copy1)
									boxmap[i][j].append(static_body_copy1)
						else:
							var static_body = get_parent().get_node("StaticBody3D")
							if static_body:
								var static_body_copy = static_body.duplicate(true)
								static_body_copy.position = Vector3(i, height, j)
								assign_material(i, j, current_height_map_value, static_body_copy,SNOWHEIGHT)
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
>>>>>>> ba02b9fdd8400b1ed783049398999d8e24a0759f
func _ready():
	if not player:
		push_error("Player is not defined. Check terrain right panel to set player.")
		queue_free()
		return

	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append([])

	for i in range(h):
		var row_map = []
		var row_map1 = []
		var row_around = []
		for j in range(w):
			row_map.append(0.0)
			row_map1.append(0)
			row_around.append(999999.0)
		map.append(row_map)
		assignnum.append(row_map1)
		aroundheightmin.append(row_around)
	
	for k in range(50): # 50は高さ
		var z_level_map = []
		for i in range(h):
			var row_for_z = []
			for j in range(w):
				row_for_z.append(-1) 
			z_level_map.append(row_for_z)
<<<<<<< HEAD
		map3dnum.append(z_level_map)
	
	for k in range(50):
		var z_level_map = []
		for i in range(h):
			var row_for_z = []
			for j in range(w):
				row_for_z.append(-1) 
			z_level_map.append(row_for_z)
		map3d.append(z_level_map)
	
	for k in range(50):
		var z_level_map = []
		for i in range(h):
			var row_for_z = []
			for j in range(w):
				row_for_z.append([]) 
			z_level_map.append(row_for_z)
		collisiondata.append(z_level_map)
=======
		map3d.append(z_level_map)
	
>>>>>>> ba02b9fdd8400b1ed783049398999d8e24a0759f
	diamondsquare()
	
	smooth_terrain(10, 3.5)
	
	var sea_left: float = -1e9
	var sea_right: float = 1e9
	var seablocksum = 0
	while (sea_right - sea_left > 0.01):
		var sea_mid: float = (sea_left + sea_right) / 2
		var count = 0
		for i in range(h):
			for j in range(w):
				if map[i][j] <= sea_mid:
					count += 1
		if count >= h * w / 4:
			sea_right = sea_mid
		else:
			sea_left = sea_mid
	SEAHEIGHT = sea_right
	for i in range(h):
		for j in range(w):
			if(map[i][j] <= SEAHEIGHT):
				map[i][j] = SEAHEIGHT
				seablocksum += 1
	playerpos = player.global_transform.origin
	
	var minheight_val = 1e9
	var maxheight_val = -1e9
	for i in range(h):
		for j in range(w):
			if map[i][j] > SEAHEIGHT: # 海は計算に含めない
				minheight_val = min(minheight_val, map[i][j])
			maxheight_val = max(maxheight_val, map[i][j])

	for i in range(h):
		for j in range(w):
			if map[i][j] > SEAHEIGHT:
				map[i][j] -= minheight_val
			else: # 海は0にします
				map[i][j] = 0.0
	
	maxheight_val -= minheight_val

	var snow_threshold: float = 0.0
	var heightleft: float = 0.0
	var heightright: float = maxheight_val
	while (heightright - heightleft > 0.01):
		var heightmid: float = (heightleft + heightright) / 2
		var boxsum = 0
		for i in range(h):
			for j in range(w):
				if map[i][j] > heightmid:
					boxsum += 1
		if (boxsum >= (h * w - seablocksum) / 2):
			heightleft = heightmid
		else:
			heightright = heightmid
	snow_threshold = heightleft
	
	var snowsegmentation = []
	for i in range(h):
		var arr = []
		for j in range(w):
			arr.append(-1)
		snowsegmentation.append(arr)
	var segmentnum = 0	
	var queue = []
	for i in range(h):
		for j in range(w):
			if(snowsegmentation[i][j]==-1) and (map[i][j]>snow_threshold):
				# 新しい雪の連結成分が見つかった
				queue.push_back([i,j])
				snowsegmentation[i][j] = segmentnum # 先にマークして重複を防ぐ
				
				while(len(queue)>0): # <-- ifブロックの内側に移動
					var p = queue.front()
					queue.pop_front()
					
					# 4方向の隣接ブロックを確認
					var neighbors = [[p[0]-1, p[1]], [p[0]+1, p[1]], [p[0], p[1]-1], [p[0], p[1]+1]]
					for neighbor in neighbors:
						var nx = neighbor[0]
						var ny = neighbor[1]
						# 範囲内で、まだ訪れていない雪ブロックならキューに追加
						if (nx >= 0 and nx < h and ny >= 0 and ny < w and 
							map[nx][ny] > snow_threshold and snowsegmentation[nx][ny] == -1):
							snowsegmentation[nx][ny] = segmentnum
							queue.push_back([nx, ny])
							
				segmentnum += 1 # <-- 連結成分を1つ見つけ終えたので、カウンターを増やす
	var segmentsize = []
	for i in range(segmentnum):
		segmentsize.append(0)
	for i in range(h):
		for j in range(w):
			if(snowsegmentation[i][j]==-1):
				continue
			segmentsize[snowsegmentation[i][j]] += 1
	
	var segmentmaxnum = -1e9
	var segmentmaxidx = -1
	for i in range(segmentnum):
		if(segmentsize[i]>segmentmaxnum):
			segmentmaxnum = segmentsize[i]
			segmentmaxidx = i
	for i in range(h):
		for j in range(w):
			if (snowsegmentation[i][j]==segmentmaxidx):
				map[i][j] += snowseparation
	max_height = maxheight_val + snowseparation
	SNOWHEIGHT = snow_threshold / max_height
	
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
	assign_map(SNOWHEIGHT)
	for i in range(h):
		for j in range(w):
			var height = int(floor(map[i][j]/0.1))
			var around = int(floor(aroundheightmin[i][j]/0.1))
			var diff = height-around
			for k in range(diff+1):
<<<<<<< HEAD
				map3dnum[height-k][i][j] = assignnum[i][j]
	for i in range(h):
		for j in range(w):
			var k = int(floor(map[i][j]/0.1))
			var curmap3d = map3d[k][i][j]
			var curmap3dnum = map3dnum[k][i][j]
			if(curmap3d!=-1&&curmap3dnum==-1):
				continue
			var que = Dequeue.new()
			que.push_back([i,j,k])
			multimesharr.append([])
			while not que.is_empty():
				var cur = que.pop_front()
				if(map3d[cur[2]][cur[0]][cur[1]]!=-1):
					continue
				map3d[cur[2]][cur[0]][cur[1]] = len(multimesharr)-1
				multimesharr[len(multimesharr)-1].push_back(cur)
				if(cur[0]-1>=0):
					if(map3dnum[cur[2]][cur[0]-1][cur[1]]==curmap3dnum&&map3d[cur[2]][cur[0]-1][cur[1]]==-1):
						que.push_back([cur[0]-1,cur[1],cur[2]])
				if(cur[0]+1<h):
					if(map3dnum[cur[2]][cur[0]+1][cur[1]]==curmap3dnum&&map3d[cur[2]][cur[0]+1][cur[1]]==-1):
						que.push_back([cur[0]+1,cur[1],cur[2]])
				if(cur[1]-1>=0):
					if(map3dnum[cur[2]][cur[0]][cur[1]-1]==curmap3dnum&&map3d[cur[2]][cur[0]][cur[1]-1]==-1):
						que.push_back([cur[0],cur[1]-1,cur[2]])
				if(cur[1]+1<w):
					if(map3dnum[cur[2]][cur[0]][cur[1]+1]==curmap3dnum&&map3d[cur[2]][cur[0]][cur[1]+1]==-1):
						que.push_back([cur[0],cur[1]+1,cur[2]])
				if(cur[2]-1>=0):
					if(map3dnum[cur[2]-1][cur[0]][cur[1]]==curmap3dnum&&map3d[cur[2]-1][cur[0]][cur[1]]==-1):
						que.push_back([cur[0],cur[1],cur[2]-1])
				if(cur[2]+1<len(map3dnum)):
					if(map3dnum[cur[2]+1][cur[0]][cur[1]]==curmap3dnum&&map3d[cur[2]+1][cur[0]][cur[1]]==-1):
						que.push_back([cur[0],cur[1],cur[2]+1])
	var static_body = get_parent().get_node("StaticBody3D")
	var meshinstance = static_body.get_node("MeshInstance3D")
	var template_mesh: Mesh
	template_mesh = meshinstance.mesh
	var cube = get_parent().get_node("cube")
	for k in range(len(multimesharr)):
		if multimesharr[k].is_empty():
			continue
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = template_mesh
		multimesh.instance_count = len(multimesharr[k])
		var multimeshinstance = MultiMeshInstance3D.new()
		multimeshinstance.multimesh = multimesh
		cube.add_child(multimeshinstance)
		for l in range(len(multimesharr[k])):
			var t = Transform3D()
			t.origin = Vector3(multimesharr[k][l][0],multimesharr[k][l][2],multimesharr[k][l][1])
			multimesh.set_instance_transform(l,t)
		assign_material(multimesharr[k][0][0],multimesharr[k][0][1],multimesharr[k][0][2],multimeshinstance)
	var physics_parent = Node3D.new()
	physics_parent.name = "TerrainCollision"
	add_child(physics_parent)
	static_body = create_collision_body(map3dnum)
	if static_body:
		physics_parent.add_child(static_body)
	print_debug(collcnt)
=======
				map3d[height-k][i][j] = assignnum[i][j]
			for k in range(around):
				print_debug(k)
				map3d[k][i][j] = 0
	for k in range(len(map3d)):
		for i in range(h):
			var prevnum = -1
			for j in range(w):
				if(map3d[k][i][j]==0):
					map3d[k][i][j] = prevnum
				else:
					prevnum = map3d[k][i][j]
	
>>>>>>> ba02b9fdd8400b1ed783049398999d8e24a0759f
