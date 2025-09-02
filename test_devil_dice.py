#!/usr/bin/env python3
"""
악마의 주사위 테스트
"""

import pygame
import sys
import os

# 모듈 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from item_effects.devil_dice import (
    activate_devil_dice, 
    update_devil_dice, 
    draw_devil_dice_effects,
    get_devil_dice_multipliers,
    is_devil_dice_active
)

# Pygame 초기화
pygame.init()

# 화면 설정
SCREEN_WIDTH = 600
SCREEN_HEIGHT = 750
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("Devil's Dice Test")

# 색상
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
BLUE = (100, 100, 255)

# 테스트용 패들
class TestPaddle:
    def __init__(self):
        self.width = 100
        self.height = 20
        self.x = SCREEN_WIDTH // 2 - self.width // 2
        self.y = SCREEN_HEIGHT - 100
        self.rect = pygame.Rect(self.x, self.y, self.width, self.height)
        self.base_width = 100
    
    def update(self):
        # 마우스 따라 이동
        mouse_x, _ = pygame.mouse.get_pos()
        self.x = mouse_x - self.width // 2
        
        if self.x < 0:
            self.x = 0
        if self.x + self.width > SCREEN_WIDTH:
            self.x = SCREEN_WIDTH - self.width
        
        self.rect.x = self.x
        self.rect.width = self.width
    
    def apply_multiplier(self, multiplier):
        """악마의 주사위 배율 적용"""
        self.width = int(self.base_width * multiplier)
        self.rect.width = self.width
    
    def draw(self, screen):
        pygame.draw.rect(screen, BLUE, self.rect)

# 메인 루프
def main():
    clock = pygame.time.Clock()
    running = True
    paddle = TestPaddle()
    current_stage = 1
    
    # 폰트
    try:
        font = pygame.font.Font("NeoDGM.ttf", 20)
        small_font = pygame.font.Font("NeoDGM.ttf", 14)
    except:
        font = pygame.font.Font(None, 20)
        small_font = pygame.font.Font(None, 14)
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE:
                    # 스페이스바로 악마의 주사위 발동
                    if not is_devil_dice_active():
                        game_state = {
                            'paddle_width': paddle.base_width,
                            'skill_gauge_max': 100,
                        }
                        multipliers = activate_devil_dice(game_state, current_stage)
                        print(f"🎲 주사위 발동! 배율: {multipliers}")
                elif event.key == pygame.K_1:
                    current_stage = 1
                    print(f"스테이지 {current_stage}로 변경")
                elif event.key == pygame.K_2:
                    current_stage = 2
                    print(f"스테이지 {current_stage}로 변경 (효과 종료됨)")
        
        # 업데이트
        paddle.update()
        
        # 악마의 주사위 업데이트
        if is_devil_dice_active():
            update_devil_dice(current_stage)
            
            # 패들 크기 배율 적용
            multipliers = get_devil_dice_multipliers()
            paddle.apply_multiplier(multipliers['paddle_size'])
        else:
            paddle.apply_multiplier(1.0)
        
        # 화면 그리기
        screen.fill(BLACK)
        
        # 격자 배경
        for x in range(0, SCREEN_WIDTH, 50):
            pygame.draw.line(screen, (30, 30, 30), (x, 0), (x, SCREEN_HEIGHT), 1)
        for y in range(0, SCREEN_HEIGHT, 50):
            pygame.draw.line(screen, (30, 30, 30), (0, y), (SCREEN_WIDTH, y), 1)
        
        # 패들 그리기
        paddle.draw(screen)
        
        # 악마의 주사위 효과 그리기
        draw_devil_dice_effects(screen, paddle.rect)
        
        # UI 정보
        if is_devil_dice_active():
            multipliers = get_devil_dice_multipliers()
            
            y_pos = 10
            info_texts = [
                f"Stage: {current_stage}",
                "== Devil's Dice Active ==",
                f"Paddle Size: x{multipliers['paddle_size']:.1f}",
                f"Skill Gauge: x{multipliers['skill_gauge']:.1f}",
                f"Item Spawn: x{multipliers['item_spawn']:.1f}",
                f"Active CD: x{multipliers['active_cooldown']:.1f}",
                f"Skill/Dash Cost: x{multipliers['skill_dash_cost']:.1f}",
                f"Dash CD: x{multipliers['dash_cooldown']:.1f}"
            ]
            
            for text in info_texts:
                surface = small_font.render(text, True, WHITE)
                screen.blit(surface, (10, y_pos))
                y_pos += 18
        else:
            info_text = font.render(f"Stage {current_stage} - Press SPACE to activate Devil's Dice", True, WHITE)
            screen.blit(info_text, (10, 10))
        
        # 조작법
        help_texts = [
            "SPACE: Activate Devil's Dice",
            "1/2: Change Stage (Stage 2 ends effect)",
            "Mouse: Move Paddle"
        ]
        
        y_pos = SCREEN_HEIGHT - 60
        for text in help_texts:
            surface = small_font.render(text, True, (150, 150, 150))
            screen.blit(surface, (10, y_pos))
            y_pos += 20
        
        # 화면 업데이트
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()