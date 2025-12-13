# downtown/mystery_designs.py
# 차원의 틈(미스터리) 건물 5가지 고유 디자인

import pygame
import math
import random

def safe_surface(size, flags=pygame.SRCALPHA):
    """안전한 Surface 생성 (SRCALPHA 기본값)"""
    try:
        return pygame.Surface(size, flags)
    except:
        return pygame.Surface(size)


# ============================================================================
# 디자인 1: 보이드 포탈 - 검은 구멍 + 보라색 소용돌이
# ============================================================================
def draw_mystery_design_1(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 1: 보이드 포탈 - 검은 구멍 + 보라색 소용돌이"""
    w, h = building.width, building.height

    # 1. 배경 그림자 (건물 아래에만 - 사각형 아티팩트 방지)
    shadow_h = 15
    shadow_surf = safe_surface((w + 20, shadow_h))
    pygame.draw.ellipse(shadow_surf, (20, 0, 40, 80), (0, 0, w + 20, shadow_h))
    screen.blit(shadow_surf, (x - 10, y + h - 5))

    # 2. 보라색 외곽 글로우
    for layer in range(5):
        glow_size = w + 40 - layer * 6
        glow_surf = safe_surface((glow_size, glow_size))
        alpha = int(80 - layer * 15)
        pygame.draw.ellipse(glow_surf, (120, 0, 180, alpha), (0, 0, glow_size, glow_size))
        screen.blit(glow_surf, (x + w//2 - glow_size//2, y + h//2 - glow_size//2))

    # 3. 소용돌이 링 (6개)
    center_x = x + w // 2
    center_y = y + h // 2

    for ring in range(6):
        radius = 10 + ring * 8
        num_points = 20
        rotation = animation_timer * (1 + ring * 0.3)

        points = []
        for i in range(num_points):
            angle = (i / num_points) * math.pi * 2 + rotation
            # 소용돌이 효과
            spiral_offset = math.sin(angle * 3 + animation_timer * 2) * 3
            r = radius + spiral_offset
            px = center_x + r * math.cos(angle)
            py = center_y + r * math.sin(angle)
            points.append((px, py))

        # 링 색상 (보라 -> 검정)
        color_ratio = ring / 6
        r = int(100 * (1 - color_ratio))
        g = 0
        b = int(150 * (1 - color_ratio))

        if len(points) > 2:
            pygame.draw.lines(screen, (r, g, b), True, points, 2)

    # 4. 중앙 블랙홀
    black_hole_radius = 15
    for layer in range(8):
        alpha = 255 - layer * 30
        size = black_hole_radius - layer * 2
        if size > 0:
            hole_surf = safe_surface((size * 2, size * 2))
            pygame.draw.circle(hole_surf, (0, 0, 0, alpha), (size, size), size)
            screen.blit(hole_surf, (center_x - size, center_y - size))

    # 5. 물음표 (회전)
    try:
        font = pygame.font.Font(None, 36)
        text = font.render("?", True, (150, 0, 255))
        text_rotated = pygame.transform.rotate(text, math.sin(animation_timer * 2) * 15)
        text_rect = text_rotated.get_rect(center=(center_x, center_y))
        screen.blit(text_rotated, text_rect)
    except:
        pass

    # 6. 파티클 효과
    if building_id not in particles:
        particles[building_id] = []

    if random.random() < 0.2:
        angle = random.uniform(0, math.pi * 2)
        distance = random.uniform(30, 50)
        particles[building_id].append({
            'x': center_x + distance * math.cos(angle),
            'y': center_y + distance * math.sin(angle),
            'target_x': center_x,
            'target_y': center_y,
            'life': 1.0,
            'color': (120, 0, 180)
        })

    for particle in particles[building_id][:]:
        dx = particle['target_x'] - particle['x']
        dy = particle['target_y'] - particle['y']
        particle['x'] += dx * 0.05
        particle['y'] += dy * 0.05
        particle['life'] -= 0.02

        if particle['life'] <= 0:
            particles[building_id].remove(particle)
        else:
            alpha = int(255 * particle['life'])
            pygame.draw.circle(screen, (*particle['color'], alpha),
                             (int(particle['x']), int(particle['y'])), 2)


# ============================================================================
# 디자인 2: 차원 균열 - 금이 간 현실 + 빛나는 틈
# ============================================================================
def draw_mystery_design_2(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 2: 차원 균열 - 금이 간 현실"""
    w, h = building.width, building.height

    # 1. 건물 본체 (회색 벽)
    for i in range(h):
        ratio = i / h
        gray = int(60 + 40 * ratio)
        pygame.draw.line(screen, (gray, gray, gray), (x, y + i), (x + w, y + i))

    # 2. 균열 글로우 (사이안/마젠타)
    crack_glow = abs(math.sin(animation_timer * 3))

    # 주요 균열 3개
    cracks = [
        [(x + w * 0.3, y), (x + w * 0.4, y + h * 0.5), (x + w * 0.2, y + h)],
        [(x + w * 0.7, y + h * 0.2), (x + w * 0.5, y + h * 0.6), (x + w * 0.8, y + h)],
        [(x + w * 0.1, y + h * 0.3), (x + w * 0.6, y + h * 0.4), (x + w * 0.5, y + h * 0.9)]
    ]

    for crack_points in cracks:
        # 균열 글로우
        for offset in range(5, 0, -1):
            glow_surf = safe_surface((w, h))
            alpha = int(100 * crack_glow * (offset / 5))
            color = (0, 255, 255) if random.random() > 0.5 else (255, 0, 255)

            for i in range(len(crack_points) - 1):
                start = (crack_points[i][0] - x, crack_points[i][1] - y)
                end = (crack_points[i+1][0] - x, crack_points[i+1][1] - y)
                pygame.draw.line(glow_surf, (*color, alpha), start, end, offset * 2)

            screen.blit(glow_surf, (x, y))

        # 균열 본체 (검은색)
        pygame.draw.lines(screen, (0, 0, 0), False, crack_points, 3)

        # 빛나는 가장자리
        pygame.draw.lines(screen, (200, 200, 255), False, crack_points, 1)

    # 3. 차원 너머 보이는 빛
    random.seed(building_id + int(animation_timer * 10))
    for _ in range(15):
        px = random.randint(x + 10, x + w - 10)
        py = random.randint(y + 10, y + h - 10)

        # 균열 근처에만 빛 표시
        near_crack = False
        for crack_points in cracks:
            for crack_x, crack_y in crack_points:
                if abs(px - crack_x) < 15 and abs(py - crack_y) < 15:
                    near_crack = True
                    break

        if near_crack:
            size = random.randint(1, 3)
            color = random.choice([(0, 255, 255), (255, 0, 255), (255, 255, 0)])
            pygame.draw.circle(screen, color, (px, py), size)
    random.seed()

    # 4. "?" 마크 (깜박임)
    if math.sin(animation_timer * 5) > 0:
        try:
            font = pygame.font.Font(None, 48)
            text = font.render("?", True, (255, 255, 255))
            text_rect = text.get_rect(center=(x + w//2, y + h//2))
            screen.blit(text, text_rect)
        except:
            pass


# ============================================================================
# 디자인 3: 시공간 왜곡 - 체스판 패턴 + 휘어지는 공간
# ============================================================================
def draw_mystery_design_3(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 3: 시공간 왜곡 - 체스판 패턴"""
    w, h = building.width, building.height

    # 1. 배경 그라데이션 (보라 -> 검정)
    for i in range(h):
        ratio = i / h
        r = int(80 * (1 - ratio))
        g = 0
        b = int(120 * (1 - ratio))
        pygame.draw.line(screen, (r, g, b), (x, y + i), (x + w, y + i))

    # 2. 왜곡된 체스판
    tile_size = 10
    distortion = animation_timer * 2

    for ty in range(0, h, tile_size):
        for tx in range(0, w, tile_size):
            # 중심으로부터의 거리 기반 왜곡
            center_x = w // 2
            center_y = h // 2
            dx = tx - center_x
            dy = ty - center_y
            distance = math.sqrt(dx*dx + dy*dy)

            # 왜곡 적용
            wave = math.sin(distance * 0.1 + distortion) * 3
            warped_x = int(x + tx + wave)
            warped_y = int(y + ty + wave)

            # 체스판 색상
            is_white = ((tx // tile_size) + (ty // tile_size)) % 2 == 0

            if is_white:
                color = (200, 200, 255)
                alpha = int(100 + 50 * abs(math.sin(distortion + distance * 0.05)))
            else:
                color = (50, 0, 100)
                alpha = 200

            tile_surf = safe_surface((tile_size, tile_size))
            tile_surf.fill((*color, alpha))
            screen.blit(tile_surf, (warped_x, warped_y))

    # 3. 중앙 소용돌이 (시공간 중심)
    center_x = x + w // 2
    center_y = y + h // 2

    for ring in range(10):
        radius = 5 + ring * 4
        rotation = animation_timer * (2 + ring * 0.2)
        num_segments = 12

        for i in range(num_segments):
            angle1 = (i / num_segments) * math.pi * 2 + rotation
            angle2 = ((i + 0.5) / num_segments) * math.pi * 2 + rotation

            x1 = center_x + radius * math.cos(angle1)
            y1 = center_y + radius * math.sin(angle1)
            x2 = center_x + radius * math.cos(angle2)
            y2 = center_y + radius * math.sin(angle2)

            color_shift = (i + ring) % 3
            if color_shift == 0:
                color = (255, 0, 255)
            elif color_shift == 1:
                color = (0, 255, 255)
            else:
                color = (255, 255, 0)

            pygame.draw.line(screen, color, (x1, y1), (x2, y2), 2)

    # 4. 물음표 (왜곡 효과)
    try:
        font = pygame.font.Font(None, 40)
        text = font.render("?", True, (255, 255, 255))

        # 물결 왜곡 적용
        warped_text = safe_surface((text.get_width() + 20, text.get_height() + 20))
        warped_text.fill((0, 0, 0, 0))

        for dy in range(text.get_height()):
            wave_offset = int(5 * math.sin(dy * 0.3 + animation_timer * 3))
            screen.blit(text, (center_x - text.get_width()//2 + wave_offset,
                              center_y - text.get_height()//2 + dy),
                       (0, dy, text.get_width(), 1))
    except:
        pass


# ============================================================================
# 디자인 4: 양자 불확정성 - 동시에 여러 상태로 존재
# ============================================================================
def draw_mystery_design_4(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 4: 양자 불확정성 - 중첩된 건물들"""
    w, h = building.width, building.height

    # 1. 배경 (진한 남색)
    pygame.draw.rect(screen, (20, 20, 60), (x, y, w, h))

    # 2. 여러 상태로 중첩된 건물 (3개)
    states = [
        {'offset': (0, 0), 'color': (255, 0, 100), 'alpha': 100},
        {'offset': (5 * math.sin(animation_timer), 3 * math.cos(animation_timer * 1.5)),
         'color': (0, 255, 100), 'alpha': 100},
        {'offset': (3 * math.cos(animation_timer * 0.8), 5 * math.sin(animation_timer * 1.2)),
         'color': (100, 100, 255), 'alpha': 100}
    ]

    for state in states:
        offset_x, offset_y = state['offset']
        state_surf = safe_surface((w, h))

        # 건물 윤곽
        pygame.draw.rect(state_surf, (*state['color'], state['alpha']),
                        (0, 0, w, h), 3)

        # 내부 패턴
        for i in range(3):
            inner_margin = 10 + i * 8
            pygame.draw.rect(state_surf, (*state['color'], state['alpha'] // 2),
                           (inner_margin, inner_margin,
                            w - inner_margin * 2, h - inner_margin * 2), 2)

        screen.blit(state_surf, (x + offset_x, y + offset_y))

    # 3. 양자 파동 (확률 구름)
    wave_pulse = abs(math.sin(animation_timer * 3))

    for wave in range(5):
        wave_radius = 20 + wave * 10 + wave_pulse * 15
        wave_surf = safe_surface((wave_radius * 2, wave_radius * 2))
        alpha = int(50 * (1 - wave / 5) * wave_pulse)

        pygame.draw.circle(wave_surf, (150, 255, 255, alpha),
                          (wave_radius, wave_radius), wave_radius, 2)

        screen.blit(wave_surf, (x + w//2 - wave_radius, y + h//2 - wave_radius))

    # 4. 슈뢰딩거 고양이 물음표 (동시에 여러 위치)
    try:
        font = pygame.font.Font(None, 32)

        question_positions = [
            (x + w//2, y + h//2),
            (x + w//2 + 8, y + h//2 + 5),
            (x + w//2 - 5, y + h//2 - 3)
        ]

        colors = [(255, 0, 100, 150), (0, 255, 100, 150), (100, 100, 255, 150)]

        for pos, color in zip(question_positions, colors):
            text = font.render("?", True, color[:3])
            text.set_alpha(color[3])
            text_rect = text.get_rect(center=pos)
            screen.blit(text, text_rect)
    except:
        pass

    # 5. 입자-파동 이중성 효과
    random.seed(building_id * 7 + int(animation_timer * 5))
    for _ in range(20):
        px = random.randint(x + 5, x + w - 5)
        py = random.randint(y + 5, y + h - 5)

        # 입자로 보일 때
        if random.random() > 0.5:
            pygame.draw.circle(screen, (255, 255, 255), (px, py), 1)
        # 파동으로 보일 때
        else:
            wave_len = random.randint(3, 8)
            pygame.draw.line(screen, (200, 200, 255),
                           (px - wave_len, py), (px + wave_len, py), 1)
    random.seed()


# ============================================================================
# 디자인 5: 엔트로피 증가 - 질서에서 혼돈으로
# ============================================================================
def draw_mystery_design_5(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 5: 엔트로피 증가 - 무질서도 상승"""
    w, h = building.width, building.height

    # 1. 배경 그라데이션 (질서 -> 혼돈)
    for i in range(h):
        ratio = i / h  # 0 (상단, 질서) -> 1 (하단, 혼돈)

        # 색상도 질서에서 혼돈으로
        r = int(50 + 150 * ratio)
        g = int(50 - 30 * ratio)
        b = int(100 - 80 * ratio)

        # 노이즈 추가 (하단으로 갈수록 증가)
        noise = int(random.uniform(-30, 30) * ratio)
        r = max(0, min(255, r + noise))
        g = max(0, min(255, g + noise))
        b = max(0, min(255, b + noise))

        pygame.draw.line(screen, (r, g, b), (x, y + i), (x + w, y + i))

    # 2. 상단: 정렬된 격자 (질서)
    grid_size = 8
    for gx in range(0, w, grid_size):
        for gy in range(0, h // 3, grid_size):  # 상단 1/3만
            pygame.draw.rect(screen, (100, 100, 150),
                           (x + gx, y + gy, grid_size - 1, grid_size - 1), 1)

    # 3. 중단: 부분적 붕괴
    entropy_level = (animation_timer % 3) / 3  # 0-1 순환

    for gx in range(0, w, grid_size):
        for gy in range(h // 3, h * 2 // 3, grid_size):
            # 엔트로피에 따라 격자 흐트러짐
            offset_x = random.uniform(-5, 5) * entropy_level
            offset_y = random.uniform(-5, 5) * entropy_level
            rotation = random.uniform(-15, 15) * entropy_level

            rect_surf = safe_surface((grid_size, grid_size))
            pygame.draw.rect(rect_surf, (150, 100, 100),
                           (0, 0, grid_size - 1, grid_size - 1), 1)

            rotated = pygame.transform.rotate(rect_surf, rotation)
            screen.blit(rotated, (x + gx + offset_x, y + gy + offset_y))

    # 4. 하단: 완전한 혼돈
    random.seed(building_id + int(animation_timer * 10))
    for _ in range(50):
        px = random.randint(x, x + w)
        py = random.randint(y + h * 2 // 3, y + h)

        # 무작위 도형
        shape_type = random.randint(0, 2)
        size = random.randint(2, 6)
        color = (random.randint(100, 255),
                random.randint(50, 150),
                random.randint(50, 100))

        if shape_type == 0:  # 원
            pygame.draw.circle(screen, color, (px, py), size)
        elif shape_type == 1:  # 사각형
            pygame.draw.rect(screen, color, (px - size, py - size, size * 2, size * 2))
        else:  # 선
            angle = random.uniform(0, math.pi * 2)
            end_x = px + size * 3 * math.cos(angle)
            end_y = py + size * 3 * math.sin(angle)
            pygame.draw.line(screen, color, (px, py), (end_x, end_y), 2)
    random.seed()

    # 5. 물음표 (점점 흐트러짐)
    try:
        font = pygame.font.Font(None, 42)
        text = font.render("?", True, (255, 255, 255))

        # 엔트로피에 따라 왜곡
        for dy in range(text.get_height()):
            ratio = dy / text.get_height()
            distortion = int(15 * ratio * entropy_level * math.sin(dy * 0.2 + animation_timer * 5))

            screen.blit(text, (x + w//2 - text.get_width()//2 + distortion,
                              y + h//2 - text.get_height()//2 + dy),
                       (0, dy, text.get_width(), 1))
    except:
        pass

    # 6. 엔트로피 지표 (작은 막대)
    bar_width = w - 20
    bar_height = 4
    bar_x = x + 10
    bar_y = y + h - 10

    # 배경
    pygame.draw.rect(screen, (50, 50, 50), (bar_x, bar_y, bar_width, bar_height))
    # 엔트로피 수준
    filled_width = int(bar_width * entropy_level)
    pygame.draw.rect(screen, (255, 100, 0), (bar_x, bar_y, filled_width, bar_height))


# ============================================================================
# 디자인 딕셔너리
# ============================================================================
MYSTERY_DESIGNS = {
    1: draw_mystery_design_1,  # 보이드 포탈
    2: draw_mystery_design_2,  # 차원 균열
    3: draw_mystery_design_3,  # 시공간 왜곡
    4: draw_mystery_design_4,  # 양자 불확정성
    5: draw_mystery_design_5,  # 엔트로피 증가
}
