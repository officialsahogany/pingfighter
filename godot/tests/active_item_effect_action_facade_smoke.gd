extends SceneTree

const ActiveItemEffectActionFacade := preload("res://scripts/items/active_item_effect_action_facade.gd")
const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemPickupEffectState := preload("res://scripts/items/active_item_pickup_effect_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var special_gauge := 100.0
	var special_gauge_max := 500.0
	var player_pos := Vector2(100.0, 680.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var runtime_paddle_scale := 1.0
	var ball_pos := Vector2(380.0, 360.0)
	var ball_vel := Vector2(3.0, -4.0)


func _init() -> void:
	_verify_action_facade()
	_verify_controller_delegates_action_facade()

	if _failures.is_empty():
		print("active_item_effect_action_facade_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_action_facade() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()
	var facade := ActiveItemEffectActionFacade.new()

	_expect(facade.apply_gauge_charge(
		controller,
		{"gauge_gain": 10.0},
		owner,
		null,
		controller._gauge_runtime,
		controller._effect_feedback
	), "action facade should apply gauge charge")
	_expect(is_equal_approx(owner.special_gauge, 110.0), "action facade gauge charge should mutate owner gauge")

	_expect(facade.activate_vitamin_pill(
		controller,
		owner,
		null,
		controller._state_applier,
		controller._player_center_reader,
		controller._effect_feedback
	), "action facade should activate vitamin pill")
	_expect(controller.vitamin_pill_active, "action facade should apply vitamin state")
	_expect(controller.vitamin_pill_player_center == Vector2(177.5, 705.0), "action facade should read owner center")

	var field_item := {
		"item_data": {"id": "magnet_field"},
		"position": Vector2(240.0, 300.0),
	}
	facade.trigger_pickup_effect(
		controller,
		field_item,
		"Magnet Field",
		Color.BLUE,
		null,
		controller._pickup_effect_state,
		controller._effect_feedback
	)
	_expect(controller.has_pickup_effect(), "action facade should trigger pickup popup")
	_expect(controller.pickup_particles.size() == ActiveItemPickupEffectState.BALLOON_POP_PARTICLE_COUNT, "action facade should spawn capped pickup particles")


func _verify_controller_delegates_action_facade() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var owner := FakeOwner.new()

	_expect(controller.activate_long_boost(owner, null), "controller should delegate long boost through action facade")
	_expect(controller.long_boost_active, "controller should keep long boost activation state")
	_expect(controller.apply_life_elixir({}, owner, null), "controller should delegate Life Elixir through action facade")
	_expect(is_equal_approx(owner.special_gauge, 500.0), "controller action facade should fill Life Elixir gauge")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
