extends SceneTree

# expect-zero-object-leaks
const BattleTerminalScreenInputRouter := preload(
	"res://scripts/core/battle_terminal_screen_input_router.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1

	func get_viewport_rect() -> Rect2:
		return Rect2(Vector2.ZERO, Vector2(1280.0, 900.0))


class FakeScreen:
	extends RefCounted

	var active := false
	var accept_input := true
	var handle_count := 0
	var view_sizes: Array[Vector2] = []

	func is_active() -> bool:
		return active

	func handle_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object,
		view_size: Vector2
	) -> bool:
		handle_count += 1
		view_sizes.append(view_size)
		return accept_input


class FakeModalGate:
	extends RefCounted

	var runtime_perk_active := false

	func is_runtime_perk_choice_active(_module_getter: Callable) -> bool:
		return runtime_perk_active


class FakeOverlayInput:
	extends RefCounted

	var handle_count := 0

	func handle_input(
		_event: InputEvent,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable,
		_context: Dictionary
	) -> bool:
		handle_count += 1
		return true


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


func _init() -> void:
	_verify_terminal_priority_and_continue_fallthrough()
	_verify_settlement_consumes_active_input()
	_verify_stage_clear_routes_result_input()
	_verify_stage_clear_runtime_perk_overlay_route()
	_verify_source_ownership_and_order()
	call_deferred("_finish")


func _finish() -> void:
	if _failures.is_empty():
		print("battle_terminal_screen_input_router_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_terminal_priority_and_continue_fallthrough() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var continue_screen: FakeScreen = fixture["continue"]
	var settlement: FakeScreen = fixture["settlement"]
	var result: FakeScreen = fixture["result"]
	var owner := FakeOwner.new()
	continue_screen.active = true
	settlement.active = true
	result.active = true
	_expect(
		BattleTerminalScreenInputRouter.new().handle_input(
			InputEventKey.new(), owner, null, Callable(holder, "get_module")
		),
		"accepted chance-gem input must consume before later terminal screens"
	)
	_expect(continue_screen.handle_count == 1, "chance-gem screen must receive the first terminal event")
	_expect(settlement.handle_count == 0 and result.handle_count == 0, "accepted chance-gem input must stop terminal routing")
	_expect(owner.redraw_count == 1, "accepted chance-gem input must redraw once")

	continue_screen.accept_input = false
	owner.redraw_count = 0
	_expect(
		BattleTerminalScreenInputRouter.new().handle_input(
			InputEventKey.new(), owner, null, Callable(holder, "get_module")
		),
		"chance-gem refusal must fall through to active settlement"
	)
	_expect(continue_screen.handle_count == 2, "chance-gem screen must receive the refused event")
	_expect(settlement.handle_count == 1, "settlement must receive input after chance-gem refusal")
	_expect(result.handle_count == 0, "settlement consumption must still precede stage-clear result")
	_expect(owner.redraw_count == 1, "fallthrough settlement must request one redraw")
	_clear_fixture(fixture)


func _verify_settlement_consumes_active_input() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var settlement: FakeScreen = fixture["settlement"]
	var owner := FakeOwner.new()
	settlement.active = true
	settlement.accept_input = false
	_expect(
		BattleTerminalScreenInputRouter.new().handle_input(
			InputEventKey.new(), owner, null, Callable(holder, "get_module")
		),
		"active settlement must consume even when its local result is false"
	)
	_expect(settlement.handle_count == 1, "active settlement must receive the event once")
	_expect(settlement.view_sizes == [Vector2(1280.0, 900.0)], "settlement must receive the live viewport size")
	_expect(owner.redraw_count == 1, "active settlement must redraw once")
	_clear_fixture(fixture)


func _verify_stage_clear_routes_result_input() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var result: FakeScreen = fixture["result"]
	var owner := FakeOwner.new()
	result.active = true
	result.accept_input = false
	_expect(
		BattleTerminalScreenInputRouter.new().handle_input(
			InputEventKey.new(), owner, null, Callable(holder, "get_module")
		),
		"active stage-clear result must consume input"
	)
	_expect(result.handle_count == 1, "stage-clear result must receive the event once")
	_expect(result.view_sizes == [Vector2(1280.0, 900.0)], "stage-clear result must receive the live viewport size")
	_expect(owner.redraw_count == 1, "stage-clear result input must redraw once")
	_clear_fixture(fixture)


func _verify_stage_clear_runtime_perk_overlay_route() -> void:
	var fixture := _build_fixture()
	var holder: ModuleHolder = fixture["holder"]
	var result: FakeScreen = fixture["result"]
	var modal_gate: FakeModalGate = fixture["modal_gate"]
	var overlay: FakeOverlayInput = fixture["overlay"]
	var owner := FakeOwner.new()
	result.active = true
	modal_gate.runtime_perk_active = true
	_expect(
		BattleTerminalScreenInputRouter.new().handle_input(
			InputEventKey.new(), owner, null, Callable(holder, "get_module")
		),
		"runtime-perk choice above stage-clear result must consume input"
	)
	_expect(overlay.handle_count == 1, "active runtime-perk choice must receive stage-clear input through overlay routing")
	_expect(result.handle_count == 0, "stage-clear scene must not receive input below an active runtime-perk choice")
	_expect(owner.redraw_count == 1, "runtime-perk overlay route must redraw once")
	_clear_fixture(fixture)


func _verify_source_ownership_and_order() -> void:
	var router_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_terminal_screen_input_router.gd"
	)
	var input_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_input_controller.gd"
	)
	_expect(router_source.find("defeat_chance_gems_continue_screen") < router_source.find("defeat_settlement_screen"), "chance-gem route must precede settlement")
	_expect(router_source.find("defeat_settlement_screen") < router_source.find("stage_clear_result_screen"), "settlement route must precede stage-clear result")
	_expect(router_source.contains("is_runtime_perk_choice_active(module_getter)"), "terminal router must preserve the stage-clear runtime-perk overlay gate")
	_expect(input_source.contains("BattleTerminalScreenInputRouter.new()"), "scene input controller must compose the terminal router")
	_expect(input_source.contains("_terminal_input_router.handle_input("), "scene input controller must delegate terminal input once")
	_expect(input_source.find("_lingpet_input_router.handle_priority_cutin_input(") < input_source.find("_terminal_input_router.handle_input("), "Lingpet shell-break/acquisition priority must stay above terminal screens")
	_expect(input_source.find("_terminal_input_router.handle_input(") < input_source.find("_handle_runtime_perk_choice_input("), "terminal screens must stay before general runtime-perk choice routing")
	_expect(not input_source.contains("func _handle_defeat_chance_gems_continue_input"), "scene input controller must not retain chance-gem input policy")
	_expect(not input_source.contains("func _handle_defeat_settlement_input"), "scene input controller must not retain settlement input policy")
	_expect(not input_source.contains("func _handle_stage_clear_result_input"), "scene input controller must not retain result-screen input policy")


func _build_fixture() -> Dictionary:
	var holder := ModuleHolder.new()
	var continue_screen := FakeScreen.new()
	var settlement := FakeScreen.new()
	var result := FakeScreen.new()
	var modal_gate := FakeModalGate.new()
	var overlay := FakeOverlayInput.new()
	holder.modules = {
		"defeat_chance_gems_continue_screen": continue_screen,
		"defeat_settlement_screen": settlement,
		"stage_clear_result_screen": result,
		"battle_scene_modal_gate_controller": modal_gate,
		"battle_scene_overlay_input_controller": overlay,
	}
	return {
		"holder": holder,
		"continue": continue_screen,
		"settlement": settlement,
		"result": result,
		"modal_gate": modal_gate,
		"overlay": overlay,
	}


func _clear_fixture(fixture: Dictionary) -> void:
	var holder: ModuleHolder = fixture["holder"]
	holder.modules.clear()
	fixture.clear()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
