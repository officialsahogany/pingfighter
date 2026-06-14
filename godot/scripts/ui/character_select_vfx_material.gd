extends RefCounted

static func prewarm() -> void:
	pass


static func clear_caches() -> void:
	# Compatibility hook kept for callers that release shared VFX resources.
	pass


static func build_additive_canvas_material() -> CanvasItemMaterial:
	var canvas_material := CanvasItemMaterial.new()
	canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return canvas_material


static func get_palette(character_id: String) -> Dictionary:
	match character_id:
		"soldier":
			return {
				"primary": Color(0.48, 0.58, 0.32, 1.0),
				"accent": Color(1.0, 0.78, 0.24, 1.0),
				"deep": Color(0.035, 0.050, 0.035, 1.0),
			}
		"viper":
			return {
				"primary": Color(0.63, 0.25, 1.0, 1.0),
				"accent": Color(1.0, 0.20, 0.40, 1.0),
				"deep": Color(0.035, 0.018, 0.060, 1.0),
			}
		"blacksmith":
			return {
				"primary": Color(1.0, 0.42, 0.10, 1.0),
				"accent": Color(1.0, 0.82, 0.40, 1.0),
				"deep": Color(0.070, 0.032, 0.015, 1.0),
			}
		"optimus":
			return {
				"primary": Color(0.54, 0.28, 1.0, 1.0),
				"accent": Color(1.0, 0.82, 0.28, 1.0),
				"deep": Color(0.032, 0.022, 0.070, 1.0),
			}
		_:
			return {
				"primary": Color(0.13, 0.92, 1.0, 1.0),
				"accent": Color(0.82, 0.98, 1.0, 1.0),
				"deep": Color(0.018, 0.040, 0.060, 1.0),
			}
