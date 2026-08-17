extends Node2D

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const AngelLocalization := preload("res://scripts/characters/runtime_perk_angel_blessing_localization.gd")

const SELF_PATH := "res://scripts/hud/angel_blessing_roll_overlay_host.gd"
const HOST_NAME := "AngelBlessingRollOverlayHost"
const GAME_SIZE := Vector2(760.0, 750.0)
const FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const ICON_PATH := "res://assets/sprites/perks/angel_blessing_perk_icon.png"
const ICON_SHEET_PATH := "res://assets/sprites/perks/angel_blessing_perk_icon_sheet.png"
const LIGHTBURST_PATH := "res://assets/sprites/hud/mythic_reveal_lightburst_v1.png"
const SMOKE_PATH := "res://assets/sprites/hud/mythic_reveal_smoke_v1.png"
# 환격전 천운삼괘 연출은 새 괘문 아이콘을 정체성 앵커로 삼고, 한지 괘패·오방색
# 기운·전용 천문 셰이더·파티클을 같은 modal_elapsed 시계로 합성한다. 기존 천사
# 날개/후광/주사위 에셋은 로드하지 않는다. angel_blessing 내부 ID만 호환성으로 유지.
const MOTE_PATH := "res://assets/ui/character_select_vfx/character_select_particle_mote.png"
const HALO_SHADER_PATH := "res://shaders/angel_blessing_halo.gdshader"
const STYLE_FAMILY := "hwangyeokjeon_divination"
const MODAL_PANEL := Rect2(130.0, 108.0, 500.0, 520.0)
const OMEN_CENTER := Vector2(380.0, 302.0)
const OMEN_SEAL_SIZE := 196.0
const OMEN_AURA_SIZE := 280.0
const OMEN_SHEET_FRAMES := 8
const AMBIENT_PARTICLE_AMOUNT := 34
const ABSORB_PARTICLE_AMOUNT := 22
const OMEN_BURST_PARTICLE_AMOUNT := 26
const ABSORB_TRAIL_STEPS := 8
const OBANG_COLORS := [
	Color(0.20, 0.52, 0.56),
	Color(0.72, 0.16, 0.12),
	Color(0.82, 0.61, 0.20),
	Color(0.89, 0.84, 0.72),
	Color(0.12, 0.15, 0.17),
]
const TRIGRAM_PATTERNS := [
	[1, 1, 1],
	[0, 1, 0],
	[1, 0, 0],
]

static var _icon_texture: Texture2D = null
static var _icon_sheet_texture: Texture2D = null
static var _lightburst_texture: Texture2D = null
static var _smoke_texture: Texture2D = null
static var _mote_texture: Texture2D = null
static var _halo_shader: Shader = null
static var _prewarmed := false
static var _prewarm_step_index := 0
static var _active_hosts: Array = []


class OverlayDrawBridge:
	extends Control

	var host: Object = null

	func _draw() -> void:
		if host != null and host.has_method("_draw_overlay"):
			host._draw_overlay(self)


var _playfield_clip: Control = null
var _halo_layer: ColorRect = null
var _omen_aura_layer: Sprite2D = null
var _omen_aura_base_scale := 1.0
var _lightburst_layer: TextureRect = null
var _smoke_layer: TextureRect = null
var _ambient_particles: GPUParticles2D = null
var _omen_burst_particles: GPUParticles2D = null
var _absorb_particles: GPUParticles2D = null
var _draw_bridge: Control = null
var _halo_material: ShaderMaterial = null
var _snapshot: Dictionary = {}
var _player_pos := Vector2(380.0, 690.0)
var _active := false
var _was_modal_active := false
var _was_absorbing := false
var _was_divining := false


func _init() -> void:
	set_process(false)
	visible = false
	z_as_relative = false
	z_index = 3050


static func prewarm_assets() -> void:
	if _prewarmed:
		return
	_icon_texture = _load_texture(ICON_PATH, "Three Heavenly Omens seal")
	_icon_sheet_texture = _load_texture(ICON_SHEET_PATH, "Three Heavenly Omens animated seal")
	_lightburst_texture = _load_texture(LIGHTBURST_PATH, "Three Heavenly Omens lightburst")
	_smoke_texture = _load_texture(SMOKE_PATH, "Three Heavenly Omens ink smoke")
	_mote_texture = _load_texture(MOTE_PATH, "Three Heavenly Omens mote")
	_halo_shader = load(HALO_SHADER_PATH) as Shader
	_prewarmed = true


static func prewarm_assets_step() -> bool:
	if _prewarmed:
		return true
	var texture_paths := [ICON_PATH, ICON_SHEET_PATH, LIGHTBURST_PATH, SMOKE_PATH, MOTE_PATH]
	if _prewarm_step_index < texture_paths.size():
		var result := ProjectResourceLoader.prewarm_texture_threaded_step(str(texture_paths[_prewarm_step_index]))
		if not bool(result.get("done", false)):
			return false
		var texture := result.get("texture", null) as Texture2D
		match _prewarm_step_index:
			0: _icon_texture = texture
			1: _icon_sheet_texture = texture
			2: _lightburst_texture = texture
			3: _smoke_texture = texture
			4: _mote_texture = texture
		_prewarm_step_index += 1
		return false
	_halo_shader = load(HALO_SHADER_PATH) as Shader
	_prewarmed = true
	_prewarm_step_index = 0
	return true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"icon_ready": _icon_texture != null,
		"omen_identity_ready": _icon_texture != null and _icon_sheet_texture != null,
		"style_family": STYLE_FAMILY,
		"legacy_dice_assets_required": false,
		"texture_layers_ready": _lightburst_texture != null and _smoke_texture != null,
		"omen_aura_ready": _lightburst_texture != null,
		"particle_texture_ready": _mote_texture != null,
		"shader_ready": _halo_shader != null,
		"texture_layer_count": 4,
		"shader_layer_count": 1,
		"gpu_particle_layer_count": 3,
		"game_size": GAME_SIZE,
	}


static func hide_all_existing_hosts() -> void:
	var next_hosts: Array = []
	for host_ref: Variant in _active_hosts:
		var host: Node = _resolve_host_ref(host_ref)
		if host == null or not is_instance_valid(host) or host.is_queued_for_deletion():
			continue
		if host.has_method("set_active"):
			host.set_active(false)
		next_hosts.append(host_ref)
	_active_hosts = next_hosts


static func _remember_host(host: Node) -> void:
	if host == null:
		return
	for host_ref: Variant in _active_hosts:
		if _resolve_host_ref(host_ref) == host:
			return
	_active_hosts.append(weakref(host))


static func _resolve_host_ref(value: Variant) -> Node:
	if value is WeakRef:
		return (value as WeakRef).get_ref() as Node
	return value as Node if value is Node else null


static func _load_texture(path: String, label: String) -> Texture2D:
	return ProjectResourceLoader.load_texture(
		path,
		"Missing %s texture at %%s" % label,
		"Failed to load %s texture at %%s" % label
	)


func prepare() -> void:
	prewarm_assets()
	_build_children()
	_remember_host(self)


func sync_state(
	next_snapshot: Dictionary,
	next_player_pos: Vector2,
	layout: Dictionary
) -> void:
	prepare()
	_snapshot = next_snapshot.duplicate(true)
	_player_pos = Vector2(
		clampf(next_player_pos.x, 24.0, GAME_SIZE.x - 24.0),
		clampf(next_player_pos.y, 24.0, GAME_SIZE.y - 24.0)
	)
	position = _as_vector2(layout.get("game_offset", Vector2.ZERO))
	var render_scale := maxf(0.001, float(layout.get("render_scale", 1.0)))
	scale = Vector2(render_scale, render_scale)
	var modal_active := bool(_snapshot.get("modal_active", false))
	var absorption: Dictionary = _as_dictionary(_snapshot.get("absorption", {}))
	var absorbing := bool(absorption.get("active", false))
	if not modal_active and not absorbing:
		set_active(false)
		return
	_active = true
	visible = true
	_sync_layers(modal_active, absorbing, absorption)
	_was_modal_active = modal_active
	_was_absorbing = absorbing
	if _draw_bridge != null:
		_draw_bridge.queue_redraw()


func set_active(next_active: bool) -> void:
	if _active == next_active and visible == next_active:
		return
	_active = next_active
	visible = next_active
	if next_active:
		return
	_snapshot.clear()
	_was_modal_active = false
	_was_absorbing = false
	_was_divining = false
	if _ambient_particles != null:
		_ambient_particles.emitting = false
	if _omen_burst_particles != null:
		_omen_burst_particles.emitting = false
	if _absorb_particles != null:
		_absorb_particles.emitting = false
	if _halo_layer != null:
		_halo_layer.visible = false
	if _omen_aura_layer != null:
		_omen_aura_layer.visible = false
	if _lightburst_layer != null:
		_lightburst_layer.visible = false
	if _smoke_layer != null:
		_smoke_layer.visible = false
	if _draw_bridge != null:
		_draw_bridge.queue_redraw()


func tear_down(free_host: bool = false) -> void:
	set_active(false)
	if free_host:
		queue_free()


func get_debug_status() -> Dictionary:
	return {
		"active": _active and visible,
		"process_enabled": is_processing(),
		"playfield_clip_active": (
			_playfield_clip != null
			and _playfield_clip.clip_contents
			and _playfield_clip.clip_children == CanvasItem.CLIP_CHILDREN_AND_DRAW
			and _playfield_clip.position == Vector2.ZERO
			and _playfield_clip.size == GAME_SIZE
		),
		"draw_bridge_inside_clip": (
			_draw_bridge != null
			and _playfield_clip != null
			and _draw_bridge.get_parent() == _playfield_clip
			and _draw_bridge.size == GAME_SIZE
		),
		"particle_layers_inside_clip": (
			_ambient_particles != null
			and _absorb_particles != null
			and _omen_burst_particles != null
			and _ambient_particles.get_parent() == _playfield_clip
			and _absorb_particles.get_parent() == _playfield_clip
			and _omen_burst_particles.get_parent() == _playfield_clip
		),
		"ambient_emitting": _ambient_particles != null and _ambient_particles.emitting,
		"absorb_emitting": _absorb_particles != null and _absorb_particles.emitting,
		"style_family": STYLE_FAMILY,
		"omen_aura_visible": _omen_aura_layer != null and _omen_aura_layer.visible,
		"omen_aura_rotation": _omen_aura_layer.rotation if _omen_aura_layer != null else 0.0,
		"omen_aura_span_px": _omen_aura_on_screen_span(),
		"omen_aura_above_bridge": (
			_omen_aura_layer != null
			and _draw_bridge != null
			and _omen_aura_layer.get_index() > _draw_bridge.get_index()
		),
		"omen_burst_emitting": _omen_burst_particles != null and _omen_burst_particles.emitting,
		"game_offset": position,
		"render_scale": scale.x,
		"phase": get_phase_name(),
	}


func get_phase_name() -> String:
	if not bool(_snapshot.get("modal_active", false)):
		return "absorb" if bool(_as_dictionary(_snapshot.get("absorption", {})).get("active", false)) else "idle"
	var elapsed := float(_snapshot.get("modal_elapsed", 0.0))
	if elapsed < 0.60:
		return "unseal"
	if elapsed < 2.25:
		return "divination"
	if elapsed < 2.70:
		return "settle"
	if elapsed < 3.0:
		return "reveal"
	return "wait_confirm"


func _sync_layers(modal_active: bool, absorbing: bool, absorption: Dictionary) -> void:
	var elapsed := float(_snapshot.get("modal_elapsed", 0.0)) if modal_active else float(absorption.get("elapsed", 0.0))
	var intensity := 0.94 if modal_active else 0.72
	if modal_active:
		intensity *= clampf(elapsed / 0.34, 0.0, 1.0)
	if _halo_material != null:
		_halo_material.set_shader_parameter("elapsed", elapsed)
		_halo_material.set_shader_parameter("intensity", intensity)
		_halo_material.set_shader_parameter(
			"center_uv",
			Vector2(0.5, 0.43) if modal_active else _player_pos / GAME_SIZE
		)
	_halo_layer.visible = true
	_lightburst_layer.visible = modal_active
	_smoke_layer.visible = modal_active
	var pulse := 0.72 + 0.10 * sin(elapsed * 3.4)
	_lightburst_layer.modulate = Color(0.96, 0.73, 0.30, pulse * intensity)
	_smoke_layer.modulate = Color(0.24, 0.58, 0.54, (0.16 + 0.06 * sin(elapsed * 2.1)) * intensity)
	_sync_omen_layers(modal_active, elapsed)
	_ambient_particles.emitting = modal_active
	if absorbing:
		_absorb_particles.position = _player_pos
	if absorbing and not _was_absorbing:
		_absorb_particles.restart()
		_absorb_particles.emitting = true
	elif not absorbing:
		_absorb_particles.emitting = false


func _sync_omen_layers(modal_active: bool, elapsed: float) -> void:
	if _omen_aura_layer == null:
		return
	if not modal_active:
		_omen_aura_layer.visible = false
		if _omen_burst_particles != null:
			_omen_burst_particles.emitting = false
		_was_divining = false
		return
	# 괘문 인장·오방색 기운·결과 공개는 모두 modal_elapsed에서 파생한다. 모달이
	# 물리를 막는 동안에도 시계가 어긋나지 않고 PSO 프리워머에서도 결정적이다.
	var envelope := _omen_envelope(elapsed)
	var divining := elapsed >= 0.60 and elapsed < 2.25
	_omen_aura_layer.visible = envelope > 0.01
	_omen_aura_layer.rotation = _omen_aura_rotation(elapsed)
	var settle_pop := 1.0 + 0.12 * _settle_pop(elapsed)
	_omen_aura_layer.scale = Vector2.ONE * (_omen_aura_base_scale * settle_pop)
	_omen_aura_layer.modulate = Color(0.95, 0.73, 0.30, 0.34 * envelope)
	if _omen_burst_particles != null:
		if divining and not _was_divining:
			_omen_burst_particles.restart()
			_omen_burst_particles.emitting = true
		elif not divining and _was_divining and elapsed >= 2.25:
			# 괘패가 중심으로 모이는 순간 한 번 더 터뜨려 결과 공개를 연결한다.
			_omen_burst_particles.restart()
			_omen_burst_particles.emitting = true
	_was_divining = divining


func _omen_envelope(elapsed: float) -> float:
	# 봉인 해제 램프인 -> 괘독 풀 -> settle 감쇠 -> reveal/wait 호흡 유지.
	if elapsed < 0.60:
		return clampf(elapsed / 0.60, 0.0, 1.0) * 0.85
	if elapsed < 2.25:
		return 1.0
	if elapsed < 2.70:
		return lerpf(1.0, 0.66, (elapsed - 2.25) / 0.45)
	# settle 끝값 0.66에서 연속으로 이어받아 호흡한다. 위상을 (elapsed-2.70)로
	# 맞춰 경계에서 sin=0 -> 정확히 0.66에서 출발하므로 순간 침침해지는 불연속
	# (2.70에서 0.66->0.52 스텝)이 없다.
	return 0.66 + 0.05 * sin((elapsed - 2.70) * 1.6)


func _omen_aura_rotation(elapsed: float) -> float:
	# 점괘를 읽는 동안 천문이 천천히 회전하고, 결과 공개 뒤에는 거의 정지한다.
	if elapsed < 0.60:
		return -elapsed * 0.22
	if elapsed < 2.25:
		return -0.132 - (elapsed - 0.60) * 0.62
	var settle_base := -0.132 - 1.65 * 0.62
	if elapsed < 2.70:
		var settle_t := (elapsed - 2.25) / 0.45
		return settle_base - (1.0 - (1.0 - settle_t) * (1.0 - settle_t)) * 0.12
	return settle_base - 0.12 - (elapsed - 2.70) * 0.025


func _settle_pop(elapsed: float) -> float:
	if elapsed < 2.25 or elapsed >= 2.70:
		return 0.0
	var t := (elapsed - 2.25) / 0.45
	return (1.0 - t) * (1.0 - t)


func _build_children() -> void:
	if _playfield_clip != null:
		return
	_playfield_clip = Control.new()
	_playfield_clip.name = "AngelBlessingPlayfieldClip"
	_playfield_clip.position = Vector2.ZERO
	_playfield_clip.size = GAME_SIZE
	_playfield_clip.clip_contents = true
	_playfield_clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_playfield_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_playfield_clip)

	_halo_layer = ColorRect.new()
	_halo_layer.name = "AngelBlessingHaloShaderLayer"
	_halo_layer.position = Vector2.ZERO
	_halo_layer.size = GAME_SIZE
	_halo_layer.color = Color.WHITE
	_halo_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo_material = ShaderMaterial.new()
	_halo_material.shader = _halo_shader
	_halo_layer.material = _halo_material
	_playfield_clip.add_child(_halo_layer)

	_lightburst_layer = _build_texture_layer("AngelBlessingLightburstLayer", _lightburst_texture, Vector2(520.0, 520.0), Vector2(120.0, 70.0))
	_smoke_layer = _build_texture_layer("AngelBlessingSmokeLayer", _smoke_texture, Vector2(620.0, 560.0), Vector2(70.0, 58.0))
	_playfield_clip.add_child(_lightburst_layer)
	_playfield_clip.add_child(_smoke_layer)

	_ambient_particles = _build_particles("AngelBlessingAmbientParticles", AMBIENT_PARTICLE_AMOUNT, false)
	_ambient_particles.position = Vector2(380.0, 330.0)
	_playfield_clip.add_child(_ambient_particles)
	_absorb_particles = _build_particles("AngelBlessingAbsorbParticles", ABSORB_PARTICLE_AMOUNT, true)
	_playfield_clip.add_child(_absorb_particles)

	var bridge := OverlayDrawBridge.new()
	bridge.name = "AngelBlessingOverlayDrawBridge"
	bridge.host = self
	bridge.position = Vector2.ZERO
	bridge.size = GAME_SIZE
	bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playfield_clip.add_child(bridge)
	_draw_bridge = bridge

	# 환격전식 의식 광륜은 브리지(패널·괘문·텍스트) 위에 낮은 알파 ADD로 얹는다.
	# 거의 불투명한 패널 아래에 두면 묻히므로 반드시 브리지 다음 형제여야 한다.
	_omen_aura_layer = _build_centered_sprite("AngelBlessingOmenAuraLayer", _lightburst_texture, OMEN_AURA_SIZE)
	var aura_additive := CanvasItemMaterial.new()
	aura_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_omen_aura_layer.material = aura_additive
	_playfield_clip.add_child(_omen_aura_layer)
	_omen_burst_particles = _build_particles("AngelBlessingOmenBurstParticles", OMEN_BURST_PARTICLE_AMOUNT, true)
	_omen_burst_particles.position = OMEN_CENTER
	_playfield_clip.add_child(_omen_burst_particles)
	set_active(false)


# 의식 광륜의 실제 화면 폭(px). TextureRect min_size 함정을 피했는지 실측한다.
func _omen_aura_on_screen_span() -> float:
	if _omen_aura_layer == null or _omen_aura_layer.texture == null:
		return 0.0
	var tex_span := float(maxi(_omen_aura_layer.texture.get_width(), _omen_aura_layer.texture.get_height()))
	return tex_span * absf(_omen_aura_layer.scale.x)


func _build_centered_sprite(name_value: String, texture: Texture2D, size_value: float) -> Sprite2D:
	# 회전·스케일 스프라이트에는 Sprite2D가 정석이다. TextureRect는
	# texture 지정으로 min_size가 원본(768)이 되면 이후 size 축소가 min_size로
	# 되돌려져 네이티브 크기로 렌더되는 레이아웃 함정이 있으므로 쓰지 않는다.
	# centered=true라 position=중심, rotation은 중심 회전, scale로 정확한 크기 제어.
	var sprite := Sprite2D.new()
	sprite.name = name_value
	sprite.texture = texture
	sprite.position = OMEN_CENTER
	sprite.centered = true
	var tex_span := maxf(1.0, float(maxi(texture.get_width(), texture.get_height())))
	_omen_aura_base_scale = size_value / tex_span
	sprite.scale = Vector2.ONE * _omen_aura_base_scale
	sprite.visible = false
	return sprite


func _build_texture_layer(name_value: String, texture: Texture2D, size_value: Vector2, position_value: Vector2) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = name_value
	layer.texture = texture
	layer.position = position_value
	layer.size = size_value
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	layer.material = additive
	return layer


func _build_particles(name_value: String, amount_value: int, one_shot_value: bool) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.name = name_value
	particles.amount = amount_value
	particles.lifetime = 1.8
	particles.one_shot = one_shot_value
	particles.randomness = 0.78
	particles.fixed_fps = 30
	particles.texture = _mote_texture
	particles.emitting = false
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = additive
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(250.0, 160.0, 1.0) if not one_shot_value else Vector3(42.0, 24.0, 1.0)
	process_material.direction = Vector3(0.0, -1.0, 0.0)
	process_material.spread = 46.0
	process_material.initial_velocity_min = 10.0
	process_material.initial_velocity_max = 34.0
	process_material.gravity = Vector3(0.0, -7.0, 0.0)
	process_material.scale_min = 0.12
	process_material.scale_max = 0.38
	process_material.color = Color(1.0, 0.82, 0.30, 0.76)
	particles.process_material = process_material
	return particles


func _draw_overlay(canvas: CanvasItem) -> void:
	if not _active or canvas == null:
		return
	if bool(_snapshot.get("modal_active", false)):
		_draw_modal(canvas)
	var absorption: Dictionary = _as_dictionary(_snapshot.get("absorption", {}))
	if bool(absorption.get("active", false)):
		_draw_absorption(canvas, absorption)


func _draw_modal(canvas: CanvasItem) -> void:
	var elapsed := float(_snapshot.get("modal_elapsed", 0.0))
	var active_modal: Dictionary = _as_dictionary(_snapshot.get("active_modal", {}))
	var roll_result: Dictionary = _as_dictionary(active_modal.get("roll_result", {}))
	var buff_ids: Array[String] = _string_array(roll_result.get("active_buff_ids", []))
	var face := maxi(1, int(roll_result.get("roll_face", buff_ids.size())))
	canvas.draw_rect(Rect2(Vector2.ZERO, GAME_SIZE), Color(0.012, 0.022, 0.030, 0.80))
	_draw_modal_panel(canvas)
	_draw_text_centered(canvas, AngelLocalization.text("title"), Vector2(380.0, 145.0), 30, Color(0.96, 0.82, 0.48))

	# 환격전식 점괘: 한지 천문 위에 세 괘패가 공전하고, 중앙 괘문 인장이 8프레임
	# 호흡으로 점괘를 읽는다. 천사 날개·서양 마법진·주사위 토스는 사용하지 않는다.
	_draw_ritual_backplate(canvas, OMEN_CENTER, elapsed)
	_draw_ink_rays(canvas, OMEN_CENTER, elapsed)
	_draw_omen_seal(canvas, OMEN_CENTER, elapsed)
	_draw_omen_tokens(canvas, elapsed, face)
	_draw_ritual_accents(canvas, elapsed)

	if elapsed < 2.25:
		_draw_text_centered(canvas, AngelLocalization.text("rolling"), Vector2(380.0, 452.0), 17, Color(0.83, 0.81, 0.68))
		return
	_draw_text_centered(canvas, "%s  ·  %d" % [AngelLocalization.text("result"), face], Vector2(380.0, 436.0), 20, Color(0.96, 0.78, 0.34))
	_draw_result_cards(canvas, buff_ids, elapsed)
	if elapsed >= 3.0:
		var prompt_alpha := 0.62 + 0.38 * (0.5 + 0.5 * sin(elapsed * 4.8))
		_draw_text_centered(canvas, AngelLocalization.text("continue"), Vector2(380.0, 601.0), 16, Color(0.94, 0.87, 0.69, prompt_alpha))


func _draw_modal_panel(canvas: CanvasItem) -> void:
	canvas.draw_rect(MODAL_PANEL.grow(8.0), Color(0.0, 0.0, 0.0, 0.42))
	canvas.draw_rect(MODAL_PANEL, Color(0.045, 0.060, 0.065, 0.965))
	canvas.draw_rect(MODAL_PANEL, Color(0.72, 0.55, 0.25, 0.95), false, 3.0)
	canvas.draw_rect(MODAL_PANEL.grow(-8.0), Color(0.35, 0.43, 0.39, 0.78), false, 1.0)
	var band_x := MODAL_PANEL.position.x + 18.0
	var band_width := (MODAL_PANEL.size.x - 36.0) / float(OBANG_COLORS.size())
	for index: int in range(OBANG_COLORS.size()):
		var band_color: Color = OBANG_COLORS[index]
		band_color.a = 0.82
		canvas.draw_rect(Rect2(band_x + band_width * index, MODAL_PANEL.position.y + 8.0, band_width - 2.0, 3.0), band_color)
	_draw_corner_brackets(canvas, MODAL_PANEL.grow(-14.0))


func _draw_corner_brackets(canvas: CanvasItem, rect: Rect2) -> void:
	var length := 22.0
	var color := Color(0.84, 0.69, 0.36, 0.86)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var x_dir := 1.0 if is_equal_approx(corner.x, rect.position.x) else -1.0
		var y_dir := 1.0 if is_equal_approx(corner.y, rect.position.y) else -1.0
		canvas.draw_line(corner, corner + Vector2(length * x_dir, 0.0), color, 2.0)
		canvas.draw_line(corner, corner + Vector2(0.0, length * y_dir), color, 2.0)


func _draw_ritual_backplate(canvas: CanvasItem, center: Vector2, elapsed: float) -> void:
	var envelope := _omen_envelope(elapsed)
	if envelope <= 0.01:
		return
	var intro := clampf(elapsed / 0.60, 0.0, 1.0)
	var breath := 1.0 + 0.018 * sin(elapsed * 1.7)
	var scale_value := (0.76 + 0.24 * _ease_out_back(intro)) * breath
	canvas.draw_set_transform(center, -elapsed * 0.055, Vector2.ONE * scale_value)
	canvas.draw_circle(Vector2.ZERO, 140.0, Color(0.78, 0.69, 0.50, 0.085 * envelope))
	canvas.draw_arc(Vector2.ZERO, 138.0, 0.0, TAU, 72, Color(0.74, 0.58, 0.28, 0.72 * envelope), 2.2)
	canvas.draw_arc(Vector2.ZERO, 126.0, 0.0, TAU, 72, Color(0.28, 0.54, 0.52, 0.46 * envelope), 1.4)
	canvas.draw_arc(Vector2.ZERO, 105.0, 0.0, TAU, 64, Color(0.72, 0.18, 0.12, 0.40 * envelope), 1.5)
	for index: int in range(8):
		var angle := TAU * float(index) / 8.0
		var inner := Vector2.from_angle(angle) * 126.0
		var outer := Vector2.from_angle(angle) * 138.0
		canvas.draw_line(inner, outer, Color(0.88, 0.76, 0.48, 0.58 * envelope), 2.0)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_omen_seal(canvas: CanvasItem, center: Vector2, elapsed: float) -> void:
	var intro := clampf(elapsed / 0.60, 0.0, 1.0)
	var scale_value := 0.70 + 0.30 * _ease_out_back(intro)
	var breath := 1.0 + 0.025 * sin(elapsed * 2.2)
	var size_value := OMEN_SEAL_SIZE * scale_value * breath
	var rotation := 0.035 * sin(elapsed * 1.4)
	canvas.draw_circle(center, size_value * 0.52, Color(0.92, 0.82, 0.61, 0.11 * intro))
	canvas.draw_set_transform(center, rotation, Vector2.ONE)
	if _icon_sheet_texture != null:
		var frame_width := float(_icon_sheet_texture.get_width()) / float(OMEN_SHEET_FRAMES)
		var frame_height := float(_icon_sheet_texture.get_height())
		var frame := _omen_sheet_frame(elapsed)
		canvas.draw_texture_rect_region(
			_icon_sheet_texture,
			Rect2(Vector2.ONE * -size_value * 0.5, Vector2.ONE * size_value),
			Rect2(frame_width * float(frame), 0.0, frame_width, frame_height),
			Color(1.0, 0.98, 0.90, 0.98)
		)
	elif _icon_texture != null:
		canvas.draw_texture_rect(_icon_texture, Rect2(Vector2.ONE * -size_value * 0.5, Vector2.ONE * size_value), false)
	else:
		_draw_omen_fallback(canvas, Vector2.ZERO, size_value)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _omen_sheet_frame(elapsed: float) -> int:
	if elapsed < 0.60:
		return mini(2, int(floorf(clampf(elapsed / 0.60, 0.0, 0.999) * 3.0)))
	if elapsed < 2.25:
		return int(floorf((elapsed - 0.60) * 8.5)) % OMEN_SHEET_FRAMES
	if elapsed < 2.70:
		return mini(OMEN_SHEET_FRAMES - 1, int(floorf((elapsed - 2.25) / 0.45 * float(OMEN_SHEET_FRAMES))))
	return OMEN_SHEET_FRAMES - 1


func _omen_token_position(elapsed: float, index: int) -> Vector2:
	var angle_base := elapsed * 1.15 + TAU * float(index) / 3.0 - PI * 0.5
	var radius := 114.0 + 4.0 * sin(elapsed * 2.3 + float(index))
	if elapsed < 0.60:
		var intro := clampf(elapsed / 0.60, 0.0, 1.0)
		radius = lerpf(154.0, 114.0, _ease_out_back(intro))
	elif elapsed >= 2.25:
		var settle := clampf((elapsed - 2.25) / 0.45, 0.0, 1.0)
		angle_base = 2.25 * 1.15 + TAU * float(index) / 3.0 - PI * 0.5
		angle_base += (1.0 - (1.0 - settle) * (1.0 - settle)) * 0.35
		radius = lerpf(114.0, 74.0, settle)
	return OMEN_CENTER + Vector2.from_angle(angle_base) * radius


func _draw_omen_tokens(canvas: CanvasItem, elapsed: float, face: int) -> void:
	var intro := clampf(elapsed / 0.60, 0.0, 1.0)
	for index: int in range(3):
		var pos := _omen_token_position(elapsed, index)
		var active := index < face
		var color: Color = OBANG_COLORS[index]
		var alpha := (0.92 if active else 0.42) * intro
		canvas.draw_line(OMEN_CENTER, pos, Color(color.r, color.g, color.b, 0.16 * intro), 1.4)
		canvas.draw_circle(pos + Vector2(2.0, 3.0), 23.0, Color(0.0, 0.0, 0.0, 0.30 * intro))
		canvas.draw_circle(pos, 21.0, Color(0.86, 0.80, 0.65, 0.92 * intro))
		canvas.draw_arc(pos, 21.0, 0.0, TAU, 28, Color(color.r, color.g, color.b, alpha), 3.0)
		_draw_trigram(canvas, pos, TRIGRAM_PATTERNS[index] as Array, Color(0.08, 0.11, 0.12, 0.90 * intro))


func _draw_trigram(canvas: CanvasItem, center: Vector2, pattern: Array, color: Color) -> void:
	for row: int in range(3):
		var y := center.y + (float(row) - 1.0) * 6.0
		if int(pattern[row]) == 1:
			canvas.draw_line(Vector2(center.x - 11.0, y), Vector2(center.x + 11.0, y), color, 3.0)
		else:
			canvas.draw_line(Vector2(center.x - 11.0, y), Vector2(center.x - 2.5, y), color, 3.0)
			canvas.draw_line(Vector2(center.x + 2.5, y), Vector2(center.x + 11.0, y), color, 3.0)


func _draw_omen_fallback(canvas: CanvasItem, center: Vector2, size_value: float) -> void:
	canvas.draw_circle(center, size_value * 0.5, Color(0.88, 0.82, 0.66, 0.96))
	canvas.draw_arc(center, size_value * 0.48, 0.0, TAU, 36, Color(0.62, 0.16, 0.12), 3.0)
	_draw_trigram(canvas, center, TRIGRAM_PATTERNS[0] as Array, Color(0.08, 0.11, 0.12))


func _draw_ink_rays(canvas: CanvasItem, center: Vector2, elapsed: float) -> void:
	var intro := clampf(elapsed / 0.60, 0.0, 1.0)
	for index: int in range(10):
		var angle := TAU * float(index) / 10.0 - elapsed * 0.10
		var inner := center + Vector2.from_angle(angle) * 101.0
		var outer := center + Vector2.from_angle(angle) * (132.0 + 7.0 * sin(elapsed * 2.2 + index))
		var color: Color = OBANG_COLORS[index % OBANG_COLORS.size()]
		canvas.draw_line(inner, outer, Color(color.r, color.g, color.b, 0.24 * intro), 2.2)


func _draw_ritual_accents(canvas: CanvasItem, elapsed: float) -> void:
	var intro := clampf(elapsed / 0.60, 0.0, 1.0)
	for side: int in [-1, 1]:
		var x := OMEN_CENTER.x + 166.0 * float(side)
		var knot_y := 242.0 + 4.0 * sin(elapsed * 1.8 + float(side))
		var cord_color := Color(0.67, 0.16, 0.12, 0.62 * intro) if side < 0 else Color(0.22, 0.52, 0.53, 0.62 * intro)
		canvas.draw_line(Vector2(x, 197.0), Vector2(x, knot_y), cord_color, 3.0)
		canvas.draw_circle(Vector2(x, knot_y), 6.0, Color(0.82, 0.66, 0.30, 0.82 * intro))
		canvas.draw_line(Vector2(x, knot_y + 6.0), Vector2(x - 8.0 * float(side), knot_y + 36.0), cord_color, 2.2)
		canvas.draw_line(Vector2(x, knot_y + 6.0), Vector2(x + 8.0 * float(side), knot_y + 36.0), cord_color, 2.2)


func _draw_result_cards(canvas: CanvasItem, buff_ids: Array[String], elapsed: float) -> void:
	if buff_ids.is_empty():
		return
	var card_width := 132.0
	var gap := 10.0
	var total_width := card_width * buff_ids.size() + gap * maxi(0, buff_ids.size() - 1)
	var start_x := 380.0 - total_width * 0.5
	var reveal := clampf((elapsed - 2.25) / 0.45, 0.0, 1.0)
	for index: int in range(buff_ids.size()):
		var rect := Rect2(start_x + float(index) * (card_width + gap), 472.0 + (1.0 - reveal) * 20.0, card_width, 82.0)
		var pulse := 0.5 + 0.5 * sin(elapsed * 4.2 + index * 0.8)
		var accent: Color = OBANG_COLORS[index % OBANG_COLORS.size()]
		canvas.draw_rect(Rect2(rect.position + Vector2(3.0, 4.0), rect.size), Color(0.0, 0.0, 0.0, 0.34 * reveal))
		canvas.draw_rect(rect, Color(0.88, 0.82, 0.68, 0.96 * reveal))
		canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5.0)), Color(accent.r, accent.g, accent.b, 0.90 * reveal))
		canvas.draw_rect(rect.grow(1.0 + pulse), Color(0.76, 0.59, 0.28, (0.52 + pulse * 0.22) * reveal), false, 2.0)
		_draw_text_centered(canvas, AngelLocalization.buff_label(buff_ids[index]), rect.get_center() + Vector2(0.0, -7.0), 13, Color(0.08, 0.11, 0.12, reveal))
		var sign := "+" if buff_ids[index] in ["paddle_size", "gauge_max", "move_speed"] else "-"
		_draw_text_centered(canvas, "%s30%%" % sign, rect.get_center() + Vector2(0.0, 20.0), 15, Color(0.62, 0.13, 0.10, reveal))
		canvas.draw_rect(Rect2(rect.end - Vector2(17.0, 17.0), Vector2(11.0, 11.0)), Color(0.67, 0.12, 0.09, 0.74 * reveal))


func _draw_absorption(canvas: CanvasItem, absorption: Dictionary) -> void:
	var elapsed := float(absorption.get("elapsed", 0.0))
	var trajectories_value: Variant = absorption.get("trajectories", [])
	var trajectories: Array = trajectories_value if trajectories_value is Array else []
	var spread_start := Vector2(380.0 - 30.0 * float(maxi(0, trajectories.size() - 1)), 335.0)
	for trajectory_value: Variant in trajectories:
		if not (trajectory_value is Dictionary):
			continue
		var trajectory: Dictionary = trajectory_value
		var index := int(trajectory.get("index", 0))
		var delay := float(trajectory.get("delay", 0.0))
		var duration := maxf(0.001, float(trajectory.get("travel_duration", 1.8)))
		var local_time := elapsed - delay
		var start := spread_start + Vector2(float(index) * 60.0, 0.0)
		var control := (start + _player_pos) * 0.5 + Vector2(0.0, -250.0 - 42.0 * float(index))
		if local_time >= 0.0 and local_time <= duration:
			var progress := clampf(local_time / duration, 0.0, 1.0)
			for trail_index: int in range(ABSORB_TRAIL_STEPS, 0, -1):
				var trail_t := maxf(0.0, progress - float(trail_index) * 0.028)
				var trail_pos := _quadratic_bezier(start, control, _player_pos, trail_t)
				var trail_alpha := (1.0 - float(trail_index) / float(ABSORB_TRAIL_STEPS + 1)) * 0.45
				var trail_color := _omen_energy_color(index)
				canvas.draw_circle(trail_pos, 3.0 + trail_alpha * 4.0, Color(trail_color.r, trail_color.g, trail_color.b, trail_alpha))
			var pos := _quadratic_bezier(start, control, _player_pos, progress)
			var energy_color := _omen_energy_color(index)
			canvas.draw_circle(pos, 14.0, Color(energy_color.r, energy_color.g, energy_color.b, 0.16))
			canvas.draw_circle(pos, 7.0, Color(energy_color.r, energy_color.g, energy_color.b, 0.76))
			canvas.draw_circle(pos, 3.0, Color(0.98, 0.91, 0.70, 1.0))
			_draw_diamond(canvas, pos, 9.0, Color(energy_color.r, energy_color.g, energy_color.b, 0.74))
		var arrival_time := float(trajectory.get("arrival_time", delay + duration))
		var glow_duration := maxf(0.001, float(absorption.get("glow_duration", 0.35)))
		if elapsed >= arrival_time and elapsed <= arrival_time + glow_duration:
			var glow_ratio := 1.0 - (elapsed - arrival_time) / glow_duration
			var arrival_color := _omen_energy_color(index)
			canvas.draw_circle(_player_pos, 58.0 * (1.0 + (1.0 - glow_ratio) * 0.28), Color(arrival_color.r, arrival_color.g, arrival_color.b, 0.20 * glow_ratio))
			canvas.draw_arc(_player_pos, 38.0, 0.0, TAU, 28, Color(arrival_color.r, arrival_color.g, arrival_color.b, 0.82 * glow_ratio), 3.0)
			canvas.draw_arc(_player_pos, 29.0, -PI * 0.75, PI * 0.15, 18, Color(0.94, 0.82, 0.48, 0.72 * glow_ratio), 2.0)


func _quadratic_bezier(start: Vector2, control: Vector2, target: Vector2, t: float) -> Vector2:
	var one_minus_t := 1.0 - t
	return one_minus_t * one_minus_t * start + 2.0 * one_minus_t * t * control + t * t * target


func _omen_energy_color(index: int) -> Color:
	return OBANG_COLORS[posmod(index, 3)] as Color


func _draw_diamond(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	]), color)


func _draw_text_centered(canvas: CanvasItem, text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	canvas.draw_string(FONT, center + Vector2(-text_size.x * 0.5 + 1.2, text_size.y * 0.32 + 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.68))
	canvas.draw_string(FONT, center + Vector2(-text_size.x * 0.5, text_size.y * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _ease_out_back(value: float) -> float:
	var x := clampf(value, 0.0, 1.0) - 1.0
	return 1.0 + 2.70158 * x * x * x + 1.70158 * x * x


func _as_dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _as_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for entry: Variant in value:
		var text := str(entry).strip_edges()
		if text != "" and text not in result:
			result.append(text)
	return result
