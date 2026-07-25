extends SceneTree

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage7AkamuPillarBackground := preload("res://scripts/stages/stage7/stage7_akamu_pillar_background.gd")
const BattlePsoPrewarmer := preload("res://scripts/core/battle_pso_prewarmer.gd")

const BACKGROUND_SOURCE_PATH := "res://scripts/stages/stage7/stage7_akamu_pillar_background.gd"
const PSO_PREWARM_SOURCE_PATH := "res://scripts/core/battle_pso_prewarmer.gd"
const BASE_PATH := "res://assets/sprites/hud/stage7_akamu_pillar_base_imagegen_v1.png"
const FIELD_PATH := "res://assets/sprites/hud/stage7_akamu_center_field_imagegen_v1.png"
const MOTION_PATH := "res://assets/sprites/hud/stage7_akamu_pillar_motion_sprites_imagegen_v1.png"
const REACTIVE_PATH := "res://assets/sprites/hud/stage7_akamu_pillar_reactive_sprites_imagegen_v1.png"
const MANIFEST_PATH := "res://assets/sprites/hud/stage7_akamu_pillar_field_v1_manifest.json"


class Stage7BackgroundDrawProbe:
	extends Node2D

	var background: Object = null
	var view_size := Vector2(1000.0, 750.0)
	var game_offset := Vector2(120.0, 0.0)
	var game_size := Vector2(760.0, 750.0)
	var draw_count := 0
	var draw_result := false

	func _draw() -> void:
		draw_count += 1
		draw_result = bool(background.draw(
			self,
			view_size,
			game_offset,
			game_size,
			760.0,
			null,
			1.0
		))
		background.draw_pillar_background_overlay(
			self,
			view_size,
			game_offset,
			game_size,
			760.0,
			null,
			1.0
		)


var _failures: Array[String] = []
var _probe: Stage7BackgroundDrawProbe = null
var _pso_probe: Object = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	ProjectResourceLoader.clear_caches()
	_verify_asset_files_and_dimensions()
	_verify_layout_contract()
	_verify_source_and_budget_contract()
	await _verify_prewarm_and_real_draw()
	ProjectResourceLoader.clear_caches()

	if _failures.is_empty():
		print("stage7_akamu_pillar_field_art_smoke: ok")
		call_deferred("_quit_with_code", 0)
	else:
		for failure in _failures:
			push_error(failure)
		call_deferred("_quit_with_code", 1)


func _verify_asset_files_and_dimensions() -> void:
	_expect(FileAccess.file_exists(MANIFEST_PATH), "Stage 7 pillar/field provenance manifest should exist")
	var manifest_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_expect(manifest_value is Dictionary, "Stage 7 pillar/field provenance manifest should parse as JSON")
	if manifest_value is Dictionary:
		var manifest: Dictionary = manifest_value
		var assets: Dictionary = manifest.get("assets", {})
		_expect(str((assets.get("base", {}) as Dictionary).get("runtime", "")) == BASE_PATH, "manifest should route the pillar base runtime path")
		_expect(str((assets.get("field", {}) as Dictionary).get("runtime", "")) == FIELD_PATH, "manifest should route the field runtime path")
		_expect(_manifest_grid(assets, "motion_sprites") == Vector2i(4, 2), "manifest should publish the motion 4x2 grid")
		_expect(int((assets.get("motion_sprites", {}) as Dictionary).get("frame_count", 0)) == 8, "manifest should publish the motion frame count")
		_expect(_manifest_grid(assets, "reactive_sprites") == Vector2i(4, 2), "manifest should publish the reactive 4x2 grid")
		_expect(int((assets.get("reactive_sprites", {}) as Dictionary).get("frame_count", 0)) == 8, "manifest should publish the reactive frame count")
	var specs: Array[Dictionary] = [
		{"path": BASE_PATH, "size": Vector2i(1920, 1080), "alpha": false},
		{"path": FIELD_PATH, "size": Vector2i(1520, 1500), "alpha": false},
		{"path": MOTION_PATH, "size": Vector2i(1024, 576), "alpha": true},
		{"path": REACTIVE_PATH, "size": Vector2i(1024, 576), "alpha": true},
	]
	for spec in specs:
		var path: String = str(spec.get("path", ""))
		_expect(FileAccess.file_exists(path), "%s should exist" % path)
		_expect(FileAccess.file_exists("%s.import" % path), "%s should have a Godot import sidecar" % path)
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		_expect(image != null and not image.is_empty(), "%s should decode for offline asset QA" % path)
		if image == null or image.is_empty():
			continue
		_expect(image.get_size() == spec.get("size", Vector2i.ZERO), "%s should keep its runtime dimensions" % path)
		if bool(spec.get("alpha", false)):
			_verify_transparent_atlas(image, path)


func _manifest_grid(assets: Dictionary, key: String) -> Vector2i:
	var entry: Dictionary = assets.get(key, {})
	var grid: Array = entry.get("grid", [])
	if grid.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(grid[0]), int(grid[1]))


func _verify_transparent_atlas(image: Image, path: String) -> void:
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	_expect(image.get_pixel(0, 0).a <= 0.001, "%s top-left corner should be transparent" % path)
	_expect(image.get_pixel(image.get_width() - 1, image.get_height() - 1).a <= 0.001, "%s bottom-right corner should be transparent" % path)
	var transparent_samples := 0
	var visible_samples := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			if image.get_pixel(x, y).a <= 0.01:
				transparent_samples += 1
			else:
				visible_samples += 1
	_expect(transparent_samples > 1000, "%s should retain transparent cell padding" % path)
	_expect(visible_samples > 100, "%s should retain visible sprite pixels" % path)


func _verify_layout_contract() -> void:
	var background: Object = Stage7AkamuPillarBackground.new()
	var layout: Dictionary = background.get_layout_rects(
		Vector2(1280.0, 800.0),
		Vector2(260.0, 25.0),
		Vector2(760.0, 750.0)
	)
	_expect(layout.get("field", Rect2()) == Rect2(260.0, 25.0, 760.0, 750.0), "Stage 7 field should use the complete 760x750 game canvas")
	_expect(layout.get("left", Rect2()) == Rect2(0.0, 0.0, 260.0, 800.0), "Stage 7 left art should stay in the screen letterbox")
	_expect(layout.get("right", Rect2()) == Rect2(1020.0, 0.0, 260.0, 800.0), "Stage 7 right art should stay in the screen letterbox")

	var narrow_layout: Dictionary = background.get_layout_rects(
		Vector2(1000.0, 750.0),
		Vector2(120.0, 0.0),
		Vector2(760.0, 750.0)
	)
	_expect(narrow_layout.get("left", Rect2()) == Rect2(0.0, 0.0, 120.0, 750.0), "narrow viewport should preserve the left letterbox width")
	_expect(narrow_layout.get("right", Rect2()) == Rect2(880.0, 0.0, 120.0, 750.0), "narrow viewport should preserve the right letterbox width")

	var flush_layout: Dictionary = background.get_layout_rects(
		Vector2(760.0, 750.0),
		Vector2.ZERO,
		Vector2(760.0, 750.0)
	)
	_expect((flush_layout.get("left", Rect2()) as Rect2).size.x == 0.0, "flush layout should allow a zero-width left pillar")
	_expect((flush_layout.get("right", Rect2()) as Rect2).size.x == 0.0, "flush layout should allow a zero-width right pillar")

	var left_narrow := Rect2(0.0, 0.0, 44.0, 750.0)
	var left_props: Dictionary = background.get_reactive_prop_rects(left_narrow, 5, 2.5)
	_expect(_rect_inside(left_props.get("bamboo", Rect2()), left_narrow), "left score jitter should clamp bamboo inside the original letterbox")
	_expect(_rect_inside(left_props.get("ornament", Rect2()), left_narrow), "left score jitter should clamp the ornament inside the original letterbox")
	var right_narrow := Rect2(956.0, 0.0, 44.0, 750.0)
	var right_props: Dictionary = background.get_reactive_prop_rects(right_narrow, 7, -2.5)
	_expect(_rect_inside(right_props.get("bamboo", Rect2()), right_narrow), "right score jitter should clamp bamboo inside the original letterbox")
	_expect(_rect_inside(right_props.get("ornament", Rect2()), right_narrow), "right score jitter should clamp the ornament inside the original letterbox")


func _verify_source_and_budget_contract() -> void:
	var source: String = FileAccess.get_file_as_string(BACKGROUND_SOURCE_PATH)
	for path in [BASE_PATH, FIELD_PATH, MOTION_PATH, REACTIVE_PATH]:
		_expect(source.find(path) >= 0, "Stage 7 background source should reference %s" % path)
	_expect(source.find("prewarm_texture_threaded_step") >= 0, "Stage 7 generated art should use staged threaded prewarm")
	_expect(source.find("Image.load_from_file") < 0, "Stage 7 draw owner should not decode raw images at runtime")
	_expect(source.find("ImageTexture.create_from_image") < 0, "Stage 7 draw owner should not create runtime image textures")
	_expect(source.find("get_image()") < 0, "Stage 7 draw owner should not scan texture pixels")
	_expect(source.find("draw_set_transform") < 0, "Stage 7 pillar owner should not reset the battle canvas transform")
	_expect(source.find("PILLAR_UI_WIDTH") < 0, "Stage 7 art should not revive the legacy 80px playfield inset")
	_expect(source.find("MOTION_ATLAS_FRAMES") >= 0, "motion atlas should own an explicit frame-count authority")
	_expect(source.find("REACTIVE_ATLAS_FRAMES") >= 0, "reactive atlas should own an explicit frame-count authority")
	var pso_source: String = FileAccess.get_file_as_string(PSO_PREWARM_SOURCE_PATH)
	_expect(pso_source.find("_prewarm_stage7_akamu_pillar_field_textures") >= 0, "boot PSO warmup should issue real draws for Stage 7 pillar/field textures")
	for constant_name in ["BASE_TEXTURE_PATH", "FIELD_TEXTURE_PATH", "MOTION_TEXTURE_PATH", "REACTIVE_TEXTURE_PATH"]:
		_expect(
			pso_source.find("Stage7AkamuPillarBackground.%s" % constant_name) >= 0,
			"boot PSO warmup should use the Stage 7 owner constant %s" % constant_name
		)

	var background: Object = Stage7AkamuPillarBackground.new()
	var budget: Dictionary = background.get_performance_snapshot()
	_expect(int(budget.get("static_texture_draws", 99)) == 3, "static art budget should be two side crops plus one field draw")
	_expect(int(budget.get("motion_sprite_draws_full", 99)) <= 8, "full ambient budget should stay at eight atlas draws")
	_expect(int(budget.get("motion_sprite_draws_lod", 99)) <= 4, "LOD ambient budget should stay at four atlas draws")
	_expect(not bool(budget.get("hot_path_image_processing", true)), "background budget should report no hot-path image processing")


func _verify_prewarm_and_real_draw() -> void:
	var background: Object = Stage7AkamuPillarBackground.new()
	var first_done: bool = bool(background.prewarm_assets_step())
	_expect(not first_done, "first Stage 7 art prewarm call should start one texture instead of completing all four synchronously")
	var done: bool = first_done
	var call_count := 1
	while not done and call_count < 800:
		await process_frame
		done = bool(background.prewarm_assets_step())
		call_count += 1
	_expect(done, "Stage 7 pillar/field art prewarm should complete within a bounded number of calls")
	_expect(call_count >= 8, "Stage 7 art prewarm should expose separate texture/touch stages")
	_expect(bool(background.prewarm_assets_step()), "completed Stage 7 art prewarm should be idempotent")

	var status: Dictionary = background.get_asset_status()
	_expect(str(status.get("theme", "")) == "akamu_shadow_dojo_ringpia", "Stage 7 art should publish the shadow-dojo Ringpia theme")
	_expect(bool(status.get("generated_art_loaded", false)), "all four Stage 7 generated art textures should load")
	_expect(not bool(status.get("uses_code_native_placeholder", true)), "generated Stage 7 art should disable the placeholder path after prewarm")
	_expect(status.get("motion_atlas_grid", Vector2i.ZERO) == Vector2i(4, 2), "motion atlas should publish its 4x2 grid")
	_expect(int(status.get("motion_atlas_frames", 0)) == 8, "motion atlas should publish its eight-frame authority")
	_expect(status.get("reactive_atlas_grid", Vector2i.ZERO) == Vector2i(4, 2), "reactive atlas should publish its 4x2 grid")
	_expect(int(status.get("reactive_atlas_frames", 0)) == 8, "reactive atlas should publish its eight-frame authority")
	for path in [BASE_PATH, FIELD_PATH, MOTION_PATH, REACTIVE_PATH]:
		_expect(ProjectResourceLoader.get_cached_texture(path) != null, "resource prewarm should retain %s for GPU upload" % path)

	_pso_probe = BattlePsoPrewarmer.new()
	_pso_probe._warmup_step_index = 23
	_pso_probe._flush_frames_after_warmup = -100
	get_root().add_child(_pso_probe)
	for _frame in range(2):
		await process_frame
	_expect(
		is_instance_valid(_pso_probe) and int(_pso_probe._stage7_art_texture_draws_issued) == 4,
		"boot PSO warmup should issue all four real Stage 7 texture draws after resource prewarm (got %d)" % (
			int(_pso_probe._stage7_art_texture_draws_issued) if is_instance_valid(_pso_probe) else -1
		)
	)
	if is_instance_valid(_pso_probe):
		_pso_probe.queue_free()
	await process_frame
	_pso_probe = null

	background.update(0.25)
	background.trigger_excitement(1.0)
	var active_snapshot: Dictionary = background.get_debug_snapshot()
	_expect(float(active_snapshot.get("ambient_time", 0.0)) > 0.0, "ambient art clock should advance from the owner update path")
	_expect(is_equal_approx(float(active_snapshot.get("excitement", 0.0)), 1.0), "score reaction should arm at full intensity")
	background.update(0.25)
	var decay_snapshot: Dictionary = background.get_debug_snapshot()
	_expect(float(decay_snapshot.get("excitement", 1.0)) < 1.0, "score reaction should decay after its pulse")

	_probe = Stage7BackgroundDrawProbe.new()
	_probe.background = background
	get_root().add_child(_probe)
	_probe.queue_redraw()
	for _frame in range(3):
		await process_frame
	_expect(_probe.draw_count > 0, "Stage 7 generated background should execute in a real CanvasItem draw pass")
	_expect(_probe.draw_result, "Stage 7 generated background draw should return true")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return (
		inner.position.x >= outer.position.x
		and inner.position.y >= outer.position.y
		and inner.end.x <= outer.end.x
		and inner.end.y <= outer.end.y
	)


func _quit_with_code(exit_code: int) -> void:
	if _probe != null and is_instance_valid(_probe):
		_probe.queue_free()
	if _pso_probe != null and is_instance_valid(_pso_probe):
		_pso_probe.queue_free()
	for _frame in range(2):
		await process_frame
	quit(exit_code)
