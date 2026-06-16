extends Node2D

# Prewarms Vulkan/GPU pipeline state objects for the hot render paths so the
# first real-gameplay use of each shader+material combo does not stall at
# 30-300 ms while the driver compiles the PSO. Spawned as a hidden child of
# the battle scene during boot warmup, runs staged `_draw()` passes for a few
# frames, then self-destructs.
#
# Warmup scope:
#   - ImpactFlare (burst/glow/sparkle) - air strike + ball pulse paths
#   - ImpactShockwave (full ring) - air strike post-hit
#   - EnergyBall core/highlight/saturn-ring texture draw paths
#   - Viper hover sheet (left/right) - viper airborne pose
#   - Pillar HUD / overlay primitives, frame textures, orb liquid, and text
#   - Stage 1 playfield texture+primitive combos
#   - Stage 1 round-result player / Dalji pose texture-region uploads
#   - Skill cut-in sheets (power-smash / ghost-smash / phantom-kick) VRAM upload
#   - Stage 2 center playfield and falling-leaf polygon/line primitives
#   - Weather particles / warning panel primitives
#   - Timer-stack first-use script path plus common timer-bar primitives
#   - Plaza arrival/exit warp pillar shader, additive sprites, and particles
#
# Deliberately out of scope:
#   - character_info / perk_debug overlay UI
#   - Stage-specific boss skill VFX (each stage handles its own assets)

const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const EnergyBallTextureCache := preload("res://scripts/ball/energy_ball_texture_cache.gd")
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const HorizontalTimerGaugeStack := preload("res://scripts/hud/horizontal_timer_gauge_stack.gd")
const PillarOrbDrawer := preload("res://scripts/hud/pillar_orb_drawer.gd")
const PillarStatusOrbRenderer := preload("res://scripts/hud/pillar_status_orb_renderer.gd")
const ActiveItemThrowMolotovRenderer := preload("res://scripts/items/active_item_throw_molotov_renderer.gd")
const WeatherEventRenderer := preload("res://scripts/stages/common/weather_event_renderer.gd")
const Stage2PillarAssets := preload("res://scripts/stages/stage2/stage2_pillar_assets.gd")
const Stage3PillarBackground := preload("res://scripts/stages/stage3/stage3_pillar_background.gd")
const SkillCutinOverlayHost := preload("res://scripts/hud/skill_cutin_overlay_host.gd")
const CharacterTopdownRimShader := preload("res://shaders/character_topdown_rim.gdshader")

const VIPER_HOVER_LEFT_PATH := "res://assets/sprites/characters/viper/viper_subculture_left_hover_sheet.png"
const VIPER_HOVER_RIGHT_PATH := "res://assets/sprites/characters/viper/viper_subculture_right_hover_sheet.png"

# Park draws off-screen so the warmup never touches on-screen pixels even if
# the canvas item ignores its own near-zero modulate alpha.
const OFFSCREEN_POSITION := Vector2(-100000.0, -100000.0)

# Draw one warmup family per frame so the driver never has to compile every
# boot PSO candidate in a single visible transition frame. Keep two extra
# frames after the last draw to let the render server flush before freeing.
const WARMUP_DRAW_STEPS := 17
const POST_WARMUP_FLUSH_FRAMES := 2
const LIFETIME_FRAMES := WARMUP_DRAW_STEPS + POST_WARMUP_FLUSH_FRAMES

const DashTokenBoostFxHost := preload("res://scripts/hud/dash_token_boost_fx_host.gd")
const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")
const BossElectrocutionFieldHost := preload("res://scripts/effects/boss_electrocution_field_fx_host.gd")
const PlazaWarpPillarFxHost := preload("res://scripts/plaza/plaza_warp_pillar_fx_host.gd")

var _frames_remaining: int = LIFETIME_FRAMES
var _warmup_step_index: int = 0
var _flush_frames_after_warmup: int = 0
var _texture_cache: Dictionary = {}
var _pillar_drawer: Object = PillarOrbDrawer.new()
var _status_orb_renderer: Object = PillarStatusOrbRenderer.new()
var _timer_stack: Object = HorizontalTimerGaugeStack.new()
var _weather_renderer: Object = WeatherEventRenderer.new()
var _weather_state: Object = PsoWeatherWarmupState.new()
var _boost_fx_host: Node = null
var _starpoint_fx_host: Node = null
var _plaza_warp_fx_host: Node = null


class PsoWeatherWarmupState:
	extends RefCounted

	var weather_type := "fire"

	func get_weather_context() -> Dictionary:
		return {
			"type": weather_type,
			"active": true,
			"warning_text": "WEATHER",
			"warning_timer_frames": 90.0,
			"end_text": "",
			"end_timer_frames": 0.0,
		}

	func get_render_particles() -> Array:
		return [
			{"kind": "rain", "x": 24.0, "y": 20.0, "life": 1.0, "max_life": 1.0, "length": 20.0, "color": Color(0.8, 0.95, 1.0, 1.0)},
			{"kind": "hail", "x": 52.0, "y": 28.0, "life": 0.8, "max_life": 1.0, "size": 7.0, "color": Color(0.8, 0.95, 1.0, 1.0)},
			{"kind": "hail_impact", "x": 82.0, "y": 34.0, "life": 0.7, "max_life": 1.0, "size": 5.0, "color": Color(0.8, 0.95, 1.0, 1.0)},
			{"kind": "hail_burst", "x": 112.0, "y": 30.0, "life": 0.7, "max_life": 1.0, "size": 9.0, "angle": 0.4, "color": Color(0.8, 0.95, 1.0, 1.0)},
			{"kind": "hail_shard", "x": 142.0, "y": 26.0, "life": 0.7, "max_life": 1.0, "size": 4.0, "angle": 0.8, "color": Color(0.8, 0.95, 1.0, 1.0)},
			{"kind": "fire", "x": 172.0, "y": 30.0, "life": 0.9, "max_life": 1.0, "size": 4.0, "color": Color(1.0, 0.45, 0.12, 1.0)},
			{"kind": "fire_explosion", "x": 204.0, "y": 32.0, "life": 0.8, "max_life": 1.0, "size": 6.0, "color": Color(1.0, 0.45, 0.12, 1.0)},
			{"kind": "fire_spark", "x": 236.0, "y": 26.0, "life": 0.8, "max_life": 1.0, "size": 3.0, "angle": 0.5, "length": 18.0, "color": Color(1.0, 0.75, 0.18, 1.0)},
			{"kind": "ice", "x": 268.0, "y": 30.0, "life": 0.8, "max_life": 1.0, "size": 5.0, "color": Color(0.8, 0.95, 1.0, 1.0)},
			{"kind": "sand", "x": 300.0, "y": 30.0, "life": 0.8, "max_life": 1.0, "size": 4.0, "color": Color(0.9, 0.72, 0.36, 1.0)},
			{"kind": "wind", "x": 332.0, "y": 30.0, "life": 0.8, "max_life": 1.0, "size": 3.0, "vx": 5.0, "color": Color(0.78, 0.96, 1.0, 1.0)},
		]

	func get_sand_visual_segments() -> Array:
		return [
			{"rect": Rect2(18.0, 52.0, 64.0, 9.0), "depth": 70.0},
			{"rect": Rect2(92.0, 54.0, 48.0, 7.0), "depth": 42.0},
		]


func _ready() -> void:
	# Stack the prewarmer below every gameplay layer and lock its position
	# off-screen. Alpha is kept slightly above zero so the driver cannot
	# early-out before issuing the draw call.
	z_index = -4096
	z_as_relative = false
	position = OFFSCREEN_POSITION
	modulate = Color(1.0, 1.0, 1.0, 0.01)
	# Attach a dedicated boost FX host as a child so its shader-material quads
	# can be issued off-screen during the dash orb prewarm pass. The host's own
	# Sprite2D slots inherit the prewarmer's offscreen modulate, so even if the
	# slot position math placed them on-screen the alpha would dim them to zero.
	# Make sure the static shader-resource / white-texture caches on both FX host
	# classes are populated before we instantiate the hosts themselves, so the
	# slot-pool build path doesn't race the texture cache.
	DashTokenBoostFxHost.prewarm_assets()
	CommonStarpointVisualHost.prewarm_assets()
	# Shared boss electrocution field: load the 3 VFX textures + writhe-ember
	# electric material at boot. The writhe-ember shader and additive GPUParticles
	# PSOs are already warmed by the inferno / EMP hosts, so a resource prewarm
	# (no extra offscreen draw pass) is enough to avoid a first-shock hitch.
	BossElectrocutionFieldHost.prewarm_assets()
	# Plaza arrival/exit can be the first visible moment after the result scene,
	# so its pillar shader/particle combo needs an actual offscreen draw pass
	# here rather than only a static texture/material cache warmup.
	PlazaWarpPillarFxHost.prewarm_assets()
	_boost_fx_host = DashTokenBoostFxHost.new()
	_boost_fx_host.name = "BoostFxHost_pso"
	add_child(_boost_fx_host)
	# Common starpoint host: needs offscreen draws of normal-palette + detector
	# shimmer + gold-palette variants so each shader branch compiles before the
	# first balloon / rock / bird scoring frame.
	_starpoint_fx_host = CommonStarpointVisualHost.new()
	_starpoint_fx_host.name = "StarpointFxHost_pso"
	add_child(_starpoint_fx_host)
	_plaza_warp_fx_host = PlazaWarpPillarFxHost.new()
	_plaza_warp_fx_host.name = "PlazaWarpPillarFxHost_pso"
	add_child(_plaza_warp_fx_host)
	queue_redraw()


func _process(_delta: float) -> void:
	_frames_remaining -= 1
	if _warmup_step_index >= WARMUP_DRAW_STEPS:
		_flush_frames_after_warmup += 1
	if _frames_remaining <= 0 or _flush_frames_after_warmup >= POST_WARMUP_FLUSH_FRAMES:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _warmup_step_index >= WARMUP_DRAW_STEPS:
		return
	_prewarm_draw_step(_warmup_step_index)
	_warmup_step_index += 1


func _prewarm_draw_step(step_index: int) -> void:
	match step_index:
		0:
			_prewarm_impact_textures()
		1:
			_prewarm_energy_ball_textures()
		2:
			_prewarm_viper_hover_sheet()
		3:
			_prewarm_pillar_overlay_primitives()
		4:
			_prewarm_skill_icon_textures()
		5:
			_prewarm_timer_stack_primitives()
		6:
			_prewarm_weather_primitives()
		7:
			_prewarm_playfield_primitives()
		8:
			_prewarm_stage2_center_primitives()
		9:
			_prewarm_stage2_leaf_primitives()
		10:
			_prewarm_common_starpoint_drop_shader()
		11:
			_prewarm_stage2_pillar_background_textures()
		12:
			_prewarm_stage3_pillar_background_textures()
		13:
			_prewarm_character_topdown_rim_shader()
		14:
			_prewarm_stage1_result_pose_textures()
		15:
			_prewarm_skill_cutin_sheets()
		16:
			_prewarm_plaza_warp_pillar_shader_states()


# Issue the same texture draw calls the air-strike / paddle-hit feedback path
# uses so Vulkan compiles the textured-quad PSOs (with the additive blend
# behaviour the cache helpers route through `draw_texture_rect`).
func _prewarm_impact_textures() -> void:
	ImpactFlareTextureCache.draw_burst(self, Vector2.ZERO, 40.0, Color.WHITE, 0.5)
	ImpactFlareTextureCache.draw_glow(self, Vector2.ZERO, 30.0, Color.WHITE, 0.5)
	ImpactFlareTextureCache.draw_sparkle(self, Vector2.ZERO, 25.0, Color.WHITE, 0.5)
	ImpactShockwaveTextureCache.draw_full_ring(self, Vector2.ZERO, 30.0, Color.WHITE, 0.5)


func _prewarm_energy_ball_textures() -> void:
	var center := Vector2(96.0, 48.0)
	ImpactFlareTextureCache.draw_glow(self, center + Vector2(-48.0, 0.0), 30.0, Color(0.60, 0.90, 1.0, 1.0), 0.24)
	EnergyBallTextureCache.draw_core(self, center, 28.0, Color(0.76, 0.96, 1.0, 1.0), 0.72)
	EnergyBallTextureCache.draw_core(self, center + Vector2(72.0, 0.0), 18.0, Color.WHITE, 0.65)
	EnergyBallTextureCache.draw_highlight(self, center + Vector2(132.0, -8.0), 12.0, Color.WHITE, 0.55)
	EnergyBallTextureCache.draw_saturn_ring(
		self,
		center + Vector2(200.0, 0.0),
		34.0,
		deg_to_rad(18.0),
		0.90,
		Color(0.70, 0.92, 1.0, 1.0),
		0.34,
		false
	)
	EnergyBallTextureCache.draw_saturn_ring(
		self,
		center + Vector2(290.0, 0.0),
		38.0,
		deg_to_rad(-28.0),
		1.05,
		Color(0.94, 0.72, 1.0, 1.0),
		0.42,
		true
	)
	ImpactFlareTextureCache.draw_sparkle(self, center + Vector2(380.0, 0.0), 14.0, Color.WHITE, 0.40)


# Mirror the runtime hover-sheet draw: `draw_texture_rect_region` with the
# 160x160 chibi cell. The exact rect doesn't matter for PSO caching - only
# the (texture format, blend mode, vertex layout) triple does.
func _prewarm_viper_hover_sheet() -> void:
	var cell := Rect2(Vector2.ZERO, Vector2(160.0, 160.0))
	var hover_left: Texture2D = _get_texture(VIPER_HOVER_LEFT_PATH)
	if hover_left != null:
		draw_texture_rect_region(hover_left, cell, cell)
	var hover_right: Texture2D = _get_texture(VIPER_HOVER_RIGHT_PATH)
	if hover_right != null:
		draw_texture_rect_region(
			hover_right,
			Rect2(Vector2(170.0, 0.0), Vector2(160.0, 160.0)),
			cell
		)


func _prewarm_character_topdown_rim_shader() -> void:
	var hover_left: Texture2D = _get_texture(VIPER_HOVER_LEFT_PATH)
	if hover_left == null:
		return
	var previous_material: Material = material
	var rim_material := ShaderMaterial.new()
	rim_material.shader = CharacterTopdownRimShader
	rim_material.set_shader_parameter("rim_intensity", 0.65)
	rim_material.set_shader_parameter("rim_color", Color(0.85, 0.95, 1.0, 1.0))
	rim_material.set_shader_parameter("rim_offset_px", 2.0)
	rim_material.set_shader_parameter("sprite_pixel_size", Vector2(
		max(1.0, float(hover_left.get_width())),
		max(1.0, float(hover_left.get_height()))
	))
	material = rim_material
	draw_texture_rect_region(
		hover_left,
		Rect2(Vector2(340.0, 0.0), Vector2(160.0, 160.0)),
		Rect2(Vector2.ZERO, Vector2(160.0, 160.0)),
		Color.WHITE,
		false,
		true
	)
	material = previous_material


# Pillar overlay showed `draw.pillar_overlay.total max=134 ms` on the first
# frame and `avg=2.71 ms` after caching. The HUD reaches every primitive
# class - filled rect, outlined rect, filled circle, arc, polyline - so
# cover each so the HUD's first real-gameplay frame doesn't recompile them.
func _prewarm_pillar_overlay_primitives() -> void:
	_prewarm_pillar_hud_primitives()
	var gauge_frame := _get_texture(BattleResources.GAUGE_ORB_FRAME_TEXTURE_PATH)
	var dash_frame := _get_texture(BattleResources.DASH_TOKEN_FRAME_TEXTURE_PATH)
	var skill_frame := _get_texture(BattleResources.SKILL_ORB_FRAME_TEXTURE_PATH)
	var skill_cluster_frame := _get_texture(BattleResources.VIPER_SKILL_CLUSTER_FRAME_TEXTURE_PATH)

	if skill_frame != null:
		draw_texture_rect(skill_frame, Rect2(0.0, 150.0, 60.0, 60.0), false, Color(1.0, 1.0, 1.0, 0.90))
	if skill_cluster_frame != null:
		draw_texture_rect(skill_cluster_frame, Rect2(70.0, 150.0, 170.0, 40.0), false, Color(1.0, 1.0, 1.0, 0.86))
	_status_orb_renderer.draw_gauge_orb(
		self,
		Vector2(60.0, 250.0),
		38.0,
		1.35,
		1.0,
		{
			"pillar_drawer": _pillar_drawer,
			"gauge_value": 500.0,
			"gauge_max": 500.0,
			"flash_timer": 0.35,
			"flash_duration": 0.55,
			"frame_texture": gauge_frame,
			"frame_spin_angle": 24.0,
		}
	)
	_status_orb_renderer.draw_dash_orb(
		self,
		Vector2(170.0, 250.0),
		38.0,
		1.65,
		1.0,
		{
			"pillar_drawer": _pillar_drawer,
			"tokens": 1,
			"max_tokens": 3,
			"charge_progress": 0.66,
			"charge_timer": 20.0,
			"recharge_frames": 60.0,
			"flash_timer": 0.42,
			"flash_duration": 0.55,
			"dash_divider_anim_progress": 0.7,
			"dash_recovering": true,
			"boost_charging_active": true,
			"frame_texture": dash_frame,
			"frame_spin_angle": -32.0,
		}
	)
	_status_orb_renderer.draw_dash_orb(
		self,
		Vector2(280.0, 250.0),
		38.0,
		1.85,
		1.0,
		{
			"pillar_drawer": _pillar_drawer,
			"tokens": 1,
			"max_tokens": 1,
			"charge_progress": 1.0,
			"charge_timer": 0.0,
			"recharge_frames": 1.0,
			"flash_timer": 0.0,
			"flash_duration": 0.55,
			"dash_divider_anim_progress": 1.0,
			"compact_fallback_frame": true,
			"show_half_label": false,
			"glass_rim_color": Color(0.86, 0.56, 1.0, 1.0),
			"orb_outer_glow_color": Color(0.62, 0.26, 1.0, 1.0),
			"orb_metal_dark": Color(0.10, 0.06, 0.16, 1.0),
			"orb_metal_mid": Color(0.30, 0.20, 0.44, 1.0),
			"orb_metal_light": Color(0.62, 0.46, 0.78, 1.0),
			"orb_gem_core": Color(0.58, 0.20, 0.88, 1.0),
			"orb_background_outer": Color(0.08, 0.04, 0.14, 1.0),
			"orb_background_inner": Color(0.22, 0.11, 0.34, 1.0),
			"token_liquid_top": Color(0.72, 0.34, 1.0, 1.0),
			"token_liquid_bottom": Color(0.20, 0.08, 0.34, 1.0),
			"token_wave_glow": Color(0.92, 0.76, 1.0, 1.0),
			"token_inner_glow": Color(0.88, 0.64, 1.0, 1.0),
			"idle_ring_color": Color(0.78, 0.42, 1.0, 1.0),
		}
	)
	_prewarm_dash_token_boost_shader_states(dash_frame)


# Exercise the three live boost FX host shader paths so the GPU compiles each
# variant of dash_token_boost_ring.gdshader before the first real dash boost
# event. Without this, the first frame that triggers a refund / sector / half
# ready overlay would block on PSO compile and show as a frame hitch.
func _prewarm_dash_token_boost_shader_states(dash_frame: Texture2D) -> void:
	if _boost_fx_host == null or not _boost_fx_host.has_method("begin_frame"):
		return
	_boost_fx_host.begin_frame()
	# State A: rainbow refund only - mimics "boost charging pending dash refund"
	# (player just earned a free dash, refund is queued but the next token slot
	# is not yet actively filling).
	_status_orb_renderer.draw_dash_orb(
		self,
		Vector2(400.0, 250.0),
		38.0,
		2.0,
		1.0,
		{
			"pillar_drawer": _pillar_drawer,
			"tokens": 3,
			"max_tokens": 3,
			"charge_progress": 0.0,
			"charge_timer": 0.0,
			"recharge_frames": 60.0,
			"boost_charging_pending_dash_refund": true,
			"boost_fx_host": _boost_fx_host,
			"frame_texture": dash_frame,
		}
	)
	# State B: sector boost actively charging a specific token slot. Combines
	# sector_intensity + rainbow_intensity inside the shader.
	_status_orb_renderer.draw_dash_orb(
		self,
		Vector2(490.0, 250.0),
		38.0,
		2.1,
		1.0,
		{
			"pillar_drawer": _pillar_drawer,
			"tokens": 1,
			"max_tokens": 3,
			"charge_progress": 0.66,
			"charge_timer": 20.0,
			"recharge_frames": 60.0,
			"boost_charging_active": true,
			"boost_charging_token_index": 1,
			"boost_fx_host": _boost_fx_host,
			"frame_texture": dash_frame,
		}
	)
	# State C: half-ready blink (empty tokens, no recovery, HALF label gating
	# the inner pulse glow). Exercises the half_ready_intensity path.
	_status_orb_renderer.draw_dash_orb(
		self,
		Vector2(580.0, 250.0),
		38.0,
		2.2,
		1.0,
		{
			"pillar_drawer": _pillar_drawer,
			"tokens": 0,
			"max_tokens": 3,
			"charge_progress": 0.0,
			"charge_timer": 0.0,
			"recharge_frames": 60.0,
			"dash_recovering": false,
			"dash_stun_timer": 0.0,
			"dash_available_timer": 0.0,
			"dash_active": false,
			"show_half_label": true,
			"boost_fx_host": _boost_fx_host,
			"frame_texture": dash_frame,
		}
	)
	# State D: plasma ball recovery (dash mid-use / dash recovering). Exercises
	# the plasma_ball_intensity path which replaces the legacy CPU recovery
	# sparks + chain arcs + seal block.
	_status_orb_renderer.draw_dash_orb(
		self,
		Vector2(670.0, 250.0),
		38.0,
		2.3,
		1.0,
		{
			"pillar_drawer": _pillar_drawer,
			"tokens": 0,
			"max_tokens": 1,
			"charge_progress": 0.4,
			"charge_timer": 36.0,
			"recharge_frames": 60.0,
			"dash_recovering": true,
			"dash_stun_timer": 0.0,
			"dash_available_timer": 0.0,
			"dash_active": false,
			"show_half_label": false,
			"boost_fx_host": _boost_fx_host,
			"frame_texture": dash_frame,
		}
	)
	_boost_fx_host.end_frame()


func _prewarm_skill_icon_textures() -> void:
	var icon_paths: Array = []
	icon_paths.append_array(BattleResources.SMASHER_SKILL_ICON_PATHS.values())
	icon_paths.append_array(BattleResources.VIPER_SKILL_ICON_PATHS.values())
	icon_paths.append_array(BattleResources.COMMANDO_SKILL_ICON_PATHS.values())
	for index in range(icon_paths.size()):
		var texture := _get_texture(str(icon_paths[index]))
		if texture == null:
			continue
		var col: int = index % 10
		var row: int = int(float(index) / 10.0)
		draw_texture_rect(
			texture,
			Rect2(16.0 + float(col) * 28.0, 430.0 + float(row) * 28.0, 24.0, 24.0),
			false,
			Color(1.0, 1.0, 1.0, 0.82)
		)


func _prewarm_plaza_warp_pillar_shader_states() -> void:
	if _plaza_warp_fx_host == null or not is_instance_valid(_plaza_warp_fx_host):
		return
	if not _plaza_warp_fx_host.has_method("sync_state"):
		return
	_plaza_warp_fx_host.sync_state(
		[
			{
				"screen_pos": Vector2(40.0, 40.0),
				"progress": 0.50,
				"phase": "arrive",
				"strength": 1.0,
			},
			{
				"screen_pos": Vector2(134.0, 40.0),
				"progress": 0.50,
				"phase": "exit",
				"strength": 0.66,
			},
		],
		true
	)


func _prewarm_pillar_hud_primitives() -> void:
	draw_rect(Rect2(0.0, 0.0, 40.0, 3.0), Color(0.25, 0.95, 1.0, 0.88))
	draw_rect(Rect2(0.0, 10.0, 40.0, 3.0), Color(1.0, 0.22, 0.18, 0.92))
	draw_rect(Rect2(50.0, 0.0, 40.0, 40.0), Color(0.02, 0.05, 0.08, 0.58))
	draw_rect(Rect2(50.0, 0.0, 40.0, 40.0), Color(0.30, 0.78, 1.0, 0.90), false, 2.0)
	draw_circle(Vector2(100.0, 20.0), 12.0, Color(0.35, 1.0, 1.0, 0.70))
	draw_circle(Vector2(120.0, 20.0), 8.0, Color(1.0, 0.84, 0.30, 0.82))
	draw_arc(Vector2(150.0, 20.0), 14.0, 0.0, PI * 1.5, 32, Color(0.78, 0.55, 1.0, 0.8), 3.0)
	draw_polyline(
		PackedVector2Array([
			Vector2(170.0, 0.0),
			Vector2(190.0, 40.0),
			Vector2(210.0, 0.0),
		]),
		Color.WHITE,
		1.5
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(225.0, 2.0),
			Vector2(255.0, 18.0),
			Vector2(244.0, 48.0),
			Vector2(214.0, 42.0),
		]),
		Color(1.0, 0.95, 0.65, 0.48)
	)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(224.0, 84.0), "500/500", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color.WHITE)
		draw_string(font, Vector2(224.0, 104.0), "HALF", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.72, 0.76, 1.0, 0.82))


func _prewarm_stage2_leaf_primitives() -> void:
	var maple_points := PackedVector2Array()
	var center := Vector2(320.0, 220.0)
	var size := 13.0
	for idx in range(10):
		var angle: float = float(idx) * TAU / 10.0
		var radius: float = size * (1.15 if idx % 2 == 0 else 0.52)
		maple_points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(maple_points, Color(0.02, 0.06, 0.02, 0.18))
	for idx in range(maple_points.size()):
		maple_points[idx] = maple_points[idx] - Vector2(2.0, 2.0)
	draw_colored_polygon(maple_points, Color(0.24, 0.66, 0.24, 0.88))
	draw_line(center + Vector2(-9.0, 0.0), center + Vector2(11.0, 0.0), Color(0.42, 0.82, 0.32, 0.66), 1.0, true)


func _prewarm_stage2_pillar_background_textures() -> void:
	var base := _get_texture(Stage2PillarAssets.BASE_TEXTURE_PATH)
	if base != null:
		draw_texture_rect(base, Rect2(0.0, 1560.0, 220.0, 180.0), false, Color(1.0, 1.0, 1.0, 0.72))
	var tree := _get_texture(Stage2PillarAssets.TREE_TEXTURE_PATH)
	if tree != null:
		draw_texture_rect_region(
			tree,
			Rect2(240.0, 1560.0, 86.0, 270.0),
			Stage2PillarAssets.TREE_SOURCE_REGION_DATA.get("left", Rect2()),
			Color(1.0, 1.0, 1.0, 0.72),
			false,
			true
		)
		draw_texture_rect_region(
			tree,
			Rect2(340.0, 1560.0, 86.0, 270.0),
			Stage2PillarAssets.TREE_SOURCE_REGION_DATA.get("right", Rect2()),
			Color(1.0, 1.0, 1.0, 0.72),
			false,
			true
		)
	var game_frame := _get_texture(Stage2PillarAssets.GAME_FRAME_TEXTURE_PATH)
	if game_frame != null:
		draw_texture_rect(game_frame, Rect2(450.0, 1560.0, 240.0, 140.0), false, Color(1.0, 1.0, 1.0, 0.72))
	var leaf := _get_texture(Stage2PillarAssets.LEAF_TEXTURE_PATH)
	if leaf != null:
		draw_texture_rect_region(
			leaf,
			Rect2(710.0, 1560.0, 70.0, 70.0),
			Stage2PillarAssets.LEAF_SOURCE_REGION_DATA[0],
			Color(1.0, 1.0, 1.0, 0.72),
			false,
			true
		)
	var rock := _get_texture(Stage2PillarAssets.ROCK_TEXTURE_PATH)
	if rock != null:
		draw_texture_rect_region(
			rock,
			Rect2(790.0, 1560.0, 64.0, 64.0),
			Stage2PillarAssets.ROCK_SOURCE_REGION_DATA[0],
			Color(1.0, 1.0, 1.0, 0.72),
			false,
			true
		)
	var debris := _get_texture(Stage2PillarAssets.ROCK_DEBRIS_TEXTURE_PATH)
	if debris != null:
		draw_texture_rect_region(
			debris,
			Rect2(870.0, 1560.0, 48.0, 48.0),
			Stage2PillarAssets.ROCK_DEBRIS_SOURCE_REGION_DATA[0],
			Color(1.0, 1.0, 1.0, 0.72),
			false,
			true
		)


func _prewarm_stage3_pillar_background_textures() -> void:
	var base := _get_texture(Stage3PillarBackground.BASE_TEXTURE_PATH)
	if base != null:
		draw_texture_rect(base, Rect2(0.0, 1860.0, 220.0, 180.0), false, Color(1.0, 1.0, 1.0, 0.72))
	var ambient := _get_texture(Stage3PillarBackground.AMBIENT_TEXTURE_PATH)
	if ambient != null:
		var regions: Array = Stage3PillarBackground.AMBIENT_SOURCE_REGIONS
		for idx in range(mini(4, regions.size())):
			var source: Rect2 = regions[idx]
			draw_texture_rect_region(
				ambient,
				Rect2(240.0 + float(idx) * 78.0, 1860.0, 66.0, 66.0),
				source,
				Color(1.0, 1.0, 1.0, 0.72),
				false,
				true
			)
	var center_frame := _get_texture(Stage3PillarBackground.CENTER_FRAME_TEXTURE_PATH)
	if center_frame != null:
		var window: Rect2 = Stage3PillarBackground.CENTER_FRAME_WINDOW_RECT
		var source_size: Vector2 = center_frame.get_size()
		var source_right: float = window.position.x + window.size.x
		var source_bottom: float = window.position.y + window.size.y
		var pieces: Array = [
			Rect2(0.0, 0.0, source_size.x, window.position.y),
			Rect2(0.0, window.position.y, window.position.x, window.size.y),
			Rect2(source_right, window.position.y, source_size.x - source_right, window.size.y),
			Rect2(0.0, source_bottom, source_size.x, source_size.y - source_bottom),
		]
		for idx in range(pieces.size()):
			var source: Rect2 = pieces[idx]
			if source.size.x <= 0.0 or source.size.y <= 0.0:
				continue
			draw_texture_rect_region(
				center_frame,
				Rect2(560.0 + float(idx) * 88.0, 1860.0, 80.0, 70.0),
				source,
				Color(1.0, 1.0, 1.0, 0.72),
				false,
				true
			)


# Exercise both common-starpoint shader branches (normal scrap palette and the
# star-detector cyan shimmer) so the GPU compiles each variant of
# starpoint_drop.gdshader before the first balloon / rock / menhera / bird
# scoring frame. Without this, the first starpoint drop in-game would block on
# PSO compile and show as a one-frame visual stutter.
func _prewarm_common_starpoint_drop_shader() -> void:
	if _starpoint_fx_host == null or not _starpoint_fx_host.has_method("begin_frame"):
		return
	_starpoint_fx_host.begin_frame()
	# State A: normal pink-palette drop with iridescent body shimmer + cross
	# sparkle rays (Stage 1/2/3 default). Exercises both the
	# iridescent_shimmer_intensity and sparkle_ray_intensity shader branches
	# that the live wiring turns on.
	_starpoint_fx_host.sync_drop({
		"pos": Vector2(60.0, 360.0),
		"size": 12.0,
		"life": 255.0,
		"rotation": 0.42,
		"glow_intensity": 1.0,
		"star_detector_bonus": false,
		"elapsed": 1.0,
		"glow_color": Color(1.0, 0.45, 0.74, 1.0),
		"fill_color": Color(1.0, 0.42, 0.78, 1.0),
		"outline_color": Color(1.0, 1.0, 0.0, 1.0),
		"iridescent_shimmer_intensity": 1.0,
		"sparkle_ray_intensity": 1.0,
	})
	# State B: star-detector bonus drop with cyan shimmer rim.
	_starpoint_fx_host.sync_drop({
		"pos": Vector2(160.0, 360.0),
		"size": 12.0,
		"life": 255.0,
		"rotation": 1.27,
		"glow_intensity": 1.0,
		"star_detector_bonus": true,
		"elapsed": 1.4,
		"glow_color": Color(0.30, 0.92, 1.0, 1.0),
		"fill_color": Color(0.16, 0.82, 1.0, 1.0),
		"outline_color": Color(1.0, 1.0, 1.0, 1.0),
	})
	# State C: Stage 4 gold-palette drop (different rgb path in shader uniforms).
	_starpoint_fx_host.sync_drop({
		"pos": Vector2(260.0, 360.0),
		"size": 12.0,
		"life": 255.0,
		"rotation": 2.11,
		"glow_intensity": 1.0,
		"star_detector_bonus": false,
		"elapsed": 1.8,
		"glow_color": Color(1.0, 0.64, 0.16, 1.0),
		"fill_color": Color(1.0, 0.68, 0.05, 1.0),
		"outline_color": Color(1.0, 0.98, 0.52, 1.0),
	})
	_starpoint_fx_host.end_frame()


func _prewarm_timer_stack_primitives() -> void:
	_timer_stack.begin_frame()
	_timer_stack.claim("pso_warmup_timer", true)
	_timer_stack.end_frame()
	var timer_rect := Rect2(0.0, 320.0, 160.0, 12.0)
	draw_rect(timer_rect.grow(2.0), Color(0.02, 0.04, 0.08, 0.72))
	draw_rect(timer_rect, Color(0.16, 0.32, 0.62, 0.88))
	draw_rect(Rect2(timer_rect.position, Vector2(timer_rect.size.x * 0.66, timer_rect.size.y)), Color(0.48, 0.86, 1.0, 0.96))
	draw_line(timer_rect.position + Vector2(0.0, 1.0), timer_rect.position + Vector2(timer_rect.size.x, 1.0), Color(1.0, 1.0, 1.0, 0.20), 1.0, true)
	draw_arc(timer_rect.get_center() + Vector2(timer_rect.size.x + 18.0, 0.0), 10.0, 0.0, TAU, 24, Color(0.56, 0.80, 1.0, 0.58), 2.0, true)


func _prewarm_weather_primitives() -> void:
	_weather_renderer.prewarm_assets()
	for weather_type in ["fire", "ice", "rain", "hail", "sand", "breeze", "gust"]:
		_weather_state.weather_type = str(weather_type)
		_weather_renderer.draw(_weather_state, self, Vector2(0.0, 360.0))


func _prewarm_playfield_primitives() -> void:
	var background := _get_texture(BattleResources.STAGE1_CENTER_BACKGROUND_PATH)
	var border := _get_texture(BattleResources.STAGE1_CENTER_BORDER_PATH)
	var ball := _get_texture(BattleResources.PINGPONG_BALL_TEXTURE_PATH)
	var player_sheet := _get_texture(BattleResources.VIPER_PLAYER_WALK_RIGHT_SHEET_PATH)
	if background != null:
		draw_texture_rect(background, Rect2(0.0, 1120.0, 120.0, 118.0), false)
	if border != null:
		draw_texture_rect(border, Rect2(130.0, 1120.0, 120.0, 118.0), false)
	if ball != null:
		draw_texture_rect(ball, Rect2(260.0, 1120.0, 32.0, 32.0), false, Color(1.0, 1.0, 1.0, 0.92))
	if player_sheet != null:
		draw_texture_rect_region(
			player_sheet,
			Rect2(304.0, 1120.0, 80.0, 80.0),
			Rect2(0.0, 0.0, 160.0, 160.0),
			Color(0.72, 0.92, 1.0, 0.48),
			false,
			true
		)
	draw_rect(Rect2(0.0, 1250.0, 160.0, 100.0), Color(0.28, 0.26, 0.24, 1.0))
	draw_rect(Rect2(0.0, 1250.0, 160.0, 100.0), Color(0.92, 0.78, 0.34, 0.62), false, 2.0)
	draw_line(Vector2(0.0, 1300.0), Vector2(160.0, 1300.0), Color(0.92, 0.78, 0.34, 0.50), 3.0, true)
	draw_arc(Vector2(80.0, 1300.0), 28.0, 0.0, TAU, 48, Color(0.92, 0.78, 0.34, 0.54), 3.0, true)
	draw_circle(Vector2(80.0, 1300.0), 5.0, Color(1.0, 0.90, 0.46, 0.70))
	if ball != null:
		draw_polygon(
			PackedVector2Array([
				Vector2(190.0, 1250.0),
				Vector2(240.0, 1250.0),
				Vector2(240.0, 1300.0),
				Vector2(190.0, 1300.0),
			]),
			PackedColorArray([
				Color.WHITE,
				Color(0.78, 0.92, 1.0, 1.0),
				Color(0.55, 0.72, 1.0, 1.0),
				Color(0.88, 1.0, 1.0, 1.0),
			]),
			PackedVector2Array([
				Vector2(0.0, 0.0),
				Vector2(1.0, 0.0),
				Vector2(1.0, 1.0),
				Vector2(0.0, 1.0),
			]),
			ball
		)
	var ellipse_transform := Transform2D(Vector2(32.0, 0.0), Vector2(0.0, 9.0), Vector2(330.0, 1260.0))
	draw_mesh(
		ActiveItemThrowMolotovRenderer._get_filled_ellipse_mesh(),
		null,
		ellipse_transform,
		Color(1.0, 0.92, 0.20, 0.32)
	)


func _prewarm_stage1_result_pose_textures() -> void:
	_prewarm_cached_texture_region(
		BattleResources.SMASHER_VICTORY_SHEET_PATH,
		Rect2(0.0, 0.0, 160.0, 160.0),
		Rect2(0.0, 2080.0, 160.0, 160.0)
	)
	_prewarm_cached_texture_region(
		BattleResources.SMASHER_DEFEAT_SHEET_PATH,
		Rect2(0.0, 0.0, 160.0, 160.0),
		Rect2(170.0, 2080.0, 160.0, 160.0)
	)
	_prewarm_cached_texture_region(
		BattleResources.VIPER_VICTORY_SHEET_PATH,
		Rect2(0.0, 0.0, 160.0, 160.0),
		Rect2(340.0, 2080.0, 160.0, 160.0)
	)
	_prewarm_cached_texture_region(
		BattleResources.VIPER_DEFEAT_SHEET_PATH,
		Rect2(0.0, 0.0, 160.0, 160.0),
		Rect2(510.0, 2080.0, 160.0, 160.0)
	)
	_prewarm_cached_texture_region(
		BattleResources.DALJI_BOSS_VICTORY_PATH,
		Rect2(0.0, 0.0, 384.0, 512.0),
		Rect2(0.0, 2250.0, 96.0, 112.0)
	)
	_prewarm_cached_texture_region(
		BattleResources.DALJI_BOSS_DEFEAT_PATH,
		Rect2(0.0, 0.0, 384.0, 512.0),
		Rect2(106.0, 2250.0, 96.0, 112.0)
	)


# Force the first textured-quad PSO compile + VRAM upload of the large skill
# cut-in sheets offscreen at boot, so the first real Power Smashing / Ghost
# Smashing / Phantom Kick freeze does not stall on the cut-in sheet's first
# draw_texture_rect_region. The selected-character cut-in host asset prewarm
# (stage-runtime common step 6) runs and fully completes BEFORE this final PSO
# step, so the sheets it cached are already in ProjectResourceLoader here; a
# sheet not prewarmed for the selected character returns null and is skipped
# (per-character scope flows naturally through the cache).
func _prewarm_skill_cutin_sheets() -> void:
	var paths: Array = [
		SkillCutinOverlayHost.POWER_SMASHING_CUTIN_SHEET_PATH,
		SkillCutinOverlayHost.GHOST_SMASHING_CUTIN_SHEET_PATH,
		SkillCutinOverlayHost.VIPER_PHANTOM_KICK_CUTIN_SHEET_PATH,
	]
	for index in range(paths.size()):
		var path := str(paths[index])
		var texture: Texture2D = _get_texture(path)
		if texture == null:
			continue
		var cell: Vector2 = texture.get_size() / 4.0
		if cell.x <= 1.0 or cell.y <= 1.0:
			continue
		_prewarm_cached_texture_region(
			path,
			Rect2(Vector2.ZERO, cell),
			Rect2(Vector2(float(index) * 44.0, 2450.0), Vector2(40.0, 40.0))
		)


func _prewarm_cached_texture_region(path: String, source_rect: Rect2, dest_rect: Rect2) -> void:
	var texture := _get_texture(path)
	if texture == null:
		return
	draw_texture_rect_region(
		texture,
		dest_rect,
		source_rect,
		Color(1.0, 1.0, 1.0, 0.82),
		false,
		true
	)


func _prewarm_stage2_center_primitives() -> void:
	var cx := 420.0
	var cy := 1480.0
	var ring_rect := Rect2(cx - 108.0, cy - 76.0, 216.0, 152.0)
	var inner_rect := ring_rect.grow(-18.0)
	var head_rect := Rect2(cx - 96.0, cy - 66.0, 192.0, 132.0)
	var face_rect := Rect2(cx - 74.0, cy - 53.0, 148.0, 88.0)
	var snout_rect := Rect2(cx - 67.0, cy + 13.0, 134.0, 52.0)
	draw_line(Vector2(cx - 190.0, cy), Vector2(cx + 190.0, cy), Color(0.04, 0.65, 0.33, 0.92), 5.0, true)
	draw_colored_polygon(_ellipse_points(ring_rect, 8), Color(0.05, 0.12, 0.12, 0.98))
	draw_colored_polygon(_ellipse_points(inner_rect, 8), Color(0.05, 0.09, 0.10, 0.98))
	draw_colored_polygon(_ellipse_points(head_rect, 8), Color(0.15, 0.38, 0.16, 0.98))
	draw_colored_polygon(_ellipse_points(face_rect, 8), Color(0.28, 0.60, 0.25, 0.98))
	draw_colored_polygon(_ellipse_points(snout_rect, 8), Color(0.20, 0.50, 0.18, 0.98))
	draw_polyline(_closed_points(_ellipse_points(ring_rect, 16)), Color(0.08, 0.80, 0.42, 0.92), 3.0, true)
	for spot_x in [-24.0, 0.0, 24.0]:
		draw_circle(Vector2(cx + spot_x, cy - 28.0), 3.0, Color(0.16, 0.38, 0.18, 0.98))
	for eye_x in [cx - 29.0, cx + 29.0]:
		draw_circle(Vector2(eye_x, cy - 18.0), 6.0, Color(0.86, 0.82, 0.07, 0.98))
		draw_circle(Vector2(eye_x, cy - 18.0), 3.0, Color(0.03, 0.10, 0.07, 0.98))
	for idx in range(6):
		var x: float = cx - 47.5 + float(idx) * 19.0
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(x, cy + 48.0),
				Vector2(x + 9.0, cy + 48.0),
				Vector2(x + 4.5, cy + 35.0),
			]),
			Color(0.96, 0.97, 0.91, 0.98)
		)


func _get_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var texture: Texture2D = null
	# The boot resource warmup already populates ProjectResourceLoader.
	# Do not synchronously decode or import textures here: this node exists
	# only to issue draw calls for resources that are ready to draw.
	var cached_texture: Texture2D = ProjectResourceLoader.get_cached_texture(path)
	if cached_texture != null:
		texture = cached_texture
	_texture_cache[path] = texture
	return texture


func _ellipse_points(rect: Rect2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius: Vector2 = rect.size * 0.5
	for idx in range(maxi(8, segments)):
		var angle: float = TAU * float(idx) / float(maxi(8, segments))
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if points.size() > 0:
		closed.append(points[0])
	return closed
