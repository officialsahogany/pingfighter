extends SceneTree

const BattleSpawnOverlayDrawCoordinator := preload(
	"res://scripts/core/battle_spawn_overlay_draw_coordinator.gd"
)

var _failures: Array[String] = []
var _order: Array[String] = []


class FakeIntroFrame:
	extends RefCounted

	var overlay_active := true
	var restore_pillars := true
	var draw_calls := 0
	var order: Array[String] = []

	func is_ball_spawn_overlay_active(_module_getter: Callable) -> bool:
		order.append("active")
		return overlay_active

	func should_restore_ball_spawn_pillar_overlay(_module_getter: Callable) -> bool:
		order.append("restore")
		return restore_pillars

	func draw_ball_spawn_overlay(
		_canvas: CanvasItem,
		_owner: Object,
		_registry: Object,
		_module_getter: Callable,
		_view_size: Vector2
	) -> bool:
		draw_calls += 1
		if overlay_active:
			order.append("spawn")
		return overlay_active


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return 1

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


func _init() -> void:
	_verify_split_restore_order_and_labels()
	_verify_handoff_and_inactive_paths()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_spawn_overlay_draw_coordinator_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_split_restore_order_and_labels() -> void:
	_order = []
	var intro := FakeIntroFrame.new()
	intro.order = _order
	var perf_logger := FakePerfLogger.new()
	var canvas := Node2D.new()
	BattleSpawnOverlayDrawCoordinator.new().draw(
		canvas,
		RefCounted.new(),
		RefCounted.new(),
		Callable(self, "_missing_module"),
		{
			"draw_battle_scene": Callable(self, "_draw_battle"),
			"draw_battle_pillar_overlay": Callable(self, "_draw_pillar"),
		},
		intro,
		Vector2(1280.0, 720.0),
		perf_logger
	)
	_expect(
		_order == ["active", "restore", "battle", "spawn", "pillar"],
		"split spawn pass must draw battle, spawn, then restored pillar overlay"
	)
	_expect(perf_logger.labels.has("draw.frame.battle_scene"), "battle callback must keep its BattlePerf label")
	_expect(perf_logger.labels.has("draw.frame.ball_spawn_overlay"), "spawn overlay must keep its BattlePerf label")
	_expect(perf_logger.labels.has("draw.frame.pillar_overlay"), "pillar restore must keep its BattlePerf label")
	canvas.free()


func _verify_handoff_and_inactive_paths() -> void:
	_order = []
	var intro := FakeIntroFrame.new()
	intro.order = _order
	intro.restore_pillars = false
	var canvas := Node2D.new()
	var coordinator: Object = BattleSpawnOverlayDrawCoordinator.new()
	var callbacks := {
		"draw_battle_scene": Callable(self, "_draw_battle"),
		"draw_battle_pillar_overlay": Callable(self, "_draw_pillar"),
	}
	coordinator.draw(
		canvas,
		RefCounted.new(),
		RefCounted.new(),
		Callable(self, "_missing_module"),
		callbacks,
		intro,
		Vector2(1280.0, 720.0)
	)
	_expect(
		_order == ["active", "restore", "battle", "spawn"],
		"handoff spawn pass must skip pillar restoration"
	)

	_order = []
	intro.order = _order
	intro.overlay_active = false
	intro.restore_pillars = true
	coordinator.draw(
		canvas,
		RefCounted.new(),
		RefCounted.new(),
		Callable(self, "_missing_module"),
		callbacks,
		intro,
		Vector2(1280.0, 720.0)
	)
	_expect(_order == ["active", "battle"], "inactive overlay must keep the normal battle-only visible order")
	_expect(intro.draw_calls == 2, "inactive overlay must still receive the existing draw hook call")
	canvas.free()


func _verify_source_ownership() -> void:
	var coordinator_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_spawn_overlay_draw_coordinator.gd"
	)
	var frame_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_frame_controller.gd"
	)
	_expect(coordinator_source.contains("should_restore_ball_spawn_pillar_overlay"), "coordinator must own pillar-restore policy")
	_expect(coordinator_source.contains("draw.frame.pillar_overlay"), "coordinator must own spawn-pass performance labels")
	_expect(frame_source.contains("BattleSpawnOverlayDrawCoordinator.new()"), "frame controller must compose the spawn draw coordinator")
	_expect(frame_source.contains("SPAWN_OVERLAY_DRAW_CONTRACT"), "frame controller must retain source compatibility labels")
	_expect(frame_source.contains("_spawn_overlay_draw_coordinator.draw"), "frame controller must keep one spawn-pass delegation point")
	_expect(not frame_source.contains("var split_spawn_overlay_pass"), "frame controller must not retain split-pass policy")


func _draw_battle() -> void:
	_order.append("battle")


func _draw_pillar() -> void:
	_order.append("pillar")


func _missing_module(_key: String) -> Variant:
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
