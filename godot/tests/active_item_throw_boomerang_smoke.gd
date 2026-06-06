extends SceneTree

const ActiveItemThrowBoomerang := preload("res://scripts/items/active_item_throw_boomerang.gd")
const ActiveItemThrowController := preload("res://scripts/items/active_item_throw_controller.gd")
const GameAudio := preload("res://scripts/audio/game_audio.gd")

var _failures: Array[String] = []
var _collected_positions: Array[Vector2] = []
var _collected_radii: Array[float] = []
var _returned_items: Array = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 680.0)
	var boss_pos := Vector2(330.0, 25.0)
	var ball_pos := Vector2.ZERO
	var ball_active := false


class FakeRuntime:
	extends RefCounted

	func is_reinforced_boomerang_gauntlet_equipped() -> bool:
		return true

	func get_boomerang_launch_speed_multiplier() -> float:
		return 1.25

	func get_boomerang_homing_multiplier() -> float:
		return 1.4

	func get_boomerang_knockback_multiplier() -> float:
		return 1.5

	func get_boomerang_stun_multiplier() -> float:
		return 2.0


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_throw() -> void:
		calls.append("play_throw")

	func play_boomerang_loop() -> void:
		calls.append("play_boomerang_loop")

	func stop_boomerang_loop() -> void:
		calls.append("stop_boomerang_loop")

	func play_boomerang_hit() -> void:
		calls.append("play_boomerang_hit")

	func play_boomerang_break() -> void:
		calls.append("play_boomerang_break")

	func play_item_get() -> void:
		calls.append("play_item_get")


class FakeRegistry:
	extends RefCounted

	var audio := FakeAudio.new()
	var runtime: Object = null

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		if key == "mythic_item_runtime":
			return runtime
		return null


func _init() -> void:
	_verify_helper_spawns_boomerang()
	_verify_gauntlet_context_is_preserved()
	_verify_boss_hit_applies_status()
	_verify_returning_collects_and_finishes()
	_verify_particles_and_helpers()
	_verify_break_audio_matches_legacy()

	if _failures.is_empty():
		print("active_item_throw_boomerang_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_helper_spawns_boomerang() -> void:
	var helper: Object = ActiveItemThrowBoomerang.new()
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var pending_throw := {
		"start_position": Vector2(377.5, 705.0),
		"target_position": Vector2(430.0, controller.BOOMERANG_MAX_TRAVEL_Y),
	}

	helper.throw_boomerang(controller, FakeOwner.new(), pending_throw, registry)

	_expect(controller.get_boomerangs().size() == 1, "boomerang helper should append one projectile")
	var boomerang: Dictionary = controller.get_boomerangs()[0]
	_expect(_get_vector2(boomerang, "position") == Vector2(377.5, 705.0), "boomerang helper should preserve legacy start center")
	_expect(str(boomerang.get("phase", "")) == "outgoing", "boomerang helper should start outgoing")
	_expect(is_equal_approx(float(boomerang.get("target_boss_x", 0.0)), 430.0), "boomerang helper should preserve target boss x")
	_expect(_get_array(boomerang, "picked_items").is_empty(), "boomerang helper should seed picked items")
	_expect(_get_array(boomerang, "trail").size() == 1, "boomerang helper should seed trail")
	_expect(registry.audio.calls == ["play_throw", "play_boomerang_loop"], "boomerang helper should play throw and loop audio")


func _verify_gauntlet_context_is_preserved() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	registry.runtime = FakeRuntime.new()

	var context: Dictionary = controller._get_boomerang_gauntlet_context(registry)

	_expect(bool(context.get("equipped", false)), "boomerang gauntlet context should detect equipped runtime")
	_expect(is_equal_approx(float(context.get("launch_speed_multiplier", 0.0)), 1.25), "boomerang gauntlet context should preserve launch multiplier")
	_expect(is_equal_approx(float(context.get("homing_multiplier", 0.0)), 1.4), "boomerang gauntlet context should preserve homing multiplier")
	_expect(is_equal_approx(float(context.get("knockback_multiplier", 0.0)), 1.5), "boomerang gauntlet context should preserve knockback multiplier")
	_expect(is_equal_approx(float(context.get("stun_multiplier", 0.0)), 2.0), "boomerang gauntlet context should preserve stun multiplier")


func _verify_boss_hit_applies_status() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var registry := FakeRegistry.new()
	var boomerang := {
		"position": Vector2(380.0, 45.0),
		"hit_boss": false,
		"stun_multiplier": 2.0,
		"knockback_multiplier": 1.5,
	}

	controller._try_apply_boomerang_boss_hit(boomerang, Rect2(Vector2(330.0, 25.0), Vector2(100.0, 40.0)), registry)

	_expect(bool(boomerang.get("hit_boss", false)), "boomerang boss hit should latch hit flag")
	_expect(is_equal_approx(controller.grenade_boss_stun_timer_frames, controller.BOOMERANG_STUN_FRAMES * 2.0), "boomerang boss hit should apply stun multiplier")
	_expect(is_equal_approx(controller.grenade_boss_knockback_timer_frames, controller.BOOMERANG_KNOCKBACK_FRAMES), "boomerang boss hit should apply knockback timer")
	_expect(is_equal_approx(controller.grenade_boss_knockback_vel, controller.BOOMERANG_KNOCKBACK_POWER * 1.5), "boomerang boss hit should apply knockback multiplier")
	_expect(registry.audio.calls == ["play_boomerang_hit"], "boomerang boss hit should play hit audio")


func _verify_returning_collects_and_finishes() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var player_center := Vector2(owner.player_pos.x + 155.0 * 0.5, owner.player_pos.y + 25.0)
	var boomerangs: Array[Dictionary] = [{
		"position": player_center + Vector2(25.0, 0.0),
		"start_position": player_center + Vector2(25.0, 0.0),
		"phase": "returning",
		"travel_t": 1.0,
		"angle_degrees": 0.0,
		"return_wobble_phase": 0.0,
		"return_wobble_amp": 0.0,
		"return_wobble_freq": 0.1,
		"speed_jitter": 1.0,
		"gauntlet_equipped": false,
		"picked_items": [],
		"trail": [],
	}]
	controller.boomerangs = boomerangs
	_collected_positions.clear()
	_collected_radii.clear()
	_returned_items.clear()

	controller._update_boomerangs(
		owner,
		registry,
		1.0 / 60.0,
		Callable(self, "_collect_items_for_boomerang"),
		Callable(self, "_on_boomerang_returned")
	)

	_expect(controller.get_boomerangs().is_empty(), "returning boomerang near player should be removed")
	_expect(_collected_positions.size() == 1, "returning boomerang should collect nearby items")
	_expect(is_equal_approx(_collected_radii[0], controller.BOOMERANG_ITEM_PICKUP_RADIUS), "boomerang collection should use legacy radius")
	_expect(_returned_items.size() == 1, "returning boomerang should pass picked items to callback")
	_expect(str(_returned_items[0].get("name", "")) == "field_coin", "boomerang return should include collected item")
	_expect(registry.audio.calls == ["play_item_get", "stop_boomerang_loop"], "boomerang return should play return audio then stop loop")


func _verify_particles_and_helpers() -> void:
	var controller: Object = ActiveItemThrowController.new()
	var boomerang := {"trail": []}
	controller._add_boomerang_trail_point(boomerang, Vector2(1.0, 1.0))
	controller._add_boomerang_trail_point(boomerang, Vector2(2.0, 2.0))
	_expect(_get_array(boomerang, "trail").size() == 2, "boomerang trail helper should append points")
	_expect(controller._boomerang_intersects_rect(Vector2(10.0, 10.0), Rect2(Vector2(0.0, 0.0), Vector2(20.0, 20.0))), "boomerang intersection helper should preserve collision rect")

	controller._spawn_boomerang_break_particles(Vector2(100.0, 100.0))
	var first_particle: Dictionary = controller.get_boomerang_particles()[0]
	var first_age: float = float(first_particle.get("age", 0.0))

	controller._update_boomerang_particles(1.0 / 60.0)

	_expect(controller.get_boomerang_particles().size() == controller.BOOMERANG_BREAK_PARTICLE_COUNT, "boomerang break should spawn legacy particle count")
	_expect(float(controller.get_boomerang_particles()[0].get("age", 0.0)) > first_age, "boomerang particles should age")


func _verify_break_audio_matches_legacy() -> void:
	_expect(GameAudio.BOOMERANG_BREAK_SOUND_PATH == "res://assets/sounds/bonebreak.wav", "boomerang break should use the legacy BOOMERANG_BREAK bonebreak cue")


func _collect_items_for_boomerang(pos: Vector2, radius: float) -> Array:
	_collected_positions.append(pos)
	_collected_radii.append(radius)
	return [{"name": "field_coin"}]


func _on_boomerang_returned(_owner: Object, result: Dictionary, _registry: Object) -> void:
	for item in _get_array(result, "picked_items"):
		_returned_items.append(item)


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	if value is Array:
		return value
	return []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
