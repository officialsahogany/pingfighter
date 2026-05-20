extends RefCounted


func build_assets(
	rock_texture: Texture2D,
	rock_source_regions: Array,
	rock_debris_texture: Texture2D,
	rock_debris_source_regions: Array,
	rock_fragment_life_sec: float
) -> Dictionary:
	return {
		"rock_texture": rock_texture,
		"rock_source_regions": rock_source_regions,
		"rock_debris_texture": rock_debris_texture,
		"rock_debris_source_regions": rock_debris_source_regions,
		"rock_fragment_life_sec": rock_fragment_life_sec,
	}
