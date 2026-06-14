extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StatusEffectOverlayRenderer := preload("res://scripts/status/status_effect_overlay_renderer.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const ElectricStunVisual := preload("res://scripts/status/boss_electric_stun_visual.gd")
const ElectrocutionFieldHost := preload("res://scripts/effects/boss_electrocution_field_fx_host.gd")

const WALK_TEXTURE_PATH := "res://assets/sprites/stage3/menhera_boss_sheet.png"
const ATTACK_TEXTURE_PATH := "res://assets/sprites/stage3/menhera_boss_attack.png"
const DASH_TEXTURE_PATH := "res://assets/sprites/stage3/menhera_boss_dash.png"
const TURN_TEXTURE_PATH := "res://assets/sprites/stage3/menhera_boss_turn.png"
const VICTORY_TEXTURE_PATH := "res://assets/sprites/stage3/menhera_boss_victory.png"
const DEFEAT_TEXTURE_PATH := "res://assets/sprites/stage3/menhera_boss_defeat.png"
const GRID_COLS := 4
const GRID_ROWS := 2
const FRAME_COUNT := GRID_COLS * GRID_ROWS
const FRAME_INSET := 14
const DEFAULT_DRAW_SIZE := Vector2(176.0, 88.0)
const VISUAL_CENTER_Y_OFFSET := 31.0
const WALK_FRAME_INTERVAL_SEC := 0.08
const ATTACK_FRAME_INTERVAL_SEC := 0.055
const ATTACK_IMPACT_FRAME := 5
const ATTACK_IMPACT_HOLD_SEC := 0.12
const DASH_FRAME_INTERVAL_SEC := 0.07
const TURN_HOLD_SEC := 0.08
const TURN_FRAME_INTERVAL_SEC := 0.055
const TURN_PLAYBACK_FRAME_COUNT := 7
const TURN_HOP_HEIGHT_RATIO := 0.018
const MOVING_THRESHOLD := 0.12
const MOVE_RELEASE_SEC := 0.12
const PREWARM_TEXTURE_KEYS := ["walk", "attack", "dash", "turn", "victory", "defeat"]
const FRAME_METADATA_TEXTURE_SIZE := Vector2(2752.0, 1536.0)
# Alpha-bbox metadata is baked from the source sheets so boot and first draw
# never have to scan millions of pixels in GDScript.
const FRAME_SOURCE_METADATA := {
	"walk": {
		"reference": [528, 729],
		"frames": [
			[80, 17, 527, 729],
			[768, 17, 528, 729],
			[1456, 17, 528, 729],
			[2145, 17, 527, 729],
			[80, 791, 527, 728],
			[769, 791, 526, 728],
			[1456, 791, 528, 728],
			[2145, 791, 527, 728],
		],
	},
	"attack": {
		"reference": [555, 737],
		"frames": [
			[118, 28, 467, 726],
			[804, 28, 466, 726],
			[1484, 28, 467, 726],
			[2129, 51, 509, 703],
			[70, 785, 555, 737],
			[746, 842, 548, 680],
			[1431, 807, 542, 715],
			[2130, 785, 517, 737],
		],
	},
	"dash": {
		"reference": [660, 699],
		"frames": [
			[126, 134, 498, 583],
			[716, 63, 646, 648],
			[1390, 148, 660, 556],
			[2078, 172, 640, 429],
			[86, 883, 588, 527],
			[702, 831, 651, 654],
			[1509, 803, 440, 683],
			[2149, 786, 406, 699],
		],
	},
	"turn": {
		"reference": [487, 694],
		"frames": [
			[123, 38, 441, 694],
			[789, 39, 487, 691],
			[1492, 38, 455, 693],
			[2189, 38, 438, 694],
			[133, 806, 423, 693],
			[802, 806, 461, 693],
			[1521, 806, 398, 693],
			[2187, 806, 441, 694],
		],
	},
	"victory": {
		"reference": [514, 705],
		"frames": [
			[115, 57, 458, 655],
			[786, 47, 491, 669],
			[1491, 59, 457, 649],
			[2186, 51, 444, 667],
			[93, 807, 501, 689],
			[807, 838, 450, 628],
			[1463, 810, 514, 684],
			[2155, 799, 505, 705],
		],
	},
	"defeat": {
		"reference": [625, 740],
		"frames": [
			[136, 14, 418, 740],
			[787, 18, 497, 736],
			[1502, 91, 482, 663],
			[2188, 146, 481, 608],
			[123, 881, 508, 641],
			[737, 965, 625, 557],
			[1476, 906, 479, 616],
			[2163, 952, 486, 570],
		],
	},
}
const GROUND_SHADOW_SEGMENTS := 18
const GROUND_SHADOW_SEGMENTS_LOD := 12
const GROUND_SHADOW_SEGMENTS_SEVERE_LOD := 10
const READY_AURA_OUTER_SEGMENTS := 40
const READY_AURA_OUTER_SEGMENTS_LOD := 26
const READY_AURA_OUTER_SEGMENTS_SEVERE_LOD := 18
const READY_AURA_INNER_SEGMENTS := 36
const READY_AURA_INNER_SEGMENTS_LOD := 24
const READY_AURA_INNER_SEGMENTS_SEVERE_LOD := 16
const MAX_RENDERED_OVERDRIVE_TRAILS_LOD := 2
const MAX_RENDERED_OVERDRIVE_TRAILS_SEVERE_LOD := 1
const STUN_STAR_FILL := Color(1.0, 1.0, 100.0 / 255.0, 1.0)
const STUN_STAR_OUTLINE := Color(1.0, 200.0 / 255.0, 0.0, 1.0)
const STUN_STAR_GLOW_OUTER := Color(1.0, 0.92, 0.20, 0.14)
const STUN_STAR_GLOW_INNER := Color(1.0, 1.0, 0.52, 0.20)

var _textures := {}
var _frame_sources := {}
var _frame_references := {}
var _assets_prewarmed := false
var _prewarm_step_index := 0
var _last_center_x := INF
var _facing := 1
var _pending_facing := 0
var _pending_facing_time := 0.0
var _turn_active := false
var _turn_time := 0.0
var _turn_target_facing := 1
var _move_release_time := 0.0
var _is_moving := false
var _last_draw_msec := 0
var _unit_stun_star_points := PackedVector2Array()
var status_overlay_renderer: Object = StatusEffectOverlayRenderer.new()
var _active_quality_scale: float = 1.0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _assets_prewarmed:
		return true
	if _prewarm_step_index < PREWARM_TEXTURE_KEYS.size():
		_prepare_frame_source(str(PREWARM_TEXTURE_KEYS[_prewarm_step_index]))
		_prewarm_step_index += 1
		if _prewarm_step_index < PREWARM_TEXTURE_KEYS.size():
			return false
	_assets_prewarmed = true
	_prewarm_step_index = 0
	return true


func reset() -> void:
	_last_center_x = INF
	_facing = 1
	_pending_facing = 0
	_pending_facing_time = 0.0
	_turn_active = false
	_turn_time = 0.0
	_turn_target_facing = 1
	_move_release_time = 0.0
	_is_moving = false
	_last_draw_msec = 0


func draw(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	if canvas == null:
		return
	_active_quality_scale = _get_actor_quality_scale(context)
	if not _assets_prewarmed:
		prewarm_assets_step()
		return
	var boss_pos: Vector2 = _as_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_paddle_size: Vector2 = _as_vector2(context.get("boss_paddle_size", Vector2(110.0, 40.0)), Vector2(110.0, 40.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", boss_paddle_size.y))
	var center := Vector2(
		boss_pos.x + boss_paddle_size.x * 0.5 + shake_offset.x,
		boss_pos.y + boss_hitbox_height * 0.5 + VISUAL_CENTER_Y_OFFSET + shake_offset.y
	)
	var dt: float = _consume_draw_delta()
	_update_motion_state(dt, center.x, context)

	var pose: Dictionary = _select_pose(context)
	var draw_size: Vector2 = _as_vector2(context.get("stage3_menhera_boss_draw_size", DEFAULT_DRAW_SIZE), DEFAULT_DRAW_SIZE)
	center.y += _get_turn_hop_offset(draw_size.y)
	center += ElectricStunVisual.body_jitter(context)
	ElectrocutionFieldHost.drive_from_context(canvas, center, context)
	var red_ratio: float = clamp(float(context.get("stage3_boss_red_ratio", 0.0)), 0.0, 1.0)
	var ready_glow: bool = bool(context.get("stage3_boss_special_ready", false))
	var overdrive_active: bool = bool(context.get("stage3_emotional_overdrive_active", false))

	_draw_overdrive_trails(canvas, context, pose, draw_size)
	_draw_ground_shadow(canvas, center + Vector2(0.0, 36.0), Vector2(72.0, 11.0))
	if ready_glow or overdrive_active:
		_draw_ready_aura(canvas, center, draw_size, overdrive_active)

	var drawn: bool = _draw_pose(canvas, pose, center, draw_size, false, ElectricStunVisual.body_modulate(context))
	if drawn and red_ratio > 0.0:
		_draw_pose(canvas, pose, center, draw_size, false, Color(1.0, 0.08, 0.16, 0.12 + red_ratio * 0.45))
	if not drawn:
		_draw_fallback(canvas, center, draw_size, red_ratio)
	_draw_status_overlays(canvas, context, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset)


func _select_pose(context: Dictionary) -> Dictionary:
	if bool(context.get("boss_defeat_active", false)):
		return {
			"key": "defeat",
			"frame": min(FRAME_COUNT - 1, int(context.get("boss_defeat_frame", context.get("boss_result_frame", 0)))),
			"flip_h": false,
		}
	if bool(context.get("boss_victory_active", false)):
		return {
			"key": "victory",
			"frame": int(context.get("boss_victory_frame", context.get("boss_result_frame", 0))) % FRAME_COUNT,
			"flip_h": false,
		}
	if bool(context.get("boss_dash_active", false)):
		return {
			"key": "dash",
			"frame": int(context.get("boss_dash_frame", _time_frame(DASH_FRAME_INTERVAL_SEC))) % FRAME_COUNT,
			"flip_h": int(context.get("boss_dash_direction", _facing)) < 0,
		}
	if bool(context.get("boss_hit_active", false)):
		return {
			"key": "attack",
			"frame": int(context.get("boss_hit_frame", _attack_time_frame())) % FRAME_COUNT,
			"flip_h": false,
		}
	if _turn_active and _has_frame_source("turn"):
		return {
			"key": "turn",
			"frame": min(TURN_PLAYBACK_FRAME_COUNT - 1, int(floor(_turn_time / TURN_FRAME_INTERVAL_SEC))),
			"flip_h": false,
		}
	return {
		"key": "walk",
		"frame": int(context.get("boss_sprite_frame", _time_frame(WALK_FRAME_INTERVAL_SEC))) % FRAME_COUNT if _is_moving else 0,
		"flip_h": false,
	}


func _draw_pose(
	canvas: CanvasItem,
	pose: Dictionary,
	center: Vector2,
	draw_size: Vector2,
	_force_alpha_only: bool,
	modulate: Color
) -> bool:
	var key: String = str(pose.get("key", "walk"))
	var texture: Texture2D = _get_texture(key)
	var frames: Array = _get_frame_source(key)
	if texture == null or frames.is_empty():
		return false
	var frame: int = clamp(int(pose.get("frame", 0)), 0, frames.size() - 1)
	var source: Dictionary = frames[frame]
	var source_rect: Rect2 = _as_rect2(source.get("rect", Rect2()), Rect2())
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return false
	var visible_size: Vector2 = _as_vector2(source.get("visible_size", source_rect.size), source_rect.size)
	@warning_ignore("shadowed_variable_base_class")
	var reference: Vector2 = _as_vector2(_frame_references.get(key, draw_size), draw_size)
	if key in ["dash", "victory", "defeat"] and _frame_references.has("walk"):
		reference = _as_vector2(_frame_references.get("walk", reference), reference)
	reference.x = max(1.0, reference.x)
	reference.y = max(1.0, reference.y)
	var scale: float = min(draw_size.x / reference.x, draw_size.y / reference.y)
	var target_size := Vector2(max(1.0, visible_size.x * scale), max(1.0, visible_size.y * scale))
	var target_rect := Rect2(
		Vector2(center.x - target_size.x * 0.5, center.y + draw_size.y * 0.5 - target_size.y),
		target_size
	)
	if bool(pose.get("flip_h", false)):
		_draw_flipped_texture_region(canvas, texture, source_rect, target_rect, modulate)
	else:
		canvas.draw_texture_rect_region(texture, target_rect, source_rect, modulate, false, true)
	return true


func _draw_overdrive_trails(canvas: CanvasItem, context: Dictionary, pose: Dictionary, draw_size: Vector2) -> void:
	var trails: Array = _as_array(context.get("stage3_overdrive_trails", []))
	if trails.is_empty():
		return
	var render_limit: int = trails.size()
	if _is_severe_lod_active():
		render_limit = min(trails.size(), MAX_RENDERED_OVERDRIVE_TRAILS_SEVERE_LOD)
	elif _is_lod_active():
		render_limit = min(trails.size(), MAX_RENDERED_OVERDRIVE_TRAILS_LOD)
	var start_index: int = max(0, trails.size() - render_limit)
	for idx in range(trails.size() - 1, start_index - 1, -1):
		var trail: Dictionary = trails[idx] if trails[idx] is Dictionary else {}
		var alpha: float = clamp(float(trail.get("alpha", 0.0)), 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var center: Vector2 = _as_vector2(trail.get("center", Vector2.ZERO), Vector2.ZERO)
		_draw_pose(canvas, pose, center, draw_size, true, Color(1.0, 0.55, 0.86, alpha))


func _draw_ground_shadow(canvas: CanvasItem, center: Vector2, size: Vector2) -> void:
	var points := PackedVector2Array()
	var segment_count: int = _get_lod_count(GROUND_SHADOW_SEGMENTS, GROUND_SHADOW_SEGMENTS_LOD, GROUND_SHADOW_SEGMENTS_SEVERE_LOD)
	for idx in range(segment_count):
		var angle := TAU * float(idx) / float(segment_count)
		points.append(center + Vector2(cos(angle) * size.x * 0.5, sin(angle) * size.y * 0.5))
	canvas.draw_colored_polygon(points, Color(0.10, 0.03, 0.08, 0.26))


func _draw_ready_aura(canvas: CanvasItem, center: Vector2, draw_size: Vector2, overdrive_active: bool) -> void:
	var now: float = float(Time.get_ticks_msec())
	var pulse: float = 0.5 + 0.5 * sin(now * 0.014)
	var color := Color(1.0, 0.22, 0.58, 0.18 + pulse * 0.10)
	if overdrive_active:
		color = Color(0.78, 0.10, 1.0, 0.22 + pulse * 0.12)
	var radius: float = max(draw_size.x, draw_size.y) * (0.42 + pulse * 0.04)
	canvas.draw_arc(center, radius, 0.0, TAU, _get_lod_count(READY_AURA_OUTER_SEGMENTS, READY_AURA_OUTER_SEGMENTS_LOD, READY_AURA_OUTER_SEGMENTS_SEVERE_LOD), color, 3.0, true)
	if not _is_severe_lod_active():
		canvas.draw_arc(center, radius * 0.72, 0.3, TAU + 0.3, _get_lod_count(READY_AURA_INNER_SEGMENTS, READY_AURA_INNER_SEGMENTS_LOD, READY_AURA_INNER_SEGMENTS_SEVERE_LOD), Color(1.0, 0.82, 1.0, color.a * 0.72), 1.5, true)


func _draw_fallback(canvas: CanvasItem, center: Vector2, draw_size: Vector2, red_ratio: float) -> void:
	var rect := Rect2(center - draw_size * 0.5, draw_size)
	canvas.draw_rect(rect, Color(0.50 + red_ratio * 0.35, 0.10, 0.26, 0.95))
	canvas.draw_rect(rect, Color(1.0, 0.62, 0.84, 0.85), false, 2.0)
	canvas.draw_circle(center + Vector2(-18.0, -8.0), 7.0, Color(1.0, 0.70, 0.86, 1.0))
	canvas.draw_circle(center + Vector2(18.0, -8.0), 7.0, Color(1.0, 0.70, 0.86, 1.0))


func _draw_status_overlays(
	canvas: CanvasItem,
	context: Dictionary,
	boss_pos: Vector2,
	boss_paddle_size: Vector2,
	boss_hitbox_height: float,
	shake_offset: Vector2
) -> void:
	status_overlay_renderer.draw_boss_status_overlays(canvas, context, boss_pos, boss_paddle_size, boss_hitbox_height, shake_offset)


func _draw_stun_star(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	if _unit_stun_star_points.is_empty():
		_unit_stun_star_points = _build_unit_stun_star_points()
	canvas.draw_circle(center, radius * 2.0, STUN_STAR_GLOW_OUTER)
	canvas.draw_circle(center, radius * 1.35, STUN_STAR_GLOW_INNER)
	var points := PackedVector2Array()
	for point in _unit_stun_star_points:
		points.append(center + point * radius)
	canvas.draw_colored_polygon(points, STUN_STAR_FILL)
	for idx in range(points.size()):
		canvas.draw_line(points[idx], points[(idx + 1) % points.size()], STUN_STAR_OUTLINE, 1.2, true)


func _build_unit_stun_star_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for idx in range(10):
		var point_angle: float = deg_to_rad(float(idx) * 36.0 - 90.0)
		var point_radius: float = 1.0 if idx % 2 == 0 else 0.4
		points.append(Vector2(cos(point_angle), sin(point_angle)) * point_radius)
	return points


func _update_motion_state(dt: float, center_x: float, context: Dictionary) -> void:
	if _last_center_x == INF:
		_last_center_x = center_x
	var dx: float = center_x - _last_center_x
	_last_center_x = center_x
	var moving_now: bool = abs(dx) > MOVING_THRESHOLD or bool(context.get("boss_is_walking", false))
	if moving_now:
		_move_release_time = MOVE_RELEASE_SEC
		var requested_facing: int = -1 if dx < -MOVING_THRESHOLD else (1 if dx > MOVING_THRESHOLD else int(context.get("boss_facing", _facing)))
		_update_requested_facing(dt, requested_facing)
	else:
		_move_release_time = max(0.0, _move_release_time - dt)
	_is_moving = moving_now or _move_release_time > 0.0
	if _turn_active:
		_turn_time += dt
		var total_duration: float = TURN_FRAME_INTERVAL_SEC * float(TURN_PLAYBACK_FRAME_COUNT)
		if _turn_time >= total_duration:
			_facing = _turn_target_facing
			_turn_active = false
			_turn_time = 0.0


func _update_requested_facing(dt: float, requested_facing: int) -> void:
	if requested_facing == 0 or requested_facing == _facing or _turn_active:
		_pending_facing = 0
		_pending_facing_time = 0.0
		return
	if _pending_facing != requested_facing:
		_pending_facing = requested_facing
		_pending_facing_time = 0.0
	_pending_facing_time += dt
	if _pending_facing_time >= TURN_HOLD_SEC:
		_turn_active = _has_frame_source("turn")
		_turn_time = 0.0
		_turn_target_facing = requested_facing
		if not _turn_active:
			_facing = requested_facing
		_pending_facing = 0
		_pending_facing_time = 0.0


func _get_turn_hop_offset(rendered_height: float) -> float:
	if not _turn_active:
		return 0.0
	var progress: float = clamp(_turn_time / max(0.001, TURN_FRAME_INTERVAL_SEC * float(TURN_PLAYBACK_FRAME_COUNT)), 0.0, 1.0)
	return -max(1.0, rendered_height * TURN_HOP_HEIGHT_RATIO) * sin(PI * progress)


func _consume_draw_delta() -> float:
	var now: int = Time.get_ticks_msec()
	if _last_draw_msec <= 0:
		_last_draw_msec = now
		return 1.0 / 60.0
	var delta: float = clamp(float(now - _last_draw_msec) / 1000.0, 0.0, 0.05)
	_last_draw_msec = now
	return delta


func _attack_time_frame() -> int:
	var cycle: float = fmod(float(Time.get_ticks_msec()) / 1000.0, ATTACK_FRAME_INTERVAL_SEC * float(FRAME_COUNT) + ATTACK_IMPACT_HOLD_SEC)
	var frame := 0
	var cursor := 0.0
	for idx in range(FRAME_COUNT):
		var duration := ATTACK_IMPACT_HOLD_SEC if idx == ATTACK_IMPACT_FRAME else ATTACK_FRAME_INTERVAL_SEC
		if cycle < cursor + duration:
			frame = idx
			break
		cursor += duration
	return frame


func _time_frame(interval_sec: float) -> int:
	return int(floor(float(Time.get_ticks_msec()) / max(1.0, interval_sec * 1000.0))) % FRAME_COUNT


func _get_texture(key: String) -> Texture2D:
	if _textures.has(key):
		return _textures[key]
	var path := _get_texture_path(key)
	if path == "":
		return null
	_textures[key] = ProjectResourceLoader.load_texture(
		path,
		"[Stage3MenheraBoss] missing texture: %s",
		"[Stage3MenheraBoss] failed to load texture: %s"
	)
	return _textures[key]


func _get_texture_path(key: String) -> String:
	match key:
		"walk":
			return WALK_TEXTURE_PATH
		"attack":
			return ATTACK_TEXTURE_PATH
		"dash":
			return DASH_TEXTURE_PATH
		"turn":
			return TURN_TEXTURE_PATH
		"victory":
			return VICTORY_TEXTURE_PATH
		"defeat":
			return DEFEAT_TEXTURE_PATH
		_:
			return ""


func _prepare_all_frame_sources() -> void:
	for key in PREWARM_TEXTURE_KEYS:
		if not _frame_sources.has(key):
			_prepare_frame_source(str(key))


func _prepare_frame_source(key: String) -> void:
	var path := _get_texture_path(key)
	var texture: Texture2D = _get_texture(key)
	if texture == null or path == "":
		_frame_sources[key] = []
		return
	var metadata: Dictionary = _as_dictionary(FRAME_SOURCE_METADATA.get(key, {}))
	if not metadata.is_empty() and texture.get_size() == FRAME_METADATA_TEXTURE_SIZE:
		_prepare_frame_source_from_metadata(key, metadata, texture)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_frame_sources[key] = _fallback_cell_sources(texture)
		_frame_references[key] = texture.get_size() / Vector2(float(GRID_COLS), float(GRID_ROWS))
		return
	if image.is_compressed():
		image.decompress()
	var image_size := Vector2i(image.get_width(), image.get_height())
	@warning_ignore("integer_division")
	var cell_w: int = max(1, int(image_size.x / GRID_COLS))
	@warning_ignore("integer_division")
	var cell_h: int = max(1, int(image_size.y / GRID_ROWS))
	@warning_ignore("integer_division")
	var inset_x: int = min(FRAME_INSET, max(2, int(cell_w / 32)))
	@warning_ignore("integer_division")
	var inset_y: int = min(FRAME_INSET, max(2, int(cell_h / 32)))
	var frames: Array = []
	var ref_size := Vector2.ONE
	for frame in range(FRAME_COUNT):
		var col: int = frame % GRID_COLS
		@warning_ignore("integer_division")
		var row: int = int(frame / GRID_COLS)
		var scan_rect := Rect2i(
			col * cell_w + inset_x,
			row * cell_h + inset_y,
			max(1, cell_w - inset_x * 2),
			max(1, cell_h - inset_y * 2)
		)
		var visible := _scan_visible_rect(image, scan_rect)
		var source_rect := Rect2(Vector2(visible.position), Vector2(visible.size))
		var visible_size := Vector2(max(1.0, float(visible.size.x)), max(1.0, float(visible.size.y)))
		ref_size.x = max(ref_size.x, visible_size.x)
		ref_size.y = max(ref_size.y, visible_size.y)
		frames.append({"rect": source_rect, "visible_size": visible_size})
	_frame_sources[key] = frames
	_frame_references[key] = ref_size


func _prepare_frame_source_from_metadata(key: String, metadata: Dictionary, texture: Texture2D) -> void:
	var frames: Array = []
	var ref_size: Vector2 = _metadata_vector2(metadata.get("reference", []), Vector2.ONE)
	for frame_value in _as_array(metadata.get("frames", [])):
		var rect_values: Array = _as_array(frame_value)
		if rect_values.size() < 4:
			continue
		var source_rect := Rect2(
			Vector2(float(rect_values[0]), float(rect_values[1])),
			Vector2(max(1.0, float(rect_values[2])), max(1.0, float(rect_values[3])))
		)
		var visible_size := source_rect.size
		ref_size.x = max(ref_size.x, visible_size.x)
		ref_size.y = max(ref_size.y, visible_size.y)
		frames.append({"rect": source_rect, "visible_size": visible_size})
	if frames.is_empty():
		frames = _fallback_cell_sources(texture)
		ref_size = texture.get_size() / Vector2(float(GRID_COLS), float(GRID_ROWS))
	_frame_sources[key] = frames
	_frame_references[key] = ref_size


func _scan_visible_rect(image: Image, scan_rect: Rect2i) -> Rect2i:
	var min_x: int = scan_rect.position.x + scan_rect.size.x
	var min_y: int = scan_rect.position.y + scan_rect.size.y
	var max_x: int = scan_rect.position.x
	var max_y: int = scan_rect.position.y
	var found := false
	var end_x: int = scan_rect.position.x + scan_rect.size.x
	var end_y: int = scan_rect.position.y + scan_rect.size.y
	for y in range(scan_rect.position.y, end_y):
		for x in range(scan_rect.position.x, end_x):
			if image.get_pixel(x, y).a <= 0.01:
				continue
			found = true
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)
	if not found:
		return scan_rect
	return Rect2i(min_x, min_y, max(1, max_x - min_x + 1), max(1, max_y - min_y + 1))


func _fallback_cell_sources(texture: Texture2D) -> Array:
	var texture_size: Vector2 = texture.get_size()
	var cell_size := Vector2(texture_size.x / float(GRID_COLS), texture_size.y / float(GRID_ROWS))
	var frames: Array = []
	for frame in range(FRAME_COUNT):
		var col: int = frame % GRID_COLS
		@warning_ignore("integer_division")
		var row: int = int(frame / GRID_COLS)
		frames.append({
			"rect": Rect2(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), cell_size),
			"visible_size": cell_size,
		})
	return frames


func _get_frame_source(key: String) -> Array:
	if not _frame_sources.has(key):
		_prepare_frame_source(key)
	return _as_array(_frame_sources.get(key, []))


func _has_frame_source(key: String) -> bool:
	return not _get_frame_source(key).is_empty()


func _draw_flipped_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	target_rect: Rect2,
	modulate: Color
) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var points := PackedVector2Array([
		target_rect.position,
		Vector2(target_rect.end.x, target_rect.position.y),
		target_rect.end,
		Vector2(target_rect.position.x, target_rect.end.y),
	])
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_min.x, uv_max.y),
		Vector2(uv_max.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func get_asset_status() -> Dictionary:
	prewarm_assets()
	return {
		"walk": _get_texture("walk") != null,
		"attack": _get_texture("attack") != null,
		"dash": _get_texture("dash") != null,
		"turn": _get_texture("turn") != null,
		"victory": _get_texture("victory") != null,
		"defeat": _get_texture("defeat") != null,
		"walk_frame_count": _get_frame_source("walk").size(),
		"viper_airborne_lod_supported": true,
		"shared_render_quality_lod_supported": true,
	}


func _get_actor_quality_scale(context: Dictionary) -> float:
	return BattleRenderQuality.effect_scale(context)


func _is_lod_active() -> bool:
	return _active_quality_scale < 0.85


func _is_severe_lod_active() -> bool:
	return _active_quality_scale < 0.66


func _get_lod_count(base_count: int, lod_count: int, severe_lod_count: int) -> int:
	if base_count <= 0:
		return 0
	if _is_severe_lod_active():
		return clampi(severe_lod_count, 0, base_count)
	if _is_lod_active():
		return clampi(lod_count, 0, base_count)
	return base_count


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_rect2(value: Variant, fallback: Rect2) -> Rect2:
	if value is Rect2:
		return value
	return fallback


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _metadata_vector2(value: Variant, fallback: Vector2) -> Vector2:
	var values: Array = _as_array(value)
	if values.size() < 2:
		return fallback
	return Vector2(max(1.0, float(values[0])), max(1.0, float(values[1])))
