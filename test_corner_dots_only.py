"""
황금색 코너 점 (Golden Corner Dots) - 4개 모서리 점만 표시
라그나로크 해머의 코너 점 요소만 분리
"""
import pygame
import math
import sys

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 800, 600
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("황금색 코너 점 (Golden Corner Dots)")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
GOLDEN = (255, 215, 0)  # 황금색
GRAY = (100, 100, 100)
RED = (255, 100, 100)

# 폰트 설정
font_large = pygame.font.Font(None, 36)
font_medium = pygame.font.Font(None, 24)
font_small = pygame.font.Font(None, 18)

class CornerDots:
    """코너 점 시각화 클래스"""

    def __init__(self):
        self.animation_time = 0
        self.pulse_effect = 0

    def update(self, dt):
        """애니메이션 업데이트"""
        self.animation_time += dt * 0.001
        self.pulse_effect = (math.sin(self.animation_time * 3) + 1) / 2

    def draw_corner_dots(self, screen, x, y, size, dot_radius=2, color=GOLDEN, show_guide=False):
        """4개 모서리에 황금색 점 그리기

        Args:
            screen: 화면
            x, y: 사각형 좌상단 좌표
            size: 사각형 크기
            dot_radius: 점 반경 (기본 2픽셀)
            color: 점 색상 (기본 황금색)
            show_guide: 가이드라인 표시 여부
        """

        # 가이드 박스 (선택적)
        if show_guide:
            pygame.draw.rect(screen, GRAY, (x, y, size, size), 1)

        # 4개 모서리 위치 정의
        corners = [
            (x, y),                    # Top-left (왼쪽 위)
            (x + size, y),            # Top-right (오른쪽 위)
            (x, y + size),            # Bottom-left (왼쪽 아래)
            (x + size, y + size)      # Bottom-right (오른쪽 아래)
        ]

        # 각 모서리에 점 그리기
        for i, (cx, cy) in enumerate(corners):
            # 메인 점
            pygame.draw.circle(screen, color, (cx, cy), dot_radius)

            # 글로우 효과 (선택적)
            if self.pulse_effect > 0.5:
                glow_alpha = int((self.pulse_effect - 0.5) * 100)
                glow_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*color, glow_alpha), (10, 10), 6)
                screen.blit(glow_surf, (cx - 10, cy - 10))

    def draw_corner_dots_with_details(self, screen, x, y, size):
        """상세 정보와 함께 코너 점 그리기"""

        # 배경 박스
        pygame.draw.rect(screen, (40, 40, 50), (x - 20, y - 20, size + 40, size + 40))

        # 가이드 사각형
        pygame.draw.rect(screen, GRAY, (x, y, size, size), 1)

        # 4개 코너 점
        corners = [
            {"pos": (x, y), "name": "Top-Left", "label_pos": (-30, -25)},
            {"pos": (x + size, y), "name": "Top-Right", "label_pos": (10, -25)},
            {"pos": (x, y + size), "name": "Bottom-Left", "label_pos": (-40, 10)},
            {"pos": (x + size, y + size), "name": "Bottom-Right", "label_pos": (10, 10)}
        ]

        for corner in corners:
            cx, cy = corner["pos"]

            # 점 그리기
            pygame.draw.circle(screen, GOLDEN, (cx, cy), 2)

            # 확대된 버전 (시각화용)
            zoom_x = cx + corner["label_pos"][0]
            zoom_y = cy + corner["label_pos"][1]

            # 확대 원 배경
            pygame.draw.circle(screen, (60, 60, 70), (zoom_x, zoom_y), 8)
            pygame.draw.circle(screen, GRAY, (zoom_x, zoom_y), 8, 1)

            # 확대된 점
            pygame.draw.circle(screen, GOLDEN, (zoom_x, zoom_y), 4)

            # 연결선
            pygame.draw.line(screen, (100, 100, 100), (cx, cy), (zoom_x, zoom_y), 1)

def main():
    """메인 실행 함수"""
    dots = CornerDots()
    clock = pygame.time.Clock()
    running = True

    show_animation = True

    while running:
        dt = clock.tick(60)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    show_animation = not show_animation

        # 화면 클리어
        SCREEN.fill((30, 30, 50))

        # 제목
        title = font_large.render("황금색 코너 점 (Golden Corner Dots)", True, WHITE)
        title_rect = title.get_rect(center=(WIDTH // 2, 40))
        SCREEN.blit(title, title_rect)

        # 설명
        desc = font_medium.render("라그나로크 해머 - 4개 모서리 점", True, (200, 200, 200))
        desc_rect = desc.get_rect(center=(WIDTH // 2, 80))
        SCREEN.blit(desc, desc_rect)

        # 애니메이션 업데이트
        if show_animation:
            dots.update(dt)

        # 다양한 크기로 표시
        sizes = [60, 80, 100, 120]
        positions = [
            (100, 150),
            (250, 150),
            (400, 150),
            (550, 150)
        ]

        for size, pos in zip(sizes, positions):
            # 크기 레이블
            size_label = font_small.render(f"{size}x{size}", True, WHITE)
            label_rect = size_label.get_rect(center=(pos[0] + size // 2, pos[1] - 20))
            SCREEN.blit(size_label, label_rect)

            # 코너 점 그리기
            dots.draw_corner_dots(SCREEN, pos[0], pos[1], size, show_guide=True)

        # 상세 뷰 (큰 크기)
        detail_size = 200
        detail_x = WIDTH // 2 - detail_size // 2
        detail_y = 320

        # 상세 뷰 제목
        detail_title = font_medium.render("상세 뷰 (확대)", True, GOLDEN)
        detail_rect = detail_title.get_rect(center=(WIDTH // 2, detail_y - 30))
        SCREEN.blit(detail_title, detail_rect)

        # 상세 코너 점
        dots.draw_corner_dots_with_details(SCREEN, detail_x, detail_y, detail_size)

        # 정보 표시
        info_y = HEIGHT - 80
        info_lines = [
            "색상: RGB(255, 215, 0) - 황금색",
            "크기: 반경 2픽셀",
            "위치: 정확히 모서리 꼭짓점",
            "개수: 4개 (각 모서리)"
        ]

        for i, line in enumerate(info_lines):
            info_text = font_small.render(line, True, (180, 180, 180))
            SCREEN.blit(info_text, (50 + (i % 2) * 350, info_y + (i // 2) * 25))

        # 조작 안내
        control = font_small.render("ESC: 종료 | SPACE: 애니메이션 On/Off", True, (150, 150, 150))
        control_rect = control.get_rect(center=(WIDTH // 2, HEIGHT - 20))
        SCREEN.blit(control, control_rect)

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()