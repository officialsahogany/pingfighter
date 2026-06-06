extends SceneTree

const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetRailCard := preload("res://scripts/stages/common/lingpet_rail_card.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const LingpetSkillRuntimeHost := preload("res://scripts/lingpet/lingpet_skill_runtime_host.gd")

const SKILL_ID := "red_dragon_dragon_wing"

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_active := true
	var ball_pos := Vector2(380.0, 520.0)
	# ball_vel is px/frame in the live game (ball_speed_policy.gd: base 7.65,
	# normal speed cap ~26). The old fixture used 180 here, a px/second-scale
	# value that masked the unguardable speed blow-up Dragon Wing produced on a
	# real ~8 px/frame ball. Keep this fixture in the real px/frame band.
	var ball_vel := Vector2(0.0, 8.0)
	var ball_size := 28.6


class FakeAudio:
	extends RefCounted

	var launch_count := 0
	var ball_hit_count := 0
	var wall_hit_count := 0

	func play_active_item() -> void:
		launch_count += 1

	func play_dragon_breath_ball_hit() -> void:
		ball_hit_count += 1

	func play_wall_hit(_impact_speed: float) -> void:
		wall_hit_count += 1


class FakeRegistry:
	extends RefCounted

	var game_audio: Object = null

	func _init(audio: Object = null) -> void:
		game_audio = audio

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return game_audio
		return null


func _init() -> void:
	seed(20260605)
	_verify_dispatcher_and_catalog()
	_verify_runtime_wind_and_flying_dragon_hit()
	_verify_reset_clears_visible_effects()

	if _failures.is_empty():
		print("lingpet_dragon_wing_skill_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_dispatcher_and_catalog() -> void:
	_expect(LingpetSkillDispatcher.is_supported_kind("dragon_wing"), "dragon_wing should be a supported lingpet runtime kind")
	_expect(LingpetSkillDispatcher.has_supported_runtime(SKILL_ID), "Red Dragon Dragon Wing should route to a supported runtime")
	_expect(LingpetSkillDispatcher.is_dragon_wing(SKILL_ID), "dispatcher should expose a Dragon Wing helper")

	var skill: Dictionary = LingpetCatalog.get_active_skill_entry(SKILL_ID)
	_expect(not skill.is_empty(), "Red Dragon catalog should expose Dragon Wing metadata")
	_expect(str(skill.get("runtime_kind", "")) == "dragon_wing", "Dragon Wing metadata should use the dragon_wing runtime kind")
	_expect(str(skill.get("name", "")) == "용의 날개", "Dragon Wing should keep Ignis' Korean skill name")
	_expect(is_equal_approx(float(skill.get("cooldown", 0.0)), 15.0), "Dragon Wing should keep Ignis' 15-second cooldown")
	_expect(_active_pool_has(LingpetCatalog.get_active_skill_pool("red_dragon"), SKILL_ID), "Red Dragon active pool should include Dragon Wing")
	_expect(str(LingpetCatalog.get_active_skill("red_dragon").get("id", "")) == "red_dragon_dragon_breath", "Red Dragon default active skill should remain Dragon Breath")
	_expect(LingpetRailCard.is_lingpet_skill({"id": SKILL_ID}), "shared rail-card helper should recognize Dragon Wing as a lingpet skill")
	_expect(LingpetCatalog.validate_catalog(true).is_empty(), "live lingpet catalog should validate after wiring Dragon Wing")


func _verify_runtime_wind_and_flying_dragon_hit() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var registry := FakeRegistry.new(audio)
	var initial_vel := owner.ball_vel
	var launch_origin := Vector2(380.0, 520.0)

	_expect(host.launch(SKILL_ID, launch_origin, owner, {"companion_pos": launch_origin}), "runtime host should launch Dragon Wing")
	host.trigger_launch_feedback(SKILL_ID, registry)
	_expect(audio.launch_count == 1, "Dragon Wing launch should play active-item style feedback")
	_expect(host.is_launch_blocked(SKILL_ID), "Dragon Wing should block relaunch while wind / flying dragon effects are active")

	host.update(1.0 / 60.0, owner, registry, SKILL_ID)
	_expect(int(host.get_dragon_wing_wind_tick_count_for_tests()) >= 1, "Dragon Wing should apply at least one wind tick to the ball")
	_expect(not is_equal_approx(owner.ball_vel.x, initial_vel.x), "Dragon Wing wind should perturb the ball's x velocity")
	_expect(owner.ball_vel.y < initial_vel.y, "Dragon Wing wind should simultaneously push the ball upward toward the opponent")
	_expect(host.has_visible_effects(), "Dragon Wing should expose visible wind / dragon effects after launch")
	var active_snapshot: Dictionary = host.get_snapshot()
	_expect(is_equal_approx(absf(float(active_snapshot.get("dragon_wing_wind_force", 0.0))), 0.08), "Dragon Wing snapshot should expose the px/frame-scaled side wind force while active")
	_expect(float(active_snapshot.get("dragon_wing_opponent_y_wind_force", 0.0)) < 0.0, "Dragon Wing snapshot should expose the upward opponent-direction wind")
	_expect(int(active_snapshot.get("dragon_wing_swirl_tick_count", 0)) >= 1, "Dragon Wing should steer the ball through the spiral vortex")
	_expect(int(active_snapshot.get("dragon_wing_ball_swirl_trail_count", 0)) >= 1, "Dragon Wing should leave a visible spiral trail around the ball")

	var safety := 0
	while safety < 36:
		host.update(1.0 / 60.0, owner, registry, SKILL_ID)
		safety += 1
	_expect(int(host.get_dragon_wing_wind_tick_count_for_tests()) >= 30, "Dragon Wing should keep steering the ball through the active wind window")
	_expect(owner.ball_vel.y < initial_vel.y - 1.0, "Dragon Wing vortex should still make the ball drift upward")
	_expect(absf(owner.ball_vel.x) > 2.0, "Dragon Wing vortex should keep a readable side drift while the ball swirls")
	# Anti-OP guard: ball_vel is px/frame (base 7.65, game cap ~26). The vortex
	# must keep the ball in a guardable band, never the old ~640 px/frame launch.
	_expect(owner.ball_vel.length() <= 11.5, "Dragon Wing vortex must keep the ball inside a guardable px/frame speed band")

	while safety < 170:
		host.update(1.0 / 60.0, owner, registry, SKILL_ID)
		safety += 1
	_expect(owner.ball_vel.length() <= 11.5, "Dragon Wing vortex must stay speed-bounded for its whole duration")
	_expect(owner.ball_vel.y > -6.0, "Dragon Wing vortex should sweep, not launch the ball straight up unguardably")
	_expect(absf(owner.ball_vel.x) >= 2.0, "Dragon Wing vortex should retain a contestable side angle")

	var snapshot: Dictionary = host.get_snapshot()
	_expect(is_equal_approx(float(snapshot.get("dragon_wing_duration", 0.0)), 2.5), "Dragon Wing snapshot should expose Ignis' 2.5-second duration")
	_expect(int(snapshot.get("dragon_wing_swirl_tick_count", 0)) >= 30, "Dragon Wing snapshot should expose the active spiral tick count")
	_expect(int(snapshot.get("dragon_wing_ball_swirl_trail_count", 0)) > 0, "Dragon Wing snapshot should expose the visible spiral trail count")


func _verify_reset_clears_visible_effects() -> void:
	var host: Object = LingpetSkillRuntimeHost.new()
	var owner := FakeOwner.new()
	_expect(host.launch(SKILL_ID, Vector2(380.0, 520.0), owner), "Dragon Wing should launch before reset")
	_expect(host.has_visible_effects(), "Dragon Wing should be visible before reset")
	host.reset()
	_expect(not host.has_visible_effects(), "Dragon Wing reset should remove wind particles and flying dragon state")


func _active_pool_has(pool: Array[Dictionary], skill_id: String) -> bool:
	for skill in pool:
		if str(skill.get("id", "")) == skill_id:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
