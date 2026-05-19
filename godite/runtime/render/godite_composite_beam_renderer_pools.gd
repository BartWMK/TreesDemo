extends RefCounted

## Compound pool, maps sectors by mesh to dedicated pool
## This per-mesh stuff is a workaround for (unlike MeshInstance3D)
## MultiMeshInstance3D is horrid slow in selecting another mesh;
## (weird, because MeshInstance3D does it in 0 time, and MMI's
##  transform buffers can also be swapped in near 0 time).
class_name GoditeCompositeBeamRendererPools

var _pools: Dictionary[Mesh, GoditeCompositeBeamRendererCache] = {}
var _parent: Node

func _init(parent: Node) -> void:
	_parent = parent

func claim(sector: GoditeComposeBeamSector) -> MultiMeshInstance3D:
	return _get_pool(sector.asset.voxel_mesh).claim(sector)
	

func release(sector: GoditeComposeBeamSector) -> void:
	var pool: GoditeCompositeBeamRendererCache = _pools.get(sector.asset.voxel_mesh)
	if pool:
		pool.release(sector)


func warmup(mesh: Mesh) -> void:
	for mmi: MultiMeshInstance3D in _get_pool(mesh)._available:
		mmi.multimesh.mesh = mesh

func update_lod_bias(edge_quality: float) -> void:
	for pool: GoditeCompositeBeamRendererCache in _pools.values():
		pool.update_lod_bias(edge_quality)

func _get_pool(mesh: Mesh) -> GoditeCompositeBeamRendererCache:
	var pool: GoditeCompositeBeamRendererCache = _pools.get(mesh)
	if not pool:
		pool = GoditeCompositeBeamRendererCache.new(_parent)
		_pools.set(mesh, pool)
	return pool
	
