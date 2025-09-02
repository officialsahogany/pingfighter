import pygame
import random
import math
import sys

def show_cinematic_scenes(SCREEN, WIDTH, HEIGHT):
    """환상적인 시네마틱 영상 - 6개 장면"""
    
    # 기본 설정
    clock = pygame.time.Clock()
    scene_timer = 0
    current_scene = 0
    transition_alpha = 0
    transitioning = False
    final_fadeout = False
    final_fadeout_alpha = 0
    
    # 각 장면 지속 시간 (4-5초, 60fps 기준)
    scene_durations = [240, 270, 300, 240, 270]  # 5개 장면으로 변경
    
    # 글로벌 파티클과 이펙트
    particles = []
    energy_particles = []
    light_rays = []
    screen_shake = 0
    flash_alpha = 0
    
    # 장면별 특수 변수들
    scene_vars = {}
    
    def reset_scene_vars():
        """각 장면마다 변수 초기화"""
        scene_vars.clear()
        scene_vars.update({
            'paddle_x': WIDTH // 2,
            'paddle_y': HEIGHT - 100,
            'ball_x': WIDTH // 2,
            'ball_y': HEIGHT // 2,
            'ball_speed_x': 8,
            'ball_speed_y': -6,
            'boss_x': WIDTH // 2,
            'boss_y': 150,
            'boss_scale': 1.0,
            'energy_charge': 0,
            'camera_zoom': 1.0,
            'camera_x': 0,
            'camera_y': 0,
            'dramatic_timer': 0,
            'explosion_particles': [],
            'impact_waves': [],
            'special_effects': []
        })
    
    def create_particle(x, y, color, speed=3, life=60, size=3):
        """파티클 생성"""
        angle = random.uniform(0, 2 * math.pi)
        return {
            'x': x, 'y': y,
            'vx': math.cos(angle) * speed * random.uniform(0.5, 1.5),
            'vy': math.sin(angle) * speed * random.uniform(0.5, 1.5),
            'color': color,
            'life': life,
            'max_life': life,
            'size': size
        }
    
    def create_energy_particle(x, y):
        """에너지 파티클 생성"""
        return create_particle(x, y, (100, 200, 255), speed=5, life=90, size=4)
    
    def create_explosion_particle(x, y):
        """폭발 파티클 생성"""
        colors = [(255, 100, 50), (255, 150, 0), (255, 200, 100), (255, 255, 200)]
        return create_particle(x, y, random.choice(colors), speed=8, life=45, size=random.randint(2, 6))
    
    def update_particles(particle_list):
        """파티클 업데이트"""
        for particle in particle_list[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1
            particle['vy'] += 0.2  # 중력
            
            if particle['life'] <= 0:
                particle_list.remove(particle)
    
    def draw_particles(particle_list):
        """파티클 그리기"""
        for particle in particle_list:
            alpha = int(255 * (particle['life'] / particle['max_life']))
            color = (*particle['color'], alpha)
            size = max(1, int(particle['size'] * (particle['life'] / particle['max_life'])))
            
            # 글로우 효과
            for i in range(3):
                glow_size = size + (3 - i)
                glow_alpha = alpha // (i + 2)
                glow_surface = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surface, (*particle['color'], glow_alpha), 
                                 (glow_size, glow_size), glow_size)
                SCREEN.blit(glow_surface, (particle['x'] - glow_size, particle['y'] - glow_size))
    
    def scene_1_mystical_arena():
        """장면 1: 신비로운 투기장 등장"""
        # 배경 그라데이션 (밤하늘 느낌)
        for y in range(HEIGHT):
            ratio = y / HEIGHT
            # 위쪽은 더 어둡고, 아래로 갈수록 밝게
            color = (
                int(5 + 25 * ratio),
                int(3 + 18 * ratio),
                int(25 + 75 * ratio)
            )
            pygame.draw.line(SCREEN, color, (0, y), (WIDTH, y))
        
        # 🌟 별들 (반짝이는 효과)
        for i in range(25):
            star_x = (i * 123 + 50) % WIDTH  # 고정된 위치
            star_y = (i * 87 + 30) % (HEIGHT // 3)  # 상단 1/3 영역에만
            
            # 반짝임 효과
            twinkle = abs(math.sin(scene_timer * 0.1 + i * 0.5))
            star_alpha = int(100 + 155 * twinkle)
            star_size = 1 + int(twinkle * 3)
            
            # 별 색상 (약간씩 다르게)
            colors = [(255, 255, 200), (200, 200, 255), (255, 200, 255), (200, 255, 255)]
            star_color = colors[i % 4]
            
            # 별 그리기 (십자 모양)
            star_surface = pygame.Surface((star_size * 6, star_size * 6), pygame.SRCALPHA)
            # 가로선
            pygame.draw.line(star_surface, (*star_color, star_alpha), 
                           (0, star_size * 3), (star_size * 6, star_size * 3), star_size)
            # 세로선
            pygame.draw.line(star_surface, (*star_color, star_alpha), 
                           (star_size * 3, 0), (star_size * 3, star_size * 6), star_size)
            SCREEN.blit(star_surface, (star_x - star_size * 3, star_y - star_size * 3))
        
        # 🌙 달 (천천히 움직이며 위상 변화)
        moon_x = WIDTH - 150 + math.sin(scene_timer * 0.02) * 30
        moon_y = 80 + math.cos(scene_timer * 0.015) * 20
        moon_size = 40
        
        # 달의 위상 (차오르고 이지러지는 효과)
        moon_phase = (scene_timer * 0.03) % (2 * math.pi)
        
        # 달 배경 (어두운 부분)
        pygame.draw.circle(SCREEN, (60, 60, 80), (int(moon_x), int(moon_y)), moon_size)
        
        # 달의 밝은 부분 (위상에 따라 변화)
        bright_offset = int(math.sin(moon_phase) * moon_size * 0.8)
        if bright_offset > 0:
            # 차오르는 달
            bright_rect = pygame.Rect(moon_x - moon_size + bright_offset, moon_y - moon_size, 
                                    moon_size * 2 - bright_offset, moon_size * 2)
        else:
            # 이지러지는 달
            bright_rect = pygame.Rect(moon_x - moon_size, moon_y - moon_size, 
                                    moon_size * 2 + bright_offset, moon_size * 2)
        
        # 달 표면 그리기
        moon_surface = pygame.Surface((moon_size * 2, moon_size * 2), pygame.SRCALPHA)
        pygame.draw.circle(moon_surface, (220, 220, 180), (moon_size, moon_size), moon_size)
        
        # 클리핑으로 위상 효과
        clipped_surface = pygame.Surface((moon_size * 2, moon_size * 2), pygame.SRCALPHA)
        clipped_surface.blit(moon_surface, (0, 0))
        clipped_surface.set_clip(bright_rect.move(-moon_x + moon_size, -moon_y + moon_size))
        
        SCREEN.blit(clipped_surface, (moon_x - moon_size, moon_y - moon_size))
        
        # 달 글로우
        for i in range(8):
            glow_alpha = 40 - i * 5
            glow_size = moon_size + i * 3
            glow_surface = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surface, (255, 255, 200, glow_alpha), 
                             (glow_size, glow_size), glow_size)
            SCREEN.blit(glow_surface, (moon_x - glow_size, moon_y - glow_size))
        
        # 🪐 행성들 (다양한 크기와 색상으로 궤도 운동)
        planets_data = [
            {'distance': 200, 'speed': 0.03, 'size': 15, 'color': (255, 100, 100), 'rings': False},
            {'distance': 280, 'speed': 0.02, 'size': 25, 'color': (100, 255, 100), 'rings': True},
            {'distance': 350, 'speed': 0.015, 'size': 20, 'color': (100, 100, 255), 'rings': False},
            {'distance': 420, 'speed': 0.01, 'size': 30, 'color': (255, 255, 100), 'rings': True},
        ]
        
        center_x, center_y = WIDTH // 2, HEIGHT // 4
        
        for i, planet in enumerate(planets_data):
            # 궤도 계산
            angle = scene_timer * planet['speed'] + i * math.pi / 2
            planet_x = center_x + math.cos(angle) * planet['distance']
            planet_y = center_y + math.sin(angle) * planet['distance'] * 0.3  # 타원 궤도
            
            # 화면 경계 체크
            if 0 <= planet_x <= WIDTH and 0 <= planet_y <= HEIGHT // 2:
                # 행성 그리기
                size = planet['size']
                color = planet['color']
                
                # 행성 글로우
                for j in range(5):
                    glow_alpha = 60 - j * 12
                    glow_size = size + j * 4
                    glow_surface = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surface, (*color, glow_alpha), 
                                     (glow_size, glow_size), glow_size)
                    SCREEN.blit(glow_surface, (planet_x - glow_size, planet_y - glow_size))
                
                # 메인 행성
                pygame.draw.circle(SCREEN, color, (int(planet_x), int(planet_y)), size)
                
                # 행성 표면 디테일 (음영)
                shadow_color = tuple(c // 2 for c in color)
                pygame.draw.circle(SCREEN, shadow_color, 
                                 (int(planet_x + size // 3), int(planet_y + size // 3)), size // 3)
                
                # 고리가 있는 행성
                if planet['rings']:
                    ring_color = (*color, 100)
                    for ring in range(3):
                        ring_radius = size + 8 + ring * 6
                        ring_surface = pygame.Surface((ring_radius * 2, ring_radius * 2), pygame.SRCALPHA)
                        pygame.draw.circle(ring_surface, ring_color, 
                                         (ring_radius, ring_radius), ring_radius, 2)
                        SCREEN.blit(ring_surface, (planet_x - ring_radius, planet_y - ring_radius))
        
        # 투기장 구조물 실루엣
        arena_y = HEIGHT - 200
        pygame.draw.polygon(SCREEN, (20, 10, 60), [
            (0, arena_y), (WIDTH//4, arena_y-50), (3*WIDTH//4, arena_y-50), (WIDTH, arena_y),
            (WIDTH, HEIGHT), (0, HEIGHT)
        ])
        
        # 기둥들
        for i in range(5):
            pillar_x = (i + 1) * WIDTH // 6
            pillar_height = 180 + math.sin(scene_timer * 0.05 + i) * 20
            pygame.draw.rect(SCREEN, (40, 20, 80), 
                           (pillar_x - 15, HEIGHT - pillar_height, 30, pillar_height))
            
            # 기둥 글로우
            for j in range(5):
                glow_alpha = 30 - j * 5
                glow_surface = pygame.Surface((50 + j * 4, pillar_height + j * 4), pygame.SRCALPHA)
                glow_surface.fill((100, 50, 200, glow_alpha))
                SCREEN.blit(glow_surface, (pillar_x - 25 - j * 2, HEIGHT - pillar_height - j * 2))
        
        # 신비로운 빛 입자들
        if scene_timer % 10 == 0:
            for _ in range(3):
                particles.append(create_particle(
                    random.randint(0, WIDTH), HEIGHT - 200,
                    (150, 100, 255), speed=2, life=120, size=3
                ))
    
    def scene_2_dreamscape_awakening():
        """장면 2: 몽환적 각성의 세계"""
        # 몽환적 그라데이션 배경 (무지개 같은 색상 변화)
        for y in range(HEIGHT):
            time_factor = scene_timer * 0.02
            y_factor = y / HEIGHT
            
            # 여러 색상이 파도치듯 흘러가는 효과
            r = int(128 + 127 * math.sin(time_factor + y_factor * 3))
            g = int(128 + 127 * math.sin(time_factor + y_factor * 3 + 2))
            b = int(128 + 127 * math.sin(time_factor + y_factor * 3 + 4))
            
            # 부드러운 색상 블렌딩
            color = (max(20, r//2), max(20, g//2), max(60, b))
            pygame.draw.line(SCREEN, color, (0, y), (WIDTH, y))
        
        # 떠다니는 빛의 구체들 (다양한 크기와 색상)
        for i in range(12):
            sphere_time = scene_timer * 0.02 + i * 0.5
            sphere_x = WIDTH // 2 + math.sin(sphere_time) * (200 + i * 20)
            sphere_y = HEIGHT // 2 + math.cos(sphere_time * 0.7) * (100 + i * 15)
            
            # 구체 색상 (파스텔 톤)
            hue_shift = (scene_timer + i * 30) % 360
            r = int(200 + 55 * math.sin(math.radians(hue_shift)))
            g = int(200 + 55 * math.sin(math.radians(hue_shift + 120)))
            b = int(200 + 55 * math.sin(math.radians(hue_shift + 240)))
            
            # 구체 크기 (맥동)
            base_size = 15 + i * 2
            pulse = math.sin(scene_timer * 0.1 + i) * 8
            sphere_size = int(base_size + pulse)
            
            # 구체 글로우 그리기
            for j in range(8):
                glow_alpha = 100 - j * 12
                glow_size = sphere_size + j * 4
                glow_surface = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surface, (r, g, b, glow_alpha), 
                                 (glow_size, glow_size), glow_size)
                SCREEN.blit(glow_surface, (sphere_x - glow_size, sphere_y - glow_size))
        
        # 중앙의 신비로운 패들 (투명하게 나타남)
        paddle_alpha = min(255, scene_timer * 2)
        paddle_x = WIDTH // 2
        paddle_y = HEIGHT // 2
        
        # 패들 주변의 마법진 같은 원형 패턴들
        for ring in range(5):
            ring_radius = 80 + ring * 25 + math.sin(scene_timer * 0.08 + ring) * 15
            ring_alpha = paddle_alpha // (ring + 2)
            
            # 원형에 점들로 마법진 느낌
            for dot in range(16):
                dot_angle = (dot * 22.5 + scene_timer * 2) % 360
                dot_x = paddle_x + math.cos(math.radians(dot_angle)) * ring_radius
                dot_y = paddle_y + math.sin(math.radians(dot_angle)) * ring_radius
                
                dot_color = (255, 200 + ring * 10, 150 + ring * 20, ring_alpha)
                dot_size = 3 + ring
                
                dot_surface = pygame.Surface((dot_size * 2, dot_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(dot_surface, dot_color, (dot_size, dot_size), dot_size)
                SCREEN.blit(dot_surface, (dot_x - dot_size, dot_y - dot_size))
        
        # 신비로운 패들 그리기 (반투명)
        paddle_surface = pygame.Surface((140, 25), pygame.SRCALPHA)
        pygame.draw.rect(paddle_surface, (255, 255, 255, paddle_alpha), (0, 0, 140, 25))
        # 패들에 신비로운 패턴
        for i in range(7):
            pattern_alpha = paddle_alpha // 2
            pattern_x = i * 20 + 10
            pygame.draw.circle(paddle_surface, (100, 200, 255, pattern_alpha), 
                             (pattern_x, 12), 6)
        
        SCREEN.blit(paddle_surface, (paddle_x - 70, paddle_y - 12))
        
        # 몽환적 파티클들 (천천히 상승)
        if scene_timer % 8 == 0:
            for _ in range(6):
                dream_colors = [(255, 100, 200), (100, 255, 200), (200, 100, 255), (255, 255, 100)]
                particles.append(create_particle(
                    random.randint(0, WIDTH), HEIGHT + 20,
                    random.choice(dream_colors), speed=1, life=180, size=8
                ))
    
    def scene_3_boss_awakening():
        """장면 3: 악마적 보스의 각성 - 기괴하고 어둡고 흉측한 표현"""
        # 지옥 같은 배경 - 불타는 어둠과 핏빛
        for y in range(HEIGHT):
            ratio = y / HEIGHT
            # 위는 검은 어둠, 아래로 갈수록 지옥불 색상
            flicker = abs(math.sin(scene_timer * 0.15 + y * 0.01)) * 0.3
            color = (
                int(20 + ratio * 100 + flicker * 80),  # 붉은색 강조
                int(5 + ratio * 20 + flicker * 30),    # 약간의 주황
                int(ratio * 40 + flicker * 50)         # 보라빛 어둠
            )
            pygame.draw.line(SCREEN, color, (0, y), (WIDTH, y))
        
        # 배경에 번개 같은 균열 효과
        if scene_timer % 45 < 8:  # 간헐적으로 번개
            for _ in range(3):
                crack_x = random.randint(0, WIDTH)
                crack_start_y = random.randint(0, HEIGHT // 2)
                crack_end_y = crack_start_y + random.randint(100, 300)
                crack_width = random.randint(2, 6)
                
                # 지그재그 번개 효과
                points = [(crack_x, crack_start_y)]
                current_x, current_y = crack_x, crack_start_y
                while current_y < crack_end_y:
                    current_x += random.randint(-30, 30)
                    current_y += random.randint(20, 50)
                    points.append((current_x, min(current_y, crack_end_y)))
                
                # 번개 그리기
                if len(points) > 1:
                    for i in range(len(points) - 1):
                        pygame.draw.line(SCREEN, (255, 100, 100), points[i], points[i + 1], crack_width)
                        # 글로우 효과
                        pygame.draw.line(SCREEN, (255, 200, 150), points[i], points[i + 1], crack_width // 2)
        
        # 거대하고 기괴한 보스 실루엣
        boss_scale = scene_vars.get('boss_scale', 0.1)
        if scene_timer < 180:
            boss_scale = 0.1 + (scene_timer / 180) * 2.0  # 더 크게
            scene_vars['boss_scale'] = boss_scale
        
        boss_width = int(300 * boss_scale)
        boss_height = int(250 * boss_scale)
        center_x, center_y = WIDTH // 2, HEIGHT // 2
        boss_x = center_x - boss_width // 2
        boss_y = center_y - boss_height // 2
        
        # 맥동하는 어둠의 보스 색상 (심장박동처럼)
        pulse = abs(math.sin(scene_timer * 0.25))
        boss_base_color = (
            int(60 + pulse * 100),  # 붉은색 맥동
            int(15 + pulse * 40),   # 약간의 주황
            int(100 + pulse * 60)   # 어두운 보라
        )
        
        # 기괴한 메인 몸체 (불규칙한 형태)
        body_points = []
        for angle in range(0, 360, 20):
            rad = math.radians(angle)
            # 불규칙한 반지름으로 기괴한 형태
            irregular_radius = boss_width // 2 + math.sin(scene_timer * 0.1 + angle * 0.1) * 40
            x = center_x + math.cos(rad) * irregular_radius
            y = center_y + math.sin(rad) * irregular_radius * 0.8
            body_points.append((x, y))
        
        if len(body_points) > 2:
            pygame.draw.polygon(SCREEN, boss_base_color, body_points)
            # 어둠의 경계선
            pygame.draw.polygon(SCREEN, (30, 10, 50), body_points, 4)
        
        # 여러 개의 악마적인 눈들 (불규칙하게 배치)
        eye_positions = [
            (center_x - 60, center_y - 40),
            (center_x + 60, center_y - 40),
            (center_x, center_y),
            (center_x - 80, center_y + 30),
            (center_x + 80, center_y + 30),
            (center_x - 30, center_y + 60),
            (center_x + 30, center_y + 60)
        ]
        
        for i, (eye_x, eye_y) in enumerate(eye_positions):
            # 각 눈마다 다른 깜빡임 패턴
            eye_intensity = abs(math.sin(scene_timer * 0.3 + i * 0.7))
            eye_color = (
                int(255 * eye_intensity),
                int(60 * eye_intensity),
                int(30 * eye_intensity)
            )
            
            # 눈 크기도 맥동
            eye_size = int(8 + eye_intensity * 12)
            
            # 외부 글로우 (여러 겹)
            for j in range(6):
                glow_size = eye_size + j * 4
                glow_alpha = int(120 - j * 20)
                if glow_alpha > 0:
                    glow_surface = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surface, (*eye_color, glow_alpha), 
                                     (glow_size, glow_size), glow_size)
                    SCREEN.blit(glow_surface, (eye_x - glow_size, eye_y - glow_size))
            
            # 메인 눈
            pygame.draw.circle(SCREEN, eye_color, (int(eye_x), int(eye_y)), eye_size)
            # 동공
            pygame.draw.circle(SCREEN, (0, 0, 0), (int(eye_x), int(eye_y)), eye_size // 2)
            # 동공 안의 작은 빛
            if eye_intensity > 0.7:
                pygame.draw.circle(SCREEN, (255, 150, 100), (int(eye_x), int(eye_y)), 2)
        
        # 기괴한 촉수나 팔들 (꿈틀거리는 움직임)
        tentacle_count = 8
        for i in range(tentacle_count):
            angle = (i * 45 + scene_timer * 3) % 360
            rad = math.radians(angle)
            
            # 촉수의 기본 위치
            base_x = center_x + math.cos(rad) * (boss_width // 2)
            base_y = center_y + math.sin(rad) * (boss_height // 2)
            
            # 꿈틀거리는 움직임으로 촉수 끝점 계산
            tentacle_length = 100 + math.sin(scene_timer * 0.2 + i) * 40
            wiggle = math.sin(scene_timer * 0.15 + i) * 0.8
            end_x = base_x + math.cos(rad + wiggle) * tentacle_length
            end_y = base_y + math.sin(rad + wiggle) * tentacle_length
            
            # 촉수 색상 (어둠과 핏빛)
            tentacle_color = (
                int(80 + abs(math.sin(scene_timer * 0.1 + i)) * 80),
                int(30 + abs(math.sin(scene_timer * 0.1 + i)) * 50),
                int(60 + abs(math.sin(scene_timer * 0.1 + i)) * 100)
            )
            
            # 촉수 그리기 (세그먼트로 나누어 더 자연스럽게)
            segments = 5
            for seg in range(segments):
                t = seg / segments
                seg_x = base_x + (end_x - base_x) * t
                seg_y = base_y + (end_y - base_y) * t
                
                next_t = (seg + 1) / segments
                next_seg_x = base_x + (end_x - base_x) * next_t
                next_seg_y = base_y + (end_y - base_y) * next_t
                
                # 세그먼트 두께 (끝으로 갈수록 얇아짐)
                thickness = int(12 - seg * 2)
                if thickness > 0:
                    pygame.draw.line(SCREEN, tentacle_color, 
                                   (int(seg_x), int(seg_y)), (int(next_seg_x), int(next_seg_y)), thickness)
            
            # 촉수 끝에 가시나 클로우
            claw_size = 8
            for claw_i in range(3):
                claw_angle = rad + (claw_i - 1) * 0.5
                claw_end_x = end_x + math.cos(claw_angle) * claw_size
                claw_end_y = end_y + math.sin(claw_angle) * claw_size
                pygame.draw.line(SCREEN, tentacle_color, 
                               (int(end_x), int(end_y)), (int(claw_end_x), int(claw_end_y)), 3)
        
        # 지옥의 오라 - 어둠이 사방으로 퍼져나감
        if scene_timer > 90:
            aura_intensity = min(1.0, (scene_timer - 90) / 150)
            aura_radius = int(aura_intensity * 400)
            
            # 여러 층의 어둠 오라 (불규칙한 형태)
            for layer in range(10):
                alpha = int(100 * aura_intensity - layer * 10)
                if alpha > 0:
                    layer_radius = aura_radius - layer * 25
                    if layer_radius > 0:
                        aura_surface = pygame.Surface((layer_radius * 2, layer_radius * 2), pygame.SRCALPHA)
                        
                        # 불규칙한 오라 형태
                        aura_points = []
                        for angle in range(0, 360, 12):
                            rad = math.radians(angle)
                            irregular_radius = layer_radius + math.sin(scene_timer * 0.08 + angle * 0.1 + layer * 0.3) * 20
                            x = layer_radius + math.cos(rad) * irregular_radius
                            y = layer_radius + math.sin(rad) * irregular_radius
                            aura_points.append((x, y))
                        
                        if len(aura_points) > 2:
                            # 오라 색상 (어둠, 핏빛, 보라)
                            aura_color = (100 - layer * 5, 20 - layer * 2, 80 - layer * 4, alpha)
                            pygame.draw.polygon(aura_surface, aura_color, aura_points)
                        
                        SCREEN.blit(aura_surface, (center_x - layer_radius, center_y - layer_radius))
        
        # 악마적인 에너지 파티클들 (핏빛과 어둠)
        if scene_timer % 4 == 0:
            for _ in range(12):
                # 보스 주변에서 파티클 생성
                angle = random.uniform(0, 2 * math.pi)
                distance = random.uniform(80, 200)
                particle_x = center_x + math.cos(angle) * distance
                particle_y = center_y + math.sin(angle) * distance
                
                # 파티클 색상 (핏빛, 어둠, 불꽃)
                colors = [
                    (180, 30, 40),   # 핏빛
                    (100, 15, 120),  # 어둠의 보라
                    (220, 80, 0),    # 지옥불
                    (140, 0, 70),    # 어둠의 분홍
                    (60, 0, 0)       # 깊은 어둠
                ]
                particle_color = random.choice(colors)
                
                particles.append(create_particle(
                    particle_x, particle_y,
                    particle_color, speed=8, life=180, size=6
                ))
        
        # 화면 가장자리에 어둠의 비네팅 효과
        vignette_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        vignette_intensity = min(200, scene_timer * 2)
        for i in range(150):
            alpha = int(vignette_intensity * (i / 150) * 0.8)
            border = i * 2
            if border < WIDTH // 2 and border < HEIGHT // 2:
                pygame.draw.rect(vignette_surface, (0, 0, 0, alpha), 
                               (border, border, WIDTH - border * 2, HEIGHT - border * 2), 1)
        SCREEN.blit(vignette_surface, (0, 0))
        
        # 간헐적인 화면 진동 효과 (공포감 증대)
        if scene_timer % 60 < 10:
            shake_intensity = random.randint(-3, 3)
            scene_vars['screen_shake'] = shake_intensity
    
    def scene_4_dimensional_rift():
        """장면 4: 차원의 틈 - 몽환적 시공간 왜곡"""
        # 시공간 왜곡 배경 (소용돌이 같은 효과)
        center_x, center_y = WIDTH // 2, HEIGHT // 2
        
        for r in range(0, max(WIDTH, HEIGHT) // 2, 8):
            # 시간에 따라 회전하는 동심원
            rotation_speed = scene_timer * 0.05 + r * 0.01
            
            # 무지개 색상 순환
            hue = (rotation_speed * 100 + r * 2) % 360
            r_color = int(128 + 127 * math.sin(math.radians(hue)))
            g_color = int(128 + 127 * math.sin(math.radians(hue + 120)))
            b_color = int(128 + 127 * math.sin(math.radians(hue + 240)))
            
            # 왜곡된 원형들
            for angle in range(0, 360, 15):
                wave_angle = math.radians(angle + rotation_speed * 50)
                wave_radius = r + math.sin(rotation_speed * 3 + angle * 0.1) * 20
                
                x = center_x + math.cos(wave_angle) * wave_radius
                y = center_y + math.sin(wave_angle) * wave_radius
                
                if 0 <= x < WIDTH and 0 <= y < HEIGHT:
                    # 각 점에서 글로우 효과
                    point_size = 3 + int(abs(math.sin(rotation_speed + angle * 0.1)) * 5)
                    alpha = int(150 * abs(math.sin(rotation_speed * 2 + angle * 0.05)))
                    
                    point_surface = pygame.Surface((point_size * 4, point_size * 4), pygame.SRCALPHA)
                    pygame.draw.circle(point_surface, (r_color, g_color, b_color, alpha), 
                                     (point_size * 2, point_size * 2), point_size)
                    SCREEN.blit(point_surface, (x - point_size * 2, y - point_size * 2))
        
        # 차원을 가로지르는 신비한 공들
        for orb in range(8):
            orb_time = scene_timer * 0.03 + orb * 0.8
            
            # 복잡한 궤도 패턴
            base_x = WIDTH // 2 + math.sin(orb_time) * 200
            base_y = HEIGHT // 2 + math.cos(orb_time * 1.3) * 150
            
            # 추가 왜곡
            warp_x = base_x + math.sin(orb_time * 2.5) * 80
            warp_y = base_y + math.cos(orb_time * 1.8) * 60
            
            # 오브 색상 (시간에 따라 변화)
            orb_hue = (scene_timer * 5 + orb * 45) % 360
            orb_r = int(200 + 55 * math.sin(math.radians(orb_hue)))
            orb_g = int(200 + 55 * math.sin(math.radians(orb_hue + 120)))
            orb_b = int(200 + 55 * math.sin(math.radians(orb_hue + 240)))
            
            # 오브 크기 (맥동)
            orb_size = 20 + int(math.sin(orb_time * 3) * 15)
            
            # 오브의 꼬리 효과 (궤적 표시)
            trail_length = 15
            for trail in range(trail_length):
                trail_time = orb_time - trail * 0.05
                trail_x = WIDTH // 2 + math.sin(trail_time) * 200 + math.sin(trail_time * 2.5) * 80
                trail_y = HEIGHT // 2 + math.cos(trail_time * 1.3) * 150 + math.cos(trail_time * 1.8) * 60
                
                trail_alpha = int(100 * (1 - trail / trail_length))
                trail_size = max(1, orb_size - trail * 2)
                
                if trail_alpha > 0:
                    trail_surface = pygame.Surface((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(trail_surface, (orb_r, orb_g, orb_b, trail_alpha), 
                                     (trail_size, trail_size), trail_size)
                    SCREEN.blit(trail_surface, (trail_x - trail_size, trail_y - trail_size))
            
            # 메인 오브 그리기 (글로우 효과)
            for glow in range(6):
                glow_alpha = 150 - glow * 25
                glow_size = orb_size + glow * 8
                glow_surface = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surface, (orb_r, orb_g, orb_b, glow_alpha), 
                                 (glow_size, glow_size), glow_size)
                SCREEN.blit(glow_surface, (warp_x - glow_size, warp_y - glow_size))
        
        # 차원 틈새에서 나오는 신비한 패들들 (반투명)
        for phantom in range(4):
            phantom_time = scene_timer * 0.04 + phantom * 1.5
            phantom_x = WIDTH // 2 + math.sin(phantom_time) * 300
            phantom_y = HEIGHT // 2 + math.cos(phantom_time * 0.8) * 200
            
            phantom_alpha = int(120 * abs(math.sin(phantom_time)))
            
            # 유령 같은 패들
            paddle_surface = pygame.Surface((100, 20), pygame.SRCALPHA)
            
            # 패들 색상 (각각 다른 색)
            colors = [(255, 100, 255), (100, 255, 255), (255, 255, 100), (255, 100, 100)]
            paddle_color = colors[phantom % 4]
            
            pygame.draw.rect(paddle_surface, (*paddle_color, phantom_alpha), (0, 0, 100, 20))
            
            # 패들 주변 파동 효과
            for wave in range(3):
                wave_alpha = phantom_alpha // (wave + 2)
                wave_size = 20 + wave * 15
                wave_surface = pygame.Surface((wave_size * 2, wave_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(wave_surface, (*paddle_color, wave_alpha), 
                                 (wave_size, wave_size), wave_size, 3)
                SCREEN.blit(wave_surface, (phantom_x - wave_size, phantom_y - wave_size))
            
            SCREEN.blit(paddle_surface, (phantom_x - 50, phantom_y - 10))
        
        # 차원 파티클 (위아래로 흘러감)
        if scene_timer % 5 == 0:
            for _ in range(10):
                cosmic_colors = [(255, 0, 255), (0, 255, 255), (255, 255, 0), (255, 0, 127), (127, 255, 0)]
                particles.append(create_particle(
                    random.randint(0, WIDTH), random.randint(0, HEIGHT),
                    random.choice(cosmic_colors), speed=3, life=120, size=6
                ))
    
    def scene_5_ultimate_clash():
        """장면 5: 궁극기 충돌"""
        # 극적인 배경 (보라색과 골드 혼합)
        for y in range(HEIGHT):
            ratio = y / HEIGHT
            color = (
                int(50 + 100 * abs(math.sin(scene_timer * 0.1 + y * 0.01))),
                int(20 + 80 * abs(math.cos(scene_timer * 0.08 + y * 0.015))),
                int(100 + 155 * abs(math.sin(scene_timer * 0.12 + y * 0.02)))
            )
            pygame.draw.line(SCREEN, color, (0, y), (WIDTH, y))
        
        # 카메라 줌 인 효과
        zoom = scene_vars['camera_zoom']
        if scene_timer < 120:
            zoom = 1.0 + (scene_timer / 120) * 1.5
            scene_vars['camera_zoom'] = zoom
        
        # 중앙에서 에너지 충돌
        center_x, center_y = WIDTH // 2, HEIGHT // 2
        
        # 에너지 구체들 (양쪽에서 접근)
        sphere1_x = WIDTH // 4 + (scene_timer * 3)
        sphere2_x = 3 * WIDTH // 4 - (scene_timer * 3)
        
        if sphere1_x >= center_x - 50 and sphere2_x <= center_x + 50:
            # 충돌 순간!
            collision_intensity = min(255, (scene_timer - 80) * 5)
            
            # 충돌 폭발 효과
            explosion_radius = int(collision_intensity * 2)
            for i in range(10):
                alpha = collision_intensity - i * 20
                if alpha > 0:
                    explosion_surface = pygame.Surface((explosion_radius * 2, explosion_radius * 2), pygame.SRCALPHA)
                    pygame.draw.circle(explosion_surface, (255, 255, 255, alpha), 
                                     (explosion_radius, explosion_radius), explosion_radius - i * 10)
                    SCREEN.blit(explosion_surface, (center_x - explosion_radius, center_y - explosion_radius))
            
            # 충돌 파티클 대량 생성
            if scene_timer % 2 == 0:
                for _ in range(30):
                    particles.append(create_explosion_particle(center_x, center_y))
                    energy_particles.append(create_energy_particle(center_x, center_y))
        else:
            # 에너지 구체들 그리기
            for sphere_x in [sphere1_x, sphere2_x]:
                if 0 <= sphere_x <= WIDTH:
                    for i in range(6):
                        alpha = 120 - i * 20
                        size = 40 + i * 8
                        sphere_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                        color = (255, 200, 0) if sphere_x == sphere1_x else (100, 200, 255)
                        pygame.draw.circle(sphere_surface, (*color, alpha), (size, size), size)
                        SCREEN.blit(sphere_surface, (sphere_x - size, center_y - size))
    

    
    # 장면 함수들
    scene_functions = [
        scene_1_mystical_arena,
        scene_2_dreamscape_awakening,
        scene_3_boss_awakening,
        scene_4_dimensional_rift,
        scene_5_ultimate_clash
    ]
    
    # 초기 변수 설정
    reset_scene_vars()
    
    while True:
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE:
                    return  # 스페이스바 누르면 즉시 종료
        
        # 화면 클리어
        SCREEN.fill((0, 0, 0))
        
        # 장면 전환 체크
        if scene_timer >= scene_durations[current_scene] and not transitioning and not final_fadeout:
            if current_scene < len(scene_functions) - 1:
                transitioning = True
                transition_alpha = 0
            else:
                # 마지막 장면 완료 후 페이드아웃 시작
                final_fadeout = True
                final_fadeout_alpha = 0
        
        # 전환 효과 처리
        if transitioning:
            transition_alpha += 8
            if transition_alpha >= 255:
                current_scene += 1
                scene_timer = 0
                transitioning = False
                transition_alpha = 0
                reset_scene_vars()
        
        # 현재 장면 실행
        if current_scene < len(scene_functions):
            scene_functions[current_scene]()
        
        # 마지막 장면 페이드아웃 처리
        if final_fadeout:
            final_fadeout_alpha += 3  # 천천히 페이드아웃 (약 1.4초)
            if final_fadeout_alpha >= 255:
                return  # 페이드아웃 완료 후 메뉴로 복귀
        
        # 파티클 업데이트 및 그리기
        update_particles(particles)
        update_particles(energy_particles)
        draw_particles(particles)
        draw_particles(energy_particles)
        
        # 플래시 효과
        if flash_alpha > 0:
            flash_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            flash_surface.fill((255, 255, 255, flash_alpha))
            SCREEN.blit(flash_surface, (0, 0))
            flash_alpha = max(0, flash_alpha - 5)
        
        # 전환 페이드 효과
        if transitioning:
            fade_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            fade_surface.fill((0, 0, 0, transition_alpha))
            SCREEN.blit(fade_surface, (0, 0))
        
        # 마지막 장면 페이드아웃 효과
        if final_fadeout:
            fadeout_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            fadeout_surface.fill((0, 0, 0, final_fadeout_alpha))
            SCREEN.blit(fadeout_surface, (0, 0))
        
        # 화면 업데이트
        pygame.display.flip()
        clock.tick(60)
        
        # 타이머 증가 (페이드아웃 중이 아닐 때만)
        if not final_fadeout:
            scene_timer += 1
