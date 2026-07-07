extends RefCounted

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkConversionValues := preload("res://scripts/characters/perk_conversion_values.gd")

const ITEM_HORN_STRAWBERRY_MASK := "horn_strawberry_mask"
const ROLL_TRANSFORM_DURATION := "transform_duration"
const TRANSFORM_GAUGE_COST := 500.0


func sync_equipment_state(runtime: Object) -> void:
	var state: Object = runtime.horn_strawberry_mask_state
	if state == null:
		return
	if is_active(runtime):
		state.set_equipped(true, get_transform_duration_sec(runtime))
	else:
		state.deactivate_equipment(true)


func has_runtime_update_work(runtime: Object) -> bool:
	var state: Object = runtime.horn_strawberry_mask_state
	var eat_state: Object = runtime.horn_strawberry_eat_state
	var field_state: Object = runtime.horn_strawberry_field_state
	var horn_charge_state: Object = runtime.horn_strawberry_horn_charge_state
	var bomb_state: Object = runtime.horn_strawberry_bomb_state
	return (
		(state != null and state.has_runtime_update_work())
		or (eat_state != null and eat_state.has_runtime_update_work())
		or (field_state != null and field_state.has_runtime_update_work())
		or (horn_charge_state != null and horn_charge_state.has_runtime_update_work())
		or (bomb_state != null and bomb_state.has_runtime_update_work())
	)


func update(
	runtime: Object,
	owner: Object,
	registry: Object,
	delta: float,
	constants: Dictionary = {}
) -> void:
	sync_equipment_state(runtime)
	var state: Object = runtime.horn_strawberry_mask_state
	if state == null or not state.active:
		return
	var input_snapshot: Dictionary = _get_input_snapshot(runtime, owner, registry)
	if state.feed_command_input(input_snapshot, delta):
		try_transform(runtime, owner, registry)
	var was_transformed: bool = state.is_transformed()
	if was_transformed:
		_update_skill_inputs(runtime, owner, registry, delta, input_snapshot)
	_update_lingering_skills(runtime, owner, registry, delta)
	var changed: bool = bool(state.update(delta))
	if changed and not was_transformed and state.is_transformed():
		_reset_transform_skill_state(runtime)
		_force_viper_jetpack_land(runtime, owner, registry)
		_sync_paddle_scale(runtime, owner, registry, constants)
	elif changed and not state.is_transformed():
		if was_transformed:
			_play_horn_strawberry_audio(runtime, registry, "_play_horn_strawberry_change_audio")
		_reset_detransform_skill_state(runtime)
		_sync_paddle_scale(runtime, owner, registry, constants)


func try_transform(runtime: Object, owner: Object, registry: Object = null) -> bool:
	sync_equipment_state(runtime)
	var state: Object = runtime.horn_strawberry_mask_state
	if state == null:
		return false
	var current_gauge: float = _get_owner_gauge(runtime, owner)
	if not state.can_transform(current_gauge):
		return false
	var next_gauge: float = max(0.0, current_gauge - TRANSFORM_GAUGE_COST)
	if owner != null:
		owner.set("special_gauge", next_gauge)
	state.begin_transform()
	_play_horn_strawberry_audio(runtime, registry, "_play_horn_strawberry_change_audio")
	_trigger_feedback(runtime, registry)
	return true


func feed_command_input(
	runtime: Object,
	input_snapshot: Dictionary,
	delta: float,
	owner: Object = null,
	registry: Object = null
) -> bool:
	sync_equipment_state(runtime)
	var state: Object = runtime.horn_strawberry_mask_state
	if state == null:
		return false
	if not state.feed_command_input(input_snapshot, delta):
		return false
	return try_transform(runtime, owner, registry)


func get_transform_duration_sec(runtime: Object) -> float:
	if PerkConversionFlags.is_enabled():
		return _get_converted_mythic_value(runtime, ROLL_TRANSFORM_DURATION)
	var item_data: Dictionary = _get_equipped_item_data(runtime)
	if item_data.is_empty():
		return 60.0
	return max(0.1, runtime.roll_query.get_item_roll_value(
		runtime,
		item_data,
		ITEM_HORN_STRAWBERRY_MASK,
		ROLL_TRANSFORM_DURATION,
		true
	))


func get_context(runtime: Object) -> Dictionary:
	var state: Object = runtime.horn_strawberry_mask_state
	if state == null:
		return {"equipped": false, "active": false, "state": "idle"}
	var context: Dictionary = state.get_context()
	context["transform_duration_roll_sec"] = get_transform_duration_sec(runtime) if state.active else 60.0
	context["eat"] = runtime.horn_strawberry_eat_state.get_context()
	context["field"] = runtime.horn_strawberry_field_state.get_context()
	context["horn_charge"] = runtime.horn_strawberry_horn_charge_state.get_context()
	context["bomb"] = runtime.horn_strawberry_bomb_state.get_context()
	return context


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_HORN_STRAWBERRY_MASK)


func is_active(runtime: Object) -> bool:
	if PerkConversionFlags.is_enabled():
		return _get_converted_perk_level(runtime) > 0
	return is_equipped(runtime)


func is_transformed(runtime: Object) -> bool:
	var state: Object = runtime.horn_strawberry_mask_state
	return state != null and state.is_transformed()


func is_event_playing(runtime: Object) -> bool:
	var state: Object = runtime.horn_strawberry_mask_state
	return state != null and state.is_event_playing()


func is_skills_locked(runtime: Object) -> bool:
	var state: Object = runtime.horn_strawberry_mask_state
	return state != null and state.is_skills_locked()


func is_control_locked(runtime: Object) -> bool:
	var state: Object = runtime.horn_strawberry_mask_state
	var horn_charge_state: Object = runtime.horn_strawberry_horn_charge_state
	return (
		(state != null and state.is_control_locked())
		or (horn_charge_state != null and horn_charge_state.is_control_locked())
	)


func get_move_speed(runtime: Object) -> Variant:
	var state: Object = runtime.horn_strawberry_mask_state
	if state == null:
		return null
	return state.get_move_speed()


func get_paddle_size_bonus_pct(runtime: Object) -> float:
	var state: Object = runtime.horn_strawberry_mask_state
	return 0.0 if state == null else state.get_paddle_size_bonus_pct()


func get_gauge_on_hit(runtime: Object) -> float:
	var state: Object = runtime.horn_strawberry_mask_state
	return 0.0 if state == null else state.get_gauge_on_hit()


func add_eat_paddle_growth(
	runtime: Object,
	owner: Object,
	registry: Object = null,
	amount_pct: float = 0.20,
	constants: Dictionary = {}
) -> bool:
	var state: Object = runtime.horn_strawberry_mask_state
	if state == null or not state.add_eat_paddle_growth_bonus_pct(amount_pct):
		return false
	_sync_paddle_scale(runtime, owner, registry, constants)
	return true


func clear_on_equip(runtime: Object) -> void:
	var state: Object = runtime.horn_strawberry_mask_state
	if state == null:
		return
	state.set_equipped(is_active(runtime), get_transform_duration_sec(runtime))
	state.reset_round()
	_reset_all_skill_state(runtime)


func clear_on_unequip(runtime: Object) -> void:
	var state: Object = runtime.horn_strawberry_mask_state
	if state != null:
		state.deactivate_equipment(true)
	_reset_all_skill_state(runtime)


func reset(runtime: Object) -> void:
	var state: Object = runtime.horn_strawberry_mask_state
	if state != null:
		state.reset_all()
	_reset_all_skill_state(runtime)


func reset_round(_runtime: Object) -> void:
	# Round boundaries keep the command transform alive. Horn Strawberry is a
	# once-per-stage, timed form; ending it on a lost point makes the 60s kit
	# evaporate before the player can use it. Stage advance and full reset still
	# clear the transform and detached field/bomb paint lingerers.
	pass


func on_stage_advance(runtime: Object) -> void:
	var state: Object = runtime.horn_strawberry_mask_state
	if state == null:
		return
	sync_equipment_state(runtime)
	state.on_stage_advance()
	_reset_all_skill_state(runtime)


func notify_field_hit(runtime: Object, barrier_id: int, impact_pos: Vector2 = Vector2.ZERO, deps: Dictionary = {}) -> bool:
	var field_state: Object = runtime.horn_strawberry_field_state
	if field_state == null or not field_state.notify_barrier_hit(barrier_id):
		return false
	var registry: Object = deps.get("registry", null)
	if registry != null:
		_play_horn_strawberry_audio(runtime, registry, "_play_horn_strawberry_field_break_audio")
	else:
		var audio: Object = deps.get("audio", null)
		if audio != null and audio.has_method("play_horn_strawberry_field_break"):
			audio.play_horn_strawberry_field_break()
	var ball_effects: Object = deps.get("ball_effects", null)
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		ball_effects.register_hit_pulse(impact_pos, Vector2(0.0, -1.0), 0.72, "horn_strawberry_field")
	return true


func consume_strong_boss_hit(
	runtime: Object,
	ball_pos: Vector2,
	ball_vel: Vector2,
	context: Dictionary,
	deps: Dictionary = {}
) -> Dictionary:
	var horn_charge_state: Object = runtime.horn_strawberry_horn_charge_state
	if horn_charge_state != null and horn_charge_state.has_method("consume_boss_hit_suppression"):
		var horn_result: Dictionary = horn_charge_state.consume_boss_hit_suppression(ball_pos, ball_vel, context, deps)
		if not horn_result.is_empty():
			return horn_result
	var bomb_state: Object = runtime.horn_strawberry_bomb_state
	if bomb_state != null and bomb_state.has_method("consume_boss_hit_suppression"):
		return bomb_state.consume_boss_hit_suppression(ball_pos, ball_vel, context, deps)
	return {}


func has_visible_effects(runtime: Object) -> bool:
	var state: Object = runtime.horn_strawberry_mask_state
	return (
		(state != null and state.is_event_playing())
		or (runtime.horn_strawberry_eat_state != null and runtime.horn_strawberry_eat_state.has_visible_effects())
		or (runtime.horn_strawberry_field_state != null and runtime.horn_strawberry_field_state.has_visible_effects())
		or (runtime.horn_strawberry_horn_charge_state != null and runtime.horn_strawberry_horn_charge_state.has_visible_effects())
		or (runtime.horn_strawberry_bomb_state != null and runtime.horn_strawberry_bomb_state.has_visible_effects())
	)


func _update_skill_inputs(
	runtime: Object,
	owner: Object,
	registry: Object,
	delta: float,
	input_snapshot: Dictionary
) -> void:
	var horn_charge_state: Object = runtime.horn_strawberry_horn_charge_state
	if horn_charge_state != null:
		horn_charge_state.update_input(
			input_snapshot,
			owner,
			runtime,
			registry,
			_is_skill_action_blocked(runtime)
		)
	var eat_state: Object = runtime.horn_strawberry_eat_state
	if eat_state != null:
		eat_state.update_input(input_snapshot, owner, runtime, registry)
	var field_state: Object = runtime.horn_strawberry_field_state
	if field_state != null:
		field_state.update_input(input_snapshot, delta, owner, runtime, registry)
	var bomb_state: Object = runtime.horn_strawberry_bomb_state
	if bomb_state != null:
		bomb_state.update_input(
			input_snapshot,
			delta,
			owner,
			runtime,
			_is_skill_action_blocked(runtime),
			registry
		)


func _update_lingering_skills(runtime: Object, owner: Object, registry: Object, delta: float) -> void:
	var transformed: bool = is_transformed(runtime)
	var eat_state: Object = runtime.horn_strawberry_eat_state
	if eat_state != null:
		eat_state.update(delta, owner, registry, runtime)
	var field_state: Object = runtime.horn_strawberry_field_state
	if field_state != null:
		field_state.update(delta, transformed)
	var horn_charge_state: Object = runtime.horn_strawberry_horn_charge_state
	if horn_charge_state != null:
		horn_charge_state.update(delta, owner, registry, runtime)
	var bomb_state: Object = runtime.horn_strawberry_bomb_state
	if bomb_state != null:
		bomb_state.update(delta, owner, registry, transformed, runtime)


func _reset_transform_skill_state(runtime: Object) -> void:
	_reset_all_skill_state(runtime)


func _reset_detransform_skill_state(runtime: Object) -> void:
	var eat_state: Object = runtime.horn_strawberry_eat_state
	if eat_state != null:
		eat_state.reset()
	var horn_charge_state: Object = runtime.horn_strawberry_horn_charge_state
	if horn_charge_state != null:
		horn_charge_state.reset()
	var bomb_state: Object = runtime.horn_strawberry_bomb_state
	if bomb_state != null:
		bomb_state.cancel_throwing_preserve_lingering()


func _reset_all_skill_state(runtime: Object) -> void:
	var eat_state: Object = runtime.horn_strawberry_eat_state
	if eat_state != null:
		eat_state.reset()
	var field_state: Object = runtime.horn_strawberry_field_state
	if field_state != null:
		field_state.reset()
	var horn_charge_state: Object = runtime.horn_strawberry_horn_charge_state
	if horn_charge_state != null:
		horn_charge_state.reset()
	var bomb_state: Object = runtime.horn_strawberry_bomb_state
	if bomb_state != null:
		bomb_state.reset()


func _is_skill_action_blocked(runtime: Object) -> bool:
	var horn_charge_state: Object = runtime.horn_strawberry_horn_charge_state
	if horn_charge_state != null and bool(horn_charge_state.get("active")):
		return true
	var eat_state: Object = runtime.horn_strawberry_eat_state
	if eat_state != null and bool(eat_state.get("eating")):
		return true
	var bomb_state: Object = runtime.horn_strawberry_bomb_state
	if bomb_state != null and bool(bomb_state.get("throwing")):
		return true
	return false


func _get_equipped_item_data(runtime: Object) -> Dictionary:
	if not runtime.equipped_items.has(ITEM_HORN_STRAWBERRY_MASK):
		return {}
	var value: Variant = runtime.equipped_items[ITEM_HORN_STRAWBERRY_MASK]
	return runtime._get_dict(value)


func _get_converted_mythic_value(runtime: Object, key: String) -> float:
	if _get_converted_perk_level(runtime) <= 0:
		return 0.0
	return PerkConversionValues.get_mythic_value(ITEM_HORN_STRAWBERRY_MASK, key)


func _get_converted_perk_level(runtime: Object) -> int:
	if runtime != null and runtime.has_method("get_converted_perk_effect_level"):
		return max(0, int(runtime.get_converted_perk_effect_level(ITEM_HORN_STRAWBERRY_MASK)))
	return 0


func _get_input_snapshot(runtime: Object, owner: Object, registry: Object) -> Dictionary:
	var reader: Object = _get_input_reader(runtime, owner, registry)
	if reader == null or not reader.has_method("get_snapshot"):
		return {}
	var value: Variant = reader.get_snapshot()
	return value if value is Dictionary else {}


func _get_input_reader(runtime: Object, owner: Object, registry: Object) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var character_type: String = str(runtime._safe_owner_get(owner, "selected_character_type", "smasher")).strip_edges().to_lower()
	var key := "smasher_input_reader"
	if character_type == "soldier" or character_type == "commando":
		key = "commando_input_reader"
	elif character_type == "viper":
		key = "viper_input_reader"
	return registry.get_instance(key)


func _get_owner_gauge(runtime: Object, owner: Object) -> float:
	return max(0.0, float(runtime._safe_owner_get(owner, "special_gauge", 0.0)))


func _trigger_feedback(runtime: Object, registry: Object) -> void:
	runtime.gauge_feedback.trigger_gauge_flash(runtime, {"registry": registry})


func _play_horn_strawberry_audio(runtime: Object, registry: Object, method_name: String) -> void:
	if runtime == null:
		return
	var audio_router: Object = runtime.get("audio_router")
	if audio_router != null and audio_router.has_method("play_named"):
		audio_router.play_named(runtime, registry, method_name)


func _sync_paddle_scale(runtime: Object, owner: Object, registry: Object, constants: Dictionary) -> void:
	if owner != null:
		runtime.owner_syncer.sync_bulkup_paddle_scale(runtime, owner, registry, constants)


func _force_viper_jetpack_land(runtime: Object, owner: Object, registry: Object) -> void:
	var character_type: String = str(runtime._safe_owner_get(owner, "selected_character_type", "")).strip_edges().to_lower()
	if character_type != "viper":
		return
	var jetpack_state: Object = runtime._get_instance(registry, "viper_jetpack_state")
	if jetpack_state == null or not jetpack_state.has_method("force_land"):
		return
	jetpack_state.force_land({
		"audio": runtime._get_instance(registry, "game_audio"),
		"registry": registry,
		"owner": owner,
	})
