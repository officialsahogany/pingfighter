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
	var tetrominoes: Array = context.get("stage6_tetriser_tetrominoes", [])
	if tetrominoes.is_empty():
		return
	var cell_size: float = float(context.get("stage6_tetriser_cell_size", 20.0))
	for tetro in tetrominoes:
		_draw_tetromino(canvas, tetro, cell_size, shake_offset)
	for debris in context.get("stage6_tetriser_debris", []):
		_draw_debris(canvas, debris, shake_offset)


func _draw_tetromino(canvas: CanvasItem, tetro: Dictionary, cell_size: float, shake_offset: Vector2) -> void:
	var cells: Array = tetro.get("cells", [])
	if cells.is_empty():
		return
	var origin: Vector2 = _as_vector2(tetro.get("origin", Vector2.ZERO)) + shake_offset
	var visible: int = mini(int(tetro.get("visible_cells", cells.size())), cells.size())
	var assembling: bool = String(tetro.get("state", "")) == "assembling"
	var fill: Color = tetro.get("color", Color(0.6, 0.7, 1.0))
	if assembling:
		fill.a = ASSEMBLING_ALPHA
	var border: Color = BORDER_COLOR_ASSEMBLING if assembling else BORDER_COLOR
	var cell_vec := Vector2(cell_size, cell_size)
	for idx in range(visible):
		var rect := Rect2(origin + _as_vector2(cells[idx]) * cell_size, cell_vec)
		canvas.draw_rect(rect, fill)
		if not assembling:
			canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), rect.size - Vector2(4.0, 4.0)), INNER_HIGHLIGHT)
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


func get_imagegen_asset_status() -> Dictionary:
	return {}


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
