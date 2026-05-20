extends RefCounted


func build_assets(
	base_texture: Texture2D,
	tree_texture: Texture2D,
	tree_source_regions: Dictionary,
	game_frame_texture: Texture2D,
	game_frame_source_hole: Rect2
) -> Dictionary:
	return {
		"base_texture": base_texture,
		"tree_texture": tree_texture,
		"tree_source_regions": tree_source_regions,
		"game_frame_texture": game_frame_texture,
		"game_frame_source_hole": game_frame_source_hole,
	}
