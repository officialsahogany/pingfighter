extends SceneTree

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkUnlockPipelineState := preload("res://scripts/characters/runtime_perk_unlock_pipeline_state.gd")

const HELPER_NAMES := [
	"active_unlock_flight",
	"unlock_showcase_controller",
	"unlock_showcase_flow",
	"unlock_swap_layout",
	"unlock_swap_flow",
	"unlock_choice_apply",
]

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_helper_lifetimes_and_injection_seams()
	if _failures.is_empty():
		print("runtime_perk_unlock_pipeline_state_refactor_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_owner_boundary() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_pipeline_state.gd")
	_expect(RuntimePerkUnlockPipelineState != null, "unlock-pipeline state owner should preload")
	_expect(
		runtime_source.find("const RuntimePerkUnlockPipelineState := preload(\"res://scripts/characters/runtime_perk_unlock_pipeline_state.gd\")") >= 0
		and runtime_source.find("var _unlock_pipeline_state: Object = RuntimePerkUnlockPipelineState.new()") >= 0,
		"runtime perk facade should construct one unlock-pipeline state owner"
	)
	for helper_name: String in HELPER_NAMES:
		var property_name := "_%s" % helper_name
		_expect(
			runtime_source.find("var %s: Object:" % property_name) >= 0
			and runtime_source.find("return _unlock_pipeline_state.get_%s()" % helper_name) >= 0
			and runtime_source.find("_unlock_pipeline_state.set_%s(value)" % helper_name) >= 0,
			"%s should remain a writable owner-backed compatibility property" % property_name
		)
		_expect(
			owner_source.find("func get_%s() -> Object:" % helper_name) >= 0
			and owner_source.find("func set_%s(value: Object) -> void:" % helper_name) >= 0,
			"unlock-pipeline owner should expose the %s lifetime and injection seam" % helper_name
		)
	for removed_constructor: String in [
		"RuntimePerkActiveUnlockFlight.new()",
		"RuntimePerkUnlockShowcase.new()",
		"RuntimePerkUnlockShowcaseFlow.new()",
		"RuntimePerkUnlockSwapLayout.new()",
		"RuntimePerkUnlockSwapFlow.new()",
		"RuntimePerkUnlockChoiceApply.new()",
	]:
		_expect(runtime_source.find(removed_constructor) < 0, "runtime facade should not construct unlock helper %s" % removed_constructor)
	_expect(
		runtime_source.find("_active_unlock_flight.is_active_from_runtime_state") >= 0
		and runtime_source.find("_unlock_showcase_flow.finish_or_open_unlock_showcase_from_runtime_state") >= 0
		and runtime_source.find("_unlock_swap_flow.confirm_pending_swap_from_runtime_state") >= 0
		and runtime_source.find("_unlock_choice_apply.apply_choice_from_runtime_state") >= 0,
		"runtime facade should preserve the established unlock call surface"
	)


func _verify_helper_lifetimes_and_injection_seams() -> void:
	var owner := RuntimePerkUnlockPipelineState.new()
	for helper_name: String in HELPER_NAMES:
		var getter_name := "get_%s" % helper_name
		var helper: Object = owner.call(getter_name)
		_expect(helper != null, "fresh owner should construct %s" % helper_name)
		_expect(owner.call(getter_name) == helper, "owner should retain one stable %s instance" % helper_name)

	var runtime := RuntimePerkState.new()
	for helper_name: String in HELPER_NAMES:
		var property_name := "_%s" % helper_name
		var injected := HelperProbe.new(helper_name)
		runtime.set(property_name, injected)
		_expect(
			RuntimePerkRuntimeStateAccess.get_object(runtime, property_name) == injected,
			"runtime-state string lookup should resolve injected %s through the owner" % property_name
		)
		_expect(
			runtime.get("_unlock_pipeline_state").call("get_%s" % helper_name) == injected,
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
