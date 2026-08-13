extends SceneTree

# Windowed-only R2-C guardian Y-sort seal. With the PLAYER parked far from the
# probe ROI, D and E cross the authored bank sort anchor with the GUARDIAN
# sibling while every direct sibling stays z=0. F restores the D world position
# but mutates the actual guardian CanvasItem to z=1; its pixel result must match
# guardian-front E and the live tree contract must turn RED.

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapLayoutGenerator := preload("res://scripts/plaza/plaza_map_layout_generator.gd")
const PlazaMapProjection := preload("res://scripts/plaza/plaza_map_projection.gd")
const PlazaR2MapWorldCandidateHost := preload("res://scripts/plaza/plaza_r2_map_world_candidate_host.gd")

const VIEW_SIZE := Vector2i(2020, 1246)
const WORLD_SIZE := Vector2(2400.0, 1500.0)
const SPAWN_ANCHOR := Vector2(120.0, 666.0)
const EXIT_ZONE := Rect2(2250.0, 596.0, 120.0, 92.0)
const SAFE_INSETS := {
	"left": 72.0,
	"top": 72.0,
	"right": 360.0,
	"bottom": 120.0,
}
const OUTPUT_DIR := "res://.tmp/plaza_r2c_guardian_ysort"
const ENGINE_LOG_PATH := "res://.godot/codex_logs/plaza_r2c_guardian_ysort.engine.log"
const ACTOR_COLOR := Color(0.05, 0.92, 1.0, 1.0)
const GUARDIAN_COLOR := Color(0.72, 0.50, 1.0, 1.0)
const PROBE_COLOR := Color(1.0, 0.12, 0.04, 1.0)
const SAMPLE_HALF_SIZE := 6
const MIN_SENTINEL_PIXELS := 90
const MIN_CHANGED_PIXELS := 90

var _failures: Array[String] = []
var _host: Control = null
var _layout: Dictionary = {}
var _bank: Dictionary = {}
var _bank_anchor := Vector2.ZERO
var _player_world := Vector2.ZERO
var _sample_roi := Rect2i()
var _captures: Array[Dictionary] = []
var _pixel_metrics: Dictionary = {}
var _window_metrics: Dictionary = {}
var _counterproof_contract: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("plaza_r2c_guardian_ysort_vulkan_qa: CANDIDATE-ONLY; production_connected=false")
	if not _prepare_output_directory():
		_finish()
		return
	if not await _require_windowed_vulkan():
		_write_report()
		_finish()
		return
	if not _build_candidate():
		_write_report()
		_finish()
		return

	var behind_world := _bank_anchor + Vector2(0.0, -14.0)
	var front_world := _bank_anchor + Vector2(0.0, 14.0)
	_expect(bool(_host.call("sync_state", _build_state(behind_world, 1000))), "D behind state must sync")
	_expect(bool((_host.call("get_sort_contract_status") as Dictionary).get("valid", false)), "D must start from a GREEN actual sort tree")
	await _settle_frames(3)
	var image_d := await _capture("d_guardian_behind")

	_expect(bool(_host.call("sync_state", _build_state(front_world, 1022))), "E front state must sync")
	_expect(bool((_host.call("get_sort_contract_status") as Dictionary).get("valid", false)), "E must retain the same GREEN z=0 sort tree")
	await _settle_frames(3)
	var image_e := await _capture("e_guardian_front")

	_expect(bool(_host.call("sync_state", _build_state(behind_world, 1044))), "F must reset to the exact D world position before mutation")
	var guardian := _host.call("get_guardian_sort_item_for_test") as Node2D
	_expect(guardian != null, "F must mutate the actual retained guardian node")
	if guardian != null:
		guardian.z_index = 1
	_counterproof_contract = _host.call("get_sort_contract_status") as Dictionary
	_expect(not bool(_counterproof_contract.get("valid", true)), "F actual guardian z=1 mutation must turn the structural contract RED")
	_expect(not bool(_counterproof_contract.get("all_direct_z_zero", true)), "F RED must come from the real direct sibling z value")
	_expect(bool(_counterproof_contract.get("sort_root_y_sort_enabled", false)), "F must leave the real Y-sort root enabled")
	await _settle_frames(3)
	var image_f := await _capture("f_guardian_z1_counterproof")

	if image_d != null and image_e != null and image_f != null:
		_verify_pixels(image_d, image_e, image_f)
	_expect(bool(_host.call("sync_state", _build_state(behind_world, 1066))), "valid owner sync must restore the F mutation left in place")
	_expect(bool((_host.call("get_sort_contract_status") as Dictionary).get("valid", false)), "valid sync cleanup must restore the actual z=0 tree")
	_verify_evidence_files()
	_verify_engine_log_proves_vulkan()
	_write_report()
	_finish()


func _require_windowed_vulkan() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	if display_name.contains("headless"):
		_failures.append("R2-C guardian Y-sort QA requires a windowed display server")
		return false
	var rendering_method := RenderingServer.get_current_rendering_method().to_lower()
	var driver_name := _get_user_arg_value("--plaza-r2c-rendering-driver=").to_lower()
	if rendering_method != "mobile":
		_failures.append("R2-C guardian Y-sort QA requires rendering method mobile, got %s" % rendering_method)
	if driver_name != "vulkan":
		_failures.append("R2-C guardian Y-sort QA requires --plaza-r2c-rendering-driver=vulkan after `--`, got '%s'" % driver_name)
	root.content_scale_size = VIEW_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = VIEW_SIZE
	await process_frame
	await process_frame
	_window_metrics = {
		"display_server": display_name,
		"rendering_method": rendering_method,
		"rendering_driver": driver_name,
		"video_adapter_api_version": RenderingServer.get_video_adapter_api_version(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"requested_size": [VIEW_SIZE.x, VIEW_SIZE.y],
		"live_window_size": [root.size.x, root.size.y],
		"engine_log_path": ProjectSettings.globalize_path(ENGINE_LOG_PATH),
	}
	_expect(root.size == VIEW_SIZE, "live window must be exact 2020 x 1246, got %s" % root.size)
	return _failures.is_empty()


func _build_candidate() -> bool:
	var specs := PlazaAssetLoader.build_hwangyeok_building_specs(1, 5, false, false)
	_layout = PlazaMapLayoutGenerator.generate(1, 5, WORLD_SIZE, specs, SPAWN_ANCHOR, EXIT_ZONE)
	_expect(bool((_layout.get("validation", {}) as Dictionary).get("valid", false)), "seed 5 layout must validate before window construction")
	_bank = _find_by_type(_layout.get("building_specs", []), "bank")
	_expect(not _bank.is_empty(), "seed 5 layout must include bank")
	if _bank.is_empty():
		return false
	_bank_anchor = _bank.get("sort_anchor_world", Vector2.ZERO) as Vector2
	# Park the player far outside the probe ROI so only the guardian crossing
	# can change the sampled overlap pixels.
	_player_world = Vector2(
		clampf(_bank_anchor.x - 420.0, 80.0, WORLD_SIZE.x - 80.0),
		clampf(_bank_anchor.y - 360.0, 80.0, WORLD_SIZE.y - 80.0)
	)
	_host = PlazaR2MapWorldCandidateHost.new()
	_host.name = "PlazaR2CGuardianYSortHost"
	_host.position = Vector2.ZERO
	root.add_child(_host)
	var reference_projection := PlazaMapProjection.build_snapshot(
		WORLD_SIZE,
		PlazaMapProjection.derive_safe_rect(Vector2(VIEW_SIZE), SAFE_INSETS),
		WORLD_SIZE * 0.5,
		1.0
	)
	var sample_point := PlazaMapProjection.world_to_screen(
		_bank_anchor + Vector2(0.0, -20.0),
		reference_projection
	)
	_sample_roi = Rect2i(
		Vector2i(roundi(sample_point.x) - SAMPLE_HALF_SIZE, roundi(sample_point.y) - SAMPLE_HALF_SIZE),
		Vector2i(SAMPLE_HALF_SIZE * 2 + 1, SAMPLE_HALF_SIZE * 2 + 1)
	)
	_expect(_sample_roi.position.x >= 0 and _sample_roi.position.y >= 0 and _sample_roi.end.x <= VIEW_SIZE.x and _sample_roi.end.y <= VIEW_SIZE.y, "shared overlap ROI must be in bounds")
	var player_screen := PlazaMapProjection.world_to_screen(_player_world, reference_projection)
	_expect(
		Vector2(_sample_roi.get_center()).distance_to(player_screen) > 220.0,
		"parked player must stay far from the guardian overlap ROI"
	)
	return _failures.is_empty()


func _build_state(guardian_world: Vector2, ticks_msec: int) -> Dictionary:
	return {
		"render_size": Vector2(VIEW_SIZE),
		"safe_insets": SAFE_INSETS,
		"layout": _layout,
		"player_world_pos": _player_world,
		"camera_center_world": WORLD_SIZE * 0.5,
		"camera_zoom": 1.0,
		"ticks_msec": ticks_msec,
		"actor_rect_relative_world": Rect2(-55.0, -130.0, 110.0, 150.0),
		"actor_color": ACTOR_COLOR,
		"guardian_world_pos": guardian_world,
		"guardian_rect_relative_world": Rect2(-55.0, -130.0, 110.0, 150.0),
		"guardian_color": GUARDIAN_COLOR,
		"ysort_probe": {
			"building_type": "bank",
			"rect_relative_world": Rect2(-90.0, -100.0, 180.0, 140.0),
			"color": PROBE_COLOR,
		},
	}


func _verify_pixels(image_d: Image, image_e: Image, image_f: Image) -> void:
	var d_probe := _count_probe_pixels(image_d, _sample_roi)
	var d_guardian := _count_guardian_pixels(image_d, _sample_roi)
	var e_probe := _count_probe_pixels(image_e, _sample_roi)
	var e_guardian := _count_guardian_pixels(image_e, _sample_roi)
	var f_probe := _count_probe_pixels(image_f, _sample_roi)
	var f_guardian := _count_guardian_pixels(image_f, _sample_roi)
	var de_changed := _count_changed_pixels(image_d, image_e, _sample_roi)
	var df_changed := _count_changed_pixels(image_d, image_f, _sample_roi)
	_pixel_metrics = {
		"sample_roi": [_sample_roi.position.x, _sample_roi.position.y, _sample_roi.size.x, _sample_roi.size.y],
		"roi_area": _sample_roi.get_area(),
		"d_guardian_behind": {"probe_pixels": d_probe, "guardian_pixels": d_guardian},
		"e_guardian_front": {"probe_pixels": e_probe, "guardian_pixels": e_guardian},
		"f_guardian_z1_counterproof": {"probe_pixels": f_probe, "guardian_pixels": f_guardian},
		"d_to_e_changed_pixels": de_changed,
		"d_to_f_changed_pixels": df_changed,
		"minimum_sentinel_pixels": MIN_SENTINEL_PIXELS,
		"minimum_changed_pixels": MIN_CHANGED_PIXELS,
	}
	_expect(d_probe >= MIN_SENTINEL_PIXELS, "D must visibly draw the bank-owned probe over the behind guardian, got %d probe pixels" % d_probe)
	_expect(d_guardian == 0, "D overlap ROI must contain zero guardian-front pixels, got %d" % d_guardian)
	_expect(e_guardian >= MIN_SENTINEL_PIXELS, "E must visibly draw the front guardian over the bank probe, got %d guardian pixels" % e_guardian)
	_expect(e_probe == 0, "E overlap ROI must contain zero probe-front pixels, got %d" % e_probe)
	_expect(f_guardian >= MIN_SENTINEL_PIXELS, "F z=1 mutation must force the behind-position guardian to the front, got %d guardian pixels" % f_guardian)
	_expect(f_probe == 0, "F overlap ROI must contain zero probe-front pixels after actual guardian z mutation, got %d" % f_probe)
	_expect(de_changed >= MIN_CHANGED_PIXELS, "D/E paired Y crossing must change the shared overlap ROI, got %d" % de_changed)
	_expect(df_changed >= MIN_CHANGED_PIXELS, "D/F actual-z counterproof must change the shared overlap ROI, got %d" % df_changed)


func _count_probe_pixels(image: Image, roi: Rect2i) -> int:
	var count := 0
	for y in range(roi.position.y, roi.end.y):
		for x in range(roi.position.x, roi.end.x):
			var pixel := image.get_pixel(x, y)
			if pixel.r >= 0.72 and pixel.g <= 0.36 and pixel.b <= 0.28:
				count += 1
	return count


func _count_guardian_pixels(image: Image, roi: Rect2i) -> int:
	var count := 0
	for y in range(roi.position.y, roi.end.y):
		for x in range(roi.position.x, roi.end.x):
			var pixel := image.get_pixel(x, y)
			if pixel.b >= 0.78 and pixel.r >= 0.52 and pixel.g <= 0.72:
				count += 1
	return count


func _count_changed_pixels(left: Image, right: Image, roi: Rect2i) -> int:
	var count := 0
	for y in range(roi.position.y, roi.end.y):
		for x in range(roi.position.x, roi.end.x):
			var a := left.get_pixel(x, y)
			var b := right.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) >= 0.20:
				count += 1
	return count


func _capture(slug: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("capture %s returned an empty window image" % slug)
		return null
	_expect(image.get_size() == VIEW_SIZE, "%s capture must be exact 2020 x 1246, got %s" % [slug, image.get_size()])
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(slug + ".png"))
	var save_error := image.save_png(output_path)
	_expect(save_error == OK, "capture %s must save successfully (error %d)" % [slug, save_error])
	if save_error == OK:
		_captures.append({
			"slug": slug,
			"path": output_path,
			"size": [image.get_width(), image.get_height()],
			"sha256": FileAccess.get_sha256(output_path),
		})
		print("plaza_r2c_guardian_ysort_vulkan_qa: evidence %s" % output_path)
	return image


func _settle_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		if _host != null:
			_host.queue_redraw()
		await RenderingServer.frame_post_draw


func _prepare_output_directory() -> bool:
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		_failures.append("failed to create output directory: %s (%d)" % [output_dir, mkdir_error])
		return false
	for filename in DirAccess.get_files_at(output_dir):
		var remove_error := DirAccess.remove_absolute(output_dir.path_join(str(filename)))
		if remove_error != OK:
			_failures.append("failed to remove stale evidence %s (%d)" % [filename, remove_error])
	return _failures.is_empty()


func _verify_evidence_files() -> void:
	_expect(_captures.size() == 3, "paired guardian Y-sort seal requires exact D/E/F captures")
	var expected := [
		"d_guardian_behind.png",
		"e_guardian_front.png",
		"f_guardian_z1_counterproof.png",
	]
	var actual: Array[String] = []
	for filename in DirAccess.get_files_at(ProjectSettings.globalize_path(OUTPUT_DIR)):
		if str(filename).get_extension().to_lower() == "png":
			actual.append(str(filename))
	actual.sort()
	_expect(actual == expected, "evidence directory must contain exact D/E/F PNGs, got %s" % [actual])


func _verify_engine_log_proves_vulkan() -> void:
	var engine_log := FileAccess.get_file_as_string(ENGINE_LOG_PATH)
	var has_vulkan_mobile_banner := engine_log.contains("Vulkan ") and engine_log.contains("Forward Mobile")
	_window_metrics["engine_log_has_vulkan_mobile_banner"] = has_vulkan_mobile_banner
	_expect(has_vulkan_mobile_banner, "engine log must contain the real Vulkan Forward Mobile startup banner")


func _write_report() -> void:
	var report := {
		"schema": "plaza_r2c_guardian_ysort_vulkan_qa_v1",
		"pass": _failures.is_empty(),
		"failure_count": _failures.size(),
		"failures": _failures,
		"candidate_only": true,
		"production_connected": false,
		"world_size": [WORLD_SIZE.x, WORLD_SIZE.y],
		"view_size": [VIEW_SIZE.x, VIEW_SIZE.y],
		"layout_fingerprint": str(_layout.get("fingerprint", "")),
		"bank_sort_anchor_world": [_bank_anchor.x, _bank_anchor.y],
		"player_world_parked": [_player_world.x, _player_world.y],
		"window": _window_metrics,
		"captures": _captures,
		"pixel_metrics": _pixel_metrics,
		"counterproof_actual_tree_contract": _counterproof_contract,
	}
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("metrics.json"))
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to open metrics report for writing: %s" % output_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("plaza_r2c_guardian_ysort_vulkan_qa: metrics %s" % output_path)


func _get_user_arg_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _find_by_type(value: Variant, building_type: String) -> Dictionary:
	if not (value is Array):
		return {}
	for item_value in value as Array:
		if item_value is Dictionary and str((item_value as Dictionary).get("type", "")) == building_type:
			return (item_value as Dictionary).duplicate(false)
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)


func _finish() -> void:
	if _host != null and is_instance_valid(_host):
		_host.call("clear_transient_canvas_items")
		_host.queue_free()
	if _failures.is_empty() and _captures.size() != 3:
		_failures.append("run ended before exact D/E/F captures completed")
		_write_report()
	if _failures.is_empty() and _pixel_metrics.is_empty():
		_failures.append("run ended before paired overlap pixel metrics completed")
		_write_report()
	if _failures.is_empty():
		print("plaza_r2c_guardian_ysort_vulkan_qa: ok")
		print("plaza_r2c_guardian_ysort_vulkan_qa: evidence=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
		print("plaza_r2c_guardian_ysort_vulkan_qa: candidate-only, production-connected=false")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
