extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")
const GravityAccelSkill := preload("res://scripts/lingpet/lingpet_gravity_accel_skill.gd")

const SKILL_ID := "orbi_gravity_accel"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_active := true
	var ball_vel := Vector2(0.0, 8.0)
	var skip_ball_motion_step := false


class FakeAudio:
	extends RefCounted

	var cast_count := 0

	func play_lingpet_gravity_accel_cast() -> void:
		cast_count += 1

	func play_active_item() -> void:
		pass


class FakeAudioRegistry:
	extends RefCounted

	var audio: Object

	func _init(audio_double: Object) -> void:
		audio = audio_double

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		return null


func _init() -> void:
	_verify_dispatcher_and_catalog()
	_verify_descending_ball_is_pulled_up()
	_verify_rising_ball_accelerates_toward_boss()
	_verify_stronger_level_pulls_harder()
	_verify_duration_expiry()
	_verify_skip_motion_step_is_respected()
	_verify_host_routing()
	_verify_cast_audio_parity()

	if _failures.is_empty():
		print("lingpet_gravity_accel_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_and_catalog() -> void:
	_expect(LingpetSkillDispatcher.is_supported_kind("gravity_accel"), "gravity_accel should be a supported lingpet runtime kind")
	_expect(LingpetSkillDispatcher.is_gravity_accel(SKILL_ID), "dispatcher should route Serabi's Gravity Accel to the gravity_accel runtime")
	_expect(LingpetSkillDispatcher.has_supported_runtime(SKILL_ID), "orbi_gravity_accel should resolve to a supported runtime")

	var meta: Dictionary = LingpetCatalog.get_active_skill_entry(SKILL_ID)
	_expect(not meta.is_empty(), "catalog should expose the Gravity Accel skill metadata")
	_expect(str(meta.get("runtime_kind", "")) == "gravity_accel", "Gravity Accel metadata should use the gravity_accel runtime kind")
	_expect(str(meta.get("name", "")) == "중력가속", "Gravity Accel should keep its 중력가속 display name")

	var lv1: Dictionary = LingpetCatalog.get_active_skill("orbi", SKILL_ID, 1)
	var lv5: Dictionary = LingpetCatalog.get_active_skill("orbi", SKILL_ID, 5)
	_expect(float(lv5.get("duration_seconds", 0.0)) > float(lv1.get("duration_seconds", 0.0)), "duration should grow with level")
	_expect(float(lv5.get("gravity_strength", 0.0)) > float(lv1.get("gravity_strength", 0.0)), "gravity strength should grow with level")
	_expect(LingpetCatalog.validate_catalog(true).is_empty(), "Serabi Gravity Accel metadata should validate cleanly")


func _verify_descending_ball_is_pulled_up() -> void:
	var skill: Object = GravityAccelSkill.new()
	var owner := FakeOwner.new()
	owner.ball_vel = Vector2(0.0, 9.0)  # descending toward the player
	_expect(skill.launch(Vector2(380.0, 400.0), owner, _ctx(5)), "Gravity Accel should launch")
	_expect(skill.is_active(), "Gravity Accel should be active after launch")
	var before := owner.ball_vel.y
	for _i in range(4):
		skill.update(0.05, owner)
	_expect(owner.ball_vel.y < before, "a descending ball should be decelerated / dragged back up toward the boss")


func _verify_rising_ball_accelerates_toward_boss() -> void:
	var skill: Object = GravityAccelSkill.new()
	var owner := FakeOwner.new()
	owner.ball_vel = Vector2(0.0, -6.0)  # already rising toward the boss
	skill.launch(Vector2(380.0, 400.0), owner, _ctx(5))
	var before := owner.ball_vel.y
	for _i in range(3):
		skill.update(0.05, owner)
	_expect(owner.ball_vel.y < before, "a rising ball should be accelerated further toward the boss (more negative vy)")
	_expect(owner.ball_vel.y >= -GravityAccelSkill.MAX_VERTICAL_SPEED - 0.001, "vertical speed should stay within the safety cap")


func _verify_stronger_level_pulls_harder() -> void:
	var weak := _measure_upward_gain(1)
	var strong := _measure_upward_gain(5)
	_expect(strong > weak, "a higher level should pull the ball harder (Lv5 > Lv1 upward gain)")


func _measure_upward_gain(level: int) -> float:
	var skill: Object = GravityAccelSkill.new()
	var owner := FakeOwner.new()
	owner.ball_vel = Vector2(0.0, 9.0)
	skill.launch(Vector2(380.0, 400.0), owner, _ctx(level))
	var start := owner.ball_vel.y
	skill.update(0.05, owner)
	return start - owner.ball_vel.y  # positive = pulled upward


func _verify_duration_expiry() -> void:
	var skill: Object = GravityAccelSkill.new()
	var owner := FakeOwner.new()
	owner.ball_vel = Vector2(0.0, 8.0)
	skill.launch(Vector2(380.0, 400.0), owner, {"active_skill_level": 3, "duration_seconds": 2.0, "gravity_strength": 54.0})
	var elapsed := 0.0
	while elapsed < 2.4:
		skill.update(0.1, owner)
		elapsed += 0.1
	_expect(not skill.is_field_active(), "the gravity field should expire after its duration")
	# Let lingering particles fade out, then the skill is fully idle / re-castable.
	for _i in range(12):
		skill.update(0.1, owner)
	_expect(not skill.is_active(), "Gravity Accel should be fully idle once the field and particles end")


func _verify_skip_motion_step_is_respected() -> void:
	var skill: Object = GravityAccelSkill.new()
	var owner := FakeOwner.new()
	owner.ball_vel = Vector2(0.0, 9.0)
	owner.skip_ball_motion_step = true  # another owned-ball skill controls the ball
	skill.launch(Vector2(380.0, 400.0), owner, _ctx(5))
	var before := owner.ball_vel
	for _i in range(4):
		skill.update(0.05, owner)
	_expect(owner.ball_vel == before, "Gravity Accel must not fight an owned-ball skill while skip_ball_motion_step is set")


func _verify_host_routing() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	owner.ball_vel = Vector2(0.0, 9.0)
	_expect(not host.is_launch_blocked(SKILL_ID), "fresh host should not block Gravity Accel")
	_expect(host.launch(SKILL_ID, Vector2(380.0, 400.0), owner, _ctx(5)), "host should launch Gravity Accel through the dispatcher")
	_expect(host.is_launch_blocked(SKILL_ID), "Gravity Accel should block relaunch while active")
	var before := owner.ball_vel.y
	host.update(0.05, owner, null, SKILL_ID, _ctx(5))
	host.update(0.05, owner, null, SKILL_ID, _ctx(5))
	_expect(owner.ball_vel.y < before, "host update should route the gravity warp onto the ball")
	var snap: Dictionary = host.get_snapshot()
	_expect(bool(snap.get("gravity_accel_field_active", false)), "host snapshot should expose the gravity_accel field state")


func _verify_cast_audio_parity() -> void:
	# Original parity (downtown/hero_skills.py GravityControl): 'gravityaccel' on cast.
	var audio := FakeAudio.new()
	var host: Object = LingpetSkillRuntimeHost.new()
	host.trigger_launch_feedback(SKILL_ID, FakeAudioRegistry.new(audio))
	_expect(audio.cast_count == 1, "Gravity Accel cast feedback should play the dedicated gravityaccel cue, not generic active-item")


func _ctx(level: int) -> Dictionary:
	return {
		"active_skill_level": level,
		"duration_seconds": -1.0,
		"gravity_strength": -1.0,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
