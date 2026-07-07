extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_SENSOR := "sensor"
const SENSOR_DEFAULT_COOLDOWN_SEC := 15.0
const SENSOR_MIN_COOLDOWN_SEC := 1.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_BASE_PADDLE_HEIGHT := 50.0
const SENSOR_AUTO_DASH_EFFECT_FRAMES := 34.0
const SENSOR_DETECTION_HEIGHT_RATIO := 0.75
const SENSOR_MAX_TIME_TO_PLAYER_FRAMES := 60.0
const SENSOR_PLAYER_REACH_SPEED := 8.0
const SMARTPHONE_RECOVERY_GAUGE_THRESHOLD := 120.0
const SMARTPHONE_RECOVERY_COOLDOWN_FRAMES := 60.0
const SMARTPHONE_DEFENSE_COOLDOWN_FRAMES := 180.0
const SMARTPHONE_PRE_ACTIVATE_MARGIN := 16.0
const SMARTPHONE_MIN_PLAYABLE_MARGIN := 28.0
const SMARTPHONE_MIN_SAFE_DISTANCE := 35.0


func is_sensor_equipped(runtime: Object) -> bool:
	return runtime.equipped_items.has(ITEM_SENSOR)


func is_sensor_effect_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime, ITEM_SENSOR) > 0
	return is_sensor_equipped(runtime)


func is_sensor_enabled(runtime: Object) -> bool:
	return runtime.sensor_enabled


func set_sensor_enabled(runtime: Object, enabled: bool, owner: Object = null, registry: Object = null) -> void:
	runtime.sensor_enabled = bool(enabled)
	runtime._sync_owner(owner, registry)


func get_sensor_cooldown_seconds(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		var level := _get_converted_perk_level(runtime, ITEM_SENSOR)
		if level <= 0:
			return SENSOR_DEFAULT_COOLDOWN_SEC
		return max(SENSOR_MIN_COOLDOWN_SEC, PerkConversionValues.get_value(ITEM_SENSOR, "auto_dash_cooldown_sec", level))
	if not is_sensor_equipped(runtime):
		return SENSOR_DEFAULT_COOLDOWN_SEC
	var seconds: float = runtime.roll_query.get_equipped_roll_value(runtime, ITEM_SENSOR, "sensor_cooldown_sec")
	if seconds <= 0.0:
		seconds = SENSOR_DEFAULT_COOLDOWN_SEC
	return max(SENSOR_MIN_COOLDOWN_SEC, seconds)


func get_sensor_cooldown_frames(runtime: Object) -> float:
	return get_sensor_cooldown_seconds(runtime) * 60.0


func get_sensor_cooldown_remaining_seconds(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return max(0.0, runtime.sensor_auto_dash_recharge_timer_frames / 60.0)
	return max(0.0, runtime.sensor_cooldown_timer_frames / 60.0)


func get_sensor_cooldown_progress(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		if not is_sensor_effect_active(runtime):
			return 0.0
		_sync_sensor_perk_token_capacity(runtime)
		if runtime.sensor_auto_dash_tokens >= runtime.sensor_auto_dash_token_max:
			return 1.0
		var cooldown_frames: float = max(1.0, get_sensor_cooldown_frames(runtime))
		return clamp(1.0 - runtime.sensor_auto_dash_recharge_timer_frames / cooldown_frames, 0.0, 1.0)
	if not is_sensor_equipped(runtime):
		return 0.0
	var cooldown_frames: float = max(1.0, get_sensor_cooldown_frames(runtime))
	return clamp(1.0 - runtime.sensor_cooldown_timer_frames / cooldown_frames, 0.0, 1.0)


func is_sensor_auto_dash_ready(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		_sync_sensor_perk_token_capacity(runtime)
		return is_sensor_effect_active(runtime) and runtime.sensor_enabled and runtime.sensor_auto_dash_tokens > 0
	return is_sensor_equipped(runtime) and runtime.sensor_enabled and runtime.sensor_cooldown_timer_frames <= 0.0


func get_sensor_auto_dash_token_capacity(runtime: Object) -> int:
	if not PerkConversionFlags.is_enabled():
		return 0
	var level := _get_converted_perk_level(runtime, ITEM_SENSOR)
	if level <= 0:
		return 0
	return max(0, int(round(PerkConversionValues.get_value(ITEM_SENSOR, "auto_dash_token_count", level))))


func get_sensor_auto_dash_tokens(runtime: Object) -> int:
	if PerkConversionFlags.is_enabled():
		_sync_sensor_perk_token_capacity(runtime)
	return max(0, int(runtime.sensor_auto_dash_tokens))


func get_sensor_context(runtime: Object) -> Dictionary:
	return runtime.context_builder.get_sensor_context(runtime)


func clear_sensor_runtime(runtime: Object, clear_cooldown: bool = true) -> void:
	runtime.sensor_enabled = true
	if clear_cooldown:
		runtime.sensor_cooldown_timer_frames = 0.0
		_refill_sensor_perk_tokens(runtime)
	clear_sensor_round_state(runtime)


func clear_sensor_round_state(runtime: Object) -> void:
	runtime.sensor_last_dash_direction = 0.0
	runtime.sensor_auto_dash_effect_timer_frames = 0.0
	runtime.sensor_auto_dash_center = Vector2.ZERO


func build_sensor_auto_dash_request(
	runtime: Object,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	if not runtime.is_sensor_auto_dash_ready():
		return {"should_dash": false, "reason": "cooldown_or_inactive"}
	if is_sensor_runtime_blocked(runtime, config, deps):
		return {"should_dash": false, "reason": "blocked"}
	if not bool(config.get("ball_active", true)):
		return {"should_dash": false, "reason": "ball_inactive"}

	var ball_vel: Vector2 = runtime._get_vector2(config.get("ball_vel", Vector2.ZERO))
	if ball_vel.y <= 0.0:
		return {"should_dash": false, "reason": "ball_not_incoming"}

	var height: float = max(1.0, float(config.get("height", FIELD_HEIGHT)))
	var ball_pos: Vector2 = runtime._get_vector2(config.get("ball_pos", Vector2.ZERO))
	var ball_size: float = max(1.0, float(config.get("ball_size", 28.6)))
	var ball_center := ball_pos + Vector2(ball_size * 0.5, ball_size * 0.5)
	if ball_center.y <= height * SENSOR_DETECTION_HEIGHT_RATIO:
		return {"should_dash": false, "reason": "not_low_enough"}

	var paddle_width: float = max(1.0, float(config.get("paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var paddle_height: float = max(1.0, float(config.get("paddle_height", PLAYER_BASE_PADDLE_HEIGHT)))
	var player_center := player_pos + Vector2(paddle_width * 0.5, paddle_height * 0.5)
	var time_to_reach_player: float = (player_center.y - ball_center.y) / ball_vel.y
	if time_to_reach_player <= 0.0 or time_to_reach_player >= SENSOR_MAX_TIME_TO_PLAYER_FRAMES:
		return {"should_dash": false, "reason": "not_immediate"}

	var predicted_x: float = ball_center.x + ball_vel.x * time_to_reach_player
	var player_max_distance: float = SENSOR_PLAYER_REACH_SPEED * time_to_reach_player
	var distance_to_predicted: float = abs(predicted_x - player_center.x)
	if distance_to_predicted <= player_max_distance + paddle_width * 0.5:
		return {"should_dash": false, "reason": "reachable"}

	var direction: float = 1.0 if predicted_x > player_center.x else -1.0
	return {
		"should_dash": true,
		"direction": direction,
		"predicted_x": predicted_x,
		"time_to_reach_player": time_to_reach_player,
		"distance_to_predicted": distance_to_predicted,
		"player_center": player_center,
	}


func notify_sensor_auto_dash_started(
	runtime: Object,
	player_center: Vector2,
	direction: float,
	deps: Dictionary,
	poseidon_constants: Dictionary
) -> void:
	if not is_sensor_effect_active(runtime):
		return
	var deps_dict: Dictionary = runtime._get_dict(deps)
	var registry: Object = deps_dict.get("registry", null)
	var owner: Object = deps_dict.get("owner", null)
	if PerkConversionFlags.is_enabled():
		_consume_sensor_perk_token(runtime)
	else:
		runtime.sensor_cooldown_timer_frames = runtime.get_sensor_cooldown_frames()
	runtime.sensor_last_dash_direction = sign(direction)
	if abs(runtime.sensor_last_dash_direction) <= 0.01:
		runtime.sensor_last_dash_direction = 1.0
	runtime.sensor_auto_dash_center = player_center
	runtime.sensor_auto_dash_effect_timer_frames = SENSOR_AUTO_DASH_EFFECT_FRAMES
	runtime.poseidon_runtime.try_trigger_vortex(
		runtime,
		owner,
		registry,
		runtime.sensor_last_dash_direction,
		poseidon_constants
	)
	runtime._sync_owner(owner, registry)


func is_sensor_runtime_blocked(runtime: Object, config: Dictionary, deps: Dictionary) -> bool:
	var deps_dict: Dictionary = runtime._get_dict(deps)
	var round_state: Object = deps_dict.get("round_state", null)
	if round_state != null and round_state.has_method("is_waiting_for_serve") and bool(round_state.is_waiting_for_serve()):
		return true
	var wheel_state: Object = deps_dict.get("smasher_wheel_state", null)
	if wheel_state != null and wheel_state.has_method("is_active") and bool(wheel_state.is_active()):
		return true
	if is_sensor_player_stunned(runtime, deps_dict):
		return true
	return is_sensor_umbrella_blocked(runtime, config, deps_dict)


func is_sensor_player_stunned(runtime: Object, deps: Dictionary) -> bool:
	var status_state: Object = deps.get("status_effect_state", null)
	if status_state != null and status_state.has_method("has_status") and bool(status_state.has_status("player", "stun")):
		return true
	var owner: Object = deps.get("owner", null)
	if owner == null:
		return false
	if bool(runtime._safe_owner_get(owner, "player_stunned", false)):
		return true
	if float(runtime._safe_owner_get(owner, "player_stunned_timer", 0.0)) > 0.0:
		return true
	return float(runtime._safe_owner_get(owner, "player_missile_stunned_timer", 0.0)) > 0.0


func is_sensor_umbrella_blocked(runtime: Object, config: Dictionary, deps: Dictionary) -> bool:
	var owner: Object = deps.get("owner", null)
	var character_type: String = str(config.get(
		"selected_character_type",
		runtime._safe_owner_get(owner, "selected_character_type", "")
	)).strip_edges().to_lower()
	if character_type != "blacksmith" and character_type != "baltor":
		return false
	return (
		bool(runtime._safe_owner_get(owner, "blacksmith_umbrella_open", false))
		or float(runtime._safe_owner_get(owner, "blacksmith_umbrella_anim_timer", 0.0)) > 0.0
		or bool(runtime._safe_owner_get(owner, "blacksmith_umbrella_retracting", false))
		or bool(runtime._safe_owner_get(owner, "blacksmith_umbrella_swing_active", false))
	)


func update_smartphone_runtime(
	runtime: Object,
	owner: Object,
	registry: Object,
	fps_scale: float
) -> void:
	if runtime.smartphone_cooldown_frames > 0.0:
		runtime.smartphone_cooldown_frames = max(0.0, runtime.smartphone_cooldown_frames - fps_scale)
	if not runtime.is_smartphone_active():
		return

	var active_item_runtime: Object = runtime._get_instance(registry, "active_item_runtime")
	if active_item_runtime == null:
		return

	if should_smartphone_auto_defend(runtime, owner, registry, active_item_runtime, fps_scale):
		var defense_item: String = call_smartphone_auto_use(active_item_runtime, "try_smartphone_auto_defense", owner, registry)
		if defense_item != "":
			runtime.smartphone_last_auto_item = defense_item
			runtime.smartphone_cooldown_frames = SMARTPHONE_DEFENSE_COOLDOWN_FRAMES
			return

	if runtime.smartphone_cooldown_frames > 0.0:
		return

	var recovery_item: String = call_smartphone_auto_use(
		active_item_runtime,
		"try_smartphone_auto_recovery",
		owner,
		registry,
		SMARTPHONE_RECOVERY_GAUGE_THRESHOLD
	)
	if recovery_item != "":
		runtime.smartphone_last_auto_item = recovery_item
		runtime.smartphone_cooldown_frames = SMARTPHONE_RECOVERY_COOLDOWN_FRAMES


func should_smartphone_auto_defend(
	runtime: Object,
	owner: Object,
	registry: Object,
	active_item_runtime: Object,
	fps_scale: float
) -> bool:
	if owner == null:
		return false
	if not bool(runtime._safe_owner_get(owner, "ball_active", true)):
		return false
	var round_state: Object = runtime._get_instance(registry, "round_flow_state")
	if round_state != null and round_state.has_method("is_waiting_for_serve") and bool(round_state.is_waiting_for_serve()):
		return false
	if active_item_runtime != null:
		if active_item_runtime.has_method("is_stopwatch_active") and bool(active_item_runtime.is_stopwatch_active()):
			return false
		if active_item_runtime.has_method("is_holy_barrier_active") and bool(active_item_runtime.is_holy_barrier_active()):
			return false

	var ball_vel: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "ball_vel", Vector2.ZERO))
	if ball_vel.y <= 0.0:
		return false

	var active_item_slots: Array = runtime._get_array(runtime._safe_owner_get(owner, "active_item_slots", []))
	if not has_active_slot_item(runtime, active_item_slots, "stopwatch") and not has_active_slot_item(runtime, active_item_slots, "holy_barrier"):
		return false

	var ball_pos: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "ball_pos", Vector2.ZERO))
	var ball_size: float = 28.6
	var ball_bottom: float = ball_pos.y + ball_size * 0.5
	var distance_to_floor: float = FIELD_HEIGHT - ball_bottom
	var effective_step: float = max(0.0, ball_vel.y * max(0.0, fps_scale))
	var trigger_margin: float = max(SMARTPHONE_PRE_ACTIVATE_MARGIN, effective_step + 8.0)
	if distance_to_floor < 0.0 or distance_to_floor > trigger_margin:
		return false
	if ball_pos.y > FIELD_HEIGHT - SMARTPHONE_MIN_PLAYABLE_MARGIN:
		return false
	if is_smartphone_ball_safe_for_player(runtime, owner, ball_pos, ball_size):
		return false
	return true


func is_smartphone_ball_safe_for_player(
	runtime: Object,
	owner: Object,
	ball_pos: Vector2,
	ball_size: float
) -> bool:
	var player_pos: Vector2 = runtime._get_vector2(runtime._safe_owner_get(owner, "player_pos", Vector2(302.5, FIELD_HEIGHT - PLAYER_BASE_PADDLE_HEIGHT)))
	var paddle_width: float = max(1.0, float(runtime._safe_owner_get(owner, "player_paddle_width", PLAYER_BASE_PADDLE_WIDTH)))
	var paddle_height: float = max(1.0, float(runtime._safe_owner_get(owner, "player_paddle_height", PLAYER_BASE_PADDLE_HEIGHT)))
	var player_center := player_pos + Vector2(paddle_width * 0.5, paddle_height * 0.5)
	if abs(ball_pos.x - player_center.x) <= SMARTPHONE_MIN_SAFE_DISTANCE and abs(ball_pos.y - player_center.y) <= SMARTPHONE_MIN_SAFE_DISTANCE:
		return true

	var ball_rect := Rect2(ball_pos - Vector2(ball_size, ball_size) * 0.5, Vector2(ball_size, ball_size))
	var player_rect := Rect2(player_pos, Vector2(paddle_width, paddle_height)).grow(6.0)
	return player_rect.intersects(ball_rect)


func has_active_slot_item(runtime: Object, active_item_slots: Array, item_name: String) -> bool:
	for item_value in active_item_slots:
		var item_data: Dictionary = runtime._get_dict(item_value)
		if str(item_data.get("name", "")) == item_name or str(item_data.get("effect", "")) == item_name:
			return true
	return false


func call_smartphone_auto_use(
	active_item_runtime: Object,
	method_name: String,
	owner: Object,
	registry: Object,
	extra_arg: Variant = null
) -> String:
	if active_item_runtime == null or not active_item_runtime.has_method(method_name):
		return ""
	var result: Variant
	if extra_arg == null:
		result = active_item_runtime.call(method_name, owner, registry)
	else:
		result = active_item_runtime.call(method_name, owner, registry, extra_arg)
	return str(result)


func update_sensor_runtime(runtime: Object, fps_scale: float) -> void:
	var step: float = max(0.0, fps_scale)
	if PerkConversionFlags.is_enabled():
		_update_sensor_perk_token_recharge(runtime, step)
	elif runtime.sensor_cooldown_timer_frames > 0.0:
		runtime.sensor_cooldown_timer_frames = max(0.0, runtime.sensor_cooldown_timer_frames - step)
	if not is_sensor_effect_active(runtime):
		runtime.sensor_auto_dash_effect_timer_frames = 0.0
		runtime.sensor_auto_dash_center = Vector2.ZERO
		runtime.sensor_last_dash_direction = 0.0
		return
	if runtime.sensor_auto_dash_effect_timer_frames > 0.0:
		runtime.sensor_auto_dash_effect_timer_frames = max(0.0, runtime.sensor_auto_dash_effect_timer_frames - step)
		if runtime.sensor_auto_dash_effect_timer_frames <= 0.0:
			runtime.sensor_auto_dash_center = Vector2.ZERO


func _update_sensor_perk_token_recharge(runtime: Object, fps_scale: float) -> void:
	_sync_sensor_perk_token_capacity(runtime)
	if runtime.sensor_auto_dash_token_max <= 0:
		return
	if runtime.sensor_auto_dash_tokens >= runtime.sensor_auto_dash_token_max:
		runtime.sensor_auto_dash_recharge_timer_frames = 0.0
		return
	if runtime.sensor_auto_dash_recharge_timer_frames <= 0.0:
		runtime.sensor_auto_dash_recharge_timer_frames = max(1.0, get_sensor_cooldown_frames(runtime))
	runtime.sensor_auto_dash_recharge_timer_frames = max(
		0.0,
		runtime.sensor_auto_dash_recharge_timer_frames - max(0.0, fps_scale)
	)
	if runtime.sensor_auto_dash_recharge_timer_frames > 0.0:
		return
	runtime.sensor_auto_dash_tokens = min(runtime.sensor_auto_dash_token_max, runtime.sensor_auto_dash_tokens + 1)
	if runtime.sensor_auto_dash_tokens < runtime.sensor_auto_dash_token_max:
		runtime.sensor_auto_dash_recharge_timer_frames = max(1.0, get_sensor_cooldown_frames(runtime))
	else:
		runtime.sensor_auto_dash_recharge_timer_frames = 0.0


func _consume_sensor_perk_token(runtime: Object) -> void:
	_sync_sensor_perk_token_capacity(runtime)
	runtime.sensor_auto_dash_tokens = max(0, runtime.sensor_auto_dash_tokens - 1)
	if runtime.sensor_auto_dash_tokens < runtime.sensor_auto_dash_token_max and runtime.sensor_auto_dash_recharge_timer_frames <= 0.0:
		runtime.sensor_auto_dash_recharge_timer_frames = max(1.0, get_sensor_cooldown_frames(runtime))


func _refill_sensor_perk_tokens(runtime: Object) -> void:
	var max_tokens := get_sensor_auto_dash_token_capacity(runtime)
	runtime.sensor_auto_dash_token_max = max_tokens
	runtime.sensor_auto_dash_tokens = max_tokens
	runtime.sensor_auto_dash_recharge_timer_frames = 0.0


func _sync_sensor_perk_token_capacity(runtime: Object) -> void:
	var max_tokens := get_sensor_auto_dash_token_capacity(runtime)
	if max_tokens <= 0:
		runtime.sensor_auto_dash_token_max = 0
		runtime.sensor_auto_dash_tokens = 0
		runtime.sensor_auto_dash_recharge_timer_frames = 0.0
		return
	if runtime.sensor_auto_dash_token_max <= 0:
		runtime.sensor_auto_dash_token_max = max_tokens
		runtime.sensor_auto_dash_tokens = max_tokens
		runtime.sensor_auto_dash_recharge_timer_frames = 0.0
		return
	var previous_max: int = runtime.sensor_auto_dash_token_max
	runtime.sensor_auto_dash_token_max = max_tokens
	if max_tokens < previous_max:
		runtime.sensor_auto_dash_tokens = min(runtime.sensor_auto_dash_tokens, max_tokens)
	if runtime.sensor_auto_dash_tokens >= max_tokens:
		runtime.sensor_auto_dash_recharge_timer_frames = 0.0
	elif runtime.sensor_auto_dash_recharge_timer_frames <= 0.0:
		runtime.sensor_auto_dash_recharge_timer_frames = max(1.0, get_sensor_cooldown_frames(runtime))


func _get_converted_perk_level(runtime: Object, perk_id: String) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(perk_id)))
	return 0
