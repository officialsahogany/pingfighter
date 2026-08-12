extends RefCounted

const Stage1ContextReader := preload("res://scripts/stages/stage1/stage1_context_reader.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")
const Stage1DashSideGaugeRenderer := preload("res://scripts/stages/stage1/stage1_dash_side_gauge_renderer.gd")
const ImpactFlareTextureCache := preload("res://scripts/effects/impact_flare_texture_cache.gd")
const ImpactShockwaveTextureCache := preload("res://scripts/effects/impact_shockwave_texture_cache.gd")
const PaddleHologramGlitchRenderer := preload("res://scripts/effects/paddle_hologram_glitch_renderer.gd")
const OdinsEyePresentationFxHost := preload("res://scripts/items/odins_eye_presentation_fx_host.gd")
const OdinsEyePresentationRenderer := preload("res://scripts/items/odins_eye_presentation_renderer.gd")
const ViperAirborneLod := preload("res://scripts/core/viper_airborne_lod.gd")
const ViperAirborneRenderToggles := preload("res://scripts/core/viper_airborne_render_toggles.gd")
const HornStrawberryPaddleRenderer := preload("res://scripts/items/horn_strawberry_paddle_renderer.gd")
const PlayerStateGlowRenderer := preload("res://scripts/effects/player_state_glow_renderer.gd")
const StatusEffectOverlayRenderer := preload("res://scripts/status/status_effect_overlay_renderer.gd")
const SoftGlowTexture := preload("res://scripts/effects/soft_glow_texture.gd")
const PillarOrbStaticLayerCache := preload("res://scripts/hud/pillar_orb_static_layer_cache.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

# The legacy generated attack sheet uses 344x384 cells and fills most of each cell.
# Python's Smasher renderer uses a 250x120 character surface whose visible body
# is roughly 90-100 px tall, so the attack sheet must be drawn much smaller
# than its source cell size to keep the body read consistent.
const DEFAULT_PLAYER_ATTACK_DRAW_SIZE := Vector2(128.0, 143.0)
const DEFAULT_PLAYER_DIRECTIONAL_ATTACK_DRAW_SIZE := Vector2(160.0, 160.0)
const DEFAULT_PLAYER_COMMANDO_ATTACK_DRAW_SIZE := Vector2(160.0, 160.0)
const DEFAULT_PLAYER_DIRECTIONAL_WALK_DRAW_SIZE := Vector2(160.0, 160.0)
const DEFAULT_PLAYER_DIRECTIONAL_DASH_DRAW_SIZE := Vector2(160.0, 160.0)
const DEFAULT_PLAYER_IDLE_BACK_DRAW_SIZE := Vector2(160.0, 160.0)
const DEFAULT_PLAYER_VICTORY_DRAW_SIZE := Vector2(160.0, 160.0)
const DEFAULT_PLAYER_DEFEAT_DRAW_SIZE := Vector2(160.0, 160.0)
const DEFAULT_PLAYER_WHEEL_SPIN_DRAW_SIZE := Vector2(160.0, 160.0)
const DEFAULT_PLAYER_COMMANDO_RADIO_CALL_DRAW_SIZE := Vector2(160.0, 160.0)
# Commando pistol-fire dest rect. The v4 sheet is standardized to
# 640x320 / cell 160x160 with body height ~100 px (idle-anchor matched),
# so the dest rect matches idle/walk at 160x160. Previous 80x107 dest was
# needed for the legacy v3 sheet (1264x848 / cell 316x424) where the
# raised pistol pose required a tall cell — replaced by the standardized
# v4 layout where the chibi body is already pre-fit to 100 px / feet at
# y=153 in source, identical to all other commando sheets.
const DEFAULT_PLAYER_PISTOL_FIRE_DRAW_SIZE := Vector2(160.0, 160.0)
const VIPER_DUAL_GLITCH_SPAWN_FRAMES := 22.8
const VIPER_DUAL_GLITCH_FADE_FRAMES := 18.0
const VIPER_DUAL_GLITCH_EVAPORATION_FRAMES := 13.2
const VIPER_DUAL_GLITCH_ALPHA := 0.63
const VIPER_DUAL_GLITCH_WIGGLE_AMPLITUDE := 3.0
# 원본 VIPER_DUAL_GLITCH_WIGGLE_HZ = 12.0 — startup 동안 본체 렌더 rect만 ±3px / 12Hz 좌우 흔들림.
const VIPER_DUAL_GLITCH_STARTUP_WIGGLE_HZ := 12.0
# 원본 chromatic split: active ±2px, spawn 동안 ~10px까지 확장 후 수렴. + spawn 에코 잔상 3개.
const VIPER_DUAL_GLITCH_SPLIT_BASE_SHIFT := 2.0
const VIPER_DUAL_GLITCH_SPAWN_ECHO_COUNT := 3
const VIPER_DUAL_GLITCH_TIMEOUT_DISPEL_SLICE_COUNT := 8
const VIPER_DUAL_GLITCH_TIMEOUT_DISPEL_PARTICLE_COUNT := 16
const VIPER_DUAL_GLITCH_RGB_SPLIT: Array[Color] = [
	Color(1.0, 0.275, 0.471),
	Color(0.275, 1.0, 0.588),
	Color(0.275, 0.706, 1.0),
]
const PLAYER_GROUND_SHADOW_BASE_WIDTH := 225.0
const PLAYER_GROUND_SHADOW_BASE_HEIGHT := 22.0
const PLAYER_GROUND_SHADOW_ALPHA := 0.26
const PLAYER_GROUND_SHADOW_HOVER_ALPHA_BONUS := 0.06

# ── 신령환(aipill) = 호신령 빙의 상태 ────────────────────────────────────────
# 구 연출은 시안 스캔라인 글리치 + 사이버 시스템 라벨이었다(PingFighter
# 잔재). 환격전 리브랜딩 이후 이 아이템의 픽션은 "호신령이 몸을 대신 움직여
# 자동 가드한다"이므로, 어휘를 무속 강신(降神)으로 전면 교체한다.
# 구 라벨 문자열의 부활은 aipill_possession_visual_smoke 가 막는다.
#
# 팔레트 규칙: 청록/시안은 절대 쓰지 않는다 — 옥빛은 플레이어 소켓 글로우와
# 코요라(무녀 링펫)가 이미 점유 중이라 어휘가 충돌한다. 금/백금/주사 3색만.
const POSSESSION_SPIRIT_CORE := Color(1.000, 0.965, 0.860)
const POSSESSION_SPIRIT_HALO := Color(0.900, 0.780, 0.440)
const POSSESSION_TALISMAN_PAPER := Color(0.880, 0.790, 0.550)
const POSSESSION_CINNABAR := Color(0.940, 0.100, 0.055)
const POSSESSION_CINNABAR_DARK := Color(0.170, 0.012, 0.008)
const POSSESSION_INK := Color(0.090, 0.085, 0.075)
const POSSESSION_UNDER_SHADOW := Color(0.060, 0.050, 0.040, 0.55)
const POSSESSION_LEAD_AFTERIMAGE := Color(0.980, 0.840, 0.460)
# 드로우 슬롯 상한 — 상시-가시성 절차 드로우 회귀 방지용 봉인 대상 상수.
const _POSSESSION_MOTE_SLOT_COUNT := 2
const _POSSESSION_FLASH_MERIDIAN_COUNT := 2
const _POSSESSION_BACKPLATE_LAYER_COUNT := 1
# 머리 위 상태 라벨. 구 사이버 시스템 라벨을 대체하며 LanguageSettings로 번역된다.
const POSSESSION_LABEL_TEXT := "호신령 빙의"
const POSSESSION_LABEL_FONT_SIZE := 12
# 부적 슬립 / 주사 낙관 베이크. 키에 연속 float(호흡·스케일)을 넣지 말 것 —
# MAX_CACHE_ENTRIES(24) 초과 시 캐시 전체가 flush된다.
const POSSESSION_TALISMAN_CACHE_KEY := "possession_talisman:v1"
const POSSESSION_SEAL_CACHE_KEY := "possession_seal:v1"
# 베이크는 고해상도로 굽고 축소해 그린다(다운스케일 = crisp). 부적은 픽셀 QA
# 1차에서 "머리를 덮는 포스터"로 읽혀 0.5 → 0.34 로 줄였다.
const POSSESSION_TALISMAN_DRAW_SCALE := 0.34
const POSSESSION_SEAL_DRAW_SCALE := 0.5
# 선행 잔상: 프레임 간 x 델타가 이보다 크게 튀면 라운드 리셋/텔레포트로 보고
# 자기치유(0으로 리셋)한다. 라운드 리셋 훅에 의존하지 않기 위한 안전장치.
const POSSESSION_LEAD_TELEPORT_PX := 60.0

var sprite_renderer: Object = Stage1PlayerSpriteRenderer.new()
var dash_side_gauge_renderer: Object = Stage1DashSideGaugeRenderer.new()
var horn_strawberry_paddle_renderer: Object = HornStrawberryPaddleRenderer.new()
var odins_eye_presentation_renderer: Object = OdinsEyePresentationRenderer.new()
var _state_glow_renderer: Object = PlayerStateGlowRenderer.new()
var status_overlay_renderer: Object = StatusEffectOverlayRenderer.new()
var _possession_layer_cache: Object = PillarOrbStaticLayerCache.new()
var _possession_plan: Dictionary = {}
var _possession_lead_prev_x := 0.0
var _possession_lead_valid := false
var _prewarm_step_index := 0


func prewarm_runtime_assets() -> void:
	while not prewarm_runtime_assets_step():
		pass


func prewarm_runtime_assets_step() -> bool:
	match _prewarm_step_index:
		0:
			ImpactFlareTextureCache.get_glow_texture()
		1:
			ImpactFlareTextureCache.get_burst_texture()
		2:
			ImpactFlareTextureCache.get_sparkle_texture()
		3:
			ImpactShockwaveTextureCache.get_full_ring_texture()
		4:
			ImpactShockwaveTextureCache.get_wall_ring_texture("left")
		5:
			ImpactShockwaveTextureCache.get_wall_ring_texture("right")
		6:
			if sprite_renderer != null and sprite_renderer.has_method("prewarm_runtime_assets_step"):
				if not bool(sprite_renderer.prewarm_runtime_assets_step()):
					return false
			elif sprite_renderer != null and sprite_renderer.has_method("prewarm_runtime_assets"):
				sprite_renderer.prewarm_runtime_assets()
		7:
			if _state_glow_renderer != null:
				_state_glow_renderer.prewarm()
		8:
			# 신령환 빙의 정적 스택은 여기서 굽는다. 드로우 경로에서 처음
			# 만들면 발동 프레임에 콜드 래스터가 통째로 얹힌다
			# (Godot Hot-Path Lazy Init Trap).
			SoftGlowTexture.get_texture(128)
		9:
			if _possession_layer_cache != null:
				_possession_layer_cache.build_now(
					POSSESSION_TALISMAN_CACHE_KEY, _build_possession_talisman_ops()
				)
		10:
			if _possession_layer_cache != null:
				_possession_layer_cache.build_now(
					POSSESSION_SEAL_CACHE_KEY, _build_possession_seal_ops()
				)
		_:
			_prewarm_step_index = 0
			return true
	_prewarm_step_index += 1
	return false


func clear_transient_canvas_items() -> void:
	if sprite_renderer != null and sprite_renderer.has_method("clear_transient_canvas_items"):
		sprite_renderer.clear_transient_canvas_items()


# 오딘의 눈 변신/부활/사망/잔상 시각은 detached FX 호스트(z=620, 플레이필드
# 클립)에 그린다. 활성 전환은 호스트를 부착·싱크하고, 비활성 전환은 명시
# set_active(false)로 즉시 숨긴다(호스트 스스로는 오버레이 종료를 모른다 —
# clear 없는 스테일 잔상 방지). 셰이크는 컨텍스트의 단일 샘플
# screen_shake_offset을 우선한다(호출부마다 재샘플하면 셰이크가 찢어진다).
func _sync_odins_eye_overlay_host(
	canvas: CanvasItem,
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> void:
	if canvas == null:
		return
	var odins_context: Dictionary = _as_dictionary(context.get("odins_eye_context", {}))
	var host: Node = canvas.get_node_or_null("OdinsEyePresentationFxHost")
	if not _is_odins_eye_overlay_active(odins_context):
		if host != null and host.has_method("set_active"):
			host.set_active(false)
		return
	if host == null:
		host = OdinsEyePresentationFxHost.new()
		host.name = "OdinsEyePresentationFxHost"
		canvas.add_child(host)
	var effective_shake: Vector2 = shake_offset
	var context_shake: Variant = context.get("screen_shake_offset", null)
	if context_shake is Vector2:
		effective_shake = context_shake
	host.sync_state(
		_build_odins_eye_host_context(context, odins_context),
		player_pos,
		paddle_size,
		effective_shake,
		{
			"game_offset": _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO),
			"render_scale": float(context.get("render_scale", 1.0)),
		}
	)


# 오버레이 호스트 활성 판정: 부활/사망 시네마틱과 잔상·다이브 payload가
# 대상이다. transformed 단독으로는 켜지 않는다 — 변신 몸체는 플레이어
# 드로우 스왑이 그리고, 이 호스트는 시네마틱·잔상 전용이라 빈 payload에
# 호스트를 켜 두면 매 프레임 공회전한다. 반대로 폼이 꺼진 뒤에도 payload가
# 남아 있으면 페이드를 계속 그려야 한다(payload 누락="오버레이 안 그려짐"
# 회귀 클래스).
# 호스트에 넘길 최소 context 스냅샷. 호스트는 매 렌더 프레임 이 dict를
# duplicate(true)하므로 전체 actor context(기본 리터럴 308개+stage/item/
# status 병합 트리)를 넘기면 가시 VFX hot _draw() 경로에 대형 할당 회귀가
# 된다 — 렌더러가 최상위 폴백으로 실제 조회하는 키만 담는다(sub-context에
# 이미 있는 death_*/revival_*/afterimage는 제외).
const ODINS_EYE_HOST_CONTEXT_TOP_KEYS: Array[String] = [
	"player_speed",
	"player_anim_clock",
	"player_paddle_scale",
	"render_time_sec",
	"animation_time_sec",
]


func _build_odins_eye_host_context(context: Dictionary, odins_context: Dictionary) -> Dictionary:
	var host_context := {"odins_eye_context": odins_context}
	for key in ODINS_EYE_HOST_CONTEXT_TOP_KEYS:
		if context.has(key):
			host_context[key] = context[key]
	return host_context


# 변신 본체 스와프 판정: 변신 유지(transformed) 중과 부활/사망 시네마틱
# 중에는 일반 캐릭터 스프라이트 대신 오딘 본체 경로가 그린다(부활 중에는
# draw_player의 plan이 몸을 숨기고 시네마틱이 공개를 소유). 잔상 payload
# 단독으로는 스와프하지 않는다 — 그건 오버레이 호스트 몫이다.
func _is_odins_eye_body_swap_active(odins_context: Dictionary) -> bool:
	if odins_context.is_empty():
		return false
	return (
		bool(odins_context.get("transformed", odins_context.get("penalty_active", false)))
		or bool(odins_context.get("revival_animation_active", false))
		or bool(odins_context.get("death_animation_active", false))
	)


func _is_odins_eye_overlay_active(odins_context: Dictionary) -> bool:
	if odins_context.is_empty():
		return false
	if bool(odins_context.get("revival_animation_active", false)):
		return true
	if bool(odins_context.get("death_animation_active", false)):
		return true
	var afterimage_context: Dictionary = _as_dictionary(odins_context.get("afterimage", {}))
	if bool(afterimage_context.get("dive_active", false)):
		return true
	for payload_key in ["afterimages", "soul_particles", "ambient_particles", "trail", "ground_cracks", "ground_ripples", "burst_particles"]:
		var payload_value: Variant = afterimage_context.get(payload_key, null)
		if payload_value is Array and not (payload_value as Array).is_empty():
			return true
	return false


func draw(
	canvas: CanvasItem,
	context: Dictionary,
	shake_offset: Vector2,
	perf_logger: Object = null
) -> void:
	# Draw the lingpet BODY (egg / companion) behind the player. The battle scene drawer
	# injects this hook into the actor context; running it here (after the opaque stage
	# background, before the player sprite) makes an overlapping lingpet render behind the
	# player. Runs BEFORE the player-hidden early returns below (intro hologram / ghost
	# possession) so the lingpet never vanishes while the paddle is hidden.
	var lingpet_body_hook: Variant = context.get("lingpet_body_draw", null)
	var lingpet_body_hook_valid: bool = lingpet_body_hook is Callable and (lingpet_body_hook as Callable).is_valid()
	# 목말 탑승: while mounted the companion renders IN FRONT of the rider so
	# his head / raised hands cover her seat (shoulder-ride read) -- defer the
	# body hook to after the player sprite. Unmounted keeps behind-player order.
	var defer_lingpet_body: bool = _is_lingpet_body_deferred(context)
	if lingpet_body_hook_valid and not defer_lingpet_body:
		(lingpet_body_hook as Callable).call(canvas)
	if sprite_renderer != null and sprite_renderer.has_method("clear_transient_canvas_items"):
		sprite_renderer.clear_transient_canvas_items()
	# 오딘의 눈 오버레이 호스트 싱크는 플레이어-숨김 얼리리턴(인트로 홀로그램/
	# 고스트 빙의)보다 먼저 실행돼야 한다 — 얼리리턴 뒤에 두면 인트로 동안
	# 호스트가 싱크되지 않아 스테일 프레임(정지 스파이크 잔상)이 화면에 남는다.
	_sync_odins_eye_overlay_host(
		canvas,
		context,
		_as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO),
		_as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0)),
		shake_offset
	)
	# Ball-spawn-intro paddle hologram gate. Mirrors Python's
	# `get_paddle_hologram_state()`: the player paddle is fully hidden until
	# the materialize window opens, then renders through a glitch reveal.
	if not bool(context.get("paddle_hologram_should_draw", true)):
		if lingpet_body_hook_valid and defer_lingpet_body:
			(lingpet_body_hook as Callable).call(canvas)
		return
	# Ghost-smashing possession: Mika is sucked into the ball, so hide the field
	# paddle entirely (sprite + shadow) while she rides it. When the boss returns
	# the ball she leaves the RIDING phase, this gate falls through, and the
	# paddle draws normally again at the live position.
	if bool(context.get("ghost_possession_paddle_hidden", false)):
		if lingpet_body_hook_valid and defer_lingpet_body:
			(lingpet_body_hook as Callable).call(canvas)
		return
	var pillar_drawer = context.get("pillar_drawer", null)
	var player_pos: Vector2 = _as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO)
	var warp_gate_visual_offset_x: float = float(context.get(
		"warp_gate_player_visual_offset_x",
		context.get("warp_gate_mirror_offset_x", 0.0)
	))
	player_pos.x += warp_gate_visual_offset_x
	var ghost_possession_player_override: Dictionary = _as_dictionary(context.get("ghost_possession_player_override", {}))
	var ghost_possession_alpha: float = 1.0
	if not ghost_possession_player_override.is_empty():
		var ghost_from: Vector2 = _as_vector2(ghost_possession_player_override.get("from", player_pos), player_pos)
		var ghost_t: float = clampf(float(ghost_possession_player_override.get("t", 1.0)), 0.0, 1.0)
		ghost_possession_alpha = clampf(float(ghost_possession_player_override.get("alpha", 1.0)), 0.0, 1.0)
		player_pos = ghost_from.lerp(player_pos, ghost_t)
	var paddle_size: Vector2 = _as_vector2(context.get("player_paddle_size", Vector2(84.0, 16.0)), Vector2(84.0, 16.0))
	var player_speed: float = float(context.get("player_speed", 0.0))
	var dash_active: bool = bool(context.get("dash_active", false))
	var dash_recovering: bool = bool(context.get("dash_recovering", false))
	var player_move_active: bool = abs(player_speed) > 0.2 or dash_active
	var viper_airborne: bool = bool(context.get("viper_jetpack_airborne", false))
	if viper_airborne:
		player_move_active = false
	var player_victory_active: bool = bool(context.get("player_victory_active", false))
	var player_defeat_active: bool = bool(context.get("player_defeat_active", false))
	var player_wheel_spin_active: bool = bool(context.get("player_wheel_spin_active", false))
	var player_result_active: bool = player_victory_active or player_defeat_active
	if player_result_active:
		player_move_active = false
	elif player_wheel_spin_active:
		player_move_active = false
	var smasher_body_motion: bool = _uses_smasher_body_motion(context)
	var player_anim_clock: float = float(context.get("player_anim_clock", 0.0))
	var hover_amplitude: float = _get_player_hover_amplitude(context)
	var hover_wave: float = sin(player_anim_clock * float(context.get("player_hover_speed", 4.5)))
	var hover_offset: float = hover_wave * hover_amplitude
	var move_bob: float = 0.0
	var breath_wave: float = 0.0
	var player_draw_size: Vector2 = _as_vector2(context.get("player_sprite_draw_size", Vector2(250.0, 120.0)), Vector2(250.0, 120.0))
	var hit_active: bool = bool(context.get("player_hit_active", false))
	if player_victory_active:
		player_draw_size = _as_vector2(
			context.get("player_victory_draw_size", DEFAULT_PLAYER_VICTORY_DRAW_SIZE),
			DEFAULT_PLAYER_VICTORY_DRAW_SIZE
		)
	elif player_defeat_active:
		player_draw_size = _as_vector2(
			context.get("player_defeat_draw_size", DEFAULT_PLAYER_DEFEAT_DRAW_SIZE),
			DEFAULT_PLAYER_DEFEAT_DRAW_SIZE
		)
	elif player_wheel_spin_active:
		player_draw_size = _as_vector2(
			context.get("player_wheel_spin_draw_size", DEFAULT_PLAYER_WHEEL_SPIN_DRAW_SIZE),
			DEFAULT_PLAYER_WHEEL_SPIN_DRAW_SIZE
		)
	var idle_sheet_active: bool = (
		not player_move_active
		and not hit_active
		and not player_result_active
		and int(context.get("player_idle_grid_cols", 1)) > 1
		and int(context.get("player_idle_grid_rows", 1)) > 1
	)
	if idle_sheet_active:
		player_draw_size = _as_vector2(
			context.get("player_idle_draw_size", DEFAULT_PLAYER_IDLE_BACK_DRAW_SIZE),
			DEFAULT_PLAYER_IDLE_BACK_DRAW_SIZE
		)
	if bool(context.get("dash_active", false)) and not hit_active and not player_result_active and _has_directional_dash_texture(context):
		player_draw_size = _as_vector2(
			context.get("player_directional_dash_draw_size", DEFAULT_PLAYER_DIRECTIONAL_DASH_DRAW_SIZE),
			DEFAULT_PLAYER_DIRECTIONAL_DASH_DRAW_SIZE
		)
	elif player_move_active and not hit_active and not player_result_active and _has_directional_walk_texture(context):
		player_draw_size = _as_vector2(
			context.get("player_directional_walk_draw_size", DEFAULT_PLAYER_DIRECTIONAL_WALK_DRAW_SIZE),
			DEFAULT_PLAYER_DIRECTIONAL_WALK_DRAW_SIZE
		)
	# The legacy attack sheet is authored at a much larger source scale than the
	# exported walk/idle strips. Draw it at a normalized size instead of letting
	# the 344x384 source cell become a giant player sprite.
	if hit_active and not player_result_active:
		player_draw_size = _get_player_hit_draw_size(context, player_draw_size)
	# Commando weapon-fire overrides use per-weapon authored sheets where the
	# weapon, hands, arms, and body pose are drawn together. They win over
	# pistol-fire / hit / idle / walk while their trigger window is active.
	if bool(context.get("commando_weapon_fire_active", false)) and not player_result_active:
		player_draw_size = _as_vector2(
			context.get("player_commando_weapon_fire_draw_size", DEFAULT_PLAYER_PISTOL_FIRE_DRAW_SIZE),
			DEFAULT_PLAYER_PISTOL_FIRE_DRAW_SIZE
		)
	# Commando pistol-fire override has the highest precedence over the
	# walk / idle / hit branches above so a player firing while moving or
	# bouncing the ball still gets the smaller pistol-fire dest rect. This
	# matches the sprite renderer's priority chain (pistol_fire wins over
	# hit / idle / walk).
	elif bool(context.get("commando_pistol_fire_active", false)) and not player_result_active:
		player_draw_size = _as_vector2(
			context.get("player_pistol_fire_draw_size", DEFAULT_PLAYER_PISTOL_FIRE_DRAW_SIZE),
			DEFAULT_PLAYER_PISTOL_FIRE_DRAW_SIZE
		)
	elif bool(context.get("commando_radio_call_active", false)) and not player_result_active:
		player_draw_size = _as_vector2(
			context.get("player_commando_radio_call_draw_size", DEFAULT_PLAYER_COMMANDO_RADIO_CALL_DRAW_SIZE),
			DEFAULT_PLAYER_COMMANDO_RADIO_CALL_DRAW_SIZE
		)
	# 착석 시트 채택은 패들 배율 **곱하기 직전**이다 — 배율은 두 경로가 공유한다.
	player_draw_size = _resolve_mount_seated_draw_size(context, player_draw_size)
	var player_paddle_scale: float = max(0.1, float(context.get("player_paddle_scale", max(1.0, paddle_size.x / 155.0))))
	player_draw_size *= player_paddle_scale
	var player_visual_x_offset: float = 0.0
	var throw_pose_active: bool = bool(context.get("active_item_throw_windup_active", false))
	var throw_pose_progress: float = clamp(float(context.get("active_item_throw_windup_progress", 0.0)), 0.0, 1.0)

	if player_move_active:
		move_bob = abs(sin(player_anim_clock * 10.0)) * _get_player_move_bob_amplitude(context)
	else:
		if smasher_body_motion and not player_wheel_spin_active:
			breath_wave = sin(player_anim_clock * 5.236)
			player_draw_size.x *= 1.0 - breath_wave * _get_player_idle_breath_scale_x(context)
			player_draw_size.y *= 1.0 + breath_wave * _get_player_idle_breath_scale_y(context)

	var player_visual_y_offset: float = -hover_offset - move_bob - (breath_wave * _get_player_idle_breath_y(context))
	# Wall-Leap Night Raid moves the physics paddle into the top boss lane. Keep
	# the authored 160px walk/attack body inside the playfield without moving its
	# collision rect; the runtime fades this offset smoothly during RETURN.
	player_visual_y_offset += float(context.get("viper_wall_leap_raid_visual_y_offset", 0.0))
	# 수호령 탑승: lift the whole rider sprite stack (body + socket glow +
	# perk parts follow automatically -- they anchor to this rect) onto the
	# mount's back. Visual only; the physics paddle stays grounded.
	player_visual_y_offset -= float(context.get("player_mount_rider_lift_px", 0.0))
	if hit_active and not player_result_active:
		var hit_progress: float = _get_player_hit_progress(
			float(context.get("player_hit_timer", 0.0)),
			float(context.get(
				"player_hit_effective_anim_duration",
				context.get("player_hit_anim_duration", 0.36)
			))
		)
		var hit_snap: float = 1.0 - _ease_out_cubic(pillar_drawer, hit_progress)
		var hit_rebound: float = _ease_in_out_sine(pillar_drawer, hit_progress) * (1.0 - hit_progress)
		player_visual_x_offset = float(context.get("player_hit_side", 1)) * (
			float(context.get("player_hit_lunge_x", 14.0)) * hit_snap - float(context.get("player_hit_rebound_x", 5.0)) * hit_rebound
		)
		player_visual_y_offset += -float(context.get("player_hit_lunge_y", 8.0)) * hit_snap + float(context.get("player_hit_rebound_y", 2.5)) * hit_rebound
		player_draw_size.x *= 1.0 + float(context.get("player_hit_scale_x", 0.055)) * hit_snap - float(context.get("player_hit_scale_x", 0.055)) * 0.35 * hit_rebound
		player_draw_size.y *= 1.0 - float(context.get("player_hit_scale_y", 0.045)) * hit_snap + float(context.get("player_hit_scale_y", 0.045)) * 0.4 * hit_rebound

	if dash_recovering:
		player_visual_x_offset += float(randi_range(-2, 2))
		player_visual_y_offset += float(randi_range(-1, 1))

	if throw_pose_active:
		player_visual_y_offset -= sin(throw_pose_progress * PI) * 5.0

	var altitude_ratio: float = clamp(float(context.get("viper_jetpack_altitude_ratio", 0.0)), 0.0, 1.0)
	var hover_shadow_ratio: float = 0.0
	if hover_amplitude > 0.001:
		hover_shadow_ratio = (hover_offset + hover_amplitude) / (hover_amplitude * 2.0)
	var shadow_scale: float = 1.0 - hover_shadow_ratio * 0.18
	shadow_scale *= lerp(1.0, 0.58, altitude_ratio)
	# 신령환 빙의: 신령이 몸을 들어 쓰는 동안 접지감을 뺀다. PLAYER_GROUND_SHADOW_*
	# 상수는 예산 씰이 범위를 봉인 중이므로 상수가 아니라 드로우 사이트에서만 곱한다.
	var possession_shadow_scale := 1.0
	var possession_shadow_alpha_scale := 1.0
	if bool(context.get("active_item_aipill_active", false)):
		possession_shadow_scale = 0.80 - 0.04 * possession_breath(float(Time.get_ticks_msec()))
		possession_shadow_alpha_scale = 0.62
	var shadow_width: float = PLAYER_GROUND_SHADOW_BASE_WIDTH * shadow_scale * possession_shadow_scale * max(1.0, player_paddle_scale)
	var shadow_height: float = PLAYER_GROUND_SHADOW_BASE_HEIGHT * shadow_scale * possession_shadow_scale * (0.82 + 0.18 * max(1.0, player_paddle_scale))
	var shadow_floor_y: float = float(context.get("viper_jetpack_floor_y", player_pos.y))
	var player_shadow_rect := Rect2(
		player_pos.x + paddle_size.x * 0.5 - shadow_width * 0.5 + shake_offset.x,
		shadow_floor_y + paddle_size.y - 6.0 + shake_offset.y,
		shadow_width,
		shadow_height
	)
	var sample_start: int = _perf_begin(perf_logger)
	if pillar_drawer != null and pillar_drawer.has_method("draw_soft_shadow_ellipse"):
		var shadow_alpha: float = (
			PLAYER_GROUND_SHADOW_ALPHA
			+ (1.0 - shadow_scale) * PLAYER_GROUND_SHADOW_HOVER_ALPHA_BONUS
		) * lerp(1.0, 0.62, altitude_ratio) * possession_shadow_alpha_scale
		pillar_drawer.draw_soft_shadow_ellipse(
			canvas,
			player_shadow_rect,
			Color(0.0, 0.0, 0.0, shadow_alpha)
		)
	_perf_end(perf_logger, "actors.stage1.player.shadow", sample_start)

	var player_visual_rect := Rect2(
		player_pos.x + paddle_size.x * 0.5 - player_draw_size.x * 0.5 + shake_offset.x + player_visual_x_offset,
		player_pos.y + paddle_size.y - player_draw_size.y + 12.0 + shake_offset.y + player_visual_y_offset,
		player_draw_size.x,
		player_draw_size.y
	)
	# 원본 _get_viper_dual_glitch_startup_offset_px(): startup 동안 실제 위치는 고정하고
	# 본체 렌더 rect만 ±3px / 12Hz 좌우로 흔든다. (clones / 물리 위치에는 미적용)
	player_visual_rect = apply_dual_glitch_startup_body_wiggle(player_visual_rect, context)
	var player_slow_ratio: float = clamp(float(context.get("status_player_slow_ratio", 0.0)), 0.0, 1.0)
	var player_slow_active: bool = bool(context.get("status_player_slow_active", false)) or player_slow_ratio > 0.001
	if player_slow_active and player_slow_ratio <= 0.001:
		player_slow_ratio = 1.0
	var curse_reverse_ratio: float = clamp(float(context.get("stage3_curse_reverse_ratio", 0.0)), 0.0, 1.0)
	var curse_reverse_active: bool = bool(context.get("stage3_curse_reverse_active", false)) or curse_reverse_ratio > 0.001
	if curse_reverse_active and curse_reverse_ratio <= 0.001:
		curse_reverse_ratio = 1.0
	# 신령환 빙의 플랜은 본체 스프라이트보다 먼저 필요하다(배경판이 뒤에 깔리고,
	# 본체 틴트 / 실루엣 림 오버라이드가 sprite_context 에 실려야 한다).
	var aipill_active: bool = bool(context.get("active_item_aipill_active", false))
	var possession_lead_dx: float = _advance_possession_lead_offset(
		aipill_active,
		player_visual_rect.get_center().x,
		clampf(player_visual_rect.size.y / 160.0, 0.60, 1.60)
	)
	_possession_plan = build_possession_plan(
		context,
		player_visual_rect,
		float(Time.get_ticks_msec()),
		_possession_lod_level(context),
		possession_lead_dx
	)
	var possession_active: bool = bool(_possession_plan.get("active", false))
	var sprite_context: Dictionary = context
	if throw_pose_active or curse_reverse_active or player_slow_active or possession_active or ghost_possession_alpha < 0.999:
		sprite_context = context.duplicate()
	if player_slow_active:
		sprite_context["player_sprite_modulate"] = _get_player_slow_sprite_modulate(player_slow_ratio)
	# 둔화 분기가 modulate 를 통째로 덮어쓰므로 빙의 틴트는 그 뒤에서 합류해야
	# 한다(저주 반전 / 고스트 알파와 같은 자리).
	if possession_active:
		sprite_context["player_sprite_modulate"] = _combine_modulate_colors(
			sprite_context.get("player_sprite_modulate", Color.WHITE),
			_as_color(_possession_plan.get("sprite_modulate", Color.WHITE), Color.WHITE)
		)
		sprite_context["stage1_player_rim_intensity"] = float(_possession_plan.get("rim_intensity", 0.65))
		sprite_context["stage1_player_rim_color"] = _as_color(
			_possession_plan.get("rim_color", POSSESSION_SPIRIT_CORE), POSSESSION_SPIRIT_CORE
		)
	if curse_reverse_active:
		sprite_context["player_sprite_modulate"] = _combine_modulate_colors(
			sprite_context.get("player_sprite_modulate", Color.WHITE),
			_get_curse_reverse_sprite_modulate(curse_reverse_ratio)
		)
	if ghost_possession_alpha < 0.999:
		sprite_context["player_sprite_modulate"] = _combine_modulate_colors(
			sprite_context.get("player_sprite_modulate", Color.WHITE),
			Color(1.0, 1.0, 1.0, ghost_possession_alpha)
		)
	if throw_pose_active:
		sprite_context["player_sprite_rotation_degrees"] = float(context.get("active_item_throw_windup_angle_degrees", 0.0))
	var paddle_hologram_active: bool = bool(context.get("paddle_hologram_active", false))
	var paddle_hologram_progress: float = float(context.get("paddle_hologram_progress", 1.0))
	var paddle_hologram_plan: Dictionary = {}
	var horn_strawberry_transformed: bool = bool(context.get("horn_strawberry_transformed", false))
	var horn_strawberry_event_playing: bool = bool(context.get("horn_strawberry_event_playing", false))
	var odins_eye_body_context: Dictionary = _as_dictionary(context.get("odins_eye_context", {}))
	var odins_eye_body_active: bool = _is_odins_eye_body_swap_active(odins_eye_body_context)
	if paddle_hologram_active:
		paddle_hologram_plan = PaddleHologramGlitchRenderer.compute_pass_plan(
			paddle_hologram_progress, Time.get_ticks_msec()
		)
		# A flicker beat: the entire paddle vanishes for this single frame.
		# Skip every effect layer too — the original pygame helper returns an
		# empty surface for these frames so nothing tied to the paddle draws.
		if bool(paddle_hologram_plan.get("flicker_hidden", false)):
			sample_start = _perf_begin(perf_logger)
			dash_side_gauge_renderer.draw(canvas, context, player_pos, paddle_size, shake_offset)
			_perf_end(perf_logger, "actors.stage1.player.dash_side_gauge", sample_start)
			return
	# §B-3 탑다운 M 베이스: 라이더 최종 rect 가 확정된 뒤, 상태 글로우 **앞**에
	# 깔린다(M 은 라이더 아래 · 글로우는 라이더 소유). flicker 프레임은 위에서
	# 이미 return 했으므로 패들과 함께 M 도 사라진다 — 숨김 계약 공유.
	_call_lingpet_mount_base_hook(canvas, context, player_visual_rect)
	sample_start = _perf_begin(perf_logger)
	if _state_glow_renderer != null:
		_state_glow_renderer.draw(canvas, player_visual_rect, context, Time.get_ticks_msec())
	_perf_end(perf_logger, "actors.stage1.player.state_glow", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_viper_jetpack_effects(canvas, context, shake_offset, player_visual_rect, player_pos, paddle_size)
	_perf_end(perf_logger, "actors.stage1.player.jetpack_fx", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_viper_hover_flame_embers(canvas, context, shake_offset, player_visual_rect)
	_perf_end(perf_logger, "actors.stage1.player.hover_embers", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_possession_backplate(canvas, _possession_plan)
	_perf_end(perf_logger, "actors.stage1.player.possession_back", sample_start)
	sample_start = _perf_begin(perf_logger)
	var drawn_player_visual_rect: Rect2 = player_visual_rect
	if odins_eye_body_active:
		# 변신 몸체는 일반 캐릭터 스프라이트를 대체한다(혼딸기 스와프 형제).
		# 부활 연출 중에는 draw_player가 plan(draw_player=false)으로 몸을
		# 그리지 않고 시네마틱(오버레이 호스트)이 공개를 소유한다 — 일반
		# 스프라이트도 함께 숨겨야 원본 hide_paddle 계약과 일치한다.
		# 전체 actor context를 넘긴다 — 렌더러의 _value는 odins 하위 컨텍스트를
		# 우선 조회하고 player_speed/player_anim_clock 같은 최상위 키로 폴백한다.
		drawn_player_visual_rect = odins_eye_presentation_renderer.draw_player(
			canvas,
			context,
			player_pos,
			paddle_size,
			shake_offset
		)
	elif horn_strawberry_transformed:
		var horn_context: Dictionary = _as_dictionary(context.get("horn_strawberry_context", {}))
		var horn_charge_context: Dictionary = _as_dictionary(horn_context.get("horn_charge", {}))
		var horn_charge_offset: Vector2 = _as_vector2(horn_charge_context.get("current_offset", Vector2.ZERO), Vector2.ZERO)
		drawn_player_visual_rect = horn_strawberry_paddle_renderer.draw(
			canvas,
			context,
			player_pos,
			paddle_size,
			shake_offset,
			1.0,
			horn_charge_offset
		)
	elif paddle_hologram_active:
		_draw_player_with_hologram_passes(
			canvas,
			sprite_context,
			player_visual_rect,
			player_move_active,
			player_pos,
			paddle_size,
			shake_offset,
			paddle_hologram_plan
		)
	else:
		_draw_possession_lead_afterimage(
			canvas,
			_possession_plan,
			sprite_context,
			player_visual_rect,
			player_move_active,
			player_pos,
			paddle_size,
			shake_offset
		)
		_draw_viper_dual_glitch_clone_sprites(
			canvas,
			sprite_context,
			player_visual_rect,
			player_move_active,
			player_pos,
			paddle_size,
			shake_offset
		)
		sprite_renderer.draw(
			canvas,
			sprite_context,
			player_visual_rect,
			player_move_active,
			player_pos,
			paddle_size,
			shake_offset
		)
	if not horn_strawberry_transformed and not horn_strawberry_event_playing and not odins_eye_body_active:
		_draw_commando_weapon_b2_overlay(canvas, sprite_context, player_visual_rect)
		_draw_commando_weapon_overlay(canvas, sprite_context, player_visual_rect, player_move_active)
	# Deferred shoulder-ride companion pass: mount body over the rider's lower
	# body, under status-effect overlays.
	if lingpet_body_hook_valid and defer_lingpet_body:
		(lingpet_body_hook as Callable).call(canvas)
	if curse_reverse_active:
		_draw_curse_reverse_head_effect(canvas, drawn_player_visual_rect, curse_reverse_ratio)
	if player_slow_active:
		_draw_player_slow_wave(canvas, drawn_player_visual_rect, player_slow_ratio)
	if possession_active:
		sample_start = _perf_begin(perf_logger)
		_draw_possession_overlay(canvas, _possession_plan)
		_perf_end(perf_logger, "actors.stage1.player.possession_front", sample_start)
	if horn_strawberry_event_playing:
		# Python parity: transform/detransform events HIDE the normal paddle
		# (_horn_strawberry_hide_paddle = is_transformed OR is_event_playing).
		# During the first 35% of the transform event the REAL character sprite
		# slowly floats up (-80px, ease-out) like the original's captured paddle
		# snapshot; after that the cinematic's strawberry energy owns the screen.
		var horn_event_context: Dictionary = _as_dictionary(context.get("horn_strawberry_context", {}))
		var rise_offset: Vector2 = horn_strawberry_event_sprite_rise_offset(horn_event_context)
		if rise_offset.is_finite():
			var risen_rect := Rect2(player_visual_rect.position + rise_offset, player_visual_rect.size)
			sprite_renderer.draw(
				canvas,
				sprite_context,
				risen_rect,
				player_move_active,
				player_pos + rise_offset,
				paddle_size,
				shake_offset
			)
		status_overlay_renderer.draw_player_status_overlays(
			canvas,
			context,
			player_pos,
			paddle_size,
			drawn_player_visual_rect,
			shake_offset
		)
	elif status_overlay_renderer != null and status_overlay_renderer.has_method("draw_player_status_overlays"):
		# Normal state (no horn cinematic): draw the player status overlays on top
		# of the already-drawn sprite. Restores the `if` body lost in the committed
		# WIP; horn now takes priority (the status-first ordering skipped horn).
		status_overlay_renderer.draw_player_status_overlays(
			canvas,
			context,
			player_pos,
			paddle_size,
			drawn_player_visual_rect,
			shake_offset
		)
	_perf_end(perf_logger, "actors.stage1.player.sprite_stack", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_viper_air_strike_flash(canvas, context, shake_offset)
	_perf_end(perf_logger, "actors.stage1.player.air_strike_flash", sample_start)
	sample_start = _perf_begin(perf_logger)
	_draw_viper_jetpack_hold_bar(canvas, context, player_pos, paddle_size, shake_offset)
	_perf_end(perf_logger, "actors.stage1.player.hold_bar", sample_start)
	sample_start = _perf_begin(perf_logger)
	dash_side_gauge_renderer.draw(canvas, context, player_pos, paddle_size, shake_offset)
	_perf_end(perf_logger, "actors.stage1.player.dash_side_gauge", sample_start)
	if paddle_hologram_active and not horn_strawberry_transformed and not horn_strawberry_event_playing:
		# Scanlines / noise / edge-glow ride on top of the multi-pass sprite
		# so they read across the whole materializing silhouette, including
		# the cyan / magenta ghost halos.
		sample_start = _perf_begin(perf_logger)
		PaddleHologramGlitchRenderer.draw_overlays(canvas, player_visual_rect, paddle_hologram_plan)
		_perf_end(perf_logger, "actors.stage1.player.hologram_overlay", sample_start)


static func compute_dual_glitch_startup_wiggle_x(state: String, phase_frames: float) -> float:
	# 원본: wave = sin((elapsed_s) * tau * 12); offset = round(3 * wave). startup에서만.
	if state != "startup":
		return 0.0
	return roundf(VIPER_DUAL_GLITCH_WIGGLE_AMPLITUDE * sin((phase_frames / 60.0) * TAU * VIPER_DUAL_GLITCH_STARTUP_WIGGLE_HZ))


static func compute_dual_glitch_spawn_alpha_factor(phase_frames: float, spawn_frames: float = VIPER_DUAL_GLITCH_SPAWN_FRAMES) -> float:
	var progress: float = clamp(phase_frames / max(1.0, spawn_frames), 0.0, 1.0)
	var pulse_amp: float = pow(1.0 - progress, 0.7) * 0.7
	var pulse: float = abs(sin(progress * TAU * 2.0))
	return clamp(progress * (1.0 - pulse_amp * (1.0 - pulse)), 0.0, 1.0)


static func apply_dual_glitch_startup_body_wiggle(rect: Rect2, context: Dictionary) -> Rect2:
	var wiggle_x: float = compute_dual_glitch_startup_wiggle_x(
		str(context.get("viper_dual_glitch_state", "idle")),
		float(context.get("viper_dual_glitch_phase_frames", 0.0))
	)
	if wiggle_x != 0.0:
		rect.position += Vector2(wiggle_x, 0.0)
	return rect


static func compute_dual_glitch_spawn_progress(state: String, phase_frames: float, spawn_frames: float) -> float:
	if state != "spawn":
		return 1.0
	return clamp(phase_frames / max(1.0, spawn_frames), 0.0, 1.0)


static func compute_dual_glitch_split_shift(state: String, spawn_progress: float) -> float:
	# 원본: active=2px; spawn = 2 + (1-p)*8*(0.4 + 0.6*abs(sin(p*tau*2))).
	if state != "spawn":
		return VIPER_DUAL_GLITCH_SPLIT_BASE_SHIFT
	var wobble: float = abs(sin(spawn_progress * TAU * 2.0))
	return VIPER_DUAL_GLITCH_SPLIT_BASE_SHIFT + (1.0 - spawn_progress) * 8.0 * (0.4 + 0.6 * wobble)


static func compute_dual_glitch_split_alpha_boost(state: String, spawn_progress: float) -> float:
	# 원본: spawn 동안 split 고스트 알파 1 + (1-p)*0.6 부스트, active/fade=1.
	if state != "spawn":
		return 1.0
	return 1.0 + (1.0 - spawn_progress) * 0.6


static func compute_dual_glitch_echo_t(echo_idx: int, spawn_progress: float) -> float:
	return fmod(spawn_progress + float(echo_idx) * 0.22, 1.0)


static func compute_dual_glitch_echo_alpha(echo_idx: int, spawn_progress: float, base_alpha: float) -> float:
	# 원본: phase=(p+idx*0.22)%1; pulse=sin(phase*PI)^2; residual=(1-p)^0.6; a=ALPHA*0.42*pulse*residual.
	var echo_phase: float = compute_dual_glitch_echo_t(echo_idx, spawn_progress)
	var pulse: float = pow(sin(echo_phase * PI), 2.0)
	var residual: float = pow(max(0.0, 1.0 - spawn_progress), 0.6)
	return base_alpha * 0.42 * pulse * residual


static func compute_dual_glitch_steam_puff_alpha(puff_idx: int, evaporation_progress: float, base_alpha: float) -> float:
	# 원본: alpha = clone_alpha*(0.55 - idx*0.12)*(1-evap).
	return max(0.0, base_alpha * (0.55 - float(puff_idx) * 0.12) * (1.0 - evaporation_progress))


static func compute_dual_glitch_timeout_drift_y(fade_progress: float) -> float:
	return 6.0 + 18.0 * fade_progress


static func compute_dual_glitch_timeout_slice_alpha(slice_idx: int, fade_progress: float, clone_alpha: float) -> float:
	return max(0.0, clone_alpha * (0.85 - fade_progress * 0.55) * (1.0 - float(slice_idx) * 0.04))


static func compute_dual_glitch_timeout_slice_offset(slice_idx: int, clone_idx: int, side: int, fade_progress: float, tick_msec: float) -> Vector2:
	var drift_y: float = compute_dual_glitch_timeout_drift_y(fade_progress)
	var drift_x_base: float = float(side) * (2.0 + 5.0 * fade_progress)
	var wave: float = sin(tick_msec * 0.028 + float(slice_idx) * 1.17 + float(clone_idx) * 0.73)
	return Vector2(
		drift_x_base + wave * (2.0 + 8.0 * fade_progress),
		(float(slice_idx) - 3.0) * 0.8 * fade_progress - drift_y
	)


static func compute_dual_glitch_timeout_ghost_alpha(fade_progress: float, clone_alpha: float) -> float:
	return max(10.0 / 255.0, clone_alpha * (0.18 + 0.08 * (1.0 - fade_progress)))


static func compute_dual_glitch_timeout_ghost_offset(side_sign: int, fade_progress: float) -> Vector2:
	var drift_y: float = compute_dual_glitch_timeout_drift_y(fade_progress)
	var sign_value: float = -1.0 if side_sign < 0 else 1.0
	var x_offset: float = sign_value * (2.0 + 4.0 * fade_progress)
	var y_divisor: float = 2.0 if side_sign < 0 else 3.0
	return Vector2(x_offset, -floor(drift_y / y_divisor) - drift_y)


static func _dual_glitch_split_modulate(color: Color, alpha: float) -> Color:
	return Color(lerp(color.r, 1.0, 0.25), lerp(color.g, 1.0, 0.25), lerp(color.b, 1.0, 0.25), alpha)


static func _dual_glitch_echo_modulate(color: Color, alpha: float) -> Color:
	return Color(lerp(color.r, 1.0, 0.3), lerp(color.g, 1.0, 0.3), lerp(color.b, 1.0, 0.3), alpha)


func _draw_viper_dual_glitch_clone_sprites(
	canvas: CanvasItem,
	sprite_context: Dictionary,
	player_visual_rect: Rect2,
	player_move_active: bool,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> void:
	var clone_draws: Array = build_viper_dual_glitch_clone_sprite_draws(
		sprite_context,
		player_visual_rect,
		player_move_active,
		player_pos,
		paddle_size,
		shake_offset
	)
	for draw_value in clone_draws:
		if not (draw_value is Dictionary):
			continue
		var draw_info: Dictionary = draw_value
		if bool(draw_info.get("steam_puff", false)):
			_draw_dual_glitch_steam_puff(canvas, draw_info)
			continue
		if bool(draw_info.get("timeout_dispel", false)):
			_draw_dual_glitch_timeout_dispel(canvas, draw_info, sprite_context, player_move_active, paddle_size, shake_offset)
			continue
		var clone_visual_rect: Rect2 = draw_info.get("visual_rect", Rect2())
		var clone_pos: Vector2 = _as_vector2(draw_info.get("player_pos", player_pos), player_pos)
		var ghost_shift_x: float = float(draw_info.get("ghost_shift_x", VIPER_DUAL_GLITCH_SPLIT_BASE_SHIFT))
		# 에코 잔상(spawn 전용): 메인/스플릿 뒤에 먼저 그려 플레이어 -> 클론으로 미끄러지는 고스트.
		for echo_value in draw_info.get("echoes", []):
			if not (echo_value is Dictionary):
				continue
			var echo: Dictionary = echo_value
			var echo_rect: Rect2 = echo.get("rect", clone_visual_rect)
			var echo_context: Dictionary = _build_viper_dual_glitch_clone_sprite_context(
				sprite_context,
				_as_color(echo.get("modulate", Color.WHITE), Color.WHITE)
			)
			sprite_renderer.draw(
				canvas,
				echo_context,
				echo_rect,
				player_move_active,
				clone_pos,
				paddle_size,
				shake_offset
			)
		# 원본 chromatic split: 왼쪽 핑크(RGB_SPLIT[0]) / 오른쪽 블루(RGB_SPLIT[2]).
		var left_split_context: Dictionary = _build_viper_dual_glitch_clone_sprite_context(
			sprite_context,
			_as_color(draw_info.get("left_split_modulate", Color.WHITE), Color.WHITE)
		)
		sprite_renderer.draw(
			canvas,
			left_split_context,
			Rect2(clone_visual_rect.position + Vector2(-ghost_shift_x, 0.0), clone_visual_rect.size),
			player_move_active,
			clone_pos,
			paddle_size,
			shake_offset
		)
		var right_split_context: Dictionary = _build_viper_dual_glitch_clone_sprite_context(
			sprite_context,
			_as_color(draw_info.get("right_split_modulate", Color.WHITE), Color.WHITE)
		)
		sprite_renderer.draw(
			canvas,
			right_split_context,
			Rect2(clone_visual_rect.position + Vector2(ghost_shift_x, 0.0), clone_visual_rect.size),
			player_move_active,
			clone_pos,
			paddle_size,
			shake_offset
		)
		var main_context: Dictionary = _build_viper_dual_glitch_clone_sprite_context(
			sprite_context,
			_as_color(draw_info.get("main_modulate", Color.WHITE), Color.WHITE)
		)
		sprite_renderer.draw(
			canvas,
			main_context,
			clone_visual_rect,
			player_move_active,
			clone_pos,
			paddle_size,
			shake_offset
		)


func _draw_dual_glitch_steam_puff(canvas: CanvasItem, draw_info: Dictionary) -> void:
	# 원본 분신 파괴 증발: 흰/보라/청록 퍼프 3개가 떠오르며 줄어들고 페이드.
	var evap: float = float(draw_info.get("evaporation_progress", 0.0))
	var center: Vector2 = _as_vector2(draw_info.get("clone_center", Vector2.ZERO), Vector2.ZERO)
	var size: Vector2 = _as_vector2(draw_info.get("clone_size", Vector2(160.0, 160.0)), Vector2(160.0, 160.0))
	var base_alpha: float = float(draw_info.get("base_alpha", VIPER_DUAL_GLITCH_ALPHA))
	var idx: int = int(draw_info.get("clone_index", 0))
	var steam_h: float = max(18.0, size.y * 0.72)
	var tick: float = float(Time.get_ticks_msec())
	var center_y_local: float = steam_h * (0.62 - evap * 0.18)
	var puff_colors: Array[Color] = [Color(1.0, 1.0, 1.0), Color(0.765, 0.471, 1.0), Color(0.471, 1.0, 0.824)]
	for puff_idx in range(puff_colors.size()):
		var alpha: float = compute_dual_glitch_steam_puff_alpha(puff_idx, evap, base_alpha)
		if alpha <= 0.0:
			continue
		var radius: float = max(4.0, (steam_h * (0.16 + float(puff_idx) * 0.05)) * (1.0 - evap * 0.4))
		var px: float = center.x + sin((float(idx) + float(puff_idx)) * 0.9 + tick * 0.01) * (6.0 + float(puff_idx) * 4.0)
		var py: float = center.y - steam_h * 0.5 + center_y_local - float(puff_idx) * 6.0 - evap * 10.0
		var c: Color = puff_colors[puff_idx]
		canvas.draw_circle(Vector2(px, py), radius, Color(c.r, c.g, c.b, alpha))


func _draw_dual_glitch_timeout_dispel(
	canvas: CanvasItem,
	draw_info: Dictionary,
	sprite_context: Dictionary,
	player_move_active: bool,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> void:
	var visual_rect: Rect2 = draw_info.get("visual_rect", Rect2())
	var clone_pos: Vector2 = _as_vector2(draw_info.get("player_pos", visual_rect.position), visual_rect.position)
	for ghost_value in draw_info.get("ghosts", []):
		if not (ghost_value is Dictionary):
			continue
		var ghost: Dictionary = ghost_value
		var offset: Vector2 = _as_vector2(ghost.get("offset", Vector2.ZERO), Vector2.ZERO)
		var ghost_context: Dictionary = _build_viper_dual_glitch_clone_sprite_context(
			sprite_context,
			_as_color(ghost.get("modulate", Color.WHITE), Color.WHITE)
		)
		sprite_renderer.draw(
			canvas,
			ghost_context,
			Rect2(visual_rect.position + offset, visual_rect.size),
			player_move_active,
			clone_pos + offset,
			paddle_size,
			shake_offset
		)

	# 원본은 실제 스프라이트를 8조각으로 자른다. resolve 훅으로 현재 (texture, region)을
	# 회수해 가로 슬라이스를 draw_texture_rect_region으로 그린다. 회수 실패/플립 시 컬러 밴드 폴백.
	var resolved: Dictionary = sprite_renderer.resolve_current_sprite(
		sprite_context, visual_rect, player_move_active, clone_pos, paddle_size, shake_offset
	)
	var tex_value: Variant = resolved.get("texture", null)
	var sprite_texture: Texture2D = tex_value if tex_value is Texture2D else null
	var sprite_region: Rect2 = _as_rect2(resolved.get("region", Rect2()), Rect2())
	var can_slice: bool = (
		sprite_texture != null
		and sprite_region.size.x > 0.0
		and sprite_region.size.y > 0.0
		and not bool(resolved.get("flip_h", false))
	)
	for slice_value in draw_info.get("slice_specs", []):
		if not (slice_value is Dictionary):
			continue
		var slice_spec: Dictionary = slice_value
		var slice_rect: Rect2 = slice_spec.get("rect", Rect2())
		if can_slice:
			var src_band := Rect2(
				sprite_region.position.x,
				sprite_region.position.y + float(slice_spec.get("src_frac_y", 0.0)) * sprite_region.size.y,
				sprite_region.size.x,
				max(1.0, float(slice_spec.get("src_frac_h", 0.125)) * sprite_region.size.y)
			)
			canvas.draw_texture_rect_region(
				sprite_texture,
				slice_rect,
				src_band,
				_as_color(slice_spec.get("modulate", Color.WHITE), Color.WHITE),
				false,
				true
			)
		else:
			var color: Color = _as_color(slice_spec.get("color", Color.WHITE), Color.WHITE)
			canvas.draw_rect(slice_rect, color, true)
			canvas.draw_line(slice_rect.position, slice_rect.position + Vector2(slice_rect.size.x, 0.0), Color(1.0, 1.0, 1.0, color.a * 0.42), 1.0, true)

	for particle_value in draw_info.get("particles", []):
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var particle_pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO)
		var particle_size: float = float(particle.get("size", 1.0))
		var particle_color: Color = _as_color(particle.get("color", Color.WHITE), Color.WHITE)
		canvas.draw_rect(Rect2(particle_pos, Vector2(particle_size, particle_size)), particle_color, true)

	# CLAUDE.md "Transparent-canvas overlay box" 트랩: 디졸브 스캔라인을 전체 바운딩 rect에
	# 흰 가로선(draw_line)으로 그리면 스프라이트 투명 여백까지 덮어 네모박스가 보인다.
	# resolve된 (texture, region)에서 각 라인 행을 1px 텍스처 밴드로 샘플해 실루엣(알파)에만
	# 입힌다 -> 투명 텍셀은 아무것도 안 그려져 박스가 사라진다. 텍스처를 회수 못 하면
	# (can_slice=false) 스캔라인을 생략한다(폴백 full-rect 라인 금지 = 박스 재발 방지).
	var spacing: int = max(1, int(draw_info.get("scanline_spacing", 3)))
	var scan_alpha: float = float(draw_info.get("scanline_alpha", 0.0))
	if scan_alpha > 0.0 and can_slice:
		var scan_drift_y: float = float(draw_info.get("drift_y", 0.0))
		var scan_modulate := Color(1.0, 1.0, 1.0, scan_alpha)
		var scan_src_h: float = max(1.0, sprite_region.size.y / max(1.0, visual_rect.size.y))
		for y in range(0, int(visual_rect.size.y), spacing):
			var src_band := Rect2(
				sprite_region.position.x,
				sprite_region.position.y + (float(y) / max(1.0, visual_rect.size.y)) * sprite_region.size.y,
				sprite_region.size.x,
				scan_src_h
			)
			var dest_band := Rect2(
				Vector2(visual_rect.position.x, visual_rect.position.y + float(y) - scan_drift_y),
				Vector2(visual_rect.size.x, 1.0)
			)
			canvas.draw_texture_rect_region(sprite_texture, dest_band, src_band, scan_modulate, false, true)


func build_viper_dual_glitch_clone_sprite_draws(
	context: Dictionary,
	player_visual_rect: Rect2,
	_player_move_active: bool,
	player_pos: Vector2,
	_paddle_size: Vector2,
	shake_offset: Vector2
) -> Array:
	if str(context.get("selected_character_type", "")).strip_edges().to_lower() != "viper":
		return []
	var state: String = str(context.get("viper_dual_glitch_state", "idle"))
	if state not in ["spawn", "active", "fade"]:
		return []
	var entries_value: Variant = context.get("viper_dual_glitch_clone_rects", [])
	if not (entries_value is Array):
		return []
	var entries: Array = entries_value
	if entries.is_empty():
		return []

	var visual_offset: Vector2 = player_visual_rect.position - (player_pos + shake_offset)
	var tick: float = float(Time.get_ticks_msec())
	var phase_frames: float = float(context.get("viper_dual_glitch_phase_frames", 0.0))
	var spawn_frames: float = float(context.get("viper_dual_glitch_spawn_frames", VIPER_DUAL_GLITCH_SPAWN_FRAMES))
	var spawn_progress: float = compute_dual_glitch_spawn_progress(state, phase_frames, spawn_frames)
	var split_shift: float = compute_dual_glitch_split_shift(state, spawn_progress)
	var split_alpha_boost: float = compute_dual_glitch_split_alpha_boost(state, spawn_progress)
	var base_alpha: float = float(context.get("viper_dual_glitch_alpha", VIPER_DUAL_GLITCH_ALPHA))
	var fade_reason: String = str(context.get("viper_dual_glitch_fade_reason", ""))
	var fade_progress: float = clamp(
		phase_frames / max(1.0, float(context.get("viper_dual_glitch_fade_frames", VIPER_DUAL_GLITCH_FADE_FRAMES))),
		0.0,
		1.0
	) if state == "fade" else 0.0
	var clone_draws: Array = []
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var rect: Rect2 = entry.get("rect", Rect2())
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if max(0, int(entry.get("hp", 0))) <= 0 and bool(entry.get("evaporating", false)):
			# 원본: 공에 맞아 파괴된 분신은 스팀 퍼프로 증발(스프라이트 미렌더).
			var evap_progress: float = clamp(
				float(entry.get("evaporation_frames", 0.0)) / max(1.0, float(context.get("viper_dual_glitch_evaporation_frames", VIPER_DUAL_GLITCH_EVAPORATION_FRAMES))),
				0.0, 1.0
			)
			if evap_progress < 1.0:
				clone_draws.append({
					"steam_puff": true,
					"evaporation_progress": evap_progress,
					"clone_center": (rect.position + shake_offset + visual_offset) + player_visual_rect.size * 0.5,
					"clone_size": player_visual_rect.size,
					"clone_index": int(entry.get("index", 0)),
					"base_alpha": base_alpha,
				})
			continue
		var state_alpha: float = _get_viper_dual_glitch_clone_alpha(context, entry, state)
		if state_alpha <= 0.02:
			continue
		var index: int = int(entry.get("index", 0))
		var side: int = int(entry.get("side", 0))
		var jitter_x: float = sin(tick * 0.035 + float(index) * 1.7) * float(context.get(
			"viper_dual_glitch_wiggle_amplitude",
			VIPER_DUAL_GLITCH_WIGGLE_AMPLITUDE
		))
		var clone_pos: Vector2 = rect.position + Vector2(jitter_x, 0.0)
		var clone_visual_rect := Rect2(
			clone_pos + shake_offset + visual_offset,
			player_visual_rect.size
		)
		if state == "fade" and fade_reason == "timeout":
			var timeout_drift_y: float = compute_dual_glitch_timeout_drift_y(fade_progress)
			var slice_specs: Array = []
			var slice_height: float = max(3.0, clone_visual_rect.size.y / float(VIPER_DUAL_GLITCH_TIMEOUT_DISPEL_SLICE_COUNT))
			for slice_idx in range(VIPER_DUAL_GLITCH_TIMEOUT_DISPEL_SLICE_COUNT):
				var local_y: float = min(clone_visual_rect.size.y, float(slice_idx) * slice_height)
				if local_y >= clone_visual_rect.size.y:
					break
				var current_slice_h: float = min(slice_height, clone_visual_rect.size.y - local_y)
				var slice_alpha: float = compute_dual_glitch_timeout_slice_alpha(slice_idx, fade_progress, state_alpha)
				if slice_alpha <= 0.0:
					continue
				var slice_offset: Vector2 = compute_dual_glitch_timeout_slice_offset(slice_idx, index, side, fade_progress, tick)
				var slice_color: Color = VIPER_DUAL_GLITCH_RGB_SPLIT[(slice_idx + index) % VIPER_DUAL_GLITCH_RGB_SPLIT.size()]
				slice_specs.append({
					"rect": Rect2(
						clone_visual_rect.position + Vector2(slice_offset.x, local_y + slice_offset.y - timeout_drift_y),
						Vector2(clone_visual_rect.size.x, current_slice_h)
					),
					"color": Color(slice_color.r, slice_color.g, slice_color.b, slice_alpha * 0.44),
					"modulate": Color(lerp(1.0, slice_color.r, 0.5), lerp(1.0, slice_color.g, 0.5), lerp(1.0, slice_color.b, 0.5), slice_alpha),
					"src_frac_y": local_y / max(1.0, clone_visual_rect.size.y),
					"src_frac_h": current_slice_h / max(1.0, clone_visual_rect.size.y),
					"offset": slice_offset,
					"slice_index": slice_idx,
				})

			var particles: Array = []
			var rng := RandomNumberGenerator.new()
			rng.seed = int(9000 + index * 131 + (17 if side > 0 else 0))
			for particle_idx in range(VIPER_DUAL_GLITCH_TIMEOUT_DISPEL_PARTICLE_COUNT):
				var particle_alpha: float = max(
					0.0,
					state_alpha * (0.55 - fade_progress * 0.35) * (1.0 - float(particle_idx) / float(VIPER_DUAL_GLITCH_TIMEOUT_DISPEL_PARTICLE_COUNT + 2))
				)
				if particle_alpha <= 0.0:
					continue
				var base_px: float = rng.randf_range(2.0, max(2.0, clone_visual_rect.size.x - 3.0))
				var base_py: float = rng.randf_range(2.0, max(2.0, clone_visual_rect.size.y - 3.0))
				var drift_x: float = rng.randf_range(-10.0, 10.0) + float(side) * 4.0
				var drift_y_local: float = rng.randf_range(-36.0, -12.0)
				var particle_color: Color = VIPER_DUAL_GLITCH_RGB_SPLIT[particle_idx % VIPER_DUAL_GLITCH_RGB_SPLIT.size()]
				var particle_local_offset := Vector2(base_px + drift_x * fade_progress, base_py + drift_y_local * fade_progress)
				particles.append({
					"pos": clone_visual_rect.position + particle_local_offset - Vector2(0.0, timeout_drift_y),
					"local_offset": particle_local_offset,
					"size": 2.0 if particle_idx < 8 else 1.0,
					"color": Color(particle_color.r, particle_color.g, particle_color.b, particle_alpha),
				})

			var ghost_alpha: float = compute_dual_glitch_timeout_ghost_alpha(fade_progress, state_alpha)
			var ghosts: Array = []
			for ghost_side in [-1, 1]:
				var ghost_color: Color = VIPER_DUAL_GLITCH_RGB_SPLIT[0 if ghost_side < 0 else 2]
				ghosts.append({
					"offset": compute_dual_glitch_timeout_ghost_offset(ghost_side, fade_progress),
					"modulate": _dual_glitch_split_modulate(ghost_color, ghost_alpha),
				})
			clone_draws.append({
				"timeout_dispel": true,
				"entry": entry,
				"visual_rect": clone_visual_rect,
				"player_pos": clone_pos,
				"alpha": state_alpha,
				"fade_progress": fade_progress,
				"drift_y": timeout_drift_y,
				"slice_specs": slice_specs,
				"particles": particles,
				"ghosts": ghosts,
				"scanline_spacing": max(3, int(4.0 - min(0.8, fade_progress) * 1.5)),
				"scanline_alpha": (40.0 / 255.0) * (1.0 - fade_progress * 0.4),
			})
			continue
		var hp: int = max(0, int(entry.get("hp", 0)))
		var weakened: bool = hp == 1
		var split_alpha: float = max(18.0 / 255.0, state_alpha * 0.33 * split_alpha_boost)
		var echoes: Array = []
		if state == "spawn":
			for echo_idx in range(VIPER_DUAL_GLITCH_SPAWN_ECHO_COUNT):
				var echo_alpha: float = compute_dual_glitch_echo_alpha(echo_idx, spawn_progress, base_alpha)
				if echo_alpha <= 6.0 / 255.0:
					continue
				var echo_t: float = compute_dual_glitch_echo_t(echo_idx, spawn_progress)
				var echo_pos: Vector2 = player_visual_rect.position.lerp(clone_visual_rect.position, echo_t)
				var echo_color: Color = VIPER_DUAL_GLITCH_RGB_SPLIT[echo_idx % VIPER_DUAL_GLITCH_RGB_SPLIT.size()]
				echoes.append({
					"rect": Rect2(echo_pos, player_visual_rect.size),
					"modulate": _dual_glitch_echo_modulate(echo_color, echo_alpha),
				})
		clone_draws.append({
			"entry": entry,
			"visual_rect": clone_visual_rect,
			"player_pos": clone_pos,
			"alpha": state_alpha,
			"ghost_shift_x": split_shift,
			"echoes": echoes,
			"main_modulate": _get_viper_dual_glitch_clone_modulate(side, state_alpha, weakened, "main"),
			"left_split_modulate": _dual_glitch_split_modulate(VIPER_DUAL_GLITCH_RGB_SPLIT[0], split_alpha),
			"right_split_modulate": _dual_glitch_split_modulate(VIPER_DUAL_GLITCH_RGB_SPLIT[2], split_alpha),
		})
	return clone_draws


func _get_viper_dual_glitch_clone_alpha(context: Dictionary, entry: Dictionary, state: String) -> float:
	var state_alpha: float = float(context.get("viper_dual_glitch_alpha", VIPER_DUAL_GLITCH_ALPHA))
	var phase_frames: float = float(context.get("viper_dual_glitch_phase_frames", 0.0))
	if state == "spawn":
		state_alpha *= compute_dual_glitch_spawn_alpha_factor(
			phase_frames,
			float(context.get("viper_dual_glitch_spawn_frames", VIPER_DUAL_GLITCH_SPAWN_FRAMES))
		)
	elif state == "fade":
		state_alpha *= 1.0 - clamp(
			phase_frames / max(1.0, float(context.get("viper_dual_glitch_fade_frames", VIPER_DUAL_GLITCH_FADE_FRAMES))),
			0.0,
			1.0
		)
	if bool(entry.get("evaporating", false)):
		state_alpha *= 1.0 - clamp(
			float(entry.get("evaporation_frames", 0.0)) / max(1.0, float(context.get(
				"viper_dual_glitch_evaporation_frames",
				VIPER_DUAL_GLITCH_EVAPORATION_FRAMES
			))),
			0.0,
			1.0
		)
	if max(0, int(entry.get("hp", 0))) == 1:
		state_alpha *= 0.72
	return clamp(state_alpha, 0.0, 1.0)


func _get_viper_dual_glitch_clone_modulate(side: int, alpha: float, weakened: bool, pass_id: String) -> Color:
	var alpha_scale: float = 0.62 if weakened else 0.82
	match pass_id:
		"cyan":
			return Color(0.30, 1.0, 1.24, alpha * 0.34)
		"magenta":
			return Color(1.24, 0.30, 0.86, alpha * 0.30)
	if side < 0:
		return Color(1.12, 0.58, 1.24, alpha * alpha_scale)
	return Color(0.58, 1.18, 1.12, alpha * alpha_scale)


func _build_viper_dual_glitch_clone_sprite_context(sprite_context: Dictionary, modulate: Color) -> Dictionary:
	var clone_context: Dictionary = sprite_context.duplicate()
	clone_context["player_sprite_modulate"] = _combine_modulate_colors(
		sprite_context.get("player_sprite_modulate", Color.WHITE),
		modulate
	)
	return clone_context


# Cyan ghost (left-shifted) + magenta ghost (right-shifted) + main pass.
# Re-runs `sprite_renderer.draw()` once per pass with a duplicated context so
# the shared `player_sprite_modulate` swap does not bleed back into the
# caller's dictionary. The visual rect is translated for the ghost passes;
# all internal sprite-renderer math (anchors, frame indexing, body offsets)
# is keyed off `player_pos` / `paddle_size` and stays at the original anchor.
func _draw_player_with_hologram_passes(
	canvas: CanvasItem,
	sprite_context: Dictionary,
	player_visual_rect: Rect2,
	player_move_active: bool,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2,
	plan: Dictionary
) -> void:
	var base_modulate: Color = _as_color(sprite_context.get("player_sprite_modulate", Color.WHITE), Color.WHITE)
	var color_shift_x: float = float(plan.get("color_shift_x", 0.0))
	if bool(plan.get("ghosts_active", false)) and color_shift_x > 0.001:
		var cyan_context: Dictionary = sprite_context.duplicate()
		cyan_context["player_sprite_modulate"] = plan.get("cyan_modulate", Color.WHITE)
		var cyan_rect := Rect2(
			player_visual_rect.position + Vector2(-color_shift_x, 0.0),
			player_visual_rect.size
		)
		sprite_renderer.draw(
			canvas,
			cyan_context,
			cyan_rect,
			player_move_active,
			player_pos,
			paddle_size,
			shake_offset
		)
		var magenta_context: Dictionary = sprite_context.duplicate()
		magenta_context["player_sprite_modulate"] = plan.get("magenta_modulate", Color.WHITE)
		var magenta_rect := Rect2(
			player_visual_rect.position + Vector2(color_shift_x, 0.0),
			player_visual_rect.size
		)
		sprite_renderer.draw(
			canvas,
			magenta_context,
			magenta_rect,
			player_move_active,
			player_pos,
			paddle_size,
			shake_offset
		)
	var main_context: Dictionary = sprite_context.duplicate()
	main_context["player_sprite_modulate"] = PaddleHologramGlitchRenderer.combine_modulate(base_modulate, plan)
	sprite_renderer.draw(
		canvas,
		main_context,
		player_visual_rect,
		player_move_active,
		player_pos,
		paddle_size,
		shake_offset
	)


func _as_color(value, fallback: Color) -> Color:
	return value if value is Color else fallback


func _perf_begin(perf_logger: Object) -> int:
	if perf_logger != null and perf_logger.has_method("begin_sample"):
		return int(perf_logger.begin_sample())
	return 0


func _perf_end(perf_logger: Object, label: String, start_usec: int) -> void:
	if perf_logger != null and perf_logger.has_method("finish_sample"):
		perf_logger.finish_sample(label, start_usec)


# §C-1 본체 지연 판정. 목말(온이마루)은 **종전 그대로 lift > 0** 이 근거다 —
# `mounted` 로 바꾸면 홉 시작(lift=0) 프레임과 하차 잔여 lift 프레임의 픽셀이
# 바뀐다. 탑다운 합성만 지연하지 않는다: M 은 별도 콜백으로 라이더 **아래**에
# 깔리고, 본체 훅 자체는 egg 가 자기억제하므로 여기서 뒤로 미룰 대상이 없다.
# §B-3: M 베이스 훅 호출 정본. 유효한 Callable 일 때만, 렌더러가 확정한 라이더
# rect **그대로** 넘긴다(재계산 금지 — shake·visual offset 이 갈라진다).
# 호출 여부를 돌려줘 씰이 발화/비발화를 관측할 수 있게 한다.
static func _call_lingpet_mount_base_hook(canvas: CanvasItem, context: Dictionary, player_visual_rect: Rect2) -> bool:
	var mount_base_hook: Variant = context.get("lingpet_mount_base_draw", null)
	if not (mount_base_hook is Callable):
		return false
	var hook: Callable = mount_base_hook
	if not hook.is_valid():
		return false
	hook.call(canvas, player_visual_rect)
	return true


static func _is_lingpet_body_deferred(context: Dictionary) -> bool:
	if bool(context.get("player_mount_topdown_active", false)):
		return false
	return float(context.get("player_mount_rider_lift_px", 0.0)) > 0.0


# §B-4 착석 라이더 draw size. 탑다운 탑승 중에는 걷기/공격 시트가 아니라 착석
# 시트 규격이 몸 크기 정본이다(패들 배율은 그대로 곱해진다 — 호출부 순서 유지).
static func _resolve_mount_seated_draw_size(context: Dictionary, fallback: Vector2) -> Vector2:
	if not bool(context.get("player_mount_topdown_active", false)):
		return fallback
	var seated: Dictionary = context.get("player_mount_rider_seated", {}) as Dictionary
	if seated.is_empty():
		return fallback
	var spec: Dictionary = seated.get("spec", {}) as Dictionary
	var raw: Variant = spec.get("draw_size", null)
	if not (raw is Vector2):
		return fallback
	var seated_size: Vector2 = raw
	if seated_size.x <= 0.0 or seated_size.y <= 0.0:
		return fallback
	return seated_size


func _get_player_hit_progress(hit_timer: float, hit_duration: float) -> float:
	if hit_duration <= 0.0:
		return 1.0
	return clamp(1.0 - (hit_timer / hit_duration), 0.0, 1.0)


func _get_player_hit_draw_size(context: Dictionary, fallback_draw_size: Vector2) -> Vector2:
	var commando_attack_sheet_present: bool = (
		bool(context.get("commando_attack_active", false))
		and context.get("commando_attack_sheet", null) is Texture2D
	)
	if commando_attack_sheet_present:
		return _as_vector2(
			context.get("player_commando_attack_draw_size", DEFAULT_PLAYER_COMMANDO_ATTACK_DRAW_SIZE),
			DEFAULT_PLAYER_COMMANDO_ATTACK_DRAW_SIZE
		)

	var directional_attack_sheet_present: bool = (
		context.get("player_attack_left_sheet", null) is Texture2D
		or context.get("player_attack_right_sheet", null) is Texture2D
	)
	if directional_attack_sheet_present:
		return _as_vector2(
			context.get("player_directional_attack_draw_size", DEFAULT_PLAYER_DIRECTIONAL_ATTACK_DRAW_SIZE),
			DEFAULT_PLAYER_DIRECTIONAL_ATTACK_DRAW_SIZE
		)

	if context.get("player_attack_sheet", null) is Texture2D:
		return _as_vector2(
			context.get("player_attack_draw_size", DEFAULT_PLAYER_ATTACK_DRAW_SIZE),
			DEFAULT_PLAYER_ATTACK_DRAW_SIZE
		)

	return fallback_draw_size


func _ease_out_cubic(pillar_drawer, t: float) -> float:
	if pillar_drawer != null and pillar_drawer.has_method("ease_out_cubic"):
		return pillar_drawer.ease_out_cubic(t)
	var clamped_t: float = clamp(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped_t, 3.0)


func _ease_in_out_sine(pillar_drawer, t: float) -> float:
	if pillar_drawer != null and pillar_drawer.has_method("ease_in_out_sine"):
		return pillar_drawer.ease_in_out_sine(t)
	var clamped_t: float = clamp(t, 0.0, 1.0)
	return -(cos(PI * clamped_t) - 1.0) * 0.5


func _as_vector2(value, fallback: Vector2) -> Vector2:
	return Stage1ContextReader.as_vector2(value, fallback)


func _as_rect2(value, fallback: Rect2) -> Rect2:
	return value if value is Rect2 else fallback


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _uses_smasher_body_motion(context: Dictionary) -> bool:
	var character_type: String = str(context.get("selected_character_type", "smasher")).strip_edges().to_lower()
	return character_type == "" or character_type == "smasher" or character_type == "ufo_player"


func _get_player_hover_amplitude(context: Dictionary) -> float:
	if not _uses_smasher_body_motion(context):
		return 0.0
	return float(context.get("player_hover_amplitude", 7.0))


func _get_player_move_bob_amplitude(context: Dictionary) -> float:
	if not _uses_smasher_body_motion(context):
		return 0.0
	return float(context.get("player_move_bob_amplitude", 5.0))


func _get_player_idle_breath_scale_x(context: Dictionary) -> float:
	if not _uses_smasher_body_motion(context):
		return 0.0
	return float(context.get("player_idle_breath_scale_x", 0.015))


func _get_player_idle_breath_scale_y(context: Dictionary) -> float:
	if not _uses_smasher_body_motion(context):
		return 0.0
	return float(context.get("player_idle_breath_scale_y", 0.025))


func _get_player_idle_breath_y(context: Dictionary) -> float:
	if not _uses_smasher_body_motion(context):
		return 0.0
	return float(context.get("player_idle_breath_y", 2.5))


func _has_directional_walk_texture(context: Dictionary) -> bool:
	var direction: int = int(context.get("player_walk_direction", 1))
	var texture_key := "player_walk_left_texture" if direction < 0 else "player_walk_right_texture"
	return context.get(texture_key, null) is Texture2D


func _has_directional_dash_texture(context: Dictionary) -> bool:
	var direction: int = int(context.get("player_walk_direction", 1))
	var texture_key := "player_dash_left_texture" if direction < 0 else "player_dash_right_texture"
	return context.get(texture_key, null) is Texture2D


func _get_curse_reverse_sprite_modulate(ratio: float) -> Color:
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.010)
	var strength: float = clamp(ratio * (0.72 + pulse * 0.18), 0.0, 1.0)
	return Color(
		lerp(1.0, 1.26, strength),
		lerp(1.0, 0.42 + pulse * 0.06, strength),
		lerp(1.0, 0.90 + pulse * 0.12, strength),
		1.0
	)


func _get_player_slow_sprite_modulate(ratio: float) -> Color:
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.012)
	var strength: float = clamp(ratio * (0.42 + pulse * 0.12), 0.0, 1.0)
	return Color(
		lerp(1.0, 0.66, strength),
		lerp(1.0, 0.88, strength),
		lerp(1.0, 1.32, strength),
		1.0
	)


func _combine_modulate_colors(base: Variant, overlay: Color) -> Color:
	var base_color: Color = base if base is Color else Color.WHITE
	return Color(
		base_color.r * overlay.r,
		base_color.g * overlay.g,
		base_color.b * overlay.b,
		base_color.a * overlay.a
	)


func _draw_player_slow_wave(canvas: CanvasItem, player_visual_rect: Rect2, ratio: float) -> void:
	var clamped_ratio: float = clamp(ratio, 0.0, 1.0)
	var intensity: float = 0.45 + 0.55 * clamped_ratio
	var center := Vector2(player_visual_rect.get_center().x, player_visual_rect.position.y + player_visual_rect.size.y * 0.35)
	var time_phase: float = float(Time.get_ticks_msec()) * 0.006
	for idx in range(4):
		var wave_ratio: float = float(idx) / 3.0
		var wave_width: float = 74.0 * (1.0 - wave_ratio * 0.10)
		var wave_height: float = 18.0 + wave_ratio * 8.0
		var y_offset: float = -12.0 - float(idx) * 6.0 + sin(time_phase + float(idx) * 0.8) * 2.0
		var alpha: float = (0.17 - wave_ratio * 0.030) * intensity
		_draw_ellipse_outline(
			canvas,
			Rect2(center + Vector2(-wave_width * 0.5, y_offset), Vector2(wave_width, wave_height)),
			Color(0.42, 0.68, 1.0, alpha),
			2.0
		)


func _draw_ellipse_outline(canvas: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius: Vector2 = rect.size * 0.5
	for idx in range(20):
		var angle: float = TAU * float(idx) / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	for idx in range(points.size()):
		canvas.draw_line(points[idx], points[(idx + 1) % points.size()], color, width)


func _draw_curse_reverse_head_effect(canvas: CanvasItem, player_visual_rect: Rect2, ratio: float) -> void:
	var alpha: float = clamp(0.45 + ratio * 0.55, 0.0, 1.0)
	var center := Vector2(player_visual_rect.get_center().x, player_visual_rect.position.y - 15.0)
	var t: float = float(Time.get_ticks_msec()) / 200.0
	var pulse: float = 0.5 + 0.5 * sin(t * 1.7)
	canvas.draw_arc(center, 12.0 + pulse * 2.0, t, t + PI * 1.35, 24, Color(1.0, 0.34, 0.74, 0.42 * alpha), 2.0, true)
	canvas.draw_arc(center, 7.0 + pulse, t + PI, t + PI * 2.15, 18, Color(1.0, 0.74, 0.92, 0.34 * alpha), 1.5, true)
	for i in range(3):
		var angle: float = t + float(i) * TAU / 3.0
		var orb_pos := center + Vector2(cos(angle) * 8.0, sin(angle) * 4.0)
		canvas.draw_circle(orb_pos, 5.0, Color(1.0, 0.28, 0.68, 0.14 * alpha))
		canvas.draw_circle(orb_pos, 3.0, Color(1.0, 0.39, 0.71, 0.82 * alpha))
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var text := "?!"
	var font_size := 14
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var pos := center + Vector2(-text_size.x * 0.5, -12.0)
	canvas.draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.0, 0.0, 0.0, 0.72 * alpha))
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 0.68, 0.86, 0.95 * alpha))


# Python parity: during the horn strawberry TRANSFORM event the real character
# sprite floats up (-80px, ease-out 1-(1-t)^2) over the first 35% of the 4.5s
# cinematic, mirroring the original's captured-paddle-snapshot rise. Returns
# Vector2.INF ("do not draw the sprite") outside that window — the swirl/burst/
# landing phases and the detransform event are owned by the cinematic renderer.
func horn_strawberry_event_sprite_rise_offset(horn_context: Dictionary) -> Vector2:
	if str(horn_context.get("state", "")) != "transform_event":
		return Vector2.INF
	var duration_sec := 4.5
	var remaining: float = clamp(float(horn_context.get("event_timer_sec", 0.0)), 0.0, duration_sec)
	var progress: float = clamp((duration_sec - remaining) / duration_sec, 0.0, 1.0)
	if progress >= 0.35:
		return Vector2.INF
	var p: float = clamp(progress / 0.35, 0.0, 1.0)
	var rise_ease: float = 1.0 - (1.0 - p) * (1.0 - p)
	return Vector2(0.0, -80.0 * rise_ease)


# ── 신령환 = 호신령 빙의 연출 ────────────────────────────────────────────────
#
# 이 상태가 말해야 하는 것은 "버프가 걸렸다"가 아니라 "내가 조종당하고 있다"다.
# 한미량은 뒷모습 SD라 표정을 쓸 수 없으므로, 조종당함은 아래 4개 장치가 진다.
#
#  ① 인과 역전 (주장치) — 가드 12프레임 중 12→10f 구간은 신령측(기맥·낙관·
#     부적·배경판)만 반응하고 몸은 가만히 있는다. 9f부터 본체가 뒤늦게 과열
#     된다. 3프레임(~42ms)은 세기엔 짧지만 "명령 → 반응"의 인과 순서로는
#     확실히 읽힌다. spirit_ease / body_ease 가 이 두 축이다.
#  ② 선행 잔상 (주장치) — 자동 가드가 패들을 스냅시킬 때 금빛 잔상이 진행
#     방향으로 "먼저" 가 있다. 뒤따르는 잔상은 "내가 움직였다"지만 앞서는
#     잔상은 "내가 정하기 전에 몸이 끌려갔다"로만 읽힌다.
#  ③ 신탁 조준선 — 입력과 무관하게 요격점이 먼저 정해지고, 보간 없이 즉시
#     순간이동한다. 관성 없는 스냅이 "사람이 조작하는 게 아니다"의 직접 증거.
#     타깃 x는 active_item_aipill_behavior.apply_player_control 과 동일한 식
#     (공 x - 패들폭/2 를 play 범위로 클램프)이라 신규 컨텍스트 키가 필요 없다.
#  ④ 하강 강신 — 광점 2개가 머리 위에서 정수리로 수렴해 접점 글로우에 흡수
#     된다. 둔화 물결(상승)·대시(수평)·저주(회전)와 방향이 겹치지 않는다.
#
# 클럭 규칙: phase 는 active_item_aipill_runtime 에서 TAU 로 fmod 되므로
# 분수 계수(sin(0.19 * phase) 같은 것)를 쓰면 랩 순간 전 레이어가 동시에
# 튄다. 고속 성분은 phase 의 정수 배음만, 저속 성분은 벽시계로 만든다.
# 2-rate 호흡. 벽시계 기반이라 phase TAU 랩의 영향을 받지 않는다. 지면 그림자
# 축소(플랜 구축 전에 필요)와 플랜이 같은 값을 쓰도록 단일 소스로 둔다.
static func possession_breath(now_msec: float) -> float:
	return lerpf(
		0.5 + 0.5 * sin(now_msec * 0.00118),
		0.5 + 0.5 * sin(now_msec * 0.00187 + 1.3),
		0.32
	)


static func build_possession_plan(
	context: Dictionary,
	visual_rect: Rect2,
	now_msec: float,
	lod_level: int,
	lead_dx: float
) -> Dictionary:
	if not bool(context.get("active_item_aipill_active", false)):
		return {"active": false, "draw_count": 0}
	if visual_rect.size.x <= 0.0 or visual_rect.size.y <= 0.0:
		return {"active": false, "draw_count": 0}

	# 치수는 rect 비율이 아니라 base_px * u 로 잡는다. 블랙스미스 128x128,
	# 레거시 250x120 폴백에서 종횡비가 무너지는 것을 막는다.
	var u: float = clampf(visual_rect.size.y / 160.0, 0.60, 1.60)
	var cx: float = visual_rect.position.x + visual_rect.size.x * 0.5
	var top: float = visual_rect.position.y
	# 한미량 뒷모습 SD 시트에서 실제 머리 꼭대기는 셀 상단이 아니라 rect 상단
	# +30u 부근이다(위쪽 여백 + 근두운 정렬). 접점은 거기에 놓아야 "정수리로
	# 들어온다"로 읽힌다.
	var crown := Vector2(cx, top + 30.0 * u)

	# 저속 = 벽시계(자유 분수 계수 안전), 고속 = phase 정수 배음.
	var breath: float = possession_breath(now_msec)
	var phase: float = float(context.get("active_item_aipill_phase", 0.0))
	var tremor: float = sin(phase)

	# 가드 판정 플래시. 신령측은 12프레임 전 구간 즉시 반응하고, 육체측은
	# 앞 3프레임을 흘려보낸 뒤에야 따라온다 = 인과 역전.
	var flash_timer: float = float(context.get("active_item_aipill_flash_timer_frames", 0.0))
	var flash_initial: float = maxf(1.0, float(context.get("active_item_aipill_flash_initial_frames", 12.0)))
	var body_delay: float = maxf(1.0, flash_initial - 3.0)
	var spirit_ease: float = pow(clampf(flash_timer / flash_initial, 0.0, 1.0), 1.6)
	var body_ease: float = 0.0
	if flash_timer <= body_delay:
		body_ease = pow(clampf(flash_timer / body_delay, 0.0, 1.0), 1.6)

	var lod: int = clampi(lod_level, 0, 2)
	var draw_count := 0

	# L0 신주(神柱) 배경판 — 본체 뒤. 세로 축인 것이 중요하다: 둔화 물결(가로
	# 타원)과 저주 반전(원형 궤도)이 이미 그 밴드의 가로/원형 어휘를 점유했다.
	var backplate_rect := Rect2(
		cx - 50.0 * u,
		top - 8.0 * u,
		100.0 * u,
		170.0 * u
	)
	var backplate_alpha: float = 0.13 + 0.06 * breath + 0.09 * spirit_ease
	draw_count += 1

	# L5 강신부 슬립 — 정수리 바로 위에 떠 있게 둔다. 머리를 덮으면 캐릭터
	# 판독이 죽고 "포스터"로 보인다(픽셀 QA 1차에서 실제로 그렇게 나왔다).
	var talisman_center := Vector2(
		cx + sin(now_msec * 0.0016) * 2.6 * u,
		top + 9.0 * u + sin(now_msec * 0.0023) * 1.4 * u
	)
	var talisman_alpha: float = 0.74 + 0.06 * breath + 0.12 * spirit_ease
	draw_count += 1

	# L6 강하 광점 — 좌우로 벌어진 두 갈래가 정수리로 수렴한다.
	var motes: Array = []
	var mote_slots: int = _POSSESSION_MOTE_SLOT_COUNT
	if lod == 1:
		mote_slots = 1
	elif lod >= 2:
		mote_slots = 0
	for idx in range(mote_slots):
		var travel: float = fposmod(now_msec * 0.00046 + float(idx) * 0.5, 1.0)
		# 부적 뒤에 가리면 하강이 안 보인다 — 슬립 폭 밖(좌우 ±30u)에서
		# 출발해 정수리로 수렴시킨다.
		var start := Vector2(cx + (-30.0 + 60.0 * float(idx)) * u, top - 24.0 * u)
		motes.append({
			"pos": start.lerp(crown, travel),
			"radius": (8.4 - 3.0 * travel) * u,
			# 양 끝 페이드 — 팝인/팝아웃 방지.
			"alpha": (0.82 + 0.18 * spirit_ease) * sin(PI * travel),
		})
	draw_count += motes.size()

	# L7 정수리 접점.
	var crown_radius: float = (13.0 + 3.0 * tremor) * u
	var crown_alpha: float = 0.44 + 0.12 * breath + 0.30 * spirit_ease
	draw_count += 1

	# L10 상태 라벨 — 구 사이버 라벨이 있던 슬롯. 그림자 + 본문 2 draw.
	var label_pos := Vector2(cx, top - 14.0 * u)
	var label_alpha: float = 0.82 + 0.10 * breath + 0.08 * spirit_ease
	draw_count += 2

	# L9 신탁 조준선 — 자동 가드가 노리는 지점. 스무딩 금지(즉시 스냅이 핵심).
	var sight: Dictionary = {"enabled": false}
	if lod <= 1 and bool(context.get("ball_active", false)):
		var paddle_size_value: Variant = context.get("player_paddle_size", null)
		var paddle_width := 155.0
		if paddle_size_value is Vector2:
			paddle_width = maxf(1.0, (paddle_size_value as Vector2).x)
		var ball_pos_value: Variant = context.get("ball_pos", null)
		var ball_pos := Vector2.ZERO
		if ball_pos_value is Vector2:
			ball_pos = ball_pos_value
		var play_left: float = float(context.get("play_left", 0.0))
		var play_right: float = float(context.get("play_right", 760.0))
		# active_item_aipill_behavior.apply_player_control 과 동일한 클램프.
		var target_left: float = clampf(
			ball_pos.x - paddle_width * 0.5,
			play_left,
			maxf(play_left, play_right - paddle_width)
		)
		var sight_x: float = target_left + paddle_width * 0.5
		# 패들 상단에 붙인다. visual_rect 하단은 패들보다 아래(스프라이트가
		# 패들 위로 솟은 만큼)라 그대로 쓰면 화면 밖으로 나간다.
		# rect 구성식을 역산하면 흔들림까지 포함된 패들 상단이 나온다:
		#   rect.bottom = player_pos.y + paddle_h + 12 + shake.y
		var paddle_height: float = 50.0
		if paddle_size_value is Vector2:
			paddle_height = maxf(1.0, (paddle_size_value as Vector2).y)
		var sight_y: float = visual_rect.position.y + visual_rect.size.y - paddle_height - 12.0 - 4.0 * u
		sight = {
			"enabled": true,
			"from": Vector2(sight_x - 11.0 * u, sight_y),
			"to": Vector2(sight_x + 11.0 * u, sight_y),
			"width": 2.0 * u,
			"alpha": 0.30 + 0.22 * breath,
		}
		draw_count += 1

	# L8 가드 플래시 전용 — 기맥 2가닥 + 주사 낙관. 상시 선(thread) 형상은 0개다
	# (코요라 인형실과 어휘가 겹치면 안 된다). 12프레임 한정.
	var meridians: Array = []
	var seal: Dictionary = {"enabled": false}
	if spirit_ease > 0.001:
		for side in [-1.0, 1.0]:
			meridians.append({
				"from": crown + Vector2(7.0 * u * side, 0.0),
				"to": Vector2(cx + 14.0 * u * side, top - 20.0 * u),
				"width": (0.9 + 1.9 * spirit_ease) * u,
				"alpha": 0.62 * spirit_ease,
			})
		draw_count += meridians.size()
		var seal_half: float = 10.0 * u
		seal = {
			"enabled": true,
			"center": visual_rect.get_center(),
			"half": seal_half,
			"alpha": 0.70 * pow(spirit_ease, 0.6),
		}
		draw_count += 1

	# L4 선행 잔상 — 대시 잔상(수평 산개)과 겹치면 판독이 붕괴하므로 대시 중
	# 에는 배타적으로 끈다.
	var dash_active: bool = bool(context.get("dash_active", false)) \
		or bool(context.get("player_dashing", false)) \
		or bool(context.get("dash_recovering", false))
	var lead := {"enabled": false}
	if lod <= 1 and not dash_active and absf(lead_dx) > 1.5 * u:
		lead = {
			"enabled": true,
			"offset": Vector2(clampf(lead_dx, -22.0 * u, 22.0 * u), 0.0),
			"color": Color(
				POSSESSION_LEAD_AFTERIMAGE.r,
				POSSESSION_LEAD_AFTERIMAGE.g,
				POSSESSION_LEAD_AFTERIMAGE.b,
				0.28 + 0.14 * body_ease
			),
		}
		draw_count += 1

	# L2 신열(神熱) 본체 틴트 — 곱셈 성분을 1.0 이하로만 잡아 blue를 깎는다.
	# 목표 인상은 "핏기 없음"(시체)이 아니라 "안에서 타고 있음"이다.
	var body_tint: Color = Color(1.000, 0.940, 0.800).lerp(Color(1.000, 0.975, 0.885), breath)
	if body_ease > 0.0:
		body_tint = body_tint.lerp(Color(1.000, 1.000, 0.975), body_ease * 0.7)

	return {
		"active": true,
		"u": u,
		"crown": crown,
		"breath": breath,
		"tremor": tremor,
		"spirit_ease": spirit_ease,
		"body_ease": body_ease,
		"lod": lod,
		"backplate_rect": backplate_rect,
		"backplate_alpha": backplate_alpha,
		"talisman_center": talisman_center,
		"talisman_alpha": talisman_alpha,
		"motes": motes,
		"crown_radius": crown_radius,
		"crown_alpha": crown_alpha,
		"label_pos": label_pos,
		"label_alpha": label_alpha,
		"sight": sight,
		"meridians": meridians,
		"seal": seal,
		"lead": lead,
		"visual_rect": visual_rect,
		"sprite_modulate": body_tint,
		# L3: 구 코드는 빙의 중 실루엣 림을 통째로 껐다 — 글리치가 켜지는 바로
		# 그 순간 캐릭터가 배경에서 분리되지 않는 출고된 회귀였다. 억제를
		# 풀고 백금 과열 림으로 승격한다.
		"rim_intensity": clampf(0.88 + 0.12 * spirit_ease, 0.0, 1.0),
		"rim_color": POSSESSION_SPIRIT_CORE,
		# L1(지면 그림자 축소)은 이 플랜에 없다 — 그림자는 player_visual_rect
		# 보다 먼저 그려지므로 플랜을 만들 수 없고, 드로우 사이트에서 같은
		# possession_breath() 로 직접 곱한다.
		"draw_count": draw_count,
	}


# 기존 LOD 신호를 재사용한다(바이퍼 활공 / FPS 캡 강등). 새 LOD 축을 만들지
# 않는다. effect_scale 은 정적 히스테리시스 상태를 만지므로 순수 플랜 빌더
# 밖에서 한 번만 부른다.
func _possession_lod_level(context: Dictionary) -> int:
	var scale: float = ViperAirborneLod.effect_scale(context)
	if scale >= 0.90:
		return 0
	if scale >= 0.50:
		return 1
	return 2


# 프레임 간 x 델타로 선행 잔상 오프셋을 만든다. 라운드 리셋 / 텔레포트 /
# 비활성 전이에서 반대편 잔상이 날아오지 않도록 자기치유한다.
func _advance_possession_lead_offset(active: bool, center_x: float, u: float) -> float:
	if not active:
		_possession_lead_valid = false
		return 0.0
	if not _possession_lead_valid or absf(center_x - _possession_lead_prev_x) > POSSESSION_LEAD_TELEPORT_PX * u:
		_possession_lead_prev_x = center_x
		_possession_lead_valid = true
		return 0.0
	var delta: float = center_x - _possession_lead_prev_x
	_possession_lead_prev_x = center_x
	return delta * 2.2


func _draw_possession_backplate(canvas: CanvasItem, plan: Dictionary) -> void:
	if canvas == null or not bool(plan.get("active", false)):
		return
	var texture: Texture2D = SoftGlowTexture.get_texture(128)
	if texture == null:
		return
	var rect: Rect2 = plan.get("backplate_rect", Rect2())
	canvas.draw_texture_rect(
		texture,
		rect,
		false,
		Color(
			POSSESSION_SPIRIT_HALO.r,
			POSSESSION_SPIRIT_HALO.g,
			POSSESSION_SPIRIT_HALO.b,
			float(plan.get("backplate_alpha", 0.0))
		)
	)


func _draw_possession_lead_afterimage(
	canvas: CanvasItem,
	plan: Dictionary,
	sprite_context: Dictionary,
	player_visual_rect: Rect2,
	player_move_active: bool,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> void:
	if canvas == null or not bool(plan.get("active", false)):
		return
	var lead: Dictionary = plan.get("lead", {})
	if not bool(lead.get("enabled", false)):
		return
	if sprite_renderer == null or not sprite_renderer.has_method("resolve_current_sprite"):
		return
	# sprite_renderer.draw() 를 재호출하지 않는다 — resolve + 1 blit 이어야
	# 성능(바이퍼 듀얼글리치는 클론마다 풀 draw 를 돌려 수십 콜을 쓴다)과
	# 소스 계약(lingpet_body_draw 바이트 오프셋 씰) 양쪽이 성립한다.
	var resolved: Dictionary = sprite_renderer.resolve_current_sprite(
		sprite_context, player_visual_rect, player_move_active, player_pos, paddle_size, shake_offset
	)
	var texture: Variant = resolved.get("texture", null)
	if not (texture is Texture2D):
		return
	var region: Variant = resolved.get("region", null)
	if not (region is Rect2):
		return
	canvas.draw_texture_rect_region(
		texture,
		Rect2(player_visual_rect.position + _as_vector2(lead.get("offset", Vector2.ZERO), Vector2.ZERO), player_visual_rect.size),
		region,
		lead.get("color", POSSESSION_LEAD_AFTERIMAGE),
		false,
		true
	)


func _draw_possession_overlay(canvas: CanvasItem, plan: Dictionary) -> void:
	if canvas == null or not bool(plan.get("active", false)):
		return
	var u: float = float(plan.get("u", 1.0))

	var talisman: Texture2D = _get_possession_layer_texture(POSSESSION_TALISMAN_CACHE_KEY)
	if talisman != null:
		var talisman_size: Vector2 = talisman.get_size() * POSSESSION_TALISMAN_DRAW_SCALE * u
		var talisman_center: Vector2 = _as_vector2(plan.get("talisman_center", Vector2.ZERO), Vector2.ZERO)
		canvas.draw_texture_rect(
			talisman,
			Rect2(talisman_center - talisman_size * 0.5, talisman_size),
			false,
			Color(1.0, 1.0, 1.0, float(plan.get("talisman_alpha", 1.0)))
		)

	for mote_value in plan.get("motes", []):
		if not (mote_value is Dictionary):
			continue
		var mote: Dictionary = mote_value
		ImpactFlareTextureCache.draw_sparkle(
			canvas,
			_as_vector2(mote.get("pos", Vector2.ZERO), Vector2.ZERO),
			float(mote.get("radius", 1.0)),
			POSSESSION_SPIRIT_CORE,
			float(mote.get("alpha", 0.0))
		)

	ImpactFlareTextureCache.draw_glow(
		canvas,
		_as_vector2(plan.get("crown", Vector2.ZERO), Vector2.ZERO),
		float(plan.get("crown_radius", 1.0)),
		POSSESSION_SPIRIT_CORE,
		float(plan.get("crown_alpha", 0.0))
	)

	var sight: Dictionary = plan.get("sight", {})
	if bool(sight.get("enabled", false)):
		canvas.draw_line(
			_as_vector2(sight.get("from", Vector2.ZERO), Vector2.ZERO),
			_as_vector2(sight.get("to", Vector2.ZERO), Vector2.ZERO),
			Color(
				POSSESSION_SPIRIT_HALO.r,
				POSSESSION_SPIRIT_HALO.g,
				POSSESSION_SPIRIT_HALO.b,
				float(sight.get("alpha", 0.0))
			),
			float(sight.get("width", 2.0)),
			true
		)

	for meridian_value in plan.get("meridians", []):
		if not (meridian_value is Dictionary):
			continue
		var meridian: Dictionary = meridian_value
		canvas.draw_line(
			_as_vector2(meridian.get("from", Vector2.ZERO), Vector2.ZERO),
			_as_vector2(meridian.get("to", Vector2.ZERO), Vector2.ZERO),
			Color(
				POSSESSION_SPIRIT_HALO.r,
				POSSESSION_SPIRIT_HALO.g,
				POSSESSION_SPIRIT_HALO.b,
				float(meridian.get("alpha", 0.0))
			),
			float(meridian.get("width", 1.0)),
			true
		)

	var seal: Dictionary = plan.get("seal", {})
	if bool(seal.get("enabled", false)):
		var seal_texture: Texture2D = _get_possession_layer_texture(POSSESSION_SEAL_CACHE_KEY)
		if seal_texture != null:
			var seal_half: float = float(seal.get("half", 10.0))
			var seal_center: Vector2 = _as_vector2(seal.get("center", Vector2.ZERO), Vector2.ZERO)
			canvas.draw_texture_rect(
				seal_texture,
				Rect2(seal_center - Vector2(seal_half, seal_half), Vector2(seal_half, seal_half) * 2.0),
				false,
				Color(
					POSSESSION_CINNABAR.r,
					POSSESSION_CINNABAR.g,
					POSSESSION_CINNABAR.b,
					float(seal.get("alpha", 0.0))
				)
			)

	_draw_possession_label(canvas, plan)


func _draw_possession_label(canvas: CanvasItem, plan: Dictionary) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	# ThemeDB.fallback_font 를 유지할 것. 명시 NanumSquareB 로 바꾸면 JA/ZH
	# 글리프가 통째로 빈칸이 된다(feedback_godot_explicit_nanum_drops_cjk).
	var text: String = LanguageSettings.translate_text(POSSESSION_LABEL_TEXT)
	if text.strip_edges().is_empty():
		text = POSSESSION_LABEL_TEXT
	var alpha: float = clampf(float(plan.get("label_alpha", 0.0)), 0.0, 1.0)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, POSSESSION_LABEL_FONT_SIZE)
	var anchor: Vector2 = _as_vector2(plan.get("label_pos", Vector2.ZERO), Vector2.ZERO)
	var pos := Vector2(anchor.x - text_size.x * 0.5, anchor.y)
	canvas.draw_string(
		font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		POSSESSION_LABEL_FONT_SIZE, Color(POSSESSION_INK.r, POSSESSION_INK.g, POSSESSION_INK.b, 0.80 * alpha)
	)
	canvas.draw_string(
		font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		POSSESSION_LABEL_FONT_SIZE,
		Color(POSSESSION_SPIRIT_CORE.r, POSSESSION_SPIRIT_CORE.g, POSSESSION_SPIRIT_CORE.b, alpha)
	)


func _get_possession_layer_texture(key: String) -> Texture2D:
	if _possession_layer_cache == null:
		return null
	var cached: Texture2D = _possession_layer_cache.get_texture(key)
	if cached != null:
		return cached
	# 프리웜을 놓친 경우에도 핫 프레임을 통째로 태우지 않는다 — 프레임 예산
	# 안에서만 진행하고, 준비 전에는 그 레이어를 건너뛴다(1~2프레임 무해).
	var ops: Array = _build_possession_talisman_ops() if key == POSSESSION_TALISMAN_CACHE_KEY else _build_possession_seal_ops()
	return _possession_layer_cache.request_build(key, ops)


# 강신부(부적) 슬립. 좌표는 중심 (0,0) 기준, 2배 해상도로 굽는다.
# 획은 어떤 문자로도 읽히면 안 된다 — 세로 한자를 넣으면 ZH/JA 사용자에게
# 강시(僵屍) 부적으로 읽힌다. 비대칭 가로획 2개로 글리프 독법을 차단한다.
static func _build_possession_talisman_ops() -> Array:
	var body := PackedVector2Array([
		Vector2(-23.0, -40.0), Vector2(23.0, -40.0), Vector2(23.0, 32.0),
		Vector2(15.0, 48.0), Vector2(9.0, 34.0), Vector2(0.0, 54.0),
		Vector2(-9.0, 34.0), Vector2(-15.0, 48.0), Vector2(-23.0, 32.0),
	])
	var shadow := PackedVector2Array()
	for point in body:
		shadow.append(point + Vector2(2.0, 2.0))
	var ops: Array = [
		PillarOrbStaticLayerCache.make_polygon(shadow, POSSESSION_UNDER_SHADOW),
		PillarOrbStaticLayerCache.make_polygon(body, POSSESSION_TALISMAN_PAPER),
		PillarOrbStaticLayerCache.make_polygon(PackedVector2Array([
			Vector2(-16.0, -46.0), Vector2(16.0, -46.0), Vector2(16.0, -34.0), Vector2(-16.0, -34.0),
		]), POSSESSION_INK),
	]
	var border := Color(POSSESSION_CINNABAR.r, POSSESSION_CINNABAR.g, POSSESSION_CINNABAR.b, 0.85)
	var inset := [
		[Vector2(-19.0, -36.0), Vector2(19.0, -36.0)],
		[Vector2(19.0, -36.0), Vector2(19.0, 30.0)],
		[Vector2(19.0, 30.0), Vector2(-19.0, 30.0)],
		[Vector2(-19.0, 30.0), Vector2(-19.0, -36.0)],
	]
	for edge in inset:
		ops.append(PillarOrbStaticLayerCache.make_line(edge[0], edge[1], 1.5, border))
	# 세로 척추획 + 좌우 대칭 사선은 Ψ / 半 으로 읽힌다(픽셀 QA 1차). 척추를
	# 기울이고 가지를 한쪽으로 몰아 문자 독법을 깬다.
	ops.append(PillarOrbStaticLayerCache.make_line(Vector2(-3.0, -26.0), Vector2(3.0, 22.0), 4.5, POSSESSION_CINNABAR))
	ops.append(PillarOrbStaticLayerCache.make_line(Vector2(-14.0, -16.0), Vector2(-1.0, -6.0), 3.0, POSSESSION_CINNABAR))
	ops.append(PillarOrbStaticLayerCache.make_line(Vector2(12.0, -8.0), Vector2(1.0, 2.0), 3.0, POSSESSION_CINNABAR))
	ops.append(PillarOrbStaticLayerCache.make_line(Vector2(-11.0, 12.0), Vector2(2.0, 16.0), 2.5, POSSESSION_CINNABAR_DARK))
	ops.append(PillarOrbStaticLayerCache.make_circle(Vector2(9.0, 24.0), 2.4, POSSESSION_CINNABAR_DARK))
	return ops


# 가드 성공 낙관(인장). 회전은 텍스처에 굽고 런타임 회전은 쓰지 않는다
# (draw_set_transform 은 이 렌더러에서 금지).
static func _build_possession_seal_ops() -> Array:
	# 붉은 사각 테두리 + 사선은 "통행금지 표지"로 읽힌다(픽셀 QA 2차).
	# 실제 낙관처럼 주사 원판을 꽉 채우고 먹빛 획을 파낸다.
	var ops: Array = [
		PillarOrbStaticLayerCache.make_circle(Vector2.ZERO, 16.0, POSSESSION_CINNABAR_DARK),
		PillarOrbStaticLayerCache.make_circle(Vector2.ZERO, 13.5, POSSESSION_CINNABAR),
	]
	# 획은 어떤 문자로도 읽히면 안 된다. 대칭 가로획 + 중앙 세로획 조합은
	# 즉시 王/干 으로 읽히므로(픽셀 QA 1차 실패), 비대칭 사선 + 오프셋 점으로
	# 간다 — 문자 독법이 성립하지 않는 낙관 자국.
	# 원판을 가로지르는 긴 사선은 "통행금지"가 된다(픽셀 QA 3차). 원판 안을
	# 가로지르지 않는 짧은 획 3개만 쓴다 — 새겨진 낙관 자국.
	ops.append(PillarOrbStaticLayerCache.make_line(Vector2(-6.0, -4.5), Vector2(-1.5, 3.0), 3.0, POSSESSION_CINNABAR_DARK))
	ops.append(PillarOrbStaticLayerCache.make_line(Vector2(1.5, -6.0), Vector2(6.5, -2.0), 2.6, POSSESSION_CINNABAR_DARK))
	ops.append(PillarOrbStaticLayerCache.make_line(Vector2(0.5, 6.0), Vector2(6.5, 6.0), 2.6, POSSESSION_CINNABAR_DARK))
	return ops


func _draw_viper_air_strike_flash(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var timer: float = float(context.get("viper_air_strike_flash_timer", 0.0))
	if timer <= 0.0:
		return
	var duration: float = max(1.0, float(context.get("viper_air_strike_flash_duration", 18.0)))
	var progress: float = 1.0 - clamp(timer / duration, 0.0, 1.0)
	var lod_active: bool = ViperAirborneLod.is_air_strike_lod_active(context)
	if lod_active and progress > ViperAirborneLod.AIR_STRIKE_FLASH_VISIBLE_PROGRESS_CAP:
		return
	var fade: float = pow(1.0 - progress, 1.35)
	if lod_active:
		fade *= maxf(0.35, ViperAirborneLod.effect_scale(context))
	var pos: Vector2 = _as_vector2(context.get("viper_air_strike_flash_pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
	var height_ratio: float = clamp(float(context.get("viper_air_strike_flash_height_ratio", 0.0)), 0.0, 1.0)
	var radius: float = 34.0 + progress * 42.0 + height_ratio * 18.0
	if lod_active:
		radius *= 0.88
	var cyan := Color(0.35, 1.0, 1.0)

	if not lod_active:
		ImpactFlareTextureCache.draw_burst(canvas, pos, radius * 1.15, cyan, 0.30 * fade)
	ImpactFlareTextureCache.draw_glow(canvas, pos, radius * 0.72, cyan, 0.28 * fade)
	if not lod_active or progress < 0.40:
		ImpactFlareTextureCache.draw_sparkle(canvas, pos, max(20.0, radius * 0.34), Color(1.0, 0.94, 0.45), 0.48 * fade)
	ImpactShockwaveTextureCache.draw_full_ring(canvas, pos, radius * 0.62, cyan, 0.30 * fade)


func _draw_viper_jetpack_effects(
	canvas: CanvasItem,
	context: Dictionary,
	shake_offset: Vector2,
	player_visual_rect: Rect2,
	player_pos: Vector2,
	paddle_size: Vector2
) -> void:
	if str(context.get("selected_character_type", "smasher")) != "viper":
		return
	# When the hover sprite sheet is loaded, the jetpack glow + thrust read is
	# already baked into the per-frame sheet (purple back-glow + body pose).
	# Skip the procedural particle trail and nozzle pulse glow so the visual
	# does not double up. Fall back to the procedural effect only when the
	# sheet failed to load (so vipers running on a partial asset set still
	# get a thrust read).
	if bool(context.get("has_viper_hover_sheet", false)):
		return
	var particle_list: Variant = context.get("viper_jetpack_particles", [])
	if particle_list is Array:
		var lod_scale: float = ViperAirborneLod.effect_scale(context)
		var particle_index: int = 0
		var particle_stride: int = 2 if lod_scale < 0.66 else 1
		for particle in particle_list:
			particle_index += 1
			if particle_stride > 1 and particle_index % particle_stride != 0:
				continue
			if not (particle is Dictionary):
				continue
			var p: Dictionary = particle
			var life: float = float(p.get("life", 0.0))
			var max_life: float = max(0.001, float(p.get("max_life", 1.0)))
			var alpha: float = clamp(life / max_life, 0.0, 1.0)
			var pos: Vector2 = _as_vector2(p.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
			var color: Color = p.get("color", Color(0.35, 1.0, 1.0, 1.0))
			var size: float = float(p.get("size", 4.0)) * (0.65 + alpha * 0.45)
			if bool(p.get("smoke", false)):
				canvas.draw_circle(pos, size * 1.4, Color(color.r, color.g, color.b, 0.18 * alpha))
				canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.26 * alpha))
			else:
				canvas.draw_circle(pos, size * 2.0, Color(0.24, 0.88, 1.0, 0.18 * alpha))
				canvas.draw_circle(pos, size, Color(color.r, color.g, color.b, 0.86 * alpha))
				canvas.draw_circle(pos, max(1.0, size * 0.42), Color(1.0, 0.94, 0.45, 0.84 * alpha))
	if not bool(context.get("viper_jetpack_active", false)):
		return
	var center_x: float = player_pos.x + paddle_size.x * 0.5 + shake_offset.x
	var nozzle_y: float = min(
		player_visual_rect.position.y + player_visual_rect.size.y - 14.0,
		player_pos.y + paddle_size.y + 5.0 + shake_offset.y
	)
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.045)
	for side in [-1.0, 1.0]:
		var nozzle := Vector2(center_x + side * 22.0, nozzle_y)
		canvas.draw_circle(nozzle, 15.0 + pulse * 4.0, Color(0.0, 0.82, 1.0, 0.15))
		canvas.draw_circle(nozzle + Vector2(0.0, 10.0), 10.0 + pulse * 3.0, Color(0.18, 0.92, 1.0, 0.45))
		canvas.draw_circle(nozzle + Vector2(0.0, 16.0), 6.0 + pulse * 2.0, Color(1.0, 0.78, 0.26, 0.74))


# Procedural flame embers that drift below the hover sheet's baked-in
# jetpack flame. Stateless — uses Time.get_ticks_msec() + per-slot phase
# offsets so the stream is continuous without spawn/lifetime bookkeeping.
# Only fires while the hover sheet is rendering (airborne) so the embers
# match the on-sheet purple jetpack glow.
const _HOVER_EMBER_SLOT_COUNT := 8
const _HOVER_EMBER_CYCLE_MS := 820.0
const _HOVER_EMBER_FALL_DISTANCE := 72.0
const _HOVER_EMBER_LATERAL_SPREAD := 14.0
# Origin Y is a fraction of player_visual_rect.size.y measured from the top.
# 0.62 = roughly hip / upper-leg level on the chibi sprite, which is where
# the hover sheet's two purple flame plumes terminate. Tune this if a future
# hover sheet repositions the flame.
const _HOVER_EMBER_ORIGIN_Y_RATIO := 0.62


func _draw_viper_hover_flame_embers(
	canvas: CanvasItem,
	context: Dictionary,
	shake_offset: Vector2,
	player_visual_rect: Rect2
) -> void:
	if str(context.get("selected_character_type", "smasher")) != "viper":
		return
	if not bool(context.get("has_viper_hover_sheet", false)):
		return
	if not bool(context.get("viper_jetpack_airborne", false)):
		return
	if ViperAirborneRenderToggles.is_hover_embers_disabled():
		return
	# Origin: where the hover sheet's purple jet flame visibly ends — roughly
	# hip-level on the chibi sprite, NOT the feet. The plumes in the sheet
	# trail down to about 60-65% of the cell height; spawning embers below
	# the feet (cell bottom) would read as "particles appearing under boots"
	# instead of "embers dropping out of the jet exhaust".
	var origin_x: float = player_visual_rect.position.x + player_visual_rect.size.x * 0.5 + shake_offset.x
	var origin_y: float = player_visual_rect.position.y + player_visual_rect.size.y * _HOVER_EMBER_ORIGIN_Y_RATIO + shake_offset.y
	var time_ms: float = float(Time.get_ticks_msec())
	var slot_count: int = _HOVER_EMBER_SLOT_COUNT
	var lod_scale: float = ViperAirborneLod.effect_scale(context)
	if lod_scale < 0.99:
		slot_count = max(1, int(ceil(float(_HOVER_EMBER_SLOT_COUNT) * lod_scale)))
	for slot in range(slot_count):
		var slot_offset_ms: float = float(slot) * (_HOVER_EMBER_CYCLE_MS / float(slot_count))
		var phase: float = fmod(time_ms + slot_offset_ms, _HOVER_EMBER_CYCLE_MS) / _HOVER_EMBER_CYCLE_MS
		var lateral_seed: float = sin(float(slot) * 1.91 + time_ms * 0.0009) * _HOVER_EMBER_LATERAL_SPREAD
		var fall: float = phase * _HOVER_EMBER_FALL_DISTANCE
		var pos := Vector2(origin_x + lateral_seed * (0.4 + phase * 0.6), origin_y + fall)
		var fade: float = 1.0 - phase
		var size: float = (3.6 - phase * 2.4) * fade
		if size <= 0.4:
			continue
		# Purple-violet flame palette matching the hover sheet's jetpack glow.
		canvas.draw_circle(pos, size * 1.8, Color(0.55, 0.30, 0.95, 0.16 * fade))
		canvas.draw_circle(pos, size, Color(0.78, 0.55, 1.0, 0.78 * fade))
		canvas.draw_circle(pos, max(0.6, size * 0.45), Color(1.0, 0.92, 1.0, 0.85 * fade))


func _draw_viper_jetpack_hold_bar(
	canvas: CanvasItem,
	context: Dictionary,
	player_pos: Vector2,
	paddle_size: Vector2,
	shake_offset: Vector2
) -> void:
	if str(context.get("selected_character_type", "smasher")) != "viper":
		return
	var hold_ratio: float = clamp(float(context.get("viper_jetpack_hold_ratio", 0.0)), 0.0, 1.0)
	if hold_ratio <= 0.01 and not bool(context.get("viper_jetpack_overheat", false)):
		return
	if ViperAirborneRenderToggles.is_hold_bar_disabled():
		return
	# 40x3 bar vertically centered on PLAYER.centery. Anchored to the SAME
	# paddle-center, scale-tracking slot as the dash side gauge so it hugs the
	# character body at any paddle size; the hold bar keeps the inner slot and
	# the dash gauge shifts one bar-width + gap left when both are visible, so
	# the two read as a side-by-side pair instead of overlapping.
	var bar_height := 40.0
	var bar_width := 3.0
	var bar_x: float = dash_side_gauge_renderer.get_primary_bar_anchor_x(
		context, player_pos, paddle_size, shake_offset
	)
	var bar_y: float = player_pos.y + paddle_size.y * 0.5 - bar_height * 0.5 + shake_offset.y
	var rect := Rect2(bar_x, bar_y, bar_width, bar_height)
	canvas.draw_rect(rect.grow(2.0), Color(0.02, 0.05, 0.08, 0.58))
	var fill_color := Color(0.25, 0.95, 1.0, 0.88)
	var fill_ratio: float = 1.0 - hold_ratio
	if bool(context.get("viper_jetpack_overheat", false)):
		fill_color = Color(1.0, 0.22, 0.18, 0.92)
		fill_ratio = 1.0
	var fill_height: float = rect.size.y * fill_ratio
	canvas.draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - fill_height), Vector2(rect.size.x, fill_height)), fill_color)


const COMMANDO_B2_IDLE_WALK_WEAPON_OVERLAY_ENABLED := false


## B2 Commando weapon renderer.
##
## GATED OFF. The weapon-only overlay pass still produced perspective and
## grip mismatches, even with B2v2 muzzle-up assets. The shipped policy is
## now: idle / walk uses the empty-hand `base_grip` sheets, and firearms
## should appear only in weapon-specific firing sheets where the weapon,
## hands, arms, and body pose are authored together.
##
## Keep this code as a rollback / calibration reference until firing-sheet
## assets fully replace the transitional overlay work.
func _draw_commando_weapon_b2_overlay(
	canvas: CanvasItem,
	context: Dictionary,
	player_visual_rect: Rect2
) -> void:
	if not COMMANDO_B2_IDLE_WALK_WEAPON_OVERLAY_ENABLED:
		return
	if String(context.get("selected_character_type", "")) != "soldier":
		return
	if not bool(context.get("commando_weapon_b2_renderable", false)):
		return
	if bool(context.get("commando_attack_active", false)) or bool(context.get("player_hit_active", false)):
		return
	if bool(context.get("commando_pistol_fire_active", false)):
		return
	if bool(context.get("commando_radio_call_active", false)):
		return
	if bool(context.get("player_victory_active", false)) or bool(context.get("player_defeat_active", false)):
		return
	if bool(context.get("player_wheel_spin_active", false)):
		return

	var weapon_texture: Variant = context.get("commando_weapon_b2_texture", null)
	if not (weapon_texture is Texture2D):
		return
	var anchor_ref: Vector2 = _as_vector2(context.get("commando_weapon_b2_anchor", Vector2.ZERO), Vector2.ZERO)
	var pivot_ref: Vector2 = _as_vector2(context.get("commando_weapon_b2_pivot_primary", Vector2.ZERO), Vector2.ZERO)
	var draw_size_ref: Vector2 = _as_vector2(context.get("commando_weapon_b2_draw_size", Vector2.ZERO), Vector2.ZERO)
	if draw_size_ref.x <= 0.0 or draw_size_ref.y <= 0.0:
		return
	var flip_h: bool = bool(context.get("commando_weapon_b2_flip_h", false))

	const REF_CELL := Vector2(160.0, 160.0)
	var scale := Vector2(player_visual_rect.size.x / REF_CELL.x, player_visual_rect.size.y / REF_CELL.y)
	var anchor_screen: Vector2 = player_visual_rect.position + Vector2(anchor_ref.x * scale.x, anchor_ref.y * scale.y)
	var pivot_scaled := Vector2(pivot_ref.x * scale.x, pivot_ref.y * scale.y)
	var draw_size := Vector2(draw_size_ref.x * scale.x, draw_size_ref.y * scale.y)
	var pivot_for_draw := Vector2(draw_size.x - pivot_scaled.x, pivot_scaled.y) if flip_h else pivot_scaled
	var top_left: Vector2 = anchor_screen - pivot_for_draw
	var rotation_degrees: float = float(context.get("commando_weapon_b2_frame_rot", 0.0)) + float(context.get("commando_weapon_b2_base_rot", 0.0))
	var modulate: Color = _as_color(context.get("player_sprite_modulate", Color.WHITE), Color.WHITE)
	var weapon_texture_typed: Texture2D = weapon_texture
	if abs(rotation_degrees) <= 0.01:
		var dest_rect := Rect2(top_left + Vector2(draw_size.x, 0.0), Vector2(-draw_size.x, draw_size.y)) if flip_h else Rect2(top_left, draw_size)
		canvas.draw_texture_rect(weapon_texture_typed, dest_rect, false, modulate)
		return
	_draw_commando_weapon_b2_rotated(
		canvas,
		weapon_texture_typed,
		anchor_screen,
		pivot_for_draw,
		draw_size,
		rotation_degrees,
		modulate,
		flip_h
	)


func _draw_commando_weapon_b2_rotated(
	canvas: CanvasItem,
	texture: Texture2D,
	anchor_screen: Vector2,
	pivot_scaled: Vector2,
	draw_size: Vector2,
	rotation_degrees: float,
	modulate: Color,
	flip_h: bool
) -> void:
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var radians: float = deg_to_rad(rotation_degrees)
	var cos_a: float = cos(radians)
	var sin_a: float = sin(radians)
	var offsets := [
		Vector2(-pivot_scaled.x, -pivot_scaled.y),
		Vector2(draw_size.x - pivot_scaled.x, -pivot_scaled.y),
		Vector2(draw_size.x - pivot_scaled.x, draw_size.y - pivot_scaled.y),
		Vector2(-pivot_scaled.x, draw_size.y - pivot_scaled.y),
	]
	var points := PackedVector2Array()
	for offset in offsets:
		points.append(anchor_screen + Vector2(
			offset.x * cos_a - offset.y * sin_a,
			offset.x * sin_a + offset.y * cos_a
		))
	var uvs := PackedVector2Array([
		Vector2(1.0, 0.0) if flip_h else Vector2(0.0, 0.0),
		Vector2(0.0, 0.0) if flip_h else Vector2(1.0, 0.0),
		Vector2(0.0, 1.0) if flip_h else Vector2(1.0, 1.0),
		Vector2(1.0, 1.0) if flip_h else Vector2(0.0, 1.0),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


# Per-firearm weapon overlay system (Phase 3 of commando weapon-swap visuals).
# When the equipped firearm is anything other than `pistol` (the default visual
# baked into the idle/walk_* base sheets), the matching overlay sprite is
# blitted on top of the base character at a per-direction anchor so the
# rifle / launcher / trap / drone visually replaces the pistol that is drawn
# into the base sheet.
#
# Skipped in three cases: (1) base weapon = pistol, (2) attack/pistol-fire
# animation is active (those poses do not match the static low-ready overlay),
# (3) victory/defeat result animation is playing.
#
# Anchors are authored in 160x160 reference-cell coordinates inside
# `battle_draw_actor_context.gd`; the renderer scales them to the actual
# `player_visual_rect` size.
## Option A overlay path is GATED OFF and superseded by the B2 anchor-table
## system described in `.tmp/commando_b2_asset_contract.md`. The overlay
## sprites it drives (`commando_weapon_overlay_*.png`) bake the gripping
## hands into the weapon image, which fights the chibi's own hand pixels
## and produces visible arm doubling and offset weapon detachment.
##
## This function and its associated context fields are kept around as
## reference and as a hot-swap fallback during the B2 transition. Do NOT
## flip this constant back to `true` without first removing the baked
## hands from every weapon overlay PNG; otherwise the broken visual ships.
const OPTION_A_OVERLAY_ENABLED := false


func _draw_commando_weapon_overlay(
	canvas: CanvasItem,
	context: Dictionary,
	player_visual_rect: Rect2,
	player_move_active: bool
) -> void:
	if not OPTION_A_OVERLAY_ENABLED:
		return
	if String(context.get("selected_character_type", "")) != "soldier":
		return
	var weapon_id: String = String(context.get("commando_current_weapon_id", "pistol"))
	if weapon_id == "pistol" or weapon_id == "commando_pistol":
		return
	var overlay_texture: Variant = context.get("commando_weapon_overlay_texture", null)
	if not (overlay_texture is Texture2D):
		return
	if bool(context.get("commando_attack_active", false)):
		return
	if bool(context.get("commando_pistol_fire_active", false)):
		return
	if bool(context.get("commando_radio_call_active", false)):
		return
	if bool(context.get("player_victory_active", false)) or bool(context.get("player_defeat_active", false)):
		return

	var direction: int = int(context.get("player_walk_direction", 1))
	var anchor: Vector2
	var flip_h: bool = false
	if not player_move_active:
		anchor = _as_vector2(context.get("commando_weapon_overlay_anchor_back", Vector2.ZERO), Vector2.ZERO)
	elif direction < 0:
		anchor = _as_vector2(context.get("commando_weapon_overlay_anchor_left", Vector2.ZERO), Vector2.ZERO)
		flip_h = bool(context.get("commando_weapon_overlay_flip_h_for_walk_left", false))
	else:
		anchor = _as_vector2(context.get("commando_weapon_overlay_anchor_right", Vector2.ZERO), Vector2.ZERO)

	var draw_size_ref: Vector2 = _as_vector2(context.get("commando_weapon_overlay_draw_size", Vector2.ZERO), Vector2.ZERO)
	if draw_size_ref.x <= 0.0 or draw_size_ref.y <= 0.0:
		return

	const REF_CELL := Vector2(160.0, 160.0)
	var scale_x: float = player_visual_rect.size.x / REF_CELL.x
	var scale_y: float = player_visual_rect.size.y / REF_CELL.y
	var overlay_pos: Vector2 = player_visual_rect.position + Vector2(anchor.x * scale_x, anchor.y * scale_y)
	var overlay_size: Vector2 = Vector2(draw_size_ref.x * scale_x, draw_size_ref.y * scale_y)
	var overlay_texture_typed: Texture2D = overlay_texture
	var dest_rect: Rect2
	if flip_h:
		# Negative width flips the texture horizontally during draw.
		dest_rect = Rect2(overlay_pos + Vector2(overlay_size.x, 0.0), Vector2(-overlay_size.x, overlay_size.y))
	else:
		dest_rect = Rect2(overlay_pos, overlay_size)
	canvas.draw_texture_rect(overlay_texture_typed, dest_rect, false)
