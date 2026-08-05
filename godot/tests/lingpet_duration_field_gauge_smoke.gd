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
#  5. 실제 draw 경로 관통: 트리에 붙은 Node2D 의 _draw() 안에서 공개
#     draw_companion() 을 돌려 게이지가 실제로 랜딩하는지 본다. 본체가
#     보이지 않는 프레임(companion_visible=false)에서는 게이지도 같이
#     사라져야 하며, 직전 프레임 레이아웃이 스테일로 남아서도 안 된다.
#
# 순수 레이아웃 단언만으로는 "resolve_layout 은 맞는데 draw_companion 이
# 게이지를 안 부른다"는 공허-GREEN 이 가능하므로 5번 레그가 필수다.

const LingpetDurationFieldGaugeRenderer := preload("res://scripts/lingpet/lingpet_duration_field_gauge_renderer.gd")
const LingpetCompanionRenderer := preload("res://scripts/lingpet/lingpet_companion_renderer.gd")
const LingpetCompanionDrawContextBuilder := preload("res://scripts/lingpet/lingpet_companion_draw_context_builder.gd")
const LingpetCompanionSpriteAnimator := preload("res://scripts/lingpet/lingpet_companion_sprite_animator.gd")
const LingpetDurationVitality := preload("res://scripts/hud/character_info_overlay_lingpet_vitality_projection.gd")

const PROBE_CENTER := Vector2(380.0, 690.0)

var _failures: Array[String] = []


class CompanionDrawProbe:
	extends Node2D

	var renderer: Object = null
	var config: Dictionary = {}
	var center := Vector2.ZERO
	var draw_count := 0
	var last_layout: Dictionary = {}

	func _draw() -> void:
		draw_count += 1
		if renderer == null:
			return
		renderer.draw_companion(self, center, config)
		last_layout = renderer.get_last_duration_gauge_layout_for_tests()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_hidden_when_disabled_or_unrolled()
	_verify_left_side_vertical_geometry()
	_verify_fill_is_bottom_anchored()
	_verify_color_keys_lockstep_with_tab_panel()
	_verify_overfill_and_drain_exempt()
	await _verify_real_draw_path_lands_gauge()

	if _failures.is_empty():
		print("lingpet_duration_field_gauge_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


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
	var layout: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		{
			"duration_gauge_enabled": true,
			"duration_pool_current": 40.0,
			"duration_pool_max": 40.0,
			"walk_draw_size": body_px,
		}
	)
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
	# 몸통이 큰 펫일수록 게이지도 커지고 더 왼쪽으로 밀린다.
	var small: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		{
			"duration_gauge_enabled": true,
			"duration_pool_current": 40.0,
			"duration_pool_max": 40.0,
			"walk_draw_size": 82.0,
		}
	)
	var small_track: Rect2 = small.get("track_rect", Rect2())
	_expect(
		small_track.end.x > track.end.x,
		"작은 몸통 펫의 게이지가 큰 몸통 펫보다 중심에 가까워야 한다"
	)
	# walk_draw_size 미제공 펫은 애니메이터 기본 셀 크기로 폴백한다.
	var fallback: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		{
			"duration_gauge_enabled": true,
			"duration_pool_current": 40.0,
			"duration_pool_max": 40.0,
		}
	)
	var fallback_track: Rect2 = fallback.get("track_rect", Rect2())
	_expect(
		is_equal_approx(fallback_track.position.x, small_track.position.x),
		"walk_draw_size 가 없는 펫은 WALK_DRAW_SIZE(%.1f) 로 폴백해야 한다" % LingpetCompanionSpriteAnimator.WALK_DRAW_SIZE.x
	)


func _verify_fill_is_bottom_anchored() -> void:
	var layout: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		{
			"duration_gauge_enabled": true,
			"duration_pool_current": 10.0,
			"duration_pool_max": 40.0,
			"walk_draw_size": 82.0,
		}
	)
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
	var empty: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		{
			"duration_gauge_enabled": true,
			"duration_pool_current": 0.0,
			"duration_pool_max": 40.0,
		}
	)
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
	# 색값도 같은 소유자에서 나와야 한다 -- 임계값만 공유하고 색을 재타이핑하면
	# 두 표시면이 다른 빨강 / 노랑으로 갈라진다.
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
	# 실제 풀 값으로도 같은 판정이 나와야 한다(pct 환산 경로 포함).
	var critical_layout: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		{
			"duration_gauge_enabled": true,
			"duration_pool_current": 40.0 * float(critical_pct) / 100.0,
			"duration_pool_max": 40.0,
		}
	)
	_expect(
		str(critical_layout.get("color_key", "")) == "critical",
		"잔량 %d%% 인 실제 풀은 critical 로 읽혀야 한다" % critical_pct
	)


func _verify_overfill_and_drain_exempt() -> void:
	var overfilled: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		{
			"duration_gauge_enabled": true,
			"duration_pool_current": 62.0,
			"duration_pool_max": 40.0,
		}
	)
	_expect(bool(overfilled.get("overfilled", false)), "풀 초과분(영수 등)은 오버필로 표시돼야 한다")
	_expect(
		is_equal_approx(float(overfilled.get("ratio", -1.0)), 1.0),
		"오버필이어도 채움 비율은 1.0 으로 클램프돼야 한다"
	)
	var overfill_track: Rect2 = overfilled.get("track_rect", Rect2())
	var normal_track: Rect2 = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		{
			"duration_gauge_enabled": true,
			"duration_pool_current": 40.0,
			"duration_pool_max": 40.0,
		}
	).get("track_rect", Rect2())
	_expect(
		overfill_track.size.is_equal_approx(normal_track.size),
		"오버필이 트랙 자체를 키우면 안 된다(테두리 강조로만 구분)"
	)
	var exempt: Dictionary = LingpetDurationFieldGaugeRenderer.resolve_layout(
		PROBE_CENTER,
		{
			"duration_gauge_enabled": true,
			"duration_pool_current": 4.0,
			"duration_pool_max": 40.0,
			"duration_drain_exempt": true,
		}
	)
	_expect(bool(exempt.get("drain_exempt", false)), "소모 면제 상태가 레이아웃까지 전파돼야 한다")
	_expect(
		is_equal_approx(LingpetDurationFieldGaugeRenderer._resolve_pulse("critical", true), 1.0),
		"소모 면제 상태에서는 위험 색이어도 깜빡이면 안 된다(거짓 경고 방지)"
	)


func _verify_real_draw_path_lands_gauge() -> void:
	var renderer: Object = LingpetCompanionRenderer.new()
	var builder: Object = LingpetCompanionDrawContextBuilder.new()
	var probe := CompanionDrawProbe.new()
	probe.name = "LingpetDurationFieldGaugeProbe"
	probe.renderer = renderer
	probe.center = PROBE_CENTER
	probe.config = builder.build_config({
		"companion_active": true,
		"companion_visible": true,
		"duration_gauge_enabled": true,
		"duration_pool_current": 18.0,
		"duration_pool_max": 40.0,
	})
	get_root().add_child(probe)
	probe.queue_redraw()
	await process_frame
	await process_frame
	_expect(probe.draw_count > 0, "프로브의 실제 _draw() 콜백이 돌아야 한다")
	var landed: Dictionary = probe.last_layout
	_expect(
		bool(landed.get("visible", false)),
		"draw_companion() 공개 경로가 지속시간 게이지를 실제로 그려야 한다"
	)
	var landed_track: Rect2 = landed.get("track_rect", Rect2())
	_expect(
		landed_track.end.x < PROBE_CENTER.x and landed_track.size.y > landed_track.size.x,
		"실 draw 경로에서도 게이지가 중심 왼쪽 세로 바여야 한다 (rect=%s)" % str(landed_track)
	)

	# 본체가 안 보이는 프레임에서는 게이지도 사라지고, 직전 프레임 레이아웃이
	# 스테일로 남지도 않아야 한다.
	probe.config["companion_visible"] = false
	probe.queue_redraw()
	await process_frame
	await process_frame
	_expect(
		not bool(probe.last_layout.get("visible", false)),
		"본체가 숨은 프레임에서는 게이지도 그려지면 안 된다(떠다니는 UI 금지)"
	)

	probe.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
