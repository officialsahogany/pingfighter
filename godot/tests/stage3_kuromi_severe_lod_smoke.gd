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
		bool(snapshot.get("kuromi_severe_lod_restored", false)),
		"Stage 3 playfield should report the restored severe-LOD Kuromi path"
	)
	_expect(
		float(snapshot.get("kuromi_severe_lod_restore_quality_scale", 0.0)) >= 0.80
			and float(snapshot.get("kuromi_severe_lod_restore_quality_scale", 1.0)) < 0.85,
		"Stage 3 restored severe-LOD Kuromi should reuse the budgeted non-severe LOD shape"
	)
	_expect(
		bool(snapshot.get("shared_render_quality_lod_supported", false)),
		"Stage 3 playfield should keep shared render-quality LOD enabled"
	)


func _verify_severe_lod_source_path() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_playfield_renderer.gd")
	var kuromi_body := _function_body(source, "func _draw_kuromi(")
	var severe_body := _function_body(source, "func _draw_kuromi_severe_lod(")
	_expect(
		source.find("func _draw_kuromi_severe_lod") >= 0,
		"Stage 3 playfield should define a restored Kuromi severe-LOD draw path"
	)
	_expect(
		kuromi_body.find("_is_severe_lod_active(quality_scale)") >= 0,
		"Stage 3 Kuromi draw should branch on severe LOD"
	)
	_expect(
		kuromi_body.find("_draw_kuromi_severe_lod") >= 0,
		"Stage 3 Kuromi draw should use the restored severe-LOD draw path"
	)
	_expect(
		kuromi_body.find("stage3_kuromi_eating_active") >= 0,
		"Stage 3 Kuromi severe LOD should keep eating-pattern visuals on the full path"
	)
	_expect(
		severe_body.find("KUROMI_SEVERE_RESTORE_QUALITY_SCALE") >= 0
			and severe_body.find("_draw_petrified_kuromi") >= 0
			and severe_body.find("_draw_awake_kuromi") >= 0,
		"Stage 3 restored severe-LOD Kuromi should reuse the backup-style full shape renderer"
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
