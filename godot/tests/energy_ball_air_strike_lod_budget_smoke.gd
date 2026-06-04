extends SceneTree

const BallEffectsRenderer := preload("res://scripts/ball/ball_effects_renderer.gd")
const BallIntensityEffectRenderer := preload("res://scripts/ball/ball_intensity_effect_renderer.gd")
const BallIntensityParticleState := preload("res://scripts/ball/ball_intensity_particle_state.gd")
const BallIntensityTrailState := preload("res://scripts/ball/ball_intensity_trail_state.gd")
const EnergyBallFxHost := preload("res://scripts/ball/energy_ball_fx_host.gd")
const EnergyBallRenderer := preload("res://scripts/ball/energy_ball_renderer.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_air_strike_lod_budget()
	_verify_ball_effect_lod_budget()

	if _failures.is_empty():
		print("energy_ball_air_strike_lod_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_air_strike_lod_budget() -> void:
	_expect(
		EnergyBallFxHost.AIR_STRIKE_GPU_BURST_SKIP_LOD_THRESHOLD >= ViperAirborneLod.LOD_EFFECT_SCALE,
		"Air Strike LOD should skip the EnergyBall GPU hit-burst restart"
	)
	_expect(
		EnergyBallFxHost.SEVERE_LOD_AURA_PARTICLE_THRESHOLD >= ViperAirborneLod.LOD_EFFECT_SCALE,
		"Air Strike LOD should disable the EnergyBall aura particle layer"
	)
	_expect(
		EnergyBallRenderer.SEVERE_LOD_PARTICLE_DRAW_MIN_SCALE >= ViperAirborneLod.LOD_EFFECT_SCALE,
		"Air Strike LOD should skip procedural EnergyBall particle draws"
	)
	var fx_source := FileAccess.get_file_as_string("res://scripts/ball/energy_ball_fx_host.gd")
	_expect(
		_function_body(fx_source, "func _should_skip_gpu_hit_burst").find("\"viper_air_strike\"") >= 0,
		"EnergyBallFxHost should gate the special Viper Air Strike burst by kind"
	)
	_expect(
		_function_body(fx_source, "func _trigger_hit_burst").find("_should_skip_gpu_hit_burst(kind)") >= 0,
		"EnergyBallFxHost should avoid restarting burst particles under the Air Strike LOD"
	)
	var renderer_source := FileAccess.get_file_as_string("res://scripts/ball/energy_ball_renderer.gd")
	_expect(
		_function_body(renderer_source, "func draw").find("particle_renderer.clear()") >= 0,
		"EnergyBallRenderer should clear procedural particles instead of drawing them in severe LOD"
	)
	var runtime_prewarm_body := _function_body(renderer_source, "func prewarm_runtime_nodes_step")
	_expect(
		runtime_prewarm_body.find("_sync_runtime_node_prewarm()") >= 0
			and runtime_prewarm_body.find("return false") >= 0,
		"EnergyBallRenderer should stage one offscreen active FX-host frame before the first visible ball draw"
	)
	_expect(
		_function_body(renderer_source, "func _sync_runtime_node_prewarm").find("sync_state") >= 0,
		"EnergyBallRenderer runtime-node prewarm should exercise the FX host sync_state path off-screen"
	)


func _verify_ball_effect_lod_budget() -> void:
	_expect(
		BallIntensityEffectRenderer.SEVERE_LOD_SCALE_THRESHOLD >= ViperAirborneLod.LOD_EFFECT_SCALE,
		"Ball intensity renderer should classify Air Strike LOD as severe"
	)
	_expect(
		BallIntensityEffectRenderer.SEVERE_LOD_INTENSITY_PARTICLE_LIMIT <= 8,
		"Ball intensity renderer should cap Air Strike particles tightly"
	)
	_expect(
		BallIntensityParticleState.SEVERE_LOD_MAX_PARTICLES <= 18,
		"Ball intensity state should cap retained particles before the draw pass"
	)
	_expect(
		BallIntensityParticleState.SEVERE_LOD_SPAWN_CHANCE_MULTIPLIER <= 0.50,
		"Ball intensity state should reduce severe-LOD particle spawn pressure"
	)
	_expect(
		BallIntensityTrailState.SEVERE_LOD_TRAIL_LENGTH <= 4,
		"Ball intensity trail state should cap retained severe-LOD trail points"
	)
	_expect(
		BallEffectsRenderer.SEVERE_LOD_SCALE_THRESHOLD >= ViperAirborneLod.LOD_EFFECT_SCALE,
		"Ball effects renderer should classify Air Strike LOD as severe"
	)
	_expect(
		BallEffectsRenderer.SEVERE_LOD_ENERGY_PARTICLE_LIMIT <= 7,
		"Ball effects renderer should cap Air Strike energy particles tightly"
	)
	var intensity_source := FileAccess.get_file_as_string("res://scripts/ball/ball_intensity_effect_renderer.gd")
	var intensity_draw := _function_body(intensity_source, "func draw")
	_expect(
		intensity_draw.find("if not severe_lod") >= 0,
		"Ball intensity renderer should skip the extra current-ball glow in severe LOD"
	)
	_expect(
		_function_body(intensity_source, "func _draw_particles").find("not severe_lod and size > 3.2") >= 0,
		"Ball intensity renderer should skip flame sparkle accents in severe LOD"
	)
	var effects_source := FileAccess.get_file_as_string("res://scripts/ball/ball_effects_renderer.gd")
	_expect(
		_function_body(effects_source, "func _draw_energy_explosion_particles").find("_draw_energy_burst_compact") >= 0,
		"Ball effects renderer should use a compact energy burst in severe LOD"
	)
	_expect(
		_function_body(effects_source, "func _draw_energy_burst_compact").find("draw_full_ring") >= 0,
		"Compact energy burst should preserve a visible shock ring"
	)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return source.substr(start)
	return source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
