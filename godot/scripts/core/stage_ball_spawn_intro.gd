extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const StageBallSpawnIntroAtmosphereRenderer := preload("res://scripts/core/stage_ball_spawn_intro_atmosphere_renderer.gd")
const StageBallSpawnIntroBallRenderer := preload("res://scripts/core/stage_ball_spawn_intro_ball_renderer.gd")
const StageBallSpawnIntroBallState := preload("res://scripts/core/stage_ball_spawn_intro_ball_state.gd")
const StageBallSpawnIntroEffectFactory := preload("res://scripts/core/stage_ball_spawn_intro_effect_factory.gd")
const StageBallSpawnIntroEffectRenderer := preload("res://scripts/core/stage_ball_spawn_intro_effect_renderer.gd")
const StageBallSpawnIntroEffectUpdater := preload("res://scripts/core/stage_ball_spawn_intro_effect_updater.gd")
const StageBallSpawnIntroDrawLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_draw_lifecycle.gd")
const StageBallSpawnIntroFxHost := preload("res://scripts/core/stage_ball_spawn_intro_fx_host.gd")
const StageBallSpawnIntroFxLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_fx_lifecycle.gd")
const StageBallSpawnIntroLifecycle := preload("res://scripts/core/stage_ball_spawn_intro_lifecycle.gd")
const StageBallSpawnPillarOverlayHost := preload("res://scripts/core/stage_ball_spawn_pillar_overlay_host.gd")
const StageBallSpawnIntroPhase1Updater := preload("res://scripts/core/stage_ball_spawn_intro_phase_1_updater.gd")
const StageBallSpawnIntroPhase2Updater := preload("res://scripts/core/stage_ball_spawn_intro_phase_2_updater.gd")
const StageBallSpawnIntroPhase3Updater := preload("res://scripts/core/stage_ball_spawn_intro_phase_3_updater.gd")
const StageBallSpawnIntroTextureCache := preload("res://scripts/core/stage_ball_spawn_intro_texture_cache.gd")

# === Game-space constants ===
const GAME_WIDTH := 760.0
const GAME_HEIGHT := 750.0
const TUTORIAL_STAGE := 50

const PLAYER_Y := 700.0
const BOSS_Y := 25.0
const DEFAULT_PLAYER_PADDLE_WIDTH := 155.0
const BOSS_PADDLE_WIDTH := 100.0
const BOSS_HITBOX_HEIGHT := 40.0
const BALL_VISUAL_SCALE := 1.575
const BALL_RENDER_RADIUS := 16.9 * BALL_VISUAL_SCALE

# === Phase timing (4.0s gameplay handoff + 0.4s residual overlay) ===
const PHASE_1_DURATION := 2.0
const PHASE_2_DURATION := 0.75
const PHASE_3_DURATION := 1.25
const OUTRO_DURATION := 0.40
const BLOCKING_DURATION := PHASE_1_DURATION + PHASE_2_DURATION + PHASE_3_DURATION
const TOTAL_DURATION := BLOCKING_DURATION + OUTRO_DURATION
const PILLAR_OVERLAY_HOST_END_TIME := BLOCKING_DURATION

# Paddle hologram materialize window: the last 1.5s of the blocking intro.
# Mirrors Python's `get_paddle_hologram_state()` (PADDLE_HOLOGRAM_DURATION = 3s
# of an 8s intro, ~37.5%). At 4s blocking that scales to 1.5s — same ratio.
# Before this window the player and boss are fully hidden; during it they
# materialize via the glitch effect (alpha + scanlines + RGB split + flicker).
const PADDLE_HOLOGRAM_DURATION := 1.5

# === Population caps ===
# Tuned for Godot canvas batcher with the texture-blit fastpath in
# `_draw_quantum_particle()`. Each particle is now ~3 draw calls (was ~25),
# so we can afford rich entity counts at high frame rate.
const QUANTUM_PARTICLE_BASE := 24
const QUANTUM_PARTICLE_HARD_CAP := 36
const VORTEX_RING_COUNT := 5
const PHASE3_TRAIL_LIMIT := 18
const MAX_LIGHTNING_BOLTS := 12
const MAX_ELECTRIC_ARCS := 7
const MAX_HOLOGRAM_RINGS := 9
const MAX_SPARKS := 34
const MAX_ENERGY_RINGS := 5
const MAX_CHAIN_LIGHTNINGS := 2
const STARFIELD_COUNT := 26
const HAZE_CLOUD_COUNT := 2

# Replaces the 4-layer per-particle draw_circle stack ??single radial-gradient
# === Internal state ===
var active := false
var overlay_active := false
var serve_handoff_done := false
var elapsed_sec := 0.0
var current_stage := 1
var player_serves := true
var start_pos := Vector2(GAME_WIDTH * 0.5, GAME_HEIGHT * 0.5)
var target_pos := Vector2(GAME_WIDTH * 0.5, PLAYER_Y - BALL_RENDER_RADIUS)

var rng := RandomNumberGenerator.new()

var particles: Array = []
var vortex_rings: Array = []
var lightning_bolts: Array = []
var chain_lightnings: Array = []
var electric_arcs: Array = []
var sparks: Array = []
var hologram_rings: Array = []
var energy_rings: Array = []
var phase3_trail: Array = []
# Background atmosphere fillers ??make the scene feel densely packed without
# adding heavy entities. Starfield is ~1 draw_circle per dot; haze clouds are
# ~1 draw_texture_rect each and drift slowly.
var starfield: Array = []
var haze_clouds: Array = []

var lightning_spawn_timer := 0.0
var arc_spawn_timer := 0.0
var spark_spawn_timer := 0.0
var hologram_spawn_timer := 0.0
var energy_ring_timer := 0.0
var particle_spawn_timer := 0.0
var chain_spawn_timer := 0.0

var fog_alpha := 0.0
var fog_color := Color(0.85, 0.81, 0.90, 1.0)
var core_glow_radius := 0.0
var core_glow_alpha := 0.0
var atmosphere_renderer: Object = StageBallSpawnIntroAtmosphereRenderer.new()
var ball_renderer: Object = StageBallSpawnIntroBallRenderer.new()
var ball_state_resolver: Object = StageBallSpawnIntroBallState.new()
var effect_factory: Object = StageBallSpawnIntroEffectFactory.new()
var effect_renderer: Object = StageBallSpawnIntroEffectRenderer.new()
var effect_updater: Object = StageBallSpawnIntroEffectUpdater.new()
var draw_lifecycle: Object = StageBallSpawnIntroDrawLifecycle.new()
var fx_lifecycle: Object = StageBallSpawnIntroFxLifecycle.new()
var intro_lifecycle: Object = StageBallSpawnIntroLifecycle.new()
var phase_1_updater: Object = StageBallSpawnIntroPhase1Updater.new()
var phase_2_updater: Object = StageBallSpawnIntroPhase2Updater.new()
var phase_3_updater: Object = StageBallSpawnIntroPhase3Updater.new()
var fx_host: Node = null
var pillar_overlay_host: Node = null
var _asset_prewarm_step_index := 0


# === Public API ===
func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	match _asset_prewarm_step_index:
		0:
			if not StageBallSpawnIntroTextureCache.prewarm_step():
				return false
		1:
			if not StageBallSpawnIntroFxHost.prewarm_assets_step():
				return false
		_:
			_asset_prewarm_step_index = 0
			return true
	_asset_prewarm_step_index += 1
	return false


func begin(owner: Object, registry: Object) -> bool:
	return intro_lifecycle.begin_intro(self, owner, registry, {
		"tutorial_stage": TUTORIAL_STAGE,
		"game_width": GAME_WIDTH,
		"game_height": GAME_HEIGHT,
	})


func reset() -> void:
	_reset_state()


func update(delta: float, owner: Object, registry: Object) -> void:
	intro_lifecycle.update_intro(self, delta, owner, registry, {
		"phase_1_duration": PHASE_1_DURATION,
		"phase_2_duration": PHASE_2_DURATION,
		"phase_3_duration": PHASE_3_DURATION,
		"blocking_duration": BLOCKING_DURATION,
		"total_duration": TOTAL_DURATION,
	})


func handle_input(_event: InputEvent, _registry: Object = null) -> bool:
	return active


func is_active() -> bool:
	return active


func is_overlay_active() -> bool:
	return active or overlay_active


func should_restore_pillar_overlay() -> bool:
	return is_overlay_active() and not serve_handoff_done and not _is_pillar_overlay_host_active()


func get_elapsed_time() -> float:
	return elapsed_sec if is_overlay_active() else 0.0


func get_total_duration() -> float:
	return TOTAL_DURATION


# Mirror of Python's `get_paddle_hologram_state()` (pingfighter.py §122551).
# Returns the materialize state for the current frame so player / boss actor
# renderers can hide their sprites before the hologram window and apply the
# glitch reveal during it. Outside the intro this returns the "fully visible"
# state so normal rendering passes through unchanged.
func get_paddle_hologram_state() -> Dictionary:
	if not is_overlay_active():
		return {"should_draw": true, "progress": 1.0, "active": false}
	var hologram_start: float = BLOCKING_DURATION - PADDLE_HOLOGRAM_DURATION
	if elapsed_sec < hologram_start:
		return {"should_draw": false, "progress": 0.0, "active": false}
	var hologram_elapsed: float = elapsed_sec - hologram_start
	var progress: float = clamp(hologram_elapsed / PADDLE_HOLOGRAM_DURATION, 0.0, 1.0)
	if progress >= 1.0:
		return {"should_draw": true, "progress": 1.0, "active": false}
	return {"should_draw": true, "progress": progress, "active": true}


func draw(canvas: CanvasItem, owner: Object, registry: Object, view_size: Vector2) -> void:
	draw_lifecycle.draw_intro(self, canvas, owner, registry, view_size)


# === Lifecycle helpers ===
func _finish(owner: Object, registry: Object) -> void:
	intro_lifecycle.finish(self, owner, registry, target_pos)


func _complete_gameplay_handoff(owner: Object, registry: Object) -> void:
	if serve_handoff_done:
		return
	serve_handoff_done = true
	active = false
	overlay_active = true
	_apply_owner_spawn_snapshot(owner, target_pos)
	var round_state: Object = _get_instance(registry, "round_flow_state")
	if round_state != null:
		if round_state.has_method("prepare_serve_after_intro"):
			round_state.prepare_serve_after_intro()
		elif round_state.has_method("reset_round_wait"):
			round_state.reset_round_wait()
	_sync_serve_input(registry)


func _has_completed_serve_handoff() -> bool:
	return serve_handoff_done


func _reset_state() -> void:
	intro_lifecycle.reset_state(self)


func _begin_fx_host(owner: Object) -> void:
	fx_host = fx_lifecycle.begin_fx_host(
		owner,
		fx_host,
		start_pos,
		target_pos,
		BALL_RENDER_RADIUS,
		PHASE_1_DURATION,
		PHASE_2_DURATION,
		PHASE_3_DURATION,
		player_serves
	)
	if fx_host == null:
		return
	if fx_host.has_method("set_intro_renderer"):
		fx_host.set_intro_renderer(self)
	if fx_host.has_method("apply_stage_tint"):
		fx_host.apply_stage_tint(current_stage)


func _begin_pillar_overlay_host(owner: Object, registry: Object) -> void:
	_tear_down_pillar_overlay_host()
	if owner == null or not (owner is Node):
		return
	var host := StageBallSpawnPillarOverlayHost.new()
	host.name = "StageBallSpawnPillarOverlayHost"
	(owner as Node).add_child(host)
	host.begin(registry, owner)
	pillar_overlay_host = host


func _sync_fx_host_state(ball_state: Dictionary) -> void:
	var fx_phase: int = int(ball_state.get("phase", _current_phase()))
	fx_host = fx_lifecycle.sync_state(fx_host, ball_state, fx_phase, elapsed_sec)


func _sync_pillar_overlay_host() -> void:
	if pillar_overlay_host == null or not is_instance_valid(pillar_overlay_host):
		pillar_overlay_host = null
		return
	if pillar_overlay_host.has_method("sync_active"):
		pillar_overlay_host.sync_active(_should_use_pillar_overlay_host())


func _should_use_pillar_overlay_host() -> bool:
	return active and not serve_handoff_done and elapsed_sec < PILLAR_OVERLAY_HOST_END_TIME


func _is_pillar_overlay_host_active() -> bool:
	if pillar_overlay_host == null or not is_instance_valid(pillar_overlay_host):
		return false
	if pillar_overlay_host is CanvasItem and not (pillar_overlay_host as CanvasItem).visible:
		return false
	if "active" in pillar_overlay_host:
		return bool(pillar_overlay_host.get("active"))
	return true


func _sync_fx_host_layout(layout: Dictionary) -> void:
	fx_host = fx_lifecycle.sync_layout(fx_host, layout)


func _tear_down_fx_host() -> void:
	fx_host = fx_lifecycle.tear_down(fx_host)


func _tear_down_pillar_overlay_host() -> void:
	if pillar_overlay_host == null:
		return
	if is_instance_valid(pillar_overlay_host) and pillar_overlay_host.has_method("tear_down"):
		pillar_overlay_host.tear_down(true)
	pillar_overlay_host = null


func _spawn_initial_entities() -> void:
	intro_lifecycle.spawn_initial_entities(self, {
		"game_width": GAME_WIDTH,
		"game_height": GAME_HEIGHT,
		"quantum_particle_base": QUANTUM_PARTICLE_BASE,
		"vortex_ring_count": VORTEX_RING_COUNT,
		"starfield_count": STARFIELD_COUNT,
		"haze_cloud_count": HAZE_CLOUD_COUNT,
	})


# === Texture access ===
func _get_glow_texture() -> ImageTexture:
	return StageBallSpawnIntroTextureCache.get_glow_texture()


func _get_ball_texture() -> ImageTexture:
	return StageBallSpawnIntroTextureCache.get_ball_texture()


func _get_ball_body_texture() -> ImageTexture:
	return StageBallSpawnIntroTextureCache.get_ball_body_texture()


# === Phase 1: Energy condensation (2.0s) ===
func _update_phase_1(dt: float) -> void:
	phase_1_updater.update(self, dt, {
		"game_width": GAME_WIDTH,
		"game_height": GAME_HEIGHT,
		"phase_1_duration": PHASE_1_DURATION,
		"quantum_particle_hard_cap": QUANTUM_PARTICLE_HARD_CAP,
		"max_electric_arcs": MAX_ELECTRIC_ARCS,
		"max_chain_lightnings": MAX_CHAIN_LIGHTNINGS,
	})


# === Phase 2: Ball levitation (0.75s) ===
func _update_phase_2(dt: float) -> void:
	phase_2_updater.update(self, dt, {
		"phase_1_duration": PHASE_1_DURATION,
		"phase_2_duration": PHASE_2_DURATION,
		"ball_render_radius": BALL_RENDER_RADIUS,
		"max_energy_rings": MAX_ENERGY_RINGS,
		"max_electric_arcs": MAX_ELECTRIC_ARCS,
	})


# === Phase 3: Move to serve position (1.25s) ===
func _update_phase_3(dt: float) -> void:
	phase_3_updater.update(self, dt, {
		"phase_1_duration": PHASE_1_DURATION,
		"phase_2_duration": PHASE_2_DURATION,
		"phase_3_duration": PHASE_3_DURATION,
		"ball_render_radius": BALL_RENDER_RADIUS,
		"phase3_trail_limit": PHASE3_TRAIL_LIMIT,
		"max_hologram_rings": MAX_HOLOGRAM_RINGS,
		"max_sparks": MAX_SPARKS,
		"max_electric_arcs": MAX_ELECTRIC_ARCS,
		"max_energy_rings": MAX_ENERGY_RINGS,
		"max_lightning_bolts": MAX_LIGHTNING_BOLTS,
	})


func _update_outro(dt: float) -> void:
	var ball_state: Dictionary = _get_ball_state()
	var fade: float = clamp(float(ball_state.get("alpha", 0.0)), 0.0, 1.0)
	fog_alpha = min(fog_alpha, 28.0 * fade)
	core_glow_alpha = min(core_glow_alpha, 72.0 * fade)
	core_glow_radius = max(0.0, core_glow_radius * max(0.0, 1.0 - dt * 3.5))
	_prune_lifetime(lightning_bolts, dt)
	_prune_lifetime(chain_lightnings, dt)
	_prune_lifetime(electric_arcs, dt)
	_prune_lifetime(sparks, dt)
	_prune_lifetime(hologram_rings, dt)
	_prune_lifetime(energy_rings, dt)
	for particle in particles:
		_update_quantum_particle(particle, 1.0, dt)


# === Entity factories ===
func _make_quantum_particle(max_radius: float) -> Dictionary:
	return effect_factory.make_quantum_particle(rng, start_pos, max_radius)

func _update_quantum_particle(p: Dictionary, progress: float, dt: float) -> void:
	effect_updater.update_quantum_particle(p, progress, dt, start_pos)


func _make_vortex_ring(radius: float) -> Dictionary:
	return effect_factory.make_vortex_ring(rng, start_pos, radius)

func _make_starfield_dot(game_width: float, game_height: float) -> Dictionary:
	return effect_factory.make_starfield_dot(rng, game_width, game_height)

func _make_haze_cloud(game_width: float, game_height: float) -> Dictionary:
	return effect_factory.make_haze_cloud(rng, game_width, game_height)

func _update_vortex_ring(r: Dictionary, progress: float, dt: float) -> void:
	effect_updater.update_vortex_ring(r, progress, dt)


func _make_lightning_bolt(start_pt: Vector2, end_pt: Vector2, is_main: bool, branch_depth: int) -> Dictionary:
	return effect_factory.make_lightning_bolt(rng, start_pt, end_pt, is_main, branch_depth)

func _make_electric_arc(center: Vector2, radius: float) -> Dictionary:
	return effect_factory.make_electric_arc(rng, center, radius)

func _update_electric_arc(arc: Dictionary, dt: float, new_center: Vector2) -> void:
	effect_updater.update_electric_arc(rng, arc, dt, new_center)


func _make_hologram_ring(center: Vector2, radius: float) -> Dictionary:
	return effect_factory.make_hologram_ring(rng, center, radius)

func _update_hologram_ring(h: Dictionary, dt: float, new_center: Vector2) -> void:
	effect_updater.update_hologram_ring(rng, h, dt, new_center)


func _make_spark(pos: Vector2, direction: float) -> Dictionary:
	return effect_factory.make_spark(rng, pos, direction)

func _update_spark(sp: Dictionary, dt: float) -> void:
	effect_updater.update_spark(sp, dt)


func _make_energy_ring(center: Vector2, start_radius: float) -> Dictionary:
	return effect_factory.make_energy_ring(rng, center, start_radius)

func _update_energy_ring(ring: Dictionary, dt: float, new_center: Vector2) -> void:
	effect_updater.update_energy_ring(ring, dt, new_center)


func _spawn_phase1_lightning(progress: float) -> void:
	var max_radius: float = min(GAME_WIDTH, GAME_HEIGHT) * 0.4 * (1.0 - progress * 0.5)
	# Single bolt per spawn tick (was 1-3) ??keeps active bolt count bounded.
	if lightning_bolts.size() >= MAX_LIGHTNING_BOLTS:
		return
	var ang: float = rng.randf_range(0.0, TAU)
	var sd: float = max_radius * rng.randf_range(0.6, 1.0)
	var sx: Vector2 = start_pos + Vector2(cos(ang), sin(ang)) * sd
	var ed: float = max(10.0, sd * (1.0 - progress) * rng.randf_range(0.18, 0.50))
	var ea: float = ang + rng.randf_range(-0.40, 0.40)
	var ex: Vector2 = start_pos + Vector2(cos(ea), sin(ea)) * ed
	lightning_bolts.append(_make_lightning_bolt(sx, ex, true, 0))
	if rng.randf() < 0.30 and particles.size() >= 2 and lightning_bolts.size() < MAX_LIGHTNING_BOLTS:
		var a: int = rng.randi_range(0, particles.size() - 1)
		var b: int = rng.randi_range(0, particles.size() - 1)
		if a != b:
			var pa: Dictionary = particles[a]
			var pb: Dictionary = particles[b]
			lightning_bolts.append(_make_lightning_bolt(Vector2(pa.x, pa.y), Vector2(pb.x, pb.y), false, 1))


func _spawn_chain_lightning() -> void:
	if particles.size() < 4:
		return
	var n: int = rng.randi_range(3, min(4, particles.size()))
	var indices: Array = []
	while indices.size() < n:
		var idx: int = rng.randi_range(0, particles.size() - 1)
		if not indices.has(idx):
			indices.append(idx)
	var bolts: Array = []
	for i in range(indices.size() - 1):
		var pa: Dictionary = particles[indices[i]]
		var pb: Dictionary = particles[indices[i + 1]]
		bolts.append(_make_lightning_bolt(Vector2(pa.x, pa.y), Vector2(pb.x, pb.y), true, 1))
	var lifetime: float = rng.randf_range(0.20, 0.40)
	chain_lightnings.append({
		"bolts": bolts,
		"lifetime": lifetime,
		"max_lifetime": lifetime,
	})


func _prune_lifetime(arr: Array, dt: float) -> void:
	effect_updater.prune_lifetime(arr, dt)


# === Drawing ===
func _draw_spawn(canvas: CanvasItem) -> void:
	var phase: int = _current_phase()
	var ball_state: Dictionary = _get_ball_state()
	var outro_alpha: float = clamp(float(ball_state.get("alpha", 1.0)), 0.0, 1.0) if phase == 4 else 1.0
	if phase == 4:
		_draw_outro_residual(canvas, ball_state, outro_alpha)
		return

	_draw_aurora_fog(canvas)
	# Background atmosphere (drawn before god rays so rays cut through them).
	_draw_haze_clouds(canvas, phase)
	_draw_starfield(canvas, phase)
	_draw_god_rays(canvas, phase)
	_draw_vortex_rings(canvas, phase)

	if phase < 4:
		for ring in energy_rings:
			_draw_energy_ring(canvas, ring)

	var particle_alpha_mult: float = 1.0
	if phase == 1:
		particle_alpha_mult = 0.44
	elif phase == 2:
		particle_alpha_mult = 0.65
	elif phase == 3:
		particle_alpha_mult = 0.32
	elif phase == 4:
		particle_alpha_mult = 0.32 * outro_alpha
	for p in particles:
		_draw_quantum_particle(canvas, p, particle_alpha_mult)

	if phase < 4:
		for chain in chain_lightnings:
			var life_ratio: float = clamp(chain.lifetime / chain.max_lifetime, 0.0, 1.0)
			for bolt in chain.bolts:
				_draw_lightning_bolt(canvas, bolt, life_ratio)

		for bolt in lightning_bolts:
			_draw_lightning_bolt(canvas, bolt, 1.0)

		for arc in electric_arcs:
			_draw_electric_arc(canvas, arc)

		for h in hologram_rings:
			_draw_hologram_ring(canvas, h)

		for sp in sparks:
			_draw_spark(canvas, sp)

	if core_glow_alpha > 0.0 and core_glow_radius > 0.0:
		_draw_core_glow(canvas)

	if phase == 3 and phase3_trail.size() > 1:
		_draw_phase3_trail(canvas)

	if bool(ball_state.get("visible", false)):
		_draw_ball(
			canvas,
			_get_vector2(ball_state.get("pos", start_pos), start_pos),
			float(ball_state.get("scale", 1.0)),
			float(ball_state.get("alpha", 1.0)),
			bool(ball_state.get("body_visible", true)),
		)

	# Landing shockwave on Phase 3 last 0.35s ??satisfying impact tell.
	if phase == 3:
		var pp: float = float(ball_state.get("phase_progress", 0.0))
		if pp > 0.65:
			_draw_landing_shockwave(canvas, _get_vector2(ball_state.get("pos", target_pos), target_pos), (pp - 0.65) / 0.35)

	_draw_phase_flash(canvas, ball_state)


func _draw_outro_residual(canvas: CanvasItem, ball_state: Dictionary, outro_alpha: float) -> void:
	if outro_alpha <= 0.01:
		return
	var pos: Vector2 = _get_vector2(ball_state.get("pos", target_pos), target_pos)
	var radius: float = BALL_RENDER_RADIUS
	var glow_texture: Texture2D = _get_glow_texture()
	var halo_diam: float = radius * (7.2 + outro_alpha * 2.2)
	canvas.draw_texture_rect(
		glow_texture,
		Rect2(pos.x - halo_diam * 0.5, pos.y - halo_diam * 0.5, halo_diam, halo_diam),
		false,
		Color(0.46, 0.86, 1.0, outro_alpha * 0.20)
	)
	var ring_radius: float = radius * (1.75 + sin(elapsed_sec * 5.0) * 0.08)
	canvas.draw_arc(pos, ring_radius, 0.0, TAU, 40, Color(0.76, 0.96, 1.0, outro_alpha * 0.40), 1.35, true)
	var dot_count := 6
	for i in range(dot_count):
		var ang: float = elapsed_sec * 2.0 + TAU * float(i) / float(dot_count)
		var dot_pos: Vector2 = pos + Vector2(cos(ang), sin(ang)) * ring_radius
		var dot_alpha: float = outro_alpha * (0.32 + 0.22 * sin(elapsed_sec * 6.0 + float(i)))
		if dot_alpha > 0.03:
			canvas.draw_circle(dot_pos, 1.25, Color(0.92, 1.0, 0.92, dot_alpha))


func _draw_haze_clouds(canvas: CanvasItem, phase: int) -> void:
	atmosphere_renderer.draw_haze_clouds(
		canvas,
		phase,
		haze_clouds,
		elapsed_sec,
		PHASE_1_DURATION,
		PHASE_2_DURATION,
		PHASE_3_DURATION,
		GAME_WIDTH,
		GAME_HEIGHT,
		_get_ball_texture()
	)


func _draw_starfield(canvas: CanvasItem, phase: int) -> void:
	atmosphere_renderer.draw_starfield(
		canvas,
		phase,
		starfield,
		elapsed_sec,
		PHASE_1_DURATION,
		PHASE_2_DURATION,
		PHASE_3_DURATION
	)


func _draw_god_rays(canvas: CanvasItem, phase: int) -> void:
	atmosphere_renderer.draw_god_rays(
		canvas,
		phase,
		elapsed_sec,
		PHASE_1_DURATION,
		PHASE_2_DURATION,
		GAME_WIDTH,
		GAME_HEIGHT,
		start_pos
	)


func _draw_landing_shockwave(canvas: CanvasItem, center: Vector2, t: float) -> void:
	ball_renderer.draw_landing_shockwave(canvas, center, t, BALL_RENDER_RADIUS, _get_glow_texture())


func _draw_aurora_fog(canvas: CanvasItem) -> void:
	atmosphere_renderer.draw_aurora_fog(
		canvas,
		fog_alpha,
		fog_color,
		GAME_WIDTH,
		GAME_HEIGHT,
		start_pos,
		_get_glow_texture()
	)


func _draw_vortex_rings(canvas: CanvasItem, phase: int) -> void:
	if vortex_rings.is_empty():
		return
	var alpha_mult: float = 1.0
	if phase == 1:
		var p1: float = clamp(elapsed_sec / PHASE_1_DURATION, 0.0, 1.0)
		alpha_mult = 0.32 * (1.0 - p1 * 0.45)
	elif phase == 2:
		var p2: float = clamp((elapsed_sec - PHASE_1_DURATION) / PHASE_2_DURATION, 0.0, 1.0)
		alpha_mult = 0.62 - p2 * 0.12
	elif phase >= 3:
		var p3: float = clamp((elapsed_sec - PHASE_1_DURATION - PHASE_2_DURATION) / PHASE_3_DURATION, 0.0, 1.0)
		alpha_mult = max(0.0, 1.0 - p3 * 1.4)
	if alpha_mult <= 0.02:
		return
	for r in vortex_rings:
		_draw_vortex_ring(canvas, r, alpha_mult)


func _draw_vortex_ring(canvas: CanvasItem, r: Dictionary, alpha_mult: float) -> void:
	effect_renderer.draw_vortex_ring(canvas, r, alpha_mult)


func _draw_quantum_particle(canvas: CanvasItem, p: Dictionary, alpha_mult: float) -> void:
	effect_renderer.draw_quantum_particle(canvas, p, alpha_mult, _get_glow_texture())

func _draw_lightning_bolt(canvas: CanvasItem, bolt: Dictionary, alpha_mult: float) -> void:
	effect_renderer.draw_lightning_bolt(canvas, bolt, alpha_mult)

func _draw_electric_arc(canvas: CanvasItem, arc: Dictionary) -> void:
	effect_renderer.draw_electric_arc(canvas, arc)

func _draw_hologram_ring(canvas: CanvasItem, h: Dictionary) -> void:
	effect_renderer.draw_hologram_ring(canvas, rng, h)

func _draw_spark(canvas: CanvasItem, sp: Dictionary) -> void:
	effect_renderer.draw_spark(canvas, sp, _get_glow_texture())

func _draw_energy_ring(canvas: CanvasItem, ring: Dictionary) -> void:
	effect_renderer.draw_energy_ring(canvas, ring)

func _draw_core_glow(canvas: CanvasItem) -> void:
	effect_renderer.draw_core_glow(canvas, start_pos, core_glow_radius, core_glow_alpha, _get_glow_texture())

func _draw_phase3_trail(canvas: CanvasItem) -> void:
	ball_renderer.draw_phase3_trail(canvas, phase3_trail, BALL_RENDER_RADIUS, _get_glow_texture())


func _draw_ball(canvas: CanvasItem, pos: Vector2, scale: float, alpha: float, draw_body: bool = true) -> void:
	ball_renderer.draw_ball(
		canvas,
		pos,
		scale,
		alpha,
		elapsed_sec,
		BALL_RENDER_RADIUS,
		_get_glow_texture(),
		_get_ball_texture(),
		draw_body
	)


func _draw_phase_flash(canvas: CanvasItem, ball_state: Dictionary) -> void:
	ball_renderer.draw_phase_flash(canvas, ball_state, elapsed_sec, GAME_WIDTH, GAME_HEIGHT)


# === Ball-state composition ===
func _get_ball_state() -> Dictionary:
	return ball_state_resolver.get_ball_state(
		elapsed_sec,
		start_pos,
		target_pos,
		PHASE_1_DURATION,
		PHASE_2_DURATION,
		PHASE_3_DURATION,
		OUTRO_DURATION
	)


func _current_phase() -> int:
	return ball_state_resolver.current_phase(elapsed_sec, PHASE_1_DURATION, PHASE_2_DURATION, PHASE_3_DURATION)


# === Owner / registry plumbing (preserved from prior module) ===
func _get_serve_target(owner: Object) -> Vector2:
	var player_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "player_pos", Vector2.ZERO)
	var boss_pos: Vector2 = BattleSceneOwnerReader.get_vector2(owner, "boss_pos", Vector2.ZERO)
	var player_paddle_width: float = max(1.0, float(BattleSceneOwnerReader.get_value(owner, "player_paddle_width", DEFAULT_PLAYER_PADDLE_WIDTH)))
	if player_serves:
		return Vector2(player_pos.x + player_paddle_width * 0.5, PLAYER_Y - BALL_RENDER_RADIUS)
	return Vector2(boss_pos.x + BOSS_PADDLE_WIDTH * 0.5, BOSS_Y + BOSS_HITBOX_HEIGHT + BALL_RENDER_RADIUS)


func _apply_owner_spawn_snapshot(owner: Object, ball_pos: Vector2) -> void:
	if owner == null:
		return
	owner.set("ball_pos", ball_pos)
	if owner.has_method("reset_ball_interpolation"):
		owner.reset_ball_interpolation()
	else:
		owner.set("ball_pos_prev", ball_pos)
		owner.set("ball_interp_reset_requested", true)
	owner.set("ball_vel", Vector2.ZERO)
	owner.set("ball_active", false)


func _build_layout(registry: Object, view_size: Vector2) -> Dictionary:
	var layout_module: Object = _get_instance(registry, "battle_view_layout")
	if layout_module != null and layout_module.has_method("build_game_layout"):
		return layout_module.build_game_layout(view_size, GAME_WIDTH, GAME_HEIGHT)
	return {
		"game_size": Vector2(GAME_WIDTH, GAME_HEIGHT),
		"game_offset": (view_size - Vector2(GAME_WIDTH, GAME_HEIGHT)) * 0.5,
		"render_scale": 1.0,
	}


func _sync_serve_input(registry: Object) -> void:
	var serve_flow: Object = _get_instance(registry, "serve_flow_controller")
	if serve_flow != null and serve_flow.has_method("sync_current_input_state"):
		serve_flow.sync_current_input_state()


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
