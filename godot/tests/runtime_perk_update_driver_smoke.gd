extends SceneTree

const RuntimePerkUpdateDriver := preload("res://scripts/core/battle_scene_runtime_perk_update_driver.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var marker := "owner"


class FakeRuntimePerkState:
	extends RefCounted

	var call_count := 0
	var last_owner: Object
	var last_registry: Object
	var last_delta := 0.0

	func update_resume_safety(owner: Object, registry: Object, delta: float) -> void:
		call_count += 1
		last_owner = owner
		last_registry = registry
		last_delta = delta


class NoopRuntimePerkState:
	extends RefCounted

	var untouched := true


class FakeRegistry:
	extends RefCounted

	var runtime_perk_state: Object

	func _init(perk_state: Object = null) -> void:
		runtime_perk_state = perk_state

	func get_instance(key: String) -> Object:
		if key == "runtime_perk_state":
			return runtime_perk_state
		return null


func _init() -> void:
	var driver: Object = RuntimePerkUpdateDriver.new()
	var owner := FakeOwner.new()
	var perk_state := FakeRuntimePerkState.new()
	var registry := FakeRegistry.new(perk_state)

	driver.update_runtime_perk_resume(owner, registry, 0.25)
	_expect(perk_state.call_count == 1, "driver should call runtime perk resume safety once")
	_expect(perk_state.last_owner == owner, "driver should forward owner")
	_expect(perk_state.last_registry == registry, "driver should forward registry")
	_expect(abs(perk_state.last_delta - 0.25) <= 0.001, "driver should forward delta")
	perk_state.last_owner = null
	perk_state.last_registry = null
	registry.runtime_perk_state = null

	driver.update_runtime_perk_resume(owner, FakeRegistry.new(NoopRuntimePerkState.new()), 0.5)
	driver.update_runtime_perk_resume(owner, FakeRegistry.new(), 0.5)
	driver.update_runtime_perk_resume(owner, null, 0.5)

	if _failures.is_empty():
		print("runtime_perk_update_driver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
