"""
SmasherBoardPart — 스매셔 호버보드 파츠.
v3: 부유 반중력 글로우 + 에너지 트레일 + 하방 스러스터 제거 (좌우 이동 화염만 존재)
"""

import math
import pygame
from entities.player_skeleton import (
    BodyPart, Joint, Skeleton, ORDER_BOARD, SLOT_BOARD,
)
from typing import Optional


class SmasherBoardPart(BodyPart):

    def __init__(self, block: int = 9):
        super().__init__(slot=SLOT_BOARD, draw_order=ORDER_BOARD,
                         joint_a="hip", joint_b=None)
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, hip_y = joint_a.world_int()

        t = pygame.time.get_ticks() / 1000.0
        wave = math.sin(phase * math.tau)
        hip_sway = int(wave * 2)
        sway_offset = int(hip_sway * 0.3)

        # 보드 자체 미세 진동
        board_float = math.sin(t * 4.5) * 1.0

        board_y_offset = int(3.4 * b)
        board_y = hip_y + board_y_offset + int(board_float)

        board_length = int(7.6 * b)
        board_thickness = max(5, int(0.7 * b))
        board_rect = pygame.Rect(
            cx - board_length // 2 - sway_offset,
            board_y, board_length, board_thickness,
        )

        nose_length = int(1.4 * b)
        tail_length = int(1.4 * b)

        pulse = 0.5 + 0.5 * math.sin(t * 5.0)
        # ── 반중력장 글로우 (보드 아래 에너지 필드) ──
        antigrav_w = board_length + int(2 * b)
        antigrav_h = int(2.0 * b)
        antigrav_surf = pygame.Surface((antigrav_w, antigrav_h), pygame.SRCALPHA)
        ag_alpha = int(20 + 15 * pulse)
        pygame.draw.ellipse(antigrav_surf,
                           (*palette["board_glow"], ag_alpha),
                           (0, 0, antigrav_w, antigrav_h))
        surface.blit(antigrav_surf,
                    (board_rect.centerx - antigrav_w // 2,
                     board_rect.bottom + int(0.2 * b)),
                    special_flags=pygame.BLEND_RGBA_ADD)

        # ── 보드 본체 ──
        board_poly = [
            (board_rect.left - nose_length, board_rect.centery + board_thickness // 2),
            (board_rect.left + nose_length // 2, board_rect.top),
            (board_rect.right - tail_length // 2, board_rect.top),
            (board_rect.right + tail_length, board_rect.centery + board_thickness // 2),
            (board_rect.right - tail_length // 2, board_rect.bottom),
            (board_rect.left + nose_length // 2, board_rect.bottom),
        ]
        # 바닥면 + 측면 + 상면
        pygame.draw.polygon(surface, (18, 24, 45), [(x, y + 2) for x, y in board_poly])
        pygame.draw.polygon(surface, (35, 45, 80), [(x, y + 1) for x, y in board_poly])
        pygame.draw.polygon(surface, palette["board_base"], board_poly)

        # 데크 하이라이트
        deck_poly = [
            (board_rect.left - nose_length // 2, board_rect.centery + board_thickness // 4),
            (board_rect.left + nose_length // 2, board_rect.top + 1),
            (board_rect.right - tail_length // 2, board_rect.top + 1),
            (board_rect.right + tail_length // 2, board_rect.centery + board_thickness // 4),
            (board_rect.right - tail_length // 2, board_rect.bottom - board_thickness // 3),
            (board_rect.left + nose_length // 2, board_rect.bottom - board_thickness // 3),
        ]
        pygame.draw.polygon(surface, palette["board_highlight"], deck_poly)

        # ── 데크 패널라인 + 에너지 트레일 ──
        routing_start = board_rect.left + nose_length
        routing_end = board_rect.right - tail_length
        routing_len = routing_end - routing_start

        for i in range(1, 4):
            lx = routing_start + routing_len * i // 4
            pygame.draw.line(surface, (30, 40, 65),
                           (lx, board_rect.top + 1), (lx, board_rect.bottom - 1), 1)

        # 가로 라우팅
        for offset, color in ((0, palette["board_highlight"]),
                               (board_thickness // 2, palette["board_shadow"])):
            pygame.draw.line(surface, color,
                           (routing_start, board_rect.top + board_thickness // 2 - offset),
                           (routing_end, board_rect.top + board_thickness // 2 - offset), 1)

        # 에너지 트레일 (중앙 발광)
        trail_y = board_rect.centery
        trail_alpha = int(50 + 30 * pulse)
        pygame.draw.line(surface, (*palette["board_glow"], trail_alpha),
                        (routing_start + 4, trail_y), (routing_end - 4, trail_y), 2)
        # 트레일 블룸
        tg_w = routing_len
        tg_h = int(b * 0.6)
        tg = pygame.Surface((tg_w, tg_h), pygame.SRCALPHA)
        pygame.draw.ellipse(tg, (*palette["board_glow"], int(15 * pulse)), tg.get_rect())
        surface.blit(tg, (routing_start, trail_y - tg_h // 2),
                    special_flags=pygame.BLEND_RGBA_ADD)

        # 외곽선 + 상면 엣지
        pygame.draw.polygon(surface, (30, 40, 68), board_poly, 1)
        pygame.draw.line(surface, (*palette["board_highlight"], 160),
                        board_poly[1], board_poly[2], 1)

        # ── 노즈/테일 LED ──
        for rx, po in [(board_rect.left + nose_length // 2, 0),
                       (board_rect.right - tail_length // 2, math.pi)]:
            lp = 0.5 + 0.5 * math.sin(t * 6.0 + po)
            lg = pygame.Surface((int(b * 0.8), int(b * 0.8)), pygame.SRCALPHA)
            pygame.draw.circle(lg, (*palette["board_glow"], int(35 * lp)),
                             (int(b * 0.4), int(b * 0.4)), int(b * 0.4))
            surface.blit(lg, (rx - int(b * 0.4), board_rect.centery - int(b * 0.4)),
                        special_flags=pygame.BLEND_RGBA_ADD)
            pygame.draw.circle(surface, palette["board_highlight"], (rx, board_rect.centery), 2)
            pygame.draw.circle(surface, (255, 255, 255), (rx, board_rect.centery), 1)

        # ── 리벳 ──
        for i in range(1, 4):
            rx = routing_start + routing_len * i // 4
            pygame.draw.circle(surface, palette["board_highlight"], (rx, board_rect.top + 1), 1)
            pygame.draw.circle(surface, palette["board_highlight"], (rx, board_rect.bottom - 1), 1)

        # ── 보드 하부 글로우 ──
        ug_w = board_length
        ug_h = int(b * 0.8)
        ug = pygame.Surface((ug_w, ug_h), pygame.SRCALPHA)
        pygame.draw.ellipse(ug, (*palette["board_glow"], int(25 + 15 * pulse)),
                           ug.get_rect())
        surface.blit(ug, (board_rect.centerx - ug_w // 2, board_rect.bottom),
                    special_flags=pygame.BLEND_RGBA_ADD)

        # ── 이동 방향 수평 배기 화염 (속도에 비례) ──
        # wave > 0이면 오른쪽 이동 → 왼쪽에서 배기
        # wave < 0이면 왼쪽 이동 → 오른쪽에서 배기
        move_strength = abs(wave)  # 0~1 (이동 강도)
        if move_strength > 0.05:
            # 이동 반대 방향에서 화염 분출
            if wave > 0:
                # 오른쪽 이동 → 왼쪽(노즈) 배기
                exhaust_x = board_rect.left - nose_length + int(0.3 * b)
                exhaust_dir = -1
            else:
                # 왼쪽 이동 → 오른쪽(테일) 배기
                exhaust_x = board_rect.right + tail_length - int(0.3 * b)
                exhaust_dir = 1

            exhaust_y = board_rect.centery
            self._draw_horizontal_exhaust(
                surface, exhaust_x, exhaust_y, exhaust_dir,
                move_strength, palette, t,
            )

        self._last_board_rect = board_rect

    def _draw_horizontal_exhaust(self, surface: pygame.Surface,
                                  x: int, y: int, direction: int,
                                  strength: float, palette: dict, t: float):
        """이동 속도에 비례하는 수평 배기 화염.

        strength=0이면 화염 없음, 1이면 최대 길이.
        direction: -1(왼쪽으로 분출), +1(오른쪽으로 분출)
        """
        b = self.block
        flicker = 0.6 + 0.4 * math.sin(t * 14.0)
        intensity = max(0.2, min(1.0, strength * 0.6 + flicker * 0.4))

        # 화염 길이 = 이동 속도에 비례 (느리면 짧고, 빠르면 길게)
        max_flame_len = int(3.5 * b)
        flame_len = int(max_flame_len * strength * intensity)
        flame_spread = int(b * 0.5 * (0.7 + 0.3 * intensity))

        if flame_len < 3:
            return

        fw = flame_len + int(b * 0.5)
        fh = flame_spread * 2 + 4
        fs = pygame.Surface((fw, fh), pygame.SRCALPHA)
        fcx = 0 if direction > 0 else fw  # 분출 시작점
        fcy = fh // 2

        # 화염 흔들림
        crest = int(math.sin(t * 18.0) * flame_spread * 0.15)

        # 외부 화염
        tip_x = fcx + direction * flame_len
        outer = [
            (fcx, fcy - flame_spread),
            (tip_x, fcy + crest),
            (fcx, fcy + flame_spread),
        ]
        pygame.draw.polygon(fs, (*palette["thruster_heat"], int(100 * intensity)), outer)

        # 중간 화염
        mid_spread = int(flame_spread * 0.65)
        mid_len = int(flame_len * 0.8)
        mid_tip = fcx + direction * mid_len
        mid = [
            (fcx, fcy - mid_spread),
            (mid_tip, fcy + crest // 2),
            (fcx, fcy + mid_spread),
        ]
        pygame.draw.polygon(fs, (*palette["thruster_glow"], int(120 * intensity)), mid)

        # 코어 (가장 밝은)
        core_spread = int(flame_spread * 0.3)
        core_len = int(flame_len * 0.55)
        core_tip = fcx + direction * core_len
        core = [
            (fcx, fcy - core_spread),
            (core_tip, fcy),
            (fcx, fcy + core_spread),
        ]
        pygame.draw.polygon(fs, (*palette["thruster_core"], int(180 * intensity)), core)

        # 코어 라인
        pygame.draw.line(fs, (255, 255, 240, int(200 * intensity)),
                        (fcx, fcy), (core_tip, fcy), 2)

        # 블릿
        blit_x = x - (0 if direction > 0 else fw)
        blit_y = y - fcy
        surface.blit(fs, (blit_x, blit_y), special_flags=pygame.BLEND_ADD)
