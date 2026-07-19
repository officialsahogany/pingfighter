extends RefCounted

const CharacterInfoOverlayTextLineCache := preload("res://scripts/hud/character_info_overlay_text_line_cache.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const AFFINITY_METER_HEIGHT := 8.0
const AFFINITY_HOVER_BAND_HEIGHT := 28.0
const SATIETY_METER_HEIGHT := 8.0
const SATIETY_METER_GAP := 4.0
const SATIETY_WARNING_THRESHOLD := 50
const SATIETY_CRITICAL_THRESHOLD := 20


static func merge_runtime_snapshot(panel_snapshot: Dictionary, runtime_snapshot: Dictionary) -> Dictionary:
	if runtime_snapshot.has("satiety_pct"):
		panel_snapshot["satiety_pct"] = clampi(int(runtime_snapshot.get("satiety_pct", 0)), 0, 100)
	if runtime_snapshot.has("companion_exhausted"):
		panel_snapshot["companion_exhausted"] = bool(runtime_snapshot.get("companion_exhausted", false))
	if runtime_snapshot.has("satiety_exhaustion_ratio"):
		panel_snapshot["satiety_exhaustion_ratio"] = clampf(float(runtime_snapshot.get("satiety_exhaustion_ratio", 0.0)), 0.0, 1.0)
	return panel_snapshot


static func get_strip_state(snapshot: Dictionary) -> Dictionary:
	var has_active_companion := str(snapshot.get("state", "")) == "companion" and str(snapshot.get("pet_id", "")).strip_edges() != ""
	if not has_active_companion:
		return {
			"visible": false,
			"pct": 0,
			"exhausted": false,
			"ratio": 0.0,
			"label": "",
			"value": "",
			"color_key": "hidden",
		}
	var pct := clampi(int(snapshot.get("satiety_pct", 0)), 0, 100)
	var exhausted := bool(snapshot.get("companion_exhausted", false))
	var ratio := clampf(float(snapshot.get("satiety_exhaustion_ratio", 0.0)), 0.0, 1.0)
	var color_key := "normal"
	if exhausted or pct <= SATIETY_CRITICAL_THRESHOLD:
		color_key = "critical"
	elif pct <= SATIETY_WARNING_THRESHOLD:
		color_key = "warning"
	return {
		"visible": true,
		"pct": pct,
		"exhausted": exhausted,
		"ratio": ratio,
		"label": "포만도",
		"value": "탈진 Zzz" if exhausted else "%d%%" % pct,
		"color_key": color_key,
	}


static func get_strip_layout(font: Font, rect: Rect2, satiety_state: Dictionary, ui_text_scale: float) -> Dictionary:
	if not bool(satiety_state.get("visible", false)):
		return {}
	var label_text := str(satiety_state.get("label", ""))
	var strip_y: float = rect.position.y + 18.0 + AFFINITY_METER_HEIGHT + SATIETY_METER_GAP
	var baseline_y: float = strip_y + 8.0
	var meter_w := progress_meter_width(rect)
	var meter_rect := Rect2(rect.position.x, strip_y, meter_w, SATIETY_METER_HEIGHT)
	var annot_x: float = meter_rect.end.x + 8.0
	var label_w: float = _text_size(font, label_text, 9, ui_text_scale).x
	var label_rect := Rect2(annot_x, strip_y - 1.0, label_w, SATIETY_METER_HEIGHT + 3.0)
	var value_x: float = label_rect.end.x + 5.0 * ui_text_scale
	var value_w: float = maxf(10.0, rect.end.x - value_x)
	var value_rect := Rect2(value_x, strip_y - 1.0, value_w, SATIETY_METER_HEIGHT + 3.0)
	return {
		"label_rect": label_rect,
		"meter_rect": meter_rect,
		"value_rect": value_rect,
		"baseline_y": baseline_y,
	}


static func progress_meter_width(rect: Rect2) -> float:
	return clampf(rect.size.x * 0.50, 78.0, maxf(78.0, rect.size.x - 118.0))


static func strip_color(satiety_state: Dictionary, stat_buff_color: Color) -> Color:
	match str(satiety_state.get("color_key", "normal")):
		"critical":
			return Color(1.0, 64.0 / 255.0, 82.0 / 255.0, 0.94)
		"warning":
			return Color(1.0, 206.0 / 255.0, 80.0 / 255.0, 0.92)
	return Color(stat_buff_color.r, stat_buff_color.g, stat_buff_color.b, 0.88)


static func affinity_hover_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position.x, rect.position.y, rect.size.x, AFFINITY_HOVER_BAND_HEIGHT)


static func satiety_hover_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position.x, rect.position.y + AFFINITY_HOVER_BAND_HEIGHT, rect.size.x, maxf(12.0, rect.size.y - AFFINITY_HOVER_BAND_HEIGHT))


static func _text_size(font: Font, text: String, size: int, ui_text_scale: float) -> Vector2:
	if font == null or text.is_empty():
		return Vector2.ZERO
	var visible_text := LanguageSettings.translate_text(text)
	var ui_size := maxi(1, int(round(float(size) * ui_text_scale)))
	return CharacterInfoOverlayTextLineCache.get_string_size_cached(font, visible_text, ui_size)
