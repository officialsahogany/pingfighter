extends SceneTree

const RuntimePerkChoicePipelineState := preload("res://scripts/characters/runtime_perk_choice_pipeline_state.gd")
const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const HELPER_NAMES := [
	"selection",
	"completion",
	"dispatch",
	"action_runner",
	"standard_path",
	"open_flow",
	"apply_flow",
	"confirm_flow",
	"finish_flow",
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_helper_lifetimes_and_injection_seams()
	if _failures.is_empty():
		print("runtime_perk_choice_pipeline_state_refactor_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_owner_boundary() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_choice_pipeline_state.gd")
	_expect(RuntimePerkChoicePipelineState != null, "choice-pipeline runtime-state owner should preload")
	_expect(
		runtime_source.find("const RuntimePerkChoicePipelineState := preload(\"res://scripts/characters/runtime_perk_choice_pipeline_state.gd\")") >= 0
		and runtime_source.find("var _choice_pipeline_state: Object = RuntimePerkChoicePipelineState.new()") >= 0,
		"runtime perk facade should construct one choice-pipeline state owner"
	)
	for helper_name: String in HELPER_NAMES:
		var property_name := "_choice_%s" % helper_name
		_expect(
			runtime_source.find("var %s: Object:" % property_name) >= 0
			and runtime_source.find("return _choice_pipeline_state.get_%s()" % helper_name) >= 0
			and runtime_source.find("_choice_pipeline_state.set_%s(value)" % helper_name) >= 0,
			"%s should remain a writable owner-backed compatibility property" % property_name
		)
		_expect(
			owner_source.find("func get_%s() -> Object:" % helper_name) >= 0
			and owner_source.find("func set_%s(value: Object) -> void:" % helper_name) >= 0,
			"choice-pipeline owner should expose the %s lifetime and injection seam" % helper_name
		)
	for removed_constructor: String in [
		"RuntimePerkChoiceSelection.new()",
		"RuntimePerkChoiceCompletion.new()",
		"RuntimePerkChoiceDispatch.new()",
		"RuntimePerkChoiceActionRunner.new()",
		"RuntimePerkChoiceStandardPath.new()",
		"RuntimePerkChoiceOpenFlow.new()",
		"RuntimePerkChoiceApplyFlow.new()",
		"RuntimePerkChoiceConfirmFlow.new()",
		"RuntimePerkChoiceFinishFlow.new()",
	]:
		_expect(runtime_source.find(removed_constructor) < 0, "runtime facade should not construct pipeline helper %s" % removed_constructor)
	_expect(
		runtime_source.find("_choice_open_flow.open_next_choice_from_runtime_state") >= 0
		and runtime_source.find("_choice_apply_flow.apply_choice_from_runtime_state") >= 0
		and runtime_source.find("_choice_confirm_flow.choose_selected_from_runtime_state") >= 0
		and runtime_source.find("_choice_finish_flow.finish_successful_choice_from_runtime_state") >= 0,
		"runtime facade should preserve the established choice-flow call surface"
	)


func _verify_helper_lifetimes_and_injection_seams() -> void:
	var owner := RuntimePerkChoicePipelineState.new()
	for helper_name: String in HELPER_NAMES:
		var getter_name := "get_%s" % helper_name
		var helper: Object = owner.call(getter_name)
		_expect(helper != null, "fresh owner should construct %s" % helper_name)
		_expect(owner.call(getter_name) == helper, "owner should retain one stable %s instance" % helper_name)

	var runtime := RuntimePerkState.new()
	for helper_name: String in HELPER_NAMES:
		var property_name := "_choice_%s" % helper_name
		var injected := HelperProbe.new(helper_name)
		runtime.set(property_name, injected)
		_expect(
			RuntimePerkRuntimeStateAccess.get_object(runtime, property_name) == injected,
			"runtime-state string lookup should resolve injected %s through the owner" % property_name
		)
		_expect(
			runtime.get("_choice_pipeline_state").call("get_%s" % helper_name) == injected,
			"%s setter should replace the owner-held helper without duplicate storage" % property_name
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class HelperProbe:
	extends RefCounted

	var helper_name := ""


	func _init(p_helper_name: String) -> void:
		helper_name = p_helper_name
