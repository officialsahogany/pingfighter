# downtown/action_points.py
# 행동 포인트(AP) 시스템

import pygame
import math
from .constants import (
    BASE_ACTION_POINTS, MAX_ACTION_POINTS, AP_PER_STAGE_CLEAR,
    Colors
)

class ActionPointSystem:
    """
    행동 포인트 시스템
    - 번화가에서의 활동 제한
    - 각 이벤트 방문 시 AP 소모
    - AP가 0이 되면 다음 스테이지로 강제 진입
    """

    def __init__(self):
        self.current_ap = BASE_ACTION_POINTS
        self.max_ap = MAX_ACTION_POINTS
        self.base_ap = BASE_ACTION_POINTS

        # 애니메이션
        self.display_ap = float(self.current_ap)
        self.ap_change_animation = 0
        self.last_change_amount = 0

        # 보너스 AP 추적
        self.bonus_ap_sources = {}

    def reset(self, stage_number=1):
        """새 스테이지에서 AP 리셋"""
        # 스테이지에 따른 기본 AP 계산
        bonus = min(stage_number // 3, 3)  # 3스테이지마다 +1, 최대 +3
        self.current_ap = self.base_ap + bonus
        self.max_ap = min(self.current_ap + 3, MAX_ACTION_POINTS)
        self.display_ap = float(self.current_ap)
        self.bonus_ap_sources.clear()

    def add_ap(self, amount, source="unknown"):
        """AP 추가"""
        old_ap = self.current_ap
        self.current_ap = min(self.current_ap + amount, self.max_ap)
        actual_gain = self.current_ap - old_ap

        if actual_gain > 0:
            self.last_change_amount = actual_gain
            self.ap_change_animation = 1.0
            if source not in self.bonus_ap_sources:
                self.bonus_ap_sources[source] = 0
            self.bonus_ap_sources[source] += actual_gain

        return actual_gain

    def use_ap(self, amount):
        """AP 사용 (성공 시 True 반환)"""
        if self.current_ap >= amount:
            self.current_ap -= amount
            self.last_change_amount = -amount
            self.ap_change_animation = 1.0
            return True
        return False

    def can_use(self, amount):
        """AP 사용 가능 여부"""
        return self.current_ap >= amount

    def is_exhausted(self):
        """AP가 모두 소진되었는지"""
        return self.current_ap <= 0

    def update(self, dt):
        """애니메이션 업데이트"""
        # 표시 AP 부드럽게 변경
        if abs(self.display_ap - self.current_ap) > 0.01:
            self.display_ap += (self.current_ap - self.display_ap) * dt * 8

        # 변경 애니메이션
        if self.ap_change_animation > 0:
            self.ap_change_animation -= dt * 2
            if self.ap_change_animation < 0:
                self.ap_change_animation = 0

    def draw(self, screen, x, y, font=None):
        """AP UI 그리기"""
        # 배경 패널
        panel_width = 200
        panel_height = 60
        panel_rect = pygame.Rect(x, y, panel_width, panel_height)

        # 배경
        pygame.draw.rect(screen, (20, 20, 40), panel_rect, border_radius=10)
        pygame.draw.rect(screen, Colors.NEON_CYAN, panel_rect, 2, border_radius=10)

        # AP 아이콘들 (별 모양)
        icon_start_x = x + 15
        icon_y = y + 20
        icon_size = 20
        icon_spacing = 22

        for i in range(self.max_ap):
            icon_x = icon_start_x + i * icon_spacing

            if i < int(self.display_ap):
                # 활성화된 AP
                color = Colors.NEON_CYAN
                self._draw_star(screen, icon_x, icon_y, icon_size // 2, color, filled=True)
            elif i < self.display_ap:
                # 부분적으로 활성화 (애니메이션)
                color = Colors.NEON_CYAN
                alpha = (self.display_ap - int(self.display_ap))
                self._draw_star(screen, icon_x, icon_y, icon_size // 2, color, filled=True, alpha=alpha)
            else:
                # 비활성화된 AP
                color = (60, 60, 80)
                self._draw_star(screen, icon_x, icon_y, icon_size // 2, color, filled=False)

        # AP 텍스트
        if font:
            ap_text = f"AP: {self.current_ap}/{self.max_ap}"
            text_surface = font.render(ap_text, True, Colors.TEXT_WHITE)
            screen.blit(text_surface, (x + 15, y + 40))

        # 변경 애니메이션 (+ 또는 - 표시)
        if self.ap_change_animation > 0:
            alpha = int(255 * self.ap_change_animation)
            offset_y = int((1 - self.ap_change_animation) * 20)

            if self.last_change_amount > 0:
                change_text = f"+{self.last_change_amount}"
                change_color = Colors.NEON_GREEN
            else:
                change_text = str(self.last_change_amount)
                change_color = Colors.UI_DANGER

            if font:
                change_surface = font.render(change_text, True, change_color)
                change_surface.set_alpha(alpha)
                screen.blit(change_surface, (x + panel_width - 50, y + 10 - offset_y))

    def _draw_star(self, screen, x, y, radius, color, filled=True, alpha=1.0):
        """별 모양 그리기"""
        points = []
        for i in range(10):
            angle = math.pi / 2 + i * math.pi / 5
            r = radius if i % 2 == 0 else radius * 0.5
            px = x + r * math.cos(angle)
            py = y - r * math.sin(angle)
            points.append((px, py))

        if filled:
            # 반투명 처리
            if alpha < 1.0:
                temp_surface = pygame.Surface((radius * 2 + 4, radius * 2 + 4), pygame.SRCALPHA)
                offset_points = [(p[0] - x + radius + 2, p[1] - y + radius + 2) for p in points]
                pygame.draw.polygon(temp_surface, (*color, int(255 * alpha)), offset_points)
                screen.blit(temp_surface, (x - radius - 2, y - radius - 2))
            else:
                pygame.draw.polygon(screen, color, points)
        else:
            pygame.draw.polygon(screen, color, points, 2)

    def draw_minimal(self, screen, x, y):
        """최소화된 AP 표시 (게임 HUD용)"""
        # 작은 AP 표시
        for i in range(self.current_ap):
            star_x = x + i * 15
            color = Colors.NEON_CYAN
            self._draw_star(screen, star_x, y, 6, color, filled=True)


class ActionPointEvent:
    """AP 관련 이벤트"""

    @staticmethod
    def on_stage_clear(ap_system, stage_number):
        """스테이지 클리어 시"""
        bonus = AP_PER_STAGE_CLEAR
        # 특정 스테이지에서 추가 보너스
        if stage_number % 5 == 0:  # 5의 배수 스테이지
            bonus += 1
        ap_system.add_ap(bonus, f"stage_{stage_number}_clear")

    @staticmethod
    def on_perfect_clear(ap_system):
        """퍼펙트 클리어 시 추가 AP"""
        ap_system.add_ap(1, "perfect_clear")

    @staticmethod
    def on_item_effect(ap_system, amount, item_name):
        """아이템 효과로 AP 획득"""
        ap_system.add_ap(amount, f"item_{item_name}")
