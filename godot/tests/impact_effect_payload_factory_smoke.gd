extends SceneTree

const GameplayEffectAudioModuleCatalog := preload("res://scripts/resources/gameplay_effect_audio_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const ImpactEffectPayloadFactory := preload("res://scripts/effects/impact_effect_payload_factory.gd")
const ImpactEffects := preload("res://scripts/effects/impact_effects.gd")

const TEST_COLORS: Array[Color] = [
	Color(0.4, 0.6, 1.0),
	Color(1.0, 0.45, 0.35),
]


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_energy_payloads()
	_verify_wall_payloads()
	_verify_paddle_payloads()
	_verify_runtime_fanout()
	_verify_state_delegation_and_catalog()

	if _failures.is_empty():
		print("impact_effect_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_energy_payloads() -> void:
	var burst: Dictionary = ImpactEffectPayloadFactory.build_energy_burst(Vector2(10.0, 20.0), 0.05, 2.0, TEST_COLORS, 34.0, 38.0, 12.0, 7.0)
	_expect(burst.get("pos", Vector2.ZERO) == Vector2(10.0, 20.0), "energy burst should preserve position")
	_expect(is_equal_approx(float(burst.get("intensity", 0.0)), 1.5), "energy burst should clamp intensity")
	_expect(is_equal_approx(float(burst.get("size", 0.0)), (34.0 + 38.0 * 1.5) * 0.10), "energy burst should clamp scale into size")
	_expect(is_equal_approx(float(burst.get("max_lifetime", 0.0)), (12.0 + 7.0 * 1.5) * 0.10), "energy burst should clamp scale into lifetime")
	_expect(str(burst.get("type", "")) == "burst", "energy burst should preserve type")
	_expect(_color_in(burst.get("color", Color.TRANSPARENT), TEST_COLORS), "energy burst should use the supplied palette")

	var spark: Dictionary = ImpactEffectPayloadFactory.build_drive_spark(Vector2(10.0, 20.0), TEST_COLORS)
	var spark_pos: Vector2 = spark.get("pos", Vector2.ZERO)
	_expect(absf(spark_pos.x - 10.0) <= 4.0 and absf(spark_pos.y - 20.0) <= 4.0, "drive spark should keep spawn jitter")
	_expect(float(spark.get("size", 0.0)) >= 2.0 and float(spark.get("size", 0.0)) <= 4.0, "drive spark should keep size range")
	_expect(float(spark.get("max_lifetime", 0.0)) >= 14.0 and float(spark.get("max_lifetime", 0.0)) <= 24.0, "drive spark should keep lifetime range")
	_expect(str(spark.get("type", "")) == "spark", "drive spark should preserve type")


func _verify_wall_payloads() -> void:
	var ring: Dictionary = ImpactEffectPayloadFactory.build_wall_ring(Vector2(100.0, 200.0), "left", 0.5, 0.24, TEST_COLORS)
	_expect(ring.get("pos", Vector2.ZERO) == Vector2(100.0, 200.0), "wall ring should preserve position")
	_expect(str(ring.get("side", "")) == "left", "wall ring should preserve side")
	_expect(is_equal_approx(float(ring.get("life", 0.0)), 0.24), "wall ring should preserve life")
	_expect(is_equal_approx(float(ring.get("end_radius", 0.0)), 51.0), "wall ring should scale radius by speed bonus")
	_expect(is_equal_approx(float(ring.get("thickness", 0.0)), 2.9), "wall ring should scale thickness by speed bonus")

	var particle: Dictionary = ImpactEffectPayloadFactory.build_wall_particle(Vector2(100.0, 200.0), 1.0, 0.5, 0.10, 0.16, TEST_COLORS)
	_expect(particle.get("pos", Vector2.ZERO) == Vector2(100.0, 200.0), "wall particle should preserve position")
	_expect(float(particle.get("life", 0.0)) >= 0.10 and float(particle.get("life", 0.0)) <= 0.16, "wall particle should keep life range")
	_expect(is_equal_approx(float(particle.get("max_life", 0.0)), float(particle.get("life", 0.0))), "wall particle should mirror max life")
	_expect(float(particle.get("size", 0.0)) >= 2.4 and float(particle.get("size", 0.0)) <= 5.3, "wall particle should keep size range")
	_expect(float(particle.get("trail", 0.0)) >= 8.0 and float(particle.get("trail", 0.0)) <= 20.5, "wall particle should keep trail range")


func _verify_paddle_payloads() -> void:
	var direction := Vector2(0.0, -1.0)
	var tangent := Vector2(1.0, 0.0)
	var spark: Dictionary = ImpactEffectPayloadFactory.build_paddle_spark(Vector2(300.0, 700.0), Color.WHITE, direction, tangent, 1.0, 0.12, 0.24)
	_expect(float(spark.get("life", 0.0)) >= 0.12 and float(spark.get("life", 0.0)) <= 0.265, "paddle spark should keep life range")
	_expect(float(spark.get("size", 0.0)) >= 1.8 and float(spark.get("size", 0.0)) <= 5.1, "paddle spark should keep size range")
	_expect(float(spark.get("trail", 0.0)) >= 7.0 and float(spark.get("trail", 0.0)) <= 24.0, "paddle spark should keep trail range")

	var primary: Dictionary = ImpactEffectPayloadFactory.build_paddle_primary_ring(Vector2(300.0, 700.0), Color.WHITE, 1.0, 0.20)
	_expect(is_equal_approx(float(primary.get("life", 0.0)), 0.24), "primary paddle ring should include force life bonus")
	_expect(is_equal_approx(float(primary.get("start_radius", 0.0)), 11.0), "primary paddle ring should scale start radius")

	var core: Dictionary = ImpactEffectPayloadFactory.build_paddle_core_ring(Vector2(300.0, 700.0), Color.WHITE, direction, 1.0, 0.20, Color.BLUE)
	_expect(core.get("pos", Vector2.ZERO) == Vector2(300.0, 707.0), "core paddle ring should sit behind the impact direction")

	var streak: Dictionary = ImpactEffectPayloadFactory.build_paddle_streak(Vector2(300.0, 700.0), Color.WHITE, direction, tangent, 1.0, 0.12)
	_expect(float(streak.get("life", 0.0)) >= 0.095 and float(streak.get("life", 0.0)) <= 0.16, "paddle streak should keep life range")
	_expect(float(streak.get("length", 0.0)) >= 20.0 and float(streak.get("length", 0.0)) <= 66.0, "paddle streak should keep length range")

	var flash: Dictionary = ImpactEffectPayloadFactory.build_paddle_flash(Vector2(300.0, 700.0), Color.WHITE, 1.0, 0.12, Color.BLUE)
	_expect(is_equal_approx(float(flash.get("radius", 0.0)), 44.0), "paddle flash should scale radius")


func _verify_runtime_fanout() -> void:
	var effects: Object = ImpactEffects.new()
	effects.spawn_paddle_hit_particles(Vector2(300.0, 700.0), true, Vector2(0.0, -20.0), 1.0)
	_expect(not (effects.get_hit_particles() as Array).is_empty(), "impact effects should spawn paddle particles")
	_expect(not (effects.get_hit_rings() as Array).is_empty(), "impact effects should spawn paddle rings")
	_expect(not (effects.get_hit_streaks() as Array).is_empty(), "impact effects should spawn paddle streaks")
	_expect(not (effects.get_hit_flashes() as Array).is_empty(), "impact effects should spawn paddle flashes")
	effects.spawn_wall_impact(Vector2(40.0, 300.0), "left", 20.0)
	_expect(not (effects.get_wall_impact_particles() as Array).is_empty(), "impact effects should spawn wall particles")
	_expect(not (effects.get_wall_impact_rings() as Array).is_empty(), "impact effects should spawn wall rings")
	effects.create_energy_explosion(Vector2(380.0, 360.0), 1.0, 1.0)
	_expect(not (effects.get_energy_explosion_particles() as Array).is_empty(), "impact effects should spawn energy particles")
	effects.update(0.016)
	_expect(effects.has_visible_effects(), "impact effects should stay visible after one frame")


func _verify_state_delegation_and_catalog() -> void:
	var energy_source := FileAccess.get_file_as_string("res://scripts/effects/impact_energy_effect_state.gd")
	var wall_source := FileAccess.get_file_as_string("res://scripts/effects/impact_wall_effect_state.gd")
	var paddle_source := FileAccess.get_file_as_string("res://scripts/effects/impact_paddle_effect_state.gd")
	_expect(energy_source.find("ImpactEffectPayloadFactory.build_energy_burst") >= 0, "energy impact should delegate burst payloads")
	_expect(energy_source.find("ImpactEffectPayloadFactory.build_drive_spark") >= 0, "energy impact should delegate drive spark payloads")
	_expect(wall_source.find("ImpactEffectPayloadFactory.build_wall_ring") >= 0, "wall impact should delegate ring payloads")
	_expect(wall_source.find("ImpactEffectPayloadFactory.build_wall_particle") >= 0, "wall impact should delegate particle payloads")
	_expect(paddle_source.find("ImpactEffectPayloadFactory.build_paddle_spark") >= 0, "paddle impact should delegate spark payloads")
	_expect(paddle_source.find("ImpactEffectPayloadFactory.build_paddle_primary_ring") >= 0, "paddle impact should delegate ring payloads")
	_expect(paddle_source.find("ImpactEffectPayloadFactory.build_paddle_streak") >= 0, "paddle impact should delegate streak payloads")
	_expect(paddle_source.find("ImpactEffectPayloadFactory.build_paddle_flash") >= 0, "paddle impact should delegate flash payloads")
	_expect(energy_source.find("energy_explosion_particles.append({") < 0, "energy impact should not inline particle dictionaries")
	_expect(wall_source.find("wall_impact_rings.append({") < 0, "wall impact should not inline ring dictionaries")
	_expect(wall_source.find("wall_impact_particles.append({") < 0, "wall impact should not inline particle dictionaries")
	_expect(paddle_source.find("hit_particles.append({") < 0, "paddle impact should not inline spark dictionaries")
	_expect(paddle_source.find("hit_rings.append({") < 0, "paddle impact should not inline ring dictionaries")
	_expect(paddle_source.find("hit_streaks.append({") < 0, "paddle impact should not inline streak dictionaries")
	_expect(paddle_source.find("hit_flashes.append({") < 0, "paddle impact should not inline flash dictionaries")

	var modules: Dictionary = GameplayEffectAudioModuleCatalog.MODULES
	_expect(modules.has("impact_effect_payload_factory"), "effect/audio module catalog should list the impact payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("impact_effect_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/effects/impact_effect_payload_factory.gd", "top-level module catalog should resolve the impact payload factory")


func _color_in(value: Variant, colors: Array[Color]) -> bool:
	if not (value is Color):
		return false
	for color in colors:
		if (value as Color).is_equal_approx(color):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
