extends SceneTree

# R2 environment art is a self-contained runtime candidate, but remains
# disconnected from PlazaScene until the atomic R3 activation.

const MANIFEST_PATH := "res://assets/ui/plaza/environment/hwangyeok_r2/plaza_hwangyeok_r2_environment_manifest.json"
const ASSET_ROOT := "res://assets/ui/plaza/environment/hwangyeok_r2/"
const EXPECTED_GROUND_IDS := ["map_ground"]
const EXPECTED_ROAD_IDS := [
	"entrance_forecourt",
	"plot_spur",
	"straight_negative",
	"straight_positive",
	"terminus",
	"three_way",
]
const EXPECTED_PLOT_PAD_IDS := ["plot_pad_large", "plot_pad_small"]
const EXPECTED_DECOR_IDS := ["market", "pine", "pond", "supply", "wayfinder"]
const REQUIRED_IMPORT_PARAM_LINES := [
	"compress/uastc_level=0",
	"compress/rdo_quality_loss=0.0",
	"process/channel_remap/red=0",
	"process/channel_remap/green=1",
	"process/channel_remap/blue=2",
	"process/channel_remap/alpha=3",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := _load_manifest()
	if manifest.is_empty():
		_finish()
		return

	_verify_manifest(manifest)
	_verify_runtime_assets(manifest)
	_verify_aggregate_sha(manifest)
	_verify_fail_closed_counterproofs(manifest)
	_verify_candidate_isolation()
	_finish()


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_failures.append("R2 environment manifest is missing")
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_failures.append("R2 environment manifest cannot be opened")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_failures.append("R2 environment manifest must parse as a dictionary")
		return {}
	return parsed as Dictionary


func _verify_manifest(manifest: Dictionary) -> void:
	var errors := _validate_manifest_contract(manifest)
	for error_text in errors:
		_failures.append("baseline manifest: %s" % error_text)

	var qa_value: Variant = manifest.get("qa", {})
	var qa: Dictionary = qa_value as Dictionary if qa_value is Dictionary else {}
	_expect(str(qa.get("status", "")) == "pass", "environment prep QA status must be pass")
	_expect(int(qa.get("failure_count", -1)) == 0, "environment prep QA failure_count must be zero")
	_expect(int(qa.get("runtime_png_count", -1)) == 14, "environment prep must publish exactly 14 runtime PNGs")
	_expect(int(qa.get("road_component_count", -1)) == 6, "environment prep must publish exactly six road components")
	_expect(int(qa.get("plot_pad_component_count", -1)) == 2, "environment prep must publish exactly two plot-pad components")

	var geometry_value: Variant = qa.get("road_geometry_contract", {})
	var geometry: Dictionary = geometry_value as Dictionary if geometry_value is Dictionary else {}
	_expect(geometry.get("basis_slopes", []) == [0.5, -0.5], "road geometry contract must retain exact +0.5/-0.5 basis slopes")
	_expect(int(geometry.get("elevation_degrees", -1)) == 30, "road geometry contract must retain 30 degree elevation")
	_expect(int(geometry.get("azimuth_degrees", -1)) == 45, "road geometry contract must retain 45 degree azimuth")
	var metrics_value: Variant = qa.get("road_geometry_metrics", [])
	var metrics: Array = metrics_value as Array if metrics_value is Array else []
	_expect(metrics.size() == 6, "road geometry QA must contain exactly six component records")
	for metric_value in metrics:
		if not (metric_value is Dictionary):
			_failures.append("road geometry metric must be a dictionary")
			continue
		var metric := metric_value as Dictionary
		_expect(float(metric.get("iou", 0.0)) >= 0.94, "road geometry IoU must remain >= 0.94")
		_expect(float(metric.get("guide_coverage", 0.0)) >= 0.985, "road guide coverage must remain >= 0.985")
		_expect(float(metric.get("art_spill_ratio", 1.0)) <= 0.05, "road art spill must remain <= 0.05")

	var plot_pad_geometry_value: Variant = qa.get("plot_pad_geometry_contract", {})
	var plot_pad_geometry: Dictionary = plot_pad_geometry_value as Dictionary if plot_pad_geometry_value is Dictionary else {}
	_expect(plot_pad_geometry.get("basis_slopes", []) == [0.5, -0.5], "plot-pad geometry contract must retain exact +0.5/-0.5 basis slopes")
	_expect(float(plot_pad_geometry.get("minimum_mean_luminance_8bit", -1.0)) == 75.0, "plot-pad luminance floor must remain 75")
	_expect(float(plot_pad_geometry.get("maximum_mean_luminance_8bit", -1.0)) == 90.0, "plot-pad luminance ceiling must remain 90")
	var plot_pad_metrics_value: Variant = qa.get("plot_pad_geometry_metrics", [])
	var plot_pad_metrics: Array = plot_pad_metrics_value as Array if plot_pad_metrics_value is Array else []
	_expect(plot_pad_metrics.size() == 2, "plot-pad geometry QA must contain exactly two component records")
	for metric_value in plot_pad_metrics:
		if not (metric_value is Dictionary):
			_failures.append("plot-pad geometry metric must be a dictionary")
			continue
		var metric := metric_value as Dictionary
		_expect(float(metric.get("iou", 0.0)) >= 0.96, "plot-pad geometry IoU must remain >= 0.96")
		_expect(float(metric.get("guide_coverage", 0.0)) >= 0.98, "plot-pad guide coverage must remain >= 0.98")
		_expect(float(metric.get("art_spill_ratio", 1.0)) <= 0.02, "plot-pad art spill must remain <= 0.02")
		var luminance := float(metric.get("mean_luminance_8bit", -1.0))
		_expect(luminance >= 75.0 and luminance <= 90.0, "plot-pad mean luminance must remain within 75..90")


func _validate_manifest_contract(manifest: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(manifest.get("schema_version", -1)) != 1:
		errors.append("schema_version")
	if str(manifest.get("status", "")) != "r2_candidate_runtime_art_ready":
		errors.append("status")
	if str(manifest.get("runtime_usage", "")) != "candidate_only_hwangyeok_plaza_2d_ground_road_plot_pad_and_decor":
		errors.append("runtime_usage")
	if not bool(manifest.get("candidate_only", false)):
		errors.append("candidate_only")
	if bool(manifest.get("production_connected", true)):
		errors.append("production_connected")

	var retention_value: Variant = manifest.get("source_retention_policy", {})
	var retention: Dictionary = retention_value as Dictionary if retention_value is Dictionary else {}
	if not bool(retention.get("runtime_outputs_self_contained", false)):
		errors.append("runtime_outputs_self_contained")
	if bool(retention.get("clean_checkout_rebuild_supported", true)):
		errors.append("clean_checkout_rebuild_supported")

	var assets_value: Variant = manifest.get("assets", [])
	if not (assets_value is Array):
		errors.append("assets_type")
		return errors
	var assets := assets_value as Array
	if assets.size() != 14:
		errors.append("asset_count")
	var ids_by_kind := {
		"ground": [],
		"road_piece": [],
		"plot_pad": [],
		"decor_cluster": [],
	}
	var seen_ids: Dictionary = {}
	var seen_paths: Dictionary = {}
	for asset_value in assets:
		if not (asset_value is Dictionary):
			errors.append("asset_item_type")
			continue
		var asset := asset_value as Dictionary
		var kind := str(asset.get("kind", ""))
		var asset_id := str(asset.get("asset_id", ""))
		var res_path := str(asset.get("res_path", ""))
		if not ids_by_kind.has(kind):
			errors.append("asset_kind:%s" % kind)
		else:
			(ids_by_kind[kind] as Array).append(asset_id)
		if asset_id.is_empty() or seen_ids.has(asset_id):
			errors.append("asset_id_unique:%s" % asset_id)
		seen_ids[asset_id] = true
		if not res_path.begins_with(ASSET_ROOT) or not res_path.ends_with(".png") or res_path.contains("tmp/imagegen"):
			errors.append("res_path:%s" % res_path)
		if seen_paths.has(res_path):
			errors.append("res_path_unique:%s" % res_path)
		seen_paths[res_path] = true

	for kind in ids_by_kind:
		(ids_by_kind[kind] as Array).sort()
	if ids_by_kind["ground"] != EXPECTED_GROUND_IDS:
		errors.append("ground_ids")
	if ids_by_kind["road_piece"] != EXPECTED_ROAD_IDS:
		errors.append("road_ids")
	if ids_by_kind["plot_pad"] != EXPECTED_PLOT_PAD_IDS:
		errors.append("plot_pad_ids")
	if ids_by_kind["decor_cluster"] != EXPECTED_DECOR_IDS:
		errors.append("decor_ids")
	return errors


func _verify_runtime_assets(manifest: Dictionary) -> void:
	var assets := manifest.get("assets", []) as Array
	for asset_value in assets:
		if not (asset_value is Dictionary):
			continue
		var asset := asset_value as Dictionary
		var asset_id := str(asset.get("asset_id", ""))
		var kind := str(asset.get("kind", ""))
		var res_path := str(asset.get("res_path", ""))
		var absolute_path := ProjectSettings.globalize_path(res_path)
		_expect(FileAccess.file_exists(res_path), "%s runtime PNG must exist" % asset_id)
		if not FileAccess.file_exists(res_path):
			continue

		var qa_value: Variant = asset.get("qa", {})
		var qa: Dictionary = qa_value as Dictionary if qa_value is Dictionary else {}
		_expect(FileAccess.get_sha256(absolute_path) == str(qa.get("sha256", "")), "%s runtime PNG SHA must match the manifest" % asset_id)

		var image := Image.new()
		var load_error := image.load(absolute_path)
		_expect(load_error == OK and not image.is_empty(), "%s runtime PNG must decode" % asset_id)
		if load_error != OK or image.is_empty():
			continue
		image.convert(Image.FORMAT_RGBA8)
		var expected_size := Vector2i(1536, 1024) if kind == "ground" else Vector2i(512, 512)
		_expect(Vector2i(image.get_width(), image.get_height()) == expected_size, "%s runtime canvas must be %s" % [asset_id, expected_size])
		if kind == "ground":
			_expect(image.detect_alpha() == Image.ALPHA_NONE, "map ground must remain fully opaque")
		else:
			_expect(image.get_used_rect().has_area(), "%s runtime cutout must have visible pixels" % asset_id)
			for corner in [Vector2i.ZERO, Vector2i(image.get_width() - 1, 0), Vector2i(0, image.get_height() - 1), Vector2i(image.get_width() - 1, image.get_height() - 1)]:
				_expect(image.get_pixelv(corner).a <= 0.001, "%s runtime cutout corners must remain transparent" % asset_id)

		var texture_value: Variant = ResourceLoader.load(res_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
		_expect(texture_value is Texture2D, "%s must import as Texture2D" % asset_id)
		if texture_value is Texture2D:
			var texture := texture_value as Texture2D
			_expect(texture.get_width() == expected_size.x and texture.get_height() == expected_size.y, "%s imported Texture2D size must match the runtime PNG" % asset_id)

		var import_value: Variant = asset.get("import", {})
		var import_record: Dictionary = import_value as Dictionary if import_value is Dictionary else {}
		_expect(str(import_record.get("status", "")) == "ready", "%s VRAM import status must be ready" % asset_id)
		_expect(bool(import_record.get("vram_texture", false)), "%s must use VRAM texture import" % asset_id)
		_expect(int(import_record.get("compress_mode", -1)) == 2, "%s must use VRAM compression mode 2" % asset_id)
		_expect(bool(import_record.get("high_quality", false)), "%s must use high-quality VRAM compression" % asset_id)
		_expect(bool(import_record.get("mipmaps", false)), "%s must generate mipmaps" % asset_id)
		var import_path := "%s.import" % absolute_path
		_expect(FileAccess.file_exists(import_path), "%s .png.import sidecar must exist" % asset_id)
		if FileAccess.file_exists(import_path):
			var import_text := FileAccess.get_file_as_string(import_path)
			_expect(import_text.contains("compress/mode=2"), "%s import sidecar must retain mode=2" % asset_id)
			_expect(import_text.contains("compress/high_quality=true"), "%s import sidecar must retain high quality" % asset_id)
			_expect(import_text.contains("mipmaps/generate=true"), "%s import sidecar must retain mipmaps" % asset_id)
			_expect(import_text.contains('"vram_texture": true'), "%s import sidecar must identify a VRAM texture" % asset_id)
			for required_line in REQUIRED_IMPORT_PARAM_LINES:
				_expect(import_text.contains(required_line), "%s import sidecar must retain Godot 4.6 canonical param %s" % [asset_id, required_line])


func _verify_aggregate_sha(manifest: Dictionary) -> void:
	var assets := manifest.get("assets", []) as Array
	var paths: Array[String] = []
	for asset_value in assets:
		if asset_value is Dictionary:
			paths.append(str((asset_value as Dictionary).get("res_path", "")))
	paths.sort()
	var hashing := HashingContext.new()
	_expect(hashing.start(HashingContext.HASH_SHA256) == OK, "aggregate SHA context must start")
	for res_path in paths:
		var absolute_path := ProjectSettings.globalize_path(res_path)
		hashing.update(res_path.get_file().to_utf8_buffer())
		hashing.update(PackedByteArray([0]))
		hashing.update(FileAccess.get_sha256(absolute_path).hex_decode())
	var actual_aggregate := hashing.finish().hex_encode()
	var qa_value: Variant = manifest.get("qa", {})
	var qa: Dictionary = qa_value as Dictionary if qa_value is Dictionary else {}
	_expect(actual_aggregate == str(qa.get("aggregate_runtime_sha256", "")), "aggregate runtime PNG SHA must match the deterministic prep result")


func _verify_fail_closed_counterproofs(manifest: Dictionary) -> void:
	var production_mutation := manifest.duplicate(true)
	production_mutation["production_connected"] = true
	_expect(_validate_manifest_contract(production_mutation).has("production_connected"), "production-connected mutation must be RED")

	var missing_road := manifest.duplicate(true)
	var missing_assets := missing_road.get("assets", []) as Array
	for index in range(missing_assets.size() - 1, -1, -1):
		var asset_value: Variant = missing_assets[index]
		if asset_value is Dictionary and str((asset_value as Dictionary).get("asset_id", "")) == "three_way":
			missing_assets.remove_at(index)
			break
	_expect(_validate_manifest_contract(missing_road).has("asset_count"), "missing road-piece mutation must be RED")

	var missing_plot_pad := manifest.duplicate(true)
	var missing_plot_pad_assets := missing_plot_pad.get("assets", []) as Array
	for index in range(missing_plot_pad_assets.size() - 1, -1, -1):
		var asset_value: Variant = missing_plot_pad_assets[index]
		if asset_value is Dictionary and str((asset_value as Dictionary).get("kind", "")) == "plot_pad":
			missing_plot_pad_assets.remove_at(index)
			break
	var missing_plot_pad_errors := _validate_manifest_contract(missing_plot_pad)
	_expect(missing_plot_pad_errors.has("asset_count") and missing_plot_pad_errors.has("plot_pad_ids"), "missing plot-pad mutation must be RED")

	var duplicate_id := manifest.duplicate(true)
	var duplicate_assets := duplicate_id.get("assets", []) as Array
	if duplicate_assets.size() >= 2 and duplicate_assets[0] is Dictionary and duplicate_assets[1] is Dictionary:
		(duplicate_assets[1] as Dictionary)["asset_id"] = str((duplicate_assets[0] as Dictionary).get("asset_id", ""))
	var duplicate_errors := _validate_manifest_contract(duplicate_id)
	var duplicate_red := false
	for error_text in duplicate_errors:
		if error_text.begins_with("asset_id_unique:"):
			duplicate_red = true
	_expect(duplicate_red, "duplicate asset-id mutation must be RED")

	var slope_mutation := manifest.duplicate(true)
	var qa_value: Variant = slope_mutation.get("qa", {})
	if qa_value is Dictionary:
		var geometry_value: Variant = (qa_value as Dictionary).get("road_geometry_contract", {})
		if geometry_value is Dictionary:
			(geometry_value as Dictionary)["basis_slopes"] = [0.8, -0.8]
	var geometry_after_value: Variant = (slope_mutation.get("qa", {}) as Dictionary).get("road_geometry_contract", {})
	var geometry_after: Dictionary = geometry_after_value as Dictionary if geometry_after_value is Dictionary else {}
	_expect(geometry_after.get("basis_slopes", []) != [0.5, -0.5], "slope mutation fixture must alter the authoritative basis")
	_expect(not _has_valid_geometry_contract(slope_mutation), "non-30-degree road slope mutation must be RED")

	var dark_plot_pad := manifest.duplicate(true)
	var dark_qa_value: Variant = dark_plot_pad.get("qa", {})
	if dark_qa_value is Dictionary:
		var dark_metrics_value: Variant = (dark_qa_value as Dictionary).get("plot_pad_geometry_metrics", [])
		if dark_metrics_value is Array and not (dark_metrics_value as Array).is_empty() and (dark_metrics_value as Array)[0] is Dictionary:
			((dark_metrics_value as Array)[0] as Dictionary)["mean_luminance_8bit"] = 6.7
	_expect(not _has_valid_plot_pad_contract(dark_plot_pad), "dark-earth plot-pad luminance mutation must be RED")


func _has_valid_geometry_contract(manifest: Dictionary) -> bool:
	var qa_value: Variant = manifest.get("qa", {})
	if not (qa_value is Dictionary):
		return false
	var geometry_value: Variant = (qa_value as Dictionary).get("road_geometry_contract", {})
	if not (geometry_value is Dictionary):
		return false
	var geometry := geometry_value as Dictionary
	return geometry.get("basis_slopes", []) == [0.5, -0.5] \
		and int(geometry.get("elevation_degrees", -1)) == 30 \
		and int(geometry.get("azimuth_degrees", -1)) == 45


func _has_valid_plot_pad_contract(manifest: Dictionary) -> bool:
	var qa_value: Variant = manifest.get("qa", {})
	if not (qa_value is Dictionary):
		return false
	var metrics_value: Variant = (qa_value as Dictionary).get("plot_pad_geometry_metrics", [])
	if not (metrics_value is Array) or (metrics_value as Array).size() != 2:
		return false
	for metric_value in metrics_value as Array:
		if not (metric_value is Dictionary):
			return false
		var luminance := float((metric_value as Dictionary).get("mean_luminance_8bit", -1.0))
		if luminance < 75.0 or luminance > 90.0:
			return false
	return true


func _verify_candidate_isolation() -> void:
	for source_path in ["res://scripts/plaza/plaza_scene.gd", "res://project.godot"]:
		var text := FileAccess.get_file_as_string(source_path)
		_expect(not text.contains("plaza_hwangyeok_r2_environment"), "%s must not route the R2 environment candidate" % source_path)
		_expect(not text.contains("environment/hwangyeok_r2"), "%s must not reference candidate environment assets" % source_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("plaza_r2_environment_art_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error("plaza_r2_environment_art_smoke: %s" % failure)
	quit(1)
