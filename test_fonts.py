#!/usr/bin/env python3
"""
폰트 미리보기 테스트
다양한 한글 폰트를 비교해보세요!
"""

import pygame
import sys

pygame.init()

# 화면 설정
WIDTH, HEIGHT = 800, 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("🎮 레트로 픽셀 폰트 미리보기")

# 색상
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
GREEN = (0, 255, 0)
CYAN = (0, 255, 255)
YELLOW = (255, 255, 0)
RED = (255, 0, 0)
PURPLE = (255, 0, 255)

# 테스트할 폰트들
fonts_to_test = [
    ("NeoDunggeunmoPro.ttf", "네오둥근모 (픽셀)", GREEN),
    ("Pretendard-Bold.ttf", "프리텐다드 Bold", CYAN),
    ("Pretendard-Regular.ttf", "프리텐다드 Regular", WHITE),
    ("NanumSquareB.ttf", "나눔스퀘어 Bold", YELLOW),
]

# 테스트 텍스트
test_texts = [
    "PingFighter 핑파이터",
    "Stage 6 - 보스전",
    "점수: 12,345",
    "게임 오버!",
    "아이템 획득!",
    "파워 UP! 레벨 99",
]

def main():
    clock = pygame.time.Clock()
    running = True
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
        
        # 배경
        screen.fill(BLACK)
        
        # 타이틀
        try:
            title_font = pygame.font.Font("NeoDunggeunmoPro.ttf", 48)
            title = title_font.render("🎮 폰트 미리보기", True, GREEN)
            screen.blit(title, (WIDTH//2 - title.get_width()//2, 20))
        except:
            pass
        
        # 각 폰트 테스트
        y_offset = 100
        
        for font_file, font_name, color in fonts_to_test:
            try:
                # 폰트 로드
                font = pygame.font.Font(font_file, 24)
                
                # 폰트 이름 표시
                name_text = font.render(f"[{font_name}]", True, color)
                screen.blit(name_text, (50, y_offset))
                
                # 샘플 텍스트
                sample_text = f"핑파이터 STAGE 6 - 점수: 9999"
                sample = font.render(sample_text, True, color)
                screen.blit(sample, (50, y_offset + 30))
                
                y_offset += 80
                
            except Exception as e:
                # 폰트 로드 실패
                error_font = pygame.font.Font(None, 20)
                error_text = error_font.render(f"❌ {font_name} 로드 실패", True, RED)
                screen.blit(error_text, (50, y_offset))
                y_offset += 40
        
        # 픽셀 아트 효과
        if pygame.time.get_ticks() % 1000 < 500:
            try:
                pixel_font = pygame.font.Font("NeoDunggeunmoPro.ttf", 32)
                flash_text = pixel_font.render("PRESS ESC TO EXIT", True, 
                                              (random.randint(100, 255), 
                                               random.randint(100, 255), 
                                               random.randint(100, 255)))
                screen.blit(flash_text, (WIDTH//2 - flash_text.get_width()//2, HEIGHT - 50))
            except:
                pass
        
        pygame.display.flip()
        clock.tick(30)
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    import random
    main()