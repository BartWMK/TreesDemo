extends RefCounted

## (optional) Mesh baking for higher-level (biggest, most distant) cells
##
## This takes cells, with 1 or more content sectors (different assets)
## And merges all instances (per-cell) to a single pre-baked mesh.
## This reduces the draw calls needed per most-distant sectors to '1'.
##
## Note SurfaceTool is *not* used for merging, as that is horridly slow
## due to it fetching the mesh from GPU per-append, AND it does not
## play nice when multithreaded; see godite_composite_mesh_appender
##
class_name GoditeCompositeMeshBaker

var _composite: GoditeComposite
var _cells: Array[GoditeCompositeCell]
var _cell_baker: GoditeCompositeCellBaker = GoditeCompositeCellBaker.new()

var _mesh_arrays: Dictionary[Mesh, Array] = {}

var _appenders: Array[GoditeCompositeMeshAppender] = []
var _materials: Array[Material] =[]


func _init(composite: GoditeComposite) -> void:
	_composite = composite

func bake() -> void:
	_composite.clear_baked_cells()
	
	var levels: int = _composite.bake_levels
	if levels <= 0:
		return
	
	print("Prepare baking...")
	var perf_start: int = Time.get_ticks_msec()
	
	_cells = _composite.content_map.values().filter(func (cell: GoditeCompositeCell) -> bool:
		return cell.beam_cell.level < levels and not cell.beam_sectors.is_empty() 
	)

	var count: int = _cells.size()

	# Prepare a per-cell mesh-appender with a cross-section of the assets
	# needed for the respective cell. This allows 30x+ faster baking. 
	_appenders.resize(count)
	_materials.resize(count)
	for i: int in count:
		_appenders[i] = GoditeCompositeMeshAppender.new(_mesh_arrays)

		var cell: GoditeCompositeCell = _cells[i]
		
		# Fetch meshes once, use many 
		# (opposed to surfacetool.append_from(...) which does a fetch from GPU each append!)
		for compose_beam_sector: GoditeComposeBeamSector in cell.beam_sectors:
			var asset: GoditeAsset = compose_beam_sector.asset
			
			for lod: GoditeVoxelLODAsset in asset.lods:
				var lod_mesh: Mesh = lod.mesh
				if not _mesh_arrays.has(lod_mesh):
					_mesh_arrays.set(lod_mesh, lod_mesh.surface_get_arrays(0))
				else:
					break

	var perf_prepare: int = Time.get_ticks_msec() - perf_start
	perf_start = Time.get_ticks_msec()

	# Doing this in parallel and with prepared fetch above,
	# improved stresstest scene condensing from 200 to 3 seconds!
	print("Start baking %s cells..." % count)
	WorkerThreadPool.wait_for_group_task_completion(
		WorkerThreadPool.add_group_task(_worker, _cells.size())
	)

	var perf_work: int = Time.get_ticks_msec() - perf_start
	perf_start = Time.get_ticks_msec()

	_commit()

	var perf_commit: int = Time.get_ticks_msec() - perf_start
	
	print("Baking %s cells (prep:%sms, work: %sms, commit:%sms); skipped %s due to material variation. Items condensed away: %s" % [ 
		count, 
		perf_prepare, perf_work, perf_commit, 
		_cell_baker.num_skipped,
		_cell_baker.items_condensed_away ])

## Commit all appenders, resulting in the baked meshes
func _commit() -> void:
	for i: int in _cells.size():
		var material: Material = _materials[i]
		if not material:
			continue
			
		var cell: GoditeCompositeCell = _cells[i]
		cell.baked = _appenders[i].commit(material)


func _worker(index: int) -> void:
	var cell: GoditeCompositeCell = _cells[index]
	#print("Baking cell %s" % cell.beam_cell.id)
	_materials[index] = _cell_baker.bake(cell, _appenders[index])
