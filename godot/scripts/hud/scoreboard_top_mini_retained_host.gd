extends Node2D

# 상단 미니 스코어보드 리테인드 호스트.
#
# 미니 스코어보드는 정상 상태(스파클/듀스 애니메이션 없음)에서 픽셀 불변인데도
# 공유 필러 HUD 캔버스가 매 프레임 ~50개 프리미티브(크롬 + 7세그 숫자 + 콜론)를
# 즉시 드로우로 재발행하고 있었다(stage1.pillar.top_mini_scoreboard ~0.37ms/frame,
# 2026-07-23 S2 라이브 triage). CanvasItem은 드로우 커맨드를 리테인하므로 전용
# 자식 노드에 그리고, 상태 키가 바뀌거나(점수/듀스/스테이크/레이아웃/품질/스파클창
# 경계) 애니메이션 창(스파클 진행, 듀스 화염)일 때만 queue_redraw 한다.
# 드로우 자체는 기존 ScoreboardTopMiniRenderer.draw를 그대로 호출하므로 출력
# 픽셀은 즉시 경로와 동일하다(정확성-동일 위임 — 지오메트리 복제 없음).
#
# 전역 물리 보간 스폰-글라이드 트랩 준수: 이산 배치형 정지 오버레이 호스트는
# 생성 시 physics_interpolation_mode = OFF (docs/godot_runtime_traps.md).

# 스모크 직교 카운터: redraw 게이팅 계약을 엔진 draw 디스패치 없이 검증한다.
var draw_invocation_count: int = 0
var redraw_request_count: int = 0

var _top_mini_renderer: Object = null
var _draw_args: Array = []
var _last_state_key: Array = []
var _has_state := false
var _presentation_visible := true


func _init() -> void:
	name = "TopMiniScoreboardRetainedHost"
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


# 매 프레임 호출된다(즉시 경로와 같은 케이던스). 상태 키가 같고 애니메이션
# 창이 아니면 redraw를 요청하지 않는 것이 이 호스트의 존재 이유다. 키는 렌더
# 출력에 영향을 주는 모든 입력을 커버해야 한다(Lazy Applied-Key Re-Apply
# Trap — 키 누락 = 조용한 스테일 픽셀). 키 구성은
# scoreboard_renderer._build_top_mini_state_key가 단일 소스다.
func update_state(top_mini_renderer: Object, draw_args: Array, state_key: Array, animated: bool) -> void:
	_top_mini_renderer = top_mini_renderer
	_draw_args = draw_args
	if animated or not _has_state or state_key != _last_state_key:
		_has_state = true
		_last_state_key = state_key.duplicate(true)
		redraw_request_count += 1
		queue_redraw()


func set_presentation_visible(value: bool) -> void:
	_presentation_visible = value
	visible = value


func is_presentation_visible() -> bool:
	return _presentation_visible


func _draw() -> void:
	if not _presentation_visible:
		return
	draw_invocation_count += 1
	render_to(self)


# 테스트 시임: 엔진 draw 디스패치 없이 위임 파이프라인(최신 인자 그대로 전달)을
# 검증할 수 있도록 렌더 위임을 분리한다. 실제 _draw는 self를 캔버스로 넘긴다.
func render_to(canvas: Node2D) -> void:
	if not _presentation_visible or _top_mini_renderer == null or _draw_args.size() != 11:
		return
	_top_mini_renderer.draw(
		canvas,
		_draw_args[0],
		_draw_args[1],
		_draw_args[2],
		_draw_args[3],
		_draw_args[4],
		_draw_args[5],
		_draw_args[6],
		_draw_args[7],
		_draw_args[8],
		_draw_args[9],
		_draw_args[10]
	)
