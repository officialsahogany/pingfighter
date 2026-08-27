extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const CHUKJIBU_GROUND_SEAL_PATH := "res://assets/sprites/effects/items/chukjibu_ground_seal_imagegen_v1.png"
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PARTICLE_ALPHA_CUTOFF := 0.02

const GOLD_CORE := Color(1.0, 0.82, 0.22, 1.0)
const CYAN_CORE := Color(0.38, 0.96, 1.0, 1.0)

var ground_seal_texture: Texture2D


func prewarm_assets() -> void:
	_touch_texture(get_ground_seal_texture())


func get_ground_seal_texture() -> Texture2D:
	if ground_seal_texture == null:
		ground_seal_texture = ProjectResourceLoader.load_texture(
			CHUKJIBU_GROUND_SEAL_PATH,
			"Chukjibu ground seal texture missing: %s",
			"Chukjibu ground seal texture failed to load: %s"
		)
	return ground_seal_texture


func draw(
	canvas: CanvasItem,
	dash_boost_context: Dictionary,
	particles: Array,
	shake_offset: Vector2
) -> void:
	if canvas == null or not bool(dash_boost_context.get("active", false)):
		return

	var glow_phase: float = float(dash_boost_context.get("glow_phase", 0.0))
	var pulse: float = 0.88 + 0.12 * sin(glow_phase * 1.35)
	var player_center: Vector2 = _get_vector2(
		dash_boost_context,
		"player_center",
		Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 25.0)
	) + shake_offset

	# Deliberate low-cost direct draw: the generated seal supplies item identity,
	# while lines and particles stay on the existing field renderer lifecycle.
	# This avoids a detached host that would need separate round cleanup.
	_draw_ground_seal(canvas, player_center + Vector2(0.0, 10.0), pulse)
	_draw_folded_road_lines(canvas, player_center, glow_phase, pulse)
	for particle_value in particles:
		if particle_value is Dictionary:
			_draw_afterimage_particle(canvas, particle_value, shake_offset)


func _draw_ground_seal(canvas: CanvasItem, center: Vector2, pulse: float) -> void:
	var texture := get_ground_seal_texture()
	var size := Vector2(92.0, 30.0) * (0.96 + 0.04 * pulse)
	var rect := Rect2(center - size * 0.5, size)
	if texture != null:
		canvas.draw_texture_rect(texture, rect.grow(4.0), false, Color(0.18, 0.82, 1.0, 0.18 * pulse))
		canvas.draw_texture_rect(texture, rect, false, Color(1.0, 0.96, 0.72, 0.78 * pulse))
	else:
		_draw_fallback_chevrons(canvas, center, pulse)


func _draw_folded_road_lines(canvas: CanvasItem, center: Vector2, glow_phase: float, pulse: float) -> void:
	for side in [-1.0, 1.0]:
		for index in range(3):
			var phase_offset: float = fposmod(glow_phase * 10.0 + float(index) * 15.0, 45.0)
			var x_offset: float = side * (34.0 + phase_offset)
			var y_offset: float = 4.0 + float(index - 1) * 7.0
			var inner := center + Vector2(x_offset, y_offset)
			var outer := inner + Vector2(side * (15.0 + 3.0 * pulse), -5.0)
			var alpha: float = (0.58 - phase_offset / 120.0) * pulse
			canvas.draw_line(inner, outer, Color(GOLD_CORE.r, GOLD_CORE.g, GOLD_CORE.b, alpha), 2.2)
			canvas.draw_line(outer, outer + Vector2(side * 8.0, 0.0), Color(CYAN_CORE.r, CYAN_CORE.g, CYAN_CORE.b, alpha * 0.72), 1.2)


func _draw_fallback_chevrons(canvas: CanvasItem, center: Vector2, pulse: float) -> void:
	for index in range(3):
		var x: float = float(index - 1) * 22.0
		var tip := center + Vector2(x + 10.0, 0.0)
		var color := Color(GOLD_CORE.r, GOLD_CORE.g, GOLD_CORE.b, (0.75 - float(index) * 0.08) * pulse)
		canvas.draw_line(tip + Vector2(-16.0, -7.0), tip, color, 2.2)
		canvas.draw_line(tip, tip + Vector2(-16.0, 7.0), color, 2.2)


func _draw_afterimage_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var alpha: float = clamp(float(particle.get("alpha", 0.0)), 0.0, 1.0)
	if alpha <= PARTICLE_ALPHA_CUTOFF:
		return
	var position: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
	var velocity: Vector2 = _get_vector2(particle, "velocity", Vector2.RIGHT)
	var direction: Vector2 = velocity.normalized() if velocity.length_squared() > 0.001 else Vector2.RIGHT.rotated(float(particle.get("rotation", 0.0)))
	var length: float = max(5.0, float(particle.get("length", 14.0)))
	var width: float = max(1.0, float(particle.get("radius", 2.0)))
	var color: Color = _get_color(particle.get("color", CYAN_CORE), CYAN_CORE)
	var tail: Vector2 = position - direction * length
	canvas.draw_line(tail, position, Color(color.r, color.g, color.b, alpha * 0.22), width * 2.8)
	canvas.draw_line(tail, position, Color(color.r, color.g, color.b, alpha * 0.92), width)
	canvas.draw_circle(position, width * 0.72, Color(1.0, 0.98, 0.76, alpha))


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	return value if value is Vector2 else fallback


func _get_color(value: Variant, fallback: Color) -> Color:
	return value if value is Color else fallback


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()
