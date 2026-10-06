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

const DEBUG_FIXED_SEED = true
const DEBUG_SEED_VALUE = 1234567

var baseheightma: float = 0.0
var h:int = 65
var w:int = 65
var worldh = 130
var worldw = 260
var plane_start_h:int = 32
var plane_start_w:int = 97
var desert_start_h:int = 32
var desert_start_w:int = 32
var cave_start_h:int = 32
var cave_start_w:int = 65
var castle_start_h:int = 32
var castle_start_w:int = 162
var d = 90
var entrance_width_radius: float = 3.0
var entrance_height_radius: float = 3.0
var castle_width_length = 48
var castle_height_length = 48


var battle_height = 10
var battle_width = 10
var shop_height = 4
var shop_width = 4
var rh = 32
var rw = 32
var collision
var _rng = RandomNumberGenerator.new()
var map = []
var _map3d_flat = PackedInt32Array()
var map3d = []
var collisiondata = []
var multimeshdata = []
var chunk_calculated = []
var _map3dnum_flat = PackedInt32Array()
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
var plane_shop_pos:Vector3
var cave_battle_pos:Vector3
var cave_shop_pos:Vector3
var desert_battle_pos:Vector3
var desert_shop_pos:Vector3
var snow_battle_pos:Vector3
var snow_shop_pos:Vector3
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
				map[my][mx] = average + _rng.randf_range(-1, 1) * amplitude

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
				map[y][mx] = map[y][mx] / add + _rng.randf_range(-1, 1) * amplitude

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
				map[my][x] = map[my][x] / add + _rng.randf_range(-1, 1) * amplitude

		size /= 2
		amplitude *= 0.65
	return map
#地形のなだらかな部分を平坦化する関数
func smooth_terrain(passes: int, threshold: float,map:Array, progress_weight: float = 0.0):
	var step = 0.0
	if passes > 0:
		step = progress_weight / passes
	for p in range(passes):
		if step > 0:
			await _add_loading_progress(step)
		else:
			await get_tree().process_frame
		var read_map = []
		for i in range(h):
			read_map.append(map[i].duplicate())

		for i in range(1, h - 1):
			for j in range(1, w - 1):
				var h0 = read_map[i-1][j-1]; var h1 = read_map[i-1][j]; var h2 = read_map[i-1][j+1]
				var h3 = read_map[i][j-1];   var h4 = read_map[i][j];   var h5 = read_map[i][j+1]
				var h6 = read_map[i+1][j-1]; var h7 = read_map[i+1][j]; var h8 = read_map[i+1][j+1]
				
				var max_h = max(h0, max(h1, max(h2, max(h3, max(h4, max(h5, max(h6, max(h7, h8))))))))
				var min_h = min(h0, min(h1, min(h2, min(h3, min(h4, min(h5, min(h6, min(h7, h8))))))))
				
				if max_h - min_h < threshold:
					map[i][j] = (h0 + h1 + h2 + h3 + h4 + h5 + h6 + h7 + h8) / 9.0

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
	var mat_num = _map3dnum_flat[(k) * worldh * worldw + (i) * worldw + (j)]
	# --- マテリアル割り当てロジック (優先度順) ---
	# 1. 海
	if _map3dnum_flat[(k) * worldh * worldw + (i) * worldw + (j)] == 1:
		multimesh.material_override = material_water
		return

	# 2. 岩
	if _map3dnum_flat[(k) * worldh * worldw + (i) * worldw + (j)] == 2:
		multimesh.material_override = material_rock
		return

	# 3. 雪
	if _map3dnum_flat[(k) * worldh * worldw + (i) * worldw + (j)] == 3:
		multimesh.material_override = material_snow
		return

	# 4. 草
	if _map3dnum_flat[(k) * worldh * worldw + (i) * worldw + (j)] == 4:
		multimesh.material_override = material_grass
		
	# 5. 土
	if _map3dnum_flat[(k) * worldh * worldw + (i) * worldw + (j)] == 5:
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
		horizontal = _rng.randi()%2 == 0
	if horizontal and rect.h >= min_size*2:
		var cut = _rng.randf_range(min_size,rect.h-min_size)
		var r1 = rectangle.new(rect.x,rect.y,rect.w,cut)
		var r2 = rectangle.new(rect.x,rect.y+cut,rect.w,rect.h-cut)
		result.append_array(bsp(r1,min_size))
		result.append_array(bsp(r2,min_size))
	elif not horizontal and rect.w > min_size*2:
		var cut = _rng.randf_range(min_size,rect.w-min_size)
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
		width = _rng.randi()%(cell.w-min_size)+min_size
	else:
		width = cell.w
	var height
	if cell.h > min_size:
		height = _rng.randi()%(cell.h-min_size)+min_size
	else:
		height = cell.h
	var x
	if cell.w > width:
		x = cell.x+_rng.randi()%(cell.w-width)
	else:
		x = cell.x		
	var y
	if cell.h > height:
		y = cell.y+_rng.randi()%(cell.h-height)
	else:
		y = cell.y
	for i in range(y,y+height):
		for j in range(x,x+width):
			map[i][j] = -1
	return rectangle.new(x,y,width,height)

func make_corridor(map:Array,p1:Vector2,p2:Vector2,wide:int):
	if _rng.randf() < 0.5:
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
				var q_head = 0
				while q_head < queue.size():
					var p = queue[q_head]
					q_head += 1
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
	for i in range(_rng.randi()%5+1):
		mst.append(edges[_rng.randi()%edges.size()])
	
	for i in range(mst.size()):
		var r1 = rooms[mst[i].u]
		var r2 = rooms[mst[i].v]
		var p1 = Vector2(r1.x+r1.w/2,r1.y+r1.h/2)
		var p2 = Vector2(r2.x+r2.w/2,r2.y+r2.h/2)
		make_corridor(cavemap,p1,p2,0)
	
	for y in range(1,height-1):
		for x in range(1,width-1):
			if (cavemap[y][x] == -1 or cavemap[y][x] == 1) and _rng.randf() < 0.1:
				cavemap[y+_rng.randi_range(-1,1)][x+_rng.randi_range(-1,1)] = -1
	
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
			arrw.resize(w)
			arrw.fill(0)
			arrhw.append(arrw)
		rock_acc.append(arrhw)
	for k in range(d):
		for i in range(h):
			for j in range(w):
				if _map3dnum_flat[(k) * worldh * worldw + (i+sth) * worldw + (j+stw)] == 2:
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
				if _map3dnum_flat[(y) * worldh * worldw + (x+sth) * worldw + (z+stw)] != 2:
					continue
				if _map3dnum_flat[(y-entrance_height_radius-1) * worldh * worldw + (x+sth) * worldw + (z+stw)] != -1:
					continue
				if x+entrance_width_radius < h and x-entrance_width_radius >= 0 and y+entrance_height_radius < d and y-entrance_height_radius >= 0 and z+1 < w and z-1 >= 0:
					if _map3dnum_flat[(y-entrance_height_radius) * worldh * worldw + (x+sth) * worldw + (y+stw)] != 2:
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
		
	return candidates[_rng.randi() % candidates.size()]
								
func find_longest_point(cave:Array,st:Vector2i,num:int)->Vector2i:
	var dist = cave.duplicate(true)
	var caveh = cave.size()
	var cavew = cave[0].size()
	for i in range(caveh):
		for j in range(cavew):
			dist[i][j] = 1e9
	dist[st.x][st.y] = 0
	var que = PackedInt32Array()
	que.resize(caveh * cavew)
	var que_head = 0
	var que_tail = 0
	que[que_tail] = st.x*cavew+st.y
	que_tail += 1
	while que_head < que_tail:
		var q = que[que_head]
		que_head += 1
		var i = q/cavew
		var j = q%cavew
		if i-1 >= 0:
			if cave[i-1][j] != num and dist[i-1][j] > dist[i][j]+1:
				dist[i-1][j] = dist[i][j]+1
				que[que_tail] = (i-1)*cavew+j
				que_tail += 1
		if i+1 < caveh:
			if cave[i+1][j] != num and dist[i+1][j] > dist[i][j]+1:
				dist[i+1][j] = dist[i][j]+1
				que[que_tail] = (i+1)*cavew+j
				que_tail += 1
		if j-1 >= 0:
			if cave[i][j-1] != num and dist[i][j-1] > dist[i][j]+1:
				dist[i][j-1] = dist[i][j]+1
				que[que_tail] = i*cavew+j-1
				que_tail += 1
		if j+1 < cavew:
			if cave[i][j+1] != num and dist[i][j+1] > dist[i][j]+1:
				dist[i][j+1] = dist[i][j]+1
				que[que_tail] = i*cavew+j+1
				que_tail += 1
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

var chunk_queue = []
var chunk_state = []
var chunk_col_state = []
var CHUNK_BUDGET_MS = 3.0
var unload_length = visiblelength + 2
var collision_length = 1
var unload_collision_length = 2
var is_player_frozen_for_chunk = true

var frame_times = []
var over_16ms_count = 0
var over_16ms_chunk_count = 0


func print_stats():
	if frame_times.size() == 0: return
	var total = 0.0
	var max_t = 0.0
	frame_times.sort()
	for t in frame_times:
		total += t
		max_t = max(max_t, t)
	var avg = total / frame_times.size()
	var p95 = frame_times[int(frame_times.size() * 0.95)]
	var p99 = frame_times[int(frame_times.size() * 0.99)]
	var text = "--- FRAME STATS ---
"
	text += "Frames: " + str(frame_times.size()) + "
"
	text += "Avg: " + str(avg) + " ms
"
	text += "95th: " + str(p95) + " ms
"
	text += "99th: " + str(p99) + " ms
"
	text += "Max: " + str(max_t) + " ms
"
	text += ">16.6ms count: " + str(over_16ms_count) + "
"
	text += ">16.6ms (chunk related): " + str(over_16ms_chunk_count) + "
"
	text += "-------------------
"
	print(text)
	var file = FileAccess.open("user://fps_stats.txt", FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()

func _exit_tree():
	print_stats()
func _process(delta):
	var start_process = Time.get_ticks_usec()

	var cur_pos = player.global_transform.origin
	var px = int(cur_pos.x / rh)
	var pz = int(cur_pos.z / rw)
	var old_px = int(playerpos.x / rh)
	var old_pz = int(playerpos.z / rw)
	
	if px != old_px or pz != old_pz:
		if playerpos.x != 1e9: # Not the very first frame
			var dist = max(abs(px - old_px), abs(pz - old_pz))
			if dist > 1: # Teleport detected!
				is_player_frozen_for_chunk = true
				player.process_mode = Node.PROCESS_MODE_DISABLED
		playerpos = cur_pos
		
	if not is_generating:
		_queue_chunks_around(px, pz)
			
	if is_player_frozen_for_chunk and not is_generating:
		if px >= 0 and pz >= 0 and px < chunk_col_state.size() and pz < chunk_col_state[0].size():
			if chunk_col_state[px][pz] == 2:
				player.process_mode = Node.PROCESS_MODE_INHERIT
				is_player_frozen_for_chunk = false
			
	var processed_chunks = 0
	if not is_generating:
		processed_chunks = _process_chunk_queue(cur_pos)

	if not is_generating:
		var end_process = Time.get_ticks_usec()
		var frame_ms = (end_process - start_process) / 1000.0
		frame_times.append(frame_ms)
		if frame_ms > 16.6:
			over_16ms_count += 1
			if processed_chunks > 0:
				over_16ms_chunk_count += 1





func _queue_chunks_around(px: int, pz: int):
	var vis_min_i = max(0, px - visiblelength)
	var vis_max_i = min(collisionmap.size() - 1, px + visiblelength)
	var vis_min_j = max(0, pz - visiblelength)
	var vis_max_j = min(collisionmap[0].size() - 1, pz + visiblelength)

	for i in range(vis_min_i, vis_max_i + 1):
		for j in range(vis_min_j, vis_max_j + 1):
			if i >= chunk_state.size() or j >= chunk_state[0].size(): continue
			var state = chunk_state[i][j]
			if state == 0:
				chunk_queue.append([i, j, 0.0, 0, 0, 0, null])
				chunk_state[i][j] = 1
			elif state == 3:
				chunk_state[i][j] = 2

	for i in range(chunk_state.size()):
		for j in range(chunk_state[0].size()):
			var dist = max(abs(i - px), abs(j - pz))
			var state = chunk_state[i][j]
			if dist > unload_length:
				if state == 2:
					chunk_queue.append([i, j, 0.0, 1, 0, 0, null])
					chunk_state[i][j] = 3
				elif state == 1:
					chunk_state[i][j] = 0
			
			# Collision Queue
			var col_state = chunk_col_state[i][j]
			if dist <= collision_length:
				if col_state == 0 and state == 2: # Mesh must be generated
					chunk_queue.append([i, j, 0.0, 2, 3, 0, null])
					chunk_col_state[i][j] = 1
				elif col_state == 3:
					chunk_col_state[i][j] = 2
			elif dist > unload_collision_length:
				if col_state == 2:
					chunk_queue.append([i, j, 0.0, 3, 0, 0, null])
					chunk_col_state[i][j] = 3
				elif col_state == 1:
					chunk_col_state[i][j] = 0

func _step_generate_chunk(task: Array) -> bool:
	var ci = task[0]
	var cj = task[1]
	var phase = task[4]
	
	if phase == 0:
		if not chunk_calculated[ci][cj]:
			var result_container = []
			var task_id = WorkerThreadPool.add_task(_thread_calculate_chunk_data.bind(ci, cj, result_container), true)
			task.append(task_id) # task[7]
			task.append(result_container) # task[8]
			task[4] = 1
			return false
		else:
			task[4] = 2
			return false
			
	elif phase == 1:
		var task_id = task[7]
		var result_container = task[8]
		if not WorkerThreadPool.is_task_completed(task_id):
			return false
			
		WorkerThreadPool.wait_for_task_completion(task_id)
		multimeshdata[ci][cj] = result_container[0]
		collisiondata[ci][cj] = result_container[1]

		chunk_calculated[ci][cj] = true
		task[4] = 2
		return false
		
	elif phase == 2:
		var cube = get_parent().get_node("cube")
		if len(multimeshmap[ci][cj]) == 0 and len(multimeshdata[ci][cj]) != 0:
			for group in multimeshdata[ci][cj]:
				var buf = group[0]
				var count = group[1]
				var first_block = group[2]
				
				var multimesh = MultiMesh.new()
				multimesh.transform_format = MultiMesh.TRANSFORM_3D
				multimesh.mesh = template_mesh
				multimesh.instance_count = count
				
				var b_idx = 0
				for k in range(count):
					var t = Transform3D()
					t.origin = Vector3(buf[b_idx+9], buf[b_idx+10], buf[b_idx+11])
					multimesh.set_instance_transform(k, t)
					b_idx += 12
				
				var multimeshinstance = MultiMeshInstance3D.new()
				multimeshinstance.multimesh = multimesh
				assign_material(first_block[0], first_block[1], first_block[2], multimeshinstance)
				cube.add_child(multimeshinstance)
				multimeshmap[ci][cj].append(multimeshinstance)
		return true

	return true

func _step_free_chunk(task: Array) -> bool:
	var ci = task[0]
	var cj = task[1]
	
	if len(multimeshmap[ci][cj]) > 0:
		for node in multimeshmap[ci][cj]:
			node.queue_free()
		multimeshmap[ci][cj].clear()
		
	# Also free collision if it exists (safety)
	if len(collisionmap[ci][cj]) > 0:
		for node in collisionmap[ci][cj]:
			node.queue_free()
		collisionmap[ci][cj].clear()
		chunk_col_state[ci][cj] = 0
		
	return true

func _step_build_collision(task: Array) -> bool:
	var ci = task[0]
	var cj = task[1]
	var phase = task[4]
	
	if phase == 3:
		var col_data = collisiondata[ci][cj]
		var sub_idx = task[5]
		if len(col_data) == 0:
			task[4] = 5
			return false
			
		var static_body = task[6]
		if static_body == null:
			static_body = StaticBody3D.new()
			task[6] = static_body
			
		var count = 0
		while sub_idx < len(col_data) and count < 30:
			var shape = BoxShape3D.new()
			shape.size = col_data[sub_idx][0]
			var cshape = CollisionShape3D.new()
			cshape.shape = shape
			cshape.position = col_data[sub_idx][1]
			static_body.add_child(cshape)
			sub_idx += 1
			count += 1
			
		task[5] = sub_idx
		if sub_idx >= len(col_data):
			task[4] = 4
		return false
		
	elif phase == 4:
		var static_body = task[6]
		if static_body != null:
			collisionmap[ci][cj].append(static_body)
			get_parent().get_node("cube").add_child(static_body)
		task[4] = 5
		return true

	return true

func _step_free_collision(task: Array) -> bool:
	var ci = task[0]
	var cj = task[1]
	
	if len(collisionmap[ci][cj]) > 0:
		for node in collisionmap[ci][cj]:
			node.queue_free()
		collisionmap[ci][cj].clear()
	return true

func _process_chunk_queue(center_pos: Vector3) -> int:
	var px = int(center_pos.x) / rh
	var pz = int(center_pos.z) / rw
	

	
	var cur_vel = Vector3.ZERO
	if player and player.has_method("get_velocity"):
		cur_vel = player.get_velocity()
		
	for task in chunk_queue:
		var ci = task[0]
		var cj = task[1]
		var type = task[3]
		var dist_sq = (ci - px) * (ci - px) + (cj - pz) * (cj - pz)
		task[2] = float(dist_sq)
		
		# Direction bonus removed to prevent straight-line generation blocking
				
	chunk_queue.sort_custom(func(a, b): return a[2] < b[2])
	
	var start_time = Time.get_ticks_msec()
	var processed = 0
	var new_queue = []
	var budget_exceeded = false
	
	var i = 0
	while i < chunk_queue.size():
		var task = chunk_queue[i]
		var ci = task[0]
		var cj = task[1]
		var type = task[3]
		
		# Validation check
		if type == 0 and chunk_state[ci][cj] != 1:
			i += 1
			continue
		if type == 1 and chunk_state[ci][cj] != 3:
			i += 1
			continue
		if type == 2 and chunk_col_state[ci][cj] != 1:
			i += 1
			continue
		if type == 3 and chunk_col_state[ci][cj] != 3:
			i += 1
			continue
			
		var cur_time = Time.get_ticks_msec()
		if cur_time - start_time >= CHUNK_BUDGET_MS:
			budget_exceeded = true
			
		if budget_exceeded:
			new_queue.append(task)
			i += 1
			continue
			
		var finished = false
		if type == 0:
			finished = _step_generate_chunk(task)
			if finished:
				chunk_state[ci][cj] = 2
				processed += 1
		elif type == 1:
			finished = _step_free_chunk(task)
			if finished:
				chunk_state[ci][cj] = 0
				processed += 1
		elif type == 2:
			finished = _step_build_collision(task)
			if finished:
				chunk_col_state[ci][cj] = 2
				processed += 1
		elif type == 3:
			finished = _step_free_collision(task)
			if finished:
				chunk_col_state[ci][cj] = 0
				processed += 1
				
		if not finished:
			new_queue.append(task)
			
		i += 1
		
	chunk_queue = new_queue
	return processed

func update_visibility(center_pos: Vector3):
	if is_generating: return
	_queue_chunks_around(int(center_pos.x/rh), int(center_pos.z/rw))
	_process_chunk_queue(center_pos)

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

func _debug_verify_chunk(i1: int, j1: int, new_multi: Array, new_col: Array):
	var wh = worldh
	var ww = worldw
	var wh_ww = wh * ww
	var max_k = d

	var limit_i_base = i1 * rh
	var limit_i_max = limit_i_base + rh
	if limit_i_max > wh: limit_i_max = wh
	
	var limit_j_base = j1 * rw
	var limit_j_max = limit_j_base + rw
	if limit_j_max > ww: limit_j_max = ww

	var exposed_blocks_sync = 0
	var visited = PackedByteArray()
	visited.resize(max_k * rh * rw)
	visited.fill(0)
	
	for k in range(max_k):
		var k_wh_ww = k * wh_ww
		var c_k_rh_rw = k * (rh * rw)
		for gi in range(limit_i_base, limit_i_max):
			var gi_ww = gi * ww
			var c_i = gi - limit_i_base
			var c_i_rw = c_i * rw
			for gj in range(limit_j_base, limit_j_max):
				var idx = k_wh_ww + gi_ww + gj
				var curmap3d = _map3d_flat[idx]
				var curmap3dnum = _map3dnum_flat[idx]
				if curmap3d != -1 or curmap3dnum == -1:
					continue
				
				var c_j = gj - limit_j_base
				var c_idx = c_k_rh_rw + c_i_rw + c_j
				if visited[c_idx] != 0: continue
				
				var que = []
				que.append([gi, gj, k])
				var head = 0
				
				while head < que.size():
					var cur = que[head]
					head += 1
					var cc_i = cur[0]
					var cc_j = cur[1]
					var cc_k = cur[2]
					
					var lc_i = cc_i - limit_i_base
					var lc_j = cc_j - limit_j_base
					var lc_idx = cc_k * (rh * rw) + lc_i * rw + lc_j
					if visited[lc_idx] != 0: continue
					visited[lc_idx] = 1
					exposed_blocks_sync += 1
					
					var n_idx
					if cc_i - 1 >= limit_i_base:
						n_idx = cc_k * wh_ww + (cc_i - 1) * ww + cc_j
						if _map3dnum_flat[n_idx] == curmap3dnum and visited[cc_k * (rh * rw) + (cc_i - 1 - limit_i_base) * rw + lc_j] == 0:
							que.append([cc_i - 1, cc_j, cc_k])
					if cc_i + 1 < limit_i_max:
						n_idx = cc_k * wh_ww + (cc_i + 1) * ww + cc_j
						if _map3dnum_flat[n_idx] == curmap3dnum and visited[cc_k * (rh * rw) + (cc_i + 1 - limit_i_base) * rw + lc_j] == 0:
							que.append([cc_i + 1, cc_j, cc_k])
					if cc_j - 1 >= limit_j_base:
						n_idx = cc_k * wh_ww + cc_i * ww + (cc_j - 1)
						if _map3dnum_flat[n_idx] == curmap3dnum and visited[cc_k * (rh * rw) + lc_i * rw + (lc_j - 1)] == 0:
							que.append([cc_i, cc_j - 1, cc_k])
					if cc_j + 1 < limit_j_max:
						n_idx = cc_k * wh_ww + cc_i * ww + (cc_j + 1)
						if _map3dnum_flat[n_idx] == curmap3dnum and visited[cc_k * (rh * rw) + lc_i * rw + (lc_j + 1)] == 0:
							que.append([cc_i, cc_j + 1, cc_k])
					if cc_k - 1 >= 0:
						n_idx = (cc_k - 1) * wh_ww + cc_i * ww + cc_j
						if _map3dnum_flat[n_idx] == curmap3dnum and visited[(cc_k - 1) * (rh * rw) + lc_i * rw + lc_j] == 0:
							que.append([cc_i, cc_j, cc_k - 1])
					if cc_k + 1 < max_k:
						n_idx = (cc_k + 1) * wh_ww + cc_i * ww + c_j
						if _map3dnum_flat[n_idx] == curmap3dnum and visited[(cc_k + 1) * (rh * rw) + lc_i * rw + lc_j] == 0:
							que.append([cc_i, cc_j, cc_k + 1])
							
	var exposed_blocks_new = 0
	for group in new_multi:
		exposed_blocks_new += group[1] # group[1] is count
		
	var col_count_new = new_col.size()
	
	var msg = "[VERIFY] Chunk(" + str(i1) + "," + str(j1) + ") "
	if exposed_blocks_sync == exposed_blocks_new:
		msg += "OK: Blocks match (" + str(exposed_blocks_new) + ") "
	else:
		msg += "ERROR: Mismatch! Sync=" + str(exposed_blocks_sync) + " New=" + str(exposed_blocks_new) + " "
		
	msg += "Instances=" + str(new_multi.size()) + " Col=" + str(col_count_new)
	print(msg)

func _thread_calculate_chunk_data(i1: int, j1: int, result_container: Array):
	var local_multi = []
	var local_col = []
	
	var wh = worldh
	var ww = worldw
	var wh_ww = wh * ww
	var max_k = d

	var limit_i_base = i1 * rh
	var limit_i_max = limit_i_base + rh
	if limit_i_max > wh: limit_i_max = wh
	
	var limit_j_base = j1 * rw
	var limit_j_max = limit_j_base + rw
	if limit_j_max > ww: limit_j_max = ww

	var visited_mesh = PackedByteArray()
	visited_mesh.resize(max_k * rh * rw)
	visited_mesh.fill(0)

	var group_list = []
	for k in range(max_k):
		var k_wh_ww = k * wh_ww
		var c_k_rh_rw = k * (rh * rw)
		for gi in range(limit_i_base, limit_i_max):
			var gi_ww = gi * ww
			var c_i_rw = (gi - limit_i_base) * rw
			for gj in range(limit_j_base, limit_j_max):
				var idx = k_wh_ww + gi_ww + gj
				var curmap3dnum = _map3dnum_flat[idx]
				
				var lc_idx = c_k_rh_rw + c_i_rw + (gj - limit_j_base)
				if visited_mesh[lc_idx] != 0 or curmap3dnum == -1:
					continue
					
				var que = [] 
				que.append([gi, gj, k])
				var new_group_idx = len(group_list)
				group_list.append([])
				var head = 0
				
				while head < que.size():
					var cur = que[head]
					head += 1
					var c_i = cur[0]
					var c_j = cur[1]
					var c_k = cur[2]
					
					var c_lc_idx = c_k * (rh * rw) + (c_i - limit_i_base) * rw + (c_j - limit_j_base)
					if visited_mesh[c_lc_idx] != 0:
						continue
					visited_mesh[c_lc_idx] = 1
					group_list[new_group_idx].push_back(cur)
					
					if c_i - 1 >= limit_i_base:
						var n_idx = c_k * wh_ww + (c_i - 1) * ww + c_j
						var n_lc_idx = c_k * (rh * rw) + (c_i - 1 - limit_i_base) * rw + (c_j - limit_j_base)
						if _map3dnum_flat[n_idx] == curmap3dnum and visited_mesh[n_lc_idx] == 0:
							que.append([c_i - 1, c_j, c_k])
					if c_i + 1 < limit_i_max:
						var n_idx = c_k * wh_ww + (c_i + 1) * ww + c_j
						var n_lc_idx = c_k * (rh * rw) + (c_i + 1 - limit_i_base) * rw + (c_j - limit_j_base)
						if _map3dnum_flat[n_idx] == curmap3dnum and visited_mesh[n_lc_idx] == 0:
							que.append([c_i + 1, c_j, c_k])
					if c_j - 1 >= limit_j_base:
						var n_idx = c_k * wh_ww + c_i * ww + (c_j - 1)
						var n_lc_idx = c_k * (rh * rw) + (c_i - limit_i_base) * rw + (c_j - 1 - limit_j_base)
						if _map3dnum_flat[n_idx] == curmap3dnum and visited_mesh[n_lc_idx] == 0:
							que.append([c_i, c_j - 1, c_k])
					if c_j + 1 < limit_j_max:
						var n_idx = c_k * wh_ww + c_i * ww + (c_j + 1)
						var n_lc_idx = c_k * (rh * rw) + (c_i - limit_i_base) * rw + (c_j + 1 - limit_j_base)
						if _map3dnum_flat[n_idx] == curmap3dnum and visited_mesh[n_lc_idx] == 0:
							que.append([c_i, c_j + 1, c_k])
					if c_k - 1 >= 0:
						var n_idx = (c_k - 1) * wh_ww + c_i * ww + c_j
						var n_lc_idx = (c_k - 1) * (rh * rw) + (c_i - limit_i_base) * rw + (c_j - limit_j_base)
						if _map3dnum_flat[n_idx] == curmap3dnum and visited_mesh[n_lc_idx] == 0:
							que.append([c_i, c_j, c_k - 1])
					if c_k + 1 < max_k:
						var n_idx = (c_k + 1) * wh_ww + c_i * ww + c_j
						var n_lc_idx = (c_k + 1) * (rh * rw) + (c_i - limit_i_base) * rw + (c_j - limit_j_base)
						if _map3dnum_flat[n_idx] == curmap3dnum and visited_mesh[n_lc_idx] == 0:
							que.append([c_i, c_j, c_k + 1])

	for group in group_list:
		var buf = PackedFloat32Array()
		var count = group.size()
		if count == 0: continue
		buf.resize(count * 12)
		var b_idx = 0
		for k in range(count):
			var blockt = group[k]
			buf[b_idx+0] = 1.0; buf[b_idx+1] = 0.0; buf[b_idx+2] = 0.0
			buf[b_idx+3] = 0.0; buf[b_idx+4] = 1.0; buf[b_idx+5] = 0.0
			buf[b_idx+6] = 0.0; buf[b_idx+7] = 0.0; buf[b_idx+8] = 1.0
			buf[b_idx+9] = float(blockt[0])
			buf[b_idx+10] = float(blockt[2])
			buf[b_idx+11] = float(blockt[1])
			b_idx += 12
		local_multi.append([buf, count, group[0]])

	var _chunk_mask_flat = PackedByteArray()
	_chunk_mask_flat.resize(max_k * rh * rw)
	_chunk_mask_flat.fill(0)
	
	for k in range(max_k):
		var k_wh_ww = k * wh_ww
		var c_k_rh_rw = k * (rh * rw)
		for gi in range(limit_i_base, limit_i_max):
			var gi_ww = gi * ww
			var c_i = gi - limit_i_base
			var c_i_rw = c_i * rw
			for gj in range(limit_j_base, limit_j_max):
				var idx = k_wh_ww + gi_ww + gj
				var c_j = gj - limit_j_base
				var c_idx = c_k_rh_rw + c_i_rw + c_j
				
				if _chunk_mask_flat[c_idx] == 0 and _map3dnum_flat[idx] != -1:
					var current_material = _map3dnum_flat[idx]
					var depth = 1
					while gj + depth < limit_j_max and _chunk_mask_flat[c_idx + depth] == 0 and _map3dnum_flat[idx + depth] == current_material:
						depth += 1
					
					var width = 1
					var done = false
					while gi + width < limit_i_max and not done:
						var w_idx = k_wh_ww + (gi + width) * ww + gj
						var c_w_idx = c_k_rh_rw + (c_i + width) * rw + c_j
						for l in range(depth):
							if _chunk_mask_flat[c_w_idx + l] != 0 or _map3dnum_flat[w_idx + l] != current_material:
								done = true
								break
						if not done:
							width += 1
					
					var height = 1
					done = false
					while k + height < max_k and not done:
						var h_wh_ww = (k + height) * wh_ww
						var c_h_rh_rw = (k + height) * (rh * rw)
						for m in range(width):
							var w_idx = h_wh_ww + (gi + m) * ww + gj
							var c_w_idx = c_h_rh_rw + (c_i + m) * rw + c_j
							for l in range(depth):
								if _chunk_mask_flat[c_w_idx + l] != 0 or _map3dnum_flat[w_idx + l] != current_material:
									done = true
									break
							if done: break
						if not done:
							height += 1
					
					var shape_size = Vector3(width, height, depth)
					var shape_pos = Vector3(gi + width/2.0, k + height/2.0, gj + depth/2.0) - Vector3(0.5, 0.5, 0.5)
					local_col.append([shape_size, shape_pos])
					
					for ik in range(height):
						var c_h_rh_rw = (k + ik) * (rh * rw)
						for ii in range(width):
							var c_w_idx = c_h_rh_rw + (c_i + ii) * rw + c_j
							for ij in range(depth):
								_chunk_mask_flat[c_w_idx + ij] = 1

	result_container.append(local_multi)
	result_container.append(local_col)

func calculate_chunk_data(i1: int, j1: int):
	pass

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
	
	if mazeentrance_candidate.is_empty():
		mazeentrance_candidate.append([Vector3(maze_start.x, height-diff+10+entrance_height_radius, maze_start.y), 0, 0])
		
	return mazeentrance_candidate[_rng.randi() % mazeentrance_candidate.size()]
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
					_map3dnum_flat[(worldpos.y) * worldh * worldw + (worldpos.x) * worldw + (worldpos.z)] = -1
				else:
					_map3dnum_flat[(worldpos.y) * worldh * worldw + (worldpos.x) * worldw + (worldpos.z)] = 5

func find_best_surface_anchor(x_min: int, x_max: int, z_min: int, z_max: int, ref_pos: Vector3, dir: Vector3, is_closest: bool = false, required_block: int = -99, min_dist_to_target: Vector3 = Vector3.ZERO, target_safe_dist: float = 0.0) -> Vector3:
	var best_pos = Vector3.ZERO
	var best_score = -1e9
	var best_dist = 1e9
	
	for x in range(x_min, x_max):
		for z in range(z_min, z_max):
			for y in range(d - 2, 0, -1): # Scan from top to bottom
				var block = _map3dnum_flat[(y) * worldh * worldw + (x) * worldw + (z)]
				if block != -1 and block != 1 and _map3dnum_flat[(y+1) * worldh * worldw + (x) * worldw + (z)] == -1:
					if required_block != -99 and block != required_block:
						continue
					
					var pos = Vector3(x, y, z)
					
					# Enforce a safe horizontal distance from the target if specified
					if target_safe_dist > 0.0:
						var horiz_dist = Vector2(pos.x, pos.z).distance_to(Vector2(min_dist_to_target.x, min_dist_to_target.z))
						if horiz_dist < target_safe_dist:
							continue
							
					if is_closest:
						var dist = pos.distance_to(ref_pos)
						if dist < best_dist:
							best_dist = dist
							best_pos = pos
					else:
						# Directional alignment
						var vec = (pos - ref_pos).normalized()
						var dot = vec.dot(dir)
						
						# When pushing towards an edge, we want the point to be as far as possible
						# along the direction vector.
						var projection = (pos - ref_pos).dot(dir)
						
						# The score is primarily the projection (how far it goes in the desired direction),
						# penalized slightly if it deviates from the exact angle.
						var score = projection
						if score > best_score:
							best_score = score
							best_pos = pos
					break
	return best_pos


func find_edge_on_same_landmass(start_pos: Vector3, dir_to_target: Vector3) -> Vector3:
	var q = []
	var visited = {}
	var best_pos = start_pos
	var best_score = -1e9
	
	q.append(start_pos)
	visited[str(start_pos.x) + "," + str(start_pos.y) + "," + str(start_pos.z)] = 1
	
	var attempts = 0
	while q.size() > 0 and attempts < 10000:
		attempts += 1
		var curr = q.pop_front()
		
		# Score this point
		var projection = (curr - start_pos).dot(dir_to_target)
		if projection > best_score:
			best_score = projection
			best_pos = curr
			
		# Check neighbors (N, S, E, W)
		for d_pos in [[0, 1], [1, 0], [0, -1], [-1, 0]]:
			var nx = curr.x + d_pos[0]
			var nz = curr.z + d_pos[1]
			
			# Search vertically for the surface at (nx, nz)
			var surface_y = -1
			for ny in range(int(curr.y) + 3, int(curr.y) - 4, -1):
				if ny > 0 and ny < d - 1:
					var b = _map3dnum_flat[(ny) * worldh * worldw + (nx) * worldw + (nz)]
					if b != -1 and b != 1 and _map3dnum_flat[(ny+1) * worldh * worldw + (nx) * worldw + (nz)] == -1:
						surface_y = ny
						break
						
			if surface_y != -1:
				# It's a valid surface block.
				var n_pos = Vector3(nx, surface_y, nz)
				var key = str(n_pos.x) + "," + str(n_pos.y) + "," + str(n_pos.z)
				if not visited.has(key):
					visited[key] = 1
					q.append(n_pos)
					
	return best_pos

func generate_debug_report_and_image(tunnel_exit: Vector3, a_start: Vector3, a_end: Vector3, b_start: Vector3, b_end: Vector3):
	print("========== TERRAIN GENERATION DEBUG REPORT ==========")
	print("- Tunnel Exit: ", tunnel_exit)
	
	var desert_x_min = 9999
	var desert_x_max = -1
	var desert_z_min = 9999
	var desert_z_max = -1
	var desert_y_min = 9999
	var desert_y_max = -1
	
	var snow_x_min = 9999
	var snow_x_max = -1
	var snow_z_min = 9999
	var snow_z_max = -1
	var snow_y_min = 9999
	var snow_y_max = -1
	
	var castle_x_min = 9999
	var castle_x_max = -1
	var castle_z_min = 9999
	var castle_z_max = -1
	var castle_y_min = 9999
	var castle_y_max = -1
	
	# We create a 2D map image for visualization
	var img = Image.create(worldh, worldw, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1)) # Black background
	
	# Scan the entire map surface
	for x in range(worldh):
		for z in range(worldw):
			var surface_y = -1
			var surface_id = -1
			# Scan from top to bottom
			for y in range(d - 2, 0, -1):
				var b = _map3dnum_flat[(y) * worldh * worldw + (x) * worldw + (z)]
				if b != -1:
					surface_y = y
					surface_id = b
					break
			
			if surface_y != -1:
				# Color mapping
				var col = Color(0, 0, 0)
				if surface_id == 0: col = Color(0.2, 0.6, 0.2) # Grass
				elif surface_id == 1: col = Color(0.1, 0.3, 0.8) # Water
				elif surface_id == 2: col = Color(0.5, 0.5, 0.5) # Rock
				elif surface_id == 3: col = Color(1.0, 1.0, 1.0) # Snow
				elif surface_id == 5: col = Color(0.3, 0.1, 0.1) # Wall/Castle
				else: col = Color(1, 0, 1) # Unknown
				
				img.set_pixel(x, z, col)
				
				# Update bounding boxes
				# Desert (around w/2)
				if x >= desert_start_h and x < desert_start_h + h and z >= desert_start_w and z < desert_start_w + w:
					if surface_id != 1: # Ignore water
						desert_x_min = min(desert_x_min, x)
						desert_x_max = max(desert_x_max, x)
						desert_z_min = min(desert_z_min, z)
						desert_z_max = max(desert_z_max, z)
						desert_y_min = min(desert_y_min, surface_y)
						desert_y_max = max(desert_y_max, surface_y)
				
				# Snow (ID 3)
				if surface_id == 3:
					snow_x_min = min(snow_x_min, x)
					snow_x_max = max(snow_x_max, x)
					snow_z_min = min(snow_z_min, z)
					snow_z_max = max(snow_z_max, z)
					snow_y_min = min(snow_y_min, surface_y)
					snow_y_max = max(snow_y_max, surface_y)
					
				# Castle (ID 2 or 5 in castle area)
				if x >= castle_start_h and x < castle_start_h + h and z >= castle_start_w and z < castle_start_w + w:
					if surface_id == 2 or surface_id == 5:
						castle_x_min = min(castle_x_min, x)
						castle_x_max = max(castle_x_max, x)
						castle_z_min = min(castle_z_min, z)
						castle_z_max = max(castle_z_max, z)
						castle_y_min = min(castle_y_min, surface_y)
						castle_y_max = max(castle_y_max, surface_y)

	print("- Desert Bounding Box: X(", desert_x_min, "-", desert_x_max, ") Z(", desert_z_min, "-", desert_z_max, ") Y(", desert_y_min, "-", desert_y_max, ")")
	print("- Snow Bounding Box: X(", snow_x_min, "-", snow_x_max, ") Z(", snow_z_min, "-", snow_z_max, ") Y(", snow_y_min, "-", snow_y_max, ")")
	print("- Castle Bounding Box: X(", castle_x_min, "-", castle_x_max, ") Z(", castle_z_min, "-", castle_z_max, ") Y(", castle_y_min, "-", castle_y_max, ")")
	
	var get_block = func(pos: Vector3) -> String:
		if pos == Vector3.ZERO: return "N/A"
		return str(_map3dnum_flat[(int(pos.y)) * worldh * worldw + (int(pos.x)) * worldw + (int(pos.z))])
	
	print("- Bridge A Start: ", a_start, " (ID: ", get_block.call(a_start), ")")
	print("- Bridge A End: ", a_end, " (ID: ", get_block.call(a_end), ")")
	print("- Bridge B Start: ", b_start, " (ID: ", get_block.call(b_start), ")")
	print("- Bridge B End: ", b_end, " (ID: ", get_block.call(b_end), ")")
	
	if a_end != Vector3.ZERO and b_start != Vector3.ZERO:
		var horiz_dist_ab = Vector2(a_end.x, a_end.z).distance_to(Vector2(b_start.x, b_start.z))
		print("- Horizontal Distance from Bridge A End to Bridge B Start: ", horiz_dist_ab)
		
	if b_start != Vector3.ZERO and b_end != Vector3.ZERO:
		var horiz_dist_b = Vector2(b_start.x, b_start.z).distance_to(Vector2(b_end.x, b_end.z))
		var height_diff_b = b_end.y - b_start.y
		print("- Bridge B Horizontal Distance: ", horiz_dist_b)
		print("- Bridge B Height Difference: ", height_diff_b)
		
	# Draw bridges as 3x3 red dots on the image
	var draw_dot = func(pos: Vector3, color: Color):
		if pos == Vector3.ZERO: return
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var px = int(pos.x) + dx
				var pz = int(pos.z) + dz
				if px >= 0 and px < worldh and pz >= 0 and pz < worldw:
					img.set_pixel(px, pz, color)
					
	draw_dot.call(tunnel_exit, Color(1, 1, 0)) # Yellow for tunnel exit
	draw_dot.call(a_start, Color(1, 0, 0)) # Red for bridges
	draw_dot.call(a_end, Color(1, 0, 0))
	draw_dot.call(b_start, Color(1, 0, 1)) # Magenta for Bridge B
	draw_dot.call(b_end, Color(1, 0, 1))
	
	var save_path = "C:/Users/81809/Downloads/roguelikepuzzle2/reference/godot4-procedurally-generated-terrain/terrain_map_debug.png"
	img.save_png(save_path)
	print("- Saved 2D Terrain Map to: ", save_path)
	
	var log_file = FileAccess.open("C:/Users/81809/Downloads/roguelikepuzzle2/reference/godot4-procedurally-generated-terrain/debug_report.txt", FileAccess.WRITE)
	if log_file:
		log_file.store_line("========== TERRAIN GENERATION DEBUG REPORT ==========")
		log_file.store_line("- Tunnel Exit: " + str(tunnel_exit))
		log_file.store_line("- Desert Bounding Box: X(" + str(desert_x_min) + "-" + str(desert_x_max) + ") Z(" + str(desert_z_min) + "-" + str(desert_z_max) + ") Y(" + str(desert_y_min) + "-" + str(desert_y_max) + ")")
		log_file.store_line("- Snow Bounding Box: X(" + str(snow_x_min) + "-" + str(snow_x_max) + ") Z(" + str(snow_z_min) + "-" + str(snow_z_max) + ") Y(" + str(snow_y_min) + "-" + str(snow_y_max) + ")")
		log_file.store_line("- Castle Bounding Box: X(" + str(castle_x_min) + "-" + str(castle_x_max) + ") Z(" + str(castle_z_min) + "-" + str(castle_z_max) + ") Y(" + str(castle_y_min) + "-" + str(castle_y_max) + ")")
		log_file.store_line("- Bridge A Start: " + str(a_start) + " (ID: " + get_block.call(a_start) + ")")
		log_file.store_line("- Bridge A End: " + str(a_end) + " (ID: " + get_block.call(a_end) + ")")
		log_file.store_line("- Bridge B Start: " + str(b_start) + " (ID: " + get_block.call(b_start) + ")")
		log_file.store_line("- Bridge B End: " + str(b_end) + " (ID: " + get_block.call(b_end) + ")")
		if a_end != Vector3.ZERO and b_start != Vector3.ZERO:
			log_file.store_line("- Horizontal Distance A_end to B_start: " + str(Vector2(a_end.x, a_end.z).distance_to(Vector2(b_start.x, b_start.z))))
		if b_start != Vector3.ZERO and b_end != Vector3.ZERO:
			log_file.store_line("- Bridge B Horizontal Distance: " + str(Vector2(b_start.x, b_start.z).distance_to(Vector2(b_end.x, b_end.z))))
			log_file.store_line("- Bridge B Height Difference: " + str(b_end.y - b_start.y))
	
	print("=====================================================")


func find_highest_anchor_in_rect(x_min: int, x_max: int, z_min: int, z_max: int, required_block: int = -99) -> Vector3:
	var best_pos = Vector3.ZERO
	var best_y = -1
	
	for x in range(x_min, x_max):
		for z in range(z_min, z_max):
			for y in range(d - 2, 0, -1):
				var block = _map3dnum_flat[(y) * worldh * worldw + (x) * worldw + (z)]
				if block != -1 and block != 1 and _map3dnum_flat[(y+1) * worldh * worldw + (x) * worldw + (z)] == -1:
					if required_block != -99 and block != required_block:
						continue
					
					# Find the absolute highest valid point in this rectangle
					if y > best_y:
						best_y = y
						best_pos = Vector3(x, y, z)
					break
	return best_pos

func build_bridge(p0: Vector3, p3: Vector3):
	var steps = int(p0.distance_to(p3) * 5)
	var width = 2
	for i in range(steps+1):
		var t = float(i)/steps
		var p_cur = p0.lerp(p3, t)
		var dir = (p3 - p0).normalized()
		var right = dir.cross(Vector3.UP).normalized()
		if right.length_squared() < 0.1:
			right = Vector3(1, 0, 0)
			
		for j in range(-width, width+1):
			var worldpos_f = p_cur + (right * j)
			var worldpos = Vector3i(round(worldpos_f.x), round(worldpos_f.y), round(worldpos_f.z))
			if worldpos.x < 0 or worldpos.x >= worldh or worldpos.y < 0 or worldpos.y >= d or worldpos.z < 0 or worldpos.z >= worldw:
				continue
			
			for k in range(3): # Bridge thickness
				var y = worldpos.y - k
				if y >= 0 and y < d:
					var cur_block = _map3dnum_flat[(y) * worldh * worldw + (worldpos.x) * worldw + (worldpos.z)]
					# Force overwrite anything in the path to build the bridge, cutting through floating islands.
					# But don't overwrite castle walls (5)
					if cur_block != 5:
						_map3dnum_flat[(y) * worldh * worldw + (worldpos.x) * worldw + (worldpos.z)] = 2 # Stone bridge
			for k in range(1, 6): # Clear air above bridge
				var y = worldpos.y + k
				if y >= 0 and y < d:
					var cur_block = _map3dnum_flat[(y) * worldh * worldw + (worldpos.x) * worldw + (worldpos.z)]
					# Force clear air, cutting through floating islands. Don't cut through castle walls (5).
					if cur_block != 5:
						_map3dnum_flat[(y) * worldh * worldw + (worldpos.x) * worldw + (worldpos.z)] = -1

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

func sea(map:Array, n:int = 4, progress_weight: float = 0.0):
	var flat_map = PackedFloat32Array()
	flat_map.resize(h * w)
	var idx = 0
	for i in range(h):
		for j in range(w):
			flat_map[idx] = map[i][j]
			idx += 1
			
	if progress_weight > 0: await _add_loading_progress(progress_weight / 3.0)
	else: await get_tree().process_frame
	
	flat_map.sort()
	
	if progress_weight > 0: await _add_loading_progress(progress_weight / 3.0)
	else: await get_tree().process_frame
	
	var threshold_idx = int(float(h * w) / float(n))
	threshold_idx = clamp(threshold_idx, 0, h * w - 1)
	SEAHEIGHT = flat_map[threshold_idx]
	
	for i in range(h):
		for j in range(w):
			if map[i][j] <= SEAHEIGHT:
				map[i][j] = SEAHEIGHT
				
	if progress_weight > 0: await _add_loading_progress(progress_weight / 3.0)
	else: await get_tree().process_frame
	
	var seablocksum = 0
	return [map, seablocksum]
func snow_leveling(map:Array):
	await get_tree().process_frame
	var sum = []
	var sum_height = []
	var battle_point_candidate = []
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
		sum.append(arrw)
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
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
	var res = battle_point_candidate[_rng.randi() % battle_point_candidate.size()]
	if res == null:
		# Fallback: Find the highest point in the map to place the snow boss
		var highest_i = int(h/2)
		var highest_j = int(w/2)
		var max_h = 0.0
		for i in range(5, h-5):
			for j in range(5, w-5):
				if map[i][j] > max_h:
					max_h = map[i][j]
					highest_i = i
					highest_j = j
		# We don't have a 10x10 area of snow, but we force this highest point.
		res = [highest_i, highest_j, max_h * (battle_height * battle_width)]
	
	var target_h = float(res[2]/(battle_height*battle_width))
	for i in range(-5, battle_height+5):
		for j in range(-5, battle_width+5):
			if res[0]+i >= 0 and res[0]+i < h and res[1]+j >= 0 and res[1]+j < w:
				if i >= 0 and i < battle_height and j >= 0 and j < battle_width:
					map[res[0]+i][res[1]+j] = target_h
				else:
					# Calculate distance from the edge of the flat stage
					var dist_i = 0
					if i < 0: dist_i = -i
					elif i >= battle_height: dist_i = i - battle_height + 1
					
					var dist_j = 0
					if j < 0: dist_j = -j
					elif j >= battle_width: dist_j = j - battle_width + 1
					
					var dist = max(dist_i, dist_j)
					var original_h = map[res[0]+i][res[1]+j]
					# Create a smooth ramp/slope down to the original terrain
					var blend = max(0.0, 1.0 - (dist / 6.0))
					map[res[0]+i][res[1]+j] = target_h * blend + original_h * (1.0 - blend)
	await _add_loading_progress(5.0)
	return [map,res[0],res[1]]
func snow_leveling1(map:Array,pos:Vector2):
	var sum = []
	var sum_height = []
	var battle_point_candidate = []
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
		sum.append(arrw)
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
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
			if i >= pos.x and i < pos.x+battle_height:
				continue
			if j >= pos.y and j < pos.y+battle_width:
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
			if i+shop_height-1 >= h:
				continue
			if j+shop_width-1 >= w:
				continue
			cursum += sum[i+shop_height-1][j+shop_width-1]
			cur_height += sum_height[i+shop_height-1][j+shop_width-1]
			if i-1 >= 0:
				cursum -= sum[i-1][j+shop_width-1]
				cur_height -= sum_height[i-1][j+shop_width-1]
			if j-1 >= 0:
				cursum -= sum[i+shop_height-1][j-1]
				cur_height -= sum_height[i+shop_height-1][j-1]
			if i-1 >= 0 and j-1 >= 0:
				cursum += sum[i-1][j-1]
				cur_height += sum_height[i-1][j-1]
			if cursum == shop_height*shop_width:
				battle_point_candidate.append([i,j,cur_height])
	var res = battle_point_candidate[_rng.randi() % battle_point_candidate.size()]
	if res == null:
		res = [h/2, w/2, 0.0]
	
	for i in range(shop_height):
		for j in range(shop_width):
			map[res[0]+i][res[1]+j] = float(res[2]/(shop_height*shop_width))
	return [map,res[0],res[1]]
func plane_leveling(map:Array):
	var sum = []
	var sum_height = []
	var battle_point_candidate = []
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
		sum.append(arrw)
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
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
	var res = battle_point_candidate[_rng.randi() % battle_point_candidate.size()]
	if res == null:
		res = [h/2, w/2, 0.0]
	
	for i in range(battle_height):
		for j in range(battle_width):
			map[res[0]+i][res[1]+j] = float(res[2]/(battle_height*battle_width))
	await _add_loading_progress(12.0)
	return [map,res[0],res[1]]
func plane_leveling1(map:Array,pos:Vector2):
	var sum = []
	var sum_height = []
	var battle_point_candidate = []
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
		sum.append(arrw)
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
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
			if i >= pos.x and i < pos.x+battle_height:
				continue
			if j >= pos.y and j < pos.y+battle_width:
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
			if i+shop_height-1 >= h:
				continue
			if j+shop_width-1 >= w:
				continue
			cursum += sum[i+shop_height-1][j+shop_width-1]
			cur_height += sum_height[i+shop_height-1][j+shop_width-1]
			if i-1 >= 0:
				cursum -= sum[i-1][j+shop_width-1]
				cur_height -= sum_height[i-1][j+shop_width-1]
			if j-1 >= 0:
				cursum -= sum[i+shop_height-1][j-1]
				cur_height -= sum_height[i+shop_height-1][j-1]
			if i-1 >= 0 and j-1 >= 0:
				cursum += sum[i-1][j-1]
				cur_height += sum_height[i-1][j-1]
			if cursum == shop_height*shop_width:
				battle_point_candidate.append([i,j,cur_height])
	var res = battle_point_candidate[_rng.randi() % battle_point_candidate.size()]
	if res == null:
		res = [h/2, w/2, 0.0]
	
	for i in range(shop_height):
		for j in range(shop_width):
			map[res[0]+i][res[1]+j] = float(res[2]/(shop_height*shop_width))
	return [map,res[0],res[1]]
func desert_leveling(map:Array):
	var sum = []
	var sum_height = []
	var battle_point_candidate = []
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
		sum.append(arrw)
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
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
	var res = battle_point_candidate[_rng.randi() % battle_point_candidate.size()]
	if res == null:
		# Fallback: Find the highest point in the map to place the snow boss
		var highest_i = int(h/2)
		var highest_j = int(w/2)
		var max_h = 0.0
		for i in range(5, h-5):
			for j in range(5, w-5):
				if map[i][j] > max_h:
					max_h = map[i][j]
					highest_i = i
					highest_j = j
		# We don't have a 10x10 area of snow, but we force this highest point.
		res = [highest_i, highest_j, max_h * (battle_height * battle_width)]
	
	var target_h = float(res[2]/(battle_height*battle_width))
	for i in range(-5, battle_height+5):
		for j in range(-5, battle_width+5):
			if res[0]+i >= 0 and res[0]+i < h and res[1]+j >= 0 and res[1]+j < w:
				if i >= 0 and i < battle_height and j >= 0 and j < battle_width:
					map[res[0]+i][res[1]+j] = target_h
				else:
					# Calculate distance from the edge of the flat stage
					var dist_i = 0
					if i < 0: dist_i = -i
					elif i >= battle_height: dist_i = i - battle_height + 1
					
					var dist_j = 0
					if j < 0: dist_j = -j
					elif j >= battle_width: dist_j = j - battle_width + 1
					
					var dist = max(dist_i, dist_j)
					var original_h = map[res[0]+i][res[1]+j]
					# Create a smooth ramp/slope down to the original terrain
					var blend = max(0.0, 1.0 - (dist / 6.0))
					map[res[0]+i][res[1]+j] = target_h * blend + original_h * (1.0 - blend)
	await _add_loading_progress(5.0)
	return [map,res[0],res[1]]
func desert_leveling1(map:Array,pos:Vector2):
	var sum = []
	var sum_height = []
	var battle_point_candidate = []
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
		sum.append(arrw)
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
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
			if i >= pos.x and i < pos.x+battle_height:
				continue
			if j >= pos.y and j < pos.y+battle_width:
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
			if i+shop_height-1 >= h:
				continue
			if j+shop_width-1 >= w:
				continue
			cursum += sum[i+shop_height-1][j+shop_width-1]
			cur_height += sum_height[i+shop_height-1][j+shop_width-1]
			if i-1 >= 0:
				cursum -= sum[i-1][j+shop_width-1]
				cur_height -= sum_height[i-1][j+shop_width-1]
			if j-1 >= 0:
				cursum -= sum[i+shop_height-1][j-1]
				cur_height -= sum_height[i+shop_height-1][j-1]
			if i-1 >= 0 and j-1 >= 0:
				cursum += sum[i-1][j-1]
				cur_height += sum_height[i-1][j-1]
			if cursum == shop_height*shop_width:
				battle_point_candidate.append([i,j,cur_height])
	var res = battle_point_candidate[_rng.randi() % battle_point_candidate.size()]
	if res == null:
		res = [h/2, w/2, 0.0]
	
	for i in range(shop_height):
		for j in range(shop_width):
			map[res[0]+i][res[1]+j] = float(res[2]/(shop_height*shop_width))
	return [map,res[0],res[1]]
func cave_leveling(map:Array,floor:Array):
	var sum = []
	var sum_height = []
	var battle_point_candidate = []
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
		sum.append(arrw)
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
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
	var res = battle_point_candidate[_rng.randi() % battle_point_candidate.size()]
	if res == null:
		res = [h/2, w/2, 0.0]
	for i in range(battle_height):
		for j in range(battle_width):
			floor[res[0]+i][res[1]+j] = float(res[2]/(battle_height*battle_width))
	return [floor,res[0],res[1]]
func cave_leveling1(map:Array,floor:Array,pos:Vector2):
	var sum = []
	var sum_height = []
	var battle_point_candidate = []
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
		sum.append(arrw)
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
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
			if i >= pos.x and i < pos.x+shop_height:
				continue
			if j >= pos.y and j < pos.y+shop_width:
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
			if i+shop_height-1 >= h:
				continue
			if j+shop_width-1 >= w:
				continue
			cursum += sum[i+shop_height-1][j+shop_width-1]
			cur_height += sum_height[i+shop_height-1][j+shop_width-1]
			if i-1 >= 0:
				cursum -= sum[i-1][j+shop_width-1]
				cur_height -= sum_height[i-1][j+shop_width-1]
			if j-1 >= 0:
				cursum -= sum[i+shop_height-1][j-1]
				cur_height -= sum_height[i+shop_height-1][j-1]
			if i-1 >= 0 and j-1 >= 0:
				cursum += sum[i-1][j-1]
				cur_height += sum_height[i-1][j-1]
			if cursum == shop_height*shop_width:
				battle_point_candidate.append([i,j,cur_height])
	var res = battle_point_candidate[_rng.randi() % battle_point_candidate.size()]
	if res == null:
		res = [h/2, w/2, 0.0]
	for i in range(shop_height):
		for j in range(shop_width):
			floor[res[0]+i][res[1]+j] = float(res[2]/(shop_height*shop_width))
	return [floor,res[0],res[1]]
func castle_leveling(map:Array):
	var sum = []
	var sum_height = []
	var battle_point_candidate = []
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
		sum.append(arrw)
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
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
	var res = battle_point_candidate[_rng.randi() % battle_point_candidate.size()]
	if res == null:
		# Fallback: Find the highest point in the map to place the snow boss
		var highest_i = int(h/2)
		var highest_j = int(w/2)
		var max_h = 0.0
		for i in range(5, h-5):
			for j in range(5, w-5):
				if map[i][j] > max_h:
					max_h = map[i][j]
					highest_i = i
					highest_j = j
		# We don't have a 10x10 area of snow, but we force this highest point.
		res = [highest_i, highest_j, max_h * (battle_height * battle_width)]
	
	var target_h = float(res[2]/(battle_height*battle_width))
	for i in range(-5, battle_height+5):
		for j in range(-5, battle_width+5):
			if res[0]+i >= 0 and res[0]+i < h and res[1]+j >= 0 and res[1]+j < w:
				if i >= 0 and i < battle_height and j >= 0 and j < battle_width:
					map[res[0]+i][res[1]+j] = target_h
				else:
					# Calculate distance from the edge of the flat stage
					var dist_i = 0
					if i < 0: dist_i = -i
					elif i >= battle_height: dist_i = i - battle_height + 1
					
					var dist_j = 0
					if j < 0: dist_j = -j
					elif j >= battle_width: dist_j = j - battle_width + 1
					
					var dist = max(dist_i, dist_j)
					var original_h = map[res[0]+i][res[1]+j]
					# Create a smooth ramp/slope down to the original terrain
					var blend = max(0.0, 1.0 - (dist / 6.0))
					map[res[0]+i][res[1]+j] = target_h * blend + original_h * (1.0 - blend)
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
	await get_tree().process_frame
	var castle_scene = load(castle_path)
	var castle_instance:Node3D = castle_scene.instantiate()
	var base = []
	var baseheightmin = []
	await _add_loading_progress(0.29411764705882354)
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
	await smooth_terrain(10,0.5,base, 5.0)
	await get_tree().process_frame
	var baseheightmi = 1e9
	await _add_loading_progress(0.29411764705882354)
	for i in range(h):
		for j in range(w):
			baseheightmi = min(baseheightmi,base[i][j])
	await _add_loading_progress(0.29411764705882354)
	for i in range(h):
		for j in range(w):
			base[i][j] -= baseheightmi
	await get_tree().process_frame
	var resbase = await sea(base)
	base = resbase[0]
	baseheightmi = 1e9
	await _add_loading_progress(0.29411764705882354)
	for i in range(h):
		for j in range(w):
			baseheightmi = min(baseheightmi,base[i][j])
	await _add_loading_progress(0.29411764705882354)
	for i in range(h):
		for j in range(w):
			base[i][j] -= baseheightmi
	baseheightma = 0
	await _add_loading_progress(0.29411764705882354)
	for i in range(h):
		for j in range(w):
			baseheightma = max(baseheightma,base[i][j])
	await _add_loading_progress(0.29411764705882354)
	for i in range(h):
		for j in range(w):
			base[i][j] = baseheightma-base[i][j]
	await _add_loading_progress(0.29411764705882354)
	for i in range(h):
		for j in range(w):
			base[i][j] += 3.0
	baseheightma += 3.0
	baseheightmin = await assign_aroundheightmin(baseheightmin,base)
	await _add_loading_progress(0.29411764705882354)
	for i in range(h):
		for j in range(w):
			var height = int(floor(base[i][j]/0.1))
			var around = int(floor(baseheightmin[i][j]/0.1))
			var diff = height-around
			for k in range(diff+1):
				_map3dnum_flat[(height-k) * worldh * worldw + (i+castle_start_h) * worldw + (j+castle_start_w)] = 2
	await _add_loading_progress(0.29411764705882354)
	for i in range(h):
		var height = int(floor(base[i][0]/0.1))
		var around = int(floor(baseheightma/0.1))
		var diff = around-height
		for k in range(diff+1):
			_map3dnum_flat[(around-k) * worldh * worldw + (i+castle_start_h) * worldw + (castle_start_w)] = 2
	await _add_loading_progress(0.29411764705882354)
	for i in range(h):
		var height = int(floor(base[i][w-1]/0.1))
		var around = int(floor(baseheightma/0.1))
		var diff = around-height
		for k in range(diff+1):
			_map3dnum_flat[(around-k) * worldh * worldw + (i+castle_start_h) * worldw + (w-1+castle_start_w)] = 2
	for i in range(w):
		var height = int(floor(base[h-1][i]/0.1))
		var around = int(floor(baseheightma/0.1))
		var diff = around-height
		for k in range(diff+1):
			_map3dnum_flat[(around-k) * worldh * worldw + (h-1+castle_start_h) * worldw + (i+castle_start_w)] = 2
	for i in range(w):
		var height = int(floor(base[h-1][i]/0.1))
		var around = int(floor(baseheightma/0.1))
		var diff = around-height
		for k in range(diff+1):
			_map3dnum_flat[(around-k) * worldh * worldw + (h-1+castle_start_h) * worldw + (i+castle_start_w)] = 2
	var land = []
	var dist = []
	await _add_loading_progress(0.29411764705882354)
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(-1)
		land.append(arrw)
	await _add_loading_progress(0.29411764705882354)
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(1e9)
		dist.append(arrw)
	var land_acc = []
	await _add_loading_progress(0.29411764705882354)
	for i in range(h):
		var arrw = []
		arrw.resize(w)
		arrw.fill(0)
		land_acc.append(arrw)
	await _add_loading_progress(0.29411764705882354)
	for i in range(h):
		for j in range(w):
			_map3dnum_flat[(30) * worldh * worldw + (i+castle_start_h) * worldw + (j+castle_start_w)] = 1
			if i-1 >= 0 and i+1 < h and j-1 >= 0 and j+1 < w:
				if base[i-1][j] != 0.0 and base[i+1][j] != 0.0 and base[i][j-1] != 0.0 and base[i][j+1] != 0.0:
					land_acc[i][j] = 1
			if _map3dnum_flat[(int(floor(baseheightma/0.1))) * worldh * worldw + (i+castle_start_h) * worldw + (j+castle_start_w)] == 2:
				_map3dnum_flat[(int(floor(baseheightma/0.1))) * worldh * worldw + (i+castle_start_h) * worldw + (j+castle_start_w)] = -1
			else:
				_map3dnum_flat[(int(floor(baseheightma/0.1))) * worldh * worldw + (i+castle_start_h) * worldw + (j+castle_start_w)] = 2
				land[i][j] = 2
	await _add_loading_progress(0.29411764705882354)
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
	var que = PackedInt32Array()
	que.resize(h * w)
	var que_head = 0
	var que_tail = 0
	que[que_tail] = land_start.x*w+land_start.y
	que_tail += 1
	dist[land_start.x][land_start.y] = 0
	var candidate = []
	while que_head < que_tail:
		var q = que[que_head]
		que_head += 1
		var i = q/w
		var j = q%w
		candidate.append([dist[i][j],i*w+j])
		if i-1 >= 0:
			if land[i-1][j] != -1 and dist[i-1][j] > dist[i][j]+1:
				dist[i-1][j] = dist[i][j]+1
				que[que_tail] = (i-1)*w+j
				que_tail += 1
		if i+1 < h:
			if land[i+1][j] != -1 and dist[i+1][j] > dist[i][j]+1:
				dist[i+1][j] = dist[i][j]+1
				que[que_tail] = (i+1)*w+j
				que_tail += 1
		if j-1 >= 0:
			if land[i][j-1] != -1 and dist[i][j-1] > dist[i][j]+1:
				dist[i][j-1] = dist[i][j]+1
				que[que_tail] = i*w+j-1
				que_tail += 1
		if j+1 < w:
			if land[i][j+1] != -1 and dist[i][j+1] > dist[i][j]+1:
				dist[i][j+1] = dist[i][j]+1
				que[que_tail] = i*w+j+1
				que_tail += 1
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
			var mesh_node = find_mesh_instance(castle_instance)
			# Do not modify the model's scale, keep it at (1,1,1) or its default.
			castle_instance.scale = Vector3(1, 1, 1)
			
			if mesh_node and mesh_node.mesh:
				var aabb = mesh_node.mesh.get_aabb()
				# Calculate internal voxel dimensions based on the actual model size
				# Assume 1 unit = 1 voxel block
				castle_width_length = int(floor(aabb.size.z))
				castle_height_length = int(floor(aabb.size.x))
				# Make sure it's at least 20 to avoid negative inner sizes
				castle_width_length = max(castle_width_length, 25)
				castle_height_length = max(castle_height_length, 25)
			else:
				castle_width_length = 48
				castle_height_length = 48
				
			castle_instance.position = Vector3(i+castle_height_length/2+castle_start_h, int(floor((baseheightma)/0.1))-1, j+int(castle_width_length/2)+castle_start_w)
			castle_instance.rotation_degrees = Vector3(0, 180, 0)
			add_child(castle_instance)
			
			# Removed create_trimesh_collision() entirely.
			# The AI generated castle model may not have a physical hole for the entrance,
			# and the internal castle walls/floors are already generated using map3dnum voxels.
			# Giving the model a collision mesh prevents the player from walking inside the voxel structure.
			sth = i+h/2
			stw = j+w*5/2
			break
	for k in range(1,4):
		for i in range(6,castle_height_length-5):
			for j in range(6,castle_width_length-5):
				_map3dnum_flat[(int(floor((baseheightma)/0.1))+k) * worldh * worldw + (sth+i) * worldw + (stw+j)] = 5
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
		# Force clearance in front of the entrance so the BSP doesn't block it
		var entrance_y_start = int((height-4)/2)
		var entrance_y_end = int((height-4)/2)+4
		for y in range(entrance_y_start, entrance_y_end + 1):
			for x in range(0, 8):
				if y >= 0 and y < height and x >= 0 and x < width:
					castlemap[y][x] = 0 # 0 is open floor space

		var edges = []
		for i in range(rooms.size()):
			for j in range(i+1,rooms.size()):
				var dx = rooms[i].x-rooms[j].x
				var dy = rooms[i].y-rooms[j].y
				var dist1 = int(sqrt(dx*dx+dy*dy))
				edges.append(edge.new(i,j,dist1))
		
		var mst = kruskal(rooms.size(),edges)
		if edges.size() > 0:
			for i in range(_rng.randi()%5+1):
				mst.append(edges[_rng.randi()%edges.size()])
		
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
			arrw.resize(width)
			arrw.fill(0)
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
						# Prevent stairs in front of entrance (i is center, j is small)
						var is_entrance_clearance = (i >= int((height-4)/2) and i <= int((height-4)/2)+4 and j < 8)
						if not is_entrance_clearance:
							stair_candidate.append([i,j,i+4,j])
				if j+6 < width:
					var sum2 = 0
					for i1 in range(3):
						for j1 in range(3):
							if castle_acc[k+1][i+i1][j+j1+4] == 1:
								sum2 += 1
					if sum1 == 9 and sum2 == 9:
						var is_entrance_clearance = (i >= int((height-4)/2) and i <= int((height-4)/2)+4 and j < 8)
						if not is_entrance_clearance:
							stair_candidate.append([i,j,i,j+4])
				if i-4 >= 0:
					var sum2 = 0
					for i1 in range(3):
						for j1 in range(3):
							if castle_acc[k+1][i+i1-4][j+j1] == 1:
								sum2 += 1
					if sum1 == 9 and sum2 == 9:
						var is_entrance_clearance = (i >= int((height-4)/2) and i <= int((height-4)/2)+4 and j < 8)
						if not is_entrance_clearance:
							stair_candidate.append([i,j,i-4,j])
				if j-4 >= 0:
					var sum2 = 0
					for i1 in range(3):
						for j1 in range(3):
							if castle_acc[k+1][i+i1][j+j1-4] == 1:
								sum2 += 1
					if sum1 == 9 and sum2 == 9:
						var is_entrance_clearance = (i >= int((height-4)/2) and i <= int((height-4)/2)+4 and j < 8)
						if not is_entrance_clearance:
							stair_candidate.append([i,j,i,j-4])
		if stair_candidate.size() == 0:
			# Fallback if no valid stairs were found (e.g. all blocked by clearance)
			stair_candidate.append([height-8, width-8, height-4, width-8])
		stair.append(stair_candidate[_rng.randi() % stair_candidate.size()])
		if stair.back() == null:
			# Extra safety just in case
			stair[-1] = [height-8, width-8, height-4, width-8]
			
		for i in range(stair.back()[2],stair.back()[2]+2):
			for j in range(stair.back()[3],stair.back()[3]+2):
				castle_acc[k+1][i][j] = 0
	for k in range(3):
		for i in range(height):
			for j in range(width):
				for l in range(5):
					if k == 0 and i >= int((height-4)/2)+1 and j < width-5 and i <= int((height-4)/2)+3:
						_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+l+k) * worldh * worldw + (sth+i+10) * worldw + (stw+j+10)] = -1
						_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+l+k) * worldh * worldw + (sth+10+int((height-4)/2)) * worldw + (stw+8)] = 5
						_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+l+k) * worldh * worldw + (sth+10+int((height-4)/2)+4) * worldw + (stw+8)] = 5
						_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+l+k) * worldh * worldw + (sth+10+int((height-4)/2)) * worldw + (stw+9)] = 5
						_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+l+k) * worldh * worldw + (sth+10+int((height-4)/2)+4) * worldw + (stw+9)] = 5
					else:
						_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+l+k) * worldh * worldw + (sth+i+10) * worldw + (stw+j+10)] = castle[k][i][j]
				if k == 1 and i >= int((height-4)/2)+1 and j < 6 and i <= int((height-4)/2)+3:
					_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5) * worldh * worldw + (sth+10+int((height-4)/2)) * worldw + (stw+8)] = 5
					_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5) * worldh * worldw + (sth+10+int((height-4)/2)+4) * worldw + (stw+9)] = 5
					_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5) * worldh * worldw + (sth+10+int((height-4)/2)) * worldw + (stw+9)] = 5
					_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5) * worldh * worldw + (sth+10+int((height-4)/2)+4) * worldw + (stw+8)] = 5
					_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+k) * worldh * worldw + (sth+i+10) * worldw + (stw+8)] = 5
					_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+k) * worldh * worldw + (sth+i+10) * worldw + (stw+9)] = 5
					
				_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+5+k) * worldh * worldw + (sth+i+10) * worldw + (stw+j+10)] = 5
	# --- BFS Validation for Castle Entrance Path ---
	var q = []
	var visited = {}
	var start_y = int((height-4)/2) + 2
	var start_x = 1
	var target_y = stair[0][0]
	var target_x = stair[0][1]
	q.append([start_y, start_x])
	visited[str(start_y) + "," + str(start_x)] = 1
	var path_found = false
	
	while q.size() > 0:
		var curr = q.pop_front()
		var cy = curr[0]
		var cx = curr[1]
		
		# If we are close to the stairs
		if abs(cy - target_y) <= 2 and abs(cx - target_x) <= 2:
			path_found = true
			break
			
		for dir in [[0, 1], [1, 0], [0, -1], [-1, 0]]:
			var ny = cy + dir[0]
			var nx = cx + dir[1]
			var key = str(ny) + "," + str(nx)
			if ny >= 0 and ny < height and nx >= 0 and nx < width:
				if not visited.has(key) and castle[0][ny][nx] == 0:
					visited[key] = 1
					q.append([ny, nx])
					
	if not path_found:
		push_error("Castle BFS Validation Failed: No path from entrance to stairs in the generated internal layout!")
	else:
		print("Castle BFS Validation: Path to stairs is clear.")
	
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
						_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+k+j) * worldh * worldw + (sth+sti1+i+10) * worldw + (stw+j+stj1+2+10)] = 5
						for t in range(5):
							_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+k+min(5,j+t+1)) * worldh * worldw + (sth+sti1+i+10) * worldw + (stw+j+stj1+2+10)] = -1
			else:
				for j in range(stj1-stj2+1):
					for i in range(3):
						_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+k+5-j) * worldh * worldw + (sth+sti1+i+10) * worldw + (stw+j+stj2+1+10)] = 5
						for t in range(5):
							_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+k+min(5,4-j+t+1)) * worldh * worldw + (sth+sti1+i+10) * worldw + (stw+j+stj2+10)] = -1
		else:
			if sti2 >= sti1:
				for i in range(sti2-sti1+1):
					for j in range(3):
						_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+k+i) * worldh * worldw + (sth+sti1+i+2+10) * worldw + (stw+j+stj1+10)] = 5
						for t in range(5):
							_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+k+min(5,i+t+1)) * worldh * worldw + (sth+sti1+i+2+10) * worldw + (stw+j+stj1+10)] = -1
			else:
				for i in range(sti1-sti2+1):
					for j in range(3):
						_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+k+5-i) * worldh * worldw + (sth+sti2+i+1+10) * worldw + (stw+j+stj1+10)] = 5
						for t in range(5):
							_map3dnum_flat[(int(floor((baseheightma)/0.1))+4+k*5+k+min(5,4-i+t+1)) * worldh * worldw + (sth+sti2+i+10) * worldw + (stw+j+stj1+10)] = -1


var loading_ui = null
var loading_label = null
var loading_progress = null
var loading_tween = null

func _enter_tree():
	if DEBUG_FIXED_SEED:
		_rng.seed = DEBUG_SEED_VALUE
	var file = FileAccess.open("user://game_settings.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if typeof(json) == TYPE_DICTIONARY and json.has("exp"):
			exp = json.exp
	h = int(pow(2, exp)) + 1
	w = int(pow(2, exp)) + 1
	worldh = h*2
	worldw = w*4
	plane_start_h = h/2
	plane_start_w = w*3/2
	desert_start_h = h/2
	desert_start_w = w/2
	cave_start_h = h/2
	cave_start_w = w
	castle_start_h = h/2
	castle_start_w = w*5/2
	castle_width_length = h/4*3
	castle_height_length = w/4*3

func _ready():
	loading_ui = CanvasLayer.new()
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.1, 0.1, 1.0)
	loading_ui.add_child(bg)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	
	loading_label = Label.new()
	loading_label.text = "Loading..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(loading_label)
	
	loading_progress = ProgressBar.new()
	loading_progress.custom_minimum_size = Vector2(500, 40)
	vbox.add_child(loading_progress)
	
	loading_ui.add_child(vbox)
	add_child(loading_ui)
	
	var gfx_level = 1
	var file = FileAccess.open("user://game_settings.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if typeof(json) == TYPE_DICTIONARY and json.has("gfx"):
			gfx_level = json.gfx
		
	var light = get_parent().get_node_or_null("DirectionalLight3D")
	
	if gfx_level == 2: # High
		get_viewport().msaa_3d = Viewport.MSAA_8X
		get_viewport().use_taa = true
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		if light:
			light.shadow_enabled = true
			light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	elif gfx_level == 1: # Medium
		get_viewport().msaa_3d = Viewport.MSAA_2X
		get_viewport().use_taa = false
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		if light:
			light.shadow_enabled = true
			light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	else: # Low
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		get_viewport().use_taa = false
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		if light:
			light.shadow_enabled = false
	
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Force Godot to draw the Loading UI before blocking the main thread
	await get_tree().process_frame
	await get_tree().process_frame
	
	_async_generate_terrain()


func _set_loading_text(text: String):
	if loading_label:
		loading_label.text = text
	await get_tree().process_frame


var _last_yield_time: int = 0
var is_generating = true
var _yield_counter: int = 0
func _conditional_yield():
	_yield_counter += 1
	if _yield_counter % 512 == 0:
		var current_time = Time.get_ticks_msec()
		if current_time - _last_yield_time > 50:
			await get_tree().process_frame
			_last_yield_time = Time.get_ticks_msec()

func _add_loading_progress(amount: float):
	if loading_progress:
		loading_progress.value += amount
	await get_tree().process_frame

func _update_progress_only(progress: float):
	if loading_progress:
		loading_progress.value = progress
	await get_tree().process_frame

func _update_loading(text: String, progress: float):
	if loading_label:
		loading_label.text = text
	if loading_progress:
		if loading_tween:
			loading_tween.kill()
		loading_progress.value = progress
	await get_tree().process_frame

func _setup_beautiful_environment():
	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.5, 0.8)
	sky_mat.sky_horizon_color = Color(0.6, 0.7, 0.8)
	sky_mat.ground_bottom_color = Color(0.1, 0.1, 0.15)
	sky_mat.ground_horizon_color = Color(0.6, 0.7, 0.8)
	sky.sky_material = sky_mat
	environment.sky = sky
	
	# Add some post-processing for better visuals
	environment.ssao_enabled = true
	environment.ssao_radius = 1.5
	environment.ssao_intensity = 2.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.1
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	
	env.environment = environment
	add_child(env)
	
	# Enhance existing light or create a new one
	var light = get_parent().get_node_or_null("DirectionalLight3D")
	if light == null:
		light = DirectionalLight3D.new()
		light.name = "DirectionalLight3D"
		get_parent().add_child(light)
		light.rotation_degrees = Vector3(-45, 45, 0)
	
	light.light_energy = 1.2
	light.light_color = Color(1.0, 0.95, 0.9)
	light.shadow_enabled = true
	light.shadow_blur = 1.5
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	light.directional_shadow_split_1 = 0.05
	light.directional_shadow_split_2 = 0.15
	light.directional_shadow_split_3 = 0.35


var _phase_start_time: int = 0
var _total_start_time: int = 0

func _start_phase(phase_name: String):
	print("\n--- START PHASE: ", phase_name, " ---")
	_phase_start_time = Time.get_ticks_usec()

func _end_phase(phase_name: String, local_map=null, local_floor=null, local_ceiling=null, local_desert=null, local_map3dnum=null):
	var elapsed = (Time.get_ticks_usec() - _phase_start_time) / 1000.0
	print("--- END PHASE: ", phase_name, " (", elapsed, " ms) ---")
	_print_hashes(local_map, local_floor, local_ceiling, local_desert, local_map3dnum)
	_print_memory()

func _print_memory():
	var mem = OS.get_static_memory_usage() / 1024.0 / 1024.0
	var peak_mem = OS.get_static_memory_peak_usage() / 1024.0 / 1024.0
	print("Memory: ", mem, " MB (Peak: ", peak_mem, " MB)")

func _print_hashes(local_map, local_floor, local_ceiling, local_desert, local_map3dnum):
	var out = "Hashes: "
	if local_map != null and local_map.size() > 0:
		var f = PackedFloat32Array()
		for row in local_map: f.append_array(PackedFloat32Array(row))
		out += "map=" + str(hash(f)) + " "
	if local_floor != null and local_floor.size() > 0:
		var f = PackedFloat32Array()
		for row in local_floor: f.append_array(PackedFloat32Array(row))
		out += "floor=" + str(hash(f)) + " "
	if local_ceiling != null and local_ceiling.size() > 0:
		var f = PackedFloat32Array()
		for row in local_ceiling: f.append_array(PackedFloat32Array(row))
		out += "ceiling=" + str(hash(f)) + " "
	if local_desert != null and local_desert.size() > 0:
		var f = PackedFloat32Array()
		for row in local_desert: f.append_array(PackedFloat32Array(row))
		out += "desert=" + str(hash(f)) + " "
	if _map3dnum_flat.size() > 0:
		out += "map3dnum=" + str(hash(_map3dnum_flat))
	print(out)

func _print_node_stats():
	var mm_count = 0
	var sb_count = 0
	var cs_count = 0
	var total_nodes = get_tree().get_node_count()
	
	var queue = [get_parent()]
	while queue.size() > 0:
		var node = queue.pop_front()
		if node.get_class() == "MultiMeshInstance3D":
			mm_count += 1
		elif node.get_class() == "StaticBody3D":
			sb_count += 1
		elif node.get_class() == "CollisionShape3D":
			cs_count += 1
		for child in node.get_children():
			queue.append(child)
	
	print("Node Stats:")
	print("  Total Nodes: ", total_nodes)
	print("  MultiMeshInstance3D: ", mm_count)
	print("  StaticBody3D: ", sb_count)
	print("  CollisionShape3D: ", cs_count)

func _async_generate_terrain():
	_setup_beautiful_environment()
	if loading_progress: loading_progress.value = 0.0
	player = get_parent().get_node("CharacterBody3D")
	_total_start_time = Time.get_ticks_usec()
	_start_phase("Phase 0: Memory Allocation")
	await _set_loading_text("Allocating Memory (2D)...")
	for i in range(h):
		var arrw = []
		for j in range(w):
			arrw.append([])

	await _update_loading("Allocating Memory (2D)...", 2)
	for i in range(h):
		var row_map = []
		var row_map1 = []
		var row_around = []
		row_map.resize(w)
		row_map.fill(0.0)
		row_map1.resize(w)
		row_map1.fill(0)
		row_around.resize(w)
		row_around.fill(999999.0)
		map.append(row_map)
		assignnum.append(row_map1)
		aroundheightmin.append(row_around)
	
	await _update_loading("Allocating Memory (map3dnum)...", 4)
	await _add_loading_progress(2.0)
	await _set_loading_text("Allocating Memory (map3dnum)...")
	_map3dnum_flat.resize(d * worldh * worldw)
	_map3dnum_flat.fill(-1)
	await _update_loading("Allocating Memory (nearest_ground)...", 6)
	await _add_loading_progress(2.0)
	await _set_loading_text("Allocating Memory (nearest_ground)...")
	nearest_ground.resize(d)
	for k in range(d):
		var z_level_map = []
		z_level_map.resize(worldh)
		for i in range(worldh):
			var row_for_z = []
			row_for_z.resize(worldw)
			row_for_z.fill(-1)
			z_level_map[i] = row_for_z
		nearest_ground[k] = z_level_map
		if k % 10 == 0: await get_tree().process_frame
		
	await _update_loading("Allocating Memory (map3d)...", 8)
	await _add_loading_progress(2.0)
	await _set_loading_text("Allocating Memory (map3d)...")
	_map3d_flat.resize(d * worldh * worldw)
	_map3d_flat.fill(-1)
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
	for i in range(chunkh):
		var row_for_z = []
		row_for_z.resize(chunkw)
		row_for_z.fill(false)
		chunk_calculated.append(row_for_z)
	for i in range(chunkh):
		var row_for_z = []
		row_for_z.resize(chunkw)
		row_for_z.fill(0)
		chunk_state.append(row_for_z)
	for i in range(chunkh):
		var row_col = []
		row_col.resize(chunkw)
		row_col.fill(0)
		chunk_col_state.append(row_col)
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
	await _add_loading_progress(2.0)
	_end_phase("Phase 0: Memory Allocation", null, null, null, null, map3dnum)
	_start_phase("Phase 1: Plains & Snow")
	await _set_loading_text("Generating base terrain...")
	map = await diamondsquare(map,0.75)
	await _set_loading_text("Smoothing terrain...")
	await smooth_terrain(10,0.5,map, 5.0)
	await _set_loading_text("Creating sea...")
	var resmap = await sea(map,8, 5.0)
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
	var land_heights = PackedFloat32Array()
	land_heights.resize(h * w - seablocksum)
	var l_idx = 0
	for i in range(h):
		for j in range(w):
			if map[i][j] > 0:
				land_heights[l_idx] = map[i][j]
				l_idx += 1
	land_heights.sort()
	if land_heights.size() > 0:
		var target_idx = land_heights.size() - int(float(land_heights.size()) * (2.0 / 5.0))
		target_idx = clamp(target_idx, 0, land_heights.size() - 1)
		snow_threshold = land_heights[target_idx]
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
	await _set_loading_text("Generating Snow Biome...")
	var res_leveling = await snow_leveling(map)
	map = res_leveling[0]
	var res_shop_leveling = await snow_leveling1(map,Vector2(res_leveling[1],res_leveling[2]))
	await _set_loading_text("Generating Plains Biome...")
	var res_leveling1 = await plane_leveling(map)
	map = res_leveling1[0]
	var res_shop_leveling1 = await plane_leveling1(map,Vector2(res_leveling[1],res_leveling[2]))
	aroundheightmin = await assign_aroundheightmin(aroundheightmin,map)
	assignnum = await assign_num(SNOWHEIGHT,assignnum,map,max_height)
	for i in range(h):
		aroundheightmin[i][0] = 0
		aroundheightmin[i][w-1] = 0
	for i in range(w):
		aroundheightmin[0][i] = 0
		aroundheightmin[h-1][i] = 0			
	for i in range(worldh):
		for j in range(worldw):
			# Removed the hardcoded rectangular hole that was missing ocean
			_map3dnum_flat[(30) * worldh * worldw + (i) * worldw + (j)] = 1
	for i in range(h):
		for j in range(w):
			map[i][j] += 3.0
			aroundheightmin[i][j] += 3.0
	snow_battle_pos = Vector3(res_leveling[1]+plane_start_h,int(floor(map[res_leveling[1]][res_leveling[2]]/0.1)),res_leveling[2]+plane_start_w)
	plane_battle_pos = Vector3(res_leveling1[1]+plane_start_h,int(floor(map[res_leveling1[1]][res_leveling1[2]]/0.1)),res_leveling1[2]+plane_start_w)
	snow_shop_pos = Vector3(res_shop_leveling[1]+plane_start_h,int(floor(map[res_shop_leveling[1]][res_shop_leveling[2]]/0.1))+shop_height/2,res_shop_leveling[2]+plane_start_w)
	get_parent().get_node("snow_shop").position = snow_shop_pos
	get_parent().get_node("snow_shop").scale *= shop_height
	get_parent().get_node("snow_shop/Area3D/CollisionShape3D").scale *= shop_height
	plane_shop_pos = Vector3(res_shop_leveling1[1]+plane_start_h,int(floor(map[res_shop_leveling1[1]][res_shop_leveling1[2]]/0.1))+shop_height/2,res_shop_leveling1[2]+plane_start_w)
	get_parent().get_node("plain_shop").position = plane_shop_pos
	get_parent().get_node("plain_shop").scale *= shop_height
	get_parent().get_node("plain_shop/Area3D/CollisionShape3D").scale *= shop_height
	var main_node = get_parent()
	for i in range(h):
		for j in range(w):
			var height = int(floor(map[i][j]/0.1))
			var around = int(floor(aroundheightmin[i][j]/0.1))
			var diff = height-around
			for k in range(diff+1):
				_map3dnum_flat[(height-k) * worldh * worldw + (i+plane_start_h) * worldw + (j+plane_start_w)] = assignnum[i][j]
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
	await smooth_terrain(10,3.5,floor, 2.0)
	await smooth_terrain(10,3.5,ceiling, 2.0)
	floorheightmin = await assign_aroundheightmin(floorheightmin,floor)
	ceilingheightmin = await assign_aroundheightmin(ceilingheightmin,ceiling)
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
				_map3dnum_flat[(height-k+10) * worldh * worldw + (i+cave_start_h) * worldw + (j+cave_start_w)] = 5
			for k in range(diff1+1):
				_map3dnum_flat[(height1-k+10) * worldh * worldw + (i+cave_start_h) * worldw + (j+cave_start_w)] = 5
	floorheightmi *= 10
	floorheightmi += 10
	floorheightmax *= 10
	floorheightmax += 10
	ceilingheightmax *= 10
	ceilingheightmax += 10
	ceilingheightmi *= 10
	ceilingheightmi += 10
	var caves = generate_cave(w,h,floorheightmi)#迷路
	res_leveling = await cave_leveling(caves[0],floor)
	res_shop_leveling = await cave_leveling1(caves[0],floor,Vector2(res_leveling[1],res_leveling[2]))
	cave_battle_pos = Vector3(res_leveling[1]+cave_start_h,int(floor(floor[res_leveling[1]][res_leveling[2]]/0.1))+10,res_leveling[2]+cave_start_w)
	cave_shop_pos = Vector3(res_shop_leveling[1]+cave_start_h,int(floor(floor[res_shop_leveling[1]][res_shop_leveling[2]]/0.1))+shop_height/2,res_shop_leveling[2]+cave_start_w)
	get_parent().get_node("cave_shop").position = cave_shop_pos
	get_parent().get_node("cave_shop").scale *= shop_height
	get_parent().get_node("cave_shop/Area3D/CollisionShape3D").scale *= shop_height
	for i in range(h):
		for j in range(w):
			var height = int(floor(floor[i][j]/0.1))+10
			for k in range(height,30):
				if caves[k-height][i][j] == 5:
					_map3dnum_flat[(k) * worldh * worldw + (i+cave_start_h) * worldw + (j+cave_start_w)] = 5
	#砂漠生成
	_end_phase("Phase 2: Cave", map, floor, ceiling, null, map3dnum)
	_start_phase("Phase 3: Desert")
	var desert = []
	var desertheightmin = []
	var desertassignnum = []
	for i in range(h):
		var row_map = []
		var row_around = []
		var row_assignnum = []
		row_map.resize(w)
		row_map.fill(0.0)
		row_around.resize(w)
		row_around.fill(999999.0)
		row_assignnum.resize(w)
		row_assignnum.fill(-1)
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
	await smooth_terrain(10,0.5,desert, 5.0)
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
	var resdesert = await sea(desert,3)
	desert = resdesert[0]
	for i in range(h):
		for j in range(w):
			if desert[i][j] > SEAHEIGHT:
				desert[i][j] -= SEAHEIGHT
				desert[i][j] += 1.0
			else:
				desert[i][j] = 0
	desertheightmax += 1.0
	res_leveling = await desert_leveling(desert)
	desert = res_leveling[0]
	res_shop_leveling = await desert_leveling1(desert,Vector2(res_leveling[1],res_leveling[2]))
	desertassignnum = await assign_num(SNOWHEIGHT,desertassignnum,desert,desertheightmax)
	for i in range(h):
		for j in range(w):
			desert[i][j] += 3.0
	desertheightmi = 3.0
	desert_battle_pos = Vector3(res_leveling[1]+desert_start_h,int(floor(desert[res_leveling[1]][res_leveling[2]])),res_leveling[2]+desert_start_w)
	desert_shop_pos = Vector3(res_shop_leveling[1]+desert_start_h,int(floor(desert[res_shop_leveling[1]][res_shop_leveling[2]]))+shop_height/2,res_shop_leveling[2]+desert_start_w)
	get_parent().get_node("desert_shop").position = desert_shop_pos
	get_parent().get_node("desert_shop").scale *= shop_height
	get_parent().get_node("desert_shop/Area3D/CollisionShape3D").scale *= shop_height
	desertheightmin = await assign_aroundheightmin(desertheightmin,desert)
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
				_map3dnum_flat[(height-k) * worldh * worldw + (i+desert_start_h) * worldw + (j+desert_start_w)] = desertassignnum[i][j]
	#洞窟の入口生成		
	var caveentrance = await find_cave_entrance(plane_start_h,plane_start_w,map)
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

	# --- Generate Connecting Bridges ---
	# --- Fixed Non-Vertical Bridge Generation ---
	var safe_x_min = desert_start_h + int(h/2) - 30
	var safe_x_max = desert_start_h + int(h/2) + 30
	
	# Bridge A: Desert to Snow
	var desert_z_search = desert_start_w + int(w * 0.7) 
	var snow_z_search_a = plane_start_w + int(w * 0.1)  
	
	var anchor_a = find_highest_anchor_in_rect(safe_x_min, safe_x_max, desert_z_search - 10, desert_z_search + 10)
	var anchor_b = find_highest_anchor_in_rect(safe_x_min, safe_x_max, snow_z_search_a - 10, snow_z_search_a + 10, 3) # Require snow
	
	if anchor_a != Vector3.ZERO and anchor_b != Vector3.ZERO:
		build_bridge(anchor_a, anchor_b)

	_end_phase("Phase 3: Desert", map, floor, ceiling, desert, map3dnum)
	_start_phase("Phase 4: Demon Castle")
	await _set_loading_text("Architecting Demon Castle...")
	await make_castle()

	_end_phase("Phase 4: Demon Castle", map, floor, ceiling, desert, map3dnum)
	_start_phase("Phase 5: Bridges")
	# Bridge B: Snow to Castle
	var snow_z_search_b = plane_start_w + int(w * 0.8)
	var castle_z_search = castle_start_w + int(w * 0.2)
	
	var anchor_c = find_highest_anchor_in_rect(safe_x_min, safe_x_max, snow_z_search_b - 10, snow_z_search_b + 10, 3) # Require snow
	var anchor_d = find_highest_anchor_in_rect(safe_x_min, safe_x_max, castle_z_search - 10, castle_z_search + 10, 2) # Require rock
	
	if anchor_c != Vector3.ZERO and anchor_d != Vector3.ZERO:
		build_bridge(anchor_c, anchor_d)
	# --- Generate User Requested Debug Report ---
	generate_debug_report_and_image(Vector3(mazeend[0]), anchor_a, anchor_b, anchor_c, anchor_d)
	# --------------------------------------------
	
	_end_phase("Phase 5: Bridges", map, floor, ceiling, desert, map3dnum)
	_start_phase("Phase 6: Meshes & Collisions")
	await _set_loading_text("Calculating ground proximities...")
	for k in range(d-1):
		for i in range(worldh):
			# Fast native C++ copy instead of GDScript loop
			nearest_ground[k+1][i] = nearest_ground[k][i].duplicate()
			for j in range(worldw):
				if _map3dnum_flat[(k+1) * worldh * worldw + (i) * worldw + (j)] != -1:
					nearest_ground[k+1][i][j] = k+1
					
	template_mesh = get_parent().get_node("StaticBody3D/MeshInstance3D").mesh
	await _set_loading_text("Phase 6: Meshes & Collisions (Lazy Chunking)")
	# Deferring chunk calculation to _process!
	_end_phase("Phase 6: Meshes & Collisions", map, floor, ceiling, desert, map3dnum)
	_start_phase("Phase 7: Entity Placement")
	var plane_candidate = []
	for i in range(h):
		for j in range(w):
			if map[i][j] > 3.1 and map[i][j] < 4.0:
				plane_candidate.append([i,j])
	
	# Set spawn point far away from the cave entrance (boss) so the player has a journey.
	var plain_boss_loc = Vector3(caveentrance[0])
	var furthest_pos = Vector3.ZERO
	var max_dist = 0.0
	
	# Sample up to 100 random points on the plain and pick the one furthest from the boss
	for _attempt in range(100):
		var cand = plane_candidate[_rng.randi() % plane_candidate.size()]
		var cand_pos = Vector3(cand[0]+plane_start_h, int(floor(map[cand[0]][cand[1]]/0.1))+5, cand[1]+plane_start_w)
		var dist = cand_pos.distance_to(plain_boss_loc)
		if dist > max_dist:
			max_dist = dist
			furthest_pos = cand_pos
			
	# As a fallback or if somehow plane_candidate is empty
	if furthest_pos == Vector3.ZERO:
		furthest_pos = plain_boss_loc + Vector3(30, 15, 30)

	get_parent().get_node("CharacterBody3D").position = furthest_pos
	
	# --- Spawn Bosses ---
	var spawner = get_parent().get_node_or_null("spawn_enemy")
	if spawner and spawner.has_method("spawn_boss"):
		# 1. Plain -> Cave (Near cave entrance)
		var p0dir = get_direction(caveentrance[1],caveentrance[2])
		var plain_boss_pos = Vector3(caveentrance[0]) + p0dir * 6.0
		plain_boss_pos.y += 2.0
		spawner.spawn_boss("fantasy_wolf", plain_boss_pos, 3.0, 0)
		
		# 2. Cave -> Desert (Near cave exit tunnel)
		var p3dir = get_direction(mazeend[1],mazeend[2])
		var cave_boss_pos = Vector3(mazeend[0]) + p3dir * 6.0
		cave_boss_pos.y += 2.0
		spawner.spawn_boss("cave_dragon", cave_boss_pos, 4.0, 1)
		
		# 3. Desert -> Snow (Before the bridge)
		var desert_boss_pos = Vector3(desert_shop_pos.x, desert_shop_pos.y, desert_shop_pos.z + 5)
		spawner.spawn_boss("scorpion", desert_boss_pos, 3.5, 2)
		
		# 4. Snow -> Castle (Before the bridge)
		var snow_boss_pos = Vector3(snow_shop_pos.x, snow_shop_pos.y, snow_shop_pos.z + 5)
		spawner.spawn_boss("blue_dragon", snow_boss_pos, 4.0, 3)
		
		# 5. Castle (Throne room / Top floor)
		var castle_boss_pos = Vector3(castle_start_h + h/2, int(floor(baseheightma/0.1)) + 5, castle_start_w + w/2)
		spawner.spawn_boss("demon", castle_boss_pos, 5.0, 4)

	if loading_progress: loading_progress.value = 100.0
	await get_tree().process_frame
	loading_ui.visible = false
	if player:
		player.process_mode = Node.PROCESS_MODE_INHERIT
	if loading_ui:
		is_generating = false
	update_visibility(player.global_transform.origin)
	loading_ui.queue_free()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		var bgm_node = get_node_or_null("bgm")
		if bgm_node:
			bgm_node.playing = not bgm_node.playing

func get_map3dnum(x: int, y: int, z: int) -> int:
	if x < 0 or x >= worldh or z < 0 or z >= worldw or y < 0 or y >= d:
		return -1
	var idx = (y) * worldh * worldw + (x) * worldw + (z)
	if idx < 0 or idx >= _map3dnum_flat.size():
		return -1
	return _map3dnum_flat[idx]
