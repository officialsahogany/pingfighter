"""
SmasherBoardPart — 스매셔 호버보드 + 스러스터 파츠.
Visual Polish v2: 부유 반중력 글로우 + 에너지 트레일 + 스러스터 디테일 강화
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

        # 시간 기반 (phase는 걷기용이므로 보드는 독립 타이머 사용)
        t = pygame.time.get_ticks() / 1000.0

        wave = math.sin(phase * math.tau)
        hip_sway = int(wave * 2)
        sway_offset = int(hip_sway * 0.3)

        # 보드 자체의 미세 부유 (캐릭터 부유와 별개로 보드만의 흔들림)
        board_float = math.sin(t * 4.5) * 1.0  # 빠르고 작은 진동
        board_tilt = math.sin(t * 2.8 + 0.7) * 0.5  # 미세한 좌우 기울기

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
        move_pulse = 0.3 + 0.7 * min(1.0, abs(wave))  # 이동 시 더 밝아짐

        # ── 반중력장 글로우 (보드 아래쪽 바닥 반사) ──
        antigrav_w = board_length + int(2 * b)
        antigrav_h = int(2.5 * b)
        antigrav_surf = pygame.Surface((antigrav_w, antigrav_h), pygame.SRCALPHA)
        antigrav_alpha = int(25 + 20 * pulse * move_pulse)
        pygame.draw.ellipse(antigrav_surf,
                           (*palette["board_glow"], antigrav_alpha),
                           (0, 0, antigrav_w, antigrav_h))
        # 더 밝은 내부 코어
        inner_w = int(antigrav_w * 0.6)
        inner_h = int(antigrav_h * 0.5)
        pygame.draw.ellipse(antigrav_surf,
                           (*palette["thruster_glow"], int(15 * pulse)),
                           ((antigrav_w - inner_w) // 2, (antigrav_h - inner_h) // 2,
                            inner_w, inner_h))
        surface.blit(antigrav_surf,
                    (board_rect.centerx - antigrav_w // 2,
                     board_rect.bottom + int(0.3 * b)),
                    special_flags=pygame.BLEND_RGBA_ADD)

        # ── 보드 그림자 (지면 투영) ──
        shadow_poly = [
            (board_rect.left - nose_length // 2, board_rect.bottom + int(1.5 * b)),
            (board_rect.left + nose_length, board_rect.bottom + int(1.2 * b)),
            (board_rect.right - tail_length, board_rect.bottom + int(1.2 * b)),
            (board_rect.right + tail_length // 2, board_rect.bottom + int(1.5 * b)),
        ]
        pygame.draw.polygon(surface, (*palette["board_shadow"], 40), shadow_poly)

        # ── 보드 본체 ──
        board_poly = [
            (board_rect.left - nose_length, board_rect.centery + board_thickness // 2),
            (board_rect.left + nose_length // 2, board_rect.top),
            (board_rect.right - tail_length // 2, board_rect.top),
            (board_rect.right + tail_length, board_rect.centery + board_thickness // 2),
            (board_rect.right - tail_length // 2, board_rect.bottom),
            (board_rect.left + nose_length // 2, board_rect.bottom),
        ]
        # 바닥면 (깊이감)
        bottom_poly = [(x, y + 2) for x, y in board_poly]
        pygame.draw.polygon(surface, (18, 24, 45), bottom_poly)
        # 측면 (중간톤)
        side_poly = [(x, y + 1) for x, y in board_poly]
        pygame.draw.polygon(surface, (35, 45, 80), side_poly)
        # 상면 베이스
        pygame.draw.polygon(surface, palette["board_base"], board_poly)

        # 데크 하이라이트 (상면 광택)
        deck_poly = [
            (board_rect.left - nose_length // 2, board_rect.centery + board_thickness // 4),
            (board_rect.left + nose_length // 2, board_rect.top + 1),
            (board_rect.right - tail_length // 2, board_rect.top + 1),
            (board_rect.right + tail_length // 2, board_rect.centery + board_thickness // 4),
            (board_rect.right - tail_length // 2, board_rect.bottom - board_thickness // 3),
            (board_rect.left + nose_length // 2, board_rect.bottom - board_thickness // 3),
        ]
        pygame.draw.polygon(surface, palette["board_highlight"], deck_poly)

        # ── 데크 에너지 라인 (세로 3개 + 가로 2개) ──
        routing_start = board_rect.left + nose_length
        routing_end = board_rect.right - tail_length
        routing_len = routing_end - routing_start

        # 세로 구분선 (패널라인)
        for i in range(1, 4):
            lx = routing_start + routing_len * i // 4
            pygame.draw.line(surface, (30, 40, 65),
                           (lx, board_rect.top + 1),
                           (lx, board_rect.bottom - 1), 1)

        # 가로 라우팅
        for offset, color in ((0, palette["board_highlight"]),
                               (board_thickness // 2, palette["board_shadow"])):
            pygame.draw.line(surface, color,
                           (routing_start, board_rect.top + board_thickness // 2 - offset),
                           (routing_end, board_rect.top + board_thickness // 2 - offset), 1)

        # ── 데크 에너지 트레일 (중앙 발광 라인) ──
        trail_y = board_rect.centery
        trail_alpha = int(60 + 40 * pulse * move_pulse)
        trail_color = (*palette["board_glow"], trail_alpha)
        # 메인 트레일
        pygame.draw.line(surface, trail_color,
                        (routing_start + 4, trail_y),
                        (routing_end - 4, trail_y), 2)
        # 트레일 블룸
        trail_glow_w = routing_len
        trail_glow_h = int(b * 0.8)
        trail_glow = pygame.Surface((trail_glow_w, trail_glow_h), pygame.SRCALPHA)
        pygame.draw.ellipse(trail_glow,
                           (*palette["board_glow"], int(20 * pulse * move_pulse)),
                           trail_glow.get_rect())
        surface.blit(trail_glow,
                    (routing_start, trail_y - trail_glow_h // 2),
                    special_flags=pygame.BLEND_RGBA_ADD)

        # ── 보드 외곽 ──
        pygame.draw.polygon(surface, (30, 40, 68), board_poly, 1)
        # 상면 엣지 하이라이트
        pygame.draw.line(surface, (*palette["board_highlight"], 160),
                        board_poly[1], board_poly[2], 1)

        # ── 노즈/테일 LED ──
        for rx, phase_off in [(board_rect.left + nose_length // 2, 0),
                               (board_rect.right - tail_length // 2, math.pi)]:
            led_p = 0.5 + 0.5 * math.sin(t * 6.0 + phase_off)
            # LED 글로우
            led_glow = pygame.Surface((int(b * 0.8), int(b * 0.8)), pygame.SRCALPHA)
            pygame.draw.circle(led_glow,
                             (*palette["board_glow"], int(40 * led_p)),
                             (int(b * 0.4), int(b * 0.4)), int(b * 0.4))
            surface.blit(led_glow,
                        (rx - int(b * 0.4), board_rect.centery - int(b * 0.4)),
                        special_flags=pygame.BLEND_RGBA_ADD)
            # LED 코어
            pygame.draw.circle(surface, palette["board_highlight"],
                             (rx, board_rect.centery), 2)
            pygame.draw.circle(surface, (255, 255, 255),
                             (rx, board_rect.centery), 1)

        # ── 리벳 (데크 구분선 교차점) ──
        for i in range(1, 4):
            rx = routing_start + routing_len * i // 4
            pygame.draw.circle(surface, palette["board_highlight"],
                             (rx, board_rect.top + 1), 1)
            pygame.draw.circle(surface, palette["board_highlight"],
                             (rx, board_rect.bottom - 1), 1)

        # ── 보드 하부 글로우 (부유감 강조) ──
        under_glow_w = board_length
        under_glow_h = int(1.2 * b)
        under_glow = pygame.Surface((under_glow_w, under_glow_h), pygame.SRCALPHA)
        under_alpha = int(35 + 25 * pulse * move_pulse)
        pygame.draw.ellipse(under_glow,
                           (*palette["board_glow"], under_alpha),
                           under_glow.get_rect())
        surface.blit(under_glow,
                    (board_rect.centerx - under_glow_w // 2,
                     board_rect.bottom - int(0.2 * b)),
                    special_flags=pygame.BLEND_RGBA_ADD)

        # ── 스러스터 ──
        thruster_height = int(1.5 * b)
        thruster_width = int(1.6 * b)
        movement = min(1.0, abs(wave))
        base_strength = 0.3 + 0.4 * movement
        left_strength = min(1.0, base_strength + 0.3 * max(0.0, -wave))
        right_strength = min(1.0, base_strength + 0.3 * max(0.0, wave))

        # idle에서도 스러스터 최소 출력 유지 (부유 중이니까)
        left_strength = max(0.35, left_strength)
        right_strength = max(0.35, right_strength)

        left_x = cx - int(1.2 * b) - sway_offset - int(0.4 * b)
        right_x = cx + int(0.25 * b) - sway_offset + int(0.4 * b)

        self._draw_thruster(surface, left_x, board_rect.bottom,
                           thruster_width, thruster_height, left_strength,
                           palette, t, 0.0)
        self._draw_thruster(surface, right_x, board_rect.bottom,
                           thruster_width, thruster_height, right_strength,
                           palette, t, math.pi)

        self._last_board_rect = board_rect

    def _draw_thruster(self, surface, base_x, base_y,
                       width, height, strength, palette, t, phase_offset):
        b = self.block
        flicker = 0.5 + 0.5 * math.sin(t * 12.0 + phase_offset)
        intensity = max(0.3, min(1.0, strength * 0.5 + flicker * 0.5))

        flame_length = int(height * (1.4 + intensity * 0.8))
        flame_width = int(width * (0.85 + 0.25 * intensity))
        fs = pygame.Surface((flame_width * 2 + 4, flame_length + height + 4), pygame.SRCALPHA)

        ncx = flame_width + 2
        ncy = height // 2 + 2
        nr = pygame.Rect(ncx - width // 2, ncy - height // 2, width, height)

        # ── 노즐: 4단 (외곽글로우 → 아우터 → 미드 → 코어) ──
        # 외곽 글로우
        pygame.draw.ellipse(fs, (*palette["board_glow"], int(50 * intensity)),
                           nr.inflate(int(1.0 * b), int(0.6 * b)))
        # 아우터
        pygame.draw.ellipse(fs, (*palette["thruster_heat"], int(120 * intensity)),
                           nr.inflate(int(0.3 * b), int(0.2 * b)))
        # 미드
        pygame.draw.ellipse(fs, (*palette["thruster_heat"], int(180 * intensity)), nr)
        # 코어 (가장 밝은)
        pygame.draw.ellipse(fs, palette["thruster_core"],
                           nr.inflate(-max(1, width // 3), -max(1, height // 3)))
        # 노즐 하이라이트
        pygame.draw.ellipse(fs, (255, 255, 230, int(80 * intensity)),
                           nr.inflate(-max(2, width // 2), -max(2, height // 2)))

        # ── 화염: 외부 + 중간 + 내부 코어 ──
        crest = int(math.sin(t * 16.0 + phase_offset) * flame_width * 0.2)
        # 외부 화염
        outer = [
            (ncx - flame_width + 2, nr.bottom - 1),
            (ncx + crest, nr.bottom - 1 + flame_length),
            (ncx + flame_width - 2, nr.bottom - 1),
        ]
        pygame.draw.polygon(fs, (*palette["thruster_heat"], int(140 * intensity)), outer)

        # 중간 화염
        mid_w = flame_width * 2 // 3
        mid = [
            (ncx - mid_w, nr.bottom),
            (ncx + crest // 2, nr.bottom + int(flame_length * 0.85)),
            (ncx + mid_w, nr.bottom),
        ]
        pygame.draw.polygon(fs, (*palette["thruster_glow"], int(130 * intensity)), mid)

        # 내부 코어
        core_w = flame_width // 3
        core = [
            (ncx - core_w, nr.bottom + 1),
            (ncx + crest // 4, nr.bottom + int(flame_length * 0.65)),
            (ncx + core_w, nr.bottom + 1),
        ]
        pygame.draw.polygon(fs, (*palette["thruster_core"], int(200 * intensity)), core)

        # 코어 라인 (가장 밝은 중심선)
        core_tip = (ncx + crest // 4, nr.bottom + int(flame_length * 0.55))
        pygame.draw.line(fs, (255, 255, 240, int(220 * intensity)),
                        (ncx, nr.bottom), core_tip, 2)

        surface.blit(fs, (base_x - ncx, base_y - ncy),
                    special_flags=pygame.BLEND_ADD)
