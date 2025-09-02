"""
이펙트 매니저 모듈
- 파티클 시스템 (flame, star, impact 등)
- 폭발 및 시각 효과
- 아이템 획득 효과
- 애니메이션 관리
"""

import pygame
import random
import math


# 전역 변수들
SCREEN = None
WIDTH = 600
HEIGHT = 750

# 파티클 시스템 변수들
flame_particles = []
star_particles = []
balloon_pop_effects = []
item_obtained_effects = []
impact_particles = []
drive_particles = []  # 드라이브 별빛가루 파티클
dash_smoke_particles = []  # 하프대시 연기 파티클

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
YELLOW = (255, 255, 0)


def init_effects_manager(screen, width=600, height=750):
    """이펙트 매니저 초기화"""
    global SCREEN, WIDTH, HEIGHT
    SCREEN = screen
    WIDTH = width
    HEIGHT = height
    print("")


# ================================================================================
# 🔥 FLAME PARTICLES (불꽃 파티클)
# ================================================================================

def spawn_flame_particles(x, y, count=4):
    """공에서 불꽃 가루 파티클 생성"""
    global flame_particles
    for _ in range(count):
        angle = random.uniform(0, 2*math.pi)
        speed = random.uniform(0.5, 2.0)
        vx = math.cos(angle) * speed
        vy = math.sin(angle) * speed
        flame_particles.append([x, y, vx, vy, 255, random.randint(2, 4)])  
        # [x, y, vx, vy, alpha, size]


def update_flame_particles():
    """파티클 이동 & 알파 감소"""
    global flame_particles
    new_particles = []
    for p in flame_particles:
        p[0] += p[2]  # x += vx
        p[1] += p[3]  # y += vy
        p[4] -= 8     # alpha 감소
        if p[4] > 0:
            new_particles.append(p)
    flame_particles = new_particles


def draw_flame_particles(surface):
    """불꽃 가루 그리기"""
    for x, y, vx, vy, alpha, size in flame_particles:
        color = (255, random.randint(80,150), 0, alpha)
        s = pygame.Surface((size*2, size*2), pygame.SRCALPHA)
        pygame.draw.circle(s, color, (size, size), size)
        surface.blit(s, (x-size, y-size))


# ================================================================================
# ⭐ STAR PARTICLES (별가루 파티클)
# ================================================================================

def spawn_star_particles(x, y, count=2):
    """별가루 파티클 생성 (무중력벨트 + 스피드기어 시너지)"""
    global star_particles
    for _ in range(count):
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(0.5, 2.0)
        vx = math.cos(angle) * speed
        vy = math.sin(angle) * speed
        star_particles.append([x, y, vx, vy, 255, random.randint(1, 3), random.randint(0, 360)])  
        # [x, y, vx, vy, alpha, size, rotation]


def update_star_particles():
    """별가루 파티클 업데이트"""
    global star_particles
    new_particles = []
    for x, y, vx, vy, alpha, size, rotation in star_particles:
        x += vx
        y += vy
        alpha -= 3  # 투명도 감소
        rotation += 5  # 회전
        
        if alpha > 0:
            new_particles.append([x, y, vx, vy, alpha, size, rotation])
    star_particles = new_particles


def draw_star_particles(surface):
    """별가루 파티클 그리기"""
    for x, y, vx, vy, alpha, size, rotation in star_particles:
        # 별 모양 그리기
        points = []
        for i in range(5):
            angle = math.radians(rotation + i * 72)
            outer_x = x + math.cos(angle) * size
            outer_y = y + math.sin(angle) * size
            points.append((outer_x, outer_y))
            
            angle = math.radians(rotation + i * 72 + 36)
            inner_x = x + math.cos(angle) * size * 0.5
            inner_y = y + math.sin(angle) * size * 0.5
            points.append((inner_x, inner_y))
        
        # 투명도가 있는 별 그리기
        star_surface = pygame.Surface((size*4, size*4), pygame.SRCALPHA)
        adjusted_points = [(px - x + size*2, py - y + size*2) for px, py in points]
        
        try:
            pygame.draw.polygon(star_surface, (255, 255, 100, alpha), adjusted_points)
            surface.blit(star_surface, (x - size*2, y - size*2))
        except:
            # 폴리곤 그리기 실패 시 원으로 대체
            pygame.draw.circle(surface, (255, 255, 100), (int(x), int(y)), size)


# ================================================================================
# 🌟 DRIVE PARTICLES (드라이브 별빛가루 파티클)
# ================================================================================

def spawn_drive_particles(x, y, count=3):
    """드라이브 발동 시 공 주위에 별빛가루 파티클 생성"""
    global drive_particles
    for _ in range(count):
        # 공 뒤쪽으로 향하는 파티클
        angle = random.uniform(math.pi * 0.3, math.pi * 0.7)  # 주로 위쪽 방향
        speed = random.uniform(0.3, 1.5)
        vx = math.cos(angle) * speed * random.choice([-1, 1])
        vy = -abs(math.sin(angle) * speed)  # 위로 올라가는 효과
        
        # 파티클 속성: [x, y, vx, vy, alpha, size, sparkle_phase, color_shift]
        drive_particles.append([
            x + random.randint(-5, 5),  # 약간의 x 오프셋
            y + random.randint(-5, 5),  # 약간의 y 오프셋
            vx, 
            vy, 
            200,  # 초기 알파값
            random.uniform(1, 3),  # 크기
            random.uniform(0, math.pi * 2),  # 반짝임 위상
            random.randint(0, 100)  # 색상 변화값
        ])


def update_drive_particles(ball_x, ball_y):
    """드라이브 파티클 업데이트 및 공을 따라다니는 효과"""
    global drive_particles
    new_particles = []
    
    for p in drive_particles:
        # 파티클 이동
        p[0] += p[2]  # x += vx
        p[1] += p[3]  # y += vy
        
        # 공을 향한 약한 인력 (공을 따라다니는 효과)
        dx = ball_x - p[0]
        dy = ball_y - p[1]
        distance = math.sqrt(dx*dx + dy*dy)
        
        if distance > 30:  # 너무 가깝지 않을 때만 인력 작용
            attraction = 0.05  # 인력 강도
            p[2] += (dx / distance) * attraction
            p[3] += (dy / distance) * attraction
        
        # 속도 감쇠
        p[2] *= 0.98
        p[3] *= 0.98
        
        # 알파값 감소
        p[4] -= 2
        
        # 반짝임 위상 업데이트
        p[6] += 0.2
        
        if p[4] > 0:
            new_particles.append(p)
    
    drive_particles = new_particles


def draw_drive_particles(surface):
    """드라이브 별빛가루 그리기"""
    for x, y, vx, vy, alpha, size, sparkle, color_shift in drive_particles:
        # 반짝임 효과 계산
        sparkle_intensity = (math.sin(sparkle) + 1) * 0.5
        actual_size = size * (0.5 + sparkle_intensity * 0.5)
        
        # 색상 결정 (연두색 베이스에 무지개빛 변화)
        base_green = (100, 255, 100)
        rainbow_shift = color_shift / 100.0
        
        # 무지개빛 색상 변화
        r = int(base_green[0] + 50 * math.sin(rainbow_shift * math.pi * 2))
        g = int(base_green[1] - 30 * math.sin(rainbow_shift * math.pi * 2 + math.pi/3))
        b = int(base_green[2] + 100 * math.sin(rainbow_shift * math.pi * 2 + math.pi*2/3))
        
        # 색상 범위 제한
        r = max(50, min(255, r))
        g = max(150, min(255, g))
        b = max(50, min(255, b))
        
        # 실제 알파값 (반짝임 적용)
        actual_alpha = int(alpha * sparkle_intensity)
        
        # 별빛 가루 그리기 (작은 원 + 십자 빛줄기)
        if actual_alpha > 0:
            # 중심 원
            s = pygame.Surface((int(actual_size*4), int(actual_size*4)), pygame.SRCALPHA)
            pygame.draw.circle(s, (r, g, b, actual_alpha), 
                             (int(actual_size*2), int(actual_size*2)), int(actual_size))
            
            # 십자 빛줄기 (반짝임 효과)
            if sparkle_intensity > 0.7:
                line_length = int(actual_size * 3)
                line_alpha = int(actual_alpha * 0.5)
                # 가로선
                pygame.draw.line(s, (255, 255, 255, line_alpha),
                               (int(actual_size*2 - line_length), int(actual_size*2)),
                               (int(actual_size*2 + line_length), int(actual_size*2)), 1)
                # 세로선
                pygame.draw.line(s, (255, 255, 255, line_alpha),
                               (int(actual_size*2), int(actual_size*2 - line_length)),
                               (int(actual_size*2), int(actual_size*2 + line_length)), 1)
            
            surface.blit(s, (x - actual_size*2, y - actual_size*2))


# ================================================================================
# 🎈 BALLOON POP EFFECTS (풍선 터짐 효과)
# ================================================================================

def create_balloon_pop_effect(x, y, color):
    """풍선 터짐 효과 생성"""
    global balloon_pop_effects
    for _ in range(8):
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(2, 6)
        vx = math.cos(angle) * speed
        vy = math.sin(angle) * speed
        balloon_pop_effects.append({
            'x': x, 'y': y, 'vx': vx, 'vy': vy,
            'color': color, 'alpha': 255, 'size': random.randint(3, 8),
            'life': 30
        })


def update_balloon_pop_effect():
    """풍선 터짐 효과 업데이트"""
    global balloon_pop_effects
    new_effects = []
    for effect in balloon_pop_effects:
        effect['x'] += effect['vx']
        effect['y'] += effect['vy']
        effect['vy'] += 0.2  # 중력 효과
        effect['alpha'] -= 8
        effect['life'] -= 1
        
        if effect['alpha'] > 0 and effect['life'] > 0:
            new_effects.append(effect)
    balloon_pop_effects = new_effects


def draw_balloon_pop_effect():
    """풍선 터짐 효과 그리기"""
    for effect in balloon_pop_effects:
        color = (*effect['color'], effect['alpha'])
        s = pygame.Surface((effect['size']*2, effect['size']*2), pygame.SRCALPHA)
        pygame.draw.circle(s, color, (effect['size'], effect['size']), effect['size'])
        SCREEN.blit(s, (effect['x']-effect['size'], effect['y']-effect['size']))


# ================================================================================
# 🎁 ITEM OBTAINED EFFECTS (아이템 획득 효과)
# ================================================================================

def show_item_obtained_effect(item_data, item_x=None, item_y=None):
    """아이템 획득 효과 표시"""
    global item_obtained_effects
    
    # 아이템 정보 설정
    if item_x is None:
        item_x = WIDTH // 2
    if item_y is None:
        item_y = HEIGHT // 2
    
    # 효과 생성
    effect = {
        'item_name': item_data.get('name', '아이템'),
        'item_type': item_data.get('type', 'active'),
        'x': item_x,
        'y': item_y,
        'alpha': 255,
        'scale': 0.5,
        'timer': 120,  # 2초 (60 FPS 기준)
        'particles': []
    }
    
    # 파티클 생성
    for _ in range(12):
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(1, 3)
        effect['particles'].append({
            'x': item_x, 'y': item_y,
            'vx': math.cos(angle) * speed,
            'vy': math.sin(angle) * speed,
            'alpha': 255,
            'size': random.randint(2, 5)
        })
    
    item_obtained_effects.append(effect)


def update_item_obtained_effect():
    """아이템 획득 효과 업데이트"""
    global item_obtained_effects
    new_effects = []
    
    for effect in item_obtained_effects:
        effect['timer'] -= 1
        
        # 스케일 애니메이션 (커졌다가 작아짐)
        if effect['timer'] > 90:
            effect['scale'] = min(1.5, effect['scale'] + 0.1)
        else:
            effect['scale'] = max(0.1, effect['scale'] - 0.05)
        
        # 알파 애니메이션
        if effect['timer'] < 30:
            effect['alpha'] = max(0, effect['alpha'] - 8)
        
        # 파티클 업데이트
        new_particles = []
        for particle in effect['particles']:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['alpha'] -= 3
            particle['vy'] += 0.1  # 중력
            
            if particle['alpha'] > 0:
                new_particles.append(particle)
        effect['particles'] = new_particles
        
        if effect['timer'] > 0:
            new_effects.append(effect)
    
    item_obtained_effects = new_effects


def draw_item_obtained_effect():
    """아이템 획득 효과 그리기"""
    for effect in item_obtained_effects:
        # 배경 원
        if effect['alpha'] > 0:
            bg_size = int(60 * effect['scale'])
            bg_surface = pygame.Surface((bg_size*2, bg_size*2), pygame.SRCALPHA)
            
            # 아이템 타입에 따른 색상
            if effect['item_type'] == 'active':
                bg_color = (100, 150, 255, effect['alpha'] // 3)
            else:  # passive
                bg_color = (255, 150, 100, effect['alpha'] // 3)
            
            pygame.draw.circle(bg_surface, bg_color, (bg_size, bg_size), bg_size)
            SCREEN.blit(bg_surface, (effect['x'] - bg_size, effect['y'] - bg_size))
        
        # 아이템 이름 텍스트
        if effect['alpha'] > 50:
            try:
                font = pygame.font.Font("NanumSquareB.ttf", int(24 * effect['scale']))
                text_surface = font.render(effect['item_name'], True, (255, 255, 255))
                text_surface.set_alpha(effect['alpha'])
                text_rect = text_surface.get_rect(center=(effect['x'], effect['y']))
                SCREEN.blit(text_surface, text_rect)
            except:
                # 폰트 로드 실패 시 기본 폰트 사용
                font = pygame.font.Font(None, int(24 * effect['scale']))
                text_surface = font.render(effect['item_name'], True, (255, 255, 255))
                text_surface.set_alpha(effect['alpha'])
                text_rect = text_surface.get_rect(center=(effect['x'], effect['y']))
                SCREEN.blit(text_surface, text_rect)
        
        # 파티클 그리기
        for particle in effect['particles']:
            if particle['alpha'] > 0:
                color = (255, 255, 150, particle['alpha'])
                s = pygame.Surface((particle['size']*2, particle['size']*2), pygame.SRCALPHA)
                pygame.draw.circle(s, color, (particle['size'], particle['size']), particle['size'])
                SCREEN.blit(s, (particle['x']-particle['size'], particle['y']-particle['size']))


# ================================================================================
# 💥 IMPACT EFFECTS (충돌 효과)
# ================================================================================

def create_impact_effect(x, y, ball_speed, is_player=True):
    """충돌 임팩트 효과 생성"""
    global impact_particles
    
    # 속도에 따른 파티클 수와 크기 결정
    particle_count = min(15, int(ball_speed / 2) + 5)
    
    for _ in range(particle_count):
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(ball_speed * 0.1, ball_speed * 0.3)
        
        impact_particles.append({
            'x': x, 'y': y,
            'vx': math.cos(angle) * speed,
            'vy': math.sin(angle) * speed,
            'alpha': 255,
            'size': random.randint(2, 6),
            'color': (255, 200, 100) if is_player else (100, 200, 255),
            'life': random.randint(15, 30)
        })


def update_impact_particles():
    """임팩트 파티클 업데이트"""
    global impact_particles
    new_particles = []
    
    for particle in impact_particles:
        particle['x'] += particle['vx']
        particle['y'] += particle['vy']
        particle['vx'] *= 0.98  # 마찰력
        particle['vy'] *= 0.98
        particle['alpha'] -= 8
        particle['life'] -= 1
        
        if particle['alpha'] > 0 and particle['life'] > 0:
            new_particles.append(particle)
    
    impact_particles = new_particles


def draw_impact_particles():
    """임팩트 파티클 그리기"""
    for particle in impact_particles:
        color = (*particle['color'], particle['alpha'])
        s = pygame.Surface((particle['size']*2, particle['size']*2), pygame.SRCALPHA)
        pygame.draw.circle(s, color, (particle['size'], particle['size']), particle['size'])
        SCREEN.blit(s, (particle['x']-particle['size'], particle['y']-particle['size']))


# ================================================================================
# 💨 DASH SMOKE EFFECTS (하프대시 연기 효과)
# ================================================================================

def create_dash_smoke(x, y, direction='left'):
    """일반 대시 발동 시 방구 구름 효과 생성"""
    global dash_smoke_particles
    
    # 방향에 따른 연기 생성 위치 조정 (왼쪽 대시면 오른쪽에 연기)
    smoke_x = x + (40 if direction == 'left' else -40)
    
    # 방구처럼 둥글둥글한 구름 덩어리들
    # 여러 개의 작은 구름이 뭉쳐있는 느낌
    
    # 중심 큰 구름 (뽕~ 하는 메인 구름)
    dash_smoke_particles.append({
        'x': smoke_x,
        'y': y,
        'vx': (2.0 if direction == 'left' else -2.0),
        'vy': random.uniform(-0.5, 0.5),
        'size': random.randint(25, 30),  # 큰 구름
        'alpha': random.randint(200, 255),
        'life': random.randint(20, 25),
        'shape': 'cloud',
        'fade_speed': random.uniform(10, 15)
    })
    
    # 주변 작은 구름들 (뭉글뭉글)
    for i in range(8):  # 8개의 작은 구름
        angle = (i / 8) * 2 * 3.14159  # 원형으로 배치
        radius = random.uniform(15, 25)
        
        dash_smoke_particles.append({
            'x': smoke_x + radius * math.cos(angle),
            'y': y + radius * math.sin(angle) * 0.7,  # 수직으로 약간 납작하게
            'vx': (1.5 if direction == 'left' else -1.5) + math.cos(angle) * 0.5,
            'vy': math.sin(angle) * 0.3,
            'size': random.randint(12, 18),  # 작은 구름들
            'alpha': random.randint(150, 200),
            'life': random.randint(15, 20),
            'shape': 'cloud',
            'fade_speed': random.uniform(12, 18)
        })
    
    # 아주 작은 구름 파티클들 (디테일)
    for _ in range(5):
        dash_smoke_particles.append({
            'x': smoke_x + random.randint(-20, 20),
            'y': y + random.randint(-10, 10),
            'vx': (1.0 if direction == 'left' else -1.0) + random.uniform(-0.5, 0.5),
            'vy': random.uniform(-0.2, 0.2),
            'size': random.randint(8, 12),  # 아주 작은 구름
            'alpha': random.randint(100, 150),
            'life': random.randint(10, 15),
            'shape': 'cloud',
            'fade_speed': random.uniform(15, 20)
        })

def update_dash_smoke():
    """대시 구름 파티클 업데이트 - 뭉글뭉글 퍼짐"""
    global dash_smoke_particles
    new_particles = []
    
    for particle in dash_smoke_particles:
        # 위치 업데이트
        particle['x'] += particle['vx']
        particle['y'] += particle['vy']
        
        # 부드러운 감속 (구름처럼 천천히)
        particle['vx'] *= 0.85  # 적당한 감속
        particle['vy'] *= 0.9
        
        # 구름이 약간 퍼지는 효과
        if 'size' in particle:
            particle['size'] *= 1.03  # 천천히 커짐
        
        # 부드러운 페이드 아웃
        fade_speed = particle.get('fade_speed', 15)
        particle['alpha'] -= fade_speed
            
        particle['life'] -= 1
        
        if particle['alpha'] > 0 and particle['life'] > 0:
            new_particles.append(particle)
    
    dash_smoke_particles = new_particles

def draw_dash_smoke(surface=None):
    """방구 구름 효과 그리기 - 뭉글뭉글한 구름"""
    # surface가 제공되지 않으면 전역 SCREEN 사용
    screen = surface if surface else SCREEN
    
    if not screen:
        return
    
    for particle in dash_smoke_particles:
        alpha = min(255, max(0, particle['alpha']))
        if alpha <= 0:
            continue
        
        # 구름 크기 계산
        size = int(particle.get('size', 15))
        
        if size <= 0:
            continue
        
        # 구름 그리기용 서페이스
        s = pygame.Surface((size*2, size*2), pygame.SRCALPHA)
        
        # 방구 구름 색상 (회갈색 계열)
        if particle.get('shape') == 'cloud':
            # 구름의 뭉글뭉글한 느낌을 위해 여러 개의 원을 겹쳐 그림
            
            # 메인 구름 (중심)
            main_color = (150, 140, 130, alpha)  # 회갈색
            pygame.draw.circle(s, main_color, (size, size), size)
            
            # 구름의 울퉁불퉁한 가장자리 효과
            for i in range(5):  # 5개의 작은 원으로 구름 가장자리
                angle = (i / 5) * 2 * 3.14159
                offset_x = int(size * 0.5 * math.cos(angle))
                offset_y = int(size * 0.5 * math.sin(angle))
                
                edge_size = int(size * 0.6)
                edge_alpha = int(alpha * 0.7)
                edge_color = (160, 150, 140, edge_alpha)
                
                pygame.draw.circle(s, edge_color, 
                                 (size + offset_x, size + offset_y), 
                                 edge_size)
            
            # 중심부 하이라이트 (더 밝은 부분)
            if alpha > 100:
                highlight_size = int(size * 0.4)
                highlight_color = (170, 160, 150, alpha // 2)
                pygame.draw.circle(s, highlight_color, (size, size), highlight_size)
        
        # 블렌드 모드로 자연스럽게
        screen.blit(s, (int(particle['x']-size), int(particle['y']-size)), special_flags=pygame.BLEND_PREMULTIPLIED)

# ================================================================================
# 💫 EXPLOSION EFFECTS (폭발 효과)
# ================================================================================

def show_hongryun_explosion():
    """홍련폭염 폭발 효과"""
    explosion_center_x = WIDTH // 2
    explosion_center_y = HEIGHT // 2
    
    # 파티클 생성
    for _ in range(50):
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(5, 15)
        x = explosion_center_x + math.cos(angle) * random.uniform(0, 30)
        y = explosion_center_y + math.sin(angle) * random.uniform(0, 30)
        
        spawn_flame_particles(x, y, 3)
    
    # 화면 플래시 효과
    flash_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
    flash_surface.fill((255, 100, 0, 100))
    SCREEN.blit(flash_surface, (0, 0))


def create_screen_shake(intensity=10, duration=30):
    """화면 흔들림 효과 (실제 구현은 게임 루프에서 처리)"""
    return {
        'intensity': intensity,
        'duration': duration,
        'timer': duration
    }


# ================================================================================
# 🎨 VISUAL EFFECTS (시각 효과)
# ================================================================================

def apply_white_glow(surface, intensity=60):
    """흰색 글로우 효과 적용"""
    glow_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
    glow_surface.fill((255, 255, 255, intensity))
    surface.blit(glow_surface, (0, 0))


def apply_red_overlay(surface, intensity):
    """빨간색 오버레이 효과"""
    if intensity > 0:
        red_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        red_surface.fill((255, 0, 0, min(255, int(intensity))))
        surface.blit(red_surface, (0, 0))


def apply_blue_overlay(surface, intensity):
    """파란색 오버레이 효과"""
    if intensity > 0:
        blue_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        blue_surface.fill((0, 100, 255, min(255, int(intensity))))
        surface.blit(blue_surface, (0, 0))


# ================================================================================
# 🔄 UPDATE AND DRAW ALL (통합 업데이트 및 그리기)
# ================================================================================

def update_all_effects():
    """모든 이펙트 업데이트"""
    update_flame_particles()
    update_star_particles()
    update_balloon_pop_effect()
    update_item_obtained_effect()
    update_impact_particles()


def draw_all_effects(surface):
    """모든 이펙트 그리기"""
    draw_flame_particles(surface)
    draw_star_particles(surface)
    draw_balloon_pop_effect()
    draw_item_obtained_effect()
    draw_impact_particles()


def clear_all_effects():
    """모든 이펙트 초기화"""
    global flame_particles, star_particles, balloon_pop_effects
    global item_obtained_effects, impact_particles
    
    flame_particles = []
    star_particles = []
    balloon_pop_effects = []
    item_obtained_effects = []
    impact_particles = []


# ================================================================================
# 🎭 SPECIAL EFFECTS SYSTEM (특수 효과 시스템)
# ================================================================================

class SpecialEffect:
    """특수 효과 기본 클래스"""
    def __init__(self, name, duration=60):
        self.name = name
        self.active = False
        self.timer = 0
        self.duration = duration
        self.data = {}
    
    def activate(self, **kwargs):
        """효과 활성화"""
        self.active = True
        self.timer = self.duration
        self.data.update(kwargs)
        self.on_activate()
    
    def deactivate(self):
        """효과 비활성화"""
        self.active = False
        self.timer = 0
        self.on_deactivate()
    
    def update(self, game_state):
        """효과 업데이트 (상속 클래스에서 구현)"""
        if not self.active:
            return
        
        self.timer -= 1
        if self.timer <= 0:
            self.deactivate()
            return
        
        self.on_update(game_state)
    
    def on_activate(self):
        """효과 활성화 시 호출"""
        pass
    
    def on_deactivate(self):
        """효과 비활성화 시 호출"""
        pass
    
    def on_update(self, game_state):
        """매 프레임 업데이트 시 호출"""
        pass
    
    def draw(self, surface):
        """효과 그리기 (상속 클래스에서 구현)"""
        pass


class EmotionalOverdriveEffect(SpecialEffect):
    """감정 과부하 효과"""
    def __init__(self):
        super().__init__("emotional_overdrive", 300)  # 5초
        self.flash_timer = 0
        self.trails = []
        self.psycho_bg_timer = 0
        
        # 사운드 (나중에 sound_manager와 연동)
        self.sound_manager = None
    
    def on_activate(self):
        self.flash_timer = 30
        self.trails.clear()
        self.psycho_bg_timer = 0
        print("!")
    
    def on_deactivate(self):
        self.trails.clear()
        self.psycho_bg_timer = 0
        print("")
    
    def on_update(self, game_state):
        import pygame
        import math
        import random
        
        ball_vel = game_state.get('ball_vel', [0, 0])
        boss_rect = game_state.get('boss_rect')
        ball_rect = game_state.get('ball_rect')
        
        # 1. 공 곡선 이동
        time_now = pygame.time.get_ticks()
        curve = math.sin(time_now / 80) * 3
        ball_vel[0] += curve * random.uniform(0.5, 1.2)
        
        # 2. 공 순간이동 (랜덤 확률)
        if random.random() < 0.01:
            ball_rect.centerx = random.randint(50, WIDTH - 50)
            ball_rect.centery = random.randint(150, HEIGHT - 150)
        
        # 3. 보스 잔상 추가
        if boss_rect:
            self.trails.append((boss_rect.centerx, boss_rect.centery, 200))
            self.trails = [(x, y, a - 10) for x, y, a in self.trails if a > 10][:15]
        
        # 4. 보스 반짝임 타이머
        self.flash_timer -= 1
        if self.flash_timer <= 0:
            self.flash_timer = 30
        
        # 5. 배경 깜빡임 타이머 증가
        self.psycho_bg_timer += 1
    
    def draw(self, surface):
        """감정 과부하 효과 그리기"""
        if not self.active:
            return
        
        # 보스 잔상 그리기
        for x, y, alpha in self.trails:
            if alpha > 0:
                trail_surface = pygame.Surface((60, 30), pygame.SRCALPHA)
                trail_surface.fill((255, 100, 255, alpha))
                surface.blit(trail_surface, (x - 30, y - 15))


class WhipEffect(SpecialEffect):
    """상모돌리기 효과"""
    def __init__(self):
        super().__init__("whip", 260)  # 260프레임 (약 4.3초)으로 증가
        self.wave_phase = 0
        self.original_ball_speed = [0, 0]
        self.hit_by_player = False
        
        # 사운드 로드 시도
        try:
            import pygame
            self.whip_sound = pygame.mixer.Sound("sounds/whip_effect.wav")
        except:
            self.whip_sound = None
    
    def on_activate(self):
        self.wave_phase = 0
        self.hit_by_player = False
        
        # 공 속도 저장
        ball_vel = self.data.get('ball_vel', [0, 0])
        self.original_ball_speed = [ball_vel[0], ball_vel[1]]
        
        # 효과음 재생
        if self.whip_sound:
            self.whip_sound.play(loops=-1, maxtime=self.duration * (1000/60))
        
        # 속도 일시적으로 줄이기 (25% 감소 = 75% 유지)
        ball_vel[0] *= 0.75
        ball_vel[1] *= 0.75
        
        print("!")
    
    def on_deactivate(self):
        if self.whip_sound:
            self.whip_sound.stop()
        print("")
    
    def on_update(self, game_state):
        import math
        
        ball_vel = game_state.get('ball_vel', [0, 0])
        original_speed = game_state.get('original_speed', [0, 0])
        
        self.wave_phase += 0.3
        
        # 진폭 계산
        wave = math.sin(self.wave_phase) * 35
        
        # 볼륨 조정
        if self.whip_sound:
            volume = (math.sin(self.wave_phase) + 1) / 2
            self.whip_sound.set_volume(volume)
        
        # 공의 속도에 진폭 적용
        if original_speed and len(original_speed) >= 2:
            ball_vel[0] = original_speed[0] + wave
    
    def draw(self, surface):
        """상모돌리기 시각 효과"""
        if not self.active:
            return
        
        # 회전 효과 그리기
        import pygame
        import math
        
        time_now = pygame.time.get_ticks()
        rotation_angle = (time_now * 10 / 16.67) % 360
        
        center_x = WIDTH // 2
        center_y = HEIGHT // 2
        
        # 회전하는 원형 효과
        for i in range(8):
            angle = math.radians(rotation_angle + i * 45)
            x = center_x + math.cos(angle) * 100
            y = center_y + math.sin(angle) * 100
            
            circle_surface = pygame.Surface((20, 20), pygame.SRCALPHA)
            pygame.draw.circle(circle_surface, (255, 255, 100, 150), (10, 10), 8)
            surface.blit(circle_surface, (x - 10, y - 10))


class BalloonEffect(SpecialEffect):
    """풍선 효과"""
    def __init__(self):
        super().__init__("balloon", -1)  # 라운드 끝까지 지속
        self.balloons = []
        self.used_this_round = False
        
        # 사운드 로드
        try:
            import pygame
            self.balloon_boom_sound = pygame.mixer.Sound("sounds/balloonboom.wav")
        except:
            self.balloon_boom_sound = None
    
    def on_activate(self):
        self.balloons = []
        self.used_this_round = True
        
        # 풍선 생성
        import random
        import math
        
        balloon_colors = [
            (255, 100, 100), (100, 255, 100), (100, 100, 255),
            (255, 255, 100), (255, 100, 255), (100, 255, 255)
        ]
        
        for _ in range(random.randint(3, 5)):
            x = random.randint(100, WIDTH-100)
            y = random.randint(100, HEIGHT-100)
            radius = random.randint(25, 35)
            color = random.choice(balloon_colors)
            
            speed = random.uniform(1.5, 3.0)
            angle = random.uniform(0, 2 * math.pi)
            vx = math.cos(angle) * speed
            vy = math.sin(angle) * speed
            
            self.balloons.append({
                "x": x, "y": y, "radius": radius, "color": color,
                "vx": vx, "vy": vy, "bounce": 0
            })
        
        print("!")
    
    def on_update(self, game_state):
        import math
        
        # 풍선 움직임 처리
        for balloon in self.balloons:
            balloon["x"] += balloon["vx"]
            balloon["y"] += balloon["vy"]
            balloon["bounce"] += 0.2
            balloon["y"] += int(math.sin(balloon["bounce"]) * 1)
            
            # 벽 충돌 처리
            if balloon["x"] - balloon["radius"] <= 0:
                balloon["x"] = balloon["radius"]
                balloon["vx"] = abs(balloon["vx"])
            elif balloon["x"] + balloon["radius"] >= WIDTH:
                balloon["x"] = WIDTH - balloon["radius"]
                balloon["vx"] = -abs(balloon["vx"])
            
            if balloon["y"] - balloon["radius"] <= 0:
                balloon["y"] = balloon["radius"]
                balloon["vy"] = abs(balloon["vy"])
            elif balloon["y"] + balloon["radius"] >= HEIGHT:
                balloon["y"] = HEIGHT - balloon["radius"]
                balloon["vy"] = -abs(balloon["vy"])
    
    def check_ball_collision(self, ball_rect, ball_vel):
        """풍선과 공의 충돌 체크"""
        import math
        import random
        
        BALL_RADIUS = 10  # 기본값
        
        for balloon in self.balloons[:]:
            dx = ball_rect.centerx - balloon["x"]
            dy = ball_rect.centery - balloon["y"]
            distance = math.sqrt(dx*dx + dy*dy)
            
            collision_distance = BALL_RADIUS + balloon["radius"]
            
            if distance <= collision_distance:
                # 효과음 재생
                if self.balloon_boom_sound:
                    self.balloon_boom_sound.play()
                
                # 터짐 효과 생성
                create_balloon_pop_effect(balloon["x"], balloon["y"], balloon["color"])
                
                # 풍선 제거
                self.balloons.remove(balloon)
                
                # 공 방향 변경
                current_angle = math.atan2(ball_vel[1], ball_vel[0])
                angle_change = random.uniform(-0.524, 0.524)  # ±30도
                new_angle = current_angle + angle_change
                
                speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
                ball_vel[0] = math.cos(new_angle) * speed
                ball_vel[1] = math.sin(new_angle) * speed
                
                return True
        return False
    
    def draw(self, surface):
        """풍선 그리기"""
        if not self.active:
            return
        
        import pygame
        
        for balloon in self.balloons:
            x, y = int(balloon["x"]), int(balloon["y"])
            radius = balloon["radius"]
            color = balloon["color"]
            
            # 풍선 몸체
            pygame.draw.circle(surface, color, (x, y), radius)
            pygame.draw.circle(surface, (255, 255, 255), (x, y), radius, 2)
            
            # 풍선 줄
            pygame.draw.line(surface, (100, 100, 100), 
                           (x, y - radius), (x, y - radius - 20), 2)
            
            # 하이라이트
            highlight_x = x - radius // 3
            highlight_y = y - radius // 3
            pygame.draw.circle(surface, (255, 255, 255), 
                             (highlight_x, highlight_y), radius // 4)


class TearsEffect(SpecialEffect):
    """눈물의 비 효과"""
    def __init__(self):
        super().__init__("tears", 400)  # 약 6.7초
        self.falling_tears = []
        
        # 눈물 이미지 로드 시도
        try:
            import pygame
            self.tear_img = pygame.image.load("tear_drop.png").convert_alpha()
        except:
            self.tear_img = None
    
    def on_activate(self):
        import random
        
        self.falling_tears = []
        for _ in range(10):
            x = random.randint(0, WIDTH - 20)
            y = random.randint(-200, -20)
            speed = random.uniform(2, 5)
            self.falling_tears.append([x, y, speed, y])
        
        print("!")
    
    def on_update(self, game_state):
        for tear in self.falling_tears:
            tear[3] = tear[1]  # 이전 y 저장
            tear[1] += tear[2]  # y 위치 업데이트
    
    def check_player_collision(self, player_rect):
        """플레이어와의 충돌 체크"""
        import pygame
        import random
        import math
        
        player_slow_timer = 0
        tear_particles = []
        
        new_tears = []
        for tear in self.falling_tears:
            x, y, speed, prev_y = tear
            tear_rect = pygame.Rect(x, y, 10, 10)
            
            if (tear_rect.colliderect(player_rect) and 
                prev_y <= player_rect.top and y >= player_rect.top):
                
                player_slow_timer = 130  # 2초간 느려짐
                
                # 파티클 생성
                for _ in range(6):
                    angle = random.uniform(200, 340)
                    speed = random.uniform(1.0, 3.0)
                    vx = math.cos(math.radians(angle)) * speed
                    vy = math.sin(math.radians(angle)) * speed
                    tear_particles.append([
                        player_rect.centerx, player_rect.top,
                        vx, vy, 255, random.randint(2, 4)
                    ])
                continue
            else:
                new_tears.append(tear)
        
        self.falling_tears = new_tears
        return player_slow_timer
    
    def draw(self, surface):
        """눈물 그리기"""
        if not self.active:
            return
        
        import pygame
        
        if self.tear_img:
            img = self.tear_img.copy()
            img.set_alpha(180)
            img_width_half = self.tear_img.get_width() // 2
            img_height_half = self.tear_img.get_height() // 2
            
            for x, y, speed, prev_y in self.falling_tears:
                if -50 <= x <= WIDTH + 50 and -50 <= y <= HEIGHT + 50:
                    surface.blit(img, (x - img_width_half, y - img_height_half))
        else:
            # 이미지가 없으면 원으로 그리기
            for x, y, speed, prev_y in self.falling_tears:
                if -50 <= x <= WIDTH + 50 and -50 <= y <= HEIGHT + 50:
                    pygame.draw.circle(surface, (100, 150, 255), (int(x), int(y)), 3)


class QuakeEffect(SpecialEffect):
    """지진 효과"""
    def __init__(self):
        super().__init__("quake", 180)  # 3초
        self.screen_shake_x = 0
        self.screen_shake_y = 0
        self.original_player_speed = 0
        self.original_ball_speed = [0, 0]
        
        # 사운드 로드
        try:
            import pygame
            self.quake_sound = pygame.mixer.Sound("sounds/quake_sound.wav")
        except:
            self.quake_sound = None
    
    def on_activate(self):
        # 플레이어 속도 저장 및 감소
        player_speed = self.data.get('player_speed', 5)
        self.original_player_speed = player_speed
        
        # 공 속도 저장
        ball_vel = self.data.get('ball_vel', [0, 0])
        self.original_ball_speed = [ball_vel[0], ball_vel[1]]
        
        # 효과음 재생
        if self.quake_sound:
            self.quake_sound.play()
        
        print("!")
    
    def on_deactivate(self):
        self.screen_shake_x = 0
        self.screen_shake_y = 0
        
        if self.quake_sound:
            self.quake_sound.stop()
        
        print("")
    
    def on_update(self, game_state):
        import random
        import math
        
        # 화면 흔들림 효과
        intensity = 8
        self.screen_shake_x = random.randint(-intensity, intensity)
        self.screen_shake_y = random.randint(-intensity, intensity)
        
        # 공 흔들림 효과
        ball_vel = game_state.get('ball_vel', [0, 0])
        shake_x = random.uniform(-2, 2)
        shake_y = random.uniform(-2, 2)
        ball_vel[0] += shake_x
        ball_vel[1] += shake_y
    
    def get_shake_offset(self):
        """화면 흔들림 오프셋 반환"""
        return (self.screen_shake_x, self.screen_shake_y)
    
    def draw(self, surface):
        """지진 시각 효과"""
        if not self.active:
            return
        
        # 지진 효과는 주로 화면 흔들림으로 표현되므로
        # 추가적인 시각 효과는 최소화


# ================================================================================
# 🎭 SPECIAL EFFECTS MANAGER (특수 효과 관리자)
# ================================================================================

class SpecialEffectsManager:
    """특수 효과 통합 관리자"""
    def __init__(self):
        self.effects = {
            'emotional_overdrive': EmotionalOverdriveEffect(),
            'whip': WhipEffect(),
            'balloon': BalloonEffect(),
            'tears': TearsEffect(),
            'quake': QuakeEffect()
        }
        
        self.active_effects = []
    
    def init_manager(self, screen, width=600, height=750):
        """매니저 초기화"""
        global SCREEN, WIDTH, HEIGHT
        SCREEN = screen
        WIDTH = width
        HEIGHT = height
    
    def activate_effect(self, effect_name, **kwargs):
        """특수 효과 활성화"""
        if effect_name in self.effects:
            effect = self.effects[effect_name]
            effect.activate(**kwargs)
            if effect not in self.active_effects:
                self.active_effects.append(effect)
            return True
        return False
    
    def deactivate_effect(self, effect_name):
        """특수 효과 비활성화"""
        if effect_name in self.effects:
            effect = self.effects[effect_name]
            effect.deactivate()
            if effect in self.active_effects:
                self.active_effects.remove(effect)
    
    def update_all_effects(self, game_state):
        """모든 활성 효과 업데이트"""
        for effect in self.active_effects[:]:
            effect.update(game_state)
            if not effect.active:
                self.active_effects.remove(effect)
    
    def draw_all_effects(self, surface):
        """모든 활성 효과 그리기"""
        for effect in self.active_effects:
            effect.draw(surface)
    
    def get_effect(self, effect_name):
        """특정 효과 객체 반환"""
        return self.effects.get(effect_name)
    
    def is_effect_active(self, effect_name):
        """효과 활성 상태 확인"""
        if effect_name in self.effects:
            return self.effects[effect_name].active
        return False
    
    def clear_all_effects(self):
        """모든 효과 초기화"""
        for effect in self.effects.values():
            effect.deactivate()
        self.active_effects.clear()
    
    def reset_round_effects(self):
        """라운드별 리셋이 필요한 효과들 처리"""
        # 풍선 효과 리셋
        balloon_effect = self.effects.get('balloon')
        if balloon_effect:
            balloon_effect.deactivate()
            balloon_effect.used_this_round = False


# 전역 특수 효과 매니저 인스턴스
special_effects_manager = SpecialEffectsManager()


# ================================================================================
# 🧪 TEST FUNCTIONS (테스트 함수)
# ================================================================================

def test_effects():
    """이펙트 테스트 함수"""
    print("")
    
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Effects Manager Test")
    
    init_effects_manager(screen)
    clock = pygame.time.Clock()
    
    # 테스트 데이터
    test_timer = 0
    
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_1:
                    spawn_flame_particles(WIDTH//2, HEIGHT//2, 10)
                elif event.key == pygame.K_2:
                    spawn_star_particles(WIDTH//2, HEIGHT//2, 5)
                elif event.key == pygame.K_3:
                    create_balloon_pop_effect(WIDTH//2, HEIGHT//2, (255, 0, 0))
                elif event.key == pygame.K_4:
                    show_item_obtained_effect({'name': 'Test Item', 'type': 'active'})
                elif event.key == pygame.K_5:
                    create_impact_effect(WIDTH//2, HEIGHT//2, 10)
                elif event.key == pygame.K_6:
                    show_hongryun_explosion()
        
        # 화면 클리어
        screen.fill((20, 20, 40))
        
        # 자동 이펙트 생성 (테스트용)
        test_timer += 1
        if test_timer % 60 == 0:  # 1초마다
            spawn_flame_particles(random.randint(50, WIDTH-50), random.randint(50, HEIGHT-50), 3)
        
        # 이펙트 업데이트 및 그리기
        update_all_effects()
        draw_all_effects(screen)
        
        # 가이드 텍스트
        font = pygame.font.Font(None, 24)
        guide_text = [
            "Press 1: Flame Particles",
            "Press 2: Star Particles", 
            "Press 3: Balloon Pop",
            "Press 4: Item Effect",
            "Press 5: Impact Effect",
            "Press 6: Explosion"
        ]
        
        for i, text in enumerate(guide_text):
            surface = font.render(text, True, WHITE)
            screen.blit(surface, (10, 10 + i * 25))
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()


# 모듈 테스트
if __name__ == "__main__":
    test_effects()

