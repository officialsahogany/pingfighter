#!/usr/bin/env python3
"""
울트라 프리미엄 네온 전광판 미리보기 - V3
최고급 퀄리티 10종 컬렉션
"""
import pygame
import math
import random
import sys

# 초기화
pygame.init()
WIDTH, HEIGHT = 1400, 900
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("울트라 프리미엄 전광판 V3 - 10종")
clock = pygame.time.Clock()

animation_frame = 0


# ========== 1. Holographic Diamond (홀로그래픽 다이아몬드) ==========
def draw_holographic_diamond(surface, p_score, b_score, x, y, w, h, frame):
    """다이아몬드 프리즘 홀로그램 효과"""
    # 깊은 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    for row in range(h):
        ratio = row / h
        r = int(10 + 15 * ratio)
        g = int(15 + 20 * ratio)
        b_col = int(35 + 25 * ratio)
        pygame.draw.line(bg, (r, g, b_col, 250), (0, row), (w, row))
    surface.blit(bg, (x, y))

    # 프리즘 무지개 반사
    prism_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for i in range(8):
        angle = frame * 0.02 + i * math.pi / 4
        cx = w // 2 + math.cos(angle) * 60
        cy = h // 2 + math.sin(angle) * 30

        hue = (frame * 2 + i * 45) % 360
        color = hsv_to_rgb(hue, 0.8, 1.0)

        for g_layer in range(4, 0, -1):
            size = 40 + g_layer * 15
            alpha = 40 // g_layer
            glow = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow, (*color, alpha), (size, size), size)
            prism_surf.blit(glow, (cx - size, cy - size))

    surface.blit(prism_surf, (x, y))

    # 다이아몬드 컷 패턴
    center_x, center_y = x + w // 2, y + h // 2
    for ring in range(3):
        points = []
        base_size = 50 + ring * 25
        for angle in range(0, 360, 30):
            rad = math.radians(angle + frame * (0.5 if ring % 2 == 0 else -0.5))
            dist = base_size + 5 * math.sin(rad * 6 + frame * 0.1)
            px = center_x + dist * math.cos(rad)
            py = center_y + dist * math.sin(rad) * 0.6
            points.append((px, py))

        if len(points) > 2:
            hue = (frame + ring * 40) % 360
            color = hsv_to_rgb(hue, 0.6, 1.0)
            pygame.draw.polygon(surface, (*color, 100), points, 2)

    # 스파클 효과
    random.seed(42)
    for _ in range(25):
        sx = x + random.randint(10, w - 10)
        sy = y + random.randint(10, h - 10)
        sparkle_phase = math.sin(frame * 0.15 + sx * 0.05 + sy * 0.05)
        if sparkle_phase > 0.6:
            size = int(2 + 3 * sparkle_phase)
            # 십자 스파클
            alpha = int(200 * sparkle_phase)
            spark_surf = pygame.Surface((size * 6, size * 6), pygame.SRCALPHA)
            pygame.draw.line(spark_surf, (255, 255, 255, alpha),
                           (size * 3 - size, size * 3), (size * 3 + size, size * 3), 2)
            pygame.draw.line(spark_surf, (255, 255, 255, alpha),
                           (size * 3, size * 3 - size), (size * 3, size * 3 + size), 2)
            surface.blit(spark_surf, (sx - size * 3, sy - size * 3))

    # 홀로그래픽 테두리
    for i in range(4, 0, -1):
        hue = (frame * 3 + i * 30) % 360
        color = hsv_to_rgb(hue, 0.7, 1.0)
        border = pygame.Surface((w + i * 6, h + i * 6), pygame.SRCALPHA)
        pygame.draw.rect(border, (*color, 50 // i), (0, 0, w + i * 6, h + i * 6),
                        width=2, border_radius=12)
        surface.blit(border, (x - i * 3, y - i * 3))

    draw_luxury_score(surface, p_score, b_score, x, y, w, h, frame, "rainbow")
    draw_title(surface, "DIAMOND", x + w // 2, y + h - 22, frame, "rainbow")


# ========== 2. Cyber Tokyo (사이버 도쿄) ==========
def draw_cyber_tokyo(surface, p_score, b_score, x, y, w, h, frame):
    """일본 네온 사인 + 사이버펑크"""
    # 다크 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    pygame.draw.rect(bg, (15, 5, 25, 250), (0, 0, w, h), border_radius=8)
    surface.blit(bg, (x, y))

    # 빗물 효과
    rain_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    random.seed(int(frame / 3))
    for _ in range(40):
        rx = random.randint(0, w)
        ry = (random.randint(0, h * 2) + frame * 8) % (h + 20) - 10
        length = random.randint(8, 20)
        alpha = random.randint(30, 100)
        pygame.draw.line(rain_surf, (150, 200, 255, alpha),
                        (rx, ry), (rx - 2, ry + length), 1)
    surface.blit(rain_surf, (x, y))

    # 네온 간판들
    neon_colors = [(255, 50, 100), (50, 255, 200), (255, 200, 50), (200, 50, 255)]

    for i, color in enumerate(neon_colors):
        nx = x + 20 + i * (w - 40) // 3
        ny = y + 15 + (i % 2) * 10

        # 글로우
        for g in range(4, 0, -1):
            glow = pygame.Surface((50, 25), pygame.SRCALPHA)
            pygame.draw.rect(glow, (*color, 40 // g), (0, 0, 50, 25), border_radius=4)
            surface.blit(glow, (nx - g, ny - g))

        # 깜빡임
        if (frame + i * 17) % 120 < 110:
            pygame.draw.rect(surface, color, (nx, ny, 45, 18), border_radius=3)

    # 일본어 스타일 세로 텍스트 라인
    for line_x in [x + 15, x + w - 15]:
        for dot_y in range(0, h, 12):
            phase = math.sin(frame * 0.05 + dot_y * 0.1)
            if phase > 0:
                alpha = int(100 + 100 * phase)
                pygame.draw.circle(surface, (255, 50, 150, alpha),
                                 (line_x, y + dot_y), 2)

    # 스캔라인
    for scan_y in range(0, h, 4):
        alpha = int(20 + 10 * math.sin(frame * 0.1 + scan_y * 0.2))
        pygame.draw.line(surface, (255, 255, 255, alpha),
                        (x, y + scan_y), (x + w, y + scan_y))

    # 테두리 - 이중 네온
    pygame.draw.rect(surface, (255, 50, 150), (x, y, w, h), width=2, border_radius=8)
    pygame.draw.rect(surface, (50, 255, 200), (x + 4, y + 4, w - 8, h - 8),
                    width=1, border_radius=6)

    draw_luxury_score(surface, p_score, b_score, x, y, w, h, frame, "neon_pink")
    draw_title(surface, "TOKYO", x + w // 2, y + h - 22, frame, "neon_pink")


# ========== 3. Royal Gold (로열 골드) ==========
def draw_royal_gold(surface, p_score, b_score, x, y, w, h, frame):
    """고급 황금 럭셔리"""
    # 깊은 버건디 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    for row in range(h):
        ratio = row / h
        r = int(40 + 20 * ratio)
        g = int(10 + 5 * ratio)
        b_col = int(15 + 10 * ratio)
        pygame.draw.line(bg, (r, g, b_col, 250), (0, row), (w, row))
    surface.blit(bg, (x, y))

    # 금박 파티클
    gold_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    random.seed(42)
    for _ in range(30):
        gx = random.randint(5, w - 5)
        gy = random.randint(5, h - 5)
        float_y = math.sin(frame * 0.03 + gx * 0.1) * 3
        shimmer = 0.5 + 0.5 * math.sin(frame * 0.08 + gx * 0.05 + gy * 0.05)

        if shimmer > 0.3:
            size = int(1 + 2 * shimmer)
            gold_color = (255, int(200 + 55 * shimmer), int(100 * shimmer))
            alpha = int(150 * shimmer)
            pygame.draw.circle(gold_surf, (*gold_color, alpha),
                             (gx, int(gy + float_y)), size)
    surface.blit(gold_surf, (x, y))

    # 황금 장식 라인
    ornament_y = y + 35
    for ox in range(0, w, 15):
        wave = math.sin(ox * 0.1 + frame * 0.03) * 5
        shimmer = 0.7 + 0.3 * math.sin(frame * 0.05 + ox * 0.08)
        gold = (255, int(180 + 75 * shimmer), 50)
        pygame.draw.circle(surface, gold, (x + ox, int(ornament_y + wave)), 2)

    ornament_y2 = y + h - 35
    for ox in range(0, w, 15):
        wave = math.sin(ox * 0.1 - frame * 0.03) * 5
        shimmer = 0.7 + 0.3 * math.sin(frame * 0.05 - ox * 0.08)
        gold = (255, int(180 + 75 * shimmer), 50)
        pygame.draw.circle(surface, gold, (x + ox, int(ornament_y2 + wave)), 2)

    # 코너 장식
    corners = [(x + 20, y + 20), (x + w - 20, y + 20),
               (x + 20, y + h - 20), (x + w - 20, y + h - 20)]
    for cx, cy in corners:
        for ring in range(3):
            size = 8 + ring * 4
            shimmer = 0.6 + 0.4 * math.sin(frame * 0.06 + ring)
            gold = (255, int(180 + 75 * shimmer), int(50 + 50 * shimmer))
            pygame.draw.circle(surface, gold, (cx, cy), size, 1)

    # 황금 테두리
    for i in range(3, 0, -1):
        shimmer = 0.7 + 0.3 * math.sin(frame * 0.04 + i * 0.5)
        gold = (255, int(180 + 75 * shimmer), 50)
        alpha = int(120 / i)
        border = pygame.Surface((w + i * 4, h + i * 4), pygame.SRCALPHA)
        pygame.draw.rect(border, (*gold, alpha), (0, 0, w + i * 4, h + i * 4),
                        width=2, border_radius=10)
        surface.blit(border, (x - i * 2, y - i * 2))

    draw_luxury_score(surface, p_score, b_score, x, y, w, h, frame, "gold")
    draw_title(surface, "ROYAL", x + w // 2, y + h - 22, frame, "gold")


# ========== 4. Laser Grid (레이저 그리드) ==========
def draw_laser_grid(surface, p_score, b_score, x, y, w, h, frame):
    """80년대 레이저 그리드 레트로"""
    # 깊은 보라 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    for row in range(h):
        ratio = row / h
        r = int(30 * (1 - ratio))
        g = int(5)
        b_col = int(60 * (1 - ratio) + 20)
        pygame.draw.line(bg, (r, g, b_col, 250), (0, row), (w, row))
    surface.blit(bg, (x, y))

    # 퍼스펙티브 그리드
    grid_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    horizon = h // 2 - 10
    vanish_x = w // 2

    # 수직선 (퍼스펙티브)
    for i in range(-5, 6):
        top_x = vanish_x + i * 8
        bottom_x = vanish_x + i * 60
        alpha = int(150 - abs(i) * 15)
        if alpha > 0:
            pygame.draw.line(grid_surf, (255, 0, 255, alpha),
                           (top_x, horizon), (bottom_x, h), 1)

    # 수평선
    for j in range(6):
        line_y = horizon + (h - horizon) * (j / 5) ** 1.5
        alpha = int(100 + j * 25)
        pygame.draw.line(grid_surf, (0, 255, 255, alpha),
                        (0, line_y), (w, line_y), 1)

    surface.blit(grid_surf, (x, y))

    # 레이저 빔
    laser_x = (frame * 5) % (w + 100) - 50
    if 0 < laser_x < w:
        for g in range(5, 0, -1):
            alpha = 60 // g
            pygame.draw.line(surface, (255, 0, 100, alpha),
                           (x + laser_x - g, y), (x + laser_x - g, y + h), g * 2)
        pygame.draw.line(surface, (255, 200, 255), (x + laser_x, y), (x + laser_x, y + h), 2)

    # 태양 (레트로 선셋)
    sun_y = y + horizon - 25
    sun_x = x + w // 2
    for ring in range(20, 0, -1):
        ratio = ring / 20
        r = 255
        g = int(50 + 150 * (1 - ratio))
        b_col = int(200 * (1 - ratio))
        pygame.draw.circle(surface, (r, g, b_col), (sun_x, sun_y), ring + 10)

    # 태양 줄무늬
    for stripe in range(4):
        stripe_y = sun_y + 5 + stripe * 6
        if stripe_y < y + horizon:
            pygame.draw.line(surface, (30, 5, 60), (sun_x - 30, stripe_y), (sun_x + 30, stripe_y), 3)

    # 네온 테두리
    for i in range(3, 0, -1):
        pulse = 0.7 + 0.3 * math.sin(frame * 0.08)
        border = pygame.Surface((w + i * 6, h + i * 6), pygame.SRCALPHA)
        pygame.draw.rect(border, (255, 0, int(255 * pulse), 60 // i),
                        (0, 0, w + i * 6, h + i * 6), width=2, border_radius=8)
        surface.blit(border, (x - i * 3, y - i * 3))

    draw_luxury_score(surface, p_score, b_score, x, y, w, h, frame, "retro")
    draw_title(surface, "LASER", x + w // 2, y + h - 22, frame, "retro")


# ========== 5. Ice Crystal (아이스 크리스탈) ==========
def draw_ice_crystal(surface, p_score, b_score, x, y, w, h, frame):
    """얼음 결정 + 서리 효과"""
    # 차가운 블루 그라데이션
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    for row in range(h):
        ratio = row / h
        r = int(20 + 30 * ratio)
        g = int(40 + 60 * ratio)
        b_col = int(80 + 80 * ratio)
        pygame.draw.line(bg, (r, g, b_col, 250), (0, row), (w, row))
    surface.blit(bg, (x, y))

    # 눈 결정 패턴
    crystal_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    random.seed(42)
    for _ in range(8):
        cx = random.randint(30, w - 30)
        cy = random.randint(30, h - 30)
        size = random.randint(15, 35)
        rotation = frame * 0.02 + cx * 0.1

        # 6각형 눈송이
        for arm in range(6):
            angle = rotation + arm * math.pi / 3
            end_x = cx + size * math.cos(angle)
            end_y = cy + size * math.sin(angle)

            alpha = int(80 + 40 * math.sin(frame * 0.05 + arm))
            pygame.draw.line(crystal_surf, (200, 230, 255, alpha),
                           (cx, cy), (end_x, end_y), 2)

            # 가지
            for branch in [0.4, 0.7]:
                bx = cx + size * branch * math.cos(angle)
                by = cy + size * branch * math.sin(angle)
                for side in [-1, 1]:
                    branch_angle = angle + side * math.pi / 4
                    branch_len = size * 0.3
                    bex = bx + branch_len * math.cos(branch_angle)
                    bey = by + branch_len * math.sin(branch_angle)
                    pygame.draw.line(crystal_surf, (180, 220, 255, alpha // 2),
                                   (bx, by), (bex, bey), 1)

    surface.blit(crystal_surf, (x, y))

    # 서리 텍스처
    frost_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for _ in range(100):
        fx = random.randint(0, w)
        fy = random.randint(0, h)
        sparkle = 0.3 + 0.7 * random.random()
        size = 1 if sparkle < 0.7 else 2
        alpha = int(100 * sparkle)
        pygame.draw.circle(frost_surf, (220, 240, 255, alpha), (fx, fy), size)
    surface.blit(frost_surf, (x, y))

    # 빛 반사
    reflection_x = int((frame * 2) % (w + 60)) - 30
    if 0 < reflection_x < w:
        for g in range(4, 0, -1):
            alpha = 40 // g
            ref_surf = pygame.Surface((30, h), pygame.SRCALPHA)
            for ry in range(h):
                line_alpha = int(alpha * (1 - abs(ry - h // 2) / (h // 2)))
                if line_alpha > 0:
                    pygame.draw.line(ref_surf, (255, 255, 255, line_alpha),
                                   (15 - g, ry), (15 + g, ry))
            surface.blit(ref_surf, (x + reflection_x - 15, y))

    # 얼음 테두리
    for i in range(3, 0, -1):
        shimmer = 0.6 + 0.4 * math.sin(frame * 0.05 + i)
        color = (int(150 + 50 * shimmer), int(200 + 55 * shimmer), 255)
        border = pygame.Surface((w + i * 6, h + i * 6), pygame.SRCALPHA)
        pygame.draw.rect(border, (*color, 70 // i), (0, 0, w + i * 6, h + i * 6),
                        width=2, border_radius=10)
        surface.blit(border, (x - i * 3, y - i * 3))

    draw_luxury_score(surface, p_score, b_score, x, y, w, h, frame, "ice")
    draw_title(surface, "CRYSTAL", x + w // 2, y + h - 22, frame, "ice")


# ========== 6. Neon Vegas (네온 베가스) ==========
def draw_neon_vegas(surface, p_score, b_score, x, y, w, h, frame):
    """라스베가스 카지노 스타일"""
    # 검은 배경
    pygame.draw.rect(surface, (5, 5, 15), (x, y, w, h), border_radius=10)

    # 전구 체이스 애니메이션
    bulb_colors = [(255, 220, 50), (255, 100, 50), (255, 50, 100), (50, 255, 150)]

    # 상단 전구 라인
    for i in range(0, w, 12):
        bulb_phase = (frame * 0.2 + i * 0.3) % (len(bulb_colors) * 2)
        color_idx = int(bulb_phase) % len(bulb_colors)
        brightness = 0.5 + 0.5 * (1 - abs(bulb_phase % 2 - 1))

        color = tuple(int(c * brightness) for c in bulb_colors[color_idx])
        bx, by = x + i + 6, y + 8

        # 글로우
        for g in range(3, 0, -1):
            glow = pygame.Surface((16, 16), pygame.SRCALPHA)
            pygame.draw.circle(glow, (*color, 50 // g), (8, 8), 4 + g)
            surface.blit(glow, (bx - 8, by - 8))

        pygame.draw.circle(surface, color, (bx, by), 4)

    # 하단 전구 라인
    for i in range(0, w, 12):
        bulb_phase = (-frame * 0.2 + i * 0.3) % (len(bulb_colors) * 2)
        color_idx = int(bulb_phase) % len(bulb_colors)
        brightness = 0.5 + 0.5 * (1 - abs(bulb_phase % 2 - 1))

        color = tuple(int(c * brightness) for c in bulb_colors[color_idx])
        bx, by = x + i + 6, y + h - 8

        for g in range(3, 0, -1):
            glow = pygame.Surface((16, 16), pygame.SRCALPHA)
            pygame.draw.circle(glow, (*color, 50 // g), (8, 8), 4 + g)
            surface.blit(glow, (bx - 8, by - 8))

        pygame.draw.circle(surface, color, (bx, by), 4)

    # 측면 전구
    for i in range(0, h, 12):
        for side, sx in [(1, x + 8), (-1, x + w - 8)]:
            bulb_phase = (frame * 0.15 * side + i * 0.2) % (len(bulb_colors) * 2)
            color_idx = int(bulb_phase) % len(bulb_colors)
            brightness = 0.5 + 0.5 * (1 - abs(bulb_phase % 2 - 1))

            color = tuple(int(c * brightness) for c in bulb_colors[color_idx])
            by = y + i + 6

            pygame.draw.circle(surface, color, (sx, by), 3)

    # 중앙 스포트라이트 효과
    spot_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    spot_x = w // 2 + int(30 * math.sin(frame * 0.03))
    spot_y = h // 2

    for g in range(30, 0, -2):
        alpha = int(3)
        pygame.draw.circle(spot_surf, (255, 255, 200, alpha),
                          (spot_x, spot_y), g + 20)
    surface.blit(spot_surf, (x, y))

    # 네온 프레임
    pygame.draw.rect(surface, (255, 220, 50), (x, y, w, h), width=3, border_radius=10)
    pygame.draw.rect(surface, (255, 100, 150), (x + 5, y + 5, w - 10, h - 10),
                    width=2, border_radius=8)

    draw_luxury_score(surface, p_score, b_score, x, y, w, h, frame, "vegas")
    draw_title(surface, "VEGAS", x + w // 2, y + h - 22, frame, "vegas")


# ========== 7. Deep Space (딥 스페이스) ==========
def draw_deep_space(surface, p_score, b_score, x, y, w, h, frame):
    """우주 성운 + 은하 효과"""
    # 우주 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    for row in range(h):
        for col in range(0, w, 2):
            noise = (math.sin(col * 0.02 + row * 0.02 + frame * 0.01) +
                    math.sin(col * 0.01 - row * 0.015)) / 2
            intensity = 0.5 + 0.5 * noise

            r = int(10 + 20 * intensity * (1 + math.sin(col * 0.005)))
            g = int(5 + 15 * intensity)
            b_col = int(30 + 40 * intensity)
            pygame.draw.rect(bg, (r, g, b_col), (col, row, 2, 1))
    surface.blit(bg, (x, y))

    # 성운 효과
    nebula_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    nebula_colors = [(100, 50, 150), (50, 100, 150), (150, 50, 100)]

    for color in nebula_colors:
        for _ in range(15):
            nx = random.randint(0, w)
            ny = random.randint(0, h)
            size = random.randint(30, 80)

            for g in range(5, 0, -1):
                alpha = 15 // g
                glow = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow, (*color, alpha), (size, size), size - (5 - g) * 10)
                nebula_surf.blit(glow, (nx - size, ny - size))

    surface.blit(nebula_surf, (x, y))

    # 별들
    random.seed(42)
    for _ in range(80):
        sx = x + random.randint(0, w)
        sy = y + random.randint(0, h)
        twinkle = abs(math.sin(frame * 0.08 + sx * 0.1 + sy * 0.1))
        if twinkle > 0.3:
            size = 1 if twinkle < 0.7 else 2
            alpha = int(100 + 155 * twinkle)
            pygame.draw.circle(surface, (255, 255, 255), (sx, sy), size)

    # 슈팅스타
    if frame % 180 < 30:
        progress = (frame % 180) / 30
        star_x = x + int(w * 0.2 + w * 0.6 * progress)
        star_y = y + int(h * 0.1 + h * 0.3 * progress)

        for trail in range(10):
            trail_x = star_x - trail * 4
            trail_y = star_y - trail * 2
            alpha = int(255 * (1 - trail / 10))
            if alpha > 0:
                pygame.draw.circle(surface, (255, 255, 255, alpha),
                                 (trail_x, trail_y), 3 - trail // 4)

    # 은하 중심
    center_x, center_y = x + w // 2, y + h // 2
    for ring in range(4):
        ring_size = 30 + ring * 15
        rotation = frame * 0.01 * (1 if ring % 2 == 0 else -1)

        for dot in range(20):
            angle = rotation + dot * math.pi * 2 / 20
            dist = ring_size + 5 * math.sin(dot + frame * 0.05)
            dx = center_x + dist * math.cos(angle)
            dy = center_y + dist * math.sin(angle) * 0.4

            alpha = int(80 + 50 * math.sin(dot + frame * 0.03))
            pygame.draw.circle(surface, (150, 180, 255),
                             (int(dx), int(dy)), 1)

    # 테두리
    for i in range(3, 0, -1):
        pulse = 0.6 + 0.4 * math.sin(frame * 0.04)
        color = (int(100 * pulse), int(150 * pulse), int(255 * pulse))
        border = pygame.Surface((w + i * 6, h + i * 6), pygame.SRCALPHA)
        pygame.draw.rect(border, (*color, 50 // i), (0, 0, w + i * 6, h + i * 6),
                        width=2, border_radius=10)
        surface.blit(border, (x - i * 3, y - i * 3))

    draw_luxury_score(surface, p_score, b_score, x, y, w, h, frame, "space")
    draw_title(surface, "SPACE", x + w // 2, y + h - 22, frame, "space")


# ========== 8. Electric Storm (일렉트릭 스톰) ==========
def draw_electric_storm(surface, p_score, b_score, x, y, w, h, frame):
    """번개 폭풍 + 전기 효과"""
    # 폭풍 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    storm_intensity = 0.5 + 0.5 * math.sin(frame * 0.02)
    for row in range(h):
        ratio = row / h
        r = int(15 + 25 * storm_intensity * ratio)
        g = int(15 + 30 * storm_intensity * ratio)
        b_col = int(30 + 50 * storm_intensity * ratio)
        pygame.draw.line(bg, (r, g, b_col, 250), (0, row), (w, row))
    surface.blit(bg, (x, y))

    # 구름 패턴
    cloud_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for _ in range(10):
        cx = random.randint(0, w)
        cy = random.randint(0, h // 3)
        cloud_size = random.randint(40, 80)

        for _ in range(5):
            offset_x = random.randint(-20, 20)
            offset_y = random.randint(-10, 10)
            size = random.randint(15, 30)
            pygame.draw.circle(cloud_surf, (40, 45, 60, 60),
                             (cx + offset_x, cy + offset_y), size)
    surface.blit(cloud_surf, (x, y))

    # 번개
    random.seed(int(frame / 8))
    if random.random() > 0.7:
        lightning_start = (x + random.randint(w // 4, 3 * w // 4), y + 10)
        lightning_end = (lightning_start[0] + random.randint(-50, 50), y + h - 10)

        points = [lightning_start]
        segments = random.randint(5, 8)
        for i in range(1, segments):
            t = i / segments
            mid_x = lightning_start[0] + (lightning_end[0] - lightning_start[0]) * t
            mid_y = lightning_start[1] + (lightning_end[1] - lightning_start[1]) * t
            mid_x += random.randint(-30, 30)
            points.append((mid_x, mid_y))
        points.append(lightning_end)

        # 글로우
        for glow in range(5, 0, -1):
            for i in range(len(points) - 1):
                alpha = 100 // glow
                pygame.draw.line(surface, (180, 200, 255, alpha),
                               points[i], points[i + 1], glow * 3)

        # 메인 번개
        for i in range(len(points) - 1):
            pygame.draw.line(surface, (220, 240, 255), points[i], points[i + 1], 2)

        # 분기
        for i in range(1, len(points) - 1):
            if random.random() > 0.5:
                branch_end = (points[i][0] + random.randint(-40, 40),
                            points[i][1] + random.randint(20, 50))
                pygame.draw.line(surface, (200, 220, 255), points[i], branch_end, 1)

    # 전기 스파크 (테두리)
    for _ in range(8):
        if random.random() > 0.6:
            side = random.choice(['top', 'bottom', 'left', 'right'])
            if side == 'top':
                sx, sy = x + random.randint(0, w), y
            elif side == 'bottom':
                sx, sy = x + random.randint(0, w), y + h
            elif side == 'left':
                sx, sy = x, y + random.randint(0, h)
            else:
                sx, sy = x + w, y + random.randint(0, h)

            for _ in range(3):
                ex = sx + random.randint(-15, 15)
                ey = sy + random.randint(-15, 15)
                pygame.draw.line(surface, (200, 220, 255), (sx, sy), (ex, ey), 1)

    # 테두리
    pulse = 0.5 + 0.5 * math.sin(frame * 0.1)
    for i in range(3, 0, -1):
        color = (int(100 + 100 * pulse), int(150 + 50 * pulse), 255)
        border = pygame.Surface((w + i * 6, h + i * 6), pygame.SRCALPHA)
        pygame.draw.rect(border, (*color, 60 // i), (0, 0, w + i * 6, h + i * 6),
                        width=2, border_radius=10)
        surface.blit(border, (x - i * 3, y - i * 3))

    draw_luxury_score(surface, p_score, b_score, x, y, w, h, frame, "electric")
    draw_title(surface, "STORM", x + w // 2, y + h - 22, frame, "electric")


# ========== 9. Neon Circuit (네온 서킷) ==========
def draw_neon_circuit(surface, p_score, b_score, x, y, w, h, frame):
    """전자 회로 + PCB 스타일"""
    # PCB 그린 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    pygame.draw.rect(bg, (5, 30, 20, 250), (0, 0, w, h), border_radius=8)
    surface.blit(bg, (x, y))

    # 회로 패턴
    circuit_surf = pygame.Surface((w, h), pygame.SRCALPHA)

    # 수평 라인
    for i in range(5):
        ly = 25 + i * (h - 50) // 4
        pygame.draw.line(circuit_surf, (20, 80, 50, 150), (10, ly), (w - 10, ly), 2)

        # 노드 포인트
        for j in range(4):
            nx = 30 + j * (w - 60) // 3
            pygame.draw.circle(circuit_surf, (50, 150, 80), (nx, ly), 4)
            pygame.draw.circle(circuit_surf, (100, 255, 150), (nx, ly), 2)

    # 수직 연결
    for i in range(4):
        lx = 30 + i * (w - 60) // 3
        pygame.draw.line(circuit_surf, (20, 80, 50, 150), (lx, 25), (lx, h - 25), 2)

    surface.blit(circuit_surf, (x, y))

    # 데이터 흐름 애니메이션
    flow_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for i in range(5):
        ly = 25 + i * (h - 50) // 4
        flow_x = (frame * 3 + i * 40) % (w - 20)

        for g in range(4, 0, -1):
            alpha = 100 // g
            pygame.draw.circle(flow_surf, (100, 255, 150, alpha),
                             (flow_x + 10, ly), 3 + g)
        pygame.draw.circle(flow_surf, (150, 255, 200), (flow_x + 10, ly), 3)

    surface.blit(flow_surf, (x, y))

    # LED 인디케이터
    led_colors = [(255, 50, 50), (50, 255, 50), (50, 150, 255)]
    for i, color in enumerate(led_colors):
        lx = x + 25 + i * 25
        ly = y + h - 20

        blink = (frame + i * 30) % 60 < 45
        if blink:
            for g in range(3, 0, -1):
                glow = pygame.Surface((16, 16), pygame.SRCALPHA)
                pygame.draw.circle(glow, (*color, 80 // g), (8, 8), 4 + g)
                surface.blit(glow, (lx - 8, ly - 8))
            pygame.draw.circle(surface, color, (lx, ly), 4)
        else:
            pygame.draw.circle(surface, tuple(c // 3 for c in color), (lx, ly), 4)

    # 테두리
    pygame.draw.rect(surface, (50, 150, 80), (x, y, w, h), width=2, border_radius=8)
    pygame.draw.rect(surface, (100, 255, 150), (x + 3, y + 3, w - 6, h - 6),
                    width=1, border_radius=6)

    draw_luxury_score(surface, p_score, b_score, x, y, w, h, frame, "circuit")
    draw_title(surface, "CIRCUIT", x + w // 2, y + h - 22, frame, "circuit")


# ========== 10. Aurora Wave (오로라 웨이브) ==========
def draw_aurora_wave(surface, p_score, b_score, x, y, w, h, frame):
    """부드러운 오로라 파동"""
    # 깊은 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    for row in range(h):
        ratio = row / h
        r = int(5 + 10 * ratio)
        g = int(10 + 15 * ratio)
        b_col = int(25 + 20 * ratio)
        pygame.draw.line(bg, (r, g, b_col, 250), (0, row), (w, row))
    surface.blit(bg, (x, y))

    # 오로라 웨이브
    aurora_colors = [
        (80, 255, 180),   # 민트
        (120, 200, 255),  # 하늘
        (180, 120, 255),  # 보라
        (255, 150, 200),  # 핑크
        (100, 255, 220),  # 청록
    ]

    wave_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for wave_idx in range(5):
        points_top = []
        points_bottom = []
        base_y = h // 2

        for px in range(w + 1):
            wave1 = math.sin(px * 0.02 + frame * 0.03 + wave_idx * 0.5) * 25
            wave2 = math.sin(px * 0.01 + frame * 0.02 - wave_idx * 0.3) * 15
            wave3 = math.sin(px * 0.005 + frame * 0.01) * 10
            total_wave = wave1 + wave2 + wave3

            y_pos = base_y + total_wave + wave_idx * 8 - 20
            points_top.append((px, y_pos - 20))
            points_bottom.append((px, y_pos + 20))

        # 오로라 밴드 그리기
        color = aurora_colors[wave_idx % len(aurora_colors)]
        phase = math.sin(frame * 0.02 + wave_idx * 0.5)
        alpha = int(40 + 30 * phase)

        # 상단 글로우
        for i, (pt, pb) in enumerate(zip(points_top, points_bottom)):
            if i < len(points_top) - 1:
                pt_next = points_top[i + 1]
                pb_next = points_bottom[i + 1]

                band_alpha = int(alpha * (0.5 + 0.5 * math.sin(i * 0.05 + frame * 0.02)))
                if band_alpha > 10:
                    quad_points = [pt, pt_next, pb_next, pb]
                    try:
                        pygame.draw.polygon(wave_surf, (*color, band_alpha), quad_points)
                    except:
                        pass

    surface.blit(wave_surf, (x, y))

    # 반짝이는 별
    random.seed(42)
    for _ in range(15):
        sx = random.randint(5, w - 5)
        sy = random.randint(5, h - 5)
        twinkle = abs(math.sin(frame * 0.1 + sx * 0.1 + sy * 0.1))
        if twinkle > 0.7:
            size = int(1 + 2 * twinkle)
            alpha = int(150 + 105 * twinkle)
            star = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
            pygame.draw.circle(star, (255, 255, 255, alpha), (size * 2, size * 2), size)
            surface.blit(star, (x + sx - size * 2, y + sy - size * 2))

    # 테두리
    for i in range(4, 0, -1):
        hue = (frame * 2 + i * 30) % 360
        color = hsv_to_rgb(hue, 0.5, 1.0)
        border = pygame.Surface((w + i * 4, h + i * 4), pygame.SRCALPHA)
        pygame.draw.rect(border, (*color, 40 // i), (0, 0, w + i * 4, h + i * 4),
                        width=2, border_radius=12)
        surface.blit(border, (x - i * 2, y - i * 2))

    draw_luxury_score(surface, p_score, b_score, x, y, w, h, frame, "aurora")
    draw_title(surface, "AURORA", x + w // 2, y + h - 22, frame, "aurora")


# ========== 헬퍼 함수들 ==========

def hsv_to_rgb(h, s, v):
    """HSV to RGB 변환"""
    h = h % 360
    c = v * s
    x = c * (1 - abs((h / 60) % 2 - 1))
    m = v - c

    if h < 60:
        r, g, b = c, x, 0
    elif h < 120:
        r, g, b = x, c, 0
    elif h < 180:
        r, g, b = 0, c, x
    elif h < 240:
        r, g, b = 0, x, c
    elif h < 300:
        r, g, b = x, 0, c
    else:
        r, g, b = c, 0, x

    return (int((r + m) * 255), int((g + m) * 255), int((b + m) * 255))


def draw_luxury_score(surface, p_score, b_score, x, y, w, h, frame, style="default"):
    """럭셔리 점수 표시"""
    try:
        font = pygame.font.SysFont("Arial", 64, bold=True)
        small_font = pygame.font.SysFont("Arial", 18, bold=True)
    except:
        font = pygame.font.Font(None, 72)
        small_font = pygame.font.Font(None, 22)

    center_x = x + w // 2
    score_y = y + h // 2 - 12

    # 스타일별 색상
    color_schemes = {
        "rainbow": lambda f: (hsv_to_rgb((f * 2) % 360, 0.7, 1.0),
                             hsv_to_rgb((f * 2 + 180) % 360, 0.7, 1.0)),
        "neon_pink": lambda f: ((255, 150, 200), (255, 80, 150)),
        "gold": lambda f: ((255, 220, 100), (255, 180, 50)),
        "retro": lambda f: ((255, 100, 200), (100, 255, 255)),
        "ice": lambda f: ((180, 220, 255), (100, 180, 255)),
        "vegas": lambda f: ((255, 220, 50), (255, 100, 150)),
        "space": lambda f: ((150, 200, 255), (200, 150, 255)),
        "electric": lambda f: ((200, 220, 255), (150, 200, 255)),
        "circuit": lambda f: ((100, 255, 150), (50, 200, 100)),
        "aurora": lambda f: (hsv_to_rgb((f + 120) % 360, 0.6, 1.0),
                            hsv_to_rgb((f + 240) % 360, 0.6, 1.0)),
        "default": lambda f: ((255, 255, 255), (200, 200, 200))
    }

    p_color, b_color = color_schemes.get(style, color_schemes["default"])(frame)

    # 플레이어 점수
    p_text = font.render(str(p_score), True, p_color)
    p_x = center_x - 55 - p_text.get_width() // 2

    for g in range(3, 0, -1):
        glow = font.render(str(p_score), True, p_color)
        glow.set_alpha(60 // g)
        surface.blit(glow, (p_x - g, score_y - g))
    surface.blit(p_text, (p_x, score_y))

    # VS
    vs = small_font.render("VS", True, (180, 180, 180))
    surface.blit(vs, (center_x - vs.get_width() // 2, score_y + 20))

    # 보스 점수
    b_text = font.render(str(b_score), True, b_color)
    b_x = center_x + 55 - b_text.get_width() // 2

    for g in range(3, 0, -1):
        glow = font.render(str(b_score), True, b_color)
        glow.set_alpha(60 // g)
        surface.blit(glow, (b_x - g, score_y - g))
    surface.blit(b_text, (b_x, score_y))


def draw_title(surface, text, x, y, frame, style="default"):
    """타이틀 텍스트"""
    try:
        font = pygame.font.SysFont("Arial", 16, bold=True)
    except:
        font = pygame.font.Font(None, 20)

    color_map = {
        "rainbow": hsv_to_rgb((frame * 3) % 360, 0.7, 1.0),
        "neon_pink": (255, 100, 180),
        "gold": (255, 200, 100),
        "retro": (255, 100, 255),
        "ice": (180, 220, 255),
        "vegas": (255, 200, 100),
        "space": (150, 180, 255),
        "electric": (180, 200, 255),
        "circuit": (100, 255, 150),
        "aurora": hsv_to_rgb((frame * 2 + 60) % 360, 0.6, 1.0),
        "default": (200, 200, 200)
    }

    color = color_map.get(style, (200, 200, 200))
    text_surf = font.render(text, True, color)
    text_x = x - text_surf.get_width() // 2

    for g in range(2, 0, -1):
        glow = font.render(text, True, color)
        glow.set_alpha(80 // g)
        surface.blit(glow, (text_x - g, y - g))

    surface.blit(text_surf, (text_x, y))


# 스타일 목록
STYLES = [
    ("1. Holographic Diamond", draw_holographic_diamond),
    ("2. Cyber Tokyo", draw_cyber_tokyo),
    ("3. Royal Gold", draw_royal_gold),
    ("4. Laser Grid", draw_laser_grid),
    ("5. Ice Crystal", draw_ice_crystal),
    ("6. Neon Vegas", draw_neon_vegas),
    ("7. Deep Space", draw_deep_space),
    ("8. Electric Storm", draw_electric_storm),
    ("9. Neon Circuit", draw_neon_circuit),
    ("10. Aurora Wave", draw_aurora_wave),
]


def main():
    global animation_frame

    current_style = 0
    p_score = 7
    b_score = 5

    try:
        title_font = pygame.font.SysFont("Arial", 26, bold=True)
        info_font = pygame.font.SysFont("Arial", 16)
    except:
        title_font = pygame.font.Font(None, 30)
        info_font = pygame.font.Font(None, 20)

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_1:
                    current_style = 0
                elif event.key == pygame.K_2:
                    current_style = 1
                elif event.key == pygame.K_3:
                    current_style = 2
                elif event.key == pygame.K_4:
                    current_style = 3
                elif event.key == pygame.K_5:
                    current_style = 4
                elif event.key == pygame.K_6:
                    current_style = 5
                elif event.key == pygame.K_7:
                    current_style = 6
                elif event.key == pygame.K_8:
                    current_style = 7
                elif event.key == pygame.K_9:
                    current_style = 8
                elif event.key == pygame.K_0:
                    current_style = 9
                elif event.key == pygame.K_LEFT:
                    current_style = (current_style - 1) % len(STYLES)
                elif event.key == pygame.K_RIGHT:
                    current_style = (current_style + 1) % len(STYLES)

        screen.fill((10, 10, 20))

        style_name, style_func = STYLES[current_style]

        # 메인 프리뷰
        style_func(screen, p_score, b_score,
                   WIDTH // 2 - 225, 120, 450, 180, animation_frame)

        # 타이틀
        title = title_font.render("Ultra Premium Scoreboard Collection", True, (255, 255, 255))
        screen.blit(title, (WIDTH // 2 - title.get_width() // 2, 25))

        # 현재 스타일
        style_text = title_font.render(style_name, True, (100, 200, 255))
        screen.blit(style_text, (WIDTH // 2 - style_text.get_width() // 2, 70))

        # 미니 프리뷰 (2줄 5개씩)
        preview_w, preview_h = 130, 60
        for row in range(2):
            for col in range(5):
                idx = row * 5 + col
                px = 80 + col * (preview_w + 15)
                py = 340 + row * (preview_h + 25)

                if idx == current_style:
                    pygame.draw.rect(screen, (100, 200, 255),
                                   (px - 4, py - 4, preview_w + 8, preview_h + 8),
                                   width=2, border_radius=6)

                STYLES[idx][1](screen, p_score, b_score, px, py, preview_w, preview_h, animation_frame)

                # 번호
                num = info_font.render(str(idx + 1) if idx < 9 else "0", True, (150, 150, 150))
                screen.blit(num, (px + 5, py + 5))

        # 조작법
        controls = ["1-0: 스타일 선택  |  ←/→: 이전/다음  |  ESC: 종료"]
        for i, ctrl in enumerate(controls):
            ctrl_text = info_font.render(ctrl, True, (120, 120, 120))
            screen.blit(ctrl_text, (WIDTH // 2 - ctrl_text.get_width() // 2, HEIGHT - 40 + i * 20))

        pygame.display.flip()
        animation_frame += 1
        clock.tick(60)

    pygame.quit()


if __name__ == "__main__":
    main()
