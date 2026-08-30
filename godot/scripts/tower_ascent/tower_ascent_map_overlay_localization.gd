extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const KEY_TITLE := "tower_ascent.map_overlay.title"
const KEY_CLOSE_HINT := "tower_ascent.map_overlay.close_hint"
const KEY_HUD_HINT := "tower_ascent.map_overlay.hud_hint"
const KEY_REALM_HUMAN := "tower_ascent.map_overlay.realm.human"
const KEY_REALM_IMMORTAL := "tower_ascent.map_overlay.realm.immortal"
const KEY_REALM_IMMORTAL_LOCKED := "tower_ascent.map_overlay.realm.immortal_locked"
const KEY_ENTER_IMMORTAL := "tower_ascent.map_overlay.realm.enter_immortal"
const KEY_NODE_COMBAT := "tower_ascent.map_overlay.node.combat"
const KEY_NODE_ENRAGED := "tower_ascent.map_overlay.node.enraged"
const KEY_NODE_SHOP := "tower_ascent.map_overlay.node.shop"
const KEY_NODE_TRAINING := "tower_ascent.map_overlay.node.training"
const KEY_NODE_FALLEN_MONK := "tower_ascent.map_overlay.node.fallen_monk"
const KEY_NODE_GUARDIAN_SPRING := "tower_ascent.map_overlay.node.guardian_spring"
const KEY_NODE_REST := "tower_ascent.map_overlay.node.rest"
const KEY_NODE_TAIJI_ELDER := "tower_ascent.map_overlay.node.taiji_elder"
const KEY_STATE_CURRENT := "tower_ascent.map_overlay.state.current"
const KEY_STATE_COMPLETED := "tower_ascent.map_overlay.state.completed"
const KEY_STATE_UNVISITED := "tower_ascent.map_overlay.state.unvisited"
const KEY_STATE_VANISHED := "tower_ascent.map_overlay.state.vanished"
const KEY_STATE_LOCKED := "tower_ascent.map_overlay.state.locked"

const TEXT_BY_LOCALE := {
	LanguageSettings.LANGUAGE_KOREAN: {
		KEY_TITLE: "지도",
		KEY_CLOSE_HINT: "M 또는 ESC로 닫기",
		KEY_HUD_HINT: "M 지도",
		KEY_REALM_HUMAN: "인간계",
		KEY_REALM_IMMORTAL: "신선계",
		KEY_REALM_IMMORTAL_LOCKED: "10~12층 신선계 잠김",
		KEY_ENTER_IMMORTAL: "신선계 진입",
		KEY_NODE_COMBAT: "전투",
		KEY_NODE_ENRAGED: "광폭화",
		KEY_NODE_SHOP: "상점",
		KEY_NODE_TRAINING: "수련장",
		KEY_NODE_FALLEN_MONK: "파계승",
		KEY_NODE_GUARDIAN_SPRING: "수호의 샘터",
		KEY_NODE_REST: "모닥불",
		KEY_NODE_TAIJI_ELDER: "태극노인",
		KEY_STATE_CURRENT: "현재",
		KEY_STATE_COMPLETED: "완료",
		KEY_STATE_UNVISITED: "미방문",
		KEY_STATE_VANISHED: "소멸",
		KEY_STATE_LOCKED: "잠금",
	},
	LanguageSettings.LANGUAGE_ENGLISH: {
		KEY_NODE_REST: "Campfire",
		KEY_NODE_TAIJI_ELDER: "Taiji Elder",
	},
	LanguageSettings.LANGUAGE_CHINESE: {
		KEY_NODE_REST: "篝火",
		KEY_NODE_TAIJI_ELDER: "太极老人",
	},
	LanguageSettings.LANGUAGE_JAPANESE: {
		KEY_NODE_REST: "焚き火",
		KEY_NODE_TAIJI_ELDER: "太極老人",
	},
	LanguageSettings.LANGUAGE_SPANISH: {
		KEY_NODE_REST: "Hoguera",
		KEY_NODE_TAIJI_ELDER: "Anciano del Taiji",
	},
	LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL: {
		KEY_NODE_REST: "Fogueira",
		KEY_NODE_TAIJI_ELDER: "Ancião do Taiji",
	},
	LanguageSettings.LANGUAGE_RUSSIAN: {
		KEY_NODE_REST: "Костёр",
		KEY_NODE_TAIJI_ELDER: "Старец Тайцзи",
	},
}

const NODE_KIND_KEYS := {
	"boss": KEY_NODE_COMBAT,
	"combat": KEY_NODE_COMBAT,
	"enraged": KEY_NODE_ENRAGED,
	"shop": KEY_NODE_SHOP,
	"training": KEY_NODE_TRAINING,
	"fallen_monk": KEY_NODE_FALLEN_MONK,
	"guardian_spring": KEY_NODE_GUARDIAN_SPRING,
	"rest": KEY_NODE_REST,
	"taiji_elder": KEY_NODE_TAIJI_ELDER,
}


static func text(key: String) -> String:
	var locale := LanguageSettings.get_language()
	var locale_text: Dictionary = TEXT_BY_LOCALE.get(locale, {})
	var fallback_text: Dictionary = TEXT_BY_LOCALE.get(LanguageSettings.LANGUAGE_KOREAN, {})
	return str(locale_text.get(key, fallback_text.get(key, key)))


static func node_kind_label(node_kind: String, enraged: bool = false) -> String:
	if enraged or node_kind.strip_edges().to_lower() == "enraged":
		return text(KEY_NODE_ENRAGED)
	return text(str(NODE_KIND_KEYS.get(node_kind.strip_edges().to_lower(), KEY_NODE_COMBAT)))


static func realm_label(realm_kind: String) -> String:
	if realm_kind.strip_edges().to_lower() == "immortal_realm":
		return text(KEY_REALM_IMMORTAL)
	return text(KEY_REALM_HUMAN)


static func node_state_label(
	current: bool,
	completed: bool,
	vanished: bool,
	locked: bool
) -> String:
	if current:
		return text(KEY_STATE_CURRENT)
	if vanished:
		return text(KEY_STATE_VANISHED)
	if locked:
		return text(KEY_STATE_LOCKED)
	if completed:
		return text(KEY_STATE_COMPLETED)
	return ""


static func get_registered_keys() -> Array[String]:
	var result: Array[String] = []
	var korean_text: Dictionary = TEXT_BY_LOCALE.get(LanguageSettings.LANGUAGE_KOREAN, {})
	for key_value in korean_text.keys():
		result.append(str(key_value))
	result.sort()
	return result


static func get_missing_translation_locales() -> Array[String]:
	var result: Array[String] = []
	var registered_keys := get_registered_keys()
	for locale in LanguageSettings.SUPPORTED_LANGUAGES:
		if locale == LanguageSettings.LANGUAGE_KOREAN:
			continue
		var locale_text: Dictionary = TEXT_BY_LOCALE.get(locale, {})
		for key in registered_keys:
			if not locale_text.has(key):
				result.append(locale)
				break
	return result
