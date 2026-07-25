extends RefCounted

const NPC_NAMES := {
	"shop": "상점주인 모라",
	"bank": "은행원 도윤",
	"gacha": "가챠 오퍼레이터 루미",
	"lingpet_store": "링펫 사육사 링링",
	"blacksmith": "대장장이 강철",
	"tavern": "선술집 주인 하랑",
	"academy": "아카데미 교관 서율",
}

const MENU_SPECS := {
	"shop": {
		"title": "상점",
		"subtitle": "골드로 아이템을 사고파는 곳",
		"actions": [],
	},
	"bank": {
		"title": "은행",
		"subtitle": "골드를 맡기고 찾는 금고",
		"actions": ["예금 100G", "출금 100G", "이자 정산"],
	},
	"gacha": {
		"title": "가챠샵",
		"subtitle": "아이템 뽑기 장치",
		"actions": ["액티브 캡슐 뽑기 150G"],
	},
	"lingpet_store": {
		"title": "링펫스토어",
		"subtitle": "링펫 알과 링펫 관련 상점",
		"actions": ["공명 알 뽑기 250G", "링펫 관리"],
	},
	"blacksmith": {
		"title": "대장간",
		"subtitle": "아이템을 강화하는 공방",
		"actions": ["마지막 아이템 강화"],
	},
	"tavern": {
		"title": "선술집",
		"subtitle": "퀘스트를 받는 의뢰소",
		"actions": ["퀘스트 받기"],
	},
	"academy": {
		"title": "아카데미",
		"subtitle": "액티브 스킬을 얻고 교환하는 곳",
		"actions": ["스킬 획득", "스킬 교환"],
	},
}


static func get_menu_spec(building_type: String) -> Dictionary:
	var value: Variant = MENU_SPECS.get(building_type, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func get_npc_name(building_type: String) -> String:
	return str(NPC_NAMES.get(building_type, ""))


static func build_open_state(building_type: String, fallback_title: String) -> Dictionary:
	var spec := get_menu_spec(building_type)
	return {
		"title": str(spec.get("title", fallback_title)),
		"subtitle": str(spec.get("subtitle", "")),
		"actions": _get_string_array(spec.get("actions", [])),
		"npc_name": get_npc_name(building_type),
	}


static func _get_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value as Array:
			result.append(str(item))
	return result
