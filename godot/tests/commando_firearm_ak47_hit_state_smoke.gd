extends SceneTree

const CommandoFirearmAk47HitState := preload("res://scripts/characters/commando_firearm_ak47_hit_state.gd")
const CommandoFirearmRuntime := preload("res://scripts/characters/commando_firearm_runtime.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_ak47_hit_state()
	_verify_runtime_delegates_ak47_hit_state()

	if _failures.is_empty():
		print("commando_firearm_ak47_hit_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_ak47_hit_state() -> void:
	var ignored: Dictionary = CommandoFirearmAk47HitState.build_accumulated_damage_payload("bazooka", 0, 0, 20)
	_expect(ignored.is_empty(), "AK-47 hit helper should ignore other weapons")

	var early: Dictionary = CommandoFirearmAk47HitState.build_accumulated_damage_payload("ak47", 18, 0, 20)
	var early_fields: Dictionary = _get_dict(early.get("result_fields", {}))
	_expect(int(early.get("next_hit_count", 0)) == 19, "AK-47 hit helper should increment early hits")
	_expect(int(early_fields.get("ak47_boss_hit_count", 0)) == 19, "AK-47 hit helper should expose early hit count")
	_expect(not bool(early_fields.get("ak47_accumulated_damage_ready", false)), "AK-47 early hit should not emit damage")

	var ready: Dictionary = CommandoFirearmAk47HitState.build_accumulated_damage_payload("ak47", 19, 0, 20)
	var ready_fields: Dictionary = _get_dict(ready.get("result_fields", {}))
	_expect(int(ready.get("next_hit_count", -1)) == 0, "AK-47 threshold hit should reset hit count")
	_expect(bool(ready_fields.get("ak47_accumulated_damage_ready", false)), "AK-47 threshold hit should mark damage ready")
	_expect(int(ready_fields.get("damage_units", 0)) == 1, "AK-47 threshold hit should emit at least one damage unit")

	var stacked: Dictionary = CommandoFirearmAk47HitState.build_accumulated_damage_payload("ak47", 19, 2, 20)
	var stacked_fields: Dictionary = _get_dict(stacked.get("result_fields", {}))
	_expect(int(stacked_fields.get("damage_units", 0)) == 2, "AK-47 threshold hit should preserve larger existing damage units")


func _verify_runtime_delegates_ak47_hit_state() -> void:
	var runtime := CommandoFirearmRuntime.new()
	runtime.ak47_boss_hit_count = 19
	var result := {}
	runtime._apply_ak47_accumulated_boss_damage("ak47", result)
	_expect(runtime.ak47_boss_hit_count == 0, "runtime AK-47 wrapper should store helper hit count")
	_expect(bool(result.get("ak47_accumulated_damage_ready", false)), "runtime AK-47 wrapper should merge helper fields")
	_expect(int(result.get("damage_units", 0)) == 1, "runtime AK-47 wrapper should emit damage")


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
