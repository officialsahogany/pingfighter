#!/usr/bin/env python3
"""
메탈릭 블루 사이버펑크 전광판 미리보기 - 5가지 스타일
Player vs Boss Name 표시
"""
import pygame
import math
import random
import sys
import os

# 한글 폰트 경로
KOREAN_FONTS = [
    "/System/Library/Fonts/AppleSDGothicNeo.ttc",
    "/Library/Fonts/NanumGothic.ttf",
    "/Library/Fonts/NanumGothicBold.ttf",
    "C:/Windows/Fonts/malgun.ttf",
    "C:/Windows/Fonts/gulim.ttc",
]

def get_korean_font(size):
    """한글 지원 폰트 반환"""
    for font_path in KOREAN_FONTS:
        if os.path.exists(font_path):
            try:
                return pygame.font.Font(font_path, size)
            except:
                continue
    return pygame.font.Font(None, size)


# ===== 스타일 1: 네온 그리드 사이버펑크 =====
def draw_scoreboard_style1(surface, player_score, boss_score, boss_name, x, y, w, h, frame):
    """네온 그리드 사이버펑크 - 홀로그램 그리드 패턴"""

    # 메탈릭 다크 블루 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    for row in range(h):
        ratio = row / h
        r = int(8 + 15 * ratio)
        g = int(15 + 30 * ratio)
        b = int(35 + 50 * ratio)
        pygame.draw.line(bg, (r, g, b, 245), (0, row), (w, row))
    surface.blit(bg, (x, y))

    # 그리드 패턴 (홀로그램)
    grid_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    grid_color = (0, 180, 255, 40)
    for gx in range(0, w, 20):
        pygame.draw.line(grid_surf, grid_color, (gx, 0), (gx, h), 1)
    for gy in range(0, h, 15):
        pygame.draw.line(grid_surf, grid_color, (0, gy), (w, gy), 1)
    surface.blit(grid_surf, (x, y))

    # 스캔라인 효과
    scan_y = (frame * 3) % h
    scan_surf = pygame.Surface((w, 3), pygame.SRCALPHA)
    scan_surf.fill((0, 255, 255, 80))
    surface.blit(scan_surf, (x, y + scan_y))

    # 네온 테두리 (멀티 레이어)
    for i in range(4, 0, -1):
        pulse = 0.6 + 0.4 * math.sin(frame * 0.08 + i * 0.5)
        alpha = int(120 * pulse / i)
        color = (0, int(200 * pulse), 255, alpha)
        border_surf = pygame.Surface((w + i * 4, h + i * 4), pygame.SRCALPHA)
        pygame.draw.rect(border_surf, color, (0, 0, w + i * 4, h + i * 4), 2, border_radius=8)
        surface.blit(border_surf, (x - i * 2, y - i * 2))

    # 코너 액센트
    corner_size = 15
    accent_color = (0, 255, 255)
    # 좌상단
    pygame.draw.line(surface, accent_color, (x, y + corner_size), (x, y), 2)
    pygame.draw.line(surface, accent_color, (x, y), (x + corner_size, y), 2)
    # 우상단
    pygame.draw.line(surface, accent_color, (x + w - corner_size, y), (x + w, y), 2)
    pygame.draw.line(surface, accent_color, (x + w, y), (x + w, y + corner_size), 2)
    # 좌하단
    pygame.draw.line(surface, accent_color, (x, y + h - corner_size), (x, y + h), 2)
    pygame.draw.line(surface, accent_color, (x, y + h), (x + corner_size, y + h), 2)
    # 우하단
    pygame.draw.line(surface, accent_color, (x + w - corner_size, y + h), (x + w, y + h), 2)
    pygame.draw.line(surface, accent_color, (x + w, y + h - corner_size), (x + w, y + h), 2)

    # 점수 및 이름 표시
    draw_cyberpunk_score(surface, player_score, boss_score, boss_name, x, y, w, h, frame,
                        (0, 220, 255), (255, 100, 180), "NEON GRID")


# ===== 스타일 2: 메탈릭 헥사곤 =====
def draw_scoreboard_style2(surface, player_score, boss_score, boss_name, x, y, w, h, frame):
    """메탈릭 헥사곤 - 육각형 패턴 메탈 텍스처"""

    # 메탈릭 그라데이션 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    for row in range(h):
        ratio = row / h
        # 메탈릭 블루
        r = int(25 + 35 * math.sin(ratio * math.pi))
        g = int(45 + 55 * math.sin(ratio * math.pi))
        b = int(85 + 70 * math.sin(ratio * math.pi))
        pygame.draw.line(bg, (r, g, b, 250), (0, row), (w, row))
    surface.blit(bg, (x, y))

    # 헥사곤 패턴
    hex_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    hex_size = 25
    for hx in range(-hex_size, w + hex_size, int(hex_size * 1.5)):
        for hy in range(-hex_size, h + hex_size, int(hex_size * 1.73)):
            offset = hex_size * 0.75 if (hy // int(hex_size * 1.73)) % 2 else 0
            cx, cy = hx + offset, hy

            points = []
            for i in range(6):
                angle = i * math.pi / 3 + math.pi / 6
                px = cx + (hex_size - 3) * math.cos(angle)
                py = cy + (hex_size - 3) * math.sin(angle)
                points.append((px, py))

            pulse = 0.3 + 0.3 * math.sin(frame * 0.03 + hx * 0.05)
            pygame.draw.polygon(hex_surf, (100, 180, 255, int(40 * pulse)), points, 1)

    surface.blit(hex_surf, (x, y))

    # 금속 광택 효과
    shine_x = (frame * 4) % (w + 80) - 40
    if 0 < shine_x < w:
        shine_surf = pygame.Surface((40, h), pygame.SRCALPHA)
        for sx in range(40):
            alpha = int(60 * (1 - abs(sx - 20) / 20))
            pygame.draw.line(shine_surf, (200, 220, 255, alpha), (sx, 0), (sx, h))
        surface.blit(shine_surf, (x + shine_x - 20, y))

    # 메탈 프레임
    frame_color = (120, 160, 200)
    dark_frame = (40, 60, 90)
    pygame.draw.rect(surface, dark_frame, (x - 3, y - 3, w + 6, h + 6), 4, border_radius=6)
    pygame.draw.rect(surface, frame_color, (x - 1, y - 1, w + 2, h + 2), 2, border_radius=5)

    # 볼트/리벳 장식
    bolt_positions = [(x + 10, y + 10), (x + w - 10, y + 10),
                     (x + 10, y + h - 10), (x + w - 10, y + h - 10)]
    for bx, by in bolt_positions:
        pygame.draw.circle(surface, (80, 100, 140), (bx, by), 5)
        pygame.draw.circle(surface, (150, 180, 220), (bx, by), 4)
        pygame.draw.circle(surface, (60, 80, 110), (bx, by), 2)

    draw_cyberpunk_score(surface, player_score, boss_score, boss_name, x, y, w, h, frame,
                        (140, 200, 255), (255, 140, 100), "METALLIC HEX")


# ===== 스타일 3: 플라즈마 웨이브 =====
def draw_scoreboard_style3(surface, player_score, boss_score, boss_name, x, y, w, h, frame):
    """플라즈마 웨이브 - 에너지 파동 효과"""

    # 다크 사이버 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    for row in range(h):
        ratio = row / h
        wave = math.sin(ratio * math.pi * 2 + frame * 0.05) * 0.2
        r = int(12 + 20 * (ratio + wave))
        g = int(20 + 35 * (ratio + wave))
        b = int(50 + 60 * (ratio + wave))
        pygame.draw.line(bg, (r, g, max(0, min(255, b)), 240), (0, row), (w, row))
    surface.blit(bg, (x, y))

    # 플라즈마 웨이브
    wave_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for wave_i in range(3):
        wave_points = []
        for wx in range(0, w, 3):
            wave_y = h // 2 + math.sin(wx * 0.03 + frame * 0.08 + wave_i * 2) * 25
            wave_y += math.sin(wx * 0.05 - frame * 0.06) * 10
            wave_points.append((wx, wave_y))

        if len(wave_points) > 1:
            alpha = 80 - wave_i * 20
            color = (0, 150 + wave_i * 30, 255, alpha)
            pygame.draw.lines(wave_surf, color, False, wave_points, 2)
    surface.blit(wave_surf, (x, y))

    # 에너지 파티클
    random.seed(int(frame * 0.1))
    particle_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for _ in range(15):
        px = random.randint(0, w)
        py = random.randint(0, h)
        psize = random.randint(1, 3)
        palpha = random.randint(100, 200)
        pcolor = random.choice([(0, 200, 255, palpha), (100, 255, 255, palpha), (150, 200, 255, palpha)])
        pygame.draw.circle(particle_surf, pcolor, (px, py), psize)
    surface.blit(particle_surf, (x, y))

    # 플라즈마 테두리
    for i in range(5, 0, -1):
        pulse = 0.5 + 0.5 * math.sin(frame * 0.1 + i * 0.3)
        color = (0, int(180 * pulse), int(255 * pulse), int(100 / i))
        border_surf = pygame.Surface((w + i * 6, h + i * 6), pygame.SRCALPHA)
        pygame.draw.rect(border_surf, color, (0, 0, w + i * 6, h + i * 6), 3, border_radius=10)
        surface.blit(border_surf, (x - i * 3, y - i * 3))

    draw_cyberpunk_score(surface, player_score, boss_score, boss_name, x, y, w, h, frame,
                        (100, 255, 255), (255, 150, 200), "PLASMA WAVE")


# ===== 스타일 4: 홀로그램 글리치 =====
def draw_scoreboard_style4(surface, player_score, boss_score, boss_name, x, y, w, h, frame):
    """홀로그램 글리치 - RGB 분리 글리치 효과"""

    # 홀로그래픽 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    for row in range(h):
        ratio = row / h
        # 홀로그램 색상 변화
        hue_shift = math.sin(ratio * math.pi * 3 + frame * 0.02) * 30
        r = int(15 + 25 * ratio + hue_shift * 0.3)
        g = int(25 + 40 * ratio)
        b = int(55 + 70 * ratio - hue_shift * 0.2)
        pygame.draw.line(bg, (max(0, r), max(0, g), max(0, min(255, b)), 235), (0, row), (w, row))
    surface.blit(bg, (x, y))

    # 글리치 라인
    glitch_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    random.seed(int(frame * 0.3))
    if random.random() > 0.7:
        for _ in range(3):
            gy = random.randint(0, h)
            gw = random.randint(30, 150)
            gx = random.randint(0, w - gw)
            gh = random.randint(2, 6)
            glitch_color = random.choice([(255, 0, 100, 80), (0, 255, 255, 80), (100, 0, 255, 80)])
            pygame.draw.rect(glitch_surf, glitch_color, (gx, gy, gw, gh))
    surface.blit(glitch_surf, (x, y))

    # 스캔라인
    scan_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for sy in range(0, h, 3):
        pygame.draw.line(scan_surf, (0, 0, 0, 30), (0, sy), (w, sy))
    surface.blit(scan_surf, (x, y))

    # 홀로그램 테두리 (RGB 분리)
    offset = int(math.sin(frame * 0.15) * 2)
    # Red
    red_border = pygame.Surface((w + 4, h + 4), pygame.SRCALPHA)
    pygame.draw.rect(red_border, (255, 0, 100, 60), (0, 0, w + 4, h + 4), 2, border_radius=6)
    surface.blit(red_border, (x - 2 - offset, y - 2))
    # Blue
    blue_border = pygame.Surface((w + 4, h + 4), pygame.SRCALPHA)
    pygame.draw.rect(blue_border, (0, 200, 255, 80), (0, 0, w + 4, h + 4), 2, border_radius=6)
    surface.blit(blue_border, (x - 2 + offset, y - 2))
    # White center
    pygame.draw.rect(surface, (200, 220, 255), (x - 1, y - 1, w + 2, h + 2), 1, border_radius=5)

    draw_cyberpunk_score(surface, player_score, boss_score, boss_name, x, y, w, h, frame,
                        (0, 255, 200), (255, 100, 255), "HOLO GLITCH")


# ===== 스타일 5: 테크노 서킷 =====
def draw_scoreboard_style5(surface, player_score, boss_score, boss_name, x, y, w, h, frame):
    """테크노 서킷 - 회로 기판 패턴"""

    # 딥 블루 메탈릭 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    for row in range(h):
        ratio = row / h
        r = int(10 + 20 * ratio)
        g = int(20 + 40 * ratio)
        b = int(45 + 55 * ratio)
        pygame.draw.line(bg, (r, g, b, 250), (0, row), (w, row))
    surface.blit(bg, (x, y))

    # 회로 패턴
    circuit_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    random.seed(42)
    circuit_color = (0, 180, 255, 80)
    node_color = (0, 255, 255, 150)

    # 수평 라인
    for _ in range(8):
        cy = random.randint(10, h - 10)
        cx1 = random.randint(0, w // 2)
        cx2 = random.randint(w // 2, w)
        pygame.draw.line(circuit_surf, circuit_color, (cx1, cy), (cx2, cy), 1)
        # 노드
        for nx in [cx1, cx2]:
            pygame.draw.circle(circuit_surf, node_color, (nx, cy), 3)

    # 수직 라인
    for _ in range(6):
        cx = random.randint(10, w - 10)
        cy1 = random.randint(0, h // 2)
        cy2 = random.randint(h // 2, h)
        pygame.draw.line(circuit_surf, circuit_color, (cx, cy1), (cx, cy2), 1)

    surface.blit(circuit_surf, (x, y))

    # 데이터 흐름 효과
    flow_pos = (frame * 5) % (w + h)
    for i in range(5):
        fx = (flow_pos + i * 30) % w
        fy = (flow_pos + i * 20) % h
        pulse = 0.5 + 0.5 * math.sin(frame * 0.1 + i)
        pygame.draw.circle(surface, (0, int(255 * pulse), 255, int(200 * pulse)),
                          (x + fx, y + fy), 2)

    # 테크 프레임
    for i in range(3, 0, -1):
        pulse = 0.7 + 0.3 * math.sin(frame * 0.06)
        color = (0, int(150 * pulse), int(220 * pulse))
        pygame.draw.rect(surface, color, (x - i * 2, y - i * 2, w + i * 4, h + i * 4), 1, border_radius=4)

    # 기술 마커
    marker_font = get_korean_font(10)
    markers = ["SYS:OK", "PWR:100%", "NET:ONLINE"]
    for i, marker in enumerate(markers):
        marker_text = marker_font.render(marker, True, (0, 200, 255))
        if i == 0:
            surface.blit(marker_text, (x + 5, y + 5))
        elif i == 1:
            surface.blit(marker_text, (x + w - marker_text.get_width() - 5, y + 5))
        else:
            surface.blit(marker_text, (x + 5, y + h - 15))

    draw_cyberpunk_score(surface, player_score, boss_score, boss_name, x, y, w, h, frame,
                        (80, 220, 255), (255, 180, 100), "TECH CIRCUIT")


def draw_cyberpunk_score(surface, p_score, b_score, boss_name, x, y, w, h, frame,
                        player_color, boss_color, style_name):
    """사이버펑크 스타일 점수 및 이름 표시"""

    # 폰트 설정
    score_font = get_korean_font(52)
    name_font = get_korean_font(16)
    vs_font = get_korean_font(20)
    style_font = get_korean_font(10)

    center_x = x + w // 2

    # 스타일 이름 (상단)
    style_text = style_font.render(style_name, True, (100, 150, 200))
    surface.blit(style_text, (center_x - style_text.get_width() // 2, y + 5))

    # 플레이어 이름 (좌측 상단)
    player_name = "PLAYER"
    p_name_text = name_font.render(player_name, True, player_color)
    p_name_x = center_x - 70 - p_name_text.get_width() // 2
    surface.blit(p_name_text, (p_name_x, y + 22))

    # 보스 이름 (우측 상단)
    b_name_text = name_font.render(boss_name, True, boss_color)
    b_name_x = center_x + 70 - b_name_text.get_width() // 2
    surface.blit(b_name_text, (b_name_x, y + 22))

    # VS 텍스트 (중앙)
    vs_text = vs_font.render("VS", True, (180, 200, 220))
    surface.blit(vs_text, (center_x - vs_text.get_width() // 2, y + 20))

    score_y = y + h // 2 + 5

    # 플레이어 점수 (글로우 효과)
    p_score_text = score_font.render(str(p_score), True, player_color)
    p_score_x = center_x - 65 - p_score_text.get_width() // 2

    # 글로우
    for g in range(4, 0, -1):
        glow = score_font.render(str(p_score), True, player_color)
        glow.set_alpha(40 // g)
        surface.blit(glow, (p_score_x - g, score_y - g))
    surface.blit(p_score_text, (p_score_x, score_y))

    # 구분선 (펄스)
    pulse = 0.5 + 0.5 * math.sin(frame * 0.1)
    line_color = (int(100 * pulse), int(200 * pulse), 255)
    pygame.draw.line(surface, line_color, (center_x - 2, y + 45), (center_x - 2, y + h - 15), 2)
    pygame.draw.line(surface, (200, 220, 255), (center_x, y + 45), (center_x, y + h - 15), 1)
    pygame.draw.line(surface, line_color, (center_x + 2, y + 45), (center_x + 2, y + h - 15), 2)

    # 보스 점수 (글로우 효과)
    b_score_text = score_font.render(str(b_score), True, boss_color)
    b_score_x = center_x + 65 - b_score_text.get_width() // 2

    for g in range(4, 0, -1):
        glow = score_font.render(str(b_score), True, boss_color)
        glow.set_alpha(40 // g)
        surface.blit(glow, (b_score_x - g, score_y - g))
    surface.blit(b_score_text, (b_score_x, score_y))


def main():
    pygame.init()

    # 화면 설정
    WIDTH, HEIGHT = 1200, 900
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("메탈릭 블루 사이버펑크 전광판 미리보기 - 5가지 스타일")

    clock = pygame.time.Clock()
    frame = 0

    # 전광판 크기
    board_w, board_h = 380, 130

    # 보스 이름 (테스트용)
    boss_names = ["풍악보이", "악어장군", "멘헤라걸", "퐁크", "네메시스"]

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

        # 배경 (다크 그레이)
        screen.fill((20, 25, 35))

        # 타이틀
        title_font = get_korean_font(32)
        title = title_font.render("메탈릭 블루 사이버펑크 전광판 - 5가지 스타일", True, (0, 200, 255))
        screen.blit(title, (WIDTH // 2 - title.get_width() // 2, 20))

        subtitle_font = get_korean_font(18)
        subtitle = subtitle_font.render("PLAYER vs BOSS NAME 표시 버전", True, (150, 180, 220))
        screen.blit(subtitle, (WIDTH // 2 - subtitle.get_width() // 2, 60))

        # 5개 전광판 배치 (2x2 + 1)
        positions = [
            (100, 120),   # 스타일 1
            (520, 120),   # 스타일 2
            (100, 300),   # 스타일 3
            (520, 300),   # 스타일 4
            (310, 480),   # 스타일 5 (중앙)
        ]

        # 다양한 점수 상태
        scores = [
            (3, 2),  # 플레이어 리드
            (2, 4),  # 보스 리드
            (5, 0),  # 퍼펙트
            (4, 4),  # 동점
            (1, 3),  # 보스 리드
        ]

        draw_funcs = [
            draw_scoreboard_style1,
            draw_scoreboard_style2,
            draw_scoreboard_style3,
            draw_scoreboard_style4,
            draw_scoreboard_style5,
        ]

        style_labels = [
            "1. 네온 그리드",
            "2. 메탈릭 헥사곤",
            "3. 플라즈마 웨이브",
            "4. 홀로그램 글리치",
            "5. 테크노 서킷",
        ]

        label_font = get_korean_font(14)

        for i, ((px, py), (ps, bs), draw_func, label, boss_name) in enumerate(
            zip(positions, scores, draw_funcs, style_labels, boss_names)):

            # 라벨 표시
            label_text = label_font.render(label, True, (180, 200, 220))
            screen.blit(label_text, (px + board_w // 2 - label_text.get_width() // 2, py + board_h + 10))

            # 전광판 그리기
            draw_func(screen, ps, bs, boss_name, px, py, board_w, board_h, frame)

        # 추가 정보
        info_font = get_korean_font(14)
        info_lines = [
            "특징: 메탈릭 블루 + 사이버펑크 테마",
            "PLAYER vs 보스이름 표시",
            "동적 애니메이션 효과",
            "ESC: 종료",
        ]

        for i, line in enumerate(info_lines):
            info_text = info_font.render(line, True, (120, 150, 180))
            screen.blit(info_text, (WIDTH // 2 - info_text.get_width() // 2, 650 + i * 25))

        pygame.display.flip()
        clock.tick(60)
        frame += 1

    pygame.quit()
    sys.exit()


if __name__ == "__main__":
    main()