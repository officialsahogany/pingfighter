# downtown/colosseum_arena.py
# 고대 투기장 토너먼트 시스템

import pygame
import random
import math
import sys
import os
import time
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
BOTTOM_PADDLE_Y = 710       # 하단 패들 Y (플레이어 위치)

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
        "accuracy": 0.85,
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
        "accuracy": 0.85,
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
        "style": HeroStyle.BALANCED,
        "color": (200, 50, 70),  # 진한 빨강
        "speed": 1.2,
        "reaction": 0.9,
        "power": 1.35,
        "accuracy": 0.82,
        "position": "top",
        "description": "지옥에서 온 뿔 달린 도깨비 전사"
    },
]

# 하단 패들 영웅 (hero2 - 화면 아래쪽)
BOTTOM_HEROES = [
    {
        "id": "maria",
        "name": "연화",
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
        "speed": 1.0,
        "reaction": 0.95,
        "power": 1.1,
        "accuracy": 0.85,
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
    VS_PREVIEW = "vs_preview"            # 배틀 전 VS 매치업 미리보기
    BATTLE = "battle"                  # AI 배틀 진행
    RESULT = "result"                  # 경기 결과
    ROUND_END = "round_end"            # 라운드 종료 (계속/나가기 선택)
    GUARD_NOTIFY = "guard_notify"              # 호위무사 생포 알림
    BRACKET_ANIMATION = "bracket_animation"  # 대진표 진출 애니메이션
    VICTORY_CELEBRATION = "victory_celebration"  # 우승 축하 연출
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
        self.width = PADDLE_WIDTH  # 스킬 코드 호환용 (target_paddle.width)
        self.height = PADDLE_HEIGHT  # 스킬 코드 호환용 (target_paddle.height)

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
        self.gravity_drift = 0.0  # 중력 드리프트 (px/s, 중력조절 스킬용)

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

        # 귀신발걸음 (Ghost Step) y축 이동 시스템
        self.ghost_step_active = False  # 귀신발걸음 y축 이동 활성화 여부
        self.ghost_step_y_velocity = 0.0  # y축 이동 속도
        self.ghost_step_speed = 3.0  # 기본 y축 이동 속도 (부드럽게)
        self.ghost_step_max_offset = 120  # 최대 이동 거리 (원위치에서)
        self.ghost_step_phase = 0  # 0: 전진, 1: 복귀
        self.original_y = self.y  # 원래 y 위치 저장

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

        # 귀신발걸음 y축 이동 업데이트
        self.update_ghost_step(dt)

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
                offset = (0.5 - random.random()) * 18 * speed_factor
                self.target_x = self.predicted_x + offset + self.error_offset
            elif self.style == HeroStyle.DEFENSIVE:
                # 수비적: 정확한 중앙 타격
                self.target_x = self.predicted_x + self.error_offset * 0.5
            elif self.style == HeroStyle.TRICKY:
                # 트릭: 예측 불가능한 움직임
                if random.random() < 0.3:
                    offset = random.randint(-25, 25)
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

        # 중력 드리프트 적용 (중력조절 스킬)
        if self.gravity_drift != 0:
            self.x += self.gravity_drift * dt

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

    def start_ghost_step(self):
        """귀신발걸음 y축 이동 시작 (상단→하단, 하단→상단으로 귀신처럼 다가옴)"""
        if self.ghost_step_active:
            return False

        self.ghost_step_active = True
        self.original_y = self.y
        self.ghost_step_phase = 0  # 전진 페이즈

        # 상단 영웅은 아래로 (y 증가), 하단 영웅은 위로 (y 감소)
        if self.is_top:
            self.ghost_step_y_velocity = self.ghost_step_speed  # 아래로
        else:
            self.ghost_step_y_velocity = -self.ghost_step_speed  # 위로

        print(f"[GhostStep] 귀신발걸음 y축 이동 시작! is_top={self.is_top}, 현재 y={self.y}, 방향={'아래' if self.is_top else '위'}")
        return True

    def update_ghost_step(self, dt: float):
        """귀신발걸음 y축 이동 업데이트 (1회 왕복 후 종료)"""
        if not self.ghost_step_active:
            return

        # y축으로 이동
        self.y += self.ghost_step_y_velocity

        # 현재 이동 거리 계산
        current_offset = abs(self.y - self.original_y)

        if self.ghost_step_phase == 0:
            # 전진 페이즈: 최대 거리에 도달하면 복귀로 전환
            if current_offset >= self.ghost_step_max_offset:
                self.ghost_step_phase = 1
                self.ghost_step_y_velocity = -self.ghost_step_y_velocity  # 방향 반전
                print(f"[GhostStep] 전진 완료, 복귀 시작! y={self.y}")
        else:
            # 복귀 페이즈: 원위치에 도달하면 귀신발걸음 종료
            if self.is_top:
                if self.y <= self.original_y:
                    self.end_ghost_step()
                    print(f"[GhostStep] 1회 왕복 완료 → 귀신발걸음 종료")
            else:
                if self.y >= self.original_y:
                    self.end_ghost_step()
                    print(f"[GhostStep] 1회 왕복 완료 → 귀신발걸음 종료")

    def end_ghost_step(self):
        """귀신발걸음 y축 이동 종료 및 원위치 복귀"""
        self.ghost_step_active = False
        self.y = self.original_y
        self.ghost_step_y_velocity = 0.0
        self.ghost_step_phase = 0
        print(f"[GhostStep] 귀신발걸음 종료, y={self.y}로 복귀")

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
        self.wall_bounced = False  # 벽 반사 감지 플래그

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
        self.wall_bounced = False

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

        self.wall_bounced = False  # 매 프레임 초기화
        if self.x <= left_wall:
            self.x = left_wall
            self.vx = abs(self.vx) * WALL_BOUNCE_SLOWDOWN
            self.wall_bounced = True
        elif self.x >= right_wall:
            self.x = right_wall
            self.vx = -abs(self.vx) * WALL_BOUNCE_SLOWDOWN
            self.wall_bounced = True

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
# 호위무사 시스템 (Guard Warrior System)
# ============================================================================
# 애니메이션 타이밍 상수
GUARD_ENTER_DURATION = 0.6    # 등장 시간 (초)
GUARD_CAST_DURATION = 0.8     # 시전 포즈 시간
GUARD_EXIT_DURATION = 0.5     # 퇴장 시간


class _GuardPaddle:
    """호위무사 위치를 패들처럼 사용하기 위한 가상 패들 객체"""
    def __init__(self, x, y, is_top, width=60, height=30):
        self.x = x - width // 2  # centerx → left x
        self.y = y
        self.width = width
        self.height = height
        self.centerx = x
        self.centery = y + height // 2
        self.is_top = is_top
        self.paddle_scale = 1.0


class GuardWarriorSystem:
    """호위무사 시스템 - 4강/결승에서 패배 영웅이 승자를 돕는 시스템

    사용법:
        1. setup(guards_top, guards_bottom) 으로 호위무사 할당
        2. 매 프레임 update(dt, top_paddle, bottom_paddle, ball) 호출
        3. 매 프레임 draw(screen, ...) 호출
        4. 배틀 종료 시 reset() 호출
    """

    def __init__(self, skill_manager=None, hero_paddle_renderer=None):
        self.skill_manager = skill_manager
        self.hero_paddle_renderer = hero_paddle_renderer

        # 호위무사 목록
        self.guard_warriors_top = []       # 상단 영웅의 호위무사들 [hero_dict, ...]
        self.guard_warriors_bottom = []    # 하단 영웅의 호위무사들

        # 쿨타임
        self.cooldown_top = 0.0
        self.cooldown_bottom = 0.0
        self.cooldown_range = (20.0, 30.0)  # 20~30초 랜덤

        # 등장 애니메이션 상태 (상단측)
        self.active_top = None             # 현재 등장 중인 호위무사 hero dict
        self.phase_top = None              # "entering" / "casting" / "exiting" / None
        self.anim_timer_top = 0.0
        self.x_top = 0.0                   # 현재 X 위치
        self.side_top = "left"             # 등장 방향
        self.selected_skill_top = None     # 선택된 스킬 인스턴스

        # 등장 애니메이션 상태 (하단측)
        self.active_bottom = None
        self.phase_bottom = None
        self.anim_timer_bottom = 0.0
        self.x_bottom = 0.0
        self.side_bottom = "right"
        self.selected_skill_bottom = None

        # 독립 스킬 인스턴스 (메인 스킬과 충돌 방지)
        self.skill_instances = {}          # hero_id -> [skill1, skill2]

        # 호위무사별 마지막 가상 패들 (스킬 이펙트 진행 중 위치 유지용)
        self.guard_paddles = {}            # hero_id -> _GuardPaddle

        # Y 위치 추적 (horn_charge 등에서 Y 이동 필요)
        self.y_top = 120              # 상단 호위무사 현재 Y
        self.y_bottom = 630           # 하단 호위무사 현재 Y
        self._enter_x_top = 0.0      # 등장 완료 시 X 위치 (horn_charge 기준점)
        self._enter_x_bottom = 0.0
        self._exit_start_x_top = 0.0  # 퇴장 시작 시 X 위치
        self._exit_start_y_top = 120.0
        self._exit_start_x_bottom = 0.0
        self._exit_start_y_bottom = 630.0

        # 호위무사 귀신발걸음 공 충돌 (1회 발동당 3회까지 허용)
        self._guard_ghost_step_hit_top = 0       # 상단 호위무사 이번 발동 충돌 횟수
        self._guard_ghost_step_hit_bottom = 0    # 하단 호위무사 이번 발동 충돌 횟수
        self._guard_ghost_step_max_hits = 3      # 최대 충돌 횟수
        self._guard_ball_cooldown = 0.0          # 연속 충돌 방지 쿨다운

        # 호위무사 말풍선 시스템
        self._bubble_top = None    # {'text': str, 'timer': float}
        self._bubble_bottom = None
        self._bubble_duration = 2.0  # 말풍선 표시 시간 (초)

    def setup(self, guards_top, guards_bottom, initial_delay=(10.0, 15.0)):
        """배틀 시작 시 호위무사 설정

        Args:
            guards_top: 상단 영웅의 호위무사 목록
            guards_bottom: 하단 영웅의 호위무사 목록
            initial_delay: 첫 등장까지의 대기 시간 범위 (초)
        """
        self.guard_warriors_top = list(guards_top) if guards_top else []
        self.guard_warriors_bottom = list(guards_bottom) if guards_bottom else []

        # 쿨타임 초기화 (첫 등장은 약간 더 빠르게)
        if self.guard_warriors_top:
            self.cooldown_top = random.uniform(*initial_delay)
        if self.guard_warriors_bottom:
            self.cooldown_bottom = random.uniform(*initial_delay)

        # 애니메이션 상태 초기화
        self.active_top = None
        self.active_bottom = None
        self.phase_top = None
        self.phase_bottom = None
        self.y_top = 120
        self.y_bottom = 630

        # 호위무사 스킬 인스턴스 생성
        self._init_guard_skills()

        guard_names_top = [g["name"] for g in self.guard_warriors_top]
        guard_names_bottom = [g["name"] for g in self.guard_warriors_bottom]
        print(f"[Guard] 호위무사 설정 완료 | 상단: {guard_names_top} | 하단: {guard_names_bottom}")

    def _init_guard_skills(self):
        """호위무사 전용 스킬 인스턴스 생성 (메인 스킬과 독립)"""
        self.skill_instances = {}
        all_guards = self.guard_warriors_top + self.guard_warriors_bottom
        for guard_hero in all_guards:
            hero_id = guard_hero["id"]
            if hero_id not in self.skill_instances:
                try:
                    from downtown.hero_skills import HERO_SKILL_CLASSES
                    skill_classes = HERO_SKILL_CLASSES.get(hero_id, [])
                    skills = [cls() for cls in skill_classes]
                    # game_state 연결 (메인 스킬 매니저와 공유)
                    game_state = self.skill_manager.game_state if self.skill_manager else {}
                    for skill in skills:
                        skill.game_state = game_state
                    self.skill_instances[hero_id] = skills
                    print(f"[Guard] {guard_hero['name']}({hero_id}) 스킬 인스턴스 생성: {[s.korean_name for s in skills]}")
                except Exception as e:
                    print(f"[Guard] 스킬 인스턴스 생성 실패 ({hero_id}): {e}")
                    self.skill_instances[hero_id] = []

    def update(self, dt, top_paddle, bottom_paddle, ball):
        """매 프레임 호위무사 시스템 업데이트"""
        if not self.guard_warriors_top and not self.guard_warriors_bottom:
            return

        # 말풍선 타이머 감소
        if self._bubble_top and self._bubble_top['timer'] > 0:
            self._bubble_top['timer'] -= dt
        if self._bubble_bottom and self._bubble_bottom['timer'] > 0:
            self._bubble_bottom['timer'] -= dt

        game_state = self.skill_manager.game_state if self.skill_manager else {}

        # 🔥 호위무사 귀신발걸음 공 충돌 감지 (1회 발동당 3회까지)
        if self._guard_ball_cooldown > 0:
            self._guard_ball_cooldown -= dt
        if ball and self._guard_ball_cooldown <= 0:
            self._check_guard_demon_step_ball_collision(ball, game_state)

        # 활성 호위무사 스킬 이펙트 업데이트 (호위무사 위치 기반)
        for hero_id, skills in self.skill_instances.items():
            # 이 호위무사가 어느 쪽인지 판별
            is_top_guard = any(g["id"] == hero_id for g in self.guard_warriors_top)
            # 호위무사 가상 패들 사용 (저장된 위치)
            guard_paddle = self.guard_paddles.get(hero_id)
            if guard_paddle is None:
                guard_paddle = top_paddle if is_top_guard else bottom_paddle
            target = bottom_paddle if is_top_guard else top_paddle
            for skill in skills:
                if skill.is_active:
                    skill_id = getattr(skill, 'skill_id', '')
                    # 드래곤 브레스: 공을 따라다니며 화염 발사
                    if skill_id == 'dragon_breath' and ball:
                        guard_paddle.x = ball.x - guard_paddle.width // 2
                        guard_paddle.centerx = ball.x
                    # 귀신발걸음: 현재 호위무사 위치로 동기화 (X + Y)
                    elif skill_id == 'demon_step':
                        gx = self.x_top if is_top_guard else self.x_bottom
                        gy = self.y_top if is_top_guard else self.y_bottom
                        guard_paddle.x = gx - guard_paddle.width // 2
                        guard_paddle.centerx = gx
                        guard_paddle.y = gy
                        guard_paddle.centery = gy + guard_paddle.height // 2
                    # caster 측 game_state 보호 (호위무사 스킬이 메인 영웅에 영향 방지)
                    caster_prefix = 'top_paddle' if is_top_guard else 'bottom_paddle'
                    saved = self._save_caster_state(game_state, caster_prefix)
                    skill.update(dt, guard_paddle, target, ball, game_state)
                    self._restore_caster_state(game_state, caster_prefix, saved)
                    # 스킬별 글로벌 game_state 키 차단 (메인 영웅에 영향 방지)
                    if skill_id == 'horn_charge':
                        game_state['horn_charge_active'] = False
                    elif skill_id == 'demon_step':
                        game_state['demon_eye_active'] = False
                        game_state.pop('ghost_step_start_top', None)
                        game_state.pop('ghost_step_start_bottom', None)
                    # OilSpill: 발사체/웅덩이가 모두 소진되면 비활성화
                    elif skill_id == 'oil_spill':
                        if not skill.oil_projectiles and not skill.oil_puddles:
                            skill.is_active = False

        # 상단측 호위무사 업데이트
        self._update_side(dt, is_top=True, top_paddle=top_paddle,
                          bottom_paddle=bottom_paddle, ball=ball)

        # 하단측 호위무사 업데이트
        self._update_side(dt, is_top=False, top_paddle=top_paddle,
                          bottom_paddle=bottom_paddle, ball=ball)

    def _update_side(self, dt, is_top, top_paddle, bottom_paddle, ball):
        """한 쪽의 호위무사 업데이트"""
        guards = self.guard_warriors_top if is_top else self.guard_warriors_bottom
        if not guards:
            return

        # 현재 애니메이션 진행 중이면 애니메이션 처리
        phase = self.phase_top if is_top else self.phase_bottom
        if phase:
            self._update_animation(dt, is_top, top_paddle, bottom_paddle, ball)
            return

        # 쿨타임 감소
        if is_top:
            self.cooldown_top -= dt
            if self.cooldown_top <= 0:
                self._trigger(is_top=True)
        else:
            self.cooldown_bottom -= dt
            if self.cooldown_bottom <= 0:
                self._trigger(is_top=False)

    def _trigger(self, is_top):
        """호위무사 등장 트리거"""
        guards = self.guard_warriors_top if is_top else self.guard_warriors_bottom
        if not guards:
            return

        # 결승전: 2명 중 1명 랜덤 / 4강: 1명 고정
        guard = random.choice(guards)

        # 스킬 2개 중 1개 랜덤 선택
        skills = self.skill_instances.get(guard["id"], [])
        if not skills:
            # 스킬이 없으면 다음 쿨타임 설정 후 리턴
            next_cd = random.uniform(*self.cooldown_range)
            if is_top:
                self.cooldown_top = next_cd
            else:
                self.cooldown_bottom = next_cd
            return
        skill = random.choice(skills)

        # 등장 방향 랜덤
        side = random.choice(["left", "right"])
        start_x = (GAME_AREA_X - 60) if side == "left" else (GAME_AREA_X + GAME_AREA_WIDTH + 60)

        if is_top:
            self.active_top = guard
            self.phase_top = "entering"
            self.anim_timer_top = 0.0
            self.x_top = start_x
            self.side_top = side
            self.selected_skill_top = skill
        else:
            self.active_bottom = guard
            self.phase_bottom = "entering"
            self.anim_timer_bottom = 0.0
            self.x_bottom = start_x
            self.side_bottom = side
            self.selected_skill_bottom = skill

        # 다음 쿨타임 설정
        next_cd = random.uniform(*self.cooldown_range)
        if is_top:
            self.cooldown_top = next_cd
        else:
            self.cooldown_bottom = next_cd

        print(f"[Guard] {'상단' if is_top else '하단'}측 호위무사 {guard['name']} 등장! "
              f"스킬: {skill.korean_name} | 방향: {side}")

    def _update_animation(self, dt, is_top, top_paddle, bottom_paddle, ball):
        """호위무사 등장/시전/퇴장 애니메이션"""
        if is_top:
            self.anim_timer_top += dt
            timer = self.anim_timer_top
            phase = self.phase_top
            side = self.side_top
        else:
            self.anim_timer_bottom += dt
            timer = self.anim_timer_bottom
            phase = self.phase_bottom
            side = self.side_bottom

        # 목표 좌표 계산
        if side == "left":
            target_x = GAME_AREA_X + 50
            exit_x = GAME_AREA_X - 60
            start_x = GAME_AREA_X - 60
        else:
            target_x = GAME_AREA_X + GAME_AREA_WIDTH - 50
            exit_x = GAME_AREA_X + GAME_AREA_WIDTH + 60
            start_x = GAME_AREA_X + GAME_AREA_WIDTH + 60

        if phase == "entering":
            progress = min(1.0, timer / GUARD_ENTER_DURATION)
            eased = self._ease_in_out(progress)
            current_x = start_x + (target_x - start_x) * eased

            if is_top:
                self.x_top = current_x
            else:
                self.x_bottom = current_x

            if progress >= 1.0:
                # 등장 완료 → 시전 단계 (등장 완료 X 저장)
                if is_top:
                    self.phase_top = "casting"
                    self.anim_timer_top = 0.0
                    self._enter_x_top = self.x_top
                else:
                    self.phase_bottom = "casting"
                    self.anim_timer_bottom = 0.0
                    self._enter_x_bottom = self.x_bottom
                # 스킬 발동!
                self._activate_skill(is_top, top_paddle, bottom_paddle, ball)

        elif phase == "casting":
            skill = self.selected_skill_top if is_top else self.selected_skill_bottom
            skill_id = getattr(skill, 'skill_id', '') if skill else ''

            # === 드래곤 브레스: 시전 중 공의 X좌표를 따라감 ===
            if skill_id == 'dragon_breath' and ball:
                bx = max(GAME_AREA_X + 30, min(ball.x, GAME_AREA_X + GAME_AREA_WIDTH - 30))
                if is_top:
                    self.x_top = bx
                else:
                    self.x_bottom = bx
                target_x = bx

            # === 뿔 박치기: 오니마루가 직접 돌진/복귀 ===
            elif skill_id == 'horn_charge' and skill and skill.is_active:
                base_y = 120 if is_top else 630
                enter_x = self._enter_x_top if is_top else self._enter_x_bottom
                skill_target_x = getattr(skill, 'target_x', enter_x)
                skill_impact_y = getattr(skill, 'impact_y', base_y)

                if skill.phase == skill.PHASE_CHARGING:
                    p = getattr(skill, 'charge_progress', 0) ** 2  # 이징(가속)
                    vy = base_y + (skill_impact_y - base_y) * p
                    vx = enter_x + (skill_target_x - enter_x) * p
                elif skill.phase == skill.PHASE_IMPACT:
                    vy = skill_impact_y
                    vx = skill_target_x
                elif skill.phase == skill.PHASE_RETURNING:
                    p = 1 - (1 - getattr(skill, 'return_progress', 0)) ** 2  # 이징(감속)
                    vy = skill_impact_y + (base_y - skill_impact_y) * p
                    vx = skill_target_x + (enter_x - skill_target_x) * p
                else:  # STUN
                    vy = base_y
                    vx = enter_x

                if is_top:
                    self.x_top = vx
                    self.y_top = vy
                else:
                    self.x_bottom = vx
                    self.y_bottom = vy
                return  # 타이머 기반 퇴장 안 함 - 스킬 종료 시 자동 퇴장

            # === 촉수 휘감기: 크라켄이 촉수휘감기가 끝날 때까지 대기 후 퇴장 ===
            elif skill_id == 'tentacle_wrap' and skill and skill.is_active:
                # 촉수휘감기 활성 상태 → 현재 위치에서 대기 (타이머 기반 퇴장 안 함)
                return

            elif skill_id == 'tentacle_wrap' and skill and not skill.is_active:
                # 촉수휘감기 종료 → 퇴장 전환
                if is_top:
                    self._exit_start_x_top = self.x_top
                    self._exit_start_y_top = self.y_top
                    self.phase_top = "exiting"
                    self.anim_timer_top = 0.0
                else:
                    self._exit_start_x_bottom = self.x_bottom
                    self._exit_start_y_bottom = self.y_bottom
                    self.phase_bottom = "exiting"
                    self.anim_timer_bottom = 0.0
                return

            # === 귀신발걸음: 무겐이 공을 따라다니며 상대 진영으로 전진/복귀 ===
            elif skill_id == 'demon_step' and skill and skill.is_active:
                # X축: 공을 따라감
                if ball:
                    bx = max(GAME_AREA_X + 30, min(ball.x, GAME_AREA_X + GAME_AREA_WIDTH - 30))
                    if is_top:
                        self.x_top = bx
                    else:
                        self.x_bottom = bx
                    target_x = bx

                # Y축: 상대 진영으로 전진(0~2초) → 복귀(2~4초)
                DEMON_STEP_GUARD_DURATION = 4.0
                FORWARD_DURATION = DEMON_STEP_GUARD_DURATION / 2  # 2초 전진
                base_y = 120 if is_top else 630
                # 상대 진영 끝까지 이동 (상단→화면 하단 700, 하단→화면 상단 50)
                dest_y = 700 if is_top else 50

                if timer < FORWARD_DURATION:
                    # 전진 페이즈: base_y → dest_y
                    progress = timer / FORWARD_DURATION
                    eased = self._ease_in_out(progress)
                    current_y = base_y + (dest_y - base_y) * eased
                else:
                    # 복귀 페이즈: dest_y → base_y
                    progress = min(1.0, (timer - FORWARD_DURATION) / (DEMON_STEP_GUARD_DURATION - FORWARD_DURATION))
                    eased = self._ease_in_out(progress)
                    current_y = dest_y + (base_y - dest_y) * eased

                if is_top:
                    self.y_top = current_y
                else:
                    self.y_bottom = current_y

                # 4초 후 강제 종료
                if timer >= DEMON_STEP_GUARD_DURATION:
                    skill.is_active = False
                    skill.aura_particles = []
                    game_state = self.skill_manager.game_state if self.skill_manager else {}
                    game_state['demon_eye_active'] = False
                    # 공 충돌 횟수 카운터 리셋 (1회 발동당 3회까지)
                    if is_top:
                        self._guard_ghost_step_hit_top = 0
                    else:
                        self._guard_ghost_step_hit_bottom = 0
                    # 퇴장 전환
                    if is_top:
                        self._exit_start_x_top = self.x_top
                        self._exit_start_y_top = self.y_top
                        self.phase_top = "exiting"
                        self.anim_timer_top = 0.0
                    else:
                        self._exit_start_x_bottom = self.x_bottom
                        self._exit_start_y_bottom = self.y_bottom
                        self.phase_bottom = "exiting"
                        self.anim_timer_bottom = 0.0
                return  # 타이머 기반 퇴장 안 함

            # === 기본: 시전 시간 후 퇴장 ===
            if timer >= GUARD_CAST_DURATION:
                if is_top:
                    self._exit_start_x_top = self.x_top
                    self._exit_start_y_top = self.y_top
                    self.phase_top = "exiting"
                    self.anim_timer_top = 0.0
                else:
                    self._exit_start_x_bottom = self.x_bottom
                    self._exit_start_y_bottom = self.y_bottom
                    self.phase_bottom = "exiting"
                    self.anim_timer_bottom = 0.0

        elif phase == "exiting":
            progress = min(1.0, timer / GUARD_EXIT_DURATION)
            eased = self._ease_in_out(progress)
            # 퇴장 시작 위치에서 화면 밖으로 이동
            es_x = self._exit_start_x_top if is_top else self._exit_start_x_bottom
            es_y = self._exit_start_y_top if is_top else self._exit_start_y_bottom
            base_y = 120 if is_top else 630
            current_x = es_x + (exit_x - es_x) * eased
            current_y = es_y + (base_y - es_y) * eased  # Y는 기본 위치로 복귀

            if is_top:
                self.x_top = current_x
                self.y_top = current_y
            else:
                self.x_bottom = current_x
                self.y_bottom = current_y

            if progress >= 1.0:
                # 퇴장 완료 → 초기화
                if is_top:
                    self.phase_top = None
                    self.active_top = None
                    self.selected_skill_top = None
                    self.y_top = 120
                else:
                    self.phase_bottom = None
                    self.active_bottom = None
                    self.selected_skill_bottom = None
                    self.y_bottom = 630

    def _make_guard_paddle(self, is_top):
        """현재 호위무사 위치로 가상 패들 생성"""
        if is_top:
            gx = self.x_top
            gy = self.y_top  # 추적된 Y 위치 사용
        else:
            gx = self.x_bottom
            gy = self.y_bottom  # 추적된 Y 위치 사용
        gp = _GuardPaddle(gx, gy, is_top)
        # hero_id로 저장 (스킬 이펙트 진행 중 위치 유지)
        guard = self.active_top if is_top else self.active_bottom
        if guard:
            self.guard_paddles[guard["id"]] = gp
        return gp

    def _check_guard_demon_step_ball_collision(self, ball, game_state):
        """호위무사 귀신발걸음 중 공과 충돌 감지 → game_state 플래그 설정 (1회 발동당 3회까지)"""
        import pygame
        GUARD_PADDLE_W, GUARD_PADDLE_H = 60, 30

        for hero_id, skills in self.skill_instances.items():
            is_top_guard = any(g["id"] == hero_id for g in self.guard_warriors_top)
            for skill in skills:
                if not skill.is_active:
                    continue
                skill_id = getattr(skill, 'skill_id', '')
                if skill_id != 'demon_step':
                    continue

                # 이번 발동에서 최대 횟수 도달했으면 스킵
                hit_count = self._guard_ghost_step_hit_top if is_top_guard else self._guard_ghost_step_hit_bottom
                if hit_count >= self._guard_ghost_step_max_hits:
                    continue

                # 현재 호위무사 위치로 충돌 rect 생성
                gx = self.x_top if is_top_guard else self.x_bottom
                gy = self.y_top if is_top_guard else self.y_bottom
                guard_rect = pygame.Rect(
                    int(gx - GUARD_PADDLE_W // 2), int(gy),
                    GUARD_PADDLE_W, GUARD_PADDLE_H
                )
                ball_rect = pygame.Rect(int(ball.x), int(ball.y),
                                        getattr(ball, 'width', 20),
                                        getattr(ball, 'height', 20))

                if guard_rect.colliderect(ball_rect):
                    # 공이 올바른 방향으로 오는지 확인
                    ball_vy = getattr(ball, 'vy', 0)
                    if is_top_guard and ball_vy >= 0:
                        continue
                    if not is_top_guard and ball_vy <= 0:
                        continue

                    # 충돌! 횟수 증가
                    if is_top_guard:
                        self._guard_ghost_step_hit_top += 1
                    else:
                        self._guard_ghost_step_hit_bottom += 1
                    self._guard_ball_cooldown = 0.3  # 연속 충돌 방지 쿨다운

                    hit_offset = (ball_rect.centerx - guard_rect.centerx) / (GUARD_PADDLE_W / 2)
                    game_state['guard_demon_step_ball_hit'] = {
                        'is_top_guard': is_top_guard,
                        'hit_offset': hit_offset,
                    }
                    print(f"[Guard GhostStep] 호위무사 공 충돌 (1회)! is_top={is_top_guard}, offset={hit_offset:.2f}")
                    return

    # 호위무사 스킬이 game_state를 통해 메인 영웅에 영향주는 것 방지용 키 목록
    _CASTER_STATE_KEYS = ['_locked', '_locked_x', '_locked_y', '_stunned', '_speed_boost', '_size_boost']

    def _save_caster_state(self, game_state, caster_prefix):
        """스킬 호출 전 caster 측 game_state 백업"""
        saved = {}
        for suffix in self._CASTER_STATE_KEYS:
            key = f'{caster_prefix}{suffix}'
            if key in game_state:
                saved[key] = game_state[key]
        return saved

    def _restore_caster_state(self, game_state, caster_prefix, saved):
        """스킬 호출 후 caster 측 game_state 복원 (호위무사가 변경한 것 되돌림)"""
        for suffix in self._CASTER_STATE_KEYS:
            key = f'{caster_prefix}{suffix}'
            if key in saved:
                game_state[key] = saved[key]
            else:
                # 스킬이 새로 추가한 키는 제거
                game_state.pop(key, None)

    def _activate_skill(self, is_top, top_paddle, bottom_paddle, ball):
        """호위무사 스킬 실제 발동 (호위무사 위치에서 직접 시전)"""
        skill = self.selected_skill_top if is_top else self.selected_skill_bottom
        guard = self.active_top if is_top else self.active_bottom
        if not skill or not guard:
            return

        game_state = self.skill_manager.game_state if self.skill_manager else {}

        # 호위무사 위치의 가상 패들을 caster로 사용
        guard_paddle = self._make_guard_paddle(is_top)
        # 드래곤 브레스: 공 위치에서 발동 시작
        if getattr(skill, 'skill_id', '') == 'dragon_breath' and ball:
            guard_paddle.x = ball.x - guard_paddle.width // 2
            guard_paddle.centerx = ball.x
        # 상대편이 target
        target_paddle = bottom_paddle if is_top else top_paddle

        # 스킬에 caster_is_top 설정 (위치 계산용)
        skill.caster_is_top = is_top

        # 스킬 직접 발동 (쿨타임 무시 - 호위무사 자체 쿨타임 사용)
        skill.current_cooldown = 0  # 강제 쿨타임 리셋
        if skill.is_active:
            # 이전 효과가 아직 진행 중이면 먼저 종료
            try:
                skill._end_effect(guard_paddle, target_paddle, ball, game_state)
            except Exception:
                pass
            skill.is_active = False

        # caster 측 game_state 보호 (호위무사 스킬이 메인 영웅에 영향 방지)
        caster_prefix = 'top_paddle' if is_top else 'bottom_paddle'
        saved = self._save_caster_state(game_state, caster_prefix)
        result = skill.use(guard_paddle, target_paddle, ball, game_state)
        self._restore_caster_state(game_state, caster_prefix, saved)

        # 스킬별 글로벌 game_state 키 차단 (메인 영웅에 영향 방지)
        skill_id = getattr(skill, 'skill_id', '')
        if skill_id == 'horn_charge':
            game_state['horn_charge_active'] = False
        elif skill_id == 'demon_step':
            game_state['demon_eye_active'] = False
            game_state.pop('ghost_step_start_top', None)
            game_state.pop('ghost_step_start_bottom', None)

        # duration=0 스킬 (OilSpill 등)은 use()에서 is_active가 안 켜짐 → 수동 활성화
        # (호위무사 update/draw 루프가 is_active 기반이므로 필요)
        if result and not skill.is_active and skill.duration <= 0:
            skill.is_active = True

        if result:
            # 상태 효과를 game_state에 적용 (try_use_skill과 동일한 로직)
            self._apply_status_effects(result, target_paddle)

            print(f"[Guard] {'상단' if is_top else '하단'}측 호위무사 {guard['name']} → "
                  f"{skill.korean_name} 발동 성공! (위치: x={guard_paddle.centerx:.0f})")
        else:
            print(f"[Guard] {'상단' if is_top else '하단'}측 호위무사 {guard['name']} → "
                  f"{skill.korean_name} 발동 실패")

        # 말풍선 직접 설정 (호위무사 위치에 표시)
        bubble_text = f"{guard['name']}: {skill.korean_name}!"
        bubble_data = {'text': bubble_text, 'timer': self._bubble_duration}
        if is_top:
            self._bubble_top = bubble_data
        else:
            self._bubble_bottom = bubble_data

    def _apply_status_effects(self, result, target_paddle):
        """스킬 결과에서 상태 효과를 game_state에 적용"""
        if not result or not self.skill_manager:
            return

        game_state = self.skill_manager.game_state
        target_prefix = 'top_paddle' if target_paddle.is_top else 'bottom_paddle'

        from downtown.hero_skills import StatusEffect, ScreenEffect

        if result.get('target_status'):
            status = result['target_status']
            if status == StatusEffect.STUN:
                game_state[f'{target_prefix}_stunned'] = True
            elif status == StatusEffect.SLOW:
                game_state[f'{target_prefix}_slowed'] = True
                game_state[f'{target_prefix}_slow_amount'] = result.get('slow_amount', 0.5)
            elif status == StatusEffect.CONFUSION:
                game_state[f'{target_prefix}_confused'] = True
            elif status == StatusEffect.SHRINK:
                game_state[f'{target_prefix}_shrink'] = True
                game_state[f'{target_prefix}_shrink_scale'] = result.get('shrink_amount', 0.5)
            elif status == StatusEffect.BLIND:
                game_state['blind_target_is_top'] = target_paddle.is_top

        # 화면 효과
        if 'screen_effect' in result and self.skill_manager:
            self.skill_manager.screen_effects.append({
                'type': result['screen_effect'],
                'duration': result.get('flash_duration', 0.3),
                'color': result.get('flash_color', (255, 255, 255)),
                'intensity': result.get('shake_intensity', 0)
            })

    def draw(self, screen, top_paddle=None, bottom_paddle=None, ball=None,
             shake_x=0, shake_y=0):
        """호위무사 캐릭터 및 스킬 이펙트 그리기"""
        game_state = self.skill_manager.game_state if self.skill_manager else {}

        # 호위무사 스킬 이펙트 그리기 (호위무사 위치 기반)
        for hero_id, skills in self.skill_instances.items():
            is_top_guard = any(g["id"] == hero_id for g in self.guard_warriors_top)
            guard_paddle = self.guard_paddles.get(hero_id)
            if guard_paddle is None:
                guard_paddle = top_paddle if is_top_guard else bottom_paddle
            target = bottom_paddle if is_top_guard else top_paddle
            for skill in skills:
                if skill.is_active and hasattr(skill, 'draw'):
                    try:
                        # 귀신발걸음: draw 전에 현재 호위무사 위치로 동기화
                        skill_id = getattr(skill, 'skill_id', '')
                        if skill_id == 'demon_step' and guard_paddle:
                            gx = self.x_top if is_top_guard else self.x_bottom
                            gy = self.y_top if is_top_guard else self.y_bottom
                            guard_paddle.x = gx - guard_paddle.width // 2
                            guard_paddle.centerx = gx
                            guard_paddle.y = gy
                            guard_paddle.centery = gy + guard_paddle.height // 2
                        skill.draw(screen, guard_paddle, target, ball, game_state)
                    except Exception:
                        pass

        # 상단측 호위무사 캐릭터
        if self.active_top and self.phase_top:
            self._draw_guard(screen, self.active_top,
                             self.x_top + shake_x, self.y_top + shake_y,
                             is_top=True)

        # 하단측 호위무사 캐릭터
        if self.active_bottom and self.phase_bottom:
            self._draw_guard(screen, self.active_bottom,
                             self.x_bottom + shake_x, self.y_bottom + shake_y,
                             is_top=False)

        # 호위무사 말풍선 그리기
        self._draw_guard_bubbles(screen, shake_x, shake_y)

    def _draw_guard_bubbles(self, screen, shake_x, shake_y):
        """호위무사 스킬 발동 시 말풍선 표시"""
        # 상단측 호위무사 말풍선
        if (self._bubble_top and self._bubble_top['timer'] > 0
                and self.phase_top is not None):
            bx = self.x_top + shake_x
            by = self.y_top + shake_y + 40  # 캐릭터 아래에 표시
            alpha = min(255, int(self._bubble_top['timer'] / 0.3 * 255))
            self._draw_guard_speech(screen, bx, by, self._bubble_top['text'], alpha)

        # 하단측 호위무사 말풍선
        if (self._bubble_bottom and self._bubble_bottom['timer'] > 0
                and self.phase_bottom is not None):
            bx = self.x_bottom + shake_x
            by = self.y_bottom + shake_y - 45  # 캐릭터 위에 표시
            alpha = min(255, int(self._bubble_bottom['timer'] / 0.3 * 255))
            self._draw_guard_speech(screen, bx, by, self._bubble_bottom['text'], alpha)

    def _draw_guard_speech(self, screen, x, y, text, alpha=255):
        """호위무사 말풍선 렌더링"""
        try:
            font = self._get_guard_korean_font(16)
            text_surf = font.render(text, True, (255, 255, 255))
            tw, th = text_surf.get_size()

            pad_x, pad_y = 10, 6
            bw = tw + pad_x * 2
            bh = th + pad_y * 2

            # 화면 경계 제한
            bx = max(GAME_AREA_X + 5, min(int(x - bw // 2), GAME_AREA_X + GAME_AREA_WIDTH - bw - 5))
            by = int(y - bh // 2)

            # 말풍선 서피스 (반투명)
            bubble_surf = pygame.Surface((bw, bh), pygame.SRCALPHA)
            a = min(alpha, 220)
            pygame.draw.rect(bubble_surf, (30, 20, 50, a), bubble_surf.get_rect(), border_radius=8)
            pygame.draw.rect(bubble_surf, (200, 170, 80, a), bubble_surf.get_rect(), width=2, border_radius=8)

            # 텍스트
            text_a_surf = text_surf.copy()
            if alpha < 255:
                text_a_surf.set_alpha(alpha)
            bubble_surf.blit(text_a_surf, (pad_x, pad_y))

            screen.blit(bubble_surf, (bx, by))
        except Exception:
            pass

    def _draw_guard(self, screen, guard_hero, x, y, is_top):
        """단일 호위무사 캐릭터 렌더링"""
        ix, iy = int(x), int(y)
        color = guard_hero.get("color", (200, 200, 200))

        # 글로우 효과 (반투명 원)
        glow_surf = pygame.Surface((80, 80), pygame.SRCALPHA)
        glow_alpha = 60
        # 시전 중이면 글로우 강화
        phase = self.phase_top if is_top else self.phase_bottom
        if phase == "casting":
            glow_alpha = 120
        pygame.draw.circle(glow_surf, (*color, glow_alpha), (40, 40), 40)
        screen.blit(glow_surf, (ix - 40, iy - 40))

        # 영웅 캐릭터 그리기
        if self.hero_paddle_renderer:
            facing = "down" if is_top else "up"
            try:
                self.hero_paddle_renderer.draw_hero_paddle(
                    screen,
                    guard_hero["id"],
                    ix, iy,
                    60, 30,  # 약간 작은 크기
                    facing=facing,
                    color=color,
                    scale_mode="paddle"
                )
            except Exception:
                # 폴백: 간단한 원형
                pygame.draw.circle(screen, color, (ix, iy), 20)
        else:
            # 폴백: 간단한 원형 + 테두리
            pygame.draw.circle(screen, color, (ix, iy), 20)
            pygame.draw.circle(screen, (255, 255, 255), (ix, iy), 20, 2)

        # 호위무사 이름 표시
        try:
            name_font = self._get_guard_korean_font(14)
            name_surf = name_font.render(guard_hero.get("name", "?"), True, (255, 255, 255))
            name_rect = name_surf.get_rect(centerx=ix, top=iy + 28)
            # 배경 박스
            bg_rect = name_rect.inflate(8, 4)
            bg_surf = pygame.Surface((bg_rect.width, bg_rect.height), pygame.SRCALPHA)
            pygame.draw.rect(bg_surf, (0, 0, 0, 150), bg_surf.get_rect(), border_radius=3)
            screen.blit(bg_surf, bg_rect)
            screen.blit(name_surf, name_rect)
        except Exception:
            pass

    def _get_guard_korean_font(self, size=14):
        """호위무사 UI용 한글 폰트 (캐싱)"""
        cache_key = f"_guard_font_{size}"
        cached = getattr(self, cache_key, None)
        if cached:
            return cached
        try:
            import os, sys
            if hasattr(sys, '_MEIPASS'):
                base = sys._MEIPASS
            else:
                base = os.path.dirname(os.path.dirname(__file__))
            # Pretendard 폰트 우선 시도 (프로젝트에 포함된 한글 폰트)
            font_candidates = [
                os.path.join(base, "fonts", "프리텐다드", "public", "static", "alternative", "Pretendard-Bold.ttf"),
                os.path.join(base, "fonts", "프리텐다드", "public", "static", "alternative", "Pretendard-Regular.ttf"),
                os.path.join(base, "fonts", "프리텐다드", "public", "static", "Pretendard-Bold.otf"),
                os.path.join(base, "fonts", "NanumSquareB.ttf"),
            ]
            for fp in font_candidates:
                if os.path.exists(fp):
                    font = pygame.font.Font(fp, size)
                    setattr(self, cache_key, font)
                    return font
        except Exception:
            pass
        font = pygame.font.Font(None, size)
        setattr(self, cache_key, font)
        return font

    def draw_guard_icons(self, screen, game_offset_x=0, game_offset_y=0, game_scale=1.0, fonts=None):
        """필러 배경(관중석) 위에 호위무사 캐릭터 이미지 UI 표시
        screen: REAL_SCREEN (전체화면 서피스)
        game_offset_x/y: 게임 영역의 REAL_SCREEN 내 오프셋
        game_scale: 게임 스케일 팩터
        - 하단 영웅의 호위무사 → 왼쪽 하단 필러
        - 상단 영웅의 호위무사 → 오른쪽 상단 필러
        """
        if not self.guard_warriors_top and not self.guard_warriors_bottom:
            return

        # 필러 영역 좌표 계산 (REAL_SCREEN 좌표계)
        game_scaled_w = int(SCREEN_WIDTH * game_scale)
        left_pillar_w = game_offset_x
        right_pillar_x = game_offset_x + game_scaled_w
        right_pillar_w = screen.get_width() - right_pillar_x

        # 필러가 없으면 (창 모드) 그리지 않음
        if left_pillar_w < 30 and right_pillar_w < 30:
            return

        # 한글 폰트
        name_font = self._get_guard_korean_font(14)

        # 캐릭터 렌더링용 소형 서피스 크기
        char_surf_w, char_surf_h = 80, 80
        frame_w, frame_h = 70, 70
        slot_h = 85  # 슬롯 간격 (이름 포함)

        # UI 색상
        bg_color = (15, 10, 25, 200)         # 어두운 남색 배경
        border_color = (200, 170, 80, 220)   # 금색 테두리
        label_bg = (10, 5, 20, 200)          # 이름 배경

        # --- 상단 영웅의 호위무사 → 오른쪽 상단 필러 ---
        if right_pillar_w >= 30:
            cx_right = right_pillar_x + right_pillar_w // 2
            y_start_top = game_offset_y + int(80 * game_scale)
            for i, guard in enumerate(self.guard_warriors_top):
                color = guard.get("color", (150, 150, 150))
                slot_cy = y_start_top + i * slot_h

                # 배경 프레임 (어두운 배경 + 금색 테두리)
                frame_surf = pygame.Surface((frame_w, frame_h), pygame.SRCALPHA)
                pygame.draw.rect(frame_surf, bg_color, frame_surf.get_rect(), border_radius=8)
                pygame.draw.rect(frame_surf, border_color, frame_surf.get_rect(), width=2, border_radius=8)
                screen.blit(frame_surf, (cx_right - frame_w // 2, slot_cy))

                # 영웅 캐릭터 이미지
                self._draw_guard_icon_character(
                    screen, guard, cx_right, slot_cy + frame_h // 2 - 5,
                    char_surf_w, char_surf_h, facing="down"
                )

                # 쿨타임 어둡게 오버레이
                if self.phase_top is None and self.cooldown_top > 0:
                    cd_ratio = min(1.0, self.cooldown_top / self.cooldown_range[1])
                    overlay_h = int(frame_h * cd_ratio)
                    if overlay_h > 0:
                        cd_surf = pygame.Surface((frame_w, overlay_h), pygame.SRCALPHA)
                        cd_surf.fill((0, 0, 0, 150))
                        screen.blit(cd_surf, (cx_right - frame_w // 2, slot_cy))

                # 이름 표시 (한글 폰트)
                try:
                    name = guard.get("name", "?")
                    name_surf = name_font.render(name, True, (255, 230, 170))
                    name_rect = name_surf.get_rect(centerx=cx_right, top=slot_cy + frame_h + 2)
                    bg_rect = name_rect.inflate(8, 4)
                    bg_s = pygame.Surface((bg_rect.width, bg_rect.height), pygame.SRCALPHA)
                    pygame.draw.rect(bg_s, label_bg, bg_s.get_rect(), border_radius=4)
                    screen.blit(bg_s, bg_rect)
                    screen.blit(name_surf, name_rect)
                except Exception:
                    pass

        # --- 하단 영웅의 호위무사 → 왼쪽 하단 필러 ---
        if left_pillar_w >= 30:
            cx_left = left_pillar_w // 2
            game_scaled_h = int(SCREEN_HEIGHT * game_scale)
            y_end = game_offset_y + game_scaled_h - int(80 * game_scale)
            y_start_bottom = y_end - len(self.guard_warriors_bottom) * slot_h
            for i, guard in enumerate(self.guard_warriors_bottom):
                color = guard.get("color", (150, 150, 150))
                slot_cy = y_start_bottom + i * slot_h

                # 배경 프레임 (어두운 배경 + 금색 테두리)
                frame_surf = pygame.Surface((frame_w, frame_h), pygame.SRCALPHA)
                pygame.draw.rect(frame_surf, bg_color, frame_surf.get_rect(), border_radius=8)
                pygame.draw.rect(frame_surf, border_color, frame_surf.get_rect(), width=2, border_radius=8)
                screen.blit(frame_surf, (cx_left - frame_w // 2, slot_cy))

                # 영웅 캐릭터 이미지
                self._draw_guard_icon_character(
                    screen, guard, cx_left, slot_cy + frame_h // 2 - 5,
                    char_surf_w, char_surf_h, facing="down"
                )

                # 쿨타임 어둡게 오버레이
                if self.phase_bottom is None and self.cooldown_bottom > 0:
                    cd_ratio = min(1.0, self.cooldown_bottom / self.cooldown_range[1])
                    overlay_h = int(frame_h * cd_ratio)
                    if overlay_h > 0:
                        cd_surf = pygame.Surface((frame_w, overlay_h), pygame.SRCALPHA)
                        cd_surf.fill((0, 0, 0, 150))
                        screen.blit(cd_surf, (cx_left - frame_w // 2, slot_cy))

                # 이름 표시 (한글 폰트)
                try:
                    name = guard.get("name", "?")
                    name_surf = name_font.render(name, True, (255, 230, 170))
                    name_rect = name_surf.get_rect(centerx=cx_left, top=slot_cy + frame_h + 2)
                    bg_rect = name_rect.inflate(8, 4)
                    bg_s = pygame.Surface((bg_rect.width, bg_rect.height), pygame.SRCALPHA)
                    pygame.draw.rect(bg_s, label_bg, bg_s.get_rect(), border_radius=4)
                    screen.blit(bg_s, bg_rect)
                    screen.blit(name_surf, name_rect)
                except Exception:
                    pass

    def _draw_guard_icon_character(self, screen, guard_hero, cx, cy,
                                    surf_w, surf_h, facing="down"):
        """호위무사 캐릭터를 소형 서피스에 렌더링 후 중앙 정렬하여 blit"""
        color = guard_hero.get("color", (200, 200, 200))
        if self.hero_paddle_renderer:
            try:
                # 소형 투명 서피스에 캐릭터를 중앙에 그림
                char_surf = pygame.Surface((surf_w, surf_h), pygame.SRCALPHA)
                self.hero_paddle_renderer.draw_hero_paddle(
                    char_surf, guard_hero["id"],
                    surf_w // 2, surf_h // 2,
                    48, 24,
                    facing=facing, color=color,
                    scale_mode="preview"
                )
                # 중앙 정렬하여 screen에 blit
                screen.blit(char_surf, (cx - surf_w // 2, cy - surf_h // 2))
            except Exception:
                pygame.draw.circle(screen, color, (cx, cy), 14)
                pygame.draw.circle(screen, (255, 255, 255), (cx, cy), 14, 2)
        else:
            pygame.draw.circle(screen, color, (cx, cy), 14)
            pygame.draw.circle(screen, (255, 255, 255), (cx, cy), 14, 2)

    def reset_active_skills(self):
        """득점 시 호위무사 활성 스킬 리셋"""
        game_state = self.skill_manager.game_state if self.skill_manager else {}
        for hero_id, skills in self.skill_instances.items():
            # 이 호위무사가 어느 쪽인지 판별 (패들 정보 없이 리셋)
            for skill in skills:
                if skill.is_active:
                    try:
                        skill.reset_for_new_round(game_state)
                    except Exception:
                        skill.is_active = False
                        skill.active_timer = 0.0

    def reset(self):
        """배틀 종료 시 전체 초기화"""
        # 애니메이션 상태 초기화
        self.phase_top = None
        self.phase_bottom = None
        self.active_top = None
        self.active_bottom = None
        self.selected_skill_top = None
        self.selected_skill_bottom = None
        self.y_top = 120
        self.y_bottom = 630
        self._bubble_top = None
        self._bubble_bottom = None

        # 스킬 인스턴스 정리
        game_state = self.skill_manager.game_state if self.skill_manager else {}
        for hero_id, skills in self.skill_instances.items():
            for skill in skills:
                if skill.is_active:
                    try:
                        skill.reset_for_new_round(game_state)
                    except Exception:
                        skill.is_active = False

        self.guard_warriors_top = []
        self.guard_warriors_bottom = []
        self.skill_instances = {}

    @staticmethod
    def _ease_in_out(t):
        """이징 함수 (부드러운 시작/끝)"""
        if t < 0.5:
            return 2 * t * t
        return 1 - (-2 * t + 2) ** 2 / 2


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

        # 누적 상금 시스템
        self.entry_fee = 500                    # 입장료
        self.entry_fee_paid = False             # 입장료 지불 여부
        self.accumulated_prize = 0              # 누적 상금
        self.round_prizes = {                   # 라운드별 보상
            TournamentRound.QUARTER_FINAL: 500,
            TournamentRound.SEMI_FINAL: 1000,
            TournamentRound.FINAL: 2000,
        }

        # 배팅 정보
        self.selected_match: Optional[Match] = None
        self.bet_hero: Optional[Dict] = None
        self.bet_amount = 0  # 레거시 호환용
        self.total_winnings = 0  # 레거시 호환용

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

        # 대진표 진출 애니메이션 상태
        self.bracket_anim_timer = 0.0          # 애니메이션 타이머
        self.bracket_anim_phase = 0            # 애니메이션 페이즈 (0: X표시, 1: 선 이동, 2: 완료)
        self.bracket_anim_progress = 0.0       # 애니메이션 진행도 (0.0 ~ 1.0)
        self.bracket_anim_completed_matches = []  # 완료된 매치 목록 (패자 X 표시용)
        self.bracket_anim_advancing_winners = []  # 진출하는 승자 목록 (선 이동용)
        self.bracket_anim_next_round = None    # 다음 라운드 정보
        self.bracket_anim_auto_battle = False  # 애니메이션 후 자동 배틀 진행 여부

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

        # === 호위무사 시스템 ===
        self.guard_warrior_map = {}          # hero_id -> [guard hero dicts] (토너먼트 전체 누적)
        self.guard_warriors_top = []         # 현재 배틀 상단 영웅의 호위무사들
        self.guard_warriors_bottom = []      # 현재 배틀 하단 영웅의 호위무사들
        # 쿨타임
        self.guard_cooldown_top = 0.0
        self.guard_cooldown_bottom = 0.0
        self.guard_cooldown_range = (20.0, 30.0)  # 20~30초 랜덤
        # 등장 애니메이션 상태
        self.guard_active_top = None         # 현재 등장 중인 상단측 호위무사 hero dict
        self.guard_active_bottom = None      # 현재 등장 중인 하단측 호위무사 hero dict
        self.guard_phase_top = None          # "entering" / "casting" / "exiting" / None
        self.guard_phase_bottom = None
        self.guard_anim_timer_top = 0.0
        self.guard_anim_timer_bottom = 0.0
        self.guard_x_top = 0.0              # 현재 X 위치 (애니메이션용)
        self.guard_x_bottom = 0.0
        self.guard_side_top = "left"        # 등장 방향 ("left" or "right")
        self.guard_side_bottom = "right"
        self.guard_selected_skill_top = None     # 선택된 스킬 인스턴스
        self.guard_selected_skill_bottom = None
        # 호위무사 독립 스킬 인스턴스
        self.guard_skill_instances = {}      # hero_id -> [skill1, skill2]
        # GuardWarriorSystem 인스턴스
        self.guard_system = None

    def _generate_bracket(self):
        """8강 대진표 생성 - 모든 영웅 자유 매칭 (상단/하단 구분 없음)

        변경사항:
        - 기존: TOP_HEROES 4명 vs BOTTOM_HEROES 4명 고정
        - 변경: ARENA_HEROES 8명 중 자유롭게 매칭 (무겐 vs 쿠로카게 등 가능)
        - 각 매치에서 상단/하단 포지션은 랜덤 배정
        - 스킬 방향은 is_top 플래그로 자동 조정됨
        """
        # 현재 시간 기반 로컬 Random 인스턴스로 완전 랜덤화 (시드 고정 문제 방지)
        local_rng = random.Random(time.time())

        # 전체 8명 영웅을 셔플
        all_heroes = local_rng.sample(ARENA_HEROES, len(ARENA_HEROES))

        # 4개의 매치 생성 (0-1, 2-3, 4-5, 6-7 페어링)
        self.top_heroes = []
        self.bottom_heroes = []

        for i in range(4):
            hero_a = all_heroes[i * 2]
            hero_b = all_heroes[i * 2 + 1]

            # 랜덤으로 상단/하단 결정
            if local_rng.random() < 0.5:
                top_hero, bottom_hero = hero_a, hero_b
            else:
                top_hero, bottom_hero = hero_b, hero_a

            self.top_heroes.append(top_hero)
            self.bottom_heroes.append(bottom_hero)

            # hero1 = 상단 패들 (화면 위), hero2 = 하단 패들 (화면 아래)
            match = Match(top_hero, bottom_hero, i)
            self.matches[TournamentRound.QUARTER_FINAL].append(match)

    def _advance_to_next_round(self):
        """다음 라운드 진출"""
        print(f"[Arena] _advance_to_next_round 시작 | current_round: {self.current_round}")
        if self.current_round == TournamentRound.QUARTER_FINAL:
            # 8강 → 4강
            winners = [m.winner for m in self.matches[TournamentRound.QUARTER_FINAL]]
            print(f"[Arena] 8강 승자들: {[w.get('name', '?') if w else 'None' for w in winners]}")

            # === 호위무사 할당: 8강 패자 → 승자의 호위무사 ===
            for match in self.matches[TournamentRound.QUARTER_FINAL]:
                if match.winner:
                    loser = match.hero1 if match.winner == match.hero2 else match.hero2
                    winner_id = match.winner["id"]
                    if winner_id not in self.guard_warrior_map:
                        self.guard_warrior_map[winner_id] = []
                    self.guard_warrior_map[winner_id].append(loser)
                    print(f"[Guard] 호위무사 할당: {loser['name']} → {match.winner['name']}의 호위무사")

            # 포지션 유지: top 영웅이 hero1, bottom 영웅이 hero2
            self.matches[TournamentRound.SEMI_FINAL] = [
                self._create_positioned_match(winners[0], winners[1], 0),
                self._create_positioned_match(winners[2], winners[3], 1),
            ]
            self.current_round = TournamentRound.SEMI_FINAL
            print(f"[Arena] 4강 매치 생성 완료 | current_round → SEMI_FINAL")
        elif self.current_round == TournamentRound.SEMI_FINAL:
            # 4강 → 결승
            winners = [m.winner for m in self.matches[TournamentRound.SEMI_FINAL]]
            print(f"[Arena] 4강 승자들: {[w.get('name', '?') if w else 'None' for w in winners]}")

            # === 호위무사 할당: 4강 패자 → 승자의 추가 호위무사 ===
            for match in self.matches[TournamentRound.SEMI_FINAL]:
                if match.winner:
                    loser = match.hero1 if match.winner == match.hero2 else match.hero2
                    winner_id = match.winner["id"]
                    if winner_id not in self.guard_warrior_map:
                        self.guard_warrior_map[winner_id] = []
                    self.guard_warrior_map[winner_id].append(loser)
                    print(f"[Guard] 호위무사 추가 할당: {loser['name']} → {match.winner['name']}의 호위무사 (총 {len(self.guard_warrior_map[winner_id])}명)")

            self.matches[TournamentRound.FINAL] = [
                self._create_positioned_match(winners[0], winners[1], 0),
            ]
            self.current_round = TournamentRound.FINAL
            print(f"[Arena] 결승 매치 생성 완료 | current_round → FINAL")

    def _init_guard_warriors_for_battle(self, match: Match):
        """배틀 시작 시 호위무사 시스템 초기화"""
        hero1_guards = self.guard_warrior_map.get(match.hero1["id"], [])
        hero2_guards = self.guard_warrior_map.get(match.hero2["id"], [])

        # GuardWarriorSystem 인스턴스 생성
        self.guard_system = GuardWarriorSystem(
            skill_manager=self.skill_manager,
            hero_paddle_renderer=self.hero_paddle_renderer,
        )

        # 호위무사 할당 (hero1=상단, hero2=하단 기준)
        # 주의: start_battle()에서 bet_hero에 따라 top/bottom이 바뀔 수 있음
        # 실제 배치는 _run_real_game_battle()에서 글로벌 변수로 전달
        self.guard_warriors_top = hero1_guards
        self.guard_warriors_bottom = hero2_guards

        print(f"[Guard] 배틀 호위무사 초기화 | "
              f"{match.hero1['name']}: {[g['name'] for g in hero1_guards]} | "
              f"{match.hero2['name']}: {[g['name'] for g in hero2_guards]}")

    def _create_positioned_match(self, hero_a: Dict, hero_b: Dict, match_id: int) -> Match:
        """랜덤으로 hero1(상단)/hero2(하단) 결정

        변경사항:
        - 기존: 영웅의 원래 position 필드에 따라 배치
        - 변경: 항상 랜덤 배치 (모든 영웅이 상단/하단 모두 가능)
        - 스킬 방향은 is_top 플래그로 자동 조정됨
        """
        # 항상 랜덤 배치
        if random.random() < 0.5:
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
            pingfighter.arena_battle_result = None  # 배틀 결과 초기화
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

            # === 호위무사 시스템 설정 (4강/결승) ===
            if self.current_round in (TournamentRound.SEMI_FINAL, TournamentRound.FINAL):
                try:
                    # top_hero/bottom_hero 기준으로 호위무사 할당
                    top_guards = self.guard_warrior_map.get(top_hero["id"], [])
                    bottom_guards = self.guard_warrior_map.get(bottom_hero["id"], [])
                    if top_guards or bottom_guards:
                        guard_system = GuardWarriorSystem(
                            skill_manager=pingfighter.arena_skill_manager,
                            hero_paddle_renderer=pingfighter.arena_hero_paddle_renderer,
                        )
                        guard_system.setup(top_guards, bottom_guards)
                        pingfighter.arena_guard_system = guard_system
                        print(f"[Guard] pingfighter 호위무사 시스템 설정 완료")
                    else:
                        pingfighter.arena_guard_system = None
                except Exception as e:
                    print(f"[Guard] 호위무사 시스템 설정 오류: {e}")
                    pingfighter.arena_guard_system = None
            else:
                pingfighter.arena_guard_system = None

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
                pingfighter.arena_battle_result = None  # 배틀 결과 초기화
                pingfighter.arena_top_hero = None
                pingfighter.arena_bottom_hero = None
                pingfighter.arena_hero_paddle_renderer = None
                pingfighter.arena_skill_manager = None
                pingfighter.arena_skill_check_timer = 0.0
                # 호위무사 시스템 초기화
                if hasattr(pingfighter, 'arena_guard_system') and pingfighter.arena_guard_system:
                    pingfighter.arena_guard_system.reset()
                pingfighter.arena_guard_system = None
            except Exception:
                pass

    def _start_vs_preview(self, show_buttons=False):
        """VS 매치업 미리보기 시작
        show_buttons=False: 2초 후 자동 배틀 시작 (8강 첫 배틀)
        show_buttons=True: VS 화면 + 계속/나가기 버튼 (4강/결승 진출 후)
        """
        self.vs_preview_timer = 0.0
        self.vs_preview_progress = 0.0
        self.vs_preview_show_buttons = show_buttons
        self.state = TournamentState.VS_PREVIEW
        print(f"[Arena] VS 미리보기 시작 (buttons={show_buttons}) | {self.selected_match.hero1['name']} vs {self.selected_match.hero2['name']}")

    def start_battle(self, match: Match):
        """배틀 시작 - 실제 게임 엔진 사용 (pingfighter.main 스테이지 30)"""
        self.selected_match = match

        # 배틀 활성화 (중요: _end_battle()에서 체크하므로 반드시 설정해야 함)
        self.battle_active = True
        print(f"[Arena] 배틀 시작! {match.hero1['name']} vs {match.hero2['name']}")

        # 입장료는 manager.py에서 이미 차감됨 (이중 차감 방지)
        # 첫 배틀 시작 표시만 함
        if not self.entry_fee_paid:
            self.entry_fee_paid = True

        # 점수 리셋
        self.score_top = 0
        self.score_bottom = 0

        # === 호위무사 초기화 (4강/결승만) ===
        if self.current_round in (TournamentRound.SEMI_FINAL, TournamentRound.FINAL):
            self._init_guard_warriors_for_battle(match)
        else:
            self.guard_warriors_top = []
            self.guard_warriors_bottom = []
            self.guard_skill_instances = {}

        # 배팅한 영웅이 하단(플레이어 AI)이 되도록 배치
        # 플레이어 AI는 항상 하단을 제어하므로, bet_hero가 하단이어야 배팅한 영웅이 유리
        if self.bet_hero == match.hero1:
            # bet_hero가 hero1이면 순서를 바꿔서 bet_hero가 하단이 되도록
            top_hero = match.hero2
            bottom_hero = match.hero1
            print(f"[Arena] 배치 조정: {top_hero['name']}(상단) vs {bottom_hero['name']}(하단/배팅)")
        else:
            # bet_hero가 hero2이면 그대로 (hero2가 하단)
            top_hero = match.hero1
            bottom_hero = match.hero2
            print(f"[Arena] 배치 유지: {top_hero['name']}(상단) vs {bottom_hero['name']}(하단/배팅)")

        # 실제 게임 엔진으로 배틀 실행
        try:
            if self.battle_callback:
                result = self.battle_callback(top_hero, bottom_hero)
            else:
                result = self._run_real_game_battle(top_hero, bottom_hero)

            # 결과 처리: True = 하단(플레이어 AI/배팅 영웅) 승리, False = 상단 승리
            if result:
                winner = bottom_hero  # 하단 승리 = 배팅한 영웅 승리
                self.score_top = 0
                self.score_bottom = 5
            else:
                winner = top_hero  # 상단 승리 = 배팅한 영웅 패배
                self.score_top = 5
                self.score_bottom = 0

            print(f"[Arena] 배틀 결과: result={result}, winner={winner['name']}, bet_hero={self.bet_hero['name'] if self.bet_hero else 'None'}")
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

        # === 달빛 베기 화면 정지 체크 (스킬 업데이트 전에 체크!) ===
        is_frozen = False
        if self.skill_manager:
            is_frozen = self.skill_manager.game_state.get('dark_slash_freeze', False)

        # 스킬 시스템 업데이트 (화면 정지 중에도 스킬 이펙트는 업데이트)
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

        if not is_frozen:
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

            # === 달빛 베기 벽 반사 시 즉시 상대 방향으로 꺾기 ===
            if self.skill_manager and self.ball.wall_bounced:
                game_state = self.skill_manager.game_state
                if game_state.get('dark_slash_active', False):
                    # 시전자 방향에 따라 상대 방향으로 즉시 꺾음
                    caster_is_top = game_state.get('dark_slash_caster_is_top', False)
                    if caster_is_top:
                        # 상단이 시전 → 하단 방향(양수)으로 강제
                        self.ball.vy = abs(self.ball.vy)
                    else:
                        # 하단이 시전 → 상단 방향(음수)으로 강제
                        self.ball.vy = -abs(self.ball.vy)
                    # 벽 반사 후 달빛 베기 효과 종료
                    game_state['dark_slash_active'] = False
                    print(f"[DarkSlash] 벽 반사 → 상대 방향으로 즉시 꺾음! vy={self.ball.vy:.1f}")

            # 패들 충돌 체크 + 스킬 발동
            if self.ball.check_paddle_collision(self.top_paddle):
                self._on_ball_hit(self.selected_match.hero1["id"], self.top_paddle, self.bottom_paddle)
                # 관중 반응 (약한 흥분)
                if self.arena_pillar and hasattr(self.arena_pillar, 'trigger_excitement'):
                    self.arena_pillar.trigger_excitement(intensity=0.3, duration=0.5)
            if self.ball.check_paddle_collision(self.bottom_paddle):
                self._on_ball_hit(self.selected_match.hero2["id"], self.bottom_paddle, self.top_paddle)
                # 관중 반응 (약한 흥분)
                if self.arena_pillar and hasattr(self.arena_pillar, 'trigger_excitement'):
                    self.arena_pillar.trigger_excitement(intensity=0.3, duration=0.5)
        else:
            # 화면 정지 중 - 공/패들 업데이트 없음
            scorer = None

        # 득점 처리
        if scorer:
            # 방어 로직: 배틀이 이미 종료되었으면 점수 증가 방지
            if not self.battle_active:
                print(f"[Arena] 경고: 배틀 종료 후 득점 시도 무시")
                return True

            if scorer == "top":
                self.score_top += 1
                print(f"[Arena] 상단 득점! 현재 점수: {self.score_top}:{self.score_bottom}")
            else:
                self.score_bottom += 1
                print(f"[Arena] 하단 득점! 현재 점수: {self.score_top}:{self.score_bottom}")

            # 관중 흥분 이벤트 트리거
            if self.arena_pillar and hasattr(self.arena_pillar, 'trigger_excitement'):
                self.arena_pillar.trigger_excitement(intensity=1.0, duration=2.5)

            # === 모든 활성 스킬 상태 리셋 (득점 시) ===
            if self.skill_manager:
                self.skill_manager.reset_active_skills_for_round()

                # 🔮 난쟁이마술 등으로 축소된 패들 크기 복원
                if self.top_paddle:
                    self.top_paddle.paddle_scale = 1.0
                    # 귀신발걸음 y축 이동 중이면 강제 종료 및 원위치 복귀
                    if self.top_paddle.ghost_step_active:
                        self.top_paddle.end_ghost_step()
                if self.bottom_paddle:
                    self.bottom_paddle.paddle_scale = 1.0
                    if self.bottom_paddle.ghost_step_active:
                        self.bottom_paddle.end_ghost_step()

            # 승리 체크 (5점 선취, 4:4부터 듀스)
            if self._check_winner():
                return True

            # 방어 로직: _check_winner에서 배틀이 종료되었으면 리턴
            if not self.battle_active:
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
        self.top_paddle.gravity_drift = game_state.get('top_paddle_gravity_drift', 0.0)

        # 하단 패들 상태 효과
        self.bottom_paddle.is_stunned = game_state.get('bottom_paddle_stunned', False)
        self.bottom_paddle.slow_multiplier = game_state.get('bottom_paddle_slow_amount', 1.0) if game_state.get('bottom_paddle_slowed', False) else 1.0
        self.bottom_paddle.is_confused = game_state.get('bottom_paddle_confused', False)
        self.bottom_paddle.paddle_scale = game_state.get('bottom_paddle_shrink_scale', 1.0) if game_state.get('bottom_paddle_shrink', False) else 1.0
        self.bottom_paddle.gravity_drift = game_state.get('bottom_paddle_gravity_drift', 0.0)


        # 🔥 귀신발걸음 y축 이동 트리거 처리
        if game_state.get('ghost_step_start_top', False):
            self.top_paddle.start_ghost_step()
            game_state['ghost_step_start_top'] = False  # 플래그 초기화 (한번만 발동)
            print(f"[Arena] 상단 패들 귀신발걸음 y축 이동 시작!")

        if game_state.get('ghost_step_start_bottom', False):
            self.bottom_paddle.start_ghost_step()
            game_state['ghost_step_start_bottom'] = False  # 플래그 초기화
            print(f"[Arena] 하단 패들 귀신발걸음 y축 이동 시작!")

        # 쿨다운 스킬 자동 사용 (AI)
        self.skill_check_timer += dt
        if self.skill_check_timer >= self.skill_check_interval:
            self.skill_check_timer = 0
            self._try_use_cooldown_skills()

    def _on_ball_hit(self, hero_id: str, caster_paddle, target_paddle):
        """공을 칠 때 ON_BALL_HIT 스킬 발동"""
        if not self.skill_manager or not HERO_SKILLS_AVAILABLE:
            return

        # === 달빛 베기 반격 처리 ===
        # 상대가 공을 반격하면 달빛 베기로 인한 공 가속을 원래 속도로 복귀
        game_state = self.skill_manager.game_state
        if game_state.get('dark_slash_active', False):
            # 달빛 베기 시전자와 현재 타자가 다르면 (= 상대가 반격)
            dark_slash_caster_is_top = game_state.get('dark_slash_caster_is_top', False)
            if dark_slash_caster_is_top != caster_paddle.is_top:
                # 무겐의 DarkSlash 스킬 찾아서 on_opponent_hit 호출
                mugen_skills = self.skill_manager.hero_skills.get('mugen', [])
                for skill in mugen_skills:
                    if skill.skill_id == 'dark_slash' and hasattr(skill, 'on_opponent_hit'):
                        skill.on_opponent_hit(self.ball, game_state)
                        break

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
            # 폰트 설정 (한글 지원 Pretendard 폰트)
            import os
            import sys
            font = pygame.font.Font(None, 24)
            try:
                if hasattr(sys, '_MEIPASS'):
                    base = sys._MEIPASS
                else:
                    base = os.path.dirname(os.path.dirname(__file__))
                font_candidates = [
                    os.path.join(base, "fonts", "프리텐다드", "public", "static", "alternative", "Pretendard-Bold.ttf"),
                    os.path.join(base, "fonts", "프리텐다드", "public", "static", "alternative", "Pretendard-Regular.ttf"),
                    os.path.join(base, "fonts", "프리텐다드", "public", "static", "Pretendard-Bold.otf"),
                    os.path.join(base, "fonts", "NanumSquareB.ttf"),
                ]
                for font_path in font_candidates:
                    if os.path.exists(font_path):
                        font = pygame.font.Font(font_path, 20)
                        break
            except Exception:
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

        # 방어 로직: selected_match가 없으면 강제 종료
        if not self.selected_match:
            print(f"[Arena] ERROR: selected_match is None! 강제 배틀 종료")
            self.battle_active = False
            self.state = TournamentState.BRACKET_VIEW
            return True

        # 방어 로직: 점수가 비정상적으로 높으면 강제 종료 (최대 15점)
        MAX_SCORE = 15
        if s1 >= MAX_SCORE or s2 >= MAX_SCORE:
            print(f"[Arena] 점수 상한 도달 ({s1}:{s2}) - 강제 종료")
            winner = self.selected_match.hero1 if s1 > s2 else self.selected_match.hero2
            self._end_battle(winner)
            return True

        # 듀스 상황 (둘 다 4점 이상): 2점 차이로 승리
        if s1 >= 4 and s2 >= 4:
            if abs(s1 - s2) >= 2:
                winner = self.selected_match.hero1 if s1 > s2 else self.selected_match.hero2
                print(f"[Arena] 듀스 승리! {s1}:{s2} → {winner['name']}")
                self._end_battle(winner)
                return True
        # 일반 상황: 5점 선취
        else:
            if s1 >= WIN_SCORE:
                print(f"[Arena] 일반 승리! {s1}:{s2} → {self.selected_match.hero1['name']}")
                self._end_battle(self.selected_match.hero1)
                return True
            if s2 >= WIN_SCORE:
                print(f"[Arena] 일반 승리! {s1}:{s2} → {self.selected_match.hero2['name']}")
                self._end_battle(self.selected_match.hero2)
                return True

        return False

    def _end_battle(self, winner: Dict):
        """배틀 종료 - 누적 상금 시스템"""
        # 방어 로직: 이미 종료된 배틀이면 무시
        if not self.battle_active:
            print(f"[Arena] 경고: _end_battle 중복 호출 무시 (이미 종료됨)")
            return

        print(f"[Arena] 배틀 종료! 승자: {winner.get('name', 'Unknown')} | 최종 점수: {self.score_top}:{self.score_bottom}")
        self.battle_active = False

        # 방어 로직: selected_match 체크
        if not self.selected_match:
            print(f"[Arena] ERROR: selected_match is None in _end_battle!")
            self.state = TournamentState.BRACKET_VIEW
            return

        self.selected_match.set_result(winner, self.score_top, self.score_bottom)

        # 누적 상금 시스템 - 승패 결과 처리
        if self.bet_hero:
            if winner == self.bet_hero:
                # 승리 - 라운드 보상 누적
                round_prize = self.round_prizes.get(self.current_round, 0)
                self.accumulated_prize += round_prize
                self.total_winnings = self.accumulated_prize  # 동기화
            else:
                # 패배 - 누적 상금 전액 몰수
                self.accumulated_prize = 0
                self.total_winnings = -self.entry_fee  # 입장료만 잃음 (이미 지불했으므로)

        # 나머지 경기 자동 결정 (랜덤)
        self._auto_decide_remaining_matches()

        self.state = TournamentState.RESULT
        self.result_display_timer = 180  # 3초

    def _auto_decide_remaining_matches(self):
        """현재 라운드의 나머지 경기를 랜덤으로 결정"""
        current_matches = self.matches.get(self.current_round, [])
        for match in current_matches:
            if not match.completed:
                # 호위무사 보너스: 보유 수에 따른 승률 보정 (4강/결승)
                guard_count_1 = len(self.guard_warrior_map.get(match.hero1["id"], []))
                guard_count_2 = len(self.guard_warrior_map.get(match.hero2["id"], []))
                bonus_1 = guard_count_1 * 0.05  # 호위무사 1명당 5% 보정
                bonus_2 = guard_count_2 * 0.05
                prob_1 = 0.5 + bonus_1 - bonus_2
                prob_1 = max(0.2, min(0.8, prob_1))  # 20%~80% 제한

                # 보정된 확률로 승자 결정
                winner = match.hero1 if random.random() < prob_1 else match.hero2
                # 랜덤 스코어 (승자가 5점, 패자는 0~4점)
                if winner == match.hero1:
                    score1 = 5
                    score2 = random.randint(0, 4)
                else:
                    score1 = random.randint(0, 4)
                    score2 = 5
                match.set_result(winner, score1, score2)
                guard_info = f" (호위무사: {guard_count_1} vs {guard_count_2})" if guard_count_1 or guard_count_2 else ""
                print(f"[Arena] 자동 결정: {match.hero1['name']} vs {match.hero2['name']} → 승자: {winner['name']} ({score1}:{score2}){guard_info}")

    def _auto_select_bet_hero_match(self):
        """배팅한 영웅이 포함된 경기를 자동 선택하고 바로 배틀 시작"""
        if not self.bet_hero:
            self.state = TournamentState.BRACKET_VIEW
            return

        current_matches = self.matches.get(self.current_round, [])
        for match in current_matches:
            if match.completed:
                continue
            # 배팅한 영웅이 이 경기에 있는지 확인
            if match.hero1 == self.bet_hero or match.hero2 == self.bet_hero:
                self.selected_match = match
                # 영웅 재선택 없이 바로 배틀 시작
                print(f"[Arena] 자동 배틀 시작: {match.hero1['name']} vs {match.hero2['name']} (배팅 영웅: {self.bet_hero['name']})")
                self.start_battle(match)
                return

        # 배팅 영웅을 찾지 못한 경우 (이론상 불가능)
        self.state = TournamentState.BRACKET_VIEW

    def _prepare_next_match(self):
        """배팅한 영웅이 포함된 다음 경기 준비 (배틀 시작 없이)"""
        if not self.bet_hero:
            return

        current_matches = self.matches.get(self.current_round, [])
        for match in current_matches:
            if match.completed:
                continue
            # 배팅한 영웅이 이 경기에 있는지 확인
            if match.hero1 == self.bet_hero or match.hero2 == self.bet_hero:
                self.selected_match = match
                print(f"[Arena] 다음 경기 준비: {match.hero1['name']} vs {match.hero2['name']} (배팅 영웅: {self.bet_hero['name']})")
                return

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

        if self.state == TournamentState.VS_PREVIEW:
            # VS 매치업 미리보기
            self.vs_preview_timer += dt
            vs_preview_duration = 2.0
            self.vs_preview_progress = min(1.0, self.vs_preview_timer / vs_preview_duration)
            if not getattr(self, 'vs_preview_show_buttons', False):
                # 버튼 없는 모드: 2초 후 자동 배틀 시작
                if self.vs_preview_timer >= vs_preview_duration:
                    self.start_battle(self.selected_match)
            # 버튼 있는 모드: 클릭 대기 (자동 시작 안함)

        elif self.state == TournamentState.BATTLE:
            self.update_battle(dt)
        elif self.state == TournamentState.RESULT:
            self.result_display_timer -= 1
            if self.result_display_timer <= 0:
                # 다음 단계 결정
                print(f"[Arena] RESULT 타이머 종료 | bet_hero: {self.bet_hero.get('name', '?') if self.bet_hero else None}")
                print(f"[Arena] selected_match.winner: {self.selected_match.winner.get('name', '?') if self.selected_match and self.selected_match.winner else None}")
                print(f"[Arena] current_round: {self.current_round}")

                # 배팅한 영웅이 패배했으면 토너먼트 종료
                if self.bet_hero and self.selected_match and self.selected_match.winner != self.bet_hero:
                    print(f"[Arena] 패배! → TOURNAMENT_END")
                    self.state = TournamentState.TOURNAMENT_END
                elif self.current_round == TournamentRound.FINAL:
                    # 결승전 종료
                    final_matches = self.matches.get(TournamentRound.FINAL, [])
                    final_match = final_matches[0] if final_matches else None
                    is_champion = final_match and final_match.winner == self.bet_hero
                    if is_champion:
                        # 우승! → 축하 연출
                        print(f"[Arena] 우승! → VICTORY_CELEBRATION")
                        self.victory_timer = 0.0
                        self.victory_confetti = []
                        self.state = TournamentState.VICTORY_CELEBRATION
                    else:
                        # 결승 패배 → 바로 종료
                        print(f"[Arena] 결승전 패배! → TOURNAMENT_END")
                        self.state = TournamentState.TOURNAMENT_END
                else:
                    # 승리 - 호위무사 생포 알림 후 대진표 애니메이션
                    bet_hero_loser = None
                    if self.bet_hero and self.selected_match:
                        match = self.selected_match
                        if match.winner == self.bet_hero:
                            bet_hero_loser = match.hero1 if match.winner == match.hero2 else match.hero2

                    if bet_hero_loser:
                        # 호위무사 생포 알림 먼저 표시
                        self.guard_notify_hero = bet_hero_loser
                        self.guard_notify_owner = self.bet_hero
                        self.guard_notify_timer = 0.0
                        self.guard_notify_progress = 0.0
                        # 호위무사 수: 기존 + 이번에 생포한 1명
                        current_guards = len(self.guard_warrior_map.get(self.bet_hero["id"], []))
                        self.guard_notify_total = current_guards + 1
                        self.state = TournamentState.GUARD_NOTIFY
                        print(f"[Arena] 승리! → GUARD_NOTIFY | {bet_hero_loser['name']} 생포")
                    else:
                        # 호위무사 없으면 바로 대진표 애니메이션
                        print(f"[Arena] 승리! → BRACKET_ANIMATION 시작")
                        self._start_bracket_animation()

        elif self.state == TournamentState.GUARD_NOTIFY:
            # 호위무사 생포 알림 (2.5초)
            self.guard_notify_timer += dt
            guard_notify_duration = 2.5
            self.guard_notify_progress = min(1.0, self.guard_notify_timer / guard_notify_duration)
            if self.guard_notify_timer >= guard_notify_duration:
                # 알림 끝 → 대진표 애니메이션 시작
                print(f"[Arena] GUARD_NOTIFY 완료 → BRACKET_ANIMATION 시작")
                self._start_bracket_animation()

        elif self.state == TournamentState.VICTORY_CELEBRATION:
            self.victory_timer += dt

        elif self.state == TournamentState.BRACKET_ANIMATION:
            self._update_bracket_animation(dt)

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
            box_w, box_h = 120, 140  # 대각선 레이아웃 크기

            # 8강 매치 클릭 체크
            y_base = 530
            x_positions = [60, 195, 430, 565]

            for i, match in enumerate(self.matches[TournamentRound.QUARTER_FINAL]):
                if match.completed:
                    continue
                x = x_positions[i]
                if x <= mx <= x + box_w and y_base <= my <= y_base + box_h:
                    self.selected_match = match
                    self.state = TournamentState.BETTING
                    self.bet_amount = 100
                    return

            # 4강 매치 클릭 체크
            y_semi = 310
            x_semi = [127, 497]

            for i, match in enumerate(self.matches.get(TournamentRound.SEMI_FINAL, [])):
                if match.completed:
                    continue
                x = x_semi[i]
                if x <= mx <= x + box_w and y_semi <= my <= y_semi + box_h:
                    self.selected_match = match
                    self.state = TournamentState.BETTING
                    self.bet_amount = 100
                    return

            # 결승 매치 클릭 체크
            y_final = 80
            x_final = 312

            for match in self.matches.get(TournamentRound.FINAL, []):
                if match.completed:
                    continue
                if x_final <= mx <= x_final + box_w and y_final <= my <= y_final + box_h:
                    self.selected_match = match
                    self.state = TournamentState.BETTING
                    self.bet_amount = 100
                    return

        elif self.state == TournamentState.BETTING:
            # 배팅 UI 클릭 처리 (그리기 좌표와 동일하게)
            panel_x, panel_y = 200, 200
            panel_w, panel_h = 360, 400

            # 단순화된 배팅 UI - 영웅 클릭시 바로 배틀 시작
            panel_x, panel_y = 180, 180

            # 영웅 1 선택 버튼 (클릭하면 VS 미리보기 후 배틀)
            btn1_rect = pygame.Rect(panel_x + 30, panel_y + 145, 160, 100)
            if btn1_rect.collidepoint(mx, my):
                self.bet_hero = self.selected_match.hero1
                self._start_vs_preview()
                return

            # 영웅 2 선택 버튼 (클릭하면 VS 미리보기 후 배틀)
            btn2_rect = pygame.Rect(panel_x + 210, panel_y + 145, 160, 100)
            if btn2_rect.collidepoint(mx, my):
                self.bet_hero = self.selected_match.hero2
                self._start_vs_preview()
                return

            # 포기하고 나가기 버튼
            exit_rect = pygame.Rect(panel_x + 100, panel_y + 300, 200, 40)
            if exit_rect.collidepoint(mx, my):
                # 누적 상금을 total_winnings에 저장
                self.total_winnings = self.accumulated_prize
                self.winnings_collected = True
                self.exit_requested = True
                return

        elif self.state == TournamentState.VS_PREVIEW:
            # VS 미리보기 클릭 처리 (버튼 모드일 때)
            if getattr(self, 'vs_preview_show_buttons', False) and self.vs_preview_timer >= 1.5:
                btn_y = 610
                btn_w, btn_h = 180, 50
                # 계속 도전 버튼
                continue_rect = pygame.Rect(SCREEN_WIDTH // 2 - btn_w - 20, btn_y, btn_w, btn_h)
                if continue_rect.collidepoint(mx, my):
                    if self.selected_match:
                        self.start_battle(self.selected_match)
                    return

                # 상금 수령하고 나가기 버튼
                exit_rect = pygame.Rect(SCREEN_WIDTH // 2 + 20, btn_y, btn_w, btn_h)
                if exit_rect.collidepoint(mx, my):
                    self.total_winnings = self.accumulated_prize
                    self.winnings_collected = True
                    self.exit_requested = True
                    return

        elif self.state == TournamentState.RESULT:
            # 결과 화면 클릭 시 다음으로
            self.result_display_timer = 0

        elif self.state == TournamentState.VICTORY_CELEBRATION:
            # 축하 화면 클릭 → 3초 이후부터 TOURNAMENT_END로 전환
            if getattr(self, 'victory_timer', 0) >= 3.0:
                self.state = TournamentState.TOURNAMENT_END
                return

        elif self.state == TournamentState.TOURNAMENT_END:
            # 토너먼트 종료 UI 클릭 처리 (그리기 좌표와 동일하게)
            panel_x, panel_y = 180, 180
            exit_rect = pygame.Rect(panel_x + 100, panel_y + 270, 200, 50)
            if exit_rect.collidepoint(mx, my):
                self.total_winnings = self.accumulated_prize
                self.winnings_collected = True
                self.exit_requested = True
                return

    def draw(self):
        """메인 그리기"""
        if self.state == TournamentState.VS_PREVIEW:
            self._draw_vs_preview()
        elif self.state == TournamentState.BATTLE:
            self._draw_battle()
        elif self.state == TournamentState.GUARD_NOTIFY:
            self._draw_guard_notification()
        elif self.state == TournamentState.VICTORY_CELEBRATION:
            self._draw_victory_celebration()
        elif self.state == TournamentState.BRACKET_ANIMATION:
            self._draw_bracket_animation()
        else:
            self._draw_bracket()

    def _draw_vs_preview(self):
        """VS 매치업 미리보기 그리기 (배틀 전 표시)"""
        # 배경 그리기
        self.screen.fill((25, 28, 35))

        # _draw_vs_matchup_animation 재사용 (progress 임시 설정)
        saved_progress = getattr(self, 'bracket_anim_progress', 0.0)
        self.bracket_anim_progress = self.vs_preview_progress
        self._draw_vs_matchup_animation()
        self.bracket_anim_progress = saved_progress

        # 버튼 모드: 1.5초 후 하단에 계속/나가기 버튼 페이드인
        if getattr(self, 'vs_preview_show_buttons', False) and self.vs_preview_timer >= 1.5:
            btn_fade = min(1.0, (self.vs_preview_timer - 1.5) / 0.5)  # 0.5초간 페이드인
            btn_alpha = int(255 * btn_fade)

            btn_y = 610
            btn_w, btn_h = 180, 50

            # 상금 정보 (버튼 위)
            if self.fonts and "medium" in self.fonts and btn_fade > 0.3:
                info_alpha = int(255 * btn_fade)
                acc_text = f"누적 상금: {self.accumulated_prize}G"
                surf, _ = self.fonts["medium"].render(acc_text, (int(100 * btn_fade), int(255 * btn_fade), int(100 * btn_fade)))
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, btn_y - 55))

                # 경고
                if "small" in self.fonts:
                    warn_text = "패배 시 누적 상금을 모두 잃습니다!"
                    surf, _ = self.fonts["small"].render(warn_text, (int(255 * btn_fade), int(180 * btn_fade), int(100 * btn_fade)))
                    warn_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
                    self._draw_warning_icon(warn_x - 12, btn_y - 30, 10)
                    self.screen.blit(surf, (warn_x, btn_y - 35))

            # 계속 도전 버튼
            continue_rect = pygame.Rect(SCREEN_WIDTH // 2 - btn_w - 20, btn_y, btn_w, btn_h)
            btn_surf = pygame.Surface((btn_w, btn_h), pygame.SRCALPHA)
            pygame.draw.rect(btn_surf, (80, 180, 80, btn_alpha), (0, 0, btn_w, btn_h), border_radius=5)
            self.screen.blit(btn_surf, continue_rect.topleft)
            if self.fonts and "medium" in self.fonts:
                surf, _ = self.fonts["medium"].render("계속 도전!", (255, 255, 255))
                btn_text_x = continue_rect.centerx - surf.get_width() // 2
                self._draw_fire_icon(btn_text_x - 12, continue_rect.y + 15 + surf.get_height() // 2, 12)
                self.screen.blit(surf, (btn_text_x, continue_rect.y + 15))

            # 상금 수령 버튼
            exit_rect = pygame.Rect(SCREEN_WIDTH // 2 + 20, btn_y, btn_w, btn_h)
            btn_surf = pygame.Surface((btn_w, btn_h), pygame.SRCALPHA)
            pygame.draw.rect(btn_surf, (100, 100, 180, btn_alpha), (0, 0, btn_w, btn_h), border_radius=5)
            self.screen.blit(btn_surf, exit_rect.topleft)
            if self.fonts and "medium" in self.fonts:
                surf, _ = self.fonts["medium"].render(f"{self.accumulated_prize}G 수령", (255, 255, 255))
                btn_text_x = exit_rect.centerx - surf.get_width() // 2
                self._draw_coin_icon(btn_text_x - 12, exit_rect.y + 15 + surf.get_height() // 2, 12)
                self.screen.blit(surf, (btn_text_x, exit_rect.y + 15))

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
            # DEBUG
            if self.top_paddle.paddle_scale != 1.0:
                print(f"[DEBUG Draw] top_paddle scale={self.top_paddle.paddle_scale}, scaled_width={scaled_width}")

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

            # 성스러운 공 효과 (스팀 배리어)
            if self.skill_manager and self.skill_manager.game_state.get('ball_holy', False):
                holy_glow = pygame.Surface((BALL_SIZE * 5, BALL_SIZE * 5), pygame.SRCALPHA)
                pygame.draw.circle(holy_glow, (255, 215, 80, 70), (BALL_SIZE * 5 // 2, BALL_SIZE * 5 // 2), BALL_SIZE * 5 // 2)
                pygame.draw.circle(holy_glow, (255, 240, 180, 100), (BALL_SIZE * 5 // 2, BALL_SIZE * 5 // 2), BALL_SIZE * 2)
                self.screen.blit(holy_glow, (ball_x - BALL_SIZE * 5 // 2, ball_y - BALL_SIZE * 5 // 2), special_flags=pygame.BLEND_ADD)

            # 그림자
            pygame.draw.circle(self.screen, (60, 50, 40),
                             (ball_x + 2, ball_y + 3), BALL_SIZE)
            # 공 본체
            if self.skill_manager and self.skill_manager.game_state.get('ball_on_fire', False):
                ball_color = (255, 200, 100)
            elif self.skill_manager and self.skill_manager.game_state.get('ball_holy', False):
                ball_color = (255, 240, 180)
            else:
                ball_color = (255, 255, 255)
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
        # 박스 크기 (120x160으로 확대)
        box_w, box_h = 120, 160

        # 8강 매치 (하단) - 위로 올림
        y_base = 530
        x_positions = [60, 195, 430, 565]

        for i, match in enumerate(self.matches[TournamentRound.QUARTER_FINAL]):
            x = x_positions[i]
            self._draw_match_box(match, x, y_base, i)

        # 4강 매치 (중간) - 위로 올림
        y_semi = 310
        x_semi = [127, 497]

        for i, match in enumerate(self.matches.get(TournamentRound.SEMI_FINAL, [])):
            self._draw_match_box(match, x_semi[i], y_semi, i + 4)

        # 빈 4강 슬롯
        if not self.matches.get(TournamentRound.SEMI_FINAL):
            for i, x in enumerate(x_semi):
                self._draw_empty_match_box(x, y_semi, "준결승 " + str(i + 1))

        # 결승 (상단) - 위로 올림
        y_final = 80
        x_final = 312

        final_matches = self.matches.get(TournamentRound.FINAL, [])
        if final_matches:
            self._draw_match_box(final_matches[0], x_final, y_final, 6)
        else:
            self._draw_empty_match_box(x_final, y_final, "결승")

        # 연결선 그리기
        self._draw_bracket_lines()

    def _draw_match_box(self, match: Match, x: int, y: int, match_idx: int):
        """매치 박스 그리기 (대각선 분할 레이아웃)"""
        box_w, box_h = 120, 140  # 약간 낮은 박스

        # 박스 배경
        bg_color = (45, 50, 60) if not match.completed else (35, 55, 45)
        pygame.draw.rect(self.screen, bg_color, (x, y, box_w, box_h), border_radius=8)
        pygame.draw.rect(self.screen, (100, 105, 115), (x, y, box_w, box_h), 2, border_radius=8)

        # 대각선 (왼쪽 하단 → 오른쪽 상단)
        pygame.draw.line(self.screen, (80, 85, 95), (x + 5, y + box_h - 5), (x + box_w - 5, y + 5), 2)

        # === 영웅 1 (왼쪽 상단 삼각형) ===
        h1_color = match.hero1["color"]
        hero1_name = match.hero1.get("name", "???")
        # 이름 색상 밝기 보정 (너무 어두우면 밝게)
        h1_brightness = sum(h1_color) / 3
        h1_name_color = h1_color if h1_brightness > 80 else (min(255, h1_color[0] + 100), min(255, h1_color[1] + 100), min(255, h1_color[2] + 100))
        # 이름 (상단 좌측)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(hero1_name, h1_name_color)
            self.screen.blit(surf, (x + 8, y + 8))
        # 캐릭터 이미지 (좌측 - 더 왼쪽으로, 60% 크게)
        if self.hero_paddle_renderer:
            hero1_id = match.hero1.get("id", "mugen")
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero1_id, x + 25, y + 55, 64, 45,
                facing="down", color=h1_color, scale_mode="preview"
            )

        # === VS (중앙 원) ===
        vs_x = x + box_w // 2
        vs_y = y + box_h // 2
        pygame.draw.circle(self.screen, (60, 65, 75), (vs_x, vs_y), 16)
        pygame.draw.circle(self.screen, (100, 105, 115), (vs_x, vs_y), 16, 2)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render("VS", (255, 215, 0))
            self.screen.blit(surf, (vs_x - surf.get_width() // 2, vs_y - surf.get_height() // 2))

        # === 영웅 2 (오른쪽 하단 삼각형) ===
        h2_color = match.hero2["color"]
        hero2_name = match.hero2.get("name", "???")
        # 이름 색상 밝기 보정 (너무 어두우면 밝게)
        h2_brightness = sum(h2_color) / 3
        h2_name_color = h2_color if h2_brightness > 80 else (min(255, h2_color[0] + 100), min(255, h2_color[1] + 100), min(255, h2_color[2] + 100))
        # 캐릭터 이미지 (우측 - 더 오른쪽으로, 60% 크게)
        if self.hero_paddle_renderer:
            hero2_id = match.hero2.get("id", "chronos")
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero2_id, x + box_w - 25, y + box_h - 55, 64, 45,
                facing="down", color=h2_color, scale_mode="preview"
            )
        # 이름 (하단 우측)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(hero2_name, h2_name_color)
            self.screen.blit(surf, (x + box_w - surf.get_width() - 8, y + box_h - 22))

        # 결과 표시
        if match.completed and match.winner:
            if self.fonts and "small" in self.fonts:
                surf, _ = self.fonts["small"].render(f"{match.score1}:{match.score2}", (255, 215, 0))
                self.screen.blit(surf, (x + box_w // 2 - surf.get_width() // 2, y + box_h + 5))

    def _draw_empty_match_box(self, x: int, y: int, label: str):
        """빈 매치 박스"""
        box_w, box_h = 120, 140  # 대각선 레이아웃과 동일한 크기
        pygame.draw.rect(self.screen, (35, 38, 45), (x, y, box_w, box_h), border_radius=8)
        pygame.draw.rect(self.screen, (60, 65, 75), (x, y, box_w, box_h), 2, border_radius=8)

        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render(label, (100, 100, 100))
            self.screen.blit(surf, (x + box_w // 2 - surf.get_width() // 2, y + box_h // 2 - surf.get_height() // 2))

    def _draw_bracket_lines(self):
        """대진표 연결선 (대각선 레이아웃 box_h=140 기준)"""
        line_color = (100, 105, 115)

        # 8강 박스 중심 x좌표 (box_w=120 기준)
        q1_x, q2_x, q3_x, q4_x = 120, 255, 490, 625
        # 4강 박스 중심 x좌표
        s1_x, s2_x = 187, 557
        # 결승 박스 중심 x좌표
        f_x = 372

        # 8강 top y = 530, 4강 bottom y = 450 (310+140)
        y_q_top = 530
        y_mid1 = 490  # 8강→4강 연결 중간선
        y_s_bottom = 450  # 4강 박스 하단

        # 8강 → 4강 연결 (좌측)
        pygame.draw.line(self.screen, line_color, (q1_x, y_q_top), (q1_x, y_mid1), 2)
        pygame.draw.line(self.screen, line_color, (q2_x, y_q_top), (q2_x, y_mid1), 2)
        pygame.draw.line(self.screen, line_color, (q1_x, y_mid1), (q2_x, y_mid1), 2)
        pygame.draw.line(self.screen, line_color, (s1_x, y_mid1), (s1_x, y_s_bottom), 2)

        # 8강 → 4강 연결 (우측)
        pygame.draw.line(self.screen, line_color, (q3_x, y_q_top), (q3_x, y_mid1), 2)
        pygame.draw.line(self.screen, line_color, (q4_x, y_q_top), (q4_x, y_mid1), 2)
        pygame.draw.line(self.screen, line_color, (q3_x, y_mid1), (q4_x, y_mid1), 2)
        pygame.draw.line(self.screen, line_color, (s2_x, y_mid1), (s2_x, y_s_bottom), 2)

        # 4강 top y = 310, 결승 bottom y = 220 (80+140)
        y_s_top = 310
        y_mid2 = 265  # 4강→결승 연결 중간선
        y_f_bottom = 220  # 결승 박스 하단

        # 4강 → 결승 연결
        pygame.draw.line(self.screen, line_color, (s1_x, y_s_top), (s1_x, y_mid2), 2)
        pygame.draw.line(self.screen, line_color, (s2_x, y_s_top), (s2_x, y_mid2), 2)
        pygame.draw.line(self.screen, line_color, (s1_x, y_mid2), (s2_x, y_mid2), 2)
        pygame.draw.line(self.screen, line_color, (f_x, y_mid2), (f_x, y_f_bottom), 2)

    def _draw_match_selection_hint(self):
        """경기 선택 힌트"""
        if self.fonts and "small" in self.fonts:
            hint = "관전할 경기를 클릭하세요"
            surf, _ = self.fonts["small"].render(hint, (180, 180, 180))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 700))

    def _draw_betting_ui(self):
        """단순화된 배팅 UI - 영웅만 선택"""
        if not self.selected_match:
            return

        # 반투명 오버레이
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        # 배팅 패널
        panel_x, panel_y = 180, 180
        panel_w, panel_h = 400, 355
        pygame.draw.rect(self.screen, (35, 40, 50), (panel_x, panel_y, panel_w, panel_h), border_radius=10)
        pygame.draw.rect(self.screen, (255, 215, 0), (panel_x, panel_y, panel_w, panel_h), 3, border_radius=10)

        # 라운드 타이틀
        round_names = {
            TournamentRound.QUARTER_FINAL: "8강전",
            TournamentRound.SEMI_FINAL: "4강전",
            TournamentRound.FINAL: "결승전",
        }
        if self.fonts and "large" in self.fonts:
            title = round_names.get(self.current_round, "배틀")
            surf, _ = self.fonts["large"].render(title, (255, 215, 0))
            title_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
            title_y = panel_y + 15
            self.screen.blit(surf, (title_x, title_y))
            icon_y = title_y + surf.get_height() // 2
            if self.current_round == TournamentRound.FINAL:
                self._draw_crown_icon(title_x - 14, icon_y, 14)
                self._draw_crown_icon(title_x + surf.get_width() + 14, icon_y, 14)
            else:
                self._draw_sword_icon(title_x - 14, icon_y, 12)
                self._draw_sword_icon(title_x + surf.get_width() + 14, icon_y, 12)

        # 승리 보상 표시
        current_prize = self.round_prizes.get(self.current_round, 0)
        if self.fonts and "medium" in self.fonts:
            prize_text = f"승리 보상: +{current_prize}G"
            surf, _ = self.fonts["medium"].render(prize_text, (100, 255, 100))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 55))

        # 누적 상금 표시
        if self.fonts and "small" in self.fonts:
            acc_text = f"현재 누적 상금: {self.accumulated_prize}G"
            color = (255, 215, 0) if self.accumulated_prize > 0 else (180, 180, 180)
            surf, _ = self.fonts["small"].render(acc_text, color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 85))

        # 안내 문구
        if self.fonts and "small" in self.fonts:
            hint = "승리할 영웅을 선택하세요!"
            surf, _ = self.fonts["small"].render(hint, (200, 200, 200))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 115))

        # 영웅 1 선택 버튼 (캐릭터 이미지 포함)
        hero1 = self.selected_match.hero1
        btn1_rect = pygame.Rect(panel_x + 30, panel_y + 145, 160, 100)
        pygame.draw.rect(self.screen, hero1["color"], btn1_rect, border_radius=8)
        pygame.draw.rect(self.screen, (255, 255, 255), btn1_rect, 3, border_radius=8)
        if self.fonts:
            # 영웅 이름
            if "medium" in self.fonts:
                surf, _ = self.fonts["medium"].render(hero1["name"], (255, 255, 255))
                self.screen.blit(surf, (btn1_rect.centerx - surf.get_width() // 2, btn1_rect.y + 10))
            # 영웅 칭호
            if "small" in self.fonts:
                surf, _ = self.fonts["small"].render(hero1["title"], (220, 220, 220))
                self.screen.blit(surf, (btn1_rect.centerx - surf.get_width() // 2, btn1_rect.y + 35))
        # 캐릭터 이미지
        if self.hero_paddle_renderer:
            hero1_id = hero1.get("id", "mugen")
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero1_id, btn1_rect.centerx, btn1_rect.y + 72, 50, 35,
                facing="down", color=hero1["color"], scale_mode="preview"
            )

        # VS
        if self.fonts and "large" in self.fonts:
            surf, _ = self.fonts["large"].render("VS", (255, 100, 100))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 175))

        # 영웅 2 선택 버튼 (캐릭터 이미지 포함)
        hero2 = self.selected_match.hero2
        btn2_rect = pygame.Rect(panel_x + 210, panel_y + 145, 160, 100)
        pygame.draw.rect(self.screen, hero2["color"], btn2_rect, border_radius=8)
        pygame.draw.rect(self.screen, (255, 255, 255), btn2_rect, 3, border_radius=8)
        if self.fonts:
            if "medium" in self.fonts:
                surf, _ = self.fonts["medium"].render(hero2["name"], (255, 255, 255))
                self.screen.blit(surf, (btn2_rect.centerx - surf.get_width() // 2, btn2_rect.y + 10))
            if "small" in self.fonts:
                surf, _ = self.fonts["small"].render(hero2["title"], (220, 220, 220))
                self.screen.blit(surf, (btn2_rect.centerx - surf.get_width() // 2, btn2_rect.y + 35))
        # 캐릭터 이미지
        if self.hero_paddle_renderer:
            hero2_id = hero2.get("id", "chronos")
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero2_id, btn2_rect.centerx, btn2_rect.y + 72, 50, 35,
                facing="down", color=hero2["color"], scale_mode="preview"
            )

        # 경고 문구
        if self.fonts and "small" in self.fonts:
            warn_text = "패배시 누적 상금 전액 몰수!"
            surf, _ = self.fonts["small"].render(warn_text, (255, 150, 100))
            warn_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
            self._draw_warning_icon(warn_x - 12, panel_y + 265 + surf.get_height() // 2, 10)
            self.screen.blit(surf, (warn_x, panel_y + 265))

        # 포기하고 나가기 버튼
        exit_rect = pygame.Rect(panel_x + 100, panel_y + 300, 200, 40)
        exit_color = (100, 80, 80) if self.accumulated_prize > 0 else (60, 60, 60)
        pygame.draw.rect(self.screen, exit_color, exit_rect, border_radius=5)
        if self.fonts and "small" in self.fonts:
            if self.accumulated_prize > 0:
                exit_text = f"상금 수령하고 나가기 ({self.accumulated_prize}G)"
            else:
                exit_text = "포기하고 나가기"
            surf, _ = self.fonts["small"].render(exit_text, (255, 200, 200))
            self.screen.blit(surf, (exit_rect.centerx - surf.get_width() // 2, exit_rect.y + 12))

    def _draw_result_ui(self):
        """결과 UI - 누적 상금 시스템"""
        if not self.selected_match or not self.selected_match.winner:
            return

        # 반투명 오버레이
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        winner = self.selected_match.winner
        is_win = self.bet_hero == winner

        # 결과 패널
        panel_x, panel_y = 180, 200
        panel_w, panel_h = 400, 320
        pygame.draw.rect(self.screen, (35, 40, 50), (panel_x, panel_y, panel_w, panel_h), border_radius=10)

        # 테두리 색상 (승리: 금색, 패배: 빨강)
        border_color = (255, 215, 0) if is_win else (255, 80, 80)
        pygame.draw.rect(self.screen, border_color, (panel_x, panel_y, panel_w, panel_h), 3, border_radius=10)

        # 결과 타이틀
        if self.fonts and "large" in self.fonts:
            if is_win:
                result_text = "-- 승리! --"
                text_color = (255, 215, 0)
            else:
                result_text = "패배..."
                text_color = (255, 100, 100)
            surf, _ = self.fonts["large"].render(result_text, text_color)
            result_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
            result_y = panel_y + 20
            self.screen.blit(surf, (result_x, result_y))
            if not is_win:
                icon_y = result_y + surf.get_height() // 2
                self._draw_skull_icon(result_x - 16, icon_y, 14)
                self._draw_skull_icon(result_x + surf.get_width() + 16, icon_y, 14)

        # 승자 정보
        if self.fonts and "medium" in self.fonts:
            winner_text = f"승자: {winner['name']}"
            surf, _ = self.fonts["medium"].render(winner_text, winner["color"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 65))

            # 스코어
            score_text = f"{self.selected_match.score1} : {self.selected_match.score2}"
            surf, _ = self.fonts["medium"].render(score_text, (200, 200, 200))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 95))

        # 보상/손실 표시
        if self.fonts and "medium" in self.fonts:
            if is_win:
                round_prize = self.round_prizes.get(self.current_round, 0)
                profit_text = f"+{round_prize}G 획득!"
                profit_color = (100, 255, 100)
            else:
                profit_text = "누적 상금 전액 몰수!"
                profit_color = (255, 100, 100)
            surf, _ = self.fonts["medium"].render(profit_text, profit_color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 140))

        # 누적 상금 표시
        if self.fonts and "large" in self.fonts:
            acc_text = f"누적 상금: {self.accumulated_prize}G"
            color = (255, 215, 0) if self.accumulated_prize > 0 else (150, 150, 150)
            surf, _ = self.fonts["large"].render(acc_text, color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 185))

        # 패배시 추가 메시지
        if not is_win and self.fonts and "small" in self.fonts:
            lose_msg = f"입장료 {self.entry_fee}G를 잃었습니다..."
            surf, _ = self.fonts["small"].render(lose_msg, (200, 150, 150))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 230))

        # 안내
        if self.fonts and "small" in self.fonts:
            hint = "클릭하여 계속"
            surf, _ = self.fonts["small"].render(hint, (150, 150, 150))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 280))

    def _draw_round_end_ui(self):
        """라운드 종료 UI - 누적 상금 시스템"""
        # 반투명 오버레이
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        self.screen.blit(overlay, (0, 0))

        # 패널
        panel_x, panel_y = 150, 180
        panel_w, panel_h = 460, 340
        pygame.draw.rect(self.screen, (35, 40, 50), (panel_x, panel_y, panel_w, panel_h), border_radius=10)
        pygame.draw.rect(self.screen, (255, 215, 0), (panel_x, panel_y, panel_w, panel_h), 3, border_radius=10)

        # 타이틀
        if self.fonts and "large" in self.fonts:
            round_name = "4강" if self.current_round == TournamentRound.SEMI_FINAL else "결승"
            title = f"{round_name} 진출!"
            surf, _ = self.fonts["large"].render(title, (255, 215, 0))
            title_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
            self.screen.blit(surf, (title_x, panel_y + 25))
            icon_y = panel_y + 25 + surf.get_height() // 2
            self._draw_trophy_icon(title_x - 16, icon_y, 14)
            self._draw_trophy_icon(title_x + surf.get_width() + 16, icon_y, 14)

        # 누적 상금 (크게)
        if self.fonts and "large" in self.fonts:
            acc_text = f"누적 상금: {self.accumulated_prize}G"
            surf, _ = self.fonts["large"].render(acc_text, (100, 255, 100))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 75))

        # 다음 라운드 보상 정보
        if self.fonts and "medium" in self.fonts:
            next_prize = self.round_prizes.get(self.current_round, 0)
            next_text = f"다음 라운드 보상: +{next_prize}G"
            surf, _ = self.fonts["medium"].render(next_text, (180, 180, 255))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 120))

        # 선택한 영웅 정보
        if self.bet_hero and self.fonts and "medium" in self.fonts:
            hero_name = self.bet_hero.get("name", "???")
            hero_color = self.bet_hero.get("color", (255, 255, 255))
            # 밝기 보정
            brightness = sum(hero_color) / 3
            display_color = hero_color if brightness > 80 else (min(255, hero_color[0] + 100), min(255, hero_color[1] + 100), min(255, hero_color[2] + 100))
            hero_text = f"[{hero_name}] 으로 계속 도전!"
            surf, _ = self.fonts["medium"].render(hero_text, display_color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 155))

        # 경고
        if self.fonts and "small" in self.fonts:
            warn_text = "패배 시 누적 상금을 모두 잃습니다!"
            surf, _ = self.fonts["small"].render(warn_text, (255, 180, 100))
            warn_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
            self._draw_warning_icon(warn_x - 12, panel_y + 185 + surf.get_height() // 2, 10)
            self.screen.blit(surf, (warn_x, panel_y + 185))

        # 계속 버튼 (도전)
        continue_rect = pygame.Rect(panel_x + 40, panel_y + 220, 180, 50)
        pygame.draw.rect(self.screen, (80, 180, 80), continue_rect, border_radius=5)
        if self.fonts and "medium" in self.fonts:
            surf, _ = self.fonts["medium"].render("계속 도전!", (255, 255, 255))
            btn_text_x = continue_rect.centerx - surf.get_width() // 2
            self._draw_fire_icon(btn_text_x - 12, continue_rect.y + 15 + surf.get_height() // 2, 12)
            self.screen.blit(surf, (btn_text_x, continue_rect.y + 15))

        # 나가기 버튼 (상금 수령)
        exit_rect = pygame.Rect(panel_x + 240, panel_y + 220, 180, 50)
        pygame.draw.rect(self.screen, (100, 100, 180), exit_rect, border_radius=5)
        if self.fonts and "medium" in self.fonts:
            surf, _ = self.fonts["medium"].render(f"{self.accumulated_prize}G 수령", (255, 255, 255))
            btn_text_x = exit_rect.centerx - surf.get_width() // 2
            self._draw_coin_icon(btn_text_x - 12, exit_rect.y + 15 + surf.get_height() // 2, 12)
            self.screen.blit(surf, (btn_text_x, exit_rect.y + 15))

        # 남은 보상 미리보기
        if self.fonts and "small" in self.fonts:
            remaining = []
            if self.current_round == TournamentRound.SEMI_FINAL:
                remaining = [f"4강: +{self.round_prizes[TournamentRound.SEMI_FINAL]}G",
                           f"결승: +{self.round_prizes[TournamentRound.FINAL]}G"]
            else:
                remaining = [f"결승: +{self.round_prizes[TournamentRound.FINAL]}G"]
            preview_text = "남은 보상: " + " → ".join(remaining)
            surf, _ = self.fonts["small"].render(preview_text, (150, 200, 255))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 285))

    def _draw_victory_celebration(self):
        """우승 축하 연출 화면 - 시상식 구도"""
        timer = getattr(self, 'victory_timer', 0.0)
        champion = self.bet_hero
        if not champion:
            self.state = TournamentState.TOURNAMENT_END
            return

        champion_id = champion.get("id", "mugen")
        champion_color = champion.get("color", (200, 200, 200))
        champion_name = champion.get("name", "???")
        champion_title = champion.get("title", "")
        guards = self.guard_warrior_map.get(champion_id, [])

        center_x = SCREEN_WIDTH // 2
        # 전체 연출 진행도
        intro = min(1.0, timer / 2.0)  # 0~2초: 등장
        eased = self._ease_in_out(intro)

        # === 배경 ===
        self.screen.fill((15, 12, 25))

        # 방사형 빛줄기 (금색)
        if intro > 0.3:
            ray_alpha = int(30 * min(1.0, (intro - 0.3) * 2))
            ray_surf = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
            num_rays = 12
            for i in range(num_rays):
                angle = (i / num_rays) * math.pi * 2 + self.animation_timer * 0.3
                end_x = center_x + int(math.cos(angle) * 500)
                end_y = 350 + int(math.sin(angle) * 500)
                pygame.draw.line(ray_surf, (255, 215, 0, ray_alpha), (center_x, 350), (end_x, end_y), 3)
            self.screen.blit(ray_surf, (0, 0))

        # 바닥 무대 (금색 그라데이션 라인)
        stage_y = 540
        if intro > 0.2:
            stage_alpha = int(180 * min(1.0, (intro - 0.2) * 3))
            stage_surf = pygame.Surface((SCREEN_WIDTH, 4), pygame.SRCALPHA)
            for sx in range(SCREEN_WIDTH):
                dist = abs(sx - center_x) / (SCREEN_WIDTH / 2)
                a = int(stage_alpha * max(0, 1.0 - dist * 1.2))
                stage_surf.set_at((sx, 0), (255, 215, 0, a))
                stage_surf.set_at((sx, 1), (255, 215, 0, a // 2))
                stage_surf.set_at((sx, 2), (200, 170, 0, a // 3))
                stage_surf.set_at((sx, 3), (150, 130, 0, a // 4))
            self.screen.blit(stage_surf, (0, stage_y))

        # === 호위무사 (양옆, 챔피언보다 먼저 등장) ===
        guard_y_target = 420
        guard_size_w, guard_size_h = 80, 56

        if guards and self.hero_paddle_renderer and intro > 0.1:
            guard_fade = min(1.0, (intro - 0.1) * 2.5)
            guard_eased = self._ease_in_out(guard_fade)

            # 왼쪽 호위무사 (최대 1명)
            if len(guards) >= 1:
                g = guards[0]
                g_target_x = center_x - 180
                g_start_x = -100
                gx = int(g_start_x + (g_target_x - g_start_x) * guard_eased)
                gy = int(guard_y_target + 100 * (1 - guard_eased))
                g_color = g.get("color", (150, 150, 150))

                # 글로우
                glow_a = int(40 * guard_fade)
                glow_s = pygame.Surface((120, 120), pygame.SRCALPHA)
                pygame.draw.circle(glow_s, (*g_color, glow_a), (60, 60), 55)
                self.screen.blit(glow_s, (gx - 60, gy - 60))

                self.hero_paddle_renderer.draw_hero_paddle(
                    self.screen, g.get("id", "mugen"), gx, gy, guard_size_w, guard_size_h,
                    facing="down", color=g_color, scale_mode="preview"
                )
                # 이름
                if self.fonts and "small" in self.fonts and guard_fade > 0.5:
                    ns, _ = self.fonts["small"].render(g.get("name", ""), (180, 180, 180))
                    self.screen.blit(ns, (gx - ns.get_width() // 2, gy + guard_size_h // 2 + 8))

            # 오른쪽 호위무사 (최대 1명)
            if len(guards) >= 2:
                g = guards[1]
                g_target_x = center_x + 180
                g_start_x = SCREEN_WIDTH + 100
                gx = int(g_start_x + (g_target_x - g_start_x) * guard_eased)
                gy = int(guard_y_target + 100 * (1 - guard_eased))
                g_color = g.get("color", (150, 150, 150))

                glow_s = pygame.Surface((120, 120), pygame.SRCALPHA)
                pygame.draw.circle(glow_s, (*g_color, glow_a), (60, 60), 55)
                self.screen.blit(glow_s, (gx - 60, gy - 60))

                self.hero_paddle_renderer.draw_hero_paddle(
                    self.screen, g.get("id", "mugen"), gx, gy, guard_size_w, guard_size_h,
                    facing="down", color=g_color, scale_mode="preview"
                )
                if self.fonts and "small" in self.fonts and guard_fade > 0.5:
                    ns, _ = self.fonts["small"].render(g.get("name", ""), (180, 180, 180))
                    self.screen.blit(ns, (gx - ns.get_width() // 2, gy + guard_size_h // 2 + 8))

        # === 챔피언 (중앙, 크게) ===
        champ_target_y = 380
        champ_start_y = 600
        champ_y = int(champ_start_y + (champ_target_y - champ_start_y) * eased)
        champ_w, champ_h = 150, 105

        # 챔피언 글로우 (크고 화려하게)
        if intro > 0.2:
            glow_pulse = abs(math.sin(self.animation_timer * 2)) * 0.3 + 0.7
            glow_a = int(80 * min(1.0, (intro - 0.2) * 2) * glow_pulse)
            glow_r = 110
            glow_s = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_s, (255, 215, 0, glow_a), (glow_r, glow_r), glow_r)
            self.screen.blit(glow_s, (center_x - glow_r, champ_y - glow_r))
            # 내부 캐릭터 색 글로우
            glow_s2 = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_s2, (*champion_color, glow_a // 2), (glow_r, glow_r), glow_r - 20)
            self.screen.blit(glow_s2, (center_x - glow_r, champ_y - glow_r))

        # 챔피언 캐릭터
        if self.hero_paddle_renderer:
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, champion_id, center_x, champ_y, champ_w, champ_h,
                facing="down", color=champion_color, scale_mode="preview"
            )

        # === 트로피 (챔피언 위, 스케일업 등장) ===
        if intro > 0.5:
            trophy_progress = min(1.0, (intro - 0.5) * 3)
            trophy_eased = self._ease_in_out(trophy_progress)
            trophy_y = champ_y - champ_h // 2 - 60
            trophy_size = int(30 * trophy_eased)
            if trophy_size > 3:
                # 트로피 받침대 빛
                sparkle_a = int(60 * trophy_eased + abs(math.sin(self.animation_timer * 4)) * 40)
                sparkle_s = pygame.Surface((80, 80), pygame.SRCALPHA)
                pygame.draw.circle(sparkle_s, (255, 230, 100, sparkle_a), (40, 40), 35)
                self.screen.blit(sparkle_s, (center_x - 40, trophy_y - 40))
                self._draw_trophy_icon(center_x, trophy_y, trophy_size, (255, 215, 0))

        # === 타이틀 텍스트 ===
        if intro > 0.4 and self.fonts:
            text_fade = min(1.0, (intro - 0.4) * 2.5)
            text_alpha = int(255 * text_fade)

            # "토너먼트 우승!" (큰 금색)
            if "large" in self.fonts:
                pulse = abs(math.sin(self.animation_timer * 3)) * 0.3 + 0.7
                gold = (int(255 * pulse), int(215 * pulse), 0)
                surf, _ = self.fonts["large"].render("토너먼트 우승!", gold)
                alpha_s = pygame.Surface(surf.get_size(), pygame.SRCALPHA)
                alpha_s.fill((255, 255, 255, text_alpha))
                surf.blit(alpha_s, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                title_x = center_x - surf.get_width() // 2
                self.screen.blit(surf, (title_x, 80))
                # 양쪽 트로피 아이콘
                if text_fade > 0.5:
                    icon_y = 80 + surf.get_height() // 2
                    self._draw_trophy_icon(title_x - 20, icon_y, 16)
                    self._draw_trophy_icon(title_x + surf.get_width() + 20, icon_y, 16)

            # 챔피언 이름
            if "large" in self.fonts:
                brightness = sum(champion_color) / 3
                name_color = champion_color if brightness > 80 else (
                    min(255, champion_color[0] + 100),
                    min(255, champion_color[1] + 100),
                    min(255, champion_color[2] + 100)
                )
                surf, _ = self.fonts["large"].render(champion_name, name_color)
                alpha_s = pygame.Surface(surf.get_size(), pygame.SRCALPHA)
                alpha_s.fill((255, 255, 255, text_alpha))
                surf.blit(alpha_s, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf, (center_x - surf.get_width() // 2, champ_y - champ_h // 2 - 30))

            # 칭호
            if "small" in self.fonts and champion_title:
                surf, _ = self.fonts["small"].render(champion_title, (200, 200, 200))
                alpha_s = pygame.Surface(surf.get_size(), pygame.SRCALPHA)
                alpha_s.fill((255, 255, 255, text_alpha))
                surf.blit(alpha_s, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf, (center_x - surf.get_width() // 2, champ_y + champ_h // 2 + 12))

            # 상금
            if "medium" in self.fonts and text_fade > 0.6:
                prize_text = f"획득 상금: {self.accumulated_prize}G"
                surf, _ = self.fonts["medium"].render(prize_text, (100, 255, 100))
                prize_alpha = int(255 * min(1.0, (text_fade - 0.6) * 3))
                alpha_s = pygame.Surface(surf.get_size(), pygame.SRCALPHA)
                alpha_s.fill((255, 255, 255, prize_alpha))
                surf.blit(alpha_s, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf, (center_x - surf.get_width() // 2, 570))

        # === 컨페티 파티클 ===
        if intro > 0.6:
            confetti = getattr(self, 'victory_confetti', [])
            # 새 파티클 생성
            if len(confetti) < 60 and random.random() < 0.4:
                confetti.append({
                    'x': random.randint(50, SCREEN_WIDTH - 50),
                    'y': random.randint(-20, 0),
                    'vx': random.uniform(-1, 1),
                    'vy': random.uniform(1.5, 3.5),
                    'color': random.choice([
                        (255, 215, 0), (255, 100, 100), (100, 200, 255),
                        (100, 255, 100), (255, 150, 50), (200, 100, 255)
                    ]),
                    'size': random.randint(3, 7),
                    'rot': random.uniform(0, math.pi * 2),
                    'rot_speed': random.uniform(-3, 3)
                })

            # 업데이트 + 그리기
            alive = []
            for p in confetti:
                p['x'] += p['vx']
                p['y'] += p['vy']
                p['vy'] += 0.02  # 약한 중력
                p['rot'] += p['rot_speed'] * 0.016
                if p['y'] < SCREEN_HEIGHT + 10:
                    alive.append(p)
                    # 직사각형 컨페티
                    s = p['size']
                    cs = pygame.Surface((s * 2, s), pygame.SRCALPHA)
                    pygame.draw.rect(cs, p['color'], (0, 0, s * 2, s))
                    rotated = pygame.transform.rotate(cs, math.degrees(p['rot']))
                    self.screen.blit(rotated, (int(p['x']) - rotated.get_width() // 2,
                                               int(p['y']) - rotated.get_height() // 2))
            self.victory_confetti = alive

        # === 하단 힌트 ===
        if timer >= 3.0 and self.fonts and "small" in self.fonts:
            blink = abs(math.sin(self.animation_timer * 2)) * 155 + 100
            surf, _ = self.fonts["small"].render("클릭하여 계속...", (int(blink), int(blink), int(blink)))
            self.screen.blit(surf, (center_x - surf.get_width() // 2, 680))

    def _draw_tournament_end_ui(self):
        """토너먼트 종료 UI - 누적 상금 시스템"""
        # 반투명 오버레이
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 200))
        self.screen.blit(overlay, (0, 0))

        # 결승전 결과 확인
        final_matches = self.matches.get(TournamentRound.FINAL, [])
        final_match = final_matches[0] if final_matches else None
        is_champion = final_match and final_match.winner == self.bet_hero

        # 패널
        panel_x, panel_y = 180, 180
        panel_w, panel_h = 400, 340
        pygame.draw.rect(self.screen, (35, 40, 50), (panel_x, panel_y, panel_w, panel_h), border_radius=10)
        border_color = (255, 215, 0) if is_champion else (255, 80, 80)
        pygame.draw.rect(self.screen, border_color, (panel_x, panel_y, panel_w, panel_h), 3, border_radius=10)

        # 타이틀
        if self.fonts and "large" in self.fonts:
            if is_champion:
                title = "토너먼트 우승!"
                title_color = (255, 215, 0)
            else:
                title = "결승전 패배..."
                title_color = (255, 100, 100)
            surf, _ = self.fonts["large"].render(title, title_color)
            title_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
            self.screen.blit(surf, (title_x, panel_y + 25))
            icon_y = panel_y + 25 + surf.get_height() // 2
            if is_champion:
                self._draw_trophy_icon(title_x - 16, icon_y, 14)
                self._draw_trophy_icon(title_x + surf.get_width() + 16, icon_y, 14)
            else:
                self._draw_skull_icon(title_x - 16, icon_y, 14)
                self._draw_skull_icon(title_x + surf.get_width() + 16, icon_y, 14)

        # 최종 우승자
        if final_match and final_match.winner and self.fonts and "medium" in self.fonts:
            winner_text = f"우승자: {final_match.winner['name']}"
            surf, _ = self.fonts["medium"].render(winner_text, final_match.winner["color"])
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 75))

        # 최종 획득 금액
        if self.fonts and "large" in self.fonts:
            if is_champion:
                # 우승 - 누적 상금 표시
                profit_text = f"획득 상금: {self.accumulated_prize}G"
                color = (100, 255, 100)
            else:
                # 패배 - 입장료만 잃음
                profit_text = f"손실: -{self.entry_fee}G"
                color = (255, 100, 100)
            surf, _ = self.fonts["large"].render(profit_text, color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 130))

        # 보상 상세
        if is_champion and self.fonts and "small" in self.fonts:
            detail = f"(8강 +500G + 4강 +1000G + 결승 +2000G = {self.accumulated_prize}G)"
            surf, _ = self.fonts["small"].render(detail, (180, 180, 180))
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 175))

        # 메시지
        if self.fonts and "medium" in self.fonts:
            if is_champion:
                msg = "축하합니다! 완벽한 승리!"
                msg_color = (255, 215, 0)
            else:
                msg = "다음에 다시 도전하세요!"
                msg_color = (200, 200, 200)
            surf, _ = self.fonts["medium"].render(msg, msg_color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, panel_y + 220))

        # 나가기 버튼
        exit_rect = pygame.Rect(panel_x + 100, panel_y + 270, 200, 50)
        pygame.draw.rect(self.screen, (80, 120, 180), exit_rect, border_radius=5)
        if self.fonts and "medium" in self.fonts:
            surf, _ = self.fonts["medium"].render("투기장 나가기", (255, 255, 255))
            self.screen.blit(surf, (exit_rect.centerx - surf.get_width() // 2, exit_rect.y + 15))

    def _start_bracket_animation(self):
        """대진표 진출 애니메이션 시작"""
        print(f"[Arena] _start_bracket_animation 시작 | current_round: {self.current_round}")
        self.bracket_anim_timer = 0.0
        self.bracket_anim_phase = 0  # 0: 패자 X 표시, 1: 승자 이동, 2: 대기 후 VS_PREVIEW 전환
        self.bracket_anim_progress = 0.0

        # 현재 라운드의 완료된 매치와 승자 수집
        current_matches = self.matches[self.current_round]
        self.bracket_anim_completed_matches = [m for m in current_matches if m.completed]
        self.bracket_anim_advancing_winners = [m.winner for m in self.bracket_anim_completed_matches if m.winner]
        print(f"[Arena] 완료된 매치: {len(self.bracket_anim_completed_matches)}, 진출 승자: {len(self.bracket_anim_advancing_winners)}")

        # 다음 라운드 정보 저장
        if self.current_round == TournamentRound.QUARTER_FINAL:
            self.bracket_anim_next_round = TournamentRound.SEMI_FINAL
        elif self.current_round == TournamentRound.SEMI_FINAL:
            self.bracket_anim_next_round = TournamentRound.FINAL
        else:
            self.bracket_anim_next_round = None
        print(f"[Arena] 다음 라운드: {self.bracket_anim_next_round}")

        self.bracket_anim_auto_battle = True
        self.state = TournamentState.BRACKET_ANIMATION
        print(f"[Arena] state → BRACKET_ANIMATION")

    def _update_bracket_animation(self, dt: float):
        """대진표 애니메이션 업데이트"""
        self.bracket_anim_timer += dt

        # 애니메이션 속도 설정
        phase_duration = 1.5  # 각 페이즈 지속 시간 (초)

        if self.bracket_anim_phase == 0:
            # 페이즈 0: 패자 X 표시 애니메이션
            self.bracket_anim_progress = min(1.0, self.bracket_anim_timer / phase_duration)
            if self.bracket_anim_timer >= phase_duration:
                self.bracket_anim_phase = 1
                self.bracket_anim_timer = 0.0
                self.bracket_anim_progress = 0.0

        elif self.bracket_anim_phase == 1:
            # 페이즈 1: 승자 캐릭터 이동 애니메이션
            self.bracket_anim_progress = min(1.0, self.bracket_anim_timer / phase_duration)
            if self.bracket_anim_timer >= phase_duration:
                self.bracket_anim_phase = 2
                self.bracket_anim_timer = 0.0
                self.bracket_anim_progress = 0.0
                # 다음 라운드로 진출 (매치 생성)
                print(f"[Arena] Phase 1 완료 → _advance_to_next_round() 호출")
                self._advance_to_next_round()
                print(f"[Arena] _advance_to_next_round() 완료 | current_round: {self.current_round}")
                # 배팅한 영웅이 포함된 경기 자동 선택
                self._prepare_next_match()
                print(f"[Arena] _prepare_next_match() 완료 | selected_match: {self.selected_match}")

        elif self.bracket_anim_phase == 2:
            # 페이즈 2: 짧은 대기 후 VS_PREVIEW(버튼 모드)로 전환
            wait_time = 0.3
            if self.bracket_anim_timer >= wait_time:
                # 애니메이션 상태 초기화
                self.bracket_anim_phase = 0
                self.bracket_anim_progress = 0.0
                self.bracket_anim_timer = 0.0

                # VS_PREVIEW로 전환 (버튼 포함)
                print(f"[Arena] Phase 2 완료 → VS_PREVIEW (buttons) 전환 | current_round: {self.current_round}")
                self._start_vs_preview(show_buttons=True)

    def _draw_bracket_animation(self):
        """대진표 진출 애니메이션 그리기"""
        # 배경
        self.screen.fill((25, 28, 35))

        # 라운드 진출 타이틀
        if self.fonts and "large" in self.fonts:
            round_name = ""
            if self.bracket_anim_next_round == TournamentRound.SEMI_FINAL:
                round_name = "4강"
            elif self.bracket_anim_next_round == TournamentRound.FINAL:
                round_name = "결승"

            title = f"{round_name} 진출!"
            # 타이틀 펄스 효과
            pulse = abs(math.sin(self.animation_timer * 3)) * 0.3 + 0.7
            gold_color = (int(255 * pulse), int(215 * pulse), 0)
            surf, _ = self.fonts["large"].render(title, gold_color)
            self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 30))

        # 대진표 그리기 (애니메이션 효과 포함)
        self._draw_animated_bracket()

        # 진행 표시
        if self.fonts and "small" in self.fonts:
            if self.bracket_anim_phase < 2:
                hint = "잠시 후 다음 매치가 시작됩니다..."
                alpha = int(abs(math.sin(self.animation_timer * 2)) * 155 + 100)
                surf, _ = self.fonts["small"].render(hint, (alpha, alpha, alpha))
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 700))

    def _draw_guard_notification(self):
        """호위무사 생포 알림 애니메이션"""
        guard = self.guard_notify_hero
        owner = self.guard_notify_owner
        if not guard or not owner:
            return

        progress = getattr(self, 'guard_notify_progress', 0.0)  # 0.0 ~ 1.0 over 2.5s

        # 배경
        self.screen.fill((25, 28, 35))

        # 반투명 다크 오버레이 (페이드인)
        overlay_alpha = int(min(180, 220 * min(1.0, progress * 3)))
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((10, 5, 20, overlay_alpha))
        self.screen.blit(overlay, (0, 0))

        center_x = SCREEN_WIDTH // 2

        # 호위무사 영웅 이미지 (아래에서 슬라이드 업)
        target_y = SCREEN_HEIGHT // 2 - 30
        start_y = SCREEN_HEIGHT // 2 + 100
        slide_progress = self._ease_in_out(min(1.0, progress * 2.5))
        hero_y = int(start_y + (target_y - start_y) * slide_progress)

        # 글로우 효과 (호위무사 색상)
        guard_color = guard.get("color", (150, 150, 150))
        glow_alpha = int(60 + abs(math.sin(self.animation_timer * 3)) * 40)
        glow_radius = 80
        glow_surf = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*guard_color, glow_alpha), (glow_radius, glow_radius), glow_radius)
        self.screen.blit(glow_surf, (center_x - glow_radius, hero_y - glow_radius))

        # 영웅 캐릭터 이미지
        if self.hero_paddle_renderer:
            guard_id = guard.get("id", "mugen")
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, guard_id, center_x, hero_y, 120, 84,
                facing="down", color=guard_color, scale_mode="preview"
            )
        else:
            pygame.draw.circle(self.screen, guard_color, (center_x, hero_y), 40)
            pygame.draw.circle(self.screen, (255, 255, 255), (center_x, hero_y), 40, 2)

        # 텍스트 (페이드인, progress > 0.2)
        text_alpha = max(0, min(255, int((progress - 0.2) * 4 * 255)))

        if text_alpha > 0 and self.fonts:
            guard_name = guard.get("name", "???")
            guard_title = guard.get("title", "")

            # 밝기 보정
            brightness = sum(guard_color) / 3
            name_color = guard_color if brightness > 80 else (
                min(255, guard_color[0] + 100),
                min(255, guard_color[1] + 100),
                min(255, guard_color[2] + 100)
            )

            # 이름 (큰 글씨)
            if "large" in self.fonts:
                surf, _ = self.fonts["large"].render(guard_name, name_color)
                alpha_surf = pygame.Surface(surf.get_size(), pygame.SRCALPHA)
                alpha_surf.fill((255, 255, 255, text_alpha))
                surf.blit(alpha_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf, (center_x - surf.get_width() // 2, hero_y - 80))

            # 칭호 (작은 글씨)
            if "small" in self.fonts and guard_title:
                surf, _ = self.fonts["small"].render(guard_title, (200, 200, 200))
                alpha_surf = pygame.Surface(surf.get_size(), pygame.SRCALPHA)
                alpha_surf.fill((255, 255, 255, text_alpha))
                surf.blit(alpha_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf, (center_x - surf.get_width() // 2, hero_y + 60))

            # 메인 알림 메시지
            if "medium" in self.fonts:
                msg1 = f"{guard_name}을(를) 생포했습니다!"
                msg2 = "호위무사가 되어 함께 싸워줍니다!"

                gold_color = (255, 215, 0)

                surf1, _ = self.fonts["medium"].render(msg1, gold_color)
                alpha_surf1 = pygame.Surface(surf1.get_size(), pygame.SRCALPHA)
                alpha_surf1.fill((255, 255, 255, text_alpha))
                surf1.blit(alpha_surf1, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf1, (center_x - surf1.get_width() // 2, hero_y + 100))

                surf2, _ = self.fonts["medium"].render(msg2, gold_color)
                alpha_surf2 = pygame.Surface(surf2.get_size(), pygame.SRCALPHA)
                alpha_surf2.fill((255, 255, 255, text_alpha))
                surf2.blit(alpha_surf2, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf2, (center_x - surf2.get_width() // 2, hero_y + 130))

            # 호위무사 카운트
            if "small" in self.fonts and self.guard_notify_total > 0:
                count_msg = f"현재 호위무사: {self.guard_notify_total}명"
                surf, _ = self.fonts["small"].render(count_msg, (180, 180, 180))
                alpha_surf = pygame.Surface(surf.get_size(), pygame.SRCALPHA)
                alpha_surf.fill((255, 255, 255, text_alpha))
                surf.blit(alpha_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                self.screen.blit(surf, (center_x - surf.get_width() // 2, hero_y + 165))

        # 장식 파티클 (궤도 도는 금색 스파크)
        if progress > 0.3:
            particle_count = int((progress - 0.3) * 10)
            for i in range(min(particle_count, 6)):
                angle = self.animation_timer * 2 + i * (math.pi * 2 / 6)
                dist = 100 + math.sin(self.animation_timer * 3 + i) * 20
                px = center_x + int(math.cos(angle) * dist)
                py = hero_y + int(math.sin(angle) * dist * 0.6)
                spark_alpha = int(100 + abs(math.sin(self.animation_timer * 5 + i)) * 100)
                spark_surf = pygame.Surface((8, 8), pygame.SRCALPHA)
                pygame.draw.circle(spark_surf, (255, 215, 0, spark_alpha), (4, 4), 3)
                self.screen.blit(spark_surf, (px - 4, py - 4))

    def _draw_animated_bracket(self):
        """애니메이션이 적용된 대진표 그리기"""
        # 8강 매치 (하단) - 확대 레이아웃
        y_base = 530
        x_positions = [60, 195, 430, 565]

        for i, match in enumerate(self.matches[TournamentRound.QUARTER_FINAL]):
            x = x_positions[i]
            self._draw_animated_match_box(match, x, y_base, i, TournamentRound.QUARTER_FINAL)

        # 4강 매치 (중간) - 확대 레이아웃
        y_semi = 310
        x_semi = [127, 497]

        semi_matches = self.matches.get(TournamentRound.SEMI_FINAL, [])
        for i, match in enumerate(semi_matches):
            self._draw_animated_match_box(match, x_semi[i], y_semi, i + 4, TournamentRound.SEMI_FINAL)

        # 빈 4강 슬롯 또는 승자 이동 애니메이션
        if not semi_matches or len(semi_matches) < 2:
            for i, x in enumerate(x_semi):
                if self.bracket_anim_phase >= 1 and self.current_round == TournamentRound.QUARTER_FINAL:
                    self._draw_winner_moving_to_slot(x, y_semi, i)
                else:
                    self._draw_empty_match_box(x, y_semi, "준결승 " + str(i + 1))

        # 결승 (상단) - 확대 레이아웃
        y_final = 80
        x_final = 312

        final_matches = self.matches.get(TournamentRound.FINAL, [])
        if final_matches:
            self._draw_animated_match_box(final_matches[0], x_final, y_final, 6, TournamentRound.FINAL)
        else:
            if self.bracket_anim_phase >= 1 and self.current_round == TournamentRound.SEMI_FINAL:
                self._draw_winner_moving_to_slot(x_final, y_final, 0, is_final=True)
            else:
                self._draw_empty_match_box(x_final, y_final, "결승")

        # 연결선 그리기 (애니메이션 효과 포함)
        self._draw_animated_bracket_lines()

    def _draw_animated_match_box(self, match: Match, x: int, y: int, match_idx: int, round_type: TournamentRound):
        """애니메이션이 적용된 매치 박스 그리기 (대각선 레이아웃)"""
        box_w, box_h = 120, 140  # 대각선 레이아웃 크기

        # 현재 라운드의 완료된 매치인지 확인
        is_current_round_match = (round_type == self.current_round)

        # 박스 배경
        if match.completed:
            bg_color = (35, 55, 45)
        else:
            bg_color = (45, 50, 60)

        pygame.draw.rect(self.screen, bg_color, (x, y, box_w, box_h), border_radius=8)
        pygame.draw.rect(self.screen, (100, 105, 115), (x, y, box_w, box_h), 2, border_radius=8)

        # 대각선 (왼쪽 하단 → 오른쪽 상단)
        pygame.draw.line(self.screen, (80, 85, 95), (x + 5, y + box_h - 5), (x + box_w - 5, y + 5), 2)

        # === 영웅 1 (왼쪽 상단 삼각형) ===
        hero1 = match.hero1
        h1_is_loser = match.completed and match.winner != hero1
        h1_alpha = 255

        if h1_is_loser and is_current_round_match and self.bracket_anim_phase >= 0:
            h1_alpha = int(255 * (1.0 - self.bracket_anim_progress * 0.5))

        h1_color = hero1["color"]
        hero1_name = hero1.get("name", "???")
        hero1_rect = pygame.Rect(x + 5, y + 5, 55, 70)
        # 이름 색상 밝기 보정 (너무 어두우면 밝게)
        h1_brightness = sum(h1_color) / 3
        h1_base_color = h1_color if h1_brightness > 80 else (min(255, h1_color[0] + 100), min(255, h1_color[1] + 100), min(255, h1_color[2] + 100))

        # 영웅 1 이름 (상단 좌측)
        if self.fonts and "small" in self.fonts:
            name_color = h1_base_color if h1_alpha == 255 else tuple(int(c * 0.5) for c in h1_base_color)
            surf, _ = self.fonts["small"].render(hero1_name, name_color)
            self.screen.blit(surf, (x + 8, y + 8))

        # 영웅 1 캐릭터 이미지 (좌측 - 더 왼쪽으로, 60% 크게)
        if self.hero_paddle_renderer and h1_alpha > 100:
            hero1_id = hero1.get("id", "mugen")
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero1_id, x + 25, y + 55, 64, 45,
                facing="down", color=h1_color, scale_mode="preview"
            )

        # 패자 X 표시
        if h1_is_loser and is_current_round_match and self.bracket_anim_phase >= 0:
            x_progress = min(1.0, self.bracket_anim_progress * 2)
            if x_progress > 0:
                self._draw_loser_x(hero1_rect, x_progress)

        # === VS (중앙 원) ===
        vs_x = x + box_w // 2
        vs_y = y + box_h // 2
        pygame.draw.circle(self.screen, (60, 65, 75), (vs_x, vs_y), 16)
        pygame.draw.circle(self.screen, (100, 105, 115), (vs_x, vs_y), 16, 2)
        if self.fonts and "small" in self.fonts:
            surf, _ = self.fonts["small"].render("VS", (255, 215, 0))
            self.screen.blit(surf, (vs_x - surf.get_width() // 2, vs_y - surf.get_height() // 2))

        # === 영웅 2 (오른쪽 하단 삼각형) ===
        hero2 = match.hero2
        h2_is_loser = match.completed and match.winner != hero2
        h2_alpha = 255

        if h2_is_loser and is_current_round_match and self.bracket_anim_phase >= 0:
            h2_alpha = int(255 * (1.0 - self.bracket_anim_progress * 0.5))

        h2_color = hero2["color"]
        hero2_name = hero2.get("name", "???")
        hero2_rect = pygame.Rect(x + box_w - 60, y + box_h - 75, 55, 70)
        # 이름 색상 밝기 보정 (너무 어두우면 밝게)
        h2_brightness = sum(h2_color) / 3
        h2_base_color = h2_color if h2_brightness > 80 else (min(255, h2_color[0] + 100), min(255, h2_color[1] + 100), min(255, h2_color[2] + 100))

        # 영웅 2 캐릭터 이미지 (우측 - 더 오른쪽으로, 60% 크게)
        if self.hero_paddle_renderer and h2_alpha > 100:
            hero2_id = hero2.get("id", "chronos")
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero2_id, x + box_w - 25, y + box_h - 55, 64, 45,
                facing="down", color=h2_color, scale_mode="preview"
            )

        # 영웅 2 이름 (하단 우측)
        if self.fonts and "small" in self.fonts:
            name_color = h2_base_color if h2_alpha == 255 else tuple(int(c * 0.5) for c in h2_base_color)
            surf, _ = self.fonts["small"].render(hero2_name, name_color)
            self.screen.blit(surf, (x + box_w - surf.get_width() - 8, y + box_h - 22))

        # 패자 X 표시
        if h2_is_loser and is_current_round_match and self.bracket_anim_phase >= 0:
            x_progress = min(1.0, self.bracket_anim_progress * 2)
            if x_progress > 0:
                self._draw_loser_x(hero2_rect, x_progress)

        # 승자 하이라이트 효과
        if match.completed and match.winner and is_current_round_match:
            winner_rect = hero1_rect if match.winner == hero1 else hero2_rect
            if self.bracket_anim_phase >= 0:
                glow_alpha = int(abs(math.sin(self.animation_timer * 4)) * 100 + 50)
                glow_surface = pygame.Surface((winner_rect.width + 6, winner_rect.height + 6), pygame.SRCALPHA)
                pygame.draw.rect(glow_surface, (255, 215, 0, glow_alpha),
                               (0, 0, winner_rect.width + 6, winner_rect.height + 6),
                               border_radius=5)
                self.screen.blit(glow_surface, (winner_rect.x - 3, winner_rect.y - 3))

        # 결과 표시 (스코어)
        if match.completed and match.winner:
            if self.fonts and "small" in self.fonts:
                surf, _ = self.fonts["small"].render(f"{match.score1}:{match.score2}", (255, 215, 0))
                self.screen.blit(surf, (x + box_w // 2 - surf.get_width() // 2, y + box_h + 5))

    # ====================================================================
    # 커스텀 심볼 드로잉 (이모지 대체)
    # ====================================================================
    def _draw_sword_icon(self, x: int, y: int, size: int = 16, color: Tuple[int, int, int] = (255, 215, 0)):
        """교차 검 아이콘 (⚔ 대체)"""
        s = size // 2
        # 검 1 (\)
        pygame.draw.line(self.screen, color, (x - s, y - s), (x + s, y + s), 2)
        pygame.draw.line(self.screen, color, (x - s // 2, y - s + 2), (x + s // 2, y - s + 2), 2)  # 가드
        # 검 2 (/)
        pygame.draw.line(self.screen, color, (x + s, y - s), (x - s, y + s), 2)
        pygame.draw.line(self.screen, color, (x - s // 2, y + s - 2), (x + s // 2, y + s - 2), 2)  # 가드

    def _draw_crown_icon(self, x: int, y: int, size: int = 16, color: Tuple[int, int, int] = (255, 215, 0)):
        """왕관 아이콘 (👑 대체)"""
        s = size // 2
        # 왕관 몸체
        points = [
            (x - s, y + s // 2),
            (x - s, y - s // 3),
            (x - s // 2, y),
            (x, y - s),
            (x + s // 2, y),
            (x + s, y - s // 3),
            (x + s, y + s // 2),
        ]
        pygame.draw.polygon(self.screen, color, points)
        pygame.draw.polygon(self.screen, (200, 170, 0), points, 2)

    def _draw_trophy_icon(self, x: int, y: int, size: int = 16, color: Tuple[int, int, int] = (255, 215, 0)):
        """트로피 아이콘 (🏆 대체)"""
        s = size // 2
        # 컵 몸체
        pygame.draw.rect(self.screen, color, (x - s + 2, y - s, s * 2 - 4, s + 2), border_radius=3)
        # 손잡이
        pygame.draw.arc(self.screen, color, (x - s - 3, y - s + 2, 8, s), -1.5, 1.5, 2)
        pygame.draw.arc(self.screen, color, (x + s - 5, y - s + 2, 8, s), 1.5, 4.5, 2)
        # 받침대
        pygame.draw.rect(self.screen, color, (x - s // 3, y + 2, s // 3 * 2, s // 3))
        pygame.draw.rect(self.screen, color, (x - s // 2, y + 2 + s // 3, s, 3))

    def _draw_skull_icon(self, x: int, y: int, size: int = 16, color: Tuple[int, int, int] = (255, 100, 100)):
        """해골 아이콘 (💀 대체)"""
        s = size // 2
        # 머리
        pygame.draw.circle(self.screen, color, (x, y - 2), s - 1)
        # 턱
        pygame.draw.rect(self.screen, color, (x - s // 2, y + s // 3, s, s // 3))
        # 눈
        pygame.draw.circle(self.screen, (30, 30, 30), (x - s // 3, y - 3), s // 4)
        pygame.draw.circle(self.screen, (30, 30, 30), (x + s // 3, y - 3), s // 4)

    def _draw_fire_icon(self, x: int, y: int, size: int = 14, color: Tuple[int, int, int] = (255, 150, 50)):
        """불꽃 아이콘 (🔥 대체)"""
        s = size // 2
        # 외곽 불꽃
        points = [
            (x, y - s), (x + s // 2, y - s // 3),
            (x + s, y + s // 2), (x + s // 3, y + s),
            (x - s // 3, y + s), (x - s, y + s // 2),
            (x - s // 2, y - s // 3),
        ]
        pygame.draw.polygon(self.screen, color, points)
        # 내부 불꽃 (밝은 색)
        inner = [
            (x, y - s // 3), (x + s // 3, y),
            (x + s // 4, y + s // 2), (x - s // 4, y + s // 2),
            (x - s // 3, y),
        ]
        pygame.draw.polygon(self.screen, (255, 220, 100), inner)

    def _draw_coin_icon(self, x: int, y: int, size: int = 14, color: Tuple[int, int, int] = (255, 215, 0)):
        """동전 아이콘 (💰 대체)"""
        s = size // 2
        pygame.draw.circle(self.screen, color, (x, y), s)
        pygame.draw.circle(self.screen, (200, 170, 0), (x, y), s, 2)
        # G 텍스트
        if self.fonts and "small" in self.fonts:
            g_surf, _ = self.fonts["small"].render("G", (200, 170, 0))
            self.screen.blit(g_surf, (x - g_surf.get_width() // 2, y - g_surf.get_height() // 2))

    def _draw_warning_icon(self, x: int, y: int, size: int = 14, color: Tuple[int, int, int] = (255, 200, 50)):
        """경고 삼각형 아이콘 (⚠ 대체)"""
        s = size // 2
        # 삼각형
        points = [(x, y - s), (x + s, y + s), (x - s, y + s)]
        pygame.draw.polygon(self.screen, color, points)
        pygame.draw.polygon(self.screen, (200, 150, 0), points, 2)
        # 느낌표
        pygame.draw.line(self.screen, (40, 40, 40), (x, y - s // 3), (x, y + s // 4), 2)
        pygame.draw.circle(self.screen, (40, 40, 40), (x, y + s // 2), 1)

    def _draw_loser_x(self, rect: pygame.Rect, progress: float):
        """패자에게 X 표시 그리기"""
        # X 표시 애니메이션
        x_size = int(min(rect.width, rect.height) * 0.6 * progress)
        center_x = rect.centerx
        center_y = rect.centery

        # X 색상 (빨간색)
        x_color = (255, 60, 60)
        line_width = 4

        # 첫 번째 대각선 (\)
        if progress > 0:
            end_offset = int(x_size * min(1.0, progress * 2))
            pygame.draw.line(self.screen, x_color,
                           (center_x - end_offset, center_y - end_offset),
                           (center_x + end_offset, center_y + end_offset),
                           line_width)

        # 두 번째 대각선 (/)
        if progress > 0.5:
            second_progress = (progress - 0.5) * 2
            end_offset = int(x_size * second_progress)
            pygame.draw.line(self.screen, x_color,
                           (center_x + end_offset, center_y - end_offset),
                           (center_x - end_offset, center_y + end_offset),
                           line_width)

    def _draw_winner_moving_to_slot(self, target_x: int, target_y: int, slot_idx: int, is_final: bool = False):
        """승자가 다음 라운드 슬롯으로 이동하는 애니메이션"""
        box_w, box_h = 100, 100

        # 진행도에 따른 슬롯 표시
        if self.bracket_anim_phase >= 1:
            # 이동 중인 승자 표시
            progress = self.bracket_anim_progress

            # 시작 위치 계산
            if self.current_round == TournamentRound.QUARTER_FINAL:
                # 8강 → 4강
                if slot_idx == 0:
                    # 첫 두 매치 승자
                    winners = [self.matches[TournamentRound.QUARTER_FINAL][0].winner,
                              self.matches[TournamentRound.QUARTER_FINAL][1].winner]
                    start_positions = [(150, 550), (300, 550)]
                else:
                    # 뒤 두 매치 승자
                    winners = [self.matches[TournamentRound.QUARTER_FINAL][2].winner,
                              self.matches[TournamentRound.QUARTER_FINAL][3].winner]
                    start_positions = [(480, 550), (630, 550)]

                # 중간점
                mid_y = 520

                for i, (winner, start_pos) in enumerate(zip(winners, start_positions)):
                    if winner:
                        # 이징 함수 적용
                        t = self._ease_in_out(progress)

                        # 위치 계산
                        if progress < 0.5:
                            # 상승 + 수평 이동
                            p = progress * 2
                            current_x = start_pos[0] + (target_x + box_w // 2 - start_pos[0]) * p
                            current_y = start_pos[1] - (start_pos[1] - mid_y) * p
                        else:
                            # 하강 + 최종 위치
                            p = (progress - 0.5) * 2
                            current_x = target_x + box_w // 2
                            current_y = mid_y - (mid_y - target_y - box_h // 2) * p

                        # 승자 이름 그리기 (이동 중)
                        self._draw_moving_winner(winner, int(current_x), int(current_y), progress)

            elif self.current_round == TournamentRound.SEMI_FINAL and is_final:
                # 4강 → 결승
                semi_matches = self.matches.get(TournamentRound.SEMI_FINAL, [])
                if len(semi_matches) >= 2:
                    winners = [semi_matches[0].winner, semi_matches[1].winner]
                    start_positions = [(225, 380), (555, 380)]

                    mid_y = 340

                    for i, (winner, start_pos) in enumerate(zip(winners, start_positions)):
                        if winner:
                            t = self._ease_in_out(progress)

                            if progress < 0.5:
                                p = progress * 2
                                current_x = start_pos[0] + (target_x + box_w // 2 - start_pos[0]) * p
                                current_y = start_pos[1] - (start_pos[1] - mid_y) * p
                            else:
                                p = (progress - 0.5) * 2
                                current_x = target_x + box_w // 2
                                current_y = mid_y - (mid_y - target_y - box_h // 2) * p

                            self._draw_moving_winner(winner, int(current_x), int(current_y), progress)
        else:
            # 빈 슬롯
            self._draw_empty_match_box(target_x, target_y, "결승" if is_final else f"준결승 {slot_idx + 1}")

    def _draw_moving_winner(self, winner: dict, x: int, y: int, progress: float):
        """이동 중인 승자 표시 (캐릭터 아이콘 포함)"""
        # 글로우 효과
        glow_radius = 40 + int(abs(math.sin(self.animation_timer * 5)) * 10)
        glow_alpha = int(100 + progress * 100)

        glow_surface = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
        pygame.draw.circle(glow_surface, (*winner["color"], glow_alpha),
                         (glow_radius, glow_radius), glow_radius)
        self.screen.blit(glow_surface, (x - glow_radius, y - glow_radius))

        # 캐릭터 이미지 그리기
        if self.hero_paddle_renderer:
            hero_id = winner.get("id", "mugen")
            # 스케일 애니메이션 (이동 중 약간 커짐)
            scale_factor = 1.0 + progress * 0.2
            img_w = int(60 * scale_factor)
            img_h = int(42 * scale_factor)
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero_id, x, y, img_w, img_h,
                facing="down", color=winner["color"], scale_mode="preview"
            )
        else:
            # 폴백: 영웅 색상 원
            pygame.draw.circle(self.screen, winner["color"], (x, y), 25)
            pygame.draw.circle(self.screen, (255, 255, 255), (x, y), 25, 2)

        # 이름 표시
        if self.fonts and "small" in self.fonts:
            # 밝기 보정
            color = winner["color"]
            brightness = sum(color) / 3
            name_color = color if brightness > 80 else (min(255, color[0] + 100), min(255, color[1] + 100), min(255, color[2] + 100))
            surf, _ = self.fonts["small"].render(winner["name"], name_color)
            self.screen.blit(surf, (x - surf.get_width() // 2, y - 45))

    def _draw_vs_matchup_animation(self):
        """VS 매치업 애니메이션 (다음 경기 미리보기)"""
        if not self.selected_match:
            return

        hero1 = self.selected_match.hero1
        hero2 = self.selected_match.hero2
        progress = self.bracket_anim_progress

        # 라운드 이름
        round_names = {
            TournamentRound.QUARTER_FINAL: "8강전",
            TournamentRound.SEMI_FINAL: "4강전",
            TournamentRound.FINAL: "결승전",
        }
        round_name = round_names.get(self.current_round, "다음 경기")

        # 타이틀
        if self.fonts and "large" in self.fonts:
            pulse = abs(math.sin(self.animation_timer * 3)) * 0.3 + 0.7
            gold_color = (int(255 * pulse), int(215 * pulse), 0)
            title = round_name
            surf, _ = self.fonts["large"].render(title, gold_color)
            title_x = SCREEN_WIDTH // 2 - surf.get_width() // 2
            self.screen.blit(surf, (title_x, 80))
            icon_y = 80 + surf.get_height() // 2
            self._draw_sword_icon(title_x - 16, icon_y, 14, gold_color)
            self._draw_sword_icon(title_x + surf.get_width() + 16, icon_y, 14, gold_color)

        # 영웅 1 (왼쪽에서 슬라이드 인)
        hero1_target_x = SCREEN_WIDTH // 2 - 150
        hero1_start_x = -100
        hero1_x = int(hero1_start_x + (hero1_target_x - hero1_start_x) * self._ease_in_out(min(1.0, progress * 2)))
        hero1_y = SCREEN_HEIGHT // 2

        # 글로우 효과
        glow_alpha = int(80 + abs(math.sin(self.animation_timer * 4)) * 50)
        glow_surf = pygame.Surface((160, 160), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*hero1["color"], glow_alpha), (80, 80), 70)
        self.screen.blit(glow_surf, (hero1_x - 80, hero1_y - 80))

        # 캐릭터 이미지
        if self.hero_paddle_renderer:
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero1.get("id", "mugen"), hero1_x, hero1_y, 100, 70,
                facing="down", color=hero1["color"], scale_mode="preview"
            )

        # 이름 + 칭호
        if self.fonts:
            h1_color = hero1["color"]
            h1_brightness = sum(h1_color) / 3
            h1_name_color = h1_color if h1_brightness > 80 else (min(255, h1_color[0] + 100), min(255, h1_color[1] + 100), min(255, h1_color[2] + 100))
            if "medium" in self.fonts:
                surf, _ = self.fonts["medium"].render(hero1["name"], h1_name_color)
                self.screen.blit(surf, (hero1_x - surf.get_width() // 2, hero1_y - 70))
            if "small" in self.fonts:
                surf, _ = self.fonts["small"].render(hero1["title"], (200, 200, 200))
                self.screen.blit(surf, (hero1_x - surf.get_width() // 2, hero1_y + 55))

            # 호위무사 아이콘 (영웅1)
            h1_guards = self.guard_warrior_map.get(hero1.get("id"), [])
            if h1_guards and self.hero_paddle_renderer:
                guard_spacing = 60
                guard_start_x = hero1_x - (len(h1_guards) * guard_spacing) // 2
                guard_y = hero1_y + 90
                for gi, g in enumerate(h1_guards):
                    gx = guard_start_x + gi * guard_spacing + guard_spacing // 2
                    self.hero_paddle_renderer.draw_hero_paddle(
                        self.screen, g.get("id", "mugen"), gx, guard_y, 56, 40,
                        facing="down", color=g.get("color", (150, 150, 150)), scale_mode="preview"
                    )
                    if "small" in self.fonts:
                        g_name = g.get("name", "")
                        ns, _ = self.fonts["small"].render(g_name, (180, 180, 180))
                        self.screen.blit(ns, (gx - ns.get_width() // 2, guard_y + 28))

        # VS (중앙, 스케일 애니메이션)
        vs_scale = min(1.0, progress * 3) if progress < 0.5 else 1.0
        if self.fonts and "large" in self.fonts and vs_scale > 0.1:
            vs_color = (255, int(100 + abs(math.sin(self.animation_timer * 5)) * 100), 100)
            surf, _ = self.fonts["large"].render("VS", vs_color)
            # 스케일 적용
            if vs_scale < 1.0:
                scaled_w = int(surf.get_width() * vs_scale)
                scaled_h = int(surf.get_height() * vs_scale)
                if scaled_w > 0 and scaled_h > 0:
                    scaled_surf = pygame.transform.scale(surf, (scaled_w, scaled_h))
                    self.screen.blit(scaled_surf, (SCREEN_WIDTH // 2 - scaled_w // 2, SCREEN_HEIGHT // 2 - scaled_h // 2))
            else:
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, SCREEN_HEIGHT // 2 - surf.get_height() // 2))

        # 영웅 2 (오른쪽에서 슬라이드 인)
        hero2_target_x = SCREEN_WIDTH // 2 + 150
        hero2_start_x = SCREEN_WIDTH + 100
        hero2_x = int(hero2_start_x + (hero2_target_x - hero2_start_x) * self._ease_in_out(min(1.0, progress * 2)))
        hero2_y = SCREEN_HEIGHT // 2

        # 글로우 효과
        glow_surf = pygame.Surface((160, 160), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*hero2["color"], glow_alpha), (80, 80), 70)
        self.screen.blit(glow_surf, (hero2_x - 80, hero2_y - 80))

        # 캐릭터 이미지
        if self.hero_paddle_renderer:
            self.hero_paddle_renderer.draw_hero_paddle(
                self.screen, hero2.get("id", "chronos"), hero2_x, hero2_y, 100, 70,
                facing="down", color=hero2["color"], scale_mode="preview"
            )

        # 이름 + 칭호
        if self.fonts:
            h2_color = hero2["color"]
            h2_brightness = sum(h2_color) / 3
            h2_name_color = h2_color if h2_brightness > 80 else (min(255, h2_color[0] + 100), min(255, h2_color[1] + 100), min(255, h2_color[2] + 100))
            if "medium" in self.fonts:
                surf, _ = self.fonts["medium"].render(hero2["name"], h2_name_color)
                self.screen.blit(surf, (hero2_x - surf.get_width() // 2, hero2_y - 70))
            if "small" in self.fonts:
                surf, _ = self.fonts["small"].render(hero2["title"], (200, 200, 200))
                self.screen.blit(surf, (hero2_x - surf.get_width() // 2, hero2_y + 55))

            # 호위무사 아이콘 (영웅2)
            h2_guards = self.guard_warrior_map.get(hero2.get("id"), [])
            if h2_guards and self.hero_paddle_renderer:
                guard_spacing = 60
                guard_start_x = hero2_x - (len(h2_guards) * guard_spacing) // 2
                guard_y = hero2_y + 90
                for gi, g in enumerate(h2_guards):
                    gx = guard_start_x + gi * guard_spacing + guard_spacing // 2
                    self.hero_paddle_renderer.draw_hero_paddle(
                        self.screen, g.get("id", "mugen"), gx, guard_y, 56, 40,
                        facing="down", color=g.get("color", (150, 150, 150)), scale_mode="preview"
                    )
                    if "small" in self.fonts:
                        g_name = g.get("name", "")
                        ns, _ = self.fonts["small"].render(g_name, (180, 180, 180))
                        self.screen.blit(ns, (gx - ns.get_width() // 2, guard_y + 28))

        # 하단 힌트 (버튼 모드에서 버튼이 나타나기 전까지만 표시)
        show_buttons = getattr(self, 'vs_preview_show_buttons', False)
        if self.fonts and "small" in self.fonts:
            if show_buttons and getattr(self, 'vs_preview_timer', 0) >= 1.5:
                pass  # 버튼이 표시되면 힌트 숨김
            else:
                hint = "잠시 후 배틀이 시작됩니다..." if not show_buttons else "잠시 후 계속 여부를 선택합니다..."
                alpha = int(abs(math.sin(self.animation_timer * 2)) * 155 + 100)
                surf, _ = self.fonts["small"].render(hint, (alpha, alpha, alpha))
                self.screen.blit(surf, (SCREEN_WIDTH // 2 - surf.get_width() // 2, 650))

    def _ease_in_out(self, t: float) -> float:
        """이징 함수 (부드러운 시작과 끝)"""
        if t < 0.5:
            return 2 * t * t
        else:
            return 1 - pow(-2 * t + 2, 2) / 2

    def _draw_animated_bracket_lines(self):
        """애니메이션이 적용된 대진표 연결선 (대각선 레이아웃 box_h=140 기준)"""
        base_color = (100, 105, 115)
        highlight_color = (255, 215, 0)

        # 대각선 레이아웃 좌표 (box_w=120, box_h=140)
        q1_x, q2_x, q3_x, q4_x = 120, 255, 490, 625  # 8강 박스 중심
        s1_x, s2_x = 187, 557  # 4강 박스 중심
        f_x = 372  # 결승 박스 중심
        y_q_top, y_mid1, y_s_bottom = 530, 490, 450
        y_s_top, y_mid2, y_f_bottom = 310, 265, 220

        # 8강 → 4강 연결
        if self.current_round == TournamentRound.QUARTER_FINAL and self.bracket_anim_phase >= 1:
            progress = self.bracket_anim_progress

            # 좌측 (매치 0, 1)
            self._draw_animated_line((q1_x, y_q_top), (q1_x, y_mid1), progress, base_color, highlight_color)
            self._draw_animated_line((q2_x, y_q_top), (q2_x, y_mid1), progress, base_color, highlight_color)
            self._draw_animated_line((q1_x, y_mid1), (q2_x, y_mid1), progress, base_color, highlight_color)
            self._draw_animated_line((s1_x, y_mid1), (s1_x, y_s_bottom), progress, base_color, highlight_color)

            # 우측 (매치 2, 3)
            self._draw_animated_line((q3_x, y_q_top), (q3_x, y_mid1), progress, base_color, highlight_color)
            self._draw_animated_line((q4_x, y_q_top), (q4_x, y_mid1), progress, base_color, highlight_color)
            self._draw_animated_line((q3_x, y_mid1), (q4_x, y_mid1), progress, base_color, highlight_color)
            self._draw_animated_line((s2_x, y_mid1), (s2_x, y_s_bottom), progress, base_color, highlight_color)
        else:
            # 기본 라인
            pygame.draw.line(self.screen, base_color, (q1_x, y_q_top), (q1_x, y_mid1), 2)
            pygame.draw.line(self.screen, base_color, (q2_x, y_q_top), (q2_x, y_mid1), 2)
            pygame.draw.line(self.screen, base_color, (q1_x, y_mid1), (q2_x, y_mid1), 2)
            pygame.draw.line(self.screen, base_color, (s1_x, y_mid1), (s1_x, y_s_bottom), 2)
            pygame.draw.line(self.screen, base_color, (q3_x, y_q_top), (q3_x, y_mid1), 2)
            pygame.draw.line(self.screen, base_color, (q4_x, y_q_top), (q4_x, y_mid1), 2)
            pygame.draw.line(self.screen, base_color, (q3_x, y_mid1), (q4_x, y_mid1), 2)
            pygame.draw.line(self.screen, base_color, (s2_x, y_mid1), (s2_x, y_s_bottom), 2)

        # 4강 → 결승 연결
        if self.current_round == TournamentRound.SEMI_FINAL and self.bracket_anim_phase >= 1:
            progress = self.bracket_anim_progress
            self._draw_animated_line((s1_x, y_s_top), (s1_x, y_mid2), progress, base_color, highlight_color)
            self._draw_animated_line((s2_x, y_s_top), (s2_x, y_mid2), progress, base_color, highlight_color)
            self._draw_animated_line((s1_x, y_mid2), (s2_x, y_mid2), progress, base_color, highlight_color)
            self._draw_animated_line((f_x, y_mid2), (f_x, y_f_bottom), progress, base_color, highlight_color)
        else:
            pygame.draw.line(self.screen, base_color, (s1_x, y_s_top), (s1_x, y_mid2), 2)
            pygame.draw.line(self.screen, base_color, (s2_x, y_s_top), (s2_x, y_mid2), 2)
            pygame.draw.line(self.screen, base_color, (s1_x, y_mid2), (s2_x, y_mid2), 2)
            pygame.draw.line(self.screen, base_color, (f_x, y_mid2), (f_x, y_f_bottom), 2)

    def _draw_animated_line(self, start: tuple, end: tuple, progress: float,
                           base_color: tuple, highlight_color: tuple):
        """애니메이션이 적용된 라인 그리기"""
        # 베이스 라인
        pygame.draw.line(self.screen, base_color, start, end, 2)

        # 진행도에 따른 하이라이트
        if progress > 0:
            # 라인을 따라 움직이는 하이라이트
            current_end = (
                start[0] + (end[0] - start[0]) * progress,
                start[1] + (end[1] - start[1]) * progress
            )
            pygame.draw.line(self.screen, highlight_color, start, current_end, 3)

            # 끝점에 글로우 효과
            glow_size = 6
            glow_surface = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surface, (*highlight_color, 180), (glow_size, glow_size), glow_size)
            self.screen.blit(glow_surface, (int(current_end[0]) - glow_size, int(current_end[1]) - glow_size))

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
