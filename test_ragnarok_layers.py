import pygame
import sys
import math

# 초기화
pygame.init()
WIDTH, HEIGHT = 1200, 800
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("라그나로크 해머 - 레이어별 분리 시각화")

# 색상 정의
BACKGROUND_COLOR = (20, 20, 40)
LEGENDARY_COLOR = (255, 0, 0)
GOLDEN_COLOR = (255, 215, 0)
BOLT_COLOR = (255, 255, 150)

class RagnarokVisualization:
    def __init__(self):
        self.icon_size = 60
        self.glow_intensity = 0.5
        self.glow_direction = 1
        self.animation_offset = 0
        self.animation_time = 0
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8
        self.selected_layer = 0  # 현재 선택된 레이어
        self.show_all = False  # 모든 레이어 표시 여부
        
        # 가상의 프레임들 (색상으로 대체)
        self.frame_colors = [
            (200, 50, 50),   # Frame 0 - 어두운 빨강
            (50, 200, 50),   # Frame 1 - 초록
            (50, 50, 200),   # Frame 2 - 파랑
            (200, 200, 50),  # Frame 3 - 노랑
            (200, 50, 200),  # Frame 4 - 보라
            (50, 200, 200),  # Frame 5 - 청록
            (200, 100, 50),  # Frame 6 - 주황
            (100, 100, 100), # Frame 7 - 회색
        ]
        
        self.layer_names = [
            "1. 글로우 효과 (최하단)",
            "2. 외부 테두리",
            "3. 황금색 코너 장식",
            "4. 코너 점 장식",
            "5. 애니메이션 아이콘",
            "6. 번개 효과 (최상단)"
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
        
        # 프레임 카운터
        self.frame_counter += 1
        if self.frame_counter >= self.animation_speed:
            self.frame_counter = 0
            self.current_frame = (self.current_frame + 1) % 8
    
    def draw_layer_1(self, screen, x, y):
        """레이어 1: 글로우 효과"""
        hammer_glow_multiplier = 1.8
        glow_size = int(self.icon_size * (hammer_glow_multiplier + self.glow_intensity * 0.15))
        glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
        
        # 5개의 동심원
        for i in range(5):
            alpha = 80 - i * 12
            radius = glow_size//2 - i * 4
            if radius > 0:
                pygame.draw.circle(glow_surf, (*LEGENDARY_COLOR, alpha), 
                                 (glow_size//2, glow_size//2), radius)
        
        screen.blit(glow_surf, (x - (glow_size - self.icon_size)//2, 
                               y - (glow_size - self.icon_size)//2))
    
    def draw_layer_2(self, screen, x, y):
        """레이어 2: 외부 테두리"""
        border_thickness = 3 + int(self.glow_intensity * 3)
        border_rect = pygame.Rect(x-2, y-2, self.icon_size+4, self.icon_size+4)
        pygame.draw.rect(screen, LEGENDARY_COLOR, border_rect, border_thickness)
    
    def draw_layer_3(self, screen, x, y):
        """레이어 3: 황금색 코너 장식"""
        corner_size = 8
        size = self.icon_size
        
        # 왼쪽 위
        pygame.draw.lines(screen, GOLDEN_COLOR, False, 
                         [(x-2, y+corner_size), (x-2, y-2), (x+corner_size, y-2)], 2)
        # 오른쪽 위
        pygame.draw.lines(screen, GOLDEN_COLOR, False,
                         [(x+size-corner_size+2, y-2), (x+size+2, y-2), 
                          (x+size+2, y+corner_size)], 2)
        # 왼쪽 아래
        pygame.draw.lines(screen, GOLDEN_COLOR, False,
                         [(x-2, y+size-corner_size+2), (x-2, y+size+2), 
                          (x+corner_size, y+size+2)], 2)
        # 오른쪽 아래
        pygame.draw.lines(screen, GOLDEN_COLOR, False,
                         [(x+size-corner_size+2, y+size+2), (x+size+2, y+size+2), 
                          (x+size+2, y+size-corner_size+2)], 2)
    
    def draw_layer_4(self, screen, x, y):
        """레이어 4: 코너 점 장식"""
        size = self.icon_size
        for cx, cy in [(x, y), (x+size, y), (x, y+size), (x+size, y+size)]:
            pygame.draw.circle(screen, LEGENDARY_COLOR, (cx, cy), 3)
            pygame.draw.circle(screen, GOLDEN_COLOR, (cx, cy), 2)
    
    def draw_layer_5(self, screen, x, y):
        """레이어 5: 애니메이션 아이콘"""
        icon_y = y + int(self.animation_offset)
        
        # 프레임 색상으로 대체
        frame_color = self.frame_colors[self.current_frame]
        pygame.draw.rect(screen, frame_color, 
                        (x, icon_y, self.icon_size, self.icon_size))
        
        # 프레임 번호 표시
        font = pygame.font.Font(None, 24)
        frame_text = font.render(str(self.current_frame), True, (255, 255, 255))
        text_rect = frame_text.get_rect(center=(x + self.icon_size//2, 
                                               icon_y + self.icon_size//2))
        screen.blit(frame_text, text_rect)
    
    def draw_layer_6(self, screen, x, y):
        """레이어 6: 번개 효과"""
        if self.current_frame in [0, 4]:
            size = self.icon_size
            # 첫 번째 번개
            pygame.draw.line(screen, BOLT_COLOR, 
                           (x + size//4, y - 5), 
                           (x + size//3, y + size//4), 2)
            # 두 번째 번개
            pygame.draw.line(screen, BOLT_COLOR,
                           (x + size*3//4, y - 5),
                           (x + size*2//3, y + size//4), 2)
    
    def draw(self, screen):
        """메인 그리기 함수"""
        screen.fill(BACKGROUND_COLOR)
        
        # 제목
        title_font = pygame.font.Font(None, 36)
        title_text = title_font.render("라그나로크 해머 - 레이어별 분리 시각화", True, (255, 255, 255))
        screen.blit(title_text, (WIDTH//2 - title_text.get_width()//2, 20))
        
        # 레이어 선택 메뉴
        menu_font = pygame.font.Font(None, 24)
        y_menu = 80
        for i, name in enumerate(self.layer_names):
            color = (255, 255, 0) if i == self.selected_layer else (200, 200, 200)
            if self.show_all:
                color = (150, 255, 150)
            text = menu_font.render(f"[{i+1}] {name}", True, color)
            screen.blit(text, (50, y_menu + i * 30))
        
        # 모든 레이어 표시 옵션
        all_text = menu_font.render("[A] 모든 레이어 표시", True, 
                                   (150, 255, 150) if self.show_all else (200, 200, 200))
        screen.blit(all_text, (50, y_menu + len(self.layer_names) * 30 + 20))
        
        # 개별 레이어 그리기
        if not self.show_all:
            # 단일 레이어만 표시
            x = WIDTH // 2 - self.icon_size // 2
            y = HEIGHT // 2 - self.icon_size // 2
            
            # 참조 박스
            pygame.draw.rect(screen, (50, 50, 50), 
                           (x-10, y-10, self.icon_size+20, self.icon_size+20), 1)
            
            # 선택된 레이어 그리기
            if self.selected_layer == 0:
                self.draw_layer_1(screen, x, y)
            elif self.selected_layer == 1:
                self.draw_layer_2(screen, x, y)
            elif self.selected_layer == 2:
                self.draw_layer_3(screen, x, y)
            elif self.selected_layer == 3:
                self.draw_layer_4(screen, x, y)
            elif self.selected_layer == 4:
                self.draw_layer_5(screen, x, y)
            elif self.selected_layer == 5:
                self.draw_layer_6(screen, x, y)
            
            # 레이어 설명
            desc_y = y + self.icon_size + 50
            desc_font = pygame.font.Font(None, 20)
            
            descriptions = [
                ["크기: 아이콘의 1.8배 + 펄싱(0.15배)", 
                 "동심원: 5개", 
                 "알파값: 80→68→56→44→32",
                 "색상: RGB(255, 0, 0)"],
                ["색상: 붉은색 (255, 0, 0)",
                 f"두께: 3 + {self.glow_intensity:.1f} × 3 = {3 + int(self.glow_intensity * 3)}px",
                 "위치: (x-2, y-2, size+4, size+4)"],
                ["색상: 황금색 (255, 215, 0)",
                 "길이: 8픽셀",
                 "두께: 2픽셀",
                 "위치: 각 모서리"],
                ["외부 원: 붉은색, 반지름 3",
                 "내부 원: 황금색, 반지름 2",
                 "위치: 정확히 모서리 끝점"],
                [f"현재 프레임: {self.current_frame}/8",
                 f"부유 효과: {self.animation_offset:.1f}px",
                 "프레임 속도: 8틱 (133ms)",
                 "순환: 0→1→2→3→4→5→6→7→0"],
                ["트리거: 프레임 0, 4",
                 "색상: 밝은 노랑 (255, 255, 150)",
                 "개수: 2개",
                 "위치: 상단에서 대각선"]
            ]
            
            for desc in descriptions[self.selected_layer]:
                text = desc_font.render(desc, True, (180, 180, 180))
                screen.blit(text, (WIDTH//2 - text.get_width()//2, desc_y))
                desc_y += 25
        
        else:
            # 모든 레이어 순차적으로 표시
            x_start = 100
            y_center = HEIGHT // 2
            x_gap = 180
            
            for i in range(6):
                x = x_start + i * x_gap
                y = y_center - self.icon_size // 2
                
                # 배경 박스
                pygame.draw.rect(screen, (30, 30, 40), 
                               (x-20, y-80, self.icon_size+40, self.icon_size+120))
                pygame.draw.rect(screen, (50, 50, 60), 
                               (x-20, y-80, self.icon_size+40, self.icon_size+120), 1)
                
                # 레이어 번호
                layer_font = pygame.font.Font(None, 20)
                layer_text = layer_font.render(f"Layer {i+1}", True, (255, 255, 255))
                screen.blit(layer_text, (x + self.icon_size//2 - layer_text.get_width()//2, y-60))
                
                # 각 레이어 그리기
                if i == 0:
                    self.draw_layer_1(screen, x, y)
                elif i == 1:
                    self.draw_layer_2(screen, x, y)
                elif i == 2:
                    self.draw_layer_3(screen, x, y)
                elif i == 3:
                    self.draw_layer_4(screen, x, y)
                elif i == 4:
                    self.draw_layer_5(screen, x, y)
                elif i == 5:
                    self.draw_layer_6(screen, x, y)
                
                # 레이어 이름
                name_parts = self.layer_names[i].split(" ", 1)
                if len(name_parts) > 1:
                    name_text = layer_font.render(name_parts[1], True, (180, 180, 180))
                    screen.blit(name_text, (x + self.icon_size//2 - name_text.get_width()//2, y+70))
        
        # 정보 표시
        info_font = pygame.font.Font(None, 20)
        info_texts = [
            f"Glow Intensity: {self.glow_intensity:.2f}",
            f"Current Frame: {self.current_frame}",
            f"Animation Offset: {self.animation_offset:.1f}px",
            "Press 1-6: Select Layer | A: Show All | ESC: Exit"
        ]
        
        y_info = HEIGHT - 100
        for text in info_texts:
            info_surface = info_font.render(text, True, (150, 150, 150))
            screen.blit(info_surface, (WIDTH//2 - info_surface.get_width()//2, y_info))
            y_info += 20

def main():
    clock = pygame.time.Clock()
    visualizer = RagnarokVisualization()
    running = True
    
    while running:
        dt = clock.tick(60) / 1000.0  # 델타 타임 (초)
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_1:
                    visualizer.selected_layer = 0
                    visualizer.show_all = False
                elif event.key == pygame.K_2:
                    visualizer.selected_layer = 1
                    visualizer.show_all = False
                elif event.key == pygame.K_3:
                    visualizer.selected_layer = 2
                    visualizer.show_all = False
                elif event.key == pygame.K_4:
                    visualizer.selected_layer = 3
                    visualizer.show_all = False
                elif event.key == pygame.K_5:
                    visualizer.selected_layer = 4
                    visualizer.show_all = False
                elif event.key == pygame.K_6:
                    visualizer.selected_layer = 5
                    visualizer.show_all = False
                elif event.key == pygame.K_a:
                    visualizer.show_all = not visualizer.show_all
        
        visualizer.update(dt)
        visualizer.draw(SCREEN)
        pygame.display.flip()
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()