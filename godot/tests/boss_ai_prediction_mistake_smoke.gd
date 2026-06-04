extends SceneTree

const BossAiPredictionState := preload("res://scripts/ai/boss_ai_prediction_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_context_mistake_chance_overrides_default()
	_verify_context_mistake_error_bounds_override_default()
	_verify_power_smash_halves_context_mistake_chance()
	_verify_junior_power_smash_forces_high_mistake_chance()

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


func _verify_context_mistake_error_bounds_override_default() -> void:
	var forced_prediction := _predict_with_chance(
		1.0,
		false,
		0,
		"mythic",
		0,
		{
			"boss_mistake_error_min": 0.0,
			"boss_mistake_error_max": 20.0,
			"boss_mistake_speed_scale": 4.5,
		}
	)
	var offset: float = abs(forced_prediction - 500.0)
	_expect(abs(offset - 20.0) <= 0.001, "Context mistake error bounds should cap forced misses at the configured maximum")


func _verify_power_smash_halves_context_mistake_chance() -> void:
	var mistakes := 0
	var trials := 160
	for index in range(trials):
		var prediction := _predict_with_chance(1.0, true, index)
		if abs(prediction - 500.0) >= 78.0:
			mistakes += 1
	_expect(mistakes > 30 and mistakes < 130, "Power-smash focus should halve a 100% context chance instead of forcing every prediction")


func _verify_junior_power_smash_forces_high_mistake_chance() -> void:
	var mistakes := 0
	var large_mistakes := 0
	var trials := 200
	for index in range(trials):
		var prediction := _predict_with_chance(0.0, true, index, "junior", 0)
		var offset: float = abs(prediction - 500.0)
		if offset >= 78.0:
			mistakes += 1
		if offset >= 170.0:
			large_mistakes += 1
	_expect(mistakes >= 135 and mistakes <= 185, "Junior power-smash should force roughly 80% boss prediction mistakes")
	_expect(large_mistakes == mistakes, "Junior power-smash mistakes should use the hard-to-guard error offset")


func _predict_with_chance(
	chance: float,
	focused_power_smash: bool,
	seed_value: int,
	ai_mode: String = "champion",
	combo_consumed: int = 3,
	extra_context: Dictionary = {}
) -> float:
	seed(seed_value)
	var state: Object = BossAiPredictionState.new()
	var context: Dictionary = {
		"ai_mode": ai_mode,
		"boss_mistake_chance": chance,
		"power_smashing_parabola_active": focused_power_smash,
		"power_smashing_combo_consumed": combo_consumed if focused_power_smash else 0,
	}
	context.merge(extra_context, true)
	return float(state.predict_future_x(
		Vector2(500.0, 500.0),
		Vector2(0.0, -5.0),
		1.0,
		0.0,
		2000.0,
		100.0,
		context
	))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
