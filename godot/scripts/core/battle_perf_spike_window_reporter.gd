extends RefCounted

const DRAW_SHELL_TRIGGER_MSEC := 10.0
const DRAW_FRAME_TRIGGER_MSEC := 8.0
const PLAYFIELD_TRIGGER_MSEC := 4.0
const FOCUS_TRIGGER_MSEC := 3.0
const ACTIVE_ITEM_TRIGGER_MSEC := 1.0
const MAX_HOT_LIMIT := 18
const FOCUS_LIMIT := 10
const FOCUS_LABELS := [
	"01.actors.total",
	"29.active_item_field",
	"34.scoreboard_overlay",
	"stage1.pillar_ui.total",
	"stage1.pillar_ui.gauge_orb",
	"stage1.pillar_ui.player_dash",
	"stage1.pillar_ui.boss_dash",
	"stage1.pillar_ui.commando_selector",
]


func build(
	samples: Dictionary,
	counter_summary: String,
	playfield_hot_prefixes: Array,
	stage_hot_prefixes: Array
) -> String:
	if not _should_emit(samples):
		return ""
	return "trigger=%s | max_hot=%s | focus=%s | counters=%s" % [
		_build_trigger_summary(samples),
		_build_max_summary(samples, playfield_hot_prefixes, stage_hot_prefixes, MAX_HOT_LIMIT),
		_build_focus_summary(samples),
		counter_summary,
	]


func _should_emit(samples: Dictionary) -> bool:
	if _sample_max_ms(samples, "draw.shell.frame_controller") >= DRAW_SHELL_TRIGGER_MSEC:
		return true
	if _sample_max_ms(samples, "draw.shell.total") >= DRAW_SHELL_TRIGGER_MSEC:
		return true
	if _sample_max_ms(samples, "draw.frame.total") >= DRAW_FRAME_TRIGGER_MSEC:
		return true
	if _sample_max_ms(samples, "draw.frame.battle_scene") >= DRAW_FRAME_TRIGGER_MSEC:
		return true
	if _sample_max_ms(samples, "00.playfield_frame_total") >= PLAYFIELD_TRIGGER_MSEC:
		return true
	for key_value in samples.keys():
		var label := str(key_value)
		var max_ms: float = _sample_max_ms(samples, label)
		if _is_active_item_label(label) and max_ms >= ACTIVE_ITEM_TRIGGER_MSEC:
			return true
		if _is_focus_label(label) and max_ms >= FOCUS_TRIGGER_MSEC:
			return true
	return false


func _build_trigger_summary(samples: Dictionary) -> String:
	var parts: Array[String] = []
	var seen: Dictionary = {}
	_append_trigger(parts, seen, samples, "draw.shell.frame_controller", DRAW_SHELL_TRIGGER_MSEC)
	_append_trigger(parts, seen, samples, "draw.shell.total", DRAW_SHELL_TRIGGER_MSEC)
	_append_trigger(parts, seen, samples, "draw.frame.total", DRAW_FRAME_TRIGGER_MSEC)
	_append_trigger(parts, seen, samples, "draw.frame.battle_scene", DRAW_FRAME_TRIGGER_MSEC)
	_append_trigger(parts, seen, samples, "00.playfield_frame_total", PLAYFIELD_TRIGGER_MSEC)
	for key_value in samples.keys():
		var label := str(key_value)
		if seen.has(label):
			continue
		var threshold: float = 0.0
		if _is_active_item_label(label):
			threshold = ACTIVE_ITEM_TRIGGER_MSEC
		elif _is_focus_label(label):
			threshold = FOCUS_TRIGGER_MSEC
		if threshold <= 0.0:
			continue
		_append_trigger(parts, seen, samples, label, threshold)
	if parts.is_empty():
		return "-"
	return "; ".join(parts)


func _append_trigger(
	parts: Array[String],
	seen: Dictionary,
	samples: Dictionary,
	label: String,
	threshold_ms: float
) -> void:
	if _sample_max_ms(samples, label) < threshold_ms:
		return
	var formatted: String = _format_entry(samples, label)
	if formatted == "":
		return
	seen[label] = true
	parts.append(formatted)


func _build_max_summary(
	samples: Dictionary,
	playfield_hot_prefixes: Array,
	stage_hot_prefixes: Array,
	limit: int
) -> String:
	var entries: Array[Dictionary] = []
	for key_value in samples.keys():
		var label := str(key_value)
		if not _is_hot_label(label, playfield_hot_prefixes, stage_hot_prefixes):
			continue
		entries.append(_sample_entry(samples, label))
	if entries.is_empty():
		return "-"
	entries.sort_custom(Callable(self, "_sort_entry_desc"))
	var parts: Array[String] = []
	var entry_limit: int = min(entries.size(), limit)
	for index in range(entry_limit):
		parts.append(_format_entry_from_dict(entries[index]))
	return "; ".join(parts)


func _build_focus_summary(samples: Dictionary) -> String:
	var entries: Array[Dictionary] = []
	for key_value in samples.keys():
		var label := str(key_value)
		if not _is_focus_label(label):
			continue
		var entry: Dictionary = _sample_entry(samples, label)
		if float(entry.get("max_ms", 0.0)) <= 0.0:
			continue
		entries.append(entry)
	if entries.is_empty():
		return "-"
	entries.sort_custom(Callable(self, "_sort_entry_desc"))
	var parts: Array[String] = []
	var limit: int = min(entries.size(), FOCUS_LIMIT)
	for index in range(limit):
		parts.append(_format_entry_from_dict(entries[index]))
	return "; ".join(parts)


func _sample_entry(samples: Dictionary, label: String) -> Dictionary:
	var sample: Dictionary = samples.get(label, {})
	var count: int = max(1, int(sample.get("count", 0)))
	var total_usec: int = int(sample.get("total_usec", 0))
	var max_usec: int = int(sample.get("max_usec", 0))
	return {
		"label": label,
		"avg_ms": float(total_usec) / float(count) / 1000.0,
		"max_ms": float(max_usec) / 1000.0,
		"count": count,
	}


func _sample_max_ms(samples: Dictionary, label: String) -> float:
	var sample: Dictionary = samples.get(label, {})
	return float(int(sample.get("max_usec", 0))) / 1000.0


func _format_entry(samples: Dictionary, label: String) -> String:
	if not samples.has(label):
		return ""
	return _format_entry_from_dict(_sample_entry(samples, label))


func _format_entry_from_dict(entry: Dictionary) -> String:
	return "%s=%.2f/%.2fms(n%d)" % [
		str(entry.get("label", "")),
		float(entry.get("avg_ms", 0.0)),
		float(entry.get("max_ms", 0.0)),
		int(entry.get("count", 0)),
	]


func _sort_entry_desc(a: Dictionary, b: Dictionary) -> bool:
	var a_max: float = float(a.get("max_ms", 0.0))
	var b_max: float = float(b.get("max_ms", 0.0))
	if not is_equal_approx(a_max, b_max):
		return a_max > b_max
	return float(a.get("avg_ms", 0.0)) > float(b.get("avg_ms", 0.0))


func _is_hot_label(label: String, playfield_hot_prefixes: Array, stage_hot_prefixes: Array) -> bool:
	if label.ends_with(".delta"):
		return false
	if label in [
		"physics.shell.total",
		"physics.frame.total",
		"process.shell.total",
		"process.frame.total",
	]:
		return false
	if label.begins_with("draw."):
		return true
	if _has_any_prefix(label, playfield_hot_prefixes):
		return true
	if _has_any_prefix(label, stage_hot_prefixes):
		return true
	if label.begins_with("active_item."):
		return true
	if label.begins_with("mythic."):
		return true
	if label.begins_with("ball.visual."):
		return true
	if label.begins_with("context."):
		return true
	return false


func _is_focus_label(label: String) -> bool:
	if _is_active_item_label(label):
		return true
	for focus_label in FOCUS_LABELS:
		if label == str(focus_label):
			return true
	return false


func _is_active_item_label(label: String) -> bool:
	return label == "29.active_item_field" or label.begins_with("active_item.")


func _has_any_prefix(label: String, prefixes: Array) -> bool:
	for prefix_value in prefixes:
		if label.begins_with(str(prefix_value)):
			return true
	return false
