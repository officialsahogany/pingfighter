extends SceneTree

# Seals the per-card perk-choice descriptions (2026-07-09 request): the perk choice
# modal no longer shows one shared panel for the selected/hovered perk -- every
# perk's description is laid out at once in a column under its own card. Guards:
#  - _ensure_card_desc_cache() builds one entry per choice with an accent line
#    (the numeric effect, ONLY for scaling Lv. perks) and a body (the friendly detail),
#  - unlock/instant/gold perks skip the accent so the column does not repeat the card
#    name, and the level tag is never repeated (the card already shows it),
#  - the body falls back to `description` when `detail` collapses to the same text
#    (the non-Korean locale case),
#  - _wrap_text_px() respects the pixel width and the max-line cap,
#  - the wrap cache rebuilds only when the choice set / card width changes.

const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# 비저장 locale 고정(표준): 저장형 set_language()는 실 user:// cfg를
	# 오염시킨다 — 테스트 override로 엔진 locale만 고정하고 종료 전 해제.
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_test_cache_builds_per_choice()
	_test_detail_collapse()
	_test_unlock_shows_detail_only()
	_test_wrap_respects_width_and_lines()
	_test_wrap_breaks_long_single_token()
	_test_cache_rebuild_signature()
	print("perk_choice_per_card_description_smoke: ok")
	LanguageSettings.set_test_locale_override("")
	ProjectResourceLoader.clear_caches()
	quit(0)


func _make_choices() -> Array:
	return [
		{
			# Scaling perk: accent = numeric stat, body = friendly detail. Real choices
			# always carry max_level (set by _build_level_choice); a scaling perk needs
			# max_level > 1 or its tag collapses to the single-perk "고유" wording.
			"name": "부메랑장인",
			"description": "넉백 +20%, 스턴 +20%, 발사속도 +15%",
			"detail": "액티브 아이템 부메랑이 강철 부메랑으로 바뀌어 더 강하게 던집니다.",
			"current_level": 1,
			"next_level": 2,
			"max_level": 5,
			"icon_color": Color(0.6, 0.8, 1.0),
		},
		{
			# Collapsed case: detail identical to description (non-Korean locale shape).
			"name": "요약퍽",
			"description": "같은 요약 문장입니다.",
			"detail": "같은 요약 문장입니다.",
			"current_level": 0,
			"next_level": 1,
			"max_level": 5,
			"icon_color": Color(1.0, 0.8, 0.4),
		},
		{
			# Unlock perk (해금): no accent, body = the friendly detail only (the
			# `description` "고스트스매싱 스킬 해금" just restates the card name).
			"name": "고스트스매싱 해금",
			"description": "고스트스매싱 스킬 해금",
			"detail": "게이지 420 이상에서 파워스매싱을 입력하면 공을 재발사하는 스킬을 해금합니다.",
			"max_level": 1,
			"character_restriction": "smasher",
			"unlocks_skill": "ghost_shot",
			"icon_color": Color(0.5, 0.3, 0.7),
		},
	]


func _test_cache_builds_per_choice() -> void:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	renderer._ensure_card_desc_cache(_make_choices(), 250.0)
	var cache: Array = renderer._card_desc_cache
	_expect(cache.size() == 3, "cache must hold one entry per choice, got %d" % cache.size())
	var first: Dictionary = cache[0]
	_expect(not (first.get("accent_lines", []) as Array).is_empty(), "scaling perk must have an accent (numeric) line")
	_expect(not (first.get("body_lines", []) as Array).is_empty(), "scaling perk must have a body (detail) line")
	# The accent must be the numeric stat, and the body must be the friendly detail.
	var accent_joined: String = " ".join(first.get("accent_lines", []))
	_expect(accent_joined.find("넉백") >= 0, "accent should carry the numeric stat text")


func _test_detail_collapse() -> void:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	renderer._ensure_card_desc_cache(_make_choices(), 250.0)
	var second: Dictionary = renderer._card_desc_cache[1]
	_expect((second.get("accent_lines", []) as Array).is_empty(), "collapsed perk has no distinct numeric accent")
	_expect(not (second.get("body_lines", []) as Array).is_empty(), "collapsed perk still shows one body line")


func _test_unlock_shows_detail_only() -> void:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	renderer._ensure_card_desc_cache(_make_choices(), 250.0)
	var unlock: Dictionary = renderer._card_desc_cache[2]
	_expect((unlock.get("accent_lines", []) as Array).is_empty(), "unlock perk must NOT accent the redundant 'X 스킬 해금'")
	var body_joined: String = " ".join(unlock.get("body_lines", []))
	_expect(body_joined.find("재발사") >= 0, "unlock perk body must be the friendly detail (how it works), not the redundant 'X 스킬 해금'")


func _test_wrap_respects_width_and_lines() -> void:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var font: Font = ThemeDB.fallback_font
	var text := "액티브 아이템 부메랑이 강철 부메랑으로 바뀌어 더 강하게 던지고 필드에도 더 자주 등장합니다."
	var max_px := 200.0
	var lines: Array = renderer._wrap_text_px(text, 11, max_px, 3)
	_expect(not lines.is_empty(), "wrap must produce at least one line")
	_expect(lines.size() <= 3, "wrap must honor the max-line cap, got %d" % lines.size())
	for line in lines:
		var width: float = font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11).x
		# Every wrapped line must fit the column now -- the char-level fallback breaks even
		# a lone over-wide token, so there is no single-word overflow exemption anymore.
		_expect(width <= max_px + 1.0, "every wrapped line must fit column width: '%s' (%.1f > %.1f)" % [str(line), width, max_px])


func _test_wrap_breaks_long_single_token() -> void:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var font: Font = ThemeDB.fallback_font
	# Space-less CJK run: no break spaces at all, so a space-only wrap would emit one
	# overflowing line. The char-level fallback must split it to fit the column.
	var text := "넉백스턴발사속도상승부메랑장인효과가지속적으로강화되어필드전체를제압하고안녕하세요반갑습니다여러분"
	var max_px := 120.0
	var lines: Array = renderer._wrap_text_px(text, 11, max_px, 4)
	_expect(lines.size() >= 2, "a long space-less CJK run must wrap onto multiple lines, got %d" % lines.size())
	_expect(lines.size() <= 4, "char-level wrap must still honor the max-line cap, got %d" % lines.size())
	for line in lines:
		var width: float = font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11).x
		_expect(width <= max_px + 1.0, "char-broken CJK line must fit the column: '%s' (%.1f > %.1f)" % [str(line), width, max_px])


func _test_cache_rebuild_signature() -> void:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var choices := _make_choices()
	renderer._ensure_card_desc_cache(choices, 250.0)
	var sig_a: int = renderer._card_desc_cache_signature
	var cache_ref: Array = renderer._card_desc_cache
	# Same choices + width -> no rebuild (signature stable, same array instance).
	renderer._ensure_card_desc_cache(choices, 250.0)
	_expect(renderer._card_desc_cache_signature == sig_a, "identical inputs must not change the cache signature")
	_expect(is_same(renderer._card_desc_cache, cache_ref), "identical inputs must reuse the cached array (no rebuild)")
	# Different width -> rebuild.
	renderer._ensure_card_desc_cache(choices, 180.0)
	_expect(renderer._card_desc_cache_signature != sig_a, "a different card width must trigger a rebuild")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("perk_choice_per_card_description_smoke FAIL: " + message)
	ProjectResourceLoader.clear_caches()
	quit(1)
