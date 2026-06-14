extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage4MoonPayloadFactory := preload("res://scripts/stages/stage4/stage4_moon_payload_factory.gd")

const MOON_WHITE_SHEET_PATH := "res://assets/sprites/hud/stage4_moon_white_idle_sheet_imagegen_v1.png"
const MOON_RED_TRANSFORM_SHEET_PATH := "res://assets/sprites/hud/stage4_moon_red_transform_sheet_imagegen_v2.png"
const MOON_RED_BURST_SHEET_PATH := "res://assets/sprites/hud/stage4_moon_red_burst_sheet_imagegen_v1.png"
const RED_MOON_FRAGMENT_ATLAS_PATH := "res://assets/sprites/hud/stage4_red_moon_fragment_atlas_imagegen_v1.png"
const MOON_FRAME_COUNT := 6
const MOON_FRAME_INTERVAL_MS := 105.0
const PILLAR_SOURCE_SIZE := Vector2(1659.0, 948.0)
const RED_MOON_SOURCE_ANCHOR := Vector2(1490.0, 76.0)
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const FRAGMENT_ATLAS_COLUMNS := 4
const FRAGMENT_ATLAS_ROWS := 4
const MAX_FRAGMENTS := 40
const FRAGMENT_SPAWN_MIN_FRAMES := 120.0
const FRAGMENT_SPAWN_MAX_FRAMES := 900.0
const FRAGMENT_IMAGE_SCALE_MIN := 2.8
const FRAGMENT_IMAGE_SCALE_MAX := 5.5
const FRAGMENT_ROTATION_SPEED_MIN := 0.15
const FRAGMENT_ROTATION_SPEED_MAX := 2.4
const FRAGMENT_PLAYER_HIT_COOLDOWN_MS := 100.0
const PLAYER_BURN_FRAMES := 30.0
const PLAYER_FRAGMENT_KNOCKBACK := 20.0
const BOSS_FRAGMENT_STUN_FRAMES := 30.0
const BOSS_FRAGMENT_KNOCKBACK := 8.0
const BOSS_GAUGE_DAMAGE := 50.0

var white_sheet: Texture2D = null
var red_transform_sheet: Texture2D = null
var red_burst_sheet: Texture2D = null
var fragment_atlas: Texture2D = null
var textures_loaded := false
var moon_red_intensity := 0.0
var moon_pulse_scale := 1.0
var phase_seed := 0.0
var moon_center := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var moon_fragments: Array = []
var fragment_hit_cooldowns: Dictionary = {}
var moon_fragment_timer_frames := 0.0
var moon_fragment_interval_frames := FRAGMENT_SPAWN_MIN_FRAMES
var moon_fragment_active := false
var moon_pulse_timer_frames := 0.0
var player_burn_timer_frames := 0.0
var player_burn_total_frames := PLAYER_BURN_FRAMES
var _prewarm_step_index := 0


func _init() -> void:
	rng.randomize()
	moon_fragment_interval_frames = rng.randf_range(FRAGMENT_SPAWN_MIN_FRAMES, FRAGMENT_SPAWN_MAX_FRAMES)


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if textures_loaded:
		return true
	match _prewarm_step_index:
		0:
			white_sheet = ProjectResourceLoader.load_texture(MOON_WHITE_SHEET_PATH)
		1:
			red_transform_sheet = ProjectResourceLoader.load_texture(MOON_RED_TRANSFORM_SHEET_PATH)
		2:
			red_burst_sheet = ProjectResourceLoader.load_texture(MOON_RED_BURST_SHEET_PATH)
		3:
			fragment_atlas = ProjectResourceLoader.load_texture(RED_MOON_FRAGMENT_ATLAS_PATH)
		_:
			textures_loaded = true
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	if _prewarm_step_index > 3:
		textures_loaded = true
		_prewarm_step_index = 0
		return true
	return false


func reset() -> void:
	moon_red_intensity = 0.0
	moon_pulse_scale = 1.0
	phase_seed = 0.0
	moon_center = Vector2.ZERO
	moon_fragments.clear()
	fragment_hit_cooldowns.clear()
	moon_fragment_timer_frames = 0.0
	moon_fragment_interval_frames = rng.randf_range(FRAGMENT_SPAWN_MIN_FRAMES, FRAGMENT_SPAWN_MAX_FRAMES)
	moon_fragment_active = false
	moon_pulse_timer_frames = 0.0
	player_burn_timer_frames = 0.0
	player_burn_total_frames = PLAYER_BURN_FRAMES


func update(delta: float, context: Dictionary = {}, deps: Dictionary = {}) -> void:
	var clamped_delta: float = clampf(delta, 0.0, 0.1)
	var fps_scale: float = clamped_delta * 60.0
	phase_seed += maxf(0.0, clamped_delta)
	moon_red_intensity = clampf(float(context.get("stage4_moon_red_intensity", moon_red_intensity)), 0.0, 1.0)
	moon_pulse_scale = maxf(0.4, float(context.get("stage4_moon_pulse_scale", moon_pulse_scale)))
	if moon_pulse_timer_frames > 0.0:
		moon_pulse_timer_frames = maxf(0.0, moon_pulse_timer_frames - fps_scale)
		var pulse_progress: float = 1.0 - moon_pulse_timer_frames / 30.0
		moon_pulse_scale = maxf(moon_pulse_scale, 1.0 + sin(clampf(pulse_progress, 0.0, 1.0) * PI) * 0.30)
	if player_burn_timer_frames > 0.0:
		player_burn_timer_frames = maxf(0.0, player_burn_timer_frames - fps_scale)
	_update_moon_fragments(fps_scale, context, deps)


func set_stage4_red_moon_state(intensity: float, scale: float, phase: float) -> bool:
	var previous := Vector2(moon_red_intensity, moon_pulse_scale)
	moon_red_intensity = clampf(float(intensity), 0.0, 1.0)
	moon_pulse_scale = maxf(0.4, float(scale))
	phase_seed = float(phase) / 60.0
	return previous.distance_to(Vector2(moon_red_intensity, moon_pulse_scale)) > 0.001


func draw_moon(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> Vector2:
	if canvas == null or view_size.x <= 0.0 or view_size.y <= 0.0:
		return Vector2.ZERO
	_ensure_textures()
	var center: Vector2 = _get_original_pillar_moon_center(view_size, game_offset, game_size)
	var diameter: float = maxf(64.0, 96.0 * minf(clampf(moon_pulse_scale, 0.4, 2.0), 1.08))
	var rect := Rect2(center - Vector2(diameter, diameter) * 0.5, Vector2(diameter, diameter))
	var texture: Texture2D = _get_state_texture()
	if texture != null:
		var source: Rect2 = _get_frame_source(texture)
		canvas.draw_texture_rect_region(texture, rect, source, Color.WHITE, false, true)
	else:
		_draw_glow(canvas, center, diameter)
		_draw_fallback_moon(canvas, center, diameter)
	moon_center = center
	return moon_center


func _get_original_pillar_moon_center(view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> Vector2:
	var scale: float = maxf(view_size.x / PILLAR_SOURCE_SIZE.x, view_size.y / PILLAR_SOURCE_SIZE.y)
	var target_size: Vector2 = PILLAR_SOURCE_SIZE * scale
	var offset: Vector2 = (view_size - target_size) * 0.5
	var center: Vector2 = offset + RED_MOON_SOURCE_ANCHOR * scale
	var right_start: float = game_offset.x + game_size.x
	var right_w: float = maxf(0.0, view_size.x - right_start)
	if right_w > 0.0:
		center.x = clampf(center.x, right_start + 28.0, view_size.x - 32.0)
	else:
		center.x = minf(view_size.x - 44.0, right_start + 44.0)
	center.y = maxf(28.0, center.y)
	return center


func get_stage4_moon_center() -> Vector2:
	return moon_center


func is_stage4_red_moon_active() -> bool:
	return moon_red_intensity > 0.03 or moon_pulse_scale > 1.04


func force_spawn_moon_fragments(count: int = 1, target: Variant = null) -> int:
	return _spawn_moon_fragments(max(1, count), target, {})


func get_moon_fragments() -> Array:
	var result: Array = []
	for fragment_value in moon_fragments:
		if not (fragment_value is Dictionary):
			continue
		var fragment: Dictionary = fragment_value
		if bool(fragment.get("impact", false)):
			continue
		result.append({
			"x": float(fragment.get("x", 0.0)),
			"y": float(fragment.get("y", 0.0)),
			"radius": float(fragment.get("size", 10.0)),
			"fragment_id": int(fragment.get("fragment_id", 0)),
			"deflected": bool(fragment.get("deflected", false)),
		})
	return result


func resolve_fragment_collisions(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> bool:
	if moon_fragments.is_empty():
		return false
	var handled := false
	if _resolve_player_fragment_collision(scene, context, deps):
		handled = true
	if _resolve_boss_fragment_collision(scene, context, deps):
		handled = true
	return handled


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage4_moon_fragments": _draw_array(moon_fragments, copy_arrays),
		"stage4_moon_fragment_count": moon_fragments.size(),
		"stage4_player_burn_active": player_burn_timer_frames > 0.0,
		"stage4_player_burn_ratio": _get_player_burn_ratio(),
		"stage4_moon_fragment_active": moon_fragment_active,
	}


func get_asset_status() -> Dictionary:
	_ensure_textures()
	return {
		"white_sheet": white_sheet != null,
		"red_transform_sheet": red_transform_sheet != null,
		"red_burst_sheet": red_burst_sheet != null,
		"moon_frame_count": MOON_FRAME_COUNT,
		"fragment_atlas": fragment_atlas != null,
		"fragment_frame_count": FRAGMENT_ATLAS_COLUMNS * FRAGMENT_ATLAS_ROWS,
	}


func _ensure_textures() -> void:
	if textures_loaded:
		return
	prewarm_assets()


func _get_state_texture() -> Texture2D:
	if moon_red_intensity >= 0.92 and red_burst_sheet != null:
		return red_burst_sheet
	if moon_red_intensity > 0.04 and red_transform_sheet != null:
		return red_transform_sheet
	return white_sheet


func _get_frame_source(texture: Texture2D) -> Rect2:
	var size: Vector2 = texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return Rect2()
	var frame_count: int = MOON_FRAME_COUNT
	var cell_w: float = size.x / float(frame_count)
	var frame: int = int(floor((float(Time.get_ticks_msec()) + phase_seed * 1000.0) / MOON_FRAME_INTERVAL_MS)) % frame_count
	return Rect2(float(frame) * cell_w, 0.0, cell_w, size.y)


func _draw_glow(canvas: CanvasItem, center: Vector2, diameter: float) -> void:
	var red := moon_red_intensity
	var base_color := Color(1.0, 0.95 - red * 0.45, 0.74 - red * 0.52, 1.0)
	for idx in range(4):
		var ratio: float = 1.0 + float(idx) * 0.28
		var alpha: float = (0.16 - float(idx) * 0.026) * (0.55 + red * 0.8)
		canvas.draw_circle(center, diameter * 0.52 * ratio, Color(base_color.r, base_color.g, base_color.b, alpha))


func _draw_fallback_moon(canvas: CanvasItem, center: Vector2, diameter: float) -> void:
	var red := moon_red_intensity
	var color := Color(1.0, 0.92 - red * 0.56, 0.72 - red * 0.56, 0.96)
	canvas.draw_circle(center, diameter * 0.42, color)
	canvas.draw_circle(center + Vector2(-diameter * 0.12, -diameter * 0.06), diameter * 0.055, Color(0.52, 0.18, 0.12, 0.28 + red * 0.35))
	canvas.draw_circle(center + Vector2(diameter * 0.10, diameter * 0.12), diameter * 0.045, Color(0.52, 0.18, 0.12, 0.22 + red * 0.30))


func _update_moon_fragments(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	var should_activate: bool = bool(context.get("stage4_moon_fragment_active", false)) or (
		bool(context.get("stage4_temple_destroyed", false))
		and moon_red_intensity > 0.02
	)
	if should_activate:
		if not moon_fragment_active:
			moon_fragment_timer_frames = moon_fragment_interval_frames
		moon_fragment_active = true
		moon_fragment_timer_frames += fps_scale
		if moon_fragment_timer_frames >= moon_fragment_interval_frames:
			if moon_fragments.size() < MAX_FRAGMENTS:
				_spawn_moon_fragments(rng.randi_range(3, 5), null, deps)
			moon_fragment_timer_frames = 0.0
			moon_fragment_interval_frames = rng.randf_range(FRAGMENT_SPAWN_MIN_FRAMES, FRAGMENT_SPAWN_MAX_FRAMES)
	elif moon_fragments.is_empty():
		moon_fragment_active = false

	var alive: Array = []
	for fragment_value in moon_fragments:
		if not (fragment_value is Dictionary):
			continue
		var fragment: Dictionary = fragment_value
		var keep := true
		if not bool(fragment.get("impact", false)):
			fragment["x"] = float(fragment.get("x", 0.0)) + float(fragment.get("vx", 0.0)) * fps_scale
			fragment["y"] = float(fragment.get("y", 0.0)) + float(fragment.get("vy", 0.0)) * fps_scale
			fragment["rotation"] = float(fragment.get("rotation", 0.0)) + float(fragment.get("rotation_speed", 0.0)) * fps_scale
			fragment["glow_phase"] = float(fragment.get("glow_phase", 0.0)) + 0.10 * fps_scale
			_update_fragment_trail(fragment)
			if (
				bool(context.get("stage4_destruction_active", false))
				and not bool(context.get("stage4_temple_destroyed", false))
				and _get_temple_hitbox().has_point(Vector2(float(fragment.get("x", 0.0)), float(fragment.get("y", 0.0))))
			):
				_mark_fragment_impact(fragment, "temple", deps)
			else:
				_update_fragment_field_lifecycle(fragment, fps_scale)
		else:
			fragment["impact_timer"] = maxf(0.0, float(fragment.get("impact_timer", 0.0)) - fps_scale)
			fragment["shockwave_radius"] = (30.0 - float(fragment.get("impact_timer", 0.0))) * 3.0
			if float(fragment.get("impact_timer", 0.0)) <= 0.0:
				fragment_hit_cooldowns.erase(int(fragment.get("fragment_id", 0)))
				keep = false
		if keep:
			alive.append(fragment)
	moon_fragments = alive


func _spawn_moon_fragments(count: int, target: Variant, deps: Dictionary) -> int:
	_ensure_textures()
	var spawned := 0
	var origin := _get_fragment_origin()
	for _idx in range(count):
		if moon_fragments.size() >= MAX_FRAGMENTS:
			break
		var target_pos := Vector2(
			rng.randf_range(50.0, FIELD_WIDTH - 50.0),
			rng.randf_range(500.0, FIELD_HEIGHT - 40.0)
		)
		if target is Vector2:
			target_pos = target
		moon_fragments.append(Stage4MoonPayloadFactory.build_fragment(
			origin,
			target_pos,
			rng,
			int(Time.get_ticks_msec()),
			FRAGMENT_ROTATION_SPEED_MIN,
			FRAGMENT_ROTATION_SPEED_MAX,
			FRAGMENT_IMAGE_SCALE_MIN,
			FRAGMENT_IMAGE_SCALE_MAX,
			FIELD_WIDTH + 30.0,
			FRAGMENT_ATLAS_COLUMNS * FRAGMENT_ATLAS_ROWS
		))
		spawned += 1
	if spawned > 0:
		moon_pulse_timer_frames = 30.0
		_play_fragment_shoot_audio(deps)
	return spawned


func _get_fragment_origin() -> Vector2:
	return Vector2(FIELD_WIDTH + 24.0, clampf(moon_center.y if moon_center != Vector2.ZERO else 96.0, -20.0, FIELD_HEIGHT * 0.28))


func _update_fragment_trail(fragment: Dictionary) -> void:
	var trail: Array = _as_array(fragment.get("trail", []))
	trail.append(Vector2(float(fragment.get("x", 0.0)), float(fragment.get("y", 0.0))))
	while trail.size() > 10:
		trail.pop_front()
	fragment["trail"] = trail


func _update_fragment_field_lifecycle(fragment: Dictionary, fps_scale: float) -> void:
	if not bool(fragment.get("entered_field", true)):
		var entry_margin: float = maxf(12.0, float(fragment.get("size", 12.0)))
		if float(fragment.get("x", 0.0)) <= FIELD_WIDTH + entry_margin:
			fragment["entered_field"] = true
	var right_off_screen: bool = bool(fragment.get("entered_field", true)) and float(fragment.get("x", 0.0)) > FIELD_WIDTH + 30.0
	var off_screen: bool = (
		float(fragment.get("y", 0.0)) >= FIELD_HEIGHT + 10.0
		or float(fragment.get("x", 0.0)) < -30.0
		or right_off_screen
	)
	fragment["lifetime"] = float(fragment.get("lifetime", 0.0)) - maxf(0.0, fps_scale)
	if off_screen or float(fragment.get("lifetime", 0.0)) <= 0.0:
		_mark_fragment_impact(fragment, "expired", {})


func _resolve_player_fragment_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	var player_rect: Rect2 = _get_player_rect(context)
	if player_rect.size.x <= 0.0 or player_rect.size.y <= 0.0:
		return false
	var handled := false
	for fragment_value in moon_fragments:
		if not (fragment_value is Dictionary):
			continue
		var fragment: Dictionary = fragment_value
		if bool(fragment.get("impact", false)) or bool(fragment.get("deflected", false)):
			continue
		var fragment_rect: Rect2 = _get_fragment_rect(fragment)
		if not player_rect.intersects(fragment_rect):
			continue
		if _is_player_fragment_immune(deps):
			_mark_fragment_impact(fragment, "player_immune", deps)
			scene["stage4_moon_fragment_blocked"] = true
			handled = true
			continue
		if _is_dash_active(context, deps):
			_deflect_fragment_to_boss(fragment, _get_boss_rect(context).get_center())
			scene["stage4_moon_fragment_deflected"] = true
			scene["stage4_moon_fragment_deflected_count"] = int(scene.get("stage4_moon_fragment_deflected_count", 0)) + 1
			_play_dash_audio(deps)
			handled = true
			continue
		if _can_fragment_hit_player(fragment):
			_apply_player_fragment_hit(fragment, player_rect, scene, context, deps)
			handled = true
	return handled


func _resolve_boss_fragment_collision(scene: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	var boss_rect: Rect2 = _get_boss_rect(context)
	if boss_rect.size.x <= 0.0 or boss_rect.size.y <= 0.0:
		return false
	for fragment_value in moon_fragments:
		if not (fragment_value is Dictionary):
			continue
		var fragment: Dictionary = fragment_value
		if bool(fragment.get("impact", false)) or not bool(fragment.get("deflected", false)):
			continue
		if not boss_rect.intersects(_get_fragment_rect(fragment)):
			continue
		var knockback_vel: float = BOSS_FRAGMENT_KNOCKBACK if float(fragment.get("x", 0.0)) > boss_rect.get_center().x else -BOSS_FRAGMENT_KNOCKBACK
		var status_state: Object = deps.get("status_effect_state", null)
		if status_state != null and status_state.has_method("apply_status"):
			status_state.apply_status("boss", "stun", BOSS_FRAGMENT_STUN_FRAMES, {
				"knockback_vel": knockback_vel,
				"knockback_active": true,
			}, "stage4_moon_fragment")
		var ai_state: Object = deps.get("ai_state", null)
		if ai_state != null and ai_state.has_method("start_paddle_hit_knockback"):
			ai_state.start_paddle_hit_knockback(knockback_vel, BOSS_FRAGMENT_STUN_FRAMES, 0.85, true)
		scene["boss_vel"] = knockback_vel
		scene["stage4_ponk_gauge_delta"] = float(scene.get("stage4_ponk_gauge_delta", 0.0)) - BOSS_GAUGE_DAMAGE
		scene["stage4_moon_fragment_boss_hit"] = true
		_mark_fragment_impact(fragment, "boss", deps)
		_play_actor_fragment_hit_audio(deps)
		return true
	return false


func _can_fragment_hit_player(fragment: Dictionary) -> bool:
	var fragment_id: int = int(fragment.get("fragment_id", 0))
	var now: float = float(Time.get_ticks_msec())
	var last_hit: float = float(fragment_hit_cooldowns.get(fragment_id, -FRAGMENT_PLAYER_HIT_COOLDOWN_MS))
	if now - last_hit < FRAGMENT_PLAYER_HIT_COOLDOWN_MS:
		return false
	fragment_hit_cooldowns[fragment_id] = now
	return true


func _apply_player_fragment_hit(fragment: Dictionary, player_rect: Rect2, scene: Dictionary, context: Dictionary, deps: Dictionary) -> void:
	player_burn_timer_frames = PLAYER_BURN_FRAMES
	player_burn_total_frames = PLAYER_BURN_FRAMES
	var status_state: Object = deps.get("status_effect_state", null)
	if status_state != null and status_state.has_method("apply_status"):
		status_state.apply_status("player", "burn", PLAYER_BURN_FRAMES, {
			"cleansable": true,
			"visual": "stage4_moon_fragment",
		}, "stage4_moon_fragment")
	var movement_state: Object = deps.get("movement_state", null)
	if movement_state != null and movement_state.has_method("start_knockback"):
		var player_center_x: float = player_rect.get_center().x
		var direction: float = -1.0 if float(fragment.get("x", 0.0)) > player_center_x else 1.0
		movement_state.start_knockback(direction * PLAYER_FRAGMENT_KNOCKBACK, 18.0, 0.88, true, true)
	var current_gauge: float = float(scene.get("special_gauge", context.get("special_gauge", 0.0)))
	scene["special_gauge"] = maxf(0.0, current_gauge - 2.0)
	scene["stage4_player_burn_active"] = true
	scene["stage4_player_burn_timer_frames"] = player_burn_timer_frames
	scene["stage4_moon_fragment_player_hits"] = int(scene.get("stage4_moon_fragment_player_hits", 0)) + 1
	_play_actor_fragment_hit_audio(deps)


func _deflect_fragment_to_boss(fragment: Dictionary, boss_center: Vector2) -> void:
	var pos := Vector2(float(fragment.get("x", 0.0)), float(fragment.get("y", 0.0)))
	var direction: Vector2 = boss_center - pos
	if direction.length() <= 0.001:
		direction = Vector2(-1.0, -0.2)
	direction = direction.normalized()
	fragment["vx"] = direction.x * 12.0
	fragment["vy"] = direction.y * 12.0
	fragment["deflected"] = true
	fragment["entered_field"] = true
	fragment["lifetime"] = maxf(float(fragment.get("lifetime", 0.0)), 90.0)


func _mark_fragment_impact(fragment: Dictionary, reason: String, deps: Dictionary) -> void:
	fragment["impact"] = true
	fragment["impact_timer"] = 30.0
	fragment["shockwave_radius"] = 0.0
	fragment["impact_reason"] = reason
	if reason == "temple":
		_play_fragment_impact_audio(deps)


func _get_player_rect(context: Dictionary) -> Rect2:
	var player_pos: Vector2 = _get_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var player_size: Vector2 = _get_vector2(
		context.get("player_paddle_size", Vector2(float(context.get("paddle_width", 155.0)), float(context.get("paddle_height", 50.0)))),
		Vector2(155.0, 50.0)
	)
	return Rect2(player_pos, player_size)


func _get_boss_rect(context: Dictionary) -> Rect2:
	var boss_pos: Vector2 = _get_vector2(context.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_size: Vector2 = _get_vector2(
		context.get("boss_paddle_size", Vector2(float(context.get("boss_paddle_width", 100.0)), float(context.get("boss_hitbox_height", 40.0)))),
		Vector2(100.0, 40.0)
	)
	return Rect2(boss_pos, boss_size)


func _get_fragment_rect(fragment: Dictionary) -> Rect2:
	var radius: float = maxf(1.0, float(fragment.get("size", 10.0)))
	var pos := Vector2(float(fragment.get("x", 0.0)), float(fragment.get("y", 0.0)))
	return Rect2(pos - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))


func _get_temple_hitbox() -> Rect2:
	return Rect2(250.0, 120.0, 260.0, 330.0)


func _is_dash_active(context: Dictionary, deps: Dictionary) -> bool:
	var dash_snapshot: Dictionary = _as_dictionary(context.get("dash_snapshot", {}))
	if bool(dash_snapshot.get("active", false)):
		return true
	var dash_state: Object = deps.get("dash_state", null)
	if dash_state != null:
		if dash_state.has_method("is_active") and bool(dash_state.is_active()):
			return true
		if dash_state.has_method("get_snapshot"):
			var snapshot: Dictionary = dash_state.get_snapshot()
			return bool(snapshot.get("active", false))
	return bool(context.get("dash_active", false))


func _is_player_fragment_immune(deps: Dictionary) -> bool:
	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	return cleanse_state != null and cleanse_state.has_method("is_immune") and bool(cleanse_state.is_immune())


func _get_player_burn_ratio() -> float:
	return clampf(player_burn_timer_frames / maxf(0.001, player_burn_total_frames), 0.0, 1.0)


func _draw_array(source: Array, copy_arrays: bool) -> Array:
	return source.duplicate(true) if copy_arrays else source


func _play_fragment_shoot_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage4_fragment_shoot"):
		audio.play_stage4_fragment_shoot()


func _play_fragment_impact_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage4_temple_hit"):
		audio.play_stage4_temple_hit()
	elif audio != null and audio.has_method("play_stage4_birdkill"):
		audio.play_stage4_birdkill()


func _play_actor_fragment_hit_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage4_birdkill"):
		audio.play_stage4_birdkill()
	elif audio != null and audio.has_method("play_stage4_temple_hit"):
		audio.play_stage4_temple_hit()


func _play_dash_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_dash"):
		audio.play_dash()


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return fallback
