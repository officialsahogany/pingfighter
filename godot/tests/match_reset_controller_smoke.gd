extends SceneTree

const MatchFlowController := preload("res://scripts/core/match_flow_controller.gd")

var _failures: Array[String] = []
var _drive_reset_calls := 0
var _ball_reset_calls := 0


class FakeResettable:
	extends RefCounted

	var reset_calls := 0

	func reset() -> void:
		reset_calls += 1


class FakeRoundState:
	extends RefCounted

	var reset_game_calls := 0

	func reset_game() -> void:
		reset_game_calls += 1


class FakeOrbHudState:
	extends RefCounted

	var reset_gauge_value := -1
	var reset_dash_token_value := -1

	func reset_gauge(value: int) -> void:
		reset_gauge_value = value

	func reset_dash_tokens(value: int) -> void:
		reset_dash_token_value = value


class FakeActiveItemRuntime:
	extends RefCounted

	var reset_calls := 0

	func reset() -> void:
		reset_calls += 1

	func build_starting_slots() -> Array:
		return [{"item_id": "starter_ball"}]


class FakeDriveInputState:
	extends RefCounted

	var reset_cooldowns_calls := 0

	func reset_cooldowns() -> void:
		reset_cooldowns_calls += 1


class FakeSkillConfig:
	extends RefCounted

	var reset_runtime_skills_calls := 0

	func reset_runtime_skills() -> void:
		reset_runtime_skills_calls += 1


class FakeDashState:
	extends RefCounted

	var reset_full_value := -1

	func reset_full(value: int) -> void:
		reset_full_value = value

	func get_snapshot() -> Dictionary:
		return {"tokens": reset_full_value if reset_full_value > 0 else 2}


class FakeRuntimePerkDashAmp:
	extends RefCounted

	func get_runtime_skill_bonus(skill_id: String) -> int:
		return 2 if skill_id == "dash_amplification" else 0


class FakeMythicDashCapacity:
	extends RefCounted

	func get_dash_token_capacity(base_tokens: int, runtime_perk_state: Object = null) -> int:
		var bonus := 1
		if runtime_perk_state != null and runtime_perk_state.has_method("get_runtime_skill_bonus"):
			bonus += int(runtime_perk_state.get_runtime_skill_bonus("dash_amplification"))
		return max(1, base_tokens + bonus)


class FakeAudio:
	extends RefCounted

	var stopped: Dictionary = {}

	func stop_dash_delay() -> void:
		stopped["dash"] = true

	func stop_boomerang_loop() -> void:
		stopped["boomerang"] = true

	func stop_spider_mine_walk_loop() -> void:
		stopped["spider_mine"] = true

	func stop_plasma_charge() -> void:
		stopped["plasma_charge"] = true

	func stop_plasma_shock() -> void:
		stopped["plasma_shock"] = true

	func stop_warp_gate_loop() -> void:
		stopped["warp"] = true

	func stop_magnum_grip() -> void:
		stopped["magnum"] = true

	func stop_viper_jetpack_loop() -> void:
		stopped["viper_jetpack"] = true

	func stop_chaos_spear_blackhole_loop() -> void:
		stopped["chaos_blackhole"] = true

	func stop_ragnarok_shock_loop() -> void:
		stopped["ragnarok_shock"] = true

	func stop_electric_shock_loop() -> void:
		stopped["electric_shock"] = true

	func stop_stage2_quake_loop() -> void:
		stopped["quake"] = true


func _init() -> void:
	var scoreboard := FakeResettable.new()
	var score := FakeResettable.new()
	var round_state := FakeRoundState.new()
	var orb_hud := FakeOrbHudState.new()
	var active_hud := FakeResettable.new()
	var active_item := FakeActiveItemRuntime.new()
	var mythic := FakeResettable.new()
	var treasure := FakeResettable.new()
	var skill_a := FakeResettable.new()
	var skill_b := FakeResettable.new()
	var drive_input := FakeDriveInputState.new()
	var smasher_state := FakeResettable.new()
	var runtime_perk := FakeResettable.new()
	var optimus_energy := FakeResettable.new()
	var skill_config := FakeSkillConfig.new()
	var skill_runtime := FakeResettable.new()
	var dash := FakeDashState.new()
	var audio := FakeAudio.new()
	var stage_skill := FakeResettable.new()
	var stage_background := FakeResettable.new()
	var controller: Object = MatchFlowController.new()

	var result: Dictionary = controller.reset_game({
		"scoreboard_state": scoreboard,
		"score_state": score,
		"round_state": round_state,
		"orb_hud_state": orb_hud,
		"active_hud_state": active_hud,
		"active_item_runtime": active_item,
		"mythic_item_runtime": mythic,
		"treasure_hunt_runtime": treasure,
		"skill_states": [skill_a, skill_b],
		"drive_input_state": drive_input,
		"smasher_plasma_state": smasher_state,
		"runtime_perk_state": runtime_perk,
		"optimus_energy_state": optimus_energy,
		"skill_configs": [skill_config],
		"skill_runtimes": [skill_runtime],
		"dash_state": dash,
		"audio": audio,
		"stage1_dalji_whip_skill_state": stage_skill,
		"stage_background": stage_background,
	}, {
		"reset_drive_input": Callable(self, "_record_drive_reset"),
		"reset_ball": Callable(self, "_record_ball_reset"),
	})

	_expect(scoreboard.reset_calls == 1 and score.reset_calls == 1, "scoreboard and score state should reset")
	_expect(round_state.reset_game_calls == 1, "round flow state should reset game")
	_expect(orb_hud.reset_gauge_value == 0 and active_hud.reset_calls == 1, "HUD state should reset")
	_expect(active_item.reset_calls == 1 and result.get("active_item_slots", []).size() == 1, "active item runtime should reset and return starting slots")
	_expect(mythic.reset_calls == 1 and treasure.reset_calls == 1, "mythic and treasure runtimes should reset")
	_expect(skill_a.reset_calls == 1 and skill_b.reset_calls == 1, "registered skill states should reset")
	_expect(drive_input.reset_cooldowns_calls == 1, "drive input cooldowns should reset")
	_expect(smasher_state.reset_calls == 1 and runtime_perk.reset_calls == 1 and optimus_energy.reset_calls == 1, "character runtime states should reset")
	_expect(skill_config.reset_runtime_skills_calls == 1 and skill_runtime.reset_calls == 1, "skill configs and runtimes should reset")
	_expect(_drive_reset_calls == 1, "Drive input frame callback should run")
	_expect(dash.reset_full_value == 2 and orb_hud.reset_dash_token_value == 2, "dash state should reset and sync the two-token default")
	_expect(audio.stopped.size() == 12 and bool(audio.stopped.get("boomerang", false)) and bool(audio.stopped.get("spider_mine", false)) and bool(audio.stopped.get("chaos_blackhole", false)), "reset audio loops should stop")
	_expect(stage_skill.reset_calls == 1 and stage_background.reset_calls == 1, "stage states should reset")
	_expect(_ball_reset_calls == 1, "ball reset callback should run")
	_expect(float(result.get("special_gauge_max", 0.0)) == 500.0, "reset result should include gauge max")
	_expect(not bool(result.get("optimus_charge_active", true)), "reset result should clear Optimus manual charge")
	_expect(float(result.get("optimus_charge_hold_ratio", 1.0)) == 0.0, "reset result should clear Optimus manual charge progress")
	_expect(not bool(result.get("megingjord_equipped", true)), "reset result should clear mythic equip flag")

	var junior_orb_hud := FakeOrbHudState.new()
	var junior_dash := FakeDashState.new()
	var junior_result: Dictionary = controller.reset_game({
		"orb_hud_state": junior_orb_hud,
		"dash_state": junior_dash,
		"starting_dash_tokens": 2,
		"league_player_paddle_scale": 1.5,
	}, {})
	_expect(junior_dash.reset_full_value == 2 and junior_orb_hud.reset_dash_token_value == 2, "junior reset should fill and sync two starting dash tokens")
	_expect(is_equal_approx(float(junior_result.get("player_paddle_width", 0.0)), 232.5), "junior reset should restore the enlarged league paddle width")
	_expect(is_equal_approx(float(junior_result.get("player_paddle_visual_scale_override", 0.0)), 1.0), "junior reset should preserve normal player-image scale")

	var boosted_orb_hud := FakeOrbHudState.new()
	var boosted_dash := FakeDashState.new()
	controller.reset_for_stage_transition({
		"orb_hud_state": boosted_orb_hud,
		"dash_state": boosted_dash,
		"starting_dash_tokens": 2,
		"runtime_perk_state": FakeRuntimePerkDashAmp.new(),
		"mythic_item_runtime": FakeMythicDashCapacity.new(),
	}, {})
	_expect(boosted_dash.reset_full_value == 5 and boosted_orb_hud.reset_dash_token_value == 5, "stage transition dash reset should compose Junior, perk, and mythic capacity")

	var legacy_skill := FakeResettable.new()
	controller.reset_game({"skill_states": "legacy", "skill_state": legacy_skill}, {})
	_expect(legacy_skill.reset_calls == 1, "legacy single skill state fallback should still reset")

	if _failures.is_empty():
		print("match_reset_controller_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _record_drive_reset() -> void:
	_drive_reset_calls += 1


func _record_ball_reset() -> void:
	_ball_reset_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
