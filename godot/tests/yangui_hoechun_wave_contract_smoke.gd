extends SceneTree

const YanguiHoechunRuntime := preload("res://scripts/items/mythic_item_yangui_hoechun_runtime.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const BallRoundController := preload("res://scripts/ball/ball_round_controller.gd")
const MatchRoundRestartController := preload("res://scripts/core/match_round_restart_controller.gd")
const MatchScoreEventController := preload("res://scripts/core/match_score_event_controller.gd")

const STEP_SEC := 1.0 / 120.0
const FIELD_WIDTH := 760.0
const PADDLE_CENTER_Y := 715.0
const FOCUSED_TEST_PATH := "res://tests/yangui_hoechun_wave_contract_smoke.gd"

var _failed := false


class FakeAudioRouter:
	var reflect_count := 0

	func play_yangui_hoechun_reflect_audio(_runtime: Object, _registry: Object, _speed: float) -> void:
		reflect_count += 1


class FakeRuntime:
	var audio_router := FakeAudioRouter.new()

	func _safe_owner_get(owner: Object, property_name: String, fallback: Variant) -> Variant:
		var value: Variant = owner.get(property_name)
		return fallback if value == null else value

	func _get_vector2(value: Variant) -> Vector2:
		return value if value is Vector2 else Vector2.ZERO


class FakeOwner:
	var ball_active := false
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2.ZERO
	var ball_radius := 14.3
	var ball_size := 28.6


class FakeRegistry:
	pass


class FakeMythicLifecycle:
	var yangui_hoechun_runtime: Object = YanguiHoechunRuntime.new()
	var cancel_score := false

	func reset_round(_registry: Object = null) -> void:
		yangui_hoechun_runtime.clear_runtime()

	func try_trigger_foul_whistle(_loss_type: String, _deps: Dictionary) -> bool:
		return cancel_score


class FakeScoreState:
	func score_for(scoring_side: String) -> Dictionary:
		return {
			"player_score": 1 if scoring_side == "player" else 0,
			"boss_score": 1 if scoring_side == "boss" else 0,
			"match_finished": false,
			"next_player_serves": scoring_side == "boss",
			"win_goal": 7,
			"deuce_mode": false,
			"deuce_goal": 9,
		}

	func would_score_finish(_scoring_side: String) -> bool:
		return false

	func get_snapshot() -> Dictionary:
		return {"deuce_mode": false, "player_score": 0, "boss_score": 0}


class FakeYanguiFieldRenderer:
	var draw_calls := 0

	func draw_effect(_canvas: CanvasItem, _shake_offset: Vector2, context: Dictionary) -> void:
		if bool(context.get("visible", false)):
			draw_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var reach_results := _seal_wall_reach_and_speed()
	var array_results := _seal_multi_wave_and_capacity()
	var consume_results := _seal_reflection_consumption_and_sweep()
	var dissipation_results := _seal_monotonic_dissipation()
	_seal_backstop()
	var lifecycle_results := _seal_lifecycle_routes()
	var draw_results := _seal_draw_wiring_and_lists()
	if _failed:
		push_error("yangui_hoechun_wave_contract_smoke: failed")
		quit(1)
		return
	print("[YanguiWaveReachSeal] center=%.3fs left_corner=%.3fs right_corner=%.3fs fronts=0/760" % [
		float(reach_results["center"]),
		float(reach_results["left_corner"]),
		float(reach_results["right_corner"]),
	])
	print("[YanguiWaveSpeedSeal] px_sec=%.3f phase_rad_sec=%.3f" % [
		float(reach_results["speed"]),
		float(reach_results["phase_speed"]),
	])
	print("[YanguiWaveArraySeal] active_cap=3 retained_fading=%d records_after_fade=%d no_teleport=true" % [
		int(array_results["retained_fading"]),
		int(array_results["records_after_fade"]),
	])
	print("[YanguiWaveConsumeSeal] reflections_per_wave=1 dissipate_sec=0.400 moving_ticks=%d/%d speed=%.1f/%.1f" % [
		int(consume_results["base_ticks"]),
		int(consume_results["fast_ticks"]),
		float(consume_results["base_speed"]),
		float(consume_results["fast_speed"]),
	])
	print("[YanguiDissipationSeal] before=%.3f after_retrigger=%.3f monotonic=true" % [
		float(dissipation_results["before"]),
		float(dissipation_results["after"]),
	])
	print("[YanguiWaveLifecycleSeal] score=%d serve=%d restart=%d reset=%d cancel=%d" % [
		int(lifecycle_results["score"]),
		int(lifecycle_results["serve"]),
		int(lifecycle_results["restart"]),
		int(lifecycle_results["reset"]),
		int(lifecycle_results["cancel"]),
	])
	print("[YanguiDrawWiringSeal] renderer_calls=%d visibility=%s ci_pre_push=lockstep" % [
		int(draw_results["renderer_calls"]),
		str(draw_results["visibility"]),
	])
	print("yangui_hoechun_wave_contract_smoke: ok")
	quit(0)


func _seal_wall_reach_and_speed() -> Dictionary:
	var fake_runtime := FakeRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var center_result := _run_until_both_walls(380.0, fake_runtime, owner, registry)
	var left_result := _run_until_both_walls(77.5, fake_runtime, owner, registry)
	var right_result := _run_until_both_walls(682.5, fake_runtime, owner, registry)
	_expect(_within(float(center_result["completed_sec"]), 2.80, 2.95), "center wave should reach both walls in about 2.9s")
	_expect(_within(float(left_result["completed_sec"]), 5.10, 5.30), "left-corner wave should reach the far wall in about 5.2s")
	_expect(_within(float(right_result["completed_sec"]), 5.10, 5.30), "right-corner wave should reach the far wall in about 5.2s")

	var speed_runtime: Object = YanguiHoechunRuntime.new()
	_start_wave(speed_runtime, Vector2(380.0, PADDLE_CENTER_Y))
	_advance(speed_runtime, fake_runtime, owner, registry, 1.0)
	var before := _single_wave(speed_runtime)
	_advance(speed_runtime, fake_runtime, owner, registry, 0.5)
	var after := _single_wave(speed_runtime)
	var measured_speed := (float(after["right_front_x"]) - float(before["right_front_x"])) / 0.5
	var measured_phase_speed := _phase_delta(float(before["phase"]), float(after["phase"])) / 0.5
	_expect(absf(measured_speed - 130.0) <= 0.05, "running wave speed should be 130 px/s")
	_expect(absf(measured_phase_speed - 2.38) <= 0.005, "ripple phase should also be slowed by 30%")
	_expect(float(before["right_alpha"]) >= 0.999 and float(after["right_alpha"]) >= 0.999, "traveling waves should not fade before wall contact")
	return {
		"center": center_result["completed_sec"],
		"left_corner": left_result["completed_sec"],
		"right_corner": right_result["completed_sec"],
		"speed": measured_speed,
		"phase_speed": measured_phase_speed,
	}


func _run_until_both_walls(
	origin_x: float,
	fake_runtime: FakeRuntime,
	owner: FakeOwner,
	registry: FakeRegistry
) -> Dictionary:
	var runtime: Object = YanguiHoechunRuntime.new()
	_start_wave(runtime, Vector2(origin_x, PADDLE_CENTER_Y))
	var elapsed := 0.0
	var left_reached := false
	var right_reached := false
	var completed_sec := -1.0
	while runtime.has_visible_effects() and elapsed < 6.5:
		_advance(runtime, fake_runtime, owner, registry, STEP_SEC)
		elapsed += STEP_SEC
		var contexts: Array[Dictionary] = runtime.get_debug_wave_contexts()
		if contexts.is_empty():
			continue
		var context: Dictionary = contexts[0]
		if bool(context["left_reached_wall"]):
			left_reached = true
			_expect(float(context["left_front_x"]) <= 0.001, "left branch must touch x<=0 before termination")
		if bool(context["right_reached_wall"]):
			right_reached = true
			_expect(float(context["right_front_x"]) >= FIELD_WIDTH - 0.001, "right branch must touch x>=760 before termination")
		if left_reached and right_reached and completed_sec < 0.0:
			completed_sec = elapsed
	_expect(left_reached and right_reached, "both branches must reach their own wall")
	_expect(completed_sec > 0.0, "wall completion time should be recorded")
	_expect(not runtime.has_visible_effects(), "wall dissipation should finish instead of leaving a timed ghost")
	return {"completed_sec": completed_sec}


func _seal_multi_wave_and_capacity() -> Dictionary:
	var fake_runtime := FakeRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var runtime: Object = YanguiHoechunRuntime.new()
	_start_wave(runtime, Vector2(260.0, PADDLE_CENTER_Y))
	_advance(runtime, fake_runtime, owner, registry, 0.8)
	var first_before := _single_wave(runtime)
	_start_wave(runtime, Vector2(420.0, PADDLE_CENTER_Y))
	var first_after := _context_for_id(runtime, int(first_before["wave_id"]))
	_expect(_as_vector2(first_after["origin"]).is_equal_approx(_as_vector2(first_before["origin"])), "retrigger must not teleport the existing wave origin")
	_expect(is_equal_approx(float(first_after["right_front_x"]), float(first_before["right_front_x"])), "retrigger must not rewind existing wave travel")

	runtime.clear_runtime()
	for origin_x in [180.0, 280.0, 380.0, 480.0, 580.0]:
		_start_wave(runtime, Vector2(origin_x, PADDLE_CENTER_Y))
	_expect(runtime.get_active_wave_count() == 3, "wave gameplay capacity should be capped at three")
	var contexts: Array[Dictionary] = runtime.get_debug_wave_contexts()
	_expect(contexts.size() == 5, "capacity eviction should retain every in-progress visual dissipation tail")
	var oldest: Dictionary = contexts[0]
	var second_oldest: Dictionary = contexts[1]
	_expect(bool(oldest["retired_by_cap"]), "oldest wave should enter capacity dissipation")
	_expect(bool(second_oldest["retired_by_cap"]), "second-oldest wave should also remain while capacity-dissipating")
	_expect(_as_vector2(oldest["origin"]).is_equal_approx(Vector2(180.0, PADDLE_CENTER_Y)), "capacity eviction must preserve the oldest origin while dissipating")
	_advance(runtime, fake_runtime, owner, registry, 0.2)
	oldest = _context_for_id(runtime, int(oldest["wave_id"]))
	second_oldest = _context_for_id(runtime, int(second_oldest["wave_id"]))
	_expect(_within(float(oldest["alpha"]), 0.45, 0.55), "capacity-evicted wave should fade instead of hard-resetting")
	_expect(_within(float(second_oldest["alpha"]), 0.45, 0.55), "every capacity tail should complete the same visible fade")
	_advance(runtime, fake_runtime, owner, registry, 0.21)
	contexts = runtime.get_debug_wave_contexts()
	_expect(contexts.size() == 3, "capacity tails should be removed only after their fade finishes")
	return {"retained_fading": 2, "records_after_fade": contexts.size()}


func _seal_reflection_consumption_and_sweep() -> Dictionary:
	var fake_runtime := FakeRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var runtime: Object = YanguiHoechunRuntime.new()
	_start_wave(runtime, Vector2(380.0, PADDLE_CENTER_Y))
	_advance(runtime, fake_runtime, owner, registry, 1.0)
	_start_wave(runtime, Vector2(430.0, PADDLE_CENTER_Y))
	var contexts: Array[Dictionary] = runtime.get_debug_wave_contexts()
	var first_id := int(contexts[0]["wave_id"])
	var second_id := int(contexts[1]["wave_id"])
	owner.ball_active = true
	owner.ball_pos = Vector2(float(contexts[0]["left_front_x"]), 680.0)
	owner.ball_vel = Vector2(500.0, 900.0)
	var first_speed := owner.ball_vel.length()
	_advance(runtime, fake_runtime, owner, registry, 0.001)
	_expect(owner.ball_vel.y < 0.0, "first wave should reflect a descending ball upward")
	_expect(is_equal_approx(owner.ball_vel.length(), first_speed), "reflection must preserve ball speed")
	_expect(fake_runtime.audio_router.reflect_count == 1, "a wave may reflect exactly once")
	var first_context := _context_for_id(runtime, first_id)
	var second_context := _context_for_id(runtime, second_id)
	_expect(bool(first_context["gameplay_consumed"]), "reflecting wave should own its consumed flag")
	_expect(not bool(second_context["gameplay_consumed"]), "one wave consumption must not consume sibling waves")
	owner.ball_vel = Vector2(500.0, 900.0)
	_advance(runtime, fake_runtime, owner, registry, 0.01)
	_expect(fake_runtime.audio_router.reflect_count == 1, "consumed wave must not reflect twice")
	_advance(runtime, fake_runtime, owner, registry, 0.40)
	_expect(_context_for_id(runtime, first_id).is_empty(), "consumed wave should reach alpha zero within 0.4s")

	var base_sweep := _run_moving_ball_sweep(1.0)
	var fast_sweep := _run_moving_ball_sweep(2.0)
	_expect(bool(base_sweep["reflected"]), "moving descending ball should cross and reflect from the traveling wave")
	_expect(bool(fast_sweep["reflected"]), "increased-speed moving control should still cross and reflect")
	_expect(int(base_sweep["ticks"]) >= 2 and int(fast_sweep["ticks"]) >= 2, "moving sweep fixtures must advance real ball positions across multiple ticks")
	return {
		"base_ticks": base_sweep["ticks"],
		"fast_ticks": fast_sweep["ticks"],
		"base_speed": base_sweep["speed"],
		"fast_speed": fast_sweep["speed"],
	}


func _run_moving_ball_sweep(speed_scale: float) -> Dictionary:
	var fake_runtime := FakeRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var runtime: Object = YanguiHoechunRuntime.new()
	_start_wave(runtime, Vector2(380.0, PADDLE_CENTER_Y))
	_advance(runtime, fake_runtime, owner, registry, 1.0)
	var context := _single_wave(runtime)
	owner.ball_active = true
	owner.ball_pos = Vector2(float(context["right_front_x"]), 575.0)
	owner.ball_vel = Vector2(-120.0, 1800.0 * speed_scale)
	var initial_speed := owner.ball_vel.length()
	var ticks := 0
	while owner.ball_vel.y > 0.0 and owner.ball_pos.y < 770.0 and ticks < 30:
		owner.ball_pos += owner.ball_vel * STEP_SEC
		_advance(runtime, fake_runtime, owner, registry, STEP_SEC)
		ticks += 1
	_expect(is_equal_approx(owner.ball_vel.length(), initial_speed), "moving sweep reflection must preserve velocity magnitude")
	_expect(fake_runtime.audio_router.reflect_count == 1, "moving sweep should consume one reflection budget")
	return {
		"reflected": owner.ball_vel.y < 0.0,
		"ticks": ticks,
		"speed": initial_speed,
	}


func _seal_monotonic_dissipation() -> Dictionary:
	var fake_runtime := FakeRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var runtime: Object = YanguiHoechunRuntime.new()
	_start_wave(runtime, Vector2(77.5, PADDLE_CENTER_Y))
	var elapsed := 0.0
	var context := _single_wave(runtime)
	while str(context["left_state"]) != "dissipating" and elapsed < 1.0:
		_advance(runtime, fake_runtime, owner, registry, STEP_SEC)
		elapsed += STEP_SEC
		context = _single_wave(runtime)
	_advance(runtime, fake_runtime, owner, registry, 0.10)
	context = _single_wave(runtime)
	var before := float(context["left_alpha"])
	owner.ball_active = true
	owner.ball_pos = Vector2(float(context["right_front_x"]), 680.0)
	owner.ball_vel = Vector2(0.0, 900.0)
	_advance(runtime, fake_runtime, owner, registry, 0.001)
	context = _single_wave(runtime)
	var after := float(context["left_alpha"])
	_expect(bool(context["gameplay_consumed"]), "opposite traveling side should still consume the wave")
	_expect(after <= before + 0.002, "pair dissipation must not reset an already-fading side back to alpha one")
	return {"before": before, "after": after}


func _seal_backstop() -> void:
	var fake_runtime := FakeRuntime.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var runtime: Object = YanguiHoechunRuntime.new()
	runtime.set_test_wall_termination_enabled(false)
	_start_wave(runtime, Vector2(380.0, PADDLE_CENTER_Y))
	_advance(runtime, fake_runtime, owner, registry, 7.01)
	_expect(runtime.get_last_backstop_wave_id() == 1, "failed wall fixture should trigger the 7s backstop")
	_expect(not runtime.has_visible_effects(), "backstop should terminate an otherwise immortal wave")


func _seal_lifecycle_routes() -> Dictionary:
	var production_mythic: Object = MythicItemRuntime.new()
	while not production_mythic.prewarm_initialization_step(true, false):
		pass
	_seed_lifecycle_wave(production_mythic)
	BallRoundController.new().reset_ball({}, {"mythic_item_runtime": production_mythic}, {})
	_expect(_lifecycle_wave_count(production_mythic) == 0, "production reset path should empty the actual Yangui array")
	var reset_count := _lifecycle_wave_count(production_mythic)

	_seed_lifecycle_wave(production_mythic)
	BallRoundController.new().serve_ball({}, {"mythic_item_runtime": production_mythic}, {})
	_expect(_lifecycle_wave_count(production_mythic) == 0, "production serve path should empty the actual Yangui array")
	var serve_count := _lifecycle_wave_count(production_mythic)

	_seed_lifecycle_wave(production_mythic)
	MatchRoundRestartController.new().handle_round_restart("rematch", {}, {
		"reset_ball": Callable(self, "_reset_lifecycle_wave").bind(production_mythic),
	})
	_expect(_lifecycle_wave_count(production_mythic) == 0, "production round-restart callback should empty the actual Yangui array")
	var restart_count := _lifecycle_wave_count(production_mythic)

	_seed_lifecycle_wave(production_mythic)
	MatchScoreEventController.new().handle_score_event("player", {"score_state": FakeScoreState.new()}, {
		"reset_ball": Callable(self, "_reset_lifecycle_wave").bind(production_mythic),
	})
	_expect(_lifecycle_wave_count(production_mythic) == 0, "accepted-score reset callback should empty the actual Yangui array")
	var score_count := _lifecycle_wave_count(production_mythic)

	var cancel_mythic := FakeMythicLifecycle.new()
	_seed_lifecycle_wave(cancel_mythic)
	cancel_mythic.cancel_score = true
	MatchScoreEventController.new().handle_score_event("boss", {
		"score_state": FakeScoreState.new(),
		"mythic_item_runtime": cancel_mythic,
	}, {
		"reset_ball": Callable(self, "_reset_lifecycle_wave").bind(cancel_mythic),
	})
	_expect(_lifecycle_wave_count(cancel_mythic) == 0, "boss-score cancellation should converge through the production reset path")
	return {
		"score": score_count,
		"serve": serve_count,
		"restart": restart_count,
		"reset": reset_count,
		"cancel": _lifecycle_wave_count(cancel_mythic),
	}


func _seal_draw_wiring_and_lists() -> Dictionary:
	var runtime: Object = MythicItemRuntime.new()
	while not runtime.prewarm_initialization_step(true, false):
		pass
	_start_wave(runtime.yangui_hoechun_runtime, Vector2(380.0, PADDLE_CENTER_Y))
	var visibility := bool(runtime.has_visible_field_effects())
	_expect(visibility, "production field visibility must stay true for a visible Yangui wave")
	var fake_renderer := FakeYanguiFieldRenderer.new()
	runtime.field_effect_renderer.set_yangui_hoechun_field_renderer_for_test(fake_renderer)
	var canvas := Node2D.new()
	runtime.draw_field_effects(canvas, null, Vector2.ZERO)
	canvas.free()
	_expect(fake_renderer.draw_calls == 1, "production field draw must invoke the Yangui renderer exactly once")
	var wedge_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_yangui_hoechun_field_renderer.gd")
	_expect(wedge_source.find("CORE_LENGTH_PX := 276.0") >= 0, "wedge core should stay within the approved 250-300px range")
	_expect(wedge_source.find("CRESCENT_COUNT := 3") >= 0, "wedge should carry exactly three crescent tracks")
	_expect(wedge_source.find("draw_colored_polygon") >= 0, "wedge layers should be filled geometry")
	_expect(wedge_source.find("draw_polyline") < 0 and wedge_source.find("draw_arc") < 0, "wedge renderer must not restore closed outline aesthetics")
	var ci_path := ProjectSettings.globalize_path("res://../.github/workflows/godot-ci.yml")
	var ci_source := FileAccess.get_file_as_string(ci_path)
	var pre_push_source := FileAccess.get_file_as_string("res://tools/run_pre_push_checks.ps1")
	_expect(ci_source.count(FOCUSED_TEST_PATH) == 1, "focused CI must list the Yangui wave smoke exactly once")
	_expect(pre_push_source.count(FOCUSED_TEST_PATH) == 1, "pre-push must list the Yangui wave smoke exactly once")
	_expect(ci_source.count("res://tests/") == pre_push_source.count("res://tests/"), "focused CI and pre-push smoke lists must remain lockstep")
	return {"renderer_calls": fake_renderer.draw_calls, "visibility": visibility}


func _seed_lifecycle_wave(mythic: Object) -> void:
	_start_wave(mythic.yangui_hoechun_runtime, Vector2(380.0, PADDLE_CENTER_Y))


func _reset_lifecycle_wave(mythic: Object) -> void:
	BallRoundController.new().reset_ball({}, {"mythic_item_runtime": mythic}, {})


func _lifecycle_wave_count(mythic: Object) -> int:
	return mythic.yangui_hoechun_runtime.get_debug_wave_contexts().size()


func _start_wave(runtime: Object, origin: Vector2) -> void:
	runtime.call("_start_wave", origin)


func _advance(runtime: Object, fake_runtime: Object, owner: Object, registry: Object, delta: float) -> void:
	runtime.call("_advance_effect", fake_runtime, owner, registry, delta)


func _single_wave(runtime: Object) -> Dictionary:
	var contexts: Array[Dictionary] = runtime.get_debug_wave_contexts()
	_expect(contexts.size() == 1, "fixture should own exactly one wave")
	return contexts[0] if not contexts.is_empty() else {}


func _context_for_id(runtime: Object, wave_id: int) -> Dictionary:
	for context in runtime.get_debug_wave_contexts():
		if int(context.get("wave_id", 0)) == wave_id:
			return context
	return {}


func _phase_delta(before: float, after: float) -> float:
	return fposmod(after - before, TAU * 1024.0)


func _within(value: float, minimum: float, maximum: float) -> bool:
	return value >= minimum and value <= maximum


func _as_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
