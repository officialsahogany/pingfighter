extends SceneTree

const REQUIRED_EXCLUDES := [
	"builds/*",
	"tools/*",
	"tests/*",
	"assets/concepts/*",
	"assets/sprites/characters/*/*_manifest.json",
	"assets/sprites/characters/*/*_pipeline-meta.json",
	"assets/sprites/characters/*/*_atlas.json",
	"assets/sprites/characters/*/*_source*.png*",
	"assets/sprites/characters/*/*_source*.jpeg*",
	"assets/sprites/characters/*/*_source*.jpg*",
	"assets/sprites/characters/*/*_preview.gif*",
	"assets/sprites/characters/*/*_4x2_256_clean.png*",
	"assets/sprites/characters/blacksmith/blacksmith_run_*_4x2_160_clean.png*",
	"assets/sprites/hud/*_manifest.json",
	"assets/sprites/hud/*_atlas.json",
	"assets/sprites/hud/*_autosprite_*.json",
	"assets/sprites/hud/commando_*_firearm_icon_imagegen_v1_alpha.png*",
	"assets/sprites/hud/commando_*_firearm_icon_imagegen_v1_source.png*",
	"assets/sprites/hud/stage1_dalji_whip_skillcard_imagegen_v1_source.png*",
	"assets/sprites/hud/stage1_layered_tree_sidewallroot_imagegen_v3_alpha.png*",
	"assets/sprites/hud/stage1_layered_tree_sidewallroot_imagegen_v3_source.png*",
	"assets/sprites/hud/stage5_hongryun_fireball_source_imagegen_v1.png*",
	"assets/sprites/hud/stage5_hongryun_motion_sprites_imagegen_v1_source.png*",
	"assets/sprites/hud/stage5_hongryun_motion_sprites_imagegen_v2_source.png*",
	"assets/sprites/hud/stage5_hongryun_snake_pot_imagegen_v1_source.png*",
	"assets/sprites/hud/stage5_hongryun_snake_pot_wallmount_v2_source.png*",
	"assets/ui/character_live2d/*_atlas.json",
	"assets/ui/character_live2d/*_manifest.json",
	"assets/ui/character_live2d/*_qc.json",
	"assets/ui/character_live2d/*_anchor*.png*",
	"assets/ui/character_live2d/*_keyart*.png*",
	"assets/ui/character_live2d/*_preview*.png*",
	"assets/ui/character_live2d/*_registered_*.png*",
	"assets/ui/character_live2d/*_layer_sheet*_alpha.png*",
	"assets/ui/character_live2d/smasher_live2d_rig_v1*",
	"assets/ui/character_live2d/smasher_live2d_rig_v2*",
	"assets/ui/character_live2d/smasher_live2d_rig_v3*",
	"assets/ui/character_live2d/smasher_live2d_rig_v4*",
	"assets/ui/character_live2d/smasher_live2d_rig_v5*",
	"assets/ui/launcher/*_source.png*",
	"assets/ui/loading/*_manifest.json",
	"assets/ui/loading/*_reveal_preview_*.png*",
	"assets/ui/loading/*nano_mosaic*.png*",
	"assets/ui/loading/stage1_loading_stained_glass_*.png*",
	"assets/ui/loading/stage2_loading_stained_glass_*.png*",
	"assets/ui/loading/stage1_loading_cyber_stained_glass_reveal_mask_v4.png*",
	"assets/ui/loading/stage1_loading_cyber_stained_glass_reveal_mask_v5.png*",
	"assets/ui/loading/stage2_loading_cyber_stained_glass_fullcolor_imagegen_v3.png*",
	"assets/ui/loading/stage2_loading_cyber_stained_glass_reveal_mask_v3.png*",
]


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://export_presets.cfg")
	_expect(source != "", "export preset config should be readable")
	var exclude_filters := _extract_exclude_filters(source)
	_expect(exclude_filters.size() >= 2, "Android and Windows export presets should both declare exclude filters")
	for exclude_filter in exclude_filters:
		for pattern in REQUIRED_EXCLUDES:
			_expect(
				_filter_has_pattern(exclude_filter, pattern),
				"export preset should exclude local-only asset pattern: %s" % pattern
			)

	print("export_preset_filters_smoke: ok")
	quit(0)


func _extract_exclude_filters(source: String) -> Array[String]:
	var filters: Array[String] = []
	for line in source.split("\n"):
		var trimmed := line.strip_edges()
		if not trimmed.begins_with("exclude_filter="):
			continue
		var raw_value := trimmed.substr("exclude_filter=".length()).strip_edges()
		if raw_value.begins_with("\"") and raw_value.ends_with("\"") and raw_value.length() >= 2:
			raw_value = raw_value.substr(1, raw_value.length() - 2)
		filters.append(raw_value)
	return filters


func _filter_has_pattern(exclude_filter: String, pattern: String) -> bool:
	for entry in exclude_filter.split(","):
		if str(entry).strip_edges() == pattern:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
