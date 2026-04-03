"""
패시브 아이템 연동 헬멧/페이스 파츠 — 가시투구, 방탄모자, 초월자의관, 오딘의눈.

아이템 획득 시 skin.set_part()로 교체하여 외형을 변경한다.
"""

import math
import pygame
from entities.player_skeleton import (
    BodyPart, Joint, Skeleton,
    ORDER_HEAD, SLOT_HEAD, ORDER_FACE, SLOT_FACE,
)
from typing import Optional


class SpikedHelmetPart(BodyPart):
    """가시투구 (spiked_helmet).

    짙은 강철색 투구 + 상단/측면 가시 5개.
    효과: 공 넉백 저항 증가.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_HEAD,
            draw_order=ORDER_HEAD,
            joint_a="head",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        hx, hy = joint_a.world_int()

        # ── 투구 본체 (강철색) ──
        helmet_w = int(2.8 * b)
        helmet_h = int(2.4 * b)
        helmet_rect = pygame.Rect(
            hx - helmet_w // 2,
            hy - helmet_h // 2 - int(0.3 * b),
            helmet_w, helmet_h,
        )
        # 베이스
        pygame.draw.ellipse(surface, (80, 90, 105), helmet_rect)
        # 내부 밝은 면
        inner = helmet_rect.inflate(-int(0.5 * b), -int(0.5 * b))
        pygame.draw.ellipse(surface, (100, 115, 130), inner)

        # ── 가시 5개 (상단 부채꼴) ──
        spike_colors = [(140, 150, 160), (160, 170, 180)]
        num_spikes = 5
        for i in range(num_spikes):
            angle = math.radians(-140 + i * 70)  # -140° ~ +140° 범위
            base_x = hx + int(math.cos(angle) * helmet_w * 0.42)
            base_y = helmet_rect.top + int(0.3 * b) + int(math.sin(angle) * helmet_h * 0.15)

            tip_x = hx + int(math.cos(angle) * (helmet_w * 0.42 + int(1.0 * b)))
            tip_y = base_y - int(1.2 * b)

            # 가시 삼각형
            spike_w = max(2, int(0.3 * b))
            tri = [
                (base_x - spike_w, base_y),
                (tip_x, tip_y),
                (base_x + spike_w, base_y),
            ]
            pygame.draw.polygon(surface, spike_colors[i % 2], tri)
            # 가시 하이라이트
            pygame.draw.line(surface, (200, 210, 220), (base_x, base_y), (tip_x, tip_y), 1)

        # ── T자 바이저 ──
        visor_y = helmet_rect.centery + int(0.3 * b)
        visor_w = int(1.4 * b)
        pygame.draw.line(
            surface, (200, 80, 60),
            (hx - visor_w // 2, visor_y),
            (hx + visor_w // 2, visor_y), 2,
        )
        # 코 가드
        pygame.draw.line(
            surface, (90, 100, 110),
            (hx, visor_y - int(0.3 * b)),
            (hx, visor_y + int(0.4 * b)), 2,
        )

        # ── 테두리 ──
        pygame.draw.ellipse(surface, (60, 70, 80), helmet_rect, 1)


class BulletproofHatPart(BodyPart):
    """방탄모자 (bulletproof_hat).

    군용 네이비 방탄 헬멧 + 고글 + NVG 마운트.
    효과: 투사체 데미지 감소.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_HEAD,
            draw_order=ORDER_HEAD,
            joint_a="head",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        hx, hy = joint_a.world_int()

        # ── 헬멧 본체 (네이비/올리브) ──
        helmet_w = int(2.9 * b)
        helmet_h = int(2.0 * b)
        helmet_rect = pygame.Rect(
            hx - helmet_w // 2,
            hy - helmet_h // 2 - int(0.5 * b),
            helmet_w, helmet_h,
        )
        pygame.draw.ellipse(surface, (55, 75, 55), helmet_rect)  # 올리브드랩
        # 밝은 면
        highlight = helmet_rect.inflate(-int(0.8 * b), -int(0.7 * b))
        highlight.move_ip(-2, -2)
        pygame.draw.ellipse(surface, (75, 95, 70), highlight, 1)

        # ── 헬멧 밴드 (수평) ──
        band_y = helmet_rect.centery - int(0.1 * b)
        pygame.draw.line(
            surface, (40, 55, 40),
            (helmet_rect.left + int(0.3 * b), band_y),
            (helmet_rect.right - int(0.3 * b), band_y), 2,
        )

        # ── 고글 (원형 2개) ──
        goggle_y = helmet_rect.centery + int(0.3 * b)
        goggle_r = max(3, int(0.45 * b))
        for gx_off in [-int(0.55 * b), int(0.55 * b)]:
            gx = hx + gx_off
            # 고글 프레임
            pygame.draw.circle(surface, (30, 35, 30), (gx, goggle_y), goggle_r + 1)
            # 렌즈 (녹색 야시경 느낌)
            pygame.draw.circle(surface, (100, 180, 80), (gx, goggle_y), goggle_r)
            # 렌즈 하이라이트
            pygame.draw.circle(surface, (160, 220, 140), (gx - 1, goggle_y - 1), max(1, goggle_r // 2))
        # 고글 브릿지
        pygame.draw.line(
            surface, (30, 35, 30),
            (hx - int(0.55 * b) + goggle_r, goggle_y),
            (hx + int(0.55 * b) - goggle_r, goggle_y), 2,
        )

        # ── 페이스 (헬멧 아래) ──
        face_w = int(1.6 * b)
        face_h = int(1.0 * b)
        face_rect = pygame.Rect(
            hx - face_w // 2,
            helmet_rect.bottom - int(0.2 * b),
            face_w, face_h,
        )
        pygame.draw.ellipse(surface, palette.get("face", (212, 196, 176)), face_rect)

        # ── NVG 마운트 (상단 중앙) ──
        nvg_rect = pygame.Rect(hx - int(0.3 * b), helmet_rect.top - int(0.2 * b), int(0.6 * b), int(0.5 * b))
        pygame.draw.rect(surface, (40, 50, 40), nvg_rect, border_radius=1)
        pygame.draw.rect(surface, (60, 80, 60), nvg_rect.inflate(-2, -2), border_radius=1)


class TranscendentCrownPart(BodyPart):
    """초월자의 관 (transcendent_crown).

    전설 머리장비: 황금-보라빛 왕관 + 부유하는 보석 + 신성한 후광.
    효과: 모든 투자된 스킬 레벨 +N.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_HEAD,
            draw_order=ORDER_HEAD,
            joint_a="head",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        hx, hy = joint_a.world_int()

        # ── 신성한 후광 (왕관 뒤쪽 발광 원) ──
        halo_r = int(2.0 * b)
        halo_cy = hy - int(0.5 * b)
        halo_surf = pygame.Surface((halo_r * 2 + 4, halo_r * 2 + 4), pygame.SRCALPHA)
        halo_pulse = 0.6 + 0.4 * math.sin(phase * math.tau * 1.5)
        halo_alpha = int(35 * halo_pulse)
        pygame.draw.ellipse(
            halo_surf, (220, 180, 255, halo_alpha),
            (0, 0, halo_surf.get_width(), halo_surf.get_height()),
        )
        surface.blit(
            halo_surf,
            (hx - halo_surf.get_width() // 2, halo_cy - halo_surf.get_height() // 2),
            special_flags=pygame.BLEND_RGBA_ADD,
        )

        # ── 왕관 베이스 (황금 밴드) ──
        crown_w = int(2.6 * b)
        crown_h = int(0.8 * b)
        crown_y = hy - int(1.4 * b)
        crown_rect = pygame.Rect(hx - crown_w // 2, crown_y, crown_w, crown_h)

        # 그림자
        pygame.draw.rect(surface, (120, 80, 20), crown_rect.move(1, 1), border_radius=2)
        # 황금 베이스
        pygame.draw.rect(surface, (218, 175, 60), crown_rect, border_radius=2)
        # 밝은 내부
        pygame.draw.rect(surface, (245, 210, 90), crown_rect.inflate(-3, -3), border_radius=1)

        # ── 왕관 돌기 5개 (상단 삼각형) ──
        num_prongs = 5
        prong_h = int(1.0 * b)
        for i in range(num_prongs):
            px = crown_rect.left + int((i + 0.5) * crown_w / num_prongs)
            pw = max(2, int(0.3 * b))
            tri = [
                (px - pw, crown_rect.top),
                (px, crown_rect.top - prong_h),
                (px + pw, crown_rect.top),
            ]
            # 돌기 본체
            pygame.draw.polygon(surface, (218, 175, 60), tri)
            # 하이라이트
            pygame.draw.line(surface, (255, 230, 130), (px, crown_rect.top - prong_h), (px - pw, crown_rect.top), 1)

        # ── 중앙 보석 (보라빛 다이아몬드) ──
        gem_cx = hx
        gem_cy = crown_rect.centery
        gem_r = max(3, int(0.4 * b))
        # 보석 그림자
        pygame.draw.circle(surface, (80, 30, 100), (gem_cx + 1, gem_cy + 1), gem_r)
        # 보석 본체 (보라색)
        pygame.draw.circle(surface, (160, 80, 220), (gem_cx, gem_cy), gem_r)
        # 보석 코어 (밝은 보라)
        gem_pulse = int(40 * math.sin(phase * math.tau * 2.5))
        core_color = (min(255, 200 + gem_pulse), min(255, 140 + gem_pulse), 255)
        pygame.draw.circle(surface, core_color, (gem_cx, gem_cy), max(1, gem_r - 2))
        # 보석 하이라이트
        pygame.draw.circle(surface, (255, 220, 255), (gem_cx - 1, gem_cy - 1), max(1, gem_r // 3))

        # ── 좌우 보석 (작은 보라색 원) ──
        for sx in [-int(0.8 * b), int(0.8 * b)]:
            sgx = hx + sx
            small_r = max(2, int(0.25 * b))
            pygame.draw.circle(surface, (140, 60, 180), (sgx, gem_cy), small_r)
            pygame.draw.circle(surface, (180, 120, 240), (sgx, gem_cy), max(1, small_r - 1))

        # ── 페이스 (왕관 아래) ──
        face_w = int(1.8 * b)
        face_h = int(1.2 * b)
        face_rect = pygame.Rect(
            hx - face_w // 2,
            crown_rect.bottom + int(0.1 * b),
            face_w, face_h,
        )
        pygame.draw.ellipse(surface, palette.get("face", (212, 196, 176)), face_rect)

        # ── 바이저 (얼굴 위 빛나는 눈) ──
        visor_w = int(1.4 * b)
        visor_h = int(0.4 * b)
        visor_rect = pygame.Rect(
            hx - visor_w // 2,
            face_rect.top + int(0.2 * b),
            visor_w, visor_h,
        )
        visor_pulse = 0.7 + 0.3 * math.sin(phase * math.tau * 2)
        visor_alpha = int(180 * visor_pulse)
        pygame.draw.ellipse(surface, (200, 160, 255), visor_rect)
        pygame.draw.ellipse(surface, (230, 200, 255), visor_rect.inflate(-3, -2))

        # 바이저 글로우
        glow_surf = pygame.Surface((visor_w + b, visor_h + b), pygame.SRCALPHA)
        pygame.draw.ellipse(
            glow_surf, (180, 140, 255, int(30 * visor_pulse)),
            (0, 0, glow_surf.get_width(), glow_surf.get_height()),
        )
        surface.blit(
            glow_surf,
            (visor_rect.centerx - glow_surf.get_width() // 2,
             visor_rect.centery - glow_surf.get_height() // 2),
            special_flags=pygame.BLEND_RGBA_ADD,
        )

        # ── 왕관 테두리 ──
        pygame.draw.rect(surface, (160, 120, 30), crown_rect, 1, border_radius=2)


class OdinsEyePart(BodyPart):
    """오딘의 눈 (odins_eye).

    전설 페이스 파츠: 이마 위에 빛나는 제3의 눈 + 룬 문양 오버레이.
    효과: 부활 확률.
    SLOT_FACE에 장착되어 기존 머리 파츠와 공존 가능.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_FACE,
            draw_order=ORDER_FACE,
            joint_a="head",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        hx, hy = joint_a.world_int()

        # ── 제3의 눈 (이마 위치) ──
        eye_cx = hx
        eye_cy = hy - int(0.6 * b)
        eye_w = int(1.2 * b)
        eye_h = int(0.7 * b)

        # 눈 외곽 글로우
        glow_r = int(1.0 * b)
        glow_pulse = 0.5 + 0.5 * math.sin(phase * math.tau * 2)
        glow_surf = pygame.Surface((glow_r * 2 + 4, glow_r * 2 + 4), pygame.SRCALPHA)
        glow_alpha = int(50 * glow_pulse)
        pygame.draw.ellipse(
            glow_surf, (100, 180, 255, glow_alpha),
            (0, 0, glow_surf.get_width(), glow_surf.get_height()),
        )
        surface.blit(
            glow_surf,
            (eye_cx - glow_surf.get_width() // 2, eye_cy - glow_surf.get_height() // 2),
            special_flags=pygame.BLEND_RGBA_ADD,
        )

        # 눈 테두리 (다이아몬드형)
        eye_points = [
            (eye_cx - eye_w // 2, eye_cy),      # 왼쪽
            (eye_cx, eye_cy - eye_h // 2),       # 위
            (eye_cx + eye_w // 2, eye_cy),       # 오른쪽
            (eye_cx, eye_cy + eye_h // 2),       # 아래
        ]
        # 어두운 테두리
        pygame.draw.polygon(surface, (30, 60, 100), eye_points)
        # 밝은 내부
        inner_scale = 0.75
        inner_points = [
            (eye_cx - int(eye_w * inner_scale / 2), eye_cy),
            (eye_cx, eye_cy - int(eye_h * inner_scale / 2)),
            (eye_cx + int(eye_w * inner_scale / 2), eye_cy),
            (eye_cx, eye_cy + int(eye_h * inner_scale / 2)),
        ]
        pygame.draw.polygon(surface, (60, 120, 200), inner_points)

        # 동공 (빛나는 원)
        pupil_r = max(2, int(0.2 * b))
        pupil_pulse = int(30 * math.sin(phase * math.tau * 3))
        pupil_color = (min(255, 140 + pupil_pulse), min(255, 200 + pupil_pulse), 255)
        pygame.draw.circle(surface, pupil_color, (eye_cx, eye_cy), pupil_r)
        # 동공 코어
        pygame.draw.circle(surface, (220, 240, 255), (eye_cx, eye_cy), max(1, pupil_r - 1))

        # ── 룬 문양 (눈 양옆에 작은 선) ──
        rune_pulse = int(20 * math.sin(phase * math.tau * 1.5 + 0.5))
        rune_color = (min(255, 100 + rune_pulse), min(255, 160 + rune_pulse), min(255, 230 + rune_pulse))
        rune_len = int(0.5 * b)
        # 왼쪽 룬
        lx = eye_cx - eye_w // 2 - int(0.2 * b)
        pygame.draw.line(surface, rune_color, (lx, eye_cy - rune_len // 2), (lx, eye_cy + rune_len // 2), 1)
        pygame.draw.line(surface, rune_color, (lx - 2, eye_cy), (lx + 2, eye_cy), 1)
        # 오른쪽 룬
        rx = eye_cx + eye_w // 2 + int(0.2 * b)
        pygame.draw.line(surface, rune_color, (rx, eye_cy - rune_len // 2), (rx, eye_cy + rune_len // 2), 1)
        pygame.draw.line(surface, rune_color, (rx - 2, eye_cy), (rx + 2, eye_cy), 1)

        # ── 아래로 내려오는 빛 줄기 (눈에서 발산) ──
        beam_alpha = int(25 * glow_pulse)
        beam_surf = pygame.Surface((int(0.4 * b), int(1.5 * b)), pygame.SRCALPHA)
        pygame.draw.rect(
            beam_surf, (100, 180, 255, beam_alpha),
            (0, 0, beam_surf.get_width(), beam_surf.get_height()),
        )
        surface.blit(
            beam_surf,
            (eye_cx - beam_surf.get_width() // 2, eye_cy + eye_h // 2),
            special_flags=pygame.BLEND_RGBA_ADD,
        )


class DowsingGogglesPart(BodyPart):
    """다우징 고글 (dowsing_goggles).

    청록색 탐지 고글 + 안테나 + 렌즈 빛남.
    효과: 퍽 선택지 증가.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_HEAD,
            draw_order=ORDER_HEAD,
            joint_a="head",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        hx, hy = joint_a.world_int()

        # ── 고글 밴드 (머리 둘레) ──
        band_w = int(2.8 * b)
        band_h = int(1.2 * b)
        band_rect = pygame.Rect(
            hx - band_w // 2,
            hy - int(0.2 * b),
            band_w, band_h,
        )
        pygame.draw.ellipse(surface, (40, 50, 60), band_rect)
        pygame.draw.ellipse(surface, (60, 70, 80), band_rect, 1)

        # ── 렌즈 2개 (청록색) ──
        goggle_y = hy + int(0.3 * b)
        goggle_r = max(3, int(0.5 * b))
        lens_color = (40, 200, 170)
        lens_highlight = (80, 240, 210)
        for gx_off in [-int(0.55 * b), int(0.55 * b)]:
            gx = hx + gx_off
            # 프레임
            pygame.draw.circle(surface, (30, 40, 50), (gx, goggle_y), goggle_r + 1)
            # 렌즈
            pygame.draw.circle(surface, lens_color, (gx, goggle_y), goggle_r)
            # 렌즈 하이라이트
            pygame.draw.circle(surface, lens_highlight,
                               (gx - 1, goggle_y - 1), max(1, goggle_r // 2))
        # 브릿지
        pygame.draw.line(
            surface, (30, 40, 50),
            (hx - int(0.55 * b) + goggle_r, goggle_y),
            (hx + int(0.55 * b) - goggle_r, goggle_y), 2,
        )

        # ── 안테나 (상단 중앙) ──
        ant_base_y = hy - int(0.5 * b)
        ant_tip_y = ant_base_y - int(1.0 * b)
        pygame.draw.line(surface, (60, 200, 180), (hx, ant_base_y), (hx, ant_tip_y), 2)
        # 안테나 끝 빛남 (탐지 신호)
        glow_pulse = 0.6 + 0.4 * math.sin(phase * math.tau * 2.0)
        glow_r = max(2, int(0.25 * b * glow_pulse))
        pygame.draw.circle(surface, (100, 255, 220), (hx, ant_tip_y), glow_r)
