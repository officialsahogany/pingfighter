"""
내부 테두리 모서리 장식 테스트
포세이돈의 삼지창과 동일한 스타일 구현
"""
import pygame
import math
import sys

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1200, 800
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("내부 테두리 모서리 장식 테스트")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
YELLOW = (255, 215, 0)
RED = (255, 0, 0)
BLUE = (0, 100, 255)
SILVER_BLUE = (180, 200, 255)
INNER_CORNER_BLUE = (100, 150, 200)  # 내부 모서리 파란색

# 폰트 설정
font_large = pygame.font.Font(None, 36)
font_medium = pygame.font.Font(None, 24)
font_small = pygame.font.Font(None, 18)

class InnerCornerTest:
    """내부 모서리 장식 테스트"""

    def __init__(self):
        self.animation_time = 0
        self.glow_intensity = 0
        self.animation_offset = 0

    def update(self, dt):
        """애니메이션 업데이트"""
        self.animation_time += dt

        # 글로우 효과 업데이트
        self.glow_intensity = abs(math.sin(self.animation_time * 2)) * 0.5 + 0.5

        # 상하 움직임
        self.animation_offset = math.sin(self.animation_time * 2.5) * 2

    def draw_common_legendary_frame(self, surface, x, y, size):
        """공통 전설 프레임 그리기"""
        center_x = x + size // 2
        center_y = y + size // 2
        frame_offset = int(self.animation_offset)

        # 1. 파란색 원형 글로우 (3층)
        glow_alpha = int(100 * self.glow_intensity)
        for i in range(3):
            radius = size // 2 + 10 + (3-i) * 8
            glow_surf = pygame.Surface((radius*2, radius*2), pygame.SRCALPHA)
            alpha = glow_alpha // (i+1)
            color = (*BLUE, alpha)
            pygame.draw.circle(glow_surf, color, (radius, radius), radius)
            surface.blit(glow_surf, (center_x - radius, center_y - radius + frame_offset))

        # 2. 붉은색 내부 테두리 (3중) - 상하 움직임
        for i in range(3):
            border_size = size - i * 4
            border_rect = pygame.Rect(
                center_x - border_size // 2,
                center_y - border_size // 2 + frame_offset,
                border_size,
                border_size
            )
            alpha = 200 - i * 50
            border_color = (*RED, alpha)

            # 모서리가 둥근 사각형
            border_surf = pygame.Surface((border_size, border_size), pygame.SRCALPHA)
            pygame.draw.rect(border_surf, border_color,
                           (0, 0, border_size, border_size),
                           2, border_radius=8)
            surface.blit(border_surf, border_rect.topleft)

        # 3. 은색-파란색 외곽 프레임
        frame_size = size + 12
        frame_rect = pygame.Rect(
            center_x - frame_size // 2,
            center_y - frame_size // 2,
            frame_size,
            frame_size
        )

        # 은색 기본 프레임
        pygame.draw.rect(surface, (192, 192, 192), frame_rect, 3, border_radius=10)

        # 파란색 하이라이트
        highlight_surf = pygame.Surface((frame_size, frame_size), pygame.SRCALPHA)
        pygame.draw.rect(highlight_surf, (100, 150, 255, 100),
                        (0, 0, frame_size, frame_size),
                        2, border_radius=10)
        surface.blit(highlight_surf, frame_rect.topleft)

        # 4. 황금색 코너 장식
        corner_size = 12
        corners = [
            (frame_rect.left + 5, frame_rect.top + 5),      # 좌상
            (frame_rect.right - 5 - corner_size, frame_rect.top + 5),     # 우상
            (frame_rect.left + 5, frame_rect.bottom - 5 - corner_size),   # 좌하
            (frame_rect.right - 5 - corner_size, frame_rect.bottom - 5 - corner_size)  # 우하
        ]

        for corner_x, corner_y in corners:
            # L자 모양 코너
            pygame.draw.lines(surface, YELLOW, False, [
                (corner_x, corner_y + corner_size),
                (corner_x, corner_y),
                (corner_x + corner_size, corner_y)
            ], 3)

            # 코너에 작은 점
            pygame.draw.circle(surface, YELLOW,
                             (corner_x + corner_size//2, corner_y + corner_size//2),
                             2)

        return frame_offset

    def draw_inner_corner_decorations(self, surface, x, y, size, style="poseidon"):
        """내부 테두리의 모서리 장식"""
        frame_offset = int(self.animation_offset)

        if style == "poseidon":
            # 포세이돈 스타일: 파란~은색 사각형
            corner_color = INNER_CORNER_BLUE
            corner_size = max(4, size // 15)
            offset = 3
        elif style == "dynamic":
            # 동적 스타일: 색상이 변하는 사각형
            pulse = abs(math.sin(self.animation_time * 3))
            corner_color = (
                int(100 + 50 * pulse),
                int(150 + 50 * pulse),
                int(200 + 55 * pulse)
            )
            corner_size = max(4, size // 15 + int(pulse * 2))
            offset = 3
        else:
            # 기본 스타일
            corner_color = (150, 180, 210)
            corner_size = max(5, size // 12)
            offset = 2

        corner_y = y + frame_offset

        # 좌상단 모서리
        pygame.draw.rect(surface, corner_color,
                        (x + offset, corner_y + offset,
                         corner_size, corner_size))

        # 우상단 모서리
        pygame.draw.rect(surface, corner_color,
                        (x + size - corner_size - offset, corner_y + offset,
                         corner_size, corner_size))

        # 좌하단 모서리
        pygame.draw.rect(surface, corner_color,
                        (x + offset, corner_y + size - corner_size - offset,
                         corner_size, corner_size))

        # 우하단 모서리
        pygame.draw.rect(surface, corner_color,
                        (x + size - corner_size - offset, corner_y + size - corner_size - offset,
                         corner_size, corner_size))

    def draw_icon(self, surface, x, y, size, style="poseidon"):
        """전체 아이콘 그리기"""
        # 1. 공통 전설 프레임
        self.draw_common_legendary_frame(surface, x, y, size)

        # 2. 내부 모서리 장식
        self.draw_inner_corner_decorations(surface, x, y, size, style)

def main():
    """메인 실행 함수"""
    test = InnerCornerTest()
    clock = pygame.time.Clock()
    running = True

    # 다양한 크기와 스타일
    sizes = [64, 96, 128, 160]
    styles = ["poseidon", "dynamic", "default"]

    while running:
        dt = clock.tick(60) / 1000.0  # 60 FPS, dt는 초 단위

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

        # 화면 클리어
        SCREEN.fill((30, 30, 50))

        # 제목
        title_text = font_large.render("내부 테두리 모서리 장식 테스트", True, WHITE)
        title_rect = title_text.get_rect(center=(WIDTH // 2, 50))
        SCREEN.blit(title_text, title_rect)

        # 설명
        desc_text = font_medium.render("포세이돈 스타일 vs 동적 스타일 vs 기본 스타일", True, (200, 200, 200))
        desc_rect = desc_text.get_rect(center=(WIDTH // 2, 100))
        SCREEN.blit(desc_text, desc_rect)

        # 애니메이션 업데이트
        test.update(dt)

        # 각 스타일별로 그리기
        for style_idx, style in enumerate(styles):
            style_y_base = 200 + style_idx * 220

            # 스타일 레이블
            style_label = font_medium.render(f"{style.upper()} Style", True, WHITE)
            SCREEN.blit(style_label, (50, style_y_base - 30))

            # 다양한 크기로 아이콘 그리기
            for i, size in enumerate(sizes):
                x = 150 + i * 250
                y = style_y_base

                # 아이콘 그리기
                test.draw_icon(SCREEN, x, y, size, style)

                # 크기 레이블
                size_text = font_small.render(f"{size}x{size}", True, WHITE)
                size_rect = size_text.get_rect(center=(x + size // 2, y + size + 20))
                SCREEN.blit(size_text, size_rect)

        # 조작 안내
        control_text = font_small.render("ESC: 종료", True, (150, 150, 150))
        SCREEN.blit(control_text, (WIDTH - 100, HEIGHT - 30))

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()