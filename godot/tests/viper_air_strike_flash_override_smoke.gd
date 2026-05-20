extends SceneTree

const ViperAirStrikeFlashOverride := preload("res://scripts/core/viper_air_strike_flash_override.gd")
const ViperJetpackState := preload("res://scripts/characters/viper_jetpack_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_default_off()
	_verify_env_force_disable()
	_verify_flag_path_constant()

	if _failures.is_empty():
		print("viper_air_strike_flash_override_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_default_off() -> void:
	ViperAirStrikeFlashOverride.reset_cache_for_test()
	OS.set_environment(ViperAirStrikeFlashOverride.ENV_KEY, "0")
	_expect(not ViperAirStrikeFlashOverride.is_disabled(), "override should force off when env var is '0'")
	var state := ViperJetpackState.new()
	state.offset_y = -150.0
	var result: Dictionary = state.apply_air_strike_post_hit(
		Vector2(100.0, 0.0),
		0.0,
		25.0,
		{"ball_pos": Vector2(300.0, 400.0), "gauge_max": 500.0},
		{}
	)
	_expect(state.air_strike_flash_timer > 0.0, "with override off, a successful air strike should set the flash timer to the full duration")
	_expect(int(state.air_strike_flash_timer) == int(ViperJetpackState.AIR_STRIKE_FLASH_DURATION), "default flash duration constant should drive the timer value when override is off")
	_expect(str(result.get("paddle_hit_pulse_kind", "")) == ViperJetpackState.AIR_STRIKE_HIT_PULSE_KIND, "override off should leave the air strike pulse kind untouched")


func _verify_env_force_disable() -> void:
	ViperAirStrikeFlashOverride.reset_cache_for_test()
	OS.set_environment(ViperAirStrikeFlashOverride.ENV_KEY, "1")
	_expect(ViperAirStrikeFlashOverride.is_disabled(), "override should switch on when env var is '1'")
	var state := ViperJetpackState.new()
	state.offset_y = -150.0
	var result: Dictionary = state.apply_air_strike_post_hit(
		Vector2(100.0, 0.0),
		0.0,
		25.0,
		{"ball_pos": Vector2(300.0, 400.0), "gauge_max": 500.0},
		{}
	)
	_expect(is_equal_approx(state.air_strike_flash_timer, 0.0), "with override on, the flash timer should stay at zero so the renderer short-circuits")
	_expect(str(result.get("paddle_hit_pulse_kind", "")) == ViperJetpackState.AIR_STRIKE_HIT_PULSE_KIND, "override on should still expose the air strike pulse kind so the ball pulse routing is unchanged")
	_expect(float(result.get("special_gauge", 0.0)) > 0.0, "override on should still apply the gauge bonus so only the flash render is silenced, not the gameplay reward")
	OS.set_environment(ViperAirStrikeFlashOverride.ENV_KEY, "0")
	ViperAirStrikeFlashOverride.reset_cache_for_test()


func _verify_flag_path_constant() -> void:
	_expect(ViperAirStrikeFlashOverride.FLAG_PATH == "res://viper_disable_air_strike_flash.flag", "flag path constant should stay stable so external tooling can drop the flag")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
