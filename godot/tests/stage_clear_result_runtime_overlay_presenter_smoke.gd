extends SceneTree

const StageClearResultRuntimeOverlayPresenter := preload("res://scripts/ui/stage_clear_result_runtime_overlay_presenter.gd")

var _failures: Array[String] = []


class FakeRuntimePerkState:
	extends RefCounted

	var choice_active := false
	var input_calls := 0
	var last_view_size := Vector2.ZERO

	func is_choice_active() -> bool:
		return choice_active

	func handle_input(_event: InputEvent, _owner: Object, _registry: Object, view_size: Vector2) -> void:
		input_calls += 1
		last_view_size = view_size


class FakeMythicRuntime:
	extends RefCounted

	var acquisition_active := false
	var input_calls := 0

	func is_acquisition_cinematic_active() -> bool:
		return acquisition_active

	func handle_acquisition_cinematic_input(_event: InputEvent, _registry: Object = null) -> void:
		input_calls += 1


class FakeTreasureHuntRuntime:
	extends RefCounted

	var effect_active := false

	func is_effect_active() -> bool:
		return effect_active


class FakeOverlayRenderer:
	extends RefCounted

	var visible_effects := false
	var draw_calls := 0
	var received_catalog: Object = null
	var received_icon_renderer: Object = null

	func has_visible_effects(_runtime_state: Object, _mythic_item_runtime: Object = null, _treasure_hunt_runtime: Object = null) -> bool:
		return visible_effects

	func draw(
		_canvas: CanvasItem,
		_runtime_state: Object,
		catalog: Object,
		_view_size: Vector2,
		icon_renderer: Object = null,
		_mythic_item_runtime: Object = null,
		_treasure_hunt_runtime: Object = null
	) -> void:
		draw_calls += 1
		received_catalog = catalog
		received_icon_renderer = icon_renderer


func _init() -> void:
	_verify_active_checks_and_input()
	_verify_overlay_visibility_and_draw()
	_verify_scene_delegates_runtime_overlay()

	if _failures.is_empty():
		print("stage_clear_result_runtime_overlay_presenter_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_active_checks_and_input() -> void:
	var runtime_state := FakeRuntimePerkState.new()
	var mythic_runtime := FakeMythicRuntime.new()
	var treasure_runtime := FakeTreasureHuntRuntime.new()
	_expect(not StageClearResultRuntimeOverlayPresenter.is_runtime_perk_choice_active(runtime_state), "inactive runtime perk choice should be false")
	runtime_state.choice_active = true
	_expect(StageClearResultRuntimeOverlayPresenter.is_runtime_perk_choice_active(runtime_state), "active runtime perk choice should be true")
	mythic_runtime.acquisition_active = true
	_expect(StageClearResultRuntimeOverlayPresenter.is_mythic_acquisition_cinematic_active(mythic_runtime), "active mythic acquisition should be true")
	treasure_runtime.effect_active = true
	_expect(StageClearResultRuntimeOverlayPresenter.is_treasure_hunt_effect_active(treasure_runtime), "active treasure hunt effect should be true")
	_expect(StageClearResultRuntimeOverlayPresenter.is_interaction_blocked(false, runtime_state, null), "runtime choice should block result interaction")
	runtime_state.choice_active = false
	_expect(StageClearResultRuntimeOverlayPresenter.is_interaction_blocked(true, runtime_state, null), "starpoint gate should block result interaction")
	_expect(StageClearResultRuntimeOverlayPresenter.is_interaction_blocked(false, runtime_state, treasure_runtime), "treasure hunt effect should block result interaction")

	var event := InputEventKey.new()
	StageClearResultRuntimeOverlayPresenter.handle_runtime_perk_input(event, runtime_state, null, null, Vector2(1920.0, 1080.0))
	_expect(runtime_state.input_calls == 1, "runtime perk input should call the runtime state")
	_expect(runtime_state.last_view_size == Vector2(1920.0, 1080.0), "runtime perk input should forward the view size")
	StageClearResultRuntimeOverlayPresenter.handle_mythic_acquisition_input(event, mythic_runtime, null)
	_expect(mythic_runtime.input_calls == 1, "mythic acquisition input should call the mythic runtime")


func _verify_overlay_visibility_and_draw() -> void:
	var runtime_state := FakeRuntimePerkState.new()
	var mythic_runtime := FakeMythicRuntime.new()
	var treasure_runtime := FakeTreasureHuntRuntime.new()
	var overlay_renderer := FakeOverlayRenderer.new()
	_expect(not StageClearResultRuntimeOverlayPresenter.should_draw_overlay(overlay_renderer, runtime_state, mythic_runtime, treasure_runtime), "inactive overlay should not draw")
	overlay_renderer.visible_effects = true
	_expect(StageClearResultRuntimeOverlayPresenter.should_draw_overlay(overlay_renderer, runtime_state, mythic_runtime, treasure_runtime), "visible overlay effects should request draw")
	overlay_renderer.visible_effects = false
	treasure_runtime.effect_active = true
	_expect(StageClearResultRuntimeOverlayPresenter.should_draw_overlay(overlay_renderer, runtime_state, mythic_runtime, treasure_runtime), "active treasure hunt effect should request draw")

	var canvas := Control.new()
	var fallback_catalog := RefCounted.new()
	var runtime_catalog := RefCounted.new()
	var fallback_icon := RefCounted.new()
	var runtime_icon := RefCounted.new()
	var drawn: bool = StageClearResultRuntimeOverlayPresenter.draw_overlay(
		canvas,
		overlay_renderer,
		runtime_state,
		fallback_catalog,
		runtime_catalog,
		fallback_icon,
		runtime_icon,
		Vector2(1280.0, 720.0),
		mythic_runtime,
		treasure_runtime
	)
	_expect(drawn, "draw overlay should report a draw when active")
	_expect(overlay_renderer.draw_calls == 1, "draw overlay should call renderer.draw once")
	_expect(overlay_renderer.received_catalog == runtime_catalog, "draw overlay should prefer runtime catalog")
	_expect(overlay_renderer.received_icon_renderer == runtime_icon, "draw overlay should prefer runtime icon renderer")
	canvas.free()


func _verify_scene_delegates_runtime_overlay() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	_expect(source.find("StageClearResultRuntimeOverlayPresenter.draw_overlay") >= 0, "result scene should delegate runtime overlay drawing")
	_expect(source.find("StageClearResultRuntimeOverlayPresenter.should_draw_overlay") >= 0, "result scene should delegate runtime overlay visibility")
	_expect(source.find("StageClearResultRuntimeOverlayPresenter.is_interaction_blocked") >= 0, "result scene should delegate result interaction blocking")
	_expect(source.find("StageClearResultRuntimeOverlayPresenter.handle_runtime_perk_input") >= 0, "result scene should delegate runtime perk input")
	_expect(source.find("StageClearResultRuntimeOverlayPresenter.handle_mythic_acquisition_input") >= 0, "result scene should delegate mythic acquisition input")
	_expect(source.find("has_visible_effects") < 0, "result scene should not inspect overlay renderer visible effects directly")
	_expect(source.find("has_method(\"is_choice_active\")") < 0, "result scene should not inspect runtime perk active methods directly")
	_expect(source.find("has_method(\"is_effect_active\")") < 0, "result scene should not inspect treasure hunt active methods directly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
