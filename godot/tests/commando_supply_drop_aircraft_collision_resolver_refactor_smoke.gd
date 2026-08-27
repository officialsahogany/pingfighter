extends SceneTree

const RESOLVER_PATH := "res://scripts/characters/commando_supply_drop_aircraft_collision_resolver.gd"
const CRASH_RESPONSE_PATH := "res://scripts/characters/commando_supply_drop_crash_response.gd"
const HOST_PATH := "res://scripts/characters/commando_supply_drop_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_player_rect_and_obstacle_priority()
	_verify_swept_ball_hit_and_reflection()
	_verify_crash_blast_ball_impulse()
	_verify_player_blast_knockback()

	if _failures.is_empty():
		print("commando_supply_drop_aircraft_collision_resolver_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(RESOLVER_PATH), "Commando Supply Drop aircraft collisions should have a focused resolver")
	if not FileAccess.file_exists(RESOLVER_PATH):
		return
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var resolver_source := FileAccess.get_file_as_string(RESOLVER_PATH)
	var crash_response_source := FileAccess.get_file_as_string(CRASH_RESPONSE_PATH)
	_expect(
		host_source.find("const CommandoSupplyDropAircraftCollisionResolver := preload(\"%s\")" % RESOLVER_PATH) >= 0,
		"Supply Drop host should preload the focused aircraft collision resolver"
	)
	_expect(
		host_source.find("var _collision_resolver: Object = CommandoSupplyDropAircraftCollisionResolver.new()") >= 0,
		"Supply Drop host should retain one collision resolver instance"
	)
	for marker in [
		"func get_player_paddle_rect(",
		"func resolve_obstacle(",
		"func ball_path_hits(",
		"func reflect_aircraft_hit_velocity(",
		"func resolve_crash_ball_impulse(",
		"func resolve_player_blast_knockback(",
	]:
		_expect(resolver_source.find(marker) >= 0, "collision resolver should implement %s" % marker)
	for moved_marker in [
		"func _player_paddle_hits_aircraft(",
		"func _get_player_paddle_rect(",
		"func _find_aircraft_brick_hit(",
		"func _get_rect2(",
		"func _ball_path_hits_aircraft(",
	]:
		_expect(host_source.find(moved_marker) < 0, "Supply Drop host should not retain collision marker %s" % moved_marker)
	_expect(
		host_source.find("_collision_resolver.resolve_obstacle(") >= 0
		and host_source.find("AIRCRAFT_DEFAULT_HITBOX_PADDING") >= 0,
		"obstacle collision should delegate geometry and precedence"
	)
	_expect(
		host_source.find("_collision_resolver.ball_path_hits(") >= 0,
		"ball collision should delegate swept path geometry"
	)
	_expect(
		host_source.find("_crash_response.apply_pending_ball_impulse(") >= 0
		and crash_response_source.find("_collision_resolver.resolve_crash_ball_impulse(") >= 0,
		"ground blast should delegate ball impulse mutation and geometry"
	)


func _verify_player_rect_and_obstacle_priority() -> void:
	var resolver: Object = _new_resolver()
	if resolver == null:
		return
	var player_rect: Rect2 = resolver.get_player_paddle_rect({
		"player_pos": Vector2(100.0, 200.0),
		"player_paddle_size": Vector2(40.0, 20.0),
		"dash_acceleration_active": true,
		"dash_acceleration_height_bonus": 10.0,
		"dash_acceleration_width_bonus": 4.0,
	}, 5.0)
	_expect(player_rect == Rect2(93.0, 190.0, 54.0, 40.0), "player collision rect should preserve padding and centered dash-size expansion")
	var explicit_rect := Rect2(7.0, 8.0, 9.0, 10.0)
	_expect(
		resolver.get_player_paddle_rect({"player_paddle_rect": explicit_rect}, 5.0) == explicit_rect,
		"explicit player collision rect should take precedence"
	)
	var aircraft_rect := Rect2(100.0, 100.0, 96.0, 44.0)
	var both: Dictionary = resolver.resolve_obstacle(aircraft_rect, {
		"player_paddle_rect": Rect2(120.0, 110.0, 20.0, 20.0),
		"brick_walls": [Rect2(100.0, 100.0, 96.0, 44.0)],
	}, 5.0)
	_expect(str(both.get("source", "")) == "player_paddle", "player paddle should keep precedence over a simultaneous brick overlap")
	var brick: Dictionary = resolver.resolve_obstacle(aircraft_rect, {
		"brick_walls": ["invalid", {"rect": Rect2(180.0, 110.0, 40.0, 30.0)}],
	}, 5.0)
	_expect(str(brick.get("source", "")) == "brick_wall", "overlapping brick should be identified")
	_expect(int(brick.get("wall_index", -1)) == 1, "brick result should retain the source array index")
	_expect(brick.get("impact_pos", Vector2.ZERO) == aircraft_rect.get_center().lerp(Vector2(200.0, 125.0), 0.5), "brick impact should stay halfway between collision centers")


func _verify_swept_ball_hit_and_reflection() -> void:
	var resolver: Object = _new_resolver()
	if resolver == null:
		return
	var aircraft_rect := Rect2(100.0, 100.0, 96.0, 44.0)
	_expect(
		resolver.ball_path_hits(aircraft_rect, Vector2(148.0, 70.0), Vector2(148.0, 170.0), 0.0),
		"vertical swept path should hit the aircraft even when both endpoints are outside"
	)
	_expect(
		not resolver.ball_path_hits(aircraft_rect, Vector2(10.0, 10.0), Vector2(20.0, 20.0), 5.0),
		"distant swept path should miss the grown aircraft rect"
	)
	_expect(
		resolver.reflect_aircraft_hit_velocity(Vector2(3.0, -12.0), 0.5) == Vector2(3.0, 6.0),
		"aircraft hit should damp and reverse nonzero vertical velocity"
	)
	_expect(
		resolver.reflect_aircraft_hit_velocity(Vector2(3.0, 0.0), 0.5) == Vector2(3.0, 4.0),
		"horizontal-only ball should receive the shipped downward fallback"
	)


func _verify_crash_blast_ball_impulse() -> void:
	var resolver: Object = _new_resolver()
	if resolver == null:
		return
	var center := Vector2(300.0, 660.0)
	var impulse: Dictionary = resolver.resolve_crash_ball_impulse(
		center + Vector2(0.0, -40.0),
		Vector2(0.0, 5.0),
		center,
		160.0,
		16.0,
		22.0,
		0.35
	)
	_expect(bool(impulse.get("affected", false)), "ball inside the crash radius should receive an impulse")
	var velocity: Vector2 = impulse.get("ball_vel", Vector2.ZERO)
	_expect(velocity.y < 0.0, "crash impulse should enforce an upward launch bias")
	_expect(velocity.length() <= 22.01, "crash impulse should respect the configured speed ceiling")
	_expect(
		resolver.resolve_crash_ball_impulse(center + Vector2(0.0, -200.0), Vector2.ZERO, center, 160.0, 16.0, 22.0, 0.35).is_empty(),
		"ball outside the crash radius should remain untouched"
	)
	var fast: Dictionary = resolver.resolve_crash_ball_impulse(
		center + Vector2(20.0, -20.0),
		Vector2(30.0, 0.0),
		center,
		160.0,
		16.0,
		22.0,
		0.35
	)
	_expect((fast.get("ball_vel", Vector2.ZERO) as Vector2).length() <= 30.01, "blast must not exceed an already-fast ball's existing speed")


func _verify_player_blast_knockback() -> void:
	var resolver: Object = _new_resolver()
	if resolver == null:
		return
	var center := Vector2(300.0, 660.0)
	var left: Dictionary = resolver.resolve_player_blast_knockback(
		Rect2(140.0, 640.0, 80.0, 40.0),
		center,
		160.0,
		1.0,
		36.0
	)
	_expect(bool(left.get("affected", false)), "paddle touching the blast edge should be affected")
	_expect_close(float(left.get("velocity", 0.0)), -36.0, "paddle left of the blast should be shoved left")
	var centered: Dictionary = resolver.resolve_player_blast_knockback(
		Rect2(260.0, 640.0, 80.0, 40.0),
		center,
		160.0,
		-1.0,
		36.0
	)
	_expect_close(float(centered.get("velocity", 0.0)), -36.0, "centered paddle should use the flight-direction fallback")
	_expect(
		resolver.resolve_player_blast_knockback(Rect2(0.0, 0.0, 40.0, 20.0), center, 160.0, 1.0, 36.0).is_empty(),
		"distant paddle should not receive crash knockback"
	)


func _new_resolver() -> Object:
	if not FileAccess.file_exists(RESOLVER_PATH):
		return null
	var resolver_script: Script = load(RESOLVER_PATH)
	return resolver_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.5f, got %.5f)" % [message, expected, actual])
