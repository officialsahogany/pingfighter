extends RefCounted

const MAX_DECODER_LEVEL := 5
const DECODE_PCT_PER_LEVEL := 20


static func clamp_level(level: int) -> int:
	return clampi(level, 0, MAX_DECODER_LEVEL)


static func decode_pct_for_level(level: int) -> int:
	return clampi(clamp_level(level) * DECODE_PCT_PER_LEVEL, 0, 100)


static func reveal(line: Dictionary, decoder_level: int) -> Array:
	var level := clamp_level(decoder_level)
	var output: Array = []
	var tokens_value: Variant = line.get("tokens", [])
	if not (tokens_value is Array):
		return output
	var emotion := str(line.get("emotion", ""))
	for token_value in tokens_value:
		if not (token_value is Dictionary):
			continue
		var token := token_value as Dictionary
		var tier := clampi(int(token.get("tier", MAX_DECODER_LEVEL)), 1, MAX_DECODER_LEVEL)
		var token_kind := str(token.get("kind", ""))
		if token_kind == "emotion":
			var lit := tier <= level
			var glyph := str(token.get("glyph", ""))
			output.append({
				"kind": "emotion",
				"text": glyph if lit else "",
				"glyph": glyph,
				"decoded": lit,
				"lit": lit,
				"visible": lit,
				"tier": tier,
				"token_kind": token_kind,
				"emotion": emotion,
			})
			continue
		if tier <= level:
			output.append({
				"kind": "ko",
				"key": str(token.get("key", "")),
				"decoded": true,
				"tier": tier,
				"token_kind": token_kind,
				"emotion": emotion,
			})
		else:
			output.append({
				"kind": "glyph",
				"text": str(token.get("glyph", "")),
				"decoded": false,
				"tier": tier,
				"token_kind": token_kind,
			})
	return output
