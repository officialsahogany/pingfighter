extends RefCounted

const MatchScoreState := preload("res://scripts/core/match_score_state.gd")
const ScoreboardOverlayRenderer := preload("res://scripts/hud/scoreboard_overlay_renderer.gd")
const ScoreboardTopMiniRenderer := preload("res://scripts/hud/scoreboard_top_mini_renderer.gd")
const ScoreboardTopMiniRetainedHost := preload("res://scripts/hud/scoreboard_top_mini_retained_host.gd")

const TOP_MINI_RETAINED_HOST_NAME := "TopMiniScoreboardRetainedHost"

var overlay_renderer: Object = ScoreboardOverlayRenderer.new()
var top_mini_renderer: Object = ScoreboardTopMiniRenderer.new()
var _top_mini_host_pending: Node = null
var _top_mini_external_visible := true
var _top_mini_presentation_visible := true


func draw_top_mini(
	canvas: Node2D,
	game_offset: Vector2,
	game_size: Vector2,
	gameplay_width: float,
	player_score: int,
	boss_score: int,
	deuce_mode: bool,
	sparkle_timer: float,
	sparkle_duration: float,
	t: float,
	quality_scale: float = 1.0,
	stakes: Dictionary = {},
	presentation_visible: bool = true
) -> void:
	# 로딩 전환의 외부 수명과 현재 화면의 수명을 합성한다. NPC NODE_MODAL은
	# 리테인드 호스트의 지난 프레임 커맨드까지 숨겨야 하므로 단순 draw skip으로
	# 끝내지 않고, 이미 부착됐거나 deferred 부착 대기 중인 호스트도 끈다.
	_top_mini_presentation_visible = presentation_visible
	var effective_visible: bool = _top_mini_external_visible and _top_mini_presentation_visible
	_apply_top_mini_host_visibility(canvas, effective_visible)
	if not effective_visible:
		return
	# 정상 상태의 미니 스코어보드는 픽셀 불변이므로 리테인드 자식 호스트에
	# 그리고, 상태 키 변화 / 애니메이션 창에만 redraw 한다(호스트 주석 참조).
	# 트리 밖 캔버스(스모크 픽스처, 헤드리스)나 호스트 부착 전 프레임은 기존
	# 즉시 경로로 폴백한다 — 폴백 동안에도 시각 동일.
	var host: Node2D = _get_or_create_top_mini_retained_host(canvas)
	if host != null:
		_set_top_mini_host_visible(host, true)
		# 발동선은 룰 정본에서 읽는다. 리터럴 4를 두면 7점제에서 평범한 4:4·5:5가
		# is_deuce로 잡혀 redraw 플래그가 매 프레임 서고(픽셀 불변인데도 재드로),
		# 상태 키까지 오염된다 — 듀스 표시가 안 뜨므로 눈으로는 안 보이는 회귀다.
		var is_deuce: bool = deuce_mode or (
			player_score >= MatchScoreState.DEUCE_TRIGGER
			and boss_score >= MatchScoreState.DEUCE_TRIGGER
			and player_score == boss_score
		)
		var texture_ready: bool = (
			top_mini_renderer != null
			and top_mini_renderer.has_method("are_hwangyeok_textures_ready")
			and bool(top_mini_renderer.are_hwangyeok_textures_ready())
		)
		host.update_state(
			top_mini_renderer,
			[
				game_offset, game_size, gameplay_width, player_score, boss_score,
				deuce_mode, sparkle_timer, sparkle_duration, t, quality_scale, stakes,
			],
			_build_top_mini_state_key(
				game_offset, game_size, gameplay_width, player_score, boss_score,
				is_deuce, quality_scale, stakes, sparkle_timer, texture_ready
			),
			sparkle_timer > 0.0 or is_deuce
		)
		if host.is_inside_tree():
			return
	top_mini_renderer.draw(
		canvas,
		game_offset,
		game_size,
		gameplay_width,
		player_score,
		boss_score,
		deuce_mode,
		sparkle_timer,
		sparkle_duration,
		t,
		quality_scale,
		stakes
	)


func set_top_mini_visible(owner: Object, value: bool) -> void:
	_top_mini_external_visible = value
	_apply_top_mini_host_visibility(owner, _top_mini_external_visible and _top_mini_presentation_visible)


func _apply_top_mini_host_visibility(owner: Object, value: bool) -> void:
	if _top_mini_host_pending != null and is_instance_valid(_top_mini_host_pending):
		_set_top_mini_host_visible(_top_mini_host_pending, value)
	if owner is Node:
		var existing: Node = (owner as Node).get_node_or_null(TOP_MINI_RETAINED_HOST_NAME)
		if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
			_set_top_mini_host_visible(existing, value)


func _set_top_mini_host_visible(host: Object, value: bool) -> void:
	if host == null or not is_instance_valid(host):
		return
	if host.has_method("set_presentation_visible"):
		host.set_presentation_visible(value)
	elif host is CanvasItem:
		(host as CanvasItem).visible = value


# 리테인드 호스트 redraw 게이트 키의 단일 소스. 렌더 출력에 영향을 주는 모든
# 비-애니메이션 입력이 여기 있어야 한다(누락 = 조용한 스테일 픽셀). t /
# sparkle 진행값은 애니메이션 창 플래그(animated)가 담당하므로 키에서 제외하되,
# 스파클 창의 켜짐/꺼짐 경계는 bool로 넣어 창 종료 시 정착 프레임을 1회 그린다.
func _build_top_mini_state_key(
	game_offset: Vector2,
	game_size: Vector2,
	gameplay_width: float,
	player_score: int,
	boss_score: int,
	is_deuce: bool,
	quality_scale: float,
	stakes: Dictionary,
	sparkle_timer: float,
	texture_ready: bool = false
) -> Array:
	return [
		game_offset,
		game_size,
		gameplay_width,
		player_score,
		boss_score,
		is_deuce,
		quality_scale,
		bool(stakes.get("player_can_win", false)),
		bool(stakes.get("boss_can_win", false)),
		sparkle_timer > 0.0,
		texture_ready,
	]


# boost fx host와 같은 lazy-attach 패턴: 트리 안의 실캔버스에서만 호스트를
# 만들고, 생성-부착 사이 프레임은 pending 강참조로 중복 생성을 막는다.
func _get_or_create_top_mini_retained_host(canvas: Object) -> Node2D:
	if not (canvas is Node2D):
		return null
	var parent: Node = canvas as Node
	if not parent.is_inside_tree():
		return null
	var existing: Node = parent.get_node_or_null(TOP_MINI_RETAINED_HOST_NAME)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion() and existing is Node2D:
		_top_mini_host_pending = null
		return existing
	# 스테일 pending 가드: 배틀 씬 teardown이 부착된 호스트를 해제한 뒤에도
	# pending 참조가 남을 수 있다(호스트가 그 씬의 마지막 HUD 프레임에
	# 만들어진 경우 등). freed 인스턴스는 'is' 타입 검사조차 "previously
	# freed instance" 에러를 내므로 반드시 is_instance_valid를 먼저 통과시킨다.
	if _top_mini_host_pending != null and not is_instance_valid(_top_mini_host_pending):
		_top_mini_host_pending = null
	if _top_mini_host_pending != null and not _top_mini_host_pending.is_queued_for_deletion() and _top_mini_host_pending is Node2D:
		return _top_mini_host_pending
	var host: Node2D = ScoreboardTopMiniRetainedHost.new()
	_top_mini_host_pending = host
	parent.call_deferred("add_child", host)
	return host


func draw_overlay(
	canvas: Node2D,
	hud_state,
	gameplay_width: float,
	gameplay_height: float,
	win_goal: int,
	fade_in_duration: float,
	draw_context: Dictionary = {},
	perf_logger: Object = null
) -> void:
	overlay_renderer.draw(
		canvas,
		hud_state,
		gameplay_width,
		gameplay_height,
		win_goal,
		fade_in_duration,
		draw_context,
		perf_logger
	)
