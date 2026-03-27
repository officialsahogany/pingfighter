"""
소울버스트 (Soul Burst) - 무릎 부위 패시브 아이템
대쉬 토큰이 없을 때 (게이지 < 1) 대쉬 사용 시 스페셜 게이지를 대신 소모하여 풀 대쉬 발동.
스페셜 게이지 소모량은 롤 옵션으로 130~200 범위에서 결정됨.
"""

# 디버그 플래그
DEBUG_SOUL_BURST = False


class SoulBurst:
    def __init__(self):
        self.active = False
        self.obtained = False
        self.gauge_cost = 165  # 기본값 (롤옵션으로 130~200 사이 결정)

    def activate(self):
        """아이템 획득 시 활성화"""
        self.active = True
        self.obtained = True
        if DEBUG_SOUL_BURST:
            print(f"[SOUL_BURST] 활성화! 게이지 소모량: {self.gauge_cost}")

    def deactivate(self):
        """게임 종료/리셋 시 비활성화"""
        self.active = False
        self.obtained = False
        self.gauge_cost = 165

    def set_gauge_cost(self, cost):
        """롤 옵션에서 결정된 게이지 소모량 설정"""
        self.gauge_cost = cost
        if DEBUG_SOUL_BURST:
            print(f"[SOUL_BURST] 게이지 소모량 설정: {cost}")

    def can_soul_dash(self, special_gauge):
        """스페셜 게이지로 대쉬할 수 있는지 확인"""
        if not self.active:
            return False
        return special_gauge >= self.gauge_cost

    def get_gauge_cost(self):
        """현재 게이지 소모량 반환"""
        return self.gauge_cost

    def get_available_dashes(self, special_gauge):
        """현재 스페셜 게이지로 가능한 추가 대쉬 횟수"""
        if not self.active or self.gauge_cost <= 0:
            return 0
        return int(special_gauge // self.gauge_cost)

    def update(self, current_stage=None):
        pass

    def draw_effects(self, screen, **kwargs):
        pass


# 싱글턴 인스턴스
_soul_burst_instance = None


def get_soul_burst_instance():
    global _soul_burst_instance
    if _soul_burst_instance is None:
        _soul_burst_instance = SoulBurst()
    return _soul_burst_instance


def activate_soul_burst():
    sb = get_soul_burst_instance()
    sb.activate()
    return True


def deactivate_soul_burst():
    sb = get_soul_burst_instance()
    sb.deactivate()
