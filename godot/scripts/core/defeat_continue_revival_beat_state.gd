extends RefCounted

const BattleCoreTexturePaths := preload("res://scripts/resources/battle_core_texture_paths.gd")
const BattleDrawActorResultContext := preload("res://scripts/core/battle_draw_actor_result_context.gd")
const BattleViewLayout := preload("res://scripts/core/battle_view_layout.gd")
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const FIELD_SIZE := Vector2(760.0, 750.0)
const FALLBACK_VIEW_SIZE := Vector2(1280.0, 720.0)
const DEFEAT_HOLD_SEC := 0.75
const GEM_FLIGHT_SEC := 0.55
const ABSORB_FLASH_SEC := 0.28
const VICTORY_PULSE_SEC := 1.35
const WALL_CLOCK_FAILSAFE_GRACE_SEC := 0.80
const GEM_DRAW_SIZE := Vector2(36.0, 56.0)
const TRAIL_SAMPLES := 7
const SACRED_RAY_COUNT := 10
const SACRED_MOTE_COUNT := 16
const COLOR_RESTORE_FEATHER_MIN := 48.0
const COLOR_RESTORE_FEATHER_RATIO := 0.085

const PHASE_DEFEAT_HOLD := "defeat_hold"
const PHASE_GEM_FLIGHT := "gem_flight"
const PHASE_ABSORB_FLASH := "absorb_flash"
const PHASE_VICTORY_PULSE := "victory_pulse"

var active: bool = false
var elapsed_sec: float = 0.0
var selected_character_type: String = PlayerCharacterRuntime.SMASHER
var full_pose_enabled: bool = false
var source_screen_pos: Vector2 = Vector2.ZERO
var last_target_screen_pos: Vector2 = Vector2.ZERO
var last_view_size: Vector2 = FALLBACK_VIEW_SIZE
var _owner: Object = null
var _started_msec: int = 0

var _character_runtime: Object = PlayerCharacterRuntime.new()
var _layout: Object = BattleViewLayout.new()


static func prewarm_assets() -> void:
	ProjectResourceLoader.load_imported_texture(
		BattleCoreTexturePaths.CHANCE_GEM_FULL_TEXTURE_PATH,
		"Missing chance gem full texture at %s",
		"Failed to load chance gem full texture at %s"
	)
	ImpactFlareTextureCache.prewarm()


static func is_full_pose_character(character_type: Variant) -> bool:
	var normalized := PlayerCharacterRuntime.new().normalize(character_type)
	return (
		normalized == PlayerCharacterRuntime.SMASHER
		or normalized == PlayerCharacterRuntime.VIPER
		or normalized == PlayerCharacterRuntime.BLACKSMITH
	)


func start(owner: Object, source_pos: Vector2, view_size: Vector2 = Vector2.ZERO) -> void:
	prewarm_assets()
	active = true
	elapsed_sec = 0.0
	_owner = owner
	_started_msec = Time.get_ticks_msec()
	selected_character_type = _character_runtime.normalize(_get_owner_value(owner, "selected_character_type", PlayerCharacterRuntime.SMASHER))
	full_pose_enabled = is_full_pose_character(selected_character_type)
	last_view_size = view_size if view_size.x > 1.0 and view_size.y > 1.0 else FALLBACK_VIEW_SIZE
	last_target_screen_pos = _get_player_center_screen(owner, last_view_size)
	source_screen_pos = source_pos if source_pos != Vector2.ZERO else last_target_screen_pos + Vector2(0.0, -180.0)
	_write_owner_state(owner)


func reset(owner: Object = null) -> void:
	active = false
	elapsed_sec = 0.0
	source_screen_pos = Vector2.ZERO
	last_target_screen_pos = Vector2.ZERO
	_owner = null
	_started_msec = 0
	selected_character_type = PlayerCharacterRuntime.SMASHER
	full_pose_enabled = false
	_write_owner_state(owner)


func update(delta: float, owner: Object, view_size: Vector2 = Vector2.ZERO) -> void:
	if not active:
		return
	_owner = owner
	_expire_if_wall_clock_timed_out()
	if not active:
		return
	elapsed_sec += maxf(0.0, delta)
	if view_size.x > 1.0 and view_size.y > 1.0:
		last_view_size = view_size
	last_target_screen_pos = _get_player_center_screen(owner, last_view_size)
	if elapsed_sec >= get_total_duration():
		reset(owner)
		return
	_write_owner_state(owner)


func is_active() -> bool:
	_expire_if_wall_clock_timed_out()
	return active


func blocks_battle_physics() -> bool:
	_expire_if_wall_clock_timed_out()
	return active


func has_actor_draw_context() -> bool:
	_expire_if_wall_clock_timed_out()
	return active


func get_total_duration() -> float:
	return DEFEAT_HOLD_SEC + GEM_FLIGHT_SEC + ABSORB_FLASH_SEC + VICTORY_PULSE_SEC


func get_phase() -> String:
	if not active:
		return ""
	if elapsed_sec < DEFEAT_HOLD_SEC:
		return PHASE_DEFEAT_HOLD
	if elapsed_sec < DEFEAT_HOLD_SEC + GEM_FLIGHT_SEC:
		return PHASE_GEM_FLIGHT
	if elapsed_sec < DEFEAT_HOLD_SEC + GEM_FLIGHT_SEC + ABSORB_FLASH_SEC:
		return PHASE_ABSORB_FLASH
	return PHASE_VICTORY_PULSE


func get_actor_draw_context() -> Dictionary:
	_expire_if_wall_clock_timed_out()
	if not active:
		return {}
	var phase := get_phase()
	var context := {
		"defeat_continue_revival_beat_active": true,
		"defeat_continue_revival_beat_phase": phase,
		"player_continue_absorb_glow_ratio": _get_absorb_glow_ratio(),
	}
	if not full_pose_enabled:
		return context
	if phase == PHASE_VICTORY_PULSE:
		var victory_elapsed := maxf(0.0, elapsed_sec - (DEFEAT_HOLD_SEC + GEM_FLIGHT_SEC + ABSORB_FLASH_SEC))
		context["player_victory_active"] = true
		context["player_victory_frame"] = _get_victory_frame(victory_elapsed)
		return context
	context["player_defeat_active"] = true
	var defeat_frame := _get_defeat_frame(minf(elapsed_sec, DEFEAT_HOLD_SEC + GEM_FLIGHT_SEC))
	context["player_defeat_frame"] = defeat_frame
	context["player_defeat_frame_64"] = defeat_frame
	return context


func draw_overlay(canvas: CanvasItem, owner: Object, view_size: Vector2) -> void:
	_expire_if_wall_clock_timed_out()
	if canvas == null or not active:
		return
	_owner = owner
	var safe_view_size := view_size if view_size.x > 1.0 and view_size.y > 1.0 else last_view_size
	var target := _get_player_center_screen(owner, safe_view_size)
	last_target_screen_pos = target
	var flight_progress := _get_flight_progress()
	var absorb_progress := _get_absorb_progress()
	var draw_pos := _bezier(source_screen_pos, source_screen_pos.lerp(target, 0.62) + Vector2(0.0, -130.0), target, flight_progress)
	_draw_flight_trail(canvas, target, flight_progress)
	_draw_sacred_revival_overlay(canvas, target, safe_view_size)
	if flight_progress < 1.0:
		_draw_flying_gem(canvas, draw_pos, flight_progress)
	if absorb_progress > 0.0:
		_draw_absorb_burst(canvas, target, absorb_progress)


func get_status_for_tests() -> Dictionary:
	_expire_if_wall_clock_timed_out()
	return {
		"active": active,
		"elapsed": elapsed_sec,
		"phase": get_phase(),
		"blocks_battle_physics": blocks_battle_physics(),
		"selected_character_type": selected_character_type,
		"full_pose_enabled": full_pose_enabled,
		"source_screen_pos": source_screen_pos,
		"target_screen_pos": last_target_screen_pos,
		"absorb_glow_ratio": _get_absorb_glow_ratio(),
		"sacred_overlay": get_sacred_overlay_status(),
		"total_duration": get_total_duration(),
	}


func get_sacred_overlay_status() -> Dictionary:
	_expire_if_wall_clock_timed_out()
	return {
		"active": active and _get_sacred_total_strength() > 0.001,
		"trail_strength": _get_sacred_trail_strength(),
		"bloom_strength": _get_sacred_bloom_strength(),
		"flash_alpha": _get_sacred_flash_alpha(),
		"ray_alpha": _get_sacred_ray_alpha(),
		"mote_alpha": _get_sacred_mote_alpha(),
		"warm_ratio": _get_sacred_warm_ratio(),
	}


func get_color_restore_status(view_size: Vector2 = Vector2.ZERO) -> Dictionary:
	_expire_if_wall_clock_timed_out()
	var safe_view_size := view_size if view_size.x > 1.0 and view_size.y > 1.0 else last_view_size
	if safe_view_size.x <= 1.0 or safe_view_size.y <= 1.0:
		safe_view_size = FALLBACK_VIEW_SIZE
	var center := last_target_screen_pos
	if center == Vector2.ZERO:
		center = _get_player_center_screen(_owner, safe_view_size)
	var max_radius := _get_color_restore_max_radius(center, safe_view_size)
	var feather := maxf(COLOR_RESTORE_FEATHER_MIN, minf(safe_view_size.x, safe_view_size.y) * COLOR_RESTORE_FEATHER_RATIO)
	var phase := get_phase()
	var desaturate_amount := 0.0
	var restore_radius := 0.0
	if active:
		desaturate_amount = 1.0
		if phase == PHASE_VICTORY_PULSE:
			restore_radius = max_radius * _ease_out_cubic(_get_victory_progress())
	return {
		"active": active and desaturate_amount > 0.001,
		"phase": phase,
		"elapsed": elapsed_sec,
		"center_px": center,
		"view_size_px": safe_view_size,
		"desaturate_amount": desaturate_amount,
		"restore_radius_px": restore_radius,
		"feather_px": feather,
		"max_radius_px": max_radius,
		"absorb_progress": _get_absorb_progress(),
		"victory_progress": _get_victory_progress(),
		"single_clock": true,
	}


func force_wall_clock_timeout_for_tests() -> void:
	_started_msec = Time.get_ticks_msec() - int(round((get_total_duration() + WALL_CLOCK_FAILSAFE_GRACE_SEC + 1.0) * 1000.0))


func _get_victory_frame(phase_elapsed: float) -> int:
	var is_blacksmith := selected_character_type == PlayerCharacterRuntime.BLACKSMITH
	var is_commando := selected_character_type == PlayerCharacterRuntime.COMMANDO
	var frame_count := BattleDrawActorResultContext.get_player_victory_frame_count(is_blacksmith, is_commando)
	var speed := BattleDrawActorResultContext.get_player_victory_frame_speed(is_commando)
	var frame := int(floor(maxf(0.0, phase_elapsed) / speed))
	return clampi(frame, 0, max(0, frame_count - 1))


func _get_defeat_frame(phase_elapsed: float) -> int:
	var is_blacksmith := selected_character_type == PlayerCharacterRuntime.BLACKSMITH
	var is_viper := selected_character_type == PlayerCharacterRuntime.VIPER
	var is_commando := selected_character_type == PlayerCharacterRuntime.COMMANDO
	var frame_count := BattleDrawActorResultContext.get_player_defeat_frame_count(is_blacksmith, is_viper, is_commando)
	var speed := BattleDrawActorResultContext.PLAYER_DEFEAT_64_FRAME_SPEED if is_viper else BattleDrawActorResultContext.PLAYER_DEFEAT_FRAME_SPEED
	var frame := int(floor(maxf(0.0, phase_elapsed) / speed))
	return clampi(frame, 0, max(0, frame_count - 1))


func _get_flight_progress() -> float:
	if not active:
		return 1.0
	var raw := (elapsed_sec - DEFEAT_HOLD_SEC) / maxf(GEM_FLIGHT_SEC, 0.001)
	return _ease_in_out_cubic(raw)


func _get_absorb_progress() -> float:
	if not active:
		return 0.0
	var raw := (elapsed_sec - (DEFEAT_HOLD_SEC + GEM_FLIGHT_SEC)) / maxf(ABSORB_FLASH_SEC, 0.001)
	return clampf(raw, 0.0, 1.0)


func _get_absorb_glow_ratio() -> float:
	if not active:
		return 0.0
	if elapsed_sec < DEFEAT_HOLD_SEC:
		return 0.0
	if get_phase() == PHASE_VICTORY_PULSE:
		var victory_elapsed := maxf(0.0, elapsed_sec - (DEFEAT_HOLD_SEC + GEM_FLIGHT_SEC + ABSORB_FLASH_SEC))
		var fade := 1.0 - _ease_out_cubic(victory_elapsed / maxf(VICTORY_PULSE_SEC, 0.001))
		return 0.70 * fade
	var flight := _get_flight_progress()
	var absorb := _get_absorb_progress()
	if absorb > 0.0:
		return maxf(0.35, 1.0 - _ease_out_cubic(absorb) * 0.35)
	if flight > 0.0:
		return 0.15 + 0.60 * flight
	return 0.0


func _get_sacred_total_strength() -> float:
	return maxf(maxf(_get_sacred_trail_strength(), _get_sacred_bloom_strength()), maxf(_get_sacred_ray_alpha(), _get_sacred_mote_alpha()))


func _get_sacred_trail_strength() -> float:
	if not active:
		return 0.0
	var phase := get_phase()
	if phase == PHASE_GEM_FLIGHT:
		return 0.12 + 0.34 * _get_flight_progress()
	if phase == PHASE_ABSORB_FLASH:
		return 0.40 * (1.0 - _ease_out_cubic(_get_absorb_progress()))
	return 0.0


func _get_sacred_bloom_strength() -> float:
	if not active:
		return 0.0
	var phase := get_phase()
	if phase == PHASE_ABSORB_FLASH:
		var p := _get_absorb_progress()
		return pow(sin(clampf(p, 0.0, 1.0) * PI), 0.55)
	if phase == PHASE_VICTORY_PULSE:
		var v := _get_victory_progress()
		var breath := 0.86 + 0.14 * sin(elapsed_sec * TAU * 1.15)
		return (1.0 - _ease_out_cubic(v)) * 0.62 * breath
	return 0.0


func _get_sacred_flash_alpha() -> float:
	if not active or get_phase() != PHASE_ABSORB_FLASH:
		return 0.0
	var p := _get_absorb_progress()
	return pow(sin(clampf(p, 0.0, 1.0) * PI), 1.9) * 0.42


func _get_sacred_ray_alpha() -> float:
	if not active:
		return 0.0
	var phase := get_phase()
	if phase == PHASE_ABSORB_FLASH:
		return 0.48 * _get_sacred_bloom_strength()
	if phase == PHASE_VICTORY_PULSE:
		return 0.30 * (1.0 - _ease_out_cubic(_get_victory_progress()))
	return 0.0


func _get_sacred_mote_alpha() -> float:
	if not active:
		return 0.0
	var phase := get_phase()
	if phase == PHASE_ABSORB_FLASH:
		return 0.30 + 0.34 * _get_sacred_bloom_strength()
	if phase == PHASE_VICTORY_PULSE:
		return 0.42 * (1.0 - _ease_out_cubic(_get_victory_progress()))
	return 0.0


func _get_sacred_warm_ratio() -> float:
	if not active:
		return 0.0
	var phase := get_phase()
	if phase == PHASE_GEM_FLIGHT:
		return 0.12 * _get_flight_progress()
	if phase == PHASE_ABSORB_FLASH:
		return _ease_out_cubic(_get_absorb_progress())
	if phase == PHASE_VICTORY_PULSE:
		return 1.0
	return 0.0


func _get_victory_progress() -> float:
	if not active:
		return 1.0
	var raw := (elapsed_sec - (DEFEAT_HOLD_SEC + GEM_FLIGHT_SEC + ABSORB_FLASH_SEC)) / maxf(VICTORY_PULSE_SEC, 0.001)
	return clampf(raw, 0.0, 1.0)


func _get_color_restore_max_radius(center: Vector2, view_size: Vector2) -> float:
	var corners := [
		Vector2.ZERO,
		Vector2(view_size.x, 0.0),
		Vector2(0.0, view_size.y),
		view_size,
	]
	var max_radius := 0.0
	for corner in corners:
		max_radius = maxf(max_radius, center.distance_to(corner))
	var feather := maxf(COLOR_RESTORE_FEATHER_MIN, minf(view_size.x, view_size.y) * COLOR_RESTORE_FEATHER_RATIO)
	return max_radius + feather


func _draw_flying_gem(canvas: CanvasItem, center: Vector2, progress: float) -> void:
	var texture := ProjectResourceLoader.get_cached_texture(BattleCoreTexturePaths.CHANCE_GEM_FULL_TEXTURE_PATH)
	var pulse := sin(progress * PI)
	ImpactFlareTextureCache.draw_glow(canvas, center, 54.0 + 20.0 * pulse, Color(0.36, 0.84, 1.0, 1.0), 0.22 + 0.18 * pulse)
	if texture == null:
		canvas.draw_circle(center, 14.0 + 5.0 * pulse, Color(0.32, 0.77, 1.0, 0.92))
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var scale_factor := minf(GEM_DRAW_SIZE.x / texture_size.x, GEM_DRAW_SIZE.y / texture_size.y) * (0.86 + 0.16 * pulse)
	var draw_size := texture_size * scale_factor
	canvas.draw_texture_rect(texture, Rect2(center - draw_size * 0.5, draw_size), false, Color(1.0, 1.0, 1.0, 0.94))


func _draw_flight_trail(canvas: CanvasItem, target: Vector2, flight_progress: float) -> void:
	if flight_progress <= 0.001 or flight_progress >= 0.998:
		return
	var control := source_screen_pos.lerp(target, 0.62) + Vector2(0.0, -130.0)
	var previous := source_screen_pos
	for i in range(1, TRAIL_SAMPLES + 1):
		var t := flight_progress * float(i) / float(TRAIL_SAMPLES)
		var pos := _bezier(source_screen_pos, control, target, _ease_in_out_cubic(t))
		var alpha := 0.10 + 0.20 * float(i) / float(TRAIL_SAMPLES)
		canvas.draw_line(previous, pos, Color(0.42, 0.86, 1.0, alpha), 2.2)
		previous = pos


func _draw_absorb_burst(canvas: CanvasItem, center: Vector2, progress: float) -> void:
	var rise := sin(clampf(progress, 0.0, 1.0) * PI)
	var fade := 1.0 - _ease_out_cubic(progress)
	ImpactFlareTextureCache.draw_glow(canvas, center, 78.0 + 42.0 * progress, Color(0.40, 0.88, 1.0, 1.0), 0.36 * rise)
	ImpactFlareTextureCache.draw_burst(canvas, center, 64.0 + 74.0 * progress, Color(0.86, 0.98, 1.0, 1.0), 0.38 * fade)
	for i in range(8):
		var angle := float(i) / 8.0 * TAU + progress * 0.3
		var radius := 34.0 + progress * (28.0 + float(i % 3) * 6.0)
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		ImpactFlareTextureCache.draw_sparkle(canvas, pos, 10.0 + float(i % 2) * 3.0, Color(0.72, 0.92, 1.0, 1.0), 0.30 * fade)


func _draw_sacred_revival_overlay(canvas: CanvasItem, center: Vector2, view_size: Vector2) -> void:
	var status := get_sacred_overlay_status()
	if not bool(status.get("active", false)):
		return
	var warm_ratio := float(status.get("warm_ratio", 0.0))
	var sacred_color := Color(0.42, 0.88, 1.0, 1.0).lerp(Color(1.0, 0.78, 0.36, 1.0), warm_ratio)
	var white_gold := Color(1.0, 0.96, 0.78, 1.0)
	var flash := float(status.get("flash_alpha", 0.0))
	if flash > 0.001:
		canvas.draw_rect(Rect2(Vector2.ZERO, view_size), Color(1.0, 0.93, 0.72, 0.055 * flash))
	var trail := float(status.get("trail_strength", 0.0))
	if trail > 0.001:
		_draw_sacred_trail(canvas, center, sacred_color, trail)
	var bloom := float(status.get("bloom_strength", 0.0))
	if bloom > 0.001:
		ImpactFlareTextureCache.draw_glow(canvas, center, 92.0 + 96.0 * bloom, sacred_color, 0.34 * bloom)
		ImpactFlareTextureCache.draw_burst(canvas, center, 70.0 + 126.0 * bloom, white_gold, 0.30 * bloom)
		ImpactFlareTextureCache.draw_sparkle(canvas, center + Vector2(0.0, -8.0), 34.0 + 18.0 * bloom, Color.WHITE, 0.34 * bloom)
	var ray_alpha := float(status.get("ray_alpha", 0.0))
	if ray_alpha > 0.001:
		_draw_sacred_god_rays(canvas, center, sacred_color.lerp(white_gold, 0.35), ray_alpha)
	var mote_alpha := float(status.get("mote_alpha", 0.0))
	if mote_alpha > 0.001:
		_draw_sacred_motes(canvas, center, sacred_color, mote_alpha)


func _draw_sacred_trail(canvas: CanvasItem, target: Vector2, color: Color, strength: float) -> void:
	var control := source_screen_pos.lerp(target, 0.62) + Vector2(0.0, -130.0)
	for i in range(1, TRAIL_SAMPLES + 1):
		var t := float(i) / float(TRAIL_SAMPLES)
		var pos := _bezier(source_screen_pos, control, target, _ease_in_out_cubic(t))
		var alpha := strength * (0.10 + 0.18 * t)
		ImpactFlareTextureCache.draw_sparkle(canvas, pos, 8.0 + 5.0 * t, color, alpha)


func _draw_sacred_god_rays(canvas: CanvasItem, center: Vector2, color: Color, alpha: float) -> void:
	var breath := 0.88 + 0.12 * sin(elapsed_sec * TAU * 0.72)
	for i in range(SACRED_RAY_COUNT):
		var fan_t := (float(i) + 0.5) / float(SACRED_RAY_COUNT)
		var angle := lerpf(-2.54, -0.60, fan_t)
		var length := (122.0 + 54.0 * sin(float(i) * 1.71 + 0.4)) * breath
		var start := center + Vector2(cos(angle), sin(angle)) * 16.0
		var end := center + Vector2(cos(angle), sin(angle)) * length
		var ray_alpha := alpha * (0.20 + 0.20 * sin(float(i) * 0.9 + elapsed_sec * TAU * 0.45))
		canvas.draw_line(start, end, Color(color.r, color.g, color.b, clampf(ray_alpha, 0.0, 0.38)), 1.2 + 1.4 * fan_t)


func _draw_sacred_motes(canvas: CanvasItem, center: Vector2, color: Color, alpha: float) -> void:
	for i in range(SACRED_MOTE_COUNT):
		var seed := float(i) * 0.173
		var rise := fmod(seed + elapsed_sec * (0.26 + float(i % 5) * 0.025), 1.0)
		var x := sin(seed * TAU * 2.7 + elapsed_sec * 1.15) * (22.0 + float(i % 4) * 12.0)
		var y := -18.0 - rise * (112.0 + float(i % 3) * 18.0)
		var pos := center + Vector2(x, y)
		var mote_alpha := alpha * sin(rise * PI) * (0.32 + 0.18 * float(i % 3))
		ImpactFlareTextureCache.draw_sparkle(canvas, pos, 7.0 + float(i % 4) * 2.0, color, mote_alpha)


func _get_player_center_screen(owner: Object, view_size: Vector2) -> Vector2:
	var layout: Dictionary = _layout.build_game_layout(view_size, FIELD_SIZE.x, FIELD_SIZE.y)
	var game_offset := _as_vector2(layout.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var render_scale := maxf(0.001, float(layout.get("render_scale", 1.0)))
	var player_pos := _get_owner_vector2(owner, "player_pos", Vector2(FIELD_SIZE.x * 0.5 - 77.5, FIELD_SIZE.y - 50.0))
	var player_size := Vector2(
		maxf(1.0, _get_owner_float(owner, "player_paddle_width", 155.0)),
		maxf(1.0, _get_owner_float(owner, "player_paddle_height", 50.0))
	)
	var game_center := player_pos + player_size * Vector2(0.5, 0.42)
	return game_offset + game_center * render_scale


func _write_owner_state(owner: Object) -> void:
	if owner == null:
		return
	_set_owner_value(owner, "defeat_continue_revival_beat_active", active)
	_set_owner_value(owner, "defeat_continue_revival_beat_phase", get_phase())
	_set_owner_value(owner, "defeat_continue_revival_beat_elapsed", elapsed_sec if active else 0.0)
	_set_owner_value(owner, "defeat_continue_revival_beat_full_pose", full_pose_enabled if active else false)


func _expire_if_wall_clock_timed_out() -> void:
	if not active or _started_msec == 0:
		return
	var max_msec := int(round((get_total_duration() + WALL_CLOCK_FAILSAFE_GRACE_SEC) * 1000.0))
	if Time.get_ticks_msec() - _started_msec <= max_msec:
		return
	reset(_owner)


func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var p := clampf(t, 0.0, 1.0)
	return a.lerp(b, p).lerp(b.lerp(c, p), p)


func _ease_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _ease_in_out_cubic(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	if t < 0.5:
		return 4.0 * t * t * t
	return 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return value


func _get_owner_float(owner: Object, key: String, fallback: float) -> float:
	return float(_get_owner_value(owner, key, fallback))


func _get_owner_vector2(owner: Object, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = _get_owner_value(owner, key, fallback)
	if value is Vector2:
		return value
	return fallback


func _set_owner_value(owner: Object, key: String, value: Variant) -> void:
	if owner != null:
		owner.set(key, value)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
