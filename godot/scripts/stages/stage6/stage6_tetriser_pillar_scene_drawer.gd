extends RefCounted

# Stage 6 테트리서 pillar scene drawer (SCAFFOLD).
#
# 기획: docs/stage6_tetriser_port_plan.md §3,§7
# 필러 장식 + 보스 스킬 카드 HUD 호출을 소유할 예정. 현재는 no-op.
# 시그니처는 stage5 홍련 pillar scene drawer와 동일하게 유지.


func prewarm_assets(_module_getter: Callable, _selected_character_type: String = "smasher") -> void:
	pass


func prewarm_assets_step(_module_getter: Callable, _selected_character_type: String = "smasher") -> bool:
	return true


func draw(_canvas: CanvasItem, _context: Dictionary, _registry: Object, _states: Dictionary) -> void:
	pass


func draw_pillar_hud_overlay(_canvas: CanvasItem, _context: Dictionary, _registry: Object, _states: Dictionary) -> void:
	pass


func draw_pillar_background_overlay(_canvas: CanvasItem, _context: Dictionary, _registry: Object, _states: Dictionary) -> void:
	pass


func draw_post_playfield_hud(_canvas: CanvasItem, _context: Dictionary, _registry: Object) -> void:
	pass


func get_asset_status() -> Dictionary:
	return {}
