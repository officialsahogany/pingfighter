extends SceneTree

const CharacterInfoOverlayLingpetTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_catalog_entry()
	_verify_l2d_assets()
	_verify_manifest_qa()
	if _failures.is_empty():
		print("lingpet_monkeyring_l2d_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_entry() -> void:
	_expect(LingpetCatalog.has_pet("monkeyring"), "Monkeyring should be debug-activatable through the lingpet catalog")
	_expect(not LingpetCatalog.is_pet_enabled("monkeyring"), "Monkeyring should stay out of the normal hatch pool")
	_expect(LingpetCatalog.is_pet_debug_enabled("monkeyring"), "Monkeyring should be visible in the F7 debug picker")
	_expect(LingpetCatalog.get_display_name("monkeyring") == "몽키링", "Monkeyring display name should be Korean")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "cutin_art") == "res://assets/sprites/lingpet/monkeyring_cutin_art.png", "Monkeyring should own the accepted cutin art")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "cutin_anim") == "res://assets/sprites/lingpet/monkeyring_cutin_anim.png", "Monkeyring should own the 16f acquisition Live2D sheet")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "cutin_dismiss_anim") == "res://assets/sprites/lingpet/monkeyring_click_live2d_pingpong_98f.png", "Monkeyring should use the 98f click sheet for acquisition dismiss")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "click_reaction_anim") == "res://assets/sprites/lingpet/monkeyring_click_live2d_pingpong_98f.png", "Monkeyring should use the 98f click sheet for panel click reactions")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "companion_click_reaction_anim") == "res://assets/sprites/lingpet/monkeyring_companion_click_reaction_98f.png", "Monkeyring should use the downscaled battle click reaction sheet")
	_expect(CharacterInfoOverlayLingpetTextureLoader.get_panel_live2d_visual_key("monkeyring") == "click_reaction_anim", "Character info panel should use Monkeyring's Live2D click sheet")
	var skill := LingpetCatalog.get_active_skill("monkeyring")
	_expect(str(skill.get("id", "")) == "monkeyring_headbutt", "Monkeyring should expose the debug headbutt active skill")
	_expect(LingpetSkillDispatcher.is_headbutt("monkeyring_headbutt"), "Monkeyring headbutt should resolve through the supported headbutt runtime")


func _verify_l2d_assets() -> void:
	var paths := [
		"res://assets/sprites/lingpet/monkeyring_cutin_art.png",
		"res://assets/sprites/lingpet/monkeyring_cutin_anim.png",
		"res://assets/sprites/lingpet/monkeyring_click_live2d_pingpong_98f.png",
		"res://assets/sprites/lingpet/monkeyring_companion_click_reaction_98f.png",
		"res://assets/sprites/lingpet/monkeyring_companion_walk_placeholder.png",
	]
	for path in paths:
		_expect(ResourceLoader.exists(str(path)), "%s should be import-visible to Godot" % path)
		var texture: Resource = ResourceLoader.load(str(path))
		_expect(texture is Texture2D, "%s should load as a Texture2D" % path)


func _verify_manifest_qa() -> void:
	_expect_manifest_grid("res://assets/sprites/lingpet/monkeyring_cutin_anim_manifest.json", 4, 4, 16, 1024)
	_expect_manifest_grid("res://assets/sprites/lingpet/monkeyring_click_live2d_pingpong_98f_manifest.json", 14, 7, 98, 512)
	_expect_manifest_grid("res://assets/sprites/lingpet/monkeyring_companion_click_reaction_98f_manifest.json", 14, 7, 98, 128)
	_expect_manifest_grid("res://assets/sprites/lingpet/monkeyring_companion_walk_placeholder_manifest.json", 5, 5, 25, 256)


func _expect_manifest_grid(path: String, cols: int, rows: int, frame_count: int, cell_size: int) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(data is Dictionary, "%s should parse as manifest JSON" % path)
	if not (data is Dictionary):
		return
	var runtime_sheet: Dictionary = (data as Dictionary).get("runtime_sheet", {})
	_expect(int(runtime_sheet.get("cols", 0)) == cols, "%s cols should match runtime contract" % path)
	_expect(int(runtime_sheet.get("rows", 0)) == rows, "%s rows should match runtime contract" % path)
	_expect(int(runtime_sheet.get("frame_count", 0)) == frame_count, "%s frame count should match runtime contract" % path)
	var cell: Array = runtime_sheet.get("cell_size", [])
	_expect(cell.size() == 2 and int(cell[0]) == cell_size and int(cell[1]) == cell_size, "%s cell size should match runtime contract" % path)
	var qa: Dictionary = (data as Dictionary).get("qa", {})
	_expect(int(qa.get("whole_sheet_edge_alpha", -1)) == 0, "%s should have transparent sheet edges" % path)
	_expect((qa.get("cells_with_edge_touch", []) as Array).is_empty(), "%s should not have cells touching their edge" % path)
	_expect(int(qa.get("visible_green_pixels_exact", 0)) == 0, "%s should not have visible green residue" % path)
	_expect(int(qa.get("visible_magenta_pixels_exact", 0)) == 0, "%s should not have visible magenta residue" % path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
