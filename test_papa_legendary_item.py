"""
Papa 전설 아이템 - 라그나로크 해머의 모든 효과 (해머 아이콘만 제외)
실제 라그나로크 해머와 완전히 동일한 시각 효과, 중앙 해머 이미지만 없음
"""
import pygame
import math
import sys

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1200, 800
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Papa 전설 아이템 - 라그나로크 해머 효과 (해머 제외)")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
YELLOW = (255, 215, 0)
RED = (255, 0, 0)
BLUE = (0, 100, 255)

# 폰트 설정
font_large = pygame.font.Font(None, 36)
font_medium = pygame.font.Font(None, 24)
font_small = pygame.font.Font(None, 18)

class PapaLegendaryItem:
    """Papa 아이템 - 라그나로크 해머 효과 (해머 제외)"""

    def __init__(self):
        self.animation_time = 0
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8

    def update(self, dt):
        """애니메이션 업데이트"""
        self.animation_time += dt * 0.001  # ms to seconds
        self.frame_counter += 1
        if self.frame_counter >= self.animation_speed:
            self.frame_counter = 0
            self.current_frame = (self.current_frame + 1) % 8

    def draw_icon(self, screen, x, y, size):
        """라그나로크 해머와 동일한 모든 효과 그리기 (해머 아이콘 제외)"""

        # 상하 움직임 효과 (Floating Motion)
        float_offset = math.sin(self.animation_time * 2) * 2
        y = y + float_offset

        # Layer 1: Blue Pulsing Glow (파란색 펄싱 배경)
        glow_intensity = 0.5 + 0.5 * math.sin(self.animation_time * 2)
        for i in range(3):
            radius = size // 2 - 2 - i * 3
            alpha = int(100 * glow_intensity * (1 - i * 0.3))
            glow_color = (
                min(255, 30 + i * 40),
                min(255, 90 + i * 50),
                min(255, 170 + i * 30)
            )
            if radius > 0:
                pygame.draw.circle(screen, glow_color, (x + size // 2, y + size // 2), radius)

        # Layer 2: Red Inner Borders (붉은색 내부 테두리)
        for i in range(3):
            border_alpha = 0.5 + 0.5 * math.sin(self.animation_time * 4 + i * 0.5)
            border_color = (
                int(150 + 70 * border_alpha - i * 20),
                int(20 + 20 * border_alpha - i * 10),
                int(20 + 20 * border_alpha - i * 10)
            )
            pygame.draw.rect(screen, border_color,
                           (x + 2 + i, y + 2 + i, size - 4 - i * 2, size - 4 - i * 2), 1)

        # Layer 3: 중앙에 PAPA 텍스트 표시 (해머 대신)
        text_font = pygame.font.Font(None, max(24, size // 3))
        text = text_font.render("PAPA", True, (150, 150, 255))
        text_rect = text.get_rect(center=(x + size // 2, y + size // 2))
        screen.blit(text, text_rect)

        # Layer 4: Silver-Blue Frame (은색-파란색 프레임)
        frame_color = (180, 200, 255)
        pygame.draw.rect(screen, frame_color, (x, y, size, size), 2)

        # Layer 5: Golden Corners (황금색 코너 장식)
        corner_color = (255, 215, 0)
        corner_size = 8

        # Top-left corner
        pygame.draw.lines(screen, corner_color, False,
                        [(x, y + corner_size), (x, y), (x + corner_size, y)], 2)
        pygame.draw.circle(screen, corner_color, (x + corner_size + 3, y + corner_size + 3), 2)

        # Top-right corner
        pygame.draw.lines(screen, corner_color, False,
                        [(x + size - corner_size, y), (x + size - 1, y),
                         (x + size - 1, y + corner_size)], 2)
        pygame.draw.circle(screen, corner_color, (x + size - corner_size - 3, y + corner_size + 3), 2)

        # Bottom-left corner
        pygame.draw.lines(screen, corner_color, False,
                        [(x, y + size - corner_size), (x, y + size - 1),
                         (x + corner_size, y + size - 1)], 2)
        pygame.draw.circle(screen, corner_color, (x + corner_size + 3, y + size - corner_size - 3), 2)

        # Bottom-right corner
        pygame.draw.lines(screen, corner_color, False,
                        [(x + size - corner_size, y + size - 1),
                         (x + size - 1, y + size - 1),
                         (x + size - 1, y + size - corner_size)], 2)
        pygame.draw.circle(screen, corner_color, (x + size - corner_size - 3, y + size - corner_size - 3), 2)

        # Layer 6: Red Pulsing Border (빨간색 펄싱 외곽 테두리)
        border_intensity = 0.5 + 0.5 * math.sin(self.animation_time * 3)
        border_color = (
            int(127 + 128 * border_intensity),
            0,
            0
        )
        pygame.draw.rect(screen, border_color, (x, y, size, size), 3)

        # Layer 7: Corner Dots (4개 모서리 흰점)
        for cx, cy in [(x, y), (x + size - 1, y),
                      (x, y + size - 1), (x + size - 1, y + size - 1)]:
            pygame.draw.circle(screen, WHITE, (cx, cy), 3)
            # 점 주변 글로우
            for i in range(1, 3):
                glow_alpha = 0.3 / i
                glow_color = (
                    int(255 * glow_alpha),
                    int(100 * glow_alpha),
                    int(100 * glow_alpha)
                )
                pygame.draw.circle(screen, glow_color, (cx, cy), 3 + i, 1)

def main():
    """메인 실행 함수"""
    papa_item = PapaLegendaryItem()
    clock = pygame.time.Clock()
    running = True

    # 다양한 크기로 표시
    sizes = [64, 96, 128]
    positions = [
        (200, HEIGHT // 2 - 150),
        (500, HEIGHT // 2 - 150),
        (800, HEIGHT // 2 - 150)
    ]

    while running:
        dt = clock.tick(60)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

        # 화면 클리어
        SCREEN.fill((30, 30, 50))

        # 제목
        title_text = font_large.render("Papa 전설 아이템 - 라그나로크 해머 효과 (해머 아이콘 제외)", True, WHITE)
        title_rect = title_text.get_rect(center=(WIDTH // 2, 50))
        SCREEN.blit(title_text, title_rect)

        # 설명
        desc_text = font_medium.render("모든 시각 효과는 라그나로크 해머와 동일 (중앙 해머 이미지만 없음)", True, (200, 200, 200))
        desc_rect = desc_text.get_rect(center=(WIDTH // 2, 100))
        SCREEN.blit(desc_text, desc_rect)

        # 애니메이션 업데이트
        papa_item.update(dt)

        # 다양한 크기로 아이콘 그리기
        for i, (size, pos) in enumerate(zip(sizes, positions)):
            # 아이콘 그리기
            papa_item.draw_icon(SCREEN, pos[0], pos[1], size)

            # 크기 레이블
            size_text = font_small.render(f"{size}x{size}", True, WHITE)
            size_rect = size_text.get_rect(center=(pos[0] + size // 2, pos[1] + size + 20))
            SCREEN.blit(size_text, size_rect)

        # 효과 리스트
        effects_title = font_medium.render("포함된 효과:", True, WHITE)
        SCREEN.blit(effects_title, (50, HEIGHT - 250))

        effects = [
            "1. Blue Pulsing Glow (파란색 펄싱 배경)",
            "2. Red Inner Borders (붉은색 내부 테두리)",
            "3. PAPA 텍스트 (해머 아이콘 대체)",
            "4. Silver-Blue Frame (은색-파란색 프레임)",
            "5. Golden Corners (황금색 코너 장식)",
            "6. Red Pulsing Border (빨간색 펄싱 외곽)",
            "7. Corner Dots (4개 모서리 흰점)",
            "8. Floating Motion (상하 움직임)"
        ]

        for i, effect in enumerate(effects):
            effect_text = font_small.render(effect, True, (200, 200, 200))
            SCREEN.blit(effect_text, (70, HEIGHT - 220 + i * 25))

        # 조작 안내
        info_text = font_small.render("ESC: 종료", True, (150, 150, 150))
        SCREEN.blit(info_text, (WIDTH - 100, HEIGHT - 30))

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()