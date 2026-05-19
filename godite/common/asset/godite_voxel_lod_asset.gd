extends Resource

## Voxelized version of a specific resolution for 1 LOD level
## For game-deliverable, this is NOT needed, its convinient
## to have, to be able to-rebuild the owning assets mesh with changing
## indicator colors for example.
## It is also used if baking 1 or more top-levels to reduce drawcalls
class_name GoditeVoxelLODAsset

# Fields editable that have effect when rebuild mesh from LODs
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		emit_changed()

## Edge length as calculated by authoring tool
@export var edge_length: float

## Distance as calculated by by authoring tool
@export var distance: float

## If set, re-merge into voxel_mesh will make this LOD highlighted in red
@export var colorize: bool = false:
	set(value):
		if colorize == value:
			return
		colorize = value
		emit_changed()

## Read-only; reflection of stored resolution field, indicator in inspector
@warning_ignore("unused_private_class_variable")
@export var _resolution: int:
	get():
		return resolution
	set(value):
		pass

@export_storage var voxel_size: float
@export_storage var resolution: int

## Approximate volume occupied by source voxel grid
@export_storage var volume: float

## Tight voxelized mesh AABB
@export_storage var aabb: AABB

@export var mesh: Mesh
