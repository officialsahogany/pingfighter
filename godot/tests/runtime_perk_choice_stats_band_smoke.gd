extends SceneTree

# 퍽 선택 화면 하단 능력치 원장(2026-08-06 요청) 봉인.
#
# 요구: "캐릭터정보창 능력치 항목들을 그대로 밑에 보여줘 -- 어디가 부족한지 보고
# 수련/무공을 고를 수 있게". 부수 조건: 퍽 카드가 너무 커서 줄이되 설명/폰트
# 크기는 그대로.
#
# 봉인 항목
#  1) 레이아웃이 능력치 띠를 그룹 높이에 포함한다 -- card_y가 group_top에서
#     파생되므로, 띠를 빼먹으면 그리는 좌표와 카드 클릭 히트테스트가 어긋난다.
#  2) 띠 높이가 10행 전부를 담는다. draw_cached_player_stat_rows는 rect를 넘는
#     행을 조용히 버리므로(Stats-Panel Row Budget Trap) 실제 드로우가 append한
#     행 rect 개수를 센다 -- 계약 문구가 아니라 결과로 판정한다.
#  3) 세로 예산이 모자라면 띠를 잘라서 그리는 대신 통째로 끄고 기존 레이아웃으로
#     되돌린다.
#  4) 카드 폭(=이름/성급/설명 폰트 크기의 유일한 파생원)은 그대로, 높이만 줄었다.
#  5) 제목 현판 중심이 하한 아래로 내려가지 않는다(현판 상단 잘림 방지).
#  6) runtime_perk_state가 update()의 owner/registry로 띠 플래그를 갱신한다.
#  7) 원장 크롬의 안쪽 여백이 레이아웃이 가정한 값과 일치한다.

const RuntimePerkChoiceLayout := preload("res://scripts/characters/runtime_perk_choice_layout.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkTraditionalChrome := preload("res://scripts/hud/runtime_perk_traditional_chrome.gd")
const CharacterInfoOverlayState := preload("res://scripts/hud/character_info_overlay_state.gd")
const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayStatsPresenter := preload("res://scripts/hud/character_info_overlay_stats_presenter.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

# 출하 기준 해상도(project.godot viewport 2020x1246). stretch=canvas_items/expand
# 라 캔버스 높이는 1246 아래로 내려가지 않는다.
const SHIPPED_VIEW := Vector2(2051.0, 1246.0)
const SHORT_VIEW := Vector2(1280.0, 900.0)
# 설명 블록 최악 케이스 픽스처(강조 2줄 + 본문 3줄). 렌더 캡처 스모크의
# card_description 레그와 같은 문구를 쓴다 -- 캡처는 비-headless에서만 도는데,
# 카드 축소의 핵심 리스크인 "설명이 카드 밖으로 샌다"는 폰트 메트릭만으로도
# 판정할 수 있으므로 여기서 headless 자동 회귀 봉인으로 승격한다.
const WORST_CASE_DESCRIPTION := "이동 속도 +25%, 활주 거리 +40%, 활주 후딜 -50%, 최대 기력 +120"
const WORST_CASE_DETAIL := "무공을 익히면 몸이 가벼워져 발놀림이 빨라지고, 활주 거리가 늘어나며, 후딜이 줄어 연속 대응이 한결 쉬워집니다."

var _failures: Array[String] = []
var _probe: StatsBandProbe = null
var _frame_count := 0


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var special_gauge_max := 500.0
	var player_paddle_width := 155.0
	var runtime_paddle_scale := 1.0
	var active_item_slots: Array = []


class FakeRegistry:
	extends RefCounted

	# 무공(퍽) 보너스를 실제로 태우는 스텁을 꽂을 수 있게 한다. 비어 있으면
	# 모든 모듈이 null -> 기본 능력치.
	var modules: Dictionary = {}

	func get_instance(key: String) -> Object:
		return modules.get(key, null)

	func get_cached_instance(key: String) -> Object:
		return modules.get(key, null)


# 이동 속도 / 활주 거리 / 활주 후딜에 실제 무공 보너스를 태우는 runtime_perk_state
# 스텁. build_player_stat_rows가 이 값을 집어 오지 않으면 표시가 기본값에
# 머무르므로, "레지스트리 항상 null" 픽스처로는 잡을 수 없는 누락을 잡는다.
class BoostedPerkStateStub:
	extends RefCounted

	const SPEED_MULTIPLIER := 1.25
	const DASH_DURATION_MULTIPLIER := 1.40
	const DASH_RECOVERY_MULTIPLIER := 0.50

	func get_player_speed_multiplier() -> float:
		return SPEED_MULTIPLIER

	func get_dash_duration_frames(base_frames: float) -> float:
		return base_frames * DASH_DURATION_MULTIPLIER

	func get_dash_recovery_frames(base_frames: float) -> float:
		return base_frames * DASH_RECOVERY_MULTIPLIER


class FakeStatsContextState:
	extends RefCounted

	var owner: Object = FakeOwner.new()
	var registry: Object = FakeRegistry.new()
	var hover_mouse_pos: Vector2 = Vector2(-1.0, -1.0)

	func get_stats_context_owner() -> Object:
		return owner

	func get_stats_context_registry() -> Object:
		return registry

	func get_status_hover_mouse_pos() -> Vector2:
		return hover_mouse_pos


# 툴팁 드로어 호출을 잡아내는 캐릭터 정보창 대역. 실제 정보창을 registry에
# 꽂아도 되지만, 여기서는 "밴드가 정보창의 툴팁 경로로 hover_data를 그대로
# 넘기는가"가 판정 대상이라 호출 인자를 기록한다.
class TooltipSpyOverlay:
	extends RefCounted

	var calls := 0
	var last_data: Dictionary = {}

	func _draw_tooltip(_canvas: CanvasItem, data: Dictionary, _mouse_pos: Vector2, _view_size: Vector2, _font: Font, _icon_renderer: Object = null) -> void:
		calls += 1
		last_data = data.duplicate(true)


# 실제 드로우 경로를 관통시키는 probe. 헬퍼 반환값이 아니라 트리에 붙은
# CanvasItem._draw() 안에서 렌더러를 돌려야 draw_* 호출이 유효하다.
class StatsBandProbe:
	extends Node2D

	var renderer: Object = null
	var runtime_state: Object = null
	var boosted_renderer: Object = null
	var boosted_runtime_state: Object = null
	var band_rect := Rect2()
	var short_band_rect := Rect2()
	var drawn_row_rect_count := -1
	var short_drawn_row_rect_count := -1
	var ledger_inner := Rect2()
	var base_values: Array = []
	var boosted_labels: Array = []
	var boosted_values: Array = []
	var boosted_colors: Array = []
	var hover_renderer: Object = null
	var hover_runtime_state: FakeStatsContextState = null
	var tooltip_spy: TooltipSpyOverlay = null
	var hover_row_center := Vector2.ZERO
	var no_hover_tooltip_calls := -1
	var hover_tooltip_calls := -1
	var view_size := Vector2.ZERO
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		# 크롬 안쪽 여백 계약: 레이아웃의 STATS_BAND_MIN_HEIGHT가 이 값을 전제한다.
		ledger_inner = RuntimePerkTraditionalChrome.draw_stats_ledger(self, band_rect)
		renderer._draw_stats_band(self, runtime_state, {}, band_rect)
		drawn_row_rect_count = renderer._stats_hover_row_rects.size()
		base_values = renderer._stats_value_cache.duplicate()
		# 반증 레그: 최소 높이를 밑도는 rect를 억지로 넘기면 행이 잘려야 한다.
		# 잘리지 않는다면 위 단언이 변별력 없는 공허-GREEN이라는 뜻이다.
		renderer._draw_stats_band(self, runtime_state, {}, short_band_rect)
		short_drawn_row_rect_count = renderer._stats_hover_row_rects.size()
		# 무공 보너스가 실린 컨텍스트: 별도 렌더러 인스턴스로 그려야 조립 캐시가
		# 섞이지 않는다(시그니처는 snapshot만 보므로 컨텍스트 교체를 못 잡는다).
		boosted_renderer._draw_stats_band(self, boosted_runtime_state, {}, band_rect, view_size)
		boosted_labels = boosted_renderer._stats_label_cache.duplicate()
		boosted_values = boosted_renderer._stats_value_cache.duplicate()
		boosted_colors = boosted_renderer._stats_color_cache.duplicate()
		# 툴팁 레그: 마우스를 띠 밖 -> 행 위로 옮기며 hover_data가 실제로
		# 정보창 툴팁 드로어까지 흘러가는지 본다(음성 대조 포함).
		hover_runtime_state.hover_mouse_pos = Vector2(-1.0, -1.0)
		hover_renderer._draw_stats_band(self, hover_runtime_state, {}, band_rect, view_size)
		no_hover_tooltip_calls = tooltip_spy.calls
		# 0번 = 이동 속도. 보너스가 실린 행이라 원인별 증감 내역이 실제로 생긴다.
		var rows: Array = hover_renderer._stats_hover_row_rects
		hover_row_center = (rows[0] as Rect2).get_center() if rows.size() > 0 else Vector2.ZERO
		hover_runtime_state.hover_mouse_pos = hover_row_center
		hover_renderer._draw_stats_band(self, hover_runtime_state, {}, band_rect, view_size)
		hover_tooltip_calls = tooltip_spy.calls


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_verify_band_is_inside_group_height()
	_verify_band_height_admits_every_row()
	_verify_band_disabled_when_it_does_not_fit()
	_verify_card_geometry_change_keeps_font_basis()
	_verify_worst_case_description_stays_inside_card()
	_verify_title_plaque_floor()
	_verify_runtime_state_context_capture()
	_verify_renderer_consumes_layout_rect()
	_start_draw_probe()


func _process(_delta: float) -> bool:
	if _probe == null:
		return false
	_frame_count += 1
	if _frame_count < 3:
		return false
	_verify_drawn_rows()
	_finish()
	return true


func _finish() -> void:
	LanguageSettings.set_test_locale_override("")
	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("runtime_perk_choice_stats_band_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


# 1) 띠가 그룹 높이에 포함되는가 -- 카드 y가 실제로 위로 올라오고, 같은
#    build_layout을 쓰는 카드 히트테스트가 그린 위치와 계속 일치하는가.
func _verify_band_is_inside_group_height() -> void:
	var helper := RuntimePerkChoiceLayout.new()
	var without: Dictionary = helper.build_layout(SHIPPED_VIEW, 3, false)
	var with_band: Dictionary = helper.build_layout(SHIPPED_VIEW, 3, true)
	var band_rect: Rect2 = _rect(with_band.get("stats_rect", Rect2()))
	var panel_rect: Rect2 = _rect(with_band.get("panel_rect", Rect2()))
	_expect(_rect(without.get("stats_rect", Rect2())).size.y <= 0.0, "band-off layout must not reserve a stats rect")
	_expect(band_rect.size.y > 0.0, "shipped view must fit the stats band")
	_expect(band_rect.position.y >= panel_rect.end.y, "stats band must sit below the 현재 무공 ledger")
	_expect(
		_vector(with_band.get("cards_start", Vector2.ZERO)).y < _vector(without.get("cards_start", Vector2.ZERO)).y,
		"reserving the stats band must lift the cards -- otherwise the band is not in group_h"
	)
	var hint_y: float = _vector(with_band.get("hint_pos", Vector2.ZERO)).y
	_expect(hint_y >= band_rect.end.y, "the select hint must move below the stats band")
	_expect(hint_y <= SHIPPED_VIEW.y, "the whole modal group must stay inside the view")

	# 히트테스트 일치: get_card_rects / get_card_index_at 가 같은 플래그를 받아야
	# 그린 카드 위에서 클릭이 잡힌다.
	var rects: Array = helper.get_card_rects(SHIPPED_VIEW, 3, 1.0, true)
	_expect(rects.size() == 3, "band-on layout must still build one rect per card")
	for index in range(rects.size()):
		var card_rect: Rect2 = _rect(rects[index])
		_expect(
			helper.get_card_index_at(card_rect.get_center(), SHIPPED_VIEW, 3, 1.0, true) == index,
			"band-on card %d must hit-test at its own drawn centre" % index
		)
	# 반증: 플래그를 빠뜨린 히트테스트는 어긋난다(= 위 단언에 변별력이 있다).
	# 카드 중심으로는 판별이 안 된다 -- 세로 밀림(약 146px)이 카드 높이 절반보다
	# 작아서 중심점은 여전히 옛 rect 안에 들어간다. 상단 모서리로 재야 한다.
	var mismatched: bool = false
	for index in range(rects.size()):
		var card_rect: Rect2 = _rect(rects[index])
		var top_edge := Vector2(card_rect.get_center().x, card_rect.position.y + 4.0)
		_expect(
			helper.get_card_index_at(top_edge, SHIPPED_VIEW, 3, 1.0, true) == index,
			"band-on card %d must hit-test at its own drawn top edge" % index
		)
		if helper.get_card_index_at(top_edge, SHIPPED_VIEW, 3, 1.0, false) != index:
			mismatched = true
	_expect(mismatched, "dropping the band flag on the hit-test path must desync -- otherwise the seal proves nothing")


# 2) 예약된 띠 높이가 10행을 전부 담는가 (드로어 최소 지오메트리 기준).
func _verify_band_height_admits_every_row() -> void:
	var helper := RuntimePerkChoiceLayout.new()
	for choice_count: int in [3, 4, 5]:
		var layout: Dictionary = helper.build_layout(SHIPPED_VIEW, choice_count, true)
		var band_rect: Rect2 = _rect(layout.get("stats_rect", Rect2()))
		if band_rect.size.y <= 0.0:
			continue
		_expect(
			band_rect.size.y >= RuntimePerkChoiceLayout.STATS_BAND_MIN_HEIGHT,
			"%d-card stats band must never be reserved below the 10-row minimum" % choice_count
		)
		var inner_h: float = band_rect.size.y - RuntimePerkChoiceLayout.STATS_BAND_CHROME_INSET * 2.0
		var usable: float = inner_h - RuntimePerkChoiceLayout.STATS_BAND_HEADER_HEIGHT - RuntimePerkChoiceLayout.STATS_BAND_FOOTER_PADDING
		_expect(
			usable >= RuntimePerkChoiceLayout.STATS_BAND_ROW_MIN_GAP * float(CharacterInfoOverlayState.STAT_ROW_COUNT),
			"%d-card stats band inner height must admit all %d rows" % [choice_count, CharacterInfoOverlayState.STAT_ROW_COUNT]
		)
	_expect(
		RuntimePerkChoiceLayout.STATS_BAND_ROW_COUNT == CharacterInfoOverlayState.STAT_ROW_COUNT,
		"layout row-count assumption must track the character-info stats presenter"
	)


# 3) 세로 예산이 모자라면 잘라 그리지 말고 꺼야 한다.
func _verify_band_disabled_when_it_does_not_fit() -> void:
	var helper := RuntimePerkChoiceLayout.new()
	var short_on: Dictionary = helper.build_layout(SHORT_VIEW, 3, true)
	var short_off: Dictionary = helper.build_layout(SHORT_VIEW, 3, false)
	_expect(_rect(short_on.get("stats_rect", Rect2())).size.y <= 0.0, "a view without room must drop the stats band")
	_expect(
		_vector(short_on.get("cards_start", Vector2.ZERO)).is_equal_approx(_vector(short_off.get("cards_start", Vector2.ZERO))),
		"dropping the band must restore the original card placement exactly"
	)
	var viewport_rect := Rect2(Vector2.ZERO, SHORT_VIEW)
	for card_rect_value in helper.get_card_rects(SHORT_VIEW, 3, 1.0, true):
		_expect(viewport_rect.encloses(_rect(card_rect_value)), "short-view cards must stay inside the viewport")


# 4) 카드 폭은 폰트 크기의 유일한 파생원이라 그대로여야 하고, 높이만 줄었다.
func _verify_card_geometry_change_keeps_font_basis() -> void:
	_expect(
		is_equal_approx(RuntimePerkChoiceLayout.DEFAULT_CARD_SIZE.x, 268.0),
		"card width feeds every card font size (name/rank/description) -- it must stay 268"
	)
	_expect(
		RuntimePerkChoiceLayout.DEFAULT_CARD_SIZE.y < 390.0,
		"card height must be reduced to make room for the stats band"
	)
	var helper := RuntimePerkChoiceLayout.new()
	var layout: Dictionary = helper.build_layout(SHIPPED_VIEW, 3, true)
	var card_size: Vector2 = _vector(layout.get("card_size", Vector2.ZERO))
	# 설명 폰트는 clampi(round(card_width / 16.4), 12, 18) -- 폭이 295 이상이면
	# 상한 18에 물려 카드 크기 변경이 글자 크기를 건드리지 않는다.
	_expect(card_size.x >= 295.0, "shipped card width must stay in the clamped max description font band")
	# 설명 블록이 실제로 카드 안에 머무는지는 실 wrap 결과로 판정한다 --
	# _verify_worst_case_description_stays_inside_card 참조.


# 4') 카드 축소의 실질 리스크 = 설명 누출. 실 wrap 캐시(_ensure_card_desc_cache)로
#     줄 수를 뽑고 _draw_card_description_block의 기하를 그대로 재현해, 최악
#     케이스(강조 2 + 본문 3)의 마지막 줄이 설명 상자와 카드 안에 머무는지 본다.
#     비-headless 캡처 없이도 도는 자동 회귀 봉인이다.
func _verify_worst_case_description_stays_inside_card() -> void:
	var helper := RuntimePerkChoiceLayout.new()
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var card_size: Vector2 = _vector(helper.build_layout(SHIPPED_VIEW, 3, true).get("card_size", Vector2.ZERO))
	var choice := {
		"id": "physique_move_speed",
		"name": "유운보 수련",
		"description": WORST_CASE_DESCRIPTION,
		"detail": WORST_CASE_DETAIL,
		"current_level": 3,
		"next_level": 4,
		"max_level": 5,
	}
	renderer._ensure_card_desc_cache([choice], card_size.x, null)
	var cached: Dictionary = renderer._card_desc_cache[0] if renderer._card_desc_cache.size() > 0 else {}
	var accent_lines: Array = cached.get("accent_lines", []) if cached.get("accent_lines", []) is Array else []
	var body_lines: Array = cached.get("body_lines", []) if cached.get("body_lines", []) is Array else []
	var font_size: int = int(cached.get("font_size", 0))
	# 폰트 크기 계약: 카드 축소가 설명 글자를 건드리면 안 된다(clampi 상한 18).
	_expect(font_size == 18, "shrunk card must keep the clamped max description font size (got %d)" % font_size)
	_expect(
		accent_lines.size() + body_lines.size() >= 5,
		"fixture must reach the 5-line worst case (got %d + %d)" % [accent_lines.size(), body_lines.size()]
	)

	# _draw_card_description_block 재현: box = rect + (14,3) / -(28,6),
	# 첫 baseline = box.y + font_size + 8, 줄 간격 = font_size + 4,
	# 강조/본문 사이 2px.
	var desc_top: float = card_size.y * RuntimePerkChoiceLayout.CARD_DESCRIPTION_TOP_RATIO
	var desc_h: float = card_size.y * RuntimePerkChoiceLayout.CARD_DESCRIPTION_HEIGHT_RATIO
	var box_top: float = desc_top + 3.0
	var box_bottom: float = desc_top + desc_h - 3.0
	var line_h: float = float(font_size + 4)
	var cursor: float = box_top + float(font_size) + 8.0
	cursor += float(accent_lines.size()) * line_h
	if not body_lines.is_empty() and not accent_lines.is_empty():
		cursor += 2.0
	cursor += float(body_lines.size()) * line_h
	_expect(
		cursor <= box_bottom,
		"worst-case description must fit the shrunk card's text box (%.1f > %.1f)" % [cursor, box_bottom]
	)
	_expect(box_bottom <= card_size.y, "description box must stay inside the card")

	# 성급 밑줄과 설명 괘선이 이중선으로 붙지 않아야 한다(_draw_card 기하).
	var rank_underline_y: float = card_size.y * 0.386 + clamp(card_size.y * 0.092, 27.0, 38.0) + max(14.0, card_size.y * 0.045) + 12.0
	_expect(
		desc_top - rank_underline_y >= 12.0,
		"description rule must clear the rank underline (%.1f vs %.1f)" % [desc_top, rank_underline_y]
	)


# 5) 제목 현판 중심 하한.
func _verify_title_plaque_floor() -> void:
	var helper := RuntimePerkChoiceLayout.new()
	for view: Vector2 in [SHIPPED_VIEW, SHORT_VIEW, Vector2(2020.0, 1600.0)]:
		for requested: bool in [false, true]:
			var layout: Dictionary = helper.build_layout(view, 3, requested)
			var title_pos: Vector2 = _vector(layout.get("title_pos", Vector2.ZERO))
			_expect(
				title_pos.y >= RuntimePerkChoiceLayout.TITLE_MIN_CENTER_Y,
				"title plaque centre must stay below the top clip floor (view %s, band %s)" % [view, requested]
			)
			# 하한만으로는 부족하다 -- 실제 현판 높이는 폰트 메트릭에서 나온다.
			# 렌더러의 실 산식(_draw_title)으로 현판 상단이 화면 밖으로 나가지
			# 않는지, 카드 상단과 겹치지 않는지 함께 본다.
			var layout_scale: float = float(layout.get("layout_scale", 1.0))
			var plaque_h: float = _title_plaque_height(layout_scale)
			_expect(
				title_pos.y - plaque_h * 0.5 >= 0.0,
				"title plaque must not be clipped by the screen top (view %s, band %s, top %.1f)" % [view, requested, title_pos.y - plaque_h * 0.5]
			)
			_expect(
				title_pos.y + plaque_h * 0.5 <= _vector(layout.get("cards_start", Vector2.ZERO)).y,
				"title plaque must not overlap the cards (view %s, band %s)" % [view, requested]
			)


# _draw_title의 현판 크기 산식과 동일: max(72, 제목 텍스트 높이 + 34 * scale).
func _title_plaque_height(layout_scale: float) -> float:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var font: Font = renderer._get_font()
	if font == null:
		return 72.0
	var title_font_size: int = clampi(int(round(float(RuntimePerkOverlayRenderer.TITLE_FONT_SIZE) * layout_scale)), 34, 58)
	var text_size: Vector2 = renderer._get_title_text_size(font, title_font_size)
	return maxf(72.0, text_size.y + 34.0 * layout_scale)


# 6) runtime_perk_state가 update()의 owner/registry로 플래그를 잡는가.
func _verify_runtime_state_context_capture() -> void:
	var state := RuntimePerkState.new()
	var helper := RuntimePerkChoiceLayout.new()
	_expect(not state.stats_band_enabled, "a fresh runtime state must not claim a stats context")
	_expect(not helper.stats_band_requested_from_runtime_state(state), "layout must read the runtime-state flag")

	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	state.update(0.016, SHIPPED_VIEW, owner, registry)
	_expect(state.stats_band_enabled, "update() with owner+registry must enable the stats band")
	_expect(state.get_stats_context_owner() == owner, "captured owner must be the one update() received")
	_expect(state.get_stats_context_registry() == registry, "captured registry must be the one update() received")
	_expect(helper.stats_band_requested_from_runtime_state(state), "layout must follow the captured context")

	state.update(0.016, SHIPPED_VIEW, null, registry)
	_expect(not state.stats_band_enabled, "an owner-less update must drop the stats band again")
	_expect(state.get_stats_context_owner() == null, "an owner-less update must clear the captured owner")
	_expect(state.get_stats_context_registry() == null, "an owner-less update must release the now-unusable registry")

	state.update(0.016, SHIPPED_VIEW, owner, registry)
	state.reset()
	_expect(not state.stats_band_enabled, "new-run reset must clear the stats-band context")
	_expect(state.get_stats_context_owner() == null and state.get_stats_context_registry() == null, "new-run reset must release both captured context objects")


# 7) 렌더러가 레이아웃의 stats_rect를 실제로 소비하는지에 대한 소스 계약.
#    (그림 결과 판정은 probe 레그가 담당한다.)
func _verify_renderer_consumes_layout_rect() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	_expect(source.find("_draw_stats_band(") >= 0, "renderer must own a stats band drawer")
	_expect(source.find("layout.get(\"stats_rect\"") >= 0, "renderer must read the band rect from the shared layout")
	var state_source: String = FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_state.gd")
	var update_body: String = _function_body(state_source, "func _update_internal(")
	_expect(
		update_body.find("_capture_stats_context(") >= 0,
		"the stats context must be captured in update() -- a draw-time flag flip desyncs first-frame hit-testing"
	)


func _start_draw_probe() -> void:
	var helper := RuntimePerkChoiceLayout.new()
	var layout: Dictionary = helper.build_layout(SHIPPED_VIEW, 3, true)
	_probe = StatsBandProbe.new()
	_probe.name = "RuntimePerkStatsBandProbe"
	_probe.renderer = RuntimePerkOverlayRenderer.new()
	_probe.runtime_state = FakeStatsContextState.new()
	_probe.boosted_renderer = RuntimePerkOverlayRenderer.new()
	var boosted_state := FakeStatsContextState.new()
	(boosted_state.registry as FakeRegistry).modules["runtime_perk_state"] = BoostedPerkStateStub.new()
	_probe.boosted_runtime_state = boosted_state
	_probe.hover_renderer = RuntimePerkOverlayRenderer.new()
	var hover_state := FakeStatsContextState.new()
	var tooltip_spy := TooltipSpyOverlay.new()
	var hover_registry := hover_state.registry as FakeRegistry
	hover_registry.modules["character_info_overlay"] = tooltip_spy
	# 보너스를 실어야 이동 속도 행에 원인별 증감 내역이 실제로 생긴다.
	hover_registry.modules["runtime_perk_state"] = BoostedPerkStateStub.new()
	_probe.hover_runtime_state = hover_state
	_probe.tooltip_spy = tooltip_spy
	_probe.view_size = SHIPPED_VIEW
	_probe.band_rect = _rect(layout.get("stats_rect", Rect2()))
	_probe.short_band_rect = Rect2(
		_probe.band_rect.position,
		Vector2(_probe.band_rect.size.x, RuntimePerkChoiceLayout.STATS_BAND_MIN_HEIGHT - 60.0)
	)
	get_root().add_child(_probe)
	_probe.queue_redraw()


# 2') 결과 판정: 예약된 띠 안에서 실제로 10행이 전부 그려졌는가.
func _verify_drawn_rows() -> void:
	_expect(_probe.draw_count > 0, "stats band probe must actually run _draw()")
	_expect(
		_probe.drawn_row_rect_count == CharacterInfoOverlayState.STAT_ROW_COUNT,
		"reserved stats band must draw all %d rows (drew %d)" % [CharacterInfoOverlayState.STAT_ROW_COUNT, _probe.drawn_row_rect_count]
	)
	_expect(
		_probe.short_drawn_row_rect_count < CharacterInfoOverlayState.STAT_ROW_COUNT,
		"an under-minimum band must visibly clip rows -- otherwise the row-count assert is void-GREEN"
	)
	var renderer: Object = _probe.renderer
	var labels: Array = renderer._stats_label_cache
	var values: Array = renderer._stats_value_cache
	_expect(labels.size() == CharacterInfoOverlayState.STAT_ROW_COUNT, "stats band must build the full player row set")
	var filled_labels := 0
	var filled_values := 0
	for index in range(labels.size()):
		if str(labels[index]) != "":
			filled_labels += 1
		if index < values.size() and str(values[index]) != "":
			filled_values += 1
	_expect(filled_labels == CharacterInfoOverlayState.STAT_ROW_COUNT, "every stats row must carry a label")
	_expect(filled_values == CharacterInfoOverlayState.STAT_ROW_COUNT, "every stats row must carry a value")
	# 크롬 안쪽 여백 계약: 레이아웃 최소 높이 계산이 이 인셋을 전제한다.
	_expect(
		is_equal_approx(
			_probe.ledger_inner.size.y,
			_probe.band_rect.size.y - RuntimePerkChoiceLayout.STATS_BAND_CHROME_INSET * 2.0
		),
		"stats ledger chrome inset must match the layout's row-capacity assumption"
	)
	_verify_boosted_values_match_character_info()
	_verify_hover_tooltip_routes_through_character_info()


# 툴팁 봉인: 행 hover가 캐릭터 정보창의 툴팁 드로어까지 도달하고, 그 payload가
# 설명(body)과 원인별 증감(breakdown_rows)을 모두 싣고 있어야 한다.
# include_breakdown을 hover 게이팅했으므로, 시그니처에서 그 플래그가 빠지면
# 캐시 히트로 breakdown이 영원히 비어 있게 된다 -- 그 회귀를 여기서 잡는다.
func _verify_hover_tooltip_routes_through_character_info() -> void:
	_expect(_probe.no_hover_tooltip_calls == 0, "no tooltip may be drawn while the pointer is outside the band")
	_expect(_probe.hover_tooltip_calls == 1, "hovering a stats row must drive exactly one character-info tooltip draw")
	var data: Dictionary = _probe.tooltip_spy.last_data
	_expect(str(data.get("title", "")) != "", "tooltip payload must carry the row label")
	_expect(str(data.get("subtitle", "")) != "", "tooltip payload must carry the row value")
	_expect(
		str(data.get("body", "")).length() > 10,
		"tooltip payload must carry the row description (그대로: 설명 포함)"
	)
	var breakdown: Array = data.get("breakdown_rows", []) if data.get("breakdown_rows", []) is Array else []
	_expect(
		not breakdown.is_empty(),
		"tooltip payload must carry the per-source breakdown rows (그대로: 원인별 증감 포함)"
	)


# 정확성 봉인: 무공 보너스가 실린 컨텍스트에서 (a) 표시가 기본값에서 실제로
# 움직이고, (b) 그 값/색이 캐릭터 정보창이 같은 owner+registry로 뽑는 값과
# 한 글자도 다르지 않아야 한다. 레지스트리가 항상 null인 픽스처만 쓰면
# "보너스가 통째로 누락돼 기본 능력치만 표시" 되는 회귀를 못 잡는다.
func _verify_boosted_values_match_character_info() -> void:
	var boosted_values: Array = _probe.boosted_values
	var boosted_labels: Array = _probe.boosted_labels
	var boosted_colors: Array = _probe.boosted_colors
	_expect(boosted_values.size() == CharacterInfoOverlayState.STAT_ROW_COUNT, "boosted band must build the full row set")

	# (a) 기본값 대비 실제로 달라진 행: 이동 속도 / 활주 거리 / 활주 후딜.
	var changed := 0
	for index in range(mini(boosted_values.size(), _probe.base_values.size())):
		if str(boosted_values[index]) != str(_probe.base_values[index]):
			changed += 1
	_expect(
		changed >= 3,
		"perk bonuses must move at least the 3 boosted rows (speed / dash range / dash recovery), moved %d" % changed
	)

	# (b) 캐릭터 정보창이 같은 컨텍스트로 뽑는 행과 라벨/값/색이 동일해야 한다.
	#     정보창은 자기 상수(SPECIAL_GAUGE_MAX / PLAYER_BASE_PADDLE_WIDTH /
	#     BASE_ACTIVE_ITEM_SLOT_COUNT / 버프·디버프 색)를 직접 넘기므로, 밴드가
	#     상수를 하나라도 다르게 타이핑하면 여기서 갈라진다.
	var overlay: Object = CharacterInfoOverlay.new()
	var boosted_state: Object = _probe.boosted_runtime_state
	overlay._build_stats(boosted_state.get_stats_context_owner(), boosted_state.get_stats_context_registry())
	var info_labels: Array = overlay._stats_label_cache
	var info_values: Array = overlay._stats_value_cache
	var info_colors: Array = overlay._stats_color_cache
	_expect(info_values.size() == boosted_values.size(), "character-info row count must match the band")
	var mismatches: Array[String] = []
	for index in range(mini(info_values.size(), boosted_values.size())):
		if str(info_labels[index]) != str(boosted_labels[index]):
			mismatches.append("label[%d] %s != %s" % [index, info_labels[index], boosted_labels[index]])
		if str(info_values[index]) != str(boosted_values[index]):
			mismatches.append("value[%d] %s != %s" % [index, info_values[index], boosted_values[index]])
		var info_color: Color = info_colors[index] if info_colors[index] is Color else Color.WHITE
		var band_color: Color = boosted_colors[index] if boosted_colors[index] is Color else Color.WHITE
		if not info_color.is_equal_approx(band_color):
			mismatches.append("color[%d] %s != %s" % [index, info_color, band_color])
	_expect(
		mismatches.is_empty(),
		"perk-screen stats must be byte-identical to the character-info panel: %s" % ", ".join(mismatches)
	)

	# 게이지 바까지 같은 소스에서 나오는지: 강화된 이동 속도 행은 기준선(0.5)보다
	# 오른쪽으로 차고 버프 색을 써야 한다.
	var speed_index: int = _row_index(info_labels, "이동 속도")
	_expect(speed_index >= 0, "boosted row set must contain the move-speed row")
	if speed_index >= 0:
		var speed_color: Color = info_colors[speed_index] if info_colors[speed_index] is Color else Color.WHITE
		_expect(
			speed_color.is_equal_approx(CharacterInfoOverlayState.STAT_BUFF_COLOR),
			"a boosted move speed must render in the buff colour on both screens"
		)
		var bar_fills: Array = CharacterInfoOverlayStatsPresenter._player_stat_bar_fill_cache
		_expect(
			speed_index < bar_fills.size() and float(bar_fills[speed_index]) > 0.5,
			"a boosted move speed must fill past the base-anchored midpoint"
		)
	var recovery_index: int = _row_index(info_labels, "활주 후딜 시간")
	if recovery_index >= 0:
		var recovery_color: Color = info_colors[recovery_index] if info_colors[recovery_index] is Color else Color.WHITE
		_expect(
			recovery_color.is_equal_approx(CharacterInfoOverlayState.STAT_BUFF_COLOR),
			"a shortened dash recovery is an improvement -- it must use the buff colour, not the debuff colour"
		)


func _row_index(labels: Array, label: String) -> int:
	var wanted: String = LanguageSettings.translate_text(label)
	for index in range(labels.size()):
		if str(labels[index]) == wanted:
			return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\n\nfunc ", start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


func _rect(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	return Rect2()


func _vector(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO
