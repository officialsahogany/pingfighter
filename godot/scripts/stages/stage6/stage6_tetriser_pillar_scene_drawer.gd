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


func draw_post_playfield_hud(canvas: CanvasItem, context: Dictionary, registry: Object) -> void:
	if canvas == null or registry == null:
		return
	var renderer: Object = registry.get_instance("stage6_tetriser_boss_skill_hud_renderer")
	if renderer == null or not renderer.has_method("draw"):
		return
	var state: Object = registry.get_instance("stage6_tetriser_state")
	if state == null or not state.has_method("get_hud_context"):
		return
	var hud_context: Dictionary = context.duplicate(true)
	hud_context.merge(state.get_hud_context(null, context), true)
	renderer.draw(canvas, hud_context)


func get_asset_status() -> Dictionary:
	return {}
