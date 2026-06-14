extends RefCounted

const SmasherDashMotionState := preload("res://scripts/characters/smasher_dash_motion_state.gd")
const SmasherDashTokenState := preload("res://scripts/characters/smasher_dash_token_state.gd")

const CONSECUTIVE_DASH_START_DELAY_FRAMES := 12.0
const DASH_BASE_DURATION_FRAMES := 15.0
const DASH_BASE_RECOVERY_FRAMES := 42.0
const DASH_BASE_RECHARGE_FRAMES := 300.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0

var dash_key_released_since_last: bool = true
var next_rally_gold_multiplier_armed := false
var motion_state: Object = SmasherDashMotionState.new()
var token_state: Object = SmasherDashTokenState.new()


func reset_round() -> void:
	motion_state.reset_round()
	if token_state != null and token_state.has_method("reset_round_transients"):
		token_state.reset_round_transients()
	dash_key_released_since_last = true
	next_rally_gold_multiplier_armed = false


func cancel_until_key_release() -> void:
	motion_state.reset_round()
	dash_key_released_since_last = false
	next_rally_gold_multiplier_armed = false


func reset_full(max_tokens: int = 1) -> void:
	token_state.reset_full(max_tokens)
	reset_round()


func set_max_tokens(max_tokens: int, fill_new_tokens: bool = true) -> bool:
	if token_state == null or not token_state.has_method("set_max_tokens"):
		return false
	return bool(token_state.set_max_tokens(max_tokens, fill_new_tokens))


func refill_tokens() -> void:
	token_state.refill_tokens()


func update_key_release(down_pressed: bool) -> void:
	if not down_pressed:
		dash_key_released_since_last = true


func can_chain_dash(down_pressed: bool, direction: float, soul_burst_available: bool = false) -> bool:
	return down_pressed and motion_state.can_chain(
		direction,
		token_state.has_chain_dash_token() or soul_burst_available,
		CONSECUTIVE_DASH_START_DELAY_FRAMES
	)


func can_chain_dash_from_recovery(down_pressed: bool, direction: float, soul_burst_available: bool = false) -> bool:
	return down_pressed and motion_state.can_chain_from_recovery(
		direction,
		token_state.has_chain_dash_token() or soul_burst_available
	)


func is_active() -> bool:
	return motion_state.is_active()


func is_recovering() -> bool:
	return motion_state.is_recovering()


func clear_recovery() -> void:
	if motion_state != null and motion_state.has_method("clear_recovery"):
		motion_state.clear_recovery()


func cancel_active_without_recovery() -> bool:
	if motion_state == null or not motion_state.has_method("cancel_active_without_recovery"):
		return false
	var cancelled: bool = bool(motion_state.cancel_active_without_recovery())
	if cancelled:
		dash_key_released_since_last = false
	return cancelled


func can_start_from_input(down_pressed: bool, direction: float) -> bool:
	return down_pressed and motion_state.can_start(direction, dash_key_released_since_last)


func has_full_dash_token() -> bool:
	return token_state.has_full_dash_token()


func has_chain_dash_token() -> bool:
	return token_state.has_chain_dash_token()


func start(
	direction: float,
	is_half: bool,
	runtime_perk_state: Object = null,
	registry: Object = null,
	consume_token: bool = true,
	skip_recovery: bool = false
) -> bool:
	var duration_frames: float = _get_dash_duration_frames(runtime_perk_state, registry)
	if not motion_state.start(
		direction,
		is_half,
		duration_frames,
		_get_dash_acceleration_bonus(runtime_perk_state),
		_get_dash_acceleration_level(runtime_perk_state),
		PLAYER_BASE_PADDLE_HEIGHT,
		skip_recovery
	):
		return false
	dash_key_released_since_last = false
	next_rally_gold_multiplier_armed = true
	if not is_half and consume_token and not _is_dash_cost_free(registry):
		var token_consumed: bool = token_state.consume_full_dash_token(_get_dash_recharge_frames(runtime_perk_state, registry))
		if token_consumed and token_state.try_arm_boost_charging(
			_get_boost_charge_chance_pct(runtime_perk_state, registry),
			token_state.get_last_consumed_token_index()
		):
			_play_boost_charging_audio(registry)
	return true


func update(
	delta: float,
	player_pos: Vector2,
	play_left: float,
	play_right: float,
	paddle_width: float,
	runtime_perk_state: Object = null,
	registry: Object = null
) -> Dictionary:
	var fps_scale: float = delta * 60.0
	var recharge_completed: bool = token_state.update_recharge(fps_scale, _get_dash_recharge_frames(runtime_perk_state, registry))

	var result: Dictionary = motion_state.update(
		fps_scale,
		player_pos,
		play_left,
		play_right,
		paddle_width,
		_get_dash_recovery_frames(runtime_perk_state, registry)
	)
	result["recharge_completed"] = recharge_completed
	return result


func get_snapshot() -> Dictionary:
	var snapshot: Dictionary = token_state.get_snapshot()
	snapshot.merge(motion_state.get_snapshot(), true)
	snapshot["key_released_since_last"] = dash_key_released_since_last
	snapshot["next_rally_gold_multiplier_armed"] = next_rally_gold_multiplier_armed
	return snapshot


func consume_next_rally_gold_multiplier() -> bool:
	if not next_rally_gold_multiplier_armed:
		return false
	next_rally_gold_multiplier_armed = false
	return true


func is_dash_acceleration_active() -> bool:
	var snapshot: Dictionary = motion_state.get_snapshot()
	return bool(snapshot.get("dash_acceleration_active", false))


func get_ball_collision_context() -> Dictionary:
	var snapshot: Dictionary = motion_state.get_snapshot()
	if not bool(snapshot.get("dash_acceleration_active", false)):
		return {}
	return {
		"dash_acceleration_active": true,
		"dash_acceleration_height_bonus": max(0.0, float(snapshot.get("dash_acceleration_height_bonus", 0.0))),
		"dash_acceleration_bonus": max(0.0, float(snapshot.get("dash_acceleration_bonus", 0.0))),
		"dash_acceleration_skill_level": max(0, int(snapshot.get("dash_acceleration_skill_level", 0))),
	}


func _get_dash_recharge_frames(runtime_perk_state: Object, registry: Object = null) -> float:
	var frames: float = DASH_BASE_RECHARGE_FRAMES
	if runtime_perk_state != null and runtime_perk_state.has_method("get_dash_recharge_frames"):
		frames = float(runtime_perk_state.get_dash_recharge_frames(frames))
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_dash_recharge_frames"):
		frames = float(mythic_item_runtime.get_dash_recharge_frames(frames))
	frames *= _get_dash_cooldown_multiplier(registry)
	return max(1.0, frames)


func _get_dash_cooldown_multiplier(registry: Object) -> float:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("get_dash_cooldown_multiplier"):
		return max(0.0, float(active_item_runtime.get_dash_cooldown_multiplier()))
	return 1.0


func _is_dash_cost_free(registry: Object) -> bool:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("get_dash_cost_multiplier"):
		return float(active_item_runtime.get_dash_cost_multiplier()) <= 0.0
	return false


func _get_dash_recovery_frames(runtime_perk_state: Object, registry: Object = null) -> float:
	var frames: float = DASH_BASE_RECOVERY_FRAMES
	if runtime_perk_state != null and runtime_perk_state.has_method("get_dash_recovery_frames"):
		frames = float(runtime_perk_state.get_dash_recovery_frames(frames))
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_dash_recovery_frames"):
		frames = float(mythic_item_runtime.get_dash_recovery_frames(frames))
	return max(1.0, frames)


func _get_dash_duration_frames(runtime_perk_state: Object, registry: Object = null) -> float:
	var frames: float = DASH_BASE_DURATION_FRAMES
	if runtime_perk_state != null and runtime_perk_state.has_method("get_dash_duration_frames"):
		frames = float(runtime_perk_state.get_dash_duration_frames(frames))
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_dash_duration_frames"):
		frames = float(mythic_item_runtime.get_dash_duration_frames(frames))
	return max(1.0, frames)


func _get_dash_acceleration_bonus(runtime_perk_state: Object) -> float:
	if runtime_perk_state == null:
		return 0.0
	if runtime_perk_state.has_method("get_dash_acceleration_bonus"):
		return max(0.0, float(runtime_perk_state.get_dash_acceleration_bonus()))
	if runtime_perk_state.has_method("get_runtime_skill_bonus"):
		return max(0.0, float(runtime_perk_state.get_runtime_skill_bonus("dash_acceleration")))
	return 0.0


func _get_dash_acceleration_level(runtime_perk_state: Object) -> int:
	if runtime_perk_state == null:
		return 0
	if runtime_perk_state.has_method("get_dash_acceleration_level"):
		return max(0, int(runtime_perk_state.get_dash_acceleration_level()))
	if runtime_perk_state.has_method("get_runtime_skill_level"):
		return max(0, int(runtime_perk_state.get_runtime_skill_level("dash_acceleration")))
	return int(round(_get_dash_acceleration_bonus(runtime_perk_state) / 0.70))


func _get_boost_charge_chance_pct(runtime_perk_state: Object, registry: Object = null) -> float:
	var chance_pct := 0.0
	if runtime_perk_state != null and runtime_perk_state.has_method("get_boost_charge_chance_pct"):
		chance_pct += float(runtime_perk_state.get_boost_charge_chance_pct())
	var mythic_item_runtime: Object = _get_instance(registry, "mythic_item_runtime")
	if mythic_item_runtime != null and mythic_item_runtime.has_method("get_boost_charge_chance_pct"):
		chance_pct += float(mythic_item_runtime.get_boost_charge_chance_pct())
	return clamp(chance_pct, 0.0, 100.0)


func _play_boost_charging_audio(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	if audio.has_method("play_boost_charging"):
		audio.play_boost_charging()
	elif audio.has_method("play_dash_charge"):
		audio.play_dash_charge()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
