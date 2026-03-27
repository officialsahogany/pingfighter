"""
현자의 반지 아이템 효과
장착 시 모든 퍽(런타임 스킬) 레벨 +1 (고정 옵션)
장신구 부위 장착
"""

import os

# 디버그 모드
DEBUG_SAGE_RING = os.environ.get("DEBUG_SAGE_RING", "0") == "1"

# 상수
SAGE_RING_PERK_BONUS = 1  # 고정 +1 (롤옵션 아님)


class SageRing:
    def __init__(self):
        self.active = False
        self.perk_bonus = SAGE_RING_PERK_BONUS  # 모든 퍽 레벨 +1 (고정)
        self.debug = DEBUG_SAGE_RING

    def activate(self, game_state=None, current_stage=None, width=600, height=750):
        """현자의 반지 활성화 (장착 시)"""
        self.active = True
        if self.debug:
            print(f"[SAGE_RING] 활성화! 모든 퍽 레벨 +{self.perk_bonus}")
        return True

    def deactivate(self):
        """현자의 반지 비활성화 (장착 해제 시)"""
        self.active = False
        if self.debug:
            print("[SAGE_RING] 비활성화")

    def get_perk_bonus(self):
        """현재 퍽 레벨 보너스 반환"""
        if not self.active:
            return 0
        return self.perk_bonus

    def update(self, current_stage=None):
        """상태 업데이트 (패시브 아이템이므로 특별한 업데이트 없음)"""
        pass

    def draw_effects(self, screen, **kwargs):
        """시각 효과 그리기 (패시브 아이템이므로 특별한 효과 없음)"""
        pass


# 싱글톤 인스턴스
sage_ring_instance = None


def get_sage_ring_instance():
    global sage_ring_instance
    if sage_ring_instance is None:
        sage_ring_instance = SageRing()
    return sage_ring_instance


def activate_sage_ring(game_state=None, current_stage=None):
    ring = get_sage_ring_instance()
    return ring.activate(game_state, current_stage)


def deactivate_sage_ring():
    ring = get_sage_ring_instance()
    ring.deactivate()


def reset_sage_ring():
    """현자의 반지 완전 초기화 (게임 리셋 시)"""
    global sage_ring_instance
    if sage_ring_instance:
        sage_ring_instance.deactivate()
    sage_ring_instance = None
