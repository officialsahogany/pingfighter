extends SceneTree

const LingpetLanguageCatalog := preload("res://scripts/lingpet/lingpet_language_catalog.gd")
const LingpetLanguageRichText := preload("res://scripts/lingpet/lingpet_language_rich_text.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	var line := LingpetLanguageCatalog.get_line(LingpetLanguageCatalog.LINE_MARIBO_GREET_ARRIVE)
	_verify_fonts_load()
	_verify_emotion_seal_contract()
	_verify_level_zero_glyph_runs(line)
	_verify_level_three_mixed_runs(line)
	_verify_level_five_decoded_runs(line)
	_verify_key_fallback(line)
	_verify_determinism(line)
	_verify_rich_text_label_apply(line)
	_verify_source_traps()

	if _failures.is_empty():
		print("lingpet_rich_text_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_fonts_load() -> void:
	LingpetLanguageRichText.reset_font_cache_for_tests()
	_expect(LingpetLanguageRichText.prewarm_fonts(), "rich text renderer should prewarm Lingpet and body fonts")


func _verify_emotion_seal_contract() -> void:
	for line_id in LingpetLanguageCatalog.get_line_ids():
		var line := LingpetLanguageCatalog.get_line(line_id)
		var glyph_text := str(line.get("glyph_text", "")).strip_edges()
		_expect(glyph_text.ends_with(" *"), "Lingpet emotion seal should end with the star glyph: %s" % line_id)
		var tokens: Array = line.get("tokens", []) as Array
		var emotion_token_count := 0
		for token_value in tokens:
			var token: Dictionary = token_value as Dictionary
			if str(token.get("kind", "")) == "emotion":
				emotion_token_count += 1
				_expect(str(token.get("glyph", "")) == "*", "Lingpet emotion token should use the star glyph: %s" % line_id)
		_expect(emotion_token_count == 1, "Lingpet catalog line should have exactly one emotion seal: %s" % line_id)


func _verify_level_zero_glyph_runs(line: Dictionary) -> void:
	var tokens: Array = line.get("tokens", []) as Array
	var runs := LingpetLanguageRichText.build_runs(line, 0, Callable(self, "_translate_echo"))
	_expect(runs.size() == tokens.size(), "level 0 should preserve token count")
	for index in range(tokens.size()):
		var token := tokens[index] as Dictionary
		var run := runs[index] as Dictionary
		_expect(not bool(run.get("decoded", true)), "level 0 runs should be undecoded")
		_expect(str(run.get("font_path", "")) == LingpetLanguageRichText.LINGPET_FONT_PATH, "level 0 runs should use Lingpet Script font")
		_expect(not run.has("key"), "level 0 runs should not expose i18n keys")
		if str(token.get("kind", "")) == "emotion":
			_expect(str(run.get("kind", "")) == "emotion", "level 0 emotion token should stay a sigil run")
			_expect(str(run.get("style", "")) == "emotion_hidden", "level 0 emotion token should be hidden")
			_expect(not bool(run.get("visible", true)), "level 0 emotion token should not render")
			_expect(str(run.get("text", "")) == "", "level 0 emotion token should not show the star yet")
		else:
			_expect(str(run.get("kind", "")) == "glyph", "level 0 non-emotion tokens should render as glyph")
			_expect(bool(run.get("visible", false)), "level 0 glyph runs should be visible")
			_expect(run.get("color") == LingpetLanguageRichText.GLYPH_COLOR, "glyph runs should use undecoded color")


func _verify_level_three_mixed_runs(line: Dictionary) -> void:
	var tokens: Array = line.get("tokens", []) as Array
	var runs := LingpetLanguageRichText.build_runs(line, 3, Callable(self, "_translate_echo"))
	_expect(runs.size() == tokens.size(), "level 3 should preserve token count")
	for index in range(tokens.size()):
		var token := tokens[index] as Dictionary
		var run := runs[index] as Dictionary
		var tier := int(token.get("tier", 0))
		if tier <= 3:
			_expect(str(run.get("kind", "")) == "ko", "level 3 should decode tier <= 3")
			_expect(str(run.get("font_path", "")) == LingpetLanguageRichText.BODY_FONT_PATH, "decoded runs should use body font")
			_expect(run.get("color") == LingpetLanguageRichText.DECODED_COLOR, "normal decoded runs should use decoded color")
			_expect(str(run.get("text", "")) == str(token.get("key", "")), "decoded runs should pass through key fallback text")
			_expect(bool(run.get("visible", false)), "decoded level 3 runs should be visible")
		elif str(token.get("kind", "")) == "emotion":
			_expect(str(run.get("kind", "")) == "emotion", "level 3 emotion token should stay a sigil run")
			_expect(str(run.get("style", "")) == "emotion_hidden", "level 3 emotion token should still be hidden")
			_expect(not bool(run.get("visible", true)), "level 3 emotion token should not render")
			_expect(str(run.get("text", "")) == "", "level 3 emotion token should not show the star yet")
			_expect(str(run.get("font_path", "")) == LingpetLanguageRichText.LINGPET_FONT_PATH, "hidden emotion runs should keep Lingpet Script font")
		else:
			_expect(str(run.get("kind", "")) == "glyph", "level 3 should keep tier > 3 as glyph")
			_expect(str(run.get("font_path", "")) == LingpetLanguageRichText.LINGPET_FONT_PATH, "hidden level 3 runs should use Lingpet Script font")


func _verify_level_five_decoded_runs(line: Dictionary) -> void:
	var tokens: Array = line.get("tokens", []) as Array
	var runs := LingpetLanguageRichText.build_runs(line, 5, Callable(self, "_translate_echo"))
	_expect(runs.size() == tokens.size(), "level 5 should preserve token count")
	for index in range(tokens.size()):
		var token := tokens[index] as Dictionary
		var run := runs[index] as Dictionary
		if str(token.get("kind", "")) == "emotion":
			_expect(str(run.get("kind", "")) == "emotion", "level 5 emotion token should remain a sigil run")
			_expect(str(run.get("font_path", "")) == LingpetLanguageRichText.LINGPET_FONT_PATH, "lit emotion token should use Lingpet Script font")
			_expect(str(run.get("text", "")) == str(token.get("glyph", "")), "lit emotion token should show the star glyph")
			_expect(str(run.get("style", "")) == "emotion_lit", "lit emotion token should use emotion-lit style")
			_expect(run.get("color") == LingpetLanguageRichText.EMOTION_DECODED_COLOR, "decoded emotion token should use lit color")
			_expect(bool(run.get("visible", false)), "lit emotion token should render")
			_expect(not run.has("key"), "emotion token should not become translated text")
		else:
			_expect(str(run.get("kind", "")) == "ko", "level 5 should decode non-emotion tokens")
			_expect(str(run.get("font_path", "")) == LingpetLanguageRichText.BODY_FONT_PATH, "level 5 decoded runs should use body font")
			_expect(str(run.get("style", "")) == "decoded", "normal decoded token should use decoded style")


func _verify_key_fallback(line: Dictionary) -> void:
	var runs := LingpetLanguageRichText.build_runs(line, 1)
	var first_run := runs[0] as Dictionary
	_expect(str(first_run.get("kind", "")) == "ko", "level 1 first token should be decoded")
	_expect(str(first_run.get("text", "")) == str(first_run.get("key", "")), "missing language key should fall back to key text")


func _verify_determinism(line: Dictionary) -> void:
	var first := LingpetLanguageRichText.build_runs(line, 3, Callable(self, "_translate_echo"))
	var second := LingpetLanguageRichText.build_runs(line, 3, Callable(self, "_translate_echo"))
	_expect(var_to_str(first) == var_to_str(second), "rich text run build should be deterministic")


func _verify_rich_text_label_apply(line: Dictionary) -> void:
	var label := RichTextLabel.new()
	var runs := LingpetLanguageRichText.render_line_to_label(label, line, 3, Callable(self, "_translate_echo"), 18)
	var expected_text := LingpetLanguageRichText.runs_to_plain_text(runs)
	if label.has_method("get_parsed_text"):
		_expect(str(label.call("get_parsed_text")) == expected_text, "RichTextLabel parsed text should match render runs")
	else:
		_expect(runs.size() > 0, "RichTextLabel apply should produce runs even without parsed-text API")
	label.free()


func _verify_source_traps() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_language_rich_text.gd")
	_expect(source.find("draw_string_cached") < 0, "S3 renderer should not use draw_string_cached")
	_expect(source.find("append_text") < 0, "S3 renderer should use literal add_text instead of BBCode append_text")
	_expect(source.find(".add_text(") >= 0, "S3 renderer should use RichTextLabel.add_text for literal content")
	_expect(source.find("ring_core") < 0, "S3 renderer should not read run ring_core_tier")
	_expect(source.find("LingpetLanguageCatalog.get_line") < 0, "S3 renderer should not fetch catalog lines in render helper")
	_expect(source.find("FontFile.new") < 0, "S3 renderer should not create fonts directly")
	_expect(source.find("ProjectResourceLoader.load_font") >= 0, "S3 renderer should load fonts through ProjectResourceLoader")


func _translate_echo(key: String, fallback: String) -> String:
	return fallback if fallback != "" else key


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
