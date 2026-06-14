extends RefCounted


static func build_hit(index: int, splash: Dictionary, pos: Vector2, hit_rect: Rect2) -> Dictionary:
	return {
		"index": index,
		"splash": splash,
		"pos": pos,
		"hit_rect": hit_rect,
	}
