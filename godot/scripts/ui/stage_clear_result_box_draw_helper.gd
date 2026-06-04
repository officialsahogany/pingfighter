extends RefCounted

const StageClearResultClickReactionState := preload("res://scripts/ui/stage_clear_result_click_reaction_state.gd")


static func draw_result_box_sheet_frame(
	canvas: CanvasItem,
	texture: Texture2D,
	draw_center: Vector2,
	frame_index: int,
	grid_cols: int,
	cell_size: Vector2,
	frame_draw_size: float,
	box_rotation: float,
	global_alpha: float
) -> bool:
	if canvas == null or texture == null:
		return false
	if grid_cols <= 0 or cell_size.x <= 0.0 or cell_size.y <= 0.0:
		return false
	if frame_draw_size <= 0.0 or global_alpha <= 0.001:
		return false
	var col: int = frame_index % grid_cols
	@warning_ignore("integer_division")
	var row: int = int(frame_index / grid_cols)
	var half_size: float = frame_draw_size * 0.5
	var source_rect := Rect2(
		Vector2(float(col) * cell_size.x, float(row) * cell_size.y),
		cell_size
	)
	canvas.draw_set_transform(draw_center, box_rotation, Vector2.ONE)
	canvas.draw_texture_rect_region(
		texture,
		Rect2(Vector2(-half_size, -half_size), Vector2(frame_draw_size, frame_draw_size)),
		source_rect,
		Color(1.0, 1.0, 1.0, global_alpha),
		false,
		true
	)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


static func draw_result_box_fallback(
	canvas: CanvasItem,
	draw_center: Vector2,
	half_x: float,
	half_y: float,
	box_rotation: float,
	draw_scale: float,
	is_mythic: bool,
	global_alpha: float,
	state: String,
	open_progress: float
) -> void:
	if canvas == null:
		return
	var base_color := Color(0.90, 0.44, 1.0, global_alpha) if is_mythic else Color(0.32, 0.82, 1.0, global_alpha)
	var body_fill := Color(base_color.r * 0.45, base_color.g * 0.45, base_color.b * 0.55, 0.78 * global_alpha)
	var lid_fill := Color(base_color.r, base_color.g, base_color.b, 0.66 * global_alpha)
	var rim_color := Color(1.0, 0.90, 0.45, 0.92 * global_alpha) if is_mythic else Color(0.75, 1.0, 1.0, 0.86 * global_alpha)
	var open_lift: float = 0.0
	if state == "opening" or state == "opened":
		open_lift = StageClearResultClickReactionState.smooth01(open_progress) * half_y * 0.42
	canvas.draw_set_transform(draw_center, box_rotation, Vector2.ONE)
	var body_rect := Rect2(Vector2(-half_x * 0.68, -half_y * 0.05), Vector2(half_x * 1.36, half_y * 1.02))
	var lid_rect := Rect2(Vector2(-half_x * 0.76, -half_y * 0.58 - open_lift), Vector2(half_x * 1.52, half_y * 0.46))
	canvas.draw_rect(body_rect, body_fill)
	canvas.draw_rect(body_rect, rim_color, false, max(1.5, 2.3 * draw_scale))
	canvas.draw_rect(lid_rect, lid_fill)
	canvas.draw_rect(lid_rect, rim_color, false, max(1.5, 2.2 * draw_scale))
	canvas.draw_line(
		Vector2(-half_x * 0.56, body_rect.position.y + body_rect.size.y * 0.35),
		Vector2(half_x * 0.56, body_rect.position.y + body_rect.size.y * 0.35),
		Color(1.0, 1.0, 1.0, 0.18 * global_alpha),
		max(1.0, 1.5 * draw_scale)
	)
	canvas.draw_circle(Vector2.ZERO, max(3.0, 6.0 * draw_scale), rim_color)
	canvas.draw_circle(Vector2.ZERO, max(1.4, 2.8 * draw_scale), Color(1.0, 1.0, 1.0, 0.78 * global_alpha))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
