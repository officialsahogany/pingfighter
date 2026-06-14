extends SceneTree

const GameplayLingpetModuleCatalog := preload("res://scripts/resources/gameplay_lingpet_module_catalog.gd")
const GameplayModuleCatalog := preload("res://scripts/resources/gameplay_module_catalog.gd")
const LingpetDragonBreathPayloadFactory := preload("res://scripts/lingpet/lingpet_dragon_breath_payload_factory.gd")


var _failures: Array[String] = []

func _init() -> void:
	seed(20260612)
	_verify_breath_particle_payloads()
	_verify_fire_zone_payload()
	_verify_zone_flame_payload()
	_verify_status_payload()
	_verify_molotov_payloads()
	_verify_skill_delegation_and_catalog()

	if _failures.is_empty():
		print("lingpet_dragon_breath_payload_factory_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_breath_particle_payloads() -> void:
	var origin := Vector2(380.0, 680.0)
	var initial_particle: Dictionary = LingpetDragonBreathPayloadFactory.build_breath_particle(origin, -1.0, true, 0.5)
	_expect(_is_breath_particle_inside_ranges(initial_particle, origin, -1.0, true, 0.15), "initial breath particle should keep the original range")
	var live_particle: Dictionary = LingpetDragonBreathPayloadFactory.build_breath_particle(origin, -1.0, false, 0.0)
	_expect(_is_breath_particle_inside_ranges(live_particle, origin, -1.0, false, 0.0), "continuous breath particle should keep the original range")


func _is_breath_particle_inside_ranges(particle: Dictionary, origin: Vector2, direction: float, initial: bool, expected_delay: float) -> bool:
	var pos: Vector2 = particle.get("pos", Vector2.ZERO)
	if pos.x < origin.x - 25.0 or pos.x > origin.x + 25.0:
		return false
	var expected_y := origin.y + direction * (20.0 if initial else 25.0)
	if not is_equal_approx(pos.y, expected_y):
		return false
	var vel: Vector2 = particle.get("vel", Vector2.ZERO)
	var vx_range := 66.0 if initial else 54.0
	if vel.x < -vx_range or vel.x > vx_range:
		return false
	var speed_min := 350.0 if initial else 400.0
	var speed_max := 600.0 if initial else 550.0
	if absf(vel.y) < speed_min or absf(vel.y) > speed_max:
		return false
	if signf(vel.y) != signf(direction):
		return false
	var max_life := float(particle.get("max_life", 0.0))
	var min_life := 1.0 if initial else 0.6
	var max_life_range := 1.8 if initial else 1.2
	if max_life < min_life or max_life > max_life_range:
		return false
	if not is_equal_approx(float(particle.get("life", 0.0)), max_life + expected_delay):
		return false
	var min_size := 10.0 if initial else 8.0
	var max_size := 25.0 if initial else 18.0
	var size := float(particle.get("size", 0.0))
	if size < min_size or size > max_size:
		return false
	if not is_equal_approx(float(particle.get("max_size", 0.0)), size):
		return false
	if float(particle.get("phase", -1.0)) < 0.0 or float(particle.get("phase", -1.0)) > 1.0:
		return false
	if float(particle.get("wob", -1.0)) < 0.0 or float(particle.get("wob", -1.0)) > 1.0:
		return false
	if not is_equal_approx(float(particle.get("delay", -1.0)), expected_delay):
		return false
	return not bool(particle.get("zone_reported", true))


func _verify_fire_zone_payload() -> void:
	var zone: Dictionary = LingpetDragonBreathPayloadFactory.build_fire_zone(Vector2(300.0, 120.0), 100.0, 50.0, 2.0, 0.34, 7)
	_expect(zone.get("position", Vector2.ZERO) == Vector2(300.0, 120.0), "fire zone should preserve position")
	_expect(is_equal_approx(float(zone.get("width", 0.0)), 100.0), "fire zone should preserve width")
	_expect(is_equal_approx(float(zone.get("height", 0.0)), 50.0), "fire zone should preserve height")
	_expect(is_equal_approx(float(zone.get("timer", 0.0)), 2.0), "fire zone should preserve timer")
	_expect(is_equal_approx(float(zone.get("max_timer", 0.0)), 2.0), "fire zone should preserve max timer")
	_expect(is_equal_approx(float(zone.get("spread_timer", -1.0)), 0.0), "fire zone should start with zero spread timer")
	_expect(is_equal_approx(float(zone.get("push_timer", 0.0)), 0.34), "fire zone should preserve push timer")
	_expect((zone.get("flames", []) as Array).is_empty(), "fire zone should start with an empty flame list")
	_expect(not bool(zone.get("boss_in_fire", true)), "fire zone should not start with boss contact")
	_expect(is_equal_approx(float(zone.get("last_push_dir", -1.0)), 0.0), "fire zone should start with zero push direction")
	_expect(int(zone.get("zone_id", 0)) == 7, "fire zone should preserve zone id")


func _verify_zone_flame_payload() -> void:
	var center := Vector2(380.0, 180.0)
	var flame: Dictionary = LingpetDragonBreathPayloadFactory.build_zone_flame(center, 30.0, 12.0)
	var pos: Vector2 = flame.get("pos", Vector2.ZERO)
	_expect(pos.x >= center.x - 30.0 and pos.x <= center.x + 30.0, "zone flame should keep the original x spread")
	_expect(pos.y >= center.y - 12.0 and pos.y <= center.y + 12.0, "zone flame should keep the original y spread")
	_expect(float(flame.get("size", 0.0)) >= 8.0 and float(flame.get("size", 0.0)) <= 20.0, "zone flame should keep the size range")
	_expect(float(flame.get("life", 0.0)) >= 0.33 and float(flame.get("life", 0.0)) <= 0.66, "zone flame should keep the life range")
	_expect(is_equal_approx(float(flame.get("max_life", 0.0)), 0.66), "zone flame should preserve max life")
	_expect(float(flame.get("phase", -1.0)) >= 0.0 and float(flame.get("phase", -1.0)) <= 1.0, "zone flame should keep phase in range")


func _verify_status_payload() -> void:
	var data: Dictionary = LingpetDragonBreathPayloadFactory.build_boss_slow_status_data(0.5)
	_expect(is_equal_approx(float(data.get("multiplier", 0.0)), 0.5), "boss slow data should preserve multiplier")
	_expect(bool(data.get("cleansable", false)), "boss slow data should stay cleansable")
	_expect(str(data.get("visual", "")) == "red_dragon_dragon_breath", "boss slow data should keep the Dragon Breath visual key")
	_expect(bool(data.get("suppress_legacy_boss_ai_slow", false)), "boss slow data should suppress legacy boss AI slow")


func _verify_molotov_payloads() -> void:
	var flame := {
		"pos": Vector2(310.0, 120.0),
		"size": 13.0,
		"life": 0.40,
		"max_life": 0.66,
		"phase": 0.25,
	}
	var flame_payload: Dictionary = LingpetDragonBreathPayloadFactory.build_molotov_flame_payload(flame, 8.0, 0.66)
	_expect(flame_payload.get("position", Vector2.ZERO) == Vector2(310.0, 120.0), "molotov flame payload should preserve position")
	_expect(is_equal_approx(float(flame_payload.get("size", 0.0)), 13.0), "molotov flame payload should preserve size")
	_expect(is_equal_approx(float(flame_payload.get("lifetime_frames", 0.0)), 24.0), "molotov flame payload should convert life to frames")
	_expect(is_equal_approx(float(flame_payload.get("max_lifetime_frames", 0.0)), 39.6), "molotov flame payload should convert max life to frames")
	_expect(is_equal_approx(float(flame_payload.get("color_phase", 0.0)), 0.25), "molotov flame payload should preserve color phase")

	var zone := {
		"position": Vector2(300.0, 120.0),
		"width": 100.0,
		"height": 50.0,
		"timer": 1.5,
		"max_timer": 2.0,
		"zone_id": 9,
	}
	var zone_payload: Dictionary = LingpetDragonBreathPayloadFactory.build_molotov_zone_payload(zone, 100.0, 50.0, 2.0, [flame_payload])
	_expect(zone_payload.get("position", Vector2.ZERO) == Vector2(300.0, 120.0), "molotov zone payload should preserve position")
	_expect(is_equal_approx(float(zone_payload.get("width", 0.0)), 135.0), "molotov zone payload should apply the visual width scale")
	_expect(is_equal_approx(float(zone_payload.get("height", 0.0)), 67.5), "molotov zone payload should apply the visual height scale")
	_expect(int(zone_payload.get("zone_id", 0)) == 9, "molotov zone payload should preserve zone id")
	_expect(is_equal_approx(float(zone_payload.get("duration_frames", 0.0)), 90.0), "molotov zone payload should convert timer to frames")
	_expect(is_equal_approx(float(zone_payload.get("max_duration_frames", 0.0)), 120.0), "molotov zone payload should convert max timer to frames")
	_expect(is_equal_approx(float(zone_payload.get("age_frames", 0.0)), 30.0), "molotov zone payload should compute age frames")
	_expect((zone_payload.get("flames", []) as Array).size() == 1, "molotov zone payload should preserve converted flames")


func _verify_skill_delegation_and_catalog() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_dragon_breath_skill.gd")
	_expect(source.find("LingpetDragonBreathPayloadFactory.build_breath_particle") >= 0, "Dragon Breath should delegate breath-particle payloads")
	_expect(source.find("LingpetDragonBreathPayloadFactory.build_fire_zone") >= 0, "Dragon Breath should delegate fire-zone payloads")
	_expect(source.find("LingpetDragonBreathPayloadFactory.build_zone_flame") >= 0, "Dragon Breath should delegate zone-flame payloads")
	_expect(source.find("LingpetDragonBreathPayloadFactory.build_boss_slow_status_data") >= 0, "Dragon Breath should delegate boss slow status data")
	_expect(source.find("LingpetDragonBreathPayloadFactory.build_molotov_zone_payload") >= 0, "Dragon Breath should delegate molotov zone payload conversion")
	_expect(source.find("LingpetDragonBreathPayloadFactory.build_molotov_flame_payload") >= 0, "Dragon Breath should delegate molotov flame payload conversion")
	_expect(source.find("_particles.append({") < 0, "Dragon Breath should not inline breath particle dictionaries")
	_expect(source.find("flames.append({") < 0, "Dragon Breath should not inline zone flame dictionaries")
	_expect(source.find("payload.append({") < 0, "Dragon Breath should not inline molotov zone payload dictionaries")
	_expect(source.find("out.append({") < 0, "Dragon Breath should not inline molotov flame payload dictionaries")
	_expect(source.find("\"visual\": \"red_dragon_dragon_breath\"") < 0, "Dragon Breath should not inline boss slow status data")

	var lingpet_modules: Dictionary = GameplayLingpetModuleCatalog.MODULES
	_expect(lingpet_modules.has("lingpet_dragon_breath_payload_factory"), "lingpet module catalog should list the Dragon Breath payload factory")
	var spec: Dictionary = GameplayModuleCatalog.new().get_spec("lingpet_dragon_breath_payload_factory")
	_expect(str(spec.get("path", "")) == "res://scripts/lingpet/lingpet_dragon_breath_payload_factory.gd", "top-level module catalog should resolve the Dragon Breath payload factory")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
