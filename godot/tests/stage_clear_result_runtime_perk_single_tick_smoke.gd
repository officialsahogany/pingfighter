extends SceneTree

# The result screen already advances RuntimePerkState from its own update flow.
# The battle overlay frame must not pump the same choice again while the result
# screen is active, but it must remain the owner for choices opened in battle.

const BattleSceneFrameController := preload("res://scripts/core/battle_scene_frame_controller.gd")

var _failures: Array[String] = []


class FakeRuntimePerkState:
	extends RefCounted

	var update_calls := 0

	func update() -> void:
		update_calls += 1


class FakeStageClearResultScreen:
	extends RefCounted

	var active := true
	var update_calls := 0
	var runtime_perk_state: Object

	func _init(perk_state: Object) -> void:
		runtime_perk_state = perk_state

	func is_active() -> bool:
		return active

	func update(_delta: float) -> void:
		update_calls += 1
		# Mirrors StageClearResultStarpointChoiceHandler.update_runtime_choice().
		runtime_perk_state.update()


class FakeBattleOverlayFrame:
	extends RefCounted

	var process_calls := 0
	var runtime_perk_state: Object

	func _init(perk_state: Object) -> void:
		runtime_perk_state = perk_state

	func process_idle(
		_delta: float,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable
	) -> bool:
		process_calls += 1
		runtime_perk_state.update()
		return true


class FakeReadinessController:
	extends RefCounted

	func is_intro_or_warmup_blocking(
		_module_getter: Callable,
		_is_battle_initialized: bool,
		_is_stage_landing_intro_started: bool
	) -> bool:
		return false


class FakeOwner:
	extends RefCounted

	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeModuleHost:
	extends RefCounted

	var result_screen: Object
	var overlay_frame: Object
	var readiness := FakeReadinessController.new()
	var overlay_lookups := 0

	func _init(result_screen_value: Object, overlay_frame_value: Object) -> void:
		result_screen = result_screen_value
		overlay_frame = overlay_frame_value

	func get_module(key: String) -> Object:
		match key:
			"battle_scene_readiness_controller":
				return readiness
			"stage_clear_result_screen":
				return result_screen
			"battle_scene_overlay_frame_controller":
				overlay_lookups += 1
				return overlay_frame
		return null


func _init() -> void:
	_verify_result_choice_advances_once()
	_verify_battle_choice_keeps_overlay_tick()

	if _failures.is_empty():
		print("stage_clear_result_runtime_perk_single_tick_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_result_choice_advances_once() -> void:
	var perk_state := FakeRuntimePerkState.new()
	var result_screen := FakeStageClearResultScreen.new(perk_state)
	var overlay_frame := FakeBattleOverlayFrame.new(perk_state)
	var module_host := FakeModuleHost.new(result_screen, overlay_frame)
	var owner := FakeOwner.new()

	BattleSceneFrameController.new().process_idle(
		1.0 / 60.0,
		owner,
		null,
		Callable(module_host, "get_module"),
		_callbacks()
	)

	_expect(result_screen.update_calls == 1, "active result screen should update once per idle frame")
	_expect(perk_state.update_calls == 1, "result-screen perk choice/fusion animation must advance exactly once")
	_expect(overlay_frame.process_calls == 0, "result screen must not also pump the battle overlay frame")
	_expect(module_host.overlay_lookups == 0, "result path should not instantiate or fetch the battle overlay frame")
	_expect(owner.redraw_requests == 1, "result path should still request one battle redraw")


func _verify_battle_choice_keeps_overlay_tick() -> void:
	var perk_state := FakeRuntimePerkState.new()
	var result_screen := FakeStageClearResultScreen.new(perk_state)
	result_screen.active = false
	var overlay_frame := FakeBattleOverlayFrame.new(perk_state)
	var module_host := FakeModuleHost.new(result_screen, overlay_frame)

	BattleSceneFrameController.new().process_idle(
		1.0 / 60.0,
		FakeOwner.new(),
		null,
		Callable(module_host, "get_module"),
		_callbacks()
	)

	_expect(result_screen.update_calls == 0, "inactive result screen must not own the battle choice clock")
	_expect(overlay_frame.process_calls == 1, "battle-time perk choices must still use the overlay-frame tick")
	_expect(perk_state.update_calls == 1, "battle-time perk choice should advance once")


func _callbacks() -> Dictionary:
	return {
		"is_battle_initialized": Callable(self, "_true"),
		"is_stage_landing_intro_started": Callable(self, "_true"),
	}


func _true() -> bool:
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
