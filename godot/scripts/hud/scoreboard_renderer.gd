extends RefCounted

const ScoreboardOverlayRenderer := preload("res://scripts/hud/scoreboard_overlay_renderer.gd")
const ScoreboardTopMiniRenderer := preload("res://scripts/hud/scoreboard_top_mini_renderer.gd")
const ScoreboardTopMiniRetainedHost := preload("res://scripts/hud/scoreboard_top_mini_retained_host.gd")

const TOP_MINI_RETAINED_HOST_NAME := "TopMiniScoreboardRetainedHost"

var overlay_renderer: Object = ScoreboardOverlayRenderer.new()
var top_mini_renderer: Object = ScoreboardTopMiniRenderer.new()
var _top_mini_host_pending: Node = null


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
	stakes: Dictionary = {}
) -> void:
	# 정상 상태의 미니 스코어보드는 픽셀 불변이므로 리테인드 자식 호스트에
	# 그리고, 상태 키 변화 / 애니메이션 창에만 redraw 한다(호스트 주석 참조).
	# 트리 밖 캔버스(스모크 픽스처, 헤드리스)나 호스트 부착 전 프레임은 기존
	# 즉시 경로로 폴백한다 — 폴백 동안에도 시각 동일.
	var host: Node2D = _get_or_create_top_mini_retained_host(canvas)
	if host != null:
		var is_deuce: bool = deuce_mode or (
			player_score >= 4 and boss_score >= 4 and player_score == boss_score
		)
		host.update_state(
			top_mini_renderer,
			[
				game_offset, game_size, gameplay_width, player_score, boss_score,
				deuce_mode, sparkle_timer, sparkle_duration, t, quality_scale, stakes,
			],
			_build_top_mini_state_key(
				game_offset, game_size, gameplay_width, player_score, boss_score,
				is_deuce, quality_scale, stakes, sparkle_timer
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
	sparkle_timer: float
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
	if existing is Node2D and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		_top_mini_host_pending = null
		return existing
	if _top_mini_host_pending is Node2D and is_instance_valid(_top_mini_host_pending) and not _top_mini_host_pending.is_queued_for_deletion():
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
