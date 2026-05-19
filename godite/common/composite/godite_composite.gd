@tool
extends Resource
class_name GoditeComposite

## When to apply condensing (reducing transforms based on HLOD level as 'distance')
## This reduces amount of geometry to draw and can prevent jitter/shimmering due
## to z-fighting of voxels being drawn over each other.
enum CondenseMode {
	DISABLED = 0,   # Do not apply condensing
	ON_SAVE = 1,    # Apply on save (larger file size, faster load)
	ON_LOAD = 2		# Apply on load (smaller file size, slower load)
}

## When to prepare MMI buffers from the transforms-arrays
## Note that when condensing 'apply on save', MMI buffers are forced to save
enum MMIBufferMode {
	ON_SAVE = 0,	# When saving (larger file size, faster load)
	ON_LOAD = 1		# When loading (smaller file size, slower load)
}

## When to bake cells (see bake levels)
enum CellBakeMode {
	ON_SAVE = 0,	# When saving (larger file size, faster load)
	ON_LOAD = 1		# When loading (smaller file size, slower load)
}


## Size of the top-level (largest HLOD octtree) cells
@export var sector_size: float = 1000.0

## Number of levels is 'dynamic'; but runtime_config is setup assuming '5'
## And dynamic means: could be defined differently before using builder classes
## Note that the proton connector currenly also set 5 levels.
@export var levels: int = 5

@export var condensing: CondenseMode = CondenseMode.ON_LOAD
@export var condense_levels: int = 2


## Number of levels of HLOD cells to bake into single mesh (0 for disable)
@export var bake_levels: int = 0
@export var bake_mode: CellBakeMode = CellBakeMode.ON_LOAD

@export var mmi_buffer_mode: MMIBufferMode = MMIBufferMode.ON_LOAD

## Content map, this is all cells (of all HLOD levels); 
## Keys are cell cantor IDs (see godite_beam_cell_identity) 
@export_storage var content_map: Dictionary[int, GoditeCompositeCell]

## Global AABB (all sectors/content)
@export_storage var aabb: AABB

## Create a new empty composite
static func create() -> GoditeComposite:
	var result: GoditeComposite = GoditeComposite.new()
	# NOTE: Dont set {} as default on serialized maps (or [] on arrays), 
	#       as it can frick up deserialize outcome in some Godot versions
	# https://github.com/godotengine/godot/issues/116909
	result.content_map = {}
	return result


## Clear MMI buffers (if prepare on-load), this reduces filesize significantly
## when saving (demo scene 140 > 28mb).
func clear_mmi_buffers() -> void:
	for cell: GoditeCompositeCell in content_map.values():
		for beam_sector: GoditeComposeBeamSector in cell.beam_sectors:
			beam_sector.clear_mmi_buffer()

## Used by tooling when rebuild or saving with bake-on-load
func clear_baked_cells() -> void:
	for cell: GoditeCompositeCell in content_map.values():
		cell.baked = null

## Used during parallel MMI prepare
var _parallel_cells: Array[GoditeCompositeCell]
var _condensed_away: int = 0


## Prepare all MMI buffers
func prepare_mmi_buffers() -> void:
	var start: int = Time.get_ticks_msec()
	
	_parallel_cells = content_map.values()
	_condensed_away = 0

	WorkerThreadPool.wait_for_group_task_completion(
		WorkerThreadPool.add_group_task(_prepare_mmi_buffer, _parallel_cells.size())
	)

	var elapsed: int = Time.get_ticks_msec() - start
	print("MMI buffer prepare took: %s ms, condensed away %s distant items over %s levels" % [elapsed, _condensed_away, condense_levels])
	_parallel_cells.clear()


## Prepare single MMI buffer; this also does on the fly condensing if enabled
func _prepare_mmi_buffer(cell_index: int) -> void:
	var cell: GoditeCompositeCell = _parallel_cells[cell_index]
		
	# MMI Buffers for cell not needed if the cell is/will be baked to single mesh
	var is_bake_cell: bool = cell.baked or cell.beam_cell.level < bake_levels
	if is_bake_cell:
		return

	for beam_sector: GoditeComposeBeamSector in cell.beam_sectors:
		
		# Condense transforms if enabled
		var transforms: Array[Transform3D] = beam_sector.transforms
		
		var do_condense: bool = condensing != CondenseMode.DISABLED and beam_sector.level < condense_levels
		if do_condense:
			var count_before: int = transforms.size()
			transforms = cell.get_condensed_transforms(beam_sector)
			_condensed_away += count_before - transforms.size()
		
		# Update MMI buffer
		beam_sector.transforms_to_mmi_buffer(GoditeComposeTransforms.new(transforms))
		# Note: Intentionally not clearing original transforms


## Bake the higher level(s) cells asset-sectors to pre-baked meshes
## This saves draw calls (more gains when more assets are used)
## at the cost of pre-prod bake times and runtime some GPU memory.
func bake_top_levels() -> void:
	# Condense top level(s) to meshes, combining all assets to single
	# draw call using MeshInstance instead of MultiMesh
	GoditeCompositeMeshBaker.new(self).bake()
	

## Pack transforms to L0 only (saves level * transforms on storage size)
## in data-order so that all underlying cells at all levels refer to 
## a continous region in the L0 buffer. 
func pack_transforms() -> void:
	for cell: GoditeCompositeCell in content_map.values():
		for beam_sector: GoditeComposeBeamSector in cell.beam_sectors:
			if beam_sector.level == 0:
				beam_sector.pack_transforms()

func unpack_transforms() -> void:
	for cell: GoditeCompositeCell in content_map.values():
		for beam_sector: GoditeComposeBeamSector in cell.beam_sectors:
			if beam_sector.level == 0:
				beam_sector.unpack_transforms()


func assert_ready_to_render() -> void:
	## Check if each cell has the appropriate meshes/buffers prepared
	for cell: GoditeCompositeCell in content_map.values():
		var is_baked: bool = cell.baked != null
		
		for beam_sector: GoditeComposeBeamSector in cell.beam_sectors:
			var is_valid: bool = beam_sector.has_buffer() != is_baked
			if not is_valid:
				assert(false) # seperate to allow breakpoint for data inspection
