#!/usr/bin/env python3
"""
벽돌 충돌 버그 수정 테스트
벽돌이 공을 제대로 반사시키는지 확인
"""

import pygame
import sys
import os

# 게임 설정
WIDTH = 800
HEIGHT = 600
FPS = 60

# 색상
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
GRAY = (128, 128, 128)
YELLOW = (255, 255, 0)

class WallCollisionTest:
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((WIDTH, HEIGHT))
        pygame.display.set_caption("벽돌 충돌 테스트")
        self.clock = pygame.time.Clock()
        self.font = pygame.font.Font(None, 36)
        
        # 공 설정
        self.ball = pygame.Rect(WIDTH // 2 - 10, HEIGHT // 4, 20, 20)
        self.ball_vel = [0, 5]  # 아래로 떨어지는 공
        
        # 벽돌 설정 (플레이어 패들 위치 근처)
        self.wall = {
            "rect": pygame.Rect(WIDTH // 2 - 40, HEIGHT * 0.7, 80, 20),
            "hit_count": 0,
            "crack_level": 0
        }
        
        # 플레이어 패들
        self.player = pygame.Rect(WIDTH // 2 - 50, HEIGHT - 100, 100, 20)
        
        # 상태
        self.collision_count = 0
        self.pass_through = False
        self.test_result = "테스트 진행 중..."
        
    def handle_collision(self):
        """개선된 벽돌 충돌 처리"""
        if self.ball.colliderect(self.wall["rect"]):
            self.collision_count += 1
            self.wall["hit_count"] += 1
            self.wall["crack_level"] = self.wall["hit_count"]
            
            # 충돌 방향 결정 및 위치 조정
            ball_center_x = self.ball.centerx
            ball_center_y = self.ball.centery
            wall_center_x = self.wall["rect"].centerx
            wall_center_y = self.wall["rect"].centery
            
            dx = ball_center_x - wall_center_x
            dy = ball_center_y - wall_center_y
            
            # 충돌 방향에 따른 반사 및 위치 조정
            if abs(dy) > abs(dx):
                self.ball_vel[1] = -self.ball_vel[1]  # Y 방향 반사
                # 공을 벽돌 밖으로 밀어냄
                if dy > 0:  # 공이 벽돌 아래에서 충돌
                    self.ball.bottom = self.wall["rect"].top - 1
                else:  # 공이 벽돌 위에서 충돌
                    self.ball.top = self.wall["rect"].bottom + 1
            else:
                self.ball_vel[0] = -self.ball_vel[0]  # X 방향 반사
                # 공을 벽돌 밖으로 밀어냄
                if dx > 0:  # 공이 벽돌 오른쪽에서 충돌
                    self.ball.left = self.wall["rect"].right + 1
                else:  # 공이 벽돌 왼쪽에서 충돌
                    self.ball.right = self.wall["rect"].left - 1
            
            # 속도 감쇠
            self.ball_vel[0] *= 0.9
            self.ball_vel[1] *= 0.9
            
            print(f"충돌! 벽돌 타격 횟수: {self.wall['hit_count']}, 공 속도: {self.ball_vel}")
    
    def update(self):
        # 공 이동
        self.ball.x += self.ball_vel[0]
        self.ball.y += self.ball_vel[1]
        
        # 충돌 처리
        self.handle_collision()
        
        # 벽면 충돌
        if self.ball.left <= 0 or self.ball.right >= WIDTH:
            self.ball_vel[0] = -self.ball_vel[0]
        if self.ball.top <= 0:
            self.ball_vel[1] = -self.ball_vel[1]
        
        # 공이 화면 아래로 떨어진 경우
        if self.ball.top > HEIGHT:
            if self.collision_count > 0:
                self.test_result = "❌ 실패: 공이 벽돌을 뚫고 지나감!"
                self.pass_through = True
            else:
                self.test_result = "테스트 미완료: 충돌 없이 떨어짐"
            
        # 공이 위로 올라간 경우 (성공적으로 반사됨)
        if self.ball_vel[1] < 0 and self.collision_count > 0:
            self.test_result = "✅ 성공: 공이 올바르게 반사됨!"
            
        # 벽돌이 2번 맞으면 파괴
        if self.wall["hit_count"] >= 2:
            self.wall["rect"] = pygame.Rect(0, 0, 0, 0)  # 벽돌 제거
    
    def draw(self):
        self.screen.fill(BLACK)
        
        # 벽돌 그리기
        if self.wall["hit_count"] < 2:
            if self.wall["crack_level"] == 0:
                color = GREEN
            elif self.wall["crack_level"] == 1:
                color = YELLOW
            else:
                color = RED
            pygame.draw.rect(self.screen, color, self.wall["rect"])
            pygame.draw.rect(self.screen, WHITE, self.wall["rect"], 2)
        
        # 공 그리기
        pygame.draw.circle(self.screen, WHITE, self.ball.center, 10)
        
        # 플레이어 패들 그리기
        pygame.draw.rect(self.screen, BLUE, self.player)
        
        # 정보 표시
        info_texts = [
            f"충돌 횟수: {self.collision_count}",
            f"공 속도: ({self.ball_vel[0]:.1f}, {self.ball_vel[1]:.1f})",
            f"벽돌 타격: {self.wall['hit_count']}/2",
            f"결과: {self.test_result}"
        ]
        
        y = 10
        for text in info_texts:
            surf = self.font.render(text, True, WHITE)
            self.screen.blit(surf, (10, y))
            y += 40
        
        # 도움말
        help_text = "ESC: 종료, R: 리셋"
        help_surf = self.font.render(help_text, True, GRAY)
        self.screen.blit(help_surf, (WIDTH - 200, HEIGHT - 30))
        
        pygame.display.flip()
    
    def reset(self):
        """테스트 리셋"""
        self.ball = pygame.Rect(WIDTH // 2 - 10, HEIGHT // 4, 20, 20)
        self.ball_vel = [0, 5]
        self.wall["hit_count"] = 0
        self.wall["crack_level"] = 0
        self.wall["rect"] = pygame.Rect(WIDTH // 2 - 40, HEIGHT * 0.7, 80, 20)
        self.collision_count = 0
        self.pass_through = False
        self.test_result = "테스트 진행 중..."
    
    def run(self):
        running = True
        while running:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    running = False
                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        running = False
                    elif event.key == pygame.K_r:
                        self.reset()
            
            self.update()
            self.draw()
            self.clock.tick(FPS)
        
        pygame.quit()

if __name__ == "__main__":
    test = WallCollisionTest()
    test.run()