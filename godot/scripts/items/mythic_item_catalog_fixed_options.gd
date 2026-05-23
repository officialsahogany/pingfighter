extends RefCounted

const SPEEDGEAR_FIXED_OPTIONS := [
	{
		"label": "방향 전환",
		"value": "+150",
		"unit": "%",
	},
]

const GRAVITYBELT_FIXED_OPTIONS := [
	{
		"label": "이동 반응",
		"value": "즉시",
		"unit": "",
	},
	{
		"label": "감속",
		"value": "없음",
		"unit": "",
	},
]

const REVIVAL_FIXED_OPTIONS := [
	{
		"label": "패배 방지",
		"value": "1",
		"unit": "회",
	},
]

const GOLD_BAR_FIXED_OPTIONS := [
	{
		"label": "판매가",
		"value": "2000",
		"unit": "골드",
	},
	{
		"label": "이동속도",
		"value": "-30",
		"unit": "%",
	},
]

const REINFORCED_BOOMERANG_GAUNTLET_FIXED_OPTIONS := [
	{"label": "넉백 거리", "value": "+40", "unit": "%"},
	{"label": "스턴 시간", "value": "+60", "unit": "%"},
]

const DASHHOLDER_FIXED_OPTIONS := [
	{
		"label": "대쉬 개수",
		"value": "+1",
		"unit": "개",
	},
]

const SAGE_RING_FIXED_OPTIONS := [
	{
		"label": "모든 퍽 레벨",
		"value": "+1",
		"unit": "",
	},
]

const ITEM_FIXED_OPTIONS := {
	"speedgear": SPEEDGEAR_FIXED_OPTIONS,
	"gravitybelt": GRAVITYBELT_FIXED_OPTIONS,
	"revival": REVIVAL_FIXED_OPTIONS,
	"gold_bar": GOLD_BAR_FIXED_OPTIONS,
	"reinforced_boomerang_gauntlet": REINFORCED_BOOMERANG_GAUNTLET_FIXED_OPTIONS,
	"dashholder": DASHHOLDER_FIXED_OPTIONS,
	"sage_ring": SAGE_RING_FIXED_OPTIONS,
}


func get_fixed_options(item_name: String) -> Array:
	if not ITEM_FIXED_OPTIONS.has(item_name):
		return []
	var options: Array = ITEM_FIXED_OPTIONS[item_name]
	return options.duplicate(true)
