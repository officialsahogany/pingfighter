extends RefCounted

const Stage1PillarLayerGeometry := preload("res://scripts/stages/stage1/stage1_pillar_layer_geometry.gd")

var geometry: Object = Stage1PillarLayerGeometry.new()


func draw_tree_drop_petals(canvas: CanvasItem, tree_drop_petals: Array[Dictionary]) -> void:
	for petal in tree_drop_petals:
		var max_life: float = max(0.001, float(petal.get("max_life", 1.0)))
		var life_ratio: float = clamp(float(petal.get("life", 0.0)) / max_life, 0.0, 1.0)
		var alpha: float = (230.0 / 255.0) * min(1.0, life_ratio * 1.45)
		if alpha <= 0.01:
			continue
		var size: float = max(3.0, float(petal.get("size", 6.0)))
		var pos := Vector2(float(petal["x"]), float(petal["y"]))
		var color: Color = petal["color"]
		var rect := Rect2(pos - Vector2(size + 2.5, size * 0.5 + 2.5), Vector2(size * 2.0 + 5.0, size + 5.0))
		canvas.draw_colored_polygon(geometry.build_ellipse_points(rect, 14), Color(color.r, color.g, color.b, alpha))
		canvas.draw_arc(rect.get_center(), max(2.0, size * 0.72), 0.15, PI + 0.15, 12, Color(184.0 / 255.0, 82.0 / 255.0, 94.0 / 255.0, alpha * 0.34), 1.0)
		canvas.draw_line(pos + Vector2(-size * 0.10, size * 0.35), pos + Vector2(size * 0.55, -size * 0.05), Color(198.0 / 255.0, 96.0 / 255.0, 108.0 / 255.0, alpha * 0.36), 1.0)


func draw_floating_petals(canvas: CanvasItem, floating_petals: Array[Dictionary]) -> void:
	for petal in floating_petals:
		var size: float = float(petal.get("size", 7.0))
		var pos := Vector2(float(petal["x"]), float(petal["y"]))
		var color: Color = petal["color"]
		var rect := Rect2(pos - Vector2(size, size * 0.5), Vector2(size * 2.0, size))
		canvas.draw_colored_polygon(geometry.build_ellipse_points(rect, 12), color)
