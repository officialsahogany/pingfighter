extends SceneTree

# 크리스탈(테트로미노) 실드 궤도 반경 픽셀 봉인(비헤드리스).
#
# 상태 스모크는 draw context의 숫자(ORBIT_RADIUS=165)만 증명한다. 그건 "논리
# 반경"이고, 플레이어가 체감하는 "둘레가 실제로 그만큼 넓게 그려지는가"는
# 렌더러를 통과한 픽셀로만 확정된다 — 렌더러가 폴백 상수(락스텝 누락)나 자체
# 스케일로 다른 반경을 그려도 상태 씰은 GREEN을 유지한다(공허-GREEN).
#
# 그래서 실 렌더러 stage6_tetriser_playfield_renderer.draw()로 활성 실드를
# 그린 뒤, 밝은 픽셀의 보스 중심 거리 분포를 실측해 반경을 역산한다.
# 헤드리스에서는 뷰포트 픽셀 판독 불가 → skip. 로컬/디스플레이 게이트 전용.

const Stage6TetriserCrystalShieldState := preload("res://scripts/stages/stage6/stage6_tetriser_crystal_shield_state.gd")
const Stage6TetriserPlayfieldRenderer := preload("res://scripts/stages/stage6/stage6_tetriser_playfield_renderer.gd")

const VIEW := Vector2i(760, 750)
const MEASURE_CENTER := Vector2(380.0, 375.0)   # 링 전체가 화면 안에 들어오는 측정용 중심
const LIVE_BOSS_POS := Vector2(330.0, 25.0)     # 실제 인게임 보스 위치(캡처 참고용)
const LIVE_BOSS_SIZE := Vector2(100.0, 40.0)
const EXPECTED_RADIUS := 165.0
const RADIUS_TOLERANCE := 10.0
const NARROW_RADIUS_REJECT := 140.0             # 소실 전 회귀값 110을 확실히 배제
const LIT_THRESHOLD := 0.35                     # 블록 본체(alpha 0.62)만 집계, 글로우(0.10) 제외
const CAPTURE_PATH := "d:/tmp/stage6_crystal_shield_radius_qa.png"

var _failed := false
var _canvas: Node2D = null


class ProbeCanvas:
	extends Node2D

	var renderer: Object = null
	var context: Dictionary = {}
	var frame_rect: Rect2 = Rect2()
	var boss_rect: Rect2 = Rect2()

	func _draw() -> void:
		if frame_rect.size.x > 0.0:
			draw_rect(frame_rect, Color(0.25, 0.30, 0.40, 1.0), false, 2.0)
		if boss_rect.size.x > 0.0:
			draw_rect(boss_rect, Color(0.55, 0.30, 0.30, 1.0), false, 2.0)
		if renderer != null:
			renderer.draw(self, context, Vector2.ZERO)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		print("stage6_tetriser_crystal_shield_radius_pixel_smoke: pixel QA skipped under headless display server")
		print("stage6_tetriser_crystal_shield_radius_pixel_smoke: ok")
		quit(0)
		return

	get_root().size = VIEW
	# 프로젝트는 stretch/mode="canvas_items"(기준 2020x1246)라 그대로 두면 캔버스가
	# 축소되어 그려진다. 측정 해상도를 위해 1:1로 맞추고, 그래도 남는 스케일/오프셋은
	# 아래에서 실제 캔버스 변환으로 환산한다(스트레치 설정이 바뀌어도 씰이 견디도록).
	get_root().content_scale_size = VIEW
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 1.0))
	_canvas = ProbeCanvas.new()
	_canvas.renderer = Stage6TetriserPlayfieldRenderer.new()
	get_root().add_child(_canvas)

	# --- 측정 레그: 링 전체가 보이도록 중심을 화면 중앙에 둔다(반경은 평행이동 불변).
	var measured: float = await _render_and_measure_radius(MEASURE_CENTER, false)
	_expect(measured >= 0.0, "windowed QA must obtain a viewport texture to measure the ring (fail-closed on missing texture)")
	if measured < 0.0:
		_finish()
		return
	_expect(
		absf(measured - EXPECTED_RADIUS) <= RADIUS_TOLERANCE,
		"drawn crystal shield ring radius must match the widened %.0fpx orbit (measured %.1fpx)" % [EXPECTED_RADIUS, measured]
	)
	print("stage6_tetriser_crystal_shield_radius_pixel_smoke: measured drawn ring radius = %.1fpx (expected %.0fpx)" % [measured, EXPECTED_RADIUS])
	_expect(
		measured >= NARROW_RADIUS_REJECT,
		"drawn ring must not regress to the narrow pre-loss radius (measured %.1fpx, reject band < %.0fpx)" % [measured, NARROW_RADIUS_REJECT]
	)

	# --- 캡처 레그: 실제 보스 위치에서의 링 모습을 PNG로 남겨 눈으로 확인 가능하게.
	var saved: bool = await _render_and_capture(LIVE_BOSS_POS + LIVE_BOSS_SIZE * 0.5)
	if not saved:
		print("stage6_tetriser_crystal_shield_radius_pixel_smoke: capture skipped (path not writable)")

	_finish()


func _finish() -> void:
	if _canvas != null:
		_canvas.queue_free()
	if _failed:
		quit(1)
		return
	print("stage6_tetriser_crystal_shield_radius_pixel_smoke: ok")
	quit(0)


func _build_active_shield_context(boss_center: Vector2) -> Dictionary:
	var shield: Object = Stage6TetriserCrystalShieldState.new()
	shield.debug_start(boss_center, true)
	return shield.get_actor_draw_context()


func _render_frame(boss_center: Vector2, with_chrome: bool) -> void:
	_canvas.context = _build_active_shield_context(boss_center)
	if with_chrome:
		_canvas.frame_rect = Rect2(Vector2.ONE, Vector2(VIEW) - Vector2(2.0, 2.0))
		_canvas.boss_rect = Rect2(LIVE_BOSS_POS, LIVE_BOSS_SIZE)
	else:
		_canvas.frame_rect = Rect2()
		_canvas.boss_rect = Rect2()
	_canvas.queue_redraw()


func _capture_image(boss_center: Vector2, with_chrome: bool) -> Image:
	_render_frame(boss_center, with_chrome)
	for _i in range(6):
		await process_frame
	var tex := get_root().get_texture()
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return null
	return img


# 밝은 픽셀의 중심 거리 평균 = 링 반경. 블록은 반경 R 위에 균등 배치되고 R±8만
# 차지하므로 평균이 곧 R로 수렴한다(접선 방향 오프셋 기여는 0.2px 미만).
func _render_and_measure_radius(boss_center: Vector2, with_chrome: bool) -> float:
	var img: Image = await _capture_image(boss_center, with_chrome)
	if img == null:
		return -1.0
	# 게임 좌표 -> 실제 뷰포트 픽셀 변환을 렌더 트리에서 직접 얻는다. 측정값을 다시
	# 게임 단위로 환산하므로 스트레치/스케일이 어떻든 반경 단언은 유효하다.
	var xf: Transform2D = _canvas.get_global_transform_with_canvas()
	var scale_px: float = xf.get_scale().x
	if scale_px <= 0.0001:
		return -1.0
	var center_px: Vector2 = xf * boss_center
	var total := 0.0
	var count := 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.r + c.g + c.b <= LIT_THRESHOLD:
				continue
			total += Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center_px)
			count += 1
	if count <= 0:
		return -1.0
	return (total / float(count)) / scale_px


func _render_and_capture(boss_center: Vector2) -> bool:
	var img: Image = await _capture_image(boss_center, true)
	if img == null:
		return false
	return img.save_png(CAPTURE_PATH) == OK


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
