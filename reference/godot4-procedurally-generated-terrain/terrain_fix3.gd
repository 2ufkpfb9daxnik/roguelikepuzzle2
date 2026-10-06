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
var CHUNK_BUDGET_MS = 3.0
var unload_length = visiblelength + 2

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
	if(int(playerpos.x/rh)!=int(cur_pos.x/rh)||int(playerpos.z/rw)!=int(cur_pos.z/rw)):
		playerpos = cur_pos
		if not is_generating:
			_queue_chunks_around(int(cur_pos.x/rh), int(cur_pos.z/rw))
			
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


var NODES_PER_FRAME_LIMIT = 20

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
				multimesh.buffer = buf
				
				var multimeshinstance = MultiMeshInstance3D.new()
				multimeshinstance.multimesh = multimesh
				assign_material(first_block[0], first_block[1], first_block[2], multimeshinstance)
				cube.add_child(multimeshinstance)
				multimeshmap[ci][cj].append(multimeshinstance)
		task[4] = 3
		return false
		
	elif phase == 3:
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
		while sub_idx < len(col_data) and count < 30: # 30 shapes per frame
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

func _step_free_chunk(task: Array) -> bool:
	var ci = task[0]
	var cj = task[1]
	var phase = task[4]
	
	if phase == 0:
		if len(multimeshmap[ci][cj]) > 0:
			for node in multimeshmap[ci][cj]:
				node.queue_free()
			multimeshmap[ci][cj].clear()
		task[4] = 1
		return false
		
	elif phase == 1:
		if len(collisionmap[ci][cj]) > 0:
			for node in collisionmap[ci][cj]:
				node.queue_free()
			collisionmap[ci][cj].clear()
		task[4] = 2
		return true
		
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
		
		var p_vel = Vector2(cur_vel.x, cur_vel.z)
		if p_vel.length() > 0.1:
			var dir_to_chunk = Vector2(ci - px, cj - pz).normalized()
			var dot = dir_to_chunk.dot(p_vel.normalized())
			if type == 0:
				task[2] -= dot * 5.0
			else:
				task[2] += dot * 5.0
				
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
		var state = chunk_state[ci][cj]
		
		if type == 0 and state != 1:
			i += 1
			continue
		if type == 1 and state != 3:
			i += 1
			continue
			
		var cur_time = Time.get_ticks_msec()
		if cur_time - start_time >= CHUNK_BUDGET_MS:
			budget_exceeded = true
			
		if budget_exceeded:
			new_queue.append(task)
			i += 1
			continue
			
		if type == 0:
			var finished = _step_generate_chunk(task)
			if finished:
				chunk_state[ci][cj] = 2
				processed += 1
			else:
				new_queue.append(task)
		else:
			var finished = _step_free_chunk(task)
			if finished:
				chunk_state[ci][cj] = 0
				processed += 1
			else:
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

	# Multimesh logic
	var group_list = []
	for k in range(max_k):
		var k_wh_ww = k * wh_ww
		for gi in range(limit_i_base, limit_i_max):
			var gi_ww = gi * ww
			for gj in range(limit_j_base, limit_j_max):
				var idx = k_wh_ww + gi_ww + gj
				var curmap3d = _map3d_flat[idx]
				var curmap3dnum = _map3dnum_flat[idx]
				if curmap3d != -1 or curmap3dnum == -1:
					continue
				var que = Dequeue.new()
				que.push_back([gi, gj, k])
				var new_group_idx = len(group_list)
				group_list.append([])
				while not que.is_empty():
					var cur = que.pop_front()
					var c_i = cur[0]
					var c_j = cur[1]
					var c_k = cur[2]
					var c_idx = c_k * wh_ww + c_i * ww + c_j
					if _map3d_flat[c_idx] != -1:
						continue
					_map3d_flat[c_idx] = new_group_idx
					group_list[new_group_idx].push_back(cur)
					if c_i - 1 >= limit_i_base:
						var n_idx = c_idx - ww
						if _map3dnum_flat[n_idx] == curmap3dnum and _map3d_flat[n_idx] == -1:
							que.push_back([c_i - 1, c_j, c_k])
					if c_i + 1 < limit_i_max:
						var n_idx = c_idx + ww
						if _map3dnum_flat[n_idx] == curmap3dnum and _map3d_flat[n_idx] == -1:
							que.push_back([c_i + 1, c_j, c_k])
					if c_j - 1 >= limit_j_base:
						var n_idx = c_idx - 1
						if _map3dnum_flat[n_idx] == curmap3dnum and _map3d_flat[n_idx] == -1:
							que.push_back([c_i, c_j - 1, c_k])
					if c_j + 1 < limit_j_max:
						var n_idx = c_idx + 1
						if _map3dnum_flat[n_idx] == curmap3dnum and _map3d_flat[n_idx] == -1:
							que.push_back([c_i, c_j + 1, c_k])
					if c_k - 1 >= 0:
						var n_idx = c_idx - wh_ww
						if _map3dnum_flat[n_idx] == curmap3dnum and _map3d_flat[n_idx] == -1:
							que.push_back([c_i, c_j, c_k - 1])
					if c_k + 1 < d:
						var n_idx = c_idx + wh_ww
						if _map3dnum_flat[n_idx] == curmap3dnum and _map3d_flat[n_idx] == -1:
							que.push_back([c_i, c_j, c_k + 1])

	# Convert group_list into PackedFloat32Array buffers for MultiMesh
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

	# Collision logic
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
