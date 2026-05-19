extends Node
class_name GoditeCompositeDistRenderer

var stat_instances: int = 0

# Not expecting huge counts of dist sectors (as near it destroys LOD selection,
# and condensing doesnt support LOD selection anyway, it would bring great POP)
const POOL_SIZE: int = 500

var _available: Array[MeshInstance3D] = []
var _map_shown: Dictionary[GoditeCompositeCell, MeshInstance3D] = {}
var _warned_pool_empty: bool = false

var stat_time: int

func _ready() -> void:
	_create_pool()	


func render(delta: GoditeBeamDelta) -> void:
	stat_time = Time.get_ticks_usec()
	_free_departures(delta.dist_departures) # Departures first, frees pool for arrivals
	_render_arrivals(delta.dist_arrivals)
	stat_time = Time.get_ticks_usec() - stat_time


func _free_departures(cells: Array[GoditeCompositeCell]) -> void:
	for cell: GoditeCompositeCell in cells:
		var shown: MeshInstance3D = _map_shown.get(cell)
		if not shown:
			push_warning("Dist render; depart of unknown show; was the pool depleted before?")
			continue
		
		shown.visible = false
		shown.mesh = null
		_available.append(shown)

		stat_instances -= cell.count
		_map_shown.erase(cell)


func _render_arrivals(cells: Array[GoditeCompositeCell]) -> void:
	for cell: GoditeCompositeCell in cells:
		if _available.is_empty():
			if not _warned_pool_empty:
				_warned_pool_empty = true
				push_warning("Dist renderer; insufficient pool size")
			continue

		var mi: MeshInstance3D = _available.pop_back()

		# Position taken here must match with how condenser adjusted the transforms	
		mi.global_position = cell.beam_cell.origin
		
		mi.mesh = cell.baked
		mi.visible = true
			
		_map_shown.set(cell, mi)
		stat_instances += cell.count


func _create_pool() -> void:
	_available.resize(POOL_SIZE)
	for i: int in POOL_SIZE:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.visible = false
		add_child(mi)
		_available[i] = mi
