extends RefCounted

const SmasherPlayerController := preload("res://scripts/characters/smasher_player_controller.gd")

var shared_controller: Object = SmasherPlayerController.new()


func update(
	delta: float,
	frame_counter: int,
	player_pos: Vector2,
	player_speed: float,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var next_special_gauge: float = float(config.get("special_gauge", 0.0))
	var current_msec: int = int(config.get("current_msec", deps.get("current_msec", Time.get_ticks_msec())))
	deps["current_msec"] = current_msec
	deps["selected_character_type"] = str(config.get("selected_character_type", deps.get("selected_character_type", "soldier")))
	var input_reader: Object = deps.get("input_reader", null)
	var input_snapshot: Dictionary = input_reader.get_snapshot() if input_reader != null and input_reader.has_method("get_snapshot") else {}
	var current_stage: int = int(max(1, int(config.get("current_stage", deps.get("current_stage", 1)))))
	deps["current_stage"] = current_stage
	var pending_skill_gold_award := 0
	var weapon_controller: Object = deps.get("commando_weapon_controller", null)
	var skill_config: Object = deps.get("skill_config", null)
	var skill_input_locked: bool = _is_player_skill_input_locked(deps)
	if weapon_controller != null and weapon_controller.has_method("sync_equipped_permanent"):
		weapon_controller.sync_equipped_permanent(skill_config)
	if weapon_controller != null and weapon_controller.has_method("prepare_stage_start"):
		weapon_controller.prepare_stage_start(current_stage)

	var emergency_state: Object = deps.get("commando_emergency_supply_state", null)
	if not skill_input_locked and emergency_state != null and emergency_state.has_method("update_input"):
		var emergency_result: Dictionary = emergency_state.update_input(
			input_snapshot,
			current_msec,
			next_special_gauge,
			deps
		)
		next_special_gauge = float(emergency_result.get("special_gauge", next_special_gauge))
		if bool(emergency_result.get("activated", false)):
			pending_skill_gold_award += _get_skill_gold_award("emergency_supply", deps)
			var existing_supply_state: Object = deps.get("commando_supply_drop_state", null)
			if existing_supply_state != null and existing_supply_state.has_method("cancel_transient"):
				existing_supply_state.cancel_transient()

	var supply_state: Object = deps.get("commando_supply_drop_state", null)
	if not skill_input_locked and supply_state != null and supply_state.has_method("update_input"):
		deps["commando_supply_drop_collision_context"] = _build_supply_drop_collision_context(player_pos, config, deps)
		var supply_result: Dictionary = supply_state.update_input(
			input_snapshot,
			delta,
			next_special_gauge,
			skill_config,
			deps.get("skill_state", null),
			deps
		)
		next_special_gauge += float(supply_result.get("special_gauge_delta", 0.0))
		if bool(supply_result.get("activated", false)):
			_trigger_configured_cooldown("supply_drop", deps)
			pending_skill_gold_award += _get_skill_gold_award("supply_drop", deps)

	var firearm_runtime: Object = deps.get("commando_firearm_runtime", null)
	if not skill_input_locked and firearm_runtime != null and firearm_runtime.has_method("update_input"):
		var firearm_config: Dictionary = config.duplicate()
		firearm_config["player_pos"] = player_pos
		firearm_config["player_speed"] = player_speed
		var firearm_result: Dictionary = firearm_runtime.update_input(input_snapshot, next_special_gauge, firearm_config, deps)
		next_special_gauge = float(firearm_result.get("special_gauge", next_special_gauge))
		if bool(firearm_result.get("fired", false)):
			pending_skill_gold_award += _get_skill_gold_award(str(firearm_result.get("weapon_id", "")), deps)

	var movement_config: Dictionary = config.duplicate(true)
	movement_config["special_gauge"] = next_special_gauge
	if firearm_runtime != null and firearm_runtime.has_method("is_player_control_locked"):
		movement_config["horizontal_input_locked"] = bool(firearm_runtime.is_player_control_locked())
	if firearm_runtime != null and firearm_runtime.has_method("get_movement_speed_multiplier"):
		movement_config["paddle_max_speed_multiplier"] = float(firearm_runtime.get_movement_speed_multiplier())
	var result: Dictionary = shared_controller.update(delta, frame_counter, player_pos, player_speed, movement_config, deps)
	result["special_gauge"] = next_special_gauge
	if pending_skill_gold_award > 0:
		result["skill_gold_award"] = int(result.get("skill_gold_award", 0)) + pending_skill_gold_award
	return result


func _is_player_skill_input_locked(deps: Dictionary) -> bool:
	if bool(deps.get("player_skill_input_locked", false)):
		return true
	var status_effect_state: Object = deps.get("status_effect_state", null)
	if status_effect_state != null:
		if status_effect_state.has_method("is_player_stun_active") and bool(status_effect_state.is_player_stun_active()):
			return true
		if status_effect_state.has_method("has_status") and bool(status_effect_state.has_status("player", "stun")):
			return true
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("is_horn_strawberry_skills_locked")
		and bool(mythic_item_runtime.is_horn_strawberry_skills_locked())
	):
		return true
	if (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("is_horn_strawberry_control_locked")
		and bool(mythic_item_runtime.is_horn_strawberry_control_locked())
	):
		return true
	return false


func _trigger_configured_cooldown(skill_name: String, deps: Dictionary) -> void:
	var skill_state: Object = deps.get("skill_state", null)
	if skill_state == null or not skill_state.has_method("trigger_configured_cooldown"):
		return
	skill_state.trigger_configured_cooldown(skill_name, Time.get_ticks_msec(), deps.get("skill_config", null))


func _get_skill_gold_award(skill_name: String, deps: Dictionary) -> int:
	var skill_config: Object = deps.get("skill_config", null)
	if skill_config != null and skill_config.has_method("get_skill_gold_reward"):
		return max(0, int(skill_config.get_skill_gold_reward(skill_name)))
	if skill_config != null and skill_config.has_method("calculate_skill_gold_reward"):
		return max(0, int(skill_config.calculate_skill_gold_reward(skill_name)))
	return 0


func _build_supply_drop_collision_context(player_pos: Vector2, config: Dictionary, deps: Dictionary) -> Dictionary:
	var context := {
		"player_pos": player_pos,
		"player_paddle_size": Vector2(
			max(1.0, float(config.get("paddle_width", 155.0))),
			max(1.0, float(config.get("paddle_height", 50.0)))
		),
		"hitbox_padding": float(config.get("hitbox_padding", 5.0)),
	}
	var active_item_runtime: Object = deps.get("active_item_runtime", null)
	if active_item_runtime != null and active_item_runtime.has_method("get_ball_collision_context"):
		context.merge(active_item_runtime.get_ball_collision_context(), true)
	return context
