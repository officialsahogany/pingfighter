extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemBrickWallEffectRenderer := preload("res://scripts/items/active_item_brick_wall_effect_renderer.gd")
const ActiveItemPickupFeedback := preload("res://scripts/items/active_item_pickup_feedback.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const MythicItemPandoraLegacyRuntime := preload("res://scripts/items/mythic_item_pandora_legacy_runtime.gd")
const PerkFusionLocalizationData := preload("res://scripts/characters/perk_fusion_localization_data.gd")

const EXPECTED_ICON_PATH := "res://assets/sprites/items/wall_icon_hq_v1.png"
const EXPECTED_WALL_SHEET_PATH := "res://assets/sprites/effects/tobyeokpae_installed_variants_imagegen_v1.png"
const EXPECTED_LOCALIZED_NAMES := {
	"en": "Tobyeok Talisman",
	"zh": "土壁牌",
	"ja": "土壁札",
	"es": "Talismán Tobyeok",
	"pt-BR": "Talismã Tobyeok",
	"ru": "Талисман «Тобёк»",
}
const EXPECTED_LOCALIZED_ROLL_LABELS := {
	"en": ["Earthen Wall Length", "Tobyeok Talisman Spawn Rate"],
	"zh": ["土壁长度", "土壁牌出现率"],
	"ja": ["土壁の長さ", "土壁札出現率"],
	"es": ["Longitud del muro de tierra", "Aparición del Talismán Tobyeok"],
	"pt-BR": ["Comprimento do muro de terra", "Taxa de aparição do Talismã Tobyeok"],
	"ru": ["Длина земляной стены", "Частота появления талисмана «Тобёк»"],
}
const EXPECTED_FUSION_LABELS := {
	"zh": ["土壁长度", "土壁牌出现量"],
	"ja": ["土壁の長さ", "土壁札出現量"],
	"es": ["Longitud del muro de tierra", "Aparición del Talismán Tobyeok"],
	"pt-BR": ["Comprimento do muro de terra", "Aparição do Talismã Tobyeok"],
	"ru": ["Длина земляной стены", "Появление талисмана «Тобёк»"],
}

var _failures: Array[String] = []


func _init() -> void:
	_verify_catalog_and_icon()
	_verify_wall_sheet()
	_verify_visible_name_consumers()
	_verify_localization()
	_verify_fusion_localization()
	_verify_renderer_identity()
	LanguageSettings.set_test_locale_override("")

	if _failures.is_empty():
		print("active_item_tobyeokpae_rebrand_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_and_icon() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var item_data: Dictionary = ActiveItemCatalog.new().build_item_by_name("wall")
	_expect(str(item_data.get("name", "")) == "wall", "Tobyeok Talisman must preserve the wall compatibility ID")
	_expect(str(item_data.get("effect", "")) == "wall", "Tobyeok Talisman must preserve the wall effect route")
	_expect(str(item_data.get("display_name", "")) == "토벽패", "wall should display as Tobyeok Talisman in Korean")
	_expect(str(item_data.get("description", "")).contains("토벽"), "Tobyeok Talisman tooltip should describe the earthen wall")
	_expect(str(item_data.get("icon_path", "")) == EXPECTED_ICON_PATH, "Tobyeok Talisman should use the generated command-talisman icon")
	_expect(ActiveItemCatalog.WALL_ICON_PATH == EXPECTED_ICON_PATH, "wall icon constant should point to the Tobyeok Talisman asset")

	var icon := load(EXPECTED_ICON_PATH) as Texture2D
	_expect(icon != null, "Tobyeok Talisman generated icon should load")
	if icon == null:
		return
	_expect(icon.get_size() == Vector2(256.0, 256.0), "Tobyeok Talisman icon should use the 256px HQ contract")
	var image: Image = icon.get_image()
	var semi_count := 0
	var opaque_count := 0
	for y_value in range(image.get_height()):
		for x_value in range(image.get_width()):
			var alpha: float = image.get_pixel(x_value, y_value).a
			if alpha > 8.0 / 255.0 and alpha <= 200.0 / 255.0:
				semi_count += 1
			if alpha > 200.0 / 255.0:
				opaque_count += 1
	_expect(opaque_count >= image.get_width() * image.get_height() / 4, "Tobyeok Talisman HQ icon should keep a readable opaque silhouette")
	_expect(semi_count < image.get_width() * image.get_height() / 4, "Tobyeok Talisman icon should not carry a full-canvas chroma halo")
	_expect(image.get_pixel(0, 0).a <= 8.0 / 255.0, "Tobyeok Talisman icon corner should be transparent")


func _verify_wall_sheet() -> void:
	_expect(ActiveItemBrickWallEffectRenderer.BRICK_WALL_VARIANT_SHEET_PATH == EXPECTED_WALL_SHEET_PATH, "wall renderer should point to the generated Tobyeok earthen-wall sheet")
	var texture := load(EXPECTED_WALL_SHEET_PATH) as Texture2D
	_expect(texture != null, "Tobyeok earthen-wall variant sheet should load")
	if texture == null:
		return
	_expect(texture.get_size() == Vector2(1024.0, 128.0), "Tobyeok earthen-wall sheet should preserve the production 4x2 geometry")
	var image: Image = texture.get_image()
	for variant_index in range(ActiveItemBrickWallEffectRenderer.BRICK_WALL_VARIANT_COUNT):
		var cell_x: int = variant_index % ActiveItemBrickWallEffectRenderer.BRICK_WALL_VARIANT_GRID_COLS
		@warning_ignore("integer_division")
		var cell_y: int = variant_index / ActiveItemBrickWallEffectRenderer.BRICK_WALL_VARIANT_GRID_COLS
		var opaque_count := 0
		for y_value in range(cell_y * 64, (cell_y + 1) * 64):
			for x_value in range(cell_x * 256, (cell_x + 1) * 256):
				if image.get_pixel(x_value, y_value).a > 200.0 / 255.0:
					opaque_count += 1
		_expect(opaque_count >= 5000, "Tobyeok earthen-wall sheet cell %d should contain a readable barrier" % variant_index)


func _verify_visible_name_consumers() -> void:
	_expect(str(ActiveItemPickupFeedback.ITEM_NAME_KO.get("wall", "")) == "토벽패", "pickup feedback should use Tobyeok Talisman")
	_expect(str(MythicItemPandoraLegacyRuntime.ACTIVE_ITEM_KOREAN_NAMES.get("wall", "")) == "토벽패", "Pandora Legacy should use Tobyeok Talisman")
	var debug_source := FileAccess.get_file_as_string("res://scripts/items/active_item_debug_spawn_menu.gd")
	var roll_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_catalog_roll_definitions.gd")
	var build_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_catalog_build_router.gd")
	var perk_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_catalog.gd")
	var overflow_source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_overflow_descriptions.gd")
	_expect(debug_source.contains("토벽 설치"), "F2 active-item menu should describe the wall as an earthen-wall placement")
	_expect(roll_source.contains("토벽 길이") and roll_source.contains("토벽패 등장률"), "Master roll labels should use Tobyeok terminology")
	_expect(build_source.contains("토벽과 널뛰기") and build_source.contains("토벽패의 필드 등장"), "Master item description should use Tobyeok terminology")
	_expect(perk_source.contains("토벽·널뛰기") and perk_source.contains("토벽패 등장"), "Master perk descriptions should use Tobyeok terminology")
	_expect(overflow_source.contains("토벽·널뛰기") and overflow_source.contains("토벽패 등장"), "Master overflow description should use Tobyeok terminology")
	for source in [debug_source, roll_source, build_source, perk_source, overflow_source]:
		_expect(not str(source).contains("벽돌"), "player-facing Tobyeok production sources should not retain the old brick term")


func _verify_localization() -> void:
	var catalog := ActiveItemCatalog.new()
	for locale_value in EXPECTED_LOCALIZED_NAMES.keys():
		var locale: String = str(locale_value)
		LanguageSettings.set_test_locale_override(locale)
		var expected_name: String = str(EXPECTED_LOCALIZED_NAMES[locale])
		var item_data: Dictionary = catalog.build_item_by_name("wall")
		_expect(str(item_data.get("display_name", "")) == expected_name, "Tobyeok Talisman should localize in %s" % locale)
		_expect(LanguageSettings.translate_text("토벽패") == expected_name, "Tobyeok exact-text lane should localize in %s" % locale)
		var expected_labels: Array = EXPECTED_LOCALIZED_ROLL_LABELS[locale]
		_expect(LanguageSettings.translate_text("토벽 길이") == str(expected_labels[0]), "earthen-wall length roll label should localize in %s" % locale)
		_expect(LanguageSettings.translate_text("토벽패 등장률") == str(expected_labels[1]), "Tobyeok Talisman spawn roll label should localize in %s" % locale)


func _verify_fusion_localization() -> void:
	for locale_value in EXPECTED_FUSION_LABELS.keys():
		var locale: String = str(locale_value)
		var localized_labels: Dictionary = PerkFusionLocalizationData.OPTION_LABELS.get(locale, {})
		var expected_labels: Array = EXPECTED_FUSION_LABELS[locale]
		_expect(str(localized_labels.get("wall_length_pct", "")) == str(expected_labels[0]), "fusion earthen-wall length label should localize in %s" % locale)
		_expect(str(localized_labels.get("wall_spawn_bonus_pct", "")) == str(expected_labels[1]), "fusion Tobyeok Talisman spawn label should localize in %s" % locale)


func _verify_renderer_identity() -> void:
	var renderer := ActiveItemBrickWallEffectRenderer.new()
	var texture: Texture2D = renderer.get_brick_wall_variant_sheet_texture()
	_expect(texture != null, "Tobyeok production wall renderer should prewarm its generated sheet")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/items/active_item_brick_wall_effect_renderer.gd")
	_expect(renderer_source.contains("_draw_tobyeok_talisman_icon"), "install gauge should use the Tobyeok talisman motif")
	_expect(not renderer_source.contains("_draw_brick_hammer_icon"), "install gauge should not retain the modern brick hammer motif")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
