extends Node2D

# 콜드부트 시네마틱 Node2D 호스트(CB3) — mythic v2 패턴 포크. 타임라인/
# 프레젠테이션 플랜(CB1/CB2)의 스냅샷과 1회성 전이 이벤트를 외부 update
# 드라이버가 밀어 넣는다(_process 없음 — 모달 물리 정지 중에도 같은
# 드라이버 틱으로 돈다). §5 매니페스트 에셋(섀시/카트리지/링파츠/이그니션
# 시트)을 텍스처 우선으로 그리고, 부재 시 절차 드로 degraded 폴백을
# 유지한다(예약 에셋 per-frame re-stat 트랩 금지 — 로드는 prewarm 1회).
const PerkFusionColdBootTimelineState := preload("res://scripts/characters/perk_fusion_cold_boot_timeline_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const PerkFusionIconKey := preload("res://scripts/characters/perk_fusion_icon_key.gd")

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

# 카트리지 페이스 플레이트(에셋 실측 frac): 좌 x=0.442(우는 미러 1-x),
# y=0.510, 아이콘 스팬 32px — 커밋된 재료 퍽 아이콘을 B0~B3 내내
# 플레이트에 합성한다(카트리지 정체성 연속 계약, 소멸은 B4 코어 합체만).
const CARTRIDGE_DRAW_HEIGHT := 96.0
const CARTRIDGE_PLATE_CENTER_X_FRAC := 0.442
const CARTRIDGE_PLATE_CENTER_Y_FRAC := 0.510
const CARTRIDGE_PLATE_ICON_SPAN := 32.0
# B4 코어 페이스 대각 합성 융합 아이콘(§3 B4 계약 — prepare_fusion_pair_icon
# 재사용): 합성은 부트 진입 프리웜이 소유하고 draw는 캐시 소비만 한다.
const CORE_FACE_ICON_SPAN := 52.0

# B4 각성 모듈 = 몸-마운트 링파츠 전개 스펙: 모듈별 앵커 각/폭/회전이
# 다르다(균일 72px 정사각 즉시 배치 금지 계약). 회전은 draw_set_transform
# 트랩을 피해 정점 직접 계산 + 정규화 UV draw_polygon으로 그린다.
const MODULE_DEPLOY_SPECS := [
	{"key": "module_shoulder_pod", "angle": -PI * 0.5, "width": 88.0, "rotation": 0.0},
	{"key": "module_collar_ring", "angle": PI * 5.0 / 6.0, "width": 58.0, "rotation": PI * 5.0 / 6.0 + PI * 0.5},
	{"key": "module_gem_plate", "angle": PI / 6.0, "width": 66.0, "rotation": PI / 6.0 + PI * 0.5},
]

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
static var _icon_renderer: Object = null

var _boot_active := false
var _boot_snapshot: Dictionary = {}
var _event_pulse := 0.0
var _last_events: Array = []
var consumed_event_count := 0
var _prepared_icon_lookup: Dictionary = {}
var _prepared_pair_icon_id := ""


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
	if _icon_renderer == null:
		_icon_renderer = RuntimePerkIconRenderer.new()
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


# 부트 진입 에지(모달당 1회, 이산 시점): 커밋 record의 재료 아이콘과 B4
# 코어 페이스 대각 합성쌍을 프리웜한다 — has_icon()/prepare_fusion_pair_icon
# 이 로드·합성을 소유하므로 draw 경로는 캐시 히트만 탄다. 아이콘이 없는
# id는 lookup에서 제외해 draw 재시도(로더는 성공만 캐시 — 부재 에셋
# per-frame re-stat 트랩)를 원천 차단한다.
func prepare_committed_icons(record: Dictionary) -> void:
	_prepared_icon_lookup = {}
	_prepared_pair_icon_id = ""
	if _icon_renderer == null:
		return
	var sources: Array = record.get("sources", []) as Array
	for source_value: Variant in sources:
		var source_id := str(source_value)
		if not source_id.is_empty() and bool(_icon_renderer.has_icon(source_id)):
			_prepared_icon_lookup[source_id] = true
	var pair_id: String = PerkFusionIconKey.build(
		str(record.get("fusion_id", "")),
		int(record.get("created_revision", 0)),
		sources
	)
	# publish-on-success: prepare가 실패하면 id를 게시하지 않는다 — draw가
	# 미합성 키로 소유 폴백만 반복 렌더하는 것을 막는 계약.
	if (
		pair_id.begins_with(PerkFusionIconKey.PREFIX)
		and bool(_icon_renderer.prepare_fusion_pair_icon(
			pair_id, Vector2(CORE_FACE_ICON_SPAN, CORE_FACE_ICON_SPAN), true
		))
	):
		_prepared_pair_icon_id = pair_id


func get_prepared_pair_icon_id() -> String:
	return _prepared_pair_icon_id


func get_prepared_icon_ids() -> Array:
	var ids: Array = _prepared_icon_lookup.keys()
	ids.sort()
	return ids


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
	_prepared_icon_lookup = {}
	_prepared_pair_icon_id = ""
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
			_draw_docked_bays(center)
			_draw_boot_gauge(center, progress, plan)
		PerkFusionColdBootTimelineState.BEAT_IGNITION_CREST:
			_draw_docked_bays(center)
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
	# B0: 좌우 레일에서 카트리지 2기가 중앙 베이로 활주 — 각 페이스가
	# 자기 재료 퍽 아이콘을 싣고 이동한다(정체성 보존, _draw_cartridge 소관).
	var travel: float = lerpf(240.0, 46.0, progress)
	for side: int in [-1, 1]:
		_draw_cartridge(center + Vector2(float(side) * travel, 0.0), side)


func _draw_twist_lock(center: Vector2, progress: float) -> void:
	# B1: 링 칼라 회전-스냅 체결.
	var snap_angle: float = lerpf(0.62, 0.0, progress)
	for side: int in [-1, 1]:
		_draw_cartridge(center + Vector2(float(side) * 46.0, 0.0), side)
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


# B2/B3: 도킹된 카트리지 유지 — 점등 섀시에서 베이가 다시 비면 카트리지
# 정체성 연속이 끊긴다. 카트리지 소멸은 B4 코어 합체 시점뿐이다.
func _draw_docked_bays(center: Vector2) -> void:
	for side: int in [-1, 1]:
		_draw_cartridge(center + Vector2(float(side) * 46.0, 0.0), side)


# 카트리지 셸(좌/우 미러; 텍스처 부재면 절차 폴백) + 커밋된 재료 퍽
# 아이콘을 페이스 플레이트에 합성.
func _draw_cartridge(cartridge_center: Vector2, side: int) -> void:
	var cartridge_texture: Texture2D = _texture("cartridge_left" if side < 0 else "cartridge_right")
	var icon_center := cartridge_center
	var icon_span := 24.0
	if cartridge_texture != null:
		var cartridge_h := CARTRIDGE_DRAW_HEIGHT
		var cartridge_w: float = cartridge_h * float(cartridge_texture.get_width()) / float(cartridge_texture.get_height())
		draw_texture_rect(
			cartridge_texture,
			Rect2(cartridge_center - Vector2(cartridge_w, cartridge_h) * 0.5, Vector2(cartridge_w, cartridge_h)),
			false
		)
		var plate_x_frac := CARTRIDGE_PLATE_CENTER_X_FRAC if side < 0 else 1.0 - CARTRIDGE_PLATE_CENTER_X_FRAC
		icon_center = cartridge_center + Vector2(
			(plate_x_frac - 0.5) * cartridge_w,
			(CARTRIDGE_PLATE_CENTER_Y_FRAC - 0.5) * cartridge_h
		)
		icon_span = CARTRIDGE_PLATE_ICON_SPAN
	else:
		var cartridge_rect := Rect2(cartridge_center - Vector2(20.0, 30.0), Vector2(40.0, 60.0))
		draw_rect(cartridge_rect, Color(CHASSIS_COLOR.lightened(0.12), 0.95))
		draw_rect(cartridge_rect, Color(ACCENT_COLOR, 0.8), false, 2.0)
	_draw_cartridge_face_icon(icon_center, icon_span, side)


# 커밋 record.sources(정확히 2, 정렬)를 좌/우 페이스에 1:1 합성 — 부트
# 진입 에지에서 프리웜된 아이콘만 그린다(캐시 히트 전용 draw 계약).
func _draw_cartridge_face_icon(icon_center: Vector2, icon_span: float, side: int) -> void:
	var sources: Array = (_boot_snapshot.get("committed_record", {}) as Dictionary).get("sources", []) as Array
	if _icon_renderer == null or sources.size() < 2:
		return
	var source_id := str(sources[0] if side < 0 else sources[1])
	if not _prepared_icon_lookup.has(source_id):
		return
	_icon_renderer.draw_icon(
		self,
		source_id,
		Rect2(icon_center - Vector2(icon_span, icon_span) * 0.5, Vector2(icon_span, icon_span))
	)


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
	_draw_core_face_icon(center, progress)
	var brown_out_count: int = int(plan.get("brown_out_lane_count", 0))
	var ejected_count: int = int(plan.get("ejected_module_count", 0))
	var fault_total: int = brown_out_count + ejected_count
	for fault_index: int in range(mini(fault_total, GAUGE_SEGMENTS)):
		var fault_angle: float = TAU * float(fault_index) / float(maxi(fault_total, 1)) - PI * 0.5
		var fault_color := Color(FAULT_COLOR, 0.85) if fault_index < brown_out_count else Color(CHASSIS_COLOR.lightened(0.25), 0.95)
		draw_arc(center, 96.0, fault_angle, fault_angle + 0.30, 8, fault_color, 7.0)
	var deployed_count: int = int(plan.get("deployed_module_count", 0))
	for module_index: int in range(mini(deployed_count, MODULE_DEPLOY_SPECS.size())):
		_draw_awakened_module(center, module_index, progress)


# B4 코어 페이스: 통합 코어에 대각 합성 융합 아이콘 안착 — 리빌 패널과
# 같은 페이스 처리(암판+골드 헤어라인)로 가독과 검출 결정론을 확보한다.
# 합성 텍스처는 프리웜 캐시 소비 전용(draw 핫패스 재합성 없음 계약).
func _draw_core_face_icon(center: Vector2, progress: float) -> void:
	if _prepared_pair_icon_id == "" or _icon_renderer == null:
		return
	var icon_rect := Rect2(
		center - Vector2(CORE_FACE_ICON_SPAN, CORE_FACE_ICON_SPAN) * 0.5,
		Vector2(CORE_FACE_ICON_SPAN, CORE_FACE_ICON_SPAN)
	)
	var face_alpha: float = clampf(0.55 + 0.45 * progress, 0.0, 1.0)
	draw_rect(icon_rect.grow(5.0), Color(0.02, 0.03, 0.06, 0.92 * face_alpha))
	draw_rect(icon_rect.grow(5.0), Color(GOLD_COLOR, 0.8 * face_alpha), false, 1.5)
	_icon_renderer.draw_icon(self, _prepared_pair_icon_id, icon_rect, face_alpha)


# B4 SNAP OPEN: 모듈별 스태거 전개 — 베이 안쪽(림 내측)에서 섀시 림
# 마운트 지점으로 슬라이드+스냅 팝(즉시 배치 금지 계약). 몸(섀시)에
# 마운트되는 링파츠 read — 플로팅 링 금지. 회전 텍스처 quad는
# draw_set_transform 트랩을 피해 정점 직접 계산+정규화 UV draw_polygon.
func _draw_awakened_module(center: Vector2, module_index: int, progress: float) -> void:
	var spec: Dictionary = MODULE_DEPLOY_SPECS[module_index]
	var deploy: float = clampf((progress * 2.2 - float(module_index) * 0.28) / 0.45, 0.0, 1.0)
	if deploy <= 0.0:
		return
	var snap: float = 1.0 - pow(1.0 - deploy, 3.0)
	var pop: float = 1.0 + 0.16 * sin(deploy * PI)
	var mount_dir := Vector2(cos(float(spec["angle"])), sin(float(spec["angle"])))
	var module_center: Vector2 = center + mount_dir * lerpf(CHASSIS_RADIUS - 46.0, CHASSIS_RADIUS - 4.0, snap)
	var alpha: float = clampf(deploy * 1.8, 0.0, 1.0)
	var module_texture: Texture2D = _texture(str(spec["key"]))
	if module_texture == null:
		draw_circle(module_center, 12.0 * snap * pop, Color(GOLD_COLOR, 0.9 * alpha))
		draw_arc(module_center, maxf(1.0, 16.0 * snap * pop), 0.0, TAU, 24, Color(GOLD_COLOR, 0.5 * alpha), 2.0)
		return
	var half_w: float = float(spec["width"]) * 0.5 * (0.55 + 0.45 * snap) * pop
	var half_h: float = half_w * float(module_texture.get_height()) / float(module_texture.get_width())
	var rotation_rad := float(spec["rotation"])
	var axis_x := Vector2(cos(rotation_rad), sin(rotation_rad))
	var axis_y := Vector2(-axis_x.y, axis_x.x)
	var points := PackedVector2Array([
		module_center - axis_x * half_w - axis_y * half_h,
		module_center + axis_x * half_w - axis_y * half_h,
		module_center + axis_x * half_w + axis_y * half_h,
		module_center - axis_x * half_w + axis_y * half_h,
	])
	# draw_polygon 텍스처 UV는 반드시 정규화 [0,1](픽셀 rect 금지 트랩).
	var uvs := PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
	var modulate := Color(1.0, 1.0, 1.0, alpha)
	draw_polygon(points, PackedColorArray([modulate, modulate, modulate, modulate]), uvs, module_texture)
