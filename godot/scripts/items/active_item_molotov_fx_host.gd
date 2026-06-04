extends Node2D

# 화염병 한 개의 fire zone 전용 모듈러 VFX 호스트.
#
# 모듈러 VFX 레이어링 (텍스처 + 셰이더 + 파티클 + 트윈) 패턴을 기존의
# 평면적인 ellipse-stack 화염 표현 위에 얹는다. 스테이지 5 홍련 inferno
# 패밀리의 WritheEmber 프리셋(`hongryun_inferno_*`)을 재사용해서 화염
# 톤의 chromatic-aberration + UV-writhe + flicker + breath alpha를 공짜로
# 얻는다.
#
# 레이어 구성:
#   1) Ember Floor    : 바닥에 누운 넓은 화염 베드. heat_texture +
#                        `hongryun_inferno_charge` 프리셋. 가로 stretch.
#   2) Flame Dome     : 위로 솟는 본 불꽃. 같은 heat_texture를 세로 stretch +
#                        `hongryun_inferno_trail` 프리셋 (격렬한 writhe).
#   3) Char Ring      : 그을린 땅 외곽 띠. dragon_ring_texture를
#                        다크 톤으로 modulate. `hongryun_inferno_dragon_ring`.
#   4) Burst Sprite   : 폭발 첫 프레임 one-shot 플래시. heat_texture +
#                        `hongryun_inferno_burst` 프리셋. tween 페이드.
#   5) Ember Particles: GPUParticles2D, sparkle_texture가 위로 날리는 잔불.
#
# 멀티-zone 지원: 이 호스트는 단일 zone만 담당. throw_renderer가 zone마다
# 호스트를 하나씩 할당하는 풀을 관리한다. zone이 끝나면 `set_active(false)`
# 한 번이면 모든 자식 sprite/particles가 visible=false + emitting=false로
# 내려가서 leak 없음 (inferno_burst_fx_host의 single-cleanup 패턴 차용).
#
# 다른 화염 류 스킬/아이템에도 재사용 가능: WritheEmber 프리셋만 갈아
# 끼우면 동일한 5-레이어 레시피를 보스 화염 필드, 위프 폭발, 다른 폭발
# 액티브 등에 그대로 적용할 수 있다.

const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")
const InfernoChargeFxHost := preload("res://scripts/stages/stage5/stage5_hongryun_inferno_charge_fx_host.gd")

const FLOOR_TEXTURE_BASE_SIZE := 192.0
const FLAME_DOME_TEXTURE_BASE_SIZE := 192.0
const CHAR_RING_TEXTURE_BASE_SIZE := 192.0
const BURST_TEXTURE_BASE_SIZE := 192.0
const BURST_FADE_IN_SEC := 0.08
const BURST_HOLD_SEC := 0.10
const BURST_FADE_OUT_SEC := 0.42
const EMBER_PARTICLE_AMOUNT := 44
const PARTICLE_FIXED_FPS := 30
const EMBER_PARTICLE_QUALITY_GATE := 0.55

var elapsed_sec := 0.0

var _state: Dictionary = {}
var _floor_sprite: Sprite2D = null
var _floor_material: ShaderMaterial = null
var _flame_dome_sprite: Sprite2D = null
var _flame_dome_material: ShaderMaterial = null
var _char_ring_sprite: Sprite2D = null
var _char_ring_material: ShaderMaterial = null
var _burst_sprite: Sprite2D = null
var _burst_material: ShaderMaterial = null
var _ember_particles: GPUParticles2D = null
var _additive_material: CanvasItemMaterial = null
var _burst_tween: Tween = null
var _burst_intensity := 0.0
var _ring_rotation := 0.0
var _flame_dome_phase := 0.0

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
		"molotov_fx_host_shader_floor_ready":
			WritheEmber.has_preset("hongryun_inferno_charge"),
		"molotov_fx_host_shader_flame_ready":
			WritheEmber.has_preset("hongryun_inferno_trail"),
		"molotov_fx_host_shader_char_ring_ready":
			WritheEmber.has_preset("hongryun_inferno_dragon_ring"),
		"molotov_fx_host_shader_burst_ready":
			WritheEmber.has_preset("hongryun_inferno_burst"),
		"molotov_fx_host_particle_amount": EMBER_PARTICLE_AMOUNT,
		"molotov_fx_host_layers": 5,
	}


func _ready() -> void:
	z_as_relative = false
	z_index = 8
	_additive_material = _make_additive_material()
	_build_children()
	set_active(visible and not _state.is_empty())


func sync_state(next_state: Dictionary, active: bool) -> void:
	if _floor_sprite == null:
		_build_children()
	_state = next_state.duplicate(false)
	set_active(active and can_handle_state(_state))
	if not visible:
		return
	elapsed_sec = float(Time.get_ticks_msec()) / 1000.0
	_apply_state()
	queue_redraw()


func can_handle_state(next_state: Dictionary) -> bool:
	return float(next_state.get("life_ratio", 0.0)) > 0.0


func set_active(active: bool) -> void:
	visible = active
	set_process(false)
	if not active:
		_kill_burst_tween()
		_burst_intensity = 0.0
		if _floor_sprite != null:
			_floor_sprite.visible = false
		if _flame_dome_sprite != null:
			_flame_dome_sprite.visible = false
		if _char_ring_sprite != null:
			_char_ring_sprite.visible = false
		if _burst_sprite != null:
			_burst_sprite.visible = false
		if _ember_particles != null:
			_ember_particles.emitting = false
		return


# 폭발 첫 프레임에 한 번 호출. 0.08초 fade-in → 0.10초 hold → 0.42초 fade-out.
# 이미 burst가 진행 중이면 즉시 끝내고 새로 시작 (state leak 차단).
func trigger_explosion_burst() -> void:
	if _burst_sprite == null:
		_build_children()
	_kill_burst_tween()
	_burst_intensity = 0.0
	if _burst_sprite != null:
		_burst_sprite.visible = true
	_burst_tween = create_tween()
	_burst_tween.tween_method(_apply_burst_intensity, 0.0, 1.0, BURST_FADE_IN_SEC).set_ease(Tween.EASE_OUT)
	_burst_tween.tween_interval(BURST_HOLD_SEC)
	_burst_tween.tween_method(_apply_burst_intensity, 1.0, 0.0, BURST_FADE_OUT_SEC).set_ease(Tween.EASE_IN)
	_burst_tween.tween_callback(_finish_burst)


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	if free_self:
		queue_free()


func get_debug_status() -> Dictionary:
	return {
		"active": visible,
		"life_ratio": float(_state.get("life_ratio", 0.0)),
		"burst_intensity": _burst_intensity,
		"floor_shader_ready":
			_floor_material != null and WritheEmber.is_material_using_shader(_floor_material),
		"flame_shader_ready":
			_flame_dome_material != null and WritheEmber.is_material_using_shader(_flame_dome_material),
		"char_ring_shader_ready":
			_char_ring_material != null and WritheEmber.is_material_using_shader(_char_ring_material),
		"burst_shader_ready":
			_burst_material != null and WritheEmber.is_material_using_shader(_burst_material),
		"ember_emitting": _ember_particles != null and _ember_particles.emitting,
	}


func _apply_state() -> void:
	# zone_pos는 throw_renderer가 game_offset + (zone_center + shake) * render_scale로
	# 계산해 넘긴 screen-space 좌표. host 자신을 그 위치에 두고, 자식
	# sprite/particle은 Vector2.ZERO에 두어 host.scale = render_scale가
	# 크기까지 일치시키게 한다 (stage5_hongryun_inferno_burst_fx_host 패턴).
	var zone_pos: Vector2 = _as_vector2(_state.get("zone_pos", Vector2(380.0, 15.0)), Vector2(380.0, 15.0))
	var render_scale: float = max(0.01, float(_state.get("render_scale", 1.0)))
	position = zone_pos
	scale = Vector2(render_scale, render_scale)

	var width: float = max(20.0, float(_state.get("width", 150.0)))
	var height: float = max(10.0, float(_state.get("height", 60.0)))
	var life_ratio: float = clamp(float(_state.get("life_ratio", 1.0)), 0.0, 1.0)
	var quality_scale: float = clamp(float(_state.get("quality_scale", 1.0)), 0.0, 1.0)

	# Time-driven breathing for size+alpha jitter so the field reads as living
	# fire instead of a static decal. UV writhe already comes from the shader;
	# this just gives the overall silhouette a subtle bob.
	_flame_dome_phase = elapsed_sec * 1.7
	var breath: float = 0.85 + 0.15 * sin(_flame_dome_phase)
	var breath_slow: float = 0.90 + 0.10 * sin(_flame_dome_phase * 0.55 + 1.2)

	# Layer 1 — Ember Floor (wide horizontal bed)
	if _floor_sprite != null:
		_floor_sprite.position = Vector2.ZERO
		var floor_w: float = width * 1.08 * breath_slow
		var floor_h: float = height * 1.40
		_floor_sprite.scale = Vector2(floor_w / FLOOR_TEXTURE_BASE_SIZE, floor_h / FLOOR_TEXTURE_BASE_SIZE)
		var floor_alpha: float = clamp(0.72 * life_ratio * (0.6 + 0.4 * quality_scale), 0.0, 1.0)
		_floor_sprite.modulate = Color(1.0, 0.92, 0.78, floor_alpha)
		_floor_sprite.visible = true
		if _floor_material != null:
			_floor_material.set_shader_parameter("elapsed", elapsed_sec)
			_floor_material.set_shader_parameter("intensity", 0.85 + 0.25 * life_ratio)

	# Layer 2 — Flame Dome (vertical pillars rising above the floor)
	if _flame_dome_sprite != null:
		# Anchor the dome so the bottom sits at the floor center; rising flames
		# read as growing UP from the ground instead of centered on the bed.
		var dome_h: float = max(height * 1.6, 80.0) * breath
		var dome_w: float = max(width * 0.92, 50.0) * breath_slow
		_flame_dome_sprite.position = Vector2(0.0, -dome_h * 0.18)
		_flame_dome_sprite.scale = Vector2(
			dome_w / FLAME_DOME_TEXTURE_BASE_SIZE,
			dome_h / FLAME_DOME_TEXTURE_BASE_SIZE
		)
		var dome_alpha: float = clamp(0.78 * life_ratio * (0.7 + 0.3 * quality_scale), 0.0, 1.0)
		_flame_dome_sprite.modulate = Color(1.0, 0.85, 0.62, dome_alpha)
		_flame_dome_sprite.visible = true
		if _flame_dome_material != null:
			_flame_dome_material.set_shader_parameter("elapsed", elapsed_sec)
			_flame_dome_material.set_shader_parameter("intensity", 0.95 + 0.30 * life_ratio)

	# Layer 3 — Char Ring (charred ground belt under the flames)
	if _char_ring_sprite != null:
		_char_ring_sprite.position = Vector2(0.0, height * 0.18)
		_ring_rotation += 0.012
		_char_ring_sprite.rotation = _ring_rotation
		var ring_w: float = width * 1.18
		var ring_h: float = max(height * 0.95, 30.0)
		_char_ring_sprite.scale = Vector2(
			ring_w / CHAR_RING_TEXTURE_BASE_SIZE,
			ring_h / CHAR_RING_TEXTURE_BASE_SIZE
		)
		# Dark red-brown char tone; fades together with the fire.
		var ring_alpha: float = clamp(0.55 * life_ratio, 0.0, 1.0)
		_char_ring_sprite.modulate = Color(0.55, 0.18, 0.10, ring_alpha)
		_char_ring_sprite.visible = true
		if _char_ring_material != null:
			_char_ring_material.set_shader_parameter("elapsed", elapsed_sec)
			_char_ring_material.set_shader_parameter("intensity", 0.45 + 0.25 * life_ratio)

	# Layer 5 — Ember particles (drifting upward sparks)
	if _ember_particles != null:
		_ember_particles.position = Vector2(0.0, -height * 0.1)
		var allow_particles: bool = quality_scale >= EMBER_PARTICLE_QUALITY_GATE and life_ratio > 0.05
		# Only restart emission on the rising edge so the existing in-flight
		# sparks live out their natural lifetime instead of snapping off when
		# life_ratio dips below 0.05 mid-tick.
		if allow_particles and not _ember_particles.emitting:
			_ember_particles.restart()
		_ember_particles.emitting = allow_particles
		var process_mat: ParticleProcessMaterial = _ember_particles.process_material
		if process_mat != null:
			# Cooler color as the fire dies down — bright orange → dim red.
			var ember_color := Color(1.0, 0.55 + 0.25 * life_ratio, 0.18, 0.65 + 0.25 * life_ratio)
			process_mat.color = ember_color
			# Spawn ring follows the floor width so embers come from the whole bed.
			process_mat.emission_ring_radius = width * 0.42
			process_mat.emission_ring_inner_radius = width * 0.18


func _apply_burst_intensity(value: float) -> void:
	_burst_intensity = clamp(value, 0.0, 1.0)
	if _burst_sprite == null:
		return
	# Burst grows outward as it fades, like an inferno shockwave.
	var burst_grow: float = 0.55 + _burst_intensity * 0.95
	var width: float = max(20.0, float(_state.get("width", 150.0)))
	var burst_diameter: float = max(width * 1.6, 220.0) * burst_grow
	_burst_sprite.position = Vector2.ZERO
	_burst_sprite.scale = Vector2(
		burst_diameter / BURST_TEXTURE_BASE_SIZE,
		burst_diameter / BURST_TEXTURE_BASE_SIZE
	)
	var burst_alpha: float = clamp(_burst_intensity * 1.00, 0.0, 1.0)
	_burst_sprite.modulate = Color(1.0, 0.95, 0.78, burst_alpha)
	if _burst_material != null:
		_burst_material.set_shader_parameter("elapsed", elapsed_sec)
		_burst_material.set_shader_parameter("intensity", 0.85 + _burst_intensity * 0.85)


func _finish_burst() -> void:
	if _burst_sprite != null:
		_burst_sprite.visible = false
	_burst_intensity = 0.0


func _kill_burst_tween() -> void:
	if _burst_tween != null and _burst_tween.is_valid():
		_burst_tween.kill()
	_burst_tween = null


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()

	if _char_ring_sprite == null:
		_char_ring_sprite = Sprite2D.new()
		_char_ring_sprite.name = "MolotovCharRing"
		_char_ring_sprite.centered = true
		_char_ring_sprite.texture = InfernoChargeFxHost._get_dragon_ring_texture()
		_char_ring_sprite.material = WritheEmber.build_material("hongryun_inferno_dragon_ring")
		_char_ring_sprite.visible = false
		_char_ring_sprite.z_index = 0
		add_child(_char_ring_sprite)
		_char_ring_material = _char_ring_sprite.material as ShaderMaterial

	if _floor_sprite == null:
		_floor_sprite = Sprite2D.new()
		_floor_sprite.name = "MolotovEmberFloor"
		_floor_sprite.centered = true
		_floor_sprite.texture = InfernoChargeFxHost._get_heat_texture()
		_floor_sprite.material = WritheEmber.build_material("hongryun_inferno_charge")
		_floor_sprite.visible = false
		_floor_sprite.z_index = 1
		add_child(_floor_sprite)
		_floor_material = _floor_sprite.material as ShaderMaterial

	if _flame_dome_sprite == null:
		_flame_dome_sprite = Sprite2D.new()
		_flame_dome_sprite.name = "MolotovFlameDome"
		_flame_dome_sprite.centered = true
		_flame_dome_sprite.texture = InfernoChargeFxHost._get_heat_texture()
		_flame_dome_sprite.material = WritheEmber.build_material("hongryun_inferno_trail")
		_flame_dome_sprite.visible = false
		_flame_dome_sprite.z_index = 2
		add_child(_flame_dome_sprite)
		_flame_dome_material = _flame_dome_sprite.material as ShaderMaterial

	if _burst_sprite == null:
		_burst_sprite = Sprite2D.new()
		_burst_sprite.name = "MolotovExplosionBurst"
		_burst_sprite.centered = true
		_burst_sprite.texture = InfernoChargeFxHost._get_heat_texture()
		_burst_sprite.material = WritheEmber.build_material("hongryun_inferno_burst")
		_burst_sprite.visible = false
		_burst_sprite.z_index = 3
		add_child(_burst_sprite)
		_burst_material = _burst_sprite.material as ShaderMaterial

	if _ember_particles == null:
		_ember_particles = GPUParticles2D.new()
		_ember_particles.name = "MolotovEmberParticles"
		_ember_particles.amount = EMBER_PARTICLE_AMOUNT
		_ember_particles.lifetime = 0.85
		_ember_particles.one_shot = false
		_ember_particles.explosiveness = 0.0
		_ember_particles.randomness = 0.95
		_ember_particles.fixed_fps = PARTICLE_FIXED_FPS
		_ember_particles.local_coords = true
		_ember_particles.visibility_rect = Rect2(-220.0, -260.0, 440.0, 360.0)
		_ember_particles.texture = ImpactFlareTextureCache.get_sparkle_texture()
		_ember_particles.material = _additive_material
		_ember_particles.process_material = _build_upward_ember_material()
		_ember_particles.emitting = false
		_ember_particles.z_index = 4
		add_child(_ember_particles)


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


static func _build_upward_ember_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	# Upward bias — embers float up like real fire, not radial outward.
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 35.0
	mat.gravity = Vector3(0.0, -55.0, 0.0)
	mat.initial_velocity_min = 22.0
	mat.initial_velocity_max = 58.0
	mat.radial_accel_min = -10.0
	mat.radial_accel_max = 14.0
	mat.tangential_accel_min = -55.0
	mat.tangential_accel_max = 55.0
	mat.damping_min = 18.0
	mat.damping_max = 44.0
	mat.scale_min = 0.025
	mat.scale_max = 0.060
	mat.color = Color(1.0, 0.62, 0.20, 0.85)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = 64.0
	mat.emission_ring_inner_radius = 28.0
	mat.emission_ring_height = 0.0
	return mat


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
