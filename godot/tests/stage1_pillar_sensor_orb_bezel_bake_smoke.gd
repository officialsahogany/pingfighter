extends SceneTree

# Seal: 위험감지센서 오브 정적 베젤 스택 bake-once (perf).
#
# 2026-07-23 S2 라이브 triage에서 stage1.pillar_ui.sensor가 ~0.26ms/frame
# (프리미엄 리드로우 7e866bac0 + 퍽-인지 상시 가시성 e43fe13cf의 합)으로
# 확인되어, 프레임 불변인 베젤 스택(본체/셰이딩/림/리벳/웰 = 15드로 사이트)을
# pillar_orb_static_layer_cache로 1회 베이크 후 블릿 1회로 바꿨다.
#
# 씰 구성(플레이북 #5a 봉인 규율 — 폴백이 correctness-identical이라 픽셀
# 패리티 씰은 봉인력이 없으므로, 소스-계약 프리미티브 예산 + ops 지오메트리
# 계약 + 베이크 수렴으로 배선을 문다. 라이브 재측정의 라벨 us/prims가 런타임
# 직교 카운터):
#  (1) 소스 계약: 핫패스 _draw_sensor_cooldown_orb는 동적 프리미티브만
#      (draw_arc 5 / draw_circle 7) + 블릿 배선(request_build/draw_centered/
#      벡터 폴백 호출)을 갖는다. 정적 스택 색상 직접 드로우는 0.
#  (2) 폴백/ops 예산: _draw_sensor_bezel_vector = draw_arc 7 + draw_circle 4
#      사이트, _build_sensor_bezel_ops = make_arc_band_aa 7 + make_circle 4
#      사이트 (지오메트리 1:1 대응 유지 가드).
#  (3) ops 지오메트리 계약: 베젤/림/리벳/웰의 반경·폭·위치가 벡터 경로 공식과
#      일치, 총 21 ops.
#  (4) 베이크 수렴: build_now가 실제 Texture2D를 돌려주고 극단 크기가 아님.
#
# 반증검증(수동, in-place 토글 — git reset 금지):
#  - 핫패스의 블릿 분기를 지우고 벡터 스택을 되돌리면 (1) RED.
#  - ops에서 림 아크 하나를 빼면 (2)·(3) RED.

const Stage1PillarUiRenderer := preload("res://scripts/hud/stage1_pillar_ui_renderer.gd")

const RENDERER_SOURCE_PATH := "res://scripts/hud/stage1_pillar_ui_renderer.gd"
const TEST_RADIUS := 33.26
const TEST_SF := 1.44

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_hot_path_source_budget()
	_verify_fallback_and_ops_source_budget()
	_verify_ops_geometry_contract()
	_verify_bake_converges_to_texture()

	if _failures.is_empty():
		print("stage1_pillar_sensor_orb_bezel_bake_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _get_function_region(source: String, function_name: String) -> String:
	var start: int = source.find("func %s(" % function_name)
	if start < 0:
		_failures.append("source region not found: %s" % function_name)
		return ""
	var end: int = source.find("\nfunc ", start)
	if end < 0:
		end = source.length()
	return source.substr(start, end - start)


func _count_occurrences(region: String, needle: String) -> int:
	var count := 0
	var search_from := 0
	while true:
		var idx: int = region.find(needle, search_from)
		if idx < 0:
			break
		count += 1
		search_from = idx + needle.length()
	return count


func _read_renderer_source() -> String:
	var file := FileAccess.open(RENDERER_SOURCE_PATH, FileAccess.READ)
	if file == null:
		_failures.append("cannot open renderer source: %s" % RENDERER_SOURCE_PATH)
		return ""
	return file.get_as_text()


func _verify_hot_path_source_budget() -> void:
	var source: String = _read_renderer_source()
	if source.is_empty():
		return
	var hot: String = _get_function_region(source, "_draw_sensor_cooldown_orb")
	if hot.is_empty():
		return
	var arc_count: int = _count_occurrences(hot, "canvas.draw_arc(")
	var circle_count: int = _count_occurrences(hot, "canvas.draw_circle(")
	_expect(arc_count == 5, "hot path draw_arc sites should be dynamic-only 5 (got %d)" % arc_count)
	_expect(circle_count == 7, "hot path draw_circle sites should be dynamic-only 7 (got %d)" % circle_count)
	_expect(_count_occurrences(hot, "request_build") == 1, "hot path should wire the budgeted cache build")
	_expect(_count_occurrences(hot, "draw_centered") == 1, "hot path should blit the baked bezel stack")
	_expect(
		_count_occurrences(hot, "_draw_sensor_bezel_vector(") == 1,
		"hot path should keep the correctness-identical vector fallback"
	)
	_expect(
		_count_occurrences(hot, "SENSOR_COL_BEZEL") == 0,
		"hot path must not draw the static bezel stack directly"
	)


func _verify_fallback_and_ops_source_budget() -> void:
	var source: String = _read_renderer_source()
	if source.is_empty():
		return
	var fallback: String = _get_function_region(source, "_draw_sensor_bezel_vector")
	if not fallback.is_empty():
		var fb_arcs: int = _count_occurrences(fallback, "canvas.draw_arc(")
		var fb_circles: int = _count_occurrences(fallback, "canvas.draw_circle(")
		_expect(fb_arcs == 7, "vector fallback should keep 7 draw_arc sites (got %d)" % fb_arcs)
		_expect(fb_circles == 4, "vector fallback should keep 4 draw_circle sites (got %d)" % fb_circles)
	var ops_region: String = _get_function_region(source, "_build_sensor_bezel_ops")
	if not ops_region.is_empty():
		var op_arcs: int = _count_occurrences(ops_region, "make_arc_band_aa(")
		var op_circles: int = _count_occurrences(ops_region, "make_circle(")
		_expect(op_arcs == 7, "bake ops should mirror 7 arc sites (got %d)" % op_arcs)
		_expect(op_circles == 4, "bake ops should mirror 4 circle sites (got %d)" % op_circles)


func _verify_ops_geometry_contract() -> void:
	var renderer := Stage1PillarUiRenderer.new()
	var ops: Array = renderer._build_sensor_bezel_ops(TEST_RADIUS, TEST_SF)
	_expect(ops.size() == 21, "bezel bake should emit 21 ops (got %d)" % ops.size())
	if ops.size() != 21:
		return

	var bezel_inner: float = TEST_RADIUS * 0.64
	var well_radius: float = TEST_RADIUS * 0.60
	var band_mid: float = (TEST_RADIUS + bezel_inner) * 0.5

	var body: Dictionary = ops[0]
	_expect(String(body.get("kind", "")) == "circle", "op0 should be the bezel body circle")
	_expect(is_equal_approx(float(body.get("radius", 0.0)), TEST_RADIUS), "bezel body radius should match")
	_expect(body.get("color", Color()) == Stage1PillarUiRenderer.SENSOR_COL_BEZEL, "bezel body color should match the shared const")

	var band_hi: Dictionary = ops[1]
	_expect(String(band_hi.get("kind", "")) == "arc_aa", "op1 should be the upper shading arc")
	_expect(is_equal_approx(float(band_hi.get("radius", 0.0)), band_mid), "shading arc should ride band_mid")
	_expect(
		is_equal_approx(float(band_hi.get("half_width", 0.0)), max(1.0, TEST_RADIUS - bezel_inner) * 0.5),
		"shading arc width should equal the bezel band width"
	)

	var gold_rim: Dictionary = ops[4]
	_expect(is_equal_approx(float(gold_rim.get("radius", 0.0)), TEST_RADIUS - 1.7 * TEST_SF), "gold rim radius should match the vector formula")
	_expect(is_equal_approx(float(gold_rim.get("half_width", 0.0)), max(1.0, 1.9 * TEST_SF) * 0.5), "gold rim width should match the vector formula")

	var first_rivet: Dictionary = ops[7]
	_expect(String(first_rivet.get("kind", "")) == "circle", "op7 should start the rivet ring")
	var rivet_center: Vector2 = first_rivet.get("center", Vector2.ZERO)
	_expect(
		is_equal_approx(rivet_center.y, -band_mid) and absf(rivet_center.x) < 0.001,
		"first rivet should sit at 12 o'clock on band_mid"
	)

	var well: Dictionary = ops[19]
	_expect(String(well.get("kind", "")) == "circle", "op19 should be the obsidian well")
	_expect(is_equal_approx(float(well.get("radius", 0.0)), well_radius), "well radius should match")

	var shadow: Dictionary = ops[20]
	_expect(String(shadow.get("kind", "")) == "arc_aa", "op20 should be the inner shadow arc")
	var shadow_center: Vector2 = shadow.get("center", Vector2.ZERO)
	_expect(is_equal_approx(shadow_center.y, -well_radius * 0.14), "inner shadow should keep its upward offset")


func _verify_bake_converges_to_texture() -> void:
	var renderer := Stage1PillarUiRenderer.new()
	var ops: Array = renderer._build_sensor_bezel_ops(TEST_RADIUS, TEST_SF)
	var key: String = renderer._sensor_bezel_cache_key(TEST_RADIUS, TEST_SF)
	var texture: Texture2D = renderer._sensor_static_layer_cache.build_now(key, ops)
	_expect(texture != null, "build_now should produce the baked bezel texture")
	if texture == null:
		return
	var size: Vector2 = texture.get_size()
	_expect(size.x >= TEST_RADIUS * 2.0 and size.x <= TEST_RADIUS * 4.0, "baked texture width should cover the bezel extent (got %s)" % str(size))
	var cached: Texture2D = renderer._sensor_static_layer_cache.get_texture(key)
	_expect(cached == texture, "baked texture should be served from the cache on the next lookup")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
