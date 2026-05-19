extends RefCounted
class_name GoditeCompositeCellBaker

var num_baked: int = 0
var num_skipped: int = 0
var items_condensed_away: int = 0

## Bake to appender offline-mesh (commit that to get live mesh)
## Returns material if baked, null if not bake/condense-able
## NOTE: this currently assumes homogenous material use
func bake(cell: GoditeCompositeCell, appender: GoditeCompositeMeshAppender) -> Material:
	
	var material: Material = null
		
	for beam_sector: GoditeComposeBeamSector in cell.beam_sectors:
		var lod_mesh: Mesh = get_bake_lod_mesh(beam_sector.asset).mesh
		var lod_material: Material = lod_mesh.surface_get_material(0)
		if not material:
			material = lod_material

		var transforms: Array[Transform3D] = cell.get_condensed_transforms(beam_sector)
		items_condensed_away += beam_sector.transforms.size() - transforms.size()
		
		# Transform needs to become local to cell corner; allows instances to 
		# just take cell position and not have to calc/add center
		var origin_offset: Vector3 = cell.beam_cell.origin
		for t: Transform3D in transforms:
			t.origin -= origin_offset
			appender.append_mesh_surface(lod_mesh, t)

	#cell.baked = st.commit() <- Must be done on main thread; see composite condenser
	assert(material)
	num_baked += 1
	return material


static func get_bake_lod_mesh(asset: GoditeAsset) -> GoditeVoxelLODAsset:
	# TODO: This should consider cell distance configurations and per-asset
	# dimensions / view distances. (not all of that is accesible here...)
	return asset.lods[-1]
