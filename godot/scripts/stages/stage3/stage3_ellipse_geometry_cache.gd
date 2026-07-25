extends RefCounted

const MAX_POINTS_CACHE_ENTRIES := 128
const MAX_OUTLINE_POINTS_CACHE_ENTRIES := 128

var unit_point_cache: Dictionary = {}
var points_cache: Dictionary = {}
var outline_points_cache: Dictionary = {}


func get_points(rect: Rect2, segments: int) -> PackedVector2Array:
	var count := maxi(8, segments)
	var cache_key := _rect_cache_key(rect, count)
	var cached: Variant = points_cache.get(cache_key, null)
	if cached is PackedVector2Array:
		return cached
	var unit_points := get_unit_points(count)
	var points := PackedVector2Array()
	var center := rect.get_center()
	var radius := rect.size * 0.5
	for point in unit_points:
		points.append(center + Vector2(point.x * radius.x, point.y * radius.y))
	if points_cache.size() >= MAX_POINTS_CACHE_ENTRIES:
		points_cache.clear()
	points_cache[cache_key] = points
	return points


func get_outline_points(rect: Rect2, segments: int) -> PackedVector2Array:
	var count := maxi(8, segments)
	var cache_key := _rect_cache_key(rect, count)
	var cached: Variant = outline_points_cache.get(cache_key, null)
	if cached is PackedVector2Array:
		return cached
	var points := get_points(rect, count)
	if points.is_empty():
		return PackedVector2Array()
	var closed_points := PackedVector2Array()
	for point in points:
		closed_points.append(point)
	closed_points.append(points[0])
	if outline_points_cache.size() >= MAX_OUTLINE_POINTS_CACHE_ENTRIES:
		outline_points_cache.clear()
	outline_points_cache[cache_key] = closed_points
	return closed_points


func get_unit_points(segments: int) -> PackedVector2Array:
	if unit_point_cache.has(segments):
		return unit_point_cache[segments]
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)))
	unit_point_cache[segments] = points
	return points


func clear() -> void:
	unit_point_cache.clear()
	points_cache.clear()
	outline_points_cache.clear()


func get_snapshot() -> Dictionary:
	return {
		"unit_point_cache_count": unit_point_cache.size(),
		"points_cache_count": points_cache.size(),
		"outline_points_cache_count": outline_points_cache.size(),
	}


func _rect_cache_key(rect: Rect2, segments: int) -> String:
	return "%d:%d:%d:%d:%d" % [
		int(round(rect.position.x * 10.0)),
		int(round(rect.position.y * 10.0)),
		int(round(rect.size.x * 10.0)),
		int(round(rect.size.y * 10.0)),
		segments,
	]
