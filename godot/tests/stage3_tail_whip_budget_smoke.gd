extends SceneTree

const Stage3BossSkillState := preload("res://scripts/stages/stage3/stage3_boss_skill_state.gd")
const Stage3EffectRenderer := preload("res://scripts/stages/stage3/stage3_menhera_skill_effect_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_tail_runtime_budget()
	_verify_tail_renderer_sampling_budget()

	if _failures.is_empty():
		print("stage3_tail_whip_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_tail_runtime_budget() -> void:
	var state := Stage3BossSkillState.new()
	state.force_kuromi_awake()
	state.set("kuromi_eating_cooldown", 10.0)
	state.set("tail_whip_active", true)
	state.set("tail_whip_timer", 0.5)
	state.set("tail_whip_target", Vector2(390.0, 375.0))
	state.set("tail_has_target", true)
	var context := {
		"current_stage": 3,
		"ball_pos": Vector2(390.0, 375.0),
		"ball_vel": Vector2(10.0, 0.0),
		"player_pos": Vector2(300.0, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"play_left": 0.0,
		"play_right": 760.0,
		"play_height": 750.0,
	}
	var result: Dictionary = state.update(1.0 / 60.0, context, {})
	var snapshot: Dictionary = state.get_snapshot()
	_expect(_as_array(snapshot.get("stage3_tail_points", [])).size() == Stage3BossSkillState.TAIL_POINT_COUNT, "tail runtime should export the budgeted curve point count")
	_expect(Stage3BossSkillState.TAIL_POINT_COUNT <= 24, "tail runtime should not return to the old 30-point hot path")
	_expect(bool(snapshot.get("stage3_tail_curve_active", false)), "tail collision should still arm curve-after-hit")
	_expect(result.has("ball_vel"), "tail collision should still redirect the ball")
	_expect(_as_array(snapshot.get("stage3_tail_hit_bursts", [])).size() <= Stage3BossSkillState.MAX_TAIL_HIT_BURSTS, "tail hit bursts should stay capped")
	var prism_count: int = _as_array(snapshot.get("stage3_prism_particles", [])).size()
	_expect(prism_count >= Stage3BossSkillState.TAIL_HIT_PRISM_MIN_COUNT, "tail hit should keep the prism burst")
	_expect(prism_count <= Stage3BossSkillState.TAIL_HIT_PRISM_MAX_COUNT, "tail hit should use the reduced strong prism burst budget")
	_expect(Stage3BossSkillState.MAX_PRISM_PARTICLES <= 60, "tail prism live cap should stay below the old 90-particle cap")


func _verify_tail_renderer_sampling_budget() -> void:
	var renderer := Stage3EffectRenderer.new()
	var runtime_points: Array = []
	for index in range(Stage3BossSkillState.TAIL_POINT_COUNT):
		runtime_points.append(Vector2(float(index), float(index * 2)))
	renderer._copy_tail_draw_points(runtime_points, Stage3EffectRenderer.TAIL_DRAW_POINT_LIMIT, Vector2(1.0, 2.0))
	_expect(renderer.tail_draw_points.size() == Stage3EffectRenderer.TAIL_DRAW_POINT_LIMIT, "tail renderer should downsample normal-quality curve points")
	_expect(renderer.tail_draw_points[0] == Vector2(1.0, 2.0), "tail renderer should preserve the first sampled point")
	_expect(renderer.tail_draw_points[renderer.tail_draw_points.size() - 1] == Vector2(float(Stage3BossSkillState.TAIL_POINT_COUNT), float((Stage3BossSkillState.TAIL_POINT_COUNT - 1) * 2 + 2)), "tail renderer should preserve the end sampled point")
	renderer.tail_draw_points.clear()
	renderer._active_quality_scale = 0.5
	var severe_limit: int = renderer._get_lod_count(
		Stage3EffectRenderer.TAIL_DRAW_POINT_LIMIT,
		Stage3EffectRenderer.TAIL_DRAW_POINT_LIMIT_LOD,
		Stage3EffectRenderer.TAIL_DRAW_POINT_LIMIT_SEVERE_LOD
	)
	renderer._copy_tail_draw_points(runtime_points, severe_limit, Vector2.ZERO)
	_expect(renderer.tail_draw_points.size() <= Stage3EffectRenderer.TAIL_DRAW_POINT_LIMIT_SEVERE_LOD, "tail renderer should use the severe LOD curve cap")
	_expect(renderer._get_tail_shadow_step() == 0, "tail renderer should skip shadow segments in severe LOD")


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
