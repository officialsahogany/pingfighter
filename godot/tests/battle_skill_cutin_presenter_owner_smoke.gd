extends SceneTree

const BattleSkillCutinPresenter := preload(
	"res://scripts/core/battle_skill_cutin_presenter.gd"
)

var _failures: Array[String] = []


class FakeSkillState:
	extends RefCounted

	var active := true
	var cutin_state: Object = null

	func is_cutin_active() -> bool:
		return active


class FakeCutinHost:
	extends RefCounted

	var draw_calls := 0
	var last_state: Object = null
	var last_view_size := Vector2.ZERO

	func draw(_canvas: CanvasItem, cutin_state: Object, view_size: Vector2) -> void:
		draw_calls += 1
		last_state = cutin_state
		last_view_size = view_size


class FakeOverlayFrame:
	extends RefCounted

	var blocking := false
	var received_getter := false

	func has_blocking_activity(module_getter: Callable) -> bool:
		received_getter = module_getter.is_valid()
		return blocking


class FakeRegistry:
	extends RefCounted

	var modules: Dictionary = {}
	var reads: Array[String] = []

	func get_cached_instance(key: String) -> Variant:
		reads.append(key)
		return modules.get(key, null)


class ModuleHolder:
	extends RefCounted

	var overlay_frame: Object = null

	func get_module(key: String) -> Variant:
		if key == "battle_scene_overlay_frame_controller":
			return overlay_frame
		return null


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return 1

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


func _init() -> void:
	_verify_priority_blocking_and_dispatch()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_skill_cutin_presenter_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_priority_blocking_and_dispatch() -> void:
	var presenter: Object = BattleSkillCutinPresenter.new()
	var canvas := Node2D.new()
	var smasher_cutin := RefCounted.new()
	var viper_cutin := RefCounted.new()
	var smasher := FakeSkillState.new()
	smasher.cutin_state = smasher_cutin
	var viper := FakeSkillState.new()
	viper.cutin_state = viper_cutin
	var cutin_host := FakeCutinHost.new()
	var registry := FakeRegistry.new()
	registry.modules = {
		"smasher_power_smash_state": smasher,
		"viper_skill_runtime": viper,
		"skill_cutin_overlay_host": cutin_host,
	}
	var overlay_frame := FakeOverlayFrame.new()
	var holder := ModuleHolder.new()
	holder.overlay_frame = overlay_frame
	var getter := Callable(holder, "get_module")
	var perf_logger := FakePerfLogger.new()
	var view_size := Vector2(1280.0, 720.0)

	presenter.draw_if_active(canvas, registry, getter, view_size, perf_logger)
	_expect(cutin_host.draw_calls == 1, "active skill cut-in must draw exactly once")
	_expect(cutin_host.last_state == smasher_cutin, "Smasher cut-in must keep priority over Viper")
	_expect(cutin_host.last_view_size == view_size, "cut-in host must receive the live view size")
	_expect(perf_logger.labels.has("draw.frame.skill_cutin"), "skill cut-in must keep its BattlePerf label")

	smasher.active = false
	presenter.draw_if_active(canvas, registry, getter, view_size, perf_logger)
	_expect(cutin_host.draw_calls == 2 and cutin_host.last_state == viper_cutin, "Viper cut-in must be selected when Smasher is inactive")

	overlay_frame.blocking = true
	var host_reads_before := registry.reads.count("skill_cutin_overlay_host")
	presenter.draw_if_active(canvas, registry, getter, view_size, perf_logger)
	_expect(cutin_host.draw_calls == 2, "blocking overlay must suppress skill cut-in drawing")
	_expect(overlay_frame.received_getter, "blocking overlay must receive the module getter")
	_expect(
		registry.reads.count("skill_cutin_overlay_host") == host_reads_before,
		"blocked cut-ins must not resolve the draw host"
	)

	canvas.free()


func _verify_source_ownership() -> void:
	var presenter_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_skill_cutin_presenter.gd"
	)
	var frame_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_frame_controller.gd"
	)
	_expect(presenter_source.contains("func _get_active_cutin_state"), "presenter must own active-state selection")
	_expect(presenter_source.contains("smasher_power_smash_state"), "presenter must own Smasher priority")
	_expect(presenter_source.contains("viper_skill_runtime"), "presenter must own Viper fallback")
	_expect(not presenter_source.contains("for module_key in ["), "draw hot path must not allocate a route Array")
	_expect(frame_source.contains("BattleSkillCutinPresenter.new()"), "frame controller must compose the skill cut-in presenter")
	_expect(frame_source.contains("func _draw_skill_cutin_if_active"), "frame controller must retain the compatibility facade")
	_expect(not frame_source.contains("func _get_active_skill_cutin_state"), "frame controller must not retain state-selection policy")
	_expect(not frame_source.contains("draw.frame.skill_cutin"), "frame controller must not retain skill cut-in performance policy")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
