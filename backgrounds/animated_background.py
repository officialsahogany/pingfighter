import os
import sys

def resource_path(relative_path):
    """PyInstaller 번들과 일반 실행 모두에서 작동하는 리소스 경로 반환"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    return os.path.join(base_path, relative_path)


# -*- coding: utf-8 -*-
import pygame
import math
import random


class AnimatedBackground:
    """스테이지 1 - 풍악보이 (한국 전통 테마) 배경"""

    GAME_AREA_X = 80
    GAME_AREA_WIDTH = 600
    GAME_AREA_END_X = 680

    def __init__(self, base_image_path="stage1_field.png", target_width=None, target_height=None):
        W = target_width or 760
        H = target_height or 750
        self.width = W
        self.height = H

        # 프로시저럴 바닥 생성
        self.base_image = pygame.Surface((W, H))
        self._generate_floor(W, H)

        self.time = 0

        # 서피스 재사용 (매 프레임 생성 방지)
        self.glow_surface = pygame.Surface((W, H), pygame.SRCALPHA)
        self.grid_surface = pygame.Surface((W, H), pygame.SRCALPHA)
        self.rotated_surface = pygame.Surface((W, H), pygame.SRCALPHA)
        self.flash_surface = pygame.Surface((W, H), pygame.SRCALPHA)
        self._transparent = (0, 0, 0, 0)

        self.center_x = W // 2
        self.center_y = H // 2
        self.taegeuk_radius = 80

        self.grid_particles = []
        for _ in range(20):
            self.grid_particles.append({
                'x': random.randint(0, W),
                'y': random.randint(H // 2, H),
                'speed': random.uniform(0.5, 2),
                'size': random.randint(1, 3)
            })

    # ================================================================
    # 프로시저럴 한국 전통 석재 바닥 생성
    # ================================================================
    def _generate_floor(self, W, H):
        """고퀄리티 한국 전통 석조 바닥 텍스처 생성"""
        _sin = math.sin
        cx, cy = W // 2, H // 2

        # ── 색상 팔레트 (한국 전통 석재/기와/목재) ──
        stone = (72, 68, 62)            # 짙은 화강암
        stone_light = (95, 90, 82)      # 밝은 화강암
        stone_dark = (52, 48, 42)       # 어두운 화강암 그림자
        stone_warm = (82, 74, 65)       # 따뜻한 석재
        stone_cool = (65, 65, 72)       # 서늘한 청석
        grout = (42, 38, 34)            # 줄눈 (타일 틈)
        grout_light = (58, 54, 48)      # 밝은 줄눈
        moss_color = (55, 68, 42)       # 이끼
        wood_accent = (95, 65, 40)      # 목재 악센트
        dancheong_red = (140, 45, 35)   # 단청 빨강
        dancheong_blue = (35, 55, 95)   # 단청 파랑

        def clamp(v):
            return max(0, min(255, int(v)))

        def multi_noise(x, y, seed=0):
            v = 0.0
            v += 0.30 * _sin(x * 0.019 + y * 0.014 + seed)
            v += 0.22 * _sin(x * 0.038 - y * 0.027 + seed * 1.7)
            v += 0.18 * _sin(x * 0.071 + y * 0.058 + seed * 2.3)
            v += 0.14 * _sin(x * 0.127 - y * 0.098 + seed * 3.1)
            v += 0.10 * _sin(x * 0.211 + y * 0.173 + seed * 4.7)
            v += 0.06 * _sin(x * 0.347 - y * 0.289 + seed * 6.1)
            return max(-1.0, min(1.0, v))

        floor = self.base_image

        # ═══════════════════════════════════════════════════════════
        # 1. 베이스 석재 + 2px 연속 노이즈
        # ═══════════════════════════════════════════════════════════
        floor.fill(stone)
        noise_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        step = 2
        for gy in range(0, H, step):
            for gx in range(0, W, step):
                n1 = multi_noise(gx, gy, seed=0)
                n2 = multi_noise(gx, gy, seed=50.0)
                n3 = multi_noise(gx, gy, seed=120.0)
                bright = n1 * 10.0
                warm = n2 * 5.0
                sat = n3 * 3.0
                r = clamp(stone[0] + bright + warm + sat)
                g = clamp(stone[1] + bright + warm * 0.4 + sat * 0.2)
                b = clamp(stone[2] + bright - warm * 0.3 + sat * 0.5)
                pygame.draw.rect(noise_surf, (r, g, b, 85), (gx, gy, step, step))
        floor.blit(noise_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 2. 방사형 그라데이션 (중앙 밝게)
        # ═══════════════════════════════════════════════════════════
        grad_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        max_dist = math.sqrt(cx ** 2 + cy ** 2)
        for ring in range(28, 0, -1):
            frac = ring / 28.0
            radius = int(max_dist * frac)
            pygame.draw.circle(grad_surf, (20, 18, 15, int(5 * (1.0 - frac))),
                               (cx, cy), radius)
        for ring in range(10, 0, -1):
            frac = ring / 10.0
            radius = int(180 * frac)
            pygame.draw.circle(grad_surf, (200, 190, 170, int(4 * (1.0 - frac))),
                               (cx, cy), radius)
        floor.blit(grad_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 3. 석재 타일 그리드 (불규칙 사각 타일)
        # ═══════════════════════════════════════════════════════════
        tile_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(500)
        # 타일 크기 변동
        tile_base_w = 48
        tile_base_h = 42
        y_pos = 5
        row = 0
        tile_rects = []  # 타일 위치 저장 (색상 패치용)
        while y_pos < H - 5:
            th = tile_base_h + random.randint(-6, 6)
            x_pos = 5 + (row % 2) * random.randint(8, 18)  # 지그재그 오프셋
            while x_pos < W - 5:
                tw = tile_base_w + random.randint(-8, 8)
                tile_rects.append((x_pos, y_pos, tw, th))
                # 줄눈 (타일 틈새) - 어두운 선
                grout_a = random.randint(50, 90)
                # 하단 줄눈
                pygame.draw.line(tile_surf, (*grout, grout_a),
                                 (x_pos, y_pos + th), (x_pos + tw, y_pos + th), 1)
                # 우측 줄눈
                pygame.draw.line(tile_surf, (*grout, grout_a),
                                 (x_pos + tw, y_pos), (x_pos + tw, y_pos + th), 1)
                # 줄눈 밝은 가장자리 (위/좌 - 빛 받는 면)
                grout_la = grout_a // 3
                pygame.draw.line(tile_surf, (*grout_light, grout_la),
                                 (x_pos, y_pos), (x_pos + tw, y_pos), 1)
                pygame.draw.line(tile_surf, (*grout_light, grout_la),
                                 (x_pos, y_pos), (x_pos, y_pos + th), 1)
                x_pos += tw + random.randint(2, 4)
            y_pos += th + random.randint(2, 4)
            row += 1
        random.seed()
        floor.blit(tile_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 4. 타일별 색상 변화 (각 타일마다 미세한 색조 차이)
        # ═══════════════════════════════════════════════════════════
        tilecolor_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(501)
        tile_palettes = [
            stone, stone_light, stone_warm, stone_cool,
            (78, 72, 66), (68, 65, 60), (85, 78, 70), (60, 58, 55),
        ]
        for tx, ty, tw, th in tile_rects:
            tc = random.choice(tile_palettes)
            ta = random.randint(20, 45)
            pygame.draw.rect(tilecolor_surf, (*tc, ta), (tx + 1, ty + 1, tw - 1, th - 1))
        random.seed()
        floor.blit(tilecolor_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 5. 대규모 색상 패치 (습기/풍화/이끼 영역)
        # ═══════════════════════════════════════════════════════════
        patch_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(302)
        patch_types = [
            (stone_light, 8, 16, 40, 90, 8),      # 밝은 석재
            (stone_dark, 10, 20, 30, 70, 8),       # 어두운 음영
            (stone_warm, 6, 12, 35, 65, 6),        # 따뜻한 풍화
            (stone_cool, 6, 12, 30, 55, 6),        # 서늘한 청석
            (moss_color, 5, 10, 15, 35, 5),        # 이끼 영역
            ((75, 60, 50), 6, 12, 25, 50, 4),      # 붉은 풍화
        ]
        for pc, a_min, a_max, r_min, r_max, count in patch_types:
            for _ in range(count):
                px = random.randint(20, W - 20)
                py = random.randint(20, H - 20)
                pr = random.randint(r_min, r_max)
                pa = random.randint(a_min, a_max)
                for r in range(pr, 0, -2):
                    frac = r / pr
                    pygame.draw.circle(patch_surf,
                                       (pc[0], pc[1], pc[2], int(pa * frac * frac)),
                                       (px, py), r)
        random.seed()
        floor.blit(patch_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 6. 석재 알갱이 텍스처 (화강암 입자)
        # ═══════════════════════════════════════════════════════════
        grain_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(42)
        # 굵은 입자 클러스터
        clusters = [(random.randint(15, W-15), random.randint(15, H-15))
                     for _ in range(35)]
        for ccx, ccy in clusters:
            for _ in range(random.randint(5, 12)):
                gx = ccx + random.randint(-20, 20)
                gy = ccy + random.randint(-20, 20)
                if 1 <= gx < W-1 and 1 <= gy < H-1:
                    gs = random.randint(1, 3)
                    shade = random.randint(-12, 12)
                    ga = random.randint(30, 60)
                    gc = (clamp(stone[0]+shade), clamp(stone[1]+shade),
                          clamp(stone[2]+shade), ga)
                    pygame.draw.ellipse(grain_surf, gc,
                                        (gx-gs, gy-max(1, gs-1), gs*2, max(2, (gs-1)*2)))
        # 중간 입자
        for _ in range(800):
            gx = random.randint(1, W-2)
            gy = random.randint(1, H-2)
            shade = random.randint(-18, 18)
            ga = random.randint(30, 65)
            gc = (clamp(stone[0]+shade), clamp(stone[1]+shade),
                  clamp(stone[2]+shade), ga)
            pygame.draw.circle(grain_surf, gc, (gx, gy), random.randint(1, 2))
        # 미세 입자
        for _ in range(3000):
            gx = random.randint(0, W-1)
            gy = random.randint(0, H-1)
            shade = random.randint(-20, 20)
            ga = random.randint(20, 55)
            grain_surf.set_at((gx, gy), (clamp(stone[0]+shade),
                                         clamp(stone[1]+shade),
                                         clamp(stone[2]+shade), ga))
        # 운모 반짝임 (화강암 특유)
        mica_centers = [(random.randint(20, W-20), random.randint(20, H-20))
                        for _ in range(18)]
        for mx, my in mica_centers:
            for _ in range(random.randint(3, 7)):
                px = mx + random.randint(-12, 12)
                py = my + random.randint(-12, 12)
                if 0 <= px < W and 0 <= py < H:
                    grain_surf.set_at((px, py),
                                      (random.randint(140, 170),
                                       random.randint(135, 160),
                                       random.randint(120, 145),
                                       random.randint(50, 110)))
        for _ in range(180):
            gx = random.randint(0, W-1)
            gy = random.randint(0, H-1)
            grain_surf.set_at((gx, gy), (155, 148, 135, random.randint(35, 80)))
        random.seed()
        floor.blit(grain_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 7. 이끼/지의류 (줄눈 근처에 집중)
        # ═══════════════════════════════════════════════════════════
        moss_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(333)
        moss_palettes = [
            (50, 65, 38), (55, 72, 42), (45, 58, 35),
            (60, 70, 45), (48, 62, 40), (52, 60, 36),
        ]
        # 줄눈 영역 근처에 이끼 점
        for tx, ty, tw, th in tile_rects:
            if random.random() < 0.3:  # 30% 타일에만
                # 하단 줄눈 근처
                for _ in range(random.randint(2, 6)):
                    mx = tx + random.randint(3, max(4, tw - 3))
                    my = ty + th + random.randint(-2, 2)
                    ms = random.randint(1, 3)
                    mc = random.choice(moss_palettes)
                    ma = random.randint(30, 70)
                    pygame.draw.circle(moss_surf, (*mc, ma), (mx, my), ms)
            if random.random() < 0.2:  # 20% - 우측 줄눈
                for _ in range(random.randint(1, 4)):
                    mx = tx + tw + random.randint(-2, 2)
                    my = ty + random.randint(3, max(4, th - 3))
                    ms = random.randint(1, 2)
                    mc = random.choice(moss_palettes)
                    ma = random.randint(25, 60)
                    pygame.draw.circle(moss_surf, (*mc, ma), (mx, my), ms)
        # 구석/가장자리 이끼 패치
        for _ in range(12):
            mx = random.randint(10, W-10)
            my = random.randint(10, H-10)
            mr = random.randint(8, 20)
            mc = random.choice(moss_palettes)
            for r in range(mr, 0, -2):
                frac = r / mr
                pygame.draw.circle(moss_surf, (*mc, int(12 * frac * frac)), (mx, my), r)
        random.seed()
        floor.blit(moss_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 8. 풍화 균열
        # ═══════════════════════════════════════════════════════════
        crack_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(99)
        cr_dark = (clamp(stone_dark[0]-10), clamp(stone_dark[1]-10), clamp(stone_dark[2]-8))
        cr_light = (clamp(stone_light[0]+5), clamp(stone_light[1]+5), clamp(stone_light[2]+3))
        for _ in range(10):
            sx = random.randint(80, W-80)
            sy = random.randint(60, H-60)
            angle = random.uniform(0, math.pi * 2)
            pts = [(sx, sy)]
            for _ in range(random.randint(4, 9)):
                seg_len = random.randint(6, 18)
                angle += random.uniform(-0.6, 0.6)
                pts.append((pts[-1][0] + int(seg_len * math.cos(angle)),
                            pts[-1][1] + int(seg_len * _sin(angle))))
            ca = random.randint(25, 45)
            if len(pts) >= 2:
                deep = [(p[0], p[1]+1) for p in pts]
                pygame.draw.lines(crack_surf, (*cr_dark, ca // 2), False, deep, 2)
                pygame.draw.lines(crack_surf, (*cr_dark, ca), False, pts, 1)
                light = [(p[0], p[1]-1) for p in pts]
                pygame.draw.lines(crack_surf, (*cr_light, ca // 3), False, light, 1)
            for _ in range(random.randint(1, 3)):
                if len(pts) < 3:
                    break
                bi = random.randint(1, len(pts)-1)
                bx, by = pts[bi]
                ba = angle + random.uniform(-1.2, 1.2)
                b_pts = [(bx, by)]
                for _ in range(random.randint(2, 4)):
                    bl = random.randint(4, 12)
                    ba += random.uniform(-0.6, 0.6)
                    b_pts.append((b_pts[-1][0]+int(bl*math.cos(ba)),
                                  b_pts[-1][1]+int(bl*_sin(ba))))
                if len(b_pts) >= 2:
                    pygame.draw.lines(crack_surf, (*cr_dark, random.randint(15, 28)),
                                      False, b_pts, 1)
        random.seed()
        floor.blit(crack_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 9. 미세 그림자 노이즈 (깊이감)
        # ═══════════════════════════════════════════════════════════
        shadow_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        random.seed(777)
        for _ in range(100):
            sx = random.randint(0, W-1)
            sy = random.randint(0, H-1)
            sr = random.randint(3, 10)
            sa = random.randint(4, 12)
            if random.random() < 0.6:
                pygame.draw.circle(shadow_surf,
                                   (stone_dark[0]-8, stone_dark[1]-8, stone_dark[2]-6, sa),
                                   (sx, sy), sr)
            else:
                pygame.draw.circle(shadow_surf,
                                   (stone_light[0]+5, stone_light[1]+5, stone_light[2]+3, sa),
                                   (sx, sy), sr)
        random.seed()
        floor.blit(shadow_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 10. 닳은 바닥 (전투 마모 + 발자국)
        # ═══════════════════════════════════════════════════════════
        wear_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        for r in range(80, 0, -2):
            frac = r / 80.0
            pygame.draw.ellipse(wear_surf,
                                (stone_light[0], stone_light[1], stone_light[2],
                                 int(4 * (1.0 - frac))),
                                (cx-r, cy-int(r*0.55), r*2, int(r*1.1)))
        for pad_y in [55, H-55]:
            for r in range(55, 0, -3):
                frac = r / 55.0
                pygame.draw.ellipse(wear_surf,
                                    (stone_light[0]+5, stone_light[1]+5, stone_light[2]+3,
                                     int(3 * (1.0 - frac))),
                                    (cx-r, pad_y-int(r*0.35), r*2, int(r*0.7)))
        random.seed(222)
        for _ in range(15):
            fx = random.randint(110, W-110)
            fy = random.randint(70, H-70)
            fw, fh = random.randint(3, 7), random.randint(2, 5)
            pygame.draw.ellipse(wear_surf,
                                (stone_dark[0], stone_dark[1], stone_dark[2],
                                 random.randint(5, 12)),
                                (fx-fw, fy-fh, fw*2, fh*2))
        random.seed()
        floor.blit(wear_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 11. 단청 문양 테두리 (게임 영역 가장자리)
        # ═══════════════════════════════════════════════════════════
        dancheong_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        ga_x = self.GAME_AREA_X       # 80
        ga_ex = self.GAME_AREA_END_X   # 680
        border_a = 35
        # 좌우 단청 테두리 선
        for offset in [8, 16, 24]:
            # 빨강 선 (짝수)
            if offset % 16 == 0:
                bc = (*dancheong_red, border_a)
            else:
                bc = (*dancheong_blue, border_a)
            pygame.draw.line(dancheong_surf, bc,
                             (ga_x + offset, 10), (ga_x + offset, H - 10), 1)
            pygame.draw.line(dancheong_surf, bc,
                             (ga_ex - offset, 10), (ga_ex - offset, H - 10), 1)
        # 상하 단청 테두리 선
        for offset in [8, 16, 24]:
            if offset % 16 == 0:
                bc = (*dancheong_red, border_a)
            else:
                bc = (*dancheong_blue, border_a)
            pygame.draw.line(dancheong_surf, bc,
                             (ga_x + 5, offset), (ga_ex - 5, offset), 1)
            pygame.draw.line(dancheong_surf, bc,
                             (ga_x + 5, H - offset), (ga_ex - 5, H - offset), 1)
        # 모서리 단청 무늬 (작은 사각 장식)
        for corner_x, corner_y in [(ga_x + 12, 12), (ga_ex - 12, 12),
                                    (ga_x + 12, H - 12), (ga_ex - 12, H - 12)]:
            pygame.draw.rect(dancheong_surf, (*dancheong_red, 40),
                             (corner_x - 4, corner_y - 4, 8, 8), 1)
            pygame.draw.rect(dancheong_surf, (*dancheong_blue, 30),
                             (corner_x - 2, corner_y - 2, 4, 4))
        floor.blit(dancheong_surf, (0, 0))

        # ═══════════════════════════════════════════════════════════
        # 12. 비네트 (가장자리 어둡게)
        # ═══════════════════════════════════════════════════════════
        vignette_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        vig_max = math.sqrt(cx**2 + cy**2)
        for ring in range(28):
            radius = int(vig_max * (1.0 - ring * 0.028))
            pygame.draw.circle(vignette_surf, (15, 12, 10, int(2.5 + ring * 1.5)),
                               (cx, cy), radius)
        floor.blit(vignette_surf, (0, 0))

    def update(self, dt):
        self.time += dt
        for particle in self.grid_particles:
            particle['y'] -= particle['speed']
            if particle['y'] < self.height // 2:
                particle['y'] = self.height
                particle['x'] = random.randint(0, self.width)

    def draw(self, screen):
        screen.blit(self.base_image, (0, 0))

        self.glow_surface.fill(self._transparent)
        pulse = math.sin(self.time * 0.002) * 0.5 + 0.5
        glow_alpha = int(80 + pulse * 100)
        glow_radius = self.taegeuk_radius + int(pulse * 15)

        for i in range(3):
            radius = glow_radius + i * 10
            alpha = max(0, glow_alpha - i * 30)
            if alpha > 0:
                pygame.draw.circle(self.glow_surface,
                                   (25, 25, 200, alpha),
                                   (self.center_x, self.center_y), radius)

        rotation = self.time * 0.001
        self.rotated_surface.fill(self._transparent)

        for angle in range(0, 360, 90):
            rad = math.radians(angle + rotation * 50)
            x = self.center_x + math.cos(rad) * (self.taegeuk_radius + 30)
            y = self.center_y + math.sin(rad) * (self.taegeuk_radius + 30)
            spark_alpha = int(100 + pulse * 100)
            pygame.draw.circle(self.rotated_surface,
                               (50, 50, 255, spark_alpha),
                               (int(x), int(y)), 3)

        screen.blit(self.glow_surface, (0, 0), special_flags=pygame.BLEND_ADD)
        screen.blit(self.rotated_surface, (0, 0), special_flags=pygame.BLEND_ADD)

        self.grid_surface.fill(self._transparent)
        for particle in self.grid_particles:
            alpha = int(100 * (1 - (particle['y'] - self.height // 2) / (self.height // 2)))
            if alpha > 0:
                pygame.draw.circle(self.grid_surface,
                                   (25, 25, 150, alpha),
                                   (int(particle['x']), int(particle['y'])),
                                   particle['size'])

        screen.blit(self.grid_surface, (0, 0), special_flags=pygame.BLEND_ADD)

        if int(self.time / 1000) % 3 == 0:
            flash_alpha = int(abs(math.sin(self.time * 0.01)) * 20)
            self.flash_surface.fill(self._transparent)
            pygame.draw.circle(self.flash_surface,
                               (10, 10, 10, flash_alpha),
                               (self.center_x, self.center_y),
                               self.taegeuk_radius + 10)
            screen.blit(self.flash_surface, (0, 0), special_flags=pygame.BLEND_ADD)
