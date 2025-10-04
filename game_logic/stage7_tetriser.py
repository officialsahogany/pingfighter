"""
Stage 7: 테트리서 관련 공용 훅
--------------------------------
pingfighter(레거시)와 모듈식 런타임에서 공통으로 참조할 수 있는
아주 얇은 규칙(인변트) 레이어입니다. 게임플레이 로직을 옮기지 않고,
중요 불변식(스탑워치 중 게이지 비충전 등)을 한 곳에서 정의해
호출부 실수를 방지합니다.

주의
- 무거운 상태/렌더링은 이 모듈에 두지 않습니다.
- 리셋/스테이지 전환 판단 등 순수 함수만 둡니다.
"""

from __future__ import annotations

try:
    import pygame  # 타입 힌트와 충돌 계산 유틸용
except Exception:  # 런타임 없는 정적 분석 환경 대비
    pygame = None  # type: ignore


def should_charge_gauge(*, current_stage: int, stopwatch_active: bool, stopwatch_timer: int) -> bool:
    """Stage 7 보스 게이지 충전 여부 판단.

    불변식:
    - 스탑워치로 시간이 정지(stopwatch_active and stopwatch_timer>0)인 동안에는
      어떤 게이지도 충전되지 않는다.
    - 스테이지 7일 때만 테트리서 게이지 충전 로직을 가동한다.
    """
    if current_stage != 7:
        return False
    if stopwatch_active and stopwatch_timer > 0:
        return False
    return True


def should_reset_transient_on_round_reset(*, current_stage: int) -> bool:
    """라운드 리셋 시 Stage7의 일시 상태를 즉시 비우는지 판단.

    기본 정책(레거시 호환):
    - Stage 7 라운드 간에는 일부 상태(예: 지속 게이지)는 보존 가능.
    - 따라서 현재 스테이지가 7일 때는 Stage7 내부 구조물/투사체의 하드 리셋을 건너뛸 수 있다.
    - 스테이지가 7이 아닐 때는 반드시 비운다.
    """
    return current_stage != 7


def choose_reflection_axis(prev_rect: "pygame.Rect", cur_rect: "pygame.Rect", block_rect: "pygame.Rect") -> str:
    """테트리스 벽 충돌 시 반사 축 선택 규칙을 통일한다.

    규칙(레거시 동작과 동일):
    - 직전 프레임 기준으로 좌우에서 진입했다면 수평 반사('h')
    - 위아래에서 진입했다면 수직 반사('v')
    - 애매한 경우 현재 프레임의 겹침량을 비교해 더 작은 축으로 반사

    Returns: 'h' 또는 'v'
    """
    # 직전 프레임 위치 기준 진입 방향 추정
    collided_horiz = prev_rect.right <= block_rect.left or prev_rect.left >= block_rect.right
    collided_vert = prev_rect.bottom <= block_rect.top or prev_rect.top >= block_rect.bottom

    if collided_horiz and not collided_vert:
        return 'h'
    if collided_vert and not collided_horiz:
        return 'v'

    # 겹침량 비교(현재 프레임)
    overlap_x = min(cur_rect.right - block_rect.left, block_rect.right - cur_rect.left)
    overlap_y = min(cur_rect.bottom - block_rect.top, block_rect.bottom - cur_rect.top)
    return 'h' if overlap_x < overlap_y else 'v'


def get_tetro_wall_spawn_spec(width: int = 600, height: int = 750) -> dict:
    """테트리스 벽 스폰 스펙 공용 정의(최소 수렴 버전).

    - 시각/충돌 안정성을 위해 모듈식 구현(stage_features) 기본값을 노출한다.
    - 레거시(pingfighter)는 기존 상수를 유지하되, 추후 단계에서 이 스펙을 채택 가능.

    Returns:
        dict: {
          'tile': 24,
          'cols': 5,
          'pieces_per_side': 10,
          'interval_sec': 30.0,
          'skill_cost': 50,
        }
    """
    # 화면 크기에 따른 적응 규칙은 향후 도입(현재는 고정값 유지)
    return {
        'tile': 24,
        'cols': 5,
        'pieces_per_side': 10,
        'interval_sec': 30.0,
        'skill_cost': 50,
    }


def get_tetro_wall_spawn_spec_legacy(width: int = 600, height: int = 750) -> dict:
    """레거시 pingfighter용 스펙(현행 동작 유지).

    - pingfighter.py는 tile=20, cols=5, 30초, 코스트 50, 측면당 10개로 설계됨.
    - 최소 수렴 단계에서는 수치 유지가 중요하므로 그대로 반환.
    """
    return {
        'tile': 20,
        'cols': 5,
        'pieces_per_side': 10,
        'interval_sec': 30.0,
        'skill_cost': 50,
    }
