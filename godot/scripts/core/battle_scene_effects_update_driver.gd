extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneEffectsUpdateResultApplier := preload("res://scripts/core/battle_scene_effects_update_result_applier.gd")

var _fallback_result_applier: Object = BattleSceneEffectsUpdateResultApplier.new()


func update_effects(owner: Object, registry: Object, delta: float) -> void:
	var controller: Object = _get_instance(registry, "battle_effects_update_controller")
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	if owner == null or controller == null or context_builder == null:
		return

	var perf_logger: Object = _get_instance(registry, "battle_perf_logger")
	var total_start: int = _perf_begin(perf_logger)
	var sample_start: int = _perf_begin(perf_logger)
	var effects_context: Dictionary = context_builder.build_effects_context(owner, registry)
	_perf_end(perf_logger, "physics.effects.build_context", sample_start)
	sample_start = _perf_begin(perf_logger)
	var effects_deps: Dictionary = context_builder.build_effects_deps(
		registry,
		int(effects_context.get("current_stage", _get_owner_value(owner, "current_stage", 1))),
		str(effects_context.get("selected_character_type", _get_owner_value(owner, "selected_character_type", "smasher"))),
		str(effects_context.get("stage1_boss_variant", _get_owner_value(owner, "stage1_boss_variant", "dalji")))
	)
	effects_deps["perf_logger"] = perf_logger
	_perf_end(perf_logger, "physics.effects.build_deps", sample_start)
	sample_start = _perf_begin(perf_logger)
	var result: Dictionary = controller.update(
		delta,
		effects_context,
		effects_deps
	)
	_perf_end(perf_logger, "physics.effects.controller", sample_start)
	sample_start = _perf_begin(perf_logger)
	_get_result_applier(registry).apply_effects_result(owner, result)
	_perf_end(perf_logger, "physics.effects.apply", sample_start)
	_perf_end(perf_logger, "physics.effects.total", total_start)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_result_applier(registry: Object) -> Object:
	var applier: Object = _get_instance(registry, "battle_scene_effects_update_result_applier")
	if applier != null and applier.has_method("apply_effects_result"):
		return applier
	return _fallback_result_applier


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
