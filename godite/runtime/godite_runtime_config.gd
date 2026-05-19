@tool
extends Resource
class_name GoditeRuntimeConfig

signal reload
signal reconstruct
signal hlod_changed

var emit_changes: bool = true

@export_group("Preproduction")

## Enable rendering when running game
@export var runtime: bool = true:
	set(value):
		if runtime == value:
			return
		runtime = value
		if emit_changes:
			reconstruct.emit()

## Enable rendering in-editor
@export var editor: bool = false:
	set(value):
		if editor == value:
			return
		editor = value
		if emit_changes:
			reconstruct.emit()

@export_group("Render passes")

## Draw 'dist' sectors (sectors with baked mesh)
@export var draw_dist_sectors: bool = true:
	set(value):
		if draw_dist_sectors == value:
			return
		draw_dist_sectors = value
		if emit_changes:
			reconstruct.emit()

## Draw 'far' sectors (Multimesh sectors)
@export var draw_far_sectors: bool = true:
	set(value):
		if draw_far_sectors == value:
			return
		draw_far_sectors = value
		if emit_changes:
			reconstruct.emit()
		
## Draw 'proximity' sectors (MeshInstance sectors)
@export var draw_near_sectors: bool = true:
	set(value):
		if draw_near_sectors == value:
			return
		draw_near_sectors = value
		if emit_changes:
			reconstruct.emit()

## Draw HLOD/Octtree cells (only content cells are drawn)
@export var draw_debug_data: bool = false:
	set(value):
		if draw_debug_data == value:
			return
		draw_debug_data = value
		if emit_changes:
			reconstruct.emit()

@export_group("Quality vs Peformance")

## Quality of voxel rendering into the distance; lowering this
## will improve performance but will render more muddy / voxalized.
## This is just a LOD Bias on the viewport / project
@export_range(0, 2, 0.01) var screen_distance_quality: float = 1:
	set(value):
		if screen_distance_quality == value:
			return
		screen_distance_quality = value
		if emit_changes:
			emit_changed()
		
## Quality of voxel rendering near corners/edges of screen
## Higher setting is better quality at a performance cost
## Note this only affects far sectors (multimeshes)
## This is CPU intensive; but counteracts godot's 
## spherical LOD selection; which can cause very 'voxely' (low-LOD)
## selections near screen edges. Ideally, godot would support
## planar and/or projected methods, but a'las for now.
## (i've talked face2face with the respective maintainer of that code after
##  godotcon, and he is considering proposing/adding that feature).
##
@export_range(0, 1, 0.01) var screen_edge_quality: float = 0.15:
	set(value):
		if screen_edge_quality == value:
			return
		screen_edge_quality = value
		if emit_changes:
			emit_changed()




## Settings to configure the distances used to select octtree levels
@export_group("HLOD")

@export_range(0,3, 1) var bake_levels: int = 0:
	set(value):
		if bake_levels == value:
			return
			
		if use_cards and value > 0:
			push_error("Cant set cell baking >0 when using cards; not (yet?) supported")
			return
	
		bake_levels = value
		if emit_changes:
			reload.emit()
	
@export_range(0,4, 1) var condense_levels: int = 0:
	set(value):
		if condense_levels == value:
			return
		condense_levels = value
		if emit_changes:
			reload.emit()

## HLOD level selection mode:[br]
## Defines what kind of distance measurement is used to select occtree levels
## using the ranges below.
## [b]Spherical[/b]: Distance to camera position.[br]
## [b]Planar[/b]: Distance to camera near plane.[br]
@export_enum("Spherical:0", "Planar:1") var hlod_selection_mode: int = 1:
	set(value):
		if hlod_selection_mode == value:
			return
		hlod_selection_mode = value
		if emit_changes:
			hlod_changed.emit()


# Note: ranges here are named in reverse of that of implementation
#       this is more easy to comprehend, especially given the relative measurements
## Range up to which use HLOD4 (64 units size)
@export_range(25,1000, 25) var level_4_range_end: float = 225:
	set(value):
		if level_4_range_end == value:
			return
		level_4_range_end = value
		if emit_changes:
			hlod_changed.emit()

## Range up to which use HLOD3 (128 units size)[br]
## To prevent overlap/bad configurations, this is [b]measured from level_4_range[/b] 
@export_range(100,2000, 25) var level_3_range_end: float = 300:
	set(value):
		if level_3_range_end == value:
			return
		level_3_range_end = value
		if emit_changes:
			hlod_changed.emit()

## Range up to which use HLOD2 (256 units size)[br] 
## To prevent overlap/bad configurations, this is [b]measured from level_3_range[/b] 
@export_range(250,5000, 50) var level_2_range_end: float = 500:
	set(value):
		if level_2_range_end == value:
			return
		level_2_range_end = value
		if emit_changes:
			hlod_changed.emit()

## Range up to which use HLOD1 (512 units size)[br]
## To prevent overlap/bad configurations, this is [b]measured from level_2_range[/b][br]
## [b][i]Beyond this range, HLOD0 (1024 units size) is used[/i][/b]
@export_range(500,10000, 100) var level_1_range_end: float = 1000:
	set(value):
		if level_1_range_end == value:
			return
		level_1_range_end = value
		if emit_changes:
			hlod_changed.emit()

@export_group("Mode")

## Use billboards with octahedral projection of instead voxel LODs
@export var use_cards: bool:
	set(value):
		if use_cards == value:
			return
			
		use_cards = value
		if emit_changes:
			if use_cards and bake_levels > 0:
				push_warning("Baking cells isn't (yet?) supported for cards; setting bake levels to 0 and forcing reload")
				emit_changes = false
				bake_levels = 0
				emit_changes = true
				reload.emit()
			else:
				reconstruct.emit()
