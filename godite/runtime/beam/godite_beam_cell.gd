@tool
extends Resource

## A beam (Octtree) cell; this is a abstract concept and the cell
## is 'virtual' in that it only desribes a box in space, but it
## does not describe any content like assets or transforms.
## For conrecte (persisted/content description) see GoditeCompositeCell
class_name GoditeBeamCell

@export var id: int # See GoditeBeamCellIdentity

@export var level: int
@export var origin: Vector3
@export var size: float

static func create(level_: int, origin_: Vector3, size_: float) -> GoditeBeamCell:
	var cell: GoditeBeamCell = GoditeBeamCell.new()
	cell.id = GoditeBeamCellIdentity.pack(level_, origin_, size_)
	cell.level = level_
	cell.origin = origin_ 
	cell.size = size_
	return cell

func get_world_aabb() -> AABB:
	return AABB(
		origin,
		Vector3(size, size, size)
	)

func get_local_aabb() -> AABB:
	return AABB(
		Vector3(-0.5 * size, -0.5 * size, -0.5 * size),
		Vector3(size, size, size)
	)
