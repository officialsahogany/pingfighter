# -*- coding: utf-8 -*-
"""
보스 선출 화면
행성 도착 후 보스 3명 중 랜덤 1명을 룰렛 연출로 선출.
"""

import pygame
import math
import random
import sys

try:
    from pixel_font_manager import get_font, FontStyle
except ImportError:
    get_font = lambda s, **kw: pygame.font.Font(None, s)

try:
    from config.planet_configs import PLANET_CONFIGS, select_random_boss
except ImportError:
    PLANET_CONFIGS = {}
    select_random_boss = None


class BossSelectScreen:
    """보스 선출 룰렛 화면"""

    def __init__(self, screen, width, height):
        self.screen = screen
        self.width = width
        self.height = height
        self.clock = pygame.time.Clock()
        self.time = 0.0

        try:
            self.font_title = get_font(28, style="bold")
            self.font_boss = get_font(22, style="bold")
            self.font_sub = get_font(16, style="regular")
            self.font_result = get_font(36, style="bold")
        except Exception:
            self.font_title = pygame.font.Font(None, 36)
            self.font_boss = pygame.font.Font(None, 28)
            self.font_sub = pygame.font.Font(None, 20)
            self.font_result = pygame.font.Font(None, 48)

    def show_selection(self, planet_num):
        """
        보스 선출 애니메이션을 보여주고, 선출된 보스 이름을 반환한다.
        현재 구현된 보스가 1명뿐이면 항상 그 보스가 선출되지만,
        3명 중 고르는 연출은 동일하게 수행.
        """
        config = PLANET_CONFIGS.get(planet_num, {})
        boss_roster = config.get("boss_roster", [
            {"name": "???", "implemented": False},
            {"name": "???", "implemented": False},
            {"name": "???", "implemented": False},
        ])
        planet_name = config.get("name", f"행성 {planet_num}")
        theme_color = config.get("theme_color", (100, 100, 100))
        glow_color = config.get("glow_color", (150, 150, 150))

        # 3명 미만이면 ??? 로 채움
        while len(boss_roster) < 3:
            boss_roster.append({"name": "???", "implemented": False})

        # 선출할 보스 결정 (구현된 보스 중 랜덤)
        available = [b for b in boss_roster if b["implemented"]]
        if available:
            selected_boss = random.choice(available)
        else:
            selected_boss = boss_roster[0]  # 폴백

        selected_index = boss_roster.index(selected_boss)

        # 카드 크기/위치
        card_w, card_h = 160, 200
        card_gap = 25
        total_w = card_w * 3 + card_gap * 2
        start_x = (self.width - total_w) // 2
        card_y = (self.height - card_h) // 2

        # 룰렛 애니메이션 변수
        # 하이라이트가 빠르게 돌다가 선택된 인덱스에서 멈춤
        roulette_cycles = random.randint(8, 12)  # 총 몇 바퀴 돌지
        total_stops = roulette_cycles * 3 + selected_index  # 총 멈춤 횟수
        roulette_speed = 3.0  # 초기 속도 (프레임당 진행)
        roulette_pos = 0.0  # 현재 위치 (실수)
        roulette_done = False

        # 페이즈
        phase = "intro"  # intro → roulette → reveal → done
        phase_timer = 0
        intro_duration = 40
        reveal_duration = 90

        running = True
        while running:
            dt = self.clock.tick(60) / 1000.0
            self.time += dt
            phase_timer += 1

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE or event.key == pygame.K_SPACE:
                        running = False

            # 배경
            self.screen.fill((8, 8, 20))
            # 배경 파티클
            for _ in range(3):
                px = random.randint(0, self.width)
                py = random.randint(0, self.height)
                pa = random.randint(20, 60)
                pygame.draw.circle(self.screen, (pa, pa, int(pa * 1.5)), (px, py), 1)

            # 타이틀
            title_text = f"{planet_name} - 보스 선출"
            title_surf = self.font_title.render(title_text, True, glow_color)
            title_rect = title_surf.get_rect(center=(self.width // 2, card_y - 60))
            self.screen.blit(title_surf, title_rect)

            # 현재 하이라이트 인덱스
            if phase == "intro":
                highlight_idx = -1  # 없음
                if phase_timer >= intro_duration:
                    phase = "roulette"
                    phase_timer = 0

            elif phase == "roulette":
                # 감속하면서 진행
                progress = roulette_pos / total_stops
                # 후반부로 갈수록 느려짐 (이징)
                current_speed = roulette_speed * max(0.08, 1.0 - progress * 0.92)
                roulette_pos += current_speed * dt * 60

                if roulette_pos >= total_stops:
                    roulette_pos = float(total_stops)
                    roulette_done = True
                    phase = "reveal"
                    phase_timer = 0

                highlight_idx = int(roulette_pos) % 3

            elif phase == "reveal":
                highlight_idx = selected_index
                if phase_timer >= reveal_duration:
                    running = False

            else:
                highlight_idx = selected_index

            # 카드 3장 그리기
            for i, boss in enumerate(boss_roster):
                cx = start_x + i * (card_w + card_gap)
                cy = card_y
                is_highlighted = (i == highlight_idx)
                is_selected_final = (phase == "reveal" and i == selected_index)
                is_implemented = boss.get("implemented", False)

                # 카드 배경
                if is_selected_final:
                    # 선출된 보스: 밝은 테두리 + 확대 효과
                    scale_bonus = int(4 * math.sin(self.time * 4))
                    card_rect = pygame.Rect(cx - 4 - scale_bonus, cy - 4 - scale_bonus,
                                            card_w + 8 + scale_bonus * 2, card_h + 8 + scale_bonus * 2)
                    pygame.draw.rect(self.screen, glow_color, card_rect, border_radius=12)
                    inner_rect = pygame.Rect(cx - 2, cy - 2, card_w + 4, card_h + 4)
                    pygame.draw.rect(self.screen, (20, 20, 40), inner_rect, border_radius=10)
                elif is_highlighted and phase == "roulette":
                    # 룰렛 하이라이트
                    card_rect = pygame.Rect(cx - 3, cy - 3, card_w + 6, card_h + 6)
                    pygame.draw.rect(self.screen, (255, 255, 100), card_rect, border_radius=12)
                    inner_rect = pygame.Rect(cx, cy, card_w, card_h)
                    pygame.draw.rect(self.screen, (25, 25, 50), inner_rect, border_radius=10)
                else:
                    card_rect = pygame.Rect(cx, cy, card_w, card_h)
                    pygame.draw.rect(self.screen, (20, 20, 40), card_rect, border_radius=10)
                    pygame.draw.rect(self.screen, (50, 55, 80), card_rect, 2, border_radius=10)

                # 카드 내용
                inner_cx = cx + card_w // 2
                inner_cy = cy + card_h // 2

                if is_implemented:
                    # 보스 아이콘 (색상 원)
                    icon_color = theme_color
                    icon_y = cy + 60
                    pygame.draw.circle(self.screen, icon_color, (inner_cx, icon_y), 30)
                    pygame.draw.circle(self.screen, glow_color, (inner_cx, icon_y), 30, 2)
                    # 눈 (간단한 이모지)
                    pygame.draw.circle(self.screen, (255, 255, 255), (inner_cx - 8, icon_y - 5), 5)
                    pygame.draw.circle(self.screen, (255, 255, 255), (inner_cx + 8, icon_y - 5), 5)
                    pygame.draw.circle(self.screen, (0, 0, 0), (inner_cx - 8, icon_y - 5), 3)
                    pygame.draw.circle(self.screen, (0, 0, 0), (inner_cx + 8, icon_y - 5), 3)

                    # 보스 이름
                    name_surf = self.font_boss.render(boss["name"], True, (255, 255, 255))
                    name_rect = name_surf.get_rect(center=(inner_cx, cy + card_h - 50))
                    self.screen.blit(name_surf, name_rect)
                else:
                    # 미구현 보스: 잠금 표시
                    lock_color = (60, 60, 80)
                    pygame.draw.circle(self.screen, lock_color, (inner_cx, cy + 60), 30)
                    # 자물쇠 아이콘
                    pygame.draw.rect(self.screen, (80, 80, 100),
                                     (inner_cx - 12, cy + 55, 24, 20), border_radius=3)
                    pygame.draw.arc(self.screen, (80, 80, 100),
                                    (inner_cx - 10, cy + 40, 20, 20), 0, math.pi, 3)

                    name_surf = self.font_boss.render("???", True, (80, 80, 100))
                    name_rect = name_surf.get_rect(center=(inner_cx, cy + card_h - 50))
                    self.screen.blit(name_surf, name_rect)

                # 준비 중 텍스트 (미구현)
                if not is_implemented:
                    sub_surf = self.font_sub.render("준비 중", True, (60, 60, 80))
                    sub_rect = sub_surf.get_rect(center=(inner_cx, cy + card_h - 25))
                    self.screen.blit(sub_surf, sub_rect)

            # 선출 결과 표시
            if phase == "reveal":
                result_alpha = min(255, phase_timer * 6)
                result_text = f">> {selected_boss['name']} <<"
                result_surf = self.font_result.render(result_text, True, glow_color)
                result_surf.set_alpha(result_alpha)
                result_rect = result_surf.get_rect(center=(self.width // 2, card_y + card_h + 60))
                self.screen.blit(result_surf, result_rect)

                # "도전!" 텍스트
                if phase_timer > 30:
                    challenge_alpha = min(255, (phase_timer - 30) * 8)
                    ch_surf = self.font_sub.render("도전 시작!", True, (255, 220, 150))
                    ch_surf.set_alpha(challenge_alpha)
                    ch_rect = ch_surf.get_rect(center=(self.width // 2, card_y + card_h + 100))
                    self.screen.blit(ch_surf, ch_rect)

            # 하단 안내
            hint_surf = self.font_sub.render("SPACE / ESC: 건너뛰기", True, (80, 90, 110))
            hint_rect = hint_surf.get_rect(center=(self.width // 2, self.height - 30))
            self.screen.blit(hint_surf, hint_rect)

            pygame.display.flip()

        pygame.event.clear()
        return selected_boss["name"]
