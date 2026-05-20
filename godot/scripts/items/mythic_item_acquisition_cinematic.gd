extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const BUILDUP_DURATION := 2.0
const BURST_DURATION := 0.30
const WHITE_FADE_DURATION := 1.0
const REVEAL_CLICK_DELAY := 0.50
const ABSORB_SPIN_DURATION := 1.0
const ABSORB_PULL_DURATION := 1.50
const PADDLE_GLOW_DURATION := 0.60
const LEGEND_AFTER_STOP_DELAY := 1.50
const ICON_SIZE := 92.0
const CHEST_SIZE := 134.0
const PHASE_BUILDUP := "build"
const PHASE_BURST := "burst"
const PHASE_WHITE_FADE := "white_fade"
const PHASE_REVEAL := "reveal"
const PHASE_ABSORB_SPIN := "absorb_spin"
const PHASE_ABSORB_PULL := "absorb_pull"
const PHASE_PADDLE_GLOW := "paddle_glow"
const BEAM_SPAWN_TIMES := [0.8, 1.4, 1.7, 1.9]

var active := false
var phase := PHASE_BUILDUP
var phase_timer := 0.0
var elapsed := 0.0
var item_data: Dictionary = {}
var display_name := ""
var item_texture: Texture2D = null
var icon_frame_count := 1
var icon_frame_msec := 33
var icon_source_inset := 0.0
var item_origin := Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
var player_center := Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 25.0)
var next_beam_index := 0
var beams: Array[Dictionary] = []
var cracks: Array[Dictionary] = []
var ambient_particles: Array[Dictionary] = []
var burst_particles: Array[Dictionary] = []
var symbol_positions: Array[Dictionary] = []
var baroque_particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var burst_started_elapsed := -1.0
var legend_after_played := false
var legend_after_stop_timer := 0.0
var absorb_started := false
var item_alpha := 1.0
var item_float_offset := 0.0
var rotation := 0.0
var paddle_glow_intensity := 0.0


func trigger(acquired_item_data: Dictionary, pickup_position: Vector2, target_player_center: Vector2, registry: Object = null) -> void:
	active = true
	phase = PHASE_BUILDUP
	phase_timer = 0.0
	elapsed = 0.0
	item_data = acquired_item_data.duplicate(true)
	display_name = _resolve_display_name(item_data)
	item_origin = pickup_position
	player_center = target_player_center
	next_beam_index = 0
	beams.clear()
	cracks.clear()
	ambient_particles.clear()
	burst_particles.clear()
	symbol_positions.clear()
	baroque_particles.clear()
	burst_started_elapsed = -1.0
	legend_after_played = false
	legend_after_stop_timer = 0.0
	absorb_started = false
	item_alpha = 1.0
	item_float_offset = 0.0
	rotation = 0.0
	paddle_glow_intensity = 0.0
	rng.randomize()
	_load_item_texture()
	_create_ambient_particles()
	_play_first_audio(registry, ["play_legendary_open", "play_pandora", "play_active_item"])


func reset(registry: Object = null) -> void:
	if legend_after_played:
		_play_first_audio(registry, ["stop_legendary_after"])
	active = false
	phase = PHASE_BUILDUP
	phase_timer = 0.0
	elapsed = 0.0
	item_data.clear()
	display_name = ""
	item_texture = null
	beams.clear()
	cracks.clear()
	ambient_particles.clear()
	burst_particles.clear()
	symbol_positions.clear()
	baroque_particles.clear()
	legend_after_played = false
	legend_after_stop_timer = 0.0
	absorb_started = false
	item_alpha = 1.0
	paddle_glow_intensity = 0.0


func is_active() -> bool:
	return active


func is_waiting_for_click() -> bool:
	return active and phase == PHASE_REVEAL and phase_timer >= REVEAL_CLICK_DELAY and not absorb_started


func handle_input(event: InputEvent, registry: Object = null) -> bool:
	if not active:
		return false
	var requested := false
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		requested = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		requested = touch_event.pressed
	elif event is InputEventKey:
		var key_event: InputEventKey = event
		requested = key_event.pressed and not key_event.echo and (
			key_event.keycode == KEY_SPACE
			or key_event.physical_keycode == KEY_SPACE
			or key_event.keycode == KEY_ENTER
			or key_event.physical_keycode == KEY_ENTER
		)
	if requested and is_waiting_for_click():
		_start_absorb(registry)
	return true


func update(delta: float, registry: Object = null) -> void:
	if not active:
		return
	var dt: float = max(0.0, delta)
	elapsed += dt
	phase_timer += dt
	_update_legend_after_stop(dt, registry)
	_update_ambient_particles(dt)
	_update_beams(dt)
	_update_burst_particles(dt)
	_update_baroque_particles(dt)

	match phase:
		PHASE_BUILDUP:
			_update_build_phase()
			if phase_timer >= BUILDUP_DURATION:
				_start_burst()
		PHASE_BURST:
			if burst_started_elapsed >= 0.0 and elapsed - burst_started_elapsed >= 0.50 and not legend_after_played:
				legend_after_played = true
				_play_first_audio(registry, ["play_legendary_after", "play_pandora", "play_active_item"])
			if phase_timer >= BURST_DURATION:
				_set_phase(PHASE_WHITE_FADE)
		PHASE_WHITE_FADE:
			if phase_timer >= WHITE_FADE_DURATION:
				_set_phase(PHASE_REVEAL)
		PHASE_REVEAL:
			_update_reveal_motion(dt)
		PHASE_ABSORB_SPIN:
			_update_absorb_spin(dt)
			if phase_timer >= ABSORB_SPIN_DURATION:
				_set_phase(PHASE_ABSORB_PULL)
		PHASE_ABSORB_PULL:
			_update_absorb_pull()
			if phase_timer >= ABSORB_PULL_DURATION:
				_set_phase(PHASE_PADDLE_GLOW)
		PHASE_PADDLE_GLOW:
			_update_paddle_glow()
			if phase_timer >= PADDLE_GLOW_DURATION:
				reset(registry)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or not active:
		return
	canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(FIELD_WIDTH, FIELD_HEIGHT)), Color(0.0, 0.0, 0.0, 0.72))
	var center := Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
	_draw_ambient(canvas)
	if phase == PHASE_BUILDUP or phase == PHASE_BURST:
		_draw_chest(canvas, center)
		_draw_cracks(canvas, center)
	for beam in beams:
		_draw_beam(canvas, center, beam)
	_draw_burst_particles(canvas)
	if phase == PHASE_WHITE_FADE:
		var fade_ratio: float = 1.0 - clamp(phase_timer / WHITE_FADE_DURATION, 0.0, 1.0)
		canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(FIELD_WIDTH, FIELD_HEIGHT)), Color(1.0, 1.0, 1.0, 0.82 * fade_ratio))
	if phase == PHASE_REVEAL or phase == PHASE_ABSORB_SPIN or phase == PHASE_ABSORB_PULL:
		_draw_reveal(canvas, center, shake_offset)
	if phase == PHASE_PADDLE_GLOW or phase == PHASE_ABSORB_PULL:
		_draw_paddle_glow(canvas, shake_offset)
		_draw_baroque_particles(canvas)


func get_snapshot() -> Dictionary:
	return {
		"active": active,
		"phase": phase,
		"phase_timer": phase_timer,
		"elapsed": elapsed,
		"item_name": str(item_data.get("name", "")),
		"display_name": display_name,
		"beam_count": beams.size(),
		"crack_count": cracks.size(),
		"waiting_for_click": is_waiting_for_click(),
		"absorb_started": absorb_started,
		"item_alpha": item_alpha,
	}


func _set_phase(next_phase: String) -> void:
	phase = next_phase
	phase_timer = 0.0
	if next_phase == PHASE_REVEAL:
		item_alpha = 1.0
		item_float_offset = 0.0
	if next_phase == PHASE_ABSORB_PULL:
		item_alpha = 1.0
	if next_phase == PHASE_PADDLE_GLOW:
		item_alpha = 0.0
		paddle_glow_intensity = 1.0
		_spawn_baroque_particles()


func _spawn_baroque_particles() -> void:
	baroque_particles.clear()
	# 4 baroque types: fleur (꽃잎), acanthus (잎사귀), rosette (꽃송이), scroll (소용돌이)
	# 30 particles total, evenly distributed across 4 types
	var palette := [
		Color(1.0, 0.84, 0.0),    # gold
		Color(0.85, 0.65, 0.13),  # goldenrod
		Color(1.0, 0.97, 0.86),   # cream
		Color(0.75, 0.75, 0.75),  # silver
	]
	for i in range(30):
		var kind: int = i % 4   # 0:fleur 1:acanthus 2:rosette 3:scroll
		var angle: float = rng.randf_range(-PI * 0.85, -PI * 0.15)   # upward arc
		var speed: float = rng.randf_range(180.0, 360.0)
		var velocity: Vector2 = Vector2(cos(angle), sin(angle)) * speed
		var color: Color = palette[i % palette.size()]
		baroque_particles.append({
			"position": player_center,
			"velocity": velocity,
			"gravity": rng.randf_range(380.0, 520.0),
			"life": rng.randf_range(0.85, 1.30),
			"max_life": 1.30,
			"size": rng.randf_range(6.0, 11.0),
			"angle": rng.randf_range(0.0, TAU),
			"spin": rng.randf_range(-4.5, 4.5),
			"pulse": 0.0,
			"pulse_speed": rng.randf_range(5.0, 9.0),
			"kind": kind,
			"color": color,
		})


func _update_build_phase() -> void:
	while next_beam_index < BEAM_SPAWN_TIMES.size() and elapsed >= float(BEAM_SPAWN_TIMES[next_beam_index]):
		var crack_count := next_beam_index + 1
		for _i in range(crack_count):
			var angle: float = rng.randf_range(0.0, TAU)
			cracks.append({
				"angle": angle,
				"length": rng.randf_range(32.0, 68.0),
				"width": rng.randf_range(1.0, 3.0),
				"born": elapsed,
				"branch_dir": rng.randf_range(0.35, 0.65) * (1.0 if rng.randf() < 0.5 else -1.0),
			})
			for _j in range(2):
				_create_beam(angle + rng.randf_range(-0.16, 0.16), true)
		next_beam_index += 1


func _start_burst() -> void:
	_set_phase(PHASE_BURST)
	burst_started_elapsed = elapsed
	# Massive ray fan — original spawns 30+ beams during the burst frame
	for _i in range(28):
		_create_beam(rng.randf_range(0.0, TAU), false)
	for _i in range(54):
		var angle: float = rng.randf_range(0.0, TAU)
		var speed: float = rng.randf_range(140.0, 360.0)
		var color := Color(1.0, rng.randf_range(0.72, 0.96), rng.randf_range(0.25, 0.75), 1.0)
		burst_particles.append({
			"position": Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5),
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"radius": rng.randf_range(2.5, 7.0),
			"life": rng.randf_range(0.45, 0.82),
			"max_life": rng.randf_range(0.62, 0.94),
			"color": color,
		})


func _start_absorb(registry: Object) -> void:
	absorb_started = true
	_set_phase(PHASE_ABSORB_SPIN)
	legend_after_stop_timer = LEGEND_AFTER_STOP_DELAY
	_play_first_audio(registry, ["play_legendary_ending", "play_item_get"])
	symbol_positions.clear()
	for i in range(6):
		var angle: float = TAU * float(i) / 6.0
		symbol_positions.append({
			"angle": angle,
			"radius": 132.0,
			"position": Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5) + Vector2(cos(angle), sin(angle)) * 132.0,
			"scale": 1.0,
			"idx": i,
		})


func _update_reveal_motion(dt: float) -> void:
	rotation += dt * 0.30
	item_float_offset = sin(elapsed * 3.0) * 18.0


func _update_absorb_spin(dt: float) -> void:
	rotation += dt * (1.4 + phase_timer * 3.0)
	item_float_offset = sin(elapsed * 4.0) * 12.0
	for i in range(symbol_positions.size()):
		var symbol: Dictionary = symbol_positions[i]
		var angle: float = float(symbol.get("angle", 0.0)) + rotation
		var radius: float = float(symbol.get("radius", 132.0)) * (1.0 - 0.08 * clamp(phase_timer / ABSORB_SPIN_DURATION, 0.0, 1.0))
		symbol["position"] = Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5) + Vector2(cos(angle), sin(angle)) * radius
		symbol_positions[i] = symbol


func _update_absorb_pull() -> void:
	var progress: float = clamp(phase_timer / ABSORB_PULL_DURATION, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 2.2)
	rotation += 0.08 + eased * 0.12
	item_alpha = 1.0 - eased
	for i in range(symbol_positions.size()):
		var symbol: Dictionary = symbol_positions[i]
		var base_angle: float = float(symbol.get("angle", 0.0)) + rotation + progress * TAU * 2.2
		var radius: float = 132.0 * (1.0 - progress * 0.92)
		var spiral_pos := Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5) + Vector2(cos(base_angle), sin(base_angle)) * radius
		symbol["position"] = spiral_pos.lerp(player_center, eased)
		symbol["scale"] = max(0.10, 1.0 - eased * 0.82)
		symbol_positions[i] = symbol


func _update_paddle_glow() -> void:
	var progress: float = clamp(phase_timer / PADDLE_GLOW_DURATION, 0.0, 1.0)
	if progress < 0.30:
		paddle_glow_intensity = progress / 0.30
	elif progress < 0.70:
		paddle_glow_intensity = 1.0
	else:
		paddle_glow_intensity = 1.0 - ((progress - 0.70) / 0.30)


func _update_legend_after_stop(dt: float, registry: Object) -> void:
	if legend_after_stop_timer <= 0.0:
		return
	legend_after_stop_timer = max(0.0, legend_after_stop_timer - dt)
	if legend_after_stop_timer <= 0.0:
		_play_first_audio(registry, ["stop_legendary_after"])


func _create_beam(angle: float, from_crack: bool) -> void:
	# 3-color palette per original: neon gold, electric blue, pure white
	# 30% chance of a pure-white beam — these read as "lightning strike" rays
	var palette := [
		Color(1.0, 0.84, 0.20, 1.0),   # neon gold
		Color(0.30, 0.55, 1.0, 1.0),   # electric blue
		Color(1.0, 1.0, 1.0, 1.0),     # pure white
	]
	if not from_crack:
		palette[1] = Color(0.30, 0.85, 1.0, 1.0)   # warmer cyan during burst
	var color: Color = palette[rng.randi() % palette.size()]
	# Progressive width across 4 buildup waves (1.5 → 4 min, 4 → 11 max).
	# Burst beams stay thick from frame zero.
	var min_w: float
	var max_w: float
	if from_crack:
		var wave_count: int = max(1, BEAM_SPAWN_TIMES.size() - 1)
		var wave_progress: float = clamp(float(next_beam_index) / float(wave_count), 0.0, 1.0)
		min_w = 1.5 + wave_progress * 2.5    # 1.5 → 4.0
		max_w = 4.0 + wave_progress * 7.0    # 4.0 → 11.0
	else:
		min_w = 4.0
		max_w = 9.0
	beams.append({
		"angle": angle,
		"length": 0.0,
		"max_length": rng.randf_range(1100.0, 1400.0),   # full screen diagonal + buffer
		"speed": rng.randf_range(2000.0, 3500.0),         # slam to edge in ~0.3-0.7s
		"width": rng.randf_range(min_w, max_w),
		"pulse": rng.randf_range(0.0, TAU),
		"color": color,
		"from_crack": from_crack,
	})


func _update_beams(dt: float) -> void:
	for i in range(beams.size()):
		var beam: Dictionary = beams[i]
		var speed: float = float(beam.get("speed", 500.0))
		var length: float = float(beam.get("length", 0.0))
		var max_length: float = float(beam.get("max_length", 600.0))
		var speed_scale := 1.5 if bool(beam.get("from_crack", false)) else 1.0
		if phase == PHASE_BURST:
			speed_scale = 2.3
		beam["length"] = min(max_length, length + speed * speed_scale * dt)
		beam["pulse"] = float(beam.get("pulse", 0.0)) + dt * (7.0 if phase == PHASE_BURST else 2.8)
		beams[i] = beam


func _create_ambient_particles() -> void:
	var center := Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)
	for _i in range(44):
		var angle: float = rng.randf_range(0.0, TAU)
		var distance: float = rng.randf_range(110.0, 310.0)
		var color := Color(0.45 + rng.randf() * 0.55, 0.74 + rng.randf() * 0.22, 1.0, 1.0)
		ambient_particles.append({
			"base": center,
			"angle": angle,
			"distance": distance,
			"orbit_speed": rng.randf_range(-0.55, 0.55),
			"position": center + Vector2(cos(angle), sin(angle)) * distance,
			"radius": rng.randf_range(1.4, 3.8),
			"pulse": rng.randf_range(0.0, TAU),
			"color": color,
		})


func _update_ambient_particles(dt: float) -> void:
	for i in range(ambient_particles.size()):
		var particle: Dictionary = ambient_particles[i]
		var angle: float = float(particle.get("angle", 0.0)) + float(particle.get("orbit_speed", 0.0)) * dt * (1.0 + min(2.5, elapsed))
		var distance: float = max(28.0, float(particle.get("distance", 120.0)) - dt * 18.0)
		var base: Vector2 = _get_vector2(particle.get("base", Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT * 0.5)))
		particle["angle"] = angle
		particle["distance"] = distance
		particle["pulse"] = float(particle.get("pulse", 0.0)) + dt * 4.0
		particle["position"] = base + Vector2(cos(angle), sin(angle)) * distance
		ambient_particles[i] = particle


func _update_burst_particles(dt: float) -> void:
	if burst_particles.is_empty():
		return
	var write_index := 0
	for read_index in range(burst_particles.size()):
		var particle: Dictionary = burst_particles[read_index]
		var life: float = float(particle.get("life", 0.0)) - dt
		if life <= 0.0:
			continue
		var velocity: Vector2 = _get_vector2(particle.get("velocity", Vector2.ZERO)) * pow(0.76, dt)
		particle["life"] = life
		particle["velocity"] = velocity
		particle["position"] = _get_vector2(particle.get("position", Vector2.ZERO)) + velocity * dt
		burst_particles[write_index] = particle
		write_index += 1
	if write_index < burst_particles.size():
		burst_particles.resize(write_index)


func _update_baroque_particles(dt: float) -> void:
	if baroque_particles.is_empty():
		return
	var write_index := 0
	for read_index in range(baroque_particles.size()):
		var particle: Dictionary = baroque_particles[read_index]
		var life: float = float(particle.get("life", 0.0)) - dt
		if life <= 0.0:
			continue
		var velocity: Vector2 = _get_vector2(particle.get("velocity", Vector2.ZERO))
		var gravity: float = float(particle.get("gravity", 420.0))
		velocity.y += gravity * dt
		velocity *= pow(0.94, dt * 60.0)   # mild air drag
		particle["life"] = life
		particle["velocity"] = velocity
		particle["position"] = _get_vector2(particle.get("position", Vector2.ZERO)) + velocity * dt
		particle["angle"] = float(particle.get("angle", 0.0)) + float(particle.get("spin", 0.0)) * dt
		particle["pulse"] = float(particle.get("pulse", 0.0)) + float(particle.get("pulse_speed", 1.0)) * dt
		baroque_particles[write_index] = particle
		write_index += 1
	if write_index < baroque_particles.size():
		baroque_particles.resize(write_index)


func _draw_ambient(canvas: CanvasItem) -> void:
	if phase == PHASE_PADDLE_GLOW:
		return
	for particle in ambient_particles:
		var pos: Vector2 = _get_vector2(particle.get("position", Vector2.ZERO))
		var pulse: float = 0.5 + 0.5 * sin(float(particle.get("pulse", 0.0)))
		var radius: float = float(particle.get("radius", 2.0))
		var color: Color = _get_color(particle.get("color", Color.WHITE))
		var alpha: float = 0.22 + pulse * 0.34
		canvas.draw_circle(pos, radius * 3.0, Color(color.r, color.g, color.b, alpha * 0.16))
		canvas.draw_circle(pos, radius, Color(color.r, color.g, color.b, alpha))


func _draw_chest(canvas: CanvasItem, center: Vector2) -> void:
	var progress: float = clamp(elapsed / BUILDUP_DURATION, 0.0, 1.0)
	var shake := Vector2(sin(elapsed * 34.0), cos(elapsed * 29.0) * 0.5) * progress * (5.0 if phase == PHASE_BUILDUP else 28.0)
	var draw_center := center + shake
	var scale: float = 1.0 + sin(elapsed * 8.0) * 0.035
	var half := CHEST_SIZE * scale * 0.5
	var spin: float = elapsed * 0.6

	canvas.draw_circle(draw_center, half * 1.32, Color(0.10, 0.78, 1.0, 0.06 + progress * 0.10))
	canvas.draw_circle(draw_center, half * 1.10, Color(0.42, 0.18, 0.86, 0.04 + progress * 0.06))

	var holo_offsets := [0.0, 4.0, 8.0]
	for i in range(holo_offsets.size()):
		var ofs: float = float(holo_offsets[i])
		var layer_half: float = max(6.0, half - ofs)
		var diamond := PackedVector2Array([
			draw_center + Vector2(0.0, -layer_half),
			draw_center + Vector2(layer_half, 0.0),
			draw_center + Vector2(0.0, layer_half),
			draw_center + Vector2(-layer_half, 0.0),
		])
		if i == 0:
			canvas.draw_colored_polygon(diamond, Color(0.05, 0.07, 0.13, 0.94))
		var primary_alpha: float = 0.85 - float(i) * 0.22
		var accent_alpha: float = 0.62 - float(i) * 0.18
		var cyan_color := Color(0.18, 0.96, 1.0, max(0.0, primary_alpha))
		var gold_color := Color(1.0, 0.74, 0.18, max(0.0, accent_alpha))
		canvas.draw_polyline(_closed_polyline(diamond), cyan_color, max(1.2, 3.0 - float(i) * 0.7), true)
		canvas.draw_polyline(_closed_polyline(diamond), gold_color, max(1.0, 1.6 - float(i) * 0.3), true)
		if phase == PHASE_BURST:
			# chromatic aberration during the burst frame
			var cab := Vector2(2.5, 0.0)
			var diamond_r := PackedVector2Array()
			var diamond_b := PackedVector2Array()
			for p in diamond:
				diamond_r.append(p - cab)
				diamond_b.append(p + cab)
			canvas.draw_polyline(_closed_polyline(diamond_r), Color(1.0, 0.20, 0.20, 0.32), 1.6, true)
			canvas.draw_polyline(_closed_polyline(diamond_b), Color(0.20, 0.45, 1.0, 0.32), 1.6, true)

	# Hex crystal core
	var hex_radius: float = half * 0.46
	var hex_pts := PackedVector2Array()
	for j in range(6):
		var hex_angle: float = TAU * float(j) / 6.0 + spin * 0.4
		hex_pts.append(draw_center + Vector2(cos(hex_angle), sin(hex_angle)) * hex_radius)
	canvas.draw_colored_polygon(hex_pts, Color(0.07, 0.09, 0.16, 0.92))
	canvas.draw_polyline(_closed_polyline(hex_pts), Color(1.0, 0.85, 0.22, 0.88), 2.0, true)
	canvas.draw_polyline(_closed_polyline(hex_pts), Color(0.30, 0.96, 1.0, 0.46), 1.0, true)

	# Diagonal energy lines
	for k in range(4):
		var diag_angle: float = PI * 0.25 + PI * 0.5 * float(k) + spin * 0.6
		var diag_end := draw_center + Vector2(cos(diag_angle), sin(diag_angle)) * half * 0.78
		canvas.draw_line(draw_center, diag_end, Color(0.0, 0.96, 1.0, 0.55), 2.0, true)
		canvas.draw_line(draw_center, diag_end, Color(1.0, 1.0, 1.0, 0.30), 1.0, true)

	# Plasma core (concentric pulse)
	var pulse: float = 1.0 + 0.18 * sin(elapsed * 9.0)
	canvas.draw_circle(draw_center, 13.0 * pulse * scale, Color(0.55, 0.30, 0.92, 0.55))
	canvas.draw_circle(draw_center, 9.0 * pulse * scale, Color(0.0, 0.96, 1.0, 0.66))
	canvas.draw_circle(draw_center, 5.5 * pulse * scale, Color(1.0, 1.0, 1.0, 0.92))

	# Holographic rings
	canvas.draw_arc(draw_center, half * 0.68, spin, spin + PI * 1.6, 40, Color(1.0, 0.86, 0.30, 0.78), 2.0, true)
	canvas.draw_arc(draw_center, half * 0.82, -spin * 1.2, -spin * 1.2 + PI * 1.3, 40, Color(0.45, 0.94, 1.0, 0.58), 1.6, true)
	canvas.draw_arc(draw_center, half * 0.96, spin * 0.7, spin * 0.7 + PI * 1.0, 36, Color(1.0, 1.0, 1.0, 0.34), 1.0, true)

	# Apex triangle hint
	var tri_top := draw_center + Vector2(0.0, -half * 0.55)
	var tri_left := draw_center + Vector2(-half * 0.16, -half * 0.28)
	var tri_right := draw_center + Vector2(half * 0.16, -half * 0.28)
	var tri := PackedVector2Array([tri_top, tri_right, tri_left, tri_top])
	canvas.draw_polyline(tri, Color(1.0, 0.82, 0.20, 0.82), 1.6, true)


func _draw_cracks(canvas: CanvasItem, center: Vector2) -> void:
	for crack in cracks:
		var age: float = max(0.0, elapsed - float(crack.get("born", elapsed)))
		var glow: float = clamp(age / 0.20, 0.0, 1.0)
		if age > 0.20:
			glow = 0.7 + 0.3 * sin(elapsed * 5.0)
		var angle: float = float(crack.get("angle", 0.0))
		var length: float = float(crack.get("length", 42.0))
		var end_pos := center + Vector2(cos(angle), sin(angle)) * length
		var width: float = float(crack.get("width", 2.0))
		canvas.draw_line(center, end_pos, Color(1.0, 0.92, 0.28, 0.30 * glow), width + 5.0, true)
		canvas.draw_line(center, end_pos, Color(1.0, 1.0, 0.84, 0.82 * glow), max(1.0, width), true)
		if length > 38.0:
			var branch_dir: float = float(crack.get("branch_dir", 0.5))
			var branch_angle: float = angle + branch_dir
			var mid := center.lerp(end_pos, 0.5)
			var branch_end := mid + Vector2(cos(branch_angle), sin(branch_angle)) * length * 0.45
			canvas.draw_line(mid, branch_end, Color(1.0, 0.86, 0.36, 0.28 * glow), max(1.0, width * 0.7) + 2.0, true)
			canvas.draw_line(mid, branch_end, Color(1.0, 1.0, 0.84, 0.62 * glow), max(1.0, width * 0.55), true)


func _draw_beam(canvas: CanvasItem, center: Vector2, beam: Dictionary) -> void:
	var angle: float = float(beam.get("angle", 0.0))
	var length: float = float(beam.get("length", 0.0))
	if length <= 0.0:
		return
	var dir := Vector2(cos(angle), sin(angle))
	var end_pos := center + dir * length
	var color: Color = _get_color(beam.get("color", Color(0.35, 0.90, 1.0, 1.0)))
	var pulse_raw: float = float(beam.get("pulse", 0.0))
	var pulse: float = 1.0 + 0.50 * sin(pulse_raw)   # ±50% pulse, matches original
	var width: float = float(beam.get("width", 2.0)) * pulse
	# Brightened tint (clamped to 1.0) — sits between the saturated mid layer and the white core
	var bright := Color(min(1.0, color.r + 0.45), min(1.0, color.g + 0.45), min(1.0, color.b + 0.45), 1.0)

	# 5-layer beam: outer halo → mid color → bright tinted → white-hot → razor centerline.
	# High-alpha bright layers over the dark backdrop fake the BLEND_ADD bloom feel.
	canvas.draw_line(center, end_pos, Color(color.r, color.g, color.b, 0.22), max(2.0, width * 3.5), true)
	canvas.draw_line(center, end_pos, Color(color.r, color.g, color.b, 0.46), max(1.5, width * 2.5), true)
	canvas.draw_line(center, end_pos, Color(bright.r, bright.g, bright.b, 0.80), max(1.2, width * 1.7), true)
	canvas.draw_line(center, end_pos, Color(1.0, 1.0, 1.0, 0.94), max(1.0, width * 0.85), true)
	canvas.draw_line(center, end_pos, Color(1.0, 1.0, 1.0, 1.0), 1.0, true)

	# Origin pulse — bright bloom where beams emerge from the chest center.
	# This is what gives the buildup the "light pouring out" feel rather than "lines being drawn".
	var origin_pulse: float = 0.85 + 0.15 * sin(pulse_raw * 1.5)
	canvas.draw_circle(center, max(10.0, width * 3.5) * origin_pulse, Color(color.r, color.g, color.b, 0.30))
	canvas.draw_circle(center, max(5.0, width * 1.8) * origin_pulse, Color(bright.r, bright.g, bright.b, 0.65))
	canvas.draw_circle(center, max(2.5, width * 0.8) * origin_pulse, Color(1.0, 1.0, 1.0, 0.95))

	# Leading edge flare + speedline pips along the beam (motion-blur "ray" feel)
	if length > 40.0:
		var flare_pulse: float = 0.88 + 0.12 * sin(pulse_raw * 2.5)
		canvas.draw_circle(end_pos, 26.0 * flare_pulse, Color(color.r, color.g, color.b, 0.24))
		canvas.draw_circle(end_pos, 15.0 * flare_pulse, Color(bright.r, bright.g, bright.b, 0.65))
		canvas.draw_circle(end_pos, 6.5 * flare_pulse, Color(1.0, 1.0, 1.0, 0.96))
		# 3 bright pips along the beam fading toward the tail — speedline read
		for i in range(3):
			var t: float = 0.86 - float(i) * 0.20
			if t <= 0.05:
				break
			var seg_pos := center.lerp(end_pos, t)
			var seg_alpha: float = (0.55 - float(i) * 0.16) * pulse
			canvas.draw_circle(seg_pos, max(2.0, width * 0.9), Color(1.0, 1.0, 1.0, seg_alpha))


func _draw_burst_particles(canvas: CanvasItem) -> void:
	for particle in burst_particles:
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(0.01, float(particle.get("max_life", 0.75)))
		var alpha: float = clamp(life / max_life, 0.0, 1.0)
		if alpha <= 0.02:
			continue
		var pos: Vector2 = _get_vector2(particle.get("position", Vector2.ZERO))
		var velocity: Vector2 = _get_vector2(particle.get("velocity", Vector2.ZERO))
		var radius: float = float(particle.get("radius", 4.0)) * (0.45 + alpha * 0.8)
		var color: Color = _get_color(particle.get("color", Color(1.0, 0.85, 0.3)))
		# Trail (5 stamps backward along velocity, fading)
		var trail_step: Vector2 = -velocity * 0.018
		for t in range(5):
			var trail_pos := pos + trail_step * float(t + 1)
			var trail_alpha: float = (0.40 - float(t) * 0.07) * alpha
			var trail_radius: float = radius * (1.0 - float(t) * 0.16)
			if trail_radius <= 0.4 or trail_alpha <= 0.02:
				continue
			canvas.draw_circle(trail_pos, trail_radius, Color(color.r, color.g, color.b, trail_alpha))
		canvas.draw_circle(pos, radius * 3.0, Color(color.r, color.g, color.b, 0.12 * alpha))
		canvas.draw_circle(pos, radius, Color(color.r, color.g, color.b, 0.82 * alpha))
		canvas.draw_circle(pos, radius * 0.55, Color(1.0, 1.0, 1.0, 0.62 * alpha))


func _draw_baroque_particles(canvas: CanvasItem) -> void:
	if baroque_particles.is_empty():
		return
	for particle in baroque_particles:
		var life: float = float(particle.get("life", 0.0))
		var max_life: float = max(0.01, float(particle.get("max_life", 1.30)))
		var alpha_ratio: float = clamp(life / max_life, 0.0, 1.0)
		# fade-in for the first 0.15, sustain, then fade-out
		var fade: float = alpha_ratio
		if alpha_ratio > 0.85:
			fade = (1.0 - alpha_ratio) / 0.15
		fade = clamp(fade, 0.0, 1.0)
		if fade <= 0.02:
			continue
		var pos: Vector2 = _get_vector2(particle.get("position", Vector2.ZERO))
		var size: float = float(particle.get("size", 8.0))
		var ang: float = float(particle.get("angle", 0.0))
		var pulse: float = 0.85 + 0.15 * sin(float(particle.get("pulse", 0.0)))
		var color: Color = _get_color(particle.get("color", Color(1.0, 0.84, 0.0)))
		var col := Color(color.r, color.g, color.b, fade * 0.85)
		var col_dim := Color(color.r, color.g, color.b, fade * 0.40)
		var col_glow := Color(color.r, color.g, color.b, fade * 0.20)
		var s: float = size * pulse
		var kind: int = int(particle.get("kind", 0))
		# Soft glow halo behind every shape
		canvas.draw_circle(pos, s * 1.6, col_glow)
		match kind:
			0:
				# Fleur: 4-petal flower (4 lobes around center)
				for k in range(4):
					var pa: float = ang + TAU * float(k) / 4.0
					var lobe := pos + Vector2(cos(pa), sin(pa)) * s * 0.55
					canvas.draw_circle(lobe, s * 0.55, col)
				canvas.draw_circle(pos, s * 0.42, Color(1.0, 1.0, 1.0, fade * 0.85))
			1:
				# Acanthus leaf: tapered diamond + curl spine
				var tip := pos + Vector2(cos(ang), sin(ang)) * s * 1.10
				var tail := pos - Vector2(cos(ang), sin(ang)) * s * 0.55
				var perp := Vector2(-sin(ang), cos(ang)) * s * 0.42
				var leaf := PackedVector2Array([tip, pos + perp, tail, pos - perp])
				canvas.draw_colored_polygon(leaf, col)
				canvas.draw_polyline(_closed_polyline(leaf), col_dim, 1.2, true)
				canvas.draw_line(tail, tip, Color(1.0, 1.0, 1.0, fade * 0.55), 1.0, true)
			2:
				# Rosette: 6-petal compact rose with golden core
				for k in range(6):
					var pa2: float = ang + TAU * float(k) / 6.0
					var lobe2 := pos + Vector2(cos(pa2), sin(pa2)) * s * 0.50
					canvas.draw_circle(lobe2, s * 0.40, col)
				canvas.draw_circle(pos, s * 0.50, col_dim)
				canvas.draw_circle(pos, s * 0.30, Color(1.0, 0.95, 0.55, fade * 0.95))
			_:
				# Scroll: spiral approximated with arc + accent loop
				var radius_a: float = s * 0.85
				canvas.draw_arc(pos, radius_a, ang, ang + PI * 1.7, 22, col, 1.6, true)
				canvas.draw_arc(pos, radius_a * 0.55, ang + PI, ang + PI * 2.4, 16, col, 1.4, true)
				var head := pos + Vector2(cos(ang), sin(ang)) * radius_a
				canvas.draw_circle(head, s * 0.25, Color(1.0, 1.0, 1.0, fade * 0.80))


func _draw_reveal(canvas: CanvasItem, center: Vector2, shake_offset: Vector2) -> void:
	var fade: float = clamp(phase_timer / 0.50, 0.0, 1.0)
	var icon_center := center + Vector2(0.0, item_float_offset)
	if phase == PHASE_ABSORB_PULL:
		var progress: float = clamp(phase_timer / ABSORB_PULL_DURATION, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 2.2)
		icon_center = icon_center.lerp(player_center + shake_offset, eased)
	# Mystical halo (drawn first — sits BEHIND the symbol/icon stack)
	_draw_mystical_halo(canvas, icon_center, fade * item_alpha)
	# Sacred geometry magic circle (between the halo and the symbol ring)
	_draw_sacred_geometry(canvas, icon_center, fade * item_alpha)
	for radius_idx in range(4):
		var ring_radius: float = 72.0 + float(radius_idx) * 32.0 + sin(elapsed * 3.0 + float(radius_idx)) * 4.0
		var alpha: float = (0.24 - float(radius_idx) * 0.04) * fade * max(0.0, item_alpha)
		canvas.draw_arc(icon_center, ring_radius, rotation + float(radius_idx), rotation + TAU * 0.78 + float(radius_idx), 56, Color(0.45, 0.95, 1.0, alpha), 2.0, true)
		canvas.draw_arc(icon_center, ring_radius + 6.0, -rotation - float(radius_idx), -rotation + TAU * 0.52 - float(radius_idx), 48, Color(1.0, 0.82, 0.26, alpha * 0.82), 1.4, true)
	_draw_symbols(canvas, icon_center, fade * item_alpha)
	# Constellation connector lines between symbols (drawn after symbols so they read as connecting glyphs)
	_draw_constellation_links(canvas, icon_center, fade * item_alpha)
	_draw_item_icon(canvas, icon_center, ICON_SIZE * (1.0 + (1.0 - fade) * 0.55), fade * item_alpha)
	if phase == PHASE_REVEAL:
		_draw_reveal_text(canvas, center, fade)


func _draw_mystical_halo(canvas: CanvasItem, halo_center: Vector2, fade: float) -> void:
	if fade <= 0.05:
		return
	# Pulse like a soft breath
	var pulse: float = 0.70 + 0.30 * abs(sin(elapsed * 1.6))
	# 6 nested radial layers — outer first so inner glows on top
	var layers := [
		{"r": 200.0, "a": 0.06, "c": Color(1.00, 0.96, 0.78)},
		{"r": 160.0, "a": 0.08, "c": Color(1.00, 0.92, 0.71)},
		{"r": 130.0, "a": 0.10, "c": Color(1.00, 0.88, 0.63)},
		{"r": 100.0, "a": 0.12, "c": Color(1.00, 0.84, 0.55)},
		{"r":  75.0, "a": 0.14, "c": Color(1.00, 0.80, 0.47)},
		{"r":  50.0, "a": 0.16, "c": Color(1.00, 0.76, 0.39)},
	]
	for layer in layers:
		var lr: float = float(layer["r"]) * pulse
		var la: float = float(layer["a"]) * fade * pulse
		var lc: Color = layer["c"]
		# Approximate radial gradient via 4 stacked discs at decreasing radius
		for step in range(4):
			var sr: float = lr * (1.0 - float(step) * 0.18)
			var sa: float = la * (0.55 + float(step) * 0.15)
			canvas.draw_circle(halo_center, sr, Color(lc.r, lc.g, lc.b, sa))
	# Bright white core
	var core_r: float = 30.0 * pulse
	canvas.draw_circle(halo_center, core_r, Color(1.0, 1.0, 1.0, 0.30 * fade))
	canvas.draw_circle(halo_center, core_r * 0.55, Color(1.0, 1.0, 1.0, 0.55 * fade))
	# 20 orbiting sparkle stars (after the warmup)
	if fade > 0.30:
		var spark_count: int = 20
		for i in range(spark_count):
			var orbit_angle: float = TAU * float(i) / float(spark_count) + elapsed * 0.10
			var orbit_dist: float = 60.0 + sin(orbit_angle * 3.0 + elapsed * 1.6) * 20.0
			var sx: float = halo_center.x + orbit_dist * cos(orbit_angle)
			var sy: float = halo_center.y + orbit_dist * sin(orbit_angle)
			var sparkle: float = abs(sin(elapsed * 5.0 + float(i)))
			var sa: float = 0.40 * sparkle * fade
			if sa <= 0.02:
				continue
			var radius: float = 1.6 + sparkle * 1.6
			canvas.draw_circle(Vector2(sx, sy), radius * 2.4, Color(1.0, 0.96, 0.86, sa * 0.45))
			canvas.draw_circle(Vector2(sx, sy), radius, Color(1.0, 0.96, 0.86, sa))
	# 12 radial light rays (peak only)
	if fade > 0.55:
		var ray_count: int = 12
		for i in range(ray_count):
			var ra: float = TAU * float(i) / float(ray_count) + elapsed * 0.20
			var ray_len: float = 150.0 + sin(elapsed * 3.0 + float(i)) * 30.0
			var ray_alpha: float = 0.16 * fade * pulse
			var rx: float = halo_center.x + ray_len * cos(ra)
			var ry: float = halo_center.y + ray_len * sin(ra)
			canvas.draw_line(halo_center, Vector2(rx, ry), Color(1.0, 0.94, 0.78, ray_alpha * 0.55), 3.0, true)
			canvas.draw_line(halo_center, Vector2(rx, ry), Color(1.0, 1.0, 0.92, ray_alpha), 1.0, true)


func _draw_sacred_geometry(canvas: CanvasItem, geom_center: Vector2, fade: float) -> void:
	if fade <= 0.30:
		return
	var inner_alpha: float = clamp((fade - 0.30) / 0.70, 0.0, 1.0)
	var royal_gold := Color(1.0, 0.84, 0.0, inner_alpha)
	var ancient_silver := Color(0.78, 0.80, 0.86, inner_alpha)
	var deep_purple := Color(0.36, 0.12, 0.62, inner_alpha)
	var mystic_violet := Color(0.58, 0.30, 0.92, inner_alpha)
	var sacred_amber := Color(1.00, 0.72, 0.18, inner_alpha)
	# Triple hex magic circle (3 nested hexagons rotating at different speeds)
	for layer in range(3):
		var hex_radius: float = 80.0 - float(layer) * 10.0
		var layer_alpha: float = inner_alpha * (1.0 - float(layer) * 0.12)
		if layer_alpha <= 0.04:
			continue
		var hex_color: Color = mystic_violet
		if layer == 1:
			hex_color = deep_purple
		elif layer == 2:
			hex_color = sacred_amber
		hex_color.a = layer_alpha * 0.55
		var spin: float = -rotation * (0.5 + float(layer) * 0.20)
		var hex_pts := PackedVector2Array()
		for j in range(6):
			var ha: float = TAU * float(j) / 6.0 + spin
			hex_pts.append(geom_center + Vector2(cos(ha), sin(ha)) * hex_radius)
		canvas.draw_polyline(_closed_polyline(hex_pts), hex_color, 1.2, true)
		# Vertex dots
		for p in hex_pts:
			canvas.draw_arc(p, 2.0, 0.0, TAU, 12, Color(royal_gold.r, royal_gold.g, royal_gold.b, layer_alpha * 0.85), 1.0, true)
	# Central 6-pointed star (12-vertex star polyline)
	var star_radius: float = 40.0
	var star_pts := PackedVector2Array()
	for j in range(12):
		var sa: float = TAU * float(j) / 12.0 - rotation * 0.7
		var sr: float = star_radius if j % 2 == 0 else star_radius * 0.5
		star_pts.append(geom_center + Vector2(cos(sa), sin(sa)) * sr)
	canvas.draw_polyline(_closed_polyline(star_pts), Color(sacred_amber.r, sacred_amber.g, sacred_amber.b, inner_alpha * 0.85), 1.4, true)
	# Dotted spokes from center to outer hex vertices
	for i in range(6):
		var spoke_angle: float = TAU * float(i) / 6.0 - rotation * 0.5
		for j in range(0, 80, 10):
			if j % 20 < 10:
				var dx: float = geom_center.x + float(j) * cos(spoke_angle)
				var dy: float = geom_center.y + float(j) * sin(spoke_angle)
				canvas.draw_circle(Vector2(dx, dy), 1.0, Color(ancient_silver.r, ancient_silver.g, ancient_silver.b, inner_alpha * 0.66))
	# 6 rune crosses between hex vertices
	for i in range(6):
		var rune_angle: float = TAU * (float(i) + 0.5) / 6.0 - rotation * 0.5
		var rune_x: float = geom_center.x + 65.0 * cos(rune_angle)
		var rune_y: float = geom_center.y + 65.0 * sin(rune_angle)
		var rp := Vector2(rune_x, rune_y)
		canvas.draw_line(rp + Vector2(-3.0, 0.0), rp + Vector2(3.0, 0.0), Color(mystic_violet.r, mystic_violet.g, mystic_violet.b, inner_alpha * 0.85), 1.0, true)
		canvas.draw_line(rp + Vector2(0.0, -3.0), rp + Vector2(0.0, 3.0), Color(mystic_violet.r, mystic_violet.g, mystic_violet.b, inner_alpha * 0.85), 1.0, true)
		canvas.draw_arc(rp, 5.0, 0.0, TAU, 14, Color(royal_gold.r, royal_gold.g, royal_gold.b, inner_alpha * 0.66), 1.0, true)


func _draw_constellation_links(canvas: CanvasItem, geom_center: Vector2, fade: float) -> void:
	if fade <= 0.60:
		return
	var alpha: float = clamp((fade - 0.60) / 0.40, 0.0, 1.0)
	var silver := Color(0.78, 0.80, 0.86, alpha * 0.55)
	var num_symbols: int = 6
	var outer_radius: float = 132.0
	for i in range(num_symbols):
		for j in range(i + 1, num_symbols):
			if (i + j) % 2 != 0:
				continue
			var a1: float = TAU * float(i) / float(num_symbols) + rotation
			var a2: float = TAU * float(j) / float(num_symbols) + rotation
			var p1: Vector2 = geom_center + Vector2(cos(a1), sin(a1)) * outer_radius
			var p2: Vector2 = geom_center + Vector2(cos(a2), sin(a2)) * outer_radius
			# Dotted line: 5 visible dots along the segment (every 3 of 15 steps)
			for k in range(15):
				if k % 3 != 0:
					continue
				var t: float = float(k) / 15.0
				var dot := p1.lerp(p2, t)
				canvas.draw_circle(dot, 1.0, silver)


func _draw_symbols(canvas: CanvasItem, center: Vector2, alpha: float) -> void:
	if alpha <= 0.01:
		return
	var source: Array[Dictionary] = symbol_positions
	if source.is_empty():
		for i in range(6):
			var angle: float = rotation + TAU * float(i) / 6.0
			_draw_symbol(canvas, center + Vector2(cos(angle), sin(angle)) * 132.0, 1.0, alpha, i)
		return
	for i in range(source.size()):
		var symbol: Dictionary = source[i]
		_draw_symbol(
			canvas,
			_get_vector2(symbol.get("position", center)),
			float(symbol.get("scale", 1.0)),
			alpha,
			int(symbol.get("idx", i))
		)


func _draw_symbol(canvas: CanvasItem, pos: Vector2, scale: float, alpha: float, idx: int = 0) -> void:
	var s: float = max(0.1, scale)
	var royal_gold := Color(1.0, 0.84, 0.0, alpha)
	var amber := Color(1.0, 0.75, 0.0, alpha)
	var silver := Color(0.78, 0.80, 0.86, alpha)
	var deep_purple := Color(0.32, 0.10, 0.62, alpha)
	var mystic_violet := Color(0.56, 0.20, 0.92, alpha)
	var soft_white := Color(1.0, 1.0, 1.0, 0.85 * alpha)

	# Outer ornamental ring shared by all symbols
	canvas.draw_arc(pos, 18.0 * s, 0.0, TAU, 28, Color(deep_purple.r, deep_purple.g, deep_purple.b, alpha * 0.55), 1.0, true)
	canvas.draw_arc(pos, 15.0 * s, 0.0, TAU, 28, Color(mystic_violet.r, mystic_violet.g, mystic_violet.b, alpha * 0.45), 1.0, true)

	match idx % 6:
		0:
			# Sun: 3 concentric rings + 8 rays + amber core
			canvas.draw_arc(pos, 10.0 * s, 0.0, TAU, 30, royal_gold, 1.6, true)
			canvas.draw_arc(pos, 7.0 * s, 0.0, TAU, 24, amber, 1.2, true)
			canvas.draw_arc(pos, 4.0 * s, 0.0, TAU, 18, royal_gold, 1.0, true)
			canvas.draw_circle(pos, 2.2 * s, amber)
			if s > 0.30:
				for r in range(8):
					var ray_angle: float = TAU * float(r) / 8.0
					var p1: Vector2 = pos + Vector2(cos(ray_angle), sin(ray_angle)) * 5.5 * s
					var p2: Vector2 = pos + Vector2(cos(ray_angle), sin(ray_angle)) * 9.0 * s
					canvas.draw_line(p1, p2, Color(royal_gold.r, royal_gold.g, royal_gold.b, alpha * 0.86), 1.2, true)
		1:
			# Moon + stars: silver crescent arc + violet inner arc + 2 small stars
			if s > 0.20:
				canvas.draw_arc(pos, 9.0 * s, PI * 0.30, PI * 1.70, 28, silver, 1.8, true)
				canvas.draw_arc(pos, 7.0 * s, PI * 0.40, PI * 1.60, 24, mystic_violet, 1.0, true)
				if s > 0.40:
					canvas.draw_circle(pos + Vector2(5.5 * s, -3.0 * s), 1.4, silver)
					canvas.draw_circle(pos + Vector2(3.0 * s, 2.5 * s), 1.0, silver)
		2:
			# Pentagram (10-point star polyline) + amber core
			var star := PackedVector2Array()
			for j in range(10):
				var sa: float = TAU * float(j) / 10.0 - PI * 0.5
				var sr: float = (10.0 if j % 2 == 0 else 4.0) * s
				star.append(pos + Vector2(cos(sa), sin(sa)) * sr)
			canvas.draw_polyline(_closed_polyline(star), royal_gold, 1.6, true)
			canvas.draw_circle(pos, 1.8, amber)
		3:
			# Infinity (two rings + inner rings + amber center dot)
			var left := pos + Vector2(-5.0 * s, 0.0)
			var right := pos + Vector2(5.0 * s, 0.0)
			canvas.draw_arc(left, 5.0 * s, 0.0, TAU, 22, deep_purple, 1.6, true)
			canvas.draw_arc(right, 5.0 * s, 0.0, TAU, 22, deep_purple, 1.6, true)
			canvas.draw_arc(left, 3.0 * s, 0.0, TAU, 16, mystic_violet, 1.0, true)
			canvas.draw_arc(right, 3.0 * s, 0.0, TAU, 16, mystic_violet, 1.0, true)
			canvas.draw_circle(pos, 1.6, amber)
		4:
			# Celtic cross: cross beams + center ring + 4 endcap dots
			canvas.draw_line(pos + Vector2(-8.0 * s, 0.0), pos + Vector2(8.0 * s, 0.0), silver, 1.8, true)
			canvas.draw_line(pos + Vector2(0.0, -8.0 * s), pos + Vector2(0.0, 8.0 * s), silver, 1.8, true)
			canvas.draw_arc(pos, 5.0 * s, 0.0, TAU, 22, royal_gold, 1.4, true)
			canvas.draw_arc(pos, 3.0 * s, 0.0, TAU, 16, amber, 1.0, true)
			if s > 0.30:
				var endcaps := [Vector2(-8.0 * s, 0.0), Vector2(8.0 * s, 0.0), Vector2(0.0, -8.0 * s), Vector2(0.0, 8.0 * s)]
				for e in endcaps:
					canvas.draw_circle(pos + e, 1.6, silver)
		_:
			# Sacred diamond (outer + inner diamond polyline + amber + violet center)
			var outer := PackedVector2Array([
				pos + Vector2(0.0, -10.0 * s),
				pos + Vector2(8.0 * s, 0.0),
				pos + Vector2(0.0, 10.0 * s),
				pos + Vector2(-8.0 * s, 0.0),
			])
			canvas.draw_polyline(_closed_polyline(outer), royal_gold, 1.6, true)
			var inner := PackedVector2Array([
				pos + Vector2(0.0, -6.0 * s),
				pos + Vector2(5.0 * s, 0.0),
				pos + Vector2(0.0, 6.0 * s),
				pos + Vector2(-5.0 * s, 0.0),
			])
			canvas.draw_polyline(_closed_polyline(inner), amber, 1.2, true)
			canvas.draw_circle(pos, 1.8, mystic_violet)
			canvas.draw_circle(pos, 0.9, soft_white)


func _draw_item_icon(canvas: CanvasItem, center: Vector2, size: float, alpha: float) -> void:
	if alpha <= 0.01:
		return
	var icon_rect := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	canvas.draw_circle(center, size * 0.72, Color(1.0, 0.80, 0.20, 0.18 * alpha))
	canvas.draw_circle(center, size * 0.52, Color(0.06, 0.07, 0.12, 0.84 * alpha))
	canvas.draw_arc(center, size * 0.55, rotation, rotation + TAU, 72, Color(1.0, 0.90, 0.35, 0.70 * alpha), 2.4, true)
	if item_texture != null:
		canvas.draw_texture_rect_region(item_texture, icon_rect, _get_icon_source_rect(), Color(1.0, 1.0, 1.0, alpha))
	else:
		canvas.draw_circle(center, size * 0.34, Color(1.0, 0.82, 0.22, 0.88 * alpha))


func _draw_reveal_text(canvas: CanvasItem, center: Vector2, alpha: float) -> void:
	_draw_centered_text(canvas, "신화 아이템", center + Vector2(0.0, -154.0), 25, Color(1.0, 0.83, 0.22, 0.96 * alpha))
	_draw_centered_text(canvas, display_name, center + Vector2(0.0, 132.0), 24, Color(1.0, 1.0, 1.0, 0.96 * alpha))
	if is_waiting_for_click():
		var pulse: float = 0.55 + 0.45 * sin(elapsed * 6.0)
		_draw_centered_text(canvas, "클릭하여 획득", center + Vector2(0.0, 172.0), 18, Color(0.72, 0.96, 1.0, (0.55 + pulse * 0.35) * alpha))


func _draw_paddle_glow(canvas: CanvasItem, shake_offset: Vector2) -> void:
	var center := player_center + shake_offset
	var alpha: float = clamp(paddle_glow_intensity, 0.0, 1.0)
	if alpha <= 0.01:
		return
	var time_factor: float = phase_timer * 6.0

	# HSV rainbow expansion rings (8 layers, hue cycling)
	for i in range(8):
		var hue: float = fmod(time_factor * 0.05 + float(i) * 0.083, 1.0)
		var ring_radius: float = 26.0 + float(i) * 14.0
		var ring_alpha: float = alpha * max(0.0, 1.0 - float(i) * 0.10) * 0.46
		var ring_color := Color.from_hsv(hue, 0.78, 1.0, ring_alpha)
		canvas.draw_arc(center, ring_radius, 0.0, TAU, 64, ring_color, max(1.0, 4.0 - float(i) * 0.35), true)

	# Outward propagating rings (kept from original)
	for i in range(5):
		var t: float = fmod(phase_timer * 1.6 + float(i) * 0.17, 1.0)
		var radius: float = 26.0 + t * 108.0
		canvas.draw_arc(center, radius, 0.0, TAU, 72, Color(1.0, 0.84, 0.22, alpha * (1.0 - t) * 0.40), max(1.0, 4.0 * (1.0 - t)), true)

	# Spiral mystic particles
	if alpha > 0.30:
		var spiral_count: int = 14
		var spiral_palette := [
			Color(0.58, 0.44, 0.86),
			Color(0.39, 0.58, 0.93),
			Color(0.53, 0.81, 0.92),
			Color(0.87, 0.63, 0.87),
		]
		for i in range(spiral_count):
			var ang: float = TAU * float(i) / float(spiral_count) + phase_timer * 2.4
			var pr: float = 32.0 + sin(phase_timer * 4.5 + float(i) * 0.42) * 18.0
			var px: float = center.x + pr * cos(ang)
			var py: float = center.y + pr * sin(ang) * 0.72
			var pcol: Color = spiral_palette[i % spiral_palette.size()]
			var psize: float = 2.4 + sin(phase_timer * 6.0 + float(i)) * 1.0
			canvas.draw_circle(Vector2(px, py), psize, Color(pcol.r, pcol.g, pcol.b, alpha * 0.55))

	# 6 sacred runes (gold rings + spoke to center)
	if alpha > 0.50:
		for i in range(6):
			var rang: float = TAU * float(i) / 6.0 + phase_timer * 0.55
			var rune_pos := center + Vector2(cos(rang), sin(rang)) * 70.0
			canvas.draw_arc(rune_pos, 4.0, 0.0, TAU, 14, Color(1.0, 0.84, 0.18, alpha * 0.66), 1.2, true)
			canvas.draw_line(rune_pos, center, Color(1.0, 0.84, 0.18, alpha * 0.30), 1.0, true)

	# Cross + diagonal beams during peak
	if alpha > 0.70:
		var line_len: float = 200.0 * alpha
		var beam_alpha: float = alpha * 0.55
		for off in [-2.0, -1.0, 0.0, 1.0, 2.0]:
			canvas.draw_line(Vector2(center.x - line_len, center.y + off), Vector2(center.x + line_len, center.y + off), Color(1.0, 0.84, 0.20, beam_alpha), 1.0, true)
			canvas.draw_line(Vector2(center.x + off, center.y - line_len * 0.5), Vector2(center.x + off, center.y + line_len * 0.5), Color(1.0, 0.84, 0.20, beam_alpha), 1.0, true)
		var diag: float = 100.0 * alpha
		var diag_alpha: float = alpha * 0.35
		for off in [-1.0, 0.0, 1.0]:
			canvas.draw_line(Vector2(center.x - diag + off, center.y - diag), Vector2(center.x + diag + off, center.y + diag), Color(1.0, 1.0, 1.0, diag_alpha), 1.0, true)
			canvas.draw_line(Vector2(center.x + diag + off, center.y - diag), Vector2(center.x - diag + off, center.y + diag), Color(1.0, 1.0, 1.0, diag_alpha), 1.0, true)

	# Center flash + core
	canvas.draw_circle(center, 36.0 + alpha * 8.0, Color(1.0, 0.82, 0.25, 0.24 * alpha))
	canvas.draw_circle(center, 18.0, Color(1.0, 0.92, 0.45, 0.38 * alpha))
	canvas.draw_circle(center, 12.0, Color(1.0, 1.0, 1.0, 0.64 * alpha))


func _draw_centered_text(canvas: CanvasItem, text: String, baseline_center: Vector2, font_size: int, color: Color) -> void:
	if text == "":
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var pos := Vector2(baseline_center.x - text_size.x * 0.5, baseline_center.y)
	canvas.draw_string(font, pos + Vector2(2.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.72))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _closed_polyline(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if points.size() > 0:
		closed.append(points[0])
	return closed


func _load_item_texture() -> void:
	item_texture = null
	icon_frame_count = max(1, int(item_data.get("icon_frame_count", 1)))
	icon_frame_msec = max(1, int(item_data.get("icon_frame_msec", 33)))
	icon_source_inset = max(0.0, float(item_data.get("icon_source_inset", 0.0)))
	var path := str(item_data.get("icon_sheet_path", ""))
	if path == "":
		path = str(item_data.get("icon_path", ""))
	if path == "":
		return
	item_texture = ProjectResourceLoader.load_texture(path)


func _get_icon_source_rect() -> Rect2:
	if item_texture == null:
		return Rect2()
	var texture_size: Vector2 = item_texture.get_size()
	var frame_count: int = max(1, icon_frame_count)
	var frame_width: float = texture_size.x / float(frame_count)
	var frame_index: int = 0
	if frame_count > 1:
		frame_index = int(floor(float(Time.get_ticks_msec()) / float(icon_frame_msec))) % frame_count
	var inset: float = min(icon_source_inset, max(0.0, min(frame_width, texture_size.y) * 0.42))
	return Rect2(
		Vector2(frame_width * float(frame_index) + inset, inset),
		Vector2(max(1.0, frame_width - inset * 2.0), max(1.0, texture_size.y - inset * 2.0))
	)


func _resolve_display_name(source: Dictionary) -> String:
	for key in ["qualified_display_name", "korean_name", "display_name", "name"]:
		var value := str(source.get(key, ""))
		if value != "":
			return value
	return "신화 아이템"


func _resolve_player_center(owner: Object) -> Vector2:
	if owner == null:
		return Vector2(FIELD_WIDTH * 0.5, FIELD_HEIGHT - 25.0)
	var player_pos: Vector2 = _get_vector2(owner.get("player_pos") if owner.has_method("get") else Vector2.ZERO)
	var paddle_width: float = float(owner.get("player_paddle_width")) if owner.has_method("get") else 155.0
	var paddle_height: float = float(owner.get("player_paddle_height")) if owner.has_method("get") else 50.0
	return player_pos + Vector2(paddle_width * 0.5, paddle_height * 0.5)


func _play_first_audio(registry: Object, method_names: Array[String]) -> void:
	var audio: Object = _get_instance(registry, "game_audio")
	if audio == null:
		return
	for method_name in method_names:
		if audio.has_method(method_name):
			audio.call(method_name)
			return


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	return Vector2.ZERO


func _get_color(value: Variant) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]) / 255.0, float(value[1]) / 255.0, float(value[2]) / 255.0, 1.0)
	return Color.WHITE
