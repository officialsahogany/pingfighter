extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const ICON_SIZE := Vector2i(256, 256)
const EXPECTED := {
	"ko": {
		"common_expansion": ["광맥결", "광맥결로 기맥을 넓혀 이번 런의 무공 최대 슬롯을 1칸씩 늘립니다. 자신은 무공 슬롯을 차지하지 않으며, 직접 투자한 레벨만 적용됩니다. 초월자의 왕관·현문차력·점화 등 유효 레벨 보너스로는 슬롯이 늘지 않습니다."],
		"perk_boost_charge": ["축기결", "축기결이 발동하면 다음 활주 횟수 소모를 1회 무효화하고, 재충전 중인 활주 1회의 남은 시간을 90% 줄입니다."],
		"perk_laurel_shield": ["오엽호신", "공을 막아주는 다섯 벽사 잎이 주변을 돌며 몸을 보호합니다."],
		"common_training": ["조식심법", "호흡과 기운을 고르게 하여 모든 초식을 더 빠르게 다시 펼칩니다. 모든 효과 적용 후 최종 쿨타임은 기본값의 5% 미만으로 내려가지 않습니다. (최대 95% 감소)"],
	},
	"en": {
		"common_expansion": ["Meridian-Widening Art", "Meridian-Widening Art increases maximum Mugong slots by 1 per level. Only directly invested levels count; effective-level bonuses do not add slots."],
		"perk_boost_charge": ["Energy-Gathering Art", "Energy-Gathering Art may preserve the next glide charge and sharply shorten one recharge."],
		"perk_laurel_shield": ["Five-Leaf Ward", "Five warding leaves orbit you and block the ball."],
		"common_training": ["Breath-Regulating Inner Art", "Breath-Regulating Inner Art makes all Chosik recharge faster."],
	},
	"zh": {
		"common_expansion": ["广脉诀", "广脉诀每级使武功最大栏位增加1。仅直接投资的等级有效；有效等级加成不会增加栏位。"],
		"perk_boost_charge": ["蓄气诀", "蓄气诀可使下一次滑步不消耗次数，并大幅缩短一次恢复时间。"],
		"perk_laurel_shield": ["五叶护身", "五片辟邪叶环绕护身并挡住球。"],
		"common_training": ["调息心法", "调息心法使所有招式恢复得更快。"],
	},
	"ja": {
		"common_expansion": ["広脈訣", "広脈訣はレベルごとに武功の最大枠を1つ増やします。直接投資したレベルのみ有効で、有効レベルボーナスでは枠は増えません。"],
		"perk_boost_charge": ["蓄気訣", "蓄気訣により次の滑走回数を消費せず、1回分の回復時間を大幅に短縮することがあります。"],
		"perk_laurel_shield": ["五葉護身", "五枚の魔除けの葉が周囲を巡り、ボールを防ぎます。"],
		"common_training": ["調息心法", "調息心法により、すべての招式の再充填が早くなります。"],
	},
	"es": {
		"common_expansion": ["Arte de Meridianos Amplios", "El Arte de Meridianos Amplios aumenta en 1 los espacios máximos de Mugong por nivel. Solo cuentan los niveles invertidos directamente; los bonos de nivel efectivo no añaden espacios."],
		"perk_boost_charge": ["Arte de Acumulación de Energía", "El Arte de Acumulación de Energía puede conservar la siguiente carga de deslizamiento y acortar mucho una recarga."],
		"perk_laurel_shield": ["Guardia de Cinco Hojas", "Cinco hojas protectoras orbitan a tu alrededor y bloquean la pelota."],
		"common_training": ["Arte Interior de la Respiración", "El Arte Interior de la Respiración acelera la recarga de todas las técnicas."],
	},
	"pt-BR": {
		"common_expansion": ["Arte dos Meridianos Amplos", "A Arte dos Meridianos Amplos aumenta em 1 os espaços máximos de Mugong por nível. Apenas níveis investidos diretamente contam; bônus de nível efetivo não adicionam espaços."],
		"perk_boost_charge": ["Arte de Acúmulo de Energia", "A Arte de Acúmulo de Energia pode preservar a próxima carga de deslize e reduzir muito uma recarga."],
		"perk_laurel_shield": ["Guarda das Cinco Folhas", "Cinco folhas protetoras orbitam ao seu redor e bloqueiam a bola."],
		"common_training": ["Arte Interior da Respiração", "A Arte Interior da Respiração acelera a recarga de todas as técnicas."],
	},
	"ru": {
		"common_expansion": ["Техника Широких Меридианов", "Техника Широких Меридианов увеличивает максимум ячеек мугон на 1 за уровень. Учитываются только напрямую вложенные уровни; бонусы эффективного уровня не добавляют ячейки."],
		"perk_boost_charge": ["Искусство Накопления Энергии", "Искусство Накопления Энергии может сохранить следующий заряд скольжения и резко сократить одну перезарядку."],
		"perk_laurel_shield": ["Оберег Пяти Листьев", "Пять защитных листьев вращаются вокруг вас и блокируют мяч."],
		"common_training": ["Искусство Управления Дыханием", "Искусство Управления Дыханием ускоряет восстановление всех техник."],
	},
}
const ICON_PATHS := {
	"common_expansion": "res://assets/sprites/perks/common_expansion_perk_icon.png",
	"perk_boost_charge": "res://assets/sprites/perks/perk_boost_charge_perk_icon_v2.png",
	"perk_laurel_shield": "res://assets/sprites/perks/perk_laurel_shield_perk_icon.png",
	"common_training": "res://assets/sprites/perks/common_training_perk_icon.png",
}
const MANIFEST_PATHS := {
	"common_expansion": "res://assets/sprites/perks/common_expansion_perk_icon_manifest.json",
	"perk_boost_charge": "res://assets/sprites/perks/perk_boost_charge_perk_icon_v2_manifest.json",
	"perk_laurel_shield": "res://assets/sprites/perks/perk_laurel_shield_perk_icon_manifest.json",
	"common_training": "res://assets/sprites/perks/common_training_perk_icon_manifest.json",
}
const EXPECTED_ROLL_LABELS := {
	"ko": "축기결 발동확률",
	"en": "Energy-Gathering Art Chance",
	"zh": "蓄气诀发动概率",
	"ja": "蓄気訣発動率",
	"es": "Probabilidad de Arte de Acumulación de Energía",
	"pt-BR": "Chance da Arte de Acúmulo de Energia",
	"ru": "Шанс Искусства Накопления Энергии",
}

var _failed := false


func _init() -> void:
	PerkConversionFlags.debug_set_enabled(true)
	_test_names_and_localization()
	_test_materialized_roll_label()
	_test_compatibility_ids_and_values()
	_test_icon_contract()
	LanguageSettings.set_test_locale_override("")
	if _failed:
		quit(1)
		return
	print("common_mugong_foundation_rebrand_smoke: ok")
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


func _test_materialized_roll_label() -> void:
	for locale: String in EXPECTED_ROLL_LABELS.keys():
		LanguageSettings.set_test_locale_override(locale)
		_expect(LanguageSettings.translate_text("축기결 발동확률") == str(EXPECTED_ROLL_LABELS[locale]), "the 축기결 mythic roll label should translate for %s" % locale)


func _test_compatibility_ids_and_values() -> void:
	var aliases := {
		"common_expansion": "accessory_slot_expand",
		"perk_boost_charge": "boost_charging",
		"perk_laurel_shield": "perk_laurel_shield",
		"common_training": "skill_cooldown_training",
	}
	for perk_id: String in aliases.keys():
		_expect(str(LanguageSettingsData.PERK_LOCALIZATION_ALIASES.get(perk_id, "")) == str(aliases[perk_id]), "%s must preserve its localization alias" % perk_id)
	var expansion: Dictionary = RuntimePerkCatalog.COMMON_PERKS.get("common_expansion", {})
	var charging: Dictionary = RuntimePerkCatalog.COMMON_PERKS.get("perk_boost_charge", {})
	var ward: Dictionary = RuntimePerkCatalog.COMMON_PERKS.get("perk_laurel_shield", {})
	var training: Dictionary = RuntimePerkCatalog.COMMON_PERKS.get("common_training", {})
	_expect(RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS.has("common_training"), "조식심법 should remain only as a training-migrated compatibility id")
	_expect(not "common_training" in _ids(RuntimePerkCatalog.new().get_choices("smasher", {}, true, 500)), "조식심법 should not return to current Mugong offers")
	_expect(int(expansion.get("max_level", 0)) == 4, "광맥결 must keep the four-level slot expansion contract")
	_expect(int(charging.get("max_level", 0)) == 5, "축기결 must keep the five-level proc contract")
	_expect(int(ward.get("max_level", 0)) == 5, "오엽호신 must keep the five-level leaf contract")
	_expect(int(training.get("max_level", 0)) == 5, "조식심법 must keep the five-level cooldown contract")
	_expect(str((expansion.get("descriptions", {}) as Dictionary).get(4, "")) == "무공 최대 슬롯 +1 (총 10)", "광맥결 Lv.4 must retain the ten-slot cap")
	_expect(str((charging.get("descriptions", {}) as Dictionary).get(5, "")).find("확률 +35%") >= 0, "축기결 Lv.5 must retain the 35% proc chance")
	_expect(str((charging.get("descriptions", {}) as Dictionary).get(5, "")).find("재충전 -90%") >= 0, "축기결 must retain the 90% recharge reduction")
	_expect(str((ward.get("descriptions", {}) as Dictionary).get(5, "")) == "벽사 잎 5개 보호", "오엽호신 Lv.5 must retain five blocking leaves")
	_expect(str((training.get("descriptions", {}) as Dictionary).get(5, "")) == "모든 초식 쿨타임 40% 감소", "조식심법 Lv.5 must retain the 40% cooldown reduction")


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


func _ids(entries: Array) -> Array[String]:
	var result: Array[String] = []
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			result.append(str((entry_value as Dictionary).get("id", "")))
	return result
