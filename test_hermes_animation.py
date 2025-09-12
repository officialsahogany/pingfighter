import pygame
import sys
import math

# 초기화
pygame.init()
WIDTH, HEIGHT = 1000, 700
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("헤르메스의 신발 - 애니메이션 분석")

# 색상 정의
BACKGROUND_COLOR = (20, 20, 40)
LEGENDARY_COLOR = (255, 0, 0)
GOLDEN_COLOR = (255, 215, 0)

class HermesVisualization:
    def __init__(self):
        self.icon_size = 60
        self.glow_intensity = 0.5
        self.glow_direction = 1
        self.animation_offset = 0
        self.animation_time = 0
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 4  # 헤르메스는 더 빠름 (4틱)
        self.hermes_glow_multiplier = 1.8  # 라그나로크와 동일
        
        # 가상의 프레임들 (색상으로 대체)
        self.frame_colors = [
            (100, 200, 255),  # Frame 0 - 하늘색
            (150, 220, 255),  # Frame 1 - 밝은 하늘색
            (200, 240, 255),  # Frame 2 - 더 밝은 하늘색
            (255, 255, 255),  # Frame 3 - 흰색
            (255, 240, 200),  # Frame 4 - 밝은 노랑
            (255, 220, 150),  # Frame 5 - 노랑
            (200, 200, 255),  # Frame 6 - 연한 보라
            (150, 180, 255),  # Frame 7 - 진한 하늘색
        ]
    
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
        
        # 프레임 카운터 (헤르메스는 더 빠름)
        self.frame_counter += 1
        if self.frame_counter >= self.animation_speed:
            self.frame_counter = 0
            self.current_frame = (self.current_frame + 1) % 8
    
    def draw_comparison(self, screen):
        """헤르메스 vs 라그나로크 비교"""
        screen.fill(BACKGROUND_COLOR)
        
        # 제목
        title_font = pygame.font.Font(None, 36)
        title_text = title_font.render("헤르메스의 신발 vs 라그나로크 해머", True, (255, 255, 255))
        screen.blit(title_text, (WIDTH//2 - title_text.get_width()//2, 20))
        
        # 헤르메스 (왼쪽)
        hermes_x = WIDTH//4 - self.icon_size//2
        hermes_y = HEIGHT//2 - self.icon_size//2
        self.draw_hermes_icon(screen, hermes_x, hermes_y)
        
        # 라그나로크 (오른쪽)
        ragnarok_x = WIDTH*3//4 - self.icon_size//2
        ragnarok_y = HEIGHT//2 - self.icon_size//2
        self.draw_ragnarok_icon(screen, ragnarok_x, ragnarok_y)
        
        # 비교 정보
        info_font = pygame.font.Font(None, 24)
        y_info = HEIGHT//2 + 100
        
        # 헤르메스 정보
        hermes_info = [
            "헤르메스의 신발",
            f"프레임: {self.current_frame}/8",
            "속도: 4틱 (빠름)",
            "특수효과: 없음",
            "글로우: 1.8x"
        ]
        for i, text in enumerate(hermes_info):
            color = (100, 200, 255) if i == 0 else (200, 200, 200)
            text_surf = info_font.render(text, True, color)
            screen.blit(text_surf, (WIDTH//4 - text_surf.get_width()//2, y_info + i*25))
        
        # 라그나로크 정보
        ragnarok_info = [
            "라그나로크 해머",
            f"프레임: {self.current_frame}/8",
            "속도: 8틱 (보통)",
            "특수효과: 번개",
            "글로우: 1.8x"
        ]
        for i, text in enumerate(ragnarok_info):
            color = (255, 100, 100) if i == 0 else (200, 200, 200)
            text_surf = info_font.render(text, True, color)
            screen.blit(text_surf, (WIDTH*3//4 - text_surf.get_width()//2, y_info + i*25))
        
        # 애니메이션 속도 비교 바
        bar_y = HEIGHT - 100
        bar_height = 20
        
        # 헤르메스 속도 바
        pygame.draw.rect(screen, (50, 50, 50), (100, bar_y, 300, bar_height))
        hermes_progress = (self.frame_counter / self.animation_speed) * 300
        pygame.draw.rect(screen, (100, 200, 255), (100, bar_y, hermes_progress, bar_height))
        
        # 라그나로크 속도 바 (시뮬레이션)
        ragnarok_speed = 8
        ragnarok_progress = (self.frame_counter / ragnarok_speed) * 300
        pygame.draw.rect(screen, (50, 50, 50), (500, bar_y, 300, bar_height))
        pygame.draw.rect(screen, (255, 100, 100), (500, bar_y, min(300, ragnarok_progress), bar_height))
        
        # 속도 라벨
        speed_label = info_font.render("애니메이션 속도 비교", True, (255, 255, 255))
        screen.blit(speed_label, (WIDTH//2 - speed_label.get_width()//2, bar_y - 30))
    
    def draw_hermes_icon(self, screen, x, y):
        """헤르메스 아이콘 그리기"""
        size = self.icon_size
        
        # 1. 글로우 효과
        glow_size = int(size * (self.hermes_glow_multiplier + self.glow_intensity * 0.15))
        glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
        for i in range(5):
            alpha = 80 - i * 12
            pygame.draw.circle(glow_surf, (*LEGENDARY_COLOR, alpha), 
                             (glow_size//2, glow_size//2), 
                             glow_size//2 - i * 4)
        screen.blit(glow_surf, (x - (glow_size - size)//2, y - (glow_size - size)//2))
        
        # 2. 외부 테두리
        border_thickness = 3 + int(self.glow_intensity * 3)
        border_rect = pygame.Rect(x-2, y-2, size+4, size+4)
        pygame.draw.rect(screen, LEGENDARY_COLOR, border_rect, border_thickness)
        
        # 3. 황금색 코너 장식
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
        
        # 4. 코너 점 장식
        for cx, cy in [(x, y), (x+size, y), (x, y+size), (x+size, y+size)]:
            pygame.draw.circle(screen, LEGENDARY_COLOR, (cx, cy), 3)
            pygame.draw.circle(screen, GOLDEN_COLOR, (cx, cy), 2)
        
        # 5. 애니메이션 아이콘 (부유 효과 포함)
        icon_y = y + int(self.animation_offset)
        frame_color = self.frame_colors[self.current_frame]
        pygame.draw.rect(screen, frame_color, (x, icon_y, size, size))
        
        # 신발 모양 그리기
        shoe_color = (255, 255, 255)
        pygame.draw.ellipse(screen, shoe_color, (x+size//4, icon_y+size//2, size//2, size//4))
        
        # 날개 그리기
        wing_offset = math.sin(self.animation_time * 10) * 2
        # 왼쪽 날개
        pygame.draw.polygon(screen, (255, 255, 200), 
                          [(x+size//4-5+wing_offset, icon_y+size//2),
                           (x+size//4-10+wing_offset, icon_y+size//2-5),
                           (x+size//4, icon_y+size//2)])
        # 오른쪽 날개
        pygame.draw.polygon(screen, (255, 255, 200),
                          [(x+size*3//4+5-wing_offset, icon_y+size//2),
                           (x+size*3//4+10-wing_offset, icon_y+size//2-5),
                           (x+size*3//4, icon_y+size//2)])
        
        # 프레임 번호
        font = pygame.font.Font(None, 16)
        frame_text = font.render(f"F{self.current_frame}", True, (0, 0, 0))
        screen.blit(frame_text, (x+size//2-10, icon_y+size//2-8))
    
    def draw_ragnarok_icon(self, screen, x, y):
        """라그나로크 아이콘 그리기 (비교용)"""
        size = self.icon_size
        
        # 동일한 글로우 효과
        glow_size = int(size * (1.8 + self.glow_intensity * 0.15))
        glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
        for i in range(5):
            alpha = 80 - i * 12
            pygame.draw.circle(glow_surf, (*LEGENDARY_COLOR, alpha), 
                             (glow_size//2, glow_size//2), 
                             glow_size//2 - i * 4)
        screen.blit(glow_surf, (x - (glow_size - size)//2, y - (glow_size - size)//2))
        
        # 동일한 테두리와 장식
        border_thickness = 3 + int(self.glow_intensity * 3)
        border_rect = pygame.Rect(x-2, y-2, size+4, size+4)
        pygame.draw.rect(screen, LEGENDARY_COLOR, border_rect, border_thickness)
        
        # 황금색 코너 (동일)
        corner_size = 8
        # 코너 그리기 (코드 생략 - 헤르메스와 동일)
        
        # 애니메이션 아이콘
        icon_y = y + int(self.animation_offset)
        hammer_color = (150, 150, 150)
        # 해머 머리
        pygame.draw.rect(screen, hammer_color, (x+size//4, icon_y+size//4, size//2, size//3))
        # 해머 손잡이
        pygame.draw.rect(screen, (100, 50, 0), (x+size//2-5, icon_y+size//2, 10, size//3))
        
        # 번개 효과 (프레임 0, 4에서만)
        if self.current_frame in [0, 4]:
            bolt_color = (255, 255, 150)
            pygame.draw.line(screen, bolt_color, (x+size//4, y-5), (x+size//3, y+size//4), 2)
            pygame.draw.line(screen, bolt_color, (x+size*3//4, y-5), (x+size*2//3, y+size//4), 2)

def main():
    clock = pygame.time.Clock()
    visualizer = HermesVisualization()
    running = True
    
    while running:
        dt = clock.tick(60) / 1000.0
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
        
        visualizer.update(dt)
        visualizer.draw_comparison(SCREEN)
        pygame.display.flip()
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()