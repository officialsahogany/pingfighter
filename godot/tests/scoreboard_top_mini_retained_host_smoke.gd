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
#  (7) 전환 가시성: 지연 생성 중 숨김도 호스트 부착 뒤까지 유지
#  (8) 수명 합성: external loading hide와 NODE_MODAL presentation hide가 서로
#      먼저 풀려도 다른 이유가 남아 있으면 리테인드/즉시 경로 모두 계속 숨김
#  (9) 범위: 활성 탑 NODE_MODAL만 숨기고 COMBAT 복귀와 비탑 캠페인은 표시
#  (10) deferred 부착 전 숨김도 새 호스트에 보존되어 stale 픽셀이 0프레임 노출
#
# 반증검증(수동, in-place 토글 — git reset 금지):
#  - update_state의 키 비교를 제거(항상 queue_redraw)하면 (1) 레그 RED.
#  - _build_top_mini_state_key에서 quality_scale 항을 빼면 (2) 품질 레그 RED.
#  - draw_top_mini의 호스트 분기를 제거하면 (1)·(5) 레그 RED.

const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const BattleSceneMatchEventDriver := preload("res://scripts/core/battle_scene_match_event_driver.gd")
const ScoreboardRenderer := preload("res://scripts/hud/scoreboard_renderer.gd")
const ScoreboardTopMiniRetainedHost := preload("res://scripts/hud/scoreboard_top_mini_retained_host.gd")
const Stage1TopMiniScoreboardSceneDrawer := preload("res://scripts/stages/stage1/stage1_top_mini_scoreboard_scene_drawer.gd")

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


class FakeTransitionOwner:
	extends Node2D

	var current_stage := 1
	var weather_type := ""
	var weather_event_active := false
	var weather_event_context := {}


class FakeTransitionScoreboardRenderer:
	extends RefCounted

	var visibility_calls: Array[bool] = []
	var last_canvas: Object = null

	func set_top_mini_visible(canvas: Object, is_visible: bool) -> void:
		last_canvas = canvas
		visibility_calls.append(is_visible)


class FakeTransitionRegistry:
	extends RefCounted

	var scoreboard_renderer := FakeTransitionScoreboardRenderer.new()

	func get_instance(key: String) -> Object:
		if key == "scoreboard_renderer":
			return scoreboard_renderer
		return null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)



class FakeTowerFlow:
	extends RefCounted

	var active := true
	var phase := "COMBAT"

	func is_active() -> bool:
		return active

	func get_phase_name() -> String:
		return phase


class FakeScoreState:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {"player_score": 7, "boss_score": 2, "deuce_mode": false}

	func would_score_finish(_side: String) -> bool:
		return false

	func is_player_in_danger() -> bool:
		return false


class FakeSceneRegistry:
	extends RefCounted

	var scoreboard_renderer: Object
	var score_state := FakeScoreState.new()
	var flow_owner: Object = null

	func _init(new_scoreboard_renderer: Object) -> void:
		scoreboard_renderer = new_scoreboard_renderer

	func get_instance(key: String) -> Object:
		if key == "scoreboard_renderer":
			return scoreboard_renderer
		if key == "match_score_state":
			return score_state
		return null

	func get_cached_instance(key: String) -> Object:
		if key == "tower_ascent_flow_owner":
			return flow_owner
		return null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _verify_non_node_canvas_falls_back_inline()
	await _verify_retained_host_redraw_gating()
	await _verify_visibility_survives_pending_attach()
	await _verify_stage_transition_driver_toggles_visibility()
	await _verify_tower_node_modal_visibility_lifecycle()
	await _verify_stale_freed_pending_host_recovers()

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
	game_offset: Vector2 = Vector2(260.0, 40.0),
	presentation_visible: bool = true
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
		stakes,
		presentation_visible
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
	# deferred attach 전에 로딩 hide가 들어와도 pending 호스트가 같은 상태로
	# 부착되어야 한다. draw skip만으로는 이 레그에서 이전 픽셀이 노출된다.
	renderer.set_top_mini_visible(canvas, false)

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
	_expect(not host.visible and not host.is_presentation_visible(), "pending host should attach hidden")
	renderer.set_top_mini_visible(canvas, true)
	_expect(host.visible and host.is_presentation_visible(), "external visibility restore should show the attached host")
	await process_frame

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

	# (6) 듀스 폴백 발동선은 룰 정본을 따라야 한다. deuce_mode=false인 평범한
	# 동점(구 리터럴 4:4 포함)은 정착 상태라 redraw가 서면 안 된다 — 듀스 표시는
	# 안 뜨므로 눈으로 안 보이는 상시 재드로 회귀다. 마지막 드로 상태를 바꾸므로
	# render_to 검증 뒤에 둔다.
	var below_trigger: int = MatchScoreState.DEUCE_TRIGGER - 1
	_draw_once(renderer, canvas, below_trigger, below_trigger, false)
	var rr_below: int = host.redraw_request_count
	_draw_once(renderer, canvas, below_trigger, below_trigger, false)
	_expect(
		host.redraw_request_count == rr_below,
		"a non-deuce tie below the trigger must stay settled (no per-frame redraw)"
	)
	# 반대로 정본 발동선에서의 동점은 deuce_mode 플래그 없이도 폴백이 잡아야 한다.
	_draw_once(renderer, canvas, MatchScoreState.DEUCE_TRIGGER, MatchScoreState.DEUCE_TRIGGER, false)
	var rr_at_trigger: int = host.redraw_request_count
	_draw_once(renderer, canvas, MatchScoreState.DEUCE_TRIGGER, MatchScoreState.DEUCE_TRIGGER, false)
	_expect(
		host.redraw_request_count > rr_at_trigger,
		"a tie at the deuce trigger should still animate through the fallback"
	)

	# 중복 호스트 없음.
	var host_count := 0
	for child in canvas.get_children():
		if child.name == "TopMiniScoreboardRetainedHost":
			host_count += 1
	_expect(host_count == 1, "exactly one retained host should exist under the canvas")

	root.remove_child(canvas)
	canvas.free()
	await process_frame


func _verify_visibility_survives_pending_attach() -> void:
	var renderer := ScoreboardRenderer.new()
	var fake_top := FakeForwardTopMiniRenderer.new()
	renderer.top_mini_renderer = fake_top
	var canvas := Node2D.new()
	root.add_child(canvas)

	_draw_once(renderer, canvas)
	var draw_calls_before_hide: int = fake_top.draw_calls
	renderer.set_top_mini_visible(canvas, false)
	_draw_once(renderer, canvas)
	_expect(fake_top.draw_calls == draw_calls_before_hide, "transition-hidden pending host must not fall back to inline drawing")
	var host: Node2D = null
	for _spin in range(10):
		host = canvas.get_node_or_null("TopMiniScoreboardRetainedHost") as Node2D
		if host != null and host.is_inside_tree():
			break
		await process_frame
	_expect(host != null and host.is_inside_tree(), "hidden pending host should still attach under the live canvas")
	if host != null:
		_expect(not host.visible, "stage-transition hiding should survive deferred host attachment")
		_draw_once(renderer, canvas)
		_expect(not host.visible, "drawing while transition-hidden must not reveal the top mini scoreboard")
		_expect(fake_top.draw_calls == draw_calls_before_hide, "transition-hidden attached host must not issue draw calls")
		renderer.set_top_mini_visible(canvas, true)
		_expect(host.visible, "finishing transition loading should restore the top mini scoreboard")

	root.remove_child(canvas)
	canvas.free()
	await process_frame


func _verify_stage_transition_driver_toggles_visibility() -> void:
	var driver := BattleSceneMatchEventDriver.new()
	var owner := FakeTransitionOwner.new()
	var registry := FakeTransitionRegistry.new()
	root.add_child(owner)

	driver.call("_begin_stage_transition_loading", owner, registry, 2)
	_expect(bool(driver.is_stage_transition_loading_active()), "stage transition should enter its loading gate")
	_expect(registry.scoreboard_renderer.visibility_calls == [false], "transition loading should hide the top mini scoreboard immediately")
	_expect(registry.scoreboard_renderer.last_canvas == owner, "top mini visibility should target the live battle canvas")

	driver.call("_finish_stage_transition_loading", owner, registry)
	_expect(not bool(driver.is_stage_transition_loading_active()), "finishing transition loading should release its gate")
	_expect(registry.scoreboard_renderer.visibility_calls == [false, true], "finishing transition loading should restore the top mini scoreboard")

	root.remove_child(owner)
	owner.free()
	await process_frame


# (8) 스테일 freed pending 복구: 호스트가 부착된 뒤 그 씬이 통째로 해제되면
func _verify_tower_node_modal_visibility_lifecycle() -> void:
	var renderer := ScoreboardRenderer.new()
	var fake_top := FakeForwardTopMiniRenderer.new()
	renderer.top_mini_renderer = fake_top
	var registry := FakeSceneRegistry.new(renderer)
	var drawer := Stage1TopMiniScoreboardSceneDrawer.new()
	var canvas := Node2D.new()
	root.add_child(canvas)

	# 비탑 일반 캠페인: flow cache가 없어도 기존 점수판 경로가 살아 있다.
	_draw_scene_once(drawer, registry, canvas)
	var host: Node = null
	for _spin in range(10):
		host = canvas.get_node_or_null("TopMiniScoreboardRetainedHost")
		if host != null and host.is_inside_tree():
			break
		await process_frame
	_expect(host != null and host.is_inside_tree(), "normal campaign should attach the retained score host")
	if host == null:
		root.remove_child(canvas)
		canvas.free()
		return
	_expect(host.visible, "normal campaign without tower flow must keep the mini scoreboard visible")

	var flow := FakeTowerFlow.new()
	registry.flow_owner = flow
	flow.active = false
	flow.phase = "NODE_MODAL"
	_draw_scene_once(drawer, registry, canvas)
	_expect(host.visible, "inactive tower flow must not alter the shared campaign HUD")

	# 다섯 생산 NPC 노드의 공용 수명 경계: 활성 NODE_MODAL에서만 숨긴다.
	flow.active = true
	flow.phase = "NODE_MODAL"
	var forwarded_before_hide: int = fake_top.draw_calls
	_draw_scene_once(drawer, registry, canvas)
	_expect(not host.visible and not host.is_presentation_visible(), "active tower NODE_MODAL must hide the retained score host")
	var probe := Node2D.new()
	host.render_to(probe)
	_expect(fake_top.draw_calls == forwarded_before_hide, "hidden retained host must not forward stale draw commands")

	# 로딩 hide가 겹친 뒤 external 이유만 풀어도 NODE_MODAL 이유가 남는다.
	renderer.set_top_mini_visible(canvas, false)
	renderer.set_top_mini_visible(canvas, true)
	_expect(not host.visible, "releasing external hide must not override active NODE_MODAL hide")

	# 전투 복귀: 같은 호스트를 다시 보이고 최신 7|2 상태를 위임한다.
	flow.phase = "COMBAT"
	_draw_scene_once(drawer, registry, canvas)
	_expect(host.visible and host.is_presentation_visible(), "tower COMBAT return must restore the mini scoreboard")
	host.render_to(probe)
	_expect(fake_top.draw_calls == forwarded_before_hide + 1, "combat restore should resume retained drawing")
	_expect(fake_top.last_player_score == 7, "combat restore should forward the current player score")

	# 역순 합성: COMBAT 중 external loading hide는 presentation draw가 덮지 못한다.
	renderer.set_top_mini_visible(canvas, false)
	_draw_scene_once(drawer, registry, canvas)
	_expect(not host.visible, "external loading hide must survive a visible COMBAT draw request")
	renderer.set_top_mini_visible(canvas, true)
	_expect(host.visible, "external loading restore should show the host when COMBAT remains visible")

	probe.free()
	root.remove_child(canvas)
	canvas.free()
	await process_frame


func _draw_scene_once(drawer: Object, registry: Object, canvas: Node2D) -> void:
	drawer.draw(
		canvas,
		{"width": 760.0, "top_mini_score_sparkle_duration": 0.35},
		registry,
		{},
		Vector2(260.0, 40.0),
		Vector2(760.0, 750.0),
		1.25
	)


# (10) 스테일 freed pending 복구: 호스트가 부착된 뒤 그 씬이 통째로 해제되면
# 렌더러의 pending 참조가 freed 인스턴스로 남는다(호스트가 씬의 마지막 HUD
# 프레임에 만들어진 배틀에서 실전 재현 — 2026-07-23 라이브 신고). 구 코드는
# 'is' 타입 검사를 is_instance_valid보다 먼저 태워 "Left operand of 'is' is a
# previously freed instance" SCRIPT ERROR를 냈다(러너가 RED로 승격 = 이 레그의
# 반증 축). 새 코드는 스테일 참조를 청소하고 새 캔버스에 새 호스트를 붙인다.
func _verify_stale_freed_pending_host_recovers() -> void:
	var renderer := ScoreboardRenderer.new()
	var fake_top := FakeForwardTopMiniRenderer.new()
	renderer.top_mini_renderer = fake_top

	var canvas_a := Node2D.new()
	root.add_child(canvas_a)
	_draw_once(renderer, canvas_a)
	# 부착까지 대기하되 draw는 더 부르지 않는다 — pending이 남은 채 부착되는
	# 실전 창을 재현하기 위함(정리는 다음 _get_or_create 호출에서만 일어남).
	var attached: Node = null
	for _spin in range(10):
		attached = canvas_a.get_node_or_null("TopMiniScoreboardRetainedHost")
		if attached != null and attached.is_inside_tree():
			break
		await process_frame
	_expect(attached != null and attached.is_inside_tree(), "precondition: host should attach under canvas A")

	root.remove_child(canvas_a)
	canvas_a.free()
	await process_frame

	var canvas_b := Node2D.new()
	root.add_child(canvas_b)
	_draw_once(renderer, canvas_b)
	var recovered: Node = null
	for _spin in range(10):
		recovered = canvas_b.get_node_or_null("TopMiniScoreboardRetainedHost")
		if recovered != null and recovered.is_inside_tree():
			break
		await process_frame
	_expect(
		recovered != null and recovered.is_inside_tree(),
		"stale freed pending should be cleared and a fresh host should attach under canvas B"
	)

	root.remove_child(canvas_b)
	canvas_b.free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
