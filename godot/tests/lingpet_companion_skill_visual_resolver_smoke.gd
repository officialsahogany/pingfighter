extends SceneTree

const LingpetCompanionSkillVisualResolver := preload("res://scripts/lingpet/lingpet_companion_skill_visual_resolver.gd")

var _failures: Array[String] = []


class FakeSkillState:
	extends RefCounted

	var windup_active := false


class ModernRuntimeHost:
	extends RefCounted

	var active_owner: Dictionary = {}

	func get_active_position_override_owner(_skill_ids: Array[String], fallback_pos: Vector2) -> Dictionary:
		if active_owner.is_empty():
			return {
				"has": false,
				"slot_index": -1,
				"skill_id": "",
				"pos": fallback_pos,
			}
		return active_owner.duplicate(true)


class FallbackRuntimeHost:
	extends RefCounted

	var override_ids: Dictionary = {}
	var override_pos_by_id: Dictionary = {}
	var cast_pose_progress_by_id: Dictionary = {}

	func has_companion_position_override(skill_id: String) -> bool:
		return bool(override_ids.get(skill_id, false))

	func get_companion_position_override(skill_id: String, fallback_pos: Vector2) -> Vector2:
		var pos: Variant = override_pos_by_id.get(skill_id, fallback_pos)
		return pos if pos is Vector2 else fallback_pos

	func get_companion_cast_pose_progress(skill_id: String) -> float:
		return float(cast_pose_progress_by_id.get(skill_id, -1.0))


func _init() -> void:
	_verify_modern_position_override_owner_and_body_skill()
	_verify_fallback_position_override_owner()
	_verify_active_visual_slot_selection()
	_verify_runtime_delegates_visual_resolution()

	if _failures.is_empty():
		print("lingpet_companion_skill_visual_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_modern_position_override_owner_and_body_skill() -> void:
	var resolver := LingpetCompanionSkillVisualResolver.new()
	var host := ModernRuntimeHost.new()
	host.active_owner = {
		"has": true,
		"slot_index": 1,
		"skill_id": "lunabi_headbutt",
		"pos": Vector2(120.0, 240.0),
	}
	var owner: Dictionary = resolver.get_active_position_override_owner(
		["red_dragon_dragon_breath", "lunabi_headbutt"],
		host,
		Vector2(10.0, 20.0)
	)
	_expect(resolver.has_active_position_override(owner), "modern host override owner should report active")
	_expect_eq(int(owner.get("slot_index", -1)), 1, "modern host override owner should preserve slot index")
	_expect_str(str(owner.get("skill_id", "")), "lunabi_headbutt", "modern host override owner should preserve skill id")
	_expect_eq(owner.get("pos"), Vector2(120.0, 240.0), "modern host override owner should preserve override position")
	_expect_str(resolver.get_companion_body_skill_id(owner, "red_dragon_dragon_breath"), "lunabi_headbutt", "body skill id should prefer active override skill")
	var empty_owner := resolver.get_active_position_override_owner([], ModernRuntimeHost.new(), Vector2(5.0, 6.0))
	_expect(not resolver.has_active_position_override(empty_owner), "empty modern host owner should report inactive")
	_expect_str(resolver.get_companion_body_skill_id(empty_owner, "maribo_hydro_sphere"), "maribo_hydro_sphere", "body skill id should fall back to current skill")


func _verify_fallback_position_override_owner() -> void:
	var resolver := LingpetCompanionSkillVisualResolver.new()
	var host := FallbackRuntimeHost.new()
	host.override_ids["koyora_puppet_control"] = true
	host.override_pos_by_id["koyora_puppet_control"] = Vector2(300.0, 420.0)
	var owner: Dictionary = resolver.get_active_position_override_owner(
		["rabi_ghost_summon", "koyora_puppet_control"],
		host,
		Vector2(10.0, 20.0)
	)
	_expect(resolver.has_active_position_override(owner), "fallback host override owner should report active")
	_expect_eq(int(owner.get("slot_index", -1)), 1, "fallback host should resolve active override slot")
	_expect_str(str(owner.get("skill_id", "")), "koyora_puppet_control", "fallback host should resolve active override skill")
	_expect_eq(owner.get("pos"), Vector2(300.0, 420.0), "fallback host should resolve active override position")


func _verify_active_visual_slot_selection() -> void:
	var resolver := LingpetCompanionSkillVisualResolver.new()
	var states := [FakeSkillState.new(), FakeSkillState.new()]
	states[1].windup_active = true
	_expect_eq(
		resolver.get_active_visual_slot_index(["maribo_hydro_sphere", "koyora_doll_curse"], states, FallbackRuntimeHost.new()),
		1,
		"visual slot should prefer the casting windup slot"
	)
	states[1].windup_active = false
	var host := FallbackRuntimeHost.new()
	host.cast_pose_progress_by_id["koyora_doll_curse"] = 0.25
	_expect_eq(
		resolver.get_active_visual_slot_index(["maribo_hydro_sphere", "koyora_doll_curse"], states, host),
		1,
		"visual slot should use companion cast pose progress when no slot is winding up"
	)
	host.cast_pose_progress_by_id.clear()
	_expect_eq(
		resolver.get_active_visual_slot_index(["maribo_hydro_sphere", "koyora_doll_curse"], states, host),
		0,
		"visual slot should fall back to slot 0 when no active visual owner exists"
	)


func _verify_runtime_delegates_visual_resolution() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_visual_resolver.gd")
	var surface_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_skill_runtime_surface.gd")
	_expect(runtime_source.find("LingpetCompanionSkillVisualResolver") >= 0, "egg runtime should preload the companion skill visual resolver")
	_expect(runtime_source.find("_skill_runtime_surface.get_active_position_owner") >= 0, "runtime should delegate active position override owner resolution through the skill runtime surface")
	_expect(surface_source.find("companion_skill_visual_resolver.get_active_position_override_owner") >= 0, "skill runtime surface should delegate active position override owner resolution to the visual resolver")
	_expect(runtime_source.find("func _get_active_visual_slot_index") < 0, "runtime should not reintroduce the single-use active visual slot wrapper")
	_expect(runtime_source.find("_skill_runtime_surface.get_visual_surface") >= 0, "runtime draw path should ask the skill runtime surface for visual slot state")
	_expect(surface_source.find("companion_skill_visual_resolver.get_active_visual_slot_index") >= 0, "skill runtime surface should call the active visual slot resolver")
	_expect(runtime_source.find("get_companion_cast_pose_progress(skill_id)") < 0, "runtime should not keep cast-pose visual slot logic inline")
	_expect(owner_source.find("get_active_position_override_owner") >= 0, "visual resolver should own override owner resolution")
	_expect(owner_source.find("get_companion_cast_pose_progress") >= 0, "visual resolver should own cast-pose visual slot fallback")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _expect_str(actual: String, expected: String, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected '%s', got '%s')" % [message, expected, actual])
