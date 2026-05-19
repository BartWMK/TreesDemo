extends RefCounted

## This is a cell that intersects the frustum and has content
## Created by caster during intersection phase 
class_name GoditeBeamIntersection

## The composite cell, this also has the beam_cell
var composite_cell: GoditeCompositeCell

## Point nearest to camera near frustum
var planar_nearest: Vector3

## Screen position
var edge_factor: float
