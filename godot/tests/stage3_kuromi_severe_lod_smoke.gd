extends SceneTree

const Stage3PlayfieldRenderer := preload("res://scripts/stages/stage3/stage3_playfield_renderer.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_severe_lod_snapshot()
	_verify_severe_lod_source_path()

	if _failures.is_empty():
		print("stage3_kuromi_severe_lod_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_severe_lod_snapshot() -> void:
	var renderer := Stage3PlayfieldRenderer.new()
	var snapshot := renderer.get_performance_snapshot()
	_expect(
		bool(snapshot.get("kuromi_severe_lod_simplified", false)),
		"Stage 3 playfield should report the simplified severe-LOD Kuromi path"
	)
	_expect(
		bool(snapshot.get("shared_render_quality_lod_supported", false)),
		"Stage 3 playfield should keep shared render-quality LOD enabled"
	)


func _verify_severe_lod_source_path() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_playfield_renderer.gd")
	var kuromi_body := _function_body(source, "func _draw_kuromi(")
	_expect(
		source.find("func _draw_kuromi_severe_lod") >= 0,
		"Stage 3 playfield should define a simplified Kuromi severe-LOD draw path"
	)
	_expect(
		kuromi_body.find("_is_severe_lod_active(quality_scale)") >= 0,
		"Stage 3 Kuromi draw should branch on severe LOD"
	)
	_expect(
		kuromi_body.find("_draw_kuromi_severe_lod") >= 0,
		"Stage 3 Kuromi draw should use the simplified severe-LOD draw path"
	)
	_expect(
		kuromi_body.find("stage3_kuromi_eating_active") >= 0,
		"Stage 3 Kuromi severe LOD should keep eating-pattern visuals on the full path"
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
