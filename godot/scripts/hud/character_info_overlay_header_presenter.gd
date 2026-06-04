extends RefCounted

const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")
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
	text_size_callable: Callable,
	draw_text_xy_callable: Callable
) -> Dictionary:
	var title_x: float = panel_rect.position.x + 26.0
	var title_y: float = panel_rect.position.y + 42.0
	draw_text_xy_callable.call(canvas, font, "캐릭터 정보", title_x, title_y, 28, Color.WHITE)
	var character_type: String = character_type_override if character_type_override != "" else CharacterInfoOverlayOwnerState.character_type_from_owner(owner, character_runtime)
	var display_name: String = CharacterInfoOverlayOwnerState.character_display_name_from_owner(owner, character_type)
	var subtitle_text: String = cached_subtitle(display_name, character_type, subtitle_cache)
	draw_text_xy_callable.call(canvas, font, subtitle_text, title_x, title_y + 24.0, 14, text_dim)

	var effective_runtime_state: Object = runtime_state if runtime_state != null else CharacterInfoOverlayOwnerState.get_instance(registry, "runtime_perk_state")
	var snapshot: Dictionary = runtime_snapshot_override if runtime_snapshot_override is Dictionary else {}
	if not (runtime_snapshot_override is Dictionary) and effective_runtime_state != null and effective_runtime_state.has_method("get_snapshot"):
		snapshot = effective_runtime_state.get_snapshot()
	var pending: int = int(snapshot.get("pending_skill_choices", 0))
	if not snapshot.has("pending_skill_choices"):
		pending = int(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "runtime_perk_pending_choices", 0))
	var gold: int = int(snapshot.get("gold_from_perks", 0))
	if not snapshot.has("gold_from_perks"):
		gold = int(CharacterInfoOverlayValueUtils.safe_owner_get(owner, "runtime_perk_gold", 0))
	var status: String = cached_status_text(pending, gold, status_text_cache)
	var width_state: Dictionary = cached_status_width(font, status, 14, status_width_cache, text_size_callable)
	var status_width: float = float(width_state.get("width", 0.0))
	draw_text_xy_callable.call(canvas, font, status, panel_rect.end.x - status_width - 26.0, title_y + 16.0, 14, accent_gold)
	return width_state
