extends SceneTree

const BallIntensity := preload("res://scripts/ball/ball_intensity.gd")
const BallPhysics := preload("res://scripts/ball/ball_physics.gd")
const LingpetCompanionBodyHitState := preload("res://scripts/lingpet/lingpet_companion_body_hit_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var ball_active := true
	var ball_pos := Vector2.ZERO
	var ball_vel := Vector2(0.0, 10.0)
	var ball_size := 28.6
	var max_bounce_angle := 60.0
	var special_gauge := 0.0
	var special_gauge_max := 500.0
	var current_stage := 1
	var rally_speed_cap_bonus := 0.0


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func _init(initial_instances: Dictionary = {}) -> void:
		instances = initial_instances

	func get_cached_instance(key: String) -> Object:
		return instances.get(key, null)

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


func _init() -> void:
	_verify_lingpet_contact_registers_player_side_actor()
	_verify_overlap_and_cooldown_do_not_double_register()
	_verify_strike_active_still_registers_contact()
	_verify_companion_guard_uses_ball_physics_speed_policy()
	_verify_companion_guard_uses_rally_floor()
	_verify_companion_guard_clamps_to_rally_cap()
	_verify_companion_guard_uses_junior_rally_floor()
	_verify_companion_guard_uses_fire_cap()
	_verify_companion_guard_saturates_rally_cap_bonus()
	_verify_companion_guard_clamps_oversized_bonus_on_bounce()
	_verify_missing_ball_intensity_is_safe()

	if _failures.is_empty():
		print("lingpet_companion_body_hit_intensity_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_lingpet_contact_registers_player_side_actor() -> void:
	var state := LingpetCompanionBodyHitState.new()
	var owner := _build_owner_at(Vector2(320.0, 540.0))
	var ball_intensity := BallIntensity.new()
	var registry := FakeRegistry.new({"ball_intensity": ball_intensity})
	var result: Dictionary = state.resolve_ball_hit(owner, registry, Vector2(320.0, 540.0), 100.0, 44.0, 0.0, true, false)
	_expect(bool(result.get("hit", false)), "companion overlap should resolve as a real hit")
	_expect(bool(result.get("should_begin_strike", false)), "inactive strike state should request the strike animation")
	_expect(ball_intensity.get_last_hit_by() == "player", "lingpet body hit should preserve legacy player side")
	_expect(ball_intensity.get_last_hit_side() == "player", "lingpet body hit should expose player side")
	_expect(ball_intensity.get_last_hit_actor() == "lingpet", "lingpet body hit should expose lingpet actor")
	_expect(str(ball_intensity.get_last_contact_tags().get("source", "")) == "companion_guard", "lingpet body hit should tag companion guard source")
	_expect(ball_intensity.get_rally_contact_count() == 1, "lingpet body hit should register one contact")
	_expect(ball_intensity.get_rally_exchange_count() == 0, "first lingpet body hit should not create an exchange")
	ball_intensity.register_hit("boss")
	_expect(ball_intensity.get_rally_exchange_count() == 1, "boss handoff after lingpet player-side hit should create one exchange")


func _verify_overlap_and_cooldown_do_not_double_register() -> void:
	var state := LingpetCompanionBodyHitState.new()
	var owner := _build_owner_at(Vector2(300.0, 500.0))
	var ball_intensity := BallIntensity.new()
	var registry := FakeRegistry.new({"ball_intensity": ball_intensity})
	var first: Dictionary = state.resolve_ball_hit(owner, registry, Vector2(300.0, 500.0), 100.0, 44.0, 0.0, true, false)
	_expect(bool(first.get("hit", false)), "first companion overlap should hit")
	owner.ball_pos = Vector2(300.0, 500.0)
	var second: Dictionary = state.resolve_ball_hit(owner, registry, Vector2(300.0, 500.0), 100.0, 44.0, 0.0, true, false)
	_expect(not bool(second.get("hit", false)), "continued overlap during cooldown should not hit again")
	_expect(ball_intensity.get_rally_contact_count() == 1, "continued overlap should not double-register ball intensity contact")


func _verify_strike_active_still_registers_contact() -> void:
	var state := LingpetCompanionBodyHitState.new()
	var owner := _build_owner_at(Vector2(280.0, 520.0))
	var ball_intensity := BallIntensity.new()
	var registry := FakeRegistry.new({"ball_intensity": ball_intensity})
	var result: Dictionary = state.resolve_ball_hit(owner, registry, Vector2(280.0, 520.0), 100.0, 44.0, 0.0, true, true)
	_expect(bool(result.get("hit", false)), "strike-active companion overlap should still resolve the body hit")
	_expect(not bool(result.get("should_begin_strike", true)), "strike-active body hit should not request another strike")
	_expect(ball_intensity.get_rally_contact_count() == 1, "strike-active body hit should still register ball intensity contact")
	_expect(ball_intensity.get_last_hit_actor() == "lingpet", "strike-active body hit should preserve lingpet actor")


func _verify_missing_ball_intensity_is_safe() -> void:
	var state := LingpetCompanionBodyHitState.new()
	var owner := _build_owner_at(Vector2(340.0, 510.0))
	var registry := FakeRegistry.new()
	var result: Dictionary = state.resolve_ball_hit(owner, registry, Vector2(340.0, 510.0), 100.0, 44.0, 0.0, true, false)
	_expect(bool(result.get("hit", false)), "missing ball_intensity should not block companion body hit")
	_expect(is_equal_approx(owner.ball_vel.length(), 10.0), "without ball_physics, companion guard should preserve the old bounce speed fallback")


func _verify_companion_guard_uses_ball_physics_speed_policy() -> void:
	var state := LingpetCompanionBodyHitState.new()
	var owner := _build_owner_at(Vector2(320.0, 540.0))
	owner.ball_vel = Vector2(0.0, 18.0)
	var registry := FakeRegistry.new({"ball_physics": BallPhysics.new()})
	var result: Dictionary = state.resolve_ball_hit(owner, registry, Vector2(320.0, 540.0), 100.0, 44.0, 0.0, true, false)
	_expect(bool(result.get("hit", false)), "companion speed-policy fixture should hit")
	_expect(owner.ball_vel.length() > 18.0, "companion guard should apply one dampened rally acceleration step instead of staying speed-neutral")
	_expect(is_equal_approx(owner.rally_speed_cap_bonus, 0.5), "companion guard should count as one rally-cap hit")


func _verify_companion_guard_uses_rally_floor() -> void:
	var state := LingpetCompanionBodyHitState.new()
	var owner := _build_owner_at(Vector2(320.0, 540.0))
	owner.ball_vel = Vector2(0.0, 2.0)
	var physics := BallPhysics.new()
	var registry := FakeRegistry.new({"ball_physics": physics})
	var result: Dictionary = state.resolve_ball_hit(owner, registry, Vector2(320.0, 540.0), 100.0, 44.0, 0.0, true, false)
	_expect(bool(result.get("hit", false)), "companion rally-floor fixture should hit")
	_expect(owner.ball_vel.length() >= float(physics.get_minimum_rally_speed()) - 0.001, "companion guard should raise low-speed balls to the rally floor")


func _verify_companion_guard_clamps_to_rally_cap() -> void:
	var state := LingpetCompanionBodyHitState.new()
	var owner := _build_owner_at(Vector2(320.0, 540.0))
	owner.ball_vel = Vector2(0.0, 40.0)
	var registry := FakeRegistry.new({"ball_physics": BallPhysics.new()})
	var result: Dictionary = state.resolve_ball_hit(owner, registry, Vector2(320.0, 540.0), 100.0, 44.0, 0.0, true, false)
	_expect(bool(result.get("hit", false)), "companion cap fixture should hit")
	_expect(owner.ball_vel.length() <= 26.001, "companion guard should clamp boosted speed to the active champion rally cap")


func _verify_companion_guard_uses_junior_rally_floor() -> void:
	var state := LingpetCompanionBodyHitState.new()
	var owner := _build_owner_at(Vector2(320.0, 540.0))
	owner.ball_vel = Vector2(0.0, 2.0)
	var physics := BallPhysics.new()
	physics.configure_context(1, "junior")
	var champion_physics := BallPhysics.new()
	var registry := FakeRegistry.new({"ball_physics": physics})
	var result: Dictionary = state.resolve_ball_hit(owner, registry, Vector2(320.0, 540.0), 100.0, 44.0, 0.0, true, false)
	_expect(bool(result.get("hit", false)), "companion junior floor fixture should hit")
	_expect(owner.ball_vel.length() >= float(physics.get_minimum_rally_speed()) - 0.001, "companion guard should use the junior rally floor")
	_expect(owner.ball_vel.length() < float(champion_physics.get_minimum_rally_speed()), "junior companion guard floor should stay below champion floor")


func _verify_companion_guard_uses_fire_cap() -> void:
	var state := LingpetCompanionBodyHitState.new()
	var owner := _build_owner_at(Vector2(320.0, 540.0))
	owner.ball_vel = Vector2(0.0, 80.0)
	owner.rally_speed_cap_bonus = 1.0
	var physics := BallPhysics.new()
	physics.configure_context(1, "champion", false, "fire")
	var registry := FakeRegistry.new({"ball_physics": physics})
	var result: Dictionary = state.resolve_ball_hit(owner, registry, Vector2(320.0, 540.0), 100.0, 44.0, 0.0, true, false)
	_expect(bool(result.get("hit", false)), "companion fire cap fixture should hit")
	_expect(owner.ball_vel.length() <= 36.001, "companion guard should clamp boosted speed to the fire rally cap plus current bonus")
	_expect(is_equal_approx(owner.rally_speed_cap_bonus, 1.5), "companion guard should advance the fire rally cap bonus for the next hit")


func _verify_companion_guard_saturates_rally_cap_bonus() -> void:
	var state := LingpetCompanionBodyHitState.new()
	var owner := _build_owner_at(Vector2(320.0, 540.0))
	owner.ball_vel = Vector2(0.0, 18.0)
	owner.rally_speed_cap_bonus = 9.8
	var registry := FakeRegistry.new({"ball_physics": BallPhysics.new()})
	var result: Dictionary = state.resolve_ball_hit(owner, registry, Vector2(320.0, 540.0), 100.0, 44.0, 0.0, true, false)
	_expect(bool(result.get("hit", false)), "companion saturation fixture should hit")
	_expect(is_equal_approx(owner.rally_speed_cap_bonus, 10.0), "companion guard should saturate the rally cap bonus at the shared ceiling")
	owner.ball_pos = Vector2(320.0, 540.0)
	owner.ball_vel = Vector2(0.0, 18.0)
	var second_state := LingpetCompanionBodyHitState.new()
	var second: Dictionary = second_state.resolve_ball_hit(owner, registry, Vector2(320.0, 540.0), 100.0, 44.0, 0.0, true, false)
	_expect(bool(second.get("hit", false)), "second companion saturation fixture should hit")
	_expect(is_equal_approx(owner.rally_speed_cap_bonus, 10.0), "repeated companion guards should not grow the bonus past the ceiling")


func _verify_companion_guard_clamps_oversized_bonus_on_bounce() -> void:
	var state := LingpetCompanionBodyHitState.new()
	var owner := _build_owner_at(Vector2(320.0, 540.0))
	owner.ball_vel = Vector2(0.0, 80.0)
	owner.rally_speed_cap_bonus = 50.0
	var registry := FakeRegistry.new({"ball_physics": BallPhysics.new()})
	var result: Dictionary = state.resolve_ball_hit(owner, registry, Vector2(320.0, 540.0), 100.0, 44.0, 0.0, true, false)
	_expect(bool(result.get("hit", false)), "companion oversized-bonus fixture should hit")
	_expect(owner.ball_vel.length() <= 36.001, "companion guard bounce should clamp an oversized stored bonus to the shared ceiling")
	_expect(is_equal_approx(owner.rally_speed_cap_bonus, 10.0), "companion guard should normalize an oversized stored bonus down to the ceiling")


func _build_owner_at(pos: Vector2) -> FakeOwner:
	var owner := FakeOwner.new()
	owner.ball_pos = pos
	return owner


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
