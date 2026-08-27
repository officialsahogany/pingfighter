extends RefCounted

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const ICON_PATH := ActiveItemCatalog.STOPWATCH_ICON_PATH
const FIELD_SIZE := Vector2(760.0, 750.0)
const WATCH_CENTER := Vector2(380.0, 104.0)
const WATCH_DRAW_SIZE := Vector2(78.0, 78.0)
const OUTER_RING_RADIUS := 69.0
const INNER_RING_RADIUS := 51.0
const RING_ARC_POINT_COUNT := 48
const BINDING_NODE_COUNT := 4
const RING_MOTE_COUNT := 3
const HAND_LOCK_ANGLE := -PI * 0.35
const VEIL_EDGE_BAND := 46.0

const FROZEN_MOTE_ANCHORS: Array[Vector2] = [
	Vector2(0.08, 0.16), Vector2(0.22, 0.55), Vector2(0.16, 0.82), Vector2(0.34, 0.30),
	Vector2(0.45, 0.68), Vector2(0.31, 0.09), Vector2(0.56, 0.22), Vector2(0.62, 0.84),
	Vector2(0.71, 0.48), Vector2(0.68, 0.12), Vector2(0.84, 0.70), Vector2(0.90, 0.30),
	Vector2(0.79, 0.90), Vector2(0.93, 0.55),
]

const INK_BLUE := Color(0.025, 0.075, 0.14, 1.0)
const BRASS_DARK := Color(0.38, 0.22, 0.035, 1.0)
const BRASS := Color(0.94, 0.65, 0.12, 1.0)
const BRASS_LIGHT := Color(1.0, 0.88, 0.38, 1.0)
const MAGIC_CYAN := Color(0.12, 0.9, 1.0, 1.0)

var _icon_texture: Texture2D


func prewarm_assets() -> void:
	_touch_texture(get_icon_texture())


func draw(canvas: CanvasItem, stopwatch_context: Dictionary) -> void:
	if canvas == null or not bool(stopwatch_context.get("active", false)):
		return

	var freeze_active: bool = bool(stopwatch_context.get("freeze_active", false))
	var recovery_active: bool = bool(stopwatch_context.get("recovery_active", false))
	var timer_frames: float = maxf(0.0, float(stopwatch_context.get("timer_frames", 0.0)))
	var initial_timer_frames: float = maxf(1.0, float(stopwatch_context.get("initial_timer_frames", 120.0)))
	var recovery_timer_frames: float = maxf(0.0, float(stopwatch_context.get("recovery_timer_frames", 0.0)))
	var recovery_initial_frames: float = maxf(1.0, float(stopwatch_context.get("recovery_initial_frames", 60.0)))
	var freeze_ratio: float = clampf(timer_frames / initial_timer_frames, 0.0, 1.0)
	var recovery_ratio: float = clampf(recovery_timer_frames / recovery_initial_frames, 0.0, 1.0)
	var phase: float = float(stopwatch_context.get("clock_angle", 0.0))
	var unwind: float = 0.0 if freeze_active else 1.0 - recovery_ratio
	var effect_alpha: float = 1.0 if freeze_active else recovery_ratio

	_draw_activation_flash(canvas, stopwatch_context)
	_draw_time_veil(canvas, phase, effect_alpha, freeze_active, unwind)
	_draw_time_binding_ring(canvas, WATCH_CENTER, phase, effect_alpha, unwind, recovery_active)
	_draw_binding_diamond(canvas, WATCH_CENTER, phase, effect_alpha, unwind)
	_draw_watch(canvas, WATCH_CENTER, phase, effect_alpha, freeze_ratio, recovery_active, freeze_active, recovery_ratio)


func get_icon_texture() -> Texture2D:
	if _icon_texture == null:
		_icon_texture = ProjectResourceLoader.load_texture(
			ICON_PATH,
			"Missing Yosul Pocket Watch icon at %s",
			"Failed to load Yosul Pocket Watch icon at %s"
		)
	return _icon_texture


func get_asset_status() -> Dictionary:
	return {
		"icon_path": ICON_PATH,
		"icon_ready": get_icon_texture() != null,
	}


func _draw_activation_flash(canvas: CanvasItem, context: Dictionary) -> void:
	var flash_timer: float = maxf(0.0, float(context.get("flash_timer_frames", 0.0)))
	var flash_initial: float = maxf(1.0, float(context.get("flash_initial_frames", 10.0)))
	if flash_timer <= 0.0:
		return
	var flash_ratio: float = clampf(flash_timer / flash_initial, 0.0, 1.0)
	var burst: float = 1.0 - flash_ratio
	canvas.draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), Color(0.54, 0.96, 1.0, 0.2 * flash_ratio))
	canvas.draw_circle(WATCH_CENTER, 70.0 + burst * 150.0, Color(MAGIC_CYAN.r, MAGIC_CYAN.g, MAGIC_CYAN.b, 0.07 * flash_ratio))
	canvas.draw_circle(WATCH_CENTER, 96.0 + burst * 60.0, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.1 * flash_ratio))
	canvas.draw_circle(WATCH_CENTER, 52.0 + burst * 30.0, Color(1.0, 1.0, 1.0, 0.16 * flash_ratio))


func _draw_time_veil(canvas: CanvasItem, phase: float, alpha: float, freeze_active: bool, unwind: float) -> void:
	var veil_alpha: float = (0.105 if freeze_active else 0.055) * alpha
	canvas.draw_rect(Rect2(Vector2.ZERO, FIELD_SIZE), Color(INK_BLUE.r, INK_BLUE.g, INK_BLUE.b, veil_alpha))
	var band_alpha: float = 0.1 * alpha
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(FIELD_SIZE.x, VEIL_EDGE_BAND)), Color(INK_BLUE.r, INK_BLUE.g, INK_BLUE.b, band_alpha))
	canvas.draw_rect(Rect2(Vector2(0.0, FIELD_SIZE.y - VEIL_EDGE_BAND), Vector2(FIELD_SIZE.x, VEIL_EDGE_BAND)), Color(INK_BLUE.r, INK_BLUE.g, INK_BLUE.b, band_alpha))
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(VEIL_EDGE_BAND, FIELD_SIZE.y)), Color(INK_BLUE.r, INK_BLUE.g, INK_BLUE.b, band_alpha))
	canvas.draw_rect(Rect2(Vector2(FIELD_SIZE.x - VEIL_EDGE_BAND, 0.0), Vector2(VEIL_EDGE_BAND, FIELD_SIZE.y)), Color(INK_BLUE.r, INK_BLUE.g, INK_BLUE.b, band_alpha))

	for index in range(FROZEN_MOTE_ANCHORS.size()):
		var anchor: Vector2 = FROZEN_MOTE_ANCHORS[index] * FIELD_SIZE
		var mote: Vector2 = anchor.lerp(WATCH_CENTER, unwind * 0.22)
		var twinkle: float = 0.5 + 0.5 * sin(phase * 2.0 + float(index) * 2.4)
		var mote_alpha: float = (0.18 + 0.28 * twinkle) * alpha
		var half_span: float = 3.0 + float(index % 3)
		var mote_color: Color = MAGIC_CYAN if index % 2 == 0 else BRASS_LIGHT
		canvas.draw_line(
			mote + Vector2(-half_span, 0.0),
			mote + Vector2(half_span, 0.0),
			Color(mote_color.r, mote_color.g, mote_color.b, mote_alpha),
			1.0
		)
		canvas.draw_line(
			mote + Vector2(0.0, -half_span),
			mote + Vector2(0.0, half_span),
			Color(mote_color.r, mote_color.g, mote_color.b, mote_alpha),
			1.0
		)


# The four-direction binding seal is carried by pulsing light nodes only. Drawing
# the diamond as connected strokes reads as a hard cage outline over the field.
func _draw_binding_diamond(
	canvas: CanvasItem,
	center: Vector2,
	phase: float,
	alpha: float,
	unwind: float
) -> void:
	var horizontal: float = 101.0 + unwind * 24.0
	var vertical: float = 55.0 + unwind * 16.0
	var nodes: Array[Vector2] = [
		center + Vector2(0.0, -vertical),
		center + Vector2(horizontal, 0.0),
		center + Vector2(0.0, vertical),
		center + Vector2(-horizontal, 0.0),
	]
	for index in range(BINDING_NODE_COUNT):
		var node: Vector2 = nodes[index]
		var node_glow: float = 0.5 + 0.5 * sin(phase * 1.8 + float(index) * PI * 0.5)
		canvas.draw_circle(node, 16.0, Color(BRASS.r, BRASS.g, BRASS.b, 0.03 * alpha))
		canvas.draw_circle(node, 8.0, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, (0.05 + 0.04 * node_glow) * alpha))
		canvas.draw_circle(node, 2.6, Color(MAGIC_CYAN.r, MAGIC_CYAN.g, MAGIC_CYAN.b, (0.4 + 0.35 * node_glow) * alpha))


# The time-binding ring is luminous, not linear: wide low-alpha bands stack into a
# soft halo so the seal reads as light rather than a drawn perimeter.
func _draw_time_binding_ring(
	canvas: CanvasItem,
	center: Vector2,
	phase: float,
	alpha: float,
	unwind: float,
	recovery_active: bool
) -> void:
	var expansion: float = 1.0 + unwind * 0.32
	var outer_radius: float = OUTER_RING_RADIUS * expansion
	var inner_radius: float = INNER_RING_RADIUS * (1.0 + unwind * 0.18)

	_draw_soft_halo_band(canvas, center, outer_radius, 30.0, Color(BRASS.r, BRASS.g, BRASS.b, 0.018 * alpha))
	_draw_soft_halo_band(canvas, center, outer_radius, 17.0, Color(BRASS.r, BRASS.g, BRASS.b, 0.024 * alpha))
	_draw_soft_halo_band(canvas, center, outer_radius, 7.0, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.03 * alpha))
	_draw_soft_halo_band(canvas, center, inner_radius, 22.0, Color(MAGIC_CYAN.r, MAGIC_CYAN.g, MAGIC_CYAN.b, 0.018 * alpha))
	_draw_soft_halo_band(canvas, center, inner_radius, 9.0, Color(MAGIC_CYAN.r, MAGIC_CYAN.g, MAGIC_CYAN.b, 0.024 * alpha))

	if recovery_active:
		for echo in range(2):
			var echo_radius: float = outer_radius * (1.16 + 0.3 * float(echo)) + unwind * 30.0
			var echo_alpha: float = (0.028 - 0.011 * float(echo)) * (1.0 - unwind) * alpha
			_draw_soft_halo_band(canvas, center, echo_radius, 24.0, Color(MAGIC_CYAN.r, MAGIC_CYAN.g, MAGIC_CYAN.b, echo_alpha))

	for index in range(RING_MOTE_COUNT):
		var angle: float = phase * 0.18 + TAU * float(index) / float(RING_MOTE_COUNT)
		var mote: Vector2 = center + Vector2.from_angle(angle) * outer_radius
		var shimmer: float = 0.5 + 0.5 * sin(phase * 2.4 + float(index) * 2.1)
		canvas.draw_circle(mote, 9.0, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.05 * alpha))
		canvas.draw_circle(mote, 2.4, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, (0.4 + 0.35 * shimmer) * alpha))


func _draw_watch(
	canvas: CanvasItem,
	center: Vector2,
	phase: float,
	alpha: float,
	freeze_ratio: float,
	recovery_active: bool,
	freeze_active: bool,
	recovery_ratio: float
) -> void:
	var pulse: float = 1.0 + 0.035 * sin(phase * 0.8)
	if recovery_active:
		pulse += 0.04 * sin(phase * 2.2)
	canvas.draw_circle(center, 58.0 * pulse, Color(MAGIC_CYAN.r, MAGIC_CYAN.g, MAGIC_CYAN.b, 0.035 * alpha))
	canvas.draw_circle(center, 50.0 * pulse, Color(0.0, 0.0, 0.0, 0.1 * alpha))
	canvas.draw_circle(center, 45.0 * pulse, Color(0.0, 0.0, 0.0, 0.13 * alpha))
	canvas.draw_circle(center, 40.0 * pulse, Color(0.0, 0.0, 0.0, 0.16 * alpha))
	canvas.draw_circle(center, 42.0 * pulse, Color(MAGIC_CYAN.r, MAGIC_CYAN.g, MAGIC_CYAN.b, (0.05 + 0.05 * freeze_ratio) * alpha))
	canvas.draw_circle(center, 33.0 * pulse, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.05 * alpha))

	var texture: Texture2D = get_icon_texture()
	if texture != null:
		var draw_size: Vector2 = WATCH_DRAW_SIZE * pulse
		canvas.draw_texture_rect(
			texture,
			Rect2(center - draw_size * 0.5, draw_size),
			false,
			Color(1.0, 1.0, 1.0, alpha)
		)
	else:
		_draw_watch_fallback(canvas, center, pulse, alpha)

	var hand_angle: float = HAND_LOCK_ANGLE
	if freeze_active:
		hand_angle += sin(phase * 7.0) * 0.03
	else:
		hand_angle -= (1.0 - recovery_ratio) * TAU * 1.5
	var hand_dir := Vector2.from_angle(hand_angle)
	canvas.draw_line(center + hand_dir * 40.0, center + hand_dir * 56.0, Color(MAGIC_CYAN.r, MAGIC_CYAN.g, MAGIC_CYAN.b, 0.7 * alpha), 2.2)
	canvas.draw_circle(center + hand_dir * 56.0, 4.0, Color(MAGIC_CYAN.r, MAGIC_CYAN.g, MAGIC_CYAN.b, 0.16 * alpha))
	canvas.draw_circle(center + hand_dir * 56.0, 1.6, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.85 * alpha))

	var core_radius: float = 11.0 + 2.0 * sin(phase)
	canvas.draw_circle(center, core_radius, Color(MAGIC_CYAN.r, MAGIC_CYAN.g, MAGIC_CYAN.b, 0.09 * alpha))
	canvas.draw_circle(center, core_radius * 0.45, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, 0.16 * alpha))


func _draw_watch_fallback(canvas: CanvasItem, center: Vector2, pulse: float, alpha: float) -> void:
	canvas.draw_circle(center, 34.0 * pulse, Color(BRASS_DARK.r, BRASS_DARK.g, BRASS_DARK.b, alpha))
	canvas.draw_circle(center, 25.0 * pulse, Color(INK_BLUE.r, INK_BLUE.g, INK_BLUE.b, alpha))
	canvas.draw_circle(center + Vector2(0.0, -39.0), 7.0, Color(BRASS_LIGHT.r, BRASS_LIGHT.g, BRASS_LIGHT.b, alpha))


func _draw_soft_halo_band(canvas: CanvasItem, center: Vector2, radius: float, band_width: float, color: Color) -> void:
	if radius <= 0.0 or band_width <= 0.0 or color.a <= 0.0:
		return
	canvas.draw_arc(center, radius, 0.0, TAU, RING_ARC_POINT_COUNT, color, band_width)


func _touch_texture(texture: Texture2D) -> void:
	if texture != null:
		texture.get_size()
