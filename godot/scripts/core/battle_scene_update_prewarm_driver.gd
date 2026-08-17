extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const BattleSceneUpdatePrewarmKeySets := preload("res://scripts/core/battle_scene_update_prewarm_key_sets.gd")
const BattleSceneUpdatePrewarmPlan := preload("res://scripts/core/battle_scene_update_prewarm_plan.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

var character_runtime: Object = PlayerCharacterRuntime.new()
var _prewarm_plan: Object = BattleSceneUpdatePrewarmPlan.new()
var battle_update_prewarmed := false
var battle_update_prewarmed_for := ""
var update_prewarm_step_index := 0
var update_prewarm_substep_index := 0
var update_prewarm_detail_label := ""
var battle_ball_update_prewarmed := false
var battle_ball_update_prewarmed_for := ""


class PerfRegistryAdapter:
	extends RefCounted

	var registry: Object = null
	var perf_logger: Object = null
	var label_prefix := ""
	var lookup_index := 0

	func _init(p_registry: Object = null, p_perf_logger: Object = null, p_label_prefix: String = "") -> void:
		registry = p_registry
		perf_logger = p_perf_logger
		label_prefix = p_label_prefix

	func get_instance(key: String) -> Object:
		var sample_index := lookup_index
		lookup_index += 1
		var start_usec := _perf_begin()
		var instance: Object = null
		if registry != null and registry.has_method("get_instance"):
			var value: Variant = registry.get_instance(key)
			if value is Object:
				instance = value
		_perf_end("%s.lookup.%02d_%s" % [label_prefix, sample_index, key], start_usec)
		return instance

	func _perf_begin() -> int:
		if perf_logger != null and perf_logger.has_method("begin_sample"):
			return int(perf_logger.begin_sample())
		return 0

	func _perf_end(label: String, start_usec: int) -> void:
		if perf_logger != null and perf_logger.has_method("finish_sample"):
			perf_logger.finish_sample(label, start_usec)


func prewarm_update(owner: Object, registry: Object) -> void:
	while not prewarm_update_step(owner, registry):
		pass


func prewarm_update_step(owner: Object, registry: Object) -> bool:
	if owner == null or registry == null:
		return true
	var prewarm_key: String = str(_prewarm_plan.build_prewarm_key(owner))
	if battle_update_prewarmed and battle_update_prewarmed_for == prewarm_key:
		return true
	if battle_update_prewarmed_for != prewarm_key:
		battle_update_prewarmed = false
		battle_update_prewarmed_for = prewarm_key
		update_prewarm_step_index = 0
		update_prewarm_substep_index = 0
		update_prewarm_detail_label = ""
	var module_count := BattleSceneUpdatePrewarmKeySets.UPDATE_MODULE_KEYS.size()
	if update_prewarm_step_index < module_count:
		update_prewarm_detail_label = str(BattleSceneUpdatePrewarmKeySets.UPDATE_MODULE_KEYS[update_prewarm_step_index])
		if not _prewarm_instance_script_step(registry, update_prewarm_detail_label):
			return false
		_get_instance(registry, update_prewarm_detail_label)
		update_prewarm_step_index += 1
		update_prewarm_substep_index = 0
		return false

	var step_done := true
	match update_prewarm_step_index - module_count:
		0:
			update_prewarm_detail_label = "player_lookup"
			step_done = _prewarm_player_control_lookup(owner, registry)
		1:
			step_done = _prewarm_player_control_context_step(owner, registry)
		2:
			update_prewarm_detail_label = "boss_ai_context"
			_prewarm_boss_ai_context(owner, registry)
		3:
			step_done = _prewarm_effects_context_step(owner, registry)
		4:
			step_done = _prewarm_match_flow_context_step(owner, registry)
		_:
			battle_update_prewarmed = true
			update_prewarm_step_index = 0
			update_prewarm_substep_index = 0
			update_prewarm_detail_label = ""
			return true
	if not step_done:
		return false
	update_prewarm_step_index += 1
	update_prewarm_substep_index = 0
	return false


func prewarm_ball_update(owner: Object, registry: Object) -> void:
	while not prewarm_ball_update_step(owner, registry):
		pass


func prewarm_ball_update_step(owner: Object, registry: Object) -> bool:
	if owner == null or registry == null:
		return true
	var prewarm_key: String = str(_prewarm_plan.build_prewarm_key(owner))
	if battle_ball_update_prewarmed and battle_ball_update_prewarmed_for == prewarm_key:
		return true
	if not _prewarm_instance_script_step(registry, "battle_scene_ball_update_driver"):
		return false
	var ball_driver: Object = _get_instance(registry, "battle_scene_ball_update_driver")
	if ball_driver != null and ball_driver.has_method("prewarm_update"):
		ball_driver.prewarm_update(owner, registry)
	if ball_driver != null and ball_driver.has_method("prewarm_round_deps"):
		ball_driver.prewarm_round_deps(owner, registry)
	battle_ball_update_prewarmed = true
	battle_ball_update_prewarmed_for = prewarm_key
	return true


func get_update_prewarm_detail_label(owner: Object) -> String:
	var module_count := BattleSceneUpdatePrewarmKeySets.UPDATE_MODULE_KEYS.size()
	if update_prewarm_step_index < module_count:
		return str(BattleSceneUpdatePrewarmKeySets.UPDATE_MODULE_KEYS[update_prewarm_step_index])
	match update_prewarm_step_index - module_count:
		0:
			return "player_lookup"
		1:
			return _get_step_key_label(
				"player_deps",
				_prewarm_plan.get_player_control_context_keys(character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher")))
			)
		2:
			return "boss_ai_context"
		3:
			return _get_step_key_label("effects_deps", _prewarm_plan.get_effects_context_keys(owner))
		4:
			return _get_step_key_label("match_deps", _prewarm_plan.get_match_flow_context_keys(owner))
	return ""


func _prewarm_update_context(owner: Object, registry: Object) -> void:
	_prewarm_player_control_context(owner, registry)
	_prewarm_boss_ai_context(owner, registry)
	_prewarm_effects_context(owner, registry)
	_prewarm_match_flow_context(owner, registry)


func _prewarm_player_control_context(owner: Object, registry: Object) -> void:
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	if context_builder == null:
		return

	var character_type: String = str(_get_owner_value(owner, "selected_character_type", "smasher"))
	if context_builder.has_method("build_player_control_config"):
		context_builder.build_player_control_config(character_type)
	if context_builder.has_method("build_player_control_deps"):
		context_builder.build_player_control_deps(registry, character_type)


func _prewarm_player_control_context_step(owner: Object, registry: Object) -> bool:
	var character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	var keys: Array = _prewarm_plan.get_player_control_context_keys(character_type)
	if update_prewarm_substep_index < keys.size():
		var key := str(keys[update_prewarm_substep_index])
		update_prewarm_detail_label = "player_deps.%02d_%s" % [
			update_prewarm_substep_index,
			key,
		]
		if not _prewarm_instance_script_step(registry, key):
			return false
		var instance: Object = _get_instance(registry, key)
		if not _prewarm_instance_assets_step(key, instance):
			return false
		update_prewarm_substep_index += 1
		return false
	update_prewarm_detail_label = "player_deps.finalize"
	_prewarm_player_control_context(owner, registry)
	return true


func _prewarm_boss_ai_context(owner: Object, registry: Object) -> void:
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	if context_builder == null:
		return
	if context_builder.has_method("build_boss_ai_context"):
		context_builder.build_boss_ai_context(owner, registry)


func _prewarm_effects_context(owner: Object, registry: Object) -> void:
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	if context_builder == null:
		return
	var character_type: String = str(_get_owner_value(owner, "selected_character_type", "smasher"))
	var effects_context: Dictionary = {}
	if context_builder.has_method("build_effects_context"):
		effects_context = context_builder.build_effects_context(owner, registry)
	if context_builder.has_method("build_effects_deps"):
		context_builder.build_effects_deps(
			registry,
			int(effects_context.get("current_stage", _get_owner_value(owner, "current_stage", 1))),
			str(effects_context.get("selected_character_type", character_type)),
			str(effects_context.get("stage1_boss_variant", _get_owner_value(owner, "stage1_boss_variant", "dalji")))
		)


func _prewarm_effects_context_step(owner: Object, registry: Object) -> bool:
	var keys: Array = _prewarm_plan.get_effects_context_keys(owner)
	if update_prewarm_substep_index < keys.size():
		var key := str(keys[update_prewarm_substep_index])
		update_prewarm_detail_label = "effects_deps.%02d_%s" % [
			update_prewarm_substep_index,
			key,
		]
		if not _prewarm_instance_script_step(registry, key):
			return false
		var instance: Object = _get_instance(registry, key)
		if not _prewarm_instance_assets_step(key, instance):
			return false
		update_prewarm_substep_index += 1
		return false
	update_prewarm_detail_label = "effects_deps.finalize"
	_prewarm_effects_context(owner, registry)
	return true


func _prewarm_match_flow_context(owner: Object, registry: Object) -> void:
	var context_builder: Object = _get_instance(registry, "battle_update_context")
	if context_builder == null:
		return
	if context_builder.has_method("build_match_flow_deps"):
		var perf_logger: Object = _get_perf_logger(registry)
		var label_prefix := "process.frame.update_prewarm.match_deps.finalize"
		var total_start: int = _perf_begin(perf_logger)
		_build_match_flow_deps_for_prewarm(
			context_builder,
			registry,
			int(_get_owner_value(owner, "current_stage", 1)),
			false,
			perf_logger,
			label_prefix,
			character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
		)
		_perf_end(perf_logger, "%s.total" % label_prefix, total_start)


func _prewarm_match_flow_context_step(owner: Object, registry: Object) -> bool:
	var keys: Array = _prewarm_plan.get_match_flow_context_keys(owner)
	if update_prewarm_substep_index < keys.size():
		var key := str(keys[update_prewarm_substep_index])
		update_prewarm_detail_label = "match_deps.%02d_%s" % [
			update_prewarm_substep_index,
			key,
		]
		if not _prewarm_instance_script_step(registry, key):
			return false
		var instance: Object = _get_instance(registry, key)
		if not _prewarm_instance_assets_step(key, instance):
			return false
		update_prewarm_substep_index += 1
		return false
	update_prewarm_detail_label = "match_deps.finalize"
	_prewarm_match_flow_context(owner, registry)
	return true


func _prewarm_player_control_lookup(owner: Object, registry: Object) -> bool:
	var character_type: String = character_runtime.normalize(_get_owner_value(owner, "selected_character_type", "smasher"))
	var controller_key: String = character_runtime.get_player_controller_key(character_type)
	if not _prewarm_instance_script_step(registry, controller_key):
		return false
	_get_instance(registry, controller_key)
	return true


func _prewarm_instance_script_step(registry: Object, key: String) -> bool:
	if registry == null:
		return true
	if registry.has_method("request_threaded_script"):
		registry.request_threaded_script(key)
	if registry.has_method("is_threaded_script_ready"):
		return bool(registry.is_threaded_script_ready(key))
	return true


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_perf_logger(registry: Object) -> Object:
	return _get_instance(registry, "battle_perf_logger")


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _prewarm_instance_assets_step(key: String, instance: Object) -> bool:
	if key not in ["smasher_cleanse_state", "cheongringwi_vision_chosik_state"]:
		return true
	if instance == null or not instance.has_method("prewarm_assets_step"):
		return true
	return bool(instance.prewarm_assets_step())


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	return BattleSceneOwnerReader.get_value(owner, key, fallback)


func _get_step_key_label(prefix: String, keys: Array) -> String:
	if update_prewarm_substep_index < keys.size():
		return "%s.%02d_%s" % [
			prefix,
			update_prewarm_substep_index,
			str(keys[update_prewarm_substep_index]),
		]
	return "%s.finalize" % prefix


func _build_match_flow_deps_for_prewarm(
	context_builder: Object,
	registry: Object,
	current_stage: int,
	include_all_stage_deps: bool,
	perf_logger: Object = null,
	perf_label_prefix: String = "",
	character_type: String = ""
) -> void:
	var deps_registry: Object = registry
	if perf_logger != null and not perf_label_prefix.is_empty():
		deps_registry = PerfRegistryAdapter.new(registry, perf_logger, perf_label_prefix)
	if _method_accepts_argument_count(context_builder, "build_match_flow_deps", 6):
		context_builder.build_match_flow_deps(
			deps_registry,
			current_stage,
			perf_logger,
			perf_label_prefix,
			include_all_stage_deps,
			character_type
		)
	elif _method_accepts_argument_count(context_builder, "build_match_flow_deps", 5):
		context_builder.build_match_flow_deps(deps_registry, current_stage, perf_logger, perf_label_prefix, include_all_stage_deps)
	elif _method_accepts_argument_count(context_builder, "build_match_flow_deps", 4):
		context_builder.build_match_flow_deps(deps_registry, current_stage, perf_logger, perf_label_prefix)
	elif _method_accepts_argument_count(context_builder, "build_match_flow_deps", 3):
		context_builder.build_match_flow_deps(deps_registry, current_stage, perf_logger)
	else:
		context_builder.build_match_flow_deps(deps_registry, current_stage)


func _method_accepts_argument_count(target: Object, method_name: String, argument_count: int) -> bool:
	if target == null:
		return false
	for method_value in target.get_method_list():
		var method_info: Dictionary = method_value if method_value is Dictionary else {}
		if str(method_info.get("name", "")) != method_name:
			continue
		var args: Array = method_info.get("args", [])
		return args.size() >= argument_count
	return false
