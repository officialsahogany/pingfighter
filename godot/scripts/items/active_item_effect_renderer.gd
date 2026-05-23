extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const BrickWallEffectRenderer := preload("res://scripts/items/active_item_brick_wall_effect_renderer.gd")

const LONG_BOOST_ICON_PATH := ActiveItemCatalog.LONG_BOOST_ICON_PATH
const VITAMIN_PILL_ICON_PATH := ActiveItemCatalog.VITAMIN_PILL_ICON_PATH
const STRANGE_VIAL_ICON_PATH := ActiveItemCatalog.STRANGE_VIAL_ICON_PATH
const STOPWATCH_ICON_PATH := ActiveItemCatalog.STOPWATCH_ICON_PATH
const MAGNET_FIELD_ICON_PATH := ActiveItemCatalog.MAGNET_FIELD_ICON_PATH
const HOLY_BARRIER_ICON_PATH := ActiveItemCatalog.HOLY_BARRIER_ICON_PATH
const DASH_BOOST_ICON_PATH := "res://assets/sprites/items/dash_boost.png"
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PICKUP_ICON_SIZE := 40.0
const PICKUP_DISPLAY_FONT_SIZE := 16
const PICKUP_NOTICE_FONT_SIZE := 14
const PICKUP_NOTICE_TEXT := "획득!"
const PICKUP_GLOW_RING_COUNT := 2
const PICKUP_GLOW_ARC_POINT_COUNT := 18
const MAX_PICKUP_PARTICLE_RENDER_COUNT := 28
const EXTRA_PICKUP_TEXT_PREWARM_ITEMS := [
	"ammo_box",
	"doping_potion",
	"elixir_of_mastery",
]
const LONG_BOOST_TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const LONG_BOOST_TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const LONG_BOOST_TIMER_STACK_SPACING := 18.0
const LONG_BOOST_TIMER_ICON_SIZE := 28.0
const REGENERATION_POTION_PARTICLE_DURATION_SEC := 0.78
const REGENERATION_POTION_RING_DURATION_SEC := 0.58
const EFFECT_PARTICLE_ALPHA_CUTOFF := 0.02
const STOPWATCH_FACE_NUMBERS := ["12", "3", "6", "9"]

var long_boost_icon_texture: Texture2D
var vitamin_pill_icon_texture: Texture2D
var strange_vial_icon_texture: Texture2D
var stopwatch_icon_texture: Texture2D
var magnet_field_icon_texture: Texture2D
var holy_barrier_icon_texture: Texture2D
var dash_boost_icon_texture: Texture2D
var brick_wall_variant_sheet_texture: Texture2D
var _font_cache: Font
var _pickup_icon_cache: Dictionary = {}
var _text_size_cache: Dictionary = {}
var _prewarm_step_index := 0
var _brick_wall_renderer: Object = BrickWallEffectRenderer.new()


func prewarm_assets(active_item_hud_visuals: Object = null) -> void:
	while not prewarm_assets_step(active_item_hud_visuals):
		pass


func prewarm_assets_step(active_item_hud_visuals: Object = null) -> bool:
	match _prewarm_step_index:
		0:
			if ResourceLoader.exists(LONG_BOOST_ICON_PATH):
				_touch_texture(_get_long_boost_icon_texture())
		1:
			if ResourceLoader.exists(VITAMIN_PILL_ICON_PATH):
				_touch_texture(_get_vitamin_pill_icon_texture())
		2:
			if ResourceLoader.exists(STRANGE_VIAL_ICON_PATH):
				_touch_texture(_get_strange_vial_icon_texture())
		3:
			if ResourceLoader.exists(MAGNET_FIELD_ICON_PATH):
				_touch_texture(_get_magnet_field_icon_texture())
		4:
			if ResourceLoader.exists(HOLY_BARRIER_ICON_PATH):
				_touch_texture(_get_holy_barrier_icon_texture())
		5:
			if ResourceLoader.exists(DASH_BOOST_ICON_PATH):
				_touch_texture(_get_dash_boost_icon_texture())
		6:
			_brick_wall_renderer.prewarm_assets()
			brick_wall_variant_sheet_texture = _brick_wall_renderer.brick_wall_variant_sheet_texture
		7:
			if active_item_hud_visuals != null and active_item_hud_visuals.has_method("prewarm_catalog_icons_step"):
				if not bool(active_item_hud_visuals.prewarm_catalog_icons_step()):
					return false
			elif active_item_hud_visuals != null and active_item_hud_visuals.has_method("prewarm_catalog_icons"):
				active_item_hud_visuals.prewarm_catalog_icons()
		8:
			_prewarm_pickup_text()
		_:
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func draw_field_effects(
	canvas: CanvasItem,
	pickup_particles: Array,
	regeneration_potion_rings: Array,
	regeneration_potion_particles: Array,
	stopwatch_context: Dictionary,
	magnet_field_context: Dictionary,
	magnet_field_particles: Array,
	holy_barrier_context: Dictionary,
	holy_barrier_particles: Array,
	brick_wall_context: Dictionary,
	long_boost_timer_context: Dictionary,
	vitamin_pill_timer_context: Dictionary,
	strange_vial_timer_context: Dictionary,
	dash_boost_context: Dictionary = {},
	dash_boost_particles: Array = [],
	shake_offset: Vector2 = Vector2.ZERO,
	timer_stack: Object = null,
	perf_logger: Object = null
) -> void:
	if canvas == null:
		return
	var detail_perf_logger: Object = perf_logger if _should_sample_detail(perf_logger, "active_item.field") else null
	var sample_start: int = _perf_begin(detail_perf_logger)
	_draw_stopwatch_effect(canvas, stopwatch_context)
	_perf_end(detail_perf_logger, "active_item.field.stopwatch", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_magnet_field_effect(canvas, magnet_field_context, magnet_field_particles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.field.magnet", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_holy_barrier_effect(canvas, holy_barrier_context, holy_barrier_particles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.field.holy_barrier", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_dash_boost_effect(canvas, dash_boost_context, dash_boost_particles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.field.dash_boost", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_brick_wall_effect(canvas, brick_wall_context, shake_offset)
	_perf_end(detail_perf_logger, "active_item.field.brick_wall", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_regeneration_potion_effect(canvas, regeneration_potion_rings, regeneration_potion_particles, shake_offset)
	_perf_end(detail_perf_logger, "active_item.field.regeneration", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_vitamin_pill_effect(canvas, vitamin_pill_timer_context, shake_offset)
	_perf_end(detail_perf_logger, "active_item.field.vitamin_pill", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_strange_vial_effect(canvas, strange_vial_timer_context, shake_offset)
	_perf_end(detail_perf_logger, "active_item.field.strange_vial", sample_start)
	var has_shared_timer_stack: bool = timer_stack != null and timer_stack.has_method("claim")
	var timer_stack_index := 0
	if bool(magnet_field_context.get("active", false)):
		if has_shared_timer_stack:
			timer_stack_index = int(timer_stack.claim("magnet_field", true))
		sample_start = _perf_begin(detail_perf_logger)
		_draw_magnet_field_timer_gauge(canvas, magnet_field_context, timer_stack_index)
		_perf_end(detail_perf_logger, "active_item.field.timer_magnet", sample_start)
		if not has_shared_timer_stack:
			timer_stack_index += 1
	if bool(holy_barrier_context.get("active", false)):
		if has_shared_timer_stack:
			timer_stack_index = int(timer_stack.claim("holy_barrier", true))
		sample_start = _perf_begin(detail_perf_logger)
		_draw_holy_barrier_timer_gauge(canvas, holy_barrier_context, timer_stack_index)
		_perf_end(detail_perf_logger, "active_item.field.timer_holy_barrier", sample_start)
		if not has_shared_timer_stack:
			timer_stack_index += 1
	if bool(vitamin_pill_timer_context.get("active", false)):
		if has_shared_timer_stack:
			timer_stack_index = int(timer_stack.claim("vitamin_pill", true))
		sample_start = _perf_begin(detail_perf_logger)
		_draw_vitamin_pill_timer_gauge(canvas, vitamin_pill_timer_context, timer_stack_index)
		_perf_end(detail_perf_logger, "active_item.field.timer_vitamin_pill", sample_start)
		if not has_shared_timer_stack:
			timer_stack_index += 1
	if bool(strange_vial_timer_context.get("active", false)):
		if has_shared_timer_stack:
			timer_stack_index = int(timer_stack.claim("strange_vial", true))
		sample_start = _perf_begin(detail_perf_logger)
		_draw_strange_vial_timer_gauge(canvas, strange_vial_timer_context, timer_stack_index)
		_perf_end(detail_perf_logger, "active_item.field.timer_strange_vial", sample_start)
		if not has_shared_timer_stack:
			timer_stack_index += 1
	if bool(long_boost_timer_context.get("active", false)):
		if has_shared_timer_stack:
			timer_stack_index = int(timer_stack.claim("long_boost", true))
		sample_start = _perf_begin(detail_perf_logger)
		_draw_long_boost_timer_gauge(canvas, long_boost_timer_context, timer_stack_index)
		_perf_end(detail_perf_logger, "active_item.field.timer_long_boost", sample_start)
		if not has_shared_timer_stack:
			timer_stack_index += 1
	if bool(dash_boost_context.get("active", false)):
		if has_shared_timer_stack:
			timer_stack_index = int(timer_stack.claim("dash_boost", true))
		sample_start = _perf_begin(detail_perf_logger)
		_draw_dash_boost_timer_gauge(canvas, dash_boost_context, timer_stack_index)
		_perf_end(detail_perf_logger, "active_item.field.timer_dash_boost", sample_start)
	sample_start = _perf_begin(detail_perf_logger)
	var pickup_particle_start: int = max(0, pickup_particles.size() - MAX_PICKUP_PARTICLE_RENDER_COUNT)
	for particle_index in range(pickup_particle_start, pickup_particles.size()):
		var particle_value: Variant = pickup_particles[particle_index]
		if particle_value is Dictionary:
			_draw_pickup_particle(canvas, particle_value, shake_offset)
	_perf_end(detail_perf_logger, "active_item.field.pickup_particles", sample_start)


func draw_pickup_effect(
	canvas: CanvasItem,
	registry: Object,
	pickup_effect: Dictionary,
	perf_logger: Object = null
) -> void:
	if canvas == null or pickup_effect.is_empty():
		return

	var center: Vector2 = _get_vector2(pickup_effect, "position", Vector2.ZERO)
	var alpha: float = clamp(float(pickup_effect.get("alpha", 1.0)), 0.0, 1.0)
	if alpha <= 0.0:
		return

	var detail_perf_logger: Object = perf_logger if _should_sample_detail(perf_logger, "active_item.pickup") else null
	var sample_start: int = _perf_begin(detail_perf_logger)
	_draw_pickup_glow(canvas, center, alpha)
	_perf_end(detail_perf_logger, "active_item.pickup.glow", sample_start)

	sample_start = _perf_begin(detail_perf_logger)
	var icon_texture: Texture2D = _get_pickup_icon_texture(pickup_effect, registry)
	_perf_end(detail_perf_logger, "active_item.pickup.icon_lookup", sample_start)
	if icon_texture != null:
		var icon_rect := Rect2(
			center - Vector2(PICKUP_ICON_SIZE, PICKUP_ICON_SIZE) * 0.5,
			Vector2(PICKUP_ICON_SIZE, PICKUP_ICON_SIZE)
		)
		canvas.draw_texture_rect(icon_texture, icon_rect, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		canvas.draw_circle(center, PICKUP_ICON_SIZE * 0.45, Color(1.0, 100.0 / 255.0, 1.0, 0.85 * alpha))

	var item_name: String = str(pickup_effect.get("display_name", ""))
	sample_start = _perf_begin(detail_perf_logger)
	_draw_centered_text(canvas, item_name, center + Vector2(0.0, 54.0), PICKUP_DISPLAY_FONT_SIZE, Color(1.0, 1.0, 1.0, alpha))
	_draw_centered_text(canvas, PICKUP_NOTICE_TEXT, center + Vector2(0.0, 70.0), PICKUP_NOTICE_FONT_SIZE, Color(1.0, 215.0 / 255.0, 0.0, alpha))


	_perf_end(detail_perf_logger, "active_item.pickup.text", sample_start)


func _draw_stopwatch_effect(canvas: CanvasItem, stopwatch_context: Dictionary) -> void:
	if not bool(stopwatch_context.get("active", false)):
		return

	var flash_timer: float = float(stopwatch_context.get("flash_timer_frames", 0.0))
	var flash_initial: float = max(1.0, float(stopwatch_context.get("flash_initial_frames", 10.0)))
	if flash_timer > 0.0:
		var flash_alpha: float = clamp((flash_timer / flash_initial) * (250.0 / 255.0), 0.0, 0.98)
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(FIELD_WIDTH, FIELD_HEIGHT)), Color(1.0, 1.0, 200.0 / 255.0, flash_alpha))

	var clock_center := Vector2(FIELD_WIDTH * 0.5, 100.0)
	var clock_radius: float = 60.0
	canvas.draw_circle(clock_center, clock_radius + 10.0, Color(0.0, 0.0, 0.0, 150.0 / 255.0))
	canvas.draw_circle(clock_center, clock_radius, Color(180.0 / 255.0, 140.0 / 255.0, 90.0 / 255.0, 1.0))
	canvas.draw_circle(clock_center, clock_radius - 2.0, Color(220.0 / 255.0, 180.0 / 255.0, 120.0 / 255.0, 1.0))
	canvas.draw_circle(clock_center, clock_radius - 8.0, Color(1.0, 1.0, 240.0 / 255.0, 1.0))

	for i in range(STOPWATCH_FACE_NUMBERS.size()):
		var angle: float = float(i) * PI * 0.5 - PI * 0.5
		var text_pos: Vector2 = clock_center + Vector2(cos(angle), sin(angle)) * (clock_radius - 20.0)
		_draw_centered_text(canvas, str(STOPWATCH_FACE_NUMBERS[i]), text_pos + Vector2(0.0, 5.0), 16, Color(80.0 / 255.0, 60.0 / 255.0, 40.0 / 255.0, 1.0))

	var clock_angle: float = float(stopwatch_context.get("clock_angle", 0.0))
	_draw_clock_hand(canvas, clock_center, clock_angle * 0.5, 30.0, Color(40.0 / 255.0, 30.0 / 255.0, 20.0 / 255.0, 1.0), 4.0)
	_draw_clock_hand(canvas, clock_center, clock_angle * 2.0, 45.0, Color(40.0 / 255.0, 30.0 / 255.0, 20.0 / 255.0, 1.0), 2.0)
	_draw_clock_hand(canvas, clock_center, clock_angle * 6.0, 50.0, Color(1.0, 0.0, 0.0, 1.0), 1.0)
	canvas.draw_circle(clock_center, 3.0, Color(60.0 / 255.0, 40.0 / 255.0, 20.0 / 255.0, 1.0))


func _draw_magnet_field_effect(
	canvas: CanvasItem,
	magnet_context: Dictionary,
	magnet_particles: Array,
	shake_offset: Vector2
) -> void:
	if not bool(magnet_context.get("active", false)):
		return

	var player_center: Vector2 = _get_vector2(
		magnet_context,
		"player_center",
		Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 25.0)
	) + shake_offset
	var timer_frames: float = float(magnet_context.get("timer_frames", 0.0))
	var initial_timer_frames: float = max(1.0, float(magnet_context.get("initial_timer_frames", 480.0)))
	var remaining_ratio: float = clamp(timer_frames / initial_timer_frames, 0.0, 1.0)
	var alpha_base: float = min(180.0 / 255.0, (180.0 / 255.0) * remaining_ratio)
	var field_phase: float = float(magnet_context.get("field_phase", 0.0))

	for i in range(3):
		var ring_phase: float = field_phase + float(i) * TAU / 3.0
		var pulse: float = 0.6 + 0.4 * sin(ring_phase)
		var radius: float = (60.0 + float(i) * 50.0) * pulse
		var alpha: float = alpha_base * 0.3 * (1.0 - float(i) / 3.0)
		if alpha > 0.0 and radius > 0.0:
			canvas.draw_arc(
				player_center,
				radius,
				0.0,
				TAU,
				24,
				Color(100.0 / 255.0, 150.0 / 255.0, 1.0, alpha),
				2.0
			)

	for i in range(4):
		var line_phase: float = field_phase * 0.5 + float(i) * TAU / 6.0
		var start_radius: float = 120.0 + 30.0 * sin(line_phase)
		var angle: float = TAU * float(i) / 6.0
		var start_pos := Vector2(
			player_center.x + cos(angle) * start_radius,
			player_center.y - 80.0 - 20.0 * sin(line_phase)
		)
		var mid_pos := Vector2(
			player_center.x + cos(angle) * start_radius * 0.5,
			player_center.y - 40.0
		)
		var line_alpha: float = alpha_base * 0.4
		if line_alpha > 0.0:
			var line_color := Color(150.0 / 255.0, 120.0 / 255.0, 1.0, line_alpha)
			canvas.draw_line(start_pos, mid_pos, line_color, 1.0)
			canvas.draw_line(mid_pos, player_center, line_color, 1.0)

	for particle_value in magnet_particles:
		if particle_value is Dictionary:
			_draw_magnet_field_particle(canvas, particle_value, shake_offset)

	if timer_frames < 60.0 and int(timer_frames) % 10 < 5:
		canvas.draw_circle(player_center, 100.0, Color(150.0 / 255.0, 100.0 / 255.0, 1.0, 30.0 / 255.0))


func _draw_holy_barrier_effect(
	canvas: CanvasItem,
	barrier_context: Dictionary,
	holy_barrier_particles: Array,
	shake_offset: Vector2
) -> void:
	if not bool(barrier_context.get("active", false)):
		return

	var width: float = float(barrier_context.get("width", FIELD_WIDTH))
	var barrier_y: float = float(barrier_context.get("barrier_y", FIELD_HEIGHT - 25.0))
	var barrier_height: float = float(barrier_context.get("barrier_height", 20.0))
	var center_y: float = barrier_y + barrier_height * 0.5
	var glow_phase: float = float(barrier_context.get("glow_phase", 0.0))
	var glow_intensity: float = 0.75 + 0.25 * sin(glow_phase)
	var gradient_height: int = int(barrier_height + 20.0)

	for i in range(0, gradient_height, 4):
		var ratio: float = float(i) / max(1.0, float(gradient_height))
		var alpha: float = (80.0 / 255.0) * glow_intensity * (1.0 - ratio)
		var y: float = barrier_y - 10.0 + float(i)
		canvas.draw_line(
			Vector2(0.0, y) + shake_offset,
			Vector2(width, y) + shake_offset,
			Color(1.0, 1.0, 200.0 / 255.0, alpha),
			2.0
		)

	var line_alpha: float = (200.0 / 255.0) * glow_intensity
	for offset in range(-1, 2):
		var layer_alpha: float = line_alpha * (1.0 - abs(float(offset)) * 0.2)
		canvas.draw_line(
			Vector2(0.0, center_y + float(offset)) + shake_offset,
			Vector2(width, center_y + float(offset)) + shake_offset,
			Color(1.0, 1.0, 150.0 / 255.0, layer_alpha),
			2.0
		)

	var symbol_spacing: int = 120
	var symbol_size: float = 12.0
	for x in range(int(symbol_spacing * 0.5), int(width), symbol_spacing):
		var center := Vector2(float(x), center_y) + shake_offset
		var pulse: float = 0.7 + 0.3 * sin(glow_phase + float(x) * 0.05)
		canvas.draw_circle(center, symbol_size * pulse * 0.4, Color(1.0, 1.0, 200.0 / 255.0, 0.88))
		for angle_degrees in range(0, 360, 90):
			var angle: float = deg_to_rad(float(angle_degrees))
			var ray_end: Vector2 = center + Vector2(cos(angle), sin(angle)) * symbol_size * pulse
			canvas.draw_line(center, ray_end, Color(1.0, 1.0, 180.0 / 255.0, 0.86), 1.0)

	for particle_value in holy_barrier_particles:
		if particle_value is Dictionary:
			_draw_holy_barrier_particle(canvas, particle_value, shake_offset)

	var timer_frames: float = float(barrier_context.get("timer_frames", 0.0))
	if timer_frames < 60.0 and int(timer_frames) % 10 < 5:
		canvas.draw_rect(
			Rect2(Vector2(0.0, barrier_y - 5.0) + shake_offset, Vector2(width, barrier_height + 10.0)),
			Color(1.0, 1.0, 1.0, 50.0 / 255.0)
		)


func _draw_dash_boost_effect(
	canvas: CanvasItem,
	dash_boost_context: Dictionary,
	dash_boost_particles: Array,
	shake_offset: Vector2
) -> void:
	if not bool(dash_boost_context.get("active", false)):
		return

	var glow_phase: float = float(dash_boost_context.get("glow_phase", 0.0))
	var pulse: float = abs(sin(glow_phase))
	var player_center: Vector2 = _get_vector2(
		dash_boost_context,
		"player_center",
		Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 25.0)
	) + shake_offset

	var aura_radius: float = 60.0 + 10.0 * pulse
	for i in range(3):
		var radius: float = aura_radius - float(i) * 15.0
		if radius <= 0.0:
			continue
		var alpha: float = clamp((30.0 + 20.0 * pulse - float(i) * 10.0) / 255.0, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		canvas.draw_arc(player_center, radius, 0.0, TAU, 24, Color(100.0 / 255.0, 200.0 / 255.0, 1.0, alpha), 2.0)

	for i in range(4):
		var angle: float = glow_phase + float(i) * (PI * 0.5)
		var length: float = 20.0 + 10.0 * pulse
		var start_pos: Vector2 = player_center + Vector2(cos(angle), sin(angle)) * 25.0
		var end_pos: Vector2 = player_center + Vector2(cos(angle), sin(angle)) * (25.0 + length)
		canvas.draw_line(
			start_pos,
			end_pos,
			Color(150.0 / 255.0, 1.0, 200.0 / 255.0, clamp(100.0 / 255.0 * pulse, 0.0, 1.0)),
			2.0
		)

	for particle_value in dash_boost_particles:
		if particle_value is Dictionary:
			_draw_dash_boost_particle(canvas, particle_value, shake_offset)


func _draw_dash_boost_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var alpha: float = clamp(float(particle.get("alpha", 0.0)), 0.0, 1.0)
	if alpha <= 0.0:
		return
	var position: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
	var radius: float = max(1.0, float(particle.get("radius", 2.0)))
	var fallback_color := Color(100.0 / 255.0, 200.0 / 255.0, 1.0, 1.0)
	var color: Color = _get_color(particle.get("color", fallback_color), fallback_color)
	var core_color := Color(color.r, color.g, color.b, alpha)
	var glow_color := Color(color.r, color.g, color.b, alpha * 0.3)
	canvas.draw_circle(position, radius * 1.5, glow_color)
	canvas.draw_circle(position, radius, core_color)


func _draw_brick_wall_effect(canvas: CanvasItem, brick_wall_context: Dictionary, shake_offset: Vector2) -> void:
	_brick_wall_renderer.draw_brick_wall_effect(canvas, brick_wall_context, shake_offset)


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
		canvas.draw_arc(center, radius, 0.0, TAU, 24, Color(1.0, 230.0 / 255.0, 80.0 / 255.0, 0.58 * life), 4.0)
		canvas.draw_arc(center, radius * 0.62, 0.0, TAU, 20, Color(1.0, 1.0, 170.0 / 255.0, 0.34 * life), 2.0)
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


func _draw_vitamin_pill_effect(canvas: CanvasItem, timer_context: Dictionary, shake_offset: Vector2) -> void:
	if not bool(timer_context.get("active", false)):
		return

	var player_center: Vector2 = _get_vector2(
		timer_context,
		"player_center",
		Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 25.0)
	) + shake_offset
	var phase: float = float(timer_context.get("phase", 0.0))
	var timer_frames: float = float(timer_context.get("timer_frames", 0.0))
	var initial_timer_frames: float = max(1.0, float(timer_context.get("initial_timer_frames", 600.0)))
	var remaining_ratio: float = clamp(timer_frames / initial_timer_frames, 0.0, 1.0)
	var flash_timer: float = float(timer_context.get("flash_timer_frames", 0.0))
	var flash_initial: float = max(1.0, float(timer_context.get("flash_initial_frames", 10.0)))

	if flash_timer > 0.0:
		var flash_alpha: float = clamp((flash_timer / flash_initial) * 0.12, 0.0, 0.12)
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(FIELD_WIDTH, FIELD_HEIGHT)), Color(0.25, 0.72, 1.0, flash_alpha))

	var aura_alpha: float = 0.16 + 0.08 * sin(phase * 1.7)
	canvas.draw_circle(player_center, 42.0, Color(80.0 / 255.0, 170.0 / 255.0, 1.0, aura_alpha * remaining_ratio))
	canvas.draw_arc(player_center, 48.0 + 4.0 * sin(phase), 0.0, TAU, 24, Color(145.0 / 255.0, 220.0 / 255.0, 1.0, 0.34 * remaining_ratio), 2.0)

	for i in range(4):
		var lane: float = float(i) - 1.5
		var wave: float = sin(phase * 1.35 + lane * 0.9)
		var start_pos := player_center + Vector2(-46.0 - 8.0 * wave, lane * 6.0 - 8.0)
		var end_pos := start_pos + Vector2(-22.0 - 7.0 * abs(wave), -3.0 * wave)
		var alpha: float = (0.20 + 0.10 * abs(wave)) * remaining_ratio
		canvas.draw_line(start_pos, end_pos, Color(120.0 / 255.0, 215.0 / 255.0, 1.0, alpha), 2.0)


func _draw_strange_vial_effect(canvas: CanvasItem, timer_context: Dictionary, shake_offset: Vector2) -> void:
	if not bool(timer_context.get("active", false)):
		return

	var player_center: Vector2 = _get_vector2(
		timer_context,
		"player_center",
		Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 25.0)
	) + shake_offset
	var phase: float = float(timer_context.get("phase", 0.0))
	var effect_type: String = str(timer_context.get("effect_type", ""))
	var scale_value: float = max(0.1, float(timer_context.get("paddle_scale", 1.0)))
	var timer_frames: float = float(timer_context.get("timer_frames", 0.0))
	var initial_timer_frames: float = max(1.0, float(timer_context.get("initial_timer_frames", 600.0)))
	var remaining_ratio: float = clamp(timer_frames / initial_timer_frames, 0.0, 1.0)
	var flash_timer: float = float(timer_context.get("flash_timer_frames", 0.0))
	var flash_initial: float = max(1.0, float(timer_context.get("flash_initial_frames", 12.0)))
	var is_enlarge: bool = effect_type == "enlarge"
	var primary := Color(170.0 / 255.0, 80.0 / 255.0, 230.0 / 255.0, 1.0) if is_enlarge else Color(70.0 / 255.0, 230.0 / 255.0, 120.0 / 255.0, 1.0)
	var secondary := Color(215.0 / 255.0, 140.0 / 255.0, 1.0, 1.0) if is_enlarge else Color(110.0 / 255.0, 1.0, 165.0 / 255.0, 1.0)

	if flash_timer > 0.0:
		var flash_alpha: float = clamp((flash_timer / flash_initial) * 0.14, 0.0, 0.14)
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(FIELD_WIDTH, FIELD_HEIGHT)), Color(primary.r, primary.g, primary.b, flash_alpha))

	var base_radius: float = 34.0 + 15.0 * clamp(scale_value, 0.5, 2.2)
	for i in range(3):
		var radius: float = base_radius + float(i) * 14.0 + sin(phase + float(i)) * 3.0
		var angle_offset: float = phase * (0.55 + float(i) * 0.12) * (1.0 if is_enlarge else -1.0)
		var sides: int = 6 if (i % 2 == 0) else 3
		if not is_enlarge and i == 1:
			sides = 8
		_draw_polygon_outline(canvas, player_center, radius, sides, angle_offset, Color(primary.r, primary.g, primary.b, (0.30 - float(i) * 0.06) * remaining_ratio), 2.0)

	for i in range(6):
		var angle: float = phase * (0.8 if is_enlarge else -1.05) + TAU * float(i) / 6.0
		var distance: float = base_radius + 10.0 + sin(phase * 1.6 + float(i)) * 6.0
		var dot_pos := player_center + Vector2(cos(angle), sin(angle)) * distance
		var pulse: float = 0.55 + 0.45 * sin(phase * 2.0 + float(i) * 0.7)
		canvas.draw_circle(dot_pos, 2.0 + 1.4 * pulse, Color(secondary.r, secondary.g, secondary.b, (0.28 + 0.18 * pulse) * remaining_ratio))

	var arrow_dir: float = -1.0 if is_enlarge else 1.0
	for i in range(3):
		var lane: float = float(i) - 1.0
		var offset := Vector2(lane * 16.0, -42.0 - lane * 4.0 * arrow_dir)
		var start_pos: Vector2 = player_center + offset
		var end_pos: Vector2 = start_pos + Vector2(0.0, -18.0 * arrow_dir)
		canvas.draw_line(start_pos, end_pos, Color(primary.r, primary.g, primary.b, 0.34 * remaining_ratio), 2.0)
		canvas.draw_line(end_pos, end_pos + Vector2(-5.0, 6.0 * arrow_dir), Color(primary.r, primary.g, primary.b, 0.34 * remaining_ratio), 2.0)
		canvas.draw_line(end_pos, end_pos + Vector2(5.0, 6.0 * arrow_dir), Color(primary.r, primary.g, primary.b, 0.34 * remaining_ratio), 2.0)


func _draw_magnet_field_timer_gauge(canvas: CanvasItem, timer_context: Dictionary, stack_index: int) -> void:
	var active: bool = bool(timer_context.get("active", false))
	var timer_frames: float = float(timer_context.get("timer_frames", 0.0))
	var initial_timer_frames: float = float(timer_context.get("initial_timer_frames", 0.0))
	if not active or timer_frames <= 0.0:
		return

	var ratio: float = clamp(timer_frames / max(1.0, initial_timer_frames), 0.0, 1.0)
	var remaining_seconds: float = timer_frames / 60.0
	var frame_rect := Rect2(_get_timer_bar_position(stack_index), LONG_BOOST_TIMER_BAR_SIZE)
	var outer_rect := frame_rect.grow(5.0)
	var mid_rect := frame_rect.grow(3.0)
	var border_rect := frame_rect.grow(2.0)
	canvas.draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_rect(outer_rect, Color(30.0 / 255.0, 20.0 / 255.0, 50.0 / 255.0, 0.94))
	canvas.draw_rect(mid_rect, Color(80.0 / 255.0, 60.0 / 255.0, 160.0 / 255.0, 0.96))
	canvas.draw_rect(mid_rect, Color(140.0 / 255.0, 110.0 / 255.0, 220.0 / 255.0, 0.92), false, 2.0)
	canvas.draw_rect(border_rect, Color(25.0 / 255.0, 18.0 / 255.0, 45.0 / 255.0, 0.96))
	canvas.draw_rect(frame_rect, Color(0.06, 0.04, 0.10, 0.94))

	var base_color: Color
	var highlight_color: Color
	if remaining_seconds > 5.0:
		base_color = Color(120.0 / 255.0, 80.0 / 255.0, 1.0, 0.98)
		highlight_color = Color(180.0 / 255.0, 150.0 / 255.0, 1.0, 0.98)
	elif remaining_seconds > 3.0:
		base_color = Color(100.0 / 255.0, 70.0 / 255.0, 220.0 / 255.0, 0.98)
		highlight_color = Color(160.0 / 255.0, 130.0 / 255.0, 1.0, 0.98)
	else:
		var pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.015))
		base_color = Color((200.0 + 55.0 * pulse) / 255.0, (80.0 + 60.0 * pulse) / 255.0, (150.0 + 60.0 * pulse) / 255.0, 0.99)
		highlight_color = Color((230.0 + 25.0 * pulse) / 255.0, (120.0 + 50.0 * pulse) / 255.0, (200.0 + 55.0 * pulse) / 255.0, 0.99)

	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * ratio)
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, base_color)
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.34))), highlight_color)
	for i in range(1, 10):
		var tick_x: float = frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(i) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(140.0 / 255.0, 120.0 / 255.0, 200.0 / 255.0, 0.92),
			1.0
		)

	if fill_width > 2.0 and fill_width < frame_rect.size.x - 4.0:
		var glint_x: float = frame_rect.position.x + 2.0 + fill_width
		canvas.draw_line(
			Vector2(glint_x, frame_rect.position.y + 2.0),
			Vector2(glint_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(1.0, 1.0, 1.0, 0.46),
			2.0
		)

	var icon_size := Vector2(LONG_BOOST_TIMER_ICON_SIZE, LONG_BOOST_TIMER_ICON_SIZE) * 0.66
	var icon_top_left := frame_rect.position + Vector2(-icon_size.x - 6.0, 0.0)
	var icon_center := icon_top_left + icon_size * 0.5
	var icon_pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.01))
	canvas.draw_arc(icon_center, icon_size.x * 0.70, 0.0, TAU, 24, Color(140.0 / 255.0, 100.0 / 255.0, 1.0, 0.42 + 0.32 * icon_pulse), 2.0)
	var icon_texture: Texture2D = _get_magnet_field_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_top_left, icon_size), false)
	else:
		_draw_magnet_field_icon_fallback(canvas, icon_center, icon_size.x)


func _draw_holy_barrier_timer_gauge(canvas: CanvasItem, timer_context: Dictionary, stack_index: int) -> void:
	var active: bool = bool(timer_context.get("active", false))
	var timer_frames: float = float(timer_context.get("timer_frames", 0.0))
	var initial_timer_frames: float = float(timer_context.get("initial_timer_frames", 0.0))
	if not active or timer_frames <= 0.0:
		return

	var ratio: float = clamp(timer_frames / max(1.0, initial_timer_frames), 0.0, 1.0)
	var remaining_seconds: float = timer_frames / 60.0
	var frame_rect := Rect2(_get_timer_bar_position(stack_index), LONG_BOOST_TIMER_BAR_SIZE)
	var outer_rect := frame_rect.grow(5.0)
	var mid_rect := frame_rect.grow(3.0)
	var border_rect := frame_rect.grow(2.0)
	canvas.draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_rect(outer_rect, Color(40.0 / 255.0, 35.0 / 255.0, 20.0 / 255.0, 0.94))
	canvas.draw_rect(mid_rect, Color(180.0 / 255.0, 150.0 / 255.0, 80.0 / 255.0, 0.96))
	canvas.draw_rect(mid_rect, Color(1.0, 220.0 / 255.0, 150.0 / 255.0, 0.92), false, 2.0)
	canvas.draw_rect(border_rect, Color(35.0 / 255.0, 30.0 / 255.0, 18.0 / 255.0, 0.96))
	canvas.draw_rect(frame_rect, Color(0.10, 0.08, 0.04, 0.94))

	var base_color: Color
	var highlight_color: Color
	if remaining_seconds > 4.0:
		base_color = Color(1.0, 220.0 / 255.0, 100.0 / 255.0, 0.98)
		highlight_color = Color(1.0, 245.0 / 255.0, 180.0 / 255.0, 0.98)
	elif remaining_seconds > 2.0:
		base_color = Color(1.0, 180.0 / 255.0, 80.0 / 255.0, 0.98)
		highlight_color = Color(1.0, 210.0 / 255.0, 130.0 / 255.0, 0.98)
	else:
		var pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.015))
		base_color = Color(1.0, (140.0 + 60.0 * pulse) / 255.0, (60.0 + 40.0 * pulse) / 255.0, 0.99)
		highlight_color = Color(1.0, (180.0 + 50.0 * pulse) / 255.0, (100.0 + 50.0 * pulse) / 255.0, 0.99)

	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * ratio)
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, base_color)
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.34))), highlight_color)
	for i in range(1, 10):
		var tick_x: float = frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(i) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(220.0 / 255.0, 200.0 / 255.0, 160.0 / 255.0, 0.92),
			1.0
		)

	if fill_width > 2.0 and fill_width < frame_rect.size.x - 4.0:
		var glint_x: float = frame_rect.position.x + 2.0 + fill_width
		canvas.draw_line(
			Vector2(glint_x, frame_rect.position.y + 2.0),
			Vector2(glint_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(1.0, 1.0, 1.0, 0.46),
			2.0
		)

	var icon_size := Vector2(LONG_BOOST_TIMER_ICON_SIZE, LONG_BOOST_TIMER_ICON_SIZE) * 0.66
	var icon_top_left := frame_rect.position + Vector2(-icon_size.x - 6.0, 0.0)
	var icon_center := icon_top_left + icon_size * 0.5
	var icon_pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.01))
	canvas.draw_arc(icon_center, icon_size.x * 0.70, 0.0, TAU, 24, Color(1.0, 1.0, 150.0 / 255.0, 0.42 + 0.32 * icon_pulse), 2.0)
	var icon_texture: Texture2D = _get_holy_barrier_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_top_left, icon_size), false)
	else:
		canvas.draw_circle(icon_center, icon_size.x * 0.42, Color(1.0, 245.0 / 255.0, 170.0 / 255.0, 1.0))


func _draw_dash_boost_timer_gauge(canvas: CanvasItem, timer_context: Dictionary, stack_index: int) -> void:
	var active: bool = bool(timer_context.get("active", false))
	var timer_frames: float = float(timer_context.get("timer_frames", 0.0))
	var initial_timer_frames: float = float(timer_context.get("initial_timer_frames", 0.0))
	if not active or timer_frames <= 0.0:
		return

	var ratio: float = clamp(timer_frames / max(1.0, initial_timer_frames), 0.0, 1.0)
	var remaining_seconds: float = timer_frames / 60.0
	var frame_rect := Rect2(_get_timer_bar_position(stack_index), LONG_BOOST_TIMER_BAR_SIZE)
	var outer_rect := frame_rect.grow(5.0)
	var mid_rect := frame_rect.grow(3.0)
	var border_rect := frame_rect.grow(2.0)
	canvas.draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_rect(outer_rect, Color(18.0 / 255.0, 36.0 / 255.0, 52.0 / 255.0, 0.94))
	canvas.draw_rect(mid_rect, Color(60.0 / 255.0, 130.0 / 255.0, 180.0 / 255.0, 0.96))
	canvas.draw_rect(mid_rect, Color(120.0 / 255.0, 210.0 / 255.0, 1.0, 0.92), false, 2.0)
	canvas.draw_rect(border_rect, Color(20.0 / 255.0, 32.0 / 255.0, 50.0 / 255.0, 0.96))
	canvas.draw_rect(frame_rect, Color(0.04, 0.08, 0.13, 0.94))

	var base_color: Color
	var highlight_color: Color
	if remaining_seconds > 5.0:
		base_color = Color(100.0 / 255.0, 200.0 / 255.0, 1.0, 0.98)
		highlight_color = Color(170.0 / 255.0, 230.0 / 255.0, 1.0, 0.98)
	elif remaining_seconds > 2.5:
		base_color = Color(120.0 / 255.0, 230.0 / 255.0, 200.0 / 255.0, 0.98)
		highlight_color = Color(180.0 / 255.0, 250.0 / 255.0, 220.0 / 255.0, 0.98)
	else:
		var pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.015))
		base_color = Color((150.0 + 100.0 * pulse) / 255.0, (220.0 + 30.0 * pulse) / 255.0, 1.0, 0.99)
		highlight_color = Color((200.0 + 55.0 * pulse) / 255.0, (240.0 + 15.0 * pulse) / 255.0, 1.0, 0.99)

	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * ratio)
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, base_color)
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.34))), highlight_color)
	for i in range(1, 10):
		var tick_x: float = frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(i) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(160.0 / 255.0, 220.0 / 255.0, 1.0, 0.92),
			1.0
		)

	if fill_width > 2.0 and fill_width < frame_rect.size.x - 4.0:
		var glint_x: float = frame_rect.position.x + 2.0 + fill_width
		canvas.draw_line(
			Vector2(glint_x, frame_rect.position.y + 2.0),
			Vector2(glint_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(1.0, 1.0, 1.0, 0.46),
			2.0
		)

	var icon_size := Vector2(LONG_BOOST_TIMER_ICON_SIZE, LONG_BOOST_TIMER_ICON_SIZE) * 0.66
	var icon_top_left := frame_rect.position + Vector2(-icon_size.x - 6.0, 0.0)
	var icon_center := icon_top_left + icon_size * 0.5
	var icon_pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.01))
	canvas.draw_arc(icon_center, icon_size.x * 0.70, 0.0, TAU, 24, Color(150.0 / 255.0, 220.0 / 255.0, 1.0, 0.42 + 0.32 * icon_pulse), 2.0)
	var icon_texture: Texture2D = _get_dash_boost_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_top_left, icon_size), false)
	else:
		canvas.draw_circle(icon_center, icon_size.x * 0.42, Color(100.0 / 255.0, 200.0 / 255.0, 1.0, 1.0))


func _draw_vitamin_pill_timer_gauge(canvas: CanvasItem, timer_context: Dictionary, stack_index: int) -> void:
	var active: bool = bool(timer_context.get("active", false))
	var timer_frames: float = float(timer_context.get("timer_frames", 0.0))
	var initial_timer_frames: float = float(timer_context.get("initial_timer_frames", 0.0))
	if not active or timer_frames <= 0.0:
		return

	var ratio: float = clamp(timer_frames / max(1.0, initial_timer_frames), 0.0, 1.0)
	var remaining_seconds: float = timer_frames / 60.0
	var frame_rect := Rect2(_get_timer_bar_position(stack_index), LONG_BOOST_TIMER_BAR_SIZE)
	var outer_rect := frame_rect.grow(5.0)
	var mid_rect := frame_rect.grow(3.0)
	var border_rect := frame_rect.grow(2.0)
	canvas.draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_rect(outer_rect, Color(16.0 / 255.0, 22.0 / 255.0, 32.0 / 255.0, 0.94))
	canvas.draw_rect(mid_rect, Color(55.0 / 255.0, 85.0 / 255.0, 120.0 / 255.0, 0.96))
	canvas.draw_rect(mid_rect, Color(110.0 / 255.0, 150.0 / 255.0, 190.0 / 255.0, 0.92), false, 2.0)
	canvas.draw_rect(border_rect, Color(24.0 / 255.0, 28.0 / 255.0, 36.0 / 255.0, 0.96))
	canvas.draw_rect(frame_rect, Color(0.05, 0.07, 0.11, 0.94))

	var base_color: Color
	var highlight_color: Color
	if remaining_seconds > 6.0:
		base_color = Color(70.0 / 255.0, 170.0 / 255.0, 1.0, 0.98)
		highlight_color = Color(140.0 / 255.0, 210.0 / 255.0, 1.0, 0.98)
	elif remaining_seconds > 3.0:
		base_color = Color(80.0 / 255.0, 200.0 / 255.0, 230.0 / 255.0, 0.98)
		highlight_color = Color(160.0 / 255.0, 235.0 / 255.0, 245.0 / 255.0, 0.98)
	else:
		var pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.015))
		base_color = Color(1.0, (140.0 + 80.0 * pulse) / 255.0, 90.0 / 255.0, 0.99)
		highlight_color = Color(1.0, (190.0 + 50.0 * pulse) / 255.0, 120.0 / 255.0, 0.99)

	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * ratio)
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, base_color)
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.34))), highlight_color)
	for i in range(1, 10):
		var tick_x: float = frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(i) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(180.0 / 255.0, 200.0 / 255.0, 220.0 / 255.0, 0.92),
			1.0
		)

	if fill_width > 2.0 and fill_width < frame_rect.size.x - 4.0:
		var glint_x: float = frame_rect.position.x + 2.0 + fill_width
		canvas.draw_line(
			Vector2(glint_x, frame_rect.position.y + 2.0),
			Vector2(glint_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(1.0, 1.0, 1.0, 0.46),
			2.0
		)

	var icon_size := Vector2(LONG_BOOST_TIMER_ICON_SIZE, LONG_BOOST_TIMER_ICON_SIZE) * 0.68
	var icon_top_left := frame_rect.position + Vector2(-icon_size.x - 6.0, -1.0 + 1.0 * sin(float(Time.get_ticks_msec()) * 0.02))
	var icon_center := icon_top_left + icon_size * 0.5
	canvas.draw_circle(icon_center, icon_size.x * 0.62, Color(0.0, 0.0, 0.0, 0.38))
	canvas.draw_arc(icon_center, icon_size.x * 0.68, 0.0, TAU, 24, Color(120.0 / 255.0, 215.0 / 255.0, 1.0, 0.38), 2.0)
	var icon_texture: Texture2D = _get_vitamin_pill_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_top_left, icon_size), false)
	else:
		canvas.draw_circle(icon_center, icon_size.x * 0.40, Color(80.0 / 255.0, 170.0 / 255.0, 1.0, 1.0))
		canvas.draw_rect(Rect2(icon_center - Vector2(icon_size.x * 0.18, icon_size.y * 0.12), Vector2(icon_size.x * 0.36, icon_size.y * 0.24)), Color(1.0, 1.0, 1.0, 0.42))


func _draw_strange_vial_timer_gauge(canvas: CanvasItem, timer_context: Dictionary, stack_index: int) -> void:
	var active: bool = bool(timer_context.get("active", false))
	var timer_frames: float = float(timer_context.get("timer_frames", 0.0))
	var initial_timer_frames: float = float(timer_context.get("initial_timer_frames", 0.0))
	if not active or timer_frames <= 0.0:
		return

	var ratio: float = clamp(timer_frames / max(1.0, initial_timer_frames), 0.0, 1.0)
	var remaining_seconds: float = timer_frames / 60.0
	var effect_type: String = str(timer_context.get("effect_type", ""))
	var is_enlarge: bool = effect_type == "enlarge"
	var frame_rect := Rect2(_get_timer_bar_position(stack_index), LONG_BOOST_TIMER_BAR_SIZE)
	var outer_rect := frame_rect.grow(5.0)
	var mid_rect := frame_rect.grow(3.0)
	var border_rect := frame_rect.grow(2.0)
	var frame_color := Color(80.0 / 255.0, 30.0 / 255.0, 120.0 / 255.0, 0.94) if is_enlarge else Color(20.0 / 255.0, 80.0 / 255.0, 40.0 / 255.0, 0.94)
	var mid_color := Color(140.0 / 255.0, 60.0 / 255.0, 180.0 / 255.0, 0.96) if is_enlarge else Color(40.0 / 255.0, 160.0 / 255.0, 80.0 / 255.0, 0.96)
	var rim_color := Color(180.0 / 255.0, 100.0 / 255.0, 220.0 / 255.0, 0.92) if is_enlarge else Color(80.0 / 255.0, 220.0 / 255.0, 120.0 / 255.0, 0.92)
	canvas.draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.28))
	canvas.draw_rect(outer_rect, frame_color)
	canvas.draw_rect(mid_rect, mid_color)
	canvas.draw_rect(mid_rect, rim_color, false, 2.0)
	canvas.draw_rect(border_rect, Color(24.0 / 255.0, 18.0 / 255.0, 24.0 / 255.0, 0.96))
	canvas.draw_rect(frame_rect, Color(0.06, 0.04, 0.07, 0.94))

	var base_color: Color
	var highlight_color: Color
	if is_enlarge:
		if remaining_seconds > 6.0:
			base_color = Color(160.0 / 255.0, 80.0 / 255.0, 220.0 / 255.0, 0.98)
			highlight_color = Color(200.0 / 255.0, 120.0 / 255.0, 1.0, 0.98)
		elif remaining_seconds > 3.0:
			base_color = Color(180.0 / 255.0, 60.0 / 255.0, 200.0 / 255.0, 0.98)
			highlight_color = Color(220.0 / 255.0, 100.0 / 255.0, 240.0 / 255.0, 0.98)
		else:
			var pulse_purple: float = abs(sin(float(Time.get_ticks_msec()) * 0.015))
			base_color = Color((180.0 + 60.0 * pulse_purple) / 255.0, (60.0 + 40.0 * pulse_purple) / 255.0, (200.0 + 40.0 * pulse_purple) / 255.0, 0.99)
			highlight_color = Color((220.0 + 30.0 * pulse_purple) / 255.0, (100.0 + 40.0 * pulse_purple) / 255.0, (240.0 + 15.0 * pulse_purple) / 255.0, 0.99)
	else:
		if remaining_seconds > 6.0:
			base_color = Color(60.0 / 255.0, 200.0 / 255.0, 100.0 / 255.0, 0.98)
			highlight_color = Color(100.0 / 255.0, 240.0 / 255.0, 140.0 / 255.0, 0.98)
		elif remaining_seconds > 3.0:
			base_color = Color(40.0 / 255.0, 180.0 / 255.0, 80.0 / 255.0, 0.98)
			highlight_color = Color(80.0 / 255.0, 220.0 / 255.0, 120.0 / 255.0, 0.98)
		else:
			var pulse_green: float = abs(sin(float(Time.get_ticks_msec()) * 0.015))
			base_color = Color((40.0 + 40.0 * pulse_green) / 255.0, (180.0 + 60.0 * pulse_green) / 255.0, (80.0 + 40.0 * pulse_green) / 255.0, 0.99)
			highlight_color = Color((80.0 + 40.0 * pulse_green) / 255.0, (220.0 + 30.0 * pulse_green) / 255.0, (120.0 + 30.0 * pulse_green) / 255.0, 0.99)

	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * ratio)
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, base_color)
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.34))), highlight_color)
	if fill_width > 2.0 and fill_width < frame_rect.size.x - 4.0:
		var glint_x: float = frame_rect.position.x + 2.0 + fill_width
		canvas.draw_line(
			Vector2(glint_x, frame_rect.position.y + 2.0),
			Vector2(glint_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(1.0, 1.0, 1.0, 0.46),
			2.0
		)

	var icon_size := Vector2(LONG_BOOST_TIMER_ICON_SIZE, LONG_BOOST_TIMER_ICON_SIZE) * 0.70
	var icon_top_left := frame_rect.position + Vector2(-icon_size.x - 6.0, (frame_rect.size.y - icon_size.y) * 0.5)
	var icon_center := icon_top_left + icon_size * 0.5
	canvas.draw_circle(icon_center, icon_size.x * 0.62, Color(0.0, 0.0, 0.0, 0.38))
	canvas.draw_arc(icon_center, icon_size.x * 0.68, 0.0, TAU, 24, Color(rim_color.r, rim_color.g, rim_color.b, 0.42), 2.0)
	var icon_texture: Texture2D = _get_strange_vial_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_top_left, icon_size), false)
	else:
		canvas.draw_circle(icon_center, icon_size.x * 0.40, rim_color)
		canvas.draw_circle(icon_center + Vector2(-3.0, -4.0), icon_size.x * 0.12, Color(1.0, 1.0, 1.0, 0.36))


func _draw_long_boost_timer_gauge(canvas: CanvasItem, timer_context: Dictionary, stack_index: int) -> void:
	var active: bool = bool(timer_context.get("active", false))
	var timer_frames: float = float(timer_context.get("timer_frames", 0.0))
	var initial_timer_frames: float = float(timer_context.get("initial_timer_frames", 0.0))
	if not active or timer_frames <= 0.0:
		return

	var ratio: float = clamp(timer_frames / max(1.0, initial_timer_frames), 0.0, 1.0)
	var remaining_seconds: float = timer_frames / 60.0
	var bar_pos := _get_timer_bar_position(stack_index)
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


func _draw_magnet_field_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var alpha: float = clamp(float(particle.get("alpha", 1.0)), 0.0, 1.0)
	if alpha <= EFFECT_PARTICLE_ALPHA_CUTOFF:
		return
	var color: Color = _get_color(particle.get("color", Color(100.0 / 255.0, 150.0 / 255.0, 1.0, 1.0)), Color(100.0 / 255.0, 150.0 / 255.0, 1.0, 1.0))
	var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
	var radius: float = max(1.0, float(particle.get("radius", 3.0)))
	canvas.draw_circle(center, radius * 2.2, Color(color.r, color.g, color.b, 0.15 * alpha))
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, alpha))


func _draw_holy_barrier_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var alpha: float = clamp(float(particle.get("alpha", 1.0)), 0.0, 1.0)
	if alpha <= EFFECT_PARTICLE_ALPHA_CUTOFF:
		return
	var color: Color = _get_color(particle.get("color", Color(1.0, 1.0, 200.0 / 255.0, 1.0)), Color(1.0, 1.0, 200.0 / 255.0, 1.0))
	var radius: float = max(1.0, float(particle.get("radius", 3.0)))
	var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
	canvas.draw_circle(center, radius * 1.85, Color(color.r, color.g, color.b, 0.12 * alpha))
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, alpha))


func _draw_pickup_glow(canvas: CanvasItem, center: Vector2, alpha: float) -> void:
	for i in range(PICKUP_GLOW_RING_COUNT):
		var ratio: float = float(i) / float(max(1, PICKUP_GLOW_RING_COUNT))
		var radius: float = 40.0 * (1.0 - ratio)
		canvas.draw_circle(center, radius, Color(1.0, 1.0, 1.0, 0.10 * (1.0 - ratio) * alpha))
	canvas.draw_circle(center, 30.0, Color(30.0 / 255.0, 40.0 / 255.0, 60.0 / 255.0, 150.0 / 255.0 * alpha))
	canvas.draw_arc(center, 30.0, 0.0, TAU, PICKUP_GLOW_ARC_POINT_COUNT, Color(100.0 / 255.0, 150.0 / 255.0, 1.0, 150.0 / 255.0 * alpha), 2.0)


func _draw_clock_hand(canvas: CanvasItem, center: Vector2, angle: float, length: float, color: Color, width: float) -> void:
	var end_pos: Vector2 = center + Vector2(cos(angle - PI * 0.5), sin(angle - PI * 0.5)) * length
	canvas.draw_line(center, end_pos, color, width)


func _draw_polygon_outline(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	sides: int,
	rotation: float,
	color: Color,
	width: float
) -> void:
	if sides < 3 or radius <= 0.0:
		return
	var first_angle: float = rotation
	var first_point: Vector2 = center + Vector2(cos(first_angle), sin(first_angle)) * radius
	var previous_point: Vector2 = first_point
	for i in range(1, sides):
		var angle: float = rotation + TAU * float(i) / float(sides)
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		canvas.draw_line(previous_point, point, color, width)
		previous_point = point
	canvas.draw_line(previous_point, first_point, color, width)


func _draw_magnet_field_icon_fallback(canvas: CanvasItem, center: Vector2, size: float) -> void:
	var coil_radius: float = size * 0.36
	canvas.draw_arc(center, coil_radius, 0.0, TAU, 28, Color(80.0 / 255.0, 85.0 / 255.0, 100.0 / 255.0, 1.0), max(1.0, size * 0.10))
	canvas.draw_arc(center, coil_radius, 0.0, TAU, 28, Color(140.0 / 255.0, 150.0 / 255.0, 170.0 / 255.0, 1.0), max(1.0, size * 0.07))
	for i in range(6):
		var angle: float = float(i) * TAU / 6.0
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * (coil_radius - 1.0)
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * (coil_radius + 1.0)
		canvas.draw_line(inner, outer, Color(200.0 / 255.0, 210.0 / 255.0, 230.0 / 255.0, 1.0), 1.0)
	canvas.draw_circle(center, size * 0.24, Color(120.0 / 255.0, 80.0 / 255.0, 1.0, 0.24))
	canvas.draw_circle(center, size * 0.14, Color(160.0 / 255.0, 100.0 / 255.0, 1.0, 1.0))
	canvas.draw_circle(center, size * 0.08, Color(220.0 / 255.0, 180.0 / 255.0, 1.0, 1.0))


func _draw_centered_text(canvas: CanvasItem, text: String, baseline_center: Vector2, font_size: int, color: Color) -> void:
	if text == "":
		return
	var font: Font = _get_font()
	if font == null:
		return
	var text_size: Vector2 = _get_text_size(font, text, font_size)
	var pos := Vector2(baseline_center.x - text_size.x * 0.5, baseline_center.y)
	canvas.draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.65))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_item_icon_texture(item_data: Dictionary, registry: Object) -> Texture2D:
	var direct_texture = item_data.get("icon_texture", null)
	if direct_texture is Texture2D:
		return direct_texture as Texture2D
	var path: String = str(item_data.get("icon_path", ""))
	if path != "" and _pickup_icon_cache.has(path):
		var cached_texture = _pickup_icon_cache[path]
		if cached_texture is Texture2D:
			return cached_texture as Texture2D
	var visuals: Object = _get_instance(registry, "active_item_hud_visuals")
	if visuals != null and visuals.has_method("get_icon_texture"):
		var texture: Variant = visuals.get_icon_texture(item_data)
		if texture is Texture2D:
			if path != "":
				_pickup_icon_cache[path] = texture
			return texture
	return null


func _get_pickup_icon_texture(pickup_effect: Dictionary, registry: Object) -> Texture2D:
	var direct_texture = pickup_effect.get("icon_texture", null)
	if direct_texture is Texture2D:
		return direct_texture as Texture2D
	return _get_item_icon_texture(_get_dictionary(pickup_effect, "item_data"), registry)


func _get_long_boost_icon_texture() -> Texture2D:
	if long_boost_icon_texture == null:
		long_boost_icon_texture = ProjectResourceLoader.load_texture(
			LONG_BOOST_ICON_PATH,
			"Missing long boost icon at %s",
			"Failed to load long boost icon at %s"
		)
	return long_boost_icon_texture


func _get_vitamin_pill_icon_texture() -> Texture2D:
	if vitamin_pill_icon_texture == null:
		vitamin_pill_icon_texture = ProjectResourceLoader.load_texture(
			VITAMIN_PILL_ICON_PATH,
			"Missing vitamin pill icon at %s",
			"Failed to load vitamin pill icon at %s"
		)
	return vitamin_pill_icon_texture


func _get_strange_vial_icon_texture() -> Texture2D:
	if strange_vial_icon_texture == null:
		strange_vial_icon_texture = ProjectResourceLoader.load_texture(
			STRANGE_VIAL_ICON_PATH,
			"Missing strange vial icon at %s",
			"Failed to load strange vial icon at %s"
		)
	return strange_vial_icon_texture


func _get_magnet_field_icon_texture() -> Texture2D:
	if magnet_field_icon_texture == null:
		magnet_field_icon_texture = ProjectResourceLoader.load_texture(
			MAGNET_FIELD_ICON_PATH,
			"Missing magnet field icon at %s",
			"Failed to load magnet field icon at %s"
		)
	return magnet_field_icon_texture


func _get_holy_barrier_icon_texture() -> Texture2D:
	if holy_barrier_icon_texture == null:
		holy_barrier_icon_texture = ProjectResourceLoader.load_texture(
			HOLY_BARRIER_ICON_PATH,
			"Missing holy barrier icon at %s",
			"Failed to load holy barrier icon at %s"
		)
	return holy_barrier_icon_texture


func _get_dash_boost_icon_texture() -> Texture2D:
	if dash_boost_icon_texture == null:
		dash_boost_icon_texture = ProjectResourceLoader.load_texture(
			DASH_BOOST_ICON_PATH,
			"Missing dash boost icon at %s",
			"Failed to load dash boost icon at %s"
		)
	return dash_boost_icon_texture


func _get_brick_wall_variant_sheet_texture() -> Texture2D:
	brick_wall_variant_sheet_texture = _brick_wall_renderer.get_brick_wall_variant_sheet_texture()
	return brick_wall_variant_sheet_texture


func _get_brick_wall_variant_index(wall_rect: Rect2, visual_variant: int) -> int:
	return _brick_wall_renderer.get_brick_wall_variant_index(wall_rect, visual_variant)


func _get_brick_wall_variant_source_rect(sheet: Texture2D, variant_index: int) -> Rect2:
	return _brick_wall_renderer.get_brick_wall_variant_source_rect(sheet, variant_index)


func _prewarm_pickup_text() -> void:
	var font: Font = _get_font()
	if font == null:
		return
	_get_text_size(font, PICKUP_NOTICE_TEXT, PICKUP_NOTICE_FONT_SIZE)
	var active_catalog: Object = ActiveItemCatalog.new()
	_prewarm_catalog_pickup_text(font, active_catalog, ActiveItemCatalog.FIELD_SPAWN_ORDER)
	_prewarm_catalog_pickup_text(font, active_catalog, EXTRA_PICKUP_TEXT_PREWARM_ITEMS)
	var passive_mythic_catalog: Object = MythicItemCatalog.new()
	_prewarm_catalog_pickup_text(font, passive_mythic_catalog, MythicItemCatalog.FIELD_SPAWN_ORDER)


func _prewarm_catalog_pickup_text(font: Font, catalog: Object, item_names: Array) -> void:
	for item_name in item_names:
		_get_text_size(font, catalog.get_display_name(str(item_name)), PICKUP_DISPLAY_FONT_SIZE)


func _get_font() -> Font:
	if _font_cache == null:
		_font_cache = ThemeDB.fallback_font
	return _font_cache


func _get_text_size(font: Font, text: String, font_size: int) -> Vector2:
	var cache_key := "%d:%s" % [font_size, text]
	if _text_size_cache.has(cache_key):
		var cached_size: Variant = _text_size_cache[cache_key]
		if cached_size is Vector2:
			return cached_size
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	_text_size_cache[cache_key] = text_size
	return text_size


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()


func _get_timer_bar_position(stack_index: int) -> Vector2:
	return Vector2(
		FIELD_WIDTH - LONG_BOOST_TIMER_BAR_SIZE.x - LONG_BOOST_TIMER_BAR_MARGIN.x,
		FIELD_HEIGHT - LONG_BOOST_TIMER_BAR_MARGIN.y - float(max(0, stack_index)) * LONG_BOOST_TIMER_STACK_SPACING
	)


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


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _should_sample_detail(perf_logger: Object, label: String) -> bool:
	if perf_logger == null or not perf_logger.has_method("should_sample_detail"):
		return false
	return bool(perf_logger.should_sample_detail(label))
