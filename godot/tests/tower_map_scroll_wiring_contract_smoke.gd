extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerMapScrollAssetCatalog := preload(
	"res://scripts/tower_ascent/tower_map_scroll_asset_catalog.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)

const EXPECTED_ASSET_COUNT := 16
const EXPECTED_UPSCALE_MANIFEST_ASSET_COUNT := 11
const EXPECTED_CLOUD_ASSET_COUNT := 5

var _failures: Array[String] = []
var _leg_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_approved_asset_catalog_and_dimensions()
	_verify_x4_manifest_and_import_policy()
	_verify_cloud_bitmap_import_policy()
	_verify_negative_cache_and_missing_asset_fallback()
	_verify_deterministic_nonrepeating_floor_variants()
	_verify_production_prewarm_order_and_draw_peek_contract()
	_verify_opaque_floor_tile_render_model_and_fallback()
	_verify_band_chunk_scale_invariant_boundary_fixture()
	_verify_fullscreen_draw_call_budget_lockstep()
	_verify_three_route_brush_states_and_geometry()
	_verify_fullscreen_medal_node_contract()
	_verify_floor_gate_plaque_three_slice_contract()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_map_scroll_wiring_contract_smoke: PASS=%d" % _leg_count)
		print("tower_map_scroll_wiring_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
		quit(1)


func _verify_x4_manifest_and_import_policy() -> void:
	var manifest_path := (
		"res://assets/sprites/tower/map_scroll/tower_map_scroll_x4_manifest.json"
	)
	var manifest_value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(manifest_path)
	)
	_expect(manifest_value is Dictionary, "S5 must retain its reproducible x4 asset manifest")
	if not (manifest_value is Dictionary):
		return
	var manifest := manifest_value as Dictionary
	_expect(str(manifest.get("model", "")) == "realesrgan-x4plus", "S5 must pin the conservative Real-ESRGAN model selected by the art gate")
	_expect(int(manifest.get("scale", 0)) == 4, "S5 must pin the approved x4 scale")
	var records: Array = manifest.get("assets", [])
	_expect(
		records.size() == EXPECTED_UPSCALE_MANIFEST_ASSET_COUNT,
		"the Real-ESRGAN manifest must retain its original 11 promoted bitmaps"
	)
	var alpha_asset_count := 0
	for record_value in records:
		var record := record_value as Dictionary
		var source_name := str(record.get("source", ""))
		var output_name := str(record.get("output", ""))
		var root := "res://assets/sprites/tower/map_scroll/"
		var source_path := root + source_name
		var output_path := root + output_name
		_expect(FileAccess.file_exists(source_path), "%s source must remain preserved" % source_name)
		_expect(FileAccess.file_exists(output_path), "%s x4 output must remain tracked" % output_name)
		_expect(
			FileAccess.get_sha256(source_path) == str(record.get("source_sha256", "")),
			"%s reviewed source hash must remain unchanged" % source_name
		)
		_expect(
			FileAccess.get_sha256(output_path) == str(record.get("output_sha256", "")),
			"%s generated x4 hash must match the manifest" % output_name
		)
		var alpha: Dictionary = record.get("alpha", {})
		if bool(alpha.get("present", false)):
			alpha_asset_count += 1
			_expect(str(record.get("output_mode", "")) == "RGBA", "%s must retain recombined source alpha" % output_name)
		else:
			_expect(str(record.get("output_mode", "")) == "RGB", "%s must remain an opaque RGB bitmap" % output_name)
		var import_source := FileAccess.get_file_as_string(output_path + ".import")
		_expect(import_source.find("compress/mode=2") >= 0, "%s must use offline VRAM compression" % output_name)
		_expect(import_source.find("compress/high_quality=true") >= 0, "%s must use high-quality VRAM compression" % output_name)
		_expect(import_source.find("mipmaps/generate=true") >= 0, "%s must generate mipmaps for overview downscaling" % output_name)
	_expect(alpha_asset_count == 4, "only the three brushes and plaque may own source alpha")
	_leg_count += 1


func _verify_cloud_bitmap_import_policy() -> void:
	var catalog := TowerMapScrollAssetCatalog.new()
	_expect(
		TowerMapScrollAssetCatalog.CLOUD_ASSET_KEYS.size() == EXPECTED_CLOUD_ASSET_COUNT,
		"the bitmap cloud family must declare three motifs plus wall interior and dissolve"
	)
	var expected_world_sizes := {
		TowerMapScrollAssetCatalog.CLOUD_SWIRL_LARGE: Vector2i(260, 160),
		TowerMapScrollAssetCatalog.CLOUD_SWIRL_MEDIUM: Vector2i(196, 112),
		TowerMapScrollAssetCatalog.CLOUD_WISP: Vector2i(152, 64),
		TowerMapScrollAssetCatalog.CLOUD_WALL_INTERIOR: Vector2i(692, 320),
		TowerMapScrollAssetCatalog.CLOUD_WALL_DISSOLVE: Vector2i(692, 224),
	}
	var expected_texture_sizes := {
		TowerMapScrollAssetCatalog.CLOUD_SWIRL_LARGE: Vector2i(1040, 640),
		TowerMapScrollAssetCatalog.CLOUD_SWIRL_MEDIUM: Vector2i(784, 448),
		TowerMapScrollAssetCatalog.CLOUD_WISP: Vector2i(608, 256),
		TowerMapScrollAssetCatalog.CLOUD_WALL_INTERIOR: Vector2i(2768, 1280),
		TowerMapScrollAssetCatalog.CLOUD_WALL_DISSOLVE: Vector2i(2768, 896),
	}
	for asset_key in TowerMapScrollAssetCatalog.CLOUD_ASSET_KEYS:
		var path := catalog.resolve_declared_path(asset_key)
		_expect(path.ends_with("_imagegen_v1_x4.png"), "%s must bind the approved versioned imagegen bitmap" % asset_key)
		_expect(ResourceLoader.exists(path, "Texture2D"), "%s must own an imported Texture2D" % asset_key)
		_expect(catalog.get_expected_size(asset_key) == expected_world_sizes[asset_key], "%s must preserve its authored world size" % asset_key)
		_expect(catalog.get_expected_texture_size(asset_key) == expected_texture_sizes[asset_key], "%s must preserve exact x4 texture density" % asset_key)
		var image := Image.new()
		var image_error := image.load_png_from_buffer(
			FileAccess.get_file_as_bytes(path)
		)
		_expect(image_error == OK and not image.is_empty(), "%s source bitmap must decode" % asset_key)
		if image_error == OK and not image.is_empty():
			if asset_key == TowerMapScrollAssetCatalog.CLOUD_WALL_INTERIOR:
				_expect(
					image.detect_alpha() == Image.ALPHA_NONE,
					"the wall interior must remain an opaque concealment core"
				)
			else:
				_expect(
					image.detect_alpha() != Image.ALPHA_NONE,
					"%s must retain soft source alpha" % asset_key
				)
		var import_source := FileAccess.get_file_as_string(path + ".import")
		_expect(import_source.find("compress/mode=2") >= 0, "%s must use offline VRAM compression" % asset_key)
		_expect(import_source.find("compress/high_quality=true") >= 0, "%s must use high-quality VRAM compression" % asset_key)
		_expect(import_source.find("mipmaps/generate=true") >= 0, "%s must generate mipmaps for fit-all downscaling" % asset_key)
	_leg_count += 1


func _verify_approved_asset_catalog_and_dimensions() -> void:
	var catalog := TowerMapScrollAssetCatalog.new()
	var keys := catalog.get_asset_keys()
	_expect(keys.size() == EXPECTED_ASSET_COUNT, "the catalog must declare all 16 approved files")
	var declared_paths: Dictionary = {}
	for asset_key in keys:
		var path := catalog.resolve_declared_path(asset_key)
		_expect(path.begins_with("res://assets/sprites/tower/map_scroll/"), "%s must remain inside the canonical map-scroll root" % asset_key)
		_expect(path.ends_with("_x4.png"), "%s must use the versioned Real-ESRGAN x4 candidate" % asset_key)
		_expect(path.find("_candidate") < 0, "%s runtime path must not retain candidate naming" % asset_key)
		_expect(not declared_paths.has(path), "%s must own a distinct bitmap" % asset_key)
		declared_paths[path] = true
		_expect(ResourceLoader.exists(path, "Texture2D"), "%s must have an imported Texture2D" % asset_key)
		var cold := catalog.get_cached_resolution(asset_key)
		_expect(not bool(cold.get("cached", true)), "%s cold draw peek must not touch the filesystem" % asset_key)
	var prewarm := catalog.prewarm_all()
	_expect(bool(prewarm.get("ready", false)), "all approved files must prewarm")
	_expect(int(prewarm.get("entry_count", 0)) == EXPECTED_ASSET_COUNT, "prewarm must cache all 16 approved files")
	for asset_key in keys:
		var resolution := catalog.get_cached_resolution(asset_key)
		var texture := resolution.get("texture", null) as Texture2D
		_expect(bool(resolution.get("ready", false)), "%s must pass its explicit dimension contract" % asset_key)
		_expect(texture != null, "%s must resolve as Texture2D" % asset_key)
		if texture != null:
			_expect(
				Vector2i(texture.get_size()) == catalog.get_expected_texture_size(asset_key),
				"%s must use its declared x4 texture density" % asset_key
			)
			var world_size := catalog.get_expected_size(asset_key)
			var expected_world_size := (
				Vector2i(620, 48)
				if asset_key == TowerMapScrollAssetCatalog.FLOOR_GATE_PLAQUE
				else catalog.get_expected_size(asset_key)
				if asset_key in TowerMapScrollAssetCatalog.CLOUD_ASSET_KEYS
				else Vector2i(72, 320)
				if asset_key in [
					TowerMapScrollAssetCatalog.ROUTE_BRUSH_UNSELECTED,
					TowerMapScrollAssetCatalog.ROUTE_BRUSH_AVAILABLE,
					TowerMapScrollAssetCatalog.ROUTE_BRUSH_COMPLETED_GOLD,
				]
				else Vector2i(692, 320)
			)
			_expect(
				world_size == expected_world_size,
				"%s x4 density must not change authored world geometry" % asset_key
			)
	var first_key := str(keys[0])
	var mutable_copy := catalog.get_cached_resolution(first_key)
	mutable_copy["ready"] = false
	_expect(bool(catalog.get_cached_resolution(first_key).get("ready", false)), "GRT-032: cached resolutions must be shallow defensive copies")
	var debug_state := catalog.get_debug_state()
	_expect(int(debug_state.get("filesystem_probe_count", -1)) == EXPECTED_ASSET_COUNT, "each approved path must be probed exactly once")
	_expect(int(debug_state.get("resource_load_count", -1)) == EXPECTED_ASSET_COUNT, "each approved texture must load exactly once")
	_leg_count += 1


func _verify_negative_cache_and_missing_asset_fallback() -> void:
	var canonical := TowerMapScrollAssetCatalog.new()
	var missing_key := TowerMapScrollAssetCatalog.HUMAN_BAND_ASSET_KEYS[1]
	var missing_path := canonical.resolve_declared_path(missing_key)
	var catalog := TowerMapScrollAssetCatalog.new(
		func(path: String) -> bool:
			return path != missing_path and ResourceLoader.exists(path, "Texture2D"),
		func(path: String) -> Resource:
			return ResourceLoader.load(path, "Texture2D")
	)
	var first := catalog.prewarm_asset(missing_key)
	var second := catalog.prewarm_asset(missing_key)
	_expect(not bool(first.get("ready", true)), "a deleted approved file must select the procedural fallback")
	_expect(str(first.get("reason", "")) == "missing_asset", "a deleted approved file must preserve the missing_asset reason")
	_expect(first.get("texture", null) == null, "a missing file must not fabricate a texture")
	_expect(bool(second.get("cache_hit", false)), "GRT-004: a missing path must remain negatively cached")
	var debug_state := catalog.get_debug_state()
	_expect(int(debug_state.get("filesystem_probe_count", -1)) == 1, "a repeated missing path must not be statted every frame")
	_expect(int(debug_state.get("resource_load_count", -1)) == 0, "a missing path must never reach ResourceLoader.load")
	_leg_count += 1


func _verify_deterministic_nonrepeating_floor_variants() -> void:
	var catalog := TowerMapScrollAssetCatalog.new()
	var previous_key := ""
	var first_pass: Array[String] = []
	for floor_number in range(1, 13):
		var realm_kind := (
			TowerMapScrollAssetCatalog.REALM_IMMORTAL
			if floor_number >= 10
			else TowerMapScrollAssetCatalog.REALM_HUMAN
		)
		var asset_key := TowerMapScrollAssetCatalog.resolve_band_asset_key(realm_kind, floor_number, previous_key)
		_expect(asset_key != previous_key, "adjacent floors %d/%d must not reuse one band variant" % [floor_number - 1, floor_number])
		first_pass.append(asset_key)
		previous_key = asset_key
	var second_pass: Array[String] = []
	previous_key = ""
	for floor_number in range(1, 13):
		var realm_kind := TowerMapScrollAssetCatalog.REALM_IMMORTAL if floor_number >= 10 else TowerMapScrollAssetCatalog.REALM_HUMAN
		var asset_key := TowerMapScrollAssetCatalog.resolve_band_asset_key(realm_kind, floor_number, previous_key)
		second_pass.append(asset_key)
		previous_key = asset_key
	_expect(first_pass == second_pass, "floor band selection must be deterministic and gameplay-RNG free")
	_leg_count += 1


func _verify_opaque_floor_tile_render_model_and_fallback() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "tower-map-scroll-bands",
		"map_seed": 83521,
	}), "the S3 render fixture must begin")
	var renderer := TowerAscentFlowRenderer.new()
	var model := renderer.build_fullscreen_map_model(
		flow,
		Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	)
	var background: Dictionary = model.get("scroll_background", {})
	_expect(bool(background.get("ready", false)), "the live fullscreen model must select approved opaque bands")
	var tiles: Array = background.get("tiles", [])
	var draw_chunks: Array = background.get("draw_chunks", [])
	_expect(
		tiles.size() == (model.get("floor_bands", []) as Array).size()
		and tiles.size() == 12,
		"the default overview must retain one approved band-art contract for floors 1 through 12"
	)
	_expect(draw_chunks.size() >= tiles.size(), "expanded segments must expose every opaque repeated/cropped draw chunk")
	var world_rect: Rect2 = model.get("world_rect", Rect2())
	var tile_world_rect: Rect2 = background.get("world_rect", Rect2())
	var camera: Dictionary = model.get("camera", {})
	var camera_offset: Vector2 = camera.get("offset", Vector2.ZERO)
	var camera_view_rect: Rect2 = model.get("camera_view_rect", Rect2())
	var camera_world_rect: Rect2 = model.get("camera_world_rect", Rect2())
	var camera_render_zoom := float(camera.get("render_zoom_multiplier", 0.0))
	var projected_camera_world := Rect2(
		camera_world_rect.position * camera_render_zoom + camera_offset,
		camera_world_rect.size * camera_render_zoom
	)
	var content_rect: Rect2 = model.get("content_rect", Rect2())
	var map_scale := float(model.get("map_scale", 0.0))
	var previous_key := ""
	var previous_floor := 0
	var asset_key_by_floor := {}
	_expect(is_equal_approx(world_rect.size.x, content_rect.size.x), "the M-key scroll world must fit the live content width")
	var expected_default_zoom := clampf(
		float(model.get("minimum_cover_zoom", 0.0))
			/ TowerAscentTuning.TEMP_MAP_DEFAULT_ZOOMOUT_DIVISOR,
		float(model.get("minimum_fit_all_zoom", 0.0)),
		float(model.get("minimum_cover_zoom", 0.0))
	)
	_expect(is_equal_approx(camera_render_zoom, expected_default_zoom), "the M-key camera must derive four wheel-down notches from its viewport cover")
	_expect(bool(model.get("subcover_active", false)), "the M-key default must activate the explicit scroll surround")
	_expect(
		projected_camera_world.position.x > camera_view_rect.position.x + 0.01
			and projected_camera_world.end.x < camera_view_rect.end.x - 0.01
			and projected_camera_world.position.y <= camera_view_rect.position.y + 0.01
			and projected_camera_world.end.y >= camera_view_rect.end.y - 0.01,
		"the default scroll must expose only horizontal surround while retaining vertical art coverage"
	)
	for index in range(tiles.size()):
		var tile := tiles[index] as Dictionary
		var tile_rect: Rect2 = tile.get("rect", Rect2())
		var asset_key := str(tile.get("asset_key", ""))
		_expect(tile.get("texture", null) is Texture2D, "every visible floor tile must own a cached band texture")
		_expect(tile.get("paper_texture", null) is Texture2D, "the approved common paper must sit below every opaque band")
		_expect(
			asset_key != previous_key,
			"adjacent rendered floors %d/%d must not repeat variant %s"
				% [previous_floor, int(tile.get("floor", 0)), asset_key]
		)
		_expect(is_equal_approx(tile_rect.position.x, tile_world_rect.position.x) and is_equal_approx(tile_rect.size.x, tile_world_rect.size.x), "every band must span the scroll width")
		_expect(tile_rect.size.is_equal_approx(Vector2(692.0, 320.0) * map_scale), "each opaque band must preserve its approved aspect ratio at M-key content scale: floor=%d size=%s" % [int(tile.get("floor", 0)), str(tile_rect.size)])
		asset_key_by_floor[int(tile.get("floor", 0))] = asset_key
		previous_key = asset_key
		previous_floor = int(tile.get("floor", 0))
	var previous_end_y := tile_world_rect.position.y
	var expected_overlap_base_world_px := 56.0
	_expect(
		is_equal_approx(
			renderer.get_map_scroll_band_seam_overlap_world_px(),
			expected_overlap_base_world_px
		),
		"band chunks must retain the approved 56px base-world overlap"
	)
	var expected_overlap := expected_overlap_base_world_px * map_scale
	_expect(draw_chunks.size() == 22, "the 34-row map must retain its existing 22 draw chunks")
	_expect(
		int(background.get("draw_call_count", -1)) == draw_chunks.size() * 2,
		"bounded entry/body/tail phases must remain one art draw per chunk"
	)
	var first_band_scale := _chunk_vertical_scale(draw_chunks[0] as Dictionary, "texture")
	var first_chunk := draw_chunks[0] as Dictionary
	var first_paper_scale := _chunk_vertical_scale_for_rects(
		first_chunk.get("paper_rect", Rect2()),
		first_chunk.get("normalized_source_rect", Rect2()),
		first_chunk.get("paper_texture", null) as Texture2D
	)
	var production_scales_match := true
	var production_source_bounds_ok := true
	for chunk_index in range(draw_chunks.size()):
		var chunk_variant: Variant = draw_chunks[chunk_index]
		var chunk := chunk_variant as Dictionary
		var chunk_rect: Rect2 = chunk.get("rect", Rect2())
		var alpha_ramp_world_px := float(chunk.get("alpha_ramp_world_px", -1.0))
		var source_rect: Rect2 = chunk.get(
			"normalized_source_rect",
			Rect2(0.0, 0.0, 1.0, 1.0)
		)
		var paper_rect: Rect2 = chunk.get("paper_rect", Rect2())
		var paper_source_rect: Rect2 = chunk.get("paper_source_rect", Rect2())
		var seam_entry_rect: Rect2 = chunk.get("seam_entry_rect", Rect2())
		var seam_entry_source_rect: Rect2 = chunk.get("seam_entry_source_rect", Rect2())
		var seam_tail_rect: Rect2 = chunk.get("seam_tail_rect", Rect2())
		var seam_tail_source_rect: Rect2 = chunk.get("seam_tail_source_rect", Rect2())
		_expect(chunk.get("texture", null) is Texture2D, "every opaque draw chunk must own its cached band texture")
		_expect(chunk.get("paper_texture", null) is Texture2D, "every opaque draw chunk must retain the common paper underlay")
		_expect(
			str(chunk.get("asset_key", ""))
				== str(asset_key_by_floor.get(int(chunk.get("floor", 0)), "")),
			"every repeated/cropped chunk must retain its floor's selected variant"
		)
		_expect(
			is_equal_approx(chunk_rect.position.x, tile_world_rect.position.x)
			and is_equal_approx(chunk_rect.size.x, tile_world_rect.size.x),
			"every repeated band chunk must span the scroll width"
		)
		var required_overlap := expected_overlap if chunk_index > 0 else 0.0
		_expect(
			is_equal_approx(paper_rect.position.y, previous_end_y)
			and is_equal_approx(chunk_rect.position.y, paper_rect.position.y)
			and is_equal_approx(chunk_rect.end.y, paper_rect.end.y - required_overlap),
			"native-scale band bodies must reserve exactly one reflected tail"
		)
		_expect(
			is_equal_approx(alpha_ramp_world_px, required_overlap),
			"every overlap must carry the matching vertical alpha ramp"
		)
		_expect(
			is_equal_approx(
				source_rect.size.y,
				chunk_rect.size.y / (320.0 * map_scale)
			),
			"band-body source and target heights must preserve native scale"
		)
		_expect(
			is_equal_approx(source_rect.position.y, required_overlap / (320.0 * map_scale)),
			"later bodies must begin after the omitted bright source gutter"
		)
		var body_source_bounds_ok := (
			source_rect.position.y >= -0.0001 and source_rect.end.y <= 1.0001
		)
		var paper_source_bounds_ok := (
			paper_source_rect.position.y >= -0.0001
			and paper_source_rect.end.y <= 1.0001
		)
		production_source_bounds_ok = (
			production_source_bounds_ok
			and body_source_bounds_ok
			and paper_source_bounds_ok
		)
		_expect(
			body_source_bounds_ok,
			"every band-body source rect must stay inside normalized texture bounds"
		)
		_expect(
			paper_source_bounds_ok,
			"every paper source rect must stay inside normalized texture bounds"
		)
		if chunk_index == 0:
			_expect(
				not seam_entry_rect.has_area()
				and not seam_entry_source_rect.has_area()
				and not seam_tail_rect.has_area()
				and not seam_tail_source_rect.has_area(),
				"the map-top chunk must omit incoming seam phase geometry"
			)
		else:
			_expect(
				is_equal_approx(seam_entry_rect.position.y, paper_rect.position.y - required_overlap)
				and is_equal_approx(seam_entry_rect.end.y, paper_rect.position.y),
				"every real seam must own one bounded incoming phase strip"
			)
			var entry_source_bounds_ok := (
				seam_entry_source_rect.position.y >= -0.0001
				and seam_entry_source_rect.end.y <= 1.0001
			)
			production_source_bounds_ok = (
				production_source_bounds_ok and entry_source_bounds_ok
			)
			_expect(
				entry_source_bounds_ok,
				"every seam-entry source rect must stay inside normalized texture bounds"
			)
			_expect(
				is_equal_approx(
					_chunk_vertical_scale_for_rects(
						seam_entry_rect,
						seam_entry_source_rect,
						chunk.get("texture", null) as Texture2D
					),
					first_band_scale
				),
				"every reflected seam entry must preserve native art scale"
			)
			_expect(
				is_equal_approx(seam_tail_rect.position.y, chunk_rect.end.y)
				and is_equal_approx(seam_tail_rect.end.y, paper_rect.end.y),
				"every shifted body must end in one bounded reflected tail"
			)
			var tail_source_bounds_ok := (
				seam_tail_source_rect.position.y >= -0.0001
				and seam_tail_source_rect.end.y <= 1.0001
			)
			production_source_bounds_ok = (
				production_source_bounds_ok and tail_source_bounds_ok
			)
			_expect(
				tail_source_bounds_ok,
				"every seam-tail source rect must stay inside normalized texture bounds"
			)
			_expect(
				is_equal_approx(
					_chunk_vertical_scale_for_rects(
						seam_tail_rect,
						seam_tail_source_rect,
						chunk.get("texture", null) as Texture2D
					),
					first_band_scale
				),
				"every reflected seam tail must preserve the first chunk's native art scale"
			)
		var band_scale_matches := is_equal_approx(
			_chunk_vertical_scale(chunk, "texture"),
			first_band_scale
		)
		var paper_scale_matches := is_equal_approx(
			_chunk_vertical_scale_for_rects(
				paper_rect,
				paper_source_rect,
				chunk.get("paper_texture", null) as Texture2D
			),
			first_paper_scale
		)
		production_scales_match = (
			production_scales_match and band_scale_matches and paper_scale_matches
		)
		_expect(
			band_scale_matches,
			"band layer scale must match the first chunk for every production chunk"
		)
		_expect(
			paper_scale_matches,
			"paper layer scale must match the first chunk for every production chunk"
		)
		_expect(not chunk.has("content_rect"), "content_rect must not survive as duplicate dead geometry")
		_expect(chunk.has("paper_rect"), "paper_rect must remain the live logical chunk geometry")
		previous_end_y = paper_rect.end.y
	_expect(
		is_equal_approx(previous_end_y, tile_world_rect.end.y),
		"the opaque tile stack must cover the complete scroll world: end=%.3f expected=%.3f"
			% [previous_end_y, tile_world_rect.end.y]
	)
	print(
		"[TowerMapBandScaleInvariant] production_chunks=%d scale_match=%s band_scale=%.6f paper_scale=%.6f source_bounds=%s entries=%d reflected_tails=%d"
			% [
				draw_chunks.size(),
				str(production_scales_match),
				first_band_scale,
				first_paper_scale,
				str(production_source_bounds_ok),
				draw_chunks.size() - 1,
				draw_chunks.size() - 1,
			]
	)
	var legacy: Dictionary = renderer.build_render_model(flow).get("legacy_scroll_background", {})
	_expect(bool(legacy.get("ready", false)), "the transformed legacy surface must use the same approved tiles")

	var catalog := TowerMapScrollAssetCatalog.new()
	catalog.prewarm_all()
	var resolutions: Dictionary = {}
	for asset_key in catalog.get_asset_keys():
		resolutions[asset_key] = catalog.get_cached_resolution(asset_key)
	var missing_key := str((tiles[0] as Dictionary).get("asset_key", ""))
	var missing_resolution: Dictionary = (resolutions[missing_key] as Dictionary).duplicate(false)
	missing_resolution["ready"] = false
	missing_resolution["texture"] = null
	resolutions[missing_key] = missing_resolution
	var fallback := renderer.build_scroll_background_model(
		model.get("floor_bands", []),
		world_rect,
		str(model.get("realm_kind", "human_realm")),
		resolutions
	)
	_expect(not bool(fallback.get("ready", true)), "a missing used band must keep the procedural fallback alive")
	_expect(str(fallback.get("reason", "")) == "band_unavailable", "the fallback must identify its missing band gate")
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	_expect(renderer_source.find("draw_texture_rect_region") >= 0, "S3 must crop only camera-visible source regions")
	_expect(renderer_source.find("alpha = entry_t") >= 0, "band entries must retain their vertex-alpha fade owner")
	_expect(renderer_source.find("_draw_scroll_texture_phase") >= 0, "every real seam must retain its bounded reflected entry/tail owner")
	_expect(renderer_source.find("canvas.draw_polygon(polygon_points, colors, uvs, texture)") >= 0, "the seam ramp must remain one polygon draw per RGB band chunk")
	_expect(renderer_source.find("draw_rect(MAP_RECT, PAPER, true)") >= 0, "S3 must retain the procedural paper fallback")
	_leg_count += 1


func _verify_band_chunk_scale_invariant_boundary_fixture() -> void:
	var catalog := TowerMapScrollAssetCatalog.new()
	catalog.prewarm_all()
	var resolutions: Dictionary = {}
	for asset_key in catalog.get_asset_keys():
		resolutions[asset_key] = catalog.get_cached_resolution(asset_key)
	var chunk_heights := PackedFloat32Array([320.0, 320.0, 160.0, 100.0])
	var floor_bands: Array[Dictionary] = []
	var chunk_y := 0.0
	for index in range(chunk_heights.size()):
		var chunk_height := float(chunk_heights[index])
		floor_bands.append({
			"segment_floor": index + 1,
			"realm_kind": "human_realm",
			"segment_rect": Rect2(0.0, chunk_y, 692.0, chunk_height),
			"y": chunk_y + chunk_height * 0.5,
		})
		chunk_y += chunk_height
	var renderer := TowerAscentFlowRenderer.new()
	var model := renderer.build_scroll_background_model(
		floor_bands,
		Rect2(0.0, 0.0, 692.0, chunk_y),
		"human_realm",
		resolutions,
		Vector2(692.0, 320.0)
	)
	_expect(bool(model.get("ready", false)), "scale boundary fixture must resolve approved textures")
	var chunks: Array = model.get("draw_chunks", [])
	_expect(chunks.size() == chunk_heights.size(), "scale boundary fixture must retain one chunk per requested height")
	if chunks.size() != chunk_heights.size():
		_leg_count += 1
		return
	var expected_fades := PackedFloat32Array([0.0, 56.0, 56.0, 50.0])
	var expected_target_heights := PackedFloat32Array([320.0, 264.0, 104.0, 50.0])
	var expected_entry_heights := PackedFloat32Array([0.0, 56.0, 56.0, 50.0])
	var expected_tail_heights := PackedFloat32Array([0.0, 56.0, 56.0, 50.0])
	var first_band_scale := _chunk_vertical_scale(chunks[0] as Dictionary, "texture")
	var first_paper_scale := _chunk_vertical_scale(chunks[0] as Dictionary, "paper_texture")
	var boundary_scales_match := true
	var boundary_source_bounds_ok := true
	for index in range(chunks.size()):
		var chunk := chunks[index] as Dictionary
		var chunk_rect: Rect2 = chunk.get("rect", Rect2())
		var source_rect: Rect2 = chunk.get("normalized_source_rect", Rect2())
		var paper_rect: Rect2 = chunk.get("paper_rect", Rect2())
		var paper_source_rect: Rect2 = chunk.get("paper_source_rect", Rect2())
		var entry_rect: Rect2 = chunk.get("seam_entry_rect", Rect2())
		var entry_source_rect: Rect2 = chunk.get("seam_entry_source_rect", Rect2())
		var tail_rect: Rect2 = chunk.get("seam_tail_rect", Rect2())
		var tail_source_rect: Rect2 = chunk.get("seam_tail_source_rect", Rect2())
		_expect(
			is_equal_approx(chunk_rect.size.y, float(expected_target_heights[index])),
			"boundary chunk %d target must expand by exactly its source-matched overlap" % index
		)
		_expect(
			is_equal_approx(float(chunk.get("alpha_ramp_world_px", -1.0)), float(expected_fades[index])),
			"boundary chunk %d must retain the expected 320/160/cap fade span" % index
		)
		_expect(
			is_equal_approx(entry_rect.size.y, float(expected_entry_heights[index])),
			"boundary chunk %d must retain its bounded reflected-entry height" % index
		)
		_expect(
			is_equal_approx(tail_rect.size.y, float(expected_tail_heights[index])),
			"boundary chunk %d must retain its bounded reflected-tail height" % index
		)
		var source_bounds_ok := (
			source_rect.position.y >= -0.0001 and source_rect.end.y <= 1.0001
			and paper_source_rect.position.y >= -0.0001
			and paper_source_rect.end.y <= 1.0001
			and entry_source_rect.position.y >= -0.0001
			and entry_source_rect.end.y <= 1.0001
			and tail_source_rect.position.y >= -0.0001
			and tail_source_rect.end.y <= 1.0001
		)
		boundary_source_bounds_ok = boundary_source_bounds_ok and source_bounds_ok
		_expect(
			source_bounds_ok,
			"320/160/cap body and reflected-tail source rects must stay inside [0,1]"
		)
		var band_scale_matches := is_equal_approx(
			_chunk_vertical_scale(chunk, "texture"),
			first_band_scale
		)
		var paper_scale_matches := is_equal_approx(
			_chunk_vertical_scale_for_rects(
				paper_rect,
				paper_source_rect,
				chunk.get("paper_texture", null) as Texture2D
			),
			first_paper_scale
		)
		boundary_scales_match = (
			boundary_scales_match and band_scale_matches and paper_scale_matches
		)
		_expect(
			band_scale_matches,
			"320/160/cap band scale must match the first 320px chunk"
		)
		_expect(
			paper_scale_matches,
			"320/160/cap paper scale must match the first 320px chunk"
		)
	print(
		"[TowerMapBandScaleBoundary] content_heights=320,320,160,100 target_heights=320,264,104,50 entry_heights=0,56,56,50 tail_heights=0,56,56,50 fades=0,56,56,50 scale_match=%s source_bounds=%s band_scale=%.6f paper_scale=%.6f"
			% [
				str(boundary_scales_match),
				str(boundary_source_bounds_ok),
				first_band_scale,
				first_paper_scale,
			]
	)
	_leg_count += 1


func _chunk_vertical_scale(chunk: Dictionary, texture_key: String) -> float:
	var texture := chunk.get(texture_key, null) as Texture2D
	var target_rect: Rect2 = chunk.get("rect", Rect2())
	var source_rect: Rect2 = chunk.get("normalized_source_rect", Rect2())
	if texture == null or source_rect.size.y <= 0.0 or texture.get_height() <= 0:
		return -1.0
	return target_rect.size.y / (source_rect.size.y * float(texture.get_height()))


func _chunk_vertical_scale_for_rects(
	target_rect: Rect2,
	source_rect: Rect2,
	texture: Texture2D
) -> float:
	if texture == null or source_rect.size.y <= 0.0 or texture.get_height() <= 0:
		return -1.0
	return target_rect.size.y / (source_rect.size.y * float(texture.get_height()))


func _verify_fullscreen_draw_call_budget_lockstep() -> void:
	var worst_seed := -1
	var worst_draw_calls := -1
	var worst_background_draw_calls := -1
	for map_seed in range(1, 129):
		var flow := TowerAscentFlowOwner.new()
		_expect(flow.begin_vertical_slice(null, Callable(), {
			"run_id": "tower-map-band-seam-budget-%d" % map_seed,
			"map_seed": map_seed,
		}), "the draw-call budget fixture must begin for seed %d" % map_seed)
		var renderer := TowerAscentFlowRenderer.new()
		var model := renderer.build_fullscreen_map_model(
			flow,
			Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
		)
		var debug_state := renderer.get_render_cache_debug_state()
		var draw_calls := int(debug_state.get("total_map_draw_call_budget", -1))
		var background: Dictionary = model.get("scroll_background", {})
		var background_draw_calls := int(background.get("draw_call_count", -1))
		_expect(
			draw_calls <= TowerAscentTuning.TEMP_MAP_PATH_DRAW_CALL_BUDGET,
			"seed %d map draw calls %d must stay within the sealed %d ceiling"
				% [map_seed, draw_calls, TowerAscentTuning.TEMP_MAP_PATH_DRAW_CALL_BUDGET]
		)
		_expect(
			background_draw_calls
				== (background.get("draw_chunks", []) as Array).size() * 2,
			"seed %d must retain one paper and one phase-mapped art draw per chunk"
				% map_seed
		)
		if draw_calls > worst_draw_calls:
			worst_seed = map_seed
			worst_draw_calls = draw_calls
			worst_background_draw_calls = background_draw_calls
		if flow.has_method("_finish_vertical_slice"):
			flow.call("_finish_vertical_slice")
	print(
		"[TowerMapBandSeamBudget] seeds=128 worst_seed=%d map_draw_calls=%d/%d background_draw_calls=%d"
			% [
				worst_seed,
				worst_draw_calls,
				TowerAscentTuning.TEMP_MAP_PATH_DRAW_CALL_BUDGET,
				worst_background_draw_calls,
			]
	)
	_leg_count += 1


func _verify_production_prewarm_order_and_draw_peek_contract() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	var cold := flow.get_map_scroll_asset_resolution(TowerMapScrollAssetCatalog.COMMON_HANJI_PAPER)
	_expect(not bool(cold.get("cached", true)), "the production owner must begin with a non-probing cold peek")
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "tower-map-scroll-prewarm",
		"map_seed": 83521,
	}), "the production flow fixture must begin")
	var debug_state := flow.get_map_scroll_asset_debug_state()
	_expect(int(debug_state.get("entry_count", 0)) == EXPECTED_ASSET_COUNT, "prepare must prewarm all 16 files before map draw")
	_expect(int(debug_state.get("ready_count", 0)) == EXPECTED_ASSET_COUNT, "production prewarm must retain all approved textures")
	var map_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_map_progress.gd"
	)
	var prepare_body := _function_body(map_source, "func prepare_vertical_slice_combat(")
	var prewarm_index := prepare_body.find("_prewarm_map_scroll_assets()")
	var ready_index := prepare_body.find("_prepared = true")
	_expect(prewarm_index >= 0 and ready_index > prewarm_index, "GRT-003: map art prewarm must finish before the flow becomes drawable")
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	# The sanctioned prewarm-aware wrapper is ProjectResourceLoader.load_imported_texture,
	# whose name contains "ResourceLoader.load" as a substring. Strip the wrapper before
	# searching so the seal still catches a RAW engine load on the draw owner.
	var raw_load_source: String = renderer_source.replace("ProjectResourceLoader.load_imported_texture", "")
	raw_load_source = raw_load_source.replace("ProjectResourceLoader.load_texture", "")
	_expect(raw_load_source.find("ResourceLoader.load") < 0, "draw ownership must not load resources")
	_expect(raw_load_source.find("ResourceLoader.exists") < 0, "draw ownership must not probe missing paths")
	_leg_count += 1


func _verify_three_route_brush_states_and_geometry() -> void:
	var renderer := TowerAscentFlowRenderer.new()
	var edge := {"from": "floor_1_gate", "to": "floor_2_left"}
	var unselected_key := renderer.resolve_route_brush_asset_key(edge, [], [], "floor_1_gate")
	var available_key := renderer.resolve_route_brush_asset_key(
		edge,
		[],
		["floor_2_left"],
		"floor_1_gate"
	)
	var completed_key := renderer.resolve_route_brush_asset_key(
		edge,
		[{"from": "floor_1_gate", "to": "floor_2_left"}],
		["floor_2_left"],
		"floor_1_gate"
	)
	_expect(unselected_key == TowerMapScrollAssetCatalog.ROUTE_BRUSH_UNSELECTED, "an inactive route must use the approved unselected brush")
	_expect(available_key == TowerMapScrollAssetCatalog.ROUTE_BRUSH_AVAILABLE, "a current-node candidate must use the approved available brush")
	_expect(completed_key == TowerMapScrollAssetCatalog.ROUTE_BRUSH_COMPLETED_GOLD, "route history must take priority and use the approved gold brush")
	_expect(unselected_key != available_key and available_key != completed_key and completed_key != unselected_key, "the three route states must never collapse to alpha variants of one key")
	var route_clip := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var clipped_edge := {
		"from_position": Vector2(50.0, 50.0),
		"to_position": Vector2(50.0, 140.0),
	}
	_expect(not renderer.should_draw_route_edge_in_view(clipped_edge, unselected_key, route_clip), "an unselected edge with an offscreen endpoint must not leave an orphan brush tail")
	_expect(not renderer.should_draw_route_edge_in_view(clipped_edge, available_key, route_clip), "an available edge with an offscreen endpoint must wait until both nodes are visible")
	_expect(renderer.should_draw_route_edge_in_view(clipped_edge, completed_key, route_clip), "completed gold history must retain its established clipped continuation")
	clipped_edge["to_position"] = Vector2(50.0, 90.0)
	_expect(renderer.should_draw_route_edge_in_view(clipped_edge, unselected_key, route_clip), "a non-gold edge between two visible nodes must remain drawable")

	var catalog := TowerMapScrollAssetCatalog.new()
	catalog.prewarm_all()
	var texture_paths := PackedStringArray()
	for asset_key in [unselected_key, available_key, completed_key]:
		var texture := catalog.get_cached_resolution(asset_key).get("texture", null) as Texture2D
		_expect(texture != null, "%s must resolve to its own approved brush texture" % asset_key)
		if texture != null:
			texture_paths.append(texture.resource_path)
	_expect(texture_paths.size() == 3 and texture_paths[0] != texture_paths[1] and texture_paths[1] != texture_paths[2] and texture_paths[2] != texture_paths[0], "the three path states must bind three distinct files")

	var quads := renderer.build_route_brush_strip(PackedVector2Array([
		Vector2(100.0, 300.0),
		Vector2(124.0, 220.0),
		Vector2(112.0, 140.0),
	]))
	var completed_quads := renderer.build_completed_route_brush_strip(PackedVector2Array([
		Vector2(100.0, 300.0),
		Vector2(124.0, 220.0),
		Vector2(112.0, 140.0),
	]))
	_expect(quads.size() >= 4, "a long curved route must tile the vertical brush instead of stretching one copy end to end")
	_expect(quads.size() > completed_quads.size(), "non-gold routes must overlap more brush copies while completed gold keeps its approved spacing")
	var saw_full_tile := false
	var saw_uv_restart := false
	var previous_tile_start := -INF
	for quad_index in range(quads.size()):
		var quad := quads[quad_index] as Dictionary
		var quad_points: PackedVector2Array = quad.get("points", PackedVector2Array())
		var quad_uvs: PackedVector2Array = quad.get("uvs", PackedVector2Array())
		_expect(quad_points.size() == 4, "every brush tile segment must remain a textured quad")
		if quad_points.size() == 4:
			_expect(is_equal_approx(quad_points[0].distance_to(quad_points[1]), 18.0), "route width must stay at the fixed 18px world contract")
			_expect(is_equal_approx(quad_points[2].distance_to(quad_points[3]), 18.0), "route width must not grow with edge length")
			var texture_axis := (
				(quad_points[2] + quad_points[3]) * 0.5
				- (quad_points[0] + quad_points[1]) * 0.5
			).normalized()
			var path_direction: Vector2 = quad.get("path_direction", Vector2.ZERO)
			_expect(texture_axis.dot(path_direction) >= 0.999, "the texture vertical axis must align with the local route direction")
		_expect(float(quad.get("world_length", INF)) <= 80.001, "no brush tile may exceed the 72:320 aspect-ratio length")
		_expect(is_equal_approx(float(quad.get("tile_stride", 0.0)), 28.0), "non-gold route stamps must advance by the dense 28px stride")
		var tile_start := float(quad.get("tile_start_distance", INF))
		if is_finite(previous_tile_start):
			_expect(is_equal_approx(tile_start - previous_tile_start, 28.0), "dense route stamps must overlap at one deterministic stride")
		previous_tile_start = tile_start
		if quad_uvs.size() == 4:
			_expect(quad_uvs[0].y >= -0.001 and quad_uvs[2].y <= 1.001, "each tiled brush copy must use normalized vertical UVs")
			saw_full_tile = saw_full_tile or is_equal_approx(quad_uvs[2].y, 1.0)
			if quad_index > 0:
				var previous_uvs: PackedVector2Array = (quads[quad_index - 1] as Dictionary).get("uvs", PackedVector2Array())
				if previous_uvs.size() == 4 and is_equal_approx(previous_uvs[2].y, 1.0) and is_equal_approx(quad_uvs[0].y, 0.0):
					saw_uv_restart = true
	_expect(saw_full_tile and saw_uv_restart, "vertical brush UVs must restart for each along-path tile")

	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "tower-map-scroll-brush",
		"map_seed": 83521,
	}), "the S4 production brush fixture must begin")
	var model := renderer.build_fullscreen_map_model(
		flow,
		Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	)
	var model_edges: Array = model.get("edges", [])
	_expect(not model_edges.is_empty() and not ((model_edges[0] as Dictionary).get("brush_quads", []) as Array).is_empty(), "fullscreen curved routes must cache textured brush geometry")
	var art_radius := float(model.get("art_size", 0.0)) * 0.5
	for model_edge_variant in model_edges:
		var model_edge := model_edge_variant as Dictionary
		_expect(
			(model_edge.get("path_start", Vector2.ZERO) as Vector2).distance_to(
				model_edge.get("from_position", Vector2.ZERO) as Vector2
			) <= art_radius + 0.001,
			"route starts must clamp under the source medal instead of leaving an orphan stamp"
		)
		_expect(
			(model_edge.get("path_end", Vector2.ZERO) as Vector2).distance_to(
				model_edge.get("to_position", Vector2.ZERO) as Vector2
			) <= art_radius + 0.001,
			"route ends must clamp under the target medal instead of protruding past the node"
		)
	var cache_state := renderer.get_render_cache_debug_state()
	_expect(int(cache_state.get("path_brush_segment_count", 0)) > 0, "the render cache must account for brush strip segments")
	_expect(int(cache_state.get("path_brush_draw_call_budget", -1)) == int(cache_state.get("path_brush_segment_count", 0)), "the brush strip draw-call budget must remain explicit")
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	_expect(renderer_source.find("canvas.draw_polygon(") >= 0, "S4 must actually draw the approved brush textures")
	# The training-dummy floor-pivot wobble (862a27477) legitimately rotates via
	# a temporary draw transform. The playfield-transform contract is therefore
	# balance, not absence: every non-identity draw_set_transform must pair with
	# an immediate identity restore so map drawing never inherits a stale matrix.
	var transform_call_count := renderer_source.count("canvas.draw_set_transform(")
	var identity_restore_count := renderer_source.count(
		"canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)"
	)
	_expect(
		transform_call_count == identity_restore_count * 2,
		"every non-identity draw_set_transform in the map renderer must pair with an identity restore"
	)
	var fullscreen_draw_start := renderer_source.find("func _draw_fullscreen_map_model(")
	var fullscreen_edge_start := renderer_source.find("for edge_variant in model.get(\"edges\", [])", fullscreen_draw_start)
	var fullscreen_plaque_redraw := renderer_source.find("_draw_fullscreen_floor_guides(", fullscreen_edge_start)
	_expect(fullscreen_edge_start >= 0 and fullscreen_plaque_redraw > fullscreen_edge_start, "fullscreen plaques must redraw over route endpoints before medals")
	var legacy_draw_start := renderer_source.find("func _draw_route_map(")
	var legacy_edge_start := renderer_source.find("for edge_variant in edges:", legacy_draw_start)
	var legacy_plaque_redraw := renderer_source.find("_draw_floor_bands(", legacy_edge_start)
	_expect(legacy_edge_start >= 0 and legacy_plaque_redraw > legacy_edge_start, "M-key plaques must redraw over route endpoints before medals")
	_leg_count += 1


func _verify_fullscreen_medal_node_contract() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(null, Callable(), {
		"run_id": "tower-map-scroll-medals",
		"map_seed": 83521,
	}), "the fullscreen medal fixture must begin")
	var renderer := TowerAscentFlowRenderer.new()
	var model := renderer.build_fullscreen_map_model(
		flow,
		Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
	)
	_expect(is_equal_approx(float(model.get("art_size", 0.0)), 32.0 * float(model.get("map_scale", 0.0))), "M-key node medals must follow the same content scale as the scroll")
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	var fullscreen_node_body := _function_body(
		renderer_source,
		"func _draw_fullscreen_map_node("
	)
	_expect(fullscreen_node_body.find("NODE_ART_TEXTURES") < 0, "fullscreen nodes must not place the legacy square art tile behind approved medals")
	_expect(fullscreen_node_body.find("canvas.draw_circle(") >= 0, "fullscreen nodes must use the same circular medal frame language as the approved composite")
	_expect(fullscreen_node_body.find("build_map_icon_presentation(node)") >= 0, "fullscreen medals must keep the approved iconography catalog")
	var target_ids: Array[String] = flow.get_route_target_ids()
	_expect(not target_ids.is_empty(), "the 2.15x gameplay fixture must expose a route target")
	if not target_ids.is_empty():
		flow.call("_resolve_route_target", target_ids[0])
		var total := (
			TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
			+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
			+ TowerAscentTuning.TEMP_MAP_TRANSITION_CAMERA_ZOOM_IN_SEC
			+ TowerAscentTuning.TEMP_MAP_TRANSITION_TRAVEL_SEC
			+ TowerAscentTuning.TEMP_MAP_TRANSITION_ARRIVE_VANISH_SEC
			+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_OUT_SEC
		)
		flow.set_transition_progress_for_qa(
			(
				TowerAscentTuning.TEMP_MAP_TRANSITION_BATTLE_FADE_OUT_SEC
				+ TowerAscentTuning.TEMP_MAP_TRANSITION_MAP_FADE_IN_SEC
			) / total
		)
		var gameplay_model := renderer.build_fullscreen_map_model(
			flow,
			Rect2(Vector2.ZERO, Vector2(2020.0, 1246.0))
		)
		var gameplay_camera: Dictionary = gameplay_model.get("camera", {})
		var gameplay_base_zoom := float(gameplay_camera.get("base_zoom_multiplier", 0.0))
		var gameplay_default_zoom := clampf(
			float(gameplay_model.get("minimum_cover_zoom", 0.0))
				/ TowerAscentTuning.TEMP_MAP_DEFAULT_ZOOMOUT_DIVISOR,
			float(gameplay_model.get("minimum_fit_all_zoom", 0.0)),
			float(gameplay_model.get("minimum_cover_zoom", 0.0))
		)
		_expect(is_equal_approx(gameplay_base_zoom, gameplay_default_zoom), "the walking transition must begin at the four-notch-out base")
		_expect(is_equal_approx(float(gameplay_camera.get("zoom_multiplier", 0.0)), 1.0), "the existing 1.0 to 1.18 walker intro multiplier must remain separate from the cover-aware base zoom")
	_leg_count += 1


func _verify_floor_gate_plaque_three_slice_contract() -> void:
	var renderer := TowerAscentFlowRenderer.new()
	var target_rect := renderer.build_floor_plaque_target_rect(Vector2(346.0, 320.0))
	_expect(target_rect.size.is_equal_approx(Vector2(184.0, 24.0)), "the runtime plaque must read as a compact floor marker rather than a shelf")
	var slices := renderer.build_horizontal_three_slice_model(
		Vector2(2480.0, 192.0),
		target_rect
	)
	_expect(slices.size() == 3, "the x4 plaque must render as left, stretchable middle, and right slices")
	if slices.size() == 3:
		var left := slices[0] as Dictionary
		var middle := slices[1] as Dictionary
		var right := slices[2] as Dictionary
		var left_source: Rect2 = left.get("source_rect", Rect2())
		var middle_source: Rect2 = middle.get("source_rect", Rect2())
		var right_source: Rect2 = right.get("source_rect", Rect2())
		var left_target: Rect2 = left.get("target_rect", Rect2())
		var middle_target: Rect2 = middle.get("target_rect", Rect2())
		var right_target: Rect2 = right.get("target_rect", Rect2())
		_expect(is_equal_approx(left_source.size.x, 192.0) and is_equal_approx(right_source.size.x, 192.0), "the plaque endcaps must retain their approved square source geometry at x4 density")
		_expect(is_equal_approx(left_target.size.x, target_rect.size.y) and is_equal_approx(right_target.size.x, target_rect.size.y), "horizontal stretching must preserve both endcap aspect ratios")
		_expect(is_equal_approx(left_target.end.x, middle_target.position.x) and is_equal_approx(middle_target.end.x, right_target.position.x), "plaque slices must meet without gaps")
		_expect(is_equal_approx(left_source.end.x, middle_source.position.x) and is_equal_approx(middle_source.end.x, right_source.position.x), "three-slice source regions must cover the approved texture continuously")
		_expect(is_equal_approx(right_source.end.x, 2480.0) and is_equal_approx(right_target.end.x, target_rect.end.x), "three-slice rendering must cover both full source and target widths")
	var catalog := TowerMapScrollAssetCatalog.new()
	catalog.prewarm_all()
	var plaque_resolution := catalog.get_cached_resolution(
		TowerMapScrollAssetCatalog.FLOOR_GATE_PLAQUE
	)
	var plaque_texture := plaque_resolution.get("texture", null) as Texture2D
	_expect(plaque_texture != null and Vector2i(plaque_texture.get_size()) == Vector2i(2480, 192), "S5 must use the x4 plaque texture without changing its world rect")
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	_expect(renderer_source.find("_draw_floor_plaque(") >= 0 and renderer_source.find("build_horizontal_three_slice_model(") >= 0, "both map surfaces must use the approved plaque and runtime floor number overlay")
	_leg_count += 1


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	return source.substr(start) if next_func < 0 else source.substr(start, next_func - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
