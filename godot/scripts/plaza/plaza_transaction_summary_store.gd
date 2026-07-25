extends RefCounted

const BANK := "bank"
const SHOP := "shop"
const BLACKSMITH := "blacksmith"
const GACHA := "gacha"
const LINGPET_STORE := "lingpet_store"
const ACADEMY := "academy"
const TAVERN := "tavern"

const FACILITY_KEYS := [
	BANK,
	SHOP,
	BLACKSMITH,
	GACHA,
	LINGPET_STORE,
	ACADEMY,
	TAVERN,
]

const CLEAR_ON_MENU_CLOSE := [
	SHOP,
	BLACKSMITH,
	GACHA,
	LINGPET_STORE,
	TAVERN,
]

var _summaries: Dictionary = {}


func record(facility: String, summary: Dictionary) -> void:
	if facility not in FACILITY_KEYS:
		return
	_summaries[facility] = summary.duplicate(true)


func get_summary(facility: String) -> Dictionary:
	var value: Variant = _summaries.get(facility, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func clear_all() -> void:
	_summaries.clear()


func clear_on_menu_close() -> void:
	for facility in CLEAR_ON_MENU_CLOSE:
		_summaries.erase(facility)
