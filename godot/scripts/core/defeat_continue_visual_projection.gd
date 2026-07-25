extends RefCounted

# Pure timeline and geometry projection for the chance-gem continue screen.
# Callback, audio, resource, FX-host, and drawing lifecycle stay in the screen.

const BUTTON_SIZE := Vector2(330.0, 50.0)
const CONFIRM_SHAKE_DURATION_SEC := 2.0
const CONFIRM_SHATTER_START_SEC := 2.0
const CONFIRM_SHATTER_DURATION_SEC := 0.60
const CONFIRM_WHITEOUT_START_SEC := 2.30
const CONFIRM_RESET_TIME_SEC := 2.90
const CONFIRM_FADEBACK_END_SEC := 3.50
const IMPACT_FLASH_DURATION_SEC := 0.24
const IMPACT_RING_DURATION_SEC := 0.42
const IMPACT_SHAKE_DURATION_SEC := 0.56
const IMPACT_BEAM_DURATION_SEC := 0.50
const IMPACT_CHROMA_DURATION_SEC := 0.34


static func get_boss_victory_source_rect(texture_size: Vector2, stage_id: int, frame_index: int) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2()
	var columns := 4
	var rows := 2
	if stage_id == 2:
		columns = 8
		rows = 8
	elif stage_id >= 4 and texture_size.x <= texture_size.y * 1.05:
		columns = 1
		rows = 1
	var frame_count := maxi(1, columns * rows)
	var frame := posmod(frame_index, frame_count)
	var cell_size := Vector2(texture_size.x / float(columns), texture_size.y / float(rows))
	@warning_ignore("integer_division")
	var row := int(frame / columns)
	return Rect2(Vector2(float(frame % columns) * cell_size.x, float(row) * cell_size.y), cell_size)


static func get_visual_remaining_gems(consuming: bool, shatter_started: bool, remaining_gems: int, post_consume_remaining_gems: int) -> int:
	return post_consume_remaining_gems if consuming and shatter_started else remaining_gems


static func get_breaking_gem_index(consuming: bool, continue_reset_fired: bool, max_gems: int, remaining_gems: int) -> int:
	if not consuming or continue_reset_fired:
		return -1
	var index := max_gems - remaining_gems
	return index if index >= 0 and index < max_gems else -1


static func has_shatter_started(consuming: bool, confirm_elapsed: float) -> bool:
	return consuming and confirm_elapsed >= CONFIRM_SHATTER_START_SEC


static func has_shatter_completed(consuming: bool, confirm_elapsed: float) -> bool:
	return consuming and confirm_elapsed >= CONFIRM_SHATTER_START_SEC + CONFIRM_SHATTER_DURATION_SEC


static func is_shatter_window_active(consuming: bool, confirm_elapsed: float) -> bool:
	return consuming and confirm_elapsed >= CONFIRM_SHATTER_START_SEC and confirm_elapsed < CONFIRM_SHATTER_START_SEC + CONFIRM_SHATTER_DURATION_SEC


static func get_shatter_progress(consuming: bool, confirm_elapsed: float) -> float:
	if not consuming:
		return 0.0
	return clampf((confirm_elapsed - CONFIRM_SHATTER_START_SEC) / maxf(CONFIRM_SHATTER_DURATION_SEC, 0.001), 0.0, 1.0)


static func get_confirm_shake_offset(consuming: bool, confirm_elapsed: float, index: int, breaking_index: int) -> Vector2:
	if not consuming or has_shatter_started(consuming, confirm_elapsed) or index != breaking_index:
		return Vector2.ZERO
	var progress := clampf(confirm_elapsed / maxf(CONFIRM_SHAKE_DURATION_SEC, 0.001), 0.0, 1.0)
	var intensity := progress * progress
	var amplitude := 2.0 + 7.0 * intensity
	return Vector2(
		sin(confirm_elapsed * TAU * 8.2) * amplitude,
		sin(confirm_elapsed * TAU * 11.7 + 0.8) * amplitude * 0.42
	)


static func get_pre_shatter_charge(consuming: bool, confirm_elapsed: float) -> float:
	if not consuming or confirm_elapsed < 0.10 or has_shatter_started(consuming, confirm_elapsed):
		return 0.0
	var progress := clampf(confirm_elapsed / maxf(CONFIRM_SHAKE_DURATION_SEC, 0.001), 0.0, 1.0)
	return progress * progress


static func get_pre_shatter_crack(consuming: bool, confirm_elapsed: float) -> float:
	if not consuming or confirm_elapsed < 0.55 or has_shatter_started(consuming, confirm_elapsed):
		return 0.0
	var progress := clampf((confirm_elapsed - 0.55) / maxf(CONFIRM_SHAKE_DURATION_SEC - 0.55, 0.001), 0.0, 1.0)
	return ease_in_out_cubic(progress)


static func get_impact_time(consuming: bool, confirm_elapsed: float) -> float:
	return confirm_elapsed - CONFIRM_SHATTER_START_SEC if consuming else -1.0


static func get_impact_flash_alpha(consuming: bool, confirm_elapsed: float) -> float:
	var impact_time := get_impact_time(consuming, confirm_elapsed)
	if impact_time < 0.0 or impact_time > IMPACT_FLASH_DURATION_SEC:
		return 0.0
	var progress := clampf(impact_time / maxf(IMPACT_FLASH_DURATION_SEC, 0.001), 0.0, 1.0)
	return pow(1.0 - progress, 2.1)


static func get_impact_ring_progress(consuming: bool, confirm_elapsed: float) -> float:
	var impact_time := get_impact_time(consuming, confirm_elapsed)
	if impact_time < 0.0:
		return 0.0
	return clampf(impact_time / maxf(IMPACT_RING_DURATION_SEC, 0.001), 0.0, 1.0)


static func get_impact_ring_alpha(consuming: bool, confirm_elapsed: float) -> float:
	var progress := get_impact_ring_progress(consuming, confirm_elapsed)
	if progress <= 0.0 or progress >= 1.0:
		return 0.0
	return pow(1.0 - progress, 1.35)


static func get_light_beam_alpha(consuming: bool, confirm_elapsed: float) -> float:
	var impact_time := get_impact_time(consuming, confirm_elapsed)
	if impact_time < 0.0 or impact_time > IMPACT_BEAM_DURATION_SEC:
		return 0.0
	var progress := clampf(impact_time / maxf(IMPACT_BEAM_DURATION_SEC, 0.001), 0.0, 1.0)
	return clampf(progress / 0.16, 0.0, 1.0) * pow(1.0 - progress, 1.5)


static func get_chroma_split_strength(consuming: bool, confirm_elapsed: float) -> float:
	var impact_time := get_impact_time(consuming, confirm_elapsed)
	if impact_time < 0.0 or impact_time > IMPACT_CHROMA_DURATION_SEC:
		return 0.0
	var progress := clampf(impact_time / maxf(IMPACT_CHROMA_DURATION_SEC, 0.001), 0.0, 1.0)
	return pow(1.0 - progress, 1.7)


static func get_impact_shake_offset(consuming: bool, confirm_elapsed: float) -> Vector2:
	var impact_time := get_impact_time(consuming, confirm_elapsed)
	if impact_time < 0.0 or impact_time > IMPACT_SHAKE_DURATION_SEC:
		return Vector2.ZERO
	var progress := clampf(impact_time / maxf(IMPACT_SHAKE_DURATION_SEC, 0.001), 0.0, 1.0)
	var amplitude := 10.0 * pow(1.0 - progress, 2.4)
	return Vector2(
		sin((confirm_elapsed + 0.11) * TAU * 16.0) * amplitude,
		sin((confirm_elapsed + 0.37) * TAU * 21.0) * amplitude * 0.55
	)


static func get_whiteout_alpha(consuming: bool, confirm_elapsed: float) -> float:
	if not consuming or confirm_elapsed < CONFIRM_WHITEOUT_START_SEC:
		return 0.0
	if confirm_elapsed <= CONFIRM_RESET_TIME_SEC:
		var rise := (confirm_elapsed - CONFIRM_WHITEOUT_START_SEC) / maxf(CONFIRM_RESET_TIME_SEC - CONFIRM_WHITEOUT_START_SEC, 0.001)
		return ease_in_out_cubic(rise)
	var fade := (confirm_elapsed - CONFIRM_RESET_TIME_SEC) / maxf(CONFIRM_FADEBACK_END_SEC - CONFIRM_RESET_TIME_SEC, 0.001)
	return 1.0 - ease_out_cubic(fade)


static func get_consumed_gem_center(view_size: Vector2, consumed: int, max_gems: int) -> Vector2:
	var gem_gap := minf(view_size.x * 0.095, 122.0)
	var first_x := view_size.x * 0.5 - gem_gap
	var index := clampi(consumed - 1, 0, max_gems - 1)
	return Vector2(first_x + float(index) * gem_gap, scaled_y(view_size, 540.0))


static func fit_size_rect(source_size: Vector2, center: Vector2, max_size: Vector2) -> Rect2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Rect2(center, Vector2.ZERO)
	var scale_factor := minf(max_size.x / source_size.x, max_size.y / source_size.y)
	var draw_size := source_size * scale_factor
	return Rect2(center - draw_size * 0.5, draw_size)


static func cover_size_rect(source_size: Vector2, target: Rect2) -> Rect2:
	if source_size.x <= 0.0 or source_size.y <= 0.0 or target.size.x <= 0.0 or target.size.y <= 0.0:
		return Rect2(target.position, Vector2.ZERO)
	var scale_factor := maxf(target.size.x / source_size.x, target.size.y / source_size.y)
	var draw_size := source_size * scale_factor
	return Rect2(target.get_center() - draw_size * 0.5, draw_size)


static func get_button_rect(view_size: Vector2) -> Rect2:
	var width_scale := clampf(view_size.x / 1280.0, 0.78, 1.08)
	var height_scale := clampf(view_size.y / 720.0, 0.90, 1.12)
	var scaled_size := Vector2(BUTTON_SIZE.x * width_scale, BUTTON_SIZE.y * height_scale)
	var top := minf(view_size.y - scaled_size.y - 26.0, scaled_y(view_size, 676.0) - scaled_size.y * 0.5)
	return Rect2(Vector2(view_size.x * 0.5 - scaled_size.x * 0.5, top), scaled_size)


static func scaled_y(view_size: Vector2, base_y: float) -> float:
	return base_y * clampf(view_size.y / 720.0, 0.78, 1.28)


static func scaled_font(view_size: Vector2, base_size: int) -> int:
	return maxi(10, int(round(float(base_size) * clampf(view_size.y / 720.0, 0.86, 1.18))))


static func ease_out_cubic(value: float) -> float:
	var normalized := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - normalized, 3.0)


static func ease_in_out_cubic(value: float) -> float:
	var normalized := clampf(value, 0.0, 1.0)
	if normalized < 0.5:
		return 4.0 * normalized * normalized * normalized
	return 1.0 - pow(-2.0 * normalized + 2.0, 3.0) * 0.5
