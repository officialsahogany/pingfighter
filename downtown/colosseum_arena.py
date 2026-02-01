# downtown/colosseum_arena.py
# 고대 투기장 토너먼트 시스템

import pygame
import random
import math
import sys
import os
from enum import Enum
from typing import List, Dict, Optional, Tuple

# 상수
SCREEN_WIDTH = 760
SCREEN_HEIGHT = 750
GAME_AREA_X = 80
GAME_AREA_WIDTH = 600
PADDLE_WIDTH = 80
PADDLE_HEIGHT = 12
BALL_SIZE = 10
WIN_SCORE = 5  # 5점 선취 승리

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
        "id": "gallita",
        "name": "갤리타",
        "title": "폭풍의 여전사",
        "style": HeroStyle.AGGRESSIVE,
        "color": (60, 200, 120),
        "speed": 1.3,
        "reaction": 0.85,
        "power": 1.2,
        "accuracy": 0.8,
        "position": "top",
        "description": "번개처럼 빠른 공격이 특기인 여전사"
    },
    {
        "id": "archines",
        "name": "아르키네스",
        "title": "철벽의 수호자",
        "style": HeroStyle.DEFENSIVE,
        "color": (60, 120, 220),
        "speed": 0.9,
        "reaction": 1.2,
        "power": 0.8,
        "accuracy": 0.95,
        "position": "top",
        "description": "완벽한 수비로 상대를 지치게 만드는 전략가"
    },
    {
        "id": "chungkia",
        "name": "토키아",
        "title": "바위의 거인",
        "style": HeroStyle.DEFENSIVE,
        "color": (200, 140, 60),
        "speed": 0.8,
        "reaction": 1.3,
        "power": 0.9,
        "accuracy": 0.98,
        "position": "top",
        "description": "느리지만 절대 실수하지 않는 철벽 수비수"
    },
    {
        "id": "poineth",
        "name": "포이네스",
        "title": "그림자 암살자",
        "style": HeroStyle.TRICKY,
        "color": (160, 60, 200),
        "speed": 1.1,
        "reaction": 0.85,
        "power": 1.1,
        "accuracy": 0.75,
        "position": "top",
        "description": "예측 불가능한 움직임으로 상대를 혼란에 빠뜨림"
    },
]

# 하단 패들 영웅 (hero2 - 화면 아래쪽)
BOTTOM_HEROES = [
    {
        "id": "gestand",
        "name": "게스탄드",
        "title": "현명한 전술가",
        "style": HeroStyle.BALANCED,
        "color": (100, 160, 220),
        "speed": 1.0,
        "reaction": 1.1,
        "power": 0.95,
        "accuracy": 0.92,
        "position": "bottom",
        "description": "상대의 패턴을 분석하고 대응하는 지략가"
    },
    {
        "id": "bukandai",
        "name": "부칸다이",
        "title": "광기의 광대",
        "style": HeroStyle.TRICKY,
        "color": (220, 80, 180),
        "speed": 1.15,
        "reaction": 0.8,
        "power": 1.25,
        "accuracy": 0.7,
        "position": "bottom",
        "description": "미친듯이 강력하지만 불안정한 도박사"
    },
    {
        "id": "pinjo",
        "name": "핀조",
        "title": "불굴의 검투사",
        "style": HeroStyle.AGGRESSIVE,
        "color": (220, 60, 60),
        "speed": 1.2,
        "reaction": 0.9,
        "power": 1.3,
        "accuracy": 0.85,
        "position": "bottom",
        "description": "화끈한 공격으로 상대를 압도하는 베테랑 검투사"
    },
    {
        "id": "alexa",
        "name": "알렉사",
        "title": "황금의 창",
        "style": HeroStyle.BALANCED,
        "color": (220, 180, 60),
        "speed": 1.0,
        "reaction": 1.0,
        "power": 1.0,
        "accuracy": 0.9,
        "position": "bottom",
        "description": "모든 면에서 균형 잡힌 만능 전사"
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
# AI 패들 컨트롤러
# ============================================================================
class AIPaddleController:
    def __init__(self, hero: Dict, is_top: bool):
        self.hero = hero
        self.is_top = is_top
        self.x = GAME_AREA_X + GAME_AREA_WIDTH // 2 - PADDLE_WIDTH // 2
        self.y = 30 if is_top else SCREEN_HEIGHT - 50
        self.target_x = self.x
        self.speed = 6 * hero["speed"]
        self.reaction_delay = int(10 / hero["reaction"])
        self.reaction_timer = 0
        self.last_ball_x = 0

        # 스타일별 행동 패턴
        self.style = hero["style"]
        self.power = hero["power"]
        self.accuracy = hero["accuracy"]

    def update(self, ball_x: float, ball_y: float, ball_vy: float):
        """AI 패들 업데이트"""
        # 공이 자기 방향으로 올 때만 반응
        coming_towards = (ball_vy < 0 and self.is_top) or (ball_vy > 0 and not self.is_top)

        if coming_towards:
            self.reaction_timer += 1
            if self.reaction_timer >= self.reaction_delay:
                # 목표 위치 계산 (스타일에 따라 다름)
                if self.style == HeroStyle.AGGRESSIVE:
                    # 공격적: 공보다 약간 앞서서 이동
                    self.target_x = ball_x - PADDLE_WIDTH // 2 + random.randint(-15, 15)
                elif self.style == HeroStyle.DEFENSIVE:
                    # 수비적: 정확히 공 위치로
                    self.target_x = ball_x - PADDLE_WIDTH // 2
                elif self.style == HeroStyle.TRICKY:
                    # 트릭: 불규칙한 움직임
                    offset = random.randint(-30, 30)
                    self.target_x = ball_x - PADDLE_WIDTH // 2 + offset
                else:
                    # 균형: 약간의 오차
                    self.target_x = ball_x - PADDLE_WIDTH // 2 + random.randint(-5, 5)
        else:
            # 공이 멀어질 때는 중앙으로
            self.reaction_timer = 0
            center = GAME_AREA_X + GAME_AREA_WIDTH // 2 - PADDLE_WIDTH // 2
            self.target_x = self.target_x * 0.95 + center * 0.05

        # 목표 위치로 이동
        diff = self.target_x - self.x
        if abs(diff) > 2:
            move = min(abs(diff), self.speed) * (1 if diff > 0 else -1)
            self.x += move

        # 경계 체크
        self.x = max(GAME_AREA_X, min(self.x, GAME_AREA_X + GAME_AREA_WIDTH - PADDLE_WIDTH))

    def get_rect(self) -> pygame.Rect:
        return pygame.Rect(self.x, self.y, PADDLE_WIDTH, PADDLE_HEIGHT)

# ============================================================================
# 공 클래스
# ============================================================================
class ArenaBall:
    def __init__(self):
        self.reset()

    def reset(self, direction: int = 1):
        self.x = GAME_AREA_X + GAME_AREA_WIDTH // 2
        self.y = SCREEN_HEIGHT // 2
        angle = random.uniform(-0.3, 0.3)
        speed = 5
        self.vx = speed * math.sin(angle)
        self.vy = speed * direction

    def update(self) -> Optional[str]:
        """공 업데이트, 득점 시 'top' 또는 'bottom' 반환"""
        self.x += self.vx
        self.y += self.vy

        # 좌우 벽 반사
        if self.x <= GAME_AREA_X + BALL_SIZE:
            self.x = GAME_AREA_X + BALL_SIZE
            self.vx = -self.vx
        elif self.x >= GAME_AREA_X + GAME_AREA_WIDTH - BALL_SIZE:
            self.x = GAME_AREA_X + GAME_AREA_WIDTH - BALL_SIZE
            self.vx = -self.vx

        # 상하 득점 체크
        if self.y <= 0:
            return "bottom"  # 하단 플레이어 득점
        elif self.y >= SCREEN_HEIGHT:
            return "top"  # 상단 플레이어 득점

        return None

    def check_paddle_collision(self, paddle: AIPaddleController) -> bool:
        """패들 충돌 체크"""
        paddle_rect = paddle.get_rect()
        ball_rect = pygame.Rect(self.x - BALL_SIZE, self.y - BALL_SIZE,
                                BALL_SIZE * 2, BALL_SIZE * 2)

        if paddle_rect.colliderect(ball_rect):
            # 충돌 처리
            if paddle.is_top:
                self.y = paddle_rect.bottom + BALL_SIZE
                self.vy = abs(self.vy) * 1.02  # 약간 가속
            else:
                self.y = paddle_rect.top - BALL_SIZE
                self.vy = -abs(self.vy) * 1.02

            # 패들 위치에 따른 각도 변화
            hit_pos = (self.x - paddle.x) / PADDLE_WIDTH
            self.vx += (hit_pos - 0.5) * 3 * paddle.power

            # 최대 속도 제한
            max_speed = 12
            speed = math.sqrt(self.vx ** 2 + self.vy ** 2)
            if speed > max_speed:
                self.vx = self.vx / speed * max_speed
                self.vy = self.vy / speed * max_speed

            return True
        return False

# ============================================================================
# 토너먼트 시스템
# ============================================================================
class ColosseumsArena:
    def __init__(self, screen: pygame.Surface, fonts: Dict, player_gold: int):
        self.screen = screen
        self.fonts = fonts
        self.player_gold = player_gold

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

    def start_battle(self, match: Match):
        """배틀 시작"""
        self.selected_match = match
        self.battle_active = True
        self.score_top = 0
        self.score_bottom = 0

        # AI 패들 생성
        self.top_paddle = AIPaddleController(match.hero1, is_top=True)
        self.bottom_paddle = AIPaddleController(match.hero2, is_top=False)

        # 공 생성
        self.ball = ArenaBall()
        self.ball.reset(direction=1)

        self.state = TournamentState.BATTLE

    def update_battle(self) -> bool:
        """배틀 업데이트, 완료 시 True 반환"""
        if not self.battle_active:
            return False

        # AI 패들 업데이트
        self.top_paddle.update(self.ball.x, self.ball.y, self.ball.vy)
        self.bottom_paddle.update(self.ball.x, self.ball.y, self.ball.vy)

        # 공 업데이트
        scorer = self.ball.update()

        # 패들 충돌 체크
        self.ball.check_paddle_collision(self.top_paddle)
        self.ball.check_paddle_collision(self.bottom_paddle)

        # 득점 처리
        if scorer:
            if scorer == "top":
                self.score_top += 1
            else:
                self.score_bottom += 1

            # 승리 체크 (5점 선취, 4:4부터 듀스)
            if self._check_winner():
                return True

            # 공 리셋
            self.ball.reset(direction=1 if scorer == "bottom" else -1)

        return False

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
            self.update_battle()
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
            # 배팅 UI 클릭 처리
            panel_x, panel_y = 200, 200
            panel_w, panel_h = 360, 350

            # 영웅 1 선택 버튼
            btn1_rect = pygame.Rect(panel_x + 20, panel_y + 80, 150, 60)
            if btn1_rect.collidepoint(mx, my):
                self.bet_hero = self.selected_match.hero1
                return

            # 영웅 2 선택 버튼
            btn2_rect = pygame.Rect(panel_x + 190, panel_y + 80, 150, 60)
            if btn2_rect.collidepoint(mx, my):
                self.bet_hero = self.selected_match.hero2
                return

            # 배팅액 조절 버튼
            # -100
            if pygame.Rect(panel_x + 50, panel_y + 180, 50, 30).collidepoint(mx, my):
                self.bet_amount = max(100, self.bet_amount - 100)
                return
            # +100
            if pygame.Rect(panel_x + 260, panel_y + 180, 50, 30).collidepoint(mx, my):
                self.bet_amount = min(self.player_gold, self.bet_amount + 100)
                return
            # -500
            if pygame.Rect(panel_x + 50, panel_y + 220, 50, 30).collidepoint(mx, my):
                self.bet_amount = max(100, self.bet_amount - 500)
                return
            # +500
            if pygame.Rect(panel_x + 260, panel_y + 220, 50, 30).collidepoint(mx, my):
                self.bet_amount = min(self.player_gold, self.bet_amount + 500)
                return

            # 배팅 확정 버튼
            confirm_rect = pygame.Rect(panel_x + 80, panel_y + 280, 200, 50)
            if confirm_rect.collidepoint(mx, my) and self.bet_hero:
                self.start_battle(self.selected_match)
                return

            # 취소 버튼
            cancel_rect = pygame.Rect(panel_x + 130, panel_y + 340, 100, 35)
            if cancel_rect.collidepoint(mx, my):
                self.state = TournamentState.SELECT_MATCH
                self.bet_hero = None
                return

        elif self.state == TournamentState.RESULT:
            # 결과 화면 클릭 시 다음으로
            self.result_display_timer = 0

        elif self.state == TournamentState.ROUND_END:
            # 계속 배팅 버튼
            continue_rect = pygame.Rect(200, 400, 160, 50)
            if continue_rect.collidepoint(mx, my):
                self._advance_to_next_round()
                self.state = TournamentState.SELECT_MATCH
                return

            # 수익 확정하고 나가기 버튼
            exit_rect = pygame.Rect(400, 400, 160, 50)
            if exit_rect.collidepoint(mx, my):
                self.winnings_collected = True
                self.exit_requested = True
                return

        elif self.state == TournamentState.TOURNAMENT_END:
            # 종료 화면 클릭 시 나가기
            exit_rect = pygame.Rect(280, 450, 200, 50)
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
        # 배경
        self.screen.fill((20, 25, 30))

        # 콜로세움 배경 사용 (가능한 경우)
        if self.arena_background:
            self.arena_background.draw(self.screen, offset_x=GAME_AREA_X, offset_y=0)
        else:
            # 폴백: 기본 게임 영역
            pygame.draw.rect(self.screen, (194, 158, 108),  # 모래색
                            (GAME_AREA_X, 0, GAME_AREA_WIDTH, SCREEN_HEIGHT))

        # 중앙선 (모래 위에 그려진 라인)
        center_y = SCREEN_HEIGHT // 2
        pygame.draw.line(self.screen, (164, 128, 88),
                        (GAME_AREA_X + 30, center_y), (GAME_AREA_X + GAME_AREA_WIDTH - 30, center_y), 3)

        # 원형 경기장 라인
        pygame.draw.circle(self.screen, (164, 128, 88),
                          (GAME_AREA_X + GAME_AREA_WIDTH // 2, center_y), 120, 2)

        # 패들 그리기 (영웅 패들 렌더러 사용)
        if self.top_paddle and self.selected_match:
            paddle_rect = self.top_paddle.get_rect()
            hero1 = self.selected_match.hero1

            if self.hero_paddle_renderer:
                # 영웅 패들 렌더러로 그리기 (상단 영웅은 아래를 바라봄)
                self.hero_paddle_renderer.draw_hero_paddle(
                    self.screen,
                    hero1["id"],
                    paddle_rect.centerx,
                    paddle_rect.centery,
                    PADDLE_WIDTH,
                    PADDLE_HEIGHT,
                    facing="down",
                    color=hero1["color"]
                )
            else:
                # 폴백: 기본 패들
                shadow_rect = paddle_rect.copy()
                shadow_rect.y += 3
                pygame.draw.rect(self.screen, (60, 50, 40), shadow_rect, border_radius=4)
                pygame.draw.rect(self.screen, hero1["color"], paddle_rect, border_radius=4)

        if self.bottom_paddle and self.selected_match:
            paddle_rect = self.bottom_paddle.get_rect()
            hero2 = self.selected_match.hero2

            if self.hero_paddle_renderer:
                # 영웅 패들 렌더러로 그리기 (하단 영웅은 위를 바라봄)
                self.hero_paddle_renderer.draw_hero_paddle(
                    self.screen,
                    hero2["id"],
                    paddle_rect.centerx,
                    paddle_rect.centery,
                    PADDLE_WIDTH,
                    PADDLE_HEIGHT,
                    facing="up",
                    color=hero2["color"]
                )
            else:
                # 폴백: 기본 패들
                shadow_rect = paddle_rect.copy()
                shadow_rect.y += 3
                pygame.draw.rect(self.screen, (60, 50, 40), shadow_rect, border_radius=4)
                pygame.draw.rect(self.screen, hero2["color"], paddle_rect, border_radius=4)

        # 공 그리기 (그림자 포함)
        if self.ball:
            # 그림자
            pygame.draw.circle(self.screen, (60, 50, 40),
                             (int(self.ball.x) + 2, int(self.ball.y) + 3), BALL_SIZE)
            # 공
            pygame.draw.circle(self.screen, (255, 255, 255),
                             (int(self.ball.x), int(self.ball.y)), BALL_SIZE)
            # 하이라이트
            pygame.draw.circle(self.screen, (255, 255, 200),
                             (int(self.ball.x) - 3, int(self.ball.y) - 3), 3)

        # 필러 (사이드 UI)
        if self.arena_pillar:
            self.arena_pillar.draw(self.screen)

        # 점수판
        self._draw_scoreboard()

        # 영웅 정보
        self._draw_hero_info()

        # 전경 효과
        if self.arena_background:
            self.arena_background.draw_foreground(self.screen, offset_x=GAME_AREA_X, offset_y=0)

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
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("투기장 테스트")
    clock = pygame.time.Clock()

    # 폰트 (테스트용)
    import pygame.freetype
    fonts = {}
    try:
        fonts["small"] = pygame.freetype.Font(None, 16)
        fonts["medium"] = pygame.freetype.Font(None, 20)
        fonts["large"] = pygame.freetype.Font(None, 28)
    except:
        pass

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
