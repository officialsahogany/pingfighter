extends SceneTree

const LingpetDecoder := preload("res://scripts/lingpet/lingpet_decoder.gd")
const LingpetLanguageCatalog := preload("res://scripts/lingpet/lingpet_language_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()


func _run() -> void:
	_verify_catalog_samples_exist()
	_verify_reveal_contract_for_all_samples()

	if _failures.is_empty():
		print("lingpet_reveal_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_samples_exist() -> void:
	var line_ids := LingpetLanguageCatalog.get_line_ids()
	_expect(line_ids.size() >= 2, "S2 catalog should include at least two sample lines")
	for line_id in line_ids:
		var line := LingpetLanguageCatalog.get_line(line_id)
		_expect(not line.is_empty(), "catalog line should be readable: %s" % line_id)
		_expect(str(line.get("id", "")) == line_id, "catalog line id should match lookup key: %s" % line_id)
		_expect(str(line.get("speaker", "")) != "", "catalog line should include speaker: %s" % line_id)
		_expect(str(line.get("emotion", "")) != "", "catalog line should include emotion: %s" % line_id)
		_expect(str(line.get("glyph_text", "")) != "", "catalog line should include glyph_text: %s" % line_id)
		var tokens: Array = line.get("tokens", []) as Array
		_expect(tokens.size() > 0, "catalog line should include tokens: %s" % line_id)
		_expect(_join_token_glyphs(tokens) == str(line.get("glyph_text", "")), "catalog glyph_text should match token glyph order: %s" % line_id)


func _verify_reveal_contract_for_all_samples() -> void:
	for line_id in LingpetLanguageCatalog.get_line_ids():
		var line := LingpetLanguageCatalog.get_line(line_id)
		_verify_tier_gate(line_id, line)
		_verify_monotonic_reveal(line_id, line)
		_verify_boundaries(line_id, line)
		_verify_determinism(line_id, line)
		_verify_decode_ratio(line_id, line)


func _verify_tier_gate(line_id: String, line: Dictionary) -> void:
	var tokens: Array = line.get("tokens", []) as Array
	for level in range(0, LingpetDecoder.MAX_DECODER_LEVEL + 1):
		var revealed := LingpetDecoder.reveal(line, level)
		_expect(revealed.size() == tokens.size(), "reveal should preserve token count for %s level %d" % [line_id, level])
		for index in range(tokens.size()):
			var token: Dictionary = tokens[index] as Dictionary
			var segment: Dictionary = revealed[index] as Dictionary
			var tier := clampi(int(token.get("tier", LingpetDecoder.MAX_DECODER_LEVEL)), 1, LingpetDecoder.MAX_DECODER_LEVEL)
			var should_decode := tier <= level
			_expect(bool(segment.get("decoded", false)) == should_decode, "tier gate mismatch for %s token %d level %d" % [line_id, index, level])
			_expect(int(segment.get("tier", 0)) == tier, "segment should echo token tier for %s token %d" % [line_id, index])
			_expect(str(segment.get("token_kind", "")) == str(token.get("kind", "")), "segment should echo token kind for %s token %d" % [line_id, index])
			if str(token.get("kind", "")) == "emotion":
				_expect(str(segment.get("kind", "")) == "emotion", "emotion segment should stay a sigil token for %s token %d" % [line_id, index])
				_expect(str(segment.get("glyph", "")) == str(token.get("glyph", "")), "emotion segment should preserve glyph for %s token %d" % [line_id, index])
				_expect(bool(segment.get("lit", false)) == should_decode, "emotion segment lit flag should follow tier gate for %s token %d" % [line_id, index])
				_expect(bool(segment.get("visible", true)) == should_decode, "emotion segment visibility should follow tier gate for %s token %d" % [line_id, index])
				_expect(str(segment.get("text", "")) == (str(token.get("glyph", "")) if should_decode else ""), "emotion segment should hide until lit for %s token %d" % [line_id, index])
				_expect(not segment.has("key"), "emotion segment should not expose i18n key for %s token %d" % [line_id, index])
			elif should_decode:
				_expect(str(segment.get("kind", "")) == "ko", "decoded segment should use ko kind for %s token %d" % [line_id, index])
				_expect(str(segment.get("key", "")) == str(token.get("key", "")), "decoded segment should return i18n key for %s token %d" % [line_id, index])
				_expect(not segment.has("text"), "decoded segment should not pre-translate text for %s token %d" % [line_id, index])
				_expect(str(segment.get("emotion", "")) == str(line.get("emotion", "")), "decoded segment should carry line emotion for %s token %d" % [line_id, index])
			else:
				_expect(str(segment.get("kind", "")) == "glyph", "hidden segment should use glyph kind for %s token %d" % [line_id, index])
				_expect(str(segment.get("text", "")) == str(token.get("glyph", "")), "hidden segment should return glyph text for %s token %d" % [line_id, index])
				_expect(not segment.has("key"), "hidden segment should not expose i18n key for %s token %d" % [line_id, index])


func _verify_monotonic_reveal(line_id: String, line: Dictionary) -> void:
	for level in range(0, LingpetDecoder.MAX_DECODER_LEVEL):
		var current_keys := _decoded_key_set(LingpetDecoder.reveal(line, level))
		var next_keys := _decoded_key_set(LingpetDecoder.reveal(line, level + 1))
		for key in current_keys.keys():
			_expect(bool(next_keys.get(key, false)), "decoded key should stay visible for %s level %d key %s" % [line_id, level, key])


func _verify_boundaries(line_id: String, line: Dictionary) -> void:
	var tokens: Array = line.get("tokens", []) as Array
	_expect(_decoded_count(LingpetDecoder.reveal(line, 0)) == 0, "level 0 should decode no tokens for %s" % line_id)
	_expect(_decoded_count(LingpetDecoder.reveal(line, LingpetDecoder.MAX_DECODER_LEVEL)) == tokens.size(), "max level should decode all tokens for %s" % line_id)


func _verify_determinism(line_id: String, line: Dictionary) -> void:
	for level in range(0, LingpetDecoder.MAX_DECODER_LEVEL + 1):
		var first := LingpetDecoder.reveal(line, level)
		var second := LingpetDecoder.reveal(line, level)
		_expect(var_to_str(first) == var_to_str(second), "reveal should be deterministic for %s level %d" % [line_id, level])


func _verify_decode_ratio(line_id: String, line: Dictionary) -> void:
	var tokens: Array = line.get("tokens", []) as Array
	for level in range(0, LingpetDecoder.MAX_DECODER_LEVEL + 1):
		var decoded_count := _decoded_count(LingpetDecoder.reveal(line, level))
		var expected_count := roundi(float(tokens.size()) * float(LingpetDecoder.decode_pct_for_level(level)) / 100.0)
		_expect(abs(decoded_count - expected_count) <= 1, "decoded ratio should track level percent for %s level %d" % [line_id, level])


func _decoded_count(segments: Array) -> int:
	var count := 0
	for segment_value in segments:
		if segment_value is Dictionary and bool((segment_value as Dictionary).get("decoded", false)):
			count += 1
	return count


func _decoded_key_set(segments: Array) -> Dictionary:
	var keys := {}
	for segment_value in segments:
		if not (segment_value is Dictionary):
			continue
		var segment := segment_value as Dictionary
		if bool(segment.get("decoded", false)):
			if segment.has("key"):
				keys[str(segment.get("key", ""))] = true
	return keys


func _join_token_glyphs(tokens: Array) -> String:
	var glyphs := PackedStringArray()
	for token_value in tokens:
		if token_value is Dictionary:
			glyphs.append(str((token_value as Dictionary).get("glyph", "")))
	return " ".join(glyphs)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
