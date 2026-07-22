extends SceneTree

# Seal: 상단 미니 스코어보드 리테인드 호스트 (perf — redraw 게이팅 계약).
#
# 2026-07-23 S2 라이브 triage에서 stage1.pillar.top_mini_scoreboard가 매 프레임
# ~0.37ms(정상 상태에서 픽셀 불변인데도 ~50 프리미티브 재발행)로 확인되어,
# 트리 안 실캔버스에서는 리테인드 자식 호스트에 그리고 상태 키 변화/애니메이션
# 창에만 queue_redraw 하도록 바꿨다. 이 씰은 다음을 봉인한다:
#  (1) redraw 게이트: 동일 상태 반복 호출은 redraw 요청 0회 (perf 본체)
#  (2) 키 커버리지: 점수/품질/스테이크/레이아웃(레터박스 숨김 포함) 변화가
#      각각 redraw를 유발 (Lazy Applied-Key Re-Apply Trap — 키 누락 방지)
#  (3) 애니메이션 창: 스파클 진행/듀스는 매 호출 redraw + 창 종료 정착 1회
#  (4) 폴백: 비-노드 캔버스(스모크/헤드리스 픽스처)와 호스트 부착 전 프레임은
#      기존 즉시 경로 유지 (정확성-동일 폴백)
#  (5) 위임 파이프라인: 호스트 render_to가 최신 인자를 그대로 전달
#  (6) 스폰-글라이드 트랩 준수: physics_interpolation_mode == OFF
#
# 반증검증(수동, in-place 토글 — git reset 금지):
#  - update_state의 키 비교를 제거(항상 queue_redraw)하면 (1) 레그 RED.
#  - _build_top_mini_state_key에서 quality_scale 항을 빼면 (2) 품질 레그 RED.
#  - draw_top_mini의 호스트 분기를 제거하면 (1)·(5) 레그 RED.

const ScoreboardRenderer := preload("res://scripts/hud/scoreboard_renderer.gd")
const ScoreboardTopMiniRetainedHost := preload("res://scripts/hud/scoreboard_top_mini_retained_host.gd")

var _failures: Array[String] = []


class FakeForwardTopMiniRenderer:
	extends RefCounted

	var draw_calls := 0
	var last_player_score := -1
	var last_canvas: Object = null

	func draw(
		canvas: Node2D,
		_game_offset: Vector2,
		_game_size: Vector2,
		_gameplay_width: float,
		player_score: int,
		_boss_score: int,
		_deuce_mode: bool,
		_sparkle_timer: float,
		_sparkle_duration: float,
		_t: float,
		_quality_scale: float = 1.0,
		_stakes: Dictionary = {}
	) -> void:
		draw_calls += 1
		last_player_score = player_score
		last_canvas = canvas


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_non_node_canvas_falls_back_inline()
	await _verify_retained_host_redraw_gating()

	if _failures.is_empty():
		print("scoreboard_top_mini_retained_host_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _draw_once(
	renderer: Object,
	canvas: Object,
	player_score: int = 3,
	boss_score: int = 1,
	deuce_mode: bool = false,
	sparkle_timer: float = 0.0,
	quality_scale: float = 0.58,
	stakes: Dictionary = {},
	game_offset: Vector2 = Vector2(260.0, 40.0)
) -> void:
	renderer.draw_top_mini(
		canvas,
		game_offset,
		Vector2(760.0, 750.0),
		760.0,
		player_score,
		boss_score,
		deuce_mode,
		sparkle_timer,
		0.35,
		1.25,
		quality_scale,
		stakes
	)


func _verify_non_node_canvas_falls_back_inline() -> void:
	var renderer := ScoreboardRenderer.new()
	var fake_top := FakeForwardTopMiniRenderer.new()
	renderer.top_mini_renderer = fake_top
	_draw_once(renderer, null)
	_draw_once(renderer, null)
	_expect(fake_top.draw_calls == 2, "non-node canvas should keep the inline immediate path every call")
	await process_frame


func _verify_retained_host_redraw_gating() -> void:
	var renderer := ScoreboardRenderer.new()
	var fake_top := FakeForwardTopMiniRenderer.new()
	renderer.top_mini_renderer = fake_top
	var canvas := Node2D.new()
	root.add_child(canvas)

	# 생성 프레임: 호스트는 아직 부착 전이라 즉시 경로 폴백이 그린다.
	_draw_once(renderer, canvas)
	_expect(fake_top.draw_calls == 1, "attach-gap frame should fall back to the inline path")

	# deferred add_child 플러시 시점은 엔진 메인루프 순서에 민감하므로 bounded
	# 대기(그 사이 draw 호출 없음 — 폴백 카운트는 1로 유지된다).
	var host: Node = null
	for _spin in range(10):
		host = canvas.get_node_or_null("TopMiniScoreboardRetainedHost")
		if host != null and host.is_inside_tree():
			break
		await process_frame
	_expect(host != null and host.is_inside_tree(), "retained host should attach under the live canvas")
	if host == null:
		root.remove_child(canvas)
		canvas.free()
		return
	_expect(
		host.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF,
		"retained host must opt out of physics interpolation (spawn-glide trap)"
	)

	# 부착 대기 프레임 동안 큐된 redraw가 실제 _draw로 디스패치되어 페이크
	# 렌더러에 위임됐어야 한다(리테인드 파이프라인 라이브 증거 — 헤드리스에서도
	# CanvasItem draw 디스패치는 돈다).
	_expect(host.draw_invocation_count >= 1, "queued redraw should dispatch the host _draw at least once")

	# (1) redraw 게이트: 부착 후 동일 상태 반복 호출은 inline 0회 + redraw 0회.
	# fake_top.draw_calls는 inline 경로와 호스트 _draw 디스패치를 모두 세므로,
	# await 없는 동기 구간에서는 델타 == inline 호출 수다.
	var rr_baseline: int = host.redraw_request_count
	var inline_calls_before: int = fake_top.draw_calls
	_draw_once(renderer, canvas)
	_draw_once(renderer, canvas)
	_draw_once(renderer, canvas)
	_expect(fake_top.draw_calls == inline_calls_before, "attached host should replace the inline path")
	_expect(
		host.redraw_request_count == rr_baseline,
		"identical steady state must not request redraw (got %d extra)" % (host.redraw_request_count - rr_baseline)
	)

	# (2) 키 커버리지: 각 입력 변화가 정확히 1회 redraw.
	_draw_once(renderer, canvas, 4)
	_expect(host.redraw_request_count == rr_baseline + 1, "score change should request one redraw")
	_draw_once(renderer, canvas, 4, 1, false, 0.0, 1.0)
	_expect(host.redraw_request_count == rr_baseline + 2, "quality scale change should request one redraw")
	_draw_once(renderer, canvas, 4, 1, false, 0.0, 1.0, {"player_can_win": true})
	_expect(host.redraw_request_count == rr_baseline + 3, "stakes change should request one redraw")
	_draw_once(renderer, canvas, 4, 1, false, 0.0, 1.0, {"player_can_win": true}, Vector2(260.0, 10.0))
	_expect(
		host.redraw_request_count == rr_baseline + 4,
		"letterbox-hide offset change should request one settling redraw"
	)
	_draw_once(renderer, canvas, 4, 1, false, 0.0, 1.0, {"player_can_win": true}, Vector2(260.0, 10.0))
	_expect(host.redraw_request_count == rr_baseline + 4, "hidden state should stay settled without redraws")

	# (3) 애니메이션 창: 스파클 진행은 매 호출 redraw, 종료 시 정착 1회.
	_draw_once(renderer, canvas, 4, 1, false, 0.20)
	_draw_once(renderer, canvas, 4, 1, false, 0.15)
	_expect(host.redraw_request_count == rr_baseline + 6, "active sparkle window should redraw every call")
	_draw_once(renderer, canvas, 4, 1, false, 0.0)
	_expect(host.redraw_request_count == rr_baseline + 7, "sparkle window end should settle with one redraw")
	_draw_once(renderer, canvas, 4, 1, false, 0.0)
	_expect(host.redraw_request_count == rr_baseline + 7, "post-sparkle steady state should stop redrawing")
	var rr_deuce: int = host.redraw_request_count
	_draw_once(renderer, canvas, 4, 4, true)
	_draw_once(renderer, canvas, 4, 4, true)
	_expect(host.redraw_request_count == rr_deuce + 2, "deuce (t-animated flames) should redraw every call")

	# (5) 위임 파이프라인: render_to가 최신 인자를 그대로 전달.
	var probe := Node2D.new()
	var forwarded_before: int = fake_top.draw_calls
	host.render_to(probe)
	_expect(fake_top.draw_calls == forwarded_before + 1, "render_to should delegate to the top mini renderer")
	_expect(fake_top.last_player_score == 4, "render_to should forward the latest stored args")
	_expect(fake_top.last_canvas == probe, "render_to should draw onto the provided canvas")
	probe.free()

	# 중복 호스트 없음.
	var host_count := 0
	for child in canvas.get_children():
		if child.name == "TopMiniScoreboardRetainedHost":
			host_count += 1
	_expect(host_count == 1, "exactly one retained host should exist under the canvas")

	root.remove_child(canvas)
	canvas.free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
