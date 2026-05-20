extends SceneTree

const StageBallSpawnIntro := preload("res://scripts/core/stage_ball_spawn_intro.gd")
const StageBallSpawnIntroPhase2Updater := preload("res://scripts/core/stage_ball_spawn_intro_phase_2_updater.gd")

var _failures: Array[String] = []


class FakeIntro:
	extends RefCounted

	var elapsed_sec := 2.0
	var rng := RandomNumberGenerator.new()
	var start_pos := Vector2(380.0, 375.0)
	var particles := []
	var vortex_rings := [{"id": 1}]
	var lightning_bolts := []
	var chain_lightnings := []
	var electric_arcs := []
	var energy_rings := []
	var lightning_spawn_timer := 0.10
	var arc_spawn_timer := 0.20
	var energy_ring_timer := 0.14
	var core_glow_radius := 0.0
	var core_glow_alpha := 0.0
	var fog_alpha := 0.0
	var fog_color := Color.WHITE
	var next_ball_state := {
		"pos": Vector2(410.0, 350.0),
		"scale": 1.25,
	}
	var made_lightnings := 0
	var made_energy_rings := 0
	var made_arcs := 0
	var energy_updates := 0
	var arc_updates := 0
	var quantum_updates := 0
	var vortex_updates := 0
	var prune_calls := 0
	var ball_state_calls := 0

	func _get_ball_state() -> Dictionary:
		ball_state_calls += 1
		return next_ball_state

	func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
		return value if value is Vector2 else fallback

	func _make_lightning_bolt(start_pt: Vector2, end_pt: Vector2, is_main: bool, branch_depth: int) -> Dictionary:
		made_lightnings += 1
		return {
			"start": start_pt,
			"end": end_pt,
			"is_main": is_main,
			"branch_depth": branch_depth,
		}

	func _make_energy_ring(center: Vector2, start_radius: float) -> Dictionary:
		made_energy_rings += 1
		return {
			"center": center,
			"radius": start_radius,
		}

	func _update_energy_ring(_ring: Dictionary, _dt: float, _new_center: Vector2) -> void:
		energy_updates += 1

	func _make_electric_arc(center: Vector2, radius: float) -> Dictionary:
		made_arcs += 1
		return {
			"center": center,
			"radius": radius,
		}

	func _update_electric_arc(_arc: Dictionary, _dt: float, _new_center: Vector2) -> void:
		arc_updates += 1

	func _prune_lifetime(_entities: Array, _dt: float) -> void:
		prune_calls += 1

	func _update_quantum_particle(_particle: Dictionary, _progress: float, _dt: float) -> void:
		quantum_updates += 1

	func _update_vortex_ring(_ring: Dictionary, _progress: float, _dt: float) -> void:
		vortex_updates += 1


class FakePhase2Updater:
	extends RefCounted

	var calls := 0
	var last_config: Dictionary = {}

	func update(_intro: Object, _dt: float, config: Dictionary) -> void:
		calls += 1
		last_config = config


func _init() -> void:
	_verify_phase_2_updater_routes_levitation_timers()
	_verify_intro_delegates_phase_2_update()

	if _failures.is_empty():
		print("stage_ball_spawn_intro_phase_2_updater_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_phase_2_updater_routes_levitation_timers() -> void:
	var updater: Object = StageBallSpawnIntroPhase2Updater.new()
	var intro := FakeIntro.new()
	intro.rng.seed = 12345

	updater.update(intro, 0.20, {
		"phase_1_duration": 2.0,
		"phase_2_duration": 0.75,
		"ball_render_radius": 26.6175,
		"max_energy_rings": 5,
		"max_electric_arcs": 7,
	})

	_expect(intro.made_lightnings == 1, "phase 2 updater should spawn fade lightning during early levitation")
	_expect(intro.lightning_bolts.size() == 1, "phase 2 updater should append spawned lightning")
	_expect(is_equal_approx(intro.lightning_spawn_timer, 0.0), "phase 2 updater should reset lightning timer")
	_expect(intro.made_energy_rings == 1, "phase 2 updater should create energy rings")
	_expect(intro.energy_rings.size() == 1, "phase 2 updater should append energy rings")
	_expect(is_equal_approx(intro.energy_ring_timer, 0.0), "phase 2 updater should reset energy-ring timer")
	_expect(intro.made_arcs == 1, "phase 2 updater should create electric arcs")
	_expect(intro.electric_arcs.size() == 1, "phase 2 updater should append electric arcs")
	_expect(is_equal_approx(intro.arc_spawn_timer, 0.0), "phase 2 updater should reset arc timer")
	_expect(intro.energy_updates == 1, "phase 2 updater should update energy rings around the ball")
	_expect(intro.arc_updates == 1, "phase 2 updater should update electric arcs around the ball")
	_expect(intro.prune_calls == 4, "phase 2 updater should prune phase 2 lifetime collections")
	_expect(intro.vortex_updates == 1, "phase 2 updater should keep ticking vortex rings")
	_expect(intro.ball_state_calls == 3, "phase 2 updater should preserve original ball-state lookup cadence")
	_expect(intro.core_glow_radius > 0.0 and intro.core_glow_alpha > 0.0, "phase 2 updater should update core glow")
	_expect(intro.fog_alpha > 0.0, "phase 2 updater should update levitation fog alpha")


func _verify_intro_delegates_phase_2_update() -> void:
	var intro: Object = StageBallSpawnIntro.new()
	var updater := FakePhase2Updater.new()
	intro.phase_2_updater = updater

	intro._update_phase_2(0.02)

	_expect(updater.calls == 1, "intro phase 2 method should delegate to phase 2 updater")
	_expect(updater.last_config.get("phase_2_duration", 0.0) == 0.75, "intro should pass phase 2 duration")
	_expect(updater.last_config.get("max_energy_rings", 0) == 5, "intro should pass energy-ring cap")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
