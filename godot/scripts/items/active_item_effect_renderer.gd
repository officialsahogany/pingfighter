extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const LONG_BOOST_ICON_PATH := ActiveItemCatalog.LONG_BOOST_ICON_PATH
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PICKUP_ICON_SIZE := 40.0
const LONG_BOOST_TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const LONG_BOOST_TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const LONG_BOOST_TIMER_ICON_SIZE := 28.0
const REGENERATION_POTION_PARTICLE_DURATION_SEC := 0.78
const REGENERATION_POTION_RING_DURATION_SEC := 0.58

var long_boost_icon_texture: Texture2D


func draw_field_effects(
	canvas: CanvasItem,
	pickup_particles: Array,
	regeneration_potion_rings: Array,
	regeneration_potion_particles: Array,
	long_boost_timer_context: Dictionary,
	shake_offset: Vector2 = Vector2.ZERO
) -> void:
	if canvas == null:
		return
	_draw_regeneration_potion_effect(canvas, regeneration_potion_rings, regeneration_potion_particles, shake_offset)
	_draw_long_boost_timer_gauge(canvas, long_boost_timer_context)
	for particle_value in pickup_particles:
		if particle_value is Dictionary:
			_draw_pickup_particle(canvas, particle_value, shake_offset)


func draw_pickup_effect(canvas: CanvasItem, registry: Object, pickup_effect: Dictionary) -> void:
	if canvas == null or pickup_effect.is_empty():
		return

	var center: Vector2 = _get_vector2(pickup_effect, "position", Vector2.ZERO)
	var alpha: float = clamp(float(pickup_effect.get("alpha", 1.0)), 0.0, 1.0)
	if alpha <= 0.0:
		return

	_draw_pickup_glow(canvas, center, alpha)

	var icon_texture: Texture2D = _get_item_icon_texture(_get_dictionary(pickup_effect, "item_data"), registry)
	if icon_texture != null:
		var icon_rect := Rect2(
			center - Vector2(PICKUP_ICON_SIZE, PICKUP_ICON_SIZE) * 0.5,
			Vector2(PICKUP_ICON_SIZE, PICKUP_ICON_SIZE)
		)
		canvas.draw_texture_rect(icon_texture, icon_rect, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		canvas.draw_circle(center, PICKUP_ICON_SIZE * 0.45, Color(1.0, 100.0 / 255.0, 1.0, 0.85 * alpha))

	var item_name: String = str(pickup_effect.get("display_name", ""))
	_draw_centered_text(canvas, item_name, center + Vector2(0.0, 54.0), 16, Color(1.0, 1.0, 1.0, alpha))
	_draw_centered_text(canvas, "획득!", center + Vector2(0.0, 70.0), 14, Color(1.0, 215.0 / 255.0, 0.0, alpha))


func _draw_regeneration_potion_effect(
	canvas: CanvasItem,
	regeneration_potion_rings: Array,
	regeneration_potion_particles: Array,
	shake_offset: Vector2
) -> void:
	for ring_value in regeneration_potion_rings:
		if not (ring_value is Dictionary):
			continue
		var ring: Dictionary = ring_value
		var center: Vector2 = _get_vector2(ring, "position", Vector2.ZERO) + shake_offset
		var age: float = float(ring.get("age", 0.0))
		var duration: float = max(0.001, float(ring.get("duration", REGENERATION_POTION_RING_DURATION_SEC)))
		var progress: float = clamp(age / duration, 0.0, 1.0)
		var life: float = 1.0 - progress
		var radius: float = lerp(24.0, 92.0, progress)
		canvas.draw_arc(center, radius, 0.0, TAU, 72, Color(1.0, 230.0 / 255.0, 80.0 / 255.0, 0.58 * life), 4.0)
		canvas.draw_arc(center, radius * 0.62, 0.0, TAU, 56, Color(1.0, 1.0, 170.0 / 255.0, 0.34 * life), 2.0)
		canvas.draw_circle(center, radius * 0.26, Color(1.0, 210.0 / 255.0, 30.0 / 255.0, 0.16 * life))

	for particle_value in regeneration_potion_particles:
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
		var age: float = float(particle.get("age", 0.0))
		var lifetime: float = max(0.001, float(particle.get("lifetime", REGENERATION_POTION_PARTICLE_DURATION_SEC)))
		var life: float = clamp(1.0 - age / lifetime, 0.0, 1.0)
		if life <= 0.0:
			continue
		var radius: float = max(1.0, float(particle.get("radius", 3.0))) * (0.55 + 0.45 * life)
		var color: Color = _get_color(particle.get("color", Color(1.0, 230.0 / 255.0, 80.0 / 255.0, 1.0)), Color(1.0, 230.0 / 255.0, 80.0 / 255.0, 1.0))
		canvas.draw_circle(center, radius * 2.1, Color(color.r, color.g, color.b, 0.13 * life))
		canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.92 * life))
		canvas.draw_circle(center + Vector2(-radius * 0.32, -radius * 0.32), radius * 0.32, Color(1.0, 1.0, 1.0, 0.42 * life))


func _draw_long_boost_timer_gauge(canvas: CanvasItem, timer_context: Dictionary) -> void:
	var active: bool = bool(timer_context.get("active", false))
	var timer_frames: float = float(timer_context.get("timer_frames", 0.0))
	var initial_timer_frames: float = float(timer_context.get("initial_timer_frames", 0.0))
	if not active or timer_frames <= 0.0:
		return

	var ratio: float = clamp(timer_frames / max(1.0, initial_timer_frames), 0.0, 1.0)
	var remaining_seconds: float = timer_frames / 60.0
	var bar_pos := Vector2(
		FIELD_WIDTH - LONG_BOOST_TIMER_BAR_SIZE.x - LONG_BOOST_TIMER_BAR_MARGIN.x,
		FIELD_HEIGHT - LONG_BOOST_TIMER_BAR_MARGIN.y
	)
	var frame_rect := Rect2(bar_pos, LONG_BOOST_TIMER_BAR_SIZE)
	var frame_bg := frame_rect.grow(4.0)
	canvas.draw_rect(frame_bg, Color(0.0, 0.0, 0.0, 0.54))
	canvas.draw_rect(frame_rect, Color(0.08, 0.07, 0.04, 0.92))

	var base_color: Color
	var highlight_color: Color
	if remaining_seconds > 6.0:
		base_color = Color(1.0, 215.0 / 255.0, 0.0, 0.96)
		highlight_color = Color(1.0, 235.0 / 255.0, 120.0 / 255.0, 0.96)
	elif remaining_seconds > 3.0:
		base_color = Color(1.0, 170.0 / 255.0, 0.0, 0.96)
		highlight_color = Color(1.0, 200.0 / 255.0, 60.0 / 255.0, 0.96)
	else:
		var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.018)
		base_color = Color(1.0, lerp(0.18, 0.45, pulse), 0.04, 0.98)
		highlight_color = Color(1.0, lerp(0.55, 0.82, pulse), 0.20, 0.98)

	var fill_rect := Rect2(frame_rect.position, Vector2(frame_rect.size.x * ratio, frame_rect.size.y))
	if fill_rect.size.x > 0.5:
		canvas.draw_rect(fill_rect, base_color)
		canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.35))), highlight_color)

	canvas.draw_rect(frame_rect, Color(1.0, 215.0 / 255.0, 0.0, 0.86), false, 2.0)
	canvas.draw_line(frame_rect.position + Vector2(0.0, frame_rect.size.y + 2.0), frame_rect.end + Vector2(0.0, 2.0), Color(0.35, 0.18, 0.02, 0.65), 2.0)

	var icon_center := frame_rect.position + Vector2(-16.0, frame_rect.size.y * 0.5)
	var icon_pulse: float = 1.0 + 0.08 * sin(float(Time.get_ticks_msec()) * 0.012)
	var icon_size := Vector2(LONG_BOOST_TIMER_ICON_SIZE, LONG_BOOST_TIMER_ICON_SIZE) * icon_pulse
	canvas.draw_circle(icon_center, icon_size.x * 0.58, Color(0.0, 0.0, 0.0, 0.42))
	var icon_texture: Texture2D = _get_long_boost_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_center - icon_size * 0.5, icon_size), false)
	else:
		canvas.draw_circle(icon_center, icon_size.x * 0.40, Color(100.0 / 255.0, 200.0 / 255.0, 1.0, 1.0))
		canvas.draw_circle(icon_center + Vector2(-4.0, -5.0), icon_size.x * 0.12, Color(1.0, 1.0, 1.0, 0.36))


func _draw_pickup_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var age: float = float(particle.get("age", 0.0))
	var lifetime: float = max(0.01, float(particle.get("lifetime", 0.45)))
	var alpha: float = (1.0 - age / lifetime) * 0.72
	var color: Color = _get_color(particle.get("color", Color.WHITE), Color.WHITE)
	color.a *= alpha
	canvas.draw_circle(
		_get_vector2(particle, "position", Vector2.ZERO) + shake_offset,
		float(particle.get("radius", 3.0)),
		color
	)


func _draw_pickup_glow(canvas: CanvasItem, center: Vector2, alpha: float) -> void:
	for i in range(6):
		var ratio: float = float(i) / 6.0
		var radius: float = 40.0 * (1.0 - ratio)
		canvas.draw_circle(center, radius, Color(1.0, 1.0, 1.0, 0.10 * (1.0 - ratio) * alpha))
	canvas.draw_circle(center, 30.0, Color(30.0 / 255.0, 40.0 / 255.0, 60.0 / 255.0, 150.0 / 255.0 * alpha))
	canvas.draw_arc(center, 30.0, 0.0, TAU, 32, Color(100.0 / 255.0, 150.0 / 255.0, 1.0, 150.0 / 255.0 * alpha), 2.0)


func _draw_centered_text(canvas: CanvasItem, text: String, baseline_center: Vector2, font_size: int, color: Color) -> void:
	if text == "":
		return
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var pos := Vector2(baseline_center.x - text_size.x * 0.5, baseline_center.y)
	canvas.draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.65))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_item_icon_texture(item_data: Dictionary, registry: Object) -> Texture2D:
	var visuals: Object = _get_instance(registry, "active_item_hud_visuals")
	if visuals != null and visuals.has_method("get_icon_texture"):
		var texture: Variant = visuals.get_icon_texture(item_data)
		if texture is Texture2D:
			return texture
	return null


func _get_long_boost_icon_texture() -> Texture2D:
	if long_boost_icon_texture == null:
		long_boost_icon_texture = ProjectResourceLoader.load_texture(
			LONG_BOOST_ICON_PATH,
			"Missing long boost icon at %s",
			"Failed to load long boost icon at %s"
		)
	return long_boost_icon_texture


func _get_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]) / 255.0, float(value[1]) / 255.0, float(value[2]) / 255.0, 1.0)
	return fallback


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
