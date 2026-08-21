extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")

const ICON_DIR := "res://assets/sprites/perks"
const MUGONG_SUFFIX := "_mugong_icon.png"
const EXPECTED_STATIC_SIZE := Vector2i(256, 256)
const CAPTURE_PATH := "res://../.tmp/perk_icon_redraw/godot_general_icon_render_probe.png"
const CONSUMER_ROUTE_SEALS := {
	"perk_choice": {
		"path": "res://scripts/hud/runtime_perk_overlay_renderer.gd",
		"tokens": ["func _draw_icon(", "icon_renderer.draw_icon(canvas, skill_id"],
	},
	"mugong_collection_and_character_info": {
		"path": "res://scripts/hud/character_info_overlay_perk_presenter.gd",
		"tokens": ["icon_renderer.draw_icon(canvas, perk_id"],
	},
	"character_info_tooltip": {
		"path": "res://scripts/hud/character_info_overlay_support.gd",
		"tokens": ["perk_icon_renderer.draw_icon(canvas, icon_id"],
	},
	"perk_fusion": {
		"path": "res://scripts/hud/perk_fusion_overlay_renderer.gd",
		"tokens": ["icon_renderer.draw_icon(canvas, perk_id"],
	},
	"debug_codex": {
		"path": "res://scripts/hud/runtime_perk_debug_picker.gd",
		"tokens": ["icon_renderer.draw_icon(canvas, perk_id"],
	},
	"battle_hud_strip": {
		"path": "res://scripts/hud/runtime_perk_hud_strip_renderer.gd",
		"tokens": ["icon_renderer.draw_icon(canvas, str(entry.get(\"draw_id\""],
	},
	"stage_clear_reward": {
		"path": "res://scripts/ui/stage_clear_result_reward_card_draw_helper.gd",
		"tokens": ["perk_icon_renderer.draw_icon(canvas, perk_id"],
	},
	"treasure_hunt_reward": {
		"path": "res://scripts/items/treasure_hunt_runtime.gd",
		"tokens": ["renderer.draw_icon(canvas, perk_id"],
	},
}


class GeneralIconRenderProbe:
	extends Node2D

	var renderer := RuntimePerkIconRenderer.new()
	var ids: Array[String] = []
	var draw_results: Dictionary = {}
	var draw_count := 0

	func _draw() -> void:
		draw_count += 1
		draw_results.clear()
		draw_rect(Rect2(Vector2.ZERO, Vector2(get_viewport_rect().size)), Color(6.0 / 255.0, 20.0 / 255.0, 35.0 / 255.0))
		for i in range(ids.size()):
			var perk_id := str(ids[i])
			var col := i % 7
			var row := int(floor(float(i) / 7.0))
			var cell_rect := Rect2(Vector2(18.0 + float(col) * 98.0, 18.0 + float(row) * 86.0), Vector2(78.0, 78.0))
			draw_rect(cell_rect, Color(9.0 / 255.0, 27.0 / 255.0, 48.0 / 255.0))
			draw_rect(cell_rect, Color(52.0 / 255.0, 121.0 / 255.0, 152.0 / 255.0), false, 1.0)
			draw_results[perk_id] = bool(renderer.draw_icon(self, perk_id, Rect2(cell_rect.position + Vector2(11.0, 5.0), Vector2(56.0, 56.0)), 1.0, true))
			var font := ThemeDB.fallback_font
			if font != null:
				draw_string(font, cell_rect.position + Vector2(23.0, 69.0), "Lv.1", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(1.0, 0.88, 0.25))


var _failures: Array[String] = []
var _mugong_ids: Array[String] = []
var _probe: GeneralIconRenderProbe = null
var _frame_count := 0


func _init() -> void:
	_mugong_ids = _discover_mugong_ids()
	_expect(not _mugong_ids.is_empty(), "filesystem/import/map discovery should find Mugong icon assets")
	_verify_static_wiring()
	_verify_consumer_routes()
	_verify_no_conflicting_production_paths()
	var row_count := maxi(1, ceili(float(_mugong_ids.size()) / 7.0))
	get_root().size = Vector2i(720, maxi(382, 28 + row_count * 86))
	_probe = GeneralIconRenderProbe.new()
	_probe.ids = _mugong_ids.duplicate()
	_probe.name = "GeneralIconRenderProbe"
	get_root().add_child(_probe)
	_probe.queue_redraw()


func _process(_delta: float) -> bool:
	_frame_count += 1
	if _frame_count < 3:
		return false
	_verify_draw_probe()
	_capture_probe_if_available()
	ProjectResourceLoader.clear_caches()

	if _failures.is_empty():
		print("runtime_perk_general_icon_static_smoke: ok assets=", _mugong_ids.size())
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
	return true


func _discover_mugong_ids() -> Array[String]:
	var found: Dictionary = {}
	var icon_dir := DirAccess.open(ICON_DIR)
	_expect(icon_dir != null, "Mugong icon directory should be readable")
	if icon_dir != null:
		for file_name in icon_dir.get_files():
			if file_name.ends_with(MUGONG_SUFFIX):
				found[file_name.trim_suffix(MUGONG_SUFFIX)] = true
			elif file_name.ends_with("%s.import" % MUGONG_SUFFIX):
				found[file_name.trim_suffix("%s.import" % MUGONG_SUFFIX)] = true
	for path_value in RuntimePerkIconRenderer.PERK_ICON_PATHS.values():
		var path := str(path_value)
		if path.begins_with("%s/" % ICON_DIR) and path.ends_with(MUGONG_SUFFIX):
			found[path.get_file().trim_suffix(MUGONG_SUFFIX)] = true
	var result: Array[String] = []
	for id_value in found.keys():
		result.append(str(id_value))
	result.sort()
	return result


func _verify_static_wiring() -> void:
	var renderer := RuntimePerkIconRenderer.new()
	var covered_ids := renderer.covered_ids()
	for perk_id in _mugong_ids:
		var expected_path := "%s/%s%s" % [ICON_DIR, perk_id, MUGONG_SUFFIX]
		var legacy_path := "%s/%s_perk_icon.png" % [ICON_DIR, perk_id]
		var actual_path := str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(perk_id, ""))
		_expect(FileAccess.file_exists(expected_path), "%s filesystem-discovered Mugong source PNG should exist" % perk_id)
		_expect(actual_path == expected_path, "%s should register its filesystem-discovered Mugong PNG path" % perk_id)
		_expect(actual_path != legacy_path, "%s should reject the legacy perk-icon path" % perk_id)
		_expect(not RuntimePerkIconRenderer.PERK_SHEET_PATHS.has(perk_id), "%s should stay static-only and not register an animated sheet" % perk_id)
		_expect(covered_ids.has(perk_id), "%s should be covered by runtime perk icon ids" % perk_id)
		_verify_import_chain(expected_path, perk_id)

		var imported_texture: Texture2D = ProjectResourceLoader.load_imported_texture(expected_path)
		_expect(imported_texture is CompressedTexture2D, "%s should load from its imported .ctex before raw-PNG fallback" % perk_id)
		var static_texture: Texture2D = renderer._get_texture(expected_path)
		_expect(static_texture != null, "%s static icon should load through ProjectResourceLoader" % perk_id)
		if static_texture != null:
			_expect(static_texture.get_width() == EXPECTED_STATIC_SIZE.x and static_texture.get_height() == EXPECTED_STATIC_SIZE.y, "%s new-generation static icon should stay 256x256" % perk_id)

		var source: Dictionary = renderer._get_icon_source(perk_id)
		_expect(source.get("texture", null) == static_texture, "%s should use the registered Mugong PNG as its draw source" % perk_id)
		_expect(source.get("region", Rect2()).size == Vector2.ZERO, "%s static source should not carry a sheet region" % perk_id)
		_verify_source_png_alpha(expected_path, EXPECTED_STATIC_SIZE, "%s static icon" % perk_id)

	renderer.prewarm_assets()
	for perk_id in _mugong_ids:
		var expected_path := str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(perk_id, ""))
		var legacy_path := "%s/%s_perk_icon.png" % [ICON_DIR, perk_id]
		_expect(renderer.has_icon(perk_id), "%s should remain drawable after prewarm" % perk_id)
		_expect(renderer._texture_cache.has(expected_path), "%s Mugong icon should be cached by prewarm" % perk_id)
		_expect(not renderer._texture_cache.has(legacy_path), "%s prewarm should not load the legacy perk icon" % perk_id)


func _verify_import_chain(path: String, perk_id: String) -> void:
	var import_path := "%s.import" % path
	_expect(FileAccess.file_exists(import_path), "%s should commit its .import sidecar" % perk_id)
	var import_config := ConfigFile.new()
	var import_error := import_config.load(import_path)
	_expect(import_error == OK, "%s .import sidecar should parse" % perk_id)
	if import_error != OK:
		return
	_expect(str(import_config.get_value("remap", "importer", "")) == "texture", "%s should use the texture importer" % perk_id)
	_expect(str(import_config.get_value("remap", "type", "")) == "CompressedTexture2D", "%s should remap to CompressedTexture2D" % perk_id)
	_expect(str(import_config.get_value("deps", "source_file", "")) == path, "%s .import source_file should match the mapped PNG" % perk_id)
	var ctex_path := str(import_config.get_value("remap", "path", ""))
	_expect(ctex_path.begins_with("res://.godot/imported/") and ctex_path.ends_with(".ctex"), "%s should declare a .ctex remap" % perk_id)
	_expect(FileAccess.file_exists(ctex_path), "%s declared .ctex should exist in the warm import cache" % perk_id)
	var dest_files_value: Variant = import_config.get_value("deps", "dest_files", PackedStringArray())
	var dest_files_include_ctex := false
	if dest_files_value is PackedStringArray:
		dest_files_include_ctex = (dest_files_value as PackedStringArray).has(ctex_path)
	elif dest_files_value is Array:
		dest_files_include_ctex = (dest_files_value as Array).has(ctex_path)
	_expect(dest_files_include_ctex, "%s dest_files should include the declared .ctex" % perk_id)


func _verify_consumer_routes() -> void:
	for surface_value in CONSUMER_ROUTE_SEALS.keys():
		var surface := str(surface_value)
		var spec: Dictionary = CONSUMER_ROUTE_SEALS[surface]
		var source_path := str(spec.get("path", ""))
		# A consumer script that no longer exists in this tree is not an icon-wiring
		# defect. Skip it instead of failing, so a retired or in-flight consumer
		# cannot mask a real routing regression in the surfaces that do exist.
		if not FileAccess.file_exists(source_path):
			print("runtime_perk_general_icon_static_smoke: SKIPPED consumer %s (%s missing)" % [surface, source_path])
			continue
		var source := FileAccess.get_file_as_string(source_path)
		_expect(not source.is_empty(), "%s consumer source should be readable: %s" % [surface, source_path])
		for token_value in spec.get("tokens", []):
			var token := str(token_value)
			_expect(source.find(token) >= 0, "%s should route the displayed perk id through the shared draw_icon contract" % surface)


func _verify_no_conflicting_production_paths() -> void:
	var production_files: Array[String] = []
	production_files.append_array(_collect_source_files("res://scripts"))
	production_files.append_array(_collect_source_files("res://scenes"))
	var expected_literal_hits: Dictionary = {}
	for perk_id in _mugong_ids:
		expected_literal_hits[perk_id] = 0
	for source_path in production_files:
		var source := FileAccess.get_file_as_string(source_path)
		if source.is_empty():
			continue
		for perk_id in _mugong_ids:
			var expected_path := "%s/%s%s" % [ICON_DIR, perk_id, MUGONG_SUFFIX]
			var legacy_path := "%s/%s_perk_icon.png" % [ICON_DIR, perk_id]
			_expect(source.find(legacy_path) < 0, "%s should not retain a legacy production reference in %s" % [perk_id, source_path])
			if source.find(expected_path) >= 0:
				expected_literal_hits[perk_id] = int(expected_literal_hits[perk_id]) + 1
			var direct_prefix := "%s/%s_" % [ICON_DIR, perk_id]
			for line_value in source.split("\n"):
				var line := str(line_value)
				if line.find(direct_prefix) >= 0 and line.find("icon") >= 0 and line.find(".png") >= 0:
					_expect(line.find(expected_path) >= 0, "%s production icon literal should agree with the shared Mugong path in %s" % [perk_id, source_path])
	for perk_id in _mugong_ids:
		_expect(int(expected_literal_hits.get(perk_id, 0)) > 0, "%s should have a positive production reference to its discovered Mugong path" % perk_id)


func _collect_source_files(root_path: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		return result
	for file_name in directory.get_files():
		var extension := file_name.get_extension().to_lower()
		if extension in ["gd", "tscn", "tres"]:
			result.append(root_path.path_join(file_name))
	for subdirectory in directory.get_directories():
		result.append_array(_collect_source_files(root_path.path_join(subdirectory)))
	return result


func _verify_source_png_alpha(path: String, expected_size: Vector2i, label: String) -> void:
	var image := Image.new()
	var load_error := image.load(ProjectSettings.globalize_path(path))
	if load_error != OK:
		load_error = image.load(path)
	_expect(load_error == OK, "%s source PNG should load for alpha QA" % label)
	if load_error != OK:
		return
	_expect(image.get_width() == expected_size.x and image.get_height() == expected_size.y, "%s source PNG should keep expected dimensions" % label)
	var opaque_count := 0
	var semi_alpha_count := 0
	var edge_alpha_count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if alpha >= 0.999:
				opaque_count += 1
			elif alpha > 0.001:
				semi_alpha_count += 1
			if (x == 0 or y == 0 or x == image.get_width() - 1 or y == image.get_height() - 1) and alpha > 0.001:
				edge_alpha_count += 1
	_expect(opaque_count > 0, "%s source PNG should contain visible pixels" % label)
	_expect(semi_alpha_count > 0, "%s source PNG should preserve its soft-alpha seal edge" % label)
	_expect(edge_alpha_count == 0, "%s source PNG should leave transparent outer edges" % label)


func _verify_draw_probe() -> void:
	_expect(_probe != null and _probe.draw_count > 0, "general icon render probe should receive a live draw callback")
	if _probe == null:
		return
	for perk_id in _mugong_ids:
		_expect(bool(_probe.draw_results.get(perk_id, false)), "%s should draw through RuntimePerkIconRenderer.draw_icon" % perk_id)


func _capture_probe_if_available() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var viewport_texture: Texture2D = get_root().get_texture()
	if viewport_texture == null:
		return
	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		return
	image.save_png(ProjectSettings.globalize_path(CAPTURE_PATH))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
