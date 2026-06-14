extends RefCounted

const MODE_WALK := "walk"
const MODE_STRIKE := "strike"
const MODE_CAST := "cast"

const SHEET_COLS := 5
const SHEET_ROWS := 5
const SHEET_FRAME_COUNT := 25
const IDLE_FRAME := 12
const FLIGHT_FPS_MIN := 4.8
const FLIGHT_FPS_MAX := 13.5
const WALK_DRAW_SIZE := Vector2(82.0, 82.0)
const WALK_Y_OFFSET := -6.0
const STRIKE_START_FRAME := 18
const STRIKE_IMPACT_FRAME := 22
const STRIKE_FRAME_TIME := 0.036
const STRIKE_FOLLOW_HOLD := 0.12
const STRIKE_MAX_GAP := 220.0
const STRIKE_X_TOLERANCE := 16.0
const PHYSICS_TICKS := 72.0
const STRIKE_DRAW_SIZE := Vector2(104.0, 104.0)
const STRIKE_Y_OFFSET := -12.0
const CAST_DRAW_SIZE := Vector2(104.0, 104.0)
const CAST_Y_OFFSET := -12.0

var strike_active := false
var strike_elapsed := 0.0
var strike_start_frame := 0
var strike_latched := false
# Walk-animation phase, in frames. Advanced by advance_walk_phase() from the companion's
# update_lingpet tick instead of raw wall-clock time. This is what makes the walk frame
# FREEZE when update_lingpet is skipped by a pause branch (power-smash freeze, mythic
# cinematic, scoreboard fade): a wall-clock frame keeps cycling — marching in place — while
# the frozen pet's position never advances. Consumers that never call advance_walk_phase
# (the soul-clone's own animator instance) keep the wall-clock fallback below.
var walk_phase := 0.0
var _walk_phase_driven := false


func reset_all() -> void:
	strike_active = false
	strike_elapsed = 0.0
	strike_start_frame = 0
	strike_latched = false


func advance(delta: float) -> void:
	if not strike_active:
		return
	strike_elapsed += maxf(0.0, delta)
	var last_frame: int = SHEET_FRAME_COUNT - 1
	var play_frames: int = maxi(0, last_frame - strike_start_frame)
	var total: float = float(play_frames) * STRIKE_FRAME_TIME + STRIKE_FOLLOW_HOLD
	if strike_elapsed >= total:
		strike_active = false
		strike_elapsed = 0.0


func begin_strike(start_frame: int) -> void:
	strike_active = true
	strike_elapsed = 0.0
	strike_start_frame = clampi(start_frame, STRIKE_START_FRAME, SHEET_FRAME_COUNT - 1)


func reset_latch() -> void:
	strike_latched = false


func get_strike_frame() -> int:
	var last_frame: int = SHEET_FRAME_COUNT - 1
	if STRIKE_FRAME_TIME <= 0.0:
		return last_frame
	var advanced: int = int(strike_elapsed / STRIKE_FRAME_TIME)
	return clampi(strike_start_frame + advanced, strike_start_frame, last_frame)


func get_cast_frame(windup_elapsed: float, windup_seconds: float) -> int:
	var max_frame: int = maxi(0, SHEET_FRAME_COUNT - 1)
	if windup_seconds <= 0.0:
		return max_frame
	var progress: float = clampf(windup_elapsed / windup_seconds, 0.0, 1.0)
	return clampi(int(progress * float(SHEET_FRAME_COUNT)), 0, max_frame)


func advance_walk_phase(delta: float, speed_ratio: float) -> void:
	# Accumulate the walk phase only while the pet is actually moving. Called once per
	# companion update_lingpet tick, so it stops accumulating the moment that tick is
	# skipped (pause branches) — freezing the walk frame instead of marching in place.
	_walk_phase_driven = true
	var ratio := clampf(speed_ratio, 0.0, 1.0)
	if ratio <= 0.0:
		return
	var fps: float = lerpf(FLIGHT_FPS_MIN, FLIGHT_FPS_MAX, ratio)
	walk_phase += maxf(0.0, delta) * fps


func get_walk_frame(patrol_pause: float, ticks_msec: int = -1, speed_ratio: float = 0.0) -> int:
	var ratio := clampf(speed_ratio, 0.0, 1.0)
	if ratio <= 0.0:
		return clampi(IDLE_FRAME, 0, SHEET_FRAME_COUNT - 1)
	if _walk_phase_driven:
		return int(walk_phase) % SHEET_FRAME_COUNT
	var current_ticks: int = Time.get_ticks_msec() if ticks_msec < 0 else ticks_msec
	var elapsed: float = float(current_ticks) / 1000.0
	var fps: float = lerpf(FLIGHT_FPS_MIN, FLIGHT_FPS_MAX, ratio)
	return int(elapsed * fps) % SHEET_FRAME_COUNT


func get_strike_start_frame(frames_to_contact: float) -> int:
	var per_steps: float = STRIKE_FRAME_TIME * PHYSICS_TICKS
	if per_steps <= 0.0:
		return STRIKE_IMPACT_FRAME
	var start: int = STRIKE_IMPACT_FRAME - int(round(frames_to_contact / per_steps))
	if start > STRIKE_IMPACT_FRAME:
		start = STRIKE_IMPACT_FRAME
	if start < STRIKE_START_FRAME:
		return -1
	return start


func build_draw_rects(
	texture: Texture2D,
	mode: String,
	center: Vector2,
	patrol_pause: float,
	windup_elapsed: float,
	windup_seconds: float,
	speed_ratio: float = 0.0,
	draw_size_override: Vector2 = Vector2.ZERO
) -> Dictionary:
	if texture == null:
		return {}
	var frame: int = get_frame(mode, patrol_pause, windup_elapsed, windup_seconds, speed_ratio)
	var draw_size: Vector2 = _resolve_draw_size(mode, draw_size_override)
	return {
		"frame": frame,
		"source": get_source_rect(texture, frame),
		"dest": Rect2(center - draw_size * 0.5 + Vector2(0.0, get_y_offset(mode)), draw_size),
	}


func get_frame(mode: String, patrol_pause: float, windup_elapsed: float, windup_seconds: float, speed_ratio: float = 0.0) -> int:
	match mode:
		MODE_CAST:
			return get_cast_frame(windup_elapsed, windup_seconds)
		MODE_STRIKE:
			return get_strike_frame()
		_:
			return get_walk_frame(patrol_pause, -1, speed_ratio)


func get_source_rect(texture: Texture2D, frame: int) -> Rect2:
	if texture == null:
		return Rect2()
	var cols: int = maxi(1, SHEET_COLS)
	var rows: int = maxi(1, SHEET_ROWS)
	var safe_frame: int = clampi(frame, 0, SHEET_FRAME_COUNT - 1)
	var cell_w: float = float(texture.get_width()) / float(cols)
	var cell_h: float = float(texture.get_height()) / float(rows)
	var col: int = safe_frame % cols
	var row: int = floori(float(safe_frame) / float(cols))
	return Rect2(float(col) * cell_w, float(row) * cell_h, cell_w, cell_h)


func get_draw_size(mode: String) -> Vector2:
	match mode:
		MODE_CAST:
			return CAST_DRAW_SIZE
		MODE_STRIKE:
			return STRIKE_DRAW_SIZE
		_:
			return WALK_DRAW_SIZE


func _resolve_draw_size(mode: String, draw_size_override: Vector2) -> Vector2:
	if draw_size_override.x > 0.0 and draw_size_override.y > 0.0:
		return draw_size_override
	return get_draw_size(mode)


func get_y_offset(mode: String) -> float:
	match mode:
		MODE_CAST:
			return CAST_Y_OFFSET
		MODE_STRIKE:
			return STRIKE_Y_OFFSET
		_:
			return WALK_Y_OFFSET
