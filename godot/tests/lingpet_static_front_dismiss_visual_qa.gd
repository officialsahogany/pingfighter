extends SceneTree

# 비헤드리스 픽셀 QA — S1 정적 정면 모델의 획득 퇴장 분기.
#
# 표준 스모크 러너(헤드리스·더미 렌더링 서버)는 SubViewport 캡처가 불가능하므로,
# 이 스크립트는 실제 렌더러로 직접 실행한다 (열린 에디터와의 임포트 경합을 피해
# 자산 변경이 정리된 시점에 실행할 것):
#   <godot_console> --path godot res://tests/lingpet_static_front_dismiss_visual_qa.gd
#   (SceneTree 스크립트 실행: --script 인자 사용)
#
# 증명 대상 (2026-08-04 계약):
#   1. 퇴장 중반(0.5): 정적 원화가 그려진다 (>200px)
#   2. 페이드 구간(0.85): 아직 사라지지 않았다 (>0px, 중반보다 약함) — 급소멸 금지
#   3. 종단(0.995): 완전 페이드 (0px)
#   4. 대조군(원화 null): 녹색 픽셀 0 — 판별력 증명

const AcquireCutinOverlayHost := preload("res://scripts/hud/lingpet_acquire_cutin_overlay_host.gd")

var _failed := false


class DismissProbe:
	extends Node2D

	var host: RefCounted = null
	var progress := 0.5
	var view := Vector2(400.0, 300.0)

	func _draw() -> void:
		if host != null:
			host._draw_dismiss_action(self, view, progress)


func _init() -> void:
	call_deferred("_run")


func _expect(label: String, ok: bool) -> void:
	if ok:
		print("PASS: %s" % label)
	else:
		_failed = true
		printerr("FAIL: %s" % label)


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 300)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var art_image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	art_image.fill(Color(0.0, 1.0, 0.0, 1.0))
	var art_texture := ImageTexture.create_from_image(art_image)

	var host := AcquireCutinOverlayHost.new()
	host._cutin_dismiss_sheet = null
	host._cutin_art = art_texture

	var probe := DismissProbe.new()
	probe.host = host
	viewport.add_child(probe)

	var mid := await _measure_green(viewport, probe, 0.5)
	var fading := await _measure_green(viewport, probe, 0.85)
	var ended := await _measure_green(viewport, probe, 0.995)
	_expect("퇴장 중반(0.5): 정적 원화 가시 (>200px, 실측 %d)" % mid[0], mid[0] > 200)
	_expect("페이드 구간(0.85): 잔존 (>0px, 실측 %d)" % fading[0], fading[0] > 0)
	# 페이드는 픽셀 '개수'가 아니라 '강도'로 재야 한다 — 알파 0.5여도 임계 위면
	# 개수는 그대로다(1차 실측에서 확인된 계측 설계 정정).
	_expect(
		"페이드 구간: 녹색 에너지가 중반보다 감쇠 (%.0f < %.0f)" % [fading[1], mid[1]],
		fading[1] < mid[1] * 0.75
	)
	_expect("종단(0.995): 완전 페이드 (0px, 실측 %d)" % ended[0], ended[0] == 0)

	host._cutin_art = null
	var control := await _measure_green(viewport, probe, 0.5)
	_expect("대조군(원화 null): 녹색 0px (실측 %d)" % control[0], control[0] == 0)

	viewport.queue_free()
	await process_frame

	if _failed:
		printerr("lingpet_static_front_dismiss_visual_qa: FAILED")
		quit(1)
		return
	print("lingpet_static_front_dismiss_visual_qa: ok")
	quit(0)


func _measure_green(viewport: SubViewport, probe: DismissProbe, progress: float) -> Array:
	# 반환 [count, energy]: count = 임계 초과 픽셀 수, energy = 녹색 초과분 합
	# (강도 지표 — 페이드 감쇠는 energy로만 판정 가능).
	probe.progress = progress
	probe.queue_redraw()
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null:
		_failed = true
		printerr("FAIL: viewport capture null (헤드리스 실행? 비헤드리스로 실행할 것)")
		return [-1, -1.0]
	var count := 0
	var energy := 0.0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var c := image.get_pixel(x, y)
			if c.g > 0.2 and c.r < 0.31 and c.b < 0.31:
				energy += c.g - maxf(c.r, c.b)
				if c.g > 0.39:
					count += 1
	return [count, energy]
