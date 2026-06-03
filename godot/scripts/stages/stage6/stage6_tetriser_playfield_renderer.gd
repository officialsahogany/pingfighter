extends RefCounted

# Stage 6 테트리서 playfield renderer (SCAFFOLD).
#
# 기획: docs/stage6_tetriser_port_plan.md §3
# 테트로미노 블록 / 가드 블록 / 좌우 벽 / 파편 / EMP / 초인 광선 / 중앙 큐브
# 전투 VFX를 소유할 예정. 현재는 no-op(공/플레이어/보스는 actor renderer가 처리).


func prewarm_assets() -> void:
	pass


func prewarm_assets_step() -> bool:
	return true


func reset() -> void:
	pass


func clear_transient_canvas_items() -> void:
	pass


func draw(_canvas: CanvasItem, _context: Dictionary, _shake_offset: Vector2, _perf_logger: Object = null) -> void:
	# TODO(stage6): 테트로미노/가드/벽/중앙 큐브/광선/EMP/파편 draw.
	pass


func get_imagegen_asset_status() -> Dictionary:
	return {}
