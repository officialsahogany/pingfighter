"""
OptimusFistPart — 옵티머스 오른손 강철 전기 주먹 (기본 + 강화 버전).
원본: pingfighter.py _create_mecha_paddle_surface() 라인 29522~29750
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton
from typing import Optional

# 주먹은 오른팔(ORDER_R_ARM=25) 뒤, 방패(ORDER_SHIELD=27) 자리에 대응
ORDER_FIST = 26
SLOT_FIST = "fist"


class OptimusFistPart(BodyPart):
    """오른손 강철 전기 주먹. 기본/강화 두 가지 디자인 + 강화 조립 애니메이션."""

    def __init__(self):
        super().__init__(slot=SLOT_FIST, draw_order=ORDER_FIST,
                         joint_a="r_wrist", joint_b=None)

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        # 오른팔에서 계산한 손목 위치 사용 (스윙 반영)
        skin = getattr(self, '_skin_ref', None)
        wrist_pos = getattr(skin, '_r_wrist_pos', None)

        # 옵티머스 암 활성화 시 주먹 렌더링 스킵
        if wrist_pos is None:
            return

        wrist_int = wrist_pos
        fist_cx = wrist_int[0] + 8
        fist_cy = wrist_int[1] + 4

        # 게임 상태에서 강화 정보 가져오기
        gs = getattr(skin, '_game_state', None)
        upgraded = getattr(gs, 'mech_arm_upgrade_complete', False)
        anim_active = getattr(gs, 'mech_arm_upgrade_active', False)
        anim_timer = getattr(gs, 'mech_arm_upgrade_timer', 0)
        particles = getattr(gs, 'mech_arm_particles', [])

        now = pygame.time.get_ticks()
        anim_duration = 2000

        # 애니메이션 진행률
        anim_progress = 0.0
        if anim_active and anim_timer > 0:
            elapsed = now - anim_timer
            anim_progress = min(1.0, elapsed / anim_duration)
            if anim_progress >= 1.0:
                upgraded = True
                anim_active = False

        # ── 강화 조립 애니메이션 ──
        if anim_active and anim_progress > 0:
            self._draw_upgrade_animation(
                surface, fist_cx, fist_cy, anim_progress,
                phase, particles, now)

        # ── 주먹 본체 ──
        if upgraded:
            fist_w, fist_h = 44, 50
        else:
            fist_w, fist_h = 36, 40
        fist_rect = pygame.Rect(
            fist_cx - fist_w // 2, fist_cy - fist_h // 2,
            fist_w, fist_h)

        # 주먹 글로우
        fist_glow = pygame.Surface(
            (fist_w + 40, fist_h + 40), pygame.SRCALPHA)
        if upgraded:
            glow_alpha = int(60 + 50 * math.sin(phase * math.tau * 3))
            glow_color = (255, 150, 80, glow_alpha)
        else:
            glow_alpha = int(40 + 30 * math.sin(phase * math.tau * 3))
            glow_color = (100, 200, 255, glow_alpha)
        pygame.draw.ellipse(fist_glow, glow_color,
                            (0, 0, fist_w + 40, fist_h + 40))
        surface.blit(fist_glow, (fist_rect.left - 20, fist_rect.top - 20))

        # 주먹 베이스
        if upgraded:
            pygame.draw.ellipse(surface, (80, 60, 50), fist_rect)
            pygame.draw.ellipse(surface, (100, 80, 60),
                                fist_rect.inflate(-6, -6))
        else:
            pygame.draw.ellipse(surface, palette["hex_base"], fist_rect)
            pygame.draw.ellipse(surface, (60, 70, 85),
                                fist_rect.inflate(-6, -6))

        # ── 너클 플레이트 ──
        knuckle_y = fist_cy - (12 if upgraded else 10)
        offsets = [-12, -4, 4, 12] if upgraded else [-10, -3, 4, 11]
        for ki, kx_off in enumerate(offsets):
            kw = 12 if upgraded else 10
            kh = 18 if upgraded else 14
            kr = pygame.Rect(
                fist_cx + kx_off - kw // 2, knuckle_y - kh // 2, kw, kh)
            if upgraded:
                pygame.draw.rect(surface, (90, 70, 55), kr, border_radius=2)
                pygame.draw.rect(surface, (255, 180, 100), kr, 2,
                                 border_radius=2)
                led_p = int(200 + 55 * math.sin(
                    phase * math.tau * 5 + ki * 0.5))
                pygame.draw.circle(surface, (255, led_p, 50),
                                   (fist_cx + kx_off, knuckle_y - 3), 3)
            else:
                pygame.draw.rect(surface, palette["body"], kr, border_radius=3)
                pygame.draw.rect(surface, palette["accent"], kr, 1,
                                 border_radius=3)
                led_p = int(180 + 75 * math.sin(
                    phase * math.tau * 4 + ki * 0.5))
                pygame.draw.circle(surface, (led_p, led_p, 255),
                                   (fist_cx + kx_off, knuckle_y - 2), 2)

        # ── 전기/에너지 아크 ──
        if upgraded:
            arc_colors = [(255, 180, 80), (255, 140, 60), (255, 200, 120)]
            arc_count = 5
        else:
            arc_colors = [(150, 220, 255)] * 3
            arc_count = 3
        for arc_i in range(arc_count):
            arc_phase = (phase * math.tau * 5
                         + arc_i * (1.3 if upgraded else 2.1))
            arc_len = (16 if upgraded else 12) + 6 * math.sin(arc_phase)
            arc_angle = math.radians(
                -60 + arc_i * (72 if upgraded else 40)
                + math.sin(phase * 10) * 15)
            arc_start_dist = 22 if upgraded else 18
            arc_start = (
                fist_cx + int(math.cos(arc_angle) * arc_start_dist),
                fist_cy - 8 + int(math.sin(arc_angle) * 14))
            arc_end = (
                arc_start[0] + int(math.cos(arc_angle + 0.3) * arc_len),
                arc_start[1] + int(math.sin(arc_angle + 0.3) * arc_len))
            mid1 = (
                (arc_start[0] + arc_end[0]) // 2
                + int(math.sin(phase * 20 + arc_i) * 5),
                (arc_start[1] + arc_end[1]) // 2
                + int(math.cos(phase * 20 + arc_i) * 4))
            ac = arc_colors[arc_i % len(arc_colors)]
            w = 3 if upgraded else 2
            pygame.draw.line(surface, ac, arc_start, mid1, w)
            pygame.draw.line(surface, ac, mid1, arc_end, w)
            end_glow = (255, 220, 150) if upgraded else (200, 240, 255)
            pygame.draw.circle(surface, end_glow, arc_end,
                               4 if upgraded else 3)

        # ── 손등 에너지 코어 ──
        core_x = fist_cx
        core_y = fist_cy + (8 if upgraded else 6)
        core_r = 14 if upgraded else 10
        pygame.draw.circle(
            surface,
            (80, 60, 50) if upgraded else palette["hex_base"],
            (core_x, core_y), core_r)
        core_pulse = int(200 + 55 * math.sin(phase * math.tau * 2))
        if upgraded:
            pygame.draw.circle(surface, (255, core_pulse, 50),
                               (core_x, core_y), core_r - 2)
            pygame.draw.circle(surface, (255, 255, 200),
                               (core_x, core_y), 6)
            pygame.draw.circle(surface, (255, 180, 80),
                               (core_x, core_y), core_r + 2, 2)
        else:
            pygame.draw.circle(surface, (core_pulse, core_pulse, 255),
                               (core_x, core_y), 8)
            pygame.draw.circle(surface, (255, 255, 255),
                               (core_x, core_y), 4)

        # ── 손가락 관절 (주먹 쥔 상태) ──
        finger_spread = 8 if upgraded else 7
        finger_y_off = 22 if upgraded else 18
        for fi in range(4):
            fx = fist_cx - int(finger_spread * 1.5) + fi * finger_spread
            fy = fist_cy - finger_y_off
            fsz = 6 if upgraded else 5
            fc = (90, 70, 55) if upgraded else palette["hand"]
            fc2 = (70, 55, 45) if upgraded else palette["body"]
            pygame.draw.circle(surface, fc, (fx, fy), fsz)
            pygame.draw.circle(surface, fc2, (fx, fy), fsz - 1)

        # 엄지
        if upgraded:
            thumb_pts = [
                (fist_cx + 24, fist_cy - 5),
                (fist_cx + 32, fist_cy + 3),
                (fist_cx + 30, fist_cy + 14)]
            pygame.draw.polygon(surface, (90, 70, 55), thumb_pts)
            pygame.draw.polygon(surface, (255, 180, 100), thumb_pts, 2)
        else:
            thumb_pts = [
                (fist_cx + 20, fist_cy - 4),
                (fist_cx + 26, fist_cy + 2),
                (fist_cx + 24, fist_cy + 10)]
            pygame.draw.polygon(surface, palette["hand"], thumb_pts)
            pygame.draw.polygon(surface, palette["body"], thumb_pts, 2)

        # 주먹 외곽 LED 링
        if upgraded:
            pygame.draw.ellipse(surface, (255, 180, 100), fist_rect, 3)
        else:
            pygame.draw.ellipse(surface, palette["accent"], fist_rect, 2)

        # ── 스파크 파티클 ──
        spark_count = 6 if upgraded else 4
        for sp_i in range(spark_count):
            sp_phase = phase * 8 + sp_i * (1.0 if upgraded else 1.5)
            spark_dist = (24 if upgraded else 20) + sp_i * 3
            sp_x = fist_cx + int(math.cos(sp_phase) * spark_dist)
            sp_y = (fist_cy - 6
                    + int(math.sin(sp_phase * 1.3)
                          * (18 if upgraded else 15 + sp_i * 2)))
            sp_alpha = int(150 + 100 * math.sin(sp_phase * 2))
            spark_surf = pygame.Surface((8, 8), pygame.SRCALPHA)
            if upgraded:
                pygame.draw.circle(spark_surf, (255, 200, 100, sp_alpha),
                                   (4, 4), 3)
            else:
                pygame.draw.circle(spark_surf, (255, 255, 255, sp_alpha),
                                   (4, 4), 2)
            surface.blit(spark_surf, (sp_x - 4, sp_y - 4))

    def _draw_upgrade_animation(self, surface, fist_cx, fist_cy,
                                progress, phase, particles, now):
        """기계손 강화 조립 애니메이션."""
        # 배경 글로우
        glow_i = int(80 + 120 * math.sin(progress * math.pi))
        glow_sz = int(60 + 40 * progress)
        glow_s = pygame.Surface((glow_sz * 2, glow_sz * 2), pygame.SRCALPHA)
        pygame.draw.circle(glow_s, (100, 180, 255, glow_i),
                           (glow_sz, glow_sz), glow_sz)
        surface.blit(glow_s, (fist_cx - glow_sz, fist_cy - glow_sz))

        # 수렴 파티클
        particle_colors = [(80, 150, 255), (100, 220, 255), (200, 230, 255)]
        for p in particles:
            p_elapsed = now - p.get('spawn_time', now)
            p_life = min(1.0, p_elapsed / p.get('max_life', 1000))
            dist = p.get('dist', 40) * (1.0 - progress * 0.9)
            pa = p.get('angle', 0)
            px = fist_cx + int(math.cos(pa + progress * 2) * dist)
            py = fist_cy + int(math.sin(pa + progress * 2) * dist)
            psz = int(p.get('size', 3) * (1.0 - p_life * 0.5))
            if psz > 0:
                pc = particle_colors[p.get('color_idx', 0) % 3]
                pa2 = int(255 * (1.0 - p_life * 0.7))
                ps = pygame.Surface(
                    (psz * 2 + 4, psz * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(ps, (*pc, pa2),
                                   (psz + 2, psz + 2), psz)
                tail = int(8 * (1.0 - progress))
                if tail > 0:
                    tx = px + int(math.cos(pa) * tail)
                    ty = py + int(math.sin(pa) * tail)
                    pygame.draw.line(surface, (*pc, pa2 // 2),
                                     (px, py), (tx, ty), 2)
                surface.blit(ps, (px - psz - 2, py - psz - 2))

        # Phase 2-3: 조립 부품
        if progress > 0.3:
            assemble = (progress - 0.3) / 0.7
            for pi in range(4):
                pa = math.radians(pi * 90 + 45)
                pd = 50 * (1.0 - assemble)
                ppx = fist_cx + int(math.cos(pa) * pd)
                ppy = fist_cy + int(math.sin(pa) * pd)
                psz = int(8 + 4 * assemble)
                pal = int(200 * assemble)
                ps = pygame.Surface((psz * 2, psz * 2), pygame.SRCALPHA)
                pygame.draw.rect(ps, (60, 80, 120, pal),
                                 (0, 0, psz * 2, psz * 2), border_radius=3)
                pygame.draw.rect(ps, (100, 180, 255, pal),
                                 (0, 0, psz * 2, psz * 2), 2, border_radius=3)
                surface.blit(ps, (ppx - psz, ppy - psz))

        # Phase 3: 완성 에너지 폭발
        if progress > 0.7:
            burst = (progress - 0.7) / 0.3
            br = int(20 + 60 * burst)
            ba = int(180 * (1.0 - burst))
            bs = pygame.Surface((br * 2, br * 2), pygame.SRCALPHA)
            pygame.draw.circle(bs, (150, 220, 255, ba), (br, br), br, 3)
            pygame.draw.circle(bs, (255, 255, 255, ba // 2),
                               (br, br), int(br * 0.7), 2)
            surface.blit(bs, (fist_cx - br, fist_cy - br))
            # 전기 스파크
            for si in range(8):
                sa = math.radians(si * 45 + phase * 180)
                sl = int(30 * burst)
                ss = (fist_cx + int(math.cos(sa) * 15),
                      fist_cy + int(math.sin(sa) * 15))
                se = (fist_cx + int(math.cos(sa) * (15 + sl)),
                      fist_cy + int(math.sin(sa) * (15 + sl)))
                sm = ((ss[0] + se[0]) // 2
                      + int(math.sin(phase * 30 + si) * 5),
                      (ss[1] + se[1]) // 2
                      + int(math.cos(phase * 30 + si) * 5))
                pygame.draw.line(surface, (200, 240, 255), ss, sm, 2)
                pygame.draw.line(surface, (255, 255, 255), sm, se, 2)
