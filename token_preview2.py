"""
대쉬 토큰 디자인 미리보기 - 글로시 루비 기반 고급 업그레이드 10가지
"""
import pygame
import math
import sys

pygame.init()

SCREEN_WIDTH = 1200
SCREEN_HEIGHT = 700
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("Glossy Ruby Upgrade Preview")

WHITE = (255, 255, 255)
DARK_BG = (20, 20, 30)
TOKEN_SIZE = 48
CORNER_RADIUS = 10

def draw_token_1(surface, x, y, time_now):
    """1. 글로시 루비 + 인너 글로우"""
    token_surf = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)

    # 베이스 그라데이션
    for yl in range(TOKEN_SIZE):
        ratio = yl / TOKEN_SIZE
        r = int(190 - 70 * ratio)
        g = int(25 - 10 * ratio)
        b = int(35 - 15 * ratio)
        pygame.draw.line(token_surf, (r, g, b), (0, yl), (TOKEN_SIZE, yl))

    # 마스크
    mask = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)
    pygame.draw.rect(mask, (255,255,255,255), (0,0,TOKEN_SIZE,TOKEN_SIZE), border_radius=CORNER_RADIUS)
    token_surf.blit(mask, (0,0), special_flags=pygame.BLEND_RGBA_MULT)

    # 상단 광택
    gloss_h = TOKEN_SIZE // 3
    gloss = pygame.Surface((TOKEN_SIZE - 8, gloss_h), pygame.SRCALPHA)
    for yl in range(gloss_h):
        alpha = int(100 * (1 - yl / gloss_h) ** 2)
        pygame.draw.line(gloss, (255, 255, 255, alpha), (0, yl), (TOKEN_SIZE - 8, yl))
    token_surf.blit(gloss, (4, 4))

    # 인너 글로우 (중앙 발광)
    inner = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)
    pygame.draw.rect(inner, (255, 100, 120, 25), (8, 8, TOKEN_SIZE-16, TOKEN_SIZE-16), border_radius=6)
    token_surf.blit(inner, (0, 0))

    # 테두리
    pygame.draw.rect(token_surf, (150, 40, 50), (0,0,TOKEN_SIZE,TOKEN_SIZE), width=2, border_radius=CORNER_RADIUS)

    surface.blit(token_surf, (x, y))
    return "1. Inner Glow"

def draw_token_2(surface, x, y, time_now):
    """2. 글로시 루비 + 더블 테두리"""
    token_surf = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)

    # 베이스
    for yl in range(TOKEN_SIZE):
        ratio = yl / TOKEN_SIZE
        r = int(195 - 75 * ratio)
        g = int(28 - 12 * ratio)
        b = int(38 - 18 * ratio)
        pygame.draw.line(token_surf, (r, g, b), (0, yl), (TOKEN_SIZE, yl))

    mask = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)
    pygame.draw.rect(mask, (255,255,255,255), (0,0,TOKEN_SIZE,TOKEN_SIZE), border_radius=CORNER_RADIUS)
    token_surf.blit(mask, (0,0), special_flags=pygame.BLEND_RGBA_MULT)

    # 광택
    gloss_h = TOKEN_SIZE // 3
    gloss = pygame.Surface((TOKEN_SIZE - 8, gloss_h), pygame.SRCALPHA)
    for yl in range(gloss_h):
        alpha = int(110 * (1 - yl / gloss_h) ** 2)
        pygame.draw.line(gloss, (255, 255, 255, alpha), (0, yl), (TOKEN_SIZE - 8, yl))
    token_surf.blit(gloss, (4, 4))

    # 더블 테두리 (외곽 어둡고 내부 밝게)
    pygame.draw.rect(token_surf, (100, 25, 35), (0,0,TOKEN_SIZE,TOKEN_SIZE), width=3, border_radius=CORNER_RADIUS)
    pygame.draw.rect(token_surf, (180, 60, 70), (2,2,TOKEN_SIZE-4,TOKEN_SIZE-4), width=1, border_radius=CORNER_RADIUS-1)

    surface.blit(token_surf, (x, y))
    return "2. Double Border"

def draw_token_3(surface, x, y, time_now):
    """3. 글로시 루비 + 소프트 섀도우"""
    token_surf = pygame.Surface((TOKEN_SIZE+8, TOKEN_SIZE+8), pygame.SRCALPHA)
    off = 4

    # 소프트 섀도우
    for i in range(3):
        shadow_rect = pygame.Rect(off+2-i, off+2-i, TOKEN_SIZE+i*2, TOKEN_SIZE+i*2)
        pygame.draw.rect(token_surf, (0, 0, 0, 15-i*4), shadow_rect, border_radius=CORNER_RADIUS+i)

    # 베이스
    for yl in range(TOKEN_SIZE):
        ratio = yl / TOKEN_SIZE
        r = int(190 - 70 * ratio)
        g = int(25 - 10 * ratio)
        b = int(35 - 15 * ratio)
        pygame.draw.line(token_surf, (r, g, b), (off, off+yl), (off+TOKEN_SIZE, off+yl))

    mask = pygame.Surface((TOKEN_SIZE+8, TOKEN_SIZE+8), pygame.SRCALPHA)
    pygame.draw.rect(mask, (255,255,255,255), (off,off,TOKEN_SIZE,TOKEN_SIZE), border_radius=CORNER_RADIUS)
    token_surf.blit(mask, (0,0), special_flags=pygame.BLEND_RGBA_MULT)

    # 광택
    gloss_h = TOKEN_SIZE // 3
    gloss = pygame.Surface((TOKEN_SIZE - 8, gloss_h), pygame.SRCALPHA)
    for yl in range(gloss_h):
        alpha = int(100 * (1 - yl / gloss_h) ** 2)
        pygame.draw.line(gloss, (255, 255, 255, alpha), (0, yl), (TOKEN_SIZE - 8, yl))
    token_surf.blit(gloss, (off+4, off+4))

    pygame.draw.rect(token_surf, (140, 35, 45), (off,off,TOKEN_SIZE,TOKEN_SIZE), width=2, border_radius=CORNER_RADIUS)

    surface.blit(token_surf, (x-4, y-4))
    return "3. Soft Shadow"

def draw_token_4(surface, x, y, time_now):
    """4. 글로시 루비 + 베벨 효과"""
    token_surf = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)

    # 베이스
    for yl in range(TOKEN_SIZE):
        ratio = yl / TOKEN_SIZE
        r = int(185 - 65 * ratio)
        g = int(22 - 8 * ratio)
        b = int(32 - 12 * ratio)
        pygame.draw.line(token_surf, (r, g, b), (0, yl), (TOKEN_SIZE, yl))

    mask = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)
    pygame.draw.rect(mask, (255,255,255,255), (0,0,TOKEN_SIZE,TOKEN_SIZE), border_radius=CORNER_RADIUS)
    token_surf.blit(mask, (0,0), special_flags=pygame.BLEND_RGBA_MULT)

    # 광택
    gloss_h = TOKEN_SIZE // 3
    gloss = pygame.Surface((TOKEN_SIZE - 8, gloss_h), pygame.SRCALPHA)
    for yl in range(gloss_h):
        alpha = int(90 * (1 - yl / gloss_h) ** 2)
        pygame.draw.line(gloss, (255, 255, 255, alpha), (0, yl), (TOKEN_SIZE - 8, yl))
    token_surf.blit(gloss, (4, 4))

    # 베벨 (상단 밝고 하단 어둡게)
    pygame.draw.line(token_surf, (220, 80, 90, 150), (CORNER_RADIUS, 2), (TOKEN_SIZE-CORNER_RADIUS, 2), 1)
    pygame.draw.line(token_surf, (80, 15, 25, 150), (CORNER_RADIUS, TOKEN_SIZE-3), (TOKEN_SIZE-CORNER_RADIUS, TOKEN_SIZE-3), 1)

    pygame.draw.rect(token_surf, (130, 30, 40), (0,0,TOKEN_SIZE,TOKEN_SIZE), width=2, border_radius=CORNER_RADIUS)

    surface.blit(token_surf, (x, y))
    return "4. Bevel Effect"

def draw_token_5(surface, x, y, time_now):
    """5. 글로시 루비 + 리치 그라데이션"""
    token_surf = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)

    # 더 풍부한 그라데이션 (3단계)
    for yl in range(TOKEN_SIZE):
        ratio = yl / TOKEN_SIZE
        if ratio < 0.3:
            r, g, b = 210, 45, 55
        elif ratio < 0.7:
            t = (ratio - 0.3) / 0.4
            r = int(210 - 40 * t)
            g = int(45 - 20 * t)
            b = int(55 - 20 * t)
        else:
            t = (ratio - 0.7) / 0.3
            r = int(170 - 50 * t)
            g = int(25 - 10 * t)
            b = int(35 - 15 * t)
        pygame.draw.line(token_surf, (r, g, b), (0, yl), (TOKEN_SIZE, yl))

    mask = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)
    pygame.draw.rect(mask, (255,255,255,255), (0,0,TOKEN_SIZE,TOKEN_SIZE), border_radius=CORNER_RADIUS)
    token_surf.blit(mask, (0,0), special_flags=pygame.BLEND_RGBA_MULT)

    # 강한 광택
    gloss_h = TOKEN_SIZE // 3
    gloss = pygame.Surface((TOKEN_SIZE - 6, gloss_h), pygame.SRCALPHA)
    for yl in range(gloss_h):
        alpha = int(130 * (1 - yl / gloss_h) ** 2.5)
        pygame.draw.line(gloss, (255, 255, 255, alpha), (0, yl), (TOKEN_SIZE - 6, yl))
    token_surf.blit(gloss, (3, 3))

    pygame.draw.rect(token_surf, (140, 35, 45), (0,0,TOKEN_SIZE,TOKEN_SIZE), width=2, border_radius=CORNER_RADIUS)

    surface.blit(token_surf, (x, y))
    return "5. Rich Gradient"

def draw_token_6(surface, x, y, time_now):
    """6. 글로시 루비 + 엣지 하이라이트"""
    token_surf = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)

    # 베이스
    for yl in range(TOKEN_SIZE):
        ratio = yl / TOKEN_SIZE
        r = int(190 - 70 * ratio)
        g = int(25 - 10 * ratio)
        b = int(35 - 15 * ratio)
        pygame.draw.line(token_surf, (r, g, b), (0, yl), (TOKEN_SIZE, yl))

    mask = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)
    pygame.draw.rect(mask, (255,255,255,255), (0,0,TOKEN_SIZE,TOKEN_SIZE), border_radius=CORNER_RADIUS)
    token_surf.blit(mask, (0,0), special_flags=pygame.BLEND_RGBA_MULT)

    # 광택
    gloss_h = TOKEN_SIZE // 3
    gloss = pygame.Surface((TOKEN_SIZE - 8, gloss_h), pygame.SRCALPHA)
    for yl in range(gloss_h):
        alpha = int(100 * (1 - yl / gloss_h) ** 2)
        pygame.draw.line(gloss, (255, 255, 255, alpha), (0, yl), (TOKEN_SIZE - 8, yl))
    token_surf.blit(gloss, (4, 4))

    # 엣지 하이라이트 (좌상단)
    pygame.draw.arc(token_surf, (255, 180, 180, 100), (2, 2, 20, 20), math.pi/2, math.pi, 2)

    pygame.draw.rect(token_surf, (150, 40, 50), (0,0,TOKEN_SIZE,TOKEN_SIZE), width=2, border_radius=CORNER_RADIUS)

    surface.blit(token_surf, (x, y))
    return "6. Edge Highlight"

def draw_token_7(surface, x, y, time_now):
    """7. 글로시 루비 + 딥 새틴"""
    token_surf = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)

    # 새틴 느낌 그라데이션 (더 부드러운 전환)
    for yl in range(TOKEN_SIZE):
        ratio = yl / TOKEN_SIZE
        # 사인 곡선으로 부드러운 전환
        smooth = (math.sin(ratio * math.pi - math.pi/2) + 1) / 2
        r = int(200 - 80 * smooth)
        g = int(30 - 15 * smooth)
        b = int(40 - 20 * smooth)
        pygame.draw.line(token_surf, (r, g, b), (0, yl), (TOKEN_SIZE, yl))

    mask = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)
    pygame.draw.rect(mask, (255,255,255,255), (0,0,TOKEN_SIZE,TOKEN_SIZE), border_radius=CORNER_RADIUS)
    token_surf.blit(mask, (0,0), special_flags=pygame.BLEND_RGBA_MULT)

    # 새틴 광택 (더 넓고 부드럽게)
    gloss_h = TOKEN_SIZE // 2
    gloss = pygame.Surface((TOKEN_SIZE - 6, gloss_h), pygame.SRCALPHA)
    for yl in range(gloss_h):
        alpha = int(70 * (1 - yl / gloss_h) ** 1.5)
        pygame.draw.line(gloss, (255, 255, 255, alpha), (0, yl), (TOKEN_SIZE - 6, yl))
    token_surf.blit(gloss, (3, 3))

    pygame.draw.rect(token_surf, (145, 38, 48), (0,0,TOKEN_SIZE,TOKEN_SIZE), width=2, border_radius=CORNER_RADIUS)

    surface.blit(token_surf, (x, y))
    return "7. Deep Satin"

def draw_token_8(surface, x, y, time_now):
    """8. 글로시 루비 + 프레임드"""
    token_surf = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)

    # 외곽 프레임 (어두운)
    pygame.draw.rect(token_surf, (80, 20, 28), (0,0,TOKEN_SIZE,TOKEN_SIZE), border_radius=CORNER_RADIUS)

    # 내부 루비
    inner_size = TOKEN_SIZE - 8
    inner_surf = pygame.Surface((inner_size, inner_size), pygame.SRCALPHA)
    for yl in range(inner_size):
        ratio = yl / inner_size
        r = int(200 - 70 * ratio)
        g = int(35 - 15 * ratio)
        b = int(45 - 20 * ratio)
        pygame.draw.line(inner_surf, (r, g, b), (0, yl), (inner_size, yl))

    inner_mask = pygame.Surface((inner_size, inner_size), pygame.SRCALPHA)
    pygame.draw.rect(inner_mask, (255,255,255,255), (0,0,inner_size,inner_size), border_radius=CORNER_RADIUS-3)
    inner_surf.blit(inner_mask, (0,0), special_flags=pygame.BLEND_RGBA_MULT)
    token_surf.blit(inner_surf, (4, 4))

    # 내부 광택
    gloss_h = inner_size // 3
    gloss = pygame.Surface((inner_size - 6, gloss_h), pygame.SRCALPHA)
    for yl in range(gloss_h):
        alpha = int(110 * (1 - yl / gloss_h) ** 2)
        pygame.draw.line(gloss, (255, 255, 255, alpha), (0, yl), (inner_size - 6, yl))
    token_surf.blit(gloss, (7, 7))

    # 프레임 하이라이트
    pygame.draw.rect(token_surf, (120, 35, 45), (0,0,TOKEN_SIZE,TOKEN_SIZE), width=1, border_radius=CORNER_RADIUS)

    surface.blit(token_surf, (x, y))
    return "8. Framed Ruby"

def draw_token_9(surface, x, y, time_now):
    """9. 글로시 루비 + 바텀 글로우"""
    token_surf = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)

    # 베이스
    for yl in range(TOKEN_SIZE):
        ratio = yl / TOKEN_SIZE
        r = int(190 - 70 * ratio)
        g = int(25 - 10 * ratio)
        b = int(35 - 15 * ratio)
        pygame.draw.line(token_surf, (r, g, b), (0, yl), (TOKEN_SIZE, yl))

    mask = pygame.Surface((TOKEN_SIZE, TOKEN_SIZE), pygame.SRCALPHA)
    pygame.draw.rect(mask, (255,255,255,255), (0,0,TOKEN_SIZE,TOKEN_SIZE), border_radius=CORNER_RADIUS)
    token_surf.blit(mask, (0,0), special_flags=pygame.BLEND_RGBA_MULT)

    # 상단 광택
    gloss_h = TOKEN_SIZE // 3
    gloss = pygame.Surface((TOKEN_SIZE - 8, gloss_h), pygame.SRCALPHA)
    for yl in range(gloss_h):
        alpha = int(100 * (1 - yl / gloss_h) ** 2)
        pygame.draw.line(gloss, (255, 255, 255, alpha), (0, yl), (TOKEN_SIZE - 8, yl))
    token_surf.blit(gloss, (4, 4))

    # 하단 반사 글로우
    bottom_h = 10
    bottom = pygame.Surface((TOKEN_SIZE - 12, bottom_h), pygame.SRCALPHA)
    for yl in range(bottom_h):
        alpha = int(40 * (yl / bottom_h))
        pygame.draw.line(bottom, (255, 180, 180, alpha), (0, yl), (TOKEN_SIZE - 12, yl))
    token_surf.blit(bottom, (6, TOKEN_SIZE - bottom_h - 4))

    pygame.draw.rect(token_surf, (150, 40, 50), (0,0,TOKEN_SIZE,TOKEN_SIZE), width=2, border_radius=CORNER_RADIUS)

    surface.blit(token_surf, (x, y))
    return "9. Bottom Glow"

def draw_token_10(surface, x, y, time_now):
    """10. 글로시 루비 + 프리미엄"""
    token_surf = pygame.Surface((TOKEN_SIZE+4, TOKEN_SIZE+4), pygame.SRCALPHA)
    off = 2

    # 미세한 외곽 글로우
    pygame.draw.rect(token_surf, (255, 80, 100, 20), (0,0,TOKEN_SIZE+4,TOKEN_SIZE+4), border_radius=CORNER_RADIUS+2)

    # 베이스 (더 깊은 색감)
    for yl in range(TOKEN_SIZE):
        ratio = yl / TOKEN_SIZE
        r = int(195 - 75 * ratio)
        g = int(28 - 13 * ratio)
        b = int(40 - 18 * ratio)
        pygame.draw.line(token_surf, (r, g, b), (off, off+yl), (off+TOKEN_SIZE, off+yl))

    mask = pygame.Surface((TOKEN_SIZE+4, TOKEN_SIZE+4), pygame.SRCALPHA)
    pygame.draw.rect(mask, (255,255,255,255), (off,off,TOKEN_SIZE,TOKEN_SIZE), border_radius=CORNER_RADIUS)
    token_surf.blit(mask, (0,0), special_flags=pygame.BLEND_RGBA_MULT)

    # 프리미엄 광택 (두 레이어)
    gloss_h = TOKEN_SIZE // 3
    gloss = pygame.Surface((TOKEN_SIZE - 8, gloss_h), pygame.SRCALPHA)
    for yl in range(gloss_h):
        alpha = int(120 * (1 - yl / gloss_h) ** 2)
        pygame.draw.line(gloss, (255, 255, 255, alpha), (0, yl), (TOKEN_SIZE - 8, yl))
    token_surf.blit(gloss, (off+4, off+4))

    # 미세한 하이라이트 라인
    pygame.draw.line(token_surf, (255, 200, 200, 60), (off+CORNER_RADIUS, off+3), (off+TOKEN_SIZE-CORNER_RADIUS, off+3), 1)

    # 테두리 (2톤)
    pygame.draw.rect(token_surf, (160, 45, 55), (off,off,TOKEN_SIZE,TOKEN_SIZE), width=2, border_radius=CORNER_RADIUS)
    pygame.draw.rect(token_surf, (120, 30, 40), (off+1,off+1,TOKEN_SIZE-2,TOKEN_SIZE-2), width=1, border_radius=CORNER_RADIUS-1)

    surface.blit(token_surf, (x-2, y-2))
    return "10. Premium"


def main():
    clock = pygame.time.Clock()
    font = pygame.font.Font(None, 24)

    running = True
    while running:
        time_now = pygame.time.get_ticks()

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

        screen.fill(DARK_BG)

        title_font = pygame.font.Font(None, 48)
        title = title_font.render("Glossy Ruby - Premium Upgrades", True, WHITE)
        screen.blit(title, (SCREEN_WIDTH//2 - title.get_width()//2, 30))

        subtitle = font.render("Press ESC to exit | Choose your favorite design", True, (150, 150, 150))
        screen.blit(subtitle, (SCREEN_WIDTH//2 - subtitle.get_width()//2, 70))

        designs = [
            draw_token_1, draw_token_2, draw_token_3, draw_token_4, draw_token_5,
            draw_token_6, draw_token_7, draw_token_8, draw_token_9, draw_token_10
        ]

        start_x = 100
        start_y = 150
        spacing_x = 200
        spacing_y = 220

        for i, draw_func in enumerate(designs):
            row = i // 5
            col = i % 5
            x = start_x + col * spacing_x
            y = start_y + row * spacing_y

            bg_rect = pygame.Rect(x - 30, y - 20, 160, 160)
            pygame.draw.rect(screen, (30, 30, 40), bg_rect, border_radius=10)
            pygame.draw.rect(screen, (50, 50, 60), bg_rect, width=1, border_radius=10)

            token_x = x + 50 - TOKEN_SIZE//2
            token_y = y + 30
            name = draw_func(screen, token_x, token_y, time_now)

            name_surf = font.render(name, True, WHITE)
            screen.blit(name_surf, (x + 50 - name_surf.get_width()//2, y + 100))

        pygame.display.flip()
        clock.tick(60)

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()
