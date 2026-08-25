extends RefCounted

var wave_timer_frames := 0.0
var wave_life_frames := 0.0
var wave_center := Vector2.ZERO
var wave_seed := 0.0
var phase := 0.0
var paired_proc_timer_frames := 0.0
var paired_proc_effect_type := ""
# paired 무료 우회는 "같은 물리 히트의 두 번째 CC 성분"에만 허용된다. 다른 소스의
# 별개 적대 이벤트가 3프레임 안에 반대 CC로 들어와도 확률·기력 없이 공짜로 막히면 안 되므로,
# 기록된 source와 일치할 때만 우회한다.
var paired_proc_source := ""
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
	paired_proc_source = ""
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
			paired_proc_source = ""
	if wave_timer_frames > 0.0:
		wave_timer_frames = max(0.0, wave_timer_frames - step)
		if wave_timer_frames <= 0.0:
			wave_life_frames = 0.0


func is_wave_active() -> bool:
	return wave_timer_frames > 0.0


func consume_paired_proc_bypass(source: String, normalized_effect_type: String) -> bool:
	if paired_proc_timer_frames <= 0.0:
		paired_proc_effect_type = ""
		paired_proc_source = ""
		return false
	if paired_proc_effect_type == "" or paired_proc_effect_type == normalized_effect_type:
		return false
	# 같은 물리 히트(같은 source)의 반대 CC 성분일 때만 무료 우회. 다른 소스의 별개 히트는
	# 정상 확률·기력 경로를 타야 한다(교차-소스 무료 차단 익스플로잇 차단).
	if paired_proc_source != source:
		return false
	last_blocked_source = source
	last_blocked_effect_type = normalized_effect_type
	# 무료 우회권은 "같은 히트의 두 번째 CC 성분 1회"만 — 사용 즉시 창을 닫아(소모)
	# 3프레임 창 안에서 같은 반대 CC가 반복 호출돼도 무료로 막히지 않게 한다(세 번째부터는
	# 정상 확률·기력 경로). record_block(성공 롤)만 창을 다시 연다.
	paired_proc_timer_frames = 0.0
	paired_proc_effect_type = ""
	paired_proc_source = ""
	return true


func start_wave(center: Vector2, life_frames: float) -> void:
	wave_center = center
	wave_life_frames = life_frames
	wave_timer_frames = life_frames
	wave_seed = randf_range(0.0, TAU)


func record_block(source: String, normalized_effect_type: String, paired_window_frames: float) -> void:
	paired_proc_timer_frames = paired_window_frames
	paired_proc_effect_type = normalized_effect_type
	paired_proc_source = source
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
