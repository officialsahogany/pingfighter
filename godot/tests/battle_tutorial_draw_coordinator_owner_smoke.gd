extends SceneTree

const BattleTutorialDrawCoordinator := preload(
	"res://scripts/core/battle_tutorial_draw_coordinator.gd"
)

var _failures: Array[String] = []


class OwnerHint:
	extends RefCounted

	var calls := 0
	var received_owner: Object = null
	var received_view_size := Vector2.ZERO

	func draw(_canvas: CanvasItem, owner: Object, view_size: Vector2) -> void:
		calls += 1
		received_owner = owner
		received_view_size = view_size


class ContextHint:
	extends RefCounted

	var calls := 0
	var received_owner: Object = null
	var received_registry: Object = null
	var received_view_size := Vector2.ZERO

	func draw(
		_canvas: CanvasItem,
		owner: Object,
		registry: Object,
		view_size: Vector2
	) -> void:
		calls += 1
		received_owner = owner
		received_registry = registry
		received_view_size = view_size


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}
	var reads: Array[String] = []

	func get_module(key: String) -> Variant:
		reads.append(key)
		return modules.get(key, null)


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return 1

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


func _init() -> void:
	_verify_fixed_draw_order_signatures_and_labels()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_tutorial_draw_coordinator_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_fixed_draw_order_signatures_and_labels() -> void:
	var coordinator: Object = BattleTutorialDrawCoordinator.new()
	var canvas := Node2D.new()
	var owner := RefCounted.new()
	var registry := RefCounted.new()
	var junior := OwnerHint.new()
	var skill := ContextHint.new()
	var commando := ContextHint.new()
	var jetpack := ContextHint.new()
	var practice := ContextHint.new()
	var active_item := ContextHint.new()
	var character_info := ContextHint.new()
	var holder := ModuleHolder.new()
	holder.modules = {
		"junior_mika_tutorial_hint": junior,
		"skill_orb_tooltip_tutorial_hint": skill,
		"commando_firearm_tutorial_hint": commando,
		"viper_jetpack_tutorial_hint": jetpack,
		"viper_practice_mode": practice,
		"active_item_use_tutorial_hint": active_item,
		"character_info_tutorial_hint": character_info,
	}
	var perf_logger := FakePerfLogger.new()
	var view_size := Vector2(1280.0, 720.0)

	coordinator.draw_all(
		canvas,
		owner,
		registry,
		Callable(holder, "get_module"),
		view_size,
		perf_logger
	)

	var expected_order: Array[String] = [
		"junior_mika_tutorial_hint",
		"skill_orb_tooltip_tutorial_hint",
		"commando_firearm_tutorial_hint",
		"viper_jetpack_tutorial_hint",
		"viper_practice_mode",
		"active_item_use_tutorial_hint",
		"character_info_tutorial_hint",
	]
	_expect(holder.reads == expected_order, "tutorial draw routes must keep their fixed display order")
	_expect(junior.calls == 1, "junior Mika must use the owner-only draw signature")
	_expect(junior.received_owner == owner and junior.received_view_size == view_size, "junior Mika draw context must be preserved")
	for hint: ContextHint in [skill, commando, jetpack, practice, active_item, character_info]:
		_expect(hint.calls == 1, "context-aware tutorial routes must draw exactly once")
		_expect(
			hint.received_owner == owner
			and hint.received_registry == registry
			and hint.received_view_size == view_size,
			"context-aware tutorial draw arguments must be preserved"
		)
	for label in [
		"draw.frame.junior_mika_hint",
		"draw.frame.skill_orb_tooltip_tutorial",
		"draw.frame.commando_firearm_tutorial",
		"draw.frame.viper_jetpack_tutorial",
		"draw.frame.viper_practice_mode",
		"draw.frame.active_item_use_tutorial",
		"draw.frame.character_info_tutorial",
	]:
		_expect(perf_logger.labels.has(label), "missing tutorial draw BattlePerf label: %s" % label)

	canvas.free()


func _verify_source_ownership() -> void:
	var coordinator_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_tutorial_draw_coordinator.gd"
	)
	var frame_source := FileAccess.get_file_as_string(
		"res://scripts/core/battle_scene_frame_controller.gd"
	)
	_expect(coordinator_source.contains("junior_mika_tutorial_hint"), "coordinator must own the first tutorial draw route")
	_expect(coordinator_source.contains("character_info_tutorial_hint"), "coordinator must own the final tutorial draw route")
	_expect(frame_source.contains("BattleTutorialDrawCoordinator.new()"), "frame controller must compose the tutorial draw coordinator")
	_expect(frame_source.contains("TUTORIAL_DRAW_ROUTE_KEYS"), "frame controller must retain its source-wiring compatibility keys")
	_expect(not frame_source.contains("junior_mika_hint.draw"), "frame controller must not retain the junior tutorial draw branch")
	_expect(not frame_source.contains("draw.frame.character_info_tutorial"), "frame controller must not retain tutorial draw performance policy")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
