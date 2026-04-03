"""
다우징 고글 (dowsing_goggles) - 머리 부위 패시브 아이템.

장착 시 퍽 선택지가 1~2개 증가합니다 (기본 3+골드변환 → 4~5+골드변환).
롤 옵션: 퍽 선택지 증가 1~2개.
"""


# ── 글로벌 상태 ──
_extra_perk_choices = 0          # 현재 장착된 고글의 추가 퍽 선택지 수
_enhancement_bonus_pct = 0       # 강화 버프 보너스


def get_extra_perk_choices() -> int:
    """현재 추가 퍽 선택지 수 반환 (장착 해제 시 0)."""
    return _extra_perk_choices


def set_extra_perk_choices(value: int) -> None:
    """추가 퍽 선택지 수 설정."""
    global _extra_perk_choices
    _extra_perk_choices = max(0, min(2, int(value)))


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
    global _extra_perk_choices, _enhancement_bonus_pct
    _extra_perk_choices = 0
    _enhancement_bonus_pct = 0


def reset_all() -> None:
    """게임 리셋 시 호출."""
    deactivate()
