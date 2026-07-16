extends RefCounted

## Procedural presentation for Odin's Eye.
##
## This renderer deliberately owns no state and allocates no textures. It reads
## the authoritative Odin context, then draws a compact deterministic set of
## circles and line strips. The caller may pass either the Odin sub-context or
## an actor context containing `odins_eye_context`.

# Bang timing (audio-latency-compensated) is single-sourced from the state so the
# BANG_LATENCY_SEC knob moves the flash / body-snap / shake together.
const OdinsEyeState := preload("res://scripts/items/odins_eye_state.gd")

# MUST equal OdinsEyeState.REVIVAL_EVENT_SEC (3.75). safe_progress is clamped
# [0,1], so a mismatch freezes the burst and desyncs the odinchange.wav bang.
const REVIVAL_DURATION_SEC := 3.75
# Phase cuts on the 3.75s (225f) clock, restoring the original 4-phase shape:
# gather 90f (0-1.5s), form 60f (1.5-2.5s), burst-prep 30f (2.5-3.0s),
# dark-burst reveal 45f (3.0-3.75s). Explosion FIRES at REVIVAL_BURST_PREP_END
# (3.0s) and the flash peaks at the 3.2s audio bang.
const REVIVAL_GATHER_END := 0.40
const REVIVAL_FORM_END := 2.0 / 3.0
const REVIVAL_BURST_PREP_END := 0.80

const BASE_VISUAL_SIZE := Vector2(180.0, 185.0)
const BASE_PADDLE_WIDTH := 155.0
const BODY_CENTER_Y_OFFSET := -55.0

const DARK_CORE := Color(0.065, 0.018, 0.105, 1.0)
const DARK_MID := Color(0.17, 0.055, 0.26, 1.0)
const VOID_PURPLE := Color(0.40, 0.15, 0.58, 1.0)
const ARCANE_PURPLE := Color(0.72, 0.38, 0.94, 1.0)
const EYE_GOLD := Color(1.0, 0.83, 0.34, 1.0)
const EYE_WHITE := Color(1.0, 0.98, 0.86, 1.0)


func draw_player(
	canvas: CanvasItem,
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> Rect2:
	var plan: Dictionary = build_presentation_plan(context, player_pos, paddle_size, shake_offset)
	var visual_rect: Rect2 = plan.get("player_rect", Rect2())
	if not bool(plan.get("draw_player", false)):
		return visual_rect

	# 대쉬 다이브: sink / underground / emerge paddle offset + fade
	# (legendary_items.py:7068-7107 visual params contract).
	if not bool(plan.get("dive_visible", true)):
		return visual_rect

	var opacity: float = clampf(float(plan.get("dive_alpha", 1.0)), 0.0, 1.0)
	# `disintegrate_progress` is the body-tear driver (_draw_eldritch_player uses
	# displace = value * 10), reused across the death phases to fray the seams.
	var disintegrate_progress := 0.0
	var body_scale := 1.0
	var death_shake := Vector2.ZERO
	var death_time: float = _time_seconds(context)
	if bool(plan.get("draw_death", false)):
		var death_phase: String = str(plan.get("death_phase", ""))
		var phase_progress: float = clampf(float(plan.get("death_phase_progress", 0.0)), 0.0, 1.0)
		if death_phase == "pre_explosion":
			# 죽어가는 몸: 폭발이 가까울수록 심해지는 떨림 + 이음새 찢김 + 불안정 스트로브
			# (원본 실루엣 pulse/shake + eye_glow 상승). 금색→붉은눈·균열은 오버레이가 스탬프.
			var buildup: float = clampf(float(plan.get("death_energy_buildup", 0.0)), 0.0, 1.0)
			death_shake = Vector2(sin(death_time * 40.0), cos(death_time * 37.0)) * buildup * 4.0
			disintegrate_progress = buildup * 0.5
			opacity *= 1.0 - buildup * 0.15 * (0.5 + 0.5 * sin(death_time * 30.0))
		elif death_phase == "explosion":
			opacity *= lerpf(1.0, 0.72, phase_progress)
			body_scale = 1.0 + sin(phase_progress * PI) * 0.08
			# 충격파가 터지는 프레임에 몸이 실제로 터져나가듯 격렬한 흔들림 + 이음새 폭발.
			death_shake = Vector2(sin(death_time * 55.0), cos(death_time * 48.0)) * 8.0
			disintegrate_progress = (4.0 + phase_progress * 6.0) / 10.0
		elif death_phase == "disintegrate":
			disintegrate_progress = phase_progress
			# 분해 시작 직후 몸을 거의 지워, 흩어지는 8개 파편이 프레임을 차지하게 한다
			# (원본은 분해 시작 시 human_silhouette_alpha->0; 이중 이미지 제거).
			opacity *= pow(1.0 - phase_progress, 3.0)
			body_scale = lerpf(1.0, 1.18, phase_progress)
		if bool(plan.get("hide_player", false)):
			opacity = 0.0
	if opacity <= 0.01:
		return visual_rect

	var draw_rect := _scaled_rect(visual_rect, body_scale)
	draw_rect.position.y += float(plan.get("dive_offset_y", 0.0))
	if death_shake != Vector2.ZERO:
		draw_rect.position += death_shake * (draw_rect.size.x / BASE_VISUAL_SIZE.x)
	var time_sec: float = death_time

	# 어둠의 늪 발동 중 Y축 스핀 (legendary_items.py:10213-10237): the whole
	# body compresses on cos(t*20); the near-edge-on frame collapses to a thin
	# silhouette line. Vertex-scaled — draw_set_transform is forbidden.
	var spin: float = _resolve_spin(context, time_sec)
	if absf(spin) < 0.05:
		var line_unit: float = minf(draw_rect.size.x / BASE_VISUAL_SIZE.x, draw_rect.size.y / BASE_VISUAL_SIZE.y)
		canvas.draw_line(
			Vector2(draw_rect.get_center().x, draw_rect.position.y),
			Vector2(draw_rect.get_center().x, draw_rect.position.y + draw_rect.size.y),
			_alpha(Color(40.0 / 255.0, 18.0 / 255.0, 60.0 / 255.0, 180.0 / 255.0), opacity),
			maxf(1.0, 3.0 * line_unit),
			true
		)
		return draw_rect

	_draw_eldritch_player(
		canvas,
		draw_rect,
		time_sec,
		opacity,
		disintegrate_progress,
		float(_value(context, "player_speed", 0.0)),
		spin
	)
	_draw_eldritch_ambient_particles(canvas, context, draw_rect, opacity, spin)
	return draw_rect


func draw_overlay(
	canvas: CanvasItem,
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> void:
	var plan: Dictionary = build_presentation_plan(context, player_pos, paddle_size, shake_offset)
	var visual_rect: Rect2 = plan.get("player_rect", Rect2())
	var time_sec: float = _time_seconds(context)
	if bool(plan.get("draw_revival", false)):
		_draw_revival_cinematic(
			canvas,
			visual_rect,
			float(plan.get("revival_progress", 0.0)),
			time_sec,
			float(_value(context, "player_speed", 0.0))
		)
	elif bool(plan.get("draw_death", false)):
		_draw_death_cinematic(canvas, visual_rect, plan, time_sec)

	# Python draws the afterimages (pingfighter.py:142502) then the dash dive
	# effects (:142505) while the penalty form is live.
	if _is_transformed(context):
		_draw_afterimages(canvas, context, shake_offset)
		_draw_dive_effects(canvas, context, shake_offset)

	_draw_dark_swamp(canvas, context, time_sec, shake_offset)


## Pure layout/gating surface used by focused smoke tests and integration.
func build_presentation_plan(
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2 = Vector2.ZERO
) -> Dictionary:
	var revival_active: bool = bool(_value(context, "revival_animation_active", false))
	var death_active: bool = bool(_value(context, "death_animation_active", false))
	var transformed: bool = _is_transformed(context)
	var visual_rect := get_player_visual_rect(context, player_pos, paddle_size, shake_offset)
	var revival_timer_sec: float = maxf(0.0, float(_value(context, "revival_timer_sec", 0.0)))
	var revival_progress: float = clampf(
		float(_value(
			context,
			"revival_progress",
			1.0 - revival_timer_sec / REVIVAL_DURATION_SEC
		)),
		0.0,
		1.0
	)
	var spikes: Array = _dark_swamp_array(context, "spikes", "dark_swamp_spikes", "lurker_spikes")
	var dive_visual: Dictionary = _dive_visual(context)
	return {
		"player_rect": visual_rect,
		"draw_player": transformed and not revival_active,
		"draw_revival": revival_active,
		"revival_progress": revival_progress,
		"draw_death": death_active,
		"death_phase": str(_value(context, "death_phase", "")),
		"death_phase_progress": clampf(float(_value(context, "death_phase_progress", 0.0)), 0.0, 1.0),
		"death_overall_progress": clampf(float(_value(context, "death_overall_progress", 0.0)), 0.0, 1.0),
		"death_energy_buildup": clampf(float(_value(context, "death_energy_buildup", 0.0)), 0.0, 1.0),
		"death_disintegrate_progress": clampf(float(_value(context, "death_disintegrate_progress", 0.0)), 0.0, 1.0),
		"hide_player": bool(_value(context, "hide_player_paddle", false)),
		"dark_swamp_spike_count": spikes.size(),
		"dive_visible": bool(dive_visual.get("visible", true)),
		"dive_alpha": clampf(float(dive_visual.get("alpha", 1.0)), 0.0, 1.0),
		"dive_offset_y": float(dive_visual.get("offset_y", 0.0)),
	}


func get_player_visual_rect(
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2 = Vector2.ZERO
) -> Rect2:
	var fallback_scale: float = maxf(1.0, paddle_size.x / BASE_PADDLE_WIDTH)
	var paddle_scale: float = clampf(
		float(_value(context, "player_paddle_scale", fallback_scale)),
		0.72,
		1.55
	)
	var visual_size: Vector2 = BASE_VISUAL_SIZE * paddle_scale
	var center := Vector2(
		player_pos.x + paddle_size.x * 0.5,
		player_pos.y + paddle_size.y * 0.5 + BODY_CENTER_Y_OFFSET * paddle_scale
	) + shake_offset
	return Rect2(center - visual_size * 0.5, visual_size)


# Local body-space (legacy 180x185 surface) coordinates. `spin` compresses X
# around the body pivot (dark-swamp Y-axis spin, legendary_items.py:10213-10237);
# a NEGATIVE spin mirrors the back face. Vertex math only — draw_set_transform
# is forbidden here (identity reset destroys the parent game_offset transform).
const ELDRITCH_HEAD_Y := 36.0
const ELDRITCH_SHOULDER_Y := 55.0
const ELDRITCH_BODY_END_Y := 170.0

# Arm tentacle configs (legendary_items.py:10017-10025):
# [side, y_off, base_angle, length, thickness, curl_dir, speed, curl_strength]
const ELDRITCH_ARM_CONFIGS: Array = [
	[-1.0, -2.0, -0.35, 75.0, 12.0, 1.0, 0.65, 1.4],
	[-1.0, 6.0, -0.1, 62.0, 8.0, -1.0, 0.85, 1.7],
	[-1.0, -8.0, -0.6, 55.0, 7.0, 1.0, 1.0, 1.9],
	[1.0, -2.0, 0.35, 73.0, 12.0, -1.0, 0.7, 1.4],
	[1.0, 6.0, 0.1, 60.0, 8.0, 1.0, 0.9, 1.7],
	[1.0, -8.0, 0.6, 53.0, 7.0, -1.0, 1.05, 1.9],
]

# Head tendril configs (legendary_items.py:10092-10095): [angle, length, width]
const ELDRITCH_HORN_CONFIGS: Array = [
	[-0.8, 28.0, 5.0], [-1.3, 22.0, 4.0], [0.8, 26.0, 5.0],
	[1.3, 20.0, 4.0], [-1.6, 16.0, 3.0], [1.6, 16.0, 3.0],
]

# Straight-line rune letterforms (ᚠᚢᚦᚨᚱᚲᚷᚹ) in a centered 8x14 box — the
# elder futhark is carved from straight strokes, so procedural line sets keep
# the legacy glyph read without a first-use font/cache cost in the draw path.
const ELDRITCH_RUNE_GLYPHS: Array = [
	[Vector2(-3, -7), Vector2(-3, 7), Vector2(-3, -6), Vector2(3, -3), Vector2(-3, -2), Vector2(3, 1)],
	[Vector2(-3, -7), Vector2(-3, 7), Vector2(-3, -7), Vector2(3, -3), Vector2(3, -3), Vector2(3, 7)],
	[Vector2(-3, -7), Vector2(-3, 7), Vector2(-3, -4), Vector2(3, -1), Vector2(3, -1), Vector2(-3, 2)],
	[Vector2(-3, -7), Vector2(-3, 7), Vector2(-3, -7), Vector2(3, -4), Vector2(-3, -3), Vector2(3, 0)],
	[Vector2(-3, -7), Vector2(-3, 7), Vector2(-3, -7), Vector2(3, -4), Vector2(3, -4), Vector2(-3, -1), Vector2(-3, -1), Vector2(3, 7)],
	[Vector2(3, -7), Vector2(-3, 0), Vector2(-3, 0), Vector2(3, 7)],
	[Vector2(-4, -6), Vector2(4, 6), Vector2(4, -6), Vector2(-4, 6)],
	[Vector2(-3, -7), Vector2(-3, 7), Vector2(-3, -7), Vector2(3, -4), Vector2(3, -4), Vector2(-3, -1)],
]

const ELDRITCH_PARTICLE_COLORS: Array[Color] = [
	Color(115.0 / 255.0, 75.0 / 255.0, 190.0 / 255.0),
	Color(165.0 / 255.0, 60.0 / 255.0, 115.0 / 255.0),
	Color(70.0 / 255.0, 100.0 / 255.0, 185.0 / 255.0),
	Color(80.0 / 255.0, 155.0 / 255.0, 175.0 / 255.0),
]


func _eldritch_point(origin: Vector2, unit: float, spin: float, local_x: float, local_y: float) -> Vector2:
	return Vector2(origin.x + (local_x - 90.0) * spin * unit, origin.y + local_y * unit)


## Organic 24-step body silhouette (legendary_items.py:9920-9953). Exposed as
## a pure builder so the geometry seal can assert triangulability across
## animation phases without a live canvas.
func _build_eldritch_body_points(
	origin: Vector2,
	unit: float,
	spin: float,
	t: float,
	lean_px: float,
	displace: float
) -> PackedVector2Array:
	var body_steps := 24
	var left_edge: Array[Vector2] = []
	var right_edge: Array[Vector2] = []
	for step_index in range(body_steps + 1):
		var body_progress: float = float(step_index) / float(body_steps)
		var body_y: float = ELDRITCH_SHOULDER_Y + body_progress * (ELDRITCH_BODY_END_Y - ELDRITCH_SHOULDER_Y)
		var half_width: float
		if body_progress < 0.12:
			half_width = 22.0 + body_progress * 60.0
		elif body_progress < 0.35:
			half_width = 29.0 - (body_progress - 0.12) / 0.23 * 8.0
		elif body_progress < 0.65:
			half_width = 21.0 - (body_progress - 0.35) / 0.3 * 6.0
		else:
			half_width = 15.0 - (body_progress - 0.65) / 0.35 * 11.0
		half_width = maxf(1.0, half_width)
		var wave_left: float = sin(t * 1.0 + body_progress * 5.0) * 3.0 * body_progress
		var wave_right: float = sin(t * 1.0 + body_progress * 5.0 + 2.0) * 3.0 * body_progress
		var swirl: float = sin(t * 0.7 + body_progress * 3.5) * 4.0 * body_progress
		var body_center_x: float = (
			90.0 + lean_px * (1.0 - body_progress * 0.5) + swirl
			+ sin(float(step_index) * 2.17) * displace
		)
		var edge_y: float = body_y - displace * body_progress * 0.35
		left_edge.append(_eldritch_point(origin, unit, spin, body_center_x - half_width + wave_left, edge_y))
		right_edge.append(_eldritch_point(origin, unit, spin, body_center_x + half_width + wave_right, edge_y))
	var body_points := PackedVector2Array()
	for edge_point in left_edge:
		body_points.append(edge_point)
	for reverse_index in range(right_edge.size() - 1, -1, -1):
		body_points.append(right_edge[reverse_index])
	return body_points


## Dark-swamp Y-axis spin factor (legendary_items.py:10213-10218). 1.0 when
## the swamp presentation is idle; cos(t*20) while spinning. |value| < 0.05
## means the edge-on silhouette-line frame.
func _resolve_spin(context: Dictionary, time_sec: float) -> float:
	var odin_context: Dictionary = _odin_context(context)
	var swamp_context: Variant = odin_context.get(
		"dark_swamp",
		odin_context.get("dark_swamp_context", {})
	)
	var swamp_spinning: bool = (
		swamp_context is Dictionary and bool((swamp_context as Dictionary).get("active", false))
	)
	if not swamp_spinning:
		swamp_spinning = not _dark_swamp_array(context, "spikes", "dark_swamp_spikes", "lurker_spikes").is_empty()
	if not swamp_spinning:
		return 1.0
	return cos(time_sec * 0.8 * 20.0)


func _eldritch_circle(
	canvas: CanvasItem,
	origin: Vector2,
	unit: float,
	spin: float,
	local_x: float,
	local_y: float,
	local_radius: float,
	color: Color
) -> void:
	if local_radius <= 0.25 or color.a <= 0.003:
		return
	var center := _eldritch_point(origin, unit, spin, local_x, local_y)
	var radius: float = local_radius * unit
	if absf(absf(spin) - 1.0) < 0.01:
		canvas.draw_circle(center, radius, color)
	else:
		_fill_ellipse(canvas, center, radius * absf(spin), radius, color)


func _draw_eldritch_player(
	canvas: CanvasItem,
	visual_rect: Rect2,
	time_sec: float,
	opacity: float,
	disintegrate_progress: float,
	player_speed: float,
	spin: float = 1.0
) -> void:
	# Full-fidelity port of the legacy transformed form
	# (legendary_items.py:9864-10207, draw_dark_paddle). All local coordinates
	# are the legacy 180x185 surface space, mapped through _eldritch_point.
	var unit: float = minf(visual_rect.size.x / BASE_VISUAL_SIZE.x, visual_rect.size.y / BASE_VISUAL_SIZE.y)
	if unit <= 0.01 or opacity <= 0.01 or absf(spin) < 0.02:
		return
	var origin := Vector2(visual_rect.get_center().x, visual_rect.position.y)
	var t: float = time_sec * 0.8
	var lean: float = clampf(player_speed * 0.012, -0.32, 0.32)
	var lean_px: float = lean * 8.0
	var pulse: float = (sin(t * 3.0) + 1.0) * 0.5
	var displace: float = disintegrate_progress * 10.0
	var head_x: float = 90.0 + lean_px

	# --- 0. 보라빛 원형 후광 오라 (10 rings, per-ring wobble) ---
	for aura_index in range(10):
		var aura_radius: float = 74.0 - float(aura_index) * 5.0 + sin(t * 0.7 + float(aura_index) * 0.3) * 3.0
		var aura_alpha: float = (22.0 - float(aura_index) * 1.8) / 255.0
		if aura_radius <= 0.0 or aura_alpha <= 0.0:
			continue
		_eldritch_circle(
			canvas, origin, unit, spin,
			90.0 + lean * 4.0 + sin(t * 0.4 + float(aura_index) * 0.6) * 2.0,
			ELDRITCH_HEAD_Y + 30.0 + cos(t * 0.35 + float(aura_index) * 0.5) * 1.5,
			aura_radius,
			_alpha(Color(55.0 / 255.0, 25.0 / 255.0, 85.0 / 255.0, aura_alpha), opacity)
		)

	# --- 1. 몸통 — 24단계 유기적 실루엣 폴리곤 (어깨→가슴→허리→소멸) ---
	var body_points: PackedVector2Array = _build_eldritch_body_points(origin, unit, spin, t, lean_px, displace)
	# Animated point set: triangulation-guarded fill with a visible capsule
	# fallback (the animated-polygon trap).
	if body_points.size() >= 3 and not Geometry2D.triangulate_polygon(body_points).is_empty():
		var centroid := Vector2.ZERO
		for body_point in body_points:
			centroid += body_point
		centroid /= float(body_points.size())
		var glow_points := PackedVector2Array()
		var mid_points := PackedVector2Array()
		for body_point in body_points:
			var out_dir: Vector2 = body_point - centroid
			var out_dist: float = maxf(out_dir.length(), 0.001)
			var out_norm: Vector2 = out_dir / out_dist
			glow_points.append(body_point + Vector2(out_norm.x * 8.0, out_norm.y * 5.0) * unit)
			mid_points.append(body_point + Vector2(out_norm.x * 3.0, out_norm.y * 2.0) * unit)
		if not Geometry2D.triangulate_polygon(glow_points).is_empty():
			canvas.draw_colored_polygon(glow_points, _alpha(Color(40.0 / 255.0, 18.0 / 255.0, 60.0 / 255.0, 35.0 / 255.0), opacity))
		if not Geometry2D.triangulate_polygon(mid_points).is_empty():
			canvas.draw_colored_polygon(mid_points, _alpha(Color(22.0 / 255.0, 9.0 / 255.0, 35.0 / 255.0, 160.0 / 255.0), opacity))
		canvas.draw_colored_polygon(body_points, _alpha(Color(12.0 / 255.0, 4.0 / 255.0, 20.0 / 255.0, 220.0 / 255.0), opacity))
	else:
		var previous_body := _eldritch_point(origin, unit, spin, 90.0 + lean_px, ELDRITCH_SHOULDER_Y)
		for segment_index in range(1, 7):
			var segment_progress: float = float(segment_index) / 6.0
			var body_point := _eldritch_point(
				origin, unit, spin,
				90.0 + lean_px * (1.0 - segment_progress * 0.5),
				lerpf(ELDRITCH_SHOULDER_Y, ELDRITCH_BODY_END_Y, segment_progress)
			)
			var body_width: float = lerpf(48.0, 9.0, pow(segment_progress, 0.78)) * unit
			canvas.draw_line(previous_body, body_point, _alpha(DARK_CORE, opacity), maxf(1.0, body_width), true)
			previous_body = body_point

	# --- 2. 몸통 감싸는 소용돌이 에너지 (나선 위스프 8가닥 × 20세그먼트) ---
	for wisp_index in range(8):
		var wisp_offset: float = float(wisp_index) * (TAU / 8.0)
		var wisp_dir: float = 1.0 if wisp_index % 2 == 0 else -1.0
		var has_previous := false
		var previous_wisp := Vector2.ZERO
		for wisp_segment in range(20):
			var wisp_progress: float = float(wisp_segment) / 20.0
			var wisp_y: float = ELDRITCH_SHOULDER_Y - 5.0 + wisp_progress * (ELDRITCH_BODY_END_Y - ELDRITCH_SHOULDER_Y + 10.0)
			var wisp_angle: float = wisp_offset + t * 0.5 * wisp_dir + wisp_progress * PI * 3.0
			var wisp_radius: float
			if wisp_progress < 0.2:
				wisp_radius = 20.0 + wisp_progress * 40.0
			elif wisp_progress < 0.5:
				wisp_radius = 28.0 - (wisp_progress - 0.2) / 0.3 * 6.0
			else:
				wisp_radius = 22.0 - (wisp_progress - 0.5) / 0.5 * 14.0
			wisp_radius = maxf(3.0, wisp_radius + sin(t * 1.5 + wisp_index + wisp_progress * 4.0) * 4.0)
			var wisp_point := _eldritch_point(
				origin, unit, spin,
				90.0 + lean_px * (1.0 - wisp_progress * 0.5) + cos(wisp_angle) * wisp_radius,
				wisp_y
			)
			var edge_fade: float = minf(wisp_progress, 1.0 - wisp_progress) * 2.0
			var wisp_alpha: float = (
				70.0 * edge_fade * (0.6 + sin(t * 2.5 + float(wisp_index) * 1.3 + wisp_progress * 3.0) * 0.4)
			) / 255.0
			if has_previous and wisp_alpha > 0.003:
				var wisp_width: float = maxf(1.0, 4.0 * edge_fade * (1.0 + sin(t * 2.0 + wisp_index) * 0.3) * unit)
				canvas.draw_line(previous_wisp, wisp_point, _alpha(Color(50.0 / 255.0, 24.0 / 255.0, 72.0 / 255.0, wisp_alpha), opacity), wisp_width, true)
			previous_wisp = wisp_point
			has_previous = true

	# --- 3. 팔 촉수 (6개 × 18세그먼트, 글로우/미드/코어 3겹 + 팔 끝 3갈래) ---
	for arm_index in range(ELDRITCH_ARM_CONFIGS.size()):
		var arm_config: Array = ELDRITCH_ARM_CONFIGS[arm_index]
		var arm_side: float = float(arm_config[0])
		var arm_length: float = float(arm_config[3])
		var arm_thickness: float = float(arm_config[4])
		var arm_start_x: float = 90.0 + lean_px + arm_side * 20.0
		var arm_start_y: float = ELDRITCH_SHOULDER_Y + float(arm_config[1])
		var arm_segments := 18
		var arm_points: Array[Vector2] = []
		for arm_segment in range(arm_segments + 1):
			var arm_progress: float = float(arm_segment) / float(arm_segments)
			var curl: float = float(arm_config[5]) * arm_progress * arm_progress * float(arm_config[7])
			var arm_wave: float = sin(t * float(arm_config[6]) + float(arm_index) * 1.1 + arm_progress * 3.0) * 0.3 * arm_progress
			var arm_angle: float = PI * 0.5 * arm_side + float(arm_config[2]) + curl + arm_wave + lean * (1.0 - arm_progress)
			var arm_dist: float = arm_progress * arm_length
			arm_points.append(_eldritch_point(
				origin, unit, spin,
				arm_start_x + cos(arm_angle) * arm_dist
					+ sin(t * 0.8 + float(arm_index) * 1.5 + arm_progress * 4.0) * 3.0 * arm_progress
					+ sin(float(arm_index) * 1.9) * displace,
				arm_start_y + sin(arm_angle) * arm_dist * 0.55 + arm_progress * 18.0
					+ cos(t * 0.6 + float(arm_index) * 0.9 + arm_progress * 3.0) * 2.0 * arm_progress
					- cos(float(arm_index) * 1.3) * displace * 0.35
			))
		for arm_segment in range(1, arm_points.size()):
			var seg_progress: float = float(arm_segment) / float(arm_points.size())
			var outer_alpha: float = 30.0 * (1.0 - seg_progress * 0.5) / 255.0
			var mid_alpha: float = 160.0 * (1.0 - seg_progress * 0.4) / 255.0
			var core_alpha: float = 230.0 * (1.0 - seg_progress * 0.35) / 255.0
			var outer_width: float = maxf(2.0, arm_thickness * 1.6 * (1.0 - seg_progress * 0.7)) * unit
			var mid_width: float = maxf(1.0, arm_thickness * 1.05 * (1.0 - seg_progress * 0.65)) * unit
			var core_width: float = maxf(1.0, arm_thickness * 0.6 * (1.0 - seg_progress * 0.6)) * unit
			var mid_color := Color(
				(38.0 - seg_progress * 20.0) / 255.0,
				(15.0 - seg_progress * 8.0) / 255.0,
				(55.0 - seg_progress * 28.0) / 255.0,
				mid_alpha
			)
			var core_color := Color(
				maxf(0.0, 14.0 - seg_progress * 10.0) / 255.0,
				maxf(0.0, 4.0 - seg_progress * 3.0) / 255.0,
				maxf(0.0, 24.0 - seg_progress * 15.0) / 255.0,
				core_alpha
			)
			canvas.draw_line(arm_points[arm_segment - 1], arm_points[arm_segment], _alpha(Color(55.0 / 255.0, 28.0 / 255.0, 75.0 / 255.0, outer_alpha), opacity), outer_width, true)
			canvas.draw_line(arm_points[arm_segment - 1], arm_points[arm_segment], _alpha(mid_color, opacity), mid_width, true)
			canvas.draw_line(arm_points[arm_segment - 1], arm_points[arm_segment], _alpha(core_color, opacity), core_width, true)
		if arm_points.size() >= 2:
			var arm_tip: Vector2 = arm_points[arm_points.size() - 1]
			var tip_angle: float = (arm_tip - arm_points[arm_points.size() - 2]).angle()
			for fork_index in range(3):
				var fork_angle: float = tip_angle + float(fork_index - 1) * 0.5 + sin(t * 2.5 + arm_index + fork_index) * 0.2
				var fork_length: float = (9.0 + sin(t * 3.0 + fork_index + arm_index) * 3.0) * unit
				canvas.draw_line(
					arm_tip,
					arm_tip + Vector2(cos(fork_angle), sin(fork_angle)) * fork_length,
					_alpha(Color(22.0 / 255.0, 8.0 / 255.0, 35.0 / 255.0, 100.0 / 255.0), opacity),
					maxf(1.0, arm_thickness / 3.0 * unit),
					true
				)

	# --- 4. 머리 촉수 (6가닥 × 10세그먼트) ---
	for horn_index in range(ELDRITCH_HORN_CONFIGS.size()):
		var horn_config: Array = ELDRITCH_HORN_CONFIGS[horn_index]
		var horn_length: float = float(horn_config[1])
		var previous_horn := _eldritch_point(origin, unit, spin, head_x, ELDRITCH_HEAD_Y - 8.0)
		for horn_segment in range(1, 11):
			var horn_progress: float = float(horn_segment) / 10.0
			var horn_angle: float = float(horn_config[0]) - PI * 0.5 + sin(t * 1.2 + horn_index + horn_progress * 3.0) * 0.25 * horn_progress
			var horn_point := _eldritch_point(
				origin, unit, spin,
				head_x + cos(horn_angle) * horn_progress * horn_length,
				ELDRITCH_HEAD_Y - 8.0 + sin(horn_angle) * horn_progress * horn_length
			)
			var horn_alpha: float = 180.0 * (1.0 - horn_progress * 0.5) / 255.0
			var horn_width: float = maxf(1.0, float(horn_config[2]) * (1.0 - horn_progress * 0.7) * unit)
			canvas.draw_line(previous_horn, horn_point, _alpha(Color(30.0 / 255.0, 12.0 / 255.0, 45.0 / 255.0, horn_alpha), opacity), horn_width, true)
			previous_horn = horn_point

	# --- 5. 머리/얼굴 코어 (글로우 5링 + 코어 + 외곽 링) ---
	for glow_index in range(5):
		var head_glow_radius: float = 28.0 - float(glow_index) * 2.0 + pulse * 2.0
		if head_glow_radius > 0.0:
			_eldritch_circle(
				canvas, origin, unit, spin, head_x, ELDRITCH_HEAD_Y, head_glow_radius,
				_alpha(Color(46.0 / 255.0, 20.0 / 255.0, 70.0 / 255.0, 42.0 * (1.0 - float(glow_index) * 0.14) / 255.0), opacity)
			)
	_eldritch_circle(canvas, origin, unit, spin, head_x, ELDRITCH_HEAD_Y, 19.0, _alpha(Color(12.0 / 255.0, 5.0 / 255.0, 22.0 / 255.0, 245.0 / 255.0), opacity))
	var head_ring_center := _eldritch_point(origin, unit, spin, head_x, ELDRITCH_HEAD_Y)
	canvas.draw_polyline(
		_ellipse_points(head_ring_center, 19.0 * absf(spin) * unit, 19.0 * unit),
		_alpha(Color(40.0 / 255.0, 16.0 / 255.0, 58.0 / 255.0, 140.0 / 255.0), opacity),
		maxf(1.0, 2.0 * unit),
		true
	)

	# --- 6. 오딘의 눈 (8단계 색변화 글로우 + 코어 3겹 + 슬릿 눈동자) ---
	var eye_x: float = head_x + clampf(player_speed * 0.04, -4.0, 4.0)
	var eye_scale: float = 0.88 + pulse * 0.12
	for eye_glow_index in range(8):
		var eye_glow_radius: float = (19.0 - float(eye_glow_index) * 2.1) * eye_scale
		if eye_glow_radius <= 0.0:
			continue
		_eldritch_circle(
			canvas, origin, unit, spin, eye_x, ELDRITCH_HEAD_Y, eye_glow_radius,
			_alpha(Color(
				1.0,
				(195.0 - float(eye_glow_index) * 14.0) / 255.0,
				(60.0 - float(eye_glow_index) * 6.0) / 255.0,
				62.0 * (1.0 - float(eye_glow_index) * 0.1) / 255.0
			), opacity)
		)
	_eldritch_circle(canvas, origin, unit, spin, eye_x, ELDRITCH_HEAD_Y, 10.0 * eye_scale, _alpha(Color(1.0, 218.0 / 255.0, 105.0 / 255.0), opacity))
	_eldritch_circle(canvas, origin, unit, spin, eye_x, ELDRITCH_HEAD_Y, 7.0 * eye_scale, _alpha(Color(1.0, 235.0 / 255.0, 148.0 / 255.0), opacity))
	_eldritch_circle(canvas, origin, unit, spin, eye_x, ELDRITCH_HEAD_Y, 4.0 * eye_scale, _alpha(Color(1.0, 250.0 / 255.0, 215.0 / 255.0), opacity))
	canvas.draw_line(
		_eldritch_point(origin, unit, spin, eye_x, ELDRITCH_HEAD_Y - 4.0 * eye_scale),
		_eldritch_point(origin, unit, spin, eye_x, ELDRITCH_HEAD_Y + 4.0 * eye_scale),
		_alpha(Color(52.0 / 255.0, 28.0 / 255.0, 18.0 / 255.0, 230.0 / 255.0), opacity),
		maxf(1.0, 3.0 * eye_scale * unit),
		true
	)
	_eldritch_circle(
		canvas, origin, unit, spin,
		eye_x - 3.0 * eye_scale, ELDRITCH_HEAD_Y - 3.0 * eye_scale, 2.0 * eye_scale,
		_alpha(Color(1.0, 1.0, 250.0 / 255.0, 200.0 / 255.0), opacity * 0.86)
	)

	# --- 7. 룬 문자 (실제 룬 자형 7개, 심볼 순환·점멸·이중 글로우) ---
	for rune_index in range(7):
		var rune_orbit: float = t * 0.15 + float(rune_index) * (TAU / 7.0)
		var rune_dist: float = 54.0 + sin(t * 1.2 + float(rune_index) * 1.5) * 7.0
		var rune_x: float = 90.0 + lean * 4.0 + cos(rune_orbit) * rune_dist
		var rune_y: float = ELDRITCH_HEAD_Y + 22.0 + sin(rune_orbit) * rune_dist * 0.75
		var rune_alpha: float = clampf(200.0 * (0.45 + sin(t * 2.0 + float(rune_index) * 1.3) * 0.55), 0.0, 255.0) / 255.0
		if rune_alpha <= 0.01:
			continue
		var glyph: Array = ELDRITCH_RUNE_GLYPHS[(rune_index + int(t * 0.3)) % ELDRITCH_RUNE_GLYPHS.size()]
		for stroke_index in range(0, glyph.size() - 1, 2):
			var stroke_from: Vector2 = glyph[stroke_index]
			var stroke_to: Vector2 = glyph[stroke_index + 1]
			canvas.draw_line(
				_eldritch_point(origin, unit, spin, rune_x + stroke_from.x - 1.0, rune_y + stroke_from.y - 1.0),
				_eldritch_point(origin, unit, spin, rune_x + stroke_to.x - 1.0, rune_y + stroke_to.y - 1.0),
				_alpha(Color(210.0 / 255.0, 160.0 / 255.0, 248.0 / 255.0, rune_alpha * 0.4), opacity),
				maxf(1.0, 2.4 * unit),
				true
			)
			canvas.draw_line(
				_eldritch_point(origin, unit, spin, rune_x + stroke_from.x, rune_y + stroke_from.y),
				_eldritch_point(origin, unit, spin, rune_x + stroke_to.x, rune_y + stroke_to.y),
				_alpha(Color(185.0 / 255.0, 115.0 / 255.0, 218.0 / 255.0, rune_alpha), opacity),
				maxf(1.0, 1.3 * unit),
				true
			)

	# --- 9. 에너지 파동 (확장 링 2개) ---
	for wave_index in range(2):
		var wave_progress: float = fmod(t * 0.25 + float(wave_index) * 0.5, 1.0)
		var wave_radius: float = (25.0 + wave_progress * 38.0) * unit
		var wave_alpha: float = 18.0 * (1.0 - wave_progress) / 255.0
		if wave_alpha <= 0.003 or wave_radius <= 0.5:
			continue
		var wave_center := _eldritch_point(origin, unit, spin, 90.0 + lean * 4.0, ELDRITCH_HEAD_Y + 15.0)
		canvas.draw_polyline(
			_ellipse_points(wave_center, wave_radius * absf(spin), wave_radius),
			_alpha(Color(58.0 / 255.0, 26.0 / 255.0, 82.0 / 255.0, wave_alpha), opacity),
			maxf(1.0, 2.0 * unit),
			true
		)


func _draw_eldritch_ambient_particles(
	canvas: CanvasItem,
	context: Dictionary,
	visual_rect: Rect2,
	opacity: float,
	spin: float
) -> void:
	# 상시 어둠 입자 (legendary_items.py:10168-10196) — positions live in the
	# legacy 180x185 body-local space inside the afterimage state so they ride
	# the paddle, the dive offset, and the dark-swamp spin together.
	var particles: Variant = _afterimage_context(context).get("ambient_particles", [])
	if not (particles is Array):
		return
	var unit: float = minf(visual_rect.size.x / BASE_VISUAL_SIZE.x, visual_rect.size.y / BASE_VISUAL_SIZE.y)
	if unit <= 0.01 or absf(spin) < 0.02:
		return
	var origin := Vector2(visual_rect.get_center().x, visual_rect.position.y)
	for particle_variant in particles:
		if not (particle_variant is Dictionary):
			continue
		var particle: Dictionary = particle_variant
		var life_ratio: float = clampf(
			float(particle.get("life", 0.0)) / maxf(1.0, float(particle.get("max_life", 60.0))),
			0.0,
			1.0
		)
		var particle_size: float = float(particle.get("size", 2.0)) * life_ratio
		var particle_alpha: float = 145.0 * life_ratio / 255.0
		if particle_size <= 0.25 or particle_alpha <= 0.01:
			continue
		var color_index: int = clampi(int(particle.get("color_type", 0)), 0, ELDRITCH_PARTICLE_COLORS.size() - 1)
		_eldritch_circle(
			canvas, origin, unit, spin,
			float(particle.get("x", 90.0)), float(particle.get("y", 60.0)), particle_size,
			_alpha(Color(ELDRITCH_PARTICLE_COLORS[color_index], particle_alpha), opacity)
		)


func _draw_revival_cinematic(
	canvas: CanvasItem,
	visual_rect: Rect2,
	progress: float,
	time_sec: float,
	player_speed: float
) -> void:
	var safe_progress: float = clampf(progress, 0.0, 1.0)
	var unit: float = minf(visual_rect.size.x / BASE_VISUAL_SIZE.x, visual_rect.size.y / BASE_VISUAL_SIZE.y)
	var center := visual_rect.position + Vector2(visual_rect.size.x * 0.5, visual_rect.size.y * 0.43)
	if safe_progress < REVIVAL_GATHER_END:
		var gather_progress: float = safe_progress / REVIVAL_GATHER_END
		var sphere_radius: float = lerpf(10.0, 79.0, _ease_out_cubic(gather_progress)) * unit
		_draw_void_sphere(canvas, center, sphere_radius, time_sec, 0.72 + gather_progress * 0.28)
		for slot_index in range(10):
			var slot_angle: float = float(slot_index) * TAU / 10.0 + time_sec * (0.15 if slot_index % 2 == 0 else -0.12)
			var outer_radius: float = lerpf(150.0, sphere_radius + 14.0 / maxf(unit, 0.01), gather_progress) * unit
			var mote_pos := center + Vector2(cos(slot_angle) * outer_radius, sin(slot_angle) * outer_radius * 0.68)
			canvas.draw_line(mote_pos, mote_pos.lerp(center, 0.18), _alpha(ARCANE_PURPLE, 0.34 + gather_progress * 0.34), maxf(1.0, 1.5 * unit), true)
			canvas.draw_circle(mote_pos, maxf(1.0, (2.6 - float(slot_index % 3) * 0.45) * unit), _alpha(EYE_GOLD if slot_index % 4 == 0 else ARCANE_PURPLE, 0.72))
		return

	if safe_progress < REVIVAL_FORM_END:
		var form_progress: float = (safe_progress - REVIVAL_GATHER_END) / (REVIVAL_FORM_END - REVIVAL_GATHER_END)
		var form_radius: float = (79.0 + sin(time_sec * 5.2) * (3.0 + form_progress * 2.0)) * unit
		_draw_void_sphere(canvas, center, form_radius, time_sec, 1.0)
		_draw_sphere_cracks(canvas, center, form_radius, form_progress, time_sec, 0.88)
		canvas.draw_arc(center, form_radius + (8.0 + form_progress * 15.0) * unit, 0.0, TAU, 40, _alpha(EYE_GOLD, 0.18 + form_progress * 0.34), maxf(1.0, 2.0 * unit), true)
		return

	if safe_progress < REVIVAL_BURST_PREP_END:
		# 폭발 직전 (burst-prep, 2.5-3.0s): 구체가 수축 후 재팽창하며 골드 코어를
		# 응축한다 (원본 phase 2 shrink_expand). 충격파/몸 없음 — 오디오 빌드업 유지.
		var prep: float = (safe_progress - REVIVAL_FORM_END) / (REVIVAL_BURST_PREP_END - REVIVAL_FORM_END)
		var shrink_expand: float = 1.0 - sin(prep * PI) * 0.28
		var prep_radius: float = (79.0 * shrink_expand + sin(time_sec * 6.0) * 3.0) * unit
		_draw_void_sphere(canvas, center, prep_radius, time_sec, 1.0)
		_draw_sphere_cracks(canvas, center, prep_radius, 1.0, time_sec, 0.88 + prep * 0.5)
		var prep_core: float = (10.0 + prep * 20.0) * unit
		canvas.draw_circle(center, prep_core, _alpha(EYE_GOLD, 0.22 + prep * 0.5))
		canvas.draw_circle(center, prep_core * 0.5, _alpha(Color(1.0, 0.95, 0.7), 0.5 + prep * 0.45))
		return

	# 어둠 폭발 + 실루엣 공개 (dark-burst reveal, 3.0-3.75s; 원본 _update_dark_burst).
	# 폭발은 3.0s에 발화하고, 플래시는 오디오 BANG(3.20s = burst 0.267)에 맞춰 피크한
	# 뒤 3.75s까지 잔향으로 감쇠한다.
	var burst: float = (safe_progress - REVIVAL_BURST_PREP_END) / (1.0 - REVIVAL_BURST_PREP_END)
	# Audio-latency-compensated bang position (single-sourced from the state).
	var bang_t: float = OdinsEyeState.REVIVAL_BANG_T
	var flash_env: float = clampf(
		burst / bang_t if burst < bang_t else 1.0 - (burst - bang_t) / (1.0 - bang_t),
		0.0,
		1.0
	)
	# Pre-bang implosion: 마지막 급수축 + 코어 점등 (오디오 딥, bang 직전). bang_t에
	# 비례해 bang 직전까지 이어지도록 창을 잡는다.
	var implode_window: float = bang_t * 0.5
	if burst < implode_window:
		var implode: float = burst / maxf(0.001, implode_window)
		var implode_radius: float = lerpf(64.0, 12.0, implode) * unit
		canvas.draw_circle(center, implode_radius, _alpha(Color(0.10, 0.03, 0.16), 0.9))
		canvas.draw_circle(center, implode_radius * 0.6, _alpha(EYE_GOLD, 0.6 + implode * 0.4))
	var shock_radius: float = lerpf(24.0, 190.0, _ease_out_cubic(burst)) * unit
	canvas.draw_arc(center, shock_radius, 0.0, TAU, 48, _alpha(Color(0.86, 0.55, 1.0), 0.78 * flash_env), maxf(1.0, 6.0 * unit * flash_env + 1.0), true)
	canvas.draw_arc(center, shock_radius * 0.72, 0.0, TAU, 40, _alpha(EYE_GOLD, 0.56 * flash_env), maxf(1.0, 2.5 * unit), true)
	_draw_radial_burst(canvas, center, burst, time_sec, 16, 38.0 * unit, 150.0 * unit, flash_env)
	# 팡! — 오디오 BANG(3.20s)에 맞춰 터지는 대형 밝은 중심 플래시. flash_env를 제곱해
	# 피크를 날카롭게(짧고 강하게) 만든다 (원본 dark_burst center_burst_flash 255 등가).
	var bang: float = flash_env * flash_env
	if bang > 0.01:
		canvas.draw_circle(center, lerpf(70.0, 250.0, burst) * unit, _alpha(Color(0.82, 0.5, 1.0), 0.42 * bang))
		canvas.draw_circle(center, maxf(1.0, lerpf(110.0, 40.0, burst) * unit), _alpha(Color(1.0, 0.9, 1.0), 0.7 * bang))
		canvas.draw_circle(center, maxf(1.0, lerpf(46.0, 14.0, burst) * unit), _alpha(Color.WHITE, 0.85 * bang))
	else:
		canvas.draw_circle(center, maxf(1.0, lerpf(72.0, 16.0, burst) * unit), _alpha(EYE_GOLD, 0.22 * flash_env))

	# 원본은 dark_burst 시작(3.0s)에 실루엣을 즉시 full alpha로 스냅한다. 몸이 "팡"
	# (bang_t = 오디오BANG+지연)에 확 나타나도록 빠르게 스냅한 뒤 3.75s까지 full 유지 →
	# finalize 시 draw_player의 정착 몸(scale 1.0)으로 매끄럽게 인계된다.
	var reveal_alpha: float = _revival_reveal_alpha(burst, bang_t)
	var reveal_scale: float = lerpf(0.62, 1.0, reveal_alpha)
	_draw_eldritch_player(canvas, _scaled_rect(visual_rect, reveal_scale), time_sec, reveal_alpha, 0.0, player_speed)


## Silhouette reveal ramp for the dark-burst phase: snaps to full at the audio
## bang (burst == bang_t = 3.20s) then holds, mirroring the original's instant
## reveal at dark_burst start. Pure so the audio-sync seal can pin "full by the
## bang" (was a slow ramp finishing at 3.75s, which read as a late reveal).
func _revival_reveal_alpha(burst: float, bang_t: float) -> float:
	return _ease_out_cubic(clampf(burst / maxf(0.001, bang_t), 0.0, 1.0))


# Deterministic 0..1 hash — replaces the legacy per-frame random() so the death
# fragments/particles are stateless (each element's whole trajectory is a
# closed-form function of its index + phase_progress; a trail is just the same
# function re-evaluated at earlier elapsed frames).
const DEATH_DIS_FRAMES := 90.0
const DEATH_EXP_FRAMES := 60.0
const DEATH_GRAVITY := 0.15
# 8 named body parts (legendary_items.py:8993-9002) in legacy body-local px.
const DEATH_BODY_PARTS: Array = [
	["head", 0.0, -46.0, 12.0], ["eye_l", -7.0, -49.0, 5.0], ["eye_r", 7.0, -49.0, 5.0],
	["torso", 0.0, -18.0, 15.0], ["arm_l", -30.0, -20.0, 8.0], ["arm_r", 30.0, -20.0, 8.0],
	["leg_l", -11.0, 24.0, 10.0], ["leg_r", 11.0, 24.0, 10.0],
]
const DEATH_FLAME := Color(200.0 / 255.0, 100.0 / 255.0, 50.0 / 255.0)
const DEATH_PURPLE := Color(140.0 / 255.0, 60.0 / 255.0, 160.0 / 255.0)
const DEATH_RED := Color(180.0 / 255.0, 50.0 / 255.0, 70.0 / 255.0)
const DEATH_SMOKE := Color(50.0 / 255.0, 35.0 / 255.0, 55.0 / 255.0)
const DEATH_DARK := Color(40.0 / 255.0, 20.0 / 255.0, 50.0 / 255.0)
const DEATH_FRAG_BODY := Color(35.0 / 255.0, 18.0 / 255.0, 45.0 / 255.0)
const DEATH_EYE_BODY := Color(200.0 / 255.0, 60.0 / 255.0, 80.0 / 255.0)
const DEATH_EYE_GLOW := Color(255.0 / 255.0, 100.0 / 255.0, 120.0 / 255.0)
const DEATH_EYE_CORE := Color(255.0 / 255.0, 200.0 / 255.0, 200.0 / 255.0)
const DEATH_TRAIL := Color(40.0 / 255.0, 20.0 / 255.0, 50.0 / 255.0)
const DEATH_CRACK := Color(1.0, 150.0 / 255.0, 100.0 / 255.0)


func _hash11(n: float) -> float:
	return fposmod(sin(n * 127.1) * 43758.5453, 1.0)


func _draw_death_cinematic(canvas: CanvasItem, visual_rect: Rect2, plan: Dictionary, time_sec: float) -> void:
	var unit: float = minf(visual_rect.size.x / BASE_VISUAL_SIZE.x, visual_rect.size.y / BASE_VISUAL_SIZE.y)
	var center := visual_rect.position + Vector2(visual_rect.size.x * 0.5, visual_rect.size.y * 0.43)
	var phase: String = str(plan.get("death_phase", ""))
	var phase_progress: float = clampf(float(plan.get("death_phase_progress", 0.0)), 0.0, 1.0)
	if phase == "pre_explosion":
		_draw_death_pre_explosion(canvas, visual_rect, center, unit, plan, time_sec)
	elif phase == "explosion":
		_draw_death_explosion(canvas, center, unit, phase_progress, time_sec)
	elif phase == "disintegrate":
		_draw_death_disintegrate(canvas, center, unit, phase_progress)


func _draw_death_pre_explosion(
	canvas: CanvasItem,
	visual_rect: Rect2,
	center: Vector2,
	unit: float,
	plan: Dictionary,
	time_sec: float
) -> void:
	# 폭발 직전 (2.0s): 축적 오라 + 궤도 점 배경 위에, 죽어가는 몸의 tell —
	# 금색→붉은색 깜빡이는 눈, 눈에서 뻗는 균열, 새어나오는 에너지 파티클.
	var buildup: float = clampf(float(plan.get("death_energy_buildup", 0.0)), 0.0, 1.0)
	var aura_radius: float = lerpf(50.0, 82.0, buildup) * unit
	canvas.draw_circle(center, aura_radius, _alpha(VOID_PURPLE, 0.08 + buildup * 0.18))
	canvas.draw_arc(center, aura_radius, time_sec * 0.8, time_sec * 0.8 + PI * 1.55, 32, _alpha(ARCANE_PURPLE, 0.22 + buildup * 0.58), maxf(1.0, (1.0 + buildup * 2.0) * unit), true)
	for mote_index in range(7):
		var mote_angle: float = float(mote_index) * TAU / 7.0 + time_sec * 0.35
		var mote_radius: float = lerpf(120.0, 38.0, buildup) * unit
		var mote_pos := center + Vector2(cos(mote_angle) * mote_radius, sin(mote_angle) * mote_radius * 0.72)
		canvas.draw_circle(mote_pos, maxf(1.0, 2.4 * unit), _alpha(EYE_GOLD if mote_index % 3 == 0 else ARCANE_PURPLE, 0.38 + buildup * 0.48))

	# Dying eye stamped on the body's gold eye (ELDRITCH_HEAD_Y): rising red +
	# fast panic flicker reads as a gold->red crossfade without touching the body.
	var eye_pos := Vector2(visual_rect.get_center().x, visual_rect.position.y + ELDRITCH_HEAD_Y * unit)
	var flicker: float = 0.5 + sin(time_sec * 12.0) * 0.5
	for glow_index in range(4):
		var glow_radius: float = (15.0 - float(glow_index) * 3.0) * unit * (0.6 + flicker * 0.4)
		if glow_radius <= 0.0:
			continue
		canvas.draw_circle(eye_pos, glow_radius, _alpha(Color(
			1.0,
			lerpf(0.78, 0.20, buildup) * (1.0 - float(glow_index) * 0.2),
			lerpf(0.31, 0.08, buildup)
		), buildup * flicker * (0.4 - float(glow_index) * 0.08)))
	canvas.draw_circle(eye_pos, maxf(1.0, 5.0 * unit * flicker), _alpha(Color(1.0, lerpf(0.7, 0.25, buildup), 0.3), buildup))

	# Growing spider cracks radiating from the eye across the head/chest.
	var crack_count: int = int(ceil(buildup * 5.0))
	for crack_index in range(crack_count):
		var crack_angle: float = float(crack_index) * TAU / maxf(1.0, float(crack_count)) + time_sec * 0.2
		var crack_len: float = 25.0 * unit * (0.5 + buildup * 0.8)
		canvas.draw_line(eye_pos, eye_pos + Vector2(cos(crack_angle), sin(crack_angle)) * crack_len, _alpha(DEATH_CRACK, buildup * 0.9), maxf(1.0, 1.6 * unit), true)

	# Energy hemorrhage: particles bleed outward + droop under gravity.
	for particle_index in range(10):
		var particle_angle: float = _hash11(float(particle_index)) * TAU
		var drift: float = buildup * lerpf(20.0, 55.0, _hash11(float(particle_index) * 2.0)) * unit
		var particle_pos := eye_pos + Vector2(
			cos(particle_angle) * drift,
			sin(particle_angle) * drift * 0.7 + buildup * buildup * 20.0 * unit
		)
		var leak_color: Color = [DEATH_DARK, DEATH_PURPLE, DEATH_RED][particle_index % 3]
		canvas.draw_circle(particle_pos, maxf(1.0, 3.0 * unit), _alpha(leak_color, (1.0 - buildup * 0.4) * 0.7))


func _draw_death_explosion(
	canvas: CanvasItem,
	center: Vector2,
	unit: float,
	phase_progress: float,
	time_sec: float
) -> void:
	# 폭발 (1.0s): 다중 충격파 4겹 + 파편 폭발(불꽃 포함) + 가산-등가 중심 플래시.
	var explosion_fade: float = 1.0 - phase_progress
	# Cascading multi-shockwave (원본 4-wave, staggered).
	for wave_index in range(4):
		var wave_stagger: float = float(wave_index) * 0.06
		var wave_progress: float = _ease_out_cubic(clampf((phase_progress - wave_stagger) / maxf(0.001, 1.0 - wave_stagger), 0.0, 1.0))
		var wave_radius: float = wave_progress * (180.0 + float(wave_index) * 40.0) * unit
		var wave_alpha: float = (220.0 - float(wave_index) * 30.0) / 255.0 * (1.0 - wave_progress)
		if wave_radius <= 0.5 or wave_alpha <= 0.003:
			continue
		var wave_color: Color = (
			Color((120.0 - float(wave_index) * 20.0) / 255.0, (40.0 - float(wave_index) * 10.0) / 255.0, (80.0 - float(wave_index) * 15.0) / 255.0)
			if wave_index < 2
			else Color(60.0 / 255.0, 20.0 / 255.0, 40.0 / 255.0)
		)
		var wave_thickness: float = maxf(1.0, (5.0 - float(wave_index)) * unit)
		for ring_index in range(3):
			canvas.draw_arc(center, wave_radius + float(ring_index) * 3.0 * unit, 0.0, TAU, 40, _alpha(wave_color, wave_alpha / float(ring_index + 2)), wave_thickness + float(ring_index), true)

	# Underlying clean shock + arcs for continuity.
	var shock_radius: float = lerpf(22.0, 175.0, _ease_out_cubic(phase_progress)) * unit
	canvas.draw_arc(center, shock_radius, 0.0, TAU, 48, _alpha(Color(0.88, 0.58, 1.0), 0.5 * explosion_fade), maxf(1.0, 5.0 * unit * explosion_fade), true)
	canvas.draw_arc(center, shock_radius * 0.68, 0.0, TAU, 40, _alpha(EYE_GOLD, 0.45 * explosion_fade), maxf(1.0, 3.0 * unit), true)

	# Debris burst (~36; flame teardrops mixed with dark/purple/red/smoke).
	var burst_f: float = phase_progress * DEATH_EXP_FRAMES
	var life_ratio: float = clampf(1.0 - phase_progress, 0.0, 1.0)
	for debris_index in range(36):
		var debris_angle: float = _hash11(float(debris_index)) * TAU
		var debris_speed: float = lerpf(5.0, 20.0, _hash11(float(debris_index) * 3.0))
		var debris_pos := center + Vector2(cos(debris_angle), sin(debris_angle)) * debris_speed * burst_f * unit
		var debris_size: float = lerpf(5.0, 15.0, _hash11(float(debris_index) * 5.0)) * life_ratio * unit
		if debris_size <= 0.5:
			continue
		var debris_kind: int = debris_index % 5
		if debris_kind == 4:
			_draw_death_flame(canvas, debris_pos, debris_size, life_ratio)
		else:
			var debris_color: Color = [DEATH_DARK, DEATH_PURPLE, DEATH_RED, DEATH_SMOKE][debris_kind]
			canvas.draw_circle(debris_pos, debris_size, _alpha(debris_color, life_ratio * 0.85))

	# 팡! — 대형 밝은 중심 플래시. 오디오 BANG(1.92s)은 폭발 발화(2.0s)보다 살짝
	# 이르지만 오디오 출력 지연 때문에 실제로는 더 늦게 들리므로, 플래시 피크를
	# DEATH_BANG_FRAC(2.0s+지연)로 밀어 들리는 "팡"에 맞춘다. env를 제곱해 짧고
	# 강한 피크 + 흰 코어 (원본 flash 255 + center_burst 등가).
	var death_bang_t: float = clampf(OdinsEyeState.DEATH_BANG_FRAC, 0.0, 0.3)
	var flash_env: float = clampf(
		(
			phase_progress / maxf(0.001, death_bang_t)
			if phase_progress < death_bang_t
			else 1.0 - (phase_progress - death_bang_t) / 0.35
		),
		0.0,
		1.0
	)
	var bang: float = flash_env * flash_env
	if bang > 0.01:
		canvas.draw_circle(center, lerpf(90.0, 240.0, phase_progress) * unit, _alpha(Color(0.6, 0.24, 0.36), 0.5 * bang))
		canvas.draw_circle(center, maxf(1.0, lerpf(130.0, 40.0, phase_progress) * unit), _alpha(Color(1.0, 0.7, 0.8), 0.6 * bang))
		canvas.draw_circle(center, maxf(1.0, lerpf(60.0, 16.0, phase_progress) * unit), _alpha(Color(1.0, 0.95, 0.92), 0.85 * bang))


func _draw_death_disintegrate(canvas: CanvasItem, center: Vector2, unit: float, phase_progress: float) -> void:
	# 분해 (1.5s): 캐릭터가 8개 신체 부위로 산산조각 — 해부학적 방향 비산 + 중력 아크 +
	# 회전 + 모션 트레일, 눈은 붉게 발광. 소형 파편이 뒤를 채운다. (원본의 핵심 역동성.)
	var life_ratio: float = clampf(1.0 - phase_progress, 0.0, 1.0)
	var frame_f: float = phase_progress * DEATH_DIS_FRAMES

	# Extra disintegration shockwave (single ring, original max 120).
	var dis_wave: float = _ease_out_cubic(phase_progress) * 120.0 * unit
	if dis_wave > 0.5:
		canvas.draw_arc(center, dis_wave, 0.0, TAU, 40, _alpha(Color(80.0 / 255.0, 30.0 / 255.0, 60.0 / 255.0), life_ratio * 0.6), maxf(1.0, 3.0 * unit), true)

	# Dense small debris behind the main parts (staggered birth keeps emitting
	# while progress < 0.8), for volumetric mass.
	for debris_index in range(28):
		var birth_p: float = _hash11(float(debris_index) * 2.3) * 0.8
		if phase_progress < birth_p:
			continue
		var local_f: float = (phase_progress - birth_p) / maxf(0.001, 1.0 - birth_p) * DEATH_DIS_FRAMES
		var debris_origin := center + Vector2(
			(_hash11(float(debris_index) * 4.1) - 0.5) * 40.0,
			(_hash11(float(debris_index) * 4.7) - 0.7) * 45.0
		) * unit
		var debris_angle: float = _hash11(float(debris_index) * 5.3) * TAU
		var debris_speed: float = lerpf(4.0, 18.0, _hash11(float(debris_index) * 6.1))
		var debris_pos := debris_origin + Vector2(
			cos(debris_angle) * debris_speed * local_f,
			sin(debris_angle) * debris_speed * local_f - lerpf(1.0, 4.0, _hash11(float(debris_index) * 7.7)) * local_f + 0.5 * DEATH_GRAVITY * local_f * local_f
		) * unit
		var debris_size: float = lerpf(3.0, 10.0, _hash11(float(debris_index) * 8.3)) * (0.3 + life_ratio * 0.7) * unit
		if debris_size <= 0.5:
			continue
		var debris_color: Color = [DEATH_DARK, DEATH_PURPLE, DEATH_SMOKE][debris_index % 3]
		canvas.draw_circle(debris_pos, debris_size, _alpha(debris_color, life_ratio * 0.7))

	# 8 named body-part fragments — the shatter.
	for part_index in range(DEATH_BODY_PARTS.size()):
		var part: Array = DEATH_BODY_PARTS[part_index]
		var part_name: String = str(part[0])
		var origin := center + Vector2(float(part[1]), float(part[2])) * unit
		var is_eye: bool = part_name.begins_with("eye")
		# Anatomical direction: head/eyes up, arms up-out, legs down-out.
		var base_angle: float = atan2(float(part[2]), float(part[1])) + (_hash11(float(part_index) * 3.1) - 0.5)
		var speed: float = lerpf(6.0, 14.0, _hash11(float(part_index) * 5.7))
		var vx: float = cos(base_angle) * speed
		var vy0: float = sin(base_angle) * speed - lerpf(2.0, 5.0, _hash11(float(part_index) * 7.3))
		var draw_size: float = (float(part[3]) + (_hash11(float(part_index) * 15.1) * 6.0 - 2.0)) * (0.3 + life_ratio * 0.7) * unit
		if draw_size <= 0.5:
			continue
		var rotation_value: float = _hash11(float(part_index) * 9.1) * TAU + (_hash11(float(part_index) * 11.9) - 0.5) * 0.4 * frame_f
		var frag_pos := _death_frag_pos(origin, vx, vy0, frame_f, unit)

		# Stateless motion trail: the same closed-form position at earlier frames.
		for trail_index in range(1, 6):
			var trail_f: float = frame_f - float(trail_index) * 3.0
			if trail_f < 0.0:
				break
			var trail_pos := _death_frag_pos(origin, vx, vy0, trail_f, unit)
			canvas.draw_circle(trail_pos, maxf(1.0, draw_size * 0.6), _alpha(DEATH_TRAIL, life_ratio * (1.0 - float(trail_index) / 6.0) * 0.33))

		if is_eye:
			canvas.draw_circle(frag_pos, draw_size + 4.0 * unit, _alpha(DEATH_EYE_GLOW, life_ratio * 0.4))
			canvas.draw_circle(frag_pos, draw_size, _alpha(DEATH_EYE_BODY, life_ratio))
			canvas.draw_circle(frag_pos, maxf(1.0, draw_size / 3.0), _alpha(DEATH_EYE_CORE, life_ratio))
		else:
			_draw_death_chunk(canvas, frag_pos, draw_size, rotation_value, part_index, life_ratio)


func _death_frag_pos(origin: Vector2, vx: float, vy0: float, frame_f: float, unit: float) -> Vector2:
	# Analytic integration of the legacy per-frame vx/vy + gravity 0.15/frame^2.
	return origin + Vector2(vx * frame_f, vy0 * frame_f + 0.5 * DEATH_GRAVITY * frame_f * frame_f) * unit


func _draw_death_chunk(
	canvas: CanvasItem,
	frag_pos: Vector2,
	draw_size: float,
	rotation_value: float,
	part_index: int,
	life_ratio: float
) -> void:
	# Irregular 6-vertex hexagon body chunk. Monotone angle steps + bounded
	# positive radius jitter keep it star-convex (always triangulable); guarded
	# fill + draw_polyline outline give the solid-piece read.
	var points := PackedVector2Array()
	for vertex_index in range(6):
		var vertex_angle: float = rotation_value + float(vertex_index) * TAU / 6.0
		var vertex_radius: float = draw_size * (0.7 + _hash11(float(part_index) * 13.0 + float(vertex_index)) * 0.3)
		points.append(frag_pos + Vector2(cos(vertex_angle), sin(vertex_angle)) * vertex_radius)
	var body_color: Color = _alpha(DEATH_FRAG_BODY, life_ratio * 0.94)
	if Geometry2D.triangulate_polygon(points).is_empty():
		canvas.draw_circle(frag_pos, draw_size, body_color)
		return
	canvas.draw_colored_polygon(points, body_color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	canvas.draw_polyline(outline, _alpha(Color(65.0 / 255.0, 38.0 / 255.0, 75.0 / 255.0), life_ratio * 0.9), maxf(1.0, draw_size * 0.12), true)


func _draw_death_flame(canvas: CanvasItem, flame_pos: Vector2, flame_size: float, life_ratio: float) -> void:
	# Teardrop flame (legendary_items.py:9149-9157) — concave dart, triangulation-guarded.
	var points := PackedVector2Array([
		flame_pos + Vector2(0.0, -flame_size),
		flame_pos + Vector2(-flame_size * 0.6, flame_size * 0.4),
		flame_pos + Vector2(0.0, 0.0),
		flame_pos + Vector2(flame_size * 0.6, flame_size * 0.4),
	])
	var flame_color: Color = _alpha(DEATH_FLAME, life_ratio * 0.9)
	if Geometry2D.triangulate_polygon(points).is_empty():
		canvas.draw_circle(flame_pos, flame_size * 0.7, flame_color)
	else:
		canvas.draw_colored_polygon(points, flame_color)


func _draw_dark_swamp(canvas: CanvasItem, context: Dictionary, time_sec: float, shake_offset: Vector2) -> void:
	var spikes: Array = _dark_swamp_array(context, "spikes", "dark_swamp_spikes", "lurker_spikes")
	for spike_index in range(spikes.size()):
		var spike_variant: Variant = spikes[spike_index]
		if not (spike_variant is Dictionary):
			continue
		var spike: Dictionary = spike_variant
		_draw_dark_swamp_spike(canvas, spike, spike_index, time_sec, shake_offset)

	var fragments: Array = _dark_swamp_array(context, "fragments", "dark_swamp_fragments", "spike_fragments")
	for fragment_index in range(mini(fragments.size(), 36)):
		var fragment_variant: Variant = fragments[fragment_index]
		if not (fragment_variant is Dictionary):
			continue
		var fragment: Dictionary = fragment_variant
		var fragment_pos: Vector2 = _vector_value(
			fragment.get(
				"pos",
				fragment.get("position", Vector2(fragment.get("x", 0.0), fragment.get("y", 0.0)))
			),
			Vector2.ZERO
		) + shake_offset
		var fragment_alpha: float = _normalized_alpha(fragment.get("alpha", 1.0))
		var fragment_size: float = maxf(1.0, float(fragment.get("size", 4.0)))
		var fragment_angle: float = float(fragment.get("rotation", float(fragment_index) * 1.7))
		var direction := Vector2(cos(fragment_angle), sin(fragment_angle))
		canvas.draw_line(fragment_pos - direction * fragment_size * 0.5, fragment_pos + direction * fragment_size * 0.5, _alpha(ARCANE_PURPLE, fragment_alpha), maxf(1.0, fragment_size * 0.45), true)


# 럴커 가시 = 파세트 자수정 크리스탈 (legendary_items.py:10566-10796). Godot의
# draw_colored_polygon은 Pygame surface 할당 비용이 없으므로 원본의 3D 면·광택·
# 결·팁 글로우·서브 크리스탈 군집을 그대로 되살린다. 크리스탈 폴리곤은 star-convex라
# 삼각분할이 항상 성공하지만, 애니메이션 폴리곤 트랩 규칙대로 매 fill을 가드한다.
const SWAMP_CRYSTAL_BASE := Color(130.0 / 255.0, 55.0 / 255.0, 165.0 / 255.0)
const SWAMP_CRYSTAL_DARK := Color(75.0 / 255.0, 30.0 / 255.0, 105.0 / 255.0)
const SWAMP_CRYSTAL_MID := Color(150.0 / 255.0, 75.0 / 255.0, 190.0 / 255.0)
const SWAMP_CRYSTAL_HIGH := Color(195.0 / 255.0, 110.0 / 255.0, 235.0 / 255.0)
const SWAMP_CRYSTAL_EDGE := Color(210.0 / 255.0, 140.0 / 255.0, 255.0 / 255.0)
const SWAMP_SUB_BASE := Color(100.0 / 255.0, 45.0 / 255.0, 135.0 / 255.0)
const SWAMP_SUB_DARK := Color(65.0 / 255.0, 25.0 / 255.0, 95.0 / 255.0)
const SWAMP_SUB_HIGH := Color(155.0 / 255.0, 80.0 / 255.0, 200.0 / 255.0)
const SWAMP_SUB_EDGE := Color(170.0 / 255.0, 100.0 / 255.0, 230.0 / 255.0)
const SWAMP_POOL_OUTER := Color(15.0 / 255.0, 5.0 / 255.0, 25.0 / 255.0)
const SWAMP_POOL_MID := Color(30.0 / 255.0, 10.0 / 255.0, 50.0 / 255.0)
const SWAMP_POOL_CORE := Color(80.0 / 255.0, 30.0 / 255.0, 120.0 / 255.0)
const SWAMP_GLOW_OUTER := Color(140.0 / 255.0, 60.0 / 255.0, 220.0 / 255.0)
const SWAMP_GLOW_MID := Color(190.0 / 255.0, 120.0 / 255.0, 255.0 / 255.0)
const SWAMP_GLOW_CORE := Color(230.0 / 255.0, 180.0 / 255.0, 255.0 / 255.0)
const SWAMP_GLOW_INNER := Color(1.0, 220.0 / 255.0, 1.0)
const SWAMP_SHADOW := Color(10.0 / 255.0, 5.0 / 255.0, 18.0 / 255.0)


## 7-point faceted main-crystal outline (legendary_items.py:10704-10712). Pure
## builder so the geometry seal can sweep the animation range for triangulability.
func _build_swamp_crystal_points(
	cx: float,
	by: float,
	height: float,
	width: float,
	jag: float,
	apex: Vector2
) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(cx - width - 2.0, by),
		Vector2(cx + width + 2.0, by),
		Vector2(cx + width * 0.8, by - height * 0.35),
		Vector2(cx + width * 0.5 + jag, by - height * 0.65),
		apex,
		Vector2(cx - width * 0.5 - jag, by - height * 0.65),
		Vector2(cx - width * 0.8, by - height * 0.35),
	])


func _fill_convex(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> bool:
	# Triangulation-guarded fill (animated draw_colored_polygon trap). Returns
	# false when the point set is degenerate so callers can fall back cleanly.
	if points.size() < 3 or color.a <= 0.003:
		return false
	if Geometry2D.triangulate_polygon(points).is_empty():
		return false
	canvas.draw_colored_polygon(points, color)
	return true


func _swamp_brighten(color: Color, blend: float) -> Color:
	# Dissolving crystals wash toward white (legacy min(255, base + delta*blend)).
	return color.lerp(Color(1.0, 0.92, 1.0), clampf(blend, 0.0, 1.0) * 0.55)


func _draw_dark_swamp_spike(
	canvas: CanvasItem,
	spike: Dictionary,
	spike_index: int,
	time_sec: float,
	shake_offset: Vector2
) -> void:
	var base_pos: Vector2 = _vector_value(
		spike.get(
			"pos",
			spike.get("position", Vector2(float(spike.get("x", 0.0)), float(spike.get("y", 0.0))))
		),
		Vector2.ZERO
	) + shake_offset
	var phase: String = str(spike.get("phase", "hold"))
	var phase_progress: float = clampf(float(spike.get("phase_progress", 1.0)), 0.0, 1.0)
	var height: float = maxf(0.0, float(spike.get("current_height", spike.get("height", 0.0))))
	if not spike.has("current_height"):
		if phase == "rising":
			height *= _ease_out_cubic(phase_progress)
		elif phase == "falling":
			height *= 1.0 - phase_progress
	var width: float = maxf(2.0, float(spike.get("width", 8.0)))
	if height <= 0.5:
		return
	var alpha: float = _normalized_alpha(spike.get("dissolve_alpha", spike.get("alpha", 1.0)))
	var dissolving: bool = phase == "dissolving"
	if dissolving and not spike.has("dissolve_alpha"):
		alpha *= 1.0 - phase_progress
	if alpha <= 0.01:
		return
	var seed_id: float = float(int(spike.get("id", spike_index)))
	var spike_offset: float = float(spike.get("offset", seed_id * 1.37))
	var timer: float = time_sec * 60.0 + float(spike.get("timer_frames", 0.0))
	var wobble: float = float(spike.get("wobble", 0.0)) + sin(timer * 0.05 + spike_offset) * 1.2
	base_pos.x += wobble
	var cx: float = base_pos.x
	var by: float = base_pos.y
	var apex := Vector2(cx + sin(timer * 0.03 + spike_offset) * width * 0.22, by - height)
	var blend: float = (1.0 - alpha) if dissolving else 0.0

	# ─── 1. 바닥 웅덩이 (3레이어 맥동 타원) ───
	var ground_pulse: float = 0.85 + 0.15 * sin(timer * 0.08 + spike_offset)
	var ground_w: float = (width * 3.0 + 14.0) * ground_pulse
	var ground_h: float = 9.0 * ground_pulse
	_fill_ellipse(canvas, base_pos, ground_w, ground_h, _alpha(SWAMP_POOL_OUTER, alpha * 0.5))
	_fill_ellipse(canvas, base_pos, ground_w * 0.7, ground_h * 0.7, _alpha(SWAMP_POOL_MID, alpha * 0.7))
	_fill_ellipse(canvas, base_pos, ground_w * 0.35, ground_h * 0.4, _alpha(SWAMP_POOL_CORE, alpha * 0.4))

	# ─── 2. 서브 크리스탈 군집 (2~4개, 원본 데이터 사용) ───
	var sub_crystals: Variant = spike.get("sub_crystals", [])
	if sub_crystals is Array:
		for sub_index in range((sub_crystals as Array).size()):
			var sub_variant: Variant = sub_crystals[sub_index]
			if sub_variant is Dictionary:
				_draw_swamp_sub_crystal(canvas, sub_variant, cx, by, height, width, alpha, blend, timer, sub_index, dissolving)

	# ─── 3. 메인 크리스탈 (7점 파세트 + 3D 면 + 광택 + 결 + 외곽선) ───
	var jag: float = width * 0.15 * sin(timer * 0.12 + spike_offset)
	var main_points: PackedVector2Array = _build_swamp_crystal_points(cx, by, height, width, jag, apex)
	var base_color: Color = _swamp_brighten(SWAMP_CRYSTAL_BASE, blend)
	var shadow_points := PackedVector2Array()
	for point in main_points:
		shadow_points.append(point + Vector2(4.0, 4.0))
	_fill_convex(canvas, shadow_points, _alpha(SWAMP_SHADOW, alpha * 0.4))
	if not _fill_convex(canvas, main_points, _alpha(base_color, alpha)):
		# Degenerate fallback: legacy 4-line stick so a spike is never invisible.
		canvas.draw_line(base_pos, apex, _alpha(base_color, alpha), maxf(1.0, width * 2.0), true)
		return
	# 오른쪽 어두운 면 (3D).
	_fill_convex(canvas, PackedVector2Array([
		main_points[1], main_points[2], main_points[3], apex,
		Vector2(cx + width * 0.15, by - height * 0.5), Vector2(cx + width * 0.1, by),
	]), _alpha(_swamp_brighten(SWAMP_CRYSTAL_DARK, blend), alpha))
	# 왼쪽 밝은 면 (하이라이트).
	_fill_convex(canvas, PackedVector2Array([
		main_points[0], main_points[6], main_points[5], apex,
		Vector2(cx - width * 0.15, by - height * 0.5), Vector2(cx - width * 0.1, by),
	]), _alpha(_swamp_brighten(SWAMP_CRYSTAL_HIGH, blend), alpha))
	# 중앙 광택 스트라이프.
	if not dissolving and height > 20.0:
		_fill_convex(canvas, PackedVector2Array([
			Vector2(cx - width * 0.15, by - height * 0.1),
			Vector2(cx + width * 0.08, by - height * 0.1),
			Vector2(cx + width * 0.12, by - height * 0.7),
			Vector2(cx, by - height + 3.0),
			Vector2(cx - width * 0.1, by - height * 0.7),
		]), _alpha(_swamp_brighten(SWAMP_CRYSTAL_MID, blend), alpha * 0.6))
	# 외곽선 (글로우 라인).
	var outline := PackedVector2Array(main_points)
	outline.append(main_points[0])
	canvas.draw_polyline(outline, _alpha(SWAMP_CRYSTAL_EDGE, alpha * 0.7), maxf(1.0, 2.0), true)
	# 내부 결 라인 (크리스탈 결).
	if not dissolving and height > 25.0:
		for grain_frac in [0.3, 0.55]:
			var grain_y: float = by - height * grain_frac
			var grain_half: float = width * (1.0 - grain_frac * 0.6)
			canvas.draw_line(Vector2(cx - grain_half, grain_y), Vector2(cx + grain_half, grain_y), _alpha(SWAMP_CRYSTAL_EDGE, alpha * 0.25), 1.0, true)

	# ─── 4. 팁 글로우 (3레이어 맥동 구체) + 스파클 ───
	if not dissolving:
		var pulse: float = 0.8 + 0.2 * sin(timer * 0.15 + spike_offset)
		canvas.draw_circle(apex, maxf(1.0, 13.0 * pulse), _alpha(SWAMP_GLOW_OUTER, alpha * 0.2))
		canvas.draw_circle(apex, maxf(1.0, 8.0 * pulse), _alpha(SWAMP_GLOW_MID, alpha * 0.4))
		canvas.draw_circle(apex, maxf(1.0, 4.0 * pulse), _alpha(SWAMP_GLOW_CORE, alpha * 0.7))
		canvas.draw_circle(apex, maxf(1.0, 2.0 * pulse), _alpha(SWAMP_GLOW_INNER, alpha * 0.86))
		# 주변 트윙클 스파클 3개 (sin 밝기 변화).
		for sparkle_index in range(3):
			var twinkle: float = 0.5 + 0.5 * sin(timer * 0.12 * (1.0 + float(sparkle_index) * 0.4) + seed_id + float(sparkle_index) * 2.1)
			if twinkle <= 0.15:
				continue
			var sparkle_angle: float = _hash11(seed_id + float(sparkle_index) * 3.3) * TAU
			var sparkle_dist: float = (width + 6.0 + float(sparkle_index) * 5.0)
			var sparkle_pos := apex + Vector2(cos(sparkle_angle) * sparkle_dist, sin(sparkle_angle) * sparkle_dist * 0.8 - height * 0.1)
			canvas.draw_circle(sparkle_pos, maxf(1.0, 3.0), _alpha(SWAMP_GLOW_MID, alpha * twinkle * 0.5))
			canvas.draw_circle(sparkle_pos, maxf(1.0, 1.4), _alpha(SWAMP_GLOW_INNER, alpha * twinkle))


func _draw_swamp_sub_crystal(
	canvas: CanvasItem,
	sub: Dictionary,
	cx: float,
	by: float,
	height: float,
	width: float,
	alpha: float,
	blend: float,
	timer: float,
	sub_index: int,
	dissolving: bool
) -> void:
	var sub_x: float = cx + float(sub.get("offset_x", 0.0))
	var sub_base_y: float = by - height * float(sub.get("offset_y_ratio", 0.2))
	var sub_h: float = height * float(sub.get("height_ratio", 0.4))
	var sub_w: float = width * float(sub.get("width_ratio", 0.6))
	if sub_h <= 2.0 or sub_w <= 1.0:
		return
	var angle_rad: float = deg_to_rad(float(sub.get("angle_deg", 0.0)))
	var lean: float = sin(angle_rad) * sub_h
	var sub_tip := Vector2(sub_x + lean * 0.3, sub_base_y - sub_h)
	var sub_points := PackedVector2Array([
		Vector2(sub_x - sub_w, sub_base_y),
		Vector2(sub_x + sub_w, sub_base_y),
		Vector2(sub_x + sub_w * 0.4 + lean * 0.15, sub_base_y - sub_h * 0.6),
		sub_tip,
		Vector2(sub_x - sub_w * 0.4 + lean * 0.15, sub_base_y - sub_h * 0.6),
	])
	# 서브 그림자.
	var sub_shadow := PackedVector2Array()
	for point in sub_points:
		sub_shadow.append(point + Vector2(3.0, 3.0))
	_fill_convex(canvas, sub_shadow, _alpha(SWAMP_SHADOW, alpha * 0.3))
	if not _fill_convex(canvas, sub_points, _alpha(_swamp_brighten(SWAMP_SUB_BASE, blend), alpha)):
		return
	# 서브 어두운 면 / 밝은 면.
	_fill_convex(canvas, PackedVector2Array([
		sub_points[1], sub_points[2], sub_points[3], Vector2(sub_x + sub_w * 0.2, sub_base_y - sub_h * 0.4),
	]), _alpha(_swamp_brighten(SWAMP_SUB_DARK, blend), alpha))
	_fill_convex(canvas, PackedVector2Array([
		sub_points[0], sub_points[4], sub_points[3], Vector2(sub_x - sub_w * 0.2, sub_base_y - sub_h * 0.4),
	]), _alpha(_swamp_brighten(SWAMP_SUB_HIGH, blend), alpha))
	# 서브 외곽선.
	var sub_outline := PackedVector2Array(sub_points)
	sub_outline.append(sub_points[0])
	canvas.draw_polyline(sub_outline, _alpha(SWAMP_SUB_EDGE, alpha * 0.6), 1.0, true)
	# 서브 팁 글로우.
	if not dissolving:
		var sub_glow: float = 4.0 + sin(timer * 0.25 + float(sub_index) * 1.7) * 1.5
		canvas.draw_circle(sub_tip, maxf(1.0, sub_glow), _alpha(SWAMP_GLOW_MID, alpha * 0.35))
		canvas.draw_circle(sub_tip, maxf(1.0, sub_glow * 0.5), _alpha(SWAMP_GLOW_CORE, alpha * 0.24))


func _draw_void_sphere(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	time_sec: float,
	opacity: float
) -> void:
	if radius <= 0.5 or opacity <= 0.01:
		return
	canvas.draw_circle(center, radius * 1.16, _alpha(VOID_PURPLE, opacity * 0.15))
	canvas.draw_circle(center, radius, _alpha(DARK_MID, opacity * 0.94))
	canvas.draw_circle(center + Vector2(-radius * 0.09, -radius * 0.08), radius * 0.76, _alpha(DARK_CORE, opacity))
	canvas.draw_arc(center, radius * 0.87, time_sec * 0.7, time_sec * 0.7 + PI * 1.35, 36, _alpha(ARCANE_PURPLE, opacity * 0.45), maxf(1.0, radius * 0.035), true)
	canvas.draw_circle(center - Vector2(radius * 0.18, radius * 0.19), maxf(1.0, radius * 0.09), _alpha(EYE_GOLD, opacity * 0.42))


func _draw_sphere_cracks(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	progress: float,
	time_sec: float,
	opacity: float
) -> void:
	var safe_progress: float = clampf(progress, 0.0, 1.0)
	if safe_progress <= 0.01 or radius <= 0.5:
		return
	for crack_index in range(7):
		var crack_angle: float = float(crack_index) * TAU / 7.0 + sin(float(crack_index) * 2.1) * 0.18 + time_sec * 0.01
		var crack_start := center + Vector2(cos(crack_angle), sin(crack_angle)) * radius * 0.18
		var crack_mid := center + Vector2(cos(crack_angle + 0.12 * sin(crack_index)), sin(crack_angle + 0.12 * sin(crack_index))) * radius * (0.42 + 0.14 * safe_progress)
		var crack_end := center + Vector2(cos(crack_angle - 0.10), sin(crack_angle - 0.10)) * radius * lerpf(0.52, 0.92, safe_progress)
		canvas.draw_line(crack_start, crack_mid, _alpha(EYE_GOLD, opacity * safe_progress * 0.86), maxf(1.0, radius * 0.025), true)
		canvas.draw_line(crack_mid, crack_end, _alpha(ARCANE_PURPLE, opacity * safe_progress), maxf(1.0, radius * 0.018), true)


func _draw_radial_burst(
	canvas: CanvasItem,
	center: Vector2,
	progress: float,
	time_sec: float,
	spoke_count: int,
	inner_radius: float,
	outer_radius: float,
	opacity: float
) -> void:
	if opacity <= 0.01:
		return
	for spoke_index in range(spoke_count):
		var spoke_angle: float = float(spoke_index) * TAU / float(spoke_count) + time_sec * 0.035
		var spoke_scale: float = 0.76 + 0.24 * sin(float(spoke_index) * 2.41)
		var start := center + Vector2(cos(spoke_angle), sin(spoke_angle)) * inner_radius * (0.6 + progress * 0.4)
		var finish := center + Vector2(cos(spoke_angle), sin(spoke_angle)) * lerpf(inner_radius, outer_radius * spoke_scale, _ease_out_cubic(progress))
		var spoke_color: Color = EYE_GOLD if spoke_index % 4 == 0 else ARCANE_PURPLE
		canvas.draw_line(start, finish, _alpha(spoke_color, opacity * 0.72), maxf(1.0, 3.0 * opacity), true)


# ==================== 👻 잔상 / 🌑 대쉬 다이브 ====================

const AFTERIMAGE_DRAW_LIMIT := 24
const SOUL_PARTICLE_DRAW_LIMIT := 80
const FOG_PURPLE := Color(30.0 / 255.0, 15.0 / 255.0, 45.0 / 255.0)
const TENTACLE_PURPLE := Color(35.0 / 255.0, 18.0 / 255.0, 50.0 / 255.0)
const SILHOUETTE_CORE := Color(20.0 / 255.0, 10.0 / 255.0, 30.0 / 255.0)
const SILHOUETTE_RING := Color(50.0 / 255.0, 25.0 / 255.0, 70.0 / 255.0)
const AFTERIMAGE_EYE_GLOW := Color(1.0, 200.0 / 255.0, 100.0 / 255.0)
const AFTERIMAGE_EYE_BODY := Color(1.0, 220.0 / 255.0, 130.0 / 255.0)
const AFTERIMAGE_PUPIL := Color(50.0 / 255.0, 25.0 / 255.0, 15.0 / 255.0)
const SOUL_GLOW := Color(180.0 / 255.0, 140.0 / 255.0, 220.0 / 255.0)
const SOUL_CORE := Color(220.0 / 255.0, 200.0 / 255.0, 1.0)
const SMOKE_PURPLE := Color(60.0 / 255.0, 40.0 / 255.0, 80.0 / 255.0)
const WISP_CORE := Color(200.0 / 255.0, 150.0 / 255.0, 1.0)
const WISP_BRIGHT := Color(1.0, 220.0 / 255.0, 1.0)
const TRAIL_SHADOW_OUTER := Color(25.0 / 255.0, 12.0 / 255.0, 40.0 / 255.0)
const TRAIL_SHADOW_INNER := Color(12.0 / 255.0, 5.0 / 255.0, 22.0 / 255.0)
const TRAIL_EYE_PURPLE := Color(80.0 / 255.0, 40.0 / 255.0, 120.0 / 255.0)
const CRACK_GLOW := Color(60.0 / 255.0, 30.0 / 255.0, 90.0 / 255.0)
const CRACK_CORE := Color(80.0 / 255.0, 40.0 / 255.0, 120.0 / 255.0)
const RIPPLE_OUTER := Color(70.0 / 255.0, 35.0 / 255.0, 100.0 / 255.0)
const RIPPLE_INNER := Color(50.0 / 255.0, 25.0 / 255.0, 75.0 / 255.0)
const DISSOLVE_SMOKE_DOT := Color(60.0 / 255.0, 35.0 / 255.0, 80.0 / 255.0)


func _draw_afterimages(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	# legendary_items.py:7442-7467 — soul particles behind, silhouettes on top.
	var afterimage_context: Dictionary = _afterimage_context(context)
	var souls: Variant = afterimage_context.get("soul_particles", [])
	if souls is Array:
		for soul_index in range(mini((souls as Array).size(), SOUL_PARTICLE_DRAW_LIMIT)):
			var soul_variant: Variant = souls[soul_index]
			if soul_variant is Dictionary:
				_draw_soul_particle(canvas, soul_variant, shake_offset)
	var afterimages: Variant = afterimage_context.get("afterimages", [])
	if not (afterimages is Array):
		return
	for afterimage_index in range(mini((afterimages as Array).size(), AFTERIMAGE_DRAW_LIMIT)):
		var afterimage_variant: Variant = afterimages[afterimage_index]
		if not (afterimage_variant is Dictionary):
			continue
		var afterimage: Dictionary = afterimage_variant
		var alpha: float = _normalized_alpha(afterimage.get("alpha", 0.0))
		if alpha <= 0.01:
			continue
		# Silhouette anchors 60px above the paddle anchor (legendary 7464/7467).
		var center := Vector2(
			float(afterimage.get("x", 0.0)),
			float(afterimage.get("y", 0.0)) - 60.0
		) + shake_offset
		if str(afterimage.get("phase", "hold")) == "hit":
			_draw_dissolving_afterimage(
				canvas,
				center,
				alpha,
				float(afterimage.get("hit_timer", 0.0)),
				float(afterimage.get("dissolve_offset", 0.0))
			)
		else:
			_draw_afterimage_silhouette(
				canvas,
				center,
				alpha,
				float(afterimage.get("timer", 0.0))
			)


func _draw_afterimage_silhouette(
	canvas: CanvasItem,
	center: Vector2,
	alpha: float,
	timer_frames: float
) -> void:
	# Mini eldritch-eye silhouette (legendary_items.py:7469-7545), scale 0.6.
	var t: float = timer_frames * 0.08
	var s := 0.6

	for fog_index in range(4):
		var fog_angle: float = t * 0.4 + float(fog_index) * (PI / 2.0)
		var fog_dist: float = 25.0 + sin(t * 2.0 + fog_index) * 5.0
		var fog_pos := center + Vector2(cos(fog_angle) * fog_dist, sin(fog_angle) * fog_dist * 0.6)
		canvas.draw_circle(fog_pos, 12.0, _alpha(FOG_PURPLE, alpha * 0.25))

	for tentacle_index in range(6):
		var base_angle: float = (float(tentacle_index) / 6.0) * TAU + t * 0.3
		var wave_offset: float = sin(t * 4.0 + tentacle_index) * 0.25
		var tentacle_len: float = 25.0 + sin(t * 2.0 + float(tentacle_index) * 0.5) * 5.0
		var previous := center
		for segment_index in range(1, 6):
			var progress: float = float(segment_index) / 5.0
			var dist: float = progress * tentacle_len * s
			var angle: float = base_angle + wave_offset * progress * 2.0
			var thickness: float = maxf(1.0, (1.0 - progress * 0.6) * 4.0)
			var point := center + Vector2(cos(angle) * dist, sin(angle) * dist * 0.7)
			canvas.draw_line(previous, point, _alpha(TENTACLE_PURPLE, alpha * 0.6 * (1.0 - progress * 0.4)), thickness, true)
			previous = point

	var core_radius: float = 12.0 * s
	canvas.draw_circle(center, core_radius, _alpha(SILHOUETTE_CORE, alpha * 0.7))
	canvas.draw_arc(center, core_radius, 0.0, TAU, 16, _alpha(SILHOUETTE_RING, alpha * 0.5), 1.0, true)

	var eye_alpha: float = alpha * (0.6 + sin(t * 4.0) * 0.2)
	for glow_index in range(3):
		var glow_radius: float = (8.0 - float(glow_index) * 2.0) * s
		if glow_radius > 0.0:
			canvas.draw_circle(center, glow_radius, _alpha(AFTERIMAGE_EYE_GLOW, eye_alpha * 0.5 * (1.0 - float(glow_index) * 0.25)))
	canvas.draw_circle(center, 5.0 * s, _alpha(AFTERIMAGE_EYE_BODY, eye_alpha))
	canvas.draw_line(
		center + Vector2(0.0, -2.0 * s),
		center + Vector2(0.0, 2.0 * s),
		_alpha(AFTERIMAGE_PUPIL, eye_alpha * 0.8),
		maxf(1.0, 2.0 * s),
		true
	)


func _draw_dissolving_afterimage(
	canvas: CanvasItem,
	center: Vector2,
	alpha: float,
	hit_timer_frames: float,
	dissolve_offset: float
) -> void:
	# Soul-escape dissolve (legendary_items.py:7587-7670).
	var hit_progress: float = clampf(hit_timer_frames / 45.0, 0.0, 1.0)
	var t: float = hit_timer_frames * 0.15
	var shake := Vector2(sin(t * 10.0) * (3.0 + hit_progress * 10.0), -dissolve_offset)

	for tentacle_index in range(6):
		var base_angle: float = (float(tentacle_index) / 6.0) * TAU + t * 0.8
		var spread: float = 1.0 + hit_progress * 3.0
		var tentacle_len: float = (20.0 + sin(t * 4.0 + tentacle_index) * 5.0) * spread
		var previous := center + shake
		for segment_index in range(1, 5):
			var progress: float = float(segment_index) / 4.0
			var dist: float = progress * tentacle_len * 0.6
			var angle: float = base_angle + sin(t * 6.0 + tentacle_index + segment_index) * 0.3 * hit_progress
			var thickness: float = maxf(1.0, (1.0 - progress * 0.6) * 3.0 * (1.0 - hit_progress * 0.5))
			var point := center + shake + Vector2(
				cos(angle) * dist,
				sin(angle) * dist * 0.7 - hit_progress * 15.0
			)
			var segment_alpha: float = alpha * 0.5 * (1.0 - progress * 0.3) * (1.0 - hit_progress * 0.7)
			if segment_alpha > 0.0:
				canvas.draw_line(previous, point, _alpha(SILHOUETTE_RING, segment_alpha), thickness, true)
			previous = point

	var core_radius: float = 10.0 * (1.0 - hit_progress * 0.6)
	if core_radius > 0.0:
		canvas.draw_circle(center + shake, core_radius, _alpha(Color(25.0 / 255.0, 12.0 / 255.0, 35.0 / 255.0), alpha * 0.6 * (1.0 - hit_progress * 0.5)))

	var flicker: float = 0.3 + sin(t * 15.0) * 0.7 if hit_progress < 0.8 else (1.0 - hit_progress) * 5.0
	var eye_alpha: float = alpha * flicker * (1.0 - hit_progress * 0.8)
	if eye_alpha > 10.0 / 255.0:
		var eye_center := center + shake + Vector2(0.0, -hit_progress * 20.0)
		for glow_index in range(3):
			var glow_radius: float = (7.0 - float(glow_index) * 2.0) * (1.0 - hit_progress * 0.5)
			if glow_radius > 0.0:
				canvas.draw_circle(eye_center, glow_radius, _alpha(AFTERIMAGE_EYE_GLOW, eye_alpha * 0.5 * (1.0 - float(glow_index) * 0.25)))
		var eye_radius: float = 4.0 * (1.0 - hit_progress * 0.4)
		if eye_radius > 0.0:
			canvas.draw_circle(eye_center, eye_radius, _alpha(AFTERIMAGE_EYE_BODY, eye_alpha))

	for smoke_index in range(5):
		var smoke_angle: float = t * 0.5 + float(smoke_index) * (TAU / 5.0)
		var smoke_dist: float = 15.0 + hit_progress * 25.0
		var smoke_pos := center + shake + Vector2(
			cos(smoke_angle) * smoke_dist,
			sin(smoke_angle) * smoke_dist * 0.5 - hit_progress * 25.0
		)
		var smoke_alpha: float = alpha * 0.3 * (1.0 - hit_progress * 0.6)
		if smoke_alpha > 0.0:
			canvas.draw_circle(smoke_pos, maxf(1.0, 3.0 - hit_progress * 2.0), _alpha(DISSOLVE_SMOKE_DOT, smoke_alpha))


func _draw_soul_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	# legendary_items.py:7547-7585.
	var max_life: float = maxf(1.0, float(particle.get("max_life", 60.0)))
	var size: float = float(particle.get("size", 6.0)) * clampf(float(particle.get("life", 0.0)) / max_life, 0.0, 1.0)
	var alpha: float = _normalized_alpha(particle.get("alpha", 0.0))
	if size <= 0.5 or alpha <= 0.01:
		return
	var pos := Vector2(float(particle.get("x", 0.0)), float(particle.get("y", 0.0))) + shake_offset
	var particle_type: String = str(particle.get("type", "soul"))
	if particle_type == "soul":
		canvas.draw_circle(pos, size + 4.0, _alpha(SOUL_GLOW, alpha * 0.5))
		canvas.draw_circle(pos, size, _alpha(SOUL_CORE, alpha))
		canvas.draw_circle(pos, maxf(1.0, size * 0.5), _alpha(Color.WHITE, alpha))
	elif particle_type == "smoke":
		var rotation_value: float = float(particle.get("rotation", 0.0))
		var life_value: float = float(particle.get("life", 0.0))
		var points := PackedVector2Array()
		for point_index in range(6):
			var point_angle: float = rotation_value + (float(point_index) / 6.0) * TAU
			var point_radius: float = size * (0.6 + sin(point_angle * 3.0 + life_value * 0.1) * 0.4)
			points.append(pos + Vector2(cos(point_angle), sin(point_angle)) * point_radius)
		# Animated point set: guard the fill per the triangulation trap, with a
		# visible circle fallback.
		if Geometry2D.triangulate_polygon(points).is_empty():
			canvas.draw_circle(pos, size * 0.8, _alpha(SMOKE_PURPLE, alpha))
		else:
			canvas.draw_colored_polygon(points, _alpha(SMOKE_PURPLE, alpha))
	else:
		canvas.draw_circle(pos, size, _alpha(WISP_CORE, alpha))
		canvas.draw_circle(pos, maxf(1.0, size * 0.5), _alpha(WISP_BRIGHT, minf(1.0, alpha + 30.0 / 255.0)))


func _draw_dive_effects(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	# legendary_items.py:7196-7217 draw order: ripples → trail → cracks → particles.
	var afterimage_context: Dictionary = _afterimage_context(context)

	var ripples: Variant = afterimage_context.get("ground_ripples", [])
	if ripples is Array:
		for ripple_variant in ripples:
			if not (ripple_variant is Dictionary):
				continue
			var ripple: Dictionary = ripple_variant
			var ripple_alpha: float = _normalized_alpha(ripple.get("alpha", 0.0))
			var radius: float = float(ripple.get("radius", 0.0))
			if ripple_alpha <= 0.01 or radius <= 0.5:
				continue
			var ripple_pos := Vector2(float(ripple.get("x", 0.0)), float(ripple.get("y", 0.0))) + shake_offset
			canvas.draw_polyline(_ellipse_points(ripple_pos, radius, radius * 0.5), _alpha(RIPPLE_OUTER, ripple_alpha), 2.0, true)
			if radius * 2.0 > 20.0:
				canvas.draw_polyline(_ellipse_points(ripple_pos, radius * 0.6, radius * 0.3), _alpha(RIPPLE_INNER, ripple_alpha * 0.5), 1.0, true)

	var trail: Variant = afterimage_context.get("trail", [])
	if trail is Array:
		for trail_variant in trail:
			if not (trail_variant is Dictionary):
				continue
			var trail_entry: Dictionary = trail_variant
			var trail_alpha: float = _normalized_alpha(trail_entry.get("alpha", 0.0))
			if trail_alpha <= 0.01:
				continue
			var trail_pos := Vector2(float(trail_entry.get("x", 0.0)), float(trail_entry.get("y", 0.0))) + shake_offset
			_fill_ellipse(canvas, trail_pos, 30.0, 12.0, _alpha(TRAIL_SHADOW_OUTER, trail_alpha))
			_fill_ellipse(canvas, trail_pos, 18.0, 7.0, _alpha(TRAIL_SHADOW_INNER, trail_alpha * 0.7))
			var eye_pulse: float = 3.0 + sin(float(trail_entry.get("timer", 0.0)) * 0.3) * 2.0
			_fill_ellipse(canvas, trail_pos, eye_pulse, eye_pulse * 0.5, _alpha(TRAIL_EYE_PURPLE, trail_alpha * 0.5))

	var cracks: Variant = afterimage_context.get("ground_cracks", [])
	if cracks is Array:
		for crack_variant in cracks:
			if not (crack_variant is Dictionary):
				continue
			var crack: Dictionary = crack_variant
			var crack_progress: float = float(crack.get("timer", 0.0)) / maxf(1.0, float(crack.get("max_timer", 1.0)))
			var visible_len: float
			var crack_alpha: float
			if crack_progress < 0.2:
				visible_len = float(crack.get("length", 0.0)) * (crack_progress / 0.2)
				crack_alpha = 220.0 / 255.0
			else:
				visible_len = float(crack.get("length", 0.0))
				crack_alpha = (220.0 / 255.0) * (1.0 - (crack_progress - 0.2) / 0.8)
			if crack_alpha <= 0.01 or visible_len <= 0.5:
				continue
			var crack_start := Vector2(float(crack.get("x", 0.0)), float(crack.get("y", 0.0))) + shake_offset
			var crack_angle: float = float(crack.get("angle", 0.0))
			# Horizontally squashed crack line (Y * 0.4, legendary 7261).
			var crack_end := crack_start + Vector2(cos(crack_angle) * visible_len, sin(crack_angle) * visible_len * 0.4)
			var crack_width: float = maxf(1.0, float(crack.get("width", 1.0)))
			canvas.draw_line(crack_start, crack_end, _alpha(CRACK_GLOW, crack_alpha / 3.0), crack_width + 3.0, true)
			canvas.draw_line(crack_start, crack_end, _alpha(CRACK_CORE, crack_alpha), crack_width, true)

	var particles: Variant = afterimage_context.get("burst_particles", [])
	if particles is Array:
		for particle_variant in particles:
			if not (particle_variant is Dictionary):
				continue
			var particle: Dictionary = particle_variant
			var life_ratio: float = clampf(
				float(particle.get("life", 0.0)) / maxf(1.0, float(particle.get("max_life", 40.0))),
				0.0,
				1.0
			)
			var particle_alpha: float = life_ratio
			var particle_size: float = maxf(1.0, float(particle.get("size", 3.0)) * life_ratio)
			if particle_alpha <= 0.01:
				continue
			var particle_pos := Vector2(float(particle.get("x", 0.0)), float(particle.get("y", 0.0))) + shake_offset
			var particle_color: Color = particle.get("color", VOID_PURPLE) if particle.get("color", null) is Color else VOID_PURPLE
			canvas.draw_circle(particle_pos, particle_size + 3.0, _alpha(particle_color, particle_alpha * 0.25))
			canvas.draw_circle(particle_pos, particle_size, _alpha(particle_color, particle_alpha))


func _fill_ellipse(canvas: CanvasItem, center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	if radius_x <= 0.25 or radius_y <= 0.25 or color.a <= 0.003:
		return
	canvas.draw_colored_polygon(_ellipse_points(center, radius_x, radius_y, false), color)


func _ellipse_points(center: Vector2, radius_x: float, radius_y: float, closed: bool = true) -> PackedVector2Array:
	var points := PackedVector2Array()
	const SEGMENTS := 20
	for point_index in range(SEGMENTS):
		var point_angle: float = (float(point_index) / float(SEGMENTS)) * TAU
		points.append(center + Vector2(cos(point_angle) * radius_x, sin(point_angle) * radius_y))
	if closed:
		points.append(points[0])
	return points


func _afterimage_context(context: Dictionary) -> Dictionary:
	var value: Variant = _value(context, "afterimage", {})
	return value if value is Dictionary else {}


func _dive_visual(context: Dictionary) -> Dictionary:
	var value: Variant = _afterimage_context(context).get("dive_visual", {})
	return value if value is Dictionary else {}


func _dark_swamp_array(context: Dictionary, nested_key: String, primary_key: String, legacy_key: String) -> Array:
	var odin_context: Dictionary = _odin_context(context)
	var swamp_variant: Variant = odin_context.get("dark_swamp_context", odin_context.get("dark_swamp", {}))
	if swamp_variant is Dictionary:
		var swamp_context: Dictionary = swamp_variant
		var nested_variant: Variant = swamp_context.get(nested_key, [])
		if nested_variant is Array:
			return nested_variant
	var primary_variant: Variant = _value(context, primary_key, [])
	if primary_variant is Array and not (primary_variant as Array).is_empty():
		return primary_variant
	var legacy_variant: Variant = _value(context, legacy_key, [])
	if legacy_variant is Array:
		return legacy_variant
	return []


func _is_transformed(context: Dictionary) -> bool:
	var odin_context: Dictionary = _odin_context(context)
	if not odin_context.is_empty():
		return bool(odin_context.get("transformed", odin_context.get("penalty_active", false)))
	return bool(context.get("odins_eye_transformed", context.get("penalty_active", context.get("transformed", false))))


func _odin_context(context: Dictionary) -> Dictionary:
	var nested: Variant = context.get("odins_eye_context", {})
	if nested is Dictionary and not (nested as Dictionary).is_empty():
		return nested
	# Public draw APIs also accept the Odin sub-context directly. Restrict this
	# fallback to Odin-owned signal names so an unrelated actor dictionary does
	# not accidentally become an Odin context merely because it has `active`.
	if (
		context.has("penalty_active")
		or context.has("revival_animation_active")
		or context.has("death_animation_active")
		or context.has("dark_swamp_context")
	):
		return context
	return {}


func _value(context: Dictionary, key: String, default_value: Variant) -> Variant:
	var odin_context: Dictionary = _odin_context(context)
	if odin_context.has(key):
		return odin_context[key]
	var prefixed_key := "odins_eye_%s" % key
	if context.has(prefixed_key):
		return context[prefixed_key]
	return context.get(key, default_value)


func _time_seconds(context: Dictionary) -> float:
	for key in ["render_time_sec", "animation_time_sec", "player_anim_clock"]:
		var value: Variant = _value(context, key, null)
		if value is float or value is int:
			return float(value)
	return float(Time.get_ticks_msec()) * 0.001


func _vector_value(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


func _normalized_alpha(value: Variant) -> float:
	var alpha_value: float = float(value)
	if alpha_value > 1.0:
		alpha_value /= 255.0
	return clampf(alpha_value, 0.0, 1.0)


func _alpha(color: Color, multiplier: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(color.a * multiplier, 0.0, 1.0))


func _scaled_rect(rect: Rect2, scale_factor: float) -> Rect2:
	var safe_scale: float = maxf(0.01, scale_factor)
	var next_size: Vector2 = rect.size * safe_scale
	return Rect2(rect.get_center() - next_size * 0.5, next_size)


func _ease_out_cubic(value: float) -> float:
	var inverse: float = 1.0 - clampf(value, 0.0, 1.0)
	return 1.0 - inverse * inverse * inverse
