"""
PNG 프레임 모서리 색상 클러스터 분석
같은 색상의 픽셀들이 연결되어 하나의 점을 형성
"""
import pygame
import sys
import os
from collections import deque

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1400, 900
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("모서리 색상 클러스터 분석 - 연결된 같은 색 픽셀 그룹")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
YELLOW = (255, 255, 0)
CYAN = (0, 255, 255)
MAGENTA = (255, 0, 255)

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

class CornerClusterAnalyzer:
    """모서리 색상 클러스터 분석기"""

    def __init__(self):
        self.frames = []
        self.corner_clusters = []  # 각 프레임의 모서리 클러스터
        self._load_and_analyze()

    def _load_and_analyze(self):
        """PNG 프레임을 로드하고 모서리 클러스터 분석"""
        print("\n=== PNG 프레임 모서리 색상 클러스터 분석 ===\n")

        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                # 원본 로드
                original = pygame.image.load(frame_path).convert_alpha()
                self.frames.append(original)

                # 모서리 클러스터 분석
                clusters = self._find_corner_clusters(original, i)
                self.corner_clusters.append(clusters)

            except Exception as e:
                print(f"✗ 프레임 {i} 로드 실패: {e}")
                empty = pygame.Surface((60, 60), pygame.SRCALPHA)
                self.frames.append(empty)
                self.corner_clusters.append({})

    def _find_corner_clusters(self, surface, frame_idx):
        """모서리 근처의 색상 클러스터 찾기"""
        width, height = surface.get_size()
        print(f"\nFrame {frame_idx} 클러스터 분석:")
        print("=" * 60)

        clusters = {
            "TL": [],
            "TR": [],
            "BL": [],
            "BR": []
        }

        # 각 모서리 근처 영역 정의 (10x10 픽셀 영역)
        corner_areas = {
            "TL": (0, 0, 10, 10),
            "TR": (width-10, 0, 10, 10),
            "BL": (0, height-10, 10, 10),
            "BR": (width-10, height-10, 10, 10)
        }

        for corner_name, (start_x, start_y, area_w, area_h) in corner_areas.items():
            print(f"\n{corner_name} 모서리 영역 ({start_x},{start_y})~({start_x+area_w-1},{start_y+area_h-1}):")

            # 이미 방문한 픽셀 추적
            visited = set()

            # 영역 내 모든 픽셀 검사
            for y in range(start_y, min(start_y + area_h, height)):
                for x in range(start_x, min(start_x + area_w, width)):
                    if (x, y) in visited:
                        continue

                    color = surface.get_at((x, y))

                    # 투명하거나 너무 어두운 픽셀 무시
                    if color.a < 100 or (color.r < 50 and color.g < 50 and color.b < 50):
                        continue

                    # 붉은색 배경 무시
                    if color.r > 100 and color.g < 50 and color.b < 50:
                        continue

                    # 연결된 같은 색상 픽셀 찾기 (BFS)
                    cluster = self._find_connected_pixels(surface, x, y, color, visited,
                                                         start_x, start_y, area_w, area_h)

                    if len(cluster) >= 2:  # 2개 이상 연결된 픽셀만 클러스터로 인정
                        avg_color = self._get_average_color(surface, cluster)
                        clusters[corner_name].append({
                            "pixels": cluster,
                            "size": len(cluster),
                            "color": avg_color,
                            "center": self._get_cluster_center(cluster)
                        })

                        print(f"  클러스터 발견: {len(cluster)}개 픽셀, RGB{avg_color[:3]}")

        return clusters

    def _find_connected_pixels(self, surface, start_x, start_y, target_color, visited,
                              area_x, area_y, area_w, area_h):
        """BFS로 연결된 같은 색상 픽셀 찾기"""
        width, height = surface.get_size()
        cluster = []
        queue = deque([(start_x, start_y)])
        visited.add((start_x, start_y))

        # 색상 유사도 임계값
        color_threshold = 30

        while queue:
            x, y = queue.popleft()
            cluster.append((x, y))

            # 4방향 이웃 검사
            for dx, dy in [(0, 1), (1, 0), (0, -1), (-1, 0)]:
                nx, ny = x + dx, y + dy

                # 영역 내에 있는지 확인
                if (nx < area_x or nx >= area_x + area_w or
                    ny < area_y or ny >= area_y + area_h):
                    continue

                # 이미지 경계 확인
                if nx < 0 or nx >= width or ny < 0 or ny >= height:
                    continue

                if (nx, ny) in visited:
                    continue

                # 색상 비교
                neighbor_color = surface.get_at((nx, ny))
                if self._colors_similar(target_color, neighbor_color, color_threshold):
                    visited.add((nx, ny))
                    queue.append((nx, ny))

        return cluster

    def _colors_similar(self, c1, c2, threshold):
        """두 색상이 유사한지 확인"""
        if c2.a < 100:  # 투명 픽셀
            return False

        diff = abs(c1.r - c2.r) + abs(c1.g - c2.g) + abs(c1.b - c2.b)
        return diff <= threshold

    def _get_average_color(self, surface, pixels):
        """클러스터의 평균 색상 계산"""
        if not pixels:
            return (0, 0, 0, 0)

        total_r, total_g, total_b, total_a = 0, 0, 0, 0
        for x, y in pixels:
            color = surface.get_at((x, y))
            total_r += color.r
            total_g += color.g
            total_b += color.b
            total_a += color.a

        count = len(pixels)
        return (total_r // count, total_g // count,
                total_b // count, total_a // count)

    def _get_cluster_center(self, pixels):
        """클러스터의 중심점 계산"""
        if not pixels:
            return (0, 0)

        total_x, total_y = 0, 0
        for x, y in pixels:
            total_x += x
            total_y += y

        return (total_x // len(pixels), total_y // len(pixels))

    def draw_frame_with_clusters(self, screen, frame_idx):
        """프레임과 클러스터 시각화"""

        if frame_idx >= len(self.frames):
            return

        x_base = 100
        y_base = 150

        # 원본 프레임
        frame = self.frames[frame_idx]

        # 크게 확대 (15배)
        scale_factor = 15
        width, height = frame.get_size()
        scaled_size_w = width * scale_factor
        scaled_size_h = height * scale_factor

        # 확대된 이미지
        scaled = pygame.transform.scale(frame, (scaled_size_w, scaled_size_h))
        screen.blit(scaled, (x_base, y_base))

        # 외곽선
        pygame.draw.rect(screen, WHITE, (x_base, y_base, scaled_size_w, scaled_size_h), 1)

        # 클러스터 표시
        if frame_idx < len(self.corner_clusters):
            clusters = self.corner_clusters[frame_idx]

            # 색상별로 다른 테두리 색
            corner_colors = {
                "TL": YELLOW,
                "TR": CYAN,
                "BL": MAGENTA,
                "BR": GREEN
            }

            for corner_name, cluster_list in clusters.items():
                border_color = corner_colors.get(corner_name, WHITE)

                for cluster in cluster_list:
                    # 각 픽셀 하이라이트
                    for px, py in cluster["pixels"]:
                        screen_x = x_base + px * scale_factor
                        screen_y = y_base + py * scale_factor

                        # 픽셀 테두리
                        pygame.draw.rect(screen, border_color,
                                       (screen_x, screen_y, scale_factor, scale_factor), 2)

                    # 클러스터 중심 표시
                    cx, cy = cluster["center"]
                    center_x = x_base + cx * scale_factor + scale_factor // 2
                    center_y = y_base + cy * scale_factor + scale_factor // 2
                    pygame.draw.circle(screen, border_color, (center_x, center_y), 3)

        # 프레임 정보
        title = font_medium.render(f"Frame {frame_idx} - 색상 클러스터 분석", True, WHITE)
        screen.blit(title, (x_base, y_base - 30))

        # 클러스터 정보 표시
        info_x = x_base + scaled_size_w + 30
        info_y = y_base

        info_title = font_medium.render("클러스터 정보:", True, WHITE)
        screen.blit(info_title, (info_x, info_y))
        info_y += 30

        if frame_idx < len(self.corner_clusters):
            clusters = self.corner_clusters[frame_idx]

            for corner_name in ["TL", "TR", "BL", "BR"]:
                corner_label = font_small.render(f"{corner_name}:", True, CYAN)
                screen.blit(corner_label, (info_x, info_y))
                info_y += 20

                if corner_name in clusters:
                    for i, cluster in enumerate(clusters[corner_name]):
                        color = cluster["color"]
                        size = cluster["size"]

                        # 색상 박스
                        pygame.draw.rect(screen, color[:3], (info_x + 20, info_y, 20, 15))
                        pygame.draw.rect(screen, WHITE, (info_x + 20, info_y, 20, 15), 1)

                        # 정보
                        text = f"RGB({color[0]}, {color[1]}, {color[2]}) - {size}px"
                        label = font_tiny.render(text, True, (200, 200, 200))
                        screen.blit(label, (info_x + 45, info_y + 2))

                        info_y += 18
                else:
                    no_cluster = font_tiny.render("클러스터 없음", True, (150, 150, 150))
                    screen.blit(no_cluster, (info_x + 20, info_y))
                    info_y += 18

                info_y += 10

def main():
    """메인 실행 함수"""
    analyzer = CornerClusterAnalyzer()
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
        title = font_large.render("PNG 모서리 색상 클러스터 분석", True, WHITE)
        title_rect = title.get_rect(center=(WIDTH // 2, 40))
        SCREEN.blit(title, title_rect)

        desc = font_medium.render("같은 색상의 연결된 픽셀 그룹이 하나의 점을 형성", True, (200, 200, 200))
        desc_rect = desc.get_rect(center=(WIDTH // 2, 70))
        SCREEN.blit(desc, desc_rect)

        # 프레임과 클러스터 표시
        analyzer.draw_frame_with_clusters(SCREEN, current_frame)

        # 조작 안내
        control = font_small.render("←→: 프레임 선택 | 0-7: 직접 선택 | ESC: 종료", True, (150, 150, 150))
        control_rect = control.get_rect(center=(WIDTH // 2, HEIGHT - 20))
        SCREEN.blit(control, control_rect)

        # 범례
        legend_y = HEIGHT - 100
        legend = font_small.render("테두리 색상: ", True, WHITE)
        SCREEN.blit(legend, (50, legend_y))

        corner_colors = [
            ("TL", YELLOW),
            ("TR", CYAN),
            ("BL", MAGENTA),
            ("BR", GREEN)
        ]

        for i, (name, color) in enumerate(corner_colors):
            pygame.draw.rect(SCREEN, color, (150 + i * 80, legend_y - 2, 20, 15))
            label = font_small.render(name, True, color)
            SCREEN.blit(label, (175 + i * 80, legend_y))

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()