extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")

const LONG_BOOST_ICON_PATH := ActiveItemCatalog.LONG_BOOST_ICON_PATH
const VITAMIN_PILL_ICON_PATH := ActiveItemCatalog.VITAMIN_PILL_ICON_PATH
const STRANGE_VIAL_ICON_PATH := ActiveItemCatalog.STRANGE_VIAL_ICON_PATH
const STOPWATCH_ICON_PATH := ActiveItemCatalog.STOPWATCH_ICON_PATH
const MAGNET_FIELD_ICON_PATH := ActiveItemCatalog.MAGNET_FIELD_ICON_PATH
const HOLY_BARRIER_ICON_PATH := ActiveItemCatalog.HOLY_BARRIER_ICON_PATH
const DASH_BOOST_ICON_PATH := "res://assets/sprites/items/dash_boost.png"
const BRICK_WALL_VARIANT_SHEET_PATH := "res://assets/sprites/effects/brick_wall_installed_variants_imagegen_v1.png"
const BRICK_WALL_VARIANT_GRID_COLS := 4
const BRICK_WALL_VARIANT_GRID_ROWS := 2
const BRICK_WALL_VARIANT_COUNT := BRICK_WALL_VARIANT_GRID_COLS * BRICK_WALL_VARIANT_GRID_ROWS
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
			_touch_texture(_get_brick_wall_variant_sheet_texture())
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
	var walls: Array = brick_wall_context.get("walls", [])
	for wall_value in walls:
		if not (wall_value is Dictionary):
			continue
		var wall: Dictionary = wall_value
		_draw_brick_wall(
			canvas,
			_get_rect2(wall, "rect", Rect2()),
			int(wall.get("crack_level", 0)),
			1.0,
			shake_offset,
			int(wall.get("visual_variant", -1)),
			int(wall.get("crack_seed", 0)),
			_get_vector2(wall, "crack_origin_ratio", Vector2(-1.0, -1.0))
		)

	if bool(brick_wall_context.get("installing", false)):
		var pending_wall: Dictionary = _get_dictionary(brick_wall_context, "pending_wall")
		var wall_rect: Rect2 = _get_rect2(pending_wall, "rect", Rect2())
		if wall_rect.size.x > 0.0 and wall_rect.size.y > 0.0:
			var timer_frames: float = float(brick_wall_context.get("install_timer_frames", 0.0))
			var initial_frames: float = max(1.0, float(brick_wall_context.get("install_initial_frames", 30.0)))
			var progress: float = clamp(1.0 - timer_frames / initial_frames, 0.0, 1.0)
			_draw_brick_wall(
				canvas,
				wall_rect,
				0,
				0.42 + progress * 0.30,
				shake_offset,
				int(pending_wall.get("visual_variant", -1))
			)
			_draw_brick_install_gauge(canvas, pending_wall, progress, shake_offset)

	var particles: Array = brick_wall_context.get("particles", [])
	for particle_value in particles:
		if particle_value is Dictionary:
			_draw_brick_particle(canvas, particle_value, shake_offset)


func _draw_brick_wall(
	canvas: CanvasItem,
	wall_rect: Rect2,
	crack_level: int,
	alpha: float,
	shake_offset: Vector2,
	visual_variant: int = -1,
	crack_seed: int = 0,
	crack_origin_ratio: Vector2 = Vector2(-1.0, -1.0)
) -> void:
	if wall_rect.size.x <= 0.0 or wall_rect.size.y <= 0.0:
		return

	var draw_rect := Rect2(wall_rect.position + shake_offset, wall_rect.size)
	var variant_sheet: Texture2D = _get_brick_wall_variant_sheet_texture()
	if variant_sheet != null:
		var variant_index: int = _get_brick_wall_variant_index(wall_rect, visual_variant)
		canvas.draw_texture_rect_region(
			variant_sheet,
			draw_rect,
			_get_brick_wall_variant_source_rect(variant_sheet, variant_index),
			Color(1.0, 1.0, 1.0, alpha)
		)
		_draw_brick_cracks(canvas, draw_rect, crack_level, alpha, crack_seed, crack_origin_ratio)
		return

	var base_color := Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0, alpha)
	if crack_level == 1:
		base_color = Color(120.0 / 255.0, 60.0 / 255.0, 30.0 / 255.0, alpha)
	elif crack_level >= 2:
		base_color = Color(90.0 / 255.0, 45.0 / 255.0, 25.0 / 255.0, alpha)

	canvas.draw_rect(draw_rect, Color(0.0, 0.0, 0.0, 0.22 * alpha))
	canvas.draw_rect(draw_rect, base_color)
	canvas.draw_line(draw_rect.position, draw_rect.position + Vector2(draw_rect.size.x, 0.0), Color(205.0 / 255.0, 130.0 / 255.0, 75.0 / 255.0, 0.78 * alpha), 2.0)
	canvas.draw_line(draw_rect.position, draw_rect.position + Vector2(0.0, draw_rect.size.y), Color(205.0 / 255.0, 130.0 / 255.0, 75.0 / 255.0, 0.58 * alpha), 1.0)
	canvas.draw_line(draw_rect.position + Vector2(0.0, draw_rect.size.y), draw_rect.end, Color(55.0 / 255.0, 25.0 / 255.0, 15.0 / 255.0, 0.76 * alpha), 2.0)
	canvas.draw_line(draw_rect.position + Vector2(draw_rect.size.x, 0.0), draw_rect.end, Color(55.0 / 255.0, 25.0 / 255.0, 15.0 / 255.0, 0.62 * alpha), 1.0)

	var mortar_color := Color(70.0 / 255.0, 35.0 / 255.0, 20.0 / 255.0, 0.74 * alpha)
	for row in range(1, 3):
		var y: float = draw_rect.position.y + draw_rect.size.y * float(row) / 3.0
		canvas.draw_line(Vector2(draw_rect.position.x, y), Vector2(draw_rect.end.x, y), mortar_color, 1.0)
	for col in range(1, 4):
		var x: float = draw_rect.position.x + draw_rect.size.x * float(col) / 4.0
		var y_offset: float = draw_rect.size.y / 3.0 if col % 2 == 0 else 0.0
		canvas.draw_line(Vector2(x, draw_rect.position.y + y_offset), Vector2(x, draw_rect.end.y), mortar_color, 1.0)

	canvas.draw_rect(draw_rect, Color(35.0 / 255.0, 18.0 / 255.0, 12.0 / 255.0, 0.88 * alpha), false, 2.0)
	_draw_brick_cracks(canvas, draw_rect, crack_level, alpha, crack_seed, crack_origin_ratio)


func _draw_brick_cracks(
	canvas: CanvasItem,
	draw_rect: Rect2,
	crack_level: int,
	alpha: float,
	crack_seed: int = 0,
	crack_origin_ratio: Vector2 = Vector2(-1.0, -1.0)
) -> void:
	if crack_level <= 0:
		return
	var seed_value: int = _get_brick_crack_seed(draw_rect, crack_level, crack_seed)
	var origin_ratio: Vector2 = _get_brick_crack_origin_ratio(seed_value, crack_origin_ratio)
	var origin := Vector2(
		draw_rect.position.x + draw_rect.size.x * origin_ratio.x,
		draw_rect.position.y + draw_rect.size.y * origin_ratio.y
	)
	var primary_sign := -1.0 if _brick_crack_random(seed_value, 1) < 0.5 else 1.0
	var primary_angle: float = (0.0 if primary_sign > 0.0 else PI) + lerpf(-0.34, 0.34, _brick_crack_random(seed_value, 2))
	var primary_length: float = draw_rect.size.x * lerpf(0.26, 0.42, _brick_crack_random(seed_value, 3))
	var primary_points: PackedVector2Array = _build_brick_crack_path(draw_rect, origin, primary_angle, primary_length, 5, seed_value, 10)
	_draw_brick_crack_polyline(canvas, primary_points, alpha, 1.45)

	var counter_angle: float = primary_angle + PI + lerpf(-0.26, 0.26, _brick_crack_random(seed_value, 4))
	var counter_length: float = draw_rect.size.x * lerpf(0.14, 0.25, _brick_crack_random(seed_value, 5))
	_draw_brick_crack_polyline(
		canvas,
		_build_brick_crack_path(draw_rect, origin, counter_angle, counter_length, 3, seed_value, 30),
		alpha,
		1.25
	)

	var branch_count: int = 4 + min(crack_level, 2) * 2
	for branch_index in range(branch_count):
		var branch_anchor: Vector2 = _pick_crack_branch_anchor(primary_points, branch_index, seed_value)
		var branch_side := -1.0 if branch_index % 2 == 0 else 1.0
		var branch_angle: float = primary_angle + branch_side * lerpf(0.7, 1.45, _brick_crack_random(seed_value, 50 + branch_index))
		if _brick_crack_random(seed_value, 70 + branch_index) < 0.32:
			branch_angle += PI
		var branch_length: float = draw_rect.size.x * lerpf(0.08, 0.18, _brick_crack_random(seed_value, 90 + branch_index))
		_draw_brick_crack_polyline(
			canvas,
			_build_brick_crack_path(draw_rect, branch_anchor, branch_angle, branch_length, 2 + branch_index % 2, seed_value, 110 + branch_index * 7),
			alpha,
			1.05
		)

	_draw_brick_crack_chips(canvas, draw_rect, origin, seed_value, crack_level, alpha)


func _build_brick_crack_path(
	draw_rect: Rect2,
	origin: Vector2,
	angle: float,
	length: float,
	segments: int,
	seed_value: int,
	salt: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(origin)
	var current: Vector2 = origin
	var segment_count: int = max(1, segments)
	for segment_index in range(segment_count):
		var jitter: float = lerpf(-0.42, 0.42, _brick_crack_random(seed_value, salt + segment_index * 3))
		var step_length: float = length / float(segment_count) * lerpf(0.72, 1.22, _brick_crack_random(seed_value, salt + segment_index * 3 + 1))
		current += Vector2(cos(angle + jitter), sin(angle + jitter)) * step_length
		current.x = clamp(current.x, draw_rect.position.x + 2.0, draw_rect.end.x - 2.0)
		current.y = clamp(current.y, draw_rect.position.y + 2.0, draw_rect.end.y - 2.0)
		points.append(current)
	return points


func _draw_brick_crack_polyline(canvas: CanvasItem, points: PackedVector2Array, alpha: float, width: float) -> void:
	if points.size() < 2:
		return
	var shadow_color := Color(9.0 / 255.0, 5.0 / 255.0, 3.0 / 255.0, 0.86 * alpha)
	var inner_color := Color(28.0 / 255.0, 14.0 / 255.0, 8.0 / 255.0, 0.94 * alpha)
	var highlight_color := Color(214.0 / 255.0, 124.0 / 255.0, 64.0 / 255.0, 0.22 * alpha)
	for point_index in range(points.size() - 1):
		canvas.draw_line(points[point_index], points[point_index + 1], shadow_color, width + 0.8)
	for point_index in range(points.size() - 1):
		canvas.draw_line(points[point_index], points[point_index + 1], inner_color, width)
	for point_index in range(points.size() - 1):
		canvas.draw_line(points[point_index] + Vector2(-0.45, -0.45), points[point_index + 1] + Vector2(-0.45, -0.45), highlight_color, max(0.55, width * 0.42))


func _draw_brick_crack_chips(
	canvas: CanvasItem,
	draw_rect: Rect2,
	origin: Vector2,
	seed_value: int,
	crack_level: int,
	alpha: float
) -> void:
	var chip_count: int = 3 + min(crack_level, 2) * 2
	for chip_index in range(chip_count):
		var chip_pos := origin + Vector2(
			lerpf(-draw_rect.size.x * 0.16, draw_rect.size.x * 0.16, _brick_crack_random(seed_value, 160 + chip_index * 2)),
			lerpf(-draw_rect.size.y * 0.34, draw_rect.size.y * 0.34, _brick_crack_random(seed_value, 161 + chip_index * 2))
		)
		chip_pos.x = clamp(chip_pos.x, draw_rect.position.x + 3.0, draw_rect.end.x - 3.0)
		chip_pos.y = clamp(chip_pos.y, draw_rect.position.y + 3.0, draw_rect.end.y - 3.0)
		var radius: float = lerpf(0.75, 1.75, _brick_crack_random(seed_value, 190 + chip_index))
		canvas.draw_circle(chip_pos, radius + 0.5, Color(12.0 / 255.0, 7.0 / 255.0, 4.0 / 255.0, 0.42 * alpha))
		canvas.draw_circle(chip_pos + Vector2(-0.25, -0.25), radius * 0.42, Color(210.0 / 255.0, 112.0 / 255.0, 52.0 / 255.0, 0.22 * alpha))


func _pick_crack_branch_anchor(points: PackedVector2Array, branch_index: int, seed_value: int) -> Vector2:
	if points.size() <= 1:
		return Vector2.ZERO
	var min_index: int = 1
	var max_index: int = maxi(1, points.size() - 2)
	var anchor_index: int = clampi(min_index + int(floor(_brick_crack_random(seed_value, 130 + branch_index) * float(max_index))), min_index, max_index)
	return points[anchor_index]


func _get_brick_crack_seed(draw_rect: Rect2, crack_level: int, crack_seed: int) -> int:
	if crack_seed > 0:
		return crack_seed
	return int(abs(round(draw_rect.position.x * 17.0 + draw_rect.position.y * 31.0 + draw_rect.size.x * 13.0 + float(crack_level) * 97.0))) + 1


func _get_brick_crack_origin_ratio(seed_value: int, crack_origin_ratio: Vector2) -> Vector2:
	if crack_origin_ratio.x >= 0.0 and crack_origin_ratio.y >= 0.0:
		return Vector2(
			clamp(crack_origin_ratio.x, 0.12, 0.88),
			clamp(crack_origin_ratio.y, 0.18, 0.82)
		)
	return Vector2(
		lerpf(0.26, 0.74, _brick_crack_random(seed_value, 210)),
		lerpf(0.26, 0.74, _brick_crack_random(seed_value, 211))
	)


func _brick_crack_random(seed_value: int, salt: int) -> float:
	var raw: float = sin(float(seed_value) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return fposmod(raw, 1.0)


func _draw_brick_install_gauge(
	canvas: CanvasItem,
	pending_wall: Dictionary,
	progress: float,
	shake_offset: Vector2
) -> void:
	var gauge_center: Vector2 = _get_vector2(pending_wall, "gauge_center", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 80.0)) + shake_offset
	var gauge_size := Vector2(80.0, 8.0)
	var gauge_rect := Rect2(gauge_center - gauge_size * 0.5, gauge_size)
	canvas.draw_rect(gauge_rect, Color(80.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0, 0.92))
	canvas.draw_rect(gauge_rect, Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0, 1.0), false, 2.0)
	var fill_color := Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0, 1.0)
	if progress >= 0.8:
		fill_color = Color(1.0, 220.0 / 255.0, 70.0 / 255.0, 1.0)
	elif progress >= 0.5:
		fill_color = Color(160.0 / 255.0, 82.0 / 255.0, 45.0 / 255.0, 1.0)
	var fill_width: float = max(0.0, (gauge_size.x - 4.0) * progress)
	if fill_width > 0.5:
		canvas.draw_rect(Rect2(gauge_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, gauge_size.y - 4.0)), fill_color)
	_draw_brick_hammer_icon(canvas, gauge_center + Vector2(55.0, 0.0), progress)


func _draw_brick_hammer_icon(canvas: CanvasItem, center: Vector2, progress: float) -> void:
	canvas.draw_circle(center, 12.0, Color(50.0 / 255.0, 50.0 / 255.0, 50.0 / 255.0, 0.94))
	canvas.draw_circle(center, 12.0, Color(100.0 / 255.0, 100.0 / 255.0, 100.0 / 255.0, 0.88), false, 2.0)
	var hammer_frame: int = int(progress * 30.0) % 20
	var angle_degrees: float = 0.0
	if hammer_frame < 5:
		angle_degrees = -45.0
	elif hammer_frame < 8:
		angle_degrees = 35.0
	elif hammer_frame >= 10 and hammer_frame < 15:
		angle_degrees = -35.0
	elif hammer_frame >= 15 and hammer_frame < 18:
		angle_degrees = 30.0
	var angle: float = deg_to_rad(angle_degrees - 90.0)
	var handle_end: Vector2 = center + Vector2(cos(angle), sin(angle)) * 8.0
	canvas.draw_line(center, handle_end, Color(101.0 / 255.0, 67.0 / 255.0, 33.0 / 255.0, 1.0), 2.0)
	var head_a: Vector2 = handle_end + Vector2(cos(angle + PI * 0.5), sin(angle + PI * 0.5)) * 4.0
	var head_b: Vector2 = handle_end + Vector2(cos(angle - PI * 0.5), sin(angle - PI * 0.5)) * 4.0
	canvas.draw_line(head_a, head_b, Color(165.0 / 255.0, 165.0 / 255.0, 165.0 / 255.0, 1.0), 5.0)
	canvas.draw_line(head_a, head_b, Color(90.0 / 255.0, 90.0 / 255.0, 90.0 / 255.0, 1.0), 1.0)
	if hammer_frame == 7 or hammer_frame == 17:
		canvas.draw_circle(center + Vector2(0.0, 6.0), 2.2, Color(1.0, 220.0 / 255.0, 100.0 / 255.0, 1.0))
	canvas.draw_line(center + Vector2(-2.0, 7.0), center + Vector2(2.0, 7.0), Color(80.0 / 255.0, 80.0 / 255.0, 80.0 / 255.0, 1.0), 2.0)


func _draw_brick_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var life: float = max(0.0, float(particle.get("life", 0.0)))
	var initial_life: float = max(1.0, float(particle.get("initial_life", life)))
	var life_ratio: float = clamp(life / initial_life, 0.0, 1.0)
	if life_ratio <= EFFECT_PARTICLE_ALPHA_CUTOFF:
		return
	var center: Vector2 = _get_vector2(particle, "position", Vector2.ZERO) + shake_offset
	var color: Color = _get_color(particle.get("color", Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0, 1.0)), Color(139.0 / 255.0, 69.0 / 255.0, 19.0 / 255.0, 1.0))
	if str(particle.get("kind", "dust")) == "brick":
		_draw_brick_fragment_particle(canvas, center, particle, color, life_ratio)
		return
	var radius: float = max(1.0, float(particle.get("radius", 3.0))) * (0.65 + life_ratio * 0.35)
	canvas.draw_circle(center, radius * 1.8, Color(color.r, color.g, color.b, 0.10 * life_ratio))
	canvas.draw_circle(center, radius, Color(color.r, color.g, color.b, 0.62 * life_ratio))


func _draw_brick_fragment_particle(
	canvas: CanvasItem,
	center: Vector2,
	particle: Dictionary,
	color: Color,
	life_ratio: float
) -> void:
	var size: Vector2 = _get_vector2(particle, "size", Vector2(6.0, 4.0))
	var rotation: float = float(particle.get("rotation", 0.0))
	var draw_color := Color(color.r, color.g, color.b, 0.92 * life_ratio)
	var outline_color := Color(45.0 / 255.0, 22.0 / 255.0, 12.0 / 255.0, 0.55 * life_ratio)
	var half_size: Vector2 = size * 0.5
	var local_corners := [
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]
	var points := PackedVector2Array()
	for corner in local_corners:
		points.append(_rotated_local(center, corner, rotation))
	canvas.draw_colored_polygon(points, draw_color)
	for i in range(points.size()):
		canvas.draw_line(points[i], points[(i + 1) % points.size()], outline_color, 1.0)


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
	if brick_wall_variant_sheet_texture == null:
		brick_wall_variant_sheet_texture = ProjectResourceLoader.load_texture(
			BRICK_WALL_VARIANT_SHEET_PATH,
			"Missing brick wall variant sheet at %s",
			"Failed to load brick wall variant sheet at %s"
		)
	return brick_wall_variant_sheet_texture


func _get_brick_wall_variant_index(wall_rect: Rect2, visual_variant: int) -> int:
	if visual_variant >= 0:
		return visual_variant % BRICK_WALL_VARIANT_COUNT
	var fallback_seed: int = int(round(wall_rect.position.x * 7.0 + wall_rect.position.y * 3.0 + wall_rect.size.x * 5.0))
	return int(abs(fallback_seed)) % BRICK_WALL_VARIANT_COUNT


func _get_brick_wall_variant_source_rect(sheet: Texture2D, variant_index: int) -> Rect2:
	var texture_size: Vector2 = sheet.get_size()
	var cell_size := Vector2(
		texture_size.x / float(BRICK_WALL_VARIANT_GRID_COLS),
		texture_size.y / float(BRICK_WALL_VARIANT_GRID_ROWS)
	)
	var clamped_index: int = clampi(variant_index, 0, BRICK_WALL_VARIANT_COUNT - 1)
	var source_col: int = clamped_index % BRICK_WALL_VARIANT_GRID_COLS
	var source_row: int = int(floor(float(clamped_index) / float(BRICK_WALL_VARIANT_GRID_COLS)))
	return Rect2(
		Vector2(float(source_col) * cell_size.x, float(source_row) * cell_size.y),
		cell_size
	)


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


func _rotated_local(center: Vector2, local: Vector2, angle: float) -> Vector2:
	return center + Vector2(
		local.x * cos(angle) - local.y * sin(angle),
		local.x * sin(angle) + local.y * cos(angle)
	)


func _get_rect2(source: Dictionary, key: String, fallback: Rect2) -> Rect2:
	var value: Variant = source.get(key, fallback)
	if value is Rect2:
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
