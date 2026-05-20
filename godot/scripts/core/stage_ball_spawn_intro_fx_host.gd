extends Node2D

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StageBallSpawnIntroTextureCache := preload("res://scripts/core/stage_ball_spawn_intro_texture_cache.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")

const VORTEX_TEXTURE_PATH := "res://assets/sprites/core/ball_spawn/stage_ball_spawn_vortex_imagegen_v1.png"
const ORBIT_RINGS_TEXTURE_PATH := "res://assets/sprites/core/ball_spawn/stage_ball_spawn_orbit_rings_imagegen_v1.png"
const RAY_BURST_TEXTURE_PATH := "res://assets/sprites/core/ball_spawn/stage_ball_spawn_ray_burst_imagegen_v1.png"
const GAME_SIZE := Vector2(760.0, 750.0)
# In Godot the playfield is the FULL game canvas (game x=0..760). The "pillars"
# that the legacy Python codebase carved out at x=0..80 / 680..760 are not
# present here — outer pillar chrome lives in the screen letterbox area
# OUTSIDE the game canvas (see `battle_scene_config.gd` and
# `battle_playfield_scene_drawer.gd`). The clip below therefore must match the
# game canvas so spawn FX cannot leak past `game_offset` into the letterbox.
const PLAYFIELD_CLIP_POSITION := Vector2.ZERO
const PLAYFIELD_CLIP_SIZE := GAME_SIZE
const SHARD_COLUMNS := 4
const SHARD_ROWS := 3
const SHARD_COUNT := SHARD_COLUMNS * SHARD_ROWS
const CORE_QUAD_SIZE := 230.0
const PHASE1_VORTEX_QUAD_SIZE := 680.0
const ORBIT_RINGS_QUAD_SIZE := 540.0
const BODY_DRAW_DIAMETER_MULT := 2.85
const SHARD_SCATTER_RADIUS := 122.0
const RAY_BURST_QUAD_SIZE := 540.0
const PHASE1_INFLOW_EMISSION_RADIUS := 330.0
const STAGE_TINT_TABLE := {
	1: Color(1.00, 0.90, 0.45, 1.0),
	2: Color(0.65, 1.00, 0.55, 1.0),
	3: Color(1.00, 0.70, 0.95, 1.0),
	4: Color(1.00, 0.85, 0.55, 1.0),
	5: Color(0.55, 0.85, 1.00, 1.0),
	6: Color(1.00, 0.55, 0.30, 1.0),
	7: Color(0.70, 0.55, 1.00, 1.0),
}

class PlayfieldAccentLayer:
	extends Control

	var host: Object = null

	func _draw() -> void:
		if host != null and host.has_method("_draw_clipped_accents"):
			host._draw_clipped_accents(self)


class IntroSpawnDrawBridge:
	extends Control

	var intro: Object = null

	func _draw() -> void:
		if intro == null:
			return
		if not intro.has_method("_draw_spawn"):
			return
		intro._draw_spawn(self)


var phase_1_duration := 2.0
var phase_2_duration := 0.75
var phase_3_duration := 1.25
var ball_render_radius := 26.6175
var player_serves := true

var start_pos := Vector2.ZERO
var target_pos := Vector2.ZERO
var ball_pos := Vector2.ZERO
var ball_scale := 1.0
var ball_alpha := 0.0
var elapsed_sec := 0.0
var phase := 1
var phase_progress := 0.0

var fx_core_alpha := 0.0
var fx_phase1_intensity := 0.0
var fx_phase1_flash := 0.0
var fx_swirl_strength := 0.0
var fx_shard_converge := 0.0
var fx_launch_burst := 0.0
var fx_flash := 0.0
var stage_tint := Color.WHITE

var _glow_texture: Texture2D = null
var _ball_body_texture: Texture2D = null
var _playfield_clip: Control = null
var _intro_render_layer: Control = null
var _intro_renderer: Object = null
var _playfield_accent_layer: Control = null
var _phase1_vortex_quad: Control = null
var _orbit_rings_quad: TextureRect = null
var _ray_burst_quad: TextureRect = null
var _phase1_inflow_particles: GPUParticles2D = null
var _core_quad: ColorRect = null
var _condense_particles: GPUParticles2D = null
var _launch_particles: GPUParticles2D = null
var _phase1_vortex_material: ShaderMaterial = null
var _orbit_rings_material: ShaderMaterial = null
var _core_material: ShaderMaterial = null
var _additive_material: CanvasItemMaterial = null
var _tween: Tween = null
var _ray_burst_tween: Tween = null
var _ray_burst_flash_tween: Tween = null
var _orbit_rings_intro_tween: Tween = null
var _orbit_rings_breath_tween: Tween = null
var _orbit_rings_out_tween: Tween = null
var _shards: Array = []
var _running := false
var _shards_visible := false
var _phase1_vortex_uses_writhe := false
var _ray_burst_triggered := false
var _ray_burst_absorb_particles_active := false
var _orbit_rings_phaseout_triggered := false
var _layout_synced := false
var _outro_idle_entered := false

static var _vortex_texture: Texture2D = null
static var _orbit_rings_texture: Texture2D = null
static var _ray_burst_texture: Texture2D = null


static func prewarm_assets() -> void:
	StageBallSpawnIntroTextureCache.get_glow_texture()
	StageBallSpawnIntroTextureCache.get_ball_body_texture()
	_get_vortex_texture()
	_get_orbit_rings_texture()
	_get_ray_burst_texture()
	WritheEmber.prewarm()
	_build_phase1_vortex_shader_material()
	_build_phase1_inflow_process_material()
	_build_core_shader_material()
	_build_particle_process_material(Vector3(0.0, -1.0, 0.0), false)
	_build_particle_process_material(Vector3(0.0, -1.0, 0.0), true)


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"ball_spawn_intro_shader_host_pipeline": (
			WritheEmber.has_preset("ball_spawn_vortex")
			and WritheEmber.has_preset("ball_spawn_orbit_rings")
			and _build_core_shader_material() != null
			and _build_phase1_vortex_shader_material() != null
		),
		"ball_spawn_intro_shader_layers": 4,
		"ball_spawn_intro_gpu_particle_layers": 3,
		"ball_spawn_intro_texture_pieces_ready": (
			_is_png_texture_loaded(VORTEX_TEXTURE_PATH, _get_vortex_texture())
			and _is_png_texture_loaded(ORBIT_RINGS_TEXTURE_PATH, _get_orbit_rings_texture())
			and _is_png_texture_loaded(RAY_BURST_TEXTURE_PATH, _get_ray_burst_texture())
		),
		"ball_spawn_intro_vortex_png_slot": _is_png_texture_loaded(VORTEX_TEXTURE_PATH, _get_vortex_texture()),
		"ball_spawn_intro_orbit_rings_png_slot": _is_png_texture_loaded(ORBIT_RINGS_TEXTURE_PATH, _get_orbit_rings_texture()),
		"ball_spawn_intro_ray_burst_png_slot": _is_png_texture_loaded(RAY_BURST_TEXTURE_PATH, _get_ray_burst_texture()),
		"ball_spawn_intro_vortex_texture_path": VORTEX_TEXTURE_PATH,
		"ball_spawn_intro_orbit_rings_texture_path": ORBIT_RINGS_TEXTURE_PATH,
		"ball_spawn_intro_ray_burst_texture_path": RAY_BURST_TEXTURE_PATH,
	}


func begin_fx(
	next_start_pos: Vector2,
	next_target_pos: Vector2,
	next_ball_render_radius: float,
	next_phase_1_duration: float,
	next_phase_2_duration: float,
	next_phase_3_duration: float,
	next_player_serves: bool
) -> void:
	tear_down(false)
	start_pos = next_start_pos
	target_pos = next_target_pos
	ball_pos = next_start_pos
	ball_render_radius = next_ball_render_radius
	phase_1_duration = next_phase_1_duration
	phase_2_duration = next_phase_2_duration
	phase_3_duration = next_phase_3_duration
	player_serves = next_player_serves
	elapsed_sec = 0.0
	phase = 1
	phase_progress = 0.0
	fx_core_alpha = 0.0
	fx_phase1_intensity = 0.0
	fx_phase1_flash = 0.0
	fx_swirl_strength = 0.0
	fx_shard_converge = 0.0
	fx_launch_burst = 0.0
	fx_flash = 0.0
	stage_tint = Color.WHITE
	_ray_burst_triggered = false
	_ray_burst_absorb_particles_active = false
	_orbit_rings_phaseout_triggered = false
	_layout_synced = false
	_outro_idle_entered = false
	_running = true
	visible = false
	z_as_relative = false
	z_index = 900
	_glow_texture = StageBallSpawnIntroTextureCache.get_glow_texture()
	_ball_body_texture = StageBallSpawnIntroTextureCache.get_ball_body_texture()
	_additive_material = _make_additive_material()
	_build_children()
	_trigger_orbit_rings_phase1()
	_start_tween()
	_sync_particles()
	_queue_fx_redraw()


func apply_stage_tint(stage_num: int) -> void:
	var tint: Color = STAGE_TINT_TABLE.get(stage_num, Color.WHITE)
	stage_tint = tint
	_apply_current_tint()
	_sync_particles()
	_queue_fx_redraw()


func set_intro_renderer(intro: Object) -> void:
	_intro_renderer = intro
	if _intro_render_layer != null:
		_intro_render_layer.intro = intro
		_intro_render_layer.queue_redraw()


func _apply_current_tint() -> void:
	var tint: Color = stage_tint
	if _phase1_vortex_quad != null:
		_phase1_vortex_quad.modulate = _with_alpha(tint, _phase1_vortex_quad.modulate.a)
	if _orbit_rings_quad != null:
		_orbit_rings_quad.modulate = _with_alpha(tint, _orbit_rings_quad.modulate.a)
	if _ray_burst_quad != null:
		_ray_burst_quad.modulate = _with_alpha(tint, _ray_burst_quad.modulate.a)
	if _core_quad != null:
		_core_quad.modulate = _with_alpha(tint, _core_quad.modulate.a)
	if _core_material != null:
		_core_material.set_shader_parameter("tint_color", tint)
	if _phase1_vortex_material != null and not _phase1_vortex_uses_writhe:
		_phase1_vortex_material.set_shader_parameter("tint_color", tint)


func sync_layout(layout: Dictionary) -> void:
	position = _get_vector2(layout.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var render_scale: float = float(layout.get("render_scale", 1.0))
	scale = Vector2(render_scale, render_scale)
	_layout_synced = true
	visible = _running
	_queue_fx_redraw()


func sync_state(ball_state: Dictionary, next_phase: int, next_elapsed_sec: float) -> void:
	if not _running:
		return
	elapsed_sec = next_elapsed_sec
	phase = next_phase
	phase_progress = float(ball_state.get("phase_progress", 0.0))
	ball_pos = _get_vector2(ball_state.get("pos", start_pos), start_pos)
	ball_scale = float(ball_state.get("scale", 1.0))
	ball_alpha = float(ball_state.get("alpha", 0.0))
	if phase >= 4:
		_enter_outro_idle()
		_queue_fx_redraw()
		return
	if phase >= 2 and not _orbit_rings_phaseout_triggered:
		_orbit_rings_phase2_transition()
	if phase == 3 and not _ray_burst_triggered:
		_trigger_ray_burst()
	_update_phase1_vortex_quad()
	_update_orbit_rings_quad()
	_update_core_quad()
	_update_shards()
	_sync_particles()
	_queue_fx_redraw()


func _enter_outro_idle() -> void:
	# Keep _running, visible, and _layout_synced intact so the intro draw bridge
	# inside the playfield clip can still render the outro residual halo without
	# leaking it to the canvas (and into the left/right pillar columns).
	if _outro_idle_entered:
		return
	_outro_idle_entered = true
	_kill_active_tweens()
	_stop_particles()
	if _phase1_vortex_quad != null:
		_phase1_vortex_quad.visible = false
	if _orbit_rings_quad != null:
		_orbit_rings_quad.visible = false
	if _ray_burst_quad != null:
		_ray_burst_quad.visible = false
	if _core_quad != null:
		_core_quad.visible = false


func tear_down(free_self: bool = false) -> void:
	_running = false
	visible = false
	_layout_synced = false
	_kill_active_tweens()
	_stop_particles()
	if free_self:
		_clear_runtime_refs()
		queue_free()
		return
	for child in get_children():
		child.queue_free()
	_clear_runtime_refs()


func _kill_active_tweens() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if _ray_burst_tween != null and _ray_burst_tween.is_valid():
		_ray_burst_tween.kill()
	_ray_burst_tween = null
	if _ray_burst_flash_tween != null and _ray_burst_flash_tween.is_valid():
		_ray_burst_flash_tween.kill()
	_ray_burst_flash_tween = null
	for tween in [_orbit_rings_intro_tween, _orbit_rings_breath_tween, _orbit_rings_out_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_orbit_rings_intro_tween = null
	_orbit_rings_breath_tween = null
	_orbit_rings_out_tween = null


func _clear_runtime_refs() -> void:
	_shards.clear()
	_playfield_clip = null
	_intro_render_layer = null
	_playfield_accent_layer = null
	_phase1_vortex_quad = null
	_orbit_rings_quad = null
	_ray_burst_quad = null
	_phase1_inflow_particles = null
	_core_quad = null
	_condense_particles = null
	_launch_particles = null
	_phase1_vortex_material = null
	_orbit_rings_material = null
	_core_material = null
	_additive_material = null
	_shards_visible = false
	_phase1_vortex_uses_writhe = false
	_ray_burst_triggered = false
	_ray_burst_absorb_particles_active = false
	_orbit_rings_phaseout_triggered = false
	_layout_synced = false
	_outro_idle_entered = false


func _stop_particles() -> void:
	if _phase1_inflow_particles != null:
		_phase1_inflow_particles.emitting = false
	if _condense_particles != null:
		_condense_particles.emitting = false
	if _launch_particles != null:
		_launch_particles.emitting = false


func get_debug_status() -> Dictionary:
	return {
		"active": _running and visible and _layout_synced,
		"layout_synced": _layout_synced,
		"stage_tint": stage_tint,
		"texture_pieces_ready": bool(build_pipeline_status().get("ball_spawn_intro_texture_pieces_ready", false)),
		"vortex_png_slot": _is_png_texture_loaded(VORTEX_TEXTURE_PATH, _get_vortex_texture()),
		"orbit_rings_png_slot": _is_png_texture_loaded(ORBIT_RINGS_TEXTURE_PATH, _get_orbit_rings_texture()),
		"ray_burst_png_slot": _is_png_texture_loaded(RAY_BURST_TEXTURE_PATH, _get_ray_burst_texture()),
		"vortex_writhe_shader": _phase1_vortex_uses_writhe and WritheEmber.is_material_using_shader(_phase1_vortex_material),
		"orbit_rings_writhe_shader": WritheEmber.is_material_using_shader(_orbit_rings_material),
		"orbit_rings_visible": _orbit_rings_quad != null and _orbit_rings_quad.visible,
		"orbit_rings_phaseout_triggered": _orbit_rings_phaseout_triggered,
		"ray_burst_visible": _ray_burst_quad != null and _ray_burst_quad.visible,
		"ray_burst_triggered": _ray_burst_triggered,
		"playfield_clip_active": (
			_playfield_clip != null
			and _playfield_clip.clip_contents
			and _playfield_clip.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW
			and _playfield_clip.position == PLAYFIELD_CLIP_POSITION
			and _playfield_clip.size == PLAYFIELD_CLIP_SIZE
		),
		"procedural_accents_clipped_to_playfield": (
			_playfield_accent_layer != null
			and _playfield_clip != null
			and _playfield_accent_layer.get_parent() == _playfield_clip
			and _playfield_accent_layer.size == GAME_SIZE
		),
		"intro_renderer_clipped_to_playfield": (
			_intro_render_layer != null
			and _playfield_clip != null
			and _intro_render_layer.get_parent() == _playfield_clip
			and _intro_render_layer.intro == _intro_renderer
			and _intro_renderer != null
		),
		"particles_local_to_clip": _particles_are_local_to_clip(),
		"phase1_inflow_radius_safe": _is_phase1_inflow_radius_safe(),
	}


func _draw() -> void:
	pass


func _draw_clipped_accents(canvas: CanvasItem) -> void:
	if canvas == null:
		return
	if not _running:
		return
	if phase == 1:
		_draw_phase1_accents(canvas)
		return
	var pulse: float = 0.45 + 0.55 * sin(elapsed_sec * 17.0)
	var flash_alpha: float = fx_flash * 0.12 + fx_launch_burst * 0.10
	if flash_alpha > 0.01:
		canvas.draw_rect(Rect2(Vector2.ZERO, GAME_SIZE), _tinted_color(Color(0.58, 0.88, 1.0, flash_alpha)), true)
	var ray_alpha: float = clamp((fx_core_alpha * 0.18 + fx_launch_burst * 0.26) * ball_alpha, 0.0, 0.45)
	if ray_alpha <= 0.01:
		return
	var ray_count := 12
	for i in range(ray_count):
		var angle: float = elapsed_sec * (1.35 + float(i % 3) * 0.16) + TAU * float(i) / float(ray_count)
		var length: float = 70.0 + 28.0 * sin(elapsed_sec * 5.0 + float(i))
		var width: float = 1.4 + 1.6 * pulse + fx_launch_burst * 2.2
		var start: Vector2 = ball_pos + Vector2(cos(angle), sin(angle)) * (ball_render_radius * (1.2 + fx_launch_burst))
		var end: Vector2 = ball_pos + Vector2(cos(angle), sin(angle)) * length
		canvas.draw_line(start, end, _tinted_color(Color(0.68, 0.94, 1.0, ray_alpha * (0.45 + 0.55 * pulse))), width, true)


func _build_children() -> void:
	_playfield_clip = Control.new()
	_playfield_clip.name = "BallSpawnPlayfieldClip"
	_playfield_clip.position = PLAYFIELD_CLIP_POSITION
	_playfield_clip.size = PLAYFIELD_CLIP_SIZE
	_playfield_clip.clip_contents = true
	_playfield_clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_playfield_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_playfield_clip)

	_playfield_accent_layer = PlayfieldAccentLayer.new()
	_playfield_accent_layer.name = "BallSpawnPlayfieldAccentLayer"
	_playfield_accent_layer.host = self
	_playfield_accent_layer.position = Vector2.ZERO
	_playfield_accent_layer.size = GAME_SIZE
	_playfield_accent_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield_accent_layer.z_index = 0
	_playfield_clip.add_child(_playfield_accent_layer)

	_intro_render_layer = IntroSpawnDrawBridge.new()
	_intro_render_layer.name = "BallSpawnIntroDrawBridge"
	_intro_render_layer.intro = _intro_renderer
	_intro_render_layer.position = Vector2.ZERO
	_intro_render_layer.size = GAME_SIZE
	_intro_render_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_render_layer.z_index = 6
	_playfield_clip.add_child(_intro_render_layer)

	var vortex_texture: Texture2D = _get_vortex_texture()
	if vortex_texture != null and WritheEmber.has_preset("ball_spawn_vortex"):
		var vortex_texture_rect := TextureRect.new()
		vortex_texture_rect.name = "BallSpawnVortexTexture"
		vortex_texture_rect.texture = vortex_texture
		vortex_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vortex_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_phase1_vortex_quad = vortex_texture_rect
		_phase1_vortex_material = WritheEmber.build_material("ball_spawn_vortex")
		_phase1_vortex_uses_writhe = true
	else:
		var vortex_fallback_rect := ColorRect.new()
		vortex_fallback_rect.name = "BallSpawnVortexShaderFallback"
		vortex_fallback_rect.color = Color.WHITE
		_phase1_vortex_quad = vortex_fallback_rect
		_phase1_vortex_material = _build_phase1_vortex_shader_material()
		_phase1_vortex_uses_writhe = false
	_phase1_vortex_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase1_vortex_quad.z_index = -8
	_phase1_vortex_quad.material = _phase1_vortex_material
	_add_effect_child(_phase1_vortex_quad)

	var orbit_rings_texture: Texture2D = _get_orbit_rings_texture()
	if orbit_rings_texture != null and WritheEmber.has_preset("ball_spawn_orbit_rings"):
		_orbit_rings_quad = TextureRect.new()
		_orbit_rings_quad.name = "BallSpawnOrbitRingsTexture"
		_orbit_rings_quad.texture = orbit_rings_texture
		_orbit_rings_quad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_orbit_rings_quad.stretch_mode = TextureRect.STRETCH_SCALE
		_orbit_rings_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_orbit_rings_quad.z_index = -6
		_orbit_rings_material = WritheEmber.build_material("ball_spawn_orbit_rings")
		_orbit_rings_quad.material = _orbit_rings_material
		_orbit_rings_quad.modulate = _with_alpha(stage_tint, 0.0)
		_orbit_rings_quad.visible = false
		_add_effect_child(_orbit_rings_quad)

	_core_quad = ColorRect.new()
	_core_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_core_quad.color = Color.WHITE
	_core_quad.z_index = -2
	_core_material = _build_core_shader_material()
	_core_quad.material = _core_material
	_add_effect_child(_core_quad)

	var ray_burst_texture: Texture2D = _get_ray_burst_texture()
	if ray_burst_texture != null:
		_ray_burst_quad = TextureRect.new()
		_ray_burst_quad.name = "BallSpawnRayBurstTexture"
		_ray_burst_quad.texture = ray_burst_texture
		_ray_burst_quad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_ray_burst_quad.stretch_mode = TextureRect.STRETCH_SCALE
		_ray_burst_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ray_burst_quad.z_index = 9
		_ray_burst_quad.material = _additive_material
		_ray_burst_quad.visible = false
		_add_effect_child(_ray_burst_quad)

	_build_shards()
	_phase1_inflow_particles = _make_phase1_inflow_particles()
	_condense_particles = _make_particles("BallSpawnCondenseParticles", false)
	_launch_particles = _make_particles("BallSpawnLaunchParticles", true)
	_add_effect_child(_phase1_inflow_particles)
	_add_effect_child(_condense_particles)
	_add_effect_child(_launch_particles)
	_apply_current_tint()
	_update_phase1_vortex_quad()
	_update_core_quad()


func _add_effect_child(child: Node) -> void:
	if child == null:
		return
	if _playfield_clip != null:
		_playfield_clip.add_child(child)
	else:
		add_child(child)


func _build_shards() -> void:
	if _ball_body_texture == null:
		return
	var tex_w: float = float(_ball_body_texture.get_width())
	var tex_h: float = float(_ball_body_texture.get_height())
	var cell_w: float = tex_w / float(SHARD_COLUMNS)
	var cell_h: float = tex_h / float(SHARD_ROWS)
	_shards.clear()
	for y in range(SHARD_ROWS):
		for x in range(SHARD_COLUMNS):
			var idx: int = y * SHARD_COLUMNS + x
			var region := Rect2(float(x) * cell_w, float(y) * cell_h, cell_w, cell_h)
			var atlas := AtlasTexture.new()
			atlas.atlas = _ball_body_texture
			atlas.region = region
			var sprite := Sprite2D.new()
			sprite.name = "BallSpawnShard%d" % idx
			sprite.texture = atlas
			sprite.centered = true
			sprite.visible = false
			sprite.z_index = 5
			_add_effect_child(sprite)
			var cell_center := Vector2(region.position.x + region.size.x * 0.5, region.position.y + region.size.y * 0.5)
			var final_offset := cell_center - Vector2(tex_w * 0.5, tex_h * 0.5)
			var angle: float = TAU * (float(idx) / float(SHARD_COUNT)) + (0.22 if y % 2 == 0 else -0.18)
			var scatter := Vector2(cos(angle), sin(angle)) * (SHARD_SCATTER_RADIUS + float((idx % 4) * 11))
			_shards.append({
				"sprite": sprite,
				"final_offset": final_offset,
				"scatter": scatter,
				"angle": angle,
				"spin": 1.0 if idx % 2 == 0 else -1.0,
			})


func _make_particles(node_name: String, launch: bool) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.name = node_name
	particles.amount = 72 if launch else 96
	particles.lifetime = 0.58 if launch else 0.78
	particles.one_shot = false
	particles.explosiveness = 0.18 if launch else 0.0
	particles.randomness = 0.72
	particles.fixed_fps = 60
	particles.texture = _glow_texture
	particles.material = _additive_material
	particles.process_material = _build_particle_process_material(Vector3(0.0, -1.0, 0.0), launch)
	particles.emitting = false
	particles.z_index = 8 if launch else 4
	particles.local_coords = true
	return particles


func _make_phase1_inflow_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.name = "BallSpawnPhase1InflowParticles"
	particles.amount = 220
	particles.lifetime = 1.70
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.82
	particles.fixed_fps = 60
	particles.texture = _glow_texture
	particles.material = _additive_material
	particles.process_material = _build_phase1_inflow_process_material()
	particles.emitting = false
	particles.z_index = -4
	particles.local_coords = true
	return particles


func _start_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(false)
	_tween.tween_property(self, "fx_phase1_intensity", 1.0, max(0.10, phase_1_duration - 0.22)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "fx_phase1_flash", 1.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "fx_phase1_flash", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "fx_phase1_intensity", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "fx_core_alpha", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "fx_swirl_strength", 1.0, phase_2_duration * 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "fx_shard_converge", 1.0, phase_2_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "fx_flash", 1.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "fx_flash", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(Callable(self, "_trigger_ray_burst"))
	_tween.tween_property(self, "fx_launch_burst", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "fx_swirl_strength", 0.42, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var phase_3_tail: float = max(0.10, phase_3_duration - 0.28)
	_tween.tween_property(self, "fx_launch_burst", 0.0, phase_3_tail).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "fx_core_alpha", 0.0, phase_3_tail).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _trigger_ray_burst() -> void:
	if _ray_burst_triggered:
		return
	_ray_burst_triggered = true
	if _ray_burst_quad == null:
		return
	if _ray_burst_tween != null and _ray_burst_tween.is_valid():
		_ray_burst_tween.kill()
	if _ray_burst_flash_tween != null and _ray_burst_flash_tween.is_valid():
		_ray_burst_flash_tween.kill()
	var burst_size := RAY_BURST_QUAD_SIZE
	var half_size := Vector2(burst_size, burst_size) * 0.5
	_ray_burst_quad.position = start_pos - half_size
	_ray_burst_quad.size = Vector2(burst_size, burst_size)
	_ray_burst_quad.pivot_offset = half_size
	_ray_burst_quad.scale = Vector2(0.35, 0.35)
	_ray_burst_quad.rotation = 0.0
	_ray_burst_quad.modulate = _with_alpha(stage_tint, 0.0)
	_ray_burst_quad.visible = true
	_set_ray_burst_absorb_particles(true)
	_start_ray_burst_core_flash()

	_ray_burst_tween = create_tween()
	_ray_burst_tween.set_parallel(true)

	# Stage A: the launch ray blooms hard at the spawn point.
	_ray_burst_tween.tween_property(_ray_burst_quad, "scale", Vector2(1.60, 1.60), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_ray_burst_tween.tween_property(_ray_burst_quad, "rotation", deg_to_rad(60.0), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_ray_burst_tween.tween_property(_ray_burst_quad, "modulate:a", 1.0, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Stage B: it spirals into the serve target, reading as energy being
	# pulled into the forming ball.
	_ray_burst_tween.chain().tween_property(_ray_burst_quad, "position", target_pos - half_size, 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	_ray_burst_tween.parallel().tween_property(_ray_burst_quad, "scale", Vector2(0.18, 0.18), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_ray_burst_tween.parallel().tween_property(_ray_burst_quad, "rotation", deg_to_rad(600.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_ray_burst_tween.parallel().tween_property(_ray_burst_quad, "modulate", _get_ray_burst_compression_tint(0.85), 0.55)

	# Stage C: a small residue pulse at the ball, then a fast vanish.
	_ray_burst_tween.chain().tween_property(_ray_burst_quad, "scale", Vector2(0.30, 0.30), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ray_burst_tween.parallel().tween_property(_ray_burst_quad, "modulate:a", 0.42, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ray_burst_tween.chain().tween_property(_ray_burst_quad, "scale", Vector2.ZERO, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_ray_burst_tween.parallel().tween_property(_ray_burst_quad, "modulate:a", 0.0, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_ray_burst_tween.chain().tween_callback(Callable(self, "_finish_ray_burst"))


func _hide_ray_burst() -> void:
	if _ray_burst_quad != null:
		_ray_burst_quad.visible = false


func _trigger_orbit_rings_phase1() -> void:
	if _orbit_rings_quad == null:
		return
	if _orbit_rings_intro_tween != null and _orbit_rings_intro_tween.is_valid():
		_orbit_rings_intro_tween.kill()
	if _orbit_rings_breath_tween != null and _orbit_rings_breath_tween.is_valid():
		_orbit_rings_breath_tween.kill()
	if _orbit_rings_out_tween != null and _orbit_rings_out_tween.is_valid():
		_orbit_rings_out_tween.kill()
	_orbit_rings_phaseout_triggered = false
	_orbit_rings_quad.visible = true
	_orbit_rings_quad.modulate = _with_alpha(stage_tint, 0.0)
	_orbit_rings_quad.scale = Vector2(0.70, 0.70)
	_update_orbit_rings_quad()

	_orbit_rings_intro_tween = create_tween()
	_orbit_rings_intro_tween.set_parallel(true)
	_orbit_rings_intro_tween.tween_property(_orbit_rings_quad, "modulate:a", 0.85, 0.50).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_orbit_rings_intro_tween.tween_property(_orbit_rings_quad, "scale", Vector2.ONE, 0.80).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_orbit_rings_intro_tween.chain().tween_callback(Callable(self, "_start_orbit_rings_breath"))


func _start_orbit_rings_breath() -> void:
	if _orbit_rings_quad == null or _orbit_rings_phaseout_triggered:
		return
	if _orbit_rings_breath_tween != null and _orbit_rings_breath_tween.is_valid():
		_orbit_rings_breath_tween.kill()
	_orbit_rings_breath_tween = create_tween()
	_orbit_rings_breath_tween.set_loops()
	_orbit_rings_breath_tween.tween_property(_orbit_rings_quad, "scale", Vector2(1.05, 1.05), 1.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_orbit_rings_breath_tween.tween_property(_orbit_rings_quad, "scale", Vector2(0.97, 0.97), 1.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _orbit_rings_phase2_transition() -> void:
	if _orbit_rings_phaseout_triggered:
		return
	_orbit_rings_phaseout_triggered = true
	if _orbit_rings_quad == null:
		return
	if _orbit_rings_intro_tween != null and _orbit_rings_intro_tween.is_valid():
		_orbit_rings_intro_tween.kill()
	if _orbit_rings_breath_tween != null and _orbit_rings_breath_tween.is_valid():
		_orbit_rings_breath_tween.kill()
	if _orbit_rings_out_tween != null and _orbit_rings_out_tween.is_valid():
		_orbit_rings_out_tween.kill()
	_orbit_rings_out_tween = create_tween()
	_orbit_rings_out_tween.set_parallel(true)
	_orbit_rings_out_tween.tween_property(_orbit_rings_quad, "modulate:a", 0.0, 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_orbit_rings_out_tween.tween_property(_orbit_rings_quad, "scale", Vector2(0.40, 0.40), 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_orbit_rings_out_tween.chain().tween_callback(Callable(self, "_hide_orbit_rings"))


func _hide_orbit_rings() -> void:
	if _orbit_rings_quad != null:
		_orbit_rings_quad.visible = false


func _finish_ray_burst() -> void:
	_set_ray_burst_absorb_particles(false)
	_hide_ray_burst()
	if _ray_burst_quad != null:
		_ray_burst_quad.modulate = _with_alpha(stage_tint, 0.0)


func _set_ray_burst_absorb_particles(active: bool) -> void:
	_ray_burst_absorb_particles_active = active
	if _condense_particles != null:
		_condense_particles.amount = 160 if active else 96
		_condense_particles.emitting = active or (_running and phase == 2 and ball_alpha > 0.05)


func _start_ray_burst_core_flash() -> void:
	if _core_quad == null:
		return
	_ray_burst_flash_tween = create_tween()
	_ray_burst_flash_tween.tween_interval(0.12)
	_ray_burst_flash_tween.tween_property(_core_quad, "modulate", _get_core_flash_tint(), 0.02).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_ray_burst_flash_tween.chain().tween_property(_core_quad, "modulate", _with_alpha(stage_tint, 1.0), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _update_phase1_vortex_quad() -> void:
	if _phase1_vortex_quad == null:
		return
	var phase1_visible: bool = _running and (phase == 1 or fx_phase1_intensity > 0.02)
	_phase1_vortex_quad.visible = phase1_visible
	if not phase1_visible:
		return
	var quad_size: float = PHASE1_VORTEX_QUAD_SIZE * (0.92 + fx_phase1_intensity * 0.16)
	_phase1_vortex_quad.position = start_pos - Vector2(quad_size, quad_size) * 0.5
	_phase1_vortex_quad.size = Vector2(quad_size, quad_size)
	if _phase1_vortex_material != null:
		_phase1_vortex_material.set_shader_parameter("elapsed", elapsed_sec)
		_phase1_vortex_material.set_shader_parameter("intensity", fx_phase1_intensity)
		if not _phase1_vortex_uses_writhe:
			_phase1_vortex_material.set_shader_parameter("phase_progress", phase_progress if phase == 1 else 1.0)
			_phase1_vortex_material.set_shader_parameter("flash", fx_phase1_flash)


func _update_orbit_rings_quad() -> void:
	if _orbit_rings_quad == null:
		return
	var visible_now: bool = _running and (phase == 1 or _orbit_rings_phaseout_triggered)
	_orbit_rings_quad.visible = _orbit_rings_quad.visible and visible_now
	if not _orbit_rings_quad.visible:
		return
	var rings_size := ORBIT_RINGS_QUAD_SIZE
	var half_size := Vector2(rings_size, rings_size) * 0.5
	_orbit_rings_quad.size = Vector2(rings_size, rings_size)
	_orbit_rings_quad.pivot_offset = half_size
	_orbit_rings_quad.position = start_pos - half_size
	_orbit_rings_quad.rotation = elapsed_sec * 0.25
	if _orbit_rings_material != null:
		_orbit_rings_material.set_shader_parameter("elapsed", elapsed_sec)
		_orbit_rings_material.set_shader_parameter("intensity", fx_phase1_intensity)


func _update_core_quad() -> void:
	if _core_quad == null:
		return
	var quad_size: float = CORE_QUAD_SIZE * (0.82 + ball_scale * 0.24 + fx_launch_burst * 0.36)
	_core_quad.position = ball_pos - Vector2(quad_size, quad_size) * 0.5
	_core_quad.size = Vector2(quad_size, quad_size)
	_core_quad.visible = _running and phase >= 2 and ball_alpha > 0.02
	if _core_material != null:
		_core_material.set_shader_parameter("elapsed", elapsed_sec)
		_core_material.set_shader_parameter("core_alpha", fx_core_alpha * ball_alpha)
		_core_material.set_shader_parameter("swirl_strength", fx_swirl_strength + fx_launch_burst * 0.7)
		_core_material.set_shader_parameter("phase_progress", phase_progress)
		_core_material.set_shader_parameter("launch_burst", fx_launch_burst)


func _update_shards() -> void:
	var visible_now: bool = _running and phase == 2 and ball_alpha > 0.02
	_shards_visible = visible_now
	var source_w: float = float(StageBallSpawnIntroTextureCache.BALL_BODY_TEX_SIZE)
	var target_diam: float = ball_render_radius * BODY_DRAW_DIAMETER_MULT * max(0.25, ball_scale)
	var draw_scale: float = target_diam / max(1.0, source_w)
	var converge: float = clamp(fx_shard_converge, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - converge, 3.0)
	for entry in _shards:
		var sprite: Sprite2D = entry.sprite
		if sprite == null:
			continue
		sprite.visible = visible_now
		if not visible_now:
			continue
		var final_offset: Vector2 = entry.final_offset * draw_scale
		var scatter: Vector2 = entry.scatter * (1.0 - eased)
		var jitter := Vector2(cos(elapsed_sec * 11.0 + entry.angle), sin(elapsed_sec * 9.0 - entry.angle)) * (1.0 - eased) * 4.5
		sprite.position = ball_pos + final_offset + scatter + jitter
		sprite.scale = Vector2(draw_scale, draw_scale) * (0.84 + 0.16 * eased)
		sprite.rotation = entry.spin * (1.0 - eased) * (1.35 + 0.18 * sin(elapsed_sec * 8.0 + entry.angle))
		sprite.modulate = Color(0.86, 0.96, 1.0, clamp(ball_alpha * (1.0 - max(0.0, eased - 0.72) / 0.28), 0.0, 0.88))


func _sync_particles() -> void:
	if _phase1_inflow_particles != null:
		_phase1_inflow_particles.position = start_pos
		_phase1_inflow_particles.emitting = _running and phase == 1 and phase_progress < 0.98
		var phase1_mat: ParticleProcessMaterial = _phase1_inflow_particles.process_material
		if phase1_mat != null:
			var pull: float = clamp(0.55 + fx_phase1_intensity * 0.75 + fx_phase1_flash * 0.70, 0.45, 2.0)
			phase1_mat.radial_accel_min = -360.0 * pull
			phase1_mat.radial_accel_max = -150.0 * pull
			phase1_mat.tangential_accel_min = -110.0 * pull
			phase1_mat.tangential_accel_max = 110.0 * pull
			phase1_mat.color = _tinted_color(Color(0.62 + fx_phase1_flash * 0.22, 0.86, 1.0, 0.45 + fx_phase1_intensity * 0.35))
	if _condense_particles != null:
		_condense_particles.position = ball_pos
		_condense_particles.emitting = _ray_burst_absorb_particles_active or (_running and phase == 2 and ball_alpha > 0.05)
		var condense_mat: ParticleProcessMaterial = _condense_particles.process_material
		if condense_mat != null:
			if _ray_burst_absorb_particles_active:
				condense_mat.radial_accel_min = -560.0
				condense_mat.radial_accel_max = -240.0
				condense_mat.tangential_accel_min = -240.0
				condense_mat.tangential_accel_max = 240.0
				condense_mat.damping_min = 18.0
				condense_mat.damping_max = 54.0
				condense_mat.scale_min = 0.030
				condense_mat.scale_max = 0.120
				condense_mat.color = _tinted_color(Color(1.0, 0.86, 1.0, 0.86))
			else:
				condense_mat.radial_accel_min = -260.0
				condense_mat.radial_accel_max = -90.0
				condense_mat.tangential_accel_min = -160.0
				condense_mat.tangential_accel_max = 160.0
				condense_mat.damping_min = 14.0
				condense_mat.damping_max = 42.0
				condense_mat.scale_min = 0.025
				condense_mat.scale_max = 0.085
				condense_mat.color = _tinted_color(Color(0.86, 0.76, 1.0, 0.72))
	if _launch_particles != null:
		_launch_particles.position = ball_pos
		_launch_particles.emitting = _running and phase == 3 and phase_progress < 0.82
		var mat: ParticleProcessMaterial = _launch_particles.process_material
		if mat != null:
			var trail_dir := Vector3(0.0, -1.0, 0.0) if player_serves else Vector3(0.0, 1.0, 0.0)
			mat.direction = trail_dir
			mat.color = _tinted_color(Color(0.66, 0.92, 1.0, 0.78))


func _draw_phase1_accents(canvas: CanvasItem) -> void:
	var intensity: float = clamp(fx_phase1_intensity, 0.0, 1.0)
	var flash: float = clamp(fx_phase1_flash, 0.0, 1.0)
	if flash > 0.01:
		canvas.draw_rect(Rect2(Vector2.ZERO, GAME_SIZE), _tinted_color(Color(0.65, 0.90, 1.0, flash * 0.20)), true)
	var ray_alpha: float = clamp(0.05 + intensity * 0.20 + flash * 0.34, 0.0, 0.50)
	var pulse: float = 0.45 + 0.55 * sin(elapsed_sec * 12.0)
	for i in range(16):
		var angle: float = elapsed_sec * (1.25 + float(i % 4) * 0.14) + TAU * float(i) / 16.0
		var inner: float = 18.0 + intensity * 22.0
		var length: float = 110.0 + intensity * 74.0 + 18.0 * sin(elapsed_sec * 4.0 + float(i))
		var start: Vector2 = start_pos + Vector2(cos(angle), sin(angle)) * inner
		var end: Vector2 = start_pos + Vector2(cos(angle), sin(angle)) * length
		var col := _tinted_color(Color(0.58 + 0.24 * pulse, 0.82, 1.0, ray_alpha * (0.35 + 0.65 * pulse)))
		canvas.draw_line(start, end, col, 1.0 + intensity * 1.5 + flash * 2.4, true)


func _queue_fx_redraw() -> void:
	queue_redraw()
	if _playfield_accent_layer != null:
		_playfield_accent_layer.queue_redraw()
	if _intro_render_layer != null:
		_intro_render_layer.queue_redraw()


static func _build_phase1_vortex_shader_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float intensity = 0.0;
uniform float phase_progress = 0.0;
uniform float flash = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0);

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float r = length(p);
	float angle = atan(p.y, p.x);
	float outer = smoothstep(1.06, 0.10, r);
	float center_hole = smoothstep(0.03 + phase_progress * 0.08, 0.26 + phase_progress * 0.20, r);
	float pull_mask = outer * center_hole;
	float spiral_a = sin(angle * 8.0 - elapsed * 4.8 + r * (19.0 + intensity * 7.0));
	float spiral_b = sin(angle * -5.0 + elapsed * 3.4 + r * (27.0 - intensity * 4.0));
	float band = max(0.0, spiral_a) * 0.62 + max(0.0, spiral_b) * 0.38;
	float ring_phase = fract(r * (5.8 + intensity * 3.2) - elapsed * (0.48 + intensity * 1.45));
	float rings = smoothstep(0.48, 0.40, abs(ring_phase - 0.5));
	float scan = 0.72 + 0.28 * sin((UV.y + UV.x * 0.14) * 180.0 + elapsed * 18.0);
	float core_pull = smoothstep(0.72, 0.0, r) * phase_progress;
	float alpha = (0.10 + intensity * 0.36) * pull_mask * scan * (band * 0.45 + rings * 0.34 + core_pull * 0.26);
	alpha += flash * smoothstep(0.88, 0.0, r) * 0.26;
	vec3 cyan = vec3(0.28, 0.82, 1.0);
	vec3 magenta = vec3(1.0, 0.48, 0.94);
	vec3 white_blue = vec3(0.84, 0.96, 1.0);
	vec3 color = mix(cyan, magenta, clamp(max(0.0, spiral_b) + r * 0.25, 0.0, 1.0));
	color = mix(color, white_blue, flash * 0.55 + core_pull * 0.18);
	COLOR = vec4(color * tint_color.rgb, clamp(alpha * tint_color.a, 0.0, 0.78));
}
"""
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _build_core_shader_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float elapsed = 0.0;
uniform float core_alpha = 0.0;
uniform float swirl_strength = 0.0;
uniform float phase_progress = 0.0;
uniform float launch_burst = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0);

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float r = length(p);
	float angle = atan(p.y, p.x);
	float inner_mask = smoothstep(1.02, 0.05, r);
	float outer_mask = smoothstep(1.18, 0.18, r);
	float spiral = sin(angle * 7.0 - elapsed * 8.5 + r * (18.0 + swirl_strength * 6.0));
	float spiral_band = max(0.0, spiral) * outer_mask;
	float ring_phase = fract(r * (5.2 + launch_burst * 2.4) - elapsed * (0.82 + launch_burst * 1.6));
	float ring = smoothstep(0.50, 0.42, abs(ring_phase - 0.5)) * outer_mask;
	float scan = 0.72 + 0.28 * sin(UV.y * 138.0 + elapsed * 22.0);
	float core = smoothstep(0.42, 0.0, r) * (0.48 + 0.52 * sin(elapsed * 13.0));
	float alpha = core_alpha * scan * (core * 0.36 + spiral_band * 0.22 + ring * 0.34 + launch_burst * inner_mask * 0.24);
	vec3 color = mix(vec3(0.30, 0.72, 1.0), vec3(0.96, 0.72, 1.0), clamp(spiral_band + phase_progress * 0.35, 0.0, 1.0));
	COLOR = vec4(color * tint_color.rgb, clamp(alpha * tint_color.a, 0.0, 0.85));
}
"""
	@warning_ignore("shadowed_variable_base_class")
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _build_phase1_inflow_process_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 28.0
	mat.radial_accel_min = -360.0
	mat.radial_accel_max = -150.0
	mat.tangential_accel_min = -110.0
	mat.tangential_accel_max = 110.0
	mat.damping_min = 8.0
	mat.damping_max = 32.0
	mat.scale_min = 0.026
	mat.scale_max = 0.088
	mat.color = Color(0.62, 0.86, 1.0, 0.64)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = PHASE1_INFLOW_EMISSION_RADIUS
	return mat


static func _build_particle_process_material(direction: Vector3, launch: bool) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = direction
	mat.spread = 68.0 if launch else 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 120.0 if launch else 26.0
	mat.initial_velocity_max = 260.0 if launch else 96.0
	mat.radial_accel_min = -35.0 if launch else -260.0
	mat.radial_accel_max = 40.0 if launch else -90.0
	mat.tangential_accel_min = -90.0 if launch else -160.0
	mat.tangential_accel_max = 90.0 if launch else 160.0
	mat.damping_min = 32.0 if launch else 14.0
	mat.damping_max = 90.0 if launch else 42.0
	mat.scale_min = 0.035 if launch else 0.025
	mat.scale_max = 0.105 if launch else 0.085
	mat.color = Color(0.66, 0.92, 1.0, 0.78) if launch else Color(0.86, 0.76, 1.0, 0.72)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 16.0 if launch else 76.0
	return mat


static func _get_vortex_texture() -> Texture2D:
	if _vortex_texture != null:
		return _vortex_texture
	_vortex_texture = ProjectResourceLoader.load_texture(VORTEX_TEXTURE_PATH)
	return _vortex_texture


static func _get_orbit_rings_texture() -> Texture2D:
	if _orbit_rings_texture != null:
		return _orbit_rings_texture
	_orbit_rings_texture = ProjectResourceLoader.load_texture(ORBIT_RINGS_TEXTURE_PATH)
	return _orbit_rings_texture


static func _get_ray_burst_texture() -> Texture2D:
	if _ray_burst_texture != null:
		return _ray_burst_texture
	_ray_burst_texture = ProjectResourceLoader.load_texture(RAY_BURST_TEXTURE_PATH)
	return _ray_burst_texture


static func _is_png_texture_loaded(path: String, texture: Texture2D) -> bool:
	if texture == null:
		return false
	var loaded: Texture2D = ProjectResourceLoader.load_texture(path)
	return loaded != null and loaded == texture


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


func _particles_are_local_to_clip() -> bool:
	for particles in [_phase1_inflow_particles, _condense_particles, _launch_particles]:
		if particles != null and not particles.local_coords:
			return false
	return (
		_phase1_inflow_particles != null
		and _condense_particles != null
		and _launch_particles != null
	)


func _is_phase1_inflow_radius_safe() -> bool:
	if _phase1_inflow_particles == null:
		return false
	var mat: ParticleProcessMaterial = _phase1_inflow_particles.process_material
	if mat == null:
		return false
	var max_radius: float = min(start_pos.x, GAME_SIZE.x - start_pos.x, start_pos.y, GAME_SIZE.y - start_pos.y)
	return mat.emission_sphere_radius <= max_radius


func _tinted_color(color: Color) -> Color:
	return Color(color.r * stage_tint.r, color.g * stage_tint.g, color.b * stage_tint.b, color.a * stage_tint.a)


func _get_ray_burst_compression_tint(alpha: float) -> Color:
	return Color(
		stage_tint.r * 1.50,
		stage_tint.g * 0.95,
		stage_tint.b * 1.10,
		alpha * stage_tint.a
	)


func _get_core_flash_tint() -> Color:
	return Color(
		stage_tint.r * 2.0,
		stage_tint.g * 2.0,
		stage_tint.b * 2.0,
		stage_tint.a
	)


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
