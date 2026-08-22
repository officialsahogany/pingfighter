extends RefCounted
## 대성영단 (호환 ID: elixir_of_mastery)
## 신화급 액티브 아이템 - 복용 시 보유 성장형 무공 중 하나를 카탈로그 상한으로
## 시네마틱 연출: 화면 정지 → 3초 빌드업 → 결과 공개 → 축하 → 확인 대기

const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkProgression := preload("res://scripts/characters/runtime_perk_progression.gd")

const BUILDUP_DURATION := 3.0
const REVEAL_DURATION := 1.5
const CINEMATIC_PARTICLE_COUNT := 60
const RUNE_CIRCLE_COUNT := 3
const SPARKLE_BURST_COUNT := 80
const CONFETTI_COUNT := 140

enum Phase { INACTIVE, BUILDUP, REVEAL, CELEBRATION }

var active := false
var cinematic_active := false
var cinematic_phase: int = Phase.INACTIVE
var cinematic_timer := 0.0
var waiting_for_confirm := false

var selected_perk_id := ""
var selected_perk_data: Dictionary = {}
var old_level := 0
var target_level := 0

var bottle_rotation := 0.0
var bottle_scale := 1.0
var flash_alpha := 0.0
var result_alpha := 0.0
var particles: Array = []
var rune_circles: Array = []
var sparkles: Array = []
var confetti: Array = []
var fireworks: Array = []
var shockwaves: Array = []
var rays_rotation := 0.0
var banner_progress := 0.0
var level5_impact_scale := 1.0
var icon_breath_scale := 1.0
var celebration_triggered := false
var celebration_timer := 0.0
var _fireworks_queue: Array = []


func reset() -> void:
	active = false
	cinematic_active = false
	cinematic_phase = Phase.INACTIVE
	cinematic_timer = 0.0
	waiting_for_confirm = false
	selected_perk_id = ""
	selected_perk_data = {}
	old_level = 0
	target_level = 0
	bottle_rotation = 0.0
	bottle_scale = 1.0
	flash_alpha = 0.0
	result_alpha = 0.0
	particles.clear()
	rune_circles.clear()
	sparkles.clear()
	confetti.clear()
	fireworks.clear()
	shockwaves.clear()
	rays_rotation = 0.0
	banner_progress = 0.0
	level5_impact_scale = 1.0
	icon_breath_scale = 1.0
	celebration_triggered = false
	celebration_timer = 0.0
	_fireworks_queue.clear()


func get_eligible_perks(runtime_skill_levels: Dictionary, all_skill_pools: Array) -> Array:
	var eligible: Array = []
	for pool in all_skill_pools:
		if not (pool is Dictionary):
			continue
		for skill_id in pool:
			var skill_data: Dictionary = pool[skill_id] if pool[skill_id] is Dictionary else {}
			var mastery_level := get_mastery_target_level(str(skill_id), skill_data)
			if mastery_level <= 0:
				continue
			var current: int = int(runtime_skill_levels.get(skill_id, 0))
			if current > 0 and current < mastery_level:
				eligible.append({
					"id": skill_id,
					"data": skill_data,
					"current_level": current,
					"target_level": mastery_level,
				})
	return eligible


# GRT-054: the eligible family is canonical by perk identity while the target
# itself comes from that perk's catalog max_level. S2 therefore keeps today's
# 37 Mugong + 10 unbounded-training candidates byte-for-byte, and S3 can lower
# only the 37 catalog caps without making the item silently exclude them.
static func get_mastery_target_level(skill_id: String, skill_data: Dictionary) -> int:
	var clean_id := skill_id.strip_edges()
	if not RuntimePerkProgression.has_perk(clean_id) and not RuntimePerkCatalog.TRAINING_MIGRATED_PERK_IDS.has(clean_id):
		return 0
	return maxi(0, int(skill_data.get("max_level", 0)))


func activate(
	runtime_skill_levels: Dictionary,
	all_skill_pools: Array,
	apply_skill_func: Callable
) -> bool:
	var eligible: Array = get_eligible_perks(runtime_skill_levels, all_skill_pools)
	if eligible.is_empty():
		return false

	var chosen: Dictionary = eligible[randi() % eligible.size()]
	selected_perk_id = str(chosen.get("id", ""))
	selected_perk_data = chosen.get("data", {}) if chosen.get("data") is Dictionary else {}
	old_level = int(chosen.get("current_level", 0))
	target_level = int(chosen.get("target_level", 0))

	var levels_to_add: int = target_level - old_level
	for _i in range(levels_to_add):
		if apply_skill_func.is_valid():
			apply_skill_func.call(selected_perk_id)

	cinematic_active = true
	cinematic_phase = Phase.BUILDUP
	cinematic_timer = 0.0
	active = true
	_init_particles()
	return true


func should_pause_game() -> bool:
	return cinematic_active


func update(dt: float) -> void:
	if not cinematic_active:
		return
	cinematic_timer += dt
	match cinematic_phase:
		Phase.BUILDUP:
			_update_buildup(dt)
		Phase.REVEAL:
			_update_reveal(dt)
		Phase.CELEBRATION:
			_update_celebration(dt)


func handle_confirm() -> bool:
	if not waiting_for_confirm:
		return false
	_finish_cinematic()
	return true


func get_draw_context() -> Dictionary:
	return {
		"active": cinematic_active,
		"phase": cinematic_phase,
		"timer": cinematic_timer,
		"bottle_rotation": bottle_rotation,
		"bottle_scale": bottle_scale,
		"flash_alpha": flash_alpha,
		"result_alpha": result_alpha,
		"particles": particles,
		"rune_circles": rune_circles,
		"sparkles": sparkles,
		"confetti": confetti,
		"fireworks": fireworks,
		"shockwaves": shockwaves,
		"rays_rotation": rays_rotation,
		"banner_progress": banner_progress,
		"level5_impact_scale": level5_impact_scale,
		"icon_breath_scale": icon_breath_scale,
		"celebration_triggered": celebration_triggered,
		"celebration_timer": celebration_timer,
		"waiting_for_confirm": waiting_for_confirm,
		"selected_perk_id": selected_perk_id,
		"selected_perk_data": selected_perk_data,
		"old_level": old_level,
		"target_level": target_level,
	}


func _init_particles() -> void:
	particles.clear()
	rune_circles.clear()
	sparkles.clear()
	for _i in range(CINEMATIC_PARTICLE_COUNT):
		var angle: float = randf() * TAU
		var dist: float = randf_range(50.0, 200.0)
		particles.append({
			"angle": angle,
			"dist": dist,
			"speed": randf_range(0.5, 2.0),
			"rise": 0.0,
			"rise_speed": randf_range(18.0, 42.0),
			"size": randf_range(2.0, 5.0),
			"color": _random_particle_color(),
			"alpha": randf_range(0.6, 1.0),
			"phase_offset": randf() * TAU,
		})
	for i in range(RUNE_CIRCLE_COUNT):
		rune_circles.append({
			"radius": 80.0 + float(i) * 50.0,
			"rotation": float(i) * 1.2,
			"speed": 0.8 + float(i) * 0.3,
			"direction": -1.0 if i == 1 else 1.0,
			"segments": 6 + i * 2,
			"alpha": (180.0 - float(i) * 30.0) / 255.0,
		})


func _update_buildup(dt: float) -> void:
	var progress: float = minf(1.0, cinematic_timer / BUILDUP_DURATION)
	var acceleration: float = progress * progress
	bottle_rotation += dt * lerpf(48.0, 230.0, acceleration)
	var breath_phase: float = cinematic_timer * lerpf(2.0, 6.5, acceleration)
	bottle_scale = 0.94 + 0.06 * progress + 0.07 * sin(breath_phase) * lerpf(0.35, 1.0, progress)
	for p in particles:
		p["angle"] = float(p.get("angle", 0.0)) + float(p.get("speed", 1.0)) * dt * lerpf(0.45, 1.65, acceleration)
		p["dist"] = maxf(5.0, float(p.get("dist", 100.0)) - lerpf(16.0, 118.0, acceleration) * dt)
		p["rise"] = float(p.get("rise", 0.0)) + float(p.get("rise_speed", 28.0)) * dt * lerpf(0.45, 1.65, progress)
	for rc in rune_circles:
		var direction: float = float(rc.get("direction", 1.0))
		rc["rotation"] = float(rc.get("rotation", 0.0)) + float(rc.get("speed", 1.0)) * direction * dt * lerpf(0.40, 2.50, acceleration)
	if cinematic_timer >= BUILDUP_DURATION:
		cinematic_phase = Phase.REVEAL
		cinematic_timer = 0.0
		flash_alpha = 1.0
		_spawn_explosion_sparkles()


func _update_reveal(dt: float) -> void:
	flash_alpha = maxf(0.0, 1.0 - cinematic_timer * (300.0 / 255.0))
	result_alpha = minf(1.0, cinematic_timer * (200.0 / 255.0))
	_update_sparkles(dt)
	if cinematic_timer >= REVEAL_DURATION:
		cinematic_phase = Phase.CELEBRATION
		cinematic_timer = 0.0
		waiting_for_confirm = true
		_trigger_celebration()


func _update_celebration(dt: float) -> void:
	result_alpha = 1.0
	celebration_timer += dt
	rays_rotation = fmod(rays_rotation + dt * 42.0, 360.0)
	if banner_progress < 1.0:
		banner_progress = minf(1.0, banner_progress + dt * 3.5)
	if celebration_timer < 0.7:
		var t: float = celebration_timer / 0.7
		var eased: float = 1.0 - exp(-t * 4.5) * abs(cos(t * 10.0))
		level5_impact_scale = 2.2 * (1.0 - eased) + 1.0 * eased
	else:
		var target: float = 1.0 + 0.12 * sin(celebration_timer * 5.0)
		level5_impact_scale += (target - level5_impact_scale) * minf(1.0, dt * 6.0)
	var icon_target: float = 1.0 + 0.08 * sin(celebration_timer * 3.5)
	if celebration_timer < 0.4:
		var t2: float = celebration_timer / 0.4
		icon_breath_scale = 1.35 * (1.0 - t2) + icon_target * t2
	else:
		icon_breath_scale += (icon_target - icon_breath_scale) * minf(1.0, dt * 5.0)
	var sw_to_remove: Array = []
	for sw in shockwaves:
		if float(sw.get("delay", 0.0)) > 0.0:
			sw["delay"] = float(sw.get("delay", 0.0)) - dt
			continue
		sw["age"] = float(sw.get("age", 0.0)) + dt
		var progress: float = float(sw.get("age", 0.0)) / maxf(0.01, float(sw.get("duration", 1.0)))
		if progress >= 1.0:
			sw_to_remove.append(sw)
			continue
		var eased: float = 1.0 - pow(1.0 - progress, 3.0)
		sw["radius"] = float(sw.get("max_radius", 260.0)) * eased
		sw["current_alpha"] = 1.0 - progress
	for sw in sw_to_remove:
		shockwaves.erase(sw)
	while not _fireworks_queue.is_empty():
		var entry: Dictionary = _fireworks_queue[0]
		if float(entry.get("time", 0.0)) > celebration_timer:
			break
		_fireworks_queue.pop_front()
		_spawn_firework_burst(float(entry.get("ox", 0.0)), float(entry.get("oy", 0.0)))
	if celebration_timer > 2.0 and randf() < dt * 1.2:
		_spawn_firework_burst(randf_range(-230.0, 230.0), randf_range(-200.0, 70.0))
	var confetti_to_remove: Array = []
	for c in confetti:
		c["life"] = float(c.get("life", 0.0)) - dt
		c["vy"] = float(c.get("vy", 0.0)) + float(c.get("gravity", 350.0)) * dt
		c["vx"] = float(c.get("vx", 0.0)) * pow(float(c.get("drag", 0.5)), maxf(0.0001, dt))
		c["x"] = float(c.get("x", 0.0)) + float(c.get("vx", 0.0)) * dt
		c["y"] = float(c.get("y", 0.0)) + float(c.get("vy", 0.0)) * dt
		c["rotation"] = float(c.get("rotation", 0.0)) + float(c.get("rot_speed", 0.0)) * dt
		if float(c.get("life", 0.0)) <= 0.0 or float(c.get("y", 0.0)) > 430.0:
			confetti_to_remove.append(c)
	for c in confetti_to_remove:
		confetti.erase(c)
	var fw_to_remove: Array = []
	for f in fireworks:
		f["life"] = float(f.get("life", 0.0)) - dt
		f["vy"] = float(f.get("vy", 0.0)) + 180.0 * dt
		var firework_drag: float = pow(0.965, maxf(0.0001, dt * 60.0))
		f["vx"] = float(f.get("vx", 0.0)) * firework_drag
		f["vy"] = float(f.get("vy", 0.0)) * firework_drag
		f["x"] = float(f.get("x", 0.0)) + float(f.get("vx", 0.0)) * dt
		f["y"] = float(f.get("y", 0.0)) + float(f.get("vy", 0.0)) * dt
		if float(f.get("life", 0.0)) <= 0.0:
			fw_to_remove.append(f)
	for f in fw_to_remove:
		fireworks.erase(f)
	_update_sparkles(dt)


func _update_sparkles(dt: float) -> void:
	var to_remove: Array = []
	for s in sparkles:
		s["life"] = float(s.get("life", 0.0)) - dt
		s["x"] = float(s.get("x", 0.0)) + float(s.get("vx", 0.0)) * dt
		s["y"] = float(s.get("y", 0.0)) + float(s.get("vy", 0.0)) * dt
		s["vy"] = float(s.get("vy", 0.0)) + 50.0 * dt
		if float(s.get("life", 0.0)) <= 0.0:
			to_remove.append(s)
	for s in to_remove:
		sparkles.erase(s)


func _spawn_explosion_sparkles() -> void:
	sparkles.clear()
	for _i in range(SPARKLE_BURST_COUNT):
		var angle: float = randf() * TAU
		var speed: float = randf_range(100.0, 400.0)
		sparkles.append({
			"x": 0.0, "y": 0.0,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed,
			"size": randf_range(2.0, 6.0),
			"color": _random_sparkle_color(),
			"life": randf_range(1.0, 3.0),
			"max_life": 3.0,
		})


func _trigger_celebration() -> void:
	celebration_triggered = true
	celebration_timer = 0.0
	level5_impact_scale = 2.2
	icon_breath_scale = 1.35
	confetti.clear()
	for _i in range(CONFETTI_COUNT):
		var angle: float = randf() * TAU
		var speed: float = randf_range(180.0, 540.0)
		confetti.append({
			"x": randf_range(-40.0, 40.0),
			"y": randf_range(-40.0, 40.0),
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed - 90.0,
			"rotation": randf_range(0.0, 360.0),
			"rot_speed": randf_range(-600.0, 600.0),
			"size": randf_range(4.0, 10.0),
			"variant": randi() % 4,
			"color": _random_confetti_color(),
			"life": randf_range(2.5, 4.5),
			"max_life": 4.5,
			"gravity": randf_range(280.0, 460.0),
			"drag": randf_range(0.35, 0.65),
		})
	shockwaves = [
		{"radius": 0.0, "max_radius": 260.0, "width": 6.0, "color": Color(1.0, 0.84, 0.39), "delay": 0.0, "age": 0.0, "duration": 0.75, "current_alpha": 1.0},
		{"radius": 0.0, "max_radius": 340.0, "width": 5.0, "color": Color(0.84, 0.16, 0.08), "delay": 0.13, "age": 0.0, "duration": 0.85, "current_alpha": 1.0},
		{"radius": 0.0, "max_radius": 420.0, "width": 4.0, "color": Color.WHITE, "delay": 0.28, "age": 0.0, "duration": 0.95, "current_alpha": 1.0},
	]
	_fireworks_queue = [
		{"time": 0.15, "ox": -180.0, "oy": -60.0},
		{"time": 0.40, "ox": 170.0, "oy": -40.0},
		{"time": 0.75, "ox": -60.0, "oy": -180.0},
		{"time": 1.10, "ox": 60.0, "oy": 40.0},
		{"time": 1.50, "ox": -150.0, "oy": 70.0},
		{"time": 1.95, "ox": 180.0, "oy": 90.0},
	]


func _spawn_firework_burst(offset_x: float, offset_y: float) -> void:
	var palette: Array = _random_firework_palette()
	for _i in range(50):
		var angle: float = randf() * TAU
		var speed: float = randf_range(110.0, 290.0)
		fireworks.append({
			"x": offset_x, "y": offset_y,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed,
			"size": randf_range(1.5, 3.5),
			"color": palette[randi() % palette.size()],
			"life": randf_range(0.5, 1.2),
			"max_life": 1.2,
		})


func _finish_cinematic() -> void:
	cinematic_active = false
	waiting_for_confirm = false
	active = false
	cinematic_phase = Phase.INACTIVE
	celebration_triggered = false
	confetti.clear()
	fireworks.clear()
	shockwaves.clear()
	_fireworks_queue.clear()


func _random_particle_color() -> Color:
	var colors: Array = [Color(0.96, 0.68, 0.16), Color(0.84, 0.16, 0.08), Color(1.0, 0.84, 0.39), Color(1.0, 0.96, 0.78)]
	return colors[randi() % colors.size()]


func _random_sparkle_color() -> Color:
	var colors: Array = [Color(1.0, 0.84, 0.0), Color(0.84, 0.16, 0.08), Color(1.0, 0.94, 0.68), Color.WHITE, Color(1.0, 0.63, 0.12)]
	return colors[randi() % colors.size()]


func _random_confetti_color() -> Color:
	# Textured result uses a gold/crimson four-cell atlas. These colors remain
	# for the procedural fallback and deliberately exclude white/gray/green.
	var colors: Array = [
		Color(1.0, 0.76, 0.12),
		Color(0.93, 0.55, 0.08),
		Color(0.84, 0.09, 0.04),
		Color(0.64, 0.035, 0.02),
	]
	return colors[randi() % colors.size()]


func _random_firework_palette() -> Array:
	var palettes: Array = [
		[Color(1.0, 0.84, 0.0), Color(1.0, 0.71, 0.24), Color(1.0, 1.0, 0.78)],
		[Color(0.84, 0.16, 0.08), Color(1.0, 0.42, 0.12), Color(1.0, 0.94, 0.68)],
		[Color(0.93, 0.61, 0.12), Color(1.0, 0.82, 0.35), Color.WHITE],
		[Color(0.57, 0.12, 0.06), Color(0.94, 0.31, 0.10), Color(1.0, 0.82, 0.35)],
	]
	return palettes[randi() % palettes.size()]
