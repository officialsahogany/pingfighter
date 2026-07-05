extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const PLAYER_BASE_PADDLE_WIDTH := 155.0
const PLAYER_THROW_CENTER_Y_OFFSET := 25.0
const BOSS_BASE_WIDTH := 100.0


func get_player_throw_center(owner: Object) -> Vector2:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(
		owner,
		"player_pos",
		Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 50.0)
	)
	return Vector2(
		player_pos.x + PLAYER_BASE_PADDLE_WIDTH * 0.5,
		player_pos.y + PLAYER_THROW_CENTER_Y_OFFSET
	)


func get_boss_position(owner: Object) -> Vector2:
	return BattleSceneOwnerReader.get_vector2(
		owner,
		"boss_pos",
		Vector2(FIELD_WIDTH * 0.5 - BOSS_BASE_WIDTH * 0.5, 25.0)
	)


func get_boss_center_x(owner: Object) -> float:
	var boss_pos: Vector2 = get_boss_position(owner)
	return boss_pos.x + BOSS_BASE_WIDTH * 0.5


func activate_grenade(controller: Object, owner: Object, registry: Object) -> bool:
	if _is_activation_blocked(controller, registry):
		return false

	var boss_pos: Vector2 = get_boss_position(owner)
	var target_x: float = boss_pos.x + BOSS_BASE_WIDTH * 0.5 + randf_range(
		-_get_float(controller, "GRENADE_TARGET_RANDOM_X", 30.0),
		_get_float(controller, "GRENADE_TARGET_RANDOM_X", 30.0)
	)
	var target := Vector2(
		_clamp_radial_target_x(controller, target_x, "GRENADE_EXPLOSION_RADIUS", 190.0),
		boss_pos.y + 20.0
	)
	_queue_controller_pending_throw(
		controller,
		owner,
		registry,
		"grenade",
		_get_int(controller, "GRENADE_THROW_WINDUP_MSEC", 600),
		target
	)
	return true


func activate_flare(controller: Object, owner: Object, registry: Object) -> bool:
	if _is_activation_blocked(controller, registry):
		return false

	var boss_pos: Vector2 = get_boss_position(owner)
	var target_x: float = boss_pos.x + BOSS_BASE_WIDTH * 0.5 + randf_range(
		-_get_float(controller, "FLARE_TARGET_RANDOM_X", 50.0),
		_get_float(controller, "FLARE_TARGET_RANDOM_X", 50.0)
	)
	var target := Vector2(
		_clamp_radial_target_x(controller, target_x, "FLARE_RADIUS", 180.0),
		boss_pos.y + 40.0 + _get_float(controller, "FLARE_TARGET_BELOW_BOSS", 40.0)
	)
	_queue_controller_pending_throw(
		controller,
		owner,
		registry,
		"flare",
		_get_int(controller, "FLARE_THROW_WINDUP_MSEC", 600),
		target
	)
	return true


func activate_tear_gas(controller: Object, owner: Object, registry: Object) -> bool:
	if _is_activation_blocked(controller, registry, _get_int(controller, "TEAR_GAS_THROW_LOCK_MSEC", 0)):
		return false

	var boss_pos: Vector2 = get_boss_position(owner)
	var target_x: float = boss_pos.x + BOSS_BASE_WIDTH * 0.5 + randf_range(
		-_get_float(controller, "TEAR_GAS_TARGET_RANDOM_X", 55.0),
		_get_float(controller, "TEAR_GAS_TARGET_RANDOM_X", 55.0)
	)
	var target := Vector2(
		_clamp_radial_target_x(controller, target_x, "TEAR_GAS_MAX_RADIUS_X", 240.0),
		boss_pos.y + 40.0 + _get_float(controller, "TEAR_GAS_TARGET_BELOW_BOSS", 30.0)
	)
	_queue_controller_pending_throw(
		controller,
		owner,
		registry,
		"tear_gas",
		_get_int(controller, "TEAR_GAS_THROW_WINDUP_MSEC", 600),
		target,
		true
	)
	return true


func activate_dynamite(controller: Object, owner: Object, registry: Object) -> bool:
	if _is_activation_blocked(controller, registry, _get_int(controller, "DYNAMITE_THROW_LOCK_MSEC", 0)):
		return false

	var boss_pos: Vector2 = get_boss_position(owner)
	var target := Vector2(
		boss_pos.x + BOSS_BASE_WIDTH * 0.5 + randf_range(-30.0, 30.0),
		_get_float(controller, "DYNAMITE_LAND_Y", 120.0)
	)
	_queue_controller_pending_throw(
		controller,
		owner,
		registry,
		"dynamite",
		_get_int(controller, "DYNAMITE_THROW_WINDUP_MSEC", 500),
		target,
		true
	)
	return true


func activate_molotov(controller: Object, owner: Object, registry: Object) -> bool:
	if _is_activation_blocked(controller, registry, _get_int(controller, "MOLOTOV_THROW_LOCK_MSEC", 0)):
		return false

	var boss_pos: Vector2 = get_boss_position(owner)
	var target_x: float = boss_pos.x + BOSS_BASE_WIDTH * 0.5 + randf_range(
		-_get_float(controller, "MOLOTOV_TARGET_RANDOM_X", 50.0),
		_get_float(controller, "MOLOTOV_TARGET_RANDOM_X", 50.0)
	)
	var target := Vector2(
		_clamp_molotov_target_x(controller, target_x),
		_resolve_molotov_target_y(controller, boss_pos)
	)
	_queue_controller_pending_throw(
		controller,
		owner,
		registry,
		"molotov",
		_get_int(controller, "MOLOTOV_THROW_WINDUP_MSEC", 600),
		target,
		true
	)
	return true


func _resolve_molotov_target_y(controller: Object, boss_pos: Vector2) -> float:
	var requested_y: float = boss_pos.y + _get_float(controller, "MOLOTOV_TARGET_BEHIND_BOSS_Y", -10.0)
	return max(_get_molotov_fire_min_center_y(controller), requested_y)


func _get_molotov_fire_min_center_y(controller: Object) -> float:
	var configured_y: float = _get_float(controller, "MOLOTOV_FIRE_MIN_CENTER_Y", -1.0)
	if configured_y > 0.0:
		return configured_y
	var fire_height: float = _get_float(controller, "MOLOTOV_FIRE_HEIGHT", 60.0)
	return max(10.0, fire_height * 0.5 + 10.0)


func _clamp_molotov_target_x(controller: Object, target_x: float) -> float:
	var field_width: float = _get_float(controller, "FIELD_WIDTH", FIELD_WIDTH)
	var fire_width: float = _get_float(controller, "MOLOTOV_FIRE_WIDTH", 150.0)
	var margin: float = max(10.0, fire_width * 0.5)
	return clamp(target_x, margin, max(margin, field_width - margin))


func _clamp_radial_target_x(controller: Object, target_x: float, radius_key: String, fallback_radius: float) -> float:
	var field_width: float = _get_float(controller, "FIELD_WIDTH", FIELD_WIDTH)
	var margin: float = min(field_width * 0.5, max(10.0, _get_float(controller, radius_key, fallback_radius)))
	return clamp(target_x, margin, max(margin, field_width - margin))


func activate_boomerang(
	controller: Object,
	owner: Object,
	registry: Object,
	gauntlet_context_callback: Callable = Callable()
) -> bool:
	if _is_activation_blocked(controller, registry):
		return false

	var boss_pos: Vector2 = get_boss_position(owner)
	var target := Vector2(
		boss_pos.x + BOSS_BASE_WIDTH * 0.5,
		_get_float(controller, "BOOMERANG_MAX_TRAVEL_Y", 25.0)
	)
	var gauntlet_context: Dictionary = {}
	if gauntlet_context_callback.is_valid():
		var value: Variant = gauntlet_context_callback.call(registry)
		if value is Dictionary:
			gauntlet_context = value
	_queue_controller_pending_throw(
		controller,
		owner,
		registry,
		"boomerang",
		_get_int(controller, "BOOMERANG_THROW_WINDUP_MSEC", 400),
		target,
		true,
		{"gauntlet_equipped": bool(gauntlet_context.get("equipped", false))}
	)
	return true


func activate_banana(controller: Object, owner: Object, registry: Object) -> bool:
	if _is_activation_blocked(controller, registry, _get_int(controller, "BANANA_THROW_LOCK_MSEC", 0)):
		return false

	var boss_pos: Vector2 = get_boss_position(owner)
	var target := Vector2(
		boss_pos.x + BOSS_BASE_WIDTH * 0.5 + randf_range(-50.0, 50.0),
		_get_float(controller, "BANANA_LAND_Y", 45.0)
	)
	_queue_controller_pending_throw(
		controller,
		owner,
		registry,
		"banana",
		_get_int(controller, "BANANA_THROW_WINDUP_MSEC", 500),
		target,
		true
	)
	return true


func activate_soap(controller: Object, owner: Object, registry: Object) -> bool:
	if _is_activation_blocked(controller, registry, _get_int(controller, "SOAP_THROW_LOCK_MSEC", 0)):
		return false

	var boss_pos: Vector2 = get_boss_position(owner)
	var target := Vector2(
		boss_pos.x + BOSS_BASE_WIDTH * 0.5 + randf_range(-40.0, 40.0),
		_get_float(controller, "SOAP_LAND_Y", 45.0)
	)
	_queue_controller_pending_throw(
		controller,
		owner,
		registry,
		"soap",
		_get_int(controller, "SOAP_THROW_WINDUP_MSEC", 500),
		target,
		true
	)
	return true


func activate_spider_mine(
	controller: Object,
	owner: Object,
	registry: Object,
	deploy_callback: Callable = Callable()
) -> bool:
	if _is_activation_blocked(controller, registry, _get_int(controller, "SPIDER_MINE_THROW_LOCK_MSEC", 0)):
		return false

	if deploy_callback.is_valid():
		deploy_callback.call(owner)
	play_active_item_audio_cue(registry)
	return true


func is_throw_locked(controller: Object, registry: Object, lock_msec: int = -1) -> bool:
	var effective_lock_msec: int = lock_msec
	if effective_lock_msec < 0:
		effective_lock_msec = _get_int(controller, "THROW_LOCK_MSEC", 0)
	if effective_lock_msec <= 0:
		return false
	var round_state: Object = _get_instance(registry, "round_flow_state")
	if round_state == null or not round_state.has_method("get_round_start_time_msec"):
		return false
	var round_start_msec: int = int(round_state.get_round_start_time_msec())
	if round_start_msec <= 0:
		return false
	return Time.get_ticks_msec() - round_start_msec < effective_lock_msec


func queue_pending_throw(
	pending_throws: Array[Dictionary],
	owner: Object,
	registry: Object,
	item_name: String,
	windup_msec: int,
	target_position: Vector2,
	play_active_item_audio: bool = false,
	extra_fields: Dictionary = {}
) -> void:
	_append_pending_throw(
		pending_throws,
		owner,
		registry,
		item_name,
		windup_msec,
		target_position,
		play_active_item_audio,
		extra_fields
	)


func _queue_controller_pending_throw(
	controller: Object,
	owner: Object,
	registry: Object,
	item_name: String,
	windup_msec: int,
	target_position: Vector2,
	play_active_item_audio: bool = false,
	extra_fields: Dictionary = {}
) -> void:
	var effective_windup_msec: int = _get_commando_adjusted_windup_msec(
		controller,
		registry,
		item_name,
		windup_msec
	)
	var merged_extra_fields: Dictionary = extra_fields.duplicate(true)
	merged_extra_fields["base_windup_msec"] = windup_msec
	_append_pending_throw(
		_get_array(controller, "pending_throws"),
		owner,
		registry,
		item_name,
		effective_windup_msec,
		target_position,
		play_active_item_audio,
		merged_extra_fields
	)


func _append_pending_throw(
	pending_throws: Array,
	owner: Object,
	registry: Object,
	item_name: String,
	windup_msec: int,
	target_position: Vector2,
	play_active_item_audio: bool,
	extra_fields: Dictionary
) -> void:
	var now_msec: int = Time.get_ticks_msec()
	var pending_throw := {
		"item_name": item_name,
		"start_msec": now_msec,
		"release_msec": now_msec + windup_msec,
		"windup_msec": windup_msec,
		"start_position": get_player_throw_center(owner),
		"target_position": target_position,
	}
	for key in extra_fields:
		pending_throw[key] = extra_fields[key]
	pending_throws.append(pending_throw)
	play_throw_before_audio(registry)
	if play_active_item_audio:
		play_active_item_audio_cue(registry)


func play_throw_before_audio(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_throw_before"):
		audio.play_throw_before()


func play_active_item_audio_cue(registry: Object) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio != null and audio.has_method("play_active_item"):
		audio.play_active_item()


func _is_activation_blocked(controller: Object, registry: Object, lock_msec: int = -1) -> bool:
	if is_throw_locked(controller, registry, lock_msec):
		return true
	if controller != null and controller.has_method("is_throw_windup_active"):
		return bool(controller.is_throw_windup_active())
	return false


func _get_commando_adjusted_windup_msec(
	controller: Object,
	registry: Object,
	item_name: String,
	windup_msec: int
) -> int:
	if controller != null and controller.has_method("get_commando_adjusted_windup_msec"):
		return max(1, int(controller.get_commando_adjusted_windup_msec(item_name, windup_msec, registry)))
	return max(1, int(windup_msec))


func _get_array(source: Object, key: String) -> Array:
	if source == null:
		return []
	var value: Variant = source.get(key)
	if value is Array:
		return value
	return []


func _get_float(source: Object, key: String, fallback: float = 0.0) -> float:
	if source == null:
		return fallback
	var value: Variant = source.get(key)
	if value is float or value is int:
		return float(value)
	return fallback


func _get_int(source: Object, key: String, fallback: int = 0) -> int:
	if source == null:
		return fallback
	var value: Variant = source.get(key)
	if value is int or value is float:
		return int(value)
	return fallback


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
