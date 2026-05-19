extends Node
class_name GoditeCompositeProxRenderer

var use_cards: bool
var stat_instances: int = 0

## If using many different and dense assets up close, this might need to increase
## Since the nodes do not _process; it doesnt affect performance, just a little memory.
const POOL_SIZE: int = 20000

var _available: Array[GoditeInstance3D] = []
var _map_shown: Dictionary[GoditeComposeProxSector, Array] = {}
var _warned_pool_empty: bool = false

var stat_time: int

func _ready() -> void:
	_create_pool()	


func render(delta: GoditeBeamDelta) -> void:
	stat_time = Time.get_ticks_usec()
	# Departures (first, to free up pool items for arrivals)
	_free_departures(delta.prox_departures)
	_render_arrivals(delta.prox_arrivals)
	stat_time = Time.get_ticks_usec() - stat_time


func _free_departures(sectors: Array[GoditeComposeProxSector]) -> void:
	for sector: GoditeComposeProxSector in sectors:
		var shown: Array = _map_shown.get(sector, [])
		if not shown:
			push_warning("Prox render; depart of unknown show; was the pool depleted before?")
			continue
		
		for ri: GoditeInstance3D in shown:
			ri.godite_asset = null
			_available.append(ri)

		stat_instances -= sector.transforms.size()
		_map_shown.erase(sector)


func _render_arrivals(sectors: Array[GoditeComposeProxSector]) -> void:
	for sector: GoditeComposeProxSector in sectors:
		if _available.size() < sector.transforms.size():
			if not _warned_pool_empty:
				_warned_pool_empty = true
				push_warning("PROX renderer; insufficient pool size")
			continue

		var shows: Array = []
		for t: Transform3D in sector.transforms:
			var mi: GoditeInstance3D = _available.pop_back()
			mi.transform = t
			mi.godite_asset = sector.asset
			mi.visible = true
			shows.append(mi)
			
		_map_shown.set(sector, shows)
		stat_instances += sector.transforms.size()


func _create_pool() -> void:
	print("New prox pool (mode %s)" % [ "CARDS" if use_cards else "VOXELLOD"])
	_available.resize(POOL_SIZE)
	for i: int in POOL_SIZE:
		var ri: GoditeInstance3D = GoditeInstance3D.new()
		ri.mode = GoditeInstance3D.Mode.CARD if use_cards else GoditeInstance3D.Mode.VOXEL
		ri.visible = false
		add_child(ri)
		_available[i] = ri
