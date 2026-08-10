extends SceneTree

# The filename is the historical R0 asset/import snapshot. Promotion has since
# advanced to R1: this smoke keeps the original seven-building invariants while
# also sealing the active production manifest, renderer, and minimap contract.

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapWorldHost := preload("res://scripts/plaza/plaza_map_world_host.gd")
const PlazaMinimapProjection := preload("res://scripts/plaza/plaza_minimap_projection.gd")

const EXPECTED_TYPES := [
	"shop",
	"bank",
	"gacha",
	"lingpet_store",
	"blacksmith",
	"tavern",
	"academy",
]
const EXPECTED_DISPLAY_HEIGHTS := {
	"shop": 275,
	"bank": 360,
	"gacha": 295,
	"lingpet_store": 285,
	"blacksmith": 300,
	"tavern": 260,
	"academy": 315,
}
const ACTIVE_RUNTIME_USAGE := "production_active_hwangyeok_plaza_2d_retained_building_layers"
const MIN_APPROVED_WINDOW_HUE_SEPARATION_DEGREES := 35.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	PlazaAssetLoader.reset_for_test()
	_verify_promoted_manifest_boundary()
	var manifest_paths := PlazaAssetLoader.get_hwangyeok_building_manifest_paths()
	var texture_paths := PlazaAssetLoader.get_hwangyeok_building_prewarm_texture_paths()
	_verify_runtime_manifests_and_imports(manifest_paths, texture_paths)
	_verify_owner_delegated_prewarm(manifest_paths, texture_paths)
	_verify_production_specs_and_shared_marker_color()

	if _failures.is_empty():
		print("plaza_hwangyeok_building_r0_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_promoted_manifest_boundary() -> void:
	for path_value in PlazaAssetLoader.BUILDING_MANIFEST_PATHS:
		var path := str(path_value)
		_expect(path.find("plaza_lingpia_") >= 0, "legacy manifest catalog should remain available as an explicit rollback path")
	for path in PlazaAssetLoader.get_prewarm_texture_paths(1):
		_expect(path.find("/buildings/") < 0, "base plaza prewarm should not duplicate building layers owned by the retained world chain")
	var live_scene_source := FileAccess.get_file_as_string("res://scripts/plaza/plaza_scene.gd")
	_expect(live_scene_source.find("plaza_map_world_host.gd") >= 0, "R1 should attach the retained map host to the live plaza scene")
	_expect(live_scene_source.find("build_hwangyeok_building_specs(") >= 0, "R1 live plaza should consume the canonical Hwangyeok spec builder")


func _verify_runtime_manifests_and_imports(manifest_paths: Array[String], texture_paths: Array[String]) -> void:
	_expect(manifest_paths.size() == 7, "the historical R0 snapshot should retain seven manifests after active R1 promotion")
	_expect(texture_paths.size() == 21, "the historical R0 snapshot should retain exactly 7 x 3 active prewarm texture paths")
	var unique_paths := {}
	for path in texture_paths:
		unique_paths[path] = true
	_expect(unique_paths.size() == 21, "all historical R0 layer texture paths should remain unique in active R1")

	var seen_types := {}
	for manifest_path in manifest_paths:
		_expect(FileAccess.file_exists(manifest_path), "runtime manifest should exist: %s" % manifest_path)
		var manifest := PlazaAssetLoader.load_manifest(manifest_path)
		var building_type := str(manifest.get("building_type", ""))
		seen_types[building_type] = true
		_expect(str(manifest.get("status", "")) == "r1_active_runtime", "%s should carry the generated active R1 status" % building_type)
		_expect(str(manifest.get("runtime_usage", "")) == ACTIVE_RUNTIME_USAGE, "%s should declare the active retained-building production usage" % building_type)
		_expect(_json_vector2(manifest.get("source_size", [])) == Vector2(1254.0, 1254.0), "%s should retain 1254px authoring coordinates" % building_type)
		_expect(_json_vector2(manifest.get("runtime_texture_size", [])) == Vector2(512.0, 512.0), "%s should use physical 512px runtime textures" % building_type)
		_expect(not bool(manifest.get("allow_rotation", true)), "%s should forbid runtime rotation" % building_type)
		_expect(not bool(manifest.get("allow_mirror", true)), "%s should forbid runtime mirroring" % building_type)
		var import_policy_value: Variant = manifest.get("runtime_import_policy", {})
		var import_policy: Dictionary = import_policy_value as Dictionary if import_policy_value is Dictionary else {}
		_expect(int(import_policy.get("compress_mode", -1)) == 2, "%s should author VRAM compression mode 2" % building_type)
		_expect(bool(import_policy.get("metadata_vram_texture", false)), "%s should declare a VRAM texture import" % building_type)
		_expect(bool(import_policy.get("mipmaps_generate", false)), "%s should generate mipmaps for scaled map rendering" % building_type)
		var layers_value: Variant = manifest.get("layers", {})
		var layers: Dictionary = layers_value as Dictionary if layers_value is Dictionary else {}
		for layer_key in ["base", "sign_emissive", "window_glow_mask"]:
			var layer_value: Variant = layers.get(layer_key, {})
			var layer: Dictionary = layer_value as Dictionary if layer_value is Dictionary else {}
			var runtime_path := str(layer.get("res_path", ""))
			_expect(runtime_path.find("/buildings/hwangyeok/") >= 0, "%s %s should use the isolated runtime directory" % [building_type, layer_key])
			_expect(FileAccess.file_exists(runtime_path), "%s %s runtime PNG should exist" % [building_type, layer_key])
			_expect(str(layer.get("sha256", "")) == FileAccess.get_sha256(runtime_path), "%s %s hash should match the runtime PNG" % [building_type, layer_key])
			_verify_vram_import_sidecar(runtime_path, building_type, layer_key)
	for building_type in EXPECTED_TYPES:
		_expect(seen_types.has(building_type), "the historical R0 roster promoted to active R1 should contain %s" % building_type)


func _verify_vram_import_sidecar(runtime_path: String, building_type: String, layer_key: String) -> void:
	var import_path := runtime_path + ".import"
	_expect(FileAccess.file_exists(import_path), "%s %s should have an imported texture sidecar" % [building_type, layer_key])
	if not FileAccess.file_exists(import_path):
		return
	var source := FileAccess.get_file_as_string(import_path)
	_expect(source.find("source_file=\"%s\"" % runtime_path) >= 0, "%s %s import should point back to its own runtime PNG" % [building_type, layer_key])
	_expect(source.find("path.bptc=\"") >= 0 and source.find("path.astc=\"") >= 0, "%s %s import should retain both BPTC and ASTC destinations" % [building_type, layer_key])
	_expect(source.find("\ncompress/mode=2\n") >= 0, "%s %s import should use VRAM compression" % [building_type, layer_key])
	_expect(source.find("\ncompress/high_quality=true\n") >= 0, "%s %s import should use high-quality compression" % [building_type, layer_key])
	_expect(source.find("\nmipmaps/generate=true\n") >= 0, "%s %s import should generate mipmaps" % [building_type, layer_key])
	_expect(source.find("\"vram_texture\": true") >= 0, "%s %s import metadata should be a VRAM texture" % [building_type, layer_key])


func _verify_owner_delegated_prewarm(manifest_paths: Array[String], texture_paths: Array[String]) -> void:
	var host := PlazaMapWorldHost.new()
	root.add_child(host)
	var complete := false
	for _step in range(texture_paths.size() + 2):
		complete = host.prewarm_assets_step(
			manifest_paths,
			false,
			"hwangyeok_r0_smoke"
		)
		if complete:
			break
	_expect(complete, "the map-world owner should delegate through the renderer and complete all 21 prewarm loads")
	var status := PlazaAssetLoader.get_building_prewarm_status("hwangyeok_r0_smoke")
	_expect(bool(status.get("complete", false)), "delegated building prewarm status should be complete")
	_expect(int(status.get("expected_path_count", 0)) == 21, "delegated prewarm should retain the 21-path contract")
	_expect(int(status.get("path_count", 0)) == 21, "delegated prewarm should discover all 21 paths")
	for path in texture_paths:
		_expect(bool(status.get(path, false)), "delegated prewarm should load %s" % path)
	host.free()


func _verify_production_specs_and_shared_marker_color() -> void:
	var specs := PlazaAssetLoader.build_hwangyeok_building_specs(1, 918273, true, false)
	_expect(specs.size() == 7, "full-layout R1 production route should build all seven specs")
	var colors := {}
	var approved_window_colors: Array[Color] = []
	for spec in specs:
		var building_type := str(spec.get("type", ""))
		_expect(str(spec.get("asset_set_id", "")) == PlazaAssetLoader.HWANGYEOK_BUILDING_ASSET_SET_ID, "%s should carry the active production asset-set id" % building_type)
		_expect(spec.get("source_size", Vector2.ZERO) == Vector2(1254.0, 1254.0), "%s should preserve source-pixel geometry" % building_type)
		_expect(spec.get("runtime_texture_size", Vector2.ZERO) == Vector2(512.0, 512.0), "%s should record the physical runtime texture size" % building_type)
		_expect(int(spec.get("display_height", 0)) == int(EXPECTED_DISPLAY_HEIGHTS.get(building_type, 0)), "%s should consume manifest display hierarchy" % building_type)
		_expect((spec.get("footprint_polygon", []) as Array).size() == 4, "%s should carry the approved four-point footprint" % building_type)
		_expect(str(spec.get("footprint_polygon_order", "")) == "rear_right_front_left", "%s should retain the authored footprint vertex order" % building_type)
		_expect(str(spec.get("approach_side", "")) == "lower_left", "%s should retain the lower-left road approach constraint" % building_type)
		var coordinate_contract_value: Variant = spec.get("coordinate_contract", {})
		var coordinate_contract: Dictionary = coordinate_contract_value as Dictionary if coordinate_contract_value is Dictionary else {}
		_expect(bool(coordinate_contract.get("viewport_or_fit_derived_values_forbidden", false)), "%s geometry should forbid viewport-derived authoring values" % building_type)
		_expect(spec.get("base_texture", null) is Texture2D, "%s should load its base texture" % building_type)
		_expect(spec.get("sign_texture", null) is Texture2D, "%s should load its sign mask" % building_type)
		_expect(spec.get("window_texture", null) is Texture2D, "%s should load its window mask" % building_type)
		var base_texture := spec.get("base_texture", null) as Texture2D
		if base_texture != null:
			_expect(base_texture.get_size() == Vector2(512.0, 512.0), "%s imported base should be 512px" % building_type)
		var marker_color_value: Variant = spec.get("marker_color", null)
		_expect(marker_color_value is Color, "%s should expose the manifest window color to minimap consumers" % building_type)
		if marker_color_value is Color:
			var marker_color := marker_color_value as Color
			colors[marker_color.to_html(false)] = true
			approved_window_colors.append(marker_color)
		if building_type == "gacha":
			_expect(spec.get("entrance_anchor", Vector2.ZERO) == Vector2(210.0, 1015.0), "gacha should retain its separately authored left-edge entrance anchor")
			var corridor_value: Variant = spec.get("entrance_access_corridor", {})
			var corridor: Dictionary = corridor_value as Dictionary if corridor_value is Dictionary else {}
			_expect(bool(corridor.get("required", false)), "gacha should retain its non-pivot-centered access corridor constraint")
	_expect(colors.size() == 7, "the seven active R1 specs should retain seven distinct approved window colors")
	var minimum_hue_separation := _minimum_circular_hue_separation_degrees(approved_window_colors)
	_expect(minimum_hue_separation >= MIN_APPROVED_WINDOW_HUE_SEPARATION_DEGREES, "the active R1 window palette should retain at least %.1f degrees circular hue separation (got %.3f)" % [MIN_APPROVED_WINDOW_HUE_SEPARATION_DEGREES, minimum_hue_separation])

	var minimap_state := PlazaMinimapProjection.build(specs, 0.0, 0.0, 760.0, PlazaAssetLoader.HWANGYEOK_MAP_WORLD_SIZE.x, PlazaAssetLoader.HWANGYEOK_MAP_WORLD_SIZE.x - 90.0)
	var markers_value: Variant = minimap_state.get("building_markers", [])
	var markers: Array = markers_value as Array if markers_value is Array else []
	_expect(markers.size() == specs.size(), "active minimap projection should expose one marker per production spec")
	for marker_value in markers:
		if not (marker_value is Dictionary):
			continue
		var marker := marker_value as Dictionary
		var matched_spec := _find_spec(specs, str(marker.get("type", "")))
		_expect(not matched_spec.is_empty(), "minimap marker should map back to a building spec")
		if not matched_spec.is_empty():
			_expect(marker.get("marker_color", null) == matched_spec.get("window_glow_color", null), "minimap marker should consume the same manifest color as the retained window layer")

	var host := PlazaMapWorldHost.new()
	root.add_child(host)
	_expect(host.sync_state({
		"render_size": PlazaAssetLoader.HWANGYEOK_MAP_WORLD_SIZE,
		"game_size": PlazaAssetLoader.HWANGYEOK_MAP_WORLD_SIZE,
		"render_scale": 1.0,
		"render_background": false,
		"camera_x": 0.0,
		"building_baseline_y": PlazaAssetLoader.BUILDING_BASELINE_Y,
		"ticks_msec": 1000,
		"building_specs": specs,
	}), "active R1 specs should sync through the production retained map-world host")
	var layer_statuses := host.get_building_layer_statuses()
	_expect(layer_statuses.size() == specs.size(), "map-world host should expose one retained layer status per active R1 spec")
	for index in range(mini(layer_statuses.size(), specs.size())):
		var spec: Dictionary = specs[index]
		var layer_status: Dictionary = layer_statuses[index]
		var building_type := str(spec.get("type", ""))
		var expected_rect: Rect2 = spec.get("visual_rect", Rect2())
		var expected_scale := expected_rect.size / Vector2(512.0, 512.0)
		_expect(layer_status.get("base_texture_size", Vector2.ZERO) == Vector2(512.0, 512.0), "%s retained base should bind the physical 512px texture" % building_type)
		_expect((layer_status.get("base_position", Vector2.ZERO) as Vector2).is_equal_approx(expected_rect.position), "%s retained base should use the authoring-derived visual origin" % building_type)
		_expect((layer_status.get("base_scale", Vector2.ZERO) as Vector2).is_equal_approx(expected_scale), "%s should scale 512 runtime pixels to the 1254-source visual rect" % building_type)
		_expect(_rect_is_equal_approx(layer_status.get("base_render_rect", Rect2()), expected_rect), "%s retained base should fill the authoring-derived visual rect" % building_type)
		_expect(_rect_is_equal_approx(layer_status.get("sign_render_rect", Rect2()), expected_rect), "%s sign mask should stay registered after runtime downscale" % building_type)
		_expect(_rect_is_equal_approx(layer_status.get("window_render_rect", Rect2()), expected_rect), "%s window mask should stay registered after runtime downscale" % building_type)
		_expect(_color_rgb_is_equal_approx(layer_status.get("sign_modulate", Color.TRANSPARENT), spec.get("sign_glow_color", Color.TRANSPARENT)), "%s retained sign should consume its manifest tint" % building_type)
		_expect(_color_rgb_is_equal_approx(layer_status.get("window_modulate", Color.TRANSPARENT), spec.get("window_glow_color", Color.TRANSPARENT)), "%s retained window should consume its manifest tint" % building_type)
	host.free()


func _find_spec(specs: Array[Dictionary], building_type: String) -> Dictionary:
	for spec in specs:
		if str(spec.get("type", "")) == building_type:
			return spec
	return {}


func _minimum_circular_hue_separation_degrees(colors: Array[Color]) -> float:
	if colors.size() < 2:
		return 0.0
	var minimum_separation := 360.0
	for first_index in range(colors.size() - 1):
		for second_index in range(first_index + 1, colors.size()):
			var direct_delta := absf(colors[first_index].h - colors[second_index].h) * 360.0
			minimum_separation = minf(minimum_separation, minf(direct_delta, 360.0 - direct_delta))
	return minimum_separation


func _json_vector2(value: Variant) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return Vector2.ZERO


func _rect_is_equal_approx(value: Variant, expected: Rect2) -> bool:
	if not (value is Rect2):
		return false
	var rect := value as Rect2
	return rect.position.is_equal_approx(expected.position) and rect.size.is_equal_approx(expected.size)


func _color_rgb_is_equal_approx(value: Variant, expected_value: Variant) -> bool:
	if not (value is Color) or not (expected_value is Color):
		return false
	var color := value as Color
	var expected := expected_value as Color
	return is_equal_approx(color.r, expected.r) and is_equal_approx(color.g, expected.g) and is_equal_approx(color.b, expected.b)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
