extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const BrickWallEffectRenderer := preload("res://scripts/items/active_item_brick_wall_effect_renderer.gd")
const TrampolineRenderer := preload("res://scripts/items/active_item_trampoline_renderer.gd")
const TimerGaugeRenderer := preload("res://scripts/items/active_item_timer_gauge_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PICKUP_ICON_SIZE := 40.0
const PICKUP_DISPLAY_FONT_SIZE := 16
const PICKUP_NOTICE_FONT_SIZE := 14
const PICKUP_NOTICE_TEXT := "획득!"
const PICKUP_USE_HINT_TEXT_FORMAT := "%d번 키로 사용"
const PICKUP_USE_HINT_PREWARM_SLOT_COUNT := 9
const PICKUP_GLOW_RING_COUNT := 2
const PICKUP_GLOW_ARC_POINT_COUNT := 18
const MAX_PICKUP_PARTICLE_RENDER_COUNT := 28
const EXTRA_PICKUP_TEXT_PREWARM_ITEMS := [
	"ammo_box",
	"doping_potion",
	"elixir_of_mastery",
]
const REGENERATION_POTION_PARTICLE_DURATION_SEC := 0.78
const REGENERATION_POTION_RING_DURATION_SEC := 0.58
const EFFECT_PARTICLE_ALPHA_CUTOFF := 0.02
const STOPWATCH_FACE_NUMBERS := ["12", "3", "6", "9"]
# 홀로그램 분신 = 진짜 에너지볼 레이어를 같은 텍스처 캐시로 미러링하되
# 전체 알파만 낮춘 반투명 버전. 단일 레버로 투명도를 튠한다.

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
var _trampoline_renderer: Object = TrampolineRenderer.new()
var _timer_gauge_renderer: Object = TimerGaugeRenderer.new()


func prewarm_assets(active_item_hud_visuals: Object = null) -> void:
	while not prewarm_assets_step(active_item_hud_visuals):
		pass


func prewarm_assets_step(active_item_hud_visuals: Object = null) -> bool:
	match _prewarm_step_index:
		0:
			if ResourceLoader.exists(TimerGaugeRenderer.LONG_BOOST_ICON_PATH):
				_touch_texture(_get_long_boost_icon_texture())
		1:
			if ResourceLoader.exists(TimerGaugeRenderer.VITAMIN_PILL_ICON_PATH):
				_touch_texture(_get_vitamin_pill_icon_texture())
		2:
			if ResourceLoader.exists(TimerGaugeRenderer.STRANGE_VIAL_ICON_PATH):
				_touch_texture(_get_strange_vial_icon_texture())
		3:
			if ResourceLoader.exists(TimerGaugeRenderer.DOPING_POTION_ICON_PATH):
				_touch_texture(_get_doping_potion_icon_texture())
		4:
			if ResourceLoader.exists(TimerGaugeRenderer.MAGNET_FIELD_ICON_PATH):
				_touch_texture(_get_magnet_field_icon_texture())
		5:
			if ResourceLoader.exists(TimerGaugeRenderer.HOLY_BARRIER_ICON_PATH):
				_touch_texture(_get_holy_barrier_icon_texture())
		6:
			if ResourceLoader.exists(TimerGaugeRenderer.DASH_BOOST_ICON_PATH):
				_touch_texture(_get_dash_boost_icon_texture())
		7:
			_brick_wall_renderer.prewarm_assets()
			brick_wall_variant_sheet_texture = _brick_wall_renderer.brick_wall_variant_sheet_texture
			_trampoline_renderer.prewarm_assets()
		8:
			if active_item_hud_visuals != null and active_item_hud_visuals.has_method("prewarm_catalog_icons_step"):
				if not bool(active_item_hud_visuals.prewarm_catalog_icons_step()):
					return false
			elif active_item_hud_visuals != null and active_item_hud_visuals.has_method("prewarm_catalog_icons"):
				active_item_hud_visuals.prewarm_catalog_icons()
		9:
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
	perf_logger: Object = null,
	doping_potion_context: Dictionary = {}
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
		_timer_gauge_renderer.draw_magnet_field_timer_gauge(canvas, magnet_field_context, timer_stack_index)
		_perf_end(detail_perf_logger, "active_item.field.timer_magnet", sample_start)
		if not has_shared_timer_stack:
			timer_stack_index += 1
	if bool(holy_barrier_context.get("active", false)):
		if has_shared_timer_stack:
			timer_stack_index = int(timer_stack.claim("holy_barrier", true))
		sample_start = _perf_begin(detail_perf_logger)
		_timer_gauge_renderer.draw_holy_barrier_timer_gauge(canvas, holy_barrier_context, timer_stack_index)
		_perf_end(detail_perf_logger, "active_item.field.timer_holy_barrier", sample_start)
		if not has_shared_timer_stack:
			timer_stack_index += 1
	if bool(vitamin_pill_timer_context.get("active", false)):
		if has_shared_timer_stack:
			timer_stack_index = int(timer_stack.claim("vitamin_pill", true))
		sample_start = _perf_begin(detail_perf_logger)
		_timer_gauge_renderer.draw_vitamin_pill_timer_gauge(canvas, vitamin_pill_timer_context, timer_stack_index)
		_perf_end(detail_perf_logger, "active_item.field.timer_vitamin_pill", sample_start)
		if not has_shared_timer_stack:
			timer_stack_index += 1
	if bool(strange_vial_timer_context.get("active", false)):
		if has_shared_timer_stack:
			timer_stack_index = int(timer_stack.claim("strange_vial", true))
		sample_start = _perf_begin(detail_perf_logger)
		_timer_gauge_renderer.draw_strange_vial_timer_gauge(canvas, strange_vial_timer_context, timer_stack_index)
		_perf_end(detail_perf_logger, "active_item.field.timer_strange_vial", sample_start)
		if not has_shared_timer_stack:
			timer_stack_index += 1
	if bool(doping_potion_context.get("active", false)):
		if has_shared_timer_stack:
			timer_stack_index = int(timer_stack.claim("doping_potion", true))
		sample_start = _perf_begin(detail_perf_logger)
		_timer_gauge_renderer.draw_doping_potion_timer_gauge(canvas, doping_potion_context, timer_stack_index)
		_perf_end(detail_perf_logger, "active_item.field.timer_doping_potion", sample_start)
		if not has_shared_timer_stack:
			timer_stack_index += 1
	if bool(long_boost_timer_context.get("active", false)):
		if has_shared_timer_stack:
			timer_stack_index = int(timer_stack.claim("long_boost", true))
		sample_start = _perf_begin(detail_perf_logger)
		_timer_gauge_renderer.draw_long_boost_timer_gauge(canvas, long_boost_timer_context, timer_stack_index)
		_perf_end(detail_perf_logger, "active_item.field.timer_long_boost", sample_start)
		if not has_shared_timer_stack:
			timer_stack_index += 1
	if bool(dash_boost_context.get("active", false)):
		if has_shared_timer_stack:
			timer_stack_index = int(timer_stack.claim("dash_boost", true))
		sample_start = _perf_begin(detail_perf_logger)
		_timer_gauge_renderer.draw_dash_boost_timer_gauge(canvas, dash_boost_context, timer_stack_index)
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
	var notice_text: String = _get_pickup_notice_text(pickup_effect)
	sample_start = _perf_begin(detail_perf_logger)
	_draw_centered_text(canvas, item_name, center + Vector2(0.0, 54.0), PICKUP_DISPLAY_FONT_SIZE, Color(1.0, 1.0, 1.0, alpha))
	_draw_centered_text(canvas, notice_text, center + Vector2(0.0, 70.0), PICKUP_NOTICE_FONT_SIZE, Color(1.0, 215.0 / 255.0, 0.0, alpha))


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


func draw_trampoline_effect(canvas: CanvasItem, trampoline_context: Dictionary, shake_offset: Vector2) -> void:
	_trampoline_renderer.draw_trampoline_effect(canvas, trampoline_context, shake_offset)


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


func _get_pickup_notice_text(pickup_effect: Dictionary) -> String:
	var use_hint_text: String = str(pickup_effect.get("use_hint_text", "")).strip_edges()
	if use_hint_text != "":
		return use_hint_text
	return LanguageSettings.translate_text(PICKUP_NOTICE_TEXT)


func _get_long_boost_icon_texture() -> Texture2D:
	long_boost_icon_texture = _timer_gauge_renderer.get_long_boost_icon_texture()
	return long_boost_icon_texture


func _get_doping_potion_icon_texture() -> Texture2D:
	return _timer_gauge_renderer.get_doping_potion_icon_texture()


func _get_vitamin_pill_icon_texture() -> Texture2D:
	vitamin_pill_icon_texture = _timer_gauge_renderer.get_vitamin_pill_icon_texture()
	return vitamin_pill_icon_texture


func _get_strange_vial_icon_texture() -> Texture2D:
	strange_vial_icon_texture = _timer_gauge_renderer.get_strange_vial_icon_texture()
	return strange_vial_icon_texture


func _get_magnet_field_icon_texture() -> Texture2D:
	magnet_field_icon_texture = _timer_gauge_renderer.get_magnet_field_icon_texture()
	return magnet_field_icon_texture


func _get_holy_barrier_icon_texture() -> Texture2D:
	holy_barrier_icon_texture = _timer_gauge_renderer.get_holy_barrier_icon_texture()
	return holy_barrier_icon_texture


func _get_dash_boost_icon_texture() -> Texture2D:
	dash_boost_icon_texture = _timer_gauge_renderer.get_dash_boost_icon_texture()
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
	_get_text_size(font, LanguageSettings.translate_text(PICKUP_NOTICE_TEXT), PICKUP_NOTICE_FONT_SIZE)
	for slot_number in range(1, PICKUP_USE_HINT_PREWARM_SLOT_COUNT + 1):
		_get_text_size(font, PICKUP_USE_HINT_TEXT_FORMAT % [slot_number], PICKUP_NOTICE_FONT_SIZE)
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
