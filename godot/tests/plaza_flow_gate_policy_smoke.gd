extends SceneTree

const PlazaFlowGatePolicy := preload("res://scripts/plaza/plaza_flow_gate_policy.gd")

var _failures: Array[String] = []


func _init() -> void:
	_expect_gate([false, false, false, false, false], PlazaFlowGatePolicy.STREET, "idle street")
	_expect_gate([false, false, false, false, true], PlazaFlowGatePolicy.INTERIOR_MENU, "menu gate")
	_expect_gate([false, false, false, true, true], PlazaFlowGatePolicy.BUILDING_TRANSITION, "transition before menu")
	_expect_gate([false, false, true, true, true], PlazaFlowGatePolicy.PLAZA_WARP, "warp before transition")
	_expect_gate([false, true, true, true, true], PlazaFlowGatePolicy.CHARACTER_INFO, "character info before warp")
	_expect_gate([true, true, true, true, true], PlazaFlowGatePolicy.RUNTIME_PERK, "runtime perk highest priority")
	for gate in [
		PlazaFlowGatePolicy.RUNTIME_PERK,
		PlazaFlowGatePolicy.CHARACTER_INFO,
		PlazaFlowGatePolicy.PLAZA_WARP,
		PlazaFlowGatePolicy.BUILDING_TRANSITION,
		PlazaFlowGatePolicy.INTERIOR_MENU,
	]:
		_expect(PlazaFlowGatePolicy.blocks_street_update(gate), "%s should block street movement" % gate)
	_expect(not PlazaFlowGatePolicy.blocks_street_update(PlazaFlowGatePolicy.STREET), "street should allow movement")

	if _failures.is_empty():
		print("plaza_flow_gate_policy_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect_gate(flags: Array, expected: StringName, label: String) -> void:
	var actual := PlazaFlowGatePolicy.resolve(
		bool(flags[0]),
		bool(flags[1]),
		bool(flags[2]),
		bool(flags[3]),
		bool(flags[4])
	)
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
