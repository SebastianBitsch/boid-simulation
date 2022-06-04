extends Node2D

onready var boid_prefab = preload("res://Scenes/Boid.tscn")
onready var predator_prefab = preload("res://Scenes/Predator.tscn")

# Map bounds # TODO: Change to Vector2i in godot 4
export(Vector2) var map_size = Vector2(1750,1750)

# Flock properties
export(int, 0, 20) var num_predators = 5
export(int, 1, 10000) var num_boids = 1500
export(int, 1, 10) var max_flock_size = 15

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

var grass: Rect2 = Rect2(Vector2(-250,-250),Vector2(500,500))

var boids: Array
var predators: Array

var velocities: Array
var view_distances: Array
var hunger: Array
var eating: Array

var predator_velocities: Array
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
		velocities.append(Vector2(randf()-0.5,randf()-0.5)*max_speed)
		view_distances.append(view_distance)
		hunger.append(0)
		eating.append(false)

	for _i in range(num_predators):
		var p = get_random_pos_in_sphere(spawn_radius) 
		var b = spawn_node(predator_prefab, p)

		# Initialize arrays
		predators.append(b)

	# Instantiate quadtrees
	qt = QuadTree.new(Rect2(-map_size/2,map_size))
	last_qt = qt

func _process(_delta):
	for i in range(num_boids):
		if eating[i]:
			hunger[i] -= 2
			if hunger[i] <= 0:
				hunger[i] = 0
				eating[i] = false
			continue
			
		if should_eat(i):
			eating[i] = true
		else:
			hunger[i] += 1

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
		
		var acceleration = cohesion_vector + align_vector + separation_vector + flee_vector
		
		if eating[i]:
			acceleration = -velocities[i] * 0.02 + flee_vector
		
		# Update velocity
		var velocity = (velocities[i] + acceleration).clamped(max_speed)
		velocity = bound_position(boids[i].global_position, velocity)
		
		move_boid(i, velocity)

	# Update quadtree drawing
	update()
	last_qt = qt


func move_boid(index: int, velocity: Vector2) -> void:
	"""Move a boid with a given index by a velocity, and update the quadtree with the new position"""
	velocities[index] = boids[index].move_and_slide(velocity)
	var _success = qt.insert([boids[index].global_position,index])


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

func cohesion_rule(own_pos: Vector2, flock: Array) -> Vector2:
	var flock_center: = Vector2()
	
	for f in flock:
		flock_center += boids[f].global_position
	
	if flock.size():
		flock_center /= flock.size()
		var center_dir = own_pos.direction_to(flock_center)
		var center_speed = max_speed * (own_pos.distance_to(flock_center) / view_distance)
		return center_dir * center_speed
		
	return Vector2.ZERO

func align_rule(flock: Array) -> Vector2:
	var align_vector: = Vector2()
	for f in flock:
		align_vector += velocities[f]
	
	if flock.size():
		align_vector /= flock.size()
	return align_vector

func separation_rule(own_pos: Vector2, flock: Array) -> Vector2:
	var avoid_vector: = Vector2()

	for f in flock:
		var d = own_pos.distance_to(boids[f].global_position)
		if d < avoid_distance:
			avoid_vector -= (boids[f].global_position - own_pos).normalized() * (avoid_distance / d * max_speed)
	return avoid_vector


func flee_rule(own_pos: Vector2) -> Vector2:
	var flee_dir = own_pos.direction_to(get_global_mouse_position())
	var flee_dist = (own_pos.distance_to(get_global_mouse_position()) / view_distance)
	return Vector2.ZERO if 2 < flee_dist else max_speed * flee_dir * flee_dist 

func should_eat(index: int) -> bool:
	return grass.has_point(boids[index].global_position) and 1000 < hunger[index]


func get_flock(i: int) -> Array:
	"""
	Given an an index of a boid return the indicies of all other
	boids within its view distance.
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
