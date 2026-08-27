extends RefCounted

const MIN_COOLDOWN_FRAMES := 1200.0
const MAX_COOLDOWN_FRAMES := 2100.0
const DOOR_OPEN_TIME := 60.0
const DOOR_OPEN_DELAY := 30.0
const MACHINE_RISE_TIME := 90.0
const MACHINE_RISE_DELAY := 90.0
const SHOOTING_DELAY := 90.0
const MACHINE_LOWER_TIME := 90.0
const MACHINE_LOWER_DELAY := 30.0
const DOOR_CLOSE_TIME := 60.0
const SHOOT_INTERVAL := 10.0
# Starpoint (special) balloon payout contract: every activation guarantees
# SPECIAL_BALLOON_GUARANTEED_COUNT golden balloons (clamped by how many the volley
# actually shoots), caps at SPECIAL_BALLOON_MAX_COUNT, and rolls exactly
# SPECIAL_BALLOON_PRESENT_CHANCE odds that it pays out above the guaranteed floor.
# The extras gate is followed by a uniform guaranteed+1..min(max, total) draw, so the
# "more than the floor" rate stays fixed regardless of how many balloons are shot.
# A two-balloon volley is already at the floor and pays both as golden.
const SPECIAL_BALLOON_GUARANTEED_COUNT := 2
const SPECIAL_BALLOON_MAX_COUNT := 4
const SPECIAL_BALLOON_PRESENT_CHANCE := 0.75

# Retains the Stage 1 balloon machine's cooldown, phase presentation, and
# per-activation shot plan. The global RNG is deliberate legacy behavior;
# construction consumes only the original initial cooldown roll.
var active := false
var phase := "idle"
var timer_frames := 0.0
var cooldown_timer := 0.0
var door_open_percent := 0.0
var machine_scale := 0.0
var balloon_shoot_timer := 0.0
var balloon_shoot_count := 0
var total_balloon_count := 0
var balloon_shoot_order: Array[int] = []
var balloon_shoot_angles: Array[float] = []
var special_balloon_indices: Array[int] = []


func _init() -> void:
	set_next_cooldown()


func reset() -> void:
	active = false
	phase = "idle"
	timer_frames = 0.0
	door_open_percent = 0.0
	machine_scale = 0.0
	set_next_cooldown()


func update(fps_scale: float, deps: Dictionary, host: Object) -> void:
	if active:
		update_active(fps_scale, deps, host)
	elif cooldown_timer <= 0.0:
		activate()
	else:
		cooldown_timer = max(0.0, cooldown_timer - fps_scale)
		if cooldown_timer <= 0.0:
			activate()


func activate() -> void:
	if active:
		return
	active = true
	phase = "door_opening"
	timer_frames = 0.0
	door_open_percent = 0.0
	machine_scale = 0.0
	balloon_shoot_timer = 0.0
	balloon_shoot_count = 0
	total_balloon_count = randi_range(2, 4)
	balloon_shoot_order = _build_shuffled_indices(total_balloon_count)
	special_balloon_indices = _build_special_indices(total_balloon_count)
	balloon_shoot_angles = _build_shoot_angles(total_balloon_count)


func update_active(fps_scale: float, deps: Dictionary, host: Object) -> void:
	if host != null and host.has_method("_prewarm_active_event_assets"):
		host.call("_prewarm_active_event_assets")
	var phase_started := timer_frames <= 0.0
	timer_frames += fps_scale

	match phase:
		"door_opening":
			if phase_started:
				_play_door_sound(deps)
			door_open_percent = _ease_out_cubic(min(1.0, timer_frames / DOOR_OPEN_TIME))
			if timer_frames >= DOOR_OPEN_TIME:
				set_phase("door_open_wait")
		"door_open_wait":
			if timer_frames >= DOOR_OPEN_DELAY:
				set_phase("machine_rising")
		"machine_rising":
			if phase_started:
				_play_machine_sound(deps)
			machine_scale = _ease_out_cubic(min(1.0, timer_frames / MACHINE_RISE_TIME))
			if timer_frames >= MACHINE_RISE_TIME:
				set_phase("machine_rise_wait")
		"machine_rise_wait":
			if timer_frames >= MACHINE_RISE_DELAY:
				set_phase("shooting")
				balloon_shoot_timer = 0.0
				balloon_shoot_count = 0
		"shooting":
			balloon_shoot_timer += fps_scale
			while balloon_shoot_timer >= SHOOT_INTERVAL and balloon_shoot_count < total_balloon_count:
				if host != null and host.has_method("_shoot_single_balloon"):
					host.call("_shoot_single_balloon", balloon_shoot_count, deps)
				balloon_shoot_count += 1
				balloon_shoot_timer -= SHOOT_INTERVAL
			if balloon_shoot_count >= total_balloon_count:
				set_phase("shooting_wait")
		"shooting_wait":
			if timer_frames >= SHOOTING_DELAY:
				set_phase("machine_lowering")
		"machine_lowering":
			if phase_started:
				_play_machine_sound(deps)
			machine_scale = 1.0 - _ease_in_cubic(min(1.0, timer_frames / MACHINE_LOWER_TIME))
			if timer_frames >= MACHINE_LOWER_TIME:
				set_phase("machine_lower_wait")
		"machine_lower_wait":
			if timer_frames >= MACHINE_LOWER_DELAY:
				set_phase("door_closing")
		"door_closing":
			if phase_started:
				_play_door_sound(deps)
			door_open_percent = 1.0 - _ease_in_cubic(min(1.0, timer_frames / DOOR_CLOSE_TIME))
			if timer_frames >= DOOR_CLOSE_TIME:
				deactivate()


func set_phase(next_phase: String) -> void:
	phase = next_phase
	timer_frames = 0.0


func deactivate() -> void:
	active = false
	phase = "idle"
	timer_frames = 0.0
	door_open_percent = 0.0
	machine_scale = 0.0
	set_next_cooldown()


func set_next_cooldown() -> void:
	cooldown_timer = randf_range(MIN_COOLDOWN_FRAMES, MAX_COOLDOWN_FRAMES)


func _build_shuffled_indices(count: int) -> Array[int]:
	var result: Array[int] = []
	for index in range(count):
		result.append(index)
	result.shuffle()
	return result


func _build_special_indices(count: int) -> Array[int]:
	var candidates: Array[int] = _build_shuffled_indices(count)
	var special_count: int = _roll_special_balloon_count(count)
	var result: Array[int] = []
	for index in range(special_count):
		result.append(candidates[index])
	return result


func _roll_special_balloon_count(count: int) -> int:
	var max_special: int = min(SPECIAL_BALLOON_MAX_COUNT, count)
	if max_special <= 0:
		return 0
	var guaranteed: int = min(SPECIAL_BALLOON_GUARANTEED_COUNT, max_special)
	# The gate roll is consumed unconditionally so an activation always advances the
	# global RNG stream by the same shape, even when the volley already sits at the cap.
	var extras_gate: float = randf()
	if guaranteed >= max_special or extras_gate >= SPECIAL_BALLOON_PRESENT_CHANCE:
		return guaranteed
	return randi_range(guaranteed + 1, max_special)


func _build_shoot_angles(count: int) -> Array[float]:
	var result: Array[float] = []
	for index in range(count):
		result.append(TAU / float(count) * float(index) + randf_range(-PI / 12.0, PI / 12.0))
	result.shuffle()
	return result


func _play_door_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage1_balloon_door"):
		audio.play_stage1_balloon_door()


func _play_machine_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage1_balloon_machine"):
		audio.play_stage1_balloon_machine()


func _ease_out_cubic(value: float) -> float:
	return 1.0 - pow(1.0 - clamp(value, 0.0, 1.0), 3.0)


func _ease_in_cubic(value: float) -> float:
	var clamped: float = clamp(value, 0.0, 1.0)
	return clamped * clamped * clamped
