extends RefCounted

const DEFAULT_VARIANT_BY_STAGE := {
	1: "dalji",
	2: "cheongringwi",
	3: "yeonmyo",
}

const VARIANTS := {
	"dalji": {
		"stage": 1,
		"display_name": "달지",
		"codex_key": "boss.dalji",
		"ported": true,
	},
	"gaksi": {
		"stage": 1,
		"display_name": "각시탈",
		"codex_key": "boss.gaksital",
		"ported": true,
	},
	"podo": {
		"stage": 1,
		"display_name": "포도대장",
		"codex_key": "boss.pododaejang",
		"ported": true,
	},
	"cheongringwi": {
		"stage": 2,
		"display_name": "청린귀",
		"codex_key": "boss.cheongringwi",
		"ported": true,
	},
	"molewang": {
		"stage": 2,
		"display_name": "지굴왕",
		"codex_key": "boss.molewang",
		"ported": true,
	},
	"arachne": {
		"stage": 2,
		"display_name": "거미각시",
		"codex_key": "boss.arachne",
		"boss_paddle_scale": 1.30,
		"ported": true,
	},
	"yeonmyo": {
		"stage": 3,
		"display_name": "환묘 연묘",
		"codex_key": "boss.yeonmyo",
		"ported": true,
	},
	"teddy_bear": {
		"stage": 3,
		"display_name": "포웅귀",
		"codex_key": "boss.teddy_bear",
		"ported": true,
	},
	"alice": {
		"stage": 3,
		"display_name": "옥토선자",
		"codex_key": "boss.alice",
		"ported": true,
	},
}


# Stage 1 predates the catalog and its owner field can still carry long-form
# ids, so fold known aliases onto the canonical id before any lookup.
const VARIANT_ALIASES := {
	"gaksital": "gaksi",
	"talkwangdae": "gaksi",
	"talchum": "gaksi",
	"pododaejang": "podo",
	"podo_daejang": "podo",
}

static func get_default_variant(stage_id: int) -> String:
	return str(DEFAULT_VARIANT_BY_STAGE.get(stage_id, ""))


static func normalize_variant(stage_id: int, value: Variant) -> String:
	var requested := canonicalize_variant_id(value)
	var entry: Dictionary = VARIANTS.get(requested, {})
	if not entry.is_empty() and int(entry.get("stage", -1)) == stage_id and bool(entry.get("ported", false)):
		return requested
	return get_default_variant(stage_id)


static func canonicalize_variant_id(value: Variant) -> String:
	var requested := str(value).strip_edges().to_lower()
	return str(VARIANT_ALIASES.get(requested, requested))


static func get_entry(stage_id: int, value: Variant) -> Dictionary:
	var variant_id := normalize_variant(stage_id, value)
	var entry: Dictionary = VARIANTS.get(variant_id, {})
	var result := entry.duplicate(true)
	result["id"] = variant_id
	return result


static func is_ported_variant(stage_id: int, value: Variant) -> bool:
	var requested := canonicalize_variant_id(value)
	var entry: Dictionary = VARIANTS.get(requested, {})
	return not entry.is_empty() and int(entry.get("stage", -1)) == stage_id and bool(entry.get("ported", false))
