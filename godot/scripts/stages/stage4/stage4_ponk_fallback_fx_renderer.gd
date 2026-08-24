extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage4PonkMagneticAssets := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_assets.gd")
const Stage4PonkMagneticProjectileState := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_projectile_state.gd")
const Stage4PonkMeditationState := preload("res://scripts/stages/stage4/stage4_ponk_meditation_state.gd")

# Draw-only fallback for the creation frame or missing modular FX assets. The
# skill facade keeps effect ordering and host-handled decisions; this renderer
# owns the retained magnetic sheet cache and procedural draw recipes only.

var magnetic_sheet: Texture2D = null
var textures_loaded := false


func ensure_textures() -> void:
	if textures_loaded:
		return
	textures_loaded = true
	magnetic_sheet = ProjectResourceLoader.load_texture(
		Stage4PonkMagneticAssets.MAGNETIC_FIELD_SHEET_PATH
	)


func get_asset_status() -> Dictionary:
	ensure_textures()
	return {
		"magnetic_field_sheet": magnetic_sheet != null,
		"magnetic_field_frame_count": (
			Stage4PonkMagneticAssets.MAGNETIC_FIELD_FRAME_COUNT
			if magnetic_sheet != null
			else 0
		),
	}


func draw_magnetic_field(
	canvas: Object,
	context: Dictionary,
	shake_offset: Vector2,
	magnetic_state: Object,
	frame_clock: float
) -> void:
	var center: Vector2 = _as_vector2(
		context.get("stage4_magnetic_center", magnetic_state.magnetic_center),
		magnetic_state.magnetic_center
	) + shake_offset
	var radius: float = maxf(16.0, float(context.get(
		"stage4_magnetic_radius",
		magnetic_state.magnetic_radius
	)))
	var frame: int = int(context.get(
		"stage4_magnetic_frame",
		get_current_frame_index(frame_clock)
	)) % Stage4PonkMagneticAssets.MAGNETIC_FIELD_FRAME_COUNT
	canvas.draw_circle(center, radius * 0.98, Color(0.16, 0.76, 1.0, 0.12))
	canvas.draw_circle(center, radius * 0.42, Color(0.62, 1.0, 1.0, 0.18))
	_draw_magnetic_sheet_frame(
		canvas,
		center,
		radius * 2.72,
		frame,
		Color(0.82, 1.0, 1.0, 0.86)
	)
	var phase: float = frame_clock * 5.7
	for idx in range(4):
		var ring_radius: float = radius * (0.54 + float(idx) * 0.16)
		var alpha: float = 0.40 - float(idx) * 0.050
		canvas.draw_arc(
			center,
			ring_radius,
			phase + float(idx) * 0.7,
			phase + float(idx) * 0.7 + PI * 1.45,
			56,
			Color(0.64, 1.0, 1.0, alpha),
			3.0,
			true
		)
	canvas.draw_circle(center, radius * 0.18, Color(0.80, 1.0, 1.0, 0.34))


func draw_magnetic_projectile(
	canvas: Object,
	context: Dictionary,
	shake_offset: Vector2,
	projectile_state: Object,
	frame_clock: float
) -> void:
	var fade_active: bool = bool(context.get(
		"stage4_magnetic_projectile_fade_active",
		projectile_state.fade_timer_seconds > 0.0
	))
	var center: Vector2 = _as_vector2(
		context.get("stage4_magnetic_projectile_pos", projectile_state.pos),
		projectile_state.pos
	)
	var radius: float = maxf(12.0, float(context.get(
		"stage4_magnetic_projectile_radius",
		projectile_state.radius
	)))
	var alpha_scale := 1.0
	if fade_active and not bool(context.get(
		"stage4_magnetic_projectile_active",
		projectile_state.active
	)):
		center = _as_vector2(
			context.get("stage4_magnetic_projectile_fade_pos", projectile_state.fade_pos),
			projectile_state.fade_pos
		)
		radius = maxf(12.0, float(context.get(
			"stage4_magnetic_projectile_fade_radius",
			projectile_state.fade_radius
		)))
		alpha_scale = clampf(
			float(context.get(
				"stage4_magnetic_projectile_fade_timer",
				projectile_state.fade_timer_seconds
			)) / Stage4PonkMagneticProjectileState.PROJECTILE_FADE_SECONDS,
			0.0,
			1.0
		)
	center += shake_offset
	var frame: int = get_current_frame_index(frame_clock)
	canvas.draw_circle(
		center,
		radius * 0.95,
		Color(0.24, 0.92, 1.0, 0.16 * alpha_scale)
	)
	_draw_magnetic_sheet_frame(
		canvas,
		center,
		radius * 2.20,
		frame,
		Color(0.76, 1.0, 1.0, 0.74 * alpha_scale)
	)
	canvas.draw_circle(
		center,
		radius * 0.60,
		Color(0.92, 0.36, 1.0, 0.20 * alpha_scale)
	)
	canvas.draw_arc(
		center,
		radius * 0.72,
		-frame_clock * 7.0,
		-frame_clock * 7.0 + PI * 1.7,
		48,
		Color(0.64, 1.0, 1.0, 0.70 * alpha_scale),
		3.0,
		true
	)


func draw_meditation(
	canvas: Object,
	context: Dictionary,
	shake_offset: Vector2,
	meditation_state: Object,
	frame_clock: float
) -> void:
	var boss_center: Vector2 = _get_boss_center(context) + shake_offset
	for circle_value in _as_array(context.get(
		"stage4_meditation_circles",
		meditation_state.meditation_circles
	)):
		if not (circle_value is Dictionary):
			continue
		var circle: Dictionary = circle_value
		var alpha: float = clampf(float(circle.get("life", 0.0)) / 72.0, 0.0, 1.0)
		var center: Vector2 = _as_vector2(
			circle.get("pos", boss_center - shake_offset),
			boss_center - shake_offset
		) + shake_offset
		canvas.draw_arc(
			center,
			float(circle.get("radius", 40.0)),
			0.0,
			TAU,
			56,
			Color(1.0, 0.84, 0.42, alpha * 0.48),
			2.0,
			true
		)
	for trail_value in _as_array(context.get(
		"stage4_meditation_trails",
		meditation_state.meditation_trails
	)):
		if not (trail_value is Dictionary):
			continue
		var trail: Dictionary = trail_value
		var alpha: float = clampf(float(trail.get("life", 0.0)) / 34.0, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(
			trail.get("pos", Vector2.ZERO),
			Vector2.ZERO
		) + shake_offset
		canvas.draw_circle(
			pos,
			maxf(2.0, float(trail.get("radius", 9.0))) * alpha,
			Color(1.0, 0.78, 0.28, alpha * 0.32)
		)
	for particle_value in _as_array(context.get(
		"stage4_meditation_particles",
		meditation_state.meditation_particles
	)):
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var alpha: float = clampf(float(particle.get("life", 0.0)) / 42.0, 0.0, 1.0)
		var pos: Vector2 = _as_vector2(
			particle.get("pos", Vector2.ZERO),
			Vector2.ZERO
		) + shake_offset
		canvas.draw_circle(
			pos,
			maxf(1.0, float(particle.get("size", 2.5))),
			Color(0.92, 1.0, 0.78, alpha * 0.72)
		)
	var ball_pos: Vector2 = _as_vector2(
		context.get("stage4_meditation_ball_pos", meditation_state.meditation_ball_pos),
		meditation_state.meditation_ball_pos
	) + shake_offset
	canvas.draw_circle(ball_pos, 25.0, Color(1.0, 0.83, 0.28, 0.18))
	canvas.draw_arc(
		boss_center,
		Stage4PonkMeditationState.ORBIT_RADIUS * 1.5,
		frame_clock * 2.4,
		frame_clock * 2.4 + PI * 1.2,
		48,
		Color(1.0, 0.86, 0.42, 0.42),
		2.0,
		true
	)


func get_current_frame_index(frame_clock: float) -> int:
	return int(floor(
		frame_clock / Stage4PonkMagneticAssets.MAGNETIC_FIELD_FRAME_INTERVAL
	)) % Stage4PonkMagneticAssets.MAGNETIC_FIELD_FRAME_COUNT


func _draw_magnetic_sheet_frame(
	canvas: Object,
	center: Vector2,
	draw_size: float,
	frame: int,
	modulate: Color
) -> void:
	if magnetic_sheet == null:
		canvas.draw_circle(
			center,
			draw_size * 0.35,
			Color(modulate.r, modulate.g, modulate.b, modulate.a * 0.28)
		)
		return
	var sheet_size: Vector2 = magnetic_sheet.get_size()
	var cell_size := Vector2(
		sheet_size.x / float(Stage4PonkMagneticAssets.MAGNETIC_FIELD_COLS),
		sheet_size.y / float(Stage4PonkMagneticAssets.MAGNETIC_FIELD_ROWS)
	)
	var col: int = frame % Stage4PonkMagneticAssets.MAGNETIC_FIELD_COLS
	var row: int = int(floor(
		float(frame) / float(Stage4PonkMagneticAssets.MAGNETIC_FIELD_COLS)
	)) % Stage4PonkMagneticAssets.MAGNETIC_FIELD_ROWS
	canvas.draw_texture_rect_region(
		magnetic_sheet,
		Rect2(center - Vector2(draw_size, draw_size) * 0.5, Vector2(draw_size, draw_size)),
		Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size),
		modulate,
		false,
		true
	)


func _get_boss_center(context: Dictionary) -> Vector2:
	var boss_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2(330.0, 55.0))
	var boss_size: Vector2 = _get_vector2(context, "boss_paddle_size", Vector2.ZERO)
	if boss_size == Vector2.ZERO:
		boss_size = Vector2(
			float(context.get("boss_paddle_width", 100.0)),
			float(context.get("boss_hitbox_height", 40.0))
		)
	return boss_pos + boss_size * 0.5


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _as_vector2(source.get(key, fallback), fallback)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return fallback


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
