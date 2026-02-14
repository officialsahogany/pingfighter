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
        hair_hi = (60, 40, 80)
        eye_glow = (200, 100, 255)
        eye_core = (255, 180, 255)
        band = (240, 240, 240)
        band_sh = (200, 200, 210)
        aura = (120, 50, 180)
        # Background aura
        aura_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_s, (*aura, 20), (0, 0, w, h))
        surf.blit(aura_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # Face
        face_w = int(w * 0.58)
        face_h = int(h * 0.72)
        face_top = int(h * 0.22)
        face_rect = pygame.Rect(cx - face_w // 2, face_top, face_w, face_h)
        pygame.draw.ellipse(surf, skin, face_rect)
        # Jaw shading
        jaw_rect = pygame.Rect(cx - face_w // 2, face_top + face_h // 2, face_w, face_h // 2)
        pygame.draw.ellipse(surf, skin_sh, jaw_rect)
        pygame.draw.ellipse(surf, skin, pygame.Rect(cx - face_w // 2 + 1, face_top, face_w - 2, int(face_h * 0.7)))
        # Cheek highlight
        pygame.draw.ellipse(surf, (*skin_hi, 60), (cx - face_w // 3, face_top + face_h * 3 // 8, face_w // 4, face_h // 5))
        # Hair back mass
        hair_rect = pygame.Rect(cx - int(w * 0.42), int(h * 0.02), int(w * 0.84), int(h * 0.55))
        pygame.draw.ellipse(surf, hair, hair_rect)
        # Spiky hair top
        spikes = [(-0.35, 0.05, -0.25, -0.12), (-0.15, 0.02, -0.05, -0.15),
                  (0.0, 0.01, 0.1, -0.18), (0.15, 0.02, 0.25, -0.10),
                  (0.3, 0.05, 0.38, -0.08), (-0.08, 0.0, 0.02, -0.22)]
        for x1f, y1f, x2f, y2f in spikes:
            px = [cx + int(x1f * w), cx + int(x2f * w), cx + int((x1f + x2f) * 0.5 * w)]
            py = [int(h * (0.15 + y1f)), int(h * (0.05 + y2f)), int(h * (0.12 + (y1f + y2f) * 0.5))]
            pygame.draw.polygon(surf, hair, list(zip(px, py)))
        # Hair highlight strands
        for dx, dy1, dy2 in [(-0.1, 0.08, 0.25), (0.05, 0.06, 0.22), (0.15, 0.09, 0.28)]:
            pygame.draw.line(surf, hair_hi,
                             (cx + int(dx * w), int(dy1 * h)),
                             (cx + int((dx + 0.02) * w), int(dy2 * h)), 1)
        # Bangs over forehead
        bang_pts = [(cx - int(w * 0.28), int(h * 0.18)),
                    (cx - int(w * 0.15), int(h * 0.38)),
                    (cx - int(w * 0.05), int(h * 0.35)),
                    (cx + int(w * 0.02), int(h * 0.40)),
                    (cx + int(w * 0.12), int(h * 0.32)),
                    (cx + int(w * 0.25), int(h * 0.18)),
                    (cx, int(h * 0.08))]
        pygame.draw.polygon(surf, hair, bang_pts)
        # Hachimaki headband
        band_y = int(h * 0.28)
        band_h = max(2, int(h * 0.06))
        pygame.draw.rect(surf, band, (cx - int(w * 0.32), band_y, int(w * 0.64), band_h))
        pygame.draw.rect(surf, band_sh, (cx - int(w * 0.32), band_y + band_h - 1, int(w * 0.64), 1))
        # Band tails
        tail_x = cx + int(w * 0.28)
        for i, (ty, tx_off) in enumerate([(0, 5), (3, 8), (6, 10)]):
            pygame.draw.line(surf, band, (tail_x, band_y + ty),
                             (tail_x + int(tx_off * b / 5), band_y + ty + int(h * 0.12)), max(1, band_h // 2))
        # Eyes - glowing purple demon eyes
        eye_y = int(h * 0.42)
        eye_sp = int(w * 0.12)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            # Eye glow aura
            glow_s = pygame.Surface((w, h), pygame.SRCALPHA)
            pygame.draw.circle(glow_s, (*eye_glow, 30), (ex, eye_y), max(3, int(b * 0.5)))
            surf.blit(glow_s, (0, 0), special_flags=pygame.BLEND_ADD)
            # Sclera
            sw = max(3, int(w * 0.08))
            sh = max(2, int(h * 0.06))
            pygame.draw.ellipse(surf, (240, 230, 240), (ex - sw, eye_y - sh, sw * 2, sh * 2))
            # Iris
            ir = max(2, int(min(sw, sh) * 0.7))
            pygame.draw.circle(surf, eye_glow, (ex, eye_y), ir)
            # Pupil
            pr = max(1, ir // 2)
            pygame.draw.circle(surf, (40, 10, 60), (ex, eye_y), pr)
            # Highlight
            pygame.draw.circle(surf, eye_core, (ex + s, eye_y - 1), max(1, pr // 2))
        # Nose
        nose_y = int(h * 0.55)
        pygame.draw.line(surf, skin_sh, (cx, int(h * 0.48)), (cx - 1, nose_y), 1)
        pygame.draw.circle(surf, skin_sh, (cx, nose_y), max(1, b // 8))
        # Mouth - thin serious line
        mouth_y = int(h * 0.65)
        pygame.draw.line(surf, (180, 130, 120), (cx - int(w * 0.06), mouth_y), (cx + int(w * 0.06), mouth_y), 1)
        # Chin shadow
        pygame.draw.ellipse(surf, (*skin_sh, 40), (cx - face_w // 4, int(h * 0.75), face_w // 2, int(h * 0.12)))
        # Border
        pygame.draw.rect(surf, (*aura, 180), (0, 0, w, h), 1, border_radius=2)

    # ─── 2. KRAKEN (크라켄) ───
    def _portrait_kraken(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        body = (140, 70, 60)
        body_dk = (100, 45, 35)
        body_lt = (170, 100, 85)
        dot_color = (80, 160, 255)
        eye_color = (200, 240, 100)
        eye_glow = (160, 220, 60)
        # Background - deep sea dark
        pygame.draw.rect(surf, (10, 20, 40, 120), (0, 0, w, h))
        # Dome-shaped head
        dome_w = int(w * 0.82)
        dome_h = int(h * 0.65)
        dome_top = int(h * 0.02)
        dome_rect = pygame.Rect(cx - dome_w // 2, dome_top, dome_w, dome_h)
        pygame.draw.ellipse(surf, body, dome_rect)
        # Dome shading - darker edges
        pygame.draw.ellipse(surf, body_dk, pygame.Rect(dome_rect.x + 2, dome_rect.y + 2, dome_w - 4, dome_h - 4), 2)
        # Dome highlight
        hi_rect = pygame.Rect(cx - dome_w // 4, dome_top + int(h * 0.05), dome_w // 3, dome_h // 3)
        pygame.draw.ellipse(surf, (*body_lt, 60), hi_rect)
        # Bioluminescent dots on dome
        import random
        rng = random.Random(42)
        for _ in range(12):
            dx = cx + rng.randint(-dome_w // 3, dome_w // 3)
            dy = dome_top + rng.randint(int(dome_h * 0.15), int(dome_h * 0.7))
            dr = max(1, rng.randint(1, int(b * 0.15) + 1))
            glow_s = pygame.Surface((dr * 6, dr * 6), pygame.SRCALPHA)
            pygame.draw.circle(glow_s, (*dot_color, 30), (dr * 3, dr * 3), dr * 3)
            pygame.draw.circle(glow_s, (*dot_color, 80), (dr * 3, dr * 3), dr * 2)
            pygame.draw.circle(glow_s, (200, 230, 255), (dr * 3, dr * 3), dr)
            surf.blit(glow_s, (dx - dr * 3, dy - dr * 3), special_flags=pygame.BLEND_ADD)
        # Large eyes
        eye_y = int(h * 0.40)
        eye_sp = int(w * 0.16)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            # Eye shape - tall oval
            ew = max(4, int(w * 0.12))
            eh = max(5, int(h * 0.16))
            pygame.draw.ellipse(surf, (20, 30, 10), (ex - ew, eye_y - eh, ew * 2, eh * 2))
            # Iris
            ir = max(3, int(min(ew, eh) * 0.75))
            pygame.draw.circle(surf, eye_color, (ex, eye_y), ir)
            # Pupil - vertical slit
            pygame.draw.ellipse(surf, (20, 20, 10), (ex - max(1, ir // 4), eye_y - ir + 1, max(2, ir // 2), ir * 2 - 2))
            # Glow
            glow_s = pygame.Surface((ew * 4, eh * 4), pygame.SRCALPHA)
            pygame.draw.circle(glow_s, (*eye_glow, 25), (ew * 2, eh * 2), ir * 2)
            surf.blit(glow_s, (ex - ew * 2, eye_y - eh * 2), special_flags=pygame.BLEND_ADD)
            # Highlight
            pygame.draw.circle(surf, (255, 255, 220), (ex + s * 2, eye_y - 2), max(1, ir // 3))
        # Small tentacles around chin area
        tent_y = int(h * 0.62)
        for i in range(7):
            tx = cx + int((i - 3) * w * 0.09)
            tent_len = int(h * 0.25) + (i % 3) * int(h * 0.06)
            pts = []
            for t in range(6):
                tf = t / 5.0
                ty = tent_y + int(tent_len * tf)
                wave = int(_sin(tf * 3.14 + i * 0.8) * w * 0.03)
                pts.append((tx + wave, ty))
            if len(pts) >= 2:
                thick = max(1, int(b * 0.18))
                for j in range(len(pts) - 1):
                    cur_thick = max(1, thick - j * thick // (len(pts)))
                    pygame.draw.line(surf, body, pts[j], pts[j + 1], cur_thick)
                # Suction cups
                for j in range(1, len(pts) - 1, 2):
                    pygame.draw.circle(surf, body_lt, pts[j], max(1, int(b * 0.06)))
        # Mouth slit
        mouth_y = int(h * 0.58)
        pygame.draw.arc(surf, body_dk, (cx - int(w * 0.08), mouth_y, int(w * 0.16), int(h * 0.06)), 3.14, 6.28, 1)
        pygame.draw.rect(surf, (*dot_color, 100), (0, 0, w, h), 1, border_radius=2)

    # ─── 3. CHRONOS (키르케/흑마녀) ───
    def _portrait_chronos(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        skin = (210, 200, 215)
        skin_sh = (180, 165, 185)
        skin_hi = (235, 230, 240)
        hood = (35, 20, 50)
        hood_lt = (55, 35, 75)
        eye_color = (180, 80, 255)
        eye_core = (230, 160, 255)
        aura = (100, 40, 160)
        lip = (160, 120, 150)
        # Dark background
        pygame.draw.rect(surf, (15, 8, 25, 140), (0, 0, w, h))
        # Aura wisps
        aura_s = pygame.Surface((w, h), pygame.SRCALPHA)
        for i in range(5):
            ax = cx + int(_sin(i * 1.3) * w * 0.3)
            ay = int(h * 0.3 + _cos(i * 1.7) * h * 0.2)
            ar = max(3, int(b * 0.4 + i * b * 0.1))
            pygame.draw.circle(aura_s, (*aura, 15), (ax, ay), ar)
        surf.blit(aura_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # Hood / cowl - large dark shape framing the face
        hood_pts = [(0, 0), (w, 0), (w, int(h * 0.7)),
                    (cx + int(w * 0.35), int(h * 0.85)),
                    (cx, int(h * 0.92)),
                    (cx - int(w * 0.35), int(h * 0.85)),
                    (0, int(h * 0.7))]
        pygame.draw.polygon(surf, hood, hood_pts)
        # Hood inner edge highlight
        inner_pts = [(cx - int(w * 0.3), int(h * 0.12)),
                     (cx - int(w * 0.35), int(h * 0.5)),
                     (cx - int(w * 0.3), int(h * 0.75)),
                     (cx, int(h * 0.85)),
                     (cx + int(w * 0.3), int(h * 0.75)),
                     (cx + int(w * 0.35), int(h * 0.5)),
                     (cx + int(w * 0.3), int(h * 0.12))]
        if len(inner_pts) >= 3:
            pygame.draw.polygon(surf, hood_lt, inner_pts, 1)
        # Face inside hood
        face_w = int(w * 0.48)
        face_h = int(h * 0.60)
        face_top = int(h * 0.20)
        face_rect = pygame.Rect(cx - face_w // 2, face_top, face_w, face_h)
        pygame.draw.ellipse(surf, skin, face_rect)
        # Face shading
        sh_rect = pygame.Rect(cx - face_w // 2, face_top + face_h // 2, face_w, face_h // 2)
        pygame.draw.ellipse(surf, skin_sh, sh_rect)
        pygame.draw.ellipse(surf, skin, pygame.Rect(face_rect.x + 1, face_rect.y, face_w - 2, int(face_h * 0.65)))
        # Forehead highlight
        pygame.draw.ellipse(surf, (*skin_hi, 50), (cx - face_w // 4, face_top + int(face_h * 0.08), face_w // 2, face_h // 4))
        # Eyes - glowing purple, mysterious
        eye_y = int(h * 0.42)
        eye_sp = int(w * 0.10)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            # Glow
            glow_s = pygame.Surface((w, h), pygame.SRCALPHA)
            pygame.draw.circle(glow_s, (*eye_color, 25), (ex, eye_y), max(4, int(b * 0.5)))
            surf.blit(glow_s, (0, 0), special_flags=pygame.BLEND_ADD)
            # Sclera
            sw = max(3, int(w * 0.07))
            sh = max(2, int(h * 0.05))
            pygame.draw.ellipse(surf, (230, 220, 240), (ex - sw, eye_y - sh, sw * 2, sh * 2))
            # Iris
            ir = max(2, int(min(sw, sh) * 0.8))
            pygame.draw.circle(surf, eye_color, (ex, eye_y), ir)
            # Pupil
            pr = max(1, ir * 2 // 3)
            pygame.draw.circle(surf, (30, 10, 50), (ex, eye_y), pr)
            # Highlight
            pygame.draw.circle(surf, eye_core, (ex + s, eye_y - 1), max(1, pr // 2))
        # Thin eyebrows
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = eye_y - max(2, int(h * 0.06))
            pygame.draw.line(surf, skin_sh, (bx - s * int(w * 0.04), by + 1), (bx + s * int(w * 0.03), by), 1)
        # Nose
        nose_y = int(h * 0.54)
        pygame.draw.line(surf, skin_sh, (cx, int(h * 0.48)), (cx - 1, nose_y), 1)
        # Mouth - slight mysterious smile
        mouth_y = int(h * 0.64)
        pygame.draw.arc(surf, lip, (cx - int(w * 0.06), mouth_y - int(h * 0.02), int(w * 0.12), int(h * 0.05)), 3.3, 6.1, 1)
        # Purple aura wisps near face edges
        for i in range(3):
            wy = int(h * 0.3 + i * h * 0.15)
            for s in [-1, 1]:
                wx = cx + s * int(w * 0.28 + _sin(i * 2.0) * w * 0.05)
                pygame.draw.circle(surf, (*aura, 40), (wx, wy), max(1, int(b * 0.12)))
        pygame.draw.rect(surf, (*aura, 150), (0, 0, w, h), 1, border_radius=2)

    # ─── 4. ONIMARU (오니마루/악마) ───
    def _portrait_onimaru(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        skin = (200, 60, 50)
        skin_dk = (160, 40, 35)
        skin_lt = (230, 90, 70)
        hair = (30, 20, 25)
        horn = (180, 170, 140)
        horn_dk = (140, 130, 100)
        eye_color = (255, 220, 40)
        eye_core = (255, 255, 120)
        fang = (240, 235, 220)
        # Fiery background
        fire_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(fire_s, (200, 60, 20, 25), (0, int(h * 0.2), w, int(h * 0.8)))
        surf.blit(fire_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # Wild dark hair - back mass
        hair_rect = pygame.Rect(cx - int(w * 0.45), int(h * 0.0), int(w * 0.9), int(h * 0.5))
        pygame.draw.ellipse(surf, hair, hair_rect)
        # Wild spikes
        for x_off, y_off in [(-0.38, 0.08), (-0.25, -0.02), (-0.1, -0.05), (0.05, -0.06), (0.2, -0.03), (0.35, 0.06)]:
            sx = cx + int(x_off * w)
            sy = int(h * (0.1 + y_off))
            pygame.draw.polygon(surf, hair, [(sx - int(w * 0.06), int(h * 0.15)),
                                             (sx, sy), (sx + int(w * 0.06), int(h * 0.15))])
        # Face - red
        face_w = int(w * 0.60)
        face_h = int(h * 0.68)
        face_top = int(h * 0.20)
        face_rect = pygame.Rect(cx - face_w // 2, face_top, face_w, face_h)
        pygame.draw.ellipse(surf, skin, face_rect)
        # Face shading
        pygame.draw.ellipse(surf, skin_dk, pygame.Rect(face_rect.x + 2, face_top + face_h // 2, face_w - 4, face_h // 2))
        pygame.draw.ellipse(surf, skin, pygame.Rect(face_rect.x + 2, face_top, face_w - 4, int(face_h * 0.6)))
        # Highlight on cheek
        pygame.draw.ellipse(surf, (*skin_lt, 50), (cx - face_w // 3, face_top + face_h // 3, face_w // 4, face_h // 5))
        # Demon horns
        for s in [-1, 1]:
            hx = cx + s * int(w * 0.18)
            hy = int(h * 0.18)
            horn_pts = [(hx - s * int(w * 0.04), hy + int(h * 0.08)),
                        (hx + s * int(w * 0.08), hy - int(h * 0.18)),
                        (hx + s * int(w * 0.02), hy + int(h * 0.06))]
            pygame.draw.polygon(surf, horn, horn_pts)
            pygame.draw.polygon(surf, horn_dk, horn_pts, 1)
            # Horn ridges
            for t in range(3):
                tf = (t + 1) / 4.0
                rx = int(hx + s * int(w * 0.08) * tf)
                ry = int(hy + int(h * 0.08) - int(h * 0.26) * tf)
                pygame.draw.line(surf, horn_dk, (rx - 1, ry), (rx + 1, ry), 1)
        # Fierce brow line
        for s in [-1, 1]:
            bx1 = cx + s * int(w * 0.04)
            bx2 = cx + s * int(w * 0.18)
            by = int(h * 0.34)
            pygame.draw.line(surf, (80, 20, 20), (bx1, by + 2), (bx2, by - 1), max(1, int(b * 0.12)))
        # Fierce yellow eyes
        eye_y = int(h * 0.42)
        eye_sp = int(w * 0.12)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            sw = max(3, int(w * 0.08))
            sh = max(2, int(h * 0.05))
            # Angular eye shape
            eye_pts = [(ex - sw, eye_y), (ex, eye_y - sh), (ex + sw, eye_y), (ex, eye_y + sh)]
            pygame.draw.polygon(surf, (255, 250, 200), eye_pts)
            # Iris
            ir = max(2, int(min(sw, sh) * 0.7))
            pygame.draw.circle(surf, eye_color, (ex, eye_y), ir)
            # Pupil - vertical slit
            pygame.draw.ellipse(surf, (40, 10, 10), (ex - max(1, ir // 4), eye_y - ir + 1, max(2, ir // 2), ir * 2 - 2))
            # Glow
            pygame.draw.circle(surf, (*eye_core, 30), (ex, eye_y), ir + 2)
        # Nose - broad
        nose_y = int(h * 0.55)
        pygame.draw.line(surf, skin_dk, (cx - 1, int(h * 0.47)), (cx - 2, nose_y), 1)
        pygame.draw.line(surf, skin_dk, (cx + 1, int(h * 0.47)), (cx + 2, nose_y), 1)
        # Mouth with fangs
        mouth_y = int(h * 0.65)
        mw = int(w * 0.14)
        pygame.draw.line(surf, (120, 30, 25), (cx - mw, mouth_y), (cx + mw, mouth_y), max(1, int(b * 0.08)))
        # Upper fangs
        for s in [-1, 1]:
            fx = cx + s * int(mw * 0.6)
            pygame.draw.polygon(surf, fang, [(fx - 1, mouth_y - 1), (fx, mouth_y + int(h * 0.06)), (fx + 1, mouth_y - 1)])
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
        eye_color = (140, 100, 200)
        eye_hi = (200, 180, 255)
        blush = (255, 160, 160)
        lip = (230, 140, 150)
        ribbon = (255, 100, 130)
        ribbon_dk = (200, 70, 100)
        # Soft pink background
        pygame.draw.rect(surf, (60, 30, 50, 60), (0, 0, w, h))
        # Fluffy hair - back volume
        hair_back = pygame.Rect(cx - int(w * 0.48), int(h * 0.0), int(w * 0.96), int(h * 0.75))
        pygame.draw.ellipse(surf, hair, hair_back)
        # Hair side puffs
        for s in [-1, 1]:
            puff_x = cx + s * int(w * 0.35)
            pygame.draw.ellipse(surf, hair, (puff_x - int(w * 0.14), int(h * 0.25), int(w * 0.28), int(h * 0.45)))
            pygame.draw.ellipse(surf, hair_lt, (puff_x - int(w * 0.10), int(h * 0.28), int(w * 0.15), int(h * 0.20)))
        # Face
        face_w = int(w * 0.50)
        face_h = int(h * 0.65)
        face_top = int(h * 0.22)
        face_rect = pygame.Rect(cx - face_w // 2, face_top, face_w, face_h)
        pygame.draw.ellipse(surf, skin, face_rect)
        # Soft shading
        pygame.draw.ellipse(surf, skin_sh, pygame.Rect(face_rect.x, face_top + face_h * 2 // 3, face_w, face_h // 3))
        pygame.draw.ellipse(surf, skin, pygame.Rect(face_rect.x + 1, face_top, face_w - 2, int(face_h * 0.55)))
        # Forehead highlight
        pygame.draw.ellipse(surf, (*skin_hi, 40), (cx - face_w // 4, face_top + int(face_h * 0.05), face_w // 2, face_h // 4))
        # Hair bangs - soft round bangs
        bang_y = int(h * 0.22)
        for i in range(5):
            bx = cx + int((i - 2) * w * 0.08)
            by_end = bang_y + int(h * 0.12) + (i % 2) * int(h * 0.04)
            pygame.draw.ellipse(surf, hair, (bx - int(w * 0.06), int(h * 0.08), int(w * 0.12), by_end - int(h * 0.05)))
        # Hair highlights
        for dx in [-0.12, 0.0, 0.10]:
            pygame.draw.line(surf, hair_lt, (cx + int(dx * w), int(h * 0.06)), (cx + int(dx * w), int(h * 0.28)), 1)
        # Ribbon bow on top
        rib_y = int(h * 0.06)
        rib_cx = cx + int(w * 0.15)
        # Bow loops
        for s in [-1, 1]:
            bow_pts = [(rib_cx, rib_y + int(h * 0.03)),
                       (rib_cx + s * int(w * 0.10), rib_y - int(h * 0.02)),
                       (rib_cx + s * int(w * 0.08), rib_y + int(h * 0.06))]
            pygame.draw.polygon(surf, ribbon, bow_pts)
            pygame.draw.polygon(surf, ribbon_dk, bow_pts, 1)
        # Bow center knot
        pygame.draw.circle(surf, ribbon_dk, (rib_cx, rib_y + int(h * 0.03)), max(1, int(b * 0.08)))
        # Big doll-like eyes
        eye_y = int(h * 0.44)
        eye_sp = int(w * 0.10)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            # Large round eye
            ew = max(4, int(w * 0.09))
            eh = max(4, int(h * 0.09))
            pygame.draw.ellipse(surf, (255, 255, 255), (ex - ew, eye_y - eh, ew * 2, eh * 2))
            # Iris - large
            ir = max(3, int(min(ew, eh) * 0.8))
            pygame.draw.circle(surf, eye_color, (ex, eye_y + 1), ir)
            # Pupil
            pr = max(1, ir // 2)
            pygame.draw.circle(surf, (30, 20, 50), (ex, eye_y + 1), pr)
            # Sparkle highlights
            pygame.draw.circle(surf, (255, 255, 255), (ex + s * 2, eye_y - 2), max(1, ir // 3))
            pygame.draw.circle(surf, (255, 255, 255), (ex - s, eye_y + 2), max(1, ir // 5))
            # Upper lash line
            pygame.draw.arc(surf, (60, 30, 60), (ex - ew, eye_y - eh, ew * 2, eh * 2), 0.3, 2.8, max(1, int(b * 0.06)))
        # Rosy cheeks
        for s in [-1, 1]:
            chx = cx + s * int(w * 0.14)
            chy = int(h * 0.54)
            pygame.draw.ellipse(surf, (*blush, 50), (chx - int(w * 0.05), chy - int(h * 0.03), int(w * 0.10), int(h * 0.06)))
        # Cute small nose
        pygame.draw.circle(surf, skin_sh, (cx, int(h * 0.54)), max(1, int(b * 0.06)))
        # Small sweet mouth
        mouth_y = int(h * 0.63)
        pygame.draw.ellipse(surf, lip, (cx - int(w * 0.04), mouth_y, int(w * 0.08), int(h * 0.03)))
        pygame.draw.ellipse(surf, (*skin_hi, 120), (cx - int(w * 0.02), mouth_y, int(w * 0.04), int(h * 0.015)))
        pygame.draw.rect(surf, (*ribbon, 180), (0, 0, w, h), 1, border_radius=2)

    # ─── 6. IGNIS (이그니스/용기사) ───
    def _portrait_ignis(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        helmet = (180, 50, 30)
        helmet_lt = (220, 90, 50)
        helmet_dk = (130, 30, 20)
        gold = (220, 190, 80)
        gold_dk = (180, 150, 50)
        skin = (230, 200, 175)
        skin_sh = (200, 170, 145)
        hair = (240, 120, 40)
        hair_lt = (255, 170, 70)
        eye_color = (200, 100, 30)
        eye_hi = (255, 200, 100)
        # Fiery background
        fire_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(fire_s, (200, 80, 20, 20), (cx - int(w * 0.4), 0, int(w * 0.8), h))
        surf.blit(fire_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # Dragon helmet - covers upper half of face
        helm_pts = [(cx - int(w * 0.45), int(h * 0.50)),
                    (cx - int(w * 0.42), int(h * 0.10)),
                    (cx - int(w * 0.20), int(h * 0.02)),
                    (cx, int(h * -0.02)),
                    (cx + int(w * 0.20), int(h * 0.02)),
                    (cx + int(w * 0.42), int(h * 0.10)),
                    (cx + int(w * 0.45), int(h * 0.50))]
        pygame.draw.polygon(surf, helmet, helm_pts)
        pygame.draw.polygon(surf, helmet_dk, helm_pts, 2)
        # Helmet center ridge
        pygame.draw.line(surf, gold, (cx, int(h * -0.02)), (cx, int(h * 0.50)), max(1, int(b * 0.10)))
        # Helmet side ridges
        for s in [-1, 1]:
            pygame.draw.line(surf, gold_dk, (cx + s * int(w * 0.20), int(h * 0.05)),
                             (cx + s * int(w * 0.38), int(h * 0.48)), max(1, int(b * 0.06)))
        # Helmet highlight
        pygame.draw.ellipse(surf, (*helmet_lt, 50), (cx - int(w * 0.15), int(h * 0.08), int(w * 0.30), int(h * 0.18)))
        # Visor slit for eyes
        visor_y = int(h * 0.38)
        visor_h = max(3, int(h * 0.08))
        visor_rect = pygame.Rect(cx - int(w * 0.30), visor_y, int(w * 0.60), visor_h)
        pygame.draw.rect(surf, (10, 5, 5), visor_rect, border_radius=2)
        # Eyes through visor
        eye_sp = int(w * 0.12)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            ir = max(2, visor_h // 2)
            pygame.draw.circle(surf, eye_color, (ex, visor_y + visor_h // 2), ir)
            pygame.draw.circle(surf, eye_hi, (ex + s, visor_y + visor_h // 2 - 1), max(1, ir // 2))
        # Lower face (below helmet)
        lower_top = int(h * 0.48)
        face_w = int(w * 0.52)
        face_h = int(h * 0.48)
        face_rect = pygame.Rect(cx - face_w // 2, lower_top, face_w, face_h)
        pygame.draw.ellipse(surf, skin, face_rect)
        pygame.draw.ellipse(surf, skin_sh, pygame.Rect(face_rect.x, lower_top + face_h // 2, face_w, face_h // 2))
        # Nose
        pygame.draw.line(surf, skin_sh, (cx, int(h * 0.55)), (cx - 1, int(h * 0.63)), 1)
        # Determined mouth
        mouth_y = int(h * 0.72)
        pygame.draw.line(surf, (180, 130, 110), (cx - int(w * 0.06), mouth_y), (cx + int(w * 0.06), mouth_y), 1)
        # Fiery hair coming out from under helmet
        for i in range(8):
            hx = cx + int((i - 3.5) * w * 0.08)
            hy_start = int(h * 0.08)
            hy_end = int(h * -0.05) - (i % 3) * int(h * 0.05)
            hair_c = hair if i % 2 == 0 else hair_lt
            pygame.draw.polygon(surf, hair_c, [(hx - int(w * 0.03), hy_start),
                                               (hx, hy_end),
                                               (hx + int(w * 0.03), hy_start)])
        # Side hair wisps
        for s in [-1, 1]:
            for j in range(3):
                sx = cx + s * int(w * 0.42)
                sy = int(h * 0.35 + j * h * 0.08)
                pygame.draw.line(surf, hair, (sx, sy), (sx + s * int(w * 0.08), sy + int(h * 0.10)), max(1, int(b * 0.08)))
        pygame.draw.rect(surf, (*gold, 180), (0, 0, w, h), 1, border_radius=2)

    # ─── 7. GEAR (기어/스팀펑크) ───
    def _portrait_gear(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        skin = (215, 185, 150)
        skin_sh = (190, 160, 125)
        skin_hi = (240, 215, 185)
        hair = (120, 80, 50)
        hair_lt = (155, 115, 75)
        goggle = (180, 120, 50)
        goggle_lt = (210, 160, 80)
        goggle_dk = (140, 90, 35)
        lens = (180, 220, 240)
        lens_hi = (220, 245, 255)
        oil = (60, 50, 40)
        cog = (170, 140, 90)
        # Warm background
        pygame.draw.rect(surf, (50, 35, 25, 80), (0, 0, w, h))
        # Messy brown hair
        hair_rect = pygame.Rect(cx - int(w * 0.44), int(h * 0.02), int(w * 0.88), int(h * 0.48))
        pygame.draw.ellipse(surf, hair, hair_rect)
        # Messy hair tufts
        for xf, yf in [(-0.30, 0.0), (-0.15, -0.04), (0.0, -0.06), (0.12, -0.03), (0.28, 0.01)]:
            tx = cx + int(xf * w)
            ty = int(h * (0.06 + yf))
            pygame.draw.ellipse(surf, hair, (tx - int(w * 0.08), ty, int(w * 0.16), int(h * 0.18)))
        # Hair highlights
        for dx in [-0.10, 0.05, 0.18]:
            pygame.draw.line(surf, hair_lt, (cx + int(dx * w), int(h * 0.08)), (cx + int(dx * w) + 2, int(h * 0.25)), 1)
        # Round friendly face
        face_w = int(w * 0.56)
        face_h = int(h * 0.68)
        face_top = int(h * 0.22)
        face_rect = pygame.Rect(cx - face_w // 2, face_top, face_w, face_h)
        pygame.draw.ellipse(surf, skin, face_rect)
        # Cheek shading
        pygame.draw.ellipse(surf, skin_sh, pygame.Rect(face_rect.x, face_top + face_h * 2 // 3, face_w, face_h // 3))
        pygame.draw.ellipse(surf, skin, pygame.Rect(face_rect.x + 1, face_top, face_w - 2, int(face_h * 0.55)))
        # Forehead highlight
        pygame.draw.ellipse(surf, (*skin_hi, 40), (cx - face_w // 4, face_top + int(face_h * 0.06), face_w // 2, face_h // 4))
        # Goggles on forehead
        gog_y = int(h * 0.18)
        gog_h = max(4, int(h * 0.12))
        # Strap
        pygame.draw.rect(surf, goggle_dk, (cx - int(w * 0.38), gog_y + gog_h // 4, int(w * 0.76), gog_h // 2))
        # Lens housings
        for s in [-1, 1]:
            gx = cx + s * int(w * 0.12)
            lr = max(3, int(h * 0.06))
            pygame.draw.circle(surf, goggle, (gx, gog_y + gog_h // 2), lr + 2)
            pygame.draw.circle(surf, goggle_dk, (gx, gog_y + gog_h // 2), lr + 2, 1)
            pygame.draw.circle(surf, lens, (gx, gog_y + gog_h // 2), lr)
            pygame.draw.circle(surf, lens_hi, (gx + s, gog_y + gog_h // 2 - 1), max(1, lr // 3))
        # Bridge
        pygame.draw.line(surf, goggle, (cx - int(w * 0.04), gog_y + gog_h // 2),
                         (cx + int(w * 0.04), gog_y + gog_h // 2), max(1, int(b * 0.08)))
        # Friendly eyes
        eye_y = int(h * 0.44)
        eye_sp = int(w * 0.11)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            sw = max(3, int(w * 0.07))
            sh = max(2, int(h * 0.06))
            pygame.draw.ellipse(surf, (255, 255, 255), (ex - sw, eye_y - sh, sw * 2, sh * 2))
            ir = max(2, int(min(sw, sh) * 0.65))
            pygame.draw.circle(surf, (100, 70, 40), (ex, eye_y), ir)
            pr = max(1, ir // 2)
            pygame.draw.circle(surf, (30, 20, 15), (ex, eye_y), pr)
            pygame.draw.circle(surf, (255, 255, 240), (ex + s, eye_y - 1), max(1, pr // 2))
        # Thick friendly eyebrows
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = eye_y - max(3, int(h * 0.07))
            pygame.draw.line(surf, hair, (bx - s * int(w * 0.04), by + 1), (bx + s * int(w * 0.04), by), max(1, int(b * 0.08)))
        # Round nose
        pygame.draw.circle(surf, skin_sh, (cx, int(h * 0.56)), max(2, int(b * 0.10)))
        pygame.draw.circle(surf, skin_hi, (cx - 1, int(h * 0.55)), max(1, int(b * 0.05)))
        # Friendly grin
        mouth_y = int(h * 0.66)
        pygame.draw.arc(surf, (160, 110, 90), (cx - int(w * 0.08), mouth_y - int(h * 0.03), int(w * 0.16), int(h * 0.08)), 3.3, 6.1, 1)
        # Oil smudges on cheeks
        for s in [-1, 1]:
            ox = cx + s * int(w * 0.18)
            oy = int(h * 0.52)
            pygame.draw.ellipse(surf, (*oil, 60), (ox - int(w * 0.04), oy, int(w * 0.06), int(h * 0.03)))
        # Cog decorations near ears
        for s in [-1, 1]:
            cog_x = cx + s * int(w * 0.30)
            cog_y = int(h * 0.40)
            cr = max(2, int(b * 0.15))
            pygame.draw.circle(surf, cog, (cog_x, cog_y), cr)
            pygame.draw.circle(surf, goggle_dk, (cog_x, cog_y), cr, 1)
            for a in range(6):
                angle = a * 3.14159 / 3
                tx = cog_x + int(_cos(angle) * cr)
                ty = cog_y + int(_sin(angle) * cr)
                pygame.draw.circle(surf, cog, (tx, ty), max(1, cr // 3))
        pygame.draw.rect(surf, (*goggle, 180), (0, 0, w, h), 1, border_radius=2)

    # ─── 8. KUROKAGE (쿠로카게/닌자) ───
    def _portrait_kurokage(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        cloth = (30, 25, 35)
        cloth_lt = (50, 45, 55)
        cloth_dk = (15, 12, 20)
        skin = (215, 190, 165)
        skin_sh = (185, 160, 135)
        eye_color = (180, 200, 220)
        eye_hi = (230, 240, 255)
        scar = (200, 140, 130)
        # Dark background
        pygame.draw.rect(surf, (10, 8, 15, 150), (0, 0, w, h))
        # Hood/cowl covering head
        hood_pts = [(0, 0), (w, 0), (w, int(h * 0.6)),
                    (cx + int(w * 0.40), int(h * 0.80)),
                    (cx, int(h * 0.90)),
                    (cx - int(w * 0.40), int(h * 0.80)),
                    (0, int(h * 0.6))]
        pygame.draw.polygon(surf, cloth, hood_pts)
        # Hood fold lines
        pygame.draw.line(surf, cloth_lt, (cx - int(w * 0.1), int(h * 0.05)), (cx - int(w * 0.15), int(h * 0.55)), 1)
        pygame.draw.line(surf, cloth_lt, (cx + int(w * 0.1), int(h * 0.05)), (cx + int(w * 0.15), int(h * 0.55)), 1)
        # Visible skin strip - just the eye area
        strip_top = int(h * 0.28)
        strip_h = int(h * 0.18)
        strip_pts = [(cx - int(w * 0.32), strip_top),
                     (cx + int(w * 0.32), strip_top),
                     (cx + int(w * 0.30), strip_top + strip_h),
                     (cx - int(w * 0.30), strip_top + strip_h)]
        pygame.draw.polygon(surf, skin, strip_pts)
        # Shading on skin
        pygame.draw.polygon(surf, skin_sh, [(cx - int(w * 0.30), strip_top + strip_h // 2),
                                            (cx + int(w * 0.30), strip_top + strip_h // 2),
                                            (cx + int(w * 0.30), strip_top + strip_h),
                                            (cx - int(w * 0.30), strip_top + strip_h)])
        # Mask covering lower face
        mask_top = strip_top + strip_h
        mask_pts = [(cx - int(w * 0.32), mask_top),
                    (cx + int(w * 0.32), mask_top),
                    (cx + int(w * 0.25), int(h * 0.85)),
                    (cx, int(h * 0.92)),
                    (cx - int(w * 0.25), int(h * 0.85))]
        pygame.draw.polygon(surf, cloth_dk, mask_pts)
        # Mask fold detail
        pygame.draw.line(surf, cloth_lt, (cx, mask_top + 2), (cx, int(h * 0.80)), 1)
        # Sharp piercing eyes
        eye_y = strip_top + strip_h // 2
        eye_sp = int(w * 0.13)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            # Narrow sharp eye shape
            sw = max(4, int(w * 0.09))
            sh = max(2, int(h * 0.04))
            eye_pts = [(ex - sw, eye_y + 1), (ex - sw // 2, eye_y - sh),
                       (ex + sw // 2, eye_y - sh), (ex + sw, eye_y + 1),
                       (ex, eye_y + sh)]
            pygame.draw.polygon(surf, (240, 240, 245), eye_pts)
            # Iris
            ir = max(2, sh)
            pygame.draw.circle(surf, eye_color, (ex, eye_y), ir)
            # Pupil
            pr = max(1, ir // 2)
            pygame.draw.circle(surf, (15, 15, 25), (ex, eye_y), pr)
            # Highlight
            pygame.draw.circle(surf, eye_hi, (ex + s, eye_y - 1), max(1, pr // 2))
        # Scar across right eye
        sc_x = cx + int(w * 0.13)
        pygame.draw.line(surf, scar, (sc_x - int(w * 0.02), strip_top - int(h * 0.03)),
                         (sc_x + int(w * 0.02), strip_top + strip_h + int(h * 0.05)), max(1, int(b * 0.06)))
        # Intense brow furrow
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = strip_top + 1
            pygame.draw.line(surf, skin_sh, (bx - s * int(w * 0.05), by + 1), (bx + s * int(w * 0.03), by), 1)
        pygame.draw.rect(surf, (*cloth_lt, 150), (0, 0, w, h), 1, border_radius=2)

    # ─── 9. BANSHEE (밴시/해골) ───
    def _portrait_banshee(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        bone = (230, 220, 210)
        bone_sh = (190, 180, 170)
        bone_dk = (160, 150, 140)
        bone_hi = (245, 240, 235)
        gold_mask = (220, 190, 80)
        gold_dk = (180, 150, 50)
        gold_lt = (245, 220, 120)
        eye_color = (60, 220, 240)
        eye_glow = (80, 255, 255)
        ghost_hair = (180, 200, 220)
        # Dark ethereal background
        pygame.draw.rect(surf, (15, 20, 30, 140), (0, 0, w, h))
        # Ghost glow
        glow_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_s, (*eye_color, 15), (cx - int(w * 0.35), int(h * 0.1), int(w * 0.7), int(h * 0.7)))
        surf.blit(glow_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # Wispy ghost hair
        for i in range(6):
            hx = cx + int((i - 2.5) * w * 0.12)
            pts = [(hx, int(h * 0.05))]
            for t in range(4):
                tf = (t + 1) / 4.0
                hy = int(h * 0.05 + h * 0.35 * tf)
                wave = int(_sin(tf * 4.0 + i * 1.2) * w * 0.04)
                pts.append((hx + wave, hy))
            if len(pts) >= 2:
                for j in range(len(pts) - 1):
                    alpha = 180 - j * 30
                    pygame.draw.line(surf, (*ghost_hair, max(40, alpha)), pts[j], pts[j + 1], max(1, int(b * 0.08) - j))
        # Skull face
        face_w = int(w * 0.54)
        face_h = int(h * 0.62)
        face_top = int(h * 0.15)
        face_rect = pygame.Rect(cx - face_w // 2, face_top, face_w, face_h)
        pygame.draw.ellipse(surf, bone, face_rect)
        # Skull shading
        pygame.draw.ellipse(surf, bone_sh, pygame.Rect(face_rect.x + 2, face_top + face_h // 2, face_w - 4, face_h // 2))
        pygame.draw.ellipse(surf, bone, pygame.Rect(face_rect.x + 2, face_top, face_w - 4, int(face_h * 0.55)))
        # Cracks
        crack_start = (cx - int(w * 0.08), face_top + int(face_h * 0.12))
        crack_mid = (cx - int(w * 0.10), face_top + int(face_h * 0.30))
        crack_end = (cx - int(w * 0.06), face_top + int(face_h * 0.42))
        pygame.draw.line(surf, bone_dk, crack_start, crack_mid, 1)
        pygame.draw.line(surf, bone_dk, crack_mid, crack_end, 1)
        pygame.draw.line(surf, bone_dk, crack_mid, (crack_mid[0] - int(w * 0.04), crack_mid[1] + int(h * 0.05)), 1)
        # Eye sockets
        eye_y = int(h * 0.35)
        eye_sp = int(w * 0.11)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            sock_w = max(4, int(w * 0.10))
            sock_h = max(4, int(h * 0.10))
            pygame.draw.ellipse(surf, (20, 25, 30), (ex - sock_w, eye_y - sock_h, sock_w * 2, sock_h * 2))
            # Glowing cyan eyes
            glow_s2 = pygame.Surface((sock_w * 4, sock_h * 4), pygame.SRCALPHA)
            pygame.draw.circle(glow_s2, (*eye_color, 40), (sock_w * 2, sock_h * 2), sock_w)
            surf.blit(glow_s2, (ex - sock_w * 2, eye_y - sock_h * 2), special_flags=pygame.BLEND_ADD)
            ir = max(2, int(min(sock_w, sock_h) * 0.5))
            pygame.draw.circle(surf, eye_color, (ex, eye_y), ir)
            pygame.draw.circle(surf, eye_glow, (ex, eye_y), max(1, ir // 2))
            pygame.draw.circle(surf, (255, 255, 255), (ex + s, eye_y - 1), max(1, ir // 3))
        # Nose cavity
        nose_y = int(h * 0.50)
        pygame.draw.polygon(surf, bone_dk, [(cx - int(w * 0.02), nose_y - int(h * 0.03)),
                                            (cx + int(w * 0.02), nose_y - int(h * 0.03)),
                                            (cx, nose_y + int(h * 0.02))])
        # Golden jaw mask/guard
        mask_top = int(h * 0.55)
        mask_pts = [(cx - int(w * 0.30), mask_top),
                    (cx + int(w * 0.30), mask_top),
                    (cx + int(w * 0.25), int(h * 0.85)),
                    (cx, int(h * 0.95)),
                    (cx - int(w * 0.25), int(h * 0.85))]
        pygame.draw.polygon(surf, gold_mask, mask_pts)
        pygame.draw.polygon(surf, gold_dk, mask_pts, 1)
        # Mask detail lines
        pygame.draw.line(surf, gold_lt, (cx, mask_top + 2), (cx, int(h * 0.88)), 1)
        for s in [-1, 1]:
            pygame.draw.line(surf, gold_dk, (cx + s * int(w * 0.12), mask_top + 3),
                             (cx + s * int(w * 0.10), int(h * 0.82)), 1)
        # Mask rivets
        for s in [-1, 1]:
            for j in range(2):
                ry = mask_top + int(h * 0.08) + j * int(h * 0.12)
                rx = cx + s * int(w * 0.22 - j * w * 0.04)
                pygame.draw.circle(surf, gold_lt, (rx, ry), max(1, int(b * 0.04)))
        pygame.draw.rect(surf, (*eye_color, 150), (0, 0, w, h), 1, border_radius=2)

    # ─── 10. NECRO (네크로/사령술사) ───
    def _portrait_necro(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        skin = (170, 150, 175)
        skin_sh = (140, 120, 145)
        skin_hi = (195, 180, 200)
        bone = (220, 210, 190)
        bone_dk = (180, 170, 150)
        eye_color = (80, 240, 100)
        eye_glow = (60, 200, 80)
        dark_aura = (40, 20, 60)
        # Dark background
        pygame.draw.rect(surf, (12, 8, 20, 140), (0, 0, w, h))
        # Dark aura
        aura_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_s, (*dark_aura, 30), (0, 0, w, h))
        surf.blit(aura_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # Thin gaunt face
        face_w = int(w * 0.46)
        face_h = int(h * 0.72)
        face_top = int(h * 0.22)
        face_rect = pygame.Rect(cx - face_w // 2, face_top, face_w, face_h)
        pygame.draw.ellipse(surf, skin, face_rect)
        # Face shading - sunken cheeks
        pygame.draw.ellipse(surf, skin_sh, pygame.Rect(face_rect.x, face_top + face_h * 2 // 3, face_w, face_h // 3))
        pygame.draw.ellipse(surf, skin, pygame.Rect(face_rect.x + 2, face_top, face_w - 4, int(face_h * 0.5)))
        # Sunken cheek shadows
        for s in [-1, 1]:
            chx = cx + s * int(w * 0.12)
            chy = int(h * 0.52)
            pygame.draw.ellipse(surf, (*skin_sh, 80), (chx - int(w * 0.05), chy, int(w * 0.08), int(h * 0.12)))
        # Bone crown
        crown_y = int(h * 0.08)
        crown_h = int(h * 0.18)
        crown_w = int(w * 0.50)
        crown_rect = pygame.Rect(cx - crown_w // 2, crown_y, crown_w, crown_h)
        pygame.draw.rect(surf, bone, crown_rect, border_radius=2)
        pygame.draw.rect(surf, bone_dk, crown_rect, 1, border_radius=2)
        # Crown spikes
        for i in range(5):
            sx = crown_rect.left + int((i + 0.5) * crown_w / 5)
            spike_h = int(h * 0.10) if i == 2 else int(h * 0.06 + (i % 2) * h * 0.03)
            pygame.draw.polygon(surf, bone, [(sx - int(w * 0.02), crown_y),
                                             (sx, crown_y - spike_h),
                                             (sx + int(w * 0.02), crown_y)])
            pygame.draw.polygon(surf, bone_dk, [(sx - int(w * 0.02), crown_y),
                                                (sx, crown_y - spike_h),
                                                (sx + int(w * 0.02), crown_y)], 1)
        # Crown skull emblem
        emb_y = crown_y + crown_h // 2
        pygame.draw.circle(surf, bone_dk, (cx, emb_y), max(2, int(b * 0.12)))
        pygame.draw.circle(surf, bone, (cx, emb_y), max(1, int(b * 0.08)))
        # Dark circles under eyes
        eye_y = int(h * 0.40)
        eye_sp = int(w * 0.10)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            # Dark circles
            pygame.draw.ellipse(surf, (*skin_sh, 100), (ex - int(w * 0.06), eye_y - int(h * 0.02),
                                                        int(w * 0.12), int(h * 0.08)))
            # Eyes
            sw = max(3, int(w * 0.07))
            sh = max(2, int(h * 0.05))
            pygame.draw.ellipse(surf, (200, 200, 190), (ex - sw, eye_y - sh, sw * 2, sh * 2))
            # Iris - glowing green
            ir = max(2, int(min(sw, sh) * 0.7))
            pygame.draw.circle(surf, eye_color, (ex, eye_y), ir)
            # Pupil
            pr = max(1, ir // 2)
            pygame.draw.circle(surf, (10, 30, 15), (ex, eye_y), pr)
            # Glow
            glow_s = pygame.Surface((sw * 4, sh * 4), pygame.SRCALPHA)
            pygame.draw.circle(glow_s, (*eye_glow, 30), (sw * 2, sh * 2), ir + 2)
            surf.blit(glow_s, (ex - sw * 2, eye_y - sh * 2), special_flags=pygame.BLEND_ADD)
            # Highlight
            pygame.draw.circle(surf, (200, 255, 210), (ex + s, eye_y - 1), max(1, pr // 2))
        # Sharp thin eyebrows
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = eye_y - max(3, int(h * 0.07))
            pygame.draw.line(surf, skin_sh, (bx - s * int(w * 0.02), by + 1), (bx + s * int(w * 0.05), by - 1), 1)
        # Pointed nose
        nose_y = int(h * 0.55)
        pygame.draw.line(surf, skin_sh, (cx, int(h * 0.46)), (cx - 1, nose_y), 1)
        pygame.draw.line(surf, skin_sh, (cx, int(h * 0.46)), (cx + 1, nose_y), 1)
        # Thin grim mouth
        mouth_y = int(h * 0.66)
        pygame.draw.line(surf, (130, 100, 120), (cx - int(w * 0.06), mouth_y), (cx + int(w * 0.06), mouth_y), 1)
        # Corners turned down
        for s in [-1, 1]:
            pygame.draw.line(surf, (130, 100, 120), (cx + s * int(w * 0.06), mouth_y),
                             (cx + s * int(w * 0.07), mouth_y + 2), 1)
        pygame.draw.rect(surf, (*eye_glow, 150), (0, 0, w, h), 1, border_radius=2)

    # ─── 11. JOKER (조커/광대) ───
    def _portrait_joker(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        face_white = (240, 235, 230)
        face_sh = (210, 205, 200)
        hat_red = (200, 40, 40)
        hat_gold = (230, 200, 80)
        hat_dk = (160, 25, 25)
        nose_red = (220, 50, 50)
        lip_red = (200, 40, 40)
        eye_color = (60, 140, 200)
        star = (255, 220, 60)
        # Colorful background
        pygame.draw.rect(surf, (50, 20, 50, 80), (0, 0, w, h))
        # Jester hat
        # Center point of hat
        hat_y = int(h * 0.15)
        # Left horn of hat
        left_pts = [(cx - int(w * 0.35), hat_y + int(h * 0.12)),
                    (cx - int(w * 0.48), int(h * -0.05)),
                    (cx - int(w * 0.15), hat_y)]
        pygame.draw.polygon(surf, hat_red, left_pts)
        pygame.draw.polygon(surf, hat_dk, left_pts, 1)
        # Right horn of hat
        right_pts = [(cx + int(w * 0.35), hat_y + int(h * 0.12)),
                     (cx + int(w * 0.48), int(h * -0.05)),
                     (cx + int(w * 0.15), hat_y)]
        pygame.draw.polygon(surf, hat_gold, right_pts)
        pygame.draw.polygon(surf, (190, 160, 50), right_pts, 1)
        # Hat band
        pygame.draw.rect(surf, hat_gold, (cx - int(w * 0.35), hat_y, int(w * 0.70), max(2, int(h * 0.05))))
        # Bells on hat tips
        for bx, by in [(cx - int(w * 0.48), int(h * -0.05)), (cx + int(w * 0.48), int(h * -0.05))]:
            bell_r = max(2, int(b * 0.10))
            pygame.draw.circle(surf, hat_gold, (bx, by), bell_r)
            pygame.draw.circle(surf, (200, 170, 50), (bx, by), bell_r, 1)
            pygame.draw.circle(surf, (180, 150, 40), (bx, by + bell_r // 2), max(1, bell_r // 3))
        # White painted face
        face_w = int(w * 0.55)
        face_h = int(h * 0.65)
        face_top = int(h * 0.22)
        face_rect = pygame.Rect(cx - face_w // 2, face_top, face_w, face_h)
        pygame.draw.ellipse(surf, face_white, face_rect)
        pygame.draw.ellipse(surf, face_sh, pygame.Rect(face_rect.x, face_top + face_h * 2 // 3, face_w, face_h // 3))
        pygame.draw.ellipse(surf, face_white, pygame.Rect(face_rect.x + 1, face_top, face_w - 2, int(face_h * 0.5)))
        # Eyes - one normal, one with star
        eye_y = int(h * 0.42)
        eye_sp = int(w * 0.11)
        # Left eye - normal with makeup
        ex_l = cx - eye_sp
        sw = max(3, int(w * 0.07))
        sh = max(2, int(h * 0.05))
        # Blue diamond makeup around left eye
        pygame.draw.polygon(surf, (80, 120, 200, 80), [(ex_l, eye_y - sh - 2), (ex_l + sw + 1, eye_y),
                                                        (ex_l, eye_y + sh + 2), (ex_l - sw - 1, eye_y)])
        pygame.draw.ellipse(surf, (255, 255, 255), (ex_l - sw, eye_y - sh, sw * 2, sh * 2))
        ir = max(2, int(min(sw, sh) * 0.7))
        pygame.draw.circle(surf, eye_color, (ex_l, eye_y), ir)
        pr = max(1, ir // 2)
        pygame.draw.circle(surf, (20, 20, 30), (ex_l, eye_y), pr)
        pygame.draw.circle(surf, (255, 255, 255), (ex_l - 1, eye_y - 1), max(1, pr // 2))
        # Right eye - star design
        ex_r = cx + eye_sp
        # Star shape around eye
        star_r = max(3, int(b * 0.3))
        for p in range(5):
            angle = p * 2 * 3.14159 / 5 - 3.14159 / 2
            sx1 = ex_r + int(_cos(angle) * star_r)
            sy1 = eye_y + int(_sin(angle) * star_r)
            angle2 = (p + 0.5) * 2 * 3.14159 / 5 - 3.14159 / 2
            sx2 = ex_r + int(_cos(angle2) * star_r * 0.4)
            sy2 = eye_y + int(_sin(angle2) * star_r * 0.4)
            pygame.draw.line(surf, star, (sx1, sy1), (sx2, sy2), 1)
        pygame.draw.ellipse(surf, (255, 255, 255), (ex_r - sw, eye_y - sh, sw * 2, sh * 2))
        pygame.draw.circle(surf, eye_color, (ex_r, eye_y), ir)
        pygame.draw.circle(surf, (20, 20, 30), (ex_r, eye_y), pr)
        pygame.draw.circle(surf, (255, 255, 255), (ex_r - 1, eye_y - 1), max(1, pr // 2))
        # Arched eyebrows
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = eye_y - max(3, int(h * 0.08))
            pygame.draw.arc(surf, (60, 40, 80),
                            (bx - int(w * 0.05), by - int(h * 0.03), int(w * 0.10), int(h * 0.06)),
                            0.3, 2.8, max(1, int(b * 0.06)))
        # Red nose
        nose_y = int(h * 0.53)
        nose_r = max(2, int(b * 0.14))
        pygame.draw.circle(surf, nose_red, (cx, nose_y), nose_r)
        pygame.draw.circle(surf, (240, 80, 80), (cx - 1, nose_y - 1), max(1, nose_r // 3))
        # Wide grinning mouth
        mouth_y = int(h * 0.65)
        mouth_w = int(w * 0.20)
        # Red lips - wide grin
        pygame.draw.arc(surf, lip_red, (cx - mouth_w, mouth_y - int(h * 0.05), mouth_w * 2, int(h * 0.12)),
                        3.3, 6.1, max(1, int(b * 0.08)))
        # Grin corners curving up
        for s in [-1, 1]:
            pygame.draw.arc(surf, lip_red,
                            (cx + s * mouth_w - int(w * 0.03), mouth_y - int(h * 0.04), int(w * 0.06), int(h * 0.06)),
                            0.5 if s == 1 else 2.0, 2.0 if s == 1 else 3.5, 1)
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
        eye_color = (220, 180, 60)
        eye_glow = (240, 200, 80)
        shimmer = (255, 230, 150)
        # Sandy/warm background
        pygame.draw.rect(surf, (60, 40, 25, 100), (0, 0, w, h))
        # Heat shimmer effect
        shimmer_s = pygame.Surface((w, h), pygame.SRCALPHA)
        for i in range(4):
            sy = int(h * (0.2 + i * 0.2))
            sw = int(w * 0.6 + _sin(i * 1.5) * w * 0.1)
            pygame.draw.ellipse(shimmer_s, (*shimmer, 8), (cx - sw // 2, sy - int(h * 0.05), sw, int(h * 0.10)))
        surf.blit(shimmer_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # Turban/headwrap - top portion
        turban_pts = [(cx - int(w * 0.40), int(h * 0.25)),
                      (cx - int(w * 0.35), int(h * 0.02)),
                      (cx, int(h * -0.02)),
                      (cx + int(w * 0.35), int(h * 0.02)),
                      (cx + int(w * 0.40), int(h * 0.25))]
        pygame.draw.polygon(surf, wrap, turban_pts)
        # Turban folds
        for i in range(3):
            fy = int(h * 0.05 + i * h * 0.06)
            pygame.draw.line(surf, wrap_dk, (cx - int(w * 0.30), fy), (cx + int(w * 0.30), fy), 1)
        # Turban highlight
        pygame.draw.ellipse(surf, (*wrap_lt, 50), (cx - int(w * 0.15), int(h * 0.04), int(w * 0.30), int(h * 0.12)))
        # Visible face strip - eyes and upper nose
        face_w = int(w * 0.50)
        face_h = int(h * 0.28)
        face_top = int(h * 0.25)
        face_rect = pygame.Rect(cx - face_w // 2, face_top, face_w, face_h)
        pygame.draw.ellipse(surf, skin, face_rect)
        # Skin shading
        pygame.draw.ellipse(surf, skin_sh, pygame.Rect(face_rect.x + 2, face_top + face_h // 2, face_w - 4, face_h // 2))
        pygame.draw.ellipse(surf, skin, pygame.Rect(face_rect.x + 2, face_top, face_w - 4, int(face_h * 0.6)))
        # Mysterious glowing amber eyes
        eye_y = int(h * 0.36)
        eye_sp = int(w * 0.11)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            # Eye glow
            glow_s = pygame.Surface((w, h), pygame.SRCALPHA)
            pygame.draw.circle(glow_s, (*eye_glow, 20), (ex, eye_y), max(4, int(b * 0.4)))
            surf.blit(glow_s, (0, 0), special_flags=pygame.BLEND_ADD)
            # Sclera
            sw = max(3, int(w * 0.07))
            sh = max(2, int(h * 0.05))
            pygame.draw.ellipse(surf, (250, 245, 230), (ex - sw, eye_y - sh, sw * 2, sh * 2))
            # Iris
            ir = max(2, int(min(sw, sh) * 0.7))
            pygame.draw.circle(surf, eye_color, (ex, eye_y), ir)
            # Pupil
            pr = max(1, ir // 2)
            pygame.draw.circle(surf, (40, 25, 10), (ex, eye_y), pr)
            # Highlight
            pygame.draw.circle(surf, (255, 240, 200), (ex + s, eye_y - 1), max(1, pr // 2))
        # Intense eyebrows
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = eye_y - max(3, int(h * 0.07))
            pygame.draw.line(surf, skin_sh, (bx - s * int(w * 0.04), by + 1), (bx + s * int(w * 0.04), by - 1),
                             max(1, int(b * 0.07)))
        # Face wrap covering lower face
        wrap_top = int(h * 0.48)
        wrap_pts = [(cx - int(w * 0.42), wrap_top),
                    (cx + int(w * 0.42), wrap_top),
                    (cx + int(w * 0.38), int(h * 0.95)),
                    (cx, int(h * 0.98)),
                    (cx - int(w * 0.38), int(h * 0.95))]
        pygame.draw.polygon(surf, wrap, wrap_pts)
        pygame.draw.polygon(surf, wrap_dk, wrap_pts, 1)
        # Wrap fold details
        for i in range(4):
            fy = wrap_top + int(h * 0.05 + i * h * 0.10)
            fold_indent = int(w * 0.02 * (i % 2))
            pygame.draw.line(surf, wrap_dk, (cx - int(w * 0.32) + fold_indent, fy),
                             (cx + int(w * 0.32) - fold_indent, fy), 1)
        # Wrap highlight
        pygame.draw.ellipse(surf, (*wrap_lt, 30), (cx - int(w * 0.15), wrap_top + int(h * 0.05),
                                                    int(w * 0.30), int(h * 0.15)))
        # Nose bridge visible
        pygame.draw.line(surf, skin_sh, (cx, int(h * 0.40)), (cx, int(h * 0.48)), 1)
        pygame.draw.rect(surf, (*eye_glow, 150), (0, 0, w, h), 1, border_radius=2)

    # ─── 13. RA (라/태양신) ───
    def _portrait_ra(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        gold = (220, 190, 60)
        gold_dk = (180, 150, 30)
        gold_lt = (245, 225, 100)
        metal = (200, 180, 100)
        metal_dk = (160, 140, 70)
        eye_color = (255, 160, 30)
        eye_glow = (255, 200, 60)
        blue = (40, 80, 180)
        blue_lt = (70, 120, 220)
        # Radiant background
        glow_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_s, (200, 150, 30, 25), (cx - int(w * 0.45), int(h * 0.05), int(w * 0.9), int(h * 0.8)))
        surf.blit(glow_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # Egyptian hawk helmet (Horus style)
        # Main helmet shape
        helm_pts = [(cx - int(w * 0.48), int(h * 0.55)),
                    (cx - int(w * 0.45), int(h * 0.08)),
                    (cx - int(w * 0.25), int(h * 0.0)),
                    (cx, int(h * -0.03)),
                    (cx + int(w * 0.25), int(h * 0.0)),
                    (cx + int(w * 0.45), int(h * 0.08)),
                    (cx + int(w * 0.48), int(h * 0.55))]
        pygame.draw.polygon(surf, gold, helm_pts)
        pygame.draw.polygon(surf, gold_dk, helm_pts, 2)
        # Helmet stripes (blue and gold alternating)
        for i in range(4):
            sy = int(h * 0.08 + i * h * 0.10)
            stripe_w = int(w * 0.40 - i * w * 0.02)
            if i % 2 == 0:
                pygame.draw.rect(surf, blue, (cx - stripe_w, sy, stripe_w * 2, max(2, int(h * 0.04))))
            else:
                pygame.draw.rect(surf, gold_lt, (cx - stripe_w, sy, stripe_w * 2, max(2, int(h * 0.04))))
        # Helmet center cobra/uraeus
        cobra_x = cx
        cobra_y = int(h * 0.08)
        cobra_pts = [(cobra_x - int(w * 0.03), int(h * 0.10)),
                     (cobra_x, int(h * -0.05)),
                     (cobra_x + int(w * 0.03), int(h * 0.10))]
        pygame.draw.polygon(surf, gold_lt, cobra_pts)
        pygame.draw.circle(surf, (200, 40, 40), (cobra_x, int(h * 0.02)), max(1, int(b * 0.06)))
        # Golden face plate/mask
        face_w = int(w * 0.42)
        face_h = int(h * 0.55)
        face_top = int(h * 0.32)
        face_rect = pygame.Rect(cx - face_w // 2, face_top, face_w, face_h)
        pygame.draw.ellipse(surf, metal, face_rect)
        pygame.draw.ellipse(surf, metal_dk, pygame.Rect(face_rect.x + 2, face_top + face_h // 2, face_w - 4, face_h // 2))
        pygame.draw.ellipse(surf, metal, pygame.Rect(face_rect.x + 2, face_top, face_w - 4, int(face_h * 0.55)))
        # Eye of Horus markings
        eye_y = int(h * 0.45)
        eye_sp = int(w * 0.10)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            # Horus eye outline
            ew = max(4, int(w * 0.09))
            eh = max(3, int(h * 0.06))
            # Upper lid line (thick, Egyptian style)
            pygame.draw.line(surf, (10, 10, 10), (ex - ew, eye_y), (ex + ew, eye_y - 1), max(1, int(b * 0.08)))
            # Eye teardrop line going down
            pygame.draw.line(surf, (10, 10, 10), (ex + s * int(ew * 0.3), eye_y + eh),
                             (ex + s * int(ew * 0.2), eye_y + eh + int(h * 0.08)), max(1, int(b * 0.05)))
            # Winged outer corner
            pygame.draw.line(surf, (10, 10, 10), (ex + s * ew, eye_y),
                             (ex + s * int(ew * 1.3), eye_y - int(h * 0.03)), max(1, int(b * 0.05)))
            # Eye shape
            pygame.draw.ellipse(surf, (20, 15, 10), (ex - ew + 1, eye_y - eh + 1, (ew - 1) * 2, (eh - 1) * 2))
            # Glowing iris
            ir = max(2, int(min(ew, eh) * 0.6))
            pygame.draw.circle(surf, eye_color, (ex, eye_y), ir)
            # Glow
            glow_s2 = pygame.Surface((ir * 6, ir * 6), pygame.SRCALPHA)
            pygame.draw.circle(glow_s2, (*eye_glow, 30), (ir * 3, ir * 3), ir * 2)
            surf.blit(glow_s2, (ex - ir * 3, eye_y - ir * 3), special_flags=pygame.BLEND_ADD)
            # Pupil
            pr = max(1, ir // 2)
            pygame.draw.circle(surf, (60, 20, 5), (ex, eye_y), pr)
            pygame.draw.circle(surf, (255, 230, 150), (ex + s, eye_y - 1), max(1, pr // 2))
        # Nose ridge on mask
        pygame.draw.line(surf, metal_dk, (cx, int(h * 0.48)), (cx, int(h * 0.62)), max(1, int(b * 0.05)))
        # Chin of mask
        chin_y = int(h * 0.78)
        pygame.draw.polygon(surf, gold, [(cx - int(w * 0.10), chin_y),
                                         (cx, int(h * 0.92)),
                                         (cx + int(w * 0.10), chin_y)])
        pygame.draw.polygon(surf, gold_dk, [(cx - int(w * 0.10), chin_y),
                                            (cx, int(h * 0.92)),
                                            (cx + int(w * 0.10), chin_y)], 1)
        pygame.draw.rect(surf, (*gold, 200), (0, 0, w, h), 1, border_radius=2)

    # ─── 14. ANDROID (안드로이드/로봇) ───
    def _portrait_android(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        metal = (160, 165, 175)
        metal_dk = (120, 125, 135)
        metal_lt = (195, 200, 210)
        panel = (140, 145, 155)
        led_blue = (50, 150, 255)
        led_glow = (80, 180, 255)
        circuit = (60, 180, 220)
        # Tech background
        pygame.draw.rect(surf, (15, 20, 30, 120), (0, 0, w, h))
        # Grid lines in background
        for i in range(0, w, max(3, w // 8)):
            pygame.draw.line(surf, (30, 40, 60, 30), (i, 0), (i, h), 1)
        for i in range(0, h, max(3, h // 6)):
            pygame.draw.line(surf, (30, 40, 60, 30), (0, i), (w, i), 1)
        # Head shape - angular/mechanical
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
        pygame.draw.polygon(surf, metal, head_pts)
        pygame.draw.polygon(surf, metal_dk, head_pts, 1)
        # Panel lines on face
        # Center vertical line
        pygame.draw.line(surf, metal_dk, (cx, head_top), (cx, head_top + head_h), 1)
        # Horizontal panel line
        panel_y = head_top + int(head_h * 0.55)
        pygame.draw.line(surf, metal_dk, (cx - head_w // 2, panel_y), (cx + head_w // 2, panel_y), 1)
        # Highlight on forehead
        pygame.draw.ellipse(surf, (*metal_lt, 40), (cx - int(w * 0.12), head_top + int(head_h * 0.05),
                                                     int(w * 0.24), int(head_h * 0.20)))
        # Visor for eyes
        visor_y = head_top + int(head_h * 0.30)
        visor_h = max(4, int(h * 0.12))
        visor_w = int(w * 0.50)
        visor_rect = pygame.Rect(cx - visor_w // 2, visor_y, visor_w, visor_h)
        pygame.draw.rect(surf, (20, 30, 50), visor_rect, border_radius=2)
        pygame.draw.rect(surf, metal_dk, visor_rect, 1, border_radius=2)
        # LED blue eyes
        eye_sp = int(w * 0.12)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            ey = visor_y + visor_h // 2
            # Eye glow
            glow_s = pygame.Surface((w, h), pygame.SRCALPHA)
            pygame.draw.circle(glow_s, (*led_blue, 30), (ex, ey), max(4, int(b * 0.4)))
            surf.blit(glow_s, (0, 0), special_flags=pygame.BLEND_ADD)
            # LED eye
            led_r = max(2, visor_h // 3)
            pygame.draw.circle(surf, led_blue, (ex, ey), led_r)
            pygame.draw.circle(surf, led_glow, (ex, ey), max(1, led_r * 2 // 3))
            pygame.draw.circle(surf, (200, 230, 255), (ex + s, ey - 1), max(1, led_r // 3))
        # Circuit patterns on cheek plates
        for s in [-1, 1]:
            cpx = cx + s * int(w * 0.22)
            cpy = head_top + int(head_h * 0.55)
            # Horizontal circuit line
            pygame.draw.line(surf, circuit, (cpx, cpy), (cpx + s * int(w * 0.08), cpy), 1)
            # Vertical circuit line
            pygame.draw.line(surf, circuit, (cpx + s * int(w * 0.04), cpy), (cpx + s * int(w * 0.04), cpy + int(h * 0.10)), 1)
            # Circuit node dots
            pygame.draw.circle(surf, circuit, (cpx + s * int(w * 0.04), cpy), max(1, int(b * 0.04)))
            pygame.draw.circle(surf, circuit, (cpx + s * int(w * 0.08), cpy), max(1, int(b * 0.04)))
            pygame.draw.circle(surf, circuit, (cpx + s * int(w * 0.04), cpy + int(h * 0.10)), max(1, int(b * 0.04)))
        # Nose sensor
        nose_y = head_top + int(head_h * 0.58)
        pygame.draw.rect(surf, panel, (cx - max(1, int(w * 0.02)), nose_y, max(2, int(w * 0.04)), max(2, int(h * 0.06))))
        # Mouth speaker grille
        mouth_y = head_top + int(head_h * 0.72)
        grille_w = int(w * 0.16)
        grille_h = max(3, int(h * 0.06))
        pygame.draw.rect(surf, metal_dk, (cx - grille_w // 2, mouth_y, grille_w, grille_h), border_radius=1)
        for i in range(4):
            lx = cx - grille_w // 2 + int((i + 0.5) * grille_w / 4)
            pygame.draw.line(surf, (80, 85, 95), (lx, mouth_y + 1), (lx, mouth_y + grille_h - 1), 1)
        # Antenna/sensor on top
        ant_x = cx + int(w * 0.15)
        ant_y = head_top - int(h * 0.02)
        pygame.draw.line(surf, metal, (ant_x, head_top), (ant_x, ant_y - int(h * 0.08)), max(1, int(b * 0.05)))
        pygame.draw.circle(surf, led_blue, (ant_x, ant_y - int(h * 0.08)), max(1, int(b * 0.06)))
        # LED glow on antenna
        glow_s = pygame.Surface((int(b * 0.5) * 2, int(b * 0.5) * 2), pygame.SRCALPHA)
        ar = max(2, int(b * 0.25))
        pygame.draw.circle(glow_s, (*led_glow, 30), (ar, ar), ar)
        surf.blit(glow_s, (ant_x - ar, ant_y - int(h * 0.08) - ar), special_flags=pygame.BLEND_ADD)
        pygame.draw.rect(surf, (*led_blue, 180), (0, 0, w, h), 1, border_radius=2)

    # ─── 15. MONKEYKING (원숭이왕/손오공) ───
    def _portrait_monkeyking(self, surf, w, h, color):
        cx = w // 2
        b = max(4, min(w, h) // 5)
        fur = (160, 110, 60)
        fur_dk = (120, 80, 40)
        fur_lt = (195, 150, 90)
        skin = (230, 190, 145)
        skin_sh = (200, 160, 120)
        skin_hi = (245, 220, 185)
        crown = (230, 200, 60)
        crown_dk = (190, 160, 30)
        crown_lt = (255, 230, 100)
        eye_color = (220, 190, 40)
        eye_hi = (255, 240, 120)
        # Warm golden background
        pygame.draw.rect(surf, (50, 35, 15, 80), (0, 0, w, h))
        glow_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_s, (200, 150, 40, 15), (cx - int(w * 0.4), int(h * 0.1), int(w * 0.8), int(h * 0.7)))
        surf.blit(glow_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # Fur mass (top and sides of head)
        fur_rect = pygame.Rect(cx - int(w * 0.46), int(h * 0.05), int(w * 0.92), int(h * 0.65))
        pygame.draw.ellipse(surf, fur, fur_rect)
        # Fur texture - tufts
        for xf, yf in [(-0.32, 0.10), (-0.18, 0.06), (-0.05, 0.04), (0.08, 0.05), (0.22, 0.08), (0.35, 0.12)]:
            tx = cx + int(xf * w)
            ty = int(h * (0.08 + yf))
            pygame.draw.ellipse(surf, fur_lt, (tx - int(w * 0.06), ty, int(w * 0.10), int(h * 0.12)))
        # Fur dark shading at sides
        for s in [-1, 1]:
            pygame.draw.ellipse(surf, fur_dk, (cx + s * int(w * 0.30) - int(w * 0.08), int(h * 0.15),
                                               int(w * 0.14), int(h * 0.35)))
        # Monkey ears on sides
        for s in [-1, 1]:
            ear_x = cx + s * int(w * 0.38)
            ear_y = int(h * 0.28)
            ear_r = max(3, int(b * 0.25))
            pygame.draw.circle(surf, fur, (ear_x, ear_y), ear_r + 1)
            pygame.draw.circle(surf, skin, (ear_x, ear_y), ear_r)
            pygame.draw.circle(surf, skin_sh, (ear_x + s, ear_y + 1), max(1, ear_r * 2 // 3))
        # Monkey face (lighter skin area)
        face_w = int(w * 0.48)
        face_h = int(h * 0.55)
        face_top = int(h * 0.28)
        face_rect = pygame.Rect(cx - face_w // 2, face_top, face_w, face_h)
        pygame.draw.ellipse(surf, skin, face_rect)
        # Face shading
        pygame.draw.ellipse(surf, skin_sh, pygame.Rect(face_rect.x, face_top + face_h * 2 // 3, face_w, face_h // 3))
        pygame.draw.ellipse(surf, skin, pygame.Rect(face_rect.x + 2, face_top, face_w - 4, int(face_h * 0.5)))
        # Cheek highlight
        for s in [-1, 1]:
            pygame.draw.ellipse(surf, (*skin_hi, 40), (cx + s * int(w * 0.06) - int(w * 0.06), face_top + int(face_h * 0.3),
                                                        int(w * 0.10), int(face_h * 0.15)))
        # Golden crown/band on forehead
        band_y = int(h * 0.18)
        band_h = max(3, int(h * 0.08))
        band_w = int(w * 0.52)
        band_rect = pygame.Rect(cx - band_w // 2, band_y, band_w, band_h)
        pygame.draw.rect(surf, crown, band_rect, border_radius=2)
        pygame.draw.rect(surf, crown_dk, band_rect, 1, border_radius=2)
        # Crown center gem
        pygame.draw.circle(surf, (200, 50, 50), (cx, band_y + band_h // 2), max(1, int(b * 0.08)))
        pygame.draw.circle(surf, (240, 100, 100), (cx - 1, band_y + band_h // 2 - 1), max(1, int(b * 0.04)))
        # Crown edge details
        for i in range(3):
            dx = int((i - 1) * band_w * 0.3)
            pygame.draw.circle(surf, crown_lt, (cx + dx, band_y + band_h // 2), max(1, int(b * 0.04)))
        # Bright golden eyes
        eye_y = int(h * 0.42)
        eye_sp = int(w * 0.10)
        for s in [-1, 1]:
            ex = cx + s * eye_sp
            sw = max(3, int(w * 0.07))
            sh = max(2, int(h * 0.06))
            pygame.draw.ellipse(surf, (255, 255, 240), (ex - sw, eye_y - sh, sw * 2, sh * 2))
            ir = max(2, int(min(sw, sh) * 0.7))
            pygame.draw.circle(surf, eye_color, (ex, eye_y), ir)
            pr = max(1, ir // 2)
            pygame.draw.circle(surf, (50, 30, 10), (ex, eye_y), pr)
            pygame.draw.circle(surf, eye_hi, (ex + s, eye_y - 1), max(1, pr // 2))
        # Mischievous arched eyebrows
        for s in [-1, 1]:
            bx = cx + s * eye_sp
            by = eye_y - max(3, int(h * 0.07))
            pygame.draw.arc(surf, fur_dk, (bx - int(w * 0.05), by - int(h * 0.03), int(w * 0.10), int(h * 0.05)),
                            0.3, 2.8, max(1, int(b * 0.07)))
        # Flat monkey nose
        nose_y = int(h * 0.53)
        nose_w = max(3, int(w * 0.06))
        nose_h = max(2, int(h * 0.04))
        pygame.draw.ellipse(surf, skin_sh, (cx - nose_w, nose_y, nose_w * 2, nose_h * 2))
        # Nostrils
        for s in [-1, 1]:
            pygame.draw.circle(surf, (170, 130, 100), (cx + s * max(1, nose_w // 2), nose_y + nose_h), max(1, int(b * 0.04)))
        # Mischievous wide grin
        mouth_y = int(h * 0.65)
        mouth_w = int(w * 0.14)
        pygame.draw.arc(surf, (170, 120, 80), (cx - mouth_w, mouth_y - int(h * 0.02), mouth_w * 2, int(h * 0.08)),
                        3.3, 6.1, max(1, int(b * 0.07)))
        # Teeth showing in grin
        teeth_y = mouth_y + int(h * 0.01)
        pygame.draw.rect(surf, (250, 245, 235), (cx - int(mouth_w * 0.5), teeth_y, int(mouth_w), max(1, int(h * 0.02))))
        # Chin tuft of fur
        pygame.draw.ellipse(surf, fur_lt, (cx - int(w * 0.06), int(h * 0.78), int(w * 0.12), int(h * 0.12)))
        pygame.draw.rect(surf, (*crown, 180), (0, 0, w, h), 1, border_radius=2)


# ─────────────────────────────────────────────
# 싱글턴
# ─────────────────────────────────────────────
_portrait_renderer_instance = None


def get_portrait_renderer() -> HeroPortraitRenderer:
    global _portrait_renderer_instance
    if _portrait_renderer_instance is None:
        _portrait_renderer_instance = HeroPortraitRenderer()
    return _portrait_renderer_instance
