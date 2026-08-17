extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const ICON_SIZE := Vector2i(256, 256)
const EXPECTED := {
	"ko": {
		"common_bulk_up": ["철산공", "철산공으로 몸의 기세를 넓혀 몸집 크기가 증가합니다."],
		"common_swiftness": ["유운보", "유운보의 가벼운 보법으로 이동 속도가 증가합니다."],
	},
	"en": {
		"common_bulk_up": ["Iron Mountain Art", "Iron Mountain training increases body size."],
		"common_swiftness": ["Drifting Cloud Step", "Drifting Cloud footwork increases movement speed."],
	},
	"zh": {
		"common_bulk_up": ["铁山功", "修炼铁山功，增加体型。"],
		"common_swiftness": ["流云步", "施展流云步，提高移动速度。"],
	},
	"ja": {
		"common_bulk_up": ["鉄山功", "鉄山功の鍛錬で体サイズが増加します。"],
		"common_swiftness": ["流雲歩", "流雲歩の身運びで移動速度が上昇します。"],
	},
	"es": {
		"common_bulk_up": ["Arte de la Montaña de Hierro", "El Arte de la Montaña de Hierro aumenta el tamaño corporal."],
		"common_swiftness": ["Paso de Nube Errante", "El Paso de Nube Errante aumenta la velocidad de movimiento."],
	},
	"pt-BR": {
		"common_bulk_up": ["Arte da Montanha de Ferro", "A Arte da Montanha de Ferro aumenta o tamanho corporal."],
		"common_swiftness": ["Passo da Nuvem Errante", "O Passo da Nuvem Errante aumenta a velocidade de movimento."],
	},
	"ru": {
		"common_bulk_up": ["Искусство Железной Горы", "Искусство Железной Горы увеличивает размер тела."],
		"common_swiftness": ["Шаг Текущего Облака", "Шаг Текущего Облака увеличивает скорость движения."],
	},
}
const ICON_PATHS := {
	"common_bulk_up": "res://assets/sprites/perks/common_bulk_up_perk_icon.png",
	"common_swiftness": "res://assets/sprites/perks/common_swiftness_perk_icon.png",
}
const MANIFEST_PATHS := {
	"common_bulk_up": "res://assets/sprites/perks/common_bulk_up_perk_icon_manifest.json",
	"common_swiftness": "res://assets/sprites/perks/common_swiftness_perk_icon_manifest.json",
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
	print("common_mugong_cheolsan_yuun_rebrand_smoke: ok")
	quit(0)


func _test_names_and_localization() -> void:
	var catalog := RuntimePerkCatalog.new()
	for locale: String in EXPECTED.keys():
		LanguageSettings.set_test_locale_override(locale)
		var locale_expected: Dictionary = EXPECTED[locale]
		for perk_id: String in locale_expected.keys():
			var expected_fields: Array = locale_expected[perk_id]
			var data: Dictionary = catalog.get_perk_data(perk_id)
			_expect(str(data.get("name", "")) == str(expected_fields[0]), "%s should expose its adopted name for %s" % [perk_id, locale])
			_expect(str(data.get("detail", "")) == str(expected_fields[1]), "%s should expose its rebranded summary for %s" % [perk_id, locale])


func _test_compatibility_ids_and_values() -> void:
	_expect(str(LanguageSettingsData.PERK_LOCALIZATION_ALIASES.get("common_bulk_up", "")) == "paddle_bulk", "철산공 must preserve the common_bulk_up localization alias")
	_expect(str(LanguageSettingsData.PERK_LOCALIZATION_ALIASES.get("common_swiftness", "")) == "move_speed", "유운보 must preserve the common_swiftness localization alias")
	var bulk: Dictionary = RuntimePerkCatalog.COMMON_PERKS.get("common_bulk_up", {})
	var swift: Dictionary = RuntimePerkCatalog.COMMON_PERKS.get("common_swiftness", {})
	_expect(int(bulk.get("max_level", 0)) == 5, "철산공 must keep the five-level common_bulk_up contract")
	_expect(int(swift.get("max_level", 0)) == 5, "유운보 must keep the five-level common_swiftness contract")
	var bulk_descriptions: Dictionary = bulk.get("descriptions", {})
	var swift_descriptions: Dictionary = swift.get("descriptions", {})
	_expect(str(bulk_descriptions.get(1, "")) == "몸집 크기 6% 증가", "철산공 Lv.1 must retain the +6% paddle-size value")
	_expect(str(bulk_descriptions.get(5, "")) == "몸집 크기 30% 증가", "철산공 Lv.5 must retain the +30% paddle-size value")
	_expect(str(swift_descriptions.get(1, "")) == "이동속도 6% 증가", "유운보 Lv.1 must retain the +6% movement-speed value")
	_expect(str(swift_descriptions.get(5, "")) == "이동속도 30% 증가", "유운보 Lv.5 must retain the +30% movement-speed value")


func _test_icon_contract() -> void:
	var renderer := RuntimePerkIconRenderer.new()
	for perk_id: String in ICON_PATHS.keys():
		var icon_path := str(ICON_PATHS[perk_id])
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
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(MANIFEST_PATHS[perk_id])))
		_expect(parsed is Dictionary, "%s manifest should parse" % perk_id)
		if parsed is Dictionary:
			var manifest: Dictionary = parsed
			_expect(str(manifest.get("perk_id", "")) == perk_id, "%s manifest should preserve its compatibility id" % perk_id)
			_expect(str(manifest.get("runtime_path", "")) == icon_path, "%s manifest should record its production path" % perk_id)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
