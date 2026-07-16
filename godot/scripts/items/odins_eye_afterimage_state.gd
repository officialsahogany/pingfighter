extends RefCounted

## Odin's Eye transformed afterimage (잔상) + dash dive (대쉬 다이브) state.
##
## Python parity source: legendary_items.py 6792-6801 / 6816-6834 (fields),
## 6928-7107 (dash dive), 7328-7791 (afterimage system). All timers are frames
## at the 60fps reference and all velocities are px/frame, matching the battle
## ball and the dark-swamp sibling. Alpha values stay on the legacy 0..255
## scale inside the payload dicts; the presentation renderer normalizes.

const REFERENCE_FPS := 60.0

# --- 잔상 (afterimage) constants: legendary_items.py:6793-6801 ---
const AFTERIMAGE_HOLD_FRAMES := 60.0
const AFTERIMAGE_FADE_FRAMES := 30.0
const AFTERIMAGE_HIT_FRAMES := 45.0
const AFTERIMAGE_SPAWN_INTERVAL_FRAMES := 6.0
const AFTERIMAGE_MIN_SPAWN_MOVE_PX := 10.0
const AFTERIMAGE_INITIAL_ALPHA := 200.0
const AFTERIMAGE_HIT_COOLDOWN_EXTRA_FRAMES := 10.0

# --- 잔상 반사 (ball reflection) constants: legendary_items.py:7717-7745 ---
const BALL_MIN_REFLECT_SPEED := 4.0
const BALL_MAX_REFLECT_SPEED := 14.0
const BALL_MIN_SPEED_BOOST := 1.0
const BALL_MAX_SPEED_BOOST := 1.1
const BALL_MAX_REFLECT_ANGLE := PI / 3.0
# Hitbox: paddle-wide box centered 60px above the anchor (silhouette center),
# 50px tall — legendary_items.py:7701-7705.
const HITBOX_CENTER_Y_OFFSET := -60.0
const HITBOX_HEIGHT := 50.0
const HIT_GAUGE_GAIN := 50.0

# --- 대쉬 다이브 constants: legendary_items.py:6825-6831, 7009-7013 ---
const DIVE_SINK_FRAMES := 8.0
const DIVE_EMERGE_FRAMES := 12.0
const DIVE_TRAIL_INTERVAL_FRAMES := 2.0
const DIVE_TRAIL_MAX_TIMER_FRAMES := 30.0
const DIVE_AFTERIMAGE_WIDTH := 155.0
const DIVE_AFTERIMAGE_HEIGHT := 25.0
const DIVE_SINK_MAX_OFFSET_Y := 120.0

const BURST_PARTICLE_GRAVITY_PER_FRAME := 0.12
const BURST_PARTICLE_DRAG_PER_FRAME := 0.95

# --- 상시 어둠 입자 (transformed-form ambient motes,
# legendary_items.py:10168-10196). Positions are LEGACY BODY-LOCAL coords on
# the 180x185 surface (head at x=90, y=36) so they follow the paddle, the
# dive offset, and the dark-swamp spin in the renderer. ---
const AMBIENT_PARTICLE_LIMIT := 14
const AMBIENT_SPAWN_CHANCE := 0.5
const AMBIENT_ANCHOR := Vector2(90.0, 61.0)
const SOUL_PARTICLE_BUOYANCY_PER_FRAME := 0.05
const SOUL_PARTICLE_DRAG_PER_FRAME := 0.98
const SOUL_PARTICLE_ALPHA_DECAY := 0.95

# Dark-purple burst palette: legendary_items.py:7153-7159.
const BURST_COLORS: Array[Color] = [
	Color(30.0 / 255.0, 15.0 / 255.0, 50.0 / 255.0),
	Color(50.0 / 255.0, 25.0 / 255.0, 80.0 / 255.0),
	Color(20.0 / 255.0, 10.0 / 255.0, 35.0 / 255.0),
	Color(40.0 / 255.0, 20.0 / 255.0, 65.0 / 255.0),
	Color(60.0 / 255.0, 30.0 / 255.0, 90.0 / 255.0),
]

var afterimages: Array[Dictionary] = []
var soul_particles: Array[Dictionary] = []
var afterimage_spawn_cooldown_frames := 0.0
var afterimage_hit_cooldown_frames := 0.0
var last_afterimage_pos := Vector2.ZERO

var dive_active := false
var dive_sink_phase := false
var dive_underground_phase := false
var dive_emerge_phase := false
var dive_sink_timer_frames := 0.0
var dive_emerge_timer_frames := 0.0
var dive_sink_pos := Vector2.ZERO
var dive_trail: Array[Dictionary] = []
var dive_trail_spawn_cooldown_frames := 0.0
var dive_ground_cracks: Array[Dictionary] = []
var dive_burst_particles: Array[Dictionary] = []
var dive_ground_ripples: Array[Dictionary] = []

var ambient_particles: Array[Dictionary] = []

var _prev_dash_active := false
var _frame_accumulator_frames := 0.0
var _ambient_clock_frames := 0.0
var _last_player_center := Vector2.ZERO
var _has_last_player_center := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func set_random_seed(value: int) -> void:
	_rng.seed = value


func clear_all() -> void:
	clear_afterimages()
	_reset_dash_dive()
	ambient_particles.clear()
	_prev_dash_active = false
	_frame_accumulator_frames = 0.0
	_ambient_clock_frames = 0.0
	_has_last_player_center = false


func reset_round() -> void:
	# Python parity: go_to_next_round clears the afterimages (:182122) and
	# reset_for_new_round resets the dash dive (:6922).
	clear_all()


func clear_afterimages() -> void:
	# legendary_items.py:7784-7791.
	afterimages.clear()
	soul_particles.clear()
	afterimage_spawn_cooldown_frames = 0.0
	afterimage_hit_cooldown_frames = 0.0
	last_afterimage_pos = Vector2.ZERO


func has_runtime_update_work() -> bool:
	return (
		dive_active
		or not afterimages.is_empty()
		or not soul_particles.is_empty()
		or not dive_trail.is_empty()
		or not dive_ground_cracks.is_empty()
		or not dive_burst_particles.is_empty()
		or not dive_ground_ripples.is_empty()
		or not ambient_particles.is_empty()
		or afterimage_spawn_cooldown_frames > 0.0
		or afterimage_hit_cooldown_frames > 0.0
	)


## Per-tick driver. `params` keys: player_center (Vector2), paddle_width,
## paddle_height (float), moving (bool), dash_active (bool), anim_blocked
## (bool — revival / death cinematic; cancels the dive and blocks dive start).
func update(delta_sec: float, params: Dictionary) -> bool:
	var safe_delta_sec: float = maxf(0.0, delta_sec)
	if not has_runtime_update_work() and safe_delta_sec <= 0.0:
		return false
	_frame_accumulator_frames += safe_delta_sec * REFERENCE_FPS
	var frames_to_step := int(floor(_frame_accumulator_frames + 0.000001))
	if frames_to_step <= 0:
		return false
	_frame_accumulator_frames -= float(frames_to_step)
	var player_center: Vector2 = _as_vector2(params.get("player_center", Vector2.ZERO))
	var paddle_width: float = maxf(1.0, float(params.get("paddle_width", 155.0)))
	var paddle_height: float = maxf(1.0, float(params.get("paddle_height", 50.0)))
	var moving: bool = bool(params.get("moving", false))
	var dash_active: bool = bool(params.get("dash_active", false))
	var anim_blocked: bool = bool(params.get("anim_blocked", false))
	var revival_active: bool = bool(params.get("revival_active", false))
	for _frame_index in range(frames_to_step):
		_update_one_frame(player_center, paddle_width, paddle_height, moving, dash_active, anim_blocked, revival_active)
	return true


func _update_one_frame(
	player_center: Vector2,
	paddle_width: float,
	paddle_height: float,
	moving: bool,
	dash_active: bool,
	anim_blocked: bool,
	revival_active: bool = false
) -> void:
	# Dash edge -> dive start. Python fires start_dash_dive at every dash
	# entry site (pingfighter.py:104009/:109711/:109991/:110289); the mythic
	# tick observes the shared dash state instead, so the edge lands one frame
	# after the dash but drives the identical phase machine.
	if dash_active and not _prev_dash_active and not anim_blocked:
		start_dash_dive(player_center)
	_prev_dash_active = dash_active

	_update_ambient_particles_one_frame(player_center, revival_active)
	_update_afterimages_one_frame()

	if dive_active:
		_update_dash_dive_one_frame(player_center, dash_active, anim_blocked)
	else:
		_update_dive_effects_one_frame()

	# Movement afterimages skip while diving (pingfighter.py:205134).
	if moving and not dive_active:
		create_afterimage(player_center, paddle_width, paddle_height)


func _update_ambient_particles_one_frame(player_center: Vector2, revival_active: bool = false) -> void:
	# legendary_items.py:10168-10196 — rising dark motes around the body.
	# The legacy spawn lived inside draw_dark_paddle, which early-returns for
	# the REVIVAL cinematic only (death keeps drawing the body), so revival
	# pauses new spawns while existing motes keep aging out.
	var ambient_t: float = _ambient_clock_frames / REFERENCE_FPS * 0.8
	_ambient_clock_frames += 1.0
	var player_vx: float = 0.0
	if _has_last_player_center:
		player_vx = player_center.x - _last_player_center.x
	_last_player_center = player_center
	_has_last_player_center = true

	if not revival_active and ambient_particles.size() < AMBIENT_PARTICLE_LIMIT and _rng.randf() < AMBIENT_SPAWN_CHANCE:
		var spawn_angle: float = _rng.randf_range(0.0, TAU)
		var spawn_dist: float = _rng.randf_range(22.0, 55.0)
		ambient_particles.append({
			"x": AMBIENT_ANCHOR.x + cos(spawn_angle) * spawn_dist,
			"y": AMBIENT_ANCHOR.y + sin(spawn_angle) * spawn_dist * 0.8,
			"vx": _rng.randf_range(-0.3, 0.3) + player_vx * 0.01,
			"vy": _rng.randf_range(-0.65, -0.15),
			"size": _rng.randf_range(1.5, 3.2),
			"life": float(_rng.randi_range(30, 60)),
			"max_life": 60.0,
			"color_type": _rng.randi_range(0, 3),
		})

	for index in range(ambient_particles.size() - 1, -1, -1):
		var particle: Dictionary = ambient_particles[index]
		particle["x"] = (
			float(particle["x"]) + float(particle["vx"])
			+ sin(ambient_t * 4.0 + float(particle["life"]) * 0.1) * 0.15
		)
		particle["y"] = float(particle["y"]) + float(particle["vy"])
		particle["life"] = float(particle["life"]) - 1.0
		if float(particle["life"]) <= 0.0:
			ambient_particles.remove_at(index)


# ==================== 👻 잔상 시스템 ====================

func create_afterimage(player_center: Vector2, paddle_width: float, paddle_height: float) -> void:
	# legendary_items.py:7330-7359.
	if afterimage_spawn_cooldown_frames > 0.0:
		return
	if (
		absf(player_center.x - last_afterimage_pos.x) < AFTERIMAGE_MIN_SPAWN_MOVE_PX
		and absf(player_center.y - last_afterimage_pos.y) < AFTERIMAGE_MIN_SPAWN_MOVE_PX
	):
		return
	afterimages.append(_make_afterimage(player_center, paddle_width, paddle_height))
	afterimage_spawn_cooldown_frames = AFTERIMAGE_SPAWN_INTERVAL_FRAMES
	last_afterimage_pos = player_center


func _make_afterimage(pos: Vector2, width: float, height: float) -> Dictionary:
	return {
		"x": pos.x,
		"y": pos.y,
		"width": width,
		"height": height,
		"timer": 0.0,
		"alpha": AFTERIMAGE_INITIAL_ALPHA,
		"phase": "hold",
		"glow_offset": 0.0,
		"hit_timer": 0.0,
		"dissolve_offset": 0.0,
	}


func _update_afterimages_one_frame() -> void:
	# legendary_items.py:7364-7440.
	if afterimage_spawn_cooldown_frames > 0.0:
		afterimage_spawn_cooldown_frames -= 1.0
	if afterimage_hit_cooldown_frames > 0.0:
		afterimage_hit_cooldown_frames -= 1.0

	for index in range(afterimages.size() - 1, -1, -1):
		var afterimage: Dictionary = afterimages[index]
		afterimage["timer"] = float(afterimage["timer"]) + 1.0
		afterimage["glow_offset"] = sin(float(afterimage["timer"]) * 0.15) * 5.0

		if str(afterimage["phase"]) == "hit":
			afterimage["hit_timer"] = float(afterimage["hit_timer"]) + 1.0
			var hit_progress: float = float(afterimage["hit_timer"]) / AFTERIMAGE_HIT_FRAMES
			afterimage["dissolve_offset"] = hit_progress * 40.0
			afterimage["alpha"] = 200.0 * (1.0 - hit_progress * 1.2)
			if float(afterimage["hit_timer"]) < 30.0 and _rng.randf() < 0.6:
				var soul_anchor := Vector2(float(afterimage["x"]), float(afterimage["y"]) - 60.0)
				for _soul_index in range(2):
					soul_particles.append({
						"x": soul_anchor.x + _rng.randf_range(-20.0, 20.0),
						"y": soul_anchor.y + _rng.randf_range(-30.0, 10.0) - float(afterimage["dissolve_offset"]),
						"vx": _rng.randf_range(-1.5, 1.5),
						"vy": _rng.randf_range(-4.0, -1.5),
						"size": _rng.randf_range(4.0, 12.0),
						"life": float(_rng.randi_range(30, 60)),
						"max_life": 60.0,
						"type": ["soul", "smoke", "wisp"][_rng.randi_range(0, 2)],
						"rotation": _rng.randf_range(0.0, TAU),
						"rot_speed": _rng.randf_range(-0.1, 0.1),
						"alpha": float(_rng.randi_range(150, 220)),
					})
			if float(afterimage["hit_timer"]) >= AFTERIMAGE_HIT_FRAMES:
				afterimages.remove_at(index)
			continue

		if str(afterimage["phase"]) == "hold" and float(afterimage["timer"]) >= AFTERIMAGE_HOLD_FRAMES:
			afterimage["phase"] = "fade"
		if str(afterimage["phase"]) == "fade":
			var fade_progress: float = (
				(float(afterimage["timer"]) - AFTERIMAGE_HOLD_FRAMES) / AFTERIMAGE_FADE_FRAMES
			)
			afterimage["alpha"] = 200.0 * (1.0 - fade_progress)
			if float(afterimage["alpha"]) <= 0.0:
				afterimages.remove_at(index)

	for index in range(soul_particles.size() - 1, -1, -1):
		var particle: Dictionary = soul_particles[index]
		particle["x"] = float(particle["x"]) + float(particle["vx"])
		particle["y"] = float(particle["y"]) + float(particle["vy"])
		particle["vy"] = float(particle["vy"]) - SOUL_PARTICLE_BUOYANCY_PER_FRAME
		particle["vx"] = float(particle["vx"]) * SOUL_PARTICLE_DRAG_PER_FRAME
		particle["rotation"] = float(particle["rotation"]) + float(particle["rot_speed"])
		particle["life"] = float(particle["life"]) - 1.0
		particle["alpha"] = float(particle["alpha"]) * SOUL_PARTICLE_ALPHA_DECAY
		if float(particle["life"]) <= 0.0 or float(particle["alpha"]) <= 5.0:
			soul_particles.remove_at(index)


## Ball reflection (legendary_items.py:7672-7782). The caller gates on a
## descending ball (ball_vel.y > 0, pingfighter.py:205138) and applies the
## returned velocity plus last-hit / rally / gauge / audio side effects.
func check_ball_collision(ball_center: Vector2, ball_radius: float, ball_vel: Vector2) -> Dictionary:
	var miss := {"hit": false, "new_velocity": ball_vel, "hit_pos": Vector2.ZERO}
	if afterimage_hit_cooldown_frames > 0.0:
		return miss
	for afterimage in afterimages:
		if str(afterimage["phase"]) == "hit":
			# One soul-escape at a time (legendary_items.py:7687-7690).
			return miss
	for afterimage in afterimages:
		var anchor_x: float = float(afterimage["x"])
		var width: float = maxf(1.0, float(afterimage["width"]))
		var hitbox := Rect2(
			anchor_x - width * 0.5,
			float(afterimage["y"]) + HITBOX_CENTER_Y_OFFSET,
			width,
			HITBOX_HEIGHT
		)
		var closest := Vector2(
			clampf(ball_center.x, hitbox.position.x, hitbox.position.x + hitbox.size.x),
			clampf(ball_center.y, hitbox.position.y, hitbox.position.y + hitbox.size.y)
		)
		if ball_center.distance_to(closest) > ball_radius:
			continue

		var current_speed: float = maxf(ball_vel.length(), BALL_MIN_REFLECT_SPEED)
		var hit_offset: float = clampf((ball_center.x - anchor_x) / (width * 0.5), -1.0, 1.0)
		var angle: float = hit_offset * BALL_MAX_REFLECT_ANGLE
		var direction: float = -1.0 if ball_vel.y > 0.0 else 1.0
		var boosted_speed: float = minf(
			current_speed * _rng.randf_range(BALL_MIN_SPEED_BOOST, BALL_MAX_SPEED_BOOST),
			BALL_MAX_REFLECT_SPEED
		)
		var new_velocity := Vector2(-sin(angle) * direction, cos(angle) * direction) * boosted_speed

		afterimage["phase"] = "hit"
		afterimage["hit_timer"] = 0.0
		afterimage["dissolve_offset"] = 0.0
		afterimage_hit_cooldown_frames = AFTERIMAGE_HIT_FRAMES + AFTERIMAGE_HIT_COOLDOWN_EXTRA_FRAMES

		# Initial soul burst (legendary_items.py:7758-7775).
		var soul_center := Vector2(anchor_x, float(afterimage["y"]) - 60.0)
		for _burst_index in range(15):
			var burst_angle: float = _rng.randf_range(0.0, TAU)
			var burst_speed: float = _rng.randf_range(2.0, 6.0)
			soul_particles.append({
				"x": soul_center.x + _rng.randf_range(-15.0, 15.0),
				"y": soul_center.y + _rng.randf_range(-25.0, 15.0),
				"vx": cos(burst_angle) * burst_speed * 0.5,
				"vy": -absf(sin(burst_angle) * burst_speed) - 2.0,
				"size": _rng.randf_range(5.0, 14.0),
				"life": float(_rng.randi_range(35, 70)),
				"max_life": 70.0,
				"type": ["soul", "soul", "smoke", "wisp"][_rng.randi_range(0, 3)],
				"rotation": _rng.randf_range(0.0, TAU),
				"rot_speed": _rng.randf_range(-0.15, 0.15),
				"alpha": float(_rng.randi_range(180, 255)),
			})
		return {
			"hit": true,
			"new_velocity": new_velocity,
			"hit_pos": Vector2(anchor_x, float(afterimage["y"])),
		}
	return miss


# ==================== 🌑 대쉬 다이브 시스템 ====================

func start_dash_dive(player_center: Vector2) -> void:
	# legendary_items.py:6944-6973 (transform / cinematic gates live at the
	# caller; the consecutive-dash emerge cancel lives here).
	if dive_active:
		dive_emerge_phase = false
		dive_emerge_timer_frames = 0.0
	dive_active = true
	dive_sink_phase = true
	dive_underground_phase = false
	dive_emerge_phase = false
	dive_sink_timer_frames = 0.0
	dive_emerge_timer_frames = 0.0
	dive_sink_pos = player_center
	dive_trail.clear()
	dive_trail_spawn_cooldown_frames = 0.0
	_spawn_ground_cracks(player_center, 5)
	_spawn_ground_ripple(player_center)
	_spawn_dive_particles(player_center, false)


func end_dash_dive(player_center: Vector2) -> void:
	# legendary_items.py:7037-7047.
	dive_sink_phase = false
	dive_underground_phase = false
	dive_emerge_phase = true
	dive_emerge_timer_frames = 0.0
	_spawn_ground_cracks(player_center, 8)
	_spawn_ground_ripple(player_center)
	_spawn_dive_particles(player_center, true)


func is_dash_diving() -> bool:
	return dive_active


func _reset_dash_dive() -> void:
	# legendary_items.py:6930-6942.
	dive_active = false
	dive_sink_phase = false
	dive_underground_phase = false
	dive_emerge_phase = false
	dive_sink_timer_frames = 0.0
	dive_emerge_timer_frames = 0.0
	dive_trail.clear()
	dive_trail_spawn_cooldown_frames = 0.0
	dive_ground_cracks.clear()
	dive_burst_particles.clear()
	dive_ground_ripples.clear()


func _update_dash_dive_one_frame(player_center: Vector2, dash_active: bool, anim_blocked: bool) -> void:
	# legendary_items.py:6975-7035.
	if anim_blocked:
		_reset_dash_dive()
		return
	if dive_sink_phase:
		dive_sink_timer_frames += 1.0
		if dive_sink_timer_frames >= DIVE_SINK_FRAMES:
			dive_sink_phase = false
			dive_underground_phase = true
	elif dive_underground_phase:
		if dash_active:
			dive_trail_spawn_cooldown_frames -= 1.0
			if dive_trail_spawn_cooldown_frames <= 0.0:
				dive_trail.append({
					"x": player_center.x,
					"y": player_center.y,
					"alpha": 200.0,
					"timer": 0.0,
					"max_timer": DIVE_TRAIL_MAX_TIMER_FRAMES,
				})
				# Underground path afterimages bypass the movement spawn
				# cooldown (legendary_items.py:7009-7020).
				afterimages.append(_make_afterimage(
					player_center,
					DIVE_AFTERIMAGE_WIDTH,
					DIVE_AFTERIMAGE_HEIGHT
				))
				dive_trail_spawn_cooldown_frames = DIVE_TRAIL_INTERVAL_FRAMES
		else:
			end_dash_dive(player_center)
	elif dive_emerge_phase:
		dive_emerge_timer_frames += 1.0
		if dive_emerge_timer_frames >= DIVE_EMERGE_FRAMES:
			dive_emerge_phase = false
			dive_active = false
	_update_dive_effects_one_frame()


func _update_dive_effects_one_frame() -> void:
	# legendary_items.py:7162-7194.
	for index in range(dive_trail.size() - 1, -1, -1):
		var trail: Dictionary = dive_trail[index]
		trail["timer"] = float(trail["timer"]) + 1.0
		trail["alpha"] = 200.0 * (1.0 - float(trail["timer"]) / maxf(1.0, float(trail["max_timer"])))
		if float(trail["timer"]) >= float(trail["max_timer"]) or float(trail["alpha"]) <= 0.0:
			dive_trail.remove_at(index)

	for index in range(dive_ground_cracks.size() - 1, -1, -1):
		var crack: Dictionary = dive_ground_cracks[index]
		crack["timer"] = float(crack["timer"]) + 1.0
		if float(crack["timer"]) >= float(crack["max_timer"]):
			dive_ground_cracks.remove_at(index)

	for index in range(dive_ground_ripples.size() - 1, -1, -1):
		var ripple: Dictionary = dive_ground_ripples[index]
		ripple["timer"] = float(ripple["timer"]) + 1.0
		var progress: float = float(ripple["timer"]) / maxf(1.0, float(ripple["max_timer"]))
		ripple["radius"] = 5.0 + (float(ripple["max_radius"]) - 5.0) * progress
		ripple["alpha"] = 220.0 * (1.0 - progress)
		if float(ripple["timer"]) >= float(ripple["max_timer"]):
			dive_ground_ripples.remove_at(index)

	for index in range(dive_burst_particles.size() - 1, -1, -1):
		var particle: Dictionary = dive_burst_particles[index]
		particle["x"] = float(particle["x"]) + float(particle["vx"])
		particle["y"] = float(particle["y"]) + float(particle["vy"])
		particle["vy"] = float(particle["vy"]) + BURST_PARTICLE_GRAVITY_PER_FRAME
		particle["vx"] = float(particle["vx"]) * BURST_PARTICLE_DRAG_PER_FRAME
		particle["life"] = float(particle["life"]) - 1.0
		if float(particle["life"]) <= 0.0:
			dive_burst_particles.remove_at(index)


func _spawn_ground_cracks(pos: Vector2, count: int) -> void:
	# legendary_items.py:7111-7124.
	for _crack_index in range(count):
		dive_ground_cracks.append({
			"x": pos.x,
			"y": pos.y,
			"angle": _rng.randf_range(0.0, TAU),
			"length": _rng.randf_range(15.0, 45.0),
			"timer": 0.0,
			"max_timer": float(_rng.randi_range(20, 40)),
			"width": float(_rng.randi_range(1, 3)),
		})


func _spawn_ground_ripple(pos: Vector2) -> void:
	# legendary_items.py:7126-7135.
	dive_ground_ripples.append({
		"x": pos.x,
		"y": pos.y,
		"radius": 5.0,
		"max_radius": 65.0,
		"alpha": 220.0,
		"timer": 0.0,
		"max_timer": 25.0,
	})


func _spawn_dive_particles(pos: Vector2, upward: bool) -> void:
	# legendary_items.py:7137-7160.
	var count := 18 if upward else 12
	for _particle_index in range(count):
		var angle: float = _rng.randf_range(0.0, TAU)
		var speed: float = _rng.randf_range(2.0, 7.0) if upward else _rng.randf_range(1.0, 4.0)
		var vy_base: float = -_rng.randf_range(2.0, 6.0) if upward else _rng.randf_range(1.0, 3.0)
		dive_burst_particles.append({
			"x": pos.x + _rng.randf_range(-20.0, 20.0),
			"y": pos.y + _rng.randf_range(-5.0, 5.0),
			"vx": cos(angle) * speed,
			"vy": vy_base,
			"size": _rng.randf_range(3.0, 9.0),
			"life": float(_rng.randi_range(15, 40)),
			"max_life": 40.0,
			"color": BURST_COLORS[_rng.randi_range(0, BURST_COLORS.size() - 1)],
		})


func should_hide_player_for_dive() -> bool:
	# legendary_items.py:7053-7066.
	if not dive_active:
		return false
	if dive_sink_phase and dive_sink_timer_frames >= DIVE_SINK_FRAMES / 2.0:
		return true
	if dive_underground_phase:
		return true
	if dive_emerge_phase and dive_emerge_timer_frames < DIVE_EMERGE_FRAMES * 0.25:
		return true
	return false


## Paddle visual params during the dive (legendary_items.py:7068-7107).
## `alpha` is normalized to 0..1 for the renderer opacity multiplier.
func get_dive_visual_params() -> Dictionary:
	if not dive_active:
		return {"active": false, "offset_y": 0.0, "alpha": 1.0, "visible": true}
	if dive_sink_phase:
		var sink_progress: float = dive_sink_timer_frames / maxf(1.0, DIVE_SINK_FRAMES)
		var sink_ease: float = sink_progress * sink_progress
		return {
			"active": true,
			"offset_y": DIVE_SINK_MAX_OFFSET_Y * sink_ease,
			"alpha": maxf(0.0, 1.0 - sink_ease * 1.5),
			"visible": sink_ease < 0.85,
		}
	if dive_underground_phase:
		return {"active": true, "offset_y": DIVE_SINK_MAX_OFFSET_Y, "alpha": 0.0, "visible": false}
	if dive_emerge_phase:
		var emerge_progress: float = dive_emerge_timer_frames / maxf(1.0, DIVE_EMERGE_FRAMES)
		var emerge_ease: float = 1.0 - (1.0 - emerge_progress) * (1.0 - emerge_progress)
		return {
			"active": true,
			"offset_y": DIVE_SINK_MAX_OFFSET_Y * (1.0 - emerge_ease),
			"alpha": minf(1.0, emerge_progress * 2.5),
			"visible": true,
		}
	return {"active": true, "offset_y": 0.0, "alpha": 1.0, "visible": true}


func get_context() -> Dictionary:
	return {
		"afterimages": afterimages.duplicate(true),
		"soul_particles": soul_particles.duplicate(true),
		"ambient_particles": ambient_particles.duplicate(true),
		"trail": dive_trail.duplicate(true),
		"ground_cracks": dive_ground_cracks.duplicate(true),
		"ground_ripples": dive_ground_ripples.duplicate(true),
		"burst_particles": dive_burst_particles.duplicate(true),
		"dive_active": dive_active,
		"dive_visual": get_dive_visual_params(),
	}


func _as_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO
