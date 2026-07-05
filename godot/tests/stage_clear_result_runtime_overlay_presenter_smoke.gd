extends SceneTree

const StageClearResultRuntimeOverlayPresenter := preload("res://scripts/ui/stage_clear_result_runtime_overlay_presenter.gd")
const StageClearResultRuntimeOverlaySceneHandler := preload("res://scripts/ui/stage_clear_result_runtime_overlay_scene_handler.gd")
const StageClearResultScene := preload("res://scripts/ui/stage_clear_result_scene.gd")

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
	_verify_scene_handler_uses_scene_dependencies()
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


func _verify_scene_handler_uses_scene_dependencies() -> void:
	var scene := StageClearResultScene.new()
	scene.size = Vector2(1280.0, 720.0)
	var runtime_state := FakeRuntimePerkState.new()
	var mythic_runtime := FakeMythicRuntime.new()
	var treasure_runtime := FakeTreasureHuntRuntime.new()
	var overlay_renderer := FakeOverlayRenderer.new()
	var runtime_catalog := RefCounted.new()
	var runtime_icon := RefCounted.new()
	scene.set("_runtime_perk_state", runtime_state)
	scene.set("_mythic_item_runtime", mythic_runtime)
	scene.set("_treasure_hunt_runtime", treasure_runtime)
	scene.set("_runtime_perk_overlay_renderer", overlay_renderer)
	scene.set("_runtime_perk_catalog", runtime_catalog)
	scene.set("_runtime_perk_icon_renderer", runtime_icon)

	_expect(not StageClearResultRuntimeOverlaySceneHandler.is_runtime_perk_choice_active(scene), "scene handler should read inactive runtime perk choice state")
	runtime_state.choice_active = true
	_expect(StageClearResultRuntimeOverlaySceneHandler.is_runtime_perk_choice_active(scene), "scene handler should read active runtime perk choice state")
	_expect(StageClearResultRuntimeOverlaySceneHandler.is_interaction_blocked(scene), "scene handler should report interaction blocking from runtime perk choices")
	runtime_state.choice_active = false
	scene.set("_starpoint_choice_gate_active", true)
	_expect(StageClearResultRuntimeOverlaySceneHandler.is_interaction_blocked(scene), "scene handler should read the scene starpoint gate")
	StageClearResultRuntimeOverlaySceneHandler.set_starpoint_choice_gate_active(scene, false)
	_expect(not bool(scene.get("_starpoint_choice_gate_active")), "scene handler should clear the starpoint gate")
	_expect(int(scene.get("_starpoint_choice_gate_box_index")) == -1, "scene handler should clear the starpoint gate box index")
	mythic_runtime.acquisition_active = true
	_expect(StageClearResultRuntimeOverlaySceneHandler.is_mythic_acquisition_cinematic_active(scene), "scene handler should read mythic acquisition state")
	treasure_runtime.effect_active = true
	_expect(StageClearResultRuntimeOverlaySceneHandler.is_treasure_hunt_effect_active(scene), "scene handler should read treasure-hunt state")

	var event := InputEventKey.new()
	StageClearResultRuntimeOverlaySceneHandler.handle_runtime_perk_input(scene, event)
	_expect(runtime_state.input_calls == 1, "scene handler should route runtime perk input through the presenter")
	_expect(runtime_state.last_view_size == Vector2(1280.0, 720.0), "scene handler should forward the scene view size")
	StageClearResultRuntimeOverlaySceneHandler.handle_mythic_acquisition_input(scene, event)
	_expect(mythic_runtime.input_calls == 1, "scene handler should route mythic acquisition input through the presenter")

	_expect(StageClearResultRuntimeOverlaySceneHandler.should_draw_overlay(scene), "scene handler should draw while treasure hunt is active")
	var drawn: bool = StageClearResultRuntimeOverlaySceneHandler.draw_overlay(scene, scene.size)
	_expect(drawn, "scene handler should report overlay draw when active")
	_expect(overlay_renderer.draw_calls == 1, "scene handler should call the runtime overlay renderer once")
	_expect(overlay_renderer.received_catalog == runtime_catalog, "scene handler should forward the runtime catalog")
	_expect(overlay_renderer.received_icon_renderer == runtime_icon, "scene handler should forward the runtime icon renderer")
	scene.free()


func _verify_scene_delegates_runtime_overlay() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene.gd")
	var screen_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_screen.gd")
	var draw_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_draw_scene_handler.gd")
	var config_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_config_scene_handler.gd")
	var input_scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_input_scene_handler.gd")
	var scene_context_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_scene_context_builder.gd")
	var scene_handler_source: String = FileAccess.get_file_as_string("res://scripts/ui/stage_clear_result_runtime_overlay_scene_handler.gd")
	var starpoint_choice_handler_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_starpoint_choice_handler.gd")
	var starpoint_choice_state_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_starpoint_choice_state.gd")
	_expect(source.find("StageClearResultConfigSceneHandler.create_default_perk_catalog") >= 0, "result scene should request its default runtime perk catalog through config scene glue")
	_expect(source.find("StageClearResultConfigSceneHandler.create_default_perk_icon_renderer") >= 0, "result scene should request its default runtime perk icon renderer through config scene glue")
	_expect(source.find("StageClearResultConfigSceneHandler.create_default_runtime_perk_overlay_renderer") >= 0, "result scene should request its default runtime perk overlay renderer through config scene glue")
	_expect(source.find("RuntimePerkCatalog.new()") < 0, "result scene should not create the runtime perk catalog directly")
	_expect(source.find("RuntimePerkIconRenderer.new()") < 0, "result scene should not create the runtime perk icon renderer directly")
	_expect(source.find("RuntimePerkOverlayRenderer.new()") < 0, "result scene should not create the runtime perk overlay renderer directly")
	_expect(config_scene_handler_source.find("RuntimePerkCatalog.new()") >= 0, "config scene handler should create the default runtime perk catalog")
	_expect(config_scene_handler_source.find("RuntimePerkIconRenderer.new()") >= 0, "config scene handler should create the default runtime perk icon renderer")
	_expect(config_scene_handler_source.find("RuntimePerkOverlayRenderer.new()") >= 0, "config scene handler should create the default runtime perk overlay renderer")
	var registry_source: String = FileAccess.get_file_as_string("res://scripts/core/stage_clear_result_handler_registry.gd")
	_expect(registry_source.find("StageClearResultStarpointChoiceHandler.new()") >= 0, "handler registry should route starpoint choice flow through its handler")
	_expect(screen_source.find("StageClearResultRuntimeOverlaySceneHandler.set_starpoint_choice_gate_active") < 0, "result screen should not write starpoint gate scene glue directly")
	_expect(starpoint_choice_handler_source.find("StageClearResultRuntimeOverlaySceneHandler.set_starpoint_choice_gate_active") < 0, "starpoint choice handler should delegate starpoint gate scene glue")
	_expect(starpoint_choice_state_source.find("StageClearResultRuntimeOverlaySceneHandler.set_starpoint_choice_gate_active") >= 0, "starpoint choice state should route starpoint gate scene glue through the runtime overlay scene handler")
	_expect(source.find("func set_starpoint_choice_gate_active") < 0, "result scene should not keep a starpoint gate facade")
	_expect(source.find("StageClearResultDrawSceneHandler.draw_result_scene") >= 0, "result scene should delegate top-level drawing through the draw scene handler")
	_expect(draw_scene_handler_source.find("StageClearResultRuntimeOverlaySceneHandler.draw_overlay") >= 0, "draw scene handler should delegate runtime overlay drawing to the scene handler")
	_expect(input_scene_handler_source.find("StageClearResultRuntimeOverlaySceneHandler.handle_runtime_perk_input") >= 0, "input scene handler should delegate runtime perk input to the runtime overlay scene handler")
	_expect(input_scene_handler_source.find("StageClearResultRuntimeOverlaySceneHandler.handle_mythic_acquisition_input") >= 0, "input scene handler should delegate mythic acquisition input to the runtime overlay scene handler")
	_expect(scene_context_source.find("StageClearResultRuntimeOverlaySceneHandler.is_runtime_perk_choice_active") >= 0, "scene context builder should delegate runtime perk state to the runtime overlay scene handler")
	_expect(scene_context_source.find("StageClearResultRuntimeOverlaySceneHandler.is_treasure_hunt_effect_active") >= 0, "scene context builder should delegate treasure-hunt state to the runtime overlay scene handler")
	_expect(source.find("StageClearResultRuntimeOverlayPresenter.") < 0, "result scene should not call runtime overlay presenter directly")
	_expect(scene_handler_source.find("StageClearResultRuntimeOverlayPresenter.draw_overlay") >= 0, "scene handler should delegate runtime overlay drawing to the presenter")
	_expect(scene_handler_source.find("StageClearResultRuntimeOverlayPresenter.should_draw_overlay") >= 0, "scene handler should delegate runtime overlay visibility to the presenter")
	_expect(scene_handler_source.find("StageClearResultRuntimeOverlayPresenter.is_interaction_blocked") >= 0, "scene handler should delegate interaction blocking policy to the presenter")
	_expect(scene_handler_source.find("StageClearResultRuntimeOverlayPresenter.handle_runtime_perk_input") >= 0, "scene handler should delegate runtime perk input to the presenter")
	_expect(scene_handler_source.find("StageClearResultRuntimeOverlayPresenter.handle_mythic_acquisition_input") >= 0, "scene handler should delegate mythic acquisition input to the presenter")
	_expect(scene_handler_source.find("static func set_starpoint_choice_gate_active") >= 0, "runtime overlay scene handler should own starpoint gate scene writes")
	_expect(source.find("func _draw_runtime_perk_overlay") < 0, "result scene should not keep runtime-overlay draw fanout wrappers")
	_expect(source.find("func _should_draw_runtime_perk_overlay") < 0, "result scene should not keep runtime-overlay visibility fanout wrappers")
	_expect(source.find("func _handle_runtime_perk_input") < 0, "result scene should not keep runtime perk input fanout wrappers")
	_expect(source.find("func _handle_mythic_acquisition_input") < 0, "result scene should not keep mythic acquisition input fanout wrappers")
	_expect(source.find("func _is_mythic_acquisition_cinematic_active") < 0, "result scene should not keep mythic acquisition state fanout wrappers")
	_expect(source.find("func _is_treasure_hunt_effect_active") < 0, "result scene should not keep treasure-hunt state fanout wrappers")
	_expect(source.find("func _is_result_interaction_blocked") < 0, "result scene should not keep interaction-block fanout wrappers")
	_expect(source.find("func _is_runtime_perk_choice_active") < 0, "result scene should not keep runtime perk state fanout wrappers")
	_expect(source.find("_starpoint_choice_gate_active = active") < 0, "result scene should not write starpoint gate fields inline")
	_expect(source.find("has_visible_effects") < 0, "result scene should not inspect overlay renderer visible effects directly")
	_expect(source.find("has_method(\"is_choice_active\")") < 0, "result scene should not inspect runtime perk active methods directly")
	_expect(source.find("has_method(\"is_effect_active\")") < 0, "result scene should not inspect treasure hunt active methods directly")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
