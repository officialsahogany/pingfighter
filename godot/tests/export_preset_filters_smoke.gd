extends SceneTree

const REQUIRED_EXCLUDES := [
	"builds/*",
	"tools/*",
	"tests/*",
	"assets/concepts/*",
	"assets/sprites/characters/*/*_manifest.json",
	"assets/sprites/characters/*/*_pipeline-meta.json",
	"assets/sprites/characters/*/*_atlas.json",
	"assets/sprites/characters/*/*_source*.png*",
	"assets/sprites/characters/*/*_source*.jpeg*",
	"assets/sprites/characters/*/*_source*.jpg*",
	"assets/sprites/characters/*/*_preview.gif*",
	"assets/sprites/characters/*/*_4x2_256_clean.png*",
]


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://export_presets.cfg")
	_expect(source != "", "export preset config should be readable")
	var exclude_filters := _extract_exclude_filters(source)
	_expect(exclude_filters.size() >= 2, "Android and Windows export presets should both declare exclude filters")
	for exclude_filter in exclude_filters:
		for pattern in REQUIRED_EXCLUDES:
			_expect(
				_filter_has_pattern(exclude_filter, pattern),
				"export preset should exclude local-only asset pattern: %s" % pattern
			)

	print("export_preset_filters_smoke: ok")
	quit(0)


func _extract_exclude_filters(source: String) -> Array[String]:
	var filters: Array[String] = []
	for line in source.split("\n"):
		var trimmed := line.strip_edges()
		if not trimmed.begins_with("exclude_filter="):
			continue
		var raw_value := trimmed.substr("exclude_filter=".length()).strip_edges()
		if raw_value.begins_with("\"") and raw_value.ends_with("\"") and raw_value.length() >= 2:
			raw_value = raw_value.substr(1, raw_value.length() - 2)
		filters.append(raw_value)
	return filters


func _filter_has_pattern(exclude_filter: String, pattern: String) -> bool:
	for entry in exclude_filter.split(","):
		if str(entry).strip_edges() == pattern:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
