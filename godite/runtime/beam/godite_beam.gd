extends Node

## This is the worker-thread wrapper
class_name GoditeBeam

## It would be better to have a 'update camera' call (public); but for now
## Just doing things in _process here is convinient for quick test integrations.

var _thread: Thread 

var _trigger: Semaphore = Semaphore.new()
var _mux: Mutex = Mutex.new()

# Beam -> Diff -> Delta
var _beam: GoditeBeamCaster 
var _beam_diff: GoditeBeamDiff = GoditeBeamDiff.new()
var _beam_delta: GoditeBeamDelta = GoditeBeamDelta.new()

var _empty_delta: GoditeBeamDelta = GoditeBeamDelta.new()

var _exit: bool = false


const ENABLE_DEBUG_OUTSIDE_OF_EDITOR: bool = false

func _init(composite: GoditeComposite) -> void:
	_beam = GoditeBeamCaster.new(composite)


func _enter_tree() -> void:
	assert(not _thread)
	_thread = Thread.new()
	_thread.start(_worker_thread)
	pass
	
	
func _exit_tree() -> void:
	_exit = true
	_trigger.post()
	_thread.wait_to_finish()
	_thread = null

## For now dont rely on client code, just do here for convinience
## In production, camera should be updated soonest-possible in frame
func _process(_delta: float) -> void:
	update_camera()

func update_camera() -> void:
	_mux.lock()
	
	# Current limitation: only support of only 1 viewport
	# (not only due to this here, there are more reasons but those are easily fixed if needed)
	var viewport: Viewport = EditorInterface.get_editor_viewport_3d() if Engine.is_editor_hint() \
		else get_tree().current_scene.get_viewport()
	_beam.update_frustum(viewport)
	
	_trigger.post()
	
	_mux.unlock()


## Gets delta of cells for processing on main thread by 'renderers'
func get_delta() -> GoditeBeamDelta:
	var result: GoditeBeamDelta
	_mux.lock()
	
	# Prevent having the same delta read twice
	result = _beam_delta if _beam_delta else _empty_delta
	_beam_delta = null
		
	_mux.unlock()
	return result


## Set/update the HLOD ranges (at what ranges to subdivide / enter deeper octree-levels).
func set_hlod_ranges(ranges: Array[float], select_mode: GoditeBeamCaster.HLOD_SELECTION) -> void:
	assert(ranges.size() >= 5)
	_mux.lock()
	_beam.set_hlod_ranges(ranges, select_mode)
	_mux.unlock()


func _worker_thread() -> void:
	print("Beam workerthread started")

	while true:
		_trigger.wait()
		if _exit:
			break

		_update()

	print("Beam workerthread exiting")


func _update() -> void:
	if _beam_delta != null:
		# Data not yet read; prevent main thread from missing updates
		# and going out of sync
		return
		
	var start: int = Time.get_ticks_usec()
	
	# Get state (set of things intersecting with frustum)
	var state: GoditeBeamState = _beam.get_acive_state()
	
	if not state:
		_trigger.post() # retry
		return
	
	# Get delta from new and previous state
	var new_delta: GoditeBeamDelta = _beam_diff.diff(state)

	# Store delta for pickup by main thread
	_mux.lock()
	_beam_delta = new_delta
	_beam_delta.count = state.item_count
	_beam_delta.time_us = Time.get_ticks_usec() - start
	_mux.unlock()
