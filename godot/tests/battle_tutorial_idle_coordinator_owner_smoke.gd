extends SceneTree

const BattleTutorialIdleCoordinator := preload(
	"res://scripts/core/battle_tutorial_idle_coordinator.gd"
)

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var redraw_calls := 0

	func request_battle_redraw() -> void:
		redraw_calls += 1


class FakeRegistry:
	extends RefCounted


class FakeThreeArgHint:
	extends RefCounted

	var call_name := ""
	var call_order: Array[String] = []
	var redraw := false
	var calls := 0

	func update(_delta: float, _owner: Object, _registry: Object) -> bool:
		calls += 1
		call_order.append(call_name)
		return redraw


class FakeFourArgHint:
	extends RefCounted

	var call_name := ""
	var call_order: Array[String] = []
	var redraw := false
	var calls := 0
	var received_getter := false

	func update(_delta: float, _owner: Object, _registry: Object, module_getter: Callable) -> bool:
		calls += 1
		call_order.append(call_name)
		received_getter = module_getter.is_valid()
		return redraw


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return 1

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


class FakeModuleHost:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		return modules.get(key, null)


func _init() -> void:
	_verify_update_order_signatures_and_redraws()
	_verify_missing_modules_are_noops()
	_verify_source_ownership()

	if _failures.is_empty():
		print("battle_tutorial_idle_coordinator_owner_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_update_order_signatures_and_redraws() -> void:
	var coordinator: Object = BattleTutorialIdleCoordinator.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var perf_logger := FakePerfLogger.new()
	var host := FakeModuleHost.new()
	var order: Array[String] = []

	var junior := FakeThreeArgHint.new()
	_setup_hint(junior, "junior", order, true)
	var skill := FakeFourArgHint.new()
	_setup_hint(skill, "skill", order, false)
	var commando := FakeFourArgHint.new()
	_setup_hint(commando, "commando", order, true)
	var jetpack := FakeFourArgHint.new()
	_setup_hint(jetpack, "jetpack", order, false)
	var practice := FakeFourArgHint.new()
	_setup_hint(practice, "practice", order, true)
	var active_item := FakeFourArgHint.new()
	_setup_hint(active_item, "active_item", order, false)
	var character_info := FakeFourArgHint.new()
	_setup_hint(character_info, "character_info", order, true)
	host.modules = {
		"junior_mika_tutorial_hint": junior,
		"skill_orb_tooltip_tutorial_hint": skill,
		"commando_firearm_tutorial_hint": commando,
		"viper_jetpack_tutorial_hint": jetpack,
		"viper_practice_mode": practice,
		"active_item_use_tutorial_hint": active_item,
		"character_info_tutorial_hint": character_info,
	}

	coordinator.update_all(
		1.0 / 60.0,
		owner,
		registry,
		Callable(host, "get_module"),
		perf_logger
	)

	_expect(
		order == ["junior", "skill", "commando", "jetpack", "practice", "active_item", "character_info"],
		"tutorial idle updates must preserve their established order"
	)
	_expect(owner.redraw_calls == 4, "each true hint update must preserve its own redraw request")
	_expect(junior.calls == 1, "junior Mika must use its three-argument update exactly once")
	for hint in [skill, commando, jetpack, practice, active_item, character_info]:
		_expect(hint.calls == 1 and hint.received_getter, "context-aware hints must receive the module getter exactly once")
	for label in [
		"process.frame.junior_mika_hint",
		"process.frame.skill_orb_tooltip_tutorial",
		"process.frame.commando_firearm_tutorial",
		"process.frame.viper_jetpack_tutorial",
		"process.frame.viper_practice_mode",
		"process.frame.active_item_use_tutorial",
		"process.frame.character_info_tutorial",
	]:
		_expect(perf_logger.labels.has(label), "missing tutorial BattlePerf label: %s" % label)


func _verify_missing_modules_are_noops() -> void:
	var coordinator: Object = BattleTutorialIdleCoordinator.new()
	var owner := FakeOwner.new()
	var perf_logger := FakePerfLogger.new()
	var host := FakeModuleHost.new()
	coordinator.update_all(0.016, owner, null, Callable(host, "get_module"), perf_logger)
	_expect(owner.redraw_calls == 0, "missing hints must not request redraws")
	_expect(perf_logger.labels.is_empty(), "missing hints must not create empty performance samples")


func _verify_source_ownership() -> void:
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/core/battle_tutorial_idle_coordinator.gd")
	var frame_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_frame_controller.gd")
	_expect(coordinator_source.contains("junior_mika_tutorial_hint"), "coordinator must own the junior Mika update route")
	_expect(coordinator_source.contains("character_info_tutorial_hint"), "coordinator must own the final character-info update route")
	_expect(frame_source.contains("BattleTutorialIdleCoordinator.new()"), "frame controller must compose the tutorial idle coordinator")
	_expect(not frame_source.contains("process.frame.junior_mika_hint"), "frame controller must not retain tutorial performance policy")
	_expect(not frame_source.contains("process.frame.character_info_tutorial"), "frame controller must not retain the final tutorial update branch")


func _setup_hint(hint: Object, call_name: String, order: Array[String], redraw: bool) -> void:
	hint.call_name = call_name
	hint.call_order = order
	hint.redraw = redraw


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
