"""
SmasherBoardPart — 스매셔 호버보드 + 스러스터 파츠.

원본: pingfighter.py create_smasher_paddle_surface() 29949~30062줄
관절 바인딩: hip (보드는 다리 아래에 위치, hip 기준으로 상대 배치)
"""

import math
import pygame
from entities.player_skeleton import (
    BodyPart, Joint, Skeleton,
    ORDER_BOARD, SLOT_BOARD,
)
from typing import Optional


class SmasherBoardPart(BodyPart):
    """스매셔 호버보드 + 스러스터 화염.

    다리 아래에 보드를 그리고, 보드 하단에 스러스터 화염 효과를 렌더링.
    phase 값에 따라 화염이 흔들린다.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_BOARD,
            draw_order=ORDER_BOARD,
            joint_a="hip",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, hip_y = joint_a.world_int()

        wave = math.sin(phase * math.tau)
        hip_sway = int(wave * 2)
        sway_offset = int(hip_sway * 0.3)

        # 보드 Y 위치 = 다리 최하단 아래
        # 원본: calf.bottom - 0.25*b ≈ hip_y + 1.1*b + 2.2*b - 4 + 1.1*b - 0.25*b
        #      = hip_y + 4.15*b - 4 ≈ hip_y + 33 (block=9)
        # LegsPart 기준: pelvis는 hip_y+0.7*b에서 시작, calf bottom ≈ hip_y+30
        board_y_offset = int(3.4 * b)  # hip 기준 보드 위치 (다리 바로 아래)
        board_y = hip_y + board_y_offset

        board_length = int(7.6 * b)
        board_thickness = max(4, int(0.62 * b))
        board_rect = pygame.Rect(
            cx - board_length // 2 - sway_offset,
            board_y, board_length, board_thickness,
        )

        nose_length = int(1.4 * b)
        tail_length = int(1.4 * b)

        # ── 보드 그림자 ──
        board_shadow_poly = [
            (board_rect.left - nose_length // 2, board_rect.bottom + 2),
            (board_rect.left + nose_length, board_rect.top - 1),
            (board_rect.right - tail_length, board_rect.top - 1),
            (board_rect.right + tail_length // 2, board_rect.bottom + 2),
        ]
        pygame.draw.polygon(
            surface, (*palette["board_shadow"], 110), board_shadow_poly,
        )

        # ── 보드 본체 (6각형) ──
        board_poly = [
            (board_rect.left - nose_length, board_rect.centery + board_thickness // 2),
            (board_rect.left + nose_length // 2, board_rect.top),
            (board_rect.right - tail_length // 2, board_rect.top),
            (board_rect.right + tail_length, board_rect.centery + board_thickness // 2),
            (board_rect.right - tail_length // 2, board_rect.bottom),
            (board_rect.left + nose_length // 2, board_rect.bottom),
        ]
        pygame.draw.polygon(surface, palette["board_base"], board_poly)

        # ── 데크 패턴 ──
        deck_poly = [
            (board_rect.left - nose_length // 2, board_rect.centery + board_thickness // 3),
            (board_rect.left + nose_length // 2, board_rect.top + board_thickness // 4),
            (board_rect.right - tail_length // 2, board_rect.top + board_thickness // 4),
            (board_rect.right + tail_length // 2, board_rect.centery + board_thickness // 3),
            (board_rect.right - tail_length // 2, board_rect.bottom - board_thickness // 4),
            (board_rect.left + nose_length // 2, board_rect.bottom - board_thickness // 4),
        ]
        pygame.draw.polygon(surface, palette["board_highlight"], deck_poly)

        # ── 라우팅 라인 ──
        routing_length = board_rect.width - nose_length - tail_length
        routing_start = board_rect.left + nose_length
        for offset, color in ((0, palette["board_highlight"]),
                               (board_thickness // 2, palette["board_shadow"])):
            pygame.draw.line(
                surface, color,
                (routing_start, board_rect.top + board_thickness // 2 - offset),
                (routing_start + routing_length, board_rect.top + board_thickness // 2 - offset),
                2,
            )

        # ── 보드 글로우 ──
        thruster_height = int(1.5 * b)
        glow_w = board_length + int(1.6 * b)
        glow_h = thruster_height * 2
        board_glow_surface = pygame.Surface((glow_w, glow_h), pygame.SRCALPHA)
        pygame.draw.ellipse(
            board_glow_surface,
            (*palette["board_glow"], 60),
            board_glow_surface.get_rect(),
        )
        surface.blit(
            board_glow_surface,
            (board_rect.left - int(0.8 * b) - nose_length // 2,
             board_rect.bottom - glow_h // 2),
            special_flags=pygame.BLEND_ADD,
        )

        # ── 스러스터 화염 ──
        thruster_width = int(1.6 * b)

        # 왼쪽/오른쪽 스러스터 위치
        movement = min(1.0, abs(wave))
        base_strength = 0.25 + 0.35 * movement
        left_strength = min(1.0, base_strength + 0.4 * max(0.0, -wave))
        right_strength = min(1.0, base_strength + 0.4 * max(0.0, wave))

        left_x = cx - int(1.2 * b) - sway_offset - int(0.4 * b)
        right_x = cx + int(0.25 * b) - sway_offset + int(0.4 * b)

        self._draw_thruster(
            surface, left_x, board_rect.bottom,
            thruster_width, thruster_height, left_strength,
            palette, phase, 0.0,
        )
        self._draw_thruster(
            surface, right_x, board_rect.bottom,
            thruster_width, thruster_height, right_strength,
            palette, phase, math.pi,
        )

        self._last_board_rect = board_rect

    def _draw_thruster(self, surface: pygame.Surface,
                       base_x: int, base_y: int,
                       width: int, height: int, strength: float,
                       palette: dict, phase: float, phase_offset: float):
        """개별 스러스터 화염 렌더링."""
        b = self.block
        flicker = 0.6 + 0.4 * math.sin(phase * math.tau * 2.0 + phase_offset)
        intensity = max(0.25, min(1.0, strength * 0.6 + flicker * 0.4))

        flame_length = int(height * (1.6 + intensity))
        flame_width = int(width * (0.9 + 0.3 * intensity))
        flame_surface = pygame.Surface(
            (flame_width * 2, flame_length + height), pygame.SRCALPHA,
        )

        nozzle_cx = flame_width
        nozzle_cy = height // 2
        nozzle_rect = pygame.Rect(
            nozzle_cx - width // 2, nozzle_cy - height // 2,
            width, height,
        )

        # 노즐
        pygame.draw.ellipse(
            flame_surface, (*palette["board_glow"], int(120 * intensity)),
            nozzle_rect.inflate(int(0.5 * b), int(0.3 * b)),
        )
        pygame.draw.ellipse(
            flame_surface, (*palette["thruster_heat"], int(160 * intensity)),
            nozzle_rect,
        )
        pygame.draw.ellipse(
            flame_surface, palette["thruster_core"],
            nozzle_rect.inflate(-max(1, width // 3), -max(1, height // 3)),
        )

        # 화염 꼬리
        crest = int(math.sin(phase * math.tau * 4.0 + phase_offset) * flame_width * 0.25)
        outer_points = [
            (nozzle_cx - flame_width + 2, nozzle_rect.bottom - 1),
            (nozzle_cx + crest, nozzle_rect.bottom - 1 + flame_length),
            (nozzle_cx + flame_width - 2, nozzle_rect.bottom - 1),
        ]
        pygame.draw.polygon(
            flame_surface,
            (*palette["thruster_heat"], int(180 * intensity)),
            outer_points,
        )

        inner_points = [
            (nozzle_cx - flame_width // 2, nozzle_rect.bottom + flame_length // 3),
            (nozzle_cx + crest // 2, nozzle_rect.bottom - 1 + flame_length - flame_length // 4),
            (nozzle_cx + flame_width // 2, nozzle_rect.bottom + flame_length // 3),
        ]
        pygame.draw.polygon(
            flame_surface,
            (*palette["thruster_glow"], int(160 * intensity)),
            inner_points,
        )

        surface.blit(
            flame_surface,
            (base_x - flame_width, base_y - height // 2),
            special_flags=pygame.BLEND_ADD,
        )
