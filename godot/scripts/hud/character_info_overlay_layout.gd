extends RefCounted


static func update_frame_layout(target: Object, view_size: Vector2, current_view_size: Vector2, current_panel_rect: Rect2) -> void:
	if current_panel_rect.size != Vector2.ZERO and current_view_size.is_equal_approx(view_size):
		return
	target.set("_layout_view_size", view_size)
	# 기준 PNG(1264x964) 실측 기하: 패널 상단 22/하단 여백 13(비대칭 —
	# 하단 여백 우선 앵커), 폭 1214. 섹션 x=44(inner 19), content_top=+62.
	var panel_size := Vector2(min(1214.0, max(520.0, view_size.x - 50.0)), min(929.0, max(440.0, view_size.y - 35.0)))
	var panel_x: float = (view_size.x - panel_size.x) * 0.5
	var panel_y: float = clamp(view_size.y - 13.0 - panel_size.y, 8.0, 22.0)
	var panel_rect := Rect2(Vector2(panel_x, panel_y), panel_size)
	target.set("_layout_panel_rect", panel_rect)
	var inner_margin := 19.0
	var content_top := panel_rect.position.y + 62.0
	var content_bottom := panel_rect.end.y - 15.0
	var content_height: float = max(300.0, content_bottom - content_top)
	# Passive-item retirement redesign (mockup v2 2026-07-08): equipment slots,
	# the passive vault AND the active-item strip stay zero-hidden (presenter
	# draws, hover, drag, and prewarm all gate on nonzero rects; the top-right
	# trash can follows via should_show_trash drag-source gate). 권위는 사용자
	# 지정 기준 PNG(7/9 04:07 최종본) — 좌측 열은 스킬 히어로 카드 -> 퍽 행 ->
	# 플레이어 능력치(하단까지 확장), 우측 열은 링펫 풀하이트 + 하단 링펫
	# 능력치 박스. (이력: 7/10 리포트로 액티브 스트립이 일시 복귀했었으나
	# 이번 복원의 권위 결정으로 기준 PNG를 따른다 — 액티브 슬롯 노출은 전투
	# HUD 트레이가 소유.)
	var column_gap := 19.0
	var content_width: float = panel_rect.size.x - inner_margin * 2.0
	var lingpet_w: float = clamp(content_width * 0.30, 200.0, 380.0)
	var left_w: float = max(220.0, content_width - column_gap - lingpet_w)
	var left_x: float = panel_rect.position.x + inner_margin
	var left_rect := Rect2(left_x, content_top, left_w, content_height)
	target.set("_layout_inventory_rect", Rect2())
	target.set("_layout_equipment_rect", Rect2())
	target.set("_layout_active_items_rect", Rect2())
	# 분할 비율 = 기준 PNG 실측 역산(스킬 84..381/퍽 410..621/능력치 650..930).
	target.set("_layout_skill_rect", section_rect(left_rect, 0.0, 0.360))
	target.set("_layout_perk_rect", section_rect(left_rect, 0.383, 0.260))
	target.set("_layout_stats_rect", section_rect(left_rect, 0.664, 0.340))
	var lingpet_stats_h: float = clamp(content_height * 0.209, 110.0, 190.0)
	var lingpet_x: float = left_rect.end.x + column_gap
	target.set("_layout_lingpet_rect", Rect2(lingpet_x, content_top, lingpet_w, max(120.0, content_height - lingpet_stats_h - 12.0)))
	target.set("_layout_lingpet_stats_rect", Rect2(lingpet_x, content_bottom - lingpet_stats_h, lingpet_w, lingpet_stats_h))


static func section_rect(column_rect: Rect2, start_ratio: float, height_ratio: float) -> Rect2:
	var gap := 10.0
	var y: float = column_rect.position.y + column_rect.size.y * start_ratio
	var height: float = column_rect.size.y * height_ratio - gap
	return Rect2(column_rect.position.x, y, column_rect.size.x, max(64.0, height))
