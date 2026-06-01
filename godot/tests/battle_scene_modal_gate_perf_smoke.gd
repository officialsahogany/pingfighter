extends SceneTree

const BattleSceneModalGateController := preload("res://scripts/core/battle_scene_modal_gate_controller.gd")

var _failures: Array[String] = []


class FakePerfLogger:
	extends RefCounted

	var labels: Array[String] = []

	func begin_sample() -> int:
		return Time.get_ticks_usec()

	func finish_sample(label: String, _start_usec: int) -> void:
		labels.append(label)


class FakeCachedModuleGetter:
	extends RefCounted

	var cached: Dictionary = {}
	var cached_keys: Array[String] = []
	var lazy_keys: Array[String] = []

	func _get_cached_module(key: String) -> Object:
		cached_keys.append(key)
		return _as_object(cached.get(key, null))

	func get_module(key: String) -> Object:
		lazy_keys.append(key)
		return _as_object(cached.get(key, null))

	func _as_object(value: Variant) -> Object:
		if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
			return value as Object
		return null


class FakePauseMenu:
	extends RefCounted

	var active := false

	func is_active() -> bool:
		return active


class FakeTreasureHuntRuntime:
	extends RefCounted

	var active := false

	func is_effect_active() -> bool:
		return active


func _init() -> void:
	_verify_closed_gate_uses_cached_lookup_without_lazy_creation()
	_verify_cached_pause_menu_still_blocks_physics()
	_verify_treasure_hunt_effect_blocks_physics()

	if _failures.is_empty():
		print("battle_scene_modal_gate_perf_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_closed_gate_uses_cached_lookup_without_lazy_creation() -> void:
	var modal_gate := BattleSceneModalGateController.new()
	var getter := FakeCachedModuleGetter.new()
	var perf_logger := FakePerfLogger.new()

	var blocked: bool = bool(modal_gate.should_block_battle_physics_with_perf(
		Callable(getter, "get_module"),
		perf_logger
	))

	_expect(not blocked, "closed modal gate should not block battle physics")
	_expect(getter.lazy_keys.is_empty(), "closed modal gate should not lazy-create overlay modules")
	for key in [
		"runtime_perk_state",
		"treasure_hunt_runtime",
		"character_debug_picker",
		"runtime_perk_debug_picker",
		"stage_debug_picker",
		"weather_debug_picker",
		"lingpet_debug_picker",
		"mythic_item_runtime",
		"active_item_runtime",
		"pause_menu_overlay",
		"character_info_overlay",
	]:
		_expect(getter.cached_keys.has(key), "closed modal gate should probe cached %s" % key)
	_expect(
		perf_logger.labels.has("physics.modal_gate.treasure_hunt"),
		"modal gate perf should expose the treasure-hunt branch"
	)
	_expect(
		perf_logger.labels.has("physics.modal_gate.pause_menu"),
		"modal gate perf should expose the pause-menu branch"
	)
	_expect(
		perf_logger.labels.has("physics.modal_gate.lingpet_debug"),
		"modal gate perf should expose the lingpet debug branch"
	)
	_expect(
		perf_logger.labels.has("physics.modal_gate.elixir_cinematic"),
		"modal gate perf should expose the final elixir branch when nothing blocks"
	)


func _verify_cached_pause_menu_still_blocks_physics() -> void:
	var modal_gate := BattleSceneModalGateController.new()
	var getter := FakeCachedModuleGetter.new()
	var pause_menu := FakePauseMenu.new()
	pause_menu.active = true
	getter.cached["pause_menu_overlay"] = pause_menu
	var perf_logger := FakePerfLogger.new()

	var blocked: bool = bool(modal_gate.should_block_battle_physics_with_perf(
		Callable(getter, "get_module"),
		perf_logger
	))

	_expect(blocked, "cached active pause menu should block battle physics")
	_expect(getter.lazy_keys.is_empty(), "active cached pause menu should still avoid lazy lookup")
	_expect(
		perf_logger.labels.has("physics.modal_gate.pause_menu"),
		"modal gate perf should sample the active pause-menu branch"
	)


func _verify_treasure_hunt_effect_blocks_physics() -> void:
	var modal_gate := BattleSceneModalGateController.new()
	var getter := FakeCachedModuleGetter.new()
	var treasure := FakeTreasureHuntRuntime.new()
	treasure.active = true
	getter.cached["treasure_hunt_runtime"] = treasure
	var perf_logger := FakePerfLogger.new()

	var blocked: bool = bool(modal_gate.should_block_battle_physics_with_perf(
		Callable(getter, "get_module"),
		perf_logger
	))

	_expect(blocked, "active treasure-hunt animation should block battle physics")
	_expect(getter.lazy_keys.is_empty(), "active treasure-hunt gate should still avoid lazy lookup")
	_expect(
		perf_logger.labels.has("physics.modal_gate.treasure_hunt"),
		"modal gate perf should sample the active treasure-hunt branch"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
