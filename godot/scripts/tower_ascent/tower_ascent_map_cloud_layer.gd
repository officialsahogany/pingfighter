extends RefCounted

const TowerMapScrollAssetCatalog := preload(
	"res://scripts/tower_ascent/tower_map_scroll_asset_catalog.gd"
)

const BITMAP_FRONT_CLOUD_COUNT := 8
const BITMAP_MAX_MOTIF_DRAW_CALLS := BITMAP_FRONT_CLOUD_COUNT * 2
const BITMAP_DISSOLVE_DRAW_CALLS := 2
const BITMAP_REVEAL_SPLIT_DRAW_CALLS := 1
const PROCEDURAL_DRAW_CALL_COUNT := 1
const WALL_INTERIOR_TILE_Y_SCALE := 3.0
const LOW_ZOOM_MOTIF_SCALE_MAXIMUM := 3.5
const LOW_ZOOM_MOTIF_SCALE_END := 0.52
const WALL_INTERIOR_OPACITY := 1.0
const WALL_MINIMUM_CONCEAL_OPACITY := 0.90
const DISSOLVE_JOIN_BLEND_RATIO := 0.075
const PRESENTATION_SEED_SALT := 0x434c4f5544
const PROCEDURAL_WALL_COLOR := Color("625441")
const FRONT_CLOUD_ASSET_KEYS: Array[String] = [
	TowerMapScrollAssetCatalog.CLOUD_SWIRL_LARGE,
	TowerMapScrollAssetCatalog.CLOUD_SWIRL_MEDIUM,
	TowerMapScrollAssetCatalog.CLOUD_WISP,
	TowerMapScrollAssetCatalog.CLOUD_SWIRL_MEDIUM,
	TowerMapScrollAssetCatalog.CLOUD_SWIRL_LARGE,
	TowerMapScrollAssetCatalog.CLOUD_WISP,
	TowerMapScrollAssetCatalog.CLOUD_SWIRL_MEDIUM,
	TowerMapScrollAssetCatalog.CLOUD_SWIRL_LARGE,
]
const FRONT_CLOUD_CENTER_Y_RATIOS: Array[float] = [
	0.07, 0.19, 0.31, 0.43, 0.57, 0.69, 0.81, 0.93,
]
const FRONT_CLOUD_SCALE_MINIMUMS: Array[float] = [
	1.62, 1.44, 1.90, 1.34, 1.56, 1.82, 1.42, 1.50,
]
const FRONT_CLOUD_SCALE_MAXIMUMS: Array[float] = [
	2.02, 1.82, 2.42, 1.70, 1.96, 2.30, 1.80, 1.92,
]

static var _textured_quad_points := PackedVector2Array([
	Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
])
static var _textured_quad_colors := PackedColorArray([
	Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE,
])
static var _textured_quad_uvs := PackedVector2Array([
	Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO,
])


static func interior_tile_world_size(map_scale: float = 1.0) -> Vector2:
	var base_size := Vector2(TowerMapScrollAssetCatalog.CLOUD_WALL_INTERIOR_WORLD_SIZE)
	return Vector2(
		base_size.x,
		base_size.y * WALL_INTERIOR_TILE_Y_SCALE
	) * maxf(0.001, map_scale)


static func estimate_draw_calls(
	nodes_value: Variant,
	art_size: float = 80.0,
	map_scale: float = 1.0
) -> int:
	var nodes: Array = nodes_value if nodes_value is Array else []
	var floors: Dictionary = {}
	var minimum_y := INF
	var maximum_y := -INF
	for node_variant in nodes:
		if not (node_variant is Dictionary):
			continue
		var node := node_variant as Dictionary
		var floor_number := int(node.get("segment_floor", node.get("floor", 0)))
		if floor_number <= 0:
			continue
		var position: Vector2 = node.get("world_position", Vector2.ZERO)
		floors[floor_number] = true
		minimum_y = minf(minimum_y, position.y)
		maximum_y = maxf(maximum_y, position.y)
	if floors.is_empty() or not is_finite(minimum_y) or not is_finite(maximum_y):
		return 0
	var vertical_padding := maxf(art_size * 1.35, 20.0)
	var tile_height := maxf(1.0, interior_tile_world_size(map_scale).y)
	# The merged wall is tiled from its moving dissolve join upward. A reveal can
	# split one tile between the stable and fading portions, hence the single
	# extra interior call. The eight accents may each straddle one horizontal edge.
	var conservative_height := maximum_y - minimum_y + vertical_padding * 2.0
	var interior_calls := maxi(1, ceili(conservative_height / tile_height))
	return (
		interior_calls
		+ BITMAP_REVEAL_SPLIT_DRAW_CALLS
		+ BITMAP_DISSOLVE_DRAW_CALLS
		+ BITMAP_MAX_MOTIF_DRAW_CALLS
	)


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
	var wall_rect := _build_wall_rect(bounds_by_floor, world_rect, art_size)
	var boundary_by_revealed_floor := _build_boundary_by_revealed_floor(
		floor_numbers,
		bounds_by_floor,
		wall_rect
	)
	var floor_spans := _build_floor_spans(
		floor_numbers,
		boundary_by_revealed_floor,
		wall_rect
	)
	var presentation_rng := RandomNumberGenerator.new()
	# Presentation randomness stays isolated from authoritative gameplay RNG.
	presentation_rng.seed = int((map_seed ^ PRESENTATION_SEED_SALT) & 0x7fffffff)
	var bitmap_assets := _build_bitmap_asset_models(resolution_by_key_value)
	var bitmap_ready := (
		bitmap_assets.size() == TowerMapScrollAssetCatalog.CLOUD_ASSET_KEYS.size()
	)
	var safe_scale := maxf(0.001, map_scale)
	var interior_size := interior_tile_world_size(safe_scale)
	var dissolve_size: Vector2 = (
		(bitmap_assets.get(TowerMapScrollAssetCatalog.CLOUD_WALL_DISSOLVE, {}) as Dictionary)
			.get("world_size", Vector2(
				TowerMapScrollAssetCatalog.CLOUD_WALL_DISSOLVE_WORLD_SIZE
			))
	)
	var motif_specs: Array[Dictionary] = []
	if bitmap_ready:
		motif_specs = _build_motif_specs(
			wall_rect,
			presentation_rng,
			bitmap_assets,
			safe_scale
		)
	var draw_call_reserve := estimate_draw_calls(nodes, art_size, safe_scale)
	return {
		"floors": floor_spans,
		"floor_numbers": floor_numbers,
		"wall_rect": wall_rect,
		"boundary_by_revealed_floor": boundary_by_revealed_floor,
		"merged_region_count": 1 if wall_rect.has_area() else 0,
		"render_mode": "bitmap" if bitmap_ready else "procedural",
		"bitmap_assets": bitmap_assets,
		"bitmap_asset_count": bitmap_assets.size(),
		"interior_spec": {
			"kind": "wall_interior",
			"asset_key": TowerMapScrollAssetCatalog.CLOUD_WALL_INTERIOR,
			"world_size": interior_size,
			"opacity": WALL_INTERIOR_OPACITY,
		},
		"dissolve_spec": {
			"kind": "lower_dissolve",
			"asset_key": TowerMapScrollAssetCatalog.CLOUD_WALL_DISSOLVE,
			"world_size": Vector2(dissolve_size) * safe_scale,
			"join_blend_ratio": DISSOLVE_JOIN_BLEND_RATIO,
		},
		"motif_specs": motif_specs,
		"motif_count": motif_specs.size(),
		"parallax_layer_count": 2 if bitmap_ready else 1,
		"maximum_draw_calls_per_merged_region": draw_call_reserve,
		"draw_call_count": draw_call_reserve,
		"procedural_draw_call_count": PROCEDURAL_DRAW_CALL_COUNT,
		"blend_mode": "mix",
		"material_swap_count": 0,
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
	var state := wall_visual_state(model, reveal_visual)
	if not bool(state.get("visible", false)):
		return
	var zoom := maxf(0.001, float(camera_model.get(
		"render_zoom_multiplier",
		camera_model.get("zoom_multiplier", 1.0)
	)))
	var camera_offset: Vector2 = camera_model.get("offset", Vector2.ZERO)
	canvas.draw_set_transform(camera_offset, 0.0, Vector2.ONE * zoom)
	var bitmap_assets_value: Variant = model.get("bitmap_assets", null)
	if (
		str(model.get("render_mode", "procedural")) == "bitmap"
		and bitmap_assets_value is Dictionary
	):
		_draw_bitmap_wall(
			canvas,
			model,
			state,
			bitmap_assets_value as Dictionary,
			float(reveal_visual.get("drift_time_sec", 0.0)),
			zoom
		)
	else:
		var wall_fill_rect: Rect2 = state.get("wall_fill_rect", Rect2())
		if wall_fill_rect.has_area():
			canvas.draw_rect(
				wall_fill_rect,
				Color(PROCEDURAL_WALL_COLOR, WALL_MINIMUM_CONCEAL_OPACITY),
				true
			)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func estimate_visible_draw_calls(
	model_value: Variant,
	reveal_visual: Dictionary
) -> int:
	if not (model_value is Dictionary):
		return 0
	var model := model_value as Dictionary
	if not bool(wall_visual_state(model, reveal_visual).get("visible", false)):
		return 0
	return (
		int(model.get("draw_call_count", 0))
		if str(model.get("render_mode", "procedural")) == "bitmap"
		else int(model.get("procedural_draw_call_count", PROCEDURAL_DRAW_CALL_COUNT))
	)


static func floor_alpha_multiplier(
	floor_number: int,
	reveal_visual: Dictionary
) -> float:
	var revealed_floor := int(reveal_visual.get("revealed_floor", 0))
	if floor_number <= revealed_floor:
		return 0.0
	if (
		bool(reveal_visual.get("pending", false))
		and floor_number <= int(reveal_visual.get("target_floor", 0))
	):
		return 1.0 - smoothstep(
			0.0,
			1.0,
			clampf(float(reveal_visual.get("progress", 0.0)), 0.0, 1.0)
		)
	return 1.0


static func wall_visual_state(model: Dictionary, reveal_visual: Dictionary) -> Dictionary:
	var wall_rect: Rect2 = model.get("wall_rect", Rect2())
	var floor_numbers_value: Variant = model.get("floor_numbers", null)
	if not wall_rect.has_area() or not (floor_numbers_value is Array):
		return {"visible": false}
	var floor_numbers := floor_numbers_value as Array
	if floor_numbers.is_empty():
		return {"visible": false}
	var revealed_floor := int(reveal_visual.get("revealed_floor", 0))
	var target_floor := int(reveal_visual.get("target_floor", revealed_floor))
	var reveal_pending := (
		bool(reveal_visual.get("pending", false))
		and target_floor > revealed_floor
	)
	var progress := (
		smoothstep(
			0.0,
			1.0,
			clampf(float(reveal_visual.get("progress", 0.0)), 0.0, 1.0)
		)
		if reveal_pending
		else 0.0
	)
	var boundary_by_revealed_floor: Dictionary = model.get(
		"boundary_by_revealed_floor",
		{}
	)
	var start_boundary := _boundary_y_for_revealed_floor(
		floor_numbers,
		boundary_by_revealed_floor,
		revealed_floor,
		wall_rect
	)
	var end_boundary := (
		_boundary_y_for_revealed_floor(
			floor_numbers,
			boundary_by_revealed_floor,
			target_floor,
			wall_rect
		)
		if reveal_pending
		else start_boundary
	)
	var boundary_y := lerpf(start_boundary, end_boundary, progress)
	boundary_y = clampf(boundary_y, wall_rect.position.y, wall_rect.end.y)
	if boundary_y <= wall_rect.position.y + 0.001:
		return {
			"visible": false,
			"start_boundary_y": start_boundary,
			"end_boundary_y": end_boundary,
			"boundary_y": boundary_y,
			"reveal_alpha": 0.0,
		}
	var dissolve_spec: Dictionary = model.get("dissolve_spec", {})
	var dissolve_size: Vector2 = dissolve_spec.get("world_size", Vector2.ZERO)
	var dissolve_height := minf(
		maxf(0.0, dissolve_size.y),
		boundary_y - wall_rect.position.y
	)
	var dissolve_rect := Rect2(
		Vector2(wall_rect.position.x, boundary_y - dissolve_height),
		Vector2(wall_rect.size.x, dissolve_height)
	)
	var interior_rect := Rect2(
		wall_rect.position,
		Vector2(wall_rect.size.x, maxf(0.0, dissolve_rect.position.y - wall_rect.position.y))
	)
	var reveal_segment_rect := Rect2()
	if reveal_pending and interior_rect.end.y > end_boundary + 0.001:
		reveal_segment_rect = Rect2(
			Vector2(wall_rect.position.x, end_boundary),
			Vector2(wall_rect.size.x, interior_rect.end.y - end_boundary)
		)
	var stable_dissolve_rect := dissolve_rect
	var fading_dissolve_rect := Rect2()
	if reveal_pending:
		stable_dissolve_rect = dissolve_rect.intersection(Rect2(
			wall_rect.position,
			Vector2(wall_rect.size.x, maxf(0.0, end_boundary - wall_rect.position.y))
		))
		var fade_top := maxf(dissolve_rect.position.y, end_boundary)
		if dissolve_rect.end.y > fade_top + 0.001:
			fading_dissolve_rect = Rect2(
				Vector2(wall_rect.position.x, fade_top),
				Vector2(wall_rect.size.x, dissolve_rect.end.y - fade_top)
			)
	return {
		"visible": true,
		"wall_fill_rect": Rect2(
			wall_rect.position,
			Vector2(wall_rect.size.x, boundary_y - wall_rect.position.y)
		),
		"interior_rect": interior_rect,
		"dissolve_rect": dissolve_rect,
		"stable_dissolve_rect": stable_dissolve_rect,
		"fading_dissolve_rect": fading_dissolve_rect,
		"reveal_segment_rect": reveal_segment_rect,
		"start_boundary_y": start_boundary,
		"end_boundary_y": end_boundary,
		"boundary_y": boundary_y,
		"reveal_alpha": 1.0 - progress if reveal_pending else 1.0,
		"dissolve_alpha": 1.0,
		"reveal_fade_start_y": end_boundary if reveal_pending else boundary_y,
		"reveal_fade_end_y": boundary_y,
		"reveal_pending": reveal_pending,
	}


static func merged_region_contract_holds(model: Dictionary) -> bool:
	var interior: Dictionary = model.get("interior_spec", {})
	var dissolve: Dictionary = model.get("dissolve_spec", {})
	return (
		int(model.get("merged_region_count", 0)) == 1
		and (model.get("wall_rect", Rect2()) as Rect2).has_area()
		and str(interior.get("asset_key", ""))
			== TowerMapScrollAssetCatalog.CLOUD_WALL_INTERIOR
		and float(interior.get("opacity", 0.0)) >= WALL_MINIMUM_CONCEAL_OPACITY
		and str(dissolve.get("asset_key", ""))
			== TowerMapScrollAssetCatalog.CLOUD_WALL_DISSOLVE
		and float(dissolve.get("join_blend_ratio", 0.0)) > 0.0
		and int(model.get("motif_count", 0)) == BITMAP_FRONT_CLOUD_COUNT
		and str(model.get("blend_mode", "")) == "mix"
		and int(model.get("material_swap_count", -1)) == 0
	)


static func wrapped_cloud_center_x(
	spec: Dictionary,
	wall_rect: Rect2,
	drift_time: float
) -> float:
	if wall_rect.size.x <= 0.001:
		return wall_rect.get_center().x
	var travel := (
		float(spec.get("drift_direction", 1.0))
		* float(spec.get("drift_speed", 0.0))
		* maxf(0.0, drift_time)
	)
	return wall_rect.position.x + fposmod(
		float(spec.get("base_center_x", wall_rect.get_center().x))
			- wall_rect.position.x
			+ travel,
		wall_rect.size.x
	)


func _draw_bitmap_wall(
	canvas: CanvasItem,
	model: Dictionary,
	state: Dictionary,
	bitmap_assets: Dictionary,
	drift_time: float,
	render_zoom: float
) -> void:
	var interior_spec: Dictionary = model.get("interior_spec", {})
	var interior_asset: Dictionary = bitmap_assets.get(
		str(interior_spec.get("asset_key", "")),
		{}
	)
	var interior_texture := interior_asset.get("texture", null) as Texture2D
	var interior_source_size: Vector2 = interior_asset.get("texture_size", Vector2.ZERO)
	var interior_world_size: Vector2 = interior_spec.get("world_size", Vector2.ZERO)
	if (
		interior_texture != null
		and interior_source_size.x > 0.0
		and interior_source_size.y > 0.0
		and interior_world_size.y > 0.0
	):
		var interior_draw_rect: Rect2 = state.get("interior_rect", Rect2())
		var dissolve_rect: Rect2 = state.get("dissolve_rect", Rect2())
		var join_blend_height := _dissolve_join_blend_height(
			dissolve_rect,
			float((model.get("dissolve_spec", {}) as Dictionary).get(
				"join_blend_ratio",
				0.0
			))
		)
		if interior_draw_rect.has_area() and join_blend_height > 0.0:
			interior_draw_rect.size.y = minf(
				interior_draw_rect.size.y + join_blend_height,
				float(state.get("boundary_y", interior_draw_rect.end.y))
					- interior_draw_rect.position.y
			)
		_draw_wall_interior(
			canvas,
			interior_texture,
			interior_source_size,
			interior_world_size,
			interior_draw_rect,
			float(state.get("reveal_fade_start_y", interior_draw_rect.end.y)),
			float(state.get("reveal_fade_end_y", interior_draw_rect.end.y)),
			float(state.get("reveal_alpha", 1.0))
		)
	var dissolve_spec: Dictionary = model.get("dissolve_spec", {})
	var dissolve_asset: Dictionary = bitmap_assets.get(
		str(dissolve_spec.get("asset_key", "")),
		{}
	)
	var dissolve_texture := dissolve_asset.get("texture", null) as Texture2D
	var dissolve_source_size: Vector2 = dissolve_asset.get("texture_size", Vector2.ZERO)
	var dissolve_rect: Rect2 = state.get("dissolve_rect", Rect2())
	var wall_rect: Rect2 = model.get("wall_rect", Rect2())
	var motif_clip: Rect2 = state.get("interior_rect", Rect2())
	var motif_join_blend_height := _dissolve_join_blend_height(
		dissolve_rect,
		float(dissolve_spec.get("join_blend_ratio", 0.0))
	)
	if motif_clip.has_area() and motif_join_blend_height > 0.0:
		motif_clip.size.y = minf(
			motif_clip.size.y + motif_join_blend_height,
			float(state.get("boundary_y", motif_clip.end.y)) - motif_clip.position.y
		)
	var reveal_fade_start_y := float(state.get("reveal_fade_start_y", motif_clip.end.y))
	var reveal_fade_end_y := float(state.get("reveal_fade_end_y", motif_clip.end.y))
	var reveal_alpha := float(state.get("reveal_alpha", 1.0))
	var motif_render_scale := lerpf(
		LOW_ZOOM_MOTIF_SCALE_MAXIMUM,
		1.0,
		smoothstep(0.0, LOW_ZOOM_MOTIF_SCALE_END, maxf(0.0, render_zoom))
	)
	for spec_variant in model.get("motif_specs", []):
		if not (spec_variant is Dictionary):
			continue
		var spec := spec_variant as Dictionary
		var asset: Dictionary = bitmap_assets.get(str(spec.get("asset_key", "")), {})
		var texture := asset.get("texture", null) as Texture2D
		var source_size: Vector2 = asset.get("texture_size", Vector2.ZERO)
		var target_size: Vector2 = (
			(spec.get("size", Vector2.ZERO) as Vector2) * motif_render_scale
		)
		if texture == null or source_size.x <= 0.0 or target_size.x <= 0.0:
			continue
		var target_rect := Rect2(
			Vector2(
				wrapped_cloud_center_x(spec, wall_rect, drift_time) - target_size.x * 0.5,
				float(spec.get("center_y", wall_rect.get_center().y)) - target_size.y * 0.5
			),
			target_size
		)
		var modulate := Color(1.0, 1.0, 1.0, float(spec.get("opacity", 1.0)))
		_draw_texture_clipped_with_vertical_fade(
			canvas,
			texture,
			target_rect,
			motif_clip,
			source_size,
			modulate,
			reveal_fade_start_y,
			reveal_fade_end_y,
			reveal_alpha
		)
		if target_rect.position.x < wall_rect.position.x:
			target_rect.position.x += wall_rect.size.x
			_draw_texture_clipped_with_vertical_fade(
				canvas, texture, target_rect, motif_clip, source_size, modulate,
				reveal_fade_start_y, reveal_fade_end_y, reveal_alpha
			)
		elif target_rect.end.x > wall_rect.end.x:
			target_rect.position.x -= wall_rect.size.x
			_draw_texture_clipped_with_vertical_fade(
				canvas, texture, target_rect, motif_clip, source_size, modulate,
				reveal_fade_start_y, reveal_fade_end_y, reveal_alpha
			)
	if (
		dissolve_texture != null
		and dissolve_rect.has_area()
		and dissolve_source_size.x > 0.0
		and dissolve_source_size.y > 0.0
	):
		# Foreground dissolve owns the final join so enlarged fit-all motifs blend
		# beneath it instead of clipping to a new horizontal edge.
		_draw_dissolve_with_join_blend(
			canvas,
			dissolve_texture,
			dissolve_rect,
			dissolve_source_size,
			float(dissolve_spec.get("join_blend_ratio", 0.0)),
			float(state.get("reveal_fade_start_y", dissolve_rect.end.y)),
			float(state.get("reveal_fade_end_y", dissolve_rect.end.y)),
			float(state.get("reveal_alpha", 1.0))
		)


static func _dissolve_join_blend_height(
	dissolve_rect: Rect2,
	join_blend_ratio: float
) -> float:
	return dissolve_rect.size.y * clampf(join_blend_ratio, 0.0, 0.25)


static func _draw_dissolve_with_join_blend(
	canvas: CanvasItem,
	texture: Texture2D,
	target_rect: Rect2,
	source_size: Vector2,
	join_blend_ratio: float,
	fade_start_y: float,
	fade_end_y: float,
	tail_alpha: float
) -> void:
	var blend_ratio := clampf(join_blend_ratio, 0.0, 0.25)
	var blend_height := _dissolve_join_blend_height(target_rect, blend_ratio)
	if blend_height <= 0.001:
		_draw_texture_rect_region_vertical_alpha(
			canvas,
			texture,
			target_rect,
			Rect2(Vector2.ZERO, source_size),
			source_size,
			_reveal_fade_alpha_at_y(target_rect.position.y, fade_start_y, fade_end_y, tail_alpha),
			_reveal_fade_alpha_at_y(target_rect.end.y, fade_start_y, fade_end_y, tail_alpha)
		)
		return
	var blend_rect := Rect2(
		target_rect.position,
		Vector2(target_rect.size.x, blend_height)
	)
	_draw_texture_rect_region_vertical_alpha(
		canvas,
		texture,
		blend_rect,
		Rect2(Vector2.ZERO, Vector2(source_size.x, source_size.y * blend_ratio)),
		source_size,
		0.0,
		_reveal_fade_alpha_at_y(blend_rect.end.y, fade_start_y, fade_end_y, tail_alpha)
	)
	var remainder_rect := Rect2(
		Vector2(target_rect.position.x, blend_rect.end.y),
		Vector2(target_rect.size.x, target_rect.end.y - blend_rect.end.y)
	)
	if not remainder_rect.has_area():
		return
	_draw_texture_rect_region_vertical_alpha(
		canvas,
		texture,
		remainder_rect,
		Rect2(
			Vector2(0.0, source_size.y * blend_ratio),
			Vector2(source_size.x, source_size.y * (1.0 - blend_ratio))
		),
		source_size,
		_reveal_fade_alpha_at_y(remainder_rect.position.y, fade_start_y, fade_end_y, tail_alpha),
		_reveal_fade_alpha_at_y(remainder_rect.end.y, fade_start_y, fade_end_y, tail_alpha)
	)


static func _draw_wall_interior(
	canvas: CanvasItem,
	texture: Texture2D,
	source_size: Vector2,
	tile_world_size: Vector2,
	interior_rect: Rect2,
	fade_start_y: float,
	fade_end_y: float,
	fade_alpha: float
) -> void:
	if not interior_rect.has_area() or tile_world_size.y <= 0.001:
		return
	var chunk_bottom := interior_rect.end.y
	while chunk_bottom > interior_rect.position.y + 0.001:
		var chunk_top := maxf(
			interior_rect.position.y,
			chunk_bottom - tile_world_size.y
		)
		var chunk_rect := Rect2(
			Vector2(interior_rect.position.x, chunk_top),
			Vector2(interior_rect.size.x, chunk_bottom - chunk_top)
		)
		var source_height := source_size.y * chunk_rect.size.y / tile_world_size.y
		var source_rect := Rect2(
			Vector2(0.0, source_size.y - source_height),
			Vector2(source_size.x, source_height)
		)
		if chunk_rect.end.y > fade_start_y + 0.001 and fade_end_y > fade_start_y + 0.001:
			var upper_height := clampf(
				fade_start_y - chunk_rect.position.y,
				0.0,
				chunk_rect.size.y
			)
			var upper_ratio := upper_height / chunk_rect.size.y
			if upper_height > 0.001:
				var upper_target := Rect2(
					chunk_rect.position,
					Vector2(chunk_rect.size.x, upper_height)
				)
				var upper_source := Rect2(
					source_rect.position,
					Vector2(source_rect.size.x, source_rect.size.y * upper_ratio)
				)
				canvas.draw_texture_rect_region(texture, upper_target, upper_source)
			var lower_target := Rect2(
				Vector2(chunk_rect.position.x, chunk_rect.position.y + upper_height),
				Vector2(chunk_rect.size.x, chunk_rect.size.y - upper_height)
			)
			var lower_source := Rect2(
				Vector2(source_rect.position.x, source_rect.position.y + source_rect.size.y * upper_ratio),
				Vector2(source_rect.size.x, source_rect.size.y * (1.0 - upper_ratio))
			)
			_draw_texture_rect_region_vertical_alpha(
				canvas,
				texture,
				lower_target,
				lower_source,
				source_size,
				_reveal_fade_alpha_at_y(lower_target.position.y, fade_start_y, fade_end_y, fade_alpha),
				_reveal_fade_alpha_at_y(lower_target.end.y, fade_start_y, fade_end_y, fade_alpha)
			)
		else:
			canvas.draw_texture_rect_region(
				texture,
				chunk_rect,
				source_rect,
				Color.WHITE
			)
		chunk_bottom = chunk_top


static func _reveal_fade_alpha_at_y(
	world_y: float,
	fade_start_y: float,
	fade_end_y: float,
	tail_alpha: float
) -> float:
	if fade_end_y <= fade_start_y + 0.001 or world_y <= fade_start_y:
		return 1.0
	var fade_progress := clampf(
		(world_y - fade_start_y) / (fade_end_y - fade_start_y),
		0.0,
		1.0
	)
	return lerpf(1.0, clampf(tail_alpha, 0.0, 1.0), fade_progress)


static func _draw_texture_rect_region_vertical_alpha(
	canvas: CanvasItem,
	texture: Texture2D,
	target_rect: Rect2,
	source_rect: Rect2,
	source_size: Vector2,
	top_alpha: float,
	bottom_alpha: float,
	modulate: Color = Color.WHITE
) -> void:
	if not target_rect.has_area() or source_size.x <= 0.001 or source_size.y <= 0.001:
		return
	var safe_top_alpha := clampf(top_alpha, 0.0, 1.0)
	var safe_bottom_alpha := clampf(bottom_alpha, 0.0, 1.0)
	if is_equal_approx(safe_top_alpha, safe_bottom_alpha):
		canvas.draw_texture_rect_region(
			texture,
			target_rect,
			source_rect,
			Color(modulate, modulate.a * safe_top_alpha)
		)
		return
	_textured_quad_points[0] = target_rect.position
	_textured_quad_points[1] = Vector2(target_rect.end.x, target_rect.position.y)
	_textured_quad_points[2] = target_rect.end
	_textured_quad_points[3] = Vector2(target_rect.position.x, target_rect.end.y)
	_textured_quad_colors[0] = Color(modulate, modulate.a * safe_top_alpha)
	_textured_quad_colors[1] = _textured_quad_colors[0]
	_textured_quad_colors[2] = Color(modulate, modulate.a * safe_bottom_alpha)
	_textured_quad_colors[3] = _textured_quad_colors[2]
	_textured_quad_uvs[0] = source_rect.position / source_size
	_textured_quad_uvs[1] = Vector2(source_rect.end.x, source_rect.position.y) / source_size
	_textured_quad_uvs[2] = source_rect.end / source_size
	_textured_quad_uvs[3] = Vector2(source_rect.position.x, source_rect.end.y) / source_size
	canvas.draw_polygon(
		_textured_quad_points,
		_textured_quad_colors,
		_textured_quad_uvs,
		texture
	)


static func _draw_texture_clipped_with_vertical_fade(
	canvas: CanvasItem,
	texture: Texture2D,
	target_rect: Rect2,
	clip_rect: Rect2,
	source_size: Vector2,
	modulate: Color,
	fade_start_y: float,
	fade_end_y: float,
	tail_alpha: float
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
	_draw_texture_rect_region_vertical_alpha(
		canvas,
		texture,
		clipped_rect,
		source_rect,
		source_size,
		_reveal_fade_alpha_at_y(clipped_rect.position.y, fade_start_y, fade_end_y, tail_alpha),
		_reveal_fade_alpha_at_y(clipped_rect.end.y, fade_start_y, fade_end_y, tail_alpha),
		modulate
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


static func _build_motif_specs(
	wall_rect: Rect2,
	rng: RandomNumberGenerator,
	bitmap_assets: Dictionary,
	map_scale: float
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
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
			"kind": "cloud_motif",
			"asset_key": asset_key,
			"stable_id": cloud_index,
			"size": world_size * map_scale * scale_multiplier,
			"base_center_x": wall_rect.position.x + wall_rect.size.x * clampf(
				center_zone + rng.randf_range(-0.075, 0.075),
				0.04,
				0.96
			),
			"center_y": wall_rect.position.y + wall_rect.size.y * clampf(
				FRONT_CLOUD_CENTER_Y_RATIOS[cloud_index]
					+ rng.randf_range(-0.028, 0.028),
				0.05,
				0.95
			),
			"drift_direction": -1.0 if rng.randi() % 2 == 0 else 1.0,
			"drift_speed": 4.6 * map_scale * rng.randf_range(0.86, 1.42),
			"opacity": rng.randf_range(0.90, 1.0),
		})
	return result


static func _build_wall_rect(
	bounds_by_floor: Dictionary,
	world_rect: Rect2,
	art_size: float
) -> Rect2:
	if bounds_by_floor.is_empty() or not world_rect.has_area():
		return Rect2()
	var minimum_y := INF
	var maximum_y := -INF
	for bounds_value in bounds_by_floor.values():
		var bounds := bounds_value as Vector2
		minimum_y = minf(minimum_y, bounds.x)
		maximum_y = maxf(maximum_y, bounds.y)
	var vertical_padding := maxf(art_size * 1.35, 20.0)
	var top := maxf(world_rect.position.y, minimum_y - vertical_padding)
	var bottom := minf(world_rect.end.y, maximum_y + vertical_padding)
	if bottom <= top + 0.001:
		return Rect2()
	return Rect2(
		Vector2(world_rect.position.x, top),
		Vector2(world_rect.size.x, bottom - top)
	)


static func _build_boundary_by_revealed_floor(
	floor_numbers: Array,
	bounds_by_floor: Dictionary,
	wall_rect: Rect2
) -> Dictionary:
	var result: Dictionary = {0: wall_rect.end.y}
	for index in range(floor_numbers.size()):
		var floor_number := int(floor_numbers[index])
		if index >= floor_numbers.size() - 1:
			result[floor_number] = wall_rect.position.y
			continue
		var public_bounds: Vector2 = bounds_by_floor[floor_number]
		var next_floor_number := int(floor_numbers[index + 1])
		var locked_bounds: Vector2 = bounds_by_floor[next_floor_number]
		result[floor_number] = clampf(
			(public_bounds.x + locked_bounds.y) * 0.5,
			wall_rect.position.y,
			wall_rect.end.y
		)
	return result


static func _build_floor_spans(
	floor_numbers: Array,
	boundary_by_revealed_floor: Dictionary,
	wall_rect: Rect2
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lower_boundary := wall_rect.end.y
	for floor_value in floor_numbers:
		var floor_number := int(floor_value)
		var upper_boundary := float(boundary_by_revealed_floor.get(
			floor_number,
			wall_rect.position.y
		))
		result.append({
			"floor": floor_number,
			"floor_rect": Rect2(
				Vector2(wall_rect.position.x, upper_boundary),
				Vector2(wall_rect.size.x, maxf(0.0, lower_boundary - upper_boundary))
			),
		})
		lower_boundary = upper_boundary
	return result


static func _boundary_y_for_revealed_floor(
	floor_numbers: Array,
	boundary_by_revealed_floor: Dictionary,
	revealed_floor: int,
	wall_rect: Rect2
) -> float:
	if revealed_floor <= 0:
		return float(boundary_by_revealed_floor.get(0, wall_rect.end.y))
	var resolved_boundary := wall_rect.end.y
	for floor_value in floor_numbers:
		var floor_number := int(floor_value)
		if floor_number > revealed_floor:
			break
		resolved_boundary = float(boundary_by_revealed_floor.get(
			floor_number,
			resolved_boundary
		))
	return resolved_boundary
