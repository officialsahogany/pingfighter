#!/usr/bin/env python3
"""
Stage 2 정글지진 벽돌 렌더링 버그 수정 테스트

버그: Stage 2에서 벽돌아이템을 플레이어가 사용해서 필드에 설치한 뒤에 
보스가 정글지진을 발동시 벽돌이 지진동안 안보이는 버그

수정 내용:
1. earthquake_offset_x, earthquake_offset_y 전역 변수 추가
2. draw_field()에서 Stage 2일 때 earthquake offset 설정
3. draw_objects()에서 벽돌 그릴 때 earthquake offset 적용
4. 다른 스테이지에서는 earthquake offset을 0으로 초기화

테스트 방법:
1. Stage 2 시작
2. 벽돌 아이템 획득 및 사용
3. 보스가 정글지진 발동할 때까지 대기
4. 지진 중에도 벽돌이 화면과 함께 흔들리며 계속 보이는지 확인
"""

import pygame
import sys
import os
import math
import random

# 게임 디렉토리를 Python 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 상수 정의
WIDTH = 600
HEIGHT = 750
FPS = 60

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
BROWN = (139, 69, 19)
GREEN = (0, 255, 0)
RED = (255, 0, 0)

class EarthquakeBrickTest:
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((WIDTH, HEIGHT))
        pygame.display.set_caption("Stage 2 정글지진 벽돌 렌더링 테스트")
        self.clock = pygame.time.Clock()
        self.running = True
        
        # 테스트 상태
        self.earthquake_active = False
        self.earthquake_timer = 0
        self.earthquake_duration = 80  # 정글지진 지속시간
        self.earthquake_offset_x = 0
        self.earthquake_offset_y = 0
        
        # 벽돌 시스템
        self.walls = []
        self.add_test_bricks()
        
        # 폰트
        self.font = pygame.font.Font(None, 36)
        self.small_font = pygame.font.Font(None, 24)
        
    def add_test_bricks(self):
        """테스트용 벽돌 추가"""
        # 3개의 벽돌을 필드에 배치
        positions = [
            (200, 400),
            (300, 450),
            (400, 400)
        ]
        
        for x, y in positions:
            wall = {
                "rect": pygame.Rect(x, y, 60, 20),
                "crack_level": random.randint(0, 2)
            }
            self.walls.append(wall)
            
    def get_earthquake_offset(self):
        """지진 효과를 위한 화면 흔들림 오프셋 계산"""
        if not self.earthquake_active:
            return (0, 0)
        
        # 지진 강도 (시간에 따라 감소)
        progress = self.earthquake_timer / self.earthquake_duration
        intensity = 8 * (1 - progress)  # 8픽셀에서 시작해서 점차 감소
        
        # 랜덤한 방향으로 흔들림
        offset_x = (random.random() - 0.5) * intensity * 2
        offset_y = (random.random() - 0.5) * intensity * 2
        
        return (int(offset_x), int(offset_y))
    
    def trigger_earthquake(self):
        """정글지진 발동"""
        self.earthquake_active = True
        self.earthquake_timer = 0
        print("🌋 정글지진 발동!")
        
    def update(self):
        """게임 상태 업데이트"""
        # 지진 효과 업데이트
        if self.earthquake_active:
            self.earthquake_timer += 1
            if self.earthquake_timer >= self.earthquake_duration:
                self.earthquake_active = False
                self.earthquake_timer = 0
                print("🌋 정글지진 종료")
        
        # 지진 오프셋 계산
        self.earthquake_offset_x, self.earthquake_offset_y = self.get_earthquake_offset()
        
    def draw_background(self):
        """배경 그리기 (지진 효과 포함)"""
        # 정글 배경색
        jungle_color = (34, 139, 34)  # Forest Green
        
        if self.earthquake_active:
            # 지진 중일 때 배경을 임시 Surface에 그리고 오프셋 적용
            temp_surface = pygame.Surface((WIDTH, HEIGHT))
            temp_surface.fill(jungle_color)
            
            # 정글 나무 표현 (간단한 원들)
            for i in range(10):
                x = 60 * i + 30
                y = 100 + random.randint(-10, 10)
                pygame.draw.circle(temp_surface, (0, 100, 0), (x, y), 30)
            
            # 오프셋 적용하여 화면에 그리기
            self.screen.fill(BLACK)
            self.screen.blit(temp_surface, (self.earthquake_offset_x, self.earthquake_offset_y))
        else:
            # 지진이 없을 때 일반 배경
            self.screen.fill(jungle_color)
            
            # 정글 나무 표현 (간단한 원들)
            for i in range(10):
                x = 60 * i + 30
                y = 100
                pygame.draw.circle(self.screen, (0, 100, 0), (x, y), 30)
    
    def draw_bricks(self):
        """벽돌 그리기 (수정된 로직 적용)"""
        for wall in self.walls:
            wall_rect = wall["rect"].copy()  # 원본 rect 복사
            wall_crack_level = wall["crack_level"]
            
            # 🌋 Stage 2 정글지진 오프셋 적용 (배경과 동기화)
            # 이것이 핵심 수정 부분!
            wall_rect.x += self.earthquake_offset_x
            wall_rect.y += self.earthquake_offset_y
            
            # 벽돌 색상 (균열 레벨에 따라)
            if wall_crack_level == 0:
                wall_color = BROWN
            elif wall_crack_level == 1:
                wall_color = (160, 82, 45)  # 밝은 갈색
            else:
                wall_color = (184, 134, 11)  # 더 밝은 갈색
            
            # 벽돌 그리기
            pygame.draw.rect(self.screen, wall_color, wall_rect)
            pygame.draw.rect(self.screen, WHITE, wall_rect, 2)  # 흰색 테두리
            
            # 균열 그리기
            if wall_crack_level > 0:
                crack_color = RED if wall_crack_level >= 2 else (255, 255, 0)
                for i in range(wall_crack_level * 2):
                    start_x = wall_rect.x + random.randint(5, wall_rect.width - 5)
                    start_y = wall_rect.y + random.randint(5, wall_rect.height - 5)
                    crack_length = random.randint(5, 10)
                    angle = random.uniform(0, 2 * math.pi)
                    end_x = start_x + int(math.cos(angle) * crack_length)
                    end_y = start_y + int(math.sin(angle) * crack_length)
                    pygame.draw.line(self.screen, crack_color, (start_x, start_y), (end_x, end_y), 1)
    
    def draw_ui(self):
        """UI 정보 표시"""
        # 상태 표시
        if self.earthquake_active:
            status_text = self.font.render("🌋 정글지진 발동중!", True, RED)
            progress = self.earthquake_timer / self.earthquake_duration
            progress_text = self.small_font.render(f"진행도: {progress*100:.0f}%", True, WHITE)
            offset_text = self.small_font.render(
                f"오프셋: ({self.earthquake_offset_x}, {self.earthquake_offset_y})", 
                True, WHITE
            )
        else:
            status_text = self.font.render("지진 대기중...", True, WHITE)
            progress_text = self.small_font.render("SPACE키로 지진 발동", True, GREEN)
            offset_text = self.small_font.render("오프셋: (0, 0)", True, WHITE)
        
        # 텍스트 표시
        self.screen.blit(status_text, (WIDTH//2 - status_text.get_width()//2, 20))
        self.screen.blit(progress_text, (WIDTH//2 - progress_text.get_width()//2, 60))
        self.screen.blit(offset_text, (WIDTH//2 - offset_text.get_width()//2, 85))
        
        # 벽돌 개수 표시
        brick_text = self.small_font.render(f"벽돌 개수: {len(self.walls)}", True, WHITE)
        self.screen.blit(brick_text, (10, HEIGHT - 30))
        
        # 수정 설명
        fix_text = self.small_font.render("수정: 벽돌이 지진 오프셋과 동기화됨", True, GREEN)
        self.screen.blit(fix_text, (WIDTH//2 - fix_text.get_width()//2, HEIGHT - 60))
        
        # 조작법
        controls = [
            "SPACE: 정글지진 발동",
            "B: 벽돌 추가",
            "C: 벽돌 제거",
            "ESC: 종료"
        ]
        y = HEIGHT - 150
        for control in controls:
            text = self.small_font.render(control, True, (200, 200, 200))
            self.screen.blit(text, (10, y))
            y += 25
    
    def handle_events(self):
        """이벤트 처리"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    self.running = False
                elif event.key == pygame.K_SPACE:
                    # 지진 발동
                    if not self.earthquake_active:
                        self.trigger_earthquake()
                elif event.key == pygame.K_b:
                    # 벽돌 추가
                    x = random.randint(100, WIDTH - 100)
                    y = random.randint(300, 500)
                    wall = {
                        "rect": pygame.Rect(x, y, 60, 20),
                        "crack_level": random.randint(0, 2)
                    }
                    self.walls.append(wall)
                    print(f"벽돌 추가: ({x}, {y})")
                elif event.key == pygame.K_c:
                    # 벽돌 제거
                    if self.walls:
                        self.walls.pop()
                        print("벽돌 제거됨")
    
    def run(self):
        """메인 게임 루프"""
        print("=" * 60)
        print("Stage 2 정글지진 벽돌 렌더링 버그 수정 테스트")
        print("=" * 60)
        print("수정 내용:")
        print("- earthquake_offset_x/y를 전역 변수로 추가")
        print("- draw_objects()에서 벽돌 그릴 때 earthquake offset 적용")
        print("- 배경과 벽돌이 동일한 오프셋으로 흔들림")
        print("=" * 60)
        print("\n조작법:")
        print("SPACE: 정글지진 발동")
        print("B: 벽돌 추가")
        print("C: 벽돌 제거")
        print("ESC: 종료")
        print("=" * 60)
        
        while self.running:
            self.handle_events()
            self.update()
            
            # 그리기
            self.draw_background()
            self.draw_bricks()
            self.draw_ui()
            
            pygame.display.flip()
            self.clock.tick(FPS)
        
        pygame.quit()
        print("\n테스트 종료")

if __name__ == "__main__":
    test = EarthquakeBrickTest()
    test.run()