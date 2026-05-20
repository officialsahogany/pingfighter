extends SceneTree

const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const ActiveItemThrowWindup := preload("res://scripts/items/active_item_throw_windup.gd")

var _failures: Array[String] = []
var _released_items: Array[Dictionary] = []
var _fallback_released_items: Array[Dictionary] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 680.0)
	var boss_pos := Vector2(330.0, 55.0)


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


func _init() -> void:
	_verify_windup_helper_releases_due_items()
	_verify_windup_helper_dispatches_release_by_item_name()
	_verify_windup_draw_context_and_pose()
	_verify_controller_delegates_windup_release()

	if _failures.is_empty():
		print("active_item_throw_windup_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_windup_helper_releases_due_items() -> void:
	var windup: Object = ActiveItemThrowWindup.new()
	var now_msec: int = Time.get_ticks_msec()
	var pending_throws: Array[Dictionary] = [
		{
			"item_name": "future",
			"start_msec": now_msec,
			"release_msec": now_msec + 1000,
		},
		{
			"item_name": "due",
			"start_msec": now_msec - 1000,
			"release_msec": now_msec - 1,
		},
	]
	_released_items.clear()

	var survivors: Array[Dictionary] = windup.update_pending_throws(
		pending_throws,
		FakeOwner.new(),
		FakeRegistry.new(),
		Callable(self, "_record_release")
	)

	_expect(survivors.size() == 1, "windup helper should keep only future throws")
	_expect(str(survivors[0].get("item_name", "")) == "future", "windup helper should preserve future throw data")
	_expect(_released_items.size() == 1, "windup helper should release due throws")
	_expect(str(_released_items[0].get("item_name", "")) == "due", "windup helper should release the due item")


func _verify_windup_helper_dispatches_release_by_item_name() -> void:
	var windup: Object = ActiveItemThrowWindup.new()
	_released_items.clear()
	_fallback_released_items.clear()

	windup.release_pending_throw(
		null,
		FakeOwner.new(),
		{"item_name": "soap"},
		FakeRegistry.new(),
		{"soap": Callable(self, "_record_release")},
		Callable(self, "_record_fallback_release")
	)
	windup.release_pending_throw(
		null,
		FakeOwner.new(),
		{"item_name": "unknown"},
		FakeRegistry.new(),
		{"soap": Callable(self, "_record_release")},
		Callable(self, "_record_fallback_release")
	)

	_expect(_released_items.size() == 1, "windup helper should dispatch known item through matching callback")
	_expect(str(_released_items[0].get("item_name", "")) == "soap", "windup helper should preserve known release item")
	_expect(_fallback_released_items.size() == 1, "windup helper should dispatch unknown item through fallback callback")
	_expect(
		str(_fallback_released_items[0].get("item_name", "")) == "unknown",
		"windup helper should preserve fallback release item"
	)


func _verify_windup_draw_context_and_pose() -> void:
	var windup: Object = ActiveItemThrowWindup.new()
	var now_msec: int = Time.get_ticks_msec()
	var pending_throws: Array[Dictionary] = [{
		"item_name": "flare",
		"start_msec": now_msec - 300,
		"release_msec": now_msec + 300,
	}]

	var context: Dictionary = windup.build_draw_context(pending_throws, 600, 30.0, -20.0)
	_expect(bool(context.get("active", false)), "windup draw context should be active while pending")
	_expect(str(context.get("item_name", "")) == "flare", "windup draw context should preserve item name")
	_expect(float(context.get("progress", 0.0)) > 0.35, "windup draw context should compute progress")
	_expect(float(context.get("progress", 0.0)) < 0.85, "windup draw context progress should stay bounded")
	_expect(is_equal_approx(windup.get_pose_angle_degrees(0.15, 30.0, -20.0), 15.0), "windup pose should ramp into hold angle")
	_expect(is_equal_approx(windup.get_pose_angle_degrees(0.50, 30.0, -20.0), 30.0), "windup pose should hold mid-windup")
	_expect(is_equal_approx(windup.get_pose_angle_degrees(1.0, 30.0, -20.0), -20.0), "windup pose should release at final angle")


func _verify_controller_delegates_windup_release() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var now_msec: int = Time.get_ticks_msec()
	var pending_throws: Array[Dictionary] = [{
		"item_name": "grenade",
		"start_msec": now_msec - 1000,
		"release_msec": now_msec - 1,
		"start_position": Vector2(360.0, 700.0),
		"target_position": Vector2(380.0, 100.0),
	}]
	controller.pending_throws = pending_throws

	controller._update_throw_windups(FakeOwner.new(), FakeRegistry.new())

	_expect(controller.get_pending_throws().is_empty(), "controller windup update should clear released throws")
	_expect(controller.get_grenades().size() == 1, "controller windup update should dispatch due grenade release")


func _record_release(_owner: Object, pending_throw: Dictionary, _registry: Object) -> void:
	_released_items.append(pending_throw)


func _record_fallback_release(_owner: Object, pending_throw: Dictionary, _registry: Object) -> void:
	_fallback_released_items.append(pending_throw)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
