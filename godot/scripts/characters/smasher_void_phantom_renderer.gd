extends RefCounted

# 허공환영 환영공 드로우.
#
# 핵심 계약은 "실제 공 형태/팔레트 + 살짝 비치는 본체 + 은은한 시안 림"이다.
# 환영 본체는 실제 공이 사용한 완성 컨텍스트를 BallRenderer.draw_current()에 넘긴다.
# 분리된 node FX만 끄고 스킬 색·그림자·상태 오버레이·공 전용 잔상은 그대로 복제한다.
# 본체·그림자·상태 오버레이·공 전용 잔상은 모두 72% 알파이고 1px 이하의 끊긴
# 시안 림이 더해진다. 발동/간파/팝은
# 공의 정체를 색으로 과도하게 폭로하지 않는 짧은 사건 연출이다.
#
# 레이어/예산:
#   launch anchor burst(공유 1회) -> exact ball stack -> subtle cyan rim
#   -> reveal cyan fracture(10프레임) -> cyan glitch pop.
# 실제 공 렌더러와 같은 fx_lod_scale을 받아 링/색수차/파티클 상세도가 함께 벗겨진다.
# 별도 FX host나 첫 프레임 텍스처 빌드는 만들지 않는 작은 최종 절차형 VFX다.
const EnergyBallRendererScript := preload("res://scripts/ball/energy_ball_renderer.gd")
const BallRendererScript := preload("res://scripts/ball/ball_renderer.gd")
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const WritheEmber := preload("res://scripts/effects/writhe_ember_material.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const VoidPhantomFxHost := preload("res://scripts/characters/smasher_void_phantom_fx_host.gd")

const BACKPLATE_PATH := "res://assets/sprites/skills/void_phantom_vfx/void_phantom_backplate.png"
const ARC_TRAIL_PATH := "res://assets/sprites/skills/void_phantom_vfx/void_phantom_arc_trail.png"

const VOID_CYAN := Color(0.46, 0.96, 1.0)
const VOID_PALE_CYAN := Color(0.78, 0.99, 1.0)
const VOID_SEAL_GOLD := Color(0.94, 0.79, 0.43)
const LAUNCH_SPLIT_FRAMES := 14.0
const MAX_DECOY_RENDERERS := 2
const DECOY_BODY_ALPHA := 0.72
const FULL_DETAIL_LOD_THRESHOLD := 0.82
const ACCENT_TEXTURE_LOD_THRESHOLD := 0.68
const CHARGE_ORB_START_RADIUS := 2.5
const CHARGE_ORB_FINAL_RADIUS := EnergyBallRendererScript.BALL_RENDER_RADIUS * 0.94
const MODULAR_RELEASE_FRAMES := 14.0

var _ball_renderers: Array[Object] = []
var _last_launch_serial_by_slot: Array[int] = []
var _writhe_material: ShaderMaterial = null
var _writhe_enraged := false
var _fx_host: Node = null
var _fx_host_add_pending := false

static var _backplate_texture: Texture2D = null
static var _arc_trail_texture: Texture2D = null
static var _prewarmed := false


func _init() -> void:
	prewarm_assets()
	_writhe_material = WritheEmber.build_material("smasher_void_phantom_writhe")
	_fx_host = VoidPhantomFxHost.new()
	_fx_host.name = "SmasherVoidPhantomFxHost"
	_fx_host.prewarm_node_pipeline()
	for _index in range(MAX_DECOY_RENDERERS):
		_ball_renderers.append(BallRendererScript.new())
		_last_launch_serial_by_slot.append(-1)


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_PREDELETE
		and _fx_host != null
		and is_instance_valid(_fx_host)
		and not _fx_host.is_inside_tree()
	):
		_fx_host.free()


static func prewarm_assets() -> void:
	if _prewarmed:
		return
	WritheEmber.prewarm()
	_get_backplate_texture()
	_get_arc_trail_texture()
	VoidPhantomFxHost.prewarm_assets()
	_prewarmed = true


static func build_pipeline_status() -> Dictionary:
	prewarm_assets()
	var host_status: Dictionary = VoidPhantomFxHost.build_pipeline_status()
	return {
		"backplate_texture_ready": _get_backplate_texture() != null,
		"arc_trail_texture_ready": _get_arc_trail_texture() != null,
		"particle_texture_ready": bool(host_status.get("particle_texture_ready", false)),
		"normal_preset_ready": WritheEmber.has_preset("smasher_void_phantom_writhe"),
		"enraged_preset_ready": WritheEmber.has_preset("smasher_void_phantom_writhe_enraged"),
	}


# 흔들림 오프셋 합성을 단일 헬퍼로 강제해, 환영 좌표 규약(실 공 중심 좌표계)이
# 드로우 사이트마다 갈라지지 않게 한다.
static func resolve_render_center(entity: Dictionary, shake_offset: Vector2) -> Vector2:
	var value: Variant = entity.get("pos", Vector2.ZERO)
	var pos: Vector2 = value if value is Vector2 else Vector2.ZERO
	return pos + shake_offset


static func resolve_launch_origin(draw_context: Dictionary, shake_offset: Vector2) -> Vector2:
	var value: Variant = draw_context.get("launch_origin", Vector2.ZERO)
	var origin: Vector2 = value if value is Vector2 else Vector2.ZERO
	return origin + shake_offset


static func should_draw_launch_split(
	draw_context: Dictionary, _shake_offset: Vector2 = Vector2.ZERO
) -> bool:
	# 흔들림은 유효성 판정에 관여하지 않는다. 원본 좌표의 명시적 bool만 신뢰한다.
	return bool(draw_context.get("has_launch_origin", false))


# 자동 씰과 생산 루프가 같은 값을 사용한다. 희소 레이어를 live-index stride로
# 깜빡이게 하지 않고, 심한 LOD에서는 개수 자체를 안정적으로 줄인다.
static func get_launch_arc_count(fx_lod_scale: float) -> int:
	return 2 if fx_lod_scale >= FULL_DETAIL_LOD_THRESHOLD else 1


static func get_pop_shard_count(fx_lod_scale: float) -> int:
	return 6 if fx_lod_scale >= FULL_DETAIL_LOD_THRESHOLD else 3


static func is_accent_texture_enabled(fx_lod_scale: float) -> bool:
	return fx_lod_scale >= ACCENT_TEXTURE_LOD_THRESHOLD


static func get_charge_orb_radius(charge_ratio: float) -> float:
	var formation: float = clampf((charge_ratio - 0.04) / 0.92, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - formation, 2.2)
	return lerpf(CHARGE_ORB_START_RADIUS, CHARGE_ORB_FINAL_RADIUS, eased)


static func get_release_shockwave_radius(age_frames: float) -> float:
	var expansion: float = clampf(age_frames / LAUNCH_SPLIT_FRAMES, 0.0, 1.0)
	return lerpf(CHARGE_ORB_FINAL_RADIUS * 0.86, 68.0, 1.0 - pow(1.0 - expansion, 1.35))


func draw(
	canvas: CanvasItem,
	draw_context: Dictionary,
	shake_offset: Vector2,
	fx_lod_scale: float = 1.0,
	ball_renderer_context: Dictionary = {}
) -> void:
	if canvas == null or draw_context.is_empty():
		set_active(false)
		return
	var lod_scale: float = clampf(fx_lod_scale, 0.35, 1.0)
	var phase: float = float(draw_context.get("phase", 0.0))
	var locked_index: int = int(draw_context.get("locked_decoy_index", -1))
	var reveal_flash_ratio: float = clampf(
		float(draw_context.get("reveal_flash_ratio", 0.0)), 0.0, 1.0
	)
	var decoys: Array = draw_context.get("decoys", [])
	var release_life: float = get_modular_release_life(decoys)
	var phase_envelope: float = _sync_modular_fx_host(
		canvas,
		draw_context,
		shake_offset,
		lod_scale,
		ball_renderer_context,
		release_life
	)
	_draw_modular_texture_layers(
		canvas,
		draw_context,
		shake_offset,
		lod_scale,
		release_life,
		phase_envelope
	)
	if bool(draw_context.get("charging", false)):
		_draw_charge_gather(
			canvas,
			_get_vector2(draw_context, "charge_ball_pos") + shake_offset,
			clampf(float(draw_context.get("charge_ratio", 0.0)), 0.0, 1.0),
			draw_context.get("seal_ring_texture", null),
			lod_scale
		)
	# 복제 원본이 없는 프레임에는 환영 본체와 발동 균열을 fail-closed한다.
	# 팝은 이미 소멸한 환영의 잔여 연출이므로 아래 독립 경로에서 수명을 마친다.
	if not ball_renderer_context.is_empty():
		# 최상위 키 두 개만 환영별로 덮는다. 하위 스냅샷은 모든 BallRenderer가
		# 읽기 전용으로 소비하므로 프레임당 한 번의 얕은 복사면 충분하다.
		var decoy_renderer_context: Dictionary = ball_renderer_context.duplicate()
		decoy_renderer_context["effect_lod_scale"] = lod_scale
		# 완성 공 스택 전체를 살짝 비치게 한다. 시안 림과 발동/간파/소멸 사건
		# 연출은 별도 레이어라 이 알파에 묶지 않는다.
		decoy_renderer_context["ball_render_alpha"] = DECOY_BODY_ALPHA
		var launch_origin: Vector2 = resolve_launch_origin(draw_context, shake_offset)
		if should_draw_launch_split(draw_context, shake_offset):
			_draw_launch_split(
				canvas,
				launch_origin,
				decoys,
				phase,
				lod_scale,
				draw_context.get("seal_ring_texture", null)
			)
		var launch_serial: int = int(draw_context.get("launch_serial", 0))
		for index in range(decoys.size()):
			var decoy_value: Variant = decoys[index]
			if decoy_value is Dictionary:
				_draw_decoy(
					canvas,
					decoy_value,
					phase,
					index == locked_index,
					reveal_flash_ratio,
					shake_offset,
					lod_scale,
					decoy_renderer_context,
					index,
					launch_serial
				)
	var pop_particles: Array = draw_context.get("pop_particles", [])
	for particle_value in pop_particles:
		if particle_value is Dictionary:
			_draw_pop_particle(canvas, particle_value, shake_offset, lod_scale)


static func get_modular_release_life(decoys: Array) -> float:
	var youngest_age := INF
	for decoy_value in decoys:
		if decoy_value is Dictionary:
			youngest_age = minf(
				youngest_age,
				float((decoy_value as Dictionary).get("age_frames", MODULAR_RELEASE_FRAMES))
			)
	if youngest_age == INF or youngest_age >= MODULAR_RELEASE_FRAMES:
		return 0.0
	return clampf(1.0 - youngest_age / MODULAR_RELEASE_FRAMES, 0.0, 1.0)


func set_active(active: bool) -> void:
	if _fx_host != null and is_instance_valid(_fx_host) and _fx_host.has_method("set_active"):
		_fx_host.set_active(active)


func get_fx_host_for_tests() -> Node:
	return _fx_host


func _sync_modular_fx_host(
	canvas: CanvasItem,
	draw_context: Dictionary,
	shake_offset: Vector2,
	lod_scale: float,
	ball_renderer_context: Dictionary,
	release_life: float
) -> float:
	var charging: bool = bool(draw_context.get("charging", false))
	var release_active: bool = (
		bool(draw_context.get("has_launch_origin", false)) and release_life > 0.0
	)
	if not charging and not release_active:
		set_active(false)
		return 1.0
	var layout_value: Variant = ball_renderer_context.get("node_fx_layout", {})
	if not (layout_value is Dictionary) or (layout_value as Dictionary).is_empty():
		set_active(false)
		return 1.0
	var layout: Dictionary = layout_value
	var render_scale: float = maxf(0.01, float(layout.get("render_scale", 1.0)))
	var game_offset: Vector2 = _variant_vector2(layout.get("game_offset", Vector2.ZERO))
	var playfield_pos: Vector2 = (
		_get_vector2(draw_context, "charge_ball_pos")
		if charging
		else _get_vector2(draw_context, "launch_origin")
	)
	# Detached child slots always use the explicit rendered-playfield mapping.
	# Do not reuse a parent draw transform and do not reset it to IDENTITY.
	var screen_pos: Vector2 = VoidPhantomFxHost.build_screen_position_for_tests(
		playfield_pos,
		shake_offset,
		game_offset,
		render_scale
	)
	var host: Node = _get_or_create_fx_host(canvas)
	if host == null or not host.has_method("sync_state"):
		return 1.0
	host.sync_state({
		"active": true,
		"phase": "charge" if charging else "release",
		"screen_pos": screen_pos,
		"game_offset": game_offset,
		"render_scale": render_scale,
		"charge_ratio": clampf(float(draw_context.get("charge_ratio", 0.0)), 0.0, 1.0),
		"release_life": release_life,
		"intensity": maxf(0.12, float(draw_context.get("charge_ratio", release_life))),
		"quality_scale": lod_scale,
	}, true)
	if host.has_method("get_phase_envelope"):
		return maxf(0.0, float(host.get_phase_envelope()))
	return 1.0


func _get_or_create_fx_host(canvas: CanvasItem) -> Node:
	if _fx_host == null or not is_instance_valid(_fx_host):
		_fx_host = VoidPhantomFxHost.new()
		_fx_host.name = "SmasherVoidPhantomFxHost"
		_fx_host.prewarm_node_pipeline()
		_fx_host_add_pending = false
	if not _fx_host.is_inside_tree() and not _fx_host_add_pending:
		_fx_host_add_pending = true
		canvas.call_deferred("add_child", _fx_host)
	return _fx_host


func _draw_modular_texture_layers(
	canvas: CanvasItem,
	draw_context: Dictionary,
	shake_offset: Vector2,
	lod_scale: float,
	release_life: float,
	phase_envelope: float
) -> void:
	var charging: bool = bool(draw_context.get("charging", false))
	if not charging and release_life <= 0.0:
		return
	var center: Vector2 = (
		_get_vector2(draw_context, "charge_ball_pos")
		if charging
		else _get_vector2(draw_context, "launch_origin")
	) + shake_offset
	var charge_ratio: float = clampf(float(draw_context.get("charge_ratio", 0.0)), 0.0, 1.0)
	var eased: float = charge_ratio * charge_ratio * (3.0 - 2.0 * charge_ratio)
	var expansion: float = 1.0 - release_life
	var envelope: float = clampf(phase_envelope, 0.0, 1.5)
	var elapsed: float = float(Time.get_ticks_msec()) / 1000.0
	var backplate_size: float = (
		lerpf(44.0, 158.0, eased)
		if charging
		else lerpf(138.0, 204.0, expansion)
	)
	var arc_size: float = (
		lerpf(38.0, 148.0, eased)
		if charging
		else lerpf(126.0, 226.0, expansion)
	)
	var backplate_alpha: float = (
		(0.07 + 0.31 * eased) * minf(1.0, envelope)
		if charging
		else 0.46 * release_life * minf(1.0, envelope)
	)
	var arc_alpha: float = (
		(0.13 + 0.52 * eased) * minf(1.0, envelope)
		if charging
		else 0.82 * release_life * minf(1.0, envelope)
	)
	var previous_material: Material = canvas.material
	# Solid ink depth is MIX. The generated asset already carries its radial mask.
	canvas.material = null
	_draw_rotated_texture(
		canvas,
		_get_backplate_texture(),
		center,
		backplate_size,
		elapsed * (-0.10 if charging else 0.34),
		Color(0.70, 0.82, 0.94, backplate_alpha)
	)

	# Exactly one writhing-ember shader pass for every luminous arc draw, followed
	# by unconditional material restoration. No draw_set_transform call is used.
	var enraged: bool = bool(draw_context.get("enraged", false))
	if enraged != _writhe_enraged:
		_writhe_enraged = enraged
		WritheEmber.apply_preset(
			_writhe_material,
			"smasher_void_phantom_writhe_enraged" if enraged else "smasher_void_phantom_writhe"
		)
	_writhe_material.set_shader_parameter("elapsed", elapsed)
	_writhe_material.set_shader_parameter("intensity", (0.62 + 0.58 * eased) * envelope)
	canvas.material = _writhe_material
	var rotation: float = (
		elapsed * (0.82 + 0.34 * charge_ratio)
		if charging
		else elapsed * 1.45 + expansion * 1.2
	)
	_draw_rotated_texture(
		canvas,
		_get_arc_trail_texture(),
		center,
		arc_size,
		rotation,
		Color(0.86, 0.98, 1.0, arc_alpha * (0.64 + 0.36 * lod_scale))
	)
	if lod_scale >= FULL_DETAIL_LOD_THRESHOLD:
		_draw_rotated_texture(
			canvas,
			_get_arc_trail_texture(),
			center,
			arc_size * 0.78,
			-rotation * 0.74 + PI,
			Color(0.74, 0.92, 1.0, arc_alpha * 0.34)
		)
	canvas.material = previous_material


func _draw_rotated_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	side: float,
	rotation: float,
	color: Color
) -> void:
	if texture == null or side <= 0.0 or color.a <= 0.0:
		return
	var half := Vector2.ONE * side * 0.5
	var local_points := [
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	]
	var points := PackedVector2Array()
	for local_point in local_points:
		points.append(center + (local_point as Vector2).rotated(rotation))
	canvas.draw_colored_polygon(
		points,
		color,
		PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(1.0, 0.0),
			Vector2(1.0, 1.0),
			Vector2(0.0, 1.0),
		]),
		texture
	)


func _draw_charge_gather(
	canvas: CanvasItem,
	center: Vector2,
	charge_ratio: float,
	seal_ring_texture: Variant,
	lod_scale: float
) -> void:
	var eased: float = charge_ratio * charge_ratio * (3.0 - 2.0 * charge_ratio)
	var orb_radius: float = get_charge_orb_radius(charge_ratio)
	var orb_energy: float = clampf((charge_ratio - 0.02) / 0.88, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(charge_ratio * TAU * 3.0)
	ImpactFlareTextureCache.draw_burst(
		canvas,
		center,
		15.0 + eased * 34.0,
		VOID_CYAN,
		0.08 + eased * 0.22
	)
	if seal_ring_texture is Texture2D:
		var seal_texture: Texture2D = seal_ring_texture
		var seal_size: float = 42.0 + eased * 66.0
		canvas.draw_texture_rect(
			seal_texture,
			Rect2(center - Vector2.ONE * seal_size * 0.5, Vector2.ONE * seal_size),
			false,
			Color(0.70, 0.95, 1.0, 0.10 + eased * 0.46),
			false
		)
	# 기존 완성 공은 이 단계에서 숨겨진다. 아래 네 겹이 작은 기핵에서 실제 공
	# 크기까지 자라므로, 차지 시간이 곧 에너지구의 형성 시간으로 읽힌다.
	canvas.draw_circle(
		center,
		orb_radius * (1.42 + pulse * 0.10),
		Color(VOID_CYAN.r, VOID_CYAN.g, VOID_CYAN.b, 0.035 + orb_energy * 0.085),
		true
	)
	canvas.draw_circle(
		center,
		orb_radius * 1.10,
		Color(0.18, 0.77, 0.96, 0.13 + orb_energy * 0.19),
		true
	)
	canvas.draw_circle(
		center,
		orb_radius,
		Color(0.20, 0.57 + orb_energy * 0.20, 0.92, 0.38 + orb_energy * 0.34),
		true
	)
	canvas.draw_circle(
		center - Vector2(orb_radius * 0.18, orb_radius * 0.20),
		maxf(1.2, orb_radius * (0.22 + pulse * 0.035)),
		Color(0.88, 1.0, 1.0, 0.48 + orb_energy * 0.42),
		true
	)
	canvas.draw_arc(
		center,
		orb_radius * 1.04,
		-charge_ratio * TAU * 2.2,
		-charge_ratio * TAU * 2.2 + PI * 1.42,
		22 if lod_scale >= FULL_DETAIL_LOD_THRESHOLD else 14,
		Color(VOID_PALE_CYAN.r, VOID_PALE_CYAN.g, VOID_PALE_CYAN.b, 0.22 + orb_energy * 0.36),
		1.15,
		true
	)
	var arc_count: int = 3 if lod_scale >= FULL_DETAIL_LOD_THRESHOLD else 2
	for arc_index in range(arc_count):
		var direction: float = -1.0 if arc_index % 2 == 0 else 1.0
		var rotation: float = charge_ratio * TAU * direction * (1.1 + float(arc_index) * 0.22)
		var radius: float = orb_radius + 9.0 + float(arc_index) * 7.0
		canvas.draw_arc(
			center,
			radius,
			rotation,
			rotation + PI * (0.72 + float(arc_index) * 0.13),
			18 if lod_scale >= FULL_DETAIL_LOD_THRESHOLD else 11,
			Color(VOID_CYAN.r, VOID_CYAN.g, VOID_CYAN.b, 0.24 + eased * 0.28),
			1.0 + eased * 0.7,
			true
		)
	var wisp_count: int = 6 if lod_scale >= FULL_DETAIL_LOD_THRESHOLD else 4
	for wisp_index in range(wisp_count):
		var angle: float = TAU * float(wisp_index) / float(wisp_count) - charge_ratio * TAU * 1.7
		var direction := Vector2(cos(angle), sin(angle))
		var outer_radius: float = 54.0 - eased * 13.0 + float(wisp_index % 2) * 4.0
		var inner_radius: float = maxf(orb_radius + 2.0, outer_radius - 10.0 - eased * 9.0)
		canvas.draw_line(
			center + direction * outer_radius,
			center + direction * inner_radius,
			Color(VOID_SEAL_GOLD.r, VOID_SEAL_GOLD.g, VOID_SEAL_GOLD.b, (0.28 + eased * 0.40) * (0.82 + pulse * 0.18)),
			1.15,
			true
		)


func _draw_decoy(
	canvas: CanvasItem,
	decoy: Dictionary,
	phase: float,
	is_locked: bool,
	reveal_flash_ratio: float,
	shake_offset: Vector2,
	lod_scale: float,
	ball_renderer_context: Dictionary,
	fallback_slot: int,
	launch_serial: int
) -> void:
	var center: Vector2 = resolve_render_center(decoy, shake_offset)
	var render_slot: int = clampi(
		int(decoy.get("render_slot", fallback_slot)), 0, MAX_DECOY_RENDERERS - 1
	)
	var ball_renderer: Object = _ball_renderers[render_slot]
	# 발동 프레임의 draw가 생략돼도 serial이 바뀐 첫 draw에서 이전 잔상을 지운다.
	if _last_launch_serial_by_slot[render_slot] != launch_serial and ball_renderer.has_method("clear"):
		ball_renderer.clear()
		_last_launch_serial_by_slot[render_slot] = launch_serial
	ball_renderer_context["ball_vel"] = _get_vector2(decoy, "vel")
	ball_renderer.draw_current(
		canvas,
		center,
		ball_renderer_context,
		null,
		false
	)
	_draw_player_cyan_rim(canvas, center, phase, decoy, is_locked, lod_scale)
	if reveal_flash_ratio > 0.0:
		_draw_reveal_fracture(canvas, center, decoy, phase, reveal_flash_ratio, lod_scale)


func _draw_player_cyan_rim(
	canvas: CanvasItem,
	center: Vector2,
	phase: float,
	decoy: Dictionary,
	is_locked: bool,
	lod_scale: float
) -> void:
	var seed_value: float = float(decoy.get("flicker_seed", 0.0))
	var rotation: float = phase * 0.42 + seed_value
	var radius: float = EnergyBallRendererScript.BALL_RENDER_RADIUS * (1.22 if lod_scale >= FULL_DETAIL_LOD_THRESHOLD else 1.10)
	var alpha: float = 0.13 if is_locked else 0.10
	if lod_scale < FULL_DETAIL_LOD_THRESHOLD:
		alpha *= 0.58
	canvas.draw_arc(
		center,
		radius,
		rotation,
		rotation + PI * 0.72,
		14 if lod_scale >= FULL_DETAIL_LOD_THRESHOLD else 9,
		Color(VOID_CYAN.r, VOID_CYAN.g, VOID_CYAN.b, alpha),
		0.9,
		true
	)


func _draw_launch_split(
	canvas: CanvasItem,
	launch_origin: Vector2,
	decoys: Array,
	phase: float,
	lod_scale: float,
	seal_ring_texture: Variant = null
) -> void:
	var direction_sum := Vector2.ZERO
	var youngest_age := INF
	var live_count := 0
	for decoy_value in decoys:
		if not (decoy_value is Dictionary):
			continue
		direction_sum += _get_vector2(decoy_value, "vel").normalized()
		youngest_age = minf(
			youngest_age, float(decoy_value.get("age_frames", LAUNCH_SPLIT_FRAMES))
		)
		live_count += 1
	if live_count <= 0 or youngest_age >= LAUNCH_SPLIT_FRAMES:
		return
	var life: float = clampf(1.0 - youngest_age / LAUNCH_SPLIT_FRAMES, 0.0, 1.0)
	var expansion: float = 1.0 - life
	var shockwave_radius: float = get_release_shockwave_radius(youngest_age)
	if seal_ring_texture is Texture2D:
		var seal_texture: Texture2D = seal_ring_texture
		var seal_size: float = 84.0 + 54.0 * expansion
		canvas.draw_texture_rect(
			seal_texture,
			Rect2(
				launch_origin - Vector2.ONE * seal_size * 0.5,
				Vector2.ONE * seal_size
			),
			false,
			Color(0.76, 0.96, 1.0, 0.54 * life),
			false
		)
	ImpactFlareTextureCache.draw_burst(
		canvas, launch_origin, 34.0 + 52.0 * expansion, VOID_CYAN, 0.34 * life
	)
	# 완성된 구가 순간적으로 백색 핵으로 압축된 뒤 충격파와 방사광으로 터진다.
	# 실제 공/환영은 바로 아래 레이어에서 이미 발사 방향으로 움직이기 시작한다.
	canvas.draw_circle(
		launch_origin,
		8.0 + 20.0 * pow(life, 1.55),
		Color(0.82, 1.0, 1.0, 0.62 * pow(life, 1.35)),
		true
	)
	canvas.draw_arc(
		launch_origin,
		shockwave_radius,
		0.0,
		TAU,
		32 if lod_scale >= FULL_DETAIL_LOD_THRESHOLD else 20,
		Color(VOID_PALE_CYAN.r, VOID_PALE_CYAN.g, VOID_PALE_CYAN.b, 0.72 * life),
		2.4 - expansion * 1.1,
		true
	)
	var ray_count: int = 10 if lod_scale >= FULL_DETAIL_LOD_THRESHOLD else 6
	for ray_index in range(ray_count):
		var ray_angle: float = phase * 0.31 + TAU * float(ray_index) / float(ray_count)
		var ray_direction := Vector2(cos(ray_angle), sin(ray_angle))
		var ray_start: float = 7.0 + 13.0 * expansion
		var ray_end: float = 31.0 + 43.0 * expansion + float(ray_index % 2) * 8.0
		canvas.draw_line(
			launch_origin + ray_direction * ray_start,
			launch_origin + ray_direction * ray_end,
			Color(VOID_PALE_CYAN.r, VOID_PALE_CYAN.g, VOID_PALE_CYAN.b, 0.50 * life),
			1.55 if ray_index % 2 == 0 else 0.95,
			true
		)
	if is_accent_texture_enabled(lod_scale):
		ImpactFlareTextureCache.draw_sparkle(
			canvas, launch_origin, 12.0 + 10.0 * expansion, VOID_PALE_CYAN, 0.22 * life
		)
	var arc_count: int = get_launch_arc_count(lod_scale)
	for arc_index in range(arc_count):
		var radius: float = 17.0 + 15.0 * expansion + float(arc_index) * 7.0
		var rotation: float = phase * (0.72 if arc_index == 0 else -0.52) + float(arc_index) * PI
		canvas.draw_arc(
			launch_origin,
			radius,
			rotation,
			rotation + PI * (1.18 if arc_index == 0 else 0.82),
			22 if arc_index == 0 else 15,
			Color(VOID_CYAN.r, VOID_CYAN.g, VOID_CYAN.b, (0.48 - float(arc_index) * 0.14) * life),
			1.55 if arc_index == 0 else 1.0,
			true
		)
	if lod_scale < FULL_DETAIL_LOD_THRESHOLD:
		return
	for decoy_value in decoys:
		if not (decoy_value is Dictionary):
			continue
		var direction: Vector2 = _get_vector2(decoy_value, "vel").normalized()
		if direction.length_squared() <= 0.001:
			direction = direction_sum.normalized()
		canvas.draw_line(
			launch_origin - direction * 3.0,
			launch_origin + direction * (20.0 + 12.0 * expansion),
			Color(VOID_PALE_CYAN.r, VOID_PALE_CYAN.g, VOID_PALE_CYAN.b, 0.34 * life),
			1.25,
			true
		)


func _draw_reveal_fracture(
	canvas: CanvasItem,
	center: Vector2,
	decoy: Dictionary,
	phase: float,
	reveal_flash_ratio: float,
	lod_scale: float
) -> void:
	var energy: float = pow(reveal_flash_ratio, 0.72)
	var vel: Vector2 = _get_vector2(decoy, "vel")
	var tangent := Vector2(1.0, 0.0)
	if vel.length_squared() > 0.001:
		var direction: Vector2 = vel.normalized()
		tangent = Vector2(-direction.y, direction.x)
	var radius: float = EnergyBallRendererScript.BALL_RENDER_RADIUS
	if is_accent_texture_enabled(lod_scale):
		var separation: float = 1.5 + (1.0 - reveal_flash_ratio) * 2.5
		ImpactFlareTextureCache.draw_sparkle(
			canvas, center + tangent * separation, radius * 0.34, VOID_PALE_CYAN, 0.22 * energy
		)
	canvas.draw_arc(
		center,
		radius * (1.08 + (1.0 - reveal_flash_ratio) * 0.16),
		-phase * 1.15,
		-phase * 1.15 + PI * 1.18,
		18 if lod_scale >= FULL_DETAIL_LOD_THRESHOLD else 11,
		Color(VOID_CYAN.r, VOID_CYAN.g, VOID_CYAN.b, 0.34 * energy),
		1.15,
		true
	)


func _draw_pop_particle(
	canvas: CanvasItem,
	particle: Dictionary,
	shake_offset: Vector2,
	lod_scale: float
) -> void:
	var age_frames: float = float(particle.get("age_frames", 0.0))
	var lifetime_frames: float = maxf(1.0, float(particle.get("lifetime_frames", 12.0)))
	var life: float = clampf(1.0 - age_frames / lifetime_frames, 0.0, 1.0)
	if life <= 0.0:
		return
	var center: Vector2 = resolve_render_center(particle, shake_offset)
	var seed_value: float = float(particle.get("flicker_seed", 0.0))
	var expansion: float = age_frames / lifetime_frames
	ImpactFlareTextureCache.draw_burst(
		canvas, center, 16.0 + age_frames * 2.2, VOID_CYAN, 0.25 * life
	)
	if is_accent_texture_enabled(lod_scale):
		ImpactFlareTextureCache.draw_sparkle(
			canvas, center, 10.0 + age_frames * 1.1, VOID_PALE_CYAN, 0.24 * life
		)
	var shard_count: int = get_pop_shard_count(lod_scale)
	for index in range(shard_count):
		var angle: float = seed_value + TAU * float(index) / float(shard_count) + expansion * 0.34
		var direction := Vector2(cos(angle), sin(angle))
		var start_pos: Vector2 = center + direction * (4.0 + age_frames * 0.35)
		var end_pos: Vector2 = center + direction * (13.0 + age_frames * 0.86)
		canvas.draw_line(
			start_pos,
			end_pos,
			Color(VOID_CYAN.r, VOID_CYAN.g, VOID_CYAN.b, 0.52 * life),
			1.35,
			true
		)


func _get_vector2(source: Dictionary, key: String) -> Vector2:
	var value: Variant = source.get(key, Vector2.ZERO)
	return value if value is Vector2 else Vector2.ZERO


static func _variant_vector2(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2.ZERO


static func _get_backplate_texture() -> Texture2D:
	if _backplate_texture == null:
		_backplate_texture = ProjectResourceLoader.load_texture(
			BACKPLATE_PATH,
			"Void Phantom backplate texture missing",
			"Void Phantom backplate texture load failed"
		)
	return _backplate_texture


static func _get_arc_trail_texture() -> Texture2D:
	if _arc_trail_texture == null:
		_arc_trail_texture = ProjectResourceLoader.load_texture(
			ARC_TRAIL_PATH,
			"Void Phantom arc trail texture missing",
			"Void Phantom arc trail texture load failed"
		)
	return _arc_trail_texture


static func reset_modular_assets_for_test() -> void:
	_backplate_texture = null
	_arc_trail_texture = null
	_prewarmed = false
	VoidPhantomFxHost.reset_for_test()
