extends SceneTree

const RuntimePerkCharacterContext := preload("res://scripts/characters/runtime_perk_character_context.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_character_aliases_and_keys()
	_verify_owner_character_type_compatibility()
	_verify_stage_and_dash_token_fallbacks()
	_verify_state_keeps_only_callback_context_wrappers()

	if _failures.is_empty():
		print("runtime_perk_character_context_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_character_aliases_and_keys() -> void:
	var context := RuntimePerkCharacterContext.new()
	_expect(context.normalize_character_type(" Commando ") == "soldier", "Commando alias should normalize to soldier")
	_expect(context.normalize_character_type("io") == "optimus", "io alias should normalize to optimus")
	_expect(context.normalize_character_type("unknown") == "smasher", "unknown character should fall back to smasher")
	_expect(context.get_skill_config_key("soldier") == "commando_skill_config", "soldier should route to Commando skill config")
	_expect(context.get_skill_state_key("viper") == "viper_skill_state", "viper should route to Viper skill state")
	_expect(context.get_skill_config_key("optimus") == "", "optimus should preserve the no-config runtime-perk route")


func _verify_owner_character_type_compatibility() -> void:
	var context := RuntimePerkCharacterContext.new()
	_expect(context.get_owner_character_type(null) == "smasher", "null owner should fall back to smasher")
	_expect(context.get_owner_character_type(FakeOwner.new({"selected_character_type": "commando"})) == "soldier", "owner Commando alias should read as soldier")
	_expect(context.get_owner_character_type(FakeOwner.new({"selected_character_type": "viper"})) == "viper", "owner Viper should read as viper")
	_expect(context.get_owner_character_type(FakeOwner.new({"selected_character_type": "optimus"})) == "smasher", "owner Optimus fallback should preserve existing state behavior")


func _verify_stage_and_dash_token_fallbacks() -> void:
	var context := RuntimePerkCharacterContext.new()
	_expect(context.get_current_stage(null) == 0, "null owner stage should be zero")
	_expect(context.get_current_stage(FakeOwner.new({"current_stage": -3})) == 0, "negative owner stage should clamp to zero")
	_expect(context.get_current_stage(FakeOwner.new({"current_stage": 5})) == 5, "owner stage should be read when present")
	_expect(context.get_starting_dash_tokens(null) == 1, "null owner should get one starting dash token")
	_expect(context.get_starting_dash_tokens(FakeOwner.new({"starting_dash_tokens": -2})) == 1, "owner dash token override should clamp to at least one")
	_expect(context.get_starting_dash_tokens(FakeOwner.new({"starting_dash_tokens": 3})) == 3, "owner dash token override should be honored")


func _verify_state_keeps_only_callback_context_wrappers() -> void:
	var state_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	_expect(state_source.find("func _get_skill_config_key") >= 0, "state should keep the skill-config callback wrapper used by unlock swap flow")
	_expect(state_source.find("func _get_character_type") >= 0, "state should keep the character-type callback wrapper used by finish flow")
	_expect(state_source.find("func _get_skill_state_key") < 0, "state should not keep unused skill-state key compatibility wrapper")
	_expect(state_source.find("func _normalize_character_type") < 0, "state should not keep unused character-normalization wrapper")
	_expect(state_source.find("func _get_current_stage") < 0, "state should not keep unused stage wrapper")
	_expect(state_source.find("func _get_starting_dash_tokens") < 0, "state should not keep unused dash-token wrapper")
	_expect(state_source.find("func _perf_begin") < 0, "state should not keep unused perf wrappers")
	_expect(state_source.find("func _get_array(value: Variant)") < 0, "state should not keep unused array fallback wrapper")
	_expect(state_source.find("func _get_dict(value: Variant)") < 0, "state should not keep unused dictionary fallback wrapper")
	_expect(state_source.find("func _get_color(value: Variant)") < 0, "state should not keep unused color fallback wrapper")
	_expect(state_source.find("func _get_vector2(value: Variant)") < 0, "state should not keep unused vector fallback wrapper")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class FakeOwner:
	var data: Dictionary = {}

	func _init(source: Dictionary) -> void:
		data = source

	func _get(property: StringName) -> Variant:
		return data.get(str(property), null)
