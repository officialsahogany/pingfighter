"""
다우징 고글 (dowsing_goggles) - 머리 부위 패시브 아이템.

장착 시 퍽 선택지가 1개 고정 증가합니다 (기본 3+골드변환 → 4+골드변환).
롤 옵션: 추가 퍽 등장 확률 30~60%.
  - 퍽 선택 시 해당 확률로 보너스 퍽 1개가 추가 등장합니다.
"""
import random as _random


# ── 글로벌 상태 ──
_bonus_perk_chance = 0.0         # 추가 퍽 등장 확률 (0.0 ~ 1.0)
_enhancement_bonus_pct = 0       # 강화 버프 보너스
_bonus_perk_triggered = False    # 이번 퍽 선택에서 보너스 퍽이 발동됐는지


def get_fixed_extra_perk_count() -> int:
    """고정 추가 퍽 선택지 수 (항상 1)."""
    return 1


def roll_bonus_perk() -> bool:
    """추가 퍽 등장 확률 판정. 성공 시 True."""
    global _bonus_perk_triggered
    if _bonus_perk_chance <= 0:
        _bonus_perk_triggered = False
        return False
    _bonus_perk_triggered = _random.random() < _bonus_perk_chance
    return _bonus_perk_triggered


def was_bonus_perk_triggered() -> bool:
    """가장 최근 roll_bonus_perk() 결과 반환."""
    return _bonus_perk_triggered


def clear_bonus_trigger() -> None:
    """보너스 트리거 플래그 초기화 (애니메이션 표시 후 호출)."""
    global _bonus_perk_triggered
    _bonus_perk_triggered = False


def get_bonus_perk_chance() -> float:
    """현재 추가 퍽 등장 확률 반환 (0.0 ~ 1.0)."""
    return _bonus_perk_chance


def set_bonus_perk_chance(value: float) -> None:
    """추가 퍽 등장 확률 설정 (0~100 정수 → 내부 0.0~1.0 변환)."""
    global _bonus_perk_chance
    # 정수(30~60)로 들어오면 0.01 곱해서 비율로 변환
    if value > 1.0:
        value = value / 100.0
    _bonus_perk_chance = max(0.0, min(1.0, float(value)))


def set_enhancement_bonus(pct: float) -> None:
    """강화 보너스 비율 설정."""
    global _enhancement_bonus_pct
    _enhancement_bonus_pct = pct


def get_enhancement_bonus() -> float:
    return _enhancement_bonus_pct


def activate() -> None:
    """장착 시 호출."""
    pass  # 실제 값은 apply_roll_bonuses_from_item 에서 설정


def deactivate() -> None:
    """장착 해제 시 호출."""
    global _bonus_perk_chance, _enhancement_bonus_pct, _bonus_perk_triggered
    _bonus_perk_chance = 0.0
    _enhancement_bonus_pct = 0
    _bonus_perk_triggered = False


def reset_all() -> None:
    """게임 리셋 시 호출."""
    deactivate()
