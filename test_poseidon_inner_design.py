import pygame
import sys
import math

# 초기화
pygame.init()
WIDTH, HEIGHT = 800, 600
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("포세이돈 삼지창 - 내부 디자인 추가 테스트")

# 색상 정의
BACKGROUND_COLOR = (20, 20, 40)
LEGENDARY_COLOR = (255, 0, 0)
GOLDEN_COLOR = (255, 215, 0)

class PoseidonTest:
    def __init__(self):
        self.icon_size = 120  # 큰 사이즈로 테스트
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8
        self.glow_intensity = 0.5
        self.glow_direction = 1
        self.animation_offset = 0
        self.animation_time = 0
        
    def update(self, dt):
        """애니메이션 업데이트"""
        # 글로우 펄싱
        self.glow_intensity += 0.02 * self.glow_direction
        if self.glow_intensity >= 1.0:
            self.glow_intensity = 1.0
            self.glow_direction = -1
        elif self.glow_intensity <= 0.0:
            self.glow_intensity = 0.0
            self.glow_direction = 1
        
        # 위아래 부유 효과
        self.animation_time += dt
        self.animation_offset = math.sin(self.animation_time * 2) * 5
        
        # 프레임 카운터
        self.frame_counter += 1
        if self.frame_counter >= self.animation_speed:
            self.frame_counter = 0
            self.current_frame = (self.current_frame + 1) % 8
    
    def draw_poseidon_icon(self, screen, x, y, size):
        """포세이돈 아이콘 그리기"""
        # 글로우 효과 제거 (사용자 요청)
        
        # 외부 테두리 - 붉은색 (펄싱 효과)
        border_thickness = 3 + int(self.glow_intensity * 3)
        border_rect = pygame.Rect(x-2, y-2, size+4, size+4)
        pygame.draw.rect(screen, LEGENDARY_COLOR, border_rect, border_thickness)
        
        # 황금색 코너 장식
        corner_size = 8
        corner_color = (255, 215, 0)
        # 왼쪽 위
        pygame.draw.lines(screen, corner_color, False, 
                         [(x-2, y+corner_size), (x-2, y-2), (x+corner_size, y-2)], 2)
        # 오른쪽 위
        pygame.draw.lines(screen, corner_color, False,
                         [(x+size-corner_size+2, y-2), (x+size+2, y-2), (x+size+2, y+corner_size)], 2)
        # 왼쪽 아래
        pygame.draw.lines(screen, corner_color, False,
                         [(x-2, y+size-corner_size+2), (x-2, y+size+2), (x+corner_size, y+size+2)], 2)
        # 오른쪽 아래
        pygame.draw.lines(screen, corner_color, False,
                         [(x+size-corner_size+2, y+size+2), (x+size+2, y+size+2), (x+size+2, y+size-corner_size+2)], 2)
        
        # 코너 점 장식 제거 (사용자 요청)
        
        # 삼지창 아이콘 (간단한 표현)
        icon_y = y + int(self.animation_offset)
        trident_color = (100, 200, 255)
        
        # 삼지창 막대
        pygame.draw.rect(screen, trident_color, (x + size//2 - 3, icon_y + 10, 6, size - 20))
        
        # 삼지창 머리
        prong_y = icon_y + 10
        # 가운데 갈래
        pygame.draw.polygon(screen, trident_color, 
                          [(x + size//2, prong_y - 5),
                           (x + size//2 - 5, prong_y + 15),
                           (x + size//2 + 5, prong_y + 15)])
        # 왼쪽 갈래
        pygame.draw.polygon(screen, trident_color,
                          [(x + size//2 - 15, prong_y),
                           (x + size//2 - 20, prong_y + 15),
                           (x + size//2 - 10, prong_y + 15)])
        # 오른쪽 갈래
        pygame.draw.polygon(screen, trident_color,
                          [(x + size//2 + 15, prong_y),
                           (x + size//2 + 20, prong_y + 15),
                           (x + size//2 + 10, prong_y + 15)])
        
        # PNG에 없는 내부 디자인 추가 (라그나로크/헤르메스 스타일)
        # 1. 내부 빨간색 테두리 (프레임별 그라데이션)
        frame_gradient = self.current_frame / 8.0  # 0.0 ~ 1.0
        inner_red = int(200 + 55 * math.sin(frame_gradient * math.pi * 2))  # 200-255 사이 변화
        inner_border_color = (inner_red, 0, 0)
        inner_border_rect = pygame.Rect(x, icon_y, size, size)  # 아이콘 전체 크기
        pygame.draw.rect(screen, inner_border_color, inner_border_rect, 3)
        
        # 2. 꼭지점 (프레임별 색상 변화 - 라그나로크 스타일)
        # 프레임에 따라 색상 변화 (스크린샷 기반)
        if self.current_frame == 0 or self.current_frame == 4:
            corner_color_inner = (0, 150, 255)  # 파란색
        elif self.current_frame == 1 or self.current_frame == 5:
            corner_color_inner = (255, 200, 0)  # 주황색/노란색
        elif self.current_frame == 2 or self.current_frame == 6:
            corner_color_inner = (255, 50, 50)  # 빨간색
        else:  # 3, 7
            corner_color_inner = (255, 255, 200)  # 밝은 노란색/흰색
            
        corner_positions = [
            (x, icon_y),  # 왼쪽 위
            (x+size, icon_y),  # 오른쪽 위
            (x, icon_y+size),  # 왼쪽 아래
            (x+size, icon_y+size)  # 오른쪽 아래
        ]
        for cx, cy in corner_positions:
            # 사각형 꼭지점 (라그나로크 스타일)
            pygame.draw.rect(screen, corner_color_inner, (cx-3, cy-3, 6, 6))
    
    def draw(self, screen):
        """화면 그리기"""
        screen.fill(BACKGROUND_COLOR)
        
        # 제목
        title_font = pygame.font.Font(None, 36)
        title_text = title_font.render("포세이돈 삼지창 - 내부 디자인 추가", True, (255, 255, 255))
        screen.blit(title_text, (WIDTH//2 - title_text.get_width()//2, 30))
        
        # 큰 아이콘 그리기
        self.draw_poseidon_icon(screen, WIDTH//2 - self.icon_size//2, HEIGHT//2 - self.icon_size//2, self.icon_size)
        
        # 정보 표시
        info_font = pygame.font.Font(None, 24)
        info_texts = [
            f"프레임: {self.current_frame}/8",
            f"내부 테두리 빨간색: RGB({int(200 + 55 * math.sin(self.current_frame/8.0 * math.pi * 2))}, 0, 0)",
            "파란색 꼭지점: RGB(0, 150, 255)",
            f"글로우 강도: {self.glow_intensity:.2f}"
        ]
        
        y_offset = HEIGHT - 150
        for text in info_texts:
            text_surf = info_font.render(text, True, (200, 200, 200))
            screen.blit(text_surf, (WIDTH//2 - text_surf.get_width()//2, y_offset))
            y_offset += 30
        
        # 작은 버전들 (여러 프레임 동시 표시)
        small_size = 60
        y_small = 100
        for i in range(8):
            x_small = 50 + i * 90
            
            # 배경
            pygame.draw.rect(screen, (30, 30, 40), (x_small-5, y_small-5, small_size+10, small_size+10))
            
            # 작은 아이콘 그리기 (프레임별)
            old_frame = self.current_frame
            self.current_frame = i
            self.draw_poseidon_icon(screen, x_small, y_small, small_size)
            self.current_frame = old_frame
            
            # 프레임 번호
            frame_font = pygame.font.Font(None, 16)
            frame_text = frame_font.render(str(i), True, (255, 255, 255))
            screen.blit(frame_text, (x_small + small_size//2 - 4, y_small + small_size + 5))

def main():
    clock = pygame.time.Clock()
    test = PoseidonTest()
    running = True
    
    while running:
        dt = clock.tick(60) / 1000.0
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 스페이스바로 프레임 수동 변경
                    test.current_frame = (test.current_frame + 1) % 8
        
        test.update(dt)
        test.draw(SCREEN)
        pygame.display.flip()
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()