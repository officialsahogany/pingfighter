extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")


func build_deps(owner: Object, registry: Object) -> Dictionary:
	if owner == null or registry == null:
		return {}
	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var sample_start: int = _perf_begin(perf_logger)
	var character_type: String = str(_get_owner_value(owner, "selected_character_type", "smasher"))
	_perf_end(perf_logger, "physics.deps.character_type", sample_start)
	sample_start = _perf_begin(perf_logger)
	var skill_orb_tooltip_state := _get_skill_orb_tooltip_hover_state(owner, registry)
	_perf_end(perf_logger, "physics.deps.skill_tooltip_hover", sample_start)
	sample_start = _perf_begin(perf_logger)
	var deps := {
		"current_stage": int(_get_owner_value(owner, "current_stage", 1)),
		"scoreboard_state": _get_instance(registry, "scoreboard_state"),
		"stage3_boss_skill_state": _get_instance(registry, "stage3_boss_skill_state"),
		"power_state": _get_instance(registry, "smasher_power_smash_state") if character_type == "smasher" else null,
		"round_state": _get_instance(registry, "round_flow_state"),
		"mythic_item_runtime": _get_instance(registry, "mythic_item_runtime"),
		"serve_flow_controller": _get_instance(registry, "serve_flow_controller"),
		"serve_context": _build_serve_context(owner),
		"skill_orb_tooltip_active": not skill_orb_tooltip_state.is_empty(),
		"skill_orb_tooltip_key": str(skill_orb_tooltip_state.get("skill_name", "")),
	}
	_perf_end(perf_logger, "physics.deps.instances", sample_start)
	_perf_end(perf_logger, "physics.deps.total", total_start)
	return deps


func _build_serve_context(owner: Object) -> Dictionary:
	return {
		"current_stage": int(_get_owner_value(owner, "current_stage", 1)),
	}


func _get_skill_orb_tooltip_hover_state(owner: Object, registry: Object) -> Dictionary:
	var hover_state: Object = _get_instance(registry, "skill_orb_tooltip_hover_state")
	if hover_state == null or not hover_state.has_method("update_hover_state"):
		return {}
	return hover_state.update_hover_state(owner, registry)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
