extends RefCounted
class_name GoditeBeamCaster

## Intersect data with frustum
## This is frustum culling with the extra of coupled configuration to have the culler
## apply rules (draw distance, MMI vs MI instancing, baked cells etc.) to the output.

enum HLOD_SELECTION {
	SPHERICAL = 0,
	PLANAR = 1
}

var _select_mode: HLOD_SELECTION = HLOD_SELECTION.PLANAR

var _levels: int
var _top_cell_size: float
var _composite: GoditeComposite

# Camera node cannot be used outside of main thread; so need to store
# some (pre-calculated) things for use during culling.
var _has_camera: bool = false
var _viewport_size: Vector2i
var _cam_pos: Vector3
var _view_projection: Projection
var _max_radius: float
var _cam_forward: Vector3
var _near_plane_point: Vector3
var _near_plane_normal: Vector3

# Part of optimsation taking advantage of ya average world being vertically limited
# (unless your making a space simulation, this helps a lot in reducing cpu time)
var _topcell_y_min: int
var _topcell_y_max: int

## Prefab empty result when no camera, in error or disabled.
var _empty_results: GoditeBeamIntersections = GoditeBeamIntersections.new(1)

## Results of intersection with the frustum
## Output of phase 1 (get active cells)
## Input for the rule based output phase 2 (get active state)
var _intersect_results: GoditeBeamIntersections = GoditeBeamIntersections.new()

## Non reallocating buffer per-HLOD level (optimisation)
var _intersect_corners: GoditeBeamCornerBuffer

## Cell traversal count; just for debug tracing
var _intersect_traversals: int

# Ranges at which subdivision is performed
# Called begin range here, as when the distance if below the value,
# a deeper hlod begins.
var _level_begin_ranges: Array[float] = [ # These are known-good defaults
	2000,   #1000
	1000,   #500
	500,    #250
	200,    #125
	0#75,     #62
]

func _init(composite: GoditeComposite) -> void:
	_levels = composite.levels
	_top_cell_size = composite.sector_size
	_composite = composite
	
	# Optimisation regarding that most worlds have limited verticality
	_topcell_y_min = int(floor(composite.aabb.position.y / _top_cell_size)) 
	_topcell_y_max = int(floor((composite.aabb.position.y + composite.aabb.size.y) / _top_cell_size)) 

	_intersect_corners = GoditeBeamCornerBuffer.new(_levels)

## Set configuration
func set_hlod_ranges(ranges: Array[float], select_mode_: HLOD_SELECTION) -> void:
	assert(ranges.size() >= 5)
	_level_begin_ranges = ranges
	_select_mode = select_mode_

## Call this from main thread; this takes over needed camera data
func update_frustum(viewport: Viewport) -> void:
	_viewport_size = viewport.get_visible_rect().size # Note: not in pixels
	
	var camera: Camera3D = viewport.get_camera_3d()
	if not camera:
		_has_camera = false
		return	

	# Get things needed to (un)project etc. later in workerthread
	# (Cant use camera for unproject, as it bombs out when not on main thread)
	var transform: Transform3D = camera.global_transform
	var projection: Projection = camera.get_camera_projection()
	
	_view_projection = projection * Projection(transform.affine_inverse())

	_cam_pos = transform.origin
	_max_radius = camera.far
	_cam_forward = -transform.basis.z.normalized()
	var near_dist: float = projection.get_z_near()
	_near_plane_normal = _cam_forward
	_near_plane_point = transform.origin + (_cam_forward * near_dist)
		
	_has_camera = true

## STAGE 2 (get_acive_state) - workerthread
## ==================================================
## Now each cell is known, per cell multiple content sectors
## - Discard content sectors beyond their level visibility end-range
## - Do per content sector apply rules based on asset's configuration
## - Create a state
func get_acive_state() -> GoditeBeamState:
	# NOTE: Must return fresh instance, as diffing will save it as state to compare later
	var result: GoditeBeamState = GoditeBeamState.new()
	
	var cell_state: GoditeBeamIntersections = _get_active_cells()
	
	#print("Cells intersected: " + str(cell_state.count) + " traversals: " + str(_intersect_traversals))
	
	# This is where the composite CELLs are SPLIT into SECTOR types to be rendered
	# Its the asset that dictates the rules for sector visibility and sector type selection
	# Instance level visibility lives in the renderer
	
	var item_count: int = 0
	for i: int in cell_state.count:
		var intersection: GoditeBeamIntersection = cell_state.list[i]
		var cell: GoditeCompositeCell = intersection.composite_cell

		# For data renderer
		result.cells.set(cell, true)

		# For baked (dist) renderer
		if cell.baked:
			result.dist_sectors.set(cell, 0)
			item_count += 0 # FIXME: Dont have top level count yet; make and set during build
			continue

		# Beam(MMI) and Prox(Inst) renderers
		var near_corner_dist: float = intersection.planar_nearest.distance_to(_cam_pos)
		for item: GoditeComposeBeamSector in cell.beam_sectors:
			var asset: GoditeAsset = item.asset

			# Per asset max draw distance
			var draw_end_dist: float = asset.sector_faux_end
			if draw_end_dist > 0 and near_corner_dist > asset.sector_faux_end:
				continue

			# For proximity renderer?
			if item.prox_sector: # Only if prox version available
				var use_sectors_from: float = asset.sector_faux_from
				var use_prox: bool = false
				
				if use_sectors_from <= 0:
					use_prox = true # setting of 0 means always use prox at deepest level
				else:
					use_prox = near_corner_dist < use_sectors_from

				if use_prox:
					result.prox_sectors.set(item.prox_sector, 0)
					item_count += item.prox_sector.transforms.size()
					continue

			# For beam renderer
			result.beam_sectors.set(item, 0)
			item.edge_factor = intersection.edge_factor
			item_count += item.count
	
	result.item_count = item_count
	return result

const ID_OFFSET_3D: int = GoditeBeamCellIdentity.OFFSET_3D
 
## STAGE 1: Get active cell state (_get_active_cells) - workerthread
## ==================================================
## - Get cell range around camera (raidus = FAR)
##  - Find cells in range that intersect frustum:
##    Perform HLOD recursion:
##     1. Has cell content? -> no > discard
##     2. Is content AABB in frustum? no > discard
##     3. Is cell beyond its begin-range? no > RECURSE
##  - (1+2+3 = yes) store cell as 'ACTIVE' 
##
func _get_active_cells() -> GoditeBeamIntersections:
	_intersect_traversals = 0
	_intersect_results.clear()
	
	if not _has_camera: return _empty_results
	
	# Note: Using a non-realloc buffer saves +- 1 full millisecond
	
	var start_x: int = int(floor((_cam_pos.x - _max_radius) / _top_cell_size))
	var end_x: int = int(ceil((_cam_pos.x + _max_radius) / _top_cell_size))

	var start_y: int = int(floor((_cam_pos.y - _max_radius) / _top_cell_size))
	var end_y: int = int(ceil((_cam_pos.y + _max_radius) / _top_cell_size))

	# Vertical clip to content range instead of camera max view dist
	start_y = max(_topcell_y_min, start_y)
	end_y = min(_topcell_y_max, end_y)

	var start_z: int = int(floor((_cam_pos.z - _max_radius) / _top_cell_size))
	var end_z: int = int(ceil((_cam_pos.z + _max_radius) / _top_cell_size))
	
	# Note: the multiplies determined hueristic (after observation of edge-missing
	# cells sometimes when using the absolute theoretical limit)
	var radius_sq: float = (_top_cell_size * _top_cell_size) * 2.0 * 1.5
	var center_offset: Vector3 = Vector3(_top_cell_size, _top_cell_size, _top_cell_size) * 0.5

	# Used for inlined cantor ID packing (huge saving in call overhead)
	var id_x: int
	var id_y: int

	var top_cell_origin: Vector3 # 'top' here relates to level 0 top level (largest octree box)

	var top_cell_x: float
	var top_cell_y: float

	for x: int in range(start_x, end_x + 1):
		top_cell_x = x * _top_cell_size
		id_x = x + ID_OFFSET_3D
		for y: int in range(start_y, end_y + 1):
			top_cell_y = y * _top_cell_size
			id_y = y + ID_OFFSET_3D
			for z: int in range(start_z, end_z + 1):
				top_cell_origin = Vector3(top_cell_x, top_cell_y, z * _top_cell_size)

				# Discard If distance > radius of a cell; and center is behind camera plane
				# This saves 50% (one hemisphere) in processing time!
				if (top_cell_origin + center_offset).distance_squared_to(_cam_pos) > radius_sq and \
					_near_plane_normal.dot(top_cell_origin - _near_plane_point) < 0:
					continue

				# Inlined ID composition; Level is fixed 0 here, and assume values are in range
				#var top_cell_id: int = GoditeBeamCellIdentity.pack(0, top_cell_origin, _top_cell_size)
				var top_cell_id: int = (id_x << 36) | (id_y << 18) | (z + ID_OFFSET_3D) 
				
				# Can now fetch content for the cell (if any)
				var composite_cell: GoditeCompositeCell = _composite.content_map.get(top_cell_id)
				if not composite_cell:
					continue # No content
				
				# Process from this top-level cell (that will recurse and drill down if needed)
				_process_level(composite_cell)
	
	return _intersect_results


func _process_level(cell: GoditeCompositeCell) -> void:
	_intersect_traversals += 1
	
	# Note: has content check for top level is done in the toplevel loop above
	#       has content check for descendants is *implicit*: see below, only leaves are traversed
	
	## 1. VISIBILITY CHECK (projected Space)
	
	# Non-realloc corner fetch setup; since this is 'always' inner loop, it matters
	# But as we progress over levels, each level does need its own buffer. 
	var corners: Array[Vector3] = _intersect_corners.get_buffer(cell.beam_cell.level)
	var cell_aabb: AABB = cell.aabb
	
	# NOTE: Without this grow, culling is so perfectly tight that due to 
	# (lack-of) float precision will sometimes remove edge-sectors from
	# prox, causing items to dissapear/appear at screen edges, the pop-out when doing
	# a fly-over-canopy is sometime very visible. This grow fixes that 
	# (but it also dilutes the edge factor furhter below, but for now
	# its good enough, and not worth it to make 2 corner sets which is expensive)
	# This also allows tuning, if needed, for 'longer shadows' not also 
	# dissapearing when its caster moves out of screen.
	cell_aabb = cell_aabb.grow(5)
	
	# Get cell projected cell corners into a buffer, we need them more than once
	_get_corners(cell_aabb.position, cell_aabb.size, corners)
	
	if not _is_inside_frustum(corners):
		return

	## 2. HLOD SUBDIV DECISION
	var level: int = cell.beam_cell.level
	
	var subdivide: bool = level < _levels - 1 # Can it subdivide? (not if at smallest cell level)
	
	if subdivide: # can subdivide, see if 'want' to, per the configuration
		var center: Vector3 = cell.beam_cell.origin + cell.beam_cell.size * Vector3(0.5, 0.5, 0.5)
		
		var distance: float
		match _select_mode:
			HLOD_SELECTION.SPHERICAL: distance = center.distance_to(_cam_pos)
			HLOD_SELECTION.PLANAR: distance = abs(_near_plane_normal.dot(center - _near_plane_point))
			_: assert(false)
		
		# Use configuration to see subdiv is wanted at this range
		var subdiv_distance: float = _level_begin_ranges[level]
		assert(subdiv_distance > 0)
		subdivide = distance < subdiv_distance

	## 3. HLOD SUBDIVISION
	if subdivide:
		# only descending down cells/branches with content
		for child: GoditeCompositeCell in cell.leaves.values():
			assert(child.beam_cell.level == level + 1)
			_process_level(child)
		return

	## 4. STORE SELECTED
	var planar_closest: Vector3 = _get_planar_closest(corners)
	_intersect_results.push(cell, planar_closest, get_distance_to_edge_factor(planar_closest))


## Returns 0.0 at center, 1.0 at screen edge, >1.0 if off-screen.
## (this is used by renderer to counter godot's spherical LOD selection mode a bit
##  by using the value to calculate a LOD bias for the multimesh later on;
##  this optionally improves the screen edge MMIs quality)
func get_distance_to_edge_factor(world_pos: Vector3) -> float:
	# 1. Transform world point to Clip Space
	var clip_pos: Vector4 = _view_projection * Vector4(world_pos.x, world_pos.y, world_pos.z, 1.0)
	
	# 2. Behind camera check (W <= 0 means it's behind the near plane)
	if clip_pos.w <= 0.0:
		return 2.0 # Indicates it's behind/off-screen
		
	# 3. Perspective Divide to get NDC (-1 to 1 range)
	# ndc.x = -1 (Left), 1 (Right)
	# ndc.y = -1 (Bottom), 1 (Top)
	var ndc_x: float = clip_pos.x / clip_pos.w
	var ndc_y: float = clip_pos.y / clip_pos.w
	
	# 4. Calculate distance factor
	# Using max(abs) tells how close it is to the NEAREST edge (square bounds)
	# Using .length() would give a circular distance from center
	var dist_from_center: float = max(abs(ndc_x), abs(ndc_y))
	
	return dist_from_center


## Return the corner position of the corner cosest to near-Z frustum plane
func _get_planar_closest(corners: Array[Vector3]) -> Vector3:
	var min_d: float = 1000000000.0
	var closest: Vector3 = Vector3.INF
	var planar_d: float
	for corner: Vector3 in corners:
		planar_d = _near_plane_normal.dot(corner - _near_plane_point)
		if planar_d < min_d:
			min_d = planar_d
			closest = corner
	return closest


## Returns TRUE if any part of the box is inside the camera frustum
## after projection.
func _is_inside_frustum(corners: Array[Vector3]) -> bool:
	var all_off_left: bool = true
	var all_off_right: bool = true
	var all_off_bottom: bool = true
	var all_off_top: bool = true
	var all_off_near: bool = true
	var all_off_far: bool = true

	var clip_pos: Vector4
	var w: float
	for c: Vector3 in corners:
		# Project world point to Clip Space (W-coordinate included)
		clip_pos = _view_projection * Vector4(c.x, c.y, c.z, 1.0)
		
		# A point is inside if -w <= x/y/z <= w
		w = clip_pos.w
		
		# Visible if 1 point is inside
		if (clip_pos.x >= -w and clip_pos.x <= w and 
			clip_pos.y >= -w and clip_pos.y <= w and 
			clip_pos.z >= 0   and clip_pos.z <= w):
			return true
			
		if clip_pos.x >= -w: all_off_left = false
		if clip_pos.x <= w:  all_off_right = false
		if clip_pos.y >= -w: all_off_bottom = false
		if clip_pos.y <= w:  all_off_top = false
		if clip_pos.z >= 0:  all_off_near = false # Near plane is 0 in Godot Projection
		if clip_pos.z <= w:  all_off_far = false

	# If all corners are on the same "outside" side of any frustum plane, it's invisible
	if all_off_far or all_off_left or all_off_right or all_off_bottom or all_off_top or all_off_near:
		return false
		
	return true


## Get corners for a given (cell) box
func _get_corners(origin: Vector3, size: Vector3, corners: Array[Vector3]) -> void:
	var x_min: float = origin.x
	var x_max: float = origin.x + size.x
	
	var y_min: float = origin.y
	var y_max: float = origin.y + size.y
	
	var z_min: float = origin.z
	var z_max: float = origin.z + size.z

	corners[0] = Vector3(x_min, y_min, z_min)
	corners[1] = Vector3(x_max, y_min, z_min)
	corners[2] = Vector3(x_min, y_max, z_min)
	corners[3] = Vector3(x_max, y_max, z_min)
	
	corners[4] = Vector3(x_min, y_min, z_max)
	corners[5] = Vector3(x_max, y_min, z_max)
	corners[6] = Vector3(x_min, y_max, z_max)
	corners[7] = Vector3(x_max, y_max, z_max)
	
