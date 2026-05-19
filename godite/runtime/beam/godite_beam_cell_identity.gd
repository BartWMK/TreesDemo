extends RefCounted
class_name GoditeBeamCellIdentity

# Constants for bit-packing
# With 18 bits, the range is 2^18 (262144). Half is 131072.
const OFFSET_3D: int = 131072 
const MASK_18: int = 0x3FFFF # 18 bits

static var is_editor: bool = Engine.is_editor_hint()

# Use cantor ID's (note these do *not* have spacial locality)
static func pack(level_: int, origin: Vector3, size: float) -> int:
	## Encodes Level, X, Y, and Z into a single 64-bit ID
	# Convert world position to integer grid coordinates
	var gx: int = int(round(origin.x / size)) + OFFSET_3D
	var gy: int = int(round(origin.y / size)) + OFFSET_3D
	var gz: int = int(round(origin.z / size)) + OFFSET_3D

	if is_editor:
		_assert_valid_coord(level_, origin)
		assert((gx & MASK_18) == gx)
		assert((gy & MASK_18) == gy)
		assert((gz & MASK_18) == gz)

	# Pack: [Level: 8][X: 18][Y: 18][Z: 18] = 62 bits used
	return (level_ << 54) | (gx << 36) | (gy << 18) | gz
	
	
## Decodes the ID back into Level, Origin, and Size
## Notice this is inlined in the caster as optimisation, so changes here
## should propogate to there... 
static func unpack(packed: int, top_level_size: float) -> GoditeBeamCell:
	# Extract components using shifts and masks
	var level_: int = (packed >> 54) & 0xFF
	var gx: int = ((packed >> 36) & MASK_18) - OFFSET_3D
	var gy: int = ((packed >> 18) & MASK_18) - OFFSET_3D
	var gz: int = (packed & MASK_18) - OFFSET_3D
	
	# Calculate size based on level
	# Standard octree: size = top_size / 2^level
	var current_size: float = top_level_size / float(1 << level_)
	
	# Create Vector3 origin
	var origin: Vector3 = Vector3(gx, gy, gz) * current_size
	
	# Assuming GoditeBeamCell constructor accepts Vector3
	var cell: GoditeBeamCell = GoditeBeamCell.create(level_, origin, current_size)
	
	_assert_valid_coord(level_, origin) # Update this assertion for 3D if needed

	# Need to update assertion to match new packing layout if cell.id generates it
	# assert(cell.id == packed) 
	return cell


static func level(packed: int) -> int:
	return 	(packed >> 54) & 0xFF


# NOTE: Debug validation code below assumes std config of 5 levels, top level 1000 units.

const cell_sizes: Array[float] = [
	1000,500,250,125,125*0.5
]

static func _assert_valid_coord(level_: int, v: Vector3) -> void:
	var valid: bool = true
	valid = valid and (level_ >= 0 and level_ <= 6)

	var level_cell_size: float = cell_sizes[level_]
	valid = valid and (fmod(v.x, level_cell_size) == 0)
	valid = valid and (fmod(v.y, level_cell_size) == 0)
	valid = valid and (fmod(v.z, level_cell_size) == 0)

	if not valid:
		push_error("ID generator, invalid input: level %s, vector %s" % [level, v])
