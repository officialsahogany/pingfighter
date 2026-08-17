extends RefCounted

const LanguageSettings := preload("res://scripts/core/language_settings.gd")

const KEY_TITLE := "tower_ascent.map_overlay.title"
const KEY_CLOSE_HINT := "tower_ascent.map_overlay.close_hint"
const KEY_NODE_COMBAT := "tower_ascent.map_overlay.node.combat"
const KEY_NODE_ENRAGED := "tower_ascent.map_overlay.node.enraged"
const KEY_NODE_SHOP := "tower_ascent.map_overlay.node.shop"
const KEY_NODE_TRAINING := "tower_ascent.map_overlay.node.training"
const KEY_NODE_FALLEN_MONK := "tower_ascent.map_overlay.node.fallen_monk"
const KEY_NODE_GUARDIAN_SPRING := "tower_ascent.map_overlay.node.guardian_spring"
const KEY_NODE_REST := "tower_ascent.map_overlay.node.rest"
const KEY_STATE_CURRENT := "tower_ascent.map_overlay.state.current"
const KEY_STATE_COMPLETED := "tower_ascent.map_overlay.state.completed"
const KEY_STATE_UNVISITED := "tower_ascent.map_overlay.state.unvisited"
const KEY_STATE_VANISHED := "tower_ascent.map_overlay.state.vanished"
const KEY_STATE_LOCKED := "tower_ascent.map_overlay.state.locked"
const KEY_LEGEND_TYPES := "tower_ascent.map_overlay.legend.types"
const KEY_LEGEND_STATES := "tower_ascent.map_overlay.legend.states"

const TEXT_BY_LOCALE := {
	LanguageSettings.LANGUAGE_KOREAN: {
		KEY_TITLE: "지도",
		KEY_CLOSE_HINT: "M 또는 ESC로 닫기",
		KEY_NODE_COMBAT: "전투",
		KEY_NODE_ENRAGED: "광폭화",
		KEY_NODE_SHOP: "상점",
		KEY_NODE_TRAINING: "수련장",
		KEY_NODE_FALLEN_MONK: "파계승",
		KEY_NODE_GUARDIAN_SPRING: "수호의 샘터",
		KEY_NODE_REST: "휴식",
		KEY_STATE_CURRENT: "현재",
		KEY_STATE_COMPLETED: "완료",
		KEY_STATE_UNVISITED: "미방문",
		KEY_STATE_VANISHED: "소멸",
		KEY_STATE_LOCKED: "잠금",
		KEY_LEGEND_TYPES: "전투 · 광폭화 · 상점 · 수련장 · 파계승 · 수호의 샘터 · 휴식",
		KEY_LEGEND_STATES: "현재 · 완료 · 미방문 · 소멸 · 잠금",
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
	for locale in LanguageSettings.SUPPORTED_LANGUAGES:
		if locale != LanguageSettings.LANGUAGE_KOREAN and not TEXT_BY_LOCALE.has(locale):
			result.append(locale)
	return result
