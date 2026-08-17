extends SceneTree

const RuntimePerkChoiceLayout := preload("res://scripts/characters/runtime_perk_choice_layout.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkTraditionalChrome := preload("res://scripts/hud/runtime_perk_traditional_chrome.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_reference_layout()
	_verify_compact_layout()
	_verify_target_resolutions()
	_verify_status_talisman_geometry()
	_verify_card_readability_contract()
	_verify_card_medallion_clearance()
	_verify_status_badge_containment()
	_verify_status_badge_text_contract()
	_verify_visual_owner_contract()
	if _failures.is_empty():
		print("runtime_perk_traditional_choice_ui_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _verify_reference_layout() -> void:
	var helper := RuntimePerkChoiceLayout.new()
	var view_size := Vector2(1456.0, 1090.0)
	var layout: Dictionary = helper.build_layout(view_size, 4)
	var card_size: Vector2 = layout.get("card_size", Vector2.ZERO)
	var cards: Array = helper.get_card_rects(view_size, 4, 1.0)
	var panel: Rect2 = layout.get("panel_rect", Rect2())
	_expect(card_size.y > card_size.x, "reference choices should be tall parchment cards")
	_expect(cards.size() == 4, "reference layout should preserve all four choice hit targets")
	_expect(panel.position.y > (cards.back() as Rect2).end.y, "owned Mugong ledger should sit below the integrated cards")
	_expect(panel.end.y < view_size.y, "reference ledger should remain inside the viewport")
	for index: int in range(cards.size()):
		var card: Rect2 = cards[index]
		_expect(Rect2(Vector2.ZERO, view_size).encloses(card), "reference card %d should remain on screen" % index)
		_expect(helper.get_card_index_at(card.get_center(), view_size, 4, 1.0) == index, "redesign must preserve card %d click ownership" % index)


func _verify_compact_layout() -> void:
	var helper := RuntimePerkChoiceLayout.new()
	var view_size := Vector2(760.0, 750.0)
	for choice_count: int in [3, 4]:
		var layout: Dictionary = helper.build_layout(view_size, choice_count)
		var cards: Array = helper.get_card_rects(view_size, choice_count, 1.0)
		var panel: Rect2 = layout.get("panel_rect", Rect2())
		_expect(cards.size() == choice_count, "compact layout should preserve %d choice slots" % choice_count)
		_expect(panel.end.y < view_size.y, "compact %d-choice ledger should remain on screen" % choice_count)
		for card_value: Variant in cards:
			_expect(Rect2(Vector2.ZERO, view_size).encloses(card_value as Rect2), "compact choice card should remain on screen")


func _verify_target_resolutions() -> void:
	var helper := RuntimePerkChoiceLayout.new()
	for view_size: Vector2 in [
		Vector2(1280.0, 720.0),
		Vector2(1536.0, 1024.0),
		Vector2(1920.0, 1080.0),
		Vector2(2560.0, 1440.0),
	]:
		var layout: Dictionary = helper.build_layout(view_size, 4)
		var cards: Array = helper.get_card_rects(view_size, 4, 1.0)
		var panel: Rect2 = layout.get("panel_rect", Rect2())
		var hint: Vector2 = layout.get("hint_pos", Vector2.ZERO)
		_expect(cards.size() == 4, "%s should retain four candidate cards" % view_size)
		_expect(Rect2(Vector2.ZERO, view_size).encloses(panel), "%s should keep the current-Mugong ledger on screen" % view_size)
		_expect(hint.y < view_size.y - 8.0, "%s should keep the input hint on screen" % view_size)
		for card_value: Variant in cards:
			_expect(Rect2(Vector2.ZERO, view_size).encloses(card_value as Rect2), "%s should keep every candidate card on screen" % view_size)


func _verify_status_talisman_geometry() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var panel := Rect2(150.0, 720.0, 1156.0, 172.0)
	var counter: Rect2 = renderer._get_status_counter_rect(panel)
	_expect(panel.encloses(counter), "status counter board should remain inside the ledger")
	var previous := Rect2()
	for index: int in range(6):
		var slot: Rect2 = renderer._get_status_slot_rect(panel, index, 6)
		_expect(slot.size.y > slot.size.x, "owned Mugong cell %d should read as a vertical talisman board" % index)
		_expect(panel.encloses(slot), "owned Mugong cell %d should remain inside the ledger" % index)
		_expect(slot.end.x < counter.position.x, "owned Mugong cell %d should not overlap the status board" % index)
		if index > 0:
			_expect(slot.position.x > previous.end.x, "owned Mugong cells should keep an even positive gap")
		previous = slot


func _verify_card_readability_contract() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var rank_color: Color = renderer._level_color({"next_level": 1, "max_level": 5}, false, 1.0)
	var hanji: Color = RuntimePerkTraditionalChrome.HANJI_LIGHT
	var rank_luma: float = rank_color.r + rank_color.g + rank_color.b
	var hanji_luma: float = hanji.r + hanji.g + hanji.b
	_expect(hanji_luma - rank_luma > 1.15, "normal 1성 rank should have strong dark-ink contrast on hanji")
	_expect(RuntimePerkOverlayRenderer.CARD_ICON_DRAW_SCALE >= 1.02, "perk icon art should fill the medallion instead of leaving a broad empty ring")
	_expect(RuntimePerkOverlayRenderer.CARD_ICON_DRAW_SCALE <= 1.06, "perk icon art should retain a narrow reveal inside the circular rim")
	_expect(RuntimePerkTraditionalChrome.BACKDROP_DIM_ALPHA >= 0.60 and RuntimePerkTraditionalChrome.BACKDROP_DIM_ALPHA <= 0.70, "choice modal should darken 65 percent while retaining the live game background")
	_expect(RuntimePerkTraditionalChrome.BACKDROP_WASH_ALPHA <= 0.08, "traditional navy wash should remain translucent")
	_expect(RuntimePerkTraditionalChrome.CARD_PAPER_VARIANT_COUNT >= 4, "candidate cards should not repeat one identical paper surface")
	_expect(RuntimePerkTraditionalChrome.CARD_PAPER_TEXTURE_ALPHA >= 0.40 and RuntimePerkTraditionalChrome.CARD_PAPER_TEXTURE_ALPHA <= 0.52, "authored hanji fibres should remain visible without muddying body copy")
	_expect(RuntimePerkTraditionalChrome.PAPER_FIBER_ALPHA <= 0.07, "paper fibres should remain below body-text contrast")
	_expect(RuntimePerkTraditionalChrome.PAPER_LANDSCAPE_ALPHA <= 0.09, "lower ink landscapes should stay restrained")
	_expect(RuntimePerkTraditionalChrome.PAINTED_CARD_ORNAMENT_ALPHA <= 0.18, "painted card ornaments should remain behind body text")
	_expect(RuntimePerkTraditionalChrome.CARD_CORNER_ORNAMENT_SIZE >= 20.0, "perk cards should carry visible traditional ornaments at all four corners")
	_expect(RuntimePerkTraditionalChrome.CARD_CORNER_ORNAMENT_SIZE <= 26.0, "card corner ornaments should not crowd the icon or copy")
	_expect(FileAccess.file_exists(RuntimePerkOverlayRenderer.TRADITIONAL_ORNAMENT_ATLAS_PATH), "traditional perk cards should ship their dedicated painted ornament atlas")
	_expect(FileAccess.file_exists(RuntimePerkOverlayRenderer.TRADITIONAL_CARD_PAPER_TEXTURE_PATH), "traditional perk cards should ship their shared authored hanji surface")
	_expect(FileAccess.file_exists(RuntimePerkIconRenderer.PERK_ICON_PATHS.get("common_refresh", "")), "refresh should resolve to its traditional seal icon")
	_expect(FileAccess.file_exists(RuntimePerkIconRenderer.PERK_ICON_PATHS.get("convert_to_gold", "")), "gold conversion should resolve to its aged yeopjeon icon")
	_expect(str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get("common_refresh", "")).contains("traditional_v2"), "refresh should no longer use the neon legacy icon")
	_expect(str(RuntimePerkIconRenderer.PERK_SHEET_PATHS.get("common_refresh", "")).contains("traditional_v2"), "sheet-first refresh lookup should no longer revive the neon legacy sheet")
	_expect(str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get("convert_to_gold", "")).contains("traditional_v2"), "gold conversion should no longer use the glossy legacy coin")
	_expect(RuntimePerkTraditionalChrome.TITLE_PLAQUE_FILL_ALPHA <= 0.68, "title ink plaque should remain painterly instead of becoming an opaque UI bar")
	_expect(RuntimePerkTraditionalChrome.TITLE_RAIL_WIDTH_RATIO <= 0.72, "title rails should remain shorter than the ink heading")
	_expect(RuntimePerkOverlayRenderer.CARD_SELECTION_TRANSITION_MSEC >= 120.0 and RuntimePerkOverlayRenderer.CARD_SELECTION_TRANSITION_MSEC <= 200.0, "card focus transition should stay restrained and responsive")
	_expect(RuntimePerkOverlayRenderer.CARD_SELECTION_SCALE <= 0.04, "selected-card scale should remain subtle")


# 메달리온 바깥 링이 카드 상단 황동 테두리(종이면 위)를 파고들거나 아래 이름판에
# 물리면 안 된다. 판정은 실제 그리기가 쓰는 지오메트리 정본을 통과시킨다.
func _verify_card_medallion_clearance() -> void:
	var helper := RuntimePerkChoiceLayout.new()
	# 라이브 배율(1.32)·중간 배율·컴팩트 배율을 모두 덮는다. 카드 세로 여백은
	# layout_scale에 따라 달라지므로 한 해상도만 재면 다른 배율에서 다시 붙는다.
	for view_size: Vector2 in [
		Vector2(1920.0, 1080.0),
		Vector2(1456.0, 1090.0),
		Vector2(1280.0, 720.0),
		Vector2(760.0, 750.0),
	]:
		for choice_count: int in [3, 4]:
			var cards: Array = helper.get_card_rects(view_size, choice_count, 1.0)
			if cards.is_empty():
				_expect(false, "%s x%d should produce choice cards" % [view_size, choice_count])
				continue
			var card: Rect2 = cards[0]
			var geometry: Dictionary = RuntimePerkOverlayRenderer.get_card_medallion_geometry(card)
			var center: Vector2 = geometry.get("center", Vector2.ZERO)
			var outer: float = float(geometry.get("radius", 0.0)) + RuntimePerkOverlayRenderer.CARD_MEDALLION_RIM_PAD
			var paper_top: float = float(geometry.get("paper_top", 0.0))
			var nameplate_top: float = float(geometry.get("nameplate_top", 0.0))
			var label := "%s x%d" % [view_size, choice_count]
			_expect(
				center.y - outer >= paper_top + RuntimePerkOverlayRenderer.CARD_MEDALLION_TOP_CLEARANCE_MIN - 0.01,
				"%s medallion should keep visible breathing room below the card's top brass frame" % label
			)
			_expect(
				center.y + outer <= nameplate_top - RuntimePerkOverlayRenderer.CARD_MEDALLION_BOTTOM_CLEARANCE_MIN + 0.01,
				"%s medallion should not slide under the name plate" % label
			)
			_expect(
				center.y - outer > card.position.y,
				"%s medallion should stay inside the card rect" % label
			)
			var icon_size: float = float(geometry.get("icon_size", 0.0))
			_expect(
				icon_size * RuntimePerkOverlayRenderer.CARD_ICON_DRAW_SCALE >= card.size.x * 0.24,
				"%s medallion should stay large enough to read the perk art" % label
			)
			_expect(
				icon_size <= card.size.x * RuntimePerkOverlayRenderer.CARD_ICON_MEDALLION_WIDTH_RATIO + 0.01,
				"%s medallion should not exceed its horizontal budget" % label
			)


# "현재 무공" 성급 명패는 어두운 글자 / 금박 바탕이라, 글자가 명패 밖으로 1px만
# 나가도 어두운 셀 위에 얹혀 "하단이 잘렸다"로 읽힌다. 판정은 실제 그리기 경로가
# 쓰는 baseline 공식(`_draw_text_centered`)을 그대로 되짚어 잉크 상/하단을 낸다.
func _verify_status_badge_containment() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var font: Font = renderer._get_font()
	if font == null:
		_expect(false, "status badge containment needs a resolvable UI font")
		return
	var helper := RuntimePerkChoiceLayout.new()
	for view_size: Vector2 in [
		Vector2(1920.0, 1080.0),
		Vector2(1456.0, 1090.0),
		Vector2(1280.0, 720.0),
		Vector2(760.0, 750.0),
	]:
		var panel: Rect2 = helper.build_layout(view_size, 3).get("panel_rect", Rect2())
		# format_mugong_level이 실제로 낼 수 있는 폭 스펙트럼을 덮는다 -- 극성 오버플로
		# 문구가 가장 넓다.
		for badge_text: String in ["1성", "10성", "극성", "극성 +2"]:
			var slot: Rect2 = renderer._get_status_slot_rect(panel, 0, 6)
			var badge: Dictionary = renderer.get_status_badge_geometry(slot, badge_text)
			var rect: Rect2 = badge.get("rect", Rect2())
			var center: Vector2 = badge.get("text_center", Vector2.ZERO)
			var font_size: int = int(badge.get("font_size", 9))
			var measured: Vector2 = font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
			var baseline: float = center.y + measured.y * RuntimePerkOverlayRenderer.TEXT_CENTER_BASELINE_RATIO
			var ink_top: float = baseline - font.get_ascent(font_size)
			var ink_bottom: float = baseline + font.get_descent(font_size)
			var label := "%s \"%s\"" % [view_size, badge_text]
			_expect(
				ink_bottom <= rect.end.y + 0.01,
				"%s badge glyphs must not spill below the gold plate onto the dark cell" % label
			)
			_expect(
				ink_top >= rect.position.y - 0.01,
				"%s badge glyphs must not spill above the gold plate" % label
			)
			_expect(
				center.x - measured.x * 0.5 >= rect.position.x - 0.01
					and center.x + measured.x * 0.5 <= rect.end.x + 0.01,
				"%s badge glyphs must stay inside the plate horizontally" % label
			)
			_expect(slot.encloses(rect), "%s badge plate should stay inside its talisman cell" % label)
			_expect(
				rect.get_center().y > slot.get_center().y,
				"%s badge plate should stay anchored to the lower part of the cell" % label
			)


# "현재 무공" 명패 문구 계약. 합일 셀은 프레젠터가 내려 준 전용 등급 문구를 그대로
# 써야 하고(현지화 정본은 PerkFusionLocalization), 성장형은 경지, 단일 습득형과
# 슬롯 셀은 명패 없음이다.
func _verify_status_badge_text_contract() -> void:
	var renderer := RuntimePerkOverlayRenderer.new()
	var fusion_label: String = PerkFusionLocalization.text("level_fusion")
	_expect(fusion_label.strip_edges() != "", "fusion badge localization must resolve to a visible label")
	_expect(
		renderer.get_status_badge_text({
			"tree": "fusion",
			"max_level": 1,
			"level": 1,
			"_level_text": fusion_label,
		}) == fusion_label,
		"fused Mugong cells must label themselves 합일 instead of rendering a blank plate"
	)
	_expect(
		renderer.get_status_badge_text({"tree": "common", "max_level": 5, "level": 1})
			== LanguageSettings.format_mugong_level(1, 5),
		"growing perks should keep their 경지 badge"
	)
	_expect(
		renderer.get_status_badge_text({"tree": "common", "max_level": 5, "level": 5})
			== LanguageSettings.format_mugong_level(5, 5),
		"maxed perks should keep their 극성 badge"
	)
	# 단일 습득형의 범용 태그(고유 / 비급 / 절세무공)는 이 좁은 명패에 싣지 않는
	# 기존 결정 -- 합일 추가가 그 결정을 흘려 넘기지 않았는지 함께 잠근다.
	for plain: Dictionary in [
		{"tree": "common", "max_level": 1, "level": 1},
		{"tree": "common", "max_level": 1, "level": 1, "rarity": "mythic"},
		{"tree": "common", "max_level": 1, "level": 1, "character_restriction": "smasher"},
	]:
		_expect(
			renderer.get_status_badge_text(plain) == "",
			"single-acquire perks should stay badge-free in the compact status cell"
		)
	for cell_key: String in ["is_slot_cell", "_is_slot_cell"]:
		var cell: Dictionary = {"tree": "common", "max_level": 5, "level": 3}
		cell[cell_key] = true
		_expect(
			renderer.get_status_badge_text(cell) == "",
			"slot-occupancy cells should stay badge-free (%s)" % cell_key
		)
	_expect(
		renderer.get_status_badge_text({"tree": "fusion", "max_level": 1, "_level_text": ""}) == "",
		"a fusion cell without a resolved label should draw no plate rather than an empty one"
	)


func _verify_visual_owner_contract() -> void:
	var renderer_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	var chrome_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_traditional_chrome.gd")
	_expect(renderer_source.contains("RuntimePerkTraditionalChrome.draw_backdrop"), "standard choice path should use the lacquer/hanji backdrop owner")
	_expect(renderer_source.contains("RuntimePerkTraditionalChrome.draw_card_base"), "choice cards should use the parchment-card owner")
	_expect(renderer_source.contains("prewarm_traditional_choice_assets"), "painted perk ornaments should load before the first visible card draw")
	_expect(renderer_source.contains("RuntimePerkTraditionalChrome.draw_medallion_finish"), "choice icons should share one engraved medallion finish")
	_expect(renderer_source.contains("RuntimePerkTraditionalChrome.draw_talisman_slot"), "owned Mugong cells should use the talisman-slot owner")
	_expect(renderer_source.contains("RuntimePerkTraditionalChrome.draw_status_counter_board"), "dynamic counters should be grouped in the status ledger")
	_expect(renderer_source.contains("RuntimePerkTraditionalChrome.draw_hint_ribbon"), "input guidance should use the ink-cloud ribbon")
	_expect(renderer_source.contains("_sync_choice_visual_selection"), "keyboard and mouse focus should drive the visual lift transition")
	_expect(chrome_source.contains("_draw_paper_fibres"), "parchment cards should own a shared hanji-fibre layer")
	_expect(chrome_source.contains("_draw_paper_flecks"), "parchment cards should break up flat color with stable pulp flecks")
	_expect(chrome_source.contains("_draw_paper_patina"), "parchment cards should shade and wear their edges")
	_expect(chrome_source.contains("_draw_card_paper_texture"), "parchment cards should blend the prewarmed authored hanji surface")
	_expect(not chrome_source.contains("_draw_card_watermark"), "card surfaces should not reintroduce procedural circular watermarks")
	_expect(not chrome_source.contains("ORNAMENT_SEAL_CLOUD_CELL"), "card surfaces should not render the authored circular seal watermark")
	_expect(chrome_source.contains("_draw_lower_ink_landscape"), "parchment cards should fill lower whitespace with restrained ink scenery")
	_expect(chrome_source.contains("_draw_card_painted_ornament"), "choice cards should prefer authored ink-wash ornaments over procedural lines")
	_expect(chrome_source.contains("_draw_card_corner_ornaments"), "choice cards should render mirrored brass lattice ornaments at all four corners")
	_expect(chrome_source.contains("_draw_backdrop_painted_ornaments"), "the modal backdrop should share the authored ink-wash atlas")
	_expect(renderer_source.contains("◆ 현재 무공"), "status heading should use player-facing Mugong terminology")
	_expect(renderer_source.contains("무공 골드: %d"), "status currency should use player-facing Mugong terminology")
	_expect(not chrome_source.contains("load("), "the chrome draw path should not load the prewarmed ornament atlas")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
