extends SceneTree

const RuntimePerkDescriptionEmphasis := preload(
	"res://scripts/hud/runtime_perk_description_emphasis.gd"
)
const RuntimePerkOverlayRenderer := preload(
	"res://scripts/hud/runtime_perk_overlay_renderer.gd"
)
const RuntimePerkCatalog := preload(
	"res://scripts/characters/runtime_perk_catalog.gd"
)
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const LOCALE_FIXTURES := {
	"ko": {"text": "피해 +25%, 1.5초 지속, 위력 2배", "tokens": ["+25%", "1.5초", "2배"]},
	"en": {"text": "Damage +25%, lasts 1.5 seconds, multiplier x2", "tokens": ["+25%", "1.5 seconds", "x2"]},
	"zh": {"text": "伤害+25％，持续1.5秒，倍率2倍", "tokens": ["+25％", "1.5秒", "2倍"]},
	"ja": {"text": "ダメージ+25％、1.5秒持続、威力2倍", "tokens": ["+25％", "1.5秒", "2倍"]},
	"es": {"text": "Daño +25 %, dura 1,5 segundos, multiplicador x2", "tokens": ["+25 %", "1,5 segundos", "x2"]},
	"pt-BR": {"text": "Dano +25 %, dura 1,5 segundos, multiplicador x2", "tokens": ["+25 %", "1,5 segundos", "x2"]},
	"ru": {"text": "Урон +25 %, длится 1,5 секунды, множитель x2", "tokens": ["+25 %", "1,5 секунды", "x2"]},
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_locale_fixtures()
	_verify_all_localized_catalog_digits_are_emphasized()
	_verify_renderer_cache_consumes_shared_owner()
	_verify_start_reward_entrypoints_share_description_drawer()
	LanguageSettings.set_test_locale_override("")
	ProjectResourceLoader.clear_caches()
	if _failures.is_empty():
		print("runtime_perk_description_emphasis_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_locale_fixtures() -> void:
	for locale_value in LOCALE_FIXTURES.keys():
		var locale := str(locale_value)
		var fixture: Dictionary = LOCALE_FIXTURES[locale]
		var text := str(fixture.get("text", ""))
		var segments: Array = RuntimePerkDescriptionEmphasis.split_segments(text)
		_expect(_join_segments(segments) == text, "%s segmentation must preserve the localized text byte-for-byte" % locale)
		_expect(_plain_segments_have_no_ascii_digits(segments), "%s numeric characters must not remain in the body-color segments" % locale)
		for token_value in fixture.get("tokens", []):
			var token := str(token_value)
			_expect(_has_emphasized_token(segments, token), "%s must emphasize '%s' as one token" % [locale, token])
	var plain := RuntimePerkDescriptionEmphasis.split_segments("수치가 없는 설명입니다.")
	_expect(plain.size() == 1 and not bool((plain[0] as Dictionary).get("emphasized", true)), "copy without a number must remain one body-color segment")


func _verify_all_localized_catalog_digits_are_emphasized() -> void:
	var inspected := 0
	var numeric_by_locale: Dictionary = {}
	for locale in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(locale)
		numeric_by_locale[locale] = 0
		var catalog: Dictionary = RuntimePerkCatalog.new().get_all_perk_data()
		for perk_value in catalog.values():
			if not (perk_value is Dictionary):
				continue
			var perk := perk_value as Dictionary
			var texts: Array = [str(perk.get("detail", ""))]
			var descriptions: Dictionary = perk.get("descriptions", {}) if perk.get("descriptions", {}) is Dictionary else {}
			for description_value in descriptions.values():
				texts.append(str(description_value))
			for text_value in texts:
				var text := str(text_value)
				if text == "":
					continue
				inspected += 1
				var segments: Array = RuntimePerkDescriptionEmphasis.split_segments(text)
				_expect(_join_segments(segments) == text, "%s catalog segmentation must preserve source text" % locale)
				_expect(_plain_segments_have_no_ascii_digits(segments), "%s catalog text left a digit in a body-color segment: %s" % [locale, text])
				if _has_ascii_digit(text):
					numeric_by_locale[locale] = int(numeric_by_locale.get(locale, 0)) + 1
	for locale in LanguageSettings.SUPPORTED_LANGUAGES:
		_expect(int(numeric_by_locale.get(locale, 0)) > 0, "%s catalog audit must inspect numeric copy" % locale)
	_expect(inspected > 0, "localized catalog emphasis audit must inspect real descriptions")
	print("S3 catalog emphasis audit: inspected=%d numeric_by_locale=%s" % [inspected, numeric_by_locale])


func _verify_renderer_cache_consumes_shared_owner() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var renderer: Object = RuntimePerkOverlayRenderer.new()
	var choice := {
		"id": "s3_probe",
		"name": "강조 봉인",
		"description": "피해 +25%, 1.5초 지속",
		"detail": "본문 수치는 2배이며 나머지 글자는 현행 색을 유지합니다.",
		"current_level": 1,
		"next_level": 2,
		"max_level": 5,
	}
	renderer._ensure_card_desc_cache([choice], 353.0, null, 173.0)
	var cached: Dictionary = renderer._card_desc_cache[0] if renderer._card_desc_cache.size() > 0 else {}
	var accent_segment_lines: Array = cached.get("accent_segment_lines", []) if cached.get("accent_segment_lines", []) is Array else []
	var body_segment_lines: Array = cached.get("body_segment_lines", []) if cached.get("body_segment_lines", []) is Array else []
	_expect(not accent_segment_lines.is_empty(), "shared renderer cache must carry emphasized segments for the numeric effect line")
	_expect(not body_segment_lines.is_empty(), "shared renderer cache must carry emphasized segments for the friendly body line")
	_expect(_nested_has_emphasized_token(accent_segment_lines, "+25%"), "renderer effect cache must use the shared owner for +25%")
	_expect(_nested_has_emphasized_token(body_segment_lines, "2배"), "renderer body cache must use the shared owner for 2배")
	_verify_cached_line_segments(renderer, cached, "accent_lines", "accent_segment_lines", 353.0 - 44.0)
	_verify_cached_line_segments(renderer, cached, "body_lines", "body_segment_lines", 353.0 - 44.0)
	_expect(
		RuntimePerkOverlayRenderer.CARD_DESCRIPTION_BODY_COLOR.is_equal_approx(Color(50.0 / 255.0, 42.0 / 255.0, 34.0 / 255.0)),
		"non-numeric card copy must retain the existing body ink color"
	)
	_expect(
		RuntimePerkOverlayRenderer.CARD_DESCRIPTION_EMPHASIS_COLOR.is_equal_approx(Color(96.0 / 255.0, 55.0 / 255.0, 26.0 / 255.0)),
		"numeric emphasis must reuse the existing effect-line palette color"
	)


func _verify_cached_line_segments(
	renderer: Object,
	cached: Dictionary,
	line_key: String,
	segment_key: String,
	max_width: float
) -> void:
	var lines: Array = cached.get(line_key, []) if cached.get(line_key, []) is Array else []
	var segment_lines: Array = cached.get(segment_key, []) if cached.get(segment_key, []) is Array else []
	var font: Font = renderer._get_font()
	var font_size := int(cached.get("font_size", 0))
	_expect(segment_lines.size() == lines.size(), "%s must keep one segment list per wrapped line" % segment_key)
	for line_index in range(mini(lines.size(), segment_lines.size())):
		var segments: Array = segment_lines[line_index] if segment_lines[line_index] is Array else []
		_expect(_join_segments(segments) == str(lines[line_index]), "%s line %d must reconstruct the wrapped source" % [segment_key, line_index])
		var segmented_width := 0.0
		for segment_value in segments:
			if segment_value is Dictionary:
				segmented_width += renderer._get_text_size(font, str((segment_value as Dictionary).get("text", "")), font_size).x
		_expect(segmented_width <= max_width + 1.0, "%s line %d segmented draw must stay inside the card width" % [segment_key, line_index])


# 일반 보상, 탑 시작, 탑 승리 보상 세 entrypoint가 모두 같은 설명 드로어를
# 호출하는지 잠근다. 강조 파서가 화면별로 복제되면 이 소유권 씰이 RED가 된다.
func _verify_start_reward_entrypoints_share_description_drawer() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_overlay_renderer.gd")
	var reward_start := source.find("func draw(\n")
	var start_card_start := source.find("func draw_tower_start_card(")
	var tower_reward_start := source.find("func draw_tower_reward_pick(")
	var next_owner_start := source.find("func build_tower_reward_balance_rows(")
	_expect(reward_start >= 0 and start_card_start > reward_start, "shared renderer must expose the ordinary reward draw entrypoint")
	_expect(tower_reward_start > start_card_start and next_owner_start > tower_reward_start, "shared renderer must expose tower start/reward entrypoints")
	if reward_start >= 0 and start_card_start > reward_start:
		_expect(source.substr(reward_start, start_card_start - reward_start).find("_draw_per_card_descriptions(") >= 0, "ordinary reward cards must use the shared description drawer")
	if start_card_start >= 0 and tower_reward_start > start_card_start:
		_expect(source.substr(start_card_start, tower_reward_start - start_card_start).find("_draw_per_card_descriptions(") >= 0, "tower start cards must use the shared description drawer")
	if tower_reward_start >= 0 and next_owner_start > tower_reward_start:
		_expect(source.substr(tower_reward_start, next_owner_start - tower_reward_start).find("_draw_per_card_descriptions(") >= 0, "tower reward cards must use the shared description drawer")
	_expect(source.count("RuntimePerkDescriptionEmphasis := preload(") == 1, "numeric emphasis must have exactly one owner preload in the shared renderer")


func _join_segments(segments: Array) -> String:
	var result := ""
	for segment_value in segments:
		if segment_value is Dictionary:
			result += str((segment_value as Dictionary).get("text", ""))
	return result


func _plain_segments_have_no_ascii_digits(segments: Array) -> bool:
	for segment_value in segments:
		if not (segment_value is Dictionary):
			return false
		var segment := segment_value as Dictionary
		if not bool(segment.get("emphasized", false)) and _has_ascii_digit(str(segment.get("text", ""))):
			return false
	return true


func _has_ascii_digit(text: String) -> bool:
	for character in text:
		if character in "0123456789":
			return true
	return false


func _has_emphasized_token(segments: Array, token: String) -> bool:
	for segment_value in segments:
		if segment_value is Dictionary:
			var segment := segment_value as Dictionary
			if bool(segment.get("emphasized", false)) and str(segment.get("text", "")) == token:
				return true
	return false


func _nested_has_emphasized_token(segment_lines: Array, token: String) -> bool:
	for line_value in segment_lines:
		if line_value is Array and _has_emphasized_token(line_value as Array, token):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
