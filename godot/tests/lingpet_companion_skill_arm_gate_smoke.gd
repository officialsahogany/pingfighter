extends SceneTree

const LingpetCompanionSkillArmGate := preload("res://scripts/lingpet/lingpet_companion_skill_arm_gate.gd")

var _failures: Array[String] = []


class FakeSkillState:
	extends RefCounted

	var windup_active := false


class FakeRuntimeHost:
	extends RefCounted

	var shared_pairs: Dictionary = {}
	var launch_blocked_ids: Dictionary = {}
	var position_override_ids: Dictionary = {}

	func skills_share_exclusive_resource(first_skill_id: String, second_skill_id: String) -> bool:
		return bool(shared_pairs.get("%s|%s" % [first_skill_id, second_skill_id], false))

	func is_launch_blocked(skill_id: String) -> bool:
		return bool(launch_blocked_ids.get(skill_id, false))

	func has_companion_position_override(skill_id: String) -> bool:
		return bool(position_override_ids.get(skill_id, false))


func _init() -> void:
	_verify_windup_slot_blocks_shared_resource()
	_verify_active_launch_or_position_override_blocks_shared_resource()
	_verify_runtime_delegates_arm_gate()

	if _failures.is_empty():
		print("lingpet_companion_skill_arm_gate_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_windup_slot_blocks_shared_resource() -> void:
	var gate := LingpetCompanionSkillArmGate.new()
	var host := FakeRuntimeHost.new()
	host.shared_pairs["maribo_hydro_sphere|rabi_ghost_summon"] = true
	var states := [FakeSkillState.new(), FakeSkillState.new()]
	states[0].windup_active = true
	var active_ids: Array[String] = ["rabi_ghost_summon", "maribo_hydro_sphere"]
	_expect(not gate.can_arm(1, "maribo_hydro_sphere", active_ids, states, host), "slot 1 should not arm while a shared-resource peer is winding up")
	_expect(gate.can_arm(1, "red_dragon_dragon_breath", active_ids, states, host), "free-resource skill should arm beside a BALL_OWNER windup")
	states[0].windup_active = false
	_expect(gate.can_arm(1, "maribo_hydro_sphere", active_ids, states, host), "shared-resource peer with no active hold should not block arm")


func _verify_active_launch_or_position_override_blocks_shared_resource() -> void:
	var gate := LingpetCompanionSkillArmGate.new()
	var host := FakeRuntimeHost.new()
	host.shared_pairs["maribo_hydro_sphere|monkeyring_wild_roar"] = true
	host.shared_pairs["lunabi_headbutt|monkeyring_wild_roar"] = true
	var states := [FakeSkillState.new(), FakeSkillState.new()]
	var active_ids: Array[String] = ["monkeyring_wild_roar", "maribo_hydro_sphere"]
	host.launch_blocked_ids["monkeyring_wild_roar"] = true
	_expect(not gate.can_arm(1, "maribo_hydro_sphere", active_ids, states, host), "launch-blocked peer should hold its exclusive resource")
	host.launch_blocked_ids.clear()
	host.position_override_ids["monkeyring_wild_roar"] = true
	_expect(not gate.can_arm(1, "lunabi_headbutt", ["monkeyring_wild_roar", "lunabi_headbutt"], states, host), "position-override peer should hold its exclusive resource")


func _verify_runtime_delegates_arm_gate() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var controller_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_controller.gd")
	var owner_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_skill_arm_gate.gd")
	_expect(runtime_source.find("LingpetCompanionSkillController") >= 0, "egg runtime should preload the companion skill controller")
	_expect(controller_source.find("LingpetCompanionSkillArmGate") >= 0, "companion skill controller should preload the companion skill arm gate")
	_expect(controller_source.find("_arm_gate.can_arm") >= 0, "companion skill controller arm path should delegate to the arm gate")
	_expect(runtime_source.find("func _slot_holds_exclusive_resource") < 0, "runtime should not keep an unused private resource-hold wrapper")
	_expect(runtime_source.find("skills_share_exclusive_resource(skill_id, other_skill_id)") < 0, "runtime should not keep exclusive-resource intersection logic inline")
	_expect(owner_source.find("skills_share_exclusive_resource") >= 0, "arm gate should own exclusive-resource intersection checks")
	_expect(owner_source.find("is_launch_blocked") >= 0, "arm gate should preserve active launch-blocked resource holds")
	_expect(owner_source.find("has_companion_position_override") >= 0, "arm gate should preserve position-override resource holds")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
