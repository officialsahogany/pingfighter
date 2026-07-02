extends SceneTree

const HeadbuttSkill := preload("res://scripts/lingpet/lingpet_headbutt_skill.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const LaunchPayloadBuilder := preload("res://scripts/lingpet/lingpet_companion_skill_launch_payload_builder.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0


class FakeBossAiState:
	extends RefCounted

	var knockback_calls := 0
	var last_velocity := 0.0
	var last_frames := 0.0
	var last_decay := 0.0
	var last_replace := false

	func start_paddle_hit_knockback(velocity: float, frames: float, decay_per_frame: float, replace_current: bool = true) -> void:
		knockback_calls += 1
		last_velocity = velocity
		last_frames = frames
		last_decay = decay_per_frame
		last_replace = replace_current


class FakeStatusEffectState:
	extends RefCounted

	var calls: Array[Dictionary] = []

	func apply_status(target: String, status_id: String, duration_frames: float, data: Dictionary = {}, source: String = "") -> Dictionary:
		var status_call := {
			"target": target,
			"status_id": status_id,
			"duration_frames": duration_frames,
			"data": data.duplicate(true),
			"source": source,
		}
		calls.append(status_call)
		return status_call

	func get_calls_for_source(source: String) -> Array[Dictionary]:
		var matches: Array[Dictionary] = []
		for status_call in calls:
			if str(status_call.get("source", "")) == source:
				matches.append(status_call)
		return matches


class FakeAudio:
	extends RefCounted

	var boomerang_hit_count := 0
	var paddle_hit_count := 0
	var dynamite_count := 0
	var horn_charge_count := 0

	func play_boomerang_hit() -> void:
		boomerang_hit_count += 1

	func play_paddle_hit() -> void:
		paddle_hit_count += 1

	func play_dynamite_explosion() -> void:
		dynamite_count += 1

	func play_horn_charge() -> void:
		horn_charge_count += 1


class FakeFeedback:
	extends RefCounted

	var shakes: Array[Vector2] = []

	func max_screen_shake(amount: float, intensity: float) -> void:
		shakes.append(Vector2(amount, intensity))


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value if value is Object else null


func _init() -> void:
	_verify_dispatcher_catalog_and_payload()
	_verify_horncharge_audio_route()
	_verify_normal_headbutt_uses_ai_knockback()
	_verify_onimaru_hit_stun_and_self_stun()
	_verify_onimaru_slam_radius_scales_catch()
	_verify_mega_stun_owns_knockback()
	_verify_runtime_host_routes_headbutt_state()

	if _failures.is_empty():
		print("lingpet_headbutt_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_catalog_and_payload() -> void:
	_expect(LingpetSkillDispatcher.is_supported_kind("headbutt"), "dispatcher should support the headbutt runtime kind")
	_expect(LingpetSkillDispatcher.is_headbutt("lunabi_headbutt"), "Lunabi Headbutt should route to the headbutt runtime")
	_expect(LingpetSkillDispatcher.is_headbutt("onimaru_headbutt"), "Onimaru Headbutt should route to the shared headbutt runtime through catalog metadata")
	_expect(LingpetSkillDispatcher.skills_share_exclusive_resource("lunabi_headbutt", "onimaru_headbutt"), "Headbutt variants should share the position-override exclusive resource")

	var lunabi_lv5: Dictionary = LingpetCatalog.get_active_skill("lunabi", "lunabi_headbutt", 5)
	_expect(str(lunabi_lv5.get("runtime_kind", "")) == "headbutt", "Lunabi catalog entry should keep runtime_kind=headbutt")
	_expect(int(lunabi_lv5.get("headbutt_count", 0)) == 3, "Lunabi Lv.5 should resolve to a 3-hit combo")
	_expect(is_equal_approx(float(lunabi_lv5.get("knockback_scale", 0.0)), 1.40), "Lunabi Lv.5 should resolve the 1.40 knockback scale")
	_expect(is_equal_approx(float(lunabi_lv5.get("mega_chance", -1.0)), 0.25), "Lunabi Lv.5 should resolve the 25% mega roll")

	var onimaru_lv1: Dictionary = LingpetCatalog.get_active_skill("onimaru", "onimaru_headbutt", 1)
	var onimaru_lv5: Dictionary = LingpetCatalog.get_active_skill("onimaru", "onimaru_headbutt", 5)
	_expect(str(onimaru_lv1.get("runtime_kind", "")) == "headbutt", "Onimaru catalog entry should reuse the headbutt runtime kind")
	_expect(float(onimaru_lv5.get("dash_radius", 0.0)) > float(onimaru_lv1.get("dash_radius", 0.0)), "Onimaru reach should widen with level")
	_expect(float(onimaru_lv5.get("slam_radius", 0.0)) > float(onimaru_lv1.get("slam_radius", 0.0)), "Onimaru ground-slam blast/stun radius should widen with level")
	_expect(float(onimaru_lv5.get("hit_stun_seconds", 0.0)) > float(onimaru_lv1.get("hit_stun_seconds", 0.0)), "Onimaru boss stun should grow with level")
	_expect(float(onimaru_lv5.get("self_stun_seconds", 99.0)) < float(onimaru_lv1.get("self_stun_seconds", 0.0)), "Onimaru self-stun should shrink with level")
	_expect(is_equal_approx(float(onimaru_lv1.get("disable_moving_miss", 0.0)), 1.0), "Onimaru should disable moving-target misses")
	_expect(is_equal_approx(float(onimaru_lv1.get("ground_slam", 0.0)), 1.0), "Onimaru should enable the ground-slam impact feel")

	var payload: Dictionary = LaunchPayloadBuilder.new().build(onimaru_lv5, "onimaru_headbutt", 5, Vector2(210.0, 620.0), 18.0, null)
	_expect(is_equal_approx(float(payload.get("dash_radius", 0.0)), float(onimaru_lv5.get("dash_radius", 0.0))), "launch payload should forward dash_radius")
	_expect(is_equal_approx(float(payload.get("slam_radius", 0.0)), float(onimaru_lv5.get("slam_radius", 0.0))), "launch payload should forward slam_radius")
	_expect(is_equal_approx(float(payload.get("hit_stun_seconds", 0.0)), float(onimaru_lv5.get("hit_stun_seconds", 0.0))), "launch payload should forward hit_stun_seconds")
	_expect(is_equal_approx(float(payload.get("self_stun_seconds", 0.0)), float(onimaru_lv5.get("self_stun_seconds", 0.0))), "launch payload should forward self_stun_seconds")
	_expect(is_equal_approx(float(payload.get("disable_moving_miss", 0.0)), 1.0), "launch payload should forward disable_moving_miss")
	_expect(is_equal_approx(float(payload.get("ground_slam", 0.0)), 1.0), "launch payload should forward ground_slam")


func _verify_horncharge_audio_route() -> void:
	var source := _read_text("res://scripts/audio/game_audio.gd")
	_expect(source.find("func play_horn_charge() -> void:") >= 0, "game audio should expose a generic horncharge cue for Onimaru")
	var body := _function_body(source, "func play_horn_charge() -> void:")
	_expect(body.find("horn_strawberry_horn_charge_sfx") >= 0, "generic horncharge cue should use the legacy horncharge.wav player")
	_expect(body.find("play_dynamite_explosion") < 0 and body.find("grenade_sfx") < 0, "generic horncharge cue should not fall back to grenade/dynamite as its primary sound")


func _verify_normal_headbutt_uses_ai_knockback() -> void:
	var skill := HeadbuttSkill.new()
	var owner := FakeOwner.new()
	var boss_ai := FakeBossAiState.new()
	var status_state := FakeStatusEffectState.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new({
		"boss_ai_state": boss_ai,
		"status_effect_state": status_state,
		"game_audio": audio,
	})
	var context := {
		"active_skill_level": 1,
		"knockback_scale": 1.10,
		"headbutt_count": 1,
		"mega_chance": 0.0,
	}
	_expect(skill.launch(Vector2(380.0, 600.0), owner, context), "normal Headbutt should launch")
	var hit := _step_until_hit(skill, owner, registry)
	_expect(hit, "normal Headbutt should hit a stationary boss")
	_expect(boss_ai.knockback_calls == 1, "normal non-stun Headbutt should use the boss AI paddle-hit knockback channel")
	_expect(is_equal_approx(absf(boss_ai.last_velocity), 13.0 * 1.10), "normal Headbutt knockback velocity should include level scale")
	_expect(is_equal_approx(boss_ai.last_frames, 30.0), "normal Headbutt should use the 30-frame knockback window")
	_expect(is_equal_approx(boss_ai.last_decay, 0.91), "normal Headbutt should use the headbutt decay")
	_expect(boss_ai.last_replace, "normal Headbutt should replace existing paddle-hit knockback")
	_expect(status_state.calls.is_empty(), "normal non-mega Headbutt should not apply a boss stun")
	_expect(audio.boomerang_hit_count == 1, "normal Headbutt should play the boomerang-hit cue")
	_expect(str(skill.get_snapshot().get("headbutt_last_result", "")) == "hit", "normal Headbutt snapshot should report hit")


func _verify_onimaru_hit_stun_and_self_stun() -> void:
	var onimaru_lv1: Dictionary = LingpetCatalog.get_active_skill("onimaru", "onimaru_headbutt", 1)
	var context: Dictionary = onimaru_lv1.duplicate(true)
	context["active_skill_level"] = 1

	var skill := HeadbuttSkill.new()
	var owner := FakeOwner.new()
	owner.boss_vel = 30.0
	var boss_ai := FakeBossAiState.new()
	var status_state := FakeStatusEffectState.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new({
		"boss_ai_state": boss_ai,
		"status_effect_state": status_state,
		"game_audio": audio,
		"battle_feedback_state": feedback,
	})
	context["registry"] = registry
	var launch_origin := Vector2(380.0, 600.0)
	_expect(skill.launch(launch_origin, owner, context), "Onimaru Headbutt should launch")
	var launch_snapshot: Dictionary = skill.get_snapshot()
	_expect(bool(launch_snapshot.get("headbutt_disable_moving_miss", false)), "Onimaru Headbutt should arm with moving-target misses disabled")
	_expect(int(launch_snapshot.get("headbutt_combo_total", 0)) == 1, "Onimaru Headbutt should stay single-hit")
	_expect(not bool(launch_snapshot.get("headbutt_mega_charging", false)), "Onimaru Headbutt should never enter the random mega charge")
	_expect(is_equal_approx(float(launch_snapshot.get("headbutt_dash_duration", 0.0)), 0.43), "Onimaru ground-slam dash should use the original HornCharge 0.43s charge window")
	_expect(audio.horn_charge_count == 1, "Onimaru ground-slam should play the legacy horncharge cue at launch")
	_expect(not skill.suppresses_companion_body_hit(), "Onimaru should still bounce the ball / strike DURING the charge (only the post-hit self-stun incapacitates it)")

	var initial_target := owner.boss_pos + Vector2(owner.boss_paddle_width * 0.5, owner.boss_hitbox_height * 0.5)
	var initial_distance := maxf(1.0, launch_origin.distance_to(initial_target))
	skill.update(0.10, owner, registry)
	var early_pos := skill.get_companion_position_override(launch_origin)
	var early_ratio := launch_origin.distance_to(early_pos) / initial_distance
	_expect(early_ratio < 0.12, "Onimaru ground-slam dash should accelerate from a slow start (progress^2), not move at constant speed")

	var hit := _step_until_hit(skill, owner, registry)
	_expect(hit, "Onimaru Headbutt should hit when the boss stays on the committed cast-time spot")
	_expect(skill.get_miss_count_for_tests() == 0, "Onimaru Headbutt should not record a random moving-target miss")
	_expect(boss_ai.knockback_calls == 0, "Onimaru hit stun should own knockback through status, not the paddle-hit channel")
	var stun_calls := status_state.get_calls_for_source("lingpet_headbutt_hit")
	_expect(stun_calls.size() == 1, "Onimaru Headbutt should apply exactly one per-hit stun")
	if stun_calls.size() == 1:
		var stun_call: Dictionary = stun_calls[0]
		var stun_data: Dictionary = stun_call.get("data", {})
		_expect(str(stun_call.get("target", "")) == "boss", "Onimaru Headbutt stun should target the boss")
		_expect(str(stun_call.get("status_id", "")) == "stun", "Onimaru Headbutt should apply stun")
		_expect(is_equal_approx(float(stun_call.get("duration_frames", 0.0)), 120.0), "Onimaru Lv.1 stun should last 2.0s / 120 frames")
		_expect(bool(stun_data.get("knockback_active", false)), "Onimaru stun should carry active knockback")
		# Knockback distance PARITY with the arena HornCharge (downtown/hero_skills.py:4586 =
		# 73 px/frame). The old 13 x 1.25 = 16.25 px/frame gave a ~170px generic-hit shove that
		# did NOT fly the boss to the wall like the original.
		var kb_vel := absf(float(stun_data.get("knockback_vel", 0.0)))
		var kb_frames := float(stun_data.get("knockback_frames", 0.0))
		var kb_decay := float(stun_data.get("knockback_decay_per_frame", 0.0))
		_expect(kb_vel >= 70.0, "Onimaru stun knockback velocity must match the original HornCharge ~73 px/frame, not the generic ~16 hit knockback")
		_expect(is_equal_approx(kb_frames, 30.0), "Onimaru stun knockback should keep the headbutt frame window")
		_expect(is_equal_approx(kb_decay, 0.91), "Onimaru stun knockback should keep the headbutt decay")
		# OUTCOME: the decaying per-frame velocity's total travel (vel * (1 - decay^frames) /
		# (1 - decay)) must fly the boss ACROSS the 760px field into the wall like the original,
		# not the old ~170px shove. Reverse-verified to FAIL on the pre-parity 16.25 px/frame.
		var kb_travel := kb_vel * (1.0 - pow(kb_decay, kb_frames)) / maxf(0.0001, 1.0 - kb_decay)
		_expect(kb_travel >= 700.0, "Onimaru knockback must carry the boss across the field into the wall (HornCharge parity), not a moderate mid-field shove")

	# Ground-slam impact feel (arena HornCharge parity): earthquake shake + heavy slam cue.
	var post_hit: Dictionary = skill.get_snapshot()
	_expect(bool(post_hit.get("headbutt_ground_slam", false)), "Onimaru headbutt should flag the ground-slam feel")
	_expect(feedback.shakes.size() >= 1, "Onimaru ground slam should trigger an earthquake screen shake on impact")
	if feedback.shakes.size() >= 1:
		# Locked to the heavy-quake tier: the old 0.40 / 8.0 (~3.2px, ~0.2s) read as no
		# shake next to the explosion VFX, so keep this well above it (0.60 / 24.0 ships).
		_expect(feedback.shakes[0].x >= 0.55, "Onimaru ground-slam shake amount must read as a heavy quake, not the old barely-there 0.4 impulse")
		_expect(feedback.shakes[0].y >= 20.0, "Onimaru ground-slam shake intensity must land in the heavy-explosion tier, not the old tiny 8.0 jitter")
	_expect(audio.horn_charge_count == 1, "Onimaru ground slam should not replay the launch horncharge cue on impact")
	_expect(audio.dynamite_count == 0, "Onimaru ground slam should use the dedicated horncharge cue instead of the dynamite/grenade fallback")
	_expect(audio.boomerang_hit_count == 0, "Onimaru ground slam should NOT fall back to the light boomerang hit sound")

	# After impact Onimaru recoils back toward its launch lane BEFORE the self-stun begins.
	_expect(bool(post_hit.get("headbutt_returning", false)), "Onimaru should recoil/return toward the launch origin before the self-stun")
	_expect(not bool(post_hit.get("headbutt_self_stun_active", false)), "self-stun should not start until the recoil return completes")
	_expect(skill.suppresses_companion_body_hit(), "the dazed pet must stay incapacitated during the recoil return too")

	_step_seconds(skill, owner, registry, 0.6)
	var stunned: Dictionary = skill.get_snapshot()
	_expect(not bool(stunned.get("headbutt_returning", false)), "recoil return should finish")
	_expect(bool(stunned.get("headbutt_self_stun_active", false)), "Onimaru should enter self-stun after returning home")
	_expect(is_equal_approx(float(stunned.get("headbutt_self_stun_seconds", 0.0)), 5.0), "Onimaru Lv.1 self-stun should be 5.0s")
	_expect(skill.get_companion_position_override(Vector2.ZERO).distance_to(launch_origin) <= 1.0, "Onimaru should be stunned back at its launch lane, not parked at the boss")
	_expect(skill.is_active() and skill.has_companion_position_override(), "self-stun should keep owning the companion body position")
	_expect(skill.suppresses_companion_body_hit(), "Onimaru self-stun MUST suppress companion body hit + anticipatory strike (the incapacitated pet cannot bounce the ball)")

	_step_seconds(skill, owner, registry, 5.1)
	_expect(not bool(skill.get_snapshot().get("headbutt_self_stun_active", false)), "Onimaru self-stun should clear after its timer")
	_expect(not skill.is_active(), "Onimaru should become idle once self-stun and impact timers have cleared")
	_expect(not skill.suppresses_companion_body_hit(), "body hit should resume once the self-stun ends")

	# Committed-slam DODGE: the slam locks onto the boss's cast-time spot and does NOT
	# re-track, so a boss that leaves that spot during the dash makes the pet slam the
	# empty wall -- shake + VFX still fire, but the boss takes NO stun/knockback.
	var dodge_owner := FakeOwner.new()
	dodge_owner.boss_pos = Vector2(330.0, 25.0)
	var dodge_audio := FakeAudio.new()
	var dodge_feedback := FakeFeedback.new()
	var dodge_status := FakeStatusEffectState.new()
	var dodge_registry := FakeRegistry.new({
		"boss_ai_state": FakeBossAiState.new(),
		"status_effect_state": dodge_status,
		"game_audio": dodge_audio,
		"battle_feedback_state": dodge_feedback,
	})
	var dodge_context: Dictionary = onimaru_lv1.duplicate(true)
	dodge_context["active_skill_level"] = 1
	dodge_context["registry"] = dodge_registry
	var dodge_skill := HeadbuttSkill.new()
	_expect(dodge_skill.launch(Vector2(380.0, 600.0), dodge_owner, dodge_context), "committed slam should launch")
	var dodge_initial_target := dodge_owner.boss_pos + Vector2(dodge_owner.boss_paddle_width * 0.5, dodge_owner.boss_hitbox_height * 0.5)
	var dodge_launch_snap: Dictionary = dodge_skill.get_snapshot()
	_expect((dodge_launch_snap.get("headbutt_fixed_target", Vector2.ZERO) as Vector2).distance_to(dodge_initial_target) <= 0.01, "committed slam should lock the cast-time boss center as its fixed wall target")
	# Boss flees far from the locked spot before the dash lands.
	dodge_owner.boss_pos = Vector2(330.0 + 260.0, 25.0)
	for _i in range(40):
		dodge_skill.update(0.05, dodge_owner, dodge_registry)
		var lr := str(dodge_skill.get_snapshot().get("headbutt_last_result", ""))
		if lr == "wall_slam" or lr == "hit":
			break
	var dodge_snap: Dictionary = dodge_skill.get_snapshot()
	_expect(str(dodge_snap.get("headbutt_last_result", "")) == "wall_slam", "a boss that leaves the locked spot should make the slam hit empty wall (wall_slam), not the boss")
	_expect((dodge_snap.get("headbutt_fixed_target", Vector2.ZERO) as Vector2).distance_to(dodge_initial_target) <= 0.01, "committed slam must keep the original fixed wall target after the boss moves")
	_expect(dodge_skill.get_hit_count_for_tests() == 0, "a dodged slam should not count as a boss hit")
	_expect(dodge_status.get_calls_for_source("lingpet_headbutt_hit").size() == 0, "a dodged / empty-wall slam must NOT stun or knock back the boss")
	_expect(dodge_feedback.shakes.size() >= 1, "the empty-wall slam should STILL shake the screen (the slam landed on the wall)")
	# And a boss that STAYS on the locked spot is still hit (control case).
	var stay_owner := FakeOwner.new()
	stay_owner.boss_pos = Vector2(330.0, 25.0)
	var stay_status := FakeStatusEffectState.new()
	var stay_registry := FakeRegistry.new({
		"boss_ai_state": FakeBossAiState.new(),
		"status_effect_state": stay_status,
		"game_audio": FakeAudio.new(),
		"battle_feedback_state": FakeFeedback.new(),
	})
	var stay_context: Dictionary = onimaru_lv1.duplicate(true)
	stay_context["active_skill_level"] = 1
	stay_context["registry"] = stay_registry
	var stay_skill := HeadbuttSkill.new()
	_expect(stay_skill.launch(Vector2(380.0, 600.0), stay_owner, stay_context), "committed slam (stay case) should launch")
	var stay_target := stay_owner.boss_pos + Vector2(stay_owner.boss_paddle_width * 0.5, stay_owner.boss_hitbox_height * 0.5)
	_expect((stay_skill.get_snapshot().get("headbutt_fixed_target", Vector2.ZERO) as Vector2).distance_to(stay_target) <= 0.01, "stay case should lock the same cast-time wall target")
	for _j in range(40):
		stay_skill.update(0.05, stay_owner, stay_registry)
		var lr2 := str(stay_skill.get_snapshot().get("headbutt_last_result", ""))
		if lr2 == "wall_slam" or lr2 == "hit":
			break
	_expect(str(stay_skill.get_snapshot().get("headbutt_last_result", "")) == "hit", "a boss that stays on the locked spot should be hit by the committed slam")
	_expect(stay_status.get_calls_for_source("lingpet_headbutt_hit").size() == 1, "a boss hit on the locked spot should take the per-hit stun + knockback")


func _verify_onimaru_slam_radius_scales_catch() -> void:
	# A boss that flees the SAME distance (175px, leaving its edge ~125px from the locked
	# spot) is DODGED at Lv.1 (80px blast radius) but CAUGHT at Lv.5 (160px blast radius).
	# This proves the real stun-catch radius -- not just the VFX -- widens with level.
	var results := {}
	for level in [1, 5]:
		var owner := FakeOwner.new()
		owner.boss_pos = Vector2(330.0, 25.0)
		var status := FakeStatusEffectState.new()
		var registry := FakeRegistry.new({
			"boss_ai_state": FakeBossAiState.new(),
			"status_effect_state": status,
			"game_audio": FakeAudio.new(),
			"battle_feedback_state": FakeFeedback.new(),
		})
		var ctx: Dictionary = LingpetCatalog.get_active_skill("onimaru", "onimaru_headbutt", level).duplicate(true)
		ctx["active_skill_level"] = level
		ctx["registry"] = registry
		var skill := HeadbuttSkill.new()
		_expect(skill.launch(Vector2(380.0, 600.0), owner, ctx), "slam-radius case Lv.%d should launch" % level)
		_expect(float(skill.get_snapshot().get("headbutt_slam_radius", 0.0)) > 0.0, "Lv.%d should resolve a positive slam radius" % level)
		# Boss slides 175px from the locked spot before the dash lands.
		owner.boss_pos = Vector2(330.0 + 175.0, 25.0)
		for _i in range(40):
			skill.update(0.05, owner, registry)
			var lr := str(skill.get_snapshot().get("headbutt_last_result", ""))
			if lr == "wall_slam" or lr == "hit":
				break
		results[level] = str(skill.get_snapshot().get("headbutt_last_result", ""))
	_expect(str(results.get(1, "")) == "wall_slam", "Lv.1 small blast radius should let a 175px-fleeing boss dodge into an empty-wall slam")
	_expect(str(results.get(5, "")) == "hit", "Lv.5 wide blast radius should still catch the same 175px-fleeing boss (real stun radius grew)")


func _verify_mega_stun_owns_knockback() -> void:
	var skill := HeadbuttSkill.new()
	var owner := FakeOwner.new()
	var boss_ai := FakeBossAiState.new()
	var status_state := FakeStatusEffectState.new()
	var registry := FakeRegistry.new({
		"boss_ai_state": boss_ai,
		"status_effect_state": status_state,
		"game_audio": FakeAudio.new(),
	})
	var context := {
		"active_skill_level": 5,
		"knockback_scale": 1.40,
		"headbutt_count": 3,
		"mega_chance": 0.25,
		"mega_knockback_bonus_pct": 0.50,
		"mega_stun_seconds": 1.5,
		"headbutt_mega_roll": 0.0,
	}
	_expect(skill.launch(Vector2(380.0, 600.0), owner, context), "forced Mega Headbutt should launch")
	var launch_snapshot: Dictionary = skill.get_snapshot()
	_expect(bool(launch_snapshot.get("headbutt_is_mega", false)), "forced roll should trigger Mega Headbutt")
	_expect(bool(launch_snapshot.get("headbutt_mega_charging", false)), "Mega Headbutt should charge before dashing")
	_expect(int(launch_snapshot.get("headbutt_combo_total", 0)) == 1, "Mega Headbutt should collapse combo to one hit")
	skill.update(1.0, owner, registry)
	_expect(skill.get_hit_count_for_tests() == 0, "Mega Headbutt should not hit during charge")

	var hit := _step_until_hit(skill, owner, registry)
	_expect(hit, "Mega Headbutt should hit after charge completion")
	_expect(boss_ai.knockback_calls == 0, "Mega Headbutt should not use the paddle-hit knockback channel")
	var stun_calls := status_state.get_calls_for_source("lingpet_headbutt_mega")
	_expect(stun_calls.size() == 1, "Mega Headbutt should apply exactly one mega stun")
	if stun_calls.size() == 1:
		var stun_call: Dictionary = stun_calls[0]
		var stun_data: Dictionary = stun_call.get("data", {})
		_expect(is_equal_approx(float(stun_call.get("duration_frames", 0.0)), 90.0), "Mega Lv.5 stun should last 1.5s / 90 frames")
		_expect(str(stun_data.get("source", "")) == "lingpet_headbutt_mega", "Mega stun data should keep the mega source")
		_expect(bool(stun_data.get("knockback_active", false)), "Mega stun should carry knockback")
		_expect(is_equal_approx(absf(float(stun_data.get("knockback_vel", 0.0))), 13.0 * 1.40 * 1.50), "Mega stun knockback should compound scale and mega bonus")
		_expect(is_equal_approx(float(stun_data.get("knockback_frames", 0.0)), 30.0), "Mega stun knockback should keep the headbutt frame window")
		_expect(is_equal_approx(float(stun_data.get("knockback_decay_per_frame", 0.0)), 0.91), "Mega stun knockback should keep the headbutt decay")
	var hit_snapshot: Dictionary = skill.get_snapshot()
	_expect(str(hit_snapshot.get("headbutt_last_result", "")) == "mega_hit", "Mega Headbutt snapshot should report mega_hit")
	_expect(bool(hit_snapshot.get("headbutt_mega_impact", false)), "Mega Headbutt should expose its impact VFX flag")


func _verify_runtime_host_routes_headbutt_state() -> void:
	var host := LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"boss_ai_state": FakeBossAiState.new(),
		"game_audio": FakeAudio.new(),
	})
	var context := {
		"active_skill_level": 1,
		"knockback_scale": 1.10,
		"headbutt_count": 1,
		"mega_chance": 0.0,
	}
	_expect(host.launch("lunabi_headbutt", Vector2(380.0, 600.0), owner, context), "runtime host should launch Lunabi Headbutt")
	_expect(host.has_companion_position_override("lunabi_headbutt"), "runtime host should expose Headbutt position override while active")
	_expect(host.is_launch_blocked("lunabi_headbutt"), "runtime host should block another Headbutt while the dash owns the body")
	_expect(bool(host.get_snapshot().get("headbutt_active", false)), "runtime host snapshot should merge Headbutt state")
	host.update(0.05, owner, registry, "lunabi_headbutt")
	_expect(bool(host.has_visible_effects_for_skill("lunabi_headbutt")), "runtime host should expose Headbutt visible effects after update")
	_expect(not host.suppresses_companion_body_hit("lunabi_headbutt"), "Lunabi Headbutt (no self-stun) must never suppress the companion body hit")

	# Drive a separate host through Onimaru's headbutt to self-stun and confirm the host
	# routes the body-hit suppression (this is the path lingpet_egg_runtime + the strike
	# anticipator consult; a missing SKILL_KIND_HEADBUTT case here would let the stunned
	# pet keep bouncing the ball).
	var onimaru_host := LingpetSkillRuntimeHost.new()
	var onimaru_owner := FakeOwner.new()
	onimaru_owner.boss_vel = 30.0
	var onimaru_registry := FakeRegistry.new({
		"boss_ai_state": FakeBossAiState.new(),
		"status_effect_state": FakeStatusEffectState.new(),
		"game_audio": FakeAudio.new(),
	})
	var onimaru_ctx: Dictionary = LingpetCatalog.get_active_skill("onimaru", "onimaru_headbutt", 1).duplicate(true)
	onimaru_ctx["active_skill_level"] = 1
	_expect(onimaru_host.launch("onimaru_headbutt", Vector2(380.0, 600.0), onimaru_owner, onimaru_ctx), "runtime host should launch Onimaru Headbutt")
	_expect(not onimaru_host.suppresses_companion_body_hit("onimaru_headbutt"), "Onimaru should NOT suppress body hit during the charge")
	var onimaru_self_stunned := false
	for _i in range(80):
		onimaru_host.update(0.05, onimaru_owner, onimaru_registry, "onimaru_headbutt")
		if onimaru_host.suppresses_companion_body_hit("onimaru_headbutt"):
			onimaru_self_stunned = true
			break
	_expect(onimaru_self_stunned, "runtime host must route Onimaru's self-stun body-hit suppression through suppresses_companion_body_hit()")


func _step_until_hit(skill: Object, owner: Object, registry: Object, max_steps: int = 80) -> bool:
	for _i in range(max_steps):
		skill.update(0.05, owner, registry)
		if int(skill.get_hit_count_for_tests()) > 0:
			return true
	return false


func _step_until_result(skill: Object, owner: Object, registry: Object, max_steps: int = 80) -> void:
	for _i in range(max_steps):
		skill.update(0.05, owner, registry)
		if int(skill.get_hit_count_for_tests()) > 0 or int(skill.get_miss_count_for_tests()) > 0:
			return


func _step_seconds(skill: Object, owner: Object, registry: Object, seconds: float) -> void:
	var remaining := maxf(0.0, seconds)
	while remaining > 0.0:
		var step := minf(0.05, remaining)
		skill.update(step, owner, registry)
		remaining -= step


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + signature.length())
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)
