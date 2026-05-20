extends RefCounted

const DEFAULT_BORDER_FLASH_DURATION_SEC := 0.22


func draw_border_flash(
	canvas: CanvasItem,
	width: float,
	height: float,
	shake_offset: Vector2,
	border_flash: Dictionary
) -> void:
	var timer: float = float(border_flash.get("timer", 0.0))
	if timer <= 0.0:
		return
	var duration: float = max(0.001, float(border_flash.get("duration", DEFAULT_BORDER_FLASH_DURATION_SEC)))
	var side: String = str(border_flash.get("side", ""))
	var impact_y: float = float(border_flash.get("y", 0.0))
	var ratio: float = clamp(timer / duration, 0.0, 1.0)
	var alpha: float = ratio * ratio * 0.50
	var color := Color(0.30, 1.0, 0.58, alpha)
	var soft_color := Color(0.0, 0.78, 0.64, alpha * 0.32)
	if side == "left":
		canvas.draw_rect(Rect2(shake_offset.x, shake_offset.y, 15.0, height), soft_color)
		canvas.draw_line(Vector2(10.0, 0.0) + shake_offset, Vector2(10.0, height) + shake_offset, color, 4.0)
	elif side == "right":
		canvas.draw_rect(Rect2(width - 15.0 + shake_offset.x, shake_offset.y, 15.0, height), soft_color)
		canvas.draw_line(Vector2(width - 10.0, 0.0) + shake_offset, Vector2(width - 10.0, height) + shake_offset, color, 4.0)
	elif side == "top":
		canvas.draw_rect(Rect2(shake_offset.x, shake_offset.y, width, 15.0), soft_color)
		canvas.draw_line(Vector2(0.0, 10.0) + shake_offset, Vector2(width, 10.0) + shake_offset, color, 4.0)
	elif side == "bottom":
		canvas.draw_rect(Rect2(shake_offset.x, height - 15.0 + shake_offset.y, width, 15.0), soft_color)
		canvas.draw_line(Vector2(0.0, height - 10.0) + shake_offset, Vector2(width, height - 10.0) + shake_offset, color, 4.0)
	if side in ["left", "right"]:
		var spark_y: float = clamp(impact_y, 12.0, height - 12.0)
		canvas.draw_circle(Vector2(10.0 if side == "left" else width - 10.0, spark_y) + shake_offset, 18.0 * ratio, Color(0.75, 1.0, 0.40, alpha * 0.85))


func draw_boss_rage_screen_tint(
	canvas: CanvasItem,
	width: float,
	height: float,
	shake_offset: Vector2,
	tint: float
) -> void:
	if tint <= 0.0:
		return
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.018)
	var alpha: float = (0.055 + pulse * 0.045) * clamp(tint, 0.0, 1.0)
	canvas.draw_rect(Rect2(shake_offset, Vector2(width, height)), Color(1.0, 0.02, 0.0, alpha))
	canvas.draw_rect(Rect2(shake_offset + Vector2(5.0, 5.0), Vector2(width - 10.0, height - 10.0)), Color(1.0, 0.16, 0.04, alpha * 1.8), false, 4.0)
