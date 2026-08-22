extends RefCounted

const CLOUD_LAYER_COUNT := 3
const CLOUD_SAMPLE_COUNT := 48
const PRESENTATION_SEED_SALT := 0x434c4f5544
const PAPER_LIGHT := Color("f1dfb8")
const PAPER_DEEP := Color("d7bd88")
const INK := Color("30271f")


static func estimate_draw_calls(nodes_value: Variant) -> int:
	var floors: Dictionary = {}
	var nodes: Array = nodes_value if nodes_value is Array else []
	for node_variant in nodes:
		if node_variant is Dictionary:
			floors[int((node_variant as Dictionary).get(
				"segment_floor",
				(node_variant as Dictionary).get("floor", 0)
			))] = true
	return floors.size() * CLOUD_LAYER_COUNT


func build(
	nodes_value: Variant,
	world_rect: Rect2,
	map_seed: int,
	art_size: float
) -> Dictionary:
	var bounds_by_floor: Dictionary = {}
	var nodes: Array = nodes_value if nodes_value is Array else []
	for node_variant in nodes:
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var floor_number := int(node.get("segment_floor", node.get("floor", 0)))
		if floor_number <= 0:
			continue
		var position: Vector2 = node.get("world_position", Vector2.ZERO)
		var bounds: Vector2 = bounds_by_floor.get(
			floor_number,
			Vector2(position.y, position.y)
		)
		bounds.x = minf(bounds.x, position.y)
		bounds.y = maxf(bounds.y, position.y)
		bounds_by_floor[floor_number] = bounds
	var floor_numbers: Array = bounds_by_floor.keys()
	floor_numbers.sort()
	var presentation_rng := RandomNumberGenerator.new()
	# This RNG is intentionally local and presentation-only. It never receives or
	# returns the authoritative gameplay RNG state.
	presentation_rng.seed = int((map_seed ^ PRESENTATION_SEED_SALT) & 0x7fffffff)
	var floor_specs: Array[Dictionary] = []
	var vertical_padding := maxf(art_size * 1.35, 20.0)
	for floor_value in floor_numbers:
		var floor_number := int(floor_value)
		var y_bounds: Vector2 = bounds_by_floor[floor_number]
		var floor_rect := Rect2(
			Vector2(world_rect.position.x, y_bounds.x - vertical_padding),
			Vector2(
				world_rect.size.x,
				maxf(art_size * 2.7, y_bounds.y - y_bounds.x + vertical_padding * 2.0)
			)
		).intersection(world_rect)
		var layers: Array[Dictionary] = []
		for layer_index in range(CLOUD_LAYER_COUNT):
			var inset_ratio := 0.035 + float(layer_index) * 0.075
			var layer_rect := floor_rect.grow(-floor_rect.size.y * inset_ratio)
			layer_rect.position.x = floor_rect.position.x
			layer_rect.size.x = floor_rect.size.x
			var points := _build_soft_band_points(
				layer_rect,
				presentation_rng,
				0.075 + float(layer_index) * 0.018
			)
			layers.append({
				"points": points,
				"color": _layer_color(layer_index),
			})
		floor_specs.append({
			"floor": floor_number,
			"layers": layers,
			"drift_amplitude": art_size * presentation_rng.randf_range(0.08, 0.18),
			"drift_speed": presentation_rng.randf_range(0.38, 0.62),
			"drift_phase": presentation_rng.randf_range(0.0, TAU),
		})
	return {
		"floors": floor_specs,
		"draw_call_count": floor_specs.size() * CLOUD_LAYER_COUNT,
		"presentation_seed": presentation_rng.seed,
	}


func draw(
	canvas: CanvasItem,
	model_value: Variant,
	camera_model: Dictionary,
	reveal_visual: Dictionary
) -> void:
	if canvas == null or not (model_value is Dictionary):
		return
	var model := model_value as Dictionary
	var zoom := maxf(0.001, float(camera_model.get(
		"render_zoom_multiplier",
		camera_model.get("zoom_multiplier", 1.0)
	)))
	var camera_offset: Vector2 = camera_model.get("offset", Vector2.ZERO)
	var revealed_floor := int(reveal_visual.get("revealed_floor", 0))
	var target_floor := int(reveal_visual.get("target_floor", 0))
	var reveal_pending := bool(reveal_visual.get("pending", false))
	var reveal_progress := smoothstep(
		0.0,
		1.0,
		clampf(float(reveal_visual.get("progress", 0.0)), 0.0, 1.0)
	)
	var drift_time := float(reveal_visual.get("drift_time_sec", 0.0))
	for floor_variant in model.get("floors", []):
		if not (floor_variant is Dictionary):
			continue
		var floor_spec := floor_variant as Dictionary
		var floor_number := int(floor_spec.get("floor", 0))
		if floor_number <= revealed_floor:
			continue
		var alpha_multiplier := 1.0
		if reveal_pending and floor_number <= target_floor:
			alpha_multiplier = 1.0 - reveal_progress
		if alpha_multiplier <= 0.001:
			continue
		var drift := sin(
			drift_time * float(floor_spec.get("drift_speed", 0.0))
			+ float(floor_spec.get("drift_phase", 0.0))
		) * float(floor_spec.get("drift_amplitude", 0.0))
		canvas.draw_set_transform(
			camera_offset + Vector2(drift * zoom, 0.0),
			0.0,
			Vector2.ONE * zoom
		)
		for layer_variant in floor_spec.get("layers", []):
			if not (layer_variant is Dictionary):
				continue
			var layer := layer_variant as Dictionary
			var color: Color = layer.get("color", PAPER_LIGHT)
			color.a *= alpha_multiplier
			var points_value: Variant = layer.get("points", null)
			if not (points_value is PackedVector2Array):
				continue
			canvas.draw_colored_polygon(
				points_value as PackedVector2Array,
				color
			)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _build_soft_band_points(
	rect: Rect2,
	rng: RandomNumberGenerator,
	wave_ratio: float
) -> PackedVector2Array:
	var top_points := PackedVector2Array()
	var bottom_points := PackedVector2Array()
	var wave_height := rect.size.y * wave_ratio
	var top_phase := rng.randf_range(0.0, TAU)
	var top_harmonic_phase := rng.randf_range(0.0, TAU)
	var bottom_phase := rng.randf_range(0.0, TAU)
	var bottom_harmonic_phase := rng.randf_range(0.0, TAU)
	for sample_index in range(CLOUD_SAMPLE_COUNT + 1):
		var ratio := float(sample_index) / float(CLOUD_SAMPLE_COUNT)
		var x := lerpf(rect.position.x, rect.end.x, ratio)
		# Low-frequency paired harmonics read as rolling ink mist. Per-sample
		# randomness produced angular mountain teeth, so all random choices are
		# phases fixed once during cached map construction.
		var top_wave := (
			sin(ratio * TAU * 1.35 + top_phase) * wave_height
			+ sin(ratio * TAU * 2.7 + top_harmonic_phase) * wave_height * 0.34
		)
		var bottom_wave := (
			sin(ratio * TAU * 1.18 + bottom_phase) * wave_height
			+ sin(ratio * TAU * 2.36 + bottom_harmonic_phase) * wave_height * 0.31
		)
		top_points.append(Vector2(x, rect.position.y + top_wave))
		bottom_points.append(Vector2(x, rect.end.y + bottom_wave))
	var polygon := PackedVector2Array()
	for point in top_points:
		polygon.append(point)
	for index in range(bottom_points.size() - 1, -1, -1):
		polygon.append(bottom_points[index])
	return polygon


static func _layer_color(layer_index: int) -> Color:
	match layer_index:
		0:
			return Color(PAPER_DEEP, 0.50)
		1:
			return Color(PAPER_LIGHT, 0.68)
	return Color(INK, 0.10)
