#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
빠칭코(슬롯머신) 게임 모듈
- 미니창 형태로 표시
- 3개의 세로 회전 슬롯
- 마우스 클릭으로 슬롯 정지
- 마우스 휠로 배팅 금액 조절
"""

import pygame
import pygame.freetype
import math
import random
import os
import sys

# 리소스 경로 함수
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)


# ============================================
# 슬롯 심볼 정의
# ============================================
class SlotSymbol:
    """슬롯 심볼 정의"""
    # 심볼 타입과 배당률
    SYMBOLS = {
        "pingpong": {"name": "탁구공", "multiplier": 2, "color": (255, 255, 255)},
        "banana": {"name": "바나나", "multiplier": 3, "color": (255, 230, 50)},
        "apple": {"name": "사과", "multiplier": 4, "color": (220, 50, 50)},
        "key": {"name": "열쇠", "multiplier": 5, "color": (255, 200, 100)},
        "diamond": {"name": "다이아몬드", "multiplier": 7, "color": (100, 200, 255)},
        "pandora": {"name": "판도라 상자", "multiplier": 10, "color": (180, 100, 255)},
        "seven": {"name": "럭키 7", "multiplier": 0, "color": (255, 215, 0), "bonus": True},  # 보너스 라운드
    }

    # 심볼 등장 확률 (가중치)
    WEIGHTS = {
        "pingpong": 30,  # 가장 흔함
        "banana": 25,
        "apple": 20,
        "key": 12,
        "diamond": 8,
        "pandora": 4,
        "seven": 1,  # 가장 희귀
    }

    @classmethod
    def get_random_symbol(cls):
        """가중치 기반 랜덤 심볼 선택"""
        symbols = list(cls.WEIGHTS.keys())
        weights = list(cls.WEIGHTS.values())
        return random.choices(symbols, weights=weights, k=1)[0]

    @classmethod
    def get_symbol_list(cls):
        """전체 심볼 리스트 (회전용)"""
        return list(cls.SYMBOLS.keys())


# ============================================
# 슬롯 릴 클래스
# ============================================
class SlotReel:
    """개별 슬롯 릴"""

    def __init__(self, reel_index):
        self.reel_index = reel_index
        self.symbols = SlotSymbol.get_symbol_list()
        self.current_offset = random.uniform(0, len(self.symbols))
        self.target_symbol = None
        self.is_spinning = False
        self.is_stopped = False
        self.spin_speed = 0
        self.max_spin_speed = 25 + reel_index * 3  # 릴마다 약간 다른 속도
        self.deceleration = 0
        self.final_symbol = None

    def start_spin(self):
        """릴 회전 시작"""
        self.is_spinning = True
        self.is_stopped = False
        self.spin_speed = self.max_spin_speed
        self.deceleration = 0
        self.final_symbol = None

    def stop_spin(self, forced_symbol=None):
        """릴 정지 시작 (감속)"""
        if not self.is_spinning or self.is_stopped:
            return

        self.is_stopped = True
        self.deceleration = 0.5 + self.reel_index * 0.1

        # 강제 심볼 (보너스 라운드용)
        if forced_symbol:
            self.final_symbol = forced_symbol
        else:
            self.final_symbol = SlotSymbol.get_random_symbol()

    def update(self, dt):
        """릴 업데이트"""
        if not self.is_spinning:
            return

        # 회전 중
        self.current_offset += self.spin_speed * dt

        # 감속 중
        if self.is_stopped:
            self.spin_speed -= self.deceleration

            # 정지 완료
            if self.spin_speed <= 0:
                self.spin_speed = 0
                self.is_spinning = False
                # 최종 심볼 위치로 스냅
                if self.final_symbol:
                    target_idx = self.symbols.index(self.final_symbol)
                    self.current_offset = target_idx

    def get_visible_symbols(self, count=3):
        """화면에 보이는 심볼들 (위, 중앙, 아래)"""
        symbols = []
        base_idx = int(self.current_offset) % len(self.symbols)

        for i in range(-1, count - 1):
            idx = (base_idx + i) % len(self.symbols)
            symbols.append(self.symbols[idx])

        return symbols

    def get_center_symbol(self):
        """중앙 심볼 (당첨 라인)"""
        if not self.is_spinning and self.final_symbol:
            return self.final_symbol
        idx = int(self.current_offset + 0.5) % len(self.symbols)
        return self.symbols[idx]


# ============================================
# 빠칭코 게임 클래스
# ============================================
class PachinkoGame:
    """빠칭코(슬롯머신) 게임 로직"""

    STATE_BETTING = "betting"
    STATE_SPINNING = "spinning"
    STATE_STOPPING = "stopping"
    STATE_RESULT = "result"
    STATE_BONUS_BETTING = "bonus_betting"
    STATE_BONUS_SPINNING = "bonus_spinning"
    STATE_BONUS_RESULT = "bonus_result"

    def __init__(self):
        self.reels = [SlotReel(i) for i in range(3)]
        self.state = self.STATE_BETTING

        # 배팅 관련
        self.bet_amount = 10
        self.min_bet = 1
        self.max_bet = 100
        self.player_gold = 0

        # 결과 관련
        self.result_symbols = [None, None, None]
        self.win_amount = 0
        self.win_multiplier = 0
        self.is_jackpot = False
        self.is_bonus = False

        # 보너스 라운드
        self.bonus_round = False
        self.bonus_bet = 0
        self.bonus_symbol = None

        # 애니메이션
        self.animation_timer = 0
        self.result_display_timer = 0
        self.stopped_reels = 0

        # 사운드 플래그
        self.play_spin_sound = False
        self.play_stop_sound = False
        self.play_win_sound = False
        self.play_lose_sound = False
        self.play_jackpot_sound = False

    def set_player_gold(self, gold):
        """플레이어 골드 설정"""
        self.player_gold = gold
        self.bet_amount = min(self.bet_amount, gold, self.max_bet)

    def adjust_bet(self, delta):
        """배팅 금액 조절"""
        if self.state not in [self.STATE_BETTING, self.STATE_BONUS_BETTING]:
            return

        self.bet_amount += delta
        self.bet_amount = max(self.min_bet, min(self.bet_amount, self.max_bet, self.player_gold))

    def start_spin(self):
        """슬롯 회전 시작"""
        if self.state == self.STATE_BETTING:
            if self.bet_amount > self.player_gold:
                return False

            self.player_gold -= self.bet_amount
            self.state = self.STATE_SPINNING
            self.stopped_reels = 0
            self.result_symbols = [None, None, None]
            self.win_amount = 0
            self.is_jackpot = False
            self.is_bonus = False

            for reel in self.reels:
                reel.start_spin()

            self.play_spin_sound = True
            return True

        elif self.state == self.STATE_BONUS_BETTING:
            if self.bet_amount > self.player_gold:
                return False

            self.bonus_bet = self.bet_amount
            self.player_gold -= self.bet_amount
            self.state = self.STATE_BONUS_SPINNING
            self.stopped_reels = 0

            for reel in self.reels:
                reel.start_spin()

            self.play_spin_sound = True
            return True

        return False

    def stop_current_reel(self):
        """현재 릴 정지 (클릭 시)"""
        if self.state == self.STATE_SPINNING:
            if self.stopped_reels < 3:
                reel = self.reels[self.stopped_reels]
                if reel.is_spinning and not reel.is_stopped:
                    reel.stop_spin()
                    self.stopped_reels += 1
                    self.play_stop_sound = True

                    if self.stopped_reels >= 3:
                        self.state = self.STATE_STOPPING

        elif self.state == self.STATE_BONUS_SPINNING:
            if self.stopped_reels < 3:
                reel = self.reels[self.stopped_reels]
                if reel.is_spinning and not reel.is_stopped:
                    # 보너스 라운드: 강제로 동일 심볼
                    reel.stop_spin(forced_symbol=self.bonus_symbol)
                    self.stopped_reels += 1
                    self.play_stop_sound = True

                    if self.stopped_reels >= 3:
                        self.state = self.STATE_STOPPING

    def update(self, dt):
        """게임 업데이트"""
        self.animation_timer += dt

        # 릴 업데이트
        all_stopped = True
        for reel in self.reels:
            reel.update(dt)
            if reel.is_spinning:
                all_stopped = False

        # 모든 릴이 정지되면 결과 계산
        if self.state == self.STATE_STOPPING and all_stopped:
            self._calculate_result()

        # 결과 표시 타이머
        if self.state in [self.STATE_RESULT, self.STATE_BONUS_RESULT]:
            self.result_display_timer += dt

    def _calculate_result(self):
        """결과 계산"""
        self.result_symbols = [reel.get_center_symbol() for reel in self.reels]

        # 3개 모두 동일한지 확인
        if self.result_symbols[0] == self.result_symbols[1] == self.result_symbols[2]:
            symbol = self.result_symbols[0]
            symbol_data = SlotSymbol.SYMBOLS[symbol]

            # 럭키 7 (보너스 라운드)
            if symbol_data.get("bonus"):
                self.is_bonus = True
                self.bonus_symbol = SlotSymbol.get_random_symbol()
                # 7이 아닌 다른 심볼로
                while SlotSymbol.SYMBOLS[self.bonus_symbol].get("bonus"):
                    self.bonus_symbol = SlotSymbol.get_random_symbol()
                self.state = self.STATE_BONUS_BETTING
                self.play_jackpot_sound = True
            else:
                # 일반 당첨
                multiplier = symbol_data["multiplier"]

                # 보너스 라운드 결과면 x2 추가
                if self.bonus_round:
                    multiplier *= 2
                    self.bonus_round = False

                self.win_multiplier = multiplier
                self.win_amount = self.bet_amount * multiplier
                self.player_gold += self.win_amount
                self.is_jackpot = multiplier >= 7

                if self.bonus_round:
                    self.state = self.STATE_BONUS_RESULT
                else:
                    self.state = self.STATE_RESULT

                self.result_display_timer = 0

                if self.is_jackpot:
                    self.play_jackpot_sound = True
                else:
                    self.play_win_sound = True
        else:
            # 꽝
            self.win_amount = 0
            self.win_multiplier = 0

            if self.bonus_round:
                # 보너스 라운드 실패 (원래 배팅금은 이미 차감됨)
                self.bonus_round = False
                self.state = self.STATE_BONUS_RESULT
            else:
                self.state = self.STATE_RESULT

            self.result_display_timer = 0
            self.play_lose_sound = True

    def start_bonus_round(self):
        """보너스 라운드 시작"""
        self.bonus_round = True
        self.state = self.STATE_BONUS_BETTING
        self.bet_amount = min(self.bet_amount, self.player_gold, self.max_bet)

    def reset_for_new_game(self):
        """새 게임 준비"""
        self.state = self.STATE_BETTING
        self.result_symbols = [None, None, None]
        self.win_amount = 0
        self.win_multiplier = 0
        self.is_jackpot = False
        self.is_bonus = False
        self.result_display_timer = 0
        self.stopped_reels = 0
        self.bonus_round = False


# ============================================
# 빠칭코 게임 UI
# ============================================
class PachinkoGameUI:
    """빠칭코 게임 미니창 UI"""

    def __init__(self, screen_width, screen_height, fonts=None):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.fonts = fonts or {}

        self.game = PachinkoGame()
        self.is_active = False

        # 미니창 크기 (크레인보다 크게, Y축 넓게)
        self.window_width = 480
        self.window_height = 580
        self.window_x = (screen_width - self.window_width) // 2
        self.window_y = (screen_height - self.window_height) // 2 - 20

        # 애니메이션
        self.animation_timer = 0
        self.particles = []

        # 색상
        self.COLORS = {
            "bg_dark": (20, 10, 35),
            "bg_gradient_top": (40, 20, 60),
            "bg_gradient_bottom": (15, 8, 25),
            "frame_gold": (255, 200, 80),
            "frame_gold_dark": (180, 140, 50),
            "neon_pink": (255, 80, 150),
            "neon_cyan": (80, 220, 255),
            "neon_yellow": (255, 240, 100),
            "neon_green": (100, 255, 150),
            "reel_bg": (25, 15, 40),
            "reel_highlight": (60, 40, 80),
            "text_white": (255, 255, 255),
            "text_gold": (255, 215, 100),
            "button_bg": (60, 40, 80),
            "button_hover": (100, 70, 130),
            "win_line": (255, 50, 50),
        }

    def start_game(self, player_gold):
        """게임 시작"""
        self.is_active = True
        self.game = PachinkoGame()
        self.game.set_player_gold(player_gold)
        self.particles = []

    def get_player_gold(self):
        """현재 플레이어 골드"""
        return self.game.player_gold

    def update(self, dt):
        """업데이트"""
        if not self.is_active:
            return

        self.animation_timer += dt
        self.game.update(dt)

        # 파티클 업데이트
        self.particles = [p for p in self.particles if p.update(dt)]

        # 당첨 시 파티클 생성
        if self.game.is_jackpot and self.game.state == self.game.STATE_RESULT:
            if random.random() < 0.3:
                self._spawn_win_particle()

    def _spawn_win_particle(self):
        """승리 파티클 생성"""
        x = self.window_x + random.randint(50, self.window_width - 50)
        y = self.window_y + random.randint(100, 300)
        color = random.choice([
            (255, 215, 0), (255, 100, 150), (100, 220, 255), (255, 255, 100)
        ])
        vx = random.uniform(-50, 50)
        vy = random.uniform(-100, -50)
        self.particles.append(Particle(x, y, color, vx, vy, life=1.5, size=4, gravity=100))

    def handle_event(self, event):
        """이벤트 처리"""
        if not self.is_active:
            return None

        # ESC로 종료
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                # 회전 중이 아닐 때만 종료 가능
                if self.game.state in [self.game.STATE_BETTING, self.game.STATE_RESULT,
                                       self.game.STATE_BONUS_RESULT]:
                    self.is_active = False
                    return "exit"

            # 스페이스로 스핀/다음
            elif event.key == pygame.K_SPACE:
                if self.game.state in [self.game.STATE_BETTING, self.game.STATE_BONUS_BETTING]:
                    self.game.start_spin()
                elif self.game.state in [self.game.STATE_SPINNING, self.game.STATE_BONUS_SPINNING]:
                    self.game.stop_current_reel()
                elif self.game.state == self.game.STATE_RESULT:
                    if self.game.result_display_timer > 1.0:
                        self.game.reset_for_new_game()
                elif self.game.state == self.game.STATE_BONUS_RESULT:
                    if self.game.result_display_timer > 1.0:
                        self.game.reset_for_new_game()

        # 마우스 휠로 배팅 조절
        elif event.type == pygame.MOUSEWHEEL:
            self.game.adjust_bet(event.y * 5)

        # 마우스 클릭
        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:  # 좌클릭
                mouse_pos = pygame.mouse.get_pos()

                # 창 내부 클릭 확인
                if self._is_inside_window(mouse_pos):
                    # 회전 중이면 릴 정지
                    if self.game.state in [self.game.STATE_SPINNING, self.game.STATE_BONUS_SPINNING]:
                        self.game.stop_current_reel()
                    # 버튼 클릭 확인
                    else:
                        self._handle_button_click(mouse_pos)

        return None

    def _is_inside_window(self, pos):
        """창 내부인지 확인"""
        return (self.window_x <= pos[0] <= self.window_x + self.window_width and
                self.window_y <= pos[1] <= self.window_y + self.window_height)

    def _handle_button_click(self, pos):
        """버튼 클릭 처리"""
        # 스핀 버튼 영역
        spin_btn = self._get_spin_button_rect()
        if spin_btn.collidepoint(pos):
            if self.game.state in [self.game.STATE_BETTING, self.game.STATE_BONUS_BETTING]:
                self.game.start_spin()
            elif self.game.state in [self.game.STATE_RESULT, self.game.STATE_BONUS_RESULT]:
                if self.game.result_display_timer > 0.5:
                    self.game.reset_for_new_game()

        # 배팅 +/- 버튼
        plus_btn = self._get_bet_plus_button_rect()
        minus_btn = self._get_bet_minus_button_rect()

        if plus_btn.collidepoint(pos):
            self.game.adjust_bet(10)
        elif minus_btn.collidepoint(pos):
            self.game.adjust_bet(-10)

    def _get_spin_button_rect(self):
        """스핀 버튼 영역"""
        btn_w, btn_h = 120, 45
        btn_x = self.window_x + (self.window_width - btn_w) // 2
        btn_y = self.window_y + self.window_height - 70
        return pygame.Rect(btn_x, btn_y, btn_w, btn_h)

    def _get_bet_plus_button_rect(self):
        """배팅 + 버튼"""
        return pygame.Rect(self.window_x + self.window_width - 80,
                          self.window_y + self.window_height - 130, 35, 35)

    def _get_bet_minus_button_rect(self):
        """배팅 - 버튼"""
        return pygame.Rect(self.window_x + 45,
                          self.window_y + self.window_height - 130, 35, 35)

    def draw(self, screen):
        """화면 그리기"""
        if not self.is_active:
            return

        # 배경 어둡게
        overlay = pygame.Surface((self.screen_width, self.screen_height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 200))
        screen.blit(overlay, (0, 0))

        # 메인 창 그리기
        self._draw_machine_frame(screen)
        self._draw_reels(screen)
        self._draw_ui(screen)
        self._draw_particles(screen)

        # 결과 오버레이
        if self.game.state in [self.game.STATE_RESULT, self.game.STATE_BONUS_RESULT]:
            self._draw_result_overlay(screen)
        elif self.game.state == self.game.STATE_BONUS_BETTING:
            self._draw_bonus_overlay(screen)

    def _draw_machine_frame(self, screen):
        """슬롯머신 프레임 그리기"""
        C = self.COLORS
        x, y, w, h = self.window_x, self.window_y, self.window_width, self.window_height

        # 그림자
        shadow_surf = pygame.Surface((w + 20, h + 20), pygame.SRCALPHA)
        pygame.draw.rect(shadow_surf, (0, 0, 0, 100), (10, 10, w, h), border_radius=15)
        screen.blit(shadow_surf, (x - 5, y - 5))

        # 메인 프레임 (그라데이션)
        frame_surf = pygame.Surface((w, h), pygame.SRCALPHA)
        for i in range(h):
            ratio = i / h
            r = int(C["bg_gradient_top"][0] * (1 - ratio) + C["bg_gradient_bottom"][0] * ratio)
            g = int(C["bg_gradient_top"][1] * (1 - ratio) + C["bg_gradient_bottom"][1] * ratio)
            b = int(C["bg_gradient_top"][2] * (1 - ratio) + C["bg_gradient_bottom"][2] * ratio)
            pygame.draw.line(frame_surf, (r, g, b), (0, i), (w, i))

        # 둥근 마스크
        mask = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.rect(mask, (255, 255, 255), (0, 0, w, h), border_radius=15)
        frame_surf.blit(mask, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
        screen.blit(frame_surf, (x, y))

        # 테두리 (골드 + 글로우)
        pygame.draw.rect(screen, C["frame_gold_dark"], (x - 3, y - 3, w + 6, h + 6), 4, border_radius=18)
        pygame.draw.rect(screen, C["frame_gold"], (x, y, w, h), 3, border_radius=15)

        # 상단 장식 (네온 사인)
        self._draw_header(screen, x, y, w)

        # LED 라이트
        self._draw_led_lights(screen, x, y, w, h)

    def _draw_header(self, screen, x, y, w):
        """상단 헤더 (네온 사인)"""
        C = self.COLORS
        header_h = 50
        header_y = y + 10

        # 헤더 배경
        header_rect = pygame.Rect(x + 20, header_y, w - 40, header_h)
        pygame.draw.rect(screen, (30, 15, 45), header_rect, border_radius=8)
        pygame.draw.rect(screen, C["frame_gold"], header_rect, 2, border_radius=8)

        # "SLOT" 네온 텍스트
        font = self.fonts.get("large") or self.fonts.get("medium")
        if font:
            # 글로우 효과
            glow_intensity = int(200 + 55 * math.sin(self.animation_timer * 4))
            text = "★ SLOT MACHINE ★"

            for offset in range(3, 0, -1):
                glow_color = (*C["neon_pink"][:3], glow_intensity // (offset + 1))
                try:
                    glow_surf, _ = font.render(text, glow_color)
                    screen.blit(glow_surf, (x + w // 2 - glow_surf.get_width() // 2 - offset,
                                           header_y + 12 - offset))
                except:
                    pass

            try:
                text_surf, _ = font.render(text, C["text_white"])
                screen.blit(text_surf, (x + w // 2 - text_surf.get_width() // 2, header_y + 12))
            except:
                pass

    def _draw_led_lights(self, screen, x, y, w, h):
        """LED 라이트 장식"""
        C = self.COLORS
        colors = [C["neon_pink"], C["neon_yellow"], C["neon_green"], C["neon_cyan"]]

        # 좌측 LED
        for i in range(8):
            led_y = y + 80 + i * 50
            if led_y > y + h - 100:
                break
            color_idx = (i + int(self.animation_timer * 5)) % len(colors)
            color = colors[color_idx]
            blink = math.sin(self.animation_timer * 8 + i * 0.7) > 0

            if blink:
                # 글로우
                glow_surf = pygame.Surface((16, 16), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*color, 80), (8, 8), 8)
                screen.blit(glow_surf, (x + 8, led_y - 4))
            pygame.draw.circle(screen, color if blink else (color[0]//3, color[1]//3, color[2]//3),
                              (x + 16, led_y + 4), 5)

        # 우측 LED
        for i in range(8):
            led_y = y + 80 + i * 50
            if led_y > y + h - 100:
                break
            color_idx = (i + int(self.animation_timer * 5) + 2) % len(colors)
            color = colors[color_idx]
            blink = math.sin(self.animation_timer * 8 + i * 0.7 + 3.14) > 0

            if blink:
                glow_surf = pygame.Surface((16, 16), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*color, 80), (8, 8), 8)
                screen.blit(glow_surf, (x + w - 24, led_y - 4))
            pygame.draw.circle(screen, color if blink else (color[0]//3, color[1]//3, color[2]//3),
                              (x + w - 16, led_y + 4), 5)

    def _draw_reels(self, screen):
        """슬롯 릴 그리기"""
        C = self.COLORS
        x, y = self.window_x, self.window_y

        # 릴 영역
        reel_area_x = x + 50
        reel_area_y = y + 80
        reel_area_w = self.window_width - 100
        reel_area_h = 280

        # 릴 영역 배경
        pygame.draw.rect(screen, C["reel_bg"],
                        (reel_area_x, reel_area_y, reel_area_w, reel_area_h), border_radius=10)
        pygame.draw.rect(screen, C["frame_gold_dark"],
                        (reel_area_x, reel_area_y, reel_area_w, reel_area_h), 3, border_radius=10)

        # 각 릴 그리기
        reel_width = (reel_area_w - 40) // 3
        reel_spacing = 10

        for i, reel in enumerate(self.game.reels):
            reel_x = reel_area_x + 15 + i * (reel_width + reel_spacing)
            self._draw_single_reel(screen, reel, reel_x, reel_area_y + 15,
                                  reel_width, reel_area_h - 30, i)

        # 당첨 라인 (중앙 가로선)
        line_y = reel_area_y + reel_area_h // 2
        pygame.draw.line(screen, C["win_line"],
                        (reel_area_x - 10, line_y), (reel_area_x + reel_area_w + 10, line_y), 3)
        # 화살표
        pygame.draw.polygon(screen, C["win_line"], [
            (reel_area_x - 15, line_y),
            (reel_area_x - 5, line_y - 8),
            (reel_area_x - 5, line_y + 8)
        ])
        pygame.draw.polygon(screen, C["win_line"], [
            (reel_area_x + reel_area_w + 15, line_y),
            (reel_area_x + reel_area_w + 5, line_y - 8),
            (reel_area_x + reel_area_w + 5, line_y + 8)
        ])

    def _draw_single_reel(self, screen, reel, x, y, w, h, reel_index):
        """개별 릴 그리기"""
        C = self.COLORS

        # 릴 배경
        pygame.draw.rect(screen, (35, 20, 50), (x, y, w, h), border_radius=8)

        # 릴 하이라이트
        highlight_surf = pygame.Surface((w, 20), pygame.SRCALPHA)
        pygame.draw.rect(highlight_surf, (80, 60, 100, 100), (0, 0, w, 20), border_radius=8)
        screen.blit(highlight_surf, (x, y))

        # 심볼 그리기 (3개: 위, 중앙, 아래)
        symbols = reel.get_visible_symbols(3)
        symbol_h = h // 3

        # 회전 오프셋 계산
        scroll_offset = (reel.current_offset % 1) * symbol_h if reel.is_spinning else 0

        for i, symbol in enumerate(symbols):
            symbol_y = y + i * symbol_h - scroll_offset + symbol_h // 6
            # 화면 밖이면 스킵
            if symbol_y < y - symbol_h or symbol_y > y + h:
                continue
            self._draw_symbol(screen, symbol, x + 5, symbol_y, w - 10, symbol_h - 10,
                            is_center=(i == 1))

        # 릴 테두리
        pygame.draw.rect(screen, C["frame_gold_dark"], (x, y, w, h), 2, border_radius=8)

        # 정지된 릴 표시
        if reel.is_stopped or not reel.is_spinning:
            if self.game.stopped_reels > reel_index or self.game.state in [
                self.game.STATE_RESULT, self.game.STATE_BONUS_RESULT]:
                # 정지 완료 표시 (체크마크)
                check_x = x + w - 20
                check_y = y + 10
                pygame.draw.circle(screen, C["neon_green"], (check_x, check_y), 10)
                pygame.draw.lines(screen, (255, 255, 255), False, [
                    (check_x - 5, check_y), (check_x - 1, check_y + 4), (check_x + 5, check_y - 4)
                ], 2)

    def _draw_symbol(self, screen, symbol_name, x, y, w, h, is_center=False):
        """심볼 그리기"""
        symbol_data = SlotSymbol.SYMBOLS.get(symbol_name, {})
        color = symbol_data.get("color", (200, 200, 200))

        # 심볼 배경
        bg_color = (color[0]//4, color[1]//4, color[2]//4)
        pygame.draw.rect(screen, bg_color, (x, y, w, h), border_radius=6)

        # 중앙 심볼 강조
        if is_center:
            pygame.draw.rect(screen, color, (x, y, w, h), 2, border_radius=6)

        # 심볼 아이콘 그리기
        cx = x + w // 2
        cy = y + h // 2

        if symbol_name == "pingpong":
            # 탁구공
            pygame.draw.circle(screen, (255, 255, 255), (cx, cy), min(w, h) // 3)
            pygame.draw.circle(screen, (200, 200, 200), (cx, cy), min(w, h) // 3, 2)
            # 줄무늬
            pygame.draw.arc(screen, (220, 220, 220),
                          (cx - min(w,h)//3, cy - min(w,h)//3, min(w,h)*2//3, min(w,h)*2//3),
                          0.5, 2.5, 2)

        elif symbol_name == "banana":
            # 바나나
            pygame.draw.arc(screen, (255, 230, 50),
                          (cx - 20, cy - 15, 40, 40), 0.5, 2.8, 8)
            pygame.draw.arc(screen, (200, 180, 40),
                          (cx - 20, cy - 15, 40, 40), 0.5, 2.8, 2)

        elif symbol_name == "apple":
            # 사과
            pygame.draw.circle(screen, (220, 50, 50), (cx, cy + 3), min(w, h) // 3)
            pygame.draw.circle(screen, (180, 40, 40), (cx, cy + 3), min(w, h) // 3, 2)
            # 꼭지
            pygame.draw.rect(screen, (100, 70, 40), (cx - 2, cy - 18, 4, 10))
            # 잎
            pygame.draw.ellipse(screen, (80, 180, 80), (cx + 2, cy - 20, 12, 8))

        elif symbol_name == "key":
            # 열쇠
            pygame.draw.circle(screen, (255, 200, 100), (cx - 8, cy - 5), 10)
            pygame.draw.circle(screen, (200, 150, 70), (cx - 8, cy - 5), 6)
            pygame.draw.rect(screen, (255, 200, 100), (cx - 2, cy - 5, 20, 5))
            pygame.draw.rect(screen, (255, 200, 100), (cx + 10, cy, 5, 8))
            pygame.draw.rect(screen, (255, 200, 100), (cx + 5, cy, 5, 6))

        elif symbol_name == "diamond":
            # 다이아몬드
            points = [(cx, cy - 20), (cx + 18, cy), (cx, cy + 20), (cx - 18, cy)]
            pygame.draw.polygon(screen, (100, 200, 255), points)
            pygame.draw.polygon(screen, (200, 240, 255), points, 2)
            # 내부 빛
            inner_points = [(cx, cy - 10), (cx + 8, cy), (cx, cy + 10), (cx - 8, cy)]
            pygame.draw.polygon(screen, (200, 240, 255), inner_points)

        elif symbol_name == "pandora":
            # 판도라 상자
            pygame.draw.rect(screen, (120, 60, 160), (cx - 15, cy - 10, 30, 25), border_radius=3)
            pygame.draw.rect(screen, (180, 100, 220), (cx - 15, cy - 15, 30, 10), border_radius=3)
            # 잠금장치
            pygame.draw.circle(screen, (255, 215, 0), (cx, cy + 2), 5)
            pygame.draw.rect(screen, (255, 215, 0), (cx - 2, cy - 3, 4, 8))
            # 빛나는 효과
            glow = int(100 + 50 * math.sin(self.animation_timer * 5))
            glow_surf = pygame.Surface((40, 40), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (180, 100, 255, glow), (5, 5, 30, 30), border_radius=5)
            screen.blit(glow_surf, (cx - 20, cy - 15))

        elif symbol_name == "seven":
            # 럭키 7
            # 배경 글로우
            glow = int(150 + 100 * math.sin(self.animation_timer * 6))
            glow_surf = pygame.Surface((w, h), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (255, 215, 0, glow), (0, 0, w, h), border_radius=6)
            screen.blit(glow_surf, (x, y))

            # 7 그리기
            pygame.draw.rect(screen, (255, 50, 50), (cx - 15, cy - 20, 30, 8), border_radius=2)
            pygame.draw.polygon(screen, (255, 50, 50), [
                (cx + 10, cy - 12), (cx + 15, cy - 12),
                (cx - 5, cy + 20), (cx - 10, cy + 20)
            ])
            # 테두리
            pygame.draw.rect(screen, (255, 255, 200), (cx - 15, cy - 20, 30, 8), 2, border_radius=2)

    def _draw_ui(self, screen):
        """UI 요소 그리기"""
        C = self.COLORS
        x, y = self.window_x, self.window_y
        w, h = self.window_width, self.window_height

        # 하단 패널
        panel_y = y + h - 160
        panel_h = 150
        pygame.draw.rect(screen, (30, 20, 45), (x + 10, panel_y, w - 20, panel_h), border_radius=10)
        pygame.draw.rect(screen, C["frame_gold_dark"], (x + 10, panel_y, w - 20, panel_h), 2, border_radius=10)

        # 골드 표시
        font_medium = self.fonts.get("medium")
        font_small = self.fonts.get("small")

        if font_small:
            gold_text = f"보유 골드: {self.game.player_gold:,} G"
            gold_surf, _ = font_small.render(gold_text, C["text_gold"])
            screen.blit(gold_surf, (x + 30, panel_y + 15))

        # 배팅 금액
        bet_y = panel_y + 45
        if font_small:
            bet_label = "배팅:"
            bet_surf, _ = font_small.render(bet_label, C["text_white"])
            screen.blit(bet_surf, (x + 30, bet_y))

        # 배팅 금액 표시
        bet_display_x = x + w // 2 - 40
        bet_display_w = 80
        pygame.draw.rect(screen, (50, 35, 70), (bet_display_x, bet_y - 5, bet_display_w, 30), border_radius=5)
        pygame.draw.rect(screen, C["neon_yellow"], (bet_display_x, bet_y - 5, bet_display_w, 30), 2, border_radius=5)

        if font_medium:
            bet_text = f"{self.game.bet_amount}"
            bet_surf, _ = font_medium.render(bet_text, C["neon_yellow"])
            screen.blit(bet_surf, (bet_display_x + bet_display_w // 2 - bet_surf.get_width() // 2, bet_y))

        # +/- 버튼
        minus_btn = self._get_bet_minus_button_rect()
        plus_btn = self._get_bet_plus_button_rect()

        mouse_pos = pygame.mouse.get_pos()

        # - 버튼
        minus_hover = minus_btn.collidepoint(mouse_pos)
        pygame.draw.rect(screen, C["button_hover"] if minus_hover else C["button_bg"], minus_btn, border_radius=5)
        pygame.draw.rect(screen, C["neon_cyan"], minus_btn, 2, border_radius=5)
        if font_medium:
            minus_surf, _ = font_medium.render("-", C["text_white"])
            screen.blit(minus_surf, (minus_btn.centerx - minus_surf.get_width() // 2,
                                    minus_btn.centery - minus_surf.get_height() // 2))

        # + 버튼
        plus_hover = plus_btn.collidepoint(mouse_pos)
        pygame.draw.rect(screen, C["button_hover"] if plus_hover else C["button_bg"], plus_btn, border_radius=5)
        pygame.draw.rect(screen, C["neon_cyan"], plus_btn, 2, border_radius=5)
        if font_medium:
            plus_surf, _ = font_medium.render("+", C["text_white"])
            screen.blit(plus_surf, (plus_btn.centerx - plus_surf.get_width() // 2,
                                   plus_btn.centery - plus_surf.get_height() // 2))

        # 스핀 버튼
        spin_btn = self._get_spin_button_rect()
        spin_hover = spin_btn.collidepoint(mouse_pos)

        # 버튼 상태에 따른 색상
        if self.game.state in [self.game.STATE_BETTING, self.game.STATE_BONUS_BETTING]:
            btn_color = C["neon_green"] if spin_hover else (80, 200, 100)
            btn_text = "SPIN!"
        elif self.game.state in [self.game.STATE_SPINNING, self.game.STATE_BONUS_SPINNING]:
            btn_color = C["neon_pink"]
            btn_text = "STOP!"
        else:
            btn_color = C["neon_cyan"] if spin_hover else (60, 180, 200)
            btn_text = "다시"

        # 버튼 글로우
        glow_surf = pygame.Surface((spin_btn.width + 10, spin_btn.height + 10), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*btn_color, 80), (0, 0, spin_btn.width + 10, spin_btn.height + 10), border_radius=10)
        screen.blit(glow_surf, (spin_btn.x - 5, spin_btn.y - 5))

        pygame.draw.rect(screen, btn_color, spin_btn, border_radius=8)
        pygame.draw.rect(screen, C["text_white"], spin_btn, 2, border_radius=8)

        if font_medium:
            spin_surf, _ = font_medium.render(btn_text, C["text_white"])
            screen.blit(spin_surf, (spin_btn.centerx - spin_surf.get_width() // 2,
                                   spin_btn.centery - spin_surf.get_height() // 2))

        # 조작 힌트
        if font_small:
            if self.game.state in [self.game.STATE_BETTING, self.game.STATE_BONUS_BETTING]:
                hint = "마우스 휠: 배팅 조절 | 클릭/Space: 스핀"
            elif self.game.state in [self.game.STATE_SPINNING, self.game.STATE_BONUS_SPINNING]:
                hint = f"클릭/Space: 슬롯 정지 ({self.game.stopped_reels}/3)"
            else:
                hint = "클릭/Space: 다시 | ESC: 나가기"

            hint_surf, _ = font_small.render(hint, (150, 150, 180))
            screen.blit(hint_surf, (x + w // 2 - hint_surf.get_width() // 2, y + h - 20))

    def _draw_result_overlay(self, screen):
        """결과 오버레이"""
        C = self.COLORS
        x, y = self.window_x, self.window_y
        w, h = self.window_width, self.window_height

        # 반투명 오버레이
        overlay = pygame.Surface((w - 80, 120), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        screen.blit(overlay, (x + 40, y + 200))

        font_large = self.fonts.get("large") or self.fonts.get("medium")
        font_medium = self.fonts.get("medium")

        if self.game.win_amount > 0:
            # 당첨
            if self.game.is_jackpot:
                result_text = "★ JACKPOT! ★"
                result_color = C["neon_yellow"]
            else:
                result_text = "WIN!"
                result_color = C["neon_green"]

            win_text = f"+{self.game.win_amount:,} G (x{self.game.win_multiplier})"

            # 글로우 효과
            glow = int(200 + 55 * math.sin(self.animation_timer * 8))

            if font_large:
                for offset in range(3, 0, -1):
                    try:
                        glow_surf, _ = font_large.render(result_text, (*result_color, glow // offset))
                        screen.blit(glow_surf, (x + w // 2 - glow_surf.get_width() // 2 - offset,
                                               y + 220 - offset))
                    except:
                        pass
                result_surf, _ = font_large.render(result_text, result_color)
                screen.blit(result_surf, (x + w // 2 - result_surf.get_width() // 2, y + 220))

            if font_medium:
                win_surf, _ = font_medium.render(win_text, C["text_gold"])
                screen.blit(win_surf, (x + w // 2 - win_surf.get_width() // 2, y + 270))
        else:
            # 꽝
            if font_large:
                lose_text = "MISS..."
                lose_surf, _ = font_large.render(lose_text, (150, 100, 100))
                screen.blit(lose_surf, (x + w // 2 - lose_surf.get_width() // 2, y + 240))

    def _draw_bonus_overlay(self, screen):
        """보너스 라운드 오버레이"""
        C = self.COLORS
        x, y = self.window_x, self.window_y
        w, h = self.window_width, self.window_height

        # 반투명 오버레이
        overlay = pygame.Surface((w - 60, 150), pygame.SRCALPHA)
        overlay.fill((50, 20, 80, 220))
        screen.blit(overlay, (x + 30, y + 180))
        pygame.draw.rect(screen, C["neon_yellow"], (x + 30, y + 180, w - 60, 150), 3, border_radius=10)

        font_large = self.fonts.get("large") or self.fonts.get("medium")
        font_medium = self.fonts.get("medium")
        font_small = self.fonts.get("small")

        # 보너스 라운드 텍스트
        glow = int(200 + 55 * math.sin(self.animation_timer * 6))

        if font_large:
            bonus_text = "★ BONUS ROUND! ★"
            for offset in range(3, 0, -1):
                try:
                    glow_surf, _ = font_large.render(bonus_text, (*C["neon_yellow"], glow // offset))
                    screen.blit(glow_surf, (x + w // 2 - glow_surf.get_width() // 2 - offset,
                                           y + 195 - offset))
                except:
                    pass
            bonus_surf, _ = font_large.render(bonus_text, C["neon_yellow"])
            screen.blit(bonus_surf, (x + w // 2 - bonus_surf.get_width() // 2, y + 195))

        if font_medium:
            # 설명
            desc_text = "다시 배팅하세요! 무조건 3개 일치!"
            desc_surf, _ = font_medium.render(desc_text, C["text_white"])
            screen.blit(desc_surf, (x + w // 2 - desc_surf.get_width() // 2, y + 240))

            # 보너스 심볼 표시
            symbol_data = SlotSymbol.SYMBOLS.get(self.game.bonus_symbol, {})
            symbol_text = f"당첨 심볼: {symbol_data.get('name', '???')} (x{symbol_data.get('multiplier', 0) * 2})"
            symbol_surf, _ = font_medium.render(symbol_text, C["text_gold"])
            screen.blit(symbol_surf, (x + w // 2 - symbol_surf.get_width() // 2, y + 275))

        if font_small:
            hint_text = "배팅 후 SPIN을 눌러 보너스 획득!"
            hint_surf, _ = font_small.render(hint_text, (180, 180, 200))
            screen.blit(hint_surf, (x + w // 2 - hint_surf.get_width() // 2, y + 310))

    def _draw_particles(self, screen):
        """파티클 그리기"""
        for particle in self.particles:
            particle.draw(screen)


# ============================================
# 파티클 클래스
# ============================================
class Particle:
    """파티클 효과"""

    def __init__(self, x, y, color, vx=0, vy=0, life=1.0, size=3, gravity=0):
        self.x = x
        self.y = y
        self.color = color
        self.vx = vx
        self.vy = vy
        self.life = life
        self.max_life = life
        self.size = size
        self.gravity = gravity

    def update(self, dt):
        self.x += self.vx * dt
        self.y += self.vy * dt
        self.vy += self.gravity * dt
        self.life -= dt
        return self.life > 0

    def draw(self, screen):
        if self.life <= 0:
            return
        alpha = int(255 * (self.life / self.max_life))
        surf = pygame.Surface((self.size * 2, self.size * 2), pygame.SRCALPHA)
        pygame.draw.circle(surf, (*self.color[:3], alpha), (self.size, self.size), self.size)
        screen.blit(surf, (self.x - self.size, self.y - self.size))
