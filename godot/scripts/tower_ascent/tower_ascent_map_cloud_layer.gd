extends RefCounted

const TowerMapScrollAssetCatalog := preload(
	"res://scripts/tower_ascent/tower_map_scroll_asset_catalog.gd"
)

const CLOUD_LAYER_COUNT := 3
const CLOUD_SAMPLE_COUNT := 48
const BITMAP_PARALLAX_LAYER_COUNT := 2
const BITMAP_FRONT_CLOUD_COUNT := 4
const BITMAP_MAX_DRAW_CALLS_PER_FLOOR := 13
# 피드백2 5항: the near-opaque mist fog owns spatial concealment of locked
# floors; the haze band and motifs above it only supply cloud texture. The
# tone is deliberately distinct from the scroll chrome paper (f1dfb8) so a
# fogged floor reads as mist, not as an unpainted panel (the zoom QA probe
# classifies chrome-paper pixels as blank background).
const FOG_COVER_OPACITY := 0.97
const FOG_COVER_COLOR := Color("ece4cd")
const FOG_EDGE_WAVE_RATIO := 0.055
# World-space pixels at 1.0x map zoom. The core remains near-opaque while two
# cached gradient strips split the old single hard step across the organic edge.
const FOG_EDGE_FEATHER_DEPTH := 12.0
const FOG_EDGE_ALPHA_STEP_COUNT := 100
const PRESENTATION_SEED_SALT := 0x434c4f5544
const PAPER_LIGHT := Color("f1dfb8")
const PAPER_DEEP := Color("d7bd88")
const INK := Color("30271f")
const FRONT_CLOUD_ASSET_KEYS: Array[String] = [
	TowerMapScrollAssetCatalog.CLOUD_SWIRL_LARGE,
	TowerMapScrollAssetCatalog.CLOUD_SWIRL_MEDIUM,
	TowerMapScrollAssetCatalog.CLOUD_WISP,
	TowerMapScrollAssetCatalog.CLOUD_SWIRL_MEDIUM,
]
const FRONT_CLOUD_CENTER_Y_RATIOS: Array[float] = [0.30, 0.67, 0.45, 0.80]
const FRONT_CLOUD_SCALE_MINIMUMS: Array[float] = [1.10, 1.00, 1.18, 0.82]
const FRONT_CLOUD_SCALE_MAXIMUMS: Array[float] = [1.28, 1.18, 1.48, 1.02]

static var _fog_feather_colors_by_step: Array[PackedColorArray] = []


static func estimate_draw_calls(nodes_value: Variant) -> int:
	var floors: Dictionary = {}
	var nodes: Array = nodes_value if nodes_value is Array else []
	for node_variant in nodes:
		if node_variant is Dictionary:
			floors[int((node_variant as Dictionary).get(
				"segment_floor",
				(node_variant as Dictionary).get("floor", 0)
			))] = true
	# Reserve the bitmap worst case even when assets are unavailable. One fog
	# core plus two edge-feather strips, one tileable haze band as two clipped
	# copies, and four foreground motifs that may each straddle one horizontal
	# wrap edge (3 + 2 + 4 * 2 = 13). The route builder widens dot spacing against
	# this reserve before draw.
	return floors.size() * BITMAP_MAX_DRAW_CALLS_PER_FLOOR


func build(
	nodes_value: Variant,
	world_rect: Rect2,
	map_seed: int,
	art_size: float,
	resolution_by_key_value: Variant = {},
	map_scale: float = 1.0
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
	_ensure_fog_feather_color_cache()
	var bitmap_assets := _build_bitmap_asset_models(resolution_by_key_value)
	var bitmap_ready := (
		bitmap_assets.size() == TowerMapScrollAssetCatalog.CLOUD_ASSET_KEYS.size()
	)
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
			"floor_rect": floor_rect,
			"layers": layers,
			"bitmap_specs": _build_bitmap_specs(
				floor_rect,
				presentation_rng,
				bitmap_assets,
				map_scale
			) if bitmap_ready else [],
			"drift_amplitude": art_size * presentation_rng.randf_range(0.08, 0.18),
			"drift_speed": presentation_rng.randf_range(0.38, 0.62),
			"drift_phase": presentation_rng.randf_range(0.0, TAU),
		})
	return {
		"floors": floor_specs,
		"render_mode": "bitmap" if bitmap_ready else "procedural",
		"bitmap_assets": bitmap_assets,
		"bitmap_asset_count": bitmap_assets.size(),
		"parallax_layer_count": BITMAP_PARALLAX_LAYER_COUNT if bitmap_ready else 1,
		"maximum_draw_calls_per_floor": BITMAP_MAX_DRAW_CALLS_PER_FLOOR,
		"draw_call_count": floor_specs.size() * BITMAP_MAX_DRAW_CALLS_PER_FLOOR,
		"procedural_draw_call_count": floor_specs.size() * CLOUD_LAYER_COUNT,
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
	var bitmap_mode := str(model.get("render_mode", "procedural")) == "bitmap"
	var bitmap_assets_value: Variant = model.get("bitmap_assets", null)
	if bitmap_mode and not (bitmap_assets_value is Dictionary):
		bitmap_mode = false
	if bitmap_mode:
		canvas.draw_set_transform(camera_offset, 0.0, Vector2.ONE * zoom)
	var floors_value: Variant = model.get("floors", null)
	if not (floors_value is Array):
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	for floor_variant in floors_value:
		if not (floor_variant is Dictionary):
			continue
		var floor_spec := floor_variant as Dictionary
		var floor_number := int(floor_spec.get("floor", 0))
		var alpha_multiplier := _floor_alpha_multiplier_from_values(
			floor_number,
			revealed_floor,
			target_floor,
			reveal_pending,
			reveal_progress
		)
		if alpha_multiplier <= 0.001:
			continue
		if bitmap_mode:
			_draw_bitmap_floor(
				canvas,
				floor_spec,
				bitmap_assets_value as Dictionary,
				drift_time,
				alpha_multiplier
			)
		else:
			_draw_procedural_floor(
				canvas,
				floor_spec,
				zoom,
				camera_offset,
				drift_time,
				alpha_multiplier
			)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func estimate_visible_draw_calls(
	model_value: Variant,
	reveal_visual: Dictionary
) -> int:
	if not (model_value is Dictionary):
		return 0
	var model := model_value as Dictionary
	var floors_value: Variant = model.get("floors", null)
	if not (floors_value is Array):
		return 0
	var calls_per_floor := (
		BITMAP_MAX_DRAW_CALLS_PER_FLOOR
		if str(model.get("render_mode", "procedural")) == "bitmap"
		else CLOUD_LAYER_COUNT
	)
	var visible_floor_count := 0
	for floor_variant in floors_value:
		if not (floor_variant is Dictionary):
			continue
		var floor_number := int((floor_variant as Dictionary).get("floor", 0))
		if floor_alpha_multiplier(floor_number, reveal_visual) > 0.001:
			visible_floor_count += 1
	return visible_floor_count * calls_per_floor


static func floor_alpha_multiplier(
	floor_number: int,
	reveal_visual: Dictionary
) -> float:
	return _floor_alpha_multiplier_from_values(
		floor_number,
		int(reveal_visual.get("revealed_floor", 0)),
		int(reveal_visual.get("target_floor", 0)),
		bool(reveal_visual.get("pending", false)),
		smoothstep(
			0.0,
			1.0,
			clampf(float(reveal_visual.get("progress", 0.0)), 0.0, 1.0)
		)
	)


static func wrapped_cloud_center_x(
	spec: Dictionary,
	floor_rect: Rect2,
	drift_time: float
) -> float:
	if floor_rect.size.x <= 0.001:
		return floor_rect.get_center().x
	var travel := (
		float(spec.get("drift_direction", 1.0))
		* float(spec.get("drift_speed", 0.0))
		* maxf(0.0, drift_time)
	)
	return floor_rect.position.x + fposmod(
		float(spec.get("base_center_x", floor_rect.get_center().x))
			- floor_rect.position.x
			+ travel,
		floor_rect.size.x
	)


static func _floor_alpha_multiplier_from_values(
	floor_number: int,
	revealed_floor: int,
	target_floor: int,
	reveal_pending: bool,
	reveal_progress: float
) -> float:
	if floor_number <= revealed_floor:
		return 0.0
	if reveal_pending and floor_number <= target_floor:
		return 1.0 - reveal_progress
	return 1.0


func _draw_bitmap_floor(
	canvas: CanvasItem,
	floor_spec: Dictionary,
	bitmap_assets: Dictionary,
	drift_time: float,
	alpha_multiplier: float
) -> void:
	var floor_rect: Rect2 = floor_spec.get("floor_rect", Rect2())
	if floor_rect.size.x <= 0.001 or floor_rect.size.y <= 0.001:
		return
	var specs_value: Variant = floor_spec.get("bitmap_specs", null)
	if not (specs_value is Array):
		return
	for spec_variant in specs_value:
		if not (spec_variant is Dictionary):
			continue
		var spec := spec_variant as Dictionary
		if str(spec.get("kind", "cloud")) == "fog":
			var fog_color: Color = spec.get("color", FOG_COVER_COLOR)
			var fog_opacity := alpha_multiplier * float(spec.get("opacity", 1.0))
			_draw_cached_fog_feather_polygon(
				canvas,
				spec.get("top_feather_points", null),
				fog_opacity
			)
			_draw_cached_fog_feather_polygon(
				canvas,
				spec.get("bottom_feather_points", null),
				fog_opacity
			)
			_draw_cached_fog_polygon(
				canvas,
				spec.get("core_points", null),
				Color(fog_color, fog_opacity)
			)
			continue
		var asset_value: Variant = bitmap_assets.get(str(spec.get("asset_key", "")), null)
		if not (asset_value is Dictionary):
			continue
		var asset := asset_value as Dictionary
		var texture := asset.get("texture", null) as Texture2D
		var source_size: Vector2 = asset.get("texture_size", Vector2.ZERO)
		var target_size: Vector2 = spec.get("size", Vector2.ZERO)
		if texture == null or source_size.x <= 0.0 or target_size.x <= 0.0:
			continue
		var modulate := Color(1.0, 1.0, 1.0, alpha_multiplier * float(spec.get(
			"opacity",
			1.0
		)))
		if str(spec.get("kind", "cloud")) == "haze":
			var travel := (
				float(spec.get("drift_direction", 1.0))
				* float(spec.get("drift_speed", 0.0))
				* maxf(0.0, drift_time)
				+ float(spec.get("phase_offset", 0.0))
			)
			var wrap_offset := fposmod(travel, floor_rect.size.x)
			var first_rect := Rect2(
				Vector2(
					floor_rect.position.x + wrap_offset - floor_rect.size.x,
					float(spec.get("center_y", floor_rect.get_center().y))
						- target_size.y * 0.5
				),
				target_size
			)
			_draw_texture_clipped(
				canvas,
				texture,
				first_rect,
				floor_rect,
				source_size,
				modulate
			)
			first_rect.position.x += floor_rect.size.x
			_draw_texture_clipped(
				canvas,
				texture,
				first_rect,
				floor_rect,
				source_size,
				modulate
			)
			continue
		var center_x := wrapped_cloud_center_x(spec, floor_rect, drift_time)
		var target_rect := Rect2(
			Vector2(
				center_x - target_size.x * 0.5,
				float(spec.get("center_y", floor_rect.get_center().y))
					- target_size.y * 0.5
			),
			target_size
		)
		_draw_texture_clipped(
			canvas,
			texture,
			target_rect,
			floor_rect,
			source_size,
			modulate
		)
		if target_rect.position.x < floor_rect.position.x:
			target_rect.position.x += floor_rect.size.x
			_draw_texture_clipped(
				canvas,
				texture,
				target_rect,
				floor_rect,
				source_size,
				modulate
			)
		elif target_rect.end.x > floor_rect.end.x:
			target_rect.position.x -= floor_rect.size.x
			_draw_texture_clipped(
				canvas,
				texture,
				target_rect,
				floor_rect,
				source_size,
				modulate
			)


static func _draw_cached_fog_polygon(
	canvas: CanvasItem,
	points_value: Variant,
	color: Color
) -> void:
	if not (points_value is PackedVector2Array):
		return
	var points := points_value as PackedVector2Array
	if points.size() < 3:
		return
	canvas.draw_colored_polygon(points, color)


static func _draw_cached_fog_feather_polygon(
	canvas: CanvasItem,
	points_value: Variant,
	opacity: float
) -> void:
	if not (points_value is PackedVector2Array):
		return
	var points := points_value as PackedVector2Array
	if points.size() < 3 or _fog_feather_colors_by_step.is_empty():
		return
	var color_step := clampi(
		int(round(
			clampf(opacity / FOG_COVER_OPACITY, 0.0, 1.0)
				* float(FOG_EDGE_ALPHA_STEP_COUNT)
		)),
		0,
		FOG_EDGE_ALPHA_STEP_COUNT
	)
	canvas.draw_polygon(points, _fog_feather_colors_by_step[color_step])


static func _draw_texture_clipped(
	canvas: CanvasItem,
	texture: Texture2D,
	target_rect: Rect2,
	clip_rect: Rect2,
	source_size: Vector2,
	modulate: Color
) -> void:
	var clipped_rect := target_rect.intersection(clip_rect)
	if clipped_rect.size.x <= 0.001 or clipped_rect.size.y <= 0.001:
		return
	var source_per_world := Vector2(
		source_size.x / target_rect.size.x,
		source_size.y / target_rect.size.y
	)
	var source_rect := Rect2(
		(clipped_rect.position - target_rect.position) * source_per_world,
		clipped_rect.size * source_per_world
	)
	canvas.draw_texture_rect_region(
		texture,
		clipped_rect,
		source_rect,
		modulate
	)


func _draw_procedural_floor(
	canvas: CanvasItem,
	floor_spec: Dictionary,
	zoom: float,
	camera_offset: Vector2,
	drift_time: float,
	alpha_multiplier: float
) -> void:
	var drift := sin(
		drift_time * float(floor_spec.get("drift_speed", 0.0))
		+ float(floor_spec.get("drift_phase", 0.0))
	) * float(floor_spec.get("drift_amplitude", 0.0))
	canvas.draw_set_transform(
		camera_offset + Vector2(drift * zoom, 0.0),
		0.0,
		Vector2.ONE * zoom
	)
	var layers_value: Variant = floor_spec.get("layers", null)
	if not (layers_value is Array):
		return
	for layer_variant in layers_value:
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


static func _build_bitmap_asset_models(
	resolution_by_key_value: Variant
) -> Dictionary:
	if not (resolution_by_key_value is Dictionary):
		return {}
	var resolution_by_key := resolution_by_key_value as Dictionary
	var result: Dictionary = {}
	for asset_key in TowerMapScrollAssetCatalog.CLOUD_ASSET_KEYS:
		var resolution_value: Variant = resolution_by_key.get(asset_key, null)
		if not (resolution_value is Dictionary):
			return {}
		var resolution := resolution_value as Dictionary
		var texture := resolution.get("texture", null) as Texture2D
		if not bool(resolution.get("ready", false)) or texture == null:
			return {}
		result[asset_key] = {
			"texture": texture,
			"world_size": Vector2(resolution.get("world_size", Vector2i.ZERO)),
			"texture_size": Vector2(resolution.get(
				"expected_texture_size",
				Vector2i.ZERO
			)),
		}
	return result


static func _build_bitmap_specs(
	floor_rect: Rect2,
	rng: RandomNumberGenerator,
	bitmap_assets: Dictionary,
	map_scale: float
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var safe_scale := maxf(0.001, map_scale)
	var haze_asset: Dictionary = bitmap_assets.get(
		TowerMapScrollAssetCatalog.CLOUD_HAZE_BAND,
		{}
	)
	var haze_world_size: Vector2 = haze_asset.get("world_size", Vector2.ZERO)
	var fog_geometry := _build_fog_cover_geometry(floor_rect, rng)
	# 피드백2 5항: locked floors must be genuinely unreadable, like the pre-S7
	# fog. A near-opaque core and two gradient organic edge strips sit under
	# the textured haze/motif layers and fade with the same reveal multiplier.
	result.append({
		"kind": "fog",
		"depth_layer": 0,
		"color": FOG_COVER_COLOR,
		"opacity": FOG_COVER_OPACITY,
		"core_points": fog_geometry.get("core_points", PackedVector2Array()),
		"top_feather_points": fog_geometry.get(
			"top_feather_points",
			PackedVector2Array()
		),
		"bottom_feather_points": fog_geometry.get(
			"bottom_feather_points",
			PackedVector2Array()
		),
	})
	result.append({
		"kind": "haze",
		"asset_key": TowerMapScrollAssetCatalog.CLOUD_HAZE_BAND,
		"depth_layer": 0,
		"size": Vector2(floor_rect.size.x, haze_world_size.y * safe_scale),
		"center_y": floor_rect.position.y + floor_rect.size.y * rng.randf_range(0.46, 0.56),
		"phase_offset": rng.randf_range(0.0, floor_rect.size.x),
		"drift_direction": -1.0 if rng.randi() % 2 == 0 else 1.0,
		"drift_speed": 2.2 * safe_scale * rng.randf_range(0.86, 1.16),
		"opacity": 1.0,
	})
	for cloud_index in range(BITMAP_FRONT_CLOUD_COUNT):
		var asset_key := FRONT_CLOUD_ASSET_KEYS[cloud_index]
		var asset: Dictionary = bitmap_assets.get(asset_key, {})
		var world_size: Vector2 = asset.get("world_size", Vector2.ZERO)
		var scale_multiplier := rng.randf_range(
			FRONT_CLOUD_SCALE_MINIMUMS[cloud_index],
			FRONT_CLOUD_SCALE_MAXIMUMS[cloud_index]
		)
		var center_zone := (float(cloud_index) + 0.5) / float(BITMAP_FRONT_CLOUD_COUNT)
		result.append({
			"kind": "cloud",
			"asset_key": asset_key,
			"depth_layer": 1,
			"stable_id": cloud_index,
			"size": world_size * safe_scale * scale_multiplier,
			"base_center_x": floor_rect.position.x + floor_rect.size.x * clampf(
				center_zone + rng.randf_range(-0.075, 0.075),
				0.04,
				0.96
			),
			"center_y": floor_rect.position.y + floor_rect.size.y * clampf(
				FRONT_CLOUD_CENTER_Y_RATIOS[cloud_index]
					+ rng.randf_range(-0.055, 0.055),
				0.08,
				0.92
			),
			"drift_direction": -1.0 if rng.randi() % 2 == 0 else 1.0,
			"drift_speed": 4.6 * safe_scale * rng.randf_range(0.86, 1.42),
			"opacity": rng.randf_range(0.90, 1.0),
		})
	return result


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


static func fog_polygon_is_triangulable(points_value: Variant) -> bool:
	if not (points_value is PackedVector2Array):
		return false
	var points := points_value as PackedVector2Array
	if points.size() < 3:
		return false
	var doubled_area := 0.0
	for index in range(points.size()):
		var current := points[index]
		var next := points[(index + 1) % points.size()]
		doubled_area += current.x * next.y - next.x * current.y
	return (
		absf(doubled_area) > 0.001
		and not Geometry2D.triangulate_polygon(points).is_empty()
	)


static func _ensure_fog_feather_color_cache() -> void:
	if _fog_feather_colors_by_step.size() == FOG_EDGE_ALPHA_STEP_COUNT + 1:
		return
	_fog_feather_colors_by_step.clear()
	var edge_count := CLOUD_SAMPLE_COUNT + 1
	for step in range(FOG_EDGE_ALPHA_STEP_COUNT + 1):
		var colors := PackedColorArray()
		var inner_alpha := (
			FOG_COVER_OPACITY
			* float(step)
			/ float(FOG_EDGE_ALPHA_STEP_COUNT)
		)
		for _index in range(edge_count):
			colors.append(Color(FOG_COVER_COLOR, 0.0))
		for _index in range(edge_count):
			colors.append(Color(FOG_COVER_COLOR, inner_alpha))
		_fog_feather_colors_by_step.append(colors)


static func _build_fog_cover_geometry(
	rect: Rect2,
	rng: RandomNumberGenerator
) -> Dictionary:
	var outer_points := _build_soft_band_points(rect, rng, FOG_EDGE_WAVE_RATIO)
	var edge_count := CLOUD_SAMPLE_COUNT + 1
	if outer_points.size() != edge_count * 2:
		return {}
	var feather_depth := minf(FOG_EDGE_FEATHER_DEPTH, rect.size.y * 0.16)
	var outer_top := PackedVector2Array()
	var inner_top := PackedVector2Array()
	var outer_bottom := PackedVector2Array()
	var inner_bottom := PackedVector2Array()
	for index in range(edge_count):
		var top_point := outer_points[index]
		outer_top.append(top_point)
		inner_top.append(top_point + Vector2(0.0, feather_depth))
		var bottom_point := outer_points[edge_count + index]
		outer_bottom.append(bottom_point)
		inner_bottom.append(bottom_point - Vector2(0.0, feather_depth))
	var core_points := PackedVector2Array()
	for point in inner_top:
		core_points.append(point)
	for point in inner_bottom:
		core_points.append(point)
	if not fog_polygon_is_triangulable(core_points):
		core_points = _rect_polygon(Rect2(
			Vector2(rect.position.x, rect.position.y + feather_depth),
			Vector2(rect.size.x, rect.size.y - feather_depth * 2.0)
		))
	var top_feather_points := PackedVector2Array()
	for point in outer_top:
		top_feather_points.append(point)
	for index in range(inner_top.size() - 1, -1, -1):
		top_feather_points.append(inner_top[index])
	if not fog_polygon_is_triangulable(top_feather_points):
		top_feather_points.clear()
	var bottom_feather_points := PackedVector2Array()
	for point in outer_bottom:
		bottom_feather_points.append(point)
	for index in range(inner_bottom.size() - 1, -1, -1):
		bottom_feather_points.append(inner_bottom[index])
	if not fog_polygon_is_triangulable(bottom_feather_points):
		bottom_feather_points.clear()
	return {
		"core_points": core_points,
		"top_feather_points": top_feather_points,
		"bottom_feather_points": bottom_feather_points,
	}


static func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])


static func _layer_color(layer_index: int) -> Color:
	match layer_index:
		0:
			return Color(PAPER_DEEP, 0.50)
		1:
			return Color(PAPER_LIGHT, 0.68)
	return Color(INK, 0.10)
