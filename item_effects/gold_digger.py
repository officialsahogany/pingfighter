"""
골드디거 아이템 효과
골드 획득량이 25%~50% 증가하는 패시브 아이템
팔 부위 장착 (최대 2개까지 장착 가능, 보너스 누적)
"""

import os
import random

# 디버그 모드
DEBUG_GOLD_DIGGER = os.environ.get("DEBUG_GOLD_DIGGER", "0") == "1"

# 상수
GOLD_DIGGER_MIN_BONUS = 0.25  # 최소 25% 증가
GOLD_DIGGER_MAX_BONUS = 0.50  # 최대 50% 증가


class GoldDigger:
    def __init__(self):
        self.equipped_count = 0  # 장착된 골드디거 개수
        self.bonuses = []  # 각 골드디거의 보너스 리스트
        self.debug = DEBUG_GOLD_DIGGER

    def activate(self, game_state=None, current_stage=None, width=600, height=750):
        """골드디거 획득 및 활성화 (스택 추가)"""
        # 새로운 골드디거의 보너스 결정 (25%~50%)
        new_bonus = random.uniform(GOLD_DIGGER_MIN_BONUS, GOLD_DIGGER_MAX_BONUS)
        self.bonuses.append(new_bonus)

        if self.debug:
            print(f"[GOLD_DIGGER] 획득! 골드 보너스: +{new_bonus * 100:.1f}% (총 {len(self.bonuses)}개)")

        return True

    def equip(self):
        """골드디거 장착 (스택 증가)"""
        if self.bonuses:
            self.equipped_count = len(self.bonuses)
            if self.debug:
                total_bonus = sum(self.bonuses)
                print(f"[GOLD_DIGGER] 장착됨 - 총 {self.equipped_count}개, 골드 획득량 +{total_bonus * 100:.1f}%")
            return True
        return False

    def unequip(self):
        """골드디거 장착 해제"""
        if self.equipped_count > 0:
            self.equipped_count = 0
            if self.debug:
                print("[GOLD_DIGGER] 장착 해제")
            return True
        return False

    def deactivate(self):
        """골드디거 제거 (게임 종료)"""
        self.equipped_count = 0
        self.bonuses = []

        if self.debug:
            print("[GOLD_DIGGER] 비활성화")

    def update(self, current_stage=None):
        """상태 업데이트 (패시브 아이템이므로 특별한 업데이트 없음)"""
        pass

    def draw_effects(self, screen, **kwargs):
        """시각 효과 그리기 (패시브 아이템이므로 특별한 효과 없음)"""
        pass

    def get_gold_multiplier(self):
        """골드 획득량 배율 반환 (모든 장착된 골드디거 보너스 합산)

        Returns:
            float: 1.0 + 총 보너스 (장착 시) 또는 1.0 (미장착 시)
        """
        if self.equipped_count <= 0 or not self.bonuses:
            return 1.0  # 장착하지 않으면 보너스 없음

        # 장착된 개수만큼의 보너스 합산
        total_bonus = sum(self.bonuses[:self.equipped_count])
        return 1.0 + total_bonus

    def get_bonus_percentage(self):
        """현재 골드 보너스 퍼센트 반환 (표시용)"""
        if self.equipped_count <= 0 or not self.bonuses:
            return 0.0
        total_bonus = sum(self.bonuses[:self.equipped_count])
        return total_bonus * 100

    def is_active(self):
        """소지 중인지 여부"""
        return len(self.bonuses) > 0

    def is_equipped(self):
        """장착 중인지 여부"""
        return self.equipped_count > 0

    @property
    def active(self):
        """호환성을 위한 active 프로퍼티"""
        return self.is_active()

    @property
    def equipped(self):
        """호환성을 위한 equipped 프로퍼티"""
        return self.is_equipped()

    @property
    def gold_bonus(self):
        """호환성을 위한 gold_bonus 프로퍼티 (총 보너스 반환)"""
        if not self.bonuses:
            return 0.0
        return sum(self.bonuses[:max(1, self.equipped_count)])


# 싱글톤 인스턴스
gold_digger_instance = None


def get_gold_digger_instance():
    global gold_digger_instance
    if gold_digger_instance is None:
        gold_digger_instance = GoldDigger()
    return gold_digger_instance


def activate_gold_digger(game_state=None, current_stage=None, width=600, height=750):
    """골드디거 획득 (스택 추가)"""
    digger = get_gold_digger_instance()
    return digger.activate(game_state, current_stage, width, height)


def deactivate_gold_digger():
    """골드디거 제거"""
    digger = get_gold_digger_instance()
    digger.deactivate()


def equip_gold_digger():
    """골드디거 장착"""
    digger = get_gold_digger_instance()
    return digger.equip()


def unequip_gold_digger():
    """골드디거 장착 해제"""
    digger = get_gold_digger_instance()
    return digger.unequip()


def update_gold_digger(current_stage=None):
    """골드디거 업데이트"""
    digger = get_gold_digger_instance()
    digger.update(current_stage)


def draw_gold_digger_effects(screen, **kwargs):
    """골드디거 효과 그리기"""
    digger = get_gold_digger_instance()
    digger.draw_effects(screen, **kwargs)


def get_gold_digger_multiplier():
    """골드디거로 인한 골드 획득량 배율 반환 (모든 스택 합산)"""
    digger = get_gold_digger_instance()
    return digger.get_gold_multiplier()


def get_gold_digger_bonus_percentage():
    """골드디거 보너스 퍼센트 반환 (표시용)"""
    digger = get_gold_digger_instance()
    return digger.get_bonus_percentage()


def is_gold_digger_active():
    """골드디거 소지 중인지 여부"""
    digger = get_gold_digger_instance()
    return digger.is_active()


def is_gold_digger_equipped():
    """골드디거 장착 중인지 여부"""
    digger = get_gold_digger_instance()
    return digger.is_equipped()


def get_gold_digger_count():
    """장착된 골드디거 개수 반환"""
    digger = get_gold_digger_instance()
    return digger.equipped_count


def reset_gold_digger():
    """골드디거 상태 완전 초기화 (게임 종료/사망 시)"""
    global gold_digger_instance
    if gold_digger_instance:
        gold_digger_instance.deactivate()
    gold_digger_instance = None
