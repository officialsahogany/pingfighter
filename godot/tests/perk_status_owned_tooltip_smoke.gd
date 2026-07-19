extends SceneTree

# Seals the "현재 퍽" owned-perk hover tooltip in the perk choice modal (2026-07-09
# request): hovering an owned-perk icon shows a character-info-style tooltip
# (left = friendly detail, right = "능력치" numeric breakdown). Guards:
#  - _perk_stats_for_level() reads descriptions[level] with an effective-level fallback,
#  - _perk_stat_lines() comma-splits the stats and collapses to [] (single panel) when
#    the stats equal the detail (non-Korean locale summary case),
#  - runtime_perk_state stores/returns the hover mouse position,
#  - the modal input handler captures the pointer on mouse motion so the renderer can
#    hover-test the icons.

const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkModalInput := preload("res://scripts/characters/runtime_perk_modal_input.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkFusionDisplayProjection := preload("res://scripts/characters/perk_fusion_display_projection.gd")
const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")
const MysticDiceRoller := preload("res://scripts/characters/mystic_dice_roller.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# 비저장 locale 고정(표준): 저장형 set_language()는 실 user:// cfg를
	# 오염시킨다 — 테스트 override로 엔진 locale만 고정하고 종료 전 해제.
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_test_stats_for_level()
	_test_stat_lines_split_and_collapse()
	_test_state_hover_storage()
	_test_input_captures_hover()
	_test_owned_perks_exclude_active_unlocks()
	_test_slot_grid_reserves_free_cells()
	_test_dice_hover_reaches_right_panel()
	_test_fusion_hover_reaches_right_panel()
	_test_status_panel_wiring_source()
	print("perk_status_owned_tooltip_smoke: ok")
	LanguageSettings.set_test_locale_override("")
	ProjectResourceLoader.clear_caches()
	quit(0)


func _skill() -> Dictionary:
	return {
		"name": "부메랑장인",
		"descriptions": {1: "넉백 +20%, 스턴 +20%", 2: "넉백 +28%, 스턴 +35%"},
		"detail": "액티브 아이템 부메랑이 강철 부메랑으로 바뀝니다.",
		"level": 1,
		"max_level": 5,
		"icon_color": Color(0.6, 0.8, 1.0),
	}


func _test_stats_for_level() -> void:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	_expect(renderer._perk_stats_for_level(_skill()) == "넉백 +20%, 스턴 +20%", "level 1 stats mismatch")
	var lv2: Dictionary = _skill()
	lv2["level"] = 2
	_expect(renderer._perk_stats_for_level(lv2) == "넉백 +28%, 스턴 +35%", "level 2 stats mismatch")
	# Effective level above the defined caps: registered perk ids generate the
	# overflow stat line (runtime_perk_overflow_descriptions.gd); ids without a
	# registered pattern keep the highest-defined fallback.
	var lv7: Dictionary = _skill()
	lv7["level"] = 7
	_expect(renderer._perk_stats_for_level(lv7) == "넉백 +28%, 스턴 +35%", "unregistered overflow must fall back to highest defined")
	var catalog: Object = RuntimePerkCatalog.new()
	var real_lv7: Dictionary = catalog.get_perk_data("dash_jump")
	real_lv7["id"] = "dash_jump"
	real_lv7["level"] = 7
	_expect(renderer._perk_stats_for_level(real_lv7) == "대쉬 거리 49% 증가", "registered overflow must show the generated Lv.7 stats")


func _test_stat_lines_split_and_collapse() -> void:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var lines: Array = renderer._perk_stat_lines("넉백 +20%, 스턴 +20%, 발사속도 +15%", "강철로 바뀝니다.")
	_expect(lines.size() == 3, "distinct stats must split into 3 lines, got %d" % lines.size())
	_expect(str(lines[0]) == "넉백 +20%", "first stat line mismatch: %s" % str(lines[0]))
	# Collapse: stats identical to detail (non-Korean summary case) -> no right panel.
	_expect(renderer._perk_stat_lines("같은 요약", "같은 요약").is_empty(), "identical stats/detail must collapse")
	_expect(renderer._perk_stat_lines("", "설명만").is_empty(), "empty stats must produce no right panel")


func _test_state_hover_storage() -> void:
	var state: Object = RuntimePerkState.new()
	state.set_status_hover_mouse_pos(Vector2(123.0, 456.0))
	_expect(state.get_status_hover_mouse_pos() == Vector2(123.0, 456.0), "state must store/return the hover mouse position")


func _test_input_captures_hover() -> void:
	var input: Object = RuntimePerkModalInput.new()
	var recorder: Dictionary = {"pos": Vector2(-999.0, -999.0)}
	var callbacks: Dictionary = {
		"get_card_index_at": func(_pos: Vector2, _vs: Vector2) -> int: return -1,
		"select_choice_index": func(_idx: int) -> void: pass,
		"set_status_hover_mouse_pos": func(pos: Vector2) -> void: recorder["pos"] = pos,
	}
	var event := InputEventMouseMotion.new()
	event.position = Vector2(321.0, 654.0)
	input.handle_choice_input(event, null, null, Vector2(1000.0, 700.0), callbacks)
	_expect(recorder["pos"] == Vector2(321.0, 654.0), "mouse motion must store the pointer for hover-testing")


func _test_owned_perks_exclude_active_unlocks() -> void:
	# The "현재 퍽" list must exclude active-skill unlock perks (they live in the 5-orb
	# skill HUD and do not consume a perk slot); passive perks stay.
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var catalog: Object = RuntimePerkCatalog.new()
	var levels: Dictionary = {"common_bulk_up": 1, "unlock_warp_gate": 1, "unlock_smasher_wheel": 1}
	var acquired: Array = renderer._build_acquired_perks(levels, catalog, null)
	var ids: Array = []
	for perk in acquired:
		ids.append(str((perk as Dictionary).get("id", "")))
	_expect(ids.has("common_bulk_up"), "passive perk (common_bulk_up) must remain in the owned list")
	_expect(not ids.has("unlock_warp_gate"), "active-skill unlock (unlock_warp_gate) must be excluded")
	_expect(not ids.has("unlock_smasher_wheel"), "active-skill unlock (unlock_smasher_wheel) must be excluded")


func _test_slot_grid_reserves_free_cells() -> void:
	# 코덱스 v1 P1 행동 씰: 소모 5 + 비소모(common_expansion Lv.1, 한도 6→7)
	# → 카운터 5/7, 그리드 7칸 중 빈칸 정확 2, 비소모 셀은 그리드 뒤 별도
	# 표시(빈칸 산정 미참여). acquired.size() 기준 옛 산정은 빈칸 1로 어긋난다.
	PerkConversionFlags.debug_set_enabled(true)
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var catalog: Object = RuntimePerkCatalog.new()
	var levels: Dictionary = {
		"dash_lightweight": 1,
		"dash_module_control": 1,
		"dash_jump": 1,
		"item_luck": 1,
		"common_swiftness": 1,
		"common_expansion": 1,
	}
	var slot_limit: int = catalog.get_perk_slot_limit(levels)
	_expect(slot_limit == 7, "expansion Lv.1 fixture should raise the slot limit to 7 (got %d)" % slot_limit)
	_expect(catalog.count_owned_slot_perks(levels) == 5, "fixture should consume exactly 5 slots")
	var acquired: Array = renderer._build_acquired_perks(levels, catalog, null)
	var grid: Array = renderer._build_status_slot_grid(acquired, slot_limit)
	_expect(grid.size() == 8, "grid must hold 7 slot cells + 1 trailing free cell (got %d)" % grid.size())
	if grid.size() != 8:
		PerkConversionFlags.debug_set_enabled(false)
		return
	var empty_count := 0
	for value in grid:
		if value is Dictionary and bool((value as Dictionary).get("_empty_slot", false)):
			empty_count += 1
	_expect(empty_count == 2, "5/7 fixture must show exactly 2 empty slots (got %d)" % empty_count)
	for idx in range(5):
		_expect(
			grid[idx] is Dictionary and not bool((grid[idx] as Dictionary).get("_empty_slot", false)),
			"slot-consuming cells must fill the grid front (index %d)" % idx
		)
	for idx in [5, 6]:
		_expect(
			grid[idx] is Dictionary and bool((grid[idx] as Dictionary).get("_empty_slot", false)),
			"empty cells must sit after the consuming cells (index %d)" % idx
		)
	_expect(
		grid[7] is Dictionary and bool((grid[7] as Dictionary).get("_slot_free_cell", false)),
		"the non-consuming perk must trail the grid as a free cell, not eat an empty slot"
	)
	PerkConversionFlags.debug_set_enabled(false)


func _test_dice_hover_reaches_right_panel() -> void:
	# 코덱스 v1 P2 행동 씰(주사위): 실 status-panel hover 경로 — projection
	# 스냅샷 → fold → 툴팁 stat entries. 주사위 엔트리는 descriptions 사전
	# 없이 단수 description(태그 7행)이라 옛 경로에서는 우측 패널이 사라졌다.
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var catalog: Object = RuntimePerkCatalog.new()
	var permanent: Dictionary = {}
	var sign_flip := 1
	for stat_key: String in MysticDiceRoller.STAT_KEYS:
		permanent[stat_key] = 5 * sign_flip
		sign_flip = -sign_flip
	var snapshot := {
		"perk_fusion_display_projection": {
			"entries": [{"type": "mystic_dice", "permanent_raw": permanent, "use_count": 3}],
		},
	}
	var acquired: Array = renderer._build_acquired_perks_for_snapshot({}, catalog, null, snapshot)
	_expect(acquired.size() == 1, "dice projection should fold into one display entry (got %d)" % acquired.size())
	if acquired.is_empty():
		return
	var entries: Array = renderer._perk_status_tooltip_stat_entries(acquired[0] as Dictionary)
	_expect(
		entries.size() == MysticDiceRoller.STAT_KEYS.size(),
		"all %d dice stat rows must reach the right panel (got %d)" % [MysticDiceRoller.STAT_KEYS.size(), entries.size()]
	)
	var seen_colors: Dictionary = {}
	for entry_value in entries:
		var entry: Dictionary = entry_value as Dictionary
		_expect(str(entry.get("text", "")).find("[[") < 0, "dice tag prefixes must not leak into the panel text")
		seen_colors[str(entry.get("color", Color.WHITE))] = true
	_expect(seen_colors.size() >= 2, "benefit/curse rows must keep distinct colors (got %d)" % seen_colors.size())


func _test_fusion_hover_reaches_right_panel() -> void:
	# 코덱스 v1 P2 행동 씰(융합): 실 projector로 만든 projection 스냅샷을
	# fold에 관통 — 융합 엔트리의 태그 스탯이 우측 패널 엔트리로 도달하고
	# 태그 원문은 노출되지 않아야 한다.
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var catalog: Object = RuntimePerkCatalog.new()
	var projector: Object = PerkFusionDisplayProjection.new()
	var levels := {"common_swiftness": 5, "item_luck": 5}
	var record := {
		"fusion_id": "fusion_0",
		"sources": ["common_swiftness", "item_luck"],
		"outcome": "side_effect",
		"option_penalties": {"common_swiftness": {"power": {"multiplier": 0.8}}},
	}
	var projection: Dictionary = projector.build(levels, {"fusion_revision": 1, "records": [record]}, catalog)
	_expect(not (projection.get("entries", []) as Array).is_empty(), "projector fixture should emit projection entries")
	var snapshot := {"perk_fusion_display_projection": projection}
	var acquired: Array = renderer._build_acquired_perks_for_snapshot(levels, catalog, null, snapshot)
	var fusion_entry: Dictionary = {}
	for value in acquired:
		if value is Dictionary and str((value as Dictionary).get("tree", "")) == "fusion":
			fusion_entry = value as Dictionary
			break
	_expect(not fusion_entry.is_empty(), "fusion projection entry must survive the status-panel fold")
	if fusion_entry.is_empty():
		return
	var entries: Array = renderer._perk_status_tooltip_stat_entries(fusion_entry)
	_expect(entries.size() >= 2, "fusion tagged stat rows must reach the right panel (got %d)" % entries.size())
	var seen_colors: Dictionary = {}
	for entry_value in entries:
		var entry: Dictionary = entry_value as Dictionary
		_expect(str(entry.get("text", "")).find("[[") < 0, "fusion tag prefixes must not leak into the panel text")
		seen_colors[str(entry.get("color", Color.WHITE))] = true
	_expect(seen_colors.size() >= 2, "fusion header/body rows must keep distinct colors (got %d)" % seen_colors.size())

	# 취소선 메타 보존: 삭제 옵션 태그 라인은 strikethrough 플래그를 유지한다.
	var deleted_fixture := {
		"max_level": 1,
		"detail": "융합 결과 로그",
		"description": (
			str(PerkFusionLocalization.STAT_HEADER_PREFIX) + "결과 요약\n"
			+ str(PerkFusionLocalization.STAT_DELETED_PREFIX) + "삭제된 옵션"
		),
	}
	var deleted_entries: Array = renderer._perk_status_tooltip_stat_entries(deleted_fixture)
	_expect(deleted_entries.size() == 2, "deleted-option fixture should split into 2 rows (got %d)" % deleted_entries.size())
	if deleted_entries.size() == 2:
		_expect(
			bool((deleted_entries[1] as Dictionary).get("strikethrough", false)),
			"deleted-option row must preserve the strikethrough flag"
		)
		_expect(
			not bool((deleted_entries[0] as Dictionary).get("strikethrough", false)),
			"header row must not inherit the strikethrough flag"
		)


func _test_status_panel_wiring_source() -> void:
	# 소스씰: canvas 인자가 CanvasItem 고정이라 Fake draw 캡처가 불가하므로,
	# 조립/엔트리 헬퍼가 실제 draw 함수 본문에 배선되어 있음을 함수 본문
	# 추출로 봉인한다(헬퍼만 GREEN이고 draw는 옛 경로인 회귀 차단).
	var source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	var panel_body := _extract_function_source(source, "func _draw_status_panel(")
	_expect(panel_body.find("_build_status_slot_grid(") >= 0, "_draw_status_panel must assemble the grid via _build_status_slot_grid")
	_expect(panel_body.find("_empty_slot") >= 0, "_draw_status_panel must branch empty cells on the assembler's _empty_slot flag")
	_expect(panel_body.find("max(slot_limit_for_grid, acquired.size())") < 0, "the acquired.size() empty-slot math must stay removed")
	var tooltip_body := _extract_function_source(source, "func _draw_perk_status_tooltip(")
	_expect(tooltip_body.find("_perk_status_tooltip_stat_entries(") >= 0, "_draw_perk_status_tooltip must route the right panel through the shared entry parser")
	_expect(tooltip_body.find("strikethrough") >= 0, "_draw_perk_status_tooltip must render the strikethrough metadata")


func _extract_function_source(source: String, header: String) -> String:
	var start := source.find(header)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + header.length())
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("perk_status_owned_tooltip_smoke FAIL: " + message)
	ProjectResourceLoader.clear_caches()
	quit(1)
