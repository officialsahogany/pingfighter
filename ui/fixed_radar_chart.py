"""
레이더 차트 UI 개선 모듈
- 라벨 겹침 문제 해결
- 반응형 레이아웃 적용
"""

import pygame
import math


def draw_improved_radar_chart(screen, stats, center_x, center_y, radius=120):
    """개선된 능력치 레이더 차트 그리기"""
    
    # 네오둥근모 폰트 로드
    try:
        font_label = pygame.font.Font("NeoDGM.ttf", 14)  # 라벨용 작은 폰트
        font_grade = pygame.font.Font("NeoDGM.ttf", 12)  # 등급 표시용
        font_percent = pygame.font.Font("NeoDGM.ttf", 10)  # 퍼센트 표시용
    except:
        font_label = pygame.font.Font(None, 14)
        font_grade = pygame.font.Font(None, 12)
        font_percent = pygame.font.Font(None, 10)
    
    # 색상 정의
    WHITE = (255, 255, 255)
    GRAY = (150, 150, 150)
    LIGHT_GRAY = (100, 100, 100)
    DARK_GRAY = (50, 50, 50)
    BLUE = (100, 150, 255)
    
    # 능력치 데이터 (0-100 범위로 정규화)
    abilities = {
        "스킬 활용": stats.get('skill_mastery_score', 0),
        "대쉬 활용": stats.get('dash_mastery_score', 0),
        "아이템 활용": stats.get('item_mastery_score', 0),
        "가드 능력": stats.get('guard_ability_score', 0)
    }
    
    # 능력치 수와 각도 계산
    num_abilities = len(abilities)
    angle_step = 2 * math.pi / num_abilities
    
    # 배경 원형 그리드 그리기 (20, 40, 60, 80, 100%)
    for i in range(1, 6):
        grid_radius = radius * (i / 5)
        pygame.draw.circle(screen, DARK_GRAY, (center_x, center_y), int(grid_radius), 1)
    
    # 축 선 그리기
    ability_names = list(abilities.keys())
    points = []
    
    for i, ability_name in enumerate(ability_names):
        angle = -math.pi / 2 + i * angle_step  # -90도부터 시작 (위쪽)
        
        # 축 선 그리기
        end_x = center_x + math.cos(angle) * radius
        end_y = center_y + math.sin(angle) * radius
        pygame.draw.line(screen, LIGHT_GRAY, (center_x, center_y), (end_x, end_y), 1)
        
        # 능력치 값에 따른 점 위치 계산
        value = abilities[ability_name]
        value_radius = radius * (value / 100)
        point_x = center_x + math.cos(angle) * value_radius
        point_y = center_y + math.sin(angle) * value_radius
        points.append((point_x, point_y))
        
        # 능력명 텍스트 표시 (개선된 위치 계산)
        # 라벨 거리를 동적으로 조정
        label_distance = radius + 25  # 기존 30에서 25로 축소
        text_x = center_x + math.cos(angle) * label_distance
        text_y = center_y + math.sin(angle) * label_distance
        
        # 등급 색상 계산
        grade, color = score_to_grade(value)
        
        # 라벨 텍스트 렌더링
        ability_text = font_label.render(ability_name, True, WHITE)
        grade_text = font_grade.render(f"({grade})", True, color)
        
        # 각 방향에 따른 정밀한 위치 조정
        ability_rect = ability_text.get_rect()
        grade_rect = grade_text.get_rect()
        
        # 위쪽 (스킬 활용)
        if i == 0:
            ability_rect.centerx = text_x
            ability_rect.bottom = text_y - 5
            grade_rect.centerx = text_x
            grade_rect.top = text_y - 3
        
        # 오른쪽 (대쉬 활용) - 문제가 되는 부분
        elif i == 1:
            ability_rect.left = text_x + 8
            ability_rect.centery = text_y - 8
            grade_rect.left = text_x + 8
            grade_rect.centery = text_y + 8
        
        # 아래쪽 (아이템 활용)
        elif i == 2:
            ability_rect.centerx = text_x
            ability_rect.top = text_y + 5
            grade_rect.centerx = text_x
            grade_rect.top = text_y + 20
        
        # 왼쪽 (가드 능력)
        elif i == 3:
            ability_rect.right = text_x - 8
            ability_rect.centery = text_y - 8
            grade_rect.right = text_x - 8
            grade_rect.centery = text_y + 8
        
        # 화면 경계 체크 및 조정
        screen_width = screen.get_width()
        screen_height = screen.get_height()
        
        # 오른쪽 경계 체크
        if ability_rect.right > screen_width - 10:
            offset = ability_rect.right - (screen_width - 10)
            ability_rect.x -= offset
            grade_rect.x -= offset
        
        # 왼쪽 경계 체크
        if ability_rect.left < 10:
            offset = 10 - ability_rect.left
            ability_rect.x += offset
            grade_rect.x += offset
        
        # 텍스트 그리기
        screen.blit(ability_text, ability_rect)
        screen.blit(grade_text, grade_rect)
    
    # 능력치 영역 채우기 (반투명)
    if len(points) >= 3:
        # 반투명 서페이스 생성
        overlay = pygame.Surface((radius * 2 + 100, radius * 2 + 100), pygame.SRCALPHA)
        
        # 중심을 기준으로 좌표 변환
        relative_points = [
            (x - center_x + radius + 50, y - center_y + radius + 50) 
            for x, y in points
        ]
        
        # 채우기
        pygame.draw.polygon(overlay, (*BLUE, 80), relative_points)
        screen.blit(overlay, (center_x - radius - 50, center_y - radius - 50))
    
    # 능력치 점들을 선으로 연결
    if len(points) >= 2:
        pygame.draw.polygon(screen, BLUE, points, 2)
    
    # 능력치 점 표시
    for point in points:
        pygame.draw.circle(screen, WHITE, (int(point[0]), int(point[1])), 4)
        pygame.draw.circle(screen, BLUE, (int(point[0]), int(point[1])), 3)
    
    # 중심점 표시
    pygame.draw.circle(screen, (200, 200, 200), (center_x, center_y), 3)
    
    # 퍼센트 표시 (격자선 위에 작게)
    for i in range(1, 6):
        percent = i * 20
        percent_text = font_percent.render(f"{percent}", True, GRAY)
        
        # 우측 상단 대각선 방향에 표시
        angle = -math.pi / 4  # 45도
        percent_x = center_x + math.cos(angle) * (radius * (i / 5))
        percent_y = center_y + math.sin(angle) * (radius * (i / 5))
        
        percent_rect = percent_text.get_rect(center=(percent_x + 10, percent_y - 5))
        screen.blit(percent_text, percent_rect)


def score_to_grade(score):
    """점수를 등급과 색상으로 변환"""
    if score >= 90:
        return "S", (255, 215, 0)  # 골드
    elif score >= 80:
        return "A", (150, 255, 150)  # 연녹색
    elif score >= 70:
        return "B", (100, 200, 255)  # 하늘색
    elif score >= 60:
        return "C", (200, 200, 255)  # 연보라
    elif score >= 50:
        return "D", (255, 200, 150)  # 연주황
    elif score >= 30:
        return "E", (255, 150, 100)  # 오렌지
    else:
        return "F", (150, 150, 150)  # 그레이


def draw_compact_radar_chart(screen, stats, center_x, center_y, radius=80):
    """작은 공간에 맞는 컴팩트한 레이더 차트"""
    
    # 네오둥근모 폰트 로드 (더 작은 크기)
    try:
        font_label = pygame.font.Font("NeoDGM.ttf", 11)
        font_grade = pygame.font.Font("NeoDGM.ttf", 10)
    except:
        font_label = pygame.font.Font(None, 11)
        font_grade = pygame.font.Font(None, 10)
    
    # 색상 정의
    WHITE = (255, 255, 255)
    GRAY = (100, 100, 100)
    DARK_GRAY = (50, 50, 50)
    BLUE = (100, 150, 255)
    
    # 능력치 데이터 간소화 (한글 축약)
    abilities = {
        "스킬": stats.get('skill_mastery_score', 0),
        "대쉬": stats.get('dash_mastery_score', 0),
        "아이템": stats.get('item_mastery_score', 0),
        "가드": stats.get('guard_ability_score', 0)
    }
    
    # 능력치 수와 각도 계산
    num_abilities = len(abilities)
    angle_step = 2 * math.pi / num_abilities
    
    # 배경 원형 그리드 (간소화)
    for i in [2, 4]:  # 40%, 80%만 표시
        grid_radius = radius * (i / 5)
        pygame.draw.circle(screen, DARK_GRAY, (center_x, center_y), int(grid_radius), 1)
    
    # 외곽선
    pygame.draw.circle(screen, GRAY, (center_x, center_y), radius, 1)
    
    # 축 선과 라벨
    ability_names = list(abilities.keys())
    points = []
    
    for i, ability_name in enumerate(ability_names):
        angle = -math.pi / 2 + i * angle_step
        
        # 축 선
        end_x = center_x + math.cos(angle) * radius
        end_y = center_y + math.sin(angle) * radius
        pygame.draw.line(screen, GRAY, (center_x, center_y), (end_x, end_y), 1)
        
        # 능력치 점
        value = abilities[ability_name]
        value_radius = radius * (value / 100)
        point_x = center_x + math.cos(angle) * value_radius
        point_y = center_y + math.sin(angle) * value_radius
        points.append((point_x, point_y))
        
        # 라벨 (더 가까이)
        label_distance = radius + 15
        text_x = center_x + math.cos(angle) * label_distance
        text_y = center_y + math.sin(angle) * label_distance
        
        # 등급
        grade, color = score_to_grade(value)
        
        # 텍스트 렌더링 (능력명과 등급을 한 줄로)
        label_text = font_label.render(f"{ability_name}({grade})", True, color)
        label_rect = label_text.get_rect(center=(text_x, text_y))
        
        # 경계 조정
        if label_rect.right > screen.get_width() - 5:
            label_rect.right = screen.get_width() - 5
        if label_rect.left < 5:
            label_rect.left = 5
        
        screen.blit(label_text, label_rect)
    
    # 영역 채우기
    if len(points) >= 3:
        overlay = pygame.Surface((radius * 2 + 40, radius * 2 + 40), pygame.SRCALPHA)
        relative_points = [
            (x - center_x + radius + 20, y - center_y + radius + 20) 
            for x, y in points
        ]
        pygame.draw.polygon(overlay, (*BLUE, 60), relative_points)
        screen.blit(overlay, (center_x - radius - 20, center_y - radius - 20))
    
    # 선 연결
    if len(points) >= 2:
        pygame.draw.polygon(screen, BLUE, points, 2)
    
    # 점 표시
    for point in points:
        pygame.draw.circle(screen, BLUE, (int(point[0]), int(point[1])), 3)