extends SceneTree

const EffectsUpdateDriver := preload("res://scripts/core/battle_scene_effects_update_driver.gd")
const EffectsUpdateResultApplier := preload("res://scripts/core/battle_scene_effects_update_result_applier.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var current_stage := 2
	var selected_character_type := "viper"
	var drive_text_timer_frames := 12.0
	var special_gauge := 100.0
	var applied_marker := false


class FakeController:
	extends RefCounted

	var calls := 0
	var last_perf_logger: Object

	func update(_delta: float, context: Dictionary, deps: Dictionary) -> Dictionary:
		calls += 1
		last_perf_logger = deps.get("perf_logger", null)
		return {
			"drive_text_timer_frames": 77.0,
			"special_gauge": 300.0,
			"stage_seen": int(deps.get("stage_seen", 0)),
			"context_seen": bool(context.get("context_seen", false)),
		}


class FakeContextBuilder:
	extends RefCounted

	var effects_context_calls := 0
	var effects_deps_calls := 0
	var deps_stage := 0
	var deps_character := ""

	func build_effects_context(_owner: Object, _registry: Object) -> Dictionary:
		effects_context_calls += 1
		return {
			"context_seen": true,
			"current_stage": 2,
			"selected_character_type": "viper",
		}

	func build_effects_deps(
		_registry: Object,
		current_stage: int = 1,
		character_type: String = "",
		_stage1_boss_variant: String = "dalji"
	) -> Dictionary:
		effects_deps_calls += 1
		deps_stage = current_stage
		deps_character = character_type
		return {
			"stage_seen": current_stage,
			"character_seen": character_type,
		}


class FakeTrackingApplier:
	extends RefCounted

	var calls := 0

	func apply_effects_result(owner: Object, result: Dictionary) -> void:
		calls += 1
		owner.set("applied_marker", bool(result.get("context_seen", false)))
		owner.set("drive_text_timer_frames", float(result.get("drive_text_timer_frames", -1.0)))


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakePerfLogger:
	extends RefCounted

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(_label: String, _start_usec: int) -> void:
		pass


func _init() -> void:
	_verify_direct_apply()
	_verify_driver_uses_registered_applier()
	_verify_driver_fallback_applier()

	if _failures.is_empty():
		print("effects_update_result_applier_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_apply() -> void:
	var owner := FakeOwner.new()
	var applier: Object = EffectsUpdateResultApplier.new()

	applier.apply_effects_result(owner, {
		"drive_text_timer_frames": 33.0,
		"special_gauge": 250.0,
	})
	_expect(abs(owner.drive_text_timer_frames - 33.0) <= 0.001, "effects result should update Drive text timer")
	_expect(abs(owner.special_gauge - 250.0) <= 0.001, "effects result should update special gauge when provided")

	applier.apply_effects_result(owner, {"drive_text_timer_frames": 44.0})
	_expect(abs(owner.drive_text_timer_frames - 44.0) <= 0.001, "effects result should keep updating Drive text timer")
	_expect(abs(owner.special_gauge - 250.0) <= 0.001, "missing special gauge should not overwrite owner gauge")


func _verify_driver_uses_registered_applier() -> void:
	var owner := FakeOwner.new()
	var controller := FakeController.new()
	var context_builder := FakeContextBuilder.new()
	var tracking_applier := FakeTrackingApplier.new()
	var perf_logger := FakePerfLogger.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"battle_effects_update_controller": controller,
		"battle_update_context": context_builder,
		"battle_scene_effects_update_result_applier": tracking_applier,
		"battle_perf_logger": perf_logger,
	}
	var driver: Object = EffectsUpdateDriver.new()

	driver.update_effects(owner, registry, 0.25)

	_expect(controller.calls == 1, "effects driver should call controller")
	_expect(controller.last_perf_logger == perf_logger, "effects driver should pass the perf logger into effect deps")
	_expect(context_builder.effects_context_calls == 1, "effects driver should build effects context")
	_expect(context_builder.effects_deps_calls == 1 and context_builder.deps_stage == 2, "effects driver should build deps for owner stage")
	_expect(context_builder.deps_character == "viper", "effects driver should pass the selected character into deps")
	_expect(tracking_applier.calls == 1, "effects driver should route result through registered applier")
	_expect(owner.applied_marker, "registered effects applier should mutate owner")
	_expect(abs(owner.drive_text_timer_frames - 77.0) <= 0.001, "registered effects applier should receive controller result")


func _verify_driver_fallback_applier() -> void:
	var owner := FakeOwner.new()
	var controller := FakeController.new()
	var context_builder := FakeContextBuilder.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"battle_effects_update_controller": controller,
		"battle_update_context": context_builder,
	}
	var driver: Object = EffectsUpdateDriver.new()

	driver.update_effects(owner, registry, 0.25)

	_expect(abs(owner.drive_text_timer_frames - 77.0) <= 0.001, "effects driver fallback applier should update Drive timer")
	_expect(abs(owner.special_gauge - 300.0) <= 0.001, "effects driver fallback applier should update special gauge")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
