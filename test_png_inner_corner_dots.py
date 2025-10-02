"""
PNG 내부 코너 점 분석 (Inner Corner Dots in PNG)
PNG 이미지 파일 자체에 포함된 4개 모서리 점
"""
import pygame
import sys
import os

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1400, 800
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("PNG 내부 코너 점 - 이미지 파일에 포함된 4개 모서리 점")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
YELLOW = (255, 215, 0)
RED = (255, 0, 0)
CYAN = (0, 255, 255)
GREEN = (0, 255, 0)

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

class PNGInnerCornerDots:
    """PNG 내부 코너 점 분석"""

    def __init__(self):
        self.frames = []
        self.corner_pixels = []  # 각 프레임의 실제 코너 픽셀 색상
        self.current_frame = 0
        self.animation_timer = 0
        self._load_and_analyze()

    def _load_and_analyze(self):
        """PNG 프레임을 로드하고 실제 코너 픽셀 분석"""
        print("PNG 내부 코너 점 분석 중...")

        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                # 원본 로드
                original = pygame.image.load(frame_path).convert_alpha()
                self.frames.append(original)

                # 실제 코너 픽셀 추출 (정확히 모서리 위치)
                corners = self._extract_exact_corner_pixels(original)
                self.corner_pixels.append(corners)

                print(f"✓ 프레임 {i}: 코너 픽셀 분석 완료")
                for corner in corners:
                    if corner["color"]:
                        print(f"  - {corner['name']}: RGB{corner['color'][:3]} A={corner['color'][3]}")

            except Exception as e:
                print(f"✗ 프레임 {i} 로드 실패: {e}")
                empty = pygame.Surface((60, 60), pygame.SRCALPHA)
                self.frames.append(empty)
                self.corner_pixels.append([])

    def _extract_exact_corner_pixels(self, surface):
        """정확한 코너 픽셀 추출"""
        width, height = surface.get_size()

        # 정확한 코너 위치
        corners = [
            {"name": "Top-Left", "pos": (0, 0), "color": None},
            {"name": "Top-Right", "pos": (width-1, 0), "color": None},
            {"name": "Bottom-Left", "pos": (0, height-1), "color": None},
            {"name": "Bottom-Right", "pos": (width-1, height-1), "color": None}
        ]

        for corner in corners:
            x, y = corner["pos"]
            try:
                color = surface.get_at((x, y))
                corner["color"] = (color.r, color.g, color.b, color.a)
            except:
                corner["color"] = (0, 0, 0, 0)

        return corners

    def draw_frame_with_zoom(self, screen, x, y, size, frame_idx):
        """프레임과 확대된 코너 표시"""

        if frame_idx >= len(self.frames):
            return

        frame = self.frames[frame_idx]

        # 배경
        pygame.draw.rect(screen, (40, 40, 50), (x-10, y-10, size+20, size+20))

        # 프레임 그리기
        scaled = pygame.transform.scale(frame, (size, size))
        screen.blit(scaled, (x, y))

        # 프레임 테두리
        pygame.draw.rect(screen, (100, 100, 100), (x, y, size, size), 1)

        # 코너 확대 표시
        if frame_idx < len(self.corner_pixels):
            corners = self.corner_pixels[frame_idx]

            # 확대 위치 (프레임 주변)
            zoom_positions = [
                (x - 50, y - 50),      # Top-left
                (x + size + 10, y - 50),  # Top-right
                (x - 50, y + size + 10),  # Bottom-left
                (x + size + 10, y + size + 10)  # Bottom-right
            ]

            for corner, zoom_pos in zip(corners, zoom_positions):
                # 확대 박스
                zoom_size = 40
                pygame.draw.rect(screen, (60, 60, 70),
                               (zoom_pos[0], zoom_pos[1], zoom_size, zoom_size))
                pygame.draw.rect(screen, (100, 100, 120),
                               (zoom_pos[0], zoom_pos[1], zoom_size, zoom_size), 1)

                # 확대된 픽셀 (큰 사각형으로 표시)
                if corner["color"]:
                    color = corner["color"][:3]  # RGB만
                    pygame.draw.rect(screen, color,
                                   (zoom_pos[0] + 5, zoom_pos[1] + 5, 30, 30))

                    # 중심 하이라이트
                    if color[0] > 150 or color[1] > 150 or color[2] > 150:
                        pygame.draw.rect(screen, WHITE,
                                       (zoom_pos[0] + 15, zoom_pos[1] + 15, 10, 10))

                # 연결선
                corner_x = x + (0 if "Left" in corner["name"] else size)
                corner_y = y + (0 if "Top" in corner["name"] else size)
                line_end = (zoom_pos[0] + zoom_size//2, zoom_pos[1] + zoom_size//2)
                pygame.draw.line(screen, (80, 80, 80),
                               (corner_x, corner_y), line_end, 1)

                # 초록색 마커 (스크린샷처럼)
                pygame.draw.circle(screen, GREEN, (corner_x, corner_y), 8, 2)

    def draw_all_frames_grid(self, screen):
        """8개 프레임 그리드 표시"""

        for i in range(8):
            row = i // 4
            col = i % 4
            x = 100 + col * 220
            y = 150 + row * 220
            size = 80

            # 프레임 라벨
            label = font_small.render(f"Frame {i}", True, WHITE)
            label_rect = label.get_rect(center=(x + size//2, y - 20))
            screen.blit(label, label_rect)

            # 프레임과 확대 표시
            self.draw_frame_with_zoom(screen, x, y, size, i)

            # 코너 색상 정보
            if i < len(self.corner_pixels):
                corners = self.corner_pixels[i]
                # 첫 번째 코너 색상만 표시 (대표로)
                if corners and corners[0]["color"]:
                    color = corners[0]["color"]
                    info = font_small.render(
                        f"RGB({color[0]}, {color[1]}, {color[2]})",
                        True, (180, 180, 180)
                    )
                    info_rect = info.get_rect(center=(x + size//2, y + size + 60))
                    screen.blit(info, info_rect)

    def draw_corner_comparison(self, screen):
        """코너 색상 비교 테이블"""

        x = 1000
        y = 150

        title = font_medium.render("코너 픽셀 색상 비교", True, WHITE)
        screen.blit(title, (x, y))

        y += 40

        # 헤더
        headers = ["Frame", "TL", "TR", "BL", "BR"]
        for i, header in enumerate(headers):
            text = font_small.render(header, True, CYAN)
            screen.blit(text, (x + i * 60, y))

        y += 25

        # 각 프레임의 코너 색상
        for frame_idx in range(8):
            # 프레임 번호
            text = font_small.render(f"{frame_idx}", True, WHITE)
            screen.blit(text, (x, y))

            if frame_idx < len(self.corner_pixels):
                corners = self.corner_pixels[frame_idx]

                for i, corner in enumerate(corners):
                    if corner["color"]:
                        color = corner["color"][:3]
                        # 색상 사각형
                        pygame.draw.rect(screen, color,
                                       (x + 60 + i * 60, y, 20, 15))

                        # 밝은 픽셀 표시
                        if max(color) > 200:
                            pygame.draw.rect(screen, YELLOW,
                                           (x + 60 + i * 60, y, 20, 15), 1)

            y += 20

    def draw_large_analysis(self, screen, frame_idx):
        """큰 크기로 상세 분석"""

        x = 1000
        y = 450
        size = 150

        title = font_medium.render(f"프레임 {frame_idx} 상세 분석", True, WHITE)
        title_rect = title.get_rect(center=(x + size//2, y - 30))
        screen.blit(title, title_rect)

        self.draw_frame_with_zoom(screen, x, y, size, frame_idx)

    def update(self, dt):
        """애니메이션 업데이트"""
        self.animation_timer += dt
        if self.animation_timer > 500:
            self.animation_timer = 0
            self.current_frame = (self.current_frame + 1) % 8

def main():
    """메인 실행 함수"""
    analyzer = PNGInnerCornerDots()
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
        SCREEN.fill((30, 30, 50))

        # 제목
        title = font_large.render("PNG 내부 코너 점 분석", True, WHITE)
        title_rect = title.get_rect(center=(WIDTH // 2, 40))
        SCREEN.blit(title, title_rect)

        # 설명
        desc = font_medium.render("PNG 이미지 파일 자체의 정확한 모서리 픽셀 (초록색 마커)", True, (200, 200, 200))
        desc_rect = desc.get_rect(center=(WIDTH // 2, 80))
        SCREEN.blit(desc, desc_rect)

        # 애니메이션 모드
        if show_animation:
            analyzer.update(dt)
            display_frame = analyzer.current_frame
        else:
            display_frame = selected_frame

        # 8개 프레임 그리드
        analyzer.draw_all_frames_grid(SCREEN)

        # 코너 색상 비교
        analyzer.draw_corner_comparison(SCREEN)

        # 큰 분석
        analyzer.draw_large_analysis(SCREEN, display_frame)

        # 조작 안내
        control = font_small.render("←→: 프레임 선택 | SPACE: 애니메이션 | ESC: 종료", True, (150, 150, 150))
        control_rect = control.get_rect(center=(WIDTH // 2, HEIGHT - 20))
        SCREEN.blit(control, control_rect)

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()