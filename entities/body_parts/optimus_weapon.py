"""
OptimusWeaponPart — 옵티머스 왼손 사이버 탁구채 (기본 + 궁극의 강화 버전).
원본: pingfighter.py _create_mecha_paddle_surface() 라인 29285~29520
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_WEAPON, SLOT_WEAPON
from typing import Optional


class OptimusWeaponPart(BodyPart):
    """왼손에 들린 사이버 전자 탁구채. 기본/궁극 두 가지 디자인."""

    def __init__(self):
        super().__init__(slot=SLOT_WEAPON, draw_order=ORDER_WEAPON,
                         joint_a="l_wrist", joint_b=None)

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        # 왼팔 파츠에서 계산한 손목 위치 사용 (스윙 반영)
        skin = getattr(self, '_skin_ref', None)
        wrist_int = getattr(skin, '_l_wrist_pos', None)
        if wrist_int is None:
            wrist_int = joint_a.world_int()

        # 게임 상태에서 강화 정보 가져오기
        gs = getattr(skin, '_game_state', None)
        paddle_upgraded = getattr(gs, 'paddle_upgrade_complete', False)
        paddle_anim_active = getattr(gs, 'paddle_upgrade_active', False)
        paddle_anim_timer = getattr(gs, 'paddle_upgrade_timer', 0)
        paddle_particles = getattr(gs, 'paddle_upgrade_particles', [])

        now = pygame.time.get_ticks()
        anim_duration = 2000

        # 애니메이션 진행률
        anim_progress = 0.0
        if paddle_anim_active and paddle_anim_timer > 0:
            elapsed = now - paddle_anim_timer
            anim_progress = min(1.0, elapsed / anim_duration)
            if anim_progress >= 1.0:
                paddle_upgraded = True
                paddle_anim_active = False

        # ── 탁구채 서피스 ──
        paddle_surf_size = 190 if paddle_upgraded else 140
        paddle_surface = pygame.Surface(
            (paddle_surf_size, paddle_surf_size), pygame.SRCALPHA)
        ps_cx, ps_cy = paddle_surf_size // 2, paddle_surf_size // 2

        # 라켓 면 크기
        if paddle_upgraded:
            paddle_w, paddle_h = 88, 99
        else:
            paddle_w, paddle_h = 66, 77
        paddle_rect = pygame.Rect(
            ps_cx - paddle_w // 2, ps_cy - 8, paddle_w, paddle_h)

        # ── 손잡이 (그립) ──
        grip_offset_y = -44 if paddle_upgraded else -40
        if paddle_upgraded:
            pygame.draw.rect(paddle_surface, (100, 50, 30),
                             (ps_cx - 9, ps_cy + grip_offset_y - 6, 18, 40),
                             border_radius=5)
            pygame.draw.rect(paddle_surface, (255, 180, 80),
                             (ps_cx - 7, ps_cy + grip_offset_y - 4, 14, 36),
                             border_radius=4)
            pygame.draw.rect(paddle_surface, (255, 220, 120),
                             (ps_cx - 5, ps_cy + grip_offset_y, 10, 28),
                             1, border_radius=3)
            # 그립 보석 장식
            pygame.draw.circle(paddle_surface, (255, 80, 80),
                               (ps_cx, ps_cy + grip_offset_y + 16), 6)
            pygame.draw.circle(paddle_surface, (255, 200, 200),
                               (ps_cx, ps_cy + grip_offset_y + 16), 3)
        else:
            pygame.draw.rect(paddle_surface, palette["grip"],
                             (ps_cx - 7, ps_cy + grip_offset_y - 4, 14, 32),
                             border_radius=4)
            pygame.draw.rect(paddle_surface, palette["grip_line"],
                             (ps_cx - 5, ps_cy + grip_offset_y, 10, 24),
                             1, border_radius=3)

        # ── 라켓 면 ──
        if paddle_upgraded:
            self._draw_upgraded_paddle(paddle_surface, paddle_rect, phase)
        else:
            self._draw_basic_paddle(paddle_surface, paddle_rect, palette, phase)

        # 145도 오른쪽(시계방향) 회전
        rotated_paddle = pygame.transform.rotate(paddle_surface, -145)

        # 블릿 위치 (손목 기준)
        paddle_blit_x = (wrist_int[0] - rotated_paddle.get_width() // 2
                         - (22 if paddle_upgraded else 17))
        paddle_blit_y = (wrist_int[1] - rotated_paddle.get_height() // 2
                         - (11 if paddle_upgraded else 6))

        # ── 강화 애니메이션 ──
        if paddle_anim_active and anim_progress > 0:
            self._draw_upgrade_animation(
                surface, paddle_blit_x, paddle_blit_y,
                rotated_paddle, anim_progress, phase,
                paddle_particles, now)

        # 탁구채 블릿
        surface.blit(rotated_paddle, (paddle_blit_x, paddle_blit_y))

    def _draw_basic_paddle(self, surf: pygame.Surface,
                           rect: pygame.Rect, palette: dict, phase: float):
        """기본 사이버 탁구채."""
        # 외곽 프레임
        pygame.draw.rect(surf, palette["hex_base"], rect, border_radius=6)
        # 메인 면
        inner_rect = rect.inflate(-8, -8)
        pygame.draw.rect(surf, palette["helmet"], inner_rect, border_radius=4)
        # 사이버 그리드
        grid_color = (*palette["accent"], 120)
        for gy in range(inner_rect.top + 6, inner_rect.bottom - 4, 10):
            pygame.draw.line(surf, grid_color,
                             (inner_rect.left + 4, gy),
                             (inner_rect.right - 4, gy), 1)
        for gx in range(inner_rect.left + 6, inner_rect.right - 4, 10):
            pygame.draw.line(surf, grid_color,
                             (gx, inner_rect.top + 4),
                             (gx, inner_rect.bottom - 4), 1)
        # 중앙 에너지 코어
        ccx, ccy = rect.centerx, rect.centery
        pygame.draw.circle(surf, palette["hex_base"], (ccx, ccy), 12)
        pygame.draw.circle(surf, palette["accent"], (ccx, ccy), 10)
        pygame.draw.circle(surf, palette["hex_core"], (ccx, ccy), 6)
        pygame.draw.circle(surf, palette["visor_highlight"], (ccx, ccy), 3)
        # 외곽 LED 테두리
        pygame.draw.rect(surf, palette["accent"], rect, 3, border_radius=6)
        # 모서리 LED
        for corner in [(rect.left + 4, rect.top + 4),
                       (rect.right - 4, rect.top + 4),
                       (rect.left + 4, rect.bottom - 4),
                       (rect.right - 4, rect.bottom - 4)]:
            pygame.draw.circle(surf, palette["visor_highlight"], corner, 3)

    def _draw_upgraded_paddle(self, surf: pygame.Surface,
                              rect: pygame.Rect, phase: float):
        """궁극의 탁구채 (강화 완료)."""
        # 외곽 프레임 (다크 레드-골드)
        pygame.draw.rect(surf, (80, 30, 20), rect, border_radius=8)
        pygame.draw.rect(surf, (60, 20, 15),
                         rect.inflate(-4, -4), border_radius=6)
        # 메인 면
        inner_rect = rect.inflate(-10, -10)
        pygame.draw.rect(surf, (120, 40, 30), inner_rect, border_radius=5)
        # 에너지 패턴 (십자 + 대각선)
        energy_color = (255, 200, 100, 180)
        pygame.draw.line(surf, energy_color,
                         (inner_rect.centerx, inner_rect.top + 4),
                         (inner_rect.centerx, inner_rect.bottom - 4), 2)
        pygame.draw.line(surf, energy_color,
                         (inner_rect.left + 4, inner_rect.centery),
                         (inner_rect.right - 4, inner_rect.centery), 2)
        pygame.draw.line(surf, energy_color,
                         (inner_rect.left + 8, inner_rect.top + 8),
                         (inner_rect.right - 8, inner_rect.bottom - 8), 2)
        pygame.draw.line(surf, energy_color,
                         (inner_rect.right - 8, inner_rect.top + 8),
                         (inner_rect.left + 8, inner_rect.bottom - 8), 2)
        # 중앙 궁극 에너지 코어
        ccx, ccy = rect.centerx, rect.centery
        for ring_i in range(3):
            ring_r = 18 - ring_i * 4
            ring_alpha = int(80 + 60 * math.sin(
                phase * math.tau * 3 + ring_i))
            ring_surf = pygame.Surface(
                (ring_r * 2 + 4, ring_r * 2 + 4), pygame.SRCALPHA)
            pygame.draw.circle(ring_surf, (255, 180, 80, ring_alpha),
                               (ring_r + 2, ring_r + 2), ring_r, 2)
            surf.blit(ring_surf, (ccx - ring_r - 2, ccy - ring_r - 2))
        pygame.draw.circle(surf, (80, 30, 20), (ccx, ccy), 16)
        core_pulse = int(200 + 55 * math.sin(phase * math.tau * 2))
        pygame.draw.circle(surf, (255, core_pulse, 50), (ccx, ccy), 14)
        pygame.draw.circle(surf, (255, 220, 150), (ccx, ccy), 10)
        pygame.draw.circle(surf, (255, 255, 230), (ccx, ccy), 5)
        # 외곽 LED
        pygame.draw.rect(surf, (255, 200, 100), rect, 4, border_radius=8)
        # 모서리 에너지 포인트
        for ci, (ox, oy) in enumerate([
            (6, 6), (-6, 6), (6, -6), (-6, -6)
        ]):
            cx_pos = rect.left + 6 if ox > 0 else rect.right - 6
            cy_pos = rect.top + 6 if oy > 0 else rect.bottom - 6
            cp = int(200 + 55 * math.sin(phase * math.tau * 4 + ci * 0.5))
            pygame.draw.circle(surf, (255, cp, 80), (cx_pos, cy_pos), 5)
            pygame.draw.circle(surf, (255, 255, 200), (cx_pos, cy_pos), 2)
        # 에너지 아크
        for arc_i in range(4):
            arc_angle = math.radians(arc_i * 90 + 45 + phase * 60)
            arc_start = (
                ccx + int(math.cos(arc_angle) * 12),
                ccy + int(math.sin(arc_angle) * 12))
            arc_len = 10 + 5 * math.sin(phase * math.tau * 4 + arc_i)
            arc_end = (
                ccx + int(math.cos(arc_angle) * (12 + arc_len)),
                ccy + int(math.sin(arc_angle) * (12 + arc_len)))
            pygame.draw.line(surf, (255, 220, 150), arc_start, arc_end, 2)

    def _draw_upgrade_animation(self, surface, blit_x, blit_y,
                                rotated_paddle, progress, phase,
                                particles, now):
        """탁구채 강화 조립 애니메이션."""
        paddle_cx = blit_x + rotated_paddle.get_width() // 2
        paddle_cy = blit_y + rotated_paddle.get_height() // 2

        # 배경 글로우
        glow_intensity = int(100 + 150 * math.sin(progress * math.pi))
        glow_size = int(70 + 50 * progress)
        glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (255, 150, 80, glow_intensity),
                           (glow_size, glow_size), glow_size)
        surface.blit(glow_surf, (paddle_cx - glow_size, paddle_cy - glow_size))

        # 수렴 파티클
        particle_colors = [
            (255, 80, 80), (255, 160, 80), (255, 220, 120), (255, 255, 200)]
        for p in particles:
            p_elapsed = now - p.get('spawn_time', now)
            p_life_ratio = min(1.0, p_elapsed / p.get('max_life', 1000))
            current_dist = p.get('dist', 40) * (1.0 - progress * 0.9)
            p_angle = p.get('angle', 0)
            px = paddle_cx + int(math.cos(p_angle + progress * 3) * current_dist)
            py = paddle_cy + int(math.sin(p_angle + progress * 3) * current_dist)
            p_size = int(p.get('size', 3) * (1.0 - p_life_ratio * 0.5))
            if p_size > 0:
                p_color = particle_colors[p.get('color_idx', 0) % len(particle_colors)]
                p_alpha = int(255 * (1.0 - p_life_ratio * 0.6))
                p_surf = pygame.Surface(
                    (p_size * 2 + 4, p_size * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(p_surf, (*p_color, p_alpha),
                                   (p_size + 2, p_size + 2), p_size)
                tail_len = int(10 * (1.0 - progress))
                if tail_len > 0:
                    tail_x = px + int(math.cos(p_angle) * tail_len)
                    tail_y = py + int(math.sin(p_angle) * tail_len)
                    pygame.draw.line(surface, (*p_color, p_alpha // 2),
                                     (px, py), (tail_x, tail_y), 2)
                surface.blit(p_surf, (px - p_size - 2, py - p_size - 2))

        # Phase 2-3: 조립 중인 부품
        if progress > 0.3:
            assemble = (progress - 0.3) / 0.7
            for plate_idx in range(6):
                plate_angle = math.radians(plate_idx * 60 + 30)
                plate_dist = 60 * (1.0 - assemble)
                plate_x = paddle_cx + int(math.cos(plate_angle) * plate_dist)
                plate_y = paddle_cy + int(math.sin(plate_angle) * plate_dist)
                plate_size = int(10 + 6 * assemble)
                plate_alpha = int(220 * assemble)
                plate_surf = pygame.Surface(
                    (plate_size * 2, plate_size * 2), pygame.SRCALPHA)
                pygame.draw.rect(plate_surf, (120, 50, 30, plate_alpha),
                                 (0, 0, plate_size * 2, plate_size * 2),
                                 border_radius=4)
                pygame.draw.rect(plate_surf, (255, 180, 80, plate_alpha),
                                 (0, 0, plate_size * 2, plate_size * 2),
                                 2, border_radius=4)
                surface.blit(plate_surf,
                             (plate_x - plate_size, plate_y - plate_size))

        # Phase 3: 완성 에너지 폭발
        if progress > 0.7:
            burst = (progress - 0.7) / 0.3
            burst_r = int(25 + 70 * burst)
            burst_alpha = int(200 * (1.0 - burst))
            burst_surf = pygame.Surface(
                (burst_r * 2, burst_r * 2), pygame.SRCALPHA)
            pygame.draw.circle(burst_surf, (255, 180, 80, burst_alpha),
                               (burst_r, burst_r), burst_r, 4)
            pygame.draw.circle(burst_surf, (255, 255, 200, burst_alpha // 2),
                               (burst_r, burst_r), int(burst_r * 0.7), 3)
            surface.blit(burst_surf,
                         (paddle_cx - burst_r, paddle_cy - burst_r))
            # 방사형 스파크
            for sp_i in range(10):
                sp_angle = math.radians(sp_i * 36 + phase * 200)
                sp_len = int(35 * burst)
                sp_start = (
                    paddle_cx + int(math.cos(sp_angle) * 18),
                    paddle_cy + int(math.sin(sp_angle) * 18))
                sp_end = (
                    paddle_cx + int(math.cos(sp_angle) * (18 + sp_len)),
                    paddle_cy + int(math.sin(sp_angle) * (18 + sp_len)))
                sp_mid = (
                    (sp_start[0] + sp_end[0]) // 2
                    + int(math.sin(phase * 40 + sp_i) * 6),
                    (sp_start[1] + sp_end[1]) // 2
                    + int(math.cos(phase * 40 + sp_i) * 6))
                pygame.draw.line(surface, (255, 200, 120), sp_start, sp_mid, 2)
                pygame.draw.line(surface, (255, 255, 200), sp_mid, sp_end, 2)
