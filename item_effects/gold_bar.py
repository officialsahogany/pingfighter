"""
금괴 아이템 효과
상점에 판매하면 2000골드 획득 가능한 패시브 아이템
장착 불가 - 인벤토리에 소지만 가능
상점에서 구매 불가 (상점에 스폰되지 않음)
"""

import os

# 디버그 모드
DEBUG_GOLD_BAR = os.environ.get("DEBUG_GOLD_BAR", "0") == "1"

# 상수
GOLD_BAR_SELL_PRICE = 2000  # 판매 가격
GOLD_BAR_SPEED_PENALTY = 0.30  # 소지 시 이동속도 30% 감소


class GoldBar:
    def __init__(self):
        self.active = False  # 소지 중인지 여부
        self.sell_price = GOLD_BAR_SELL_PRICE
        self.debug = DEBUG_GOLD_BAR

    def activate(self, game_state=None, current_stage=None, width=600, height=750):
        """금괴 획득 (인벤토리에 추가)"""
        self.active = True

        if self.debug:
            print(f"[GOLD_BAR] 획득! 판매가: {self.sell_price}골드")

        return True

    def deactivate(self):
        """금괴 제거 (판매 또는 게임 종료)"""
        self.active = False

        if self.debug:
            print("[GOLD_BAR] 제거됨")

    def update(self, current_stage=None):
        """상태 업데이트 (패시브 아이템이므로 특별한 업데이트 없음)"""
        pass

    def draw_effects(self, screen, **kwargs):
        """시각 효과 그리기 (패시브 아이템이므로 특별한 효과 없음)"""
        pass

    def get_sell_price(self):
        """판매 가격 반환"""
        return self.sell_price if self.active else 0

    def get_speed_multiplier(self):
        """이동속도 배율 반환 (소지 중이면 -30%)"""
        if self.active:
            return 1.0 - GOLD_BAR_SPEED_PENALTY
        return 1.0

    def is_active(self):
        """소지 중인지 여부"""
        return self.active


# 싱글톤 인스턴스
gold_bar_instance = None


def get_gold_bar_instance():
    global gold_bar_instance
    if gold_bar_instance is None:
        gold_bar_instance = GoldBar()
    return gold_bar_instance


def activate_gold_bar(game_state=None, current_stage=None, width=600, height=750):
    """금괴 획득"""
    bar = get_gold_bar_instance()
    return bar.activate(game_state, current_stage, width, height)


def deactivate_gold_bar():
    """금괴 제거"""
    bar = get_gold_bar_instance()
    bar.deactivate()


def update_gold_bar(current_stage=None):
    """금괴 업데이트"""
    bar = get_gold_bar_instance()
    bar.update(current_stage)


def draw_gold_bar_effects(screen, **kwargs):
    """금괴 효과 그리기"""
    bar = get_gold_bar_instance()
    bar.draw_effects(screen, **kwargs)


def get_gold_bar_sell_price():
    """금괴 판매 가격 반환"""
    bar = get_gold_bar_instance()
    return bar.get_sell_price()


def get_gold_bar_speed_multiplier():
    """금괴로 인한 이동속도 배율 반환 (소지 시 0.7)"""
    bar = get_gold_bar_instance()
    return bar.get_speed_multiplier()


def is_gold_bar_active():
    """금괴 소지 중인지 여부"""
    bar = get_gold_bar_instance()
    return bar.is_active()


def reset_gold_bar():
    """금괴 상태 완전 초기화 (게임 종료/사망 시)"""
    global gold_bar_instance
    if gold_bar_instance:
        gold_bar_instance.deactivate()
    gold_bar_instance = None
