# -*- coding: utf-8 -*-
"""
콜로세움 영웅 패들 렌더러
8명의 영웅 - 사람 형태의 캐릭터 (스매셔/발토르 스타일)
상단: 정면 (아래를 바라봄)
하단: 뒷모습 (위를 바라봄, 뒷통수가 보임)
"""

import pygame
import math
from typing import Dict, Tuple, Optional


class HeroPaddleRenderer:
    """영웅 패들 렌더링 클래스 - 사람 형태"""

    def __init__(self):
        self.animation_time = 0.0
        self.hero_states: Dict[str, Dict] = {}

    def update(self, dt: float):
        """애니메이션 업데이트"""
        self.animation_time += dt

    def get_hero_state(self, hero_id: str) -> Dict:
        """영웅 상태 가져오기/생성"""
        if hero_id not in self.hero_states:
            self.hero_states[hero_id] = {
                'move_direction': 0,
                'move_timer': 0.0,
                'prev_x': 0,
            }
        return self.hero_states[hero_id]

    def update_movement(self, hero_id: str, current_x: float, dt: float):
        """이동 상태 업데이트"""
        state = self.get_hero_state(hero_id)
        dx = current_x - state['prev_x']
        if abs(dx) > 0.5:
            state['move_direction'] = 1 if dx > 0 else -1
            state['move_timer'] = 0.2
        if state['move_timer'] > 0:
            state['move_timer'] -= dt
        else:
            state['move_direction'] = 0
        state['prev_x'] = current_x

    def draw_hero_paddle(self, screen: pygame.Surface, hero_id: str,
                         x: float, y: float, width: int, height: int,
                         facing: str = "down", color: Tuple[int, int, int] = (200, 200, 200)):
        """영웅 패들 그리기 (사람 형태)
        facing="down": 정면 (아래를 바라봄, 얼굴이 보임)
        facing="up": 뒷모습 (위를 바라봄, 뒷통수가 보임)
        """
        state = self.get_hero_state(hero_id)
        move_dir = state['move_direction']
        lean = move_dir * 3 if state['move_timer'] > 0 else 0

        # 기본 단위 (스케일)
        b = max(4, width // 16)

        # facing에 따라 정면/뒷면 결정
        show_back = (facing == "up")

        if hero_id == "gallita":
            self._draw_gallita(screen, x, y, b, show_back, lean, color)
        elif hero_id == "archines":
            self._draw_archines(screen, x, y, b, show_back, lean, color)
        elif hero_id == "chungkia":
            self._draw_tokia(screen, x, y, b, show_back, lean, color)
        elif hero_id == "poineth":
            self._draw_poineth(screen, x, y, b, show_back, lean, color)
        elif hero_id == "gestand":
            self._draw_gestand(screen, x, y, b, show_back, lean, color)
        elif hero_id == "bukandai":
            self._draw_bukandai(screen, x, y, b, show_back, lean, color)
        elif hero_id == "pinjo":
            self._draw_pinjo(screen, x, y, b, show_back, lean, color)
        elif hero_id == "alexa":
            self._draw_alexa(screen, x, y, b, show_back, lean, color)
        else:
            self._draw_default(screen, x, y, b, show_back, lean, color)

    # ========================================================================
    # 갤리타 - 폭풍의 여전사 (번개/스피드 테마)
    # ========================================================================
    def _draw_gallita(self, screen, cx, cy, b, show_back, lean, color):
        """갤리타 - 민첩한 여전사, 번개 창"""
        cx = int(cx) + lean
        cy = int(cy)

        # 색상 팔레트
        main = (60, 200, 120)
        dark = (40, 150, 90)
        light = (100, 230, 160)
        skin = (255, 220, 190)
        hair = (255, 230, 100)  # 금발
        lightning = (255, 255, 150)

        torso_y = cy - int(1.5 * b)

        # === 머리 ===
        head_y = torso_y - int(3 * b)
        head_r = int(1.8 * b)

        if show_back:
            # 뒷모습 - 뒷통수
            pygame.draw.circle(screen, hair, (cx, head_y), head_r)
            # 뒷머리 디테일
            pygame.draw.arc(screen, dark, (cx - head_r, head_y - head_r, head_r * 2, head_r * 2),
                           0, math.pi, 2)
            # 뾰족한 뒷머리
            for i in range(5):
                hx = cx - int(1.2 * b) + i * int(0.6 * b)
                hy = head_y - int(1 * b) - (i % 2) * int(0.5 * b)
                pygame.draw.polygon(screen, hair, [
                    (hx, head_y - int(0.5 * b)),
                    (hx - int(0.2 * b), hy - int(0.8 * b)),
                    (hx + int(0.2 * b), hy - int(0.8 * b)),
                ])
        else:
            # 정면 - 얼굴
            pygame.draw.circle(screen, skin, (cx, head_y), head_r)
            # 머리카락 (번개 모양 뾰족한 스타일)
            hair_points = [
                (cx - int(1.5 * b), head_y - int(0.5 * b)),
                (cx - int(0.8 * b), head_y - int(2 * b)),
                (cx - int(0.3 * b), head_y - int(0.8 * b)),
                (cx + int(0.3 * b), head_y - int(2.5 * b)),
                (cx + int(0.8 * b), head_y - int(0.6 * b)),
                (cx + int(1.5 * b), head_y - int(1.8 * b)),
            ]
            pygame.draw.polygon(screen, hair, hair_points)
            # 눈
            eye_y = head_y + int(0.3 * b)
            pygame.draw.circle(screen, (255, 255, 255), (cx - int(0.5 * b), eye_y), int(0.4 * b))
            pygame.draw.circle(screen, (255, 255, 255), (cx + int(0.5 * b), eye_y), int(0.4 * b))
            pygame.draw.circle(screen, (30, 100, 60), (cx - int(0.5 * b), eye_y + int(0.1 * b)), int(0.25 * b))
            pygame.draw.circle(screen, (30, 100, 60), (cx + int(0.5 * b), eye_y + int(0.1 * b)), int(0.25 * b))

        # === 몸통 (갑옷) ===
        torso_w = int(3 * b)
        torso_h = int(2.5 * b)
        torso_rect = pygame.Rect(cx - torso_w // 2, torso_y - int(0.5 * b), torso_w, torso_h)
        pygame.draw.rect(screen, main, torso_rect, border_radius=int(0.5 * b))
        pygame.draw.rect(screen, dark, torso_rect, 2, border_radius=int(0.5 * b))

        if not show_back:
            # 정면 가슴 장식 (번개 문양)
            chest_cx = cx
            chest_cy = torso_rect.centery
            pygame.draw.polygon(screen, lightning, [
                (chest_cx, chest_cy - int(0.8 * b)),
                (chest_cx + int(0.3 * b), chest_cy),
                (chest_cx, chest_cy + int(0.2 * b)),
                (chest_cx - int(0.3 * b), chest_cy),
            ])
        else:
            # 뒷면 - 망토/등 디테일
            pygame.draw.line(screen, dark, (cx, torso_rect.top + int(0.3 * b)),
                           (cx, torso_rect.bottom - int(0.3 * b)), 2)

        # === 어깨 보호대 ===
        shoulder_y = torso_y - int(0.3 * b)
        pygame.draw.ellipse(screen, light, (cx - int(2.2 * b), shoulder_y - int(0.6 * b), int(1.2 * b), int(1.2 * b)))
        pygame.draw.ellipse(screen, dark, (cx - int(2.2 * b), shoulder_y - int(0.6 * b), int(1.2 * b), int(1.2 * b)), 2)
        pygame.draw.ellipse(screen, light, (cx + int(1 * b), shoulder_y - int(0.6 * b), int(1.2 * b), int(1.2 * b)))
        pygame.draw.ellipse(screen, dark, (cx + int(1 * b), shoulder_y - int(0.6 * b), int(1.2 * b), int(1.2 * b)), 2)

        # === 팔 ===
        arm_y = shoulder_y + int(0.3 * b)
        pygame.draw.line(screen, skin, (cx - int(1.8 * b), arm_y), (cx - int(2.5 * b), arm_y + int(1.5 * b)), int(0.6 * b))
        pygame.draw.line(screen, skin, (cx + int(1.8 * b), arm_y), (cx + int(2.5 * b), arm_y + int(1 * b)), int(0.6 * b))

        # === 번개 창 ===
        spear_x = cx + int(3 * b)
        spear_top = arm_y - int(3 * b)
        spear_bottom = arm_y + int(2 * b)
        pygame.draw.line(screen, (180, 150, 100), (spear_x, spear_top), (spear_x, spear_bottom), int(0.3 * b))
        # 창날
        tip_y = spear_top - int(1.5 * b)
        pygame.draw.polygon(screen, lightning, [
            (spear_x, tip_y),
            (spear_x - int(0.6 * b), spear_top),
            (spear_x + int(0.6 * b), spear_top),
        ])

    # ========================================================================
    # 아르키네스 - 철벽의 수호자 (방패/수비 테마)
    # ========================================================================
    def _draw_archines(self, screen, cx, cy, b, show_back, lean, color):
        """아르키네스 - 중갑 전사, 큰 방패"""
        cx = int(cx) + lean
        cy = int(cy)

        main = (60, 120, 220)
        dark = (40, 80, 180)
        light = (100, 160, 255)
        metal = (180, 190, 200)

        torso_y = cy - int(1.5 * b)

        # === 헬멧 ===
        head_y = torso_y - int(3 * b)
        helmet_rect = pygame.Rect(cx - int(1.8 * b), head_y - int(1.5 * b), int(3.6 * b), int(3 * b))
        pygame.draw.ellipse(screen, metal, helmet_rect)
        pygame.draw.ellipse(screen, dark, helmet_rect, 2)

        # 헬멧 장식 (크레스트) - 정면/뒷면 모두 보임
        crest_top = head_y - int(2.5 * b)
        pygame.draw.rect(screen, main, (cx - int(0.3 * b), crest_top - int(1 * b), int(0.6 * b), int(1.5 * b)), border_radius=2)

        if show_back:
            # 뒷모습 - 헬멧 뒷면
            pygame.draw.arc(screen, dark, helmet_rect, 0, math.pi, 3)
        else:
            # 정면 - 바이저 (T자 슬릿)
            visor_y = head_y + int(0.3 * b)
            pygame.draw.rect(screen, (30, 30, 40), (cx - int(1.2 * b), visor_y - int(0.15 * b), int(2.4 * b), int(0.3 * b)))
            pygame.draw.rect(screen, (30, 30, 40), (cx - int(0.15 * b), visor_y - int(0.15 * b), int(0.3 * b), int(0.8 * b)))
            # 눈빛
            pygame.draw.rect(screen, (150, 200, 255), (cx - int(0.8 * b), visor_y - int(0.1 * b), int(0.4 * b), int(0.2 * b)))
            pygame.draw.rect(screen, (150, 200, 255), (cx + int(0.4 * b), visor_y - int(0.1 * b), int(0.4 * b), int(0.2 * b)))

        # === 몸통 (중갑) ===
        torso_w = int(4 * b)
        torso_h = int(3 * b)
        torso_rect = pygame.Rect(cx - torso_w // 2, torso_y - int(0.5 * b), torso_w, torso_h)
        pygame.draw.rect(screen, main, torso_rect, border_radius=int(0.4 * b))
        pygame.draw.rect(screen, dark, torso_rect, 2, border_radius=int(0.4 * b))

        if not show_back:
            # 정면 갑옷 패턴
            inner_rect = torso_rect.inflate(-int(0.8 * b), -int(0.6 * b))
            pygame.draw.rect(screen, light, inner_rect, 2, border_radius=int(0.3 * b))

        # === 어깨 (큰 견갑) ===
        shoulder_y = torso_y - int(0.5 * b)
        left_pauldron = [
            (cx - int(2.2 * b), shoulder_y - int(0.8 * b)),
            (cx - int(1.2 * b), shoulder_y - int(1 * b)),
            (cx - int(0.8 * b), shoulder_y + int(0.8 * b)),
            (cx - int(2.5 * b), shoulder_y + int(1 * b)),
        ]
        pygame.draw.polygon(screen, metal, left_pauldron)
        pygame.draw.polygon(screen, dark, left_pauldron, 2)
        right_pauldron = [
            (cx + int(2.2 * b), shoulder_y - int(0.8 * b)),
            (cx + int(1.2 * b), shoulder_y - int(1 * b)),
            (cx + int(0.8 * b), shoulder_y + int(0.8 * b)),
            (cx + int(2.5 * b), shoulder_y + int(1 * b)),
        ]
        pygame.draw.polygon(screen, metal, right_pauldron)
        pygame.draw.polygon(screen, dark, right_pauldron, 2)

        # === 팔 ===
        arm_y = shoulder_y + int(0.5 * b)
        pygame.draw.line(screen, metal, (cx - int(2 * b), arm_y), (cx - int(2.8 * b), arm_y + int(1.5 * b)), int(0.7 * b))
        pygame.draw.line(screen, metal, (cx + int(2 * b), arm_y), (cx + int(2.8 * b), arm_y + int(1.2 * b)), int(0.7 * b))

        # === 큰 방패 (왼손) ===
        shield_cx = cx - int(3.5 * b)
        shield_cy = arm_y + int(1 * b)
        shield_w = int(2.5 * b)
        shield_h = int(4 * b)
        shield_rect = pygame.Rect(shield_cx - shield_w // 2, shield_cy - shield_h // 2, shield_w, shield_h)
        pygame.draw.rect(screen, main, shield_rect, border_radius=int(0.3 * b))
        pygame.draw.rect(screen, light, shield_rect, 3, border_radius=int(0.3 * b))
        if not show_back:
            # 정면에서만 방패 문양 보임
            pygame.draw.line(screen, metal, (shield_cx, shield_rect.top + int(0.5 * b)), (shield_cx, shield_rect.bottom - int(0.5 * b)), int(0.4 * b))
            pygame.draw.line(screen, metal, (shield_rect.left + int(0.4 * b), shield_cy), (shield_rect.right - int(0.4 * b), shield_cy), int(0.4 * b))

    # ========================================================================
    # 토키아 - 바위의 거인 (거대/둔중 테마)
    # ========================================================================
    def _draw_tokia(self, screen, cx, cy, b, show_back, lean, color):
        """토키아 - 거대한 바위 전사"""
        cx = int(cx) + lean // 2
        cy = int(cy)
        b = int(b * 1.2)  # 더 큰 캐릭터

        main = (200, 140, 60)
        dark = (150, 100, 40)
        light = (230, 180, 100)
        rock = (140, 130, 110)
        skin = (180, 140, 100)

        torso_y = cy - int(1.5 * b)

        # === 머리 ===
        head_y = torso_y - int(3 * b)
        head_r = int(2 * b)
        pygame.draw.circle(screen, skin, (cx, head_y), head_r)
        pygame.draw.circle(screen, dark, (cx, head_y), head_r, 2)

        if show_back:
            # 뒷모습 - 대머리/짧은 머리
            pygame.draw.arc(screen, dark, (cx - head_r, head_y - head_r, head_r * 2, head_r * 2),
                           math.pi * 0.2, math.pi * 0.8, 3)
            # 뒷목 주름
            pygame.draw.line(screen, dark, (cx - int(0.5 * b), head_y + head_r - int(0.3 * b)),
                           (cx + int(0.5 * b), head_y + head_r - int(0.3 * b)), 2)
        else:
            # 정면 - 바위 같은 이마 장식
            brow_y = head_y - int(0.5 * b)
            for i in range(3):
                rock_x = cx - int(1 * b) + i * int(1 * b)
                pygame.draw.circle(screen, rock, (rock_x, brow_y), int(0.4 * b))
            # 작은 눈
            eye_y = head_y + int(0.5 * b)
            pygame.draw.circle(screen, (60, 40, 20), (cx - int(0.5 * b), eye_y), int(0.3 * b))
            pygame.draw.circle(screen, (60, 40, 20), (cx + int(0.5 * b), eye_y), int(0.3 * b))
            # 두꺼운 눈썹
            brow_line_y = eye_y - int(0.4 * b)
            pygame.draw.line(screen, dark, (cx - int(1 * b), brow_line_y + int(0.1 * b)), (cx - int(0.2 * b), brow_line_y), int(0.3 * b))
            pygame.draw.line(screen, dark, (cx + int(0.2 * b), brow_line_y), (cx + int(1 * b), brow_line_y + int(0.1 * b)), int(0.3 * b))

        # === 거대한 몸통 ===
        torso_w = int(5 * b)
        torso_h = int(3.5 * b)
        torso_rect = pygame.Rect(cx - torso_w // 2, torso_y - int(0.5 * b), torso_w, torso_h)
        pygame.draw.rect(screen, main, torso_rect, border_radius=int(0.6 * b))
        pygame.draw.rect(screen, dark, torso_rect, 3, border_radius=int(0.6 * b))

        # 바위 질감
        for i in range(4):
            rx = torso_rect.x + int(0.8 * b) + i * int(1 * b)
            ry = torso_rect.centery + ((i % 2) - 0.5) * int(0.5 * b)
            pygame.draw.circle(screen, rock, (int(rx), int(ry)), int(0.5 * b))
            pygame.draw.circle(screen, dark, (int(rx), int(ry)), int(0.5 * b), 1)

        # === 거대한 어깨 ===
        shoulder_y = torso_y - int(0.5 * b)
        pygame.draw.ellipse(screen, main, (cx - int(3 * b), shoulder_y - int(1 * b), int(1.8 * b), int(2 * b)))
        pygame.draw.ellipse(screen, dark, (cx - int(3 * b), shoulder_y - int(1 * b), int(1.8 * b), int(2 * b)), 2)
        pygame.draw.ellipse(screen, main, (cx + int(1.2 * b), shoulder_y - int(1 * b), int(1.8 * b), int(2 * b)))
        pygame.draw.ellipse(screen, dark, (cx + int(1.2 * b), shoulder_y - int(1 * b), int(1.8 * b), int(2 * b)), 2)

        # === 두꺼운 팔 ===
        arm_y = shoulder_y + int(0.8 * b)
        pygame.draw.line(screen, skin, (cx - int(2.5 * b), arm_y), (cx - int(3.5 * b), arm_y + int(2 * b)), int(1 * b))
        pygame.draw.line(screen, skin, (cx + int(2.5 * b), arm_y), (cx + int(3.5 * b), arm_y + int(2 * b)), int(1 * b))
        # 큰 주먹
        pygame.draw.circle(screen, skin, (cx - int(3.5 * b), arm_y + int(2.2 * b)), int(0.8 * b))
        pygame.draw.circle(screen, skin, (cx + int(3.5 * b), arm_y + int(2.2 * b)), int(0.8 * b))

    # ========================================================================
    # 포이네스 - 그림자 암살자 (스텔스/닌자 테마)
    # ========================================================================
    def _draw_poineth(self, screen, cx, cy, b, show_back, lean, color):
        """포이네스 - 그림자 암살자"""
        cx = int(cx) + lean
        cy = int(cy)

        main = (160, 60, 200)
        dark = (100, 40, 140)
        light = (200, 120, 255)
        shadow = (40, 20, 60)

        torso_y = cy - int(1.5 * b)

        # === 후드 머리 ===
        head_y = torso_y - int(3 * b)
        hood_points = [
            (cx - int(2 * b), head_y + int(0.8 * b)),
            (cx, head_y - int(2 * b)),
            (cx + int(2 * b), head_y + int(0.8 * b)),
            (cx + int(1.5 * b), head_y + int(1.5 * b)),
            (cx - int(1.5 * b), head_y + int(1.5 * b)),
        ]
        pygame.draw.polygon(screen, dark, hood_points)
        pygame.draw.polygon(screen, main, hood_points, 2)

        if show_back:
            # 뒷모습 - 후드 뒷면
            pygame.draw.circle(screen, dark, (cx, head_y + int(0.3 * b)), int(1 * b))
            # 후드 주름
            pygame.draw.arc(screen, shadow, (cx - int(1 * b), head_y - int(0.5 * b), int(2 * b), int(1.5 * b)),
                           math.pi * 0.3, math.pi * 0.7, 2)
        else:
            # 정면 - 그림자 속 얼굴
            pygame.draw.circle(screen, shadow, (cx, head_y + int(0.3 * b)), int(1 * b))
            # 빛나는 눈
            eye_y = head_y + int(0.3 * b)
            glow = int(128 + 127 * math.sin(self.animation_time * 5))
            eye_color = (glow, int(glow * 0.5), 255)
            pygame.draw.circle(screen, eye_color, (cx - int(0.4 * b), eye_y), int(0.25 * b))
            pygame.draw.circle(screen, eye_color, (cx + int(0.4 * b), eye_y), int(0.25 * b))

        # === 날렵한 몸통 ===
        torso_w = int(2.5 * b)
        body_points = [
            (cx - torso_w // 2, torso_y - int(0.5 * b)),
            (cx + torso_w // 2, torso_y - int(0.5 * b)),
            (cx + int(1 * b), torso_y + int(2 * b)),
            (cx - int(1 * b), torso_y + int(2 * b)),
        ]
        pygame.draw.polygon(screen, dark, body_points)
        pygame.draw.polygon(screen, main, body_points, 2)

        # === 어깨 패드 ===
        shoulder_y = torso_y - int(0.3 * b)
        pygame.draw.ellipse(screen, main, (cx - int(2 * b), shoulder_y - int(0.4 * b), int(1 * b), int(0.8 * b)))
        pygame.draw.ellipse(screen, main, (cx + int(1 * b), shoulder_y - int(0.4 * b), int(1 * b), int(0.8 * b)))

        # === 팔 ===
        arm_y = shoulder_y + int(0.2 * b)
        pygame.draw.line(screen, dark, (cx - int(1.5 * b), arm_y), (cx - int(2.5 * b), arm_y + int(1.2 * b)), int(0.4 * b))
        pygame.draw.line(screen, dark, (cx + int(1.5 * b), arm_y), (cx + int(2.5 * b), arm_y + int(1.2 * b)), int(0.4 * b))

        # === 단검 (양손) ===
        dagger_start = (cx - int(2.5 * b), arm_y + int(1.3 * b))
        dagger_end = (dagger_start[0] - int(1.5 * b), dagger_start[1] - int(0.8 * b))
        pygame.draw.line(screen, (200, 200, 220), dagger_start, dagger_end, int(0.2 * b))
        dagger_start2 = (cx + int(2.5 * b), arm_y + int(1.3 * b))
        dagger_end2 = (dagger_start2[0] + int(1.5 * b), dagger_start2[1] - int(0.8 * b))
        pygame.draw.line(screen, (200, 200, 220), dagger_start2, dagger_end2, int(0.2 * b))

    # ========================================================================
    # 게스탄드 - 현명한 전술가 (마법사/책 테마)
    # ========================================================================
    def _draw_gestand(self, screen, cx, cy, b, show_back, lean, color):
        """게스탄드 - 현자, 마법 지팡이"""
        cx = int(cx) + lean
        cy = int(cy)

        main = (100, 160, 220)
        dark = (60, 120, 180)
        light = (140, 200, 255)
        robe = (60, 80, 140)
        skin = (240, 220, 200)
        beard = (200, 200, 210)

        torso_y = cy - int(1.5 * b)

        # === 머리 ===
        head_y = torso_y - int(3 * b)
        head_r = int(1.6 * b)
        pygame.draw.circle(screen, skin, (cx, head_y), head_r)

        if show_back:
            # 뒷모습 - 짧은 회색 머리
            pygame.draw.arc(screen, (150, 150, 160), (cx - head_r, head_y - head_r, head_r * 2, head_r * 2),
                           math.pi * 0.2, math.pi * 0.8, int(0.5 * b))
            # 뒷목
            pygame.draw.rect(screen, skin, (cx - int(0.4 * b), head_y + head_r - int(0.3 * b), int(0.8 * b), int(0.5 * b)))
        else:
            # 정면 - 수염 현자
            # 짧은 머리카락
            pygame.draw.arc(screen, (150, 150, 160),
                           (cx - int(1.5 * b), head_y - int(1.8 * b), int(3 * b), int(2 * b)),
                           0, math.pi, int(0.4 * b))
            # 눈
            eye_y = head_y + int(0.2 * b)
            pygame.draw.circle(screen, (255, 255, 255), (cx - int(0.4 * b), eye_y), int(0.35 * b))
            pygame.draw.circle(screen, (255, 255, 255), (cx + int(0.4 * b), eye_y), int(0.35 * b))
            pygame.draw.circle(screen, (40, 80, 120), (cx - int(0.4 * b), eye_y + int(0.05 * b)), int(0.2 * b))
            pygame.draw.circle(screen, (40, 80, 120), (cx + int(0.4 * b), eye_y + int(0.05 * b)), int(0.2 * b))
            # 수염
            beard_top = head_y + int(0.8 * b)
            beard_bottom = head_y + int(2 * b)
            beard_points = [
                (cx - int(0.8 * b), beard_top),
                (cx + int(0.8 * b), beard_top),
                (cx + int(0.5 * b), beard_bottom),
                (cx, beard_bottom + int(0.5 * b)),
                (cx - int(0.5 * b), beard_bottom),
            ]
            pygame.draw.polygon(screen, beard, beard_points)

        # === 로브 몸통 ===
        robe_points = [
            (cx - int(1.2 * b), torso_y - int(0.8 * b)),
            (cx + int(1.2 * b), torso_y - int(0.8 * b)),
            (cx + int(2 * b), torso_y + int(2.5 * b)),
            (cx - int(2 * b), torso_y + int(2.5 * b)),
        ]
        pygame.draw.polygon(screen, robe, robe_points)
        pygame.draw.polygon(screen, dark, robe_points, 2)

        if not show_back:
            # 정면 로브 장식
            pygame.draw.line(screen, main, (cx, torso_y - int(0.5 * b)), (cx, torso_y + int(2 * b)), int(0.3 * b))

        # === 어깨 ===
        shoulder_y = torso_y - int(0.5 * b)
        pygame.draw.ellipse(screen, main, (cx - int(2 * b), shoulder_y - int(0.5 * b), int(1.2 * b), int(1 * b)))
        pygame.draw.ellipse(screen, main, (cx + int(0.8 * b), shoulder_y - int(0.5 * b), int(1.2 * b), int(1 * b)))

        # === 팔 ===
        arm_y = shoulder_y + int(0.3 * b)
        pygame.draw.line(screen, robe, (cx - int(1.5 * b), arm_y), (cx - int(2.2 * b), arm_y + int(1.5 * b)), int(0.5 * b))
        pygame.draw.line(screen, robe, (cx + int(1.5 * b), arm_y), (cx + int(2.5 * b), arm_y + int(1 * b)), int(0.5 * b))

        # === 마법 지팡이 ===
        staff_x = cx + int(3 * b)
        staff_top = arm_y - int(2.5 * b)
        staff_bottom = arm_y + int(2 * b)
        pygame.draw.line(screen, (120, 80, 50), (staff_x, staff_top), (staff_x, staff_bottom), int(0.3 * b))
        # 지팡이 끝 마법 구슬
        orb_y = staff_top - int(0.5 * b)
        pygame.draw.circle(screen, (100, 200, 255), (staff_x, orb_y), int(0.6 * b))
        pygame.draw.circle(screen, (200, 240, 255), (staff_x, orb_y), int(0.3 * b))

    # ========================================================================
    # 부칸다이 - 광기의 광대 (광대/트릭 테마)
    # ========================================================================
    def _draw_bukandai(self, screen, cx, cy, b, show_back, lean, color):
        """부칸다이 - 미친 광대"""
        cx = int(cx) + lean
        cy = int(cy)

        main = (220, 80, 180)
        dark = (180, 40, 140)
        alt = (80, 200, 220)
        skin = (255, 240, 220)
        yellow = (255, 255, 0)

        torso_y = cy - int(1.5 * b)

        # === 광대 모자 + 머리 ===
        head_y = torso_y - int(3 * b)
        head_r = int(1.5 * b)
        pygame.draw.circle(screen, skin, (cx, head_y), head_r)

        # 광대 모자 (세 갈래) - 정면/뒷면 모두 보임
        hat_top = head_y - int(2 * b)
        # 왼쪽 갈래
        pygame.draw.polygon(screen, main, [
            (cx - int(1.2 * b), head_y - int(0.8 * b)),
            (cx - int(0.3 * b), head_y - int(0.5 * b)),
            (cx - int(1 * b), hat_top - int(0.5 * b)),
        ])
        pygame.draw.circle(screen, yellow, (cx - int(1 * b), hat_top - int(0.8 * b)), int(0.3 * b))
        # 중앙 갈래
        pygame.draw.polygon(screen, alt, [
            (cx - int(0.5 * b), head_y - int(0.8 * b)),
            (cx + int(0.5 * b), head_y - int(0.8 * b)),
            (cx, hat_top - int(1 * b)),
        ])
        pygame.draw.circle(screen, yellow, (cx, hat_top - int(1.3 * b)), int(0.3 * b))
        # 오른쪽 갈래
        pygame.draw.polygon(screen, main, [
            (cx + int(0.3 * b), head_y - int(0.5 * b)),
            (cx + int(1.2 * b), head_y - int(0.8 * b)),
            (cx + int(1 * b), hat_top - int(0.5 * b)),
        ])
        pygame.draw.circle(screen, yellow, (cx + int(1 * b), hat_top - int(0.8 * b)), int(0.3 * b))

        if not show_back:
            # 정면 - 미친 눈과 미소
            eye_y = head_y + int(0.2 * b)
            pygame.draw.circle(screen, (255, 255, 255), (cx - int(0.5 * b), eye_y), int(0.5 * b))
            pygame.draw.circle(screen, (255, 255, 255), (cx + int(0.5 * b), eye_y), int(0.35 * b))
            pygame.draw.circle(screen, main, (cx - int(0.5 * b), eye_y), int(0.25 * b))
            pygame.draw.circle(screen, alt, (cx + int(0.5 * b), eye_y), int(0.2 * b))
            # 미친 미소
            smile_y = head_y + int(0.8 * b)
            pygame.draw.arc(screen, (200, 50, 50),
                           (cx - int(0.8 * b), smile_y - int(0.4 * b), int(1.6 * b), int(0.8 * b)),
                           0, math.pi, int(0.2 * b))

        # === 광대 복장 ===
        torso_w = int(3 * b)
        torso_h = int(2.5 * b)
        torso_rect = pygame.Rect(cx - torso_w // 2, torso_y - int(0.5 * b), torso_w, torso_h)
        pygame.draw.rect(screen, main, torso_rect, border_radius=int(0.3 * b))
        # 다이아몬드 패턴
        for i in range(3):
            dx = cx - int(1 * b) + i * int(1 * b)
            pygame.draw.polygon(screen, alt, [
                (dx, torso_rect.centery - int(0.6 * b)),
                (dx + int(0.4 * b), torso_rect.centery),
                (dx, torso_rect.centery + int(0.6 * b)),
                (dx - int(0.4 * b), torso_rect.centery),
            ])

        # === 어깨 (퍼프) ===
        shoulder_y = torso_y - int(0.3 * b)
        pygame.draw.circle(screen, alt, (cx - int(1.8 * b), shoulder_y), int(0.7 * b))
        pygame.draw.circle(screen, main, (cx + int(1.8 * b), shoulder_y), int(0.7 * b))

        # === 팔 ===
        arm_y = shoulder_y + int(0.3 * b)
        pygame.draw.line(screen, main, (cx - int(1.8 * b), arm_y), (cx - int(2.5 * b), arm_y + int(1.2 * b)), int(0.4 * b))
        pygame.draw.line(screen, alt, (cx + int(1.8 * b), arm_y), (cx + int(2.8 * b), arm_y + int(1 * b)), int(0.4 * b))

        # === 폭탄 (오른손) ===
        bomb_x = cx + int(3 * b)
        bomb_y = arm_y + int(1.2 * b)
        pygame.draw.circle(screen, (40, 40, 40), (bomb_x, bomb_y), int(0.8 * b))
        pygame.draw.line(screen, (150, 100, 50), (bomb_x, bomb_y - int(0.8 * b)), (bomb_x + int(0.3 * b), bomb_y - int(1.3 * b)), int(0.15 * b))
        # 불꽃
        spark_y = bomb_y - int(1.5 * b)
        pygame.draw.circle(screen, (255, 200, 50), (bomb_x + int(0.3 * b), spark_y), int(0.3 * b))
        pygame.draw.circle(screen, (255, 100, 0), (bomb_x + int(0.3 * b), spark_y), int(0.2 * b))

    # ========================================================================
    # 핀조 - 불굴의 검투사 (로마 검투사 테마)
    # ========================================================================
    def _draw_pinjo(self, screen, cx, cy, b, show_back, lean, color):
        """핀조 - 로마 검투사"""
        cx = int(cx) + lean
        cy = int(cy)

        main = (220, 60, 60)
        dark = (160, 40, 40)
        light = (255, 100, 100)
        metal = (180, 170, 150)
        gold = (220, 180, 80)
        skin = (200, 160, 130)

        torso_y = cy - int(1.5 * b)

        # === 검투사 투구 ===
        head_y = torso_y - int(3 * b)
        helmet_rect = pygame.Rect(cx - int(1.8 * b), head_y - int(1.8 * b), int(3.6 * b), int(3 * b))
        pygame.draw.ellipse(screen, metal, helmet_rect)
        pygame.draw.ellipse(screen, dark, helmet_rect, 2)

        # 투구 깃털 장식
        feather_base = head_y - int(2 * b)
        pygame.draw.polygon(screen, main, [
            (cx - int(0.3 * b), feather_base),
            (cx, feather_base - int(2 * b)),
            (cx + int(0.3 * b), feather_base),
        ])

        if not show_back:
            # 정면 - 얼굴과 전투적인 눈
            face_y = head_y + int(0.5 * b)
            pygame.draw.rect(screen, skin, (cx - int(0.8 * b), face_y - int(0.5 * b), int(1.6 * b), int(1 * b)))
            # 전투적인 눈
            eye_y = face_y
            pygame.draw.line(screen, (80, 40, 40), (cx - int(0.7 * b), eye_y - int(0.15 * b)), (cx - int(0.2 * b), eye_y + int(0.05 * b)), 2)
            pygame.draw.line(screen, (80, 40, 40), (cx + int(0.2 * b), eye_y + int(0.05 * b)), (cx + int(0.7 * b), eye_y - int(0.15 * b)), 2)
            pygame.draw.circle(screen, (255, 200, 100), (cx - int(0.45 * b), eye_y), int(0.15 * b))
            pygame.draw.circle(screen, (255, 200, 100), (cx + int(0.45 * b), eye_y), int(0.15 * b))
        else:
            # 뒷모습 - 투구 뒷면
            pygame.draw.arc(screen, dark, helmet_rect, 0, math.pi, 3)

        # === 갑옷 몸통 ===
        torso_w = int(3.5 * b)
        torso_h = int(2.8 * b)
        torso_rect = pygame.Rect(cx - torso_w // 2, torso_y - int(0.5 * b), torso_w, torso_h)
        pygame.draw.rect(screen, main, torso_rect, border_radius=int(0.4 * b))
        pygame.draw.rect(screen, dark, torso_rect, 2, border_radius=int(0.4 * b))

        if not show_back:
            # 정면 복근 패턴
            for i in range(2):
                for j in range(2):
                    ax = cx - int(0.5 * b) + j * int(1 * b)
                    ay = torso_rect.centery - int(0.4 * b) + i * int(0.8 * b)
                    pygame.draw.rect(screen, dark, (ax - int(0.3 * b), ay - int(0.25 * b), int(0.6 * b), int(0.5 * b)), 1, border_radius=2)

        # 벨트
        belt_y = torso_rect.bottom - int(0.5 * b)
        pygame.draw.rect(screen, gold, (cx - int(1.5 * b), belt_y, int(3 * b), int(0.5 * b)))

        # === 어깨 보호대 ===
        shoulder_y = torso_y - int(0.5 * b)
        pygame.draw.ellipse(screen, metal, (cx - int(2.3 * b), shoulder_y - int(0.7 * b), int(1.4 * b), int(1.4 * b)))
        pygame.draw.ellipse(screen, dark, (cx - int(2.3 * b), shoulder_y - int(0.7 * b), int(1.4 * b), int(1.4 * b)), 2)
        pygame.draw.ellipse(screen, metal, (cx + int(0.9 * b), shoulder_y - int(0.7 * b), int(1.4 * b), int(1.4 * b)))
        pygame.draw.ellipse(screen, dark, (cx + int(0.9 * b), shoulder_y - int(0.7 * b), int(1.4 * b), int(1.4 * b)), 2)

        # === 팔 ===
        arm_y = shoulder_y + int(0.5 * b)
        pygame.draw.line(screen, skin, (cx - int(1.8 * b), arm_y), (cx - int(2.8 * b), arm_y + int(1.5 * b)), int(0.6 * b))
        pygame.draw.line(screen, skin, (cx + int(1.8 * b), arm_y), (cx + int(2.8 * b), arm_y + int(1.2 * b)), int(0.6 * b))

        # === 검 (오른손) ===
        sword_hand = (cx + int(2.8 * b), arm_y + int(1.3 * b))
        sword_tip = (sword_hand[0] + int(2 * b), sword_hand[1] - int(1.5 * b))
        pygame.draw.line(screen, (220, 220, 230), sword_hand, sword_tip, int(0.3 * b))
        pygame.draw.line(screen, (100, 60, 30), sword_hand, (sword_hand[0] - int(0.3 * b), sword_hand[1] + int(0.5 * b)), int(0.25 * b))

        # === 작은 방패 (왼손) ===
        shield_cx = cx - int(3.2 * b)
        shield_cy = arm_y + int(1.2 * b)
        pygame.draw.circle(screen, metal, (shield_cx, shield_cy), int(1 * b))
        pygame.draw.circle(screen, gold, (shield_cx, shield_cy), int(0.5 * b))
        pygame.draw.circle(screen, dark, (shield_cx, shield_cy), int(1 * b), 2)

    # ========================================================================
    # 알렉사 - 황금의 창 (귀족/황금 테마)
    # ========================================================================
    def _draw_alexa(self, screen, cx, cy, b, show_back, lean, color):
        """알렉사 - 황금 갑옷의 귀족 전사"""
        cx = int(cx) + lean
        cy = int(cy)

        gold = (220, 180, 60)
        dark_gold = (180, 140, 40)
        light_gold = (255, 220, 100)
        skin = (255, 230, 210)
        red = (180, 50, 50)
        hair = (200, 160, 80)

        torso_y = cy - int(1.5 * b)

        # === 머리 + 왕관 ===
        head_y = torso_y - int(3 * b)
        head_r = int(1.5 * b)

        if show_back:
            # 뒷모습 - 금발 뒷머리
            pygame.draw.circle(screen, hair, (cx, head_y), head_r)
            # 머리카락 질감
            for i in range(5):
                angle = math.pi * 0.3 + i * 0.3
                hx = cx + int(math.cos(angle) * head_r * 0.8)
                hy = head_y + int(math.sin(angle) * head_r * 0.8)
                pygame.draw.line(screen, dark_gold, (cx, head_y - int(0.5 * b)), (hx, hy + int(0.5 * b)), 2)
        else:
            # 정면 - 얼굴
            pygame.draw.circle(screen, skin, (cx, head_y), head_r)
            # 금발 앞머리
            pygame.draw.arc(screen, light_gold, (cx - int(1.5 * b), head_y - int(2 * b), int(3 * b), int(2.5 * b)),
                           0, math.pi, int(0.5 * b))
            # 눈
            eye_y = head_y + int(0.2 * b)
            pygame.draw.ellipse(screen, (255, 255, 255), (cx - int(0.7 * b), eye_y - int(0.2 * b), int(0.5 * b), int(0.4 * b)))
            pygame.draw.ellipse(screen, (255, 255, 255), (cx + int(0.2 * b), eye_y - int(0.2 * b), int(0.5 * b), int(0.4 * b)))
            pygame.draw.circle(screen, (100, 80, 60), (cx - int(0.45 * b), eye_y), int(0.15 * b))
            pygame.draw.circle(screen, (100, 80, 60), (cx + int(0.45 * b), eye_y), int(0.15 * b))
            # 미소
            smile_y = head_y + int(0.7 * b)
            pygame.draw.arc(screen, (200, 100, 100),
                           (cx - int(0.4 * b), smile_y - int(0.2 * b), int(0.8 * b), int(0.4 * b)),
                           0, math.pi, 1)

        # 왕관 - 정면/뒷면 모두 보임
        crown_base = head_y - int(1.2 * b)
        crown_points = [
            (cx - int(1.2 * b), crown_base + int(0.3 * b)),
            (cx - int(0.8 * b), crown_base - int(0.8 * b)),
            (cx - int(0.3 * b), crown_base + int(0.1 * b)),
            (cx, crown_base - int(1.2 * b)),
            (cx + int(0.3 * b), crown_base + int(0.1 * b)),
            (cx + int(0.8 * b), crown_base - int(0.8 * b)),
            (cx + int(1.2 * b), crown_base + int(0.3 * b)),
        ]
        pygame.draw.polygon(screen, gold, crown_points)
        pygame.draw.polygon(screen, dark_gold, crown_points, 2)
        # 왕관 보석
        pygame.draw.circle(screen, red, (cx, crown_base - int(0.9 * b)), int(0.25 * b))

        # === 황금 갑옷 ===
        torso_w = int(3.2 * b)
        torso_h = int(2.8 * b)
        torso_rect = pygame.Rect(cx - torso_w // 2, torso_y - int(0.5 * b), torso_w, torso_h)
        pygame.draw.rect(screen, gold, torso_rect, border_radius=int(0.5 * b))
        pygame.draw.rect(screen, dark_gold, torso_rect, 2, border_radius=int(0.5 * b))

        if not show_back:
            # 정면 갑옷 장식
            inner_rect = torso_rect.inflate(-int(0.6 * b), -int(0.4 * b))
            pygame.draw.rect(screen, light_gold, inner_rect, 2, border_radius=int(0.4 * b))
            # 중앙 보석
            pygame.draw.circle(screen, red, (cx, torso_rect.centery), int(0.4 * b))
            pygame.draw.circle(screen, (255, 100, 100), (cx - int(0.1 * b), torso_rect.centery - int(0.1 * b)), int(0.15 * b))

        # === 어깨 ===
        shoulder_y = torso_y - int(0.4 * b)
        pygame.draw.ellipse(screen, gold, (cx - int(2.2 * b), shoulder_y - int(0.6 * b), int(1.3 * b), int(1.2 * b)))
        pygame.draw.ellipse(screen, dark_gold, (cx - int(2.2 * b), shoulder_y - int(0.6 * b), int(1.3 * b), int(1.2 * b)), 2)
        pygame.draw.ellipse(screen, gold, (cx + int(0.9 * b), shoulder_y - int(0.6 * b), int(1.3 * b), int(1.2 * b)))
        pygame.draw.ellipse(screen, dark_gold, (cx + int(0.9 * b), shoulder_y - int(0.6 * b), int(1.3 * b), int(1.2 * b)), 2)

        # === 팔 ===
        arm_y = shoulder_y + int(0.4 * b)
        pygame.draw.line(screen, skin, (cx - int(1.7 * b), arm_y), (cx - int(2.5 * b), arm_y + int(1.3 * b)), int(0.5 * b))
        pygame.draw.line(screen, skin, (cx + int(1.7 * b), arm_y), (cx + int(2.8 * b), arm_y + int(1 * b)), int(0.5 * b))

        # === 황금 창 ===
        spear_x = cx + int(3.2 * b)
        spear_top = arm_y - int(3 * b)
        spear_bottom = arm_y + int(2 * b)
        pygame.draw.line(screen, gold, (spear_x, spear_top), (spear_x, spear_bottom), int(0.25 * b))
        # 창날
        tip_y = spear_top - int(1 * b)
        pygame.draw.polygon(screen, light_gold, [
            (spear_x, tip_y),
            (spear_x - int(0.5 * b), spear_top),
            (spear_x + int(0.5 * b), spear_top),
        ])
        pygame.draw.polygon(screen, dark_gold, [
            (spear_x, tip_y),
            (spear_x - int(0.5 * b), spear_top),
            (spear_x + int(0.5 * b), spear_top),
        ], 1)

    # ========================================================================
    # 유틸리티
    # ========================================================================
    def _draw_default(self, screen, cx, cy, b, show_back, lean, color):
        """기본 캐릭터"""
        cx = int(cx) + lean
        cy = int(cy)
        torso_y = cy - int(1.5 * b)

        # 머리
        head_y = torso_y - int(3 * b)
        pygame.draw.circle(screen, (200, 180, 160), (cx, head_y), int(1.5 * b))

        if not show_back:
            # 정면 눈
            eye_y = head_y + int(0.3 * b)
            pygame.draw.circle(screen, (0, 0, 0), (cx - int(0.4 * b), eye_y), int(0.2 * b))
            pygame.draw.circle(screen, (0, 0, 0), (cx + int(0.4 * b), eye_y), int(0.2 * b))

        # 몸통
        torso_rect = pygame.Rect(cx - int(1.5 * b), torso_y - int(0.5 * b), int(3 * b), int(2.5 * b))
        pygame.draw.rect(screen, color, torso_rect, border_radius=int(0.4 * b))


# 싱글톤
_hero_paddle_renderer: Optional[HeroPaddleRenderer] = None

def get_hero_paddle_renderer() -> HeroPaddleRenderer:
    global _hero_paddle_renderer
    if _hero_paddle_renderer is None:
        _hero_paddle_renderer = HeroPaddleRenderer()
    return _hero_paddle_renderer
