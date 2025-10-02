"""
PNG 프레임 모든 모서리 색상 분석
4개 모서리 픽셀의 실제 색상을 모두 추출하여 비교
"""
import pygame
import sys
import os

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1200, 800
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("모든 모서리 색상 분석")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
YELLOW = (255, 255, 0)

# 폰트 설정
font_large = pygame.font.Font(None, 36)
font_medium = pygame.font.Font(None, 24)
font_small = pygame.font.Font(None, 16)

# 리소스 경로 헬퍼
def resource_path(relative_path):
    """Get absolute path to resource"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

class CornerColorAnalyzer:
    """모서리 색상 분석기"""

    def __init__(self):
        self.frames = []
        self.all_corner_colors = []  # 모든 프레임의 모든 코너 색상
        self._load_and_analyze()

    def _load_and_analyze(self):
        """PNG 프레임을 로드하고 모든 모서리 색상 분석"""
        print("\n=== 모든 PNG 프레임의 모서리 색상 분석 ===\n")

        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                # 원본 로드
                original = pygame.image.load(frame_path).convert_alpha()
                self.frames.append(original)

                # 모든 모서리 색상 추출
                corners = self._extract_all_corner_colors(original, i)
                self.all_corner_colors.append(corners)

            except Exception as e:
                print(f"✗ 프레임 {i} 로드 실패: {e}")
                empty = pygame.Surface((60, 60), pygame.SRCALPHA)
                self.frames.append(empty)
                self.all_corner_colors.append({})

        # 색상 패턴 분석
        self._analyze_color_patterns()

    def _extract_all_corner_colors(self, surface, frame_idx):
        """모든 모서리의 실제 색상 추출"""
        width, height = surface.get_size()

        corners = {
            "TL": {"pos": (0, 0), "color": None},
            "TR": {"pos": (width-1, 0), "color": None},
            "BL": {"pos": (0, height-1), "color": None},
            "BR": {"pos": (width-1, height-1), "color": None}
        }

        print(f"Frame {frame_idx} (크기: {width}x{height}):")

        for name, data in corners.items():
            x, y = data["pos"]
            try:
                color = surface.get_at((x, y))
                data["color"] = (color.r, color.g, color.b, color.a)

                # 색상 분류
                color_type = self._classify_color(color.r, color.g, color.b, color.a)

                print(f"  {name} ({x:2},{y:2}): RGB({color.r:3}, {color.g:3}, {color.b:3}) A={color.a:3} - {color_type}")

            except Exception as e:
                print(f"  {name}: 읽기 실패 - {e}")
                data["color"] = (0, 0, 0, 0)

        print()
        return corners

    def _classify_color(self, r, g, b, a):
        """색상 분류"""
        if a == 0:
            return "투명"
        elif r > 200 and g < 100 and b < 100:
            return "빨간색 계열"
        elif r > 200 and g > 200 and b > 200:
            return "흰색/밝은 회색"
        elif r > 150 and g > 150 and b > 150:
            return "회색 계열"
        elif b > r and b > g:
            return "파란색 계열"
        elif r > 100 and g > 100:
            return "황색 계열"
        else:
            return "기타"

    def _analyze_color_patterns(self):
        """색상 패턴 분석"""
        print("\n=== 색상 패턴 분석 ===\n")

        # TL, TR, BL의 공통 색상 찾기
        tl_colors = set()
        tr_colors = set()
        bl_colors = set()
        br_colors = set()

        for frame_colors in self.all_corner_colors:
            if "TL" in frame_colors and frame_colors["TL"]["color"]:
                tl_colors.add(frame_colors["TL"]["color"][:3])  # RGB만
            if "TR" in frame_colors and frame_colors["TR"]["color"]:
                tr_colors.add(frame_colors["TR"]["color"][:3])
            if "BL" in frame_colors and frame_colors["BL"]["color"]:
                bl_colors.add(frame_colors["BL"]["color"][:3])
            if "BR" in frame_colors and frame_colors["BR"]["color"]:
                br_colors.add(frame_colors["BR"]["color"][:3])

        print("고유 색상들:")
        print(f"  TL: {len(tl_colors)}개 색상")
        for color in tl_colors:
            print(f"     RGB{color}")

        print(f"  TR: {len(tr_colors)}개 색상")
        for color in tr_colors:
            print(f"     RGB{color}")

        print(f"  BL: {len(bl_colors)}개 색상")
        for color in bl_colors:
            print(f"     RGB{color}")

        print(f"  BR: {len(br_colors)}개 색상")
        for color in br_colors:
            print(f"     RGB{color}")

        # 공통 색상 찾기
        print("\n공통 색상 (TL, TR, BL에 모두 나타나는 색상):")
        common_colors = tl_colors & tr_colors & bl_colors
        for color in common_colors:
            print(f"  RGB{color}")

    def draw_frame_analysis(self, screen, frame_idx):
        """프레임별 모서리 색상 시각화"""

        if frame_idx >= len(self.frames):
            return

        x_base = 100
        y_base = 150

        # 프레임 이미지
        frame = self.frames[frame_idx]
        size = 200
        scaled = pygame.transform.scale(frame, (size, size))
        screen.blit(scaled, (x_base, y_base))
        pygame.draw.rect(screen, WHITE, (x_base, y_base, size, size), 1)

        # 프레임 라벨
        label = font_medium.render(f"Frame {frame_idx}", True, WHITE)
        screen.blit(label, (x_base, y_base - 30))

        # 각 모서리 색상 표시
        if frame_idx < len(self.all_corner_colors):
            corners = self.all_corner_colors[frame_idx]

            # 코너 위치
            corner_positions = {
                "TL": (x_base - 60, y_base - 60),
                "TR": (x_base + size + 20, y_base - 60),
                "BL": (x_base - 60, y_base + size + 20),
                "BR": (x_base + size + 20, y_base + size + 20)
            }

            for name, pos in corner_positions.items():
                if name in corners and corners[name]["color"]:
                    color = corners[name]["color"][:3]  # RGB만

                    # 색상 박스
                    pygame.draw.rect(screen, color, (pos[0], pos[1], 40, 40))
                    pygame.draw.rect(screen, WHITE, (pos[0], pos[1], 40, 40), 1)

                    # 라벨
                    label = font_small.render(name, True, WHITE)
                    screen.blit(label, (pos[0] + 5, pos[1] - 20))

                    # RGB 값
                    rgb_text = font_small.render(f"{color[0]},{color[1]},{color[2]}", True, (200, 200, 200))
                    screen.blit(rgb_text, (pos[0] - 10, pos[1] + 45))

    def draw_color_table(self, screen):
        """색상 테이블 그리기"""

        x = 400
        y = 150

        # 테이블 헤더
        title = font_medium.render("모든 프레임 모서리 색상 비교", True, WHITE)
        screen.blit(title, (x, y - 30))

        # 헤더
        headers = ["Frame", "TL", "TR", "BL", "BR"]
        for i, header in enumerate(headers):
            text = font_small.render(header, True, YELLOW)
            screen.blit(text, (x + i * 120, y))

        y += 30

        # 각 프레임의 색상
        for frame_idx in range(8):
            # 프레임 번호
            text = font_small.render(f"{frame_idx}", True, WHITE)
            screen.blit(text, (x, y))

            if frame_idx < len(self.all_corner_colors):
                corners = self.all_corner_colors[frame_idx]

                corner_names = ["TL", "TR", "BL", "BR"]
                for i, name in enumerate(corner_names):
                    if name in corners and corners[name]["color"]:
                        color = corners[name]["color"][:3]

                        # 색상 사각형
                        rect_x = x + 120 + i * 120
                        pygame.draw.rect(screen, color, (rect_x, y, 30, 20))
                        pygame.draw.rect(screen, (100, 100, 100), (rect_x, y, 30, 20), 1)

                        # 밝은 색 표시
                        if max(color) > 200:
                            pygame.draw.rect(screen, YELLOW, (rect_x - 2, y - 2, 34, 24), 1)

            y += 25

def main():
    """메인 실행 함수"""
    analyzer = CornerColorAnalyzer()
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

        # 화면 클리어
        SCREEN.fill((30, 30, 50))

        # 제목
        title = font_large.render("PNG 프레임 모든 모서리 색상 분석", True, WHITE)
        title_rect = title.get_rect(center=(WIDTH // 2, 40))
        SCREEN.blit(title, title_rect)

        # 현재 프레임 분석
        analyzer.draw_frame_analysis(SCREEN, current_frame)

        # 색상 테이블
        analyzer.draw_color_table(SCREEN)

        # 조작 안내
        control = font_small.render("←→: 프레임 선택 | ESC: 종료", True, (150, 150, 150))
        control_rect = control.get_rect(center=(WIDTH // 2, HEIGHT - 20))
        SCREEN.blit(control, control_rect)

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()