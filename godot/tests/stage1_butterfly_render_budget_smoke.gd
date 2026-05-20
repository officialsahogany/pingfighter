extends SceneTree

const Stage1PillarAmbientState := preload("res://scripts/stages/stage1/stage1_pillar_ambient_state.gd")
const Stage1PillarBackground := preload("res://scripts/stages/stage1/stage1_pillar_background.gd")
const Stage1PillarButterflyRenderer := preload("res://scripts/stages/stage1/stage1_pillar_butterfly_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_render_budget_constants()
	_verify_perf_labels_and_forwarding()

	if _failures.is_empty():
		print("stage1_butterfly_render_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_render_budget_constants() -> void:
	_expect(Stage1PillarAmbientState.BUTTERFLY_TRAIL_LIMIT <= 6, "Stage 1 butterfly trail should keep a tight render history")
	_expect(Stage1PillarAmbientState.BUTTERFLY_PARTICLE_LIMIT <= 14, "Stage 1 butterfly particles should keep a tight render history")
	_expect(Stage1PillarAmbientState.BUTTERFLY_ABSORB_BURST_COUNT <= 8, "Stage 1 butterfly absorb burst should keep a bounded particle spawn")
	_expect(Stage1PillarAmbientState.BUTTERFLY_ABSORB_DRIP_CHANCE <= 0.25, "Stage 1 butterfly absorb drip should keep a bounded per-frame spawn chance")
	_expect(Stage1PillarBackground.BUTTERFLY_ABSORB_RING_COUNT <= 1, "Stage 1 butterfly absorb should keep a tight ring count")
	_expect(Stage1PillarBackground.BUTTERFLY_ABSORB_RING_SEGMENTS <= 18, "Stage 1 butterfly absorb should keep a bounded ring segment budget")
	_expect(Stage1PillarBackground.BUTTERFLY_ABSORB_RING_SEGMENTS_LOD <= 10, "Stage 1 butterfly absorb should keep a tight LOD ring segment budget")
	_expect(Stage1PillarButterflyRenderer.LOD_BUTTERFLY_STRIDE >= 2, "Stage 1 butterfly pillar renderer should stride decorative butterflies under LOD")


func _verify_perf_labels_and_forwarding() -> void:
	var background_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_pillar_background.gd")
	var scene_drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	var pillar_butterfly_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_pillar_butterfly_renderer.gd")
	_expect(
		background_source.find("func draw_butterfly_ingame(") >= 0
			and background_source.find("perf_logger: Object = null") >= 0,
		"Stage 1 butterfly draw should accept the shared perf logger"
	)
	for label in [
		"stage1.butterfly.trail",
		"stage1.butterfly.particles",
		"stage1.butterfly.sprite",
		"stage1.butterfly.absorb",
	]:
		_expect(background_source.find(label) >= 0, "butterfly draw should report " + label)
	_expect(
		scene_drawer_source.find("draw_butterfly_ingame(canvas, shake_offset, perf_logger)") >= 0,
		"playfield scene drawer should forward BattlePerf logger to Stage 1 butterfly draw"
	)
	_expect(
		pillar_butterfly_source.find("var left_rect: Rect2 = geometry.get_side_rect(\"left\"") >= 0
			and pillar_butterfly_source.find("var right_rect: Rect2 = geometry.get_side_rect(\"right\"") >= 0,
		"pillar butterfly renderer should compute side rects once per draw pass"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
