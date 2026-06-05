extends RefCounted

const PHASE_HIDDEN := "hidden"
const PHASE_DELAY := "delay"
const PHASE_UNFURLING := "unfurling"
const PHASE_VISIBLE := "visible"

const SCROLL_DELAY := 1.10
const SCROLL_UNFURL_DURATION := 0.95

# Extended downward (was 850) so the acquired-item list has room for the
# separate active / passive / mythic bands without cramping the cards.
const SCROLL_REGION_RECT := Rect2(Vector2(340.0, 96.0), Vector2(1240.0, 904.0))
const SCROLL_CONTENT_MARGIN := Vector4(70.0, 90.0, 70.0, 76.0)
const SCROLL_DRAG_VIEW_MARGIN := 72.0


static func update_phase(
	phase: String,
	timer: float,
	delta: float,
	blocked: bool,
	all_boxes_opened: bool,
	scroll_delay: float,
	unfurl_duration: float
) -> Dictionary:
	if delta <= 0.0 or blocked:
		return {
			"phase": phase,
			"timer": timer,
		}
	match phase:
		PHASE_HIDDEN:
			if all_boxes_opened:
				return {
					"phase": PHASE_DELAY,
					"timer": 0.0,
				}
		PHASE_DELAY:
			var delay_timer: float = timer + delta
			if delay_timer >= scroll_delay:
				return {
					"phase": PHASE_UNFURLING,
					"timer": 0.0,
				}
			return {
				"phase": PHASE_DELAY,
				"timer": delay_timer,
			}
		PHASE_UNFURLING:
			var unfurl_timer: float = timer + delta
			if unfurl_timer >= unfurl_duration:
				return {
					"phase": PHASE_VISIBLE,
					"timer": unfurl_duration,
				}
			return {
				"phase": PHASE_UNFURLING,
				"timer": unfurl_timer,
			}
		PHASE_VISIBLE:
			pass
	return {
		"phase": phase,
		"timer": timer,
	}


static func get_unfurl_progress(phase: String, timer: float, unfurl_duration: float) -> float:
	match phase:
		PHASE_HIDDEN, PHASE_DELAY:
			return 0.0
		PHASE_UNFURLING:
			return smooth01(timer / max(0.001, unfurl_duration))
		PHASE_VISIBLE:
			return 1.0
	return 0.0


static func get_box_global_alpha(phase: String, timer: float, unfurl_duration: float) -> float:
	match phase:
		PHASE_HIDDEN, PHASE_DELAY:
			return 1.0
		PHASE_UNFURLING:
			var t: float = timer / max(0.001, unfurl_duration)
			return clamp(1.0 - smooth01(t) * 0.96, 0.04, 1.0)
		PHASE_VISIBLE:
			return 0.04
	return 1.0


static func get_base_rect(
	draw_scale: float,
	source_rect: Rect2
) -> Rect2:
	return Rect2(source_rect.position * draw_scale, source_rect.size * draw_scale)


static func get_full_rect(
	draw_scale: float,
	position_offset: Vector2,
	source_rect: Rect2
) -> Rect2:
	var base_rect: Rect2 = get_base_rect(draw_scale, source_rect)
	return Rect2(base_rect.position + position_offset, base_rect.size)


static func get_region_full_rect(draw_scale: float, position_offset: Vector2) -> Rect2:
	return get_full_rect(draw_scale, position_offset, SCROLL_REGION_RECT)


static func clamp_region_offset(candidate_offset: Vector2, draw_scale: float, view_size: Vector2) -> Vector2:
	return clamp_offset(candidate_offset, draw_scale, view_size, SCROLL_DRAG_VIEW_MARGIN, SCROLL_REGION_RECT)


static func get_region_drag_offset(
	mouse_position: Vector2,
	grab_offset: Vector2,
	draw_scale: float,
	view_size: Vector2
) -> Vector2:
	var base_rect: Rect2 = get_base_rect(draw_scale, SCROLL_REGION_RECT)
	return clamp_region_offset(mouse_position - grab_offset - base_rect.position, draw_scale, view_size)


static func clamp_offset(
	candidate_offset: Vector2,
	draw_scale: float,
	view_size: Vector2,
	keep_visible_margin: float,
	source_rect: Rect2
) -> Vector2:
	var base_rect: Rect2 = get_base_rect(draw_scale, source_rect)
	var scaled_margin: float = keep_visible_margin * draw_scale
	var min_x: float = scaled_margin - base_rect.end.x
	var max_x: float = view_size.x - scaled_margin - base_rect.position.x
	var min_y: float = scaled_margin - base_rect.end.y
	var max_y: float = view_size.y - scaled_margin - base_rect.position.y
	return Vector2(
		clamp_axis(candidate_offset.x, min_x, max_x),
		clamp_axis(candidate_offset.y, min_y, max_y)
	)


static func clamp_axis(value: float, min_value: float, max_value: float) -> float:
	if min_value > max_value:
		return (min_value + max_value) * 0.5
	return clampf(value, min_value, max_value)


static func smooth01(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
