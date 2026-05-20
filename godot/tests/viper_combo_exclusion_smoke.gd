extends SceneTree

const PaddleBounceEventRouter := preload("res://scripts/ball/paddle_bounce_event_router.gd")
const SmasherComboState := preload("res://scripts/characters/smasher_combo_state.gd")


class FakeFeedback:
	var gauge_flash_count := 0

	func trigger_gauge_flash() -> void:
		gauge_flash_count += 1


func _init() -> void:
	var router: Object = PaddleBounceEventRouter.new()
	var combo_state: Object = SmasherComboState.new()
	var feedback := FakeFeedback.new()
	var deps := {
		"combo_state": combo_state,
		"feedback": feedback,
	}
	var smasher_context := {
		"selected_character_type": "smasher",
		"gauge_charge_per_hit": 10.0,
		"gauge_max": 500.0,
	}
	var viper_context := {
		"selected_character_type": "viper",
		"gauge_charge_per_hit": 10.0,
		"gauge_max": 500.0,
	}

	var gauge: float = router.register_player_hit(Vector2(320.0, 690.0), 0.0, false, false, 0.0, smasher_context, deps)
	_expect(int(combo_state.get_combo_count()) == 1, "Smasher hit should register combo count")
	_expect(abs(gauge - 10.0) < 0.01, "first Smasher hit should gain base gauge")

	gauge = router.register_player_hit(Vector2(322.0, 690.0), 0.0, false, false, gauge, smasher_context, deps)
	_expect(int(combo_state.get_combo_count()) == 2, "second Smasher hit should advance combo count")
	_expect(abs(gauge - 22.0) < 0.01, "second Smasher hit should apply combo gauge bonus")

	var before_combo: int = int(combo_state.get_combo_count())
	gauge = router.register_player_hit(Vector2(324.0, 690.0), 0.0, false, false, gauge, viper_context, deps)
	_expect(int(combo_state.get_combo_count()) == before_combo, "Viper hit should not touch Smasher combo count")
	_expect(abs(gauge - 32.0) < 0.01, "Viper hit should gain only base gauge, not Smasher combo bonus")
	_expect(feedback.gauge_flash_count == 3, "normal gauge flash should still trigger for Viper base gauge gain")

	print("viper_combo_exclusion_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
