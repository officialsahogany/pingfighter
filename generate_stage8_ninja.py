"""Stage 8 배경 생성 스크립트 - 닌자 저택 (음습하고 어두운 일본풍)

음습하고 어두운 분위기의 일본풍 닌자 저택 맵.
스타디움 라인과 중앙 서클을 유지하면서 깔끔한 디자인.
"""

import math
import random

import pygame

# 게임 화면 크기
WIDTH = 600
HEIGHT = 750

# 색상 팔레트 - 어두운 일본풍 닌자 저택
DARK_WOOD = (25, 20, 18)           # 매우 어두운 나무색
DARK_TATAMI = (35, 32, 25)         # 어두운 다다미
SHADOW_BLACK = (12, 10, 15)        # 그림자
BLOOD_RED_DIM = (60, 15, 15)       # 희미한 붉은색 (피/위험)
PAPER_SCREEN = (45, 42, 38)        # 어두운 창호지
MOON_GLOW = (80, 85, 100)          # 달빛 (파란 빛)
NINJA_PURPLE = (35, 25, 50)        # 닌자 보라색
LANTERN_ORANGE = (120, 60, 20)     # 등불 주황색 (어두운)
GOLD_ACCENT = (100, 80, 30)        # 금색 강조

# 스타디움 라인 색상 - 어두운 붉은빛
STADIUM_LINE_COLOR = (100, 40, 40)
STADIUM_LINE_GLOW = (140, 50, 50)
STADIUM_CIRCLE_COLOR = (90, 35, 35)


def generate_stage8_background():
    """Stage 8 닌자 저택 배경 생성"""
    pygame.init()
    background = pygame.Surface((WIDTH, HEIGHT))

    # 1. 기본 배경 그라데이션 (위에서 아래로 어두운 그라데이션)
    for y in range(HEIGHT):
        ratio = y / HEIGHT
        # 위쪽은 더 어둡게 (천장/그림자), 아래쪽은 약간 밝게 (바닥)
        r = int(15 + ratio * 20)
        g = int(12 + ratio * 18)
        b = int(18 + ratio * 15)
        pygame.draw.line(background, (r, g, b), (0, y), (WIDTH, y))

    # 2. 다다미 패턴 (바닥 느낌)
    draw_tatami_floor(background)

    # 3. 벽면 패널/장지문 패턴 (양쪽 벽)
    draw_wall_panels(background)

    # 4. 천장 서까래 패턴
    draw_ceiling_beams(background)

    # 5. 음습한 그림자 오버레이
    draw_shadows(background)

    # 6. 은은한 달빛 효과
    draw_moonlight(background)

    # 7. 등불 장식 (양쪽 벽에)
    draw_lanterns(background)

    # 8. 닌자 가문 문양 (중앙 장식)
    draw_clan_emblem(background)

    # 9. 스타디움 라인과 중앙 서클 (마지막에 그려서 잘 보이게)
    draw_stadium_elements(background)

    # 10. 먼지/미립자 효과
    draw_dust_particles(background)

    return background


def draw_tatami_floor(surface):
    """다다미 바닥 패턴"""
    tatami_height = 60
    tatami_width = 90

    # 바닥 영역 (화면 하단 2/3)
    floor_start_y = HEIGHT // 4

    for row in range(floor_start_y, HEIGHT, tatami_height):
        offset = (row // tatami_height % 2) * (tatami_width // 2)
        for col in range(-tatami_width, WIDTH + tatami_width, tatami_width):
            x = col + offset
            y = row

            # 다다미 매트 색상 (미세하게 다른 톤)
            color_var = random.randint(-5, 5)
            tatami_color = (
                max(0, min(255, 35 + color_var)),
                max(0, min(255, 32 + color_var)),
                max(0, min(255, 25 + color_var))
            )

            # 다다미 매트 그리기
            rect = pygame.Rect(x, y, tatami_width - 2, tatami_height - 2)
            pygame.draw.rect(surface, tatami_color, rect)

            # 다다미 테두리 (짙은 선)
            border_color = (20, 18, 15)
            pygame.draw.rect(surface, border_color, rect, 1)

            # 다다미 질감 라인 (세로 줄무늬)
            for lx in range(x + 5, x + tatami_width - 5, 6):
                line_color = (30, 28, 22)
                pygame.draw.line(surface, line_color,
                               (lx, y + 2), (lx, y + tatami_height - 4))


def draw_wall_panels(surface):
    """벽면 장지문/패널 패턴"""
    panel_width = 60
    panel_height = HEIGHT // 3

    # 왼쪽 벽
    for i, y in enumerate(range(0, HEIGHT, panel_height)):
        # 패널 프레임 (나무틀)
        frame_rect = pygame.Rect(0, y, panel_width, panel_height)
        pygame.draw.rect(surface, DARK_WOOD, frame_rect)

        # 장지문 안쪽 (밝은 종이 느낌이지만 어둡게)
        inner_rect = pygame.Rect(5, y + 5, panel_width - 10, panel_height - 10)
        pygame.draw.rect(surface, PAPER_SCREEN, inner_rect)

        # 창살 무늬 (격자)
        for gx in range(10, panel_width - 5, 15):
            pygame.draw.line(surface, DARK_WOOD,
                           (gx, y + 5), (gx, y + panel_height - 5), 1)
        for gy in range(y + 10, y + panel_height - 5, 20):
            pygame.draw.line(surface, DARK_WOOD,
                           (5, gy), (panel_width - 5, gy), 1)

    # 오른쪽 벽
    for i, y in enumerate(range(0, HEIGHT, panel_height)):
        x_start = WIDTH - panel_width
        frame_rect = pygame.Rect(x_start, y, panel_width, panel_height)
        pygame.draw.rect(surface, DARK_WOOD, frame_rect)

        inner_rect = pygame.Rect(x_start + 5, y + 5, panel_width - 10, panel_height - 10)
        pygame.draw.rect(surface, PAPER_SCREEN, inner_rect)

        for gx in range(x_start + 10, WIDTH - 5, 15):
            pygame.draw.line(surface, DARK_WOOD,
                           (gx, y + 5), (gx, y + panel_height - 5), 1)
        for gy in range(y + 10, y + panel_height - 5, 20):
            pygame.draw.line(surface, DARK_WOOD,
                           (x_start + 5, gy), (WIDTH - 5, gy), 1)


def draw_ceiling_beams(surface):
    """천장 서까래 패턴"""
    beam_spacing = 80
    beam_thickness = 12

    # 상단 영역에만 (위쪽 1/4)
    for y in range(0, HEIGHT // 4, beam_spacing):
        # 가로 서까래
        beam_color = (20, 16, 14)
        pygame.draw.rect(surface, beam_color,
                        (60, y, WIDTH - 120, beam_thickness))

        # 서까래 하이라이트 (나무 질감)
        highlight_color = (30, 24, 20)
        pygame.draw.line(surface, highlight_color,
                        (60, y + 2), (WIDTH - 60, y + 2), 1)


def draw_shadows(surface):
    """음습한 그림자 오버레이"""
    shadow_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)

    # 모서리 그림자 (비네트 효과)
    for i in range(50):
        alpha = max(0, 100 - i * 2)

        # 왼쪽 그림자
        pygame.draw.rect(shadow_surface, (0, 0, 0, alpha),
                        (0, 0, i * 2, HEIGHT))
        # 오른쪽 그림자
        pygame.draw.rect(shadow_surface, (0, 0, 0, alpha),
                        (WIDTH - i * 2, 0, i * 2, HEIGHT))
        # 상단 그림자
        pygame.draw.rect(shadow_surface, (0, 0, 0, alpha),
                        (0, 0, WIDTH, i * 2))
        # 하단 그림자 (약하게)
        pygame.draw.rect(shadow_surface, (0, 0, 0, alpha // 2),
                        (0, HEIGHT - i, WIDTH, i))

    # 불규칙한 그림자 패치
    for _ in range(15):
        sx = random.randint(80, WIDTH - 80)
        sy = random.randint(50, HEIGHT - 50)
        sw = random.randint(40, 100)
        sh = random.randint(30, 80)
        shadow_alpha = random.randint(20, 50)

        # 타원형 그림자
        shadow_ellipse = pygame.Surface((sw, sh), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_ellipse, (0, 0, 10, shadow_alpha),
                           (0, 0, sw, sh))
        shadow_surface.blit(shadow_ellipse, (sx - sw // 2, sy - sh // 2))

    surface.blit(shadow_surface, (0, 0))


def draw_moonlight(surface):
    """은은한 달빛 효과 (창문을 통해 들어오는 빛)"""
    moonlight_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)

    # 오른쪽 위에서 들어오는 대각선 달빛
    light_start_x = WIDTH - 100
    light_start_y = 50
    light_width = 150
    light_length = 400

    # 빛 줄기 (여러 겹으로 그라데이션)
    for i in range(30):
        alpha = max(0, 15 - i // 2)
        offset = i * 5

        points = [
            (light_start_x - offset, light_start_y),
            (light_start_x + light_width // 2 - offset, light_start_y),
            (light_start_x - 50 - offset, light_start_y + light_length),
            (light_start_x - 100 - offset, light_start_y + light_length)
        ]
        pygame.draw.polygon(moonlight_surface, (*MOON_GLOW, alpha), points)

    # 달빛 하이라이트 (매우 희미한 원형)
    for _ in range(5):
        mx = random.randint(WIDTH // 2, WIDTH - 100)
        my = random.randint(50, HEIGHT // 3)
        mr = random.randint(30, 60)
        pygame.draw.circle(moonlight_surface, (*MOON_GLOW, 8), (mx, my), mr)

    surface.blit(moonlight_surface, (0, 0))


def draw_lanterns(surface):
    """등불 장식 (양쪽 벽에)"""
    lantern_positions = [
        (35, 180),      # 왼쪽 상단
        (35, HEIGHT - 220),   # 왼쪽 하단
        (WIDTH - 35, 180),    # 오른쪽 상단
        (WIDTH - 35, HEIGHT - 220),  # 오른쪽 하단
    ]

    for lx, ly in lantern_positions:
        # 등불 줄
        pygame.draw.line(surface, DARK_WOOD, (lx, ly - 30), (lx, ly), 2)

        # 등불 본체 (사각형 등롱)
        lantern_w = 20
        lantern_h = 30

        # 등불 프레임
        frame_color = (40, 30, 20)
        pygame.draw.rect(surface, frame_color,
                        (lx - lantern_w // 2, ly, lantern_w, lantern_h), 2)

        # 등불 빛 (내부)
        glow_surface = pygame.Surface((lantern_w - 4, lantern_h - 4), pygame.SRCALPHA)
        for gi in range(10):
            glow_alpha = max(0, 40 - gi * 4)
            glow_color = (120, 60, 20, glow_alpha)
            pygame.draw.rect(glow_surface, glow_color,
                           (gi, gi, lantern_w - 4 - gi * 2, lantern_h - 4 - gi * 2))
        surface.blit(glow_surface, (lx - lantern_w // 2 + 2, ly + 2))

        # 등불 주변 빛 번짐 효과
        for ri in range(5):
            glow_radius = 25 + ri * 8
            glow_alpha = max(0, 15 - ri * 3)
            pygame.draw.circle(surface, (*LANTERN_ORANGE[:2], 30, glow_alpha),
                             (lx, ly + lantern_h // 2), glow_radius)


def draw_clan_emblem(surface):
    """닌자 가문 문양 (중앙 장식)"""
    center_x = WIDTH // 2
    center_y = HEIGHT // 2

    # 문양 배경 원 (희미한 붉은색)
    emblem_radius = 60
    emblem_surface = pygame.Surface((emblem_radius * 2 + 20, emblem_radius * 2 + 20), pygame.SRCALPHA)

    # 여러 겹의 원으로 글로우 효과
    for i in range(15):
        r = emblem_radius + i * 2
        alpha = max(0, 20 - i * 2)
        pygame.draw.circle(emblem_surface, (*BLOOD_RED_DIM, alpha),
                          (emblem_radius + 10, emblem_radius + 10), r, 1)

    # 문양 본체 - 수리검 형태의 별 (6개의 뾰족한 끝)
    num_points = 6
    for i in range(num_points):
        angle = math.radians(i * 60 - 90)
        inner_angle = math.radians(i * 60 + 30 - 90)

        # 바깥 뾰족점
        ox = emblem_radius + 10 + math.cos(angle) * (emblem_radius - 10)
        oy = emblem_radius + 10 + math.sin(angle) * (emblem_radius - 10)

        # 안쪽 들어간 점
        ix = emblem_radius + 10 + math.cos(inner_angle) * 25
        iy = emblem_radius + 10 + math.sin(inner_angle) * 25

        # 중심과 연결
        pygame.draw.line(emblem_surface, (*BLOOD_RED_DIM, 40),
                        (emblem_radius + 10, emblem_radius + 10), (ox, oy), 2)

    # 중앙 원
    pygame.draw.circle(emblem_surface, BLOOD_RED_DIM,
                      (emblem_radius + 10, emblem_radius + 10), 15, 2)
    pygame.draw.circle(emblem_surface, (*BLOOD_RED_DIM, 30),
                      (emblem_radius + 10, emblem_radius + 10), 8)

    surface.blit(emblem_surface, (center_x - emblem_radius - 10, center_y - emblem_radius - 10))


def draw_stadium_elements(surface):
    """스타디움 라인과 중앙 서클"""
    center_x = WIDTH // 2
    center_y = HEIGHT // 2
    stadium_radius = 80

    # 1. 중앙 가로 라인 글로우 효과
    line_y = center_y

    # 글로우 레이어
    for i in range(5):
        glow_alpha = max(0, 60 - i * 15)
        glow_color = (*STADIUM_LINE_GLOW, glow_alpha)
        glow_surface = pygame.Surface((WIDTH, 6 + i * 2), pygame.SRCALPHA)
        pygame.draw.line(glow_surface, glow_color,
                        (0, 3 + i), (WIDTH, 3 + i), 2 + i)
        surface.blit(glow_surface, (0, line_y - 3 - i))

    # 메인 라인
    pygame.draw.line(surface, STADIUM_LINE_COLOR, (0, line_y), (WIDTH, line_y), 2)
    # 내부 밝은 라인
    pygame.draw.line(surface, STADIUM_LINE_GLOW, (0, line_y), (WIDTH, line_y), 1)

    # 2. 중앙 서클 글로우 효과
    for i in range(6):
        glow_alpha = max(0, 40 - i * 8)
        radius = stadium_radius + i * 3
        pygame.draw.circle(surface, (*STADIUM_LINE_GLOW, glow_alpha),
                          (center_x, center_y), radius, 2)

    # 메인 서클
    pygame.draw.circle(surface, STADIUM_LINE_COLOR, (center_x, center_y), stadium_radius, 3)
    # 내부 장식 서클
    pygame.draw.circle(surface, STADIUM_LINE_GLOW, (center_x, center_y), stadium_radius - 5, 1)
    pygame.draw.circle(surface, (*STADIUM_LINE_COLOR, 80), (center_x, center_y), stadium_radius - 15, 1)

    # 3. 센터 도트 (작은 장식)
    pygame.draw.circle(surface, STADIUM_LINE_GLOW, (center_x, center_y), 5)
    pygame.draw.circle(surface, STADIUM_LINE_COLOR, (center_x, center_y), 3)


def draw_dust_particles(surface):
    """먼지/미립자 효과 (음습한 분위기)"""
    dust_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)

    for _ in range(50):
        dx = random.randint(70, WIDTH - 70)
        dy = random.randint(30, HEIGHT - 30)
        dr = random.randint(1, 3)
        dalpha = random.randint(15, 40)

        # 먼지 입자 (어두운 색조)
        dust_color = (80, 75, 70, dalpha)
        pygame.draw.circle(dust_surface, dust_color, (dx, dy), dr)

    surface.blit(dust_surface, (0, 0))


def main():
    """메인 실행 함수"""
    background = generate_stage8_background()

    # 이미지 저장
    pygame.image.save(background, "stage8_field.png")
    print("Stage 8 배경 생성 완료: stage8_field.png")

    # 미리보기 창
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Stage 8 - Ninja Mansion Preview")

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_r:
                    # R키로 재생성
                    background = generate_stage8_background()
                    pygame.image.save(background, "stage8_field.png")
                    print("배경 재생성 완료!")

        screen.blit(background, (0, 0))
        pygame.display.flip()

    pygame.quit()


if __name__ == "__main__":
    main()
