"""
패널티킥 미니게임 모듈 - 오락실 전용
FIFA 승부차기 룰: 5:5 교대 킥 + 서든데스
공격/수비 선택 가능
"""

import pygame
import pygame.freetype
import pygame.gfxdraw
import random
import math
import os
import sys
import time


def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)


# ============================================
# 상수
# ============================================
WIDTH = 760
HEIGHT = 750

# 골대 관련
GOAL_WIDTH = 400
GOAL_HEIGHT = 140
GOAL_X = (WIDTH - GOAL_WIDTH) // 2
GOAL_TOP_Y = 80  # 골대 상단 Y (공격 모드: 위쪽 골대)
GOAL_BOTTOM_Y = HEIGHT - 80 - GOAL_HEIGHT  # 수비 모드: 아래쪽 골대

# 골대 3등분 영역
GOAL_ZONE_WIDTH = GOAL_WIDTH // 3
GOAL_LEFT = 0
GOAL_CENTER = 1
GOAL_RIGHT = 2

# 공
BALL_RADIUS = 12
BALL_START_ATTACK_Y = HEIGHT - 150  # 공격 시 공 시작 위치
BALL_START_DEFENSE_Y = 150  # 수비 시 보스 공 시작

# 패들/골키퍼
KEEPER_WIDTH = 80
KEEPER_HEIGHT = 90

# 킥커
KICKER_WIDTH = 50
KICKER_HEIGHT = 70

# 파워 게이지
POWER_MAX = 100
POWER_CHARGE_SPEED = 1.8  # 프레임당 충전량
CURVE_CHARGE_SPEED = 1.2
ANGLE_CHARGE_SPEED = 1.5

# FIFA 룰
KICKS_PER_ROUND = 5  # 정규 5킥

# 색상
COLOR_GRASS = (34, 139, 34)
COLOR_GRASS_LIGHT = (50, 160, 50)
COLOR_GRASS_DARK = (28, 120, 28)
COLOR_LINE = (255, 255, 255)
COLOR_GOAL_POST = (220, 220, 220)
COLOR_GOAL_NET = (180, 180, 180, 120)
COLOR_BALL = (255, 255, 255)
COLOR_BALL_SHADOW = (20, 20, 20)
COLOR_GOLD = (255, 200, 50)
COLOR_RED = (220, 50, 50)
COLOR_BLUE = (50, 120, 220)
COLOR_DARK_BG = (15, 20, 15)
COLOR_WHITE = (255, 255, 255)
COLOR_GRAY = (150, 150, 150)
COLOR_BLACK = (0, 0, 0)


# ============================================
# 게임 상태
# ============================================
class GameState:
    ROLE_SELECT = "role_select"       # 공격/수비 선택
    AIM = "aim"                       # 조준 중 (공격 모드)
    CHARGING = "charging"             # 파워 충전 중 (스페이스바 홀딩)
    BALL_FLYING = "ball_flying"       # 공 날아가는 중
    DEFENSE_SELECT = "defense_select" # 수비 방향 선택
    KEEPER_DIVING = "keeper_diving"   # 골키퍼 다이빙 중
    GOAL_RESULT = "goal_result"       # 골/실패 결과
    ROUND_SUMMARY = "round_summary"   # 라운드 요약
    GAME_OVER = "game_over"           # 게임 종료


class Role:
    ATTACK = "attack"
    DEFENSE = "defense"


# ============================================
# 공 물리
# ============================================
class Ball:
    def __init__(self):
        self.reset()

    def reset(self):
        self.x = WIDTH // 2
        self.y = 0
        self.vx = 0
        self.vy = 0
        self.curve = 0  # 커브력 (-1 ~ 1)
        self.power = 0
        self.active = False
        self.trail = []  # 궤적
        self.rotation = 0
        self.scale = 1.0  # 원근감

    def launch(self, start_x, start_y, target_y, power, angle_offset, curve):
        """공 발사"""
        self.x = start_x
        self.y = start_y
        self.power = power
        self.curve = curve
        self.active = True
        self.trail = []

        # 목표까지 거리
        distance = abs(target_y - start_y)
        # 파워에 비례한 속도 (8~16)
        speed = 8 + (power / POWER_MAX) * 8

        # 방향 (위로 또는 아래로)
        direction = -1 if target_y < start_y else 1
        self.vy = speed * direction

        # 좌우 각도 (angle_offset: -1 ~ 1)
        self.vx = angle_offset * 4.5

        # 파워가 너무 세면 골대 위로 넘어갈 확률
        self.overshoot = power > 85 and random.random() < (power - 85) / 30

    def update(self):
        if not self.active:
            return

        # 커브 적용 (시간에 따라 vx에 영향)
        self.vx += self.curve * 0.12

        self.x += self.vx
        self.y += self.vy

        # 궤적 기록
        self.trail.append((self.x, self.y))
        if len(self.trail) > 30:
            self.trail.pop(0)

        # 공 회전
        self.rotation += self.vx * 3

        # 원근감 (공격 모드: 위로 갈수록 작아짐)
        if self.vy < 0:
            progress = 1 - max(0, (self.y - GOAL_TOP_Y)) / (BALL_START_ATTACK_Y - GOAL_TOP_Y)
            self.scale = 1.0 - progress * 0.35
        else:
            progress = max(0, (self.y - BALL_START_DEFENSE_Y)) / (GOAL_BOTTOM_Y - BALL_START_DEFENSE_Y)
            self.scale = 1.0 - (1 - progress) * 0.35

    def get_zone(self, goal_x, goal_width):
        """공이 골대의 어느 영역에 있는지"""
        zone_w = goal_width / 3
        if self.x < goal_x + zone_w:
            return GOAL_LEFT
        elif self.x < goal_x + zone_w * 2:
            return GOAL_CENTER
        else:
            return GOAL_RIGHT

    def is_in_goal(self, goal_x, goal_y, goal_width, goal_height):
        """공이 골대 안에 있는지"""
        return (goal_x <= self.x <= goal_x + goal_width and
                goal_y <= self.y <= goal_y + goal_height)

    def is_past_goal(self, goal_y, direction):
        """공이 골대를 지나갔는지"""
        if direction == -1:  # 위로
            return self.y < goal_y - 20
        else:  # 아래로
            return self.y > goal_y + GOAL_HEIGHT + 20


# ============================================
# 골키퍼
# ============================================
class Keeper:
    def __init__(self):
        self.x = WIDTH // 2
        self.y = 0
        self.target_x = WIDTH // 2
        self.dive_direction = None  # None, LEFT, CENTER, RIGHT
        self.diving = False
        self.dive_progress = 0
        self.dive_speed = 12
        self.start_x = WIDTH // 2

    def set_position(self, y):
        self.y = y
        self.x = WIDTH // 2
        self.target_x = WIDTH // 2
        self.dive_direction = None
        self.diving = False
        self.dive_progress = 0
        self.start_x = WIDTH // 2

    def decide_dive(self, direction):
        """다이빙 방향 결정"""
        self.dive_direction = direction
        self.diving = True
        self.dive_progress = 0
        self.start_x = self.x

        if direction == GOAL_LEFT:
            self.target_x = GOAL_X + GOAL_ZONE_WIDTH // 2
        elif direction == GOAL_RIGHT:
            self.target_x = GOAL_X + GOAL_WIDTH - GOAL_ZONE_WIDTH // 2
        else:  # CENTER
            self.target_x = WIDTH // 2

    def update(self):
        if self.diving and self.dive_direction is not None:
            self.dive_progress = min(1.0, self.dive_progress + 0.08)
            # 이징 함수 (빠르게 시작, 느리게 끝)
            ease = 1 - (1 - self.dive_progress) ** 3
            self.x = self.start_x + (self.target_x - self.start_x) * ease

    def is_saving(self, ball_zone):
        """골키퍼가 해당 영역을 막고 있는지"""
        return self.dive_direction == ball_zone


# ============================================
# 패널티킥 게임 UI
# ============================================
class PenaltyKickGameUI:
    """패널티킥 미니게임 UI"""

    def __init__(self, screen_width, screen_height, fonts=None):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.fonts = fonts
        self._font_cache = {}

        # 게임 상태
        self.state = GameState.ROLE_SELECT
        self.role = None  # 현재 킥의 역할 (공격/수비)
        self.first_role = None  # 처음 선택한 역할

        # FIFA 스코어
        self.player_score = 0
        self.boss_score = 0
        self.current_kick = 0  # 현재 킥 번호 (0~9, 이후 서든데스)
        self.kick_results = []  # [(attacker, result), ...]
        self.total_kicks = KICKS_PER_ROUND * 2  # 총 10킥
        self.is_sudden_death = False

        # 공격 조작 변수
        self.power = 0
        self.angle_offset = 0  # -1 ~ 1
        self.curve_amount = 0  # -1 ~ 1 (양수=우커브)
        self.charging = False
        self.space_held = False
        self.left_held = False
        self.right_held = False
        self.down_held = False

        # 방어 선택 변수
        self.defense_choice = GOAL_CENTER
        self.defense_confirmed = False

        # 게임 오브젝트
        self.ball = Ball()
        self.keeper = Keeper()

        # 보스 AI
        self.boss_kick_power = 0
        self.boss_kick_angle = 0
        self.boss_kick_curve = 0

        # 애니메이션
        self.animation_timer = 0
        self.result_timer = 0
        self.result_text = ""
        self.result_color = COLOR_WHITE
        self.goal_flash = 0
        self.particles = []

        # 잔디 스트라이프 캐시
        self.grass_stripes = []
        for i in range(25):
            self.grass_stripes.append(COLOR_GRASS_LIGHT if i % 2 == 0 else COLOR_GRASS)

        # 메뉴 선택
        self.menu_selection = 0  # 0=공격, 1=수비

        # 사운드 (나중에 연동)
        self.sound_kick = None
        self.sound_goal = None
        self.sound_save = None
        self.sound_whistle = None
        self._init_sounds()

        # 준비 타이머
        self.ready_timer = 0
        self.ready_text = ""

    def _init_sounds(self):
        """효과음 초기화"""
        try:
            current_dir = os.path.dirname(os.path.abspath(__file__))
            parent_dir = os.path.dirname(current_dir)
            sounds_dir = os.path.join(parent_dir, "sounds")
            # 나중에 전용 사운드 추가 가능
        except Exception:
            pass

    def _get_font(self, size):
        """폰트 캐시"""
        if size not in self._font_cache:
            if self.fonts and 'default' in self.fonts:
                try:
                    font_path = self.fonts['default']
                    self._font_cache[size] = pygame.freetype.Font(font_path, size)
                except Exception:
                    self._font_cache[size] = pygame.freetype.SysFont("Arial", size)
            else:
                self._font_cache[size] = pygame.freetype.SysFont("Arial", size)
        return self._font_cache[size]

    # ============================================
    # 게임 시작
    # ============================================
    def start_game(self):
        """게임 초기화 및 시작"""
        self.state = GameState.ROLE_SELECT
        self.player_score = 0
        self.boss_score = 0
        self.current_kick = 0
        self.kick_results = []
        self.is_sudden_death = False
        self.menu_selection = 0

    # ============================================
    # 이벤트 처리
    # ============================================
    def handle_event(self, event):
        """이벤트 처리 - 'exit' 반환 시 게임 종료"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                if self.state == GameState.ROLE_SELECT:
                    return 'exit'
                elif self.state == GameState.GAME_OVER:
                    return 'exit'
                # 게임 중 ESC는 무시

            # 역할 선택
            if self.state == GameState.ROLE_SELECT:
                return self._handle_role_select(event)

            # 공격 모드: 조준/충전
            elif self.state == GameState.AIM:
                return self._handle_aim(event)

            elif self.state == GameState.CHARGING:
                return self._handle_charging_keydown(event)

            # 수비 모드: 방향 선택
            elif self.state == GameState.DEFENSE_SELECT:
                return self._handle_defense_select(event)

            # 결과 화면
            elif self.state == GameState.GOAL_RESULT:
                return self._handle_result(event)

            # 라운드 요약
            elif self.state == GameState.ROUND_SUMMARY:
                return self._handle_summary(event)

            # 게임 오버
            elif self.state == GameState.GAME_OVER:
                if event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                    return 'exit'

        elif event.type == pygame.KEYUP:
            if self.state == GameState.CHARGING:
                return self._handle_charging_keyup(event)

        return None

    def _handle_role_select(self, event):
        """공격/수비 선택"""
        if event.key == pygame.K_LEFT or event.key == pygame.K_UP:
            self.menu_selection = 0
        elif event.key == pygame.K_RIGHT or event.key == pygame.K_DOWN:
            self.menu_selection = 1
        elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
            self.first_role = Role.ATTACK if self.menu_selection == 0 else Role.DEFENSE
            self._start_next_kick()
        return None

    def _handle_aim(self, event):
        """조준 시작 - 스페이스바 누르면 충전 시작"""
        if event.key == pygame.K_SPACE:
            self.state = GameState.CHARGING
            self.charging = True
            self.space_held = True
            self.power = 0
            self.angle_offset = 0
            self.curve_amount = 0
        return None

    def _handle_charging_keydown(self, event):
        """충전 중 키 다운"""
        if event.key == pygame.K_LEFT:
            self.left_held = True
        elif event.key == pygame.K_RIGHT:
            self.right_held = True
        elif event.key == pygame.K_DOWN:
            self.down_held = True
        return None

    def _handle_charging_keyup(self, event):
        """충전 중 키 업 - 스페이스바 떼면 발사"""
        if event.key == pygame.K_SPACE:
            self.space_held = False
            self.charging = False
            self._launch_player_kick()
        elif event.key == pygame.K_LEFT:
            self.left_held = False
        elif event.key == pygame.K_RIGHT:
            self.right_held = False
        elif event.key == pygame.K_DOWN:
            self.down_held = False
        return None

    def _handle_defense_select(self, event):
        """수비 방향 선택"""
        if event.key == pygame.K_LEFT:
            self.defense_choice = GOAL_LEFT
        elif event.key == pygame.K_RIGHT:
            self.defense_choice = GOAL_RIGHT
        elif event.key == pygame.K_DOWN or event.key == pygame.K_UP:
            self.defense_choice = GOAL_CENTER
        elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
            if not self.defense_confirmed:
                self.defense_confirmed = True
                self._launch_boss_kick()
        return None

    def _handle_result(self, event):
        """결과 확인 후 다음 진행"""
        if event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
            if self.result_timer > 60:
                self._check_game_end()
        return None

    def _handle_summary(self, event):
        """라운드 요약 후 다음"""
        if event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
            return None
        return None

    # ============================================
    # 게임 로직
    # ============================================
    def _start_next_kick(self):
        """다음 킥 시작"""
        self.ball.reset()
        self.power = 0
        self.angle_offset = 0
        self.curve_amount = 0
        self.left_held = False
        self.right_held = False
        self.down_held = False
        self.space_held = False
        self.charging = False
        self.defense_confirmed = False
        self.result_timer = 0
        self.ready_timer = 90  # 1.5초 준비 시간

        # 짝수 킥: 첫번째 역할, 홀수 킥: 반대 역할 (교대)
        if self.current_kick % 2 == 0:
            self.role = self.first_role
        else:
            self.role = Role.DEFENSE if self.first_role == Role.ATTACK else Role.ATTACK

        if self.role == Role.ATTACK:
            # 플레이어 공격 모드
            self.ball.x = WIDTH // 2
            self.ball.y = BALL_START_ATTACK_Y
            self.keeper.set_position(GOAL_TOP_Y + GOAL_HEIGHT // 2 - KEEPER_HEIGHT // 2)
            self.state = GameState.AIM
            self.ready_text = "KICK!"
        else:
            # 플레이어 수비 모드
            self.ball.x = WIDTH // 2
            self.ball.y = BALL_START_DEFENSE_Y
            self.keeper.set_position(GOAL_BOTTOM_Y + GOAL_HEIGHT // 2 - KEEPER_HEIGHT // 2)
            self.defense_choice = GOAL_CENTER
            self.state = GameState.DEFENSE_SELECT
            self.ready_text = "SAVE!"

            # 보스 AI 킥 파라미터 미리 결정
            self.boss_kick_power = random.randint(55, 90)
            self.boss_kick_angle = random.uniform(-0.8, 0.8)
            self.boss_kick_curve = random.uniform(-0.6, 0.6)

    def _launch_player_kick(self):
        """플레이어 킥 발사"""
        self.state = GameState.BALL_FLYING

        # 보스 골키퍼 랜덤 다이빙 결정
        boss_dive = random.choice([GOAL_LEFT, GOAL_CENTER, GOAL_RIGHT])
        self.keeper.decide_dive(boss_dive)

        # 공 발사
        self.ball.launch(
            start_x=WIDTH // 2,
            start_y=BALL_START_ATTACK_Y,
            target_y=GOAL_TOP_Y + GOAL_HEIGHT // 2,
            power=self.power,
            angle_offset=self.angle_offset,
            curve=self.curve_amount
        )

        self._spawn_kick_particles(WIDTH // 2, BALL_START_ATTACK_Y)

    def _launch_boss_kick(self):
        """보스 킥 발사 + 플레이어 골키퍼 다이빙"""
        self.state = GameState.BALL_FLYING

        # 플레이어 골키퍼 다이빙
        self.keeper.decide_dive(self.defense_choice)

        # 보스 공 발사 (위에서 아래로)
        self.ball.launch(
            start_x=WIDTH // 2,
            start_y=BALL_START_DEFENSE_Y,
            target_y=GOAL_BOTTOM_Y + GOAL_HEIGHT // 2,
            power=self.boss_kick_power,
            angle_offset=self.boss_kick_angle,
            curve=self.boss_kick_curve
        )

        self._spawn_kick_particles(WIDTH // 2, BALL_START_DEFENSE_Y)

    def _check_ball_result(self):
        """공의 결과 판정"""
        if self.role == Role.ATTACK:
            goal_x = GOAL_X
            goal_y = GOAL_TOP_Y
            direction = -1
        else:
            goal_x = GOAL_X
            goal_y = GOAL_BOTTOM_Y
            direction = 1

        # 공이 골대를 지나갔는지
        if self.ball.is_past_goal(goal_y, direction):
            ball_zone = self.ball.get_zone(goal_x, GOAL_WIDTH)
            in_goal = self.ball.is_in_goal(goal_x, goal_y, GOAL_WIDTH, GOAL_HEIGHT)

            # 오버슈트 (파워 너무 강하면 위로 넘어감)
            if self.ball.overshoot:
                in_goal = False

            # 골대 밖 (좌우로 벗어남)
            if self.ball.x < goal_x or self.ball.x > goal_x + GOAL_WIDTH:
                in_goal = False

            if in_goal:
                # 골키퍼가 막았는지 확인
                if self.keeper.is_saving(ball_zone):
                    # 세이브!
                    self._show_result("SAVE!", COLOR_RED if self.role == Role.ATTACK else COLOR_BLUE)
                    is_goal = False
                else:
                    # 골!
                    self._show_result("GOAL!", COLOR_GOLD)
                    is_goal = True
                    self.goal_flash = 30
                    self._spawn_goal_particles()
            else:
                # 빗나감
                self._show_result("MISS!", COLOR_GRAY)
                is_goal = False

            # 스코어 업데이트
            if self.role == Role.ATTACK:
                if is_goal:
                    self.player_score += 1
                self.kick_results.append(("player", is_goal))
            else:
                if is_goal:
                    self.boss_score += 1
                self.kick_results.append(("boss", is_goal))

            self.ball.active = False
            self.state = GameState.GOAL_RESULT
            self.current_kick += 1
            return True

        return False

    def _show_result(self, text, color):
        """결과 텍스트 표시"""
        self.result_text = text
        self.result_color = color
        self.result_timer = 0

    def _check_game_end(self):
        """게임 종료 조건 확인"""
        # 정규 10킥 완료
        if self.current_kick >= self.total_kicks and not self.is_sudden_death:
            if self.player_score != self.boss_score:
                self.state = GameState.GAME_OVER
                return
            else:
                # 동점 → 서든데스
                self.is_sudden_death = True

        # 서든데스 (2킥 단위로 체크)
        if self.is_sudden_death and self.current_kick % 2 == 0:
            sd_kicks = self.current_kick - self.total_kicks
            if sd_kicks >= 2:  # 최소 2킥 후 체크
                # 서든데스에서의 득점 비교
                sd_player = sum(1 for a, g in self.kick_results[self.total_kicks:] if a == "player" and g)
                sd_boss = sum(1 for a, g in self.kick_results[self.total_kicks:] if a == "boss" and g)
                if sd_player != sd_boss:
                    self.state = GameState.GAME_OVER
                    return

        # 정규전 중 조기 종료 판단
        if not self.is_sudden_death and self.current_kick < self.total_kicks:
            remaining = self.total_kicks - self.current_kick
            # 플레이어 남은 킥
            player_remaining = sum(1 for i in range(self.current_kick, self.total_kicks) if self._is_player_kick(i))
            boss_remaining = remaining - player_remaining

            # 상대가 남은 킥 다 넣어도 못 이기면 조기 종료
            if self.player_score > self.boss_score + boss_remaining:
                self.state = GameState.GAME_OVER
                return
            if self.boss_score > self.player_score + player_remaining:
                self.state = GameState.GAME_OVER
                return

        # 다음 킥
        self._start_next_kick()

    def _is_player_kick(self, kick_index):
        """해당 킥이 플레이어 공격인지"""
        if kick_index % 2 == 0:
            return self.first_role == Role.ATTACK
        else:
            return self.first_role == Role.DEFENSE

    # ============================================
    # 업데이트
    # ============================================
    def update(self, dt):
        """매 프레임 업데이트"""
        self.animation_timer += 1

        # 준비 타이머
        if self.ready_timer > 0:
            self.ready_timer -= 1
            if self.ready_timer <= 0:
                # AIM이나 DEFENSE_SELECT 상태 유지
                pass

        # 충전 중
        if self.state == GameState.CHARGING and self.space_held:
            # 파워 충전
            self.power = min(POWER_MAX, self.power + POWER_CHARGE_SPEED)

            # 방향 충전
            if self.left_held:
                self.angle_offset = max(-1.0, self.angle_offset - ANGLE_CHARGE_SPEED / POWER_MAX)
            if self.right_held:
                self.angle_offset = min(1.0, self.angle_offset + ANGLE_CHARGE_SPEED / POWER_MAX)

            # 커브 충전
            if self.down_held:
                # 방향키에 따라 커브 방향 결정
                if self.left_held:
                    self.curve_amount = max(-1.0, self.curve_amount - CURVE_CHARGE_SPEED / POWER_MAX)
                elif self.right_held:
                    self.curve_amount = min(1.0, self.curve_amount + CURVE_CHARGE_SPEED / POWER_MAX)
                else:
                    # 아래키만 누르면 랜덤 방향 커브 증가 (절대값)
                    if self.curve_amount >= 0:
                        self.curve_amount = min(1.0, self.curve_amount + CURVE_CHARGE_SPEED / POWER_MAX)
                    else:
                        self.curve_amount = max(-1.0, self.curve_amount - CURVE_CHARGE_SPEED / POWER_MAX)

        # 공 비행 중
        if self.state == GameState.BALL_FLYING:
            self.ball.update()
            self.keeper.update()
            self._check_ball_result()

        # 결과 타이머
        if self.state == GameState.GOAL_RESULT:
            self.result_timer += 1
            if self.result_timer > 120:
                self._check_game_end()

        # 골 플래시
        if self.goal_flash > 0:
            self.goal_flash -= 1

        # 파티클 업데이트
        self._update_particles()

    # ============================================
    # 파티클
    # ============================================
    def _spawn_kick_particles(self, x, y):
        """킥 시 먼지 파티클"""
        for _ in range(15):
            self.particles.append({
                'x': x + random.randint(-15, 15),
                'y': y + random.randint(-5, 5),
                'vx': random.uniform(-3, 3),
                'vy': random.uniform(-4, 0),
                'life': random.randint(15, 30),
                'max_life': 30,
                'color': (139, 119, 101),
                'size': random.randint(3, 6)
            })

    def _spawn_goal_particles(self):
        """골 시 축하 파티클"""
        cx, cy = WIDTH // 2, HEIGHT // 2
        for _ in range(40):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2, 8)
            self.particles.append({
                'x': cx,
                'y': cy,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': random.randint(30, 60),
                'max_life': 60,
                'color': random.choice([COLOR_GOLD, COLOR_WHITE, COLOR_RED, (50, 200, 50)]),
                'size': random.randint(3, 8)
            })

    def _update_particles(self):
        """파티클 업데이트"""
        for p in self.particles[:]:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['vy'] += 0.15  # 중력
            p['life'] -= 1
            if p['life'] <= 0:
                self.particles.remove(p)

    # ============================================
    # 렌더링
    # ============================================
    def draw(self, screen):
        """메인 드로우"""
        if self.state == GameState.ROLE_SELECT:
            self._draw_role_select(screen)
        elif self.state == GameState.GAME_OVER:
            self._draw_game_over(screen)
        else:
            self._draw_field(screen)
            self._draw_goal(screen)
            self._draw_characters(screen)
            self._draw_ball(screen)
            self._draw_particles(screen)
            self._draw_hud(screen)

            if self.state == GameState.AIM or self.state == GameState.CHARGING:
                self._draw_aim_ui(screen)
            elif self.state == GameState.DEFENSE_SELECT:
                self._draw_defense_ui(screen)

            if self.state == GameState.GOAL_RESULT:
                self._draw_result_text(screen)

            if self.ready_timer > 0:
                self._draw_ready(screen)

    def _draw_field(self, screen):
        """축구장 필드"""
        # 잔디 스트라이프
        stripe_h = HEIGHT // len(self.grass_stripes)
        for i, color in enumerate(self.grass_stripes):
            pygame.draw.rect(screen, color, (0, i * stripe_h, WIDTH, stripe_h))

        # 중앙선
        pygame.draw.line(screen, COLOR_LINE, (60, HEIGHT // 2), (WIDTH - 60, HEIGHT // 2), 2)

        # 중앙 원
        pygame.draw.circle(screen, COLOR_LINE, (WIDTH // 2, HEIGHT // 2), 60, 2)
        pygame.draw.circle(screen, COLOR_LINE, (WIDTH // 2, HEIGHT // 2), 4)

        # 페널티 박스 (상단)
        box_w = 360
        box_h = 160
        box_x = (WIDTH - box_w) // 2
        pygame.draw.rect(screen, COLOR_LINE, (box_x, 0, box_w, box_h), 2)
        # 페널티 아크
        pygame.draw.arc(screen, COLOR_LINE,
                       (WIDTH // 2 - 60, box_h - 30, 120, 60),
                       0, math.pi, 2)

        # 페널티 박스 (하단)
        pygame.draw.rect(screen, COLOR_LINE, (box_x, HEIGHT - box_h, box_w, box_h), 2)
        pygame.draw.arc(screen, COLOR_LINE,
                       (WIDTH // 2 - 60, HEIGHT - box_h - 30, 120, 60),
                       math.pi, math.pi * 2, 2)

        # 페널티 스팟
        pygame.draw.circle(screen, COLOR_LINE, (WIDTH // 2, 130), 4)
        pygame.draw.circle(screen, COLOR_LINE, (WIDTH // 2, HEIGHT - 130), 4)

        # 골 플래시
        if self.goal_flash > 0:
            flash_alpha = int((self.goal_flash / 30) * 80)
            flash_surf = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            flash_surf.fill((255, 215, 0, flash_alpha))
            screen.blit(flash_surf, (0, 0))

    def _draw_goal(self, screen):
        """골대 렌더링"""
        # 상단 골대
        self._draw_single_goal(screen, GOAL_X, GOAL_TOP_Y, GOAL_WIDTH, GOAL_HEIGHT, top=True)
        # 하단 골대
        self._draw_single_goal(screen, GOAL_X, GOAL_BOTTOM_Y, GOAL_WIDTH, GOAL_HEIGHT, top=False)

    def _draw_single_goal(self, screen, x, y, w, h, top=True):
        """개별 골대 그리기"""
        # 골 네트 배경
        net_surf = pygame.Surface((w, h), pygame.SRCALPHA)
        net_surf.fill((255, 255, 255, 30))

        # 네트 라인
        for i in range(0, w, 15):
            pygame.draw.line(net_surf, (255, 255, 255, 50), (i, 0), (i, h))
        for j in range(0, h, 15):
            pygame.draw.line(net_surf, (255, 255, 255, 50), (0, j), (w, j))
        screen.blit(net_surf, (x, y))

        # 골 포스트
        post_w = 6
        pygame.draw.rect(screen, COLOR_GOAL_POST, (x - post_w // 2, y, post_w, h))  # 좌
        pygame.draw.rect(screen, COLOR_GOAL_POST, (x + w - post_w // 2, y, post_w, h))  # 우

        # 크로스바
        if top:
            pygame.draw.rect(screen, COLOR_GOAL_POST, (x, y + h - 3, w, 6))
        else:
            pygame.draw.rect(screen, COLOR_GOAL_POST, (x, y - 3, w, 6))

        # 3등분 가이드 (반투명)
        guide_surf = pygame.Surface((w, h), pygame.SRCALPHA)
        zone_w = w // 3
        for i in range(1, 3):
            pygame.draw.line(guide_surf, (255, 255, 255, 40),
                           (zone_w * i, 0), (zone_w * i, h), 1)
        screen.blit(guide_surf, (x, y))

    def _draw_characters(self, screen):
        """캐릭터 렌더링"""
        if self.role == Role.ATTACK:
            # 보스 = 골키퍼 (상단)
            self._draw_keeper(screen, self.keeper.x, self.keeper.y, is_boss=True)
            # 플레이어 = 킥커 (하단)
            self._draw_kicker(screen, WIDTH // 2, BALL_START_ATTACK_Y + 30, is_boss=False)
        else:
            # 보스 = 킥커 (상단)
            self._draw_kicker(screen, WIDTH // 2, BALL_START_DEFENSE_Y - 30, is_boss=True)
            # 플레이어 = 골키퍼 (하단)
            self._draw_keeper(screen, self.keeper.x, self.keeper.y, is_boss=False)

    def _draw_keeper(self, screen, x, y, is_boss=False):
        """골키퍼 그리기"""
        # 그림자
        shadow_surf = pygame.Surface((KEEPER_WIDTH + 10, 15), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 60),
                          (0, 0, KEEPER_WIDTH + 10, 15))
        screen.blit(shadow_surf, (x - KEEPER_WIDTH // 2 - 5, y + KEEPER_HEIGHT - 5))

        # 몸체
        body_color = (200, 60, 60) if is_boss else (60, 120, 200)
        glove_color = (255, 180, 0)

        # 다리
        leg_w, leg_h = 12, 25
        pygame.draw.rect(screen, (50, 50, 50),
                        (x - 15, y + KEEPER_HEIGHT - 30, leg_w, leg_h))
        pygame.draw.rect(screen, (50, 50, 50),
                        (x + 3, y + KEEPER_HEIGHT - 30, leg_w, leg_h))

        # 상의
        torso_rect = pygame.Rect(x - KEEPER_WIDTH // 4, y + 15, KEEPER_WIDTH // 2, 40)
        pygame.draw.rect(screen, body_color, torso_rect, border_radius=5)

        # 번호
        font = self._get_font(14)
        num = "1" if not is_boss else "1"
        font.render_to(screen, (x - 4, y + 28), num, COLOR_WHITE)

        # 머리
        head_r = 14
        pygame.draw.circle(screen, (230, 190, 150), (x, y + 10), head_r)
        # 머리카락
        hair_color = (40, 30, 20) if is_boss else (80, 60, 40)
        pygame.draw.arc(screen, hair_color, (x - head_r, y - 5, head_r * 2, head_r),
                       0, math.pi, 4)

        # 글러브 (다이빙 방향으로)
        if self.keeper.diving:
            dive_offset = (self.keeper.x - WIDTH // 2) * 0.3
            # 왼팔
            pygame.draw.circle(screen, glove_color,
                             (int(x - 30 + dive_offset), int(y + 25)), 10)
            # 오른팔
            pygame.draw.circle(screen, glove_color,
                             (int(x + 30 + dive_offset), int(y + 25)), 10)
        else:
            pygame.draw.circle(screen, glove_color, (x - 25, y + 30), 10)
            pygame.draw.circle(screen, glove_color, (x + 25, y + 30), 10)

    def _draw_kicker(self, screen, x, y, is_boss=False):
        """킥커 그리기"""
        body_color = (200, 60, 60) if is_boss else (60, 120, 200)

        # 그림자
        shadow_surf = pygame.Surface((KICKER_WIDTH + 10, 12), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 60),
                          (0, 0, KICKER_WIDTH + 10, 12))
        screen.blit(shadow_surf, (x - KICKER_WIDTH // 2 - 5, y + KICKER_HEIGHT - 5))

        # 다리
        pygame.draw.rect(screen, (50, 50, 50),
                        (x - 12, y + KICKER_HEIGHT - 25, 10, 22))
        pygame.draw.rect(screen, (50, 50, 50),
                        (x + 2, y + KICKER_HEIGHT - 25, 10, 22))

        # 상의
        torso_rect = pygame.Rect(x - KICKER_WIDTH // 4, y + 15, KICKER_WIDTH // 2, 35)
        pygame.draw.rect(screen, body_color, torso_rect, border_radius=5)

        # 번호
        font = self._get_font(14)
        num = "10" if not is_boss else "9"
        font.render_to(screen, (x - 7, y + 25), num, COLOR_WHITE)

        # 머리
        head_r = 12
        pygame.draw.circle(screen, (230, 190, 150), (x, y + 10), head_r)

    def _draw_ball(self, screen):
        """공 그리기"""
        if not self.ball.active and self.state not in (GameState.AIM, GameState.CHARGING, GameState.DEFENSE_SELECT):
            return

        bx, by = self.ball.x, self.ball.y

        if not self.ball.active:
            # 대기 중인 공
            if self.role == Role.ATTACK:
                bx, by = WIDTH // 2, BALL_START_ATTACK_Y
            else:
                bx, by = WIDTH // 2, BALL_START_DEFENSE_Y

        # 궤적
        if self.ball.active and len(self.ball.trail) > 1:
            for i, (tx, ty) in enumerate(self.ball.trail):
                alpha = int(255 * (i / len(self.ball.trail)) * 0.4)
                r = max(2, int(BALL_RADIUS * 0.5 * (i / len(self.ball.trail))))
                trail_surf = pygame.Surface((r * 2, r * 2), pygame.SRCALPHA)
                pygame.draw.circle(trail_surf, (255, 255, 255, alpha), (r, r), r)
                screen.blit(trail_surf, (int(tx) - r, int(ty) - r))

        # 그림자
        shadow_y = by + 15
        shadow_r = int(BALL_RADIUS * self.ball.scale * 0.8)
        shadow_surf = pygame.Surface((shadow_r * 4, shadow_r * 2), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, 40),
                          (0, 0, shadow_r * 4, shadow_r * 2))
        screen.blit(shadow_surf, (int(bx) - shadow_r * 2, int(shadow_y) - shadow_r))

        # 공
        r = max(4, int(BALL_RADIUS * self.ball.scale))
        pygame.draw.circle(screen, COLOR_BALL, (int(bx), int(by)), r)
        pygame.draw.circle(screen, (200, 200, 200), (int(bx), int(by)), r, 2)

        # 오각형 패턴 (축구공)
        pent_r = r * 0.4
        for angle_offset in range(0, 360, 72):
            a = math.radians(angle_offset + self.ball.rotation)
            px = bx + math.cos(a) * pent_r
            py = by + math.sin(a) * pent_r
            pygame.draw.circle(screen, (50, 50, 50), (int(px), int(py)), max(1, int(r * 0.15)))

    def _draw_particles(self, screen):
        """파티클 렌더링"""
        for p in self.particles:
            alpha = int(255 * (p['life'] / p['max_life']))
            s = max(1, int(p['size'] * (p['life'] / p['max_life'])))
            surf = pygame.Surface((s * 2, s * 2), pygame.SRCALPHA)
            color = (*p['color'][:3], alpha)
            pygame.draw.circle(surf, color, (s, s), s)
            screen.blit(surf, (int(p['x']) - s, int(p['y']) - s))

    def _draw_hud(self, screen):
        """스코어보드 HUD"""
        # 상단 스코어 바
        hud_h = 50
        hud_surf = pygame.Surface((WIDTH, hud_h), pygame.SRCALPHA)
        hud_surf.fill((0, 0, 0, 160))
        screen.blit(hud_surf, (0, 0))

        font_big = self._get_font(24)
        font_sm = self._get_font(14)

        # 플레이어 스코어
        font_big.render_to(screen, (WIDTH // 2 - 80, 12), str(self.player_score), COLOR_BLUE)
        font_sm.render_to(screen, (WIDTH // 2 - 80, 35), "PLAYER", COLOR_BLUE)

        # VS
        font_big.render_to(screen, (WIDTH // 2 - 10, 12), "-", COLOR_WHITE)

        # 보스 스코어
        font_big.render_to(screen, (WIDTH // 2 + 55, 12), str(self.boss_score), COLOR_RED)
        font_sm.render_to(screen, (WIDTH // 2 + 45, 35), "BOSS", COLOR_RED)

        # 킥 번호
        if self.is_sudden_death:
            kick_text = "SUDDEN DEATH"
        else:
            kick_text = f"KICK {min(self.current_kick + 1, self.total_kicks)}/{self.total_kicks}"
        font_sm.render_to(screen, (20, 18), kick_text, COLOR_GOLD)

        # 역할 표시
        role_text = "ATK" if self.role == Role.ATTACK else "DEF"
        role_color = COLOR_BLUE if self.role == Role.ATTACK else (100, 200, 100)
        font_sm.render_to(screen, (WIDTH - 60, 18), role_text, role_color)

        # 킥 결과 마커
        self._draw_kick_markers(screen)

    def _draw_kick_markers(self, screen):
        """킥 결과 마커 (O/X)"""
        marker_y = 55
        start_x = WIDTH // 2 - (self.total_kicks * 12) // 2
        font = self._get_font(10)

        # 정규 킥 마커
        for i in range(self.total_kicks):
            mx = start_x + i * 12
            if i < len(self.kick_results):
                attacker, is_goal = self.kick_results[i]
                if attacker == "player":
                    color = COLOR_BLUE if is_goal else (80, 80, 120)
                    symbol = "O" if is_goal else "X"
                else:
                    color = COLOR_RED if is_goal else (120, 80, 80)
                    symbol = "O" if is_goal else "X"
                font.render_to(screen, (mx, marker_y), symbol, color)
            else:
                font.render_to(screen, (mx, marker_y), "-", COLOR_GRAY)

    def _draw_aim_ui(self, screen):
        """공격 모드 UI"""
        # 파워 게이지 (좌측)
        gauge_x = 30
        gauge_y = HEIGHT - 280
        gauge_w = 25
        gauge_h = 200

        # 배경
        pygame.draw.rect(screen, (30, 30, 30), (gauge_x - 2, gauge_y - 2, gauge_w + 4, gauge_h + 4),
                        border_radius=3)
        pygame.draw.rect(screen, (60, 60, 60), (gauge_x, gauge_y, gauge_w, gauge_h), border_radius=2)

        # 파워 바
        fill_h = int((self.power / POWER_MAX) * gauge_h)
        if fill_h > 0:
            # 색상 그라디언트 (녹→황→적)
            ratio = self.power / POWER_MAX
            if ratio < 0.5:
                color = (int(ratio * 2 * 255), 200, 50)
            else:
                color = (255, int((1 - ratio) * 2 * 200), 50)
            pygame.draw.rect(screen, color,
                           (gauge_x, gauge_y + gauge_h - fill_h, gauge_w, fill_h),
                           border_radius=2)

        # 위험 구간 표시 (85% 이상 = 오버슈트 가능)
        danger_y = gauge_y + int((1 - 0.85) * gauge_h)
        pygame.draw.line(screen, COLOR_RED, (gauge_x, danger_y), (gauge_x + gauge_w, danger_y), 2)

        font = self._get_font(11)
        font.render_to(screen, (gauge_x - 2, gauge_y - 18), "POWER", COLOR_WHITE)
        font.render_to(screen, (gauge_x, gauge_y + gauge_h + 5), f"{int(self.power)}%", COLOR_WHITE)

        # 방향 표시 (하단)
        dir_x = WIDTH // 2
        dir_y = HEIGHT - 60
        bar_w = 200

        pygame.draw.line(screen, COLOR_GRAY,
                        (dir_x - bar_w // 2, dir_y), (dir_x + bar_w // 2, dir_y), 3)
        # 현재 방향 마커
        marker_x = dir_x + int(self.angle_offset * bar_w // 2)
        pygame.draw.circle(screen, COLOR_GOLD, (marker_x, dir_y), 8)
        pygame.draw.circle(screen, COLOR_WHITE, (marker_x, dir_y), 8, 2)

        font.render_to(screen, (dir_x - 25, dir_y + 15), "ANGLE", COLOR_WHITE)

        # 커브 게이지 (우측)
        curve_x = WIDTH - 55
        curve_y = HEIGHT - 280
        curve_w = 25
        curve_h = 200

        pygame.draw.rect(screen, (30, 30, 30), (curve_x - 2, curve_y - 2, curve_w + 4, curve_h + 4),
                        border_radius=3)
        pygame.draw.rect(screen, (60, 60, 60), (curve_x, curve_y, curve_w, curve_h), border_radius=2)

        # 커브 바
        curve_fill = int(abs(self.curve_amount) * curve_h)
        if curve_fill > 0:
            curve_color = (100, 180, 255)
            pygame.draw.rect(screen, curve_color,
                           (curve_x, curve_y + curve_h - curve_fill, curve_w, curve_fill),
                           border_radius=2)

        font.render_to(screen, (curve_x - 2, curve_y - 18), "CURVE", COLOR_WHITE)
        font.render_to(screen, (curve_x, curve_y + curve_h + 5),
                      f"{int(abs(self.curve_amount) * 100)}%", COLOR_WHITE)

        # 조작 안내
        if self.state == GameState.AIM:
            guide_font = self._get_font(16)
            # 반투명 배경
            guide_surf = pygame.Surface((300, 30), pygame.SRCALPHA)
            guide_surf.fill((0, 0, 0, 120))
            screen.blit(guide_surf, (WIDTH // 2 - 150, HEIGHT - 35))
            guide_font.render_to(screen, (WIDTH // 2 - 130, HEIGHT - 30),
                               "SPACE: Charge  Arrow: Aim", COLOR_GOLD)

    def _draw_defense_ui(self, screen):
        """수비 모드 UI"""
        # 3지선다 영역 표시
        zone_w = GOAL_WIDTH // 3

        for i in range(3):
            zx = GOAL_X + zone_w * i
            zy = GOAL_BOTTOM_Y

            selected = (i == self.defense_choice)

            # 선택 영역 하이라이트
            sel_surf = pygame.Surface((zone_w, GOAL_HEIGHT), pygame.SRCALPHA)
            if selected:
                sel_surf.fill((50, 150, 255, 80))
                screen.blit(sel_surf, (zx, zy))
                pygame.draw.rect(screen, COLOR_BLUE, (zx, zy, zone_w, GOAL_HEIGHT), 3)
            else:
                sel_surf.fill((255, 255, 255, 20))
                screen.blit(sel_surf, (zx, zy))

        # 방향 레이블
        font = self._get_font(16)
        labels = ["LEFT", "CENTER", "RIGHT"]
        keys = ["<-", "v", "->"]
        for i, (label, key) in enumerate(zip(labels, keys)):
            zx = GOAL_X + zone_w * i + zone_w // 2
            zy = GOAL_BOTTOM_Y + GOAL_HEIGHT + 20
            color = COLOR_BLUE if i == self.defense_choice else COLOR_GRAY
            text_w = len(label) * 8
            font.render_to(screen, (zx - text_w // 2, zy), label, color)
            font.render_to(screen, (zx - 8, zy + 20), key, color)

        # 안내
        guide_font = self._get_font(16)
        if not self.defense_confirmed:
            guide_surf = pygame.Surface((350, 30), pygame.SRCALPHA)
            guide_surf.fill((0, 0, 0, 120))
            screen.blit(guide_surf, (WIDTH // 2 - 175, HEIGHT - 35))
            guide_font.render_to(screen, (WIDTH // 2 - 155, HEIGHT - 30),
                               "Arrow: Select  SPACE: Confirm", COLOR_GOLD)

    def _draw_result_text(self, screen):
        """결과 텍스트 대형 표시"""
        if self.result_timer < 90:
            # 확대 → 축소 애니메이션
            if self.result_timer < 15:
                scale = self.result_timer / 15 * 1.2
            elif self.result_timer < 25:
                scale = 1.2 - (self.result_timer - 15) / 10 * 0.2
            else:
                scale = 1.0

            font_size = int(48 * scale)
            font = self._get_font(max(12, font_size))

            # 반투명 배경
            bg_surf = pygame.Surface((300, 80), pygame.SRCALPHA)
            bg_surf.fill((0, 0, 0, 120))
            screen.blit(bg_surf, (WIDTH // 2 - 150, HEIGHT // 2 - 40))

            text_surf, text_rect = font.render(self.result_text, self.result_color)
            screen.blit(text_surf,
                       (WIDTH // 2 - text_rect.width // 2,
                        HEIGHT // 2 - text_rect.height // 2))

    def _draw_ready(self, screen):
        """준비 텍스트"""
        if self.ready_timer > 0:
            alpha = min(255, int(self.ready_timer / 90 * 255))
            font = self._get_font(36)
            text_surf, text_rect = font.render(self.ready_text, COLOR_GOLD)

            # 반투명 배경
            bg_surf = pygame.Surface((250, 60), pygame.SRCALPHA)
            bg_surf.fill((0, 0, 0, min(150, alpha)))
            screen.blit(bg_surf, (WIDTH // 2 - 125, HEIGHT // 2 - 30))

            text_alpha_surf = pygame.Surface((text_rect.width, text_rect.height), pygame.SRCALPHA)
            font.render_to(text_alpha_surf, (0, 0), self.ready_text, COLOR_GOLD)
            screen.blit(text_alpha_surf,
                       (WIDTH // 2 - text_rect.width // 2,
                        HEIGHT // 2 - text_rect.height // 2))

    def _draw_role_select(self, screen):
        """역할 선택 화면"""
        screen.fill(COLOR_DARK_BG)

        # 타이틀
        font_title = self._get_font(32)
        font_title.render_to(screen, (WIDTH // 2 - 120, 100), "PENALTY KICK", COLOR_GOLD)

        font_sub = self._get_font(18)
        font_sub.render_to(screen, (WIDTH // 2 - 80, 150), "Choose your role", COLOR_WHITE)

        # 공격 카드
        card_w, card_h = 200, 260
        card_gap = 40
        cards_total = card_w * 2 + card_gap
        start_x = (WIDTH - cards_total) // 2

        for i, (label, desc, icon) in enumerate([
            ("ATTACK", "You kick the ball!", "->"),
            ("DEFENSE", "You save the goal!", "<-")
        ]):
            cx = start_x + i * (card_w + card_gap)
            cy = 220

            selected = (i == self.menu_selection)

            # 카드 배경
            if selected:
                # 글로우
                glow_surf = pygame.Surface((card_w + 20, card_h + 20), pygame.SRCALPHA)
                glow_color = COLOR_BLUE if i == 0 else (200, 80, 80)
                pygame.draw.rect(glow_surf, (*glow_color, 60),
                               (0, 0, card_w + 20, card_h + 20), border_radius=15)
                screen.blit(glow_surf, (cx - 10, cy - 10))

            card_color = (40, 50, 70) if selected else (30, 35, 45)
            border_color = COLOR_GOLD if selected else (60, 60, 70)
            pygame.draw.rect(screen, card_color, (cx, cy, card_w, card_h), border_radius=10)
            pygame.draw.rect(screen, border_color, (cx, cy, card_w, card_h), 2, border_radius=10)

            # 아이콘 (축구공 / 글러브)
            icon_cx = cx + card_w // 2
            icon_cy = cy + 70
            if i == 0:
                # 축구공
                pygame.draw.circle(screen, COLOR_WHITE, (icon_cx, icon_cy), 30)
                pygame.draw.circle(screen, (180, 180, 180), (icon_cx, icon_cy), 30, 2)
                for a in range(0, 360, 72):
                    px = icon_cx + int(math.cos(math.radians(a)) * 12)
                    py = icon_cy + int(math.sin(math.radians(a)) * 12)
                    pygame.draw.circle(screen, (50, 50, 50), (px, py), 4)
            else:
                # 글러브
                pygame.draw.circle(screen, (255, 180, 0), (icon_cx - 15, icon_cy), 18)
                pygame.draw.circle(screen, (255, 180, 0), (icon_cx + 15, icon_cy), 18)
                pygame.draw.rect(screen, (255, 200, 50), (icon_cx - 20, icon_cy, 40, 25),
                               border_radius=5)

            # 텍스트
            font_label = self._get_font(22)
            font_desc = self._get_font(13)
            text_color = COLOR_GOLD if selected else COLOR_GRAY
            lbl_surf, lbl_rect = font_label.render(label, text_color)
            screen.blit(lbl_surf, (icon_cx - lbl_rect.width // 2, cy + 130))

            desc_surf, desc_rect = font_desc.render(desc, COLOR_WHITE if selected else COLOR_GRAY)
            screen.blit(desc_surf, (icon_cx - desc_rect.width // 2, cy + 165))

        # 조작 안내
        font_guide = self._get_font(14)
        font_guide.render_to(screen, (WIDTH // 2 - 100, 520),
                           "Arrow: Select  SPACE: Confirm", COLOR_GRAY)
        font_guide.render_to(screen, (WIDTH // 2 - 60, 545),
                           "ESC: Exit", COLOR_GRAY)

    def _draw_game_over(self, screen):
        """게임 오버 화면"""
        screen.fill(COLOR_DARK_BG)

        # 결과
        if self.player_score > self.boss_score:
            title = "YOU WIN!"
            title_color = COLOR_GOLD
        elif self.player_score < self.boss_score:
            title = "YOU LOSE"
            title_color = COLOR_RED
        else:
            title = "DRAW"
            title_color = COLOR_GRAY

        font_title = self._get_font(40)
        t_surf, t_rect = font_title.render(title, title_color)
        screen.blit(t_surf, (WIDTH // 2 - t_rect.width // 2, 120))

        # 스코어
        font_score = self._get_font(60)
        score_text = f"{self.player_score} - {self.boss_score}"
        s_surf, s_rect = font_score.render(score_text, COLOR_WHITE)
        screen.blit(s_surf, (WIDTH // 2 - s_rect.width // 2, 200))

        # 킥 기록
        font_sm = self._get_font(14)
        y_offset = 300
        for i, (attacker, is_goal) in enumerate(self.kick_results):
            kick_num = i + 1
            if i >= self.total_kicks:
                kick_num_text = f"SD {i - self.total_kicks + 1}"
            else:
                kick_num_text = f"#{kick_num}"

            who = "Player" if attacker == "player" else "Boss"
            result = "GOAL" if is_goal else "MISS"
            color = COLOR_BLUE if attacker == "player" else COLOR_RED
            result_color = COLOR_GOLD if is_goal else COLOR_GRAY

            font_sm.render_to(screen, (WIDTH // 2 - 100, y_offset), kick_num_text, COLOR_WHITE)
            font_sm.render_to(screen, (WIDTH // 2 - 50, y_offset), who, color)
            font_sm.render_to(screen, (WIDTH // 2 + 40, y_offset), result, result_color)
            y_offset += 22

        # 안내
        font_guide = self._get_font(16)
        font_guide.render_to(screen, (WIDTH // 2 - 80, HEIGHT - 60),
                           "SPACE: Exit", COLOR_GRAY)

        # 파티클
        self._draw_particles(screen)
