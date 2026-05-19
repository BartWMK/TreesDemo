extends RefCounted

## Transforms array with on-demand/cached AABB
class_name GoditeComposeTransforms

var list: Array[Transform3D]:
	set(value):
		list = value
		_aabb = AABB()

var aabb: AABB:
	get():
		if _aabb == AABB():
			_aabb = GoditeAABB.from_transforms(list)
		return _aabb
		
var _aabb: AABB


func count() -> int:
	return list.size()


func _init(content: Array[Transform3D] = []) -> void:
	list = content
