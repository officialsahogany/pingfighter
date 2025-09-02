"""
수학 관련 유틸리티 함수 모음
점진적 리팩토링을 위한 수학 계산 코드 분리
"""
import math
import random

# === 기본 수학 상수 ===
PI = math.pi
TWO_PI = math.pi * 2
HALF_PI = math.pi / 2
QUARTER_PI = math.pi / 4

# 각도 변환
DEG_TO_RAD = math.pi / 180
RAD_TO_DEG = 180 / math.pi

# === 좌표 계산 함수 ===
def get_center_pos(rect):
    """pygame.Rect의 중심 좌표 반환
    
    Args:
        rect: pygame.Rect 객체
    
    Returns:
        중심 좌표 (x, y) 튜플
    """
    return (rect.centerx, rect.centery)

def calculate_distance(pos1, pos2):
    """두 점 사이의 거리 계산
    
    Args:
        pos1: 첫 번째 점 (x, y) 튜플
        pos2: 두 번째 점 (x, y) 튜플
    
    Returns:
        두 점 사이의 거리 (float)
    """
    return math.sqrt((pos1[0] - pos2[0])**2 + (pos1[1] - pos2[1])**2)

def calculate_distance_squared(pos1, pos2):
    """두 점 사이의 거리 제곱 계산 (성능 최적화용)
    
    제곱근 계산을 생략하여 성능 향상
    거리 비교만 필요한 경우 유용
    """
    return (pos1[0] - pos2[0])**2 + (pos1[1] - pos2[1])**2

def get_angle_between(pos1, pos2):
    """두 점 사이의 각도 계산 (라디안)
    
    Args:
        pos1: 시작점 (x, y)
        pos2: 끝점 (x, y)
    
    Returns:
        각도 (라디안, -π ~ π)
    """
    return math.atan2(pos2[1] - pos1[1], pos2[0] - pos1[0])

def get_angle_between_deg(pos1, pos2):
    """두 점 사이의 각도 계산 (도)
    
    Returns:
        각도 (도, -180 ~ 180)
    """
    return get_angle_between(pos1, pos2) * RAD_TO_DEG

# === 벡터 연산 함수 ===
def normalize_vector(x, y):
    """벡터 정규화 (단위 벡터로 변환)
    
    Args:
        x: 벡터의 x 성분
        y: 벡터의 y 성분
    
    Returns:
        정규화된 벡터 (x, y) 튜플
    """
    length = math.sqrt(x * x + y * y)
    if length == 0:
        return (0, 0)
    return (x / length, y / length)

def vector_length(x, y):
    """벡터의 길이 계산"""
    return math.sqrt(x * x + y * y)

def vector_dot(v1, v2):
    """벡터 내적 계산"""
    return v1[0] * v2[0] + v1[1] * v2[1]

def vector_add(v1, v2):
    """벡터 덧셈"""
    return (v1[0] + v2[0], v1[1] + v2[1])

def vector_subtract(v1, v2):
    """벡터 뺄셈"""
    return (v1[0] - v2[0], v1[1] - v2[1])

def vector_multiply(v, scalar):
    """벡터 스칼라 곱셈"""
    return (v[0] * scalar, v[1] * scalar)

def vector_reflect(velocity, normal):
    """벡터 반사 계산
    
    Args:
        velocity: 입사 속도 벡터 (vx, vy)
        normal: 법선 벡터 (nx, ny) - 정규화되어야 함
    
    Returns:
        반사된 속도 벡터 (vx, vy)
    """
    dot = velocity[0] * normal[0] + velocity[1] * normal[1]
    return (velocity[0] - 2 * dot * normal[0], 
            velocity[1] - 2 * dot * normal[1])

# === 회전 함수 ===
def rotate_point(x, y, angle):
    """점을 원점 기준으로 회전
    
    Args:
        x, y: 점의 좌표
        angle: 회전 각도 (라디안)
    
    Returns:
        회전된 좌표 (x, y)
    """
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)
    return (x * cos_a - y * sin_a, x * sin_a + y * cos_a)

def rotate_point_around(x, y, cx, cy, angle):
    """특정 중심점 기준으로 점 회전
    
    Args:
        x, y: 점의 좌표
        cx, cy: 회전 중심 좌표
        angle: 회전 각도 (라디안)
    
    Returns:
        회전된 좌표 (x, y)
    """
    # 중심점 기준으로 상대 좌표 계산
    rx = x - cx
    ry = y - cy
    # 회전
    rotated = rotate_point(rx, ry, angle)
    # 절대 좌표로 변환
    return (rotated[0] + cx, rotated[1] + cy)

# === 보간 함수 ===
def lerp(start, end, t):
    """선형 보간 (Linear Interpolation)
    
    Args:
        start: 시작값
        end: 끝값
        t: 보간 비율 (0.0 ~ 1.0)
    
    Returns:
        보간된 값
    """
    return start + (end - start) * t

def lerp_angle(start, end, t):
    """각도 보간 (최단 경로로 회전)
    
    Args:
        start: 시작 각도 (라디안)
        end: 끝 각도 (라디안)
        t: 보간 비율 (0.0 ~ 1.0)
    
    Returns:
        보간된 각도 (라디안)
    """
    diff = (end - start) % TWO_PI
    if diff > PI:
        diff -= TWO_PI
    return start + diff * t

def lerp_2d(start_pos, end_pos, t):
    """2D 좌표 선형 보간"""
    return (lerp(start_pos[0], end_pos[0], t),
            lerp(start_pos[1], end_pos[1], t))

def smoothstep(t):
    """부드러운 보간 곡선 (3t² - 2t³)"""
    t = max(0, min(1, t))
    return t * t * (3 - 2 * t)

def smootherstep(t):
    """더 부드러운 보간 곡선 (6t⁵ - 15t⁴ + 10t³)"""
    t = max(0, min(1, t))
    return t * t * t * (t * (t * 6 - 15) + 10)

# === 범위 제한 함수 ===
def clamp(value, min_val, max_val):
    """값을 최소/최대 범위로 제한"""
    return max(min_val, min(value, max_val))

def clamp_angle(angle):
    """각도를 -π ~ π 범위로 제한"""
    while angle > PI:
        angle -= TWO_PI
    while angle < -PI:
        angle += TWO_PI
    return angle

def clamp_angle_deg(angle):
    """각도를 -180 ~ 180 범위로 제한"""
    while angle > 180:
        angle -= 360
    while angle < -180:
        angle += 360
    return angle

# === 랜덤 함수 ===
def random_range(min_val, max_val):
    """범위 내 랜덤 실수"""
    return random.uniform(min_val, max_val)

def random_int_range(min_val, max_val):
    """범위 내 랜덤 정수"""
    return random.randint(min_val, max_val)

def random_angle():
    """랜덤 각도 (라디안)"""
    return random.uniform(0, TWO_PI)

def random_point_in_circle(center_x, center_y, radius):
    """원 내부의 랜덤 점 생성"""
    angle = random_angle()
    r = math.sqrt(random.random()) * radius
    return (center_x + r * math.cos(angle),
            center_y + r * math.sin(angle))

def random_point_on_circle(center_x, center_y, radius):
    """원 둘레의 랜덤 점 생성"""
    angle = random_angle()
    return (center_x + radius * math.cos(angle),
            center_y + radius * math.sin(angle))

# === 충돌 검사 함수 ===
def point_in_rect(point, rect):
    """점이 사각형 내부에 있는지 확인
    
    Args:
        point: (x, y) 튜플
        rect: pygame.Rect 객체
    
    Returns:
        bool: 내부에 있으면 True
    """
    return (rect.left <= point[0] <= rect.right and
            rect.top <= point[1] <= rect.bottom)

def point_in_circle(point, center, radius):
    """점이 원 내부에 있는지 확인"""
    return calculate_distance(point, center) <= radius

def circles_overlap(center1, radius1, center2, radius2):
    """두 원이 겹치는지 확인"""
    return calculate_distance(center1, center2) <= (radius1 + radius2)

def rect_overlap(rect1, rect2):
    """두 사각형이 겹치는지 확인"""
    return rect1.colliderect(rect2)

# === 물리 계산 함수 ===
def get_velocity_from_angle(angle, speed):
    """각도와 속도로 속도 벡터 계산
    
    Args:
        angle: 각도 (라디안)
        speed: 속력
    
    Returns:
        속도 벡터 (vx, vy)
    """
    return (speed * math.cos(angle), speed * math.sin(angle))

def get_angle_from_velocity(vx, vy):
    """속도 벡터로부터 각도 계산"""
    return math.atan2(vy, vx)

def get_speed_from_velocity(vx, vy):
    """속도 벡터로부터 속력 계산"""
    return math.sqrt(vx * vx + vy * vy)

def apply_friction(velocity, friction):
    """마찰력 적용
    
    Args:
        velocity: 현재 속도
        friction: 마찰 계수 (0.0 ~ 1.0)
    
    Returns:
        감속된 속도
    """
    return velocity * (1 - friction)

def apply_gravity(vy, gravity, max_fall_speed=None):
    """중력 적용
    
    Args:
        vy: 현재 수직 속도
        gravity: 중력 가속도
        max_fall_speed: 최대 낙하 속도 (선택)
    
    Returns:
        중력이 적용된 수직 속도
    """
    new_vy = vy + gravity
    if max_fall_speed is not None:
        new_vy = min(new_vy, max_fall_speed)
    return new_vy

# === 이징 함수 (Easing Functions) ===
def ease_in_quad(t):
    """2차 가속 이징"""
    return t * t

def ease_out_quad(t):
    """2차 감속 이징"""
    return t * (2 - t)

def ease_in_out_quad(t):
    """2차 가속-감속 이징"""
    if t < 0.5:
        return 2 * t * t
    return -1 + (4 - 2 * t) * t

def ease_in_cubic(t):
    """3차 가속 이징"""
    return t * t * t

def ease_out_cubic(t):
    """3차 감속 이징"""
    t -= 1
    return t * t * t + 1

def ease_in_out_cubic(t):
    """3차 가속-감속 이징"""
    if t < 0.5:
        return 4 * t * t * t
    t = 2 * t - 2
    return 1 + t * t * t / 2

def ease_in_elastic(t, period=0.3):
    """탄성 가속 이징"""
    if t == 0 or t == 1:
        return t
    s = period / (2 * PI) * math.asin(1)
    t -= 1
    return -(math.pow(2, 10 * t) * math.sin((t - s) * 2 * PI / period))

def ease_out_elastic(t, period=0.3):
    """탄성 감속 이징"""
    if t == 0 or t == 1:
        return t
    s = period / (2 * PI) * math.asin(1)
    return math.pow(2, -10 * t) * math.sin((t - s) * 2 * PI / period) + 1

def ease_out_bounce(t):
    """바운스 감속 이징"""
    if t < 1 / 2.75:
        return 7.5625 * t * t
    elif t < 2 / 2.75:
        t -= 1.5 / 2.75
        return 7.5625 * t * t + 0.75
    elif t < 2.5 / 2.75:
        t -= 2.25 / 2.75
        return 7.5625 * t * t + 0.9375
    else:
        t -= 2.625 / 2.75
        return 7.5625 * t * t + 0.984375