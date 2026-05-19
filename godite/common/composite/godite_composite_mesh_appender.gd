extends RefCounted

## SurfaceTool.append_from(...) from a workerthread => freeze / tragically slow!; 
## Due pounding the GPU with ""get's" ; which driver no-likey.
## This class implements append_from, but using pre-fetched meshes for appending.
## Now it can be parallel, mesh-fetch is prepared, nett result is 30x+ faster
## Used when baking cells
##
## NOTE THIS class is NOT GENERIC; it always takes surface 0, assumes no tangents etc.
## It is specifically for the voxel baker!
##
class_name GoditeCompositeMeshAppender

var _vertices: PackedVector3Array = []
var _normals: PackedVector3Array = []
var _indices: PackedInt32Array = []
#var _uvs: PackedVector2Array = []
var _colors: PackedColorArray = []
#var _tangents: PackedFloat32Array = [] # Tangents are usually Vector4 as float array

var _current_offset: int = 0

var _mesh_arrays: Dictionary[Mesh, Array]

## Instance a appender; used append_mesh_surface to append, 
## then commit(...) to obtain the merged mesh.
##
## mesh_arrays		Array of meshes than can be used to append
func _init(mesh_arrays: Dictionary[Mesh, Array]) -> void:
	_mesh_arrays = mesh_arrays

## Appends another mesh's surface to the internal arrays with a transform
func append_mesh_surface(mesh: Mesh, transform: Transform3D) -> void:
	var arrays: Array = _mesh_arrays.get(mesh)
	assert(arrays)
	if not arrays: 
		return

	var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var src_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	#var src_tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]

	# 1. Transform Positions and Normals
	# Normal transform needs to ignore translation and handle non-uniform scaling
	var basis_it: Basis = transform.basis.inverse().transposed()

	for i: int in range(src_verts.size()):
		_vertices.append(transform * src_verts[i])
		
		if src_norms.size() > i:
			_normals.append((basis_it * src_norms[i]).normalized())
		
		if src_colors.size() > i:
			_colors.append(src_colors[i])
			
		#if src_tangents.size() > i * 4:
			## Tangents are tricky: they are Vector4. Transform the Vector3 part.
			#var t_vec: Vector3 = Vector3(src_tangents[i*4], src_tangents[i*4+1], src_tangents[i*4+2])
			#var t_transformed: Vector3 = (transform.basis * t_vec).normalized()
			#_tangents.append(t_transformed.x)
			#_tangents.append(t_transformed.y)
			#_tangents.append(t_transformed.z)
			#_tangents.append(src_tangents[i*4+3]) # Preserve the W (bi-tangent sign)

	# 2. Offset and Append Indices
	for i: int in range(src_indices.size()):
		_indices.append(src_indices[i] + _current_offset)

	# 3. Update offset for next append
	_current_offset += src_verts.size()


## Commits arrays to a new ArrayMesh
func commit(material: Material) -> ArrayMesh:
	var final_arrays: Array = []
	final_arrays.resize(Mesh.ARRAY_MAX)
	
	final_arrays[Mesh.ARRAY_VERTEX] = _vertices
	if not _normals.is_empty(): final_arrays[Mesh.ARRAY_NORMAL] = _normals
	if not _indices.is_empty(): final_arrays[Mesh.ARRAY_INDEX] = _indices
	#if not _uvs.is_empty(): final_arrays[Mesh.ARRAY_TEX_UV] = _uvs
	if not _colors.is_empty(): final_arrays[Mesh.ARRAY_COLOR] = _colors
	#if not _tangents.is_empty(): final_arrays[Mesh.ARRAY_TANGENT] = _tangents
	
	var st: SurfaceTool = SurfaceTool.new()
	st.create_from_arrays(final_arrays)
	st.index()
	st.optimize_indices_for_cache()
	st.set_material(material)
	return st.commit()
