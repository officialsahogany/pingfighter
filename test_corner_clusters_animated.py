"""
PNG 프레임 코너 클러스터 애니메이션
TL: 8픽셀 (노란색), TR: 10픽셀 (시안), BL: 10픽셀 (마젠타), BR: 12픽셀 (초록)
"""
import pygame
import sys
import os
from collections import deque

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1200, 800
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("PNG 코너 클러스터 애니메이션 - 4개 모서리 하이라이트")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
YELLOW = (255, 215, 0)
CYAN = (0, 255, 255)
MAGENTA = (255, 0, 255)
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

class CornerClusterAnimation:
    """코너 클러스터 애니메이션"""

    def __init__(self):
        self.frames = []
        self.corner_clusters = []  # 각 프레임의 코너 클러스터
        self.current_frame = 0
        self.animation_timer = 0
        self.animation_speed = 100  # 100ms per frame
        self._load_and_extract_clusters()

    def _load_and_extract_clusters(self):
        """PNG 프레임을 로드하고 코너 클러스터 추출"""
        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                # 원본 로드
                original = pygame.image.load(frame_path).convert_alpha()
                self.frames.append(original)

                # 코너 클러스터 추출
                clusters = self._extract_corner_clusters(original)
                self.corner_clusters.append(clusters)

            except Exception as e:
                print(f"✗ 프레임 {i} 로드 실패: {e}")
                empty = pygame.Surface((32, 32), pygame.SRCALPHA)
                self.frames.append(empty)
                self.corner_clusters.append({})

    def _extract_corner_clusters(self, surface):
        """정확한 코너 클러스터 추출 - 연결된 픽셀 그룹"""
        width, height = surface.get_size()

        clusters = {
            "TL": {"pixels": [], "color": None},
            "TR": {"pixels": [], "color": None},
            "BL": {"pixels": [], "color": None},
            "BR": {"pixels": [], "color": None}
        }

        # 각 모서리 영역 (10x10)
        corner_areas = {
            "TL": (0, 0, 10, 10),
            "TR": (width-10, 0, 10, 10),
            "BL": (0, height-10, 10, 10),
            "BR": (width-10, height-10, 10, 10)
        }

        for corner_name, (start_x, start_y, area_w, area_h) in corner_areas.items():
            # 가장 큰 클러스터 찾기
            visited = set()
            largest_cluster = []
            cluster_color = None

            for y in range(start_y, min(start_y + area_h, height)):
                for x in range(start_x, min(start_x + area_w, width)):
                    if (x, y) in visited:
                        continue

                    color = surface.get_at((x, y))

                    # 투명하거나 너무 어두운 픽셀 무시
                    if color.a < 100 or (color.r < 50 and color.g < 50 and color.b < 50):
                        continue

                    # 붉은색 배경 무시 (75, 0, 0)
                    if color.r == 75 and color.g == 0 and color.b == 0:
                        continue

                    # 연결된 픽셀 찾기 (BFS)
                    cluster = self._find_connected_pixels(surface, x, y, color, visited,
                                                         start_x, start_y, area_w, area_h)

                    # 가장 큰 클러스터 저장 (최소 2픽셀 이상)
                    if len(cluster) >= 2 and len(cluster) > len(largest_cluster):
                        largest_cluster = cluster
                        cluster_color = (color.r, color.g, color.b, color.a)

            clusters[corner_name]["pixels"] = largest_cluster
            clusters[corner_name]["color"] = cluster_color

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

    def update(self, dt):
        """애니메이션 업데이트"""
        self.animation_timer += dt
        if self.animation_timer >= self.animation_speed:
            self.animation_timer = 0
            self.current_frame = (self.current_frame + 1) % 8

    def draw_clusters_only(self, screen):
        """클러스터만 그리기 (프레임 없이)"""

        # 제목
        title = font_large.render("PNG 코너 클러스터 애니메이션", True, WHITE)
        title_rect = title.get_rect(center=(WIDTH // 2, 40))
        screen.blit(title, title_rect)

        # 프레임 번호
        frame_text = font_medium.render(f"Frame {self.current_frame}", True, WHITE)
        frame_rect = frame_text.get_rect(center=(WIDTH // 2, 80))
        screen.blit(frame_text, frame_rect)

        if self.current_frame >= len(self.corner_clusters):
            return

        clusters = self.corner_clusters[self.current_frame]

        # 중앙에 큰 사각형으로 클러스터 표시
        center_x, center_y = WIDTH // 2, HEIGHT // 2
        size = 300
        scale = 10  # 픽셀당 10배 확대

        # 배경 사각형
        pygame.draw.rect(screen, (40, 40, 50),
                        (center_x - size//2, center_y - size//2, size, size))
        pygame.draw.rect(screen, (100, 100, 100),
                        (center_x - size//2, center_y - size//2, size, size), 2)

        # 코너별 색상과 위치
        corner_info = {
            "TL": {"color": YELLOW, "label_pos": (-100, -100), "count": 8},
            "TR": {"color": CYAN, "label_pos": (100, -100), "count": 10},
            "BL": {"color": MAGENTA, "label_pos": (-100, 100), "count": 10},
            "BR": {"color": GREEN, "label_pos": (100, 100), "count": 12}
        }

        # 각 코너 클러스터 그리기
        for corner_name, cluster_data in clusters.items():
            if not cluster_data["pixels"]:
                continue

            corner_color = corner_info[corner_name]["color"]

            # 클러스터의 픽셀들을 확대해서 그리기
            for px, py in cluster_data["pixels"]:
                # 원본 32x32 이미지를 300x300 영역에 맞추기
                x = center_x - size//2 + (px * size // 32)
                y = center_y - size//2 + (py * size // 32)
                pixel_size = size // 32

                # 픽셀 그리기
                if cluster_data["color"]:
                    # 원본 색상으로 채우기
                    pygame.draw.rect(screen, cluster_data["color"][:3],
                                   (x, y, pixel_size, pixel_size))

                # 코너별 색상 테두리
                pygame.draw.rect(screen, corner_color,
                               (x, y, pixel_size, pixel_size), 2)

            # 라벨
            info = corner_info[corner_name]
            label_x = center_x + info["label_pos"][0]
            label_y = center_y + info["label_pos"][1]

            # 코너 이름과 픽셀 수
            label = font_medium.render(f"{corner_name}: {info['count']}px", True, corner_color)
            label_rect = label.get_rect(center=(label_x, label_y))
            screen.blit(label, label_rect)

            # 실제 색상 정보
            if cluster_data["color"]:
                color_rgb = cluster_data["color"][:3]
                color_text = font_small.render(f"RGB({color_rgb[0]}, {color_rgb[1]}, {color_rgb[2]})",
                                              True, (200, 200, 200))
                color_rect = color_text.get_rect(center=(label_x, label_y + 25))
                screen.blit(color_text, color_rect)

        # 범례
        legend_y = HEIGHT - 100
        legend_x = WIDTH // 2 - 200

        legend = font_medium.render("코너 클러스터:", True, WHITE)
        screen.blit(legend, (legend_x, legend_y))

        for i, (name, info) in enumerate(corner_info.items()):
            x = legend_x + 120 + i * 100
            # 색상 박스
            pygame.draw.rect(screen, info["color"], (x, legend_y, 30, 20))
            # 라벨
            label = font_small.render(f"{name} ({info['count']})", True, info["color"])
            screen.blit(label, (x + 35, legend_y + 2))

def main():
    """메인 실행 함수"""
    animation = CornerClusterAnimation()
    clock = pygame.time.Clock()
    running = True

    while running:
        dt = clock.tick(60)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 수동 프레임 진행
                    animation.current_frame = (animation.current_frame + 1) % 8
                elif event.key >= pygame.K_0 and event.key <= pygame.K_7:
                    # 특정 프레임 선택
                    animation.current_frame = event.key - pygame.K_0

        # 애니메이션 업데이트
        animation.update(dt)

        # 화면 클리어
        SCREEN.fill((30, 30, 50))

        # 클러스터만 그리기
        animation.draw_clusters_only(SCREEN)

        # 조작 안내
        control = font_small.render("SPACE: 수동 진행 | 0-7: 프레임 선택 | ESC: 종료", True, (150, 150, 150))
        control_rect = control.get_rect(center=(WIDTH // 2, HEIGHT - 20))
        SCREEN.blit(control, control_rect)

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()