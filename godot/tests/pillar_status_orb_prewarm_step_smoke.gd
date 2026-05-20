extends SceneTree

const PillarStatusOrbRenderer := preload("res://scripts/hud/pillar_status_orb_renderer.gd")
const DashTokenBoostFxHost := preload("res://scripts/hud/dash_token_boost_fx_host.gd")

var _failures: Array[String] = []


func _init() -> void:
	var renderer := PillarStatusOrbRenderer.new()
	var calls := 0
	while not renderer.prewarm_caches_step([16.0, 20.0]) and calls < 10:
		calls += 1
	_expect(calls == 5, "status orb prewarm should split two radii across six small chunks")
	_expect(renderer._prewarm_cache_step_index == 0, "status orb prewarm step index should reset after completion")

	# The status orb renderer must drive the boost FX host's static prewarm so
	# the shader resource is loaded before the first frame asks the FX host to
	# sync any slot state. The pipeline status dict is the externally visible
	# evidence that prewarm_assets() ran.
	var status: Dictionary = renderer.get_boost_fx_host_pipeline_status()
	_expect(
		bool(status.get("dash_token_boost_ring_shader_ready", false)),
		"prewarm_caches_step must mark the dash token boost ring shader as ready"
	)
	_expect(
		bool(status.get("dash_token_boost_ring_white_texture_ready", false)),
		"prewarm_caches_step must build the boost FX host's shared white texture"
	)
	_expect(
		int(status.get("dash_token_boost_ring_max_slots", 0)) >= 2,
		"boost FX host must expose enough slots for player + boss dash orbs"
	)

	# Calling prewarm_assets() multiple times should be idempotent so the
	# resource prewarm controller can re-enter the step path safely.
	DashTokenBoostFxHost.prewarm_assets()
	DashTokenBoostFxHost.prewarm_assets()
	var second_status: Dictionary = DashTokenBoostFxHost.build_pipeline_status()
	_expect(
		bool(second_status.get("dash_token_boost_ring_shader_ready", false)),
		"boost FX host prewarm_assets() must stay ready after a second call"
	)

	if _failures.is_empty():
		print("pillar_status_orb_prewarm_step_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
