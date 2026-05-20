extends RefCounted

const GAUGE_GAIN_FLASH_DURATION := 0.45
const DASH_FLASH_DURATION := 0.55
const DASH_DIVIDER_ANIM_DURATION := 0.60

var screen_shake := 0.0
var screen_shake_intensity := 0.0
var fixed_shake_offset := Vector2.ZERO
var gauge_flash_timer := 0.0
var dash_flash_timer := 0.0
var dash_divider_anim_progress := 1.0
var dash_prev_token_max := 1


func update(delta: float, dash_token_max: int) -> void:
	fixed_shake_offset = Vector2.ZERO
	screen_shake = move_toward(screen_shake, 0.0, delta * 2.0)
	gauge_flash_timer = max(0.0, gauge_flash_timer - delta)
	dash_flash_timer = max(0.0, dash_flash_timer - delta)
	if dash_token_max != dash_prev_token_max:
		dash_prev_token_max = dash_token_max
		dash_divider_anim_progress = 0.0
	if dash_divider_anim_progress < 1.0:
		dash_divider_anim_progress = min(1.0, dash_divider_anim_progress + delta / DASH_DIVIDER_ANIM_DURATION)


func reset_round(dash_token_max: int) -> void:
	fixed_shake_offset = Vector2.ZERO
	gauge_flash_timer = 0.0
	dash_flash_timer = 0.0
	dash_divider_anim_progress = 1.0
	dash_prev_token_max = max(1, dash_token_max)


func set_screen_shake(amount: float, intensity: float) -> void:
	screen_shake = amount
	screen_shake_intensity = intensity


func max_screen_shake(amount: float, intensity: float) -> void:
	screen_shake = max(screen_shake, amount)
	screen_shake_intensity = max(screen_shake_intensity, intensity)


func push_fixed_shake_offset(offset: Vector2) -> void:
	fixed_shake_offset += offset


func trigger_gauge_flash() -> void:
	gauge_flash_timer = GAUGE_GAIN_FLASH_DURATION


func trigger_dash_flash() -> void:
	dash_flash_timer = DASH_FLASH_DURATION


func get_shake_offset() -> Vector2:
	var random_offset := Vector2.ZERO
	if screen_shake > 0.0:
		random_offset = Vector2(
			randf_range(-screen_shake_intensity, screen_shake_intensity),
			randf_range(-screen_shake_intensity, screen_shake_intensity)
		) * screen_shake
	return fixed_shake_offset + random_offset


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
