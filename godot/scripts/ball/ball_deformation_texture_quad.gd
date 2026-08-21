extends RefCounted

# draw_set_transform을 사용하지 않고 텍스처 쿼드의 네 꼭짓점을 직접 변형한다.
# battle_scene_drawer가 이미 적용한 플레이필드 변환을 자식 렌더러가 지우지 않는다.
static func draw_centered(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	size_px: float,
	color: Color,
	alpha: float,
	pivot: Vector2,
	deformation: Dictionary
) -> void:
	if canvas == null or texture == null or size_px <= 0.0 or alpha <= 0.0:
		return
	if not bool(deformation.get("active", false)):
		var size := Vector2(size_px, size_px)
		canvas.draw_texture_rect(
			texture,
			Rect2(center - size * 0.5, size),
			false,
			Color(color.r, color.g, color.b, alpha)
		)
		return
	var half_size: float = size_px * 0.5
	var points := PackedVector2Array([
		_map_point(center + Vector2(-half_size, -half_size), pivot, deformation),
		_map_point(center + Vector2(half_size, -half_size), pivot, deformation),
		_map_point(center + Vector2(half_size, half_size), pivot, deformation),
		_map_point(center + Vector2(-half_size, half_size), pivot, deformation),
	])
	var modulate := Color(color.r, color.g, color.b, alpha)
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	var uvs := PackedVector2Array([
		Vector2.ZERO,
		Vector2(1.0, 0.0),
		Vector2.ONE,
		Vector2(0.0, 1.0),
	])
	canvas.draw_polygon(points, colors, uvs, texture)


static func _map_point(point: Vector2, pivot: Vector2, deformation: Dictionary) -> Vector2:
	var axis_value: Variant = deformation.get("axis", Vector2.UP)
	var axis: Vector2 = axis_value as Vector2 if axis_value is Vector2 else Vector2.UP
	if axis.length_squared() <= 0.001:
		return point
	axis = axis.normalized()
	var perpendicular := Vector2(-axis.y, axis.x)
	var offset: Vector2 = point - pivot
	return (
		pivot
		+ axis * offset.dot(axis) * float(deformation.get("axis_scale", 1.0))
		+ perpendicular
			* offset.dot(perpendicular)
			* float(deformation.get("perpendicular_scale", 1.0))
	)
