extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")


static func draw(
	canvas: CanvasItem,
	snapshot: Dictionary,
	time: float,
	additive_material: Material,
	aura_material: ShaderMaterial,
	burst_material: ShaderMaterial
) -> void:
	if canvas == null or snapshot.is_empty():
		return
	_draw_texture(
		canvas,
		ImpactFlareTextureCache.get_glow_texture(),
		snapshot.get("backplate_rect", Rect2()),
		snapshot.get("backplate_color", Color.TRANSPARENT),
		additive_material
	)
	_draw_shaded_texture(
		canvas,
		ImpactShockwaveTextureCache.get_full_ring_texture(),
		snapshot.get("ring_rect", Rect2()),
		snapshot.get("ring_color", Color.TRANSPARENT),
		aura_material,
		time,
		float(snapshot.get("ring_intensity", 0.0))
	)
	_draw_shaded_texture(
		canvas,
		ImpactShockwaveTextureCache.get_full_ring_texture(),
		snapshot.get("accent_rect", Rect2()),
		snapshot.get("accent_color", Color.TRANSPARENT),
		aura_material,
		time,
		float(snapshot.get("accent_intensity", 0.0))
	)
	if not bool(snapshot.get("burst_visible", false)):
		return
	_draw_texture(
		canvas,
		ImpactFlareTextureCache.get_burst_texture(),
		snapshot.get("burst_rect", Rect2()),
		snapshot.get("burst_color", Color.TRANSPARENT),
		additive_material
	)
	_draw_shaded_texture(
		canvas,
		ImpactShockwaveTextureCache.get_full_ring_texture(),
		snapshot.get("burst_ring_rect", Rect2()),
		snapshot.get("burst_ring_color", Color.TRANSPARENT),
		burst_material,
		time,
		float(snapshot.get("burst_ring_intensity", 0.0))
	)


static func _draw_shaded_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	rect: Rect2,
	color: Color,
	shader_material: ShaderMaterial,
	time: float,
	intensity: float
) -> void:
	if shader_material != null:
		shader_material.set_shader_parameter("elapsed", time)
		shader_material.set_shader_parameter("intensity", intensity)
	_draw_texture(canvas, texture, rect, color, shader_material)


static func _draw_texture(canvas: CanvasItem, texture: Texture2D, rect: Rect2, color: Color, draw_material: Material) -> void:
	if texture == null or not rect.has_area() or color.a <= 0.0:
		return
	var previous_material: Material = canvas.material
	canvas.material = draw_material
	canvas.draw_texture_rect(texture, rect, false, color)
	canvas.material = previous_material
