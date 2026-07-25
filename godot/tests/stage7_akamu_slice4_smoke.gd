extends SceneTree

const Stage7AkamuState := preload("res://scripts/stages/stage7/stage7_akamu_state.gd")
const BallRoundController := preload("res://scripts/ball/ball_round_controller.gd")

const CLOUD_PRECAST_SEC := 0.400
const CLOUD_DASH_SEC := 0.316
const CLOUD_BUFFER_SEC := 0.180
const CLOUD_TOTAL_SEC := 8.280
const CLOUD_SEMI_ALPHA := 100.0 / 255.0
const ESCAPE_DURATION_SEC := 0.500
const ESCAPE_TRIGGER_CHANCE := 0.40

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var cloud_calls := 0

	func play_stage7_akamu_cloud() -> void:
		cloud_calls += 1


class FakeStatusEffectState:
	extends RefCounted

	var stun_active := false
	var stun_remaining_frames := 0.0
	var clear_calls := 0

	func get_status(target: String, status_id: String) -> Dictionary:
		if target == "boss" and status_id == "stun" and stun_active:
			return {"remaining_frames": stun_remaining_frames}
		return {}

	func clear_status(target: String, status_id: String) -> void:
		if target == "boss" and status_id == "stun":
			clear_calls += 1
			stun_active = false


class FakeActiveItemRuntime:
	extends RefCounted

	var cooldown_paused := false
	var stun_active := false
	var stun_remaining_frames := 0.0
	var clear_calls := 0

	func get_boss_ai_context() -> Dictionary:
		return {
			"active_item_boss_skill_cooldown_paused": cooldown_paused,
			"active_item_tear_gas_cooldown_pause_active": cooldown_paused,
		}

	func get_boss_disable_context() -> Dictionary:
		return {
			"stun_active": stun_active,
			"stun_remaining_frames": stun_remaining_frames,
		}

	func clear_boss_disable_effects() -> void:
		clear_calls += 1
		stun_active = false


class FakeMythicItemRuntime:
	extends RefCounted

	var stun_active := false
	var stun_remaining_frames := 0.0
	var clear_calls := 0
	var seen_registry: Object = null

	func get_boss_disable_context() -> Dictionary:
		return {
			"stun_active": stun_active,
			"stun_remaining_frames": stun_remaining_frames,
		}

	func clear_boss_disable_effects(registry: Object) -> void:
		clear_calls += 1
		seen_registry = registry
		stun_active = false


class FakeCommandoRuntime:
	extends RefCounted

	var trapped_count := 0
	var release_calls := 0

	func get_boss_net_trap_context() -> Dictionary:
		return {
			"boss_trapped": trapped_count > 0,
			"trapped_count": trapped_count,
		}

	func release_boss_net_traps() -> int:
		release_calls += 1
		var released: int = trapped_count
		trapped_count = 0
		return released


class FakeRegistry:
	extends RefCounted


func _init() -> void:
	_verify_paid_cloud_timeline_and_audio()
	_verify_cloud_alpha_and_cooldown_pause()
	_verify_cloud_composite_intangibility_and_writer_gates()
	_verify_escape_low_gauge_and_failed_episode()
	_verify_escape_immediate_trigger_and_clear_facades()
	_verify_escape_net_delay_and_pause()
	_verify_escape_motion_ghosts_and_timing_freeze()
	_verify_post_bounce_notification_and_real_round_home_reset()
	_verify_slice4_cleanup()

	if _failures.is_empty():
		print("stage7_akamu_slice4_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_paid_cloud_timeline_and_audio() -> void:
	var state: Object = Stage7AkamuState.new()
	var audio := FakeAudio.new()
	var context: Dictionary = _base_context()
	context["boss_pos"] = Vector2(120.0, 25.0)
	state.debug_seed_rng(74001)
	state.debug_set_awakened(true)
	state.debug_set_gauge(200.0)

	_expect(
		state.debug_start_cloud(context, {"audio": audio}, false),
		"paid cloud should start with at least 120 gauge"
	)
	var snapshot: Dictionary = state.debug_get_cloud_snapshot()
	_expect_close(state.debug_get_gauge(), 80.0, "paid cloud should deduct 120 immediately")
	_expect(str(snapshot.get("phase", "")) == "pre", "cloud should begin in the 400ms pre phase")
	_expect_vector(
		snapshot.get("origin_boss_pos", Vector2.ZERO),
		Vector2(330.0, 25.0),
		"cloud should snap the boss top-left to the centered 380px center"
	)
	_expect_vector(
		state.get_boss_ai_context().get("stage7_akamu_scripted_boss_pos", Vector2.ZERO),
		Vector2(330.0, 25.0),
		"cloud pre phase should own the centered scripted position"
	)
	_expect(state.is_boss_ball_intangible(), "cloud should become ball-intangible at cast start")
	_expect(audio.cloud_calls == 0, "cloud audio should wait for landing")

	_advance(state, CLOUD_PRECAST_SEC - 0.001, context, {"audio": audio})
	snapshot = state.debug_get_cloud_snapshot()
	_expect(str(snapshot.get("phase", "")) == "pre", "cloud should not leave pre before 400ms")
	state.update(0.001, context, {"audio": audio})
	snapshot = state.debug_get_cloud_snapshot()
	_expect(str(snapshot.get("phase", "")) == "down", "cloud should enter down at exactly 400ms")
	_expect_close(float(snapshot.get("phase_elapsed_sec", -1.0)), 0.0, "down should own a fresh phase clock")

	_advance(state, CLOUD_DASH_SEC - 0.001, context, {"audio": audio})
	_expect(str(state.debug_get_cloud_snapshot().get("phase", "")) == "down", "cloud should remain down through 315ms")
	_expect(audio.cloud_calls == 0, "cloud audio must not fire before the 316ms landing boundary")
	state.update(0.001, context, {"audio": audio})
	snapshot = state.debug_get_cloud_snapshot()
	_expect(str(snapshot.get("phase", "")) == "up", "landing should transition directly to up")
	_expect(bool(snapshot.get("field_active", false)), "landing should start the cloud field")
	_expect(audio.cloud_calls == 1, "landing should play the exact cloud cue once")
	_expect_vector(
		snapshot.get("field_center", Vector2.ZERO),
		Vector2(380.0, 755.0),
		"cloud field should use the landing center plus the legacy 80px Y offset"
	)
	# Awakening has no separate midstay phase in the Python runtime. Reaching up
	# immediately and ending it after one 316ms leg seals that deliberate parity.
	_advance(state, CLOUD_DASH_SEC - 0.001, context, {"audio": audio})
	_expect(str(state.debug_get_cloud_snapshot().get("phase", "")) == "up", "awakened cloud should have no landing midstay")
	var release_result: Dictionary = state.update(0.001, context, {"audio": audio})
	snapshot = state.debug_get_cloud_snapshot()
	_expect(not bool(snapshot.get("dash_active", true)), "cloud up should finish after 316ms")
	_expect(str(snapshot.get("phase", "x")) == "", "cloud should have no hidden awakened phase after up")
	_expect_close(
		float(snapshot.get("invuln_buffer_remaining_sec", 0.0)),
		CLOUD_BUFFER_SEC,
		"cloud should arm the 180ms post-up intangibility buffer"
	)
	_expect_vector(
		release_result.get("boss_pos", Vector2.ZERO),
		Vector2(330.0, 25.0),
		"cloud completion should publish the centered home position once"
	)
	_expect(audio.cloud_calls == 1, "up completion must not replay landing audio")

	_advance(state, CLOUD_BUFFER_SEC - 0.001, context, {"audio": audio})
	_expect(state.is_boss_ball_intangible(), "cloud should remain intangible through 179ms of its buffer")
	state.update(0.001, context, {"audio": audio})
	_expect(not state.is_boss_ball_intangible(), "cloud intangibility should clear at 180ms")
	_expect(audio.cloud_calls == 1, "cloud field updates must keep the landing cue one-shot")


func _verify_cloud_alpha_and_cooldown_pause() -> void:
	var context: Dictionary = _base_context()
	var state: Object = Stage7AkamuState.new()
	var audio := FakeAudio.new()
	_expect(state.debug_start_cloud(context, {"audio": audio}, true), "free cloud should start for alpha testing")
	_land_cloud(state, context, {"audio": audio})
	var snapshot: Dictionary = state.debug_get_cloud_snapshot()
	_expect_close(float(snapshot.get("field_elapsed_sec", -1.0)), 0.0, "landing should start the field clock at zero")
	_expect_close(float(snapshot.get("field_alpha", 0.0)), 1.0, "new cloud should be fully opaque")

	_advance(state, 3.0, context, {"audio": audio})
	snapshot = state.debug_get_cloud_snapshot()
	_expect_close(float(snapshot.get("field_alpha", 0.0)), 1.0, "cloud should stay solid through 3.0s")
	_advance(state, 1.0, context, {"audio": audio})
	snapshot = state.debug_get_cloud_snapshot()
	_expect_close(
		float(snapshot.get("field_alpha", 0.0)),
		lerpf(1.0, CLOUD_SEMI_ALPHA, 0.5),
		"cloud should be halfway from solid to semi-alpha at 4.0s",
		0.001
	)
	_advance(state, 1.0, context, {"audio": audio})
	_expect_close(
		float(state.debug_get_cloud_snapshot().get("field_alpha", 0.0)),
		CLOUD_SEMI_ALPHA,
		"cloud should reach 100/255 alpha at 5.0s",
		0.001
	)
	_advance(state, 0.28, context, {"audio": audio})
	_expect_close(
		float(state.debug_get_cloud_snapshot().get("field_alpha", 0.0)),
		CLOUD_SEMI_ALPHA,
		"cloud should hold semi-alpha through the 5.28s fade boundary",
		0.001
	)
	_advance(state, 1.5, context, {"audio": audio})
	_expect_close(
		float(state.debug_get_cloud_snapshot().get("field_alpha", 0.0)),
		CLOUD_SEMI_ALPHA * 0.5,
		"cloud should be halfway through final fade at 6.78s",
		0.001
	)
	_advance(state, CLOUD_TOTAL_SEC - 6.78 - 0.001, context, {"audio": audio})
	snapshot = state.debug_get_cloud_snapshot()
	_expect(bool(snapshot.get("field_active", false)), "cloud should still exist just before 8.28s")
	_expect(float(snapshot.get("field_alpha", 0.0)) > 0.0, "cloud alpha should remain positive just before expiry")
	state.update(0.001, context, {"audio": audio})
	snapshot = state.debug_get_cloud_snapshot()
	_expect(not bool(snapshot.get("field_active", true)), "cloud should leave exactly at 8.28s")
	_expect_close(float(snapshot.get("field_alpha", -1.0)), 0.0, "expired cloud should expose zero alpha")
	_expect(audio.cloud_calls == 1, "the full 8.28s field must not replay cloud audio")

	var paused_state: Object = Stage7AkamuState.new()
	var runtime := FakeActiveItemRuntime.new()
	runtime.cooldown_paused = true
	_expect(paused_state.debug_start_cloud(context, {}, true), "pause cloud precondition should start")
	var cooldown_before: float = float(paused_state.debug_get_cloud_snapshot().get("cooldown_remaining_sec", 0.0))
	paused_state.update(0.1, context, {"active_item_runtime": runtime})
	snapshot = paused_state.debug_get_cloud_snapshot()
	_expect_close(float(snapshot.get("phase_elapsed_sec", 0.0)), 0.1, "active cloud dash should progress during boss-skill pause")
	_expect_close(float(snapshot.get("cooldown_remaining_sec", 0.0)), cooldown_before, "cloud cooldown should stop during boss-skill pause")

	runtime.cooldown_paused = false
	_advance(paused_state, 0.3 + CLOUD_DASH_SEC, context, {"active_item_runtime": runtime})
	snapshot = paused_state.debug_get_cloud_snapshot()
	_expect(bool(snapshot.get("field_active", false)), "unpaused cloud should reach its field")
	var paused_field_elapsed: float = float(snapshot.get("field_elapsed_sec", 0.0))
	cooldown_before = float(snapshot.get("cooldown_remaining_sec", 0.0))
	runtime.cooldown_paused = true
	_advance(paused_state, 0.2, context, {"active_item_runtime": runtime})
	snapshot = paused_state.debug_get_cloud_snapshot()
	_expect_close(
		float(snapshot.get("field_elapsed_sec", 0.0)),
		paused_field_elapsed + 0.2,
		"active cloud field should keep aging during boss-skill pause"
	)
	_expect_close(float(snapshot.get("cooldown_remaining_sec", 0.0)), cooldown_before, "field activity must not unpause cloud cooldown")


func _verify_cloud_composite_intangibility_and_writer_gates() -> void:
	var context: Dictionary = _base_context()
	var state: Object = Stage7AkamuState.new()
	state.set_boss_ball_intangible_source("external_test", true)
	_expect(state.debug_start_cloud(context, {}, true), "composite intangibility precondition should start cloud")
	_land_cloud(state, context)
	_advance(state, CLOUD_DASH_SEC, context)
	_advance(state, CLOUD_BUFFER_SEC, context)
	_expect(state.is_boss_ball_intangible(), "cloud source expiry must preserve an external intangibility contributor")
	state.set_boss_ball_intangible_source("external_test", false)
	_expect(not state.is_boss_ball_intangible(), "composite intangibility should clear after the final source leaves")

	var puppet_state: Object = Stage7AkamuState.new()
	var puppet_context: Dictionary = context.duplicate(true)
	puppet_context["lingpet_puppet_grab_active"] = true
	_expect(not puppet_state.debug_start_cloud(puppet_context, {}, true), "puppet grab should own scripted motion ahead of cloud")

	var clone_state: Object = Stage7AkamuState.new()
	_expect(clone_state.debug_start_clone_cast(context, true), "clone writer-gate precondition should start")
	_expect(not clone_state.debug_start_cloud(context, {}, true), "active clone cast should reject cloud scripted ownership")

	var shuriken_state: Object = Stage7AkamuState.new()
	shuriken_state.debug_set_gauge(100.0)
	shuriken_state.debug_set_shuriken_cooldown_remaining(0.0, 8.0)
	shuriken_state.update(0.0, context)
	_expect(bool(shuriken_state.debug_get_shuriken_snapshot().get("casting", false)), "shuriken writer-gate precondition should start")
	_expect(not shuriken_state.debug_start_cloud(context, {}, true), "active shuriken cast should reject cloud scripted ownership")

	var cloud_state: Object = Stage7AkamuState.new()
	cloud_state.debug_set_gauge(100.0)
	_expect(cloud_state.debug_start_cloud(context, {}, true), "reverse writer-gate precondition should start cloud")
	_expect(not cloud_state.debug_start_clone_cast(context, true), "active cloud should reject clone scripted ownership")
	cloud_state.debug_set_shuriken_cooldown_remaining(0.0, 8.0)
	cloud_state.update(0.0, context)
	_expect(not bool(cloud_state.debug_get_shuriken_snapshot().get("casting", false)), "shuriken scheduler should wait for active cloud motion")

	var escape_state: Object = Stage7AkamuState.new()
	_expect(escape_state.debug_start_escape(context), "escape writer-gate precondition should start")
	_expect(not escape_state.debug_start_cloud(context, {}, true), "active escape should reject cloud scripted ownership")


func _verify_escape_low_gauge_and_failed_episode() -> void:
	var context: Dictionary = _base_context()
	var status_state := FakeStatusEffectState.new()
	status_state.stun_active = true
	status_state.stun_remaining_frames = 60.0
	var deps := {"status_effect_state": status_state}

	var low_gauge_state: Object = Stage7AkamuState.new()
	low_gauge_state.debug_set_gauge(29.0)
	low_gauge_state.debug_set_shuriken_cooldown_remaining(99.0, 99.0)
	low_gauge_state.update(0.0, context, deps)
	var snapshot: Dictionary = low_gauge_state.debug_get_escape_snapshot()
	_expect(bool(snapshot.get("episode_active", false)), "stun should open an escape episode even when underfunded")
	_expect(not bool(snapshot.get("attempted", true)), "gauge below 30 should not spend the episode's single attempt")
	_expect(not bool(snapshot.get("active", true)), "underfunded escape should stay inactive")
	low_gauge_state.update(0.1, context, deps)
	_expect(not bool(low_gauge_state.debug_get_escape_snapshot().get("attempted", true)), "underfunded frames should remain retry-eligible without rolling")
	_expect(status_state.clear_calls == 0, "underfunded escape must not clear the originating stun")

	var failed_status := FakeStatusEffectState.new()
	failed_status.stun_active = true
	failed_status.stun_remaining_frames = 60.0
	var failed_state: Object = Stage7AkamuState.new()
	failed_state.debug_set_gauge(100.0)
	failed_state.debug_set_shuriken_cooldown_remaining(99.0, 99.0)
	failed_state.debug_seed_rng(_seed_for_escape_roll(false))
	failed_state.update(0.0, context, {"status_effect_state": failed_status})
	snapshot = failed_state.debug_get_escape_snapshot()
	_expect(bool(snapshot.get("attempted", false)), "failed 40% roll should consume exactly one episode attempt")
	_expect(not bool(snapshot.get("active", true)), "failed escape roll should not start motion")
	_expect_close(failed_state.debug_get_gauge(), 100.0, "failed escape should not spend gauge")
	failed_state.debug_seed_rng(_seed_for_escape_roll(true))
	_advance(failed_state, 0.5, context, {"status_effect_state": failed_status})
	snapshot = failed_state.debug_get_escape_snapshot()
	_expect(bool(snapshot.get("attempted", false)) and not bool(snapshot.get("active", true)), "continuous stun should never reroll after its failed attempt")
	_expect(failed_status.clear_calls == 0, "failed escape must leave disable effects intact")


func _verify_escape_immediate_trigger_and_clear_facades() -> void:
	var context: Dictionary = _base_context()
	var status_state := FakeStatusEffectState.new()
	status_state.stun_active = true
	status_state.stun_remaining_frames = 120.0
	var active_runtime := FakeActiveItemRuntime.new()
	active_runtime.stun_active = true
	active_runtime.stun_remaining_frames = 90.0
	var mythic_runtime := FakeMythicItemRuntime.new()
	mythic_runtime.stun_active = true
	mythic_runtime.stun_remaining_frames = 150.0
	var commando_runtime := FakeCommandoRuntime.new()
	commando_runtime.trapped_count = 2
	var registry := FakeRegistry.new()
	var deps := {
		"status_effect_state": status_state,
		"active_item_runtime": active_runtime,
		"mythic_item_runtime": mythic_runtime,
		"commando_firearm_runtime": commando_runtime,
		"registry": registry,
	}
	var state: Object = Stage7AkamuState.new()
	state.debug_set_gauge(100.0)
	state.debug_set_shuriken_cooldown_remaining(99.0, 99.0)
	state.debug_seed_rng(_seed_for_escape_roll(true))

	state.update(0.0, context, deps)
	var snapshot: Dictionary = state.debug_get_escape_snapshot()
	_expect(bool(snapshot.get("active", false)), "status stun should attempt escape immediately without the net delay")
	_expect_close(float(snapshot.get("ready_remaining_sec", -1.0)), 0.0, "stun-triggered escape should have no readiness delay")
	_expect_close(state.debug_get_gauge(), 70.0, "successful automatic escape should spend 30 gauge")
	_expect(state.is_boss_ball_intangible(), "active escape should own its composite intangibility source")
	_expect(str(state.get_actor_draw_context().get("stage7_akamu_status", "")) == "escape_active", "successful escape should publish active status immediately")
	_expect(status_state.clear_calls == 1, "escape facade should clear status-effect stun")
	_expect(active_runtime.clear_calls == 1, "escape facade should clear active-item boss disables")
	_expect(mythic_runtime.clear_calls == 1, "escape facade should clear mythic boss disables")
	_expect(mythic_runtime.seen_registry == registry, "mythic clear facade should receive the shared registry")
	_expect(commando_runtime.release_calls == 1, "escape facade should release commando net traps")
	_expect(int(snapshot.get("released_net_count", 0)) == 2, "escape snapshot should expose the released net count")
	var hologram: Dictionary = snapshot.get("hologram", {})
	_expect_close(float(hologram.get("total_sec", 0.0)), 2.9, "hologram should live for max remaining stun 2.5s plus 0.4s fade")
	_expect_close(float(hologram.get("remaining_sec", 0.0)), 2.9, "new hologram should begin at its full stun-plus-fade duration")

	_advance(state, ESCAPE_DURATION_SEC, context, deps)
	snapshot = state.debug_get_escape_snapshot()
	_expect(not bool(snapshot.get("active", true)), "escape motion should finish at 500ms")
	_expect(not state.is_boss_ball_intangible(), "escape should release its intangibility at motion completion")
	hologram = snapshot.get("hologram", {})
	_expect_close(float(hologram.get("remaining_sec", 0.0)), 2.4, "hologram should continue after motion for the original stun remainder")
	_advance(state, 2.399, context, deps)
	_expect(bool(state.debug_get_escape_snapshot().get("hologram_active", false)), "hologram should survive until just before stun-plus-fade expiry")
	state.update(0.001, context, deps)
	_expect(not bool(state.debug_get_escape_snapshot().get("hologram_active", true)), "hologram should clear at stun remainder plus 400ms")


func _verify_escape_net_delay_and_pause() -> void:
	var context: Dictionary = _base_context()
	var commando_runtime := FakeCommandoRuntime.new()
	commando_runtime.trapped_count = 1
	var state: Object = Stage7AkamuState.new()
	state.debug_set_gauge(100.0)
	state.debug_set_shuriken_cooldown_remaining(99.0, 99.0)
	state.debug_seed_rng(_seed_for_escape_roll(true))
	state.update(0.0, context, {"commando_firearm_runtime": commando_runtime})
	var snapshot: Dictionary = state.debug_get_escape_snapshot()
	_expect(not bool(snapshot.get("active", true)), "net-only escape should not start on the detection frame")
	_expect_close(float(snapshot.get("ready_remaining_sec", 0.0)), 0.3, "net-only escape should arm a 300ms delay")
	_advance(state, 0.299, context, {"commando_firearm_runtime": commando_runtime})
	snapshot = state.debug_get_escape_snapshot()
	_expect(not bool(snapshot.get("active", true)), "net escape should remain pending through 299ms")
	_expect_close(float(snapshot.get("ready_remaining_sec", 0.0)), 0.001, "net delay should expose its final millisecond", 0.0002)
	state.update(0.001, context, {"commando_firearm_runtime": commando_runtime})
	snapshot = state.debug_get_escape_snapshot()
	_expect(bool(snapshot.get("active", false)), "net escape should attempt at exactly 300ms")
	_expect(int(snapshot.get("released_net_count", 0)) == 1, "successful net escape should report one released trap")

	var paused_commando := FakeCommandoRuntime.new()
	paused_commando.trapped_count = 1
	var paused_runtime := FakeActiveItemRuntime.new()
	var paused_state: Object = Stage7AkamuState.new()
	paused_state.debug_set_gauge(100.0)
	paused_state.debug_set_shuriken_cooldown_remaining(99.0, 99.0)
	paused_state.debug_seed_rng(_seed_for_escape_roll(true))
	var paused_deps := {
		"active_item_runtime": paused_runtime,
		"commando_firearm_runtime": paused_commando,
	}
	paused_state.update(0.0, context, paused_deps)
	paused_runtime.cooldown_paused = true
	_advance(paused_state, 0.2, context, paused_deps)
	snapshot = paused_state.debug_get_escape_snapshot()
	_expect_close(float(snapshot.get("ready_remaining_sec", 0.0)), 0.3, "boss-skill pause should freeze pending net delay")
	_expect(str(paused_state.get_actor_draw_context().get("stage7_akamu_status", "")) == "paused", "pending escape should expose paused status while its scheduler is stopped")
	paused_runtime.cooldown_paused = false
	_advance(paused_state, 0.3, context, paused_deps)
	_expect(bool(paused_state.debug_get_escape_snapshot().get("active", false)), "net delay should resume and trigger after pause release")


func _verify_escape_motion_ghosts_and_timing_freeze() -> void:
	var context: Dictionary = _base_context()
	context["boss_pos"] = Vector2(330.0, 25.0)
	context["ball_pos"] = Vector2(500.0, 100.0)
	var state: Object = Stage7AkamuState.new()
	_expect(state.debug_start_escape(context), "debug escape should start for motion verification")
	var snapshot: Dictionary = state.debug_get_escape_snapshot()
	_expect_vector(snapshot.get("target_boss_pos", Vector2.ZERO), Vector2(70.0, 25.0), "ball on the right should send escape 260px left")
	_expect(int(snapshot.get("afterimage_count", 0)) == 1, "escape should begin with only the zero-delay ghost")
	_expect(state.is_boss_ball_intangible(), "escape motion should be ball-intangible immediately")

	_advance(state, 0.239, context)
	_expect(int(state.debug_get_escape_snapshot().get("afterimage_count", 0)) == 4, "four ghosts should be visible before the 240ms fifth delay")
	state.update(0.001, context)
	var afterimages: Array = state.get_actor_draw_context().get("stage7_akamu_afterimages", [])
	_expect(afterimages.size() == 5, "all five ghosts should appear at the 240ms delay boundary")
	for index in range(afterimages.size()):
		var ghost: Dictionary = afterimages[index]
		_expect(int(ghost.get("index", -1)) == index, "escape ghosts should retain stable delay indices")
		_expect_close(
			float(ghost.get("alpha", -1.0)),
			float(255 - index * 40) / 255.0,
			"escape ghost should keep the exact legacy base alpha before fade"
		)
		if index > 0:
			var previous_alpha: float = float((afterimages[index - 1] as Dictionary).get("alpha", 0.0))
			_expect(previous_alpha > float(ghost.get("alpha", 1.0)), "escape ghost base alpha should descend with delay index")
	_expect_close(float((afterimages[4] as Dictionary).get("progress", -1.0)), 0.0, "fifth ghost should enter at zero local progress")

	state.update(0.01, context)
	snapshot = state.debug_get_escape_snapshot()
	_expect_close(float(snapshot.get("elapsed_sec", 0.0)), 0.25, "escape midpoint should land at 250ms")
	_expect_vector(snapshot.get("boss_pos", Vector2.ZERO), Vector2(135.0, 25.0), "escape should use quadratic ease-out: 75% distance at half time", 0.001)

	var runtime := FakeActiveItemRuntime.new()
	runtime.cooldown_paused = true
	state.update(0.1, context, {"active_item_runtime": runtime})
	snapshot = state.debug_get_escape_snapshot()
	_expect_close(float(snapshot.get("elapsed_sec", 0.0)), 0.35, "active escape should keep moving during boss-skill cooldown pause")
	_expect(str(state.get_actor_draw_context().get("stage7_akamu_status", "")) == "escape_active", "active escape status should outrank cooldown pause")

	var timing_frozen_context: Dictionary = context.duplicate(true)
	timing_frozen_context["waiting_for_serve"] = true
	state.update(0.1, timing_frozen_context, {"active_item_runtime": runtime})
	_expect_close(float(state.debug_get_escape_snapshot().get("elapsed_sec", 0.0)), 0.35, "serve timing freeze should stop active escape motion")
	runtime.cooldown_paused = false
	state.update(0.1, context, {"active_item_runtime": runtime})
	var release_result: Dictionary = state.update(0.05, context, {"active_item_runtime": runtime})
	snapshot = state.debug_get_escape_snapshot()
	_expect(not bool(snapshot.get("active", true)), "escape should finish after 500ms of unfrozen active time")
	_expect_vector(release_result.get("boss_pos", Vector2.ZERO), Vector2(70.0, 25.0), "escape completion should publish the exact target position")
	_expect(int(snapshot.get("afterimage_count", -1)) == 0, "escape completion should clear all five ghosts")
	_expect(not state.is_boss_ball_intangible(), "escape completion should release its intangibility source")

	var right_state: Object = Stage7AkamuState.new()
	var left_ball_context: Dictionary = context.duplicate(true)
	left_ball_context["ball_pos"] = Vector2(100.0, 100.0)
	_expect(right_state.debug_start_escape(left_ball_context), "opposite-direction escape should start")
	_expect_vector(
		right_state.debug_get_escape_snapshot().get("target_boss_pos", Vector2.ZERO),
		Vector2(590.0, 25.0),
		"ball on the left should send escape 260px right"
	)

	var shrink_state: Object = Stage7AkamuState.new()
	var shrink_context: Dictionary = context.duplicate(true)
	shrink_context["boss_paddle_shrink_scale"] = 0.45
	_expect(shrink_state.debug_start_escape(shrink_context), "dwarf-scale escape precondition should start")
	var shrink_draw_context: Dictionary = shrink_state.get_actor_draw_context()
	var shrink_ghosts: Array = shrink_draw_context.get("stage7_akamu_afterimages", [])
	var shrink_hologram: Dictionary = shrink_draw_context.get("stage7_akamu_hologram", {})
	_expect_close(float((shrink_ghosts[0] as Dictionary).get("visual_scale", 0.0)), 0.45, "escape ghost should capture launch-time dwarf scale")
	_expect_close(float(shrink_hologram.get("visual_scale", 0.0)), 0.45, "escape hologram should capture launch-time dwarf scale")
	shrink_context["boss_paddle_shrink_scale"] = 1.0
	shrink_state.update(0.1, shrink_context)
	shrink_draw_context = shrink_state.get_actor_draw_context()
	shrink_hologram = shrink_draw_context.get("stage7_akamu_hologram", {})
	_expect_close(float(shrink_hologram.get("visual_scale", 0.0)), 0.45, "escape hologram should not resize when dwarf magic expires")


func _verify_post_bounce_notification_and_real_round_home_reset() -> void:
	var context: Dictionary = _base_context()
	var notification_state: Object = Stage7AkamuState.new()
	notification_state.debug_seed_rng(74077)
	notification_state.debug_set_gauge(500.0)
	var committed_velocity := Vector2(4.5, 11.0)
	var committed_scene := {
		"ball_pos": Vector2(380.0, 92.0),
		"ball_vel": committed_velocity,
	}
	notification_state.handle_boss_paddle_hit(committed_scene, context)
	_expect_vector(
		committed_scene.get("ball_vel", Vector2.ZERO),
		committed_velocity,
		"post-bounce cloud/clone notification must never rewrite the committed normal bounce"
	)

	var state: Object = Stage7AkamuState.new()
	_expect(state.debug_start_cloud(context, {}, true), "round-home reset cloud precondition should start")
	_advance(state, CLOUD_PRECAST_SEC, context)
	_advance(state, 0.2, context)
	var down_pos: Vector2 = state.debug_get_cloud_snapshot().get("boss_pos", Vector2.ZERO)
	_expect(down_pos.y > 25.0, "round-home reset precondition should place the boss below its home band")
	var reset_result: Dictionary = BallRoundController.new().reset_ball({
		"width": 760.0,
		"height": 750.0,
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_width": 155.0,
		"player_y": 690.0,
		"boss_pos": down_pos,
		"boss_paddle_width": 100.0,
		"boss_y": 25.0,
	}, {"stage7_akamu_state": state}, {})
	_expect_vector(
		reset_result.get("boss_pos", Vector2.ZERO),
		Vector2(330.0, 25.0),
		"real BallRoundController reset should normalize a cloud-down boss to the Stage 7 home band"
	)
	_expect(
		not bool(state.debug_get_cloud_snapshot().get("dash_active", true)),
		"real ball-reset cleanup should cancel the active cloud writer"
	)


func _verify_slice4_cleanup() -> void:
	var context: Dictionary = _base_context()
	var state: Object = Stage7AkamuState.new()
	state.debug_set_gauge(200.0)
	state.debug_set_awakened(true)
	state.set_boss_ball_intangible_source("external_cleanup_test", true)
	_expect(state.debug_start_cloud(context, {}, false), "cleanup cloud precondition should start")
	var cloud_cooldown_before: float = float(state.debug_get_cloud_snapshot().get("cooldown_remaining_sec", 0.0))
	_expect(cloud_cooldown_before > 0.0, "paid cloud should arm its cooldown for the persistence check")
	state.clear_round_transients()
	var cloud_snapshot: Dictionary = state.debug_get_cloud_snapshot()
	_expect(not bool(cloud_snapshot.get("dash_active", true)), "round cleanup should cancel cloud dash")
	_expect(not bool(cloud_snapshot.get("field_active", true)), "round cleanup should clear cloud field")
	# 원본 파리티(2026-07-12): 스킬 쿨타임은 라운드 경계를 넘어 유지된다.
	_expect_close(
		float(cloud_snapshot.get("cooldown_remaining_sec", -1.0)),
		cloud_cooldown_before,
		"cloud skill cooldown must PERSIST across the round boundary (not reset)"
	)
	_expect(not state.is_boss_ball_intangible(), "round cleanup should clear cloud and external intangibility sources")
	_expect(not bool(state.get_boss_ai_context().get("stage7_akamu_scripted_motion_active", true)), "round cleanup should release cloud scripted motion")
	_expect((state.get_actor_draw_context().get("stage7_akamu_cloud", {}) as Dictionary).is_empty(), "round cleanup should clear cloud render payload")
	_expect_close(state.debug_get_gauge(), 80.0, "transient cleanup should preserve post-cost Stage 7 gauge")
	_expect(state.debug_is_awakened(), "transient cleanup should preserve awakening")
	state.reset()
	_expect_close(float(state.debug_get_cloud_snapshot().get("cooldown_remaining_sec", -1.0)), 0.0, "full reset SHOULD clear the cloud cooldown")

	var escape_state: Object = Stage7AkamuState.new()
	_expect(escape_state.debug_start_escape(context, {}, 1.0), "cleanup escape precondition should start")
	escape_state.update(0.24, context)
	escape_state.clear_round_transients()
	var escape_snapshot: Dictionary = escape_state.debug_get_escape_snapshot()
	_expect(not bool(escape_snapshot.get("active", true)), "round cleanup should cancel escape motion")
	_expect(not bool(escape_snapshot.get("episode_active", true)), "round cleanup should close the escape episode")
	_expect(not bool(escape_snapshot.get("hologram_active", true)), "round cleanup should clear escape hologram")
	_expect(int(escape_snapshot.get("afterimage_count", -1)) == 0, "round cleanup should clear escape ghosts")
	_expect(not escape_state.is_boss_ball_intangible(), "round cleanup should clear escape intangibility")

	state.reset_for_result()
	_expect_close(state.debug_get_gauge(), 0.0, "result reset should clear Slice 4 gauge")
	_expect(not state.debug_is_awakened(), "result reset should clear Slice 4 awakening")


func _land_cloud(state: Object, context: Dictionary, deps: Dictionary = {}) -> void:
	_advance(state, CLOUD_PRECAST_SEC, context, deps)
	_advance(state, CLOUD_DASH_SEC, context, deps)


func _advance(
	state: Object,
	duration_sec: float,
	context: Dictionary,
	deps: Dictionary = {}
) -> void:
	var remaining: float = duration_sec
	while remaining > 0.000001:
		var step: float = minf(0.1, remaining)
		state.update(step, context, deps)
		remaining -= step


func _seed_for_escape_roll(want_success: bool) -> int:
	for candidate in range(1, 10000):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var succeeds: bool = rng.randf() <= ESCAPE_TRIGGER_CHANCE
		if succeeds == want_success:
			return candidate
	return 1


func _base_context() -> Dictionary:
	return {
		"current_stage": 7,
		"selected_character_type": "smasher",
		"ball_active": true,
		"waiting_for_serve": false,
		"width": 760.0,
		"height": 750.0,
		"play_left": 0.0,
		"play_right": 760.0,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_size": Vector2(100.0, 40.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 690.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_pos": Vector2(500.0, 100.0),
		"ball_size": 20.0,
		"special_gauge": 100.0,
		"player_speed": 5.0,
		"boss_vel": 0.0,
		"last_hit_by": "player",
	}


func _vector(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO


func _expect_vector(
	actual_value: Variant,
	expected_value: Variant,
	message: String,
	tolerance: float = 0.0001
) -> void:
	var actual: Vector2 = _vector(actual_value)
	var expected: Vector2 = _vector(expected_value)
	_expect(actual.distance_to(expected) <= tolerance, "%s (expected %s, got %s)" % [message, expected, actual])


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s (expected %.5f, got %.5f)" % [message, expected, actual])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
