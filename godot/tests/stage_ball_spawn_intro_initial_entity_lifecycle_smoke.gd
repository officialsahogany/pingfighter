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
	_expect(is_equal_approx(intro.fog_alpha, 100.0), "initial entity lifecycle should initialize fog alpha")
	_expect(intro.fog_color == Color(0.78, 0.86, 1.0, 1.0), "initial entity lifecycle should initialize fog color")


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
