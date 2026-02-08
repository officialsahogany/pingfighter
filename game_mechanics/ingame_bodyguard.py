"""인게임 호위무사 시스템

투기장에서 우승 후 등용한 영웅이 다음 스테이지에서 일정 시간마다
화면 옆에서 등장하여 보스를 공격하는 시스템.

투기장 호위무사(GuardWarriorSystem)를 내부적으로 재사용하여
동일한 UI, 스킬 이펙트, 위치를 보장한다.
"""
import random
import os

try:
    import pygame
    import pygame.freetype
except ImportError:
    pygame = None


# ============================================================================
# 상수
# ============================================================================
GAME_AREA_X = 80           # 게임 영역 시작 X
GAME_AREA_WIDTH = 600      # 게임 영역 너비
SCREEN_WIDTH = 760         # 전체 내부 해상도 너비
SCREEN_HEIGHT = 750        # 전체 내부 해상도 높이

# 영웅별 한국어 이름 및 스킬명
HERO_DISPLAY_INFO = {
    "mugen":    {"name": "무겐",    "skill": "달빛베기",     "color": (120, 60, 180)},
    "kraken":   {"name": "크라켄",  "skill": "촉수휘감기",   "color": (40, 120, 140)},
    "chronos":  {"name": "크로노스","skill": "중력제어",     "color": (200, 170, 100)},
    "onimaru":  {"name": "오니마루","skill": "지옥의 불꽃",  "color": (200, 50, 70)},
    "maria":    {"name": "연화",    "skill": "인형조종",     "color": (180, 100, 150)},
    "ignis":    {"name": "이그니스","skill": "드래곤 브레스", "color": (220, 100, 40)},
    "gear":     {"name": "기어",    "skill": "스팀배리어",   "color": (140, 100, 60)},
    "kurokage": {"name": "쿠로카게","skill": "그림자분신",   "color": (50, 50, 70)},
}


class _MinimalSkillManager:
    """GuardWarriorSystem이 요구하는 최소한의 skill_manager 인터페이스"""
    def __init__(self):
        self.game_state = {}
        self.screen_effects = []


class _PaddleProxy:
    """pygame.Rect를 패들 객체처럼 래핑"""
    def __init__(self, rect, is_top):
        self.x = rect.x
        self.y = rect.y
        self.width = rect.width
        self.height = rect.height
        self.centerx = rect.centerx
        self.centery = rect.centery
        self.is_top = is_top
        self.paddle_scale = 1.0


class _BallProxy:
    """공 Rect + 속도를 래핑"""
    def __init__(self, rect, vx=0, vy=0):
        self.x = rect.x
        self.y = rect.y
        self.width = rect.width
        self.height = rect.height
        self.centerx = rect.centerx
        self.centery = rect.centery
        self.vx = vx
        self.vy = vy


# ============================================================================
# 인게임 호위무사 클래스
# ============================================================================
class InGameBodyguard:
    """스테이지 진행 중 플레이어를 돕는 호위무사 시스템

    투기장 GuardWarriorSystem을 내부적으로 재사용하여 동일한 스킬/UI 제공.
    """

    def __init__(self):
        self.hero_data = None
        self.active = False
        self._guard_system = None   # GuardWarriorSystem 인스턴스
        self._skill_manager = None  # 최소 skill_manager
        self._hero_paddle_renderer = None

    def setup(self, hero_data: dict):
        """호위무사 설정 (투기장 우승 후 등용된 영웅)"""
        self.hero_data = hero_data
        self.active = True

        # 패들 렌더러 초기화
        try:
            from downtown.hero_paddles import get_hero_paddle_renderer
            self._hero_paddle_renderer = get_hero_paddle_renderer()
        except Exception:
            self._hero_paddle_renderer = None

        # 최소 skill_manager 생성
        self._skill_manager = _MinimalSkillManager()

        # GuardWarriorSystem 생성 및 설정
        try:
            from downtown.colosseum_arena import GuardWarriorSystem
            self._guard_system = GuardWarriorSystem(
                skill_manager=self._skill_manager,
                hero_paddle_renderer=self._hero_paddle_renderer,
            )
            # 플레이어 측(하단) 호위무사로 설정
            self._guard_system.setup(
                guards_top=[],                # 상단(보스 측)은 없음
                guards_bottom=[hero_data],    # 하단(플레이어 측)에 배치
                initial_delay=(12.0, 18.0),
            )
            print(f"[Bodyguard] 호위무사 설정 완료 (GuardWarriorSystem): "
                  f"{hero_data.get('name', '???')} (id={hero_data.get('id')})")
        except Exception as e:
            print(f"[Bodyguard] GuardWarriorSystem 생성 실패: {e}")
            import traceback
            traceback.print_exc()
            self._guard_system = None

    def reset(self):
        """호위무사 시스템 리셋"""
        if self._guard_system:
            self._guard_system.reset()
        self.hero_data = None
        self.active = False
        self._guard_system = None
        self._skill_manager = None

    def update(self, dt: float, boss_rect=None, player_rect=None,
               ball_rect=None, ball_vx=0, ball_vy=0) -> dict:
        """매 프레임 업데이트

        Args:
            dt: 델타 타임 (초)
            boss_rect: 보스 pygame.Rect (상단)
            player_rect: 플레이어 pygame.Rect (하단)
            ball_rect: 공 pygame.Rect
            ball_vx, ball_vy: 공 속도
        """
        if not self.active or not self._guard_system:
            return {}

        # Rect → 프록시 패들/공 변환
        top_paddle = _PaddleProxy(boss_rect, is_top=True) if boss_rect else None
        bottom_paddle = _PaddleProxy(player_rect, is_top=False) if player_rect else None
        ball = _BallProxy(ball_rect, ball_vx, ball_vy) if ball_rect else None

        # 가짜 패들 폴백 (None 방지)
        if top_paddle is None:
            top_paddle = _PaddleProxy(pygame.Rect(380, 25, 120, 40), is_top=True)
        if bottom_paddle is None:
            bottom_paddle = _PaddleProxy(pygame.Rect(380, 710, 120, 40), is_top=False)

        self._guard_system.update(dt, top_paddle, bottom_paddle, ball)
        return {}

    def draw(self, screen, boss_rect=None, player_rect=None, ball_rect=None):
        """호위무사 캐릭터 및 스킬 이펙트 그리기"""
        if not self.active or not self._guard_system:
            return

        # Rect → 프록시 변환
        top_paddle = _PaddleProxy(boss_rect, is_top=True) if boss_rect else None
        bottom_paddle = _PaddleProxy(player_rect, is_top=False) if player_rect else None
        ball = _BallProxy(ball_rect) if ball_rect else None

        if top_paddle is None:
            top_paddle = _PaddleProxy(pygame.Rect(380, 25, 120, 40), is_top=True)
        if bottom_paddle is None:
            bottom_paddle = _PaddleProxy(pygame.Rect(380, 710, 120, 40), is_top=False)

        self._guard_system.draw(
            screen,
            top_paddle=top_paddle,
            bottom_paddle=bottom_paddle,
            ball=ball,
        )

    def draw_pillar_icon(self, screen, game_offset_x=0, game_offset_y=0,
                         game_scale=1.0):
        """필러에 호위무사 UI 아이콘 표시 (투기장과 동일한 스타일/위치)"""
        if not self.active or not self._guard_system:
            return

        self._guard_system.draw_guard_icons(
            screen,
            game_offset_x=game_offset_x,
            game_offset_y=game_offset_y,
            game_scale=game_scale,
        )

    def reset_active_skills(self):
        """득점 시 호위무사 활성 스킬 리셋"""
        if self._guard_system:
            self._guard_system.reset_active_skills()


# ============================================================================
# 싱글턴 인스턴스
# ============================================================================
_bodyguard_instance = None


def get_bodyguard() -> InGameBodyguard:
    """인게임 호위무사 싱글턴 인스턴스"""
    global _bodyguard_instance
    if _bodyguard_instance is None:
        _bodyguard_instance = InGameBodyguard()
    return _bodyguard_instance
