extends SceneTree

const StageBallSpawnIntro := preload("res://scripts/core/stage_ball_spawn_intro.gd")
const StageBallSpawnIntroPhase1Updater := preload("res://scripts/core/stage_ball_spawn_intro_phase_1_updater.gd")

var _failures: Array[String] = []


class FakeIntro:
	extends RefCounted

	var elapsed_sec := 1.0
	var rng := RandomNumberGenerator.new()
	var start_pos := Vector2(380.0, 375.0)
	var particles := [{"id": 1}, {"id": 2}]
	var vortex_rings := [{"id": 1}]
	var lightning_bolts := []
	var chain_lightnings := []
	var electric_arcs := []
	var lightning_spawn_timer := 0.20
	var chain_spawn_timer := 0.0
	var arc_spawn_timer := 0.22
	var particle_spawn_timer := 0.30
	var core_glow_radius := 0.0
	var core_glow_alpha := 0.0
	var fog_alpha := 0.0
	var fog_color := Color.WHITE
	var quantum_updates := 0
	var vortex_updates := 0
	var lightning_spawns := 0
	var chain_spawns := 0
	var prune_calls := 0
	var made_arcs := 0
	var made_particles := 0

	func _update_quantum_particle(_particle: Dictionary, _progress: float, _dt: float) -> void:
		quantum_updates += 1

	func _update_vortex_ring(_ring: Dictionary, _progress: float, _dt: float) -> void:
		vortex_updates += 1

	func _spawn_phase1_lightning(_progress: float) -> void:
		lightning_spawns += 1

	func _spawn_chain_lightning() -> void:
		chain_spawns += 1

	func _make_electric_arc(center: Vector2, radius: float) -> Dictionary:
		made_arcs += 1
		return {
			"center": center,
			"radius": radius,
		}

	func _prune_lifetime(_entities: Array, _dt: float) -> void:
		prune_calls += 1

	func _make_quantum_particle(max_radius: float) -> Dictionary:
		made_particles += 1
		return {
			"max_radius": max_radius,
		}


class FakePhase1Updater:
	extends RefCounted

	var calls := 0
	var last_config: Dictionary = {}

	func update(_intro: Object, _dt: float, config: Dictionary) -> void:
		calls += 1
		last_config = config


func _init() -> void:
	_verify_phase_1_updater_routes_entities_and_timers()
	_verify_intro_delegates_phase_1_update()

	if _failures.is_empty():
		print("stage_ball_spawn_intro_phase_1_updater_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_phase_1_updater_routes_entities_and_timers() -> void:
	var updater: Object = StageBallSpawnIntroPhase1Updater.new()
	var intro := FakeIntro.new()
	intro.rng.seed = 12345

	updater.update(intro, 0.20, {
		"game_width": 760.0,
		"game_height": 750.0,
		"phase_1_duration": 2.0,
		"quantum_particle_hard_cap": 10,
		"max_electric_arcs": 7,
		"max_chain_lightnings": 0,
	})

	_expect(intro.quantum_updates == 2, "phase 1 updater should tick existing quantum particles")
	_expect(intro.vortex_updates == 1, "phase 1 updater should tick existing vortex rings")
	_expect(intro.lightning_spawns == 1, "phase 1 updater should route lightning timer spawns")
	_expect(is_equal_approx(intro.lightning_spawn_timer, 0.0), "phase 1 updater should reset lightning timer after spawn")
	_expect(intro.chain_spawns == 0, "phase 1 updater should respect chain-lightning cap")
	_expect(intro.electric_arcs.size() == 1, "phase 1 updater should append electric arcs after threshold")
	_expect(intro.made_arcs == 1, "phase 1 updater should create electric arcs through intro factory")
	_expect(is_equal_approx(intro.arc_spawn_timer, 0.0), "phase 1 updater should reset arc timer after spawn")
	_expect(intro.prune_calls == 3, "phase 1 updater should prune phase 1 lifetime collections")
	_expect(is_equal_approx(intro.particle_spawn_timer, 0.0), "phase 1 updater should reset particle timer after top-up")
	_expect(intro.made_particles >= 1, "phase 1 updater should top up quantum particles")
	_expect(intro.particles.size() > 2, "phase 1 updater should append topped-up particles")
	_expect(intro.core_glow_radius > 0.0 and intro.core_glow_alpha > 0.0, "phase 1 updater should update core glow")
	_expect(intro.fog_alpha > 0.0, "phase 1 updater should update aurora fog alpha")


func _verify_intro_delegates_phase_1_update() -> void:
	var intro: Object = StageBallSpawnIntro.new()
	var updater := FakePhase1Updater.new()
	intro.phase_1_updater = updater

	intro._update_phase_1(0.02)

	_expect(updater.calls == 1, "intro phase 1 method should delegate to phase 1 updater")
	_expect(updater.last_config.get("phase_1_duration", 0.0) == 2.0, "intro should pass phase 1 duration")
	_expect(updater.last_config.get("quantum_particle_hard_cap", 0) == 36, "intro should pass particle cap")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
