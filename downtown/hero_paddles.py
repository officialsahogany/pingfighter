# -*- coding: utf-8 -*-
"""
콜로세움 영웅 패들 렌더러
8명의 영웅 각각 고유한 패들 이미지 + 이동 애니메이션
"""

import pygame
import math
from typing import Dict, Tuple, Optional


class HeroPaddleRenderer:
    """영웅 패들 렌더링 클래스"""

    def __init__(self):
        self.animation_time = 0.0
        # 각 영웅별 애니메이션 상태
        self.hero_states: Dict[str, Dict] = {}

    def update(self, dt: float):
        """애니메이션 업데이트"""
        self.animation_time += dt

    def get_hero_state(self, hero_id: str) -> Dict:
        """영웅 상태 가져오기/생성"""
        if hero_id not in self.hero_states:
            self.hero_states[hero_id] = {
                'move_direction': 0,  # -1: 왼쪽, 0: 정지, 1: 오른쪽
                'move_timer': 0.0,
                'prev_x': 0,
            }
        return self.hero_states[hero_id]

    def update_movement(self, hero_id: str, current_x: float, dt: float):
        """이동 상태 업데이트"""
        state = self.get_hero_state(hero_id)

        # 이동 방향 감지
        dx = current_x - state['prev_x']
        if abs(dx) > 0.5:
            state['move_direction'] = 1 if dx > 0 else -1
            state['move_timer'] = 0.15  # 이동 애니메이션 지속 시간

        # 타이머 감소
        if state['move_timer'] > 0:
            state['move_timer'] -= dt
        else:
            state['move_direction'] = 0

        state['prev_x'] = current_x

    def draw_hero_paddle(self, screen: pygame.Surface, hero_id: str,
                         x: float, y: float, width: int, height: int,
                         facing: str = "down", color: Tuple[int, int, int] = (200, 200, 200)):
        """영웅 패들 그리기

        Args:
            screen: 화면
            hero_id: 영웅 ID
            x, y: 패들 중심 좌표
            width, height: 패들 크기
            facing: "down" (상단 영웅) 또는 "up" (하단 영웅)
            color: 영웅 기본 색상
        """
        state = self.get_hero_state(hero_id)
        move_dir = state['move_direction']

        # 이동 시 기울기
        tilt = move_dir * 8 if state['move_timer'] > 0 else 0

        # 영웅별 그리기
        if hero_id == "gallita":
            self._draw_gallita(screen, x, y, width, height, facing, tilt, color)
        elif hero_id == "archines":
            self._draw_archines(screen, x, y, width, height, facing, tilt, color)
        elif hero_id == "chungkia":  # 토키아 (id는 chungkia로 유지)
            self._draw_tokia(screen, x, y, width, height, facing, tilt, color)
        elif hero_id == "poineth":
            self._draw_poineth(screen, x, y, width, height, facing, tilt, color)
        elif hero_id == "gestand":
            self._draw_gestand(screen, x, y, width, height, facing, tilt, color)
        elif hero_id == "bukandai":
            self._draw_bukandai(screen, x, y, width, height, facing, tilt, color)
        elif hero_id == "pinjo":
            self._draw_pinjo(screen, x, y, width, height, facing, tilt, color)
        elif hero_id == "alexa":
            self._draw_alexa(screen, x, y, width, height, facing, tilt, color)
        else:
            # 기본 패들
            self._draw_default(screen, x, y, width, height, facing, tilt, color)

    # ========================================================================
    # 상단 영웅들 (아래를 바라봄)
    # ========================================================================

    def _draw_gallita(self, screen, x, y, width, height, facing, tilt, color):
        """갤리타 - 폭풍의 여전사 (번개 테마)"""
        # 기본 색상
        main_color = (60, 200, 120)
        dark_color = (40, 150, 90)
        light_color = (100, 230, 150)
        lightning_color = (255, 255, 150)

        cx, cy = int(x), int(y)
        hw, hh = width // 2, height // 2

        # 그림자
        shadow_offset = 3
        pygame.draw.ellipse(screen, (30, 30, 30),
                           (cx - hw - 2, cy + shadow_offset, width + 4, height + 4))

        # 몸통 (날렵한 형태)
        body_points = [
            (cx - hw + tilt, cy - hh),
            (cx + hw + tilt, cy - hh),
            (cx + hw - 5, cy + hh),
            (cx - hw + 5, cy + hh),
        ]
        pygame.draw.polygon(screen, main_color, body_points)
        pygame.draw.polygon(screen, dark_color, body_points, 2)

        # 머리
        head_y = cy - hh - 12 if facing == "down" else cy + hh + 12
        head_radius = 10
        pygame.draw.circle(screen, main_color, (cx + tilt, head_y), head_radius)
        pygame.draw.circle(screen, dark_color, (cx + tilt, head_y), head_radius, 2)

        # 눈 (아래/위를 바라봄)
        eye_offset_y = 3 if facing == "down" else -3
        pygame.draw.circle(screen, (255, 255, 255), (cx - 3 + tilt, head_y + eye_offset_y), 3)
        pygame.draw.circle(screen, (255, 255, 255), (cx + 3 + tilt, head_y + eye_offset_y), 3)
        pygame.draw.circle(screen, (0, 0, 0), (cx - 3 + tilt, head_y + eye_offset_y + 1), 2)
        pygame.draw.circle(screen, (0, 0, 0), (cx + 3 + tilt, head_y + eye_offset_y + 1), 2)

        # 번개 모양 머리카락
        hair_y = head_y - 8 if facing == "down" else head_y + 8
        lightning_points = [
            (cx - 8 + tilt, hair_y),
            (cx - 3 + tilt, hair_y - 6),
            (cx + tilt, hair_y - 2),
            (cx + 3 + tilt, hair_y - 8),
            (cx + 8 + tilt, hair_y - 3),
        ]
        if facing == "up":
            lightning_points = [(p[0], head_y + (head_y - p[1])) for p in lightning_points]
        pygame.draw.lines(screen, lightning_color, False, lightning_points, 3)

        # 번개 이펙트 (이동 시)
        if tilt != 0:
            bolt_x = cx + (15 if tilt > 0 else -15)
            bolt_y = cy
            self._draw_lightning_bolt(screen, bolt_x, bolt_y, facing)

    def _draw_archines(self, screen, x, y, width, height, facing, tilt, color):
        """아르키네스 - 철벽의 수호자 (방패 테마)"""
        main_color = (60, 120, 220)
        dark_color = (40, 90, 180)
        light_color = (100, 160, 255)
        shield_color = (180, 180, 200)

        cx, cy = int(x), int(y)
        hw, hh = width // 2, height // 2

        # 그림자
        pygame.draw.ellipse(screen, (30, 30, 30),
                           (cx - hw - 2, cy + 3, width + 4, height + 4))

        # 넓은 몸통 (방패같은 형태)
        body_rect = pygame.Rect(cx - hw + tilt//2, cy - hh, width, height + 5)
        pygame.draw.rect(screen, main_color, body_rect, border_radius=5)
        pygame.draw.rect(screen, dark_color, body_rect, 3, border_radius=5)

        # 방패 무늬
        shield_rect = pygame.Rect(cx - 12 + tilt//2, cy - 3, 24, 10)
        pygame.draw.rect(screen, shield_color, shield_rect, border_radius=2)
        pygame.draw.rect(screen, dark_color, shield_rect, 1, border_radius=2)

        # 머리 (헬멧)
        head_y = cy - hh - 10 if facing == "down" else cy + hh + 10
        # 헬멧 본체
        pygame.draw.circle(screen, shield_color, (cx + tilt//2, head_y), 11)
        pygame.draw.circle(screen, (100, 100, 120), (cx + tilt//2, head_y), 11, 2)

        # 헬멧 장식
        crest_y = head_y - 8 if facing == "down" else head_y + 8
        pygame.draw.rect(screen, main_color, (cx - 2 + tilt//2, crest_y - 5, 4, 10))

        # 눈 (헬멧 슬릿)
        eye_y = head_y + 2 if facing == "down" else head_y - 2
        pygame.draw.rect(screen, (20, 20, 40), (cx - 8 + tilt//2, eye_y, 16, 3))
        # 눈빛
        pygame.draw.rect(screen, (200, 220, 255), (cx - 5 + tilt//2, eye_y, 4, 2))
        pygame.draw.rect(screen, (200, 220, 255), (cx + 2 + tilt//2, eye_y, 4, 2))

    def _draw_tokia(self, screen, x, y, width, height, facing, tilt, color):
        """토키아 - 바위의 거인 (거대하고 둔중한 느낌)"""
        main_color = (200, 140, 60)
        dark_color = (150, 100, 40)
        light_color = (230, 180, 100)
        rock_color = (140, 130, 110)

        cx, cy = int(x), int(y)
        hw, hh = width // 2, height // 2

        # 큰 그림자
        pygame.draw.ellipse(screen, (30, 30, 30),
                           (cx - hw - 5, cy + 4, width + 10, height + 6))

        # 넓고 두꺼운 몸통
        body_points = [
            (cx - hw - 5 + tilt//3, cy - hh),
            (cx + hw + 5 + tilt//3, cy - hh),
            (cx + hw + 8, cy + hh + 3),
            (cx - hw - 8, cy + hh + 3),
        ]
        pygame.draw.polygon(screen, main_color, body_points)
        pygame.draw.polygon(screen, dark_color, body_points, 3)

        # 바위 질감
        for i in range(3):
            rx = cx - 15 + i * 15 + tilt//3
            ry = cy - 2 + (i % 2) * 4
            pygame.draw.circle(screen, rock_color, (rx, ry), 4)
            pygame.draw.circle(screen, dark_color, (rx, ry), 4, 1)

        # 큰 머리
        head_y = cy - hh - 14 if facing == "down" else cy + hh + 14
        head_radius = 14
        pygame.draw.circle(screen, main_color, (cx + tilt//3, head_y), head_radius)
        pygame.draw.circle(screen, dark_color, (cx + tilt//3, head_y), head_radius, 3)

        # 작은 눈 (둔해 보이게)
        eye_offset_y = 4 if facing == "down" else -4
        pygame.draw.circle(screen, (255, 255, 255), (cx - 5 + tilt//3, head_y + eye_offset_y), 3)
        pygame.draw.circle(screen, (255, 255, 255), (cx + 5 + tilt//3, head_y + eye_offset_y), 3)
        pygame.draw.circle(screen, (60, 40, 20), (cx - 5 + tilt//3, head_y + eye_offset_y), 2)
        pygame.draw.circle(screen, (60, 40, 20), (cx + 5 + tilt//3, head_y + eye_offset_y), 2)

        # 두꺼운 눈썹
        brow_y = head_y + eye_offset_y - 4
        pygame.draw.line(screen, dark_color,
                        (cx - 8 + tilt//3, brow_y), (cx - 2 + tilt//3, brow_y - 1), 3)
        pygame.draw.line(screen, dark_color,
                        (cx + 2 + tilt//3, brow_y - 1), (cx + 8 + tilt//3, brow_y), 3)

    def _draw_poineth(self, screen, x, y, width, height, facing, tilt, color):
        """포이네스 - 그림자 암살자 (날렵하고 신비로운)"""
        main_color = (160, 60, 200)
        dark_color = (100, 40, 140)
        light_color = (200, 120, 255)
        shadow_color = (60, 30, 80)

        cx, cy = int(x), int(y)
        hw, hh = width // 2, height // 2

        # 흐릿한 그림자 (여러 개로 잔상 효과)
        for i in range(3):
            offset = (i - 1) * 4
            alpha_surf = pygame.Surface((width + 10, height + 10), pygame.SRCALPHA)
            pygame.draw.ellipse(alpha_surf, (30, 20, 40, 80 - i * 20),
                               (0, 3, width + 10, height + 4))
            screen.blit(alpha_surf, (cx - hw - 5 + offset, cy - 2))

        # 날렵한 몸통
        body_points = [
            (cx - hw + 8 + tilt, cy - hh),
            (cx + hw - 8 + tilt, cy - hh),
            (cx + hw - 3, cy + hh),
            (cx - hw + 3, cy + hh),
        ]
        pygame.draw.polygon(screen, main_color, body_points)
        pygame.draw.polygon(screen, light_color, body_points, 1)

        # 후드 머리
        head_y = cy - hh - 10 if facing == "down" else cy + hh + 10

        # 후드
        hood_points = [
            (cx - 12 + tilt, head_y + (5 if facing == "down" else -5)),
            (cx + tilt, head_y - (10 if facing == "down" else -10)),
            (cx + 12 + tilt, head_y + (5 if facing == "down" else -5)),
        ]
        pygame.draw.polygon(screen, shadow_color, hood_points)

        # 얼굴 (어둡게)
        pygame.draw.circle(screen, (40, 20, 50), (cx + tilt, head_y), 7)

        # 빛나는 눈
        eye_offset_y = 2 if facing == "down" else -2
        glow_time = math.sin(self.animation_time * 5) * 0.3 + 0.7
        eye_color = (int(200 * glow_time), int(100 * glow_time), int(255 * glow_time))
        pygame.draw.circle(screen, eye_color, (cx - 3 + tilt, head_y + eye_offset_y), 2)
        pygame.draw.circle(screen, eye_color, (cx + 3 + tilt, head_y + eye_offset_y), 2)

        # 이동 시 잔상
        if tilt != 0:
            trail_offset = -tilt * 2
            trail_surf = pygame.Surface((width, height + 20), pygame.SRCALPHA)
            trail_points = [(p[0] - cx + hw + trail_offset, p[1] - cy + hh + 10) for p in body_points]
            pygame.draw.polygon(trail_surf, (160, 60, 200, 60), trail_points)
            screen.blit(trail_surf, (cx - hw, cy - hh - 10))

    # ========================================================================
    # 하단 영웅들 (위를 바라봄)
    # ========================================================================

    def _draw_gestand(self, screen, x, y, width, height, facing, tilt, color):
        """게스탄드 - 현명한 전술가 (책/두루마리 테마)"""
        main_color = (100, 160, 220)
        dark_color = (60, 120, 180)
        light_color = (140, 200, 255)
        scroll_color = (240, 230, 200)

        cx, cy = int(x), int(y)
        hw, hh = width // 2, height // 2

        # 그림자
        pygame.draw.ellipse(screen, (30, 30, 30),
                           (cx - hw - 2, cy + 3, width + 4, height + 4))

        # 로브 형태 몸통
        robe_points = [
            (cx - hw + 3 + tilt, cy - hh - 3),
            (cx + hw - 3 + tilt, cy - hh - 3),
            (cx + hw + 5, cy + hh),
            (cx - hw - 5, cy + hh),
        ]
        pygame.draw.polygon(screen, main_color, robe_points)
        pygame.draw.polygon(screen, dark_color, robe_points, 2)

        # 로브 주름
        pygame.draw.line(screen, dark_color, (cx - 10 + tilt, cy - hh), (cx - 15, cy + hh), 1)
        pygame.draw.line(screen, dark_color, (cx + 10 + tilt, cy - hh), (cx + 15, cy + hh), 1)

        # 두루마리 장식
        scroll_y = cy + 2
        pygame.draw.rect(screen, scroll_color, (cx - 8 + tilt//2, scroll_y - 3, 16, 6), border_radius=2)
        pygame.draw.rect(screen, dark_color, (cx - 8 + tilt//2, scroll_y - 3, 16, 6), 1, border_radius=2)

        # 머리 (수염 있는 현자)
        head_y = cy + hh + 12 if facing == "up" else cy - hh - 12
        pygame.draw.circle(screen, (220, 190, 160), (cx + tilt//2, head_y), 10)
        pygame.draw.circle(screen, dark_color, (cx + tilt//2, head_y), 10, 2)

        # 눈 (위를 바라봄)
        eye_offset_y = -3 if facing == "up" else 3
        pygame.draw.circle(screen, (255, 255, 255), (cx - 3 + tilt//2, head_y + eye_offset_y), 3)
        pygame.draw.circle(screen, (255, 255, 255), (cx + 3 + tilt//2, head_y + eye_offset_y), 3)
        pygame.draw.circle(screen, (40, 80, 120), (cx - 3 + tilt//2, head_y + eye_offset_y - 1), 2)
        pygame.draw.circle(screen, (40, 80, 120), (cx + 3 + tilt//2, head_y + eye_offset_y - 1), 2)

        # 수염
        beard_y = head_y + 6 if facing == "up" else head_y - 6
        beard_points = [
            (cx - 5 + tilt//2, head_y + (4 if facing == "up" else -4)),
            (cx + tilt//2, beard_y + 5),
            (cx + 5 + tilt//2, head_y + (4 if facing == "up" else -4)),
        ]
        if facing == "down":
            beard_points = [(p[0], head_y - (p[1] - head_y)) for p in beard_points]
        pygame.draw.polygon(screen, (200, 200, 210), beard_points)

    def _draw_bukandai(self, screen, x, y, width, height, facing, tilt, color):
        """부칸다이 - 광기의 광대 (어릿광대 테마)"""
        main_color = (220, 80, 180)
        dark_color = (180, 40, 140)
        light_color = (255, 140, 220)
        alt_color = (80, 200, 220)  # 대비색

        cx, cy = int(x), int(y)
        hw, hh = width // 2, height // 2

        # 그림자
        pygame.draw.ellipse(screen, (30, 30, 30),
                           (cx - hw - 2, cy + 3, width + 4, height + 4))

        # 광대 복장 (지그재그)
        body_rect = pygame.Rect(cx - hw + tilt, cy - hh, width, height + 3)
        pygame.draw.rect(screen, main_color, body_rect, border_radius=3)

        # 다이아몬드 패턴
        for i in range(3):
            dx = cx - 15 + i * 15 + tilt
            pygame.draw.polygon(screen, alt_color, [
                (dx, cy - 5), (dx + 5, cy), (dx, cy + 5), (dx - 5, cy)
            ])

        pygame.draw.rect(screen, dark_color, body_rect, 2, border_radius=3)

        # 머리 (광대 모자)
        head_y = cy + hh + 12 if facing == "up" else cy - hh - 12
        pygame.draw.circle(screen, (255, 230, 200), (cx + tilt, head_y), 10)

        # 광대 모자 (삼각형 2개)
        hat_y = head_y - 8 if facing == "up" else head_y + 8
        if facing == "up":
            # 왼쪽 모자
            pygame.draw.polygon(screen, main_color, [
                (cx - 10 + tilt, head_y - 5),
                (cx - 5 + tilt, head_y - 15),
                (cx + tilt, head_y - 5),
            ])
            # 오른쪽 모자
            pygame.draw.polygon(screen, alt_color, [
                (cx + tilt, head_y - 5),
                (cx + 5 + tilt, head_y - 15),
                (cx + 10 + tilt, head_y - 5),
            ])
            # 방울
            pygame.draw.circle(screen, (255, 255, 0), (cx - 5 + tilt, head_y - 16), 3)
            pygame.draw.circle(screen, (255, 255, 0), (cx + 5 + tilt, head_y - 16), 3)
        else:
            pygame.draw.polygon(screen, main_color, [
                (cx - 10 + tilt, head_y + 5),
                (cx - 5 + tilt, head_y + 15),
                (cx + tilt, head_y + 5),
            ])
            pygame.draw.polygon(screen, alt_color, [
                (cx + tilt, head_y + 5),
                (cx + 5 + tilt, head_y + 15),
                (cx + 10 + tilt, head_y + 5),
            ])
            pygame.draw.circle(screen, (255, 255, 0), (cx - 5 + tilt, head_y + 16), 3)
            pygame.draw.circle(screen, (255, 255, 0), (cx + 5 + tilt, head_y + 16), 3)

        # 미친 눈 (크기가 다름)
        eye_offset_y = -2 if facing == "up" else 2
        pygame.draw.circle(screen, (255, 255, 255), (cx - 4 + tilt, head_y + eye_offset_y), 4)
        pygame.draw.circle(screen, (255, 255, 255), (cx + 4 + tilt, head_y + eye_offset_y), 3)
        # 다른 색 눈동자
        pygame.draw.circle(screen, main_color, (cx - 4 + tilt, head_y + eye_offset_y), 2)
        pygame.draw.circle(screen, alt_color, (cx + 4 + tilt, head_y + eye_offset_y), 2)

        # 미소
        smile_y = head_y + (5 if facing == "up" else -5)
        pygame.draw.arc(screen, (200, 50, 50),
                       (cx - 6 + tilt, smile_y - 3, 12, 8),
                       0 if facing == "up" else math.pi,
                       math.pi if facing == "up" else 0, 2)

    def _draw_pinjo(self, screen, x, y, width, height, facing, tilt, color):
        """핀조 - 불굴의 검투사 (전투적인 검투사)"""
        main_color = (220, 60, 60)
        dark_color = (160, 40, 40)
        light_color = (255, 100, 100)
        armor_color = (180, 150, 100)

        cx, cy = int(x), int(y)
        hw, hh = width // 2, height // 2

        # 그림자
        pygame.draw.ellipse(screen, (30, 30, 30),
                           (cx - hw - 2, cy + 3, width + 4, height + 4))

        # 근육질 몸통
        body_points = [
            (cx - hw + tilt, cy - hh),
            (cx + hw + tilt, cy - hh),
            (cx + hw + 3, cy + hh + 2),
            (cx - hw - 3, cy + hh + 2),
        ]
        pygame.draw.polygon(screen, main_color, body_points)

        # 어깨 보호대
        pygame.draw.ellipse(screen, armor_color, (cx - hw - 8 + tilt, cy - hh - 2, 15, 10))
        pygame.draw.ellipse(screen, armor_color, (cx + hw - 7 + tilt, cy - hh - 2, 15, 10))
        pygame.draw.ellipse(screen, dark_color, (cx - hw - 8 + tilt, cy - hh - 2, 15, 10), 2)
        pygame.draw.ellipse(screen, dark_color, (cx + hw - 7 + tilt, cy - hh - 2, 15, 10), 2)

        pygame.draw.polygon(screen, dark_color, body_points, 2)

        # 벨트
        belt_y = cy + 2
        pygame.draw.rect(screen, armor_color, (cx - hw + 5, belt_y - 2, width - 10, 5))
        pygame.draw.rect(screen, (200, 180, 80), (cx - 5, belt_y - 3, 10, 6))  # 버클

        # 머리 (투구)
        head_y = cy + hh + 12 if facing == "up" else cy - hh - 12
        pygame.draw.circle(screen, armor_color, (cx + tilt, head_y), 11)
        pygame.draw.circle(screen, dark_color, (cx + tilt, head_y), 11, 2)

        # 투구 깃털
        feather_y = head_y - 8 if facing == "up" else head_y + 8
        feather_points = [
            (cx + tilt, head_y - (8 if facing == "up" else -8)),
            (cx - 4 + tilt, feather_y - (10 if facing == "up" else -10)),
            (cx + tilt, feather_y - (8 if facing == "up" else -8)),
            (cx + 4 + tilt, feather_y - (12 if facing == "up" else -12)),
        ]
        pygame.draw.polygon(screen, main_color, feather_points)

        # 얼굴 (투구 아래)
        face_y = head_y + (3 if facing == "up" else -3)
        pygame.draw.rect(screen, (200, 160, 140), (cx - 6 + tilt, face_y - 4, 12, 8))

        # 눈 (전투적인)
        eye_offset_y = -1 if facing == "up" else 1
        pygame.draw.line(screen, (80, 40, 40),
                        (cx - 6 + tilt, face_y + eye_offset_y - 2),
                        (cx - 2 + tilt, face_y + eye_offset_y), 2)
        pygame.draw.line(screen, (80, 40, 40),
                        (cx + 2 + tilt, face_y + eye_offset_y),
                        (cx + 6 + tilt, face_y + eye_offset_y - 2), 2)
        pygame.draw.circle(screen, (255, 200, 100), (cx - 4 + tilt, face_y + eye_offset_y), 2)
        pygame.draw.circle(screen, (255, 200, 100), (cx + 4 + tilt, face_y + eye_offset_y), 2)

    def _draw_alexa(self, screen, x, y, width, height, facing, tilt, color):
        """알렉사 - 황금의 창 (황금빛 전사)"""
        main_color = (220, 180, 60)
        dark_color = (180, 140, 40)
        light_color = (255, 220, 100)
        gold_color = (255, 215, 0)

        cx, cy = int(x), int(y)
        hw, hh = width // 2, height // 2

        # 황금빛 그림자
        pygame.draw.ellipse(screen, (60, 50, 20),
                           (cx - hw - 2, cy + 3, width + 4, height + 4))

        # 우아한 몸통
        body_points = [
            (cx - hw + 5 + tilt, cy - hh),
            (cx + hw - 5 + tilt, cy - hh),
            (cx + hw, cy + hh),
            (cx - hw, cy + hh),
        ]
        pygame.draw.polygon(screen, main_color, body_points)
        pygame.draw.polygon(screen, gold_color, body_points, 2)

        # 황금 장식
        pygame.draw.circle(screen, gold_color, (cx + tilt, cy), 5)
        pygame.draw.circle(screen, dark_color, (cx + tilt, cy), 5, 1)

        # 어깨 장식
        pygame.draw.circle(screen, gold_color, (cx - hw + 3 + tilt, cy - hh + 3), 4)
        pygame.draw.circle(screen, gold_color, (cx + hw - 3 + tilt, cy - hh + 3), 4)

        # 머리 (왕관)
        head_y = cy + hh + 11 if facing == "up" else cy - hh - 11
        pygame.draw.circle(screen, (240, 210, 180), (cx + tilt, head_y), 10)
        pygame.draw.circle(screen, dark_color, (cx + tilt, head_y), 10, 2)

        # 왕관
        crown_y = head_y - 10 if facing == "up" else head_y + 10
        if facing == "up":
            crown_points = [
                (cx - 10 + tilt, head_y - 5),
                (cx - 6 + tilt, head_y - 12),
                (cx - 2 + tilt, head_y - 8),
                (cx + tilt, head_y - 14),
                (cx + 2 + tilt, head_y - 8),
                (cx + 6 + tilt, head_y - 12),
                (cx + 10 + tilt, head_y - 5),
            ]
        else:
            crown_points = [
                (cx - 10 + tilt, head_y + 5),
                (cx - 6 + tilt, head_y + 12),
                (cx - 2 + tilt, head_y + 8),
                (cx + tilt, head_y + 14),
                (cx + 2 + tilt, head_y + 8),
                (cx + 6 + tilt, head_y + 12),
                (cx + 10 + tilt, head_y + 5),
            ]
        pygame.draw.polygon(screen, gold_color, crown_points)
        pygame.draw.polygon(screen, dark_color, crown_points, 1)

        # 왕관 보석
        gem_y = head_y - 11 if facing == "up" else head_y + 11
        pygame.draw.circle(screen, (255, 50, 50), (cx + tilt, gem_y), 3)

        # 눈 (우아한)
        eye_offset_y = -2 if facing == "up" else 2
        pygame.draw.ellipse(screen, (255, 255, 255),
                           (cx - 6 + tilt, head_y + eye_offset_y - 2, 5, 4))
        pygame.draw.ellipse(screen, (255, 255, 255),
                           (cx + 1 + tilt, head_y + eye_offset_y - 2, 5, 4))
        pygame.draw.circle(screen, (100, 80, 60), (cx - 4 + tilt, head_y + eye_offset_y), 2)
        pygame.draw.circle(screen, (100, 80, 60), (cx + 4 + tilt, head_y + eye_offset_y), 2)

        # 미소
        smile_y = head_y + (4 if facing == "up" else -4)
        pygame.draw.arc(screen, (200, 100, 100),
                       (cx - 4 + tilt, smile_y - 2, 8, 4),
                       0 if facing == "up" else math.pi,
                       math.pi if facing == "up" else 0, 1)

    # ========================================================================
    # 유틸리티
    # ========================================================================

    def _draw_default(self, screen, x, y, width, height, facing, tilt, color):
        """기본 패들"""
        cx, cy = int(x), int(y)
        hw, hh = width // 2, height // 2

        # 그림자
        pygame.draw.ellipse(screen, (30, 30, 30),
                           (cx - hw - 2, cy + 3, width + 4, height + 4))

        # 패들
        rect = pygame.Rect(cx - hw + tilt, cy - hh, width, height)
        pygame.draw.rect(screen, color, rect, border_radius=4)
        pygame.draw.rect(screen, (50, 50, 50), rect, 2, border_radius=4)

        # 얼굴
        head_y = cy + hh + 10 if facing == "up" else cy - hh - 10
        pygame.draw.circle(screen, (200, 180, 160), (cx + tilt, head_y), 8)

        # 눈
        eye_offset_y = -2 if facing == "up" else 2
        pygame.draw.circle(screen, (0, 0, 0), (cx - 2 + tilt, head_y + eye_offset_y), 2)
        pygame.draw.circle(screen, (0, 0, 0), (cx + 2 + tilt, head_y + eye_offset_y), 2)

    def _draw_lightning_bolt(self, screen, x, y, facing):
        """번개 이펙트"""
        bolt_color = (255, 255, 150)
        points = [
            (x, y - 15),
            (x + 5, y - 5),
            (x, y),
            (x + 8, y + 15),
        ]
        if facing == "up":
            points = [(p[0], y - (p[1] - y)) for p in points]
        pygame.draw.lines(screen, bolt_color, False, points, 2)


# 싱글톤 인스턴스
_hero_paddle_renderer: Optional[HeroPaddleRenderer] = None

def get_hero_paddle_renderer() -> HeroPaddleRenderer:
    """영웅 패들 렌더러 싱글톤 가져오기"""
    global _hero_paddle_renderer
    if _hero_paddle_renderer is None:
        _hero_paddle_renderer = HeroPaddleRenderer()
    return _hero_paddle_renderer
