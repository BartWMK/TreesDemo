extends RefCounted


## The state of items to draw
class_name GoditeBeamState

# Using maps to ensure uniqueness and making diffs faster
# the float is the draw distance

# Sectors, from near to far
var prox_sectors: Dictionary[GoditeComposeProxSector, float]
var beam_sectors: Dictionary[GoditeComposeBeamSector, float]
var dist_sectors: Dictionary[GoditeCompositeCell, bool]

## Cells, used by (debug) data renderer 
var cells: Dictionary[GoditeCompositeCell, bool]

## Total items (trees) drawn
var item_count: int
