import pygame
import sys

# 초기화
pygame.init()
WIDTH, HEIGHT = 800, 600
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("라그나로크 해머 - 글로우 효과 시각화")

# 색상 정의
BACKGROUND_COLOR = (20, 20, 40)  # 어두운 배경
LEGENDARY_COLOR = (255, 0, 0)  # 붉은색

def draw_glow_effect(screen, x, y, size, glow_intensity):
    """라그나로크 해머의 글로우 효과만 그리기"""
    
    # 라그나로크 해머 전용 글로우 배율
    hammer_glow_multiplier = 1.8
    
    # 글로우 크기 계산: 기본 크기의 1.8배 + 펄싱 효과(0.15배)
    glow_size = int(size * (hammer_glow_multiplier + glow_intensity * 0.15))
    
    # 글로우 서피스 생성 (알파 채널 포함)
    glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
    
    # 5개의 동심원 레이어
    for i in range(5):
        # 알파값 계산: 80 → 68 → 56 → 44 → 32
        alpha = 80 - i * 12
        
        # 각 레이어의 반지름 (4픽셀씩 감소)
        radius = glow_size//2 - i * 4
        
        # 동심원 그리기
        pygame.draw.circle(glow_surf, (*LEGENDARY_COLOR, alpha), 
                         (glow_size//2, glow_size//2), 
                         radius)
    
    # 글로우 효과를 화면에 블릿 (중앙 정렬)
    screen.blit(glow_surf, (x - (glow_size - size)//2, y - (glow_size - size)//2))
    
    # 참조용 아이콘 영역 표시 (실선 사각형)
    pygame.draw.rect(screen, (100, 100, 100), (x, y, size, size), 1)
    
    # 정보 텍스트
    font = pygame.font.Font(None, 24)
    info_texts = [
        f"Icon Size: {size}px",
        f"Glow Size: {glow_size}px (x{hammer_glow_multiplier + glow_intensity * 0.15:.2f})",
        f"Glow Layers: 5",
        f"Alpha Values: 80, 68, 56, 44, 32",
        f"Layer Gap: 4px",
        f"Glow Intensity: {glow_intensity:.2f}"
    ]
    
    y_offset = 20
    for text in info_texts:
        text_surface = font.render(text, True, (200, 200, 200))
        screen.blit(text_surface, (20, y_offset))
        y_offset += 30

def main():
    clock = pygame.time.Clock()
    running = True
    
    # 아이콘 크기
    icon_size = 60
    
    # 글로우 강도 (펄싱 효과를 위한 변수)
    glow_intensity = 0.0
    glow_direction = 1
    
    # 여러 크기로 테스트
    test_sizes = [40, 60, 80, 100]
    
    # 폰트 초기화
    font = pygame.font.Font(None, 24)
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
        
        # 화면 초기화
        SCREEN.fill(BACKGROUND_COLOR)
        
        # 펄싱 효과 업데이트 (0.0 ~ 1.0 사이)
        glow_intensity += 0.02 * glow_direction
        if glow_intensity >= 1.0:
            glow_intensity = 1.0
            glow_direction = -1
        elif glow_intensity <= 0.0:
            glow_intensity = 0.0
            glow_direction = 1
        
        # 메인 글로우 효과 (화면 중앙)
        center_x = WIDTH // 2
        center_y = HEIGHT // 2
        draw_glow_effect(SCREEN, center_x - icon_size//2, center_y - icon_size//2, 
                        icon_size, glow_intensity)
        
        # 하단에 다양한 크기 예시
        x_start = WIDTH // 2 - (len(test_sizes) * 120) // 2
        y_bottom = HEIGHT - 150
        
        for i, size in enumerate(test_sizes):
            x = x_start + i * 120
            y = y_bottom - size // 2
            
            # 작은 글로우 효과들
            small_glow_surf = pygame.Surface((int(size * 2), int(size * 2)), pygame.SRCALPHA)
            for j in range(5):
                alpha = (80 - j * 12) // 2  # 더 투명하게
                radius = size - j * 3
                if radius > 0:
                    pygame.draw.circle(small_glow_surf, (*LEGENDARY_COLOR, alpha), 
                                     (size, size), radius)
            
            SCREEN.blit(small_glow_surf, (x - size//2, y - size//2))
            pygame.draw.rect(SCREEN, (100, 100, 100), (x + size//2, y + size//2, size, size), 1)
            
            # 크기 레이블
            size_text = font.render(f"{size}px", True, (150, 150, 150))
            SCREEN.blit(size_text, (x + size//2, y + size + size//2 + 10))
        
        # 타이틀
        title_font = pygame.font.Font(None, 36)
        title_text = title_font.render("Ragnarok Hammer - Glow Effect Visualization", True, (255, 255, 255))
        title_rect = title_text.get_rect(center=(WIDTH//2, HEIGHT - 50))
        SCREEN.blit(title_text, title_rect)
        
        # 업데이트
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()