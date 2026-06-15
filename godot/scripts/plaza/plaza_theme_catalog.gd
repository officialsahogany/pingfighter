extends RefCounted

const DEFAULT_STAGE_ID := 1

const STAGE_THEMES := {
	1: {
		"id": "stage1_cyber_joseon",
		"display_name": "사이버 조선",
		"floor_repeat": 380,
		"asset_slug": "cyber_joseon",
	},
	2: {
		"id": "stage2_jungle_relic",
		"display_name": "정글 유적",
		"floor_repeat": 380,
		"asset_slug": "jungle_relic",
	},
	3: {
		"id": "stage3_neon_city",
		"display_name": "네온 시티",
		"floor_repeat": 380,
		"asset_slug": "neon_city",
	},
	4: {
		"id": "stage4_moon_temple",
		"display_name": "달빛 사찰",
		"floor_repeat": 380,
		"asset_slug": "moon_temple",
	},
	5: {
		"id": "stage5_hongryun",
		"display_name": "홍련 화시장",
		"floor_repeat": 380,
		"asset_slug": "hongryun",
	},
	6: {
		"id": "stage6_tetriser",
		"display_name": "테트리서",
		"floor_repeat": 380,
		"asset_slug": "tetriser",
	},
}


static func normalize_stage_id(stage_id: int) -> int:
	if STAGE_THEMES.has(stage_id):
		return stage_id
	return DEFAULT_STAGE_ID


static func get_theme(stage_id: int) -> Dictionary:
	var normalized := normalize_stage_id(stage_id)
	var theme_value: Variant = STAGE_THEMES.get(normalized, {})
	if theme_value is Dictionary:
		return (theme_value as Dictionary).duplicate(true)
	return {}


static func get_asset_slug(stage_id: int) -> String:
	var theme := get_theme(stage_id)
	return str(theme.get("asset_slug", "cyber_joseon"))
