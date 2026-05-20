extends RefCounted


func build_status(
	base_texture: Texture2D,
	tree_texture: Texture2D,
	tree_source_regions: Dictionary,
	game_frame_texture: Texture2D,
	leaf_texture: Texture2D,
	leaf_source_regions: Array,
	rock_texture: Texture2D,
	rock_source_regions: Array,
	rock_debris_texture: Texture2D,
	rock_debris_source_regions: Array
) -> Dictionary:
	return {
		"base": base_texture != null,
		"tree": tree_texture != null and tree_source_regions.has("left") and tree_source_regions.has("right"),
		"game_frame": game_frame_texture != null,
		"leaf": leaf_texture != null and not leaf_source_regions.is_empty(),
		"rock": rock_texture != null and not rock_source_regions.is_empty(),
		"rock_debris": rock_debris_texture != null and not rock_debris_source_regions.is_empty(),
	}
