extends RefCounted

const ACTION_LEFT := "ui_left"
const ACTION_RIGHT := "ui_right"
const ACTION_UP := "ui_up"
const ACTION_DOWN := "ui_down"
const ACTION_ACCEPT := "ui_accept"
const ACTIONS := [
	ACTION_LEFT,
	ACTION_RIGHT,
	ACTION_UP,
	ACTION_DOWN,
	ACTION_ACCEPT,
]

const BASE_RADIUS := 54.0
const MIN_RADIUS := 42.0
const MAX_RADIUS := 86.0
const EDGE_MARGIN_RATIO := 0.045
const BOTTOM_MARGIN_RATIO := 0.055
const BUTTON_GAP_RATIO := 0.35
const SAFE_MARGIN_MIN := 8.0
const CONTROL_ANCHOR_MOVEMENT := "movement_anchor_rect"
const CONTROL_ANCHOR_ACTION := "action_anchor_rect"
const MOBILE_PILLAR_HUD_LIFTED_KEY := "mobile_pillar_hud_lifted"
const SIDE_STRIP_WIDTH_RATIO := 1.0
const SIDE_STRIP_MAX_RADIUS_RATIO := 6.4
const SIDE_STRIP_EDGE_RADIUS_RATIO := 0.55
const SIDE_STRIP_BOTTOM_RADIUS_RATIO := 0.70
const SIDE_STRIP_INSET_RATIO := 0.035
const SIDE_STRIP_BOTTOM_INSET_RATIO := 0.055
const FIELD_HEIGHT_FALLBACK := 750.0
const PILLAR_HUD_LEFT_CENTER_X_OFFSET := 95.0
const PILLAR_HUD_LEFT_CENTER_BOTTOM_OFFSET := 65.0
const PILLAR_HUD_RIGHT_CENTER_X_OFFSET := 80.0
const PILLAR_HUD_RIGHT_CENTER_BOTTOM_OFFSET := 80.0
const PILLAR_HUD_LEFT_AVOID_HALF_WIDTH := 165.0
const PILLAR_HUD_LEFT_AVOID_TOP := 230.0
const PILLAR_HUD_LEFT_AVOID_BOTTOM := 105.0
const PILLAR_HUD_RIGHT_AVOID_HALF_WIDTH := 125.0
const PILLAR_HUD_RIGHT_AVOID_TOP := 125.0
const PILLAR_HUD_RIGHT_AVOID_BOTTOM := 125.0
const PILLAR_HUD_VERTICAL_CLEARANCE := 18.0
const MOVEMENT_PAD_KEY := "movement_pad_rect"
const MOVEMENT_PAD_DEADZONE_RATIO := 0.20
const MOVEMENT_PAD_HIT_GRACE_RATIO := 0.52
const BUTTON_HIT_RADIUS_RATIO := 1.42
const ACTIVE_ALPHA := 0.44
const IDLE_ALPHA := 0.24
const OUTLINE_ALPHA := 0.58

var active_touches: Dictionary = {}
var pressed_actions: Dictionary = {}
var controls_enabled := false

# 모바일 ACCEPT 버튼 → 좌클릭 계약 정적 채널. 모바일 런타임은
# emulate_mouse_from_touch가 모든 터치를 합성 LMB로 바꿔 입력 리더의 raw
# 마우스 폴링(Input.is_mouse_button_pressed)이 신뢰 불가하므로, 화면
# ACCEPT 버튼의 눌림을 정적 채널로 게시하고 리더가 mouse_left에 합산해
# 소비한다(리더는 컨트롤 인스턴스를 모르므로 static). 게시는 실 입력
# 경로(_sync_actions)에서만 일어나고 release_all이 반드시 내린다.
static var _touch_accept_pressed_static := false


static func is_touch_accept_pressed() -> bool:
	return _touch_accept_pressed_static


# 씬 teardown처럼 인스턴스가 이미 사라졌을 수 있는 경로용 강제 정리 —
# 수동 Input.action_press 잔존과 정적 accept 채널 누출을 함께 내린다.
static func force_release_static() -> void:
	for action in ACTIONS:
		Input.action_release(str(action))
	_touch_accept_pressed_static = false


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not controls_enabled:
		active_touches.clear()
		release_all()


func handle_input(event: InputEvent, view_size: Vector2, enabled: bool = true, layout_context: Dictionary = {}) -> bool:
	set_controls_enabled(enabled)
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return false

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if not controls_enabled:
			# disabled(모달) 윈도우의 터치는 기록조차 하지 않는다 — 여기서
			# active_touches에 넣으면 재활성화 프레임에 phantom ACCEPT로
			# 부활한다. 눌려 있던 손가락도 지금 내린다.
			active_touches.erase(touch_event.index)
			release_all()
			return false
		if touch_event.pressed:
			active_touches[touch_event.index] = touch_event.position
		else:
			active_touches.erase(touch_event.index)
		_sync_actions(view_size, layout_context)
		return _point_hits_any_control(touch_event.position, view_size, layout_context)

	var drag_event: InputEventScreenDrag = event
	if not controls_enabled:
		active_touches.erase(drag_event.index)
		release_all()
		return false
	if not active_touches.has(drag_event.index):
		# enabled 상태에서 press를 본 적 없는 orphan drag(모달 중 시작된
		# 드래그가 해제 후 흘러들어오는 경로)는 phantom finger로 등록하지
		# 않는다.
		return false
	active_touches[drag_event.index] = drag_event.position
	_sync_actions(view_size, layout_context)
	return _point_hits_any_control(drag_event.position, view_size, layout_context)


func draw(canvas: CanvasItem, view_size: Vector2, layout_context: Dictionary = {}) -> void:
	if canvas == null or not _should_draw():
		return
	var layout: Dictionary = _build_layout(view_size, layout_context)
	_draw_movement_pad(canvas, layout)
	_draw_button(canvas, layout, ACTION_UP, "up")
	_draw_button(canvas, layout, ACTION_DOWN, "down")
	_draw_button(canvas, layout, ACTION_ACCEPT, "accept")


func release_all() -> void:
	for action in pressed_actions.keys():
		Input.action_release(str(action))
	pressed_actions.clear()
	_touch_accept_pressed_static = false


func _sync_actions(view_size: Vector2, layout_context: Dictionary = {}) -> void:
	var wanted := {}
	for action in ACTIONS:
		wanted[action] = false

	for position in active_touches.values():
		var action: String = _get_action_at_position(position, view_size, layout_context)
		if action != "":
			wanted[action] = true

	for action in ACTIONS:
		var should_press: bool = bool(wanted.get(action, false))
		var is_pressed: bool = pressed_actions.has(action)
		if should_press and not is_pressed:
			Input.action_press(action)
			pressed_actions[action] = true
		elif not should_press and is_pressed:
			Input.action_release(action)
			pressed_actions.erase(action)
	_touch_accept_pressed_static = pressed_actions.has(ACTION_ACCEPT)


func _should_draw() -> bool:
	return controls_enabled and (_is_mobile_platform() or not active_touches.is_empty())


func _is_mobile_platform() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


func _build_layout(view_size: Vector2, layout_context: Dictionary = {}) -> Dictionary:
	var safe_rect: Rect2 = _build_safe_rect(view_size)
	var min_axis: float = max(1.0, min(safe_rect.size.x, safe_rect.size.y))
	var preferred_radius: float = clamp(min_axis * 0.07, MIN_RADIUS, MAX_RADIUS)
	var anchor_rects: Dictionary = _get_control_anchor_rects(safe_rect, layout_context)
	var radius: float = _fit_radius_to_anchor_rects(preferred_radius, anchor_rects)
	var gap: float = radius * BUTTON_GAP_RATIO
	var movement_rect: Rect2 = _get_rect(anchor_rects, CONTROL_ANCHOR_MOVEMENT)
	var action_rect: Rect2 = _get_rect(anchor_rects, CONTROL_ANCHOR_ACTION)
	var movement_edge_margin: float = _get_anchor_edge_margin(movement_rect, safe_rect, radius)
	var movement_bottom_margin: float = _get_anchor_bottom_margin(movement_rect, safe_rect, radius)
	var action_edge_margin: float = _get_anchor_edge_margin(action_rect, safe_rect, radius)
	var action_bottom_margin: float = _get_anchor_bottom_margin(action_rect, safe_rect, radius)

	var left_center := movement_rect.position + Vector2(
		movement_edge_margin + radius,
		movement_rect.size.y - movement_bottom_margin - radius
	)
	var right_center := left_center + Vector2(radius * 2.0 + gap, 0.0)
	var action_center := action_rect.position + Vector2(
		action_rect.size.x - action_edge_margin - radius,
		action_rect.size.y - action_bottom_margin - radius
	)
	var down_center := action_center - Vector2(radius * 2.0 + gap, 0.0)
	var up_center := down_center - Vector2(0.0, radius * 2.0 + gap)

	return {
		"radius": radius,
		MOVEMENT_PAD_KEY: Rect2(
			Vector2(left_center.x - radius, left_center.y - radius),
			Vector2(right_center.x - left_center.x + radius * 2.0, radius * 2.0)
		),
		"movement_pad_deadzone": radius * MOVEMENT_PAD_DEADZONE_RATIO,
		ACTION_LEFT: left_center,
		ACTION_RIGHT: right_center,
		ACTION_UP: up_center,
		ACTION_DOWN: down_center,
		ACTION_ACCEPT: action_center,
	}


func _build_safe_rect(view_size: Vector2) -> Rect2:
	var fallback := Rect2(Vector2.ZERO, view_size)
	if not _is_mobile_platform():
		return fallback
	var safe_rect: Rect2 = _get_scaled_display_safe_rect(view_size)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return fallback.grow_individual(
			-SAFE_MARGIN_MIN,
			-SAFE_MARGIN_MIN,
			-SAFE_MARGIN_MIN,
			-SAFE_MARGIN_MIN
		)
	return safe_rect.intersection(fallback)


func _get_control_anchor_rects(safe_rect: Rect2, layout_context: Dictionary) -> Dictionary:
	var side_anchor_rects: Dictionary = _get_side_anchor_rects(safe_rect, layout_context)
	if not side_anchor_rects.is_empty():
		return side_anchor_rects
	var playfield_anchor_rects: Dictionary = _get_playfield_anchor_rects(safe_rect, layout_context)
	if not playfield_anchor_rects.is_empty():
		return playfield_anchor_rects
	return {
		CONTROL_ANCHOR_MOVEMENT: safe_rect,
		CONTROL_ANCHOR_ACTION: safe_rect,
	}


func _get_side_anchor_rects(safe_rect: Rect2, layout_context: Dictionary) -> Dictionary:
	if not _is_mobile_platform():
		return {}
	var game_offset: Vector2 = _get_vector2(layout_context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(layout_context, "game_size", Vector2.ZERO)
	if game_size.x <= 0.0 or game_size.y <= 0.0:
		return {}
	var game_rect := Rect2(game_offset, game_size).intersection(safe_rect)
	if game_rect.size.x <= 0.0 or game_rect.size.y <= 0.0:
		return {}

	var min_width: float = _get_min_anchor_width(MIN_RADIUS)
	if safe_rect.size.y < _get_min_anchor_height(MIN_RADIUS):
		return {}
	var left_side := Rect2(
		safe_rect.position,
		Vector2(max(0.0, game_rect.position.x - safe_rect.position.x), safe_rect.size.y)
	)
	var right_side := Rect2(
		Vector2(game_rect.end.x, safe_rect.position.y),
		Vector2(max(0.0, safe_rect.end.x - game_rect.end.x), safe_rect.size.y)
	)
	if bool(layout_context.get(MOBILE_PILLAR_HUD_LIFTED_KEY, false)):
		if left_side.size.x < min_width or right_side.size.x < min_width:
			return {}
		return {
			CONTROL_ANCHOR_MOVEMENT: _get_outer_side_strip(left_side, true, min_width),
			CONTROL_ANCHOR_ACTION: _get_outer_side_strip(right_side, false, min_width),
		}
	var avoid_rects: Dictionary = _get_pillar_hud_avoid_rects(safe_rect, layout_context, game_rect)
	var left_anchor: Rect2 = _get_outer_anchor_before_avoid(left_side, _get_rect(avoid_rects, "left"), true, min_width)
	var right_anchor: Rect2 = _get_outer_anchor_before_avoid(right_side, _get_rect(avoid_rects, "right"), false, min_width)
	if left_anchor.size.x >= min_width and right_anchor.size.x >= min_width:
		return {
			CONTROL_ANCHOR_MOVEMENT: _get_outer_side_strip(left_anchor, true, min_width),
			CONTROL_ANCHOR_ACTION: _get_outer_side_strip(right_anchor, false, min_width),
		}
	left_anchor = _get_anchor_above_avoid(left_side, _get_rect(avoid_rects, "left"), min_width)
	right_anchor = _get_anchor_above_avoid(right_side, _get_rect(avoid_rects, "right"), min_width)
	if left_anchor.size.x >= min_width and right_anchor.size.x >= min_width:
		return {
			CONTROL_ANCHOR_MOVEMENT: _get_outer_side_strip(left_anchor, true, min_width),
			CONTROL_ANCHOR_ACTION: _get_outer_side_strip(right_anchor, false, min_width),
		}
	if left_side.size.x < min_width or right_side.size.x < min_width:
		return {}
	return {
		CONTROL_ANCHOR_MOVEMENT: _get_outer_side_strip(left_side, true, min_width),
		CONTROL_ANCHOR_ACTION: _get_outer_side_strip(right_side, false, min_width),
	}


func _get_playfield_anchor_rects(safe_rect: Rect2, layout_context: Dictionary) -> Dictionary:
	var game_offset: Vector2 = _get_vector2(layout_context, "game_offset", Vector2.ZERO)
	var game_size: Vector2 = _get_vector2(layout_context, "game_size", Vector2.ZERO)
	var playfield_rect := Rect2(game_offset, game_size).intersection(safe_rect)
	var min_width: float = _get_min_anchor_width(MIN_RADIUS)
	if playfield_rect.size.x < min_width * 2.0 or playfield_rect.size.y < _get_min_anchor_height(MIN_RADIUS):
		return {}
	var half_width: float = playfield_rect.size.x * 0.5
	return {
		CONTROL_ANCHOR_MOVEMENT: Rect2(playfield_rect.position, Vector2(half_width, playfield_rect.size.y)),
		CONTROL_ANCHOR_ACTION: Rect2(
			Vector2(playfield_rect.position.x + half_width, playfield_rect.position.y),
			Vector2(half_width, playfield_rect.size.y)
		),
	}


func _get_outer_side_strip(side_rect: Rect2, is_left: bool, min_width: float) -> Rect2:
	var preferred_width: float = max(min_width, side_rect.size.x * SIDE_STRIP_WIDTH_RATIO)
	var max_width: float = max(min_width, MAX_RADIUS * SIDE_STRIP_MAX_RADIUS_RATIO)
	var strip_width: float = min(side_rect.size.x, min(preferred_width, max_width))
	if is_left:
		return Rect2(side_rect.position, Vector2(strip_width, side_rect.size.y))
	return Rect2(
		Vector2(side_rect.end.x - strip_width, side_rect.position.y),
		Vector2(strip_width, side_rect.size.y)
	)


func _get_pillar_hud_avoid_rects(safe_rect: Rect2, layout_context: Dictionary, game_rect: Rect2) -> Dictionary:
	var field_height: float = max(1.0, float(layout_context.get("field_height", FIELD_HEIGHT_FALLBACK)))
	var scale_factor: float = game_rect.size.y / field_height
	var bottom_y: float = game_rect.position.y + game_rect.size.y
	var left_center := Vector2(
		game_rect.position.x - PILLAR_HUD_LEFT_CENTER_X_OFFSET * scale_factor,
		bottom_y - PILLAR_HUD_LEFT_CENTER_BOTTOM_OFFSET * scale_factor
	)
	var right_center := Vector2(
		game_rect.end.x + PILLAR_HUD_RIGHT_CENTER_X_OFFSET * scale_factor,
		bottom_y - PILLAR_HUD_RIGHT_CENTER_BOTTOM_OFFSET * scale_factor
	)
	var left_rect := Rect2(
		Vector2(
			left_center.x - PILLAR_HUD_LEFT_AVOID_HALF_WIDTH * scale_factor,
			left_center.y - PILLAR_HUD_LEFT_AVOID_TOP * scale_factor
		),
		Vector2(
			PILLAR_HUD_LEFT_AVOID_HALF_WIDTH * 2.0 * scale_factor,
			(PILLAR_HUD_LEFT_AVOID_TOP + PILLAR_HUD_LEFT_AVOID_BOTTOM) * scale_factor
		)
	).intersection(safe_rect)
	var right_rect := Rect2(
		Vector2(
			right_center.x - PILLAR_HUD_RIGHT_AVOID_HALF_WIDTH * scale_factor,
			right_center.y - PILLAR_HUD_RIGHT_AVOID_TOP * scale_factor
		),
		Vector2(
			PILLAR_HUD_RIGHT_AVOID_HALF_WIDTH * 2.0 * scale_factor,
			(PILLAR_HUD_RIGHT_AVOID_TOP + PILLAR_HUD_RIGHT_AVOID_BOTTOM) * scale_factor
		)
	).intersection(safe_rect)
	return {
		"left": left_rect,
		"right": right_rect,
	}


func _get_outer_anchor_before_avoid(side_rect: Rect2, avoid_rect: Rect2, is_left: bool, min_width: float) -> Rect2:
	if side_rect.size.x <= 0.0 or side_rect.size.y <= 0.0 or avoid_rect.size.x <= 0.0:
		return Rect2()
	if is_left:
		var left_width: float = max(0.0, avoid_rect.position.x - side_rect.position.x - PILLAR_HUD_VERTICAL_CLEARANCE)
		if left_width < min_width:
			return Rect2()
		return Rect2(side_rect.position, Vector2(left_width, side_rect.size.y))
	var start_x: float = avoid_rect.end.x + PILLAR_HUD_VERTICAL_CLEARANCE
	var width: float = max(0.0, side_rect.end.x - start_x)
	if width < min_width:
		return Rect2()
	return Rect2(Vector2(start_x, side_rect.position.y), Vector2(width, side_rect.size.y))


func _get_anchor_above_avoid(side_rect: Rect2, avoid_rect: Rect2, min_width: float) -> Rect2:
	if side_rect.size.x < min_width or side_rect.size.y <= 0.0 or avoid_rect.size.y <= 0.0:
		return Rect2()
	var height: float = max(0.0, avoid_rect.position.y - side_rect.position.y - PILLAR_HUD_VERTICAL_CLEARANCE)
	if height < _get_min_anchor_height(MIN_RADIUS):
		return Rect2()
	return Rect2(side_rect.position, Vector2(side_rect.size.x, height))


func _fit_radius_to_anchor_rects(preferred_radius: float, anchor_rects: Dictionary) -> float:
	var fitted_radius: float = preferred_radius
	for key in [CONTROL_ANCHOR_MOVEMENT, CONTROL_ANCHOR_ACTION]:
		var anchor_rect: Rect2 = _get_rect(anchor_rects, key)
		if anchor_rect.size.x > 0.0:
			fitted_radius = min(fitted_radius, _get_max_radius_for_anchor_width(anchor_rect.size.x))
	return clamp(fitted_radius, MIN_RADIUS, preferred_radius)


func _get_min_anchor_width(radius: float) -> float:
	return radius * (4.0 + BUTTON_GAP_RATIO + SIDE_STRIP_EDGE_RADIUS_RATIO)


func _get_min_anchor_height(radius: float) -> float:
	return radius * (4.0 + BUTTON_GAP_RATIO + SIDE_STRIP_BOTTOM_RADIUS_RATIO)


func _get_max_radius_for_anchor_width(anchor_width: float) -> float:
	return max(1.0, anchor_width / (4.0 + BUTTON_GAP_RATIO + SIDE_STRIP_EDGE_RADIUS_RATIO))


func _get_anchor_edge_margin(anchor_rect: Rect2, safe_rect: Rect2, radius: float) -> float:
	if anchor_rect == safe_rect:
		return max(radius * 0.7, anchor_rect.size.x * EDGE_MARGIN_RATIO)
	return max(radius * SIDE_STRIP_EDGE_RADIUS_RATIO, anchor_rect.size.x * SIDE_STRIP_INSET_RATIO)


func _get_anchor_bottom_margin(anchor_rect: Rect2, safe_rect: Rect2, radius: float) -> float:
	if anchor_rect == safe_rect:
		return max(radius * 0.55, anchor_rect.size.y * BOTTOM_MARGIN_RATIO)
	return max(radius * SIDE_STRIP_BOTTOM_RADIUS_RATIO, anchor_rect.size.y * SIDE_STRIP_BOTTOM_INSET_RATIO)


func _get_button_hit_radius(radius: float) -> float:
	return radius * BUTTON_HIT_RADIUS_RATIO


func _get_scaled_display_safe_rect(view_size: Vector2) -> Rect2:
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return Rect2()
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return Rect2(Vector2(safe_area.position), Vector2(safe_area.size))
	var scale := Vector2(
		view_size.x / float(window_size.x),
		view_size.y / float(window_size.y)
	)
	return Rect2(
		Vector2(safe_area.position) * scale,
		Vector2(safe_area.size) * scale
	)


func _get_action_at_position(position: Vector2, view_size: Vector2, layout_context: Dictionary = {}) -> String:
	var layout: Dictionary = _build_layout(view_size, layout_context)
	var horizontal_action: String = _get_horizontal_action_at_position(position, layout)
	if horizontal_action != "":
		return horizontal_action
	var radius: float = float(layout.get("radius", BASE_RADIUS))
	var hit_radius: float = _get_button_hit_radius(radius)
	var best_action := ""
	var best_distance := hit_radius + 1.0
	for action in ACTIONS:
		if action == ACTION_LEFT or action == ACTION_RIGHT:
			continue
		var center: Vector2 = _get_button_center(layout, action)
		var distance: float = position.distance_to(center)
		if distance <= hit_radius and distance < best_distance:
			best_action = action
			best_distance = distance
	return best_action


func _point_hits_any_control(position: Vector2, view_size: Vector2, layout_context: Dictionary = {}) -> bool:
	var layout: Dictionary = _build_layout(view_size, layout_context)
	if _point_hits_movement_pad(position, layout):
		return true
	var radius: float = float(layout.get("radius", BASE_RADIUS))
	var hit_radius: float = _get_button_hit_radius(radius)
	for action in ACTIONS:
		if action == ACTION_LEFT or action == ACTION_RIGHT:
			continue
		var center: Vector2 = _get_button_center(layout, action)
		if position.distance_to(center) <= hit_radius:
			return true
	return false


func _get_horizontal_action_at_position(position: Vector2, layout: Dictionary) -> String:
	if not _point_hits_movement_pad(position, layout):
		return ""
	var left_center: Vector2 = _get_button_center(layout, ACTION_LEFT)
	var right_center: Vector2 = _get_button_center(layout, ACTION_RIGHT)
	var midpoint_x: float = (left_center.x + right_center.x) * 0.5
	var deadzone: float = float(layout.get("movement_pad_deadzone", 0.0))
	if position.x < midpoint_x - deadzone:
		return ACTION_LEFT
	if position.x > midpoint_x + deadzone:
		return ACTION_RIGHT
	return ""


func _point_hits_movement_pad(position: Vector2, layout: Dictionary) -> bool:
	var rect: Rect2 = _get_rect(layout, MOVEMENT_PAD_KEY)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	var radius: float = float(layout.get("radius", BASE_RADIUS))
	var hit_radius: float = radius * (1.0 + MOVEMENT_PAD_HIT_GRACE_RATIO)
	var center_y: float = rect.position.y + rect.size.y * 0.5
	var left_center := Vector2(rect.position.x + radius, center_y)
	var right_center := Vector2(rect.end.x - radius, center_y)
	if abs(position.y - center_y) > hit_radius:
		return false
	if position.x >= left_center.x and position.x <= right_center.x:
		return true
	return position.distance_to(left_center) <= hit_radius or position.distance_to(right_center) <= hit_radius


func _draw_movement_pad(canvas: CanvasItem, layout: Dictionary) -> void:
	var left_center: Vector2 = _get_button_center(layout, ACTION_LEFT)
	var right_center: Vector2 = _get_button_center(layout, ACTION_RIGHT)
	var radius: float = float(layout.get("radius", BASE_RADIUS))
	var midpoint_x: float = (left_center.x + right_center.x) * 0.5
	var base_fill := Color(0.06, 0.12, 0.18, IDLE_ALPHA)
	var active_fill := Color(0.16, 0.56, 0.86, ACTIVE_ALPHA)
	var outline_color := Color(0.58, 0.84, 1.0, OUTLINE_ALPHA)
	var icon_color := Color(0.86, 0.96, 1.0, 0.88)
	var center_rect := Rect2(
		Vector2(left_center.x, left_center.y - radius),
		Vector2(right_center.x - left_center.x, radius * 2.0)
	)

	canvas.draw_rect(center_rect, base_fill)
	canvas.draw_circle(left_center, radius, base_fill)
	canvas.draw_circle(right_center, radius, base_fill)
	if pressed_actions.has(ACTION_LEFT):
		var left_active_rect := Rect2(
			Vector2(left_center.x, left_center.y - radius),
			Vector2(midpoint_x - left_center.x, radius * 2.0)
		)
		canvas.draw_circle(left_center, radius, active_fill)
		canvas.draw_rect(left_active_rect, active_fill)
	if pressed_actions.has(ACTION_RIGHT):
		var right_active_rect := Rect2(
			Vector2(midpoint_x, right_center.y - radius),
			Vector2(right_center.x - midpoint_x, radius * 2.0)
		)
		canvas.draw_rect(right_active_rect, active_fill)
		canvas.draw_circle(right_center, radius, active_fill)

	canvas.draw_arc(left_center, radius, PI * 0.5, PI * 1.5, 32, outline_color, 2.0, true)
	canvas.draw_arc(right_center, radius, -PI * 0.5, PI * 0.5, 32, outline_color, 2.0, true)
	canvas.draw_line(left_center + Vector2(0.0, -radius), right_center + Vector2(0.0, -radius), outline_color, 2.0, true)
	canvas.draw_line(left_center + Vector2(0.0, radius), right_center + Vector2(0.0, radius), outline_color, 2.0, true)
	canvas.draw_line(
		Vector2(midpoint_x, left_center.y - radius * 0.55),
		Vector2(midpoint_x, left_center.y + radius * 0.55),
		Color(0.86, 0.96, 1.0, 0.34),
		2.0,
		true
	)
	_draw_arrow(canvas, left_center, radius, "left", icon_color)
	_draw_arrow(canvas, right_center, radius, "right", icon_color)


func _draw_button(canvas: CanvasItem, layout: Dictionary, action: String, icon: String) -> void:
	var center: Vector2 = _get_button_center(layout, action)
	var radius: float = float(layout.get("radius", BASE_RADIUS))
	var active: bool = pressed_actions.has(action)
	var fill_alpha: float = ACTIVE_ALPHA if active else IDLE_ALPHA
	var fill_color := Color(0.06, 0.12, 0.18, fill_alpha)
	var outline_color := Color(0.58, 0.84, 1.0, OUTLINE_ALPHA)
	var icon_color := Color(0.86, 0.96, 1.0, 0.86)

	canvas.draw_circle(center, radius, fill_color)
	canvas.draw_arc(center, radius, 0.0, TAU, 56, outline_color, 2.0, true)
	if icon == "accept":
		canvas.draw_circle(center, radius * 0.27, icon_color)
		canvas.draw_arc(center, radius * 0.44, 0.0, TAU, 40, icon_color, 2.0, true)
		return
	_draw_arrow(canvas, center, radius, icon, icon_color)


func _draw_arrow(canvas: CanvasItem, center: Vector2, radius: float, direction: String, color: Color) -> void:
	var size: float = radius * 0.42
	var points := PackedVector2Array()
	if direction == "left":
		points = PackedVector2Array([
			center + Vector2(-size, 0.0),
			center + Vector2(size * 0.42, -size * 0.82),
			center + Vector2(size * 0.42, size * 0.82),
		])
	elif direction == "right":
		points = PackedVector2Array([
			center + Vector2(size, 0.0),
			center + Vector2(-size * 0.42, -size * 0.82),
			center + Vector2(-size * 0.42, size * 0.82),
		])
	elif direction == "up":
		points = PackedVector2Array([
			center + Vector2(0.0, -size),
			center + Vector2(-size * 0.82, size * 0.42),
			center + Vector2(size * 0.82, size * 0.42),
		])
	else:
		points = PackedVector2Array([
			center + Vector2(0.0, size),
			center + Vector2(-size * 0.82, -size * 0.42),
			center + Vector2(size * 0.82, -size * 0.42),
		])
	canvas.draw_colored_polygon(points, color)


func _get_button_center(layout: Dictionary, action: String) -> Vector2:
	var value: Variant = layout.get(action, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_rect(layout: Dictionary, key: String) -> Rect2:
	var value: Variant = layout.get(key, Rect2())
	if value is Rect2:
		return value
	return Rect2()


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback
