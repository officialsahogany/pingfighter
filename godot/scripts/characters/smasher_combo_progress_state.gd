extends RefCounted

const SMASHER_DASH_COMBO_GRACE_FRAMES: float = 40.0
const SMASHER_COMBO_MIN_SKILL_COUNT: int = 2
const SMASHER_COMBO_GAUGE_MAX_COUNT: float = 6.0

var combo_count: int = 0
var dash_combo_grace_timer: float = 0.0
var dash_combo_grace_count: int = 0
var gauge_smooth: float = 0.0


func reset_combo() -> void:
	combo_count = 0
	dash_combo_grace_timer = 0.0
	dash_combo_grace_count = 0
	gauge_smooth = 0.0


func clear_gauge_smooth() -> void:
	gauge_smooth = 0.0


func start_dash_combo_grace() -> void:
	if combo_count >= SMASHER_COMBO_MIN_SKILL_COUNT:
		dash_combo_grace_count = combo_count
		dash_combo_grace_timer = SMASHER_DASH_COMBO_GRACE_FRAMES
	else:
		dash_combo_grace_count = 0
		dash_combo_grace_timer = 0.0
	combo_count = 0


func update_timers(fps_scale: float) -> void:
	if dash_combo_grace_timer > 0.0:
		dash_combo_grace_timer = max(0.0, dash_combo_grace_timer - fps_scale)
		if dash_combo_grace_timer <= 0.0:
			dash_combo_grace_count = 0

	var display_combo: int = combo_count if combo_count > 0 else dash_combo_grace_count
	var target_progress: float = min(1.0, float(display_combo) / SMASHER_COMBO_GAUGE_MAX_COUNT) if display_combo > 0 else 0.0
	var ease: float = 0.18 if target_progress >= gauge_smooth else 0.10
	gauge_smooth += (target_progress - gauge_smooth) * ease * max(1.0, fps_scale)
	if abs(gauge_smooth - target_progress) < 0.001:
		gauge_smooth = target_progress


func register_hit() -> int:
	combo_count += 1
	return combo_count


func get_effective_combo() -> int:
	if dash_combo_grace_timer > 0.0 and dash_combo_grace_count > combo_count:
		return dash_combo_grace_count
	return combo_count


func get_combo_count() -> int:
	return combo_count


func get_dash_combo_grace_timer() -> float:
	return dash_combo_grace_timer


func get_dash_combo_grace_count() -> int:
	return dash_combo_grace_count


func get_gauge_smooth() -> float:
	return gauge_smooth


func get_min_skill_count() -> int:
	return SMASHER_COMBO_MIN_SKILL_COUNT


func get_dash_combo_grace_frames() -> float:
	return SMASHER_DASH_COMBO_GRACE_FRAMES


func get_gauge_max_count() -> float:
	return SMASHER_COMBO_GAUGE_MAX_COUNT
