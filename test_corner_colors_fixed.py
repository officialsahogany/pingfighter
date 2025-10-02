"""
PNG 프레임 모서리 색상 정확한 분석
BR 위치를 다시 확인하여 분석
"""
import pygame
import sys
import os

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1400, 900
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("PNG 모서리 색상 정확한 분석 - BR 재확인")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
YELLOW = (255, 255, 0)
CYAN = (0, 255, 255)

# 폰트 설정
font_large = pygame.font.Font(None, 36)
font_medium = pygame.font.Font(None, 24)
font_small = pygame.font.Font(None, 16)
font_tiny = pygame.font.Font(None, 12)

# 리소스 경로 헬퍼
def resource_path(relative_path):
    """Get absolute path to resource"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

class DetailedCornerAnalyzer:
    """상세 모서리 분석"""

    def __init__(self):
        self.frames = []
        self.corner_analysis = []
        self._load_and_analyze()

    def _load_and_analyze(self):
        """PNG 프레임을 로드하고 모서리 및 주변 픽셀 분석"""
        print("\n=== PNG 프레임 모서리 상세 분석 ===\n")

        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                # 원본 로드
                original = pygame.image.load(frame_path).convert_alpha()
                self.frames.append(original)

                # 모서리 및 주변 분석
                analysis = self._analyze_corners_and_surroundings(original, i)
                self.corner_analysis.append(analysis)

            except Exception as e:
                print(f"✗ 프레임 {i} 로드 실패: {e}")
                empty = pygame.Surface((60, 60), pygame.SRCALPHA)
                self.frames.append(empty)
                self.corner_analysis.append({})

    def _analyze_corners_and_surroundings(self, surface, frame_idx):
        """모서리 및 주변 픽셀 상세 분석"""
        width, height = surface.get_size()
        print(f"\nFrame {frame_idx} (크기: {width}x{height}):")
        print("=" * 60)

        analysis = {}

        # 실제 이미지가 60x60인지 32x32인지 확인
        actual_width = width
        actual_height = height

        # BR 모서리 주변 영역 상세 검사
        print("\nBR 영역 상세 검사:")
        print("-" * 40)

        # BR 주변 5x5 영역 검사
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                x = actual_width - 1 + dx
                y = actual_height - 1 + dy

                if 0 <= x < actual_width and 0 <= y < actual_height:
                    try:
                        color = surface.get_at((x, y))
                        marker = "***" if dx == 0 and dy == 0 else "   "
                        print(f"{marker} ({x:2},{y:2}): RGB({color.r:3}, {color.g:3}, {color.b:3}) A={color.a:3}")
                    except:
                        print(f"    ({x:2},{y:2}): Error")

        # 4개 모서리 정확한 위치
        corners = {
            "TL": (0, 0),
            "TR": (actual_width - 1, 0),
            "BL": (0, actual_height - 1),
            "BR": (actual_width - 1, actual_height - 1)
        }

        print("\n정확한 모서리 색상:")
        print("-" * 40)

        for name, (x, y) in corners.items():
            try:
                color = surface.get_at((x, y))
                analysis[name] = {
                    "pos": (x, y),
                    "color": (color.r, color.g, color.b, color.a)
                }

                # 색상 유형 판별
                if color.b == 255 and color.r > 100 and color.g > 100:
                    color_type = "밝은 파란색 계열"
                elif color.r > 200 and color.g < 100 and color.b < 100:
                    color_type = "빨간색 계열"
                elif color.r > 200 and color.g > 200 and color.b > 200:
                    color_type = "흰색/밝은 회색"
                else:
                    color_type = f"기타 (R:{color.r} G:{color.g} B:{color.b})"

                print(f"  {name} ({x:2},{y:2}): RGB({color.r:3}, {color.g:3}, {color.b:3}) A={color.a:3} - {color_type}")

            except Exception as e:
                print(f"  {name}: Error - {e}")
                analysis[name] = {"pos": (x, y), "color": (0, 0, 0, 0)}

        return analysis

    def draw_detailed_analysis(self, screen, frame_idx):
        """상세 분석 시각화"""

        if frame_idx >= len(self.frames):
            return

        x_base = 100
        y_base = 150

        # 원본 프레임
        frame = self.frames[frame_idx]

        # 크게 확대 (10배)
        scale_factor = 10
        width, height = frame.get_size()
        scaled_size = width * scale_factor

        # 확대된 이미지
        scaled = pygame.transform.scale(frame, (scaled_size, scaled_size))
        screen.blit(scaled, (x_base, y_base))

        # 그리드 그리기
        for i in range(width + 1):
            # 수직선
            pygame.draw.line(screen, (80, 80, 80),
                           (x_base + i * scale_factor, y_base),
                           (x_base + i * scale_factor, y_base + scaled_size), 1)
        for i in range(height + 1):
            # 수평선
            pygame.draw.line(screen, (80, 80, 80),
                           (x_base, y_base + i * scale_factor),
                           (x_base + scaled_size, y_base + i * scale_factor), 1)

        # 모서리 표시
        if frame_idx < len(self.corner_analysis):
            corners = self.corner_analysis[frame_idx]

            for name, data in corners.items():
                if "pos" in data:
                    x, y = data["pos"]
                    screen_x = x_base + x * scale_factor
                    screen_y = y_base + y * scale_factor

                    # 모서리 하이라이트
                    pygame.draw.rect(screen, YELLOW,
                                   (screen_x, screen_y, scale_factor, scale_factor), 2)

                    # 라벨
                    label = font_small.render(name, True, YELLOW)
                    screen.blit(label, (screen_x - 20, screen_y - 20))

        # 프레임 정보
        title = font_medium.render(f"Frame {frame_idx} ({width}x{height}) - 10x 확대", True, WHITE)
        screen.blit(title, (x_base, y_base - 30))

        # 색상 정보 표시
        info_x = x_base + scaled_size + 50
        info_y = y_base

        info_title = font_medium.render("모서리 색상 정보:", True, WHITE)
        screen.blit(info_title, (info_x, info_y))
        info_y += 30

        if frame_idx < len(self.corner_analysis):
            corners = self.corner_analysis[frame_idx]

            for name in ["TL", "TR", "BL", "BR"]:
                if name in corners and "color" in corners[name]:
                    color = corners[name]["color"]
                    pos = corners[name]["pos"]

                    # 색상 박스
                    pygame.draw.rect(screen, color[:3], (info_x, info_y, 30, 30))
                    pygame.draw.rect(screen, WHITE, (info_x, info_y, 30, 30), 1)

                    # 텍스트
                    text = f"{name} ({pos[0]},{pos[1]}): RGB({color[0]}, {color[1]}, {color[2]})"
                    label = font_small.render(text, True, (200, 200, 200))
                    screen.blit(label, (info_x + 40, info_y + 8))

                    info_y += 35

    def draw_comparison_table(self, screen):
        """모든 프레임 비교 테이블"""

        x = 750
        y = 150

        title = font_medium.render("모든 프레임 모서리 색상", True, WHITE)
        screen.blit(title, (x, y - 30))

        # 헤더
        headers = ["Frame", "TL", "TR", "BL", "BR"]
        for i, header in enumerate(headers):
            text = font_small.render(header, True, CYAN)
            screen.blit(text, (x + i * 100, y))

        y += 25

        # 각 프레임
        for frame_idx in range(min(8, len(self.corner_analysis))):
            # 프레임 번호
            text = font_small.render(f"{frame_idx}", True, WHITE)
            screen.blit(text, (x, y))

            corners = self.corner_analysis[frame_idx]

            for i, name in enumerate(["TL", "TR", "BL", "BR"]):
                if name in corners and "color" in corners[name]:
                    color = corners[name]["color"][:3]

                    # 색상 사각형
                    rect_x = x + 100 + i * 100
                    pygame.draw.rect(screen, color, (rect_x, y, 25, 20))
                    pygame.draw.rect(screen, (100, 100, 100), (rect_x, y, 25, 20), 1)

                    # RGB 값 (작게)
                    rgb_text = f"{color[0]},{color[1]},{color[2]}"
                    text = font_tiny.render(rgb_text, True, (150, 150, 150))
                    screen.blit(text, (rect_x + 30, y + 5))

            y += 25

def main():
    """메인 실행 함수"""
    analyzer = DetailedCornerAnalyzer()
    clock = pygame.time.Clock()
    running = True
    current_frame = 0

    while running:
        clock.tick(60)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_LEFT:
                    current_frame = (current_frame - 1) % 8
                elif event.key == pygame.K_RIGHT:
                    current_frame = (current_frame + 1) % 8
                elif event.key >= pygame.K_0 and event.key <= pygame.K_7:
                    current_frame = event.key - pygame.K_0

        # 화면 클리어
        SCREEN.fill((30, 30, 50))

        # 제목
        title = font_large.render("PNG 모서리 색상 정확한 분석 - BR 재확인", True, WHITE)
        title_rect = title.get_rect(center=(WIDTH // 2, 40))
        SCREEN.blit(title, title_rect)

        # 상세 분석
        analyzer.draw_detailed_analysis(SCREEN, current_frame)

        # 비교 테이블
        analyzer.draw_comparison_table(SCREEN)

        # 조작 안내
        control = font_small.render("←→: 프레임 선택 | 0-7: 직접 선택 | ESC: 종료", True, (150, 150, 150))
        control_rect = control.get_rect(center=(WIDTH // 2, HEIGHT - 20))
        SCREEN.blit(control, control_rect)

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()