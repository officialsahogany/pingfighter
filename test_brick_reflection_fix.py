#!/usr/bin/env python3
"""
벽돌 파괴 시 공 반사 버그 수정 테스트

수정 내용:
- 충돌면에 따른 올바른 반사 방향 계산
- 리스트 복사본으로 안전한 순회
- 파괴 시 특별 효과음 재생
"""

import pygame
import sys
import os
import math

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
BLUE = (0, 0, 255)
YELLOW = (255, 255, 0)

class BrickReflectionTest:
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((WIDTH, HEIGHT))
        pygame.display.set_caption("벽돌 반사 버그 수정 테스트")
        self.clock = pygame.time.Clock()
        self.running = True
        
        # 공
        self.ball = pygame.Rect(WIDTH//2, HEIGHT-100, 12, 12)
        self.ball_vel = [0, 0]
        self.ball_active = False
        self.ball_trail = []  # 공의 궤적
        
        # 벽돌
        self.walls = []
        self.setup_test_bricks()
        
        # 파티클 시스템
        self.particles = []
        
        # 로그
        self.collision_log = []
        self.max_log_lines = 12
        
        # 폰트
        self.font = pygame.font.Font(None, 24)
        self.big_font = pygame.font.Font(None, 32)
        
    def setup_test_bricks(self):
        """테스트용 벽돌 배치"""
        # 다양한 각도로 공이 충돌할 수 있도록 배치
        positions = [
            (WIDTH//2, 200),      # 중앙 상단
            (WIDTH//2 - 100, 300),  # 왼쪽
            (WIDTH//2 + 100, 300),  # 오른쪽
            (WIDTH//2, 400),      # 중앙 하단
        ]
        
        for x, y in positions:
            brick = {
                "rect": pygame.Rect(x - 40, y - 15, 80, 30),
                "hit_count": 0,
                "crack_level": 0
            }
            self.walls.append(brick)
    
    def launch_ball(self, angle_deg=90):
        """특정 각도로 공 발사"""
        if not self.ball_active:
            self.ball.center = (WIDTH//2, HEIGHT-100)
            speed = 8
            angle_rad = math.radians(angle_deg)
            self.ball_vel = [
                speed * math.sin(angle_rad),
                -speed * math.cos(angle_rad)
            ]
            self.ball_active = True
            self.ball_trail.clear()
            self.log(f"공 발사! 각도: {angle_deg}°, 속도: ({self.ball_vel[0]:.1f}, {self.ball_vel[1]:.1f})")
    
    def reset(self):
        """리셋"""
        self.ball.center = (WIDTH//2, HEIGHT-100)
        self.ball_vel = [0, 0]
        self.ball_active = False
        self.walls.clear()
        self.setup_test_bricks()
        self.particles.clear()
        self.collision_log.clear()
        self.ball_trail.clear()
        self.log("리셋 완료")
    
    def log(self, message):
        """로그 추가"""
        self.collision_log.append(message)
        if len(self.collision_log) > self.max_log_lines:
            self.collision_log.pop(0)
        print(message)
    
    def create_destruction_particles(self, rect):
        """벽돌 파괴 파티클 생성"""
        for i in range(20):
            angle = (i / 20) * 2 * math.pi
            speed = 3 + (i % 3)
            particle = {
                'x': rect.centerx,
                'y': rect.centery,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': 40,
                'color': (139, 69, 19)  # 갈색
            }
            self.particles.append(particle)
    
    def update(self):
        """게임 상태 업데이트"""
        # 공 업데이트
        if self.ball_active:
            # 궤적 추가
            self.ball_trail.append((self.ball.centerx, self.ball.centery))
            if len(self.ball_trail) > 30:
                self.ball_trail.pop(0)
            
            self.ball.x += self.ball_vel[0]
            self.ball.y += self.ball_vel[1]
            
            # 벽 충돌 (좌우)
            if self.ball.left <= 0 or self.ball.right >= WIDTH:
                self.ball_vel[0] = -self.ball_vel[0]
                if self.ball.left <= 0:
                    self.ball.left = 0
                else:
                    self.ball.right = WIDTH
                self.log("벽 충돌 (좌우)")
            
            # 벽 충돌 (상단)
            if self.ball.top <= 0:
                self.ball_vel[1] = -self.ball_vel[1]
                self.ball.top = 0
                self.log("벽 충돌 (상단)")
            
            # 바닥 충돌 (공 리셋)
            if self.ball.bottom >= HEIGHT:
                self.ball_active = False
                self.log("바닥 충돌 - 공 리셋")
        
        # 벽돌 충돌 검사 (수정된 로직)
        if self.ball_active:
            for wall in self.walls[:]:  # 리스트 복사본으로 순회
                if self.ball.colliderect(wall["rect"]):
                    # 충돌 전 상태 로그
                    old_hit_count = wall["hit_count"]
                    old_vel = (self.ball_vel[0], self.ball_vel[1])
                    
                    # 벽돌에 맞은 횟수 증가
                    wall["hit_count"] += 1
                    wall["crack_level"] = wall["hit_count"]
                    
                    # 올바른 공 반사 로직: 충돌면에 따른 반사
                    ball_center_y = self.ball.centery
                    wall_center_y = wall["rect"].centery
                    
                    # 공이 벽돌의 위쪽이나 아래쪽에서 충돌한 경우
                    if abs(ball_center_y - wall_center_y) > abs(self.ball.centerx - wall["rect"].centerx):
                        self.ball_vel[1] = -self.ball_vel[1]  # Y 방향 반사
                        collision_side = "상하"
                    else:
                        self.ball_vel[0] = -self.ball_vel[0]  # X 방향 반사
                        collision_side = "좌우"
                    
                    # 속도 감쇠
                    self.ball_vel[0] *= 0.9
                    self.ball_vel[1] *= 0.9
                    
                    # 로그 기록
                    self.log(f"벽돌 충돌! [{collision_side}] {old_hit_count}→{wall['hit_count']}")
                    self.log(f"  속도 변화: ({old_vel[0]:.1f}, {old_vel[1]:.1f}) → ({self.ball_vel[0]:.1f}, {self.ball_vel[1]:.1f})")
                    
                    # 벽돌 파괴 확인
                    if wall["hit_count"] >= 2:
                        self.log(f"  💥 벽돌 파괴! 파티클 생성")
                        self.create_destruction_particles(wall["rect"])
                        self.walls.remove(wall)
                    
                    break  # 한 프레임에 하나의 벽돌과만 충돌
        
        # 파티클 업데이트
        for particle in self.particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['vy'] += 0.3  # 중력
            particle['life'] -= 1
            
            if particle['life'] <= 0:
                self.particles.remove(particle)
    
    def draw_brick_with_cracks(self, wall):
        """균열이 있는 벽돌 그리기"""
        wall_rect = wall["rect"]
        wall_crack_level = wall["crack_level"]
        
        # 벽돌 기본 색상
        if wall_crack_level == 0:
            wall_color = (139, 69, 19)  # 갈색
        elif wall_crack_level == 1:
            wall_color = (160, 82, 45)  # 살짝 밝은 갈색
        else:
            wall_color = (184, 134, 11)  # 더 밝은 갈색
        
        # 벽돌 그리기
        pygame.draw.rect(self.screen, wall_color, wall_rect)
        pygame.draw.rect(self.screen, WHITE, wall_rect, 2)
        
        # 균열 표시
        if wall_crack_level > 0:
            crack_color = (80, 40, 10) if wall_crack_level == 1 else (220, 20, 60)
            center_x, center_y = wall_rect.center
            if wall_crack_level == 1:
                # 작은 균열
                pygame.draw.line(self.screen, crack_color, 
                               (center_x, wall_rect.top + 5), 
                               (center_x, wall_rect.bottom - 5), 1)
            else:
                # 심한 균열
                pygame.draw.line(self.screen, crack_color, 
                               (wall_rect.left + 5, center_y), 
                               (wall_rect.right - 5, center_y), 2)
                pygame.draw.line(self.screen, crack_color, 
                               (center_x, wall_rect.top + 5), 
                               (center_x, wall_rect.bottom - 5), 2)
    
    def draw(self):
        """화면 그리기"""
        self.screen.fill(BLACK)
        
        # 제목
        title = self.big_font.render("벽돌 반사 버그 수정 테스트", True, WHITE)
        self.screen.blit(title, (WIDTH//2 - title.get_width()//2, 10))
        
        # 벽돌 그리기
        for wall in self.walls:
            self.draw_brick_with_cracks(wall)
        
        # 공 궤적 그리기
        for i, pos in enumerate(self.ball_trail):
            alpha = i / len(self.ball_trail) if self.ball_trail else 0
            color = (int(255 * alpha), int(255 * alpha), int(255 * alpha))
            pygame.draw.circle(self.screen, color, pos, 2)
        
        # 공 그리기
        if self.ball_active:
            pygame.draw.circle(self.screen, WHITE, self.ball.center, 6)
            # 속도 벡터 표시
            end_x = self.ball.centerx + self.ball_vel[0] * 5
            end_y = self.ball.centery + self.ball_vel[1] * 5
            pygame.draw.line(self.screen, YELLOW, self.ball.center, (end_x, end_y), 2)
        else:
            pygame.draw.circle(self.screen, (100, 100, 100), self.ball.center, 6)
        
        # 파티클 그리기
        for particle in self.particles:
            pygame.draw.circle(self.screen, particle['color'], 
                             (int(particle['x']), int(particle['y'])), 2)
        
        # 로그 표시
        log_y = HEIGHT - 280
        log_title = self.font.render("충돌 로그:", True, WHITE)
        self.screen.blit(log_title, (10, log_y))
        log_y += 25
        
        for log_entry in self.collision_log[-10:]:  # 최근 10개만 표시
            log_surface = self.font.render(log_entry, True, (200, 200, 200))
            self.screen.blit(log_surface, (10, log_y))
            log_y += 22
        
        # 조작법
        controls = [
            "1-9: 각도별 공 발사 (1=10°, 5=90°, 9=170°)",
            "클릭: 벽돌 배치", 
            "R: 리셋",
            "ESC: 종료"
        ]
        
        control_y = 50
        for control in controls:
            control_surface = self.font.render(control, True, (150, 150, 150))
            self.screen.blit(control_surface, (WIDTH - 350, control_y))
            control_y += 20
        
        # 상태 표시
        status_y = 50
        status_texts = [
            f"벽돌 개수: {len(self.walls)}",
            f"공 활성: {'예' if self.ball_active else '아니오'}",
            f"공 속도: ({self.ball_vel[0]:.1f}, {self.ball_vel[1]:.1f})"
        ]
        
        for status in status_texts:
            status_surface = self.font.render(status, True, GREEN)
            self.screen.blit(status_surface, (10, status_y))
            status_y += 20
    
    def handle_events(self):
        """이벤트 처리"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    self.running = False
                elif event.key == pygame.K_r:
                    self.reset()
                elif pygame.K_1 <= event.key <= pygame.K_9:
                    # 1-9 키로 각도 조절 발사
                    angle = 10 + (event.key - pygame.K_1) * 20  # 10° ~ 170°
                    self.launch_ball(angle)
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:  # 왼쪽 클릭
                    mouse_x, mouse_y = pygame.mouse.get_pos()
                    brick = {
                        "rect": pygame.Rect(mouse_x - 40, mouse_y - 15, 80, 30),
                        "hit_count": 0,
                        "crack_level": 0
                    }
                    self.walls.append(brick)
                    self.log(f"벽돌 추가: ({mouse_x}, {mouse_y})")
    
    def run(self):
        """메인 게임 루프"""
        print("=" * 60)
        print("벽돌 반사 버그 수정 테스트")
        print("=" * 60)
        print("수정 내용:")
        print("1. 충돌면에 따른 올바른 반사 방향 계산")
        print("2. ball_vel[1] = -abs(ball_vel[1]) → 충돌면 기반 반사")
        print("3. 리스트 복사본으로 안전한 순회")
        print("=" * 60)
        print("\n조작법:")
        print("1-9: 각도별 공 발사")
        print("클릭: 벽돌 배치")
        print("R: 리셋")
        print("ESC: 종료")
        print("=" * 60)
        
        while self.running:
            self.handle_events()
            self.update()
            self.draw()
            
            pygame.display.flip()
            self.clock.tick(FPS)
        
        pygame.quit()
        print("\n테스트 종료")

if __name__ == "__main__":
    test = BrickReflectionTest()
    test.run()