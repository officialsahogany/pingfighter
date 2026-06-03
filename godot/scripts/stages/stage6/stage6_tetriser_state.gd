extends RefCounted

# Stage 6 테트리서 boss state (SCAFFOLD STUB).
#
# 기획: docs/stage6_tetriser_port_plan.md
# 원본 참조: pingfighter.py `stage7_*` / `STAGE7_*`,
#   game_logic/stage7_tetriser.py (순수 불변식: 게이지 충전 조건, 라운드
#   리셋 정책, 반사축 선택, 벽 스펙) — 1차 포팅 기준.
#
# 단일 cleanup 경로 규율 (홍련 패턴 / CLAUDE.md 보스 이벤트 누수 규칙):
# round-end / show_result / stage-leave 세 경로 모두 `_clear_combat_state()`
# 1개 함수를 통과시킨다. 새 상태 변수를 추가할 때도 그 함수 안에만 정리를
# 추가하면 누락이 발생할 수 없도록 유지한다.
#
# 현재는 스캐폴드 — 게이지(max 500/25초당)/낙하 테트로/가드/벽/초인/광선/
# 중앙 큐브 로직 미구현(TODO).

const STAGE_ID := 6
const BOSS_NAME := "테트리서"


func reset() -> void:
	_clear_combat_state()


func reset_round() -> void:
	_clear_combat_state()


func reset_for_result() -> void:
	_clear_combat_state()


func _clear_combat_state() -> void:
	# TODO(stage6): 게이지(스테이지 이탈 시에만 0) / 낙하 테트로 / 가드 블록 /
	# 좌우 벽 / 초인 상태·스케일·파티클 / 광선 / 중앙 큐브 / 테트로 파편 정리.
	pass


func update(_delta: float, _context: Dictionary, _deps: Dictionary = {}) -> Dictionary:
	# TODO(stage6): 게이지 자동 충전 + 스킬 스케줄(낙하/가드/벽) + 초인 드레인
	# + 중앙 큐브 + 충돌/파괴 매트릭스. 반환 dict는 홍련 패턴 참조.
	return {}


func get_boss_ai_context() -> Dictionary:
	return {}


func get_actor_draw_context() -> Dictionary:
	return {}


func get_hud_context(_stage_background: Object = null, _context: Dictionary = {}) -> Dictionary:
	return {}


func should_skip_ball_motion_step() -> bool:
	return false


func get_status() -> String:
	return "stage6_tetriser_scaffold"
