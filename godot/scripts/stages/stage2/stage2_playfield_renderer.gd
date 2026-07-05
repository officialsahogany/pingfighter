extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")

const CENTER_SOURCE_PATH := "res://assets/sprites/hud/stage2_center_field_flat_imagegen_v1_source.png"
const CENTER_FALLBACK_PATH := "res://assets/sprites/hud/stage2_center_field_flat_imagegen_v1.png"
const BUSH_ATLAS_PATH := "res://assets/sprites/hud/stage2_bush_clump_atlas_imagegen_v3.png"
const VINE_ATLAS_PATH := "res://assets/sprites/hud/stage2_ingame_boss_vines_imagegen_v2.png"

const LOGICAL_SIZE := Vector2(600.0, 750.0)
const BUSH_RUSTLE_RANGE := 150.0
const BUSH_RUSTLE_NORMAL := 8.0
const BUSH_RUSTLE_DASH := 15.0
const VINE_RUSTLE_RANGE := 120.0
const VINE_RUSTLE_NORMAL := 7.0
const VINE_RUSTLE_DASH := 12.0
const VINE_RUSTLE_STRIP_COUNT := 1
const VINE_RENDER_STRIDE_SEVERE_LOD := 1
const ENABLE_STATIC_BUSH_CLUSTER_CACHE := false
const MAX_BUSH_TEXTURE_CLUSTERS_PER_BUSH := 3
const BUSH_RENDER_STRIDE_SEVERE_LOD := 1
const BUSH_CLUSTER_RENDER_STRIDE_SEVERE_LOD := 2
const PLAYER_BUSH_TEXTURE_CLUSTER_BONUS := 1
const FALLING_LEAF_RENDER_LIMIT := 8
const FALLING_LEAF_RENDER_LIMIT_SEVERE_LOD := 6
const ELLIPSE_SEGMENTS := 32
const ELLIPSE_OUTLINE_SEGMENTS := 64
const ELLIPSE_ARC_SEGMENTS := 28
const LOD_ACTIVE_THRESHOLD := 0.85
const SEVERE_LOD_ACTIVE_THRESHOLD := 0.66
const PERF_LOG_ENV := "PINGFIGHTER_STAGE2_PERF_LOG"
const PERF_LOG_FLAG_PATH := "res://stage2_perf_log.flag"
const PERF_LOG_INTERVAL_SEC := 0.75

const BUSH_SPECS := [
	{"x": 50.0, "y": 40.0, "size": "large", "variant": 0, "area": "boss"},
	{"x": 550.0, "y": 35.0, "size": "medium", "variant": 1, "area": "boss"},
	{"x": 25.0, "y": 80.0, "size": "small", "variant": 2, "area": "boss"},
	{"x": 575.0, "y": 75.0, "size": "medium", "variant": 0, "area": "boss"},
	{"x": 100.0, "y": 25.0, "size": "small", "variant": 1, "area": "boss"},
	{"x": 500.0, "y": 20.0, "size": "large", "variant": 2, "area": "boss"},
	{"x": 50.0, "y": 715.0, "size": "medium", "variant": 1, "area": "player"},
	{"x": 550.0, "y": 710.0, "size": "large", "variant": 0, "area": "player"},
	{"x": 25.0, "y": 690.0, "size": "small", "variant": 2, "area": "player"},
	{"x": 575.0, "y": 695.0, "size": "medium", "variant": 1, "area": "player"},
	{"x": 100.0, "y": 730.0, "size": "small", "variant": 0, "area": "player"},
	{"x": 500.0, "y": 710.0, "size": "large", "variant": 2, "area": "player"},
]

const VINE_SPECS := [
	{"x": 55.0, "length": 155.0, "sprite_index": 0},
	{"x": 150.0, "length": 135.0, "sprite_index": 1},
	{"x": 255.0, "length": 165.0, "sprite_index": 2},
	{"x": 350.0, "length": 140.0, "sprite_index": 3},
	{"x": 460.0, "length": 185.0, "sprite_index": 4},
	{"x": 545.0, "length": 130.0, "sprite_index": 5},
]

# Fixed Stage 2 imagegen atlases use measured alpha bounds to avoid first-entry pixel scans.
const BUSH_SOURCE_REGION_DATA := [
	Rect2(32.0, 38.0, 260.0, 246.0),
	Rect2(335.0, 41.0, 279.0, 232.0),
	Rect2(652.0, 52.0, 261.0, 232.0),
	Rect2(947.0, 42.0, 284.0, 240.0),
	Rect2(20.0, 347.0, 277.0, 232.0),
	Rect2(338.0, 360.0, 272.0, 221.0),
	Rect2(648.0, 352.0, 261.0, 241.0),
	Rect2(947.0, 352.0, 284.0, 243.0),
	Rect2(27.0, 656.0, 266.0, 238.0),
	Rect2(330.0, 674.0, 277.0, 230.0),
	Rect2(636.0, 675.0, 274.0, 216.0),
	Rect2(949.0, 672.0, 283.0, 218.0),
	Rect2(28.0, 976.0, 265.0, 216.0),
	Rect2(335.0, 961.0, 267.0, 233.0),
	Rect2(644.0, 971.0, 262.0, 221.0),
	Rect2(943.0, 967.0, 281.0, 227.0),
]
const VINE_SOURCE_REGION_DATA := [
	Rect2(62.0, 27.0, 254.0, 650.0),
	Rect2(392.0, 31.0, 271.0, 609.0),
	Rect2(763.0, 31.0, 223.0, 629.0),
	Rect2(1108.0, 28.0, 257.0, 631.0),
	Rect2(1474.0, 31.0, 241.0, 521.0),
	Rect2(1826.0, 30.0, 232.0, 630.0),
]
const BUSH_LEAF_PALETTE := [
	Color(42.0 / 255.0, 102.0 / 255.0, 38.0 / 255.0, 235.0 / 255.0),
	Color(52.0 / 255.0, 122.0 / 255.0, 48.0 / 255.0, 235.0 / 255.0),
	Color(62.0 / 255.0, 142.0 / 255.0, 55.0 / 255.0, 235.0 / 255.0),
	Color(38.0 / 255.0, 90.0 / 255.0, 35.0 / 255.0, 235.0 / 255.0),
	Color(55.0 / 255.0, 130.0 / 255.0, 45.0 / 255.0, 235.0 / 255.0),
	Color(45.0 / 255.0, 110.0 / 255.0, 50.0 / 255.0, 235.0 / 255.0),
]

var textures_loaded := false
var center_source_load_attempted := false
var center_fallback_load_attempted := false
var bush_load_attempted := false
var vine_load_attempted := false
var center_source_texture: Texture2D = null
var center_fallback_texture: Texture2D = null
var bush_texture: Texture2D = null
var vine_texture: Texture2D = null
var bush_source_image: Image = null
var bush_source_regions: Array = []
var vine_source_regions: Array = []

var layout_ready := false
var bushes: Array = []
var vines: Array = []
var falling_leaves: Array = []
var rng := RandomNumberGenerator.new()

var last_update_msec := 0
var time_sec := 0.0
var boss_center_valid := false
var player_center_valid := false
var previous_boss_center_x := LOGICAL_SIZE.x * 0.5
var previous_player_center_x := LOGICAL_SIZE.x * 0.5
var ellipse_unit_point_cache := {}
var perf_log_checked := false
var perf_log_enabled := false
var perf_log_next_msec := 0
var perf_samples := {}
var prewarm_done := false
var prewarm_step_index := 0


func draw(canvas: CanvasItem, context: Dictionary, _shake_offset: Vector2, perf_logger: Object = null) -> void:
	var draw_start := _perf_begin()
	if canvas == null:
		return
	var prepare_start := _perf_begin()
	var battle_prepare_start := _battle_perf_begin(perf_logger)
	_ensure_textures()
	_ensure_layout()
	_perf_end("stage2_playfield_prepare", prepare_start)
	_battle_perf_end(perf_logger, "stage2.playfield.prepare", battle_prepare_start)

	var width: float = float(context.get("width", 760.0))
	var height: float = float(context.get("height", 750.0))
	if width <= 0.0 or height <= 0.0:
		_perf_end("stage2_playfield_draw", draw_start)
		return

	var scale_x: float = width / LOGICAL_SIZE.x
	var scale_y: float = height / LOGICAL_SIZE.y
	var quality_scale: float = _get_playfield_quality_scale(context)
	var delta: float = _tick_delta()
	var motion_start := _perf_begin()
	var battle_motion_start := _battle_perf_begin(perf_logger)
	_update_motion(delta, context, scale_x, scale_y)
	_perf_end("stage2_playfield_motion", motion_start)
	_battle_perf_end(perf_logger, "stage2.playfield.motion", battle_motion_start)

	var has_imagegen_base := center_source_texture != null or center_fallback_texture != null
	var base_start := _perf_begin()
	var battle_base_start := _battle_perf_begin(perf_logger)
	if center_source_texture != null:
		_draw_cover_texture(canvas, center_source_texture, Rect2(0.0, 0.0, width, height))
	elif center_fallback_texture != null:
		canvas.draw_texture_rect(center_fallback_texture, Rect2(0.0, 0.0, width, height), false)
	else:
		_draw_procedural_fallback(canvas, width, height)
	_perf_end("stage2_playfield_base", base_start)
	_battle_perf_end(perf_logger, "stage2.playfield.base", battle_base_start)

	if has_imagegen_base:
		var center_base_start := _perf_begin()
		var battle_center_base_start := _battle_perf_begin(perf_logger)
		_draw_center_stadium_base(canvas, width, height, scale_x, scale_y)
		_perf_end("stage2_playfield_center_base", center_base_start)
		_battle_perf_end(perf_logger, "stage2.playfield.center_base", battle_center_base_start)

	var vines_start := _perf_begin()
	var battle_vines_start := _battle_perf_begin(perf_logger)
	_draw_vines(canvas, scale_x, scale_y, quality_scale)
	_perf_end("stage2_playfield_vines", vines_start)
	_battle_perf_end(perf_logger, "stage2.playfield.vines", battle_vines_start)
	var bushes_start := _perf_begin()
	var battle_bushes_start := _battle_perf_begin(perf_logger)
	_draw_bushes(canvas, scale_x, scale_y, quality_scale)
	_perf_end("stage2_playfield_bushes", bushes_start)
	_battle_perf_end(perf_logger, "stage2.playfield.bushes", battle_bushes_start)

	var ring_rect := _center_ring_rect(scale_x, scale_y)
	var center := Vector2(LOGICAL_SIZE.x * 0.5 * scale_x, LOGICAL_SIZE.y * 0.5 * scale_y)
	var electric_start := _perf_begin()
	var battle_electric_start := _battle_perf_begin(perf_logger)
	_draw_stadium_electric_flow(canvas, width, center.x, center.y, ring_rect, quality_scale)
	_perf_end("stage2_playfield_electric", electric_start)
	_battle_perf_end(perf_logger, "stage2.playfield.electric", battle_electric_start)
	var face_start := _perf_begin()
	var battle_face_start := _battle_perf_begin(perf_logger)
	_draw_center_eyes_and_expression(canvas, context, scale_x, scale_y)
	_perf_end("stage2_playfield_face", face_start)
	_battle_perf_end(perf_logger, "stage2.playfield.face", battle_face_start)
	var leaves_start := _perf_begin()
	var battle_leaves_start := _battle_perf_begin(perf_logger)
	_draw_falling_leaves(canvas, scale_x, scale_y, quality_scale)
	_perf_end("stage2_playfield_leaves", leaves_start)
	_battle_perf_end(perf_logger, "stage2.playfield.leaves", battle_leaves_start)
	var rage_start := _perf_begin()
	var battle_rage_start := _battle_perf_begin(perf_logger)
	_draw_rage_tint(canvas, context, width, height)
	_perf_end("stage2_playfield_rage_tint", rage_start)
	_battle_perf_end(perf_logger, "stage2.playfield.rage_tint", battle_rage_start)
	_perf_end("stage2_playfield_draw", draw_start)
	_perf_maybe_log(context)


func get_imagegen_asset_status() -> Dictionary:
	_ensure_textures()
	return {
		"center_source": center_source_texture != null,
		"center_fallback": center_fallback_texture != null,
		"bush_atlas": bush_texture != null and not bush_source_regions.is_empty(),
		"vine_atlas": vine_texture != null and not vine_source_regions.is_empty(),
		"bush_sprite_count": bush_source_regions.size(),
		"vine_sprite_count": vine_source_regions.size(),
	}


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if prewarm_done:
		return true
	if textures_loaded and layout_ready:
		prewarm_done = true
		prewarm_step_index = 0
		return true
	match prewarm_step_index:
		0:
			_load_center_source_texture()
		1:
			_load_center_fallback_texture()
		2:
			_load_bush_texture()
		3:
			_load_vine_texture()
		4:
			_mark_textures_loaded_if_attempted()
			_ensure_layout()
		_:
			_mark_textures_loaded_if_attempted()
			_ensure_layout()
			prewarm_done = true
			prewarm_step_index = 0
			return true
	prewarm_step_index += 1
	if prewarm_step_index > 4:
		_mark_textures_loaded_if_attempted()
		if layout_ready:
			prewarm_done = true
			prewarm_step_index = 0
			return true
	return false


func get_layout_snapshot(_width: float = 760.0, _height: float = 750.0) -> Dictionary:
	_ensure_textures()
	_ensure_layout()
	return {
		"bush_count": bushes.size(),
		"vine_count": vines.size(),
		"falling_leaf_count": falling_leaves.size(),
		"falling_leaf_render_limit": FALLING_LEAF_RENDER_LIMIT,
		"falling_leaf_render_limit_severe_lod": FALLING_LEAF_RENDER_LIMIT_SEVERE_LOD,
		"bush_draw_cluster_count": _count_bush_draw_clusters(),
		"max_bush_texture_clusters_per_bush": MAX_BUSH_TEXTURE_CLUSTERS_PER_BUSH,
		"bush_render_stride_severe_lod": BUSH_RENDER_STRIDE_SEVERE_LOD,
		"bush_cluster_render_stride_severe_lod": BUSH_CLUSTER_RENDER_STRIDE_SEVERE_LOD,
		"vine_render_stride_severe_lod": VINE_RENDER_STRIDE_SEVERE_LOD,
		"player_bush_texture_cluster_bonus": PLAYER_BUSH_TEXTURE_CLUSTER_BONUS,
		"bush_sprite_count": bush_source_regions.size(),
		"vine_sprite_count": vine_source_regions.size(),
	}


func _ensure_textures() -> void:
	if textures_loaded:
		return
	_load_center_source_texture()
	_load_center_fallback_texture()
	_load_bush_texture()
	_load_vine_texture()
	_mark_textures_loaded_if_attempted()


func _load_center_source_texture() -> void:
	if center_source_load_attempted:
		return
	center_source_load_attempted = true
	center_source_texture = ProjectResourceLoader.load_texture(CENTER_SOURCE_PATH)


func _load_center_fallback_texture() -> void:
	if center_fallback_load_attempted:
		return
	center_fallback_load_attempted = true
	center_fallback_texture = ProjectResourceLoader.load_texture(CENTER_FALLBACK_PATH)


func _load_bush_texture() -> void:
	if bush_load_attempted:
		return
	bush_load_attempted = true
	bush_texture = ProjectResourceLoader.load_texture(BUSH_ATLAS_PATH)
	if bush_texture != null:
		bush_source_regions = BUSH_SOURCE_REGION_DATA.duplicate()
		if ENABLE_STATIC_BUSH_CLUSTER_CACHE:
			bush_source_image = bush_texture.get_image()
			if bush_source_image != null and not bush_source_image.is_empty():
				bush_source_image.convert(Image.FORMAT_RGBA8)
	else:
		bush_source_regions.clear()


func _load_vine_texture() -> void:
	if vine_load_attempted:
		return
	vine_load_attempted = true
	vine_texture = ProjectResourceLoader.load_texture(VINE_ATLAS_PATH)
	if vine_texture != null:
		vine_source_regions = VINE_SOURCE_REGION_DATA.duplicate()
	else:
		vine_source_regions.clear()


func _mark_textures_loaded_if_attempted() -> void:
	textures_loaded = (
		center_source_load_attempted
		and center_fallback_load_attempted
		and bush_load_attempted
		and vine_load_attempted
	)


func _ensure_layout() -> void:
	if layout_ready:
		return
	layout_ready = true
	rng.seed = 2002
	bushes.clear()
	vines.clear()
	falling_leaves.clear()

	var size_map := {
		"small": 35.0,
		"medium": 50.0,
		"large": 70.0,
	}
	for spec in BUSH_SPECS:
		var base_size: float = float(size_map.get(str(spec["size"]), 50.0))
		var variant: int = int(spec["variant"])
		var area: String = str(spec["area"])
		var clusters: Array = _generate_bush_clusters(base_size, variant, area)
		var bush := {
			"x": float(spec["x"]),
			"y": float(spec["y"]),
			"base_size": base_size,
			"variant": variant,
			"area": area,
			"rustle_amount": 0.0,
			"rustle_angle": 0.0,
			"clusters": clusters,
			"draw_clusters": _build_bush_draw_clusters(clusters, base_size, variant, area),
			"leaves": _generate_bush_leaf_dots(base_size, variant, area),
		}
		bush["static_cluster_cache"] = _build_static_bush_cluster_cache(bush) if ENABLE_STATIC_BUSH_CLUSTER_CACHE else {}
		bushes.append(bush)

	for spec in VINE_SPECS:
		vines.append({
			"x": float(spec["x"]),
			"base_y": -8.0,
			"length": float(spec["length"]),
			"thickness": 4.0,
			"sprite_index": int(spec["sprite_index"]),
			"rustle_amount": 0.0,
			"rustle_angle": 0.0,
			"rustle_phase": 0.0,
			"segments": _generate_vine_segments(int(spec["sprite_index"])),
		})

	var leaf_types := ["maple", "oak", "tropical"]
	var leaf_colors := [
		Color(34.0 / 255.0, 139.0 / 255.0, 34.0 / 255.0, 1.0),
		Color(0.0, 128.0 / 255.0, 0.0, 1.0),
		Color(85.0 / 255.0, 107.0 / 255.0, 47.0 / 255.0, 1.0),
		Color(107.0 / 255.0, 142.0 / 255.0, 35.0 / 255.0, 1.0),
		Color(154.0 / 255.0, 205.0 / 255.0, 50.0 / 255.0, 1.0),
	]
	for _idx in range(8):
		var side := "left" if rng.randf() < 0.5 else "right"
		var x: float = rng.randf_range(0.0, 80.0) if side == "left" else rng.randf_range(LOGICAL_SIZE.x - 80.0, LOGICAL_SIZE.x)
		falling_leaves.append({
			"x": x,
			"y": rng.randf_range(-100.0, 0.0),
			"speed": rng.randf_range(0.5, 2.0),
			"sway": rng.randf_range(0.0, TAU),
			"rotation": rng.randf_range(0.0, TAU),
			"rotation_speed": rng.randf_range(-3.0, 3.0),
			"size": rng.randf_range(8.0, 15.0),
			"type": leaf_types[rng.randi_range(0, leaf_types.size() - 1)],
			"color": leaf_colors[rng.randi_range(0, leaf_colors.size() - 1)],
			"side": side,
			"z_depth": rng.randf_range(0.5, 1.0),
		})


func _generate_bush_clusters(base_size: float, variant: int, area: String) -> Array:
	var clusters: Array = []
	var cluster_count: int = (10 if area == "player" else 8) + (variant % 3)
	var density: float = 0.80 if area == "player" else 0.70
	clusters.append({
		"offset": Vector2.ZERO,
		"size": base_size * 0.70,
		"darkness": 0.85,
	})
	for idx in range(cluster_count):
		@warning_ignore("shadowed_global_identifier")
		var seed: float = base_size * 0.37 + float(variant) * 13.0 + float(idx) * 17.0 + (29.0 if area == "player" else 5.0)
		var angle: float = TAU * float(idx) / float(maxi(1, cluster_count)) + (_noise(seed) - 0.5) * 0.45
		var distance: float = (_noise(seed + 1.7) * 0.45 + 0.2) * base_size * density
		var size_factor: float = _noise(seed + 3.1) * 0.3 + 0.5
		var darkness_factor: float = _noise(seed + 4.6) * 0.3 + 0.65
		clusters.append({
			"offset": Vector2(cos(angle), sin(angle)) * distance,
			"size": base_size * size_factor,
			"darkness": darkness_factor,
		})
	return clusters


func _generate_bush_leaf_dots(base_size: float, variant: int, area: String) -> Array:
	var leaves: Array = []
	var count: int = (15 if area == "player" else 10) + (variant % (8 if area == "player" else 6))
	for idx in range(count):
		@warning_ignore("shadowed_global_identifier")
		var seed: float = base_size * 0.83 + float(variant) * 19.0 + float(idx) * 11.0 + (41.0 if area == "player" else 7.0)
		var angle: float = _noise(seed) * TAU
		var distance: float = (_noise(seed + 2.2) * 0.8 + 0.3) * base_size
		leaves.append({
			"offset": Vector2(cos(angle), sin(angle)) * distance,
			"size": 3.0 + floor(_noise(seed + 5.0) * (7.0 if area == "player" else 5.0)),
			"variant": int(floor(_noise(seed + 8.0) * 6.0)),
			"type": int(floor(_noise(seed + 10.0) * 3.0)),
		})
	return leaves


func _build_bush_draw_clusters(clusters: Array, base_size: float, variant: int, area: String) -> Array:
	if bush_source_regions.is_empty():
		return []
	var indexed_clusters: Array = []
	for idx in range(clusters.size()):
		var cluster: Dictionary = clusters[idx]
		var offset: Vector2 = _as_vector2(cluster.get("offset", Vector2.ZERO), Vector2.ZERO)
		indexed_clusters.append({
			"idx": idx,
			"cluster": cluster,
			"offset_y": offset.y,
			"size": float(cluster.get("size", 10.0)),
		})
	indexed_clusters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["offset_y"]) == float(b["offset_y"]):
			return float(a["size"]) < float(b["size"])
		return float(a["offset_y"]) < float(b["offset_y"])
	)

	var draw_clusters: Array = []
	var area_bonus := 2 if area == "player" else 0
	for item in _select_bush_draw_cluster_items(indexed_clusters, _get_bush_draw_cluster_limit(area)):
		var idx: int = int(item["idx"])
		var cluster: Dictionary = item["cluster"]
		var offset: Vector2 = _as_vector2(cluster.get("offset", Vector2.ZERO), Vector2.ZERO)
		var source_index: int = (variant * 5 + idx * 3 + area_bonus) % bush_source_regions.size()
		var source: Rect2 = bush_source_regions[source_index]
		var frontness: float = 0.55 + max(0.0, offset.y / max(1.0, base_size)) * 0.5
		var target_scale: float = 1.48 + 0.06 * float(idx % 3)
		if area == "player":
			target_scale *= 1.08
		draw_clusters.append({
			"idx": idx,
			"offset": offset,
			"source": source,
			"frontness": frontness,
			"size": float(cluster.get("size", 20.0)),
			"target_scale": target_scale,
		})
	return draw_clusters


func _get_bush_draw_cluster_limit(area: String) -> int:
	return MAX_BUSH_TEXTURE_CLUSTERS_PER_BUSH + (PLAYER_BUSH_TEXTURE_CLUSTER_BONUS if area == "player" else 0)


func _select_bush_draw_cluster_items(indexed_clusters: Array, render_limit: int) -> Array:
	if render_limit <= 0:
		return []
	if indexed_clusters.size() <= render_limit:
		return indexed_clusters
	var selected_items: Array = []
	var selected_indices := {}
	for item in indexed_clusters:
		if int(item.get("idx", -1)) != 0:
			continue
		selected_items.append(item)
		selected_indices[int(item["idx"])] = true
		break
	for item_index in range(indexed_clusters.size() - 1, -1, -1):
		if selected_items.size() >= render_limit:
			break
		var item: Dictionary = indexed_clusters[item_index]
		var cluster_index := int(item.get("idx", -1))
		if selected_indices.has(cluster_index):
			continue
		selected_items.append(item)
		selected_indices[cluster_index] = true
	selected_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["offset_y"]) == float(b["offset_y"]):
			return float(a["size"]) < float(b["size"])
		return float(a["offset_y"]) < float(b["offset_y"])
	)
	return selected_items


func _build_static_bush_cluster_cache(bush: Dictionary) -> Dictionary:
	if bush_source_image == null or bush_source_image.is_empty():
		return {}
	var draw_clusters: Array = bush.get("draw_clusters", []) if bush.get("draw_clusters", []) is Array else []
	if draw_clusters.is_empty():
		return {}

	var x: float = float(bush.get("x", 0.0))
	var y: float = float(bush.get("y", 0.0))
	var min_x := 0.0
	var min_y := 0.0
	var max_x := 0.0
	var max_y := 0.0
	var has_bounds := false
	var cluster_rects: Array = []
	for item in draw_clusters:
		var offset: Vector2 = _as_vector2(item.get("offset", Vector2.ZERO), Vector2.ZERO)
		var source: Rect2 = item.get("source", Rect2())
		if source.size.x <= 0.0 or source.size.y <= 0.0:
			continue
		var target_w: float = max(14.0, float(item.get("size", 20.0)) * float(item.get("target_scale", 1.48)))
		var target_h: float = max(8.0, target_w * source.size.y / max(1.0, source.size.x))
		var dest := Rect2(
			x + offset.x - target_w * 0.5,
			y + offset.y - target_h * 0.58,
			target_w,
			target_h
		)
		cluster_rects.append({"source": source, "dest": dest})
		if not has_bounds:
			min_x = dest.position.x
			min_y = dest.position.y
			max_x = dest.position.x + dest.size.x
			max_y = dest.position.y + dest.size.y
			has_bounds = true
		else:
			min_x = min(min_x, dest.position.x)
			min_y = min(min_y, dest.position.y)
			max_x = max(max_x, dest.position.x + dest.size.x)
			max_y = max(max_y, dest.position.y + dest.size.y)
	if not has_bounds:
		return {}

	var origin := Vector2(floor(min_x) - 2.0, floor(min_y) - 2.0)
	var cache_size := Vector2i(
		maxi(1, int(ceil(max_x - origin.x)) + 2),
		maxi(1, int(ceil(max_y - origin.y)) + 2)
	)
	var cache_image := Image.create_empty(cache_size.x, cache_size.y, false, Image.FORMAT_RGBA8)
	cache_image.fill(Color(0.0, 0.0, 0.0, 0.0))

	for entry in cluster_rects:
		var source: Rect2 = entry.get("source", Rect2())
		var dest: Rect2 = entry.get("dest", Rect2())
		var source_rect := Rect2i(
			Vector2i(int(round(source.position.x)), int(round(source.position.y))),
			Vector2i(maxi(1, int(round(source.size.x))), maxi(1, int(round(source.size.y))))
		)
		var dest_size := Vector2i(maxi(1, int(round(dest.size.x))), maxi(1, int(round(dest.size.y))))
		var source_image := Image.create_empty(source_rect.size.x, source_rect.size.y, false, Image.FORMAT_RGBA8)
		source_image.blit_rect(bush_source_image, source_rect, Vector2i.ZERO)
		source_image.resize(dest_size.x, dest_size.y, Image.INTERPOLATE_LANCZOS)
		cache_image.blend_rect(
			source_image,
			Rect2i(Vector2i.ZERO, dest_size),
			Vector2i(int(round(dest.position.x - origin.x)), int(round(dest.position.y - origin.y)))
		)

	var texture := ImageTexture.create_from_image(cache_image)
	if texture == null:
		return {}
	return {
		"texture": texture,
		"rect": Rect2(origin, Vector2(float(cache_size.x), float(cache_size.y))),
	}


func _generate_vine_segments(sprite_index: int) -> Array:
	var segments: Array = []
	for idx in range(10):
		@warning_ignore("shadowed_global_identifier")
		var seed: float = float(sprite_index * 31 + idx * 7)
		segments.append({
			"offset_x": (_noise(seed) - 0.5) * 10.0,
			"size": 0.8 + _noise(seed + 3.0) * 0.4,
		})
	return segments


func _tick_delta() -> float:
	var now: int = Time.get_ticks_msec()
	if last_update_msec <= 0:
		last_update_msec = now
		return 1.0 / 60.0
	var delta: float = clamp(float(now - last_update_msec) / 1000.0, 0.0, 0.05)
	last_update_msec = now
	if delta <= 0.0:
		delta = 1.0 / 60.0
	time_sec += delta
	return delta


func _update_motion(delta: float, context: Dictionary, scale_x: float, _scale_y: float) -> void:
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(float(context.get("boss_paddle_width", 110.0)), 18.0)), Vector2(110.0, 18.0))
	var boss_center_x: float = (boss_pos.x + boss_size.x * 0.5) / max(0.01, scale_x)
	if boss_center_valid:
		var boss_delta_x: float = boss_center_x - previous_boss_center_x
		if abs(boss_delta_x) > 2.0:
			var dash_like: bool = abs(boss_delta_x) > 15.0 or abs(float(context.get("boss_vel", 0.0))) > 10.0
			_trigger_bush_rustle("boss", boss_center_x, dash_like)
			_trigger_vine_rustle(boss_center_x, dash_like)
	previous_boss_center_x = boss_center_x
	boss_center_valid = true

	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	var player_center_x: float = (player_pos.x + player_size.x * 0.5) / max(0.01, scale_x)
	if player_center_valid:
		var player_delta_x: float = player_center_x - previous_player_center_x
		if abs(player_delta_x) > 2.0:
			var dash_snapshot: Dictionary = context.get("dash_snapshot", {}) if context.get("dash_snapshot", {}) is Dictionary else {}
			var player_dash_like: bool = abs(player_delta_x) > 15.0 or bool(dash_snapshot.get("active", false))
			_trigger_bush_rustle("player", player_center_x, player_dash_like)
	previous_player_center_x = player_center_x
	player_center_valid = true

	var bush_decay: float = pow(0.85, delta * 60.0)
	for idx in range(bushes.size()):
		var bush: Dictionary = bushes[idx]
		var amount: float = float(bush.get("rustle_amount", 0.0)) * bush_decay
		if amount < 0.5:
			amount = 0.0
			bush["rustle_angle"] = 0.0
		else:
			bush["rustle_angle"] = float(bush.get("rustle_angle", 0.0)) + 0.2 * delta * 60.0
		bush["rustle_amount"] = amount
		bushes[idx] = bush

	var vine_decay: float = pow(0.88, delta * 60.0)
	for idx in range(vines.size()):
		var vine: Dictionary = vines[idx]
		var amount: float = float(vine.get("rustle_amount", 0.0)) * vine_decay
		if amount < 0.18:
			amount = 0.0
			vine["rustle_angle"] = 0.0
			vine["rustle_phase"] = 0.0
		else:
			vine["rustle_phase"] = float(vine.get("rustle_phase", 0.0)) + clamp(delta * 13.2, 0.18, 0.55)
		vine["rustle_amount"] = amount
		vines[idx] = vine

	for idx in range(falling_leaves.size()):
		var leaf: Dictionary = falling_leaves[idx]
		var z: float = float(leaf.get("z_depth", 1.0))
		leaf["y"] = float(leaf.get("y", 0.0)) + float(leaf.get("speed", 1.0)) * z * delta * 60.0
		leaf["sway"] = float(leaf.get("sway", 0.0)) + 0.03 * delta * 60.0
		leaf["x"] = float(leaf.get("x", 0.0)) + sin(float(leaf.get("sway", 0.0))) * 1.5 * z * delta * 60.0
		leaf["rotation"] = float(leaf.get("rotation", 0.0)) + float(leaf.get("rotation_speed", 0.0)) * 0.0174533 * delta * 60.0
		if float(leaf.get("y", 0.0)) > LOGICAL_SIZE.y + 30.0:
			var side: String = str(leaf.get("side", "left"))
			leaf["y"] = rng.randf_range(-100.0, -20.0)
			leaf["rotation"] = rng.randf_range(0.0, TAU)
			leaf["x"] = rng.randf_range(0.0, 80.0) if side == "left" else rng.randf_range(LOGICAL_SIZE.x - 80.0, LOGICAL_SIZE.x)
		falling_leaves[idx] = leaf


func _trigger_bush_rustle(area: String, paddle_x: float, dash_like: bool) -> void:
	var base_rustle: float = BUSH_RUSTLE_DASH if dash_like else BUSH_RUSTLE_NORMAL
	var angle_multiplier: float = 0.6 if dash_like else 0.3
	for idx in range(bushes.size()):
		var bush: Dictionary = bushes[idx]
		if str(bush.get("area", "")) != area:
			continue
		var distance: float = abs(float(bush.get("x", 0.0)) - paddle_x)
		if distance >= BUSH_RUSTLE_RANGE:
			continue
		var distance_factor: float = (BUSH_RUSTLE_RANGE - distance) / BUSH_RUSTLE_RANGE
		bush["rustle_amount"] = distance_factor * base_rustle
		bush["rustle_angle"] = angle_multiplier if paddle_x > float(bush.get("x", 0.0)) else -angle_multiplier
		bushes[idx] = bush


func _trigger_vine_rustle(paddle_x: float, dash_like: bool) -> void:
	var base_rustle: float = VINE_RUSTLE_DASH if dash_like else VINE_RUSTLE_NORMAL
	var angle_multiplier: float = 0.62 if dash_like else 0.38
	for idx in range(vines.size()):
		var vine: Dictionary = vines[idx]
		var distance: float = abs(float(vine.get("x", 0.0)) - paddle_x)
		if distance >= VINE_RUSTLE_RANGE:
			continue
		var distance_factor: float = (VINE_RUSTLE_RANGE - distance) / VINE_RUSTLE_RANGE
		if float(vine.get("rustle_amount", 0.0)) <= 0.01:
			vine["rustle_phase"] = 0.0
		vine["rustle_amount"] = max(float(vine.get("rustle_amount", 0.0)), distance_factor * base_rustle)
		vine["rustle_angle"] = angle_multiplier if paddle_x > float(vine.get("x", 0.0)) else -angle_multiplier
		vines[idx] = vine


func _draw_cover_texture(canvas: CanvasItem, texture: Texture2D, dest: Rect2) -> void:
	if texture == null:
		return
	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var scale_factor: float = max(dest.size.x / source_size.x, dest.size.y / source_size.y)
	var visible_size := dest.size / scale_factor
	var source_pos := (source_size - visible_size) * 0.5
	var source := Rect2(source_pos, visible_size)
	canvas.draw_texture_rect_region(texture, dest, source, Color.WHITE, false, true)


func _draw_center_stadium_base(canvas: CanvasItem, width: float, _height: float, scale_x: float, scale_y: float) -> void:
	var cx: float = LOGICAL_SIZE.x * 0.5 * scale_x
	var cy: float = LOGICAL_SIZE.y * 0.5 * scale_y
	var s: float = max(0.7, min(scale_x, scale_y))
	var face_cy: float = cy + round(4.0 * scale_y)
	var head_rect := _centered_rect(Vector2(cx, face_cy), Vector2(round(194.0 * scale_x), round(132.0 * scale_y)))
	var ring_rect := head_rect.grow_individual(round(9.0 * scale_x), round(9.0 * scale_y), round(9.0 * scale_x), round(9.0 * scale_y))
	var line_width: float = max(2.0, round(3.0 * s))
	canvas.draw_line(Vector2(0.0, cy), Vector2(width, cy), _rgba255(11.0, 166.0, 85.0, 255.0), line_width + 2.0, true)
	canvas.draw_line(Vector2(0.0, cy), Vector2(width, cy), _rgba255(18.0, 220.0, 117.0, 255.0), line_width, true)
	_draw_ellipse(canvas, ring_rect, _rgba255(12.0, 30.0, 31.0, 255.0))
	_draw_ellipse_outline(canvas, ring_rect, _rgba255(18.0, 205.0, 106.0, 255.0), max(2.0, round(3.0 * s)))
	var inner_rect := ring_rect.grow(-18.0 * s)
	if inner_rect.size.x > 0.0 and inner_rect.size.y > 0.0:
		_draw_ellipse(canvas, inner_rect, _rgba255(12.0, 24.0, 27.0, 255.0))
	_draw_ellipse(canvas, head_rect, _rgba255(38.0, 96.0, 40.0, 255.0))
	var face_rect := _centered_rect(Vector2(cx, face_cy - round(9.0 * scale_y)), Vector2(round(148.0 * scale_x), round(88.0 * scale_y)))
	_draw_ellipse(canvas, face_rect, _rgba255(70.0, 152.0, 64.0, 255.0))
	var snout_rect := _centered_rect(Vector2(cx, face_cy + round(39.0 * scale_y)), Vector2(round(134.0 * scale_x), round(52.0 * scale_y)))
	_draw_ellipse(canvas, snout_rect, _rgba255(48.0, 128.0, 47.0, 255.0))
	var nose_r: float = max(4.0, round(9.0 * s))
	canvas.draw_circle(Vector2(cx, face_cy - round(7.0 * scale_y)), nose_r, _rgba255(0.0, 177.0, 94.0, 255.0))
	for spot_x in [-24.0, 0.0, 24.0]:
		canvas.draw_circle(Vector2(cx + spot_x * scale_x, face_cy - round(28.0 * scale_y)), max(2.0, round(3.0 * s)), _rgba255(42.0, 98.0, 45.0, 255.0))
	var eye_y: float = face_cy - round(18.0 * scale_y)
	var eye_r: float = max(3.0, round(6.0 * s))
	for eye_x in [cx - 29.0 * scale_x, cx + 29.0 * scale_x]:
		canvas.draw_circle(Vector2(eye_x, eye_y), eye_r, _rgba255(222.0, 211.0, 18.0, 255.0))
		canvas.draw_circle(Vector2(eye_x, eye_y), max(1.0, floor(eye_r * 0.5)), _rgba255(8.0, 26.0, 18.0, 255.0))
	var tooth_y: float = face_cy + round(48.0 * scale_y)
	var tooth_w: float = max(4.0, round(9.0 * scale_x))
	var tooth_h: float = max(6.0, round(13.0 * scale_y))
	var tooth_pitch: float = max(1.0, round(19.0 * scale_x))
	var tooth_start: float = cx - tooth_pitch * 2.5
	for idx in range(6):
		var x: float = tooth_start + float(idx) * tooth_pitch
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(x, tooth_y),
			Vector2(x + tooth_w, tooth_y),
			Vector2(x + tooth_w * 0.5, tooth_y - tooth_h),
		]), _rgba255(245.0, 248.0, 232.0, 255.0))
	_draw_ellipse_outline(canvas, ring_rect, _rgba255(18.0, 205.0, 106.0, 255.0), max(2.0, round(3.0 * s)))


func _draw_vines(canvas: CanvasItem, scale_x: float, scale_y: float, quality_scale: float) -> void:
	var stride: int = VINE_RENDER_STRIDE_SEVERE_LOD if _is_severe_lod_active(quality_scale) else 1
	for vine_index in range(vines.size()):
		if stride > 1 and vine_index % stride != 0:
			continue
		var vine: Dictionary = vines[vine_index]
		if not _draw_imagegen_vine(canvas, vine, scale_x, scale_y):
			_draw_procedural_vine(canvas, vine, scale_x, scale_y)


func _draw_imagegen_vine(canvas: CanvasItem, vine: Dictionary, scale_x: float, scale_y: float) -> bool:
	if vine_texture == null or vine_source_regions.is_empty():
		return false
	var sprite_index: int = int(vine.get("sprite_index", 0)) % vine_source_regions.size()
	var source: Rect2 = vine_source_regions[sprite_index]
	if source.size.x <= 0.0 or source.size.y <= 0.0:
		return false
	var target_h: float = max(1.0, float(vine.get("length", 120.0)) * scale_y)
	var target_w: float = max(1.0, source.size.x * target_h / max(1.0, source.size.y))
	var x: float = float(vine.get("x", 0.0)) * scale_x - target_w * 0.5
	var y: float = float(vine.get("base_y", 0.0)) * scale_y
	var rustle_amount: float = float(vine.get("rustle_amount", 0.0))
	if rustle_amount <= 0.05:
		canvas.draw_texture_rect_region(vine_texture, Rect2(x, y, target_w, target_h), source, Color.WHITE, false, true)
		return true

	var strip_h: float = max(2.0, target_h / float(VINE_RUSTLE_STRIP_COUNT))
	var sy := 0.0
	while sy < target_h:
		var h: float = min(strip_h, target_h - sy)
		var depth: float = sy / max(1.0, target_h - 1.0)
		var dx: float = _get_vine_rustle_dx(vine, depth, scale_x)
		var source_strip := Rect2(
			source.position + Vector2(0.0, source.size.y * sy / target_h),
			Vector2(source.size.x, source.size.y * h / target_h)
		)
		canvas.draw_texture_rect_region(vine_texture, Rect2(x + dx, y + sy, target_w, h), source_strip, Color.WHITE, false, true)
		sy += h
	return true


func _draw_procedural_vine(canvas: CanvasItem, vine: Dictionary, scale_x: float, scale_y: float) -> void:
	var x: float = float(vine.get("x", 0.0)) * scale_x
	var base_y: float = float(vine.get("base_y", 0.0)) * scale_y
	var length_scaled: float = float(vine.get("length", 120.0)) * scale_y
	var segments: Array = vine.get("segments", []) if vine.get("segments", []) is Array else []
	var points := PackedVector2Array()
	for idx in range(segments.size()):
		var depth: float = float(idx) / float(maxi(1, segments.size() - 1))
		var segment: Dictionary = segments[idx]
		var pos := Vector2(
			x + float(segment.get("offset_x", 0.0)) * scale_x + _get_vine_rustle_dx(vine, depth, scale_x),
			base_y + length_scaled * depth
		)
		points.append(pos)
		canvas.draw_circle(pos + Vector2(3.0, 3.0), max(1.0, 4.0 * min(scale_x, scale_y)), Color(0.0, 0.0, 0.0, 0.12))
		canvas.draw_circle(pos, max(1.0, 3.0 * min(scale_x, scale_y)), _rgba255(40.0, 95.0, 39.0, 230.0))
	if points.size() > 1:
		canvas.draw_polyline(points, _rgba255(38.0, 80.0, 38.0, 255.0), max(1.0, 4.0 * min(scale_x, scale_y)), true)


func _get_vine_rustle_dx(vine: Dictionary, depth: float, scale_x: float) -> float:
	var rustle_amount: float = float(vine.get("rustle_amount", 0.0))
	if rustle_amount <= 0.0:
		return 0.0
	var direction: float = 1.0 if float(vine.get("rustle_angle", 0.0)) >= 0.0 else -1.0
	var phase: float = float(vine.get("rustle_phase", 0.0))
	var envelope: float = pow(clamp(depth, 0.0, 1.0), 1.35)
	var amount: float = rustle_amount * scale_x
	var wave: float = sin(phase + depth * PI * 2.25) * amount * 0.48
	var drift: float = direction * amount * 0.30
	return (wave + drift) * envelope


func _draw_bushes(canvas: CanvasItem, scale_x: float, scale_y: float, quality_scale: float) -> void:
	var severe_lod_active := _is_severe_lod_active(quality_scale)
	var stride: int = BUSH_RENDER_STRIDE_SEVERE_LOD if severe_lod_active else 1
	for bush_index in range(bushes.size()):
		if stride > 1 and bush_index % stride != 0:
			continue
		var bush: Dictionary = bushes[bush_index]
		if not _draw_imagegen_bush(canvas, bush, scale_x, scale_y, severe_lod_active):
			_draw_procedural_bush(canvas, bush, scale_x, scale_y)


func _draw_imagegen_bush(canvas: CanvasItem, bush: Dictionary, scale_x: float, scale_y: float, severe_lod_active: bool = false) -> bool:
	if bush_texture == null or bush_source_regions.is_empty():
		return false
	var x: float = float(bush.get("x", 0.0)) * scale_x
	var y: float = float(bush.get("y", 0.0)) * scale_y
	var base_size: float = float(bush.get("base_size", 50.0)) * min(scale_x, scale_y)
	var rustle_amount: float = float(bush.get("rustle_amount", 0.0)) * min(scale_x, scale_y)
	var rustle_angle: float = float(bush.get("rustle_angle", 0.0))
	var global_rx: float = sin(rustle_angle) * rustle_amount
	var global_ry: float = cos(rustle_angle * 1.5) * rustle_amount * 0.3
	var shadow_w: float = base_size * 2.2
	var shadow_h: float = base_size * 0.8
	_draw_ellipse(canvas, Rect2(x - shadow_w * 0.5 + 6.0 + global_rx, y + base_size * 0.5 + 2.0 + global_ry, shadow_w, shadow_h), Color(0.02, 0.05, 0.02, 0.20))

	if rustle_amount <= 0.05:
		var static_cache: Dictionary = bush.get("static_cluster_cache", {}) if bush.get("static_cluster_cache", {}) is Dictionary else {}
		var texture_value: Variant = static_cache.get("texture", null)
		var rect_value: Variant = static_cache.get("rect", Rect2())
		if texture_value is Texture2D and rect_value is Rect2:
			var cached_texture: Texture2D = texture_value
			var cache_rect: Rect2 = rect_value
			canvas.draw_texture_rect(
				cached_texture,
				Rect2(
					cache_rect.position.x * scale_x,
					cache_rect.position.y * scale_y,
					cache_rect.size.x * scale_x,
					cache_rect.size.y * scale_y
				),
				false
			)
			return true

	var variant: int = int(bush.get("variant", 0))
	var draw_clusters: Array = bush.get("draw_clusters", []) if bush.get("draw_clusters", []) is Array else []
	var cluster_stride: int = BUSH_CLUSTER_RENDER_STRIDE_SEVERE_LOD if severe_lod_active else 1
	var cluster_draw_index := 0
	for item in draw_clusters:
		if cluster_stride > 1 and cluster_draw_index % cluster_stride != 0:
			cluster_draw_index += 1
			continue
		cluster_draw_index += 1
		var idx: int = int(item["idx"])
		var offset: Vector2 = _as_vector2(item.get("offset", Vector2.ZERO), Vector2.ZERO)
		var source: Rect2 = item.get("source", Rect2())
		if source.size.x <= 0.0 or source.size.y <= 0.0:
			continue
		var frontness: float = float(item.get("frontness", 0.55))
		var local_phase: float = rustle_angle * 2.1 + float(idx) * 0.73 + float(variant)
		var local_rx: float = global_rx * (0.32 + frontness * 0.72) + sin(local_phase) * rustle_amount * 0.28
		var local_ry: float = global_ry * (0.25 + frontness * 0.45) + cos(local_phase * 1.4) * rustle_amount * 0.08
		var target_w: float = float(item.get("size", 20.0)) * min(scale_x, scale_y) * float(item.get("target_scale", 1.48))
		target_w = max(14.0, target_w)
		var target_h: float = max(8.0, target_w * source.size.y / max(1.0, source.size.x))
		var dest := Rect2(
			x + offset.x * scale_x + local_rx - target_w * 0.5,
			y + offset.y * scale_y + local_ry - target_h * 0.58,
			target_w,
			target_h
		)
		canvas.draw_texture_rect_region(bush_texture, dest, source, Color.WHITE, false, true)

	return true


func _draw_procedural_bush(canvas: CanvasItem, bush: Dictionary, scale_x: float, scale_y: float) -> void:
	var x: float = float(bush.get("x", 0.0)) * scale_x
	var y: float = float(bush.get("y", 0.0)) * scale_y
	var base_size: float = float(bush.get("base_size", 50.0)) * min(scale_x, scale_y)
	var rustle_amount: float = float(bush.get("rustle_amount", 0.0)) * min(scale_x, scale_y)
	var rustle_angle: float = float(bush.get("rustle_angle", 0.0))
	var rx: float = sin(rustle_angle) * rustle_amount
	var ry: float = cos(rustle_angle * 1.5) * rustle_amount * 0.3
	_draw_ellipse(canvas, Rect2(x - base_size * 1.1 + rx, y + base_size * 0.38 + ry, base_size * 2.2, base_size * 0.76), Color(0.02, 0.05, 0.02, 0.20))
	for idx in range(7):
		var angle: float = TAU * float(idx) / 7.0
		var pos := Vector2(x + cos(angle) * base_size * 0.45 + rx, y + sin(angle) * base_size * 0.36 + ry)
		var radius := base_size * (0.32 + 0.08 * float(idx % 2))
		canvas.draw_circle(pos, radius, _rgba255(28.0 + float(idx % 3) * 8.0, 72.0 + float(idx % 3) * 10.0, 32.0, 238.0))
	canvas.draw_circle(Vector2(x + rx, y - base_size * 0.06 + ry), base_size * 0.42, _rgba255(48.0, 105.0, 42.0, 235.0))
	_draw_bush_leaf_dots(canvas, bush, scale_x, scale_y, rx, ry)


func _draw_bush_leaf_dots(canvas: CanvasItem, bush: Dictionary, scale_x: float, scale_y: float, rustle_x: float, rustle_y: float) -> void:
	var x: float = float(bush.get("x", 0.0)) * scale_x
	var y: float = float(bush.get("y", 0.0)) * scale_y
	var leaves: Array = bush.get("leaves", []) if bush.get("leaves", []) is Array else []
	for leaf in leaves:
		var offset: Vector2 = _as_vector2(leaf.get("offset", Vector2.ZERO), Vector2.ZERO)
		var size: float = max(1.0, float(leaf.get("size", 4.0)) * min(scale_x, scale_y))
		var pos := Vector2(x + offset.x * scale_x + rustle_x * 0.7, y + offset.y * scale_y + rustle_y * 0.7)
		var color: Color = BUSH_LEAF_PALETTE[int(leaf.get("variant", 0)) % BUSH_LEAF_PALETTE.size()]
		match int(leaf.get("type", 0)):
			0:
				_draw_ellipse(canvas, Rect2(pos.x - size * 0.5, pos.y - size * 0.25, size, size * 0.5), color)
			1:
				canvas.draw_colored_polygon(PackedVector2Array([
					pos + Vector2(0.0, -size * 0.6),
					pos + Vector2(size * 0.45, 0.0),
					pos + Vector2(0.0, size * 0.6),
					pos + Vector2(-size * 0.45, 0.0),
				]), color)
			_:
				canvas.draw_circle(pos, size * 0.45, color)


func _draw_stadium_electric_flow(canvas: CanvasItem, width: float, center_x: float, line_y: float, ring_rect: Rect2, _quality_scale: float) -> void:
	var cycle: float = fmod(time_sec, 18.0)
	if cycle > 0.85:
		return
	var pulse: float = cycle / 0.85
	var travel: float = pulse * pulse * (3.0 - 2.0 * pulse)
	var direction := -1.0 if int(floor(time_sec / 18.0)) % 2 == 1 else 1.0
	if direction < 0.0:
		travel = 1.0 - travel
	var head_x: float = width * travel
	var strength: float = sin(pulse * PI)
	var tail_len: float = max(42.0, width * 0.11)
	var line_start: float = max(0.0, head_x - tail_len) if direction > 0.0 else max(0.0, head_x - 6.0)
	var line_end: float = min(width, head_x + 6.0) if direction > 0.0 else min(width, head_x + tail_len)
	if line_end > line_start:
		canvas.draw_line(Vector2(line_start, line_y), Vector2(line_end, line_y), Color(42.0 / 255.0, 214.0 / 255.0, 214.0 / 255.0, 0.14 + 0.23 * strength), 5.0, true)
		canvas.draw_line(Vector2(line_start, line_y + 1.0), Vector2(line_end, line_y + 1.0), Color(106.0 / 255.0, 240.0 / 255.0, 174.0 / 255.0, 0.10 + 0.15 * strength), 2.0, true)
		canvas.draw_line(Vector2(line_start, line_y - 1.0), Vector2(line_end, line_y - 1.0), Color(235.0 / 255.0, 1.0, 244.0 / 255.0, 0.18 + 0.24 * strength), 1.0, true)
	var radius_x: float = max(1.0, ring_rect.size.x * 0.5)
	var normalized_offset: float = abs(head_x - center_x) / radius_x
	if normalized_offset > 1.22:
		return
	var circle_strength: float = max(0.0, 1.0 - normalized_offset / 1.22) * strength
	if circle_strength <= 0.02:
		return
	var circle_progress: float = clamp((head_x - (center_x - radius_x)) / (radius_x * 2.0), 0.0, 1.0)
	var upper_angle: float = PI - circle_progress * PI if direction > 0.0 else (1.0 - circle_progress) * PI
	var lower_angle: float = PI + circle_progress * PI if direction > 0.0 else -(1.0 - circle_progress) * PI
	var arc_span: float = 0.22 + 0.10 * circle_strength
	for angle in [upper_angle, lower_angle]:
		_draw_ellipse_arc(canvas, ring_rect, angle - arc_span, angle + arc_span, Color(42.0 / 255.0, 214.0 / 255.0, 214.0 / 255.0, 0.18 + 0.30 * circle_strength), 3.0)
		_draw_ellipse_arc(canvas, ring_rect, angle - arc_span * 0.56, angle + arc_span * 0.56, Color(235.0 / 255.0, 1.0, 244.0 / 255.0, 0.25 + 0.36 * circle_strength), 1.0)


func _draw_center_eyes_and_expression(canvas: CanvasItem, context: Dictionary, scale_x: float, scale_y: float) -> void:
	var center_x: float = LOGICAL_SIZE.x * 0.5 * scale_x
	var center_y: float = LOGICAL_SIZE.y * 0.5 * scale_y
	var left_eye_x: float = center_x - 27.0 * scale_x
	var right_eye_x: float = center_x + 27.0 * scale_x
	var eye_y: float = center_y - 12.0 * scale_y
	var eye_radius := 12.0
	var pupil_radius := 5.0
	var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", Vector2(center_x, center_y)), Vector2(center_x, center_y))
	for eye_x in [left_eye_x, right_eye_x]:
		canvas.draw_circle(Vector2(eye_x, eye_y), eye_radius, Color.WHITE)
		canvas.draw_arc(Vector2(eye_x, eye_y), eye_radius, 0.0, TAU, 32, _rgba255(0.0, 50.0, 0.0, 255.0), 2.0, true)
		var pupil_offset := _calculate_pupil_offset(Vector2(eye_x, eye_y), ball_pos, eye_radius, pupil_radius)
		var pupil_pos := Vector2(eye_x, eye_y) + pupil_offset
		canvas.draw_circle(pupil_pos, pupil_radius, Color.BLACK)
		canvas.draw_circle(pupil_pos + Vector2(-2.0, -2.0), 2.0, Color.WHITE)

	var expression: String = str(context.get("stage2_boss_expression", "neutral"))
	var mouth_y: float = center_y + 20.0 * scale_y
	var mouth_scale: float = min(scale_x, scale_y)
	if expression == "happy":
		var arc_rect := _centered_rect(Vector2(center_x, mouth_y + 10.0 * scale_y), Vector2(60.0 * scale_x, 40.0 * scale_y))
		_draw_ellipse_arc(canvas, arc_rect, 0.0, PI, Color.BLACK, max(1.0, 8.0 * mouth_scale))
		_draw_ellipse(canvas, _centered_rect(Vector2(center_x, mouth_y + 10.0 * scale_y), Vector2(50.0 * scale_x, 20.0 * scale_y)), _rgba255(200.0, 50.0, 50.0, 255.0))
		for idx in range(4):
			var tooth_x: float = center_x - 15.0 * scale_x + float(idx) * 10.0 * scale_x
			canvas.draw_rect(Rect2(tooth_x, mouth_y, 8.0 * scale_x, 10.0 * scale_y), Color.WHITE)
		for eye_x in [left_eye_x, right_eye_x]:
			var eye_arc_rect := Rect2(eye_x - eye_radius, eye_y - eye_radius - 5.0 * scale_y, eye_radius * 2.0, eye_radius * 2.0)
			_draw_ellipse_arc(canvas, eye_arc_rect, 0.0, PI, Color.BLACK, 3.0)
	elif expression == "sad":
		var sad_rect := _centered_rect(Vector2(center_x, mouth_y + 10.0 * scale_y), Vector2(50.0 * scale_x, 30.0 * scale_y))
		_draw_ellipse_arc(canvas, sad_rect, PI * 0.2, PI * 0.8, Color.BLACK, max(1.0, 5.0 * mouth_scale))
		for tear_x in [left_eye_x, right_eye_x]:
			var tear_y: float = eye_y + eye_radius + 5.0 * scale_y
			canvas.draw_circle(Vector2(tear_x, tear_y), max(2.0, 4.0 * mouth_scale), _rgba255(100.0, 150.0, 255.0, 220.0))
			canvas.draw_circle(Vector2(tear_x, tear_y + 8.0 * scale_y), max(2.0, 3.0 * mouth_scale), _rgba255(150.0, 200.0, 255.0, 190.0))
			canvas.draw_circle(Vector2(tear_x, tear_y + 14.0 * scale_y), max(1.0, 2.0 * mouth_scale), _rgba255(200.0, 220.0, 255.0, 160.0))
		var brow_offset: float = 15.0 * scale_x
		var brow_y_offset: float = 20.0 * scale_y
		canvas.draw_line(Vector2(left_eye_x - brow_offset, eye_y - brow_y_offset), Vector2(left_eye_x + 10.0 * scale_x, eye_y - 25.0 * scale_y), _rgba255(0.0, 50.0, 0.0, 255.0), 3.0, true)
		canvas.draw_line(Vector2(right_eye_x - 10.0 * scale_x, eye_y - 25.0 * scale_y), Vector2(right_eye_x + brow_offset, eye_y - brow_y_offset), _rgba255(0.0, 50.0, 0.0, 255.0), 3.0, true)

	var pulse: float = sin(time_sec * 3.0) * 0.5 + 0.5
	if pulse > 0.95:
		for eye_x in [left_eye_x, right_eye_x]:
			canvas.draw_circle(Vector2(eye_x, eye_y), eye_radius + 5.0, _rgba255(255.0, 255.0, 100.0, 60.0))


func _calculate_pupil_offset(eye_pos: Vector2, ball_pos: Vector2, eye_radius: float, pupil_radius: float) -> Vector2:
	var delta := ball_pos - eye_pos
	var distance: float = delta.length()
	if distance <= 0.001:
		return Vector2.ZERO
	var max_distance: float = eye_radius - pupil_radius - 2.0
	return delta.normalized() * min(max_distance, distance * 0.05)


func _draw_falling_leaves(canvas: CanvasItem, scale_x: float, scale_y: float, quality_scale: float) -> void:
	var render_limit: int = _get_lod_count(
		FALLING_LEAF_RENDER_LIMIT,
		FALLING_LEAF_RENDER_LIMIT,
		FALLING_LEAF_RENDER_LIMIT_SEVERE_LOD,
		quality_scale
	)
	if render_limit <= 0:
		return
	var start_index := maxi(0, falling_leaves.size() - render_limit)
	for leaf_index in range(start_index, falling_leaves.size()):
		var leaf: Dictionary = falling_leaves[leaf_index]
		var pos := Vector2(float(leaf.get("x", 0.0)) * scale_x, float(leaf.get("y", 0.0)) * scale_y)
		var size: float = float(leaf.get("size", 10.0)) * min(scale_x, scale_y)
		var rot: float = float(leaf.get("rotation", 0.0))
		var color: Color = leaf.get("color", _rgba255(34.0, 139.0, 34.0, 255.0))
		color.a = clamp(float(leaf.get("z_depth", 1.0)), 0.35, 1.0)
		var leaf_type: String = str(leaf.get("type", "tropical"))
		_draw_detailed_leaf(canvas, pos, size, leaf_type, color, rot)


func _draw_detailed_leaf(canvas: CanvasItem, pos: Vector2, size: float, leaf_type: String, color: Color, rotation: float) -> void:
	var forward := Vector2(cos(rotation), sin(rotation))
	var side := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array()
	if leaf_type == "maple":
		for idx in range(10):
			var angle: float = rotation + float(idx) * TAU / 10.0
			var radius: float = size * (1.15 if idx % 2 == 0 else 0.52)
			points.append(pos + Vector2(cos(angle), sin(angle)) * radius)
	elif leaf_type == "oak":
		points = PackedVector2Array([
			pos + forward * size,
			pos + side * size * 0.46,
			pos - forward * size,
			pos - side * size * 0.46,
		])
	else:
		points = PackedVector2Array([
			pos + forward * size * 1.25,
			pos + forward * size * 0.25 + side * size * 0.46,
			pos - forward * size * 1.25,
			pos + forward * size * 0.25 - side * size * 0.46,
		])
	canvas.draw_colored_polygon(points, Color(color.r * 0.28, color.g * 0.28, color.b * 0.28, color.a * 0.18))
	for idx in range(points.size()):
		points[idx] = points[idx] - Vector2(2.0, 2.0)
	canvas.draw_colored_polygon(points, color)
	canvas.draw_line(pos - forward * size * 0.65, pos + forward * size * 0.75, Color(min(1.0, color.r + 0.12), min(1.0, color.g + 0.12), min(1.0, color.b + 0.08), color.a * 0.75), 1.0, true)


func _draw_rage_tint(canvas: CanvasItem, context: Dictionary, width: float, height: float) -> void:
	var rage_tint: float = clamp(float(context.get("stage2_boss_rage_tint", 0.0)), 0.0, 1.0)
	if rage_tint <= 0.0:
		return
	canvas.draw_rect(Rect2(0.0, 0.0, width, height), Color(1.0, 0.0, 0.0, min(0.22, 0.20 * rage_tint)))


func _draw_procedural_fallback(canvas: CanvasItem, width: float, height: float) -> void:
	canvas.draw_rect(Rect2(0.0, 0.0, width, height), Color(0.045, 0.105, 0.075, 1.0))
	for band in range(11):
		var y: float = float(band) * height / 11.0
		canvas.draw_rect(Rect2(0.0, y, width, height / 11.0 + 1.0), Color(0.04 + float(band % 3) * 0.012, 0.13 + float(band % 2) * 0.018, 0.078, 0.22))
	var center := Vector2(width * 0.5, height * 0.5)
	canvas.draw_line(Vector2(0.0, center.y + 1.0), Vector2(width, center.y + 1.0), Color(0.01, 0.03, 0.02, 0.42), 4.0, true)
	canvas.draw_line(Vector2(0.0, center.y), Vector2(width, center.y), Color(0.45, 0.58, 0.28, 0.70), 2.0, true)
	canvas.draw_arc(center, 94.0, 0.0, TAU, 96, Color(0.42, 0.55, 0.24, 0.62), 3.0, true)
	canvas.draw_arc(center, 104.0, 0.0, TAU, 96, Color(0.02, 0.07, 0.04, 0.40), 2.0, true)


func _center_ring_rect(scale_x: float, scale_y: float) -> Rect2:
	var cx: float = LOGICAL_SIZE.x * 0.5 * scale_x
	var cy: float = LOGICAL_SIZE.y * 0.5 * scale_y
	var face_cy: float = cy + round(4.0 * scale_y)
	var head_rect := _centered_rect(Vector2(cx, face_cy), Vector2(round(194.0 * scale_x), round(132.0 * scale_y)))
	return head_rect.grow_individual(round(9.0 * scale_x), round(9.0 * scale_y), round(9.0 * scale_x), round(9.0 * scale_y))


func _centered_rect(center: Vector2, size: Vector2) -> Rect2:
	return Rect2(center - size * 0.5, size)


func _draw_ellipse(canvas: CanvasItem, rect: Rect2, color: Color, segments: int = ELLIPSE_SEGMENTS) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	canvas.draw_colored_polygon(_ellipse_points(rect, segments), color)


func _draw_ellipse_outline(canvas: CanvasItem, rect: Rect2, color: Color, width: float, segments: int = ELLIPSE_OUTLINE_SEGMENTS) -> void:
	var points := _ellipse_points(rect, segments)
	if points.size() <= 2:
		return
	points.append(points[0])
	canvas.draw_polyline(points, color, width, true)


func _draw_ellipse_arc(canvas: CanvasItem, rect: Rect2, start_angle: float, end_angle: float, color: Color, width: float, segments: int = ELLIPSE_ARC_SEGMENTS) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius: Vector2 = rect.size * 0.5
	var span: float = end_angle - start_angle
	var count: int = maxi(4, segments)
	for idx in range(count + 1):
		var t: float = float(idx) / float(count)
		var angle: float = start_angle + span * t
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	canvas.draw_polyline(points, color, width, true)


func _ellipse_points(rect: Rect2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius: Vector2 = rect.size * 0.5
	var unit_points: PackedVector2Array = _get_ellipse_unit_points(segments)
	for point in unit_points:
		points.append(center + Vector2(point.x * radius.x, point.y * radius.y))
	return points


func _get_ellipse_unit_points(segments: int) -> PackedVector2Array:
	var count: int = maxi(8, segments)
	if ellipse_unit_point_cache.has(count):
		return ellipse_unit_point_cache[count]
	var points := PackedVector2Array()
	for idx in range(count):
		var angle: float = TAU * float(idx) / float(count)
		points.append(Vector2(cos(angle), sin(angle)))
	ellipse_unit_point_cache[count] = points
	return points


func _get_playfield_quality_scale(context: Dictionary) -> float:
	return BattleRenderQuality.effect_scale(context)


func _is_lod_active(quality_scale: float) -> bool:
	return quality_scale < LOD_ACTIVE_THRESHOLD


func _is_severe_lod_active(quality_scale: float) -> bool:
	return quality_scale < SEVERE_LOD_ACTIVE_THRESHOLD


func _get_lod_count(base_count: int, lod_count: int, severe_lod_count: int, quality_scale: float) -> int:
	if _is_severe_lod_active(quality_scale):
		return max(0, min(base_count, severe_lod_count))
	if not _is_lod_active(quality_scale):
		return base_count
	return max(0, min(base_count, lod_count))


func _perf_begin() -> int:
	if not _is_perf_log_enabled():
		return 0
	return Time.get_ticks_usec()


func _perf_end(label: String, start_usec: int) -> void:
	if start_usec <= 0:
		return
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var sample: Dictionary = perf_samples.get(label, {"count": 0, "total": 0.0, "max": 0.0})
	sample["count"] = int(sample.get("count", 0)) + 1
	sample["total"] = float(sample.get("total", 0.0)) + elapsed_ms
	sample["max"] = max(float(sample.get("max", 0.0)), elapsed_ms)
	perf_samples[label] = sample


func _battle_perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _battle_perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


func _perf_maybe_log(context: Dictionary) -> void:
	if not _is_perf_log_enabled() or perf_samples.is_empty():
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec < perf_log_next_msec:
		return
	perf_log_next_msec = now_msec + int(PERF_LOG_INTERVAL_SEC * 1000.0)
	var keys := perf_samples.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		var sample: Dictionary = perf_samples.get(key, {})
		var count: int = max(1, int(sample.get("count", 0)))
		var average_ms: float = float(sample.get("total", 0.0)) / float(count)
		parts.append("%s avg=%.3fms max=%.3fms n=%d" % [
			str(key),
			average_ms,
			float(sample.get("max", 0.0)),
			count,
		])
	var joined := ""
	for idx in range(parts.size()):
		if idx > 0:
			joined += "; "
		joined += parts[idx]
	print(
		"[Stage2PlayfieldPerf] stage=",
		int(context.get("current_stage", 1)),
		" bushes=",
		bushes.size(),
		" active_bushes=",
		_count_active_bushes(),
		" bush_clusters=",
		_count_bush_draw_clusters(),
		" bush_leaf_dots=",
		_count_bush_leaf_dots(),
		" vines=",
		vines.size(),
		" active_vines=",
		_count_active_vines(),
		" leaves=",
		falling_leaves.size(),
		" rage=%.2f" % float(context.get("stage2_boss_rage_tint", 0.0)),
		" | ",
		joined
	)
	perf_samples.clear()


func _is_perf_log_enabled() -> bool:
	if perf_log_checked:
		return perf_log_enabled
	perf_log_checked = true
	var value := OS.get_environment(PERF_LOG_ENV).strip_edges().to_lower()
	perf_log_enabled = value in ["1", "true", "yes", "on"] or FileAccess.file_exists(PERF_LOG_FLAG_PATH)
	return perf_log_enabled


func _count_active_bushes() -> int:
	var count := 0
	for bush in bushes:
		if float(bush.get("rustle_amount", 0.0)) > 0.05:
			count += 1
	return count


func _count_active_vines() -> int:
	var count := 0
	for vine in vines:
		if float(vine.get("rustle_amount", 0.0)) > 0.05:
			count += 1
	return count


func _count_bush_draw_clusters() -> int:
	var count := 0
	for bush in bushes:
		var clusters: Array = bush.get("draw_clusters", []) if bush.get("draw_clusters", []) is Array else []
		count += clusters.size()
	return count


func _count_bush_leaf_dots() -> int:
	var count := 0
	for bush in bushes:
		var leaves: Array = bush.get("leaves", []) if bush.get("leaves", []) is Array else []
		count += leaves.size()
	return count


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _rgba255(r: float, g: float, b: float, a: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a / 255.0)


@warning_ignore("shadowed_global_identifier")
func _noise(seed: float) -> float:
	return fposmod(sin(seed * 12.9898) * 43758.5453, 1.0)
