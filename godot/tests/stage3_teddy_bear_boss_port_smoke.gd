extends SceneTree

const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const TeddyBearBossState := preload("res://scripts/stages/stage3/stage3_teddy_bear_boss_state.gd")
const Stage3BossVariantSkillState := preload("res://scripts/stages/stage3/stage3_boss_variant_skill_state.gd")
const Stage3DashBlockInputProxy := preload("res://scripts/stages/stage3/stage3_dash_block_input_proxy.gd")

var failures: Array[String] = []


class FakeStatusEffectState:
	extends RefCounted
	var calls: Array = []

	func apply_status(target: String, status_id: String, duration: float, payload: Dictionary, source: String) -> void:
		calls.append({
			"target": target,
			"status_id": status_id,
			"duration": duration,
			"payload": payload,
			"source": source,
		})


class FakeAudio:
	extends RefCounted
	var calls: Array[String] = []

	func play_stage3_dollcurse() -> void:
		calls.append("cotton_throw")

	func play_stage3_chest_land() -> void:
		calls.append("cotton_bomb")

	func play_stage3_curse_explode() -> void:
		calls.append("cotton_explode")

	func play_lingpet_puppet_grab_pull() -> void:
		calls.append("hug_cast")

	func play_bomb_surprise_attach() -> void:
		calls.append("hug_land")

	func play_lingpet_puppet_grab_kiss() -> void:
		calls.append("heart_cast")

	func play_stage3_tail() -> void:
		calls.append("heart_slap")


class FakeFeedback:
	extends RefCounted
	var shake_count := 0

	func max_screen_shake(_duration: float, _intensity: float) -> void:
		shake_count += 1


class FakeInputReader:
	extends RefCounted
	var snapshot := {
		"left_pressed": true,
		"right_pressed": false,
		"down_pressed": true,
		"action_pressed": true,
		"direction": -1.0,
	}

	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_catalog_and_proxy()
	_verify_hit_gauge_and_negative_gates()
	_verify_cotton_throw_and_whiteout()
	_verify_cotton_bomb_slow_fragments_and_ghost_curve()
	_verify_deadly_hug_dash_lane()
	_verify_heart_beam_knockback_schedule()
	_verify_cleanup_and_hud()
	if failures.is_empty():
		print("stage3_teddy_bear_boss_port_smoke: ok")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_catalog_and_proxy() -> void:
	_expect(StageBossVariantCatalog.normalize_variant(3, "teddy_bear") == "teddy_bear", "Teddy must register as a Stage 3 variant")
	_expect(StageBossVariantCatalog.normalize_variant(2, "teddy_bear") == "cheongringwi", "Teddy must fail closed outside Stage 3")
	_expect(StageBossVariantCatalog.normalize_variant(3, "unknown") == "yeonmyo", "unknown Stage 3 variants must preserve Yeonmyo")
	var proxy := Stage3BossVariantSkillState.new()
	var result: Dictionary = proxy.update(0.0, _context(), {})
	_expect(proxy.active_variant == "teddy_bear", "Stage 3 proxy must route Teddy")
	_expect(result.is_empty(), "idle Teddy update should not invent owner mutations")
	var default_context := _context()
	default_context["stage_boss_variant"] = "yeonmyo"
	proxy.update(0.0, default_context, {})
	_expect(proxy.active_variant == "yeonmyo", "Stage 3 proxy must retain the headline route")
	_expect(not proxy.is_deadly_hug_dash_blocked(), "headline boss must not inherit Teddy's dash lock")
	var module_catalog := FileAccess.get_file_as_string("res://scripts/resources/gameplay_stage_module_catalog.gd")
	_expect(
		module_catalog.contains("\"path\": \"res://scripts/stages/stage3/stage3_boss_variant_skill_state.gd\""),
		"production module catalog must instantiate the Stage 3 variant proxy"
	)


func _verify_hit_gauge_and_negative_gates() -> void:
	var state := TeddyBearBossState.new()
	state.boss_special_gauge = 100.0
	state.cotton_throw_cooldown = 99.0
	state.cotton_bomb_cooldown = 99.0
	state.deadly_hug_cooldown = 99.0
	state.heart_beam_cooldown = 99.0
	var result: Dictionary = state.register_boss_hit(Vector2(4.0, -8.0), _context(), {})
	_expect(is_equal_approx(state.boss_special_gauge, 150.0), "boss contact must grant the legacy +50 gauge")
	_expect(is_equal_approx(float(result.get("stage3_boss_gauge_gain", 0.0)), 50.0), "boss contact result must report +50")
	_expect(not bool(result.get("teddy_cotton_throw_triggered", true)), "cooldown must block cotton throw")
	_expect(not bool(result.get("teddy_cotton_bomb_triggered", true)), "cooldown must block cotton bomb")
	_expect(not bool(result.get("teddy_deadly_hug_triggered", true)), "cooldown must block deadly hug")
	_expect(not bool(result.get("teddy_heart_beam_triggered", true)), "cooldown must block heart beam")
	var wrong_stage := _context()
	wrong_stage["current_stage"] = 2
	var before := state.boss_special_gauge
	_expect(state.register_boss_hit(Vector2.ZERO, wrong_stage, {}).is_empty(), "wrong-stage contact must fail closed")
	_expect(is_equal_approx(state.boss_special_gauge, before), "wrong-stage contact must not mutate Teddy gauge")


func _verify_cotton_throw_and_whiteout() -> void:
	var state := TeddyBearBossState.new()
	var audio := FakeAudio.new()
	var deps := {"audio": audio}
	var context := _context()
	state._activate_cotton_throw(deps)
	for _index in range(11):
		state.update(0.05, context, deps)
	_expect(state.cotton_throw_projectiles.size() >= 3 and state.cotton_throw_projectiles.size() <= 5, "cotton throw must launch 3..5 projectiles after 30f")
	_expect(audio.calls.has("cotton_throw"), "cotton throw must route audio")
	var projectile: Dictionary = state.cotton_throw_projectiles[0]
	projectile["pos"] = _player_center(context)
	projectile["vel"] = Vector2.ZERO
	state.cotton_throw_projectiles[0] = projectile
	state.update(1.0 / 60.0, context, deps)
	_expect(state.blackout_timer > 0.0, "cotton hit must start the 120f whiteout")
	state.update(1.0 / 60.0, context, deps)
	_expect(float(state.get_actor_draw_context().get("stage3_teddy_blackout_ratio", 0.0)) > 0.0, "whiteout must reach the production draw context")
	for _index in range(41):
		state.update(0.05, context, deps)
	_expect(state.blackout_timer <= 0.0, "whiteout must restore visibility after 120f")


func _verify_cotton_bomb_slow_fragments_and_ghost_curve() -> void:
	var state := TeddyBearBossState.new()
	var status_effect := FakeStatusEffectState.new()
	var audio := FakeAudio.new()
	var deps := {"status_effect_state": status_effect, "audio": audio}
	var context := _context()
	context["enraged_boss_active"] = true
	state._activate_cotton_bomb(deps)
	for _index in range(11):
		state.update(0.05, context, deps)
	_expect(state.cotton_bombs.size() >= 3 and state.cotton_bombs.size() <= 5, "cotton bomb must place 3..5 hazards after 30f")
	var bomb: Dictionary = state.cotton_bombs[0]
	bomb["pos"] = context["ball_pos"]
	state.cotton_bombs[0] = bomb
	var original_velocity: Vector2 = context["ball_vel"]
	var hit_result := state.update(1.0 / 60.0, context, deps)
	var curved_velocity: Vector2 = hit_result.get("ball_vel", original_velocity)
	_expect(not curved_velocity.is_equal_approx(original_velocity), "bomb-ball contact must apply the initial 0.4..0.7rad ghost kick")
	_expect(absf(curved_velocity.length() - original_velocity.length()) < 0.01, "initial ghost kick must preserve ball speed")
	_expect(state.cotton_fragments.size() == 4, "enraged bomb must split into exactly four fragments")
	_expect(audio.calls.has("cotton_explode"), "enraged bomb split must route explosion audio")
	var fragment: Dictionary = state.cotton_fragments[0]
	fragment["pos"] = _player_center(context)
	fragment["vel"] = Vector2.ZERO
	state.cotton_fragments[0] = fragment
	context["ball_active"] = false
	state.update(1.0 / 60.0, context, deps)
	_expect(state.cotton_slow_timer > 0.0, "cotton fragment-player contact must start the 120f slow")
	_expect(not status_effect.calls.is_empty(), "cotton slow must use the shared status consumer")
	if not status_effect.calls.is_empty():
		var call: Dictionary = status_effect.calls.back()
		_expect(is_equal_approx(float(call.get("payload", {}).get("multiplier", 0.0)), 0.5), "cotton slow multiplier must be x0.50")
		_expect(call.get("source", "") == "teddy_cotton_bomb", "cotton slow source must be stable")
	context["ball_active"] = true
	for _index in range(21):
		state.update(0.05, context, deps)
	_expect(state.ghost_curve_timer <= 0.0, "ghost curve must expire after 60f")


func _verify_deadly_hug_dash_lane() -> void:
	var state := TeddyBearBossState.new()
	var audio := FakeAudio.new()
	var context := _context()
	var deps := {"audio": audio}
	state._activate_deadly_hug(context, deps)
	for _index in range(32):
		state.update(0.05, context, deps)
	_expect(not state.deadly_hug_rush_active and state.deadly_hug_timer > 0.0, "deadly hug must rush at 6px/f and open the 300f zone at Y630")
	_expect(state.is_deadly_hug_dash_blocked(), "player inside the 350px hug zone must be dash-blocked")
	var input := FakeInputReader.new()
	var skill_proxy := Stage3BossVariantSkillState.new()
	skill_proxy.active_variant = "teddy_bear"
	skill_proxy.teddy_bear_state = state
	var dash_proxy := Stage3DashBlockInputProxy.new().configure(input, skill_proxy)
	var snapshot: Dictionary = dash_proxy.get_snapshot()
	_expect(not bool(snapshot.get("down_pressed", true)), "dedicated dash lane must suppress the down trigger inside hug")
	_expect(bool(snapshot.get("left_pressed", false)), "hug dash lock must preserve horizontal movement")
	_expect(bool(snapshot.get("action_pressed", false)), "hug dash lock must preserve non-dash action input")
	var outside_context := context.duplicate(true)
	outside_context["player_pos"] = Vector2(0.0, 680.0)
	state.update(0.0, outside_context, deps)
	_expect(not state.is_deadly_hug_dash_blocked(), "player outside the authored hug width must keep dash")
	_expect(bool(dash_proxy.get_snapshot().get("down_pressed", false)), "dash input must restore immediately outside the zone")
	for _index in range(101):
		state.update(0.05, outside_context, deps)
	_expect(state.deadly_hug_timer <= 0.0, "deadly hug must expire after 300f")
	_expect(audio.calls.has("hug_cast") and audio.calls.has("hug_land"), "deadly hug cast and landing audio must both route")


func _verify_heart_beam_knockback_schedule() -> void:
	var state := TeddyBearBossState.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var deps := {"audio": audio, "feedback": feedback}
	var context := _context()
	state._activate_heart_beam(context, deps)
	state.heart_projectile["pos"] = _player_center(context)
	state.heart_projectile["vel"] = Vector2.ZERO
	state.update(1.0 / 60.0, context, deps)
	_expect(state.heart_knockback_schedule.size() == 3, "heart hit must schedule exactly three knockbacks")
	var first_result := state.update(1.0 / 60.0, context, deps)
	_expect(first_result.has("player_pos"), "heart knockback frame 0 must update the real player position result")
	for _index in range(50):
		var result: Dictionary = state.update(1.0 / 60.0, context, deps)
		if result.has("player_pos"):
			context["player_pos"] = result["player_pos"]
	var applied_count := 0
	for value in state.heart_knockback_schedule:
		if value is Dictionary and bool(value.get("applied", false)):
			applied_count += 1
	_expect(applied_count == 3, "heart knockback must land at frames 0/24/48")
	_expect(audio.calls.count("heart_slap") == 3, "each of the three heart slaps must route feedback audio")
	_expect(feedback.shake_count == 3, "each heart slap must request screen shake")
	_expect(audio.calls.has("heart_cast"), "heart cast must route its launch audio")


func _verify_cleanup_and_hud() -> void:
	var state := TeddyBearBossState.new()
	state.boss_special_gauge = 275.0
	state.blackout_timer = 1.0
	state.cotton_bombs = [{"pos": Vector2.ONE}]
	state.deadly_hug_timer = 2.0
	var hud := state.get_hud_context()
	_expect(hud.get("stage3_boss_skill_hud_boss_name", "") == "테디베어", "HUD must use the player-facing Korean boss name")
	_expect(bool(hud.get("stage3_boss_skill_hud_show_boss_gauge", false)), "Teddy HUD must expose the shared boss gauge")
	_expect((hud.get("stage3_boss_skill_hud_skills", []) as Array).size() == 4, "Teddy HUD must list all four skills")
	state.reset_round()
	_expect(is_equal_approx(state.boss_special_gauge, 275.0), "round cleanup must preserve Teddy gauge like the legacy round route")
	_expect(state.blackout_timer <= 0.0 and state.cotton_bombs.is_empty() and state.deadly_hug_timer <= 0.0, "round cleanup must remove every detached Teddy hazard")
	state.reset()
	_expect(is_equal_approx(state.boss_special_gauge, 0.0), "match reset must clear Teddy gauge")


func _context() -> Dictionary:
	return {
		"current_stage": 3,
		"stage_boss_variant": "teddy_bear",
		"ball_active": true,
		"waiting_for_serve": false,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_pos": Vector2(380.0, 400.0),
		"ball_vel": Vector2(5.0, 8.0),
		"ball_size": 28.6,
	}


func _player_center(context: Dictionary) -> Vector2:
	return Vector2(context["player_pos"]) + Vector2(context["player_paddle_size"]) * 0.5


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
