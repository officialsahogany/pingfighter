extends RefCounted

const LINE_MARIBO_GREET_ARRIVE := "lingpet.language.maribo.greet_arrive"
const LINE_MARIBO_MEAL_CHECK := "lingpet.language.maribo.meal_check"
const LINE_GENERIC_WARM_1 := "lingpet.language.generic.warm.1"
const LINE_GENERIC_CURIOUS_1 := "lingpet.language.generic.curious.1"
const LINE_GENERIC_URGENT_1 := "lingpet.language.generic.urgent.1"
const LINE_GENERIC_SAD_1 := "lingpet.language.generic.sad.1"
const LINE_GENERIC_NEUTRAL_1 := "lingpet.language.generic.neutral.1"

const LINE_IDS := [
	LINE_MARIBO_GREET_ARRIVE,
	LINE_MARIBO_MEAL_CHECK,
	LINE_GENERIC_WARM_1,
	LINE_GENERIC_CURIOUS_1,
	LINE_GENERIC_URGENT_1,
	LINE_GENERIC_SAD_1,
	LINE_GENERIC_NEUTRAL_1,
]

const GENERIC_LINE_IDS_BY_EMOTION := {
	"warm": [LINE_GENERIC_WARM_1],
	"curious": [LINE_GENERIC_CURIOUS_1],
	"urgent": [LINE_GENERIC_URGENT_1],
	"sad": [LINE_GENERIC_SAD_1],
	"neutral": [LINE_GENERIC_NEUTRAL_1],
}

const LINES := {
	LINE_MARIBO_GREET_ARRIVE: {
		"id": LINE_MARIBO_GREET_ARRIVE,
		"speaker": "maribo",
		"emotion": "warm",
		"glyph_text": "tu toho na langa *",
		"tokens": [
			{"key": "lingpet.language.maribo.greet_arrive.token.you", "glyph": "tu", "tier": 1, "kind": "root"},
			{"key": "lingpet.language.maribo.greet_arrive.token.arrived", "glyph": "toho", "tier": 3, "kind": "verb"},
			{"key": "lingpet.language.maribo.greet_arrive.token.to_me", "glyph": "na", "tier": 2, "kind": "particle"},
			{"key": "lingpet.language.maribo.greet_arrive.token.together", "glyph": "langa", "tier": 4, "kind": "loop"},
			{"key": "lingpet.language.maribo.greet_arrive.token.warmth", "glyph": "*", "tier": 5, "kind": "emotion"},
		],
	},
	LINE_MARIBO_MEAL_CHECK: {
		"id": LINE_MARIBO_MEAL_CHECK,
		"speaker": "maribo",
		"emotion": "curious",
		"glyph_text": "komotha tu pala =ne *",
		"tokens": [
			{"key": "lingpet.language.maribo.meal_check.token.ate", "glyph": "komotha", "tier": 3, "kind": "verb"},
			{"key": "lingpet.language.maribo.meal_check.token.you", "glyph": "tu", "tier": 1, "kind": "root"},
			{"key": "lingpet.language.maribo.meal_check.token.rice", "glyph": "pala", "tier": 2, "kind": "noun"},
			{"key": "lingpet.language.maribo.meal_check.token.question", "glyph": "=ne", "tier": 4, "kind": "particle"},
			{"key": "lingpet.language.maribo.meal_check.token.care", "glyph": "*", "tier": 5, "kind": "emotion"},
		],
	},
	LINE_GENERIC_WARM_1: {
		"id": LINE_GENERIC_WARM_1,
		"speaker": "generic",
		"emotion": "warm",
		"glyph_text": "mio naro kora lumi *",
		"tokens": [
			{"key": "lingpet.language.generic.warm.1.token.with_you", "glyph": "mio", "tier": 3, "kind": "root"},
			{"key": "lingpet.language.generic.warm.1.token.when_here", "glyph": "naro", "tier": 1, "kind": "time"},
			{"key": "lingpet.language.generic.warm.1.token.core", "glyph": "kora", "tier": 4, "kind": "noun"},
			{"key": "lingpet.language.generic.warm.1.token.warm", "glyph": "lumi", "tier": 2, "kind": "emotion_word"},
			{"key": "lingpet.language.generic.warm.1.token.heart", "glyph": "*", "tier": 5, "kind": "emotion"},
		],
	},
	LINE_GENERIC_CURIOUS_1: {
		"id": LINE_GENERIC_CURIOUS_1,
		"speaker": "generic",
		"emotion": "curious",
		"glyph_text": "tomo pala sena miki *",
		"tokens": [
			{"key": "lingpet.language.generic.curious.1.token.today", "glyph": "tomo", "tier": 3, "kind": "time"},
			{"key": "lingpet.language.generic.curious.1.token.ball", "glyph": "pala", "tier": 1, "kind": "noun"},
			{"key": "lingpet.language.generic.curious.1.token.what", "glyph": "sena", "tier": 4, "kind": "question"},
			{"key": "lingpet.language.generic.curious.1.token.scent", "glyph": "miki", "tier": 2, "kind": "sense"},
			{"key": "lingpet.language.generic.curious.1.token.spark", "glyph": "*", "tier": 5, "kind": "emotion"},
		],
	},
	LINE_GENERIC_URGENT_1: {
		"id": LINE_GENERIC_URGENT_1,
		"speaker": "generic",
		"emotion": "urgent",
		"glyph_text": "lena suro daka chiri *",
		"tokens": [
			{"key": "lingpet.language.generic.urgent.1.token.left", "glyph": "lena", "tier": 3, "kind": "direction"},
			{"key": "lingpet.language.generic.urgent.1.token.current", "glyph": "suro", "tier": 1, "kind": "field"},
			{"key": "lingpet.language.generic.urgent.1.token.shaking", "glyph": "daka", "tier": 4, "kind": "verb"},
			{"key": "lingpet.language.generic.urgent.1.token.careful", "glyph": "chiri", "tier": 2, "kind": "warning"},
			{"key": "lingpet.language.generic.urgent.1.token.flash", "glyph": "*", "tier": 5, "kind": "emotion"},
		],
	},
	LINE_GENERIC_SAD_1: {
		"id": LINE_GENERIC_SAD_1,
		"speaker": "generic",
		"emotion": "sad",
		"glyph_text": "noku ari tu hila *",
		"tokens": [
			{"key": "lingpet.language.generic.sad.1.token.dark", "glyph": "noku", "tier": 3, "kind": "mood"},
			{"key": "lingpet.language.generic.sad.1.token.your", "glyph": "ari", "tier": 1, "kind": "root"},
			{"key": "lingpet.language.generic.sad.1.token.light", "glyph": "tu", "tier": 4, "kind": "noun"},
			{"key": "lingpet.language.generic.sad.1.token.see", "glyph": "hila", "tier": 2, "kind": "verb"},
			{"key": "lingpet.language.generic.sad.1.token.ember", "glyph": "*", "tier": 5, "kind": "emotion"},
		],
	},
	LINE_GENERIC_NEUTRAL_1: {
		"id": LINE_GENERIC_NEUTRAL_1,
		"speaker": "generic",
		"emotion": "neutral",
		"glyph_text": "na ena moru waka *",
		"tokens": [
			{"key": "lingpet.language.generic.neutral.1.token.i", "glyph": "na", "tier": 3, "kind": "root"},
			{"key": "lingpet.language.generic.neutral.1.token.here", "glyph": "ena", "tier": 1, "kind": "place"},
			{"key": "lingpet.language.generic.neutral.1.token.small_circle", "glyph": "moru", "tier": 4, "kind": "shape"},
			{"key": "lingpet.language.generic.neutral.1.token.walk", "glyph": "waka", "tier": 2, "kind": "verb"},
			{"key": "lingpet.language.generic.neutral.1.token.dot", "glyph": "*", "tier": 5, "kind": "emotion"},
		],
	},
}


static func get_line_ids() -> Array[String]:
	var ids: Array[String] = []
	for line_id in LINE_IDS:
		ids.append(str(line_id))
	return ids


static func has_line(line_id: String) -> bool:
	return LINES.has(line_id)


static func get_line(line_id: String) -> Dictionary:
	var line_value: Variant = LINES.get(line_id, {})
	if line_value is Dictionary:
		return (line_value as Dictionary).duplicate(true)
	return {}


static func get_lines_for_speaker(speaker: String) -> Array[Dictionary]:
	var normalized_speaker := speaker.strip_edges().to_lower()
	var output: Array[Dictionary] = []
	for line_id in LINE_IDS:
		var line := get_line(str(line_id))
		if str(line.get("speaker", "")).strip_edges().to_lower() == normalized_speaker:
			output.append(line)
	return output


static func get_generic_lines(emotion: String = "") -> Array[Dictionary]:
	var normalized_emotion := emotion.strip_edges().to_lower()
	var line_ids: Array = []
	if normalized_emotion != "" and GENERIC_LINE_IDS_BY_EMOTION.has(normalized_emotion):
		line_ids = GENERIC_LINE_IDS_BY_EMOTION.get(normalized_emotion, []) as Array
	else:
		for emotion_key in GENERIC_LINE_IDS_BY_EMOTION:
			for line_id in GENERIC_LINE_IDS_BY_EMOTION.get(emotion_key, []):
				line_ids.append(str(line_id))
	var output: Array[Dictionary] = []
	for line_id in line_ids:
		var line := get_line(str(line_id))
		if not line.is_empty():
			output.append(line)
	return output


static func get_random_generic_line(emotion: String = "", rng: RandomNumberGenerator = null) -> Dictionary:
	var lines := get_generic_lines(emotion)
	if lines.is_empty():
		return {}
	var index := 0
	if rng != null:
		index = rng.randi_range(0, lines.size() - 1)
	return (lines[index] as Dictionary).duplicate(true)
