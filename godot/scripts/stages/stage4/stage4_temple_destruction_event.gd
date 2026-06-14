extends RefCounted

const Stage4DestructionWavePayloadFactory := preload("res://scripts/stages/stage4/stage4_destruction_wave_payload_factory.gd")
const Stage4TempleCollapsePayloadFactory := preload("res://scripts/stages/stage4/stage4_temple_collapse_payload_factory.gd")

const PHASE_IDLE := 0
const PHASE_MOON_TURNING_RED := 1
const PHASE_RED_LIGHT := 2
const PHASE_DESTRUCTION_WAVE := 3
const PHASE_COLLAPSING := 4
const PHASE_RUINS := 5

const MOON_TURN_SEC := 3.0
const RED_LIGHT_SEC := 1.5
const WAVE_SEC := 2.0
const COLLAPSE_SEC := 5.0
const WAVE_FIRE_TIME_SEC := 1.0
const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0
const WAVE_SPEED_PX_PER_SEC := 720.0
const WAVE_MAX_LIFETIME_SEC := 1.5
const WAVE_HIT_RADIUS := 50.0
const WAVE_START := Vector2(FIELD_WIDTH + 24.0, 10.0)
const WAVE_TARGET := Vector2(FIELD_WIDTH * 0.5, 350.0)
const TEMPLE_X := FIELD_WIDTH * 0.5
const TEMPLE_BASE_Y := 450.0
const PAGODA_LEVELS := 5
const ADDITIONAL_DEBRIS_INTERVAL_SEC := 25.0 / 60.0
const ADDITIONAL_DEBRIS_END_SEC := 200.0 / 60.0
const DEBRIS_FADE_START_SEC := 200.0 / 60.0
const ROOF_FADE_START_SEC := 220.0 / 60.0
const DEBRIS_OPACITY_FADE_PER_FRAME := 2.0 / 255.0
const MAPWIDE_BURST_DEBRIS_COUNT := 48

const LANTERN_ANCHORS := [
	{"x": 130.0, "y": 300.0, "size": "large"},
	{"x": 630.0, "y": 300.0, "size": "large"},
	{"x": 230.0, "y": 250.0, "size": "medium"},
	{"x": 530.0, "y": 250.0, "size": "medium"},
	{"x": 330.0, "y": 180.0, "size": "small"},
	{"x": 430.0, "y": 180.0, "size": "small"},
]

const TRAINING_DUMMY_ANCHORS := [
	Vector2(200.0, 500.0),
	Vector2(560.0, 500.0),
]

const DEBRIS_TYPE_SPRITE_VARIANTS := {
	"brick": [0, 12, 13],
	"roof_tile": [1, 11],
	"wood_beam": [2, 14],
	"stone": [15, 8, 4, 13],
	"pillar_chunk": [3, 15],
	"glass": [9, 10],
	"spire_ornament": [5],
	"window_lattice": [6],
	"door_fragment": [7],
	"stair_stone": [8, 15],
	"dust": [13],
}

var temple_destroyed := false
var destruction_animation_active := false
var destruction_phase := PHASE_IDLE
var phase_timer := 0.0
var total_timer := 0.0
var moon_red_intensity := 0.0
var moon_pulse_scale := 1.0
var red_light_alpha := 0.0
var collapse_progress := 0.0
var screen_shake_intensity := 0.0
var destruction_wave_active := false
var destruction_wave_progress := 0.0
var destruction_wave_fired := false
var destruction_wave: Dictionary = {}
var last_start_reason := ""
var rng := RandomNumberGenerator.new()
var collapse_debris: Array = []
var roof_fragments: Array = []
var dust_clouds: Array = []
var falling_lanterns: Array = []
var ground_fires: Array = []
var collapse_payload_started := false
var decorations_destroyed := false
var next_additional_debris_time := 0.0


func _init() -> void:
	rng.randomize()


func reset() -> void:
	temple_destroyed = false
	destruction_animation_active = false
	destruction_phase = PHASE_IDLE
	phase_timer = 0.0
	total_timer = 0.0
	moon_red_intensity = 0.0
	moon_pulse_scale = 1.0
	red_light_alpha = 0.0
	collapse_progress = 0.0
	screen_shake_intensity = 0.0
	destruction_wave_active = false
	destruction_wave_progress = 0.0
	destruction_wave_fired = false
	destruction_wave.clear()
	last_start_reason = ""
	_clear_collapse_payload()


func start_destruction_animation(reason: String = "") -> bool:
	if destruction_animation_active or temple_destroyed:
		return false
	destruction_animation_active = true
	destruction_phase = PHASE_MOON_TURNING_RED
	phase_timer = 0.0
	total_timer = 0.0
	moon_red_intensity = maxf(moon_red_intensity, 0.02)
	moon_pulse_scale = 1.0
	red_light_alpha = 0.0
	collapse_progress = 0.0
	screen_shake_intensity = 0.0
	destruction_wave_active = false
	destruction_wave_progress = 0.0
	destruction_wave_fired = false
	destruction_wave.clear()
	last_start_reason = reason
	_clear_collapse_payload()
	return true


func update(delta: float, _context: Dictionary = {}, deps: Dictionary = {}) -> void:
	if not destruction_animation_active:
		_update_idle_moon(delta)
		return
	var clamped_delta: float = clampf(delta, 0.0, 0.1)
	phase_timer += clamped_delta
	total_timer += clamped_delta
	match destruction_phase:
		PHASE_MOON_TURNING_RED:
			_update_moon_turning_red(deps)
		PHASE_RED_LIGHT:
			_update_red_light()
		PHASE_DESTRUCTION_WAVE:
			_update_destruction_wave(clamped_delta, deps)
		PHASE_COLLAPSING:
			_update_collapsing(clamped_delta)
		PHASE_RUINS:
			_finish_destruction()


func is_destruction_animation_active() -> bool:
	return destruction_animation_active


func is_temple_destroyed() -> bool:
	return temple_destroyed


func get_snapshot() -> Dictionary:
	return {
		"stage4_temple_destroyed": temple_destroyed,
		"stage4_destruction_active": destruction_animation_active,
		"stage4_destruction_phase": destruction_phase,
		"stage4_destruction_phase_timer": phase_timer,
		"stage4_destruction_total_timer": total_timer,
		"stage4_moon_red_intensity": moon_red_intensity,
		"stage4_moon_pulse_scale": moon_pulse_scale,
		"stage4_red_light_alpha": red_light_alpha,
		"stage4_collapse_progress": collapse_progress,
		"stage4_screen_shake_intensity": screen_shake_intensity,
		"stage4_destruction_wave_active": destruction_wave_active,
		"stage4_destruction_wave_progress": destruction_wave_progress,
		"stage4_destruction_wave": destruction_wave,
		"stage4_destruction_reason": last_start_reason,
		"stage4_decorations_destroyed": decorations_destroyed or temple_destroyed,
		"stage4_collapse_debris": collapse_debris,
		"stage4_roof_fragments": roof_fragments,
		"stage4_dust_clouds": dust_clouds,
		"stage4_falling_lanterns": falling_lanterns,
		"stage4_ground_fires": ground_fires,
	}


func _update_idle_moon(delta: float) -> void:
	if temple_destroyed:
		moon_red_intensity = move_toward(moon_red_intensity, 1.0, delta * 0.4)
		moon_pulse_scale = 1.0 + 0.07 * sin(float(Time.get_ticks_msec()) * 0.004)
	else:
		moon_pulse_scale = 1.0
		red_light_alpha = 0.0
		screen_shake_intensity = 0.0


func _update_moon_turning_red(_deps: Dictionary) -> void:
	var progress: float = clampf(phase_timer / MOON_TURN_SEC, 0.0, 1.0)
	moon_red_intensity = sqrt(progress)
	moon_pulse_scale = 1.0 + 0.10 * sin(progress * PI * 5.0)
	if progress >= 1.0:
		_enter_phase(PHASE_RED_LIGHT)


func _update_red_light() -> void:
	var progress: float = clampf(phase_timer / RED_LIGHT_SEC, 0.0, 1.0)
	var flash: float = sin(progress * PI)
	red_light_alpha = 0.58 * flash
	moon_red_intensity = 1.0
	moon_pulse_scale = 1.0 + 0.08 * flash
	if progress >= 1.0:
		red_light_alpha = 0.0
		_enter_phase(PHASE_DESTRUCTION_WAVE)


func _update_destruction_wave(delta: float, deps: Dictionary) -> void:
	var progress: float = clampf(phase_timer / WAVE_SEC, 0.0, 1.0)
	moon_red_intensity = 1.0
	destruction_wave_progress = progress
	if phase_timer <= WAVE_FIRE_TIME_SEC + 0.0001:
		var charge: float = clampf(phase_timer / WAVE_FIRE_TIME_SEC, 0.0, 1.0)
		moon_pulse_scale = 1.0 + charge * 0.5
		destruction_wave_active = false
		destruction_wave.clear()
	elif not destruction_wave_fired:
		destruction_wave_fired = true
		moon_pulse_scale = 1.0
		_fire_destruction_wave()
		_play_moon_shoot_sound(deps)
	if destruction_wave_fired and not destruction_wave.is_empty():
		_update_destruction_wave_payload(delta, deps)
	if progress >= 1.0:
		destruction_wave_active = false
		destruction_wave_progress = 0.0
		destruction_wave.clear()
		_enter_phase(PHASE_COLLAPSING)


func _update_collapsing(delta: float) -> void:
	if not collapse_payload_started:
		_start_collapse_payload()
	var progress: float = clampf(phase_timer / COLLAPSE_SEC, 0.0, 1.0)
	collapse_progress = progress
	moon_red_intensity = 1.0
	moon_pulse_scale = 1.0 + 0.04 * sin(total_timer * 9.0)
	if progress < 0.2:
		screen_shake_intensity = 8.0 + progress * 18.0
	elif progress < 0.5:
		screen_shake_intensity = 12.0
	else:
		screen_shake_intensity = maxf(0.0, 12.0 * (1.0 - progress))
	_update_collapse_payload(delta)
	if progress >= 1.0:
		_enter_phase(PHASE_RUINS)


func _finish_destruction() -> void:
	temple_destroyed = true
	destruction_animation_active = false
	destruction_phase = PHASE_RUINS
	phase_timer = 0.0
	moon_red_intensity = 1.0
	moon_pulse_scale = 1.0
	red_light_alpha = 0.0
	collapse_progress = 1.0
	screen_shake_intensity = 0.0
	destruction_wave_active = false
	destruction_wave_progress = 0.0
	destruction_wave.clear()


func _enter_phase(next_phase: int) -> void:
	destruction_phase = next_phase
	phase_timer = 0.0
	if next_phase == PHASE_COLLAPSING:
		collapse_progress = 0.0
		_start_collapse_payload()


func _play_moon_shoot_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage4_moon_shoot"):
		audio.play_stage4_moon_shoot()


func _play_temple_hit_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_stage4_temple_hit"):
		audio.play_stage4_temple_hit()


func _fire_destruction_wave() -> void:
	destruction_wave = Stage4DestructionWavePayloadFactory.build_wave(
		WAVE_START,
		WAVE_TARGET,
		WAVE_SPEED_PX_PER_SEC,
		WAVE_MAX_LIFETIME_SEC
	)
	destruction_wave_active = true


func _update_destruction_wave_payload(delta: float, deps: Dictionary) -> void:
	var fps_scale: float = clampf(delta, 0.0, 0.1) * 60.0
	destruction_wave["lifetime"] = float(destruction_wave.get("lifetime", 0.0)) + delta
	destruction_wave["core_rotation"] = float(destruction_wave.get("core_rotation", 0.0)) + 15.0 * fps_scale
	destruction_wave["current_x"] = float(destruction_wave.get("current_x", WAVE_START.x)) + float(destruction_wave.get("vx", 0.0)) * delta
	destruction_wave["current_y"] = float(destruction_wave.get("current_y", WAVE_START.y)) + float(destruction_wave.get("vy", 0.0)) * delta
	var lifetime: float = float(destruction_wave.get("lifetime", 0.0))
	var wave_progress: float = lifetime / WAVE_MAX_LIFETIME_SEC
	destruction_wave["radius"] = 120.0 * minf(1.0, wave_progress * 1.5)
	_spawn_destruction_wave_particles()
	_update_destruction_wave_particles(fps_scale)
	var current := Vector2(float(destruction_wave.get("current_x", WAVE_START.x)), float(destruction_wave.get("current_y", WAVE_START.y)))
	if current.distance_to(WAVE_TARGET) < WAVE_HIT_RADIUS:
		_play_temple_hit_sound(deps)
		destruction_wave.clear()
		destruction_wave_active = false
	elif lifetime >= WAVE_MAX_LIFETIME_SEC:
		destruction_wave.clear()
		destruction_wave_active = false


func _spawn_destruction_wave_particles() -> void:
	var lifetime_frames: int = int(round(float(destruction_wave.get("lifetime", 0.0)) * 60.0))
	if lifetime_frames % 2 == 0:
		var center := Vector2(
			float(destruction_wave.get("current_x", WAVE_START.x)),
			float(destruction_wave.get("current_y", WAVE_START.y))
		)
		var trail: Array = _as_array(destruction_wave.get("trail", []))
		trail.append_array(Stage4DestructionWavePayloadFactory.build_trail_particles(center, 5, rng))
		destruction_wave["trail"] = trail
		var beams: Array = _as_array(destruction_wave.get("beam_particles", []))
		var angle: float = atan2(float(destruction_wave.get("vy", 0.0)), float(destruction_wave.get("vx", 0.0)))
		beams.append_array(Stage4DestructionWavePayloadFactory.build_beam_particles(center, angle, 3, rng))
		destruction_wave["beam_particles"] = beams
	if lifetime_frames % 10 == 0:
		var rings: Array = _as_array(destruction_wave.get("energy_rings", []))
		rings.append(Stage4DestructionWavePayloadFactory.build_energy_ring(
			Vector2(
				float(destruction_wave.get("current_x", WAVE_START.x)),
				float(destruction_wave.get("current_y", WAVE_START.y))
			),
			float(destruction_wave.get("radius", 25.0))
		))
		destruction_wave["energy_rings"] = rings


func _update_destruction_wave_particles(fps_scale: float) -> void:
	var alive_trail: Array = []
	for particle_value in _as_array(destruction_wave.get("trail", [])):
		if particle_value is Dictionary:
			var particle := particle_value as Dictionary
			particle["life"] = float(particle.get("life", 0.0)) - fps_scale
			particle["size"] = float(particle.get("size", 0.0)) * pow(0.95, fps_scale)
			if float(particle.get("life", 0.0)) > 0.0 and float(particle.get("size", 0.0)) >= 1.0:
				alive_trail.append(particle)
	destruction_wave["trail"] = alive_trail
	var alive_beams: Array = []
	for beam_value in _as_array(destruction_wave.get("beam_particles", [])):
		if beam_value is Dictionary:
			var beam := beam_value as Dictionary
			beam["life"] = float(beam.get("life", 0.0)) - fps_scale
			beam["length"] = float(beam.get("length", 0.0)) * pow(0.98, fps_scale)
			if float(beam.get("life", 0.0)) > 0.0:
				alive_beams.append(beam)
	destruction_wave["beam_particles"] = alive_beams
	var alive_rings: Array = []
	for ring_value in _as_array(destruction_wave.get("energy_rings", [])):
		if ring_value is Dictionary:
			var ring := ring_value as Dictionary
			ring["radius"] = float(ring.get("radius", 0.0)) + 8.0 * fps_scale
			ring["opacity"] = float(ring.get("opacity", 0.0)) - (12.0 / 255.0) * fps_scale
			ring["life"] = float(ring.get("life", 0.0)) - fps_scale
			if float(ring.get("life", 0.0)) > 0.0 and float(ring.get("opacity", 0.0)) > 0.0:
				alive_rings.append(ring)
	destruction_wave["energy_rings"] = alive_rings


func _clear_collapse_payload() -> void:
	collapse_debris.clear()
	roof_fragments.clear()
	dust_clouds.clear()
	falling_lanterns.clear()
	ground_fires.clear()
	collapse_payload_started = false
	decorations_destroyed = false
	next_additional_debris_time = 0.0


func _start_collapse_payload() -> void:
	if collapse_payload_started:
		return
	collapse_payload_started = true
	decorations_destroyed = true
	next_additional_debris_time = ADDITIONAL_DEBRIS_INTERVAL_SEC
	_create_collapse_debris()
	_start_lanterns_falling()
	_explode_training_dummies()


func _update_collapse_payload(delta: float) -> void:
	var fps_scale: float = clampf(delta, 0.0, 0.1) * 60.0
	for debris_value in collapse_debris:
		if debris_value is Dictionary:
			_update_debris_piece(debris_value as Dictionary, fps_scale, DEBRIS_FADE_START_SEC)
	for roof_value in roof_fragments:
		if roof_value is Dictionary:
			_update_debris_piece(roof_value as Dictionary, fps_scale, ROOF_FADE_START_SEC)
	for dust_value in dust_clouds:
		if dust_value is Dictionary:
			_update_dust_cloud(dust_value as Dictionary, fps_scale)
	while next_additional_debris_time > 0.0 and phase_timer >= next_additional_debris_time and next_additional_debris_time < ADDITIONAL_DEBRIS_END_SEC:
		_create_additional_crush_debris()
		next_additional_debris_time += ADDITIONAL_DEBRIS_INTERVAL_SEC
	_update_falling_lanterns(fps_scale)
	_update_ground_fires(fps_scale)


func _update_debris_piece(debris: Dictionary, fps_scale: float, fade_start_sec: float) -> void:
	if phase_timer <= float(debris.get("delay", 0.0)):
		return
	debris["x"] = float(debris.get("x", 0.0)) + float(debris.get("vx", 0.0)) * fps_scale
	debris["y"] = float(debris.get("y", 0.0)) + float(debris.get("vy", 0.0)) * fps_scale
	debris["vy"] = float(debris.get("vy", 0.0)) + float(debris.get("gravity", 0.35)) * fps_scale
	debris["vx"] = float(debris.get("vx", 0.0)) * pow(float(debris.get("drag", 0.98)), fps_scale)
	debris["rotation"] = float(debris.get("rotation", 0.0)) + float(debris.get("rotation_speed", 0.0)) * fps_scale
	if float(debris.get("y", 0.0)) > FIELD_HEIGHT or phase_timer > fade_start_sec:
		debris["opacity"] = maxf(0.0, float(debris.get("opacity", 1.0)) - DEBRIS_OPACITY_FADE_PER_FRAME * fps_scale)


func _update_dust_cloud(dust: Dictionary, fps_scale: float) -> void:
	if phase_timer <= float(dust.get("delay", 0.0)):
		return
	var opacity: float = float(dust.get("opacity", 0.0))
	var max_opacity: float = float(dust.get("max_opacity", 0.55))
	if opacity < max_opacity:
		opacity = minf(max_opacity, opacity + (3.0 / 255.0) * fps_scale)
	dust["opacity"] = opacity
	dust["size"] = float(dust.get("size", 30.0)) + float(dust.get("expand_rate", 1.0)) * fps_scale
	dust["y"] = float(dust.get("y", 0.0)) + float(dust.get("rise_speed", -0.3)) * fps_scale
	if phase_timer > float(dust.get("delay", 0.0)) + 2.0:
		dust["opacity"] = maxf(0.0, float(dust.get("opacity", 0.0)) - (1.0 / 255.0) * fps_scale)


func _create_collapse_debris() -> void:
	collapse_debris.clear()
	roof_fragments.clear()
	dust_clouds.clear()
	_create_mapwide_burst_debris()
	var spire_y: float = TEMPLE_BASE_Y - PAGODA_LEVELS * 60.0 - 80.0
	for _idx in range(8):
		collapse_debris.append(_make_debris({
			"x": TEMPLE_X + float(rng.randi_range(-20, 20)),
			"y": spire_y + float(rng.randi_range(-40, 20)),
			"vx": rng.randf_range(-4.0, 4.0),
			"vy": rng.randf_range(-8.0, -2.0),
			"size": float(rng.randi_range(8, 20)),
			"rotation": rng.randf_range(0.0, 360.0),
			"rotation_speed": rng.randf_range(-10.0, 10.0),
			"type": "spire_ornament",
			"delay": 0.0,
		}))
	for level in range(PAGODA_LEVELS):
		var level_y: float = TEMPLE_BASE_Y - float(level) * 60.0
		var level_width: float = 200.0 - float(level) * 25.0
		for _tile_idx in range(12 - level * 2):
			roof_fragments.append(_make_debris({
				"x": TEMPLE_X + rng.randf_range(-level_width * 0.5, level_width * 0.5),
				"y": level_y - 50.0 + rng.randf_range(-10.0, 10.0),
				"vx": rng.randf_range(-6.0, 6.0),
				"vy": rng.randf_range(-5.0, 0.0),
				"size": float(rng.randi_range(10, 18)),
				"rotation": rng.randf_range(0.0, 360.0),
				"rotation_speed": rng.randf_range(-12.0, 12.0),
				"type": "roof_tile",
				"gravity": 0.3,
				"drag": 0.97,
				"delay": float(level * 15) / 60.0,
			}))
	for level in range(PAGODA_LEVELS):
		var level_y: float = TEMPLE_BASE_Y - float(level) * 60.0
		var level_width: float = 200.0 - float(level) * 25.0
		for _brick_idx in range(8 - level):
			var side: float = -1.0 if rng.randi_range(0, 1) == 0 else 1.0
			collapse_debris.append(_make_debris({
				"x": TEMPLE_X + side * rng.randf_range(level_width * 0.25, level_width * 0.5),
				"y": level_y - rng.randf_range(10.0, 40.0),
				"vx": side * rng.randf_range(2.0, 5.0),
				"vy": rng.randf_range(-3.0, 1.0),
				"size": float(rng.randi_range(8, 20)),
				"rotation": rng.randf_range(0.0, 360.0),
				"rotation_speed": rng.randf_range(-8.0, 8.0),
				"type": "brick",
				"delay": (float(level * 20) + float(rng.randi_range(0, 30))) / 60.0,
			}))
	for level in range(PAGODA_LEVELS):
		var level_y: float = TEMPLE_BASE_Y - float(level) * 60.0
		var level_width: float = 200.0 - float(level) * 25.0
		for side_value in [-1.0, 1.0]:
			collapse_debris.append(_make_debris({
				"x": TEMPLE_X + float(side_value) * (level_width * 0.5 - 15.0),
				"y": level_y - 25.0,
				"vx": float(side_value) * rng.randf_range(1.0, 3.0),
				"vy": rng.randf_range(-2.0, 0.0),
				"size": float(rng.randi_range(15, 25)),
				"rotation": rng.randf_range(0.0, 90.0),
				"rotation_speed": rng.randf_range(-5.0, 5.0),
				"type": "pillar_chunk",
				"delay": (float(level * 25) + 50.0) / 60.0,
			}))
	for level in range(1, 4):
		var level_y: float = TEMPLE_BASE_Y - float(level) * 60.0
		for side_value in [-1.0, 1.0]:
			collapse_debris.append(_make_debris({
				"x": TEMPLE_X + float(side_value) * 50.0,
				"y": level_y - 25.0,
				"vx": float(side_value) * rng.randf_range(2.0, 4.0),
				"vy": rng.randf_range(-4.0, -1.0),
				"size": float(rng.randi_range(12, 18)),
				"rotation": rng.randf_range(0.0, 360.0),
				"rotation_speed": rng.randf_range(-15.0, 15.0),
				"type": "window_lattice",
				"delay": (float(level * 30) + 20.0) / 60.0,
			}))
	for idx in range(4):
		collapse_debris.append(_make_debris({
			"x": TEMPLE_X + float(rng.randi_range(-25, 25)),
			"y": TEMPLE_BASE_Y - 30.0,
			"vx": rng.randf_range(-3.0, 3.0),
			"vy": rng.randf_range(-2.0, 1.0),
			"size": float(rng.randi_range(15, 25)),
			"rotation": rng.randf_range(0.0, 360.0),
			"rotation_speed": rng.randf_range(-6.0, 6.0),
			"type": "door_fragment",
			"delay": (80.0 + float(idx) * 10.0) / 60.0,
		}))
	for step in range(5):
		for _stone_idx in range(3):
			collapse_debris.append(_make_debris({
				"x": TEMPLE_X + float(rng.randi_range(-80, 80)),
				"y": TEMPLE_BASE_Y + float(step) * 12.0 + 5.0,
				"vx": rng.randf_range(-2.0, 2.0),
				"vy": rng.randf_range(-1.0, 0.0),
				"size": float(rng.randi_range(10, 20)),
				"rotation": rng.randf_range(0.0, 360.0),
				"rotation_speed": rng.randf_range(-4.0, 4.0),
				"type": "stone",
				"delay": (120.0 + float(step) * 15.0) / 60.0,
			}))
	for _dust_idx in range(15):
		dust_clouds.append(_make_dust_cloud(
			TEMPLE_X + float(rng.randi_range(-100, 100)),
			TEMPLE_BASE_Y + float(rng.randi_range(-50, 50)),
			float(rng.randi_range(30, 60)),
			float(rng.randi_range(80, 150)) / 255.0,
			rng.randf_range(0.5, 1.5),
			rng.randf_range(-0.5, -0.2),
			float(rng.randi_range(30, 120)) / 60.0
		))


func _create_mapwide_burst_debris() -> void:
	var origin := Vector2(TEMPLE_X, TEMPLE_BASE_Y - 120.0)
	var types := ["roof_tile", "brick", "wood_beam", "pillar_chunk", "spire_ornament", "window_lattice", "door_fragment", "stone"]
	for idx in range(MAPWIDE_BURST_DEBRIS_COUNT):
		var base_angle: float = TAU * float(idx) / float(MAPWIDE_BURST_DEBRIS_COUNT)
		var angle: float = base_angle + rng.randf_range(-0.16, 0.16)
		var side_boost: float = 1.35 if abs(cos(angle)) > 0.62 else 1.0
		var speed: float = rng.randf_range(14.0, 32.0) * side_boost
		var start_offset := Vector2(rng.randf_range(-46.0, 46.0), rng.randf_range(-52.0, 42.0))
		var debris_type: String = str(types[idx % types.size()])
		collapse_debris.append(_make_debris({
			"x": origin.x + start_offset.x,
			"y": origin.y + start_offset.y,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed - rng.randf_range(3.0, 9.0),
			"gravity": rng.randf_range(0.10, 0.22),
			"drag": rng.randf_range(0.992, 0.998),
			"size": float(rng.randi_range(8, 24)),
			"rotation": rng.randf_range(0.0, 360.0),
			"rotation_speed": rng.randf_range(-28.0, 28.0),
			"type": debris_type,
			"delay": rng.randf_range(0.0, 0.12),
			"mapwide_burst": true,
		}))


func _create_additional_crush_debris() -> void:
	var sink_offset: float = collapse_progress * 300.0
	var crush_factor: float = 1.0 - minf(1.0, maxf(0.0, (collapse_progress - 0.1) / 0.5)) * 0.6
	var num_debris: int = int(3.0 + (1.0 - crush_factor) * 10.0)
	for _idx in range(num_debris):
		var debris_type: String = _weighted_crush_debris_type()
		if debris_type == "dust":
			dust_clouds.append(_make_dust_cloud(
				TEMPLE_X + float(rng.randi_range(-80, 80)),
				TEMPLE_BASE_Y + sink_offset + float(rng.randi_range(-30, 30)),
				float(rng.randi_range(20, 40)),
				float(rng.randi_range(60, 100)) / 255.0,
				rng.randf_range(0.8, 2.0),
				rng.randf_range(-0.8, -0.3),
				0.0
			))
			continue
		var level: int = rng.randi_range(0, 4)
		var level_y: float = TEMPLE_BASE_Y - float(level) * 60.0 * crush_factor + sink_offset
		collapse_debris.append(_make_debris({
			"x": TEMPLE_X + float(rng.randi_range(-100, 100)),
			"y": level_y + float(rng.randi_range(-20, 20)),
			"vx": rng.randf_range(-3.0, 3.0),
			"vy": rng.randf_range(-2.0, 2.0),
			"size": float(rng.randi_range(6, 14)),
			"rotation": rng.randf_range(0.0, 360.0),
			"rotation_speed": rng.randf_range(-8.0, 8.0),
			"type": debris_type,
			"delay": 0.0,
		}))
	if rng.randf() < 0.3 and crush_factor < 0.8:
		for _tile_idx in range(2):
			roof_fragments.append(_make_debris({
				"x": TEMPLE_X + float(rng.randi_range(-60, 60)),
				"y": TEMPLE_BASE_Y - 200.0 * crush_factor + sink_offset,
				"vx": rng.randf_range(-4.0, 4.0),
				"vy": rng.randf_range(-3.0, 0.0),
				"size": float(rng.randi_range(8, 14)),
				"rotation": rng.randf_range(0.0, 360.0),
				"rotation_speed": rng.randf_range(-10.0, 10.0),
				"type": "roof_tile",
				"gravity": 0.3,
				"drag": 0.97,
				"delay": 0.0,
			}))


func _weighted_crush_debris_type() -> String:
	var roll: int = rng.randi_range(1, 100)
	if roll <= 30:
		return "brick"
	if roll <= 55:
		return "roof_tile"
	if roll <= 75:
		return "stone"
	if roll <= 85:
		return "pillar_chunk"
	return "dust"


func _start_lanterns_falling() -> void:
	falling_lanterns.clear()
	for lantern in LANTERN_ANCHORS:
		falling_lanterns.append(Stage4TempleCollapsePayloadFactory.make_falling_lantern(lantern, rng))


func _update_falling_lanterns(fps_scale: float) -> void:
	for lantern_value in falling_lanterns:
		if not (lantern_value is Dictionary):
			continue
		var lantern: Dictionary = lantern_value as Dictionary
		if bool(lantern.get("broken", false)):
			continue
		lantern["vy"] = float(lantern.get("vy", 0.0)) + 0.35 * fps_scale
		lantern["y"] = float(lantern.get("y", 0.0)) + float(lantern.get("vy", 0.0)) * fps_scale
		lantern["x"] = float(lantern.get("x", 0.0)) + float(lantern.get("vx", 0.0)) * fps_scale
		lantern["rotation"] = float(lantern.get("rotation", 0.0)) + float(lantern.get("rotation_speed", 0.0)) * 0.7 * fps_scale
		lantern["vx"] = float(lantern.get("vx", 0.0)) * pow(0.98, fps_scale)
		if float(lantern.get("y", 0.0)) >= float(lantern.get("ground_y", 650.0)):
			var bounce_count: int = int(lantern.get("bounce_count", 0))
			if bounce_count == 0:
				lantern["deformation"] = 0.5
				lantern["y"] = float(lantern.get("ground_y", 650.0))
				lantern["vy"] = -float(lantern.get("vy", 0.0)) * 0.3
				lantern["bounce_count"] = 1
				lantern["rotation_speed"] = float(lantern.get("rotation_speed", 0.0)) * 0.5
			elif bounce_count == 1 and float(lantern.get("vy", 0.0)) > 0.0:
				lantern["broken"] = true
				lantern["deformation"] = 0.3
				_create_ground_fire(float(lantern.get("x", 0.0)), float(lantern.get("ground_y", 650.0)))
				_create_lantern_debris(float(lantern.get("x", 0.0)), float(lantern.get("ground_y", 650.0)))
		if float(lantern.get("deformation", 0.0)) > 0.0:
			lantern["deformation"] = maxf(0.0, float(lantern.get("deformation", 0.0)) - 0.05 * fps_scale)


func _create_ground_fire(x: float, y: float) -> void:
	var fire := {"x": x, "y": y, "lifetime": 60.0, "particles": []}
	for _idx in range(20):
		(fire["particles"] as Array).append(_make_fire_particle(
			x + float(rng.randi_range(-20, 20)),
			y + float(rng.randi_range(-5, 5)),
			rng.randf_range(-2.0, 2.0),
			rng.randf_range(-3.0, -1.0),
			float(rng.randi_range(3, 8)),
			float(rng.randi_range(20, 40))
		))
	ground_fires.append(fire)


func _create_lantern_debris(x: float, y: float) -> void:
	for _idx in range(25):
		collapse_debris.append(_make_debris({
			"x": x,
			"y": y - 5.0,
			"vx": rng.randf_range(-8.0, 8.0),
			"vy": rng.randf_range(-6.0, -2.0),
			"size": float(rng.randi_range(2, 6)),
			"rotation": rng.randf_range(0.0, 360.0),
			"rotation_speed": rng.randf_range(-30.0, 30.0),
			"type": "glass",
			"delay": 0.0,
		}))
	for _idx in range(5):
		collapse_debris.append(_make_debris({
			"x": x,
			"y": y - 5.0,
			"vx": rng.randf_range(-6.0, 6.0),
			"vy": rng.randf_range(-4.0, -1.0),
			"size": float(rng.randi_range(6, 10)),
			"rotation": rng.randf_range(0.0, 360.0),
			"rotation_speed": rng.randf_range(-15.0, 15.0),
			"type": "wood_beam",
			"delay": 0.0,
		}))


func _update_ground_fires(fps_scale: float) -> void:
	var alive_fires: Array = []
	for fire_value in ground_fires:
		if not (fire_value is Dictionary):
			continue
		var fire: Dictionary = fire_value as Dictionary
		fire["lifetime"] = float(fire.get("lifetime", 0.0)) - fps_scale
		var particles: Array = []
		for particle_value in _as_array(fire.get("particles", [])):
			if not (particle_value is Dictionary):
				continue
			var particle: Dictionary = particle_value as Dictionary
			particle["y"] = float(particle.get("y", 0.0)) + float(particle.get("vy", 0.0)) * fps_scale
			particle["x"] = float(particle.get("x", 0.0)) + float(particle.get("vx", 0.0)) * fps_scale
			particle["vy"] = float(particle.get("vy", 0.0)) - 0.1 * fps_scale
			particle["life"] = float(particle.get("life", 0.0)) - fps_scale
			particle["size"] = maxf(1.0, float(particle.get("size", 1.0)) - 0.1 * fps_scale)
			if float(particle.get("life", 0.0)) > 0.0 and float(particle.get("size", 0.0)) > 0.0:
				particles.append(particle)
		fire["particles"] = particles
		if float(fire.get("lifetime", 0.0)) > 30.0 and particles.size() < 15:
			for _idx in range(3):
				particles.append(_make_fire_particle(
					float(fire.get("x", 0.0)) + float(rng.randi_range(-15, 15)),
					float(fire.get("y", 0.0)),
					rng.randf_range(-1.0, 1.0),
					rng.randf_range(-2.0, -0.5),
					float(rng.randi_range(3, 6)),
					float(rng.randi_range(15, 25))
				))
		if float(fire.get("lifetime", 0.0)) > 0.0 or particles.size() > 0:
			alive_fires.append(fire)
	ground_fires = alive_fires


func _explode_training_dummies() -> void:
	for pos in TRAINING_DUMMY_ANCHORS:
		for _idx in range(8):
			var angle: float = rng.randf_range(0.0, TAU)
			var speed: float = rng.randf_range(3.0, 8.0)
			collapse_debris.append(_make_debris({
				"x": pos.x,
				"y": pos.y,
				"vx": cos(angle) * speed,
				"vy": sin(angle) * speed - 3.0,
				"gravity": 0.3,
				"rotation": rng.randf_range(0.0, 360.0),
				"rotation_speed": rng.randf_range(-15.0, 15.0),
				"size": float(rng.randi_range(5, 12)),
				"type": "wood_beam",
				"delay": 0.0,
			}))
		dust_clouds.append(_make_dust_cloud(pos.x, pos.y, float(rng.randi_range(20, 38)), 0.45, rng.randf_range(0.7, 1.5), rng.randf_range(-0.5, -0.2), 0.0))


func _make_debris(data: Dictionary) -> Dictionary:
	return Stage4TempleCollapsePayloadFactory.make_debris(data, rng, DEBRIS_TYPE_SPRITE_VARIANTS)


func _make_dust_cloud(x: float, y: float, size: float, max_opacity: float, expand_rate: float, rise_speed: float, delay: float) -> Dictionary:
	return Stage4TempleCollapsePayloadFactory.make_dust_cloud(
		x,
		y,
		size,
		max_opacity,
		expand_rate,
		rise_speed,
		delay
	)


func _make_fire_particle(x: float, y: float, vx: float, vy: float, size: float, life: float) -> Dictionary:
	return Stage4TempleCollapsePayloadFactory.make_fire_particle(
		x,
		y,
		vx,
		vy,
		size,
		life,
		rng
	)


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []
