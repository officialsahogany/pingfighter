"""
BossPong - 리팩토링된 메인 게임 파일
아케이드 스타일 보스 배틀 퐁 게임
"""

import pygame
import random
import sys
import math
import importlib

# 코어 모듈
from core.constants import *
from core.config import game_config

# 매니저 모듈
from stages.stage_loader import StageLoader
import ui_manager
import effects_manager
import physics_manager
import dash_manager

# 게임 모듈
import items
import option as option_module
import gacha
import opening
import skill
import academy
import cinematic

# 모듈 리로드
importlib.reload(items)

# AI 모듈 (선택적)
try:
    from boss_ai_integration import EnhancedBossAI, create_game_state, apply_ai_decision
    AI_AVAILABLE = True
    print("🧠 딥러닝 AI 모듈이 로드되었습니다!")
except ImportError as e:
    AI_AVAILABLE = False
    print(f"⚠️ 딥러닝 AI 모듈을 사용할 수 없습니다: {e}")
    print("   기본 AI로 실행됩니다. TensorFlow 설치: pip install tensorflow")

# 플레이어 분석 시스템 (선택적)
try:
    from player_skill_analyzer import get_player_analyzer, SkillRank
    SKILL_ANALYZER_AVAILABLE = True
    print("🏆 플레이어 실력 분석 시스템이 로드되었습니다!")
except ImportError as e:
    SKILL_ANALYZER_AVAILABLE = False
    print(f"⚠️ 플레이어 분석 시스템 로드 실패: {e}")
    def get_player_analyzer():
        return None


class BossPongGame:
    """메인 게임 클래스"""
    
    def __init__(self):
        """게임 초기화"""
        pygame.init()
        
        # 화면 설정
        self.screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
        pygame.display.set_caption("PINGFIGHTER")
        
        # 게임 설정
        self.config = game_config
        self.clock = pygame.time.Clock()
        self.running = True
        
        # 스테이지 로더
        self.stage_loader = StageLoader()
        self.current_stage = 1
        
        # 게임 상태
        self.game_state = "menu"  # menu, playing, paused, game_over
        self.player_score = 0
        self.ai_score = 0
        
        # 엔티티들 (나중에 클래스로 분리)
        self.player_x = SCREEN_WIDTH // 2 - PADDLE_WIDTH // 2
        self.player_y = SCREEN_HEIGHT - 50
        self.ai_x = SCREEN_WIDTH // 2 - PADDLE_WIDTH // 2
        self.ai_y = 50
        
        self.ball_x = SCREEN_WIDTH // 2
        self.ball_y = SCREEN_HEIGHT // 2
        self.ball_dx = random.choice([-BALL_SPEED, BALL_SPEED])
        self.ball_dy = random.choice([-BALL_SPEED, BALL_SPEED])
        
        # 배경 로드
        self.load_stage_backgrounds()
        
    def load_stage_backgrounds(self):
        """모든 스테이지 배경 로드"""
        for stage in range(1, 7):
            self.stage_loader.load_stage_background(stage)
    
    def get_current_background(self):
        """현재 스테이지 배경 반환"""
        return self.stage_loader.get_background(self.current_stage)
    
    def handle_events(self):
        """이벤트 처리"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    if self.game_state == "playing":
                        self.game_state = "paused"
                    elif self.game_state == "paused":
                        self.game_state = "playing"
                    else:
                        self.running = False
    
    def update(self):
        """게임 로직 업데이트"""
        if self.game_state != "playing":
            return
        
        # 플레이어 입력 처리
        keys = pygame.key.get_pressed()
        if keys[pygame.K_LEFT] and self.player_x > 0:
            self.player_x -= 5
        if keys[pygame.K_RIGHT] and self.player_x < SCREEN_WIDTH - PADDLE_WIDTH:
            self.player_x += 5
        
        # 공 이동
        self.ball_x += self.ball_dx
        self.ball_y += self.ball_dy
        
        # 벽 충돌
        if self.ball_x <= 0 or self.ball_x >= SCREEN_WIDTH - BALL_SIZE:
            self.ball_dx *= -1
        
        # 점수 처리
        if self.ball_y <= 0:
            self.player_score += 1
            self.reset_ball()
        elif self.ball_y >= SCREEN_HEIGHT:
            self.ai_score += 1
            self.reset_ball()
        
        # 패들 충돌 체크
        self.check_paddle_collision()
        
        # AI 이동
        self.update_ai()
    
    def check_paddle_collision(self):
        """패들과 공 충돌 체크"""
        # 플레이어 패들
        if (self.player_y <= self.ball_y <= self.player_y + PADDLE_HEIGHT and
            self.player_x <= self.ball_x <= self.player_x + PADDLE_WIDTH):
            self.ball_dy = -abs(self.ball_dy)
            
        # AI 패들
        if (self.ai_y <= self.ball_y <= self.ai_y + PADDLE_HEIGHT and
            self.ai_x <= self.ball_x <= self.ai_x + PADDLE_WIDTH):
            self.ball_dy = abs(self.ball_dy)
    
    def update_ai(self):
        """AI 패들 업데이트"""
        # 간단한 AI 로직
        if self.ball_x < self.ai_x + PADDLE_WIDTH // 2:
            self.ai_x = max(0, self.ai_x - 4)
        elif self.ball_x > self.ai_x + PADDLE_WIDTH // 2:
            self.ai_x = min(SCREEN_WIDTH - PADDLE_WIDTH, self.ai_x + 4)
    
    def reset_ball(self):
        """공 위치 리셋"""
        self.ball_x = SCREEN_WIDTH // 2
        self.ball_y = SCREEN_HEIGHT // 2
        self.ball_dx = random.choice([-BALL_SPEED, BALL_SPEED])
        self.ball_dy = random.choice([-BALL_SPEED, BALL_SPEED])
    
    def draw(self):
        """화면 그리기"""
        # 배경 그리기
        background = self.get_current_background()
        self.screen.blit(background, (0, 0))
        
        # 패들 그리기
        pygame.draw.rect(self.screen, WHITE, (self.player_x, self.player_y, PADDLE_WIDTH, PADDLE_HEIGHT))
        pygame.draw.rect(self.screen, RED, (self.ai_x, self.ai_y, PADDLE_WIDTH, PADDLE_HEIGHT))
        
        # 공 그리기
        pygame.draw.circle(self.screen, YELLOW, (int(self.ball_x), int(self.ball_y)), BALL_SIZE)
        
        # 점수 표시
        self.draw_score()
        
        # 화면 업데이트
        pygame.display.flip()
    
    def draw_score(self):
        """점수 표시"""
        font = pygame.font.Font(None, 36)
        player_text = font.render(f"Player: {self.player_score}", True, WHITE)
        ai_text = font.render(f"AI: {self.ai_score}", True, WHITE)
        
        self.screen.blit(player_text, (10, SCREEN_HEIGHT - 40))
        self.screen.blit(ai_text, (10, 10))
    
    def run(self):
        """메인 게임 루프"""
        # 오프닝 화면 (옵션)
        # opening.show_opening(self.screen)
        
        self.game_state = "playing"
        
        while self.running:
            self.handle_events()
            self.update()
            self.draw()
            self.clock.tick(FPS)
        
        pygame.quit()
        sys.exit()


def main():
    """메인 함수"""
    game = BossPongGame()
    game.run()


if __name__ == "__main__":
    main()