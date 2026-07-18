extends Node2D

# 콜드부트 시네마틱 Node2D 호스트(CB3) — mythic v2 패턴 포크. 타임라인/
# 프레젠테이션 플랜(CB1/CB2)의 스냅샷과 1회성 전이 이벤트를 외부 update
# 드라이버가 밀어 넣는다(_process 없음 — 모달 물리 정지 중에도 같은
# 드라이버 틱으로 돈다). CB3는 절차 드로 스탠드인: CB4가 §5 매니페스트
# 에셋(섀시/카트리지/이그니션 시트)으로 교체한다. 미생성 에셋 경로는
# 여기 배선하지 않는다(예약 에셋 per-frame re-stat 트랩).
const PerkFusionColdBootTimelineState := preload("res://scripts/characters/perk_fusion_cold_boot_timeline_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

# §5 에셋 매니페스트(CB4b): 텍스처 우선 + 절차 드로 degraded 폴백. 존재
# 검사·로드는 prewarm 1회에서만(예약 에셋 per-frame re-stat 트랩 금지).
const ASSET_DIR := "res://assets/sprites/effects/perk_fusion_cold_boot/"
const CHASSIS_OFF_TEXTURE_PATH := ASSET_DIR + "cold_boot_chassis_off.png"
const CHASSIS_ON_TEXTURE_PATH := ASSET_DIR + "cold_boot_chassis_on.png"
const CARTRIDGE_LEFT_TEXTURE_PATH := ASSET_DIR + "cold_boot_cartridge_left.png"
const CARTRIDGE_RIGHT_TEXTURE_PATH := ASSET_DIR + "cold_boot_cartridge_right.png"
const MODULE_SHOULDER_POD_TEXTURE_PATH := ASSET_DIR + "cold_boot_module_shoulder_pod.png"
const MODULE_COLLAR_RING_TEXTURE_PATH := ASSET_DIR + "cold_boot_module_collar_ring.png"
const MODULE_GEM_PLATE_TEXTURE_PATH := ASSET_DIR + "cold_boot_module_gem_plate.png"
const IGNITION_SHEET_TEXTURE_PATH := ASSET_DIR + "cold_boot_ignition_ring_sheet.png"
# 아틀라스 그리드 권위: AutoSprite 4x4 = 16프레임(잘못된 그리드는 조용히
# 엉뚱한 셀을 자른다 — atlas grid authority 트랩).
const IGNITION_SHEET_COLS := 4
const IGNITION_SHEET_ROWS := 4
const IGNITION_SHEET_FRAMES := 16

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
static var _textures: Dictionary = {}

var _boot_active := false
var _boot_snapshot: Dictionary = {}
var _event_pulse := 0.0
var _last_events: Array = []
var consumed_event_count := 0


# §5 텍스처 프리웜(이산 시점 1회): 존재하는 에셋만 캐시에 올린다 —
# 부재 시 해당 조각은 절차 드로 폴백. _draw/_process 인스턴스화 금지.
static func prewarm_assets() -> void:
	if _assets_prewarmed:
		return
	var manifest := {
		"chassis_off": CHASSIS_OFF_TEXTURE_PATH,
		"chassis_on": CHASSIS_ON_TEXTURE_PATH,
		"cartridge_left": CARTRIDGE_LEFT_TEXTURE_PATH,
		"cartridge_right": CARTRIDGE_RIGHT_TEXTURE_PATH,
		"module_shoulder_pod": MODULE_SHOULDER_POD_TEXTURE_PATH,
		"module_collar_ring": MODULE_COLLAR_RING_TEXTURE_PATH,
		"module_gem_plate": MODULE_GEM_PLATE_TEXTURE_PATH,
		"ignition_sheet": IGNITION_SHEET_TEXTURE_PATH,
	}
	for texture_key: String in manifest.keys():
		var path := str(manifest[texture_key])
		if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
			continue
		var texture: Variant = ProjectResourceLoader.load_imported_texture(path)
		if texture is Texture2D:
			_textures[texture_key] = texture
	_assets_prewarmed = true


static func _texture(texture_key: String) -> Texture2D:
	var value: Variant = _textures.get(texture_key)
	return value if value is Texture2D else null


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
		PerkFusionColdBootTimelineState.BEAT_REVEAL:
			# B5 SETTLE은 렌더하지 않는다 — flow reveal 진입과 동시에 호스트가
			# 닫히고 모달 리빌 패널이 홀드를 소유한다(B5=핸드오프 공식 계약).
			_draw_core_reveal(center, progress, plan)
	if _event_pulse > 0.0:
		# 전이 순간 촉감 펄스(하드웨어 래치 CHNK 시각 앵커).
		draw_arc(center, CHASSIS_RADIUS + 18.0, 0.0, TAU, 48, Color(ACCENT_COLOR, 0.55 * _event_pulse), 3.0)


func _draw_chassis(center: Vector2) -> void:
	# 텍스처 우선: B0/B1=꺼짐 상태, B2 이후=점등 상태(부팅 램프의 기계 tell).
	var beat := str(_boot_snapshot.get("beat", ""))
	var chassis_key := "chassis_off" if beat in [
		PerkFusionColdBootTimelineState.BEAT_DOCK_IN,
		PerkFusionColdBootTimelineState.BEAT_TWIST_LOCK,
	] else "chassis_on"
	var chassis_texture: Texture2D = _texture(chassis_key)
	if chassis_texture != null:
		var span: float = (CHASSIS_RADIUS + 10.0) * 2.0
		draw_texture_rect(chassis_texture, Rect2(center - Vector2(span, span) * 0.5, Vector2(span, span)), false)
		return
	draw_circle(center, CHASSIS_RADIUS + 10.0, Color(CHASSIS_COLOR, 0.92))
	draw_arc(center, CHASSIS_RADIUS + 8.0, 0.0, TAU, 64, Color(ACCENT_COLOR, 0.22), 2.0)


func _draw_dock_in(center: Vector2, progress: float) -> void:
	# B0: 좌우 레일에서 카트리지 2기가 중앙 베이로 활주(정체성 보존은 CB4
	# 아이콘 오버레이 소관 — CB3는 셸 실루엣).
	var travel: float = lerpf(240.0, 46.0, progress)
	for side: int in [-1, 1]:
		var cartridge_center: Vector2 = center + Vector2(float(side) * travel, 0.0)
		if _draw_cartridge(cartridge_center, side):
			continue
		var cartridge_rect := Rect2(cartridge_center - Vector2(20.0, 30.0), Vector2(40.0, 60.0))
		draw_rect(cartridge_rect, Color(CHASSIS_COLOR.lightened(0.12), 0.95))
		draw_rect(cartridge_rect, Color(ACCENT_COLOR, 0.75), false, 2.0)


func _draw_twist_lock(center: Vector2, progress: float) -> void:
	# B1: 링 칼라 회전-스냅 체결.
	var snap_angle: float = lerpf(0.62, 0.0, progress)
	for side: int in [-1, 1]:
		var bay_center: Vector2 = center + Vector2(float(side) * 46.0, 0.0)
		if _draw_cartridge(bay_center, side):
			continue
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
	var ignition_sheet: Texture2D = _texture("ignition_sheet")
	if ignition_sheet != null:
		# AutoSprite 4x4 시트: 진행도→프레임. 픽셀 rect region(정규화 UV
		# 아님 — draw_texture_rect_region 계약).
		var frame_index: int = clampi(int(progress * float(IGNITION_SHEET_FRAMES)), 0, IGNITION_SHEET_FRAMES - 1)
		var cell_w: float = ignition_sheet.get_width() / float(IGNITION_SHEET_COLS)
		var cell_h: float = ignition_sheet.get_height() / float(IGNITION_SHEET_ROWS)
		var source_rect := Rect2(
			Vector2(float(frame_index % IGNITION_SHEET_COLS) * cell_w, float(frame_index / IGNITION_SHEET_COLS) * cell_h),
			Vector2(cell_w, cell_h)
		)
		var span: float = pulse_radius * 2.4
		draw_texture_rect_region(
			ignition_sheet,
			Rect2(center - Vector2(span, span) * 0.5, Vector2(span, span)),
			source_rect,
			Color(1.0, 1.0, 1.0, clampf(pulse_alpha + 0.25, 0.0, 1.0))
		)
	else:
		draw_arc(center, pulse_radius, 0.0, TAU, 64, Color(ACCENT_COLOR, pulse_alpha), 6.0)
	if bool(plan.get("ignition_surge", false)):
		draw_arc(center, pulse_radius * 0.86, 0.0, TAU, 64, Color(FAULT_COLOR, pulse_alpha * 0.9), 4.0)
	if bool(plan.get("ignition_dual_gold_ring", false)):
		draw_arc(center, pulse_radius * 0.78, 0.0, TAU, 64, Color(GOLD_COLOR, pulse_alpha), 4.0)
	if bool(plan.get("stabilizer_snap", false)):
		var coil_sweep: float = TAU * clampf(progress * 2.0, 0.0, 1.0)
		draw_arc(center, 84.0, -PI * 0.5, -PI * 0.5 + coil_sweep, 48, Color(CORE_STABLE_COLOR, 0.95), 5.0)


# 카트리지 텍스처 드로(좌/우 미러 셸): 텍스처 부재면 false — 절차 폴백.
func _draw_cartridge(cartridge_center: Vector2, side: int) -> bool:
	var cartridge_texture: Texture2D = _texture("cartridge_left" if side < 0 else "cartridge_right")
	if cartridge_texture == null:
		return false
	var cartridge_h := 96.0
	var cartridge_w: float = cartridge_h * float(cartridge_texture.get_width()) / float(cartridge_texture.get_height())
	draw_texture_rect(
		cartridge_texture,
		Rect2(cartridge_center - Vector2(cartridge_w, cartridge_h) * 0.5, Vector2(cartridge_w, cartridge_h)),
		false
	)
	return true


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
	var module_keys := ["module_shoulder_pod", "module_collar_ring", "module_gem_plate"]
	for module_index: int in range(mini(deployed_count, 3)):
		var module_angle: float = -PI * 0.5 + TAU * float(module_index) / 3.0
		var module_center: Vector2 = center + Vector2(cos(module_angle), sin(module_angle)) * (CHASSIS_RADIUS - 6.0)
		var module_texture: Texture2D = _texture(module_keys[module_index])
		if module_texture != null:
			var module_span := 72.0
			draw_texture_rect(module_texture, Rect2(module_center - Vector2(module_span, module_span) * 0.5, Vector2(module_span, module_span)), false)
			continue
		draw_circle(module_center, 12.0, Color(GOLD_COLOR, 0.9))
		draw_arc(module_center, 16.0, 0.0, TAU, 24, Color(GOLD_COLOR, 0.5), 2.0)
