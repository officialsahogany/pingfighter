# -*- coding: utf-8 -*-
"""
로컬 멀티플레이어 모드 - 스매셔 스킬 시스템 완전 구현
싱글플레이어와 동일한 스킬/게이지/콤보 시스템 적용

스킬 목록 (싱글플레이어 기준 완전 동일):
- 쇼트 (Short Shot): 자동 발동, 공 속도 1.3배
- 드라이브 (Drive): 150 게이지, 퍼펙트 타이밍 시 커브
- 파워스매싱 (Power Smashing): 350 게이지, 포물선 궤적
- 클렌즈 (Cleanse): 100 게이지, 상태이상 해제 (멀티에서는 간소화)
"""

import pygame
import random
import math
from typing import Dict, List, Tuple, Optional, Callable, Any

# ============================================================================
# 상수 정의 (싱글플레이어 pingfighter.py 기준 동일)
# ============================================================================

# 게이지 시스템
GAUGE_MAX = 500
GAUGE_HIT_CHARGE = 60  # 스매셔 기본 충전량

# 콤보 보너스 (%)
COMBO_GAUGE_BONUS = {
    2: 30,   # 2콤보: +30%
    3: 50,   # 3콤보: +50%
    4: 70,   # 4콤보: +70%
    5: 85,   # 5콤보: +85%
    6: 100,  # 6콤보+: +100%
}
COMBO_MAX_BONUS = 100

# 쇼트 (Short Shot) - 자동 발동
SHORT_SHOT_SPEED_MULTIPLIER = 1.3
SHORT_SHOT_DURATION = 36  # 프레임

# 드라이브 (Drive) - 150 게이지
DRIVE_GAUGE_COST = 150
DRIVE_CURVE_STRENGTH = 0.4
DRIVE_SPEED_BOOST = 1.2

# 파워스매싱 (Power Smashing) - 350 게이지
POWER_SMASH_GAUGE_COST = 350
POWER_SMASH_SPEED_MULT = 1.5
POWER_SMASH_GRAVITY = 0.035
POWER_SMASH_BOOST_DURATION = 30  # 0.5초 (프레임)

# 클렌즈 (Cleanse) - 100 게이지
CLEANSE_GAUGE_COST = 100
CLEANSE_COOLDOWN = 60
CLEANSE_IMMUNITY_DURATION = 60

# 물리
BALL_BASE_SPEED = 6.0
BALL_MAX_SPEED = 20.0
PADDLE_SPEED = 8
DASH_SPEED_BOOST = 4
DASH_COOLDOWN = 30

# 키 바인딩
class KeyBindings:
    """플레이어별 키 바인딩"""
    def __init__(self, is_p1: bool, is_top: bool):
        if is_p1:
            # P1: 방향키 + Shift
            self.left = pygame.K_LEFT
            self.right = pygame.K_RIGHT
            self.up = pygame.K_UP      # 쇼트/클렌즈
            self.down = pygame.K_DOWN  # 파워스매싱
            self.dash = pygame.K_RSHIFT
            self.skill = pygame.K_RCTRL  # 드라이브 강화
        else:
            # P2: WASD + Space
            self.left = pygame.K_a
            self.right = pygame.K_d
            self.up = pygame.K_w      # 쇼트/클렌즈
            self.down = pygame.K_s    # 파워스매싱
            self.dash = pygame.K_SPACE
            self.skill = pygame.K_LCTRL  # 드라이브 강화


# ============================================================================
# 플레이어 클래스
# ============================================================================

class SmasherPlayer:
    """스매셔 캐릭터 플레이어"""

    def __init__(self, player_num: int, is_top: bool, screen_width: int, screen_height: int):
        self.num = player_num
        self.is_top = is_top
        self.screen_width = screen_width
        self.screen_height = screen_height

        # 위치/크기
        self.width = 100
        self.height = 20
        self.x = screen_width // 2 - self.width // 2
        self.y = 60 if is_top else screen_height - 80
        self.speed = PADDLE_SPEED

        # 키 바인딩
        self.keys = KeyBindings(player_num == 1, is_top)

        # 게이지 시스템
        self.gauge = 0
        self.gauge_max = GAUGE_MAX

        # 콤보 시스템
        self.combo = 0
        self.combo_timer = 0
        self.combo_display_timer = 0

        # 대시 시스템
        self.dash_cooldown = 0
        self.dash_active = False

        # 스킬 상태
        self.short_shot_active = False
        self.short_shot_timer = 0

        self.drive_active = False
        self.drive_direction = 0
        self.drive_text_timer = 0

        self.power_smash_active = False
        self.power_smash_timer = 0
        self.power_smash_ready = False

        self.cleanse_cooldown = 0
        self.cleanse_immunity = 0

        # 애니메이션
        self.walking_timer = 0
        self.hit_pose_timer = 0
        self.facing_left = False
        self.step_phase = 0.0

        # 넉백
        self.knockback_x = 0
        self.knockback_timer = 0

        # 점수
        self.score = 0

    def reset_for_round(self):
        """라운드 시작 시 위치/상태 리셋"""
        self.x = self.screen_width // 2 - self.width // 2
        self.combo = 0
        self.combo_timer = 0
        self.short_shot_active = False
        self.drive_active = False
        self.power_smash_active = False

    def update_keys(self, keys: pygame.key.ScancodeWrapper) -> Tuple[bool, int]:
        """키 입력 처리, 반환: (이동 중 여부, 이동 방향)"""
        moving = False
        move_dir = 0

        # 대시 처리
        move_speed = self.speed
        if self.dash_cooldown <= 0 and keys[self.keys.dash]:
            move_speed += DASH_SPEED_BOOST
            self.dash_cooldown = DASH_COOLDOWN
            self.dash_active = True

        # 이동 처리
        if keys[self.keys.left]:
            self.x -= move_speed
            self.facing_left = True
            moving = True
            move_dir = -1
        if keys[self.keys.right]:
            self.x += move_speed
            self.facing_left = False
            moving = True
            move_dir = 1

        # 경계 제한
        self.x = max(0, min(self.screen_width - self.width, self.x))

        if moving:
            self.walking_timer = 10
            self.step_phase = (self.step_phase + 0.1) % 1.0

        return moving, move_dir

    def update_timers(self):
        """타이머 업데이트"""
        # 콤보 타이머
        if self.combo_timer > 0:
            self.combo_timer -= 1
            if self.combo_timer <= 0:
                self.combo = 0

        if self.combo_display_timer > 0:
            self.combo_display_timer -= 1

        # 애니메이션 타이머
        if self.hit_pose_timer > 0:
            self.hit_pose_timer -= 1
        if self.walking_timer > 0:
            self.walking_timer -= 1

        # 대시 쿨다운
        if self.dash_cooldown > 0:
            self.dash_cooldown -= 1

        # 스킬 타이머
        if self.short_shot_timer > 0:
            self.short_shot_timer -= 1
            if self.short_shot_timer <= 0:
                self.short_shot_active = False

        if self.drive_text_timer > 0:
            self.drive_text_timer -= 1

        if self.power_smash_timer > 0:
            self.power_smash_timer -= 1
            if self.power_smash_timer <= 0:
                self.power_smash_active = False

        # 클렌즈 쿨다운/면역
        if self.cleanse_cooldown > 0:
            self.cleanse_cooldown -= 1
        if self.cleanse_immunity > 0:
            self.cleanse_immunity -= 1

        # 넉백
        if self.knockback_timer > 0:
            self.knockback_timer -= 1
            self.knockback_x *= 0.85
            if self.knockback_timer <= 0:
                self.knockback_x = 0

        # 파워스매싱 준비 상태
        self.power_smash_ready = self.gauge >= POWER_SMASH_GAUGE_COST

    def charge_gauge(self, is_hit: bool = True):
        """게이지 충전 (콤보 보너스 포함)"""
        if not is_hit:
            return

        base_charge = GAUGE_HIT_CHARGE

        # 콤보 보너스 계산
        if self.combo >= 6:
            bonus_pct = COMBO_MAX_BONUS
        else:
            bonus_pct = COMBO_GAUGE_BONUS.get(self.combo, 0)

        total_charge = base_charge + int(base_charge * bonus_pct / 100)
        self.gauge = min(self.gauge + total_charge, self.gauge_max)

    def add_combo(self):
        """콤보 추가"""
        self.combo += 1
        self.combo_timer = 180  # 3초
        self.combo_display_timer = 60

    def apply_knockback(self, direction: int, strength: float = 15):
        """넉백 적용"""
        self.knockback_x = direction * strength
        self.knockback_timer = 10

    def get_rect(self) -> pygame.Rect:
        """충돌 박스 반환"""
        return pygame.Rect(self.x, self.y, self.width, self.height)

    def get_center(self) -> Tuple[float, float]:
        """중심점 반환"""
        return (self.x + self.width / 2, self.y + self.height / 2)


# ============================================================================
# 공 클래스
# ============================================================================

class Ball:
    """게임 공"""

    def __init__(self, screen_width: int, screen_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.radius = 10
        self.reset()

    def reset(self, direction: int = 0):
        """공 리셋"""
        self.x = float(self.screen_width // 2)
        self.y = float(self.screen_height // 2)
        self.speed_x = BALL_BASE_SPEED * (1 if random.random() > 0.5 else -1)
        self.speed_y = BALL_BASE_SPEED * (direction if direction != 0 else (1 if random.random() > 0.5 else -1))
        self.curve_x = 0.0

        # 효과 상태 초기화
        self.short_shot_active = False
        self.power_smash_active = False
        self.power_smash_gravity = 0.0
        self.last_hitter: Optional[SmasherPlayer] = None

    def update(self) -> Optional[str]:
        """공 업데이트, 반환: 득점 방향 ('top', 'bottom', None)"""
        # 이동
        self.x += self.speed_x
        self.y += self.speed_y

        # 커브 적용
        if self.curve_x != 0:
            self.speed_x += self.curve_x * 0.5
            self.curve_x *= 0.98
            if abs(self.curve_x) < 0.01:
                self.curve_x = 0

        # 파워스매싱 중력 적용
        if self.power_smash_active and self.power_smash_gravity > 0:
            self.speed_y += self.power_smash_gravity

        # 좌우 벽 충돌
        if self.x - self.radius <= 0:
            self.x = self.radius
            self.speed_x = abs(self.speed_x)
            return 'wall'
        elif self.x + self.radius >= self.screen_width:
            self.x = self.screen_width - self.radius
            self.speed_x = -abs(self.speed_x)
            return 'wall'

        # 득점 체크
        if self.y - self.radius <= 0:
            return 'top'  # 하단 플레이어 득점
        elif self.y + self.radius >= self.screen_height:
            return 'bottom'  # 상단 플레이어 득점

        return None

    def apply_paddle_bounce(self, player: SmasherPlayer, hit_pos: float):
        """패들 반사 물리 적용"""
        # 기본 반사
        if player.is_top:
            self.speed_y = abs(self.speed_y)
        else:
            self.speed_y = -abs(self.speed_y)

        # 패들 위치에 따른 각도
        self.speed_x = (hit_pos - 0.5) * 12

    def apply_speed_limit(self):
        """속도 제한 적용"""
        speed = math.sqrt(self.speed_x**2 + self.speed_y**2)
        if speed > BALL_MAX_SPEED:
            factor = BALL_MAX_SPEED / speed
            self.speed_x *= factor
            self.speed_y *= factor

    def get_rect(self) -> pygame.Rect:
        """충돌 박스 반환"""
        return pygame.Rect(
            self.x - self.radius,
            self.y - self.radius,
            self.radius * 2,
            self.radius * 2
        )


# ============================================================================
# 이펙트 시스템
# ============================================================================

class EffectManager:
    """시각 효과 관리"""

    def __init__(self):
        self.text_effects: List[Dict] = []  # 텍스트 이펙트
        self.screen_shake = 0
        self.shake_x = 0
        self.shake_y = 0

    def add_text_effect(self, x: float, y: float, text: str, color: Tuple[int, int, int], duration: int = 30):
        """텍스트 이펙트 추가"""
        self.text_effects.append({
            'x': x, 'y': y, 'text': text, 'color': color,
            'timer': duration, 'max_timer': duration
        })

    def add_screen_shake(self, intensity: int):
        """화면 흔들림 추가"""
        self.screen_shake = max(self.screen_shake, intensity)

    def update(self):
        """이펙트 업데이트"""
        # 텍스트 이펙트
        new_effects = []
        for eff in self.text_effects:
            eff['timer'] -= 1
            eff['y'] -= 1  # 위로 떠오름
            if eff['timer'] > 0:
                new_effects.append(eff)
        self.text_effects = new_effects

        # 화면 흔들림
        if self.screen_shake > 0:
            self.screen_shake -= 1
            self.shake_x = random.randint(-3, 3)
            self.shake_y = random.randint(-3, 3)
        else:
            self.shake_x = 0
            self.shake_y = 0


# ============================================================================
# 스킬 처리 시스템
# ============================================================================

class SkillSystem:
    """스킬 발동 및 처리"""

    @staticmethod
    def check_and_apply_skills(player: SmasherPlayer, ball: Ball, keys: pygame.key.ScancodeWrapper,
                               effects: EffectManager, play_sounds: Dict[str, Callable]) -> bool:
        """
        히트 시 스킬 체크 및 적용
        반환: 스킬 발동 여부
        """
        skill_used = False
        center_x, center_y = player.get_center()

        # 1. 파워스매싱 체크 (↓/S + 히트, 350 게이지)
        if keys[player.keys.down] and player.gauge >= POWER_SMASH_GAUGE_COST:
            player.gauge -= POWER_SMASH_GAUGE_COST
            player.power_smash_active = True
            player.power_smash_timer = POWER_SMASH_BOOST_DURATION

            # 공에 파워스매싱 효과 적용
            ball.speed_x *= POWER_SMASH_SPEED_MULT
            ball.speed_y *= POWER_SMASH_SPEED_MULT
            ball.power_smash_active = True
            ball.power_smash_gravity = POWER_SMASH_GRAVITY

            effects.add_text_effect(center_x, center_y - 30, "POWER SMASH!", (255, 100, 50), 45)
            effects.add_screen_shake(15)

            try:
                play_sounds.get('power_smash', lambda: None)()
            except:
                pass

            skill_used = True

        # 2. 드라이브 체크 (←→/AD + 히트, 150 게이지)
        elif (keys[player.keys.left] or keys[player.keys.right]) and player.gauge >= DRIVE_GAUGE_COST:
            player.gauge -= DRIVE_GAUGE_COST
            player.drive_active = True
            player.drive_text_timer = 30

            # 커브 방향 결정
            if keys[player.keys.left]:
                ball.curve_x = -DRIVE_CURVE_STRENGTH
                player.drive_direction = -1
            else:
                ball.curve_x = DRIVE_CURVE_STRENGTH
                player.drive_direction = 1

            ball.speed_x *= DRIVE_SPEED_BOOST
            ball.speed_y *= DRIVE_SPEED_BOOST

            effects.add_text_effect(center_x, center_y - 30, "DRIVE!", (255, 255, 100), 30)

            try:
                play_sounds.get('drive', lambda: None)()
            except:
                pass

            skill_used = True

        # 3. 쇼트 체크 (↑/W + 히트, 게이지 무료)
        elif keys[player.keys.up]:
            player.short_shot_active = True
            player.short_shot_timer = SHORT_SHOT_DURATION

            ball.speed_x *= SHORT_SHOT_SPEED_MULTIPLIER
            ball.speed_y *= SHORT_SHOT_SPEED_MULTIPLIER
            ball.short_shot_active = True

            effects.add_text_effect(center_x, center_y - 30, "SHORT!", (100, 200, 255), 25)

            try:
                play_sounds.get('short_shot', lambda: None)()
            except:
                pass

            skill_used = True

        return skill_used

    @staticmethod
    def check_cleanse(player: SmasherPlayer, keys: pygame.key.ScancodeWrapper,
                      effects: EffectManager, play_sounds: Dict[str, Callable]) -> bool:
        """클렌즈 체크 (별도 키로 발동)"""
        # 멀티플레이어에서는 상태이상이 없으므로 간소화
        # 추후 상태이상 시스템 추가 시 확장
        return False


# ============================================================================
# 렌더러
# ============================================================================

class MultiplayerRenderer:
    """멀티플레이어 렌더링"""

    def __init__(self, screen: pygame.Surface, width: int, height: int,
                 get_font: Callable, create_smasher_sprite: Callable):
        self.screen = screen
        self.width = width
        self.height = height
        self.get_font = get_font
        self.create_smasher_sprite = create_smasher_sprite

    def draw_background(self, shake_x: int = 0, shake_y: int = 0):
        """배경 그리기"""
        self.screen.fill((20, 25, 35))

        # 중앙선
        pygame.draw.line(self.screen, (60, 70, 90),
                        (shake_x, self.height // 2 + shake_y),
                        (self.width + shake_x, self.height // 2 + shake_y), 2)
        for i in range(0, self.width, 30):
            pygame.draw.circle(self.screen, (80, 90, 110),
                             (i + shake_x, self.height // 2 + shake_y), 3)

    def draw_player(self, player: SmasherPlayer, shake_x: int = 0, shake_y: int = 0):
        """플레이어 스프라이트 그리기"""
        try:
            sprite = self.create_smasher_sprite(player.step_phase)

            # 상단 플레이어는 180도 회전
            if player.is_top:
                sprite = pygame.transform.rotate(sprite, 180)

            # 위치 계산 (넉백 포함)
            draw_x = player.x + player.knockback_x + shake_x
            draw_y = player.y + shake_y

            # 스프라이트 중앙 정렬
            rect = sprite.get_rect()
            rect.centerx = draw_x + player.width // 2
            rect.centery = draw_y + player.height // 2

            self.screen.blit(sprite, rect)

        except Exception:
            # 폴백: 단순 사각형
            color = (0, 150, 255) if player.num == 1 else (255, 100, 100)
            pygame.draw.rect(self.screen, color,
                           (player.x + shake_x, player.y + shake_y,
                            player.width, player.height),
                           border_radius=5)

    def draw_ball(self, ball: Ball, shake_x: int = 0, shake_y: int = 0):
        """공 그리기"""
        x = int(ball.x) + shake_x
        y = int(ball.y) + shake_y

        # 스킬 효과 표시
        if ball.short_shot_active:
            pygame.draw.circle(self.screen, (100, 200, 255), (x, y), ball.radius + 4, 2)
        if ball.power_smash_active:
            pygame.draw.circle(self.screen, (255, 100, 50), (x, y), ball.radius + 6, 3)

        # 공 본체
        pygame.draw.circle(self.screen, (255, 255, 255), (x, y), ball.radius)
        pygame.draw.circle(self.screen, (200, 200, 200), (x, y), ball.radius, 2)

    def draw_gauge(self, player: SmasherPlayer):
        """게이지 바 그리기"""
        gauge_width = 160
        gauge_height = 14
        border = 2

        # 위치
        if player.is_top:
            gauge_x = self.width - gauge_width - 20
            gauge_y = 45
        else:
            gauge_x = self.width - gauge_width - 20
            gauge_y = self.height - gauge_height - 45

        # 배경
        pygame.draw.rect(self.screen, (30, 30, 40),
                        (gauge_x - border, gauge_y - border,
                         gauge_width + border * 2, gauge_height + border * 2),
                        border_radius=4)

        # 게이지 채움
        fill_ratio = player.gauge / player.gauge_max
        fill_width = int(gauge_width * fill_ratio)

        # 색상 (충전량에 따라)
        if player.power_smash_ready:
            gauge_color = (255, 200, 50)  # 파워스매싱 준비
        elif fill_ratio >= 0.7:
            gauge_color = (100, 255, 100)
        elif fill_ratio >= 0.3:
            gauge_color = (200, 200, 100)
        else:
            gauge_color = (200, 100, 100)

        if fill_width > 0:
            pygame.draw.rect(self.screen, gauge_color,
                           (gauge_x, gauge_y, fill_width, gauge_height),
                           border_radius=3)

        # 스킬 코스트 마커
        markers = [
            (DRIVE_GAUGE_COST, (150, 150, 150)),      # 드라이브: 150
            (POWER_SMASH_GAUGE_COST, (255, 100, 100)) # 파워스매싱: 350
        ]
        for cost, color in markers:
            pos = int(gauge_width * (cost / GAUGE_MAX))
            pygame.draw.line(self.screen, color,
                           (gauge_x + pos, gauge_y - 2),
                           (gauge_x + pos, gauge_y + gauge_height + 2), 2)

        # 플레이어 라벨
        try:
            font = self.get_font(16)
        except:
            font = pygame.font.Font(None, 16)

        p_color = (0, 150, 255) if player.num == 1 else (255, 100, 100)
        label = font.render(f"P{player.num}", True, p_color)
        self.screen.blit(label, (gauge_x - label.get_width() - 8,
                                gauge_y + (gauge_height - label.get_height()) // 2))

        # 게이지 수치
        gauge_text = font.render(f"{player.gauge}/{player.gauge_max}", True, (180, 180, 180))
        self.screen.blit(gauge_text, (gauge_x + gauge_width + 8,
                                     gauge_y + (gauge_height - gauge_text.get_height()) // 2))

    def draw_combo(self, player: SmasherPlayer):
        """콤보 표시"""
        if player.combo_display_timer <= 0 or player.combo < 2:
            return

        # 위치
        if player.is_top:
            x, y = self.width - 100, 80
        else:
            x, y = self.width - 100, self.height - 90

        # 색상 (콤보에 따라)
        if player.combo >= 6:
            color = (255, 50, 50)
        elif player.combo >= 4:
            color = (255, 150, 50)
        else:
            color = (255, 255, 100)

        # 크기 애니메이션
        scale = 1.0 + (player.combo_display_timer / 60) * 0.3

        try:
            font = self.get_font(int(28 * scale))
        except:
            font = pygame.font.Font(None, int(28 * scale))

        text = font.render(f"{player.combo} COMBO!", True, color)
        rect = text.get_rect(center=(x, y))
        self.screen.blit(text, rect)

        # 보너스 표시
        if player.combo >= 2:
            bonus = COMBO_GAUGE_BONUS.get(player.combo, COMBO_MAX_BONUS)
            try:
                bonus_font = self.get_font(14)
            except:
                bonus_font = pygame.font.Font(None, 14)
            bonus_text = bonus_font.render(f"+{bonus}% 게이지", True, (150, 255, 150))
            bonus_rect = bonus_text.get_rect(center=(x, y + 20))
            self.screen.blit(bonus_text, bonus_rect)

    def draw_score(self, p1: SmasherPlayer, p2: SmasherPlayer):
        """점수 표시"""
        try:
            font = self.get_font(40)
        except:
            font = pygame.font.Font(None, 40)

        p1_color = (0, 150, 255)
        p2_color = (255, 100, 100)

        # 상단 점수
        top_player = p1 if p1.is_top else p2
        top_color = p1_color if top_player.num == 1 else p2_color
        top_text = font.render(f"P{top_player.num}: {top_player.score}", True, top_color)
        self.screen.blit(top_text, (20, 10))

        # 하단 점수
        bottom_player = p2 if p1.is_top else p1
        bottom_color = p1_color if bottom_player.num == 1 else p2_color
        bottom_text = font.render(f"P{bottom_player.num}: {bottom_player.score}", True, bottom_color)
        self.screen.blit(bottom_text, (20, self.height - 45))

    def draw_effects(self, effects: EffectManager):
        """이펙트 그리기"""
        try:
            font = self.get_font(22)
        except:
            font = pygame.font.Font(None, 22)

        for eff in effects.text_effects:
            alpha = int(255 * (eff['timer'] / eff['max_timer']))
            text = font.render(eff['text'], True, eff['color'])
            self.screen.blit(text, (eff['x'] - text.get_width() // 2, eff['y']))

    def draw_countdown(self, count: int):
        """카운트다운 표시"""
        try:
            font = self.get_font(80)
        except:
            font = pygame.font.Font(None, 80)

        text = font.render(str(count), True, (255, 255, 0))
        rect = text.get_rect(center=(self.width // 2, self.height // 2))
        self.screen.blit(text, rect)

    def draw_help(self, p1: SmasherPlayer, p2: SmasherPlayer):
        """조작법 안내"""
        try:
            font = self.get_font(12)
        except:
            font = pygame.font.Font(None, 12)

        # 상단 플레이어 도움말
        top = p1 if p1.is_top else p2
        if top.num == 1:
            help_text = "P1: ←→ 이동 | ↑+히트:쇼트 | ←→+히트:드라이브(150) | ↓+히트:파워스매싱(350)"
        else:
            help_text = "P2: A/D 이동 | W+히트:쇼트 | A/D+히트:드라이브(150) | S+히트:파워스매싱(350)"
        text = font.render(help_text, True, (100, 100, 100))
        self.screen.blit(text, (self.width // 2 - text.get_width() // 2, 3))

        # 하단 플레이어 도움말
        bottom = p2 if p1.is_top else p1
        if bottom.num == 1:
            help_text = "P1: ←→ 이동 | ↑+히트:쇼트 | ←→+히트:드라이브(150) | ↓+히트:파워스매싱(350)"
        else:
            help_text = "P2: A/D 이동 | W+히트:쇼트 | A/D+히트:드라이브(150) | S+히트:파워스매싱(350)"
        text = font.render(help_text, True, (100, 100, 100))
        self.screen.blit(text, (self.width // 2 - text.get_width() // 2, self.height - 15))

        # ESC 안내
        esc_text = font.render("ESC: 메뉴", True, (80, 80, 80))
        self.screen.blit(esc_text, (self.width - esc_text.get_width() - 10, self.height // 2 - 6))


# ============================================================================
# 캐릭터 선택 화면
# ============================================================================

def show_character_select(screen: pygame.Surface, width: int, height: int,
                          get_font: Callable, play_click: Callable,
                          create_smasher: Callable) -> Optional[Tuple[Tuple[str, bool], Tuple[str, bool]]]:
    """
    캐릭터 선택 화면
    반환: ((p1_char, p1_is_top), (p2_char, p2_is_top)) 또는 None (취소)
    """
    clock = pygame.time.Clock()

    characters = [
        {"id": "smasher", "name": "스매셔", "available": True, "color": (0, 150, 255),
         "desc": "균형잡힌 올라운더\n쇼트/드라이브/파워스매싱"},
        {"id": "commando", "name": "코만도", "available": False, "color": (100, 100, 100),
         "desc": "Coming Soon"},
        {"id": "baltor", "name": "발토르", "available": False, "color": (100, 100, 100),
         "desc": "Coming Soon"},
        {"id": "optimus", "name": "옵티머스", "available": False, "color": (100, 100, 100),
         "desc": "Coming Soon"},
    ]

    current_player = 1
    p1_selection = None
    p2_selection = None
    hover_index = 0

    # 위치 완전 랜덤
    p1_is_top = random.choice([True, False])

    while True:
        clock.tick(60)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return None
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return None
                elif event.key == pygame.K_LEFT:
                    hover_index = (hover_index - 1) % len(characters)
                    try:
                        play_click()
                    except:
                        pass
                elif event.key == pygame.K_RIGHT:
                    hover_index = (hover_index + 1) % len(characters)
                    try:
                        play_click()
                    except:
                        pass
                elif event.key in (pygame.K_RETURN, pygame.K_SPACE):
                    if characters[hover_index]["available"]:
                        if current_player == 1:
                            p1_selection = characters[hover_index]["id"]
                            current_player = 2
                        else:
                            p2_selection = characters[hover_index]["id"]
                            return ((p1_selection, p1_is_top), (p2_selection, not p1_is_top))
                        try:
                            play_click()
                        except:
                            pass

            if event.type == pygame.MOUSEBUTTONDOWN:
                mx, my = pygame.mouse.get_pos()
                card_w, card_h = 150, 200
                start_x = (width - len(characters) * (card_w + 15) + 15) // 2
                card_y = height // 2 - card_h // 2

                for i, char in enumerate(characters):
                    card_x = start_x + i * (card_w + 15)
                    if pygame.Rect(card_x, card_y, card_w, card_h).collidepoint(mx, my):
                        if char["available"]:
                            if current_player == 1:
                                p1_selection = char["id"]
                                current_player = 2
                            else:
                                p2_selection = char["id"]
                                return ((p1_selection, p1_is_top), (p2_selection, not p1_is_top))
                            try:
                                play_click()
                            except:
                                pass

        # 마우스 호버
        mx, my = pygame.mouse.get_pos()
        card_w, card_h = 150, 200
        start_x = (width - len(characters) * (card_w + 15) + 15) // 2
        card_y = height // 2 - card_h // 2

        for i, char in enumerate(characters):
            card_x = start_x + i * (card_w + 15)
            if pygame.Rect(card_x, card_y, card_w, card_h).collidepoint(mx, my):
                hover_index = i

        # 렌더링
        screen.fill((15, 20, 35))

        try:
            title_font = get_font(52)
            sub_font = get_font(24)
            card_font = get_font(22)
            desc_font = get_font(14)
            hint_font = get_font(16)
        except:
            title_font = pygame.font.Font(None, 52)
            sub_font = pygame.font.Font(None, 24)
            card_font = pygame.font.Font(None, 22)
            desc_font = pygame.font.Font(None, 14)
            hint_font = pygame.font.Font(None, 16)

        # 제목
        title_color = (0, 150, 255) if current_player == 1 else (255, 100, 100)
        title = title_font.render(f"P{current_player} 캐릭터 선택", True, title_color)
        screen.blit(title, (width // 2 - title.get_width() // 2, 50))

        # 위치 정보
        pos_text = "상단" if (current_player == 1 and p1_is_top) or (current_player == 2 and not p1_is_top) else "하단"
        pos_surf = sub_font.render(f"배정 위치: {pos_text}", True, (180, 180, 180))
        screen.blit(pos_surf, (width // 2 - pos_surf.get_width() // 2, 110))

        # 캐릭터 카드
        for i, char in enumerate(characters):
            card_x = start_x + i * (card_w + 15)
            is_hover = i == hover_index
            is_available = char["available"]

            # 카드 배경
            if is_hover and is_available:
                bg = (50, 60, 80)
                border = title_color
                bw = 3
            elif is_available:
                bg = (35, 40, 55)
                border = (70, 80, 100)
                bw = 2
            else:
                bg = (25, 28, 38)
                border = (45, 50, 60)
                bw = 1

            pygame.draw.rect(screen, bg, (card_x, card_y, card_w, card_h), border_radius=12)
            pygame.draw.rect(screen, border, (card_x, card_y, card_w, card_h), bw, border_radius=12)

            # 스프라이트 미리보기
            if char["id"] == "smasher" and is_available:
                try:
                    preview = create_smasher(0.0)
                    preview = pygame.transform.scale(preview, (80, 40))
                    screen.blit(preview, (card_x + (card_w - 80) // 2, card_y + 40))
                except:
                    pygame.draw.rect(screen, char["color"],
                                   (card_x + 35, card_y + 50, 80, 20), border_radius=5)
            else:
                pygame.draw.rect(screen, (60, 60, 70),
                               (card_x + 35, card_y + 50, 80, 40), border_radius=5)

            # 캐릭터 이름
            name_color = char["color"] if is_available else (70, 70, 70)
            name = card_font.render(char["name"], True, name_color)
            screen.blit(name, (card_x + (card_w - name.get_width()) // 2, card_y + card_h - 60))

            # 설명
            desc_lines = char["desc"].split('\n')
            for j, line in enumerate(desc_lines):
                desc_color = (140, 140, 140) if is_available else (60, 60, 60)
                desc = desc_font.render(line, True, desc_color)
                screen.blit(desc, (card_x + (card_w - desc.get_width()) // 2, card_y + card_h - 35 + j * 16))

        # P1 선택 완료 표시
        if p1_selection:
            info = f"P1: {p1_selection} ({'상단' if p1_is_top else '하단'})"
            info_surf = sub_font.render(info, True, (0, 150, 255))
            screen.blit(info_surf, (20, height - 70))

        # 조작 안내
        hint = hint_font.render("← → 선택 | Enter 확정 | ESC 취소", True, (100, 100, 100))
        screen.blit(hint, (width // 2 - hint.get_width() // 2, height - 35))

        pygame.display.flip()

    return None


# ============================================================================
# 결과 화면
# ============================================================================

def show_result(screen: pygame.Surface, width: int, height: int,
                winner: SmasherPlayer, p1: SmasherPlayer, p2: SmasherPlayer,
                get_font: Callable):
    """결과 화면 표시"""
    clock = pygame.time.Clock()
    timer = 0

    while True:
        dt = clock.tick(60) / 1000.0
        timer += dt

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return
            if event.type == pygame.KEYDOWN:
                if event.key in (pygame.K_RETURN, pygame.K_SPACE, pygame.K_ESCAPE):
                    return
            if event.type == pygame.MOUSEBUTTONDOWN:
                return

        screen.fill((15, 20, 35))

        try:
            title_font = get_font(72)
            score_font = get_font(40)
            hint_font = get_font(24)
        except:
            title_font = pygame.font.Font(None, 72)
            score_font = pygame.font.Font(None, 40)
            hint_font = pygame.font.Font(None, 24)

        # 승자 표시
        win_color = (0, 150, 255) if winner.num == 1 else (255, 100, 100)

        # 펄스 효과
        pulse = 1.0 + math.sin(timer * 4) * 0.1

        title = title_font.render(f"P{winner.num} 승리!", True, win_color)
        title = pygame.transform.scale(title,
                                       (int(title.get_width() * pulse),
                                        int(title.get_height() * pulse)))
        rect = title.get_rect(center=(width // 2, height // 2 - 80))
        screen.blit(title, rect)

        # 점수
        score_text = score_font.render(f"P1: {p1.score}  -  P2: {p2.score}", True, (200, 200, 200))
        score_rect = score_text.get_rect(center=(width // 2, height // 2 + 10))
        screen.blit(score_text, score_rect)

        # 안내
        hint = hint_font.render("아무 키나 눌러 메뉴로", True, (120, 120, 120))
        hint_rect = hint.get_rect(center=(width // 2, height // 2 + 80))
        screen.blit(hint, hint_rect)

        pygame.display.flip()


# ============================================================================
# 메인 게임 루프
# ============================================================================

def run_multiplayer_game(screen: pygame.Surface, width: int, height: int,
                         get_font_func: Callable, play_sound_funcs: Dict[str, Callable],
                         create_smasher_func: Callable, bgm_manager: Any) -> bool:
    """
    멀티플레이어 게임 실행

    Args:
        screen: pygame 화면
        width, height: 화면 크기
        get_font_func: 폰트 가져오기 함수
        play_sound_funcs: 사운드 함수 딕셔너리
        create_smasher_func: 스매셔 스프라이트 생성 함수
        bgm_manager: BGM 관리자

    Returns:
        True: 정상 종료, False: 강제 종료
    """
    # 캐릭터 선택
    selection = show_character_select(
        screen, width, height, get_font_func,
        play_sound_funcs.get('click', lambda: None),
        create_smasher_func
    )

    if selection is None:
        return True  # 취소

    (p1_char, p1_is_top), (p2_char, p2_is_top) = selection

    # 게임 객체 생성
    clock = pygame.time.Clock()

    p1 = SmasherPlayer(1, p1_is_top, width, height)
    p2 = SmasherPlayer(2, p2_is_top, width, height)
    ball = Ball(width, height)
    effects = EffectManager()
    renderer = MultiplayerRenderer(screen, width, height, get_font_func, create_smasher_func)

    # 게임 상태
    win_score = 5
    round_delay = 60
    round_timer = round_delay
    game_paused = True

    # BGM
    try:
        bgm_manager.play_stage_bgm(1)
    except:
        pass

    # 메인 루프
    running = True
    while running:
        dt = clock.tick(60)

        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return False
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    try:
                        bgm_manager.play_menu_bgm()
                    except:
                        pass
                    return True

        # 라운드 대기
        if game_paused:
            round_timer -= 1
            if round_timer <= 0:
                game_paused = False

        keys = pygame.key.get_pressed()

        if not game_paused:
            # 플레이어 입력 처리
            p1.update_keys(keys)
            p2.update_keys(keys)

            # 타이머 업데이트
            p1.update_timers()
            p2.update_timers()

            # 공 업데이트
            ball_result = ball.update()

            if ball_result == 'wall':
                try:
                    play_sound_funcs.get('wall', lambda: None)()
                except:
                    pass

            # 플레이어 충돌 체크
            for player in [p1, p2]:
                opponent = p2 if player == p1 else p1

                # 충돌 조건
                ball_going_toward = (player.is_top and ball.speed_y < 0) or \
                                   (not player.is_top and ball.speed_y > 0)

                if not ball_going_toward:
                    continue

                p_rect = player.get_rect()
                b_rect = ball.get_rect()

                # 충돌 판정
                if p_rect.colliderect(b_rect):
                    # 히트 위치 계산
                    hit_pos = (ball.x - player.x) / player.width
                    hit_pos = max(0, min(1, hit_pos))

                    # 이전 효과 초기화
                    ball.short_shot_active = False
                    ball.power_smash_active = False
                    ball.power_smash_gravity = 0
                    ball.curve_x = 0

                    # 기본 반사
                    ball.apply_paddle_bounce(player, hit_pos)

                    # 스킬 체크 및 적용
                    SkillSystem.check_and_apply_skills(
                        player, ball, keys, effects, play_sound_funcs
                    )

                    # 속도 제한
                    ball.apply_speed_limit()

                    # 콤보 및 게이지
                    player.add_combo()
                    player.charge_gauge(True)
                    player.hit_pose_timer = 15
                    ball.last_hitter = player

                    # 상대방 콤보 리셋
                    opponent.combo = 0

                    # 파워스매싱 넉백
                    if ball.power_smash_active:
                        direction = 1 if ball.x > opponent.x + opponent.width / 2 else -1
                        opponent.apply_knockback(direction, 20)

                    try:
                        play_sound_funcs.get('hit', lambda: None)()
                    except:
                        pass

            # 득점 체크
            if ball_result in ('top', 'bottom'):
                # 득점자 결정
                if ball_result == 'top':
                    # 하단 플레이어 득점
                    scorer = p1 if not p1.is_top else p2
                else:
                    # 상단 플레이어 득점
                    scorer = p1 if p1.is_top else p2

                scorer.score += 1

                try:
                    play_sound_funcs.get('score', lambda: None)()
                except:
                    pass

                # 승리 체크
                if scorer.score >= win_score:
                    show_result(screen, width, height, scorer, p1, p2, get_font_func)
                    try:
                        bgm_manager.play_menu_bgm()
                    except:
                        pass
                    return True

                # 라운드 리셋
                ball.reset(1 if ball_result == 'top' else -1)
                p1.reset_for_round()
                p2.reset_for_round()
                game_paused = True
                round_timer = round_delay

        # 이펙트 업데이트
        effects.update()

        # 렌더링
        renderer.draw_background(effects.shake_x, effects.shake_y)
        renderer.draw_player(p1, effects.shake_x, effects.shake_y)
        renderer.draw_player(p2, effects.shake_x, effects.shake_y)
        renderer.draw_ball(ball, effects.shake_x, effects.shake_y)
        renderer.draw_gauge(p1)
        renderer.draw_gauge(p2)
        renderer.draw_combo(p1)
        renderer.draw_combo(p2)
        renderer.draw_score(p1, p2)
        renderer.draw_effects(effects)
        renderer.draw_help(p1, p2)

        if game_paused and round_timer > 0:
            renderer.draw_countdown((round_timer // 20) + 1)

        pygame.display.flip()

    return True
