extends Node3D

@export var player : Node3D
@export var material_snow : Material = preload("res://texture/snow/material_snow.tres")
@export var material_rock : Material = preload("res://texture/rock/material_rock.tres")
@export var material_grass : Material = preload("res://texture/grass/material_grass.tres")
@export var material_dirt : Material = preload("res://texture/dirt/material_dirt.tres")
@export var material_water : Material = preload("res://texture/water/material_water.tres")
@export var CAVE_MIN_SIZE = 8
@export var CAVE_EXTRA_EDGES = 3
@export var CAVE_HEIGHT = 5
@export var CAVE_AUTOMATON_STEPS = 5
@export_range(0.5, 1.0, 0.05) var CAVE_ENTRANCE_SOLIDITY_REQUIREMENT: float = 0.8
@export var castle_path: String = "res://model/castle/castle.glb"
var exp = 6
var h:int = pow(2, exp) + 1
var w:int = pow(2, exp) + 1
var worldh = h*2
var worldw = w*4
var plane_start_h:int = h/2
var plane_start_w:int = w*3/2
var desert_start_h:int = h/2
var desert_start_w:int = w/2
var cave_start_h:int = h/2
var cave_start_w:int = w
var castle_start_h:int = h/2
var castle_start_w:int = w*5/2
var d = 90
var entrance_width_radius: float = 3.0
var entrance_height_radius: float = 3.0
var castle_width_length = h/4*3
var castle_height_length = w/4*3
var battle_height = 10
var battle_width = 10
var rh = 32
var rw = 32
var collision
var map = []
var map3d = []
var collisiondata = []
var multimeshdata = []
var map3dnum = []
var nearest_ground = []
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
var bsp_leaf_nodes: Array = []
var dungeon_grid: Array = []
var plane_battle_pos:Vector3
var cave_battle_pos:Vector3
var desert_battle_pos:Vector3
var snow_battle_pos:Vector3
#地形生成
func diamondsquare(map:Array,amplitude=1.5)->Array:
	var size = h - 1
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
	return map
#地形のなだらかな部分を平坦化する関数
func smooth_terrain(passes: int, threshold: float,map:Array):
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

func get_slope(i: int, j: int,map:Array) -> float:
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

class rectangle:
	var x:int
	var y:int
	var w:int
	var h:int
	func _init(_x,_y,_w,_h):
		x = _x
		y = _y
		w = _w
		h = _h

class edge:
	var u:int
	var v:int
	var w:int
	func _init(u,v,w):
		self.u = u
		self.v = v
		self.w = w
class dsu:
	var parent = []
	var rank = []
	func _init(n):
		parent.resize(n)
		rank.resize(n)
		for i in range(n):
			parent[i] = i
			rank[i] = 0
	func find(x):
		if parent[x] != x:
			parent[x] = find(parent[x])
		return parent[x]
	func union(x,y):
		var rx = find(x)
		var ry = find(y)
		if rx == ry:
			return false
		if rank[rx]<rank[ry]:
			parent[rx] = ry
		elif rank[rx]>rank[ry]:
			parent[ry] = rx
		else:
			parent[ry] = rx
			rank[rx] += 1
		return true
		
func kruskal(n:int,edges:Array)->Array:
	edges.sort_custom(func(a,b):return a.w<b.w)
	var dsu = dsu.new(n)
	var mst = []
	var total_cost = 0
	for e in edges:
		if dsu.union(e.u,e.v):
			mst.append(e)
			total_cost += e.w
	return mst
	
func bsp(rect:rectangle,min_size:int)->Array:
	var result = []
	if rect.w<min_size*2 and rect.h<min_size*2:
		result.append(rect)
		return result
	 
	var horizontal = false
	if rect.w > rect.h and rect.w >= min_size*2:
		horizontal = false
	elif rect.h > rect.w and rect.h >= min_size*2:
		horizontal = true
	else:
		horizontal = randi()%2 == 0
	if horizontal and rect.h >= min_size*2:
		var cut = randf_range(min_size,rect.h-min_size)
		var r1 = rectangle.new(rect.x,rect.y,rect.w,cut)
		var r2 = rectangle.new(rect.x,rect.y+cut,rect.w,rect.h-cut)
		result.append_array(bsp(r1,min_size))
		result.append_array(bsp(r2,min_size))
	elif not horizontal and rect.w > min_size*2:
		var cut = randf_range(min_size,rect.w-min_size)
		var r1 = rectangle.new(rect.x,rect.y,cut,rect.h)
		var r2 = rectangle.new(rect.x+cut,rect.y,rect.w-cut,rect.h)
		result.append_array(bsp(r1,min_size))
		result.append_array(bsp(r2,min_size))
	else:
		result.append(rect)
	return result
func make_graph(cells:Array)->Dictionary:
	var graph = {}
	for i in range(cells.size()):
		graph[i] = []
		for j in range(cells.size()):
			if i!=j and cells[i].intersects(cells[j]):
				graph[i].append(j)
	return graph

func make_room(cell:rectangle,map:Array,min_size:int=10)->rectangle:
	var width
	if cell.w > min_size:
		width = randi()%(cell.w-min_size)+min_size
	else:
		width = cell.w
	var height
	if cell.h > min_size:
		height = randi()%(cell.h-min_size)+min_size
	else:
		height = cell.h
	var x
	if cell.w > width:
		x = cell.x+randi()%(cell.w-width)
	else:
		x = cell.x		
	var y
	if cell.h > height:
		y = cell.y+randi()%(cell.h-height)
	else:
		y = cell.y
	for i in range(y,y+height):
		for j in range(x,x+width):
			map[i][j] = -1
	return rectangle.new(x,y,width,height)

func make_corridor(map:Array,p1:Vector2,p2:Vector2,wide:int):
	if randf() < 0.5:
		for x in range(min(p1.x,p2.x),max(p1.x,p2.x)+1):
			for k in range(-wide,wide+1):
				if p1.y+k >= 0 and p1.y+k < map[0].size():
					if map[p1.y+k][x] != 1:
						map[p1.y+k][x] = 0
		for y in range(min(p1.y,p2.y),max(p1.y,p2.y)+1):
			for k in range(-wide,wide+1):
				if p2.x+k >= 0 and p2.x+k < map.size():
					if map[y][p2.x+k] != 1:
						map[y][p2.x+k] = 0
	else:
		for y in range(min(p1.y,p2.y),max(p1.y,p2.y)+1):
			for k in range(-wide,wide+1):
				if p1.x+k >= 0 and p1.x+k < map.size():
					if map[y][p1.x+k] != 1:
						map[y][p1.x+k] = 0
		for x in range(min(p1.x,p2.x),max(p1.x,p2.x)+1):
			for k in range(-wide,wide+1):
				if p2.y+k >= 0 and p2.y+k < map[0].size():
					if map[p2.y+k][x] != 1:
						map[p2.y+k][x] = 0

func cell_automaton(map:Array,num:int,steps:int=1):
	for i in range(steps):
		var nmap = map.duplicate(true)
		for y in range(map.size()):
			for x in range(map[0].size()):
				if map[y][x] == 0:
					continue
				var wallcnt = 0
				for dy in range(-1,2):
					for dx in range(-1,2):
						if dx == 0 and dy == 0:
							continue
						var ny = y+dy
						var nx = x+dx
						if ny < 0 or nx < 0 or ny >= map.size() or nx >= map[0].size():
							wallcnt += 1
						elif map[ny][nx] == num:
							wallcnt += 1
				if wallcnt > 4:
					nmap[y][x] = num
				else:
					nmap[y][x] = -1
		map = nmap
	return map

func bfs(map:Array) -> Array:
	var labels = []
	for y in range(map.size()):
		labels.append([])
		for x in range(map[0].size()):
			labels[y].append(-1)
	
	var id = 0
	for y in range(map.size()):
		for x in range(map[0].size()):
			if map[y][x] == -1 and labels[y][x] == -1:
				var queue = [Vector2(x,y)]
				while queue.size()>0:
					var p = queue.pop_front()
					if labels[p.y][p.x] != -1:
						continue
					labels[p.y][p.x] = id
					if p.x-1>=0 :
						if map[p.y][p.x-1]==-1 and labels[p.y][p.x-1] == -1:
							queue.append(Vector2(p.x-1,p.y))
					if p.y-1>=0 :
						if map[p.y-1][p.x]==-1 and labels[p.y-1][p.x] == -1:
							queue.append(Vector2(p.x,p.y-1))
					if p.x+1<map[0].size():
						if map[p.y][p.x+1]==-1 and labels[p.y][p.x+1] == -1:
							queue.append(Vector2(p.x+1,p.y))
					if p.y+1<map.size() :
						if map[p.y+1][p.x]==-1 and labels[p.y+1][p.x] == -1:
							queue.append(Vector2(p.x,p.y+1))
				id += 1
	return labels
func generate_cave(width:int,height:int,floorheightmi:int,min_size:int=15):
	var cavemap = []
	var caves = []
	for y in range(height):
		cavemap.append([])
		for x in range(width):
			cavemap[y].append(5)
	var root = rectangle.new(0,0,width,height)
	var cells = bsp(root,min_size)
	var rooms = []
	for i in range(cells.size()):
		rooms.append(make_room(cells[i],cavemap))
	for i in range(cells.size()):
		for y in range(cells[i].y+cells[i].h/4,cells[i].y+cells[i].h*3/4):
			for x in range(cells[i].x+cells[i].w/4,cells[i].x+cells[i].w*3/4):
				if cavemap[y][x]==-1:
					cavemap[y][x] = 0
	var edges = []
	for i in range(rooms.size()):
		for j in range(i+1,rooms.size()):
			var dx = rooms[i].x-rooms[j].x
			var dy = rooms[i].y-rooms[j].y
			var dist = int(sqrt(dx*dx+dy*dy))
			edges.append(edge.new(i,j,dist))
	
	var mst = kruskal(rooms.size(),edges)
	for i in range(randi()%5+1):
		mst.append(edges[randi()%edges.size()])
	
	for i in range(mst.size()):
		var r1 = rooms[mst[i].u]
		var r2 = rooms[mst[i].v]
		var p1 = Vector2(r1.x+r1.w/2,r1.y+r1.h/2)
		var p2 = Vector2(r2.x+r2.w/2,r2.y+r2.h/2)
		make_corridor(cavemap,p1,p2,0)
	
	for y in range(1,height-1):
		for x in range(1,width-1):
			if (cavemap[y][x] == -1 or cavemap[y][x] == 1) and randf() < 0.1:
				cavemap[y+randi_range(-1,1)][x+randi_range(-1,1)] = -1
	
	for y in range(height):
		for x in range(width):
			if y == 0 or x == 0 or y == height-1 or x == width-1:
				cavemap[y][x] = 5
	for i in range(5):
		cavemap = cell_automaton(cavemap,5)
	caves.append(cavemap)
	for i in range(29-floorheightmi):
		if i%2 == 1:
			caves.append(cell_automaton(caves[i],5))
		else:
			caves.append(caves[i])
	for i in range(10):
		for y in range(height):
			for x in range(width):
				if y == 0 or x == 0 or y == height-1 or x == width-1:
					caves[i][y][x] = 5
		for y in range(1,height-1):
			for x in range(1,width-1):
				if caves[i][y][x] == 0:
					caves[i][y][x] = -1
		var labels = bfs(caves[i])
		var counts = {}
		for y in range(height):
			for x in range(width):
				var id = labels[y][x]
				if id != -1:
					counts[id] = counts.get(id,0)+1
		
		var max_id = -1
		var max_count = -1
		for id in counts.keys():
			if counts[id] > max_count:
				max_count = counts[id]
				max_id = id
					
		for y in range(height):
			for x in range(width):
				if labels[y][x] != max_id:
					caves[i][y][x] = 5
		for y in range(height):
			for x in range(width):
				if y == 0 or x == 0 or y == height-1 or x == width-1:
					caves[i][y][x] = 5
	return caves
func find_cave_entrance(sth:int,stw:int,map:Array):
	var candidates = []
	var rock_acc = []
	for k in range(d):
		var arrhw = []
		for i in range(h):
			var arrw = []
			for j in range(w):
				arrw.append(0)
			arrhw.append(arrw)
		rock_acc.append(arrhw)
	for k in range(d):
		for i in range(h):
			for j in range(w):
				if map3dnum[k][i+sth][j+stw] == 2:
					rock_acc[k][i][j] += 1
	for k in range(d):
		for j in range(w):
			for i in range(h-1):
				rock_acc[k][i+1][j] += rock_acc[k][i][j]
	for k in range(d):
		for i in range(h):
			for j in range(w-1):
				rock_acc[k][i][j+1] += rock_acc[k][i][j]
	for i in range(h):
		for j in range(w):
			for k in range(d-1):
				rock_acc[k+1][i][j] += rock_acc[k][i][j]
	for y in range(30,d):
		for x in range(h):
			for z in range(w):
				if map3dnum[y][x+sth][z+stw] != 2:
					continue
				if map3dnum[y-entrance_height_radius-1][x+sth][z+stw] != -1:
					continue
				if x+entrance_width_radius < h and x-entrance_width_radius >= 0 and y+entrance_height_radius < d and y-entrance_height_radius >= 0 and z+1 < w and z-1 >= 0:
					if map3dnum[y-entrance_height_radius][x+sth][y+stw] != 2:
						continue
					var rock_sum = 0
					var lx = int(x-entrance_width_radius)
					var ly = int(y-entrance_height_radius)
					var lz = z-1
					var rx = int(x+entrance_width_radius)
					var ry = int(y+entrance_height_radius)
					var rz = z+1
					rock_sum += rock_acc[ry][rx][rz]
					if ly-1 >= 0:
						rock_sum -= rock_acc[ly-1][rx][rz]
					if lx-1 >= 0:
						rock_sum -= rock_acc[ry][lx-1][rz]
					if lz-1 >= 0:
						rock_sum -= rock_acc[ry][rx][lz-1]
					if lx-1 >= 0 and ly-1 >= 0:
						rock_sum += rock_acc[ly-1][lx-1][rz]
					if lx-1 >= 0 and lz-1 >= 0:
						rock_sum += rock_acc[ry][lx-1][lz-1]
					if ly-1 >= 0 and lz-1 >= 0:
						rock_sum += rock_acc[ly-1][rx][lz-1]
					if lx-1 >= 0 and ly-1 >= 0 and lz-1 >= 0:
						rock_sum -= rock_acc[ly-1][lx-1][lz-1]
					if (entrance_width_radius*2-1)*(entrance_height_radius*2-1) <= rock_sum:			
						if  map[x][z-1] < map[x][z] || map[x][z] < map[x][z+1]:
							candidates.append([Vector3i(x+sth,y,z+stw),0,1])
						else:
							candidates.append([Vector3i(x+sth,y,z+stw),0,0])
				if x+1 < h and x-1 >= 0 and y+entrance_height_radius < d and y-entrance_height_radius >= 0 and z+entrance_width_radius < w and z-entrance_width_radius >= 0:
					var rock_sum = 0
					var lx = x-1
					var ly = int(y-entrance_height_radius)
					var lz = int(z-entrance_width_radius)
					var rx = x+1
					var ry = int(y+entrance_height_radius)
					var rz = int(z+entrance_width_radius)
					rock_sum += rock_acc[ry][rx][rz]
					if ly-1 >= 0:
						rock_sum -= rock_acc[ly-1][rx][rz]
					if lx-1 >= 0:
						rock_sum -= rock_acc[ry][lx-1][rz]
					if lz-1 >= 0:
						rock_sum -= rock_acc[ry][rx][lz-1]
					if lx-1 >= 0 and ly-1 >= 0:
						rock_sum += rock_acc[ly-1][lx-1][rz]
					if lx-1 >= 0 and lz-1 >= 0:
						rock_sum += rock_acc[ry][lx-1][lz-1]
					if ly-1 >= 0 and lz-1 >= 0:
						rock_sum += rock_acc[ly-1][rx][lz-1]
					if lx-1 >= 0 and ly-1 >= 0 and lz-1 >= 0:
						rock_sum -= rock_acc[ly-1][lx-1][lz-1]
					if (entrance_width_radius*2-1)*(entrance_height_radius*2-1) <= rock_sum:
						if  map[x-1][z] < map[x][z] or map[x][z] < map[x+1][z]:
							candidates.append([Vector3i(x+sth,y,z+stw),1,1])
						else:
							candidates.append([Vector3i(x+sth,y,z+stw),1,0])
						
	if candidates.is_empty():
		print("ERROR: No suitable and accessible cave entrance location found.")
		return null
		
	return candidates.pick_random()
								
func find_longest_point(cave:Array,st:Vector2i,num:int)->Vector2i:
	var dist = cave.duplicate(true)
	var caveh = cave.size()
	var cavew = cave[0].size()
	for i in range(caveh):
		for j in range(cavew):
			dist[i][j] = 1e9
	dist[st.x][st.y] = 0
	var que = Dequeue.new()
	que.push_back(st.x*cavew+st.y)
	while que.size() > 0:
		var q = que.peek_front()
		que.pop_front()
		var i = q/cavew
		var j = q%cavew
		if i-1 >= 0:
			if cave[i-1][j] != num and dist[i-1][j] > dist[i][j]+1:
				dist[i-1][j] = dist[i][j]+1
				que.push_back((i-1)*cavew+j)
		if i+1 < caveh:
			if cave[i+1][j] != num and dist[i+1][j] > dist[i][j]+1:
				dist[i+1][j] = dist[i][j]+1
				que.push_back((i+1)*cavew+j)
		if j-1 >= 0:
			if cave[i][j-1] != num and dist[i][j-1] > dist[i][j]+1:
				dist[i][j-1] = dist[i][j]+1
				que.push_back(i*cavew+j-1)
		if j+1 < cavew:
			if cave[i][j+1] != num and dist[i][j+1] > dist[i][j]+1:
				dist[i][j+1] = dist[i][j]+1
				que.push_back(i*cavew+j+1)
	var px = -1
	var py = -1
	var cur = -1
	for i in range(caveh):
		for j in range(cavew):
			if dist[i][j] == 1e9:
				continue
			if cur < dist[i][j]:
				cur = dist[i][j]
				px = i
				py = j
	return Vector2i(px,py)
	
func assign_num(snowheight:float,assignnum:Array,map:Array,max_height:float)->Array:
	# --- パラメータ ---
	var SNOW_START_HEIGHT = snowheight
	var ROCK_SLOPE_MIN = 0.55
	var ROCK_HEIGHT_FACTOR = 0.3
	for i in range(h):
		for j in range(w):
			if(i>=h||j>=w):
				continue
			
			var current_height = map[i][j]
			
			var slope = get_slope(i,j,map)
			var normalized_height = current_height / max_height if max_height > 0 else 0.0
			
			# --- マテリアル割り当てロジック (優先度順) ---
			# 1. 海
			if current_height == 0.0:
				assignnum[i][j] = 1
				continue
			
			# 2. 岩
			var rock_slope_threshold = ROCK_SLOPE_MIN - (normalized_height * ROCK_HEIGHT_FACTOR)
			if slope > rock_slope_threshold:
				assignnum[i][j] = 2
				continue

			# 3. 雪
			if normalized_height > SNOW_START_HEIGHT:
				assignnum[i][j] = 3
				continue

			### 変更: 残りのエリアを草と土で1:1に分割
			var n = (noise.get_noise_2d(float(i), float(j)) + 1.0) / 2.0
			if n < 0.5:
				assignnum[i][j] = 4
			else:
				assignnum[i][j] = 5

	return assignnum

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
func assign_aroundheightmin(aroundheightmin:Array,map:Array)->Array:
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
	return aroundheightmin
	
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
					if(i1*rh+i>=worldh):
						continue
					for j in range(rw):
						if(j1*rw+j>=worldw):
							continue
						if not mask[k][i1*rh+i][j1*rw+j] and voxel_data[k][i1*rh+i][j1*rw+j] != -1:
							var current_material = voxel_data[k][i1*rh+i][j1*rw+j]
							var depth = 1
							while j1*rw+j+depth<worldw and j+depth<rw and not mask[k][int(i1*rh+i)][int(j1*rw+j+depth)] and voxel_data[k][int(i1*rh+i)][int(j1*rw+j+depth)] == current_material:
								depth += 1
						
							var width = 1
							var done = false
							while i1*rh+i+width<worldh and i+width<rh and not done:
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
	for k in range(voxel_data.size()):
		for i1 in range(multimeshdata.size()):
			for j1 in range(multimeshdata[0].size()):
				for i in range(rh):
					if(i1*rh+i>=worldh):
						continue
					for j in range(rw):
						if(j1*rw+j>=worldw):
							continue
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
							if(cur[0]+1<worldh&&cur[0]+1<(i1+1)*rh):
								if(map3dnum[cur[2]][cur[0]+1][cur[1]]==curmap3dnum&&map3d[cur[2]][cur[0]+1][cur[1]]==-1):
									que.push_back([cur[0]+1,cur[1],cur[2]])
							if(cur[1]-1>=0&&cur[1]-1>=j1*rw):
								if(map3dnum[cur[2]][cur[0]][cur[1]-1]==curmap3dnum&&map3d[cur[2]][cur[0]][cur[1]-1]==-1):
									que.push_back([cur[0],cur[1]-1,cur[2]])
							if(cur[1]+1<worldw&&cur[1]+1<(j1+1)*rw):
								if(map3dnum[cur[2]][cur[0]][cur[1]+1]==curmap3dnum&&map3d[cur[2]][cur[0]][cur[1]+1]==-1):
									que.push_back([cur[0],cur[1]+1,cur[2]])
							if(cur[2]-1>=0):
								if(map3dnum[cur[2]-1][cur[0]][cur[1]]==curmap3dnum&&map3d[cur[2]-1][cur[0]][cur[1]]==-1):
									que.push_back([cur[0],cur[1],cur[2]-1])
							if(cur[2]+1<len(map3dnum)):
								if(map3dnum[cur[2]+1][cur[0]][cur[1]]==curmap3dnum&&map3d[cur[2]+1][cur[0]][cur[1]]==-1):
									que.push_back([cur[0],cur[1],cur[2]+1])
	return 
func assign_maze_entrance(maze_start:Vector2i,floor:Array,floorheightmin:Array,caves:Array):
	var mazeentrance_candidate = []
	var height = int(floor(floor[maze_start.x][maze_start.y]/0.1))
	var around = int(floor(floorheightmin[maze_start.x][maze_start.y]/0.1))
	var diff = height-around
	if caves[maze_start.x-1][maze_start.y] == 5 and caves[maze_start.x][maze_start.y-1] == 5:
		mazeentrance_candidate.append([Vector3(maze_start.x-1,height-diff+10+entrance_height_radius,maze_start.y+entrance_width_radius),1,0])
		mazeentrance_candidate.append([Vector3(maze_start.x+entrance_width_radius,height-diff+10+entrance_height_radius,maze_start.y-1),0,0])
	if caves[maze_start.x+1][maze_start.y] == 5 and caves[maze_start.x][maze_start.y+1] == 5:
		mazeentrance_candidate.append([Vector3(maze_start.x+1,height-diff+10+entrance_height_radius,maze_start.y-entrance_width_radius),1,1])
		mazeentrance_candidate.append([Vector3(maze_start.x-entrance_width_radius,height-diff+10+entrance_height_radius,maze_start.y+1),0,1])
	if caves[maze_start.x-1][maze_start.y] == 5 and caves[maze_start.x][maze_start.y+1] == 5:
		mazeentrance_candidate.append([Vector3(maze_start.x-1,height-diff+10+entrance_height_radius,maze_start.y-entrance_width_radius),1,0])
		mazeentrance_candidate.append([Vector3(maze_start.x+entrance_width_radius,height-diff+10+entrance_height_radius,maze_start.y+1),0,1])
	if caves[maze_start.x+1][maze_start.y] == 5 and caves[maze_start.x][maze_start.y-1] == 5:
		mazeentrance_candidate.append([Vector3(maze_start.x+1,height-diff+10+entrance_height_radius,maze_start.y+entrance_width_radius),1,1])
		mazeentrance_candidate.append([Vector3(maze_start.x-entrance_width_radius,height-diff+10+entrance_height_radius,maze_start.y-1),0,0])
	return mazeentrance_candidate.pick_random()
func get_direction(ax:int,pol:int)->Vector3:
	if ax == 0:
		return Vector3(0,0,1) if pol == 0 else Vector3(0,0,-1)
	else:
		return Vector3(1,0,0) if pol == 0 else Vector3(-1,0,0)
func bezie_curve(p0:Vector3,p1:Vector3,p2:Vector3,p3:Vector3,t:float)->Vector3:
	var u = 1.0-t
	var t2 = t*t
	var u2 = u*u
	var u3 = u2*u
	var t3 = t2*t
	var point = u3*p0
	point += 3*u2*t*p1
	point += 3*u*t2*p2
	point += t3*p3
	return point
func carve_tunnel(p0:Vector3,p1:Vector3,p2:Vector3,p3:Vector3):
	var steps = 15000
	var widthr = entrance_width_radius
	var heightr = entrance_height_radius
	var dirt_pad = 1
	for i in range(steps+1):
		var t = float(i)/steps
		var p_cur = bezie_curve(p0,p1,p2,p3,t)
		var p_next = bezie_curve(p0,p1,p2,p3,t+0.001)
		var tan = (p_next-p_cur).normalized()
		var right = tan.cross(Vector3.UP).normalized()
		var up = right.cross(tan).normalized()
		var wholew = int(widthr+dirt_pad)
		var wholeh = int(heightr+dirt_pad)
		for j in range(-wholew,wholew+1):
			for k in range(-wholeh,wholeh+1):
				var worldpos_f = p_cur+(right*j)+(up*k)
				var worldpos = Vector3i(round(worldpos_f.x),round(worldpos_f.y),round(worldpos_f.z))
				if worldpos.x < 0 or worldpos.x >= worldh or worldpos.y < 0 or worldpos.y >= d or worldpos.z < 0 or worldpos.z >= worldw:
					continue
				var isin = false
				if (float(j/widthr))**2+(float(k/heightr))**2 < 1:
					isin = true
				if isin:
					map3dnum[worldpos.y][worldpos.x][worldpos.z] = -1
				else:
					map3dnum[worldpos.y][worldpos.x][worldpos.z] = 5
func make_tunnel(caveentrance:Array,mazeentrance:Array):
	var p0 = Vector3(caveentrance[0])	
	var p3 = Vector3(mazeentrance[0]+Vector3(cave_start_h,0,cave_start_w))
	var p0dir = get_direction(caveentrance[1],caveentrance[2])
	var p3dir = get_direction(mazeentrance[1],mazeentrance[2])
	var horizontal_distance = (p0*Vector3(1,0,1)).distance_to(p3*Vector3(1,0,1))
	var threshold = entrance_width_radius*4.0
	var curve_depth = p0.distance_to(p3) / 3.0
	p0 += p0dir*4
	p3 += p3dir*3
	var	p1 = (p0-p0dir*2*curve_depth)-Vector3(0,curve_depth*0.75,0)
	var	p2 = (p3-p3dir*2*curve_depth)+Vector3(0,curve_depth*0.75,0)
	
	carve_tunnel(p0,p1,p2,p3)

func sea(map:Array,n:int = 4):
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
		if count >= h * w / n:
			sea_right = sea_mid
		else:
			sea_left = sea_mid
	SEAHEIGHT = sea_right
	for i in range(h):
		for j in range(w):
			if(map[i][j] <= SEAHEIGHT):
				map[i][j] = SEAHEIGHT
				
	return [map,seablocksum]
func snow_leveling(map:Array):
	var sum = []
	var sum_height = []
	var battle_point_candidate = []
	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append(0)
		sum.append(arrw)
	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append(0)
		sum_height.append(arrw)
	for i in range(h):
		for j in range(w):
			sum_height[i][j] = map[i][j]
			if i-2 < 0 or i+2 >= h or j-2 < 0 or j+2 >= w:
				continue
			if map[i-1][j] <= SNOWHEIGHT:
				continue
			if map[i-2][j] <= SNOWHEIGHT:
				continue
			if map[i+1][j] <= SNOWHEIGHT:
				continue
			if map[i+2][j] <= SNOWHEIGHT:
				continue
			if map[i][j-1] <= SNOWHEIGHT:
				continue
			if map[i][j-2] <= SNOWHEIGHT:
				continue
			if map[i][j+1] <= SNOWHEIGHT:
				continue
			if map[i][j+2] <= SNOWHEIGHT:
				continue
			if map[i][j] <= SNOWHEIGHT:
				continue
			if map[i+1][j+1] <= SNOWHEIGHT:
				continue
			if map[i+1][j-1] <= SNOWHEIGHT:
				continue
			if map[i-1][j-1] <= SNOWHEIGHT:
				continue
			if map[i-1][j+1] <= SNOWHEIGHT:
				continue
			sum[i][j] = 1
	for i in range(h):
		for j in range(w-1):
			sum[i][j+1] += sum[i][j]
			sum_height[i][j+1] += sum_height[i][j]
	for j in range(w):
		for i in range(h-1):
			sum[i+1][j] += sum[i][j]
			sum_height[i+1][j] += sum_height[i][j]
	for i in range(h):
		for j in range(w):
			var can_set = true
			var cursum = 0;
			var cur_height = 0;
			if i+battle_height-1 >= h:
				continue
			if j+battle_width-1 >= w:
				continue
			cursum += sum[i+battle_height-1][j+battle_width-1]
			cur_height += sum_height[i+battle_height-1][j+battle_width-1]
			if i-1 >= 0:
				cursum -= sum[i-1][j+battle_width-1]
				cur_height -= sum_height[i-1][j+battle_width-1]
			if j-1 >= 0:
				cursum -= sum[i+battle_height-1][j-1]
				cur_height -= sum_height[i+battle_height-1][j-1]
			if i-1 >= 0 and j-1 >= 0:
				cursum += sum[i-1][j-1]
				cur_height += sum_height[i-1][j-1]
			if cursum == battle_height*battle_width:
				battle_point_candidate.append([i,j,cur_height])
	var res = battle_point_candidate.pick_random()
	for i in range(battle_height):
		for j in range(battle_width):
			map[res[0]+i][res[1]+j] = float(res[2]/(battle_height*battle_width))
	return [map,res[0],res[1]]
func plane_leveling(map:Array):
	var sum = []
	var sum_height = []
	var battle_point_candidate = []
	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append(0)
		sum.append(arrw)
	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append(0)
		sum_height.append(arrw)
	for i in range(h):
		for j in range(w):
			sum_height[i][j] = map[i][j]
			if i-2 < 0 or i+2 >= h or j-2 < 0 or j+2 >= w:
				continue
			if map[i-1][j] > SNOWHEIGHT:
				continue
			if map[i-2][j] > SNOWHEIGHT:
				continue
			if map[i+1][j] > SNOWHEIGHT:
				continue
			if map[i+2][j] > SNOWHEIGHT:
				continue
			if map[i][j-1] > SNOWHEIGHT:
				continue
			if map[i][j-2] > SNOWHEIGHT:
				continue
			if map[i][j+1] > SNOWHEIGHT:
				continue
			if map[i][j+2] > SNOWHEIGHT:
				continue
			if map[i][j] > SNOWHEIGHT:
				continue
			if map[i+1][j+1] > SNOWHEIGHT:
				continue
			if map[i+1][j-1] > SNOWHEIGHT:
				continue
			if map[i-1][j-1] > SNOWHEIGHT:
				continue
			if map[i-1][j+1] > SNOWHEIGHT:
				continue
			sum[i][j] = 1
	for i in range(h):
		for j in range(w-1):
			sum[i][j+1] += sum[i][j]
			sum_height[i][j+1] += sum_height[i][j]
	for j in range(w):
		for i in range(h-1):
			sum[i+1][j] += sum[i][j]
			sum_height[i+1][j] += sum_height[i][j]
	for i in range(h):
		for j in range(w):
			var can_set = true
			var cursum = 0;
			var cur_height = 0;
			if i+battle_height-1 >= h:
				continue
			if j+battle_width-1 >= w:
				continue
			cursum += sum[i+battle_height-1][j+battle_width-1]
			cur_height += sum_height[i+battle_height-1][j+battle_width-1]
			if i-1 >= 0:
				cursum -= sum[i-1][j+battle_width-1]
				cur_height -= sum_height[i-1][j+battle_width-1]
			if j-1 >= 0:
				cursum -= sum[i+battle_height-1][j-1]
				cur_height -= sum_height[i+battle_height-1][j-1]
			if i-1 >= 0 and j-1 >= 0:
				cursum += sum[i-1][j-1]
				cur_height += sum_height[i-1][j-1]
			if cursum == battle_height*battle_width:
				battle_point_candidate.append([i,j,cur_height])
	var res = battle_point_candidate.pick_random()
	for i in range(battle_height):
		for j in range(battle_width):
			map[res[0]+i][res[1]+j] = float(res[2]/(battle_height*battle_width))
	return [map,res[0],res[1]]
func desert_leveling(map:Array):
	var sum = []
	var sum_height = []
	var battle_point_candidate = []
	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append(0)
		sum.append(arrw)
	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append(0)
		sum_height.append(arrw)
	for i in range(h):
		for j in range(w):
			sum_height[i][j] = map[i][j]
			if i-2 < 0 or i+2 >= h or j-2 < 0 or j+2 >= w:
				continue
			if map[i-1][j] == 0:
				continue
			if map[i-2][j] == 0:
				continue
			if map[i+1][j] == 0:
				continue
			if map[i+2][j] == 0:
				continue
			if map[i][j-1] == 0:
				continue
			if map[i][j-2] == 0:
				continue
			if map[i][j+1] == 0:
				continue
			if map[i][j+2] == 0:
				continue
			if map[i][j] == 0:
				continue
			if map[i+1][j+1] == 0:
				continue
			if map[i+1][j-1] == 0:
				continue
			if map[i-1][j-1] == 0:
				continue
			if map[i-1][j+1] == 0:
				continue
			sum[i][j] = 1
	for i in range(h):
		for j in range(w-1):
			sum[i][j+1] += sum[i][j]
			sum_height[i][j+1] += sum_height[i][j]
	for j in range(w):
		for i in range(h-1):
			sum[i+1][j] += sum[i][j]
			sum_height[i+1][j] += sum_height[i][j]
	for i in range(h):
		for j in range(w):
			var can_set = true
			var cursum = 0;
			var cur_height = 0;
			if i+battle_height-1 >= h:
				continue
			if j+battle_width-1 >= w:
				continue
			cursum += sum[i+battle_height-1][j+battle_width-1]
			cur_height += sum_height[i+battle_height-1][j+battle_width-1]
			if i-1 >= 0:
				cursum -= sum[i-1][j+battle_width-1]
				cur_height -= sum_height[i-1][j+battle_width-1]
			if j-1 >= 0:
				cursum -= sum[i+battle_height-1][j-1]
				cur_height -= sum_height[i+battle_height-1][j-1]
			if i-1 >= 0 and j-1 >= 0:
				cursum += sum[i-1][j-1]
				cur_height += sum_height[i-1][j-1]
			if cursum == battle_height*battle_width:
				battle_point_candidate.append([i,j,cur_height])
	var res = battle_point_candidate.pick_random()
	for i in range(battle_height):
		for j in range(battle_width):
			map[res[0]+i][res[1]+j] = float(res[2]/(battle_height*battle_width))
	return [map,res[0],res[1]]
func cave_leveling(map:Array,floor:Array):
	var sum = []
	var sum_height = []
	var battle_point_candidate = []
	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append(0)
		sum.append(arrw)
	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append(0)
		sum_height.append(arrw)
	for i in range(h):
		for j in range(w):
			sum_height[i][j] = floor[i][j]
			if i-2 < 0 or i+2 >= h or j-2 < 0 or j+2 >= w:
				continue
			if map[i-1][j] == 5:
				continue
			if map[i-2][j] == 5:
				continue
			if map[i+1][j] == 5:
				continue
			if map[i+2][j] == 5:
				continue
			if map[i][j-1] == 5:
				continue
			if map[i][j-2] == 5:
				continue
			if map[i][j+1] == 5:
				continue
			if map[i][j+2] == 5:
				continue
			if map[i][j] == 5:
				continue
			if map[i+1][j+1] == 5:
				continue
			if map[i+1][j-1] == 5:
				continue
			if map[i-1][j-1] == 5:
				continue
			if map[i-1][j+1] == 5:
				continue
			sum[i][j] = 1
	for i in range(h):
		for j in range(w-1):
			sum[i][j+1] += sum[i][j]
			sum_height[i][j+1] += sum_height[i][j]
	for j in range(w):
		for i in range(h-1):
			sum[i+1][j] += sum[i][j]
			sum_height[i+1][j] += sum_height[i][j]
	for i in range(h):
		for j in range(w):
			var can_set = true
			var cursum = 0;
			var cur_height = 0;
			if i+battle_height-1 >= h:
				continue
			if j+battle_width-1 >= w:
				continue
			cursum += sum[i+battle_height-1][j+battle_width-1]
			cur_height += sum_height[i+battle_height-1][j+battle_width-1]
			if i-1 >= 0:
				cursum -= sum[i-1][j+battle_width-1]
				cur_height -= sum_height[i-1][j+battle_width-1]
			if j-1 >= 0:
				cursum -= sum[i+battle_height-1][j-1]
				cur_height -= sum_height[i+battle_height-1][j-1]
			if i-1 >= 0 and j-1 >= 0:
				cursum += sum[i-1][j-1]
				cur_height += sum_height[i-1][j-1]
			if cursum == battle_height*battle_width:
				battle_point_candidate.append([i,j,cur_height])
	var res = battle_point_candidate.pick_random()
	for i in range(battle_height):
		for j in range(battle_width):
			floor[res[0]+i][res[1]+j] = float(res[2]/(battle_height*battle_width))
	return [floor,res[0],res[1]]
func castle_leveling(map:Array):
	var sum = []
	var sum_height = []
	var battle_point_candidate = []
	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append(0)
		sum.append(arrw)
	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append(0)
		sum_height.append(arrw)
	for i in range(h):
		for j in range(w):
			sum_height[i][j] = map[i][j]
			if i-2 < 0 or i+2 >= h or j-2 < 0 or j+2 >= w:
				continue
			if map[i-1][j] <= SNOWHEIGHT:
				continue
			if map[i-2][j] <= SNOWHEIGHT:
				continue
			if map[i+1][j] <= SNOWHEIGHT:
				continue
			if map[i+2][j] <= SNOWHEIGHT:
				continue
			if map[i][j-1] <= SNOWHEIGHT:
				continue
			if map[i][j-2] <= SNOWHEIGHT:
				continue
			if map[i][j+1] <= SNOWHEIGHT:
				continue
			if map[i][j+2] <= SNOWHEIGHT:
				continue
			if map[i][j] <= SNOWHEIGHT:
				continue
			if map[i+1][j+1] <= SNOWHEIGHT:
				continue
			if map[i+1][j-1] <= SNOWHEIGHT:
				continue
			if map[i-1][j-1] <= SNOWHEIGHT:
				continue
			if map[i-1][j+1] <= SNOWHEIGHT:
				continue
			sum[i][j] = 1
	for i in range(h):
		for j in range(w-1):
			sum[i][j+1] += sum[i][j]
			sum_height[i][j+1] += sum_height[i][j]
	for j in range(w):
		for i in range(h-1):
			sum[i+1][j] += sum[i][j]
			sum_height[i+1][j] += sum_height[i][j]
	for i in range(h):
		for j in range(w):
			var can_set = true
			var cursum = 0;
			var cur_height = 0;
			if i+battle_height-1 >= h:
				continue
			if j+battle_width-1 >= w:
				continue
			cursum += sum[i+battle_height-1][j+battle_width-1]
			cur_height += sum_height[i+battle_height-1][j+battle_width-1]
			if i-1 >= 0:
				cursum -= sum[i-1][j+battle_width-1]
				cur_height -= sum_height[i-1][j+battle_width-1]
			if j-1 >= 0:
				cursum -= sum[i+battle_height-1][j-1]
				cur_height -= sum_height[i+battle_height-1][j-1]
			if i-1 >= 0 and j-1 >= 0:
				cursum += sum[i-1][j-1]
				cur_height += sum_height[i-1][j-1]
			if cursum == battle_height*battle_width:
				battle_point_candidate.append([i,j,cur_height])
	var res = battle_point_candidate.pick_random()
	for i in range(battle_height):
		for j in range(battle_width):
			map[res[0]+i][res[1]+j] = float(res[2]/(battle_height*battle_width))
	return [map,res[0],res[1]]
func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = find_mesh_instance(child)
		if found != null:
			return found
	return null
func make_castle():
	var castle_scene = load(castle_path)
	var castle_instance:Node3D = castle_scene.instantiate()
	var base = []
	var baseheightmin = []
	for i in range(h):
		var row_map = []
		var row_around = []
		for j in range(w):
			row_map.append(0.0)
			row_around.append(999999.0)
		base.append(row_map)
		baseheightmin.append(row_around)
	base[0][0] = -1.5
	base[h-1][0] = -1.5
	base[0][w-1] = -1.5
	base[h-1][w-1] = -1.5
	base[h/2][w/2] = 2.0
	base[h/2][0] = -1.5
	base[0][w/2] = -1.5
	base[h/2][w-1] = -1.5
	base[h-1][w/2] = -1.5
	base = diamondsquare(base)
	smooth_terrain(10,0.5,base)
	var baseheightmi = 1e9
	for i in range(h):
		for j in range(w):
			baseheightmi = min(baseheightmi,base[i][j])
	for i in range(h):
		for j in range(w):
			base[i][j] -= baseheightmi
	var resbase = sea(base)
	base = resbase[0]
	baseheightmi = 1e9
	for i in range(h):
		for j in range(w):
			baseheightmi = min(baseheightmi,base[i][j])
	for i in range(h):
		for j in range(w):
			base[i][j] -= baseheightmi
	var baseheightma = 0
	for i in range(h):
		for j in range(w):
			baseheightma = max(baseheightma,base[i][j])
	for i in range(h):
		for j in range(w):
			base[i][j] = baseheightma-base[i][j]
	for i in range(h):
		for j in range(w):
			base[i][j] += 3.0
	baseheightma += 3.0
	baseheightmin = assign_aroundheightmin(baseheightmin,base)
	for i in range(h):
		for j in range(w):
			var height = int(floor(base[i][j]/0.1))
			var around = int(floor(baseheightmin[i][j]/0.1))
			var diff = height-around
			for k in range(diff+1):
				map3dnum[height-k][i+castle_start_h][j+castle_start_w] = 2
	for i in range(h):
		var height = int(floor(base[i][0]/0.1))
		var around = int(floor(baseheightma/0.1))
		var diff = around-height
		for k in range(diff+1):
			map3dnum[around-k][i+castle_start_h][castle_start_w] = 2
	for i in range(h):
		var height = int(floor(base[i][w-1]/0.1))
		var around = int(floor(baseheightma/0.1))
		var diff = around-height
		for k in range(diff+1):
			map3dnum[around-k][i+castle_start_h][w-1+castle_start_w] = 2
	for i in range(w):
		var height = int(floor(base[h-1][i]/0.1))
		var around = int(floor(baseheightma/0.1))
		var diff = around-height
		for k in range(diff+1):
			map3dnum[around-k][h-1+castle_start_h][i+castle_start_w] = 2
	for i in range(w):
		var height = int(floor(base[h-1][i]/0.1))
		var around = int(floor(baseheightma/0.1))
		var diff = around-height
		for k in range(diff+1):
			map3dnum[around-k][h-1+castle_start_h][i+castle_start_w] = 2
	var land = []
	var dist = []
	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append(-1)
		land.append(arrw)
	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append(1e9)
		dist.append(arrw)
	var land_acc = []
	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append(0)
		land_acc.append(arrw)
	for i in range(h):
		for j in range(w):
			map3dnum[30][i+castle_start_h][j+castle_start_w] = 1
			if i-1 >= 0 and i+1 < h and j-1 >= 0 and j+1 < w:
				if base[i-1][j] != 0.0 and base[i+1][j] != 0.0 and base[i][j-1] != 0.0 and base[i][j+1] != 0.0:
					land_acc[i][j] = 1
			if map3dnum[int(floor(baseheightma/0.1))][i+castle_start_h][j+castle_start_w] == 2:
				map3dnum[int(floor(baseheightma/0.1))][i+castle_start_h][j+castle_start_w] = -1
			else:
				map3dnum[int(floor(baseheightma/0.1))][i+castle_start_h][j+castle_start_w] = 2
				land[i][j] = 2
	for i in range(h):
		for j in range(w-1):
			land_acc[i][j+1] += land_acc[i][j]
	for j in range(w):
		for i in range(h-1):
			land_acc[i+1][j] += land_acc[i][j]
	var land_start = find_longest_point(land,Vector2i(h/2,w/2),-1)
	var land_end = find_longest_point(land,land_start,-1)
	if land_start.y > land_end.y:
		var m = land_start
		land_start = land_end
		land_end = m
	print(land_start)
	print(land_end)
	var que = Dequeue.new()
	que.push_back(land_start.x*w+land_start.y)
	dist[land_start.x][land_start.y] = 0
	var candidate = []
	while que.size() > 0:
		var q = que.peek_front()
		que.pop_front()
		var i = q/w
		var j = q%w
		candidate.append([dist[i][j],i*w+j])
		if i-1 >= 0:
			if land[i-1][j] != -1 and dist[i-1][j] > dist[i][j]+1:
				dist[i-1][j] = dist[i][j]+1
				que.push_back((i-1)*w+j)
		if i+1 < h:
			if land[i+1][j] != -1 and dist[i+1][j] > dist[i][j]+1:
				dist[i+1][j] = dist[i][j]+1
				que.push_back((i+1)*w+j)
		if j-1 >= 0:
			if land[i][j-1] != -1 and dist[i][j-1] > dist[i][j]+1:
				dist[i][j-1] = dist[i][j]+1
				que.push_back(i*w+j-1)
		if j+1 < w:
			if land[i][j+1] != -1 and dist[i][j+1] > dist[i][j]+1:
				dist[i][j+1] = dist[i][j]+1
				que.push_back(i*w+j+1)
	candidate.sort()
	var sth:int = h/2
	var stw:int = w/2*5
	for k in range(candidate.size()):
		var curc = candidate[k]
		if typeof(curc) != TYPE_ARRAY:
			push_error("Invalid candidate element: " + str(curc))
			continue
		var i = curc[1]/w
		var j = curc[1]%w
		var cash = castle_height_length
		var casw = castle_width_length
		var sum = 0
		if cash+i >= h or casw+j >= w:
			continue
		sum += land_acc[i+cash][j+casw]
		if i-1 >= 0:
			sum -= land_acc[i-1][j+casw]
		if j-1 >= 0:
			sum -= land_acc[i+cash][j-1]
		if i-1 >= 0 and j-1 >= 0 :
			sum += land_acc[i-1][j-1]
		if sum >= (castle_height_length+1)*(castle_width_length+1)-20:
			castle_instance.position = Vector3(i+castle_height_length/2+castle_start_h,int(floor((baseheightma)/0.1))+int(int(h/4*3)/2)-2,j+int(castle_width_length/2)+castle_start_w)
			castle_instance.scale = Vector3(castle_height_length,int(h/4*3),castle_width_length)
			castle_instance.rotation_degrees = Vector3(0, 180, 0)
			add_child(castle_instance)
			var mesh_node: MeshInstance3D = castle_instance.get_node_or_null("tripo_node_7d6e79c8-b98/MeshInstance3D")
			mesh_node = find_mesh_instance(castle_instance)
			mesh_node.create_trimesh_collision()
			sth = i+h/2
			stw = j+w*5/2
			break
	for k in range(1,4):
		for i in range(6,castle_height_length-5):
			for j in range(6,castle_width_length-5):
				map3dnum[int(floor((baseheightma)/0.1))+k][sth+i][stw+j] = 5
	var castle = []
	var height = castle_height_length-19
	var width = castle_width_length-19
	for k in range(3):
		var castlemap = []
		for y in range(height):
			castlemap.append([])
			for x in range(width):
				castlemap[y].append(5)
		var root = rectangle.new(0,0,width,height)
		var cells = bsp(root,10)
		var rooms = []
		for i in range(cells.size()):
			rooms.append(make_room(cells[i],castlemap))
		for i in range(cells.size()):
			for y in range(cells[i].y+cells[i].h,cells[i].y+cells[i].h):
				for x in range(cells[i].x+cells[i].w,cells[i].x+cells[i].w):
					if castlemap[y][x]==-1:
						castlemap[y][x] = 0
		var edges = []
		for i in range(rooms.size()):
			for j in range(i+1,rooms.size()):
				var dx = rooms[i].x-rooms[j].x
				var dy = rooms[i].y-rooms[j].y
				var dist1 = int(sqrt(dx*dx+dy*dy))
				edges.append(edge.new(i,j,dist1))
		
		var mst = kruskal(rooms.size(),edges)
		for i in range(randi()%5+1):
			mst.append(edges[randi()%edges.size()])
		
		for i in range(mst.size()):
			var r1 = rooms[mst[i].u]
			var r2 = rooms[mst[i].v]
			var p1 = Vector2(r1.x+r1.w/2,r1.y+r1.h/2)
			var p2 = Vector2(r2.x+r2.w/2,r2.y+r2.h/2)
			make_corridor(castlemap,p1,p2,1)
		
		for y in range(height):
			for x in range(width):
				if y == 0 or x == 0 or y == height-1 or x == width-1:
					castlemap[y][x] = 5
		castle.append(castlemap)
		for y in range(height):
			for x in range(width):
				if y == 0 or x == 0 or y == height-1 or x == width-1:
					castle[k][y][x] = 5
		for y in range(1,height-1):
			for x in range(1,width-1):
				if castle[k][y][x] == 0:
					castle[k][y][x] = -1
		var labels = bfs(castle[k])
		var counts = {}
		for y in range(height):
			for x in range(width):
				var id = labels[y][x]
				if id != -1:
					counts[id] = counts.get(id,0)+1
		
		var max_id = -1
		var max_count = -1
		for id in counts.keys():
			if counts[id] > max_count:
				max_count = counts[id]
				max_id = id
					
		for y in range(height):
			for x in range(width):
				if labels[y][x] != max_id:
					castle[k][y][x] = 5
		for y in range(height):
			for x in range(width):
				if y == 0 or x == 0 or y == height-1 or x == width-1:
					castle[k][y][x] = 5
	var stair = []
	var castle_acc = []
	for k in range(3):
		var arrhw = []
		for i in range(height):
			var arrw = []
			for j in range(width):
				arrw.append(0)
			arrhw.append(arrw)
		castle_acc.append(arrhw)
		for i in range(height):
			for j in range(width):
				if i-1 >= 0 and i+1 < height and j-1 >= 0 and j+1 < width:
					if castle[k][i-1][j] == -1 and castle[k][i+1][j] == -1 and castle[k][i][j+1] == -1 and castle[k][i][j-1] == -1 and castle[k][i+1][j+1] == -1 and castle[k][i+1][j-1] == -1 and castle[k][i-1][j+1] == -1 and castle[k][i-1][j-1] == -1:
						castle_acc[k][i][j] = 1
	for k in range(2):
		var stair_candidate = []
		for i in range(height):
			for j in range(width):
				if i+2 >= height or j+2 >= width:
					continue
				var sum1 = 0
				for i1 in range(3):
					for j1 in range(3):
						if castle_acc[k][i+i1][j+j1] == 1:
							sum1 += 1
				if i+6 < height:
					var sum2 = 0
					for i1 in range(3):
						for j1 in range(3):
							if castle_acc[k+1][i+i1+4][j+j1] == 1:
								sum2 += 1
					if sum1 == 9 and sum2 == 9:
						stair_candidate.append([i,j,i+4,j])
				if j+6 < width:
					var sum2 = 0
					for i1 in range(3):
						for j1 in range(3):
							if castle_acc[k+1][i+i1][j+j1+4] == 1:
								sum2 += 1
					if sum1 == 9 and sum2 == 9:
						stair_candidate.append([i,j,i,j+4])
				if i-4 >= 0:
					var sum2 = 0
					for i1 in range(3):
						for j1 in range(3):
							if castle_acc[k+1][i+i1-4][j+j1] == 1:
								sum2 += 1
					if sum1 == 9 and sum2 == 9:
						stair_candidate.append([i,j,i-4,j])
				if j-4 >= 0:
					var sum2 = 0
					for i1 in range(3):
						for j1 in range(3):
							if castle_acc[k+1][i+i1][j+j1-4] == 1:
								sum2 += 1
					if sum1 == 9 and sum2 == 9:
						stair_candidate.append([i,j,i,j-4])
		stair.append(stair_candidate.pick_random())
		for i in range(stair.back()[2],stair.back()[2]+2):
			for j in range(stair.back()[3],stair.back()[3]+2):
				castle_acc[k+1][i][j] = 0
	for k in range(3):
		for i in range(height):
			for j in range(width):
				for l in range(5):
					if k == 0 and i >= int((height-4)/2)+1 and j < width-5 and i <= int((height-4)/2)+3:
						map3dnum[int(floor((baseheightma)/0.1))+4+k*5+l+k][sth+i+10][stw+j+10] = -1
						map3dnum[int(floor((baseheightma)/0.1))+4+k*5+l+k][sth+10+int((height-4)/2)][stw+8] = 5
						map3dnum[int(floor((baseheightma)/0.1))+4+k*5+l+k][sth+10+int((height-4)/2)+4][stw+8] = 5
						map3dnum[int(floor((baseheightma)/0.1))+4+k*5+l+k][sth+10+int((height-4)/2)][stw+9] = 5
						map3dnum[int(floor((baseheightma)/0.1))+4+k*5+l+k][sth+10+int((height-4)/2)+4][stw+9] = 5
					else:
						map3dnum[int(floor((baseheightma)/0.1))+4+k*5+l+k][sth+i+10][stw+j+10] = castle[k][i][j]
				if k == 1 and i >= int((height-4)/2)+1 and j < 6 and i <= int((height-4)/2)+3:
					map3dnum[int(floor((baseheightma)/0.1))+4+k*5][sth+10+int((height-4)/2)][stw+8] = 5
					map3dnum[int(floor((baseheightma)/0.1))+4+k*5][sth+10+int((height-4)/2)+4][stw+9] = 5
					map3dnum[int(floor((baseheightma)/0.1))+4+k*5][sth+10+int((height-4)/2)][stw+9] = 5
					map3dnum[int(floor((baseheightma)/0.1))+4+k*5][sth+10+int((height-4)/2)+4][stw+8] = 5
					map3dnum[int(floor((baseheightma)/0.1))+4+k*5+k][sth+i+10][stw+8] = 5
					map3dnum[int(floor((baseheightma)/0.1))+4+k*5+k][sth+i+10][stw+9] = 5
					
				map3dnum[int(floor((baseheightma)/0.1))+4+k*5+5+k][sth+i+10][stw+j+10] = 5
	print(stair.size())
	for k in range(stair.size()):
		var sti1 = stair[k][0]
		var stj1 = stair[k][1]
		var sti2 = stair[k][2]
		var stj2 = stair[k][3]
		if sti1 == sti2:
			if stj2 >= stj1:
				for j in range(stj2-stj1+1):
					for i in range(3):
						map3dnum[int(floor((baseheightma)/0.1))+4+k*5+k+j][sth+sti1+i+10][stw+j+stj1+2+10] = 5
						for t in range(5):
							map3dnum[int(floor((baseheightma)/0.1))+4+k*5+k+min(5,j+t+1)][sth+sti1+i+10][stw+j+stj1+2+10] = -1
			else:
				for j in range(stj1-stj2+1):
					for i in range(3):
						map3dnum[int(floor((baseheightma)/0.1))+4+k*5+k+5-j][sth+sti1+i+10][stw+j+stj2+1+10] = 5
						for t in range(5):
							map3dnum[int(floor((baseheightma)/0.1))+4+k*5+k+min(5,4-j+t+1)][sth+sti1+i+10][stw+j+stj2+10] = -1
		else:
			if sti2 >= sti1:
				for i in range(sti2-sti1+1):
					for j in range(3):
						map3dnum[int(floor((baseheightma)/0.1))+4+k*5+k+i][sth+sti1+i+2+10][stw+j+stj1+10] = 5
						for t in range(5):
							map3dnum[int(floor((baseheightma)/0.1))+4+k*5+k+min(5,i+t+1)][sth+sti1+i+2+10][stw+j+stj1+10] = -1
			else:
				for i in range(sti1-sti2+1):
					for j in range(3):
						map3dnum[int(floor((baseheightma)/0.1))+4+k*5+k+5-i][sth+sti2+i+1+10][stw+j+stj1+10] = 5
						for t in range(5):
							map3dnum[int(floor((baseheightma)/0.1))+4+k*5+k+min(5,4-i+t+1)][sth+sti2+i+10][stw+j+stj1+10] = -1
func _ready():
	player = get_parent().get_node("CharacterBody3D")
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
	
	for k in range(d): 
		var z_level_map = []
		for i in range(worldh):
			var row_for_z = []
			for j in range(worldw):
				row_for_z.append(-1) 
			z_level_map.append(row_for_z)
		map3dnum.append(z_level_map)
	for k in range(d): 
		var z_level_map = []
		for i in range(worldh):
			var row_for_z = []
			for j in range(worldw):
				row_for_z.append(-1) 
			z_level_map.append(row_for_z)
		nearest_ground.append(z_level_map)
		
	for k in range(d):
		var z_level_map = []
		for i in range(worldh):
			var row_for_z = []
			for j in range(worldw):
				row_for_z.append(-1) 
			z_level_map.append(row_for_z)
		map3d.append(z_level_map)
	var chunkh = worldh/rh
	var chunkw = worldw/rw
	if(chunkw*rw<worldw):
		chunkw+=1
	if(chunkh*rh<worldh):
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
	#草原の生成
	for i in range(h):
		map[i][0] = -1.0
		map[i][w-1] = -1.0
	for j in range(w):
		map[0][j] = -1.0
		map[h-1][j] = -1.0
	map[h/2][w/2] = 0.5
	map = diamondsquare(map,0.75)
	smooth_terrain(10,0.5,map)
	var resmap = sea(map,8)
	var seablocksum =resmap[1]
	map = resmap[0]
	var minheight_val = 1e9
	var maxheight_val = -1e9
	for i in range(h):
		for j in range(w):
			if map[i][j] > SEAHEIGHT:
				minheight_val = min(minheight_val, map[i][j])
			maxheight_val = max(maxheight_val, map[i][j])

	for i in range(h):
		for j in range(w):
			if map[i][j] > SEAHEIGHT:
				map[i][j] -= minheight_val
			else:
				map[i][j] = 0
	
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
		if (boxsum >= (h * w - seablocksum) / 5 * 2):
			heightleft = heightmid
		else:
			heightright = heightmid
	snow_threshold = heightleft
	#雪山の生成
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
				
				while(len(queue)>0):
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
							
				segmentnum += 1
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
	var res_leveling = snow_leveling(map)
	map = res_leveling[0]
	var res_leveling1 = plane_leveling(map)
	map = res_leveling1[0]
	aroundheightmin = assign_aroundheightmin(aroundheightmin,map)
	assignnum = assign_num(SNOWHEIGHT,assignnum,map,max_height)
	for i in range(h):
		aroundheightmin[i][0] = 0
		aroundheightmin[i][w-1] = 0
	for i in range(w):
		aroundheightmin[0][i] = 0
		aroundheightmin[h-1][i] = 0			
	for i in range(worldh):
		for j in range(worldw):
			if i >= h and i < 2*h and j >= 2*w and j < 3*w:
				continue
			map3dnum[30][i][j] = 1
	for i in range(h):
		for j in range(w):
			map[i][j] += 3.0
			aroundheightmin[i][j] += 3.0
	snow_battle_pos = Vector3(res_leveling[1]+plane_start_h,int(floor(map[res_leveling[1]][res_leveling[2]]/0.1)),res_leveling[2]+plane_start_w)
	plane_battle_pos = Vector3(res_leveling1[1]+plane_start_h,int(floor(map[res_leveling1[1]][res_leveling1[2]]/0.1)),res_leveling1[2]+plane_start_w)
	for i in range(h):
		for j in range(w):
			var height = int(floor(map[i][j]/0.1))
			var around = int(floor(aroundheightmin[i][j]/0.1))
			var diff = height-around
			for k in range(diff+1):
				map3dnum[height-k][i+plane_start_h][j+plane_start_w] = assignnum[i][j]
	#洞窟生成
	var floor = []#迷路の床
	var floorheightmin = []
	var ceiling = []#迷路の天井
	var ceilingheightmin = []
	for i in range(h):
		var row_map = []
		var row_around = []
		for j in range(w):
			row_map.append(0.0)
			row_around.append(999999.0)
		floor.append(row_map)
		floorheightmin.append(row_around)
	for i in range(h):
		var row_map = []
		var row_around = []
		for j in range(w):
			row_map.append(0.0)
			row_around.append(999999.0)
		ceiling.append(row_map)
		ceilingheightmin.append(row_around)
	floor = diamondsquare(floor,0.70)
	ceiling = diamondsquare(ceiling,0.70)
	smooth_terrain(10,3.5,floor)
	smooth_terrain(10,3.5,ceiling)
	floorheightmin = assign_aroundheightmin(floorheightmin,floor)
	ceilingheightmin = assign_aroundheightmin(ceilingheightmin,ceiling)
	var floorheightmax = 0
	var floorheightmi = 1e9
	var ceilingheightmax = 0
	var ceilingheightmi = 1e9
	var dist_ceil_groundmin = 1e9
	
	for i in range(h):
		for j in range(w):
			floorheightmi = min(floorheightmi,floor[i][j])
			ceilingheightmi = min(ceilingheightmi,ceiling[i][j])
	for i in range(h):
		for j in range(w):
			floor[i][j] -= floorheightmi
			floorheightmin[i][j] -= floorheightmi
			ceiling[i][j] -= ceilingheightmi
			ceilingheightmin[i][j] -= ceilingheightmi
	floorheightmi = 0
	ceilingheightmi = 0
	for i in range(h):
		for j in range(w):
			var height = floor[i][j]
			floorheightmax = max(floorheightmax,height)
			var height1 = ceiling[i][j]
			ceilingheightmax = max(ceilingheightmax,height1)
	for i in range(h):
		for j in range(w):
			var height = floor[i][j]
			var height1 = ceiling[i][j]
			dist_ceil_groundmin	 = min(dist_ceil_groundmin,height1-height)
	for i in range(h):
		for j in range(w):
			ceiling[i][j] += 0.3-dist_ceil_groundmin
			ceilingheightmin[i][j] += 0.3-dist_ceil_groundmin
	ceilingheightmax += 0.3-dist_ceil_groundmin
	ceilingheightmi += 0.3-dist_ceil_groundmin
	for i in range(h):
		for j in range(w):
			var height = int(floor(floor[i][j]/0.1))
			var around = int(floor(floorheightmin[i][j]/0.1))
			var diff = height-around
			var height1 = int(floor(ceiling[i][j]/0.1))
			var around1 = int(floor(ceilingheightmin[i][j]/0.1))
			var diff1 = height1-around1
			for k in range(diff+1):
				map3dnum[height-k+10][i+cave_start_h][j+cave_start_w] = 5
			for k in range(diff1+1):
				map3dnum[height1-k+10][i+cave_start_h][j+cave_start_w] = 5
	floorheightmi *= 10
	floorheightmi += 10
	floorheightmax *= 10
	floorheightmax += 10
	ceilingheightmax *= 10
	ceilingheightmax += 10
	ceilingheightmi *= 10
	ceilingheightmi += 10
	var caves = generate_cave(w,h,floorheightmi)#迷路
	res_leveling = cave_leveling(caves[0],floor)
	cave_battle_pos = Vector3(res_leveling[1]+cave_start_h,int(floor(floor[res_leveling[1]][res_leveling[1]]/0.1))+10,res_leveling[2]+cave_start_w)
	for i in range(h):
		for j in range(w):
			var height = int(floor(floor[i][j]/0.1))+10
			for k in range(height,30):
				if caves[k-height][i][j] == 5:
					map3dnum[k][i+cave_start_h][j+cave_start_w] = 5
	#砂漠生成
	var desert = []
	var desertheightmin = []
	var desertassignnum = []
	for i in range(h):
		var row_map = []
		var row_around = []
		var row_assignnum = []
		for j in range(w):
			row_map.append(0.0)
			row_around.append(999999.0)
			row_assignnum.append(-1)
		desert.append(row_map)
		desertheightmin.append(row_around)
		desertassignnum.append(row_assignnum)
	for i in range(h):
		desert[i][0] = -1.0
		desert[i][w-1] = -1.0
	for j in range(w):
		desert[0][j] = -1.0
		desert[h-1][j] = -1.0
	desert[h/2][w/2] = 0.2
	desert = diamondsquare(desert,0.75)
	smooth_terrain(10,0.5,desert)
	var desert_plane_diff = -1e9
	var desertheightmi = 1e9
	var desertheightmax = -1e9
	for i in range(h):
		for j in range(w):
			desertheightmi = min(desertheightmi,desert[i][j])
			desertheightmax = max(desertheightmax,desert[i][j])
	for i in range(h):
		for j in range(w):
			desert[i][j] -= desertheightmi
	desertheightmax -= desertheightmi
	var resdesert = sea(desert,3)
	desert = resdesert[0]
	for i in range(h):
		for j in range(w):
			if desert[i][j] > SEAHEIGHT:
				desert[i][j] -= SEAHEIGHT
				desert[i][j] += 1.0
			else:
				desert[i][j] = 0
	desertheightmax += 1.0
	res_leveling = desert_leveling(desert)
	desert = res_leveling[0]
	desertassignnum = assign_num(SNOWHEIGHT,desertassignnum,desert,desertheightmax)
	for i in range(h):
		for j in range(w):
			desert[i][j] += 3.0
	desertheightmi = 3.0
	desert_battle_pos = Vector3(res_leveling[1]+desert_start_h,int(floor(desert[res_leveling[1]][res_leveling[2]])),res_leveling[2]+desert_start_w)
	desertheightmin = assign_aroundheightmin(desertheightmin,desert)
	for i in range(h):
		desertheightmin[i][0] = min(desertheightmin[i][0],3.0)
		desertheightmin[i][w-1] = min(desertheightmin[i][w-1],3.0)
	for j in range(w):
		desertheightmin[0][j] = min(desertheightmin[0][j],3.0)
		desertheightmin[h-1][j] = min(desertheightmin[h-1][j],3.0)
	for i in range(h):
		for j in range(w):
			if desertassignnum[i][j] != 2 and desertassignnum[i][j] != 1:
				desertassignnum[i][j] = 5
	for i in range(h):
		for j in range(w):
			var height = int(floor(desert[i][j]/0.1))
			var around = int(floor(desertheightmin[i][j]/0.1))
			var diff = height-around
			for k in range(diff+1):
				map3dnum[height-k][i+desert_start_h][j+desert_start_w] = desertassignnum[i][j]
	#洞窟の入口生成		
	var caveentrance = find_cave_entrance(plane_start_h,plane_start_w,map)
	get_parent().get_node("CharacterBody3D").position = caveentrance[0]+Vector3i(0,100,0)
	var px
	var py
	
	for i in range(caves[0].size()):
		for j in range(caves[0][0].size()):
			if caves[0][i][j] != 5:
				px = i
				py = j
	var maze_start = find_longest_point(caves[0],Vector2i(px,py),5)
	var maze_end = find_longest_point(caves[0],maze_start,5)
	var dist_to_start = (Vector3(caveentrance[0]) - Vector3(maze_start.x + cave_start_h, 0, maze_start.y + cave_start_w)).length_squared()
	var dist_to_end = (Vector3(caveentrance[0]) - Vector3(maze_end.x + cave_start_h, 0, maze_end.y + cave_start_w)).length_squared()
	if dist_to_start > dist_to_end:
		var m = maze_start
		maze_start = maze_end
		maze_end = m
	var mazeentrance = assign_maze_entrance(maze_start,floor,floorheightmin,caves[0])
	mazeentrance[0].y += 1
	make_tunnel(caveentrance,mazeentrance)
	var caveend = Vector3(h,int(floor(desert[h/2][w/4]/0.1)+entrance_height_radius)+1,w)
	var mazeend = assign_maze_entrance(maze_end,floor,floorheightmin,caves[0])
	mazeend[0].y += 1
	make_tunnel([caveend,0,0],mazeend)
	make_castle()
	for k in range(d-1):
		for i in range(worldh):
			for j in range(worldw):
				nearest_ground[k+1][i][j] = nearest_ground[k][i][j]
				if map3dnum[k+1][i][j] != -1:
					nearest_ground[k+1][i][j] = k+1
					
	template_mesh = get_parent().get_node("StaticBody3D/MeshInstance3D").mesh
	create_multimesh_body(map3dnum)
	create_collision_body(map3dnum)
	
