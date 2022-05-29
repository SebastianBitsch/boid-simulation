extends Node2D

onready var boid_prefab = preload("res://Scenes/Boid.tscn")

# Map bounds # TODO: Change to Vector2i in godot 4
export(Vector2) var map_size = Vector2(1750,1750)

# Flock properties
export(int, 1, 10000) var num_boids = 1000
export(int, 1, 10) var max_flock_size = 5

# Speed
export var max_speed: = 100.0

# Forces
export(float, -1, 1) var cohesion_force: = 0.05
export(float, -1, 1) var align_force: = 0.05
export(float, -1, 1) var separation_force: = 0.05
export(float, -5, 5) var flee_force: = -3
export(float, -10, 10) var out_of_bounds_force = 8

# Distances
export(float, 1, 100) var view_distance: = 60.0
export(float, 1, 100) var avoid_distance: = 30.0

var boids: Array
var velocities: Array
var view_distances: Array
 
var qt: QuadTree
var last_qt: QuadTree


func _ready():
	var spawn_radius = int(min(map_size.x,map_size.y)/2)
	
	# Spawn boids
	for _i in range(num_boids):
		var p = get_random_pos_in_sphere(spawn_radius) 
		var b = spawn_node(boid_prefab, p)

		# Initialize arrays
		boids.append(b)
		velocities.append(Vector2.ZERO)
		view_distances.append(view_distance)

	# Instantiate quadtrees
	qt = QuadTree.new(Rect2(-map_size/2,map_size))
	last_qt = qt



func _physics_process(_delta):
	# Create empty quadtree
	qt = QuadTree.new(Rect2(-map_size/2,map_size))
	
	# Update position and velocity for every boid
	for i in range(num_boids):
		# Only update every second frame
		if OS.get_ticks_usec() % 2 == 0:
			velocities[i] = boids[i].move_and_slide(velocities[i])
			continue
		
		# Get flock and their collective vectors
		var flock = get_flock(i)
		var vectors = get_flock_status(boids[i].global_position, flock)
		
		# Calculate forces
		var cohesion_vector = vectors[0] * cohesion_force
		var align_vector = vectors[1] * align_force
		var separation_vector = vectors[2] * separation_force
		var flee_vector = vectors[3] * flee_force

		# Update veolcity
		var acceleration = cohesion_vector + align_vector + separation_vector + flee_vector
		var velocity = (velocities[i] + acceleration).clamped(max_speed)

		velocity = bound_position(boids[i].global_position, velocity)
		velocities[i] = boids[i].move_and_slide(velocity)

		# Insert in quadtree
		var _success = qt.insert([boids[i].global_position,i])
		update()

	last_qt = qt


func bound_position(pos: Vector2, velocity : Vector2) -> Vector2:
	var bounds = map_size * 0.5
	if pos.x < -bounds.x:
		velocity.x += out_of_bounds_force
	elif bounds.x < pos.x:
		velocity.x += -out_of_bounds_force
	if pos.y < -bounds.y:
		velocity.y += out_of_bounds_force
	elif bounds.y < pos.y:
		velocity.y += -out_of_bounds_force
	return velocity

func get_flock_status(own_pos, flock: Array):
	var center_vector: = Vector2()
	var flock_center: = Vector2()
	var align_vector: = Vector2()
	var avoid_vector: = Vector2()
	var flee_vector: = Vector2()

	for f in flock:
		var neighbor_pos: Vector2 = boids[f].global_position

		align_vector += velocities[f]
		flock_center += neighbor_pos
		
		var d = own_pos.distance_to(neighbor_pos)
		if 0 < d and d < avoid_distance:
			avoid_vector -= (neighbor_pos - own_pos).normalized() * (avoid_distance / d * max_speed)
	
	var flock_size = flock.size()
	if flock_size:
		align_vector /= flock_size
		flock_center /= flock_size
	
	if flock_center != Vector2.ZERO:
		var center_dir = own_pos.direction_to(flock_center)
		var center_speed = max_speed * (own_pos.distance_to(flock_center) / view_distance)
		center_vector = center_dir * center_speed
	
#	var flee_dir = own_pos.direction_to(player.global_position)
#	var flee_dist = (own_pos.distance_to(player.global_position) / view_distance)
#	flee_vector = Vector2.ZERO if 1 < flee_dist else max_speed * flee_dir * flee_dist

	return [center_vector, align_vector, avoid_vector, flee_vector]

func _process(_delta):
	print(Engine.get_frames_per_second())

func get_flock(i):
	var vd = view_distances[i]
	var origin = boids[i].global_position - Vector2(vd/2,vd/2)
	var flock = last_qt.query_range(Rect2(origin, Vector2(vd,vd)))
	
	# Update view radius
	if len(flock) < max_flock_size:
		view_distances[i] += 1
	else:
		view_distances[i] = view_distance
	
	# Get only the indices from the returned flock
	var indices = []
	for f in flock:
		indices.append(f[1])

	return indices


# Handles closing game when Escape is pressed
func _input(_event):
	if Input.is_action_pressed("ui_cancel"):
		get_tree().quit()

# Draw debug rectangles for every node in the quadtree
func _draw():
	if not qt:
		return
	var boundaries = qt.get_boundaries()
	for b in boundaries:
		draw_rect(b, Color.red, false, 3)




# == Helper functions == 

func spawn_node(node, pos: Vector2):
	var s = node.instance()
	s.position = pos
	self.add_child(s)
	return s

func get_random_pos_in_sphere (R : float) -> Vector2:
	var a = randf() * 2 * PI
	var r = R * sqrt(randf())

	var x = r * cos(a)
	var y = r * sin(a)
	return Vector2(x,y)


func vector_sum(vecs: Array) -> Vector2:
	var sum = Vector2.ZERO
	for v in vecs:
		sum += v
	return sum
