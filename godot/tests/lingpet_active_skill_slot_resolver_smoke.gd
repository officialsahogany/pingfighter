extends SceneTree

const LingpetActiveSkillSlotResolver := preload("res://scripts/lingpet/lingpet_active_skill_slot_resolver.gd")

var _failures: Array[String] = []


class FakeProfile:
	extends RefCounted

	var active_skill_ids: Array[String] = []
	var active_slot_count := 1
	var second_active_unlocked := false
	var windup_by_slot: Dictionary = {}

	func _init(ids: Array = [], unlocked := false, slot_count := 1) -> void:
		for raw_id in ids:
			active_skill_ids.append(str(raw_id))
		second_active_unlocked = unlocked
		active_slot_count = slot_count

	func get_active_skill(slot_index: int) -> Dictionary:
		var skill_id := get_skill_id(slot_index)
		if skill_id == "":
			return {}
		return {
			"id": skill_id,
			"slot_index": slot_index,
		}

	func get_skill_id(slot_index: int) -> String:
		if slot_index < 0 or slot_index >= active_skill_ids.size():
			return ""
		return active_skill_ids[slot_index]

	func get_skill_windup_seconds(fallback: float, slot_index: int) -> float:
		return float(windup_by_slot.get(slot_index, fallback))

	func is_second_active_unlocked() -> bool:
		return second_active_unlocked

	func get_active_slot_count() -> int:
		return active_slot_count


class FakeRuntimeHost:
	extends RefCounted

	var shared_pairs: Dictionary = {}

	func _init(pairs: Dictionary = {}) -> void:
		shared_pairs = pairs.duplicate(true)

	func would_share_module(first_skill_id: String, second_skill_id: String) -> bool:
		return bool(shared_pairs.get("%s|%s" % [first_skill_id, second_skill_id], false))


func _init() -> void:
	_verify_locked_second_slot_stays_hidden()
	_verify_unlocked_second_slot_surfaces_runtime_metadata()
	_verify_shared_module_collapses_runtime_slot_count()
	_verify_runtime_delegates_slot_decisions()

	if _failures.is_empty():
		print("lingpet_active_skill_slot_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_locked_second_slot_stays_hidden() -> void:
	var resolver := LingpetActiveSkillSlotResolver.new()
	var profile := FakeProfile.new(["maribo_hydro_sphere", "maribo_bubble_trap"], false, 2)
	profile.windup_by_slot[1] = 0.9

	_expect(not resolver.is_second_active_slot_enabled(profile), "locked profile should not enable slot 1")
	_expect_eq(resolver.get_active_slot_count(profile, FakeRuntimeHost.new()), 1, "locked profile should report one runtime active slot")
	_expect_str(resolver.get_skill_id_for_slot(profile, 1), "", "locked slot 1 should not expose a skill id")
	_expect_eq(resolver.get_active_skill_ids_for_runtime(profile, FakeRuntimeHost.new()), ["maribo_hydro_sphere"], "locked profile should expose only slot 0 runtime skill id")
	_expect_eq(resolver.get_second_active_skill_for_runtime_surface(profile, FakeRuntimeHost.new()), {}, "locked slot 1 should not expose runtime metadata")
	_expect_float(resolver.get_second_skill_windup_seconds_for_runtime_surface(profile, FakeRuntimeHost.new(), 0.5), 0.0, "locked slot 1 should not expose windup seconds")


func _verify_unlocked_second_slot_surfaces_runtime_metadata() -> void:
	var resolver := LingpetActiveSkillSlotResolver.new()
	var profile := FakeProfile.new(["red_dragon_dragon_breath", "red_dragon_dragon_wing"], true, 2)
	profile.windup_by_slot[1] = 0.75
	var host := FakeRuntimeHost.new()

	_expect(resolver.is_second_active_slot_enabled(profile), "unlocked profile with slot-1 id should enable slot 1")
	_expect_eq(resolver.get_active_slot_count(profile, host), 2, "distinct active skills should expose two runtime slots")
	_expect_str(resolver.get_skill_id_for_slot(profile, 0), "red_dragon_dragon_breath", "slot 0 id should pass through")
	_expect_str(resolver.get_skill_id_for_slot(profile, 1), "red_dragon_dragon_wing", "slot 1 id should pass through")
	_expect_eq(resolver.get_active_skill_ids_for_runtime(profile, host), ["red_dragon_dragon_breath", "red_dragon_dragon_wing"], "distinct active skills should expose both runtime skill ids")
	_expect_str(str(resolver.get_second_active_skill_for_runtime_surface(profile, host).get("id", "")), "red_dragon_dragon_wing", "runtime surface should expose slot 1 skill metadata")
	_expect_float(resolver.get_second_skill_windup_seconds_for_runtime_surface(profile, host, 0.5), 0.75, "runtime surface should expose slot 1 windup seconds")


func _verify_shared_module_collapses_runtime_slot_count() -> void:
	var resolver := LingpetActiveSkillSlotResolver.new()
	var profile := FakeProfile.new(["red_dragon_dragon_breath", "red_dragon_dragon_breath"], true, 2)
	var host := FakeRuntimeHost.new({
		"red_dragon_dragon_breath|red_dragon_dragon_breath": true,
	})

	_expect(resolver.is_second_active_slot_enabled(profile), "profile gate alone should still see the slot-1 id")
	_expect_str(resolver.get_skill_id_for_slot(profile, 1), "red_dragon_dragon_breath", "compatibility slot-id wrapper should not apply host conflict filtering")
	_expect_eq(resolver.get_active_slot_count(profile, host), 1, "shared-module skills should collapse runtime active slot count")
	_expect_eq(resolver.get_active_skill_ids_for_runtime(profile, host), ["red_dragon_dragon_breath"], "shared-module slot collapse should expose only one runtime skill id")
	_expect_eq(resolver.get_second_active_skill_for_runtime_surface(profile, host), {}, "shared-module slot 1 should stay off runtime surfaces")
	_expect_float(resolver.get_second_skill_windup_seconds_for_runtime_surface(profile, host, 0.5), 0.0, "shared-module slot 1 should not expose windup seconds")


func _verify_runtime_delegates_slot_decisions() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_active_skill_slot_resolver.gd")
	var surface_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_surface.gd")
	var loadout_applier_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_loadout_applier.gd")
	_expect(runtime_source.find("LingpetActiveSkillSlotResolver") >= 0, "egg runtime should preload the active skill slot resolver")
	_expect(runtime_source.find("LingpetSkillRuntimeSurface") >= 0, "egg runtime should preload the skill runtime surface")
	_expect(runtime_source.find("_skill_runtime_surface.get_active_slot_count") >= 0, "runtime active-slot count should delegate through the skill runtime surface")
	_expect(runtime_source.find("_skill_runtime_surface.get_active_skill_ids") >= 0, "runtime active-skill id list should delegate through the skill runtime surface")
	_expect(loadout_applier_source.find("skill_runtime_host.prewarm_many") >= 0 and loadout_applier_source.find("active_skill_slot_resolver.get_active_skill_ids_for_runtime") >= 0, "current-loadout applier should hand the resolver-built active skill id list to the runtime host")
	_expect(runtime_source.find("func _is_second_active_slot_enabled") < 0, "runtime should not keep an unused second-active-slot wrapper")
	_expect(runtime_source.find("func _get_current_skill_id") < 0, "runtime should not keep the old single-use current skill-id wrapper")
	_expect(runtime_source.find("func _get_current_skill_windup_seconds") < 0, "runtime should not keep the old single-use current skill-windup wrapper")
	_expect(runtime_source.find("func _get_current_active_skill") < 0, "runtime should not keep a single-use slot-0 active-skill alias")
	for second_surface_wrapper in ["func _get_second_active_skill_for_runtime_surface", "func _get_second_skill_state_for_runtime_surface", "func _get_second_skill_windup_seconds_for_runtime_surface"]:
		_expect(runtime_source.find(second_surface_wrapper) < 0, "runtime should not keep second-slot runtime-surface pass-through wrappers (%s)" % second_surface_wrapper)
	_expect(runtime_source.find("_skill_runtime_surface.get_second_active_surface") >= 0, "runtime snapshot/sync paths should ask the skill runtime surface for second-active metadata")
	_expect(surface_source.find("func get_second_active_surface") >= 0 and surface_source.find("get_active_surface_for_slot") >= 0, "skill runtime surface should own second-active surface assembly")
	_expect(runtime_source.find("for slot in range(_get_active_slot_count()):\n\t\tskill_ids.append(_get_skill_id_for_slot(slot))") < 0, "runtime should not rebuild active skill id lists inline")
	_expect(runtime_source.find("for slot in range(_get_active_slot_count()):\n\t\tvar skill_id := _get_skill_id_for_slot(slot)\n\t\tif skill_id != \"\":\n\t\t\t_skill_runtime_host.prewarm(skill_id)") < 0, "runtime skill prewarm should not rebuild active skill id lists inline")
	_expect(runtime_source.find("func _prewarm_current_skill_runtime") < 0, "runtime should not keep a private active-skill prewarm wrapper")
	_expect(runtime_source.find("_skill_runtime_host.would_share_module(first_skill_id, second_skill_id)") < 0, "runtime should not keep host module-sharing slot collapse logic inline")
	_expect(owner_source.find("would_share_module") >= 0, "resolver should own host module-sharing slot collapse logic")
	_expect(owner_source.find("func get_active_skill_ids_for_runtime") >= 0, "resolver should own runtime active skill id list assembly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected '%s', got '%s')" % [message, expected, actual])


func _expect_float(actual: float, expected: float, message: String, tolerance: float = 0.01) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.3f, got %.3f)" % [message, expected, actual])
