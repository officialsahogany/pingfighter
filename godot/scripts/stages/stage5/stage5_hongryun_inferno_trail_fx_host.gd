extends Node2D

# 홍련폭염 trail phase(phase 2) head VFX 호스트.
# Charge phase의 모듈러 VFX 패턴을 trail head에 적용 — head sprite + dragon
# scale ring + inward ember particles의 3-layer를 trail의 가장 최근 점에
#마운트해서 공이 화면을 가로지를 때 head가 살아있는 잔불처럼 보이게 한다.
# 기존 playfield_renderer의 line-based trail draw는 그대로 유지되고, 이 호스트는
# 그 위에 head 강조 layer만 추가한다.
#
# 단일 cleanup query 패턴 (CLAUDE.md "Godot ball-owning skills must clear
# skip_ball_motion_step on every release path"):
# sync_state(active=false) 한 번이면 모든 자식 sprite/particles가 visible=false
# + emitting=false로 내려가서 leak 없음.

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")
const InfernoChargeFxHost := preload("res://scripts/stages/stage5/stage5_hongryun_inferno_charge_fx_host.gd")

const HEAD_QUAD_SIZE := 200.0
const DRAGON_RING_SIZE := 260.0
const DRAGON_RING_ROTATION_SPEED := 2.2
const EMBER_PARTICLE_AMOUNT := 28
const PARTICLE_FIXED_FPS := 30

var elapsed_sec := 0.0

var _state: Dictionary = {}
var _head_sprite: Sprite2D = null
var _head_material: ShaderMaterial = null
var _dragon_ring_sprite: Sprite2D = null
var _dragon_ring_material: ShaderMaterial = null
var _ember_particles: GPUParticles2D = null
var _additive_material: CanvasItemMaterial = null

static var _prewarmed := false


static func prewarm_assets() -> void:
	if _prewarmed:
		return
	ImpactFlareTextureCache.prewarm()
	WritheEmber.prewarm()
	InfernoChargeFxHost.prewarm_assets()
	_prewarmed = true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"stage5_hongryun_inferno_trail_shader_ready":
			WritheEmber.has_preset("hongryun_inferno_trail"),
		"stage5_hongryun_inferno_trail_dragon_ring_ready":
			WritheEmber.has_preset("hongryun_inferno_dragon_ring"),
		"stage5_hongryun_inferno_trail_particle_amount": EMBER_PARTICLE_AMOUNT,
	}


func _ready() -> void:
	z_as_relative = false
	z_index = 11
	_additive_material = _make_additive_material()
	_build_children()
	set_active(visible and not _state.is_empty())


func sync_state(next_state: Dictionary, active: bool) -> void:
	if _head_sprite == null:
		_build_children()
	_state = next_state.duplicate(false)
	set_active(active and can_handle_state(_state))
	if not visible:
		return
	elapsed_sec = float(Time.get_ticks_msec()) / 1000.0
	_apply_state()
	queue_redraw()


func can_handle_state(next_state: Dictionary) -> bool:
	return bool(next_state.get("phase_active", false))


func set_active(active: bool) -> void:
	visible = active
	set_process(false)
	if not active:
		if _head_sprite != null:
			_head_sprite.visible = false
		if _dragon_ring_sprite != null:
			_dragon_ring_sprite.visible = false
		if _ember_particles != null:
			_ember_particles.emitting = false
		return


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	if free_self:
		queue_free()


func get_debug_status() -> Dictionary:
	return {
		"active": visible,
		"head_shader_ready": _head_material != null and WritheEmber.is_material_using_shader(_head_material),
		"dragon_ring_visible": _dragon_ring_sprite != null and _dragon_ring_sprite.visible,
		"ember_emitting": _ember_particles != null and _ember_particles.emitting,
	}


func _apply_state() -> void:
	if _head_sprite == null:
		return
	# head_pos는 playfield_renderer가 game_offset + (playfield_pos + shake) * render_scale로
	# 계산해 넘긴 screen-space 좌표. 호스트는 그 위치에 자기 자신을 두고,
	# 자식 sprite/particle은 Vector2.ZERO에 두어 host.scale = render_scale가
	# 크기까지 일치시키게 한다 (stage1_commando_firearm_fx_host 패턴).
	var head_pos: Vector2 = _as_vector2(_state.get("head_pos", Vector2(380.0, 375.0)), Vector2(380.0, 375.0))
	var render_scale: float = max(0.01, float(_state.get("render_scale", 1.0)))
	position = head_pos
	scale = Vector2(render_scale, render_scale)
	var trail_elapsed: float = max(0.0, float(_state.get("trail_elapsed_sec", 0.0)))
	var enraged: bool = bool(_state.get("enraged", false))
	var quality_scale: float = clamp(float(_state.get("quality_scale", 1.0)), 0.0, 1.0)

	# Head sprite grows slightly as trail picks up speed (visual acceleration).
	var growth: float = clamp(trail_elapsed / 4.0, 0.0, 1.0)
	var head_size: float = HEAD_QUAD_SIZE * (0.85 + growth * 0.35)
	_head_sprite.position = Vector2.ZERO
	var head_texture := InfernoChargeFxHost._get_heat_texture()
	if head_texture != null:
		var tex_size: Vector2 = head_texture.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			_head_sprite.scale = Vector2(head_size / tex_size.x, head_size / tex_size.y)
	var head_alpha: float = 0.62 + growth * 0.28
	if enraged:
		head_alpha = min(1.0, head_alpha + 0.10)
	head_alpha *= 0.55 + 0.45 * quality_scale
	_head_sprite.modulate = Color(1.0, 1.0, 1.0, clamp(head_alpha, 0.0, 1.0))
	_head_sprite.visible = true
	if _head_material != null:
		_head_material.set_shader_parameter("elapsed", elapsed_sec)
		_head_material.set_shader_parameter("intensity", 1.0 + growth * 0.35)

	# Dragon scale ring orbits head + rotates faster with trail age.
	if _dragon_ring_sprite != null:
		_dragon_ring_sprite.position = Vector2.ZERO
		var ring_tex := InfernoChargeFxHost._get_dragon_ring_texture()
		if ring_tex != null:
			var ring_tex_size: Vector2 = ring_tex.get_size()
			if ring_tex_size.x > 0.0 and ring_tex_size.y > 0.0:
				var ring_size: float = DRAGON_RING_SIZE * (0.90 + growth * 0.18)
				_dragon_ring_sprite.scale = Vector2(
					ring_size / ring_tex_size.x,
					ring_size / ring_tex_size.y
				)
		_dragon_ring_sprite.rotation = elapsed_sec * DRAGON_RING_ROTATION_SPEED * (1.0 + growth * 0.4)
		var ring_alpha: float = 0.40 + growth * 0.32
		if enraged:
			ring_alpha = min(1.0, ring_alpha + 0.08)
		ring_alpha *= 0.55 + 0.45 * quality_scale
		_dragon_ring_sprite.modulate = Color(1.0, 1.0, 1.0, clamp(ring_alpha, 0.0, 1.0))
		_dragon_ring_sprite.visible = true
		if _dragon_ring_material != null:
			_dragon_ring_material.set_shader_parameter("elapsed", elapsed_sec)
			_dragon_ring_material.set_shader_parameter("intensity", 0.95 + growth * 0.30)

	# Inward ember particles orbiting head.
	if _ember_particles != null:
		_ember_particles.position = Vector2.ZERO
		var allow_particles: bool = quality_scale >= 0.55
		_ember_particles.emitting = allow_particles
		var process_mat: ParticleProcessMaterial = _ember_particles.process_material
		if process_mat != null:
			var ember_color := Color(1.0, 0.50, 0.18, 0.65 + growth * 0.25)
			if enraged:
				ember_color = Color(1.0, 0.32, 0.12, 0.78 + growth * 0.18)
			process_mat.color = ember_color


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()

	if _head_sprite == null:
		_head_sprite = Sprite2D.new()
		_head_sprite.name = "InfernoTrailHeadCore"
		_head_sprite.centered = true
		_head_sprite.texture = InfernoChargeFxHost._get_heat_texture()
		_head_sprite.material = WritheEmber.build_material("hongryun_inferno_trail")
		_head_sprite.visible = false
		_head_sprite.z_index = 0
		add_child(_head_sprite)
		_head_material = _head_sprite.material as ShaderMaterial

	if _dragon_ring_sprite == null:
		_dragon_ring_sprite = Sprite2D.new()
		_dragon_ring_sprite.name = "InfernoTrailDragonRing"
		_dragon_ring_sprite.centered = true
		_dragon_ring_sprite.texture = InfernoChargeFxHost._get_dragon_ring_texture()
		_dragon_ring_sprite.material = WritheEmber.build_material("hongryun_inferno_dragon_ring")
		_dragon_ring_sprite.visible = false
		_dragon_ring_sprite.z_index = 1
		add_child(_dragon_ring_sprite)
		_dragon_ring_material = _dragon_ring_sprite.material as ShaderMaterial

	if _ember_particles == null:
		_ember_particles = GPUParticles2D.new()
		_ember_particles.name = "InfernoTrailEmberParticles"
		_ember_particles.amount = EMBER_PARTICLE_AMOUNT
		_ember_particles.lifetime = 0.55
		_ember_particles.one_shot = false
		_ember_particles.explosiveness = 0.0
		_ember_particles.randomness = 0.92
		_ember_particles.fixed_fps = PARTICLE_FIXED_FPS
		_ember_particles.local_coords = true
		_ember_particles.visibility_rect = Rect2(-180.0, -180.0, 360.0, 360.0)
		_ember_particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
		_ember_particles.material = _additive_material
		_ember_particles.process_material = _build_inward_ember_material()
		_ember_particles.emitting = false
		_ember_particles.z_index = 2
		add_child(_ember_particles)


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


static func _build_inward_ember_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 14.0
	mat.radial_accel_min = -160.0
	mat.radial_accel_max = -90.0
	mat.tangential_accel_min = -80.0
	mat.tangential_accel_max = 80.0
	mat.damping_min = 14.0
	mat.damping_max = 38.0
	mat.scale_min = 0.020
	mat.scale_max = 0.055
	mat.color = Color(1.0, 0.50, 0.18, 0.65)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = 72.0
	mat.emission_ring_inner_radius = 48.0
	mat.emission_ring_height = 0.0
	return mat


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
