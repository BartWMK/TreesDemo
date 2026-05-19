@tool
extends Node3D
class_name GoditeInstance3D

enum Mode {
	VOXEL,
	CARD
}

@export var mode: Mode = Mode.VOXEL:
	set(value):
		if mode == value:
			return
		mode = value
		if not godite_asset or not is_inside_tree():
			return
		_stop_render()
		_render()

@export var godite_asset: GoditeAsset:
	set(value):
		if value == godite_asset:
			return
			
		if godite_asset:
			_stop_render()
			
		godite_asset = value
		if value and is_inside_tree():
			_render()

var _mi_real: MeshInstance3D = MeshInstance3D.new()
var _mi_faux: MeshInstance3D = MeshInstance3D.new()

@export var inspect: bool:
	set(value):
		inspect = value
		if not is_inside_tree():
			return
		_stop_render()
		_mi_faux.lod_bias = 1
		_render()

@export var force_voxel: bool:
	set(value):
		force_voxel = value
		if not is_inside_tree():
			return
		_stop_render()
		_render()
	

func _init() -> void:
	_stop_render()
	
	add_child(_mi_real)
	add_child(_mi_faux)


func _ready() -> void:
	# Just to support instances in normal scenes for diagnostic/review
	if Engine.is_editor_hint() and godite_asset:
		_stop_render()
		_render()
	
	# Note that in runtime renderer pools; asset isnt set yet, so this doesnt work
	# currently there is a hacky apply done in the cache warmup.
	GoditeAssetFade.apply(godite_asset, mode == Mode.CARD)

func _stop_render() -> void:
	_mi_real.visible = false
	_mi_faux.visible = false
	return

func _render() -> void:
	_mi_real.mesh = godite_asset.source_mesh
	_mi_faux.mesh = godite_asset.card_mesh if mode == Mode.CARD else godite_asset.voxel_mesh
	
	_prepare()

	var faux_from: float = godite_asset.instance_faux_from
	
	# Note: The actual fading is done by shaders (using dither; as alpha clashes with tree shaders)
	_mi_faux.visibility_range_begin = faux_from
	_mi_faux.visible = true
	
	# Note: Extending with fade distance to allow cross-fade
	if faux_from > 0: 
		_mi_real.visibility_range_end = faux_from + godite_asset.instance_faux_fade
		_mi_real.visible = true
	else:
		_mi_real.visible = false


	

func _prepare() -> void:
	var cast_shadow: MeshInstance3D.ShadowCastingSetting = \
		godite_asset.instance_shadow_casting as MeshInstance3D.ShadowCastingSetting
	
	_mi_real.visible = true
	_mi_real.cast_shadow = cast_shadow
	_mi_faux.cast_shadow = cast_shadow
