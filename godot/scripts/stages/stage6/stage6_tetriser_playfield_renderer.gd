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
	for tetro in context.get("stage6_tetriser_tetrominoes", []):
		_draw_tetromino(canvas, tetro, cell_size, shake_offset)
	for guard in context.get("stage6_tetriser_guard_blocks", []):
		_draw_guard_block(canvas, guard, cell_size, shake_offset)
	var cell_vec := Vector2(cell_size, cell_size)
	for wall_cell in context.get("stage6_tetriser_wall_cells", []):
		_draw_wall_cell(canvas, wall_cell, cell_vec, shake_offset)
	for debris in context.get("stage6_tetriser_debris", []):
		_draw_debris(canvas, debris, shake_offset)


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


func get_imagegen_asset_status() -> Dictionary:
	return {}


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
