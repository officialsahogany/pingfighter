extends Node2D

# 스매셔 플라즈마 3-피스 모듈러 VFX 호스트 (절차적 라인-그리기 스타일 대체).
#
# 정적 텍스처 3장(Gemini imagegen, 휘도->알파 + 라디얼 마스크) + writhe-ember 셰이더
# + GPUParticles2D + Tween-구동 intensity 엔벨로프로 합성한다. 모션은 전부 엔진 측:
# 셰이더(UV 디스토트/브레스/색수차/플로우/플리커) + 파티클(emission/scale/fade) +
# 외부 intensity 엔벨로프(charge_size / wave energy).
#
# 블렌드 의도 분리 (빛=ADD, 실체=MIX):
#   - backplate(분위기·깊이) : writhe-ember(blend_add)  = 빛
#   - arc(율동, 회전 필라멘트) : writhe-ember(blend_add)  = 빛
#   - particles(에너지 모트)   : additive CanvasItemMaterial = 빛
#   - core(실체 구체)          : 기본 MIX Sprite2D          = 실체
#
# 회귀 가드:
#   - 별도 _draw 셰이더 패스 없음 -> draw_set_transform+IDENTITY 트랩 원천 회피.
#     각 Sprite2D가 자기 ShaderMaterial을 들고 노드가 transform을 처리한다.
#   - 좌표: 렌더러가 game_offset + (playfield_pos+shake)*render_scale로 계산한
#     screen-space pos를 넘기고, 호스트는 position=pos / scale=render_scale, 자식은
#     ZERO에 둔다 (평면 스프라이트를 3D 라이팅처럼 만들지 않는다 — 순수 2D 발광).
#   - 단일 cleanup: set_active(false) 한 번에 전 자식 visible=false + emitting=false.

const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const BACKPLATE_PATH := "res://assets/sprites/skills/plasma_vfx/plasma_backplate.png"
const ARC_PATH := "res://assets/sprites/skills/plasma_vfx/plasma_arc.png"
const PARTICLE_PATH := "res://assets/sprites/skills/plasma_vfx/plasma_particle.png"

# 오브 반경(playfield px) 대비 각 레이어의 지름 배수.
const BACKPLATE_DIAM_MULT := 2.8   # 방전 볼트 필드: 오브 밖으로 뻗음
const ARC_DIAM_MULT := 1.9         # 회전 자기장 필드 링: 오브에 가깝게
const CORE_DIAM_MULT := 0.95       # 실체 전기 뉴클리어스
const ARC_SPIN_SPEED := 1.6

const PARTICLE_AMOUNT := 26
const PARTICLE_FIXED_FPS := 30
const PARTICLE_QUALITY_GATE := 0.55
const WAVE_POP_SCALE := 1.18
const WAVE_POP_SECONDS := 0.12
# 파동이 매끄럽게 미끄러지지 않고 불안정하게 흔들리며 나아가도록 하는 위블. 자식
# 레이어에만 적용해 호스트 position(좌표 씰)은 pos로 유지한다. 3-옥타브(fBm식)로
# 빠른 기본 위빙 + 중간 + 고주파 미세 디테일 떨림을 겹친다. 주파수는 72fps
# Nyquist(36Hz) 아래로 유지. 진폭은 오브 반경 * 세기 비례.
const WOBBLE_AMP_MULT := 0.055
const WOBBLE_FREQ_1 := 34.0    # ~5.4Hz 기본 위빙
const WOBBLE_FREQ_2 := 76.0    # ~12.1Hz 중간
const WOBBLE_FREQ_3 := 118.0   # ~18.8Hz 미세 디테일
# 코어 뉴클리어스가 정지 이미지로 보이지 않도록 저속 반대회전 + 맥동.
const CORE_SPIN_SPEED := -0.9

var elapsed_sec := 0.0

var _state: Dictionary = {}
var _phase_envelope := 1.0
var _backplate: Sprite2D = null
var _backplate_material: ShaderMaterial = null
var _arc: Sprite2D = null
var _arc_material: ShaderMaterial = null
var _core: Sprite2D = null
var _particles: GPUParticles2D = null
var _additive_material: CanvasItemMaterial = null
var _last_enraged := false
var _last_phase := ""
var _pop_tween: Tween = null

static var _backplate_texture: Texture2D = null
static var _arc_texture: Texture2D = null
static var _particle_texture: Texture2D = null
static var _prewarmed := false


static func prewarm_assets() -> void:
	if _prewarmed:
		return
	WritheEmber.prewarm()
	_get_backplate_texture()
	_get_arc_texture()
	_get_particle_texture()
	_prewarmed = true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"smasher_plasma_orb_shader_ready": WritheEmber.has_preset("smasher_plasma_orb"),
		"smasher_plasma_orb_enraged_shader_ready": WritheEmber.has_preset("smasher_plasma_orb_enraged"),
		"smasher_plasma_arc_shader_ready": WritheEmber.has_preset("smasher_plasma_arc"),
		"smasher_plasma_backplate_texture_ready": _get_backplate_texture() != null,
		"smasher_plasma_arc_texture_ready": _get_arc_texture() != null,
		"smasher_plasma_particle_texture_ready": _get_particle_texture() != null,
		"smasher_plasma_particle_amount": PARTICLE_AMOUNT,
	}


func _ready() -> void:
	z_as_relative = false
	z_index = 9
	_additive_material = _make_additive_material()
	_build_children()
	# 트리 진입 시: 유효한 활성 상태(phase_active + Vector2 pos)가 있으면 in-tree에서
	# 그 위치로 즉시 재적용한다(트리 밖 deferred-add 이전 프레임에 세팅된 상태를 그대로
	# 렌더하지 않는다). 없으면 숨긴다 → 잘못된 위치에 한 프레임 뜨는 것을 차단.
	if not _state.is_empty() and bool(_state.get("phase_active", false)) and (_state.get("pos") is Vector2):
		elapsed_sec = float(Time.get_ticks_msec()) / 1000.0
		set_active(can_handle_state(_state))
		if visible:
			_apply_state()
	else:
		set_active(false)


func sync_state(next_state: Dictionary, active: bool) -> void:
	if _backplate == null:
		_build_children()
	if not active:
		_kill_pop_tween()
		_phase_envelope = 1.0
		_last_phase = ""
		_state = next_state.duplicate(false)
		set_active(false)
		return
	_state = next_state.duplicate(false)
	var next_phase := str(_state.get("phase", ""))
	_sync_phase_envelope(next_phase)
	set_active(active and can_handle_state(_state))
	if not visible:
		return
	elapsed_sec = float(Time.get_ticks_msec()) / 1000.0
	_apply_state()
	_last_phase = next_phase
	queue_redraw()


func can_handle_state(next_state: Dictionary) -> bool:
	return bool(next_state.get("phase_active", false)) and float(next_state.get("radius", 0.0)) > 0.5


func set_active(active: bool) -> void:
	visible = active
	set_process(false)
	if not active:
		_kill_pop_tween()
		_phase_envelope = 1.0
		if _backplate != null:
			_backplate.visible = false
		if _arc != null:
			_arc.visible = false
		if _core != null:
			_core.visible = false
		if _particles != null:
			_particles.emitting = false


func tear_down(free_self: bool = false) -> void:
	set_active(false)
	if free_self:
		queue_free()


func get_debug_status() -> Dictionary:
	return {
		"active": visible,
		"backplate_shader_ready": _backplate_material != null and WritheEmber.is_material_using_shader(_backplate_material),
		"arc_shader_ready": _arc_material != null and WritheEmber.is_material_using_shader(_arc_material),
		"core_blend_mix": _core != null and (_core.material == null),
		"particle_emitting": _particles != null and _particles.emitting,
		"enraged": _last_enraged,
		"phase": _last_phase,
		"phase_envelope": _phase_envelope,
	}


func _apply_state() -> void:
	if _backplate == null:
		return
	# 유효한 위치가 없으면 화면 중앙(380,375) 기본값으로 튀지 않도록 숨긴다. 첫 프레임 /
	# 비활성 / pos-less 상태에서 오브가 화면 한가운데 잠깐 뜨는 것을 원천 차단.
	var pos_value: Variant = _state.get("pos", null)
	if not (pos_value is Vector2):
		set_active(false)
		return
	var pos: Vector2 = pos_value
	var render_scale: float = max(0.01, float(_state.get("render_scale", 1.0)))
	position = pos
	scale = Vector2(render_scale, render_scale)

	var base_radius: float = max(1.0, float(_state.get("radius", 40.0)))
	var pop_amount: float = max(0.0, _phase_envelope - 1.0)
	var radius: float = base_radius * (1.0 + pop_amount * 0.08)
	var intensity: float = clamp(float(_state.get("intensity", 1.0)) * _phase_envelope, 0.0, 1.35)
	var alpha_intensity: float = clamp(intensity, 0.0, 1.0)
	var enraged: bool = bool(_state.get("enraged", false))
	var quality_scale: float = clamp(float(_state.get("quality_scale", 1.0)), 0.0, 1.0)

	if enraged != _last_enraged:
		_last_enraged = enraged
		WritheEmber.apply_preset(_backplate_material, "smasher_plasma_orb_enraged" if enraged else "smasher_plasma_orb")
		WritheEmber.apply_preset(_arc_material, "smasher_plasma_arc_enraged" if enraged else "smasher_plasma_arc")

	var quality_alpha: float = 0.55 + 0.45 * quality_scale
	# 오브 전체가 불안정하게 흔들리며 나아가도록 하는 위블(자식 레이어에만 — 호스트
	# position은 pos 유지, 좌표 씰 보존). 모든 레이어에 같은 오프셋을 줘 한 덩어리로 떤다.
	var wobble: Vector2 = _orb_wobble(base_radius, alpha_intensity)

	# backplate (분위기·깊이, ADD)
	_size_sprite(_backplate, _get_backplate_texture(), radius * BACKPLATE_DIAM_MULT)
	_backplate.position = wobble
	_backplate.modulate = Color(1.0, 1.0, 1.0, clamp((0.42 + 0.42 * alpha_intensity) * quality_alpha, 0.0, 1.0))
	_backplate.visible = true
	if _backplate_material != null:
		_backplate_material.set_shader_parameter("elapsed", elapsed_sec)
		_backplate_material.set_shader_parameter("intensity", 0.85 + 0.5 * intensity)

	# arc (율동 필라멘트, ADD) — 회전 + intensity로 알파/속도
	_size_sprite(_arc, _get_arc_texture(), radius * ARC_DIAM_MULT)
	_arc.position = wobble
	_arc.rotation = elapsed_sec * ARC_SPIN_SPEED * (1.0 + intensity * 0.6)
	_arc.modulate = Color(1.0, 1.0, 1.0, clamp((0.30 + 0.55 * alpha_intensity) * quality_alpha, 0.0, 1.0))
	_arc.visible = true
	if _arc_material != null:
		_arc_material.set_shader_parameter("elapsed", elapsed_sec)
		_arc_material.set_shader_parameter("intensity", 0.8 + 0.6 * intensity)

	# core (실체, MIX) — 밝은 전기 뉴클리어스. 정지 이미지로 보이지 않게 저속 반대회전 +
	# 스케일 맥동으로 살린다(backplate는 셰이더로 churn하지만 코어는 MIX라 셰이더 없음).
	var core_breath: float = 1.0 + 0.12 * sin(elapsed_sec * 5.0)
	_size_sprite(_core, _get_backplate_texture(), radius * CORE_DIAM_MULT * core_breath)
	_core.position = wobble
	_core.rotation = elapsed_sec * CORE_SPIN_SPEED
	var core_pulse: float = 0.85 + 0.15 * sin(elapsed_sec * 7.0)
	var core_tint: float = 0.7 + 0.3 * alpha_intensity
	_core.modulate = Color(core_tint, 0.92, 1.0, clamp((0.55 + 0.4 * alpha_intensity) * core_pulse, 0.0, 1.0))
	_core.visible = true

	# particles (에너지 모트, ADD) — 오브 반경에서 방출, LOD 게이트
	if _particles != null:
		_particles.position = wobble
		var allow: bool = quality_scale >= PARTICLE_QUALITY_GATE and alpha_intensity > 0.05
		_particles.emitting = allow
		var process_mat: ParticleProcessMaterial = _particles.process_material
		if process_mat != null:
			process_mat.emission_ring_radius = radius * 0.95
			process_mat.emission_ring_inner_radius = radius * 0.55
			var mote := Color(0.55 + 0.35 * alpha_intensity, 0.86, 1.0, clamp(0.5 + 0.4 * alpha_intensity, 0.0, 1.0))
			if enraged:
				mote = Color(0.8, 0.95, 1.0, clamp(0.65 + 0.3 * alpha_intensity, 0.0, 1.0))
			process_mat.color = mote


# 오브 위블 오프셋(호스트-로컬 px = playfield 단위; 호스트 scale=render_scale가 스크린으로
# 변환). 저주파 위빙 + 고주파 감전 떨림을 섞고 진폭은 반경*세기 비례.
func _orb_wobble(radius: float, intensity: float) -> Vector2:
	var t: float = elapsed_sec
	var amp: float = radius * WOBBLE_AMP_MULT * (0.35 + 0.65 * clamp(intensity, 0.0, 1.0))
	var wx: float = (
		sin(t * WOBBLE_FREQ_1) * 0.50
		+ sin(t * WOBBLE_FREQ_2 + 1.3) * 0.32
		+ sin(t * WOBBLE_FREQ_3 + 2.1) * 0.20
	)
	var wy: float = (
		cos(t * WOBBLE_FREQ_1 * 0.87 + 0.6) * 0.46
		+ cos(t * WOBBLE_FREQ_2 * 1.07 + 2.4) * 0.30
		+ sin(t * WOBBLE_FREQ_3 * 0.93 + 0.9) * 0.20
	)
	return Vector2(wx, wy) * amp


func _sync_phase_envelope(next_phase: String) -> void:
	if next_phase != "wave" or _last_phase == "wave":
		if next_phase != "wave":
			_kill_pop_tween()
			_phase_envelope = 1.0
		return
	if not is_inside_tree():
		_phase_envelope = 1.0
		return
	_kill_pop_tween()
	_phase_envelope = WAVE_POP_SCALE
	_pop_tween = create_tween()
	_pop_tween.tween_method(
		Callable(self, "_set_phase_envelope"),
		WAVE_POP_SCALE,
		1.0,
		WAVE_POP_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_phase_envelope(value: float) -> void:
	_phase_envelope = max(1.0, value)
	if visible:
		_apply_state()


func _kill_pop_tween() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	_pop_tween = null


func _build_children() -> void:
	if _additive_material == null:
		_additive_material = _make_additive_material()

	if _backplate == null:
		_backplate = Sprite2D.new()
		_backplate.name = "PlasmaBackplate"
		_backplate.centered = true
		_backplate.texture = _get_backplate_texture()
		_backplate.material = WritheEmber.build_material("smasher_plasma_orb")
		_backplate.visible = false
		_backplate.z_index = 0
		add_child(_backplate)
		_backplate_material = _backplate.material as ShaderMaterial

	if _arc == null:
		_arc = Sprite2D.new()
		_arc.name = "PlasmaArc"
		_arc.centered = true
		_arc.texture = _get_arc_texture()
		_arc.material = WritheEmber.build_material("smasher_plasma_arc")
		_arc.visible = false
		_arc.z_index = 1
		add_child(_arc)
		_arc_material = _arc.material as ShaderMaterial

	if _core == null:
		_core = Sprite2D.new()
		_core.name = "PlasmaCore"
		_core.centered = true
		_core.texture = _get_backplate_texture()
		# material=null -> 기본 MIX 블렌드 (실체 구체)
		_core.visible = false
		_core.z_index = 2
		add_child(_core)

	if _particles == null:
		_particles = GPUParticles2D.new()
		_particles.name = "PlasmaParticles"
		_particles.amount = PARTICLE_AMOUNT
		_particles.lifetime = 0.6
		_particles.one_shot = false
		_particles.explosiveness = 0.0
		_particles.randomness = 0.9
		_particles.fixed_fps = PARTICLE_FIXED_FPS
		_particles.local_coords = true
		_particles.visibility_rect = Rect2(-220.0, -220.0, 440.0, 440.0)
		_particles.texture = _get_particle_texture()
		_particles.material = _additive_material
		_particles.process_material = _build_particle_process_material()
		_particles.emitting = false
		_particles.z_index = 3
		add_child(_particles)


func _size_sprite(sprite: Sprite2D, texture: Texture2D, target_diameter: float) -> void:
	if sprite == null or texture == null:
		return
	if sprite.texture != texture:
		sprite.texture = texture
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	sprite.scale = Vector2(target_diameter / tex_size.x, target_diameter / tex_size.y)


func _make_additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


static func _build_particle_process_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 22.0
	mat.radial_accel_min = -120.0
	mat.radial_accel_max = -40.0
	mat.tangential_accel_min = -90.0
	mat.tangential_accel_max = 90.0
	mat.damping_min = 10.0
	mat.damping_max = 30.0
	mat.scale_min = 0.06
	mat.scale_max = 0.16
	mat.color = Color(0.6, 0.86, 1.0, 0.7)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	mat.emission_ring_radius = 40.0
	mat.emission_ring_inner_radius = 24.0
	mat.emission_ring_height = 0.0
	return mat


static func _get_backplate_texture() -> Texture2D:
	if _backplate_texture == null:
		_backplate_texture = ProjectResourceLoader.load_texture(BACKPLATE_PATH, "plasma backplate texture missing", "plasma backplate texture load failed")
	return _backplate_texture


static func _get_arc_texture() -> Texture2D:
	if _arc_texture == null:
		_arc_texture = ProjectResourceLoader.load_texture(ARC_PATH, "plasma arc texture missing", "plasma arc texture load failed")
	return _arc_texture


static func _get_particle_texture() -> Texture2D:
	if _particle_texture == null:
		_particle_texture = ProjectResourceLoader.load_texture(PARTICLE_PATH, "plasma particle texture missing", "plasma particle texture load failed")
	return _particle_texture


static func reset_textures_for_test() -> void:
	_backplate_texture = null
	_arc_texture = null
	_particle_texture = null
	_prewarmed = false


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
