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
        "apple": {"name": "사과", "multiplier": 3, "color": (220, 50, 50)},
        "key": {"name": "열쇠", "multiplier": 5, "color": (255, 200, 100)},
        "banana": {"name": "금괴", "multiplier": 7, "color": (255, 215, 0)},
        "pingpong": {"name": "진주", "multiplier": 10, "color": (255, 255, 255)},
        "diamond": {"name": "다이아몬드", "multiplier": 20, "color": (100, 200, 255)},
        "pandora": {"name": "판도라 상자", "multiplier": 30, "color": (180, 100, 255)},
        "seven": {"name": "럭키 7", "multiplier": 0, "color": (255, 215, 0), "bonus": True},  # 보너스 라운드
    }

    # 심볼 등장 확률 (가중치) - 배율 순서대로 재정렬
    WEIGHTS = {
        "apple": 30,      # 가장 흔함 (x3)
        "key": 25,        # (x5)
        "banana": 20,     # (x7)
        "pingpong": 12,   # (x10)
        "diamond": 8,     # (x20)
        "pandora": 4,     # (x30)
        "seven": 1,       # 가장 희귀 (보너스)
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

    # 3매치 확률 부스트 설정 (0.0 ~ 1.0)
    # 0.0 = 완전 랜덤, 1.0 = 거의 항상 매칭
    MATCH_BOOST_CHANCE_REEL2 = 0.35  # 두 번째 릴: 35% 확률로 첫 번째 릴과 동일
    MATCH_BOOST_CHANCE_REEL3 = 0.08  # 세 번째 릴: 8% 확률로 (매우 어렵게)

    def __init__(self):
        self.reels = [SlotReel(i) for i in range(3)]
        self.state = self.STATE_BETTING

        # 배팅 관련
        self.bet_amount = 5
        self.min_bet = 1
        self.max_bet = 30
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

        # 매칭 부스트용 - 첫 번째 릴의 심볼 저장
        self.first_reel_symbol = None

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

    def _get_boosted_symbol(self, reel_index):
        """매칭 부스트가 적용된 심볼 선택"""
        # 첫 번째 릴은 완전 랜덤
        if reel_index == 0:
            symbol = SlotSymbol.get_random_symbol()
            self.first_reel_symbol = symbol
            return symbol

        # 두 번째 릴: 35% 확률로 첫 번째와 동일
        if reel_index == 1:
            if self.first_reel_symbol and random.random() < self.MATCH_BOOST_CHANCE_REEL2:
                return self.first_reel_symbol
            else:
                return SlotSymbol.get_random_symbol()

        # 세 번째 릴: 15% 확률로 첫 번째와 동일 (더 어렵게)
        if reel_index == 2:
            if self.first_reel_symbol and random.random() < self.MATCH_BOOST_CHANCE_REEL3:
                return self.first_reel_symbol
            else:
                return SlotSymbol.get_random_symbol()

        return SlotSymbol.get_random_symbol()

    def stop_current_reel(self):
        """현재 릴 정지 (클릭 시)"""
        if self.state == self.STATE_SPINNING:
            if self.stopped_reels < 3:
                reel = self.reels[self.stopped_reels]
                if reel.is_spinning and not reel.is_stopped:
                    # 매칭 부스트 적용된 심볼 선택
                    boosted_symbol = self._get_boosted_symbol(self.stopped_reels)
                    reel.stop_spin(forced_symbol=boosted_symbol)
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

        # 마우스 휠로 배팅 조절 (5골드씩)
        elif event.type == pygame.MOUSEWHEEL:
            mouse_pos = pygame.mouse.get_pos()
            if self._is_inside_window(mouse_pos):
                self.game.adjust_bet(event.y * 5)  # 휠 한 번에 5골드
                return "bet_adjust"

        # 마우스 클릭
        elif event.type == pygame.MOUSEBUTTONDOWN:
            mouse_pos = event.pos if hasattr(event, 'pos') else pygame.mouse.get_pos()

            # 창 내부 클릭 확인
            if self._is_inside_window(mouse_pos):
                if event.button == 1:  # 좌클릭
                    # 회전 중이면 릴 정지
                    if self.game.state in [self.game.STATE_SPINNING, self.game.STATE_BONUS_SPINNING]:
                        self.game.stop_current_reel()
                        return "reel_stop"
                    # 버튼 클릭 확인
                    else:
                        result = self._handle_button_click(mouse_pos)
                        if result:
                            return result

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
                return "spin_start"
            elif self.game.state in [self.game.STATE_RESULT, self.game.STATE_BONUS_RESULT]:
                if self.game.result_display_timer > 0.5:
                    self.game.reset_for_new_game()
                    return "next_round"

        # 배팅 +/- 버튼
        plus_btn = self._get_bet_plus_button_rect()
        minus_btn = self._get_bet_minus_button_rect()

        if plus_btn.collidepoint(pos):
            self.game.adjust_bet(10)
            return "bet_plus"
        elif minus_btn.collidepoint(pos):
            self.game.adjust_bet(-10)
            return "bet_minus"

        return None

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
        """심볼 그리기 - 고퀄리티 실사풍"""
        symbol_data = SlotSymbol.SYMBOLS.get(symbol_name, {})
        color = symbol_data.get("color", (200, 200, 200))

        # 심볼 배경 (그라데이션 효과)
        bg_surf = pygame.Surface((w, h), pygame.SRCALPHA)
        for i in range(h):
            ratio = i / h
            r = int(30 + 20 * ratio)
            g = int(20 + 15 * ratio)
            b = int(50 + 20 * ratio)
            pygame.draw.line(bg_surf, (r, g, b, 230), (0, i), (w, i))
        pygame.draw.rect(bg_surf, (0, 0, 0, 0), (0, 0, w, h), border_radius=6)
        screen.blit(bg_surf, (x, y))
        pygame.draw.rect(screen, (60, 50, 80), (x, y, w, h), border_radius=6)

        # 중앙 심볼 강조 (글로우 효과)
        if is_center:
            glow_surf = pygame.Surface((w + 8, h + 8), pygame.SRCALPHA)
            glow_alpha = int(100 + 50 * math.sin(self.animation_timer * 4))
            pygame.draw.rect(glow_surf, (*color, glow_alpha), (0, 0, w + 8, h + 8), border_radius=8)
            screen.blit(glow_surf, (x - 4, y - 4))
            pygame.draw.rect(screen, color, (x, y, w, h), 3, border_radius=6)

        # 심볼 아이콘 그리기
        cx = x + w // 2
        cy = y + h // 2
        r = min(w, h) // 3  # 기본 반지름

        if symbol_name == "pingpong":
            # 진주 - 고급스러운 푸른빛 흰색 진주
            t = self.animation_timer

            # === 다층 그림자 (입체감) ===
            # 먼 그림자 (퍼짐)
            shadow_surf = pygame.Surface((r*2 + 10, 14), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_surf, (40, 50, 70, 50), (0, 0, r*2 + 6, 10))
            screen.blit(shadow_surf, (cx - r - 3, cy + r - 2))
            # 가까운 그림자
            pygame.draw.ellipse(screen, (50, 60, 80), (cx - r + 2, cy + r - 4, r*2 - 4, 8))

            # === 진주 베이스 (푸른빛 흰색) ===
            # 외곽 테두리 (살짝 푸른 그림자)
            pygame.draw.circle(screen, (200, 215, 235), (cx, cy), r + 1)

            # 진주 본체 - 다층 그라데이션
            for i in range(r, 0, -1):
                ratio = i / r

                # 중심으로 갈수록 밝아지고, 가장자리는 푸른빛
                # 푸른빛 강도 (가장자리에서 강하게)
                blue_strength = 0.4 * (1 - ratio) ** 0.7

                # 베이스 색상 (흰색 → 옅은 푸른빛)
                base_r = int(255 - 35 * (1 - ratio))
                base_g = int(255 - 20 * (1 - ratio))
                base_b = int(255 - 5 * (1 - ratio))

                # 푸른빛 블렌딩
                blue_tint_r = 180
                blue_tint_g = 210
                blue_tint_b = 255

                pr = int(base_r * (1 - blue_strength) + blue_tint_r * blue_strength)
                pg = int(base_g * (1 - blue_strength) + blue_tint_g * blue_strength)
                pb = int(base_b * (1 - blue_strength) + blue_tint_b * blue_strength)

                # 좌상단으로 살짝 오프셋 (빛 방향)
                offset_x = int(r * 0.08 * (1 - ratio))
                offset_y = int(r * 0.08 * (1 - ratio))

                pygame.draw.circle(screen, (min(255, pr), min(255, pg), min(255, pb)),
                                 (cx - offset_x, cy - offset_y), i)

            # === 광택 레이어 (여러 층) ===
            # 메인 광택 글로우 (부드러운 빛)
            glow_surf = pygame.Surface((r*2, r*2), pygame.SRCALPHA)
            for gi in range(r//2, 0, -1):
                glow_alpha = int(80 * (gi / (r//2)))
                pygame.draw.circle(glow_surf, (255, 255, 255, glow_alpha),
                                 (r//2 + 2, r//2 + 2), gi)
            screen.blit(glow_surf, (cx - r//2 - r//3, cy - r//2 - r//3))

            # === 메인 하이라이트 (좌상단 강한 빛) ===
            # 큰 하이라이트 (글로우)
            highlight_x = cx - r//3
            highlight_y = cy - r//3
            for hi in range(r//3 + 3, 0, -1):
                h_alpha = int(200 * (hi / (r//3 + 3)))
                h_surf = pygame.Surface((hi*2, hi*2), pygame.SRCALPHA)
                pygame.draw.circle(h_surf, (255, 255, 255, h_alpha), (hi, hi), hi)
                screen.blit(h_surf, (highlight_x - hi, highlight_y - hi))

            # 핵심 하이라이트 (순수 흰색)
            pygame.draw.circle(screen, (255, 255, 255), (highlight_x, highlight_y), r//4)
            pygame.draw.circle(screen, (255, 255, 255), (highlight_x - 2, highlight_y - 2), r//6)

            # === 보조 하이라이트들 ===
            # 우측 상단 작은 반사
            pygame.draw.circle(screen, (240, 248, 255), (cx + r//4, cy - r//4), r//7)
            pygame.draw.circle(screen, (255, 255, 255), (cx + r//4 - 1, cy - r//4 - 1), r//10)

            # 하단 미세 반사 (환경광)
            pygame.draw.circle(screen, (220, 235, 255, 150), (cx + r//6, cy + r//3), r//8)

            # === 푸른빛 무지개 광택 (회전) ===
            # 푸른 계열 색상
            blue_iridescent = [
                (200, 230, 255),  # 하늘색
                (180, 220, 255),  # 연한 파랑
                (220, 240, 255),  # 아이스 블루
                (190, 210, 250),  # 라벤더 블루
                (210, 235, 255),  # 페일 블루
            ]

            # 회전하는 무지개빛 아크
            irid_surf = pygame.Surface((r*2 + 8, r*2 + 8), pygame.SRCALPHA)
            for idx, irid_color in enumerate(blue_iridescent):
                arc_alpha = int(50 + 40 * math.sin(t * 2.5 + idx * 1.2))
                start_angle = (t * 0.8 + idx * (math.pi / 2.5)) % (2 * math.pi)
                end_angle = start_angle + 1.0

                pygame.draw.arc(irid_surf, (*irid_color, arc_alpha),
                              (4, 4, r*2, r*2), start_angle, end_angle, 3)
            screen.blit(irid_surf, (cx - r - 4, cy - r - 4))

            # === 림 라이트 (가장자리 빛) ===
            # 우하단 림 라이트 (반사광)
            rim_surf = pygame.Surface((r*2 + 4, r*2 + 4), pygame.SRCALPHA)
            rim_intensity = int(60 + 30 * math.sin(t * 3))
            pygame.draw.arc(rim_surf, (200, 230, 255, rim_intensity),
                          (2, 2, r*2, r*2), -0.8, 0.5, 2)
            pygame.draw.arc(rim_surf, (180, 220, 255, rim_intensity // 2),
                          (2, 2, r*2, r*2), -1.0, 0.7, 1)
            screen.blit(rim_surf, (cx - r - 2, cy - r - 2))

            # === 스파클 효과 (반짝임) ===
            sparkle_phase = t * 4

            # 메인 스파클
            sparkle1 = int(255 * max(0, math.sin(sparkle_phase)))
            if sparkle1 > 120:
                pygame.draw.circle(screen, (255, 255, 255), (cx - r//3 + 2, cy - r//3 + 2), 2)
                # 스파클 광선
                for angle in range(0, 360, 45):
                    rad = math.radians(angle)
                    end_x = cx - r//3 + 2 + int(4 * math.cos(rad))
                    end_y = cy - r//3 + 2 + int(4 * math.sin(rad))
                    pygame.draw.line(screen, (255, 255, 255, sparkle1),
                                   (cx - r//3 + 2, cy - r//3 + 2), (end_x, end_y), 1)

            # 서브 스파클
            sparkle2 = int(255 * max(0, math.sin(sparkle_phase + 2.5)))
            if sparkle2 > 180:
                pygame.draw.circle(screen, (230, 245, 255), (cx + r//5, cy - r//6), 2)

            sparkle3 = int(255 * max(0, math.sin(sparkle_phase + 4.5)))
            if sparkle3 > 200:
                pygame.draw.circle(screen, (255, 255, 255), (cx - r//5, cy + r//5), 1)

            # === 외곽 테두리 (부드러운 푸른빛) ===
            border_pulse = int(180 + 40 * math.sin(t * 2))
            pygame.draw.circle(screen, (border_pulse, min(255, border_pulse + 30), 255), (cx, cy), r, 1)

        elif symbol_name == "banana":
            # 금괴 - 초고급 리얼리스틱 골드바
            t = self.animation_timer

            # === 다층 그림자 (입체감 강화) ===
            # 멀리 퍼지는 그림자
            shadow_surf = pygame.Surface((50, 20), pygame.SRCALPHA)
            pygame.draw.ellipse(shadow_surf, (30, 25, 10, 60), (0, 0, 50, 12))
            screen.blit(shadow_surf, (cx - 25, cy + 14))
            # 가까운 그림자 (더 진하게)
            pygame.draw.polygon(screen, (50, 40, 15, 180), [
                (cx - 18, cy + 13), (cx + 20, cy + 13),
                (cx + 22, cy + 16), (cx - 16, cy + 16)
            ])

            # === 금괴 본체 - 3D 사다리꼴 ===
            # 왼쪽 면 (어두운 금색 - 그림자 면)
            left_face = [
                (cx - 16, cy - 8), (cx - 14, cy - 2),
                (cx - 18, cy + 12), (cx - 20, cy + 8)
            ]
            # 왼쪽 면 그라데이션
            for i in range(12):
                ratio = i / 12
                shade_r = int(140 + 40 * ratio)
                shade_g = int(110 + 30 * ratio)
                shade_b = int(20 + 15 * ratio)
                y_pos = cy - 2 + i
                x_left = cx - 14 - int(4 * (i / 12))
                x_right = cx - 14
                pygame.draw.line(screen, (shade_r, shade_g, shade_b),
                               (x_left, y_pos), (x_right, y_pos))

            # 앞면 (메인 골드 - 풍부한 그라데이션)
            front_face = [
                (cx - 14, cy - 2), (cx + 16, cy - 2),
                (cx + 18, cy + 12), (cx - 18, cy + 12)
            ]
            # 앞면 다층 그라데이션 (위에서 아래로)
            for i in range(14):
                ratio = i / 14
                # 위는 밝고 아래는 어둡게
                base_r = int(255 - 45 * ratio)
                base_g = int(210 - 50 * ratio)
                base_b = int(80 - 40 * ratio)
                y_pos = cy - 2 + i
                x_left = cx - 14 - int(4 * (i / 14))
                x_right = cx + 16 + int(2 * (i / 14))
                pygame.draw.line(screen, (base_r, base_g, base_b),
                               (x_left, y_pos), (x_right, y_pos))

            # 앞면 세로 그라데이션 (좌우 명암)
            for i in range(32):
                ratio = i / 32
                # 가운데가 밝고 양옆이 어두움
                brightness = 1.0 - 0.15 * abs(ratio - 0.5) * 2
                x_pos = cx - 16 + i
                pygame.draw.line(screen, (
                    int(240 * brightness),
                    int(195 * brightness),
                    int(60 * brightness), 50
                ), (x_pos, cy), (x_pos, cy + 10))

            # 오른쪽 면 (중간 밝기)
            right_face = [
                (cx + 16, cy - 2), (cx + 18, cy + 12),
                (cx + 22, cy + 8), (cx + 18, cy - 6)
            ]
            # 오른쪽 면 그라데이션
            for i in range(10):
                ratio = i / 10
                shade_r = int(220 - 30 * ratio)
                shade_g = int(175 - 25 * ratio)
                shade_b = int(50 - 15 * ratio)
                y_pos = cy - 2 + i
                x_left = cx + 16
                x_right = cx + 16 + int(4 * (1 - abs(i - 5) / 5))
                pygame.draw.line(screen, (shade_r, shade_g, shade_b),
                               (x_left, y_pos), (x_right + 2, y_pos))

            # === 윗면 (가장 밝은 면) ===
            top_face = [
                (cx - 12, cy - 10), (cx + 14, cy - 10),
                (cx + 16, cy - 2), (cx - 14, cy - 2)
            ]
            # 윗면 그라데이션 (뒤에서 앞으로)
            for i in range(8):
                ratio = i / 8
                shade_r = int(255 - 20 * ratio)
                shade_g = int(240 - 25 * ratio)
                shade_b = int(140 - 50 * ratio)
                y_pos = cy - 10 + i
                x_left = cx - 12 - int(2 * ratio)
                x_right = cx + 14 + int(2 * ratio)
                pygame.draw.line(screen, (shade_r, shade_g, shade_b),
                               (x_left, y_pos), (x_right, y_pos))

            # === 메탈릭 하이라이트 (빛 반사) ===
            # 윗면 메인 하이라이트 (강한 빛)
            highlight_intensity = int(220 + 35 * math.sin(t * 3))
            pygame.draw.line(screen, (255, 255, highlight_intensity),
                           (cx - 8, cy - 9), (cx + 10, cy - 9), 3)
            pygame.draw.line(screen, (255, 255, 255),
                           (cx - 6, cy - 8), (cx + 8, cy - 8), 2)

            # 윗면 보조 하이라이트
            pygame.draw.line(screen, (255, 250, 200),
                           (cx - 4, cy - 7), (cx + 6, cy - 7), 1)

            # 앞면 반사 하이라이트 (가운데 빛줄기)
            for i in range(3):
                alpha = 80 - i * 20
                pygame.draw.line(screen, (255, 240, 150, alpha),
                               (cx - 2 + i, cy), (cx + i, cy + 8), 2)

            # === 각인 (999.9 FINE GOLD) ===
            # 각인 홈 (어두운 부분)
            pygame.draw.rect(screen, (180, 140, 30), (cx - 10, cy + 1, 20, 8), border_radius=2)
            # 각인 면 (밝은 부분)
            pygame.draw.rect(screen, (255, 215, 70), (cx - 9, cy + 2, 18, 6), border_radius=1)
            # 각인 텍스트 효과 (작은 선들)
            pygame.draw.line(screen, (200, 160, 40), (cx - 7, cy + 4), (cx - 4, cy + 4), 1)
            pygame.draw.line(screen, (200, 160, 40), (cx - 2, cy + 4), (cx + 1, cy + 4), 1)
            pygame.draw.line(screen, (200, 160, 40), (cx + 3, cy + 4), (cx + 6, cy + 4), 1)
            pygame.draw.line(screen, (200, 160, 40), (cx - 6, cy + 6), (cx + 5, cy + 6), 1)

            # === 엣지 하이라이트 (금속 테두리) ===
            # 윗면 앞쪽 엣지 (가장 밝음)
            pygame.draw.line(screen, (255, 250, 180), (cx - 14, cy - 2), (cx + 16, cy - 2), 2)
            # 윗면 뒷쪽 엣지
            pygame.draw.line(screen, (255, 240, 160), (cx - 12, cy - 10), (cx + 14, cy - 10), 1)
            # 앞면 아래쪽 엣지
            pygame.draw.line(screen, (200, 160, 50), (cx - 18, cy + 12), (cx + 18, cy + 12), 1)

            # === 코너 베벨 효과 ===
            # 좌상단 코너
            pygame.draw.line(screen, (255, 245, 180), (cx - 12, cy - 10), (cx - 14, cy - 2), 1)
            # 우상단 코너
            pygame.draw.line(screen, (240, 200, 100), (cx + 14, cy - 10), (cx + 16, cy - 2), 1)

            # === 반짝이는 스파클 효과 ===
            sparkle_phase = t * 5
            # 메인 스파클 (상단)
            sparkle1 = int(255 * max(0, math.sin(sparkle_phase)))
            if sparkle1 > 100:
                pygame.draw.circle(screen, (255, 255, sparkle1), (cx - 5, cy - 8), 3)
                pygame.draw.circle(screen, (255, 255, 255), (cx - 5, cy - 8), 2)

            # 서브 스파클들 (여러 위치에서 반짝임)
            sparkle2 = int(255 * max(0, math.sin(sparkle_phase + 2)))
            if sparkle2 > 150:
                pygame.draw.circle(screen, (255, sparkle2, 200), (cx + 8, cy - 6), 2)

            sparkle3 = int(255 * max(0, math.sin(sparkle_phase + 4)))
            if sparkle3 > 180:
                pygame.draw.circle(screen, (255, 255, sparkle3), (cx + 12, cy + 3), 2)

            sparkle4 = int(255 * max(0, math.sin(sparkle_phase + 1.5)))
            if sparkle4 > 120:
                pygame.draw.circle(screen, (sparkle4, sparkle4, 200), (cx - 10, cy + 5), 1)

            # === 금속 광택 오버레이 ===
            # 미세한 광택 레이어 (전체적인 금속 느낌)
            gloss_surf = pygame.Surface((40, 20), pygame.SRCALPHA)
            for gy in range(20):
                gloss_alpha = int(30 * math.sin(gy / 20 * math.pi))
                pygame.draw.line(gloss_surf, (255, 255, 200, gloss_alpha),
                               (0, gy), (40, gy))
            screen.blit(gloss_surf, (cx - 18, cy - 2))

        elif symbol_name == "apple":
            # 사과 - 실사풍 광택
            # 그림자
            pygame.draw.ellipse(screen, (60, 20, 20), (cx - r - 2, cy + r - 5, r*2 + 4, 10))
            # 사과 본체
            pygame.draw.circle(screen, (200, 30, 30), (cx, cy + 2), r)
            # 그라데이션 (입체감)
            for i in range(r, 0, -1):
                ratio = i / r
                red = int(220 - 60 * (1 - ratio))
                pygame.draw.circle(screen, (red, 30 + int(20*ratio), 30 + int(20*ratio)),
                                 (cx - int(r*0.15), cy + 2 - int(r*0.1)), i)
            # 광택 하이라이트
            pygame.draw.ellipse(screen, (255, 150, 150), (cx - r//2 - 5, cy - r//2 - 2, r//2, r//3))
            pygame.draw.ellipse(screen, (255, 200, 200), (cx - r//2 - 2, cy - r//2, r//4, r//5))
            # 꼭지
            pygame.draw.polygon(screen, (90, 60, 30), [
                (cx - 2, cy - r + 2), (cx + 2, cy - r + 2),
                (cx + 1, cy - r - 10), (cx - 1, cy - r - 12)
            ])
            # 잎
            leaf_points = [(cx + 3, cy - r - 5), (cx + 15, cy - r - 12),
                          (cx + 18, cy - r - 8), (cx + 8, cy - r - 2)]
            pygame.draw.polygon(screen, (60, 160, 60), leaf_points)
            pygame.draw.polygon(screen, (80, 200, 80), leaf_points, 1)
            # 잎 줄기
            pygame.draw.line(screen, (40, 120, 40), (cx + 5, cy - r - 4), (cx + 14, cy - r - 9), 1)
            # 테두리
            pygame.draw.circle(screen, (150, 20, 20), (cx, cy + 2), r, 2)

        elif symbol_name == "key":
            # 황금 열쇠 - 메탈릭 광택
            # 그림자
            pygame.draw.ellipse(screen, (60, 50, 30), (cx - 12, cy + 12, 35, 8))
            # 손잡이 부분 (원형)
            pygame.draw.circle(screen, (200, 160, 60), (cx - 6, cy - 3), 12)
            pygame.draw.circle(screen, (255, 215, 80), (cx - 6, cy - 3), 10)
            pygame.draw.circle(screen, (180, 140, 50), (cx - 6, cy - 3), 6)
            # 손잡이 하이라이트
            pygame.draw.arc(screen, (255, 240, 150), (cx - 14, cy - 11, 16, 16), 0.5, 2.5, 2)
            # 몸통
            pygame.draw.rect(screen, (255, 200, 80), (cx, cy - 5, 22, 6), border_radius=2)
            # 몸통 그라데이션
            pygame.draw.rect(screen, (255, 220, 120), (cx, cy - 5, 22, 3), border_radius=2)
            pygame.draw.rect(screen, (200, 160, 60), (cx, cy - 2, 22, 3), border_radius=2)
            # 이빨
            pygame.draw.rect(screen, (255, 200, 80), (cx + 16, cy + 1, 4, 10))
            pygame.draw.rect(screen, (255, 200, 80), (cx + 10, cy + 1, 4, 7))
            # 이빨 하이라이트
            pygame.draw.rect(screen, (255, 230, 130), (cx + 16, cy + 1, 4, 3))
            pygame.draw.rect(screen, (255, 230, 130), (cx + 10, cy + 1, 4, 2))
            # 테두리
            pygame.draw.circle(screen, (150, 120, 40), (cx - 6, cy - 3), 12, 2)

        elif symbol_name == "diamond":
            # 다이아몬드 - 프리즘 빛 반사
            size = 20
            # 그림자
            shadow_points = [(cx, cy + size + 5), (cx + size - 5, cy + 8), (cx - size + 5, cy + 8)]
            pygame.draw.polygon(screen, (40, 60, 80), shadow_points)
            # 다이아몬드 상단 (크라운)
            top_points = [(cx, cy - size), (cx + size, cy - 2), (cx - size, cy - 2)]
            pygame.draw.polygon(screen, (180, 230, 255), top_points)
            # 다이아몬드 하단 (파빌리온)
            bottom_points = [(cx - size, cy - 2), (cx + size, cy - 2), (cx, cy + size)]
            pygame.draw.polygon(screen, (100, 180, 255), bottom_points)
            # 내부 빛 굴절
            pygame.draw.polygon(screen, (200, 240, 255), [
                (cx - size//2, cy - 2), (cx, cy - size + 5), (cx + size//2, cy - 2)
            ])
            pygame.draw.polygon(screen, (150, 210, 255), [
                (cx - size//2, cy - 2), (cx, cy + size - 5), (cx + size//2, cy - 2)
            ])
            # 프리즘 효과 (무지개빛)
            pygame.draw.line(screen, (255, 200, 200), (cx - 8, cy - 5), (cx - 3, cy + 5), 2)
            pygame.draw.line(screen, (200, 255, 200), (cx, cy - 8), (cx, cy + 3), 2)
            pygame.draw.line(screen, (200, 200, 255), (cx + 5, cy - 5), (cx + 8, cy + 5), 2)
            # 하이라이트
            pygame.draw.polygon(screen, (255, 255, 255), [
                (cx - 5, cy - size + 8), (cx, cy - size + 3), (cx + 5, cy - size + 8)
            ])
            # 테두리
            pygame.draw.polygon(screen, (150, 200, 255), top_points, 2)
            pygame.draw.polygon(screen, (80, 150, 220), bottom_points, 2)

        elif symbol_name == "pandora":
            # 판도라 상자 - 무지개빛 신비로운 보물상자
            t = self.animation_timer

            # 무지개 색상 배열 (빨주노초파남보)
            rainbow_colors = [
                (255, 50, 50),    # 빨강
                (255, 150, 50),   # 주황
                (255, 255, 50),   # 노랑
                (50, 255, 50),    # 초록
                (50, 150, 255),   # 파랑
                (100, 50, 255),   # 남색
                (200, 50, 255),   # 보라
            ]

            # 무지개 글로우 효과 (다층 회전)
            for layer in range(4):
                glow_surf = pygame.Surface((60, 60), pygame.SRCALPHA)
                # 각 레이어마다 다른 무지개 색상 사이클
                color_idx = int((t * 3 + layer * 1.5) % len(rainbow_colors))
                next_idx = (color_idx + 1) % len(rainbow_colors)
                blend = (t * 3 + layer * 1.5) % 1.0

                r = int(rainbow_colors[color_idx][0] * (1 - blend) + rainbow_colors[next_idx][0] * blend)
                g = int(rainbow_colors[color_idx][1] * (1 - blend) + rainbow_colors[next_idx][1] * blend)
                b = int(rainbow_colors[color_idx][2] * (1 - blend) + rainbow_colors[next_idx][2] * blend)

                glow_alpha = int(60 + 40 * math.sin(t * 4 + layer))
                pygame.draw.rect(glow_surf, (r, g, b, glow_alpha), (5 - layer*2, 5 - layer*2, 50 + layer*4, 50 + layer*4), border_radius=10)
                screen.blit(glow_surf, (cx - 30, cy - 25))

            # 그림자 (무지개빛 반사)
            shadow_color_idx = int(t * 2) % len(rainbow_colors)
            shadow_r = rainbow_colors[shadow_color_idx][0] // 4
            shadow_g = rainbow_colors[shadow_color_idx][1] // 4
            shadow_b = rainbow_colors[shadow_color_idx][2] // 4
            pygame.draw.ellipse(screen, (shadow_r, shadow_g, shadow_b), (cx - 18, cy + 12, 36, 8))

            # 상자 몸통 (무지개 그라데이션)
            pygame.draw.rect(screen, (80, 40, 100), (cx - 16, cy - 5, 32, 22), border_radius=4)
            for i in range(22):
                ratio = i / 22
                color_phase = (t * 2 + ratio * 2) % len(rainbow_colors)
                color_idx = int(color_phase)
                next_idx = (color_idx + 1) % len(rainbow_colors)
                blend = color_phase - color_idx

                base_r = int(rainbow_colors[color_idx][0] * (1 - blend) + rainbow_colors[next_idx][0] * blend)
                base_g = int(rainbow_colors[color_idx][1] * (1 - blend) + rainbow_colors[next_idx][1] * blend)
                base_b = int(rainbow_colors[color_idx][2] * (1 - blend) + rainbow_colors[next_idx][2] * blend)

                # 어둡게 조정
                shade = 0.4 + 0.3 * (1 - ratio)
                r = int(base_r * shade)
                g = int(base_g * shade)
                b = int(base_b * shade)
                pygame.draw.line(screen, (r, g, b), (cx - 15, cy - 4 + i), (cx + 15, cy - 4 + i))

            # 상자 뚜껑 (무지개빛 변화)
            lid_color_idx = int(t * 3) % len(rainbow_colors)
            lid_next = (lid_color_idx + 1) % len(rainbow_colors)
            lid_blend = (t * 3) % 1.0
            lid_r = int(rainbow_colors[lid_color_idx][0] * 0.6 * (1 - lid_blend) + rainbow_colors[lid_next][0] * 0.6 * lid_blend)
            lid_g = int(rainbow_colors[lid_color_idx][1] * 0.6 * (1 - lid_blend) + rainbow_colors[lid_next][1] * 0.6 * lid_blend)
            lid_b = int(rainbow_colors[lid_color_idx][2] * 0.6 * (1 - lid_blend) + rainbow_colors[lid_next][2] * 0.6 * lid_blend)
            pygame.draw.rect(screen, (lid_r, lid_g, lid_b), (cx - 18, cy - 12, 36, 12), border_radius=4)

            # 뚜껑 하이라이트 (빛나는 무지개)
            highlight_r = min(255, lid_r + 80)
            highlight_g = min(255, lid_g + 80)
            highlight_b = min(255, lid_b + 80)
            pygame.draw.rect(screen, (highlight_r, highlight_g, highlight_b), (cx - 16, cy - 11, 32, 4), border_radius=2)

            # 금속 테두리 (무지개 광택)
            border_phase = (t * 4) % len(rainbow_colors)
            border_idx = int(border_phase)
            border_next = (border_idx + 1) % len(rainbow_colors)
            border_blend = border_phase - border_idx
            border_r = int(rainbow_colors[border_idx][0] * (1 - border_blend) + rainbow_colors[border_next][0] * border_blend)
            border_g = int(rainbow_colors[border_idx][1] * (1 - border_blend) + rainbow_colors[border_next][1] * border_blend)
            border_b = int(rainbow_colors[border_idx][2] * (1 - border_blend) + rainbow_colors[border_next][2] * border_blend)
            pygame.draw.rect(screen, (border_r, border_g, border_b), (cx - 18, cy - 6, 36, 4))
            pygame.draw.rect(screen, (min(255, border_r + 50), min(255, border_g + 50), min(255, border_b + 50)), (cx - 18, cy - 6, 36, 2))

            # 자물쇠 (황금빛 유지 + 무지개 반사)
            lock_glow = int(200 + 55 * math.sin(t * 5))
            pygame.draw.circle(screen, (lock_glow, int(lock_glow * 0.8), 60), (cx, cy + 3), 7)
            pygame.draw.circle(screen, (180, 140, 50), (cx, cy + 3), 5)
            pygame.draw.rect(screen, (lock_glow, int(lock_glow * 0.8), 60), (cx - 3, cy - 4, 6, 8), border_radius=2)
            # 자물쇠 구멍
            pygame.draw.ellipse(screen, (40, 30, 20), (cx - 2, cy + 1, 4, 5))

            # 보석 장식 (무지개빛으로 변화)
            gem1_idx = int(t * 5) % len(rainbow_colors)
            gem2_idx = int(t * 5 + 3) % len(rainbow_colors)
            pygame.draw.circle(screen, rainbow_colors[gem1_idx], (cx - 10, cy + 5), 3)
            pygame.draw.circle(screen, rainbow_colors[gem2_idx], (cx + 10, cy + 5), 3)

            # 무지개 빛 파티클 (상자 주변에서 반짝임)
            for i in range(6):
                angle = t * 3 + i * (math.pi / 3)
                dist = 18 + 5 * math.sin(t * 4 + i)
                px = cx + int(math.cos(angle) * dist)
                py = cy - 3 + int(math.sin(angle) * dist * 0.6)
                spark_color = rainbow_colors[(int(t * 8) + i) % len(rainbow_colors)]
                spark_alpha = int(180 + 75 * math.sin(t * 6 + i * 2))
                spark_size = 2 + int(math.sin(t * 5 + i) > 0.5)
                pygame.draw.circle(screen, spark_color, (px, py), spark_size)

            # 상자 테두리 (무지개빛 외곽선)
            pygame.draw.rect(screen, (border_r, border_g, border_b), (cx - 16, cy - 5, 32, 22), 2, border_radius=4)
            pygame.draw.rect(screen, (lid_r, lid_g, lid_b), (cx - 18, cy - 12, 36, 12), 2, border_radius=4)

        elif symbol_name == "seven":
            # 럭키 7 - 화려한 네온 스타일
            # 배경 글로우 (다층)
            for g in range(3):
                glow = int((120 - g * 30) + (80 - g * 20) * math.sin(self.animation_timer * 6))
                glow_surf = pygame.Surface((w + g*10, h + g*10), pygame.SRCALPHA)
                pygame.draw.rect(glow_surf, (255, 215, 0, glow), (0, 0, w + g*10, h + g*10), border_radius=8)
                screen.blit(glow_surf, (x - g*5, y - g*5))
            # 7 배경
            pygame.draw.rect(screen, (80, 20, 20), (cx - 18, cy - 22, 36, 44), border_radius=5)
            # 7 본체 (3D 효과)
            # 그림자
            pygame.draw.rect(screen, (150, 30, 30), (cx - 14, cy - 18, 30, 10), border_radius=3)
            pygame.draw.polygon(screen, (150, 30, 30), [
                (cx + 12, cy - 8), (cx + 18, cy - 8),
                (cx - 2, cy + 20), (cx - 8, cy + 20)
            ])
            # 메인 7
            pygame.draw.rect(screen, (255, 50, 50), (cx - 15, cy - 19, 30, 10), border_radius=3)
            pygame.draw.polygon(screen, (255, 50, 50), [
                (cx + 11, cy - 9), (cx + 17, cy - 9),
                (cx - 3, cy + 19), (cx - 9, cy + 19)
            ])
            # 하이라이트
            pygame.draw.rect(screen, (255, 150, 150), (cx - 14, cy - 18, 28, 4), border_radius=2)
            pygame.draw.line(screen, (255, 180, 180), (cx + 13, cy - 7), (cx - 5, cy + 15), 3)
            # 골드 테두리
            pygame.draw.rect(screen, (255, 215, 0), (cx - 15, cy - 19, 30, 10), 2, border_radius=3)
            pygame.draw.polygon(screen, (255, 215, 0), [
                (cx + 11, cy - 9), (cx + 17, cy - 9),
                (cx - 3, cy + 19), (cx - 9, cy + 19)
            ], 2)
            # 반짝임 효과
            sparkle = int(255 * abs(math.sin(self.animation_timer * 10)))
            pygame.draw.circle(screen, (255, 255, sparkle), (cx - 10, cy - 15), 3)
            pygame.draw.circle(screen, (255, sparkle, 255), (cx + 10, cy - 15), 2)
            pygame.draw.circle(screen, (sparkle, 255, 255), (cx + 5, cy + 10), 2)

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
