extends SceneTree

const BattleSceneOverlayFrameController := preload("res://scripts/core/battle_scene_overlay_frame_controller.gd")
const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")

var _failures: Array[String] = []
var _modules: Dictionary = {}


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


class FakeModalGate:
	extends RefCounted

	var active_item_debug_open := false
	var character_info_active := false
	var character_debug_picker: Object = null
	var perk_debug_picker: Object = null
	var stage_debug_picker: Object = null
	var weather_debug_picker: Object = null
	var lingpet_debug_picker: Object = null
	var active_item_runtime: Object = null
	var mythic_item_runtime: Object = null
	var character_info: Object = null
	var ball_speed_debug: Object = null
	var runtime_perk_choice_active := false
	var runtime_perk_feedback_active := false

	func is_runtime_perk_choice_active(_module_getter: Callable) -> bool:
		return runtime_perk_choice_active

	func is_runtime_perk_feedback_active(_module_getter: Callable) -> bool:
		return runtime_perk_feedback_active

	func is_character_debug_picker_open(_module_getter: Callable) -> bool:
		return _is_open(character_debug_picker)

	func is_perk_debug_picker_open(_module_getter: Callable) -> bool:
		return _is_open(perk_debug_picker)

	func is_stage_debug_picker_open(_module_getter: Callable) -> bool:
		return _is_open(stage_debug_picker)

	func is_weather_debug_picker_open(_module_getter: Callable) -> bool:
		return _is_open(weather_debug_picker)

	func is_lingpet_debug_picker_open(_module_getter: Callable) -> bool:
		return _is_open(lingpet_debug_picker)

	func is_mythic_management_menu_open(_module_getter: Callable) -> bool:
		return _is_open(mythic_item_runtime, "is_debug_management_menu_open")

	func is_active_item_debug_spawn_menu_open(_module_getter: Callable) -> bool:
		if active_item_runtime != null and active_item_runtime.has_method("is_debug_spawn_menu_open"):
			return bool(active_item_runtime.is_debug_spawn_menu_open())
		return active_item_debug_open

	func is_character_info_active(_module_getter: Callable) -> bool:
		if character_info != null and character_info.has_method("is_active"):
			return bool(character_info.is_active())
		return character_info_active

	func _is_open(value: Object, method_name: String = "is_open") -> bool:
		if value != null and value.has_method(method_name):
			return bool(value.call(method_name))
		return false


class FakeActiveItemRuntime:
	extends RefCounted

	var open := false
	var draw_calls := 0
	var close_calls := 0

	func draw_debug_spawn_menu(_canvas: CanvasItem, _view_size: Vector2, _owner: Object = null) -> void:
		draw_calls += 1

	func close_debug_spawn_menu() -> void:
		open = false
		close_calls += 1

	func is_debug_spawn_menu_open() -> bool:
		return open


class FakeBallSpeedDebug:
	extends RefCounted

	var active := false
	var draw_calls := 0
	var close_calls := 0

	func is_active() -> bool:
		return active

	func draw(_canvas: CanvasItem, _owner: Object, _view_size: Vector2, _registry: Object) -> void:
		draw_calls += 1

	func close() -> void:
		active = false
		close_calls += 1


class FakeCharacterInfo:
	extends RefCounted

	var active := false
	var close_calls := 0
	var update_calls := 0
	var update_result := false

	func is_active() -> bool:
		return active

	func close(_from_input: bool = false) -> void:
		active = false
		close_calls += 1

	func update(_delta: float) -> bool:
		update_calls += 1
		return update_result


class FakeOverlay:
	extends RefCounted

	var open := false
	var close_calls := 0

	func is_open() -> bool:
		return open

	func close() -> void:
		open = false
		close_calls += 1


class FakeRuntimePerkState:
	extends RefCounted

	var update_calls := 0
	var update_with_perf_calls := 0

	func update(_delta: float, _view_size: Vector2, _owner: Object = null, _registry: Object = null) -> void:
		update_calls += 1

	func update_with_perf(
		_delta: float,
		_view_size: Vector2,
		_owner: Object = null,
		_registry: Object = null,
		perf_logger: Object = null
	) -> void:
		update_with_perf_calls += 1
		if perf_logger != null and perf_logger.has_method("begin_sample") and perf_logger.has_method("finish_sample"):
			var sample_start: int = int(perf_logger.begin_sample())
			perf_logger.finish_sample("process.runtime_perk.fake", sample_start)


class FakeMythicDebug:
	extends RefCounted

	var open := false
	var close_calls := 0

	func is_debug_management_menu_open() -> bool:
		return open

	func close_debug_management_menu() -> void:
		open = false
		close_calls += 1


class FakeOwner:
	extends RefCounted

	var player_customization_debug_overlay_enabled := false
	var redraw_count := 0

	func queue_redraw() -> void:
		redraw_count += 1


class FakeCachedRegistry:
	extends RefCounted

	var cached: Dictionary = {}
	var cached_requests: Array[String] = []

	func get_cached_instance(key: String) -> Object:
		cached_requests.append(key)
		var value: Variant = cached.get(key, null)
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null


class FakeLazyModuleGetter:
	extends RefCounted

	var perf_logger: Object = null
	var modal_gate: Object = BattleSceneModalGateController.new()
	var created_keys: Array[String] = []

	func get_module(key: String) -> Object:
		created_keys.append(key)
		if key == "battle_perf_logger":
			return perf_logger
		if key == "battle_scene_modal_gate_controller":
			return modal_gate
		return null


func _init() -> void:
	OS.set_environment("PINGFIGHTER_BATTLE_PERF_CLEAN_CAPTURE", "0")
	_verify_closed_overlay_checks_are_cached_only()
	_verify_closed_debug_overlays_do_not_draw()
	_verify_open_debug_overlays_are_timed()
	_verify_runtime_perk_update_receives_perf_logger()
	_verify_character_info_idle_redraw_is_opt_in()
	_verify_lingpet_debug_idle_redraw_is_static()
	_verify_clean_capture_closes_debug_overlays()
	OS.set_environment("PINGFIGHTER_BATTLE_PERF_CLEAN_CAPTURE", "0")

	if _failures.is_empty():
		print("battle_scene_overlay_frame_perf_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_closed_overlay_checks_are_cached_only() -> void:
	var controller := BattleSceneOverlayFrameController.new()
	var perf_logger := FakePerfLogger.new()
	var lazy_getter := FakeLazyModuleGetter.new()
	lazy_getter.perf_logger = perf_logger
	var registry := FakeCachedRegistry.new()
	var owner := FakeOwner.new()

	var handled: bool = bool(controller.process_idle(0.016, owner, registry, Callable(lazy_getter, "get_module")))
	controller.draw(null, owner, registry, Callable(lazy_getter, "get_module"), Vector2(900.0, 720.0))

	_expect(not handled, "closed overlay fast path should return gameplay control")
	_expect(owner.redraw_count == 0, "closed overlay fast path should not queue redraw")
	_expect(
		lazy_getter.created_keys.count("battle_scene_modal_gate_controller") <= 2,
		"closed overlay process and draw should fetch the modal gate once per pass"
	)
	for key in [
		"runtime_perk_state",
		"character_debug_picker",
		"runtime_perk_debug_picker",
		"stage_debug_picker",
		"weather_debug_picker",
		"lingpet_debug_picker",
		"mythic_item_runtime",
		"active_item_runtime",
		"pause_menu_overlay",
		"character_info_overlay",
		"ball_speed_debug_overlay",
	]:
		_expect(registry.cached_requests.has(key), "closed overlay check should use cached lookup for %s" % key)
		_expect(not lazy_getter.created_keys.has(key), "closed overlay check should not lazy-create %s" % key)


func _verify_closed_debug_overlays_do_not_draw() -> void:
	var controller := BattleSceneOverlayFrameController.new()
	var perf_logger := FakePerfLogger.new()
	var modal_gate := FakeModalGate.new()
	var active_runtime := FakeActiveItemRuntime.new()
	var ball_speed := FakeBallSpeedDebug.new()
	_modules = {
		"battle_perf_logger": perf_logger,
		"battle_scene_modal_gate_controller": modal_gate,
		"active_item_runtime": active_runtime,
		"ball_speed_debug_overlay": ball_speed,
	}
	controller.draw(null, null, null, Callable(self, "_get_module"), Vector2(900.0, 720.0))
	_expect(active_runtime.draw_calls == 0, "closed active-item debug menu should not draw")
	_expect(ball_speed.draw_calls == 0, "inactive ball-speed debug overlay should not draw")
	_expect(not perf_logger.labels.has("draw.overlay.active_item_debug"), "closed active-item debug menu should not emit a draw label")
	_expect(not perf_logger.labels.has("draw.overlay.ball_speed_debug"), "inactive ball-speed debug overlay should not emit a draw label")


func _verify_open_debug_overlays_are_timed() -> void:
	var controller := BattleSceneOverlayFrameController.new()
	var perf_logger := FakePerfLogger.new()
	var modal_gate := FakeModalGate.new()
	var source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_overlay_frame_controller.gd")
	_expect(
		source.find("var draw_overlay_activity: String = _get_primary_draw_overlay_activity(passive_module_getter, modal_gate)") >= 0,
		"overlay draw should resolve the active draw branch once through the cached modal gate"
	)
	_expect(
		source.find("match draw_overlay_activity:") >= 0,
		"overlay draw should dispatch from the cached active branch instead of rescanning every modal gate"
	)
	modal_gate.active_item_debug_open = true
	var active_runtime := FakeActiveItemRuntime.new()
	var ball_speed := FakeBallSpeedDebug.new()
	ball_speed.active = true
	_modules = {
		"battle_perf_logger": perf_logger,
		"battle_scene_modal_gate_controller": modal_gate,
		"active_item_runtime": active_runtime,
		"ball_speed_debug_overlay": ball_speed,
	}
	controller.draw(null, null, null, Callable(self, "_get_module"), Vector2(900.0, 720.0))
	_expect(active_runtime.draw_calls == 1, "open active-item debug menu should draw once")
	_expect(ball_speed.draw_calls == 1, "active ball-speed debug overlay should draw once")
	_expect(perf_logger.labels.has("draw.overlay.active_item_debug"), "open active-item debug menu should emit a branch draw label")
	_expect(perf_logger.labels.has("draw.overlay.ball_speed_debug"), "active ball-speed debug overlay should emit a branch draw label")


func _verify_runtime_perk_update_receives_perf_logger() -> void:
	var controller := BattleSceneOverlayFrameController.new()
	var modal_gate := FakeModalGate.new()
	var perf_logger := FakePerfLogger.new()
	var runtime_state := FakeRuntimePerkState.new()
	var owner := FakeOwner.new()
	modal_gate.runtime_perk_choice_active = true
	_modules = {
		"battle_perf_logger": perf_logger,
		"battle_scene_modal_gate_controller": modal_gate,
		"runtime_perk_state": runtime_state,
	}

	var handled: bool = bool(controller.process_idle(0.016, owner, null, Callable(self, "_get_module")))
	_expect(handled, "active runtime perk choice should block the gameplay frame")
	_expect(
		bool(controller.has_blocking_activity(Callable(self, "_get_module"))),
		"active runtime perk choice should be exposed to draw-time cutin gates"
	)
	_expect(runtime_state.update_calls == 0, "runtime perk update should prefer the perf-aware path when available")
	_expect(runtime_state.update_with_perf_calls == 1, "runtime perk perf-aware update should run once")
	_expect(owner.redraw_count == 1, "runtime perk update should queue one redraw")
	_expect(perf_logger.labels.has("process.overlay.runtime_perk_update"), "runtime perk update should emit the outer process label")
	_expect(perf_logger.labels.has("process.runtime_perk.fake"), "runtime perk update should receive the perf logger for inner labels")


func _verify_character_info_idle_redraw_is_opt_in() -> void:
	var controller := BattleSceneOverlayFrameController.new()
	var modal_gate := FakeModalGate.new()
	var perf_logger := FakePerfLogger.new()
	var source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_overlay_frame_controller.gd")
	_expect(
		source.find("var process_overlay_activity: String = _get_blocking_process_overlay_activity(passive_module_getter, modal_gate)") >= 0,
		"overlay process should resolve the active blocking branch once through the cached modal gate"
	)
	_expect(
		source.find("match process_overlay_activity:") >= 0,
		"overlay process should dispatch from the cached active branch instead of rescanning every modal gate"
	)
	modal_gate.character_info_active = true
	var character_info := FakeCharacterInfo.new()
	var owner := FakeOwner.new()
	_modules = {
		"battle_perf_logger": perf_logger,
		"battle_scene_modal_gate_controller": modal_gate,
		"character_info_overlay": character_info,
	}

	var handled_idle: bool = bool(controller.process_idle(0.016, owner, null, Callable(self, "_get_module")))
	_expect(handled_idle, "active character info overlay should block the gameplay frame")
	_expect(character_info.update_calls == 1, "character info process should update once")
	_expect(owner.redraw_count == 0, "settled character info overlay should not redraw every idle frame")
	_expect(perf_logger.labels.has("process.overlay.character_info_update"), "character info update should emit a process sublabel")
	_expect(not perf_logger.labels.has("process.overlay.character_info_queue_redraw"), "settled character info overlay should not emit a redraw queue sublabel")

	character_info.update_result = true
	var handled_dirty: bool = bool(controller.process_idle(0.016, owner, null, Callable(self, "_get_module")))
	_expect(handled_dirty, "dirty character info overlay should still block the gameplay frame")
	_expect(character_info.update_calls == 2, "dirty character info process should update again")
	_expect(owner.redraw_count == 1, "dirty character info overlay should request one redraw")
	_expect(perf_logger.labels.has("process.overlay.character_info_queue_redraw"), "dirty character info overlay should emit a redraw queue sublabel")


func _verify_lingpet_debug_idle_redraw_is_static() -> void:
	var controller := BattleSceneOverlayFrameController.new()
	var modal_gate := FakeModalGate.new()
	var perf_logger := FakePerfLogger.new()
	var lingpet_debug := FakeOverlay.new()
	var owner := FakeOwner.new()
	lingpet_debug.open = true
	modal_gate.lingpet_debug_picker = lingpet_debug
	_modules = {
		"battle_perf_logger": perf_logger,
		"battle_scene_modal_gate_controller": modal_gate,
		"lingpet_debug_picker": lingpet_debug,
	}

	var handled: bool = bool(controller.process_idle(0.016, owner, null, Callable(self, "_get_module")))
	_expect(handled, "open lingpet debug overlay should still block the gameplay frame")
	_expect(owner.redraw_count == 0, "static lingpet debug overlay should not redraw every idle frame")
	_expect(perf_logger.labels.has("process.overlay.lingpet_debug_static"), "static lingpet debug overlay should emit a cheap idle label")
	_expect(not perf_logger.labels.has("process.overlay.lingpet_debug"), "static lingpet debug overlay should not emit the old redraw queue label")


func _verify_clean_capture_closes_debug_overlays() -> void:
	OS.set_environment("PINGFIGHTER_BATTLE_PERF_CLEAN_CAPTURE", "1")
	var controller := BattleSceneOverlayFrameController.new()
	var modal_gate := FakeModalGate.new()
	var character_debug := FakeOverlay.new()
	var perk_debug := FakeOverlay.new()
	var stage_debug := FakeOverlay.new()
	var weather_debug := FakeOverlay.new()
	var lingpet_debug := FakeOverlay.new()
	var mythic_debug := FakeMythicDebug.new()
	var active_runtime := FakeActiveItemRuntime.new()
	var ball_speed := FakeBallSpeedDebug.new()
	var character_info := FakeCharacterInfo.new()
	for overlay in [character_debug, perk_debug, stage_debug, weather_debug, lingpet_debug]:
		overlay.open = true
	mythic_debug.open = true
	active_runtime.open = true
	ball_speed.active = true
	character_info.active = true
	modal_gate.character_debug_picker = character_debug
	modal_gate.perk_debug_picker = perk_debug
	modal_gate.stage_debug_picker = stage_debug
	modal_gate.weather_debug_picker = weather_debug
	modal_gate.lingpet_debug_picker = lingpet_debug
	modal_gate.mythic_item_runtime = mythic_debug
	modal_gate.active_item_runtime = active_runtime
	modal_gate.ball_speed_debug = ball_speed
	modal_gate.character_info = character_info
	var owner := FakeOwner.new()
	owner.player_customization_debug_overlay_enabled = true
	_modules = {
		"battle_scene_modal_gate_controller": modal_gate,
		"character_debug_picker": character_debug,
		"runtime_perk_debug_picker": perk_debug,
		"stage_debug_picker": stage_debug,
		"weather_debug_picker": weather_debug,
		"lingpet_debug_picker": lingpet_debug,
		"mythic_item_runtime": mythic_debug,
		"active_item_runtime": active_runtime,
		"ball_speed_debug_overlay": ball_speed,
		"character_info_overlay": character_info,
	}

	var handled: bool = bool(controller.process_idle(0.016, owner, null, Callable(self, "_get_module")))
	OS.set_environment("PINGFIGHTER_BATTLE_PERF_CLEAN_CAPTURE", "0")
	_expect(not handled, "clean capture should return to gameplay after closing debug overlays")
	_expect(owner.redraw_count == 1, "clean capture should redraw once after closing overlays")
	_expect(not character_debug.open and character_debug.close_calls == 1, "clean capture should close character debug")
	_expect(not perk_debug.open and perk_debug.close_calls == 1, "clean capture should close perk debug")
	_expect(not stage_debug.open and stage_debug.close_calls == 1, "clean capture should close stage debug")
	_expect(not weather_debug.open and weather_debug.close_calls == 1, "clean capture should close weather debug")
	_expect(not lingpet_debug.open and lingpet_debug.close_calls == 1, "clean capture should close lingpet debug")
	_expect(not mythic_debug.open and mythic_debug.close_calls == 1, "clean capture should close mythic debug")
	_expect(not active_runtime.open and active_runtime.close_calls == 1, "clean capture should close active item debug")
	_expect(not ball_speed.active and ball_speed.close_calls == 1, "clean capture should close ball speed debug")
	_expect(not character_info.active and character_info.close_calls == 1, "clean capture should close character info")
	_expect(not owner.player_customization_debug_overlay_enabled, "clean capture should disable customization debug overlay")


func _get_module(key: String) -> Object:
	var value: Variant = _modules.get(key, null)
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		return value as Object
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
