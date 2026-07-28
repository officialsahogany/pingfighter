extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const SOUL_SUMMON_ART_ID := "soul_summon_art"
const SOUL_SUMMON_ART_UNLOCK_ID := "unlock_soul_summon_art"
const SOUL_SUMMON_ART_COLOR := Color(0.55, 0.88, 1.0, 1.0)

const _COPY_BY_LANGUAGE := {
	"ko": {
		"name": "영혼소환술",
		"description": "수호령 알을 깨워 함께 싸우게 합니다.\n소환 중에만 스킬 쿨타임과 기력이 진행됩니다.\n수호령은 하나의 공유 지속시간을 사용합니다.",
		"how_to_use": "Ctrl 또는 R3로 수호령 소환/수납",
		"motion_hint": "수호령 알을 부화해 소환",
		"perk_description": "선택 즉시 수호령 알 1개가 필드에 떨어집니다.",
	},
	"en": {
		"name": "Soul Summoning Art",
		"description": "Awaken a guardian spirit egg to fight beside you.\nSkill cooldowns and energy advance only while summoned.\nAll guardians share one duration pool.",
		"how_to_use": "Press Ctrl or R3 to summon or stow the guardian",
		"motion_hint": "Hatch a guardian spirit egg and summon it",
		"perk_description": "Choosing this immediately drops one guardian spirit egg on the field.",
	},
	"zh": {
		"name": "灵魂召唤术",
		"description": "孵化守护灵蛋，让它与你并肩作战。\n只有在召唤中，技能冷却和能量才会推进。\n所有守护灵共用一个持续时间池。",
		"how_to_use": "按 Ctrl 或 R3 召唤/收纳守护灵",
		"motion_hint": "孵化守护灵蛋并召唤",
		"perk_description": "选择后立即在场上掉落 1 枚守护灵蛋。",
	},
	"ja": {
		"name": "魂魄召喚術",
		"description": "守護霊の卵を孵化させ、共に戦わせます。\n召喚中だけスキルのクールダウンと気力が進行します。\nすべての守護霊は1つの持続時間プールを共有します。",
		"how_to_use": "Ctrl または R3 で守護霊を召喚/収納",
		"motion_hint": "守護霊の卵を孵化させて召喚",
		"perk_description": "選択すると即座に守護霊の卵が1つフィールドに落ちます。",
	},
	"es": {
		"name": "Arte de Invocación de Almas",
		"description": "Incuba un huevo de espíritu guardián para que luche contigo.\nLos enfriamientos y la energía avanzan solo mientras está invocado.\nTodos los guardianes comparten una reserva de duración.",
		"how_to_use": "Pulsa Ctrl o R3 para invocar o guardar al guardián",
		"motion_hint": "Incuba un huevo de guardián y lo invoca",
		"perk_description": "Al elegirlo, cae de inmediato un huevo de espíritu guardián en el campo.",
	},
	"pt-BR": {
		"name": "Arte de Invocação de Almas",
		"description": "Choque um ovo de espírito guardião para lutar ao seu lado.\nRecargas e energia avançam apenas enquanto ele está invocado.\nTodos os guardiões compartilham uma reserva de duração.",
		"how_to_use": "Pressione Ctrl ou R3 para invocar ou guardar o guardião",
		"motion_hint": "Choca um ovo de guardião e o invoca",
		"perk_description": "Ao escolher, um ovo de espírito guardião cai imediatamente no campo.",
	},
	"ru": {
		"name": "Искусство призыва душ",
		"description": "Выведите духа-хранителя из яйца, чтобы он сражался рядом.\nОткаты и энергия идут только во время призыва.\nВсе хранители делят один запас времени.",
		"how_to_use": "Ctrl или R3: призвать/убрать хранителя",
		"motion_hint": "Выводит духа-хранителя из яйца",
		"perk_description": "При выборе на поле сразу появляется одно яйцо духа-хранителя.",
	},
}


static func get_skill_data() -> Dictionary:
	var copy: Dictionary = _get_copy()
	return {
		"name": SOUL_SUMMON_ART_ID,
		"korean": str(copy.get("name", "영혼소환술")),
		"cost": 0.0,
		"color": SOUL_SUMMON_ART_COLOR,
		"cooldown": 0.0,
		"key": "guardian_toggle",
		"description": str(copy.get("description", "")),
		"how_to_use": str(copy.get("how_to_use", "")),
		"motion_hint": str(copy.get("motion_hint", "")),
		"effect_type": "guardian_soul_orb",
		"slot_occupancy": "active_orb",
		"cooldown_reduction_eligible": false,
		"show_cooldown": false,
		"description_max_lines": 3,
		"cleanup_policy": "perk_id_lookup",
		"fixed_level": 1,
	}


static func get_unlock_perk_data() -> Dictionary:
	var copy: Dictionary = _get_copy()
	return {
		"name": str(copy.get("name", "영혼소환술")),
		"max_level": 1,
		"descriptions": {1: str(copy.get("perk_description", ""))},
		"detail": str(copy.get("description", "")),
		"icon_color": SOUL_SUMMON_ART_COLOR,
		"tree": "common_unlock",
		"unlocks_skill": SOUL_SUMMON_ART_ID,
		"slot_occupancy": "active_orb",
		"cooldown_reduction_eligible": false,
		"show_cooldown": false,
		"cleanup_policy": "perk_id_lookup",
		"fixed_level": 1,
		"exclude_from_perk_fusion": true,
	}


static func _get_copy() -> Dictionary:
	var language := LanguageSettings.get_language()
	var value: Variant = _COPY_BY_LANGUAGE.get(language, _COPY_BY_LANGUAGE["en"])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
