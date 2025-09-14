#!/usr/bin/env python3
"""
벽돌 마지막 타격 시 공 반사 버그 테스트

버그 현상: 벽돌이 깨질 때 (2번째 타격) 공을 반사하지 않는 문제

테스트 시나리오:
1. 벽돌 하나를 배치
2. 공을 벽돌에 향해 발사
3. 첫 번째 충돌: hit_count 0→1, 균열 생성, 공 반사 확인
4. 두 번째 충돌: hit_count 1→2, 벽돌 파괴, 공 반사 확인 ← 이 부분이 문제

테스트 방법:
- 스페이스바: 공 발사
- 클릭: 벽돌 배치
- R: 리셋
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

class BrickFinalHitTest:
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((WIDTH, HEIGHT))
        pygame.display.set_caption("벽돌 마지막 타격 반사 버그 테스트")
        self.clock = pygame.time.Clock()
        self.running = True
        
        # 공
        self.ball = pygame.Rect(WIDTH//2, HEIGHT-100, 12, 12)
        self.ball_vel = [0, 0]
        self.ball_active = False
        
        # 벽돌
        self.walls = []
        
        # 파티클 시스템
        self.particles = []
        
        # 로그
        self.collision_log = []
        self.max_log_lines = 10
        
        # 폰트
        self.font = pygame.font.Font(None, 24)
        self.big_font = pygame.font.Font(None, 32)
        
    def add_brick(self, x, y):
        """벽돌 추가"""
        brick = {
            "rect": pygame.Rect(x - 40, y - 15, 80, 30),
            "hit_count": 0,
            "crack_level": 0
        }
        self.walls.append(brick)
        self.log(f"벽돌 추가: ({x}, {y})")
    
    def launch_ball(self):
        """공 발사"""
        if not self.ball_active:
            self.ball.center = (WIDTH//2, HEIGHT-100)
            self.ball_vel = [0, -8]  # 위로 발사
            self.ball_active = True
            self.log("공 발사!")
    
    def reset(self):
        """리셋"""
        self.ball.center = (WIDTH//2, HEIGHT-100)
        self.ball_vel = [0, 0]
        self.ball_active = False
        self.walls.clear()
        self.particles.clear()
        self.collision_log.clear()
        self.log("리셋 완료")
    
    def log(self, message):
        """로그 추가"""
        self.collision_log.append(message)
        if len(self.collision_log) > self.max_log_lines:
            self.collision_log.pop(0)
        print(message)
    
    def create_destruction_particles(self, rect):
        """벽돌 파괴 파티클 생성"""
        for _ in range(15):
            particle = {
                'x': rect.centerx + pygame.math.Vector2(0, 0).x,
                'y': rect.centery + pygame.math.Vector2(0, 0).y,
                'vx': (pygame.math.Vector2(1, 0).rotate(pygame.math.Vector2(0, 0).angle_to(pygame.math.Vector2(1, 1)) * 360 / (2 * 3.14159) * _).x) * 3,
                'vy': (pygame.math.Vector2(1, 0).rotate(pygame.math.Vector2(0, 0).angle_to(pygame.math.Vector2(1, 1)) * 360 / (2 * 3.14159) * _).y) * 3,
                'life': 30,
                'color': (139, 69, 19)  # 갈색
            }
            self.particles.append(particle)
    
    def update(self):
        """게임 상태 업데이트"""
        # 공 업데이트
        if self.ball_active:
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
        
        # 벽돌 충돌 검사
        if self.ball_active:
            for wall in self.walls[:]:  # 리스트 복사본으로 순회
                if self.ball.colliderect(wall["rect"]):
                    # 충돌 전 상태 로그
                    old_hit_count = wall["hit_count"]
                    
                    # 벽돌에 맞은 횟수 증가
                    wall["hit_count"] += 1
                    wall["crack_level"] = wall["hit_count"]
                    
                    # 공 반사 로직 (pingfighter.py와 동일)
                    self.ball_vel[1] = -abs(self.ball_vel[1])  # 위로 튕기기
                    self.ball_vel[0] *= 0.8  # 좌우 속도 감소
                    
                    # 로그 기록
                    self.log(f"벽돌 충돌! {old_hit_count}→{wall['hit_count']}, 공속도: ({self.ball_vel[0]:.1f}, {self.ball_vel[1]:.1f})")
                    
                    # 벽돌 파괴 확인
                    if wall["hit_count"] >= 2:
                        self.log(f"벽돌 파괴! 파티클 생성")
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
            wall_color = (160, 82, 45)  # 살짝 밝은 갈색 (손상 표시)
        else:
            wall_color = (184, 134, 11)  # 더 밝은 갈색 (심각한 손상)
        
        # 벽돌 그리기
        pygame.draw.rect(self.screen, wall_color, wall_rect)
        
        # 3D 효과
        highlight_color = (min(255, wall_color[0] + 40), min(255, wall_color[1] + 40), min(255, wall_color[2] + 40))
        shadow_color = (max(0, wall_color[0] - 40), max(0, wall_color[1] - 40), max(0, wall_color[2] - 40))
        
        # 하이라이트 (위쪽, 왼쪽)
        pygame.draw.line(self.screen, highlight_color, wall_rect.topleft, wall_rect.topright, 2)
        pygame.draw.line(self.screen, highlight_color, wall_rect.topleft, wall_rect.bottomleft, 2)
        
        # 그림자 (아래쪽, 오른쪽)
        pygame.draw.line(self.screen, shadow_color, wall_rect.bottomleft, wall_rect.bottomright, 2)
        pygame.draw.line(self.screen, shadow_color, wall_rect.topright, wall_rect.bottomright, 2)
        
        # 균열 표시
        if wall_crack_level > 0:
            crack_color = (80, 40, 10) if wall_crack_level == 1 else (220, 20, 60)
            # 간단한 균열 표시
            center_x, center_y = wall_rect.center
            if wall_crack_level == 1:
                pygame.draw.line(self.screen, crack_color, (center_x, wall_rect.top + 5), (center_x, wall_rect.bottom - 5), 1)
            else:
                pygame.draw.line(self.screen, crack_color, (wall_rect.left + 5, center_y), (wall_rect.right - 5, center_y), 2)
                pygame.draw.line(self.screen, crack_color, (center_x, wall_rect.top + 5), (center_x, wall_rect.bottom - 5), 2)
    
    def draw(self):
        """화면 그리기"""
        self.screen.fill(BLACK)
        
        # 제목
        title = self.big_font.render("벽돌 마지막 타격 반사 테스트", True, WHITE)
        self.screen.blit(title, (WIDTH//2 - title.get_width()//2, 10))
        
        # 벽돌 그리기
        for wall in self.walls:
            self.draw_brick_with_cracks(wall)
        
        # 공 그리기
        if self.ball_active:
            pygame.draw.circle(self.screen, WHITE, self.ball.center, 6)
            # 공 속도 표시
            speed_text = f"속도: ({self.ball_vel[0]:.1f}, {self.ball_vel[1]:.1f})"
            speed_surface = self.font.render(speed_text, True, GREEN)
            self.screen.blit(speed_surface, (self.ball.centerx - speed_surface.get_width()//2, self.ball.centery - 30))
        else:
            pygame.draw.circle(self.screen, (100, 100, 100), self.ball.center, 6)
        
        # 파티클 그리기
        for particle in self.particles:
            pygame.draw.circle(self.screen, particle['color'], (int(particle['x']), int(particle['y'])), 2)
        
        # 로그 표시
        log_y = HEIGHT - 220
        log_title = self.font.render("충돌 로그:", True, WHITE)
        self.screen.blit(log_title, (10, log_y))
        log_y += 25
        
        for log_entry in self.collision_log[-8:]:  # 최근 8개만 표시
            log_surface = self.font.render(log_entry, True, (200, 200, 200))
            self.screen.blit(log_surface, (10, log_y))
            log_y += 20
        
        # 조작법
        controls = [
            "스페이스: 공 발사",
            "클릭: 벽돌 배치", 
            "R: 리셋",
            "ESC: 종료"
        ]
        
        control_y = 50
        for control in controls:
            control_surface = self.font.render(control, True, (150, 150, 150))
            self.screen.blit(control_surface, (10, control_y))
            control_y += 20
        
        # 상태 표시
        status_y = 170
        status_texts = [
            f"벽돌 개수: {len(self.walls)}",
            f"공 활성: {'예' if self.ball_active else '아니오'}",
            f"파티클 개수: {len(self.particles)}"
        ]
        
        for status in status_texts:
            status_surface = self.font.render(status, True, BLUE)
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
                elif event.key == pygame.K_SPACE:
                    self.launch_ball()
                elif event.key == pygame.K_r:
                    self.reset()
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:  # 왼쪽 클릭
                    mouse_x, mouse_y = pygame.mouse.get_pos()
                    self.add_brick(mouse_x, mouse_y)
    
    def run(self):
        """메인 게임 루프"""
        print("=" * 60)
        print("벽돌 마지막 타격 반사 버그 테스트")
        print("=" * 60)
        print("테스트 시나리오:")
        print("1. 클릭으로 벽돌 배치")
        print("2. 스페이스로 공 발사")
        print("3. 첫 번째 충돌 시 반사 확인")
        print("4. 두 번째 충돌 시 반사 및 파괴 확인 ← 버그 지점")
        print("=" * 60)
        print("\n조작법:")
        print("스페이스: 공 발사")
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
    test = BrickFinalHitTest()
    test.run()