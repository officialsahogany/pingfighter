# -*- coding: utf-8 -*-
import pygame
import random
import sys
import math
import os

# 리소스 경로 헬퍼 (PyInstaller 호환)
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)


def show_opening_animation(SCREEN, WIDTH, HEIGHT):
    """게임 오프닝 애니메이션 - 간단한 버전"""
    # 애니메이션 상태 변수들
    animation_timer = 0
    fade_alpha = 0
    text_alpha = 0
    logo_scale = 0.1
    logo_y = HEIGHT // 2
    logo_target_y = HEIGHT // 3
    
    # 텍스트 애니메이션
    typing_text = ""
    full_text = "핑파이터"
    typing_speed = 0.1
    typing_timer = 0
    
    # 파티클 효과
    particles = []
    sparkle_particles = []
    shooting_stars = []  # 별똥별
    fuzzy_stars = []     # 뿌연 별들
    
    # 이펙트 변수들
    glow_intensity = 0
    rotation_angle = 0
    
    # 3초 후에 "Press any key" 표시
    show_press_key = False
    press_key_alpha = 0
    
    # 10초 이상 대기 시 특별 애니메이션
    idle_timer = 0
    special_animation_active = False
    special_animation_timer = 0
    
    # 특별 애니메이션용 변수들
    battle_particles = []
    energy_waves = []
    boss_shadows = []
    paddle_projectiles = []
    screen_shake = 0
    flash_alpha = 0
    
    clock = pygame.time.Clock()
    
    while True:
        animation_timer += 1
        typing_timer += typing_speed
        
        # 1초 후에 "Press any key" 표시 시작
        if animation_timer > 60:  # 1초 = 60프레임 (60fps)
            show_press_key = True
            press_key_alpha = min(255, press_key_alpha + 3)
        
        # 특별 애니메이션 중일 때
        if special_animation_active:
            special_animation_timer += 1
            
            # 1.5초(90프레임) 후에 페이드 아웃 시작
            if special_animation_timer > 90:
                fade_alpha = min(255, fade_alpha + 5)
                if fade_alpha >= 255:
                    return  # 완전히 페이드 아웃되면 메뉴로
            
            # 화면 흔들림 효과
            screen_shake = int(10 * math.sin(special_animation_timer * 0.3))
            
            # 플래시 효과
            if special_animation_timer % 120 < 10:
                flash_alpha = 100
            else:
                flash_alpha = max(0, flash_alpha - 5)
            
            # 전투 파티클 생성
            if special_animation_timer % 5 == 0:
                for _ in range(3):
                    battle_particles.append({
                        'x': random.randint(0, WIDTH),
                        'y': random.randint(0, HEIGHT),
                        'dx': random.uniform(-8, 8),
                        'dy': random.uniform(-8, 8),
                        'life': 120,
                        'size': random.randint(3, 8),
                        'color': random.choice([(255, 100, 100), (100, 100, 255), (255, 255, 100), (255, 100, 255)])
                    })
            
            # 에너지 웨이브 생성
            if special_animation_timer % 60 == 0:
                energy_waves.append({
                    'x': WIDTH // 2,
                    'y': HEIGHT // 2,
                    'radius': 0,
                    'max_radius': WIDTH,
                    'speed': 15,
                    'life': 180,
                    'alpha': 255
                })
            
            # 보스 그림자 생성
            if special_animation_timer % 180 == 0:
                boss_shadows.append({
                    'x': random.randint(100, WIDTH - 100),
                    'y': random.randint(100, HEIGHT - 100),
                    'size': random.randint(50, 150),
                    'life': 300,
                    'alpha': 255,
                    'rotation': 0
                })
            
            # 패들 발사체 생성
            if special_animation_timer % 30 == 0:
                paddle_projectiles.append({
                    'x': random.randint(0, WIDTH),
                    'y': HEIGHT,
                    'dx': random.uniform(-5, 5),
                    'dy': random.uniform(-15, -8),
                    'life': 180,
                    'size': random.randint(5, 15)
                })
        
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN:
                if show_press_key:  # 3초 후에만 키 입력 받기
                    if not special_animation_active:
                        # 특별 애니메이션 시작
                        special_animation_active = True
                        special_animation_timer = 0
                        print("!")
                    # 특별 애니메이션이 이미 활성화되어 있으면 무시
        
        # 화면 그리기
        SCREEN.fill((0, 0, 0))  # BLACK
        
        # 특별 애니메이션 중일 때 배경을 더 어둡게
        if special_animation_active:
            SCREEN.fill((10, 5, 15))  # 어두운 보라색 배경
        
        # 배경 그라데이션 애니메이션 (더 화려하게)
        for y in range(HEIGHT):
            color_ratio = y / HEIGHT
            time_factor = math.sin(animation_timer * 0.02) * 0.3 + 0.7
            # 더 화려한 색상 팔레트
            r = int(10 + color_ratio * 100 * time_factor)
            g = int(20 + color_ratio * 150 * time_factor)
            b = int(40 + color_ratio * 180 * time_factor)
            pygame.draw.line(SCREEN, (r, g, b), (0, y), (WIDTH, y))
        
        # 특별 애니메이션 중일 때만 특별 효과들 그리기
        if special_animation_active:
            # 에너지 웨이브 그리기
            for wave in energy_waves[:]:
                wave['radius'] += wave['speed']
                wave['alpha'] = int(255 * (1 - wave['radius'] / wave['max_radius']))
                
                if wave['alpha'] > 0 and wave['radius'] < wave['max_radius']:
                    wave_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
                    pygame.draw.circle(wave_surface, (100, 200, 255, wave['alpha']), 
                                     (wave['x'], wave['y']), wave['radius'], 5)
                    SCREEN.blit(wave_surface, (0, 0))
                else:
                    energy_waves.remove(wave)
            
            # 보스 그림자 그리기
            for shadow in boss_shadows[:]:
                shadow['life'] -= 2
                shadow['alpha'] = int(255 * (shadow['life'] / 300))
                shadow['rotation'] += 2
                
                if shadow['alpha'] > 0:
                    shadow_surface = pygame.Surface((shadow['size'] * 2, shadow['size'] * 2), pygame.SRCALPHA)
                    
                    # 보스 형태 그리기 (간단한 실루엣)
                    center = (shadow['size'], shadow['size'])
                    
                    # 몸체
                    pygame.draw.ellipse(shadow_surface, (100, 0, 100, shadow['alpha']), 
                                      (shadow['size']//4, shadow['size']//4, shadow['size']//2, shadow['size']//2))
                    
                    # 눈
                    eye_size = shadow['size'] // 8
                    pygame.draw.circle(shadow_surface, (255, 0, 0, shadow['alpha']), 
                                     (center[0] - eye_size, center[1] - eye_size), eye_size)
                    pygame.draw.circle(shadow_surface, (255, 0, 0, shadow['alpha']), 
                                     (center[0] + eye_size, center[1] - eye_size), eye_size)
                    
                    # 회전 적용
                    rotated_shadow = pygame.transform.rotate(shadow_surface, shadow['rotation'])
                    shadow_rect = rotated_shadow.get_rect(center=(shadow['x'], shadow['y']))
                    SCREEN.blit(rotated_shadow, shadow_rect)
                else:
                    boss_shadows.remove(shadow)
            
            # 패들 발사체 그리기
            for projectile in paddle_projectiles[:]:
                projectile['x'] += projectile['dx']
                projectile['y'] += projectile['dy']
                projectile['life'] -= 1
                
                if projectile['life'] > 0 and projectile['y'] > -projectile['size']:
                    # 발사체 꼬리 효과
                    for i in range(10):
                        trail_alpha = int(255 * (projectile['life'] / 180) * (1 - i / 10))
                        trail_size = max(1, projectile['size'] * (1 - i / 10))
                        trail_x = projectile['x'] - projectile['dx'] * i * 0.3
                        trail_y = projectile['y'] - projectile['dy'] * i * 0.3
                        
                        if trail_alpha > 0:
                            trail_surface = pygame.Surface((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
                            pygame.draw.circle(trail_surface, (255, 255, 100, trail_alpha), 
                                             (trail_size, trail_size), trail_size)
                            SCREEN.blit(trail_surface, (trail_x - trail_size, trail_y - trail_size))
                    
                    # 발사체 본체
                    alpha = int(255 * (projectile['life'] / 180))
                    size = max(1, projectile['size'])
                    proj_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(proj_surface, (255, 255, 0, alpha), (size, size), size)
                    SCREEN.blit(proj_surface, (projectile['x'] - size, projectile['y'] - size))
                else:
                    paddle_projectiles.remove(projectile)
            
            # 전투 파티클 그리기
            for particle in battle_particles[:]:
                particle['x'] += particle['dx']
                particle['y'] += particle['dy']
                particle['life'] -= 1
                
                if particle['life'] > 0 and 0 <= particle['x'] <= WIDTH and 0 <= particle['y'] <= HEIGHT:
                    alpha = int(255 * (particle['life'] / 120))
                    size = max(1, particle['size'])
                    color = (*particle['color'], alpha)
                    
                    particle_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(particle_surface, color, (size, size), size)
                    SCREEN.blit(particle_surface, (particle['x'] - size, particle['y'] - size))
                else:
                    battle_particles.remove(particle)
            
            # 화면 흔들림 효과 적용
            shake_offset = (random.randint(-abs(screen_shake), abs(screen_shake)), 
                           random.randint(-abs(screen_shake), abs(screen_shake)))
        
        # 배경에 움직이는 파티클 효과 (간단하게)
        if animation_timer % 10 == 0:
            for _ in range(2):
                particles.append({
                    'x': random.randint(0, WIDTH),
                    'y': random.randint(0, HEIGHT),
                    'dx': random.uniform(-1, 1),
                    'dy': random.uniform(-1, 1),
                    'life': 60,
                    'size': 2
                })
        
        # 별똥별 생성 (가끔씩)
        if animation_timer % 120 == 0:  # 2초마다
            shooting_stars.append({
                'x': random.randint(0, WIDTH),
                'y': random.randint(0, HEIGHT // 3),
                'dx': random.uniform(3, 6),
                'dy': random.uniform(2, 4),
                'life': 120,
                'size': random.randint(2, 4),
                'trail_length': random.randint(20, 40)
            })
        
        # 뿌연 별들 생성 (천천히)
        if animation_timer % 180 == 0:  # 3초마다
            for _ in range(random.randint(1, 3)):
                fuzzy_stars.append({
                    'x': random.randint(0, WIDTH),
                    'y': random.randint(0, HEIGHT),
                    'life': 300,
                    'size': random.randint(4, 8),
                    'fade_speed': random.uniform(0.5, 1.5),
                    'alpha': 255
                })
        
        # 로고 스케일 애니메이션 (더 부드럽게)
        logo_scale = min(1.3, logo_scale + 0.012)
        logo_y = logo_y + (logo_target_y - logo_y) * 0.025
        
        # 로고 그리기 (더 화려한 버전)
        logo_surface = pygame.Surface((600, 300), pygame.SRCALPHA)
        
        # 특별 애니메이션 중일 때 로고에 특별 효과
        if special_animation_active:
            # 로고에 전투 효과 추가
            for i in range(20):
                spark_x = random.randint(0, 600)
                spark_y = random.randint(0, 300)
                spark_size = random.randint(2, 6)
                spark_alpha = random.randint(50, 150)
                pygame.draw.circle(logo_surface, (255, 255, 0, spark_alpha), (spark_x, spark_y), spark_size)
        
        # 외곽 글로우 효과 (더 강하게)
        glow_radius = int(25 + math.sin(animation_timer * 0.08) * 15)
        for i in range(glow_radius, 0, -2):
            alpha = int(120 * (1 - i / glow_radius))
            # 무지개 색상 효과
            hue = (animation_timer * 2 + i * 10) % 360
            if hue < 60:
                color = (255, int(255 * hue / 60), 0, alpha)
            elif hue < 120:
                color = (int(255 * (120 - hue) / 60), 255, 0, alpha)
            elif hue < 180:
                color = (0, 255, int(255 * (hue - 120) / 60), alpha)
            elif hue < 240:
                color = (0, int(255 * (240 - hue) / 60), 255, alpha)
            elif hue < 300:
                color = (int(255 * (hue - 240) / 60), 0, 255, alpha)
            else:
                color = (255, 0, int(255 * (360 - hue) / 60), alpha)
            pygame.draw.rect(logo_surface, color, (i, i, 600 - i*2, 300 - i*2), 4)
        
        # 메인 로고 프레임 (더 화려하게)
        pygame.draw.rect(logo_surface, (150, 200, 255), (0, 0, 600, 300), 10)
        pygame.draw.rect(logo_surface, (200, 220, 255), (15, 15, 570, 270), 5)
        
        # 내부 장식 (더 복잡하게)
        for i in range(8):
            x = 50 + i * 70
            y = 50 + math.sin(animation_timer * 0.05 + i * 0.5) * 15
            size = 10 + math.sin(animation_timer * 0.03 + i) * 5
            pygame.draw.circle(logo_surface, (255, 255, 255), (int(x), int(y)), int(size))
            pygame.draw.circle(logo_surface, (100, 150, 255), (int(x), int(y)), int(size), 2)
        
        # 코너 장식
        corner_size = 20
        for corner in [(0, 0), (600-corner_size, 0), (0, 300-corner_size), (600-corner_size, 300-corner_size)]:
            pygame.draw.rect(logo_surface, (255, 255, 0), (corner[0], corner[1], corner_size, corner_size))
            pygame.draw.rect(logo_surface, (255, 255, 255), (corner[0], corner[1], corner_size, corner_size), 2)
        
        # 텍스트 타이핑 효과 (한글로 변경)
        if typing_timer >= 1:
            if len(typing_text) < len(full_text):
                typing_text = full_text[:len(typing_text) + 1]
                typing_timer = 0
        
        try:
            font_large = pygame.font.Font(resource_path("NanumSquareB.ttf"), 72)
        except:
            font_large = pygame.font.Font(None, 72)
        
        # 텍스트 그림자 (더 강하게)
        for i in range(5, 0, -1):
            shadow_alpha = int(80 * (1 - i / 5))
            shadow_color = (50, 75, 127, shadow_alpha)
            shadow_surface = pygame.Surface((600, 300), pygame.SRCALPHA)
            shadow_text = font_large.render(typing_text, True, shadow_color)
            shadow_rect = shadow_text.get_rect(center=(302 + i*2, 152 + i*2))
            shadow_surface.blit(shadow_text, shadow_rect)
            logo_surface.blit(shadow_surface, (0, 0))
        
        # 메인 텍스트 (한글로 변경)
        full_text = "핑파이터"
        if len(typing_text) < len(full_text):
            typing_text = full_text[:len(typing_text) + 1]
        
        # 텍스트 글로우 효과
        for i in range(8, 0, -1):
            alpha = int(100 * (1 - i / 8))
            glow_color = (255, 255, 0, alpha)
            glow_surface = pygame.Surface((600, 300), pygame.SRCALPHA)
            glow_text = font_large.render(typing_text, True, glow_color)
            glow_rect = glow_text.get_rect(center=(300 + i, 150 + i))
            glow_surface.blit(glow_text, glow_rect)
            logo_surface.blit(glow_surface, (0, 0))
        
        text_surface = font_large.render(typing_text, True, (255, 255, 255))
        text_rect = text_surface.get_rect(center=(300, 150))
        logo_surface.blit(text_surface, text_rect)
        
        # 서브 타이틀
        try:
            font_medium = pygame.font.Font(resource_path("NanumSquareR.ttf"), 32)
        except:
            font_medium = pygame.font.Font(None, 32)
        
        subtitle_text = font_medium.render("핑퐁으로 보스를 물리쳐라!", True, (200, 220, 255))
        subtitle_rect = subtitle_text.get_rect(center=(300, 200))
        logo_surface.blit(subtitle_text, subtitle_rect)
        
        # 스케일 적용
        scaled_logo = pygame.transform.scale(logo_surface, 
                                           (int(600 * logo_scale), int(300 * logo_scale)))
        
        # 화면 흔들림 효과 적용
        if special_animation_active:
            logo_rect = scaled_logo.get_rect(center=(WIDTH // 2 + shake_offset[0], logo_y + shake_offset[1]))
        else:
            logo_rect = scaled_logo.get_rect(center=(WIDTH // 2, logo_y))
        
        SCREEN.blit(scaled_logo, logo_rect)
        
        # 스파클 파티클 (간단하게)
        if animation_timer % 15 == 0:
            for _ in range(3):
                sparkle_particles.append({
                    'x': random.randint(0, WIDTH),
                    'y': random.randint(0, HEIGHT),
                    'life': 60,
                    'size': 3
                })
        
        # 화면 전체 글로우 효과
        if animation_timer > 100:
            glow_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            glow_alpha = int(20 * math.sin(animation_timer * 0.05))
            glow_surface.fill((255, 255, 255))
            glow_surface.set_alpha(glow_alpha)
            SCREEN.blit(glow_surface, (0, 0))
        
        # 플래시 효과
        if flash_alpha > 0:
            flash_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            flash_surface.fill((255, 255, 255))
            flash_surface.set_alpha(flash_alpha)
            SCREEN.blit(flash_surface, (0, 0))
        
        # 페이드 아웃 효과
        if fade_alpha > 0:
            fade_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            fade_surface.fill((0, 0, 0))
            fade_surface.set_alpha(fade_alpha)
            SCREEN.blit(fade_surface, (0, 0))
        
        # "Press any key" 문구 (3초 후에 나타남)
        if show_press_key and not special_animation_active:
            try:
                font_small = pygame.font.Font(resource_path("NanumSquareR.ttf"), 24)
            except:
                font_small = pygame.font.Font(None, 24)
            
            # 깜빡이는 효과
            if animation_timer % 60 < 30:
                press_text = font_small.render("아무 키나 누르세요", True, (200, 200, 200))
                press_surface = pygame.Surface((WIDTH, 50), pygame.SRCALPHA)
                press_surface.fill((0, 0, 0, press_key_alpha))
                press_rect = press_text.get_rect(center=(WIDTH // 2, HEIGHT - 80))
                press_surface.blit(press_text, press_rect)
                SCREEN.blit(press_surface, (0, HEIGHT - 100))
        
        # 파티클 업데이트 및 그리기
        # 배경 파티클
        for particle in particles[:]:
            particle['x'] += particle['dx']
            particle['y'] += particle['dy']
            particle['life'] -= 1
            
            if particle['life'] > 0:
                alpha = int(255 * (particle['life'] / 60))
                size = max(1, particle['size'])  # 최소 크기 1로 제한
                particle_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                # 기본 흰색으로 파티클 그리기
                pygame.draw.circle(particle_surface, (255, 255, 255, alpha), (size, size), size)
                SCREEN.blit(particle_surface, (particle['x'] - size, particle['y'] - size))
            else:
                particles.remove(particle)
        
        # 스파클 파티클
        for particle in sparkle_particles[:]:
            particle['life'] -= 1
            if particle['life'] > 0:
                alpha = int(255 * (particle['life'] / 60))
                size = max(1, particle['size'])  # 최소 크기 1로 제한
                sparkle_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                # 기본 흰색으로 스파클 그리기
                pygame.draw.circle(sparkle_surface, (255, 255, 255, alpha), (size, size), size)
                SCREEN.blit(sparkle_surface, (particle['x'] - size, particle['y'] - size))
            else:
                sparkle_particles.remove(particle)
        
        # 별똥별 업데이트 및 그리기
        for star in shooting_stars[:]:
            star['x'] += star['dx']
            star['y'] += star['dy']
            star['life'] -= 1
            
            if star['life'] > 0 and star['x'] < WIDTH + 50 and star['y'] < HEIGHT + 50:
                # 별똥별 꼬리 그리기
                for i in range(star['trail_length']):
                    trail_alpha = int(255 * (star['life'] / 120) * (1 - i / star['trail_length']))
                    trail_size = max(1, star['size'] * (1 - i / star['trail_length']))
                    trail_x = star['x'] - star['dx'] * i * 0.5
                    trail_y = star['y'] - star['dy'] * i * 0.5
                    
                    if trail_alpha > 0 and trail_size > 0:
                        trail_surface = pygame.Surface((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(trail_surface, (255, 255, 255, trail_alpha), (trail_size, trail_size), trail_size)
                        SCREEN.blit(trail_surface, (trail_x - trail_size, trail_y - trail_size))
                
                # 별똥별 본체
                alpha = int(255 * (star['life'] / 120))
                size = max(1, star['size'])
                star_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(star_surface, (255, 255, 255, alpha), (size, size), size)
                SCREEN.blit(star_surface, (star['x'] - size, star['y'] - size))
            else:
                shooting_stars.remove(star)
        
        # 뿌연 별들 업데이트 및 그리기
        for star in fuzzy_stars[:]:
            star['life'] -= star['fade_speed']
            star['alpha'] = int(255 * (star['life'] / 300))
            
            if star['life'] > 0 and star['alpha'] > 0:
                # 뿌연 별 그리기 (여러 개의 작은 원으로)
                size = max(1, star['size'])
                for i in range(3):
                    offset = i * 2
                    fuzzy_alpha = int(star['alpha'] * (1 - i * 0.3))
                    fuzzy_size = max(1, size - i * 2)
                    
                    if fuzzy_alpha > 0 and fuzzy_size > 0:
                        fuzzy_surface = pygame.Surface((fuzzy_size * 2, fuzzy_size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(fuzzy_surface, (255, 255, 255, fuzzy_alpha), (fuzzy_size, fuzzy_size), fuzzy_size)
                        SCREEN.blit(fuzzy_surface, (star['x'] - fuzzy_size + offset, star['y'] - fuzzy_size + offset))
            else:
                fuzzy_stars.remove(star)
        
        pygame.display.flip()
        clock.tick(60) 