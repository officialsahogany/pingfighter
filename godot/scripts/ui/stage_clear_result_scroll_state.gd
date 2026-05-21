extends RefCounted

const PHASE_HIDDEN := "hidden"
const PHASE_DELAY := "delay"
const PHASE_UNFURLING := "unfurling"
const PHASE_VISIBLE := "visible"


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


static func smooth01(value: float) -> float:
	var t: float = clamp(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
