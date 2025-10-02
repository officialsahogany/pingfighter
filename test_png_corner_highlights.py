"""
PNG 프레임 내부의 코너 하이라이트 분석
라그나로크 해머 PNG 이미지 자체에 포함된 4개의 밝은 모서리 점
"""
import pygame
import sys
import os

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1400, 800
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("PNG 프레임 코너 하이라이트 - 이미지에 포함된 4개 점")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
YELLOW = (255, 215, 0)
RED = (255, 0, 0)
CYAN = (0, 255, 255)

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

class PNGCornerAnalyzer:
    """PNG 프레임의 코너 하이라이트 분석"""

    def __init__(self):
        self.frames = []
        self.corner_highlights = []
        self.current_frame = 0
        self.animation_timer = 0
        self._load_and_analyze()

    def _load_and_analyze(self):
        """PNG 프레임을 로드하고 코너 하이라이트 분석"""
        print("PNG 프레임 코너 하이라이트 분석 중...")

        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                # 원본 로드
                original = pygame.image.load(frame_path).convert_alpha()
                self.frames.append(original)

                # 코너 하이라이트 추출
                corners = self._extract_corner_highlights(original, i)
                self.corner_highlights.append(corners)

                print(f"✓ 프레임 {i}: 코너 하이라이트 {len(corners)}개 발견")

            except Exception as e:
                print(f"✗ 프레임 {i} 로드 실패: {e}")
                # 빈 프레임 추가
                empty = pygame.Surface((60, 60), pygame.SRCALPHA)
                self.frames.append(empty)
                self.corner_highlights.append([])

    def _extract_corner_highlights(self, surface, frame_idx):
        """코너의 밝은 점들을 추출"""
        width, height = surface.get_size()
        corners = []

        # 검색할 코너 영역 (각 모서리 15x15 픽셀 영역)
        corner_areas = [
            {"name": "Top-Left", "x": 0, "y": 0, "color": None},
            {"name": "Top-Right", "x": width - 15, "y": 0, "color": None},
            {"name": "Bottom-Left", "x": 0, "y": height - 15, "color": None},
            {"name": "Bottom-Right", "x": width - 15, "y": height - 15, "color": None}
        ]

        for corner in corner_areas:
            # 각 코너 영역에서 가장 밝은 픽셀 찾기
            brightest_value = 0
            brightest_pos = None
            brightest_color = None

            for dy in range(15):
                for dx in range(15):
                    x = corner["x"] + dx
                    y = corner["y"] + dy

                    if 0 <= x < width and 0 <= y < height:
                        color = surface.get_at((x, y))

                        # 밝기 계산 (알파 채널 포함)
                        if color.a > 0:
                            brightness = (color.r + color.g + color.b) * (color.a / 255)

                            # 밝은 색상만 (회색~흰색 계열)
                            if brightness > 400 and min(color.r, color.g, color.b) > 150:
                                if brightness > brightest_value:
                                    brightest_value = brightness
                                    brightest_pos = (x, y)
                                    brightest_color = color

            if brightest_pos:
                corner["pos"] = brightest_pos
                corner["color"] = brightest_color
                corner["brightness"] = brightest_value
                corners.append(corner)

        return corners

    def draw_original_with_markers(self, screen, x, y, size, frame_idx):
        """원본 프레임에 코너 마커 표시"""
        if frame_idx < len(self.frames):
            # 원본 프레임 그리기
            frame = self.frames[frame_idx]
            scaled = pygame.transform.scale(frame, (size, size))
            screen.blit(scaled, (x, y))

            # 코너 하이라이트 마커
            if frame_idx < len(self.corner_highlights):
                scale_factor = size / frame.get_width()

                for corner in self.corner_highlights[frame_idx]:
                    if "pos" in corner:
                        # 스케일된 위치 계산
                        marker_x = x + int(corner["pos"][0] * scale_factor)
                        marker_y = y + int(corner["pos"][1] * scale_factor)

                        # 노란색 원으로 표시 (스크린샷처럼)
                        pygame.draw.circle(screen, YELLOW, (marker_x, marker_y), 12, 2)

                        # 내부 점
                        if corner.get("color"):
                            pygame.draw.circle(screen,
                                             (corner["color"].r, corner["color"].g, corner["color"].b),
                                             (marker_x, marker_y), 3)

    def draw_extracted_corners(self, screen, x, y, size, frame_idx):
        """추출된 코너만 표시"""
        # 배경 박스
        pygame.draw.rect(screen, (40, 40, 50), (x, y, size, size))
        pygame.draw.rect(screen, (100, 100, 100), (x, y, size, size), 1)

        if frame_idx < len(self.corner_highlights):
            corners = self.corner_highlights[frame_idx]

            for corner in corners:
                if "pos" in corner:
                    # 코너 위치 매핑
                    rel_x = corner["pos"][0] / 60.0  # 원본 크기 60x60 기준
                    rel_y = corner["pos"][1] / 60.0

                    draw_x = x + int(rel_x * size)
                    draw_y = y + int(rel_y * size)

                    # 코너 색상으로 큰 점 그리기
                    if corner.get("color"):
                        color = corner["color"]
                        # 외곽 글로우
                        for i in range(3):
                            alpha = 100 - i * 30
                            glow_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
                            pygame.draw.circle(glow_surf,
                                             (color.r, color.g, color.b, alpha),
                                             (10, 10), 8 - i * 2)
                            screen.blit(glow_surf, (draw_x - 10, draw_y - 10))

                        # 중심점
                        pygame.draw.circle(screen,
                                         (color.r, color.g, color.b),
                                         (draw_x, draw_y), 4)

                        # 라벨
                        label = font_small.render(corner["name"], True, WHITE)
                        screen.blit(label, (draw_x - 30, draw_y + 10))

    def update(self, dt):
        """애니메이션 업데이트"""
        self.animation_timer += dt
        if self.animation_timer > 500:  # 0.5초마다
            self.animation_timer = 0
            self.current_frame = (self.current_frame + 1) % 8

def main():
    """메인 실행 함수"""
    analyzer = PNGCornerAnalyzer()
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
        title = font_large.render("PNG 프레임 코너 하이라이트 분석", True, WHITE)
        title_rect = title.get_rect(center=(WIDTH // 2, 40))
        SCREEN.blit(title, title_rect)

        # 설명
        desc = font_medium.render("라그나로크 해머 PNG 이미지에 포함된 4개의 밝은 코너", True, (200, 200, 200))
        desc_rect = desc.get_rect(center=(WIDTH // 2, 80))
        SCREEN.blit(desc, desc_rect)

        # 애니메이션 모드
        if show_animation:
            analyzer.update(dt)
            display_frame = analyzer.current_frame
        else:
            display_frame = selected_frame

        # 왼쪽: 원본 프레임 (마커 포함)
        orig_x = 150
        orig_y = 150
        orig_size = 300

        orig_title = font_medium.render(f"원본 프레임 {display_frame} (노란 원 = 코너 하이라이트)", True, YELLOW)
        SCREEN.blit(orig_title, (orig_x, orig_y - 30))

        analyzer.draw_original_with_markers(SCREEN, orig_x, orig_y, orig_size, display_frame)

        # 오른쪽: 추출된 코너만
        extract_x = 600
        extract_y = 150
        extract_size = 300

        extract_title = font_medium.render("추출된 코너 하이라이트", True, CYAN)
        SCREEN.blit(extract_title, (extract_x, extract_y - 30))

        analyzer.draw_extracted_corners(SCREEN, extract_x, extract_y, extract_size, display_frame)

        # 하단: 모든 프레임 미니 뷰
        mini_y = 500
        mini_size = 80

        for i in range(8):
            mini_x = 150 + i * 120

            # 선택된 프레임 하이라이트
            if i == display_frame:
                pygame.draw.rect(SCREEN, YELLOW,
                               (mini_x - 5, mini_y - 5, mini_size + 10, mini_size + 10), 2)

            # 미니 프레임
            analyzer.draw_original_with_markers(SCREEN, mini_x, mini_y, mini_size, i)

            # 프레임 번호
            frame_text = font_small.render(f"Frame {i}", True, WHITE)
            frame_rect = frame_text.get_rect(center=(mini_x + mini_size // 2, mini_y + mini_size + 15))
            SCREEN.blit(frame_text, frame_rect)

        # 코너 정보
        info_x = 1000
        info_y = 200

        info_title = font_medium.render("코너 하이라이트 정보:", True, WHITE)
        SCREEN.blit(info_title, (info_x, info_y))

        if display_frame < len(analyzer.corner_highlights):
            corners = analyzer.corner_highlights[display_frame]
            for i, corner in enumerate(corners):
                if "color" in corner and corner["color"]:
                    color = corner["color"]
                    info_text = f"{corner['name']}: RGB({color.r}, {color.g}, {color.b})"
                    text = font_small.render(info_text, True, (200, 200, 200))
                    SCREEN.blit(text, (info_x, info_y + 40 + i * 25))

                    # 색상 샘플
                    pygame.draw.rect(SCREEN, (color.r, color.g, color.b),
                                   (info_x + 250, info_y + 40 + i * 25, 20, 15))

        # 조작 안내
        control = font_small.render("←→: 프레임 선택 | SPACE: 애니메이션 | ESC: 종료", True, (150, 150, 150))
        control_rect = control.get_rect(center=(WIDTH // 2, HEIGHT - 30))
        SCREEN.blit(control, control_rect)

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()