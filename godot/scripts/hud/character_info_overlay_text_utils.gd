extends RefCounted


static func wrap_text_to_width_cached(
	font: Font,
	text: String,
	size: int,
	size_key: int,
	max_width: float,
	max_lines: int,
	cache: Dictionary,
	fast_text: String,
	fast_size: int,
	fast_width: int,
	fast_max_lines: int,
	fast_lines: Array,
	text_size_callable: Callable,
	cache_limit: int
) -> Dictionary:
	var safe_width: float = max(1.0, max_width)
	var max_width_key: int = int(round(safe_width))
	if text == fast_text and size_key == fast_size and max_width_key == fast_width and max_lines == fast_max_lines:
		return _wrapped_text_state(fast_lines, fast_text, fast_size, fast_width, fast_max_lines)
	var cache_key := "%d:%d:%d:%s" % [size_key, max_width_key, max_lines, text]
	if cache.has(cache_key):
		var cached_lines: Variant = cache[cache_key]
		if cached_lines is Array:
			return _wrapped_text_state(cached_lines, text, size_key, max_width_key, max_lines)
		cache.erase(cache_key)
	var lines: Array = []
	for paragraph_value in text.split("\n"):
		append_wrapped_paragraph_lines(lines, str(paragraph_value).strip_edges(), font, size, safe_width, max_lines, text_size_callable)
		if lines.size() >= max_lines:
			return store_wrapped_text_lines(cache_key, text, size_key, max_width_key, max_lines, lines, cache, cache_limit)
	while lines.size() > max_lines:
		lines.pop_back()
	return store_wrapped_text_lines(cache_key, text, size_key, max_width_key, max_lines, lines, cache, cache_limit)


static func store_wrapped_text_lines(cache_key: String, text: String, size_key: int, max_width_key: int, max_lines: int, lines: Array, cache: Dictionary, cache_limit: int) -> Dictionary:
	if cache.size() >= cache_limit:
		cache.clear()
	cache[cache_key] = lines
	return _wrapped_text_state(lines, text, size_key, max_width_key, max_lines)


static func _wrapped_text_state(lines: Array, fast_text: String, fast_size: int, fast_width: int, fast_max_lines: int) -> Dictionary:
	return {
		"lines": lines,
		"fast_text": fast_text,
		"fast_size": fast_size,
		"fast_width": fast_width,
		"fast_max_lines": fast_max_lines,
	}


static func build_overlay_wrapped_text(
	target: Object,
	font: Font,
	text: String,
	size: int,
	size_key: int,
	max_width: float,
	max_lines: int,
	cache: Dictionary,
	fast_text: String,
	fast_size: int,
	fast_width: int,
	fast_max_lines: int,
	fast_lines: Array,
	text_size_callable: Callable,
	cache_limit: int
) -> Array:
	var state: Dictionary = wrap_text_to_width_cached(font, text, size, size_key, max_width, max_lines, cache, fast_text, fast_size, fast_width, fast_max_lines, fast_lines, text_size_callable, cache_limit)
	target.set("_wrap_text_fast_text", str(state.get("fast_text", fast_text)))
	target.set("_wrap_text_fast_size", int(state.get("fast_size", fast_size)))
	target.set("_wrap_text_fast_width", int(state.get("fast_width", fast_width)))
	target.set("_wrap_text_fast_max_lines", int(state.get("fast_max_lines", fast_max_lines)))
	var lines: Array = _get_array(state.get("lines", []))
	target.set("_wrap_text_fast_lines", lines)
	return lines


static func append_wrapped_paragraph_lines(lines: Array, paragraph: String, font: Font, size: int, max_width: float, max_lines: int, text_size_callable: Callable) -> void:
	if paragraph == "":
		return
	var words: PackedStringArray = paragraph.split(" ", false)
	var line := ""
	for word_value in words:
		var word: String = str(word_value)
		var candidate := word if line == "" else line + " " + word
		if measured_text_width(text_size_callable, font, candidate, size) <= max_width:
			line = candidate
			continue
		if line != "":
			lines.append(line)
			if lines.size() >= max_lines:
				return
			line = ""
		if measured_text_width(text_size_callable, font, word, size) <= max_width:
			line = word
			continue
		var chunks: Array = split_unbroken_text_to_width(font, word, size, max_width, text_size_callable)
		for chunk in chunks:
			lines.append(str(chunk))
			if lines.size() >= max_lines:
				return
	if line != "" and lines.size() < max_lines:
		lines.append(line)


static func split_unbroken_text_to_width(font: Font, text: String, size: int, max_width: float, text_size_callable: Callable) -> Array:
	var chunks: Array = []
	var chunk := ""
	for i in range(text.length()):
		var next_character: String = text.substr(i, 1)
		var candidate := chunk + next_character
		if chunk == "" or measured_text_width(text_size_callable, font, candidate, size) <= max_width:
			chunk = candidate
			continue
		chunks.append(chunk)
		chunk = next_character
	if chunk != "":
		chunks.append(chunk)
	return chunks


static func refresh_tooltip_entry_lines(
	font: Font,
	entries: Array,
	size: int,
	max_width: float,
	max_lines: int,
	current_entries_hash: int,
	current_size: int,
	current_width: int,
	current_max_lines: int,
	line_cache: Array,
	line_dict_cache: Array,
	text_cache: Array[String],
	color_cache: Array[Color],
	wrap_text_callable: Callable,
	accent_gold: Color
) -> Dictionary:
	if entries.is_empty() or max_lines <= 0:
		return _tooltip_entry_line_state([], current_entries_hash, current_size, current_width, current_max_lines)
	var max_width_key: int = int(round(max_width))
	var entries_hash: int = hash(entries)
	if entries_hash == current_entries_hash and size == current_size and max_width_key == current_width and max_lines == current_max_lines and text_cache.size() == line_cache.size() and color_cache.size() == line_cache.size():
		return _tooltip_entry_line_state(line_cache, current_entries_hash, current_size, current_width, current_max_lines)
	line_cache.clear()
	text_cache.clear()
	color_cache.clear()
	var result: Array = line_cache
	for entry_value in entries:
		if result.size() >= max_lines:
			break
		var entry: Dictionary = _get_dict(entry_value)
		var text: String = str(entry.get("text", entry_value))
		if text == "":
			continue
		var color: Color = _get_color(entry.get("color", accent_gold))
		var wrapped: Array = _get_array(wrap_text_callable.call(font, text, size, max_width, max(1, max_lines - result.size())))
		for line in wrapped:
			var line_text: String = str(line)
			var line_entry: Dictionary = tooltip_entry_line_dict(line_dict_cache, result.size())
			line_entry["text"] = line_text
			line_entry["color"] = color
			# 삭제 흉터의 렌더러 소유 취소선 메타를 래핑을 통과해 보존한다
			# (U+0336 결합 글리프는 폰트 미지원 — 명시 세그먼트로 그린다).
			if bool(entry.get("strikethrough", false)):
				line_entry["strikethrough"] = true
			text_cache.append(line_text)
			color_cache.append(color)
			result.append(line_entry)
			if result.size() >= max_lines:
				break
	return _tooltip_entry_line_state(result, entries_hash, size, max_width_key, max_lines)


static func tooltip_entry_line_dict(line_dict_cache: Array, index: int) -> Dictionary:
	while line_dict_cache.size() <= index:
		line_dict_cache.append({})
	var data: Dictionary = line_dict_cache[index]
	data.clear()
	return data


static func _tooltip_entry_line_state(lines: Array, entries_hash: int, size: int, width: int, max_lines: int) -> Dictionary:
	return {
		"lines": lines,
		"entries_hash": entries_hash,
		"size": size,
		"width": width,
		"max_lines": max_lines,
	}


static func build_overlay_tooltip_entry_lines(
	target: Object,
	font: Font,
	entries: Array,
	size: int,
	max_width: float,
	max_lines: int,
	current_entries_hash: int,
	current_size: int,
	current_width: int,
	current_max_lines: int,
	line_cache: Array,
	line_dict_cache: Array,
	text_cache: Array[String],
	color_cache: Array[Color],
	wrap_text_callable: Callable,
	accent_gold: Color
) -> Array:
	var state: Dictionary = refresh_tooltip_entry_lines(font, entries, size, max_width, max_lines, current_entries_hash, current_size, current_width, current_max_lines, line_cache, line_dict_cache, text_cache, color_cache, wrap_text_callable, accent_gold)
	target.set("_tooltip_entry_lines_cache_entries_hash", int(state.get("entries_hash", current_entries_hash)))
	target.set("_tooltip_entry_lines_cache_size", int(state.get("size", current_size)))
	target.set("_tooltip_entry_lines_cache_width", int(state.get("width", current_width)))
	target.set("_tooltip_entry_lines_cache_max_lines", int(state.get("max_lines", current_max_lines)))
	return _get_array(state.get("lines", []))


static func measured_text_width(text_size_callable: Callable, font: Font, text: String, size: int) -> float:
	var measured: Variant = text_size_callable.call(font, text, size)
	return (measured as Vector2).x if measured is Vector2 else 0.0


static func _get_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


static func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE
