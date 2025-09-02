"""
게임 유틸리티 함수 모음
점진적 리팩토링을 위한 유틸리티 함수 분리
"""
import pygame
import math
import random

def clamp(value, min_val, max_val):
    """값을 최소/최대 범위 내로 제한"""
    return max(min_val, min(value, max_val))

def lerp(start, end, t):
    """선형 보간 (Linear Interpolation)"""
    return start + (end - start) * t

def distance(x1, y1, x2, y2):
    """두 점 사이의 거리 계산"""
    return math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)

def normalize_vector(x, y):
    """벡터를 정규화 (단위 벡터로 변환)"""
    length = math.sqrt(x * x + y * y)
    if length == 0:
        return 0, 0
    return x / length, y / length

def rotate_point(x, y, angle):
    """점을 원점 기준으로 회전"""
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)
    return x * cos_a - y * sin_a, x * sin_a + y * cos_a

def get_random_color():
    """랜덤 색상 생성"""
    return (random.randint(100, 255), 
            random.randint(100, 255), 
            random.randint(100, 255))

def blend_colors(color1, color2, ratio):
    """두 색상을 비율에 따라 혼합"""
    ratio = clamp(ratio, 0, 1)
    return tuple(int(c1 * (1 - ratio) + c2 * ratio) 
                 for c1, c2 in zip(color1, color2))

def get_gradient_color(start_color, end_color, t):
    """그라데이션 색상 계산"""
    t = clamp(t, 0, 1)
    return blend_colors(start_color, end_color, t)

def draw_gradient_rect(surface, rect, color1, color2, vertical=True):
    """그라데이션 사각형 그리기"""
    x, y, width, height = rect
    if vertical:
        for i in range(height):
            ratio = i / height
            color = get_gradient_color(color1, color2, ratio)
            pygame.draw.line(surface, color, (x, y + i), (x + width, y + i))
    else:
        for i in range(width):
            ratio = i / width
            color = get_gradient_color(color1, color2, ratio)
            pygame.draw.line(surface, color, (x + i, y), (x + i, y + height))

def get_angle_between_points(x1, y1, x2, y2):
    """두 점 사이의 각도 계산 (라디안)"""
    return math.atan2(y2 - y1, x2 - x1)

def get_velocity_from_angle(angle, speed):
    """각도와 속도로 속도 벡터 계산"""
    return speed * math.cos(angle), speed * math.sin(angle)

def reflect_vector(vx, vy, normal_x, normal_y):
    """벡터를 법선 벡터에 대해 반사"""
    dot = vx * normal_x + vy * normal_y
    return vx - 2 * dot * normal_x, vy - 2 * dot * normal_y

def screen_shake(intensity=5):
    """화면 흔들림 효과를 위한 오프셋 생성"""
    return random.randint(-intensity, intensity), random.randint(-intensity, intensity)

def create_particle_effect(x, y, count=10, colors=None, speed_range=(1, 5)):
    """파티클 효과 생성"""
    particles = []
    for _ in range(count):
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(*speed_range)
        vx, vy = get_velocity_from_angle(angle, speed)
        color = random.choice(colors) if colors else get_random_color()
        particles.append({
            'x': x, 'y': y,
            'vx': vx, 'vy': vy,
            'life': 30,
            'color': color,
            'size': random.randint(2, 5)
        })
    return particles