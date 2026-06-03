extends RefCounted


func build_deps(registry: Object, current_stage: int = 1, include_all_stages: bool = false) -> Dictionary:
	var deps := {
		"current_stage": current_stage,
		"weather_event_state": _get_instance(registry, "weather_event_state"),
		"stage_background": _get_stage_instance(registry, current_stage, "stage_background", "stage1_pillar_background"),
	}
	if include_all_stages:
		_append_stage1_deps(deps, registry)
		_append_stage2_deps(deps, registry)
		_append_stage3_deps(deps, registry)
		_append_stage4_deps(deps, registry)
		_append_stage5_deps(deps, registry)
		_append_stage6_deps(deps, registry)
	else:
		_append_current_stage_deps(deps, registry, current_stage)
	return deps


func _append_current_stage_deps(deps: Dictionary, registry: Object, current_stage: int) -> void:
	match current_stage:
		1:
			_append_stage1_deps(deps, registry)
		2:
			_append_stage2_deps(deps, registry)
		3:
			_append_stage3_deps(deps, registry)
		4:
			_append_stage4_deps(deps, registry)
		5:
			_append_stage5_deps(deps, registry)
		6:
			_append_stage6_deps(deps, registry)


func _append_stage1_deps(deps: Dictionary, registry: Object) -> void:
	deps["stage1_dalji_whip_skill_state"] = _get_instance(registry, "stage1_dalji_whip_skill_state")
	deps["stage1_dalji_spinning_top_skill_state"] = _get_instance(registry, "stage1_dalji_spinning_top_skill_state")
	deps["stage1_dalji_boss_skill_cooldown_state"] = _get_instance(registry, "stage1_dalji_boss_skill_cooldown_state")
	deps["stage1_balloon_event"] = _get_instance(registry, "stage1_balloon_event")


func _append_stage2_deps(deps: Dictionary, registry: Object) -> void:
	deps["stage2_boss_skill_state"] = _get_instance(registry, "stage2_boss_skill_state")
	deps["stage2_monkey_banana_event"] = _get_instance(registry, "stage2_monkey_banana_event")


func _append_stage3_deps(deps: Dictionary, registry: Object) -> void:
	deps["stage3_boss_skill_state"] = _get_instance(registry, "stage3_boss_skill_state")


func _append_stage4_deps(deps: Dictionary, registry: Object) -> void:
	deps["stage4_map_state"] = _get_instance(registry, "stage4_map_state")
	deps["stage4_temple_destruction_event"] = _get_instance(registry, "stage4_temple_destruction_event")
	deps["stage4_moon_event"] = _get_instance(registry, "stage4_moon_event")
	deps["stage4_bird_event"] = _get_instance(registry, "stage4_bird_event")
	deps["stage4_brazier_monk_event"] = _get_instance(registry, "stage4_brazier_monk_event")
	deps["stage4_ponk_skill_state"] = _get_instance(registry, "stage4_ponk_skill_state")


func _append_stage5_deps(deps: Dictionary, registry: Object) -> void:
	deps["stage5_hongryun_state"] = _get_instance(registry, "stage5_hongryun_state")
	deps["stage5_hongryun_fire_machine_event"] = _get_instance(registry, "stage5_hongryun_fire_machine_event")


func _append_stage6_deps(deps: Dictionary, registry: Object) -> void:
	deps["stage6_tetriser_state"] = _get_instance(registry, "stage6_tetriser_state")


func _get_stage_instance(registry: Object, current_stage: int, role: String, fallback_key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var router: Object = registry.get_instance("stage_runtime_router")
	if router != null and router.has_method("get_instance"):
		var routed: Object = router.get_instance(registry, current_stage, role)
		if routed != null:
			return routed
	return registry.get_instance(fallback_key)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)
