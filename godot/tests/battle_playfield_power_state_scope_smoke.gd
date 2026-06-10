extends SceneTree

const BattlePlayfieldSceneDrawer := preload("res://scripts/core/battle_playfield_scene_drawer.gd")

var _failures: Array[String] = []


class FakePowerState:
	extends RefCounted


class FakeCanvas:
	extends Node2D

	var ball_active := false
	var ball_visual_type := "pingpong"
	var ball_pos := Vector2.ZERO


class FakeDrawContextBuilder:
	extends RefCounted

	var character_type := "soldier"
	var last_power_state: Object = null

	func _init(initial_character_type: String) -> void:
		character_type = initial_character_type

	func build_scene_context(_canvas: CanvasItem, _shake_offset: Vector2, _registry: Object) -> Dictionary:
		return {
			"selected_character_type": character_type,
			"current_stage": 1,
			"width": 760.0,
			"height": 750.0,
			"game_offset": Vector2.ZERO,
			"game_size": Vector2(760.0, 750.0),
			"render_scale": 1.0,
		}

	func build_scene_deps(_registry: Object, _feedback: Object, power_state: Object, _draw_context: Dictionary = {}) -> Dictionary:
		last_power_state = power_state
		return {}

	func build_actor_context(_draw_context: Dictionary, _draw_deps: Dictionary, _perf_logger: Object = null) -> Dictionary:
		return {}

	func build_ball_effects_context(_draw_context: Dictionary, _draw_deps: Dictionary) -> Dictionary:
		return {}

	func build_ball_draw(_draw_context: Dictionary, _draw_deps: Dictionary) -> Dictionary:
		return {"should_draw": false}


class FakeRegistry:
	extends RefCounted

	var cached: Dictionary = {}
	var lazy_keys: Array[String] = []
	var cached_keys: Array[String] = []
	var draw_context_builder: FakeDrawContextBuilder

	func _init(character_type: String) -> void:
		draw_context_builder = FakeDrawContextBuilder.new(character_type)

	func get_instance(key: String) -> Object:
		lazy_keys.append(key)
		if key == "battle_draw_context":
			return draw_context_builder
		var value: Variant = cached.get(key, null)
		if value is Object:
			return value
		return null

	func get_cached_instance(key: String) -> Object:
		cached_keys.append(key)
		var value: Variant = cached.get(key, null)
		if value is Object:
			return value
		return null


func _init() -> void:
	_verify_non_smasher_draw_does_not_wake_smasher_power_state("soldier")
	_verify_non_smasher_draw_does_not_wake_smasher_power_state("viper")
	_verify_smasher_draw_uses_cached_power_state_only()

	if _failures.is_empty():
		print("battle_playfield_power_state_scope_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_non_smasher_draw_does_not_wake_smasher_power_state(character_type: String) -> void:
	var drawer := BattlePlayfieldSceneDrawer.new()
	var registry := FakeRegistry.new(character_type)
	var canvas := FakeCanvas.new()
	get_root().add_child(canvas)

	drawer.draw(canvas, registry, Vector2.ZERO, 760.0, 750.0, 80.0)

	_expect(
		not registry.lazy_keys.has("smasher_power_smash_state"),
		"%s playfield draw must not create Smasher power state" % character_type
	)
	_expect(
		not registry.cached_keys.has("smasher_power_smash_state"),
		"%s playfield draw must not even probe cached Smasher power state" % character_type
	)
	_expect(
		registry.draw_context_builder.last_power_state == null,
		"%s playfield deps should receive null power_state" % character_type
	)
	canvas.queue_free()


func _verify_smasher_draw_uses_cached_power_state_only() -> void:
	var drawer := BattlePlayfieldSceneDrawer.new()
	var registry := FakeRegistry.new("smasher")
	var power_state := FakePowerState.new()
	registry.cached["smasher_power_smash_state"] = power_state
	var canvas := FakeCanvas.new()
	get_root().add_child(canvas)

	drawer.draw(canvas, registry, Vector2.ZERO, 760.0, 750.0, 80.0)

	_expect(
		registry.cached_keys.has("smasher_power_smash_state"),
		"Smasher playfield draw should read the prewarmed cached power state"
	)
	_expect(
		not registry.lazy_keys.has("smasher_power_smash_state"),
		"Smasher playfield draw must not lazy-create the power state"
	)
	_expect(
		registry.draw_context_builder.last_power_state == power_state,
		"Smasher playfield deps should receive the cached power_state"
	)
	canvas.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
