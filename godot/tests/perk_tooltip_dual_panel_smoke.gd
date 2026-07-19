extends SceneTree

# Seals the 2-panel perk tooltip (2026-07-09 request): the TAB character-info perk
# grid hover tooltip now splits into left = friendly `detail`, right = "능력치"
# (the per-level numeric stats from `descriptions[level]`), mirroring the passive
# item dual tooltip. Guards:
#  - build_perk_stat_entries() splits comma-separated stats into right-panel lines,
#  - it collapses to [] (single panel) when detail == stats -- the non-Korean locale
#    case where localize_perk_data rewrites both to one summary string, so a split
#    would just duplicate the text,
#  - set_hover_data() propagates the stat entries as roll_options AND the "능력치"
#    right_header into the hover payload, which is what routes draw_tooltip to the
#    dual-panel path,
#  - the real catalog perk (부메랑장인 / reinforced_boomerang_gauntlet) produces a
#    populated right panel in Korean because its detail and stats genuinely differ.

const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)
	_test_split_distinct()
	_test_collapse_when_identical()
	_test_empty_stats()
	_test_hover_payload_wiring()
	_test_catalog_perk_dual_panel()
	_test_refresh_draw_arrays_fills_detail_cache()
	_test_overflow_effective_level_keeps_stats()
	print("perk_tooltip_dual_panel_smoke: ok")
	ProjectResourceLoader.clear_caches()
	quit(0)


func _test_split_distinct() -> void:
	var stats := "넉백 +20%, 스턴 +20%, 발사속도 +15%, 유도 +10%, 스폰 +50%"
	var detail := "부메랑을 메탈 강화합니다."
	var entries: Array = CharacterInfoOverlayPerkPresenter.build_perk_stat_entries(stats, detail)
	_expect(entries.size() == 5, "distinct stats should split into 5 entries, got %d" % entries.size())
	_expect(str(entries[0].get("text", "")) == "넉백 +20%", "first entry text mismatch: %s" % str(entries[0]))
	_expect(str(entries[4].get("text", "")) == "스폰 +50%", "last entry text mismatch: %s" % str(entries[4]))
	_expect(entries[0].get("color", null) is Color, "entry must carry a Color for the right panel")


func _test_collapse_when_identical() -> void:
	# Non-Korean locale collapse: detail == stats -> no right panel (return []).
	var summary := "부메랑을 메탈 강화하고 성능을 끌어올립니다."
	var entries: Array = CharacterInfoOverlayPerkPresenter.build_perk_stat_entries(summary, summary)
	_expect(entries.is_empty(), "identical detail/stats must collapse to a single panel (empty entries)")
	# Whitespace-only difference must still collapse.
	var padded: Array = CharacterInfoOverlayPerkPresenter.build_perk_stat_entries("  " + summary + " ", summary)
	_expect(padded.is_empty(), "whitespace-only difference must still collapse")


func _test_empty_stats() -> void:
	var entries: Array = CharacterInfoOverlayPerkPresenter.build_perk_stat_entries("", "설명만 있는 퍽")
	_expect(entries.is_empty(), "empty stats must produce no right panel")


func _test_hover_payload_wiring() -> void:
	var stats := "넉백 +20%, 스턴 +20%"
	var detail := "부메랑을 강철로 바꿉니다."
	var entries: Array = CharacterInfoOverlayPerkPresenter.build_perk_stat_entries(stats, detail)
	var data: Dictionary = {}
	data = CharacterInfoOverlayValueUtils.set_hover_data(data, "부메랑장인", "Lv.1", detail, Color.WHITE, null, null, entries, CharacterInfoOverlayPerkPresenter.PERK_STAT_HEADER)
	_expect(str(data.get("body", "")) == detail, "left panel body must be the friendly detail")
	_expect(data.has("roll_options"), "stat entries must land in roll_options to trigger the dual panel")
	_expect(CharacterInfoOverlayValueUtils.get_array(data.get("roll_options")).size() == 2, "roll_options should carry 2 stat lines")
	_expect(str(data.get("right_header", "")) == "능력치", "right panel header must be 능력치, got %s" % str(data.get("right_header", "")))

	# Collapsed case: empty entries + empty header -> single panel (no dual keys).
	var single: Dictionary = {}
	single = CharacterInfoOverlayValueUtils.set_hover_data(single, "설명퍽", "Lv.1", detail, Color.WHITE, null, null, [], "")
	_expect(not single.has("roll_options"), "collapsed perk must NOT set roll_options (single panel)")
	_expect(not single.has("right_header"), "collapsed perk must NOT set a right_header (single panel)")


func _test_catalog_perk_dual_panel() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var acquired: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(
		{"reinforced_boomerang_gauntlet": 1}, catalog, null, null, {}, [], Color.WHITE, Color.WHITE
	)
	_expect(acquired.size() == 1, "expected one acquired perk, got %d" % acquired.size())
	var perk: Dictionary = acquired[0]
	var stats := CharacterInfoOverlayValueUtils.get_string_fallback(perk, "description", "detail")
	var detail := CharacterInfoOverlayValueUtils.get_string_fallback(perk, "detail", "description")
	_expect(detail != "" and stats != "", "catalog perk must expose both detail and stats")
	_expect(detail != stats, "부메랑장인 detail and stats must differ in Korean (distinct panels)")
	var entries: Array = CharacterInfoOverlayPerkPresenter.build_perk_stat_entries(stats, detail)
	_expect(entries.size() >= 3, "부메랑장인 Lv.1 should split into several stat lines, got %d" % entries.size())


func _test_refresh_draw_arrays_fills_detail_cache() -> void:
	var catalog: Object = RuntimePerkCatalog.new()
	var acquired: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(
		{"reinforced_boomerang_gauntlet": 1}, catalog, null, null, {}, [], Color.WHITE, Color.WHITE
	)
	var draw_id: Array[String] = []
	var draw_color: Array[Color] = []
	var border_color: Array[Color] = []
	var hover_border_color: Array[Color] = []
	var level_text: Array[String] = []
	var level_color: Array[Color] = []
	var hover_title: Array[String] = []
	var hover_body: Array[String] = []
	var hover_detail: Array[String] = []
	CharacterInfoOverlayPerkPresenter.refresh_draw_arrays(
		acquired, draw_id, draw_color, border_color, hover_border_color,
		level_text, level_color, hover_title, hover_body, hover_detail,
		Color.WHITE,
		Callable(CharacterInfoOverlayFormatter, "perk_level_text"),
		Callable(CharacterInfoOverlayFormatter, "perk_level_color").bind(Color.WHITE)
	)
	_expect(hover_detail.size() == 1, "hover_detail cache must be sized to the acquired perks")
	_expect(hover_detail[0] != "", "hover_detail cache must hold the friendly detail")
	_expect(hover_body[0] != "", "hover_body cache must hold the numeric stats")
	_expect(hover_detail[0] != hover_body[0], "detail and stats caches must differ for a numeric perk")


func _test_overflow_effective_level_keeps_stats() -> void:
	# transcendent_crown / sage_ring push a perk's effective level past its max defined
	# description (e.g., Lv.6 for a max-5 perk). The tooltip must show the GENERATED
	# Lv.6 stats (runtime_perk_overflow_descriptions.gd), NOT the stale Lv.5 text
	# (2026-07-10 bug) and NOT the detail (which would collapse the right panel --
	# the original 2026-07-09 bug).
	var catalog: Object = RuntimePerkCatalog.new()
	var raw: Dictionary = catalog.get_perk_data("common_swiftness")
	var descriptions: Dictionary = raw.get("descriptions", {})
	var lv5_stats: String = str(descriptions.get(5, ""))
	var detail: String = str(raw.get("detail", ""))
	_expect(lv5_stats != "" and detail != "" and lv5_stats != detail, "test fixture: common_swiftness must have distinct Lv.5 stats and detail")

	var data: Dictionary = CharacterInfoOverlayPerkPresenter.acquired_perk_data(
		"common_swiftness", 4, 6, catalog, {}, Color.WHITE
	)
	var stats: String = str(data.get("description", ""))
	_expect(stats == "이동속도 36% 증가", "Lv.6 perk stats must be generated from the runtime pattern (6%%/lv), got: %s" % stats)
	_expect(stats != lv5_stats, "Lv.6 perk stats must NOT freeze on the stale Lv.5 text")
	_expect(stats != detail, "Lv.6 perk stats must NOT collapse to the detail")
	# The right "능력치" panel must therefore still render.
	var entries: Array = CharacterInfoOverlayPerkPresenter.build_perk_stat_entries(stats, detail)
	_expect(not entries.is_empty(), "Lv.6 perk must still produce 능력치 entries (dual panel), not an empty right panel")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("perk_tooltip_dual_panel_smoke FAIL: " + message)
	ProjectResourceLoader.clear_caches()
	quit(1)
