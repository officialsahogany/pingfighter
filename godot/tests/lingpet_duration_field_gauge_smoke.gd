extends SceneTree

# 수호령 SD 캐릭터 좌측 세로 지속시간 게이지 씰.
#
# 지키는 계약:
#  1. 게이지는 SD 몸통 "왼쪽"에 서고 세로다(높이 > 폭). 몸통 반폭 + 간격만큼
#     떨어져 스프라이트를 가리지 않는다.
#  2. 채움은 바닥 앵커 -- 남은 지속시간이 줄면 위에서 내려온다.
#  3. 경고 / 위험 임계값과 색은 TAB 캐릭터 정보 패널의 지속시간 스트립과
#     같은 소유자를 읽는다(두 표시면 락스텝).
#  4. 풀이 아직 굴려지지 않았거나(pool_max=0) 게이지가 꺼진 호출자에서는
#     아무것도 그리지 않는다(fail-closed).
#  5. ★본체가 화면 밖이면 게이지도 없다. 출격형(sortie_flight) 수호령은
#     x=-190 같은 화면 밖에서 진입/퇴장하면서 motion_visible=true 이므로,
#     게이지 X 를 무조건 필드 안으로 클램프하면 본체 없이 게이지만 좌측 끝에
#     떠 있는 유령 UI 가 된다. 밀어 넣은 결과가 몸통을 침범하면 숨겨야 한다.
#  5b. ★좌벽 보정 후의 "몸통 침범" 판정도 트랙이 아니라 장식 외곽 기준이어야
#     한다. 공통 패스는 본체 뒤에 그려지므로 뒷판이 몸통 가장자리를 덮는다.
#     화면 밖도 필러 유출도 아닌 좁은 전환 구간(104px x=40, 82px x=33)이라
#     경계 레그만으로는 빠져나간다.
#  6. ★게이지는 본체 표현 분기(일반 SD / 클릭 교감 반응 시트 / 스타코일 바인드)
#     "뒤"의 공통 패스 한 곳에서만 나간다. 분기 안에 넣으면 그 표현이 선택된
#     프레임에 게이지만 끊긴다(클릭 교감 중 게이지 소실이 실제 회귀였다).
#
# 5/6 번은 각각 회귀에서 역산한 계약이라 레그를 지운 채로는 GREEN 이 될 수 없다.

const LingpetDurationFieldGaugeRenderer := preload("res://scripts/lingpet/lingpet_duration_field_gauge_renderer.gd")
const LingpetCompanionMotionState := preload("res://scripts/lingpet/lingpet_companion_motion_state.gd")
const LingpetCompanionRenderer := preload("res://scripts/lingpet/lingpet_companion_renderer.gd")
const LingpetCompanionClickReactionState := preload("res://scripts/lingpet/lingpet_companion_click_reaction_state.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const LingpetDurationVitality := preload("res://scripts/hud/character_info_overlay_lingpet_vitality_projection.gd")

const EGG_RUNTIME_PATH := "res://scripts/lingpet/lingpet_egg_runtime.gd"
const COMPANION_RENDERER_PATH := "res://scripts/lingpet/lingpet_companion_renderer.gd"

const PROBE_CENTER := Vector2(380.0, 690.0)
# 실제 patrol 좌측 한계. 이 위치의 큰 몸통 펫(104px)이 게이지를 잃으면
# 정상 플레이 중 좌벽 근처에서 게이지가 깜빡인다.
const PATROL_LEFT_LIMIT_X := LingpetCompanionMotionState.COMPANION_PATROL_EDGE_MARGIN
const SORTIE_OFFSCREEN_LEFT_X := -190.0

var _failures: Array[String] = []


class GaugeDrawProbe:
	extends Node2D

	var config: Dictionary = {}
	var center := Vector2.ZERO
	var alpha := 1.0
	var draw_count := 0
	var last_layout: Dictionary = {}

	func _draw() -> void:
		draw_count += 1
		last_layout = LingpetDurationFieldGaugeRenderer.draw_gauge(self, center, config, alpha)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_hidden_when_disabled_or_unrolled()
	_verify_left_side_vertical_geometry()
	_verify_fill_is_bottom_anchored()
	_verify_color_keys_lockstep_with_tab_panel()
	_verify_overfill_and_drain_exempt()
	_verify_offscreen_body_hides_gauge()
	_verify_body_overlap_threshold()
	_verify_decor_stays_inside_playfield()
	_verify_body_alpha_contract()
	_verify_common_gauge_pass_outlives_body_branches()
	await _verify_real_draw_path_lands_gauge()

	if _failures.is_empty():
		print("lingpet_duration_field_gauge_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _gauge_config(center_unused: Variant = null) -> Dictionary:
	var _ignored: Variant = center_unused
	return {
		"duration_gauge_enabled": true,
		"duration_pool_current": 30.0,
		"duration_pool_max": 40.0,
	}


func _layout_at(center_x: float, body_px: float) -> Dictionary:
	var config: Dictionary = _gauge_config()
	config["walk_draw_size"] = body_px
	return LingpetDurationFieldGaugeRenderer.resolve_layout(
		Vector2(center_x, PROBE_CENTER.y),
		config
	)


func _verify_hidden_when_disabled_or_unrolled() -> void:
	var disabled: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		{
			"duration_gauge_enabled": false,
			"duration_pool_current": 30.0,
			"duration_pool_max": 40.0,
		}
	)
	_expect(
		not bool(disabled.get("visible", false)),
		"게이지를 켜지 않은 호출자(광장 / 컷인 등)에서는 그려지면 안 된다"
	)
	var unrolled: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		{
			"duration_gauge_enabled": true,
			"duration_pool_current": 0.0,
			"duration_pool_max": 0.0,
		}
	)
	_expect(
		not bool(unrolled.get("visible", false)),
		"초기 굴림 전(pool_max=0) 에는 빈 바를 노출하면 안 된다"
	)


func _verify_left_side_vertical_geometry() -> void:
	var body_px: float = 104.0
	var layout: Dictionary = _layout_at(PROBE_CENTER.x, body_px)
	_expect(bool(layout.get("visible", false)), "정상 풀에서는 게이지가 보여야 한다")
	var track: Rect2 = layout.get("track_rect", Rect2())
	_expect(
		track.end.x < PROBE_CENTER.x,
		"게이지 전체가 SD 캐릭터 중심보다 왼쪽에 있어야 한다 (end.x=%.2f, center.x=%.2f)" % [track.end.x, PROBE_CENTER.x]
	)
	_expect(
		track.end.x <= PROBE_CENTER.x - body_px * LingpetDurationFieldGaugeRenderer.BODY_HALF_WIDTH_RATIO,
		"게이지 오른쪽 끝이 몸통 반폭 안으로 들어와 스프라이트를 가리면 안 된다 (end.x=%.2f)" % track.end.x
	)
	_expect(
		track.size.y > track.size.x,
		"게이지는 세로여야 한다 (w=%.2f, h=%.2f)" % [track.size.x, track.size.y]
	)
	var small_track: Rect2 = _layout_at(PROBE_CENTER.x, 82.0).get("track_rect", Rect2())
	_expect(
		small_track.end.x > track.end.x,
		"작은 몸통 펫의 게이지가 큰 몸통 펫보다 중심에 가까워야 한다"
	)
	var fallback: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		_gauge_config()
	)
	var fallback_track: Rect2 = fallback.get("track_rect", Rect2())
	_expect(
		is_equal_approx(fallback_track.position.x, small_track.position.x),
		"walk_draw_size 가 없는 펫은 WALK_DRAW_SIZE(%.1f) 로 폴백해야 한다" % LingpetCompanionSpriteAnimator.WALK_DRAW_SIZE.x
	)


func _verify_fill_is_bottom_anchored() -> void:
	var config: Dictionary = _gauge_config()
	config["duration_pool_current"] = 10.0
	config["walk_draw_size"] = 82.0
	var layout: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(PROBE_CENTER, config)
	var track: Rect2 = layout.get("track_rect", Rect2())
	var fill: Rect2 = layout.get("fill_rect", Rect2())
	_expect(
		is_equal_approx(fill.end.y, track.end.y),
		"채움은 바닥 앵커여야 한다 (fill.end.y=%.3f, track.end.y=%.3f)" % [fill.end.y, track.end.y]
	)
	_expect(
		is_equal_approx(fill.size.y, track.size.y * 0.25),
		"25%% 잔량이면 채움 높이도 트랙의 25%% 여야 한다 (fill.h=%.3f, track.h=%.3f)" % [fill.size.y, track.size.y]
	)
	_expect(
		fill.position.y > track.position.y,
		"잔량이 줄면 채움 상단이 트랙 상단보다 아래로 내려와야 한다"
	)
	var empty_config: Dictionary = _gauge_config()
	empty_config["duration_pool_current"] = 0.0
	var empty: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(PROBE_CENTER, empty_config)
	_expect(
		bool(empty.get("visible", false)) and is_equal_approx(float(empty.get("ratio", -1.0)), 0.0),
		"고갈된 풀은 트랙만 남고 채움 0 이어야 한다(게이지 자체는 계속 보임)"
	)


func _verify_color_keys_lockstep_with_tab_panel() -> void:
	var critical_pct: int = LingpetDurationVitality.DURATION_CRITICAL_THRESHOLD
	var warning_pct: int = LingpetDurationVitality.DURATION_WARNING_THRESHOLD
	_expect(
		LingpetDurationFieldGaugeRenderer.resolve_color_key(100) == "normal",
		"만충 게이지는 normal 이어야 한다"
	)
	_expect(
		LingpetDurationFieldGaugeRenderer.resolve_color_key(warning_pct) == "warning",
		"TAB 패널 경고 임계값(%d%%) 에서 필드 게이지도 warning 이어야 한다" % warning_pct
	)
	_expect(
		LingpetDurationFieldGaugeRenderer.resolve_color_key(warning_pct + 1) == "normal",
		"경고 임계값 바로 위(%d%%) 는 normal 이어야 한다" % (warning_pct + 1)
	)
	_expect(
		LingpetDurationFieldGaugeRenderer.resolve_color_key(critical_pct) == "critical",
		"TAB 패널 위험 임계값(%d%%) 에서 필드 게이지도 critical 이어야 한다" % critical_pct
	)
	for color_key in ["critical", "warning"]:
		_expect(
			LingpetDurationFieldGaugeRenderer.resolve_fill_color(color_key).is_equal_approx(
				LingpetDurationVitality.strip_color(
					{"color_key": color_key},
					LingpetDurationFieldGaugeRenderer.COLOR_NORMAL
				)
			),
			"%s 색은 TAB 패널 스트립과 같은 값이어야 한다" % color_key
		)
	var critical_config: Dictionary = _gauge_config()
	critical_config["duration_pool_current"] = 40.0 * float(critical_pct) / 100.0
	var critical_layout: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		critical_config
	)
	_expect(
		str(critical_layout.get("color_key", "")) == "critical",
		"잔량 %d%% 인 실제 풀은 critical 로 읽혀야 한다" % critical_pct
	)


func _verify_overfill_and_drain_exempt() -> void:
	var overfill_config: Dictionary = _gauge_config()
	overfill_config["duration_pool_current"] = 62.0
	var overfilled: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		overfill_config
	)
	_expect(bool(overfilled.get("overfilled", false)), "풀 초과분(영수 등)은 오버필로 표시돼야 한다")
	_expect(
		is_equal_approx(float(overfilled.get("ratio", -1.0)), 1.0),
		"오버필이어도 채움 비율은 1.0 으로 클램프돼야 한다"
	)
	var full_config: Dictionary = _gauge_config()
	full_config["duration_pool_current"] = 40.0
	var normal_track: Rect2 = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		full_config
	).get("track_rect", Rect2())
	_expect(
		(overfilled.get("track_rect", Rect2()) as Rect2).size.is_equal_approx(normal_track.size),
		"오버필이 트랙 자체를 키우면 안 된다(테두리 강조로만 구분)"
	)
	var exempt_config: Dictionary = _gauge_config()
	exempt_config["duration_pool_current"] = 4.0
	exempt_config["duration_drain_exempt"] = true
	var exempt: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		exempt_config
	)
	_expect(bool(exempt.get("drain_exempt", false)), "소모 면제 상태가 레이아웃까지 전파돼야 한다")
	_expect(
		is_equal_approx(LingpetDurationFieldGaugeRenderer._resolve_pulse("critical", true), 1.0),
		"소모 면제 상태에서는 위험 색이어도 깜빡이면 안 된다(거짓 경고 방지)"
	)


# ★P1 회귀: 출격형 수호령 화면 밖 진입/퇴장 중 게이지만 떠 있던 결함.
func _verify_offscreen_body_hides_gauge() -> void:
	for body_px in [82.0, 104.0]:
		_expect(
			not bool(_layout_at(SORTIE_OFFSCREEN_LEFT_X, body_px).get("visible", false)),
			"좌측 화면 밖(x=%.0f, body=%.0f) 출격 진입 중에는 게이지도 없어야 한다" % [SORTIE_OFFSCREEN_LEFT_X, body_px]
		)
		_expect(
			not bool(_layout_at(LingpetCompanionMotionState.FIELD_WIDTH + 190.0, body_px).get("visible", false)),
			"우측 화면 밖(body=%.0f) 출격 진입 중에도 게이지가 없어야 한다" % body_px
		)
	# 본체 좌단이 아직 화면 밖으로 걸쳐 있으면 게이지가 설 자리가 없다.
	_expect(
		not bool(_layout_at(20.0, 104.0).get("visible", false)),
		"본체가 좌측 화면 경계에 걸친 동안에는 게이지가 없어야 한다"
	)
	# 반대로 정상 patrol 좌측 한계에서는 큰 몸통 펫도 게이지를 유지해야 한다
	# (여기서 숨어 버리면 좌벽 근처에서 게이지가 깜빡인다).
	for body_px in [82.0, 104.0]:
		var patrol_edge: Dictionary = _layout_at(PATROL_LEFT_LIMIT_X, body_px)
		_expect(
			bool(patrol_edge.get("visible", false)),
			"patrol 좌측 한계(x=%.0f, body=%.0f)에서는 게이지가 유지돼야 한다" % [PATROL_LEFT_LIMIT_X, body_px]
		)
		# 침범 판정은 트랙이 아니라 장식 외곽(visual_rect) 기준이어야 한다.
		# 공통 패스는 본체 뒤에 그려지므로 뒷판이 몸통 가장자리를 덮는다.
		var edge_visual: Rect2 = patrol_edge.get("visual_rect", Rect2())
		_expect(
			edge_visual.end.x <= PATROL_LEFT_LIMIT_X - body_px * LingpetDurationFieldGaugeRenderer.BODY_HALF_WIDTH_RATIO,
			"좌벽으로 밀어 넣은 게이지 장식이 몸통을 침범하면 안 된다 (body=%.0f, visual=%s)" % [body_px, str(edge_visual)]
		)
	_expect(
		bool(_layout_at(740.0, 82.0).get("visible", false)),
		"우측 화면 안(x=740)에서는 게이지가 정상 표시돼야 한다"
	)


# ★회귀: 좌벽 보정 후 "몸통 침범" 판정만 트랙 기준으로 남아, 장식(뒷판)이 몸통
# 가장자리를 1~2px 덮던 좁은 전환 구간. 필러 유출(x<0)도 아니고 완전 화면 밖도
# 아니어서 기존 x=42 / x=20 레그 사이로 빠져나갔다.
func _verify_body_overlap_threshold() -> void:
	var ratio: float = LingpetDurationFieldGaugeRenderer.BODY_HALF_WIDTH_RATIO
	var padding: float = LingpetDurationFieldGaugeRenderer.DECOR_PADDING
	# 좌벽 보정 후 고정되는 값들. 트랙 우단과 장식 우단이 padding 만큼 갈린다.
	var clamped_track_end_x: float = (
		LingpetDurationFieldGaugeRenderer.FIELD_MIN_X
		+ padding
		+ LingpetDurationFieldGaugeRenderer.GAUGE_WIDTH
	)
	var clamped_visual_end_x: float = clamped_track_end_x + padding
	# [몸통 px, 중심 x, 표시 기대]
	var cases: Array = [
		[104.0, 40.0, false],
		[104.0, 41.0, false],
		[104.0, 42.0, true],
		[82.0, 33.0, false],
		[82.0, 34.0, false],
		[82.0, 35.0, true],
	]
	for entry in cases:
		var body_px: float = float(entry[0])
		var center_x: float = float(entry[1])
		var expect_visible: bool = bool(entry[2])
		var body_left_x: float = center_x - body_px * ratio
		var layout: Dictionary = _layout_at(center_x, body_px)
		_expect(
			bool(layout.get("visible", false)) == expect_visible,
			"몸통 침범 임계: body=%.0f, x=%.0f 는 %s 여야 한다 (몸통 좌단=%.2f)" % [
				body_px,
				center_x,
				"표시" if expect_visible else "숨김",
				body_left_x,
			]
		)
		if expect_visible:
			var visual: Rect2 = layout.get("visual_rect", Rect2())
			_expect(
				visual.end.x <= body_left_x + 0.001,
				"표시되는 케이스는 장식까지 몸통 밖이어야 한다 (body=%.0f, x=%.0f, visual.end=%.2f, 몸통 좌단=%.2f)" % [
					body_px, center_x, visual.end.x, body_left_x
				]
			)
		else:
			# 픽스처 전제: 이 케이스들은 "트랙 기준으로는 통과하지만 장식 기준으로는
			# 침범"인 좁은 구간이어야 한다. 그래야 트랙 기준 회귀를 실제로 문다.
			_expect(
				body_left_x >= clamped_track_end_x and clamped_visual_end_x > body_left_x,
				"픽스처 전제 실패: body=%.0f, x=%.0f 는 트랙 통과/장식 침범 구간이 아니다 (몸통 좌단=%.2f, 트랙 우단=%.2f, 장식 우단=%.2f)" % [
					body_px, center_x, body_left_x, clamped_track_end_x, clamped_visual_end_x
				]
			)


# ★회귀: 트랙 Rect 만 경계로 봐서 뒷판 grow(2) / 오버필 캡이 좌측 필러로 새던 결함.
# 판정은 반드시 장식을 포함한 visual_rect 로 한다.
func _verify_decor_stays_inside_playfield() -> void:
	for body_px in [82.0, 104.0]:
		for center_x in [PATROL_LEFT_LIMIT_X, PATROL_LEFT_LIMIT_X + 3.0, 200.0, 700.0]:
			var layout: Dictionary = _layout_at(center_x, body_px)
			if not bool(layout.get("visible", false)):
				continue
			var visual: Rect2 = layout.get("visual_rect", Rect2())
			var track: Rect2 = layout.get("track_rect", Rect2())
			_expect(
				visual.size.x > track.size.x and visual.size.y > track.size.y,
				"visual_rect 는 장식 패딩만큼 트랙보다 커야 한다 (x=%.0f, body=%.0f)" % [center_x, body_px]
			)
			_expect(
				visual.position.x >= LingpetDurationFieldGaugeRenderer.FIELD_MIN_X
					and visual.end.x <= LingpetDurationFieldGaugeRenderer.FIELD_MAX_X,
				"장식 외곽까지 플레이필드 안이어야 한다 (x=%.0f, body=%.0f, visual=%s)" % [center_x, body_px, str(visual)]
			)
	var overfill_config: Dictionary = _gauge_config()
	overfill_config["duration_pool_current"] = 62.0
	overfill_config["walk_draw_size"] = 104.0
	var overfill_layout: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		Vector2(PATROL_LEFT_LIMIT_X, PROBE_CENTER.y),
		overfill_config
	)
	_expect(bool(overfill_layout.get("overfilled", false)), "오버필 픽스처는 실제 오버필이어야 한다")
	var overfill_visual: Rect2 = overfill_layout.get("visual_rect", Rect2())
	_expect(
		overfill_visual.position.x >= LingpetDurationFieldGaugeRenderer.FIELD_MIN_X,
		"오버필 상태에서도 장식이 좌측 필러로 새면 안 된다 (visual=%s)" % str(overfill_visual)
	)


# ★회귀: 공통 패스가 본체 알파를 잃고 항상 1.0 으로 그리던 결함.
# 본체 표현이 쓰는 알파와 게이지가 받는 알파가 같은 정본에서 나와야 한다.
func _verify_body_alpha_contract() -> void:
	_expect(
		is_equal_approx(
			LingpetCompanionRenderer.resolve_body_draw_alpha({"companion_visible": false}),
			0.0
		),
		"본체가 안 보이는 프레임의 본체 알파는 0 이어야 한다"
	)
	_expect(
		is_equal_approx(
			LingpetCompanionRenderer.resolve_body_draw_alpha({"switch_transition": 1.0}),
			LingpetCompanionRenderer.SWITCH_TRANSITION_MIN_ALPHA
		),
		"교체 전환 최대치에서 본체 알파는 %.2f 바닥이어야 한다" % LingpetCompanionRenderer.SWITCH_TRANSITION_MIN_ALPHA
	)
	_expect(
		LingpetCompanionRenderer.resolve_body_draw_alpha({"switch_transition": 1.0}) < 1.0,
		"교체 전환 중 본체 알파가 1.0 이면 게이지만 진하게 뜬다"
	)
	_expect(
		is_equal_approx(
			LingpetCompanionRenderer.resolve_body_draw_alpha({"companion_alpha": 0.5}),
			0.5
		),
		"고스트 페이드 알파가 본체 알파에 그대로 실려야 한다"
	)
	_expect(
		is_equal_approx(
			LingpetCompanionRenderer.resolve_body_draw_alpha({
				"switch_transition": 1.0,
				"companion_alpha": 0.5,
			}),
			LingpetCompanionRenderer.SWITCH_TRANSITION_MIN_ALPHA * 0.5
		),
		"교체 전환과 고스트 페이드는 함께 곱해져야 한다"
	)
	# 클릭 교감 정본: 시작 프레임(timer=0)은 알파 0 이라 본체가 draw 를 건너뛴다.
	# 게이지가 이 값을 안 따라가면 교감 시작 순간 게이지만 단독으로 뜬다.
	var click_state: Object = LingpetCompanionClickReactionState.new()
	click_state.start()
	_expect(
		is_equal_approx(float(click_state.get_alpha()), 0.0),
		"클릭 교감 시작 프레임(timer=0)의 본체 알파는 0 이어야 한다 (픽스처 전제)"
	)


# ★P2 회귀: 클릭 교감 반응 시트가 그려지는 프레임에 게이지만 끊기던 결함.
# 게이지 호출이 본체 분기 "안"으로 들어가면 그 순간 다시 회귀하므로, 호스트의
# 실제 함수 본문에서 공통 패스 위치를 단언한다.
func _verify_common_gauge_pass_outlives_body_branches() -> void:
	var runtime_source: String = _read_source(EGG_RUNTIME_PATH)
	var renderer_source: String = _read_source(COMPANION_RENDERER_PATH)
	_expect(runtime_source != "" and renderer_source != "", "소스 로드에 실패하면 이 레그는 판정 불가다")
	if runtime_source == "" or renderer_source == "":
		return
	_expect(
		renderer_source.find("draw_gauge(") < 0,
		"컴패니언 렌더러는 게이지를 소유하면 안 된다(본체 표현 한 갈래만 담당하므로 다른 표현에서 끊긴다)"
	)
	var behind_body: String = _function_body(runtime_source, "func draw_lingpet_body_behind_actors")
	_expect(behind_body != "", "draw_lingpet_body_behind_actors 본문을 찾아야 한다")
	var gauge_idx: int = behind_body.find("_draw_companion_duration_gauge(")
	var click_draw_idx: int = behind_body.find("_companion_click_reaction_state.draw(")
	var body_draw_idx: int = behind_body.find("_draw_companion(")
	_expect(gauge_idx >= 0, "본체 뒤 패스에서 공통 게이지 패스를 실행해야 한다")
	_expect(click_draw_idx >= 0 and body_draw_idx >= 0, "두 본체 표현 분기가 모두 있어야 한다(픽스처 전제)")
	_expect(
		gauge_idx > click_draw_idx and gauge_idx > body_draw_idx,
		"게이지 패스는 일반 SD / 클릭 교감 두 분기 '뒤'에 있어야 한다"
	)
	_expect(
		behind_body.count("_draw_companion_duration_gauge(") == 1,
		"게이지 패스는 분기마다 흩뿌리지 말고 한 번만 실행해야 한다"
	)
	# 알파를 상수로 가정하면(예: body_alpha = 1.0) 페이드 구간에서 게이지만 진해진다.
	_expect(
		behind_body.find("body_alpha = 1.0") < 0 and behind_body.find("body_visible = true") < 0,
		"본체 알파 / 가시성을 상수로 가정하면 안 된다(실제 사용 알파를 받아야 한다)"
	)
	# 공통 패스가 분기 밖(들여쓰기 1단)에 있어야 한다. 분기 안(2단 이상)으로
	# 들어가면 그 분기에서만 게이지가 나온다.
	_expect(
		behind_body.find("\n\t_draw_companion_duration_gauge(") >= 0,
		"게이지 패스가 if/else 분기 안으로 들어가면 안 된다(분기 밖 공통 실행)"
	)
	# 클릭 교감 분기도 '본체가 보이는' 프레임으로 취급해야 게이지가 나온다.
	var click_branch_tail: String = behind_body.substr(click_draw_idx)
	var click_alpha_idx: int = click_branch_tail.find("_companion_click_reaction_state.get_alpha()")
	_expect(
		click_alpha_idx >= 0
			and click_alpha_idx < click_branch_tail.find("_draw_companion_duration_gauge("),
		"클릭 교감 분기는 반응 시트가 draw 게이트로 쓰는 get_alpha() 를 그대로 게이지에 넘겨야 한다"
	)


func _verify_real_draw_path_lands_gauge() -> void:
	var probe := GaugeDrawProbe.new()
	probe.name = "LingpetDurationFieldGaugeProbe"
	probe.center = PROBE_CENTER
	probe.config = _gauge_config()
	probe.config["walk_draw_size"] = 92.0
	get_root().add_child(probe)
	probe.queue_redraw()
	await process_frame
	await process_frame
	_expect(probe.draw_count > 0, "프로브의 실제 _draw() 콜백이 돌아야 한다")
	_expect(
		bool(probe.last_layout.get("visible", false)),
		"실 draw 경로에서 게이지가 랜딩해야 한다"
	)
	var landed_track: Rect2 = probe.last_layout.get("track_rect", Rect2())
	_expect(
		landed_track.end.x < PROBE_CENTER.x and landed_track.size.y > landed_track.size.x,
		"실 draw 경로에서도 게이지가 중심 왼쪽 세로 바여야 한다 (rect=%s)" % str(landed_track)
	)

	# 화면 밖 본체는 실제 draw 경로에서도 아무것도 남기지 않아야 한다.
	probe.center = Vector2(SORTIE_OFFSCREEN_LEFT_X, PROBE_CENTER.y)
	probe.queue_redraw()
	await process_frame
	await process_frame
	_expect(
		not bool(probe.last_layout.get("visible", false)),
		"화면 밖 본체는 실 draw 경로에서도 게이지를 남기면 안 된다"
	)

	# 본체 알파 0(클릭 교감 시작 프레임) → 게이지도 없다.
	probe.center = PROBE_CENTER
	probe.alpha = 0.0
	probe.queue_redraw()
	await process_frame
	await process_frame
	_expect(
		not bool(probe.last_layout.get("visible", false)),
		"본체 알파 0 인 프레임에서는 게이지도 그려지면 안 된다(교감 시작 순간 단독 표시 금지)"
	)

	# 반대로 본체가 아직 그려지는 아주 옅은 알파에서는 게이지도 살아 있어야 한다.
	# 게이지 컷 임계가 본체보다 높으면(예: 0.01) 페이드 구간에서 본체만 남는다.
	probe.alpha = 0.008
	probe.queue_redraw()
	await process_frame
	await process_frame
	_expect(
		bool(probe.last_layout.get("visible", false)),
		"본체가 그려지는 옅은 알파(0.008)에서는 게이지도 살아 있어야 한다"
	)

	probe.queue_free()
	await process_frame


func _read_source(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_func := source.find("\nfunc ", start + signature.length())
	var next_static_func := source.find("\nstatic func ", start + signature.length())
	var end := source.length()
	if next_func >= 0:
		end = mini(end, next_func)
	if next_static_func >= 0:
		end = mini(end, next_static_func)
	return source.substr(start, end - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
