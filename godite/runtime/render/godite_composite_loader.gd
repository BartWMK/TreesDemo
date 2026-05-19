extends RefCounted
class_name GoditeCompositeLoader


static func load_composite(path: String, config: GoditeRuntimeConfig) -> GoditeComposite:
	if not path or path.is_empty():
		return null
	
	var start_time: int = Time.get_ticks_msec()
	print("Loading composite...")
	# NOTE: Cache ignore, or it will save the composite (unpacked) on scene saves in the editor.
	#       Do make sure just to load once, as it will not be shared unlike in normal modes.
	var composite: GoditeComposite = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	
	if not composite:
		push_error("Error loading composite!")
		return

	print("Loading done in %sms ; content map size: %s" % [
		(Time.get_ticks_msec() - start_time), composite.content_map.size()
	])

	var unpack_start_time: int = Time.get_ticks_msec()
	composite.unpack_transforms()
	print("Unpack done in %sms" % [ Time.get_ticks_msec() - unpack_start_time] )

	if not config:
		_post_load(composite, false)
		return composite

	config.emit_changes = false
	
	composite.bake_levels = config.bake_levels
	composite.condense_levels = config.condense_levels
	
	config.emit_changes = true
	
	_post_load(composite, true)
	
	return composite


static func _post_load(composite: GoditeComposite, force_update: bool) -> void:
	var mmi_on_load: bool = composite.mmi_buffer_mode == GoditeComposite.MMIBufferMode.ON_LOAD
	var condense_on_load: bool = composite.condensing == GoditeComposite.MMIBufferMode.ON_LOAD
	
	var update_mmi_buffers: bool = mmi_on_load or condense_on_load or force_update
	
	if not update_mmi_buffers:
		return
	
	composite.clear_mmi_buffers()
	
	composite.prepare_mmi_buffers()

	if force_update || composite.bake_mode == GoditeComposite.CellBakeMode.ON_LOAD:
		composite.bake_top_levels()

	#var stats: GoditeCompositeStats = GoditeCompositeStats.new(composite)
	#stats.trace_stats()
	
	composite.assert_ready_to_render()

	
