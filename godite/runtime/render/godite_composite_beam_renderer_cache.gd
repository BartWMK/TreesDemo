extends RefCounted

## Pool for MMI's so that no mesh-switching on MM's is needed
## which tanked performance 10ms+ when having 2 tree species
class_name GoditeCompositeBeamRendererCache

# This is a bit high, to allow for caching; x20 species is 20k nodes total for MMIs
const MAX_INTERSECTIONS: int = 1000 
 
const CAPACITY: int = MAX_INTERSECTIONS

var _available: Array[MultiMeshInstance3D] = []
var _active_map: Dictionary = {} # [Sector, MMI] -> Currently visible
var _cache_map: Dictionary = {}  # [Sector, MMI] -> Hidden, but remembers data
var _cache_order: Array = []     # Tracks order of release for LRU eviction

var _warned_pool_empty: bool = false

func _init(parent: Node) -> void:
	_create_pool(parent)

func claim(sector: GoditeComposeBeamSector) -> MultiMeshInstance3D:
	sector.from_cache = false
	
	# 1. Constant-time check: Already active?
	if _active_map.has(sector):
		return _active_map[sector]
	
	# 2. Constant-time check: In warm cache?
	if _cache_map.has(sector):
		var cached_mmi: MultiMeshInstance3D = _cache_map[sector]
		_cache_map.erase(sector)
		_cache_order.erase(sector) # Maintain eviction order
		_active_map[sector] = cached_mmi

		sector.from_cache = true

		return cached_mmi

	# 3. Pull from generic pool
	if not _available.is_empty():
		var mmi: MultiMeshInstance3D = _available.pop_back()
		_active_map[sector] = mmi
		return mmi
	
	# 4. Eviction: If pool is dry, steal from the oldest warm-cached item
	if not _cache_order.is_empty():
		var oldest_sector: GoditeComposeBeamSector = _cache_order.pop_front() # Get oldest released sector
		var stolen_mmi: MultiMeshInstance3D = _cache_map[oldest_sector]
		_cache_map.erase(oldest_sector)
		
		_active_map[sector] = stolen_mmi
		return stolen_mmi

	# 5. Total depletion
	if not _warned_pool_empty:
		_warned_pool_empty = true
		push_warning("BEAM renderer; total pool depletion (Active + Cache)")
	return null


func release(sector: GoditeComposeBeamSector) -> void:
	var mmi: MultiMeshInstance3D = _active_map.get(sector)
	if mmi:
		mmi.visible = false
		_active_map.erase(sector)
		
		# Add to cache and track the order for future eviction
		_cache_map[sector] = mmi
		_cache_order.push_back(sector)


func update_lod_bias(edge_quality: float) -> void:
	for sector: GoditeComposeBeamSector in _active_map.keys():
		var mmi: MultiMeshInstance3D = _active_map[sector]
		# Set LOD Bias towards edges of screen; this prevents the rendering server 
		# spherical LOD selector from causing voxels to become visibly boxy in
		# the edges and corners of the viewport when the viewport is wide.
		# Edge factor is written by the beam caster (not threadsafe)
		mmi.lod_bias = 1 + min(1, (sector.edge_factor * edge_quality) * 2)


func _create_pool(parent: Node) -> void:
	_available.resize(CAPACITY)
	for i: int in CAPACITY:
		var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mi.visible = false
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mi.multimesh = mm
		parent.add_child(mi)
		_available[i] = mi
