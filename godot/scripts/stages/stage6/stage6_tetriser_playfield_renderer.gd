extends RefCounted

# Stage 6 Tetriser playfield renderer.
#
# Planning: docs/stage6_tetriser_port_plan.md
# Draws the procedural Stage 6 battle-layer state from actor draw context:
# tetrominoes, guard bars, edge walls, debris, central cube, laser, EMP, and
# Crystal Shield blocks.

const ASSEMBLING_ALPHA := 0.5
const BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.22)
const BORDER_COLOR_ASSEMBLING := Color(1.0, 1.0, 1.0, 0.12)
const INNER_HIGHLIGHT := Color(1.0, 1.0, 1.0, 0.14)
const SUPER_BORDER_COLOR := Color(1.0, 0.45, 0.18, 0.95)
const CRYSTAL_SHIELD_ORBIT_RADIUS_FALLBACK := 110.0
const CUBE_VISUAL_REFERENCE_MIN := 750.0
const CUBE_VISUAL_SIZE_RATIO := 0.09
const CUBE_VISUAL_SCALE := 0.00972
const CUBE_CAMERA_DISTANCE := 3.2
const CUBE_FOV := 360.0
const CUBE_LIGHT_DIR := Vector3(0.4, -0.7, 0.6)
const CUBE_FACE_BLUE := Color(100.0 / 255.0, 170.0 / 255.0, 255.0 / 255.0, 1.0)
const CUBE_FACE_RED := Color(1.0, 80.0 / 255.0, 80.0 / 255.0, 1.0)
const CUBE_FACE_PURPLE := Color(200.0 / 255.0, 80.0 / 255.0, 1.0, 1.0)
const CUBE_EDGE_GLOW := Color(120.0 / 255.0, 200.0 / 255.0, 1.0, 1.0)
const CUBE_EDGE_MAIN := Color(220.0 / 255.0, 240.0 / 255.0, 1.0, 1.0)


func prewarm_assets() -> void:
	pass


func prewarm_assets_step() -> bool:
	return true


func reset() -> void:
	pass


func clear_transient_canvas_items() -> void:
	pass


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, _perf_logger: Object = null) -> void:
	if canvas == null:
		return
	var cell_size: float = float(context.get("stage6_tetriser_cell_size", 20.0))
	var cube: Dictionary = context.get("stage6_tetriser_cube", {})
	if not cube.is_empty():
		_draw_cube(canvas, cube, shake_offset)
	for tetro in context.get("stage6_tetriser_tetrominoes", []):
		_draw_tetromino(canvas, tetro, cell_size, shake_offset)
	for guard in context.get("stage6_tetriser_guard_blocks", []):
		_draw_guard_block(canvas, guard, cell_size, shake_offset)
	var cell_vec := Vector2(cell_size, cell_size)
	for wall_cell in context.get("stage6_tetriser_wall_cells", []):
		_draw_wall_cell(canvas, wall_cell, cell_vec, shake_offset)
	for debris in context.get("stage6_tetriser_debris", []):
		_draw_debris(canvas, debris, shake_offset)
	for drop in context.get("stage6_tetriser_starpoint_drops", []):
		if drop is Dictionary:
			_draw_starpoint_drop(canvas, drop, shake_offset)
	_draw_laser(canvas, context, shake_offset)
	for emp in context.get("stage6_tetriser_emp", []):
		_draw_emp(canvas, emp, shake_offset)
	_draw_crystal_shield(canvas, context, shake_offset)


func _draw_laser(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var laser: Dictionary = context.get("stage6_tetriser_laser", {})
	if laser.is_empty():
		return
	var target: Vector2 = _as_vector2(laser.get("target", Vector2.ZERO)) + shake_offset
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)))
	var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)))
	var origin: Vector2 = boss_pos + Vector2(boss_size.x * 0.5, boss_size.y) + shake_offset
	var progress: float = clampf(float(laser.get("progress", 0.0)), 0.0, 1.0)
	match String(laser.get("state", "")):
		"charging":
			canvas.draw_line(origin, target, Color(1.0, 0.4, 0.2, 0.18 + 0.5 * progress), 1.0 + 3.0 * progress, true)
		"firing":
			var fade: float = 1.0 - progress
			canvas.draw_line(origin, target, Color(1.0, 0.5, 0.2, 0.6 * fade), 14.0, true)
			canvas.draw_line(origin, target, Color(1.0, 0.95, 0.7, 0.9 * fade), 5.0, true)


func _draw_emp(canvas: CanvasItem, emp: Dictionary, shake_offset: Vector2) -> void:
	var progress: float = clampf(float(emp.get("progress", 0.0)), 0.0, 1.0)
	var alpha: float = (1.0 - progress) * 0.6
	if alpha <= 0.0:
		return
	var center: Vector2 = _as_vector2(emp.get("center", Vector2.ZERO)) + shake_offset
	canvas.draw_arc(center, 20.0 + progress * 160.0, 0.0, TAU, 48, Color(0.4, 0.7, 1.0, alpha), 3.0, true)


func _draw_tetromino(canvas: CanvasItem, tetro: Dictionary, cell_size: float, shake_offset: Vector2) -> void:
	var cells: Array = tetro.get("cells", [])
	if cells.is_empty():
		return
	var cs: float = float(tetro.get("cell_size", cell_size))   # super 테트로는 1.7× (34px)
	var origin: Vector2 = _as_vector2(tetro.get("origin", Vector2.ZERO)) + shake_offset
	var visible: int = mini(int(tetro.get("visible_cells", cells.size())), cells.size())
	var assembling: bool = String(tetro.get("state", "")) == "assembling"
	var is_super: bool = bool(tetro.get("super", false))
	var fill: Color = tetro.get("color", Color(0.6, 0.7, 1.0))
	if assembling:
		fill.a = ASSEMBLING_ALPHA
	var border: Color = BORDER_COLOR_ASSEMBLING if assembling else BORDER_COLOR
	if is_super and not assembling:
		border = SUPER_BORDER_COLOR
	var border_width: float = 3.0 if is_super else 2.0
	var cell_vec := Vector2(cs, cs)
	for idx in range(visible):
		var rect := Rect2(origin + _as_vector2(cells[idx]) * cs, cell_vec)
		canvas.draw_rect(rect, fill)
		if not assembling:
			canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size - Vector2(4.0, 4.0)), INNER_HIGHLIGHT)
		canvas.draw_rect(rect, border, false, border_width)


func _draw_guard_block(canvas: CanvasItem, block: Dictionary, cell_size: float, shake_offset: Vector2) -> void:
	var cells: Array = block.get("cells", [])
	if cells.is_empty():
		return
	var origin: Vector2 = _as_vector2(block.get("origin", Vector2.ZERO)) + shake_offset
	var state: String = String(block.get("state", ""))
	var visible: int = mini(int(block.get("visible_cells", cells.size())), cells.size())
	var translucent: bool = state == "assembling" or state == "sliding"
	var fill: Color = block.get("color", Color(0.58, 0.66, 0.78))
	if translucent:
		fill.a = 0.6
	var cell_vec := Vector2(cell_size, cell_size)
	for idx in range(visible):
		var rect := Rect2(origin + _as_vector2(cells[idx]) * cell_size, cell_vec)
		canvas.draw_rect(rect, fill)
		if state == "active":
			canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size - Vector2(4.0, 4.0)), INNER_HIGHLIGHT)
		canvas.draw_rect(rect, BORDER_COLOR, false, 2.0)


func _draw_cube(canvas: CanvasItem, cube: Dictionary, shake_offset: Vector2) -> void:
	var center: Vector2 = _as_vector2(cube.get("center", Vector2.ZERO)) + shake_offset
	var radius: float = float(cube.get("radius", 90.0))
	var rebuild: bool = bool(cube.get("rebuild", false))
	var ring_alpha: float = 0.25 if rebuild else 0.5
	canvas.draw_arc(center, radius, 0.0, TAU, 48, Color(0.5, 0.7, 0.95, ring_alpha), 2.0, true)

	var spin: float = float(cube.get("spin", 0.0))
	var hit_progress: float = clampf(float(cube.get("hit_progress", 0.0)), 0.0, 1.0)
	var melt_progress: float = clampf(float(cube.get("melt_progress", 0.0)), 0.0, 1.0)
	var glow_radius: float = radius * (0.42 - 0.12 * melt_progress)
	canvas.draw_circle(center, glow_radius * 1.55, Color(0.35, 0.75, 1.0, 0.16 * (1.0 - melt_progress * 0.7)))
	canvas.draw_circle(center, glow_radius, Color(0.72, 0.90, 1.0, 0.16 * (1.0 - melt_progress * 0.7)))
	for face in _build_cube_projected_faces(center, radius, spin, hit_progress, melt_progress):
		var points: PackedVector2Array = face.get("points", PackedVector2Array())
		if Geometry2D.triangulate_polygon(points).is_empty():
			continue
		canvas.draw_colored_polygon(points, face.get("color", Color(0.5, 0.7, 1.0, 0.8)))
	_draw_cube_edges(canvas, center, radius, spin, melt_progress)

	if bool(cube.get("solve_pending", false)):
		var prog: float = float(cube.get("solve_progress", 0.0))
		canvas.draw_arc(center, radius + 4.0, 0.0, TAU, 48, Color(1.0, 0.9, 0.4, 0.3 + 0.5 * prog), 3.0, true)
	elif rebuild:
		var rp: float = float(cube.get("rebuild_progress", 0)) / maxf(1.0, float(cube.get("rebuild_needed", 5)))
		canvas.draw_arc(center, radius + 4.0, -PI * 0.5, -PI * 0.5 + TAU * rp, 48, Color(0.4, 0.9, 0.6, 0.7), 3.0, true)


func debug_build_cube_projected_faces(spin: float, radius: float = 90.0, hit_progress: float = 0.0, melt_progress: float = 0.0) -> Array:
	return _build_cube_projected_faces(Vector2.ZERO, radius, spin, hit_progress, melt_progress)


func _build_cube_projected_faces(center: Vector2, radius: float, spin: float, hit_progress: float, melt_progress: float) -> Array:
	var ang_y: float = spin * 0.55
	var ang_x: float = spin * 0.35
	var visual_size: float = _cube_visual_size(melt_progress)
	var vertices: Array = []
	for vertex in _cube_vertices():
		vertices.append(_rotate_cube_vector(vertex, ang_x, ang_y))
	var normals := _cube_normals()
	var faces: Array = []
	var face_index := 0
	for indices in _cube_faces():
		var points := PackedVector2Array()
		var depth := 0.0
		for index in indices:
			var rotated: Vector3 = vertices[int(index)]
			depth += rotated.z
			points.append(_project_cube_vertex(rotated, center, visual_size))
		depth /= maxf(1.0, float(indices.size()))
		var normal: Vector3 = _rotate_cube_vector(normals[face_index], ang_x, ang_y).normalized()
		faces.append({
			"points": points,
			"depth": depth,
			"color": _cube_face_color(normal, hit_progress, melt_progress),
		})
		face_index += 1
	faces.sort_custom(Callable(self, "_sort_cube_faces_far_first"))
	return faces


func _draw_cube_edges(canvas: CanvasItem, center: Vector2, radius: float, spin: float, melt_progress: float) -> void:
	var ang_y: float = spin * 0.55
	var ang_x: float = spin * 0.35
	var visual_size: float = _cube_visual_size(melt_progress)
	var projected: Array = []
	for vertex in _cube_vertices():
		projected.append(_project_cube_vertex(_rotate_cube_vector(vertex, ang_x, ang_y), center, visual_size))
	var fade: float = 1.0 - melt_progress * 0.85
	if fade <= 0.02:
		return
	var glow := CUBE_EDGE_GLOW
	glow.a = 0.44 * fade
	var main := CUBE_EDGE_MAIN
	main.a = 0.74 * fade
	var glow_width: float = 4.0 if radius >= 60.0 else 2.0
	var main_width: float = 2.0 if radius >= 60.0 else 1.0
	for edge in _cube_edges():
		var a: Vector2 = projected[int(edge[0])]
		var b: Vector2 = projected[int(edge[1])]
		canvas.draw_line(a, b, glow, glow_width, true)
		canvas.draw_line(a, b, main, main_width, true)


func _cube_face_color(normal: Vector3, hit_progress: float, melt_progress: float) -> Color:
	var base: Color = CUBE_FACE_BLUE.lerp(CUBE_FACE_RED, clampf(hit_progress, 0.0, 1.0))
	base = base.lerp(CUBE_FACE_PURPLE, clampf(melt_progress, 0.0, 1.0))
	var light: float = maxf(0.0, normal.dot(CUBE_LIGHT_DIR.normalized()))
	var shade: float = 0.35 + 0.65 * light
	return Color(base.r * shade, base.g * shade, base.b * shade, clampf(1.0 - melt_progress * 0.85, 0.0, 1.0))


func _cube_visual_size(melt_progress: float) -> float:
	var cube_size: float = CUBE_VISUAL_REFERENCE_MIN * CUBE_VISUAL_SIZE_RATIO
	var shrink: float = 1.0 - clampf(melt_progress, 0.0, 1.0) * 0.6
	return maxf(0.05, cube_size * CUBE_VISUAL_SCALE * shrink)


func _rotate_cube_vector(value: Vector3, ang_x: float, ang_y: float) -> Vector3:
	var cy: float = cos(ang_y)
	var sy: float = sin(ang_y)
	var x1: float = value.x * cy + value.z * sy
	var z1: float = -value.x * sy + value.z * cy
	var cx: float = cos(ang_x)
	var sx: float = sin(ang_x)
	var y2: float = value.y * cx - z1 * sx
	var z2: float = value.y * sx + z1 * cx
	return Vector3(x1, y2, z2)


func _project_cube_vertex(value: Vector3, center: Vector2, visual_size: float) -> Vector2:
	var zc: float = value.z + CUBE_CAMERA_DISTANCE
	var factor: float = CUBE_FOV / maxf(0.001, zc)
	return center + Vector2(value.x, value.y) * factor * (visual_size * 0.5)


func _sort_cube_faces_far_first(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("depth", 0.0)) > float(b.get("depth", 0.0))


func _cube_vertices() -> Array:
	return [
		Vector3(-1.0, -1.0, -1.0), Vector3(1.0, -1.0, -1.0), Vector3(1.0, 1.0, -1.0), Vector3(-1.0, 1.0, -1.0),
		Vector3(-1.0, -1.0, 1.0), Vector3(1.0, -1.0, 1.0), Vector3(1.0, 1.0, 1.0), Vector3(-1.0, 1.0, 1.0),
	]


func _cube_faces() -> Array:
	return [
		[0, 1, 2, 3],
		[4, 5, 6, 7],
		[0, 1, 5, 4],
		[3, 2, 6, 7],
		[1, 2, 6, 5],
		[0, 3, 7, 4],
	]


func _cube_normals() -> Array:
	return [
		Vector3(0.0, 0.0, -1.0),
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, -1.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		Vector3(-1.0, 0.0, 0.0),
	]


func _cube_edges() -> Array:
	return [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7],
	]


func _draw_wall_cell(canvas: CanvasItem, wall_cell: Dictionary, cell_vec: Vector2, shake_offset: Vector2) -> void:
	var rect := Rect2(_as_vector2(wall_cell.get("origin", Vector2.ZERO)) + shake_offset, cell_vec)
	var fill: Color = wall_cell.get("color", Color(0.6, 0.7, 1.0))
	fill.a *= clampf(float(wall_cell.get("alpha", 1.0)), 0.0, 1.0)
	if fill.a <= 0.0:
		return
	canvas.draw_rect(rect, fill)
	var highlight := INNER_HIGHLIGHT
	highlight.a *= fill.a
	var border := BORDER_COLOR
	border.a *= fill.a
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size - Vector2(4.0, 4.0)), highlight)
	canvas.draw_rect(rect, border, false, 2.0)


func _draw_debris(canvas: CanvasItem, debris: Dictionary, shake_offset: Vector2) -> void:
	var progress: float = clampf(float(debris.get("progress", 0.0)), 0.0, 1.0)
	var color: Color = debris.get("color", Color(1.0, 1.0, 1.0))
	color.a = (1.0 - progress) * 0.7
	if color.a <= 0.0:
		return
	var grow: float = progress * 6.0
	var grow_vec := Vector2(grow, grow)
	for r in debris.get("rects", []):
		var rect: Rect2 = r
		canvas.draw_rect(Rect2(rect.position - grow_vec + shake_offset, rect.size + grow_vec * 2.0), color)


func _draw_starpoint_drop(canvas: CanvasItem, drop: Dictionary, shake_offset: Vector2) -> void:
	var pos: Vector2 = _as_vector2(drop.get("pos", Vector2.ZERO)) + shake_offset
	var size: float = maxf(4.0, float(drop.get("size", 12.0)))
	var glow: float = clampf(float(drop.get("glow_intensity", 1.0)), 0.0, 1.4)
	var life: float = maxf(0.0, float(drop.get("life", 600.0)))
	var alpha: float = clampf(life / 60.0, 0.0, 1.0)
	var rotation: float = float(drop.get("rotation", 0.0))
	var core := Color(1.0, 0.94, 0.36, 0.92 * alpha)
	var rim := Color(1.0, 0.62, 0.12, 0.78 * alpha)
	canvas.draw_circle(pos, size * (1.35 + 0.15 * glow), Color(1.0, 0.78, 0.18, 0.13 * glow * alpha))
	canvas.draw_circle(pos, size * 0.44, core)
	for i in range(5):
		var angle: float = rotation + float(i) * TAU / 5.0
		var tip: Vector2 = pos + Vector2(cos(angle), sin(angle)) * size
		canvas.draw_line(pos, tip, rim, 2.2, true)
		canvas.draw_circle(tip, size * 0.16, core)


func _draw_crystal_shield(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var blocks: Array = context.get("stage6_tetriser_crystal_shield_blocks", [])
	if blocks.is_empty():
		return
	var center: Vector2 = _as_vector2(context.get("stage6_tetriser_crystal_shield_center", Vector2.ZERO)) + shake_offset
	var radius: float = float(context.get("stage6_tetriser_crystal_shield_radius", CRYSTAL_SHIELD_ORBIT_RADIUS_FALLBACK))
	var progress: float = clampf(float(context.get("stage6_tetriser_crystal_shield_progress", 0.0)), 0.0, 1.0)
	if bool(context.get("stage6_tetriser_crystal_shield_freeze_active", false)):
		canvas.draw_arc(center, radius + 14.0 + sin(progress * TAU) * 6.0, 0.0, TAU, 64, Color(0.55, 0.92, 1.0, 0.28), 3.0, true)
		canvas.draw_arc(center, radius - 10.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, Color(1.0, 0.86, 0.35, 0.64), 4.0, true)
	for value in blocks:
		if value is Dictionary:
			_draw_crystal_shield_block(canvas, value, shake_offset)


func _draw_crystal_shield_block(canvas: CanvasItem, block: Dictionary, shake_offset: Vector2) -> void:
	var alpha: float = clampf(float(block.get("alpha", 1.0)), 0.0, 1.0)
	if alpha <= 0.0:
		return
	var pos: Vector2 = _as_vector2(block.get("position", Vector2.ZERO)) + shake_offset
	var size: float = maxf(4.0, float(block.get("size", 16.0)))
	var color: Color = block.get("color", Color(0.55, 0.90, 1.0))
	var glow_rect := Rect2(pos - Vector2(size + 12.0, size + 12.0) * 0.5, Vector2(size + 12.0, size + 12.0))
	var block_rect := Rect2(pos - Vector2(size, size) * 0.5, Vector2(size, size))
	canvas.draw_rect(glow_rect, Color(color.r, color.g, color.b, 0.10 * alpha))
	canvas.draw_rect(block_rect, Color(color.r, color.g, color.b, 0.62 * alpha))
	canvas.draw_rect(Rect2(block_rect.position + Vector2(3.0, 3.0), block_rect.size - Vector2(6.0, 6.0)), Color(1.0, 1.0, 1.0, 0.16 * alpha))
	canvas.draw_rect(block_rect, Color(1.0, 1.0, 1.0, 0.46 * alpha), false, 2.0)


func get_imagegen_asset_status() -> Dictionary:
	return {}


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
