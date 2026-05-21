extends RefCounted

## Compound pool, maps sectors by mesh to dedicated pool
## This per-mesh stuff is a workaround for (unlike MeshInstance3D)
## MultiMeshInstance3D is horrid slow in selecting another mesh;
## (weird, because MeshInstance3D does it in 0 time, and MMI's
##  transform buffers can also be swapped in near 0 time).
class_name GoditeCompositeBeamRendererPools

var _pools: Dictionary[GoditeAsset, GoditeCompositeBeamRendererCache] = {}
var _parent: Node

func _init(parent: Node) -> void:
	_parent = parent

func claim(sector: GoditeComposeBeamSector) -> MultiMeshInstance3D:
	return _get_pool(sector.asset).claim(sector)
	

func release(sector: GoditeComposeBeamSector) -> void:
	var pool: GoditeCompositeBeamRendererCache = _pools.get(sector.asset)
	if pool:
		pool.release(sector)


func warmup(asset: GoditeAsset, mesh: Mesh) -> void:
	for mmi: MultiMeshInstance3D in _get_pool(asset)._available:
		mmi.multimesh.mesh = mesh

func update_lod_bias(edge_quality: float) -> void:
	for pool: GoditeCompositeBeamRendererCache in _pools.values():
		pool.update_lod_bias(edge_quality)

func _get_pool(asset: GoditeAsset) -> GoditeCompositeBeamRendererCache:
	var pool: GoditeCompositeBeamRendererCache = _pools.get(asset)
	if not pool:
		pool = GoditeCompositeBeamRendererCache.new(_parent)
		_pools.set(asset, pool)
	return pool
	
