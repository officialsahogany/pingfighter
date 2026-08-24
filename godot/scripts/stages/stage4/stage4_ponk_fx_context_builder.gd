extends RefCounted

const Stage4PonkIllusionState := preload("res://scripts/stages/stage4/stage4_ponk_illusion_state.gd")
const Stage4PonkMagneticAssets := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_assets.gd")
const Stage4PonkMagneticFieldState := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_field_state.gd")
const Stage4PonkMagneticProjectileState := preload("res://scripts/stages/stage4/stage4_ponk_magnetic_projectile_state.gd")
const Stage4PonkMeditationState := preload("res://scripts/stages/stage4/stage4_ponk_meditation_state.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0

# Pure projection boundary between Ponk's mutable skill owners and detached FX
# hosts. It owns host-facing Dictionary shape/defaults/clamps only: no nodes,
# draw calls, RNG, clocks, audio, or lifecycle mutation.


func build_magnetic(
	context: Dictionary,
	shake_offset: Vector2,
	magnetic_state: Object,
	projectile_state: Object,
	frame_clock: float
) -> Dictionary:
	var active: bool = bool(context.get("stage4_magnetic_active", magnetic_state.magnetic_active))
	var enraged: bool = bool(context.get("stage4_magnetic_enraged", magnetic_state.magnetic_enraged))
	var timer: float = float(context.get("stage4_magnetic_timer", magnetic_state.magnetic_timer_frames))
	var total: float = (
		Stage4PonkMagneticFieldState.ENRAGED_DURATION_FRAMES
		if enraged
		else Stage4PonkMagneticFieldState.DURATION_FRAMES
	)
	return {
		"active": active,
		"progress": clampf(1.0 - maxf(0.0, timer) / maxf(1.0, total), 0.0, 1.0),
		"boss_center": _as_vector2(
			context.get("stage4_magnetic_center", magnetic_state.magnetic_center),
			_get_boss_center(context)
		),
		"radius": maxf(24.0, float(context.get("stage4_magnetic_radius", magnetic_state.magnetic_radius))),
		"frame": int(context.get("stage4_magnetic_frame", _current_magnetic_frame(frame_clock))),
		"elapsed": float(context.get("stage4_effect_clock", frame_clock)),
		"enraged": enraged,
		"projectile_active": bool(context.get("stage4_magnetic_projectile_active", projectile_state.active)),
		"projectile_pos": _as_vector2(context.get("stage4_magnetic_projectile_pos", projectile_state.pos), projectile_state.pos),
		"projectile_radius": maxf(12.0, float(context.get("stage4_magnetic_projectile_radius", projectile_state.radius))),
		"projectile_elapsed": maxf(0.0, float(context.get("stage4_magnetic_projectile_elapsed", projectile_state.elapsed_seconds))),
		"projectile_velocity": _as_vector2(context.get("stage4_magnetic_projectile_velocity", projectile_state.velocity), projectile_state.velocity),
		"projectile_y_speed_multiplier": clampf(float(context.get("stage4_magnetic_projectile_y_speed_multiplier", projectile_state.y_speed_multiplier)), 0.0, 1.0),
		"projectile_fade_active": bool(context.get("stage4_magnetic_projectile_fade_active", projectile_state.fade_timer_seconds > 0.0)),
		"projectile_fade_timer": maxf(0.0, float(context.get("stage4_magnetic_projectile_fade_timer", projectile_state.fade_timer_seconds))),
		"projectile_fade_total": Stage4PonkMagneticProjectileState.PROJECTILE_FADE_SECONDS,
		"projectile_fade_pos": _as_vector2(context.get("stage4_magnetic_projectile_fade_pos", projectile_state.fade_pos), projectile_state.fade_pos),
		"projectile_fade_radius": maxf(12.0, float(context.get("stage4_magnetic_projectile_fade_radius", projectile_state.fade_radius))),
		"projectile_fade_velocity": _as_vector2(context.get("stage4_magnetic_projectile_fade_velocity", projectile_state.fade_velocity), projectile_state.fade_velocity),
		"shake_offset": shake_offset,
		"game_offset": _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO),
		"render_scale": _resolve_render_scale(context),
	}


func build_meditation(
	context: Dictionary,
	shake_offset: Vector2,
	meditation_state: Object
) -> Dictionary:
	var active: bool = bool(context.get("stage4_meditation_active", meditation_state.meditation_active))
	var release_active: bool = bool(context.get(
		"stage4_meditation_release_fx_active",
		meditation_state.meditation_release_fx_timer_frames > 0.0
	))
	var timer: float = float(context.get("stage4_meditation_timer", meditation_state.meditation_timer_frames))
	var release_timer: float = float(context.get(
		"stage4_meditation_release_fx_timer",
		meditation_state.meditation_release_fx_timer_frames
	))
	var trails: Array = _as_array(context.get("stage4_meditation_trails", meditation_state.meditation_trails))
	if not active and release_active:
		trails = _as_array(context.get(
			"stage4_meditation_release_fx_trails",
			meditation_state.meditation_release_fx_trails
		))
	var ball_pos: Vector2 = _as_vector2(
		context.get("stage4_meditation_ball_pos", meditation_state.meditation_ball_pos),
		meditation_state.meditation_ball_pos
	)
	if not active and release_active:
		ball_pos = _as_vector2(
			context.get("ball_pos", meditation_state.meditation_release_fx_pos),
			meditation_state.meditation_release_fx_pos
		)
	return {
		"active": active,
		"release_active": release_active,
		"progress": clampf(1.0 - maxf(0.0, timer) / Stage4PonkMeditationState.DURATION_FRAMES, 0.0, 1.0),
		"release_progress": clampf(1.0 - maxf(0.0, release_timer) / Stage4PonkMeditationState.RELEASE_FX_FRAMES, 0.0, 1.0),
		"boss_center": _get_boss_center(context),
		"ball_pos": ball_pos,
		"trails": trails,
		"shake_offset": shake_offset,
		"game_offset": _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO),
		"render_scale": _resolve_render_scale(context),
		"release_origin": _as_vector2(context.get("stage4_meditation_release_fx_origin", meditation_state.meditation_release_fx_origin), meditation_state.meditation_release_fx_origin),
		"release_pos": _as_vector2(context.get("stage4_meditation_release_fx_pos", meditation_state.meditation_release_fx_pos), meditation_state.meditation_release_fx_pos),
		"release_velocity": _as_vector2(context.get("stage4_meditation_release_fx_velocity", meditation_state.meditation_release_fx_velocity), meditation_state.meditation_release_fx_velocity),
		"release_id": int(context.get("stage4_meditation_release_fx_id", meditation_state.meditation_release_fx_id)),
	}


func build_illusion(
	context: Dictionary,
	illusion_state: Object,
	frame_clock: float,
	canvas: CanvasItem = null
) -> Dictionary:
	# 풀스크린 스크린-리드 오버레이: 엔진 뷰포트가 크기의 정본이다(WIP 파괴 후
	# 재배선). 라이브 플레이필드 컨텍스트는 view_size를 안 싣고 game_size(스케일된
	# 플레이필드, 윈도우보다 작음)만 있어 폴백만 쓰면 물결이 화면 좌측 절반만
	# 덮는다. get_viewport_rect()는 트리 밖에서 ERROR → is_inside_tree 가드 필수.
	var view_size: Vector2 = Vector2.ZERO
	if canvas != null and canvas.is_inside_tree():
		view_size = canvas.get_viewport_rect().size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = _as_vector2(
			context.get("view_size", context.get("viewport_size", Vector2.ZERO)),
			Vector2.ZERO
		)
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		var game_size: Vector2 = _as_vector2(context.get("game_size", Vector2.ZERO), Vector2.ZERO)
		if game_size.x > 1.0 and game_size.y > 1.0:
			view_size = game_size
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		view_size = Vector2(
			float(context.get("width", FIELD_WIDTH)),
			float(context.get("height", FIELD_HEIGHT))
		)
	return {
		"active": bool(context.get("stage4_illusion_active", illusion_state.illusion_active)),
		"timer_frames": maxf(0.0, float(context.get("stage4_illusion_timer", illusion_state.illusion_timer_frames))),
		"duration_total": maxf(1.0, float(context.get("stage4_illusion_duration_total", Stage4PonkIllusionState.ILLUSION_DURATION_FRAMES))),
		"view_size_px": view_size,
		"elapsed_sec": float(context.get("stage4_effect_clock", frame_clock)),
		"intensity_px": float(context.get("stage4_illusion_intensity_px", 27.0)),
		"wave_freq_a": float(context.get("stage4_illusion_wave_freq_a", 9.0)),
		"wave_freq_b": float(context.get("stage4_illusion_wave_freq_b", 17.0)),
		"wave_speed": float(context.get("stage4_illusion_wave_speed", 2.2)),
		"hue_wave_amp": float(context.get("stage4_illusion_hue_amp", 0.9)),
		"hue_wave_freq": float(context.get("stage4_illusion_hue_freq", 5.0)),
		"hue_time_speed": float(context.get("stage4_illusion_hue_speed", 0.9)),
		"chroma_offset_px": float(context.get("stage4_illusion_chroma_offset_px", 3.5)),
		"saturation_boost": float(context.get("stage4_illusion_saturation_boost", 0.25)),
	}


func build_awaken_aura(
	context: Dictionary,
	shake_offset: Vector2,
	illusion_state: Object,
	frame_clock: float
) -> Dictionary:
	var intensity: float = float(illusion_state.get_awaken_aura_intensity(context))
	return {
		"active": intensity > 0.001,
		"intensity": intensity,
		"boss_center": _get_awaken_aura_center(context) + shake_offset,
		"elapsed": float(context.get("stage4_effect_clock", frame_clock)),
		"enraged": bool(context.get("stage4_illusion_awaken_aura_enraged", illusion_state.illusion_aura_enraged)),
		"game_offset": _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO),
		"render_scale": _resolve_render_scale(context),
	}


func _current_magnetic_frame(frame_clock: float) -> int:
	return int(floor(frame_clock / Stage4PonkMagneticAssets.MAGNETIC_FIELD_FRAME_INTERVAL)) % Stage4PonkMagneticAssets.MAGNETIC_FIELD_FRAME_COUNT


func _resolve_render_scale(context: Dictionary) -> float:
	var render_scale: float = float(context.get("render_scale", 0.0))
	if render_scale > 0.0:
		return render_scale
	var game_size: Vector2 = _as_vector2(context.get("game_size", Vector2.ZERO), Vector2.ZERO)
	var width: float = maxf(1.0, float(context.get("width", FIELD_WIDTH)))
	return game_size.x / width if game_size.x > 0.0 else 1.0


func _get_boss_center(context: Dictionary) -> Vector2:
	var boss_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2(330.0, 55.0))
	var boss_size: Vector2 = _get_vector2(context, "boss_paddle_size", Vector2.ZERO)
	if boss_size == Vector2.ZERO:
		boss_size = Vector2(
			float(context.get("boss_paddle_width", 100.0)),
			float(context.get("boss_hitbox_height", 40.0))
		)
	return boss_pos + boss_size * 0.5


func _get_awaken_aura_center(context: Dictionary) -> Vector2:
	var boss_pos: Vector2 = _get_vector2(context, "boss_pos", Vector2(330.0, 55.0))
	var boss_size: Vector2 = _get_vector2(context, "boss_paddle_size", Vector2(100.0, 18.0))
	var boss_hitbox_height: float = float(context.get("boss_hitbox_height", 40.0))
	return Vector2(
		boss_pos.x + boss_size.x * 0.5,
		boss_pos.y + boss_hitbox_height * 0.5 + 34.0
	)


func _get_vector2(source: Dictionary, key: String, fallback: Vector2) -> Vector2:
	return _as_vector2(source.get(key, fallback), fallback)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return fallback


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
