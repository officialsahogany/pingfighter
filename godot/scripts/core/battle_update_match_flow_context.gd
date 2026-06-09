extends RefCounted

const BattleUpdateMatchFlowDepsGroups := preload("res://scripts/core/battle_update_match_flow_deps_groups.gd")

var deps_groups: Object = BattleUpdateMatchFlowDepsGroups.new()


func build_deps(
	registry: Object,
	current_stage: int = 1,
	perf_logger: Object = null,
	perf_label_prefix: String = "",
	include_all_stage_deps: bool = true,
	character_type: String = ""
) -> Dictionary:
	var deps := {}
	var sample_start: int = _perf_begin(perf_logger)
	deps.merge(deps_groups.build_match_state_deps(registry), true)
	_perf_end(perf_logger, _perf_label(perf_label_prefix, "match_state"), sample_start)
	sample_start = _perf_begin(perf_logger)
	deps.merge(deps_groups.build_item_runtime_deps(registry), true)
	_perf_end(perf_logger, _perf_label(perf_label_prefix, "item_runtime"), sample_start)
	sample_start = _perf_begin(perf_logger)
	deps.merge(deps_groups.build_player_skill_runtime_deps(registry, character_type), true)
	_perf_end(perf_logger, _perf_label(perf_label_prefix, "player_skill"), sample_start)
	sample_start = _perf_begin(perf_logger)
	deps.merge(deps_groups.build_stage_runtime_deps(registry, current_stage, include_all_stage_deps), true)
	_perf_end(perf_logger, _perf_label(perf_label_prefix, "stage_runtime"), sample_start)
	return deps


func _perf_label(prefix: String, suffix: String) -> String:
	if prefix == "":
		return "physics.match_flow.deps.%s" % suffix
	return "%s.%s" % [prefix, suffix]


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)
