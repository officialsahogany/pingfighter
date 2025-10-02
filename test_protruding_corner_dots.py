"""
튀어나온 코너 점 (Protruding Corner Dots)
PNG 프레임 사각형 밖으로 튀어나온 4개의 코너 점
프레임별로 파란색/보라색과 흰색으로 변화
"""
import pygame
import sys
import os

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1400, 800
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("튀어나온 코너 점 - PNG 프레임 밖 4개 점")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
BLUE = (150, 150, 255)
PURPLE = (200, 150, 255)
DARK_BG = (30, 30, 50)

# 폰트 설정
font_large = pygame.font.Font(None, 36)
font_medium = pygame.font.Font(None, 24)
font_small = pygame.font.Font(None, 18)

# 리소스 경로 헬퍼
def resource_path(relative_path):
    """Get absolute path to resource"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

class ProtrudingCornerDots:
    """튀어나온 코너 점 시스템"""

    def __init__(self):
        self.frames = []
        self.corner_colors = []  # 각 프레임의 코너 색상
        self.current_frame = 0
        self.animation_timer = 0
        self._load_and_analyze()

    def _load_and_analyze(self):
        """PNG 프레임 로드 및 코너 색상 분석"""
        print("PNG 프레임 및 코너 점 분석 중...")

        # 각 프레임의 코너 색상 패턴 (실제 PNG 분석 기반)
        # Frame 0, 4: 흰색/밝은 점 (번개 프레임)
        # Frame 1,2,3,5,6,7: 파란색/보라색 점
        corner_patterns = [
            WHITE,   # Frame 0 - 번개 프레임 (흰색)
            BLUE,    # Frame 1 - 파란색
            PURPLE,  # Frame 2 - 보라색
            BLUE,    # Frame 3 - 파란색
            WHITE,   # Frame 4 - 번개 프레임 (흰색)
            PURPLE,  # Frame 5 - 보라색
            BLUE,    # Frame 6 - 파란색
            PURPLE,  # Frame 7 - 보라색
        ]

        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                # PNG 로드
                original = pygame.image.load(frame_path).convert_alpha()
                self.frames.append(original)
                self.corner_colors.append(corner_patterns[i])
                print(f"✓ 프레임 {i}: 코너 색상 {corner_patterns[i]}")

            except Exception as e:
                print(f"✗ 프레임 {i} 로드 실패: {e}")
                # 빈 프레임
                empty = pygame.Surface((60, 60), pygame.SRCALPHA)
                self.frames.append(empty)
                self.corner_colors.append(BLUE)

    def draw_protruding_dots(self, screen, x, y, size, frame_idx):
        """튀어나온 코너 점 그리기

        Args:
            x, y: PNG 프레임 위치
            size: 프레임 크기
            frame_idx: 프레임 인덱스
        """

        # 프레임 배경 (참고용)
        pygame.draw.rect(screen, (50, 50, 60), (x, y, size, size))
        pygame.draw.rect(screen, (80, 80, 90), (x, y, size, size), 1)

        # PNG 프레임 그리기
        if frame_idx < len(self.frames):
            scaled = pygame.transform.scale(self.frames[frame_idx], (size, size))
            screen.blit(scaled, (x, y))

        # 튀어나온 코너 점 위치 (프레임 밖)
        offset = 6  # 프레임에서 튀어나온 거리
        dot_size = 4  # 점 크기

        corners = [
            (x - offset, y - offset),              # Top-left (밖으로)
            (x + size + offset, y - offset),       # Top-right (밖으로)
            (x - offset, y + size + offset),       # Bottom-left (밖으로)
            (x + size + offset, y + size + offset) # Bottom-right (밖으로)
        ]

        # 코너 색상
        if frame_idx < len(self.corner_colors):
            color = self.corner_colors[frame_idx]
        else:
            color = BLUE

        # 각 코너에 점 그리기
        for cx, cy in corners:
            # 외부 글로우
            glow_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
            alpha = 100
            glow_color = (*color, alpha)
            pygame.draw.circle(glow_surf, glow_color, (10, 10), 8)
            screen.blit(glow_surf, (cx - 10, cy - 10))

            # 메인 점
            pygame.draw.circle(screen, color, (cx, cy), dot_size)

            # 중심 하이라이트
            bright = tuple(min(255, c + 50) for c in color)
            pygame.draw.circle(screen, bright, (cx, cy), 2)

    def draw_frame_comparison(self, screen):
        """8개 프레임 비교 표시"""

        for i in range(8):
            row = i // 4
            col = i % 4
            x = 100 + col * 200
            y = 150 + row * 200
            size = 80

            # 프레임 라벨
            label = font_small.render(f"Frame {i}", True, WHITE)
            label_rect = label.get_rect(center=(x + size // 2, y - 20))
            screen.blit(label, label_rect)

            # 튀어나온 점과 함께 프레임 그리기
            self.draw_protruding_dots(screen, x, y, size, i)

            # 색상 정보
            if i < len(self.corner_colors):
                color = self.corner_colors[i]
                color_name = "WHITE" if color == WHITE else "BLUE" if color == BLUE else "PURPLE"
                info = font_small.render(color_name, True, color)
                info_rect = info.get_rect(center=(x + size // 2, y + size + 30))
                screen.blit(info, info_rect)

    def draw_large_preview(self, screen, frame_idx):
        """큰 프리뷰 with 튀어나온 점"""

        size = 200
        x = 900
        y = 200

        # 제목
        title = font_medium.render(f"확대 보기 - Frame {frame_idx}", True, WHITE)
        title_rect = title.get_rect(center=(x + size // 2, y - 40))
        screen.blit(title, title_rect)

        # 큰 크기로 그리기
        self.draw_protruding_dots(screen, x, y, size, frame_idx)

        # 코너 마커 (초록색 동그라미처럼)
        offset = 6 * (size / 80)  # 크기 비율에 맞춰 조정
        corners = [
            (x - offset, y - offset),
            (x + size + offset, y - offset),
            (x - offset, y + size + offset),
            (x + size + offset, y + size + offset)
        ]

        for cx, cy in corners:
            # 초록색 마커 (스크린샷처럼)
            pygame.draw.circle(screen, (0, 255, 0), (int(cx), int(cy)), 15, 2)

    def draw_dot_only_view(self, screen):
        """점만 따로 표시"""

        y = 500
        text = font_medium.render("튀어나온 점만 표시 (프레임별 색상)", True, WHITE)
        screen.blit(text, (100, y - 30))

        for i in range(8):
            x = 100 + i * 120
            size = 60

            # 프레임 외곽선만
            pygame.draw.rect(screen, (60, 60, 70), (x, y, size, size), 1)

            # 튀어나온 점만
            offset = 5
            corners = [
                (x - offset, y - offset),
                (x + size + offset, y - offset),
                (x - offset, y + size + offset),
                (x + size + offset, y + size + offset)
            ]

            if i < len(self.corner_colors):
                color = self.corner_colors[i]
            else:
                color = BLUE

            for cx, cy in corners:
                pygame.draw.circle(screen, color, (cx, cy), 4)
                bright = tuple(min(255, c + 50) for c in color)
                pygame.draw.circle(screen, bright, (cx, cy), 2)

            # 프레임 번호
            num = font_small.render(f"{i}", True, (150, 150, 150))
            num_rect = num.get_rect(center=(x + size // 2, y + size + 15))
            screen.blit(num, num_rect)

    def update(self, dt):
        """애니메이션 업데이트"""
        self.animation_timer += dt
        if self.animation_timer > 500:  # 0.5초마다
            self.animation_timer = 0
            self.current_frame = (self.current_frame + 1) % 8

def main():
    """메인 실행 함수"""
    dots = ProtrudingCornerDots()
    clock = pygame.time.Clock()
    running = True

    selected_frame = 0
    show_animation = False

    while running:
        dt = clock.tick(60)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_LEFT:
                    selected_frame = (selected_frame - 1) % 8
                elif event.key == pygame.K_RIGHT:
                    selected_frame = (selected_frame + 1) % 8
                elif event.key == pygame.K_SPACE:
                    show_animation = not show_animation

        # 화면 클리어
        SCREEN.fill(DARK_BG)

        # 제목
        title = font_large.render("튀어나온 코너 점 (Protruding Corner Dots)", True, WHITE)
        title_rect = title.get_rect(center=(WIDTH // 2, 40))
        SCREEN.blit(title, title_rect)

        # 설명
        desc = font_medium.render("PNG 프레임 밖으로 튀어나온 4개 점 - 프레임별로 파란색/흰색 변화", True, (200, 200, 200))
        desc_rect = desc.get_rect(center=(WIDTH // 2, 80))
        SCREEN.blit(desc, desc_rect)

        # 애니메이션 모드
        if show_animation:
            dots.update(dt)
            display_frame = dots.current_frame
        else:
            display_frame = selected_frame

        # 8개 프레임 비교
        dots.draw_frame_comparison(SCREEN)

        # 큰 프리뷰
        dots.draw_large_preview(SCREEN, display_frame)

        # 점만 표시
        dots.draw_dot_only_view(SCREEN)

        # 정보
        info_y = HEIGHT - 80
        info_lines = [
            "특징: PNG 프레임 경계 밖으로 6픽셀 튀어나옴",
            "색상: Frame 0,4 = 흰색 (번개) | 나머지 = 파란색/보라색",
            f"현재 프레임: {display_frame}",
            "←→: 프레임 선택 | SPACE: 애니메이션 | ESC: 종료"
        ]

        for i, line in enumerate(info_lines):
            info_text = font_small.render(line, True, (180, 180, 180))
            SCREEN.blit(info_text, (50 + (i % 2) * 600, info_y + (i // 2) * 25))

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()