extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const ICON_SIZE := Vector2i(256, 256)
const PERK_IDS := [
	"item_luck", "item_cooldown_mastery", "item_gauge_mastery", "item_caffeine",
	"item_polish", "item_recycle", "downtown_treasure_map",
]
const EXPECTED_NAMES := {
	"ko": ["인보결", "순환결", "기령심법", "연효결", "개광결", "환보결", "천기보도"],
	"en": ["Treasure-Attracting Art", "Circulation Art", "Vessel-Spirit Inner Art", "Effect-Prolonging Art", "Consecrating-Light Art", "Treasure-Returning Art", "Heavenly-Secret Treasure Map"],
	"zh": ["引宝诀", "循环诀", "器灵心法", "延效诀", "开光诀", "还宝诀", "天机宝图"],
	"ja": ["引宝訣", "循環訣", "器霊心法", "延効訣", "開光訣", "還宝訣", "天機宝図"],
	"es": ["Arte de Atracción de Tesoros", "Arte de Circulación", "Arte Interior del Espíritu del Utensilio", "Arte de Prolongación del Efecto", "Arte de Consagración de Luz", "Arte de Retorno del Tesoro", "Mapa del Tesoro del Secreto Celestial"],
	"pt-BR": ["Arte de Atração de Tesouros", "Arte de Circulação", "Arte Interior do Espírito do Artefato", "Arte de Prolongamento do Efeito", "Arte da Luz Consagrada", "Arte do Retorno do Tesouro", "Mapa do Tesouro do Segredo Celestial"],
	"ru": ["Искусство Притяжения Сокровищ", "Искусство Круговорота", "Внутреннее Искусство Духа Сосуда", "Искусство Продления Эффекта", "Искусство Освящающего Света", "Искусство Возвращения Сокровищ", "Карта Небесной Тайны"],
}
const EXPECTED_KO_DETAILS := [
	"인보결로 기물의 기운을 끌어당겨 필드 아이템이 더 자주 나타납니다.",
	"순환결로 액티브 아이템의 기운을 빠르게 되돌려 사용 간격을 줄입니다. 모든 효과 적용 후 최종 쿨타임은 기본값의 5% 미만으로 내려가지 않습니다. (최대 95% 감소)",
	"기령심법으로 액티브 아이템을 쓸 때 기물의 영기를 받아 기력을 얻습니다.",
	"연효결로 지속시간형 액티브 아이템의 효력을 더 오래 이어갑니다.",
	"개광결로 적용 대상 무공의 수치형 능력치를 독립적으로 증폭합니다. 절세무공, 캐릭터, 비급, 수련, 즉시 효과와 카운트형 효과는 제외됩니다.",
	"환보결로 사용한 아이템을 확률적으로 되돌려 보존합니다. 자체 회수되는 부메랑은 제외됩니다.",
	"천기보도가 보상 상자에서 절세무공이 나올 확률을 높입니다. 비전초식 상자가 배정된 보스를 쓰러뜨렸고 해당 비전을 아직 보유하지 않았을 때, 상자 드랍 확률이 레벨당 3%p 증가합니다.",
]
const ICON_PATHS := {
	"item_luck": "res://assets/sprites/perks/item_luck_perk_icon.png",
	"item_cooldown_mastery": "res://assets/sprites/perks/item_cooldown_mastery_perk_icon.png",
	"item_gauge_mastery": "res://assets/sprites/perks/item_gauge_mastery_perk_icon.png",
	"item_caffeine": "res://assets/sprites/perks/item_caffeine_perk_icon.png",
	"item_polish": "res://assets/sprites/perks/item_polish_perk_icon.png",
	"item_recycle": "res://assets/sprites/perks/item_recycle_perk_icon.png",
	"downtown_treasure_map": "res://assets/sprites/perks/downtown_treasure_map_perk_icon.png",
}
const EXPECTED_RECYCLE_LABELS := {
	"ko": "환보결!", "en": "Treasure-Returning Art!", "zh": "还宝诀！", "ja": "還宝訣！",
	"es": "¡Arte de Retorno del Tesoro!", "pt-BR": "Arte do Retorno do Tesouro!", "ru": "Искусство Возвращения Сокровищ!",
}

var _failed := false


func _init() -> void:
	_test_names_and_localization()
	_test_compatibility_ids_and_values()
	_test_icon_contract()
	LanguageSettings.set_test_locale_override("")
	if _failed:
		quit(1)
		return
	print("common_mugong_item_rebrand_smoke: ok")
	quit(0)


func _test_names_and_localization() -> void:
	var catalog := RuntimePerkCatalog.new()
	for locale: String in EXPECTED_NAMES.keys():
		LanguageSettings.set_test_locale_override(locale)
		var expected_locale_names: Array = EXPECTED_NAMES[locale]
		for index in PERK_IDS.size():
			var perk_id: String = PERK_IDS[index]
			var data: Dictionary = catalog.get_perk_data(perk_id)
			_expect(str(data.get("name", "")) == str(expected_locale_names[index]), "%s should expose its adopted name for %s" % [perk_id, locale])
			if locale == "ko":
				_expect(str(data.get("detail", "")) == str(EXPECTED_KO_DETAILS[index]), "%s should expose its adopted Korean detail" % perk_id)
			else:
				var summary_map: Dictionary = _summary_map_for_locale(locale)
				var summary_key: String = _localization_key(perk_id)
				_expect(str(data.get("detail", "")) == str(summary_map.get(summary_key, "")), "%s should resolve its translated summary for %s" % [perk_id, locale])
		_expect(LanguageSettings.translate_text("환보결!") == str(EXPECTED_RECYCLE_LABELS[locale]), "the 환보결 HUD notice should translate for %s" % locale)


func _test_compatibility_ids_and_values() -> void:
	var expected_aliases := {
		"item_caffeine": "active_duration_boost",
		"item_polish": "passive_polish",
		"item_recycle": "alchemy",
		"downtown_treasure_map": "treasure_map",
	}
	for perk_id: String in expected_aliases.keys():
		_expect(str(LanguageSettingsData.PERK_LOCALIZATION_ALIASES.get(perk_id, "")) == str(expected_aliases[perk_id]), "%s must preserve its localization alias" % perk_id)
	for direct_id in ["item_luck", "item_cooldown_mastery", "item_gauge_mastery"]:
		_expect(not LanguageSettingsData.PERK_LOCALIZATION_ALIASES.has(direct_id), "%s must keep its stable direct localization key" % direct_id)
	var contracts := {
		"item_luck": [5, 1, "아이템 스폰 대기 12% 감소", 5, "아이템 스폰 대기 60% 감소"],
		"item_cooldown_mastery": [5, 1, "액티브 아이템 쿨타임 13% 감소", 5, "액티브 아이템 쿨타임 65% 감소"],
		"item_gauge_mastery": [5, 1, "액티브 사용시 기력 +15", 5, "액티브 사용시 기력 +75"],
		"item_caffeine": [5, 1, "타이머형 아이템 지속 30% 증가", 5, "타이머형 아이템 지속 150% 증가"],
		"item_polish": [5, 1, "적용 대상 무공의 수치 능력치 5% 증폭", 5, "적용 대상 무공의 수치 능력치 25% 증폭"],
		"item_recycle": [5, 1, "아이템 유지 확률 7%", 5, "아이템 유지 확률 35%"],
		"downtown_treasure_map": [5, 1, "절세무공 확률 +150%, 비전초식 상자 +3%p", 5, "절세무공 확률 +750%, 비전초식 상자 +15%p"],
	}
	for perk_id: String in contracts.keys():
		var data: Dictionary = RuntimePerkCatalog.COMMON_PERKS.get(perk_id, {})
		var contract: Array = contracts[perk_id]
		var descriptions: Dictionary = data.get("descriptions", {})
		_expect(int(data.get("max_level", 0)) == int(contract[0]), "%s max level must remain unchanged" % perk_id)
		_expect(str(descriptions.get(int(contract[1]), "")) == str(contract[2]), "%s first-level value must remain unchanged" % perk_id)
		_expect(str(descriptions.get(int(contract[3]), "")) == str(contract[4]), "%s final authored value must remain unchanged" % perk_id)


func _test_icon_contract() -> void:
	var renderer := RuntimePerkIconRenderer.new()
	for perk_id: String in ICON_PATHS.keys():
		var icon_path := str(ICON_PATHS[perk_id])
		var manifest_path := icon_path.trim_suffix(".png") + "_manifest.json"
		_expect(str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(perk_id, "")) == icon_path, "%s should keep its stable static icon path" % perk_id)
		_expect(not RuntimePerkIconRenderer.MANUAL_ICON_PATHS.has(perk_id), "%s is common Mugong art and must not resolve as a Chosik manual book" % perk_id)
		_expect(str(renderer._get_static_path(perk_id)) == icon_path, "%s should resolve through the production renderer" % perk_id)
		_expect(renderer.has_icon(perk_id), "%s should import and draw through RuntimePerkIconRenderer" % perk_id)
		var texture: Texture2D = load(icon_path) as Texture2D
		_expect(texture != null, "%s icon should import as Texture2D" % perk_id)
		if texture != null:
			_expect(Vector2i(texture.get_width(), texture.get_height()) == ICON_SIZE, "%s icon should stay 256x256" % perk_id)
		var image := Image.new()
		_expect(image.load(ProjectSettings.globalize_path(icon_path)) == OK, "%s source PNG should load for alpha QA" % perk_id)
		if not image.is_empty():
			var used_rect := image.get_used_rect()
			_expect(used_rect.position.x >= 8 and used_rect.position.y >= 8, "%s should keep transparent top-left safety padding" % perk_id)
			_expect(used_rect.end.x <= 248 and used_rect.end.y <= 248, "%s should keep transparent bottom-right safety padding" % perk_id)
			for corner in [Vector2i(0, 0), Vector2i(255, 0), Vector2i(0, 255), Vector2i(255, 255)]:
				_expect(is_zero_approx(image.get_pixelv(corner).a), "%s corners should remain fully transparent" % perk_id)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		_expect(parsed is Dictionary, "%s manifest should parse" % perk_id)
		if parsed is Dictionary:
			_expect(str((parsed as Dictionary).get("perk_id", "")) == perk_id, "%s manifest should preserve its compatibility id" % perk_id)
			_expect(str((parsed as Dictionary).get("runtime_path", "")) == icon_path, "%s manifest should record its production path" % perk_id)


func _localization_key(perk_id: String) -> String:
	return str(LanguageSettingsData.PERK_LOCALIZATION_ALIASES.get(perk_id, perk_id))


func _summary_map_for_locale(locale: String) -> Dictionary:
	match locale:
		"en": return LanguageSettingsData.PERK_SUMMARY_EN
		"zh": return LanguageSettingsData.PERK_SUMMARY_ZH
		"ja": return LanguageSettingsData.PERK_SUMMARY_JA
		"es": return LanguageSettingsData.PERK_SUMMARY_ES
		"pt-BR": return LanguageSettingsData.PERK_SUMMARY_PT_BR
		"ru": return LanguageSettingsData.PERK_SUMMARY_RU
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
