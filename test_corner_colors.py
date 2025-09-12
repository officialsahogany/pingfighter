import pygame
import sys

# 초기화
pygame.init()
WIDTH, HEIGHT = 800, 400
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("라그나로크 해머 꼭지점 색상 분석")

# 색상 정의
BACKGROUND_COLOR = (20, 20, 40)

# 라그나로크 해머의 실제 꼭지점 색상 패턴 추정
# 사용자가 파란색이라고 했으니 파란색 계열의 변화일 가능성
corner_colors_pattern1 = [
    (0, 100, 255),    # 진한 파랑
    (0, 150, 255),    # 중간 파랑
    (0, 200, 255),    # 밝은 파랑
    (100, 150, 255),  # 연한 보라빛 파랑
    (0, 100, 255),    # 진한 파랑
    (0, 150, 255),    # 중간 파랑
    (0, 200, 255),    # 밝은 파랑
    (100, 150, 255),  # 연한 보라빛 파랑
]

# 또 다른 가능한 패턴 (색상 순환)
corner_colors_pattern2 = [
    (0, 150, 255),    # 파랑
    (150, 0, 255),    # 보라
    (255, 0, 150),    # 분홍
    (255, 150, 0),    # 주황
    (0, 150, 255),    # 파랑
    (150, 0, 255),    # 보라
    (255, 0, 150),    # 분홍
    (255, 150, 0),    # 주황
]

# 현재 코드의 패턴
current_pattern = [
    (255, 215, 0),    # 황금색
    (0, 150, 255),    # 파란색
    (255, 0, 0),      # 빨간색
    (150, 0, 255),    # 보라색
    (255, 215, 0),    # 황금색
    (0, 150, 255),    # 파란색
    (255, 0, 0),      # 빨간색
    (150, 0, 255),    # 보라색
]

def draw_pattern(screen, x, y, pattern, name):
    """색상 패턴 표시"""
    font = pygame.font.Font(None, 24)
    name_text = font.render(name, True, (255, 255, 255))
    screen.blit(name_text, (x, y - 30))
    
    for i, color in enumerate(pattern):
        # 색상 사각형
        rect_x = x + i * 80
        rect_y = y
        pygame.draw.rect(screen, color, (rect_x, rect_y, 60, 60))
        pygame.draw.rect(screen, (255, 255, 255), (rect_x, rect_y, 60, 60), 2)
        
        # 프레임 번호
        frame_text = font.render(str(i), True, (255, 255, 255))
        screen.blit(frame_text, (rect_x + 25, rect_y + 70))
        
        # RGB 값
        rgb_font = pygame.font.Font(None, 16)
        rgb_text = rgb_font.render(f"R:{color[0]}", True, (200, 200, 200))
        screen.blit(rgb_text, (rect_x + 5, rect_y + 95))
        rgb_text = rgb_font.render(f"G:{color[1]}", True, (200, 200, 200))
        screen.blit(rgb_text, (rect_x + 5, rect_y + 110))
        rgb_text = rgb_font.render(f"B:{color[2]}", True, (200, 200, 200))
        screen.blit(rgb_text, (rect_x + 5, rect_y + 125))

def main():
    clock = pygame.time.Clock()
    running = True
    current_frame = 0
    frame_counter = 0
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
        
        # 화면 초기화
        SCREEN.fill(BACKGROUND_COLOR)
        
        # 프레임 업데이트
        frame_counter += 1
        if frame_counter >= 8:
            frame_counter = 0
            current_frame = (current_frame + 1) % 8
        
        # 제목
        title_font = pygame.font.Font(None, 30)
        title = title_font.render(f"꼭지점 색상 패턴 비교 (현재 프레임: {current_frame})", True, (255, 255, 255))
        SCREEN.blit(title, (WIDTH//2 - title.get_width()//2, 20))
        
        # 세 가지 패턴 표시
        draw_pattern(SCREEN, 50, 80, corner_colors_pattern1, "패턴 1: 파란색 그라데이션")
        draw_pattern(SCREEN, 50, 180, corner_colors_pattern2, "패턴 2: 색상 순환")
        draw_pattern(SCREEN, 50, 280, current_pattern, "현재 코드")
        
        # 현재 프레임 강조
        for y in [80, 180, 280]:
            highlight_x = 50 + current_frame * 80
            pygame.draw.rect(SCREEN, (255, 255, 0), (highlight_x - 2, y - 2, 64, 64), 3)
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()