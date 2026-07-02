extends RefCounted

const LingpetDecoder := preload("res://scripts/lingpet/lingpet_decoder.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const LINGPET_FONT_PATH := "res://assets/fonts/LingpetScript-Regular.ttf"
const BODY_FONT_PATH := "res://assets/fonts/NanumSquareB.ttf"
const DEFAULT_FONT_SIZE := 18
const GLYPH_COLOR := Color(0.62, 0.88, 1.0, 0.92)
const DECODED_COLOR := Color(0.96, 0.98, 1.0, 1.0)
const EMOTION_DECODED_COLOR := Color(1.0, 0.82, 0.36, 1.0)
const EMOTION_HIDDEN_COLOR := Color(1.0, 0.82, 0.36, 0.0)
const MISSING_LINGPET_FONT_WARNING := "Missing Lingpet Script font: %s"
const FAILED_LINGPET_FONT_WARNING := "Failed to load Lingpet Script font: %s"
const MISSING_BODY_FONT_WARNING := "Missing Lingpet body font: %s"
const FAILED_BODY_FONT_WARNING := "Failed to load Lingpet body font: %s"

static var _lingpet_font: Font = null
static var _body_font: Font = null


static func reset_font_cache_for_tests() -> void:
	_lingpet_font = null
	_body_font = null


static func get_lingpet_font() -> Font:
	if _lingpet_font == null:
		_lingpet_font = ProjectResourceLoader.load_font(
			LINGPET_FONT_PATH,
			MISSING_LINGPET_FONT_WARNING,
			FAILED_LINGPET_FONT_WARNING
		)
	return _lingpet_font


static func get_body_font() -> Font:
	if _body_font == null:
		_body_font = ProjectResourceLoader.load_font(
			BODY_FONT_PATH,
			MISSING_BODY_FONT_WARNING,
			FAILED_BODY_FONT_WARNING
		)
	return _body_font


static func prewarm_fonts() -> bool:
	return get_lingpet_font() != null and get_body_font() != null


static func build_runs(line: Dictionary, decoder_level: int, translator: Callable = Callable()) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var segments := LingpetDecoder.reveal(line, decoder_level)
	for segment_value in segments:
		if not (segment_value is Dictionary):
			continue
		var segment := segment_value as Dictionary
		var token_kind := str(segment.get("token_kind", ""))
		var tier := int(segment.get("tier", 0))
		var segment_kind := str(segment.get("kind", ""))
		if segment_kind == "emotion":
			var lit := bool(segment.get("lit", segment.get("decoded", false)))
			output.append({
				"kind": "emotion",
				"text": str(segment.get("text", "")),
				"glyph": str(segment.get("glyph", segment.get("text", ""))),
				"decoded": lit,
				"lit": lit,
				"visible": lit,
				"tier": tier,
				"token_kind": token_kind,
				"font_path": LINGPET_FONT_PATH,
				"color": EMOTION_DECODED_COLOR if lit else EMOTION_HIDDEN_COLOR,
				"style": "emotion_lit" if lit else "emotion_hidden",
			})
		elif segment_kind == "ko":
			var key := str(segment.get("key", ""))
			output.append({
				"kind": "ko",
				"text": _translate_key(key, translator),
				"key": key,
				"decoded": true,
				"visible": true,
				"tier": tier,
				"token_kind": token_kind,
				"font_path": BODY_FONT_PATH,
				"color": DECODED_COLOR,
				"style": "decoded",
			})
		else:
			output.append({
				"kind": "glyph",
				"text": str(segment.get("text", "")),
				"decoded": false,
				"visible": true,
				"tier": tier,
				"token_kind": token_kind,
				"font_path": LINGPET_FONT_PATH,
				"color": GLYPH_COLOR,
				"style": "glyph",
			})
	return output


static func apply_runs_to_label(label: RichTextLabel, runs: Array, font_size: int = DEFAULT_FONT_SIZE) -> void:
	if label == null:
		return
	label.clear()
	var first := true
	for run_value in runs:
		if not (run_value is Dictionary):
			continue
		var run := run_value as Dictionary
		if not bool(run.get("visible", true)):
			continue
		if not first:
			label.add_text(" ")
		first = false
		var font := _get_font_for_run(run)
		if font != null:
			label.push_font(font, font_size)
		label.push_color(_get_color(run))
		label.add_text(str(run.get("text", "")))
		label.pop()
		if font != null:
			label.pop()


static func render_line_to_label(
	label: RichTextLabel,
	line: Dictionary,
	decoder_level: int,
	translator: Callable = Callable(),
	font_size: int = DEFAULT_FONT_SIZE
) -> Array[Dictionary]:
	var runs := build_runs(line, decoder_level, translator)
	apply_runs_to_label(label, runs, font_size)
	return runs


static func runs_to_plain_text(runs: Array) -> String:
	var pieces := PackedStringArray()
	for run_value in runs:
		if not (run_value is Dictionary):
			continue
		var run := run_value as Dictionary
		if bool(run.get("visible", true)):
			pieces.append(str(run.get("text", "")))
	return " ".join(pieces)


static func _translate_key(key: String, translator: Callable) -> String:
	if translator.is_valid():
		return str(translator.call(key, key))
	return LanguageSettings.translate(key, key)


static func _get_font_for_run(run: Dictionary) -> Font:
	if str(run.get("font_path", "")) == LINGPET_FONT_PATH:
		return get_lingpet_font()
	return get_body_font()


static func _get_color(run: Dictionary) -> Color:
	var color_value: Variant = run.get("color", DECODED_COLOR)
	if color_value is Color:
		return color_value
	return DECODED_COLOR
