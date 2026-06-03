extends RefCounted

# Stage 6 테트리서 boss skill HUD renderer (SCAFFOLD).
#
# 기획: docs/stage6_tetriser_port_plan.md §3,§7
# 원본의 오른쪽 세로 게이지바 대신 달지식 보스 스킬 카드 HUD로 변환 예정:
# 보스 게이지(max 500) + 낙하 테트로 / 가드 블록 / 테트로 벽 / 초인테트리서 카드.
# 현재는 no-op.


func prewarm_assets() -> void:
	pass


func prewarm_assets_step() -> bool:
	return true


func reset() -> void:
	pass


func build_card_layout(_context: Dictionary) -> Dictionary:
	return {}


func draw(_canvas: CanvasItem, _context: Dictionary) -> void:
	pass


func get_asset_status() -> Dictionary:
	return {}
