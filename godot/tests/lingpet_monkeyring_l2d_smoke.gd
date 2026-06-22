extends SceneTree

const CharacterInfoOverlayLingpetTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const LingpetCatalog := preload("res://scripts/lingpet/lingpet_catalog.gd")
const LingpetSkillDispatcher := preload("res://scripts/lingpet/lingpet_skill_dispatcher.gd")
const NEIGHBOR_OFFSETS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var _failures: Array[String] = []


func _init() -> void:
	_verify_catalog_entry()
	_verify_l2d_assets()
	_verify_manifest_qa()
	_verify_pixel_qa()
	if _failures.is_empty():
		print("lingpet_monkeyring_l2d_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_catalog_entry() -> void:
	_expect(LingpetCatalog.has_pet("monkeyring"), "Monkeyring should be debug-activatable through the lingpet catalog")
	_expect(LingpetCatalog.is_pet_enabled("monkeyring"), "Monkeyring should now be a live hatch-pool pet")
	_expect(LingpetCatalog.get_debug_pet_ids().has("monkeyring"), "Monkeyring should still be reachable from the F7 picker")
	_expect(LingpetCatalog.get_display_name("monkeyring") == "빠나몽", "Monkeyring display name should be Korean")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "cutin_art") == "res://assets/sprites/lingpet/monkeyring_cutin_art.png", "Monkeyring should own the accepted cutin art")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "cutin_anim") == "res://assets/sprites/lingpet/monkeyring_cutin_anim.png", "Monkeyring should own the 16f acquisition Live2D sheet")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "cutin_dismiss_anim") == "res://assets/sprites/lingpet/monkeyring_cutin_dismiss_anim.png", "Monkeyring acquisition dismiss should use the dedicated capped dismiss sheet (decoupled 2026-06-21 from the full-res click sheet so the hatch prewarm stays small)")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "click_reaction_anim") == "res://assets/sprites/lingpet/monkeyring_click_live2d_pingpong_98f.png", "Monkeyring should use the 98f click sheet for panel click reactions")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "companion_click_reaction_anim") == "res://assets/sprites/lingpet/monkeyring_companion_click_reaction_98f.png", "Monkeyring should use the downscaled battle click reaction sheet")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "companion_idle") == "res://assets/sprites/lingpet/monkeyring_companion_idle.png", "Monkeyring should use the accepted rear-view idle companion sheet")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "companion_move_left") == "res://assets/sprites/lingpet/monkeyring_companion_move_left.png", "Monkeyring should use the accepted rear-3Q left movement companion sheet")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "companion_move_right") == "res://assets/sprites/lingpet/monkeyring_companion_move_right.png", "Monkeyring should use the accepted rear-3Q right movement companion sheet")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "companion_walk") == "res://assets/sprites/lingpet/monkeyring_companion_move_right.png", "Monkeyring generic walk should fall back to the accepted right movement sheet")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "companion_strike") == "res://assets/sprites/lingpet/monkeyring_companion_strike.png", "Monkeyring companion strike should use the accepted rear tail-slap strike sheet")
	_expect(LingpetCatalog.get_visual_path("monkeyring", "companion_cast") == "res://assets/sprites/lingpet/monkeyring_companion_wild_roar_cast.png", "Monkeyring companion cast should use the accepted rear Wild Roar cast sheet")
	var effect_text := LingpetCatalog.get_effect_text("monkeyring")
	_expect(effect_text.find("디버그") < 0, "Monkeyring is now a production hatch pet, so its player-facing effect text must not expose debug wording")
	_expect(effect_text.find("바나나 슬라이스") >= 0 and effect_text.find("야생의 포효") >= 0, "Monkeyring effect text should describe its two live active skills")
	_expect(effect_text.find("공용 풀") >= 0, "Monkeyring effect text should defer passive details to the shared passive loadout")
	_expect(effect_text.find("placeholder") < 0, "Monkeyring effect text should not keep the old companion placeholder wording")
	_expect(CharacterInfoOverlayLingpetTextureLoader.get_panel_live2d_visual_key("monkeyring") == "click_reaction_anim", "Character info panel should use Monkeyring's Live2D click sheet")
	var skill := LingpetCatalog.get_active_skill("monkeyring")
	_expect(str(skill.get("id", "")) == "monkeyring_banana_slice", "Monkeyring should expose Banana Slice as its active skill")
	_expect(LingpetSkillDispatcher.is_banana_slice("monkeyring_banana_slice"), "Monkeyring Banana Slice should resolve through the supported banana-slice runtime")


func _verify_l2d_assets() -> void:
	var paths := [
		"res://assets/sprites/lingpet/monkeyring_cutin_art.png",
		"res://assets/sprites/lingpet/monkeyring_cutin_anim.png",
		"res://assets/sprites/lingpet/monkeyring_click_live2d_pingpong_98f.png",
		"res://assets/sprites/lingpet/monkeyring_companion_click_reaction_98f.png",
		"res://assets/sprites/lingpet/monkeyring_companion_idle.png",
		"res://assets/sprites/lingpet/monkeyring_companion_move_left.png",
		"res://assets/sprites/lingpet/monkeyring_companion_move_right.png",
		"res://assets/sprites/lingpet/monkeyring_companion_strike.png",
		"res://assets/sprites/lingpet/monkeyring_companion_wild_roar_cast.png",
	]
	for path in paths:
		_expect(ResourceLoader.exists(str(path)), "%s should be import-visible to Godot" % path)
		var texture: Resource = ResourceLoader.load(str(path))
		_expect(texture is Texture2D, "%s should load as a Texture2D" % path)


func _verify_manifest_qa() -> void:
	_expect_manifest_grid("res://assets/sprites/lingpet/monkeyring_cutin_anim_manifest.json", 4, 4, 16, 2048)
	_expect_manifest_grid("res://assets/sprites/lingpet/monkeyring_click_live2d_pingpong_98f_manifest.json", 14, 7, 98, 1024)
	_expect_manifest_grid("res://assets/sprites/lingpet/monkeyring_companion_click_reaction_98f_manifest.json", 14, 7, 98, 256)
	_expect_companion_idle_manifest("res://assets/sprites/lingpet/monkeyring_companion_idle_manifest.json")
	_expect_companion_move_manifest("res://assets/sprites/lingpet/monkeyring_companion_move_pair_manifest.json")
	_expect_companion_strike_manifest("res://assets/sprites/lingpet/monkeyring_companion_strike_manifest.json")
	_expect_companion_wild_roar_cast_manifest("res://assets/sprites/lingpet/monkeyring_companion_wild_roar_cast_manifest.json")
	_expect_manifest_one_banana_contract("res://assets/sprites/lingpet/monkeyring_cutin_anim_manifest.json", "acquisition cut-in", false)
	_expect_manifest_one_banana_contract("res://assets/sprites/lingpet/monkeyring_click_live2d_pingpong_98f_manifest.json", "click Live2D", true)
	_expect_manifest_one_banana_contract("res://assets/sprites/lingpet/monkeyring_companion_click_reaction_98f_manifest.json", "companion click Live2D", true)


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
	if qa.has("low_alpha_dark_pixel_count"):
		_expect(int(qa.get("low_alpha_dark_pixel_count", 999999)) <= 8192, "%s should not keep black low-alpha matte residue" % path)
	if qa.has("edge_key_spill_pixel_count"):
		_expect(int(qa.get("edge_key_spill_pixel_count", 999999)) <= 50000, "%s should keep magenta edge spill below the visual QA ceiling" % path)


func _expect_companion_idle_manifest(path: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(source)
	_expect(data is Dictionary, "%s should parse as manifest JSON" % path)
	if not (data is Dictionary):
		return
	var runtime_sheet: Dictionary = (data as Dictionary).get("runtime_sheet", {})
	_expect(int(runtime_sheet.get("cols", 0)) == 5, "%s cols should match runtime contract" % path)
	_expect(int(runtime_sheet.get("rows", 0)) == 5, "%s rows should match runtime contract" % path)
	_expect(int(runtime_sheet.get("frame_count", 0)) == 25, "%s frame count should match runtime contract" % path)
	var cell: Array = runtime_sheet.get("cell_size", [])
	_expect(cell.size() == 2 and int(cell[0]) == 256 and int(cell[1]) == 256, "%s cell size should match runtime contract" % path)
	var qa: Dictionary = (data as Dictionary).get("qa", {})
	_expect(int(qa.get("edge_alpha_max", -1)) == 0, "%s should have transparent sheet edges" % path)
	_expect((qa.get("edge_touch_frames", []) as Array).is_empty(), "%s should not have cells touching their edge" % path)
	_expect(int(qa.get("visible_green_pixels", -1)) == 0, "%s should not have visible green residue" % path)
	_expect(int(qa.get("visible_magenta_pixels", -1)) == 0, "%s should not have visible magenta residue" % path)
	_expect(source.find("monkeyring_companion_idle_rear_breathe_25f_v1") >= 0, "%s should preserve the accepted idle asset id" % path)
	_expect(source.find("rear/back-view based") >= 0 and source.find("breathing") >= 0, "%s should memorize the rear idle breathing contract" % path)


func _expect_companion_move_manifest(path: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(source)
	_expect(data is Dictionary, "%s should parse as manifest JSON" % path)
	if not (data is Dictionary):
		return
	var runtime_sheet: Dictionary = (data as Dictionary).get("runtime_sheet", {})
	_expect(int(runtime_sheet.get("cols", 0)) == 5, "%s cols should match runtime contract" % path)
	_expect(int(runtime_sheet.get("rows", 0)) == 5, "%s rows should match runtime contract" % path)
	_expect(int(runtime_sheet.get("frame_count", 0)) == 25, "%s frame count should match runtime contract" % path)
	var cell: Array = runtime_sheet.get("cell_size", [])
	_expect(cell.size() == 2 and int(cell[0]) == 256 and int(cell[1]) == 256, "%s cell size should match runtime contract" % path)
	_expect(source.find("monkeyring_companion_rear_3q_move_pair_25f_v1") >= 0, "%s should preserve the accepted move asset id" % path)
	_expect(source.find("Maribo-like rear-3Q side slice") >= 0, "%s should memorize the Maribo-like rear-3Q side-slice movement contract" % path)
	_expect(source.find("selected_source_frame_indices") >= 0 and source.find("runtime_frame_source_sequence") >= 0, "%s should record the AutoSprite-derived source-frame selection" % path)
	_expect(source.find("Frames after source index 4 rotate toward side/front") >= 0, "%s should record why side/front-rotating raw frames were excluded" % path)
	_expect(source.find("\"companion_move_left\"") >= 0 and source.find("\"companion_move_right\"") >= 0, "%s should record the intended companion movement keys" % path)
	var qa: Dictionary = (data as Dictionary).get("qa", {})
	_expect_sheet_pair_qa(qa.get("left", {}), "%s left sheet" % path)
	_expect_sheet_pair_qa(qa.get("right", {}), "%s right sheet" % path)


func _expect_companion_strike_manifest(path: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(source)
	_expect(data is Dictionary, "%s should parse as manifest JSON" % path)
	if not (data is Dictionary):
		return
	var runtime_sheet: Dictionary = (data as Dictionary).get("runtime_sheet", {})
	_expect(int(runtime_sheet.get("cols", 0)) == 5, "%s cols should match runtime contract" % path)
	_expect(int(runtime_sheet.get("rows", 0)) == 5, "%s rows should match runtime contract" % path)
	_expect(int(runtime_sheet.get("frame_count", 0)) == 25, "%s frame count should match runtime contract" % path)
	var cell: Array = runtime_sheet.get("cell_size", [])
	_expect(cell.size() == 2 and int(cell[0]) == 256 and int(cell[1]) == 256, "%s cell size should match runtime contract" % path)
	_expect(source.find("monkeyring_companion_strike_tail_slap_25f_v1") >= 0, "%s should preserve the accepted strike asset id" % path)
	_expect(source.find("cmqbcx75u000bch77g70bds58") >= 0, "%s should preserve the accepted AutoSprite character id" % path)
	_expect(source.find("runtime_frame_source_sequence") >= 0, "%s should record the AutoSprite-derived source-frame remap" % path)
	_expect(source.find("\"companion_strike\"") >= 0, "%s should record the intended companion strike key" % path)
	var qa: Dictionary = (data as Dictionary).get("qa", {})
	_expect(int(qa.get("edge_alpha_max", -1)) == 0, "%s should have transparent sheet edges" % path)
	_expect((qa.get("edge_touch_frames", []) as Array).is_empty(), "%s should not have cells touching their edge" % path)
	_expect(int(qa.get("visible_green_pixels", -1)) == 0, "%s should not have visible green residue" % path)
	_expect(int(qa.get("visible_magenta_pixels", -1)) == 0, "%s should not have visible magenta residue" % path)


func _expect_companion_wild_roar_cast_manifest(path: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(source)
	_expect(data is Dictionary, "%s should parse as manifest JSON" % path)
	if not (data is Dictionary):
		return
	var runtime_sheet: Dictionary = (data as Dictionary).get("runtime_sheet", {})
	_expect(int(runtime_sheet.get("cols", 0)) == 5, "%s cols should match runtime contract" % path)
	_expect(int(runtime_sheet.get("rows", 0)) == 5, "%s rows should match runtime contract" % path)
	_expect(int(runtime_sheet.get("frame_count", 0)) == 25, "%s frame count should match runtime contract" % path)
	var cell: Array = runtime_sheet.get("cell_size", [])
	_expect(cell.size() == 2 and int(cell[0]) == 256 and int(cell[1]) == 256, "%s cell size should match runtime contract" % path)
	_expect(source.find("monkeyring_companion_wild_roar_cast_25f_v1") >= 0, "%s should preserve the accepted Wild Roar cast asset id" % path)
	_expect(source.find("wf_7a8e6d3a-0b34-43d2-a9bc-01656b8df6d7") >= 0, "%s should preserve the accepted AutoSprite workflow id" % path)
	_expect(source.find("runtime_frame_source_sequence") >= 0, "%s should record the AutoSprite-derived source-frame remap" % path)
	_expect(source.find("rear idle/crouch") >= 0 and source.find("spreads both arms upward/outward") >= 0, "%s should record the requested Wild Roar pose contract" % path)
	_expect(source.find("\"companion_cast\"") >= 0, "%s should record the intended companion cast key" % path)
	var qa: Dictionary = (data as Dictionary).get("qa", {})
	_expect(int(qa.get("edge_alpha_max", -1)) == 0, "%s should have transparent sheet edges" % path)
	_expect((qa.get("edge_touch_frames", []) as Array).is_empty(), "%s should not have cells touching their edge" % path)
	_expect(int(qa.get("visible_green_pixels", -1)) == 0, "%s should not have visible green residue" % path)
	_expect(int(qa.get("visible_magenta_pixels", -1)) == 0, "%s should not have visible magenta residue" % path)


func _expect_sheet_pair_qa(value: Variant, label: String) -> void:
	_expect(value is Dictionary, "%s QA should be a dictionary" % label)
	if not (value is Dictionary):
		return
	var qa := value as Dictionary
	_expect(int(qa.get("edge_alpha_max", -1)) == 0, "%s should have transparent sheet edges" % label)
	_expect((qa.get("edge_touch_frames", []) as Array).is_empty(), "%s should not have cells touching their edge" % label)
	_expect(int(qa.get("visible_green_pixels", -1)) == 0, "%s should not have visible green residue" % label)
	_expect(int(qa.get("visible_magenta_pixels", -1)) == 0, "%s should not have visible magenta residue" % label)


func _expect_manifest_one_banana_contract(path: String, label: String, requires_chomp: bool) -> void:
	var source := FileAccess.get_file_as_string(path)
	_expect(source.find("monkeyring_magenta") >= 0, "%s manifest should record the magenta source branch" % label)
	_expect(source.find("source_magenta_art") >= 0 or source.find("flat #ff00ff") >= 0, "%s manifest should record the flat magenta source art" % label)
	var has_one_banana_contract := source.find("EXACTLY ONE banana") >= 0 or source.find("one-banana") >= 0 or source.find("ONLY pouch banana") >= 0 or source.find("only belly-pouch banana") >= 0
	_expect(has_one_banana_contract, "%s manifest should preserve the one-banana prompt/operation contract" % label)
	if requires_chomp:
		_expect(source.find("banana_chomp") >= 0 or source.find("pulls the only belly-pouch banana out and eats it") >= 0, "%s manifest should preserve the banana pull-and-eat click contract" % label)
	_expect(source.find("several pouch bananas") < 0, "%s manifest should not keep the old multi-banana wording" % label)


func _verify_pixel_qa() -> void:
	var cutin := _load_image("res://assets/sprites/lingpet/monkeyring_cutin_anim.png")
	_verify_cell_edges(cutin, 4, 4, 16, 2048, "Monkeyring acquisition cut-in")
	_verify_no_enclosed_low_alpha_components(
		cutin,
		4,
		16,
		2048,
		Rect2i(720, 670, 600, 440),
		64,
		960,
		"Monkeyring acquisition neck/choker ROI"
	)

	var click := _load_image("res://assets/sprites/lingpet/monkeyring_click_live2d_pingpong_98f.png")
	_verify_cell_edges(click, 14, 7, 98, 1024, "Monkeyring click Live2D")
	_verify_no_large_click_cheek_alpha_disks(click)
	_verify_click_banana_regions(click)

	var companion := _load_image("res://assets/sprites/lingpet/monkeyring_companion_click_reaction_98f.png")
	_verify_cell_edges(companion, 14, 7, 98, 256, "Monkeyring companion click Live2D")

	var companion_idle := _load_image("res://assets/sprites/lingpet/monkeyring_companion_idle.png")
	_verify_cell_edges(companion_idle, 5, 5, 25, 256, "Monkeyring rear idle companion")

	var companion_move_left := _load_image("res://assets/sprites/lingpet/monkeyring_companion_move_left.png")
	_verify_cell_edges(companion_move_left, 5, 5, 25, 256, "Monkeyring rear-3Q left movement companion")

	var companion_move_right := _load_image("res://assets/sprites/lingpet/monkeyring_companion_move_right.png")
	_verify_cell_edges(companion_move_right, 5, 5, 25, 256, "Monkeyring rear-3Q right movement companion")

	var companion_strike := _load_image("res://assets/sprites/lingpet/monkeyring_companion_strike.png")
	_verify_cell_edges(companion_strike, 5, 5, 25, 256, "Monkeyring rear tail-slap strike companion")

	var companion_wild_roar_cast := _load_image("res://assets/sprites/lingpet/monkeyring_companion_wild_roar_cast.png")
	_verify_cell_edges(companion_wild_roar_cast, 5, 5, 25, 256, "Monkeyring rear Wild Roar cast companion")


func _load_image(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		_expect(false, "%s should load as an Image for pixel QA" % path)
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	return image


func _verify_cell_edges(image: Image, cols: int, rows: int, frame_count: int, cell_size: int, label: String) -> void:
	_expect(image.get_width() == cols * cell_size, "%s width should match its runtime grid" % label)
	_expect(image.get_height() == rows * cell_size, "%s height should match its runtime grid" % label)
	for index in range(frame_count):
		var cell_x := (index % cols) * cell_size
		var cell_y := int(index / cols) * cell_size
		for x in range(cell_size):
			_expect(_alpha8(image, cell_x + x, cell_y) == 0, "%s frame %d top edge should be transparent" % [label, index])
			_expect(_alpha8(image, cell_x + x, cell_y + cell_size - 1) == 0, "%s frame %d bottom edge should be transparent" % [label, index])
		for y in range(cell_size):
			_expect(_alpha8(image, cell_x, cell_y + y) == 0, "%s frame %d left edge should be transparent" % [label, index])
			_expect(_alpha8(image, cell_x + cell_size - 1, cell_y + y) == 0, "%s frame %d right edge should be transparent" % [label, index])


func _verify_no_enclosed_low_alpha_components(
	image: Image,
	cols: int,
	frame_count: int,
	cell_size: int,
	roi: Rect2i,
	threshold: int,
	min_area: int,
	label: String
) -> void:
	for index in range(frame_count):
		var components := _find_enclosed_low_alpha_components(image, index, cols, cell_size, roi, threshold, min_area)
		_expect(components.is_empty(), "%s frame %d should not contain enclosed low-alpha components: %s" % [label, index, str(components)])


func _find_enclosed_low_alpha_components(
	image: Image,
	frame_index: int,
	cols: int,
	cell_size: int,
	roi: Rect2i,
	threshold: int,
	min_area: int
) -> Array:
	var cell_x := (frame_index % cols) * cell_size
	var cell_y := int(frame_index / cols) * cell_size
	var width := roi.size.x
	var height := roi.size.y
	var seen := PackedByteArray()
	seen.resize(width * height)
	var components: Array = []
	for y in range(height):
		for x in range(width):
			var start_index := y * width + x
			if seen[start_index] != 0:
				continue
			if _alpha8(image, cell_x + roi.position.x + x, cell_y + roi.position.y + y) >= threshold:
				continue
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			seen[start_index] = 1
			var area := 0
			var alpha_sum := 0
			var touches_edge := false
			var min_x := width
			var min_y := height
			var max_x := 0
			var max_y := 0
			while not stack.is_empty():
				var current: Vector2i = stack.pop_back()
				var cx: int = current.x
				var cy: int = current.y
				var alpha: int = _alpha8(image, cell_x + roi.position.x + cx, cell_y + roi.position.y + cy)
				area += 1
				alpha_sum += alpha
				touches_edge = touches_edge or cx == 0 or cy == 0 or cx == width - 1 or cy == height - 1
				min_x = mini(min_x, cx)
				min_y = mini(min_y, cy)
				max_x = maxi(max_x, cx)
				max_y = maxi(max_y, cy)
				for offset: Vector2i in NEIGHBOR_OFFSETS:
					var nx: int = cx + offset.x
					var ny: int = cy + offset.y
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						continue
					var next_index: int = ny * width + nx
					if seen[next_index] != 0:
						continue
					if _alpha8(image, cell_x + roi.position.x + nx, cell_y + roi.position.y + ny) >= threshold:
						continue
					seen[next_index] = 1
					stack.append(Vector2i(nx, ny))
			if not touches_edge and area >= min_area:
				components.append({
					"area": area,
					"avg_alpha": float(alpha_sum) / float(area),
					"bbox": Rect2i(roi.position.x + min_x, roi.position.y + min_y, max_x - min_x + 1, max_y - min_y + 1),
				})
	return components


func _verify_no_large_click_cheek_alpha_disks(image: Image) -> void:
	var cheek_rois := [
		Rect2i(380, 330, 110, 120),
		Rect2i(560, 330, 110, 120),
	]
	var max_low_alpha_pixels := 0
	for index in range(98):
		for roi in cheek_rois:
			max_low_alpha_pixels = maxi(max_low_alpha_pixels, _count_alpha_range_pixels(image, index, 14, 1024, roi, 12, 180))
	_expect(max_low_alpha_pixels < 1200, "Monkeyring click Live2D should not contain the old large semi-transparent cheek disks")


func _verify_click_banana_regions(image: Image) -> void:
	var sample_frames := [0, 12, 24, 36, 48]
	var pouch_roi := Rect2i(330, 510, 390, 330)
	var held_roi := Rect2i(230, 290, 360, 320)
	var max_pouch_yellow := 0
	var max_held_yellow := 0
	for index in sample_frames:
		var pouch_yellow := _count_banana_yellow_pixels(image, index, 14, 1024, pouch_roi)
		max_pouch_yellow = maxi(max_pouch_yellow, pouch_yellow)
		max_held_yellow = maxi(max_held_yellow, _count_banana_yellow_pixels(image, index, 14, 1024, held_roi))
	_expect(max_pouch_yellow >= 3600, "Monkeyring click Live2D should start from the single pouch banana")
	_expect(max_pouch_yellow <= 32000, "Monkeyring click Live2D pouch banana probe should stay within the one-banana visual envelope")
	_expect(max_held_yellow >= 1800, "Monkeyring click Live2D should pull the banana into hand/mouth during the click reaction")


func _count_alpha_range_pixels(image: Image, frame_index: int, cols: int, cell_size: int, roi: Rect2i, min_alpha: int, max_alpha: int) -> int:
	var cell_x := (frame_index % cols) * cell_size
	var cell_y := int(frame_index / cols) * cell_size
	var count := 0
	for y in range(roi.position.y, roi.position.y + roi.size.y):
		for x in range(roi.position.x, roi.position.x + roi.size.x):
			var alpha := _alpha8(image, cell_x + x, cell_y + y)
			if alpha >= min_alpha and alpha <= max_alpha:
				count += 1
	return count


func _count_banana_yellow_pixels(image: Image, frame_index: int, cols: int, cell_size: int, roi: Rect2i) -> int:
	var cell_x := (frame_index % cols) * cell_size
	var cell_y := int(frame_index / cols) * cell_size
	var count := 0
	for y in range(roi.position.y, roi.position.y + roi.size.y):
		for x in range(roi.position.x, roi.position.x + roi.size.x):
			var color := image.get_pixel(cell_x + x, cell_y + y)
			var red := int(round(color.r * 255.0))
			var green := int(round(color.g * 255.0))
			var blue := int(round(color.b * 255.0))
			var alpha := int(round(color.a * 255.0))
			if alpha > 80 and red >= 150 and green >= 105 and blue <= 115 and red >= green - 35:
				count += 1
	return count


func _alpha8(image: Image, x: int, y: int) -> int:
	return int(round(image.get_pixel(x, y).a * 255.0))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
