extends SceneTree

const StageBallSpawnIntro := preload("res://scripts/core/stage_ball_spawn_intro.gd")
const StageBallSpawnIntroPhase3Updater := preload("res://scripts/core/stage_ball_spawn_intro_phase_3_updater.gd")

var _failures: Array[String] = []


class FakeIntro:
	extends RefCounted

	var elapsed_sec := 2.75
	var rng := RandomNumberGenerator.new()
	var player_serves := true
	var start_pos := Vector2(380.0, 375.0)
	var particles := []
	var vortex_rings := [{
		"angle": 0.0,
		"rotation_speed": 1.0,
		"radius": 10.0,
		"center": Vector2(380.0, 375.0),
	}]
	var phase3_trail := [Vector2(1.0, 1.0), Vector2(2.0, 2.0), Vector2(3.0, 3.0)]
	var hologram_rings := []
	var sparks := []
	var electric_arcs := []
	var energy_rings := []
	var lightning_bolts := []
	var hologram_spawn_timer := 0.14
	var spark_spawn_timer := 0.05
	var arc_spawn_timer := 0.12
	var energy_ring_timer := 0.20
	var core_glow_radius := 0.0
	var core_glow_alpha := 0.0
	var fog_alpha := 0.0
	var fog_color := Color.WHITE
	var next_ball_state := {
		"pos": Vector2(410.0, 350.0),
	}
	var made_holograms := 0
	var hologram_updates := 0
	var made_sparks := 0
	var spark_updates := 0
	var made_arcs := 0
	var arc_updates := 0
	var made_energy_rings := 0
	var energy_updates := 0
	var made_lightnings := 0
	var quantum_updates := 0
	var prune_calls := 0
	var ball_state_calls := 0

	func _get_ball_state() -> Dictionary:
		ball_state_calls += 1
		return next_ball_state

	func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
		return value if value is Vector2 else fallback

	func _make_hologram_ring(center: Vector2, radius: float) -> Dictionary:
		made_holograms += 1
		return {
			"center": center,
			"radius": radius,
		}

	func _update_hologram_ring(_hologram: Dictionary, _dt: float, _new_center: Vector2) -> void:
		hologram_updates += 1

	func _make_spark(pos: Vector2, direction: float) -> Dictionary:
		made_sparks += 1
		return {
			"pos": pos,
			"direction": direction,
		}

	func _update_spark(_spark: Dictionary, _dt: float) -> void:
		spark_updates += 1

	func _make_electric_arc(center: Vector2, radius: float) -> Dictionary:
		made_arcs += 1
		return {
			"center": center,
			"radius": radius,
		}

	func _update_electric_arc(_arc: Dictionary, _dt: float, _new_center: Vector2) -> void:
		arc_updates += 1

	func _make_energy_ring(center: Vector2, start_radius: float) -> Dictionary:
		made_energy_rings += 1
		return {
			"center": center,
			"radius": start_radius,
		}

	func _update_energy_ring(_ring: Dictionary, _dt: float, _new_center: Vector2) -> void:
		energy_updates += 1

	func _make_lightning_bolt(start_pt: Vector2, end_pt: Vector2, is_main: bool, branch_depth: int) -> Dictionary:
		made_lightnings += 1
		return {
			"start": start_pt,
			"end": end_pt,
			"is_main": is_main,
			"branch_depth": branch_depth,
		}

	func _prune_lifetime(_entities: Array, _dt: float) -> void:
		prune_calls += 1

	func _update_quantum_particle(_particle: Dictionary, _progress: float, _dt: float) -> void:
		quantum_updates += 1


class FakePhase3Updater:
	extends RefCounted

	var calls := 0
	var last_config: Dictionary = {}

	func update(_intro: Object, _dt: float, config: Dictionary) -> void:
		calls += 1
		last_config = config


func _init() -> void:
	_verify_phase_3_updater_routes_launch_timers()
	_verify_intro_delegates_phase_3_update()

	if _failures.is_empty():
		print("stage_ball_spawn_intro_phase_3_updater_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_phase_3_updater_routes_launch_timers() -> void:
	var updater: Object = StageBallSpawnIntroPhase3Updater.new()
	var intro := FakeIntro.new()
	intro.rng.seed = 12345

	updater.update(intro, 0.20, {
		"phase_1_duration": 2.0,
		"phase_2_duration": 0.75,
		"phase_3_duration": 1.25,
		"ball_render_radius": 26.6175,
		"phase3_trail_limit": 3,
		"max_hologram_rings": 9,
		"max_sparks": 34,
		"max_electric_arcs": 7,
		"max_energy_rings": 5,
		"max_lightning_bolts": 0,
	})

	_expect(intro.vortex_rings.size() == 1, "phase 3 updater should keep live vortex rings")
	_expect(float(intro.vortex_rings[0].angle) > 0.0, "phase 3 updater should advance vortex angle")
	_expect((intro.vortex_rings[0].get("center", Vector2.ZERO) as Vector2).y < 375.0, "phase 3 updater should lift vortex rings")
	_expect(intro.phase3_trail.size() == 3, "phase 3 updater should enforce trail cap")
	_expect(intro.phase3_trail.back() == Vector2(410.0, 350.0), "phase 3 updater should append current ball position")
	_expect(intro.made_holograms == 3, "phase 3 updater should spawn launch hologram rings")
	_expect(intro.hologram_updates == 3, "phase 3 updater should update hologram rings")
	_expect(is_equal_approx(intro.hologram_spawn_timer, 0.0), "phase 3 updater should reset hologram timer")
	_expect(intro.made_sparks >= 2, "phase 3 updater should spawn launch sparks")
	_expect(intro.spark_updates == intro.sparks.size(), "phase 3 updater should update spawned sparks")
	_expect(is_equal_approx(intro.spark_spawn_timer, 0.0), "phase 3 updater should reset spark timer")
	_expect(intro.made_arcs == 1 and intro.arc_updates == 1, "phase 3 updater should create and update electric arcs")
	_expect(is_equal_approx(intro.arc_spawn_timer, 0.0), "phase 3 updater should reset arc timer")
	_expect(intro.made_energy_rings == 1 and intro.energy_updates == 1, "phase 3 updater should create and update energy rings")
	_expect(is_equal_approx(intro.energy_ring_timer, 0.0), "phase 3 updater should reset energy-ring timer")
	_expect(intro.made_lightnings == 0, "phase 3 updater should respect lightning cap")
	_expect(intro.prune_calls == 5, "phase 3 updater should prune phase 3 lifetime collections")
	_expect(intro.ball_state_calls == 1, "phase 3 updater should preserve original ball-state lookup cadence")
	_expect(intro.core_glow_radius > 0.0 and intro.core_glow_alpha > 0.0, "phase 3 updater should update launch core glow")
	_expect(intro.fog_alpha > 0.0, "phase 3 updater should update launch fog alpha")


func _verify_intro_delegates_phase_3_update() -> void:
	var intro: Object = StageBallSpawnIntro.new()
	var updater := FakePhase3Updater.new()
	intro.phase_3_updater = updater

	intro._update_phase_3(0.02)

	_expect(updater.calls == 1, "intro phase 3 method should delegate to phase 3 updater")
	_expect(updater.last_config.get("phase_3_duration", 0.0) == 1.25, "intro should pass phase 3 duration")
	_expect(updater.last_config.get("phase3_trail_limit", 0) == 18, "intro should pass phase 3 trail cap")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
