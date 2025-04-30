extends Node3D
@export var player : Node3D


#==> OTHER <==#
var h = 50
var w = 50
var count = 300
var r = 10
var c = 10
var boxsize = 0.1
var mapheight = []
var aroundheightmin = []
#==> CODE <==#
func maketerrain():
	for i in range(h):
		for j in range(w):
			if(mapheight[i][j]-aroundheightmin[i][j])*boxsize>=1:
				for k in range(mapheight[i][j]-aroundheightmin[i][j]):
					var static_body = get_parent().get_node("cube").get_node("StaticBody3D")
					if static_body:
						var static_body_copy = static_body.duplicate()
						static_body_copy.position = Vector3(i*boxsize,(mapheight[i][j]-k)*boxsize, j*boxsize)
						static_body_copy.scale *= boxsize
						get_parent().get_node("cube").add_child(static_body_copy)
			else:
				var static_body = get_parent().get_node("cube").get_node("StaticBody3D")
				if static_body:
						var static_body_copy = static_body.duplicate()
						static_body_copy.position = Vector3(i*boxsize, mapheight[i][j]*boxsize, j*boxsize)
						static_body_copy.scale *= boxsize
						get_parent().get_node("cube").add_child(static_body_copy)
func _ready():
	if not player:
		push_error("Player is not defined. Check terrain right panel to set player.")
		queue_free()
		return
	for i in range(h):
		var mpl = []
		for j in range(w):
			mpl.push_back(0);
		aroundheightmin.push_back(mpl)
		mapheight.push_back(mpl);
	for k in range(count):
		var i = randi_range(0,h-r)
		var j = randi_range(0,w-c)
		var f = true
		for l in range(r):
				for m in range(c):
					mapheight[i+l][j+m] += 1
		var aroundheightmin2 = []
		for a in aroundheightmin:
			var line = []
			for b in a:
				line.append(b)
			aroundheightmin2.append(line)
		for l in range(r):
			for m in range(c):
				if(i+l-1>=0&&j+m-1>=0):
					aroundheightmin2[i][j] = min(aroundheightmin2[i][j],mapheight[i+l-1][j+m-1])
					if(abs(mapheight[i+l-1][j+m-1]-mapheight[i+l][j+m])*boxsize>2):
						f = false
				if(i+l-1>=0):
					aroundheightmin2[i][j] = min(aroundheightmin2[i][j],mapheight[i+l-1][j+m])
					if(abs(mapheight[i+l-1][j+m]-mapheight[i+l][j+m])*boxsize>2):
						f = false
				if(i+l-1>=0&&j+m+1<w):
					aroundheightmin2[i][j] = min(aroundheightmin2[i][j],mapheight[i+l-1][j+m+1])
					if(abs(mapheight[i+l-1][j+m+1]-mapheight[i+l][j+m])*boxsize>2):
						f = false
				if(j+m+1<w):
					aroundheightmin2[i][j] = min(aroundheightmin2[i][j],mapheight[i+l][j+m+1])
					if(abs(mapheight[i+l][j+m+1]-mapheight[i+l][j+m])*boxsize>2):
						f = false
				if(i+l+1<h&&j+m+1<w):
					aroundheightmin2[i][j] = min(aroundheightmin2[i][j],mapheight[i+l+1][j+m+1])
					if(abs(mapheight[i+l+1][j+m+1]-mapheight[i+l][j+m])*boxsize>2):
						f = false
				if(i+l+1<h):
					aroundheightmin2[i][j] = min(aroundheightmin2[i][j],mapheight[i+l+1][j+m])
					if(abs(mapheight[i+l+1][j+m]-mapheight[i+l][j+m])*boxsize>2):
						f = false
				if(i+l+1<h&&j+m-1>=0):
					aroundheightmin2[i][j] = min(aroundheightmin2[i][j],mapheight[i+l+1][j+m-1])
					if(abs(mapheight[i+l+1][j+m-1]-mapheight[i+l][j+m])*boxsize>2):
						f = false
				if(j+m-1>=0):
					aroundheightmin2[i][j] = min(aroundheightmin2[i][j],mapheight[i+l][j+m-1])
					if(abs(mapheight[i+l][j+m-1]-mapheight[i+l][j+m])*boxsize>2):
						f = false
		if(!f):
			for l in range(r):
				for m in range(c):
					mapheight[i+l][j+m] -= 1
		else:
			aroundheightmin = aroundheightmin2
	var minheight = 1e9
	for i in range(h):
		for j in range(w):
			minheight = min(minheight,mapheight[i][j])
	for i in range(h):
		for j in range(w):
			mapheight[i][j] -= minheight
	for i in range(h):
		for j in range(w):
			aroundheightmin[i][j] -= minheight
	maketerrain()
