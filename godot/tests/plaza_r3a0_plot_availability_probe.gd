extends SceneTree

# Offline authoring probe. This is intentionally not a *_smoke.gd nightly test:
# it renders rejected lattice candidates so topology/band edits can be chosen
# from the generator's real Geometry2D reasons instead of hand-tuned literals.

const PlazaAssetLoader := preload("res://scripts/plaza/plaza_asset_loader.gd")
const PlazaMapRoadSkeletonR3 := preload("res://scripts/plaza/plaza_map_road_skeleton_r3.gd")

const WORLD_SIZE := Vector2(2400.0, 1500.0)
const SPAWN_ANCHOR := Vector2(120.0, 666.0)
const EXIT_ZONE := Rect2(Vector2(2250.0, 596.0), Vector2(120.0, 92.0))
const OUTPUT_DIR := "res://.tmp/plaza_r3a0_plot_availability"
# Keep the two tightly packed south-east parcels visible in the authoring
# artifact so later topology edits cannot silently reintroduce the old
# market/spirit capacity deadlock.
const TARGET_PLOT_IDS := ["market_plot", "spirit_plot"]
const TARGET_SEED_BY_PLOT_ID := {"market_plot": 1, "spirit_plot": 1}
const IMAGE_SCALE := 0.5

var _failures: Array[String] = []


func _init() -> void:
	var absolute_output := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(absolute_output) != OK:
		_failures.append("failed to create output directory")
	var rendered := {}
	var metrics := {
		"world_size": WORLD_SIZE,
		"image_scale": IMAGE_SCALE,
		"cases": [],
		"post_resolution_skips": [],
		"legend": {
			"central_plaza": "7f3fbf",
			"committed_plot_outline": "ff477e",
			"committed_route_corridor": "ff9b3d",
			"committed_route_centerline": "53f0ff",
			"plot_overlap": "d94b4b",
			"committed_route": "e38b2c",
			"main_road": "3987d6",
			"route": "d6ca39",
			"outside": "777777",
			"other": "eeeeee",
		},
	}
	var target_seeds: Array[int] = []
	for target_seed_value in TARGET_SEED_BY_PLOT_ID.values():
		var target_seed := int(target_seed_value)
		if not target_seeds.has(target_seed):
			target_seeds.append(target_seed)
	target_seeds.sort()
	for map_seed in target_seeds:
		var roster := PlazaAssetLoader.build_hwangyeok_building_specs(1, map_seed, false, false)
		var layout := PlazaMapRoadSkeletonR3.generate(1, map_seed, WORLD_SIZE, roster, SPAWN_ANCHOR, EXIT_ZONE, true)
		var validation := layout.get("validation", {}) as Dictionary
		var records := _dictionary_array(layout.get("plot_availability_debug", []))
		var availability_context := layout.get("plot_availability_context", {}) as Dictionary
		if not bool(validation.get("valid", false)) and records.is_empty():
			(metrics["post_resolution_skips"] as Array).append({
				"seed": map_seed,
				"reason": str(layout.get("rejection_reason", "post_resolution_validation_failed")),
				"validation_failure_count": _dictionary_array(validation.get("violations", [])).size(),
			})
			continue
		for plot_id in TARGET_PLOT_IDS:
			if map_seed != int(TARGET_SEED_BY_PLOT_ID.get(plot_id, -1)):
				continue
			var target_records: Array[Dictionary] = []
			for record in records:
				if str(record.get("plot_id", "")) == plot_id:
					target_records.append(record)
			if target_records.is_empty():
				var record_counts_by_plot := {}
				var dominant_counts := {}
				for debug_record in records:
					var debug_plot_id := str(debug_record.get("plot_id", ""))
					record_counts_by_plot[debug_plot_id] = int(record_counts_by_plot.get(debug_plot_id, 0)) + 1
					var dominant := str(debug_record.get("dominant_rejection", ""))
					dominant_counts[dominant] = int(dominant_counts.get(dominant, 0)) + 1
				(metrics["post_resolution_skips"] as Array).append({
					"seed": map_seed,
					"reason": "target_record_missing",
					"validation": validation.duplicate(true),
					"record_counts_by_plot": record_counts_by_plot,
					"dominant_rejection_counts": dominant_counts,
					"last_record": records[records.size() - 1].duplicate(true) if not records.is_empty() else {},
				})
				_failures.append(
					"seed %d has no availability records for %s: valid=%s debug_count=%d plots=%s dominant=%s"
					% [
						map_seed,
						plot_id,
						str(validation.get("valid", false)),
						records.size(),
						str(record_counts_by_plot),
						str(dominant_counts),
					]
				)
				continue
			var case_metrics := _render_case(
				map_seed,
				plot_id,
				target_records,
				availability_context,
				absolute_output
			)
			case_metrics["layout_valid"] = bool(validation.get("valid", false))
			case_metrics["layout_validation"] = validation.duplicate(true)
			case_metrics["road_crossing_bindings"] = _dictionary_array(layout.get("road_crossing_bindings", [])).duplicate(true)
			case_metrics["layout_rejection_reason"] = str(layout.get("rejection_reason", ""))
			(metrics["cases"] as Array).append(case_metrics)
			rendered[plot_id] = true
	var unrendered_targets: Array[String] = []
	for plot_id in TARGET_PLOT_IDS:
		if not rendered.has(plot_id):
			unrendered_targets.append(plot_id)
			_failures.append("target availability case was not rendered: %s" % plot_id)
	metrics["unrendered_target_plot_ids"] = unrendered_targets
	metrics["pass"] = _failures.is_empty()
	metrics["failures"] = _failures.duplicate()
	var metrics_file := FileAccess.open("%s/metrics.json" % OUTPUT_DIR, FileAccess.WRITE)
	if metrics_file == null:
		_failures.append("failed to open metrics.json")
	else:
		metrics_file.store_string(JSON.stringify(metrics, "\t"))
		metrics_file.flush()
		metrics_file.close()
	if _failures.is_empty():
		print("plaza_r3a0_plot_availability_probe: ok cases=%s" % [rendered.keys()])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _render_case(
	map_seed: int,
	plot_id: String,
	records: Array[Dictionary],
	availability_context: Dictionary,
	absolute_output: String
) -> Dictionary:
	var image := Image.create(
		roundi(WORLD_SIZE.x * IMAGE_SCALE),
		roundi(WORLD_SIZE.y * IMAGE_SCALE),
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(Color("111318"))
	var plot_class_id := str(records[0].get("plot_class", "")) if not records.is_empty() else ""
	var band_value: Variant = PlazaMapRoadSkeletonR3.R3_PLOT_SITE_BAND_BY_CLASS.get(plot_class_id, Rect2())
	if band_value is Rect2:
		_draw_rect_outline(image, _scaled_rect(band_value as Rect2), Color("64e6db"))
	var exclusion := PlazaMapRoadSkeletonR3.CENTRAL_PLAZA_EXCLUSION_POLYGON_WORLD
	for index in range(exclusion.size()):
		_draw_line(
			image,
			_scaled_point(exclusion[index]),
			_scaled_point(exclusion[(index + 1) % exclusion.size()]),
			Color("bc72e8")
		)
	_draw_availability_context(image, availability_context)
	var reason_counts := {}
	var candidate_summaries: Array[Dictionary] = []
	for record in records:
		var reason := str(record.get("dominant_rejection", "other"))
		reason_counts[reason] = int(reason_counts.get(reason, 0)) + 1
		var pivot_value: Variant = record.get("pivot", null)
		if not (pivot_value is Vector2):
			continue
		candidate_summaries.append({
			"pivot_world": pivot_value,
			"reason": reason,
			"accepted": bool(record.get("accepted", false)),
			"branch_port": record.get("branch_port", Vector2.INF),
			"destination": record.get("destination", Vector2.INF),
			"pre_destination": record.get("pre_destination", Vector2.INF),
			"route_rejections": (record.get("route_rejections", {}) as Dictionary).duplicate(true),
		})
		var center := _scaled_point(pivot_value as Vector2)
		image.fill_rect(Rect2i(center - Vector2i(3, 3), Vector2i(7, 7)), _reason_color(reason))
	var filename := "%s_seed_%02d.png" % [plot_id, map_seed]
	var save_error := image.save_png("%s/%s" % [absolute_output, filename])
	if save_error != OK:
		_failures.append("failed to save %s: %d" % [filename, save_error])
	var route_summaries := _summarize_committed_routes(availability_context)
	var plot_summaries := _summarize_committed_plots(availability_context)
	var left_access_route := {}
	for route_summary in route_summaries:
		if str(route_summary.get("plot_id", "")) == "left_access":
			left_access_route = route_summary.duplicate(true)
			break
	return {
		"seed": map_seed,
		"plot_id": plot_id,
		"plot_class": plot_class_id,
		"candidate_count": records.size(),
		"dominant_rejection_counts": reason_counts,
		"candidate_records": candidate_summaries,
		"committed_plot_count": _dictionary_array(availability_context.get("committed_plots", [])).size(),
		"committed_plots": plot_summaries,
		"committed_route_count": route_summaries.size(),
		"committed_routes": route_summaries,
		"left_access_route": left_access_route,
		"png": filename,
	}


func _summarize_committed_plots(context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for plot in _dictionary_array(context.get("committed_plots", [])):
		var boundary := _vector2_array(plot.get("boundary_polygon_world", []))
		var bounds := Rect2()
		if not boundary.is_empty():
			var minimum := boundary[0]
			var maximum := boundary[0]
			for point in boundary:
				minimum = minimum.min(point)
				maximum = maximum.max(point)
			bounds = Rect2(minimum, maximum - minimum)
		result.append({
			"plot_id": str(plot.get("id", "")),
			"plot_class": str(plot.get("plot_class", "")),
			"pivot_world": plot.get("pivot_pos", Vector2.INF),
			"boundary_min_x": bounds.position.x,
			"boundary_min_y": bounds.position.y,
			"boundary_max_x": bounds.end.x,
			"boundary_max_y": bounds.end.y,
		})
	return result


func _draw_availability_context(image: Image, context: Dictionary) -> void:
	for plot in _dictionary_array(context.get("committed_plots", [])):
		_draw_polygon_outline(
			image,
			_vector2_array(plot.get("boundary_polygon_world", [])),
			Color("ff477e"),
			2
		)
	for blocker in _dictionary_array(context.get("committed_route_blockers", [])):
		_draw_polygon_outline(
			image,
			_vector2_array(blocker.get("polygon_world", [])),
			Color("ff9b3d"),
			2
		)
	for route_plan in _dictionary_array(context.get("committed_route_plans", [])):
		var polyline: Array[Vector2] = _vector2_array(route_plan.get("full_polyline_world", []))
		for index in range(polyline.size() - 1):
			_draw_thick_line(
				image,
				_scaled_point(polyline[index]),
				_scaled_point(polyline[index + 1]),
				Color("53f0ff"),
				2
			)


func _summarize_committed_routes(context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for route_plan in _dictionary_array(context.get("committed_route_plans", [])):
		var polyline: Array[Vector2] = _vector2_array(route_plan.get("full_polyline_world", []))
		var segment_records: Array[Dictionary] = []
		for segment_index in range(polyline.size() - 1):
			var start: Vector2 = polyline[segment_index]
			var finish: Vector2 = polyline[segment_index + 1]
			segment_records.append({
				"segment_index": segment_index,
				"start_world": start,
				"finish_world": finish,
				"min_x": minf(start.x, finish.x),
				"min_y": minf(start.y, finish.y),
				"max_x": maxf(start.x, finish.x),
				"max_y": maxf(start.y, finish.y),
				"length_world": start.distance_to(finish),
			})
		result.append({
			"plot_id": str(route_plan.get("plot_id", "")),
			"edge_id": str(route_plan.get("edge_id", "")),
			"branch_port": route_plan.get("branch_port", Vector2.INF),
			"destination": route_plan.get("destination", Vector2.INF),
			"pre_destination": route_plan.get("pre_destination", Vector2.INF),
			"half_width": float(route_plan.get("half_width", 0.0)),
			"full_polyline_world": polyline,
			"segments": segment_records,
		})
	return result


func _draw_polygon_outline(image: Image, polygon: Array[Vector2], color: Color, radius: int) -> void:
	if polygon.size() < 2:
		return
	for index in range(polygon.size()):
		_draw_thick_line(
			image,
			_scaled_point(polygon[index]),
			_scaled_point(polygon[(index + 1) % polygon.size()]),
			color,
			radius
		)


func _draw_thick_line(
	image: Image,
	start: Vector2i,
	finish: Vector2i,
	color: Color,
	radius: int
) -> void:
	var delta := finish - start
	var steps := maxi(absi(delta.x), absi(delta.y))
	var image_rect := Rect2i(Vector2i.ZERO, image.get_size())
	for step in range(steps + 1):
		var progress := 0.0 if steps <= 0 else float(step) / float(steps)
		var point := Vector2i(Vector2(start).lerp(Vector2(finish), progress).round())
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				var sample := point + Vector2i(offset_x, offset_y)
				if image_rect.has_point(sample):
					image.set_pixelv(sample, color)


func _reason_color(reason: String) -> Color:
	if reason.begins_with("central_plaza"):
		return Color("7f3fbf")
	if reason.begins_with("plot_overlap"):
		return Color("d94b4b")
	if reason.begins_with("committed_route_overlap"):
		return Color("e38b2c")
	if reason.begins_with("main_road_overlap"):
		return Color("3987d6")
	if reason.begins_with("route:"):
		return Color("d6ca39")
	if reason.contains("outside"):
		return Color("777777")
	return Color("eeeeee")


func _scaled_point(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x * IMAGE_SCALE), roundi(point.y * IMAGE_SCALE))


func _scaled_rect(rect: Rect2) -> Rect2i:
	return Rect2i(_scaled_point(rect.position), _scaled_point(rect.size))


func _draw_rect_outline(image: Image, rect: Rect2i, color: Color) -> void:
	_draw_line(image, rect.position, Vector2i(rect.end.x, rect.position.y), color)
	_draw_line(image, Vector2i(rect.end.x, rect.position.y), rect.end, color)
	_draw_line(image, rect.end, Vector2i(rect.position.x, rect.end.y), color)
	_draw_line(image, Vector2i(rect.position.x, rect.end.y), rect.position, color)


func _draw_line(image: Image, start: Vector2i, finish: Vector2i, color: Color) -> void:
	var delta := finish - start
	var steps := maxi(absi(delta.x), absi(delta.y))
	if steps <= 0:
		if Rect2i(Vector2i.ZERO, image.get_size()).has_point(start):
			image.set_pixelv(start, color)
		return
	for step in range(steps + 1):
		var point := Vector2i(Vector2(start).lerp(Vector2(finish), float(step) / float(steps)).round())
		if Rect2i(Vector2i.ZERO, image.get_size()).has_point(point):
			image.set_pixelv(point, color)


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value as Array:
			if item is Dictionary:
				result.append(item as Dictionary)
	return result


func _vector2_array(value: Variant) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if value is Array:
		for item in value as Array:
			if item is Vector2:
				result.append(item as Vector2)
	return result
