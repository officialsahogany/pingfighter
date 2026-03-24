"""
럭키코인 아이템 효과
아이템 스폰 시 5~15% 확률로 아이템이 2개 동시에 나타나는 패시브 아이템
장신구 부위 장착
"""

import os

# 디버그 모드
DEBUG_LUCKY_COIN = os.environ.get("DEBUG_LUCKY_COIN", "0") == "1"

# 상수
LUCKY_COIN_MIN_CHANCE = 5   # 최소 5% 확률
LUCKY_COIN_MAX_CHANCE = 15  # 최대 15% 확률


class LuckyCoin:
    def __init__(self):
        self.active = False
        self.double_spawn_chance = 0.10  # 기본 10% (롤 옵션으로 5~15% 결정)
        self.debug = DEBUG_LUCKY_COIN

    def activate(self, game_state=None, current_stage=None, width=600, height=750):
        """럭키코인 획득 및 활성화"""
        self.active = True
        if self.debug:
            print(f"[LUCKY_COIN] 활성화! 더블 스폰 확률: {self.double_spawn_chance * 100:.1f}%")
        return True

    def deactivate(self):
        """럭키코인 비활성화 (게임 종료 시)"""
        self.active = False
        self.double_spawn_chance = 0.10
        if self.debug:
            print("[LUCKY_COIN] 비활성화")

    def set_chance(self, chance_pct):
        """더블 스폰 확률 설정 (퍼센트 값)"""
        self.double_spawn_chance = chance_pct / 100.0
        if self.debug:
            print(f"[LUCKY_COIN] 더블 스폰 확률 설정: {chance_pct}%")

    def get_double_spawn_chance(self):
        """더블 스폰 확률 반환 (0.0 ~ 1.0)"""
        if not self.active:
            return 0.0
        return self.double_spawn_chance

    def update(self, current_stage=None):
        """상태 업데이트 (패시브 아이템이므로 특별한 업데이트 없음)"""
        pass

    def draw_effects(self, screen, **kwargs):
        """시각 효과 그리기 (패시브 아이템이므로 특별한 효과 없음)"""
        pass


# 싱글톤 인스턴스
lucky_coin_instance = None


def get_lucky_coin_instance():
    global lucky_coin_instance
    if lucky_coin_instance is None:
        lucky_coin_instance = LuckyCoin()
    return lucky_coin_instance


def activate_lucky_coin(game_state=None, current_stage=None):
    coin = get_lucky_coin_instance()
    return coin.activate(game_state, current_stage)


def deactivate_lucky_coin():
    coin = get_lucky_coin_instance()
    coin.deactivate()


def reset_lucky_coin():
    """럭키코인 완전 초기화 (게임 리셋 시)"""
    coin = get_lucky_coin_instance()
    coin.deactivate()


def get_double_spawn_chance():
    """현재 더블 스폰 확률 반환 (0.0 ~ 1.0)"""
    coin = get_lucky_coin_instance()
    return coin.get_double_spawn_chance()


def should_double_spawn():
    """더블 스폰 여부 판정 (True/False)"""
    import random
    chance = get_double_spawn_chance()
    if chance <= 0:
        return False
    return random.random() < chance
