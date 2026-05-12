extends RefCounted

var wave_timer_frames := 0.0
var wave_life_frames := 0.0
var wave_center := Vector2.ZERO
var wave_seed := 0.0
var phase := 0.0
var paired_proc_timer_frames := 0.0
var paired_proc_effect_type := ""
var last_blocked_source := ""
var last_blocked_effect_type := ""


func clear_runtime() -> void:
	clear_round_state()


func clear_round_state() -> void:
	wave_timer_frames = 0.0
	wave_life_frames = 0.0
	wave_center = Vector2.ZERO
	wave_seed = 0.0
	phase = 0.0
	paired_proc_timer_frames = 0.0
	paired_proc_effect_type = ""
	last_blocked_source = ""
	last_blocked_effect_type = ""


func update(fps_scale: float, equipped: bool) -> void:
	if not equipped:
		if wave_timer_frames > 0.0 or paired_proc_timer_frames > 0.0:
			clear_runtime()
		return
	var step: float = max(0.0, fps_scale)
	phase = fmod(phase + step * 0.055, TAU * 1024.0)
	if paired_proc_timer_frames > 0.0:
		paired_proc_timer_frames = max(0.0, paired_proc_timer_frames - step)
		if paired_proc_timer_frames <= 0.0:
			paired_proc_effect_type = ""
	if wave_timer_frames > 0.0:
		wave_timer_frames = max(0.0, wave_timer_frames - step)
		if wave_timer_frames <= 0.0:
			wave_life_frames = 0.0


func is_wave_active() -> bool:
	return wave_timer_frames > 0.0


func consume_paired_proc_bypass(source: String, normalized_effect_type: String) -> bool:
	if paired_proc_timer_frames <= 0.0:
		paired_proc_effect_type = ""
		return false
	if paired_proc_effect_type == "" or paired_proc_effect_type == normalized_effect_type:
		return false
	last_blocked_source = source
	last_blocked_effect_type = normalized_effect_type
	return true


func start_wave(center: Vector2, life_frames: float) -> void:
	wave_center = center
	wave_life_frames = life_frames
	wave_timer_frames = life_frames
	wave_seed = randf_range(0.0, TAU)


func record_block(source: String, normalized_effect_type: String, paired_window_frames: float) -> void:
	paired_proc_timer_frames = paired_window_frames
	paired_proc_effect_type = normalized_effect_type
	last_blocked_source = source
	last_blocked_effect_type = normalized_effect_type


func get_context(equipped: bool, active: bool, trigger_chance_pct: float, gauge_cost: float) -> Dictionary:
	return {
		"equipped": equipped,
		"active": active,
		"trigger_chance_pct": trigger_chance_pct,
		"gauge_cost": gauge_cost,
		"wave_active": is_wave_active(),
		"wave_timer_frames": wave_timer_frames,
		"last_blocked_source": last_blocked_source,
		"last_blocked_effect_type": last_blocked_effect_type,
	}
