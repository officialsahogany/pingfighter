extends Node2D

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const AngelLocalization := preload("res://scripts/characters/runtime_perk_angel_blessing_localization.gd")
const WritheEmberMaterial := preload("res://scripts/effects/writhe_ember_material.gd")

const SELF_PATH := "res://scripts/hud/angel_blessing_roll_overlay_host.gd"
const HOST_NAME := "AngelBlessingRollOverlayHost"
const GAME_SIZE := Vector2(760.0, 750.0)
const FONT: Font = preload("res://assets/fonts/NanumSquareB.ttf")
const ICON_PATH := "res://assets/sprites/perks/angel_blessing_perk_icon.png"
const LIGHTBURST_PATH := "res://assets/sprites/hud/mythic_reveal_lightburst_v1.png"
const SMOKE_PATH := "res://assets/sprites/hud/mythic_reveal_smoke_v1.png"
# 주사위 연출 3-피스(정적 텍스처 + 엔진 모션): 백플레이트=실체(MIX),
# 호/트레일=빛(ADD, writhe-ember 셰이더), 모트=파티클(ADD, GPUParticles2D).
const DICE_BACKPLATE_PATH := "res://assets/sprites/hud/angel_dice_backplate_imagegen_v1.png"
const DICE_ARC_PATH := "res://assets/sprites/hud/angel_dice_arc_imagegen_v1.png"
const MOTE_PATH := "res://assets/sprites/hud/angel_dice_mote_imagegen_v1.png"
const HALO_SHADER_PATH := "res://shaders/angel_blessing_halo.gdshader"
const MODAL_PANEL := Rect2(130.0, 108.0, 500.0, 520.0)
const DICE_CENTER := Vector2(380.0, 302.0)
const DICE_BACKPLATE_SIZE := 344.0
const DICE_ARC_SIZE := 306.0
const AMBIENT_PARTICLE_AMOUNT := 34
const ABSORB_PARTICLE_AMOUNT := 22
const DICE_BURST_PARTICLE_AMOUNT := 26
const ABSORB_TRAIL_STEPS := 8

static var _icon_texture: Texture2D = null
static var _lightburst_texture: Texture2D = null
static var _smoke_texture: Texture2D = null
static var _dice_backplate_texture: Texture2D = null
static var _dice_arc_texture: Texture2D = null
static var _mote_texture: Texture2D = null
static var _halo_shader: Shader = null
static var _prewarmed := false
static var _active_hosts: Array = []


class OverlayDrawBridge:
	extends Control

	var host: Object = null

	func _draw() -> void:
		if host != null and host.has_method("_draw_overlay"):
			host._draw_overlay(self)


var _playfield_clip: Control = null
var _halo_layer: ColorRect = null
var _dice_arc_layer: TextureRect = null
var _lightburst_layer: TextureRect = null
var _smoke_layer: TextureRect = null
var _ambient_particles: GPUParticles2D = null
var _dice_burst_particles: GPUParticles2D = null
var _absorb_particles: GPUParticles2D = null
var _draw_bridge: Control = null
var _halo_material: ShaderMaterial = null
var _dice_arc_material: ShaderMaterial = null
var _dice_arc_preset := ""
var _snapshot: Dictionary = {}
var _player_pos := Vector2(380.0, 690.0)
var _active := false
var _was_modal_active := false
var _was_absorbing := false
var _was_rolling := false


func _init() -> void:
	set_process(false)
	visible = false
	z_as_relative = false
	z_index = 3050


static func prewarm_assets() -> void:
	if _prewarmed:
		return
	_icon_texture = _load_texture(ICON_PATH, "Angel blessing icon")
	_lightburst_texture = _load_texture(LIGHTBURST_PATH, "Angel blessing lightburst")
	_smoke_texture = _load_texture(SMOKE_PATH, "Angel blessing smoke")
	_dice_backplate_texture = _load_texture(DICE_BACKPLATE_PATH, "Angel dice backplate")
	_dice_arc_texture = _load_texture(DICE_ARC_PATH, "Angel dice arc")
	_mote_texture = _load_texture(MOTE_PATH, "Angel dice mote")
	_halo_shader = load(HALO_SHADER_PATH) as Shader
	WritheEmberMaterial.prewarm()
	_prewarmed = true


static func prewarm_assets_step() -> bool:
	prewarm_assets()
	return true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	return {
		"icon_ready": _icon_texture != null,
		"texture_layers_ready": _lightburst_texture != null and _smoke_texture != null,
		"dice_layers_ready": _dice_backplate_texture != null and _dice_arc_texture != null,
		"particle_texture_ready": _mote_texture != null,
		"shader_ready": _halo_shader != null,
		"dice_arc_shader_ready": WritheEmberMaterial.get_shader() != null
			and WritheEmberMaterial.has_preset("angel_dice_halo")
			and WritheEmberMaterial.has_preset("angel_dice_roll_surge"),
		"texture_layer_count": 5,
		"shader_layer_count": 2,
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
	_was_rolling = false
	if _ambient_particles != null:
		_ambient_particles.emitting = false
	if _dice_burst_particles != null:
		_dice_burst_particles.emitting = false
	if _absorb_particles != null:
		_absorb_particles.emitting = false
	if _halo_layer != null:
		_halo_layer.visible = false
	if _dice_arc_layer != null:
		_dice_arc_layer.visible = false
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
			and _dice_burst_particles != null
			and _ambient_particles.get_parent() == _playfield_clip
			and _absorb_particles.get_parent() == _playfield_clip
			and _dice_burst_particles.get_parent() == _playfield_clip
		),
		"ambient_emitting": _ambient_particles != null and _ambient_particles.emitting,
		"absorb_emitting": _absorb_particles != null and _absorb_particles.emitting,
		"dice_arc_visible": _dice_arc_layer != null and _dice_arc_layer.visible,
		"dice_arc_preset": _dice_arc_preset,
		"dice_arc_rotation": _dice_arc_layer.rotation if _dice_arc_layer != null else 0.0,
		"dice_arc_above_bridge": (
			_dice_arc_layer != null
			and _draw_bridge != null
			and _dice_arc_layer.get_index() > _draw_bridge.get_index()
		),
		"dice_arc_uses_writhe_shader": (
			_dice_arc_material != null
			and WritheEmberMaterial.is_material_using_shader(_dice_arc_material)
		),
		"dice_burst_emitting": _dice_burst_particles != null and _dice_burst_particles.emitting,
		"game_offset": position,
		"render_scale": scale.x,
		"phase": get_phase_name(),
	}


func get_phase_name() -> String:
	if not bool(_snapshot.get("modal_active", false)):
		return "absorb" if bool(_as_dictionary(_snapshot.get("absorption", {})).get("active", false)) else "idle"
	var elapsed := float(_snapshot.get("modal_elapsed", 0.0))
	if elapsed < 0.60:
		return "descent"
	if elapsed < 2.25:
		return "rolling"
	if elapsed < 2.70:
		return "settle"
	if elapsed < 3.0:
		return "highlight"
	return "wait_confirm"


func _sync_layers(modal_active: bool, absorbing: bool, absorption: Dictionary) -> void:
	var elapsed := float(_snapshot.get("modal_elapsed", 0.0)) if modal_active else float(absorption.get("elapsed", 0.0))
	var intensity := 1.0 if modal_active else 0.76
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
	var pulse := 0.78 + 0.12 * sin(elapsed * 3.4)
	_lightburst_layer.modulate = Color(1.0, 0.86, 0.38, pulse * intensity)
	_smoke_layer.modulate = Color(0.78, 0.52, 1.0, (0.22 + 0.08 * sin(elapsed * 2.1)) * intensity)
	_sync_dice_layers(modal_active, elapsed)
	_ambient_particles.emitting = modal_active
	if absorbing:
		_absorb_particles.position = _player_pos
	if absorbing and not _was_absorbing:
		_absorb_particles.restart()
		_absorb_particles.emitting = true
	elif not absorbing:
		_absorb_particles.emitting = false


func _sync_dice_layers(modal_active: bool, elapsed: float) -> void:
	if _dice_arc_layer == null:
		return
	if not modal_active:
		_dice_arc_layer.visible = false
		if _dice_burst_particles != null:
			_dice_burst_particles.emitting = false
		_was_rolling = false
		return
	# 개시/종료 envelope와 페이즈 intensity는 wall-clock Tween 대신 modal_elapsed
	# 파생 함수로 계산한다. 모달이 물리를 막는 동안에도 스냅샷 시계와 어긋나지
	# 않고, PSO 프리워머의 고정 elapsed 픽스처에서도 결정적으로 그려진다.
	var envelope := _dice_envelope(elapsed)
	var rolling := elapsed >= 0.60 and elapsed < 2.25
	_dice_arc_layer.visible = envelope > 0.01
	_dice_arc_layer.rotation = _dice_arc_rotation(elapsed)
	var settle_pop := 1.0 + 0.12 * _settle_pop(elapsed)
	_dice_arc_layer.scale = Vector2.ONE * settle_pop
	_dice_arc_layer.modulate = Color(1.0, 1.0, 1.0, envelope)
	var next_preset := "angel_dice_roll_surge" if rolling else "angel_dice_halo"
	if _dice_arc_material != null:
		if next_preset != _dice_arc_preset:
			WritheEmberMaterial.apply_preset(_dice_arc_material, next_preset)
			_dice_arc_preset = next_preset
		_dice_arc_material.set_shader_parameter("elapsed", elapsed)
		_dice_arc_material.set_shader_parameter("intensity", envelope)
	if _dice_burst_particles != null:
		if rolling and not _was_rolling:
			_dice_burst_particles.restart()
			_dice_burst_particles.emitting = true
		elif not rolling and _was_rolling and elapsed >= 2.25:
			# settle 진입: 착지 반짝임 한 번 더.
			_dice_burst_particles.restart()
			_dice_burst_particles.emitting = true
	_was_rolling = rolling


func _dice_envelope(elapsed: float) -> float:
	# descent 램프인 -> rolling 풀 -> settle 감쇠 -> highlight/wait 호흡 유지.
	if elapsed < 0.60:
		return clampf(elapsed / 0.60, 0.0, 1.0) * 0.85
	if elapsed < 2.25:
		return 1.0
	if elapsed < 2.70:
		return lerpf(1.0, 0.66, (elapsed - 2.25) / 0.45)
	return 0.60 + 0.08 * sin(elapsed * 1.7)


func _dice_arc_rotation(elapsed: float) -> float:
	# 주사위 텀블(아이콘 회전)과 같은 리듬 가족: rolling 동안 반대 방향 0.6배로
	# 돌아 시차 리듬을 만들고, settle에서 감속해 고정 각도로 눕는다.
	if elapsed < 0.60:
		return -elapsed * 0.35
	if elapsed < 2.25:
		var rolling_t := (elapsed - 0.60) / 1.65
		return -0.21 - rolling_t * TAU * 1.95
	var settle_base := -0.21 - TAU * 1.95
	if elapsed < 2.70:
		var settle_t := (elapsed - 2.25) / 0.45
		return settle_base - (1.0 - (1.0 - settle_t) * (1.0 - settle_t)) * 0.55
	return settle_base - 0.55 - (elapsed - 2.70) * 0.10


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

	# 3-피스 주사위 빛 레이어는 브리지(패널·아이콘·텍스트) 위에 얹는다. 브리지가
	# 거의 불투명한 패널을 그리므로 아래 형제로 두면 묻힌다(조상 불투명 채움 트랩의
	# 형제 변형). 백플레이트(실체·MIX)는 브리지 캔버스 안에서 패널 뒤에 그린다.
	_dice_arc_layer = _build_dice_layer("AngelDiceArcLayer", _dice_arc_texture, DICE_ARC_SIZE)
	_dice_arc_material = WritheEmberMaterial.build_material("angel_dice_halo")
	_dice_arc_preset = "angel_dice_halo"
	_dice_arc_layer.material = _dice_arc_material
	_playfield_clip.add_child(_dice_arc_layer)
	_dice_burst_particles = _build_particles("AngelDiceBurstParticles", DICE_BURST_PARTICLE_AMOUNT, true)
	_dice_burst_particles.position = DICE_CENTER
	_playfield_clip.add_child(_dice_burst_particles)
	set_active(false)


func _build_dice_layer(name_value: String, texture: Texture2D, size_value: float) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = name_value
	layer.texture = texture
	layer.size = Vector2.ONE * size_value
	layer.position = DICE_CENTER - Vector2.ONE * size_value * 0.5
	layer.pivot_offset = Vector2.ONE * size_value * 0.5
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.visible = false
	return layer


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
	canvas.draw_rect(Rect2(Vector2.ZERO, GAME_SIZE), Color(0.035, 0.025, 0.10, 0.72))
	canvas.draw_rect(MODAL_PANEL, Color(0.09, 0.075, 0.18, 0.94))
	canvas.draw_rect(MODAL_PANEL, Color(0.76, 0.65, 1.0, 0.92), false, 3.0)
	_draw_text_centered(canvas, AngelLocalization.text("title"), Vector2(380.0, 154.0), 31, Color(1.0, 0.91, 0.54))

	var icon_center := Vector2(380.0, 302.0)
	var intro_scale := clampf(elapsed / 0.60, 0.0, 1.0)
	var rotation := 0.0
	var icon_scale := 0.64 + 0.36 * _ease_out_back(intro_scale)
	if elapsed >= 0.60 and elapsed < 2.25:
		var rolling_t := (elapsed - 0.60) / 1.65
		rotation = rolling_t * TAU * 3.25
		icon_center.y += absf(sin(rolling_t * PI * 6.0)) * -22.0 * (1.0 - rolling_t * 0.45)
	elif elapsed >= 2.25 and elapsed < 2.70:
		rotation = (1.0 - (elapsed - 2.25) / 0.45) * 0.42
	_draw_dice_backplate(canvas, icon_center, elapsed)
	_draw_holy_rays(canvas, icon_center, elapsed)
	_draw_angel_icon(canvas, icon_center, 156.0 * icon_scale, rotation)
	_draw_orbit_accents(canvas, icon_center, elapsed)

	if elapsed < 2.25:
		_draw_text_centered(canvas, AngelLocalization.text("rolling"), Vector2(380.0, 458.0), 17, Color(0.88, 0.84, 1.0))
		return
	_draw_text_centered(canvas, "%s  ·  %d" % [AngelLocalization.text("result"), face], Vector2(380.0, 438.0), 21, Color(1.0, 0.86, 0.38))
	_draw_result_cards(canvas, buff_ids, elapsed)
	if elapsed >= 3.0:
		var prompt_alpha := 0.62 + 0.38 * (0.5 + 0.5 * sin(elapsed * 4.8))
		_draw_text_centered(canvas, AngelLocalization.text("continue"), Vector2(380.0, 601.0), 16, Color(1.0, 0.94, 0.70, prompt_alpha))


func _draw_dice_backplate(canvas: CanvasItem, center: Vector2, elapsed: float) -> void:
	# 3-피스의 실체 조각(MIX). 패널 위·아이콘 아래에서 천천히 역회전하며 숨쉰다.
	# 아이콘과 동일한 확립 패턴(center 변환 -> 그리기 -> 원점 복원)만 사용하고,
	# 별도 셰이더 패스나 canvas.material 교체는 하지 않는다(1패스 원칙).
	if _dice_backplate_texture == null:
		return
	var envelope := _dice_envelope(elapsed)
	if envelope <= 0.01:
		return
	var intro := clampf(elapsed / 0.60, 0.0, 1.0)
	var breath := 1.0 + 0.02 * sin(elapsed * 1.7)
	var size_value := DICE_BACKPLATE_SIZE * (0.72 + 0.28 * _ease_out_back(intro)) * breath
	canvas.draw_set_transform(center, -elapsed * 0.12, Vector2.ONE)
	canvas.draw_texture_rect(
		_dice_backplate_texture,
		Rect2(Vector2(-size_value, -size_value) * 0.5, Vector2.ONE * size_value),
		false,
		Color(1.0, 1.0, 1.0, 0.42 + 0.50 * envelope)
	)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_angel_icon(canvas: CanvasItem, center: Vector2, size_value: float, rotation: float) -> void:
	if _icon_texture == null:
		_draw_fallback_die(canvas, center, size_value)
		return
	canvas.draw_set_transform(center, rotation, Vector2.ONE)
	canvas.draw_texture_rect(
		_icon_texture,
		Rect2(Vector2(-size_value, -size_value) * 0.5, Vector2.ONE * size_value),
		false,
		Color.WHITE
	)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_fallback_die(canvas: CanvasItem, center: Vector2, size_value: float) -> void:
	var rect := Rect2(center - Vector2.ONE * size_value * 0.28, Vector2.ONE * size_value * 0.56)
	canvas.draw_rect(rect, Color(1.0, 0.95, 0.76, 0.96))
	canvas.draw_rect(rect, Color(0.95, 0.66, 0.13), false, 3.0)
	canvas.draw_circle(center, size_value * 0.055, Color(0.33, 0.14, 0.78))


func _draw_holy_rays(canvas: CanvasItem, center: Vector2, elapsed: float) -> void:
	var intro := clampf(elapsed / 0.60, 0.0, 1.0)
	for index: int in range(12):
		var angle := TAU * float(index) / 12.0 + elapsed * 0.22
		var inner := center + Vector2.from_angle(angle) * 82.0
		var outer := center + Vector2.from_angle(angle) * (132.0 + 14.0 * sin(elapsed * 3.0 + index))
		canvas.draw_line(inner, outer, Color(1.0, 0.86, 0.36, 0.16 * intro), 5.0)
		canvas.draw_line(inner, outer, Color(1.0, 1.0, 0.86, 0.48 * intro), 1.4)


func _draw_orbit_accents(canvas: CanvasItem, center: Vector2, elapsed: float) -> void:
	if elapsed < 0.45:
		return
	for index: int in range(8):
		var angle := elapsed * 1.55 + TAU * float(index) / 8.0
		var radius := 112.0 + 8.0 * sin(elapsed * 2.0 + index)
		var pos := center + Vector2.from_angle(angle) * radius
		var tangent := Vector2.from_angle(angle + PI * 0.5)
		canvas.draw_line(pos - tangent * 7.0, pos + tangent * 7.0, Color(1.0, 0.96, 0.72, 0.68), 2.2)
		canvas.draw_circle(pos, 2.2, Color(1.0, 0.72, 0.18, 0.92))
	for index: int in range(6):
		var angle := -elapsed * 0.86 + TAU * float(index) / 6.0
		var pos := center + Vector2.from_angle(angle) * 142.0
		_draw_star(canvas, pos, 6.0, Color(1.0, 0.91, 0.42, 0.82))


func _draw_result_cards(canvas: CanvasItem, buff_ids: Array[String], elapsed: float) -> void:
	if buff_ids.is_empty():
		return
	var card_width := 132.0
	var gap := 10.0
	var total_width := card_width * buff_ids.size() + gap * maxi(0, buff_ids.size() - 1)
	var start_x := 380.0 - total_width * 0.5
	var reveal := clampf((elapsed - 2.25) / 0.45, 0.0, 1.0)
	for index: int in range(buff_ids.size()):
		var rect := Rect2(start_x + float(index) * (card_width + gap), 474.0 + (1.0 - reveal) * 20.0, card_width, 76.0)
		var pulse := 0.5 + 0.5 * sin(elapsed * 4.2 + index * 0.8)
		canvas.draw_rect(rect, Color(0.13, 0.09, 0.22, 0.92 * reveal))
		canvas.draw_rect(rect.grow(2.0 + pulse * 1.5), Color(1.0, 0.73, 0.20, (0.34 + pulse * 0.28) * reveal), false, 2.0)
		_draw_text_centered(canvas, AngelLocalization.buff_label(buff_ids[index]), rect.get_center() + Vector2(0.0, -5.0), 13, Color(1.0, 0.96, 0.84, reveal))
		var sign := "+" if buff_ids[index] in ["paddle_size", "gauge_max", "move_speed"] else "-"
		_draw_text_centered(canvas, "%s30%%" % sign, rect.get_center() + Vector2(0.0, 20.0), 15, Color(1.0, 0.78, 0.28, reveal))


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
				canvas.draw_circle(trail_pos, 3.0 + trail_alpha * 4.0, Color(1.0, 0.72, 0.16, trail_alpha))
			var pos := _quadratic_bezier(start, control, _player_pos, progress)
			canvas.draw_circle(pos, 14.0, Color(1.0, 0.58, 0.08, 0.16))
			canvas.draw_circle(pos, 7.0, Color(1.0, 0.86, 0.32, 0.72))
			canvas.draw_circle(pos, 3.0, Color(1.0, 1.0, 0.92, 1.0))
			canvas.draw_line(pos - Vector2(10.0, 0.0), pos + Vector2(10.0, 0.0), Color(1.0, 0.95, 0.68, 0.64), 1.5)
			canvas.draw_line(pos - Vector2(0.0, 10.0), pos + Vector2(0.0, 10.0), Color(1.0, 0.95, 0.68, 0.64), 1.5)
		var arrival_time := float(trajectory.get("arrival_time", delay + duration))
		var glow_duration := maxf(0.001, float(absorption.get("glow_duration", 0.35)))
		if elapsed >= arrival_time and elapsed <= arrival_time + glow_duration:
			var glow_ratio := 1.0 - (elapsed - arrival_time) / glow_duration
			canvas.draw_circle(_player_pos, 58.0 * (1.0 + (1.0 - glow_ratio) * 0.28), Color(1.0, 0.78, 0.24, 0.22 * glow_ratio))
			canvas.draw_arc(_player_pos, 38.0, 0.0, TAU, 28, Color(1.0, 0.94, 0.58, 0.82 * glow_ratio), 3.0)


func _quadratic_bezier(start: Vector2, control: Vector2, target: Vector2, t: float) -> Vector2:
	var one_minus_t := 1.0 - t
	return one_minus_t * one_minus_t * start + 2.0 * one_minus_t * t * control + t * t * target


func _draw_star(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_line(center - Vector2(radius, 0.0), center + Vector2(radius, 0.0), color, 1.8)
	canvas.draw_line(center - Vector2(0.0, radius), center + Vector2(0.0, radius), color, 1.8)
	canvas.draw_circle(center, radius * 0.34, Color(1.0, 1.0, 0.88, color.a))


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
