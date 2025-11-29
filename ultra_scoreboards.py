#!/usr/bin/env python3
"""
초고퀄리티 전광판 - 완전 재디자인 버전
5가지 역동적인 스타일
"""
import pygame
import math
import random
import sys
import os

WIDTH = 1400
HEIGHT = 800

WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
YELLOW = (255, 220, 0)
RED = (255, 50, 80)
BLUE = (50, 150, 255)
CYAN = (0, 255, 200)
GREEN = (100, 255, 150)
PURPLE = (200, 100, 255)
ORANGE = (255, 150, 50)

pygame.init()
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("초고퀄리티 전광판 - 새로운 디자인")
clock = pygame.time.Clock()

try:
    font_path = os.path.join(os.path.dirname(__file__), "fonts", "NeoDunggeunmoPro-Regular.ttf")
    if os.path.exists(font_path):
        font_huge = pygame.font.Font(font_path, 160)
        font_very_large = pygame.font.Font(font_path, 120)
        font_large = pygame.font.Font(font_path, 80)
        font_medium = pygame.font.Font(font_path, 50)
        font_small = pygame.font.Font(font_path, 32)
        font_tiny = pygame.font.Font(font_path, 24)
    else:
        raise FileNotFoundError
except:
    font_huge = pygame.font.Font(None, 160)
    font_very_large = pygame.font.Font(None, 120)
    font_large = pygame.font.Font(None, 80)
    font_medium = pygame.font.Font(None, 50)
    font_small = pygame.font.Font(None, 32)
    font_tiny = pygame.font.Font(None, 24)


def draw_glow_rect(surface, rect, color, glow_size=20, intensity=0.5):
    """글로우 효과가 있는 사각형"""
    x, y, w, h = rect

    # 글로우 레이어
    for i in range(glow_size, 0, -1):
        alpha = int(50 * intensity * (1 - i / glow_size))
        glow_surf = pygame.Surface((w + i*2, h + i*2), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*color, alpha), (i, i, w, h), border_radius=10)
        surface.blit(glow_surf, (x - i, y - i))

    # 메인 사각형
    pygame.draw.rect(surface, color, rect, border_radius=10)


def draw_animated_border(surface, rect, colors, frame, thickness=4):
    """애니메이션 테두리"""
    x, y, w, h = rect
    color_idx = (frame // 10) % len(colors)
    color = colors[color_idx]
    pygame.draw.rect(surface, color, rect, thickness, border_radius=10)


def draw_score_box(surface, x, y, score, label, color, size=150, frame=0, style="digital"):
    """점수 표시 박스"""
    # 배경 박스
    box_rect = pygame.Rect(x - size - 20, y - size - 20, size*2 + 40, size*2 + 40)

    # 글로우 배경
    draw_glow_rect(surface, box_rect, color, glow_size=15, intensity=0.7)

    # 어두운 배경
    pygame.draw.rect(surface, (5, 5, 10), box_rect.inflate(-8, -8), border_radius=10)

    # 점수 텍스트 (매우 큼)
    score_text = font_huge.render(str(score), True, color)
    score_rect = score_text.get_rect(center=(x, y - 20))

    # 점수 글로우
    for i in range(5, 0, -1):
        glow = font_huge.render(str(score), True, color)
        glow.set_alpha(100 // i)
        surface.blit(glow, score_rect.move(i//2, i//2))
        surface.blit(glow, score_rect.move(-i//2, -i//2))

    surface.blit(score_text, score_rect)

    # 라벨
    label_text = font_medium.render(label, True, color)
    label_rect = label_text.get_rect(center=(x, y + size - 30))
    surface.blit(label_text, label_rect)

    return box_rect


def draw_style1_neon_retro(surface, player_score, boss_score, animation_frame):
    """스타일 1: 네온 레트로 (80년대 아케이드)"""
    # 배경 그라데이션
    for i in range(HEIGHT):
        color_val = int(5 + i / HEIGHT * 15)
        pygame.draw.line(surface, (color_val, color_val*0.5, color_val*2), (0, i), (WIDTH, i))

    # 스캔라인
    for y in range(0, HEIGHT, 2):
        pygame.draw.line(surface, (255, 255, 255, 30), (0, y), (WIDTH, y), 1)

    # 타이틀 배경
    title_bar = pygame.Rect(50, 30, WIDTH-100, 100)
    pygame.draw.rect(surface, (255, 0, 150), title_bar, 5)
    pygame.draw.rect(surface, (10, 10, 20), title_bar.inflate(-10, -10))

    # 타이틀
    title = font_large.render("⚡ PING FIGHTER ⚡", True, (0, 255, 200))
    title_rect = title.get_rect(center=(WIDTH//2, 80))
    surface.blit(title, title_rect)

    # 플레이어 점수 박스 (좌측)
    p_rect = draw_score_box(surface, 300, 400, player_score, "PLAYER 1", CYAN, size=100, frame=animation_frame)

    # 보스 점수 박스 (우측)
    b_rect = draw_score_box(surface, WIDTH-300, 400, boss_score, "BOSS", RED, size=100, frame=animation_frame)

    # VS 중앙 (회전하는 다이아몬드)
    vs_x, vs_y = WIDTH // 2, 400
    angle = (animation_frame * 3) % 360

    # 회전하는 다이아몬드
    diamond_size = 60
    for layer in range(3):
        points = []
        for j in range(4):
            a = math.radians(angle + j * 90)
            size = diamond_size - layer * 15
            points.append((vs_x + size * math.cos(a), vs_y + size * math.sin(a)))
        color = [CYAN, (0, 200, 150), (0, 150, 100)][layer]
        pygame.draw.polygon(surface, color, points, 2)

    # VS 텍스트
    vs_text = font_large.render("VS", True, WHITE)
    vs_rect = vs_text.get_rect(center=(vs_x, vs_y))
    surface.blit(vs_text, vs_rect)

    # 하단 정보
    info = font_small.render("⬤ ROUND BATTLE ⬤", True, YELLOW)
    info_rect = info.get_rect(center=(WIDTH//2, HEIGHT-60))
    pygame.draw.rect(surface, (50, 0, 100), info_rect.inflate(40, 20), border_radius=10)
    surface.blit(info, info_rect)


def draw_style2_stadium_display(surface, player_score, boss_score, animation_frame):
    """스타일 2: 스타디움 디스플레이 (대형 전광판)"""
    # 어두운 배경
    pygame.draw.rect(surface, (8, 8, 15), (0, 0, WIDTH, HEIGHT))

    # 주경기장 프레임
    main_frame = pygame.Rect(40, 40, WIDTH-80, HEIGHT-80)
    pygame.draw.rect(surface, (100, 200, 255), main_frame, 8)
    pygame.draw.rect(surface, (10, 10, 25), main_frame.inflate(-16, -16))

    # 상단 헤더
    header = pygame.Rect(60, 60, WIDTH-120, 120)
    pygame.draw.rect(surface, (20, 40, 80), header)

    # 경기 정보
    game_title = font_very_large.render("ROUND MATCH", True, (100, 220, 255))
    game_rect = game_title.get_rect(center=(WIDTH//2, 120))
    surface.blit(game_title, game_rect)

    # 중앙 스코어 영역
    score_y = 280

    # 플레이어 카드 (좌측)
    p_card_x = 120
    p_card = pygame.Rect(p_card_x, score_y, 400, 350)
    pygame.draw.rect(surface, (30, 80, 150), p_card, border_radius=15)
    pygame.draw.rect(surface, (80, 150, 255), p_card, 6, border_radius=15)

    # 플레이어 아이콘
    pygame.draw.circle(surface, (100, 180, 255), (p_card_x + 60, score_y + 60), 45)
    p_icon = font_very_large.render("P", True, WHITE)
    p_icon_rect = p_icon.get_rect(center=(p_card_x + 60, score_y + 60))
    surface.blit(p_icon, p_icon_rect)

    # 플레이어 정보
    p_name = font_large.render("PLAYER", True, (100, 220, 255))
    surface.blit(p_name, (p_card_x + 130, score_y + 30))

    # 플레이어 점수 (애니메이션)
    pulse = 0.7 + 0.3 * math.sin(animation_frame * 0.1)
    p_color = (int(100*pulse), int(220*pulse), 255)
    p_score = font_huge.render(str(player_score), True, p_color)
    p_score_rect = p_score.get_rect(center=(p_card_x + 200, score_y + 200))
    surface.blit(p_score, p_score_rect)

    # 보스 카드 (우측)
    b_card_x = WIDTH - 120 - 400
    b_card = pygame.Rect(b_card_x, score_y, 400, 350)
    pygame.draw.rect(surface, (150, 50, 50), b_card, border_radius=15)
    pygame.draw.rect(surface, (255, 100, 100), b_card, 6, border_radius=15)

    # 보스 아이콘
    pygame.draw.circle(surface, (200, 80, 80), (b_card_x + 60, score_y + 60), 45)
    b_icon = font_very_large.render("B", True, WHITE)
    b_icon_rect = b_icon.get_rect(center=(b_card_x + 60, score_y + 60))
    surface.blit(b_icon, b_icon_rect)

    # 보스 정보
    b_name = font_large.render("BOSS", True, (255, 120, 120))
    surface.blit(b_name, (b_card_x + 130, score_y + 30))

    # 보스 점수
    b_color = (255, int(100*pulse), int(100*pulse))
    b_score = font_huge.render(str(boss_score), True, b_color)
    b_score_rect = b_score.get_rect(center=(b_card_x + 200, score_y + 200))
    surface.blit(b_score, b_score_rect)

    # VS 중앙
    vs_text = font_large.render("VS", True, YELLOW)
    vs_rect = vs_text.get_rect(center=(WIDTH//2, score_y + 200))
    pygame.draw.circle(surface, (100, 80, 20), (WIDTH//2, score_y + 200), 60)
    pygame.draw.circle(surface, (200, 150, 50), (WIDTH//2, score_y + 200), 55, 3)
    surface.blit(vs_text, vs_rect)

    # 하단 정보 바
    footer = pygame.Rect(60, HEIGHT-100, WIDTH-120, 80)
    pygame.draw.rect(surface, (20, 40, 80), footer)
    pygame.draw.rect(surface, (100, 200, 255), footer, 4)

    footer_text = font_small.render("🏆 FIRST TO 3 WINS 🏆", True, YELLOW)
    footer_rect = footer_text.get_rect(center=(WIDTH//2, HEIGHT-60))
    surface.blit(footer_text, footer_rect)


def draw_style3_hologram(surface, player_score, boss_score, animation_frame):
    """스타일 3: 홀로그램 (미래형)"""
    # 검정색 배경
    pygame.draw.rect(surface, (2, 2, 8), (0, 0, WIDTH, HEIGHT))

    # 홀로그램 그리드 배경
    for x in range(0, WIDTH, 40):
        alpha = 20 + 10 * math.sin(animation_frame * 0.05 + x * 0.01)
        pygame.draw.line(surface, (0, 255, 200, int(alpha)), (x, 0), (x, HEIGHT), 1)

    for y in range(0, HEIGHT, 40):
        alpha = 20 + 10 * math.sin(animation_frame * 0.05 + y * 0.01)
        pygame.draw.line(surface, (0, 255, 200, int(alpha)), (0, y), (WIDTH, y), 1)

    # 타이틀 (사이버펑크)
    title = font_very_large.render("▸ HOLOGRAM ◂", True, (0, 255, 200))
    title_rect = title.get_rect(center=(WIDTH//2, 80))

    # 타이틀 글로우
    for i in range(3):
        glow = font_very_large.render("▸ HOLOGRAM ◂", True, (0, 200, 150))
        glow.set_alpha(50)
        surface.blit(glow, title_rect.move(i, i))
    surface.blit(title, title_rect)

    # 중앙 점수 영역
    center_y = HEIGHT // 2

    # 플레이어 (좌측)
    p_x = 200

    # 플레이어 원형 프레임
    pygame.draw.circle(surface, (0, 255, 200), (p_x, center_y), 180, 3)
    pygame.draw.circle(surface, (0, 200, 150), (p_x, center_y), 170, 1)

    # 플레이어 라벨
    p_label = font_medium.render("PLAYER", True, (0, 255, 200))
    surface.blit(p_label, (p_x - 120, center_y - 150))

    # 플레이어 점수 (홀로그램 효과)
    p_score = font_huge.render(str(player_score), True, (0, 255, 200))
    p_score_rect = p_score.get_rect(center=(p_x, center_y + 30))
    for i in range(5):
        offset = i * 2
        glow = font_huge.render(str(player_score), True, (0, 150, 100))
        glow.set_alpha(50 - i*10)
        surface.blit(glow, p_score_rect.move(-offset, 0))
    surface.blit(p_score, p_score_rect)

    # 보스 (우측)
    b_x = WIDTH - 200

    # 보스 원형 프레임
    pygame.draw.circle(surface, (255, 50, 100), (b_x, center_y), 180, 3)
    pygame.draw.circle(surface, (200, 30, 80), (b_x, center_y), 170, 1)

    # 보스 라벨
    b_label = font_medium.render("BOSS", True, (255, 50, 100))
    surface.blit(b_label, (b_x - 100, center_y - 150))

    # 보스 점수
    b_score = font_huge.render(str(boss_score), True, (255, 50, 100))
    b_score_rect = b_score.get_rect(center=(b_x, center_y + 30))
    for i in range(5):
        offset = i * 2
        glow = font_huge.render(str(boss_score), True, (150, 30, 60))
        glow.set_alpha(50 - i*10)
        surface.blit(glow, b_score_rect.move(-offset, 0))
    surface.blit(b_score, b_score_rect)

    # VS 중앙
    vs_size = 80 + 20 * math.sin(animation_frame * 0.08)
    vs_font = pygame.font.Font(None, int(vs_size))
    vs = vs_font.render("VS", True, YELLOW)
    vs_rect = vs.get_rect(center=(WIDTH//2, center_y))
    surface.blit(vs, vs_rect)

    # 하단 정보
    info = font_small.render("⚛ QUANTUM BATTLE ⚛", True, (0, 255, 200))
    info_rect = info.get_rect(center=(WIDTH//2, HEIGHT-60))
    surface.blit(info, info_rect)


def draw_style4_sports_classic(surface, player_score, boss_score, animation_frame):
    """스타일 4: 스포츠 클래식 (야구장)"""
    # 진한 녹색 배경
    pygame.draw.rect(surface, (5, 25, 10), (0, 0, WIDTH, HEIGHT))

    # 목재 텍스처
    for i in range(HEIGHT):
        variation = random.randint(-5, 5) if i % 20 == 0 else 0
        color = (10 + variation, 40 + variation, 15 + variation)
        pygame.draw.line(surface, color, (0, i), (WIDTH, i))

    # 메인 보드 프레임
    board = pygame.Rect(50, 80, WIDTH-100, HEIGHT-160)
    pygame.draw.rect(surface, (20, 50, 25), board, border_radius=20)
    pygame.draw.rect(surface, (100, 180, 120), board, 12, border_radius=20)

    # 타이틀
    title = font_very_large.render("PING FIGHTER", True, (255, 220, 100))
    title_rect = title.get_rect(center=(WIDTH//2, 150))
    surface.blit(title, title_rect)

    # 스코어 영역
    score_y = 320

    # 플레이어 섹션 (좌측)
    p_section = pygame.Rect(120, score_y, 450, 280)
    pygame.draw.rect(surface, (15, 35, 20), p_section, border_radius=15)
    pygame.draw.rect(surface, (100, 200, 150), p_section, 5, border_radius=15)

    # 플레이어 점수
    p_score = font_huge.render(str(player_score), True, (150, 255, 180))
    p_score_rect = p_score.get_rect(center=(300, score_y + 120))

    # 점수 글로우
    for i in range(5):
        glow = font_huge.render(str(player_score), True, (100, 180, 120))
        glow.set_alpha(100 - i*20)
        surface.blit(glow, p_score_rect.move(i, i))
    surface.blit(p_score, p_score_rect)

    # 플레이어 라벨
    p_label = font_large.render("PLAYER", True, (100, 200, 150))
    surface.blit(p_label, (170, score_y + 220))

    # 보스 섹션 (우측)
    b_section = pygame.Rect(WIDTH-570, score_y, 450, 280)
    pygame.draw.rect(surface, (50, 20, 20), b_section, border_radius=15)
    pygame.draw.rect(surface, (200, 100, 100), b_section, 5, border_radius=15)

    # 보스 점수
    b_score = font_huge.render(str(boss_score), True, (255, 150, 150))
    b_score_rect = b_score.get_rect(center=(WIDTH-300, score_y + 120))

    for i in range(5):
        glow = font_huge.render(str(boss_score), True, (180, 100, 100))
        glow.set_alpha(100 - i*20)
        surface.blit(glow, b_score_rect.move(i, i))
    surface.blit(b_score, b_score_rect)

    # 보스 라벨
    b_label = font_large.render("BOSS", True, (200, 100, 100))
    surface.blit(b_label, (WIDTH-480, score_y + 220))

    # VS 중앙
    vs_bg = pygame.Rect(WIDTH//2 - 80, score_y + 80, 160, 160)
    pygame.draw.rect(surface, (30, 50, 35), vs_bg, border_radius=10)
    pygame.draw.rect(surface, (150, 220, 180), vs_bg, 3, border_radius=10)

    vs = font_very_large.render("VS", True, (255, 220, 100))
    vs_rect = vs.get_rect(center=(WIDTH//2, score_y + 160))
    surface.blit(vs, vs_rect)

    # 하단 배너
    banner = font_large.render("◆ FIRST TO 3 WINS ◆", True, (255, 220, 100))
    banner_rect = banner.get_rect(center=(WIDTH//2, HEIGHT - 70))
    surface.blit(banner, banner_rect)


def draw_style5_matrix_digital(surface, player_score, boss_score, animation_frame):
    """스타일 5: 매트릭스 디지털 (하이테크)"""
    # 검정 배경
    pygame.draw.rect(surface, (0, 0, 0), (0, 0, WIDTH, HEIGHT))

    # 떨어지는 코드 효과
    for i in range(30):
        x = (animation_frame * 2 + i * 50) % WIDTH
        y = (animation_frame * 3 + i * 80) % HEIGHT
        char = str(random.randint(0, 9))
        code_text = font_tiny.render(char, True, (0, 150, 100))
        surface.blit(code_text, (x, y))

    # 타이틀 프레임
    title_frame = pygame.Rect(100, 40, WIDTH-200, 100)
    pygame.draw.rect(surface, (0, 200, 150), title_frame, 3)
    pygame.draw.rect(surface, (0, 50, 40), title_frame.inflate(-6, -6))

    title = font_very_large.render("[ BATTLE STATUS ]", True, (0, 255, 200))
    title_rect = title.get_rect(center=(WIDTH//2, 90))
    surface.blit(title, title_rect)

    # 플레이어 패널 (좌측)
    p_panel = pygame.Rect(80, 200, 450, 500)
    pygame.draw.rect(surface, (0, 100, 80), p_panel, 2)
    pygame.draw.rect(surface, (0, 30, 25), p_panel.inflate(-4, -4))

    # 플레이어 헤더
    pygame.draw.line(surface, (0, 200, 150), (100, 250), (500, 250), 2)
    p_header = font_medium.render("PLAYER DATA", True, (0, 255, 200))
    surface.blit(p_header, (120, 220))

    # 플레이어 점수 (깜빡임 효과)
    if animation_frame % 20 < 15:
        p_score = font_huge.render(str(player_score), True, (0, 255, 200))
    else:
        p_score = font_huge.render(str(player_score), True, (0, 150, 100))
    p_score_rect = p_score.get_rect(center=(300, 420))
    surface.blit(p_score, p_score_rect)

    # 상태 표시
    status_text = font_small.render("● ACTIVE", True, (0, 255, 100))
    surface.blit(status_text, (130, 480))

    # 보스 패널 (우측)
    b_panel = pygame.Rect(WIDTH-530, 200, 450, 500)
    pygame.draw.rect(surface, (150, 50, 80), b_panel, 2)
    pygame.draw.rect(surface, (80, 20, 40), b_panel.inflate(-4, -4))

    # 보스 헤더
    pygame.draw.line(surface, (200, 100, 150), (WIDTH-510, 250), (WIDTH-90, 250), 2)
    b_header = font_medium.render("BOSS DATA", True, (255, 100, 150))
    surface.blit(b_header, (WIDTH-480, 220))

    # 보스 점수
    if animation_frame % 20 < 15:
        b_score = font_huge.render(str(boss_score), True, (255, 100, 150))
    else:
        b_score = font_huge.render(str(boss_score), True, (150, 50, 80))
    b_score_rect = b_score.get_rect(center=(WIDTH-300, 420))
    surface.blit(b_score, b_score_rect)

    # 상태 표시
    b_status = font_small.render("● HOSTILE", True, (255, 100, 100))
    surface.blit(b_status, (WIDTH-480, 480))

    # 하단 정보
    info = font_small.render(f"FRAME: {animation_frame % 1000:04d}", True, (0, 150, 100))
    surface.blit(info, (80, HEIGHT-60))

    connection = font_small.render("CONNECTION: STABLE ✓", True, (0, 255, 100))
    surface.blit(connection, (WIDTH-380, HEIGHT-60))


def main():
    current_style = 0
    styles = [
        ("1: 네온 레트로", draw_style1_neon_retro),
        ("2: 스타디움 디스플레이", draw_style2_stadium_display),
        ("3: 홀로그램", draw_style3_hologram),
        ("4: 스포츠 클래식", draw_style4_sports_classic),
        ("5: 매트릭스 디지털", draw_style5_matrix_digital),
    ]

    player_score = 2
    boss_score = 1
    animation_frame = 0

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_LEFT:
                    current_style = (current_style - 1) % len(styles)
                elif event.key == pygame.K_RIGHT:
                    current_style = (current_style + 1) % len(styles)
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
                elif event.key == pygame.K_UP:
                    player_score = min(9, player_score + 1)
                elif event.key == pygame.K_DOWN:
                    player_score = max(0, player_score - 1)
                elif event.key == pygame.K_w:
                    boss_score = min(9, boss_score + 1)
                elif event.key == pygame.K_s:
                    boss_score = max(0, boss_score - 1)
                elif event.key == pygame.K_ESCAPE:
                    running = False

        # 현재 스타일 그리기
        style_name, draw_func = styles[current_style]
        draw_func(screen, player_score, boss_score, animation_frame)

        # 안내 텍스트
        guide = font_tiny.render("← → 스타일 | ↑↓ P점수 | W/S 보스점수 | 1-5 선택 | ESC 종료", True, (150, 150, 200))
        screen.blit(guide, (30, 15))

        # 현재 스타일 이름
        style_text = font_medium.render(style_name, True, YELLOW)
        style_rect = style_text.get_rect(center=(WIDTH // 2, HEIGHT - 30))

        # 배경 박스
        bg_rect = style_rect.inflate(40, 20)
        pygame.draw.rect(screen, (30, 30, 50), bg_rect, border_radius=8)
        pygame.draw.rect(screen, (255, 200, 50), bg_rect, 2, border_radius=8)
        screen.blit(style_text, style_rect)

        pygame.display.flip()
        clock.tick(60)
        animation_frame += 1

    pygame.quit()


if __name__ == "__main__":
    main()
