@tool
extends GoditeComposeSector

## Composed content sector; to be stacked for display on the beam cells (octree cells)
## 1 sector contains 1 asset; 1 composite cell can contain multiple beam/prox sectors
## A beam sector *always* exists; a prox version 'can' exist (optional)
## Therefore the beam sector is the master source of data on load
class_name GoditeComposeBeamSector

## The asset to be drawn
@export_storage var asset: GoditeAsset

## Position for the MultiMesh, this is *NOT* a sector or center of a octree cell position!
## Sector/cell positions are a corner, while this 'position' is center of
## the transforms ('content' center); so that the multimesh is culled properly
## by the rendering server and LOD selection is properly based on content.
@export_storage var position: Vector3 

## The ground-truth transforms (pre-condensing)
## Used by prox-sectors (refernces same underlying data!),
## and used for condensing most distant sectors (reduces geometry budget use and reduces shimmering)
## This is "kind-of" mid-mapping of transforms.
@export_storage var transforms: Array[Transform3D]

# NOTE: Dont set [] as default on serialized arrays! (https://github.com/godotengine/godot/issues/116909)
# When processing mutations (future feature), this will need a bit of work (keep an index, or perform search)
## Pre-fab buffer to set on a MultiMeshInstance3D directly
## NOTE: If using 'condensing', buffer might have less transforms than transforms member!
@export_storage var buffer: PackedFloat32Array

## Link to proximity version of the sector. Depending configuration of the asset
## this sector (depending on camera distance) will be 'drawn' as multimesh3d (BeamSector)
## or as MeshInstance3D's (ProxSector)
@export_storage var prox_sector: GoditeComposeProxSector

## Count of the transforms (saves runtime from indirection to get it)
## allows fast registration of accumulative items drawn.
@export_storage var count: int

## Pack hierarchy
@export_storage var children: Array[GoditeComposeBeamSector]

## Pack range; indices into L0 buffer 
@export_storage var pack_start: int
@export_storage var pack_end: int



## Set runtime by mesh specific cache pool, allows ommiting rebind
## Note this is 'dirty' and will not work for example if having multiple cameras
var from_cache: bool = false

## Set by beam caster (note not thread safe!) 1 = at edge of screen, 0 is center
## It can be used to adjust LOD Bias for multimesh cells near edges of screen
## to counter the spherical LOD selection mode a little (improves edge quality
## at cost of CPU time)
var edge_factor: float = 0

func clear_mmi_buffer() -> void:
	buffer = []

func has_buffer() -> bool:
	return not buffer.is_empty()
	
func has_transforms() -> bool:
	return transforms and not transforms.is_empty()

## Prepare the transforms into MultiMeshInstance3D format buffer
func transforms_to_mmi_buffer(transforms_: GoditeComposeTransforms) -> void:
	var instance_count: int = transforms_.count()
	buffer.resize(instance_count * 12)
	
	# Place items around center of MMI position; *it matters for LOD selection* 
	# and any visibility distances. This would be most noticable with sparse
	# sectors with only a few items on one side or one corner.
	var center: Vector3 = transforms_.aabb.get_center()

	var transforms_list: Array[Transform3D] = transforms_.list
	
	for i: int in range(instance_count):
		var t: Transform3D = transforms_list[i]
		var idx: int = i * 12
		
		# Row 1 (Basis X + Origin X)
		buffer[idx + 0] = t.basis.x.x
		buffer[idx + 1] = t.basis.y.x
		buffer[idx + 2] = t.basis.z.x
		buffer[idx + 3] = t.origin.x - center.x
		
		# Row 2 (Basis Y + Origin Y)
		buffer[idx + 4] = t.basis.x.y
		buffer[idx + 5] = t.basis.y.y
		buffer[idx + 6] = t.basis.z.y
		buffer[idx + 7] = t.origin.y - center.y
		
		# Row 3 (Basis Z + Origin Z)
		buffer[idx + 8] = t.basis.x.z
		buffer[idx + 9] = t.basis.y.z
		buffer[idx + 10] = t.basis.z.z
		buffer[idx + 11] = t.origin.z - center.z


## Pack transforms for saving; note this clears transforms except L0
## (with the test scene, this means about 135mb > 28mb)
func pack_transforms() -> void:
	var total: int = transforms.size()
	assert(total > 0)

	var packed_buffer: Array[Transform3D] = []
	packed_buffer.resize(total)
	var end_cursor: int = _pack(packed_buffer, 0)
	assert(end_cursor == total)
	transforms = packed_buffer # Replace L0 buffer with packed version


## Upack transforms after load
func unpack_transforms() -> void:
	for child: GoditeComposeBeamSector in children:
		child._unpack(transforms)
	
	
func _pack(out_buffer: Array[Transform3D], cursor: int) -> int:
	var start: int = cursor
	for child: GoditeComposeBeamSector in children:
		cursor = child._pack(out_buffer, cursor)
	var end: int = cursor

	# Top layer, will just get the accumulated packed buffer as replacement
	if level == 0: 
		return cursor
		
	if children.is_empty():
		# Bottom layer; accumulate into buffer
		start = cursor
		for t: Transform3D in transforms:
			out_buffer[cursor] = t
			cursor += 1

		pack_start = start
		pack_end = cursor
	else:
		# Intermediate layer; gets accumulation of its children
		pack_start = start
		pack_end = end
	
	assert(pack_end - pack_start == transforms.size())

	transforms.clear()
	return cursor


func _unpack(top_buffer: Array[Transform3D]) -> void:
	transforms = top_buffer.slice(pack_start, pack_end)
	
	if prox_sector:
		prox_sector.transforms = transforms
		
	for child: GoditeComposeBeamSector in children:
		child._unpack(top_buffer)
