extends Node2D

# 콜드부트 시네마틱 Node2D 호스트(CB3) — mythic v2 패턴 포크. 타임라인/
# 프레젠테이션 플랜(CB1/CB2)의 스냅샷과 1회성 전이 이벤트를 외부 update
# 드라이버가 밀어 넣는다(_process 없음 — 모달 물리 정지 중에도 같은
# 드라이버 틱으로 돈다). CB3는 절차 드로 스탠드인: CB4가 §5 매니페스트
# 에셋(섀시/카트리지/이그니션 시트)으로 교체한다. 미생성 에셋 경로는
# 여기 배선하지 않는다(예약 에셋 per-frame re-stat 트랩).
const PerkFusionColdBootTimelineState := preload("res://scripts/characters/perk_fusion_cold_boot_timeline_state.gd")

# 플랜 §2 팔레트 — 결과 신호 문법(시안=동기화/골드=각성/적=과부하).
const ACCENT_COLOR := Color(0.32, 0.86, 1.0)
const GOLD_COLOR := Color(1.0, 0.79, 0.27)
const FAULT_COLOR := Color(1.0, 0.48, 0.48)
const CORE_STABLE_COLOR := Color(0.45, 0.90, 1.0)
const CHASSIS_COLOR := Color(0.01, 0.015, 0.035)

const HOST_Z_INDEX := 110
const GAUGE_SEGMENTS := 16
const CHASSIS_RADIUS := 132.0
const EVENT_PULSE_DECAY := 4.0

static var _assets_prewarmed := false

var _boot_active := false
var _boot_snapshot: Dictionary = {}
var _event_pulse := 0.0
var _last_events: Array = []
var consumed_event_count := 0


# CB3의 프리웜은 정적 플래그+절차 드로 준비뿐이다(텍스처 0). CB4가 §5
# 에셋을 추가할 때 이 함수에 로드를 모으고, _draw/_process에서의
# 인스턴스화는 계속 금지한다(핫패스 lazy-init 트랩).
static func prewarm_assets() -> void:
	if _assets_prewarmed:
		return
	_assets_prewarmed = true


static func is_prewarmed() -> bool:
	return _assets_prewarmed


func _ready() -> void:
	z_index = HOST_Z_INDEX
	z_as_relative = false
	top_level = true
	visible = false


func is_boot_active() -> bool:
	return _boot_active


# 외부 드라이버 틱: 스냅샷(비트/progress/presentation)과 이번 틱에 드레인된
# 1회성 전이 이벤트를 받는다 — 이벤트는 여기서 촉감 펄스(CHNK/THUNK 계열)
# 엔벨로프로 소비된다(정확히-한-번 소비 계약의 실 소비자).
func sync_boot(snapshot: Dictionary, events: Array, delta: float) -> void:
	_boot_active = true
	visible = true
	_boot_snapshot = snapshot.duplicate(true)
	# 감쇠를 먼저, 신규 이벤트 펄스를 나중에 — 같은 호출의 delta가 방금
	# 도착한 전이 펄스를 소멸시키면 저프레임(delta>=0.25)에서 CHNK 촉감이
	# 통째로 사라진다.
	_event_pulse = maxf(0.0, _event_pulse - maxf(0.0, delta) * EVENT_PULSE_DECAY)
	if not events.is_empty():
		_event_pulse = 1.0
		_last_events = events.duplicate()
		consumed_event_count += events.size()
	queue_redraw()


func finish_boot() -> void:
	_boot_active = false
	visible = false
	_boot_snapshot = {}
	_event_pulse = 0.0
	_last_events = []
	queue_redraw()


func get_debug_boot_state() -> Dictionary:
	return {
		"boot_active": _boot_active,
		"beat": str(_boot_snapshot.get("beat", "")),
		"consumed_event_count": consumed_event_count,
		"last_events": _last_events.duplicate(),
		"event_pulse": _event_pulse,
	}


func _draw() -> void:
	if not _boot_active:
		return
	# 컨텍스트-폴백 사이징 금지: 풀스크린 앵커는 엔진 트루스에서만 읽는다.
	var view_size: Vector2 = get_viewport_rect().size
	var center: Vector2 = view_size * 0.5
	var beat := str(_boot_snapshot.get("beat", ""))
	var progress: float = clampf(float(_boot_snapshot.get("beat_progress", 0.0)), 0.0, 1.0)
	var plan: Dictionary = _boot_snapshot.get("presentation", {}) as Dictionary
	_draw_chassis(center)
	match beat:
		PerkFusionColdBootTimelineState.BEAT_DOCK_IN:
			_draw_dock_in(center, progress)
		PerkFusionColdBootTimelineState.BEAT_TWIST_LOCK:
			_draw_twist_lock(center, progress)
		PerkFusionColdBootTimelineState.BEAT_BOOT_POST:
			_draw_boot_gauge(center, progress, plan)
		PerkFusionColdBootTimelineState.BEAT_IGNITION_CREST:
			_draw_boot_gauge(center, 1.0, plan)
			_draw_ignition(center, progress, plan)
		PerkFusionColdBootTimelineState.BEAT_REVEAL, PerkFusionColdBootTimelineState.BEAT_SETTLE:
			_draw_core_reveal(center, progress, plan)
	if _event_pulse > 0.0:
		# 전이 순간 촉감 펄스(하드웨어 래치 CHNK 시각 앵커).
		draw_arc(center, CHASSIS_RADIUS + 18.0, 0.0, TAU, 48, Color(ACCENT_COLOR, 0.55 * _event_pulse), 3.0)


func _draw_chassis(center: Vector2) -> void:
	draw_circle(center, CHASSIS_RADIUS + 10.0, Color(CHASSIS_COLOR, 0.92))
	draw_arc(center, CHASSIS_RADIUS + 8.0, 0.0, TAU, 64, Color(ACCENT_COLOR, 0.22), 2.0)


func _draw_dock_in(center: Vector2, progress: float) -> void:
	# B0: 좌우 레일에서 카트리지 2기가 중앙 베이로 활주(정체성 보존은 CB4
	# 아이콘 오버레이 소관 — CB3는 셸 실루엣).
	var travel: float = lerpf(240.0, 46.0, progress)
	for side: int in [-1, 1]:
		var cartridge_center: Vector2 = center + Vector2(float(side) * travel, 0.0)
		var cartridge_rect := Rect2(cartridge_center - Vector2(20.0, 30.0), Vector2(40.0, 60.0))
		draw_rect(cartridge_rect, Color(CHASSIS_COLOR.lightened(0.12), 0.95))
		draw_rect(cartridge_rect, Color(ACCENT_COLOR, 0.75), false, 2.0)


func _draw_twist_lock(center: Vector2, progress: float) -> void:
	# B1: 링 칼라 회전-스냅 체결.
	var snap_angle: float = lerpf(0.62, 0.0, progress)
	for side: int in [-1, 1]:
		var bay_center: Vector2 = center + Vector2(float(side) * 46.0, 0.0)
		var bay_rect := Rect2(bay_center - Vector2(20.0, 30.0), Vector2(40.0, 60.0))
		draw_rect(bay_rect, Color(CHASSIS_COLOR.lightened(0.12), 0.95))
		draw_rect(bay_rect, Color(ACCENT_COLOR, 0.85), false, 2.0)
	draw_arc(center, 78.0, -PI * 0.5 + snap_angle, PI * 0.5 + snap_angle, 32, Color(ACCENT_COLOR, 0.85), 4.0)
	draw_arc(center, 78.0, PI * 0.5 + snap_angle, PI * 1.5 + snap_angle, 32, Color(ACCENT_COLOR, 0.85), 4.0)


func _draw_boot_gauge(center: Vector2, progress: float, plan: Dictionary) -> void:
	# B2: 세그먼트 원형 부팅 게이지(POST). 티어 tell은 데이터 구동:
	# stutter=앰버→적 명멸 세그먼트, overshoot=골드 2차 링.
	var lit_count: int = int(floor(progress * float(GAUGE_SEGMENTS)))
	var stutter_index: int = GAUGE_SEGMENTS / 2
	for segment_index: int in range(GAUGE_SEGMENTS):
		var start_angle: float = TAU * float(segment_index) / float(GAUGE_SEGMENTS) - PI * 0.5
		var end_angle: float = start_angle + TAU / float(GAUGE_SEGMENTS) * 0.78
		var segment_color := Color(ACCENT_COLOR, 0.16)
		if segment_index < lit_count:
			segment_color = Color(ACCENT_COLOR, 0.9)
			if bool(plan.get("boot_stutter", false)) and segment_index == stutter_index:
				var flicker: float = 0.5 + 0.5 * sin(progress * 34.0)
				segment_color = FAULT_COLOR.lerp(Color(GOLD_COLOR, 0.9), flicker)
		draw_arc(center, 96.0, start_angle, end_angle, 12, segment_color, 7.0)
	if bool(plan.get("boot_overshoot", false)) and progress > 0.9:
		draw_arc(center, 112.0, -PI * 0.5, -PI * 0.5 + TAU * (progress - 0.9) * 10.0, 48, Color(GOLD_COLOR, 0.95), 5.0)


func _draw_ignition(center: Vector2, progress: float, plan: Dictionary) -> void:
	# B3: 원반형 이그니션 링 펄스(빔 아님). surge=적 번짐, dual gold=골드
	# 2차 펄스, stabilizer_snap=시안 안정화 코일 스냅-인.
	var pulse_radius: float = lerpf(70.0, CHASSIS_RADIUS + 26.0, progress)
	var pulse_alpha: float = 1.0 - progress * 0.6
	draw_arc(center, pulse_radius, 0.0, TAU, 64, Color(ACCENT_COLOR, pulse_alpha), 6.0)
	if bool(plan.get("ignition_surge", false)):
		draw_arc(center, pulse_radius * 0.86, 0.0, TAU, 64, Color(FAULT_COLOR, pulse_alpha * 0.9), 4.0)
	if bool(plan.get("ignition_dual_gold_ring", false)):
		draw_arc(center, pulse_radius * 0.78, 0.0, TAU, 64, Color(GOLD_COLOR, pulse_alpha), 4.0)
	if bool(plan.get("stabilizer_snap", false)):
		var coil_sweep: float = TAU * clampf(progress * 2.0, 0.0, 1.0)
		draw_arc(center, 84.0, -PI * 0.5, -PI * 0.5 + coil_sweep, 48, Color(CORE_STABLE_COLOR, 0.95), 5.0)


func _draw_core_reveal(center: Vector2, progress: float, plan: Dictionary) -> void:
	# B4/B5: 통합 코어 안착. 결함 카운트=죽은 세그먼트/암전 베이, 각성
	# 카운트=골드 위성 포드(문자 그대로 하드웨어 전개 — CB4가 링파츠 아트로
	# 교체).
	var tier := str(plan.get("tier", "success"))
	var core_color := ACCENT_COLOR
	if tier == "byproduct":
		core_color = GOLD_COLOR
	elif tier == "stable":
		core_color = CORE_STABLE_COLOR
	draw_circle(center, 42.0, Color(core_color, 0.28 + 0.22 * progress))
	draw_arc(center, 52.0, 0.0, TAU, 48, Color(core_color, 0.9), 3.0)
	var brown_out_count: int = int(plan.get("brown_out_lane_count", 0))
	var ejected_count: int = int(plan.get("ejected_module_count", 0))
	var fault_total: int = brown_out_count + ejected_count
	for fault_index: int in range(mini(fault_total, GAUGE_SEGMENTS)):
		var fault_angle: float = TAU * float(fault_index) / float(maxi(fault_total, 1)) - PI * 0.5
		var fault_color := Color(FAULT_COLOR, 0.85) if fault_index < brown_out_count else Color(CHASSIS_COLOR.lightened(0.25), 0.95)
		draw_arc(center, 96.0, fault_angle, fault_angle + 0.30, 8, fault_color, 7.0)
	var deployed_count: int = int(plan.get("deployed_module_count", 0))
	for module_index: int in range(mini(deployed_count, 3)):
		var module_angle: float = -PI * 0.5 + TAU * float(module_index) / 3.0
		var module_center: Vector2 = center + Vector2(cos(module_angle), sin(module_angle)) * (CHASSIS_RADIUS - 6.0)
		draw_circle(module_center, 12.0, Color(GOLD_COLOR, 0.9))
		draw_arc(module_center, 16.0, 0.0, TAU, 24, Color(GOLD_COLOR, 0.5), 2.0)
