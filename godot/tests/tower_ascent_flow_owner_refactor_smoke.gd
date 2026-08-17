extends SceneTree

const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentRunState := preload(
	"res://scripts/tower_ascent/tower_ascent_run_state.gd"
)

const FLOW_DIR := "res://scripts/tower_ascent/"
const OWNER_PATH := FLOW_DIR + "tower_ascent_flow_owner.gd"
const RUNTIME_PATH := FLOW_DIR + "tower_ascent_flow_runtime.gd"
const STATE_PATH := FLOW_DIR + "tower_ascent_flow_state.gd"
const CHAIN := [
	["tower_ascent_flow_owner.gd", "tower_ascent_flow_runtime.gd"],
	["tower_ascent_flow_runtime.gd", "tower_ascent_flow_snapshot_progress.gd"],
	["tower_ascent_flow_snapshot_progress.gd", "tower_ascent_flow_ending_progress.gd"],
	["tower_ascent_flow_ending_progress.gd", "tower_ascent_flow_node_progress.gd"],
	["tower_ascent_flow_node_progress.gd", "tower_ascent_flow_economy_progress.gd"],
	["tower_ascent_flow_economy_progress.gd", "tower_ascent_flow_map_progress.gd"],
	["tower_ascent_flow_map_progress.gd", "tower_ascent_flow_state.gd"],
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_facade_contract()
	_verify_owner_chain()
	_verify_eager_runtime_contract()
	if _failures.is_empty():
		print("tower_ascent_flow_owner_refactor_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_facade_contract() -> void:
	var flow := TowerAscentFlowOwner.new()
	for method_name in [
		"begin_vertical_slice",
		"restore_snapshot",
		"export_snapshot",
		"collect_muhon",
		"resolve_defeat",
		"begin_floor_nine_resolution",
		"resolve_gauntlet_victory",
		"begin_floor_twelve_true_ending",
		"begin_run_settlement",
		"handle_input",
		"update_selective",
		"draw",
	]:
		_expect(flow.has_method(method_name), "public facade must retain %s" % method_name)
	_expect(
		TowerAscentFlowOwner.SNAPSHOT_SCHEMA_VERSION == TowerAscentRunState.SNAPSHOT_SCHEMA_VERSION,
		"refactor must not change the run snapshot schema"
	)
	_expect(_line_count(FileAccess.get_file_as_string(OWNER_PATH)) <= 500, "public flow owner must stay facade-sized")
	_expect(_line_count(FileAccess.get_file_as_string(RUNTIME_PATH)) <= 500, "flow runtime coordinator must stay facade-sized")


func _verify_owner_chain() -> void:
	for link in CHAIN:
		var source := FileAccess.get_file_as_string(FLOW_DIR + str(link[0]))
		var expected := "extends \"%s%s\"" % [FLOW_DIR, str(link[1])]
		_expect(source.begins_with(expected), "%s must extend %s" % [link[0], link[1]])


func _verify_eager_runtime_contract() -> void:
	var state_source := FileAccess.get_file_as_string(STATE_PATH)
	var runtime_source := FileAccess.get_file_as_string(RUNTIME_PATH)
	_expect(state_source.count(".new()") == 19, "all shared flow dependencies, including the route serve runtime, must remain eager state fields")
	for function_name in ["update_selective", "draw"]:
		var body := _function_body(runtime_source, function_name)
		_expect(not body.is_empty(), "%s must remain on the runtime coordinator" % function_name)
		_expect(body.find(".new()") < 0, "%s must not lazy-create dependencies" % function_name)


func _function_body(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var finish := source.find("\nfunc ", start + 1)
	return source.substr(start) if finish < 0 else source.substr(start, finish - start)


func _line_count(source: String) -> int:
	return 0 if source.is_empty() else source.count("\n") + 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
