extends SceneTree

const SourceContractFunctionBody := preload("res://tests/source_contract_function_body.gd")
const Stage3EllipseGeometryCache := preload("res://scripts/stages/stage3/stage3_ellipse_geometry_cache.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_geometry_and_cache_policy()
	_verify_playfield_single_owner_contract()
	if _failures.is_empty():
		print("stage3_ellipse_geometry_cache_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_geometry_and_cache_policy() -> void:
	var cache := Stage3EllipseGeometryCache.new()
	var rect := Rect2(10.0, 20.0, 8.0, 12.0)
	var points := cache.get_points(rect, 4)
	_expect(points.size() == 8, "ellipse geometry should preserve the eight-segment minimum")
	_expect(points[0].is_equal_approx(Vector2(18.0, 26.0)), "ellipse geometry should begin on the positive X radius")
	var cached_points := cache.get_points(rect, 4)
	_expect(cached_points == points, "repeated ellipse geometry should reuse identical cached coordinates")
	_expect(cache.points_cache.size() == 1, "repeated ellipse geometry should keep one cache entry")
	var outline := cache.get_outline_points(rect, 4)
	_expect(outline.size() == 9, "ellipse outline should append one closing point")
	_expect(outline[0].is_equal_approx(outline[outline.size() - 1]), "ellipse outline should close without per-draw duplication")
	_expect(cache.outline_points_cache.size() == 1, "ellipse outline should cache its closed array")

	for index in range(Stage3EllipseGeometryCache.MAX_POINTS_CACHE_ENTRIES + 2):
		cache.get_points(Rect2(float(index) * 3.0, 1.0, 5.0, 7.0), 12)
	_expect(cache.points_cache.size() > 0 and cache.points_cache.size() <= Stage3EllipseGeometryCache.MAX_POINTS_CACHE_ENTRIES, "ellipse point cache should clear at its bounded capacity")
	cache.clear()
	var snapshot := cache.get_snapshot()
	_expect(int(snapshot.get("unit_point_cache_count", -1)) == 0, "cache clear should remove unit geometry")
	_expect(int(snapshot.get("points_cache_count", -1)) == 0, "cache clear should remove ellipse geometry")
	_expect(int(snapshot.get("outline_points_cache_count", -1)) == 0, "cache clear should remove outline geometry")


func _verify_playfield_single_owner_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/stages/stage3/stage3_playfield_renderer.gd")
	_expect(source.find("var _ellipse_geometry_cache: Stage3EllipseGeometryCache") >= 0, "Stage 3 playfield should keep one typed ellipse cache owner")
	for mirror in ["ellipse_unit_point_cache", "ellipse_points_cache", "ellipse_outline_points_cache"]:
		_expect(source.find("var %s: Dictionary = {}" % mirror) == -1, "%s mirror should be removed" % mirror)
	_expect(_function_body(source, "func _ellipse_points(").find("_ellipse_geometry_cache.get_points") >= 0, "ellipse point facade should delegate to the cache owner")
	_expect(_function_body(source, "func _ellipse_outline_points(").find("_ellipse_geometry_cache.get_outline_points") >= 0, "ellipse outline facade should delegate to the cache owner")
	_expect(_function_body(source, "func _get_ellipse_unit_points(").find("_ellipse_geometry_cache.get_unit_points") >= 0, "unit point facade should delegate to the cache owner")


func _function_body(source: String, signature: String) -> String:
	return SourceContractFunctionBody.extract(source, signature)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
