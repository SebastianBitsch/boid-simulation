extends Node2D

class_name QuadTree

export(int, 1, 20) var NODE_CAPACITY: int = 100
export(int, 1, 15) var MAX_QUERY_SIZE: int = 10

# Boundary is represented as 2 x Vector2, 
# one for origin (bottom left corner) and one for size 
#TODO: Coded as thorugh the origin was top left corner - so some things may be wrong
var boundary: Rect2
var points: Array

# Children
var north_west: QuadTree
var north_east: QuadTree
var south_west: QuadTree
var south_east: QuadTree

func _init(_boundary: Rect2 = Rect2()):
	boundary = _boundary

func get_boundaries():
	var boundaries = [boundary]
	if north_west:
		boundaries += north_west.get_boundaries()
	if north_east:
		boundaries += north_east.get_boundaries()
	if south_west:
		boundaries += south_west.get_boundaries()
	if south_east:
		boundaries += south_east.get_boundaries()
	return boundaries

func insert(p: Array) -> bool:

	if not boundary.has_point(p[0]):
		return false
	
	if len(points) < NODE_CAPACITY and north_west == null:
		points.append(p)
		return true
	
	if north_west == null:
		subdivide()
	
	if north_west.insert(p):
		return true
	if north_east.insert(p):
		return true
	if south_west.insert(p):
		return true
	if south_east.insert(p):
		return true
	
	print("ERROR: This should never happen")
	return false

func subdivide():
	var origin = boundary.position
	var half_width = boundary.size.x*0.5
	var half_height = boundary.size.y*0.5

	var size = Vector2(half_width, half_height)
	north_west = get_script().new(Rect2(origin, size))
	north_east = get_script().new(Rect2(origin+Vector2(half_width,0), size))
	south_west = get_script().new(Rect2(origin+Vector2(0, half_height), size))
	south_east = get_script().new(Rect2(origin+Vector2(half_width,half_height), size))
	for p in points:
		if north_west.insert(p):
			break
		if north_east.insert(p):
			break
		if south_west.insert(p):
			break
		if south_east.insert(p):
			break
	points = []


func query_range(_range: Rect2):
	var points_in_range: Array = []
	
	if not boundary.intersects(_range):
		return points_in_range
	
	for p in points:
		if _range.has_point(p[0]):
			points_in_range.append(p)
	
	if not north_west:
		return points_in_range
	
	if len(points_in_range) < MAX_QUERY_SIZE:
		points_in_range += north_west.query_range(_range)
	if len(points_in_range) < MAX_QUERY_SIZE:
		points_in_range += north_east.query_range(_range)
	if len(points_in_range) < MAX_QUERY_SIZE:
		points_in_range += south_west.query_range(_range)
	if len(points_in_range) < MAX_QUERY_SIZE:
		points_in_range += south_east.query_range(_range)
	
	return points_in_range
