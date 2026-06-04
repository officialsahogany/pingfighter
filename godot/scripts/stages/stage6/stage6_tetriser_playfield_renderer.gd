extends RefCounted

# Stage 6 테트리서 playfield renderer.
#
# 기획: docs/stage6_tetriser_port_plan.md §3
# 2단계(2a): 낙하/정착 테트로미노 블록을 그린다(데이터는 actor draw context의
#   `stage6_tetriser_tetrominoes`, stage6_tetriser_state.get_actor_draw_context()).
# 후속: 가드 블록/벽(3), 파편/EMP/광선/중앙 큐브(4) VFX.

const ASSEMBLING_ALPHA := 0.5
const BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.22)
const BORDER_COLOR_ASSEMBLING := Color(1.0, 1.0, 1.0, 0.12)
const INNER_HIGHLIGHT := Color(1.0, 1.0, 1.0, 0.14)
const SUPER_BORDER_COLOR := Color(1.0, 0.45, 0.18, 0.95)   # 초인 테트로 강조 테두리


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
	var sliding: bool = String(block.get("state", "")) == "sliding"
	var fill: Color = block.get("color", Color(0.58, 0.66, 0.78))
	if sliding:
		fill.a = 0.6
	var cell_vec := Vector2(cell_size, cell_size)
	for cell in cells:
		var rect := Rect2(origin + _as_vector2(cell) * cell_size, cell_vec)
		canvas.draw_rect(rect, fill)
		canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size - Vector2(4.0, 4.0)), INNER_HIGHLIGHT)
		canvas.draw_rect(rect, BORDER_COLOR, false, 2.0)


func _draw_cube(canvas: CanvasItem, cube: Dictionary, shake_offset: Vector2) -> void:
	var center: Vector2 = _as_vector2(cube.get("center", Vector2.ZERO)) + shake_offset
	var radius: float = float(cube.get("radius", 90.0))
	var rebuild: bool = bool(cube.get("rebuild", false))
	var ring_alpha: float = 0.25 if rebuild else 0.5
	canvas.draw_arc(center, radius, 0.0, TAU, 48, Color(0.5, 0.7, 0.95, ring_alpha), 2.0, true)

	var grid: Array = cube.get("grid", [])
	var n: int = int(cube.get("grid_size", 3))
	if n > 0 and grid.size() >= n * n:
		var side: float = radius * 1.25
		var cell: float = side / float(n)
		var top_left: Vector2 = center - Vector2(side, side) * 0.5
		var cell_alpha: float = 0.35 if rebuild else 1.0
		for r in range(n):
			for c in range(n):
				var col: Color = grid[r * n + c]
				col.a = cell_alpha
				var rect := Rect2(top_left + Vector2(float(c) * cell, float(r) * cell) + Vector2(1.0, 1.0), Vector2(cell - 2.0, cell - 2.0))
				canvas.draw_rect(rect, col)

	if bool(cube.get("solve_pending", false)):
		var prog: float = float(cube.get("solve_progress", 0.0))
		canvas.draw_arc(center, radius + 4.0, 0.0, TAU, 48, Color(1.0, 0.9, 0.4, 0.3 + 0.5 * prog), 3.0, true)
	elif rebuild:
		var rp: float = float(cube.get("rebuild_progress", 0)) / maxf(1.0, float(cube.get("rebuild_needed", 5)))
		canvas.draw_arc(center, radius + 4.0, -PI * 0.5, -PI * 0.5 + TAU * rp, 48, Color(0.4, 0.9, 0.6, 0.7), 3.0, true)


func _draw_wall_cell(canvas: CanvasItem, wall_cell: Dictionary, cell_vec: Vector2, shake_offset: Vector2) -> void:
	var rect := Rect2(_as_vector2(wall_cell.get("origin", Vector2.ZERO)) + shake_offset, cell_vec)
	var fill: Color = wall_cell.get("color", Color(0.6, 0.7, 1.0))
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size - Vector2(4.0, 4.0)), INNER_HIGHLIGHT)
	canvas.draw_rect(rect, BORDER_COLOR, false, 2.0)


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


func _draw_crystal_shield(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var blocks: Array = context.get("stage6_tetriser_crystal_shield_blocks", [])
	if blocks.is_empty():
		return
	var center: Vector2 = _as_vector2(context.get("stage6_tetriser_crystal_shield_center", Vector2.ZERO)) + shake_offset
	var radius: float = float(context.get("stage6_tetriser_crystal_shield_radius", 100.0))
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
