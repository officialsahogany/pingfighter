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

	func has_unowned_pet_candidates(_owner: Object) -> bool:
		return false


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
	_verify_offer_reservation_and_three_screen_cooldown()
	_verify_immediate_drop_and_three_skip_branches()
	_verify_swap_cancel_cannot_reach_drop_helper()
	if _failures.is_empty():
		print("soul_summon_art_egg_grant_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_offer_reservation_and_three_screen_cooldown() -> void:
	var runtime := LingpetEggRuntime.new()
	var registry := FakeRegistry.new(runtime)
	var catalog := RuntimePerkCatalog.new()
	var offers: Array = []
	catalog._append_soul_summon_choice(offers, {}, registry)
	_expect(_is_reserved(offers), "first unowned martial-art screen must reserve Soul Summoning Art")
	offers.clear()
	catalog._append_soul_summon_choice(offers, {}, registry)
	_expect(_is_reserved(offers), "second unowned martial-art screen must reserve Soul Summoning Art")
	for cooldown_screen in range(3):
		offers.clear()
		catalog._append_soul_summon_choice(offers, {}, registry)
		_expect(offers.is_empty(), "skipping both guarantees should hide the offer on cooldown screen %d" % (cooldown_screen + 1))
	offers.clear()
	catalog._append_soul_summon_choice(offers, {}, registry)
	_expect(_is_reserved(offers), "offer must return as a protected reservation after exactly three screens")
	offers.clear()
	catalog._append_soul_summon_choice(offers, {CommonSkillCatalog.SOUL_SUMMON_ART_ID: 1}, registry)
	_expect(offers.is_empty(), "owned Soul Summoning Art must never reappear")


func _is_reserved(offers: Array) -> bool:
	if offers.size() != 1 or not (offers[0] is Dictionary):
		return false
	var offer: Dictionary = offers[0] as Dictionary
	return (
		str(offer.get("id", "")) == CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID
		and bool(offer.get(RuntimePerkCatalog.SOUL_SUMMON_PRIORITY_KEY, false))
	)


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
	_expect(str(complete_result.get("skipped_reason", "")) == "no_unowned_pet_candidates", "complete collection must skip the drop")
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
