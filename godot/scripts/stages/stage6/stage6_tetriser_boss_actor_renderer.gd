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
	# 초인테트리서 발동 중 본체 스케일 업(중심 기준). super_scale은 state가 보간.
	var super_scale: float = maxf(1.0, float(context.get("stage6_tetriser_super_scale", 1.0)))
	var center: Vector2 = boss_pos + boss_size * 0.5 + shake_offset
	var draw_size: Vector2 = boss_size * super_scale
	var rect := Rect2(center - draw_size * 0.5, draw_size)
	var fill: Color = PLACEHOLDER_FILL
	var border: Color = PLACEHOLDER_BORDER
	if super_scale > 1.02:
		# 초인 오라(붉은 강조)로 변신 가시화.
		canvas.draw_rect(rect.grow(6.0), Color(1.0, 0.42, 0.16, 0.30))
		fill = fill.lerp(Color(1.0, 0.5, 0.3, 1.0), 0.35)
		border = Color(1.0, 0.6, 0.3, 1.0)
	canvas.draw_rect(rect, fill)
	canvas.draw_rect(rect, border, false, 2.0)


func get_asset_status() -> Dictionary:
	return {}


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
