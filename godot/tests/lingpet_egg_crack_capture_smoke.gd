extends SceneTree

# 수호령 알 크랙 PNG 오버레이 실렌더 캡처 씰(2026-07-21 리뷰 P3): 함수명
# 소스씰만으로는 잘못된 UV·회전·알파·드로 순서가 전부 통과한다 — 실
# CanvasItem draw를 SubViewport 1:1로 캡처해 픽셀로 봉인한다.
#   레그 1: hatch 1 크랙 픽셀 존재(무크랙 대비 diff > 임계)
#   레그 2: hatch 2 커버리지 > hatch 1 (stage2 = stage1 ∪ 신규 웹)
#   레그 3: 회전 비영점에서 크랙 diff 중심이 회전 0 대비 이동(회전 동기)
#   레그 4: 셸브레이크 draw에도 크랙 픽셀 유지(누적 유지)
# headless 디스플레이 서버에서는 스킵(비-headless가 실판정 — perk_slot_limit 선례).

const LingpetEggFieldRenderer := preload("res://scripts/lingpet/lingpet_egg_field_renderer.gd")

const VIEW_SIZE := Vector2i(192, 192)
const EGG_CENTER := Vector2(96.0, 108.0)
const CRACK_MIN_DIFF_PIXELS := 20
const ROTATION_CENTROID_MIN_SHIFT := 2.0

var _failures: Array[String] = []


class EggCaptureCanvas:
	extends Node2D

	var renderer: Object
	var hatch_hits := 0
	var roll_angle := 0.0
	var draw_shell_break := false
	var shell_break_progress := 0.55

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(192.0, 192.0)), Color(0.05, 0.06, 0.09, 1.0))
		if renderer == null:
			return
		if draw_shell_break:
			renderer.draw_hatch_break_egg(self, Vector2(96.0, 108.0), shell_break_progress, 0.0, 0, roll_angle)
		else:
			renderer.draw_egg(self, Vector2(96.0, 108.0), hatch_hits, 3, 0.0, 0, roll_angle)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().find("headless") >= 0:
		print("lingpet_egg_crack_capture_smoke: skipped under headless display server")
		print("lingpet_egg_crack_capture_smoke: ok")
		quit(0)
		return

	var renderer := LingpetEggFieldRenderer.new()
	renderer.prewarm()
	if renderer._get_cached_crack_texture(0) == null or renderer._get_cached_crack_texture(1) == null:
		_failures.append("crack overlay textures must prewarm before the capture legs (fail-closed)")
		_finish()
		return

	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var canvas := EggCaptureCanvas.new()
	canvas.renderer = renderer
	viewport.add_child(canvas)

	var base_image: Image = await _capture(canvas, viewport, 0, 0.0, false)
	var stage1_image: Image = await _capture(canvas, viewport, 1, 0.0, false)
	var stage2_image: Image = await _capture(canvas, viewport, 2, 0.0, false)
	var base_rot_image: Image = await _capture(canvas, viewport, 0, 0.8, false)
	var stage1_rot_image: Image = await _capture(canvas, viewport, 1, 0.8, false)
	var break_image: Image = await _capture(canvas, viewport, 0, 0.0, true)

	var stage1_diff: Array = _diff_pixels(base_image, stage1_image)
	var stage2_diff: Array = _diff_pixels(base_image, stage2_image)
	var rot_diff: Array = _diff_pixels(base_rot_image, stage1_rot_image)
	var break_diff: Array = _diff_pixels(base_image, break_image)

	_expect(
		stage1_diff.size() >= CRACK_MIN_DIFF_PIXELS,
		"stage-1 crack overlay should change visible pixels over the plain egg (got %d)" % stage1_diff.size()
	)
	_expect(
		stage2_diff.size() > stage1_diff.size(),
		"stage-2 crack coverage should grow over stage-1 (stage2=stage1 ∪ new web; got %d vs %d)" % [stage2_diff.size(), stage1_diff.size()]
	)
	_expect(
		rot_diff.size() >= CRACK_MIN_DIFF_PIXELS,
		"rotated egg should still draw the crack overlay (got %d diff pixels)" % rot_diff.size()
	)
	if not stage1_diff.is_empty() and not rot_diff.is_empty():
		# 회전 동기 판별은 평행이동에 불변인 주축 각도로 한다 — 중심 이동
		# 비교는 롤 bob 오프셋(순수 평행이동)만으로도 통과해 공허하다
		# (반증검증에서 실측된 약점). 크랙 패턴은 세로로 길쭉해 주축이
		# 안정적이고, 0.8rad 회전이면 주축도 ~0.8rad 돌아야 한다.
		var upright_angle: float = _principal_angle(stage1_diff)
		var rotated_angle: float = _principal_angle(rot_diff)
		var angle_delta: float = absf(upright_angle - rotated_angle)
		angle_delta = minf(angle_delta, PI - angle_delta)
		_expect(
			angle_delta >= 0.3,
			"crack overlay must rotate WITH the egg (principal-axis delta %.2frad < 0.3 — translation-only means rotation sync is broken)" % angle_delta
		)
	_expect(
		break_diff.size() >= CRACK_MIN_DIFF_PIXELS,
		"shell-break draw must keep visible crack pixels (accumulated cracks; got %d)" % break_diff.size()
	)

	viewport.queue_free()
	_finish()


func _capture(canvas: EggCaptureCanvas, viewport: SubViewport, hatch_hits: int, roll_angle: float, shell_break: bool) -> Image:
	canvas.hatch_hits = hatch_hits
	canvas.roll_angle = roll_angle
	canvas.draw_shell_break = shell_break
	canvas.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _diff_pixels(before: Image, after: Image) -> Array:
	# 글로우/펄스는 시간 기반이라 캡처 간 저강도 잡음을 만든다 — 판별은
	# 알 몸체 rect(88x88) 안에서 강한 델타(크랙 화이트 코어)만 센다.
	var points: Array = []
	if before == null or after == null:
		return points
	var min_x: int = maxi(0, int(EGG_CENTER.x) - 44)
	var max_x: int = mini(before.get_width(), int(EGG_CENTER.x) + 44)
	var min_y: int = maxi(0, int(EGG_CENTER.y) - 44)
	var max_y: int = mini(before.get_height(), int(EGG_CENTER.y) + 44)
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			var a: Color = before.get_pixel(x, y)
			var b: Color = after.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.25:
				points.append(Vector2(float(x), float(y)))
	return points


func _centroid(points: Array) -> Vector2:
	var total := Vector2.ZERO
	for point_value in points:
		total += point_value as Vector2
	return total / float(maxi(1, points.size()))


# 점군의 주축 각도(공분산 고유벡터, mod PI). 평행이동 불변이라 회전 동기
# 판별에 적합하다.
func _principal_angle(points: Array) -> float:
	var centroid: Vector2 = _centroid(points)
	var cov_xx := 0.0
	var cov_yy := 0.0
	var cov_xy := 0.0
	for point_value in points:
		var d: Vector2 = (point_value as Vector2) - centroid
		cov_xx += d.x * d.x
		cov_yy += d.y * d.y
		cov_xy += d.x * d.y
	return 0.5 * atan2(2.0 * cov_xy, cov_xx - cov_yy)


func _finish() -> void:
	if _failures.is_empty():
		print("lingpet_egg_crack_capture_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
