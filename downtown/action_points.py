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
        """AP UI 그리기 - 열쇠만 표시 (배경/텍스트 없음)"""
        # 현재 열쇠 개수 (최대 5개로 제한)
        display_count = min(int(self.display_ap), 5)

        # AP 아이콘들 (현재 보유한 열쇠만 표시, 최대 5개)
        icon_size = 16   # 20에서 20% 감소
        icon_spacing = 22

        for i in range(display_count):
            icon_x = x + i * icon_spacing
            self._draw_antique_key(screen, icon_x, y, icon_size, active=True)

    def _draw_antique_key(self, screen, x, y, size, active=True, alpha=1.0):
        """클래식 앤틱 열쇠 - 8자형 고리 + 긴 막대 + F자 이빨"""
        # 열쇠 서피스 생성 (세로로 긴 클래식 비율)
        key_w = int(size * 1.0)
        key_h = int(size * 2.2)  # 세로로 긴 비율
        key_surf = pygame.Surface((key_w, key_h), pygame.SRCALPHA)

        # 색상 설정
        if active:
            # 활성화 - 앤틱 브론즈/골드
            bronze_main = (175, 140, 85)       # 메인 앤틱 골드
            bronze_dark = (110, 85, 45)        # 어두운 부분
            bronze_light = (210, 180, 120)     # 하이라이트
            bronze_edge = (90, 65, 30)         # 외곽선
        else:
            # 비활성화 - 어두운 앤틱
            bronze_main = (85, 80, 70)
            bronze_dark = (55, 50, 40)
            bronze_light = (105, 100, 90)
            bronze_edge = (45, 40, 30)

        cx = key_w // 2

        # === 상단 8자형 고리 (두 개의 원형 루프) ===
        loop_r = int(key_w * 0.32)  # 고리 반지름
        loop_thickness = max(2, int(size * 0.12))  # 고리 두께
        loop_y = loop_r + 2  # 고리 중심 Y

        # 왼쪽 고리 (원형)
        left_loop_x = cx - int(loop_r * 0.55)
        # 외곽선
        pygame.draw.circle(key_surf, bronze_edge, (left_loop_x, loop_y), loop_r + 1, loop_thickness + 2)
        # 메인 고리
        pygame.draw.circle(key_surf, bronze_main, (left_loop_x, loop_y), loop_r, loop_thickness)
        # 내부 하이라이트
        pygame.draw.arc(key_surf, bronze_light,
                       (left_loop_x - loop_r + 2, loop_y - loop_r + 2, (loop_r - 2) * 2, (loop_r - 2) * 2),
                       math.pi * 0.8, math.pi * 1.5, max(1, loop_thickness // 2))

        # 오른쪽 고리 (원형)
        right_loop_x = cx + int(loop_r * 0.55)
        # 외곽선
        pygame.draw.circle(key_surf, bronze_edge, (right_loop_x, loop_y), loop_r + 1, loop_thickness + 2)
        # 메인 고리
        pygame.draw.circle(key_surf, bronze_main, (right_loop_x, loop_y), loop_r, loop_thickness)
        # 내부 하이라이트
        pygame.draw.arc(key_surf, bronze_light,
                       (right_loop_x - loop_r + 2, loop_y - loop_r + 2, (loop_r - 2) * 2, (loop_r - 2) * 2),
                       math.pi * 0.8, math.pi * 1.5, max(1, loop_thickness // 2))

        # === 고리 연결부 (중앙 상단) ===
        connect_y = loop_y + loop_r - 2
        connect_w = int(key_w * 0.25)
        connect_h = int(key_h * 0.08)

        # 연결부 외곽
        pygame.draw.ellipse(key_surf, bronze_edge,
                           (cx - connect_w // 2 - 1, connect_y - 1, connect_w + 2, connect_h + 2))
        # 연결부 메인
        pygame.draw.ellipse(key_surf, bronze_main,
                           (cx - connect_w // 2, connect_y, connect_w, connect_h))
        # 하이라이트
        pygame.draw.ellipse(key_surf, bronze_light,
                           (cx - connect_w // 4, connect_y + 1, connect_w // 2, connect_h // 2))

        # === 상단 장식 (고리 위 작은 돌출) ===
        top_dec_y = 1
        top_dec_w = int(key_w * 0.18)
        top_dec_h = int(key_h * 0.04)
        pygame.draw.ellipse(key_surf, bronze_dark,
                           (cx - top_dec_w // 2, top_dec_y, top_dec_w, top_dec_h))
        pygame.draw.ellipse(key_surf, bronze_main,
                           (cx - top_dec_w // 2 + 1, top_dec_y, top_dec_w - 2, top_dec_h - 1))

        # === 열쇠 몸통 (세로 막대) ===
        shaft_w = int(key_w * 0.22)
        shaft_top = connect_y + connect_h - 2
        shaft_bottom = int(key_h * 0.78)
        shaft_x = cx - shaft_w // 2

        # 몸통 외곽선
        pygame.draw.rect(key_surf, bronze_edge,
                        (shaft_x - 1, shaft_top, shaft_w + 2, shaft_bottom - shaft_top + 2))
        # 몸통 메인
        pygame.draw.rect(key_surf, bronze_main,
                        (shaft_x, shaft_top, shaft_w, shaft_bottom - shaft_top))

        # 몸통 하이라이트 (왼쪽 면)
        pygame.draw.line(key_surf, bronze_light,
                        (shaft_x + 1, shaft_top + 2),
                        (shaft_x + 1, shaft_bottom - 2), 1)

        # 몸통 그림자 (오른쪽 면)
        pygame.draw.line(key_surf, bronze_dark,
                        (shaft_x + shaft_w - 1, shaft_top + 2),
                        (shaft_x + shaft_w - 1, shaft_bottom - 2), 1)

        # === 몸통 마디 장식 ===
        shaft_length = shaft_bottom - shaft_top
        # 상단 마디
        node_y1 = shaft_top + int(shaft_length * 0.15)
        pygame.draw.rect(key_surf, bronze_light, (shaft_x - 2, node_y1, shaft_w + 4, 3))
        pygame.draw.rect(key_surf, bronze_edge, (shaft_x - 2, node_y1, shaft_w + 4, 3), 1)

        # 중간 마디
        node_y2 = shaft_top + int(shaft_length * 0.5)
        pygame.draw.rect(key_surf, bronze_light, (shaft_x - 1, node_y2, shaft_w + 2, 2))
        pygame.draw.rect(key_surf, bronze_edge, (shaft_x - 1, node_y2, shaft_w + 2, 2), 1)

        # === 열쇠 이빨 (F자 모양) ===
        teeth_y = shaft_bottom
        teeth_w = int(key_w * 0.38)
        teeth_h = int(key_h * 0.20)

        # 막대 연장 (이빨까지)
        pygame.draw.rect(key_surf, bronze_edge,
                        (shaft_x - 1, teeth_y, shaft_w + 2, teeth_h + 2))
        pygame.draw.rect(key_surf, bronze_main,
                        (shaft_x, teeth_y, shaft_w, teeth_h))

        # 상단 이빨 (긴 이빨)
        tooth1_y = teeth_y + int(teeth_h * 0.15)
        tooth1_h = int(teeth_h * 0.25)
        pygame.draw.rect(key_surf, bronze_edge,
                        (shaft_x + shaft_w - 1, tooth1_y, teeth_w + 2, tooth1_h + 1))
        pygame.draw.rect(key_surf, bronze_main,
                        (shaft_x + shaft_w, tooth1_y, teeth_w, tooth1_h))
        # 이빨 하이라이트
        pygame.draw.line(key_surf, bronze_light,
                        (shaft_x + shaft_w + 1, tooth1_y + 1),
                        (shaft_x + shaft_w + teeth_w - 2, tooth1_y + 1), 1)

        # 하단 이빨 (더 긴 이빨)
        tooth2_y = teeth_y + int(teeth_h * 0.60)
        tooth2_h = int(teeth_h * 0.35)
        tooth2_w = int(teeth_w * 1.1)  # 약간 더 길게
        pygame.draw.rect(key_surf, bronze_edge,
                        (shaft_x + shaft_w - 1, tooth2_y, tooth2_w + 2, tooth2_h + 1))
        pygame.draw.rect(key_surf, bronze_main,
                        (shaft_x + shaft_w, tooth2_y, tooth2_w, tooth2_h))
        # 이빨 하이라이트
        pygame.draw.line(key_surf, bronze_light,
                        (shaft_x + shaft_w + 1, tooth2_y + 1),
                        (shaft_x + shaft_w + tooth2_w - 2, tooth2_y + 1), 1)

        # 막대 끝 하이라이트
        pygame.draw.line(key_surf, bronze_light,
                        (shaft_x + 1, teeth_y + 1),
                        (shaft_x + 1, teeth_y + teeth_h - 1), 1)

        # 반투명 처리
        if alpha < 1.0:
            key_surf.set_alpha(int(255 * alpha))

        # 화면에 그리기 (세로 중심 맞춤)
        screen.blit(key_surf, (x - key_w // 2, y - key_h // 2))

    def _draw_star(self, screen, x, y, radius, color, filled=True, alpha=1.0):
        """별 모양 그리기 (하위 호환성)"""
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
        """최소화된 AP 표시 (게임 HUD용) - 작은 열쇠"""
        # 작은 AP 표시
        for i in range(self.current_ap):
            key_x = x + i * 18
            self._draw_antique_key(screen, key_x, y, 16, active=True)


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
