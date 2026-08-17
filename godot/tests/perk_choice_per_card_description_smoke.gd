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

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# 비저장 locale 고정(표준): 저장형 set_language()는 실 user:// cfg를
	# 오염시킨다 — 테스트 override로 엔진 locale만 고정하고 종료 전 해제.
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_test_cache_builds_per_choice()
	_test_training_keeps_numeric_accent_without_level()
	_test_detail_collapse()
	_test_unlock_shows_detail_only()
	_test_wrap_respects_width_and_lines()
	_test_wrap_breaks_long_single_token()
	_test_cache_rebuild_signature()
	LanguageSettings.set_test_locale_override("")
	ProjectResourceLoader.clear_caches()
	# `_expect`의 quit(1)은 실행을 멈추지 않는다 — 게이트 없이 말미의 무조건
	# ok/quit(0)이 종료코드를 덮어써 실패가 GREEN으로 읽힌다(CLAUDE.md 공허-GREEN 변종).
	if _failed:
		quit(1)
		return
	print("perk_choice_per_card_description_smoke: ok")
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
			# Skill manual (비급): no accent, body = the friendly detail only (the
			# `description` "빙혼비격 초식 비급" just restates the card name).
			"name": "빙혼비격 비급",
			"description": "빙혼비격 초식 비급",
			"detail": "게이지 420 이상에서 파워스매싱을 입력하면 공을 재발사하는 초식을 익힙니다.",
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


func _test_training_keeps_numeric_accent_without_level() -> void:
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	# 실제 카드 문구와 같은 모양(정본: physique_training_catalog.build_card).
	var training := {
		"name": "유운보 수련",
		"description": "이동 속도 4% 증가",
		"detail": "좌우로 움직이는 속도가 빨라집니다. 무공 슬롯을 쓰지 않습니다.",
		"is_physique_training": true,
		"current_level": 0,
		"next_level": 0,
		"max_level": 0,
	}
	renderer._ensure_card_desc_cache([training], 250.0)
	var cached: Dictionary = renderer._card_desc_cache[0]
	var accent_joined: String = " ".join(cached.get("accent_lines", []))
	_expect(accent_joined.find("4% 증가") >= 0, "training must keep its numeric accent without a Mugong level")
	_expect(not (cached.get("body_lines", []) as Array).is_empty(), "training must keep the friendly detail as the body")

	# Five compact cards use a smaller font and a shorter body budget instead of
	# spilling their descriptions into adjacent columns.
	renderer._ensure_card_desc_cache([training, training, training, training, training], 126.0)
	var compact: Dictionary = renderer._card_desc_cache[0]
	_expect(int(compact.get("font_size", 0)) == 10, "compact five-card training copy should use the 10px floor")
	var compact_body: Array = compact.get("body_lines", []) as Array
	_expect(compact_body.size() <= 2, "compact five-card body must stay within two lines")
	# 줄 수만 세면 문장이 서술어 앞에서 잘려 나가도 통과한다(2026-08-06 리뷰 P2-③).
	# 버려진 텍스트가 있으면 마지막 줄이 잘림 표시로 끝나야 한다.
	var compact_joined: String = "".join(compact_body)
	var full_detail: String = str(training["detail"])
	var kept_everything: bool = compact_joined.replace(" ", "") == full_detail.replace(" ", "")
	_expect(
		kept_everything or compact_joined.ends_with("..."),
		"clipped compact copy must end with a truncation marker, got '%s'" % compact_joined
	)
	# 대조군: 넓은 카드에서는 잘리지 않으므로 잘림 표시가 붙으면 안 된다.
	var wide_joined: String = "".join(cached.get("body_lines", []) as Array)
	_expect(not wide_joined.ends_with("..."), "wide card body fits and must not be marked as clipped, got '%s'" % wide_joined)


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
	_expect((unlock.get("accent_lines", []) as Array).is_empty(), "manual perk must NOT accent the redundant 'X 초식 비급'")
	var body_joined: String = " ".join(unlock.get("body_lines", []))
	_expect(body_joined.find("재발사") >= 0, "manual perk body must be the friendly detail (how it works), not the redundant 'X 초식 비급'")


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
	_failed = true
	push_error("perk_choice_per_card_description_smoke FAIL: " + message)
	ProjectResourceLoader.clear_caches()
	quit(1)
