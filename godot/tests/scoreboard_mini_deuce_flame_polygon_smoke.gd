extends SceneTree

# Seals the deuce mini-scoreboard flame geometry: every flame layer polygon
# must stay triangulable across the animation cycle. Regression reference:
# tongues flattened to exactly the baseline (max(0, h)) ran collinear with /
# duplicated the closing baseline edge, so draw_colored_polygon failed
# triangulation on the frames where the sine stack went non-positive —
# continuous "Invalid polygon data" spam during deuce (2026-06-11, 218MB log).

const ScoreboardTopMiniDeuceEffectRenderer := preload("res://scripts/hud/scoreboard_top_mini_deuce_effect_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_flame_layers_stay_triangulable_across_cycle()
	_verify_tongues_stay_above_the_closing_baseline()

	if _failures.is_empty():
		print("scoreboard_mini_deuce_flame_polygon_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_flame_layers_stay_triangulable_across_cycle() -> void:
	var cases: Array = [
		[Rect2(300.0, 20.0, 160.0, 28.0), 1.0, ScoreboardTopMiniDeuceEffectRenderer.FLAME_STEP],
		[Rect2(300.0, 20.0, 160.0, 28.0), 1.0, ScoreboardTopMiniDeuceEffectRenderer.FLAME_STEP_LOD],
		[Rect2(120.0, 12.0, 80.0, 18.0), 0.6, ScoreboardTopMiniDeuceEffectRenderer.FLAME_STEP],
		[Rect2(40.0, 8.0, 320.0, 40.0), 1.4, ScoreboardTopMiniDeuceEffectRenderer.FLAME_STEP],
	]
	var failures_found := 0
	for case_value in cases:
		var rect: Rect2 = case_value[0]
		var scale_factor: float = case_value[1]
		var step_size: int = case_value[2]
		for layer in range(ScoreboardTopMiniDeuceEffectRenderer.FLAME_LAYER_COUNT):
			for t_step in range(0, 126):
				var t: float = float(t_step) * 0.05
				var points: PackedVector2Array = ScoreboardTopMiniDeuceEffectRenderer.build_flame_layer_points(
					rect, scale_factor, t, layer, step_size
				)
				if Geometry2D.triangulate_polygon(points).is_empty():
					failures_found += 1
	_expect(
		failures_found == 0,
		"every flame layer polygon should stay triangulable across the animation cycle (got %d degenerate samples)" % failures_found
	)


func _verify_tongues_stay_above_the_closing_baseline() -> void:
	var rect := Rect2(300.0, 20.0, 160.0, 28.0)
	var baseline_y: float = rect.position.y + 7.0
	var points: PackedVector2Array = ScoreboardTopMiniDeuceEffectRenderer.build_flame_layer_points(
		rect, 1.0, 2.4, 0, ScoreboardTopMiniDeuceEffectRenderer.FLAME_STEP
	)
	var interior_on_baseline := 0
	for index in range(1, points.size() - 1):
		if points[index].y >= baseline_y - 0.0001:
			interior_on_baseline += 1
	_expect(
		interior_on_baseline == 0,
		"interior tongue points must keep a positive lift off the closing baseline edge (%d touched it)" % interior_on_baseline
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
