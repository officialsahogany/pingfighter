extends RefCounted

# Stage 6 테트리서 pillar background (SCAFFOLD).
#
# 기획: docs/stage6_tetriser_port_plan.md §3,§6
# 청색 금속/테트리스 배경 + 중앙 큐브 배경 연출을 소유할 예정.
# 현재는 단색 청색 플레이스홀더 fill(스캐폴드 진입을 시각적으로 식별).
# draw 시그니처는 stage5 홍련 background와 동일하게 유지(라우터가 동일 호출).

const BG_COLOR := Color(0.07, 0.10, 0.18, 1.0)


func prewarm_assets() -> void:
	pass


func prewarm_assets_step() -> bool:
	return true


func reset() -> void:
	pass


func update(_delta: float, _context: Dictionary = {}, _deps: Dictionary = {}) -> void:
	pass


func draw(
	canvas: CanvasItem,
	view_size: Vector2,
	game_offset: Vector2,
	game_size: Vector2,
	_field_width: float,
	_perf_logger: Object = null,
	_quality_scale: float = 1.0
) -> bool:
	if canvas == null:
		return false
	var target_size := view_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = game_offset * 2.0 + game_size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = Vector2(760.0, 750.0)
	canvas.draw_rect(Rect2(Vector2.ZERO, target_size), BG_COLOR)
	return true


func draw_pillar_background_overlay(
	_canvas: CanvasItem,
	_view_size: Vector2,
	_game_offset: Vector2,
	_game_size: Vector2,
	_field_width: float,
	_perf_logger: Object = null,
	_quality_scale: float = 1.0
) -> void:
	pass
