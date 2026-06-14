extends SceneTree

const StageBallSpawnIntro := preload("res://scripts/core/stage_ball_spawn_intro.gd")
const StageBallSpawnIntroInitialEntityLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_initial_entity_lifecycle.gd")
const StageBallSpawnIntroLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_lifecycle.gd")

var _failures: Array[String] = []


class FakeInitialEntityLifecycle:
	extends RefCounted

	var calls := 0
	var last_config: Dictionary = {}

	func spawn_initial_entities(_intro: Object, config: Dictionary) -> void:
		calls += 1
		last_config = config


func _init() -> void:
	_verify_initial_entity_lifecycle_spawns_configured_entities()
	_verify_lifecycle_delegates_initial_spawn_surface()

	if _failures.is_empty():
		print("stage_ball_spawn_intro_initial_entity_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_initial_entity_lifecycle_spawns_configured_entities() -> void:
	var lifecycle: Object = StageBallSpawnIntroInitialEntityLifecycle.new()
	var intro: Object = StageBallSpawnIntro.new()
	intro.rng.seed = 12345
	intro.start_pos = Vector2(380.0, 375.0)

	lifecycle.spawn_initial_entities(intro, {
		"game_width": 760.0,
		"game_height": 750.0,
		"quantum_particle_base": 3,
		"vortex_ring_count": 2,
		"starfield_count": 4,
		"haze_cloud_count": 1,
	})

	_expect(intro.particles.size() == 3, "initial entity lifecycle should create configured quantum particles")
	_expect(intro.vortex_rings.size() == 2, "initial entity lifecycle should create configured vortex rings")
	_expect(intro.lightning_bolts.size() == 2, "initial entity lifecycle should create initial lightning burst")
	_expect(intro.starfield.size() == 4, "initial entity lifecycle should create configured starfield dots")
	_expect(intro.haze_clouds.size() == 1, "initial entity lifecycle should create configured haze clouds")
	var dot: Dictionary = intro.starfield[0]
	var dot_pos: Vector2 = _as_vector2(dot.get("pos", Vector2.INF), Vector2.INF)
	_expect(dot_pos.x >= 0.0 and dot_pos.x <= 760.0 and dot_pos.y >= 0.0 and dot_pos.y <= 750.0, "initial starfield dot should stay inside the game canvas")
	_expect(float(dot.get("size", 0.0)) >= 0.7 and float(dot.get("size", 0.0)) <= 2.0, "initial starfield dot size should stay in range")
	_expect(float(dot.get("speed", 0.0)) >= 2.5 and float(dot.get("speed", 0.0)) <= 7.0, "initial starfield dot speed should stay in range")
	_expect(int(dot.get("hue", -1)) >= 0 and int(dot.get("hue", -1)) <= 4, "initial starfield dot hue should stay in palette range")
	var cloud: Dictionary = intro.haze_clouds[0]
	var cloud_pos: Vector2 = _as_vector2(cloud.get("pos", Vector2.INF), Vector2.INF)
	_expect(cloud_pos.x >= 80.0 and cloud_pos.x <= 680.0 and cloud_pos.y >= 80.0 and cloud_pos.y <= 670.0, "initial haze cloud should stay inside the safe playfield band")
	_expect(float(cloud.get("radius", 0.0)) >= 180.0 and float(cloud.get("radius", 0.0)) <= 320.0, "initial haze cloud radius should stay in range")
	_expect(float(cloud.get("drift_speed", 0.0)) >= 8.0 and float(cloud.get("drift_speed", 0.0)) <= 20.0, "initial haze cloud drift speed should stay in range")
	_expect(float(cloud.get("rotation_speed", -1.0)) >= -0.3 and float(cloud.get("rotation_speed", 1.0)) <= 0.3, "initial haze cloud rotation speed should stay in range")
	_expect(float(cloud.get("pulse_speed", 0.0)) >= 0.7 and float(cloud.get("pulse_speed", 0.0)) <= 1.6, "initial haze cloud pulse speed should stay in range")
	_expect(cloud.get("color", null) is Color, "initial haze cloud should have a palette color")
	_expect(is_equal_approx(intro.fog_alpha, 100.0), "initial entity lifecycle should initialize fog alpha")
	_expect(intro.fog_color == Color(0.78, 0.86, 1.0, 1.0), "initial entity lifecycle should initialize fog color")

	var intro_source := FileAccess.get_file_as_string("res://scripts/core/stage_ball_spawn_intro.gd")
	var lifecycle_source := FileAccess.get_file_as_string("res://scripts/core/stage_ball_spawn_intro_initial_entity_lifecycle.gd")
	var factory_source := FileAccess.get_file_as_string("res://scripts/core/stage_ball_spawn_intro_effect_factory.gd")
	_expect(intro_source.find("_make_starfield_dot") >= 0, "intro should expose a starfield factory wrapper")
	_expect(intro_source.find("_make_haze_cloud") >= 0, "intro should expose a haze-cloud factory wrapper")
	_expect(lifecycle_source.find("intro._make_starfield_dot") >= 0, "initial entity lifecycle should delegate starfield payloads")
	_expect(lifecycle_source.find("intro._make_haze_cloud") >= 0, "initial entity lifecycle should delegate haze payloads")
	_expect(factory_source.find("func make_starfield_dot") >= 0, "effect factory should own starfield payloads")
	_expect(factory_source.find("func make_haze_cloud") >= 0, "effect factory should own haze payloads")


func _verify_lifecycle_delegates_initial_spawn_surface() -> void:
	var lifecycle: Object = StageBallSpawnIntroLifecycle.new()
	var fake := FakeInitialEntityLifecycle.new()
	lifecycle.initial_entity_lifecycle = fake

	lifecycle.spawn_initial_entities(RefCounted.new(), {
		"quantum_particle_base": 9,
	})

	_expect(fake.calls == 1, "intro lifecycle should delegate initial entity spawning")
	_expect(fake.last_config.get("quantum_particle_base", 0) == 9, "intro lifecycle should pass initial spawn config through")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
