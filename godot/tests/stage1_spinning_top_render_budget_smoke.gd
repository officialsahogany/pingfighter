extends SceneTree

const Stage1DaljiSpinningTopRenderer := preload("res://scripts/stages/stage1/stage1_dalji_spinning_top_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_render_budget_constants()
	_verify_perf_labels_and_forwarding()

	if _failures.is_empty():
		print("stage1_spinning_top_render_budget_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_render_budget_constants() -> void:
	_expect(Stage1DaljiSpinningTopRenderer.WHIP_SEGMENTS <= 3, "Stage 1 spinning top whip should use the reduced segment budget")
	_expect(Stage1DaljiSpinningTopRenderer.LOD_WHIP_SEGMENTS <= 1, "Stage 1 spinning top whip should keep a tight LOD segment budget")
	_expect(Stage1DaljiSpinningTopRenderer.BODY_LAYER_COUNT <= 3, "Stage 1 spinning top body should use the reduced layer budget")
	_expect(Stage1DaljiSpinningTopRenderer.LOD_BODY_LAYER_COUNT <= 1, "Stage 1 spinning top body should keep a tight LOD layer budget")
	_expect(Stage1DaljiSpinningTopRenderer.GOLDEN_OUTER_GLOW_LAYERS <= 2, "Stage 1 golden top outer glow should keep a bounded layer budget")
	_expect(Stage1DaljiSpinningTopRenderer.GOLDEN_INNER_GLOW_LAYERS <= 2, "Stage 1 golden top inner glow should keep a bounded layer budget")


func _verify_perf_labels_and_forwarding() -> void:
	var renderer_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_dalji_spinning_top_renderer.gd")
	var actor_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_actor_renderer.gd")
	var scene_drawer_source := FileAccess.get_file_as_string("res://scripts/core/battle_playfield_scene_drawer.gd")
	_expect(renderer_source.find("stage1.spinning_top.whip") >= 0, "spinning top renderer should expose whip sublabel")
	_expect(renderer_source.find("stage1.spinning_top.tops") >= 0, "spinning top renderer should expose top-body sublabel")
	_expect(actor_source.find("perf_logger: Object = null") >= 0, "Stage 1 actor renderer should accept BattlePerf for spinning-top draw")
	_expect(
		scene_drawer_source.find("draw_spinning_top(canvas, actor_context, perf_logger)") >= 0,
		"playfield scene drawer should forward BattlePerf logger to Stage 1 spinning-top draw"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
