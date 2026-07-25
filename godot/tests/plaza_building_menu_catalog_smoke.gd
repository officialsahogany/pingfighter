extends SceneTree

const PlazaBuildingMenuCatalog := preload("res://scripts/plaza/plaza_building_menu_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	var expected := {
		"shop": ["상점", "골드로 아이템을 사고파는 곳", "상점주인 모라", []],
		"bank": ["은행", "골드를 맡기고 찾는 금고", "은행원 도윤", ["예금 100G", "출금 100G", "이자 정산"]],
		"gacha": ["가챠샵", "아이템 뽑기 장치", "가챠 오퍼레이터 루미", ["액티브 캡슐 뽑기 150G"]],
		"lingpet_store": ["링펫스토어", "링펫 알과 링펫 관련 상점", "링펫 사육사 링링", ["공명 알 뽑기 250G", "링펫 관리"]],
		"blacksmith": ["대장간", "아이템을 강화하는 공방", "대장장이 강철", ["마지막 아이템 강화"]],
		"tavern": ["선술집", "퀘스트를 받는 의뢰소", "선술집 주인 하랑", ["퀘스트 받기"]],
		"academy": ["아카데미", "액티브 스킬을 얻고 교환하는 곳", "아카데미 교관 서율", ["스킬 획득", "스킬 교환"]],
	}
	for building_type in expected.keys():
		var values: Array = expected[building_type]
		var state := PlazaBuildingMenuCatalog.build_open_state(str(building_type), "fallback")
		_expect_eq(str(state.get("title", "")), str(values[0]), "%s title" % building_type)
		_expect_eq(str(state.get("subtitle", "")), str(values[1]), "%s subtitle" % building_type)
		_expect_eq(str(state.get("npc_name", "")), str(values[2]), "%s NPC" % building_type)
		_expect_eq(state.get("actions", []), values[3], "%s actions" % building_type)

	var first_bank := PlazaBuildingMenuCatalog.get_menu_spec("bank")
	(first_bank.get("actions", []) as Array).clear()
	var second_bank := PlazaBuildingMenuCatalog.get_menu_spec("bank")
	_expect_eq((second_bank.get("actions", []) as Array).size(), 3, "menu specs should be deep-copied")
	var unknown := PlazaBuildingMenuCatalog.build_open_state("unknown", "미확인 건물")
	_expect_eq(str(unknown.get("title", "")), "미확인 건물", "unknown building fallback title")
	_expect_eq(str(unknown.get("subtitle", "x")), "", "unknown building subtitle")
	_expect_eq(str(unknown.get("npc_name", "x")), "", "unknown building NPC")
	_expect((unknown.get("actions", []) as Array).is_empty(), "unknown building actions")

	if _failures.is_empty():
		print("plaza_building_menu_catalog_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [label, expected, actual])
