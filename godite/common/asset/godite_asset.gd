@tool
extends Resource
class_name GoditeAsset

## Fires when re-scan of the source (hi-res scan) is required
signal scan

## Fires when re-voxalisation (using hir-res scan as input) is required
signal voxelize

## For voxel output, the mesher to use; note that quad is phased out
## as it cannot support aspect / volume compensation and thus will look
## worse than box mode (pitty, because it has a higher 'cool' factor)
enum MeshMode {
	BOX = 0,  # Mesh for Cube shader
	QUAD = 1  # Mesh for Pix shader
}

## AABB of the 'real' source object
@export_storage var source_aabb: AABB

## What reference was used for LOD merging (edge-length) computation, 
@export_storage var fov_rad: float
@export_storage var reference_viewport_size: Vector2i

## Name of the root-node of the source
@export var title: String

@export_group("Voxelisation (authoring tool params)")

## Voxel mesh mode; now using BOX; quad has self shadow and aspect ratio issues/limitations
@export_enum("Box:0", "Quad:1") var voxel_mesh_mode: int

## Resolution for LOD0, in voxels; anything >40 will explode primitive count
## and as such, using voxels for very large/high trees/things is a no-go.
@export_range(10,60,1) var base_resolution: int = 40:
	set(value):
		if value == base_resolution:
			return
		base_resolution = value
		scan.emit()
		emit_changed()

## Scan slice margin (overlap between scan slices)
@export_range(-1,1,0.05) var slice_margin: float = 0.1:
	set(value):
		if value == slice_margin:
			return
		slice_margin = value
		scan.emit()
		emit_changed()

## LOD level to make red for inidication (diagnostic)
@export var indicator_level: int = -1:
	set(value):
		if value == indicator_level:
			return
		indicator_level = value
		scan.emit()
		emit_changed()
	

## PREPROD Density threshold; this is the minimum number of samples require 
## to keep a voxel filled.
@export_range(0,50,0.01) var density_threshold: float = 2:
	set(value):
		if value == density_threshold:
			return
		density_threshold = value
		voxelize.emit()
		emit_changed()

## Scale of voxels within their resolution cell; can be used to tune
## the 'boldness' of the resulting mesh. For example; a thick leaved
## solid tree can do with extra boldness, while skinny flowers can
## do with reduced boldness.
@export var voxel_inline_scale: float = 1.0:
	set(value):
		if value == voxel_inline_scale:
			return
		voxel_inline_scale = value
		voxelize.emit()
		emit_changed()

@export var voxel_material: Material:
	set(value):
		if value == voxel_material:
			return
		voxel_material = value
		voxelize.emit()
		emit_changed()


@export_group("Rendering")

## Distance from which instances switch to faux[br]
## Setting this to 0 disables per-instance faux use
@export var instance_faux_from: float = 0:
	set(value):
		if value == instance_faux_from:
			return
		instance_faux_from = value
		emit_changed()

## Cross-fade distance starting at instance_faux_from.[br]
## Setting this to 0 disables cross fade between real and faux versions.
@export var instance_faux_fade: float = 0:
	set(value):
		if value == instance_faux_fade:
			return
		instance_faux_fade = value
		emit_changed()


## Distance from which clusters switch to faux
## Only relates to highest sector level (smallest sectors)
@export var sector_faux_from: float:
	set(value):
		if value == sector_faux_from:
			return
		sector_faux_from = value
		emit_changed()


## End range of sector drawing; this can be used for per-asset draw distance
## Set this slightly beyond any material fade out range if that is used.
## A setting of 0 uses the camera far distance (draw always)
@export var sector_faux_end: float = 0:
	set(value):
		if value == sector_faux_end:
			return
		sector_faux_end = value
		emit_changed()


@export_group("Shadows")

## SHADOW_CASTING_SETTING for MeshInstances 
## (reload or invalidate cache to take effect)
@export_enum("OFF:0", "ON:1", "DOUBLE:2","ONLY:2") \
	var instance_shadow_casting: int = MeshInstance3D.SHADOW_CASTING_SETTING_ON:
	set(value):
		if value == instance_shadow_casting:
			return
		instance_shadow_casting = value
		emit_changed()

## SHADOW_CASTING_SETTING for MultiMeshInstances
## (reload or invalidate cache to take effect)
@export_enum("OFF:0", "ON:1", "DOUBLE:2","ONLY:2") \
	var cluster_shadow_casting: int = MeshInstance3D.SHADOW_CASTING_SETTING_ON:
	set(value):
		if value == cluster_shadow_casting:
			return
		cluster_shadow_casting = value
		emit_changed()


@export_group("Octahedral projected impostor billboards")

## Number of cells along each axis of the atlas
@export var card_grid_size: int = 9

## Size of the atlas texture to generate
@export var card_atlas_size: int = 1024

## Template material; note that each object gets its own duplicate
## with the object specific atlas textures
@export var card_material: Material

@export_group("Meshes")

## The source 'real' mesh; note this is a 'flattened' version
## which combines all original meshes from the source into a single mesh
## using multiple surfaces. This allows the original input to be 
## handled as a singe Mesh. (same numbe of draw calls, but fixed 1 node
## to maintain instead of multiple).
## Note that currently any regular embedded LODs of source are lost.
@export var source_mesh: Mesh

## Mesh to use for voxel mode; this has 'lods' meshes merged into it
@export var voxel_mesh: Mesh

## Not needed for delivery; but convinient to have; allows fast rebuild
## of 'voxel_mesh' with indicator settings changed for diagnostics.
@export var lods: Array[GoditeVoxelLODAsset]

## Quad mesh; sized according to the source
## TODO: this needs 'work'; technically it should be able to fit diagonal views
##       from any angle; same issue here as in the atlas creator.
##       Currently using longest axis; but this has issues with exact-square input.
@export var card_mesh: Mesh
