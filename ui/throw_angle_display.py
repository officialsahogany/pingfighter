"""
투척류 아이템 각도 브리핑 시스템
각도 표시, 궤적 미리보기, 파워 게이지 등
"""

import pygame
import math

class ThrowAngleDisplay:
    """투척 각도 및 궤적 표시 시스템"""
    
    def __init__(self, screen, width, height):
        self.screen = screen
        self.width = width
        self.height = height
        
        # 폰트 설정
        try:
            self.font_large = pygame.font.Font("NanumSquareB.ttf", 36)
            self.font_medium = pygame.font.Font("NanumSquareR.ttf", 24)
            self.font_small = pygame.font.Font("NanumSquareR.ttf", 18)
        except:
            self.font_large = pygame.font.Font(None, 36)
            self.font_medium = pygame.font.Font(None, 24)
            self.font_small = pygame.font.Font(None, 18)
        
        # 색상 정의
        self.COLOR_ANGLE_LINE = (255, 255, 100)  # 노란색 조준선
        self.COLOR_TRAJECTORY = (100, 255, 100, 128)  # 반투명 초록색 궤적
        self.COLOR_TARGET = (255, 100, 100)  # 빨간색 타겟
        self.COLOR_INFO_BG = (0, 0, 0, 180)  # 반투명 검은 배경
        self.COLOR_TEXT = (255, 255, 255)  # 흰색 텍스트
        
        # 궤적 포인트 저장
        self.trajectory_points = []
        
    def calculate_angle(self, start_pos, end_pos):
        """두 점 사이의 각도 계산 (도 단위)"""
        dx = end_pos[0] - start_pos[0]
        dy = end_pos[1] - start_pos[1]
        angle_rad = math.atan2(-dy, dx)  # Y축이 아래로 증가하므로 -dy
        angle_deg = math.degrees(angle_rad)
        
        # 0~360도로 정규화
        if angle_deg < 0:
            angle_deg += 360
            
        return angle_deg
    
    def calculate_distance(self, start_pos, end_pos):
        """두 점 사이의 거리 계산"""
        dx = end_pos[0] - start_pos[0]
        dy = end_pos[1] - start_pos[1]
        return math.sqrt(dx**2 + dy**2)
    
    def calculate_trajectory_parabola(self, start_pos, end_pos, num_points=20):
        """포물선 궤적 계산 (연막탄 등)"""
        trajectory = []
        dx = end_pos[0] - start_pos[0]
        dy = end_pos[1] - start_pos[1]
        
        # 포물선 높이 계산 (거리에 비례)
        distance = math.sqrt(dx**2 + dy**2)
        max_height = min(distance * 0.3, 150)  # 최대 높이 제한
        
        for i in range(num_points + 1):
            t = i / num_points
            
            # 선형 보간
            x = start_pos[0] + dx * t
            y = start_pos[1] + dy * t
            
            # 포물선 높이 추가 (위로 볼록)
            parabola_height = max_height * 4 * t * (1 - t)
            y -= parabola_height
            
            trajectory.append((x, y))
        
        return trajectory
    
    def calculate_trajectory_straight(self, start_pos, end_pos, num_points=10):
        """직선 궤적 계산 (수류탄, 화염병 등)"""
        trajectory = []
        dx = end_pos[0] - start_pos[0]
        dy = end_pos[1] - start_pos[1]
        
        for i in range(num_points + 1):
            t = i / num_points
            x = start_pos[0] + dx * t
            y = start_pos[1] + dy * t
            trajectory.append((x, y))
        
        return trajectory
    
    def draw_angle_briefing(self, player_pos, target_pos, item_type="grenade"):
        """각도 브리핑 표시"""
        # 각도와 거리 계산
        angle = self.calculate_angle(player_pos, target_pos)
        distance = self.calculate_distance(player_pos, target_pos)
        
        # 1. 조준선 그리기
        self.draw_aim_line(player_pos, target_pos, angle)
        
        # 2. 궤적 미리보기
        if item_type in ["smoke_grenade"]:
            # 포물선 궤적
            trajectory = self.calculate_trajectory_parabola(player_pos, target_pos)
        else:
            # 직선 궤적
            trajectory = self.calculate_trajectory_straight(player_pos, target_pos)
        
        self.draw_trajectory(trajectory, item_type)
        
        # 3. 타겟 마커
        self.draw_target_marker(target_pos)
        
        # 4. 정보 패널
        self.draw_info_panel(angle, distance, item_type, player_pos)
        
    def draw_aim_line(self, start_pos, end_pos, angle):
        """조준선 그리기"""
        # 점선으로 조준선 표시
        dx = end_pos[0] - start_pos[0]
        dy = end_pos[1] - start_pos[1]
        distance = math.sqrt(dx**2 + dy**2)
        
        if distance > 0:
            num_dashes = int(distance / 20)
            for i in range(0, num_dashes, 2):
                t1 = i / num_dashes
                t2 = min((i + 1) / num_dashes, 1.0)
                
                x1 = start_pos[0] + dx * t1
                y1 = start_pos[1] + dy * t1
                x2 = start_pos[0] + dx * t2
                y2 = start_pos[1] + dy * t2
                
                pygame.draw.line(self.screen, self.COLOR_ANGLE_LINE, (x1, y1), (x2, y2), 2)
        
        # 각도 표시 (시작점 근처)
        angle_text = f"{angle:.0f}°"
        text_surf = self.font_medium.render(angle_text, True, self.COLOR_ANGLE_LINE)
        text_pos = (start_pos[0] + 30, start_pos[1] - 30)
        
        # 배경 박스
        text_rect = text_surf.get_rect(topleft=text_pos)
        bg_rect = text_rect.inflate(10, 6)
        bg_surf = pygame.Surface((bg_rect.width, bg_rect.height), pygame.SRCALPHA)
        bg_surf.fill((0, 0, 0, 150))
        self.screen.blit(bg_surf, bg_rect)
        self.screen.blit(text_surf, text_pos)
    
    def draw_trajectory(self, trajectory, item_type):
        """궤적 미리보기 그리기"""
        if len(trajectory) < 2:
            return
        
        # 궤적 색상 설정 (아이템별)
        colors = {
            "grenade": (80, 100, 80, 128),  # 카키색
            "smoke_grenade": (150, 150, 150, 128),  # 회색
            "flare": (255, 255, 150, 128),  # 밝은 노란색
            "molotov": (255, 100, 0, 128),  # 주황색
        }
        color = colors.get(item_type, self.COLOR_TRAJECTORY)
        
        # 궤적 점들 그리기
        for i in range(len(trajectory) - 1):
            # 점선 효과
            if i % 2 == 0:
                start = trajectory[i]
                end = trajectory[i + 1]
                
                # 두께가 점점 가늘어지는 효과
                thickness = max(1, 4 - i // 5)
                
                # 선 그리기
                pygame.draw.line(self.screen, color[:3], start, end, thickness)
        
        # 궤적 포인트 마커
        for i, point in enumerate(trajectory):
            if i % 3 == 0:  # 3개마다 하나씩 표시
                radius = max(2, 5 - i // 4)
                pygame.draw.circle(self.screen, color[:3], 
                                 (int(point[0]), int(point[1])), radius)
    
    def draw_target_marker(self, target_pos):
        """타겟 마커 그리기"""
        # 십자선 타겟
        size = 20
        thickness = 3
        
        # 외곽 원
        pygame.draw.circle(self.screen, self.COLOR_TARGET, 
                         (int(target_pos[0]), int(target_pos[1])), size, thickness)
        
        # 십자선
        pygame.draw.line(self.screen, self.COLOR_TARGET,
                        (target_pos[0] - size, target_pos[1]),
                        (target_pos[0] + size, target_pos[1]), thickness)
        pygame.draw.line(self.screen, self.COLOR_TARGET,
                        (target_pos[0], target_pos[1] - size),
                        (target_pos[0], target_pos[1] + size), thickness)
        
        # 중앙 점
        pygame.draw.circle(self.screen, (255, 255, 255), 
                         (int(target_pos[0]), int(target_pos[1])), 3)
    
    def draw_info_panel(self, angle, distance, item_type, player_pos):
        """정보 패널 그리기"""
        # 아이템 이름 한글화
        item_names = {
            "grenade": "수류탄",
            "smoke_grenade": "연막탄",
            "flare": "조명탄",
            "molotov": "화염병"
        }
        item_name = item_names.get(item_type, item_type)
        
        # 패널 위치 (화면 상단 중앙)
        panel_width = 300
        panel_height = 100
        panel_x = (self.width - panel_width) // 2
        panel_y = 50
        
        # 배경 그리기
        panel_surf = pygame.Surface((panel_width, panel_height), pygame.SRCALPHA)
        panel_surf.fill(self.COLOR_INFO_BG)
        pygame.draw.rect(panel_surf, (255, 255, 100), 
                        (0, 0, panel_width, panel_height), 2)
        self.screen.blit(panel_surf, (panel_x, panel_y))
        
        # 텍스트 정보
        info_lines = [
            f"[{item_name} 투척 준비]",
            f"각도: {angle:.1f}°",
            f"거리: {distance:.0f}px",
            f"예상 도달시간: {distance/10:.1f}초"
        ]
        
        # 텍스트 그리기
        y_offset = panel_y + 10
        for i, line in enumerate(info_lines):
            if i == 0:
                text_surf = self.font_medium.render(line, True, (255, 255, 100))
            else:
                text_surf = self.font_small.render(line, True, self.COLOR_TEXT)
            
            text_rect = text_surf.get_rect(centerx=self.width // 2, y=y_offset)
            self.screen.blit(text_surf, text_rect)
            y_offset += 22
        
        # 방향 표시 화살표
        arrow_x = panel_x + panel_width - 40
        arrow_y = panel_y + panel_height // 2
        arrow_length = 25
        
        # 각도에 따른 화살표 방향
        angle_rad = math.radians(angle)
        end_x = arrow_x + arrow_length * math.cos(angle_rad)
        end_y = arrow_y - arrow_length * math.sin(angle_rad)  # Y축 반전
        
        # 화살표 그리기
        pygame.draw.line(self.screen, (255, 255, 100), 
                        (arrow_x, arrow_y), (end_x, end_y), 3)
        
        # 화살촉
        arrow_head_size = 8
        head_angle1 = angle_rad + math.radians(150)
        head_angle2 = angle_rad - math.radians(150)
        
        head1_x = end_x + arrow_head_size * math.cos(head_angle1)
        head1_y = end_y - arrow_head_size * math.sin(head_angle1)
        head2_x = end_x + arrow_head_size * math.cos(head_angle2)
        head2_y = end_y - arrow_head_size * math.sin(head_angle2)
        
        pygame.draw.polygon(self.screen, (255, 255, 100),
                          [(end_x, end_y), (head1_x, head1_y), (head2_x, head2_y)])

# 전역 인스턴스 (싱글톤)
_throw_angle_display = None

def get_throw_angle_display(screen=None, width=600, height=750):
    """투척 각도 표시 시스템 인스턴스 가져오기"""
    global _throw_angle_display
    if _throw_angle_display is None and screen is not None:
        _throw_angle_display = ThrowAngleDisplay(screen, width, height)
    return _throw_angle_display

def show_throw_briefing(player_pos, target_pos, item_type="grenade"):
    """투척 브리핑 표시 (간편 함수)"""
    display = get_throw_angle_display()
    if display:
        display.draw_angle_briefing(player_pos, target_pos, item_type)