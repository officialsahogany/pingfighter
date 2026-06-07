extends SceneTree

const ViperSkillRuntime := preload("res://scripts/characters/viper_skill_runtime.gd")
const TooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const BossAiState := preload("res://scripts/ai/boss_ai_state.gd")


class FakeInput:
	var snapshot := {
		"left_pressed": false,
		"right_pressed": false,
		"up_pressed": false,
		"down_pressed": false,
		"direction": 0.0,
	}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeSkillConfig:
	var equipped := ["blade_rush", "nerve_strike"]

	func is_skill_equipped(skill_name: String) -> bool:
		return equipped.has(skill_name)

	func get_skill_cost(skill_name: String) -> float:
		match skill_name:
			"nerve_strike":
				return 90.0
			"blade_rush":
				return 200.0
			"dark_blade":
				return 150.0
		return 0.0

	func get_cooldown_seconds(skill_name: String) -> float:
		match skill_name:
			"nerve_strike":
				return 40.0
			"dark_blade":
				return 40.0
			"blade_rush":
				return 20.0
		return 0.0


class FakeSkillState:
	var triggered: Array[String] = []
	var cooldown_seconds: Dictionary = {}

	func trigger_configured_cooldown(skill_name: String, _now_msec: int, skill_config: Object) -> void:
		triggered.append(skill_name)
		cooldown_seconds[skill_name] = float(skill_config.get_cooldown_seconds(skill_name))

	func trigger_cooldown(skill_name: String, _now_msec: int, seconds: float) -> void:
		triggered.append(skill_name)
		cooldown_seconds[skill_name] = seconds

	func get_cooldown_remaining(_skill_name: String, _now_msec: int, _fallback_cooldown_seconds: float) -> float:
		return 0.0

	func get_configured_cooldown_remaining(_skill_name: String, _now_msec: int, _skill_config: Object) -> float:
		return 0.0


class FakePerkState:
	var levels := {"four_poisons": 0}
	var gold := 0

	func get_runtime_skill_level(skill_id: String) -> int:
		return int(levels.get(skill_id, 0))

	func award_gold(amount: int) -> int:
		gold += max(0, amount)
		return gold


class FakeOrbHud:
	var spins := 0

	func trigger_gauge_spin(_now_msec: int) -> void:
		spins += 1


class FakeFeedback:
	var shakes := 0

	func set_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1

	func max_screen_shake(_duration: float, _amount: float) -> void:
		shakes += 1


class FakeAudio:
	var moving := 0
	var attack := 0
	var show := 0
	var blade_spin_stopped := 0

	func play_viper_venom_moving() -> void:
		moving += 1

	func play_viper_venom_attack() -> void:
		attack += 1

	func play_viper_phantom_show() -> void:
		show += 1

	func stop_viper_blade_spin() -> void:
		blade_spin_stopped += 1


class FakeStatusState:
	var applications: Array[Dictionary] = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		var entry := {
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data,
			"source": source,
		}
		applications.append(entry)
		return entry


class FakeMythicRuntime:
	var spawn_count := 0
	var last_center := Vector2.ZERO

	func try_spawn_venom_mist_at_boss(boss_center: Vector2, _deps: Dictionary = {}, _force: bool = false) -> bool:
		spawn_count += 1
		last_center = boss_center
		return true


func _init() -> void:
	_test_activation_hit_freeze_confusion_and_mist()
	_test_miss_returns_without_slash_sound_or_vfx()
	_test_dark_blade_split_window()
	_test_edge_boss_arrival_ignores_player_clamp()
	_test_dual_glitch_clone_venom_slashes()
	_test_tooltip_four_poisons_bonus()
	print("viper_nerve_strike_port_smoke: ok")
	quit(0)


func _test_activation_hit_freeze_confusion_and_mist() -> void:
	var bundle: Dictionary = _make_bundle(5)
	var runtime: Object = bundle["runtime"]
	var input = bundle["input"]
	var skill_state = bundle["skill_state"]
	var perk_state = bundle["perk_state"]
	var audio = bundle["audio"]
	var status = bundle["status"]
	var mythic = bundle["mythic"]
	var config: Dictionary = _base_config()
	var player_pos := Vector2(302.5, 610.0)
	var gauge := 500.0
	_prime_air_blade_combo(runtime, 70.0)
	input.snapshot["up_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, bundle["deps"])
	_expect(bool(result.get("activated", false)), "Venom Edge should activate from the Air Blade follow-up window")
	_expect(str(result.get("skill_name", "")) == "nerve_strike", "activation should report nerve_strike")
	_expect_close(float(result.get("special_gauge", 0.0)), 410.0, "Venom Edge should spend 90 gauge")
	_expect(skill_state.triggered.back() == "nerve_strike", "Venom Edge should trigger its own cooldown")
	_expect_close(float(skill_state.cooldown_seconds.get("nerve_strike", 0.0)), 32.0, "Four Poisons Lv5 should reduce Venom Edge cooldown by 20%")
	_expect(audio.moving == 1, "Venom Edge dash start should play the moving cue")

	player_pos = _get_vector2(result, "player_pos", player_pos)
	gauge = float(result.get("special_gauge", gauge))
	input.snapshot["up_pressed"] = false
	for _i in range(30):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, bundle["deps"])
		player_pos = _get_vector2(result, "player_pos", player_pos)
	var snap: Dictionary = runtime.get_snapshot()
	_expect(bool(snap.get("nerve_strike_hit_confirmed", false)), "dash arrival should confirm a hit within 120px")
	var arrived_center: Vector2 = _get_vector2(snap, "nerve_strike_pos", Vector2.ZERO) + _get_player_paddle_size(config) * 0.5
	var boss_center: Vector2 = _get_boss_visual_center(config)
	_expect_close(arrived_center.x, boss_center.x, "Venom Edge dash arrival should align behind the boss on X")
	_expect_close(arrived_center.y, boss_center.y, "Venom Edge dash arrival should land behind the boss body instead of above its head")
	_expect(bool(snap.get("nerve_strike_freeze_active", false)), "hit cutscene should mark Venom Edge freeze active")
	_expect(audio.show == 1, "hit cutscene should play VIPER_SHOW")
	_expect(perk_state.gold == 60, "Venom Edge hit should award 60 skill gold exactly once")
	_expect(mythic.spawn_count == 1, "Venom Mist Gauntlet hook should spawn at hit entry")
	_expect_freezes_ball_and_boss(runtime, config)

	for _i in range(63):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, bundle["deps"])
		player_pos = _get_vector2(result, "player_pos", player_pos)
		runtime.update_effects(1.0, Time.get_ticks_msec(), _context_with_gauge(config, gauge), bundle["deps"])
	_expect(audio.attack == 1, "slash cue should fire at the 45% point, not at phase start")
	var strike_context: Dictionary = runtime.get_actor_draw_context()
	_expect(bool(strike_context.get("viper_venom_edge_strike_active", false)), "main Venom Edge hit should trigger the behind-boss strike sheet")
	_expect(status.applications.is_empty(), "confusion should wait until the slash cutscene finishes")

	for _i in range(75):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, bundle["deps"])
		player_pos = _get_vector2(result, "player_pos", player_pos)
		runtime.update_effects(1.0, Time.get_ticks_msec(), _context_with_gauge(config, gauge), bundle["deps"])
	var status_entry: Dictionary = status.applications.back()
	_expect(str(status_entry.get("status_id", "")) == "confusion", "slash end should apply boss confusion")
	_expect_close(float(status_entry.get("duration_frames", 0.0)), 255.0, "Four Poisons Lv5 should scale confusion to 255 frames")
	_expect(not bool(runtime.get_actor_draw_context().get("viper_venom_edge_strike_active", true)), "behind-boss strike sheet should auto-clear during the slash cutscene")
	# Python parity: the cutscene freeze is HELD through the return flight and only
	# released when Viper lands. It must NOT clear when the return phase begins.
	_expect(int(runtime.get_snapshot().get("nerve_strike_phase", -1)) == 2, "slash end should hand off to the return phase")
	_expect(bool(runtime.get_ball_collision_context().get("viper_nerve_strike_freeze_active", false)), "return phase should KEEP the cutscene freeze active (ball/boss stay frozen until landing)")
	_expect(audio.moving == 2, "return phase should play the moving cue again")
	_expect_freezes_ball_and_boss(runtime, config)
	# Advance all but the final frame of the return flight (return_hit_frames = 15);
	# the freeze must persist right up to the landing frame.
	for _i in range(14):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, bundle["deps"])
		player_pos = _get_vector2(result, "player_pos", player_pos)
	_expect(bool(runtime.get_ball_collision_context().get("viper_nerve_strike_freeze_active", false)), "freeze must persist through the entire return flight, including the frame before landing")
	_expect_freezes_ball_and_boss(runtime, config)
	# Final return frame lands Viper and releases the freeze + skill state together.
	result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, gauge, config, bundle["deps"])
	player_pos = _get_vector2(result, "player_pos", player_pos)
	_expect(not bool(runtime.get_snapshot().get("nerve_strike_active", true)), "Venom Edge should clear after the hit return phase")
	_expect(not bool(runtime.get_ball_collision_context().get("viper_nerve_strike_freeze_active", true)), "landing should release the cutscene freeze")


func _test_miss_returns_without_slash_sound_or_vfx() -> void:
	var bundle: Dictionary = _make_bundle(0)
	var runtime: Object = bundle["runtime"]
	var input = bundle["input"]
	var audio = bundle["audio"]
	var status = bundle["status"]
	var config: Dictionary = _base_config()
	var player_pos := Vector2(302.5, 610.0)
	_prime_air_blade_combo(runtime, 70.0)
	input.snapshot["up_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 500.0, config, bundle["deps"])
	player_pos = _get_vector2(result, "player_pos", player_pos)
	input.snapshot["up_pressed"] = false
	for _i in range(24):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 410.0, config, bundle["deps"])
		player_pos = _get_vector2(result, "player_pos", player_pos)
	config["boss_pos"] = Vector2(40.0, 25.0)
	for _i in range(6):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 410.0, config, bundle["deps"])
		player_pos = _get_vector2(result, "player_pos", player_pos)
	var snap: Dictionary = runtime.get_snapshot()
	_expect(not bool(snap.get("nerve_strike_hit_confirmed", true)), "boss dodge during the last dash segment should make Venom Edge miss")
	_expect(not bool(snap.get("nerve_strike_freeze_active", true)), "miss should not freeze the ball or boss")
	_expect(float(snap.get("nerve_strike_miss_text_timer", 0.0)) > 0.0, "miss should spawn MISS text")
	_expect(int(snap.get("nerve_strike_phase", -1)) == 2, "miss should skip the slash phase and return immediately")
	_expect(float(snap.get("nerve_strike_slash_vfx_frames", 0.0)) <= 0.0, "miss should not spawn Venom Edge slash VFX")
	_expect(audio.moving == 2, "miss return should play only the movement cue")
	for _i in range(9):
		result = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 410.0, config, bundle["deps"])
		player_pos = _get_vector2(result, "player_pos", player_pos)
	_expect(audio.attack == 0, "miss should not play the venomattack cue")
	_expect(status.applications.is_empty(), "miss should not apply confusion")
	_expect(not bool(runtime.get_snapshot().get("nerve_strike_active", true)), "miss should finish after the immediate return")


func _test_edge_boss_arrival_ignores_player_clamp() -> void:
	var bundle: Dictionary = _make_bundle(0)
	var runtime: Object = bundle["runtime"]
	var config: Dictionary = _base_config()
	config["boss_pos"] = Vector2(0.0, 25.0)
	runtime._start_nerve_strike(Vector2(302.5, 610.0), 500.0, config, bundle["deps"], Time.get_ticks_msec())
	var player_pos := Vector2(302.5, 610.0)
	for _i in range(30):
		var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, player_pos, 410.0, config, bundle["deps"])
		player_pos = _get_vector2(result, "player_pos", player_pos)
	var snap: Dictionary = runtime.get_snapshot()
	var arrived_pos: Vector2 = _get_vector2(snap, "nerve_strike_pos", Vector2.ZERO)
	var arrived_center: Vector2 = arrived_pos + _get_player_paddle_size(config) * 0.5
	var boss_center: Vector2 = _get_boss_visual_center(config)
	_expect_close(arrived_center.x, boss_center.x, "edge boss Venom Edge should align on X without player clamp")
	_expect_close(arrived_center.y, boss_center.y, "edge boss Venom Edge should align to the boss visual center on Y")
	_expect(arrived_pos.x < 0.0, "edge boss Venom Edge should allow Viper top-left to leave the playfield so her center reaches the boss")


func _test_dark_blade_split_window() -> void:
	var bundle: Dictionary = _make_bundle(0)
	var runtime: Object = bundle["runtime"]
	var input = bundle["input"]
	var skill_config = bundle["skill_config"]
	skill_config.equipped = ["blade_rush", "nerve_strike", "dark_blade"]
	var config: Dictionary = _base_config()
	_prime_air_blade_combo(runtime, 60.0)
	input.snapshot["up_pressed"] = true
	var result: Dictionary = runtime.try_activate_before_movement(1.0 / 60.0, Vector2(302.5, 610.0), 500.0, config, bundle["deps"])
	_expect(not bool(result.get("activated", false)), "both unlocked: before W+1.1s should not activate Venom Edge or Dark Blade")

	bundle = _make_bundle(0)
	runtime = bundle["runtime"]
	input = bundle["input"]
	skill_config = bundle["skill_config"]
	skill_config.equipped = ["blade_rush", "nerve_strike", "dark_blade"]
	_prime_air_blade_combo(runtime, 70.0)
	input.snapshot["up_pressed"] = true
	result = runtime.try_activate_before_movement(1.0 / 60.0, Vector2(302.5, 610.0), 500.0, config, bundle["deps"])
	_expect(str(result.get("skill_name", "")) == "nerve_strike", "both unlocked: W+1.1s-W+1.4s should belong to Venom Edge")

	bundle = _make_bundle(0)
	runtime = bundle["runtime"]
	input = bundle["input"]
	skill_config = bundle["skill_config"]
	skill_config.equipped = ["blade_rush", "nerve_strike", "dark_blade"]
	_prime_air_blade_combo(runtime, 90.0)
	input.snapshot["up_pressed"] = true
	result = runtime.try_activate_before_movement(1.0 / 60.0, Vector2(302.5, 610.0), 500.0, config, bundle["deps"])
	_expect(str(result.get("skill_name", "")) == "dark_blade", "both unlocked: W+1.4s-W+1.7s should hand off to Dark Blade")


func _test_dual_glitch_clone_venom_slashes() -> void:
	var bundle: Dictionary = _make_bundle(5)
	var runtime: Object = bundle["runtime"]
	var status = bundle["status"]
	var config: Dictionary = _base_config()
	runtime.dual_glitch_state = "active"
	runtime.dual_glitch_base_pos = Vector2(302.5, 610.0)
	runtime.dual_glitch_paddle_size = Vector2(155.0, 50.0)
	runtime.dual_glitch_clones = [
		{"side": -1, "hp": 4, "max_hp": 4, "collision_enabled": true, "evaporation_frames": -1.0},
		{"side": 1, "hp": 4, "max_hp": 4, "collision_enabled": true, "evaporation_frames": -1.0},
	]
	runtime._start_nerve_strike(Vector2(302.5, 610.0), 500.0, config, bundle["deps"], Time.get_ticks_msec())
	var snap: Dictionary = runtime.get_snapshot()
	_expect((snap.get("nerve_strike_clone_slashes", []) as Array).size() == 2, "Four Poisons Lv5 Dual Glitch should spawn two delayed Venom clone slashes")
	for _i in range(30):
		runtime.update_effects(1.0, Time.get_ticks_msec(), _context_with_gauge(config, 410.0), bundle["deps"])
	_expect(status.applications.size() > 0, "clone Venom slashes should apply/refresh confusion without awarding gold")
	_expect(int(bundle["perk_state"].gold) == 0, "clone Venom slashes should not grant extra gold")


func _test_tooltip_four_poisons_bonus() -> void:
	var perk_state := FakePerkState.new()
	perk_state.levels["four_poisons"] = 5
	var text: String = TooltipRenderer.new()._build_description_with_runtime_bonus(
		{"name": "nerve_strike", "description": "base"},
		{"runtime_perk_state": perk_state}
	)
	_expect(text.find("혼란 +70%") >= 0, "Venom Edge tooltip should show Four Poisons confusion scaling")
	_expect(text.find("쿨 -20%") >= 0, "Venom Edge tooltip should show Four Poisons cooldown scaling")


func _make_bundle(four_poisons_level: int) -> Dictionary:
	var runtime: Object = ViperSkillRuntime.new()
	var input := FakeInput.new()
	var skill_config := FakeSkillConfig.new()
	var skill_state := FakeSkillState.new()
	var perk_state := FakePerkState.new()
	perk_state.levels["four_poisons"] = four_poisons_level
	var orb := FakeOrbHud.new()
	var feedback := FakeFeedback.new()
	var audio := FakeAudio.new()
	var status := FakeStatusState.new()
	var mythic := FakeMythicRuntime.new()
	var deps := {
		"input_reader": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"runtime_perk_state": perk_state,
		"orb_hud_state": orb,
		"feedback": feedback,
		"audio": audio,
		"status_effect_state": status,
		"mythic_item_runtime": mythic,
	}
	return {
		"runtime": runtime,
		"input": input,
		"skill_config": skill_config,
		"skill_state": skill_state,
		"perk_state": perk_state,
		"orb": orb,
		"feedback": feedback,
		"audio": audio,
		"status": status,
		"mythic": mythic,
		"deps": deps,
	}


func _prime_air_blade_combo(runtime: Object, total_frames: float) -> void:
	runtime.blade_motion_active = true
	runtime.blade_motion_phase = 2
	runtime.blade_motion_total_frames = total_frames
	runtime.blade_motion_frames = max(0.0, total_frames - 36.0)
	runtime.blade_air_combo_window = total_frames >= 66.0
	runtime.blade_dark_mode = false
	runtime.blade_paddle_size = Vector2(155.0, 50.0)


func _expect_freezes_ball_and_boss(runtime: Object, config: Dictionary) -> void:
	var ball_pos := Vector2(260.0, 360.0)
	var ball_vel := Vector2(4.0, -6.0)
	var ball_context := {
		"selected_character_type": "viper",
		"ball_active": true,
		"ball_pos": ball_pos,
		"ball_vel": ball_vel,
		"ball_impact_boost": 1.0,
		"player_pos": Vector2(302.5, 610.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"boss_pos": config.get("boss_pos", Vector2.ZERO),
		"boss_vel": 5.0,
	}
	var ball_result: Dictionary = BallUpdateController.new().update(
		1.0 / 60.0,
		ball_context,
		{"viper_skill_runtime": runtime}
	)
	var snapshot: Dictionary = ball_result.get("snapshot", {})
	_expect(_get_vector2(snapshot, "ball_pos", Vector2.ZERO) == ball_pos, "Venom Edge freeze should hold ball position")
	_expect(_get_vector2(snapshot, "ball_vel", Vector2.ZERO) == ball_vel, "Venom Edge freeze should preserve ball velocity")

	var boss_context: Dictionary = runtime.get_boss_ai_context()
	boss_context.merge({
		"width": 760.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_paddle_width": 100.0,
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": ball_pos,
		"ball_vel": ball_vel,
	}, true)
	var boss_pos := Vector2(330.0, 25.0)
	var boss_result: Dictionary = BossAiState.new().update(1.0 / 60.0, boss_pos, 6.0, boss_context)
	_expect(_get_vector2(boss_result, "boss_pos", Vector2.ZERO) == boss_pos, "Venom Edge freeze should hold boss position")
	_expect(abs(float(boss_result.get("boss_vel", 1.0))) <= 0.01, "Venom Edge freeze should stop boss AI velocity")


func _base_config() -> Dictionary:
	return {
		"selected_character_type": "viper",
		"ball_active": true,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"player_floor_y": 680.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"boss_visual_center_y_offset": 25.0,
		"ball_pos": Vector2(430.0, 350.0),
		"ball_vel": Vector2(0.0, -8.0),
		"ball_size": 28.6,
		"ball_impact_boost": 1.0,
	}


func _get_player_paddle_size(config: Dictionary) -> Vector2:
	return Vector2(float(config.get("paddle_width", 155.0)), float(config.get("paddle_height", 50.0)))


func _get_boss_visual_center(config: Dictionary) -> Vector2:
	var boss_pos: Vector2 = _get_vector2(config, "boss_pos", Vector2.ZERO)
	var boss_width: float = float(config.get("boss_paddle_width", config.get("boss_width", 100.0)))
	var boss_height: float = float(config.get("boss_hitbox_height", config.get("boss_paddle_height", 50.0)))
	return boss_pos + Vector2(boss_width * 0.5, boss_height * 0.5 + float(config.get("boss_visual_center_y_offset", 0.0)))


func _context_with_gauge(config: Dictionary, gauge: float) -> Dictionary:
	var context: Dictionary = config.duplicate(true)
	context["special_gauge"] = gauge
	return context


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.01) -> void:
	_expect(abs(actual - expected) <= tolerance, "%s: got %.3f expected %.3f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
