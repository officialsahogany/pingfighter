# downtown/colosseum_arena.py
# 고대 투기장 토너먼트 시스템

import pygame
import random
import math
import sys
import os
from enum import Enum
from typing import List, Dict, Optional, Tuple

# 영웅 스킬 시스템 임포트
try:
    from downtown.hero_skills import (
        get_skill_manager, HeroSkillManager, SkillTrigger,
        HERO_SKILLS, get_hero_skills
    )
    HERO_SKILLS_AVAILABLE = True
except ImportError:
    try:
        from hero_skills import (
            get_skill_manager, HeroSkillManager, SkillTrigger,
            HERO_SKILLS, get_hero_skills
        )
        HERO_SKILLS_AVAILABLE = True
    except ImportError:
        HERO_SKILLS_AVAILABLE = False
        print("Hero skills module not available")

# 상수 (실제 게임과 동일)
SCREEN_WIDTH = 760
SCREEN_HEIGHT = 750
GAME_AREA_X = 80
GAME_AREA_WIDTH = 600
PADDLE_WIDTH = 80
PADDLE_HEIGHT = 12
BALL_SIZE = 10
WIN_SCORE = 5  # 5점 선취 승리

# 물리 상수 (실제 게임과 동일)
BALL_BASE_SPEED = 7.0       # 기본 공 속도
BALL_MAX_SPEED = 15.0       # 최대 공 속도
BALL_ACCELERATION = 1.03    # 충돌 시 가속률
PADDLE_HIT_ANGLE_FACTOR = 4.0  # 패들 타격 시 각도 변화 계수
WALL_BOUNCE_SLOWDOWN = 0.98  # 벽 반사 시 속도 감소

# 패들 위치 (실제 게임과 동일)
TOP_PADDLE_Y = 25           # 상단 패들 Y (보스 위치)
BOTTOM_PADDLE_Y = 720       # 하단 패들 Y (플레이어 위치)

# 배경/필러 임포트 (선택적)
try:
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from backgrounds.animated_background_stage30 import AnimatedBackgroundStage30
    from pillar_colosseum import ColosseumFrame
    VISUAL_ASSETS_AVAILABLE = True
except ImportError:
    VISUAL_ASSETS_AVAILABLE = False

# 영웅 패들 렌더러 임포트
try:
    from downtown.hero_paddles import get_hero_paddle_renderer
    HERO_PADDLES_AVAILABLE = True
except ImportError:
    try:
        from hero_paddles import get_hero_paddle_renderer
        HERO_PADDLES_AVAILABLE = True
    except ImportError:
        HERO_PADDLES_AVAILABLE = False

# 날씨 이벤트 임포트 (용의 날개 강풍 이펙트용)
try:
    from events import weather_event as weather_module
    WEATHER_EVENT_AVAILABLE = True
except ImportError:
    WEATHER_EVENT_AVAILABLE = False
    weather_module = None

# ============================================================================
# 영웅 데이터
# ============================================================================
class HeroStyle(Enum):
    AGGRESSIVE = "aggressive"  # 공격적 - 빠른 반응, 강한 스매시
    DEFENSIVE = "defensive"    # 수비적 - 안정적 수비, 느린 공격
    BALANCED = "balanced"      # 균형형 - 평균적인 능력치
    TRICKY = "tricky"          # 트릭형 - 예측 불가, 변칙 플레이

# 상단 패들 영웅 (hero1 - 화면 위쪽)
TOP_HEROES = [
    {
        "id": "mugen",
        "name": "무겐",
        "title": "귀검사",
        "style": HeroStyle.AGGRESSIVE,
        "color": (120, 60, 180),  # 보라색
        "speed": 1.3,
        "reaction": 0.85,
        "power": 1.25,
        "accuracy": 0.78,
        "position": "top",
        "description": "어둠의 검기를 다루는 동양의 귀검객"
    },
    {
        "id": "kraken",
        "name": "크라켄",
        "title": "심해의 포식자",
        "style": HeroStyle.TRICKY,
        "color": (40, 120, 140),  # 어두운 청록색
        "speed": 0.95,
        "reaction": 1.1,
        "power": 1.15,
        "accuracy": 0.82,
        "position": "top",
        "description": "심해에서 온 촉수 괴물 하이브리드"
    },
    {
        "id": "chronos",
        "name": "크로노스",
        "title": "시간술사",
        "style": HeroStyle.DEFENSIVE,
        "color": (200, 170, 100),  # 황금색
        "speed": 0.85,
        "reaction": 1.35,
        "power": 0.75,
        "accuracy": 0.98,
        "position": "top",
        "description": "시간을 조종하여 모든 공격을 예측하는 자"
    },
    {
        "id": "onimaru",
        "name": "오니마루",
        "title": "지옥의 요괴무사",
        "style": HeroStyle.AGGRESSIVE,
        "color": (200, 50, 70),  # 진한 빨강
        "speed": 1.2,
        "reaction": 0.9,
        "power": 1.35,
        "accuracy": 0.72,
        "position": "top",
        "description": "지옥에서 온 뿔 달린 도깨비 전사"
    },
]

# 하단 패들 영웅 (hero2 - 화면 아래쪽)
BOTTOM_HEROES = [
    {
        "id": "maria",
        "name": "마리아",
        "title": "인형사",
        "style": HeroStyle.TRICKY,
        "color": (180, 100, 150),  # 분홍-보라
        "speed": 1.0,
        "reaction": 1.0,
        "power": 1.1,
        "accuracy": 0.85,
        "position": "bottom",
        "description": "마리오네트를 조종하는 기묘한 소녀"
    },
    {
        "id": "ignis",
        "name": "이그니스",
        "title": "드래곤 나이트",
        "style": HeroStyle.BALANCED,
        "color": (220, 100, 40),  # 주황-빨강
        "speed": 1.1,
        "reaction": 1.05,
        "power": 1.2,
        "accuracy": 0.88,
        "position": "bottom",
        "description": "드래곤의 힘을 갑옷에 담은 용기사"
    },
    {
        "id": "gear",
        "name": "기어",
        "title": "스팀펑크 메카닉",
        "style": HeroStyle.DEFENSIVE,
        "color": (140, 100, 60),  # 구리색
        "speed": 0.9,
        "reaction": 1.25,
        "power": 0.95,
        "accuracy": 0.95,
        "position": "bottom",
        "description": "증기 기관과 톱니바퀴로 무장한 발명가"
    },
    {
        "id": "kurokage",
        "name": "쿠로카게",
        "title": "그림자 닌자",
        "style": HeroStyle.AGGRESSIVE,
        "color": (50, 50, 70),  # 어두운 남색
        "speed": 1.4,
        "reaction": 0.85,
        "power": 1.0,
        "accuracy": 0.8,
        "position": "bottom",
        "description": "어둠 속에서 나타나는 닌자 암살자"
    },
]

# 전체 영웅 목록 (호환성용)
ARENA_HEROES = TOP_HEROES + BOTTOM_HEROES

# ============================================================================
# 토너먼트 상태
# ============================================================================
class TournamentState(Enum):
    BRACKET_VIEW = "bracket_view"      # 대진표 보기
    SELECT_MATCH = "select_match"      # 경기 선택
    BETTING = "betting"                # 배팅
    BATTLE = "battle"                  # AI 배틀 진행
    RESULT = "result"                  # 경기 결과
    ROUND_END = "round_end"            # 라운드 종료 (계속/나가기 선택)
    TOURNAMENT_END = "tournament_end"  # 토너먼트 종료

class TournamentRound(Enum):
    QUARTER_FINAL = "8강"
    SEMI_FINAL = "4강"
    FINAL = "결승"

# ============================================================================
# 토너먼트 매치
# ============================================================================
class Match:
    def __init__(self, hero1: Dict, hero2: Dict, match_id: int):
        self.hero1 = hero1
        self.hero2 = hero2
        self.match_id = match_id
        self.winner: Optional[Dict] = None
        self.score1 = 0
        self.score2 = 0
        self.completed = False

    def set_result(self, winner: Dict, score1: int, score2: int):
        self.winner = winner
        self.score1 = score1
        self.score2 = score2
        self.completed = True

# ============================================================================
# AI 패들 컨트롤러 (실제 보스 AI 수준)
# ============================================================================
class AIPaddleController:
    """실제 게임의 보스 AI와 동일한 수준의 AI 컨트롤러"""

    def __init__(self, hero: Dict, is_top: bool):
        self.hero = hero
        self.is_top = is_top
        self.x = GAME_AREA_X + GAME_AREA_WIDTH // 2 - PADDLE_WIDTH // 2
        self.y = TOP_PADDLE_Y if is_top else BOTTOM_PADDLE_Y
        self.target_x = self.x
        self.velocity = 0.0
        self.visual_width = PADDLE_WIDTH  # 시각적 패들 너비 (스킬 효과용)

        # 영웅 스탯 기반 능력치
        self.base_speed = 7.0 * hero["speed"]
        self.max_speed = 10.0 * hero["speed"]
        self.reaction_time = 0.08 / hero["reaction"]  # 반응 시간 (초)
        self.prediction_accuracy = hero["accuracy"]  # 예측 정확도
        self.power = hero["power"]

        # AI 상태
        self.style = hero["style"]
        self.reaction_timer = 0.0
        self.predicted_x = self.x + PADDLE_WIDTH // 2
        self.last_prediction_time = 0.0

        # 움직임 스무딩
        self.smoothing = 0.15
        self.idle_return_speed = 0.02

        # 실수 시스템 (정확도에 따라)
        self.error_offset = 0
        self.error_update_timer = 0

        # 스킬 상태 효과
        self.is_stunned = False
        self.slow_multiplier = 1.0
        self.is_confused = False  # 조작 반전
        self.paddle_scale = 1.0   # 패들 크기 배율
        self.is_locked = False    # 스킬에 의해 위치 고정
        self.original_y = self.y  # Y축 이동 시 원래 위치 저장

        # 대쉬 시스템 (보스 대쉬와 동일한 물리 엔진)
        self.dash_active = False
        self.dash_direction = 0  # -1: 왼쪽, 1: 오른쪽
        self.dash_timer = 0  # 대쉬 지속 시간
        self.dash_duration = 25  # 대쉬 총 지속 프레임 (보스와 동일)
        self.dash_high_phase = 15  # 고속 구간 프레임
        self.dash_cooldown_ms = 0  # 대쉬 쿨다운 (ms)
        self.dash_cooldown_min_ms = 4000  # 최소 쿨다운 4초 (신화리그 수준)
        self.dash_cooldown_max_ms = 6000  # 최대 쿨다운 6초
        self.dash_speed = 40.0  # 대쉬 속도 (보스와 동일)
        self.dash_target_x = 0.0  # 대쉬 목표 X
        self.dash_stun_timer = 0  # 대쉬 후딜
        self.dash_stun_duration = 18  # 대쉬 후딜 프레임 (0.3초)
        self.dash_afterimages = []  # 대쉬 잔상 효과 (이미지 기반)
        self.dash_delay_sound_playing = False  # 후딜 사운드 재생 중

        # AI 대쉬 판단용
        self.last_ball_x = GAME_AREA_X + GAME_AREA_WIDTH // 2
        self.emergency_dash_threshold = 120  # 긴급 대쉬 발동 거리

    def _predict_x_with_walls(self, ball_x: float, ball_vx: float, ball_y: float,
                               ball_vy: float, target_y: float) -> float:
        """벽 반사를 고려한 도착 X 좌표 예측 (실제 보스 AI와 동일)"""
        if abs(ball_vy) < 0.1:
            return ball_x

        # 도착까지 걸리는 시간
        time_to_target = abs(target_y - ball_y) / abs(ball_vy)

        # X 이동량 계산
        total_dx = ball_vx * time_to_target
        predicted_x = ball_x + total_dx

        # 벽 반사 시뮬레이션
        left_wall = GAME_AREA_X + BALL_SIZE
        right_wall = GAME_AREA_X + GAME_AREA_WIDTH - BALL_SIZE

        # 반사 횟수 제한 (최대 10회)
        for _ in range(10):
            if predicted_x < left_wall:
                predicted_x = 2 * left_wall - predicted_x
            elif predicted_x > right_wall:
                predicted_x = 2 * right_wall - predicted_x
            else:
                break

        return predicted_x

    def update(self, ball_x: float, ball_y: float, ball_vx: float, ball_vy: float, dt: float):
        """AI 패들 업데이트 (실제 보스 AI 수준)"""
        # 대쉬 상태 업데이트 (항상 먼저)
        self.update_dash(dt)

        # 스킬에 의해 고정된 상태면 X축 이동 안함 (Y축은 스킬에서 직접 제어)
        if self.is_locked:
            return

        # 스턴 상태면 움직이지 않음
        if self.is_stunned:
            return

        # 대쉬 중이거나 대쉬 후딜 중이면 일반 이동 안함
        if self.dash_active or self.dash_stun_timer > 0:
            return

        # AI 긴급 대쉬 시도
        self.ai_try_emergency_dash(ball_x, ball_y, ball_vx, ball_vy)

        # 공이 자기 방향으로 오는지 확인
        coming_towards = (ball_vy < 0 and self.is_top) or (ball_vy > 0 and not self.is_top)

        # 반응 타이머 업데이트
        self.reaction_timer += dt
        self.error_update_timer += dt

        # 실수 오프셋 주기적 업데이트
        if self.error_update_timer > 0.5:
            self.error_update_timer = 0
            # 정확도에 따른 실수 범위
            error_range = int(30 * (1 - self.prediction_accuracy))
            self.error_offset = random.randint(-error_range, error_range)

        if coming_towards and self.reaction_timer >= self.reaction_time:
            # 목표 위치 예측
            self.predicted_x = self._predict_x_with_walls(
                ball_x, ball_vx, ball_y, ball_vy, self.y
            )

            # 스타일에 따른 목표 위치 조정
            if self.style == HeroStyle.AGGRESSIVE:
                # 공격적: 공이 빠를 때 더 과감하게 이동, 끝쪽 타격 선호
                speed_factor = math.hypot(ball_vx, ball_vy) / 10.0
                offset = (0.5 - random.random()) * 30 * speed_factor
                self.target_x = self.predicted_x + offset + self.error_offset
            elif self.style == HeroStyle.DEFENSIVE:
                # 수비적: 정확한 중앙 타격
                self.target_x = self.predicted_x + self.error_offset * 0.5
            elif self.style == HeroStyle.TRICKY:
                # 트릭: 예측 불가능한 움직임
                if random.random() < 0.3:
                    offset = random.randint(-40, 40)
                else:
                    offset = 0
                self.target_x = self.predicted_x + offset + self.error_offset
            else:
                # 균형: 약간의 변동
                self.target_x = self.predicted_x + self.error_offset * 0.7
        else:
            # 공이 멀어질 때 중앙으로 서서히 복귀
            center = GAME_AREA_X + GAME_AREA_WIDTH // 2
            self.target_x = self.target_x * (1 - self.idle_return_speed) + center * self.idle_return_speed
            self.reaction_timer = 0  # 반응 타이머 리셋

        # 패들 중심 기준으로 목표 설정
        target_center = self.target_x
        current_center = self.x + PADDLE_WIDTH // 2

        # 혼란 상태면 방향 반전
        diff = target_center - current_center
        if self.is_confused:
            diff = -diff

        # 속도 계산 (스무딩 적용)
        target_velocity = diff * self.smoothing * 60  # 60fps 기준

        # 둔화 적용
        target_velocity *= self.slow_multiplier

        # 속도 제한
        max_spd = self.max_speed * self.slow_multiplier
        target_velocity = max(-max_spd, min(max_spd, target_velocity))

        # 가속도 적용
        accel = 0.3 * self.slow_multiplier
        if abs(target_velocity - self.velocity) > accel:
            if target_velocity > self.velocity:
                self.velocity += accel
            else:
                self.velocity -= accel
        else:
            self.velocity = target_velocity

        # 위치 업데이트
        self.x += self.velocity

        # 경계 체크
        self.x = max(GAME_AREA_X, min(self.x, GAME_AREA_X + GAME_AREA_WIDTH - PADDLE_WIDTH))

    def get_rect(self) -> pygame.Rect:
        # paddle_scale 적용하여 축소 시 충돌 판정도 줄어들게
        scaled_width = int(PADDLE_WIDTH * self.paddle_scale)
        # 중심 기준으로 축소 (좌우 대칭)
        x_offset = (PADDLE_WIDTH - scaled_width) // 2
        return pygame.Rect(int(self.x) + x_offset, int(self.y), scaled_width, PADDLE_HEIGHT)

    def get_center_x(self) -> float:
        return self.x + PADDLE_WIDTH // 2

    def try_dash(self, target_x: float) -> bool:
        """대쉬 시도, 성공 시 True 반환 (보스 대쉬와 동일한 로직)"""
        now_ms = pygame.time.get_ticks()

        # 대쉬 불가능 상태 체크
        if self.dash_active or self.dash_stun_timer > 0 or self.is_stunned:
            return False

        # 쿨다운 체크
        if self.dash_cooldown_ms > 0 and now_ms < self.dash_cooldown_ms:
            return False

        # 대쉬 방향 결정
        paddle_center = self.x + PADDLE_WIDTH // 2
        direction = 1 if target_x > paddle_center else -1
        dash_distance = abs(target_x - paddle_center)

        # 최소 거리 체크
        if dash_distance < 30:
            return False

        # 대쉬 활성화
        self.dash_active = True
        self.dash_direction = direction
        self.dash_target_x = max(GAME_AREA_X + PADDLE_WIDTH // 2,
                                  min(GAME_AREA_X + GAME_AREA_WIDTH - PADDLE_WIDTH // 2, target_x))
        self.dash_timer = self.dash_duration

        # 🔊 대쉬 사운드 재생
        try:
            import pingfighter
            if hasattr(pingfighter, 'play_dash_sound'):
                pingfighter.play_dash_sound()
        except Exception:
            pass

        # 쿨다운 설정 (신화리그 수준: 4~6초)
        cooldown_ms = random.randint(self.dash_cooldown_min_ms, self.dash_cooldown_max_ms)
        self.dash_cooldown_ms = now_ms + cooldown_ms

        return True

    def update_dash(self, dt: float):
        """대쉬 상태 업데이트 (보스 대쉬와 동일한 물리 엔진)"""
        now_ms = pygame.time.get_ticks()

        # 잔상 효과 업데이트 (항상)
        new_afterimages = []
        for after in self.dash_afterimages:
            after['alpha'] -= 25
            after['life'] -= 1
            if after['alpha'] > 0 and after['life'] > 0:
                new_afterimages.append(after)
        self.dash_afterimages = new_afterimages

        # 후딜 상태 처리
        if self.dash_stun_timer > 0:
            prev_stun = self.dash_stun_timer
            self.dash_stun_timer -= 1

            # 🔊 후딜 종료 시 사운드 중지
            if prev_stun > 0 and self.dash_stun_timer <= 0:
                if self.dash_delay_sound_playing:
                    try:
                        import pingfighter
                        if hasattr(pingfighter, 'stop_dash_delay_sound'):
                            pingfighter.stop_dash_delay_sound()
                    except Exception:
                        pass
                    self.dash_delay_sound_playing = False
            return

        if not self.dash_active:
            return

        # 대쉬 타이머 감소
        self.dash_timer -= 1

        # 🎮 대쉬 물리 엔진 (보스와 동일한 속도 곡선)
        # 고속 구간: dash_timer > high_phase_frames
        # 감속 구간: dash_timer <= high_phase_frames
        if self.dash_timer > self.dash_high_phase:
            move_step = self.dash_speed * self.dash_direction
        else:
            # 감속: 선형 감속
            decel_factor = max(0.0, self.dash_timer / float(self.dash_high_phase)) if self.dash_high_phase > 0 else 0.0
            move_step = self.dash_speed * self.dash_direction * decel_factor

        # 잔상 추가 (2프레임마다)
        if self.dash_timer % 2 == 0:
            self.dash_afterimages.append({
                'x': self.x + PADDLE_WIDTH // 2,
                'y': self.y + PADDLE_HEIGHT // 2,
                'alpha': 160,
                'life': 10,
                'color': self.hero["color"]
            })
            if len(self.dash_afterimages) > 6:
                self.dash_afterimages.pop(0)

        # 이동 적용
        self.x += move_step

        # 목표 도달 체크
        paddle_center = self.x + PADDLE_WIDTH // 2
        if self.dash_direction > 0 and paddle_center >= self.dash_target_x:
            self.x = self.dash_target_x - PADDLE_WIDTH // 2
        elif self.dash_direction < 0 and paddle_center <= self.dash_target_x:
            self.x = self.dash_target_x - PADDLE_WIDTH // 2

        # 경계 체크
        if self.x < GAME_AREA_X:
            self.x = GAME_AREA_X
            self._end_dash()
        elif self.x > GAME_AREA_X + GAME_AREA_WIDTH - PADDLE_WIDTH:
            self.x = GAME_AREA_X + GAME_AREA_WIDTH - PADDLE_WIDTH
            self._end_dash()

        # 대쉬 종료
        if self.dash_timer <= 0:
            self._end_dash()

    def _end_dash(self):
        """대쉬 종료 처리"""
        self.dash_active = False
        self.dash_stun_timer = self.dash_stun_duration

        # 🔊 대쉬 후딜 사운드 시작
        try:
            import pingfighter
            if hasattr(pingfighter, 'play_dash_delay_sound'):
                pingfighter.play_dash_delay_sound()
                self.dash_delay_sound_playing = True
        except Exception:
            pass

    def ai_try_emergency_dash(self, ball_x: float, ball_y: float, ball_vx: float, ball_vy: float) -> bool:
        """AI 긴급 대쉬 판단 (보스 AI와 동일한 로직)"""
        now_ms = pygame.time.get_ticks()

        # 대쉬 불가능 상태
        if self.dash_cooldown_ms > 0 and now_ms < self.dash_cooldown_ms:
            return False
        if self.dash_active or self.dash_stun_timer > 0 or self.is_stunned:
            return False

        # 공이 자기 방향으로 오는지 확인
        coming_towards = (ball_vy < 0 and self.is_top) or (ball_vy > 0 and not self.is_top)
        if not coming_towards:
            return False

        # 공까지의 Y 거리 계산
        y_distance = abs(ball_y - self.y)

        # 공이 너무 멀면 대쉬 불필요 (120px 이내)
        if y_distance > 120 or y_distance <= 0:
            return False

        # 도착 시간 계산 (프레임 단위)
        time_to_paddle = y_distance / max(1.0, abs(ball_vy))

        # 시간이 너무 많이 남으면 일반 이동으로 대응 가능
        if time_to_paddle > 20.0:
            return False

        # 벽 반사 고려한 예측 X 위치
        predicted_x = self._predict_x_with_walls(ball_x, ball_vx, ball_y, ball_vy, self.y)

        # 패들 중심과 예측 위치 간 거리
        paddle_center = self.x + PADDLE_WIDTH // 2
        required_distance = abs(predicted_x - paddle_center)

        # 일반 이동으로 커버 가능한 거리 계산
        max_travel = self.max_speed * time_to_paddle * 1.5  # 여유분 포함

        # 일반 이동으로 충분하면 대쉬 불필요
        if required_distance <= max_travel:
            return False

        # 긴급 대쉬 필요 - 스타일에 따른 확률
        dash_chance = 0.6  # 기본 60% 확률 (긴급 상황)
        if self.style == HeroStyle.AGGRESSIVE:
            dash_chance = 0.85  # 공격적: 85%
        elif self.style == HeroStyle.DEFENSIVE:
            dash_chance = 0.5  # 수비적: 50%
        elif self.style == HeroStyle.TRICKY:
            dash_chance = 0.7  # 트릭: 70%

        if random.random() < dash_chance:
            return self.try_dash(predicted_x)

        return False

    def draw_dash_effects(self, screen: pygame.Surface):
        """대쉬 효과 그리기 (잔상 + 후딜 표시)"""
        # 잔상 그리기 (이미지 기반)
        for after in self.dash_afterimages:
            alpha = after.get('alpha', 0)
            if alpha <= 0:
                continue

            x = after.get('x', 0)
            y = after.get('y', 0)
            color = after.get('color', self.hero["color"])

            # 잔상 표면 생성
            trail_w = int(PADDLE_WIDTH * 0.9)
            trail_h = int(PADDLE_HEIGHT * 1.5)
            trail_surf = pygame.Surface((trail_w, trail_h), pygame.SRCALPHA)
            pygame.draw.ellipse(trail_surf, (*color, int(alpha * 0.7)),
                               (0, 0, trail_w, trail_h))
            screen.blit(trail_surf, (int(x - trail_w // 2), int(y - trail_h // 2)))

        # 대쉬 중 속도선 효과
        if self.dash_active:
            # 속도감 표현 줄무늬
            for i in range(3):
                offset = (3 - i) * 8 * (-self.dash_direction)
                alpha = 100 - i * 30
                line_surface = pygame.Surface((4, PADDLE_HEIGHT), pygame.SRCALPHA)
                line_surface.fill((255, 255, 255, alpha))
                screen.blit(line_surface, (int(self.x + offset), int(self.y)))

# ============================================================================
# 공 클래스 (실제 게임 물리 적용)
# ============================================================================
class ArenaBall:
    """실제 게임과 동일한 물리를 가진 공"""

    def __init__(self):
        self.x = GAME_AREA_X + GAME_AREA_WIDTH // 2
        self.y = SCREEN_HEIGHT // 2
        self.vx = 0.0
        self.vy = 0.0
        self.visible = False
        self.trail = []  # 잔상 효과

    def reset(self, direction: int = 1, serve_x: float = None):
        """공 초기화"""
        self.x = serve_x if serve_x else GAME_AREA_X + GAME_AREA_WIDTH // 2
        self.y = SCREEN_HEIGHT // 2

        # 실제 게임과 동일한 초기 속도
        angle = random.uniform(-0.4, 0.4)
        self.vx = BALL_BASE_SPEED * math.sin(angle)
        self.vy = BALL_BASE_SPEED * direction
        self.visible = True
        self.trail = []

    def update(self, dt: float = 1/60) -> Optional[str]:
        """공 업데이트 (실제 게임 물리)"""
        if not self.visible:
            return None

        # 잔상 추가
        self.trail.append((self.x, self.y, 1.0))
        # 잔상 페이드 아웃
        self.trail = [(x, y, a - 0.1) for x, y, a in self.trail if a > 0.1]
        if len(self.trail) > 10:
            self.trail = self.trail[-10:]

        # 위치 업데이트
        self.x += self.vx
        self.y += self.vy

        # 좌우 벽 반사
        left_wall = GAME_AREA_X + BALL_SIZE
        right_wall = GAME_AREA_X + GAME_AREA_WIDTH - BALL_SIZE

        if self.x <= left_wall:
            self.x = left_wall
            self.vx = abs(self.vx) * WALL_BOUNCE_SLOWDOWN
        elif self.x >= right_wall:
            self.x = right_wall
            self.vx = -abs(self.vx) * WALL_BOUNCE_SLOWDOWN

        # 상하 득점 체크
        if self.y <= 0:
            self.visible = False
            return "bottom"  # 하단 플레이어 득점
        elif self.y >= SCREEN_HEIGHT:
            self.visible = False
            return "top"  # 상단 플레이어 득점

        return None

    def check_paddle_collision(self, paddle: AIPaddleController) -> bool:
        """패들 충돌 체크 (실제 게임과 동일)"""
        if not self.visible:
            return False

        paddle_rect = paddle.get_rect()

        # 확장된 충돌 박스 (실제 게임처럼)
        ball_rect = pygame.Rect(
            self.x - BALL_SIZE - 2,
            self.y - BALL_SIZE - 2,
            BALL_SIZE * 2 + 4,
            BALL_SIZE * 2 + 4
        )

        if paddle_rect.colliderect(ball_rect):
            # 이미 맞은 방향이면 무시 (관통 방지)
            if paddle.is_top and self.vy < 0:
                return False
            if not paddle.is_top and self.vy > 0:
                return False

            # 충돌 위치 보정
            if paddle.is_top:
                self.y = paddle_rect.bottom + BALL_SIZE + 1
            else:
                self.y = paddle_rect.top - BALL_SIZE - 1

            # 반사 및 가속
            self.vy = -self.vy * BALL_ACCELERATION

            # 패들 타격 위치에 따른 각도 변화 (실제 게임 공식)
            paddle_center = paddle.get_center_x()
            hit_offset = (self.x - paddle_center) / (PADDLE_WIDTH / 2)
            hit_offset = max(-1.0, min(1.0, hit_offset))

            # 타격 위치와 파워에 따른 X 속도 변화
            self.vx += hit_offset * PADDLE_HIT_ANGLE_FACTOR * paddle.power

            # 속도 제한
            speed = math.hypot(self.vx, self.vy)
            if speed > BALL_MAX_SPEED:
                scale = BALL_MAX_SPEED / speed
                self.vx *= scale
                self.vy *= scale

            # 최소 Y 속도 보장 (수평으로 가는 것 방지)
            min_vy = 3.0
            if abs(self.vy) < min_vy:
                self.vy = min_vy if self.vy > 0 else -min_vy

            return True
        return False

    def get_speed(self) -> float:
        return math.hypot(self.vx, self.vy)


# ============================================================================
# 공 생성 애니메이션
# ============================================================================
class BallSpawnAnimation:
    """실제 게임과 동일한 공 생성 애니메이션"""

    def __init__(self):
        self.active = False
        self.phase = 0  # 0: 에너지 수집, 1: 공 형성, 2: 서브 모션
        self.timer = 0.0
        self.particles = []
        self.center_x = GAME_AREA_X + GAME_AREA_WIDTH // 2
        self.center_y = SCREEN_HEIGHT // 2
        self.ball_alpha = 0
        self.serve_direction = 1
        self.complete = False

        # 페이즈 지속 시간
        self.phase_durations = [1.5, 0.8, 0.5]  # 빠른 버전

    def start(self, serve_direction: int = 1):
        """애니메이션 시작"""
        self.active = True
        self.phase = 0
        self.timer = 0.0
        self.complete = False
        self.serve_direction = serve_direction
        self.ball_alpha = 0

        # 파티클 생성
        self.particles = []
        for _ in range(30):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(100, 200)
            speed = random.uniform(80, 150)
            self.particles.append({
                'x': self.center_x + math.cos(angle) * dist,
                'y': self.center_y + math.sin(angle) * dist,
                'angle': angle,
                'speed': speed,
                'size': random.uniform(2, 5),
                'color_shift': random.uniform(0, 1),
            })

    def update(self, dt: float) -> bool:
        """업데이트, 완료 시 True 반환"""
        if not self.active:
            return False

        self.timer += dt

        phase_duration = self.phase_durations[self.phase]

        if self.phase == 0:
            # 페이즈 0: 에너지 수집 - 파티클이 중앙으로 모임
            progress = min(1.0, self.timer / phase_duration)
            for p in self.particles:
                # 중앙으로 수렴
                target_dist = 150 * (1 - progress)
                current_dist = math.hypot(p['x'] - self.center_x, p['y'] - self.center_y)
                if current_dist > target_dist:
                    move_speed = p['speed'] * dt
                    dx = self.center_x - p['x']
                    dy = self.center_y - p['y']
                    dist = math.hypot(dx, dy)
                    if dist > 0:
                        p['x'] += (dx / dist) * move_speed
                        p['y'] += (dy / dist) * move_speed

                # 회전
                p['angle'] += dt * 3

            if self.timer >= phase_duration:
                self.phase = 1
                self.timer = 0

        elif self.phase == 1:
            # 페이즈 1: 공 형성
            progress = min(1.0, self.timer / phase_duration)
            self.ball_alpha = int(255 * progress)

            # 파티클이 공으로 흡수
            for p in self.particles:
                p['size'] *= 0.95

            if self.timer >= phase_duration:
                self.phase = 2
                self.timer = 0

        elif self.phase == 2:
            # 페이즈 2: 준비 완료
            progress = min(1.0, self.timer / phase_duration)

            if self.timer >= phase_duration:
                self.active = False
                self.complete = True
                return True

        return False

    def draw(self, screen: pygame.Surface):
        """애니메이션 그리기"""
        if not self.active:
            return

        # 파티클 그리기
        for p in self.particles:
            if p['size'] < 0.5:
                continue

            # 색상 (노랑 ~ 주황 ~ 흰색)
            hue = p['color_shift'] + self.timer * 0.5
            r = int(200 + 55 * math.sin(hue))
            g = int(180 + 75 * math.sin(hue + 1))
            b = int(100 + 100 * math.sin(hue + 2))

            size = int(p['size'])
            if size > 0:
                surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                alpha = min(255, int(200 * (p['size'] / 5)))
                pygame.draw.circle(surf, (r, g, b, alpha), (size, size), size)
                screen.blit(surf, (int(p['x']) - size, int(p['y']) - size), special_flags=pygame.BLEND_ADD)

        # 중앙 글로우
        if self.phase >= 1:
            glow_size = 40 + int(20 * math.sin(self.timer * 10))
            glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
            for r in range(glow_size, 0, -5):
                alpha = int(30 * self.ball_alpha / 255 * (r / glow_size))
                pygame.draw.circle(glow_surf, (255, 220, 100, alpha), (glow_size, glow_size), r)
            screen.blit(glow_surf, (int(self.center_x) - glow_size, int(self.center_y) - glow_size),
                       special_flags=pygame.BLEND_ADD)

        # 공 그리기 (형성 중)
        if self.ball_alpha > 0:
            # 그림자
            pygame.draw.circle(screen, (40, 35, 30),
                             (int(self.center_x) + 2, int(self.center_y) + 3), BALL_SIZE)
            # 공 본체
            ball_color = (255, 255, 255, self.ball_alpha)
            ball_surf = pygame.Surface((BALL_SIZE * 2 + 4, BALL_SIZE * 2 + 4), pygame.SRCALPHA)
            pygame.draw.circle(ball_surf, ball_color, (BALL_SIZE + 2, BALL_SIZE + 2), BALL_SIZE)
            screen.blit(ball_surf, (int(self.center_x) - BALL_SIZE - 2, int(self.center_y) - BALL_SIZE - 2))
            # 하이라이트
            if self.ball_alpha > 200:
                pygame.draw.circle(screen, (255, 255, 220),
                                 (int(self.center_x) - 3, int(self.center_y) - 3), 3)

    def get_spawn_position(self) -> Tuple[float, float]:
        return self.center_x, self.center_y

    def is_complete(self) -> bool:
        return self.complete

# ============================================================================
# 토너먼트 시스템
# ============================================================================
class ColosseumsArena:
    def __init__(self, screen: pygame.Surface, fonts: Dict, player_gold: int, battle_callback=None):
        """
        Args:
            screen: Pygame 화면
            fonts: 폰트 딕셔너리
            player_gold: 플레이어 골드
            battle_callback: 배틀 시작 콜백 (top_hero, bottom_hero) -> bool
                            None이면 자체 물리 시스템 사용
        """
        self.screen = screen
        self.fonts = fonts
        self.player_gold = player_gold
        self.battle_callback = battle_callback  # 실제 게임 엔진 사용 콜백

        # 토너먼트 상태
        self.state = TournamentState.BRACKET_VIEW
        self.current_round = TournamentRound.QUARTER_FINAL

        # 대진표 생성 - 상단/하단 영웅 그룹 분리 후 랜덤 매칭
        self.top_heroes = random.sample(TOP_HEROES, 4)  # 상단 패들 영웅 4명 랜덤
        self.bottom_heroes = random.sample(BOTTOM_HEROES, 4)  # 하단 패들 영웅 4명 랜덤
        self.heroes = self.top_heroes + self.bottom_heroes  # 호환성용
        self.matches: Dict[TournamentRound, List[Match]] = {
            TournamentRound.QUARTER_FINAL: [],
            TournamentRound.SEMI_FINAL: [],
            TournamentRound.FINAL: [],
        }
        self._generate_bracket()

        # 배팅 정보
        self.selected_match: Optional[Match] = None
        self.bet_hero: Optional[Dict] = None
        self.bet_amount = 0
        self.total_winnings = 0

        # 배틀 상태
        self.battle_active = False
        self.top_paddle: Optional[AIPaddleController] = None
        self.bottom_paddle: Optional[AIPaddleController] = None
        self.ball: Optional[ArenaBall] = None
        self.ball_spawn_animation: Optional[BallSpawnAnimation] = None  # 공 생성 애니메이션
        self.spawn_phase = False  # 공 생성 중 여부
        self.score_top = 0
        self.score_bottom = 0

        # UI 상태
        self.animation_timer = 0
        self.result_display_timer = 0
        self.exit_requested = False
        self.winnings_collected = False

        # 시각 효과 (배경/필러)
        self.arena_background = None
        self.arena_pillar = None
        if VISUAL_ASSETS_AVAILABLE:
            try:
                self.arena_background = AnimatedBackgroundStage30(
                    width=GAME_AREA_WIDTH, height=SCREEN_HEIGHT
                )
                self.arena_pillar = ColosseumFrame(
                    screen_width=SCREEN_WIDTH,
                    screen_height=SCREEN_HEIGHT,
                    game_width=GAME_AREA_WIDTH,
                    game_height=SCREEN_HEIGHT,
                    offset_x=GAME_AREA_X,
                    offset_y=0
                )
            except Exception as e:
                print(f"Arena visual assets init error: {e}")
                self.arena_background = None
                self.arena_pillar = None

        # 영웅 패들 렌더러
        self.hero_paddle_renderer = None
        if HERO_PADDLES_AVAILABLE:
            try:
                self.hero_paddle_renderer = get_hero_paddle_renderer()
            except Exception as e:
                print(f"Hero paddle renderer init error: {e}")
                self.hero_paddle_renderer = None

        # 영웅 스킬 시스템
        self.skill_manager: Optional[HeroSkillManager] = None
        if HERO_SKILLS_AVAILABLE:
            try:
                self.skill_manager = get_skill_manager()
                self.skill_manager.reset()
            except Exception as e:
                print(f"Skill manager init error: {e}")
                self.skill_manager = None

        # 스킬 쿨다운 체크 타이머 (AI가 쿨다운 스킬 사용)
        self.skill_check_timer = 0.0
        self.skill_check_interval = 0.5  # 0.5초마다 체크

        # 말풍선 시스템 (스킬 발동 시 외침)
        self.top_speech_text = ""       # 상단 영웅 말풍선 텍스트
        self.top_speech_timer = 0       # 상단 영웅 말풍선 타이머
        self.bottom_speech_text = ""    # 하단 영웅 말풍선 텍스트
        self.bottom_speech_timer = 0    # 하단 영웅 말풍선 타이머
        self.speech_duration = 90       # 말풍선 표시 시간 (1.5초)

    def _generate_bracket(self):
        """8강 대진표 생성 - 상단 영웅 vs 하단 영웅 매칭"""
        for i in range(4):
            # hero1 = 상단 패들 (화면 위), hero2 = 하단 패들 (화면 아래)
            match = Match(self.top_heroes[i], self.bottom_heroes[i], i)
            self.matches[TournamentRound.QUARTER_FINAL].append(match)

    def _advance_to_next_round(self):
        """다음 라운드 진출"""
        if self.current_round == TournamentRound.QUARTER_FINAL:
            # 8강 → 4강
            winners = [m.winner for m in self.matches[TournamentRound.QUARTER_FINAL]]
            # 포지션 유지: top 영웅이 hero1, bottom 영웅이 hero2
            self.matches[TournamentRound.SEMI_FINAL] = [
                self._create_positioned_match(winners[0], winners[1], 0),
                self._create_positioned_match(winners[2], winners[3], 1),
            ]
            self.current_round = TournamentRound.SEMI_FINAL
        elif self.current_round == TournamentRound.SEMI_FINAL:
            # 4강 → 결승
            winners = [m.winner for m in self.matches[TournamentRound.SEMI_FINAL]]
            self.matches[TournamentRound.FINAL] = [
                self._create_positioned_match(winners[0], winners[1], 0),
            ]
            self.current_round = TournamentRound.FINAL

    def _create_positioned_match(self, hero_a: Dict, hero_b: Dict, match_id: int) -> Match:
        """포지션에 따라 hero1(상단)/hero2(하단) 결정"""
        pos_a = hero_a.get("position", "top")
        pos_b = hero_b.get("position", "bottom")

        # 둘 다 같은 포지션이면 랜덤 배치
        if pos_a == pos_b:
            if random.random() < 0.5:
                return Match(hero_a, hero_b, match_id)
            else:
                return Match(hero_b, hero_a, match_id)

        # top 포지션 영웅이 hero1 (상단 패들)
        if pos_a == "top":
            return Match(hero_a, hero_b, match_id)
        else:
            return Match(hero_b, hero_a, match_id)

    def _calculate_odds(self, hero1: Dict, hero2: Dict) -> Tuple[float, float]:
        """배당률 계산"""
        # 능력치 기반 승률 계산
        power1 = hero1["speed"] + hero1["reaction"] + hero1["power"] + hero1["accuracy"]
        power2 = hero2["speed"] + hero2["reaction"] + hero2["power"] + hero2["accuracy"]

        total = power1 + power2
        prob1 = power1 / total
        prob2 = power2 / total

        # 배당률 (약간의 마진 포함)
        odds1 = round(1 / prob1 * 0.9, 2)
        odds2 = round(1 / prob2 * 0.9, 2)

        return odds1, odds2

    def _run_real_game_battle(self, top_hero: dict, bottom_hero: dict) -> bool:
        """실제 게임 엔진으로 배틀 실행 (pingfighter.main 호출)"""
        try:
            import pingfighter

            # 투기장 모드 글로벌 변수 설정
            pingfighter.arena_mode_enabled = True
            pingfighter.arena_top_hero = top_hero
            pingfighter.arena_bottom_hero = bottom_hero

            # 영웅 패들 렌더러 초기화
            try:
                pingfighter.arena_hero_paddle_renderer = get_hero_paddle_renderer()
            except Exception:
                pingfighter.arena_hero_paddle_renderer = None

            # 영웅 스킬 시스템 초기화
            try:
                from downtown.hero_skills import get_skill_manager, HERO_SKILLS_AVAILABLE
                if HERO_SKILLS_AVAILABLE:
                    pingfighter.arena_skill_manager = get_skill_manager()
                    pingfighter.arena_skill_manager.reset()
                    pingfighter.arena_skill_manager.init_hero_skills(top_hero["id"], is_top=True)
                    pingfighter.arena_skill_manager.init_hero_skills(bottom_hero["id"], is_top=False)
                    pingfighter.arena_skill_check_timer = 0.0
                    print(f"[Arena] Skills initialized: {top_hero['id']} vs {bottom_hero['id']}")
            except Exception as e:
                print(f"Arena skill manager init error: {e}")
                import traceback
                traceback.print_exc()
                pingfighter.arena_skill_manager = None

            # AI 플레이 모드 활성화
            pingfighter.player_ai_enabled = True

            # AI 컨트롤러 리셋
            try:
                from ai.player_ai import get_player_ai_controller
                get_player_ai_controller().on_stage_start()
            except Exception:
                pass

            # 스테이지 30에서 게임 실행
            result = pingfighter.main(30)

            return result

        except Exception as e:
            print(f"Real game battle error: {e}")
            import traceback
            traceback.print_exc()
            return random.choice([True, False])

        finally:
            # 투기장 모드 변수 초기화
            try:
                pingfighter.arena_mode_enabled = False
                pingfighter.arena_top_hero = None
                pingfighter.arena_bottom_hero = None
                pingfighter.arena_hero_paddle_renderer = None
                pingfighter.arena_skill_manager = None
                pingfighter.arena_skill_check_timer = 0.0
            except Exception:
                pass

    def start_battle(self, match: Match):
        """배틀 시작 - 실제 게임 엔진 사용 (pingfighter.main 스테이지 30)"""
        self.selected_match = match

        # 점수 리셋
        self.score_top = 0
        self.score_bottom = 0

        # 실제 게임 엔진으로 배틀 실행
        try:
            if self.battle_callback:
                result = self.battle_callback(match.hero1, match.hero2)
            else:
                result = self._run_real_game_battle(match.hero1, match.hero2)

            # 결과 처리: True = 보스 처치 (하단 영웅 승리), False = 패배 (상단 영웅 승리)
            if result:
                winner = match.hero2
                self.score_top = 0
                self.score_bottom = 5
            else:
                winner = match.hero1
                self.score_top = 5
                self.score_bottom = 0

            self._end_battle(winner)

        except Exception as e:
            print(f"Arena battle error: {e}")
            import traceback
            traceback.print_exc()
            # 에러 시 랜덤 승자 결정
            winner = random.choice([match.hero1, match.hero2])
            self.score_top = 5 if winner == match.hero1 else 0
            self.score_bottom = 5 if winner == match.hero2 else 0
            self._end_battle(winner)

    def update_battle(self, dt: float = 1/60) -> bool:
        """배틀 업데이트, 완료 시 True 반환"""
        if not self.battle_active:
            return False

        # 스킬 시스템 업데이트
        if self.skill_manager and self.top_paddle and self.bottom_paddle and self.ball:
            self._update_skills(dt)

        # 날씨 파티클 업데이트 (용의 날개 강풍 이펙트)
        if WEATHER_EVENT_AVAILABLE and weather_module.weather_event_active and weather_module.weather_event_type == "gust":
            weather_module.update_weather_particles(SCREEN_WIDTH, SCREEN_HEIGHT)

        # 공 생성 애니메이션 처리
        if self.spawn_phase and self.ball_spawn_animation:
            if self.ball_spawn_animation.update(dt):
                # 애니메이션 완료 - 공 실제 생성
                self.spawn_phase = False
                direction = self.ball_spawn_animation.serve_direction
                self.ball.reset(direction=direction)

            # 스폰 중에도 패들은 중앙으로 이동
            self.top_paddle.update(
                GAME_AREA_X + GAME_AREA_WIDTH // 2,  # 중앙
                SCREEN_HEIGHT // 2,
                0.0, 0.0, dt
            )
            self.bottom_paddle.update(
                GAME_AREA_X + GAME_AREA_WIDTH // 2,
                SCREEN_HEIGHT // 2,
                0.0, 0.0, dt
            )
            return False

        # AI 패들 업데이트 (실제 게임과 동일한 파라미터)
        self.top_paddle.update(
            self.ball.x, self.ball.y,
            self.ball.vx, self.ball.vy, dt
        )
        self.bottom_paddle.update(
            self.ball.x, self.ball.y,
            self.ball.vx, self.ball.vy, dt
        )

        # 공 업데이트
        scorer = self.ball.update(dt)

        # 패들 충돌 체크 + 스킬 발동
        if self.ball.check_paddle_collision(self.top_paddle):
            self._on_ball_hit(self.selected_match.hero1["id"], self.top_paddle, self.bottom_paddle)
        if self.ball.check_paddle_collision(self.bottom_paddle):
            self._on_ball_hit(self.selected_match.hero2["id"], self.bottom_paddle, self.top_paddle)

        # 득점 처리
        if scorer:
            if scorer == "top":
                self.score_top += 1
            else:
                self.score_bottom += 1

            # 승리 체크 (5점 선취, 4:4부터 듀스)
            if self._check_winner():
                return True

            # 공 리셋 (애니메이션으로 시작)
            self.ball.visible = False
            self.ball_spawn_animation = BallSpawnAnimation()
            self.ball_spawn_animation.start(serve_direction=1 if scorer == "bottom" else -1)
            self.spawn_phase = True

        return False

    def _update_skills(self, dt: float):
        """스킬 시스템 업데이트"""
        if not self.skill_manager:
            return

        # 스킬 매니저 업데이트
        self.skill_manager.update(dt, self.top_paddle, self.bottom_paddle, self.ball)

        # 상태 효과 적용 (패들별)
        game_state = self.skill_manager.game_state

        # 상단 패들 상태 효과
        self.top_paddle.is_stunned = game_state.get('top_paddle_stunned', False)
        self.top_paddle.slow_multiplier = game_state.get('top_paddle_slow_amount', 1.0) if game_state.get('top_paddle_slowed', False) else 1.0
        self.top_paddle.is_confused = game_state.get('top_paddle_confused', False)
        self.top_paddle.paddle_scale = game_state.get('top_paddle_shrink_scale', 1.0) if game_state.get('top_paddle_shrink', False) else 1.0

        # 하단 패들 상태 효과
        self.bottom_paddle.is_stunned = game_state.get('bottom_paddle_stunned', False)
        self.bottom_paddle.slow_multiplier = game_state.get('bottom_paddle_slow_amount', 1.0) if game_state.get('bottom_paddle_slowed', False) else 1.0
        self.bottom_paddle.is_confused = game_state.get('bottom_paddle_confused', False)
        self.bottom_paddle.paddle_scale = game_state.get('bottom_paddle_shrink_scale', 1.0) if game_state.get('bottom_paddle_shrink', False) else 1.0

        # 패들 위치 고정 (스킬에 의한 locked 상태)
        self.top_paddle.is_locked = game_state.get('top_paddle_locked', False)
        self.bottom_paddle.is_locked = game_state.get('bottom_paddle_locked', False)

        # locked 상태에서 X, Y 위치 강제 고정
        if self.top_paddle.is_locked:
            if 'top_paddle_locked_x' in game_state:
                self.top_paddle.x = game_state['top_paddle_locked_x']
            if 'top_paddle_locked_y' in game_state:
                self.top_paddle.y = game_state['top_paddle_locked_y']
        if self.bottom_paddle.is_locked:
            if 'bottom_paddle_locked_x' in game_state:
                self.bottom_paddle.x = game_state['bottom_paddle_locked_x']
            if 'bottom_paddle_locked_y' in game_state:
                self.bottom_paddle.y = game_state['bottom_paddle_locked_y']

        # 쿨다운 스킬 자동 사용 (AI)
        self.skill_check_timer += dt
        if self.skill_check_timer >= self.skill_check_interval:
            self.skill_check_timer = 0
            self._try_use_cooldown_skills()

    def _on_ball_hit(self, hero_id: str, caster_paddle, target_paddle):
        """공을 칠 때 ON_BALL_HIT 스킬 발동"""
        if not self.skill_manager or not HERO_SKILLS_AVAILABLE:
            return

        result = self.skill_manager.try_use_skill(
            hero_id,
            SkillTrigger.ON_BALL_HIT,
            caster_paddle,
            target_paddle,
            self.ball
        )

        # 스킬이 성공적으로 발동되면 말풍선 표시
        if result and 'skill_korean_name' in result:
            is_top = result.get('caster_is_top', caster_paddle.is_top)
            self.show_speech_bubble(is_top, result['skill_korean_name'])

    def _try_use_cooldown_skills(self):
        """쿨다운 완료된 ON_COOLDOWN 스킬 자동 사용"""
        if not self.skill_manager or not HERO_SKILLS_AVAILABLE:
            return

        # 상단 영웅 스킬
        if self.selected_match and random.random() < 0.7:  # 70% 확률로 사용 시도
            result = self.skill_manager.try_use_skill(
                self.selected_match.hero1["id"],
                SkillTrigger.ON_COOLDOWN,
                self.top_paddle,
                self.bottom_paddle,
                self.ball
            )
            # 스킬 발동 시 말풍선 표시
            if result and 'skill_korean_name' in result:
                self.show_speech_bubble(True, result['skill_korean_name'])

        # 하단 영웅 스킬
        if self.selected_match and random.random() < 0.7:
            result = self.skill_manager.try_use_skill(
                self.selected_match.hero2["id"],
                SkillTrigger.ON_COOLDOWN,
                self.bottom_paddle,
                self.top_paddle,
                self.ball
            )
            # 스킬 발동 시 말풍선 표시
            if result and 'skill_korean_name' in result:
                self.show_speech_bubble(False, result['skill_korean_name'])

    def show_speech_bubble(self, is_top: bool, skill_name: str):
        """영웅 말풍선 표시"""
        if is_top:
            self.top_speech_text = skill_name + "!"
            self.top_speech_timer = self.speech_duration
        else:
            self.bottom_speech_text = skill_name + "!"
            self.bottom_speech_timer = self.speech_duration

    def _draw_speech_bubbles(self):
        """영웅 말풍선 그리기"""
        # 상단 영웅 말풍선
        if self.top_speech_timer > 0 and self.top_paddle and self.top_speech_text:
            self._draw_single_speech_bubble(
                self.top_paddle.x + PADDLE_WIDTH // 2,
                self.top_paddle.y + PADDLE_HEIGHT + 10,
                self.top_speech_text,
                is_top=True
            )
            self.top_speech_timer -= 1

        # 하단 영웅 말풍선
        if self.bottom_speech_timer > 0 and self.bottom_paddle and self.bottom_speech_text:
            self._draw_single_speech_bubble(
                self.bottom_paddle.x + PADDLE_WIDTH // 2,
                self.bottom_paddle.y - 50,
                self.bottom_speech_text,
                is_top=False
            )
            self.bottom_speech_timer -= 1

    def _draw_single_speech_bubble(self, x: float, y: float, text: str, is_top: bool):
        """개별 말풍선 그리기"""
        try:
            # 폰트 설정
            font = pygame.font.Font(None, 24)
            try:
                # 한글 폰트 시도
                import os
                import sys
                if hasattr(sys, '_MEIPASS'):
                    font_path = os.path.join(sys._MEIPASS, "fonts", "NanumSquareB.ttf")
                else:
                    font_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "fonts", "NanumSquareB.ttf")
                if os.path.exists(font_path):
                    font = pygame.font.Font(font_path, 20)
            except:
                pass

            text_surface = font.render(text, True, (0, 0, 0))

            # 말풍선 크기 계산
            padding = 12
            bubble_width = text_surface.get_width() + padding * 2
            bubble_height = text_surface.get_height() + padding

            # 말풍선 위치
            bubble_x = int(x - bubble_width // 2)
            bubble_y = int(y)

            # 화면 경계 체크
            bubble_x = max(GAME_AREA_X + 5, min(bubble_x, GAME_AREA_X + GAME_AREA_WIDTH - bubble_width - 5))

            # 말풍선 표면 생성
            bubble_surface = pygame.Surface((bubble_width + 15, bubble_height + 25), pygame.SRCALPHA)

            # 그림자
            shadow_rect = pygame.Rect(3, 3, bubble_width, bubble_height)
            pygame.draw.rect(bubble_surface, (0, 0, 0, 60), shadow_rect, border_radius=10)

            # 메인 말풍선
            main_rect = pygame.Rect(0, 0, bubble_width, bubble_height)
            pygame.draw.rect(bubble_surface, (255, 255, 255), main_rect, border_radius=10)
            pygame.draw.rect(bubble_surface, (50, 50, 50), main_rect, 2, border_radius=10)

            # 말풍선 꼬리 (위/아래 방향)
            if is_top:
                # 상단 영웅: 꼬리가 위쪽 (영웅을 향함)
                tail_points = [
                    (bubble_width // 2 - 8, 2),
                    (bubble_width // 2 + 8, 2),
                    (bubble_width // 2, -12)
                ]
            else:
                # 하단 영웅: 꼬리가 아래쪽 (영웅을 향함)
                tail_points = [
                    (bubble_width // 2 - 8, bubble_height - 2),
                    (bubble_width // 2 + 8, bubble_height - 2),
                    (bubble_width // 2, bubble_height + 12)
                ]

            pygame.draw.polygon(bubble_surface, (255, 255, 255), tail_points)
            pygame.draw.polygon(bubble_surface, (50, 50, 50), tail_points, 2)

            # 텍스트 그리기
            bubble_surface.blit(text_surface, (padding, padding // 2))

            # 애니메이션 (살짝 흔들림)
            timer = self.top_speech_timer if is_top else self.bottom_speech_timer
            float_offset = math.sin(timer * 0.15) * 2

            # 화면에 그리기
            self.screen.blit(bubble_surface, (bubble_x, bubble_y + float_offset))

        except Exception as e:
            # 오류 시 무시
            pass

    def _check_winner(self) -> bool:
        """승자 체크 (5점 선취, 듀스 룰)"""
        s1, s2 = self.score_top, self.score_bottom

        # 듀스 전: 5점 선취
        if s1 < 4 and s2 < 4:
            if s1 >= WIN_SCORE:
                self._end_battle(self.selected_match.hero1)
                return True
            if s2 >= WIN_SCORE:
                self._end_battle(self.selected_match.hero2)
                return True
        else:
            # 듀스: 2점 차이
            if abs(s1 - s2) >= 2:
                if s1 > s2:
                    self._end_battle(self.selected_match.hero1)
                else:
                    self._end_battle(self.selected_match.hero2)
                return True

        return False

    def _end_battle(self, winner: Dict):
        """배틀 종료"""
        self.battle_active = False
        self.selected_match.set_result(winner, self.score_top, self.score_bottom)

        # 배팅 결과 계산
        if self.bet_hero:
            if winner == self.bet_hero:
                # 승리
                odds1, odds2 = self._calculate_odds(
                    self.selected_match.hero1,
                    self.selected_match.hero2
                )
                odds = odds1 if self.bet_hero == self.selected_match.hero1 else odds2
                self.total_winnings += int(self.bet_amount * odds)
            else:
                # 패배
                self.total_winnings -= self.bet_amount

        self.state = TournamentState.RESULT
        self.result_display_timer = 180  # 3초

    def update(self, dt: float):
        """메인 업데이트"""
        self.animation_timer += dt

        # 시각 효과 업데이트
        if self.arena_background:
            ball_x = self.ball.x if self.ball else None
            ball_y = self.ball.y if self.ball else None
            self.arena_background.update(dt, ball_x, ball_y)
        if self.arena_pillar:
            self.arena_pillar.update(dt)

        # 영웅 패들 렌더러 업데이트
        if self.hero_paddle_renderer:
            self.hero_paddle_renderer.update(dt)
            # 이동 애니메이션 추적
            if self.top_paddle and self.selected_match:
                self.hero_paddle_renderer.update_movement(
                    self.selected_match.hero1["id"],
                    self.top_paddle.x + PADDLE_WIDTH // 2,
                    dt
                )
            if self.bottom_paddle and self.selected_match:
                self.hero_paddle_renderer.update_movement(
                    self.selected_match.hero2["id"],
                    self.bottom_paddle.x + PADDLE_WIDTH // 2,
                    dt
                )

        if self.state == TournamentState.BATTLE:
            self.update_battle(dt)
        elif self.state == TournamentState.RESULT:
            self.result_display_timer -= 1
            if self.result_display_timer <= 0:
                # 다음 단계 결정
                current_matches = self.matches[self.current_round]
                all_completed = all(m.completed for m in current_matches)

                if all_completed:
                    if self.current_round == TournamentRound.FINAL:
                        self.state = TournamentState.TOURNAMENT_END
                    else:
                        self.state = TournamentState.ROUND_END
                else:
                    self.state = TournamentState.SELECT_MATCH

    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리, 종료 시 True 반환"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                if self.state == TournamentState.BATTLE:
                    return False  # 배틀 중에는 나갈 수 없음
                self.exit_requested = True
                return True

        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:  # 좌클릭
                self._handle_click(event.pos)

        return self.exit_requested

    def _handle_click(self, pos: Tuple[int, int]):
        """클릭 처리"""
        mx, my = pos

        if self.state in [TournamentState.BRACKET_VIEW, TournamentState.SELECT_MATCH]:
            # 8강 매치 클릭 체크
            y_base = 550
            x_positions = [100, 250, 430, 580]
            box_w, box_h = 100, 100

            for i, match in enumerate(self.matches[TournamentRound.QUARTER_FINAL]):
                if match.completed:
                    continue
                x = x_positions[i]
                if x <= mx <= x + box_w and y_base <= my <= y_base + box_h:
                    self.selected_match = match
                    self.state = TournamentState.BETTING
                    self.bet_amount = 100  # 기본 배팅액
                    return

        elif self.state == TournamentState.BETTING:
            # 배팅 UI 클릭 처리 (그리기 좌표와 동일하게)
            panel_x, panel_y = 200, 200
            panel_w, panel_h = 360, 400

            # 영웅 1 선택 버튼
            btn1_rect = pygame.Rect(panel_x + 20, panel_y + 80, 150, 70)
            if btn1_rect.collidepoint(mx, my):
                self.bet_hero = self.selected_match.hero1
                return

            # 영웅 2 선택 버튼
            btn2_rect = pygame.Rect(panel_x + 190, panel_y + 80, 150, 70)
            if btn2_rect.collidepoint(mx, my):
                self.bet_hero = self.selected_match.hero2
                return

            # 배팅액 조절 버튼
            # -100
            if pygame.Rect(panel_x + 50, panel_y + 200, 50, 30).collidepoint(mx, my):
                self.bet_amount = max(100, self.bet_amount - 100)
                return
            # +100
            if pygame.Rect(panel_x + 260, panel_y + 200, 50, 30).collidepoint(mx, my):
                self.bet_amount = min(self.player_gold, self.bet_amount + 100)
                return
            # -500
            if pygame.Rect(panel_x + 50, panel_y + 240, 50, 30).collidepoint(mx, my):
                self.bet_amount = max(100, self.bet_amount - 500)
                return
            # +500
            if pygame.Rect(panel_x + 260, panel_y + 240, 50, 30).collidepoint(mx, my):
                self.bet_amount = min(self.player_gold, self.bet_amount + 500)
                return

            # 배팅 확정 버튼
            confirm_rect = pygame.Rect(panel_x + 80, panel_y + 320, 200, 45)
            if confirm_rect.collidepoint(mx, my) and self.bet_hero:
                self.start_battle(self.selected_match)
                return

            # 취소 버튼
            cancel_rect = pygame.Rect(panel_x + 130, panel_y + 375, 100, 30)
            if cancel_rect.collidepoint(mx, my):
                self.state = TournamentState.SELECT_MATCH
                self.bet_hero = None
                return

        elif self.state == TournamentState.RESULT:
            # 결과 화면 클릭 시 다음으로
            self.result_display_timer = 0

        elif self.state == TournamentState.ROUND_END:
            # 라운드 종료 UI 클릭 처리 (그리기 좌표와 동일하게)
            panel_x, panel_y = 150, 200

            # 계속 배팅 버튼
            continue_rect = pygame.Rect(panel_x + 40, panel_y + 200, 180, 50)
            if continue_rect.collidepoint(mx, my):
                self._advance_to_next_round()
                self.state = TournamentState.SELECT_MATCH
                return

            # 수익 확정하고 나가기 버튼
            exit_rect = pygame.Rect(panel_x + 240, panel_y + 200, 180, 50)
            if exit_rect.collidepoint(mx, my):
                self.winnings_collected = True
                self.exit_requested = True
                return

        elif self.state == TournamentState.TOURNAMENT_END:
            # 토너먼트 종료 UI 클릭 처리 (그리기 좌표와 동일하게)
            panel_x, panel_y = 180, 200
            exit_rect = pygame.Rect(panel_x + 100, panel_y + 230, 200, 50)
            if exit_rect.collidepoint(mx, my):
                self.winnings_collected = True
                self.exit_requested = True
                return

    def draw(self):
        """메인 그리기"""
        if self.state == TournamentState.BATTLE:
            self._draw_battle()
        else:
            self._draw_bracket()

    def _draw_battle(self):
        """배틀 화면 그리기"""
        # 화면 흔들림 오프셋
        shake_x, shake_y = 0, 0
        if self.skill_manager:
            shake_x, shake_y = self.skill_manager.get_screen_shake()

        # 배경
        self.screen.fill((20, 25, 30))

        # 콜로세움 배경 사용 (가능한 경우)
        if self.arena_background:
            self.arena_background.draw(self.screen, offset_x=GAME_AREA_X + shake_x, offset_y=shake_y)
        else:
            # 폴백: 기본 게임 영역
            pygame.draw.rect(self.screen, (194, 158, 108),  # 모래색
                            (GAME_AREA_X + shake_x, shake_y, GAME_AREA_WIDTH, SCREEN_HEIGHT))

        # 중앙선 (모래 위에 그려진 라인)
        center_y = SCREEN_HEIGHT // 2
        pygame.draw.line(self.screen, (164, 128, 88),
                        (GAME_AREA_X + 30 + shake_x, center_y + shake_y),
                        (GAME_AREA_X + GAME_AREA_WIDTH - 30 + shake_x, center_y + shake_y), 3)

        # 원형 경기장 라인
        pygame.draw.circle(self.screen, (164, 128, 88),
                          (GAME_AREA_X + GAME_AREA_WIDTH // 2 + shake_x, center_y + shake_y), 120, 2)

        # 스킬 이펙트 (배경 레이어)
        if self.skill_manager and self.top_paddle and self.bottom_paddle and self.ball:
            self.skill_manager.draw_skills(self.screen, self.top_paddle, self.bottom_paddle, self.ball)

        # 날씨 파티클 그리기 (용의 날개 강풍 이펙트)
        if WEATHER_EVENT_AVAILABLE and weather_module.weather_event_active and weather_module.weather_event_type == "gust":
            weather_module.draw_weather_particles(self.screen)

        # 대쉬 효과 그리기 (패들 뒤에)
        if self.top_paddle:
            self.top_paddle.draw_dash_effects(self.screen)
        if self.bottom_paddle:
            self.bottom_paddle.draw_dash_effects(self.screen)

        # 패들 그리기 (영웅 패들 렌더러 사용)
        if self.top_paddle and self.selected_match:
            paddle_rect = self.top_paddle.get_rect()
            # 패들 크기 스케일 적용
            scaled_width = int(PADDLE_WIDTH * self.top_paddle.paddle_scale)
            hero1 = self.selected_match.hero1

            if self.hero_paddle_renderer:
                # 영웅 패들 렌더러로 그리기 (상단 영웅은 아래를 바라봄)
                self.hero_paddle_renderer.draw_hero_paddle(
                    self.screen,
                    hero1["id"],
                    paddle_rect.centerx + shake_x,
                    paddle_rect.centery + shake_y,
                    scaled_width,
                    PADDLE_HEIGHT,
                    facing="down",
                    color=hero1["color"]
                )
            else:
                # 폴백: 기본 패들
                scaled_rect = pygame.Rect(
                    paddle_rect.centerx - scaled_width // 2 + shake_x,
                    paddle_rect.y + shake_y,
                    scaled_width,
                    PADDLE_HEIGHT
                )
                shadow_rect = scaled_rect.copy()
                shadow_rect.y += 3
                pygame.draw.rect(self.screen, (60, 50, 40), shadow_rect, border_radius=4)
                pygame.draw.rect(self.screen, hero1["color"], scaled_rect, border_radius=4)

                # 스턴 표시
                if self.top_paddle.is_stunned:
                    stun_surf = pygame.Surface((scaled_width + 10, PADDLE_HEIGHT + 10), pygame.SRCALPHA)
                    pygame.draw.rect(stun_surf, (255, 255, 0, 100), stun_surf.get_rect(), border_radius=6)
                    self.screen.blit(stun_surf, (scaled_rect.x - 5, scaled_rect.y - 5))

        if self.bottom_paddle and self.selected_match:
            paddle_rect = self.bottom_paddle.get_rect()
            scaled_width = int(PADDLE_WIDTH * self.bottom_paddle.paddle_scale)
            hero2 = self.selected_match.hero2

            if self.hero_paddle_renderer:
                # 영웅 패들 렌더러로 그리기 (하단 영웅은 위를 바라봄)
                self.hero_paddle_renderer.draw_hero_paddle(
                    self.screen,
                    hero2["id"],
                    paddle_rect.centerx + shake_x,
                    paddle_rect.centery + shake_y,
                    scaled_width,
                    PADDLE_HEIGHT,
                    facing="up",
                    color=hero2["color"]
                )
            else:
                # 폴백: 기본 패들
                scaled_rect = pygame.Rect(
                    paddle_rect.centerx - scaled_width // 2 + shake_x,
                    paddle_rect.y + shake_y,
                    scaled_width,
                    PADDLE_HEIGHT
                )
                shadow_rect = scaled_rect.copy()
                shadow_rect.y += 3
                pygame.draw.rect(self.screen, (60, 50, 40), shadow_rect, border_radius=4)
                pygame.draw.rect(self.screen, hero2["color"], scaled_rect, border_radius=4)

                # 스턴 표시
                if self.bottom_paddle.is_stunned:
                    stun_surf = pygame.Surface((scaled_width + 10, PADDLE_HEIGHT + 10), pygame.SRCALPHA)
                    pygame.draw.rect(stun_surf, (255, 255, 0, 100), stun_surf.get_rect(), border_radius=6)
                    self.screen.blit(stun_surf, (scaled_rect.x - 5, scaled_rect.y - 5))

        # 혼란 상태 물음표 효과 (패들 위에 빙글빙글 도는 물음표)
        self._draw_confusion_effect(shake_x, shake_y)

        # 공 생성 애니메이션
        if self.spawn_phase and self.ball_spawn_animation:
            self.ball_spawn_animation.draw(self.screen)

        # 공 그리기 (그림자 포함)
        if self.ball and self.ball.visible:
            ball_x = int(self.ball.x) + shake_x
            ball_y = int(self.ball.y) + shake_y

            # 잔상 그리기
            for tx, ty, alpha in self.ball.trail:
                trail_alpha = int(100 * alpha)
                if trail_alpha > 10:
                    trail_size = int(BALL_SIZE * 0.7 * alpha)
                    if trail_size > 1:
                        trail_surf = pygame.Surface((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(trail_surf, (255, 255, 200, trail_alpha),
                                          (trail_size, trail_size), trail_size)
                        self.screen.blit(trail_surf, (int(tx) + shake_x - trail_size, int(ty) + shake_y - trail_size))

            # 불 효과 (스킬)
            if self.skill_manager and self.skill_manager.game_state.get('ball_on_fire', False):
                fire_glow = pygame.Surface((BALL_SIZE * 4, BALL_SIZE * 4), pygame.SRCALPHA)
                pygame.draw.circle(fire_glow, (255, 100, 0, 100), (BALL_SIZE * 2, BALL_SIZE * 2), BALL_SIZE * 2)
                self.screen.blit(fire_glow, (ball_x - BALL_SIZE * 2, ball_y - BALL_SIZE * 2), special_flags=pygame.BLEND_ADD)

            # 그림자
            pygame.draw.circle(self.screen, (60, 50, 40),
                             (ball_x + 2, ball_y + 3), BALL_SIZE)
            # 공 본체
            ball_color = (255, 200, 100) if self.skill_manager and self.skill_manager.game_state.get('ball_on_fire', False) else (255, 255, 255)
            pygame.draw.circle(self.screen, ball_color,
                             (ball_x, ball_y), BALL_SIZE)
            # 하이라이트
            pygame.draw.circle(self.screen, (255, 255, 200),
                             (int(self.ball.x) - 3, int(self.ball.y) - 3), 3)

            # 공 속도에 따른 글로우 효과
            speed = self.ball.get_speed()
            if speed > 10:
                glow_intensity = min(1.0, (speed - 10) / 5)
                glow_size = int(BALL_SIZE * 1.5 + glow_intensity * 5)
                glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                glow_alpha = int(50 * glow_intensity)
                pygame.draw.circle(glow_surf, (255, 200, 100, glow_alpha),
                                  (glow_size, glow_size), glow_size)
                self.screen.blit(glow_surf, (ball_x - glow_size, ball_y - glow_size),
                                special_flags=pygame.BLEND_ADD)

        # 스킬 화면 효과 (오버레이)
        if self.skill_manager:
            self.skill_manager.draw_screen_effects(self.screen)

        # 영웅 말풍선 그리기
        self._draw_speech_bubbles()

        # 필러 (사이드 UI)
        if self.arena_pillar:
            self.arena_pillar.draw(self.screen)

        # 점수판
        self._draw_scoreboard()

        # 영웅 정보
        self._draw_hero_info()

        # 스킬 쿨타임 UI 표시
        self._draw_skill_cooldowns()

        # 전경 효과
        if self.arena_background:
            self.arena_background.draw_foreground(self.screen, offset_x=GAME_AREA_X, offset_y=0)

    def _draw_confusion_effect(self, shake_x: int = 0, shake_y: int = 0):
        """혼란 상태 물음표 효과 그리기 (패들 위에 빙글빙글 도는 물음표)"""
        current_time = pygame.time.get_ticks()
        rotation_speed = 0.005  # 회전 속도

        # 상단 패들 혼란 효과
        if self.top_paddle and self.top_paddle.is_confused:
            self._draw_question_marks(
                self.top_paddle.x + PADDLE_WIDTH // 2 + shake_x,
                self.top_paddle.y + PADDLE_HEIGHT // 2 + shake_y + 25,  # 패들 아래쪽에 표시
                current_time, rotation_speed
            )

        # 하단 패들 혼란 효과
        if self.bottom_paddle and self.bottom_paddle.is_confused:
            self._draw_question_marks(
                self.bottom_paddle.x + PADDLE_WIDTH // 2 + shake_x,
                self.bottom_paddle.y + PADDLE_HEIGHT // 2 + shake_y - 25,  # 패들 위쪽에 표시
                current_time, rotation_speed
            )

    def _draw_question_marks(self, center_x: float, center_y: float, current_time: int, rotation_speed: float):
        """빙글빙글 도는 물음표 그리기"""
        num_questions = 3
        orbit_radius = 25  # 회전 반경

        for i in range(num_questions):
            # 각 물음표의 각도 계산 (균등하게 배치)
            angle = current_time * rotation_speed + (i * 2 * math.pi / num_questions)

            # 물음표 위치 계산 (원형 궤도)
            x = center_x + orbit_radius * math.cos(angle)
            y = center_y + orbit_radius * math.sin(angle) * 0.5  # Y축은 타원형으로

            # 물음표 크기 변화 (앞뒤 구분)
            size_factor = 0.8 + 0.2 * math.sin(angle)

            # 물음표 색상 (깜빡이는 효과)
            if math.sin(current_time * 0.01 + i) > 0:
                color = (255, 255, 100)  # 밝은 노란색
            else:
                color = (255, 200, 50)   # 어두운 노란색

            # 물음표 그리기 (폰트가 있으면 사용, 없으면 원으로 대체)
            if self.fonts and "medium" in self.fonts:
                question_text, _ = self.fonts["medium"].render("?", color)
                # 크기 조절
                scaled_width = int(question_text.get_width() * size_factor)
                scaled_height = int(question_text.get_height() * size_factor)
                if scaled_width > 0 and scaled_height > 0:
                    scaled_question = pygame.transform.scale(question_text, (scaled_width, scaled_height))
                    question_rect = scaled_question.get_rect(center=(int(x), int(y)))
                    # 그림자
                    shadow_text, _ = self.fonts["medium"].render("?", (50, 50, 0))
                    scaled_shadow = pygame.transform.scale(shadow_text, (scaled_width, scaled_height))
                    shadow_rect = scaled_shadow.get_rect(center=(int(x + 2), int(y + 2)))
                    self.screen.blit(scaled_shadow, shadow_rect)
                    self.screen.blit(scaled_question, question_rect)
            else:
                # 폰트 없을 때 원으로 대체
                radius = int(8 * size_factor)
                pygame.draw.circle(self.screen, (50, 50, 0), (int(x + 2), int(y + 2)), radius)
                pygame.draw.circle(self.screen, color, (int(x), int(y)), radius)

    def _draw_scoreboard(self):
        """점수판 그리기"""
        # 배경
        board_rect = pygame.Rect(SCREEN_WIDTH // 2 - 60, 10, 120, 50)
        pygame.draw.rect(self.screen, (40, 45, 55), board_rect, border_radius=5)
        pygame.draw.rect(self.screen, (60, 65, 75), board_rect, 2, border_radius=5)

        # 점수
        if self.fonts and "large" in self.fonts:
            score_text = f"{self.score_top} : {self.score_bottom}"
            surf, _ = self.fonts["large"].render(score_text, (255, 255, 255))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 20))

    def _draw_hero_info(self):
        """영웅 정보 표시"""
        if not self.selected_match:
            return

        # 상단 영웅 (왼쪽 필러)
        hero1 = self.selected_match.hero1
        pygame.draw.rect(self.screen, hero1["color"], (5, 100, 70, 80), border_radius=5)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(hero1["name"], (255, 255, 255))
            self.screen.blit(surf, (10, 110))

        # 하단 영웅 (오른쪽 필러)
        hero2 = self.selected_match.hero2
        pygame.draw.rect(self.screen, hero2["color"], (685, 100, 70, 80), border_radius=5)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(hero2["name"], (255, 255, 255))
            self.screen.blit(surf, (690, 110))

    def _draw_skill_cooldowns(self):
        """스킬 쿨타임 UI 표시"""
        if not self.skill_manager or not self.selected_match:
            return

        # 상단 영웅 스킬 (왼쪽 필러)
        hero1_skills = self.skill_manager.active_skills.get(self.selected_match.hero1["id"], [])
        self._draw_skill_icons(hero1_skills, 5, 200, self.selected_match.hero1["color"])

        # 하단 영웅 스킬 (오른쪽 필러)
        hero2_skills = self.skill_manager.active_skills.get(self.selected_match.hero2["id"], [])
        self._draw_skill_icons(hero2_skills, 685, 200, self.selected_match.hero2["color"])

    def _draw_skill_icons(self, skills, base_x: int, base_y: int, hero_color: Tuple[int, int, int]):
        """스킬 아이콘과 쿨타임 표시"""
        if not skills:
            return

        icon_size = 30
        padding = 5

        for i, skill in enumerate(skills):
            x = base_x + 5
            y = base_y + i * (icon_size + padding)

            # 스킬 배경
            bg_color = hero_color if skill.can_use() else (40, 40, 40)
            pygame.draw.rect(self.screen, bg_color, (x, y, icon_size, icon_size), border_radius=5)
            pygame.draw.rect(self.screen, (80, 80, 80), (x, y, icon_size, icon_size), 2, border_radius=5)

            # 쿨타임 오버레이
            if skill.current_cooldown > 0:
                cooldown_ratio = skill.current_cooldown / skill.cooldown
                overlay_height = int(icon_size * cooldown_ratio)
                overlay_rect = pygame.Rect(x, y + (icon_size - overlay_height), icon_size, overlay_height)
                overlay_surf = pygame.Surface((icon_size, overlay_height), pygame.SRCALPHA)
                overlay_surf.fill((0, 0, 0, 150))
                self.screen.blit(overlay_surf, (x, y + (icon_size - overlay_height)))

                # 쿨타임 숫자
                cd_text = f"{int(skill.current_cooldown)}"
                if self.fonts and "small" in self.fonts:
                    surf, _ = self.fonts["small"].render(cd_text, (255, 255, 255))
                    self.screen.blit(surf, (x + icon_size // 2 - surf.get_width() // 2,
                                           y + icon_size // 2 - surf.get_height() // 2))

            # 활성 중 표시
            if skill.is_active:
                glow_surf = pygame.Surface((icon_size + 4, icon_size + 4), pygame.SRCALPHA)
                pygame.draw.rect(glow_surf, (255, 255, 100, 150), glow_surf.get_rect(), border_radius=6)
                self.screen.blit(glow_surf, (x - 2, y - 2))

            # 스킬 이니셜
            initial = skill.korean_name[0] if skill.korean_name else "?"
            if self.fonts and "small" in self.fonts:
                color = (255, 255, 255) if skill.can_use() else (100, 100, 100)
                surf, _ = self.fonts["small"].render(initial, color)
                self.screen.blit(surf, (x + icon_size // 2 - surf.get_width() // 2,
                                       y + icon_size + 2))

    def _draw_bracket(self):
        """대진표 화면 그리기"""
        # 배경
        self.screen.fill((25, 28, 35))

        # 타이틀
        if self.fonts and "large" in self.fonts:
            title = f"8강 대진표"
            surf, _ = self.fonts["large"].render(title, (255, 215, 0))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 30))

        # 대진표 그리기
        self._draw_tournament_bracket()

        # 현재 상태에 따른 UI
        if self.state == TournamentState.BRACKET_VIEW:
            self._draw_match_selection_hint()
        elif self.state == TournamentState.BETTING:
            self._draw_betting_ui()
        elif self.state == TournamentState.RESULT:
            self._draw_result_ui()
        elif self.state == TournamentState.ROUND_END:
            self._draw_round_end_ui()
        elif self.state == TournamentState.TOURNAMENT_END:
            self._draw_tournament_end_ui()

    def _draw_tournament_bracket(self):
        """토너먼트 대진표 그리기"""
        # 8강 매치 (하단)
        y_base = 550
        x_positions = [100, 250, 430, 580]

        for i, match in enumerate(self.matches[TournamentRound.QUARTER_FINAL]):
            x = x_positions[i]
            self._draw_match_box(match, x, y_base, i)

        # 4강 매치 (중간)
        y_semi = 380
        x_semi = [175, 505]

        for i, match in enumerate(self.matches.get(TournamentRound.SEMI_FINAL, [])):
            self._draw_match_box(match, x_semi[i], y_semi, i + 4)

        # 빈 4강 슬롯
        if not self.matches.get(TournamentRound.SEMI_FINAL):
            for i, x in enumerate(x_semi):
                self._draw_empty_match_box(x, y_semi, "준결승 " + str(i + 1))

        # 결승 (상단)
        y_final = 200
        x_final = 340

        final_matches = self.matches.get(TournamentRound.FINAL, [])
        if final_matches:
            self._draw_match_box(final_matches[0], x_final, y_final, 6)
        else:
            self._draw_empty_match_box(x_final, y_final, "결승")

        # 연결선 그리기
        self._draw_bracket_lines()

    def _draw_match_box(self, match: Match, x: int, y: int, match_idx: int):
        """매치 박스 그리기"""
        box_w, box_h = 100, 100

        # 박스 배경
        bg_color = (45, 50, 60) if not match.completed else (35, 55, 45)
        pygame.draw.rect(self.screen, bg_color, (x, y, box_w, box_h), border_radius=5)
        pygame.draw.rect(self.screen, (80, 85, 95), (x, y, box_w, box_h), 2, border_radius=5)

        # 영웅 1
        h1_color = match.hero1["color"]
        pygame.draw.rect(self.screen, h1_color, (x + 5, y + 5, box_w - 10, 40), border_radius=3)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(match.hero1["name"], (255, 255, 255))
            self.screen.blit(surf, (x + 10, y + 15))

        # VS
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render("VS", (200, 200, 200))
            self.screen.blit(surf, (x + box_w // 2 - 10, y + 45))

        # 영웅 2
        h2_color = match.hero2["color"]
        pygame.draw.rect(self.screen, h2_color, (x + 5, y + 55, box_w - 10, 40), border_radius=3)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(match.hero2["name"], (255, 255, 255))
            self.screen.blit(surf, (x + 10, y + 65))

        # 결과 표시
        if match.completed and match.winner:
            winner_text = f"승: {match.winner['name']}"
            if self.fonts and "small" in self.fonts:
                surf, _ = self.fonts["small"].render(f"{match.score1}:{match.score2}", (255, 215, 0))
                self.screen.blit(surf, (x + box_w // 2 - 15, y + box_h + 5))

    def _draw_empty_match_box(self, x: int, y: int, label: str):
        """빈 매치 박스"""
        box_w, box_h = 100, 100
        pygame.draw.rect(self.screen, (35, 38, 45), (x, y, box_w, box_h), border_radius=5)
        pygame.draw.rect(self.screen, (60, 65, 75), (x, y, box_w, box_h), 2, border_radius=5)

        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(label, (100, 100, 100))
            self.screen.blit(surf, (x + box_w // 2 - surf.get_width() // 2, y + 40))

    def _draw_bracket_lines(self):
        """대진표 연결선"""
        line_color = (70, 75, 85)

        # 8강 → 4강 연결
        # 좌측
        pygame.draw.line(self.screen, line_color, (150, 550), (150, 520), 2)
        pygame.draw.line(self.screen, line_color, (300, 550), (300, 520), 2)
        pygame.draw.line(self.screen, line_color, (150, 520), (300, 520), 2)
        pygame.draw.line(self.screen, line_color, (225, 520), (225, 480), 2)

        # 우측
        pygame.draw.line(self.screen, line_color, (480, 550), (480, 520), 2)
        pygame.draw.line(self.screen, line_color, (630, 550), (630, 520), 2)
        pygame.draw.line(self.screen, line_color, (480, 520), (630, 520), 2)
        pygame.draw.line(self.screen, line_color, (555, 520), (555, 480), 2)

        # 4강 → 결승 연결
        pygame.draw.line(self.screen, line_color, (225, 380), (225, 340), 2)
        pygame.draw.line(self.screen, line_color, (555, 380), (555, 340), 2)
        pygame.draw.line(self.screen, line_color, (225, 340), (555, 340), 2)
        pygame.draw.line(self.screen, line_color, (390, 340), (390, 300), 2)

    def _draw_match_selection_hint(self):
        """경기 선택 힌트"""
        if self.fonts and "small" in self.fonts:
            hint = "관전할 경기를 클릭하세요"
            surf, _ = self.fonts["small"].render(hint, (180, 180, 180))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 700))

    def _draw_betting_ui(self):
        """배팅 UI"""
        if not self.selected_match:
            return

        # 반투명 오버레이
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 150))
        self.screen.blit(overlay, (0, 0))

        # 배팅 패널
        panel_x, panel_y = 200, 200
        panel_w, panel_h = 360, 400
        pygame.draw.rect(self.screen, (35, 40, 50), (panel_x, panel_y, panel_w, panel_h), border_radius=10)
        pygame.draw.rect(self.screen, (100, 180, 255), (panel_x, panel_y, panel_w, panel_h), 3, border_radius=10)

        # 타이틀
        if self.fonts and "medium" in self.fonts:
            title, _ = self.fonts["medium"].render("배팅하기", (255, 215, 0))
            self.screen.blit(title, (SCREEN_WIDTH // 2 - title.get_width() // 2, panel_y + 15))

        # 매치 정보
        if self.fonts and "small" in self.fonts:
            match_text = f"{self.selected_match.hero1['name']} vs {self.selected_match.hero2['name']}"
            surf, _ = self.fonts["small"].render(match_text, (200, 200, 200))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 45))

        # 배당률 계산
        odds1, odds2 = self._calculate_odds(self.selected_match.hero1, self.selected_match.hero2)

        # 영웅 1 선택 버튼
        hero1 = self.selected_match.hero1
        btn1_selected = self.bet_hero == hero1
        btn1_color = hero1["color"] if btn1_selected else (60, 65, 75)
        btn1_rect = pygame.Rect(panel_x + 20, panel_y + 80, 150, 70)
        pygame.draw.rect(self.screen, btn1_color, btn1_rect, border_radius=5)
        pygame.draw.rect(self.screen, (255, 255, 255) if btn1_selected else (100, 105, 115),
                        btn1_rect, 2, border_radius=5)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(hero1["name"], (255, 255, 255))
            self.screen.blit(surf, (btn1_rect.centerx - surf.get_width() // 2, btn1_rect.y + 15))
            odds_text = f"배당 x{odds1}"
            surf, _ = self.fonts["small"].render(odds_text, (255, 215, 0))
            self.screen.blit(surf, (btn1_rect.centerx - surf.get_width() // 2, btn1_rect.y + 40))

        # 영웅 2 선택 버튼
        hero2 = self.selected_match.hero2
        btn2_selected = self.bet_hero == hero2
        btn2_color = hero2["color"] if btn2_selected else (60, 65, 75)
        btn2_rect = pygame.Rect(panel_x + 190, panel_y + 80, 150, 70)
        pygame.draw.rect(self.screen, btn2_color, btn2_rect, border_radius=5)
        pygame.draw.rect(self.screen, (255, 255, 255) if btn2_selected else (100, 105, 115),
                        btn2_rect, 2, border_radius=5)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(hero2["name"], (255, 255, 255))
            self.screen.blit(surf, (btn2_rect.centerx - surf.get_width() // 2, btn2_rect.y + 15))
            odds_text = f"배당 x{odds2}"
            surf, _ = self.fonts["small"].render(odds_text, (255, 215, 0))
            self.screen.blit(surf, (btn2_rect.centerx - surf.get_width() // 2, btn2_rect.y + 40))

        # 배팅액 표시
        if self.fonts and "medium" in self.fonts:
            bet_text = f"배팅액: {self.bet_amount} G"
            surf, _ = self.fonts["medium"].render(bet_text, (255, 255, 255))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 170))

        # 배팅액 조절 버튼
        btn_color = (70, 75, 85)
        # -100
        pygame.draw.rect(self.screen, btn_color, (panel_x + 50, panel_y + 200, 50, 30), border_radius=3)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render("-100", (255, 150, 150))
            self.screen.blit(surf, (panel_x + 58, panel_y + 207))
        # +100
        pygame.draw.rect(self.screen, btn_color, (panel_x + 260, panel_y + 200, 50, 30), border_radius=3)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render("+100", (150, 255, 150))
            self.screen.blit(surf, (panel_x + 268, panel_y + 207))
        # -500
        pygame.draw.rect(self.screen, btn_color, (panel_x + 50, panel_y + 240, 50, 30), border_radius=3)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render("-500", (255, 100, 100))
            self.screen.blit(surf, (panel_x + 58, panel_y + 247))
        # +500
        pygame.draw.rect(self.screen, btn_color, (panel_x + 260, panel_y + 240, 50, 30), border_radius=3)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render("+500", (100, 255, 100))
            self.screen.blit(surf, (panel_x + 268, panel_y + 247))

        # 예상 수익
        if self.bet_hero:
            odds = odds1 if self.bet_hero == hero1 else odds2
            expected = int(self.bet_amount * odds)
            if self.fonts and "small" in self.fonts:
                profit_text = f"예상 수익: {expected} G"
                surf, _ = self.fonts["small"].render(profit_text, (100, 255, 100))
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 290))

        # 배팅 확정 버튼
        confirm_enabled = self.bet_hero is not None and self.bet_amount <= self.player_gold
        confirm_color = (80, 180, 80) if confirm_enabled else (60, 60, 60)
        confirm_rect = pygame.Rect(panel_x + 80, panel_y + 320, 200, 45)
        pygame.draw.rect(self.screen, confirm_color, confirm_rect, border_radius=5)
        if self.fonts and "medium" in self.fonts:
            text_color = (255, 255, 255) if confirm_enabled else (100, 100, 100)
            surf, _ = self.fonts["medium"].render("배팅 확정", text_color)
            self.screen.blit(surf, (confirm_rect.centerx - surf.get_width() // 2, confirm_rect.y + 12))

        # 취소 버튼
        cancel_rect = pygame.Rect(panel_x + 130, panel_y + 375, 100, 30)
        pygame.draw.rect(self.screen, (100, 60, 60), cancel_rect, border_radius=3)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render("취소", (255, 200, 200))
            self.screen.blit(surf, (cancel_rect.centerx - surf.get_width() // 2, cancel_rect.y + 8))

        # 보유 골드
        if self.fonts and "small" in self.fonts:
            gold_text = f"보유: {self.player_gold} G"
            surf, _ = self.fonts["small"].render(gold_text, (255, 215, 0))
            self.screen.blit(surf, (panel_x + 10, panel_y + panel_h - 25))

    def _draw_result_ui(self):
        """결과 UI"""
        if not self.selected_match or not self.selected_match.winner:
            return

        # 반투명 오버레이
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        # 결과 패널
        panel_x, panel_y = 180, 250
        panel_w, panel_h = 400, 250
        pygame.draw.rect(self.screen, (35, 40, 50), (panel_x, panel_y, panel_w, panel_h), border_radius=10)

        winner = self.selected_match.winner
        is_win = self.bet_hero == winner

        # 테두리 색상 (승리: 금색, 패배: 빨강)
        border_color = (255, 215, 0) if is_win else (255, 80, 80)
        pygame.draw.rect(self.screen, border_color, (panel_x, panel_y, panel_w, panel_h), 3, border_radius=10)

        # 결과 타이틀
        if self.fonts and "large" in self.fonts:
            result_text = "승리!" if is_win else "패배..."
            text_color = (255, 215, 0) if is_win else (255, 100, 100)
            surf, _ = self.fonts["large"].render(result_text, text_color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 20))

        # 승자 정보
        if self.fonts and "medium" in self.fonts:
            winner_text = f"승자: {winner['name']}"
            surf, _ = self.fonts["medium"].render(winner_text, winner["color"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 70))

            # 스코어
            score_text = f"{self.selected_match.score1} : {self.selected_match.score2}"
            surf, _ = self.fonts["medium"].render(score_text, (200, 200, 200))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 100))

        # 수익/손실
        if self.fonts and "medium" in self.fonts:
            if is_win:
                odds1, odds2 = self._calculate_odds(self.selected_match.hero1, self.selected_match.hero2)
                odds = odds1 if self.bet_hero == self.selected_match.hero1 else odds2
                profit = int(self.bet_amount * odds) - self.bet_amount
                profit_text = f"+{profit} G"
                profit_color = (100, 255, 100)
            else:
                profit_text = f"-{self.bet_amount} G"
                profit_color = (255, 100, 100)
            surf, _ = self.fonts["medium"].render(profit_text, profit_color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 140))

        # 총 수익
        if self.fonts and "small" in self.fonts:
            total_text = f"총 수익: {self.total_winnings} G"
            color = (100, 255, 100) if self.total_winnings >= 0 else (255, 100, 100)
            surf, _ = self.fonts["small"].render(total_text, color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 180))

        # 안내
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render("클릭하여 계속", (150, 150, 150))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 220))

    def _draw_round_end_ui(self):
        """라운드 종료 UI (계속/나가기 선택)"""
        # 반투명 오버레이
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        # 패널
        panel_x, panel_y = 150, 200
        panel_w, panel_h = 460, 300
        pygame.draw.rect(self.screen, (35, 40, 50), (panel_x, panel_y, panel_w, panel_h), border_radius=10)
        pygame.draw.rect(self.screen, (100, 180, 255), (panel_x, panel_y, panel_w, panel_h), 3, border_radius=10)

        # 타이틀
        if self.fonts and "large" in self.fonts:
            round_name = "4강" if self.current_round == TournamentRound.QUARTER_FINAL else "결승"
            title = f"{round_name} 진출!"
            surf, _ = self.fonts["large"].render(title, (255, 215, 0))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 30))

        # 현재 수익
        if self.fonts and "medium" in self.fonts:
            profit_text = f"현재 수익: {self.total_winnings} G"
            color = (100, 255, 100) if self.total_winnings >= 0 else (255, 100, 100)
            surf, _ = self.fonts["medium"].render(profit_text, color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 90))

        # 질문
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render("계속해서 배팅하시겠습니까?", (200, 200, 200))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 140))

        # 계속 버튼
        continue_rect = pygame.Rect(panel_x + 40, panel_y + 200, 180, 50)
        pygame.draw.rect(self.screen, (80, 180, 80), continue_rect, border_radius=5)
        if self.fonts and "medium" in self.fonts:
            surf, _ = self.fonts["medium"].render("계속 배팅", (255, 255, 255))
            self.screen.blit(surf, (continue_rect.centerx - surf.get_width() // 2, continue_rect.y + 15))

        # 나가기 버튼
        exit_rect = pygame.Rect(panel_x + 240, panel_y + 200, 180, 50)
        pygame.draw.rect(self.screen, (180, 80, 80), exit_rect, border_radius=5)
        if self.fonts and "medium" in self.fonts:
            surf, _ = self.fonts["medium"].render("수익 확정", (255, 255, 255))
            self.screen.blit(surf, (exit_rect.centerx - surf.get_width() // 2, exit_rect.y + 15))

        # 경고
        if self.fonts and "small" in self.fonts:
            warn_text = "계속하면 다음 라운드에서 질 경우 수익을 잃을 수 있습니다"
            surf, _ = self.fonts["small"].render(warn_text, (255, 180, 100))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 265))

    def _draw_tournament_end_ui(self):
        """토너먼트 종료 UI"""
        # 반투명 오버레이
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 200))
        self.screen.blit(overlay, (0, 0))

        # 패널
        panel_x, panel_y = 180, 200
        panel_w, panel_h = 400, 300
        pygame.draw.rect(self.screen, (35, 40, 50), (panel_x, panel_y, panel_w, panel_h), border_radius=10)
        pygame.draw.rect(self.screen, (255, 215, 0), (panel_x, panel_y, panel_w, panel_h), 3, border_radius=10)

        # 타이틀
        if self.fonts and "large" in self.fonts:
            surf, _ = self.fonts["large"].render("토너먼트 종료!", (255, 215, 0))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 30))

        # 최종 우승자
        final_match = self.matches[TournamentRound.FINAL][0]
        if final_match.winner and self.fonts and "medium" in self.fonts:
            winner_text = f"우승: {final_match.winner['name']}"
            surf, _ = self.fonts["medium"].render(winner_text, final_match.winner["color"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 90))

        # 최종 수익
        if self.fonts and "large" in self.fonts:
            profit_text = f"최종 수익: {self.total_winnings} G"
            color = (100, 255, 100) if self.total_winnings >= 0 else (255, 100, 100)
            surf, _ = self.fonts["large"].render(profit_text, color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 150))

        # 나가기 버튼
        exit_rect = pygame.Rect(panel_x + 100, panel_y + 230, 200, 50)
        pygame.draw.rect(self.screen, (80, 120, 180), exit_rect, border_radius=5)
        if self.fonts and "medium" in self.fonts:
            surf, _ = self.fonts["medium"].render("투기장 나가기", (255, 255, 255))
            self.screen.blit(surf, (exit_rect.centerx - surf.get_width() // 2, exit_rect.y + 15))

    def get_result(self) -> Dict:
        """결과 반환"""
        return {
            "winnings": self.total_winnings,
            "final_gold": self.player_gold + self.total_winnings,
            "completed": self.state == TournamentState.TOURNAMENT_END,
        }


# ============================================================================
# 테스트용 함수
# ============================================================================
def test_arena():
    """투기장 테스트"""
    import pygame
    import pygame.freetype

    pygame.init()
    pygame.freetype.init()

    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("콜로세움 투기장 테스트")
    clock = pygame.time.Clock()

    # 폰트 (테스트용)
    fonts = {}
    try:
        fonts["small"] = pygame.freetype.Font(None, 16)
        fonts["medium"] = pygame.freetype.Font(None, 20)
        fonts["large"] = pygame.freetype.Font(None, 28)
    except Exception as e:
        print(f"Font init error: {e}")

    arena = ColosseumsArena(screen, fonts, 1000)

    running = True
    while running:
        dt = clock.tick(60) / 1000.0

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif arena.handle_event(event):
                running = False

        arena.update(dt)
        arena.draw()
        pygame.display.flip()

    pygame.quit()


if __name__ == "__main__":
    test_arena()
