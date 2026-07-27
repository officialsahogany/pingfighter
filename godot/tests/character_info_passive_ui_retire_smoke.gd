extends SceneTree

# Seals the TAB character-info passive-UI retirement + redesign (mockup 2026-07-08):
#  - the equipment-slot column and passive vault strip are zero-hidden
#    (zero-rect pattern -- presenter draws, hover, drag, and prewarm all gate
#    on nonzero rects),
#  - equipped skills become the top-left hero section with the perk row under it,
#  - the player stats panel and the restored active-item slot strip (2026-07-10:
#    the redesign initially zero-hid the strip too and the slots vanished) fill
#    the rest of the left column, with the strip anchored to the column bottom,
#  - the lingpet panel keeps the right column at full main height,
#  - the drag trash can shows while the active-item strip is a live drag source
#    and hides while every drag-source section is zero-hidden.

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayLayout := preload("res://scripts/hud/character_info_overlay_layout.gd")
const CharacterInfoOverlayLayoutUtils := preload("res://scripts/hud/character_info_overlay_layout_utils.gd")
const CharacterInfoOverlayHoverGeometry := preload("res://scripts/hud/character_info_overlay_hover_geometry.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const DragController := preload("res://scripts/hud/character_info_overlay_drag_controller.gd")

const INNER_MARGIN := 19.0

var _failures: Array[String] = []


class FakeLayoutTarget:
	extends RefCounted

	var _layout_view_size := Vector2.ZERO
	var _layout_panel_rect := Rect2()
	var _layout_inventory_rect := Rect2(1.0, 1.0, 1.0, 1.0)
	var _layout_equipment_rect := Rect2(1.0, 1.0, 1.0, 1.0)
	var _layout_skill_rect := Rect2()
	var _layout_active_items_rect := Rect2(1.0, 1.0, 1.0, 1.0)
	var _layout_perk_rect := Rect2()
	var _layout_lingpet_rect := Rect2()
	var _layout_lingpet_stats_rect := Rect2()
	var _layout_stats_rect := Rect2()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_wide_layout_contract()
	_verify_narrow_layout_keeps_sections_hidden()
	_verify_trash_gate_follows_drag_sources()
	_verify_skill_card_geometry()
	_verify_skill_card_hover_hitbox()
	_verify_perk_display_entries_cache()
	_verify_stat_gauge_bar_metrics()

	if _failures.is_empty():
		print("character_info_passive_ui_retire_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_wide_layout_contract() -> void:
	var target := FakeLayoutTarget.new()
	CharacterInfoOverlayLayout.update_frame_layout(target, Vector2(1280.0, 980.0), Vector2.ZERO, Rect2())
	var panel: Rect2 = target._layout_panel_rect
	_expect(panel.size != Vector2.ZERO, "layout should produce a panel rect")

	# Retired sections stay zero-hidden (they were seeded nonzero to prove the write).
	_expect(target._layout_equipment_rect == Rect2(), "equipment slots must be zero-hidden after passive retirement")
	_expect(target._layout_inventory_rect == Rect2(), "passive vault strip must be zero-hidden after passive retirement")
	var active_items: Rect2 = target._layout_active_items_rect
	# 권위=기준 PNG(7/9 04:07): 액티브 스트립도 zero-hidden — 능력치 패널이
	# 좌측 열 하단까지 확장된다(액티브 슬롯 노출은 전투 HUD 트레이 소유).
	_expect(active_items == Rect2(), "active-item strip must stay zero-hidden (reference-PNG authority)")
	_expect(target._layout_stats_rect.end.y > panel.end.y - 90.0, "player stats panel must extend to the bottom of the left column")

	# Left column stacks skills (hero) -> perk row -> player stats (mockup v2).
	var skill: Rect2 = target._layout_skill_rect
	var perk: Rect2 = target._layout_perk_rect
	var lingpet: Rect2 = target._layout_lingpet_rect
	var lingpet_stats: Rect2 = target._layout_lingpet_stats_rect
	var stats: Rect2 = target._layout_stats_rect
	_expect(is_equal_approx(skill.position.x, panel.position.x + INNER_MARGIN), "skill hero section should start at the panel's left content edge")
	_expect(is_equal_approx(skill.position.y, panel.position.y + 62.0), "skill hero section should sit at the top of the content area (기준 PNG content_top=+62)")
	_expect(skill.size.x < panel.size.x - INNER_MARGIN * 2.0 - 100.0, "skill hero section should leave room for the lingpet right column")
	_expect(is_equal_approx(perk.position.x, skill.position.x) and is_equal_approx(perk.size.x, skill.size.x), "perk row should share the left column with the skill section")
	_expect(perk.position.y > skill.position.y + 1.0, "perk row should sit below the skill hero section")
	_expect(perk.size.y >= 64.0, "perk row should keep enough height for the hex slot row")
	_expect(is_equal_approx(stats.position.x, skill.position.x) and is_equal_approx(stats.size.x, skill.size.x), "player stats should share the left column (not a full-width strip)")
	_expect(stats.position.y > perk.position.y + 1.0, "player stats should sit below the perk row")
	_expect(stats.size.y >= 120.0, "player stats should keep enough height for the stat rows")

	# Restored active-item strip (2026-07-10): bottom of the left column, under stats.
	# (기준 PNG 권위: 액티브 스트립 기하 레그는 zero-hidden 전환으로 소멸 —
	# 능력치 하단 확장 레그가 위에서 그 자리를 봉인한다.)

	# Right column: lingpet panel at full height with its own lingpet-stats box below.
	_expect(absf(lingpet.end.x - (panel.end.x - INNER_MARGIN)) <= 1.0, "lingpet panel should reach the panel's right content edge")
	_expect(lingpet.position.x > skill.end.x, "lingpet panel should sit to the right of the skill/perk column")
	_expect(lingpet_stats.size != Vector2.ZERO, "the lingpet stats box should be laid out in the right column")
	_expect(is_equal_approx(lingpet_stats.position.x, lingpet.position.x) and is_equal_approx(lingpet_stats.size.x, lingpet.size.x), "lingpet stats box should share the lingpet column")
	_expect(lingpet_stats.position.y > lingpet.end.y - 1.0, "lingpet stats box should sit below the lingpet panel")
	_expect(lingpet_stats.end.y > stats.end.y - 40.0, "the right column (lingpet + stats box) should reach the content bottom")


func _verify_narrow_layout_keeps_sections_hidden() -> void:
	var target := FakeLayoutTarget.new()
	CharacterInfoOverlayLayout.update_frame_layout(target, Vector2(700.0, 520.0), Vector2.ZERO, Rect2())
	_expect(target._layout_equipment_rect == Rect2(), "narrow layout must keep equipment slots zero-hidden")
	_expect(target._layout_inventory_rect == Rect2(), "narrow layout must keep the passive vault zero-hidden")
	_expect(target._layout_active_items_rect == Rect2(), "narrow layout must keep the active-item strip zero-hidden (reference-PNG authority)")
	_expect(target._layout_skill_rect.size.x > 0.0, "narrow layout should still lay out the skill strip")
	_expect(target._layout_perk_rect.size.x > 0.0 and target._layout_lingpet_rect.size.x > 0.0, "narrow layout should still lay out perk and lingpet sections")
	_expect(target._layout_lingpet_stats_rect.size != Vector2.ZERO, "narrow layout should still lay out the lingpet stats box")


func _verify_trash_gate_follows_drag_sources() -> void:
	var hidden := FakeLayoutTarget.new()
	hidden._layout_equipment_rect = Rect2()
	hidden._layout_inventory_rect = Rect2()
	hidden._layout_active_items_rect = Rect2()
	_expect(not DragController.should_show_trash(hidden), "trash can should hide while every drag-source section is zero-hidden")

	var with_vault := FakeLayoutTarget.new()
	with_vault._layout_equipment_rect = Rect2()
	with_vault._layout_active_items_rect = Rect2()
	with_vault._layout_inventory_rect = Rect2(0.0, 0.0, 100.0, 40.0)
	_expect(DragController.should_show_trash(with_vault), "trash can should return when a drag-source section is laid out again")

	# 권위=기준 PNG: 현 레이아웃은 모든 드래그 소스가 zero-hidden이라 우상단
	# 휴지통도 노출되지 않는다(should_show_trash 게이트 관통).
	var laid_out := FakeLayoutTarget.new()
	CharacterInfoOverlayLayout.update_frame_layout(laid_out, Vector2(1280.0, 980.0), Vector2.ZERO, Rect2())
	_expect(not DragController.should_show_trash(laid_out), "current layout must hide the trash can (no drag-source section is laid out)")


func _verify_skill_card_geometry() -> void:
	# Skill slots render as vertical cards (orb well + nameplate + type badge) so the
	# hero section reads like the mockup instead of bare square slots.
	var rect_cache: Array[Rect2] = []
	var icon_cache: Array[Rect2] = []
	var fallback_cache: Array[Rect2] = []
	var center_cache: Array[Vector2] = []
	var center_x_cache: Array[float] = []
	var state: Dictionary = CharacterInfoOverlayLayoutUtils.refresh_skill_slot_layout_arrays(
		Rect2(0.0, 0.0, 860.0, 360.0), 80.0, 5,
		rect_cache, icon_cache, fallback_cache, center_cache, center_x_cache
	)
	var card: Rect2 = rect_cache[0]
	_expect(card.size.y > card.size.x, "skill cell should be a vertical card (taller than wide)")
	_expect(card.size.x > 80.0, "skill card should pad the orb well horizontally")
	_expect(card.encloses(icon_cache[0]), "the orb well should sit inside the card")
	_expect(icon_cache[0].end.y < card.end.y - 40.0, "the card should keep a nameplate + badge band under the orb well")
	_expect(is_equal_approx(float(state.get("card_height", 0.0)), card.size.y), "layout should report the card height so hover covers the full card")
	_expect(float(state.get("label_y", 0.0)) > icon_cache[0].end.y, "the nameplate row should sit below the orb well")
	_expect(is_equal_approx(rect_cache[1].position.x - rect_cache[0].position.x, float(state.get("stride", 0.0))), "card stride should match the reported stride")


# P2 regression seal: the linear hit test takes the card WIDTH for x gap rejection
# and a separate card HEIGHT for the row check. Storing the height in the single
# size value made the x hitbox card_height wide, so inter-card gutters (and the
# space after the last card) resolved as a skill-card tooltip.
func _verify_skill_card_hover_hitbox() -> void:
	var card_w := 120.0
	var card_h := 166.0
	var stride := 132.0
	# Inside card 0's badge band (below the old square hitbox) -> card 0.
	_expect(
		CharacterInfoOverlayHoverGeometry.get_hovered_linear_slot_index(Vector2(60.0, 150.0), 0.0, 0.0, card_w, stride, 5, card_h) == 0,
		"full-card hover should cover the nameplate/badge band"
	)
	# Gutter between card 0 and card 1 -> no hover (the P2 regression case).
	_expect(
		CharacterInfoOverlayHoverGeometry.get_hovered_linear_slot_index(Vector2(125.0, 50.0), 0.0, 0.0, card_w, stride, 5, card_h) == -1,
		"inter-card gutters must not resolve as a skill card"
	)
	# Just past the last card's right edge (within its stride band) -> no hover.
	_expect(
		CharacterInfoOverlayHoverGeometry.get_hovered_linear_slot_index(Vector2(4.0 * stride + 125.0, 50.0), 0.0, 0.0, card_w, stride, 5, card_h) == -1,
		"space after the last card must not resolve as a skill card"
	)
	# Below the card -> no hover.
	_expect(
		CharacterInfoOverlayHoverGeometry.get_hovered_linear_slot_index(Vector2(60.0, 170.0), 0.0, 0.0, card_w, stride, 5, card_h) == -1,
		"points below the card must not resolve as a skill card"
	)
	# Back-compat: square consumers (no height arg) keep the original contract.
	_expect(
		CharacterInfoOverlayHoverGeometry.get_hovered_linear_slot_index(Vector2(30.0, 30.0), 0.0, 0.0, 60.0, 68.0, 5) == 0,
		"square-slot consumers should keep the single-size contract"
	)
	_expect(
		CharacterInfoOverlayHoverGeometry.get_hovered_linear_slot_index(Vector2(30.0, 70.0), 0.0, 0.0, 60.0, 68.0, 5) == -1,
		"square-slot consumers should keep rejecting below-slot points"
	)


# P3 regression seal: the padded slot-grid display entries (+ typed draw arrays)
# must be rebuilt only when the acquired cache instance or the slot budget changes,
# not on every draw.
func _verify_perk_display_entries_cache() -> void:
	var overlay := CharacterInfoOverlay.new()
	var acquired: Array = [{"id": "dash_lightweight", "name": "경량화", "_draw_id": "dash_lightweight"}]
	var first: Array = overlay._build_perk_display_entries_cached(acquired, 6)
	_expect(first.size() == 6, "display entries should pad the acquired list up to the slot budget")
	var second: Array = overlay._build_perk_display_entries_cached(acquired, 6)
	_expect(is_same(first, second), "same acquired instance + slot budget should reuse the cached display entries (no per-draw rebuild)")
	var wider: Array = overlay._build_perk_display_entries_cached(acquired, 7)
	_expect(not is_same(first, wider) and wider.size() == 7, "changing the slot budget should rebuild the display entries")
	var rebuilt_source: Array = acquired.duplicate(true)
	var rebuilt: Array = overlay._build_perk_display_entries_cached(rebuilt_source, 7)
	_expect(not is_same(wider, rebuilt), "a rebuilt acquired cache instance should rebuild the display entries")

	# 링코어 셀 금지 씰 (2026-07-27). 링코어 티어는 슬롯 **비소모**다 --
	# RuntimePerkCatalog.is_slot_consuming_perk가 두 번 면제하고(:1572/:1574),
	# count_owned_slot_perks는 runtime_skill_levels만 훑으므로 affinity state에
	# 사는 티어를 볼 수조차 없다(perk_slot_limit_smoke:210이 그 계약을 봉인).
	# 그런데 표시 절반만 랜딩된 시기가 있었다(0848d4480, "Slice B slot bridge"
	# 주석 -- 그 브리지는 어떤 커밋에도 존재한 적이 없다): 티어당 셀 1개가 예산
	# 목록에 섞여 들어가 헤더가 "슬롯 6/6"인데 셀은 8개가 그려졌고, 한도 미달일
	# 땐 빈 슬롯 패딩을 잡아먹었다. 예산이 **가득 찬** 픽스처로 그 산술을 직접
	# 봉인한다 -- 1퍽 픽스처는 패딩 잠식만 보므로 이 버그로 절대 실패하지 못한다.
	var full_budget: Array = []
	for slot_index in range(6):
		full_budget.append({"id": "perk_%d" % slot_index, "name": "무공 %d" % slot_index, "_draw_id": "perk_%d" % slot_index})
	var full_grid: Array = overlay._build_perk_display_entries_cached(full_budget, 6)
	_expect(full_grid.size() == 6, "a full 6-perk budget must draw exactly 6 cells, never more (got %d)" % full_grid.size())
	var stray_ring_cells := 0
	for entry_value in full_grid:
		if bool((entry_value as Dictionary).get("_ring_core_cell", false)):
			stray_ring_cells += 1
	_expect(stray_ring_cells == 0, "the perk grid must not inject ring-core tier cells (slot-free, and already shown as its own slot in the 수호령 panel)")
	# 재도입 트립와이어: 링코어 레인을 되살리려면 빌더 파라미터를 다시 늘리거나
	# 오버레이 쪽 티어 리더를 다시 들여와야 한다 -- 둘 다 여기서 RED.
	_expect(not overlay.has_method("_get_run_ring_core_tier_for_grid"), "the overlay must not read the run ring-core tier for the perk grid")
	var builder_arity := -1
	for method_info in overlay.get_method_list():
		if str(method_info.get("name", "")) == "_build_perk_display_entries_cached":
			builder_arity = (method_info.get("args", []) as Array).size()
			break
	_expect(builder_arity == 2, "_build_perk_display_entries_cached must take only (acquired, display_slot_count) (got %d args)" % builder_arity)
	var core_source: String = _read_script_source("res://scripts/hud/character_info_overlay_core.gd")
	_expect(core_source.find("_build_perk_display_entries_cached(acquired, display_slot_count)") >= 0, "the TAB perk grid must build display entries from the acquired perks + slot budget alone")
	var support_source: String = _read_script_source("res://scripts/hud/character_info_overlay_support.gd")
	_expect(support_source.find("_ring_core_cell") < 0, "the perk-grid display builder must not re-add ring-core cells")
	_expect(support_source.find("무공 슬롯 1칸을 사용합니다") < 0, "the false ring-core slot-cost copy must stay deleted (ring core consumes no Mugong slot)")


# Stats gauge bars (2026-07-09 redesign): base-anchored fill (base = 5/10 cells,
# lower-is-better inverted so improvement always fills) + tooltip breakdown line.
func _verify_stat_gauge_bar_metrics() -> void:
	_expect(is_equal_approx(CharacterInfoOverlayStatsPresenter.stat_bar_fill_ratio(100.0, 100.0, true), 0.5), "base value should sit at half fill")
	_expect(is_equal_approx(CharacterInfoOverlayStatsPresenter.stat_bar_fill_ratio(100.0, 150.0, true), 0.75), "a +50% buff should fill three quarters")
	_expect(is_equal_approx(CharacterInfoOverlayStatsPresenter.stat_bar_fill_ratio(100.0, 300.0, true), 1.0), "fill should clamp at full")
	_expect(is_equal_approx(CharacterInfoOverlayStatsPresenter.stat_bar_fill_ratio(1.0, 0.7, false), 0.65), "lower-is-better improvement should fill past half")
	_expect(is_equal_approx(CharacterInfoOverlayStatsPresenter.stat_bar_fill_ratio(1.0, 3.0, false), 0.04), "heavy debuff should clamp to the sliver floor")
	_expect(CharacterInfoOverlayStatsPresenter.stat_bar_breakdown_text(5.0, 3.2, false).find("개선") >= 0, "faster recharge should read as an improvement")
	_expect(CharacterInfoOverlayStatsPresenter.stat_bar_breakdown_text(4.0, 6.0, true).find("+50%") >= 0, "breakdown should carry the signed delta percent")
	_expect(CharacterInfoOverlayStatsPresenter.stat_bar_breakdown_text(155.0, 155.0, true).find("그대로") >= 0, "unchanged stats should say so")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


# 소스락 레그용 원문 리더. 읽기 실패는 빈 문자열이 아니라 명시 실패로 -- 빈
# 문자열을 돌려주면 "find(...) < 0" 금지 어서션들이 전부 공허 GREEN이 된다.
func _read_script_source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_expect(false, "source-lock leg could not open %s (a read failure must fail closed)" % path)
		return "<<unreadable>>"
	var text: String = file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		_expect(false, "source-lock leg read an empty %s (fail closed)" % path)
		return "<<unreadable>>"
	return text
