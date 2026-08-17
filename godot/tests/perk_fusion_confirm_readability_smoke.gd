extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkFusionLocalization := preload("res://scripts/characters/perk_fusion_localization.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkDisplayProjectionState := preload("res://scripts/characters/runtime_perk_display_projection_state.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var runtime_state := RuntimePerkState.new()
	runtime_state.runtime_skill_levels = {
		"sensor": 5,
		"master": 5,
	}
	var snapshot: Dictionary = RuntimePerkDisplayProjectionState.new().merge_perk_fusion_modal_preview(
		runtime_state,
		{
			"phase": "confirm",
			"selected_source_ids": ["sensor", "master"],
		},
		RuntimePerkCatalog.new()
	)
	var master_preview := _find_source_preview(snapshot, "master")
	var sensor_preview := _find_source_preview(snapshot, "sensor")
	_expect(int(master_preview.get("base_level", 0)) == 5, "confirm preview should expose the source's invested level")
	_expect(int(master_preview.get("effective_level", 0)) == 5, "confirm preview should expose the source's effective level")
	_expect(_option_polarity(sensor_preview, "auto_dash_cooldown_sec") == "reverse", "preview data should retain lower-is-better polarity without exposing it as card jargon")

	var option_lines: Array[String] = []
	for option_value: Variant in master_preview.get("options", []):
		var option: Dictionary = option_value if option_value is Dictionary else {}
		var option_key := str(option.get("option_key", ""))
		_expect(not option_key.is_empty(), "confirm preview must publish the renderer's canonical option key")
		_expect(option.has("polarity"), "confirm preview should retain option polarity for fusion calculations")
		option_lines.append(PerkFusionLocalization.option_preview(
			option_key,
			option.get("value", 0.0),
			str(option.get("polarity", "forward"))
		))

	var option_text := "\n".join(option_lines)
	_expect(option_lines.size() == 3, "Master confirm card should show all three current effects")
	_expect(option_text.contains("아이템 재사용 감소: 12%"), "Master confirm card should name and unit its cooldown reduction")
	_expect(option_text.contains("벽 길이: 45%"), "Master confirm card should name and unit its wall length")
	_expect(option_text.contains("벽 생성량: 330%"), "Master confirm card should name and unit its wall spawn bonus")
	_expect(not option_text.contains("Option") and not option_text.contains("option"), "confirm card must not leak a generic or raw option name")
	_expect(not option_text.contains("높을수록 유리") and not option_text.contains("낮을수록 유리"), "confirm card should omit unexplained direction jargon")

	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("perk_fusion_confirm_readability_smoke: ok")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _find_source_preview(snapshot: Dictionary, perk_id: String) -> Dictionary:
	for preview_value: Variant in snapshot.get("source_previews", []):
		var preview: Dictionary = preview_value if preview_value is Dictionary else {}
		if str(preview.get("perk_id", "")) == perk_id:
			return preview
	return {}


func _option_polarity(preview: Dictionary, option_key: String) -> String:
	for option_value: Variant in preview.get("options", []):
		var option: Dictionary = option_value if option_value is Dictionary else {}
		if str(option.get("option_key", "")) == option_key:
			return str(option.get("polarity", ""))
	return ""


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
