extends SceneTree

const BossSkillCardHudSpec := preload("res://scripts/stages/common/boss_skill_card_hud_spec.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const Stage2ArachneBossState := preload("res://scripts/stages/stage2/stage2_arachne_boss_state.gd")
const Stage2MolewangBossState := preload("res://scripts/stages/stage2/stage2_molewang_boss_state.gd")
const Stage3AliceBossState := preload("res://scripts/stages/stage3/stage3_alice_boss_state.gd")
const Stage3TeddyBearBossState := preload("res://scripts/stages/stage3/stage3_teddy_bear_boss_state.gd")

const STAGE2_RENDERER_PATH := "res://scripts/stages/stage2/stage2_boss_skill_hud_renderer.gd"
const STAGE3_RENDERER_PATH := "res://scripts/stages/stage3/stage3_boss_skill_hud_renderer.gd"
const HUD_SPEC_PATH := "res://scripts/stages/common/boss_skill_card_hud_spec.gd"
const TARGETS := {
	"arachne": {
		"stage": 2,
		"boss_name": "거미각시",
		"source_path": "res://scripts/stages/stage2/stage2_arachne_boss_state.gd",
		"skills": {
			"web_trap": "천라주망",
			"web_rescue": "견사회수",
			"spider_rage": "혈주망진",
		},
		"legacy_labels": ["거미줄 장판", "거미줄 구출", "분노 거미줄"],
	},
	"molewang": {
		"stage": 2,
		"boss_name": "지굴왕",
		"source_path": "res://scripts/stages/stage2/stage2_molewang_boss_state.gd",
		"skills": {
			"tunnel_raid": "지맥잠행",
			"spinning_claw": "선조율풍",
			"friend_moles": "지굴원군",
		},
		"legacy_labels": ["땅굴 습격", "회전발톱", "친구두더지"],
	},
	"alice": {
		"stage": 3,
		"boss_name": "옥토선자",
		"source_path": "res://scripts/stages/stage3/stage3_alice_boss_state.gd",
		"skills": {
			"mirror_world": "경화수월",
			"size_shift": "여의변화",
			"rabbit_projectile": "옥토비탄",
		},
		"legacy_labels": ["거울 세계", "사이즈 시프트", "토끼 투사체"],
	},
	"teddy_bear": {
		"stage": 3,
		"boss_name": "포웅귀",
		"source_path": "res://scripts/stages/stage3/stage3_teddy_bear_boss_state.gd",
		"skills": {
			"cotton_throw": "면운산화",
			"cotton_bomb": "면화폭뢰",
			"deadly_hug": "사혼포옹",
			"heart_beam": "심광충파",
		},
		"legacy_labels": ["솜뭉치 투척", "솜뭉치 폭탄", "죽음의 포옹", "하트 빔"],
	},
}
const EXPECTED_LOCALIZED_NAMES := {
	"ko": {
		"천라주망": "천라주망", "견사회수": "견사회수", "혈주망진": "혈주망진",
		"지맥잠행": "지맥잠행", "선조율풍": "선조율풍", "지굴원군": "지굴원군",
		"경화수월": "경화수월", "여의변화": "여의변화", "옥토비탄": "옥토비탄",
		"면운산화": "면운산화", "면화폭뢰": "면화폭뢰", "사혼포옹": "사혼포옹", "심광충파": "심광충파",
	},
	"en": {
		"천라주망": "Heavenly Spiderweb Snare", "견사회수": "Silken Retrieval", "혈주망진": "Bloodweb Formation",
		"지맥잠행": "Earthvein Burrow", "선조율풍": "Whirling Claw Gale", "지굴원군": "Burrow Reinforcements",
		"경화수월": "Flowers in a Mirror, Moon on Water", "여의변화": "Willed Transformation", "옥토비탄": "Jade Rabbit Missile",
		"면운산화": "Cottoncloud Scatterbloom", "면화폭뢰": "Cottonflower Thunderbomb", "사혼포옹": "Dead Soul Embrace", "심광충파": "Heartlight Shockwave",
	},
	"zh": {
		"천라주망": "天罗蛛网", "견사회수": "绢丝回收", "혈주망진": "血蛛网阵",
		"지맥잠행": "地脉潜行", "선조율풍": "旋爪律风", "지굴원군": "地窟援军",
		"경화수월": "镜花水月", "여의변화": "如意变化", "옥토비탄": "玉兔飞弹",
		"면운산화": "绵云散花", "면화폭뢰": "绵花爆雷", "사혼포옹": "死魂抱拥", "심광충파": "心光冲波",
	},
	"ja": {
		"천라주망": "天羅蛛網", "견사회수": "絹糸回収", "혈주망진": "血蛛網陣",
		"지맥잠행": "地脈潜行", "선조율풍": "旋爪律風", "지굴원군": "地窟援軍",
		"경화수월": "鏡花水月", "여의변화": "如意変化", "옥토비탄": "玉兎飛弾",
		"면운산화": "綿雲散花", "면화폭뢰": "綿花爆雷", "사혼포옹": "死魂抱擁", "심광충파": "心光衝波",
	},
	"es": {
		"천라주망": "Trampa de telaraña celestial", "견사회수": "Recuperación de hilo de seda", "혈주망진": "Formación de telaraña sangrienta",
		"지맥잠행": "Acecho por la vena terrestre", "선조율풍": "Vendaval de garra giratoria", "지굴원군": "Refuerzos de la madriguera",
		"경화수월": "Flores en el espejo, luna en el agua", "여의변화": "Transformación a voluntad", "옥토비탄": "Proyectil del Conejo de Jade",
		"면운산화": "Floración de nube de algodón", "면화폭뢰": "Trueno explosivo de algodón", "사혼포옹": "Abrazo del alma muerta", "심광충파": "Onda de choque del corazón",
	},
	"pt-BR": {
		"천라주망": "Armadilha de Teia Celestial", "견사회수": "Resgate de Fio de Seda", "혈주망진": "Formação da Teia Sangrenta",
		"지맥잠행": "Esgueira pela Veia da Terra", "선조율풍": "Vendaval da Garra Giratória", "지굴원군": "Reforços da Toca",
		"경화수월": "Flor no Espelho, Lua na Água", "여의변화": "Transformação à Vontade", "옥토비탄": "Projétil do Coelho de Jade",
		"면운산화": "Florescer da Nuvem de Algodão", "면화폭뢰": "Trovão Explosivo de Algodão", "사혼포옹": "Abraço da Alma Morta", "심광충파": "Onda de Choque do Coração",
	},
	"ru": {
		"천라주망": "Небесная паутина", "견사회수": "Возврат шёлковой нитью", "혈주망진": "Кровавый паутинный строй",
		"지맥잠행": "Ход земной жилой", "선조율풍": "Вихрь вращающихся когтей", "지굴원군": "Подземное подкрепление",
		"경화수월": "Цветок в зеркале, луна в воде", "여의변화": "Преображение по воле", "옥토비탄": "Снаряд Нефритового Кролика",
		"면운산화": "Россыпь хлопковых облаков", "면화폭뢰": "Хлопковая гром-бомба", "사혼포옹": "Объятие мёртвой души", "심광충파": "Ударная волна света сердца",
	},
}
const EXPECTED_SKILL_COUNT := 13
const EXPECTED_LEG_COUNT := 7

var _failures: Array[String] = []
var _leg_count := 0


func _init() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	_verify_production_hud_ids_and_labels()
	_verify_additional_hud_skills_are_in_scope()
	_verify_tooltip_fallback_consumes_the_live_label()
	_verify_all_seven_locales()
	_verify_legacy_labels_left_production_sources()
	_verify_display_only_source_contract()
	_verify_korean_copy_has_no_em_dash()
	LanguageSettings.set_test_locale_override("")
	_expect(_leg_count == EXPECTED_LEG_COUNT, "all variant boss skill-name smoke legs must execute")
	if _failures.is_empty():
		print("variant_boss_skill_name_rebrand_smoke: PASS=%d" % _leg_count)
		print("variant_boss_skill_name_rebrand_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_production_hud_ids_and_labels() -> void:
	_leg_count += 1
	var total_skill_count := 0
	for variant_id_value in TARGETS.keys():
		var variant_id := str(variant_id_value)
		var target: Dictionary = TARGETS[variant_id]
		var state: Object = _state_for_variant(variant_id)
		_expect(state != null, "%s state fixture must exist" % variant_id)
		if state == null:
			continue
		var context: Dictionary = state.call("get_hud_context") as Dictionary
		var stage_id := int(target.get("stage", 0))
		var skills: Array = context.get("stage%d_boss_skill_hud_skills" % stage_id, []) as Array
		var expected_skills: Dictionary = target.get("skills", {}) as Dictionary
		var actual_ids: Array[String] = []
		for skill_value in skills:
			if not skill_value is Dictionary:
				continue
			var skill: Dictionary = skill_value
			var skill_id := str(skill.get("id", ""))
			actual_ids.append(skill_id)
			_expect(expected_skills.has(skill_id), "%s must not publish an unapproved skill id %s" % [variant_id, skill_id])
			_expect(str(skill.get("label", "")) == str(expected_skills.get(skill_id, "")), "%s must publish the approved label for %s" % [variant_id, skill_id])
		var expected_ids: Array[String] = []
		for expected_id_value in expected_skills.keys():
			expected_ids.append(str(expected_id_value))
		actual_ids.sort()
		expected_ids.sort()
		_expect(actual_ids == expected_ids, "%s compatibility skill-id set must remain exact" % variant_id)
		_expect(str(context.get("stage%d_boss_skill_hud_boss_name" % stage_id, "")) == str(target.get("boss_name", "")), "%s must retain its approved boss display name" % variant_id)
		total_skill_count += skills.size()
	_expect(total_skill_count == EXPECTED_SKILL_COUNT, "production HUD contexts must expose all 13 approved skill ids")


func _verify_additional_hud_skills_are_in_scope() -> void:
	_leg_count += 1
	var arachne_skills := _skills_by_id(Stage2ArachneBossState.new().get_hud_context(), 2)
	var molewang_skills := _skills_by_id(Stage2MolewangBossState.new().get_hud_context(), 2)
	_expect(str(arachne_skills.get("spider_rage", {}).get("label", "")) == "혈주망진", "spider_rage must expose 혈주망진 in the live Arachne HUD")
	_expect(str(molewang_skills.get("friend_moles", {}).get("label", "")) == "지굴원군", "friend_moles must expose 지굴원군 in the live Molewang HUD")


func _verify_tooltip_fallback_consumes_the_live_label() -> void:
	_leg_count += 1
	for variant_id_value in TARGETS.keys():
		var variant_id := str(variant_id_value)
		var target: Dictionary = TARGETS[variant_id]
		var state: Object = _state_for_variant(variant_id)
		var context: Dictionary = state.call("get_hud_context") as Dictionary
		var stage_id := int(target.get("stage", 0))
		for skill_value in context.get("stage%d_boss_skill_hud_skills" % stage_id, []):
			var skill: Dictionary = skill_value as Dictionary
			var tooltip_info: Dictionary = BossSkillCardHudSpec._build_tooltip_info(skill, {})
			_expect(str(tooltip_info.get("name", "")) == str(skill.get("label", "")), "%s tooltip fallback must consume the live label" % str(skill.get("id", "")))
	var stage2_renderer_source := FileAccess.get_file_as_string(STAGE2_RENDERER_PATH)
	var stage3_renderer_source := FileAccess.get_file_as_string(STAGE3_RENDERER_PATH)
	var hud_spec_source := FileAccess.get_file_as_string(HUD_SPEC_PATH)
	_expect(stage2_renderer_source.contains("BossSkillCardHudSpec.draw_skill_tooltip("), "Stage 2 production renderer must route hover labels through the shared tooltip spec")
	_expect(stage3_renderer_source.contains("BossSkillCardHudSpec.draw_skill_tooltip("), "Stage 3 production renderer must route hover labels through the shared tooltip spec")
	_expect(hud_spec_source.contains('skill.get("label"'), "shared production tooltip must retain the live label fallback")
	_expect(hud_spec_source.contains('LanguageSettings.translate_text(str(info.get("name", "")))'), "shared production tooltip must localize the resolved skill name")


func _verify_all_seven_locales() -> void:
	_leg_count += 1
	var locales: Array[String] = LanguageSettings.get_language_options()
	_expect(locales.size() == 7, "skill-name coverage seal must exercise all seven supported locales")
	for locale in locales:
		LanguageSettings.set_test_locale_override(locale)
		var expected: Dictionary = EXPECTED_LOCALIZED_NAMES.get(locale, {}) as Dictionary
		_expect(expected.size() == EXPECTED_SKILL_COUNT, "%s must define all 13 approved skill names" % locale)
		for source_name_value in expected.keys():
			var source_name := str(source_name_value)
			_expect(LanguageSettings.translate_text(source_name) == str(expected.get(source_name, "")), "%s must use the approved %s localization" % [source_name, locale])
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)


func _verify_legacy_labels_left_production_sources() -> void:
	_leg_count += 1
	for variant_id_value in TARGETS.keys():
		var variant_id := str(variant_id_value)
		var target: Dictionary = TARGETS[variant_id]
		var source := FileAccess.get_file_as_string(str(target.get("source_path", "")))
		for legacy_label_value in target.get("legacy_labels", []):
			var legacy_label := str(legacy_label_value)
			_expect(not source.contains(legacy_label), "%s production state must not retain legacy display copy %s" % [variant_id, legacy_label])


func _verify_display_only_source_contract() -> void:
	_leg_count += 1
	for variant_id_value in TARGETS.keys():
		var variant_id := str(variant_id_value)
		var target: Dictionary = TARGETS[variant_id]
		var source := FileAccess.get_file_as_string(str(target.get("source_path", "")))
		for skill_id_value in (target.get("skills", {}) as Dictionary).keys():
			var skill_id := str(skill_id_value)
			_expect(source.contains('"%s"' % skill_id), "%s compatibility id must remain in its production owner" % skill_id)
	_expect(FileAccess.get_file_as_string(str(TARGETS["molewang"].get("source_path", ""))).contains('return "선조율풍!"'), "Molewang speech copy must not reintroduce the old spinning-claw name")


func _verify_korean_copy_has_no_em_dash() -> void:
	_leg_count += 1
	var em_dash := String.chr(0x2014)
	var en_dash := String.chr(0x2013)
	for target_value in TARGETS.values():
		var target: Dictionary = target_value
		for label_value in (target.get("skills", {}) as Dictionary).values():
			var label := str(label_value)
			_expect(not label.contains(em_dash) and not label.contains(en_dash), "%s must not use an em dash or en dash" % label)


func _state_for_variant(variant_id: String) -> Object:
	match variant_id:
		"arachne":
			return Stage2ArachneBossState.new()
		"molewang":
			return Stage2MolewangBossState.new()
		"alice":
			return Stage3AliceBossState.new()
		"teddy_bear":
			return Stage3TeddyBearBossState.new()
	return null


func _skills_by_id(context: Dictionary, stage_id: int) -> Dictionary:
	var result := {}
	for skill_value in context.get("stage%d_boss_skill_hud_skills" % stage_id, []):
		if skill_value is Dictionary:
			var skill: Dictionary = skill_value
			result[str(skill.get("id", ""))] = skill
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
