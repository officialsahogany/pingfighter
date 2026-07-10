extends RefCounted


static func extract(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := _next_top_level_function_start(source, start + signature.length())
	if next < 0:
		next = source.length()
	return source.substr(start, next - start)


static func _next_top_level_function_start(source: String, search_from: int) -> int:
	var func_index := source.find("\nfunc ", search_from)
	var static_func_index := source.find("\nstatic func ", search_from)
	var next := _min_non_negative_index(func_index, static_func_index)
	if next < 0:
		return -1
	var function_line_start := next + 1
	return _rewind_leading_source_contract_lines(source, function_line_start, search_from)


static func _rewind_leading_source_contract_lines(source: String, function_line_start: int, search_floor: int) -> int:
	var boundary := function_line_start
	var line_start := _previous_line_start(source, boundary - 2)
	while line_start >= search_floor:
		var line_text := source.substr(line_start, boundary - line_start).strip_edges()
		if line_text == "" or line_text.begins_with("#") or line_text.begins_with("@"):
			boundary = line_start
			if line_start <= 0:
				return boundary
			line_start = _previous_line_start(source, boundary - 2)
			continue
		break
	return boundary


static func _previous_line_start(source: String, before_index: int) -> int:
	var clamped := clampi(before_index, 0, max(source.length() - 1, 0))
	var previous_newline := source.rfind("\n", clamped)
	if previous_newline < 0:
		return 0
	return previous_newline + 1


static func _min_non_negative_index(a: int, b: int) -> int:
	if a < 0:
		return b
	if b < 0:
		return a
	return min(a, b)
