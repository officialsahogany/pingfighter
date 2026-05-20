extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemLifeElixirParticles := preload("res://scripts/items/active_item_life_elixir_particles.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var special_gauge := 125.0
	var player_pos := Vector2(100.0, 680.0)
	var player_paddle_width := 200.0
	var player_paddle_height := 40.0


func _init() -> void:
	_verify_direct_life_elixir_burst()
	_verify_controller_delegates_life_elixir_particles()

	if _failures.is_empty():
		print("active_item_life_elixir_particles_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_life_elixir_burst() -> void:
	seed(101)
	var helper: Object = ActiveItemLifeElixirParticles.new()
	var particles: Array[Dictionary] = []
	var center := Vector2(220.0, 710.0)

	helper.spawn_particles(particles, center)

	_expect(particles.size() == 22, "life elixir should spawn the reference particle count")
	for particle in particles:
		var position := _get_vector2(particle, "position", Vector2.ZERO)
		var velocity := _get_vector2(particle, "velocity", Vector2.ZERO)
		_expect(abs(position.x - center.x) <= 18.0, "life elixir particle x offset should stay near player center")
		_expect(abs(position.y - center.y) <= 14.0, "life elixir particle y offset should stay near player center")
		_expect(velocity.length() > 50.0, "life elixir particle should have burst velocity")
		_expect(float(particle.get("radius", 0.0)) >= 2.4, "life elixir particle should expose a draw radius")
		_expect(float(particle.get("lifetime", 0.0)) >= 0.42, "life elixir particle should expose lifetime")
		_expect(particle.get("color", null) is Color, "life elixir particle should expose color")


func _verify_controller_delegates_life_elixir_particles() -> void:
	seed(202)
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()

	_expect(controller.apply_life_elixir({}, owner, null), "controller should apply life elixir gauge gain")
	_expect(is_equal_approx(owner.special_gauge, 500.0), "life elixir should fill gauge through shared gauge charge")
	_expect(controller.pickup_particles.size() == 22, "controller should delegate life elixir particle burst")

	var center := Vector2(200.0, 700.0)
	var first_position := _get_vector2(controller.pickup_particles[0], "position", Vector2.ZERO)
	_expect(abs(first_position.x - center.x) <= 18.0, "controller life elixir particles should use player center x")
	_expect(abs(first_position.y - center.y) <= 14.0, "controller life elixir particles should use player center y")


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
