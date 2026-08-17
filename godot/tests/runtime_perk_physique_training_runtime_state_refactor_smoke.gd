extends SceneTree

const RuntimePerkPhysiqueTrainingRuntimeState := preload("res://scripts/characters/runtime_perk_physique_training_runtime_state.gd")
const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")

var _failures: Array[String] = []


func _init() -> void:
	var original_conversion_flag := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	_verify_owner_boundary()
	_verify_owner_lifetimes_and_runtime_facade()
	PerkConversionFlags.debug_set_enabled(original_conversion_flag)
	if _failures.is_empty():
		print("runtime_perk_physique_training_runtime_state_refactor_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_owner_boundary() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_physique_training_runtime_state.gd")
	_expect(RuntimePerkPhysiqueTrainingRuntimeState != null, "Physique Training runtime-state owner should preload")
	_expect(
		runtime_source.find("const RuntimePerkPhysiqueTrainingRuntimeState := preload(\"res://scripts/characters/runtime_perk_physique_training_runtime_state.gd\")") >= 0
		and runtime_source.find("var _physique_training_runtime_state: Object = RuntimePerkPhysiqueTrainingRuntimeState.new()") >= 0,
		"runtime perk facade should construct one Physique Training feature-state owner"
	)
	for seam: Array in [
		["_physique_training_catalog", "catalog"],
		["_physique_training_state", "state"],
		["_physique_training_offer_planner", "offer_planner"],
	]:
		var property_name := str(seam[0])
		var helper_name := str(seam[1])
		_expect(
			runtime_source.find("var %s: Object:" % property_name) >= 0
			and runtime_source.find("return _physique_training_runtime_state.get_%s()" % helper_name) >= 0
			and runtime_source.find("_physique_training_runtime_state.set_%s(value)" % helper_name) >= 0,
			"%s should remain a writable owner-backed compatibility property" % property_name
		)
	_expect(
		owner_source.find("ActiveItemCooldownComposer.compose_effective_cooldown_msec") >= 0
		and owner_source.find("SmasherDashState.compute_dash_recharge_frames") >= 0
		and owner_source.find("SmasherDashState.compute_dash_recovery_frames") >= 0
		and owner_source.find("CooldownFloorPolicy.floor_final_multiplier") >= 0,
		"Physique Training owner should probe the real final cooldown and dash consumers"
	)
	for facade_contract: Array in [
		["func get_physique_training_bonus(", "_physique_training_runtime_state.get_bonus"],
		["func is_physique_training_saturated(", "_physique_training_runtime_state.is_saturated_from_runtime_state"],
		["func _apply_physique_training_choice(", "_physique_training_runtime_state.apply_choice_from_runtime_state"],
		["func _try_inject_physique_training_offer(", "_physique_training_runtime_state.try_inject_offer_from_runtime_state"],
	]:
		var body := _function_body(runtime_source, str(facade_contract[0]))
		_expect(body.find(str(facade_contract[1])) >= 0, "%s should delegate to the Physique Training owner" % str(facade_contract[0]))
	_expect(
		_function_body(runtime_source, "func _probe_physique_consumer_value(").is_empty(),
		"runtime facade should not retain the final-consumer probe implementation"
	)


func _verify_owner_lifetimes_and_runtime_facade() -> void:
	var owner := RuntimePerkPhysiqueTrainingRuntimeState.new()
	for helper_name: String in ["catalog", "state", "offer_planner"]:
		var getter_name := "get_%s" % helper_name
		var helper: Object = owner.call(getter_name)
		_expect(helper != null, "fresh owner should construct %s" % helper_name)
		_expect(owner.call(getter_name) == helper, "owner should retain one stable %s instance" % helper_name)

	var runtime := RuntimePerkState.new()
	for seam: Array in [
		["_physique_training_catalog", "catalog"],
		["_physique_training_state", "state"],
		["_physique_training_offer_planner", "offer_planner"],
	]:
		var property_name := str(seam[0])
		var helper_name := str(seam[1])
		_expect(
			RuntimePerkRuntimeStateAccess.get_object(runtime, property_name)
			== runtime.get("_physique_training_runtime_state").call("get_%s" % helper_name),
			"%s should resolve through the feature-state owner" % property_name
		)
	var first_card: Dictionary = runtime.get("_physique_training_catalog").build_card("physique_move_speed", 0)
	_expect(runtime._apply_physique_training_choice(first_card, null, null), "runtime facade should apply a Physique Training card")
	_expect(runtime.get_physique_training_count("physique_move_speed") == 1, "runtime facade should expose the owner-backed acquisition count")
	runtime.reset()
	_expect(runtime.get_physique_training_count("physique_move_speed") == 0, "runtime reset should clear the owner-backed training state")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)
