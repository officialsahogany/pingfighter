extends RefCounted

const ITEM_ODINS_EYE := "odins_eye"
const ROLL_REVIVAL_CHANCE := "revival_chance"


func sync_equipment_state(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state == null:
		return
	state.set_equipped(is_equipped(runtime))


func is_equipped(runtime: Object) -> bool:
	return runtime.roll_query.has_equipped_item_name(runtime, ITEM_ODINS_EYE)


func is_available(runtime: Object) -> bool:
	sync_equipment_state(runtime)
	var state: Object = runtime.odins_eye_state
	return state != null and state.can_revive(is_equipped(runtime))


func has_revival_used(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and bool(state.revival_used)


func is_penalty_active(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and bool(state.penalty_active)


func is_transformed(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.is_transformed()


func is_skills_locked(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.is_skills_locked()


func is_control_locked(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.is_control_locked()


func is_revival_animation_active(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.is_revival_animation_active()


func is_death_animation_active(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.is_death_animation_active()


func is_effect_active(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.is_effect_active()


func get_revival_chance_pct(runtime: Object) -> float:
	var item_data: Dictionary = _get_equipped_item_data(runtime)
	if item_data.is_empty():
		return runtime.catalog.get_default_roll_value(ITEM_ODINS_EYE, ROLL_REVIVAL_CHANCE)
	return runtime.roll_query.get_item_roll_value(
		runtime,
		item_data,
		ITEM_ODINS_EYE,
		ROLL_REVIVAL_CHANCE,
		true
	)


func get_revival_chance(runtime: Object) -> float:
	return clamp(get_revival_chance_pct(runtime) / 100.0, 0.0, 1.0)


func try_trigger_revival(runtime: Object, loss_type: String = "round", roll_pct: float = -1.0) -> bool:
	sync_equipment_state(runtime)
	var state: Object = runtime.odins_eye_state
	if state == null or not state.can_revive(is_equipped(runtime)):
		return false
	var actual_roll: float = roll_pct if roll_pct >= 0.0 else randf() * 100.0
	var chance_pct: float = get_revival_chance_pct(runtime)
	var triggered: bool = actual_roll <= chance_pct
	state.record_roll(actual_roll, triggered)
	if not triggered:
		return false
	state.begin_revival(loss_type, 3.0, actual_roll)
	return true


func begin_death_sequence(runtime: Object, loss_type: String = "round") -> bool:
	sync_equipment_state(runtime)
	var state: Object = runtime.odins_eye_state
	if state == null or not state.penalty_active:
		return false
	state.begin_death_sequence(loss_type)
	return true


func consume_revival_finalize_ready(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.consume_revival_finalize_ready()


func consume_death_finalize_ready(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.consume_death_finalize_ready()


func consume_death_explosion_edge(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.consume_death_explosion_edge()


func consume_disintegration_edge(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.consume_disintegration_edge()


func clear_after_victory(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.clear_after_victory()


func clear_after_death(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.clear_after_death()


func get_move_speed_multiplier(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 1.0 if state == null else state.get_move_speed_multiplier()


func get_dash_token_limit_override(runtime: Object) -> Variant:
	var state: Object = runtime.odins_eye_state
	if state == null:
		return null
	return state.get_dash_token_limit_override()


func get_dash_cooldown_multiplier(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 1.0 if state == null else state.get_dash_cooldown_multiplier()


func get_death_phase(runtime: Object) -> String:
	var state: Object = runtime.odins_eye_state
	return "" if state == null else state.get_death_phase()


func get_death_overall_progress(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 0.0 if state == null else state.get_death_overall_progress()


func get_death_phase_progress(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 0.0 if state == null else state.get_death_phase_progress()


func get_death_energy_buildup(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 0.0 if state == null else state.get_death_energy_buildup()


func get_death_disintegrate_progress(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 0.0 if state == null else state.get_death_disintegrate_progress()


func get_death_shake_intensity(runtime: Object) -> float:
	var state: Object = runtime.odins_eye_state
	return 0.0 if state == null else state.get_death_shake_intensity()


func should_hide_player_paddle(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and state.should_hide_player_paddle()


func get_context(runtime: Object) -> Dictionary:
	sync_equipment_state(runtime)
	var state: Object = runtime.odins_eye_state
	if state == null:
		return {"equipped": false, "active": false, "state": "idle"}
	var context: Dictionary = state.get_context()
	context["revival_chance_pct"] = get_revival_chance_pct(runtime)
	context["revival_chance"] = get_revival_chance(runtime)
	return context


func clear_on_equip(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.set_equipped(true)
		state.on_stage_advance()


func clear_on_unequip(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.set_equipped(false)


func reset(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.reset_all()


func reset_round(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.reset_round()


func on_stage_advance(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state == null:
		return
	sync_equipment_state(runtime)
	state.on_stage_advance()


func clear_runtime(runtime: Object) -> void:
	var state: Object = runtime.odins_eye_state
	if state != null:
		state.on_stage_advance()


func update_runtime(runtime: Object, fps_scale: float) -> bool:
	var state: Object = runtime.odins_eye_state
	if state == null:
		return false
	return state.update(max(0.0, fps_scale) / 60.0)


func has_runtime_update_work(runtime: Object) -> bool:
	var state: Object = runtime.odins_eye_state
	return state != null and (
		state.is_effect_active()
		or state.revival_finalize_ready
		or state.death_finalize_ready
		or state.death_explosion_edge_ready
		or state.death_disintegration_edge_ready
	)


func _get_equipped_item_data(runtime: Object) -> Dictionary:
	if not runtime.equipped_items.has(ITEM_ODINS_EYE):
		return {}
	return runtime._get_dict(runtime.equipped_items[ITEM_ODINS_EYE])
