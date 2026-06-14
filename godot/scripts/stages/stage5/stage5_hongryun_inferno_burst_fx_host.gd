extends Node2D

# 홍련폭염 trail이 플레이어 또는 safety timeout에 도달했을 때 한 번 발동하는
# 1회성 폭발 burst. Charge / Trail host의 지속 VFX와 달리 trigger_burst() 한
# 번이면 자체 tween으로 0.08초 페이드인 → 0.10초 hold → 0.42초 페이드아웃 후
# 자동으로 visible=false로 내려간다. 같은 burst가 연속으로 트리거되면 직전
# burst를 즉시 끝내고 새 burst로 재시작 (state leak 차단).

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")
const InfernoChargeFxHost := preload("res://scripts/stages/stage5/stage5_hongryun_inferno_charge_fx_host.gd")

const BURST_PEAK_SIZE := 360.0
const BURST_RING_SIZE := 460.0
const BURST_FADE_IN_SEC := 0.08
const BURST_HOLD_SEC := 0.10
const BURST_FADE_OUT_SEC := 0.42
const BURST_PARTICLE_AMOUNT := 56
const PARTICLE_FIXED_FPS := 30

var elapsed_sec := 0.0

var _state: Dictionary = {}
var _core_sprite: Sprite2D = null
var _core_material: ShaderMaterial = null
var _ring_sprite: Sprite2D = null
var _ring_material: ShaderMaterial = null
var _ember_particles: GPUParticles2D = null
var _additive_material: CanvasItemMaterial = null
var _active_tween: Tween = null
var _intensity := 0.0
var _ring_rotation := 0.0

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
		"stage5_hongryun_inferno_burst_shader_ready":
			WritheEmber.has_preset("hongryun_inferno_burst"),
		"stage5_hongryun_inferno_burst_particle_amount": BURST_PARTICLE_AMOUNT,
	}


func _ready() -> void:
	z_as_relative = false
	z_index = 14
	_additive_material = _make_additive_material()
	_build_children()
	set_active(visible and not _state.is_empty())


# 한 번의 폭발 burst를 트리거. burst_pos는 playfield_renderer가
# game_offset + (playfield_pos + shake) * render_scale로 계산해 넘긴
# screen-space 좌표. render_scale은 host node에 적용해 자식 sprite/
# particle 크기까지 한 번에 맞춘다 (stage1_commando_firearm_fx_host 패턴).
func trigger_burst(burst_pos: Vector2, enraged: bool = false, quality_scale: float = 1.0, render_scale: float = 1.0) -> void:
	if _core_sprite == null:
		_build_children()
	_state = {
		"burst_pos": burst_pos,
		"enraged": enraged,
		"quality_scale": clamp(quality_scale, 0.0, 1.0),
		"render_scale": max(0.01, render_scale),
	}
	set_active(true)
	position = burst_pos
	scale = Vector2(max(0.01, render_scale), max(0.01, render_scale))
	_position_children(Vector2.ZERO)
	_kill_active_tween()
	_intensity = 0.0
	_ring_rotation = 0.0
	if _ember_particles != null:
		_ember_particles.restart()
		_ember_particles.emitting = quality_scale >= 0.45
	_active_tween = create_tween()
	_active_tween.tween_method(_apply_intensity, 0.0, 1.0, BURST_FADE_IN_SEC).set_ease(Tween.EASE_OUT)
	_active_tween.tween_interval(BURST_HOLD_SEC)
	_active_tween.tween_method(_apply_intensity, 1.0, 0.0, BURST_FADE_OUT_SEC).set_ease(Tween.EASE_IN)
	_active_tween.tween_callback(_finish_burst)


func set_active(active: bool) -> void:
	visible = active
	set_process(active)
	if not active:
		_kill_active_tween()
		_intensity = 0.0
		if _core_sprite != null:
			_core_sprite.visible = false
		if _ring_sprite != null:
			_ring_sprite.visible = false
		if _ember_particles != null:
			_ember_particles.emitting = false
		return
	if _core_sprite != null:
		_core_sprite.visible = true
	if _ring_sprite != null:
		_ring_sprite.visible = true


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	if free_self:
		queue_free()


func get_debug_status() -> Dictionary:
	return {
		"active": visible,
		"intensity": _intensity,
		"core_shader_ready": _core_material != null and WritheEmber.is_material_using_shader(_core_material),
	}


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed_sec += delta
	_ring_rotation += delta * 4.0
	if _ring_sprite != null:
		_ring_sprite.rotation = _ring_rotation
	if _core_material != null:
		_core_material.set_shader_parameter("elapsed", elapsed_sec)
	if _ring_material != null:
		_ring_material.set_shader_parameter("elapsed", elapsed_sec)


func _apply_intensity(value: float) -> void:
	_intensity = clamp(value, 0.0, 1.0)
	var enraged: bool = bool(_state.get("enraged", false))
	var quality_scale: float = clamp(float(_state.get("quality_scale", 1.0)), 0.0, 1.0)
	var quality_damp: float = 0.55 + 0.45 * quality_scale
	# Core peaks fast then fades — eased shape comes from the tween itself.
	if _core_sprite != null:
		var core_alpha: float = clamp(_intensity * (1.10 if enraged else 1.0) * quality_damp, 0.0, 1.0)
		_core_sprite.modulate = Color(1.0, 1.0, 1.0, core_alpha)
		var core_grow: float = 0.85 + _intensity * 0.30
		var core_tex := InfernoChargeFxHost._get_heat_texture()
		if core_tex != null:
			var core_tex_size: Vector2 = core_tex.get_size()
			if core_tex_size.x > 0.0 and core_tex_size.y > 0.0:
				var core_size: float = BURST_PEAK_SIZE * core_grow
				_core_sprite.scale = Vector2(core_size / core_tex_size.x, core_size / core_tex_size.y)
	if _ring_sprite != null:
		var ring_alpha: float = clamp(_intensity * 0.85 * quality_damp, 0.0, 1.0)
		_ring_sprite.modulate = Color(1.0, 1.0, 1.0, ring_alpha)
		var ring_grow: float = 0.55 + _intensity * 0.95  # Expands outward as it fades.
		var ring_tex := InfernoChargeFxHost._get_dragon_ring_texture()
		if ring_tex != null:
			var ring_tex_size: Vector2 = ring_tex.get_size()
			if ring_tex_size.x > 0.0 and ring_tex_size.y > 0.0:
				var ring_size: float = BURST_RING_SIZE * ring_grow
				_ring_sprite.scale = Vector2(ring_size / ring_tex_size.x, ring_size / ring_tex_size.y)
	if _core_material != null:
		_core_material.set_shader_parameter("intensity", 0.6 + _intensity * 0.9)
	if _ring_material != null:
		_ring_material.set_shader_parameter("intensity", 0.6 + _intensity * 0.7)


func _finish_burst() -> void:
	set_active(false)


func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _position_children(burst_pos: Vector2) -> void:
	if _core_sprite != null:
		_core_sprite.position = burst_pos
	if _ring_sprite != null:
		_ring_sprite.position = burst_pos
	if _ember_particles != null:
		_ember_particles.position = burst_pos


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()

	if _core_sprite == null:
		_core_sprite = Sprite2D.new()
		_core_sprite.name = "InfernoBurstCore"
		_core_sprite.centered = true
		_core_sprite.texture = InfernoChargeFxHost._get_heat_texture()
		_core_sprite.material = WritheEmber.build_material("hongryun_inferno_burst")
		_core_sprite.visible = false
		_core_sprite.z_index = 1
		add_child(_core_sprite)
		_core_material = _core_sprite.material as ShaderMaterial

	if _ring_sprite == null:
		_ring_sprite = Sprite2D.new()
		_ring_sprite.name = "InfernoBurstRing"
		_ring_sprite.centered = true
		_ring_sprite.texture = InfernoChargeFxHost._get_dragon_ring_texture()
		_ring_sprite.material = WritheEmber.build_material("hongryun_inferno_burst")
		_ring_sprite.visible = false
		_ring_sprite.z_index = 0
		add_child(_ring_sprite)
		_ring_material = _ring_sprite.material as ShaderMaterial

	if _ember_particles == null:
		_ember_particles = GPUParticles2D.new()
		_ember_particles.name = "InfernoBurstEmberParticles"
		_ember_particles.amount = BURST_PARTICLE_AMOUNT
		_ember_particles.lifetime = 0.65
		_ember_particles.one_shot = true
		_ember_particles.explosiveness = 0.92
		_ember_particles.randomness = 0.95
		_ember_particles.fixed_fps = PARTICLE_FIXED_FPS
		_ember_particles.local_coords = true
		_ember_particles.visibility_rect = Rect2(-260.0, -260.0, 520.0, 520.0)
		_ember_particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
		_ember_particles.material = _additive_material
		_ember_particles.process_material = _build_outward_ember_material()
		_ember_particles.emitting = false
		_ember_particles.z_index = 2
		add_child(_ember_particles)


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


static func _build_outward_ember_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 140.0
	mat.initial_velocity_max = 320.0
	mat.radial_accel_min = 80.0
	mat.radial_accel_max = 200.0
	mat.tangential_accel_min = -120.0
	mat.tangential_accel_max = 120.0
	mat.damping_min = 80.0
	mat.damping_max = 180.0
	mat.scale_min = 0.045
	mat.scale_max = 0.090
	mat.color = Color(1.0, 0.62, 0.18, 0.88)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	return mat
