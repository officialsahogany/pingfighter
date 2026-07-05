extends SceneTree

const StageClearResultPrewarmFlowHandler := preload("res://scripts/core/stage_clear_result_prewarm_flow_handler.gd")
const StageClearResultScreen := preload("res://scripts/core/stage_clear_result_screen.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage: int = 1
	var selected_character_type: String = "smasher"


class FakeRuntimeContextHandler:
	extends RefCounted

	var stage_calls: int = 0
	var character_calls: int = 0

	func get_current_stage(owner: Object) -> int:
		stage_calls += 1
		return int(owner.get("current_stage"))

	func get_result_victory_character_type(owner: Object) -> String:
		character_calls += 1
		if owner == null:
			return "smasher"
		return str(owner.get("selected_character_type"))


class FakeSceneSpawnFlowHandler:
	extends RefCounted

	var shell_ready: bool = true
	var step_done: bool = false
	var seen_shell: Object
	var seen_character: String = ""
	var seen_stage: int = 0
	var seen_threaded: bool = false
	var shell_calls: int = 0
	var step_calls: int = 0
	var status: Dictionary = {}

	func prewarm_scene_shell(shell_handler: Object) -> Dictionary:
		shell_calls += 1
		seen_shell = shell_handler
		status = {"result_scene_packed": shell_ready}
		return {
			"ready": shell_ready,
			"status": status.duplicate(true),
		}

	func prewarm_assets_step(shell_handler: Object, selected_character_type: String, stage_id: int, use_threaded_texture_loads: bool) -> Dictionary:
		step_calls += 1
		seen_shell = shell_handler
		seen_character = selected_character_type
		seen_stage = stage_id
		seen_threaded = use_threaded_texture_loads
		status = {
			"selected_character_type": selected_character_type,
			"current_stage": stage_id,
			"threaded": use_threaded_texture_loads,
		}
		return {
			"done": step_done,
			"status": status.duplicate(true),
		}


class FakeBlockingStep:
	extends RefCounted

	var calls: int = 0

	func prewarm_assets_step(_owner: Object, _registry: Object) -> bool:
		calls += 1
		return calls >= 2


class FakeScreen:
	extends RefCounted

	var current_stage: int = 1
	var _pending_owner: Object
	var _scene_spawn_flow_handler: Object
	var _scene_shell_handler: Object
	var _runtime_context_handler: Object


func _init() -> void:
	_verify_shell_prewarm_status()
	_verify_asset_prewarm_context_and_status()
	_verify_asset_prewarm_uses_fallback_context()
	_verify_blocking_prewarm_returns_status()
	_verify_screen_adapters_own_callback_and_context()
	_verify_source_boundary()

	if _failures.is_empty():
		print("stage_clear_result_prewarm_flow_handler_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_shell_prewarm_status() -> void:
	var handler := StageClearResultPrewarmFlowHandler.new()
	var flow := FakeSceneSpawnFlowHandler.new()
	var shell := RefCounted.new()
	_expect(handler.prewarm_scene_shell(flow, shell), "prewarm flow should delegate result scene shell prewarm")
	_expect(flow.shell_calls == 1 and flow.seen_shell == shell, "prewarm flow should pass the shell handler to shell prewarm")
	_expect(bool(handler.get_prewarm_status().get("result_scene_packed", false)), "prewarm flow should retain shell prewarm status")


func _verify_asset_prewarm_context_and_status() -> void:
	var handler := StageClearResultPrewarmFlowHandler.new()
	var flow := FakeSceneSpawnFlowHandler.new()
	var runtime := FakeRuntimeContextHandler.new()
	var owner := FakeOwner.new()
	owner.current_stage = 5
	owner.selected_character_type = "viper"
	flow.step_done = true
	_expect(
		handler.prewarm_assets_step(owner, null, 1, true, flow, RefCounted.new(), runtime),
		"prewarm flow should expose completed staged prewarm"
	)
	_expect(flow.seen_character == "viper", "prewarm flow should resolve victory character for asset prewarm")
	_expect(flow.seen_stage == 5, "prewarm flow should resolve current stage for asset prewarm")
	_expect(flow.seen_threaded, "prewarm flow should preserve threaded asset prewarm mode")
	_expect(runtime.stage_calls == 1 and runtime.character_calls == 1, "prewarm flow should use runtime context for owner-bound prewarm")
	_expect(int(handler.get_prewarm_status().get("current_stage", 0)) == 5, "prewarm flow should retain staged prewarm status")


func _verify_asset_prewarm_uses_fallback_context() -> void:
	var handler := StageClearResultPrewarmFlowHandler.new()
	var flow := FakeSceneSpawnFlowHandler.new()
	var runtime := FakeRuntimeContextHandler.new()
	var fallback_owner := FakeOwner.new()
	fallback_owner.current_stage = 6
	fallback_owner.selected_character_type = "soldier"
	flow.step_done = true
	_expect(
		handler.prewarm_assets_step(null, fallback_owner, 3, false, flow, RefCounted.new(), runtime),
		"prewarm flow should use the pending owner when no explicit owner is provided"
	)
	_expect(flow.seen_character == "soldier", "prewarm flow should resolve fallback owner character")
	_expect(flow.seen_stage == 6, "prewarm flow should resolve fallback owner stage")

	handler = StageClearResultPrewarmFlowHandler.new()
	flow = FakeSceneSpawnFlowHandler.new()
	flow.step_done = true
	_expect(
		handler.prewarm_assets_step(null, null, 4, false, flow, RefCounted.new(), runtime),
		"prewarm flow should still prewarm with the stored stage when no owner is available"
	)
	_expect(flow.seen_stage == 4, "prewarm flow should preserve fallback stage without an owner")


func _verify_blocking_prewarm_returns_status() -> void:
	var handler := StageClearResultPrewarmFlowHandler.new()
	var flow := FakeSceneSpawnFlowHandler.new()
	var runtime := FakeRuntimeContextHandler.new()
	var owner := FakeOwner.new()
	owner.current_stage = 2
	owner.selected_character_type = "smasher"
	flow.step_done = true
	handler.prewarm_assets_step(owner, null, 1, false, flow, RefCounted.new(), runtime)

	var sink := FakeBlockingStep.new()
	var status: Dictionary = handler.prewarm_assets(owner, null, Callable(sink, "prewarm_assets_step"))
	_expect(sink.calls == 2, "blocking prewarm should advance until the public step reports completion")
	_expect(str(status.get("selected_character_type", "")) == "smasher", "blocking prewarm should return cached status")


func _verify_screen_adapters_own_callback_and_context() -> void:
	var handler := StageClearResultPrewarmFlowHandler.new()
	var flow := FakeSceneSpawnFlowHandler.new()
	var runtime := FakeRuntimeContextHandler.new()
	var shell := RefCounted.new()
	var owner := FakeOwner.new()
	owner.current_stage = 5
	owner.selected_character_type = "viper"
	var fallback_owner := FakeOwner.new()
	fallback_owner.current_stage = 6
	fallback_owner.selected_character_type = "soldier"
	var screen := FakeScreen.new()
	screen.current_stage = 3
	screen._pending_owner = fallback_owner
	screen._scene_spawn_flow_handler = flow
	screen._scene_shell_handler = shell
	screen._runtime_context_handler = runtime

	_expect(handler.prewarm_scene_shell_from_screen(screen), "screen shell adapter should resolve scene handlers from the screen")
	_expect(flow.shell_calls == 1 and flow.seen_shell == shell, "screen shell adapter should delegate to the resolved shell")

	flow.step_done = true
	var threaded_step: Callable = handler.build_prewarm_assets_step_callback_from_screen(screen, true)
	_expect(bool(threaded_step.call(owner, null)), "screen prewarm callback should invoke the handler-owned screen step adapter")
	_expect(flow.seen_character == "viper", "screen prewarm callback should resolve explicit owner character")
	_expect(flow.seen_stage == 5, "screen prewarm callback should resolve explicit owner stage")
	_expect(flow.seen_threaded, "screen prewarm callback should preserve threaded mode")

	flow = FakeSceneSpawnFlowHandler.new()
	flow.step_done = true
	screen._scene_spawn_flow_handler = flow
	var status: Dictionary = handler.prewarm_assets_from_screen(null, null, screen)
	_expect(flow.step_calls == 1, "screen blocking prewarm should build and use its own step callback")
	_expect(flow.seen_character == "soldier", "screen blocking prewarm should fall back to the pending owner character")
	_expect(flow.seen_stage == 6, "screen blocking prewarm should fall back to the pending owner stage")
	_expect(int(status.get("current_stage", 0)) == 6, "screen blocking prewarm should return the cached screen-adapter status")


func _verify_source_boundary() -> void:
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	var handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_prewarm_flow_handler.gd")
	var step_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_prewarm_step_data.gd")
	var screen_data_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_prewarm_screen_data.gd")
	_expect(registry_source.find("StageClearResultPrewarmFlowHandler.new()") >= 0, "handler registry should own prewarm through the prewarm flow handler")
	_expect(screen_source.find("var _prewarm_assets_status") < 0, "result screen should not own prewarm status storage")
	_expect(screen_source.find("func _apply_prewarm_flow_status") < 0, "result screen should not apply prewarm flow status inline")
	_expect(screen_source.find("func _prewarm_assets_step_impl") < 0, "result screen should not keep private prewarm step plumbing")
	_expect(screen_source.find("Callable(self, \"prewarm_assets_step\")") < 0, "result screen should not build pending-spawn prewarm callbacks directly")
	_expect(handler_source.find("var _prewarm_assets_status") >= 0, "prewarm flow handler should own prewarm status storage")
	_expect(handler_source.find("func prewarm_assets_step") >= 0, "prewarm flow handler should expose staged prewarm context assembly")
	_expect(handler_source.find("StageClearResultPrewarmStepData.prewarm_assets_step") >= 0, "prewarm flow handler should delegate staged prewarm context assembly")
	_expect(handler_source.find("StageClearResultPrewarmStepData.prewarm_scene_shell") >= 0, "prewarm flow handler should delegate shell prewarm calls")
	_expect(handler_source.find("func prewarm_assets_step_from_screen") >= 0, "prewarm flow handler should expose screen staged prewarm adapters")
	_expect(handler_source.find("StageClearResultPrewarmScreenData.build_prewarm_assets_step_context_from_screen") >= 0, "prewarm flow handler should delegate screen staged prewarm context reads")
	_expect(handler_source.find("StageClearResultPrewarmScreenData.build_prewarm_assets_step_callback_from_screen") >= 0, "prewarm flow handler should delegate pending-spawn prewarm callback wiring")
	_expect(handler_source.find("func _get_result_victory_character_type") < 0, "prewarm flow handler should not keep runtime character readers")
	_expect(handler_source.find("func _get_current_stage") < 0, "prewarm flow handler should not keep runtime stage readers")
	_expect(handler_source.find("func _get_screen_object") < 0, "prewarm flow handler should not keep screen object readers")
	_expect(handler_source.find("func _get_screen_int") < 0, "prewarm flow handler should not keep screen integer readers")
	_expect(step_data_source.find("static func prewarm_scene_shell") >= 0, "prewarm step data should own shell prewarm call normalization")
	_expect(step_data_source.find("static func prewarm_assets_step") >= 0, "prewarm step data should own staged asset-prewarm calls")
	_expect(step_data_source.find("get_result_victory_character_type") >= 0, "prewarm step data should own victory-character lookup")
	_expect(step_data_source.find("get_current_stage") >= 0, "prewarm step data should own current-stage lookup")
	_expect(step_data_source.find("static func copy_status") >= 0, "prewarm step data should own prewarm status copying")
	_expect(screen_data_source.find("static func prewarm_assets_from_screen") >= 0, "prewarm screen data should own blocking prewarm screen adapters")
	_expect(screen_data_source.find("static func prewarm_scene_shell_from_screen") >= 0, "prewarm screen data should own shell prewarm screen adapters")
	_expect(screen_data_source.find("static func build_prewarm_assets_step_context_from_screen") >= 0, "prewarm screen data should own screen staged prewarm context reads")
	_expect(screen_data_source.find("static func build_prewarm_assets_step_callback_from_screen") >= 0, "prewarm screen data should own pending-spawn prewarm callback wiring")
	var screen := StageClearResultScreen.new()
	_expect(screen != null, "result screen should instantiate with the prewarm flow handler")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
