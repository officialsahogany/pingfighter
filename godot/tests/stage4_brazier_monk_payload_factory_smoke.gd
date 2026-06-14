extends SceneTree

const Stage4BrazierMonkPayloadFactory := preload("res://scripts/stages/stage4/stage4_brazier_monk_payload_factory.gd")
const Stage4BrazierMonkEvent := preload("res://scripts/stages/stage4/stage4_brazier_monk_event.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_monk_defaults_and_overrides()
	_verify_hit_effect_payloads()
	_verify_explosion_payloads()
	_verify_event_delegates_payloads()

	if _failures.is_empty():
		print("stage4_brazier_monk_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_monk_defaults_and_overrides() -> void:
	var monk: Dictionary = Stage4BrazierMonkPayloadFactory.build_monk(Vector2(380.0, 450.0), {
		"target_x": 500.0,
		"is_smoke_grenade_monk": true,
		"monk_type": "golden",
		"speed_boost": 1.3,
	})
	_expect(is_equal_approx(float(monk.get("x", 0.0)), 380.0), "monk should use entrance x")
	_expect(is_equal_approx(float(monk.get("y", 0.0)), 450.0), "monk should use entrance y")
	_expect(is_equal_approx(float(monk.get("target_x", 0.0)), 500.0), "monk override should win")
	_expect(bool(monk.get("is_smoke_grenade_monk", false)), "smoke monk override should win")
	_expect(str(monk.get("monk_type", "")) == "golden", "monk type override should win")
	_expect(is_equal_approx(float(monk.get("speed_boost", 0.0)), 1.3), "speed boost override should win")
	_expect(str(monk.get("state", "")) == "walking", "monk should default to walking")
	_expect(is_equal_approx(float(monk.get("opacity", -1.0)), 0.0), "monk should default transparent for fade-in")
	_expect(bool(monk.get("can_deflect", false)), "monk should default deflectable")
	_expect(not bool(monk.get("returning_to_temple", true)), "monk should not default returning")


func _verify_hit_effect_payloads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7001
	var effects: Array = Stage4BrazierMonkPayloadFactory.build_hit_effects({
		"x": 300.0,
		"y": 400.0,
		"direction": -1,
	}, Stage4BrazierMonkEvent.TEMPLE_GHOST_HIT_TIP_OFFSET, rng)
	_expect(effects.size() == 9, "hit effects should include one shockwave and eight sparks")
	var shockwave: Dictionary = effects[0] as Dictionary
	_expect(str(shockwave.get("type", "")) == "shockwave", "first hit effect should be shockwave")
	_expect(is_equal_approx(float(shockwave.get("x", 0.0)), 300.0 - Stage4BrazierMonkEvent.TEMPLE_GHOST_HIT_TIP_OFFSET.x), "shockwave should respect facing direction")
	_expect(is_equal_approx(float(shockwave.get("radius", 0.0)), 8.0), "shockwave should preserve start radius")
	for index in range(1, effects.size()):
		var spark: Dictionary = effects[index] as Dictionary
		_expect(str(spark.get("type", "")) == "spark", "hit effect tail should be sparks")
		_expect(is_equal_approx(float(spark.get("alpha", 0.0)), 255.0), "spark should start opaque")
		_expect(float(spark.get("life", 0.0)) >= 12.0 and float(spark.get("life", 0.0)) <= 20.0, "spark life should stay in reference range")


func _verify_explosion_payloads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7002
	var normal: Array = Stage4BrazierMonkPayloadFactory.build_explosion_particles(Vector2(100.0, 200.0), Color(0.2, 0.1, 0.1, 1.0), false, rng)
	_expect(normal.size() == 14, "normal monk explosion should include six body chunks and eight sparks")
	var body_chunk: Dictionary = normal[0] as Dictionary
	_expect(is_equal_approx(float(body_chunk.get("x", 0.0)), 100.0), "body chunk should preserve x")
	_expect(is_equal_approx(float(body_chunk.get("gravity", 0.0)), 0.14), "body chunk should preserve gravity")
	_expect(float(body_chunk.get("life", 0.0)) >= 60.0 and float(body_chunk.get("life", 0.0)) <= 92.0, "body chunk life should stay in reference range")

	var hero: Array = Stage4BrazierMonkPayloadFactory.build_explosion_particles(Vector2(100.0, 200.0), Color(0.2, 0.1, 0.1, 1.0), true, rng)
	_expect(hero.size() == 18, "hero monk explosion should include twelve sparks")
	var hero_spark: Dictionary = hero[hero.size() - 1] as Dictionary
	_expect(str(hero_spark.get("type", "")) == "spark", "hero tail particles should be sparks")
	_expect(hero_spark.get("color", Color.BLACK) == Color(1.0, 0.86, 0.30, 1.0), "hero sparks should keep golden color")


func _verify_event_delegates_payloads() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage4/stage4_brazier_monk_event.gd")
	_expect(source.find("Stage4BrazierMonkPayloadFactory.build_monk") >= 0, "monk event should delegate monk payload defaults")
	_expect(source.find("Stage4BrazierMonkPayloadFactory.build_hit_effects") >= 0, "monk event should delegate hit-effect payloads")
	_expect(source.find("Stage4BrazierMonkPayloadFactory.build_explosion_particles") >= 0, "monk event should delegate explosion payloads")

	var catalog_source := FileAccess.get_file_as_string("res://scripts/resources/gameplay_stage_module_catalog.gd")
	_expect(catalog_source.find("stage4_brazier_monk_payload_factory") >= 0, "module catalog should expose Stage 4 monk payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
