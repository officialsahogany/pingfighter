extends RefCounted


func build_snapshot(falling_leaves: Array, fireflies: Array, leaf_source_regions: Array) -> Dictionary:
	return {
		"falling_leaf_count": falling_leaves.size(),
		"firefly_count": fireflies.size(),
		"leaf_sprite_count": leaf_source_regions.size(),
	}
