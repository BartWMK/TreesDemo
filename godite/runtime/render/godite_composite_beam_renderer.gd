extends Node
class_name GoditeCompositeBeamRenderer

var use_cards: bool

var stat_instances: int = 0

var _pools: GoditeCompositeBeamRendererPools
var _composite: GoditeComposite
var _edge_quality: float

var stat_time: int

func _init(composite: GoditeComposite) -> void:
	_composite = composite


func _ready() -> void:
	_clear() # Resets pool
	_cache_pool_warmup()


func set_edge_quality(edge_quality: float) -> void:
	_edge_quality = edge_quality

func render(delta: GoditeBeamDelta) -> void:
	stat_time = Time.get_ticks_usec()

	# Departures (first, to free up pool items for arrivals)
	_free_departures(delta.beam_departures)
	_render_arrivals(delta.beam_arrivals)

	# This is expensive; but improves edge/corner quality of MMIs
	_pools.update_lod_bias(_edge_quality)

	stat_time = Time.get_ticks_usec() - stat_time


func _free_departures(sectors: Array[GoditeComposeBeamSector]) -> void:
	for sector: GoditeComposeBeamSector in sectors:
		_pools.release(sector)
		stat_instances -= sector.count


func _render_arrivals(sectors: Array[GoditeComposeBeamSector]) -> void:
	for sector: GoditeComposeBeamSector in sectors:
		var mmi: MultiMeshInstance3D = _pools.claim(sector)
		if not mmi:
			return # Pool depleted
			
		# Cache pool sets from cache flag on sector
		if not sector.from_cache:
			var asset: GoditeAsset = sector.asset
			#var aabb: AABB = sector.aabb
			#aabb.position = Vector3.ZERO
			#mmi.multimesh.custom_aabb = aabb
			#mmi.custom_aabb = aabb

			mmi.multimesh.instance_count = int(sector.buffer.size() / 12.0)
			mmi.multimesh.buffer = sector.buffer

			var mesh: Mesh = asset.card_mesh if use_cards else asset.voxel_mesh
			if mmi.multimesh.mesh != mesh:
				mmi.multimesh.mesh = mesh
			
			mmi.position = sector.position
			mmi.cast_shadow = asset.cluster_shadow_casting as MeshInstance3D.ShadowCastingSetting

		mmi.visible = true
		stat_instances += sector.count



func _clear() -> void:
	_pools = GoditeCompositeBeamRendererPools.new(self)
	stat_instances = 0


## Setting mesh on a MMI is tragically slow; both first and consequitive times
## So dedicated pools, and warmed up to prevent 10+ms stutters.
## This is a Godot 4.x issue; and should not be the case...
## (Normal meshinstance doesnt have that issue, and MMI's transform buffer also not)
func _cache_pool_warmup() -> void:
	var start: int = Time.get_ticks_usec()
	
	var meshes: Dictionary[Mesh, bool] = {}
	for cell: GoditeCompositeCell in _composite.content_map.values():
		for sector: GoditeComposeBeamSector in cell.beam_sectors:
			GoditeAssetFade.apply(sector.asset, use_cards)
			
			var mesh: Mesh = sector.asset.card_mesh if use_cards else sector.asset.voxel_mesh
			if meshes.has(mesh):
				continue
			meshes.set(mesh, true)	
			_pools.warmup(mesh)

	print("Beam renderer cache pool warmup: %sms" % ((Time.get_ticks_usec() - start) / 1000.0))
