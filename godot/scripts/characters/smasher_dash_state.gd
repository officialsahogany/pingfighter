extends RefCounted

const SmasherDashMotionState := preload("res://scripts/characters/smasher_dash_motion_state.gd")
const SmasherDashTokenState := preload("res://scripts/characters/smasher_dash_token_state.gd")

const CONSECUTIVE_DASH_START_DELAY_FRAMES := 12.0

var dash_key_released_since_last: bool = true
var motion_state: Object = SmasherDashMotionState.new()
var token_state: Object = SmasherDashTokenState.new()


func reset_round() -> void:
	motion_state.reset_round()
	dash_key_released_since_last = true


func reset_full(max_tokens: int = 1) -> void:
	token_state.reset_full(max_tokens)
	reset_round()


func update_key_release(down_pressed: bool) -> void:
	if not down_pressed:
		dash_key_released_since_last = true


func can_chain_dash(down_pressed: bool, direction: float) -> bool:
	return down_pressed and motion_state.can_chain(
		direction,
		token_state.has_full_dash_token(),
		CONSECUTIVE_DASH_START_DELAY_FRAMES
	)


func is_active() -> bool:
	return motion_state.is_active()


func is_recovering() -> bool:
	return motion_state.is_recovering()


func can_start_from_input(down_pressed: bool, direction: float) -> bool:
	return down_pressed and motion_state.can_start(direction, dash_key_released_since_last)


func has_full_dash_token() -> bool:
	return token_state.has_full_dash_token()


func start(direction: float, is_half: bool) -> bool:
	if not motion_state.start(direction, is_half):
		return false
	dash_key_released_since_last = false
	if not is_half:
		token_state.consume_full_dash_token()
	return true


func update(delta: float, player_pos: Vector2, play_left: float, play_right: float, paddle_width: float) -> Dictionary:
	var fps_scale: float = delta * 60.0
	var recharge_completed: bool = token_state.update_recharge(fps_scale)

	var result: Dictionary = motion_state.update(fps_scale, player_pos, play_left, play_right, paddle_width)
	result["recharge_completed"] = recharge_completed
	return result


func get_snapshot() -> Dictionary:
	var snapshot: Dictionary = token_state.get_snapshot()
	snapshot.merge(motion_state.get_snapshot(), true)
	snapshot["key_released_since_last"] = dash_key_released_since_last
	return snapshot
