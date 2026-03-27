"""
기묘한 약병 (Strange Vial) - 액티브 아이템
50% 확률로 거대화(패들 200% + 이속 -60%) 또는 축소(패들 -50% + 이속 +200%)
지속시간: 30초 (1800 프레임 @ 60fps)
"""
import random

# 상수
STRANGE_VIAL_DURATION_FRAMES = 1800  # 30초
STRANGE_VIAL_ENLARGE_PADDLE_MULT = 2.0   # 패들 200% (2배)
STRANGE_VIAL_ENLARGE_SPEED_MULT = 0.4    # 이속 -60% (40%만 적용)
STRANGE_VIAL_SHRINK_PADDLE_MULT = 0.5    # 패들 -50% (50%만 적용)
STRANGE_VIAL_SHRINK_SPEED_MULT = 3.0     # 이속 +200% (3배)

# 싱글톤 인스턴스
strange_vial_instance = None


class StrangeVial:
    def __init__(self):
        self.active = False
        self.timer = 0
        self.initial_timer = 0
        self.effect_type = None  # "enlarge" 또는 "shrink"
        self.paddle_multiplier = 1.0
        self.speed_multiplier = 1.0
        # 원본 값 백업
        self._original_paddle_width = None
        self._original_player_speed = None

    def activate(self, game_state=None, current_stage=None):
        """기묘한 약병 효과 발동 - 50% 확률로 거대화 또는 축소"""
        frames = STRANGE_VIAL_DURATION_FRAMES

        # 카페인 스킬 보너스 (아카데미)
        try:
            import academy
            caffeine_multiplier = academy.get_caffeine_duration_multiplier()
            frames = int(frames * caffeine_multiplier)
        except (ImportError, AttributeError):
            pass

        # 런타임 스킬 보너스
        try:
            import pingfighter
            runtime_level = pingfighter.runtime_skill_levels.get("item_caffeine", 0)
            if runtime_level > 0:
                runtime_bonus = runtime_level * 0.25
                frames = int(frames * (1 + runtime_bonus))
        except (ImportError, AttributeError):
            pass

        self.active = True
        self.timer = frames
        self.initial_timer = frames

        # 50% 확률로 효과 결정
        if random.random() < 0.5:
            self.effect_type = "enlarge"
            self.paddle_multiplier = STRANGE_VIAL_ENLARGE_PADDLE_MULT
            self.speed_multiplier = STRANGE_VIAL_ENLARGE_SPEED_MULT
        else:
            self.effect_type = "shrink"
            self.paddle_multiplier = STRANGE_VIAL_SHRINK_PADDLE_MULT
            self.speed_multiplier = STRANGE_VIAL_SHRINK_SPEED_MULT

    def deactivate(self):
        """효과 해제 및 원본 값 복원"""
        self.active = False
        self.timer = 0
        self.initial_timer = 0
        self.effect_type = None
        self.paddle_multiplier = 1.0
        self.speed_multiplier = 1.0
        self._original_paddle_width = None
        self._original_player_speed = None

    def update(self, current_stage=None):
        """매 프레임 업데이트"""
        if not self.active:
            return
        self.timer -= 1
        if self.timer <= 0:
            self.deactivate()

    def get_remaining_ratio(self):
        """타이머 게이지 비율 (0.0 ~ 1.0)"""
        if not self.active or self.initial_timer <= 0:
            return 0.0
        return self.timer / self.initial_timer

    def get_paddle_multiplier(self):
        """현재 패들 크기 배율"""
        if not self.active:
            return 1.0
        return self.paddle_multiplier

    def get_speed_multiplier(self):
        """현재 이동속도 배율"""
        if not self.active:
            return 1.0
        return self.speed_multiplier

    def is_enlarge(self):
        """거대화 효과 여부"""
        return self.active and self.effect_type == "enlarge"

    def is_shrink(self):
        """축소 효과 여부"""
        return self.active and self.effect_type == "shrink"


def get_strange_vial_instance():
    """싱글톤 인스턴스 반환"""
    global strange_vial_instance
    if strange_vial_instance is None:
        strange_vial_instance = StrangeVial()
    return strange_vial_instance


def activate_strange_vial(game_state=None, current_stage=None):
    """기묘한 약병 효과 활성화"""
    vial = get_strange_vial_instance()
    vial.activate(game_state, current_stage)
    return True


def deactivate_strange_vial():
    """기묘한 약병 효과 비활성화"""
    vial = get_strange_vial_instance()
    vial.deactivate()


def update_strange_vial(current_stage=None):
    """기묘한 약병 업데이트"""
    vial = get_strange_vial_instance()
    vial.update(current_stage)
