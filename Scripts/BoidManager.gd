extends Node2D

onready var boid_prefab = preload("res://Scenes/Boid.tscn")
onready var predator_prefab = preload("res://Scenes/Predator.tscn")

# Map bounds # TODO: Change to Vector2i in godot 4
export(Vector2) var map_size = Vector2(1750,1750)
var map_bounds = Rect2(-map_size * 0.5, map_size)
var map_center = Vector2(0,0)

# Flock properties
export(int, 0, 20) var num_predators = 5

export(int, 1, 3000) var num_boids = 1000
export(int, 1, 10) var max_flock_size = 15

# Speed
export var max_boid_speed: = 100.0

# Force strengths
export(float, -1, 1) var cohesion_force: = 0.05
export(float, -1, 1) var align_force: = 0.05
export(float, -1, 1) var separation_force: = 0.05
export(float, -1, 1) var flee_force: = 0.5
export(float, -1, 10) var center_force: = 5

# Distances
export(float, 1, 100) var view_distance: = 60.0
export(float, 1, 100) var avoid_distance: = 30.0

var grass: Rect2 = Rect2(Vector2(-500,500),Vector2(250,250))

var boids: Array
var predators: Array

var velocities: PoolVector2Array
var view_distances: Array

var predator_velocities: PoolVector2Array
var predator_view_distances: Array 

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
		velocities.append(Vector2(randf()-0.5,randf()-0.5)*max_boid_speed)
		view_distances.append(view_distance)

	for _i in range(num_predators):
		var p = get_random_pos_in_sphere(spawn_radius) 
		var b = spawn_node(predator_prefab, p)

		# Initialize arrays
		predators.append(b)

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
			move_boid(i, velocities[i])
			continue
		
		# Get flock and their collective vectors
		var flock = get_flock(i)
		var own_pos = boids[i].global_position

		var cohesion_vector = cohesion_rule(own_pos, flock) * cohesion_force
		var align_vector = align_rule(flock) * align_force
		var separation_vector = separation_rule(own_pos, flock) * separation_force
		var flee_vector = flee_rule(own_pos) * flee_force
		var center_vector = center_rule(own_pos) * center_force
		
		# Update velocity
		var acceleration = cohesion_vector + align_vector + separation_vector + flee_vector + center_vector
		var velocity = (velocities[i] + acceleration).clamped(max_boid_speed)
		
		move_boid(i, velocity)

	for i in range(num_predators):
		var flock = get_flock(i)


	# Update quadtree drawing
	update()
	last_qt = qt


func move_boid(index: int, velocity: Vector2) -> void:
	"""Move a boid with a given index by a velocity, and update the quadtree with the new position"""
	velocities[index] = boids[index].move_and_slide(velocity)
	var _success = qt.insert([boids[index].global_position,index])


func center_rule(pos: Vector2) -> Vector2:
	""" Move boids to the center of the field if they are out of bounds """
	if not map_bounds.has_point(pos):
		var center_dir = pos.direction_to(map_center)
		return center_dir
	return Vector2.ZERO


func cohesion_rule(own_pos: Vector2, flock: Array) -> Vector2:
	""" Make the boid move towards the average position of the flock """
	var flock_center: = Vector2()
	
	for f in flock:
		flock_center += boids[f].global_position
	
	if flock.size():
		flock_center /= flock.size()
		var center_dir = own_pos.direction_to(flock_center)
		var center_speed = max_boid_speed * (own_pos.distance_to(flock_center) / view_distance)
		return center_dir * center_speed
	else:
		return Vector2.ZERO


func align_rule(flock: Array) -> Vector2:
	""" Align the boid to the flock by taking the average of the velocities"""
	var align_vector: = Vector2()
	for f in flock:
		align_vector += velocities[f]
	
	if flock.size():
		align_vector /= flock.size()
	return align_vector


func separation_rule(own_pos: Vector2, flock: Array) -> Vector2:
	""" Move the boid away from the positions of the nearby boids """
	var avoid_vector: = Vector2()

	for f in flock:
		var d = own_pos.distance_to(boids[f].global_position)
		if d < avoid_distance:
			avoid_vector -= (boids[f].global_position - own_pos).normalized() * (avoid_distance / d * max_boid_speed)
	return avoid_vector


func flee_rule(own_pos: Vector2) -> Vector2:
	var flee_dir = own_pos.direction_to(get_global_mouse_position())
	var flee_dist = (own_pos.distance_to(get_global_mouse_position()) / view_distance)
	return Vector2.ZERO if 2 < flee_dist else max_boid_speed * flee_dir * flee_dist 



func get_flock(i: int) -> Array:
	"""
	Given an an index of a boid return the indicies of all other boids within its
	view distance. Increase the view distance if the max flock size isnt reached.
	"""
	var vd = view_distances[i]
	var origin = boids[i].global_position - Vector2(vd*0.5,vd*0.5)
	var flock = last_qt.query_range(Rect2(origin, Vector2(vd,vd)))
	
	# Update view radius
	if len(flock) < max_flock_size:
		view_distances[i] += 1
	else:
		view_distances[i] = view_distance
	
	# Get only the indices from the returned flock
	# Flock is returned on the form (position, index)
	var indices = []
	for f in flock:
		# Dont add the boid itself to the flock
		if i == f[1]:
			continue
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
	
	# Draw grass
	# draw_rect(grass, Color.green, true)



# == Helper functions == 

func average(arr:Array):
	""" A helper function for computing the average of a list of a given type"""
	
	# Return nothing if the array is empty
	if len(arr) == 0:
		return null
	
	var avg = arr[0]
	for i in range(1,len(arr)):
		avg += arr[i]
	return avg / len(arr)


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
