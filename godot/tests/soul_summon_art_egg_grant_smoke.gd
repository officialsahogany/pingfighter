extends SceneTree

const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkSoulSummonArt := preload("res://scripts/characters/runtime_perk_soul_summon_art.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")

var _failures: Array[String] = []


class DynamicOwner:
	extends Node2D

	var scene_state := BattleSceneState.new()
	var extra: Dictionary = {}

	func _init() -> void:
		scene_state.reset()
		extra["ai_mode"] = "champion"
		extra["selected_character_type"] = "smasher"
		scene_state.set_value("player_pos", Vector2(380.0, 675.0))
		scene_state.set_value("boss_pos", Vector2(380.0, 35.0))

	func _get(property: StringName) -> Variant:
		var key := str(property)
		return scene_state.get_value(key) if scene_state.has_key(key) else extra.get(key, null)

	func _set(property: StringName, value: Variant) -> bool:
		var key := str(property)
		if scene_state.has_key(key):
			scene_state.set_value(key, value)
		else:
			extra[key] = value
		return true


class FakeRuntimePerkState:
	extends RefCounted
	var runtime_skill_levels := {
		CommonSkillCatalog.SOUL_SUMMON_ART_ID: 1,
		CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID: 1,
	}

	func get_runtime_skill_level(skill_id: String) -> int:
		return int(runtime_skill_levels.get(skill_id, 0))


class FakeNoCandidateCollection:
	extends RefCounted

	func sync_from_owner(_owner: Object) -> void:
		pass

	func is_full(_owner: Object) -> bool:
		return false

	func is_auto_present_league(_owner: Object) -> bool:
		return false

	func has_unowned_pet_candidates(_owner: Object) -> bool:
		return false

	func pick_random_unowned_pet_id(_owner: Object) -> String:
		return ""

	func pick_random_any_pet_id() -> String:
		return ""


class FakeRegistry:
	extends RefCounted
	var instances: Dictionary = {}

	func _init(runtime: Object) -> void:
		instances = {
			"lingpet_egg_runtime": runtime,
			"runtime_perk_state": FakeRuntimePerkState.new(),
		}

	func get_instance(key: String) -> Object:
		return instances.get(key, null) as Object

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


func _init() -> void:
	_verify_offer_uses_normal_random_pool()
	_verify_immediate_drop_and_three_skip_branches()
	_verify_swap_cancel_cannot_reach_drop_helper()
	if _failures.is_empty():
		print("soul_summon_art_egg_grant_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_offer_uses_normal_random_pool() -> void:
	var catalog := RuntimePerkCatalog.new()
	var offers: Array = []
	catalog._append_soul_summon_choice(offers, {})
	_expect(offers.size() == 1, "unowned Soul Summoning Art must enter the ordinary candidate pool")
	if offers.size() == 1:
		var raw_offer: Dictionary = offers[0] as Dictionary
		_expect(str(raw_offer.get("id", "")) == CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID, "ordinary candidate must keep the canonical unlock id")
		_expect(not raw_offer.has("_soul_summon_reserved"), "ordinary candidate must not carry the retired reservation marker")

	offers.clear()
	catalog._append_soul_summon_choice(offers, {CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID: 1})
	_expect(offers.is_empty(), "owned unlock perk must exclude Soul Summoning Art immediately")
	offers.clear()
	catalog._append_soul_summon_choice(offers, {CommonSkillCatalog.SOUL_SUMMON_ART_ID: 1})
	_expect(offers.is_empty(), "owned active skill must exclude Soul Summoning Art immediately")

	# The production chooser must be able to include and omit the art under one
	# deterministic random sequence. This seals ordinary shuffle competition,
	# not just raw candidate construction.
	seed(0x51A71)
	var present_count := 0
	var absent_count := 0
	for _screen in range(128):
		var screen_choices: Array = catalog.get_choices("smasher", {}, true, 3, null, null)
		var found := false
		for choice_value in screen_choices:
			if not choice_value is Dictionary:
				continue
			var choice: Dictionary = choice_value as Dictionary
			if str(choice.get("id", "")) != CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID:
				continue
			found = true
			_expect(str(choice.get("offer_lane", "")) == "replaceable", "Soul Summoning Art must use the ordinary replaceable lane")
			_expect(not bool(choice.get("offer_protected", true)), "Soul Summoning Art must not be protected from shuffle replacement")
			_expect(not choice.has("_soul_summon_reserved"), "production offer must not revive the retired reservation marker")
		if found:
			present_count += 1
		else:
			absent_count += 1
	_expect(present_count > 0, "deterministic production screens must include Soul Summoning Art at least once")
	_expect(absent_count > 0, "deterministic production screens must also omit Soul Summoning Art")

	var catalog_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_catalog.gd")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	for retired_symbol in [
		"SOUL_SUMMON_PRIORITY_KEY",
		"_extract_soul_summon_reserved_choice",
		"begin_soul_summon_offer_screen",
		"_soul_summon_offer_guarantee_count",
		"_soul_summon_offer_cooldown_screens",
		"_soul_summon_offer_pending_choice",
		"get_soul_summon_offer_state_for_tests",
	]:
		_expect(catalog_source.find(retired_symbol) < 0 and runtime_source.find(retired_symbol) < 0, "retired offer state must be fully removed: %s" % retired_symbol)


func _verify_immediate_drop_and_three_skip_branches() -> void:
	var runtime := LingpetEggRuntime.new()
	var registry := FakeRegistry.new(runtime)
	var owner := DynamicOwner.new()
	var first := RuntimePerkSoulSummonArt.apply_acquired(owner, registry)
	_expect(bool(first.get("dropped", false)), "successful unlock apply must immediately deploy one field egg")
	var duplicate := RuntimePerkSoulSummonArt.apply_acquired(owner, registry)
	_expect(str(duplicate.get("skipped_reason", "")) == "egg_already_present", "existing field egg should skip only the duplicate drop")
	owner.free()

	var full_runtime := LingpetEggRuntime.new()
	full_runtime.set_soul_summon_overflow_available_for_tests(false)
	var full_owner := DynamicOwner.new()
	var pet_ids: Array[String] = LingpetCatalog.get_pet_ids()
	full_owner.set("lingpet_owned_pet_ids", [pet_ids[0], pet_ids[1], pet_ids[2]])
	var full_result := full_runtime.deploy_soul_summon_egg(full_owner, FakeRegistry.new(full_runtime))
	_expect(str(full_result.get("skipped_reason", "")) == "overflow_unavailable", "full roster without overflow candidate must skip the drop")
	full_owner.free()

	var complete_runtime := LingpetEggRuntime.new()
	var complete_owner := DynamicOwner.new()
	complete_runtime.set("_collection_state", FakeNoCandidateCollection.new())
	var complete_result := complete_runtime.deploy_soul_summon_egg(complete_owner, FakeRegistry.new(complete_runtime))
	_expect(str(complete_result.get("skipped_reason", "")) == "deploy_rejected", "complete collection must skip when the central deploy path has no pet candidate")
	complete_owner.free()


func _verify_swap_cancel_cannot_reach_drop_helper() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
	var cancel_body := _function_body(source, "func cancel_pending_swap_from_runtime_state")
	var confirm_body := _function_body(source, "func confirm_pending_swap(")
	_expect(cancel_body.find("RuntimePerkSoulSummonArt") < 0, "swap cancel must be a complete no-op for egg drop and unlock effects")
	_expect(confirm_body.find("RuntimePerkSoulSummonArt.apply_acquired") >= 0, "confirmed swap must own the immediate drop after level commit")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
