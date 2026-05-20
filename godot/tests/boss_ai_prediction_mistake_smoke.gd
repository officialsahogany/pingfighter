extends SceneTree

const BossAiPredictionState := preload("res://scripts/ai/boss_ai_prediction_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_context_mistake_chance_overrides_default()
	_verify_power_smash_halves_context_mistake_chance()

	if _failures.is_empty():
		print("boss_ai_prediction_mistake_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_context_mistake_chance_overrides_default() -> void:
	var clean_prediction := _predict_with_chance(0.0, false, 0)
	_expect(abs(clean_prediction - 500.0) <= 0.001, "0% context mistake chance should keep the exact prediction")

	var forced_prediction := _predict_with_chance(1.0, false, 0)
	_expect(abs(forced_prediction - 500.0) >= 78.0, "100% context mistake chance should apply the configured mistake offset")


func _verify_power_smash_halves_context_mistake_chance() -> void:
	var mistakes := 0
	var trials := 160
	for index in range(trials):
		var prediction := _predict_with_chance(1.0, true, index)
		if abs(prediction - 500.0) >= 78.0:
			mistakes += 1
	_expect(mistakes > 30 and mistakes < 130, "Power-smash focus should halve a 100% context chance instead of forcing every prediction")


func _predict_with_chance(chance: float, focused_power_smash: bool, seed_value: int) -> float:
	seed(seed_value)
	var state: Object = BossAiPredictionState.new()
	return float(state.predict_future_x(
		Vector2(500.0, 500.0),
		Vector2(0.0, -5.0),
		1.0,
		0.0,
		2000.0,
		100.0,
		{
			"boss_mistake_chance": chance,
			"power_smashing_parabola_active": focused_power_smash,
			"power_smashing_combo_consumed": 3 if focused_power_smash else 0,
		}
	))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
