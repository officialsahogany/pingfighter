import pygame
import sys
import math

# 초기화
pygame.init()
WIDTH, HEIGHT = 600, 400
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("전설 아이템 코너 점 비교")

# 색상 정의
BACKGROUND_COLOR = (20, 20, 40)
LEGENDARY_COLOR = (255, 0, 0)
GOLDEN_COLOR = (255, 215, 0)

def draw_item_with_dots(screen, x, y, size, frame, item_name):
    """아이템 테두리와 점 그리기"""
    # 붉은색 테두리
    border_rect = pygame.Rect(x-2, y-2, size+4, size+4)
    pygame.draw.rect(screen, LEGENDARY_COLOR, border_rect, 3)
    
    # 황금색 코너 장식
    corner_size = 8
    # 왼쪽 위
    pygame.draw.lines(screen, GOLDEN_COLOR, False, 
                     [(x-2, y+corner_size), (x-2, y-2), (x+corner_size, y-2)], 2)
    # 오른쪽 위
    pygame.draw.lines(screen, GOLDEN_COLOR, False,
                     [(x+size-corner_size+2, y-2), (x+size+2, y-2), (x+size+2, y+corner_size)], 2)
    # 왼쪽 아래
    pygame.draw.lines(screen, GOLDEN_COLOR, False,
                     [(x-2, y+size-corner_size+2), (x-2, y+size+2), (x+corner_size, y+size+2)], 2)
    # 오른쪽 아래
    pygame.draw.lines(screen, GOLDEN_COLOR, False,
                     [(x+size-corner_size+2, y+size+2), (x+size+2, y+size+2), (x+size+2, y+size-corner_size+2)], 2)
    
    # 코너 점 장식 (현재 코드)
    if item_name == "current":
        for cx, cy in [(x, y), (x+size, y), (x, y+size), (x+size, y+size)]:
            pygame.draw.circle(screen, LEGENDARY_COLOR, (cx, cy), 3)
            pygame.draw.circle(screen, GOLDEN_COLOR, (cx, cy), 2)
    
    # 프레임 기반 색상 변경 제안
    elif item_name == "frame_based":
        # 프레임에 따라 점 색상 변경
        if frame % 4 == 0:
            dot_color = (255, 215, 0)  # 황금색
        elif frame % 4 == 1:
            dot_color = (0, 150, 255)  # 파란색
        elif frame % 4 == 2:
            dot_color = (255, 0, 0)    # 빨간색
        else:
            dot_color = (150, 0, 255)  # 보라색
        
        for cx, cy in [(x, y), (x+size, y), (x, y+size), (x+size, y+size)]:
            pygame.draw.circle(screen, LEGENDARY_COLOR, (cx, cy), 3)
            pygame.draw.circle(screen, dot_color, (cx, cy), 2)
    
    # PNG 스타일 (파란색 점)
    elif item_name == "png_style":
        for cx, cy in [(x, y), (x+size, y), (x, y+size), (x+size, y+size)]:
            pygame.draw.circle(screen, (0, 150, 255), (cx, cy), 3)  # 파란색
    
    # 아이템 내부 (회색으로 표시)
    inner_rect = pygame.Rect(x+4, y+4, size-8, size-8)
    pygame.draw.rect(screen, (80, 80, 80), inner_rect)
    
    # 아이템 이름
    font = pygame.font.Font(None, 20)
    text = font.render(item_name, True, (255, 255, 255))
    screen.blit(text, (x + size//2 - text.get_width()//2, y + size + 10))

def main():
    clock = pygame.time.Clock()
    running = True
    current_frame = 0
    frame_counter = 0
    animation_speed = 8
    
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
        if frame_counter >= animation_speed:
            frame_counter = 0
            current_frame = (current_frame + 1) % 8
        
        # 제목
        title_font = pygame.font.Font(None, 30)
        title = title_font.render(f"코너 점 비교 (프레임: {current_frame})", True, (255, 255, 255))
        SCREEN.blit(title, (WIDTH//2 - title.get_width()//2, 20))
        
        # 세 가지 스타일 비교
        item_size = 80
        y_center = HEIGHT//2 - item_size//2
        
        # 현재 코드 스타일
        draw_item_with_dots(SCREEN, 100, y_center, item_size, current_frame, "current")
        
        # 프레임 기반 색상 변경
        draw_item_with_dots(SCREEN, 250, y_center, item_size, current_frame, "frame_based")
        
        # PNG 스타일 (파란색)
        draw_item_with_dots(SCREEN, 400, y_center, item_size, current_frame, "png_style")
        
        # 설명
        desc_font = pygame.font.Font(None, 18)
        descriptions = [
            "현재 코드",
            "프레임 색상",
            "PNG 스타일"
        ]
        x_positions = [100 + item_size//2, 250 + item_size//2, 400 + item_size//2]
        
        for desc, x_pos in zip(descriptions, x_positions):
            desc_text = desc_font.render(desc, True, (200, 200, 200))
            SCREEN.blit(desc_text, (x_pos - desc_text.get_width()//2, y_center + item_size + 35))
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()