extends SceneTree

const Stage2PillarBackground := preload("res://scripts/stages/stage2/stage2_pillar_background.gd")
const StarpointParticleState := preload("res://scripts/stages/common/starpoint_particle_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_particle_update()
	_verify_particle_array_compaction()
	_verify_background_delegates_starpoint_particles()

	if _failures.is_empty():
		print("stage2_starpoint_particle_state_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_particle_update() -> void:
	var particle := {
		"pos": Vector2(1.0, 2.0),
		"vel": Vector2(3.0, 4.0),
		"alpha": 1.0,
		"fade_speed": 0.25,
		"life": 10.0,
	}
	StarpointParticleState.update_particle(particle, 2.0)
	_expect(particle.get("pos", Vector2.ZERO) == Vector2(7.0, 10.0), "starpoint particle state should advance position")
	_expect(particle.get("vel", Vector2.ZERO) == Vector2(3.0, 4.2), "starpoint particle state should apply gravity")
	_expect(is_equal_approx(float(particle.get("alpha", 0.0)), 0.5), "starpoint particle state should fade alpha")
	_expect(is_equal_approx(float(particle.get("life", 0.0)), 8.0), "starpoint particle state should decay life")


func _verify_particle_array_compaction() -> void:
	var particles := [
		{"pos": Vector2.ZERO, "vel": Vector2.ZERO, "alpha": 1.0, "fade_speed": 0.1, "life": 2.0},
		{"pos": Vector2.ZERO, "vel": Vector2.ZERO, "alpha": 0.1, "fade_speed": 1.0, "life": 2.0},
		{"pos": Vector2.ZERO, "vel": Vector2.ZERO, "alpha": 1.0, "fade_speed": 0.1, "life": 0.5},
	]
	StarpointParticleState.update_particles(particles, 1.0)
	_expect(particles.size() == 1, "starpoint particle state should remove faded or expired particles")
	_expect(is_equal_approx(float((particles[0] as Dictionary).get("alpha", 0.0)), 0.9), "starpoint particle state should keep updated survivors")


func _verify_background_delegates_starpoint_particles() -> void:
	var background := Stage2PillarBackground.new()
	background.starpoint_particles = [
		{"pos": Vector2.ZERO, "vel": Vector2(1.0, 0.0), "alpha": 1.0, "fade_speed": 0.1, "life": 2.0},
		{"pos": Vector2.ZERO, "vel": Vector2.ZERO, "alpha": 0.1, "fade_speed": 1.0, "life": 2.0},
	]
	background._update_starpoint_particles(1.0)
	_expect(background.starpoint_particles.size() == 1, "Stage 2 background should delegate starpoint particle compaction")
	var paths := [
		"res://scripts/stages/stage1/stage1_balloon_starpoint_state.gd",
		"res://scripts/stages/stage2/stage2_starpoint_coordinator.gd",
		"res://scripts/stages/stage3/stage3_starpoint_state.gd",
		"res://scripts/stages/stage4/stage4_bird_starpoint_state.gd",
	]
	for path in paths:
		var source: String = FileAccess.get_file_as_string(path)
		_expect(source.find("StarpointParticleState.update_particles") >= 0, "%s should delegate starpoint particle updates" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
