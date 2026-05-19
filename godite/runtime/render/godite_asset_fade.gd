extends RefCounted

## Set shader parameters for cross fades
class_name GoditeAssetFade

static func apply(asset: GoditeAsset, card_mode: bool) -> void:
	if not asset:
		return
		
	var fade_from: float = asset.instance_faux_from
	var fade_to: float = asset.instance_faux_from + asset.instance_faux_fade
	
	_apply_to_mesh(asset.title, fade_from, fade_to, asset.card_mesh if card_mode else asset.voxel_mesh)
	_apply_to_mesh(asset.title, fade_from, fade_to, asset.source_mesh)


static func _apply_to_mesh(title: String, fade_from: float, fade_to: float, mesh: Mesh) -> void:
	if not mesh:
		return
		
	for surface_index: int in mesh.get_surface_count():
		_apply_to_material(title, fade_from, fade_to, mesh.surface_get_material(surface_index))

static func _apply_to_material(_title: String, fade_from: float, fade_to: float, material: Material) -> void:
	if not material is ShaderMaterial:
		return
	var shader_material: ShaderMaterial = material as ShaderMaterial
	shader_material.set_shader_parameter("fade_from_distance", fade_from)
	shader_material.set_shader_parameter("fade_to_distance", fade_to)
