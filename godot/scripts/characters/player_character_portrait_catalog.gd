extends RefCounted

## Canonical player face-crop metadata shared by character select and the
## match-ending scoreboard. Keeping the crop anchors beside the source path
## prevents each renderer from drifting to a different character identity.

const PORTRAIT_SPECS := {
	"smasher": {
		"path": "res://assets/ui/character_live2d/han_miryang_ornate_exact5head_v5_upperbody_autosprite_v1_still_hq1024_safe.png",
		"face_focus": Vector2(0.52, 0.20),
		"source_height_ratio": 0.34,
	},
	"soldier": {
		"path": "res://assets/ui/character_live2d/rena_hwangyeok_bandit_upperbody_idle_loop49_autosprite_v20_still_hardcut.png",
		"face_focus": Vector2(0.60, 0.20),
		"source_height_ratio": 0.34,
	},
	"blacksmith": {
		"path": "res://assets/ui/character_live2d/baltor_kohaku_hwangyeok_compact4p5head_idle_loop49_autosprite_v2_still_safe.png",
		"face_focus": Vector2(0.44, 0.21),
		"source_height_ratio": 0.35,
	},
	"optimus": {
		"path": "res://assets/ui/character_cards/optimus_engineer_glasses_manual_fishnet_l2d_samecrop_cutout_v1.png",
		"face_focus": Vector2(0.50, 0.19),
		"source_height_ratio": 0.32,
	},
	"viper": {
		"path": "res://assets/ui/character_live2d/viper_serin_hwangyeok_bandit_upperbody_autosprite_legacy1536_v1_still_hq1536_mattehair_safe.png",
		"face_focus": Vector2(0.55, 0.21),
		"source_height_ratio": 0.33,
	},
}


static func get_portrait_spec(runtime_character_id: Variant) -> Dictionary:
	var character_id := _normalize_runtime_id(runtime_character_id)
	var value: Variant = PORTRAIT_SPECS.get(character_id, PORTRAIT_SPECS["smasher"])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func get_portrait_path(runtime_character_id: Variant) -> String:
	return str(get_portrait_spec(runtime_character_id).get("path", ""))


static func get_portrait_face_focus(runtime_character_id: Variant) -> Vector2:
	var value: Variant = get_portrait_spec(runtime_character_id).get("face_focus", Vector2(0.5, 0.28))
	return value as Vector2 if value is Vector2 else Vector2(0.5, 0.28)


static func get_portrait_source_height_ratio(runtime_character_id: Variant) -> float:
	return clampf(float(get_portrait_spec(runtime_character_id).get("source_height_ratio", 0.38)), 0.24, 0.46)


static func _normalize_runtime_id(value: Variant) -> String:
	var character_id := str(value).strip_edges().to_lower()
	match character_id:
		"commando", "horan":
			return "soldier"
		"kohaku", "baltor":
			return "blacksmith"
		"io":
			return "optimus"
		"serin":
			return "viper"
		"ufo_player", "mika", "han_miryang":
			return "smasher"
	return character_id if PORTRAIT_SPECS.has(character_id) else "smasher"
