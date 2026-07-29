extends RefCounted

const CharacterInfoOverlayTextLineCache := preload("res://scripts/hud/character_info_overlay_text_line_cache.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const SATIETY_METER_HEIGHT := 8.0
const SATIETY_WARNING_THRESHOLD := 50
const SATIETY_CRITICAL_THRESHOLD := 20


static func merge_runtime_snapshot(panel_snapshot: Dictionary, runtime_snapshot: Dictionary) -> Dictionary:
	if runtime_snapshot.has("duration_pool_pct"):
		panel_snapshot["duration_pool_pct"] = clampi(int(runtime_snapshot.get("duration_pool_pct", 0)), 0, 100)
	elif runtime_snapshot.has("satiety_pct"):
		# Transitional fallback for snapshots produced before the shared-pool swap.
		panel_snapshot["duration_pool_pct"] = clampi(int(runtime_snapshot.get("satiety_pct", 0)), 0, 100)
	if runtime_snapshot.has("guardian_stowed"):
		panel_snapshot["guardian_stowed"] = bool(runtime_snapshot.get("guardian_stowed", false))
	var runtime_pet_id := str(runtime_snapshot.get("pet_id", "")).strip_edges().to_lower()
	var runtime_is_companion := (
		str(runtime_snapshot.get("state", "")).strip_edges().to_lower() == "companion"
		and runtime_pet_id != ""
	)
	var display_snapshot_value: Variant = runtime_snapshot.get("character_info_display_snapshot", {})
	if runtime_is_companion and display_snapshot_value is Dictionary and not (display_snapshot_value as Dictionary).is_empty():
		# This HUD-only payload is deliberately ungated. Public owner keys remain
		# suppressed while stowed, so gameplay consumers still see no active guardian.
		panel_snapshot.merge(display_snapshot_value as Dictionary, true)
	if runtime_is_companion and (
		bool(runtime_snapshot.get("guardian_stowed", false))
		or (display_snapshot_value is Dictionary and not (display_snapshot_value as Dictionary).is_empty())
	):
		# Gameplay owner projection intentionally publishes state=none while stowed so
		# no combat consumer can mistake the guardian for active. The TAB panel instead
		# reads the runtime-owned display channel and restores its roster identity here.
		panel_snapshot["state"] = "companion"
		panel_snapshot["pet_id"] = runtime_pet_id
		if bool(runtime_snapshot.get("guardian_stowed", false)):
			panel_snapshot["title"] = _resolve_stowed_title(panel_snapshot, runtime_pet_id)
			panel_snapshot["subtitle"] = LanguageSettings.translate_text("수납 중")
		else:
			panel_snapshot["subtitle"] = LanguageSettings.translate_text("동행 중")
	return panel_snapshot


static func _resolve_stowed_title(panel_snapshot: Dictionary, pet_id: String) -> String:
	var tabs_value: Variant = panel_snapshot.get("slot_tabs", [])
	if tabs_value is Array:
		for tab_value in tabs_value as Array:
			if not (tab_value is Dictionary):
				continue
			var tab: Dictionary = tab_value as Dictionary
			if str(tab.get("pet_id", "")).strip_edges().to_lower() != pet_id:
				continue
			var tab_name := str(tab.get("name", "")).strip_edges()
			if tab_name != "":
				return tab_name
	return pet_id


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
	var pct := clampi(int(snapshot.get("duration_pool_pct", snapshot.get("satiety_pct", 0))), 0, 100)
	var color_key := "normal"
	if pct <= SATIETY_CRITICAL_THRESHOLD:
		color_key = "critical"
	elif pct <= SATIETY_WARNING_THRESHOLD:
		color_key = "warning"
	return {
		"visible": true,
		"pct": pct,
		"exhausted": false,
		"ratio": 0.0,
		"stowed": bool(snapshot.get("guardian_stowed", false)),
		"label": "지속시간",
		"value": "%d%%" % pct,
		"color_key": color_key,
	}


static func get_strip_layout(font: Font, rect: Rect2, satiety_state: Dictionary, ui_text_scale: float) -> Dictionary:
	if not bool(satiety_state.get("visible", false)):
		return {}
	var label_text := str(satiety_state.get("label", ""))
	var strip_y: float = rect.position.y + 4.0
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


static func satiety_hover_rect(rect: Rect2) -> Rect2:
	return rect


static func _text_size(font: Font, text: String, size: int, ui_text_scale: float) -> Vector2:
	if font == null or text.is_empty():
		return Vector2.ZERO
	var visible_text := LanguageSettings.translate_text(text)
	var ui_size := maxi(1, int(round(float(size) * ui_text_scale)))
	return CharacterInfoOverlayTextLineCache.get_string_size_cached(font, visible_text, ui_size)
