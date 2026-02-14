"""
영웅 초상화 렌더러 (Hero Portrait Renderer)
투기장 쿨타임 큐 UI에서 사용하는 영웅 얼굴+어깨 초상화를 프로시저럴 드로잉으로 구현.
각 영웅의 기존 디자인(hero_paddles.py)을 참고하여 고퀄리티 버스트샷 초상화 제공.
"""

import math
import pygame

_sin = math.sin
_cos = math.cos


class HeroPortraitRenderer:
    """영웅 버스트샷 초상화를 캐시하여 제공하는 렌더러."""

    def __init__(self):
        self._cache = {}  # (hero_id, w, h) -> Surface

    def clear_cache(self):
        self._cache.clear()

    def render_portrait(self, hero_id: str, color: tuple, w: int = 32, h: int = 38) -> pygame.Surface:
        """캐시된 초상화 Surface를 반환. 없으면 새로 그린다."""
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

    # ─────────────────────────────────────────────
    # Helper
    # ─────────────────────────────────────────────
    @staticmethod
    def _clamp_color(r, g, b, a=255):
        return (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)), max(0, min(255, a)))

    @staticmethod
    def _lighten(color, amount=40):
        return tuple(min(255, c + amount) for c in color[:3])

    @staticmethod
    def _darken(color, amount=40):
        return tuple(max(0, c - amount) for c in color[:3])

    # ─────────────────────────────────────────────
    # 기본 폴백
    # ─────────────────────────────────────────────
    def _portrait_default(self, surf, w, h, color):
        """알 수 없는 영웅용 기본 초상화."""
        cx, cy = w // 2, h // 2
        b = max(3, h // 8)
        # 배경 그라데이션
        bg = self._darken(color, 80)
        pygame.draw.rect(surf, (*bg, 120), (0, 0, w, h))
        # 어깨
        pygame.draw.ellipse(surf, self._darken(color, 30),
                            (cx - int(1.8 * b), cy + int(0.5 * b), int(3.6 * b), int(2.0 * b)))
        # 머리
        head_r = int(1.0 * b)
        pygame.draw.circle(surf, (200, 180, 160), (cx, cy - int(0.3 * b)), head_r)
        # 눈
        for s in [-1, 1]:
            pygame.draw.circle(surf, (40, 40, 40), (cx + s * int(0.3 * b), cy - int(0.4 * b)), max(1, b // 4))
        # 테두리
        pygame.draw.rect(surf, color, (0, 0, w, h), 1, border_radius=3)

    # ─────────────────────────────────────────────
    # 1. 무겐 (귀검사) - 보라색 검기, 하치마키, 앞머리
    # ─────────────────────────────────────────────
    def _portrait_mugen(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        hair = (25, 18, 35)
        hair_hi = (50, 35, 70)
        skin = (240, 215, 190)
        skin_sh = (210, 180, 155)
        armor = color
        armor_lt = self._lighten(color, 50)
        armor_dk = self._darken(color, 45)
        sash = (200, 160, 60)
        eye_glow = (200, 100, 255)
        eye_core = (255, 180, 255)
        aura = (150, 80, 200)
        # 배경 오라
        aura_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_s, (*aura, 25), (cx - int(2 * b), cy - int(2.5 * b), int(4 * b), int(4 * b)))
        surf.blit(aura_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # 어깨 갑옷
        sh_w, sh_h = int(3.2 * b), int(1.5 * b)
        sh_rect = pygame.Rect(cx - sh_w // 2, cy + int(0.6 * b), sh_w, sh_h)
        pygame.draw.rect(surf, armor_dk, sh_rect.move(1, 1), border_radius=int(0.3 * b))
        pygame.draw.rect(surf, armor, sh_rect, border_radius=int(0.3 * b))
        pygame.draw.rect(surf, armor_lt, sh_rect.inflate(-int(0.4 * b), -int(0.3 * b)), border_radius=2)
        # V자 기모노 깃
        kimono = (35, 28, 55)
        pygame.draw.line(surf, kimono, (cx, sh_rect.top + 2), (cx - int(0.6 * b), sh_rect.bottom), 2)
        pygame.draw.line(surf, kimono, (cx, sh_rect.top + 2), (cx + int(0.6 * b), sh_rect.bottom), 2)
        # 소데 (어깨보호대)
        for side in [-1, 1]:
            pts = [
                (cx + side * int(1.2 * b), cy + int(0.3 * b)),
                (cx + side * int(0.6 * b), cy + int(0.5 * b)),
                (cx + side * int(0.7 * b), cy + int(1.3 * b)),
                (cx + side * int(1.4 * b), cy + int(1.1 * b)),
            ]
            pygame.draw.polygon(surf, armor_dk, pts)
            pygame.draw.polygon(surf, armor_lt, pts, 1)
        # 머리
        head_w, head_h = int(1.8 * b), int(1.6 * b)
        head_rect = pygame.Rect(cx - head_w // 2, cy - int(1.5 * b), head_w, head_h)
        pygame.draw.ellipse(surf, hair, head_rect)
        # 얼굴
        face_rect = head_rect.inflate(-int(0.35 * b), -int(0.25 * b))
        face_rect.move_ip(0, int(0.18 * b))
        pygame.draw.ellipse(surf, skin, face_rect)
        pygame.draw.ellipse(surf, skin_sh, face_rect.inflate(-2, -2), 1)
        # 눈 (귀기)
        ey = face_rect.centery - int(0.08 * b)
        for s in [-1, 1]:
            ex = face_rect.centerx + s * int(0.22 * b)
            pygame.draw.ellipse(surf, eye_glow,
                                (ex - int(0.1 * b), ey - int(0.07 * b), int(0.2 * b), int(0.14 * b)))
            pygame.draw.circle(surf, eye_core, (ex, ey), max(1, int(0.05 * b)))
        # 코/입
        pygame.draw.line(surf, skin_sh, (face_rect.centerx, face_rect.centery),
                         (face_rect.centerx, face_rect.centery + int(0.12 * b)), 1)
        pygame.draw.line(surf, skin_sh,
                         (face_rect.centerx - int(0.12 * b), face_rect.bottom - int(0.2 * b)),
                         (face_rect.centerx + int(0.12 * b), face_rect.bottom - int(0.2 * b)), 1)
        # 앞머리
        for i in range(5):
            hx = face_rect.centerx + (i - 2) * int(0.18 * b)
            hy_s = head_rect.top + int(0.06 * b)
            hy_e = face_rect.top + int(0.12 * b) + abs(i - 2) * int(0.04 * b)
            pygame.draw.line(surf, hair, (hx, hy_s), (hx + (i - 2) * int(0.06 * b), hy_e), 2)
            pygame.draw.line(surf, hair_hi, (hx + 1, hy_s), (hx + (i - 2) * int(0.06 * b) + 1, hy_e), 1)
        # 하치마키
        hb_rect = pygame.Rect(head_rect.left + int(0.08 * b), head_rect.top + int(0.48 * b),
                               head_rect.width - int(0.16 * b), int(0.18 * b))
        pygame.draw.rect(surf, sash, hb_rect, border_radius=1)

    # ─────────────────────────────────────────────
    # 2. 크라켄 (심해 포식자) - 오징어 돔형 머리, 발광 눈
    # ─────────────────────────────────────────────
    def _portrait_kraken(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        body = color
        body_lt = self._lighten(color, 40)
        body_dk = self._darken(color, 50)
        body_hi = self._lighten(color, 70)
        eye = (200, 255, 200)
        eye_glow = (150, 255, 200)
        eye_pupil = (20, 80, 60)
        biolum = (80, 255, 200)
        teeth = (220, 220, 200)
        # 배경 심해 오라
        aura_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_s, (100, 200, 180, 20), (0, 0, w, h))
        surf.blit(aura_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # 몸통 (촉수 어깨)
        chest_w, chest_h = int(3.0 * b), int(1.8 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2, cy + int(0.2 * b), chest_w, chest_h)
        pygame.draw.ellipse(surf, body_dk, chest_rect.inflate(2, 2))
        pygame.draw.ellipse(surf, body, chest_rect)
        pygame.draw.ellipse(surf, body_lt, chest_rect.inflate(-int(0.5 * b), -int(0.4 * b)))
        # 팔 촉수 (양쪽)
        for side in [-1, 1]:
            sx = cx + side * int(1.2 * b)
            for seg in range(4):
                sy = cy + int(0.8 * b) + seg * int(0.3 * b)
                thick = max(2, int(0.3 * b) - seg)
                pygame.draw.circle(surf, body_dk, (sx + seg * side * 2, sy), thick)
        # 머리 (오징어 돔)
        head_w, head_h = int(2.6 * b), int(2.4 * b)
        head_rect = pygame.Rect(cx - head_w // 2, cy - int(2.0 * b), head_w, head_h)
        pygame.draw.ellipse(surf, body_dk, head_rect.inflate(2, 2))
        pygame.draw.ellipse(surf, body, head_rect)
        pygame.draw.ellipse(surf, body_lt, head_rect.inflate(-int(0.4 * b), -int(0.3 * b)))
        pygame.draw.ellipse(surf, body_hi, head_rect.inflate(-int(0.9 * b), -int(0.7 * b)))
        # 주름
        for i in range(3):
            wy = head_rect.top + int((i + 1) * 0.5 * b)
            ww = head_w - int(i * 0.3 * b)
            pygame.draw.arc(surf, body_dk,
                            (head_rect.centerx - ww // 2, wy, ww, int(0.25 * b)),
                            0, math.pi, 1)
        # 발광 점
        biolum_pos = [(-0.5, -0.2), (0.5, -0.2), (-0.7, 0.2), (0.7, 0.2), (0, -0.4), (0, 0.4)]
        for bx_off, by_off in biolum_pos:
            bx = head_rect.centerx + int(bx_off * b)
            by = head_rect.centery + int(by_off * b)
            pygame.draw.circle(surf, biolum, (bx, by), max(1, int(0.08 * b)))
        # 눈 (발광 대형)
        ey = head_rect.centery + int(0.1 * b)
        for s in [-1, 1]:
            ex = head_rect.centerx + s * int(0.5 * b)
            ew, eh = int(0.6 * b), int(0.5 * b)
            pygame.draw.ellipse(surf, eye, (ex - ew // 2, ey - eh // 2, ew, eh))
            pygame.draw.ellipse(surf, eye_glow, (ex - ew // 3, ey - eh // 3, ew * 2 // 3, eh * 2 // 3))
            pygame.draw.circle(surf, eye_pupil, (ex, ey), max(1, int(0.12 * b)))
            pygame.draw.circle(surf, (255, 255, 255), (ex - 1, ey - 1), max(1, int(0.04 * b)))
        # 이빨
        for i in range(5):
            tx = head_rect.centerx + (i - 2) * int(0.2 * b)
            ty = head_rect.bottom - int(0.15 * b)
            pygame.draw.polygon(surf, teeth, [
                (tx - int(0.06 * b), ty), (tx, ty + int(0.15 * b)), (tx + int(0.06 * b), ty)])

    # ─────────────────────────────────────────────
    # 3. 키르케/크로노스 (흑마녀) - 후드, 보라 마안, 시계장식
    # ─────────────────────────────────────────────
    def _portrait_chronos(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        robe = (30, 20, 45)
        robe_lt = (70, 50, 95)
        gold = color
        gold_lt = self._lighten(color, 60)
        gold_dk = self._darken(color, 50)
        skin = (215, 200, 210)
        skin_sh = (185, 170, 180)
        eye = (200, 50, 200)
        eye_glow = (230, 80, 255)
        hair = (20, 10, 35)
        hair_lt = (45, 30, 60)
        lip = (160, 70, 120)
        glow = (180, 80, 255)
        # 배경 오라
        aura_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_s, (*glow[:3], 18), (0, 0, w, h))
        surf.blit(aura_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # 로브 어깨
        sh_w, sh_h = int(3.2 * b), int(1.6 * b)
        sh_rect = pygame.Rect(cx - sh_w // 2, cy + int(0.4 * b), sh_w, sh_h)
        pygame.draw.rect(surf, robe, sh_rect, border_radius=int(0.4 * b))
        pygame.draw.rect(surf, robe_lt, sh_rect.inflate(-int(0.3 * b), -int(0.2 * b)), border_radius=int(0.3 * b))
        # 가슴 톱니바퀴 장식
        gear_cx, gear_cy = cx, cy + int(0.9 * b)
        gear_r = int(0.35 * b)
        pygame.draw.circle(surf, gold_dk, (gear_cx, gear_cy), gear_r)
        pygame.draw.circle(surf, gold, (gear_cx, gear_cy), gear_r - 1)
        pygame.draw.circle(surf, gold_lt, (gear_cx, gear_cy), max(1, gear_r - 3))
        # 금 테두리
        pygame.draw.rect(surf, gold_dk, sh_rect, 1, border_radius=int(0.4 * b))
        # 후드
        hood_w, hood_h = int(2.4 * b), int(2.2 * b)
        hood_rect = pygame.Rect(cx - hood_w // 2, cy - int(2.0 * b), hood_w, hood_h)
        pygame.draw.ellipse(surf, robe, hood_rect.inflate(int(0.3 * b), int(0.2 * b)))
        pygame.draw.ellipse(surf, robe_lt, hood_rect)
        # 후드 뾰족 부분
        pygame.draw.polygon(surf, robe, [
            (cx - int(0.3 * b), hood_rect.top + int(0.1 * b)),
            (cx, hood_rect.top - int(0.4 * b)),
            (cx + int(0.3 * b), hood_rect.top + int(0.1 * b)),
        ])
        # 머리카락 (후드 아래로)
        for side in [-1, 1]:
            for strand in range(3):
                sx = cx + side * int((0.3 + strand * 0.15) * b)
                sy = cy - int(0.2 * b)
                pygame.draw.line(surf, hair if strand % 2 == 0 else hair_lt,
                                 (sx, sy), (sx + side * int(0.1 * b), cy + int(0.6 * b)),
                                 max(1, int(0.08 * b)))
        # 얼굴
        face_w, face_h = int(1.2 * b), int(1.1 * b)
        face_rect = pygame.Rect(cx - face_w // 2, cy - int(0.9 * b), face_w, face_h)
        pygame.draw.ellipse(surf, skin_sh, face_rect.inflate(2, 2))
        pygame.draw.ellipse(surf, skin, face_rect)
        # 눈 (마안)
        ey = face_rect.centery - int(0.05 * b)
        for s in [-1, 1]:
            ex = face_rect.centerx + s * int(0.22 * b)
            pygame.draw.ellipse(surf, eye,
                                (ex - int(0.12 * b), ey - int(0.08 * b), int(0.24 * b), int(0.16 * b)))
            pygame.draw.circle(surf, eye_glow, (ex, ey), max(1, int(0.06 * b)))
            # 속눈썹
            pygame.draw.line(surf, (20, 10, 30),
                             (ex - int(0.1 * b), ey - int(0.08 * b)),
                             (ex - int(0.14 * b), ey - int(0.14 * b)), 1)
            pygame.draw.line(surf, (20, 10, 30),
                             (ex + int(0.1 * b), ey - int(0.08 * b)),
                             (ex + int(0.14 * b), ey - int(0.14 * b)), 1)
        # 코/입
        pygame.draw.line(surf, skin_sh, (face_rect.centerx, face_rect.centery + int(0.05 * b)),
                         (face_rect.centerx, face_rect.centery + int(0.2 * b)), 1)
        lip_y = face_rect.bottom - int(0.15 * b)
        lip_w = int(0.2 * b)
        pygame.draw.ellipse(surf, lip,
                            (face_rect.centerx - lip_w, lip_y - int(0.04 * b), lip_w * 2, int(0.1 * b)))

    # ─────────────────────────────────────────────
    # 4. 오니마루 (요괴무사) - 악마 뿔, 붉은 피부, 이빨
    # ─────────────────────────────────────────────
    def _portrait_onimaru(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        skin = (230, 170, 150)
        skin_sh = (200, 140, 120)
        skin_mid = (215, 155, 135)
        armor = color
        armor_lt = self._lighten(color, 50)
        armor_dk = self._darken(color, 45)
        horn = (180, 170, 140)
        horn_dk = (140, 130, 100)
        eye = (255, 200, 50)
        eye_glow = (255, 150, 50)
        teeth = (230, 230, 210)
        hair = (30, 20, 15)
        # 배경
        aura_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_s, (200, 50, 30, 15), (0, 0, w, h))
        surf.blit(aura_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # 어깨 갑옷
        sh_w, sh_h = int(3.4 * b), int(1.5 * b)
        sh_rect = pygame.Rect(cx - sh_w // 2, cy + int(0.5 * b), sh_w, sh_h)
        pygame.draw.rect(surf, armor_dk, sh_rect.move(1, 1), border_radius=int(0.3 * b))
        pygame.draw.rect(surf, armor, sh_rect, border_radius=int(0.3 * b))
        pygame.draw.rect(surf, armor_lt, sh_rect.inflate(-int(0.4 * b), -int(0.3 * b)), border_radius=2)
        # 목 보호대
        pygame.draw.rect(surf, armor_dk,
                         (cx - int(0.6 * b), cy + int(0.2 * b), int(1.2 * b), int(0.4 * b)),
                         border_radius=2)
        # 머리
        head_w, head_h = int(2.0 * b), int(1.8 * b)
        head_rect = pygame.Rect(cx - head_w // 2, cy - int(1.5 * b), head_w, head_h)
        pygame.draw.ellipse(surf, hair, head_rect.inflate(int(0.1 * b), int(0.05 * b)))
        # 얼굴
        face_rect = head_rect.inflate(-int(0.3 * b), -int(0.2 * b))
        face_rect.move_ip(0, int(0.15 * b))
        pygame.draw.ellipse(surf, skin_sh, face_rect.inflate(2, 2))
        pygame.draw.ellipse(surf, skin, face_rect)
        pygame.draw.ellipse(surf, skin_mid, face_rect.inflate(-int(0.2 * b), -int(0.15 * b)))
        # 이마 주름
        for i in range(2):
            wy = face_rect.top + int(0.1 * b) + i * int(0.08 * b)
            pygame.draw.line(surf, skin_sh,
                             (face_rect.centerx - int(0.25 * b), wy),
                             (face_rect.centerx + int(0.25 * b), wy), 1)
        # 뿔
        for s in [-1, 1]:
            horn_base_x = head_rect.centerx + s * int(0.5 * b)
            horn_base_y = head_rect.top + int(0.1 * b)
            horn_pts = [
                (horn_base_x - s * int(0.1 * b), horn_base_y + int(0.1 * b)),
                (horn_base_x + s * int(0.2 * b), horn_base_y - int(0.7 * b)),
                (horn_base_x + s * int(0.15 * b), horn_base_y),
            ]
            pygame.draw.polygon(surf, horn, horn_pts)
            pygame.draw.polygon(surf, horn_dk, horn_pts, 1)
        # 눈 (맹렬)
        ey = face_rect.centery - int(0.1 * b)
        for s in [-1, 1]:
            ex = face_rect.centerx + s * int(0.28 * b)
            # 날카로운 눈
            eye_pts = [
                (ex - int(0.15 * b), ey),
                (ex, ey - int(0.1 * b)),
                (ex + int(0.15 * b), ey),
                (ex, ey + int(0.06 * b)),
            ]
            pygame.draw.polygon(surf, eye, eye_pts)
            pygame.draw.polygon(surf, eye_glow, eye_pts, 1)
            pygame.draw.circle(surf, (20, 10, 5), (ex, ey), max(1, int(0.04 * b)))
        # 코 (크고 넓음)
        pygame.draw.ellipse(surf, skin_sh,
                            (cx - int(0.1 * b), face_rect.centery + int(0.05 * b), int(0.2 * b), int(0.15 * b)))
        # 입 (이빨)
        mouth_y = face_rect.bottom - int(0.3 * b)
        mouth_w = int(0.5 * b)
        pygame.draw.ellipse(surf, (60, 20, 20),
                            (cx - mouth_w // 2, mouth_y, mouth_w, int(0.2 * b)))
        for i in range(4):
            tx = cx + (i - 1.5) * int(0.1 * b)
            pygame.draw.polygon(surf, teeth, [
                (int(tx) - 2, int(mouth_y)), (int(tx), int(mouth_y + int(0.1 * b))), (int(tx) + 2, int(mouth_y))])

    # ─────────────────────────────────────────────
    # 5. 연화/마리아 (인형사) - 분홍 웨이브 머리, 리본, 인형 같은 눈
    # ─────────────────────────────────────────────
    def _portrait_maria(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        hair = (60, 30, 50)
        hair_lt = (90, 50, 75)
        skin = (245, 225, 215)
        skin_sh = (220, 195, 185)
        armor = color
        armor_lt = self._lighten(color, 50)
        armor_dk = self._darken(color, 40)
        eye_purple = (160, 80, 180)
        eye_pink = (200, 120, 180)
        blush = (255, 180, 180)
        ribbon = (220, 80, 100)
        ribbon_dk = (180, 50, 70)
        # 배경
        aura_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_s, (*self._lighten(color, 30), 15), (0, 0, w, h))
        surf.blit(aura_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # 어깨 (프릴 드레스)
        sh_w, sh_h = int(3.0 * b), int(1.4 * b)
        sh_rect = pygame.Rect(cx - sh_w // 2, cy + int(0.5 * b), sh_w, sh_h)
        pygame.draw.rect(surf, armor_dk, sh_rect.move(1, 1), border_radius=int(0.4 * b))
        pygame.draw.rect(surf, armor, sh_rect, border_radius=int(0.4 * b))
        pygame.draw.rect(surf, armor_lt, sh_rect.inflate(-int(0.4 * b), -int(0.3 * b)), border_radius=3)
        # 프릴 장식
        for i in range(6):
            fx = sh_rect.left + int(i * 0.5 * b) + int(0.1 * b)
            fy = sh_rect.top + int(0.1 * b)
            pygame.draw.arc(surf, armor_lt, (fx, fy, int(0.4 * b), int(0.3 * b)), 0, math.pi, 1)
        # 머리카락 (물결, 양옆으로 흘러내림)
        for side in [-1, 1]:
            for strand in range(4):
                sx = cx + side * int((0.4 + strand * 0.12) * b)
                sy = cy - int(1.2 * b)
                ey_s = cy + int((0.5 + strand * 0.15) * b)
                col = hair if strand % 2 == 0 else hair_lt
                pygame.draw.line(surf, col, (sx, sy),
                                 (sx + side * int(0.08 * b), ey_s), max(1, int(0.1 * b)))
        # 머리 (둥근)
        head_w, head_h = int(1.8 * b), int(1.6 * b)
        head_rect = pygame.Rect(cx - head_w // 2, cy - int(1.5 * b), head_w, head_h)
        pygame.draw.ellipse(surf, hair, head_rect)
        # 얼굴
        face_rect = head_rect.inflate(-int(0.35 * b), -int(0.28 * b))
        face_rect.move_ip(0, int(0.15 * b))
        pygame.draw.ellipse(surf, skin_sh, face_rect.inflate(2, 2))
        pygame.draw.ellipse(surf, skin, face_rect)
        # 볼터치
        for s in [-1, 1]:
            bx = face_rect.centerx + s * int(0.22 * b)
            by = face_rect.centery + int(0.12 * b)
            bs = pygame.Surface((int(0.3 * b), int(0.2 * b)), pygame.SRCALPHA)
            pygame.draw.ellipse(bs, (*blush, 60), bs.get_rect())
            surf.blit(bs, (bx - int(0.15 * b), by - int(0.1 * b)))
        # 눈 (크고 반짝이는)
        ey = face_rect.centery - int(0.06 * b)
        for s in [-1, 1]:
            ex = face_rect.centerx + s * int(0.2 * b)
            ew, eh = int(0.2 * b), int(0.18 * b)
            pygame.draw.ellipse(surf, (255, 255, 255), (ex - ew, ey - eh, ew * 2, eh * 2))
            pygame.draw.circle(surf, eye_purple, (ex, ey), max(2, int(0.1 * b)))
            pygame.draw.circle(surf, eye_pink, (ex, ey), max(1, int(0.06 * b)))
            pygame.draw.circle(surf, (255, 255, 255), (ex - 1, ey - 1), max(1, int(0.04 * b)))
            # 속눈썹
            for lash in [-1, 0, 1]:
                lx = ex + lash * max(1, int(0.06 * b))
                pygame.draw.line(surf, hair, (lx, ey - eh), (lx + lash, ey - eh - max(1, int(0.06 * b))), 1)
        # 코/입
        pygame.draw.line(surf, skin_sh, (cx, face_rect.centery + int(0.03 * b)),
                         (cx, face_rect.centery + int(0.12 * b)), 1)
        pygame.draw.ellipse(surf, (220, 140, 150),
                            (cx - int(0.1 * b), face_rect.bottom - int(0.22 * b), int(0.2 * b), int(0.08 * b)))
        # 앞머리 (물결)
        for i in range(6):
            hx = face_rect.left + int(0.08 * b) + i * int(0.18 * b)
            pygame.draw.line(surf, hair, (hx, head_rect.top + int(0.15 * b)),
                             (hx + (i - 3) * int(0.03 * b), face_rect.top + int(0.2 * b)), 2)
        # 리본
        rx, ry = cx + int(0.5 * b), cy - int(1.5 * b)
        pygame.draw.polygon(surf, ribbon, [
            (rx, ry), (rx + int(0.3 * b), ry - int(0.2 * b)),
            (rx + int(0.2 * b), ry + int(0.1 * b))])
        pygame.draw.polygon(surf, ribbon_dk, [
            (rx, ry), (rx + int(0.25 * b), ry + int(0.25 * b)),
            (rx + int(0.15 * b), ry + int(0.05 * b))])
        pygame.draw.circle(surf, ribbon, (rx, ry), max(2, int(0.08 * b)))

    # ─────────────────────────────────────────────
    # 6. 이그니스 (드래곤 나이트) - 용 투구, 불꽃 오렌지
    # ─────────────────────────────────────────────
    def _portrait_ignis(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        armor = color
        armor_lt = self._lighten(color, 50)
        armor_dk = self._darken(color, 45)
        skin = (235, 210, 180)
        skin_sh = (205, 180, 150)
        eye = (255, 160, 40)
        eye_glow = (255, 200, 80)
        horn = (140, 100, 30)
        horn_lt = (180, 140, 60)
        fire = (255, 120, 30)
        fire_hi = (255, 200, 80)
        # 배경 화염
        aura_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_s, (255, 100, 20, 15), (0, 0, w, h))
        surf.blit(aura_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # 어깨 갑옷 (용 비늘)
        sh_w, sh_h = int(3.4 * b), int(1.6 * b)
        sh_rect = pygame.Rect(cx - sh_w // 2, cy + int(0.4 * b), sh_w, sh_h)
        pygame.draw.rect(surf, armor_dk, sh_rect.move(1, 1), border_radius=int(0.3 * b))
        pygame.draw.rect(surf, armor, sh_rect, border_radius=int(0.3 * b))
        # 비늘 패턴
        for row in range(2):
            for col in range(4):
                sx = sh_rect.left + int((col + 0.5) * 0.7 * b)
                sy = sh_rect.top + int(0.3 * b) + row * int(0.4 * b)
                pygame.draw.ellipse(surf, armor_lt, (sx, sy, int(0.3 * b), int(0.2 * b)))
        # 투구
        head_w, head_h = int(2.2 * b), int(2.0 * b)
        head_rect = pygame.Rect(cx - head_w // 2, cy - int(1.7 * b), head_w, head_h)
        pygame.draw.ellipse(surf, armor_dk, head_rect.inflate(2, 2))
        pygame.draw.ellipse(surf, armor, head_rect)
        pygame.draw.ellipse(surf, armor_lt, head_rect.inflate(-int(0.3 * b), -int(0.2 * b)))
        # 투구 뿔 (드래곤)
        for s in [-1, 1]:
            hx = head_rect.centerx + s * int(0.5 * b)
            hy = head_rect.top + int(0.2 * b)
            pts = [
                (hx - s * int(0.05 * b), hy + int(0.15 * b)),
                (hx + s * int(0.3 * b), hy - int(0.6 * b)),
                (hx + s * int(0.15 * b), hy),
            ]
            pygame.draw.polygon(surf, horn, pts)
            pygame.draw.polygon(surf, horn_lt, pts, 1)
        # 바이저 슬릿 (눈)
        visor_y = head_rect.centery + int(0.05 * b)
        visor_w = int(1.4 * b)
        visor_h = int(0.3 * b)
        pygame.draw.rect(surf, (20, 10, 5),
                         (cx - visor_w // 2, visor_y - visor_h // 2, visor_w, visor_h),
                         border_radius=2)
        # 눈 (투구 안에서 빛남)
        for s in [-1, 1]:
            ex = cx + s * int(0.3 * b)
            pygame.draw.ellipse(surf, eye,
                                (ex - int(0.12 * b), visor_y - int(0.06 * b), int(0.24 * b), int(0.12 * b)))
            pygame.draw.ellipse(surf, eye_glow,
                                (ex - int(0.06 * b), visor_y - int(0.03 * b), int(0.12 * b), int(0.06 * b)))
        # 투구 중앙 문양
        pygame.draw.line(surf, fire, (cx, head_rect.top + int(0.3 * b)),
                         (cx, head_rect.centery - int(0.1 * b)), max(1, int(0.08 * b)))
        pygame.draw.circle(surf, fire_hi, (cx, head_rect.top + int(0.5 * b)), max(2, int(0.1 * b)))

    # ─────────────────────────────────────────────
    # 7. 마리/기어 (스팀펑크 메카닉) - 고글, 톱니, 구리색
    # ─────────────────────────────────────────────
    def _portrait_gear(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        skin = (240, 218, 195)
        skin_sh = (210, 188, 165)
        hair = (150, 80, 40)
        hair_lt = (180, 110, 60)
        armor = color
        armor_lt = self._lighten(color, 50)
        armor_dk = self._darken(color, 40)
        goggle_rim = (80, 60, 40)
        goggle_lens = (150, 220, 255)
        goggle_lens_dk = (100, 170, 220)
        lip = (190, 130, 120)
        gear_col = (160, 140, 100)
        # 어깨 (가죽 작업복)
        sh_w, sh_h = int(3.0 * b), int(1.4 * b)
        sh_rect = pygame.Rect(cx - sh_w // 2, cy + int(0.5 * b), sh_w, sh_h)
        pygame.draw.rect(surf, armor_dk, sh_rect.move(1, 1), border_radius=int(0.3 * b))
        pygame.draw.rect(surf, armor, sh_rect, border_radius=int(0.3 * b))
        # 톱니바퀴 장식
        for s in [-1, 1]:
            gx = cx + s * int(0.8 * b)
            gy = cy + int(1.0 * b)
            pygame.draw.circle(surf, gear_col, (gx, gy), max(2, int(0.2 * b)))
            pygame.draw.circle(surf, armor_dk, (gx, gy), max(1, int(0.12 * b)))
        # 머리카락 (풍성한 웨이브)
        for side in [-1, 1]:
            for s_i in range(3):
                sx = cx + side * int((0.4 + s_i * 0.1) * b)
                sy = cy - int(1.0 * b)
                pygame.draw.line(surf, hair if s_i % 2 == 0 else hair_lt,
                                 (sx, sy), (sx + side * int(0.1 * b), cy + int(0.4 * b)),
                                 max(1, int(0.1 * b)))
        # 머리
        head_w, head_h = int(1.8 * b), int(1.6 * b)
        head_rect = pygame.Rect(cx - head_w // 2, cy - int(1.4 * b), head_w, head_h)
        pygame.draw.ellipse(surf, hair, head_rect.inflate(int(0.15 * b), int(0.1 * b)))
        # 얼굴
        face_rect = head_rect.inflate(-int(0.35 * b), -int(0.28 * b))
        face_rect.move_ip(0, int(0.15 * b))
        pygame.draw.ellipse(surf, skin_sh, face_rect.inflate(2, 2))
        pygame.draw.ellipse(surf, skin, face_rect)
        # 고글
        ey = face_rect.centery - int(0.08 * b)
        for s in [-1, 1]:
            gx = face_rect.centerx + s * int(0.25 * b)
            gr = max(3, int(0.18 * b))
            pygame.draw.circle(surf, goggle_rim, (gx, ey), gr + 1)
            pygame.draw.circle(surf, goggle_lens, (gx, ey), gr)
            pygame.draw.circle(surf, goggle_lens_dk, (gx, ey), gr - 1)
            pygame.draw.circle(surf, (255, 255, 255), (gx - 1, ey - 1), max(1, gr // 3))
        # 고글 브릿지
        pygame.draw.line(surf, goggle_rim,
                         (cx - int(0.07 * b), ey), (cx + int(0.07 * b), ey), max(2, int(0.06 * b)))
        # 코/입
        pygame.draw.line(surf, skin_sh, (cx, face_rect.centery + int(0.1 * b)),
                         (cx, face_rect.centery + int(0.2 * b)), 1)
        lip_y = face_rect.bottom - int(0.18 * b)
        pygame.draw.ellipse(surf, lip,
                            (cx - int(0.12 * b), lip_y, int(0.24 * b), int(0.08 * b)))
        # 앞머리
        for i in range(4):
            hx = face_rect.left + int(0.15 * b) + i * int(0.22 * b)
            pygame.draw.line(surf, hair, (hx, head_rect.top + int(0.2 * b)),
                             (hx + (i - 2) * 2, face_rect.top + int(0.15 * b)), 2)
        # 고글 밴드
        pygame.draw.line(surf, goggle_rim,
                         (head_rect.left + int(0.15 * b), ey),
                         (head_rect.right - int(0.15 * b), ey), max(1, int(0.06 * b)))

    # ─────────────────────────────────────────────
    # 8. 쿠로카게 (그림자 닌자) - 닌자 마스크, 날카로운 눈
    # ─────────────────────────────────────────────
    def _portrait_kurokage(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        cloth = (35, 30, 45)
        cloth_lt = (55, 48, 65)
        cloth_dk = (20, 15, 28)
        metal = (130, 125, 140)
        metal_lt = (180, 175, 190)
        metal_dk = (80, 75, 90)
        eye = (180, 40, 40)
        eye_bright = (220, 80, 60)
        eye_glow = (255, 80, 60)
        shadow = (15, 10, 20)
        # 어깨 (닌자 의상)
        sh_w, sh_h = int(3.0 * b), int(1.3 * b)
        sh_rect = pygame.Rect(cx - sh_w // 2, cy + int(0.5 * b), sh_w, sh_h)
        pygame.draw.rect(surf, cloth_dk, sh_rect, border_radius=int(0.3 * b))
        pygame.draw.rect(surf, cloth, sh_rect.inflate(-2, -2), border_radius=int(0.3 * b))
        # 교차 띠 (가슴)
        pygame.draw.line(surf, cloth_lt, (sh_rect.left + int(0.3 * b), sh_rect.top),
                         (sh_rect.right - int(0.3 * b), sh_rect.bottom), 2)
        pygame.draw.line(surf, cloth_lt, (sh_rect.right - int(0.3 * b), sh_rect.top),
                         (sh_rect.left + int(0.3 * b), sh_rect.bottom), 2)
        # 머리 (두건)
        head_w, head_h = int(1.9 * b), int(1.7 * b)
        head_rect = pygame.Rect(cx - head_w // 2, cy - int(1.4 * b), head_w, head_h)
        pygame.draw.ellipse(surf, cloth_dk, head_rect.inflate(2, 2))
        pygame.draw.ellipse(surf, cloth, head_rect)
        pygame.draw.ellipse(surf, cloth_lt, head_rect.inflate(-int(0.2 * b), -int(0.15 * b)))
        # 두건 주름
        for i in range(3):
            fy = head_rect.centery - int(0.15 * b) + i * int(0.12 * b)
            pygame.draw.line(surf, cloth_dk,
                             (head_rect.left + int(0.2 * b), fy),
                             (head_rect.right - int(0.2 * b), fy + int(0.05 * b)), 1)
        # 이마 보호대
        hb_y = head_rect.centery - int(0.25 * b)
        hb_rect = pygame.Rect(head_rect.left + int(0.1 * b), hb_y,
                               head_rect.width - int(0.2 * b), int(0.35 * b))
        pygame.draw.rect(surf, metal_dk, hb_rect, border_radius=2)
        pygame.draw.rect(surf, metal, hb_rect.inflate(-2, -2), border_radius=2)
        pygame.draw.rect(surf, metal_lt, hb_rect.inflate(-4, -4), 1, border_radius=2)
        # 문양
        pygame.draw.circle(surf, shadow, (hb_rect.centerx, hb_rect.centery), max(2, int(0.12 * b)))
        pygame.draw.circle(surf, metal_dk, (hb_rect.centerx, hb_rect.centery), max(1, int(0.08 * b)))
        # 눈 (날카로운, 마스크 구멍에서 빛남)
        ey = head_rect.centery + int(0.08 * b)
        for s in [-1, 1]:
            ex = head_rect.centerx + s * int(0.3 * b)
            pygame.draw.ellipse(surf, shadow,
                                (ex - int(0.2 * b), ey - int(0.1 * b), int(0.4 * b), int(0.2 * b)))
            pygame.draw.ellipse(surf, eye,
                                (ex - int(0.14 * b), ey - int(0.06 * b), int(0.28 * b), int(0.12 * b)))
            pygame.draw.ellipse(surf, eye_bright,
                                (ex - int(0.08 * b), ey - int(0.03 * b), int(0.16 * b), int(0.06 * b)))
            pygame.draw.circle(surf, eye_glow, (ex + int(0.03 * b), ey - int(0.01 * b)),
                               max(1, int(0.03 * b)))
        # 마스크 (하관)
        mask_pts = [
            (head_rect.centerx - int(0.45 * b), ey + int(0.15 * b)),
            (head_rect.centerx + int(0.45 * b), ey + int(0.15 * b)),
            (head_rect.centerx + int(0.2 * b), head_rect.bottom - int(0.05 * b)),
            (head_rect.centerx - int(0.2 * b), head_rect.bottom - int(0.05 * b)),
        ]
        pygame.draw.polygon(surf, cloth, mask_pts)
        pygame.draw.polygon(surf, cloth_lt, mask_pts, 1)
        # 두건 꼬리 (뒤로 펄럭)
        for i in range(2):
            tx = head_rect.right - int(0.2 * b) + int(0.15 * b) * i
            ty = head_rect.centery + int(0.1 * b)
            pygame.draw.line(surf, cloth_dk if i == 0 else cloth,
                             (head_rect.right - int(0.1 * b), ty),
                             (tx + int(0.3 * b), ty + int(0.3 * b)), max(1, int(0.08 * b) - i))

    # ─────────────────────────────────────────────
    # 9. 벤시 (유령 여왕) - 해골 같은 창백함, 금 턱마스크, 시안 눈
    # ─────────────────────────────────────────────
    def _portrait_banshee(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        skull = (230, 225, 235)
        skull_sh = (190, 185, 200)
        hair = (30, 25, 45)
        hair_lt = (50, 42, 65)
        hair_ghost = (80, 140, 170)
        crown = (210, 180, 80)
        gold_dk = (170, 140, 50)
        eye = (80, 220, 255)
        eye_glow = (120, 255, 255)
        body_color = color
        body_lt = self._lighten(color, 40)
        body_dk = self._darken(color, 40)
        # 배경 오라
        aura_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_s, (80, 180, 220, 15), (0, 0, w, h))
        surf.blit(aura_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # 어깨 (유령 로브)
        sh_w, sh_h = int(3.0 * b), int(1.5 * b)
        sh_rect = pygame.Rect(cx - sh_w // 2, cy + int(0.4 * b), sh_w, sh_h)
        pygame.draw.rect(surf, body_dk, sh_rect, border_radius=int(0.4 * b))
        pygame.draw.rect(surf, body_color, sh_rect.inflate(-2, -2), border_radius=int(0.3 * b))
        # 머리카락 (양옆 흘러내림, 유령빛)
        for side in [-1, 1]:
            for strand in range(4):
                sx = cx + side * int((0.35 + strand * 0.1) * b)
                sy = cy - int(1.0 * b)
                ey_s = cy + int((0.6 + strand * 0.15) * b)
                col = hair if strand < 2 else hair_ghost
                pygame.draw.line(surf, col, (sx, sy),
                                 (sx + side * int(0.06 * b), ey_s), max(1, int(0.09 * b)))
        # 머리
        head_w, head_h = int(2.0 * b), int(1.8 * b)
        head_rect = pygame.Rect(cx - head_w // 2, cy - int(1.5 * b), head_w, head_h)
        pygame.draw.ellipse(surf, hair, head_rect.inflate(int(0.1 * b), int(0.05 * b)))
        # 얼굴
        face_rect = head_rect.inflate(-int(0.4 * b), -int(0.3 * b))
        face_rect.move_ip(0, int(0.18 * b))
        pygame.draw.ellipse(surf, skull_sh, face_rect.inflate(2, 2))
        pygame.draw.ellipse(surf, skull, face_rect)
        # 볼 음영 (해골)
        for s in [-1, 1]:
            pygame.draw.circle(surf, skull_sh,
                               (face_rect.centerx + s * int(0.2 * b), face_rect.centery + int(0.1 * b)),
                               max(1, int(0.1 * b)))
        # 금 턱 마스크
        chin_y = face_rect.centery + int(0.12 * b)
        chin_pts = [
            (face_rect.centerx - int(0.28 * b), chin_y),
            (face_rect.centerx + int(0.28 * b), chin_y),
            (face_rect.centerx + int(0.12 * b), chin_y + int(0.35 * b)),
            (face_rect.centerx - int(0.12 * b), chin_y + int(0.35 * b)),
        ]
        pygame.draw.polygon(surf, crown, chin_pts)
        pygame.draw.polygon(surf, gold_dk, chin_pts, 1)
        # V자 문양
        v_top = chin_y + int(0.05 * b)
        v_bot = chin_y + int(0.2 * b)
        pygame.draw.line(surf, gold_dk, (face_rect.centerx, v_top),
                         (face_rect.centerx - int(0.08 * b), v_bot), 1)
        pygame.draw.line(surf, gold_dk, (face_rect.centerx, v_top),
                         (face_rect.centerx + int(0.08 * b), v_bot), 1)
        # 눈 (시안 유령 눈, 발광)
        ey = face_rect.centery - int(0.08 * b)
        for s in [-1, 1]:
            ex = face_rect.centerx + s * int(0.2 * b)
            glow_s = pygame.Surface((int(0.5 * b), int(0.4 * b)), pygame.SRCALPHA)
            pygame.draw.ellipse(glow_s, (*eye_glow, 50), glow_s.get_rect())
            surf.blit(glow_s, (ex - int(0.25 * b), ey - int(0.2 * b)), special_flags=pygame.BLEND_ADD)
            pygame.draw.ellipse(surf, eye,
                                (ex - int(0.1 * b), ey - int(0.07 * b), int(0.2 * b), int(0.14 * b)))
            pygame.draw.circle(surf, eye_glow, (ex, ey), max(1, int(0.05 * b)))
        # 왕관
        crown_y = head_rect.top - int(0.05 * b)
        crown_w = int(1.4 * b)
        crown_rect = pygame.Rect(cx - crown_w // 2, crown_y, crown_w, int(0.35 * b))
        pygame.draw.rect(surf, crown, crown_rect, border_radius=1)
        for i in range(5):
            spike_x = crown_rect.left + int((i + 0.5) * crown_w / 5)
            spike_h = int(0.2 * b) if i % 2 == 0 else int(0.35 * b)
            pygame.draw.polygon(surf, crown, [
                (spike_x - int(0.06 * b), crown_y),
                (spike_x, crown_y - spike_h),
                (spike_x + int(0.06 * b), crown_y)])
        pygame.draw.rect(surf, gold_dk, crown_rect, 1, border_radius=1)

    # ─────────────────────────────────────────────
    # 10. 네크로 (해골 여왕) - 뼈 왕관, 보라 아우라
    # ─────────────────────────────────────────────
    def _portrait_necro(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        bone = (220, 210, 200)
        bone_dk = (180, 170, 160)
        body_col = color
        body_lt = self._lighten(color, 40)
        body_dk = self._darken(color, 50)
        eye = (200, 50, 255)
        eye_glow = (230, 100, 255)
        crown = (200, 190, 170)
        crown_dk = (160, 150, 130)
        aura = (140, 40, 200)
        # 배경 오라
        aura_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_s, (*aura, 18), (0, 0, w, h))
        surf.blit(aura_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # 어깨 (뼈 갑옷)
        sh_w, sh_h = int(3.0 * b), int(1.4 * b)
        sh_rect = pygame.Rect(cx - sh_w // 2, cy + int(0.5 * b), sh_w, sh_h)
        pygame.draw.rect(surf, body_dk, sh_rect, border_radius=int(0.3 * b))
        pygame.draw.rect(surf, body_col, sh_rect.inflate(-2, -2), border_radius=int(0.3 * b))
        # 뼈 장식
        for s in [-1, 1]:
            bx = cx + s * int(0.7 * b)
            by = cy + int(0.9 * b)
            pygame.draw.ellipse(surf, bone, (bx - int(0.15 * b), by - int(0.1 * b), int(0.3 * b), int(0.2 * b)))
            pygame.draw.circle(surf, bone_dk, (bx, by), max(1, int(0.05 * b)))
        # 머리 (해골)
        head_w, head_h = int(1.9 * b), int(1.7 * b)
        head_rect = pygame.Rect(cx - head_w // 2, cy - int(1.4 * b), head_w, head_h)
        pygame.draw.ellipse(surf, bone_dk, head_rect.inflate(2, 2))
        pygame.draw.ellipse(surf, bone, head_rect)
        # 눈구멍
        ey = head_rect.centery - int(0.05 * b)
        for s in [-1, 1]:
            ex = head_rect.centerx + s * int(0.25 * b)
            ew, eh = int(0.28 * b), int(0.24 * b)
            pygame.draw.ellipse(surf, (30, 20, 40), (ex - ew // 2, ey - eh // 2, ew, eh))
            # 영혼 불꽃
            pygame.draw.ellipse(surf, eye, (ex - ew // 3, ey - eh // 3, ew * 2 // 3, eh * 2 // 3))
            pygame.draw.circle(surf, eye_glow, (ex, ey), max(1, int(0.06 * b)))
        # 코 구멍
        pygame.draw.polygon(surf, bone_dk, [
            (cx, head_rect.centery + int(0.1 * b)),
            (cx - int(0.06 * b), head_rect.centery + int(0.2 * b)),
            (cx + int(0.06 * b), head_rect.centery + int(0.2 * b))])
        # 이빨
        mouth_y = head_rect.centery + int(0.3 * b)
        for i in range(5):
            tx = head_rect.centerx + (i - 2) * int(0.12 * b)
            pygame.draw.rect(surf, bone, (tx - 2, mouth_y, 4, int(0.1 * b)))
            pygame.draw.rect(surf, bone_dk, (tx - 2, mouth_y, 4, int(0.1 * b)), 1)
        # 뼈 왕관
        crown_y = head_rect.top - int(0.1 * b)
        for i in range(5):
            spike_x = head_rect.left + int((i + 0.5) * head_w / 5)
            spike_h = int(0.5 * b) if i == 2 else int(0.3 * b)
            pts = [
                (spike_x - int(0.08 * b), crown_y + int(0.1 * b)),
                (spike_x, crown_y - spike_h),
                (spike_x + int(0.08 * b), crown_y + int(0.1 * b)),
            ]
            pygame.draw.polygon(surf, crown, pts)
            pygame.draw.polygon(surf, crown_dk, pts, 1)
            # 관절 둥근 끝
            pygame.draw.circle(surf, crown, (spike_x, crown_y - spike_h), max(1, int(0.06 * b)))

    # ─────────────────────────────────────────────
    # 11. 조커 (광대) - 광대 메이크업, 빨간 코, 초록 머리
    # ─────────────────────────────────────────────
    def _portrait_joker(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        skin = (245, 235, 230)
        skin_sh = (215, 205, 200)
        skin_blush = (255, 180, 180)
        hair = (30, 120, 50)
        hair_lt = (50, 160, 70)
        hair_dk = (20, 80, 35)
        eye_white = (255, 255, 255)
        eye_iris = (60, 160, 80)
        eye_pupil = (10, 10, 10)
        nose_red = (220, 50, 40)
        nose_shine = (255, 140, 130)
        lip = (200, 40, 50)
        collar = color
        collar_lt = self._lighten(color, 50)
        collar_dk = self._darken(color, 40)
        # 어깨 (화려한 옷)
        sh_w, sh_h = int(3.0 * b), int(1.4 * b)
        sh_rect = pygame.Rect(cx - sh_w // 2, cy + int(0.5 * b), sh_w, sh_h)
        pygame.draw.rect(surf, collar_dk, sh_rect.move(1, 1), border_radius=int(0.3 * b))
        pygame.draw.rect(surf, collar, sh_rect, border_radius=int(0.3 * b))
        # 러플 칼라
        for i in range(5):
            rx = sh_rect.left + int(i * 0.6 * b)
            ry = sh_rect.top - int(0.1 * b)
            pygame.draw.ellipse(surf, collar_lt, (rx, ry, int(0.5 * b), int(0.35 * b)))
            pygame.draw.ellipse(surf, collar_dk, (rx, ry, int(0.5 * b), int(0.35 * b)), 1)
        # 머리
        head_r = max(4, int(0.8 * b))
        head_x, head_y = cx, cy - int(0.6 * b)
        pygame.draw.circle(surf, skin_sh, (head_x + 1, head_y + 1), head_r)
        pygame.draw.circle(surf, skin, (head_x, head_y), head_r)
        # 볼터치
        for s in [-1, 1]:
            bs = pygame.Surface((int(0.4 * b), int(0.3 * b)), pygame.SRCALPHA)
            pygame.draw.ellipse(bs, (*skin_blush, 70), bs.get_rect())
            surf.blit(bs, (head_x + s * int(0.3 * b) - int(0.2 * b),
                          head_y + int(0.1 * b) - int(0.15 * b)))
        # 눈
        ey = head_y - int(0.05 * b)
        for s in [-1, 1]:
            ex = head_x + s * int(0.28 * b)
            ew, eh = max(3, int(0.18 * b)), max(2, int(0.14 * b))
            pygame.draw.ellipse(surf, eye_white, (ex - ew, ey - eh, ew * 2, eh * 2))
            pygame.draw.circle(surf, eye_iris, (ex, ey), max(2, int(0.09 * b)))
            pygame.draw.circle(surf, eye_pupil, (ex, ey), max(1, int(0.05 * b)))
            pygame.draw.circle(surf, (255, 255, 255), (ex - 1, ey - 1), max(1, int(0.03 * b)))
        # 빨간 코
        nose_y = head_y + int(0.1 * b)
        nose_r = max(2, int(0.12 * b))
        pygame.draw.circle(surf, nose_red, (head_x, nose_y), nose_r)
        pygame.draw.circle(surf, nose_shine, (head_x - 1, nose_y - 1), max(1, nose_r // 2))
        # 입 (큰 웃음)
        mouth_y = head_y + int(0.3 * b)
        pygame.draw.arc(surf, lip,
                        (head_x - int(0.35 * b), mouth_y - int(0.15 * b), int(0.7 * b), int(0.3 * b)),
                        3.3, 6.1, max(2, int(0.06 * b)))
        # 초록 머리 (스파이키)
        for side in [-1, 1]:
            for j in range(3):
                bx = head_x + side * int((0.3 + j * 0.1) * b)
                by = head_y - int(0.5 * b)
                tx = head_x + side * int((0.5 + j * 0.12) * b)
                ty = head_y - int((0.1 - j * 0.1) * b)
                pts = [
                    (bx - side * int(0.06 * b), by + int(0.08 * b)),
                    (tx, ty),
                    (bx + side * int(0.06 * b), by),
                ]
                col = hair if j != 1 else hair_lt
                pygame.draw.polygon(surf, col, pts)
                pygame.draw.polygon(surf, hair_dk, pts, 1)
        # 위쪽 뾰족 머리
        for i in range(3):
            off_x = (i - 1) * int(0.18 * b)
            pts = [
                (head_x + off_x - int(0.08 * b), head_y - int(0.5 * b)),
                (head_x + off_x, head_y - int((0.9 + i * 0.1) * b)),
                (head_x + off_x + int(0.08 * b), head_y - int(0.5 * b)),
            ]
            col = hair_lt if i == 1 else hair
            pygame.draw.polygon(surf, col, pts)
            pygame.draw.polygon(surf, hair_dk, pts, 1)

    # ─────────────────────────────────────────────
    # 12. 세트/미라지 (사막 환술사) - 사막 터번, 황금 피부
    # ─────────────────────────────────────────────
    def _portrait_mirage(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        skin = (200, 170, 120)
        skin_sh = (170, 140, 95)
        turban = color
        turban_lt = self._lighten(color, 50)
        turban_dk = self._darken(color, 40)
        eye = (180, 140, 60)
        eye_glow = (220, 180, 80)
        jewel = (200, 50, 50)
        jewel_hi = (255, 120, 120)
        cloth = (180, 150, 80)
        cloth_lt = (210, 180, 110)
        # 배경 오라 (사막 열기)
        aura_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_s, (210, 180, 100, 12), (0, 0, w, h))
        surf.blit(aura_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # 어깨 (사막 로브)
        sh_w, sh_h = int(3.0 * b), int(1.5 * b)
        sh_rect = pygame.Rect(cx - sh_w // 2, cy + int(0.4 * b), sh_w, sh_h)
        pygame.draw.rect(surf, turban_dk, sh_rect, border_radius=int(0.3 * b))
        pygame.draw.rect(surf, cloth, sh_rect.inflate(-2, -2), border_radius=int(0.3 * b))
        pygame.draw.rect(surf, cloth_lt, sh_rect.inflate(-int(0.3 * b), -int(0.2 * b)), border_radius=2)
        # 금 줄 장식
        pygame.draw.line(surf, turban, (sh_rect.left + int(0.2 * b), sh_rect.centery),
                         (sh_rect.right - int(0.2 * b), sh_rect.centery), 1)
        # 터번
        head_w, head_h = int(2.2 * b), int(2.0 * b)
        head_rect = pygame.Rect(cx - head_w // 2, cy - int(1.7 * b), head_w, head_h)
        pygame.draw.ellipse(surf, turban_dk, head_rect.inflate(2, 2))
        pygame.draw.ellipse(surf, turban, head_rect)
        pygame.draw.ellipse(surf, turban_lt, head_rect.inflate(-int(0.4 * b), -int(0.3 * b)))
        # 터번 주름
        for i in range(4):
            fy = head_rect.top + int((i + 1) * 0.35 * b)
            pygame.draw.arc(surf, turban_dk,
                            (head_rect.left + int(0.1 * b), fy, head_rect.width - int(0.2 * b), int(0.2 * b)),
                            0, math.pi, 1)
        # 보석 장식
        pygame.draw.circle(surf, jewel, (cx, head_rect.centery - int(0.2 * b)), max(2, int(0.14 * b)))
        pygame.draw.circle(surf, jewel_hi, (cx - 1, head_rect.centery - int(0.22 * b)), max(1, int(0.06 * b)))
        # 얼굴
        face_w, face_h = int(1.2 * b), int(1.0 * b)
        face_rect = pygame.Rect(cx - face_w // 2, cy - int(0.7 * b), face_w, face_h)
        pygame.draw.ellipse(surf, skin_sh, face_rect.inflate(2, 2))
        pygame.draw.ellipse(surf, skin, face_rect)
        # 눈 (황금빛)
        ey = face_rect.centery - int(0.05 * b)
        for s in [-1, 1]:
            ex = face_rect.centerx + s * int(0.22 * b)
            ew, eh = max(3, int(0.16 * b)), max(2, int(0.12 * b))
            pygame.draw.ellipse(surf, (255, 255, 255), (ex - ew, ey - eh, ew * 2, eh * 2))
            pygame.draw.circle(surf, eye, (ex, ey), max(1, int(0.08 * b)))
            pygame.draw.circle(surf, eye_glow, (ex, ey), max(1, int(0.04 * b)))
        # 코/입
        pygame.draw.line(surf, skin_sh, (cx, face_rect.centery + int(0.05 * b)),
                         (cx, face_rect.centery + int(0.15 * b)), 1)
        # 얼굴 베일 (입 가림)
        veil_y = face_rect.centery + int(0.15 * b)
        veil_pts = [
            (face_rect.left - int(0.1 * b), veil_y),
            (face_rect.right + int(0.1 * b), veil_y),
            (face_rect.right, face_rect.bottom + int(0.1 * b)),
            (face_rect.left, face_rect.bottom + int(0.1 * b)),
        ]
        pygame.draw.polygon(surf, cloth, veil_pts)
        pygame.draw.polygon(surf, cloth_lt, veil_pts, 1)

    # ─────────────────────────────────────────────
    # 13. 호루스/라 (천둥의 매) - 매 투구, 태양 오렌지
    # ─────────────────────────────────────────────
    def _portrait_ra(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        helmet = color
        helmet_lt = self._lighten(color, 50)
        helmet_dk = self._darken(color, 45)
        gold = (220, 190, 80)
        gold_dk = (180, 150, 50)
        skin = (180, 140, 100)
        skin_sh = (150, 115, 80)
        eye = (255, 200, 50)
        eye_glow = (255, 230, 100)
        feather = (100, 70, 40)
        feather_lt = (140, 100, 60)
        # 배경
        aura_s = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_s, (255, 200, 50, 12), (0, 0, w, h))
        surf.blit(aura_s, (0, 0), special_flags=pygame.BLEND_ADD)
        # 어깨 (이집트 갑옷)
        sh_w, sh_h = int(3.2 * b), int(1.5 * b)
        sh_rect = pygame.Rect(cx - sh_w // 2, cy + int(0.4 * b), sh_w, sh_h)
        pygame.draw.rect(surf, helmet_dk, sh_rect, border_radius=int(0.3 * b))
        pygame.draw.rect(surf, helmet, sh_rect.inflate(-2, -2), border_radius=int(0.3 * b))
        # 금 줄 장식
        for i in range(3):
            gy = sh_rect.top + int(0.2 * b) + i * int(0.3 * b)
            pygame.draw.line(surf, gold, (sh_rect.left + int(0.2 * b), gy),
                             (sh_rect.right - int(0.2 * b), gy), 1)
        # 어깨 깃털
        for s in [-1, 1]:
            for f in range(3):
                fx = cx + s * int((1.0 + f * 0.15) * b)
                fy = cy + int(0.5 * b) + f * int(0.2 * b)
                pygame.draw.line(surf, feather if f % 2 == 0 else feather_lt,
                                 (fx, fy), (fx + s * int(0.3 * b), fy + int(0.4 * b)),
                                 max(1, int(0.06 * b)))
        # 투구 (매 모양)
        head_w, head_h = int(2.2 * b), int(2.0 * b)
        head_rect = pygame.Rect(cx - head_w // 2, cy - int(1.7 * b), head_w, head_h)
        pygame.draw.ellipse(surf, helmet_dk, head_rect.inflate(2, 2))
        pygame.draw.ellipse(surf, helmet, head_rect)
        pygame.draw.ellipse(surf, helmet_lt, head_rect.inflate(-int(0.3 * b), -int(0.2 * b)))
        # 부리 (투구 앞부분)
        beak_y = head_rect.centery + int(0.3 * b)
        beak_pts = [
            (cx - int(0.2 * b), beak_y),
            (cx, beak_y + int(0.4 * b)),
            (cx + int(0.2 * b), beak_y),
        ]
        pygame.draw.polygon(surf, gold, beak_pts)
        pygame.draw.polygon(surf, gold_dk, beak_pts, 1)
        # 눈 슬릿
        ey = head_rect.centery
        for s in [-1, 1]:
            ex = head_rect.centerx + s * int(0.35 * b)
            # 아이라인 (이집트 스타일)
            pygame.draw.ellipse(surf, (20, 15, 10),
                                (ex - int(0.18 * b), ey - int(0.08 * b), int(0.36 * b), int(0.16 * b)))
            pygame.draw.ellipse(surf, eye,
                                (ex - int(0.12 * b), ey - int(0.05 * b), int(0.24 * b), int(0.1 * b)))
            pygame.draw.ellipse(surf, eye_glow,
                                (ex - int(0.06 * b), ey - int(0.03 * b), int(0.12 * b), int(0.06 * b)))
            # 아이라인 연장
            pygame.draw.line(surf, (20, 15, 10),
                             (ex + s * int(0.18 * b), ey),
                             (ex + s * int(0.3 * b), ey + int(0.08 * b)), 1)
        # 투구 중앙 코브라
        cobra_y = head_rect.top + int(0.2 * b)
        pygame.draw.polygon(surf, gold, [
            (cx - int(0.1 * b), cobra_y + int(0.2 * b)),
            (cx, cobra_y - int(0.3 * b)),
            (cx + int(0.1 * b), cobra_y + int(0.2 * b))])
        pygame.draw.circle(surf, (200, 50, 50), (cx, cobra_y - int(0.15 * b)), max(1, int(0.06 * b)))

    # ─────────────────────────────────────────────
    # 14. 안드로이드 (전투 병기) - 로봇 바이저, 금속 패널
    # ─────────────────────────────────────────────
    def _portrait_android(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        metal = color
        metal_lt = self._lighten(color, 50)
        metal_dk = self._darken(color, 45)
        visor = (60, 180, 255)
        visor_lt = (100, 210, 255)
        visor_dk = (30, 100, 180)
        panel = (100, 105, 115)
        panel_lt = (140, 145, 155)
        led = (0, 255, 150)
        # 어깨 (금속 갑옷)
        sh_w, sh_h = int(3.4 * b), int(1.5 * b)
        sh_rect = pygame.Rect(cx - sh_w // 2, cy + int(0.5 * b), sh_w, sh_h)
        pygame.draw.rect(surf, metal_dk, sh_rect.move(1, 1), border_radius=int(0.2 * b))
        pygame.draw.rect(surf, metal, sh_rect, border_radius=int(0.2 * b))
        pygame.draw.rect(surf, metal_lt, sh_rect.inflate(-int(0.3 * b), -int(0.2 * b)), 1, border_radius=2)
        # 패널 라인
        for i in range(3):
            py = sh_rect.top + int(0.3 * b) + i * int(0.3 * b)
            pygame.draw.line(surf, panel, (sh_rect.left + int(0.2 * b), py),
                             (sh_rect.right - int(0.2 * b), py), 1)
        # LED 점
        for s in [-1, 1]:
            pygame.draw.circle(surf, led, (cx + s * int(0.6 * b), cy + int(0.8 * b)), max(1, int(0.06 * b)))
        # 머리 (로봇)
        head_w, head_h = int(2.0 * b), int(1.8 * b)
        head_rect = pygame.Rect(cx - head_w // 2, cy - int(1.4 * b), head_w, head_h)
        pygame.draw.rect(surf, metal_dk, head_rect.inflate(2, 2), border_radius=int(0.3 * b))
        pygame.draw.rect(surf, metal, head_rect, border_radius=int(0.3 * b))
        pygame.draw.rect(surf, metal_lt, head_rect.inflate(-int(0.2 * b), -int(0.15 * b)), 1, border_radius=int(0.25 * b))
        # 패널 라인
        for i in range(2):
            lx = head_rect.left + int((i + 1) * 0.65 * b)
            pygame.draw.line(surf, panel, (lx, head_rect.top + int(0.2 * b)),
                             (lx, head_rect.bottom - int(0.2 * b)), 1)
        # 바이저
        visor_w, visor_h = int(1.4 * b), int(0.5 * b)
        visor_rect = pygame.Rect(cx - visor_w // 2, head_rect.centery - visor_h // 2 - int(0.05 * b),
                                  visor_w, visor_h)
        pygame.draw.rect(surf, visor_dk, visor_rect.inflate(2, 2), border_radius=3)
        pygame.draw.rect(surf, visor, visor_rect, border_radius=3)
        pygame.draw.rect(surf, visor_lt, visor_rect.inflate(-2, -2), border_radius=2)
        # 눈 (LED)
        for s in [-1, 1]:
            ex = cx + s * int(0.3 * b)
            ey = visor_rect.centery
            pygame.draw.circle(surf, (255, 255, 255), (ex, ey), max(2, int(0.1 * b)))
            pygame.draw.circle(surf, visor, (ex, ey), max(1, int(0.06 * b)))
        # 입 (통풍구)
        mouth_y = head_rect.centery + int(0.35 * b)
        mouth_w = int(0.6 * b)
        for i in range(3):
            ly = mouth_y + i * int(0.08 * b)
            pygame.draw.line(surf, panel,
                             (cx - mouth_w // 2, ly), (cx + mouth_w // 2, ly), 1)
        # 안테나
        pygame.draw.line(surf, metal_dk, (cx, head_rect.top), (cx, head_rect.top - int(0.4 * b)), max(1, int(0.06 * b)))
        pygame.draw.circle(surf, led, (cx, head_rect.top - int(0.4 * b)), max(1, int(0.08 * b)))

    # ─────────────────────────────────────────────
    # 15. 원숭이왕 (밀림 패왕) - 황금 왕관, 원숭이 얼굴
    # ─────────────────────────────────────────────
    def _portrait_monkeyking(self, surf, w, h, color):
        cx, cy = w // 2, h * 55 // 100
        b = max(3, h // 7)
        fur = color
        fur_lt = self._lighten(color, 40)
        fur_dk = self._darken(color, 45)
        face_pink = (220, 170, 140)
        face_red = (200, 130, 110)
        face_sh = (180, 140, 110)
        eye_white = (255, 255, 255)
        eye_amber = (200, 150, 40)
        eye_pupil = (20, 15, 10)
        crown = (220, 190, 60)
        crown_dk = (180, 150, 30)
        ear_outer = (200, 160, 100)
        ear_inner = (220, 150, 140)
        armor = self._darken(color, 20)
        # 어깨 (갑옷)
        sh_w, sh_h = int(3.2 * b), int(1.5 * b)
        sh_rect = pygame.Rect(cx - sh_w // 2, cy + int(0.5 * b), sh_w, sh_h)
        pygame.draw.rect(surf, self._darken(armor, 20), sh_rect.move(1, 1), border_radius=int(0.3 * b))
        pygame.draw.rect(surf, armor, sh_rect, border_radius=int(0.3 * b))
        # 금 줄 장식
        pygame.draw.line(surf, crown, (sh_rect.left + int(0.2 * b), sh_rect.centery),
                         (sh_rect.right - int(0.2 * b), sh_rect.centery), 1)
        # 머리 털
        head_r = max(4, int(0.85 * b))
        head_x, head_y = cx, cy - int(0.5 * b)
        pygame.draw.circle(surf, fur_dk, (head_x, head_y), head_r + 1)
        pygame.draw.circle(surf, fur, (head_x, head_y), head_r)
        pygame.draw.circle(surf, fur_lt, (head_x - int(0.08 * b), head_y - int(0.1 * b)),
                           max(2, head_r - int(0.15 * b)))
        # 귀
        for s in [-1, 1]:
            ear_x = head_x + s * int(0.65 * b)
            ear_y = head_y - int(0.05 * b)
            er = max(2, int(0.2 * b))
            pygame.draw.circle(surf, ear_outer, (ear_x, ear_y), er)
            pygame.draw.circle(surf, ear_inner, (ear_x + s * int(0.02 * b), ear_y), max(1, er - 2))
        # 얼굴 (붉은빛 원숭이 특유)
        face_w, face_h = int(1.0 * b), int(0.9 * b)
        face_rect = pygame.Rect(head_x - face_w // 2, head_y - int(0.15 * b), face_w, face_h)
        pygame.draw.ellipse(surf, face_pink, face_rect)
        # 이마 돌출
        brow_y = head_y - int(0.05 * b)
        brow_w = int(0.7 * b)
        brow_rect = pygame.Rect(head_x - brow_w // 2, brow_y - int(0.12 * b), brow_w, int(0.24 * b))
        pygame.draw.ellipse(surf, face_red, brow_rect)
        # 눈
        ey = head_y + int(0.05 * b)
        for s in [-1, 1]:
            ex = head_x + s * int(0.2 * b)
            ew, eh = max(2, int(0.14 * b)), max(1, int(0.1 * b))
            pygame.draw.ellipse(surf, eye_white, (ex - ew, ey - eh, ew * 2, eh * 2))
            pygame.draw.circle(surf, eye_amber, (ex, ey), max(1, int(0.07 * b)))
            pygame.draw.circle(surf, eye_pupil, (ex, ey), max(1, int(0.04 * b)))
            pygame.draw.circle(surf, (255, 255, 240), (ex + 1, ey - 1), max(1, int(0.02 * b)))
        # 코 (납작하고 넓음)
        nose_y = head_y + int(0.2 * b)
        pygame.draw.polygon(surf, face_sh, [
            (head_x, nose_y - int(0.04 * b)),
            (head_x - int(0.08 * b), nose_y + int(0.06 * b)),
            (head_x + int(0.08 * b), nose_y + int(0.06 * b))])
        # 콧구멍
        for s in [-1, 1]:
            pygame.draw.circle(surf, (130, 90, 60),
                               (head_x + s * int(0.05 * b), nose_y + int(0.04 * b)), max(1, int(0.03 * b)))
        # 입
        mouth_y = head_y + int(0.35 * b)
        pygame.draw.arc(surf, (150, 100, 70),
                        (head_x - int(0.2 * b), mouth_y - int(0.05 * b), int(0.4 * b), int(0.15 * b)),
                        3.3, 6.1, 1)
        # 왕관
        crown_y = head_y - head_r - int(0.05 * b)
        cw = int(1.2 * b)
        crown_rect = pygame.Rect(head_x - cw // 2, crown_y, cw, int(0.35 * b))
        pygame.draw.rect(surf, crown, crown_rect, border_radius=2)
        pygame.draw.rect(surf, crown_dk, crown_rect, 1, border_radius=2)
        for i in range(3):
            sx = crown_rect.left + int((i + 0.5) * cw / 3)
            sh = int(0.3 * b) if i == 1 else int(0.2 * b)
            pygame.draw.polygon(surf, crown, [
                (sx - int(0.06 * b), crown_y),
                (sx, crown_y - sh),
                (sx + int(0.06 * b), crown_y)])
        # 왕관 보석
        pygame.draw.circle(surf, (200, 50, 50), (head_x, crown_y + int(0.15 * b)), max(1, int(0.06 * b)))


# ─────────────────────────────────────────────
# 싱글턴
# ─────────────────────────────────────────────
_portrait_renderer_instance = None


def get_portrait_renderer() -> HeroPortraitRenderer:
    global _portrait_renderer_instance
    if _portrait_renderer_instance is None:
        _portrait_renderer_instance = HeroPortraitRenderer()
    return _portrait_renderer_instance
