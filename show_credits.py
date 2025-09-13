def show_credits_screen():
    """크레딧 화면 표시"""
    import pygame
    import sys
    import random
    import math
    
    clock = pygame.time.Clock()
    animation_timer = 0
    
    # Import necessary globals
    from pingfighter import (SCREEN, WIDTH, HEIGHT, FontStyle, 
                             SimpleMenuBackground, show_start_screen)
    
    # 사이버펑크 테마 배경
    simple_bg = SimpleMenuBackground(WIDTH, HEIGHT)
    
    # 크레딧 정보
    credits_data = [
        {"role": "Game Director", "name": "caisetgames", "color": (255, 215, 0)},
        {"role": "BGM Sound Director", "name": "BK", "color": (100, 200, 255)},
        {"role": "Programming", "name": "PingFighter Team", "color": (0, 255, 150)},
        {"role": "Special Thanks", "name": "All Players", "color": (255, 150, 200)},
    ]
    
    # 별 효과용 리스트
    stars = []
    for _ in range(150):
        stars.append({
            'x': random.randint(0, WIDTH),
            'y': random.randint(0, HEIGHT),
            'size': random.uniform(0.5, 2.5),
            'twinkle': random.uniform(0, math.pi * 2),
            'speed': random.uniform(0.02, 0.08)
        })
    
    running = True
    while running:
        dt = clock.tick(60) / 1000.0
        animation_timer += dt
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                if event.key in [pygame.K_ESCAPE, pygame.K_RETURN, pygame.K_SPACE]:
                    running = False
                    
        # 배경 그리기
        simple_bg.update(dt)
        simple_bg.draw(SCREEN)
        
        # 별 효과
        for star in stars:
            twinkle = abs(math.sin(star['twinkle'] + animation_timer * star['speed']))
            star_alpha = int(twinkle * 150)
            star_color = (255, 255, 255, star_alpha)
            star_surf = pygame.Surface((int(star['size'] * 4), int(star['size'] * 4)), pygame.SRCALPHA)
            pygame.draw.circle(star_surf, star_color, 
                             (int(star['size'] * 2), int(star['size'] * 2)), int(star['size']))
            SCREEN.blit(star_surf, (star['x'] - star['size'] * 2, star['y'] - star['size'] * 2))
        
        # 타이틀
        font_title = FontStyle.title()  # 60pt
        font_role = FontStyle.subtitle()  # 36pt
        font_name = FontStyle.body()  # 28pt
        font_small = FontStyle.small()  # 20pt
        
        # CREDITS 타이틀 (네온 효과)
        title_y = 80
        
        # 글로우 효과
        for offset in range(10, 0, -2):
            glow_alpha = int(40 * (1 - offset / 10))
            glow_color = (0, 255, 255, glow_alpha)
            glow_surf = font_title.render("CREDITS", True, glow_color)
            glow_rect = glow_surf.get_rect(center=(WIDTH // 2, title_y))
            
            for dx in [-offset, 0, offset]:
                for dy in [-offset, 0, offset]:
                    if dx != 0 or dy != 0:
                        temp_rect = glow_rect.copy()
                        temp_rect.x += dx
                        temp_rect.y += dy
                        SCREEN.blit(glow_surf, temp_rect)
        
        # 메인 타이틀
        title_surf = font_title.render("CREDITS", True, (255, 255, 255))
        title_rect = title_surf.get_rect(center=(WIDTH // 2, title_y))
        SCREEN.blit(title_surf, title_rect)
        
        # 장식 라인
        line_y = title_y + 40
        line_color = (0, 150, 200)
        pygame.draw.line(SCREEN, line_color, (WIDTH // 2 - 150, line_y), (WIDTH // 2 - 50, line_y), 2)
        pygame.draw.line(SCREEN, line_color, (WIDTH // 2 + 50, line_y), (WIDTH // 2 + 150, line_y), 2)
        pygame.draw.circle(SCREEN, (0, 255, 255), (WIDTH // 2 - 150, line_y), 3)
        pygame.draw.circle(SCREEN, (0, 255, 255), (WIDTH // 2 + 150, line_y), 3)
        
        # 크레딧 내용
        start_y = 200
        spacing = 100
        
        for i, credit in enumerate(credits_data):
            y_pos = start_y + i * spacing
            
            # 역할 (작은 폰트, 회색)
            role_surf = font_role.render(credit["role"], True, (150, 150, 150))
            role_rect = role_surf.get_rect(center=(WIDTH // 2, y_pos))
            SCREEN.blit(role_surf, role_rect)
            
            # 이름 (큰 폰트, 컬러풀)
            # 펄스 효과
            pulse = abs(math.sin(animation_timer * 2 + i * 0.5))
            color_intensity = 0.7 + pulse * 0.3
            name_color = tuple(int(c * color_intensity) for c in credit["color"])
            
            # 글로우 효과
            for j in range(3):
                glow_alpha = 80 - j * 25
                glow_color = (*credit["color"], glow_alpha)
                glow_surf = font_name.render(credit["name"], True, glow_color)
                glow_rect = glow_surf.get_rect(center=(WIDTH // 2, y_pos + 35))
                glow_rect.x += j - 1
                glow_rect.y += j - 1
                SCREEN.blit(glow_surf, glow_rect)
            
            # 메인 이름
            name_surf = font_name.render(credit["name"], True, name_color)
            name_rect = name_surf.get_rect(center=(WIDTH // 2, y_pos + 35))
            SCREEN.blit(name_surf, name_rect)
        
        # 하단 안내 메시지
        footer_y = HEIGHT - 50
        footer_text = "Press ESC or SPACE to return"
        footer_surf = font_small.render(footer_text, True, (100, 100, 100))
        footer_rect = footer_surf.get_rect(center=(WIDTH // 2, footer_y))
        
        # 깜빡임 효과
        if int(animation_timer * 2) % 2 == 0:
            SCREEN.blit(footer_surf, footer_rect)
        
        # Copyright
        copyright_text = "© 2025 PingFighter"
        copyright_surf = font_small.render(copyright_text, True, (80, 80, 80))
        copyright_rect = copyright_surf.get_rect(center=(WIDTH // 2, footer_y + 25))
        SCREEN.blit(copyright_surf, copyright_rect)
        
        pygame.display.flip()
    
    # 메인 메뉴로 돌아가기
    show_start_screen()