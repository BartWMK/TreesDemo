extends RefCounted

## Non-realloc buffer for beam intersections; created by caster during intersection phase
## This allows metadata to be added to the intersected composite cells
## Using non-realloc saves 1 full millisecond
class_name GoditeBeamIntersections

var list: Array[GoditeBeamIntersection] = []

const BUFFER_SIZE: int = 2500

var count: int = 0

func _init(capacity: int = BUFFER_SIZE) -> void:
	list.resize(capacity)
	for i: int in capacity:
		list[i] = GoditeBeamIntersection.new()

func push(composite_cell: GoditeCompositeCell, planar_nearest: Vector3, edge_factor: float) -> void:
	var cell: GoditeBeamIntersection = list[count]
	cell.composite_cell = composite_cell
	cell.planar_nearest = planar_nearest
	cell.edge_factor = edge_factor
	count += 1

func clear() -> void:
	count = 0
	
