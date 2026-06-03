extends RefCounted

# Stage 6 테트리서 boss actor renderer (SCAFFOLD).
#
# 기획: docs/stage6_tetriser_port_plan.md §3
# 실제 테트리서 보스 스프라이트(AutoSprite 시트)는 후속 단계에서 추가한다.
# 현재는 보스 패들 위치에 placeholder 사각형을 그려 스캐폴드 진입 시 보스를
# 보이게 한다(테트리서 청색 ≈ (120,170,255)).

const PLACEHOLDER_FILL := Color(0.47, 0.67, 1.0, 0.95)
const PLACEHOLDER_BORDER := Color(0.85, 0.93, 1.0, 1.0)


func prewarm_assets() -> void:
	pass


func prewarm_assets_step() -> bool:
	return true


func reset() -> void:
	pass


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	var rect := Rect2(boss_pos + shake_offset, boss_size)
	canvas.draw_rect(rect, PLACEHOLDER_FILL)
	canvas.draw_rect(rect, PLACEHOLDER_BORDER, false, 2.0)


func get_asset_status() -> Dictionary:
	return {}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
