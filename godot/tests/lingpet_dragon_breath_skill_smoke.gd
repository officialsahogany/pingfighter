extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")

const SKILL_ID := "red_dragon_dragon_breath"
const FIRE_STATUS_SOURCE := "red_dragon_dragon_breath_fire"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var boss_pos := Vector2(330.0, 25.0)
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

	func play_dragon_breath_fire(low_volume: bool = false) -> void:
		if low_volume:
			low_fire_count += 1
		else:
			launch_count += 1

	func play_molotov_explosion() -> void:
		fallback_count += 1


class FakeFeedback:
	extends RefCounted

	var shake_count := 0

	func max_screen_shake(_duration: float, _strength: float) -> void:
		shake_count += 1


class FakeRegistry:
	extends RefCounted

	var status_effect_state: Object = null
	var game_audio: Object = null
	var battle_feedback_state: Object = null

	func _init(status_state: Object = null, audio: Object = null, feedback: Object = null) -> void:
		status_effect_state = status_state
		game_audio = audio
		battle_feedback_state = feedback

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		if key == "status_effect_state":
			return status_effect_state
		if key == "game_audio":
			return game_audio
		if key == "battle_feedback_state":
			return battle_feedback_state
		return null


func _init() -> void:
	seed(123456)
	_verify_dispatcher_and_catalog()
	_verify_runtime_ball_boost_and_fire_zone()
	_verify_reset_clears_fire_slow()

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
	owner.boss_pos = zone_pos - Vector2(owner.boss_paddle_width * 0.5, owner.boss_hitbox_height * 0.5)
	var boss_x_before := owner.boss_pos.x
	host.update(0.51, owner, registry, SKILL_ID)

	var slow_calls: Array[Dictionary] = status_state.get_calls_for_source(FIRE_STATUS_SOURCE)
	_expect(not slow_calls.is_empty(), "Dragon Breath fire zone should refresh a shared boss slow")
	if not slow_calls.is_empty():
		var first_call: Dictionary = slow_calls[0]
		_expect(str(first_call.get("target", "")) == "boss", "Dragon Breath slow should target the boss")
		_expect(str(first_call.get("status_id", "")) == "slow", "Dragon Breath should reuse the shared boss slow status")
		var data: Dictionary = first_call.get("data", {}) as Dictionary
		_expect(is_equal_approx(float(data.get("multiplier", 0.0)), 0.50), "Dragon Breath fire zone should apply the original 50 percent boss speed slow")
		_expect(str(data.get("visual", "")) == "red_dragon_dragon_breath", "Dragon Breath slow should tag its own visual id")
	_expect(absf(owner.boss_pos.x - boss_x_before) >= 50.0, "Dragon Breath fire zone should push the boss out of the flame patch")
	_expect(absf(float(owner.boss_vel)) > 0.0, "Dragon Breath fire zone push should set a visible boss velocity impulse")
	_expect(feedback.shake_count >= 1, "Dragon Breath fire-zone push should send light battle feedback")


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
