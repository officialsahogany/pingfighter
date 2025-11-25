def show_credits_screen():
    """크레딧 화면 표시"""
    import pygame
    import sys
    import random
    import math

    clock = pygame.time.Clock()
    animation_timer = 0

    # 필요한 글로벌 객체 로드
    from pingfighter import (
        SCREEN,
        WIDTH,
        HEIGHT,
        FontStyle,
        SimpleMenuBackground,
        show_start_screen,
    )

    # 심플 배경
    simple_bg = SimpleMenuBackground(WIDTH, HEIGHT)

    # 크레딧 정보
    credits_data = [
        {"role": "Game Director", "name": "Caisetgames", "color": (255, 215, 0)},
        {"role": "Producer", "name": "HAPPYMILDVIBE", "color": (255, 230, 120)},
        {"role": "BGM Sound Director", "name": "BK22", "color": (100, 200, 255)},
        {"role": "Programming", "name": "Jaeyeob Woo", "color": (0, 255, 150)},
        {"role": "QA Tester", "name": "정혜리", "color": (180, 220, 255)},
        {"role": "Special Thanks", "name": "All Players", "color": (255, 150, 200)},
    ]

    # 배경 별 효과
    stars = []
    for _ in range(150):
        stars.append(
            {
                "x": random.randint(0, WIDTH),
                "y": random.randint(0, HEIGHT),
                "size": random.uniform(0.5, 2.5),
                "twinkle": random.uniform(0, math.pi * 2),
                "speed": random.uniform(0.02, 0.08),
            }
        )

    running = True
    while running:
        dt = clock.tick(60) / 1000.0
        animation_timer += dt

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN and event.key in (
                pygame.K_ESCAPE,
                pygame.K_RETURN,
                pygame.K_SPACE,
            ):
                running = False

        # 배경 갱신
        simple_bg.update(dt)
        simple_bg.draw(SCREEN)

        # 반투명 오버레이
        overlay = pygame.Surface((WIDTH, HEIGHT))
        overlay.set_alpha(180)
        overlay.fill((0, 0, 0))
        SCREEN.blit(overlay, (0, 0))

        # 별 반짝임
        for star in stars:
            twinkle = abs(math.sin(star["twinkle"] + animation_timer * star["speed"]))
            star_alpha = int(twinkle * 150)
            star_color = (255, 255, 255, star_alpha)
            star_surf = pygame.Surface(
                (int(star["size"] * 4), int(star["size"] * 4)), pygame.SRCALPHA
            )
            pygame.draw.circle(
                star_surf,
                star_color,
                (int(star["size"] * 2), int(star["size"] * 2)),
                int(star["size"]),
            )
            SCREEN.blit(
                star_surf,
                (star["x"] - star["size"] * 2, star["y"] - star["size"] * 2),
            )

        # 폰트
        font_title = FontStyle.title()
        font_role = FontStyle.subtitle()
        font_name = FontStyle.body()
        font_small = FontStyle.small()

        # 제목 글로우
        title_y = 80
        for offset in range(10, 0, -2):
            glow_alpha = int(40 * (1 - offset / 10))
            glow_color = (0, 255, 255, glow_alpha)
            glow_surf = font_title.render("CREDITS", True, glow_color)
            glow_rect = glow_surf.get_rect(center=(WIDTH // 2, title_y))
            for dx in [-offset, 0, offset]:
                for dy in [-offset, 0, offset]:
                    if dx or dy:
                        temp_rect = glow_rect.copy()
                        temp_rect.x += dx
                        temp_rect.y += dy
                        SCREEN.blit(glow_surf, temp_rect)

        title_surf = font_title.render("CREDITS", True, (255, 255, 255))
        title_rect = title_surf.get_rect(center=(WIDTH // 2, title_y))
        SCREEN.blit(title_surf, title_rect)

        # 제목 밑 라인
        line_y = title_y + 40
        line_color = (0, 150, 200)
        pygame.draw.line(SCREEN, line_color, (WIDTH // 2 - 150, line_y), (WIDTH // 2 - 50, line_y), 2)
        pygame.draw.line(SCREEN, line_color, (WIDTH // 2 + 50, line_y), (WIDTH // 2 + 150, line_y), 2)
        pygame.draw.circle(SCREEN, (0, 255, 255), (WIDTH // 2 - 150, line_y), 3)
        pygame.draw.circle(SCREEN, (0, 255, 255), (WIDTH // 2 + 150, line_y), 3)

        # 크레딧 본문
        start_y = 200
        spacing = 100
        for i, credit in enumerate(credits_data):
            y_pos = start_y + i * spacing
            role_surf = font_role.render(credit["role"], True, (200, 200, 200))
            role_rect = role_surf.get_rect(center=(WIDTH // 2, y_pos))
            SCREEN.blit(role_surf, role_rect)

            name_surf = font_name.render(credit["name"], True, credit["color"])
            name_rect = name_surf.get_rect(center=(WIDTH // 2, y_pos + 35))
            SCREEN.blit(name_surf, name_rect)

        # 하단 안내 메시지
        footer_y = HEIGHT - 50
        footer_text = "Press ESC or SPACE to return"
        footer_surf = font_small.render(footer_text, True, (100, 100, 100))
        footer_rect = footer_surf.get_rect(center=(WIDTH // 2, footer_y))
        if int(animation_timer * 2) % 2 == 0:
            SCREEN.blit(footer_surf, footer_rect)

        # Copyright
        copyright_text = "© 2025 PingFighter"
        copyright_surf = font_small.render(copyright_text, True, (80, 80, 80))
        copyright_rect = copyright_surf.get_rect(center=(WIDTH // 2, footer_y + 25))
        SCREEN.blit(copyright_surf, copyright_rect)

        pygame.display.flip()

    # 메인 메뉴로 복귀
    show_start_screen()
