#!/usr/bin/env python3
"""
자연스러운 벽돌 균열 패턴 테스트

새로운 균열 시스템:
- 레벨 1: 브랜칭 균열 (가지형태)
- 레벨 2: 복잡한 네트워크 균열

테스트 방법:
1. 스페이스바: 균열 레벨 변경 (0 → 1 → 2 → 0)
2. 클릭: 새로운 벽돌 추가
3. ESC: 종료
"""

import pygame
import sys
import os
import random

# 게임 디렉토리를 Python 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 상수 정의
WIDTH = 800
HEIGHT = 600
FPS = 60

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
BROWN = (139, 69, 19)
GREEN = (0, 255, 0)
RED = (255, 0, 0)

class NaturalCracksTest:
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((WIDTH, HEIGHT))
        pygame.display.set_caption("자연스러운 벽돌 균열 패턴 테스트")
        self.clock = pygame.time.Clock()
        self.running = True
        
        # 벽돌 시스템
        self.walls = []
        self.add_test_bricks()
        
        # 폰트
        self.font = pygame.font.Font(None, 36)
        self.small_font = pygame.font.Font(None, 24)
        
    def add_test_bricks(self):
        """테스트용 벽돌 추가"""
        positions = [
            (150, 200, 0),  # (x, y, crack_level)
            (300, 200, 1),
            (450, 200, 2),
            (150, 300, 1),
            (300, 300, 2),
            (450, 300, 0),
            (150, 400, 2),
            (300, 400, 0),
            (450, 400, 1)
        ]
        
        for x, y, crack_level in positions:
            wall = {
                "rect": pygame.Rect(x, y, 80, 30),  # 좀 더 큰 벽돌로 균열 잘 보이게
                "crack_level": crack_level
            }
            self.walls.append(wall)
    
    def draw_brick_with_natural_cracks(self, wall_rect, wall_crack_level):
        """자연스러운 균열이 있는 벽돌 그리기"""
        draw = pygame.draw
        
        # 벽돌 기본 색상
        if wall_crack_level == 0:
            wall_color = (139, 69, 19)  # 갈색
        elif wall_crack_level == 1:
            wall_color = (160, 82, 45)  # 살짝 밝은 갈색 (손상 표시)
        else:
            wall_color = (184, 134, 11)  # 더 밝은 갈색 (심각한 손상)
        
        # 벽돌 그리기
        draw.rect(self.screen, wall_color, wall_rect)
        
        # 3D 효과 (하이라이트와 그림자)
        highlight_color = (min(255, wall_color[0] + 40), min(255, wall_color[1] + 40), min(255, wall_color[2] + 40))
        shadow_color = (max(0, wall_color[0] - 40), max(0, wall_color[1] - 40), max(0, wall_color[2] - 40))
        
        # 하이라이트 (위쪽, 왼쪽)
        draw.line(self.screen, highlight_color, wall_rect.topleft, wall_rect.topright, 2)
        draw.line(self.screen, highlight_color, wall_rect.topleft, wall_rect.bottomleft, 2)
        
        # 그림자 (아래쪽, 오른쪽)
        draw.line(self.screen, shadow_color, wall_rect.bottomleft, wall_rect.bottomright, 2)
        draw.line(self.screen, shadow_color, wall_rect.topright, wall_rect.bottomright, 2)
        
        # 모르타르 라인 (벽돌 사이의 시멘트)
        mortar_color = (105, 105, 105)
        middle_x = wall_rect.centerx
        draw.line(self.screen, mortar_color, (middle_x, wall_rect.top), (middle_x, wall_rect.bottom), 1)
        
        # 균열 색상 결정
        if wall_crack_level == 1:
            crack_color = (80, 40, 10)  # 어두운 갈색 (작은 균열)
        elif wall_crack_level == 2:
            crack_color = (220, 20, 60)  # 진한 빨간색 (심각한 균열)
        else:
            return  # 균열 없음
        
        # 자연스러운 균열 패턴 (브랜칭) - 실제 pingfighter.py 코드와 동일
        if wall_crack_level == 1:
            # 1단계: 작은 균열들 - 자연스러운 가지형태
            random.seed(wall_rect.x + wall_rect.y)  # 일관된 패턴을 위한 시드
            
            # 주 균열 - 위쪽에서 시작해서 아래로 뻗어나가는 불규칙한 선
            main_crack_start_x = wall_rect.centerx + random.randint(-10, 10)
            main_crack_start_y = wall_rect.top + random.randint(1, 3)
            
            current_x, current_y = main_crack_start_x, main_crack_start_y
            crack_points = [(current_x, current_y)]
            
            # 균열이 아래로 진행하며 랜덤하게 구부러짐
            for step in range(3):
                # 다음 점 계산 (주로 아래쪽으로, 약간 좌우로 흔들림)
                next_x = current_x + random.randint(-4, 4)
                next_y = current_y + random.randint(3, 6)
                
                # 벽돌 경계 내에 유지
                next_x = max(wall_rect.left + 2, min(wall_rect.right - 2, next_x))
                next_y = min(wall_rect.bottom - 2, next_y)
                
                crack_points.append((next_x, next_y))
                current_x, current_y = next_x, next_y
            
            # 균열 선 그리기
            for i in range(len(crack_points) - 1):
                draw.line(self.screen, crack_color, crack_points[i], crack_points[i + 1], 1)
            
            # 가지 균열들 (메인 균열에서 뻗어나오는 작은 가지들)
            for i in range(1, len(crack_points) - 1):
                main_point = crack_points[i]
                # 좌우로 작은 가지들
                for side in [-1, 1]:
                    if random.random() < 0.6:  # 60% 확률로 가지 생성
                        branch_end_x = main_point[0] + side * random.randint(3, 8)
                        branch_end_y = main_point[1] + random.randint(-2, 2)
                        
                        # 경계 체크
                        branch_end_x = max(wall_rect.left + 1, min(wall_rect.right - 1, branch_end_x))
                        branch_end_y = max(wall_rect.top + 1, min(wall_rect.bottom - 1, branch_end_y))
                        
                        draw.line(self.screen, crack_color, main_point, (branch_end_x, branch_end_y), 1)
            
            # 추가 작은 균열 (독립적)
            if random.random() < 0.5:
                small_start_x = wall_rect.left + random.randint(5, wall_rect.width - 10)
                small_start_y = wall_rect.top + random.randint(5, wall_rect.height - 10)
                small_end_x = small_start_x + random.randint(-6, 6)
                small_end_y = small_start_y + random.randint(-3, 6)
                
                # 경계 내 유지
                small_end_x = max(wall_rect.left + 1, min(wall_rect.right - 1, small_end_x))
                small_end_y = max(wall_rect.top + 1, min(wall_rect.bottom - 1, small_end_y))
                
                draw.line(self.screen, crack_color, (small_start_x, small_start_y), (small_end_x, small_end_y), 1)
        
        elif wall_crack_level == 2:
            # 2단계: 심각한 균열 - 복잡한 네트워크 형태
            random.seed(wall_rect.x + wall_rect.y + 1000)  # 다른 시드 사용
            
            # 메인 균열 네트워크 - 여러 방향에서 시작
            crack_origins = [
                (wall_rect.left + random.randint(2, 8), wall_rect.top + random.randint(2, 5)),
                (wall_rect.right - random.randint(2, 8), wall_rect.top + random.randint(2, 5)),
                (wall_rect.centerx + random.randint(-5, 5), wall_rect.centery + random.randint(-3, 3))
            ]
            
            all_crack_points = []
            
            for origin in crack_origins:
                current_x, current_y = origin
                crack_network = [origin]
                
                # 각 기점에서 불규칙하게 뻗어나가는 균열들
                directions = [
                    (random.randint(-2, 2), random.randint(2, 5)),  # 주로 아래쪽
                    (random.randint(2, 5), random.randint(-1, 3)),  # 오른쪽
                    (random.randint(-5, -2), random.randint(-1, 3)), # 왼쪽
                    (random.randint(-1, 1), random.randint(-3, -1))  # 위쪽
                ]
                
                for dx, dy in directions[:random.randint(2, 4)]:  # 2-4개의 방향으로 균열
                    branch_points = [origin]
                    curr_x, curr_y = origin
                    
                    for step in range(random.randint(2, 4)):
                        # 방향을 유지하되 약간의 랜덤성 추가
                        next_x = curr_x + dx + random.randint(-2, 2)
                        next_y = curr_y + dy + random.randint(-2, 2)
                        
                        # 경계 내 유지
                        next_x = max(wall_rect.left + 1, min(wall_rect.right - 1, next_x))
                        next_y = max(wall_rect.top + 1, min(wall_rect.bottom - 1, next_y))
                        
                        branch_points.append((next_x, next_y))
                        curr_x, curr_y = next_x, next_y
                        
                        # 방향을 점진적으로 변경 (자연스러운 곡선)
                        dx += random.randint(-1, 1)
                        dy += random.randint(-1, 1)
                    
                    crack_network.extend(branch_points)
                    
                    # 브랜치 선들 그리기
                    for i in range(len(branch_points) - 1):
                        draw.line(self.screen, crack_color, branch_points[i], branch_points[i + 1], 2)
                
                all_crack_points.extend(crack_network)
            
            # 균열들을 연결하는 추가 선들 (네트워크 형성)
            if len(all_crack_points) > 6:
                for _ in range(random.randint(2, 4)):
                    point1 = random.choice(all_crack_points)
                    point2 = random.choice(all_crack_points)
                    
                    # 너무 멀리 떨어진 점들은 연결하지 않음
                    distance = ((point1[0] - point2[0])**2 + (point1[1] - point2[1])**2)**0.5
                    if distance > 5 and distance < 20:
                        draw.line(self.screen, crack_color, point1, point2, 1)
            
            # 가장자리에서 내부로 뻗어나오는 짧은 균열들
            edge_cracks = [
                (wall_rect.left, wall_rect.centery + random.randint(-5, 5)),
                (wall_rect.right, wall_rect.centery + random.randint(-5, 5)),
                (wall_rect.centerx + random.randint(-8, 8), wall_rect.top),
                (wall_rect.centerx + random.randint(-8, 8), wall_rect.bottom)
            ]
            
            for edge_point in edge_cracks:
                if random.random() < 0.7:  # 70% 확률
                    # 가장자리에서 내부로 향하는 짧은 균열
                    target_x = edge_point[0] + random.randint(-8, 8)
                    target_y = edge_point[1] + random.randint(-4, 4)
                    
                    # 내부 방향으로 조정
                    if edge_point[0] == wall_rect.left:
                        target_x = edge_point[0] + random.randint(3, 10)
                    elif edge_point[0] == wall_rect.right:
                        target_x = edge_point[0] - random.randint(3, 10)
                    
                    if edge_point[1] == wall_rect.top:
                        target_y = edge_point[1] + random.randint(3, 8)
                    elif edge_point[1] == wall_rect.bottom:
                        target_y = edge_point[1] - random.randint(3, 8)
                    
                    # 경계 내 유지
                    target_x = max(wall_rect.left + 1, min(wall_rect.right - 1, target_x))
                    target_y = max(wall_rect.top + 1, min(wall_rect.bottom - 1, target_y))
                    
                    draw.line(self.screen, crack_color, edge_point, (target_x, target_y), 1)
        
        # 시드 리셋
        random.seed()
    
    def draw_ui(self):
        """UI 정보 표시"""
        # 제목
        title_text = self.font.render("자연스러운 벽돌 균열 패턴 테스트", True, WHITE)
        self.screen.blit(title_text, (WIDTH//2 - title_text.get_width()//2, 20))
        
        # 범례
        legend_y = 50
        legend_texts = [
            "균열 레벨 0: 정상 벽돌",
            "균열 레벨 1: 브랜칭 균열 (어두운 갈색)",
            "균열 레벨 2: 네트워크 균열 (빨간색)"
        ]
        
        for text in legend_texts:
            legend_surface = self.small_font.render(text, True, WHITE)
            self.screen.blit(legend_surface, (WIDTH//2 - legend_surface.get_width()//2, legend_y))
            legend_y += 25
        
        # 조작법
        controls = [
            "스페이스바: 모든 벽돌 균열 레벨 변경",
            "마우스 클릭: 새로운 벽돌 추가",
            "ESC: 종료"
        ]
        
        control_y = HEIGHT - 80
        for control in controls:
            control_surface = self.small_font.render(control, True, (200, 200, 200))
            self.screen.blit(control_surface, (10, control_y))
            control_y += 20
        
        # 벽돌 개수 표시
        brick_text = self.small_font.render(f"벽돌 개수: {len(self.walls)}", True, WHITE)
        self.screen.blit(brick_text, (WIDTH - 150, HEIGHT - 30))
    
    def handle_events(self):
        """이벤트 처리"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    self.running = False
                elif event.key == pygame.K_SPACE:
                    # 모든 벽돌의 균열 레벨 변경 (0 → 1 → 2 → 0)
                    for wall in self.walls:
                        wall["crack_level"] = (wall["crack_level"] + 1) % 3
                    print(f"균열 레벨 변경됨")
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:  # 왼쪽 클릭
                    # 마우스 위치에 새로운 벽돌 추가
                    mouse_x, mouse_y = pygame.mouse.get_pos()
                    wall = {
                        "rect": pygame.Rect(mouse_x - 40, mouse_y - 15, 80, 30),
                        "crack_level": random.randint(0, 2)
                    }
                    self.walls.append(wall)
                    print(f"벽돌 추가: ({mouse_x}, {mouse_y}) - 균열 레벨 {wall['crack_level']}")
    
    def run(self):
        """메인 게임 루프"""
        print("=" * 60)
        print("자연스러운 벽돌 균열 패턴 테스트")
        print("=" * 60)
        print("새로운 균열 시스템:")
        print("- 레벨 1: 브랜칭 균열 (가지형태)")
        print("- 레벨 2: 복잡한 네트워크 균열")
        print("=" * 60)
        print("\n조작법:")
        print("스페이스바: 균열 레벨 변경")
        print("마우스 클릭: 새로운 벽돌 추가")
        print("ESC: 종료")
        print("=" * 60)
        
        while self.running:
            self.handle_events()
            
            # 그리기
            self.screen.fill(BLACK)
            
            # 벽돌들 그리기
            for wall in self.walls:
                self.draw_brick_with_natural_cracks(wall["rect"], wall["crack_level"])
            
            # UI 그리기
            self.draw_ui()
            
            pygame.display.flip()
            self.clock.tick(FPS)
        
        pygame.quit()
        print("\n테스트 종료")

if __name__ == "__main__":
    test = NaturalCracksTest()
    test.run()