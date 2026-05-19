@tool
extends Resource

## A composite cell is the container for content sectors of a single HLOD(octree) cell
class_name GoditeCompositeCell

@export_storage var beam_cell: GoditeBeamCell # Self identity info

@export_storage var beam_sectors: Array[GoditeComposeBeamSector]
@export_storage var prox_sectors: Array[GoditeComposeProxSector]

## This is the real aggregated content AABB, *not* that of the cell
@export_storage var aabb: AABB

## Content octtree map; this allows beam caster to only check visibility 
## for content containing cells without having to do lookup
## or calls for each cell. This has max 8 entries (1 for each oct child)
## Key is cell identity (beam_cell.id)
@export_storage var leaves: Dictionary[int, GoditeCompositeCell]

## Baked mesh with the sectors combined (saves iterations & draw calls/state changes)
## This is optional and commonly only for 1 or 2 top levels (most distant) of cells.
@export_storage var baked: Mesh

## Aggregated count of items over all sectors
@export_storage var count: int

func _init() -> void:
	# Dont move these to intializers (https://github.com/godotengine/godot/issues/116909)
	beam_sectors = []
	prox_sectors = []


## Add a proximity ('near'/MeshInstance3Ds) sector to this cell
## Not meant to be used directly; use GoditeCompositeFactory
func add_prox(sector: GoditeComposeProxSector) -> void:
	prox_sectors.append(sector)
	aabb = aabb.merge(sector.aabb) if aabb.has_volume() else sector.aabb


## Add a beam ('far'/MultiMeshInstance3D) sector to this cell
## Not meant to be used directly; use GoditeCompositeFactory
func add_beam(sector: GoditeComposeBeamSector) -> void:
	beam_sectors.append(sector)
	aabb = aabb.merge(sector.aabb) if aabb.has_volume() else sector.aabb
	count += sector.count


## Merge the sectors of another cell into this one.
## Note this does not merge sectors themselves, not even if they
## use the same asset (which could be a needed future improvement)
func merge(cell: GoditeCompositeCell) -> void:
	for prox: GoditeComposeProxSector in cell.prox_sectors:
		add_prox(prox)
	for beam: GoditeComposeBeamSector in cell.beam_sectors:
		add_beam(beam)


## Get the condensed transforms array for the given sector
## Note this is a hardcoded and primitive version
func get_condensed_transforms(beam_sector: GoditeComposeBeamSector) -> Array[Transform3D]:
	
	var radius: float = 0
	match beam_cell.level:
		0: radius = 15
		1: radius = 10
		2: radius = 5
		3: radius = 4
		4: radius = 3
		_: assert(false)

	if radius == 0:
		return beam_sector.transforms

	var condensed_transforms: Array[Transform3D] = \
		GoditeCompositeTransformCondense.condense(beam_sector.transforms, radius)
		
	return condensed_transforms
