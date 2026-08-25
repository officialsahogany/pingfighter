extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const LanguageSettingsData := preload("res://scripts/core/language_settings_data.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const ICON_SIZE := Vector2i(256, 256)
const EXPECTED := {
	"ko": {
		"dash_lightweight": ["회기보", "회기보로 흩어진 기운을 거두어 소모한 활주 횟수를 더 빠르게 회복합니다."],
		"dash_module_control": ["수세결", "수세결로 활주 뒤 흐트러진 자세를 곧바로 거두어 다음 행동이 빨라집니다."],
		"dash_jump": ["비천보", "비천보로 한 번의 활주 지속을 늘려 더 멀리 움직입니다."],
		"dash_acceleration": ["대붕전익", "활주 순간 대붕이 날개를 펼치듯 몸집이 세로로 크게, 가로로 적당히 넓어져 더 넓은 범위의 공을 받아냅니다."],
		"dash_amplification": ["활주구슬", "활주구슬 하나마다 최대 활주 횟수가 1회 늘어나며, 구슬 하나당 무공 슬롯을 1칸 사용합니다."],
	},
	"en": {
		"dash_lightweight": ["Return-Breath Step", "Return-Breath Step restores spent glide charges faster."],
		"dash_module_control": ["Posture-Recovery Art", "Posture-Recovery Art shortens recovery after a glide."],
		"dash_jump": ["Sky-Soaring Step", "Sky-Soaring Step increases glide duration."],
		"dash_acceleration": ["Great Roc Spreads Wings", "Great Roc Spreads Wings expands your body greatly vertically and moderately horizontally during a glide."],
		"dash_amplification": ["Glide Orb", "Each Glide Orb adds one maximum glide charge and occupies one Mugong slot."],
	},
	"zh": {
		"dash_lightweight": ["回气步", "回气步使消耗的滑步次数恢复得更快。"],
		"dash_module_control": ["收势诀", "收势诀缩短滑步后的硬直。"],
		"dash_jump": ["飞天步", "飞天步增加滑步持续时间。"],
		"dash_acceleration": ["大鹏展翼", "大鹏展翼在滑步期间大幅纵向、适度横向扩大体型。"],
		"dash_amplification": ["滑步珠", "每颗滑步珠增加1次最大滑步次数，并占用1个武功栏位。"],
	},
	"ja": {
		"dash_lightweight": ["回気歩", "回気歩は消費した滑走回数の回復を早めます。"],
		"dash_module_control": ["収勢訣", "収勢訣は滑走後の硬直を短縮します。"],
		"dash_jump": ["飛天歩", "飛天歩は滑走持続時間を延ばします。"],
		"dash_acceleration": ["大鵬展翼", "大鵬展翼は滑走中、体を縦に大きく、横にほどよく拡大します。"],
		"dash_amplification": ["滑走珠", "滑走珠1個につき最大滑走回数が1回増え、武功枠を1つ使用します。"],
	},
	"es": {
		"dash_lightweight": ["Paso de Aliento Retornado", "Paso de Aliento Retornado recupera más rápido las cargas de deslizamiento gastadas."],
		"dash_module_control": ["Arte de Recuperación de Postura", "Arte de Recuperación de Postura reduce la recuperación tras un deslizamiento."],
		"dash_jump": ["Paso de Vuelo Celestial", "Paso de Vuelo Celestial aumenta la duración del deslizamiento."],
		"dash_acceleration": ["El Gran Roc Despliega las Alas", "El Gran Roc Despliega las Alas amplía mucho el cuerpo en vertical y moderadamente en horizontal durante un deslizamiento."],
		"dash_amplification": ["Orbe de Deslizamiento", "Cada Orbe de Deslizamiento añade una carga máxima de deslizamiento y ocupa un espacio de Mugong."],
	},
	"pt-BR": {
		"dash_lightweight": ["Passo do Retorno do Fôlego", "O Passo do Retorno do Fôlego recupera mais rápido as cargas de deslize gastas."],
		"dash_module_control": ["Arte de Recuperação da Postura", "A Arte de Recuperação da Postura reduz a recuperação após um deslize."],
		"dash_jump": ["Passo de Voo Celestial", "O Passo de Voo Celestial aumenta a duração do deslize."],
		"dash_acceleration": ["Grande Roc Abre as Asas", "O Grande Roc Abre as Asas amplia muito o corpo na vertical e moderadamente na horizontal durante um deslize."],
		"dash_amplification": ["Orbe de Deslize", "Cada Orbe de Deslize adiciona uma carga máxima de deslize e ocupa um espaço de Mugong."],
	},
	"ru": {
		"dash_lightweight": ["Шаг Возвращённого Дыхания", "Шаг Возвращённого Дыхания ускоряет восстановление потраченных зарядов скольжения."],
		"dash_module_control": ["Искусство Возврата Стойки", "Искусство Возврата Стойки сокращает задержку после скольжения."],
		"dash_jump": ["Небесный Летящий Шаг", "Небесный Летящий Шаг увеличивает длительность скольжения."],
		"dash_acceleration": ["Великий Рух Расправляет Крылья", "Великий Рух Расправляет Крылья значительно увеличивает тело по вертикали и умеренно по горизонтали во время скольжения."],
		"dash_amplification": ["Сфера скольжения", "Каждая Сфера скольжения добавляет один максимальный заряд скольжения и занимает одну ячейку мугон."],
	},
}
const ICON_PATHS := {
	"dash_lightweight": "res://assets/sprites/perks/dash_lightweight_perk_icon.png",
	"dash_module_control": "res://assets/sprites/perks/dash_module_control_perk_icon.png",
	"dash_jump": "res://assets/sprites/perks/dash_jump_perk_icon.png",
	"dash_acceleration": "res://assets/sprites/perks/dash_acceleration_perk_icon.png",
	"dash_amplification": "res://assets/sprites/perks/dash_amplification_perk_icon.png",
}
const EXPECTED_DASH_AMPLIFICATION_STATS := {
	"ko": ["최대 활주 횟수 +1", "최대 활주 횟수 +2", "최대 활주 횟수 +3"],
	"en": ["Maximum glide charges +1", "Maximum glide charges +2", "Maximum glide charges +3"],
	"zh": ["最大滑步次数 +1", "最大滑步次数 +2", "最大滑步次数 +3"],
	"ja": ["最大滑走回数 +1", "最大滑走回数 +2", "最大滑走回数 +3"],
	"es": ["Cargas máximas de deslizamiento +1", "Cargas máximas de deslizamiento +2", "Cargas máximas de deslizamiento +3"],
	"pt-BR": ["Cargas máximas de deslize +1", "Cargas máximas de deslize +2", "Cargas máximas de deslize +3"],
	"ru": ["Макс. зарядов скольжения +1", "Макс. зарядов скольжения +2", "Макс. зарядов скольжения +3"],
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
	print("common_mugong_dash_rebrand_smoke: ok")
	quit(0)


func _test_names_and_localization() -> void:
	var catalog := RuntimePerkCatalog.new()
	for locale: String in EXPECTED.keys():
		LanguageSettings.set_test_locale_override(locale)
		for perk_id: String in (EXPECTED[locale] as Dictionary).keys():
			var expected_fields: Array = (EXPECTED[locale] as Dictionary)[perk_id]
			var data: Dictionary = catalog.get_perk_data(perk_id)
			_expect(str(data.get("name", "")) == str(expected_fields[0]), "%s should expose its adopted name for %s" % [perk_id, locale])
			_expect(str(data.get("detail", "")) == str(expected_fields[1]), "%s should expose its rebranded summary for %s" % [perk_id, locale])
		var dash_data: Dictionary = catalog.get_perk_data("dash_amplification")
		var dash_descriptions: Dictionary = dash_data.get("descriptions", {})
		var expected_stats: Array = EXPECTED_DASH_AMPLIFICATION_STATS.get(locale, [])
		for level in range(1, 4):
			_expect(
				str(dash_descriptions.get(level, "")) == str(expected_stats[level - 1]),
				"dash_amplification level %d stat should be localized for %s" % [level, locale]
			)


func _test_compatibility_ids_and_values() -> void:
	_expect(str(LanguageSettingsData.PERK_LOCALIZATION_ALIASES.get("dash_acceleration", "")) == "burst_up", "대붕전익 must preserve the dash_acceleration localization alias")
	for direct_id in ["dash_lightweight", "dash_module_control", "dash_jump", "dash_amplification"]:
		_expect(not LanguageSettingsData.PERK_LOCALIZATION_ALIASES.has(direct_id), "%s must keep using its stable direct localization key" % direct_id)
	var expected_contracts := {
		"dash_lightweight": [5, 1, "활주 재충전 12% 감소", 5, "활주 재충전 60% 감소"],
		"dash_module_control": [5, 1, "활주 후딜 18% 감소", 5, "활주 후딜 90% 감소"],
		# 2026-08-25: 비천보의 실제 소비축인 지속 프레임 어휘로 계약을 갱신한다.
		"dash_jump": [5, 1, "활주 지속 7% 증가", 5, "활주 지속 35% 증가"],
		"dash_acceleration": [5, 1, "활주시 몸집 세로 70%·가로 10% 증가", 5, "활주시 몸집 세로 350%·가로 50% 증가"],
		"dash_amplification": [3, 1, "최대 활주 횟수 +1", 3, "최대 활주 횟수 +3"],
	}
	var dash_contract: Dictionary = RuntimePerkCatalog.COMMON_PERKS.get("dash_amplification", {})
	_expect(str(dash_contract.get("rank_tag", "")) == "unique", "활주구슬 should keep its count in level while presenting the 고유 rank tag")
	for perk_id: String in expected_contracts.keys():
		var data: Dictionary = RuntimePerkCatalog.COMMON_PERKS.get(perk_id, {})
		var contract: Array = expected_contracts[perk_id]
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


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
