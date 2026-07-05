extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
const PremiumPanelFrame := preload("res://scripts/hud/premium_panel_frame.gd")
const CharacterInfoOverlayTextWidthCache := preload("res://scripts/hud/character_info_overlay_text_width_cache.gd")
const CharacterInfoOverlayValueUtils := preload("res://scripts/hud/character_info_overlay_value_utils.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")


static func subtitle(display_name: String, character_type: String) -> String:
	return display_name + "  /  " + CharacterInfoOverlayFormatter.character_type_label(character_type)


static func cached_subtitle(display_name: String, character_type: String, cache: Dictionary) -> String:
	if display_name == str(cache.get("display_name", "")) and character_type == str(cache.get("character_type", "")):
		return str(cache.get("text", ""))
	var text: String = subtitle(display_name, character_type)
	cache["display_name"] = display_name
	cache["character_type"] = character_type
	cache["text"] = text
	return text


static func status_text(pending: int, gold: int, language: String) -> String:
	if language == LanguageSettings.LANGUAGE_ENGLISH:
		return "Choices Waiting " + str(pending) + "   Perk Gold " + str(gold)
	if language == LanguageSettings.LANGUAGE_SPANISH:
		return "Opciones en espera " + str(pending) + "   Oro de perks " + str(gold)
	if language == LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL:
		return "Escolhas pendentes " + str(pending) + "   Ouro de perks " + str(gold)
	if language == LanguageSettings.LANGUAGE_RUSSIAN:
		return "Ожидает выбор " + str(pending) + "   Золото перков " + str(gold)
	if language == LanguageSettings.LANGUAGE_CHINESE:
		return "待选择 " + str(pending) + "   升级金币 " + str(gold)
	if language == LanguageSettings.LANGUAGE_JAPANESE:
		return "選択待ち " + str(pending) + "   パークゴールド " + str(gold)
	return "선택 대기 " + str(pending) + "   퍽 골드 " + str(gold)


static func cached_status_text(pending: int, gold: int, cache: Dictionary) -> String:
	var language := LanguageSettings.get_language()
	if pending == int(cache.get("pending", -1)) and gold == int(cache.get("gold", -1)) and language == str(cache.get("language", "")):
		return str(cache.get("text", ""))
	var text: String = status_text(pending, gold, language)
	cache["pending"] = pending
	cache["gold"] = gold
	cache["language"] = language
	cache["text"] = text
	return text


static func cached_status_width(font: Font, status: String, size: int, cache: Dictionary, text_size_callable: Callable) -> Dictionary:
	return CharacterInfoOverlayTextWidthCache.get_single_width_state(font, status, size, str(cache.get("text", "")), int(cache.get("size", 0)), int(cache.get("font_id", 0)), float(cache.get("width", 0.0)), text_size_callable)


static func draw_header(
	canvas: CanvasItem,
	owner: Object,
	panel_rect: Rect2,
	font: Font,
	registry: Object,
	runtime_state: Object,
	runtime_snapshot_override: Variant,
	character_type_override: String,
	character_runtime: Object,
	subtitle_cache: Dictionary,
	status_text_cache: Dictionary,
	status_width_cache: Dictionary,
	text_dim: Color,
	accent_gold: Color,
	accent_blue: Color,
	class_emblem: Texture2D,
	text_size_callable: Callable,
	draw_text_xy_callable: Callable
) -> Dictionary:
	var accent: Color = accent_blue
	var emblem_offset := 0.0
	if class_emblem != null:
		var emblem_rect := Rect2(panel_rect.position + Vector2(18.0, 8.0), Vector2(56.0, 56.0))
		var emblem_size: Vector2 = class_emblem.get_size()
		if emblem_size.x > 0.0 and emblem_size.y > 0.0:
			var emblem_scale: float = min(emblem_rect.size.x / emblem_size.x, emblem_rect.size.y / emblem_size.y)
			var emblem_dest := Rect2(emblem_rect.get_center() - emblem_size * emblem_scale * 0.5, emblem_size * emblem_scale)
			canvas.draw_texture_rect(class_emblem, emblem_dest, false, Color(1.0, 1.0, 1.0, 0.98))
			emblem_offset = 58.0
	var title_x: float = panel_rect.position.x + 28.0 + emblem_offset
	var title_y: float = panel_rect.position.y + 42.0
	draw_text_xy_callable.call(canvas, font, "캐릭터 정보", title_x, title_y, 28, Color.WHITE)
	var title_size_value: Variant = text_size_callable.call(font, "캐릭터 정보", 28)
	var title_width: float = (title_size_value as Vector2).x if title_size_value is Vector2 else 160.0
	var motif_x: float = title_x + title_width + 14.0
	draw_text_xy_callable.call(canvas, font, "INFO", motif_x, title_y - 1.0, 13, Color(accent.r, accent.g, accent.b, 0.65))
	var motif_size_value: Variant = text_size_callable.call(font, "INFO", 13)
	var motif_width: float = (motif_size_value as Vector2).x if motif_size_value is Vector2 else 34.0
	var character_type: String = character_type_override if character_type_override != "" else CharacterInfoOverlayOwnerState.character_type_from_owner(owner, character_runtime)
	var display_name: String = CharacterInfoOverlayOwnerState.character_display_name_from_owner(owner, character_type)
	var subtitle_text: String = cached_subtitle(display_name, character_type, subtitle_cache)
	# Character name badge capsule (glass pill with a small emblem diamond).
	var subtitle_size_value: Variant = text_size_callable.call(font, subtitle_text, 14)
	var subtitle_width: float = (subtitle_size_value as Vector2).x if subtitle_size_value is Vector2 else 120.0
	var badge_rect := Rect2(Vector2(motif_x + motif_width + 30.0, title_y - 22.0), Vector2(subtitle_width + 52.0, 30.0))
	PremiumPanelFrame.draw_panel(canvas, badge_rect, PremiumPanelFrame.KIND_SLOT, Color(0.28, 0.42, 0.58, 0.32), Color(0.60, 0.78, 0.95, 0.55), 1.0)
	var emblem_center := Vector2(badge_rect.position.x + 18.0, badge_rect.get_center().y)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			emblem_center + Vector2(0.0, -6.0),
			emblem_center + Vector2(4.0, 0.0),
			emblem_center + Vector2(0.0, 6.0),
			emblem_center + Vector2(-4.0, 0.0),
		]),
		Color(accent.r, accent.g, accent.b, 0.9)
	)
	draw_text_xy_callable.call(canvas, font, subtitle_text, badge_rect.position.x + 32.0, badge_rect.get_center().y + 5.0, 14, Color.WHITE)

	# The former top-right "선택 대기 / 퍽 골드" status line is intentionally removed:
	# the top-right corner now hosts the always-visible discard trash can drawn by
	# CharacterInfoOverlayDragController.draw_overlay (original PingFighter parity).
	return {}
