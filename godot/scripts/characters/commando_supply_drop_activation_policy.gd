extends RefCounted

# Pure activation policy for Commando's base Supply Drop skill.
#
# Hold accumulation and radio/HUD feedback remain stateful concerns in
# CommandoSupplyDropState. This owner centralizes only command aliases and the
# character, transform, emergency-supply, round, gauge, and cooldown gates.

const PLAYER_SERVE_HOLD_ALLOWED_SECONDS := 6.0
const POST_SERVE_HOLD_LOCK_SECONDS := 3.0


func get_current_msec(deps: Dictionary) -> int:
	return int(deps.get("current_msec", Time.get_ticks_msec()))


func is_supply_drop_hold_pressed(input_snapshot: Dictionary) -> bool:
	return (
		bool(input_snapshot.get("down_pressed", false))
		or bool(input_snapshot.get("supply_drop_hold_pressed", false))
		or bool(input_snapshot.get("commando_supply_drop_hold_pressed", false))
	)


func can_hold_for_activation(
	special_gauge: float,
	skill_config: Object,
	skill_state: Object,
	deps: Dictionary,
	current_msec: int
) -> bool:
	return (
		can_accept_supply_hold(deps, current_msec)
		and is_supply_drop_activation_ready(
			special_gauge,
			skill_config,
			skill_state,
			deps,
			current_msec
		)
	)


func can_accept_supply_hold(deps: Dictionary, current_msec: int) -> bool:
	if not _is_commando_selected(deps):
		return false
	if _is_original_skill_blocked(deps):
		return false
	if _is_transform_skill_blocked(deps):
		return false
	if _is_emergency_supply_suppressing(deps, current_msec):
		return false
	return true


func is_supply_drop_activation_ready(
	special_gauge: float,
	skill_config: Object,
	skill_state: Object,
	deps: Dictionary,
	current_msec: int
) -> bool:
	if not _is_round_state_allowing_supply_drop(deps, current_msec):
		return false
	return can_activate(special_gauge, skill_config, skill_state, current_msec)


func can_activate(
	special_gauge: float,
	skill_config: Object,
	skill_state: Object,
	current_msec: int
) -> bool:
	var cost := 350.0
	var cooldown := 40.0
	if skill_config != null:
		if skill_config.has_method("get_skill_cost"):
			cost = float(skill_config.get_skill_cost("supply_drop"))
		if skill_config.has_method("get_cooldown_seconds"):
			cooldown = float(skill_config.get_cooldown_seconds("supply_drop"))
	if special_gauge < cost:
		return false
	if skill_state != null and skill_state.has_method("get_cooldown_remaining"):
		return float(skill_state.get_cooldown_remaining(
			"supply_drop",
			current_msec,
			cooldown
		)) <= 0.0
	return true


func _is_commando_selected(deps: Dictionary) -> bool:
	if not deps.has("selected_character_type"):
		return true
	var character_type: String = str(deps.get("selected_character_type", "")).strip_edges().to_lower()
	return character_type == "soldier" or character_type == "commando"


func _is_original_skill_blocked(deps: Dictionary) -> bool:
	for key in [
		"commando_original_skills_blocked",
		"soldier_original_skills_blocked",
		"original_skills_blocked",
		"character_original_skills_blocked",
		"commando_skills_blocked",
		"character_skills_blocked",
	]:
		if bool(deps.get(key, false)):
			return true
	return false


func _is_transform_skill_blocked(deps: Dictionary) -> bool:
	for key in [
		"odins_eye_transformed",
		"horn_strawberry_transformed",
		"commando_transformed",
		"character_transformed",
		"original_skill_transform_active",
	]:
		if bool(deps.get(key, false)):
			return true
	for source_key in ["mythic_item_runtime", "legendary_item_runtime", "active_item_runtime"]:
		var source: Object = deps.get(source_key, null)
		if _object_reports_any_true(source, [
			"is_odins_eye_transformed",
			"is_horn_strawberry_transformed",
			"is_original_skill_transform_active",
		]):
			return true
	return false


func _is_emergency_supply_suppressing(deps: Dictionary, current_msec: int) -> bool:
	var emergency_state: Object = deps.get("commando_emergency_supply_state", null)
	if emergency_state == null:
		return false
	if emergency_state.has_method("is_supply_drop_hold_suppressed"):
		return bool(emergency_state.is_supply_drop_hold_suppressed(current_msec))
	if emergency_state.has_method("get_snapshot"):
		var snapshot: Dictionary = _get_dictionary(emergency_state.get_snapshot())
		return current_msec < int(snapshot.get("suppress_until_msec", 0))
	return false


func _is_round_state_allowing_supply_drop(deps: Dictionary, current_msec: int) -> bool:
	if bool(deps.get("commando_supply_drop_ignore_round_gate", false)):
		return true
	var round_state: Object = deps.get("round_state", null)
	if round_state == null:
		return true
	var waiting_for_serve := false
	if round_state.has_method("is_waiting_for_serve"):
		waiting_for_serve = bool(round_state.is_waiting_for_serve())
	var player_serves := false
	if round_state.has_method("does_player_serve"):
		player_serves = bool(round_state.does_player_serve())
	var snapshot: Dictionary = _get_round_snapshot(round_state)
	if waiting_for_serve:
		if not player_serves:
			return false
		return float(snapshot.get("serve_timer", 0.0)) >= PLAYER_SERVE_HOLD_ALLOWED_SECONDS

	var lock_seconds: float = max(0.0, float(deps.get(
		"commando_supply_drop_post_serve_lock_seconds",
		POST_SERVE_HOLD_LOCK_SECONDS
	)))
	if lock_seconds <= 0.0:
		return true
	var round_start_msec: int = _get_round_start_msec(round_state, snapshot)
	if round_start_msec <= 0:
		return true
	return float(max(0, current_msec - round_start_msec)) >= lock_seconds * 1000.0


func _get_round_snapshot(round_state: Object) -> Dictionary:
	if round_state != null and round_state.has_method("get_snapshot"):
		return _get_dictionary(round_state.get_snapshot())
	return {}


func _get_round_start_msec(round_state: Object, snapshot: Dictionary) -> int:
	if round_state != null and round_state.has_method("get_round_start_time_msec"):
		return int(round_state.get_round_start_time_msec())
	return int(snapshot.get("round_start_time_msec", 0))


func _get_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _object_reports_any_true(source: Object, method_names: Array) -> bool:
	if source == null:
		return false
	for method_name in method_names:
		var callable_name := str(method_name)
		if source.has_method(callable_name) and bool(source.call(callable_name)):
			return true
	return false
