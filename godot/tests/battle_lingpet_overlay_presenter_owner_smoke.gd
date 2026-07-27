extends SceneTree

const BattleLingpetOverlayPresenter := preload(
	"res://scripts/core/battle_lingpet_overlay_presenter.gd"
)

var _failures: Array[String] = []


class FakeRuntime:
	extends RefCounted

	var acquire_active := true
	var overflow_active := false

	func is_acquire_cutin_active() -> bool:
		return acquire_active

	func is_overflow_choice_active() -> bool:
		return overflow_active


class FakeHost:
	extends RefCounted

	var draw_calls := 0
	var last_runtime: Object = null
	var last_view_size := Vector2.ZERO

	func draw(_canvas: CanvasItem, runtime: Object, view_size: Vector2) -> void:
		draw_calls += 1
		last_runtime = runtime
		last_view_size = view_size


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return 1

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


class FakeRegistry:
	extends RefCounted

	var cached: Dictionary = {}
	var instances: Dictionary = {}
	var cached_reads: Array[String] = []
	var instance_reads: Array[String] = []

	func get_cached_instance(key: String) -> Variant:
		cached_reads.append(key)
		return cached.get(key, null)

	func get_instance(key: String) -> Variant:
		instance_reads.append(key)
		return instances.get(key, null)


func _init() -> void:
	_verify_cached_first_fallback_and_active_gates()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_lingpet_overlay_presenter_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_cached_first_fallback_and_active_gates() -> void:
	var presenter: Object = BattleLingpetOverlayPresenter.new()
	var canvas := Node2D.new()
	var runtime := FakeRuntime.new()
	var acquire_host := FakeHost.new()
	var overflow_host := FakeHost.new()
	var registry := FakeRegistry.new()
	registry.cached["lingpet_acquire_cutin_overlay_host"] = acquire_host
	registry.instances["lingpet_egg_runtime"] = runtime
	registry.instances["lingpet_overflow_choice_overlay_host"] = overflow_host
	var perf_logger := FakePerfLogger.new()
	var view_size := Vector2(1280.0, 720.0)

	presenter.draw_if_active(
		canvas,
		registry,
		view_size,
		"is_acquire_cutin_active",
		"lingpet_acquire_cutin_overlay_host",
		"draw.frame.lingpet_acquire_cutin",
		perf_logger
	)
	_expect(acquire_host.draw_calls == 1, "active acquire cut-in must draw exactly once")
	_expect(acquire_host.last_runtime == runtime and acquire_host.last_view_size == view_size, "draw must receive the resolved runtime and view size")
	_expect(registry.cached_reads.has("lingpet_egg_runtime"), "runtime resolution must check the cache first")
	_expect(registry.instance_reads.has("lingpet_egg_runtime"), "runtime resolution must fall back to normal instantiation")
	_expect(not registry.instance_reads.has("lingpet_acquire_cutin_overlay_host"), "a cached acquire host must not be instantiated again")

	runtime.acquire_active = false
	var acquire_instance_reads_before := registry.instance_reads.count("lingpet_acquire_cutin_overlay_host")
	presenter.draw_if_active(
		canvas,
		registry,
		view_size,
		"is_acquire_cutin_active",
		"lingpet_acquire_cutin_overlay_host",
		"draw.frame.lingpet_acquire_cutin",
		perf_logger
	)
	_expect(acquire_host.draw_calls == 1, "inactive acquire cut-in must not draw")
	_expect(
		registry.instance_reads.count("lingpet_acquire_cutin_overlay_host") == acquire_instance_reads_before,
		"inactive routes must not resolve their overlay host"
	)

	runtime.overflow_active = true
	presenter.draw_if_active(
		canvas,
		registry,
		view_size,
		"is_overflow_choice_active",
		"lingpet_overflow_choice_overlay_host",
		"draw.frame.lingpet_overflow_choice",
		perf_logger
	)
	_expect(overflow_host.draw_calls == 1, "active overflow choice must draw through normal-instance fallback")
	_expect(registry.cached_reads.has("lingpet_overflow_choice_overlay_host"), "overflow host resolution must check the cache first")
	_expect(registry.instance_reads.has("lingpet_overflow_choice_overlay_host"), "overflow host resolution must use normal fallback")
	_expect(perf_logger.labels.has("draw.frame.lingpet_acquire_cutin"), "acquire draw must keep its BattlePerf label")
	_expect(perf_logger.labels.has("draw.frame.lingpet_overflow_choice"), "overflow draw must keep its BattlePerf label")

	canvas.free()


func _verify_source_ownership() -> void:
	var presenter_source := FileAccess.get_file_as_string("res://scripts/core/battle_lingpet_overlay_presenter.gd")
	var frame_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(presenter_source.contains("func _resolve_registry_object"), "presenter must own cached-first registry fallback")
	_expect(frame_source.contains("BattleLingpetOverlayPresenter.new()"), "frame controller must compose the Lingpet overlay presenter")
	_expect(frame_source.contains("func _draw_lingpet_acquire_cutin_if_active"), "frame controller must retain the acquire compatibility facade")
	_expect(frame_source.contains("lingpet_acquire_cutin_overlay_host"), "acquire route key must remain visible in the frame facade")
	_expect(frame_source.contains("lingpet_overflow_choice_overlay_host"), "overflow route key must remain visible in the frame facade")
	_expect(not frame_source.contains("runtime = registry.get_cached_instance(\"lingpet_egg_runtime\")"), "frame controller must not duplicate runtime fallback policy")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
