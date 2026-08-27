extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BattleCoreTexturePaths := preload("res://scripts/resources/battle_core_texture_paths.gd")
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const DefeatContinueVisualProjection := preload("res://scripts/core/defeat_continue_visual_projection.gd")

const DEFEAT_CONTINUE_BACKDROP_TEXTURE_PATH := BattleCoreTexturePaths.DEFEAT_CONTINUE_BACKDROP_TEXTURE_PATH


static func prewarm_liveliness_effects() -> void:
	ImpactFlareTextureCache.prewarm()


static func draw_scene_backdrop(canvas: CanvasItem, view_size: Vector2) -> void:
	if canvas == null:
		return
	var texture := get_cached_backdrop_texture()
	if texture != null:
		var backdrop_rect := _cover_texture_rect(texture, Rect2(Vector2.ZERO, view_size))
		canvas.draw_texture_rect(texture, backdrop_rect, false, Color.WHITE)
	else:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.012, 0.014, 0.013, 1.0))
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.006, 0.010, 0.009, 0.16))
	_draw_backdrop_vignette_bands(canvas, view_size)


static func draw_entry_reveal_glow(
	canvas: CanvasItem,
	view_size: Vector2,
	reveal: float,
	reveal_elapsed: float,
	reveal_duration_sec: float,
	accent: Color
) -> void:
	if canvas == null:
		return
	var inverse := 1.0 - clampf(reveal, 0.0, 1.0)
	if inverse <= 0.01:
		return
	var center := Vector2(view_size.x * 0.5, _scaled_y(view_size, 344.0))
	var bloom_alpha := 0.14 * inverse
	ImpactFlareTextureCache.draw_glow(
		canvas,
		center,
		minf(view_size.x, view_size.y) * (0.23 + 0.08 * inverse),
		accent,
		bloom_alpha
	)
	var wake := clampf(reveal_elapsed / maxf(reveal_duration_sec, 0.001), 0.0, 1.0)
	var wake_alpha := sin(clampf(wake, 0.0, 0.5) * PI * 2.0) * 0.16
	if wake_alpha > 0.0:
		ImpactFlareTextureCache.draw_burst(
			canvas,
			center,
			minf(view_size.x, view_size.y) * (0.19 + wake * 0.08),
			Color(0.66, 0.82, 0.70, 1.0),
			wake_alpha
		)


static func draw_reveal_veil(canvas: CanvasItem, view_size: Vector2, reveal: float) -> void:
	if canvas == null:
		return
	var inverse := 1.0 - clampf(reveal, 0.0, 1.0)
	if inverse <= 0.01:
		return
	var veil_alpha := pow(inverse, 1.7) * 0.74
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.0, 0.0, 0.0, veil_alpha))


static func draw_whiteout(
	canvas: CanvasItem,
	view_size: Vector2,
	alpha: float,
	confirm_elapsed: float,
	whiteout_start_sec: float,
	reset_time_sec: float
) -> void:
	if canvas == null or alpha <= 0.001:
		return
	if alpha < 0.995:
		var ripple_center := Vector2(view_size.x * 0.5, _scaled_y(view_size, 528.0))
		var ripple_progress := clampf(
			(confirm_elapsed - whiteout_start_sec) / maxf(reset_time_sec - whiteout_start_sec, 0.001),
			0.0,
			1.0
		)
		var fringe := sin(ripple_progress * PI)
		if fringe > 0.001:
			ImpactFlareTextureCache.draw_glow(
				canvas,
				ripple_center,
				minf(view_size.x, view_size.y) * (0.18 + 0.18 * ripple_progress),
				Color(0.42, 0.76, 0.62, 1.0),
				0.18 * fringe
			)
			var ring_radius := minf(view_size.x, view_size.y) * (
				0.12 + 0.20 * DefeatContinueVisualProjection.ease_out_cubic(ripple_progress)
			)
			var ring_rect := Rect2(
				ripple_center - Vector2(ring_radius, ring_radius * 0.50),
				Vector2(ring_radius * 2.0, ring_radius)
			)
			_draw_ellipse_arc(
				canvas,
				ring_rect,
				-PI * 0.02,
				PI * 0.92,
				Color(0.52, 0.76, 0.58, 0.24 * fringe),
				2.0
			)
			_draw_ellipse_arc(
				canvas,
				ring_rect,
				PI * 1.04,
				PI * 1.82,
				Color(0.86, 0.76, 0.50, 0.18 * fringe),
				1.3
			)
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.88, 0.95, 0.91, clampf(alpha, 0.0, 1.0)))


static func draw_boss_portal_figure(
	canvas: CanvasItem,
	owner: Object,
	registry: Object,
	view_size: Vector2,
	pulse: float,
	elapsed_sec: float
) -> void:
	if canvas == null:
		return
	var texture := _get_cached_boss_victory_texture(registry)
	if texture == null:
		return
	var stage_id: int = maxi(1, _read_int(owner, "current_stage", 1))
	var frame_index := int(floor(elapsed_sec / 0.12))
	var source_rect := get_boss_victory_source_rect(texture, stage_id, frame_index)
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return
	var hover := sin(elapsed_sec * TAU * 0.16) * 5.0
	var center := Vector2(view_size.x * 0.5, _scaled_y(view_size, 342.0) + hover)
	var max_size := Vector2(minf(view_size.x * 0.30, 360.0), minf(view_size.y * 0.38, 274.0))
	var draw_rect := _fit_size_rect(source_rect.size, center, max_size)
	var aura_radius := maxf(draw_rect.size.x, draw_rect.size.y) * (0.48 + pulse * 0.03)
	canvas.draw_circle(center + Vector2(0.0, draw_rect.size.y * 0.10), aura_radius, Color(0.08, 0.24, 0.19, 0.18))
	canvas.draw_texture_rect_region(texture, draw_rect, source_rect, Color(0.0, 0.0, 0.0, 0.70), false, true)
	canvas.draw_texture_rect_region(texture, draw_rect, source_rect, Color(0.16, 0.38, 0.30, 0.16), false, true)


static func get_cached_backdrop_texture() -> Texture2D:
	return ProjectResourceLoader.get_cached_texture(DEFEAT_CONTINUE_BACKDROP_TEXTURE_PATH)


static func get_boss_victory_source_rect(texture: Texture2D, stage_id: int, frame_index: int) -> Rect2:
	if texture == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	return DefeatContinueVisualProjection.get_boss_victory_source_rect(
		texture.get_size(),
		stage_id,
		frame_index
	)


static func _draw_backdrop_vignette_bands(canvas: CanvasItem, view_size: Vector2) -> void:
	var top_height := view_size.y * 0.36
	var bottom_height := view_size.y * 0.34
	var side_width := view_size.x * 0.23
	_draw_vignette_quad(
		canvas,
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(view_size.x, 0.0),
			Vector2(view_size.x, top_height),
			Vector2(0.0, top_height),
		]),
		PackedColorArray([
			Color(0.0, 0.0, 0.0, 0.36),
			Color(0.0, 0.0, 0.0, 0.36),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.0),
		])
	)
	_draw_vignette_quad(
		canvas,
		PackedVector2Array([
			Vector2(0.0, view_size.y - bottom_height),
			Vector2(view_size.x, view_size.y - bottom_height),
			Vector2(view_size.x, view_size.y),
			Vector2(0.0, view_size.y),
		]),
		PackedColorArray([
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.38),
			Color(0.0, 0.0, 0.0, 0.38),
		])
	)
	_draw_vignette_quad(
		canvas,
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(side_width, 0.0),
			Vector2(side_width, view_size.y),
			Vector2(0.0, view_size.y),
		]),
		PackedColorArray([
			Color(0.0, 0.0, 0.0, 0.26),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.26),
		])
	)
	_draw_vignette_quad(
		canvas,
		PackedVector2Array([
			Vector2(view_size.x - side_width, 0.0),
			Vector2(view_size.x, 0.0),
			Vector2(view_size.x, view_size.y),
			Vector2(view_size.x - side_width, view_size.y),
		]),
		PackedColorArray([
			Color(0.0, 0.0, 0.0, 0.0),
			Color(0.0, 0.0, 0.0, 0.26),
			Color(0.0, 0.0, 0.0, 0.26),
			Color(0.0, 0.0, 0.0, 0.0),
		])
	)


static func _draw_vignette_quad(canvas: CanvasItem, points: PackedVector2Array, colors: PackedColorArray) -> void:
	canvas.draw_polygon(points, colors)


static func _draw_ellipse_arc(
	canvas: CanvasItem,
	rect: Rect2,
	start_angle: float,
	end_angle: float,
	color: Color,
	width: float
) -> void:
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radius_x := rect.size.x * 0.5
	var radius_y := rect.size.y * 0.5
	for i in range(28):
		var progress := float(i) / 27.0
		var angle := start_angle + (end_angle - start_angle) * progress
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	canvas.draw_polyline(points, color, width)


static func _get_cached_boss_victory_texture(registry: Object) -> Texture2D:
	var resources := _get_registry_instance(registry, "battle_resources")
	if resources == null or not resources.has_method("get_resource_cache"):
		return null
	var cache_value: Variant = resources.get_resource_cache()
	if not (cache_value is Dictionary):
		return null
	var cache: Dictionary = cache_value
	var texture_value: Variant = cache.get("boss_victory_sheet", null)
	if texture_value is Texture2D:
		return texture_value
	return null


static func _fit_size_rect(source_size: Vector2, center: Vector2, max_size: Vector2) -> Rect2:
	return DefeatContinueVisualProjection.fit_size_rect(source_size, center, max_size)


static func _cover_texture_rect(texture: Texture2D, target: Rect2) -> Rect2:
	return DefeatContinueVisualProjection.cover_size_rect(texture.get_size(), target)


static func _scaled_y(view_size: Vector2, base_y: float) -> float:
	return DefeatContinueVisualProjection.scaled_y(view_size, base_y)


static func _read_int(owner: Object, key: String, fallback: int) -> int:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return int(value)


static func _get_registry_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
