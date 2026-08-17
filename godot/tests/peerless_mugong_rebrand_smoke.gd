extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const MythicPerkGrantHelper := preload("res://scripts/characters/mythic_perk_grant_helper.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const StageClearResultRewardTextResolver := preload("res://scripts/ui/stage_clear_result_reward_text_resolver.gd")
const AngelLocalization := preload("res://scripts/characters/runtime_perk_angel_blessing_localization.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")

const STATIC_SIZE := Vector2i(128, 128)
const SHEET_SIZE := Vector2i(1024, 128)
const SHEET_FRAME_INTERVAL_MSEC := 250.0
const MANIFEST_PATH := "res://assets/sprites/perks/peerless_mugong_collection_manifest.json"
const PERK_IDS := [
	"megingjord", "transcendent_crown", "ragnarok_hammer", "hermes_shoes",
	"poseidon_trident", "sacred_laurel", "heavenly_cape", "horn_strawberry_mask",
	"odins_eye", "celestial_armor", "baal_boots", "pandora_legacy", "angel_blessing",
	"yangui_hoechun",
]
const EXPECTED_NAMES := {
	"ko": ["삼재개문", "만법귀일", "천뢰진경", "축지신행", "쌍룡회류", "팔엽금강", "천문개결", "혼딸기강신", "윤회천안", "부동금강체", "풍우식기결", "금기개함", "천운삼괘", "양의회천"],
	"en": ["Three Gates of Providence", "Unity of Ten Thousand Arts", "Heavenly Thunder Scripture", "Earth-Shrinking Steps", "Twin Dragon Vortex", "Eight-Leaf Vajra", "Celestial Gate Art", "Hornberry Spirit Descent", "Samsara Heavenly Eye", "Immovable Vajra Body", "Storm-Devouring Art", "Forbidden Casket", "Three Heavenly Omens", "Dual-Principle Heaven Reversal"],
	"zh": ["三才开门", "万法归一", "天雷真经", "缩地神行", "双龙回流", "八叶金刚", "天门开诀", "角莓降神", "轮回天眼", "不动金刚体", "风雨食气诀", "禁忌开函", "天运三卦", "两仪回天"],
	"ja": ["三才開門", "万法帰一", "天雷真経", "縮地神行", "双龍回流", "八葉金剛", "天門開訣", "角苺降神", "輪廻天眼", "不動金剛体", "風雨食気訣", "禁忌開函", "天運三卦", "両儀回天"],
	"es": ["Tres Puertas del Destino", "Unidad de las Diez Mil Artes", "Escritura del Trueno Celestial", "Pasos que Acortan la Tierra", "Vórtice de los Dos Dragones", "Vajra de Ocho Hojas", "Arte de la Puerta Celestial", "Descenso del Espíritu Fresa Cornuda", "Ojo Celestial del Samsara", "Cuerpo Vajra Inmóvil", "Arte Devoratormentas", "Cofre Prohibido", "Tres Presagios Celestiales", "Reversión Celestial Dual"],
	"pt-BR": ["Três Portões do Destino", "Unidade das Dez Mil Artes", "Escritura do Trovão Celestial", "Passos que Encurtam a Terra", "Vórtice dos Dragões Gêmeos", "Vajra das Oito Folhas", "Arte do Portão Celestial", "Descida do Espírito Morango Chifrudo", "Olho Celestial do Samsara", "Corpo Vajra Imóvel", "Arte Devoradora de Tempestades", "Cofre Proibido", "Três Presságios Celestiais", "Reversão Celestial Dupla"],
	"ru": ["Трое Врат Судьбы", "Единство Десяти Тысяч Искусств", "Небесный Громовой Канон", "Шаги Сжатой Земли", "Вихрь Двух Драконов", "Ваджра Восьми Листьев", "Искусство Небесных Врат", "Нисхождение Духа Рогатой Ягоды", "Небесное Око Сансары", "Неподвижное Ваджрное Тело", "Искусство Пожирателя Бурь", "Запретный Ларец", "Три Небесных Знамения", "Двойное Небесное Отражение"],
}

var _failed := false


func _init() -> void:
	_test_catalog_and_localization()
	_test_compatibility_contract()
	_test_static_and_animated_icon_contract()
	_test_peerless_vertical_slice_labels()
	_test_materialized_labels()
	LanguageSettings.set_test_locale_override("")
	if _failed:
		quit(1)
		return
	print("peerless_mugong_rebrand_smoke: ok")
	quit(0)


func _test_catalog_and_localization() -> void:
	var catalog := RuntimePerkCatalog.new()
	for locale: String in EXPECTED_NAMES.keys():
		LanguageSettings.set_test_locale_override(locale)
		if locale == "ko":
			var item_data: Dictionary = MythicItemCatalog.new().build_item_by_name("horn_strawberry_mask")
			_verify_horn_surface_text(str(item_data.get("description", "")), "legacy mythic item")
		var expected_locale_names: Array = EXPECTED_NAMES[locale]
		for index in PERK_IDS.size():
			var perk_id: String = PERK_IDS[index]
			var data: Dictionary = catalog.get_perk_data(perk_id)
			_expect(str(data.get("name", "")) == str(expected_locale_names[index]), "%s should expose its adopted peerless name for %s" % [perk_id, locale])
			if perk_id == "horn_strawberry_mask":
				_verify_horn_activation_copy(data, locale)
			if locale != "ko":
				var summary_map: Dictionary = _summary_map_for_locale(locale)
				_expect(str(data.get("detail", "")) == str(summary_map.get(perk_id, "")), "%s should resolve its translated summary for %s" % [perk_id, locale])


func _verify_horn_activation_copy(data: Dictionary, locale: String) -> void:
	var descriptions: Dictionary = data.get("descriptions", {})
	for surfaced_text_value in [descriptions.get(1, descriptions.get("1", "")), data.get("detail", "")]:
		_verify_horn_surface_text(str(surfaced_text_value), locale)


func _verify_horn_surface_text(surfaced_text: String, surface: String) -> void:
	var normalized_command := surfaced_text.replace("→", "-")
	_expect(surfaced_text.contains("500"), "horn strawberry activation copy should expose its vigor cost for %s" % surface)
	_expect(normalized_command.contains("A-D-A-D-A-D"), "horn strawberry activation copy should expose its command for %s" % surface)


func _test_compatibility_contract() -> void:
	_expect(RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.size() == PERK_IDS.size(), "peerless roster should remain exactly 14 perks")
	for perk_id: String in PERK_IDS:
		_expect(RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.has(perk_id), "%s must keep its stable internal id" % perk_id)
		var data: Dictionary = RuntimePerkCatalog.CONVERTED_MYTHIC_PERKS.get(perk_id, {})
		_expect(str(data.get("conversion_source", "")) == perk_id, "%s must keep its conversion source" % perk_id)
		_expect(str(data.get("rarity", "")) == "mythic", "%s must remain mythic rarity" % perk_id)
		_expect(str(data.get("tree", "")) == "mythic", "%s must remain in the mythic tree" % perk_id)
		_expect(int(data.get("max_level", 0)) == 1, "%s must remain a one-level peerless art" % perk_id)
		_expect(bool(data.get("effective_level_exempt", false)), "%s must remain exempt from effective-level bonuses" % perk_id)


func _test_static_and_animated_icon_contract() -> void:
	var renderer := RuntimePerkIconRenderer.new()
	for perk_id: String in PERK_IDS:
		var static_path := "res://assets/sprites/perks/%s_perk_icon.png" % perk_id
		var sheet_path := "res://assets/sprites/perks/%s_perk_icon_sheet.png" % perk_id
		_expect(str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(perk_id, "")) == static_path, "%s should keep its stable static icon path" % perk_id)
		_expect(str(RuntimePerkIconRenderer.PERK_SHEET_PATHS.get(perk_id, "")) == sheet_path, "%s should keep its stable animated sheet path" % perk_id)
		_expect(renderer.has_icon(perk_id), "%s should import through the production icon renderer" % perk_id)
		_expect(renderer.has_animated_icon(perk_id), "%s should preserve animated acquisition/HUD art" % perk_id)
		_expect(is_equal_approx(renderer.get_icon_frame_interval_msec(perk_id), SHEET_FRAME_INTERVAL_MSEC), "%s should use the AutoSprite two-second internal-motion cadence" % perk_id)
		var static_texture: Texture2D = load(static_path) as Texture2D
		var sheet_texture: Texture2D = load(sheet_path) as Texture2D
		_expect(static_texture != null and Vector2i(static_texture.get_width(), static_texture.get_height()) == STATIC_SIZE, "%s static icon should stay 128x128" % perk_id)
		_expect(sheet_texture != null and Vector2i(sheet_texture.get_width(), sheet_texture.get_height()) == SHEET_SIZE, "%s sheet should stay 1024x128" % perk_id)
		_verify_png_alpha(perk_id, static_path, STATIC_SIZE)
		_verify_png_alpha(perk_id + " sheet", sheet_path, SHEET_SIZE)
		_verify_internal_motion_sheet(perk_id, sheet_path)
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_expect(manifest is Dictionary, "peerless Mugong collection manifest should parse")
	if manifest is Dictionary:
		var animation: Dictionary = (manifest as Dictionary).get("animation", {}) as Dictionary
		var jobs: Dictionary = animation.get("jobs", {}) as Dictionary
		_expect(str(animation.get("source", "")).contains("AutoSprite MCP"), "peerless animation manifest should retain AutoSprite provenance")
		_expect(int(animation.get("runtime_frame_interval_msec", 0)) == int(SHEET_FRAME_INTERVAL_MSEC), "peerless animation manifest cadence should match runtime")
		_expect(jobs.size() == PERK_IDS.size(), "peerless animation manifest should record every generation job")
		for perk_id: String in PERK_IDS:
			var job: Dictionary = jobs.get(perk_id, {}) as Dictionary
			if perk_id == "yangui_hoechun":
				_expect(str(job.get("generator", "")) == "Codex built-in imagegen", "양의회천 should record its built-in imagegen provenance")
				_expect(str(job.get("generation_id", "")) != "", "양의회천 should record its image generation id")
				_expect(str(job.get("motion_builder", "")).ends_with("build_yangui_hoechun_internal_motion.py"), "양의회천 should record its deterministic motion builder")
			else:
				_expect(str(job.get("asset_id", "")).begins_with("cms"), "%s should record its AutoSprite asset id" % perk_id)
				_expect(str(job.get("job_id", "")).begins_with("wf_"), "%s should record its AutoSprite job id" % perk_id)
		var assets: Array = (manifest as Dictionary).get("assets", []) as Array
		_expect(assets.size() == PERK_IDS.size(), "peerless manifest should record all 14 icons")
		for index in assets.size():
			var entry: Dictionary = assets[index] as Dictionary
			_expect(str(entry.get("perk_id", "")) == str(PERK_IDS[index]), "peerless manifest order should match the runtime roster")


func _test_peerless_vertical_slice_labels() -> void:
	var overlay_renderer := RuntimePerkOverlayRenderer.new()
	var perk := {
		"id": "odins_eye",
		"rarity": "mythic",
		"max_level": 1,
		"next_level": 1,
		"level": 1,
		"character_restriction": "",
	}
	for locale in ["ko", "en"]:
		LanguageSettings.set_test_locale_override(locale)
		var expected_tier := "절세무공" if locale == "ko" else "Peerless Martial Art"
		var expected_choice := "절세무공 선택" if locale == "ko" else "Peerless Martial Art Choice"
		_expect(overlay_renderer._level_text(perk) == expected_tier, "choice-card tier should use the peerless name for %s" % locale)
		_expect(overlay_renderer._single_level_perk_tag(perk) == expected_tier, "perk-status tier should use the peerless name for %s" % locale)
		_expect(CharacterInfoOverlayFormatter.perk_level_text(perk) == expected_tier, "held TAB perk should use the peerless name for %s" % locale)
		_expect(StageClearResultRewardTextResolver.get_reward_type_fallback_label("mythic_perk") == expected_tier, "stage-clear reward should use the peerless name for %s" % locale)
		_expect(StageClearResultRewardTextResolver.get_reward_type_fallback_label("mythic_perk_choice") == expected_choice, "stage-clear choice should use the peerless name for %s" % locale)
	var acquisition_data := MythicPerkGrantHelper.build_acquisition_cinematic_item_data("odins_eye", null)
	_expect(int(acquisition_data.get("icon_frame_msec", 0)) == int(SHEET_FRAME_INTERVAL_MSEC), "acquisition should use the same 250ms cadence as choice and held HUD icons")
	_expect(int(acquisition_data.get("icon_frame_count", 0)) == 8, "acquisition should retain all eight AutoSprite-derived frames")


func _verify_png_alpha(label: String, path: String, expected_size: Vector2i) -> void:
	var image := Image.new()
	_expect(image.load(ProjectSettings.globalize_path(path)) == OK, "%s source PNG should load" % label)
	if image.is_empty():
		return
	_expect(image.get_size() == expected_size, "%s source dimensions should match the renderer contract" % label)
	for corner in [Vector2i(0, 0), Vector2i(expected_size.x - 1, 0), Vector2i(0, expected_size.y - 1), expected_size - Vector2i.ONE]:
		_expect(is_zero_approx(image.get_pixelv(corner).a), "%s corners should remain fully transparent" % label)
	_expect(image.get_used_rect().has_area(), "%s should contain visible hanji art" % label)


func _verify_internal_motion_sheet(perk_id: String, path: String) -> void:
	var image := Image.new()
	_expect(image.load(ProjectSettings.globalize_path(path)) == OK, "%s internal-motion source PNG should load" % perk_id)
	if image.is_empty():
		return
	var frame_zero := image.get_region(Rect2i(Vector2i.ZERO, STATIC_SIZE))
	var frame_zero_rect := frame_zero.get_used_rect()
	var changed_inner_pixels := 0
	var channel_threshold := 3.0 / 255.0
	for frame_index in range(1, 8):
		var frame := image.get_region(Rect2i(Vector2i(frame_index * STATIC_SIZE.x, 0), STATIC_SIZE))
		_expect(frame.get_used_rect() == frame_zero_rect, "%s frame %d should keep one fixed outer size" % [perk_id, frame_index])
		var alpha_stable := true
		var outer_shell_stable := true
		for y in STATIC_SIZE.y:
			for x in STATIC_SIZE.x:
				var base_color := frame_zero.get_pixel(x, y)
				var frame_color := frame.get_pixel(x, y)
				if not is_equal_approx(base_color.a, frame_color.a):
					alpha_stable = false
				var distance := Vector2(float(x) - 63.5, float(y) - 63.5).length()
				var rgb_changed := (
					absf(base_color.r - frame_color.r) > channel_threshold
					or absf(base_color.g - frame_color.g) > channel_threshold
					or absf(base_color.b - frame_color.b) > channel_threshold
				)
				if distance >= 48.0:
					if rgb_changed:
						outer_shell_stable = false
				elif rgb_changed:
					changed_inner_pixels += 1
		_expect(alpha_stable, "%s frame %d should keep the static alpha silhouette" % [perk_id, frame_index])
		_expect(outer_shell_stable, "%s frame %d should not animate the outer hanji shell" % [perk_id, frame_index])
	_expect(changed_inner_pixels >= 24, "%s should contain readable internal motion inside the fixed seal" % perk_id)


func _test_materialized_labels() -> void:
	var expected_activation := {
		"ko": "삼재개문 발동!", "en": "Three Gates of Providence Activated!", "zh": "三才开门发动！", "ja": "三才開門発動！",
		"es": "¡Tres Puertas del Destino activadas!", "pt-BR": "Três Portões do Destino ativados!", "ru": "Трое Врат Судьбы открыты!",
	}
	for locale: String in expected_activation.keys():
		LanguageSettings.set_test_locale_override(locale)
		_expect(LanguageSettings.translate_text("삼재개문 발동!") == str(expected_activation[locale]), "extra-choice activation should use the new name for %s" % locale)
		_expect(AngelLocalization.text("title") == str(EXPECTED_NAMES[locale][12]), "omen modal should use the new title for %s" % locale)
		_expect(LanguageSettings.translate_text("금기개함") == str(EXPECTED_NAMES[locale][11]), "forbidden choice title should use the new name for %s" % locale)


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
