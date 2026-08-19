extends SceneTree

const TOWER_SCRIPT_ROOT := "res://scripts/tower_ascent"
const SHARED_REWARD_RENDERER_PATH := "res://scripts/hud/runtime_perk_overlay_renderer.gd"
const BANNED_TOWER_CURRENCY_TERM := "골드"
const EXEMPT_SEPARATE_CURRENCY_TERMS := ["퍽 골드", "무공 골드"]

var _failures: Array[String] = []


func _init() -> void:
	_verify_detector_counterproofs()
	_verify_tower_player_facing_sources()
	if _failures.is_empty():
		print("tower_currency_display_term_ban_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_detector_counterproofs() -> void:
	var internal_only := 'var gold := 7\nvar balances := {"gold": gold}\n'
	_expect(
		_find_banned_literals(internal_only).is_empty(),
		"internal gold identifiers and dictionary keys must remain exempt"
	)
	var retired_player_copy := 'const PLAYER_COPY := "골드 10"\n'
	_expect(
		_find_banned_literals(retired_player_copy) == ["골드 10"],
		"a restored player-facing tower Gold label must turn the detector RED"
	)
	var separate_currencies := 'const PERK := "퍽 골드"\nconst MUGONG := "무공 골드: 7"\n'
	_expect(
		_find_banned_literals(separate_currencies).is_empty(),
		"perk Gold and Mugong Gold must stay explicit separate-currency exceptions"
	)


func _verify_tower_player_facing_sources() -> void:
	var dir := DirAccess.open(TOWER_SCRIPT_ROOT)
	_expect(dir != null, "tower script root must remain readable")
	if dir == null:
		return
	var internal_gold_token_count := 0
	for file_name in DirAccess.get_files_at(TOWER_SCRIPT_ROOT):
		if not file_name.ends_with(".gd"):
			continue
		var path := "%s/%s" % [TOWER_SCRIPT_ROOT, file_name]
		var source := FileAccess.get_file_as_string(path)
		_expect(not source.is_empty(), "%s must remain readable" % path)
		internal_gold_token_count += source.count("gold")
		for literal in _find_banned_literals(source):
			_failures.append("%s restores banned tower currency copy: %s" % [path, literal])
	var shared_source := FileAccess.get_file_as_string(SHARED_REWARD_RENDERER_PATH)
	_expect(not shared_source.is_empty(), "shared reward renderer must remain readable")
	var reward_surface := _source_slice(
		shared_source,
		"func draw_tower_reward_pick(",
		"func _tower_reward_absorption_by_slot("
	)
	_expect(not reward_surface.is_empty(), "tower reward renderer surface must remain inspectable")
	for literal in _find_banned_literals(reward_surface):
		_failures.append("%s tower reward surface restores banned copy: %s" % [
			SHARED_REWARD_RENDERER_PATH,
			literal,
		])
	_expect(
		internal_gold_token_count > 0,
		"counterproof must exercise real internal gold identifiers while the display ban stays GREEN"
	)


func _find_banned_literals(source: String) -> Array[String]:
	var result: Array[String] = []
	for literal in _quoted_literals(source):
		if not literal.contains(BANNED_TOWER_CURRENCY_TERM):
			continue
		var exempt := false
		for allowed in EXEMPT_SEPARATE_CURRENCY_TERMS:
			if literal.contains(allowed):
				exempt = true
				break
		if not exempt:
			result.append(literal)
	return result


func _quoted_literals(source: String) -> Array[String]:
	var result: Array[String] = []
	var index := 0
	while index < source.length():
		var current := source.substr(index, 1)
		if current == "#":
			var newline := source.find("\n", index)
			index = source.length() if newline < 0 else newline + 1
			continue
		if current != '"' and current != "'":
			index += 1
			continue
		var quote := current
		var literal := ""
		index += 1
		var escaped := false
		while index < source.length():
			current = source.substr(index, 1)
			if escaped:
				literal += current
				escaped = false
			elif current == "\\":
				escaped = true
			elif current == quote:
				break
			else:
				literal += current
			index += 1
		result.append(literal)
		index += 1
	return result


func _source_slice(source: String, start_marker: String, end_marker: String) -> String:
	var start := source.find(start_marker)
	if start < 0:
		return ""
	var finish := source.find(end_marker, start + start_marker.length())
	if finish <= start:
		return ""
	return source.substr(start, finish - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
