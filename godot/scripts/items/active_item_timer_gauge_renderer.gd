extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")

const LONG_BOOST_ICON_PATH := ActiveItemCatalog.LONG_BOOST_ICON_PATH
const DOPING_POTION_ICON_PATH := ActiveItemCatalog.DOPING_POTION_ICON_PATH
const VITAMIN_PILL_ICON_PATH := ActiveItemCatalog.VITAMIN_PILL_ICON_PATH
const STRANGE_VIAL_ICON_PATH := ActiveItemCatalog.STRANGE_VIAL_ICON_PATH
const MAGNET_FIELD_ICON_PATH := ActiveItemCatalog.MAGNET_FIELD_ICON_PATH
const HOLOGRAM_DISK_ICON_PATH := ActiveItemCatalog.HOLOGRAM_DISK_ICON_PATH
const HOLY_BARRIER_ICON_PATH := ActiveItemCatalog.HOLY_BARRIER_ICON_PATH
const DASH_BOOST_ICON_PATH := "res://assets/sprites/items/dash_boost.png"
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const LONG_BOOST_TIMER_BAR_SIZE := Vector2(150.0, 12.0)
const LONG_BOOST_TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const LONG_BOOST_TIMER_STACK_SPACING := 18.0
const LONG_BOOST_TIMER_ICON_SIZE := 28.0

var long_boost_icon_texture: Texture2D
var doping_potion_icon_texture: Texture2D
var vitamin_pill_icon_texture: Texture2D
var strange_vial_icon_texture: Texture2D
var magnet_field_icon_texture: Texture2D
var hologram_disk_icon_texture: Texture2D
var holy_barrier_icon_texture: Texture2D
var dash_boost_icon_texture: Texture2D


func prewarm_assets() -> void:
	_touch_texture(get_long_boost_icon_texture())
	_touch_texture(get_doping_potion_icon_texture())
	_touch_texture(get_vitamin_pill_icon_texture())
	_touch_texture(get_strange_vial_icon_texture())
	_touch_texture(get_magnet_field_icon_texture())
	_touch_texture(get_hologram_disk_icon_texture())
	_touch_texture(get_holy_barrier_icon_texture())
	_touch_texture(get_dash_boost_icon_texture())


func draw_magnet_field_timer_gauge(canvas: CanvasItem, timer_context: Dictionary, stack_index: int) -> void:
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
	var icon_texture: Texture2D = get_magnet_field_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_top_left, icon_size), false)
	else:
		_draw_magnet_field_icon_fallback(canvas, icon_center, icon_size.x)


func draw_hologram_disk_timer_gauge(canvas: CanvasItem, timer_context: Dictionary, stack_index: int) -> void:
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
	canvas.draw_rect(outer_rect, Color(12.0 / 255.0, 38.0 / 255.0, 54.0 / 255.0, 0.94))
	canvas.draw_rect(mid_rect, Color(38.0 / 255.0, 132.0 / 255.0, 158.0 / 255.0, 0.96))
	canvas.draw_rect(mid_rect, Color(1.0, 80.0 / 255.0, 220.0 / 255.0, 0.88), false, 2.0)
	canvas.draw_rect(border_rect, Color(12.0 / 255.0, 28.0 / 255.0, 42.0 / 255.0, 0.96))
	canvas.draw_rect(frame_rect, Color(0.03, 0.08, 0.11, 0.94))

	var base_color: Color
	var highlight_color: Color
	if remaining_seconds > 5.0:
		base_color = Color(0.35, 0.90, 1.0, 0.98)
		highlight_color = Color(0.78, 1.0, 1.0, 0.98)
	elif remaining_seconds > 3.0:
		base_color = Color(0.45, 0.78, 1.0, 0.98)
		highlight_color = Color(0.95, 0.70, 1.0, 0.98)
	else:
		var pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.017))
		base_color = Color(0.35 + 0.25 * pulse, 0.70 + 0.22 * pulse, 1.0, 0.99)
		highlight_color = Color(1.0, 0.55 + 0.28 * pulse, 1.0, 0.99)

	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * ratio)
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, base_color)
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.34))), highlight_color)
	for i in range(1, 10):
		var tick_x: float = frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(i) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(150.0 / 255.0, 230.0 / 255.0, 1.0, 0.90),
			1.0
		)

	if fill_width > 2.0 and fill_width < frame_rect.size.x - 4.0:
		var glint_x: float = frame_rect.position.x + 2.0 + fill_width
		canvas.draw_line(
			Vector2(glint_x, frame_rect.position.y + 2.0),
			Vector2(glint_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(1.0, 1.0, 1.0, 0.48),
			2.0
		)

	var icon_size := Vector2(LONG_BOOST_TIMER_ICON_SIZE, LONG_BOOST_TIMER_ICON_SIZE) * 0.66
	var icon_top_left := frame_rect.position + Vector2(-icon_size.x - 6.0, 0.0)
	var icon_center := icon_top_left + icon_size * 0.5
	var icon_pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.012))
	canvas.draw_arc(icon_center, icon_size.x * 0.72, 0.0, TAU, 24, Color(0.35, 0.9, 1.0, 0.42 + 0.30 * icon_pulse), 2.0)
	canvas.draw_arc(icon_center, icon_size.x * 0.52, 0.0, TAU, 20, Color(1.0, 0.45, 1.0, 0.28 + 0.24 * icon_pulse), 1.5)
	var icon_texture: Texture2D = get_hologram_disk_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_top_left, icon_size), false)
	else:
		_draw_hologram_disk_icon_fallback(canvas, icon_center, icon_size.x)


func draw_doping_potion_timer_gauge(canvas: CanvasItem, timer_context: Dictionary, stack_index: int) -> void:
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
	canvas.draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.30))
	canvas.draw_rect(outer_rect, Color(52.0 / 255.0, 18.0 / 255.0, 18.0 / 255.0, 0.94))
	canvas.draw_rect(mid_rect, Color(155.0 / 255.0, 48.0 / 255.0, 32.0 / 255.0, 0.96))
	canvas.draw_rect(mid_rect, Color(1.0, 125.0 / 255.0, 75.0 / 255.0, 0.92), false, 2.0)
	canvas.draw_rect(border_rect, Color(34.0 / 255.0, 18.0 / 255.0, 18.0 / 255.0, 0.96))
	canvas.draw_rect(frame_rect, Color(0.11, 0.035, 0.035, 0.94))

	var base_color: Color
	var highlight_color: Color
	if remaining_seconds > 5.0:
		base_color = Color(1.0, 110.0 / 255.0, 45.0 / 255.0, 0.98)
		highlight_color = Color(1.0, 170.0 / 255.0, 95.0 / 255.0, 0.98)
	elif remaining_seconds > 2.5:
		base_color = Color(1.0, 80.0 / 255.0, 60.0 / 255.0, 0.98)
		highlight_color = Color(1.0, 140.0 / 255.0, 90.0 / 255.0, 0.98)
	else:
		var pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.017))
		base_color = Color(1.0, (55.0 + 95.0 * pulse) / 255.0, (40.0 + 40.0 * pulse) / 255.0, 0.99)
		highlight_color = Color(1.0, (110.0 + 70.0 * pulse) / 255.0, (70.0 + 50.0 * pulse) / 255.0, 0.99)

	var fill_width: float = max(1.0, (frame_rect.size.x - 4.0) * ratio)
	var fill_rect := Rect2(frame_rect.position + Vector2(2.0, 2.0), Vector2(fill_width, frame_rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, base_color)
	canvas.draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, max(2.0, fill_rect.size.y * 0.34))), highlight_color)
	for i in range(1, 10):
		var tick_x: float = frame_rect.position.x + 2.0 + (frame_rect.size.x - 4.0) * (float(i) / 10.0)
		canvas.draw_line(
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 4.0),
			Vector2(tick_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(1.0, 160.0 / 255.0, 110.0 / 255.0, 0.92),
			1.0
		)

	if fill_width > 2.0 and fill_width < frame_rect.size.x - 4.0:
		var glint_x: float = frame_rect.position.x + 2.0 + fill_width
		canvas.draw_line(
			Vector2(glint_x, frame_rect.position.y + 2.0),
			Vector2(glint_x, frame_rect.position.y + frame_rect.size.y - 1.0),
			Color(1.0, 1.0, 1.0, 0.48),
			2.0
		)

	var icon_size := Vector2(LONG_BOOST_TIMER_ICON_SIZE, LONG_BOOST_TIMER_ICON_SIZE) * 0.70
	var icon_top_left := frame_rect.position + Vector2(-icon_size.x - 6.0, (frame_rect.size.y - icon_size.y) * 0.5)
	var icon_center := icon_top_left + icon_size * 0.5
	var icon_pulse: float = abs(sin(float(Time.get_ticks_msec()) * 0.012))
	canvas.draw_circle(icon_center, icon_size.x * 0.62, Color(0.0, 0.0, 0.0, 0.38))
	canvas.draw_arc(icon_center, icon_size.x * 0.70, 0.0, TAU, 24, Color(1.0, 120.0 / 255.0, 80.0 / 255.0, 0.42 + 0.32 * icon_pulse), 2.0)
	var icon_texture: Texture2D = get_doping_potion_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_top_left, icon_size), false)
	else:
		canvas.draw_circle(icon_center, icon_size.x * 0.38, Color(1.0, 75.0 / 255.0, 55.0 / 255.0, 1.0))
		canvas.draw_line(icon_center + Vector2(-5.0, 5.0), icon_center + Vector2(6.0, -6.0), Color(1.0, 235.0 / 255.0, 170.0 / 255.0, 0.9), 2.0)


func draw_holy_barrier_timer_gauge(canvas: CanvasItem, timer_context: Dictionary, stack_index: int) -> void:
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
	var icon_texture: Texture2D = get_holy_barrier_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_top_left, icon_size), false)
	else:
		canvas.draw_circle(icon_center, icon_size.x * 0.42, Color(1.0, 245.0 / 255.0, 170.0 / 255.0, 1.0))


func draw_dash_boost_timer_gauge(canvas: CanvasItem, timer_context: Dictionary, stack_index: int) -> void:
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
	var icon_texture: Texture2D = get_dash_boost_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_top_left, icon_size), false)
	else:
		canvas.draw_circle(icon_center, icon_size.x * 0.42, Color(100.0 / 255.0, 200.0 / 255.0, 1.0, 1.0))


func draw_vitamin_pill_timer_gauge(canvas: CanvasItem, timer_context: Dictionary, stack_index: int) -> void:
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
	var icon_texture: Texture2D = get_vitamin_pill_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_top_left, icon_size), false)
	else:
		canvas.draw_circle(icon_center, icon_size.x * 0.40, Color(80.0 / 255.0, 170.0 / 255.0, 1.0, 1.0))
		canvas.draw_rect(Rect2(icon_center - Vector2(icon_size.x * 0.18, icon_size.y * 0.12), Vector2(icon_size.x * 0.36, icon_size.y * 0.24)), Color(1.0, 1.0, 1.0, 0.42))


func draw_strange_vial_timer_gauge(canvas: CanvasItem, timer_context: Dictionary, stack_index: int) -> void:
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
	var icon_texture: Texture2D = get_strange_vial_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_top_left, icon_size), false)
	else:
		canvas.draw_circle(icon_center, icon_size.x * 0.40, rim_color)
		canvas.draw_circle(icon_center + Vector2(-3.0, -4.0), icon_size.x * 0.12, Color(1.0, 1.0, 1.0, 0.36))


func draw_long_boost_timer_gauge(canvas: CanvasItem, timer_context: Dictionary, stack_index: int) -> void:
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
	var icon_texture: Texture2D = get_long_boost_icon_texture()
	if icon_texture != null:
		canvas.draw_texture_rect(icon_texture, Rect2(icon_center - icon_size * 0.5, icon_size), false)
	else:
		canvas.draw_circle(icon_center, icon_size.x * 0.40, Color(100.0 / 255.0, 200.0 / 255.0, 1.0, 1.0))
		canvas.draw_circle(icon_center + Vector2(-4.0, -5.0), icon_size.x * 0.12, Color(1.0, 1.0, 1.0, 0.36))


func get_long_boost_icon_texture() -> Texture2D:
	if long_boost_icon_texture == null:
		long_boost_icon_texture = ProjectResourceLoader.load_texture(
			LONG_BOOST_ICON_PATH,
			"Missing long boost icon at %s",
			"Failed to load long boost icon at %s"
		)
	return long_boost_icon_texture


func get_doping_potion_icon_texture() -> Texture2D:
	if doping_potion_icon_texture == null:
		doping_potion_icon_texture = ProjectResourceLoader.load_texture(
			DOPING_POTION_ICON_PATH,
			"Missing doping potion icon at %s",
			"Failed to load doping potion icon at %s"
		)
	return doping_potion_icon_texture


func get_vitamin_pill_icon_texture() -> Texture2D:
	if vitamin_pill_icon_texture == null:
		vitamin_pill_icon_texture = ProjectResourceLoader.load_texture(
			VITAMIN_PILL_ICON_PATH,
			"Missing vitamin pill icon at %s",
			"Failed to load vitamin pill icon at %s"
		)
	return vitamin_pill_icon_texture


func get_strange_vial_icon_texture() -> Texture2D:
	if strange_vial_icon_texture == null:
		strange_vial_icon_texture = ProjectResourceLoader.load_texture(
			STRANGE_VIAL_ICON_PATH,
			"Missing strange vial icon at %s",
			"Failed to load strange vial icon at %s"
		)
	return strange_vial_icon_texture


func get_magnet_field_icon_texture() -> Texture2D:
	if magnet_field_icon_texture == null:
		magnet_field_icon_texture = ProjectResourceLoader.load_texture(
			MAGNET_FIELD_ICON_PATH,
			"Missing magnet field icon at %s",
			"Failed to load magnet field icon at %s"
		)
	return magnet_field_icon_texture


func get_hologram_disk_icon_texture() -> Texture2D:
	if hologram_disk_icon_texture == null:
		hologram_disk_icon_texture = ProjectResourceLoader.load_texture(
			HOLOGRAM_DISK_ICON_PATH,
			"Missing hologram disk icon at %s",
			"Failed to load hologram disk icon at %s"
		)
	return hologram_disk_icon_texture


func get_holy_barrier_icon_texture() -> Texture2D:
	if holy_barrier_icon_texture == null:
		holy_barrier_icon_texture = ProjectResourceLoader.load_texture(
			HOLY_BARRIER_ICON_PATH,
			"Missing holy barrier icon at %s",
			"Failed to load holy barrier icon at %s"
		)
	return holy_barrier_icon_texture


func get_dash_boost_icon_texture() -> Texture2D:
	if dash_boost_icon_texture == null:
		dash_boost_icon_texture = ProjectResourceLoader.load_texture(
			DASH_BOOST_ICON_PATH,
			"Missing dash boost icon at %s",
			"Failed to load dash boost icon at %s"
		)
	return dash_boost_icon_texture


func _get_timer_bar_position(stack_index: int) -> Vector2:
	return Vector2(
		FIELD_WIDTH - LONG_BOOST_TIMER_BAR_SIZE.x - LONG_BOOST_TIMER_BAR_MARGIN.x,
		FIELD_HEIGHT - LONG_BOOST_TIMER_BAR_MARGIN.y - float(max(0, stack_index)) * LONG_BOOST_TIMER_STACK_SPACING
	)


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


func _draw_hologram_disk_icon_fallback(canvas: CanvasItem, center: Vector2, size: float) -> void:
	canvas.draw_circle(center, size * 0.40, Color(0.0, 0.0, 0.0, 0.34))
	canvas.draw_arc(center, size * 0.36, 0.0, TAU, 28, Color(0.35, 0.9, 1.0, 1.0), max(1.0, size * 0.08))
	canvas.draw_arc(center, size * 0.24, 0.0, TAU, 24, Color(1.0, 0.45, 1.0, 0.9), max(1.0, size * 0.05))
	canvas.draw_circle(center, size * 0.10, Color(0.78, 1.0, 1.0, 1.0))


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()
