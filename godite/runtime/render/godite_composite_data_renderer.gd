@tool
extends Node3D
class_name GoditeCompositeDataRenderer

class DataVisual extends MeshInstance3D:
	var content_aabb: MeshInstance3D = MeshInstance3D.new()
	
	func _init() -> void:
		add_child(content_aabb)

	const colors: Array[Color] = [
		Color(1,0,0),
		Color(0,1,1),
		Color(1,0,1),
		Color(0,1,0),
		Color(0,0,1)
	]
		
	func show_cell(cell: GoditeCompositeCell) -> void:
		var cell_world_aabb: AABB = cell.beam_cell.get_world_aabb()
		position = cell_world_aabb.get_center()
		
		mesh = GoditeAABB.to_mesh(cell.beam_cell.get_local_aabb(), colors[cell.beam_cell.level])
		visible = true
	
	func end_show() -> void:
		visible = false


var map_shown: Dictionary[GoditeCompositeCell, DataVisual]
var pool: Array[DataVisual] = []

func _ready() -> void:
	_prepare_pool(1000)

func render(delta: GoditeBeamDelta) -> void:
	if ! is_inside_tree():
		return

	# Departures first to free up pool items
	for cell: GoditeCompositeCell in delta.cell_departures:
		assert(map_shown.has(cell)) # Verify the delta system in threaded culler is correct
		var visual: DataVisual = map_shown[cell]
		
		# pool transfer
		visual.end_show()
		pool.append(visual)
		map_shown.erase(cell)

	for cell: GoditeCompositeCell in delta.cell_arrivals:
		if map_shown.has(cell): # Verify the delta system in threaded culler is correct
			print("%s is alrady in map %s" % [cell, map_shown.keys()])
			assert(false)
			
		# pool transfer
		var visual: DataVisual = pool.pop_back()
		map_shown[cell] = visual
		visual.show_cell(cell)
	

func _prepare_pool(pool_size: int) -> void:
	pool.clear()
	for i: int in pool_size:
		var visual: DataVisual = DataVisual.new()
		add_child(visual)
		pool.append(visual)
	
