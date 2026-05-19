extends RefCounted

class_name GoditeCompositeTransformCondense

## Reduce transforms by clumping clusters of 'radius' together as a single transform; 
## This reduces overdraw and noise, at the cost of some possible pop-in
## Note this is a pretty crude and naive implementation just for proof-of-concept.
static func condense(transforms: Array[Transform3D], radius: float) -> Array[Transform3D]:

	var clusters: Dictionary[Vector3i, Transform3D] = {}
	
	# Use the highest alt transform per-cluster
	# DONT AVERAGE! that not only takes more time, they'd 'statistically center', resulting in a visible grid
	for t: Transform3D in transforms:
		var location: Vector3i = t.origin / radius
		if clusters.has(location):
			var cluster_t: Transform3D = clusters[location]
			
			# Keep the highest; this retains more items on ridges of mountains
			# which pops in/out are most visible at a distance when sillouhette by sun
			if cluster_t.origin.y > t.origin.y:
				continue

		clusters.set(location, t)
	
	return clusters.values()
