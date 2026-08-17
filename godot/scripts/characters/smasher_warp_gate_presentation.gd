extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const WarpGateFxHost := preload("res://scripts/characters/smasher_warp_gate_fx_host.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const EFFECT_MIN_SIZE := 188.0
const EFFECT_MAX_SIZE := 286.0
const WALL_PORTAL_THROAT_ANCHOR_RATIO := 0.34
const WALL_CENTER_Y_OFFSET := -42.0
const PORTAL_LIFE_MSEC := 620
const MAX_RENDERED_PORTAL_BURSTS := 8
const PORTAL_SPARK_COUNT := 9
const PORTAL_ARC_SEGMENTS := 18
const PORTAL_ARC_LAYERS := 4
const TIMER_BAR_SIZE := Vector2(170.0, 14.0)
const TIMER_BAR_MARGIN := Vector2(16.0, 28.0)
const TIMER_STACK_SPACING := 18.0
const TIMER_STACK_KEY := "warp_gate"
const TIMER_STACK_INDEX := 0

var _fx_host: Node = null
var _fx_host_add_pending := false
var _prewarm_step_index := 0
var _prewarm_complete := false


func prewarm_step() -> bool:
	if _prewarm_complete:
		return true
	match _prewarm_step_index:
		0:
			if not ImpactFlareTextureCache.prewarm_step():
				return false
		1:
			if not ImpactShockwaveTextureCache.prewarm_step():
				return false
		2:
			WarpGateFxHost.prewarm_assets()
		_:
			_prewarm_complete = true
			return true
	_prewarm_step_index += 1
	return false


func draw(
	canvas: CanvasItem,
	shake_offset: Vector2,
	node_fx_layout: Dictionary,
	timer_stack: Object,
	visual_msec: int,
	active: bool,
	start_msec: int,
	end_msec: int,
	total_duration_msec: int,
	phase: float,
	last_player_pos: Vector2,
	last_player_size: Vector2,
	portals: Array[Dictionary],
	afterimage_smoke_puffs: Array[Dictionary]
) -> void:
	if canvas == null:
		return
	var node_fx_synced: bool = _sync_node_fx(
		canvas,
		shake_offset,
		node_fx_layout,
		visual_msec,
		active,
		start_msec,
		phase,
		last_player_pos,
		last_player_size,
		portals
	)
	if active:
		if not node_fx_synced:
			_draw_wall_portals(canvas, shake_offset, phase, last_player_pos, last_player_size)
		_draw_timer_bar(canvas, timer_stack, visual_msec, active, end_msec, total_duration_msec)
	if not node_fx_synced:
		_draw_portal_bursts(canvas, shake_offset, visual_msec, phase, portals)
	_draw_afterimage_smoke(canvas, shake_offset, visual_msec, afterimage_smoke_puffs)


func hide_node_fx() -> void:
	if _is_valid_fx_host() and _fx_host.has_method("set_active"):
		_fx_host.set_active(false)


func get_fx_host_for_tests() -> Node:
	return _fx_host if _is_valid_fx_host() else null


func build_portal_projection_for_tests(
	center: Vector2,
	size: float,
	alpha: float,
	side: int,
	kind: String,
	progress: float,
	spawn_msec: int,
	shake_offset: Vector2,
	node_fx_layout: Dictionary
) -> Dictionary:
	return _build_node_fx_portal_state(
		center,
		size,
		alpha,
		side,
		kind,
		progress,
		spawn_msec,
		shake_offset,
		node_fx_layout
	)


func _sync_node_fx(
	canvas: CanvasItem,
	shake_offset: Vector2,
	node_fx_layout: Dictionary,
	visual_msec: int,
	active: bool,
	start_msec: int,
	phase: float,
	last_player_pos: Vector2,
	last_player_size: Vector2,
	portals: Array[Dictionary]
) -> bool:
	if node_fx_layout.is_empty():
		return false
	var states: Array[Dictionary] = _build_node_fx_portal_states(
		shake_offset,
		node_fx_layout,
		visual_msec,
		active,
		start_msec,
		phase,
		last_player_pos,
		last_player_size,
		portals
	)
	if states.is_empty():
		hide_node_fx()
		return false
	var host: Node = _get_or_create_fx_host(canvas)
	if host == null or not host.has_method("sync_state"):
		return false
	if not host.is_inside_tree():
		return false
	host.sync_state(states, true)
	return true


func _build_node_fx_portal_states(
	shake_offset: Vector2,
	node_fx_layout: Dictionary,
	visual_msec: int,
	active: bool,
	start_msec: int,
	phase: float,
	last_player_pos: Vector2,
	last_player_size: Vector2,
	portals: Array[Dictionary]
) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	if active:
		var wall_y: float = clamp(last_player_pos.y + last_player_size.y * 0.5 + WALL_CENTER_Y_OFFSET, 92.0, FIELD_HEIGHT - 92.0)
		var pulse: float = 0.5 + 0.5 * sin(phase)
		var size: float = clamp(230.0 + pulse * 34.0, EFFECT_MIN_SIZE, EFFECT_MAX_SIZE)
		states.append(_build_node_fx_portal_state(Vector2(_get_wall_portal_center_x(-1, size), wall_y), size, 1.0, -1, "active", 0.0, start_msec, shake_offset, node_fx_layout))
		states.append(_build_node_fx_portal_state(Vector2(_get_wall_portal_center_x(1, size), wall_y), size, 1.0, 1, "active", 0.0, start_msec, shake_offset, node_fx_layout))

	if not portals.is_empty():
		var portal_start: int = max(0, portals.size() - MAX_RENDERED_PORTAL_BURSTS)
		for index in range(portal_start, portals.size()):
			var portal: Dictionary = portals[index]
			var center: Vector2 = _as_vector2(portal.get("center", Vector2.ZERO), Vector2.ZERO)
			var spawn_msec: int = int(portal.get("spawn_msec", visual_msec))
			var life_msec: int = max(1, int(portal.get("life_msec", PORTAL_LIFE_MSEC)))
			var progress: float = clamp(float(visual_msec - spawn_msec) / float(life_msec), 0.0, 1.0)
			var alpha: float = 1.0 - progress
			var size: float = EFFECT_MIN_SIZE * (0.75 + progress * 0.75)
			var side: int = int(portal.get("side", 1))
			if bool(portal.get("wall_anchor", false)):
				center.x = _get_wall_portal_center_x(side, size)
			states.append(_build_node_fx_portal_state(center, size, alpha, side, str(portal.get("kind", "burst")), progress, spawn_msec, shake_offset, node_fx_layout))
	return states


func _build_node_fx_portal_state(
	center: Vector2,
	size: float,
	alpha: float,
	side: int,
	kind: String,
	progress: float,
	spawn_msec: int,
	shake_offset: Vector2,
	node_fx_layout: Dictionary
) -> Dictionary:
	var render_scale: float = max(0.01, float(node_fx_layout.get("render_scale", 1.0)))
	var game_offset: Vector2 = _as_vector2(node_fx_layout.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var screen_center: Vector2 = game_offset + (center + shake_offset) * render_scale
	return {
		"screen_center": screen_center,
		"screen_size": size * render_scale,
		"side": side,
		"kind": kind,
		"alpha": alpha,
		"progress": progress,
		"spawn_msec": spawn_msec,
		"tint": _get_portal_tint(kind, 1.0),
		"hot": _get_portal_hot_color(kind),
	}


func _get_or_create_fx_host(canvas: CanvasItem) -> Node:
	if _is_valid_fx_host():
		return _fx_host
	if not (canvas is Node):
		return null
	var parent: Node = canvas as Node
	var existing: Node = parent.get_node_or_null("SmasherWarpGateFxHost")
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		_fx_host = existing
		_fx_host_add_pending = false
		return _fx_host
	_fx_host = WarpGateFxHost.new()
	_fx_host.name = "SmasherWarpGateFxHost"
	_fx_host.visible = false
	if not _fx_host_add_pending:
		_fx_host_add_pending = true
		parent.call_deferred("add_child", _fx_host)
	return _fx_host


func _is_valid_fx_host() -> bool:
	return _fx_host != null and is_instance_valid(_fx_host) and not _fx_host.is_queued_for_deletion()


func _draw_wall_portals(
	canvas: CanvasItem,
	shake_offset: Vector2,
	phase: float,
	last_player_pos: Vector2,
	last_player_size: Vector2
) -> void:
	var wall_y: float = clamp(last_player_pos.y + last_player_size.y * 0.5 + WALL_CENTER_Y_OFFSET, 92.0, FIELD_HEIGHT - 92.0)
	var pulse: float = 0.5 + 0.5 * sin(phase)
	var size: float = clamp(230.0 + pulse * 34.0, EFFECT_MIN_SIZE, EFFECT_MAX_SIZE)
	var left_center := Vector2(_get_wall_portal_center_x(-1, size), wall_y)
	var right_center := Vector2(_get_wall_portal_center_x(1, size), wall_y)
	_draw_portal_frame(canvas, left_center + shake_offset, size, 1.0, -1, "active", phase)
	_draw_portal_frame(canvas, right_center + shake_offset, size, 1.0, 1, "active", phase)


func _draw_portal_bursts(
	canvas: CanvasItem,
	shake_offset: Vector2,
	visual_msec: int,
	phase: float,
	portals: Array[Dictionary]
) -> void:
	if portals.is_empty():
		return
	var portal_start: int = max(0, portals.size() - MAX_RENDERED_PORTAL_BURSTS)
	for index in range(portal_start, portals.size()):
		var portal: Dictionary = portals[index]
		var center: Vector2 = _as_vector2(portal.get("center", Vector2.ZERO), Vector2.ZERO)
		var spawn_msec: int = int(portal.get("spawn_msec", visual_msec))
		var life_msec: int = max(1, int(portal.get("life_msec", PORTAL_LIFE_MSEC)))
		var progress: float = clamp(float(visual_msec - spawn_msec) / float(life_msec), 0.0, 1.0)
		var alpha: float = 1.0 - progress
		var size: float = EFFECT_MIN_SIZE * (0.75 + progress * 0.75)
		var side: int = int(portal.get("side", 1))
		if bool(portal.get("wall_anchor", false)):
			center.x = _get_wall_portal_center_x(side, size)
		_draw_portal_frame(canvas, center + shake_offset, size, alpha, side, str(portal.get("kind", "burst")), phase)


func _draw_afterimage_smoke(
	canvas: CanvasItem,
	shake_offset: Vector2,
	visual_msec: int,
	puffs: Array[Dictionary]
) -> void:
	for puff in puffs:
		var spawn_msec: int = int(puff.get("spawn_msec", visual_msec))
		var life_msec: int = max(1, int(puff.get("life_msec", 460)))
		var progress: float = clamp(float(visual_msec - spawn_msec) / float(life_msec), 0.0, 1.0)
		if progress >= 1.0:
			continue
		var center: Vector2 = _as_vector2(puff.get("center", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var puff_size: Vector2 = _as_vector2(puff.get("size", Vector2(72.0, 44.0)), Vector2(72.0, 44.0))
		var seed: int = int(puff.get("seed", 0))
		var fade: float = pow(1.0 - progress, 1.45)
		var spread: float = 5.0 + progress * max(12.0, puff_size.x * 0.22)
		_draw_oval_glow(
			canvas,
			center + Vector2(0.0, -progress * 12.0),
			Vector2(max(18.0, puff_size.x * 0.34), max(12.0, puff_size.y * 0.42)) * (0.82 + progress * 0.35),
			Color(0.62, 0.30, 0.92),
			fade * 0.22
		)
		for lobe_index in range(5):
			var angle: float = float((seed * 37 + lobe_index * 71) % 360) * PI / 180.0
			var lobe_progress: float = progress * (0.72 + float(lobe_index) * 0.055)
			var offset := Vector2(cos(angle) * spread, sin(angle) * spread * 0.48 - lobe_progress * 11.0)
			var radius: float = max(4.0, puff_size.y * (0.11 + float(lobe_index % 3) * 0.035)) * (0.9 + progress * 0.28)
			var color: Color = Color(0.82, 0.54, 1.0) if lobe_index % 2 == 0 else Color(0.55, 0.92, 1.0)
			canvas.draw_circle(center + offset, radius, Color(color.r, color.g, color.b, fade * (0.22 - float(lobe_index) * 0.018)))


func _get_wall_portal_center_x(side: int, size: float) -> float:
	var radius_x: float = max(1.0, size * 0.24)
	var center_offset: float = radius_x * WALL_PORTAL_THROAT_ANCHOR_RATIO
	if side < 0:
		return center_offset
	return FIELD_WIDTH - center_offset


func _draw_portal_frame(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	alpha: float,
	side: int,
	kind: String,
	phase: float
) -> void:
	_draw_procedural_portal(canvas, center, size, alpha, side, kind, phase)


func _draw_procedural_portal(
	canvas: CanvasItem,
	center: Vector2,
	size: float,
	alpha: float,
	side: int,
	kind: String,
	phase: float
) -> void:
	var radius_x: float = size * 0.24
	var radius_y: float = size * 0.43
	var tint: Color = _get_portal_tint(kind, alpha)
	var local_phase: float = phase + float(side) * 0.55 + _get_kind_phase_offset(kind)
	var pulse: float = 0.5 + 0.5 * sin(local_phase * 2.4)
	var side_sign: float = -1.0 if side < 0 else 1.0
	var core_color := Color(0.18, 0.04, 0.34)
	var hot_color := Color(1.0, 0.84, 0.36)
	var violet := Color(0.72, 0.26, 1.0)
	var cyan := Color(0.36, 0.92, 1.0)

	_draw_oval_glow(canvas, center, Vector2(radius_x * 2.15, radius_y * 1.44), Color(tint.r, tint.g, tint.b), alpha * (0.20 + pulse * 0.07))
	_draw_oval_glow(canvas, center + Vector2(side_sign * radius_x * 0.08, 0.0), Vector2(radius_x * 0.72, radius_y * 1.02), core_color, alpha * 0.34)
	_draw_portal_rings(canvas, center, Vector2(radius_x, radius_y), tint, violet, alpha, local_phase)
	_draw_portal_vortex(canvas, center, Vector2(radius_x, radius_y), side, tint, hot_color, cyan, alpha, local_phase)
	_draw_portal_sparks(canvas, center, Vector2(radius_x, radius_y), side, kind, tint, hot_color, alpha, local_phase)
	_draw_portal_throat(canvas, center, Vector2(radius_x, radius_y), side, hot_color, cyan, alpha, local_phase)


func _draw_portal_rings(
	canvas: CanvasItem,
	center: Vector2,
	radius_size: Vector2,
	tint: Color,
	violet: Color,
	alpha: float,
	local_phase: float
) -> void:
	for i in range(3):
		var t: float = float(i)
		var ring_pulse: float = 0.5 + 0.5 * sin(local_phase * (1.8 + t * 0.17) + t * 1.2)
		var radius_scale := Vector2(1.0 + t * 0.13 + ring_pulse * 0.030, 1.0 + t * 0.09 - ring_pulse * 0.018)
		var ring_alpha: float = alpha * (0.40 - t * 0.070)
		_draw_oval_ring(canvas, center, radius_size * radius_scale, Color(tint.r, tint.g, tint.b), ring_alpha)
		_draw_oval_ring(canvas, center, radius_size * radius_scale * 0.82, violet, ring_alpha * 0.56)
	var collapse: float = 0.5 + 0.5 * sin(local_phase * 3.4)
	_draw_oval_ring(canvas, center, radius_size * (0.50 + collapse * 0.09), Color(1.0, 0.88, 0.42), alpha * 0.32)


func _draw_portal_vortex(
	canvas: CanvasItem,
	center: Vector2,
	radius_size: Vector2,
	side: int,
	tint: Color,
	hot_color: Color,
	cyan: Color,
	alpha: float,
	local_phase: float
) -> void:
	var side_sign: float = -1.0 if side < 0 else 1.0
	for layer in range(PORTAL_ARC_LAYERS):
		var layer_f: float = float(layer)
		var ring_scale: float = 0.48 + layer_f * 0.15
		var sweep: float = PI * (0.42 + layer_f * 0.045)
		var start_angle: float = local_phase * (1.6 + layer_f * 0.19) * side_sign + layer_f * 1.22
		var color: Color = tint.lerp(hot_color if layer % 2 == 0 else cyan, 0.42)
		var width: float = 2.3 - layer_f * 0.26
		var arc_alpha: float = alpha * (0.42 - layer_f * 0.055)
		_draw_ellipse_arc_polyline(canvas, center, radius_size * ring_scale, start_angle, sweep * side_sign, Color(color.r, color.g, color.b, arc_alpha), width)
		_draw_ellipse_arc_polyline(canvas, center, radius_size * ring_scale * Vector2(0.82, 0.88), start_angle + PI * 0.92, -sweep * 0.58 * side_sign, Color(cyan.r, cyan.g, cyan.b, arc_alpha * 0.44), max(1.0, width * 0.58))


func _draw_portal_sparks(
	canvas: CanvasItem,
	center: Vector2,
	radius_size: Vector2,
	side: int,
	kind: String,
	tint: Color,
	hot_color: Color,
	alpha: float,
	local_phase: float
) -> void:
	var side_sign: float = -1.0 if side < 0 else 1.0
	var burst_scale: float = 1.35 if kind.begins_with("open") or kind.begins_with("resume") else 1.0
	for j in range(PORTAL_SPARK_COUNT):
		var jf: float = float(j)
		var orbit: float = 0.64 + 0.24 * sin(local_phase * 1.7 + jf * 1.31)
		var angle: float = local_phase * (1.15 + float(j % 3) * 0.16) * side_sign + jf * TAU / float(PORTAL_SPARK_COUNT)
		var spark_pos := center + Vector2(cos(angle) * radius_size.x * orbit, sin(angle) * radius_size.y * (0.72 + 0.08 * sin(jf)))
		var spark_alpha: float = alpha * (0.32 + 0.24 * sin(local_phase * 2.6 + jf) * sin(local_phase * 2.6 + jf)) * burst_scale
		var spark_color: Color = hot_color if j % 3 == 0 else Color(tint.r, tint.g, tint.b)
		ImpactFlareTextureCache.draw_sparkle(canvas, spark_pos, 3.0 + float(j % 4) * 0.7, spark_color, spark_alpha)


func _draw_portal_throat(
	canvas: CanvasItem,
	center: Vector2,
	radius_size: Vector2,
	side: int,
	hot_color: Color,
	cyan: Color,
	alpha: float,
	local_phase: float
) -> void:
	var side_sign: float = -1.0 if side < 0 else 1.0
	var throat_x: float = side_sign * radius_size.x * (0.32 + 0.06 * sin(local_phase * 2.1))
	var throat_width: float = 4.5 + 4.0 * abs(sin(local_phase * 2.7))
	var top := center + Vector2(throat_x, -radius_size.y * 0.88)
	var bottom := center + Vector2(throat_x, radius_size.y * 0.88)
	canvas.draw_line(top, bottom, Color(0.18, 0.03, 0.28, alpha * 0.62), throat_width + 5.5, true)
	canvas.draw_line(top, bottom, Color(hot_color.r, hot_color.g, hot_color.b, alpha * 0.76), throat_width, true)
	canvas.draw_line(
		center + Vector2(throat_x - side_sign * radius_size.x * 0.10, -radius_size.y * 0.62),
		center + Vector2(throat_x + side_sign * radius_size.x * 0.10, radius_size.y * 0.62),
		Color(cyan.r, cyan.g, cyan.b, alpha * 0.36),
		max(1.0, throat_width * 0.42),
		true
	)


func _draw_ellipse_arc_polyline(
	canvas: CanvasItem,
	center: Vector2,
	radius_size: Vector2,
	start_angle: float,
	sweep: float,
	color: Color,
	width: float
) -> void:
	if color.a <= 0.0 or radius_size.x <= 1.0 or radius_size.y <= 1.0:
		return
	var points := PackedVector2Array()
	for i in range(PORTAL_ARC_SEGMENTS + 1):
		var ratio: float = float(i) / float(PORTAL_ARC_SEGMENTS)
		var angle: float = start_angle + sweep * ratio
		points.append(center + Vector2(cos(angle) * radius_size.x, sin(angle) * radius_size.y))
	canvas.draw_polyline(points, color, width, true)


func _get_kind_phase_offset(kind: String) -> float:
	if kind.begins_with("enter"):
		return 0.7
	if kind.begins_with("exit"):
		return 1.4
	if kind.begins_with("resume"):
		return 2.1
	if kind.begins_with("fade"):
		return 2.8
	return 0.0


func _draw_oval_glow(canvas: CanvasItem, center: Vector2, half_extents: Vector2, color: Color, alpha: float) -> void:
	_draw_centered_cached_texture(canvas, ImpactFlareTextureCache.get_glow_texture(), center, half_extents, color, alpha)


func _draw_oval_ring(canvas: CanvasItem, center: Vector2, radius_size: Vector2, color: Color, alpha: float) -> void:
	var ring_ratio: float = max(0.001, float(ImpactShockwaveTextureCache.RING_RADIUS_RATIO))
	_draw_centered_cached_texture(canvas, ImpactShockwaveTextureCache.get_full_ring_texture(), center, radius_size / ring_ratio, color, alpha)


func _draw_centered_cached_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	half_extents: Vector2,
	color: Color,
	alpha: float
) -> void:
	if canvas == null or texture == null or half_extents.x <= 0.0 or half_extents.y <= 0.0 or alpha <= 0.0:
		return
	canvas.draw_texture_rect(texture, Rect2(center - half_extents, half_extents * 2.0), false, Color(color.r, color.g, color.b, alpha))


func _draw_timer_bar(
	canvas: CanvasItem,
	timer_stack: Object,
	visual_msec: int,
	active: bool,
	end_msec: int,
	total_duration_msec: int
) -> void:
	var ratio: float = _get_remaining_ratio(visual_msec, active, end_msec, total_duration_msec)
	if ratio <= 0.0:
		return
	var stack_index: int = _claim_timer_stack_index(timer_stack, TIMER_STACK_KEY, TIMER_STACK_INDEX)
	var rect := Rect2(_get_timer_bar_position(stack_index), TIMER_BAR_SIZE)
	canvas.draw_rect(rect.grow(3.0), Color(0.0, 0.0, 0.0, 0.45))
	canvas.draw_rect(rect, Color(0.05, 0.04, 0.12, 0.78))
	var fill_rect := Rect2(rect.position + Vector2(2.0, 2.0), Vector2((rect.size.x - 4.0) * ratio, rect.size.y - 4.0))
	canvas.draw_rect(fill_rect, Color(0.95, 0.50, 1.0, 0.92))
	canvas.draw_rect(rect, Color(1.0, 0.78, 0.38, 0.86), false, 2.0)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		canvas.draw_string(font, rect.position + Vector2(6.0, rect.size.y - 3.0), "WARP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1.0, 0.88, 0.58, 0.95))


func _get_remaining_ratio(visual_msec: int, active: bool, end_msec: int, total_duration_msec: int) -> float:
	if not active or total_duration_msec <= 0:
		return 0.0
	return clamp(float(end_msec - visual_msec) / float(total_duration_msec), 0.0, 1.0)


func _get_timer_bar_position(stack_index: int) -> Vector2:
	return Vector2(
		FIELD_WIDTH - TIMER_BAR_SIZE.x - TIMER_BAR_MARGIN.x,
		FIELD_HEIGHT - TIMER_BAR_MARGIN.y - float(max(0, stack_index)) * TIMER_STACK_SPACING
	)


func _claim_timer_stack_index(timer_stack: Object, key: String, fallback_index: int) -> int:
	if timer_stack != null and timer_stack.has_method("claim"):
		var claimed: int = int(timer_stack.claim(key, true))
		if claimed >= 0:
			return claimed
	return fallback_index


func _get_portal_tint(kind: String, alpha: float) -> Color:
	if kind.begins_with("fade"):
		return Color(0.75, 0.34, 1.0, 0.58 * alpha)
	if kind.begins_with("resume"):
		return Color(1.0, 0.78, 0.35, 0.78 * alpha)
	if kind.begins_with("exit"):
		return Color(0.32, 0.92, 1.0, 0.82 * alpha)
	if kind.begins_with("enter"):
		return Color(1.0, 0.62, 0.28, 0.82 * alpha)
	return Color(0.92, 0.45, 1.0, 0.88 * alpha)


func _get_portal_hot_color(kind: String) -> Color:
	if kind.begins_with("exit"):
		return Color(0.40, 1.0, 0.96)
	if kind.begins_with("enter"):
		return Color(1.0, 0.70, 0.28)
	if kind.begins_with("resume"):
		return Color(1.0, 0.86, 0.34)
	if kind.begins_with("fade"):
		return Color(0.84, 0.34, 1.0)
	return Color(1.0, 0.84, 0.36)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
