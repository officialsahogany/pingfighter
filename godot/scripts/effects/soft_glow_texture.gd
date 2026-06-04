extends RefCounted

# Shared soft radial-falloff glow sprite (white RGB, cos^2 feathered alpha).
# Built once per size and cached statically, so ambient / state glows can blit
# it at low alpha instead of a hard draw_circle disc and read as soft light.
# The cos^2 curve matches the project halo convention in
# common_starpoint_visual_host.gd (gentle at the rim, cheap to bake). Consumers:
# lingpet_companion_renderer (ambient pet aura) and player_state_glow_renderer
# (danger / transform state aura).

static var _cache: Dictionary = {}


static func get_texture(size: int = 64) -> Texture2D:
	var key: int = maxi(8, size)
	if _cache.has(key):
		var cached: Texture2D = _cache[key] as Texture2D
		if cached != null:
			return cached
	var img := Image.create(key, key, false, Image.FORMAT_RGBA8)
	var half: float = float(key) * 0.5
	for y in range(key):
		for x in range(key):
			var dx: float = (float(x) + 0.5) - half
			var dy: float = (float(y) + 0.5) - half
			var d: float = sqrt(dx * dx + dy * dy) / half
			var a: float = 0.0
			if d < 1.0:
				var c: float = cos(d * PI * 0.5)
				a = c * c
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	var tex: Texture2D = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
