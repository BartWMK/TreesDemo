extends RefCounted

## A non-realloc buffer for corners, per HLOD level
## Do note that if using workers, this can not be shared between threads
## so each downward traversal can use one, but not global
## (for now, hopefully workers are not needed; and using this buffer is part of preventing them)
class_name GoditeBeamCornerBuffer


class _Corners extends RefCounted:
	var points: Array[Vector3] = []
	
	func _init() -> void:
		points.resize(8)


var _level_corners: Array[_Corners] = []

func _init(levels: int) -> void:
	_level_corners.resize(levels)
	for i: int in levels:
		_level_corners[i] = _Corners.new()

func get_buffer(level: int) -> Array[Vector3]:
	return _level_corners[level].points
