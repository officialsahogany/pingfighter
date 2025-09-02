"""
그리기 관련 유틸리티 클래스 및 함수 모음
점진적 리팩토링을 위한 그리기 코드 분리
"""
import pygame
import math
from .color_utils import blend_colors, get_neon_color
from .math_utils import calculate_distance

# === DrawHelper 클래스 ===
class DrawHelper:
    """pygame.draw 호출을 간소화하는 헬퍼 클래스"""
    
    def __init__(self, surface):
        """DrawHelper 초기화
        
        Args:
            surface: pygame.Surface 객체
        """
        self.surface = surface
        self.width = surface.get_width()
        self.height = surface.get_height()
    
    def circle(self, color, pos, radius, width=0):
        """원 그리기
        
        Args:
            color: RGB 색상 튜플
            pos: 중심 좌표 (x, y)
            radius: 반지름
            width: 선 두께 (0이면 채우기)
        """
        pygame.draw.circle(self.surface, color, pos, radius, width)
    
    def rect(self, color, rect, width=0, border_radius=0):
        """사각형 그리기
        
        Args:
            color: RGB 색상 튜플
            rect: pygame.Rect 또는 (x, y, w, h) 튜플
            width: 선 두께 (0이면 채우기)
            border_radius: 모서리 둥글기
        """
        if border_radius > 0:
            pygame.draw.rect(self.surface, color, rect, width, border_radius=border_radius)
        else:
            pygame.draw.rect(self.surface, color, rect, width)
    
    def line(self, color, start_pos, end_pos, width=1):
        """선 그리기
        
        Args:
            color: RGB 색상 튜플
            start_pos: 시작점 (x, y)
            end_pos: 끝점 (x, y)
            width: 선 두께
        """
        pygame.draw.line(self.surface, color, start_pos, end_pos, width)
    
    def polygon(self, color, points, width=0):
        """다각형 그리기
        
        Args:
            color: RGB 색상 튜플
            points: 꼭지점 좌표 리스트 [(x1,y1), (x2,y2), ...]
            width: 선 두께 (0이면 채우기)
        """
        pygame.draw.polygon(self.surface, color, points, width)
    
    def ellipse(self, color, rect, width=0):
        """타원 그리기
        
        Args:
            color: RGB 색상 튜플
            rect: pygame.Rect 또는 (x, y, w, h) 튜플
            width: 선 두께 (0이면 채우기)
        """
        pygame.draw.ellipse(self.surface, color, rect, width)
    
    def arc(self, color, rect, start_angle, end_angle, width=1):
        """호 그리기
        
        Args:
            color: RGB 색상 튜플
            rect: pygame.Rect 또는 (x, y, w, h) 튜플
            start_angle: 시작 각도 (라디안)
            end_angle: 끝 각도 (라디안)
            width: 선 두께
        """
        pygame.draw.arc(self.surface, color, rect, start_angle, end_angle, width)
    
    def lines(self, color, closed, points, width=1):
        """연결된 선 그리기
        
        Args:
            color: RGB 색상 튜플
            closed: True면 폐곡선, False면 열린 선
            points: 점 좌표 리스트
            width: 선 두께
        """
        pygame.draw.lines(self.surface, color, closed, points, width)

# === 고급 그리기 함수 ===
def draw_gradient_rect(surface, rect, color1, color2, vertical=True):
    """그라데이션 사각형 그리기
    
    Args:
        surface: pygame.Surface 객체
        rect: pygame.Rect 또는 (x, y, w, h) 튜플
        color1: 시작 색상
        color2: 끝 색상
        vertical: True면 수직, False면 수평 그라데이션
    """
    if isinstance(rect, pygame.Rect):
        x, y, width, height = rect.x, rect.y, rect.width, rect.height
    else:
        x, y, width, height = rect
    
    if vertical:
        for i in range(height):
            ratio = i / height if height > 0 else 0
            color = blend_colors(color1, color2, ratio)
            pygame.draw.line(surface, color, (x, y + i), (x + width, y + i))
    else:
        for i in range(width):
            ratio = i / width if width > 0 else 0
            color = blend_colors(color1, color2, ratio)
            pygame.draw.line(surface, color, (x + i, y), (x + i, y + height))

def draw_gradient_circle(surface, center, radius, color1, color2):
    """그라데이션 원 그리기 (중심에서 바깥쪽으로)
    
    Args:
        surface: pygame.Surface 객체
        center: 중심 좌표 (x, y)
        radius: 반지름
        color1: 중심 색상
        color2: 가장자리 색상
    """
    for r in range(radius, 0, -1):
        ratio = 1 - (r / radius)
        color = blend_colors(color1, color2, ratio)
        pygame.draw.circle(surface, color, center, r)

def draw_glow_effect(surface, pos, radius, color, intensity=3):
    """광채/글로우 효과 그리기
    
    Args:
        surface: pygame.Surface 객체
        pos: 중심 좌표 (x, y)
        radius: 기본 반지름
        color: 기본 색상
        intensity: 광채 강도 (레이어 수)
    """
    glow_color = get_neon_color(color)
    
    for i in range(intensity, 0, -1):
        # 반지름이 커질수록 투명도 증가
        alpha = 50 // i
        current_radius = radius + (i * 5)
        
        # 임시 서페이스에 그리기
        temp_surface = pygame.Surface((current_radius * 2 + 10, current_radius * 2 + 10), pygame.SRCALPHA)
        
        # 알파값 적용된 색상
        color_with_alpha = (*glow_color[:3], alpha)
        pygame.draw.circle(temp_surface, color_with_alpha, 
                         (current_radius + 5, current_radius + 5), current_radius)
        
        # 메인 서페이스에 블리팅
        surface.blit(temp_surface, 
                    (pos[0] - current_radius - 5, pos[1] - current_radius - 5), 
                    special_flags=pygame.BLEND_ADD)
    
    # 중심 원 그리기
    pygame.draw.circle(surface, color, pos, radius)

def draw_dashed_line(surface, color, start_pos, end_pos, dash_length=5, gap_length=5, width=1):
    """점선 그리기
    
    Args:
        surface: pygame.Surface 객체
        color: RGB 색상 튜플
        start_pos: 시작점 (x, y)
        end_pos: 끝점 (x, y)
        dash_length: 대시 길이
        gap_length: 간격 길이
        width: 선 두께
    """
    x1, y1 = start_pos
    x2, y2 = end_pos
    distance = calculate_distance(start_pos, end_pos)
    
    if distance == 0:
        return
    
    # 방향 벡터 계산
    dx = (x2 - x1) / distance
    dy = (y2 - y1) / distance
    
    # 점선 그리기
    current_distance = 0
    drawing = True
    
    while current_distance < distance:
        if drawing:
            segment_length = min(dash_length, distance - current_distance)
            end_x = x1 + dx * (current_distance + segment_length)
            end_y = y1 + dy * (current_distance + segment_length)
            start_x = x1 + dx * current_distance
            start_y = y1 + dy * current_distance
            pygame.draw.line(surface, color, (start_x, start_y), (end_x, end_y), width)
            current_distance += dash_length
        else:
            current_distance += gap_length
        drawing = not drawing

def draw_rounded_rect(surface, color, rect, corner_radius, width=0):
    """둥근 모서리 사각형 그리기
    
    Args:
        surface: pygame.Surface 객체
        color: RGB 색상 튜플
        rect: pygame.Rect 또는 (x, y, w, h) 튜플
        corner_radius: 모서리 반지름
        width: 선 두께 (0이면 채우기)
    """
    if isinstance(rect, pygame.Rect):
        x, y, w, h = rect.x, rect.y, rect.width, rect.height
    else:
        x, y, w, h = rect
    
    # 모서리 반지름 제한
    corner_radius = min(corner_radius, min(w, h) // 2)
    
    if width == 0:
        # 채우기 모드
        # 중앙 사각형
        pygame.draw.rect(surface, color, (x + corner_radius, y, w - 2 * corner_radius, h))
        pygame.draw.rect(surface, color, (x, y + corner_radius, w, h - 2 * corner_radius))
        
        # 모서리 원
        pygame.draw.circle(surface, color, (x + corner_radius, y + corner_radius), corner_radius)
        pygame.draw.circle(surface, color, (x + w - corner_radius, y + corner_radius), corner_radius)
        pygame.draw.circle(surface, color, (x + corner_radius, y + h - corner_radius), corner_radius)
        pygame.draw.circle(surface, color, (x + w - corner_radius, y + h - corner_radius), corner_radius)
    else:
        # 윤곽선 모드
        # 상하좌우 선
        pygame.draw.line(surface, color, (x + corner_radius, y), (x + w - corner_radius, y), width)
        pygame.draw.line(surface, color, (x + corner_radius, y + h), (x + w - corner_radius, y + h), width)
        pygame.draw.line(surface, color, (x, y + corner_radius), (x, y + h - corner_radius), width)
        pygame.draw.line(surface, color, (x + w, y + corner_radius), (x + w, y + h - corner_radius), width)
        
        # 모서리 호
        pygame.draw.arc(surface, color, (x, y, 2 * corner_radius, 2 * corner_radius), 
                       math.pi / 2, math.pi, width)
        pygame.draw.arc(surface, color, (x + w - 2 * corner_radius, y, 2 * corner_radius, 2 * corner_radius), 
                       0, math.pi / 2, width)
        pygame.draw.arc(surface, color, (x, y + h - 2 * corner_radius, 2 * corner_radius, 2 * corner_radius), 
                       math.pi, 3 * math.pi / 2, width)
        pygame.draw.arc(surface, color, (x + w - 2 * corner_radius, y + h - 2 * corner_radius, 
                       2 * corner_radius, 2 * corner_radius), 3 * math.pi / 2, 2 * math.pi, width)

def draw_star(surface, color, center, outer_radius, inner_radius, points=5, rotation=0):
    """별 모양 그리기
    
    Args:
        surface: pygame.Surface 객체
        color: RGB 색상 튜플
        center: 중심 좌표 (x, y)
        outer_radius: 외곽 반지름
        inner_radius: 내부 반지름
        points: 꼭지점 수
        rotation: 회전 각도 (라디안)
    """
    cx, cy = center
    vertices = []
    
    for i in range(points * 2):
        angle = rotation + (i * math.pi / points)
        if i % 2 == 0:
            # 외곽 점
            x = cx + outer_radius * math.cos(angle)
            y = cy + outer_radius * math.sin(angle)
        else:
            # 내부 점
            x = cx + inner_radius * math.cos(angle)
            y = cy + inner_radius * math.sin(angle)
        vertices.append((x, y))
    
    pygame.draw.polygon(surface, color, vertices)

def draw_heart(surface, color, center, size):
    """하트 모양 그리기
    
    Args:
        surface: pygame.Surface 객체
        color: RGB 색상 튜플
        center: 중심 좌표 (x, y)
        size: 크기
    """
    cx, cy = center
    points = []
    
    # 하트 모양 수식 사용
    for angle in range(0, 360, 5):
        rad = math.radians(angle)
        x = 16 * (math.sin(rad) ** 3)
        y = -(13 * math.cos(rad) - 5 * math.cos(2 * rad) - 2 * math.cos(3 * rad) - math.cos(4 * rad))
        
        # 크기 조정 및 위치 이동
        x = cx + x * size / 16
        y = cy + y * size / 16
        points.append((x, y))
    
    if len(points) > 2:
        pygame.draw.polygon(surface, color, points)

def draw_arrow(surface, color, start_pos, end_pos, width=2, head_size=10):
    """화살표 그리기
    
    Args:
        surface: pygame.Surface 객체
        color: RGB 색상 튜플
        start_pos: 시작점 (x, y)
        end_pos: 끝점 (x, y)
        width: 선 두께
        head_size: 화살촉 크기
    """
    x1, y1 = start_pos
    x2, y2 = end_pos
    
    # 화살표 몸체 그리기
    pygame.draw.line(surface, color, start_pos, end_pos, width)
    
    # 화살촉 계산
    angle = math.atan2(y2 - y1, x2 - x1)
    
    # 화살촉 꼭지점
    head_angle1 = angle + 2.5
    head_angle2 = angle - 2.5
    
    head_x1 = x2 - head_size * math.cos(head_angle1)
    head_y1 = y2 - head_size * math.sin(head_angle1)
    head_x2 = x2 - head_size * math.cos(head_angle2)
    head_y2 = y2 - head_size * math.sin(head_angle2)
    
    # 화살촉 그리기
    pygame.draw.polygon(surface, color, [(x2, y2), (head_x1, head_y1), (head_x2, head_y2)])

def draw_grid(surface, color, cell_size, line_width=1):
    """격자 그리기
    
    Args:
        surface: pygame.Surface 객체
        color: RGB 색상 튜플
        cell_size: 셀 크기
        line_width: 선 두께
    """
    width = surface.get_width()
    height = surface.get_height()
    
    # 수직선
    for x in range(0, width + 1, cell_size):
        pygame.draw.line(surface, color, (x, 0), (x, height), line_width)
    
    # 수평선
    for y in range(0, height + 1, cell_size):
        pygame.draw.line(surface, color, (0, y), (width, y), line_width)