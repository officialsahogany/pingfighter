extends RefCounted

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const SmasherPlasmaFxHost := preload("res://scripts/characters/smasher_plasma_fx_host.gd")

const FIELD_MIN_RADIUS := 26.0
const FIELD_MAX_RADIUS := 104.0

var _prewarm_step_index := 0


func prewarm_step() -> bool:
	match _prewarm_step_index:
		0:
			ImpactFlareTextureCache.get_glow_texture()
		1:
			ImpactFlareTextureCache.get_burst_texture()
		2:
			ImpactFlareTextureCache.get_sparkle_texture()
		3:
			ImpactShockwaveTextureCache.get_full_ring_texture()
		4:
			ImpactShockwaveTextureCache.get_wall_ring_texture("left")
		5:
			ImpactShockwaveTextureCache.get_wall_ring_texture("right")
		6:
			SmasherPlasmaFxHost.prewarm_assets()
		7:
			var fx_probe: Node = SmasherPlasmaFxHost.new()
			if fx_probe != null and fx_probe.has_method("prewarm_node_pipeline"):
				fx_probe.prewarm_node_pipeline()
				fx_probe.free()
		_:
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func draw(
	canvas: CanvasItem,
	shake_offset: Vector2,
	visual_sec: float,
	charging: bool,
	charge_size: float,
	last_player_pos: Vector2,
	last_player_size: Vector2,
	charge_particles: Array[Dictionary],
	wave_active: bool,
	wave_pos: Vector2,
	wave_radius: float,
	wave_slow_amount: float,
	wave_trail: Array[Dictionary],
	wave_particles: Array[Dictionary],
	boss_slowed: bool,
	boss_slow_amount: float,
	contact_distortion: float,
	last_boss_pos: Vector2,
	last_boss_size: Vector2
) -> void:
	if canvas == null:
		return
	if charging:
		_draw_charge_field(
			canvas,
			shake_offset,
			visual_sec,
			charge_size,
			last_player_pos,
			last_player_size,
			charge_particles
		)
	if wave_active:
		_draw_wave(
			canvas,
			shake_offset,
			visual_sec,
			wave_pos,
			wave_radius,
			wave_slow_amount,
			wave_trail,
			wave_particles
		)
	if boss_slowed or contact_distortion > 0.01:
		_draw_boss_contact_overlay(
			canvas,
			shake_offset,
			visual_sec,
			boss_slow_amount,
			contact_distortion,
			last_boss_pos,
			last_boss_size
		)


func draw_contact_overlay(
	canvas: CanvasItem,
	shake_offset: Vector2,
	visual_sec: float,
	boss_slowed: bool,
	boss_slow_amount: float,
	contact_distortion: float,
	last_boss_pos: Vector2,
	last_boss_size: Vector2
) -> void:
	if canvas == null:
		return
	if boss_slowed or contact_distortion > 0.01:
		_draw_boss_contact_overlay(
			canvas,
			shake_offset,
			visual_sec,
			boss_slow_amount,
			contact_distortion,
			last_boss_pos,
			last_boss_size
		)


# 오브 → 보스 중심 단위 방향. FX 호스트가 구름 문양을 "상대방을 바라보게" 돌리는 데
# 쓴다(정지 그림처럼 보이던 라이브 QA 지적). 보스 위치는 state의 update_effects가 매
# 프레임 갱신하고 charging도 needs_effect_update에 포함되므로 차징 중에도 유효하다.
# 퇴화(오브가 보스 중심과 겹침) 시 위쪽으로 폴백.
static func aim_toward_boss(from_pos: Vector2, boss_pos: Vector2, boss_size: Vector2) -> Vector2:
	var boss_center := Vector2(
		boss_pos.x + boss_size.x * 0.5,
		boss_pos.y + boss_size.y * 0.5
	)
	var delta: Vector2 = boss_center - from_pos
	if delta.length_squared() < 1.0:
		return Vector2.UP
	return delta.normalized()


func get_charge_projection_for_tests(
	visual_sec: float,
	charge_size: float,
	last_player_pos: Vector2,
	last_player_size: Vector2,
	shake_offset: Vector2
) -> Vector4:
	var center: Vector2 = last_player_pos + Vector2(last_player_size.x * 0.5, last_player_size.y * 0.5 - 10.0) + shake_offset
	var radius: float = FIELD_MIN_RADIUS + (FIELD_MAX_RADIUS - FIELD_MIN_RADIUS) * charge_size
	var pulse: float = 0.5 + 0.5 * sin(visual_sec * 9.0)
	return Vector4(center.x, center.y, radius, pulse)


func _draw_charge_field(
	canvas: CanvasItem,
	shake_offset: Vector2,
	visual_sec: float,
	charge_size: float,
	last_player_pos: Vector2,
	last_player_size: Vector2,
	charge_particles: Array[Dictionary]
) -> void:
	var projection := get_charge_projection_for_tests(
		visual_sec,
		charge_size,
		last_player_pos,
		last_player_size,
		shake_offset
	)
	var center := Vector2(projection.x, projection.y)
	var radius: float = projection.z
	var pulse: float = projection.w
	ImpactFlareTextureCache.draw_glow(
		canvas,
		center,
		radius * 0.98,
		Color(0.35, 0.72, 1.0),
		(0.16 + charge_size * 0.18) * (0.82 + pulse * 0.18)
	)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, center, radius + 8.0, Color(0.42, 0.82, 1.0), 0.18 + charge_size * 0.22)
	if charge_size > 0.35:
		ImpactShockwaveTextureCache.draw_full_ring(canvas, center, radius * 0.62, Color(0.82, 0.95, 1.0), 0.12 + charge_size * 0.16)
	var spark_count: int = 1 + int(charge_size * 2.0)
	for i in range(spark_count):
		var spark_angle: float = visual_sec * 7.0 + float(i) * TAU / float(max(1, spark_count)) + sin(visual_sec * 18.0 + float(i)) * 0.5
		var start_pos: Vector2 = center + Vector2(cos(spark_angle), sin(spark_angle)) * radius * 0.85
		var spark_extension: float = 1.04 + (0.04 + 0.08 * (0.5 + 0.5 * sin(visual_sec * 11.0 + float(i) * 2.17))) * charge_size
		var end_pos: Vector2 = center + Vector2(cos(spark_angle), sin(spark_angle)) * (radius * spark_extension)
		canvas.draw_line(start_pos, end_pos, Color(0.52, 0.86, 1.0, 0.32), 1.0)
	var core_radius: float = max(3.0, radius * 0.08 * (0.85 + 0.15 * sin(visual_sec * 15.0)))
	ImpactFlareTextureCache.draw_sparkle(canvas, center, core_radius + 6.0, Color(0.82, 0.95, 1.0), 0.42 + charge_size * 0.18)
	for particle in charge_particles:
		var angle: float = float(particle.get("angle", 0.0))
		var dist: float = float(particle.get("dist", 0.0)) * charge_size * 2.0
		var life: float = clamp(float(particle.get("life", 0.0)) / 30.0, 0.0, 1.0)
		var alpha: float = float(particle.get("alpha", 1.0)) * life * 0.34
		ImpactFlareTextureCache.draw_sparkle(canvas, center + Vector2(cos(angle), sin(angle)) * dist, 3.2, Color(0.42, 0.82, 1.0), alpha * 0.55)


func _draw_wave(
	canvas: CanvasItem,
	shake_offset: Vector2,
	visual_sec: float,
	wave_pos: Vector2,
	wave_radius: float,
	wave_slow_amount: float,
	wave_trail: Array[Dictionary],
	wave_particles: Array[Dictionary]
) -> void:
	for trail in wave_trail:
		var pos: Vector2 = _as_vector2(trail.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var radius: float = float(trail.get("radius", wave_radius))
		var alpha: float = float(trail.get("alpha", 0.0)) * 0.4
		ImpactShockwaveTextureCache.draw_full_ring(canvas, pos, radius, Color(0.36, 0.74, 1.0), alpha * 0.42)

	var center: Vector2 = wave_pos + shake_offset
	var pulse: float = 0.92 + 0.08 * sin(visual_sec * 25.0)
	var fast_pulse: float = 0.95 + 0.05 * sin(visual_sec * 80.0)
	var main_radius: float = max(3.0, wave_radius * pulse)
	ImpactFlareTextureCache.draw_glow(canvas, center, main_radius * 0.88, Color(0.18, 0.50, 0.95), 0.13 * fast_pulse)
	for layer in range(2):
		var ring_radius: float = main_radius - float(layer) * 10.0
		if ring_radius > 5.0:
			ImpactShockwaveTextureCache.draw_full_ring(canvas, center, ring_radius, Color(0.34 + float(layer) * 0.07, 0.78, 1.0), (0.22 - float(layer) * 0.055) * fast_pulse)
	var outer_arcs: int = 3 + int(wave_slow_amount * 2.0)
	for i in range(outer_arcs):
		var angle: float = visual_sec * 10.0 + float(i) * TAU / float(max(1, outer_arcs)) + sin(visual_sec * 40.0 + float(i)) * 0.4
		var points := PackedVector2Array()
		for j in range(3):
			var t: float = float(j) / 2.0
			var dist_noise: float = 0.5 + 0.5 * sin(visual_sec * 13.0 + float(i) * 1.71 + float(j) * 0.9)
			var dist: float = main_radius * (0.90 + t * (0.25 + 0.22 * dist_noise))
			var jitter: float = pow(t, 1.5) * 0.16 * sin(visual_sec * 17.0 + float(i) * 2.3 + float(j))
			points.append(center + Vector2(cos(angle + jitter), sin(angle + jitter)) * dist)
		canvas.draw_polyline(points, Color(0.58, 0.88, 1.0, 0.48), 1.4, true)
	var core_radius: float = max(3.0, main_radius * 0.15 * fast_pulse)
	ImpactFlareTextureCache.draw_sparkle(canvas, center, core_radius + 6.0, Color(0.80, 0.94, 1.0), 0.46 * fast_pulse)
	for particle in wave_particles:
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var alpha: float = clamp(float(particle.get("alpha", 0.0)), 0.0, 1.0)
		ImpactFlareTextureCache.draw_sparkle(canvas, pos, 3.0, Color(0.55, 0.84, 1.0), alpha * 0.48)


func _draw_boss_contact_overlay(
	canvas: CanvasItem,
	shake_offset: Vector2,
	visual_sec: float,
	boss_slow_amount: float,
	contact_distortion: float,
	last_boss_pos: Vector2,
	last_boss_size: Vector2
) -> void:
	var strength: float = max(contact_distortion, boss_slow_amount * 0.55)
	if strength <= 0.01:
		return
	var rect := Rect2(last_boss_pos + shake_offset, last_boss_size)
	var center: Vector2 = rect.get_center()
	var radius: float = max(rect.size.x, rect.size.y) * (0.54 + 0.025 * sin(visual_sec * 6.0))
	ImpactFlareTextureCache.draw_glow(canvas, center, radius, Color(0.54, 0.82, 0.88), 0.045 * strength)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, center, radius, Color(0.76, 0.94, 0.93), 0.10 * strength)
	# 접촉 둔화는 전기 방전선이 아니라 보스 주위를 감는 세 겹의 혼백 붓선으로 읽힌다.
	# 저비용 결정적 accent라 즉시 draw를 유지하되, 본체 정체성은 모듈형 호스트가 소유한다.
	for i in range(3):
		var phase := visual_sec * (0.72 + float(i) * 0.11) + float(i) * TAU / 3.0
		var arc_radius := radius * (0.48 + float(i) * 0.14)
		var arc_span := 1.05 + 0.18 * sin(visual_sec * 2.4 + float(i))
		canvas.draw_arc(
			center,
			arc_radius,
			phase,
			phase + arc_span,
			12,
			Color(0.76, 0.95, 0.96, (0.12 + float(i) * 0.03) * strength),
			1.3 + float(i) * 0.18,
			true
		)
		var wisp_tip := center + Vector2(cos(phase + arc_span), sin(phase + arc_span)) * arc_radius
		ImpactFlareTextureCache.draw_sparkle(canvas, wisp_tip, 2.4 + float(i) * 0.5, Color(0.86, 0.98, 1.0), 0.18 * strength)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
