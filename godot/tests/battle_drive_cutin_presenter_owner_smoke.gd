extends SceneTree

const BattleDriveCutinPresenter := preload(
	"res://scripts/core/battle_drive_cutin_presenter.gd"
)

var _failures: Array[String] = []


class FakeCutinState:
	extends RefCounted

	var active := true
	var progress := 0.42

	func is_active() -> bool:
		return active

	func get_progress() -> float:
		return progress


class FakePowerState:
	extends RefCounted

	var active := true
	var enraged := true
	var drive_cutin_state := FakeCutinState.new()

	func is_drive_cutin_active() -> bool:
		return active

	func is_drive_cutin_enraged() -> bool:
		return enraged


class FakeShieldState:
	extends RefCounted

	var cutin_state := FakeCutinState.new()


class FakeMagnumState:
	extends RefCounted

	var cutin_state := FakeCutinState.new()


class FakeOverdriveState:
	extends RefCounted

	var cutin_state := FakeCutinState.new()


class FakeCutinOverlayHost:
	extends RefCounted

	var drive_draw_calls := 0
	var shield_draw_calls := 0
	var magnum_draw_calls := 0
	var overdrive_draw_calls := 0
	var last_drive_state: Object = null
	var last_shield_state: Object = null
	var last_magnum_state: Object = null
	var last_overdrive_state: Object = null

	func draw_drive_cutin(_canvas: CanvasItem, state: Object, _view_size: Vector2) -> void:
		drive_draw_calls += 1
		last_drive_state = state

	func draw_shield_kiting_cutin(
		_canvas: CanvasItem,
		state: Object,
		_shield_state: Object,
		_view_size: Vector2
	) -> void:
		shield_draw_calls += 1
		last_shield_state = state

	func draw_magnum_grip_cutin(_canvas: CanvasItem, state: Object, _view_size: Vector2) -> void:
		magnum_draw_calls += 1
		last_magnum_state = state

	func draw_smasher_overdrive_cutin(_canvas: CanvasItem, state: Object, _view_size: Vector2) -> void:
		overdrive_draw_calls += 1
		last_overdrive_state = state

	func compute_drive_slide_px(progress: float, _view_width: float) -> float:
		return progress * 100.0

	func compute_shield_kiting_slide_px(progress: float, _view_width: float) -> float:
		return progress * 200.0

	func compute_magnum_grip_slide_px(progress: float, _view_width: float) -> float:
		return progress * 300.0

	func compute_smasher_overdrive_slide_px(progress: float, _view_width: float) -> float:
		return progress * 400.0

class FakeFxHost:
	extends Node2D

	var sync_calls := 0
	var last_state: Dictionary = {}
	var last_active := false

	func sync_state(state: Dictionary, next_active: bool) -> void:
		sync_calls += 1
		last_state = state
		last_active = next_active


class FakeOverlayFrame:
	extends RefCounted

	var blocked := false

	func has_blocking_activity(_module_getter: Callable) -> bool:
		return blocked


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return 1

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


class FakeRegistry:
	extends RefCounted

	var modules: Dictionary = {}

	func get_cached_instance(key: String) -> Variant:
		return modules.get(key, null)


class FakeModuleHost:
	extends RefCounted

	var overlay := FakeOverlayFrame.new()

	func get_module(key: String) -> Object:
		if key == "battle_scene_overlay_frame_controller":
			return overlay
		return null


func _init() -> void:
	_verify_drive_priority_shield_fallback_and_blocking()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_drive_cutin_presenter_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_drive_priority_shield_fallback_and_blocking() -> void:
	var presenter: Object = BattleDriveCutinPresenter.new()
	var canvas := Node2D.new()
	var fx_host := FakeFxHost.new()
	fx_host.name = "SmasherDriveCutinFxHost"
	canvas.add_child(fx_host)
	var power := FakePowerState.new()
	var shield := FakeShieldState.new()
	var magnum := FakeMagnumState.new()
	var overdrive := FakeOverdriveState.new()
	overdrive.cutin_state.active = false
	var cutin_host := FakeCutinOverlayHost.new()
	var registry := FakeRegistry.new()
	registry.modules = {
		"smasher_power_smash_state": power,
		"smasher_shield_kiting_state": shield,
		"smasher_magnum_grip_state": magnum,
		"smasher_overdrive_state": overdrive,
		"skill_cutin_overlay_host": cutin_host,
	}
	var module_host := FakeModuleHost.new()
	var getter := Callable(module_host, "get_module")
	var perf_logger := FakePerfLogger.new()
	var view_size := Vector2(1280.0, 720.0)

	presenter.draw_if_active(canvas, registry, getter, view_size, perf_logger)
	_expect(cutin_host.drive_draw_calls == 1, "active Drive must draw before an active Shield cut-in")
	_expect(cutin_host.shield_draw_calls == 0, "Drive priority must suppress Shield presentation")
	_expect(fx_host.last_active, "active Drive must enable the shared particle host")
	_expect(bool(fx_host.last_state.get("enraged", false)), "Drive enraged state must reach the particle host")
	_expect(is_equal_approx(float(fx_host.last_state.get("slide_px", 0.0)), 42.0), "Drive slide must use the Drive curve")
	var first_payload: Dictionary = fx_host.last_state

	power.active = false
	shield.cutin_state.progress = 0.25
	presenter.draw_if_active(canvas, registry, getter, view_size, perf_logger)
	_expect(cutin_host.shield_draw_calls == 1, "Shield must draw when Drive is inactive")
	_expect(fx_host.last_active, "active Shield must keep the shared particle host enabled")
	_expect(not bool(fx_host.last_state.get("enraged", true)), "Shield particles must not inherit Drive enraged tint")
	_expect(is_equal_approx(float(fx_host.last_state.get("slide_px", 0.0)), 50.0), "Shield slide must use the Shield curve")
	_expect(is_same(first_payload, fx_host.last_state), "FX sync payload must be reused instead of allocated every draw")

	shield.cutin_state.active = false
	magnum.cutin_state.progress = 0.30
	presenter.draw_if_active(canvas, registry, getter, view_size, perf_logger)
	_expect(cutin_host.magnum_draw_calls == 1, "Magnum Grip must draw when Drive and Shield are inactive")
	_expect(fx_host.last_active, "active Magnum Grip must keep the shared particle host enabled")
	_expect(not bool(fx_host.last_state.get("enraged", true)), "Magnum Grip particles must stay on the normal cyan tint")
	_expect(is_equal_approx(float(fx_host.last_state.get("slide_px", 0.0)), 90.0), "Magnum Grip slide must use its half-cutin curve")

	magnum.cutin_state.active = false
	power.active = true
	overdrive.cutin_state.active = true
	overdrive.cutin_state.progress = 0.35
	presenter.draw_if_active(canvas, registry, getter, view_size, perf_logger)
	_expect(cutin_host.overdrive_draw_calls == 1, "Smasher Overdrive must own the half cut-in when its launch overlaps Drive feedback")
	_expect(cutin_host.drive_draw_calls == 1, "Smasher Overdrive priority must suppress overlapping Drive presentation")
	_expect(fx_host.last_active, "active Smasher Overdrive must keep the shared particle host enabled")
	_expect(not bool(fx_host.last_state.get("enraged", true)), "Smasher Overdrive particles must use the normal blue-violet tint")
	_expect(is_equal_approx(float(fx_host.last_state.get("slide_px", 0.0)), 140.0), "Smasher Overdrive slide must use its own half-cutin curve")

	module_host.overlay.blocked = true
	presenter.draw_if_active(canvas, registry, getter, view_size, perf_logger)
	_expect(not fx_host.last_active, "a blocking overlay must immediately disable cut-in particles")
	_expect(cutin_host.drive_draw_calls == 1 and cutin_host.shield_draw_calls == 1 and cutin_host.magnum_draw_calls == 1 and cutin_host.overdrive_draw_calls == 1, "blocking must suppress immediate-mode cut-in draws")
	for label in [
		"draw.frame.drive_cutin",
		"draw.frame.shield_kiting_cutin",
		"draw.frame.magnum_grip_cutin",
		"draw.frame.smasher_overdrive_cutin",
		"draw.frame.drive_cutin_fx_sync",
	]:
		_expect(perf_logger.labels.has(label), "missing cut-in BattlePerf label: %s" % label)

	canvas.free()


func _verify_source_ownership() -> void:
	var presenter_source := FileAccess.get_file_as_string("res://scripts/core/battle_drive_cutin_presenter.gd")
	var frame_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(presenter_source.contains("var _fx_host: Node"), "presenter must own the particle host reference")
	_expect(presenter_source.contains("var _fx_sync_context: Dictionary"), "presenter must own a reusable FX sync payload")
	_expect(presenter_source.contains("smasher_magnum_grip_state"), "presenter must own the upper-left Magnum Grip route")
	_expect(presenter_source.contains("smasher_overdrive_state"), "partial presenter must own the restored Smasher Overdrive route")
	_expect(not presenter_source.contains("sync_state({"), "presenter must not allocate an inline Dictionary per draw")
	_expect(frame_source.contains("BattleDriveCutinPresenter.new()"), "frame controller must compose the cut-in presenter")
	_expect(not frame_source.contains("var _drive_cutin_fx_host:"), "frame controller must not retain the particle host reference")
	_expect(not frame_source.contains("func _get_or_create_drive_cutin_fx_host"), "frame controller must not retain host creation policy")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
