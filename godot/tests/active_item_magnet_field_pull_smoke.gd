extends SceneTree

const ActiveItemEffectController := preload("res://scripts/items/active_item_effect_controller.gd")
const ActiveItemMagnetFieldPull := preload("res://scripts/items/active_item_magnet_field_pull.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_direct_pull_rules()
	_verify_controller_delegates_pull()

	if _failures.is_empty():
		print("active_item_magnet_field_pull_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_direct_pull_rules() -> void:
	var pull: Object = ActiveItemMagnetFieldPull.new()
	var context := {
		"last_hit_by": "boss",
		"ball_vel": Vector2(12.0, 0.0),
		"ball_pos": Vector2(100.0, 100.0),
		"player_pos": Vector2(160.0, 250.0),
		"player_paddle_size": Vector2(80.0, 40.0),
	}

	_expect(pull.apply_ball_pull(false, 1.0, context).is_empty(), "inactive magnet field should not pull the ball")
	var player_hit_context: Dictionary = context.duplicate()
	player_hit_context["last_hit_by"] = "player"
	_expect(pull.apply_ball_pull(true, 1.0, player_hit_context).is_empty(), "magnet field should only pull boss-returned balls")

	var result: Dictionary = pull.apply_ball_pull(true, 1.0, context)
	_expect(bool(result.get("magnet_field_pull_applied", false)), "active magnet field should apply pull inside radius")
	var next_vel: Vector2 = result.get("ball_vel", Vector2.ZERO)
	_expect(is_equal_approx(next_vel.length(), 12.0), "magnet pull should preserve current ball speed")
	_expect(next_vel.x < 12.0 and next_vel.y > 0.0, "magnet pull should bend velocity toward the player center")

	var far_context: Dictionary = context.duplicate()
	far_context["player_pos"] = Vector2(700.0, 700.0)
	_expect(pull.apply_ball_pull(true, 1.0, far_context).is_empty(), "magnet field should not pull outside radius")


func _verify_controller_delegates_pull() -> void:
	var controller: Object = ActiveItemEffectController.new()
	var context := {
		"last_hit_by": "boss",
		"ball_vel": Vector2(8.0, 0.0),
		"ball_pos": Vector2(100.0, 100.0),
		"player_pos": Vector2(160.0, 250.0),
		"player_paddle_size": Vector2(80.0, 40.0),
	}

	_expect(controller.apply_magnet_field_ball_pull(1.0, context).is_empty(), "inactive controller magnet field should not pull")
	controller.magnet_field_active = true
	var result: Dictionary = controller.apply_magnet_field_ball_pull(1.0, context)
	_expect(bool(result.get("magnet_field_pull_applied", false)), "controller should delegate active magnet pull")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
