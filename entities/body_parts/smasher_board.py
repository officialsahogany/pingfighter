"""
SmasherBoardPart — 스매셔 호버보드 + 스러스터 파츠.
Visual Polish: 3단 레이어링 + 스러스터 네온 블룸 + 데크 패널라인
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

        wave = math.sin(phase * math.tau)
        hip_sway = int(wave * 2)
        sway_offset = int(hip_sway * 0.3)

        board_y_offset = int(3.4 * b)
        board_y = hip_y + board_y_offset

        board_length = int(7.6 * b)
        board_thickness = max(4, int(0.62 * b))
        board_rect = pygame.Rect(
            cx - board_length // 2 - sway_offset,
            board_y, board_length, board_thickness,
        )

        nose_length = int(1.4 * b)
        tail_length = int(1.4 * b)

        # ── 보드 그림자 (3단 중 1단) ──
        shadow_poly = [
            (board_rect.left - nose_length // 2, board_rect.bottom + 3),
            (board_rect.left + nose_length, board_rect.top),
            (board_rect.right - tail_length, board_rect.top),
            (board_rect.right + tail_length // 2, board_rect.bottom + 3),
        ]
        pygame.draw.polygon(surface, (*palette["board_shadow"], 90), shadow_poly)

        # ── 보드 본체: 3단 (그림자 → 베이스 → 데크) ──
        board_poly = [
            (board_rect.left - nose_length, board_rect.centery + board_thickness // 2),
            (board_rect.left + nose_length // 2, board_rect.top),
            (board_rect.right - tail_length // 2, board_rect.top),
            (board_rect.right + tail_length, board_rect.centery + board_thickness // 2),
            (board_rect.right - tail_length // 2, board_rect.bottom),
            (board_rect.left + nose_length // 2, board_rect.bottom),
        ]
        # 바닥면 (어두운)
        bottom_poly = [(x, y + 1) for x, y in board_poly]
        pygame.draw.polygon(surface, (25, 32, 55), bottom_poly)
        # 베이스
        pygame.draw.polygon(surface, palette["board_base"], board_poly)

        # 데크 하이라이트
        deck_poly = [
            (board_rect.left - nose_length // 2, board_rect.centery + board_thickness // 3),
            (board_rect.left + nose_length // 2, board_rect.top + board_thickness // 4),
            (board_rect.right - tail_length // 2, board_rect.top + board_thickness // 4),
            (board_rect.right + tail_length // 2, board_rect.centery + board_thickness // 3),
            (board_rect.right - tail_length // 2, board_rect.bottom - board_thickness // 4),
            (board_rect.left + nose_length // 2, board_rect.bottom - board_thickness // 4),
        ]
        pygame.draw.polygon(surface, palette["board_highlight"], deck_poly)

        # ── 데크 패널라인 (세로 구분선 3개) ──
        routing_start = board_rect.left + nose_length
        routing_end = board_rect.right - tail_length
        routing_len = routing_end - routing_start
        for i in range(1, 4):
            lx = routing_start + routing_len * i // 4
            pygame.draw.line(surface, palette["board_shadow"],
                           (lx, board_rect.top + 1),
                           (lx, board_rect.bottom - 1), 1)

        # ── 라우팅 라인 (가로) ──
        for offset, color in ((0, palette["board_highlight"]),
                               (board_thickness // 2, palette["board_shadow"])):
            pygame.draw.line(surface, color,
                           (routing_start, board_rect.top + board_thickness // 2 - offset),
                           (routing_end, board_rect.top + board_thickness // 2 - offset), 2)

        # ── 보드 외곽 테두리 ──
        pygame.draw.polygon(surface, (35, 45, 75), board_poly, 1)

        # ── 보드 글로우 ──
        pulse = 0.6 + 0.4 * math.sin(phase * math.tau * 2)
        thruster_height = int(1.5 * b)
        glow_w = board_length + int(1.6 * b)
        glow_h = thruster_height * 2
        glow_surf = pygame.Surface((glow_w, glow_h), pygame.SRCALPHA)
        glow_alpha = int(50 * pulse)
        pygame.draw.ellipse(glow_surf, (*palette["board_glow"], glow_alpha),
                           glow_surf.get_rect())
        surface.blit(glow_surf,
                    (board_rect.left - int(0.8 * b) - nose_length // 2,
                     board_rect.bottom - glow_h // 2),
                    special_flags=pygame.BLEND_ADD)

        # ── 노즈/테일 리벳 ──
        for rx in [board_rect.left + nose_length // 2, board_rect.right - tail_length // 2]:
            pygame.draw.circle(surface, palette["board_highlight"],
                             (rx, board_rect.centery), 2)
            pygame.draw.circle(surface, (255, 255, 255), (rx, board_rect.centery), 1)

        # ── 스러스터 화염 ──
        thruster_width = int(1.6 * b)
        movement = min(1.0, abs(wave))
        base_strength = 0.25 + 0.35 * movement
        left_strength = min(1.0, base_strength + 0.4 * max(0.0, -wave))
        right_strength = min(1.0, base_strength + 0.4 * max(0.0, wave))

        left_x = cx - int(1.2 * b) - sway_offset - int(0.4 * b)
        right_x = cx + int(0.25 * b) - sway_offset + int(0.4 * b)

        self._draw_thruster(surface, left_x, board_rect.bottom,
                           thruster_width, thruster_height, left_strength,
                           palette, phase, 0.0)
        self._draw_thruster(surface, right_x, board_rect.bottom,
                           thruster_width, thruster_height, right_strength,
                           palette, phase, math.pi)

        self._last_board_rect = board_rect

    def _draw_thruster(self, surface, base_x, base_y,
                       width, height, strength, palette, phase, phase_offset):
        b = self.block
        flicker = 0.6 + 0.4 * math.sin(phase * math.tau * 2.0 + phase_offset)
        intensity = max(0.25, min(1.0, strength * 0.6 + flicker * 0.4))

        flame_length = int(height * (1.6 + intensity))
        flame_width = int(width * (0.9 + 0.3 * intensity))
        fs = pygame.Surface((flame_width * 2, flame_length + height), pygame.SRCALPHA)

        ncx = flame_width
        ncy = height // 2
        nr = pygame.Rect(ncx - width // 2, ncy - height // 2, width, height)

        # 노즐: 3단
        pygame.draw.ellipse(fs, (*palette["board_glow"], int(80 * intensity)),
                           nr.inflate(int(0.7 * b), int(0.4 * b)))
        pygame.draw.ellipse(fs, (*palette["thruster_heat"], int(140 * intensity)), nr)
        pygame.draw.ellipse(fs, palette["thruster_core"],
                           nr.inflate(-max(1, width // 3), -max(1, height // 3)))

        # 화염 꼬리: 외부 + 내부
        crest = int(math.sin(phase * math.tau * 4.0 + phase_offset) * flame_width * 0.25)
        outer = [
            (ncx - flame_width + 2, nr.bottom - 1),
            (ncx + crest, nr.bottom - 1 + flame_length),
            (ncx + flame_width - 2, nr.bottom - 1),
        ]
        pygame.draw.polygon(fs, (*palette["thruster_heat"], int(160 * intensity)), outer)

        inner = [
            (ncx - flame_width // 2, nr.bottom + flame_length // 3),
            (ncx + crest // 2, nr.bottom - 1 + flame_length - flame_length // 4),
            (ncx + flame_width // 2, nr.bottom + flame_length // 3),
        ]
        pygame.draw.polygon(fs, (*palette["thruster_glow"], int(140 * intensity)), inner)

        # 코어 라인 (가장 밝은 중심)
        core_tip = (ncx + crest // 3, nr.bottom - 1 + int(flame_length * 0.7))
        pygame.draw.line(fs, (*palette["thruster_core"], int(200 * intensity)),
                        (ncx, nr.bottom), core_tip, 2)

        surface.blit(fs, (base_x - flame_width, base_y - height // 2),
                    special_flags=pygame.BLEND_ADD)
