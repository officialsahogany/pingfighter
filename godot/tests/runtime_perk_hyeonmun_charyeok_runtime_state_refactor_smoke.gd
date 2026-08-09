extends SceneTree

const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkHyeonmunCharyeokRuntimeState := preload("res://scripts/characters/runtime_perk_hyeonmun_charyeok_runtime_state.gd")
const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


class DynamicEffectsProbe:
	extends RefCounted

	var refresh_calls := 0


	func set_item_perk_level_bonus_from_runtime_state(runtime_state: Object, bonus: int) -> Dictionary:
		var previous := int(runtime_state.get("item_perk_level_bonus"))
		runtime_state.set("item_perk_level_bonus", maxi(0, bonus))
		return {"accepted": previous != maxi(0, bonus)}


	func get_item_perk_level_bonus_from_runtime_state(runtime_state: Object) -> int:
		return int(runtime_state.get("item_perk_level_bonus"))


	func refresh_item_perk_level_bonus_dynamic_effects_from_runtime_state(
		_runtime_state: Object,
		_registry: Object,
		_owner: Object = null
	) -> Dictionary:
		refresh_calls += 1
		return {"accepted": true}


func _init() -> void:
	var original_conversion_flag := PerkConversionFlags.is_enabled()
	PerkConversionFlags.debug_set_enabled(true)
	_verify_owner_boundary()
	_verify_owner_lifetimes_and_runtime_facade()
	PerkConversionFlags.debug_set_enabled(original_conversion_flag)
	if _failures.is_empty():
		print("runtime_perk_hyeonmun_charyeok_runtime_state_refactor_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_owner_boundary() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_hyeonmun_charyeok_runtime_state.gd")
	_expect(RuntimePerkHyeonmunCharyeokRuntimeState != null, "Hyeonmun runtime-state owner should preload")
	_expect(
		runtime_source.find("const RuntimePerkHyeonmunCharyeokRuntimeState := preload(\"res://scripts/characters/runtime_perk_hyeonmun_charyeok_runtime_state.gd\")") >= 0
		and runtime_source.find("var _hyeonmun_charyeok_runtime_state: Object = RuntimePerkHyeonmunCharyeokRuntimeState.new()") >= 0,
		"runtime perk facade should construct one Hyeonmun feature-state owner"
	)
	for seam: Array in [
		["_hyeonmun_charyeok_state", "state"],
		["_hyeonmun_charyeok_renderer", "renderer"],
	]:
		var property_name := str(seam[0])
		var helper_name := str(seam[1])
		_expect(
			runtime_source.find("var %s: Object:" % property_name) >= 0
			and runtime_source.find("return _hyeonmun_charyeok_runtime_state.get_%s()" % helper_name) >= 0
			and runtime_source.find("_hyeonmun_charyeok_runtime_state.set_%s(value)" % helper_name) >= 0,
			"%s should remain a writable owner-backed compatibility property" % property_name
		)
	_expect(
		owner_source.find("get_transcendent_crown_skill_bonus") >= 0
		and owner_source.find("set_item_perk_level_bonus") >= 0
		and owner_source.find("refresh_item_perk_level_bonus_dynamic_effects") >= 0,
		"Hyeonmun owner should own Crown composition and both cached-consumer refresh directions"
	)
	for facade_contract: Array in [
		["func try_proc_hyeonmun_charyeok(", "_hyeonmun_charyeok_runtime_state.try_proc_from_runtime_state"],
		["func update_hyeonmun_charyeok(", "_hyeonmun_charyeok_runtime_state.update_from_runtime_state"],
		["func reset_hyeonmun_charyeok_round(", "_hyeonmun_charyeok_runtime_state.reset_round_from_runtime_state"],
		["func draw_hyeonmun_charyeok_timer(", "_hyeonmun_charyeok_runtime_state.draw_timer"],
	]:
		var body := _function_body(runtime_source, str(facade_contract[0]))
		_expect(body.find(str(facade_contract[1])) >= 0, "%s should delegate to the Hyeonmun owner" % str(facade_contract[0]))
	_expect(
		_function_body(runtime_source, "func _sync_hyeonmun_charyeok_effective_level_bonus(").is_empty(),
		"runtime facade should not retain Hyeonmun effective-level composition"
	)


func _verify_owner_lifetimes_and_runtime_facade() -> void:
	var owner := RuntimePerkHyeonmunCharyeokRuntimeState.new()
	for helper_name: String in ["state", "renderer"]:
		var getter_name := "get_%s" % helper_name
		var helper: Object = owner.call(getter_name)
		_expect(helper != null, "fresh owner should construct %s" % helper_name)
		_expect(owner.call(getter_name) == helper, "owner should retain one stable %s instance" % helper_name)

	var runtime := RuntimePerkState.new()
	for seam: Array in [
		["_hyeonmun_charyeok_state", "state"],
		["_hyeonmun_charyeok_renderer", "renderer"],
	]:
		var property_name := str(seam[0])
		var helper_name := str(seam[1])
		_expect(
			RuntimePerkRuntimeStateAccess.get_object(runtime, property_name)
			== runtime.get("_hyeonmun_charyeok_runtime_state").call("get_%s" % helper_name),
			"%s should resolve through the feature-state owner" % property_name
		)
	var dynamic_effects := DynamicEffectsProbe.new()
	runtime.set("_dynamic_effects", dynamic_effects)
	runtime.runtime_skill_levels["sage_ring"] = 3
	var activation: Dictionary = runtime.try_proc_hyeonmun_charyeok({"hyeonmun_charyeok_roll_unit": 0.0})
	_expect(bool(activation.get("activated", false)), "runtime facade should activate Hyeonmun through the owner")
	_expect(runtime.get_item_perk_level_bonus() == 2, "Lv.3 activation should publish temporary +2 through the canonical level source")
	_expect(dynamic_effects.refresh_calls == 1, "activation should refresh owner-cached effective-level consumers exactly once")
	_expect(runtime.update_hyeonmun_charyeok(8.0), "active owner should request redraw on its expiry tick")
	_expect(not runtime.is_hyeonmun_charyeok_active(), "owner-backed Hyeonmun should expire at the authored Lv.3 duration")
	_expect(runtime.get_item_perk_level_bonus() == 0, "expiry should remove the temporary level source")
	_expect(dynamic_effects.refresh_calls == 2, "expiry should refresh owner-cached effective-level consumers exactly once more")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)
