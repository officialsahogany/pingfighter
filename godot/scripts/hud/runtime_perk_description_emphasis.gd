extends RefCounted

# 시작 카드와 보상 카드가 공유하는 설명 수치 강조의 단일 소유자.
# 문장 순서가 로케일마다 달라도 숫자 토큰 자체를 찾아 분할하므로 카탈로그에
# 별도 마크업을 중복 저장하지 않는다.
const NUMERIC_TOKEN_PATTERN := (
	"(?i)(?:[x×]\\s*)?[+\\-−]?\\d+(?:[.,]\\d+)?"
	+ "(?:\\s*(?:%|％|x|×|배|倍|초(?:간)?|秒|msec|ms|sec(?:ond)?s?|"
	+ "seg(?:undo)?s?|сек(?:унд[а-я]*)?|회|번|개|칸|성|s))?"
)

static var _numeric_token_regex: RegEx = null


static func split_segments(text: String) -> Array:
	if text == "":
		return []
	var regex := _get_numeric_token_regex()
	if regex == null:
		return [{"text": text, "emphasized": false}]
	var segments: Array = []
	var cursor := 0
	for match_value in regex.search_all(text):
		var match := match_value as RegExMatch
		var start := match.get_start()
		var end := match.get_end()
		if start > cursor:
			segments.append({"text": text.substr(cursor, start - cursor), "emphasized": false})
		segments.append({"text": text.substr(start, end - start), "emphasized": true})
		cursor = end
	if cursor < text.length():
		segments.append({"text": text.substr(cursor), "emphasized": false})
	if segments.is_empty():
		segments.append({"text": text, "emphasized": false})
	return segments


static func split_lines(lines: Array) -> Array:
	var result: Array = []
	for line_value in lines:
		result.append(split_segments(str(line_value)))
	return result


static func _get_numeric_token_regex() -> RegEx:
	if _numeric_token_regex != null:
		return _numeric_token_regex
	var regex := RegEx.new()
	if regex.compile(NUMERIC_TOKEN_PATTERN) != OK:
		return null
	_numeric_token_regex = regex
	return _numeric_token_regex
