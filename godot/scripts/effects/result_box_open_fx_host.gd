extends Node2D

# Modular VFX host for the stage-clear result screen's reward boxes.
#
# Mirrors the chaos-spear / meditation FX host pattern: each visible piece
# is its own child node (Sprite2D / GPUParticles2D), the shared
# WritheEmberMaterial drives the backplate distortion, and a Dictionary
# state is fed per frame so the result scene can keep using its existing
# box state machine without owning shader / particle wiring.

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")

const BACKPLATE_COMMON_PATH := "res://assets/sprites/result_boxes/result_box_open_backplate_common_imagegen_v1.png"
const BACKPLATE_MYTHIC_PATH := "res://assets/sprites/result_boxes/result_box_open_backplate_mythic_imagegen_v1.png"
const RIBBON_TRAIL_PATH := "res://assets/sprites/result_boxes/result_box_open_ribbon_trail_imagegen_v1.png"

const BACKPLATE_BASE_SIZE := 165.0
const RIBBON_BASE_WIDTH := 110.0
const RIBBON_BASE_HEIGHT := 290.0
const INNER_GLOW_BASE_SIZE := 145.0
const LID_OPEN_PROGRESS := 0.55

# Fan-shaped light burst drawn behind the mandala backplate. Renders via
# the host's own _draw() (host z=0 relative; child sprites use z>=1 so the
# fan stays under the mandala / ribbon and reads as light leaking outward).
const FAN_OUTER_RADIUS := 235.0
const FAN_ARC_DEGREES := 124.0
const FAN_RAY_COUNT := 11
const FAN_VERTICAL_OFFSET := -22.0
const LID_FLASH_FADE_DURATION := 0.30
const EMERGE_GLOW_FADE_DURATION := 0.45
const LIGHT_ENVELOPE_HOLD_DURATION := 0.22
const LIGHT_ENVELOPE_FADE_DURATION := 0.55
const SPARK_PARTICLE_LIFETIME := 0.36

const COMMON_HOT := Color(0.30, 0.86, 1.00, 1.0)
const COMMON_AMBER := Color(1.00, 0.78, 0.36, 1.0)
const MYTHIC_HOT := Color(1.00, 0.42, 0.92, 1.0)
const MYTHIC_AMBER := Color(1.00, 0.78, 0.30, 1.0)

var elapsed_sec := 0.0
var open_value := 0.0
var breath_value := 0.0
var lid_flash := 0.0
var emerge_glow := 0.0
var light_envelope := 0.0

var _state: Dictionary = {}
var _active := false
var _is_mythic := false
var _last_lid_open_id: int = -1
var _backplate_preset := "result_box_burst_common"

var _backplate_sprite: Sprite2D = null
var _ribbon_sprite: Sprite2D = null
var _inner_glow_sprite: Sprite2D = null
var _spark_particles: GPUParticles2D = null
var _backplate_material: ShaderMaterial = null
var _additive_material: CanvasItemMaterial = null

var _breath_tween: Tween = null
var _open_tween: Tween = null
var _lid_flash_tween: Tween = null
var _emerge_glow_tween: Tween = null
var _light_envelope_tween: Tween = null

static var _backplate_common_texture: Texture2D = null
static var _backplate_mythic_texture: Texture2D = null
static var _ribbon_trail_texture: Texture2D = null


static func prewarm_assets() -> void:
	ImpactFlareTextureCache.prewarm()
	_get_backplate_common_texture()
	_get_backplate_mythic_texture()
	_get_ribbon_trail_texture()
	WritheEmber.prewarm()
	_build_spark_particle_material()


static func reset_prewarm_assets_for_test() -> void:
	_backplate_common_texture = null
	_backplate_mythic_texture = null
	_ribbon_trail_texture = null
	ImpactFlareTextureCache.reset_for_test()
	WritheEmber.reset_for_test()


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"result_box_open_fx_shader_pipeline": (
			WritheEmber.has_preset("result_box_burst_common")
			and WritheEmber.has_preset("result_box_burst_mythic")
		),
		"result_box_open_fx_shader_layers": 1,
		"result_box_open_fx_gpu_particle_layers": 1,
		"result_box_open_fx_texture_pieces_ready": (
			_get_backplate_common_texture() != null
			and _get_backplate_mythic_texture() != null
			and _get_ribbon_trail_texture() != null
			and ImpactFlareTextureCache.get_burst_texture() != null
			and ImpactFlareTextureCache.get_sparkle_texture() != null
		),
		"result_box_open_fx_backplate_common_png_slot": _get_backplate_common_texture() != null,
		"result_box_open_fx_backplate_mythic_png_slot": _get_backplate_mythic_texture() != null,
		"result_box_open_fx_ribbon_trail_png_slot": _get_ribbon_trail_texture() != null,
		"result_box_open_fx_backplate_common_texture_path": BACKPLATE_COMMON_PATH,
		"result_box_open_fx_backplate_mythic_texture_path": BACKPLATE_MYTHIC_PATH,
		"result_box_open_fx_ribbon_trail_texture_path": RIBBON_TRAIL_PATH,
	}


func _ready() -> void:
	# Stay z-relative so the host inherits its parent's effective z. The
	# stage-clear result scene Control sits at z_index=1200 to render above
	# gameplay; using absolute z here (the meditation FX host pattern) would
	# strand every child sprite back at z=~0 behind the result background
	# and make the entire effect invisible. Child z_index offsets below are
	# all positive so the additive layers land above the result _draw()
	# content (background + box sprite-sheet body).
	var should_remain_active := visible or _active
	z_as_relative = true
	z_index = 0
	_additive_material = _make_additive_material()
	# Host's own _draw() output (the fan-burst light) should additively
	# blend behind the mandala backplate. Child sprites have their own
	# materials so they aren't affected.
	material = _additive_material
	_build_children()
	_start_breath_tween()
	set_active(should_remain_active)
	if should_remain_active:
		_apply_state()


func sync_state(next_state: Dictionary, active: bool) -> void:
	if _backplate_sprite == null:
		_build_children()
	_state = next_state.duplicate(false)
	if is_inside_tree() and (_breath_tween == null or not _breath_tween.is_valid()):
		_start_breath_tween()
	set_active(active)
	if not active:
		return
	elapsed_sec = float(Time.get_ticks_msec()) / 1000.0
	_apply_state()
	queue_redraw()


func set_active(active: bool) -> void:
	if active and not _active:
		_start_open_tween()
	_active = active
	visible = active
	set_process(false)
	if _backplate_sprite != null:
		_backplate_sprite.visible = active
	if _ribbon_sprite != null:
		_ribbon_sprite.visible = active
	if _inner_glow_sprite != null:
		_inner_glow_sprite.visible = false
	if _spark_particles != null and not active:
		_spark_particles.emitting = false
	if not active:
		_last_lid_open_id = -1
		open_value = 0.0
		lid_flash = 0.0
		emerge_glow = 0.0
		light_envelope = 0.0


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	for tween in [_breath_tween, _open_tween, _lid_flash_tween, _emerge_glow_tween, _light_envelope_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_breath_tween = null
	_open_tween = null
	_lid_flash_tween = null
	_emerge_glow_tween = null
	_light_envelope_tween = null
	if free_self:
		queue_free()


func trigger_lid_open() -> void:
	if _spark_particles != null:
		_spark_particles.restart()
		_spark_particles.emitting = true
	if _inner_glow_sprite != null:
		_inner_glow_sprite.visible = true
	if _lid_flash_tween != null and _lid_flash_tween.is_valid():
		_lid_flash_tween.kill()
	lid_flash = 1.0
	if is_inside_tree():
		_lid_flash_tween = create_tween()
		_lid_flash_tween.tween_property(self, "lid_flash", 0.0, LID_FLASH_FADE_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# emerge_glow snaps to peak at lid pop then fades, matching the
	# light_envelope envelope so the inner glow's contribution does not
	# linger after the bright flash.
	if _emerge_glow_tween != null and _emerge_glow_tween.is_valid():
		_emerge_glow_tween.kill()
	emerge_glow = 1.0
	if is_inside_tree():
		_emerge_glow_tween = create_tween()
		_emerge_glow_tween.tween_property(self, "emerge_glow", 0.0, EMERGE_GLOW_FADE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Master "shine bright then fade out" envelope. The reward icon needs to
	# become readable quickly after the lid pop, so the bright hold is short
	# and the fade completes near the end of reward_emerge instead of lingering.
	if _light_envelope_tween != null and _light_envelope_tween.is_valid():
		_light_envelope_tween.kill()
	light_envelope = 1.0
	if is_inside_tree():
		_light_envelope_tween = create_tween()
		_light_envelope_tween.tween_interval(LIGHT_ENVELOPE_HOLD_DURATION)
		_light_envelope_tween.tween_property(self, "light_envelope", 0.0, LIGHT_ENVELOPE_FADE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if not _active or _state.is_empty():
		return
	if light_envelope <= 0.01 and lid_flash <= 0.01:
		return
	var alpha_scale: float = clampf(float(_state.get("alpha", 1.0)), 0.0, 1.0)
	var reward_emerge: float = clampf(float(_state.get("reward_emerge", 0.0)), 0.0, 1.0)
	var glow_alpha: float = clampf(light_envelope * alpha_scale, 0.0, 1.0)
	if glow_alpha <= 0.01:
		return
	var emerge_eased: float = _smooth01(reward_emerge)
	var bloom: float = lerpf(0.55, 1.18, emerge_eased) + breath_value * 0.04 + lid_flash * 0.10
	var outer_radius: float = FAN_OUTER_RADIUS * bloom
	var arc_rad: float = deg_to_rad(FAN_ARC_DEGREES * lerpf(0.55, 1.0, emerge_eased))
	var base_color: Color = MYTHIC_HOT if _is_mythic else COMMON_HOT
	var center: Vector2 = Vector2(0.0, FAN_VERTICAL_OFFSET)
	var up: float = -PI * 0.5

	# Soft cone wash — wide triangle fan with center bright and outer rim
	# transparent so the burst feathers out smoothly.
	var seg: int = 30
	var wash_points := PackedVector2Array()
	var wash_colors := PackedColorArray()
	var wash_center_color := Color(base_color.r, base_color.g, base_color.b, glow_alpha * 0.42)
	var wash_edge_color := Color(base_color.r, base_color.g, base_color.b, 0.0)
	wash_points.append(center)
	wash_colors.append(wash_center_color)
	for i in range(seg + 1):
		var t: float = float(i) / float(seg)
		var ang: float = up - arc_rad * 0.5 + arc_rad * t
		var p: Vector2 = center + Vector2(cos(ang), sin(ang)) * outer_radius
		wash_points.append(p)
		wash_colors.append(wash_edge_color)
	draw_polygon(wash_points, wash_colors)

	# Bright fan rays — narrower spokes layered above the wash so the
	# burst reads as actual rays, not just a flat gradient.
	var ray_outer_radius: float = outer_radius * 0.96
	var ray_half_width_base: float = 5.0 + emerge_eased * 5.5
	var ray_arc_rad: float = arc_rad * 0.92
	var ray_count: int = FAN_RAY_COUNT
	for r in range(ray_count):
		var t2: float = float(r) / float(max(1, ray_count - 1))
		var beam_t: float = t2 - 0.5  # -0.5 .. 0.5
		var ang_center: float = up + ray_arc_rad * beam_t
		var dir: Vector2 = Vector2(cos(ang_center), sin(ang_center))
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		# Subtle per-ray length variation so the fan reads as
		# hand-drawn light spokes, not a stamped rake.
		var length_jitter: float = 0.92 + 0.10 * sin(float(r) * 1.7 + elapsed_sec * 1.1)
		var tip_radius: float = ray_outer_radius * length_jitter
		var tip: Vector2 = center + dir * tip_radius
		var half_w: float = ray_half_width_base * (0.78 + 0.42 * (1.0 - absf(beam_t) * 1.4))
		var base_a: Vector2 = center + perp * half_w
		var base_b: Vector2 = center - perp * half_w
		var center_strength: float = 1.0 - clampf(absf(beam_t) * 1.55, 0.0, 1.0)
		var ray_alpha: float = glow_alpha * (0.40 + 0.60 * center_strength)
		ray_alpha = clampf(ray_alpha + lid_flash * 0.12, 0.0, 1.0)
		var ray_pts := PackedVector2Array([base_a, tip, base_b])
		var ray_cols := PackedColorArray([
			Color(base_color.r, base_color.g, base_color.b, ray_alpha),
			Color(1.0, 1.0, 1.0, 0.0),
			Color(base_color.r, base_color.g, base_color.b, ray_alpha),
		])
		draw_polygon(ray_pts, ray_cols)


func _apply_state() -> void:
	if _state.is_empty():
		return
	var center: Vector2 = _as_vector2(_state.get("position", Vector2.ZERO), Vector2.ZERO)
	var layout_scale: float = maxf(0.001, float(_state.get("scale", 1.0)))
	var phase: String = str(_state.get("phase", "idle"))
	var open_progress: float = clampf(float(_state.get("open_progress", 0.0)), 0.0, 1.0)
	var reward_emerge: float = clampf(float(_state.get("reward_emerge", 0.0)), 0.0, 1.0)
	var alpha_scale: float = clampf(float(_state.get("alpha", 1.0)), 0.0, 1.0)
	var is_mythic: bool = bool(_state.get("is_mythic", false))
	position = center
	scale = Vector2(layout_scale, layout_scale)

	if is_mythic != _is_mythic:
		_is_mythic = is_mythic
		_apply_kind_settings()

	var lid_open_id: int = int(_state.get("lid_open_id", -1))
	if lid_open_id != _last_lid_open_id and lid_open_id >= 0:
		_last_lid_open_id = lid_open_id
		trigger_lid_open()

	_update_backplate(phase, open_progress, reward_emerge, alpha_scale)
	_update_ribbon(phase, open_progress, reward_emerge, alpha_scale)
	_update_inner_glow(phase, open_progress, reward_emerge, alpha_scale)


func _apply_kind_settings() -> void:
	_backplate_preset = "result_box_burst_mythic" if _is_mythic else "result_box_burst_common"
	if _backplate_material != null:
		WritheEmber.apply_preset(_backplate_material, _backplate_preset)
	if _backplate_sprite != null:
		_backplate_sprite.texture = _get_backplate_texture(_is_mythic)
	if _spark_particles != null:
		var mat: ParticleProcessMaterial = _spark_particles.process_material as ParticleProcessMaterial
		if mat != null:
			mat.color = MYTHIC_HOT if _is_mythic else COMMON_HOT


func _update_backplate(phase: String, open_progress: float, reward_emerge: float, alpha_scale: float) -> void:
	if _backplate_sprite == null:
		return
	var texture: Texture2D = _get_backplate_texture(_is_mythic)
	if texture == null:
		_backplate_sprite.visible = false
		return
	var phase_intro: float = 0.0
	if phase == "opening":
		phase_intro = clampf(open_progress / maxf(0.001, LID_OPEN_PROGRESS), 0.0, 1.0)
	elif phase == "opened":
		phase_intro = 1.0
	var emerge_eased: float = _smooth01(reward_emerge)
	var grow: float = lerpf(0.82, 1.04, phase_intro) + lid_flash * 0.12 + breath_value * 0.035 + emerge_eased * 0.05
	var size: float = BACKPLATE_BASE_SIZE * grow
	var tex_size: Vector2 = texture.get_size()
	_backplate_sprite.scale = Vector2(size / maxf(1.0, tex_size.x), size / maxf(1.0, tex_size.y))
	_backplate_sprite.rotation = elapsed_sec * (0.28 if _is_mythic else -0.22)
	# Backplate alpha is driven by the light_envelope so the mandala blazes
	# at lid pop then fades to nothing. A tiny pre-lid hint during the
	# "opening" phase keeps the buildup visible before light_envelope fires.
	# During "opened" phase pre_lid_hint stays at 0 so once the envelope
	# decays the mandala disappears completely instead of holding at ~0.72.
	var pre_lid_hint: float = 0.0
	if phase == "opening":
		pre_lid_hint = phase_intro * 0.18
	var envelope: float = maxf(pre_lid_hint, light_envelope)
	var backplate_alpha: float = alpha_scale * envelope * 0.78
	backplate_alpha = clampf(backplate_alpha + lid_flash * 0.16, 0.0, 0.92)
	var backplate_tint := Color(1.0, 0.76, 1.0, backplate_alpha) if _is_mythic else Color(0.68, 1.0, 1.0, backplate_alpha)
	_backplate_sprite.modulate = backplate_tint
	_backplate_sprite.visible = backplate_alpha > 0.01
	if _backplate_material != null:
		var intensity: float = lerpf(0.82, 1.36, phase_intro) + lid_flash * 0.44 + breath_value * 0.12 + emerge_eased * 0.16
		_backplate_material.set_shader_parameter("elapsed", elapsed_sec)
		_backplate_material.set_shader_parameter("intensity", clampf(intensity, 0.0, 2.0))


func _update_ribbon(phase: String, open_progress: float, reward_emerge: float, alpha_scale: float) -> void:
	if _ribbon_sprite == null:
		return
	var texture: Texture2D = _get_ribbon_trail_texture()
	if texture == null:
		_ribbon_sprite.visible = false
		return
	var post_lid: float = clampf((open_progress - LID_OPEN_PROGRESS) / maxf(0.001, 1.0 - LID_OPEN_PROGRESS), 0.0, 1.0)
	var rise: float = 0.0
	var spread: float = 0.0
	var ribbon_alpha: float = 0.0
	if phase == "opening":
		rise = post_lid * 0.30
		spread = post_lid * 0.18
		ribbon_alpha = lerpf(0.0, 0.32, post_lid) + lid_flash * 0.22
	elif phase == "opened":
		var emerge_eased: float = _smooth01(reward_emerge)
		# Bias scale toward reward_emerge so the pillar visibly grows
		# upward AND outward instead of starting near full height with a
		# pinched waist. Without enough delta the bloom reads as a static
		# spike that just fades.
		rise = 0.30 + emerge_eased * 0.92
		spread = 0.18 + emerge_eased * 0.82
		# Ribbon scale (rise / spread) follows reward_emerge so the pillar
		# extends upward and unfurls. Ribbon alpha follows light_envelope so
		# it blazes then fades to nothing instead of holding at "opened".
		var pulse_alpha: float = lerpf(0.55, 0.95, emerge_eased)
		ribbon_alpha = light_envelope * pulse_alpha
		ribbon_alpha += sin(elapsed_sec * 2.4) * 0.035 * light_envelope
	ribbon_alpha *= alpha_scale
	ribbon_alpha = clampf(ribbon_alpha, 0.0, 1.0)
	_ribbon_sprite.visible = ribbon_alpha > 0.01
	if not _ribbon_sprite.visible:
		return
	var tex_size: Vector2 = texture.get_size()
	# Ribbon source has bright base at the BOTTOM tapering upward. The
	# texture's anchor is the centroid; planting the bright base near the
	# top of the box body and reaching upward into the reward emerge zone
	# means the ribbon's bottom edge lives a few raw units above the box
	# center.
	var width: float = RIBBON_BASE_WIDTH * (0.78 + spread * 0.62 + breath_value * 0.04)
	var height: float = RIBBON_BASE_HEIGHT * (0.62 + rise * 0.66)
	_ribbon_sprite.scale = Vector2(width / maxf(1.0, tex_size.x), height / maxf(1.0, tex_size.y))
	_ribbon_sprite.position = Vector2(0.0, -height * 0.5 - 26.0)
	var ribbon_tint := Color(1.0, 0.46, 0.96, ribbon_alpha) if _is_mythic else Color(0.48, 0.96, 1.0, ribbon_alpha)
	_ribbon_sprite.modulate = ribbon_tint


func _update_inner_glow(phase: String, open_progress: float, reward_emerge: float, alpha_scale: float) -> void:
	if _inner_glow_sprite == null:
		return
	var texture: Texture2D = _inner_glow_sprite.texture
	if texture == null:
		_inner_glow_sprite.visible = false
		return
	var persistent_glow := 0.0
	if phase == "opening":
		var post_lid: float = clampf((open_progress - LID_OPEN_PROGRESS) / maxf(0.001, 1.0 - LID_OPEN_PROGRESS), 0.0, 1.0)
		persistent_glow = lerpf(0.02, 0.16, post_lid)
	# Inner glow now follows the shared light_envelope after the lid pop so
	# it fades out fully instead of holding a steady 0.22+ brightness during
	# the entire "opened" phase. Keep a subtle breath modulation on the
	# envelope contribution so the glow still breathes while it decays.
	var envelope_glow: float = light_envelope * (0.72 + breath_value * 0.06)
	var glow_strength: float = maxf(persistent_glow, maxf(lid_flash, maxf(envelope_glow, emerge_glow * 0.52)))
	if glow_strength <= 0.01:
		_inner_glow_sprite.visible = false
		return
	var size: float = INNER_GLOW_BASE_SIZE * (0.74 + lid_flash * 0.58 + reward_emerge * 0.16 + breath_value * 0.04)
	var tex_size: Vector2 = texture.get_size()
	_inner_glow_sprite.scale = Vector2(size / maxf(1.0, tex_size.x), size / maxf(1.0, tex_size.y))
	var glow_alpha: float = alpha_scale * clampf(glow_strength * 0.58, 0.0, 0.62)
	var glow_tint := Color(1.0, 0.40, 0.92, glow_alpha) if _is_mythic else Color(0.34, 0.92, 1.0, glow_alpha)
	_inner_glow_sprite.modulate = glow_tint
	_inner_glow_sprite.position = Vector2.ZERO
	_inner_glow_sprite.visible = true


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()
	if _backplate_sprite == null:
		_backplate_sprite = Sprite2D.new()
		_backplate_sprite.name = "ResultBoxOpenBackplate"
		_backplate_sprite.centered = true
		# All FX layer z_index offsets are positive so they sit above the
		# result scene Control's own _draw() (background + box body) which
		# shares the Control's z (=1200). With z_as_relative=true on this
		# host, the effective z becomes parent_z + offset, so e.g. 1201 for
		# the backplate, 1202 for ribbon / inner glow, 1203 for sparks.
		_backplate_sprite.z_index = 1
		_backplate_sprite.texture = _get_backplate_texture(_is_mythic)
		_backplate_material = WritheEmber.build_material(_backplate_preset)
		_backplate_sprite.material = _backplate_material
		_backplate_sprite.visible = false
		add_child(_backplate_sprite)
	if _ribbon_sprite == null:
		_ribbon_sprite = Sprite2D.new()
		_ribbon_sprite.name = "ResultBoxOpenRibbonTrail"
		_ribbon_sprite.centered = true
		_ribbon_sprite.z_index = 2
		_ribbon_sprite.texture = _get_ribbon_trail_texture()
		_ribbon_sprite.material = _additive_material
		_ribbon_sprite.visible = false
		add_child(_ribbon_sprite)
	if _inner_glow_sprite == null:
		_inner_glow_sprite = Sprite2D.new()
		_inner_glow_sprite.name = "ResultBoxOpenInnerGlow"
		_inner_glow_sprite.centered = true
		_inner_glow_sprite.z_index = 2
		_inner_glow_sprite.texture = ImpactFlareTextureCache.get_burst_texture()
		_inner_glow_sprite.material = _additive_material
		_inner_glow_sprite.visible = false
		add_child(_inner_glow_sprite)
	if _spark_particles == null:
		_spark_particles = GPUParticles2D.new()
		_spark_particles.name = "ResultBoxOpenSparkParticles"
		_spark_particles.amount = 64
		_spark_particles.lifetime = SPARK_PARTICLE_LIFETIME
		_spark_particles.one_shot = true
		_spark_particles.explosiveness = 0.96
		_spark_particles.randomness = 0.85
		_spark_particles.fixed_fps = 60
		_spark_particles.local_coords = true
		_spark_particles.visibility_rect = Rect2(-220.0, -280.0, 440.0, 420.0)
		_spark_particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
		_spark_particles.material = _additive_material
		_spark_particles.process_material = _build_spark_particle_material()
		_spark_particles.emitting = false
		_spark_particles.z_index = 3
		add_child(_spark_particles)


func _start_breath_tween() -> void:
	if not is_inside_tree():
		return
	if _breath_tween != null and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = create_tween()
	_breath_tween.set_loops()
	_breath_tween.tween_property(self, "breath_value", 1.0, 1.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_property(self, "breath_value", 0.0, 0.96).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _start_open_tween() -> void:
	if not is_inside_tree():
		open_value = 1.0
		return
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	open_value = 0.0
	_open_tween = create_tween()
	_open_tween.tween_property(self, "open_value", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _build_spark_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 78.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 115.0
	mat.initial_velocity_max = 250.0
	mat.radial_accel_min = -50.0
	mat.radial_accel_max = 130.0
	mat.tangential_accel_min = -110.0
	mat.tangential_accel_max = 110.0
	mat.damping_min = 32.0
	mat.damping_max = 110.0
	mat.scale_min = 0.035
	mat.scale_max = 0.090
	mat.color = COMMON_HOT
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 14.0
	return mat


static func _get_backplate_texture(is_mythic: bool) -> Texture2D:
	if is_mythic:
		return _get_backplate_mythic_texture()
	return _get_backplate_common_texture()


static func _get_backplate_common_texture() -> Texture2D:
	if _backplate_common_texture != null:
		return _backplate_common_texture
	_backplate_common_texture = ProjectResourceLoader.load_texture(BACKPLATE_COMMON_PATH)
	return _backplate_common_texture


static func _get_backplate_mythic_texture() -> Texture2D:
	if _backplate_mythic_texture != null:
		return _backplate_mythic_texture
	_backplate_mythic_texture = ProjectResourceLoader.load_texture(BACKPLATE_MYTHIC_PATH)
	return _backplate_mythic_texture


static func _get_ribbon_trail_texture() -> Texture2D:
	if _ribbon_trail_texture != null:
		return _ribbon_trail_texture
	_ribbon_trail_texture = ProjectResourceLoader.load_texture(RIBBON_TRAIL_PATH)
	return _ribbon_trail_texture


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


static func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


static func _smooth01(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
