extends RefCounted

const _RAGNAROK_TRAIL_LIFE_MSEC := 500.0
const _FIRE_WEATHER_TRAIL_LIFE_MSEC := 360.0
const _FIRE_WEATHER_TRAIL_RENDER_LIMIT := 12
const _FIRE_WEATHER_PRIMARY_ARC_POINTS := 36
const _FIRE_WEATHER_SECONDARY_ARC_POINTS := 32
const _RAGNAROK_TRAIL_RENDER_LIMIT := 12
const _RAGNAROK_BOLT_COUNT := 5
const _RAGNAROK_BRANCH_COUNT := 2
const _RAGNAROK_ORBIT_PARTICLE_COUNT := 10
const _POSEIDON_PRIMARY_ARC_POINTS := 48
const _POSEIDON_SECONDARY_ARC_POINTS := 32
const _RAGNAROK_BALL_AURA_RADII := [90.0, 70.0, 50.0, 35.0, 25.0]
const _RAGNAROK_BALL_AURA_COLORS := [
	Color(1.0, 1.0, 1.0, 30.0 / 255.0),
	Color(150.0 / 255.0, 200.0 / 255.0, 1.0, 40.0 / 255.0),
	Color(100.0 / 255.0, 150.0 / 255.0, 1.0, 50.0 / 255.0),
	Color(50.0 / 255.0, 100.0 / 255.0, 1.0, 60.0 / 255.0),
	Color(1.0, 1.0, 1.0, 80.0 / 255.0),
]

var _ragnarok_trail: Array = []
var _ragnarok_active_last_frame := false
var _fire_weather_trail: Array = []
var _fire_weather_active_last_frame := false


func draw(canvas: CanvasItem, pos: Vector2, context: Dictionary, ball_render_radius: float) -> void:
	if bool(context.get("poisoned_ball_overlay_active", false)):
		_draw_poisoned_ball_overlay(canvas, pos, ball_render_radius)
	if bool(context.get("viper_knockback_overlay_active", false)):
		_draw_viper_knockback_ball_overlay(canvas, pos, ball_render_radius)
	var fire_weather_active: bool = bool(context.get("fire_weather_ball_active", false))
	if fire_weather_active:
		_draw_fire_weather_ball_overlay(canvas, pos, ball_render_radius, context)
	elif _fire_weather_active_last_frame:
		_fire_weather_trail.clear()
	_fire_weather_active_last_frame = fire_weather_active
	var ragnarok_active: bool = bool(context.get("ragnarok_hammer_ball_active", false))
	if ragnarok_active:
		_draw_ragnarok_hammer_ball_overlay(canvas, pos, ball_render_radius)
	elif _ragnarok_active_last_frame:
		_ragnarok_trail.clear()
	_ragnarok_active_last_frame = ragnarok_active
	if bool(context.get("poseidon_trident_ball_active", false)):
		_draw_poseidon_trident_ball_overlay(canvas, pos, ball_render_radius)


func _draw_poisoned_ball_overlay(canvas: CanvasItem, pos: Vector2, ball_render_radius: float) -> void:
	var radius: float = max(4.0, ball_render_radius)
	var now: float = float(Time.get_ticks_msec())
	var pulse: float = 0.5 + 0.5 * sin(now * 0.0105)
	canvas.draw_circle(pos, radius + 14.0 + 2.0 * pulse, Color(45.0 / 255.0, 125.0 / 255.0, 55.0 / 255.0, (26.0 + 14.0 * pulse) / 255.0))
	canvas.draw_circle(pos, radius + 8.0, Color(75.0 / 255.0, 185.0 / 255.0, 85.0 / 255.0, (40.0 + 18.0 * pulse) / 255.0))
	canvas.draw_circle(pos, radius + 3.0, Color(105.0 / 255.0, 220.0 / 255.0, 110.0 / 255.0, (42.0 + 14.0 * pulse) / 255.0))
	canvas.draw_circle(pos, max(2.0, radius * 0.65), Color(185.0 / 255.0, 1.0, 175.0 / 255.0, (72.0 + 18.0 * pulse) / 255.0))

	var orbit_distance: float = radius + 4.0 + pulse * 3.0
	var mote_size: float = max(2.0, floor(radius / 4.0))
	var phases: Array[float] = [0.0, PI]
	for phase in phases:
		var angle: float = now * 0.006 + phase
		var mote_pos: Vector2 = pos + Vector2(cos(angle) * orbit_distance, sin(angle) * orbit_distance * 0.55)
		var mote_r: float = mote_size + (1.0 if phase == 0.0 else 0.0)
		canvas.draw_circle(mote_pos, mote_r + 1.0, Color(165.0 / 255.0, 1.0, 155.0 / 255.0, (78.0 + 24.0 * pulse) / 255.0))


func _draw_viper_knockback_ball_overlay(canvas: CanvasItem, pos: Vector2, ball_render_radius: float) -> void:
	var radius: float = max(4.0, ball_render_radius)
	var now: float = float(Time.get_ticks_msec())
	var pulse: float = 0.5 + 0.5 * sin(now * 0.0115)
	canvas.draw_circle(pos, radius + 16.0 + 3.0 * pulse, Color(115.0 / 255.0, 24.0 / 255.0, 12.0 / 255.0, (34.0 + 18.0 * pulse) / 255.0))
	canvas.draw_circle(pos, radius + 10.0 + 2.0 * pulse, Color(185.0 / 255.0, 42.0 / 255.0, 18.0 / 255.0, (52.0 + 26.0 * pulse) / 255.0))
	canvas.draw_circle(pos, radius + 4.0, Color(240.0 / 255.0, 76.0 / 255.0, 22.0 / 255.0, (76.0 + 28.0 * pulse) / 255.0))
	canvas.draw_circle(pos, max(3.0, radius * 0.72), Color(1.0, 208.0 / 255.0, 128.0 / 255.0, (82.0 + 20.0 * pulse) / 255.0))

	var ember_distance: float = radius + 5.0 + pulse * 4.0
	var ember_size: float = max(2.0, floor(radius / 4.0))
	var phases: Array[float] = [0.0, PI * 0.7]
	for phase in phases:
		var angle: float = now * 0.0075 + phase
		var ember_pos: Vector2 = pos + Vector2(cos(angle) * ember_distance, sin(angle) * ember_distance * 0.58)
		canvas.draw_circle(ember_pos, ember_size + 1.0, Color(1.0, 170.0 / 255.0, 88.0 / 255.0, (92.0 + 32.0 * pulse) / 255.0))


func _draw_fire_weather_ball_overlay(canvas: CanvasItem, pos: Vector2, ball_render_radius: float, context: Dictionary) -> void:
	var radius: float = max(4.0, ball_render_radius)
	var now: float = float(Time.get_ticks_msec())
	var ball_vel: Vector2 = _get_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	_fire_weather_trail.append({"pos": pos, "time": now, "speed": ball_vel.length()})
	_trim_timed_trail_in_place(_fire_weather_trail, now, _FIRE_WEATHER_TRAIL_LIFE_MSEC, _FIRE_WEATHER_TRAIL_RENDER_LIMIT)

	for index in range(_fire_weather_trail.size()):
		var entry: Dictionary = _fire_weather_trail[index]
		var age: float = now - float(entry.get("time", 0.0))
		var t: float = clamp(1.0 - age / _FIRE_WEATHER_TRAIL_LIFE_MSEC, 0.0, 1.0)
		if t <= 0.0:
			continue
		var trail_pos: Vector2 = _get_vector2(entry.get("pos", pos), pos)
		var speed_scale: float = clamp(float(entry.get("speed", 0.0)) / 28.0, 0.0, 1.0)
		var trail_radius: float = radius * (0.55 + 0.85 * t) + speed_scale * 4.0
		canvas.draw_circle(trail_pos, trail_radius + 7.0 * t, Color(0.74, 0.05, 0.01, 0.16 * t))
		canvas.draw_circle(trail_pos + Vector2(sin(float(index) * 1.9) * 2.0, -2.0 * t), trail_radius, Color(1.0, 0.30, 0.02, 0.26 * t))
		canvas.draw_circle(trail_pos + Vector2(cos(float(index) * 2.3) * 1.4, -4.0 * t), max(1.5, trail_radius * 0.42), Color(1.0, 0.83, 0.24, 0.24 * t))

	var pulse: float = 0.5 + 0.5 * sin(now * 0.013)
	canvas.draw_circle(pos, radius + 21.0 + 3.5 * pulse, Color(0.60, 0.02, 0.0, (26.0 + 16.0 * pulse) / 255.0))
	canvas.draw_circle(pos, radius + 13.0 + 2.0 * pulse, Color(1.0, 0.16, 0.02, (46.0 + 22.0 * pulse) / 255.0))
	canvas.draw_circle(pos, radius + 5.0, Color(1.0, 0.48, 0.06, (70.0 + 24.0 * pulse) / 255.0))
	canvas.draw_circle(pos, max(3.0, radius * 0.72), Color(1.0, 0.88, 0.34, (72.0 + 22.0 * pulse) / 255.0))
	canvas.draw_arc(pos, radius + 9.0 + pulse * 2.0, now * 0.006, now * 0.006 + PI * 1.42, _FIRE_WEATHER_PRIMARY_ARC_POINTS, Color(1.0, 0.68, 0.16, 0.74), 2.2)
	canvas.draw_arc(pos, radius + 15.0, -now * 0.004, -now * 0.004 + PI * 1.15, _FIRE_WEATHER_SECONDARY_ARC_POINTS, Color(1.0, 0.18, 0.02, 0.48), 1.7)

	for flame_index in range(4):
		var phase: float = float(flame_index) * TAU / 4.0
		var angle: float = now * 0.008 + phase
		var distance: float = radius + 4.0 + sin(now * 0.010 + phase) * 2.0
		var flame_pos: Vector2 = pos + Vector2(cos(angle) * distance, sin(angle) * distance * 0.58 - 2.0)
		var flame_size: float = max(2.0, radius * (0.18 + 0.06 * sin(now * 0.014 + phase)))
		canvas.draw_circle(flame_pos, flame_size + 2.0, Color(1.0, 0.20, 0.02, 0.72))
		canvas.draw_circle(flame_pos + Vector2(0.0, -flame_size * 0.50), max(1.2, flame_size * 0.58), Color(1.0, 0.88, 0.30, 0.76))


func _draw_ragnarok_hammer_ball_overlay(canvas: CanvasItem, pos: Vector2, _ball_render_radius: float) -> void:
	var now_msec: float = float(Time.get_ticks_msec())

	# 1. 번개 오라 - 5층 동심원, 바깥 3층은 흔들림
	for layer in range(_RAGNAROK_BALL_AURA_RADII.size()):
		var aura_radius: float = float(_RAGNAROK_BALL_AURA_RADII[layer])
		var color: Color = _RAGNAROK_BALL_AURA_COLORS[layer]
		var shake := Vector2.ZERO
		if layer < 3:
			var shake_phase: float = now_msec * 0.018 + float(layer) * 2.11
			shake = Vector2(sin(shake_phase) * 2.6, cos(shake_phase * 1.37) * 2.6)
		canvas.draw_circle(pos + shake, aura_radius, color)

	# 2. 번개 볼트 - 공에서 8방향으로 방사, 각 볼트마다 가지 2-4개
	for i in range(_RAGNAROK_BOLT_COUNT):
		var angle_deg: float = fmod(now_msec * 0.2 + float(i) * (360.0 / float(_RAGNAROK_BOLT_COUNT)), 360.0)
		var angle_rad: float = deg_to_rad(angle_deg)
		var bolt_length: float = 72.0 + sin(now_msec * 0.011 + float(i) * 1.37) * 16.0
		var bolt_dir := Vector2(cos(angle_rad), sin(angle_rad))
		var bolt_end: Vector2 = pos + bolt_dir * bolt_length

		canvas.draw_line(pos, bolt_end, Color(1.0, 1.0, 1.0, 0.88), 2.6)

		for j in range(_RAGNAROK_BRANCH_COUNT):
			var branch_wave: float = 0.5 + 0.5 * sin(now_msec * 0.008 + float(i * 3 + j) * 1.21)
			var branch_start_t: float = 0.32 + 0.34 * branch_wave
			var branch_origin: Vector2 = pos.lerp(bolt_end, branch_start_t)
			var branch_side: float = -1.0 if j % 2 == 0 else 1.0
			var branch_angle: float = angle_rad + branch_side * deg_to_rad(25.0 + 16.0 * sin(now_msec * 0.010 + float(i + j) * 1.7))
			var branch_length: float = bolt_length * (0.26 + 0.12 * (0.5 + 0.5 * cos(now_msec * 0.012 + float(i * 2 + j))))
			var branch_end: Vector2 = branch_origin + Vector2(cos(branch_angle), sin(branch_angle)) * branch_length
			canvas.draw_line(branch_origin, branch_end, Color(150.0 / 255.0, 200.0 / 255.0, 1.0, 0.78), 1.0)

	# 3. 응축 파티클 - 공 주위를 도는 20개 입자
	for i in range(_RAGNAROK_ORBIT_PARTICLE_COUNT):
		var particle_angle_deg: float = fmod(now_msec * 0.5 + float(i) * (360.0 / float(_RAGNAROK_ORBIT_PARTICLE_COUNT)), 360.0)
		var distance: float = 30.0 + sin(deg_to_rad(now_msec * 0.3 + float(i) * 30.0)) * 15.0
		var particle_pos: Vector2 = pos + Vector2(cos(deg_to_rad(particle_angle_deg)), sin(deg_to_rad(particle_angle_deg))) * distance
		var particle_pulse: float = 0.5 + 0.5 * sin(now_msec * 0.017 + float(i) * 1.4)
		var size: float = 2.0 + float(i % 3) + particle_pulse
		var particle_color := Color(1.0, 1.0, 1.0, 0.62 + 0.24 * particle_pulse)
		if i % 2 == 1:
			particle_color = Color(100.0 / 255.0, 150.0 / 255.0, 1.0, 0.56 + 0.24 * particle_pulse)
		canvas.draw_circle(particle_pos, size, particle_color)

	# 4. 번개 트레일 - 공이 지나간 자취에 페이드
	_ragnarok_trail.append({"pos": pos, "time": now_msec})
	_trim_timed_trail_in_place(_ragnarok_trail, now_msec, _RAGNAROK_TRAIL_LIFE_MSEC, _RAGNAROK_TRAIL_RENDER_LIMIT)
	for index in range(_ragnarok_trail.size()):
		var entry: Dictionary = _ragnarok_trail[index]
		var age: float = now_msec - float(entry.get("time", 0.0))
		var alpha: float = max(0.0, 255.0 - age * 0.5)
		if alpha <= 0.0:
			continue
		var trail_pos: Vector2 = entry.get("pos", pos)
		canvas.draw_circle(trail_pos, 18.0, Color(100.0 / 255.0, 150.0 / 255.0, 1.0, alpha * 0.42 / 255.0))
		if index % 3 == 0:
			canvas.draw_circle(trail_pos, 8.0, Color(1.0, 1.0, 1.0, alpha * 0.22 / 255.0))

	# 5. 중앙 코어 - 공을 감싸는 펄스 번개 구체
	var pulse: float = (sin(now_msec * 0.01) + 1.0) * 0.5
	var core_size: float = 25.0 + pulse * 5.0
	canvas.draw_circle(pos, core_size, Color(1.0, 1.0, 1.0, 100.0 / 255.0))
	canvas.draw_circle(pos, max(0.0, core_size - 5.0), Color(150.0 / 255.0, 200.0 / 255.0, 1.0, 150.0 / 255.0))
	canvas.draw_circle(pos, max(0.0, core_size - 10.0), Color(1.0, 1.0, 1.0, 200.0 / 255.0))


func _draw_poseidon_trident_ball_overlay(canvas: CanvasItem, pos: Vector2, ball_render_radius: float) -> void:
	var radius: float = max(4.0, ball_render_radius)
	var now: float = float(Time.get_ticks_msec())
	var pulse: float = 0.5 + 0.5 * sin(now * 0.011)
	canvas.draw_circle(pos, radius + 15.0 + 2.0 * pulse, Color(35.0 / 255.0, 135.0 / 255.0, 1.0, (24.0 + 16.0 * pulse) / 255.0))
	canvas.draw_arc(pos, radius + 8.0 + pulse * 2.0, now * 0.004, now * 0.004 + PI * 1.55, _POSEIDON_PRIMARY_ARC_POINTS, Color(115.0 / 255.0, 215.0 / 255.0, 1.0, 0.66), 2.0)
	canvas.draw_arc(pos, radius + 13.0, -now * 0.003, -now * 0.003 + PI * 1.15, _POSEIDON_SECONDARY_ARC_POINTS, Color(205.0 / 255.0, 245.0 / 255.0, 1.0, 0.42), 1.5)
	for i in range(3):
		var angle: float = now * 0.007 + float(i) * TAU / 3.0
		var droplet_pos: Vector2 = pos + Vector2(cos(angle) * (radius + 8.0), sin(angle) * (radius + 5.0))
		canvas.draw_circle(droplet_pos, 2.2 + pulse, Color(165.0 / 255.0, 230.0 / 255.0, 1.0, 0.74))


func _trim_timed_trail_in_place(trail: Array, now_msec: float, life_msec: float, max_count: int) -> void:
	var write_idx := 0
	for index in range(trail.size()):
		var entry_value: Variant = trail[index]
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		if now_msec - float(entry.get("time", 0.0)) >= life_msec:
			continue
		trail[write_idx] = entry
		write_idx += 1

	var keep_count: int = min(write_idx, max(0, max_count))
	var keep_start: int = max(0, write_idx - keep_count)
	if keep_start > 0:
		for index in range(keep_count):
			trail[index] = trail[keep_start + index]
	trail.resize(keep_count)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	return fallback
