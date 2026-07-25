extends RefCounted

const PLAYER_SPRITE_DRAW_SIZE := Vector2(148.0, 148.0)
const PLAYER_SPRITE_FOOT_OFFSET := Vector2(0.0, 8.0)
const PLAYER_WALK_LOOP_MSEC := 760
const PLAYER_IDLE_LOOP_MSEC := 1040

const LINGPET_FOLLOW_OFFSET_X := 58.0
const LINGPET_FOLLOW_OFFSET_Y := -20.0
const LINGPET_FOLLOW_BLEND_PER_FRAME_60 := 0.12
const LINGPET_COMPANION_GRID_COLS := 5
const LINGPET_COMPANION_GRID_ROWS := 5
const LINGPET_COMPANION_FRAME_COUNT := 25
const LINGPET_COMPANION_LOOP_MSEC := 2000


static func is_player_walking(test_input_active: bool, test_input_direction: Vector2, live_input_direction: Vector2) -> bool:
	var direction := test_input_direction if test_input_active else live_input_direction
	return absf(direction.x) > 0.01


static func get_facing_direction(last_input_direction: Vector2) -> int:
	return -1 if last_input_direction.x < -0.01 else 1


static func get_player_sprite_frame(ticks_msec: int, moving: bool, frame_count: int) -> int:
	var duration_msec: int = PLAYER_WALK_LOOP_MSEC if moving else PLAYER_IDLE_LOOP_MSEC
	return get_loop_frame(ticks_msec, duration_msec, frame_count)


static func get_lingpet_sprite_frame(ticks_msec: int) -> int:
	return get_loop_frame(ticks_msec, LINGPET_COMPANION_LOOP_MSEC, LINGPET_COMPANION_FRAME_COUNT)


static func get_loop_frame(ticks_msec: int, duration_msec: int, frame_count: int) -> int:
	var safe_duration: int = max(1, duration_msec)
	var safe_frame_count: int = max(1, frame_count)
	var elapsed: int = posmod(ticks_msec, safe_duration)
	return int(floor(float(elapsed) / float(safe_duration) * float(safe_frame_count))) % safe_frame_count


static func get_sheet_frame_rect(texture_size: Vector2, frame: int, grid_cols: int, grid_rows: int) -> Rect2:
	var safe_cols: int = max(1, grid_cols)
	var safe_rows: int = max(1, grid_rows)
	var max_frame: int = max(0, safe_cols * safe_rows - 1)
	var safe_frame: int = clampi(frame, 0, max_frame)
	var cell_size: Vector2 = Vector2(texture_size.x / float(safe_cols), texture_size.y / float(safe_rows))
	var column: int = safe_frame % safe_cols
	var row: int = floori(float(safe_frame) / float(safe_cols))
	return Rect2(Vector2(float(column) * cell_size.x, float(row) * cell_size.y), cell_size)


static func get_player_draw_rect(local_foot_position: Vector2, scale: float) -> Rect2:
	return Rect2(
		local_foot_position + (PLAYER_SPRITE_FOOT_OFFSET - Vector2(PLAYER_SPRITE_DRAW_SIZE.x * 0.5, PLAYER_SPRITE_DRAW_SIZE.y)) * scale,
		PLAYER_SPRITE_DRAW_SIZE * scale
	)


static func get_lingpet_draw_rect(local_foot_position: Vector2, draw_size: float, scale: float) -> Rect2:
	var scaled_size := Vector2(draw_size, draw_size) * scale
	return Rect2(local_foot_position + Vector2(-scaled_size.x * 0.5, -scaled_size.y + 8.0 * scale), scaled_size)


static func get_lingpet_follow_target(
	player_position: Vector2,
	facing_direction: int,
	map_width: float,
	player_collision_width: float,
	ground_y: float
) -> Vector2:
	var half_collision_width := player_collision_width * 0.5
	var target_x := clampf(
		player_position.x - float(facing_direction) * LINGPET_FOLLOW_OFFSET_X,
		half_collision_width,
		map_width - half_collision_width
	)
	return Vector2(target_x, ground_y + LINGPET_FOLLOW_OFFSET_Y)


static func get_lingpet_follow_blend(delta: float) -> float:
	return clampf(maxf(0.0, delta) * 60.0 * LINGPET_FOLLOW_BLEND_PER_FRAME_60, 0.0, 1.0)


static func project_lingpet_follower_position(
	current_position: Vector2,
	initialized: bool,
	target_position: Vector2,
	delta: float
) -> Vector2:
	if not initialized:
		return target_position
	return current_position.lerp(target_position, get_lingpet_follow_blend(delta))
