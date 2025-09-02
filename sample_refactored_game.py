#!/usr/bin/env python3
"""
리팩토링된 모듈을 사용한 간단한 Pong 게임 샘플
모듈화된 코드의 실제 사용 예시
"""
import pygame
import sys
import math
import random

# 리팩토링된 모듈 임포트
from utils.color_utils import *
from utils.math_utils import *
from utils.draw_utils import DrawHelper, draw_gradient_rect, draw_glow_effect
from utils.particle_utils import *
from utils.game_constants import *
from config.constants import WIDTH, HEIGHT, PADDLE_WIDTH, PADDLE_HEIGHT, BALL_RADIUS

class Ball:
    """공 클래스"""
    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.vx = random.choice([-5, 5])
        self.vy = random.choice([-5, 5])
        self.radius = BALL_RADIUS
        self.color = WHITE
        self.trail_particles = []
        
    def update(self):
        """공 위치 업데이트"""
        self.x += self.vx
        self.y += self.vy
        
        # 벽 충돌
        if self.x <= self.radius or self.x >= WIDTH - self.radius:
            self.vx *= -1
            self.x = clamp(self.x, self.radius, WIDTH - self.radius)
            
        # 트레일 파티클 생성
        if random.random() < 0.5:
            create_trail_particle(self.x, self.y, self.trail_particles, 
                                get_neon_color(self.color), (self.vx * 0.1, self.vy * 0.1))
        
        # 파티클 업데이트
        self.trail_particles = update_particles(self.trail_particles)
        
    def draw(self, screen, draw_helper):
        """공 그리기"""
        # 트레일 파티클 그리기
        draw_particles(screen, self.trail_particles)
        
        # 글로우 효과
        draw_glow_effect(screen, (int(self.x), int(self.y)), 
                        self.radius, self.color, intensity=2)
        
        # 공 본체
        draw_helper.circle(self.color, (int(self.x), int(self.y)), self.radius)
        
    def check_paddle_collision(self, paddle):
        """패들과의 충돌 검사"""
        ball_rect = pygame.Rect(self.x - self.radius, self.y - self.radius, 
                               self.radius * 2, self.radius * 2)
        if ball_rect.colliderect(paddle.rect):
            # 충돌 위치에 따른 반사 각도 계산
            hit_pos = (self.x - paddle.rect.centerx) / (paddle.rect.width / 2)
            hit_pos = clamp(hit_pos, -1, 1)
            
            # 반사 각도
            bounce_angle = hit_pos * (math.pi / 3)  # 최대 60도
            
            # 속도 계산
            speed = get_speed_from_velocity(self.vx, self.vy)
            speed = min(speed * 1.05, MAX_BALL_SPEED)  # 약간 가속
            
            self.vx = speed * math.sin(bounce_angle)
            self.vy = -abs(speed * math.cos(bounce_angle)) if paddle.is_player else abs(speed * math.cos(bounce_angle))
            
            return True
        return False

class Paddle:
    """패들 클래스"""
    def __init__(self, x, y, is_player=True):
        self.rect = pygame.Rect(x, y, PADDLE_WIDTH, PADDLE_HEIGHT)
        self.speed = PADDLE_SPEED if is_player else PADDLE_SPEED * 0.8
        self.is_player = is_player
        self.color = get_stage_color(1) if is_player else get_stage_color(2)
        self.hit_particles = []
        
    def update(self, ball=None):
        """패들 업데이트"""
        if self.is_player:
            # 플레이어 컨트롤
            keys = pygame.key.get_pressed()
            if keys[pygame.K_LEFT]:
                self.rect.x -= self.speed
            if keys[pygame.K_RIGHT]:
                self.rect.x += self.speed
        else:
            # AI 컨트롤
            if ball:
                target_x = ball.x - self.rect.width / 2
                diff = target_x - self.rect.x
                
                # 부드러운 움직임
                move_amount = clamp(diff * 0.1, -self.speed, self.speed)
                self.rect.x += move_amount
        
        # 화면 경계 제한
        self.rect.x = clamp(self.rect.x, 0, WIDTH - self.rect.width)
        
        # 파티클 업데이트
        self.hit_particles = update_particles(self.hit_particles)
        
    def draw(self, screen, draw_helper):
        """패들 그리기"""
        # 히트 파티클 그리기
        draw_particles(screen, self.hit_particles)
        
        # 패들 그라데이션
        lighter_color = blend_colors(self.color, WHITE, 0.3)
        draw_gradient_rect(screen, self.rect, lighter_color, self.color)
        
        # 패들 테두리
        draw_helper.rect(get_neon_color(self.color), self.rect, 2)
        
    def on_hit(self):
        """공과 충돌했을 때"""
        # 히트 이펙트 생성
        create_hit_effect(self.rect.centerx, self.rect.centery, self.hit_particles, intensity=15)

class SimplePongGame:
    """간단한 Pong 게임"""
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((WIDTH, HEIGHT))
        pygame.display.set_caption("리팩토링 샘플 - Simple Pong")
        self.clock = pygame.time.Clock()
        self.draw_helper = DrawHelper(self.screen)
        
        # 게임 객체
        self.reset_game()
        
        # 배경 파티클
        self.bg_particles = []
        
        # 점수
        self.player_score = 0
        self.ai_score = 0
        
        # 폰트
        self.font = pygame.font.Font(None, 48)
        self.small_font = pygame.font.Font(None, 24)
        
    def reset_game(self):
        """게임 리셋"""
        self.ball = Ball(WIDTH // 2, HEIGHT // 2)
        self.player_paddle = Paddle(WIDTH // 2 - PADDLE_WIDTH // 2, HEIGHT - 50)
        self.ai_paddle = Paddle(WIDTH // 2 - PADDLE_WIDTH // 2, 50, is_player=False)
        
    def handle_events(self):
        """이벤트 처리"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return False
                elif event.key == pygame.K_r:
                    self.reset_game()
                elif event.key == pygame.K_SPACE:
                    # 스페이스로 파워업 효과
                    create_powerup_effect(self.ball.x, self.ball.y, self.bg_particles)
        return True
        
    def update(self):
        """게임 로직 업데이트"""
        # 패들 업데이트
        self.player_paddle.update()
        self.ai_paddle.update(self.ball)
        
        # 공 업데이트
        self.ball.update()
        
        # 충돌 검사
        if self.ball.check_paddle_collision(self.player_paddle):
            self.player_paddle.on_hit()
            self.ball.color = get_neon_color(self.player_paddle.color)
            
        if self.ball.check_paddle_collision(self.ai_paddle):
            self.ai_paddle.on_hit()
            self.ball.color = get_neon_color(self.ai_paddle.color)
        
        # 점수 체크
        if self.ball.y < 0:
            self.player_score += 1
            self.reset_game()
            create_explosion_particles(WIDTH // 2, HEIGHT // 4, self.bg_particles, count=30)
            
        elif self.ball.y > HEIGHT:
            self.ai_score += 1
            self.reset_game()
            create_explosion_particles(WIDTH // 2, HEIGHT * 3 // 4, self.bg_particles, count=30)
        
        # 배경 파티클 업데이트
        self.bg_particles = update_particles(self.bg_particles, gravity=0, friction=0.98)
        
        # 가끔 배경 파티클 생성
        if random.random() < 0.02:
            x = random.randint(0, WIDTH)
            y = random.randint(0, HEIGHT)
            create_neon_particle(x, y, self.bg_particles)
            
    def draw_ui(self):
        """UI 그리기"""
        # 점수 표시
        score_text = self.font.render(f"{self.ai_score} - {self.player_score}", True, WHITE)
        score_rect = score_text.get_rect(center=(WIDTH // 2, HEIGHT // 2))
        
        # 점수 배경
        pygame.draw.rect(self.screen, (*BLACK, 150), 
                        score_rect.inflate(40, 20), border_radius=10)
        self.screen.blit(score_text, score_rect)
        
        # 중앙선
        for y in range(0, HEIGHT, 20):
            self.draw_helper.rect(GRAY, (WIDTH // 2 - 2, y, 4, 10))
        
        # 조작법
        controls = [
            "← → : 이동",
            "SPACE : 이펙트",
            "R : 리셋",
            "ESC : 종료"
        ]
        
        y = 10
        for text in controls:
            text_surface = self.small_font.render(text, True, LIGHT_GRAY)
            self.screen.blit(text_surface, (10, y))
            y += 25
            
    def draw(self):
        """화면 그리기"""
        # 배경 그라데이션
        draw_gradient_rect(self.screen, (0, 0, WIDTH, HEIGHT), 
                          (*DARK_GRAY, 255), (*BLACK, 255))
        
        # 스테이지별 색상 효과
        stage = (self.player_score + self.ai_score) % 6 + 1
        accent_color = get_stage_color(stage)
        
        # 배경 격자
        grid_alpha = 30
        for x in range(0, WIDTH, 50):
            pygame.draw.line(self.screen, (*accent_color, grid_alpha), 
                           (x, 0), (x, HEIGHT), 1)
        for y in range(0, HEIGHT, 50):
            pygame.draw.line(self.screen, (*accent_color, grid_alpha), 
                           (0, y), (WIDTH, y), 1)
        
        # 배경 파티클
        draw_particles(self.screen, self.bg_particles)
        
        # 게임 객체
        self.player_paddle.draw(self.screen, self.draw_helper)
        self.ai_paddle.draw(self.screen, self.draw_helper)
        self.ball.draw(self.screen, self.draw_helper)
        
        # UI
        self.draw_ui()
        
    def run(self):
        """게임 실행"""
        running = True
        
        while running:
            # 이벤트 처리
            running = self.handle_events()
            
            # 업데이트
            self.update()
            
            # 그리기
            self.draw()
            
            # 화면 업데이트
            pygame.display.flip()
            self.clock.tick(FPS)
        
        pygame.quit()
        sys.exit()

def main():
    """메인 함수"""
    print("=" * 50)
    print("🎮 리팩토링된 모듈을 사용한 Simple Pong")
    print("=" * 50)
    print("이 샘플은 분리된 유틸리티 모듈들을 활용하여")
    print("간단한 Pong 게임을 구현한 예시입니다.")
    print("-" * 50)
    print("조작법:")
    print("  ← → : 패들 이동")
    print("  SPACE : 파워업 이펙트")
    print("  R : 게임 리셋")
    print("  ESC : 종료")
    print("=" * 50)
    print()
    
    game = SimplePongGame()
    game.run()

if __name__ == "__main__":
    main()