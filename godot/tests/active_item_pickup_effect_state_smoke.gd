extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemPickupEffectState := preload("res://scripts/items/active_item_pickup_effect_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_pickup_effect()
	_verify_controller_delegates_pickup_effect()

	if _failures.is_empty():
		print("active_item_pickup_effect_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_pickup_effect() -> void:
	seed(55)
	var state: Object = ActiveItemPickupEffectState.new()
	var particles: Array[Dictionary] = []
	var field_item := {
		"item_data": {"id": "banana"},
		"position": Vector2(240.0, 300.0),
	}

	var effect: Dictionary = state.trigger_pickup_effect(field_item, "banana", Color.YELLOW, particles)
	_expect(state.has_pickup_effect(effect), "pickup effect should become active after trigger")
	_expect(effect.get("display_name", "") == "banana", "pickup effect should preserve display name")
	_expect(effect.get("position", Vector2.ZERO) == Vector2(240.0, 300.0), "pickup effect should start at field item position")
	_expect(particles.size() == ActiveItemPickupEffectState.BALLOON_POP_PARTICLE_COUNT, "pickup effect should spawn capped balloon pop particles")

	state.update_pickup_effect(effect, 1.0)
	_expect(effect.get("position", Vector2.ZERO) != Vector2(240.0, 300.0), "pickup effect should move toward HUD target")
	_expect(is_equal_approx(float(effect.get("alpha", 0.0)), 180.0 / 255.0), "pickup effect should keep full alpha before fade window")

	state.update_pickup_particles(particles, 0.1)
	_expect(float(particles[0].get("age", 0.0)) > 0.0, "pickup particles should age")

	state.update_pickup_effect(effect, 2.0)
	_expect(effect.is_empty(), "pickup effect should expire")
	state.update_pickup_particles(particles, 2.0)
	_expect(particles.is_empty(), "pickup particles should expire")

	for _i in range(4):
		state.trigger_pickup_effect(field_item, "banana", Color.YELLOW, particles)
	_expect(particles.size() <= ActiveItemPickupEffectState.MAX_PICKUP_PARTICLES, "rapid pickup effects should cap particle accumulation")


func _verify_controller_delegates_pickup_effect() -> void:
	seed(66)
	var controller: Object = ActiveItemEffectController.new()
	var field_item := {
		"item_data": {"id": "gauge_charge"},
		"position": Vector2(320.0, 420.0),
	}

	controller.trigger_pickup_effect(field_item, "energy charge", Color.CYAN, null)
	_expect(controller.has_pickup_effect(), "controller should delegate pickup effect activation")
	_expect(controller.pickup_particles.size() == ActiveItemPickupEffectState.BALLOON_POP_PARTICLE_COUNT, "controller should delegate capped pickup particles")

	controller.update(null, 2.1)
	_expect(not controller.has_pickup_effect(), "controller delegated pickup effect should expire")
	_expect(controller.pickup_particles.is_empty(), "controller delegated pickup particles should expire")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
