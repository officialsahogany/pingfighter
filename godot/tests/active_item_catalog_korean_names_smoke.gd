extends SceneTree

const ActiveItemCatalog := preload("res://scripts/items/active_item_catalog.gd")
const ActiveItemPickupFeedback := preload("res://scripts/items/active_item_pickup_feedback.gd")

const EXPECTED_DISPLAY_NAMES := {
	"gauge_charge": "에너지드링크",
	"life_elixir": "생명수",
	"ammo_box": "탄약상자",
	"doping_potion": "도핑주사기",
	"vitamin_pill": "비타민드링크",
	"strange_vial": "기묘한 약병",
	"aipill": "AI 알약",
	"pandora_box": "판도라의 상자",
	"grenade": "수류탄",
	"flare": "조명탄",
	"tear_gas": "최루탄",
	"dynamite": "다이너마이트",
	"molotov": "화염병",
	"stopwatch": "스탑워치",
	"magnet_field": "자기장",
	"long_boost": "거대화포션",
	"regeneration_potion": "재생물약",
	"holy_barrier": "홀리베리어",
	"wall": "벽돌",
	"boomerang": "부메랑",
	"banana": "바나나",
	"soap": "비누",
	"spider_mine": "스파이더지뢰",
}

var _failures: Array[String] = []


func _init() -> void:
	_verify_catalog_display_names()
	_verify_pickup_fallback_names()

	if _failures.is_empty():
		print("active_item_catalog_korean_names_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_display_names() -> void:
	var catalog := ActiveItemCatalog.new()
	for item_name in EXPECTED_DISPLAY_NAMES.keys():
		var expected_name: String = str(EXPECTED_DISPLAY_NAMES[item_name])
		var item_data: Dictionary = catalog.build_item_by_name(str(item_name))
		_expect(not item_data.is_empty(), "%s should build from the active item catalog" % item_name)
		_expect(str(item_data.get("display_name", "")) == expected_name, "%s should use Korean display text" % item_name)
		_expect(catalog.get_display_name(str(item_name)) == expected_name, "%s get_display_name should use Korean display text" % item_name)


func _verify_pickup_fallback_names() -> void:
	var feedback := ActiveItemPickupFeedback.new()
	for item_name in EXPECTED_DISPLAY_NAMES.keys():
		if item_name == "ammo_box" or item_name == "doping_potion":
			continue
		var expected_name: String = str(EXPECTED_DISPLAY_NAMES[item_name])
		_expect(str(feedback._get_korean_item_name(str(item_name))) == expected_name, "%s pickup fallback should use Korean display text" % item_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
