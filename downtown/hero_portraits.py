"""
영웅 초상화 렌더러 (Hero Portrait Renderer)
투기장 쿨타임 큐 UI에서 사용하는 영웅 얼굴 초상화를 프로시저럴 드로잉으로 구현.
얼굴만 그리며 (어깨/갑옷/몸체 없음), 카드 전체를 채우는 고퀄리티 페이스 포트레이트.
"""

import math
import pygame

_sin = math.sin
_cos = math.cos


class HeroPortraitRenderer:
    """영웅 페이스 초상화를 캐시하여 제공하는 렌더러."""

    def __init__(self):
        self._cache = {}

    def clear_cache(self):
        self._cache.clear()

    def render_portrait(self, hero_id: str, color: tuple, w: int = 32, h: int = 38) -> pygame.Surface:
        key = (hero_id, w, h)
        if key in self._cache:
            return self._cache[key]
        draw_func = getattr(self, f"_portrait_{hero_id}", None)
        if draw_func is None:
            draw_func = self._portrait_default
        surf = pygame.Surface((w, h), pygame.SRCALPHA)
        try:
            draw_func(surf, w, h, color)
        except Exception:
            self._portrait_default(surf, w, h, color)
        self._cache[key] = surf
        return surf

    @staticmethod
    def _clamp_color(r, g, b, a=255):
        return (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)), max(0, min(255, a)))

    @staticmethod
    def _lighten(color, amount=40):
        return tuple(min(255, c + amount) for c in color[:3])

    @staticmethod
    def _darken(color, amount=40):
        return tuple(max(0, c - amount) for c in color[:3])

    @staticmethod
    def _mix(c1, c2, t=0.5):
        """Mix two RGB colors. t=0 -> c1, t=1 -> c2."""
        return tuple(int(a + (b - a) * t) for a, b in zip(c1[:3], c2[:3]))

    def _soft_glow(self, surf, cx, cy, radius, color, alpha=30):
        """Soft additive glow circle."""
        sz = max(4, radius * 2 + 2)
        gs = pygame.Surface((sz, sz), pygame.SRCALPHA)
        r = sz // 2
        pygame.draw.circle(gs, (*color[:3], alpha), (r, r), r)
        surf.blit(gs, (cx - r, cy - r), special_flags=pygame.BLEND_ADD)

    def _radial_glow(self, surf, cx, cy, radius, color, layers=4, max_alpha=30):
        """Multi-layer radial gradient glow for rich atmospheric effects."""
        for i in range(layers):
            frac = (layers - i) / layers
            r = max(2, int(radius * frac))
            a = max(2, int(max_alpha * (0.3 + 0.7 * (1.0 - i / layers))))
            self._soft_glow(surf, cx, cy, r, color, a)

    def _face_base(self, surf, cx, face_top, face_w, face_h, skin, skin_sh, skin_hi):
        """Draw multi-layered face with 8-layer shading for depth."""
        skin_deep = self._darken(skin_sh, 18)
        skin_mid = self._mix(skin, skin_sh, 0.5)
        fr = pygame.Rect(cx - face_w // 2, face_top, face_w, face_h)
        # Layer 1: Base skin
        pygame.draw.ellipse(surf, skin, fr)
        # Layer 2: Jaw deep shadow (lower quarter)
        pygame.draw.ellipse(surf, skin_deep,
                            (fr.x + 1, face_top + int(face_h * 0.62), face_w - 2, int(face_h * 0.38)))
        # Layer 3: Chin contour (darkest at bottom center)
        pygame.draw.ellipse(surf, (*self._darken(skin_deep, 12)[:3], 28),
                            (cx - int(face_w * 0.25), face_top + int(face_h * 0.78),
                             int(face_w * 0.50), int(face_h * 0.22)))
        # Layer 4: Mid shadow (lower half transition)
        pygame.draw.ellipse(surf, skin_sh,
                            (fr.x, face_top + int(face_h * 0.50), face_w, int(face_h * 0.50)))
        # Layer 5: Mid-tone blend zone
        pygame.draw.ellipse(surf, (*skin_mid[:3], 28),
                            (fr.x + 1, face_top + int(face_h * 0.38), face_w - 2, int(face_h * 0.25)))
        # Layer 6: Re-blend upper (clean top half)
        pygame.draw.ellipse(surf, skin,
                            (fr.x + 1, face_top, face_w - 2, int(face_h * 0.58)))
        # Layer 7: Forehead highlight (wide, soft)
        hi_w = int(face_w * 0.55)
        hi_h = int(face_h * 0.22)
        pygame.draw.ellipse(surf, (*skin_hi[:3], 38),
                            (cx - hi_w // 2, face_top + int(face_h * 0.04), hi_w, hi_h))
        # Inner forehead bright spot
        pygame.draw.ellipse(surf, (*skin_hi[:3], 22),
                            (cx - int(face_w * 0.14), face_top + int(face_h * 0.07),
                             int(face_w * 0.28), int(face_h * 0.10)))
        # Layer 8: Brow ridge definition
        pygame.draw.ellipse(surf, (*skin_sh[:3], 16),
                            (cx - int(face_w * 0.38), face_top + int(face_h * 0.22),
                             int(face_w * 0.76), int(face_h * 0.06)))
        # Left side shadow (3D depth, light from upper-right)
        pygame.draw.ellipse(surf, (*skin_sh[:3], 28),
                            (fr.x, face_top + int(face_h * 0.14), int(face_w * 0.26), int(face_h * 0.50)))
        # Right side rim light
        pygame.draw.ellipse(surf, (*skin_hi[:3], 14),
                            (fr.x + int(face_w * 0.78), face_top + int(face_h * 0.18),
                             int(face_w * 0.18), int(face_h * 0.38)))
        # Temple shadows
        for s in [-1, 1]:
            pygame.draw.ellipse(surf, (*skin_sh[:3], 14),
                                (cx + s * int(face_w * 0.34) - int(face_w * 0.09),
                                 face_top + int(face_h * 0.12),
                                 int(face_w * 0.15), int(face_h * 0.18)))
        # Cheekbone highlights
        for s in [-1, 1]:
            cb_x = cx + s * int(face_w * 0.20)
            pygame.draw.ellipse(surf, (*skin_hi[:3], 20),
                                (cb_x - int(face_w * 0.10), face_top + int(face_h * 0.34),
                                 int(face_w * 0.18), int(face_h * 0.10)))
        # Under-eye contour shadows
        for s in [-1, 1]:
            ue_x = cx + s * int(face_w * 0.15)
            pygame.draw.ellipse(surf, (*skin_sh[:3], 13),
                                (ue_x - int(face_w * 0.10), face_top + int(face_h * 0.40),
                                 int(face_w * 0.18), int(face_h * 0.055)))
        return fr

    def _face_detail(self, surf, cx, face_top, face_w, face_h, skin_sh, skin_hi):
        """Add micro-detail to human faces: nasolabial folds, philtrum, chin dimple."""
        # Nasolabial fold hints
        for s in [-1, 1]:
            nl_x = cx + s * int(face_w * 0.14)
            nl_top = face_top + int(face_h * 0.52)
            nl_bot = face_top + int(face_h * 0.70)
            pygame.draw.line(surf, (*skin_sh[:3], 13), (nl_x, nl_top), (nl_x + s, nl_bot), 1)
        # Philtrum groove
        ph_y = face_top + int(face_h * 0.64)
        ph_h = int(face_h * 0.06)
        for s in [-1, 1]:
            pygame.draw.line(surf, (*skin_sh[:3], 11),
                             (cx + s * max(1, int(face_w * 0.02)), ph_y),
                             (cx + s * max(1, int(face_w * 0.015)), ph_y + ph_h), 1)
        # Chin dimple hint
        pygame.draw.ellipse(surf, (*skin_sh[:3], 10),
                            (cx - int(face_w * 0.04), face_top + int(face_h * 0.82),
                             int(face_w * 0.08), int(face_h * 0.05)))
        # Jawline definition
        for s in [-1, 1]:
            jx1 = cx + s * int(face_w * 0.40)
            jy1 = face_top + int(face_h * 0.55)
            jx2 = cx + s * int(face_w * 0.20)
            jy2 = face_top + int(face_h * 0.90)
            pygame.draw.line(surf, (*skin_sh[:3], 10), (jx1, jy1), (jx2, jy2), 1)

    def _nose_detail(self, surf, cx, nose_y, b, skin, skin_sh, skin_hi, w, h):
        """Detailed nose: bridge, tip, nostrils, side shadow, highlight."""
        bridge_top = nose_y - int(h * 0.07)
        # Bridge shadow (left side)
        pygame.draw.line(surf, (*skin_sh[:3], 38), (cx - 1, bridge_top), (cx - 1, nose_y), 1)
        # Bridge highlight (right side, light from right)
        pygame.draw.line(surf, (*skin_hi[:3], 42), (cx + 1, bridge_top + 1), (cx + 1, nose_y - 1), 1)
        # Center bridge line
        pygame.draw.line(surf, (*skin_sh[:3], 20), (cx, bridge_top), (cx, nose_y), 1)
        # Nose tip
        tip_r = max(2, int(b * 0.09))
        pygame.draw.circle(surf, skin_sh, (cx, nose_y), tip_r + 1)
        pygame.draw.circle(surf, skin, (cx, nose_y), tip_r)
        # Tip highlight (bright specular)
        pygame.draw.circle(surf, (*skin_hi[:3], 70), (cx, nose_y - 1), max(1, tip_r // 2))
        pygame.draw.circle(surf, (*skin_hi[:3], 35), (cx + 1, nose_y - 1), max(1, tip_r // 3))
        # Nostrils
        for s in [-1, 1]:
            nx = cx + s * max(2, int(b * 0.07))
            ny = nose_y + max(1, int(b * 0.04))
            pygame.draw.circle(surf, self._darken(skin_sh, 25), (nx, ny), max(1, int(b * 0.04)))
            # Nostril inner shadow
            pygame.draw.circle(surf, self._darken(skin_sh, 40), (nx + s, ny), max(1, int(b * 0.02)))
        # Side shadows (alar crease)
        for s in [-1, 1]:
            pygame.draw.line(surf, (*skin_sh[:3], 20),
                             (cx + s * (tip_r + 1), nose_y - 2),
                             (cx + s * (tip_r + 2), nose_y + 2), 1)

    def _lips(self, surf, cx, mouth_y, b, lip_color, lip_hi, w_frac=0.14):
        """Detailed lips: cupid's bow, upper/lower lip, highlight, corner shadow."""
        w = surf.get_width()
        h = surf.get_height()
        mw = int(w * w_frac)
        lip_dk = self._darken(lip_color, 22)
        # Lip line shadow (separation)
        pygame.draw.line(surf, (*lip_dk[:3], 35),
                         (cx - int(mw * 0.7), mouth_y), (cx + int(mw * 0.7), mouth_y), 1)
        # Upper lip with cupid's bow shape
        up_pts = [(cx - mw, mouth_y), (cx - int(mw * 0.3), mouth_y - 1),
                  (cx, mouth_y + 1), (cx + int(mw * 0.3), mouth_y - 1), (cx + mw, mouth_y)]
        pygame.draw.lines(surf, lip_color, False, up_pts, max(1, int(b * 0.06)))
        # Lower lip (fuller, rounder)
        pygame.draw.arc(surf, self._lighten(lip_color, 12),
                        (cx - int(mw * 0.7), mouth_y, int(mw * 1.4), int(h * 0.035)),
                        3.4, 5.9, max(1, int(b * 0.05)))
        # Lower lip highlight
        pygame.draw.ellipse(surf, (*lip_hi[:3], 28),
                            (cx - int(mw * 0.3), mouth_y + 1, int(mw * 0.6), max(1, int(h * 0.015))))
        # Lip corner shadows
        for s in [-1, 1]:
            pygame.draw.circle(surf, (*lip_dk[:3], 22),
                               (cx + s * mw, mouth_y), max(1, int(b * 0.025)))

    def _hq_eye(self, surf, ex, ey, w, h, b, iris_color,
                pupil_color=(25, 20, 20), sclera=(245, 242, 240),
                glow_color=None, sharp=False, sparkle=True,
                lid_color=(40, 30, 30), slit_pupil=False, eye_scale=1.0):
        """Ultra HQ eye: limbal ring, 5-layer iris gradient, radial texture, lower lid, tear duct."""
        sw = max(3, int(w * 0.08 * eye_scale))
        sh = max(2, int(h * 0.065 * eye_scale))
        # Multi-layer glow
        if glow_color:
            self._soft_glow(surf, ex, ey, max(5, int(b * 0.60)), glow_color, 12)
            self._soft_glow(surf, ex, ey, max(4, int(b * 0.45)), glow_color, 22)
        # Deep socket shadow
        pygame.draw.ellipse(surf, (*self._darken(sclera, 60)[:3], 14),
                            (ex - sw - 3, ey - sh - 3, (sw + 3) * 2, (sh + 3) * 2))
        # Socket shadow
        pygame.draw.ellipse(surf, (*self._darken(sclera, 45)[:3], 22),
                            (ex - sw - 2, ey - sh - 2, (sw + 2) * 2, (sh + 2) * 2))
        # Sclera
        if sharp:
            pts = [(ex - sw, ey + 1), (ex - sw // 2, ey - sh),
                   (ex + sw // 2, ey - sh), (ex + sw, ey + 1), (ex, ey + sh)]
            pygame.draw.polygon(surf, sclera, pts)
            inner_pts = [(ex - sw + 1, ey + 1), (ex - sw // 2 + 1, ey - sh + 1),
                         (ex + sw // 2 - 1, ey - sh + 1), (ex + sw - 1, ey + 1), (ex, ey + sh - 1)]
            pygame.draw.polygon(surf, sclera, inner_pts)
        else:
            # Outer sclera (edge darkening)
            pygame.draw.ellipse(surf, self._darken(sclera, 12), (ex - sw, ey - sh, sw * 2, sh * 2))
            # Inner sclera (bright)
            pygame.draw.ellipse(surf, sclera, (ex - sw + 1, ey - sh + 1, sw * 2 - 2, sh * 2 - 2))
        # Limbal ring (dark ring at iris edge, thicker)
        ir = max(2, int(min(sw, sh) * 0.75))
        pygame.draw.circle(surf, self._darken(iris_color, 65), (ex, ey), ir + 1)
        # Iris outer ring
        pygame.draw.circle(surf, self._darken(iris_color, 30), (ex, ey), ir)
        # Iris mid ring
        pygame.draw.circle(surf, iris_color, (ex, ey), max(1, int(ir * 0.85)))
        # Inner lighter iris ring
        pygame.draw.circle(surf, self._lighten(iris_color, 25), (ex, ey), max(1, ir * 2 // 3))
        # Inner bright core
        pygame.draw.circle(surf, self._lighten(iris_color, 45), (ex, ey), max(1, ir // 2))
        # Iris radial lines (texture depth)
        iris_light = self._lighten(iris_color, 20)
        for angle_deg in range(0, 360, 50):
            rad = math.radians(angle_deg)
            inner_r = max(1, int(ir * 0.30))
            outer_r = max(2, int(ir * 0.88))
            ix = ex + int(_cos(rad) * inner_r)
            iy = ey + int(_sin(rad) * inner_r)
            ox = ex + int(_cos(rad) * outer_r)
            oy = ey + int(_sin(rad) * outer_r)
            pygame.draw.line(surf, (*iris_light[:3], 35), (ix, iy), (ox, oy), 1)
        # Pupil
        pr = max(1, ir // 2)
        if slit_pupil:
            pygame.draw.ellipse(surf, pupil_color,
                                (ex - max(1, pr // 2), ey - ir + 1, max(2, pr), ir * 2 - 2))
        else:
            # Pupil edge softening
            pygame.draw.circle(surf, self._mix(pupil_color, iris_color, 0.3), (ex, ey), pr + 1)
            pygame.draw.circle(surf, pupil_color, (ex, ey), pr)
        # Primary highlight (crisp, bright)
        side = -1 if ex < w // 2 else 1
        hl_r = max(1, int(ir * 0.33))
        hl_x = ex + side * max(1, int(sw * 0.15))
        hl_y = ey - max(1, int(sh * 0.35))
        pygame.draw.circle(surf, (255, 255, 255), (hl_x, hl_y), hl_r)
        # Secondary sparkle
        if sparkle:
            sp_r = max(1, ir // 5)
            pygame.draw.circle(surf, (255, 255, 255, 180),
                               (ex - side * max(1, int(sw * 0.10)), ey + max(1, int(sh * 0.25))), sp_r)
        # Upper eyelid (thick, defined)
        lid_t = max(1, int(b * 0.08))
        pygame.draw.arc(surf, lid_color,
                        (ex - sw - 1, ey - sh - 1, sw * 2 + 2, sh * 2 + 1),
                        0.3, 2.8, lid_t)
        # Eyelid highlight (reflected light on lid skin)
        pygame.draw.arc(surf, (*self._lighten(lid_color, 35)[:3], 22),
                        (ex - sw, ey - sh - 2, sw * 2, sh * 2),
                        0.5, 2.6, 1)
        # Lower eyelid (thinner, subtle)
        lower_t = max(1, lid_t - 1) if lid_t > 1 else 1
        pygame.draw.arc(surf, (*lid_color[:3], 42),
                        (ex - sw, ey - sh + 1, sw * 2, sh * 2),
                        3.6, 5.8, lower_t)
        # Tear duct hint (inner corner)
        td_side = 1 if ex < w // 2 else -1
        td_x = ex + td_side * (sw - 1)
        pygame.draw.circle(surf, self._mix(sclera, (255, 200, 190), 0.4),
                           (td_x, ey + 1), max(1, int(b * 0.025)))

    def _portrait_default(self, surf, w, h, color):
        cx = w // 2
        cy = h // 2
        b = max(4, min(w, h) // 5)
        bg = self._darken(color, 80)
        pygame.draw.rect(surf, (*bg, 100), (0, 0, w, h))
        face_w = int(w * 0.7)
        face_h = int(h * 0.8)
        face_rect = pygame.Rect(cx - face_w // 2, cy - face_h // 2, face_w, face_h)
        pygame.draw.ellipse(surf, (200, 180, 160), face_rect)
        pygame.draw.ellipse(surf, (180, 160, 140), face_rect, 1)
        for s in [-1, 1]:
            ex = cx + s * int(w * 0.12)
            ey = cy - int(h * 0.05)
            pygame.draw.circle(surf, (255, 255, 255), (ex, ey), max(2, b // 3))
            pygame.draw.circle(surf, (40, 40, 40), (ex, ey), max(1, b // 5))
            pygame.draw.circle(surf, (255, 255, 255), (ex + s, ey - 1), max(1, b // 8))
        pygame.draw.rect(surf, color, (0, 0, w, h), 1, border_radius=3)

    # ─── 1. MUGEN (무겐/귀검사) ───
    def _portrait_mugen(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        skin = (235, 210, 185)
        skin_sh = (205, 175, 150)
        skin_hi = (250, 235, 220)
        hair = (30, 18, 45)
        hair_mid = (45, 28, 65)
        hair_hi = (70, 50, 100)
        hair_shine = (100, 70, 140)
        eye_glow = (200, 100, 255)
        band = (240, 240, 240)
        band_sh = (210, 210, 220)
        band_hi = (255, 255, 255)
        aura = (120, 50, 180)
        # Background - layered purple aura (radial glow for rich depth)
        self._radial_glow(surf, cx, int(h * 0.4), max(8, int(w * 0.45)), aura, layers=5, max_alpha=22)
        self._radial_glow(surf, cx + int(w * 0.1), int(h * 0.3), max(6, int(w * 0.30)), (160, 80, 220), layers=4, max_alpha=16)
        self._radial_glow(surf, cx - int(w * 0.15), int(h * 0.55), max(4, int(w * 0.20)), (140, 60, 200), layers=3, max_alpha=10)
        # Ambient purple energy particles around edges
        import random as _rng_m
        _rng_m_inst = _rng_m.Random(77)
        for _ in range(12):
            px = _rng_m_inst.randint(2, w - 2)
            py = _rng_m_inst.randint(2, h - 2)
            pr = max(1, _rng_m_inst.randint(1, int(b * 0.08) + 1))
            pa = _rng_m_inst.randint(15, 40)
            pygame.draw.circle(surf, (*aura, pa), (px, py), pr + 2)
            pygame.draw.circle(surf, (200, 140, 255, pa + 15), (px, py), pr)
        # Hair back mass
        hair_rect = pygame.Rect(cx - int(w * 0.44), int(h * 0.0), int(w * 0.88), int(h * 0.56))
        pygame.draw.ellipse(surf, hair, hair_rect)
        # Hair mid-layer volume
        pygame.draw.ellipse(surf, hair_mid, (cx - int(w * 0.38), int(h * 0.04), int(w * 0.76), int(h * 0.45)))
        # Spiky hair top - more spikes, varying sizes
        spikes = [(-0.38, 0.06, -0.28, -0.10), (-0.22, 0.02, -0.12, -0.16),
                  (-0.08, 0.0, 0.02, -0.22), (0.05, 0.01, 0.15, -0.18),
                  (0.18, 0.03, 0.28, -0.12), (0.32, 0.06, 0.40, -0.06),
                  (-0.15, 0.01, -0.02, -0.20), (0.10, 0.02, 0.22, -0.14)]
        for x1f, y1f, x2f, y2f in spikes:
            px = [cx + int(x1f * w), cx + int(x2f * w), cx + int((x1f + x2f) * 0.5 * w)]
            py = [int(h * (0.14 + y1f)), int(h * (0.04 + y2f)), int(h * (0.10 + (y1f + y2f) * 0.5))]
            pygame.draw.polygon(surf, hair, list(zip(px, py)))
        # Spike edge highlights
        for x1f, _, x2f, y2f in spikes[::2]:
            tip_x = cx + int(x2f * w)
            tip_y = int(h * (0.04 + y2f))
            base_x = cx + int((x1f + x2f) * 0.5 * w)
            pygame.draw.line(surf, hair_hi, (base_x, int(h * 0.12)), (tip_x, tip_y), 1)
        # Spike tip tiny highlights (bright dot at each spike tip)
        for x1f, y1f, x2f, y2f in spikes:
            tip_x = cx + int(x2f * w)
            tip_y = int(h * (0.04 + y2f))
            pygame.draw.circle(surf, (*hair_shine[:3], 50), (tip_x, tip_y), max(1, int(b * 0.04)))
        # Individual hair strand texture lines within back mass
        for dx_f in [-0.30, -0.22, -0.14, -0.06, 0.02, 0.10, 0.18, 0.26, 0.34]:
            sx = cx + int(dx_f * w)
            pygame.draw.line(surf, (*hair_mid[:3], 45), (sx, int(h * 0.06)),
                             (sx + int(w * 0.01), int(h * 0.42)), 1)
        # Additional thin highlight strands over hair mass
        for dx_f in [-0.26, -0.10, 0.06, 0.22]:
            sx = cx + int(dx_f * w)
            pygame.draw.line(surf, (*hair_hi[:3], 35), (sx, int(h * 0.08)),
                             (sx + int(w * 0.02), int(h * 0.38)), 1)
        # Face - 4-layer shading
        face_w = int(w * 0.58)
        face_h = int(h * 0.72)
        face_top = int(h * 0.22)
        self._face_base(surf, cx, face_top, face_w, face_h, skin, skin_sh, skin_hi)
        self._face_detail(surf, cx, face_top, face_w, face_h, skin_sh, skin_hi)
        # Scar / battle mark on left cheek (diagonal slash)
        scar_x1 = cx - int(w * 0.12)
        scar_y1 = int(h * 0.46)
        scar_x2 = cx - int(w * 0.06)
        scar_y2 = int(h * 0.56)
        pygame.draw.line(surf, (*self._darken(skin_sh, 15)[:3], 35), (scar_x1, scar_y1), (scar_x2, scar_y2), 1)
        pygame.draw.line(surf, (*skin_hi[:3], 25), (scar_x1 + 1, scar_y1), (scar_x2 + 1, scar_y2), 1)
        # Right cheek highlight
        pygame.draw.ellipse(surf, (*skin_hi, 50),
                            (cx + int(w * 0.02), face_top + int(face_h * 0.35), int(face_w * 0.25), int(face_h * 0.18)))
        # Hair bangs over forehead - more detailed with layers
        bang_pts = [(cx - int(w * 0.30), int(h * 0.16)),
                    (cx - int(w * 0.18), int(h * 0.36)),
                    (cx - int(w * 0.08), int(h * 0.33)),
                    (cx, int(h * 0.38)),
                    (cx + int(w * 0.10), int(h * 0.30)),
                    (cx + int(w * 0.22), int(h * 0.20)),
                    (cx + int(w * 0.05), int(h * 0.10)),
                    (cx - int(w * 0.10), int(h * 0.08))]
        pygame.draw.polygon(surf, hair, bang_pts)
        # Bang highlight strands
        for dx, dy1, dy2 in [(-0.14, 0.10, 0.30), (-0.02, 0.09, 0.32), (0.08, 0.11, 0.26),
                              (-0.20, 0.12, 0.22), (0.14, 0.13, 0.22)]:
            pygame.draw.line(surf, hair_hi, (cx + int(dx * w), int(dy1 * h)),
                             (cx + int((dx + 0.02) * w), int(dy2 * h)), 1)
        # Hair shine line
        pygame.draw.line(surf, hair_shine, (cx - int(w * 0.05), int(h * 0.08)),
                         (cx + int(w * 0.02), int(h * 0.25)), 1)
        # Hachimaki headband - more detailed
        band_y = int(h * 0.27)
        band_h2 = max(3, int(h * 0.07))
        pygame.draw.rect(surf, band, (cx - int(w * 0.34), band_y, int(w * 0.68), band_h2))
        pygame.draw.line(surf, band_hi, (cx - int(w * 0.34), band_y), (cx + int(w * 0.34), band_y), 1)
        pygame.draw.line(surf, band_sh, (cx - int(w * 0.34), band_y + band_h2 - 1),
                         (cx + int(w * 0.34), band_y + band_h2 - 1), 1)
        # Band knot detail (right side)
        knot_x = cx + int(w * 0.30)
        knot_y = band_y + band_h2 // 2
        pygame.draw.circle(surf, band_sh, (knot_x, knot_y), max(2, int(b * 0.10)))
        pygame.draw.circle(surf, band, (knot_x, knot_y), max(1, int(b * 0.07)))
        pygame.draw.circle(surf, band_hi, (knot_x - 1, knot_y - 1), max(1, int(b * 0.04)))
        # Knot wrinkle lines
        pygame.draw.line(surf, band_sh, (knot_x - int(b * 0.06), knot_y - 1),
                         (knot_x + int(b * 0.06), knot_y + 1), 1)
        # Band tails - flowing
        tail_x = cx + int(w * 0.30)
        for i, (ty, tx_off) in enumerate([(0, 6), (3, 10), (6, 13), (9, 11)]):
            a = max(80, 220 - i * 40)
            pygame.draw.line(surf, (*band, a), (tail_x, band_y + ty),
                             (tail_x + int(tx_off * b / 5), band_y + ty + int(h * 0.14)),
                             max(1, band_h2 // 2 - i // 2))
        # Band tail edge highlights
        for i in range(2):
            a = max(60, 180 - i * 50)
            pygame.draw.line(surf, (*band_hi, a), (tail_x + 1, band_y + i * 4),
                             (tail_x + int(8 * b / 5), band_y + i * 4 + int(h * 0.12)), 1)
        # Eyes - high-quality glowing purple
        eye_y = int(h * 0.42)
        eye_sp = int(w * 0.12)
        for s in [-1, 1]:
            self._hq_eye(surf, cx + s * eye_sp, eye_y, w, h, b,
                         eye_glow, pupil_color=(40, 10, 60), sclera=(240, 230, 245),
                         glow_color=(180, 80, 255), lid_color=(50, 25, 60))
        # Intense eyebrows
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = eye_y - max(3, int(h * 0.07))
            pygame.draw.line(surf, (60, 30, 50), (bx - s * int(w * 0.05), by + 2),
                             (bx + s * int(w * 0.04), by - 1), max(1, int(b * 0.09)))
        # Nose - detailed bridge, tip, nostrils
        nose_y = int(h * 0.55)
        self._nose_detail(surf, cx, nose_y, b, skin, skin_sh, skin_hi, w, h)
        # Mouth - detailed lips
        mouth_y = int(h * 0.65)
        self._lips(surf, cx, mouth_y, b, (180, 130, 120), skin_hi)
        # Chin shadow
        pygame.draw.ellipse(surf, (*skin_sh, 45),
                            (cx - face_w // 4, int(h * 0.74), face_w // 2, int(h * 0.14)))
        # Rim light on right side
        pygame.draw.arc(surf, (*skin_hi, 35),
                        (cx - face_w // 2, face_top, face_w, face_h), 4.5, 5.8, 1)
        # Border
        pygame.draw.rect(surf, (*aura, 180), (0, 0, w, h), 1, border_radius=2)

    # ─── 2. KRAKEN (크라켄) ───
    def _portrait_kraken(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        body = (140, 70, 60)
        body_dk = (100, 45, 35)
        body_deep = (75, 30, 22)
        body_lt = (170, 100, 85)
        body_hi = (195, 130, 110)
        dot_color = (80, 160, 255)
        eye_color = (200, 240, 100)
        eye_glow = (160, 220, 60)
        # Background - deep sea layered (radial glow for richer ocean feel)
        pygame.draw.rect(surf, (8, 15, 35, 140), (0, 0, w, h))
        self._radial_glow(surf, cx, int(h * 0.35), max(8, int(w * 0.40)), (20, 50, 100), layers=5, max_alpha=18)
        self._radial_glow(surf, cx - int(w * 0.15), int(h * 0.55), max(5, int(w * 0.25)), (15, 40, 90), layers=3, max_alpha=12)
        self._radial_glow(surf, cx + int(w * 0.12), int(h * 0.20), max(4, int(w * 0.18)), (25, 65, 120), layers=3, max_alpha=10)
        # Deeper underwater caustic patterns
        for i in range(6):
            cx2 = cx + int(_sin(i * 1.7) * w * 0.25)
            cy2 = int(h * 0.12 + i * h * 0.14)
            cw = int(w * (0.25 + _sin(i * 0.9) * 0.08))
            ch = int(h * (0.06 + _cos(i * 1.2) * 0.02))
            pygame.draw.ellipse(surf, (20, 60, 120, max(4, 10 - i)),
                                (cx2 - cw // 2, cy2, cw, ch))
        # Dome-shaped head - 3-layer shading
        dome_w = int(w * 0.82)
        dome_h = int(h * 0.65)
        dome_top = int(h * 0.02)
        dome_rect = pygame.Rect(cx - dome_w // 2, dome_top, dome_w, dome_h)
        pygame.draw.ellipse(surf, body, dome_rect)
        # Dome edge shadow
        pygame.draw.ellipse(surf, body_dk,
                            (dome_rect.x + 1, dome_top + int(dome_h * 0.5), dome_w - 2, int(dome_h * 0.5)))
        pygame.draw.ellipse(surf, body,
                            (dome_rect.x + 2, dome_top, dome_w - 4, int(dome_h * 0.6)))
        # Deep shadow at base
        pygame.draw.ellipse(surf, body_deep,
                            (dome_rect.x + 3, dome_top + int(dome_h * 0.7), dome_w - 6, int(dome_h * 0.3)))
        # Dome highlight - specular
        hi_w = int(dome_w * 0.35)
        hi_h = int(dome_h * 0.3)
        pygame.draw.ellipse(surf, (*body_lt, 55),
                            (cx - hi_w // 2 - int(w * 0.05), dome_top + int(h * 0.04), hi_w, hi_h))
        # Secondary highlight
        pygame.draw.ellipse(surf, (*body_hi, 30),
                            (cx - int(w * 0.08), dome_top + int(h * 0.02), int(w * 0.12), int(h * 0.10)))
        # Dome texture ridges
        for i in range(3):
            ry = dome_top + int(dome_h * (0.25 + i * 0.15))
            rw = int(dome_w * (0.7 - i * 0.1))
            pygame.draw.arc(surf, (*body_dk, 40),
                            (cx - rw // 2, ry - int(h * 0.02), rw, int(h * 0.04)), 0, 3.14, 1)
        # Pulsating concentric ring patterns on dome
        for i in range(4):
            ring_r = max(3, int(dome_w * (0.15 + i * 0.08)))
            ring_y = dome_top + int(dome_h * 0.35)
            ring_a = max(8, 22 - i * 4)
            pygame.draw.ellipse(surf, (*body_dk[:3], ring_a),
                                (cx - ring_r, ring_y - ring_r // 2, ring_r * 2, ring_r), 1)
        # Subtle texture veins on dome surface
        for i in range(5):
            vx1 = cx + int(_sin(i * 1.8) * dome_w * 0.25)
            vy1 = dome_top + int(dome_h * (0.18 + i * 0.10))
            vx2 = vx1 + int(_cos(i * 2.3) * w * 0.08)
            vy2 = vy1 + int(h * 0.06)
            pygame.draw.line(surf, (*body_dk[:3], 18), (vx1, vy1), (vx2, vy2), 1)
        # Water droplet / moisture highlights on dome
        for i in range(5):
            drop_x = cx + int(_sin(i * 2.5 + 0.3) * dome_w * 0.28)
            drop_y = dome_top + int(dome_h * (0.14 + i * 0.11))
            pygame.draw.circle(surf, (*body_hi[:3], 40), (drop_x, drop_y), max(1, int(b * 0.04)))
            pygame.draw.circle(surf, (255, 255, 255, 25), (drop_x, drop_y - 1), max(1, int(b * 0.02)))
        # Bioluminescent dots - layered glow (increased from 16 to 26)
        import random
        rng = random.Random(42)
        for _ in range(26):
            dx = cx + rng.randint(-dome_w // 3, dome_w // 3)
            dy = dome_top + rng.randint(int(dome_h * 0.12), int(dome_h * 0.72))
            dr = max(1, rng.randint(1, int(b * 0.15) + 1))
            self._soft_glow(surf, dx, dy, dr * 3, dot_color, 25)
            pygame.draw.circle(surf, (*dot_color, 120), (dx, dy), max(1, dr))
            pygame.draw.circle(surf, (200, 230, 255), (dx, dy), max(1, dr // 2))
        # Large eyes - tall oval with enhanced detail
        eye_y = int(h * 0.40)
        eye_sp = int(w * 0.16)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            ew = max(4, int(w * 0.12))
            eh = max(5, int(h * 0.16))
            # Eye glow aura (radial for richer glow)
            self._radial_glow(surf, ex, eye_y, max(6, int(ew * 1.0)), eye_glow, layers=4, max_alpha=25)
            # Eye socket shadow
            pygame.draw.ellipse(surf, (15, 20, 8),
                                (ex - ew - 1, eye_y - eh - 1, ew * 2 + 2, eh * 2 + 2))
            # Eye shape
            pygame.draw.ellipse(surf, (20, 30, 10), (ex - ew, eye_y - eh, ew * 2, eh * 2))
            # Iris - gradient layers
            ir = max(3, int(min(ew, eh) * 0.75))
            pygame.draw.circle(surf, self._darken(eye_color, 40), (ex, eye_y), ir + 1)
            pygame.draw.circle(surf, eye_color, (ex, eye_y), ir)
            pygame.draw.circle(surf, self._lighten(eye_color, 25), (ex, eye_y), max(1, ir * 2 // 3))
            # Pupil - vertical slit
            pygame.draw.ellipse(surf, (15, 15, 8),
                                (ex - max(1, ir // 4), eye_y - ir + 1, max(2, ir // 2), ir * 2 - 2))
            # Dual highlights
            pygame.draw.circle(surf, (255, 255, 220), (ex + s * 2, eye_y - 2), max(1, ir // 3))
            pygame.draw.circle(surf, (255, 255, 230, 150), (ex - s, eye_y + 2), max(1, ir // 5))
        # Tentacles - enhanced with gradient color
        tent_y = int(h * 0.62)
        for i in range(8):
            tx = cx + int((i - 3.5) * w * 0.08)
            tent_len = int(h * 0.26) + (i % 3) * int(h * 0.06)
            pts = []
            for t in range(7):
                tf = t / 6.0
                ty = tent_y + int(tent_len * tf)
                wave = int(_sin(tf * 3.5 + i * 0.9) * w * 0.035)
                pts.append((tx + wave, ty))
            if len(pts) >= 2:
                thick = max(1, int(b * 0.20))
                for j in range(len(pts) - 1):
                    t_ratio = j / len(pts)
                    cur_thick = max(1, thick - j * thick // len(pts))
                    tc = self._mix(body, body_lt, t_ratio * 0.4)
                    pygame.draw.line(surf, tc, pts[j], pts[j + 1], cur_thick)
                # Suction cups with shadow ring and highlight
                for j in range(1, len(pts) - 1, 2):
                    cup_r = max(1, int(b * 0.06))
                    # Shadow ring around each cup
                    pygame.draw.circle(surf, body_deep, pts[j], cup_r + 1)
                    pygame.draw.circle(surf, body_lt, pts[j], cup_r)
                    pygame.draw.circle(surf, body_hi, pts[j], max(1, cup_r // 2))
                    # Tiny specular on cup
                    pygame.draw.circle(surf, (255, 220, 200, 35),
                                       (pts[j][0], pts[j][1] - 1), max(1, cup_r // 3))
        # Beak / mouth slit with deeper depth layers
        mouth_y = int(h * 0.58)
        # Outer beak shadow
        pygame.draw.arc(surf, body_deep,
                        (cx - int(w * 0.11), mouth_y - 1, int(w * 0.22), int(h * 0.09)), 3.14, 6.28, 1)
        # Mid beak
        pygame.draw.arc(surf, body_deep,
                        (cx - int(w * 0.09), mouth_y, int(w * 0.18), int(h * 0.07)), 3.14, 6.28, 1)
        # Inner beak line
        pygame.draw.arc(surf, body_dk,
                        (cx - int(w * 0.07), mouth_y + 1, int(w * 0.14), int(h * 0.05)), 3.14, 6.28, 1)
        # Beak highlight on upper lip edge
        pygame.draw.arc(surf, (*body_lt[:3], 25),
                        (cx - int(w * 0.06), mouth_y - 1, int(w * 0.12), int(h * 0.03)), 3.14, 6.28, 1)
        # Rim light on dome
        pygame.draw.arc(surf, (*body_hi, 30), dome_rect, 0.3, 1.2, 1)
        pygame.draw.rect(surf, (*dot_color, 100), (0, 0, w, h), 1, border_radius=2)

    # ─── 3. CHRONOS (키르케/흑마녀) ───
    def _portrait_chronos(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        skin = (210, 200, 215)
        skin_sh = (180, 165, 185)
        skin_hi = (235, 230, 240)
        hood = (35, 20, 50)
        hood_mid = (45, 28, 65)
        hood_lt = (60, 40, 80)
        hood_hi = (75, 55, 95)
        eye_color = (180, 80, 255)
        aura = (100, 40, 160)
        lip = (175, 130, 155)
        # Dark background
        pygame.draw.rect(surf, (12, 6, 22, 150), (0, 0, w, h))
        # Layered aura wisps (radial glow for richer aura)
        for i in range(6):
            ax = cx + int(_sin(i * 1.3) * w * 0.3)
            ay = int(h * 0.3 + _cos(i * 1.7) * h * 0.2)
            self._radial_glow(surf, ax, ay, max(4, int(b * 0.40 + i * b * 0.10)), aura, layers=4, max_alpha=16)
        # Additional deep atmospheric glow
        self._radial_glow(surf, cx, int(h * 0.45), max(6, int(w * 0.35)), (80, 30, 140), layers=5, max_alpha=12)
        # Hood / cowl - detailed dark shape
        hood_pts = [(0, 0), (w, 0), (w, int(h * 0.7)),
                    (cx + int(w * 0.35), int(h * 0.85)),
                    (cx, int(h * 0.92)),
                    (cx - int(w * 0.35), int(h * 0.85)),
                    (0, int(h * 0.7))]
        pygame.draw.polygon(surf, hood, hood_pts)
        # Hood fold shading - multiple layers for fabric depth
        # Left fold
        pygame.draw.polygon(surf, hood_mid,
                            [(cx - int(w * 0.30), int(h * 0.12)),
                             (cx - int(w * 0.35), int(h * 0.50)),
                             (cx - int(w * 0.25), int(h * 0.48)),
                             (cx - int(w * 0.22), int(h * 0.10))])
        # Right fold
        pygame.draw.polygon(surf, hood_mid,
                            [(cx + int(w * 0.22), int(h * 0.10)),
                             (cx + int(w * 0.25), int(h * 0.48)),
                             (cx + int(w * 0.35), int(h * 0.50)),
                             (cx + int(w * 0.30), int(h * 0.12))])
        # Hood inner edge highlight
        inner_pts = [(cx - int(w * 0.28), int(h * 0.14)),
                     (cx - int(w * 0.33), int(h * 0.50)),
                     (cx - int(w * 0.28), int(h * 0.76)),
                     (cx, int(h * 0.86)),
                     (cx + int(w * 0.28), int(h * 0.76)),
                     (cx + int(w * 0.33), int(h * 0.50)),
                     (cx + int(w * 0.28), int(h * 0.14))]
        pygame.draw.polygon(surf, hood_lt, inner_pts, 1)
        # Additional hood fold lines (varying shade for fabric depth)
        for i, (fx, fy1, fy2, shade_off) in enumerate([
            (-0.27, 0.20, 0.60, 8), (-0.18, 0.25, 0.65, 5),
            (0.18, 0.25, 0.65, 5), (0.27, 0.20, 0.60, 8)]):
            fold_c = self._lighten(hood, shade_off)
            pygame.draw.line(surf, (*fold_c[:3], 28),
                             (cx + int(fx * w), int(fy1 * h)),
                             (cx + int(fx * w), int(fy2 * h)), 1)
        # Hood top highlight
        pygame.draw.arc(surf, (*hood_hi, 40),
                        (cx - int(w * 0.35), -int(h * 0.1), int(w * 0.70), int(h * 0.3)), 3.5, 5.8, 1)
        # Hood interior shadow gradient (deeper darkness inside hood)
        for layer in range(3):
            shrink = int(w * 0.03 * layer)
            shade_a = max(15, 40 - layer * 12)
            pygame.draw.ellipse(surf, (8, 4, 16, shade_a),
                                (cx - int(w * 0.24) + shrink, int(h * 0.16) + layer * int(h * 0.02),
                                 int(w * 0.48) - shrink * 2, int(h * 0.58) - layer * int(h * 0.04)))
        # Starfield effect inside hood interior (tiny white dots)
        import random as _rng_c
        _rng_c_inst = _rng_c.Random(333)
        for _ in range(8):
            sx = cx + _rng_c_inst.randint(-int(w * 0.20), int(w * 0.20))
            sy = int(h * 0.18) + _rng_c_inst.randint(0, int(h * 0.50))
            sa = _rng_c_inst.randint(15, 40)
            pygame.draw.circle(surf, (220, 210, 255, sa), (sx, sy), 1)
        # Mystic rune symbols on hood (small geometric shapes)
        for i, (rx_f, ry_f) in enumerate([(-0.32, 0.35), (0.32, 0.35),
                                           (-0.30, 0.55), (0.30, 0.55),
                                           (-0.20, 0.72), (0.20, 0.72)]):
            rx = cx + int(rx_f * w)
            ry = int(ry_f * h)
            rune_a = max(12, 28 - i * 3)
            rune_r = max(1, int(b * 0.04))
            # Small diamond rune
            pygame.draw.polygon(surf, (*aura[:3], rune_a),
                                [(rx, ry - rune_r), (rx + rune_r, ry),
                                 (rx, ry + rune_r), (rx - rune_r, ry)], 1)
        # Face inside hood - 4-layer shading
        face_w = int(w * 0.48)
        face_h = int(h * 0.60)
        face_top = int(h * 0.20)
        self._face_base(surf, cx, face_top, face_w, face_h, skin, skin_sh, skin_hi)
        self._face_detail(surf, cx, face_top, face_w, face_h, skin_sh, skin_hi)
        # Cheek highlight right
        pygame.draw.ellipse(surf, (*skin_hi, 40),
                            (cx + int(w * 0.01), face_top + int(face_h * 0.35), int(face_w * 0.22), int(face_h * 0.15)))
        # Eyes - high-quality glowing purple (enhanced intensity)
        eye_y = int(h * 0.42)
        eye_sp = int(w * 0.10)
        for s in [-1, 1]:
            # Extra glow behind eyes for intensity
            self._radial_glow(surf, cx + s * eye_sp, eye_y, max(4, int(b * 0.35)), eye_color, layers=3, max_alpha=18)
            self._hq_eye(surf, cx + s * eye_sp, eye_y, w, h, b,
                         eye_color, pupil_color=(30, 10, 50), sclera=(230, 220, 240),
                         glow_color=(160, 60, 230), lid_color=(60, 35, 70))
        # Thin elegant eyebrows
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = eye_y - max(2, int(h * 0.06))
            pygame.draw.line(surf, skin_sh, (bx - s * int(w * 0.04), by + 1),
                             (bx + s * int(w * 0.04), by - 1), 1)
        # Nose - detailed delicate nose
        nose_y = int(h * 0.54)
        self._nose_detail(surf, cx, nose_y, b, skin, skin_sh, skin_hi, w, h)
        # Mouth - detailed mysterious lips
        mouth_y = int(h * 0.64)
        self._lips(surf, cx, mouth_y, b, lip, skin_hi, w_frac=0.10)
        # Chin shadow
        pygame.draw.ellipse(surf, (*skin_sh, 35),
                            (cx - face_w // 4, int(h * 0.72), face_w // 2, int(h * 0.10)))
        # Purple aura wisps near face edges - enhanced
        for i in range(4):
            wy = int(h * 0.25 + i * h * 0.14)
            for s in [-1, 1]:
                wx = cx + s * int(w * 0.26 + _sin(i * 2.0) * w * 0.05)
                a = max(20, 50 - i * 8)
                pygame.draw.circle(surf, (*aura, a), (wx, wy), max(1, int(b * 0.10)))
                pygame.draw.circle(surf, (*self._lighten(aura, 30), a // 2), (wx, wy), max(1, int(b * 0.06)))
        # Floating arcane particles (small glowing dots near edges)
        for i in range(10):
            px = cx + int(_sin(i * 2.3 + 0.5) * w * 0.38)
            py = int(h * 0.10 + i * h * 0.08)
            pa = max(12, 35 - i * 2)
            pr = max(1, int(b * 0.03))
            self._radial_glow(surf, px, py, pr * 3, (180, 120, 255), layers=2, max_alpha=pa)
            pygame.draw.circle(surf, (200, 160, 255, pa + 10), (px, py), pr)
        # Mystic rune hints on hood edge (more detailed)
        for i in range(5):
            rx = cx + int((i - 2) * w * 0.14)
            ry = int(h * 0.82)
            rune_a = max(18, 40 - i * 4)
            pygame.draw.circle(surf, (*aura, rune_a), (rx, ry), max(1, int(b * 0.05)))
            # Tiny cross rune
            cr = max(1, int(b * 0.03))
            pygame.draw.line(surf, (*self._lighten(aura, 30)[:3], rune_a),
                             (rx - cr, ry), (rx + cr, ry), 1)
            pygame.draw.line(surf, (*self._lighten(aura, 30)[:3], rune_a),
                             (rx, ry - cr), (rx, ry + cr), 1)
        pygame.draw.rect(surf, (*aura, 150), (0, 0, w, h), 1, border_radius=2)

    # ─── 4. ONIMARU (오니마루/악마) ───
    def _portrait_onimaru(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        skin = (200, 60, 50)
        skin_dk = (160, 40, 35)
        skin_deep = (130, 25, 20)
        skin_lt = (230, 90, 70)
        skin_hi = (245, 120, 95)
        hair = (30, 20, 25)
        hair_hi = (50, 35, 40)
        horn = (180, 170, 140)
        horn_dk = (140, 130, 100)
        horn_lt = (210, 200, 175)
        eye_color = (255, 220, 40)
        fang = (240, 235, 220)
        # Fiery background - multi-layer (radial glow for deeper inferno)
        self._radial_glow(surf, cx, int(h * 0.5), max(8, int(w * 0.45)), (200, 60, 20), layers=5, max_alpha=24)
        self._radial_glow(surf, cx - int(w * 0.1), int(h * 0.3), max(5, int(w * 0.25)), (250, 100, 30), layers=4, max_alpha=14)
        self._radial_glow(surf, cx + int(w * 0.15), int(h * 0.6), max(4, int(w * 0.18)), (180, 40, 10), layers=3, max_alpha=10)
        # Flame / ember particles around edges
        import random as _rng_o
        _rng_o_inst = _rng_o.Random(666)
        for _ in range(14):
            fx = _rng_o_inst.randint(2, w - 2)
            fy = _rng_o_inst.randint(2, h - 2)
            fr = max(1, _rng_o_inst.randint(1, int(b * 0.06) + 1))
            fa = _rng_o_inst.randint(18, 50)
            ember_c = _rng_o_inst.choice([(255, 120, 30), (255, 80, 15), (255, 180, 50)])
            pygame.draw.circle(surf, (*ember_c, fa), (fx, fy), fr + 1)
            pygame.draw.circle(surf, (255, 220, 120, fa // 2), (fx, fy), fr)
        # Wild dark hair - back mass with volume
        hair_rect = pygame.Rect(cx - int(w * 0.46), 0, int(w * 0.92), int(h * 0.52))
        pygame.draw.ellipse(surf, hair, hair_rect)
        # Wild spikes - more varied with edge highlights
        spike_data = [(-0.40, 0.08), (-0.28, -0.03), (-0.15, -0.06), (-0.02, -0.08),
                      (0.10, -0.06), (0.23, -0.02), (0.36, 0.07), (-0.08, -0.07)]
        for x_off, y_off in spike_data:
            sx = cx + int(x_off * w)
            sy = int(h * (0.09 + y_off))
            sw2 = int(w * 0.06)
            pygame.draw.polygon(surf, hair, [(sx - sw2, int(h * 0.14)), (sx, sy), (sx + sw2, int(h * 0.14))])
            pygame.draw.line(surf, hair_hi, (sx, sy), (sx + 1, int(h * 0.12)), 1)
        # Face - red demon, 4-layer shading
        face_w = int(w * 0.60)
        face_h = int(h * 0.68)
        face_top = int(h * 0.20)
        self._face_base(surf, cx, face_top, face_w, face_h, skin, skin_dk, skin_lt)
        self._face_detail(surf, cx, face_top, face_w, face_h, skin_dk, skin_lt)
        # Facial markings - dark tribal lines (original)
        for s in [-1, 1]:
            mx = cx + s * int(w * 0.16)
            pygame.draw.line(surf, skin_deep, (mx, face_top + int(face_h * 0.15)),
                             (mx + s * int(w * 0.02), face_top + int(face_h * 0.45)), 1)
        # Tribal tattoo / war paint marks (additional detail)
        for s in [-1, 1]:
            # Cheek war paint - horizontal streaks
            for j in range(3):
                py_off = 0.40 + j * 0.05
                px1 = cx + s * int(w * 0.08)
                px2 = cx + s * int(w * 0.22)
                py_pos = face_top + int(face_h * py_off)
                pygame.draw.line(surf, (*skin_deep[:3], 30), (px1, py_pos), (px2, py_pos), 1)
            # Forehead tribal mark (small V)
            if s == -1:
                pygame.draw.line(surf, (*skin_deep[:3], 25),
                                 (cx - int(w * 0.06), face_top + int(face_h * 0.10)),
                                 (cx, face_top + int(face_h * 0.15)), 1)
                pygame.draw.line(surf, (*skin_deep[:3], 25),
                                 (cx, face_top + int(face_h * 0.15)),
                                 (cx + int(w * 0.06), face_top + int(face_h * 0.10)), 1)
        # Demon horns - gradient with ridges
        for s in [-1, 1]:
            hx = cx + s * int(w * 0.18)
            hy = int(h * 0.18)
            base_w = int(w * 0.05)
            tip_x = hx + s * int(w * 0.09)
            tip_y = hy - int(h * 0.20)
            horn_pts = [(hx - s * base_w, hy + int(h * 0.08)),
                        (tip_x, tip_y),
                        (hx + s * int(w * 0.02), hy + int(h * 0.06))]
            pygame.draw.polygon(surf, horn, horn_pts)
            # Horn gradient - lighter tip (more steps)
            for t in range(6):
                tf = (t + 1) / 7.0
                rx = int(hx + (tip_x - hx) * tf)
                ry = int(hy + int(h * 0.07) + (tip_y - hy - int(h * 0.07)) * tf)
                pygame.draw.line(surf, self._mix(horn_dk, horn_lt, tf), (rx - 1, ry), (rx + 1, ry), 1)
            # Horn ridges / rings (concentric growth rings)
            for t in range(3):
                tf = (t + 1) / 4.0
                rx = int(hx + (tip_x - hx) * tf)
                ry = int(hy + int(h * 0.07) + (tip_y - hy - int(h * 0.07)) * tf)
                ring_w = max(1, int(base_w * (1.0 - tf * 0.6)))
                pygame.draw.line(surf, (*horn_dk[:3], 45),
                                 (rx - ring_w, ry - 1), (rx + ring_w, ry - 1), 1)
                pygame.draw.line(surf, (*horn_lt[:3], 30),
                                 (rx - ring_w, ry), (rx + ring_w, ry), 1)
            # Horn specular highlight along edge
            mid_x = int(hx + (tip_x - hx) * 0.5)
            mid_y = int(hy + int(h * 0.07) + (tip_y - hy - int(h * 0.07)) * 0.5)
            pygame.draw.line(surf, (*horn_lt[:3], 35),
                             (hx + s * 1, hy + int(h * 0.06)), (mid_x + s * 1, mid_y), 1)
            # Horn outline
            pygame.draw.polygon(surf, horn_dk, horn_pts, 1)
        # Fierce brow line - thicker, angrier
        for s in [-1, 1]:
            bx1 = cx + s * int(w * 0.03)
            bx2 = cx + s * int(w * 0.19)
            by = int(h * 0.34)
            pygame.draw.line(surf, (80, 20, 20), (bx1, by + 2), (bx2, by - 2), max(1, int(b * 0.13)))
            pygame.draw.line(surf, skin_deep, (bx1, by + 3), (bx2, by - 1), 1)
        # Eyes - fierce yellow with slit pupils
        eye_y = int(h * 0.42)
        eye_sp = int(w * 0.12)
        for s in [-1, 1]:
            self._hq_eye(surf, cx + s * eye_sp, eye_y, w, h, b,
                         eye_color, pupil_color=(40, 10, 10),
                         sclera=(255, 250, 200), sharp=True, slit_pupil=True,
                         glow_color=(255, 200, 40), lid_color=(80, 20, 20))
        # Broad nose - detailed with nostrils
        nose_y = int(h * 0.55)
        self._nose_detail(surf, cx, nose_y, b, skin, skin_dk, skin_lt, w, h)
        # Mouth with fangs - wider, more menacing
        mouth_y = int(h * 0.65)
        mw = int(w * 0.16)
        # Mouth opening (darker, deeper)
        pygame.draw.line(surf, (60, 10, 8), (cx - mw, mouth_y), (cx + mw, mouth_y), max(1, int(b * 0.10)))
        pygame.draw.line(surf, (100, 20, 15), (cx - mw, mouth_y - 1), (cx + mw, mouth_y - 1), max(1, int(b * 0.06)))
        # Mouth corners turned up (snarl)
        for s in [-1, 1]:
            pygame.draw.line(surf, (100, 20, 15), (cx + s * mw, mouth_y),
                             (cx + s * int(mw * 1.1), mouth_y - 2), 1)
            # Corner shadow
            pygame.draw.circle(surf, (60, 10, 8, 35), (cx + s * int(mw * 1.1), mouth_y - 1), max(1, int(b * 0.03)))
        # Gum line
        pygame.draw.line(surf, (140, 30, 25, 40), (cx - int(mw * 0.8), mouth_y + 1),
                         (cx + int(mw * 0.8), mouth_y + 1), 1)
        # Upper fangs - larger with highlights and shadow
        for s in [-1, 1]:
            fx = cx + s * int(mw * 0.55)
            fh = int(h * 0.07)
            # Fang shadow
            pygame.draw.polygon(surf, self._darken(fang, 30),
                                [(fx - 2, mouth_y - 1), (fx, mouth_y + fh + 1), (fx + 2, mouth_y - 1)])
            pygame.draw.polygon(surf, fang, [(fx - 1, mouth_y - 1), (fx, mouth_y + fh), (fx + 1, mouth_y - 1)])
            # Fang highlight
            pygame.draw.line(surf, (255, 255, 255), (fx, mouth_y), (fx, mouth_y + fh // 2), 1)
            # Fang tip glow
            pygame.draw.circle(surf, (255, 255, 240, 40), (fx, mouth_y + fh), max(1, int(b * 0.02)))
        # Lower fangs (smaller with shadow)
        for s in [-1, 1]:
            fx = cx + s * int(mw * 0.3)
            pygame.draw.polygon(surf, self._darken(fang, 20),
                                [(fx - 2, mouth_y + 1), (fx, mouth_y - int(h * 0.03) - 1), (fx + 2, mouth_y + 1)])
            pygame.draw.polygon(surf, fang, [(fx - 1, mouth_y + 1), (fx, mouth_y - int(h * 0.03)), (fx + 1, mouth_y + 1)])
        # Chin shadow - more pronounced oni jaw
        pygame.draw.ellipse(surf, (*skin_deep, 35),
                            (cx - face_w // 4, int(h * 0.74), face_w // 2, int(h * 0.12)))
        # Pronounced jaw / chin with oni features
        pygame.draw.ellipse(surf, (*skin_dk[:3], 25),
                            (cx - int(face_w * 0.35), int(h * 0.72), int(face_w * 0.70), int(h * 0.10)))
        pygame.draw.ellipse(surf, (*skin_lt[:3], 15),
                            (cx - int(face_w * 0.12), int(h * 0.78), int(face_w * 0.24), int(h * 0.04)))
        # Demonic energy emanation (subtle red glow wisps at edges)
        for i in range(8):
            wx = cx + int(_sin(i * 1.8) * w * 0.40)
            wy = int(h * 0.15 + i * h * 0.09)
            wa = max(10, 30 - i * 3)
            self._radial_glow(surf, wx, wy, max(2, int(b * 0.12)), (255, 50, 20), layers=2, max_alpha=wa)
        pygame.draw.rect(surf, (200, 50, 30, 180), (0, 0, w, h), 1, border_radius=2)

    # ─── 5. MARIA (연화/인형사) ───
    def _portrait_maria(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        skin = (250, 235, 230)
        skin_sh = (235, 210, 205)
        skin_hi = (255, 248, 245)
        hair = (200, 130, 180)
        hair_lt = (230, 170, 210)
        hair_dk = (160, 90, 140)
        hair_shine = (240, 195, 225)
        eye_color = (140, 100, 200)
        blush = (255, 160, 160)
        lip = (230, 140, 150)
        lip_hi = (245, 180, 185)
        ribbon = (255, 100, 130)
        ribbon_dk = (200, 70, 100)
        ribbon_hi = (255, 150, 170)
        # Soft pink background with sparkle atmosphere (radial glow for richer aura)
        pygame.draw.rect(surf, (55, 28, 48, 60), (0, 0, w, h))
        self._radial_glow(surf, cx, int(h * 0.4), max(7, int(w * 0.40)), (200, 100, 160), layers=5, max_alpha=16)
        self._radial_glow(surf, cx - int(w * 0.12), int(h * 0.3), max(4, int(w * 0.20)), (220, 140, 180), layers=3, max_alpha=10)
        self._radial_glow(surf, cx + int(w * 0.10), int(h * 0.55), max(4, int(w * 0.18)), (190, 80, 150), layers=3, max_alpha=8)
        # Subtle sparkle / glitter particles
        import random as _rng_ma
        _rng_ma_inst = _rng_ma.Random(555)
        for _ in range(10):
            sx = _rng_ma_inst.randint(3, w - 3)
            sy = _rng_ma_inst.randint(3, h - 3)
            sa = _rng_ma_inst.randint(20, 55)
            pygame.draw.circle(surf, (255, 230, 240, sa), (sx, sy), 1)
            # Cross sparkle shape
            pygame.draw.line(surf, (255, 240, 245, sa // 2), (sx - 1, sy), (sx + 1, sy), 1)
            pygame.draw.line(surf, (255, 240, 245, sa // 2), (sx, sy - 1), (sx, sy + 1), 1)
        # Fluffy hair - back volume with layers
        hair_back = pygame.Rect(cx - int(w * 0.48), 0, int(w * 0.96), int(h * 0.76))
        pygame.draw.ellipse(surf, hair_dk, hair_back)
        pygame.draw.ellipse(surf, hair, (hair_back.x + 2, hair_back.y + 1, hair_back.w - 4, hair_back.h - 3))
        # Hair side puffs with depth
        for s in [-1, 1]:
            px = cx + s * int(w * 0.35)
            pygame.draw.ellipse(surf, hair_dk, (px - int(w * 0.15), int(h * 0.24), int(w * 0.30), int(h * 0.47)))
            pygame.draw.ellipse(surf, hair, (px - int(w * 0.14), int(h * 0.25), int(w * 0.28), int(h * 0.45)))
            pygame.draw.ellipse(surf, hair_lt, (px - int(w * 0.10), int(h * 0.28), int(w * 0.15), int(h * 0.20)))
            # Shine on puff
            pygame.draw.ellipse(surf, (*hair_shine, 35), (px - int(w * 0.06), int(h * 0.30), int(w * 0.08), int(h * 0.10)))
        # Face - 4-layer porcelain shading
        face_w = int(w * 0.50)
        face_h = int(h * 0.65)
        face_top = int(h * 0.22)
        self._face_base(surf, cx, face_top, face_w, face_h, skin, skin_sh, skin_hi)
        self._face_detail(surf, cx, face_top, face_w, face_h, skin_sh, skin_hi)
        # Beauty mark / freckle detail
        pygame.draw.circle(surf, (180, 150, 145), (cx + int(w * 0.08), int(h * 0.58)), max(1, int(b * 0.02)))
        # Hair bangs - rounder, softer with overlap
        bang_y = int(h * 0.22)
        for i in range(6):
            bx = cx + int((i - 2.5) * w * 0.07)
            by_end = bang_y + int(h * 0.11) + (i % 2) * int(h * 0.04)
            bw = int(w * 0.11)
            pygame.draw.ellipse(surf, hair, (bx - bw // 2, int(h * 0.07), bw, by_end - int(h * 0.04)))
        # Hair shine streaks (more, varied)
        for dx in [-0.16, -0.10, -0.04, 0.02, 0.08, 0.14]:
            pygame.draw.line(surf, hair_shine, (cx + int(dx * w), int(h * 0.06)),
                             (cx + int(dx * w), int(h * 0.26)), 1)
        # Hair strand highlights (multiple reflection lines)
        pygame.draw.line(surf, hair_lt, (cx - int(w * 0.08), int(h * 0.08)),
                         (cx - int(w * 0.05), int(h * 0.30)), 1)
        pygame.draw.line(surf, (*hair_shine[:3], 40), (cx + int(w * 0.04), int(h * 0.06)),
                         (cx + int(w * 0.06), int(h * 0.28)), 1)
        pygame.draw.line(surf, (*hair_lt[:3], 35), (cx - int(w * 0.14), int(h * 0.10)),
                         (cx - int(w * 0.12), int(h * 0.28)), 1)
        # Individual flyaway hairs (thin lines extending past hair mass)
        for fx, fy, fa in [(-0.38, 0.15, 0.06), (0.40, 0.18, -0.04),
                           (-0.42, 0.35, 0.10), (0.44, 0.30, -0.08)]:
            pygame.draw.line(surf, (*hair[:3], 35),
                             (cx + int(fx * w), int(fy * h)),
                             (cx + int((fx + fa) * w), int((fy - 0.06) * h)), 1)
        # Ribbon bow on top - more detailed
        rib_y = int(h * 0.05)
        rib_cx = cx + int(w * 0.15)
        for s in [-1, 1]:
            bow_pts = [(rib_cx, rib_y + int(h * 0.03)),
                       (rib_cx + s * int(w * 0.11), rib_y - int(h * 0.02)),
                       (rib_cx + s * int(w * 0.09), rib_y + int(h * 0.07))]
            pygame.draw.polygon(surf, ribbon, bow_pts)
            # Bow highlight
            inner = [(rib_cx + s * int(w * 0.02), rib_y + int(h * 0.03)),
                     (rib_cx + s * int(w * 0.08), rib_y),
                     (rib_cx + s * int(w * 0.07), rib_y + int(h * 0.04))]
            pygame.draw.polygon(surf, ribbon_hi, inner)
            pygame.draw.polygon(surf, ribbon_dk, bow_pts, 1)
        # Bow center knot (enhanced)
        pygame.draw.circle(surf, ribbon_dk, (rib_cx, rib_y + int(h * 0.03)), max(2, int(b * 0.09)))
        pygame.draw.circle(surf, ribbon, (rib_cx, rib_y + int(h * 0.02)), max(1, int(b * 0.06)))
        pygame.draw.circle(surf, ribbon_hi, (rib_cx - 1, rib_y + int(h * 0.02)), max(1, int(b * 0.03)))
        # Ribbon fold inner shadows
        for s in [-1, 1]:
            fold_x = rib_cx + s * int(w * 0.06)
            fold_y = rib_y + int(h * 0.03)
            pygame.draw.line(surf, (*ribbon_dk[:3], 30), (fold_x, fold_y - int(h * 0.01)),
                             (fold_x + s * int(w * 0.02), fold_y + int(h * 0.02)), 1)
        # Ribbon tail droops
        for s in [-1, 1]:
            tail_pts = [(rib_cx + s * int(w * 0.08), rib_y + int(h * 0.06)),
                        (rib_cx + s * int(w * 0.10), rib_y + int(h * 0.12)),
                        (rib_cx + s * int(w * 0.06), rib_y + int(h * 0.11))]
            pygame.draw.lines(surf, (*ribbon[:3], 80), False, tail_pts, 1)
        # Big doll eyes - enhanced with _hq_eye
        eye_y = int(h * 0.44)
        eye_sp = int(w * 0.10)
        for s in [-1, 1]:
            self._hq_eye(surf, cx + s * eye_sp, eye_y, w, h, b,
                         eye_color, pupil_color=(30, 20, 50), sclera=(255, 255, 255),
                         lid_color=(80, 40, 70), eye_scale=1.15)
            # Extra large sparkle for doll-eye effect
            ex = cx + s * eye_sp
            ir = max(3, int(min(w * 0.08, h * 0.065) * 0.75 * 1.15))
            pygame.draw.circle(surf, (255, 255, 255), (ex + s * 2, eye_y - max(2, ir // 2)),
                               max(1, ir // 2))
        # Thick upper lashes (more defined for doll-like character)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            sw = max(3, int(w * 0.09))
            sh = max(2, int(h * 0.075))
            # Main thick lash line
            pygame.draw.arc(surf, (60, 30, 60),
                            (ex - sw - 1, eye_y - sh - 2, sw * 2 + 2, sh * 2),
                            0.2, 2.9, max(1, int(b * 0.08)))
            # Individual lash spikes extending upward
            for li in range(4):
                lash_angle = 0.6 + li * 0.5
                lx1 = ex + int(_cos(lash_angle) * sw)
                ly1 = eye_y - int(_sin(lash_angle) * sh)
                lx2 = lx1 + int(_cos(lash_angle) * max(1, int(b * 0.06)))
                ly2 = ly1 - int(_sin(lash_angle) * max(1, int(b * 0.08)))
                pygame.draw.line(surf, (50, 25, 50), (lx1, ly1), (lx2, ly2), 1)
            # Lower lash hints (thinner)
            pygame.draw.arc(surf, (80, 50, 70, 30),
                            (ex - sw, eye_y - sh + 2, sw * 2, sh * 2),
                            3.8, 5.6, 1)
        # Rosy cheeks - softer multi-layer gradient
        for s in [-1, 1]:
            chx = cx + s * int(w * 0.14)
            chy = int(h * 0.54)
            # Outermost blush (very soft)
            pygame.draw.ellipse(surf, (*blush, 15),
                                (chx - int(w * 0.08), chy - int(h * 0.05), int(w * 0.16), int(h * 0.10)))
            pygame.draw.ellipse(surf, (*blush, 30),
                                (chx - int(w * 0.06), chy - int(h * 0.04), int(w * 0.12), int(h * 0.08)))
            pygame.draw.ellipse(surf, (*blush, 50),
                                (chx - int(w * 0.04), chy - int(h * 0.02), int(w * 0.08), int(h * 0.05)))
            # Bright core
            pygame.draw.ellipse(surf, (*self._lighten(blush, 20)[:3], 25),
                                (chx - int(w * 0.02), chy - int(h * 0.01), int(w * 0.04), int(h * 0.03)))
        # Cute nose - detailed dainty nose
        nose_y = int(h * 0.54)
        self._nose_detail(surf, cx, nose_y, b, skin, skin_sh, skin_hi, w, h)
        # Sweet lips - detailed with cupid's bow
        mouth_y = int(h * 0.63)
        self._lips(surf, cx, mouth_y, b, lip, lip_hi, w_frac=0.10)
        pygame.draw.rect(surf, (*ribbon, 180), (0, 0, w, h), 1, border_radius=2)

    # ─── 6. IGNIS (이그니스/용기사) ───
    def _portrait_ignis(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        helmet = (180, 50, 30)
        helmet_lt = (220, 90, 50)
        helmet_dk = (130, 30, 20)
        helmet_hi = (240, 120, 70)
        gold = (220, 190, 80)
        gold_dk = (180, 150, 50)
        gold_lt = (245, 220, 110)
        skin = (230, 200, 175)
        skin_sh = (200, 170, 145)
        skin_hi = (248, 228, 205)
        hair = (240, 120, 40)
        hair_lt = (255, 170, 70)
        hair_bright = (255, 200, 100)
        eye_color = (200, 100, 30)
        eye_hi = (255, 200, 100)
        # Fiery background - multi-layer
        self._soft_glow(surf, cx, int(h * 0.3), max(6, int(w * 0.45)), (200, 80, 20), 18)
        self._soft_glow(surf, cx + int(w * 0.1), int(h * 0.2), max(4, int(w * 0.2)), (255, 120, 30), 10)
        # Fiery hair coming out from under helmet - drawn BEHIND helmet
        for i in range(10):
            hx = cx + int((i - 4.5) * w * 0.07)
            hy_start = int(h * 0.06)
            hy_end = int(h * -0.06) - (i % 3) * int(h * 0.05)
            hair_c = hair if i % 2 == 0 else hair_lt
            sw2 = int(w * 0.035)
            pygame.draw.polygon(surf, hair_c, [(hx - sw2, hy_start), (hx, hy_end), (hx + sw2, hy_start)])
            # Bright tip
            pygame.draw.line(surf, hair_bright, (hx, hy_end), (hx, hy_end + int(h * 0.03)), 1)
        # Dragon helmet - detailed with gradient
        helm_pts = [(cx - int(w * 0.46), int(h * 0.50)),
                    (cx - int(w * 0.43), int(h * 0.10)),
                    (cx - int(w * 0.22), int(h * 0.02)),
                    (cx, int(h * -0.02)),
                    (cx + int(w * 0.22), int(h * 0.02)),
                    (cx + int(w * 0.43), int(h * 0.10)),
                    (cx + int(w * 0.46), int(h * 0.50))]
        pygame.draw.polygon(surf, helmet, helm_pts)
        # Helmet shading layers
        pygame.draw.polygon(surf, helmet_dk, [(cx - int(w * 0.44), int(h * 0.38)),
                                               (cx - int(w * 0.42), int(h * 0.50)),
                                               (cx + int(w * 0.42), int(h * 0.50)),
                                               (cx + int(w * 0.44), int(h * 0.38))], 0)
        pygame.draw.polygon(surf, helmet, [(cx - int(w * 0.42), int(h * 0.10)),
                                            (cx - int(w * 0.20), int(h * 0.02)),
                                            (cx + int(w * 0.20), int(h * 0.02)),
                                            (cx + int(w * 0.42), int(h * 0.10)),
                                            (cx + int(w * 0.35), int(h * 0.30)),
                                            (cx - int(w * 0.35), int(h * 0.30))], 0)
        # Helmet specular highlight
        pygame.draw.ellipse(surf, (*helmet_hi, 45),
                            (cx - int(w * 0.15), int(h * 0.06), int(w * 0.30), int(h * 0.16)))
        # Center ridge - gold with highlight
        ridge_w = max(1, int(b * 0.10))
        pygame.draw.line(surf, gold, (cx, int(h * -0.02)), (cx, int(h * 0.50)), ridge_w)
        pygame.draw.line(surf, gold_lt, (cx - 1, int(h * 0.0)), (cx - 1, int(h * 0.35)), 1)
        # Side ridges
        for s in [-1, 1]:
            pygame.draw.line(surf, gold_dk, (cx + s * int(w * 0.20), int(h * 0.05)),
                             (cx + s * int(w * 0.40), int(h * 0.48)), max(1, int(b * 0.06)))
            pygame.draw.line(surf, gold, (cx + s * int(w * 0.21), int(h * 0.05)),
                             (cx + s * int(w * 0.39), int(h * 0.46)), 1)
        # Visor slit for eyes - deeper with inner glow
        visor_y = int(h * 0.38)
        visor_h2 = max(4, int(h * 0.09))
        visor_rect = pygame.Rect(cx - int(w * 0.32), visor_y, int(w * 0.64), visor_h2)
        pygame.draw.rect(surf, (5, 2, 2), visor_rect, border_radius=2)
        # Visor inner glow
        pygame.draw.rect(surf, (30, 10, 5), (visor_rect.x + 1, visor_rect.y + 1,
                                              visor_rect.w - 2, visor_rect.h - 2), 1, border_radius=1)
        # Eyes through visor with glow
        eye_sp = int(w * 0.12)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            ey = visor_y + visor_h2 // 2
            self._soft_glow(surf, ex, ey, max(3, int(b * 0.3)), eye_color, 20)
            ir = max(2, visor_h2 // 2)
            pygame.draw.circle(surf, self._darken(eye_color, 30), (ex, ey), ir + 1)
            pygame.draw.circle(surf, eye_color, (ex, ey), ir)
            pygame.draw.circle(surf, eye_hi, (ex + s, ey - 1), max(1, ir // 2))
        # Lower face - 4-layer shading
        lower_top = int(h * 0.48)
        face_w = int(w * 0.52)
        face_h = int(h * 0.48)
        self._face_base(surf, cx, lower_top, face_w, face_h, skin, skin_sh, skin_hi)
        # Nose bridge + tip
        pygame.draw.line(surf, skin_sh, (cx, int(h * 0.55)), (cx - 1, int(h * 0.63)), 1)
        pygame.draw.circle(surf, (*skin_hi, 70), (cx, int(h * 0.58)), max(1, b // 10))
        # Determined mouth with lip detail
        mouth_y = int(h * 0.72)
        pygame.draw.line(surf, (180, 130, 110), (cx - int(w * 0.07), mouth_y),
                         (cx + int(w * 0.07), mouth_y), 1)
        pygame.draw.line(surf, (*skin_sh, 60), (cx - int(w * 0.05), mouth_y + 1),
                         (cx + int(w * 0.05), mouth_y + 1), 1)
        # Side hair wisps - enhanced
        for s in [-1, 1]:
            for j in range(4):
                sx = cx + s * int(w * 0.43)
                sy = int(h * 0.32 + j * h * 0.07)
                hc = hair if j % 2 == 0 else hair_lt
                pygame.draw.line(surf, hc, (sx, sy),
                                 (sx + s * int(w * 0.09), sy + int(h * 0.08)),
                                 max(1, int(b * 0.07) - j // 2))
        # Helmet outline
        pygame.draw.polygon(surf, helmet_dk, helm_pts, 1)
        pygame.draw.rect(surf, (*gold, 180), (0, 0, w, h), 1, border_radius=2)

    # ─── 7. GEAR (기어/스팀펑크) ───
    def _portrait_gear(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        skin = (215, 185, 150)
        skin_sh = (190, 160, 125)
        skin_hi = (240, 215, 185)
        hair = (120, 80, 50)
        hair_dk = (90, 60, 35)
        hair_lt = (155, 115, 75)
        goggle = (180, 120, 50)
        goggle_lt = (210, 160, 80)
        goggle_dk = (140, 90, 35)
        goggle_hi = (235, 190, 110)
        lens = (180, 220, 240)
        lens_hi = (220, 245, 255)
        oil = (60, 50, 40)
        cog = (170, 140, 90)
        cog_dk = (130, 105, 65)
        # Warm background
        pygame.draw.rect(surf, (45, 32, 22, 85), (0, 0, w, h))
        self._soft_glow(surf, cx, int(h * 0.4), max(5, int(w * 0.3)), (150, 100, 50), 10)
        # Messy brown hair - layered with dark base
        hair_base = pygame.Rect(cx - int(w * 0.46), int(h * 0.01), int(w * 0.92), int(h * 0.50))
        pygame.draw.ellipse(surf, hair_dk, hair_base)
        pygame.draw.ellipse(surf, hair, (hair_base.x + 2, hair_base.y + 1, hair_base.w - 4, hair_base.h - 3))
        # Messy tufts - more varied
        for xf, yf, sw2 in [(-0.32, 0.0, 0.08), (-0.18, -0.04, 0.07), (-0.02, -0.06, 0.09),
                             (0.14, -0.03, 0.07), (0.28, 0.01, 0.08), (-0.08, -0.05, 0.06)]:
            tx = cx + int(xf * w)
            ty = int(h * (0.05 + yf))
            pygame.draw.ellipse(surf, hair, (tx - int(sw2 * w), ty, int(sw2 * 2 * w), int(h * 0.18)))
        # Hair shine streaks
        for dx in [-0.12, -0.02, 0.08, 0.20]:
            pygame.draw.line(surf, hair_lt, (cx + int(dx * w), int(h * 0.07)),
                             (cx + int(dx * w) + 1, int(h * 0.25)), 1)
        # Round friendly face - 4-layer
        face_w = int(w * 0.56)
        face_h = int(h * 0.68)
        face_top = int(h * 0.22)
        self._face_base(surf, cx, face_top, face_w, face_h, skin, skin_sh, skin_hi)
        # Goggles on forehead - enhanced detail
        gog_y = int(h * 0.17)
        gog_h2 = max(5, int(h * 0.13))
        # Leather strap
        pygame.draw.rect(surf, goggle_dk, (cx - int(w * 0.40), gog_y + gog_h2 // 4, int(w * 0.80), gog_h2 // 2))
        pygame.draw.line(surf, goggle, (cx - int(w * 0.40), gog_y + gog_h2 // 4),
                         (cx + int(w * 0.40), gog_y + gog_h2 // 4), 1)
        # Lens housings with brass rim
        for s in [-1, 1]:
            gx = cx + s * int(w * 0.12)
            gy = gog_y + gog_h2 // 2
            lr = max(3, int(h * 0.065))
            # Outer brass ring
            pygame.draw.circle(surf, goggle_dk, (gx, gy), lr + 3)
            pygame.draw.circle(surf, goggle, (gx, gy), lr + 2)
            pygame.draw.circle(surf, goggle_hi, (gx - 1, gy - 1), lr + 2, 1)
            # Lens with reflection
            pygame.draw.circle(surf, lens, (gx, gy), lr)
            pygame.draw.circle(surf, lens_hi, (gx + s, gy - 1), max(1, lr // 3))
            pygame.draw.circle(surf, (255, 255, 255, 100), (gx + s * 2, gy - 2), max(1, lr // 4))
            # Screws on housing
            for ang in [0.8, 2.3, 3.8, 5.3]:
                scx = gx + int(_cos(ang) * (lr + 2))
                scy = gy + int(_sin(ang) * (lr + 2))
                pygame.draw.circle(surf, goggle_dk, (scx, scy), max(1, int(b * 0.03)))
        # Bridge connector
        pygame.draw.line(surf, goggle, (cx - int(w * 0.04), gy),
                         (cx + int(w * 0.04), gy), max(1, int(b * 0.08)))
        # Eyes - friendly warm brown
        eye_y = int(h * 0.44)
        eye_sp = int(w * 0.11)
        for s in [-1, 1]:
            self._hq_eye(surf, cx + s * eye_sp, eye_y, w, h, b,
                         (100, 70, 40), pupil_color=(30, 20, 15),
                         lid_color=(80, 55, 35))
        # Thick friendly eyebrows
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = eye_y - max(3, int(h * 0.07))
            pygame.draw.line(surf, hair, (bx - s * int(w * 0.05), by + 1),
                             (bx + s * int(w * 0.05), by), max(1, int(b * 0.09)))
        # Round nose with highlight
        pygame.draw.circle(surf, skin_sh, (cx, int(h * 0.56)), max(2, int(b * 0.10)))
        pygame.draw.circle(surf, skin_hi, (cx - 1, int(h * 0.55)), max(1, int(b * 0.05)))
        # Friendly grin
        mouth_y = int(h * 0.66)
        pygame.draw.arc(surf, (160, 110, 90),
                        (cx - int(w * 0.09), mouth_y - int(h * 0.03), int(w * 0.18), int(h * 0.09)), 3.3, 6.1, 1)
        # Teeth hint
        pygame.draw.line(surf, (245, 240, 230), (cx - int(w * 0.04), mouth_y + int(h * 0.01)),
                         (cx + int(w * 0.04), mouth_y + int(h * 0.01)), 1)
        # Oil smudges - varied
        for s, ox_off, oy_off, ow, oh in [(-1, 0.18, 0.52, 0.05, 0.03),
                                            (1, 0.16, 0.55, 0.04, 0.02),
                                            (-1, 0.22, 0.48, 0.03, 0.02)]:
            ox = cx + s * int(ox_off * w)
            oy = int(oy_off * h)
            pygame.draw.ellipse(surf, (*oil, 55), (ox - int(ow * w), oy, int(ow * 2 * w), int(oh * h)))
        # Enhanced cog decorations
        for s in [-1, 1]:
            cog_x = cx + s * int(w * 0.30)
            cog_y = int(h * 0.40)
            cr = max(2, int(b * 0.16))
            # Cog teeth
            for a in range(8):
                angle = a * 3.14159 / 4
                tx = cog_x + int(_cos(angle) * cr)
                ty = cog_y + int(_sin(angle) * cr)
                pygame.draw.circle(surf, cog, (tx, ty), max(1, cr // 3))
            # Cog body
            pygame.draw.circle(surf, cog, (cog_x, cog_y), cr)
            pygame.draw.circle(surf, cog_dk, (cog_x, cog_y), cr, 1)
            # Center hole
            pygame.draw.circle(surf, goggle_dk, (cog_x, cog_y), max(1, cr // 3))
            pygame.draw.circle(surf, cog, (cog_x, cog_y), max(1, cr // 4))
        pygame.draw.rect(surf, (*goggle, 180), (0, 0, w, h), 1, border_radius=2)

    # ─── 8. KUROKAGE (쿠로카게/닌자) ───
    def _portrait_kurokage(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        cloth = (30, 25, 35)
        cloth_mid = (40, 35, 48)
        cloth_lt = (55, 48, 62)
        cloth_dk = (15, 12, 20)
        cloth_deep = (8, 6, 12)
        skin = (215, 190, 165)
        skin_sh = (185, 160, 135)
        skin_hi = (235, 215, 195)
        eye_color = (180, 200, 220)
        scar = (200, 140, 130)
        scar_dk = (170, 110, 100)
        # Dark background with shadow wisps
        pygame.draw.rect(surf, (8, 6, 12, 160), (0, 0, w, h))
        self._soft_glow(surf, cx, int(h * 0.4), max(4, int(w * 0.25)), (30, 25, 50), 10)
        # Hood/cowl - more detailed fabric
        hood_pts = [(0, 0), (w, 0), (w, int(h * 0.6)),
                    (cx + int(w * 0.40), int(h * 0.80)),
                    (cx, int(h * 0.92)),
                    (cx - int(w * 0.40), int(h * 0.80)),
                    (0, int(h * 0.6))]
        pygame.draw.polygon(surf, cloth, hood_pts)
        # Hood fold shading - fabric depth
        pygame.draw.polygon(surf, cloth_mid,
                            [(cx - int(w * 0.12), int(h * 0.03)),
                             (cx - int(w * 0.18), int(h * 0.52)),
                             (cx - int(w * 0.10), int(h * 0.50)),
                             (cx - int(w * 0.06), int(h * 0.02))])
        pygame.draw.polygon(surf, cloth_mid,
                            [(cx + int(w * 0.06), int(h * 0.02)),
                             (cx + int(w * 0.10), int(h * 0.50)),
                             (cx + int(w * 0.18), int(h * 0.52)),
                             (cx + int(w * 0.12), int(h * 0.03))])
        # Hood highlight lines
        pygame.draw.line(surf, cloth_lt, (cx - int(w * 0.09), int(h * 0.04)),
                         (cx - int(w * 0.14), int(h * 0.50)), 1)
        pygame.draw.line(surf, cloth_lt, (cx + int(w * 0.09), int(h * 0.04)),
                         (cx + int(w * 0.14), int(h * 0.50)), 1)
        # Visible skin strip - eye area with 3-layer shading
        strip_top = int(h * 0.28)
        strip_h2 = int(h * 0.18)
        strip_pts = [(cx - int(w * 0.33), strip_top),
                     (cx + int(w * 0.33), strip_top),
                     (cx + int(w * 0.31), strip_top + strip_h2),
                     (cx - int(w * 0.31), strip_top + strip_h2)]
        pygame.draw.polygon(surf, skin, strip_pts)
        # Skin shading
        pygame.draw.polygon(surf, skin_sh, [(cx - int(w * 0.31), strip_top + strip_h2 // 2),
                                            (cx + int(w * 0.31), strip_top + strip_h2 // 2),
                                            (cx + int(w * 0.31), strip_top + strip_h2),
                                            (cx - int(w * 0.31), strip_top + strip_h2)])
        # Skin highlight on bridge
        pygame.draw.ellipse(surf, (*skin_hi, 35),
                            (cx - int(w * 0.08), strip_top + 1, int(w * 0.16), strip_h2 // 2))
        # Mask covering lower face - with depth
        mask_top = strip_top + strip_h2
        mask_pts = [(cx - int(w * 0.33), mask_top),
                    (cx + int(w * 0.33), mask_top),
                    (cx + int(w * 0.26), int(h * 0.85)),
                    (cx, int(h * 0.93)),
                    (cx - int(w * 0.26), int(h * 0.85))]
        pygame.draw.polygon(surf, cloth_deep, mask_pts)
        # Mask fabric folds
        pygame.draw.line(surf, cloth_lt, (cx, mask_top + 2), (cx, int(h * 0.82)), 1)
        for s in [-1, 1]:
            pygame.draw.line(surf, (*cloth_mid, 60), (cx + s * int(w * 0.12), mask_top + 3),
                             (cx + s * int(w * 0.10), int(h * 0.78)), 1)
        # Mask stitch line
        pygame.draw.line(surf, cloth_lt, (cx - int(w * 0.25), mask_top + int(h * 0.05)),
                         (cx + int(w * 0.25), mask_top + int(h * 0.05)), 1)
        # Sharp piercing eyes - enhanced
        eye_y = strip_top + strip_h2 // 2
        eye_sp = int(w * 0.13)
        for s in [-1, 1]:
            self._hq_eye(surf, cx + s * eye_sp, eye_y, w, h, b,
                         eye_color, pupil_color=(15, 15, 25),
                         sclera=(240, 240, 245), sharp=True,
                         glow_color=None, lid_color=(50, 40, 45))
        # Intense brow furrow
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = strip_top + 1
            pygame.draw.line(surf, skin_sh, (bx - s * int(w * 0.06), by + 2),
                             (bx + s * int(w * 0.04), by - 1), max(1, int(b * 0.07)))
        # Scar across right eye - enhanced with depth
        sc_x = cx + int(w * 0.13)
        pygame.draw.line(surf, scar_dk, (sc_x - int(w * 0.02), strip_top - int(h * 0.04)),
                         (sc_x + int(w * 0.02), strip_top + strip_h2 + int(h * 0.06)),
                         max(1, int(b * 0.07)))
        pygame.draw.line(surf, scar, (sc_x - int(w * 0.02) + 1, strip_top - int(h * 0.04)),
                         (sc_x + int(w * 0.02) + 1, strip_top + strip_h2 + int(h * 0.06)), 1)
        # Shadow wisps around edges
        for i in range(4):
            wy = int(h * 0.15 + i * h * 0.18)
            for s in [-1, 1]:
                wx = cx + s * int(w * (0.35 + _sin(i * 1.5) * 0.05))
                pygame.draw.circle(surf, (*cloth_dk, 30), (wx, wy), max(1, int(b * 0.08)))
        pygame.draw.rect(surf, (*cloth_lt, 150), (0, 0, w, h), 1, border_radius=2)

    # ─── 9. BANSHEE (밴시/해골) ───
    def _portrait_banshee(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        bone = (230, 220, 210)
        bone_sh = (190, 180, 170)
        bone_dk = (160, 150, 140)
        bone_deep = (130, 120, 110)
        bone_hi = (248, 244, 238)
        gold_mask = (220, 190, 80)
        gold_dk = (180, 150, 50)
        gold_lt = (245, 220, 120)
        gold_hi = (255, 240, 160)
        eye_color = (60, 220, 240)
        eye_glow = (80, 255, 255)
        ghost_hair = (180, 200, 220)
        ghost_lt = (210, 225, 240)
        # Dark ethereal background - layered
        pygame.draw.rect(surf, (12, 18, 28, 150), (0, 0, w, h))
        self._soft_glow(surf, cx, int(h * 0.35), max(6, int(w * 0.35)), eye_color, 12)
        self._soft_glow(surf, cx - int(w * 0.1), int(h * 0.25), max(4, int(w * 0.2)), (40, 160, 200), 8)
        # Wispy ghost hair - more strands with glow
        for i in range(8):
            hx = cx + int((i - 3.5) * w * 0.10)
            pts = [(hx, int(h * 0.04))]
            for t in range(5):
                tf = (t + 1) / 5.0
                hy = int(h * 0.04 + h * 0.38 * tf)
                wave = int(_sin(tf * 4.5 + i * 1.1) * w * 0.04)
                pts.append((hx + wave, hy))
            if len(pts) >= 2:
                for j in range(len(pts) - 1):
                    alpha = 200 - j * 35
                    tc = ghost_hair if j < 2 else ghost_lt
                    pygame.draw.line(surf, (*tc, max(30, alpha)), pts[j], pts[j + 1],
                                     max(1, int(b * 0.09) - j))
        # Skull face - enhanced shading
        face_w = int(w * 0.54)
        face_h = int(h * 0.62)
        face_top = int(h * 0.15)
        fr = pygame.Rect(cx - face_w // 2, face_top, face_w, face_h)
        pygame.draw.ellipse(surf, bone, fr)
        # Multi-layer skull shading
        pygame.draw.ellipse(surf, bone_deep,
                            (fr.x + 1, face_top + int(face_h * 0.65), face_w - 2, int(face_h * 0.35)))
        pygame.draw.ellipse(surf, bone_sh,
                            (fr.x, face_top + int(face_h * 0.5), face_w, int(face_h * 0.5)))
        pygame.draw.ellipse(surf, bone,
                            (fr.x + 2, face_top, face_w - 4, int(face_h * 0.58)))
        # Skull specular highlight
        pygame.draw.ellipse(surf, (*bone_hi, 50),
                            (cx - int(face_w * 0.25), face_top + int(face_h * 0.06), int(face_w * 0.4), int(face_h * 0.2)))
        # Cracks - more detailed branching
        c1s = (cx - int(w * 0.08), face_top + int(face_h * 0.10))
        c1m = (cx - int(w * 0.10), face_top + int(face_h * 0.28))
        c1e = (cx - int(w * 0.06), face_top + int(face_h * 0.40))
        pygame.draw.line(surf, bone_dk, c1s, c1m, 1)
        pygame.draw.line(surf, bone_dk, c1m, c1e, 1)
        pygame.draw.line(surf, bone_dk, c1m, (c1m[0] - int(w * 0.05), c1m[1] + int(h * 0.06)), 1)
        # Second crack on right
        c2s = (cx + int(w * 0.06), face_top + int(face_h * 0.18))
        c2e = (cx + int(w * 0.10), face_top + int(face_h * 0.35))
        pygame.draw.line(surf, bone_dk, c2s, c2e, 1)
        pygame.draw.line(surf, bone_dk, c2e, (c2e[0] + int(w * 0.03), c2e[1] + int(h * 0.04)), 1)
        # Temporal bone ridges
        for s in [-1, 1]:
            pygame.draw.arc(surf, (*bone_sh, 50),
                            (cx + s * int(w * 0.10) - int(w * 0.08), face_top + int(face_h * 0.15),
                             int(w * 0.16), int(face_h * 0.3)), 1.0 if s > 0 else 4.0, 2.5 if s > 0 else 5.5, 1)
        # Eye sockets - deeper with double glow
        eye_y = int(h * 0.35)
        eye_sp = int(w * 0.11)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            sock_w = max(4, int(w * 0.10))
            sock_h = max(4, int(h * 0.10))
            # Deep socket
            pygame.draw.ellipse(surf, (10, 15, 20),
                                (ex - sock_w - 1, eye_y - sock_h - 1, sock_w * 2 + 2, sock_h * 2 + 2))
            pygame.draw.ellipse(surf, (20, 25, 30),
                                (ex - sock_w, eye_y - sock_h, sock_w * 2, sock_h * 2))
            # Double glow
            self._soft_glow(surf, ex, eye_y, max(4, sock_w), eye_color, 30)
            self._soft_glow(surf, ex, eye_y, max(3, sock_w // 2), eye_glow, 20)
            # Eye orb
            ir = max(2, int(min(sock_w, sock_h) * 0.5))
            pygame.draw.circle(surf, self._darken(eye_color, 30), (ex, eye_y), ir + 1)
            pygame.draw.circle(surf, eye_color, (ex, eye_y), ir)
            pygame.draw.circle(surf, eye_glow, (ex, eye_y), max(1, ir // 2))
            pygame.draw.circle(surf, (255, 255, 255), (ex + s, eye_y - 1), max(1, ir // 3))
        # Nose cavity - deeper detail
        nose_y = int(h * 0.50)
        pygame.draw.polygon(surf, (30, 30, 25),
                            [(cx - int(w * 0.025), nose_y - int(h * 0.035)),
                             (cx + int(w * 0.025), nose_y - int(h * 0.035)),
                             (cx, nose_y + int(h * 0.025))])
        pygame.draw.polygon(surf, bone_dk,
                            [(cx - int(w * 0.025), nose_y - int(h * 0.035)),
                             (cx + int(w * 0.025), nose_y - int(h * 0.035)),
                             (cx, nose_y + int(h * 0.025))], 1)
        # Golden jaw mask - enhanced with engravings
        mask_top = int(h * 0.55)
        mask_pts = [(cx - int(w * 0.30), mask_top),
                    (cx + int(w * 0.30), mask_top),
                    (cx + int(w * 0.25), int(h * 0.85)),
                    (cx, int(h * 0.95)),
                    (cx - int(w * 0.25), int(h * 0.85))]
        pygame.draw.polygon(surf, gold_mask, mask_pts)
        # Mask shading gradient
        pygame.draw.polygon(surf, gold_dk,
                            [(cx - int(w * 0.28), mask_top + int(h * 0.15)),
                             (cx + int(w * 0.28), mask_top + int(h * 0.15)),
                             (cx + int(w * 0.24), int(h * 0.85)),
                             (cx, int(h * 0.95)),
                             (cx - int(w * 0.24), int(h * 0.85))])
        pygame.draw.polygon(surf, gold_mask,
                            [(cx - int(w * 0.28), mask_top),
                             (cx + int(w * 0.28), mask_top),
                             (cx + int(w * 0.26), mask_top + int(h * 0.12)),
                             (cx - int(w * 0.26), mask_top + int(h * 0.12))])
        # Mask center line + side lines
        pygame.draw.line(surf, gold_lt, (cx, mask_top + 2), (cx, int(h * 0.90)), 1)
        for s in [-1, 1]:
            pygame.draw.line(surf, gold_dk, (cx + s * int(w * 0.12), mask_top + 3),
                             (cx + s * int(w * 0.10), int(h * 0.82)), 1)
        # Mask highlight
        pygame.draw.ellipse(surf, (*gold_hi, 30),
                            (cx - int(w * 0.10), mask_top + 2, int(w * 0.20), int(h * 0.08)))
        # Rivets with highlight
        for s in [-1, 1]:
            for j in range(3):
                ry = mask_top + int(h * 0.06) + j * int(h * 0.10)
                rx = cx + s * int(w * (0.22 - j * 0.04))
                pygame.draw.circle(surf, gold_lt, (rx, ry), max(1, int(b * 0.045)))
                pygame.draw.circle(surf, gold_hi, (rx, ry - 1), max(1, int(b * 0.02)))
        pygame.draw.polygon(surf, gold_dk, mask_pts, 1)
        pygame.draw.rect(surf, (*eye_color, 150), (0, 0, w, h), 1, border_radius=2)

    # ─── 10. NECRO (네크로/사령술사) ───
    def _portrait_necro(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        skin = (170, 150, 175)
        skin_sh = (140, 120, 145)
        skin_hi = (195, 180, 200)
        skin_deep = (120, 100, 125)
        bone = (220, 210, 190)
        bone_dk = (180, 170, 150)
        bone_lt = (240, 235, 220)
        eye_color = (80, 240, 100)
        eye_glow = (60, 200, 80)
        dark_aura = (40, 20, 60)
        # Dark background - layered
        pygame.draw.rect(surf, (10, 6, 18, 150), (0, 0, w, h))
        self._soft_glow(surf, cx, int(h * 0.4), max(5, int(w * 0.35)), dark_aura, 20)
        self._soft_glow(surf, cx + int(w * 0.1), int(h * 0.3), max(3, int(w * 0.2)), (50, 30, 70), 10)
        # Gaunt face - 4-layer shading
        face_w = int(w * 0.46)
        face_h = int(h * 0.72)
        face_top = int(h * 0.22)
        self._face_base(surf, cx, face_top, face_w, face_h, skin, skin_sh, skin_hi)
        # Sunken cheek shadows - deeper
        for s in [-1, 1]:
            chx = cx + s * int(w * 0.11)
            chy = int(h * 0.50)
            pygame.draw.ellipse(surf, (*skin_deep, 70),
                                (chx - int(w * 0.05), chy, int(w * 0.08), int(h * 0.13)))
            pygame.draw.ellipse(surf, (*skin_sh, 50),
                                (chx - int(w * 0.04), chy + int(h * 0.02), int(w * 0.06), int(h * 0.08)))
        # Facial lines - gaunt aging
        for s in [-1, 1]:
            pygame.draw.line(surf, (*skin_sh, 60),
                             (cx + s * int(w * 0.06), int(h * 0.50)),
                             (cx + s * int(w * 0.08), int(h * 0.62)), 1)
        # Bone crown - enhanced
        crown_y = int(h * 0.08)
        crown_h2 = int(h * 0.18)
        crown_w = int(w * 0.52)
        crown_rect = pygame.Rect(cx - crown_w // 2, crown_y, crown_w, crown_h2)
        pygame.draw.rect(surf, bone, crown_rect, border_radius=2)
        # Crown shading
        pygame.draw.rect(surf, bone_dk, (crown_rect.x, crown_y + crown_h2 // 2, crown_w, crown_h2 // 2), border_radius=1)
        pygame.draw.rect(surf, bone, (crown_rect.x + 1, crown_y, crown_w - 2, int(crown_h2 * 0.6)), border_radius=1)
        # Crown highlight
        pygame.draw.ellipse(surf, (*bone_lt, 35),
                            (cx - int(crown_w * 0.3), crown_y + 2, int(crown_w * 0.6), crown_h2 // 3))
        # Crown outline
        pygame.draw.rect(surf, bone_dk, crown_rect, 1, border_radius=2)
        # Crown spikes with detail
        for i in range(5):
            sx = crown_rect.left + int((i + 0.5) * crown_w / 5)
            spike_h = int(h * 0.12) if i == 2 else int(h * 0.06 + (i % 2) * h * 0.03)
            spike_pts = [(sx - int(w * 0.025), crown_y),
                         (sx, crown_y - spike_h),
                         (sx + int(w * 0.025), crown_y)]
            pygame.draw.polygon(surf, bone, spike_pts)
            pygame.draw.polygon(surf, bone_dk, spike_pts, 1)
            # Center line on spike
            pygame.draw.line(surf, bone_lt, (sx, crown_y - spike_h), (sx, crown_y), 1)
        # Crown skull emblem - detailed
        emb_y = crown_y + crown_h2 // 2
        emb_r = max(2, int(b * 0.13))
        pygame.draw.circle(surf, bone_dk, (cx, emb_y), emb_r)
        pygame.draw.circle(surf, bone, (cx, emb_y), emb_r - 1)
        # Tiny eye sockets on emblem
        for s in [-1, 1]:
            pygame.draw.circle(surf, bone_dk, (cx + s * max(1, emb_r // 3), emb_y - max(1, emb_r // 4)),
                               max(1, emb_r // 4))
        # Dark circles under eyes
        eye_y = int(h * 0.40)
        eye_sp = int(w * 0.10)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            pygame.draw.ellipse(surf, (*skin_deep, 80),
                                (ex - int(w * 0.07), eye_y - int(h * 0.03), int(w * 0.14), int(h * 0.09)))
        # Eyes - green glow with helpers
        for s in [-1, 1]:
            self._hq_eye(surf, cx + s * eye_sp, eye_y, w, h, b,
                         eye_color, pupil_color=(10, 30, 15), sclera=(200, 200, 190),
                         glow_color=eye_glow, lid_color=(80, 60, 75))
        # Sharp thin eyebrows - angular
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = eye_y - max(3, int(h * 0.07))
            pygame.draw.line(surf, skin_sh, (bx - s * int(w * 0.02), by + 1),
                             (bx + s * int(w * 0.06), by - 2), 1)
        # Pointed nose
        nose_y = int(h * 0.55)
        pygame.draw.line(surf, skin_sh, (cx, int(h * 0.46)), (cx - 1, nose_y), 1)
        pygame.draw.line(surf, skin_sh, (cx, int(h * 0.46)), (cx + 1, nose_y), 1)
        pygame.draw.circle(surf, (*skin_hi, 50), (cx, int(h * 0.50)), max(1, b // 10))
        # Grim mouth - corners down
        mouth_y = int(h * 0.66)
        pygame.draw.line(surf, (130, 100, 120), (cx - int(w * 0.07), mouth_y),
                         (cx + int(w * 0.07), mouth_y), 1)
        for s in [-1, 1]:
            pygame.draw.line(surf, (130, 100, 120), (cx + s * int(w * 0.07), mouth_y),
                             (cx + s * int(w * 0.08), mouth_y + 2), 1)
        # Lip shadow
        pygame.draw.line(surf, (*skin_sh, 50), (cx - int(w * 0.05), mouth_y + 1),
                         (cx + int(w * 0.05), mouth_y + 1), 1)
        # Death aura particles
        for i in range(5):
            ax = cx + int(_sin(i * 1.5) * w * 0.3)
            ay = int(h * 0.2 + i * h * 0.12)
            pygame.draw.circle(surf, (*dark_aura, 25), (ax, ay), max(1, int(b * 0.06)))
        pygame.draw.rect(surf, (*eye_glow, 150), (0, 0, w, h), 1, border_radius=2)

    # ─── 11. JOKER (조커/광대) ───
    def _portrait_joker(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        face_white = (240, 235, 230)
        face_sh = (215, 210, 205)
        face_hi = (250, 248, 245)
        hat_red = (200, 40, 40)
        hat_red_lt = (230, 70, 60)
        hat_gold = (230, 200, 80)
        hat_gold_lt = (250, 225, 120)
        hat_dk = (160, 25, 25)
        nose_red = (220, 50, 50)
        lip_red = (200, 40, 40)
        eye_color = (60, 140, 200)
        star_c = (255, 220, 60)
        # Colorful background
        pygame.draw.rect(surf, (45, 18, 48, 85), (0, 0, w, h))
        self._soft_glow(surf, cx, int(h * 0.4), max(5, int(w * 0.3)), (150, 50, 100), 10)
        # Jester hat - enhanced with shading
        hat_y = int(h * 0.15)
        # Left horn (red)
        left_pts = [(cx - int(w * 0.36), hat_y + int(h * 0.12)),
                    (cx - int(w * 0.48), int(h * -0.06)),
                    (cx - int(w * 0.15), hat_y)]
        pygame.draw.polygon(surf, hat_red, left_pts)
        pygame.draw.polygon(surf, hat_red_lt, [(cx - int(w * 0.32), hat_y + int(h * 0.08)),
                                                (cx - int(w * 0.42), int(h * 0.0)),
                                                (cx - int(w * 0.22), hat_y + int(h * 0.02))], 0)
        pygame.draw.polygon(surf, hat_dk, left_pts, 1)
        # Right horn (gold)
        right_pts = [(cx + int(w * 0.36), hat_y + int(h * 0.12)),
                     (cx + int(w * 0.48), int(h * -0.06)),
                     (cx + int(w * 0.15), hat_y)]
        pygame.draw.polygon(surf, hat_gold, right_pts)
        pygame.draw.polygon(surf, hat_gold_lt, [(cx + int(w * 0.22), hat_y + int(h * 0.02)),
                                                 (cx + int(w * 0.42), int(h * 0.0)),
                                                 (cx + int(w * 0.32), hat_y + int(h * 0.08))], 0)
        pygame.draw.polygon(surf, (190, 160, 50), right_pts, 1)
        # Hat band - gold with detail
        band_rect = pygame.Rect(cx - int(w * 0.36), hat_y, int(w * 0.72), max(3, int(h * 0.055)))
        pygame.draw.rect(surf, hat_gold, band_rect)
        pygame.draw.line(surf, hat_gold_lt, (band_rect.x, band_rect.y),
                         (band_rect.right, band_rect.y), 1)
        # Bells on tips - enhanced
        for bx, by in [(cx - int(w * 0.48), int(h * -0.06)), (cx + int(w * 0.48), int(h * -0.06))]:
            bell_r = max(2, int(b * 0.11))
            pygame.draw.circle(surf, hat_gold, (bx, by), bell_r)
            pygame.draw.circle(surf, hat_gold_lt, (bx - 1, by - 1), max(1, bell_r // 2))
            pygame.draw.circle(surf, (180, 150, 40), (bx, by + bell_r // 2), max(1, bell_r // 3))
            pygame.draw.circle(surf, (160, 130, 30), (bx, by), bell_r, 1)
        # White painted face - 4-layer
        face_w = int(w * 0.55)
        face_h = int(h * 0.65)
        face_top = int(h * 0.22)
        self._face_base(surf, cx, face_top, face_w, face_h, face_white, face_sh, face_hi)
        # Left eye - diamond makeup + hq_eye
        eye_y = int(h * 0.42)
        eye_sp = int(w * 0.11)
        ex_l = cx - eye_sp
        sw = max(3, int(w * 0.07))
        sh = max(2, int(h * 0.05))
        # Blue diamond around left eye
        pygame.draw.polygon(surf, (60, 100, 180, 60),
                            [(ex_l, eye_y - sh - 3), (ex_l + sw + 2, eye_y),
                             (ex_l, eye_y + sh + 3), (ex_l - sw - 2, eye_y)])
        self._hq_eye(surf, ex_l, eye_y, w, h, b, eye_color,
                     pupil_color=(20, 20, 30), lid_color=(60, 40, 80))
        # Right eye - star makeup + hq_eye
        ex_r = cx + eye_sp
        star_r = max(3, int(b * 0.32))
        # Star shape
        star_pts = []
        for p in range(10):
            angle = p * 3.14159 / 5 - 3.14159 / 2
            r = star_r if p % 2 == 0 else star_r * 0.4
            star_pts.append((ex_r + int(_cos(angle) * r), eye_y + int(_sin(angle) * r)))
        if len(star_pts) >= 3:
            pygame.draw.polygon(surf, (*star_c, 80), star_pts)
            pygame.draw.polygon(surf, star_c, star_pts, 1)
        self._hq_eye(surf, ex_r, eye_y, w, h, b, eye_color,
                     pupil_color=(20, 20, 30), lid_color=(60, 40, 80))
        # Arched expressive eyebrows
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = eye_y - max(3, int(h * 0.08))
            pygame.draw.arc(surf, (60, 40, 80),
                            (bx - int(w * 0.06), by - int(h * 0.04), int(w * 0.12), int(h * 0.07)),
                            0.3, 2.8, max(1, int(b * 0.07)))
        # Red nose - shiny
        nose_y = int(h * 0.53)
        nose_r = max(2, int(b * 0.15))
        pygame.draw.circle(surf, nose_red, (cx, nose_y), nose_r)
        pygame.draw.circle(surf, (240, 80, 80), (cx - 1, nose_y - 1), max(1, nose_r // 2))
        pygame.draw.circle(surf, (255, 120, 120), (cx - 1, nose_y - 1), max(1, nose_r // 4))
        # Wide grinning red mouth - enhanced
        mouth_y = int(h * 0.65)
        mouth_w = int(w * 0.20)
        pygame.draw.arc(surf, lip_red,
                        (cx - mouth_w, mouth_y - int(h * 0.06), mouth_w * 2, int(h * 0.14)),
                        3.3, 6.1, max(1, int(b * 0.09)))
        # Grin corners curving up
        for s in [-1, 1]:
            pygame.draw.arc(surf, lip_red,
                            (cx + s * mouth_w - int(w * 0.03), mouth_y - int(h * 0.05),
                             int(w * 0.06), int(h * 0.07)),
                            0.5 if s == 1 else 2.0, 2.0 if s == 1 else 3.5, 1)
        # Teeth hint in grin
        pygame.draw.line(surf, (250, 248, 240), (cx - int(mouth_w * 0.5), mouth_y + int(h * 0.01)),
                         (cx + int(mouth_w * 0.5), mouth_y + int(h * 0.01)), 1)
        pygame.draw.rect(surf, (*hat_gold, 180), (0, 0, w, h), 1, border_radius=2)

    # ─── 12. MIRAGE (미라지/사막환술사) ───
    def _portrait_mirage(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        skin = (200, 165, 120)
        skin_sh = (170, 135, 95)
        skin_hi = (225, 195, 155)
        wrap = (210, 190, 150)
        wrap_dk = (175, 155, 115)
        wrap_lt = (235, 220, 185)
        wrap_hi = (248, 238, 210)
        eye_color = (220, 180, 60)
        eye_glow = (240, 200, 80)
        shimmer = (255, 230, 150)
        jewel = (180, 40, 40)
        # Sandy/warm background - layered
        pygame.draw.rect(surf, (55, 38, 22, 105), (0, 0, w, h))
        # Heat shimmer effect - enhanced
        for i in range(5):
            sy = int(h * (0.15 + i * 0.18))
            sw2 = int(w * 0.5 + _sin(i * 1.4) * w * 0.12)
            self._soft_glow(surf, cx + int(_sin(i * 2.0) * w * 0.05), sy,
                            max(3, sw2 // 3), shimmer, 6)
        # Turban/headwrap - enhanced with depth
        turban_pts = [(cx - int(w * 0.42), int(h * 0.25)),
                      (cx - int(w * 0.36), int(h * 0.02)),
                      (cx, int(h * -0.03)),
                      (cx + int(w * 0.36), int(h * 0.02)),
                      (cx + int(w * 0.42), int(h * 0.25))]
        pygame.draw.polygon(surf, wrap_dk, turban_pts)
        # Turban inner (lighter)
        inner_pts = [(cx - int(w * 0.38), int(h * 0.24)),
                     (cx - int(w * 0.33), int(h * 0.04)),
                     (cx, int(h * 0.0)),
                     (cx + int(w * 0.33), int(h * 0.04)),
                     (cx + int(w * 0.38), int(h * 0.24))]
        pygame.draw.polygon(surf, wrap, inner_pts)
        # Turban folds - more detailed
        for i in range(4):
            fy = int(h * 0.04 + i * h * 0.05)
            fw = int(w * 0.30 - i * w * 0.02)
            pygame.draw.line(surf, wrap_dk, (cx - fw, fy), (cx + fw, fy), 1)
        # Turban highlight
        pygame.draw.ellipse(surf, (*wrap_hi, 45),
                            (cx - int(w * 0.14), int(h * 0.03), int(w * 0.28), int(h * 0.10)))
        # Jewel on turban center
        jewel_y = int(h * 0.10)
        jr = max(2, int(b * 0.09))
        pygame.draw.circle(surf, jewel, (cx, jewel_y), jr)
        pygame.draw.circle(surf, (220, 80, 70), (cx - 1, jewel_y - 1), max(1, jr // 2))
        pygame.draw.circle(surf, self._darken(jewel, 30), (cx, jewel_y), jr, 1)
        # Visible face strip - eyes area with shading
        face_w2 = int(w * 0.52)
        face_h2 = int(h * 0.28)
        face_top = int(h * 0.25)
        pygame.draw.ellipse(surf, skin, (cx - face_w2 // 2, face_top, face_w2, face_h2))
        pygame.draw.ellipse(surf, skin_sh,
                            (cx - face_w2 // 2 + 2, face_top + face_h2 // 2, face_w2 - 4, face_h2 // 2))
        pygame.draw.ellipse(surf, skin,
                            (cx - face_w2 // 2 + 2, face_top, face_w2 - 4, int(face_h2 * 0.6)))
        # Skin highlight on nose bridge
        pygame.draw.ellipse(surf, (*skin_hi, 40),
                            (cx - int(w * 0.06), face_top + 1, int(w * 0.12), face_h2 // 2))
        # Amber eyes - with glow
        eye_y = int(h * 0.36)
        eye_sp = int(w * 0.11)
        for s in [-1, 1]:
            self._hq_eye(surf, cx + s * eye_sp, eye_y, w, h, b,
                         eye_color, pupil_color=(40, 25, 10), sclera=(250, 245, 230),
                         glow_color=eye_glow, lid_color=(100, 75, 50))
        # Intense eyebrows
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = eye_y - max(3, int(h * 0.07))
            pygame.draw.line(surf, skin_sh, (bx - s * int(w * 0.04), by + 1),
                             (bx + s * int(w * 0.05), by - 1), max(1, int(b * 0.08)))
        # Nose bridge
        pygame.draw.line(surf, skin_sh, (cx, int(h * 0.40)), (cx, int(h * 0.48)), 1)
        pygame.draw.circle(surf, (*skin_hi, 60), (cx, int(h * 0.42)), max(1, b // 10))
        # Face wrap - enhanced with gradient
        wrap_top = int(h * 0.48)
        wrap_pts = [(cx - int(w * 0.43), wrap_top),
                    (cx + int(w * 0.43), wrap_top),
                    (cx + int(w * 0.38), int(h * 0.96)),
                    (cx, int(h * 0.99)),
                    (cx - int(w * 0.38), int(h * 0.96))]
        pygame.draw.polygon(surf, wrap, wrap_pts)
        # Wrap lower shadow
        pygame.draw.polygon(surf, wrap_dk,
                            [(cx - int(w * 0.40), int(h * 0.70)),
                             (cx + int(w * 0.40), int(h * 0.70)),
                             (cx + int(w * 0.38), int(h * 0.96)),
                             (cx, int(h * 0.99)),
                             (cx - int(w * 0.38), int(h * 0.96))])
        # Wrap fold details - more lines
        for i in range(5):
            fy = wrap_top + int(h * 0.04 + i * h * 0.09)
            fi = int(w * 0.02 * (i % 2))
            pygame.draw.line(surf, wrap_dk, (cx - int(w * 0.34) + fi, fy),
                             (cx + int(w * 0.34) - fi, fy), 1)
        # Wrap highlight
        pygame.draw.ellipse(surf, (*wrap_hi, 28),
                            (cx - int(w * 0.14), wrap_top + int(h * 0.04), int(w * 0.28), int(h * 0.12)))
        pygame.draw.polygon(surf, wrap_dk, wrap_pts, 1)
        pygame.draw.rect(surf, (*eye_glow, 150), (0, 0, w, h), 1, border_radius=2)

    # ─── 13. RA (라/태양신) ───
    def _portrait_ra(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        gold = (220, 190, 60)
        gold_dk = (180, 150, 30)
        gold_lt = (245, 225, 100)
        gold_hi = (255, 240, 150)
        metal = (200, 180, 100)
        metal_dk = (160, 140, 70)
        metal_hi = (225, 210, 135)
        eye_color = (255, 160, 30)
        eye_glow = (255, 200, 60)
        blue = (40, 80, 180)
        blue_lt = (70, 120, 220)
        # Radiant background - multi-layer sun rays
        self._soft_glow(surf, cx, int(h * 0.35), max(6, int(w * 0.45)), (200, 150, 30), 22)
        self._soft_glow(surf, cx, int(h * 0.30), max(4, int(w * 0.25)), (255, 180, 40), 10)
        # Egyptian hawk helmet - enhanced
        helm_pts = [(cx - int(w * 0.48), int(h * 0.55)),
                    (cx - int(w * 0.46), int(h * 0.08)),
                    (cx - int(w * 0.26), int(h * 0.0)),
                    (cx, int(h * -0.03)),
                    (cx + int(w * 0.26), int(h * 0.0)),
                    (cx + int(w * 0.46), int(h * 0.08)),
                    (cx + int(w * 0.48), int(h * 0.55))]
        pygame.draw.polygon(surf, gold, helm_pts)
        # Helmet shading
        pygame.draw.polygon(surf, gold_dk,
                            [(cx - int(w * 0.46), int(h * 0.35)),
                             (cx - int(w * 0.48), int(h * 0.55)),
                             (cx + int(w * 0.48), int(h * 0.55)),
                             (cx + int(w * 0.46), int(h * 0.35))])
        pygame.draw.polygon(surf, gold,
                            [(cx - int(w * 0.44), int(h * 0.08)),
                             (cx, int(h * -0.03)),
                             (cx + int(w * 0.44), int(h * 0.08)),
                             (cx + int(w * 0.38), int(h * 0.28)),
                             (cx - int(w * 0.38), int(h * 0.28))])
        # Helmet specular
        pygame.draw.ellipse(surf, (*gold_hi, 35),
                            (cx - int(w * 0.15), int(h * 0.04), int(w * 0.30), int(h * 0.14)))
        # Stripes (blue and gold)
        for i in range(5):
            sy = int(h * 0.07 + i * h * 0.08)
            sw2 = int(w * 0.42 - i * w * 0.02)
            sh2 = max(2, int(h * 0.035))
            sc = blue if i % 2 == 0 else gold_lt
            pygame.draw.rect(surf, sc, (cx - sw2, sy, sw2 * 2, sh2))
        # Center cobra/uraeus - detailed
        cobra_x = cx
        cobra_pts = [(cobra_x - int(w * 0.035), int(h * 0.10)),
                     (cobra_x, int(h * -0.06)),
                     (cobra_x + int(w * 0.035), int(h * 0.10))]
        pygame.draw.polygon(surf, gold_lt, cobra_pts)
        # Cobra hood flare
        pygame.draw.polygon(surf, gold,
                            [(cobra_x - int(w * 0.04), int(h * 0.02)),
                             (cobra_x, int(h * -0.06)),
                             (cobra_x + int(w * 0.04), int(h * 0.02))])
        # Cobra eye
        pygame.draw.circle(surf, (200, 40, 40), (cobra_x, int(h * 0.01)), max(1, int(b * 0.06)))
        pygame.draw.circle(surf, (240, 80, 70), (cobra_x, int(h * 0.0)), max(1, int(b * 0.03)))
        # Golden face plate - with multi-layer shading
        face_w = int(w * 0.42)
        face_h = int(h * 0.55)
        face_top = int(h * 0.32)
        fr = pygame.Rect(cx - face_w // 2, face_top, face_w, face_h)
        pygame.draw.ellipse(surf, metal, fr)
        pygame.draw.ellipse(surf, metal_dk,
                            (fr.x + 1, face_top + int(face_h * 0.55), face_w - 2, int(face_h * 0.45)))
        pygame.draw.ellipse(surf, metal,
                            (fr.x + 2, face_top, face_w - 4, int(face_h * 0.58)))
        pygame.draw.ellipse(surf, (*metal_hi, 40),
                            (cx - int(face_w * 0.25), face_top + int(face_h * 0.05),
                             int(face_w * 0.45), int(face_h * 0.20)))
        # Eye of Horus markings - enhanced
        eye_y = int(h * 0.45)
        eye_sp = int(w * 0.10)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            ew = max(4, int(w * 0.09))
            eh = max(3, int(h * 0.06))
            # Thick upper lid (Egyptian kohl)
            pygame.draw.line(surf, (10, 10, 10), (ex - ew, eye_y), (ex + ew, eye_y - 1),
                             max(1, int(b * 0.09)))
            # Teardrop line
            pygame.draw.line(surf, (10, 10, 10),
                             (ex + s * int(ew * 0.3), eye_y + eh),
                             (ex + s * int(ew * 0.2), eye_y + eh + int(h * 0.09)),
                             max(1, int(b * 0.05)))
            # Spiral curl at teardrop end
            curl_x = ex + s * int(ew * 0.2)
            curl_y = eye_y + eh + int(h * 0.09)
            pygame.draw.arc(surf, (10, 10, 10),
                            (curl_x - int(w * 0.02), curl_y - int(h * 0.02),
                             int(w * 0.04), int(h * 0.04)), 0.0, 4.0, 1)
            # Winged outer corner
            pygame.draw.line(surf, (10, 10, 10), (ex + s * ew, eye_y),
                             (ex + s * int(ew * 1.4), eye_y - int(h * 0.04)),
                             max(1, int(b * 0.05)))
            # Eye opening
            pygame.draw.ellipse(surf, (20, 15, 10),
                                (ex - ew + 1, eye_y - eh + 1, (ew - 1) * 2, (eh - 1) * 2))
            # Iris with glow
            ir = max(2, int(min(ew, eh) * 0.6))
            self._soft_glow(surf, ex, eye_y, max(3, ir * 2), eye_glow, 25)
            pygame.draw.circle(surf, self._darken(eye_color, 30), (ex, eye_y), ir + 1)
            pygame.draw.circle(surf, eye_color, (ex, eye_y), ir)
            pygame.draw.circle(surf, self._lighten(eye_color, 30), (ex, eye_y), max(1, ir * 2 // 3))
            pr = max(1, ir // 2)
            pygame.draw.circle(surf, (60, 20, 5), (ex, eye_y), pr)
            pygame.draw.circle(surf, (255, 230, 150), (ex + s, eye_y - 1), max(1, pr // 2))
        # Nose ridge
        pygame.draw.line(surf, metal_dk, (cx, int(h * 0.48)), (cx, int(h * 0.62)), max(1, int(b * 0.05)))
        pygame.draw.line(surf, metal_hi, (cx - 1, int(h * 0.50)), (cx - 1, int(h * 0.58)), 1)
        # Chin piece - enhanced
        chin_y = int(h * 0.78)
        chin_pts = [(cx - int(w * 0.11), chin_y),
                    (cx, int(h * 0.93)),
                    (cx + int(w * 0.11), chin_y)]
        pygame.draw.polygon(surf, gold, chin_pts)
        pygame.draw.polygon(surf, gold_dk, chin_pts, 1)
        pygame.draw.line(surf, gold_lt, (cx, chin_y), (cx, int(h * 0.90)), 1)
        # Helmet outline
        pygame.draw.polygon(surf, gold_dk, helm_pts, 1)
        pygame.draw.rect(surf, (*gold, 200), (0, 0, w, h), 1, border_radius=2)

    # ─── 14. ANDROID (안드로이드/로봇) ───
    def _portrait_android(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        metal = (160, 165, 175)
        metal_dk = (120, 125, 135)
        metal_lt = (195, 200, 210)
        metal_hi = (220, 225, 235)
        panel = (140, 145, 155)
        led_blue = (50, 150, 255)
        led_glow = (80, 180, 255)
        led_white = (200, 230, 255)
        circuit = (60, 180, 220)
        circuit_dk = (40, 120, 170)
        # Tech background - deep navy with subtle gradient
        pygame.draw.rect(surf, (10, 15, 25, 140), (0, 0, w, h))
        # Vertical gradient overlay (darker at top)
        for gy in range(0, h, max(1, h // 12)):
            a = max(0, 30 - int(gy / h * 30))
            pygame.draw.rect(surf, (5, 10, 20, a), (0, gy, w, max(1, h // 12)))
        # Grid lines in background - finer grid
        for i in range(0, w, max(2, w // 12)):
            pygame.draw.line(surf, (25, 35, 55, 20), (i, 0), (i, h), 1)
        for i in range(0, h, max(2, h // 10)):
            pygame.draw.line(surf, (25, 35, 55, 20), (0, i), (w, i), 1)
        # Background circuit traces (decorative)
        for tx, ty in [(int(w * 0.10), int(h * 0.15)), (int(w * 0.85), int(h * 0.70))]:
            pygame.draw.line(surf, (30, 50, 70, 35), (tx, ty), (tx + int(w * 0.12), ty), 1)
            pygame.draw.line(surf, (30, 50, 70, 35), (tx + int(w * 0.12), ty), (tx + int(w * 0.12), ty + int(h * 0.10)), 1)
        # Head shape - angular/mechanical with beveled edges
        head_w = int(w * 0.60)
        head_h = int(h * 0.75)
        head_top = int(h * 0.12)
        head_pts = [(cx - head_w // 2, head_top + int(head_h * 0.15)),
                    (cx - int(head_w * 0.40), head_top),
                    (cx + int(head_w * 0.40), head_top),
                    (cx + head_w // 2, head_top + int(head_h * 0.15)),
                    (cx + head_w // 2, head_top + int(head_h * 0.75)),
                    (cx + int(head_w * 0.35), head_top + head_h),
                    (cx - int(head_w * 0.35), head_top + head_h),
                    (cx - head_w // 2, head_top + int(head_h * 0.75))]
        # Multi-layer head: dark base → main metal → highlight layer
        pygame.draw.polygon(surf, metal_dk, head_pts)
        inner_pts = [(int(p[0] + (cx - p[0]) * 0.04), int(p[1] + (head_top + head_h // 2 - p[1]) * 0.04)) for p in head_pts]
        pygame.draw.polygon(surf, metal, inner_pts)
        # Specular highlight on top-right of head
        pygame.draw.ellipse(surf, (*metal_hi, 35),
                            (cx - int(w * 0.05), head_top + int(head_h * 0.03), int(w * 0.28), int(head_h * 0.18)))
        # Left side shadow
        pygame.draw.ellipse(surf, (*metal_dk, 30),
                            (cx - head_w // 2 - int(w * 0.01), head_top + int(head_h * 0.10),
                             int(w * 0.12), int(head_h * 0.55)))
        # Panel lines on face - multi-layer depth
        # Center vertical line with groove effect
        pygame.draw.line(surf, (100, 105, 115), (cx - 1, head_top + int(head_h * 0.08)), (cx - 1, head_top + head_h - int(head_h * 0.08)), 1)
        pygame.draw.line(surf, metal_dk, (cx, head_top + int(head_h * 0.08)), (cx, head_top + head_h - int(head_h * 0.08)), 1)
        pygame.draw.line(surf, metal_lt, (cx + 1, head_top + int(head_h * 0.08)), (cx + 1, head_top + head_h - int(head_h * 0.08)), 1)
        # Horizontal panel line with groove
        panel_y = head_top + int(head_h * 0.55)
        pygame.draw.line(surf, (100, 105, 115), (cx - head_w // 2 + 2, panel_y - 1), (cx + head_w // 2 - 2, panel_y - 1), 1)
        pygame.draw.line(surf, metal_dk, (cx - head_w // 2 + 2, panel_y), (cx + head_w // 2 - 2, panel_y), 1)
        pygame.draw.line(surf, metal_lt, (cx - head_w // 2 + 2, panel_y + 1), (cx + head_w // 2 - 2, panel_y + 1), 1)
        # Bolt rivets at panel intersections
        for bx, by in [(cx - head_w // 2 + int(w * 0.04), panel_y),
                        (cx + head_w // 2 - int(w * 0.04), panel_y),
                        (cx - head_w // 2 + int(w * 0.04), head_top + int(head_h * 0.20)),
                        (cx + head_w // 2 - int(w * 0.04), head_top + int(head_h * 0.20))]:
            br = max(1, int(b * 0.04))
            pygame.draw.circle(surf, metal_dk, (bx, by), br + 1)
            pygame.draw.circle(surf, metal_lt, (bx, by), br)
        # Visor for eyes - deeper with inner glow
        visor_y = head_top + int(head_h * 0.28)
        visor_h = max(5, int(h * 0.14))
        visor_w = int(w * 0.52)
        visor_rect = pygame.Rect(cx - visor_w // 2, visor_y, visor_w, visor_h)
        # Visor outer bevel
        pygame.draw.rect(surf, (60, 70, 90), visor_rect.inflate(2, 2), border_radius=3)
        # Visor deep black interior
        pygame.draw.rect(surf, (12, 18, 35), visor_rect, border_radius=2)
        # Inner subtle gradient (darker bottom)
        for vy in range(visor_rect.top + 1, visor_rect.bottom - 1):
            frac = (vy - visor_rect.top) / max(1, visor_h)
            a = max(0, int(15 - frac * 15))
            pygame.draw.line(surf, (30, 50, 80, a), (visor_rect.left + 1, vy), (visor_rect.right - 1, vy), 1)
        # Visor trim highlight on top edge
        pygame.draw.line(surf, metal_lt, (visor_rect.left + 2, visor_rect.top), (visor_rect.right - 2, visor_rect.top), 1)
        # LED blue eyes with layered glow
        eye_sp = int(w * 0.12)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            ey = visor_y + visor_h // 2
            # Outer glow halo (large, dim)
            self._soft_glow(surf, ex, ey, max(6, int(b * 0.55)), led_blue, 18)
            # Mid glow
            self._soft_glow(surf, ex, ey, max(4, int(b * 0.35)), led_glow, 25)
            # LED iris ring
            led_r = max(2, visor_h // 3)
            pygame.draw.circle(surf, led_blue, (ex, ey), led_r + 1)
            pygame.draw.circle(surf, (15, 25, 45), (ex, ey), led_r)
            pygame.draw.circle(surf, led_blue, (ex, ey), led_r, 1)
            # Inner bright core
            pygame.draw.circle(surf, led_glow, (ex, ey), max(1, led_r * 2 // 3))
            # Center white dot
            pygame.draw.circle(surf, led_white, (ex, ey), max(1, led_r // 3))
            # Specular highlight
            pygame.draw.circle(surf, (240, 248, 255), (ex + s, ey - 1), max(1, led_r // 4))
            # Scan line through eye (horizontal)
            pygame.draw.line(surf, (*led_blue, 60), (ex - led_r - 1, ey), (ex + led_r + 1, ey), 1)
        # Circuit patterns on cheek plates - enhanced
        for s in [-1, 1]:
            cpx = cx + s * int(w * 0.20)
            cpy = head_top + int(head_h * 0.58)
            # Main horizontal trace
            pygame.draw.line(surf, circuit_dk, (cpx, cpy), (cpx + s * int(w * 0.10), cpy), 1)
            pygame.draw.line(surf, circuit, (cpx, cpy - 1), (cpx + s * int(w * 0.10), cpy - 1), 1)
            # Vertical branch
            vx = cpx + s * int(w * 0.05)
            pygame.draw.line(surf, circuit, (vx, cpy), (vx, cpy + int(h * 0.12)), 1)
            # Diagonal branch
            pygame.draw.line(surf, circuit_dk, (cpx + s * int(w * 0.10), cpy),
                             (cpx + s * int(w * 0.13), cpy + int(h * 0.05)), 1)
            # Circuit nodes with glow
            for nx, ny in [(cpx, cpy), (cpx + s * int(w * 0.05), cpy),
                           (cpx + s * int(w * 0.10), cpy), (vx, cpy + int(h * 0.12)),
                           (cpx + s * int(w * 0.13), cpy + int(h * 0.05))]:
                nr = max(1, int(b * 0.04))
                pygame.draw.circle(surf, circuit, (nx, ny), nr + 1)
                pygame.draw.circle(surf, led_white, (nx, ny), nr)
        # Nose sensor - small LED indicator
        nose_y = head_top + int(head_h * 0.60)
        nose_w = max(2, int(w * 0.03))
        nose_h = max(3, int(h * 0.06))
        pygame.draw.rect(surf, panel, (cx - nose_w, nose_y, nose_w * 2, nose_h), border_radius=1)
        pygame.draw.rect(surf, metal_dk, (cx - nose_w, nose_y, nose_w * 2, nose_h), 1, border_radius=1)
        # Tiny status LED on nose
        pygame.draw.circle(surf, (50, 255, 100), (cx, nose_y + nose_h // 2), max(1, int(b * 0.03)))
        # Mouth speaker grille - enhanced with depth
        mouth_y = head_top + int(head_h * 0.73)
        grille_w = int(w * 0.18)
        grille_h = max(4, int(h * 0.07))
        # Grille recess shadow
        pygame.draw.rect(surf, (80, 85, 95), (cx - grille_w // 2 - 1, mouth_y - 1, grille_w + 2, grille_h + 2), border_radius=2)
        pygame.draw.rect(surf, (40, 45, 55), (cx - grille_w // 2, mouth_y, grille_w, grille_h), border_radius=1)
        # Grille slats
        num_slats = 5
        for i in range(num_slats):
            lx = cx - grille_w // 2 + int((i + 0.5) * grille_w / num_slats)
            pygame.draw.line(surf, (70, 75, 85), (lx, mouth_y + 1), (lx, mouth_y + grille_h - 1), 1)
        # Horizontal slat
        pygame.draw.line(surf, (60, 65, 75), (cx - grille_w // 2 + 1, mouth_y + grille_h // 2),
                         (cx + grille_w // 2 - 1, mouth_y + grille_h // 2), 1)
        # Blue LED glow behind grille
        self._soft_glow(surf, cx, mouth_y + grille_h // 2, max(3, grille_w // 3), led_blue, 12)
        # Antenna/sensor on top - enhanced
        ant_x = cx + int(w * 0.15)
        ant_base = head_top + int(head_h * 0.02)
        ant_tip = head_top - int(h * 0.10)
        # Antenna shaft with metallic shading
        pygame.draw.line(surf, metal_dk, (ant_x - 1, ant_base), (ant_x - 1, ant_tip), 1)
        pygame.draw.line(surf, metal, (ant_x, ant_base), (ant_x, ant_tip), max(1, int(b * 0.05)))
        pygame.draw.line(surf, metal_lt, (ant_x + 1, ant_base), (ant_x + 1, ant_tip), 1)
        # Antenna tip orb with glow
        orb_r = max(2, int(b * 0.07))
        self._soft_glow(surf, ant_x, ant_tip, max(4, int(b * 0.20)), led_blue, 22)
        pygame.draw.circle(surf, led_blue, (ant_x, ant_tip), orb_r)
        pygame.draw.circle(surf, led_glow, (ant_x, ant_tip), max(1, orb_r * 2 // 3))
        pygame.draw.circle(surf, led_white, (ant_x - 1, ant_tip - 1), max(1, orb_r // 3))
        # Ear sensors (small rectangles on head sides)
        for s in [-1, 1]:
            ear_x = cx + s * (head_w // 2 - int(w * 0.01))
            ear_y = head_top + int(head_h * 0.30)
            ear_w = max(2, int(w * 0.04))
            ear_h = max(4, int(h * 0.10))
            pygame.draw.rect(surf, metal_dk, (ear_x - ear_w // 2, ear_y, ear_w, ear_h), border_radius=1)
            pygame.draw.rect(surf, metal_lt, (ear_x - ear_w // 2, ear_y, ear_w, ear_h), 1, border_radius=1)
            # Small LED on ear sensor
            pygame.draw.circle(surf, led_blue, (ear_x, ear_y + ear_h // 2), max(1, int(b * 0.03)))
        # Head edge outline
        pygame.draw.polygon(surf, metal_dk, head_pts, 1)
        # Border with tech glow
        pygame.draw.rect(surf, (*led_blue, 140), (0, 0, w, h), 1, border_radius=2)
        # Corner LED dots
        for dx, dy in [(3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)]:
            pygame.draw.circle(surf, (*led_blue, 80), (dx, dy), max(1, int(b * 0.03)))

    # ─── 15. MONKEYKING (원숭이왕/손오공) ───
    def _portrait_monkeyking(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        fur = (160, 110, 60)
        fur_dk = (120, 80, 40)
        fur_lt = (195, 150, 90)
        fur_hi = (220, 180, 120)
        skin = (230, 190, 145)
        skin_sh = (200, 160, 120)
        skin_hi = (245, 220, 185)
        crown = (230, 200, 60)
        crown_dk = (190, 160, 30)
        crown_lt = (255, 230, 100)
        crown_hi = (255, 245, 160)
        eye_color = (220, 190, 40)
        eye_hi = (255, 240, 120)
        # Warm golden background with layered glow
        pygame.draw.rect(surf, (45, 30, 12, 100), (0, 0, w, h))
        # Inner warm radial glow
        self._soft_glow(surf, cx, int(h * 0.40), max(8, int(w * 0.50)), (200, 150, 40), 12)
        self._soft_glow(surf, cx, int(h * 0.40), max(6, int(w * 0.35)), (220, 170, 50), 10)
        # Fur mass (top and sides of head) - multi-layer with depth
        fur_rect = pygame.Rect(cx - int(w * 0.46), int(h * 0.05), int(w * 0.92), int(h * 0.65))
        pygame.draw.ellipse(surf, fur_dk, fur_rect.inflate(2, 2))
        pygame.draw.ellipse(surf, fur, fur_rect)
        # Fur highlight on top
        pygame.draw.ellipse(surf, (*fur_lt, 40), (cx - int(w * 0.25), int(h * 0.06), int(w * 0.50), int(h * 0.20)))
        # Fur texture - tufts with layered highlight
        for xf, yf in [(-0.35, 0.11), (-0.22, 0.06), (-0.10, 0.04), (0.02, 0.03),
                        (0.14, 0.05), (0.26, 0.08), (0.38, 0.13)]:
            tx = cx + int(xf * w)
            ty = int(h * (0.08 + yf))
            tw = int(w * 0.10)
            th = int(h * 0.13)
            pygame.draw.ellipse(surf, fur_lt, (tx - tw // 2, ty, tw, th))
            # Inner bright tip
            pygame.draw.ellipse(surf, (*fur_hi, 50), (tx - tw // 3, ty + 1, int(tw * 0.6), int(th * 0.5)))
        # Fur dark shading at sides - deeper
        for s in [-1, 1]:
            pygame.draw.ellipse(surf, fur_dk, (cx + s * int(w * 0.30) - int(w * 0.09), int(h * 0.12),
                                               int(w * 0.16), int(h * 0.40)))
            # Extra deep shadow at edge
            pygame.draw.ellipse(surf, (*self._mix(fur_dk, (60, 40, 20), 0.4), 40),
                                (cx + s * int(w * 0.36) - int(w * 0.06), int(h * 0.18),
                                 int(w * 0.10), int(h * 0.30)))
        # Monkey ears on sides - enhanced with inner detail
        for s in [-1, 1]:
            ear_x = cx + s * int(w * 0.40)
            ear_y = int(h * 0.28)
            ear_r = max(4, int(b * 0.28))
            # Ear outline (fur)
            pygame.draw.circle(surf, fur_dk, (ear_x, ear_y), ear_r + 2)
            pygame.draw.circle(surf, fur, (ear_x, ear_y), ear_r + 1)
            # Inner ear (pink skin)
            inner_r = max(2, int(ear_r * 0.75))
            pygame.draw.circle(surf, skin, (ear_x, ear_y), inner_r)
            # Inner ear shadow (deeper pink)
            pygame.draw.circle(surf, (215, 170, 135), (ear_x + s, ear_y + 1), max(1, int(inner_r * 0.6)))
            # Inner ear highlight
            pygame.draw.circle(surf, (*skin_hi, 50), (ear_x - s, ear_y - 1), max(1, int(inner_r * 0.35)))
        # Monkey face - using _face_base for multi-layer shading
        face_w = int(w * 0.48)
        face_h = int(h * 0.55)
        face_top = int(h * 0.28)
        self._face_base(surf, cx, face_top, face_w, face_h, skin, skin_sh, skin_hi)
        # Extra cheek warmth (reddish blush)
        for s in [-1, 1]:
            pygame.draw.ellipse(surf, (230, 160, 130, 25),
                                (cx + s * int(w * 0.07) - int(w * 0.05), face_top + int(face_h * 0.40),
                                 int(w * 0.09), int(face_h * 0.13)))
        # Golden crown/band on forehead - enhanced with gradient and gems
        band_y = int(h * 0.17)
        band_h = max(4, int(h * 0.09))
        band_w = int(w * 0.54)
        band_rect = pygame.Rect(cx - band_w // 2, band_y, band_w, band_h)
        # Crown shadow
        pygame.draw.rect(surf, crown_dk, band_rect.inflate(2, 2), border_radius=3)
        # Crown base
        pygame.draw.rect(surf, crown, band_rect, border_radius=2)
        # Crown gradient highlight (top half brighter)
        pygame.draw.rect(surf, (*crown_lt, 50),
                         (band_rect.x + 1, band_y, band_w - 2, band_h // 2), border_radius=2)
        # Crown specular shine
        pygame.draw.line(surf, (*crown_hi, 60),
                         (band_rect.x + int(band_w * 0.15), band_y + 1),
                         (band_rect.x + int(band_w * 0.60), band_y + 1), 1)
        # Crown outline
        pygame.draw.rect(surf, crown_dk, band_rect, 1, border_radius=2)
        # Crown center gem - ruby with highlight layers
        gem_r = max(2, int(b * 0.10))
        gem_x = cx
        gem_y = band_y + band_h // 2
        pygame.draw.circle(surf, (160, 30, 30), (gem_x, gem_y), gem_r + 1)
        pygame.draw.circle(surf, (200, 50, 50), (gem_x, gem_y), gem_r)
        pygame.draw.circle(surf, (230, 90, 90), (gem_x - 1, gem_y - 1), max(1, gem_r // 2))
        pygame.draw.circle(surf, (255, 150, 150), (gem_x - 1, gem_y - 1), max(1, gem_r // 3))
        # Side gems on crown
        for i, dx_frac in enumerate([-0.30, -0.15, 0.15, 0.30]):
            gx = cx + int(dx_frac * band_w)
            sr = max(1, int(b * 0.04))
            pygame.draw.circle(surf, crown_lt, (gx, gem_y), sr + 1)
            pygame.draw.circle(surf, crown_hi, (gx, gem_y), sr)
        # Fiery golden eyes using _hq_eye
        eye_y = int(h * 0.42)
        eye_sp = int(w * 0.10)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            ew = max(4, int(w * 0.07))
            eh = max(3, int(h * 0.06))
            self._hq_eye(surf, ex, eye_y, ew, eh, b, eye_color,
                         pupil_color=(50, 30, 10), sclera=(255, 252, 235),
                         glow_color=(220, 190, 40), sharp=True, sparkle=True,
                         lid_color=fur_dk)
        # Mischievous arched eyebrows - thicker, more expressive
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = eye_y - max(4, int(h * 0.08))
            bw = int(w * 0.06)
            bh = int(h * 0.04)
            # Thicker brow with fur texture
            pygame.draw.arc(surf, fur_dk, (bx - bw, by - bh, bw * 2, bh * 2),
                            0.3, 2.8, max(2, int(b * 0.08)))
            pygame.draw.arc(surf, self._mix(fur_dk, fur, 0.5), (bx - bw, by - bh - 1, bw * 2, bh * 2),
                            0.5, 2.6, max(1, int(b * 0.05)))
        # Flat monkey nose - enhanced with bridge and nostrils
        nose_y = int(h * 0.53)
        nose_w = max(4, int(w * 0.07))
        nose_h = max(3, int(h * 0.05))
        # Nose bridge line
        pygame.draw.line(surf, skin_sh, (cx, eye_y + int(h * 0.04)), (cx, nose_y), 1)
        # Nose body
        pygame.draw.ellipse(surf, skin_sh, (cx - nose_w, nose_y, nose_w * 2, nose_h * 2))
        pygame.draw.ellipse(surf, skin, (cx - nose_w + 1, nose_y, nose_w * 2 - 2, int(nose_h * 1.5)))
        # Nostrils with depth
        for s in [-1, 1]:
            nx = cx + s * max(2, nose_w // 2)
            ny = nose_y + nose_h
            pygame.draw.circle(surf, (160, 120, 90), (nx, ny), max(1, int(b * 0.05)))
            pygame.draw.circle(surf, (140, 100, 70), (nx + s, ny), max(1, int(b * 0.03)))
        # Nose highlight
        pygame.draw.ellipse(surf, (*skin_hi, 40), (cx - int(nose_w * 0.4), nose_y + 1,
                                                    int(nose_w * 0.8), int(nose_h * 0.8)))
        # Mischievous wide grin - enhanced with teeth detail
        mouth_y = int(h * 0.65)
        mouth_w = int(w * 0.15)
        # Mouth outline (darker)
        pygame.draw.arc(surf, (140, 90, 60), (cx - mouth_w - 1, mouth_y - int(h * 0.02) - 1,
                        mouth_w * 2 + 2, int(h * 0.09)),
                        3.3, 6.1, max(2, int(b * 0.08)))
        pygame.draw.arc(surf, (170, 120, 80), (cx - mouth_w, mouth_y - int(h * 0.02), mouth_w * 2, int(h * 0.08)),
                        3.3, 6.1, max(1, int(b * 0.07)))
        # Teeth showing in grin - individual teeth
        teeth_y = mouth_y + int(h * 0.01)
        teeth_w = int(mouth_w * 0.9)
        teeth_h = max(2, int(h * 0.025))
        pygame.draw.rect(surf, (250, 245, 235), (cx - teeth_w // 2, teeth_y, teeth_w, teeth_h))
        # Tooth dividers
        num_teeth = 4
        for i in range(1, num_teeth):
            tx = cx - teeth_w // 2 + int(i * teeth_w / num_teeth)
            pygame.draw.line(surf, (220, 210, 200), (tx, teeth_y), (tx, teeth_y + teeth_h), 1)
        # Teeth highlight
        pygame.draw.rect(surf, (255, 252, 248, 40), (cx - teeth_w // 2, teeth_y, teeth_w, max(1, teeth_h // 2)))
        # Canine fangs at edges
        for s in [-1, 1]:
            fx = cx + s * (teeth_w // 2 + 1)
            pygame.draw.polygon(surf, (248, 243, 230),
                                [(fx, teeth_y), (fx + s * max(1, int(w * 0.01)), teeth_y + teeth_h + 1), (fx, teeth_y + teeth_h)])
        # Chin tuft of fur - multi-layer
        pygame.draw.ellipse(surf, fur_dk, (cx - int(w * 0.07), int(h * 0.77), int(w * 0.14), int(h * 0.14)))
        pygame.draw.ellipse(surf, fur_lt, (cx - int(w * 0.06), int(h * 0.78), int(w * 0.12), int(h * 0.12)))
        pygame.draw.ellipse(surf, (*fur_hi, 40), (cx - int(w * 0.04), int(h * 0.79), int(w * 0.08), int(h * 0.06)))
        # Golden border with warm glow
        pygame.draw.rect(surf, (*crown, 160), (0, 0, w, h), 1, border_radius=2)
        # Corner golden dots
        for dx, dy in [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)]:
            pygame.draw.circle(surf, (*crown_lt, 80), (dx, dy), max(1, int(b * 0.03)))


# ─────────────────────────────────────────────
# 싱글턴
# ─────────────────────────────────────────────
_portrait_renderer_instance = None


def get_portrait_renderer() -> HeroPortraitRenderer:
    global _portrait_renderer_instance
    if _portrait_renderer_instance is None:
        _portrait_renderer_instance = HeroPortraitRenderer()
    return _portrait_renderer_instance
