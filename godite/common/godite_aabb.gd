extends RefCounted

class_name GoditeAABB

static func from_transforms(transforms : Array[Transform3D]) -> AABB:
	if not transforms or transforms.is_empty():
		return AABB()
		
	var aabb: AABB = AABB(transforms[0].origin, Vector3.ZERO)
	for t: Transform3D in transforms:
		aabb = aabb.expand(t.origin)
	return aabb

## Get AABB from the meshes within a tree; note this examines the vertices
## and does not rely on godot's opinion (or timing) on AABBs. 
## This also allows can be used on nodes/scenes not 'ready' or not in tree.
static func from_node(root: Node) -> AABB:
	var aabb: AABB = AABB()        # Empty AABB
	var first: bool= true         # Needed because empty AABB can't be merged

	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	
	if root is MeshInstance3D:
		meshes.append(root)

	for mi: MeshInstance3D in meshes:
		var local_aabb: AABB = from_mesh(mi.mesh)
		
		var tx: Transform3D = mi.global_transform if mi.is_inside_tree() else mi.transform
	
		var world_aabb: AABB = local_aabb * tx

		if first:
			aabb = world_aabb
			first = false
		else:
			aabb = aabb.merge(world_aabb)

	return aabb	

## Get AABB based on the actual vertices
static func from_mesh(mesh: Mesh) -> AABB:
	if mesh == null:
		return AABB()

	var min_pos: Vector3 = Vector3(INF, INF, INF)
	var max_pos: Vector3 = Vector3(-INF, -INF, -INF)
	var has_vertices: bool = false

	for surface_idx: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface_idx)
		if arrays.is_empty():
			continue

		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if vertices.is_empty():
			continue

		has_vertices = true
		for i: int in vertices.size():
			var v: Vector3 = vertices[i]
			
			if v.x < min_pos.x: min_pos.x = v.x
			if v.y < min_pos.y: min_pos.y = v.y
			if v.z < min_pos.z: min_pos.z = v.z
			
			if v.x > max_pos.x: max_pos.x = v.x
			if v.y > max_pos.y: max_pos.y = v.y
			if v.z > max_pos.z: max_pos.z = v.z

	if not has_vertices:
		return AABB()

	return AABB(min_pos, max_pos - min_pos)


## Creates a Mesh representing the wireframe cage of an AABB.
static var _color_materials: Dictionary[Color, StandardMaterial3D] = {}

static func to_mesh(aabb: AABB, color: Color = Color.RED) -> ArrayMesh:
	var p: Vector3 = aabb.position
	var s: Vector3 = aabb.size
	
	var v0: Vector3 = p # Bottom-back-left
	var v1: Vector3 = p + Vector3(s.x, 0, 0) # Bottom-back-right
	var v2: Vector3 = p + Vector3(s.x, 0, s.z) # Bottom-front-right
	var v3: Vector3 = p + Vector3(0, 0, s.z) # Bottom-front-left
	var v4: Vector3 = v0 + Vector3(0, s.y, 0) # Top-back-left
	var v5: Vector3 = v1 + Vector3(0, s.y, 0) # Top-back-right
	var v6: Vector3 = v2 + Vector3(0, s.y, 0) # Top-front-right
	var v7: Vector3 = v3 + Vector3(0, s.y, 0) # Top-front-left

	var vertices: PackedVector3Array = PackedVector3Array([
		v0, v1, v1, v2, v2, v3, v3, v0, # Bottom face
		v4, v5, v5, v6, v6, v7, v7, v4, # Top face
		v0, v4, v1, v5, v2, v6, v3, v7  # Vertical pillars
	])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	var color_material: StandardMaterial3D = _color_materials.get(color)
	if not color_material:
		color_material = StandardMaterial3D.new()
		color_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		color_material.albedo_color = color	
		_color_materials.set(color, color_material)
	
	mesh.surface_set_material(0, color_material)
	
	return mesh


## Returns the volume in world units, of the intersection of A and B
static func get_intersection_volume(aabb_a: AABB, aabb_b: AABB) -> float:
	var overlap: AABB = aabb_a.intersection(aabb_b)
	var size: Vector3 = overlap.size
	return size.x * size.y * size.z


## Returns what percentage (0.0 to 1.0) of B's original volume is inside A.
static func get_intersection_volume_factor(aabb_a: AABB, aabb_b: AABB) -> float:
	var overlap: AABB = aabb_a.intersection(aabb_b)
	
	if overlap.size.x <= 0 or overlap.size.y <= 0 or overlap.size.z <= 0:
		return 0.0
	
	var volume_overlap: float = overlap.size.x * overlap.size.y * overlap.size.z
	var volume_b: float = aabb_b.size.x * aabb_b.size.y * aabb_b.size.z
	
	if volume_b <= 0:
		return 0.0
		
	var result: float = volume_overlap / volume_b

	if result < 0 or result > 1.01:
		assert(false) # allow breakpoint on assert
		pass

	# Prevent downstream blooming due to float precision deviations
	return clamp(result, 0.0, 1.0)


## Calculates the uniform scale (0..1) required to fit AABB B inside AABB A.
## If B already fits inside A, it returns 1.0.
func get_fit_scale(aabb_a: AABB, aabb_b: AABB) -> float:
	var scale_factor: float = 1.0
	
	var size_a: Vector3 = aabb_a.size
	var size_b: Vector3 = aabb_b.size
	
	if size_b.x > size_a.x: scale_factor = min(scale_factor, size_a.x / size_b.x)
	if size_b.y > size_a.y: scale_factor = min(scale_factor, size_a.y / size_b.y)
	if size_b.z > size_a.z: scale_factor = min(scale_factor, size_a.z / size_b.z)
		
	return scale_factor
	
