extends RefCounted


func build_deps(registry: Object, current_stage: int = 1, include_all_stages: bool = false) -> Dictionary:
	var deps := {
		"current_stage": current_stage,
		"weather_event_state": _get_instance(registry, "weather_event_state"),
		"stage_background": _get_stage_instance(registry, current_stage, "stage_background", "stage1_pillar_background"),
	}
	if include_all_stages:
		# The all-stages consumers (match reset, stage transition reset, round
		# restart) only RESET modules that already exist; a never-created stage
		# module has no state to leak. get_instance() here cold-instantiated
		# every stage's state on a stage-1 match end (measured 370ms physics
		# stall), so this branch must peek the cache and never instantiate.
		_append_stage1_deps(deps, registry, true)
		_append_stage2_deps(deps, registry, true)
		_append_stage3_deps(deps, registry, true)
		_append_stage4_deps(deps, registry, true)
		_append_stage5_deps(deps, registry, true)
		_append_stage6_deps(deps, registry, true)
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


func _append_stage1_deps(deps: Dictionary, registry: Object, peek_only: bool = false) -> void:
	deps["stage1_dalji_whip_skill_state"] = _lookup_instance(registry, "stage1_dalji_whip_skill_state", peek_only)
	deps["stage1_dalji_spinning_top_skill_state"] = _lookup_instance(registry, "stage1_dalji_spinning_top_skill_state", peek_only)
	deps["stage1_dalji_boss_skill_cooldown_state"] = _lookup_instance(registry, "stage1_dalji_boss_skill_cooldown_state", peek_only)
	deps["stage1_balloon_event"] = _lookup_instance(registry, "stage1_balloon_event", peek_only)


func _append_stage2_deps(deps: Dictionary, registry: Object, peek_only: bool = false) -> void:
	deps["stage2_boss_skill_state"] = _lookup_instance(registry, "stage2_boss_skill_state", peek_only)
	deps["stage2_monkey_banana_event"] = _lookup_instance(registry, "stage2_monkey_banana_event", peek_only)


func _append_stage3_deps(deps: Dictionary, registry: Object, peek_only: bool = false) -> void:
	deps["stage3_boss_skill_state"] = _lookup_instance(registry, "stage3_boss_skill_state", peek_only)


func _append_stage4_deps(deps: Dictionary, registry: Object, peek_only: bool = false) -> void:
	deps["stage4_map_state"] = _lookup_instance(registry, "stage4_map_state", peek_only)
	deps["stage4_temple_destruction_event"] = _lookup_instance(registry, "stage4_temple_destruction_event", peek_only)
	deps["stage4_moon_event"] = _lookup_instance(registry, "stage4_moon_event", peek_only)
	deps["stage4_bird_event"] = _lookup_instance(registry, "stage4_bird_event", peek_only)
	deps["stage4_brazier_monk_event"] = _lookup_instance(registry, "stage4_brazier_monk_event", peek_only)
	deps["stage4_ponk_skill_state"] = _lookup_instance(registry, "stage4_ponk_skill_state", peek_only)


func _append_stage5_deps(deps: Dictionary, registry: Object, peek_only: bool = false) -> void:
	deps["stage5_hongryun_state"] = _lookup_instance(registry, "stage5_hongryun_state", peek_only)
	deps["stage5_hongryun_fire_machine_event"] = _lookup_instance(registry, "stage5_hongryun_fire_machine_event", peek_only)


func _append_stage6_deps(deps: Dictionary, registry: Object, peek_only: bool = false) -> void:
	deps["stage6_tetriser_state"] = _lookup_instance(registry, "stage6_tetriser_state", peek_only)


# peek_only callers must never instantiate: registries expose
# get_cached_instance() as the non-creating lookup. Registries without the
# peek API (older fakes) keep the creating path so deps stay populated.
func _lookup_instance(registry: Object, key: String, peek_only: bool) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	if peek_only and registry.has_method("get_cached_instance"):
		return registry.get_cached_instance(key)
	return registry.get_instance(key)


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
