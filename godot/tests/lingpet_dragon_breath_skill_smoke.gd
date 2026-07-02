extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const LingpetDragonBreathSkill := preload("res://scripts/lingpet/lingpet_dragon_breath_skill.gd")
const LingpetDragonBreathPayloadFactory := preload("res://scripts/lingpet/lingpet_dragon_breath_payload_factory.gd")

const SKILL_ID := "red_dragon_dragon_breath"
const FIRE_STATUS_SOURCE := "red_dragon_dragon_breath_fire"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var boss_pos := Vector2(330.0, 25.0)
	var boss_pos_prev := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var current_stage := 1
	var ball_active := true
	var ball_pos := Vector2(380.0, 658.0)
	var ball_vel := Vector2(0.0, -260.0)
	var ball_size := 28.6


class FakeStatusEffectState:
	extends RefCounted

	var calls: Array[Dictionary] = []
	var clears: Array[Dictionary] = []

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

	func clear_status(target: String, status_id: String = "", source: String = "") -> void:
		clears.append({
			"target": target,
			"status_id": status_id,
			"source": source,
		})

	func get_calls_for_source(source: String) -> Array[Dictionary]:
		var matches: Array[Dictionary] = []
		for status_call in calls:
			if str(status_call.get("source", "")) == source:
				matches.append(status_call)
		return matches


class FakeAudio:
	extends RefCounted

	var launch_count := 0
	var low_fire_count := 0
	var fallback_count := 0
	var ball_hit_sfx_count := 0

	func play_dragon_breath_fire(low_volume: bool = false) -> void:
		if low_volume:
			low_fire_count += 1
		else:
			launch_count += 1

	# Ball strikes use their own deflect cue so the fire-zone low-fire assertion
	# stays meaningful (not bumped by ball hits falling back to the fire sound).
	func play_dragon_breath_ball_hit() -> void:
		ball_hit_sfx_count += 1

	func play_molotov_explosion() -> void:
		fallback_count += 1


class FakeFeedback:
	extends RefCounted

	var shake_count := 0

	func max_screen_shake(_duration: float, _strength: float) -> void:
		shake_count += 1


class FakeBossAi:
	extends RefCounted

	var boss_dash_active := false
	var cancel_count := 0

	func cancel_dash_for_fire_block(_stun_seconds: float = 0.6, _audio: Object = null) -> bool:
		cancel_count += 1
		if not boss_dash_active:
			return false
		boss_dash_active = false
		return true


class FakeRegistry:
	extends RefCounted

	var status_effect_state: Object = null
	var game_audio: Object = null
	var battle_feedback_state: Object = null
	var boss_ai_state: Object = null

	func _init(status_state: Object = null, audio: Object = null, feedback: Object = null, boss_ai: Object = null) -> void:
		status_effect_state = status_state
		game_audio = audio
		battle_feedback_state = feedback
		boss_ai_state = boss_ai

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		if key == "status_effect_state":
			return status_effect_state
		if key == "game_audio":
			return game_audio
		if key == "battle_feedback_state":
			return battle_feedback_state
		if key == "boss_ai_state":
			return boss_ai_state
		return null


func _init() -> void:
	seed(123456)
	_verify_dispatcher_and_catalog()
	_verify_center_arm_gate()
	_verify_runtime_ball_boost_and_fire_zone()
	_verify_breath_field_reflects_distant_ball()
	_verify_reset_clears_fire_slow()
	_verify_fire_zone_crossing_barrier_and_dash_cancel()
	_verify_fire_zone_bounce_is_paced_not_jittery()

	if _failures.is_empty():
		print("lingpet_dragon_breath_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_and_catalog() -> void:
	_expect(LingpetSkillDispatcher.is_supported_kind("dragon_breath"), "dragon_breath should be a supported lingpet runtime kind")
	_expect(LingpetSkillDispatcher.has_supported_runtime(SKILL_ID), "Red Dragon Dragon Breath should route to a supported runtime")
	_expect(LingpetSkillDispatcher.is_dragon_breath(SKILL_ID), "dispatcher should expose a Dragon Breath helper")

	var skill: Dictionary = LingpetCatalog.get_active_skill_entry(SKILL_ID)
	_expect(not skill.is_empty(), "Red Dragon catalog should expose Dragon Breath metadata")
	_expect(str(skill.get("runtime_kind", "")) == "dragon_breath", "Dragon Breath metadata should use the dragon_breath runtime kind")
	_expect(str(skill.get("name", "")) == "드래곤 브레스", "Dragon Breath should keep its Korean skill name")
	_expect(is_equal_approx(float(skill.get("cooldown", 0.0)), 40.0), "Dragon Breath should use the requested 40-second cooldown")
	_expect(str(LingpetCatalog.get_active_skill("red_dragon").get("id", "")) == SKILL_ID, "Red Dragon's default active skill should be Dragon Breath")
	_expect(str(LingpetCatalog.build_default_loadout("red_dragon").get("active_skill_id", "")) == SKILL_ID, "Red Dragon default loadout should choose Dragon Breath")
	_expect(LingpetRailCard.is_lingpet_skill({"id": SKILL_ID}), "shared rail-card helper should recognize Dragon Breath as a lingpet skill")
	_expect(LingpetCatalog.validate_catalog(true).is_empty(), "live lingpet catalog should validate after wiring Dragon Breath")


func _verify_center_arm_gate() -> void:
	# Red Dragon uses the sortie motion; the breath must only arm once it has
	# entered the center background, never during ingress at the screen edge.
	var host: Object = LingpetSkillRuntimeHost.new()
	var center := {"companion_visible": true, "companion_pos": Vector2(380.0, 300.0)}
	_expect(host.can_arm(SKILL_ID, center), "Dragon Breath should arm when the dragon is inside the center background")
	_expect(not host.can_arm(SKILL_ID, {"companion_visible": true, "companion_pos": Vector2(30.0, 300.0)}), "Dragon Breath must NOT arm at the left screen edge during ingress")
	_expect(not host.can_arm(SKILL_ID, {"companion_visible": true, "companion_pos": Vector2(735.0, 300.0)}), "Dragon Breath must NOT arm at the right screen edge during ingress")
	_expect(not host.can_arm(SKILL_ID, {"companion_visible": true, "companion_pos": Vector2(-190.0, 300.0)}), "Dragon Breath must NOT arm off-screen")
	_expect(not host.can_arm(SKILL_ID, {"companion_visible": false, "companion_pos": Vector2(380.0, 300.0)}), "Dragon Breath must NOT arm while the dragon is hidden")


func _verify_breath_field_reflects_distant_ball() -> void:
	# The breath heat cone must reflect a ball that sits inside the cone but far
	# from the mouth (where no ember sprite overlaps it). This is the path that
	# makes the reflection land in normal AI-companion play, not just when the
	# ball happens to touch a tiny ember near the origin.
	var skill: Object = load("res://scripts/lingpet/lingpet_dragon_breath_skill.gd").new()
	var owner := FakeOwner.new()
	owner.ball_pos = Vector2(380.0, 400.0)
	owner.ball_vel = Vector2(0.0, -200.0)
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(FakeStatusEffectState.new(), audio, FakeFeedback.new())
	var initial_speed := owner.ball_vel.length()
	skill.launch(Vector2(380.0, 690.0), owner)
	skill.update(1.0 / 60.0, owner, registry)
	_expect(int(skill.get_ball_hit_count_for_tests()) >= 1, "breath heat cone should reflect a ball inside it even with no ember on top of the ball")
	_expect(owner.ball_vel.y < 0.0, "field-reflected ball should be driven toward the boss")
	_expect(owner.ball_vel.length() > initial_speed * 1.25, "field-reflected ball should keep the original Ignis speed boost")
	_expect(audio.ball_hit_sfx_count >= 1, "breath ball strike should play an audible deflect cue so the hit is felt")


func _verify_runtime_ball_boost_and_fire_zone() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var status_state := FakeStatusEffectState.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new(status_state, audio, feedback)
	var launch_origin := Vector2(380.0, 690.0)
	var initial_speed := owner.ball_vel.length()

	_expect(host.launch(SKILL_ID, launch_origin, owner), "runtime host should launch Dragon Breath")
	host.trigger_launch_feedback(SKILL_ID, registry)
	_expect(audio.launch_count == 1, "Dragon Breath launch should play fire feedback through game_audio")
	_expect(host.is_launch_blocked(SKILL_ID), "Dragon Breath should block relaunch while breath particles or fire zones are active")

	var safety := 0
	while int(host.get_dragon_breath_ball_hit_count_for_tests()) == 0 and safety < 120:
		host.update(1.0 / 60.0, owner, registry, SKILL_ID)
		safety += 1
	_expect(int(host.get_dragon_breath_ball_hit_count_for_tests()) >= 1, "Dragon Breath particles should hit the active ball")
	_expect(owner.ball_vel.y < 0.0, "Dragon Breath from the player side should drive the ball toward the boss")
	_expect(owner.ball_vel.length() > initial_speed * 1.25, "Dragon Breath should boost ball speed by the original Ignis multiplier range")

	safety = 0
	while int(host.get_dragon_breath_fire_zone_spawn_count_for_tests()) == 0 and safety < 300:
		host.update(1.0 / 60.0, owner, registry, SKILL_ID)
		safety += 1
	_expect(int(host.get_dragon_breath_fire_zone_spawn_count_for_tests()) >= 1, "Dragon Breath dying flames should leave at least one fire zone")
	_expect(audio.low_fire_count >= 1, "Dragon Breath fire-zone spawn should play a low fire feedback cue")

	var snapshot: Dictionary = host.get_snapshot()
	var zone_pos: Vector2 = snapshot.get("dragon_breath_fire_zone_pos", Vector2.ZERO)
	# Place the boss just LEFT of the patch center so the bounce direction is
	# deterministic, then let several frames of the smooth bounce play out (the new
	# model eases the boss out over time instead of a one-frame hard-wall snap).
	owner.boss_pos = Vector2(
		zone_pos.x - owner.boss_paddle_width * 0.5 - 8.0,
		zone_pos.y - owner.boss_hitbox_height * 0.5
	)
	# Pre-AI side (drives both the bounce direction and the crossing barrier) is the
	# same left side; the actor driver would set this each physics frame.
	owner.boss_pos_prev = owner.boss_pos
	var boss_x_before := owner.boss_pos.x
	for _i in range(12):
		host.update(1.0 / 60.0, owner, registry, SKILL_ID)

	var slow_calls: Array[Dictionary] = status_state.get_calls_for_source(FIRE_STATUS_SOURCE)
	_expect(not slow_calls.is_empty(), "Dragon Breath fire zone should refresh a shared boss slow")
	if not slow_calls.is_empty():
		var first_call: Dictionary = slow_calls[0]
		_expect(str(first_call.get("target", "")) == "boss", "Dragon Breath slow should target the boss")
		_expect(str(first_call.get("status_id", "")) == "slow", "Dragon Breath should reuse the shared boss slow status")
		var data: Dictionary = first_call.get("data", {}) as Dictionary
		_expect(is_equal_approx(float(data.get("multiplier", 0.0)), 0.50), "Dragon Breath fire zone should apply the original 50 percent boss speed slow")
		_expect(str(data.get("visual", "")) == "red_dragon_dragon_breath", "Dragon Breath slow should tag its own visual id")
	# Smooth-bounce parity with the molotov fire zone: the boss is eased OUT of the
	# patch (leftward, its approach side) and is never shoved across to the far side.
	_expect(boss_x_before - owner.boss_pos.x >= 30.0, "Dragon Breath fire zone should ease the boss out of the flame patch (leftward)")
	_expect(owner.boss_pos.x + owner.boss_paddle_width * 0.5 <= zone_pos.x + 0.5, "Dragon Breath fire zone must not shove the boss across to the far side")
	_expect(feedback.shake_count >= 1, "Dragon Breath fire-zone bounce should send light battle feedback")


func _verify_fire_zone_crossing_barrier_and_dash_cancel() -> void:
	# Parity with the molotov barrier, but post-AI (dragon breath runs in
	# update_lingpet): a boss that crossed the patch midline this frame (e.g. a
	# 40px/frame dash, which moved it during update_boss_ai) must be clamped back
	# to its PRE-AI side, and an active dash must be cancelled so it stops ramming.
	var skill: Object = LingpetDragonBreathSkill.new()
	var owner := FakeOwner.new()
	var boss_ai := FakeBossAi.new()
	boss_ai.boss_dash_active = true
	var registry := FakeRegistry.new(FakeStatusEffectState.new(), FakeAudio.new(), FakeFeedback.new(), boss_ai)

	var zone_center := Vector2(380.0, 45.0)
	# Pre-AI the boss was LEFT of the patch; this frame it ended up on the RIGHT
	# side (it crossed), as a dash would leave it.
	owner.boss_pos_prev = Vector2(280.0, 25.0)  # center 330 (left of 380)
	owner.boss_pos = Vector2(400.0, 25.0)  # center 450 (right of 380 — crossed)
	var zone: Dictionary = LingpetDragonBreathPayloadFactory.build_fire_zone(zone_center, 100.0, 50.0, 2.0, 1)

	skill._apply_single_fire_zone(zone, owner, registry, 1.0 / 60.0)

	_expect(
		owner.boss_pos.x + owner.boss_paddle_width * 0.5 <= zone_center.x + 0.01,
		"a boss that crossed the patch must be clamped back to its pre-AI (left) side"
	)
	_expect(boss_ai.cancel_count >= 1, "crossing the patch should request a dash cancel")
	_expect(not boss_ai.boss_dash_active, "the rammed dash must be cancelled so it stops")


func _verify_fire_zone_bounce_is_paced_not_jittery() -> void:
	# A boss dragged into the patch every frame must NOT re-arm a bounce every
	# frame (the molotov "기괴한 떨림"): the velocity gate + short cooldown pace it.
	var skill: Object = LingpetDragonBreathSkill.new()
	var owner := FakeOwner.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new(FakeStatusEffectState.new(), FakeAudio.new(), feedback, FakeBossAi.new())
	var zone_center := Vector2(380.0, 45.0)
	var zone: Dictionary = LingpetDragonBreathPayloadFactory.build_fire_zone(zone_center, 100.0, 50.0, 2.0, 1)

	for _i in range(20):
		# Keep dragging the boss just left of the patch center every frame.
		owner.boss_pos_prev = Vector2(360.0, 25.0)  # center 410... keep it inside the band, left bias
		owner.boss_pos = Vector2(355.0, 25.0)  # center 405, inside contact band
		skill._apply_single_fire_zone(zone, owner, registry, 1.0 / 60.0)

	_expect(
		feedback.shake_count >= 1 and feedback.shake_count <= 4,
		"a boss held in the patch should bounce a couple of times over 20 frames (paced), never per-frame: got %d" % feedback.shake_count
	)


func _verify_reset_clears_fire_slow() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var status_state := FakeStatusEffectState.new()
	var registry := FakeRegistry.new(status_state, FakeAudio.new(), FakeFeedback.new())
	host.launch(SKILL_ID, Vector2(380.0, 690.0), owner)

	var safety := 0
	while int(host.get_dragon_breath_fire_zone_spawn_count_for_tests()) == 0 and safety < 320:
		host.update(1.0 / 60.0, owner, registry, SKILL_ID)
		safety += 1

	var snapshot: Dictionary = host.get_snapshot()
	var zone_pos: Vector2 = snapshot.get("dragon_breath_fire_zone_pos", Vector2.ZERO)
	owner.boss_pos = zone_pos - Vector2(owner.boss_paddle_width * 0.5, owner.boss_hitbox_height * 0.5)
	host.update(0.51, owner, registry, SKILL_ID)
	host.reset()
	_expect(_has_clear(status_state.clears, FIRE_STATUS_SOURCE), "Dragon Breath reset should clear its shared boss slow source")
	_expect(not host.has_visible_effects(), "Dragon Breath reset should remove breath particles and fire zones")


func _has_clear(clears: Array[Dictionary], source: String) -> bool:
	for clear_call in clears:
		if str(clear_call.get("source", "")) == source:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
