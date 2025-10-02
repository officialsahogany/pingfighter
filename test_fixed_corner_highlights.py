"""
고정 코너 하이라이트 (Fixed Corner Highlights)
아이템 박스의 정확한 모서리에 위치하며 색상만 변하는 4개의 점
"""
import pygame
import math
import sys

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1200, 700
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("고정 코너 하이라이트 - 위치 고정, 색상 애니메이션")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
DARK_BG = (30, 30, 50)

# 폰트 설정
font_large = pygame.font.Font(None, 36)
font_medium = pygame.font.Font(None, 24)
font_small = pygame.font.Font(None, 18)

class FixedCornerHighlights:
    """고정 코너 하이라이트 시스템"""

    def __init__(self):
        self.animation_time = 0
        self.color_phase = 0

    def update(self, dt):
        """애니메이션 업데이트"""
        self.animation_time += dt * 0.001
        self.color_phase = (math.sin(self.animation_time * 2) + 1) / 2

    def get_current_color(self):
        """현재 애니메이션 색상 계산"""
        # 파란색 <-> 보라색 <-> 청록색으로 변화
        if self.color_phase < 0.5:
            # 파란색에서 보라색으로
            t = self.color_phase * 2
            r = int(100 + t * 100)
            g = int(150 - t * 50)
            b = 255
        else:
            # 보라색에서 청록색으로
            t = (self.color_phase - 0.5) * 2
            r = int(200 - t * 100)
            g = int(100 + t * 155)
            b = int(255 - t * 55)

        return (r, g, b)

    def draw_corner_highlights(self, screen, x, y, size, show_guide=True):
        """4개의 고정 코너 하이라이트 그리기

        Args:
            x, y: 박스의 좌상단 좌표
            size: 박스 크기
            show_guide: 가이드 박스 표시 여부
        """

        # 가이드 박스
        if show_guide:
            pygame.draw.rect(screen, (60, 60, 70), (x, y, size, size))
            pygame.draw.rect(screen, (100, 100, 120), (x, y, size, size), 1)

        # 현재 색상
        color = self.get_current_color()

        # 4개 모서리 위치 (정확히 모서리에 위치)
        corners = [
            (x, y),                      # Top-left
            (x + size - 1, y),          # Top-right
            (x, y + size - 1),          # Bottom-left
            (x + size - 1, y + size - 1) # Bottom-right
        ]

        # 각 코너에 하이라이트 그리기
        for corner_x, corner_y in corners:
            # 외부 글로우 (큰 원, 반투명)
            glow_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
            alpha = int(100 * (0.7 + 0.3 * self.color_phase))
            pygame.draw.circle(glow_surf, (*color, alpha), (10, 10), 8)
            screen.blit(glow_surf, (corner_x - 10, corner_y - 10))

            # 중간 링
            pygame.draw.circle(screen, color, (corner_x, corner_y), 4, 1)

            # 중심 밝은 점
            bright_color = tuple(min(255, c + 50) for c in color)
            pygame.draw.circle(screen, bright_color, (corner_x, corner_y), 2)

    def draw_with_labels(self, screen, x, y, size):
        """라벨과 함께 하이라이트 표시"""

        # 배경
        pygame.draw.rect(screen, (40, 40, 50), (x - 30, y - 30, size + 60, size + 60))

        # 코너 하이라이트
        self.draw_corner_highlights(screen, x, y, size, show_guide=True)

        # 라벨
        color = self.get_current_color()
        color_text = f"RGB({color[0]}, {color[1]}, {color[2]})"

        # 색상 정보
        info = font_small.render(color_text, True, WHITE)
        info_rect = info.get_rect(center=(x + size // 2, y - 10))
        screen.blit(info, info_rect)

        # 코너 라벨
        corner_labels = [
            ("TL", x - 20, y - 20),
            ("TR", x + size + 5, y - 20),
            ("BL", x - 20, y + size + 5),
            ("BR", x + size + 5, y + size + 5)
        ]

        for label, lx, ly in corner_labels:
            text = font_small.render(label, True, (150, 150, 150))
            screen.blit(text, (lx, ly))

    def draw_comparison(self, screen):
        """여러 크기로 비교 표시"""

        sizes = [60, 80, 100, 120]
        start_x = 100
        y = 200

        for i, size in enumerate(sizes):
            x = start_x + i * 180

            # 크기 라벨
            size_label = font_small.render(f"{size}x{size}", True, WHITE)
            label_rect = size_label.get_rect(center=(x + size // 2, y - 20))
            screen.blit(size_label, label_rect)

            # 하이라이트 그리기
            self.draw_corner_highlights(screen, x, y, size, show_guide=True)

    def draw_animation_phases(self, screen):
        """애니메이션 단계별 표시"""

        phases = [0, 0.25, 0.5, 0.75, 1.0]
        y = 400
        size = 80

        for i, phase in enumerate(phases):
            x = 100 + i * 200

            # 임시로 color_phase 설정
            old_phase = self.color_phase
            self.color_phase = phase

            # 단계 라벨
            phase_label = font_small.render(f"Phase {phase:.2f}", True, WHITE)
            label_rect = phase_label.get_rect(center=(x + size // 2, y - 20))
            screen.blit(phase_label, label_rect)

            # 해당 단계의 색상으로 그리기
            self.draw_corner_highlights(screen, x, y, size, show_guide=True)

            # 색상 정보
            color = self.get_current_color()
            color_text = font_small.render(f"({color[0]}, {color[1]}, {color[2]})", True, (180, 180, 180))
            color_rect = color_text.get_rect(center=(x + size // 2, y + size + 20))
            screen.blit(color_text, color_rect)

            # 원래 phase 복원
            self.color_phase = old_phase

def main():
    """메인 실행 함수"""
    highlights = FixedCornerHighlights()
    clock = pygame.time.Clock()
    running = True

    show_animation = True
    show_phases = False

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
                elif event.key == pygame.K_p:
                    show_phases = not show_phases

        # 화면 클리어
        SCREEN.fill(DARK_BG)

        # 제목
        title = font_large.render("고정 코너 하이라이트 (Fixed Corner Highlights)", True, WHITE)
        title_rect = title.get_rect(center=(WIDTH // 2, 40))
        SCREEN.blit(title, title_rect)

        # 설명
        desc = font_medium.render("아이템 박스 모서리에 고정, 색상만 애니메이션", True, (200, 200, 200))
        desc_rect = desc.get_rect(center=(WIDTH // 2, 80))
        SCREEN.blit(desc, desc_rect)

        # 애니메이션 업데이트
        if show_animation:
            highlights.update(dt)

        # 메인 디스플레이 (크게)
        main_size = 200
        main_x = WIDTH // 2 - main_size // 2
        main_y = 120

        highlights.draw_with_labels(SCREEN, main_x, main_y, main_size)

        # 여러 크기 비교
        highlights.draw_comparison(SCREEN)

        # 애니메이션 단계
        if show_phases:
            highlights.draw_animation_phases(SCREEN)

        # 정보 표시
        info_y = HEIGHT - 100
        info_lines = [
            "특징: 위치 고정, 색상만 변화",
            "색상: 파란색 → 보라색 → 청록색",
            "위치: 정확히 박스 모서리 (x, y), (x+size-1, y), (x, y+size-1), (x+size-1, y+size-1)",
            f"현재 Phase: {highlights.color_phase:.2f}"
        ]

        for i, line in enumerate(info_lines):
            info_text = font_small.render(line, True, (180, 180, 180))
            SCREEN.blit(info_text, (50, info_y + i * 20))

        # 조작 안내
        control = font_small.render("SPACE: 애니메이션 On/Off | P: 단계별 표시 | ESC: 종료", True, (150, 150, 150))
        control_rect = control.get_rect(center=(WIDTH // 2, HEIGHT - 20))
        SCREEN.blit(control, control_rect)

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()