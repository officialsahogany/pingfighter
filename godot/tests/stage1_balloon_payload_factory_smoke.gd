extends SceneTree

const GameplayStageModuleCatalog := preload("res://scripts/resources/gameplay_stage_module_catalog.gd")
const Stage1BalloonPayloadFactory := preload("res://scripts/stages/stage1/stage1_balloon_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	var balloon: Dictionary = Stage1BalloonPayloadFactory.build_balloon(
		Vector2(380.0, 375.0),
		0.5,
		3.5,
		32.0,
		Color(1.0, 0.5, 0.25, 1.0),
		1.25,
		true,
		3,
		180.0,
		-2.0
	)
	_expect(_as_vector2(balloon.get("pos", Vector2.ZERO), Vector2.ZERO) == Vector2(380.0, 375.0), "balloon payload should preserve spawn position")
	_expect(_as_vector2(balloon.get("vel", Vector2.ZERO), Vector2.ZERO).distance_to(Vector2(cos(0.5), sin(0.5)) * 3.5) <= 0.001, "balloon payload should derive velocity from angle and speed")
	_expect(float(balloon.get("radius", 0.0)) == 32.0, "balloon payload should preserve radius")
	_expect(balloon.get("color", null) == Color(1.0, 0.5, 0.25, 1.0), "balloon payload should preserve color")
	_expect(float(balloon.get("bounce", 0.0)) == 1.25, "balloon payload should preserve bounce phase")
	_expect(float(balloon.get("lifetime", -1.0)) == 0.0, "balloon payload should start at zero lifetime")
	_expect(bool(balloon.get("is_special", false)), "balloon payload should preserve special flag")
	_expect(int(balloon.get("sprite_index", -1)) == 3, "balloon payload should preserve sprite index")
	_expect(float(balloon.get("rotation", 0.0)) == 180.0, "balloon payload should preserve rotation")
	_expect(float(balloon.get("rotation_speed", 0.0)) == -2.0, "balloon payload should preserve rotation speed")
	_expect(float(balloon.get("paddle_bounce_cooldown", -1.0)) == 0.0, "balloon payload should start with no paddle cooldown")
	_expect(float(balloon.get("paddle_bounce_slow_timer", -1.0)) == 0.0, "balloon payload should start with no paddle slow timer")

	var absorbed_low: Dictionary = Stage1BalloonPayloadFactory.build_absorbed_balloon_payload(Vector2(20.0, 30.0), 12.0, Color.AQUA)
	var absorbed_mid: Dictionary = Stage1BalloonPayloadFactory.build_absorbed_balloon_payload(Vector2(20.0, 30.0), 30.0, Color.AQUA)
	var absorbed_high: Dictionary = Stage1BalloonPayloadFactory.build_absorbed_balloon_payload(Vector2(20.0, 30.0), 90.0, Color.AQUA)
	_expect(_as_vector2(absorbed_mid.get("position", Vector2.ZERO), Vector2.ZERO) == Vector2(20.0, 30.0), "absorbed balloon payload should preserve position")
	_expect(float(absorbed_low.get("strength", 0.0)) == 0.75, "absorbed balloon strength should clamp small balloons")
	_expect(float(absorbed_mid.get("strength", 0.0)) == 1.0, "absorbed balloon strength should scale from radius")
	_expect(float(absorbed_high.get("strength", 0.0)) == 1.55, "absorbed balloon strength should clamp large balloons")
	_expect(absorbed_mid.get("color", null) == Color.AQUA, "absorbed balloon payload should preserve color")

	var sprite_pop: Dictionary = Stage1BalloonPayloadFactory.build_sprite_pop_effect(
		Vector2(10.0, 11.0),
		28.0,
		false,
		6,
		4.0
	)
	_expect(str(sprite_pop.get("type", "")) == "sprite", "sprite pop effect should use sprite type")
	_expect(_as_vector2(sprite_pop.get("pos", Vector2.ZERO), Vector2.ZERO) == Vector2(10.0, 11.0), "sprite pop effect should preserve position")
	_expect(float(sprite_pop.get("timer", -1.0)) == 0.0, "sprite pop effect should start at timer zero")
	_expect(float(sprite_pop.get("life", 0.0)) == 24.0, "sprite pop effect should derive life from frame count and duration")
	_expect(float(sprite_pop.get("radius", 0.0)) == 28.0, "sprite pop effect should preserve radius")
	_expect(not bool(sprite_pop.get("is_special", true)), "sprite pop effect should preserve special flag")

	seed(12345)
	var normal_effects: Array[Dictionary] = Stage1BalloonPayloadFactory.build_fallback_pop_effects(
		Vector2(50.0, 60.0),
		Color(0.9, 0.4, 0.2, 1.0),
		30.0,
		false,
		10,
		12
	)
	_expect(normal_effects.size() == 11, "normal fallback pop should create one burst plus the normal particle count")
	_verify_burst(normal_effects[0], Vector2(50.0, 60.0), Color(0.9, 0.4, 0.2, 1.0), 66.0)
	for index in range(1, normal_effects.size()):
		_verify_particle(normal_effects[index], Vector2(50.0, 60.0), Color(0.9, 0.4, 0.2, 1.0))

	seed(12345)
	var special_effects: Array[Dictionary] = Stage1BalloonPayloadFactory.build_fallback_pop_effects(
		Vector2(50.0, 60.0),
		Color(1.0, 0.9, 0.25, 1.0),
		18.0,
		true,
		10,
		12
	)
	_expect(special_effects.size() == 13, "special fallback pop should create one burst plus the special particle count")
	_verify_burst(special_effects[0], Vector2(50.0, 60.0), Color(1.0, 0.9, 0.25, 1.0), 40.0)
	for index in range(1, special_effects.size()):
		_verify_particle(special_effects[index], Vector2(50.0, 60.0), Color(1.0, 0.9, 0.25, 1.0))

	var no_particle_effects: Array[Dictionary] = Stage1BalloonPayloadFactory.build_fallback_pop_effects(
		Vector2.ZERO,
		Color.WHITE,
		20.0,
		false,
		-1,
		12
	)
	_expect(no_particle_effects.size() == 1 and str(no_particle_effects[0].get("type", "")) == "burst", "negative fallback particle count should keep only the burst")

	var event_source: String = FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_balloon_event.gd")
	_expect(event_source.contains("Stage1BalloonPayloadFactory.build_balloon"), "Stage 1 balloon event should delegate balloon payload construction")
	_expect(event_source.contains("Stage1BalloonPayloadFactory.build_absorbed_balloon_payload"), "Stage 1 balloon event should delegate Chaos Spear absorb payload construction")
	_expect(event_source.contains("Stage1BalloonPayloadFactory.build_sprite_pop_effect"), "Stage 1 balloon event should delegate sprite pop payload construction")
	_expect(event_source.contains("Stage1BalloonPayloadFactory.build_fallback_pop_effects"), "Stage 1 balloon event should delegate fallback pop payload construction")

	var modules: Dictionary = GameplayStageModuleCatalog.MODULES
	_expect(modules.has("stage1_balloon_payload_factory"), "stage module catalog should list the Stage 1 balloon payload factory")

	if _failures.is_empty():
		print("stage1_balloon_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_burst(effect: Dictionary, position: Vector2, color: Color, expected_max_radius: float) -> void:
	_expect(str(effect.get("type", "")) == "burst", "fallback pop first effect should be the burst")
	_expect(_as_vector2(effect.get("pos", Vector2.ZERO), Vector2.ZERO) == position, "fallback burst should preserve position")
	_expect(effect.get("color", null) == color, "fallback burst should preserve color")
	_expect(float(effect.get("radius", 0.0)) == 4.0, "fallback burst should start at 4px radius")
	_expect(float(effect.get("max_radius", 0.0)) == expected_max_radius, "fallback burst should derive max radius")
	_expect(float(effect.get("alpha", 0.0)) == 0.86, "fallback burst should preserve alpha")
	_expect(float(effect.get("life", 0.0)) == 16.0, "fallback burst should preserve life")


func _verify_particle(effect: Dictionary, position: Vector2, color: Color) -> void:
	_expect(str(effect.get("type", "")) == "particle", "fallback pop decorative effect should be a particle")
	_expect(_as_vector2(effect.get("pos", Vector2.INF), Vector2.INF) == position, "fallback particle should start at pop position")
	var velocity: Vector2 = _as_vector2(effect.get("vel", Vector2.ZERO), Vector2.ZERO)
	_expect(velocity.length() >= 3.0 and velocity.length() <= 9.0, "fallback particle speed should stay in the original range")
	_expect(effect.get("color", null) == color, "fallback particle should preserve color")
	_expect(float(effect.get("alpha", 0.0)) == 1.0, "fallback particle should start fully visible")
	_expect(float(effect.get("size", 0.0)) >= 4.0 and float(effect.get("size", 0.0)) <= 11.0, "fallback particle size should stay in the original range")
	_expect(float(effect.get("life", 0.0)) >= 20.0 and float(effect.get("life", 0.0)) <= 34.0, "fallback particle life should stay in the original range")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
