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
var rh = 4
var rw = 4
var collision
var map = []
var map3d = []
var collisiondata = []
var multimeshdata = []
var map3dnum = []
var assignnum = []
var aroundheightmin = []
var collisionmap = []
var multimeshmap = []
var multimesharr = []
var playerpos = Vector3(1e9,1e9,1e9)
var visiblelength = 3
var removelength = 4
var max_height = 1.0 # 地形全体の最大高さを格納する変数
var SNOWHEIGHT = 0.75
var SEAHEIGHT = 0.0
var snowseparation = 1
# パフォーマンス向上のため、FastNoiseLiteは一度だけ初期化する
var noise = FastNoiseLite.new()
var collcnt = 0
var template_mesh: Mesh
var cube_node: Node3D
var physics_parent: Node3D 
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

#地形のなだらかな部分を平坦化する関数
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

#マテリアル割り当て
func assign_material(i:int,j:int,k:int,multimesh:MultiMeshInstance3D):
	var mat_num = map3dnum[k][i][j]
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

#マップ生成
func assign_map(snowheight:float):
	# --- パラメータ ---
	var SNOW_START_HEIGHT = snowheight
	var ROCK_SLOPE_MIN = 0.55
	var ROCK_HEIGHT_FACTOR = 0.3
	
	var image = Image.create(w/2, h/2, false, Image.FORMAT_RGB8)
	for k in range(h/2+1):
		for l in range(w/2+1):
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
					if(world_i>=h||world_j>=w):
						continue
					
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
	if(int(playerpos.x/rh)!=int(cur_pos.x/rh)||int(playerpos.z/rw)!=int(cur_pos.z/rw)):
		playerpos = cur_pos
		update_visibility(cur_pos)

func update_visibility(center_pos: Vector3):
	var px = int(center_pos.x)
	var pz = int(center_pos.z)
	px/=rh
	pz/=rw
	for i in range(max(0,px-visiblelength),min(h,px+visiblelength+1)):
		for j in range(max(0, pz-visiblelength),min(w,pz+visiblelength+1)):
			if(i>=collisionmap.size()||i<0||j>=collisionmap[0].size()||j<0):
				continue
			var cube = get_parent().get_node("cube")
			if(len(collisionmap[i][j])==0&&len(collisiondata[i][j])!=0):
				var static_body = StaticBody3D.new()
				for k in range(len(collisiondata[i][j])):
					var shape = BoxShape3D.new()
					shape.size = collisiondata[i][j][k][0]
					var cshape = CollisionShape3D.new()
					cshape.shape = shape
					cshape.position = collisiondata[i][j][k][1]
					static_body.add_child(cshape)
				collisionmap[i][j].append(static_body)
				cube.add_child(static_body)
			if(len(multimeshmap[i][j])==0&&len(multimeshdata[i][j])!=0):
				var static_body = StaticBody3D.new()
				for group in multimeshdata[i][j]:
					if group.size()==0:
						continue
					var multimesh = MultiMesh.new()
					multimesh.transform_format = MultiMesh.TRANSFORM_3D
					multimesh.mesh = template_mesh
					multimesh.instance_count = group.size()
					var multimeshinstance = MultiMeshInstance3D.new()
					multimeshinstance.multimesh = multimesh
					cube.add_child(multimeshinstance)
					for k in range(group.size()):
						var blockt = group[k]
						var t = Transform3D()
						t.origin = Vector3(blockt[0],blockt[2],blockt[1])
						multimesh.set_instance_transform(k,t)
					var blockt = group[0]
					assign_material(blockt[0],blockt[1],blockt[2],multimeshinstance)
					multimeshmap[i][j].append(multimeshinstance)
	#for i in range(max(0,px-removelength), min(h,px+removelength+1)):
		#for j in range(max(0,pz-removelength), min(w,pz+removelength+1)):
			#if(i<px-removelength||i>px+removelength||j<pz-removelength||j>pz+removelength):
				#collisionmap[i][j][0].queue_free()
				#multimeshmap[i][j][0].queue_free()
				#collisionmap[i][j].pop_back()
				#multimeshmap[i][j].pop_back()

#コリジョンを生成する関数
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
		for i1 in range(collisiondata.size()):
			for j1 in range(collisiondata[0].size()):
				for i in range(rh):
					if(i1*rh+i>=h):
						continue
					for j in range(rw):
						if(j1*rw+j>=w):
							continue
						if not mask[k][i1*rh+i][j1*rw+j] and voxel_data[k][i1*rh+i][j1*rw+j] != -1:
							var current_material = voxel_data[k][i1*rh+i][j1*rw+j]
							var depth = 1
							while j1*rw+j+depth<w and j+depth<rw and not mask[k][int(i1*rh+i)][int(j1*rw+j+depth)] and voxel_data[k][int(i1*rh+i)][int(j1*rw+j+depth)] == current_material:
								depth += 1
						
							var width = 1
							var done = false
							while i1*rh+i+width<h and i+width<rh and not done:
								for l in range(depth):
									if mask[k][i1*rh+i+width][j1*rw+j+l] or voxel_data[k][i1*rh+i+width][j1*rw+j+l] != current_material:
										done = true
										break
								if not done:
									width += 1
							var height = 1
							done = false
							while k + height < max_k and not done:
								for m in range(width):
									for l in range(depth):
										if mask[k+height][i1*rh+i+m][j1*rw+j+l] or voxel_data[k+height][i1*rh+i+m][j1*rw+j+l] != current_material:
											done = true
											break
									if done: break
								if not done:
									height += 1
							var shape = BoxShape3D.new()
							shape.size = Vector3(width, height, depth) 
							var cshape = CollisionShape3D.new()
							cshape.shape = shape
							cshape.position = Vector3(int(i1*rh+i)+width/2.0,k+height/2.0,int(j1*rw+j)+depth/2.0)
							cshape.position -= Vector3(0.5, 0.5, 0.5)
							collisiondata[i1][j1].append([shape.size,cshape.position])
							for ik in range(height):
								for ii in range(width):
									for ij in range(depth):
										mask[k+ik][i1*rh+i+ii][j1*rw+j+ij] = true
	return

func create_multimesh_body(voxel_data: Array) -> StaticBody3D:
	for i1 in range(multimeshdata.size()):
		for j1 in range(multimeshdata[0].size()):
			for i in range(rh):
				if(i1*rh+i>=h):
					continue
				for j in range(rw):
					if(j1*rw+j>=w):
						continue
					var k = int(floor(map[i1*rh+i][j1*rw+j]/0.1))
					var curmap3d = map3d[k][i1*rh+i][j1*rw+j]
					var curmap3dnum = map3dnum[k][i1*rh+i][j1*rw+j]
					if curmap3d != -1 or curmap3dnum == -1:
						continue
					var que = Dequeue.new()
					que.push_back([i1*rh+i,j1*rw+j,k])
					multimeshdata[i1][j1].append([])
					while not que.is_empty():
						var cur = que.pop_front()
						if(map3d[cur[2]][cur[0]][cur[1]]!=-1):
							continue
						map3d[cur[2]][cur[0]][cur[1]] = len(multimeshdata[i1][j1])-1
						multimeshdata[i1][j1][len(multimeshdata[i1][j1])-1].push_back(cur)
						if(cur[0]-1>=0&&cur[0]-1>=i1*rh):
							if(map3dnum[cur[2]][cur[0]-1][cur[1]]==curmap3dnum&&map3d[cur[2]][cur[0]-1][cur[1]]==-1):
								que.push_back([cur[0]-1,cur[1],cur[2]])
						if(cur[0]+1<h&&cur[0]+1<(i1+1)*rh):
							if(map3dnum[cur[2]][cur[0]+1][cur[1]]==curmap3dnum&&map3d[cur[2]][cur[0]+1][cur[1]]==-1):
								que.push_back([cur[0]+1,cur[1],cur[2]])
						if(cur[1]-1>=0&&cur[1]-1>=j1*rw):
							if(map3dnum[cur[2]][cur[0]][cur[1]-1]==curmap3dnum&&map3d[cur[2]][cur[0]][cur[1]-1]==-1):
								que.push_back([cur[0],cur[1]-1,cur[2]])
						if(cur[1]+1<w&&cur[1]+1<(j1+1)*rw):
							if(map3dnum[cur[2]][cur[0]][cur[1]+1]==curmap3dnum&&map3d[cur[2]][cur[0]][cur[1]+1]==-1):
								que.push_back([cur[0],cur[1]+1,cur[2]])
						if(cur[2]-1>=0):
							if(map3dnum[cur[2]-1][cur[0]][cur[1]]==curmap3dnum&&map3d[cur[2]-1][cur[0]][cur[1]]==-1):
								que.push_back([cur[0],cur[1],cur[2]-1])
						if(cur[2]+1<len(map3dnum)):
							if(map3dnum[cur[2]+1][cur[0]][cur[1]]==curmap3dnum&&map3d[cur[2]+1][cur[0]][cur[1]]==-1):
								que.push_back([cur[0],cur[1],cur[2]+1])
	return 
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
		map3dnum.append(z_level_map)
	
	for k in range(50):
		var z_level_map = []
		for i in range(h):
			var row_for_z = []
			for j in range(w):
				row_for_z.append(-1) 
			z_level_map.append(row_for_z)
		map3d.append(z_level_map)
	var chunkh = h/rh
	var chunkw = w/rw
	if(chunkw*rw<w):
		chunkw+=1
	if(chunkh*rh<h):
		chunkh+=1
	for i in range(chunkh):
		var row_for_z = []
		for j in range(chunkw):
			row_for_z.append([])
		collisiondata.append(row_for_z)
	for i in range(chunkh):
		var row_for_z = []
		for j in range(chunkw):
			row_for_z.append([])
		multimeshdata.append(row_for_z)
	for i in range(collisiondata.size()):
		var row_for_z = []
		for j in range(collisiondata[0].size()):
			row_for_z.append([])
		collisionmap.append(row_for_z)
	for i in range(chunkh):
		var row_for_z = []
		for j in range(chunkw):
			row_for_z.append([])
		multimeshmap.append(row_for_z)
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
				map3dnum[height-k][i][j] = assignnum[i][j]
	print(collisiondata.size())
	template_mesh = get_parent().get_node("StaticBody3D/MeshInstance3D").mesh
	create_multimesh_body(map3dnum)
	create_collision_body(map3dnum)
	
