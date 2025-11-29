#!/usr/bin/env python3
"""
5가지 새로운 전광판을 이미지로 내보내기
"""
import pygame
import math
import random
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
    for i in range(glow_size, 0, -1):
        alpha = int(50 * intensity * (1 - i / glow_size))
        glow_surf = pygame.Surface((w + i*2, h + i*2), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*color, alpha), (i, i, w, h), border_radius=10)
        surface.blit(glow_surf, (x - i, y - i))
    pygame.draw.rect(surface, color, rect, border_radius=10)


def draw_score_box(surface, x, y, score, label, color, size=150, frame=0):
    """점수 표시 박스"""
    box_rect = pygame.Rect(x - size - 20, y - size - 20, size*2 + 40, size*2 + 40)
    draw_glow_rect(surface, box_rect, color, glow_size=15, intensity=0.7)
    pygame.draw.rect(surface, (5, 5, 10), box_rect.inflate(-8, -8), border_radius=10)

    score_text = font_huge.render(str(score), True, color)
    score_rect = score_text.get_rect(center=(x, y - 20))

    for i in range(5, 0, -1):
        glow = font_huge.render(str(score), True, color)
        glow.set_alpha(100 // i)
        surface.blit(glow, score_rect.move(i//2, i//2))
        surface.blit(glow, score_rect.move(-i//2, -i//2))

    surface.blit(score_text, score_rect)

    label_text = font_medium.render(label, True, color)
    label_rect = label_text.get_rect(center=(x, y + size - 30))
    surface.blit(label_text, label_rect)

    return box_rect


def draw_style1_neon_retro(surface, player_score, boss_score, animation_frame):
    """스타일 1: 네온 레트로"""
    for i in range(HEIGHT):
        color_val = int(5 + i / HEIGHT * 15)
        pygame.draw.line(surface, (color_val, color_val*0.5, color_val*2), (0, i), (WIDTH, i))

    for y in range(0, HEIGHT, 2):
        pygame.draw.line(surface, (255, 255, 255, 30), (0, y), (WIDTH, y), 1)

    title_bar = pygame.Rect(50, 30, WIDTH-100, 100)
    pygame.draw.rect(surface, (255, 0, 150), title_bar, 5)
    pygame.draw.rect(surface, (10, 10, 20), title_bar.inflate(-10, -10))

    title = font_large.render("⚡ PING FIGHTER ⚡", True, (0, 255, 200))
    title_rect = title.get_rect(center=(WIDTH//2, 80))
    surface.blit(title, title_rect)

    p_rect = draw_score_box(surface, 300, 400, player_score, "PLAYER 1", CYAN, size=100, frame=animation_frame)
    b_rect = draw_score_box(surface, WIDTH-300, 400, boss_score, "BOSS", RED, size=100, frame=animation_frame)

    vs_x, vs_y = WIDTH // 2, 400
    angle = (animation_frame * 3) % 360

    diamond_size = 60
    for layer in range(3):
        points = []
        for j in range(4):
            a = math.radians(angle + j * 90)
            size = diamond_size - layer * 15
            points.append((vs_x + size * math.cos(a), vs_y + size * math.sin(a)))
        color = [CYAN, (0, 200, 150), (0, 150, 100)][layer]
        pygame.draw.polygon(surface, color, points, 2)

    vs_text = font_large.render("VS", True, WHITE)
    vs_rect = vs_text.get_rect(center=(vs_x, vs_y))
    surface.blit(vs_text, vs_rect)

    info = font_small.render("⬤ ROUND BATTLE ⬤", True, YELLOW)
    info_rect = info.get_rect(center=(WIDTH//2, HEIGHT-60))
    pygame.draw.rect(surface, (50, 0, 100), info_rect.inflate(40, 20), border_radius=10)
    surface.blit(info, info_rect)


def draw_style2_stadium_display(surface, player_score, boss_score, animation_frame):
    """스타일 2: 스타디움 디스플레이"""
    pygame.draw.rect(surface, (8, 8, 15), (0, 0, WIDTH, HEIGHT))

    main_frame = pygame.Rect(40, 40, WIDTH-80, HEIGHT-80)
    pygame.draw.rect(surface, (100, 200, 255), main_frame, 8)
    pygame.draw.rect(surface, (10, 10, 25), main_frame.inflate(-16, -16))

    header = pygame.Rect(60, 60, WIDTH-120, 120)
    pygame.draw.rect(surface, (20, 40, 80), header)

    game_title = font_very_large.render("ROUND MATCH", True, (100, 220, 255))
    game_rect = game_title.get_rect(center=(WIDTH//2, 120))
    surface.blit(game_title, game_rect)

    score_y = 280

    p_card_x = 120
    p_card = pygame.Rect(p_card_x, score_y, 400, 350)
    pygame.draw.rect(surface, (30, 80, 150), p_card, border_radius=15)
    pygame.draw.rect(surface, (80, 150, 255), p_card, 6, border_radius=15)

    pygame.draw.circle(surface, (100, 180, 255), (p_card_x + 60, score_y + 60), 45)
    p_icon = font_very_large.render("P", True, WHITE)
    p_icon_rect = p_icon.get_rect(center=(p_card_x + 60, score_y + 60))
    surface.blit(p_icon, p_icon_rect)

    p_name = font_large.render("PLAYER", True, (100, 220, 255))
    surface.blit(p_name, (p_card_x + 130, score_y + 30))

    pulse = 0.7 + 0.3 * math.sin(animation_frame * 0.1)
    p_color = (int(100*pulse), int(220*pulse), 255)
    p_score = font_huge.render(str(player_score), True, p_color)
    p_score_rect = p_score.get_rect(center=(p_card_x + 200, score_y + 200))
    surface.blit(p_score, p_score_rect)

    b_card_x = WIDTH - 120 - 400
    b_card = pygame.Rect(b_card_x, score_y, 400, 350)
    pygame.draw.rect(surface, (150, 50, 50), b_card, border_radius=15)
    pygame.draw.rect(surface, (255, 100, 100), b_card, 6, border_radius=15)

    pygame.draw.circle(surface, (200, 80, 80), (b_card_x + 60, score_y + 60), 45)
    b_icon = font_very_large.render("B", True, WHITE)
    b_icon_rect = b_icon.get_rect(center=(b_card_x + 60, score_y + 60))
    surface.blit(b_icon, b_icon_rect)

    b_name = font_large.render("BOSS", True, (255, 120, 120))
    surface.blit(b_name, (b_card_x + 130, score_y + 30))

    b_color = (255, int(100*pulse), int(100*pulse))
    b_score = font_huge.render(str(boss_score), True, b_color)
    b_score_rect = b_score.get_rect(center=(b_card_x + 200, score_y + 200))
    surface.blit(b_score, b_score_rect)

    vs_text = font_large.render("VS", True, YELLOW)
    vs_rect = vs_text.get_rect(center=(WIDTH//2, score_y + 200))
    pygame.draw.circle(surface, (100, 80, 20), (WIDTH//2, score_y + 200), 60)
    pygame.draw.circle(surface, (200, 150, 50), (WIDTH//2, score_y + 200), 55, 3)
    surface.blit(vs_text, vs_rect)

    footer = pygame.Rect(60, HEIGHT-100, WIDTH-120, 80)
    pygame.draw.rect(surface, (20, 40, 80), footer)
    pygame.draw.rect(surface, (100, 200, 255), footer, 4)

    footer_text = font_small.render("🏆 FIRST TO 3 WINS 🏆", True, YELLOW)
    footer_rect = footer_text.get_rect(center=(WIDTH//2, HEIGHT-60))
    surface.blit(footer_text, footer_rect)


def draw_style3_hologram(surface, player_score, boss_score, animation_frame):
    """스타일 3: 홀로그램"""
    pygame.draw.rect(surface, (2, 2, 8), (0, 0, WIDTH, HEIGHT))

    for x in range(0, WIDTH, 40):
        alpha = 20 + 10 * math.sin(animation_frame * 0.05 + x * 0.01)
        pygame.draw.line(surface, (0, 255, 200), (x, 0), (x, HEIGHT), 1)

    for y in range(0, HEIGHT, 40):
        alpha = 20 + 10 * math.sin(animation_frame * 0.05 + y * 0.01)
        pygame.draw.line(surface, (0, 255, 200), (0, y), (WIDTH, y), 1)

    title = font_very_large.render("▸ HOLOGRAM ◂", True, (0, 255, 200))
    title_rect = title.get_rect(center=(WIDTH//2, 80))

    for i in range(3):
        glow = font_very_large.render("▸ HOLOGRAM ◂", True, (0, 200, 150))
        glow.set_alpha(50)
        surface.blit(glow, title_rect.move(i, i))
    surface.blit(title, title_rect)

    center_y = HEIGHT // 2

    p_x = 200

    pygame.draw.circle(surface, (0, 255, 200), (p_x, center_y), 180, 3)
    pygame.draw.circle(surface, (0, 200, 150), (p_x, center_y), 170, 1)

    p_label = font_medium.render("PLAYER", True, (0, 255, 200))
    surface.blit(p_label, (p_x - 120, center_y - 150))

    p_score = font_huge.render(str(player_score), True, (0, 255, 200))
    p_score_rect = p_score.get_rect(center=(p_x, center_y + 30))
    for i in range(5):
        offset = i * 2
        glow = font_huge.render(str(player_score), True, (0, 150, 100))
        glow.set_alpha(50 - i*10)
        surface.blit(glow, p_score_rect.move(-offset, 0))
    surface.blit(p_score, p_score_rect)

    b_x = WIDTH - 200

    pygame.draw.circle(surface, (255, 50, 100), (b_x, center_y), 180, 3)
    pygame.draw.circle(surface, (200, 30, 80), (b_x, center_y), 170, 1)

    b_label = font_medium.render("BOSS", True, (255, 50, 100))
    surface.blit(b_label, (b_x - 100, center_y - 150))

    b_score = font_huge.render(str(boss_score), True, (255, 50, 100))
    b_score_rect = b_score.get_rect(center=(b_x, center_y + 30))
    for i in range(5):
        offset = i * 2
        glow = font_huge.render(str(boss_score), True, (150, 30, 60))
        glow.set_alpha(50 - i*10)
        surface.blit(glow, b_score_rect.move(-offset, 0))
    surface.blit(b_score, b_score_rect)

    vs_size = 80 + 20 * math.sin(animation_frame * 0.08)
    vs_font = pygame.font.Font(None, int(vs_size))
    vs = vs_font.render("VS", True, YELLOW)
    vs_rect = vs.get_rect(center=(WIDTH//2, center_y))
    surface.blit(vs, vs_rect)

    info = font_small.render("⚛ QUANTUM BATTLE ⚛", True, (0, 255, 200))
    info_rect = info.get_rect(center=(WIDTH//2, HEIGHT-60))
    surface.blit(info, info_rect)


def draw_style4_sports_classic(surface, player_score, boss_score, animation_frame):
    """스타일 4: 스포츠 클래식"""
    pygame.draw.rect(surface, (5, 25, 10), (0, 0, WIDTH, HEIGHT))

    board = pygame.Rect(50, 80, WIDTH-100, HEIGHT-160)
    pygame.draw.rect(surface, (20, 50, 25), board, border_radius=20)
    pygame.draw.rect(surface, (100, 180, 120), board, 12, border_radius=20)

    title = font_very_large.render("PING FIGHTER", True, (255, 220, 100))
    title_rect = title.get_rect(center=(WIDTH//2, 150))
    surface.blit(title, title_rect)

    score_y = 320

    p_section = pygame.Rect(120, score_y, 450, 280)
    pygame.draw.rect(surface, (15, 35, 20), p_section, border_radius=15)
    pygame.draw.rect(surface, (100, 200, 150), p_section, 5, border_radius=15)

    p_score = font_huge.render(str(player_score), True, (150, 255, 180))
    p_score_rect = p_score.get_rect(center=(300, score_y + 120))

    for i in range(5):
        glow = font_huge.render(str(player_score), True, (100, 180, 120))
        glow.set_alpha(100 - i*20)
        surface.blit(glow, p_score_rect.move(i, i))
    surface.blit(p_score, p_score_rect)

    p_label = font_large.render("PLAYER", True, (100, 200, 150))
    surface.blit(p_label, (170, score_y + 220))

    b_section = pygame.Rect(WIDTH-570, score_y, 450, 280)
    pygame.draw.rect(surface, (50, 20, 20), b_section, border_radius=15)
    pygame.draw.rect(surface, (200, 100, 100), b_section, 5, border_radius=15)

    b_score = font_huge.render(str(boss_score), True, (255, 150, 150))
    b_score_rect = b_score.get_rect(center=(WIDTH-300, score_y + 120))

    for i in range(5):
        glow = font_huge.render(str(boss_score), True, (180, 100, 100))
        glow.set_alpha(100 - i*20)
        surface.blit(glow, b_score_rect.move(i, i))
    surface.blit(b_score, b_score_rect)

    b_label = font_large.render("BOSS", True, (200, 100, 100))
    surface.blit(b_label, (WIDTH-480, score_y + 220))

    vs_bg = pygame.Rect(WIDTH//2 - 80, score_y + 80, 160, 160)
    pygame.draw.rect(surface, (30, 50, 35), vs_bg, border_radius=10)
    pygame.draw.rect(surface, (150, 220, 180), vs_bg, 3, border_radius=10)

    vs = font_very_large.render("VS", True, (255, 220, 100))
    vs_rect = vs.get_rect(center=(WIDTH//2, score_y + 160))
    surface.blit(vs, vs_rect)

    banner = font_large.render("◆ FIRST TO 3 WINS ◆", True, (255, 220, 100))
    banner_rect = banner.get_rect(center=(WIDTH//2, HEIGHT - 70))
    surface.blit(banner, banner_rect)


def draw_style5_matrix_digital(surface, player_score, boss_score, animation_frame):
    """스타일 5: 매트릭스 디지털"""
    pygame.draw.rect(surface, (0, 0, 0), (0, 0, WIDTH, HEIGHT))

    for i in range(30):
        x = (animation_frame * 2 + i * 50) % WIDTH
        y = (animation_frame * 3 + i * 80) % HEIGHT
        char = str(random.randint(0, 9))
        code_text = font_tiny.render(char, True, (0, 150, 100))
        surface.blit(code_text, (x, y))

    title_frame = pygame.Rect(100, 40, WIDTH-200, 100)
    pygame.draw.rect(surface, (0, 200, 150), title_frame, 3)
    pygame.draw.rect(surface, (0, 50, 40), title_frame.inflate(-6, -6))

    title = font_very_large.render("[ BATTLE STATUS ]", True, (0, 255, 200))
    title_rect = title.get_rect(center=(WIDTH//2, 90))
    surface.blit(title, title_rect)

    p_panel = pygame.Rect(80, 200, 450, 500)
    pygame.draw.rect(surface, (0, 100, 80), p_panel, 2)
    pygame.draw.rect(surface, (0, 30, 25), p_panel.inflate(-4, -4))

    pygame.draw.line(surface, (0, 200, 150), (100, 250), (500, 250), 2)
    p_header = font_medium.render("PLAYER DATA", True, (0, 255, 200))
    surface.blit(p_header, (120, 220))

    if animation_frame % 20 < 15:
        p_score = font_huge.render(str(player_score), True, (0, 255, 200))
    else:
        p_score = font_huge.render(str(player_score), True, (0, 150, 100))
    p_score_rect = p_score.get_rect(center=(300, 420))
    surface.blit(p_score, p_score_rect)

    status_text = font_small.render("● ACTIVE", True, (0, 255, 100))
    surface.blit(status_text, (130, 480))

    b_panel = pygame.Rect(WIDTH-530, 200, 450, 500)
    pygame.draw.rect(surface, (150, 50, 80), b_panel, 2)
    pygame.draw.rect(surface, (80, 20, 40), b_panel.inflate(-4, -4))

    pygame.draw.line(surface, (200, 100, 150), (WIDTH-510, 250), (WIDTH-90, 250), 2)
    b_header = font_medium.render("BOSS DATA", True, (255, 100, 150))
    surface.blit(b_header, (WIDTH-480, 220))

    if animation_frame % 20 < 15:
        b_score = font_huge.render(str(boss_score), True, (255, 100, 150))
    else:
        b_score = font_huge.render(str(boss_score), True, (150, 50, 80))
    b_score_rect = b_score.get_rect(center=(WIDTH-300, 420))
    surface.blit(b_score, b_score_rect)

    b_status = font_small.render("● HOSTILE", True, (255, 100, 100))
    surface.blit(b_status, (WIDTH-480, 480))

    info = font_small.render(f"FRAME: {animation_frame % 1000:04d}", True, (0, 150, 100))
    surface.blit(info, (80, HEIGHT-60))

    connection = font_small.render("CONNECTION: STABLE ✓", True, (0, 255, 100))
    surface.blit(connection, (WIDTH-380, HEIGHT-60))


# 각 스타일을 개별 이미지로 저장
styles = [
    ("ultra_style1_neon_retro", draw_style1_neon_retro, "네온 레트로 - 80년대 아케이드"),
    ("ultra_style2_stadium", draw_style2_stadium_display, "스타디움 디스플레이 - 대형 전광판"),
    ("ultra_style3_hologram", draw_style3_hologram, "홀로그램 - 미래형"),
    ("ultra_style4_sports", draw_style4_sports_classic, "스포츠 클래식 - 야구장"),
    ("ultra_style5_matrix", draw_style5_matrix_digital, "매트릭스 디지털 - 하이테크"),
]

for filename, draw_func, description in styles:
    surface = pygame.Surface((WIDTH, HEIGHT))
    surface.fill((10, 10, 20))

    # 배경 제목
    bg_title = font_medium.render(description, True, YELLOW)
    bg_title_rect = bg_title.get_rect(center=(WIDTH // 2, 15))
    surface.blit(bg_title, bg_title_rect)

    draw_func(surface, 2, 1, 100)

    pygame.image.save(surface, f"/tmp/{filename}.png")
    print(f"✅ {filename}.png 저장완료")

print("\n🎉 모든 새로운 스코어보드 이미지가 /tmp에 저장되었습니다!")
pygame.quit()
