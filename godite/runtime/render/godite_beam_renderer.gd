@tool
extends Node

## Main 'top level' "renderer"
## Propagates the 'diff' to the specialty renders
class_name GoditeBeamRenderer

var _composite: GoditeComposite

var _beam: GoditeBeam

var _prox_renderer: GoditeCompositeProxRenderer # Proximity, MeshInstance3Ds
var _beam_renderer: GoditeCompositeBeamRenderer # 'Far', MultiMeshInstance3Ds
var _dist_renderer: GoditeCompositeDistRenderer # Baked (multi-asset), MeshInstance3Ds
var _data_renderer: GoditeCompositeDataRenderer # Debug overlay

var _stats: GoditeBeamRendererStats = GoditeBeamRendererStats.new()

var _configuration: GoditeRuntimeConfig:
	set(value):
		if _configuration and _configuration.hlod_changed.is_connected(_on_hlod_changed):
			_configuration.hlod_changed.disconnect(_on_hlod_changed)
		
		_configuration = value

		if _configuration:
			_configuration.hlod_changed.connect(_on_hlod_changed)

var editor: bool = Engine.is_editor_hint()

func _exit_tree() -> void:
	_stop()


func _enter_tree() -> void:
	_start()


func _init(composite: GoditeComposite) -> void:
	_composite = composite


func configure(configuration: GoditeRuntimeConfig) -> void:
	_configuration = configuration


func _on_hlod_changed() -> void:
	if not _beam:
		return
		
	# Beam wants it in HLOD0 first order
	var lod3_dubdiv_distance: float = _configuration.level_4_range_end
	var lod2_dubdiv_distance: float = lod3_dubdiv_distance + _configuration.level_3_range_end
	var lod1_dubdiv_distance: float = lod2_dubdiv_distance + _configuration.level_2_range_end
	var lod0_dubdiv_distance: float = lod1_dubdiv_distance + _configuration.level_1_range_end
	# LOD0 (1k box) is drawn to infinity; only limited by per-item draw distance settings
	
	# The 0 end value is for HLOD4 (or 'max') which cannot be subdivided (value not used)
	var hlod_distances: Array[float] = [
		lod0_dubdiv_distance, 
		lod1_dubdiv_distance, 
		lod2_dubdiv_distance, 
		lod3_dubdiv_distance, 0 ]
		
	_beam.set_hlod_ranges(hlod_distances, _configuration.hlod_selection_mode)


func get_main_root_viewport() -> Viewport:
	if editor:
		var editor_viewport: Viewport = EditorInterface.get_editor_main_screen().get_viewport()
		return editor_viewport
	return Engine.get_main_loop().root
	
	
func _process(_delta: float) -> void:
	if not _beam:
		return

	_stats.pre_render()
		
	var beam_delta: GoditeBeamDelta = _beam.get_delta()
	
	_beam_renderer.set_edge_quality(_configuration.screen_edge_quality)
	
	if editor:
		ProjectSettings.set_setting("rendering/mesh_lod/lod_change/threshold_pixels", _configuration.screen_distance_quality)
	else:
		get_viewport().mesh_lod_threshold = _configuration.screen_distance_quality
	
	var draw_data: bool = (editor or GoditeBeam.ENABLE_DEBUG_OUTSIDE_OF_EDITOR) \
							and _configuration.draw_debug_data
		
	if _configuration.draw_dist_sectors: 	_dist_renderer.render(beam_delta)
	if _configuration.draw_far_sectors:		_beam_renderer.render(beam_delta)
	if _configuration.draw_near_sectors:	_prox_renderer.render(beam_delta)
	if draw_data:							_data_renderer.render(beam_delta)

	_stats.post_render(self, beam_delta)



func _stop() -> void:
	if _dist_renderer:
		_dist_renderer.queue_free()
		_dist_renderer = null
	if _beam_renderer:
		_beam_renderer.queue_free()
		_beam_renderer = null
	if _prox_renderer:
		_prox_renderer.queue_free()
		_prox_renderer = null
	if _data_renderer:
		_data_renderer.queue_free()
		_data_renderer = null
		
	if _beam:
		_beam.queue_free()
		_beam = null
	

func _start() -> void:
	_stop()

	if not _composite:
		return
	
	_beam = GoditeBeam.new(_composite)
	add_child(_beam)
	_on_hlod_changed()

	_dist_renderer = GoditeCompositeDistRenderer.new()
	_beam_renderer = GoditeCompositeBeamRenderer.new(_composite)
	_prox_renderer = GoditeCompositeProxRenderer.new()
	
	_prox_renderer.use_cards = _configuration.use_cards
	_beam_renderer.use_cards = _configuration.use_cards
	
	_beam.add_child(_dist_renderer)
	_beam.add_child(_beam_renderer)
	_beam.add_child(_prox_renderer)

	if editor or GoditeBeam.ENABLE_DEBUG_OUTSIDE_OF_EDITOR:
		_data_renderer = GoditeCompositeDataRenderer.new()
		_beam.add_child(_data_renderer)
