extends SceneTree

const BallIntensity := preload("res://scripts/ball/ball_intensity.gd")
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


func _build_owner_at(pos: Vector2) -> FakeOwner:
	var owner := FakeOwner.new()
	owner.ball_pos = pos
	return owner


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
