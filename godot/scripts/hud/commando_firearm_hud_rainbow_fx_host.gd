extends Node2D

# Commando firearm HUD acquired-weapon rainbow border FX host.
#
# Mirrors the dash_token_boost_fx_host pattern: one persistent Node2D attached
# to the pillar canvas, exposing a per-frame sync API. Hosts:
#
#   * one Sprite2D + ShaderMaterial quad behind the firearm panel that paints
#     the rainbow border / sweep / corner accents / outer glow
#   * four GPUParticles2D emitters at the panel corners that spit short-lived
#     spark bursts whenever the highlight intensity rises
#   * a tween-driven pop_progress + alpha modulation so the border eases in at
#     activation and eases out as the timer ratio decays
#
# The renderer chain calls `begin_frame()` once per frame, then `sync_panel()`
# with the current panel rect and the highlight state; `end_frame()` hides the
# quad and corner emitters if no sync arrived this frame.

const RAINBOW_SHADER := preload("res://shaders/hud/commando_firearm_hud_rainbow_border.gdshader")

const HOST_Z_INDEX := 5
# Quad inflates the actual panel rect by this many pixels per side so the
# outer glow has room to bleed past the panel edge.
const PANEL_OUTER_GLOW_PX := 18.0
# Maximum number of distinct panels we expect to highlight at once. Today this
# is always 1 (single firearm panel), but the pool sizing matches the
# dash_token_boost_fx_host convention.
const MAX_SLOTS := 1
const CORNER_COUNT := 4
# Pop-in tween duration in frames (60fps), a short snap to an "alive" feel.
const POP_IN_FRAMES := 14.0

static var _prewarmed: bool = false
static var _shader_ready: bool = false
static var _white_texture: Texture2D = null
static var _spark_texture: Texture2D = null

var _slot_sprite: Sprite2D = null
var _slot_material: ShaderMaterial = null
var _corner_emitters: Array[GPUParticles2D] = []
var _slot_active: bool = false
var _frame_synced: bool = false
var _last_intensity: float = 0.0
var _pop_progress: float = 0.0
var _last_weapon_id: String = ""
var _last_burst_weapon_id: String = ""
var _last_burst_msec: int = -100000


static func prewarm_assets() -> void:
	if _prewarmed:
		return
	_shader_ready = RAINBOW_SHADER is Shader
	_get_or_create_white_texture()
	_get_or_create_spark_texture()
	_prewarmed = true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"commando_firearm_hud_rainbow_shader_ready": _shader_ready,
		"commando_firearm_hud_rainbow_white_texture_ready": _white_texture != null,
		"commando_firearm_hud_rainbow_spark_texture_ready": _spark_texture != null,
	}


static func _get_or_create_white_texture() -> Texture2D:
	if _white_texture != null:
		return _white_texture
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white_texture = ImageTexture.create_from_image(img)
	return _white_texture


static func _get_or_create_spark_texture() -> Texture2D:
	if _spark_texture != null:
		return _spark_texture
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(size) * 0.5, float(size) * 0.5)
	var max_dist: float = float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(float(x), float(y)).distance_to(center)
			var t: float = clamp(1.0 - d / max_dist, 0.0, 1.0)
			var a: float = pow(t, 1.7)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_spark_texture = ImageTexture.create_from_image(img)
	return _spark_texture


func _ready() -> void:
	z_as_relative = false
	z_index = HOST_Z_INDEX
	_build_slot()


func begin_frame() -> void:
	_frame_synced = false


func sync_panel(rect: Rect2, intensity: float, weapon_id: String, elapsed_seconds: float) -> void:
	if _slot_sprite == null:
		_build_slot()
	var safe_intensity: float = clamp(intensity, 0.0, 1.0)
	if safe_intensity <= 0.001:
		return
	_frame_synced = true
	_apply_slot(rect, safe_intensity, weapon_id, elapsed_seconds)


func end_frame() -> void:
	if _frame_synced:
		return
	if _slot_sprite != null and _slot_sprite.visible:
		_slot_sprite.visible = false
	for emitter in _corner_emitters:
		if emitter != null and emitter.emitting:
			emitter.emitting = false
	_slot_active = false
	_last_intensity = 0.0
	_pop_progress = 0.0
	_last_weapon_id = ""


func set_active(value: bool) -> void:
	visible = value
	if not value:
		if _slot_sprite != null:
			_slot_sprite.visible = false
		for emitter in _corner_emitters:
			if emitter != null:
				emitter.emitting = false
		_slot_active = false
		_last_intensity = 0.0
		_pop_progress = 0.0
		_last_weapon_id = ""


func tear_down(deferred: bool = true) -> void:
	if deferred:
		queue_free()
	else:
		free()


func _build_slot() -> void:
	if _slot_sprite != null:
		return
	var tex: Texture2D = _get_or_create_white_texture()
	var sprite := Sprite2D.new()
	sprite.name = "RainbowBorderSlot"
	sprite.texture = tex
	sprite.centered = true
	sprite.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = RAINBOW_SHADER
	sprite.material = mat
	add_child(sprite)
	_slot_sprite = sprite
	_slot_material = mat

	for i in range(CORNER_COUNT):
		var emitter := GPUParticles2D.new()
		emitter.name = "CornerSpark%d" % i
		emitter.amount = 12
		emitter.lifetime = 0.55
		emitter.one_shot = false
		emitter.preprocess = 0.0
		emitter.explosiveness = 0.65
		emitter.randomness = 0.45
		emitter.emitting = false
		emitter.visible = true
		emitter.texture = _get_or_create_spark_texture()
		emitter.z_as_relative = true
		emitter.z_index = 1
		emitter.process_material = _build_corner_particle_material()
		add_child(emitter)
		_corner_emitters.append(emitter)


func _build_corner_particle_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3(0.0, 18.0, 0.0)
	mat.initial_velocity_min = 22.0
	mat.initial_velocity_max = 68.0
	mat.damping_min = 0.6
	mat.damping_max = 1.4
	mat.scale_min = 0.45
	mat.scale_max = 1.05
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = curve
	mat.scale_curve = scale_curve
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.95, 0.55, 1.0))
	gradient.set_color(1, Color(0.55, 0.65, 1.0, 0.0))
	gradient.add_point(0.35, Color(1.0, 0.45, 0.85, 1.0))
	gradient.add_point(0.7, Color(0.4, 0.95, 1.0, 0.55))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex
	return mat


func _apply_slot(rect: Rect2, intensity: float, weapon_id: String, elapsed_seconds: float) -> void:
	var sprite: Sprite2D = _slot_sprite
	if sprite == null:
		return
	var mat: ShaderMaterial = _slot_material
	if mat == null:
		return
	# Pop-in tween: when weapon_id changes (new acquisition) OR intensity crosses
	# the activation threshold from 0, snap pop_progress back to 0 and let it
	# ease toward 1 over POP_IN_FRAMES.
	var rearm := false
	if not _slot_active or weapon_id != _last_weapon_id:
		rearm = true
	if rearm:
		_pop_progress = 0.0
		_trigger_corner_burst(weapon_id)
	_pop_progress = clamp(_pop_progress + 1.0 / max(POP_IN_FRAMES, 1.0), 0.0, 1.0)

	var outer := rect.grow(PANEL_OUTER_GLOW_PX)
	sprite.visible = true
	sprite.position = outer.position + outer.size * 0.5
	var tex: Texture2D = sprite.texture
	var tex_w: float = float(tex.get_width()) if tex != null else 4.0
	var tex_h: float = float(tex.get_height()) if tex != null else 4.0
	if tex_w > 0.0 and tex_h > 0.0:
		sprite.scale = Vector2(outer.size.x / tex_w, outer.size.y / tex_h)

	var panel_half_uv: Vector2 = Vector2(
		(rect.size.x * 0.5) / max(outer.size.x, 1.0),
		(rect.size.y * 0.5) / max(outer.size.y, 1.0)
	)
	var border_thickness_uv: float = clamp(
		(min(rect.size.x, rect.size.y) * 0.18) / max(outer.size.x, outer.size.y),
		0.012,
		0.18
	)
	var outer_glow_uv: float = clamp(
		PANEL_OUTER_GLOW_PX / max(outer.size.x, outer.size.y),
		0.0,
		0.35
	)

	mat.set_shader_parameter("elapsed", elapsed_seconds)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("pop_progress", _pop_progress)
	mat.set_shader_parameter("panel_half_size_uv", panel_half_uv)
	mat.set_shader_parameter("border_thickness_uv", border_thickness_uv)
	mat.set_shader_parameter("outer_glow_uv", outer_glow_uv)

	# Position corner emitters at the actual panel corners (not the inflated
	# outer rect) so sparks blossom along the visible border.
	var corners := [
		rect.position,
		Vector2(rect.position.x + rect.size.x, rect.position.y),
		Vector2(rect.position.x, rect.position.y + rect.size.y),
		rect.position + rect.size,
	]
	for i in range(min(CORNER_COUNT, _corner_emitters.size())):
		var emitter: GPUParticles2D = _corner_emitters[i]
		if emitter == null:
			continue
		emitter.position = corners[i]
		# Light continuous emission while highlight is active, dimming with the
		# fade-out ratio.
		emitter.emitting = intensity > 0.05
		emitter.amount_ratio = clamp(intensity * (0.4 + 0.6 * _pop_progress), 0.0, 1.0)

	_slot_active = true
	_last_intensity = intensity
	_last_weapon_id = weapon_id


func _trigger_corner_burst(weapon_id: String) -> void:
	# Force a one-shot burst from each corner emitter on activation by
	# restarting them. Subsequent same-frame syncs in the same activation
	# window don't re-burst; we debounce on weapon_id + msec.
	var now_msec: int = Time.get_ticks_msec()
	if weapon_id == _last_burst_weapon_id and now_msec - _last_burst_msec < 200:
		return
	_last_burst_weapon_id = weapon_id
	_last_burst_msec = now_msec
	for emitter in _corner_emitters:
		if emitter == null:
			continue
		emitter.restart()
		emitter.emitting = true
