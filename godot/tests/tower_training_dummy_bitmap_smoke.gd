extends SceneTree

const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerTrainingStrikePresentationState := preload(
	"res://scripts/tower_ascent/tower_training_strike_presentation_state.gd"
)

const ASSET_PATH := "res://assets/sprites/tower/noncombat/training_dummy_imagegen_v1.png"
const IMPORT_PATH := ASSET_PATH + ".import"
const EXPECTED_SHA256 := "da674f5b6e2df25e6a10126d637e1a21812449b46618d1e774b186a94dac0c58"
const EXPECTED_SIZE := Vector2i(256, 256)
const EXPECTED_PIVOT := Vector2(128.0, 236.0)
const EXPECTED_ALPHA_BOUNDS := Rect2i(54, 64, 148, 172)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_promoted_asset_and_import()
	_verify_prewarm_and_procedural_fallback()
	_verify_shared_floor_pivot_for_s6_tiers()
	_verify_source_ownership()
	if _failures.is_empty():
		print("tower_training_dummy_bitmap_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_promoted_asset_and_import() -> void:
	_expect(FileAccess.file_exists(ASSET_PATH), "approved C training dummy PNG must be promoted")
	_expect(FileAccess.file_exists(IMPORT_PATH), "approved C training dummy must carry its .import sidecar")
	if not FileAccess.file_exists(ASSET_PATH):
		return
	_expect(
		FileAccess.get_sha256(ASSET_PATH).to_lower() == EXPECTED_SHA256,
		"promoted runtime PNG bytes must exactly match approved candidate C"
	)
	var image := Image.load_from_file(ProjectSettings.globalize_path(ASSET_PATH))
	_expect(image != null and not image.is_empty(), "promoted training dummy PNG must decode")
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == EXPECTED_SIZE, "training dummy runtime canvas must stay 256x256")
	_expect(_alpha_bounds(image) == EXPECTED_ALPHA_BOUNDS, "candidate C alpha bounds must stay 148x172 at [54,64,202,236)")
	_expect(_edge_alpha_count(image) == 0, "training dummy transparent canvas edges must remain empty")
	_expect(_alpha_count_at_or_below(image, int(EXPECTED_PIVOT.y)) == 0, "no dummy pixel may extend below the floor pivot")
	_expect(_visible_green_fringe_count(image) == 0, "promoted alpha must contain no chroma-green fringe")
	var import_source := FileAccess.get_file_as_string(IMPORT_PATH)
	_expect(import_source.contains('source_file="%s"' % ASSET_PATH), ".import source path must target the promoted PNG")
	_expect(import_source.contains("training_dummy_imagegen_v1.png-") and import_source.contains(".ctex"), ".import must name its materialized texture")
	_expect(import_source.contains("compress/mode=0"), "single-frame UI-stage prop must retain lossless texture import")
	_expect(import_source.contains("mipmaps/generate=false"), "1x modal prop must not generate unused mipmaps")


func _verify_prewarm_and_procedural_fallback() -> void:
	var renderer := TowerAscentFlowRenderer.new()
	var loaded: Dictionary = renderer.get_training_dummy_asset_debug_state()
	_expect(bool(loaded.get("loaded", false)), "renderer construction must prewarm the approved dummy before draw")
	_expect(str(loaded.get("render_mode", "")) == "bitmap", "prewarmed renderer must select bitmap mode")
	_expect(Vector2i(loaded.get("texture_size", Vector2i.ZERO)) == EXPECTED_SIZE, "prewarmed texture must resolve at 256x256")
	_expect(str(loaded.get("texture_class", "")) == "CompressedTexture2D", "local proof must consume the imported .ctex texture")
	renderer.debug_set_training_dummy_texture(null)
	var fallback: Dictionary = renderer.get_training_dummy_asset_debug_state()
	_expect(not bool(fallback.get("loaded", true)), "missing-texture counterproof must clear bitmap state")
	_expect(str(fallback.get("render_mode", "")) == "procedural_fallback", "missing bitmap must explicitly retain the procedural dummy")
	renderer.prewarm_training_dummy_asset()
	_expect(bool(renderer.get_training_dummy_asset_debug_state().get("loaded", false)), "explicit prewarm must recover bitmap mode after fallback counterproof")


func _verify_shared_floor_pivot_for_s6_tiers() -> void:
	var renderer := TowerAscentFlowRenderer.new()
	var contract: Dictionary = renderer.get_training_dummy_asset_contract()
	_expect(str(contract.get("path", "")) == ASSET_PATH, "renderer asset contract must expose the promoted path")
	_expect(Vector2(contract.get("pivot", Vector2.ZERO)).is_equal_approx(EXPECTED_PIVOT), "bitmap pivot must remain candidate C bottom center (128,236)")
	_expect(Rect2i(contract.get("visible_bounds", Rect2i())) == EXPECTED_ALPHA_BOUNDS, "renderer visible bounds must match measured alpha")
	var stage_rect := Rect2(312.0, 150.0, 405.0, 210.0)
	var dummy_slot := Rect2(526.0, 154.0, 174.0, 202.0)
	var expected_floor_pivot := Vector2(dummy_slot.get_center().x, stage_rect.end.y - 13.0)
	var floor_pivot := TowerAscentFlowRenderer.resolve_training_dummy_floor_pivot(
		dummy_slot,
		stage_rect,
		1.0
	)
	_expect(floor_pivot.is_equal_approx(expected_floor_pivot), "bitmap must inherit S6's established stage-floor pivot")
	var local_rect := TowerAscentFlowRenderer.training_dummy_bitmap_local_rect(1.0)
	_expect(local_rect.position.is_equal_approx(-EXPECTED_PIVOT), "bitmap draw rect must place pixel pivot exactly at local origin")
	_expect(local_rect.size.is_equal_approx(Vector2(EXPECTED_SIZE)), "bitmap draw rect must preserve the approved 256px canvas")
	var tier_specs: Array[Dictionary] = [
		{"kind": "critical", "start": 1000, "sample": 1720, "degrees": 12.0},
		{"kind": "great", "start": 3000, "sample": 3460, "degrees": 7.0},
		{"kind": "base", "start": 5000, "sample": 5460, "degrees": 3.5},
	]
	for spec in tier_specs:
		var state := TowerTrainingStrikePresentationState.new()
		state.configure("smasher", {}, null)
		state.set_clock_msec_for_tests(int(spec.start))
		_expect(state.start(str(spec.kind)), "%s S6 strike must start" % spec.kind)
		state.set_clock_msec_for_tests(int(spec.sample))
		state.update_wall_clock()
		var rotation := rad_to_deg(float(state.get_visual_model().get("dummy_rotation_radians", 0.0)))
		_expect(is_equal_approx(rotation, float(spec.degrees)), "%s bitmap must receive S6's approved wobble tier" % spec.kind)
		_expect(
			TowerAscentFlowRenderer.resolve_training_dummy_floor_pivot(dummy_slot, stage_rect, 1.0).is_equal_approx(floor_pivot),
			"%s wobble must not translate the floor pivot" % spec.kind
		)


func _verify_source_ownership() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	var draw_start := source.find("func _draw_training_dummy(")
	var pivot_start := source.find("static func resolve_training_dummy_floor_pivot", draw_start)
	var dispatcher := source.substr(draw_start, pivot_start - draw_start)
	_expect(draw_start >= 0 and pivot_start > draw_start, "training dummy draw dispatcher must remain inspectable")
	_expect(dispatcher.contains("_training_dummy_texture != null"), "dispatcher must prefer the promoted bitmap")
	_expect(dispatcher.contains("_draw_training_dummy_placeholder("), "dispatcher must retain a visible procedural fallback")
	var bitmap_start := source.find("func _draw_training_dummy_bitmap(")
	var fallback_start := source.find("func _draw_training_dummy_placeholder(", bitmap_start)
	var bitmap_source := source.substr(bitmap_start, fallback_start - bitmap_start)
	_expect(bitmap_source.contains("draw_set_transform(pivot, rotation_radians"), "bitmap must rotate around the shared floor pivot")
	_expect(bitmap_source.contains("draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)"), "temporary bitmap transform must be reset before later modal drawing")
	_expect(bitmap_source.contains("training_dummy_bitmap_local_rect(content_scale)"), "bitmap placement must consume the measured pixel pivot")
	var prewarm_start := source.find("func prewarm_training_dummy_asset()")
	var prewarm_end := source.find("func get_training_dummy_asset_paths", prewarm_start)
	var prewarm_source := source.substr(prewarm_start, prewarm_end - prewarm_start)
	_expect(prewarm_source.contains("ProjectResourceLoader.load_imported_texture"), "prewarm must prefer the tracked imported texture")
	_expect(not dispatcher.contains("load(") and not dispatcher.contains("Image.load"), "draw path must perform zero asset loading or decoding")


func _alpha_bounds(image: Image) -> Rect2i:
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.0:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _edge_alpha_count(image: Image) -> int:
	var count := 0
	for x in range(image.get_width()):
		count += int(image.get_pixel(x, 0).a > 0.0)
		count += int(image.get_pixel(x, image.get_height() - 1).a > 0.0)
	for y in range(1, image.get_height() - 1):
		count += int(image.get_pixel(0, y).a > 0.0)
		count += int(image.get_pixel(image.get_width() - 1, y).a > 0.0)
	return count


func _alpha_count_at_or_below(image: Image, pivot_y: int) -> int:
	var count := 0
	for y in range(pivot_y, image.get_height()):
		for x in range(image.get_width()):
			count += int(image.get_pixel(x, y).a > 0.0)
	return count


func _visible_green_fringe_count(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			if color.g > color.r + 8.0 / 255.0 and color.g > color.b + 8.0 / 255.0:
				count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
