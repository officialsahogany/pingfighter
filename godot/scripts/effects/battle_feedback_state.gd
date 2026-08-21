extends RefCounted

const GamepadVibrationSettings := preload("res://scripts/core/gamepad_vibration_settings.gd")

const GAUGE_GAIN_FLASH_DURATION := 0.45
const DASH_FLASH_DURATION := 0.55
const DASH_DIVIDER_ANIM_DURATION := 0.60
const PADDLE_HIT_VIBRATION_BASE_SPEED := 7.65
const PADDLE_HIT_VIBRATION_MAX_SPEED := 35.0
const PADDLE_HIT_VIBRATION_MIN_INTERVAL_MSEC := 45
const PADDLE_HIT_VIBRATION_MIN_DURATION := 0.08
const PADDLE_HIT_VIBRATION_MAX_DURATION := 0.16
const PADDLE_HIT_VIBRATION_MIN_WEAK := 0.25
const PADDLE_HIT_VIBRATION_MAX_WEAK := 0.85
const PADDLE_HIT_VIBRATION_MIN_STRONG := 0.45
const PADDLE_HIT_VIBRATION_MAX_STRONG := 1.0
const PADDLE_HIT_VIBRATION_SPEED_CURVE := 0.75
const DRIVE_HIT_VIBRATION_WEAK := 0.78
const DRIVE_HIT_VIBRATION_STRONG := 1.0
const DRIVE_HIT_VIBRATION_DURATION := 0.18
const POWER_SMASH_HIT_VIBRATION_WEAK := 1.0
const POWER_SMASH_HIT_VIBRATION_STRONG := 1.0
const POWER_SMASH_HIT_VIBRATION_DURATION := 0.28

var screen_shake := 0.0
var screen_shake_intensity := 0.0
# 원본 파리티 채널: duration 동안 진폭을 감쇠 없이 유지하고 하드 스톱한다.
# 기본 감쇠 채널(screen_shake)과 독립이며 최종 진폭은 둘의 max로 합친다.
var sustained_shake_timer := 0.0
var sustained_shake_intensity := 0.0
var fixed_shake_offset := Vector2.ZERO
var gauge_flash_timer := 0.0
var dash_flash_timer := 0.0
var dash_divider_anim_progress := 1.0
var dash_prev_token_max := 1
var _last_paddle_hit_vibration_msec := -1000000


func update(delta: float, dash_token_max: int) -> void:
	fixed_shake_offset = Vector2.ZERO
	screen_shake = move_toward(screen_shake, 0.0, delta * 2.0)
	sustained_shake_timer = maxf(0.0, sustained_shake_timer - delta)
	if sustained_shake_timer <= 0.0:
		sustained_shake_intensity = 0.0
	gauge_flash_timer = max(0.0, gauge_flash_timer - delta)
	dash_flash_timer = max(0.0, dash_flash_timer - delta)
	if dash_token_max != dash_prev_token_max:
		dash_prev_token_max = dash_token_max
		dash_divider_anim_progress = 0.0
	if dash_divider_anim_progress < 1.0:
		dash_divider_anim_progress = min(1.0, dash_divider_anim_progress + delta / DASH_DIVIDER_ANIM_DURATION)


func reset_round(dash_token_max: int) -> void:
	fixed_shake_offset = Vector2.ZERO
	sustained_shake_timer = 0.0
	sustained_shake_intensity = 0.0
	gauge_flash_timer = 0.0
	dash_flash_timer = 0.0
	dash_divider_anim_progress = 1.0
	dash_prev_token_max = max(1, dash_token_max)
	stop_gamepad_vibration()


func set_screen_shake(amount: float, intensity: float) -> void:
	screen_shake = amount
	screen_shake_intensity = intensity


func max_screen_shake(amount: float, intensity: float) -> void:
	screen_shake = max(screen_shake, amount)
	screen_shake_intensity = max(screen_shake_intensity, intensity)


# duration초 동안 ±intensity를 감쇠 없이 유지한다(pygame 원본의 사각 포락 셰이크).
func max_sustained_screen_shake(duration: float, intensity: float) -> void:
	sustained_shake_timer = maxf(sustained_shake_timer, duration)
	sustained_shake_intensity = maxf(sustained_shake_intensity, intensity)


func push_fixed_shake_offset(offset: Vector2) -> void:
	fixed_shake_offset += offset


func trigger_gauge_flash() -> void:
	gauge_flash_timer = GAUGE_GAIN_FLASH_DURATION


func trigger_dash_flash() -> void:
	dash_flash_timer = DASH_FLASH_DURATION


func trigger_paddle_hit_vibration(
	ball_speed: float,
	is_player: bool = true,
	drive_activated: bool = false,
	power_activated: bool = false
) -> bool:
	var vibration: Dictionary = GamepadVibrationSettings.apply_vibration_sensitivity(
		build_paddle_hit_vibration(ball_speed, is_player, drive_activated, power_activated)
	)
	if vibration.is_empty():
		return false
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_paddle_hit_vibration_msec < PADDLE_HIT_VIBRATION_MIN_INTERVAL_MSEC:
		return false
	if not _start_gamepad_vibration(vibration):
		return false
	_last_paddle_hit_vibration_msec = now_msec
	return true


func build_paddle_hit_vibration(
	ball_speed: float,
	is_player: bool = true,
	drive_activated: bool = false,
	power_activated: bool = false
) -> Dictionary:
	if not is_player or ball_speed <= 0.0:
		return {}
	if power_activated:
		return {
			"weak": POWER_SMASH_HIT_VIBRATION_WEAK,
			"strong": POWER_SMASH_HIT_VIBRATION_STRONG,
			"duration": POWER_SMASH_HIT_VIBRATION_DURATION,
			"speed_ratio": 1.0,
			"intensity": 1.0,
			"profile": "power_smash",
		}
	if drive_activated:
		return {
			"weak": DRIVE_HIT_VIBRATION_WEAK,
			"strong": DRIVE_HIT_VIBRATION_STRONG,
			"duration": DRIVE_HIT_VIBRATION_DURATION,
			"speed_ratio": 1.0,
			"intensity": 1.0,
			"profile": "drive",
		}
	var speed_span: float = max(0.001, PADDLE_HIT_VIBRATION_MAX_SPEED - PADDLE_HIT_VIBRATION_BASE_SPEED)
	var speed_ratio: float = clamp((ball_speed - PADDLE_HIT_VIBRATION_BASE_SPEED) / speed_span, 0.0, 1.0)
	var intensity: float = pow(speed_ratio, PADDLE_HIT_VIBRATION_SPEED_CURVE)
	return {
		"weak": lerp(PADDLE_HIT_VIBRATION_MIN_WEAK, PADDLE_HIT_VIBRATION_MAX_WEAK, intensity),
		"strong": lerp(PADDLE_HIT_VIBRATION_MIN_STRONG, PADDLE_HIT_VIBRATION_MAX_STRONG, intensity),
		"duration": lerp(PADDLE_HIT_VIBRATION_MIN_DURATION, PADDLE_HIT_VIBRATION_MAX_DURATION, intensity),
		"speed_ratio": speed_ratio,
		"intensity": intensity,
		"profile": "normal",
	}


func stop_gamepad_vibration() -> void:
	for joypad in Input.get_connected_joypads():
		Input.stop_joy_vibration(int(joypad))


func _start_gamepad_vibration(vibration: Dictionary) -> bool:
	var joypads: Array = Input.get_connected_joypads()
	if joypads.is_empty():
		return false
	for joypad in joypads:
		Input.start_joy_vibration(
			int(joypad),
			float(vibration.get("weak", 0.0)),
			float(vibration.get("strong", 0.0)),
			float(vibration.get("duration", 0.0))
		)
	return true


func get_shake_offset() -> Vector2:
	var amplitude := get_shake_amplitude()
	var random_offset := Vector2.ZERO
	if amplitude > 0.0:
		random_offset = Vector2(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude, amplitude)
		)
	return fixed_shake_offset + random_offset


# 감쇠 채널은 남은 타이머를 곱한 값, 지속 채널은 설정 진폭 그대로 쓴다.
func get_shake_amplitude() -> float:
	var amplitude := 0.0
	if screen_shake > 0.0:
		amplitude = screen_shake_intensity * screen_shake
	if sustained_shake_timer > 0.0:
		amplitude = maxf(amplitude, sustained_shake_intensity)
	return amplitude


func get_gauge_flash_timer() -> float:
	return gauge_flash_timer


func get_gauge_flash_duration() -> float:
	return GAUGE_GAIN_FLASH_DURATION


func get_dash_flash_timer() -> float:
	return dash_flash_timer


func get_dash_flash_duration() -> float:
	return DASH_FLASH_DURATION


func get_dash_divider_anim_progress() -> float:
	return dash_divider_anim_progress
