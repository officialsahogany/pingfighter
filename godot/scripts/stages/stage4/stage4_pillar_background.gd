extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage4MoonEvent := preload("res://scripts/stages/stage4/stage4_moon_event.gd")
const Stage4PillarBackgroundPayloadFactory := preload("res://scripts/stages/stage4/stage4_pillar_background_payload_factory.gd")

const NIGHTSKY_PRIMARY_PATH := "res://assets/sprites/hud/stage4_empty_temple_nightsky_base_imagegen_v4_nomoon.png"
const NIGHTSKY_FALLBACK_PATH := "res://assets/sprites/hud/stage4_empty_temple_nightsky_base_imagegen_v3.png"
const TIBETAN_MOTION_PATH := "res://assets/sprites/hud/stage4_tibetan_cyber_temple_motion_sprites_imagegen_v2.png"
const STAGE4_TEMPLE_MOTION_ENABLED := false
const WALL_IMPACT_FLASH_SEC := 0.24
const WALL_IMPACT_ACCENT_MAX := 8

var nightsky_primary: Texture2D = null
var nightsky_fallback: Texture2D = null
var tibetan_motion: Texture2D = null
var textures_loaded := false
var moon_event: Object = Stage4MoonEvent.new()
var time_sec := 0.0
var last_stage4_context: Dictionary = {}
var last_stage4_deps: Dictionary = {}
var last_map_state: Object = null
var last_moon_center := Vector2.ZERO
var wall_shake_accents: Array = []
var _prewarm_assets_step_index := 0
var _texture_prewarm_step_index := 0


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	match _prewarm_assets_step_index:
		0:
			if not _prewarm_texture_step():
				return false
		1:
			if moon_event != null:
				if moon_event.has_method("prewarm_assets_step"):
					if not bool(moon_event.prewarm_assets_step()):
						return false
				elif moon_event.has_method("prewarm_assets"):
					moon_event.prewarm_assets()
		_:
			_prewarm_assets_step_index = 0
			return true
	_prewarm_assets_step_index += 1
	if _prewarm_assets_step_index > 1:
		_prewarm_assets_step_index = 0
		return true
	return false


func reset() -> void:
	time_sec = 0.0
	last_stage4_context.clear()
	last_stage4_deps.clear()
	last_map_state = null
	last_moon_center = Vector2.ZERO
	wall_shake_accents.clear()
	if moon_event != null and moon_event.has_method("reset"):
		moon_event.reset()


func update(delta: float, context: Dictionary = {}, deps: Dictionary = {}) -> void:
	var clamped_delta: float = maxf(0.0, delta)
	time_sec += clamped_delta
	_update_wall_shake_accents(clamped_delta)
	# Shallow copy is safe: no consumer mutates nested context values; :79/:85 merges
	# add top-level keys only, moon_event.update reads context read-only, and every
	# cached read (:160/:181/:197/:435) is a top-level scalar. Avoids a ~55-key/frame deep copy.
	last_stage4_context = context.duplicate()
	last_stage4_deps = deps.duplicate()
	var map_state: Object = deps.get("stage4_map_state", null)
	last_map_state = map_state
	if map_state != null:
		if map_state.has_method("update"):
			map_state.update(delta, context, deps)
		if map_state.has_method("get_draw_context"):
			last_stage4_context.merge(map_state.get_draw_context(deps), true)
	else:
		var destruction: Object = deps.get("stage4_temple_destruction_event", null)
		if destruction != null and destruction.has_method("update"):
			destruction.update(delta, context, deps)
		if destruction != null and destruction.has_method("get_snapshot"):
			last_stage4_context.merge(destruction.get_snapshot(), true)
	var active_moon_event: Object = _resolve_moon_event(deps)
	if active_moon_event != null and active_moon_event.has_method("update") and (map_state == null or not _has_direct_moon_event(deps)):
		active_moon_event.update(delta, last_stage4_context, deps)


func draw(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2, _field_width: float) -> bool:
	if canvas == null or view_size.x <= 0.0 or view_size.y <= 0.0:
		return false
	_ensure_textures()
	_draw_background_layers(canvas, view_size, game_offset, game_size)
	_draw_motion_layers(canvas, view_size, game_offset, game_size)
	_draw_wall_shake_accents(canvas, game_offset, game_size)
	var active_moon_event: Object = _resolve_moon_event()
	if active_moon_event != null and active_moon_event.has_method("draw_moon"):
		last_moon_center = active_moon_event.draw_moon(canvas, view_size, game_offset, game_size)
	_draw_red_overlay(canvas, view_size)
	return true


func set_stage4_red_moon_state(intensity: float, scale: float, phase: float) -> bool:
	var active_moon_event: Object = _resolve_moon_event()
	if active_moon_event != null and active_moon_event.has_method("set_stage4_red_moon_state"):
		return bool(active_moon_event.set_stage4_red_moon_state(intensity, scale, phase))
	return false


func get_stage4_moon_center() -> Vector2:
	var active_moon_event: Object = _resolve_moon_event()
	if active_moon_event != null and active_moon_event.has_method("get_stage4_moon_center"):
		var center: Variant = active_moon_event.get_stage4_moon_center()
		if center is Vector2:
			return center
	return last_moon_center


func is_stage4_red_moon_active() -> bool:
	var active_moon_event: Object = _resolve_moon_event()
	if active_moon_event != null and active_moon_event.has_method("is_stage4_red_moon_active"):
		return bool(active_moon_event.is_stage4_red_moon_active())
	return false


func check_smoke_touches_brazier(smoke_x: float, smoke_y: float, smoke_radius: float, deps: Dictionary = {}) -> bool:
	var resolved_deps: Dictionary = _merge_cached_deps(deps)
	var map_state: Object = _get_cached_map_state(resolved_deps)
	if map_state != null and map_state.has_method("check_smoke_touches_brazier"):
		return bool(map_state.check_smoke_touches_brazier(smoke_x, smoke_y, smoke_radius, resolved_deps))
	return false


func trigger_smoke_grenade_monk_return(deps: Dictionary = {}) -> int:
	var resolved_deps: Dictionary = _merge_cached_deps(deps)
	var map_state: Object = _get_cached_map_state(resolved_deps)
	if map_state != null and map_state.has_method("trigger_smoke_grenade_monk_return"):
		return int(map_state.trigger_smoke_grenade_monk_return(resolved_deps))
	var monk_event: Object = _get_cached_stage4_event("stage4_brazier_monk_event", resolved_deps)
	if monk_event != null and monk_event.has_method("trigger_smoke_grenade_monk_return"):
		return int(monk_event.trigger_smoke_grenade_monk_return())
	return 0


func get_brazier_position() -> Vector2:
	var map_state: Object = _get_cached_map_state()
	if map_state != null and map_state.has_method("get_brazier_position"):
		var pos: Variant = map_state.get_brazier_position()
		if pos is Vector2:
			return pos
	return Vector2(380.0, 570.0)


func is_brazier_lit() -> bool:
	var map_state: Object = _get_cached_map_state()
	if map_state != null and map_state.has_method("is_brazier_lit"):
		return bool(map_state.is_brazier_lit())
	return bool(last_stage4_context.get("stage4_brazier_lit", false))


func get_crow_positions() -> Array:
	var bird_event: Object = _get_cached_stage4_event("stage4_bird_event")
	if bird_event != null and bird_event.has_method("get_crow_positions"):
		var positions: Variant = bird_event.get_crow_positions()
		if positions is Array:
			return positions
	return []


func catch_crow(index: int, deps: Dictionary = {}, context: Dictionary = {}) -> bool:
	var resolved_deps: Dictionary = _merge_cached_deps(deps)
	var bird_event: Object = _get_cached_stage4_event("stage4_bird_event", resolved_deps)
	if bird_event != null and bird_event.has_method("catch_crow"):
		return bool(bird_event.catch_crow(index, resolved_deps, context))
	return false


func resolve_ball_collision(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> bool:
	var current_stage: int = int(context.get("current_stage", last_stage4_context.get("current_stage", 4)))
	if current_stage != 4:
		return false
	var resolved_deps: Dictionary = _merge_cached_deps(deps)
	var handled := false
	if _resolve_star_bird_collision(scene, context, resolved_deps):
		handled = true
	if _resolve_monk_staff_collision(scene, context, resolved_deps):
		handled = true
	if _resolve_moon_fragment_collision(scene, context, resolved_deps):
		handled = true
	if _resolve_ponk_skill_collision(scene, context, resolved_deps):
		handled = true
	return handled


func apply_ball_motion(scene: Dictionary, context: Dictionary, deps: Dictionary = {}, fps_scale: float = 1.0) -> bool:
	var current_stage: int = int(context.get("current_stage", last_stage4_context.get("current_stage", 4)))
	if current_stage != 4:
		return false
	var resolved_deps: Dictionary = _merge_cached_deps(deps)
	var ponk_skill_state: Object = _resolve_ponk_skill_state(resolved_deps)
	if ponk_skill_state == null or not ponk_skill_state.has_method("apply_ball_motion"):
		return false
	return bool(ponk_skill_state.apply_ball_motion(scene, context, resolved_deps, fps_scale))


func trigger_tree_shake(side: String, impact_y: float, impact_speed: float, field_height: float) -> void:
	var resolved_side: String = side.strip_edges().to_lower()
	if resolved_side not in ["left", "right"]:
		return
	var height: float = maxf(1.0, field_height)
	var y_ratio: float = clampf(impact_y / height, 0.03, 0.97)
	var speed_scale: float = clampf(abs(impact_speed) / 640.0, 0.35, 1.65)
	wall_shake_accents.append(Stage4PillarBackgroundPayloadFactory.build_wall_shake_accent(
		resolved_side,
		y_ratio,
		speed_scale,
		WALL_IMPACT_FLASH_SEC
	))
	while wall_shake_accents.size() > WALL_IMPACT_ACCENT_MAX:
		wall_shake_accents.pop_front()


func _resolve_star_bird_collision(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> bool:
	var resolved_deps: Dictionary = deps  # already merged by resolve_ball_collision (single caller)
	var bird_event: Object = _get_cached_stage4_event("stage4_bird_event", resolved_deps)
	if bird_event == null or not bird_event.has_method("get_crow_positions"):
		return false
	if bird_event.has_method("resolve_ball_collision"):
		return bool(bird_event.resolve_ball_collision(scene, context, resolved_deps))
	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", _get_vector2(context, "ball_pos", Vector2.ZERO))
	var ball_radius: float = maxf(
		float(context.get("ball_size", 28.6)) * 0.5,
		float(context.get("ball_render_radius", float(context.get("ball_size", 28.6)) * 0.5))
	)
	for crow_value in bird_event.get_crow_positions():
		if not (crow_value is Dictionary):
			continue
		var crow: Dictionary = crow_value
		var crow_pos := Vector2(float(crow.get("x", 0.0)), float(crow.get("y", 0.0)))
		var crow_radius: float = maxf(1.0, float(crow.get("radius", 25.0)))
		if ball_pos.distance_to(crow_pos) > crow_radius + ball_radius:
			continue
		var crow_index: int = int(crow.get("index", -1))
		if not catch_crow(crow_index, resolved_deps, context):
			continue
		scene["stage4_star_bird_caught"] = true
		scene["stage4_star_bird_caught_index"] = crow_index
		scene["stage4_star_bird_caught_pos"] = crow_pos
		scene["stage4_star_bird_caught_count"] = int(scene.get("stage4_star_bird_caught_count", 0)) + 1
		_play_star_bird_hit_audio(resolved_deps)
		return true
	return false


func _resolve_monk_staff_collision(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> bool:
	var resolved_deps: Dictionary = deps  # already merged by resolve_ball_collision (single caller)
	var monk_event: Object = _get_cached_stage4_event("stage4_brazier_monk_event", resolved_deps)
	if monk_event == null:
		return false
	var ball_pos: Vector2 = _get_vector2(scene, "ball_pos", _get_vector2(context, "ball_pos", Vector2.ZERO))
	var last_hit_by: String = _get_last_hit_by(context, resolved_deps)
	if monk_event.has_method("trigger_monk_swing"):
		monk_event.trigger_monk_swing(ball_pos.x, ball_pos.y, last_hit_by)
	if not monk_event.has_method("get_monk_staff_deflection"):
		return false
	var deflection_result: Variant = monk_event.get_monk_staff_deflection(ball_pos.x, ball_pos.y)
	if not (deflection_result is Dictionary) or (deflection_result as Dictionary).is_empty():
		return false
	var result: Dictionary = deflection_result
	var deflection: Vector2 = _as_vector2(result.get("deflection", Vector2.ZERO), Vector2.ZERO)
	if deflection.length() <= 0.001:
		return false
	var ball_vel: Vector2 = _get_vector2(scene, "ball_vel", _get_vector2(context, "ball_vel", Vector2.ZERO))
	var current_speed: float = maxf(ball_vel.length(), float(context.get("min_ball_speed", 3.0)))
	var new_speed: float = minf(35.0, current_speed * clampf(float(result.get("speed_multiplier", 1.65)), 1.0, 2.1))
	var next_vel: Vector2 = ball_vel + deflection * 5.0
	if next_vel.length() <= 0.001:
		next_vel = deflection
	var final_vel: Vector2 = next_vel.normalized() * new_speed
	scene["ball_vel"] = final_vel
	scene["ball_spin_strength"] = 0.3
	scene["ball_spin_direction"] = 1 if deflection.x > 0.0 else -1
	scene["stage4_monk_staff_hit"] = true
	scene["stage4_monk_staff_hit_count"] = int(scene.get("stage4_monk_staff_hit_count", 0)) + 1
	_play_monk_staff_audio(resolved_deps, new_speed)
	_register_stage4_hit_pulse(resolved_deps, ball_pos, final_vel, "stage4_monk_staff")
	return true


func _resolve_moon_fragment_collision(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> bool:
	var resolved_deps: Dictionary = deps  # already merged by resolve_ball_collision (single caller)
	var active_moon_event: Object = _resolve_moon_event(resolved_deps)
	if active_moon_event == null or not active_moon_event.has_method("resolve_fragment_collisions"):
		return false
	var handled: bool = bool(active_moon_event.resolve_fragment_collisions(scene, context, resolved_deps))
	if handled and scene.has("stage4_ponk_gauge_delta"):
		var ponk_skill_state: Object = _resolve_ponk_skill_state(resolved_deps)
		if ponk_skill_state != null and ponk_skill_state.has_method("apply_gauge_delta"):
			ponk_skill_state.apply_gauge_delta(float(scene.get("stage4_ponk_gauge_delta", 0.0)))
	return handled


func _resolve_ponk_skill_collision(scene: Dictionary, context: Dictionary, deps: Dictionary = {}) -> bool:
	var resolved_deps: Dictionary = deps  # already merged by resolve_ball_collision (single caller)
	var ponk_skill_state: Object = _resolve_ponk_skill_state(resolved_deps)
	if ponk_skill_state == null or not ponk_skill_state.has_method("resolve_ball_collision"):
		return false
	return bool(ponk_skill_state.resolve_ball_collision(scene, context, resolved_deps))


func draw_pillar_moon_fragment_overlay(_canvas: CanvasItem, _context: Dictionary = {}) -> void:
	pass


func draw_pillar_destruction_wave_overlay(_canvas: CanvasItem, _context: Dictionary = {}) -> void:
	pass


func get_imagegen_asset_status() -> Dictionary:
	_ensure_textures()
	var active_moon_event: Object = _resolve_moon_event()
	var moon_status: Dictionary = active_moon_event.get_asset_status() if active_moon_event != null and active_moon_event.has_method("get_asset_status") else {}
	return {
		"nightsky_primary": nightsky_primary != null,
		"nightsky_fallback": nightsky_fallback != null,
		"original_temple_base": nightsky_primary != null,
		"temple_motion_enabled": STAGE4_TEMPLE_MOTION_ENABLED,
		"tibetan_motion": STAGE4_TEMPLE_MOTION_ENABLED and tibetan_motion != null,
		"moon_white": bool(moon_status.get("white_sheet", false)),
		"moon_red_transform": bool(moon_status.get("red_transform_sheet", false)),
		"moon_red_burst": bool(moon_status.get("red_burst_sheet", false)),
		"moon_frame_count": int(moon_status.get("moon_frame_count", 0)),
		"moon_fragment_atlas": bool(moon_status.get("fragment_atlas", false)),
		"moon_fragment_frame_count": int(moon_status.get("fragment_frame_count", 0)),
	}


func _ensure_textures() -> void:
	if textures_loaded:
		return
	while not _prewarm_texture_step():
		pass


func _prewarm_texture_step() -> bool:
	if textures_loaded:
		return true
	match _texture_prewarm_step_index:
		0:
			nightsky_primary = ProjectResourceLoader.load_texture(NIGHTSKY_PRIMARY_PATH)
		1:
			nightsky_fallback = ProjectResourceLoader.load_texture(NIGHTSKY_FALLBACK_PATH)
		2:
			if STAGE4_TEMPLE_MOTION_ENABLED:
				tibetan_motion = ProjectResourceLoader.load_texture(TIBETAN_MOTION_PATH)
		_:
			textures_loaded = true
			_texture_prewarm_step_index = 0
			return true
	_texture_prewarm_step_index += 1
	if _texture_prewarm_step_index > 2:
		textures_loaded = true
		_texture_prewarm_step_index = 0
		return true
	return false


func _draw_background_layers(canvas: CanvasItem, view_size: Vector2, _game_offset: Vector2, _game_size: Vector2) -> void:
	var drew := false
	var base: Texture2D = nightsky_primary if nightsky_primary != null else nightsky_fallback
	if base != null:
		_draw_cover_texture(canvas, base, Rect2(Vector2.ZERO, view_size), Color(1.0, 1.0, 1.0, 1.0))
		drew = true
	if not drew:
		_draw_fallback_background(canvas, view_size)


func _draw_motion_layers(canvas: CanvasItem, view_size: Vector2, game_offset: Vector2, game_size: Vector2) -> void:
	if not STAGE4_TEMPLE_MOTION_ENABLED:
		return
	if tibetan_motion != null:
		var pulse: float = 0.5 + 0.5 * sin(time_sec * 1.7)
		var alpha: float = 0.08 + (1.0 - pulse) * 0.05
		var left_w: float = maxf(0.0, game_offset.x)
		var right_x: float = game_offset.x + game_size.x
		var right_w: float = maxf(0.0, view_size.x - right_x)
		if left_w > 24.0:
			_draw_cover_texture(canvas, tibetan_motion, Rect2(0.0, 0.0, left_w, view_size.y), Color(0.64, 0.92, 1.0, alpha))
		if right_w > 24.0:
			_draw_cover_texture(canvas, tibetan_motion, Rect2(right_x, 0.0, right_w, view_size.y), Color(1.0, 0.58, 0.44, alpha))


func _update_wall_shake_accents(delta: float) -> void:
	if wall_shake_accents.is_empty():
		return
	var alive: Array = []
	for accent_value in wall_shake_accents:
		if not (accent_value is Dictionary):
			continue
		var accent: Dictionary = accent_value
		var timer: float = float(accent.get("timer", 0.0)) - delta
		if timer <= 0.0:
			continue
		accent["timer"] = timer
		alive.append(accent)
	wall_shake_accents = alive


func _draw_wall_shake_accents(canvas: CanvasItem, game_offset: Vector2, game_size: Vector2) -> void:
	if wall_shake_accents.is_empty() or game_size.x <= 0.0 or game_size.y <= 0.0:
		return
	for accent_value in wall_shake_accents:
		if not (accent_value is Dictionary):
			continue
		var accent: Dictionary = accent_value
		var side: String = str(accent.get("side", "left"))
		var duration: float = maxf(0.001, float(accent.get("duration", WALL_IMPACT_FLASH_SEC)))
		var timer: float = clampf(float(accent.get("timer", duration)), 0.0, duration)
		var life: float = timer / duration
		var speed_scale: float = clampf(float(accent.get("speed_scale", 1.0)), 0.35, 1.65)
		var x: float = game_offset.x if side == "left" else game_offset.x + game_size.x
		var y: float = game_offset.y + game_size.y * clampf(float(accent.get("y_ratio", 0.5)), 0.0, 1.0)
		var dir: float = -1.0 if side == "left" else 1.0
		var reach: float = 20.0 + 42.0 * speed_scale
		var alpha: float = life * (0.42 + speed_scale * 0.12)
		var core := Vector2(x, y)
		canvas.draw_line(core, Vector2(x + dir * reach, y), Color(1.0, 0.36, 0.16, alpha), 2.0 + speed_scale * 1.8, true)
		canvas.draw_line(Vector2(x, y - 10.0 * speed_scale), Vector2(x + dir * reach * 0.72, y - 4.0 * speed_scale), Color(0.32, 0.96, 1.0, alpha * 0.55), 1.25 + speed_scale, true)
		canvas.draw_line(Vector2(x, y + 10.0 * speed_scale), Vector2(x + dir * reach * 0.72, y + 4.0 * speed_scale), Color(1.0, 0.18, 0.10, alpha * 0.44), 1.25 + speed_scale, true)
		canvas.draw_circle(core, 5.0 + speed_scale * 5.0, Color(1.0, 0.62, 0.24, alpha * 0.42))


func _draw_red_overlay(canvas: CanvasItem, view_size: Vector2) -> void:
	var red_alpha: float = clampf(float(last_stage4_context.get("stage4_red_light_alpha", 0.0)), 0.0, 1.0)
	if red_alpha > 0.01:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(1.0, 0.03, 0.02, red_alpha * 0.28))


func _draw_cover_texture(canvas: CanvasItem, texture: Texture2D, target: Rect2, modulate: Color) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0 or target.size.x <= 0.0 or target.size.y <= 0.0:
		return
	var scale_factor: float = maxf(target.size.x / texture_size.x, target.size.y / texture_size.y)
	var source_size: Vector2 = target.size / maxf(0.001, scale_factor)
	var source_pos: Vector2 = (texture_size - source_size) * 0.5
	canvas.draw_texture_rect_region(texture, target, Rect2(source_pos, source_size), modulate, false, true)


func _draw_fallback_background(canvas: CanvasItem, view_size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.025, 0.018, 0.042, 1.0))
	for idx in range(64):
		var x: float = fposmod(float(idx * 59) + time_sec * 8.0, view_size.x)
		var y: float = fposmod(float(idx * 37), view_size.y)
		canvas.draw_circle(Vector2(x, y), 1.0 + float(idx % 3) * 0.35, Color(0.82, 0.92, 1.0, 0.30))


func _get_cached_map_state(deps: Dictionary = {}) -> Object:
	var direct_value: Variant = deps.get("stage4_map_state", null)
	if typeof(direct_value) == TYPE_OBJECT and direct_value != null:
		return direct_value as Object
	if last_map_state != null:
		return last_map_state
	var value: Variant = last_stage4_deps.get("stage4_map_state", null)
	if typeof(value) == TYPE_OBJECT and value != null:
		return value as Object
	return null


func _get_cached_stage4_event(key: String, deps: Dictionary = {}) -> Object:
	var value: Variant = deps.get(key, null)
	if typeof(value) == TYPE_OBJECT and value != null:
		return value as Object
	value = last_stage4_deps.get(key, null)
	if typeof(value) == TYPE_OBJECT and value != null:
		return value as Object
	return null


func _resolve_moon_event(deps: Dictionary = {}) -> Object:
	var value: Variant = deps.get("stage4_moon_event", null)
	if typeof(value) == TYPE_OBJECT and value != null:
		return value as Object
	value = last_stage4_deps.get("stage4_moon_event", null)
	if typeof(value) == TYPE_OBJECT and value != null:
		return value as Object
	return moon_event


func _resolve_ponk_skill_state(deps: Dictionary = {}) -> Object:
	var value: Variant = deps.get("stage4_ponk_skill_state", null)
	if typeof(value) == TYPE_OBJECT and value != null:
		return value as Object
	value = last_stage4_deps.get("stage4_ponk_skill_state", null)
	if typeof(value) == TYPE_OBJECT and value != null:
		return value as Object
	return null


func _has_direct_moon_event(deps: Dictionary) -> bool:
	var value: Variant = deps.get("stage4_moon_event", null)
	return typeof(value) == TYPE_OBJECT and value != null


func _merge_cached_deps(deps: Dictionary) -> Dictionary:
	if deps.is_empty():
		return last_stage4_deps.duplicate()
	var merged: Dictionary = last_stage4_deps.duplicate()
	merged.merge(deps, true)
	return merged


func _play_star_bird_hit_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_stage4_birdkill"):
		audio.play_stage4_birdkill()
	elif audio.has_method("play_stage4_fragment_shoot"):
		audio.play_stage4_fragment_shoot()


func _play_monk_staff_audio(deps: Dictionary, impact_speed: float) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_wall_hit"):
		audio.play_wall_hit(impact_speed)
	elif audio.has_method("play_stage4_temple_hit"):
		audio.play_stage4_temple_hit()


func _register_stage4_hit_pulse(deps: Dictionary, pos: Vector2, vel: Vector2, kind: String) -> void:
	var ball_effects: Object = deps.get("ball_effects", null)
	if ball_effects != null and ball_effects.has_method("register_hit_pulse"):
		ball_effects.register_hit_pulse(pos, vel, 0.64, kind)


func _get_last_hit_by(context: Dictionary, deps: Dictionary) -> String:
	var direct := str(context.get("last_hit_by", "")).strip_edges().to_lower()
	if direct in ["player", "boss"]:
		return direct
	var ball_intensity: Object = deps.get("ball_intensity", null)
	if ball_intensity != null and ball_intensity.has_method("get_last_hit_by"):
		var value := str(ball_intensity.get_last_hit_by()).strip_edges().to_lower()
		if value in ["player", "boss"]:
			return value
	return "player"


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = source.get(key, fallback)
	if value is Vector2:
		return value
	return fallback


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return fallback
