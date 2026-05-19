extends RefCounted
class_name GoditeBeamDiff

var _previous_state: GoditeBeamState = GoditeBeamState.new()
var _empty_delta: GoditeBeamDelta = GoditeBeamDelta.new()

func diff(state: GoditeBeamState) -> GoditeBeamDelta:
	if not state:
		return _empty_delta

	# TODO: func disabled Optimize equal case (at slight cost for non equal case)
	#if is_equal(state):
		#return _empty_delta

	var new_delta: GoditeBeamDelta = GoditeBeamDelta.new()

	# New Beam arrivals for show
	for sector: GoditeComposeBeamSector in state.beam_sectors:
		if _previous_state.beam_sectors.has(sector):
			continue
		assert(!new_delta.beam_arrivals.has(sector))
		new_delta.beam_arrivals.append(sector)

	# New Prox arrivals for show
	for sector: GoditeComposeProxSector in state.prox_sectors:
		if _previous_state.prox_sectors.has(sector):
			continue
		assert(!new_delta.prox_arrivals.has(sector))
		new_delta.prox_arrivals.append(sector)


	# Beam departures for hide
	for sector: GoditeComposeBeamSector in _previous_state.beam_sectors:
		if state.beam_sectors.has(sector):
			continue
		assert(!new_delta.beam_departures.has(sector))
		new_delta.beam_departures.append(sector)

	# Prox departures for hide
	for sector: GoditeComposeProxSector in _previous_state.prox_sectors:
		if state.prox_sectors.has(sector):
			continue
		assert(!new_delta.prox_departures.has(sector))
		new_delta.prox_departures.append(sector)


	# Cell diff for condensed renderer (only top levels)
	# New cell arrivals for show
	for cell: GoditeCompositeCell in state.dist_sectors:
		if _previous_state.dist_sectors.has(cell):
			continue
		assert(!new_delta.dist_arrivals.has(cell))
		new_delta.dist_arrivals.append(cell)

	# Cell departures for hide
	for cell: GoditeCompositeCell in _previous_state.dist_sectors:
		if state.dist_sectors.has(cell):
			continue
		assert(!new_delta.dist_departures.has(cell))
		new_delta.dist_departures.append(cell)	


	# Cell diff data renderer; editor only
	# This does *all* cells (bad performance); 
	# condenser only needs specific level(s)
	if Engine.is_editor_hint() or GoditeBeam.ENABLE_DEBUG_OUTSIDE_OF_EDITOR:
		# New cell arrivals for show
		for cell: GoditeCompositeCell in state.cells:
			if _previous_state.cells.has(cell):
				continue
			assert(!new_delta.cell_arrivals.has(cell))
			new_delta.cell_arrivals.append(cell)

		# Cell departures for hide
		for cell: GoditeCompositeCell in _previous_state.cells:
			if state.cells.has(cell):
				continue
			assert(!new_delta.cell_departures.has(cell))
			new_delta.cell_departures.append(cell)


	# Prepare for next diff
	_previous_state = state
	
	return new_delta



# FIXME: Ronsider / reinstate (after the delta overhaul)
func is_equal(_state: GoditeBeamState) -> bool:
	return false
	#var count: int = state.size()
	#if count != _previous_state.size():
		#return false
		#
	#for i: int in count:
		#if state[i] != _previous_state[i]:
			#return false
			#
	#return true
