"""
라그나로크 해머 실제 코너 클러스터 구현
게임에서 실제로 사용되는 4개 코너 하이라이트
"""
import pygame
import sys
import os
import math

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1200, 800
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("라그나로크 해머 - 실제 코너 클러스터 구현")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
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

class RagnarokCornerClusters:
    """라그나로크 해머 코너 클러스터 시스템"""

    def __init__(self):
        self.frames = []
        self.current_frame = 0
        self.animation_timer = 0
        self.animation_speed = 100  # 100ms per frame

        # 코너 클러스터 색상 (PNG에서 추출한 실제 색상)
        self.cluster_colors = [
            (246, 246, 255),  # Frame 0,4: 밝은 파란-흰색
            (229, 229, 255),  # Frame 1,5: 연한 파란색
            (153, 153, 255),  # Frame 2,6: 중간 파란색
            (170, 170, 255),  # Frame 3,7: 진한 파란색
        ]

        self._load_frames()

    def _load_frames(self):
        """PNG 프레임 로드"""
        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                original = pygame.image.load(frame_path).convert_alpha()
                self.frames.append(original)
            except Exception as e:
                print(f"✗ 프레임 {i} 로드 실패: {e}")
                empty = pygame.Surface((32, 32), pygame.SRCALPHA)
                self.frames.append(empty)

    def update(self, dt):
        """애니메이션 업데이트"""
        self.animation_timer += dt
        if self.animation_timer >= self.animation_speed:
            self.animation_timer = 0
            self.current_frame = (self.current_frame + 1) % 8

    def draw_corner_clusters(self, screen, x, y, size):
        """코너 클러스터만 그리기 (실제 게임 구현)"""

        # 현재 프레임 색상 선택
        color_index = self.current_frame % 4
        cluster_color = self.cluster_colors[color_index]

        # 프레임 5,7에서는 약간 어둡게
        if self.current_frame in [5, 7]:
            cluster_color = tuple(max(0, c - 30) for c in cluster_color)

        # 펄스 효과 (살짝 밝기 변화)
        pulse = abs(math.sin(pygame.time.get_ticks() / 500)) * 0.3
        pulsed_color = tuple(min(255, int(c * (1 + pulse))) for c in cluster_color)

        # 클러스터 크기 (픽셀 수를 시각적 크기로 변환)
        cluster_sizes = {
            "TL": 8,   # 8픽셀 클러스터
            "TR": 10,  # 10픽셀 클러스터
            "BL": 10,  # 10픽셀 클러스터
            "BR": 12,  # 12픽셀 클러스터
        }

        # 각 코너에 클러스터 그리기
        corners = {
            "TL": (x, y),
            "TR": (x + size - 1, y),
            "BL": (x, y + size - 1),
            "BR": (x + size - 1, y + size - 1)
        }

        for corner_name, corner_pos in corners.items():
            cluster_size = cluster_sizes[corner_name]

            # 클러스터 크기를 시각적 반경으로 변환 (픽셀수 / 4)
            visual_radius = cluster_size // 2

            # 클러스터 그리기 (여러 픽셀이 모인 형태)
            self._draw_cluster_shape(screen, corner_pos[0], corner_pos[1],
                                    visual_radius, pulsed_color, cluster_size)

    def _draw_cluster_shape(self, screen, cx, cy, radius, color, pixel_count):
        """실제 클러스터 모양 그리기 (픽셀들이 모인 형태)"""

        # 클러스터 패턴 (픽셀 수에 따라 다른 모양)
        if pixel_count == 8:  # TL - 8픽셀
            # 2x4 형태
            offsets = [(-1,-2), (0,-2), (-1,-1), (0,-1),
                      (-1,0), (0,0), (-1,1), (0,1)]
        elif pixel_count == 10:  # TR, BL - 10픽셀
            # 십자 형태
            offsets = [(0,-2), (-1,-1), (0,-1), (1,-1),
                      (-1,0), (0,0), (1,0),
                      (0,1), (-1,1), (1,1)]
        else:  # BR - 12픽셀
            # 3x4 형태
            offsets = [(-1,-2), (0,-2), (1,-2),
                      (-1,-1), (0,-1), (1,-1),
                      (-1,0), (0,0), (1,0),
                      (-1,1), (0,1), (1,1)]

        # 각 픽셀 그리기
        pixel_size = 3  # 각 픽셀 크기
        for ox, oy in offsets:
            px = cx + ox * pixel_size
            py = cy + oy * pixel_size

            # 중심 픽셀은 더 밝게
            if ox == 0 and oy == 0:
                bright_color = tuple(min(255, c + 30) for c in color)
                pygame.draw.rect(screen, bright_color,
                               (px, py, pixel_size, pixel_size))
            else:
                pygame.draw.rect(screen, color,
                               (px, py, pixel_size, pixel_size))

            # 테두리
            pygame.draw.rect(screen, tuple(c//2 for c in color),
                           (px, py, pixel_size, pixel_size), 1)

    def draw_full_ragnarok_with_clusters(self, screen, x, y, size):
        """전체 라그나로크 해머와 코너 클러스터"""

        # 1. 파란색 글로우 (뒤쪽)
        glow_surf = pygame.Surface((size + 60, size + 60), pygame.SRCALPHA)
        glow_radius = size // 2 + 20
        for i in range(20, 0, -1):
            alpha = int(100 * (i / 20))
            color = (*tuple(int(c * (i/20)) for c in (100, 150, 255)), alpha)
            pygame.draw.circle(glow_surf, color,
                             (glow_surf.get_width() // 2, glow_surf.get_height() // 2),
                             glow_radius + i)
        screen.blit(glow_surf, (x - 30, y - 30))

        # 2. 빨간 테두리
        for i in range(3):
            pygame.draw.rect(screen, (150 - i*30, 0, 0),
                           (x - 5 - i*2, y - 5 - i*2,
                            size + 10 + i*4, size + 10 + i*4), 2)

        # 3. PNG 프레임
        if self.current_frame < len(self.frames):
            frame = self.frames[self.current_frame]
            scaled = pygame.transform.scale(frame, (size, size))
            screen.blit(scaled, (x, y))

        # 4. 은색 테두리
        pygame.draw.rect(screen, (192, 192, 192), (x-2, y-2, size+4, size+4), 2)

        # 5. 코너 클러스터 (중요!)
        self.draw_corner_clusters(screen, x, y, size)

        # 6. 외부 코너 점들
        corner_positions = [(x-5, y-5), (x+size+5, y-5),
                          (x-5, y+size+5), (x+size+5, y+size+5)]
        for pos in corner_positions:
            pygame.draw.circle(screen, (255, 255, 255), pos, 3)

    def draw_comparison(self, screen):
        """비교 뷰 - 원본, 클러스터만, 전체"""

        y_pos = 300

        # 1. PNG 프레임만
        x = 200
        label = font_medium.render("PNG 프레임", True, WHITE)
        label_rect = label.get_rect(center=(x + 50, y_pos - 30))
        screen.blit(label, label_rect)

        if self.current_frame < len(self.frames):
            frame = self.frames[self.current_frame]
            scaled = pygame.transform.scale(frame, (100, 100))
            screen.blit(scaled, (x, y_pos))
        pygame.draw.rect(screen, (100, 100, 100), (x, y_pos, 100, 100), 1)

        # 2. 코너 클러스터만
        x = 500
        label = font_medium.render("코너 클러스터", True, WHITE)
        label_rect = label.get_rect(center=(x + 50, y_pos - 30))
        screen.blit(label, label_rect)

        # 빈 배경
        pygame.draw.rect(screen, (40, 40, 50), (x, y_pos, 100, 100))
        pygame.draw.rect(screen, (100, 100, 100), (x, y_pos, 100, 100), 1)

        # 클러스터만 그리기
        self.draw_corner_clusters(screen, x, y_pos, 100)

        # 3. 전체 효과
        x = 800
        label = font_medium.render("전체 라그나로크", True, WHITE)
        label_rect = label.get_rect(center=(x + 50, y_pos - 30))
        screen.blit(label, label_rect)

        self.draw_full_ragnarok_with_clusters(screen, x, y_pos, 100)

        # 설명
        info_y = y_pos + 150
        info_text = [
            "코너 클러스터 구성:",
            "• TL (왼쪽상단): 8픽셀 클러스터",
            "• TR (오른쪽상단): 10픽셀 클러스터",
            "• BL (왼쪽하단): 10픽셀 클러스터",
            "• BR (오른쪽하단): 12픽셀 클러스터",
            "",
            "색상: 파란-흰색 계열 (프레임별 변화)"
        ]

        for i, text in enumerate(info_text):
            label = font_small.render(text, True, (200, 200, 200))
            screen.blit(label, (WIDTH // 2 - 150, info_y + i * 25))

def main():
    """메인 실행 함수"""
    clusters = RagnarokCornerClusters()
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
                    clusters.current_frame = (clusters.current_frame + 1) % 8

        # 애니메이션 업데이트
        clusters.update(dt)

        # 화면 클리어
        SCREEN.fill(DARK_BG)

        # 제목
        title = font_large.render("라그나로크 해머 - 실제 코너 클러스터", True, WHITE)
        title_rect = title.get_rect(center=(WIDTH // 2, 40))
        SCREEN.blit(title, title_rect)

        # 현재 프레임
        frame_text = font_medium.render(f"Frame {clusters.current_frame}", True, WHITE)
        frame_rect = frame_text.get_rect(center=(WIDTH // 2, 80))
        SCREEN.blit(frame_text, frame_rect)

        # 비교 뷰
        clusters.draw_comparison(SCREEN)

        # 조작 안내
        control = font_small.render("SPACE: 수동 진행 | ESC: 종료", True, (150, 150, 150))
        control_rect = control.get_rect(center=(WIDTH // 2, HEIGHT - 20))
        SCREEN.blit(control, control_rect)

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()