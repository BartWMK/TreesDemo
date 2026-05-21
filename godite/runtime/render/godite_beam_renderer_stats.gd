extends RefCounted
class_name GoditeBeamRendererStats

## 'Renderers' times
var _max_dist_time: float
var _max_beam_time: float
var _max_prox_time: float

## Main thread time
var _max_main_time: float

## Worker thread time
var _max_work_time: float

## Items drawn
var _max_input_count: int
var _max_draw_count: int

var _last_trace_time: float

## Number of sectors drawn
var _stat_beam_sectors: int
var _stat_prox_sectors: int

## MMI update timing
var _max_mmi_buffer_time: int
var _max_mmi_mesh_time: int

var _main_start: int

func pre_render() -> void:
	_main_start = Time.get_ticks_usec()

func post_render(renderer: GoditeBeamRenderer, beam_delta: GoditeBeamDelta) -> void:
	_stat_beam_sectors += beam_delta.beam_arrivals.size() - beam_delta.beam_departures.size()
	_stat_prox_sectors += beam_delta.prox_arrivals.size() - beam_delta.prox_departures.size()

	_max_dist_time = maxf(_max_dist_time, renderer._dist_renderer.stat_time)
	_max_beam_time = maxf(_max_beam_time, renderer._beam_renderer.stat_time)
	_max_prox_time = maxf(_max_prox_time, renderer._prox_renderer.stat_time)
	
	_max_work_time = maxf(_max_work_time, beam_delta.time_us)
	_max_main_time = maxf(_max_main_time, Time.get_ticks_usec() - _main_start)

	_max_mmi_buffer_time = maxi(_max_mmi_buffer_time, renderer._beam_renderer.stat_buffer_select)
	_max_mmi_mesh_time = maxi(_max_mmi_mesh_time, renderer._beam_renderer.stat_mesh_select)

	var drawn: int = renderer._beam_renderer.stat_instances \
					+ renderer._prox_renderer.stat_instances \
					+ renderer._dist_renderer.stat_instances

	_max_draw_count = maxi(_max_draw_count, drawn)
	_max_input_count = maxi(_max_input_count, beam_delta.count)

	var now: int = Time.get_ticks_msec()
	if now - _last_trace_time < 1000:
		return
	
	print("CPU; mainthr: %sms (d: %sms, b: %sms[%s,%s], p: %sms), workerthr: %sms, items input/drawn: %s/%s, p=%s b=%s" % [
		_max_main_time / 1000.0,
		_max_dist_time / 1000.0,
		_max_beam_time / 1000.0,

		_max_mmi_buffer_time / 1000.0,
		_max_mmi_mesh_time / 1000.0,
		
		_max_prox_time / 1000.0,
		_max_work_time / 1000.0,
		_max_input_count,
		_max_draw_count,
		_stat_prox_sectors,
		_stat_beam_sectors
		])
			
	_max_main_time = 0
	_max_dist_time = 0
	_max_beam_time = 0
	
	_max_mmi_buffer_time = 0
	_max_mmi_mesh_time = 0
	
	_max_prox_time = 0
	_max_work_time = 0
	_max_input_count = 0
	_max_draw_count = 0
	_last_trace_time = now
