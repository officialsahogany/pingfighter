extends SceneTree

const StageClearResultMythicAcquisitionHandler := preload("res://scripts/core/stage_clear_result_mythic_acquisition_handler.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends Node2D


class FakeScene:
	extends Control


class FakeMythicRuntime:
	extends RefCounted

	var active: bool = false
	var update_calls: int = 0
	var input_calls: int = 0
	var last_owner: Object = null
	var last_registry: Object = null
	var last_delta: float = 0.0
	var acquisition_cinematic: Object = null

	func is_acquisition_cinematic_active() -> bool:
		return active

	func update(owner: Object, registry: Object, delta: float) -> void:
		update_calls += 1
		last_owner = owner
		last_registry = registry
		last_delta = delta

	func handle_acquisition_cinematic_input(_event: InputEvent, registry: Object = null) -> bool:
		input_calls += 1
		last_registry = registry
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_update_input_and_raise()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_mythic_acquisition_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_update_input_and_raise() -> void:
	var handler := StageClearResultMythicAcquisitionHandler.new()
	var owner := FakeOwner.new()
	var scene := FakeScene.new()
	var runtime := FakeMythicRuntime.new()
	var registry := RefCounted.new()
	var cinematic := Node2D.new()
	cinematic.z_index = 7
	cinematic.z_as_relative = true
	cinematic.process_mode = Node.PROCESS_MODE_INHERIT
	runtime.acquisition_cinematic = cinematic
	root.add_child(owner)
	owner.add_child(scene)
	owner.add_child(cinematic)

	_expect(not handler.update_cinematic(0.25, runtime, owner, registry), "handler should skip inactive mythic acquisition updates")
	_expect(runtime.update_calls == 0, "inactive mythic acquisition should not update")
	runtime.active = true
	_expect(handler.update_cinematic(0.25, runtime, owner, registry), "handler should update active mythic acquisition cinematics")
	_expect(runtime.update_calls == 1, "handler should call the mythic runtime update once")
	_expect(runtime.last_owner == owner, "handler should forward the result owner to mythic runtime update")
	_expect(runtime.last_registry == registry, "handler should forward the registry to mythic runtime update")
	_expect(is_equal_approx(runtime.last_delta, 0.25), "handler should forward delta to mythic runtime update")
	_expect(not cinematic.z_as_relative, "handler should force mythic acquisition cinematic to absolute z ordering")
	_expect(cinematic.z_index >= 1305, "handler should raise mythic acquisition cinematic above result chrome")
	_expect(cinematic.process_mode == Node.PROCESS_MODE_ALWAYS, "handler should keep mythic acquisition cinematic processing over the result modal")

	var event := InputEventKey.new()
	_expect(handler.handle_input(event, runtime, owner, registry, scene), "handler should consume input while mythic acquisition is active")
	_expect(runtime.input_calls == 1, "handler should route input to the mythic runtime")
	_expect(runtime.last_registry == registry, "handler should forward registry during mythic acquisition input")
	runtime.active = false
	_expect(not handler.handle_input(event, runtime, owner, registry, scene), "handler should ignore input when mythic acquisition is inactive")
	_expect(runtime.input_calls == 1, "inactive mythic acquisition input should not call runtime input")
	owner.queue_free()


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_mythic_acquisition_handler.gd")
	_expect(registry_source.find("StageClearResultMythicAcquisitionHandler.new()") >= 0, "handler registry should delegate mythic acquisition glue to its handler")
	_expect(screen_source.find("func _update_mythic_acquisition_cinematic") < 0, "result screen should not own mythic acquisition update glue")
	_expect(screen_source.find("func _handle_mythic_acquisition_input") < 0, "result screen should not own mythic acquisition input glue")
	_expect(screen_source.find("func _raise_result_mythic_acquisition_cinematic") < 0, "result screen should not own mythic acquisition raise glue")
	_expect(handler_source.find("handle_acquisition_cinematic_input") >= 0, "mythic acquisition handler should own runtime input fanout")
	_expect(handler_source.find("Node.PROCESS_MODE_ALWAYS") >= 0, "mythic acquisition handler should keep the cinematic active over the modal")
	_expect(handler_source.find("maxi(cinematic.z_index, 1305)") >= 0, "mythic acquisition handler should own result-layer z raise")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
