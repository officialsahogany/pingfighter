"""
독안개장갑 (Venom Mist Gauntlet) — 바이퍼 전용 패시브 아이템 (부위: 팔)

베놈 엣지 적중 시 30~50% 확률로 보스 주변에 독안개 영역 생성.
- 독안개 안에서 보스 이동속도 -50% 감소
- 1초당 보스 게이지 50 감소 (스테이지 6 홍련: 구슬게이지 1개 감소)
"""

from __future__ import annotations
import random
import math
from typing import Optional

# ─── 내부 상태 (모듈 전역 변수) ───
_active = False                   # 아이템 장착/활성화 여부
_mist_active = False              # 현재 독안개 영역 활성 여부
_mist_timer = 0                   # 독안개 남은 프레임 (0이면 비활성)
_mist_x = 0.0                    # 독안개 중심 X
_mist_y = 0.0                    # 독안개 중심 Y
_mist_radius = 120               # 독안개 반경 (px)
_mist_duration_frames = 180       # 독안개 지속시간 기본 3초 (롤옵션 2~5초)
_trigger_chance = 0.40            # 발동 확률 기본값 (40%) — 롤옵션 30~50%
_boss_slow_amount = 0.50          # 보스 감속률 50%
_gauge_drain_per_sec = 50         # 1초당 보스 게이지 감소량
_hongryun_orb_drain_interval = 60 # 홍련 구슬 감소 간격 (1초 = 60프레임)
_gauge_drain_accumulator = 0      # 게이지 감소 누적 카운터

# 연마 퍽 + 강화 보너스 지원
_enhancement_bonus_pct = 0        # 강화 버프 보너스 (장착 시 동기화)

# 파티클 상태 (독안개 시각 효과)
_mist_particles: list[dict] = []


# ─── 공개 함수들 ───

def activate_venom_mist_gauntlet() -> None:
    """아이템 활성화 (장착 시)"""
    global _active
    _active = True


def deactivate_venom_mist_gauntlet() -> None:
    """아이템 비활성화 (장착 해제 시)"""
    global _active, _mist_active, _mist_timer, _gauge_drain_accumulator
    global _mist_particles, _enhancement_bonus_pct, _mist_duration_frames
    _active = False
    _mist_active = False
    _mist_timer = 0
    _gauge_drain_accumulator = 0
    _mist_particles.clear()
    _enhancement_bonus_pct = 0
    _mist_duration_frames = 180


def is_venom_mist_active() -> bool:
    """아이템이 활성화(장착) 상태인지"""
    return _active


def is_mist_field_active() -> bool:
    """독안개 영역이 현재 활성 상태인지"""
    return _active and _mist_active and _mist_timer > 0


def set_trigger_chance(chance_pct: float) -> None:
    """발동 확률 설정 (롤옵션 적용용, 30~50)"""
    global _trigger_chance
    _trigger_chance = max(0.0, min(1.0, chance_pct / 100.0))


def get_trigger_chance() -> float:
    """현재 발동 확률 반환 (0.0~1.0)"""
    return _trigger_chance


def set_mist_duration_sec(sec: float) -> None:
    """독안개 지속시간 설정 (롤옵션 적용용, 2~5초)"""
    global _mist_duration_frames
    _mist_duration_frames = int(max(120, min(300, sec * 60)))


def get_mist_duration_sec() -> float:
    """현재 독안개 지속시간(초) 반환"""
    return _mist_duration_frames / 60.0


def set_enhancement_bonus(pct: float) -> None:
    """강화 버프 보너스 설정"""
    global _enhancement_bonus_pct
    _enhancement_bonus_pct = pct


def try_spawn_mist(boss_cx: float, boss_cy: float) -> bool:
    """베놈 엣지 적중 시 호출 — 확률 판정 후 독안개 생성.

    Returns True if mist was spawned.
    """
    if not _active:
        return False

    # 연마 퍽 + 강화 보너스 적용된 발동 확률
    effective_chance = _trigger_chance
    if _enhancement_bonus_pct > 0:
        effective_chance *= (1.0 + _enhancement_bonus_pct / 100.0)
    effective_chance = min(1.0, effective_chance)

    if random.random() > effective_chance:
        return False

    global _mist_active, _mist_timer, _mist_x, _mist_y
    global _gauge_drain_accumulator, _mist_particles
    _mist_active = True
    _mist_timer = _mist_duration_frames
    _mist_x = boss_cx
    _mist_y = boss_cy
    _gauge_drain_accumulator = 0
    _mist_particles.clear()
    # 초기 파티클 생성
    _spawn_initial_particles()
    return True


def update_mist(boss_cx: float, boss_cy: float, current_stage: int,
                boss_gauge_ref: dict) -> dict:
    """매 프레임 호출 — 독안개 업데이트.

    Args:
        boss_cx, boss_cy: 보스 현재 중심 좌표
        current_stage: 현재 스테이지 번호
        boss_gauge_ref: {'boss_special_gauge': int, 'hongryun_hit_count': int}
                        변경 사항을 딕셔너리로 반환

    Returns:
        dict with keys:
            'slow_active': bool — 보스가 독안개 안에 있는지
            'slow_amount': float — 감속률 (0.0~1.0)
            'gauge_drained': int — 이번 프레임에 감소된 게이지량
            'hongryun_orb_drained': int — 이번 프레임에 감소된 홍련 구슬 수
    """
    global _mist_timer, _mist_active, _gauge_drain_accumulator

    result = {
        'slow_active': False,
        'slow_amount': 0.0,
        'gauge_drained': 0,
        'hongryun_orb_drained': 0,
    }

    if not _active or not _mist_active or _mist_timer <= 0:
        return result

    _mist_timer -= 1
    if _mist_timer <= 0:
        _mist_active = False
        _mist_particles.clear()
        return result

    # 파티클 업데이트
    _update_particles()

    # 보스가 독안개 범위 안에 있는지 판정
    dx = boss_cx - _mist_x
    dy = boss_cy - _mist_y
    dist = math.sqrt(dx * dx + dy * dy)

    if dist <= _mist_radius:
        result['slow_active'] = True
        result['slow_amount'] = _boss_slow_amount

        # 게이지 감소 — 프레임당 0.5 (초당 30)
        _gauge_drain_accumulator += 0.5

        if current_stage == 5:
            # 스테이지 6 홍련 (코드상 stage5) → 구슬게이지 1초당 1개 감소
            if _gauge_drain_accumulator >= _hongryun_orb_drain_interval:
                _gauge_drain_accumulator = 0
                result['hongryun_orb_drained'] = 1
        else:
            # 일반 스테이지 → 프레임당 0.5씩 누적, 1 이상이면 정수분 드레인
            if _gauge_drain_accumulator >= 1.0:
                drained = int(_gauge_drain_accumulator)
                _gauge_drain_accumulator -= drained
                result['gauge_drained'] = drained

    return result


def get_mist_position() -> tuple:
    """독안개 중심 좌표 반환"""
    return (_mist_x, _mist_y)


def get_mist_radius() -> int:
    """독안개 반경 반환"""
    return _mist_radius


def get_mist_alpha() -> float:
    """독안개 투명도 (0.0~1.0) — 남은 시간에 따라 페이드아웃"""
    if not _mist_active or _mist_timer <= 0:
        return 0.0
    # 마지막 1초(60프레임)에 페이드아웃
    if _mist_timer < 60:
        return _mist_timer / 60.0
    return 1.0


def get_mist_particles() -> list:
    """현재 파티클 목록 반환 (렌더링용)"""
    return _mist_particles


def get_mist_timer_ratio() -> float:
    """독안개 잔여 시간 비율 (1.0=방금 시작, 0.0=끝남) — 애니메이션 페이즈용"""
    if not _mist_active or _mist_timer <= 0:
        return 0.0
    return _mist_timer / _mist_duration_frames


def get_mist_elapsed_frames() -> int:
    """독안개 경과 프레임 반환 — sin/cos 애니메이션 시드용"""
    if not _mist_active:
        return 0
    return _mist_duration_frames - _mist_timer


def reset_all() -> None:
    """게임 리셋 시 모든 상태 초기화"""
    global _active, _mist_active, _mist_timer, _gauge_drain_accumulator
    global _mist_particles, _trigger_chance, _enhancement_bonus_pct, _mist_duration_frames
    _active = False
    _mist_active = False
    _mist_timer = 0
    _gauge_drain_accumulator = 0
    _mist_particles.clear()
    _trigger_chance = 0.40
    _enhancement_bonus_pct = 0
    _mist_duration_frames = 180


# ─── 파티클 내부 함수 ───

def _make_fog_puff(layer: str = "mid") -> dict:
    """안개 퍼프 파티클 생성. layer: 'deep' | 'mid' | 'wisp'"""
    angle = random.uniform(0, math.tau)

    if layer == "deep":
        # 깊은 층: 큰 덩어리, 느리게 소용돌이
        dist = random.uniform(0, _mist_radius * 0.5)
        size = random.randint(18, 35)
        alpha = random.randint(30, 55)
        life = random.randint(80, 140)
        speed = random.uniform(0.08, 0.2)
        drift_phase = random.uniform(0, math.tau)
    elif layer == "wisp":
        # 가장자리 갈래: 얇고 빠르게 흩어지는 줄기
        dist = random.uniform(_mist_radius * 0.5, _mist_radius * 1.05)
        size = random.randint(6, 14)
        alpha = random.randint(25, 60)
        life = random.randint(30, 70)
        speed = random.uniform(0.3, 0.7)
        drift_phase = random.uniform(0, math.tau)
    else:  # mid
        # 중간 층: 표준 안개 구름
        dist = random.uniform(0, _mist_radius * 0.8)
        size = random.randint(10, 22)
        alpha = random.randint(35, 70)
        life = random.randint(50, 100)
        speed = random.uniform(0.12, 0.35)
        drift_phase = random.uniform(0, math.tau)

    vx = math.cos(angle) * speed
    vy = math.sin(angle) * speed
    return {
        'x': _mist_x + math.cos(angle) * dist,
        'y': _mist_y + math.sin(angle) * dist,
        'vx': vx, 'vy': vy,
        'size': size,
        'base_alpha': alpha,
        'alpha': alpha,
        'life': life,
        'max_life': life,
        'layer': layer,
        'drift_phase': drift_phase,  # 개별 소용돌이 위상
        'grow': random.uniform(0.98, 1.02),  # 크기 변화율
    }


def _spawn_initial_particles():
    """독안개 생성 시 초기 파티클 배치 — 3계층 안개"""
    global _mist_particles
    # deep 층: 8개 — 코어를 채우는 두꺼운 안개
    for _ in range(8):
        _mist_particles.append(_make_fog_puff("deep"))
    # mid 층: 14개 — 부드러운 볼륨감
    for _ in range(14):
        _mist_particles.append(_make_fog_puff("mid"))
    # wisp 층: 8개 — 가장자리 실타래
    for _ in range(8):
        _mist_particles.append(_make_fog_puff("wisp"))


def _update_particles():
    """파티클 위치/수명 업데이트 + 소용돌이 드리프트 + 새 파티클 보충"""
    global _mist_particles

    elapsed = _mist_duration_frames - _mist_timer
    t = elapsed * 0.02  # 느린 시간 흐름

    alive = []
    for p in _mist_particles:
        # 소용돌이 드리프트 (중심 주위로 천천히 회전)
        dx = p['x'] - _mist_x
        dy = p['y'] - _mist_y
        dist = math.sqrt(dx * dx + dy * dy)
        swirl_strength = 0.008 if p['layer'] == 'deep' else 0.015
        if dist > 1:
            # 접선 방향 + 약간 바깥 확산
            tx = -dy / dist * swirl_strength
            ty = dx / dist * swirl_strength
            p['vx'] = p['vx'] * 0.92 + tx + random.uniform(-0.02, 0.02)
            p['vy'] = p['vy'] * 0.92 + ty + random.uniform(-0.02, 0.02)

        p['x'] += p['vx']
        p['y'] += p['vy']

        # 크기 맥동
        p['size'] = max(3, p['size'] * p['grow'])
        if p['size'] > 40:
            p['grow'] = min(p['grow'], 0.99)
        elif p['size'] < 6 and p['layer'] != 'wisp':
            p['grow'] = max(p['grow'], 1.01)

        # 수명 기반 알파 — 부드러운 페이드인/아웃
        p['life'] -= 1
        life_ratio = p['life'] / max(1, p['max_life'])
        # ease: 처음 20% 페이드인, 마지막 30% 페이드아웃
        if life_ratio > 0.8:
            fade = (1.0 - life_ratio) / 0.2
        elif life_ratio < 0.3:
            fade = life_ratio / 0.3
        else:
            fade = 1.0
        p['alpha'] = int(p['base_alpha'] * fade)

        if p['life'] > 0 and p['alpha'] > 0:
            alive.append(p)

    _mist_particles = alive

    # 파티클 보충 — 안개가 자연스럽게 유지되도록
    deep_count = sum(1 for p in _mist_particles if p['layer'] == 'deep')
    mid_count = sum(1 for p in _mist_particles if p['layer'] == 'mid')
    wisp_count = sum(1 for p in _mist_particles if p['layer'] == 'wisp')

    if deep_count < 6:
        _mist_particles.append(_make_fog_puff("deep"))
    if mid_count < 10:
        _mist_particles.append(_make_fog_puff("mid"))
        if random.random() < 0.5:
            _mist_particles.append(_make_fog_puff("mid"))
    if wisp_count < 6:
        _mist_particles.append(_make_fog_puff("wisp"))
