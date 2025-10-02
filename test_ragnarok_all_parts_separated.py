"""
라그나로크 해머 - 모든 파츠 완전 분리
실제 게임 코드의 모든 구성 요소를 개별적으로 표시
"""
import pygame
import math
import sys
import os

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1600, 900
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("라그나로크 해머 - 모든 파츠 완전 분리")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
YELLOW = (255, 215, 0)
RED = (255, 0, 0)
BLUE = (0, 100, 255)

# 폰트 설정
font_title = pygame.font.Font(None, 32)
font_label = pygame.font.Font(None, 20)
font_small = pygame.font.Font(None, 16)

# 리소스 경로 헬퍼
def resource_path(relative_path):
    """Get absolute path to resource"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

class RagnarokParts:
    """라그나로크 해머의 모든 파츠를 분리"""

    def __init__(self):
        self.animation_time = 0
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8
        self.hammer_frames = []
        self.glow_cache = {}
        self._load_hammer_frames()

    def _load_hammer_frames(self):
        """실제 PNG 프레임 로드"""
        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                frame = pygame.image.load(frame_path).convert_alpha()
                # 붉은 배경 제거
                cleaned = self._strip_red_background(frame)
                self.hammer_frames.append(cleaned)
                print(f"✓ 라그나로크 프레임 {i} 로드 성공")
            except Exception as e:
                print(f"✗ 프레임 {i} 로드 실패: {e}")
                # 대체 프레임 생성
                fallback = pygame.Surface((60, 60), pygame.SRCALPHA)
                self._draw_fallback_hammer(fallback, i)
                self.hammer_frames.append(fallback)

    def _strip_red_background(self, frame):
        """PNG의 붉은 배경 제거"""
        cleaned = pygame.Surface(frame.get_size(), pygame.SRCALPHA)
        width, height = frame.get_size()
        for y in range(height):
            for x in range(width):
                color = frame.get_at((x, y))
                if color.a == 0:
                    continue
                # 붉은색 배경 제거
                if color.r > 150 and color.g < 100 and color.b < 100:
                    continue
                cleaned.set_at((x, y), color)
        return cleaned

    def _draw_fallback_hammer(self, surface, frame_idx):
        """대체 해머 그리기"""
        hammer_color = (200 - frame_idx*10, 100 + frame_idx*5, 50)
        # 해머 헤드
        pygame.draw.rect(surface, hammer_color, (15, 10, 30, 20))
        # 해머 손잡이
        pygame.draw.rect(surface, (100, 50, 30), (25, 25, 10, 30))

    def update(self, dt):
        """애니메이션 업데이트"""
        self.animation_time += dt * 0.001
        self.frame_counter += 1
        if self.frame_counter >= self.animation_speed:
            self.frame_counter = 0
            self.current_frame = (self.current_frame + 1) % 8

    # === 파츠 1: 파란색 원형 글로우 (3층 펄싱) ===
    def draw_part1_blue_glow(self, screen, x, y, size):
        """파란색 원형 글로우 - 3층 펄싱 효과"""
        pulse = (math.sin(self.animation_time * 4.0) + 1) / 2

        # 캐시 키 (성능 최적화)
        pulse_bucket = int(pulse * 20)
        cache_key = (size, pulse_bucket)

        if cache_key not in self.glow_cache:
            # 글로우 서페이스 생성
            glow_surface = pygame.Surface((size, size), pygame.SRCALPHA)
            center = (size // 2, size // 2)

            base_radius = max(6, int(size * 0.42))
            outer_radius = min(size // 2, int(base_radius + size * 0.05 * pulse))
            middle_radius = int(outer_radius * 0.85)
            inner_radius = max(4, int(outer_radius * 0.65))

            # 3층 원형 글로우
            pygame.draw.circle(glow_surface, (30, 90, 170, 80), center, outer_radius)
            pygame.draw.circle(glow_surface, (70, 140, 200, 150), center, middle_radius)
            pygame.draw.circle(glow_surface, (140, 190, 220, 190), center, inner_radius)

            self.glow_cache[cache_key] = glow_surface

        screen.blit(self.glow_cache[cache_key], (x, y))

    # === 파츠 2: 붉은색 내부 테두리 (3중 그라데이션) ===
    def draw_part2_red_inner_borders(self, screen, x, y, size):
        """붉은색 내부 테두리 - 3중 그라데이션"""
        inner_pulse = (math.sin(self.animation_time * 6.0) + 1) / 2

        # 3중 테두리 색상 (그라데이션)
        outer_color = (
            int(150 + 70 * inner_pulse),
            int(30 + 35 * inner_pulse),
            int(30 + 35 * inner_pulse)
        )
        middle_color = (
            int(135 + 65 * inner_pulse),
            int(20 + 30 * inner_pulse),
            int(20 + 30 * inner_pulse)
        )
        inner_color = (
            int(120 + 60 * inner_pulse),
            int(10 + 25 * inner_pulse),
            int(10 + 25 * inner_pulse)
        )

        # 3중 테두리 그리기
        pygame.draw.rect(screen, outer_color, (x + 2, y + 2, size - 4, size - 4), 1)
        pygame.draw.rect(screen, middle_color, (x + 3, y + 3, size - 6, size - 6), 1)
        pygame.draw.rect(screen, inner_color, (x + 4, y + 4, size - 8, size - 8), 1)

    # === 파츠 3: 은색-파란색 외곽 프레임 ===
    def draw_part3_silver_blue_frame(self, screen, x, y, size):
        """은색-파란색 외곽 프레임"""
        frame_color = (180, 200, 255)  # 은색-파란색
        pygame.draw.rect(screen, frame_color, (x - 1, y - 1, size + 2, size + 2), 2)

    # === 파츠 4: 황금색 L자 코너 장식 ===
    def draw_part4_golden_corners(self, screen, x, y, size):
        """황금색 L자 코너 장식"""
        corner_color = (255, 215, 0)  # 황금색
        corner_size = 8

        # Top-left L자
        pygame.draw.lines(screen, corner_color, False,
                         [(x - 2, y + corner_size), (x - 2, y - 2), (x + corner_size, y - 2)], 2)

        # Top-right L자
        pygame.draw.lines(screen, corner_color, False,
                         [(x + size - corner_size + 2, y - 2), (x + size + 2, y - 2),
                          (x + size + 2, y + corner_size)], 2)

        # Bottom-left L자
        pygame.draw.lines(screen, corner_color, False,
                         [(x - 2, y + size - corner_size + 2), (x - 2, y + size + 2),
                          (x + corner_size, y + size + 2)], 2)

        # Bottom-right L자
        pygame.draw.lines(screen, corner_color, False,
                         [(x + size - corner_size + 2, y + size + 2), (x + size + 2, y + size + 2),
                          (x + size + 2, y + size - corner_size + 2)], 2)

    # === 파츠 5: 황금색 코너 점 ===
    def draw_part5_corner_dots(self, screen, x, y, size):
        """황금색 코너 점 (4개)"""
        corner_color = (255, 215, 0)

        # 4개 모서리에 점
        corners = [
            (x, y),                      # Top-left
            (x + size, y),              # Top-right
            (x, y + size),              # Bottom-left
            (x + size, y + size)        # Bottom-right
        ]

        for cx, cy in corners:
            pygame.draw.circle(screen, corner_color, (cx, cy), 2)

    # === 파츠 6: PNG 애니메이션 프레임 ===
    def draw_part6_png_frames(self, screen, x, y, size):
        """실제 PNG 애니메이션 프레임 (8장)"""
        if self.hammer_frames:
            current_icon = self.hammer_frames[self.current_frame % len(self.hammer_frames)]
            scaled_icon = pygame.transform.scale(current_icon, (size, size))
            screen.blit(scaled_icon, (x, y))

    # === 파츠 7: 번개 효과 ===
    def draw_part7_lightning_effect(self, screen, x, y, size):
        """번개 효과 (프레임 0, 4에서만)"""
        if self.current_frame in [0, 4]:
            bolt_color = (255, 255, 150)
            # 왼쪽 번개
            pygame.draw.line(screen, bolt_color,
                           (x + size // 4, y - 5),
                           (x + size // 3, y + size // 4), 2)
            # 오른쪽 번개
            pygame.draw.line(screen, bolt_color,
                           (x + size * 3 // 4, y - 5),
                           (x + size * 2 // 3, y + size // 4), 2)

    # === 파츠 8: 상하 움직임 효과 ===
    def get_floating_offset(self):
        """상하 움직임 오프셋 계산"""
        return int(math.sin(self.animation_time * 2.5) * 2)

    def draw_part8_floating_motion(self, screen, x, y, size):
        """상하 움직임 효과 시각화"""
        offset = self.get_floating_offset()
        # 움직임을 보여주는 박스
        pygame.draw.rect(screen, (100, 100, 255),
                        (x, y + offset, size, size), 2)
        # 움직임 화살표
        mid_x = x + size // 2
        if offset > 0:
            pygame.draw.polygon(screen, (100, 200, 255),
                              [(mid_x - 5, y - 10), (mid_x + 5, y - 10), (mid_x, y - 5)])
        else:
            pygame.draw.polygon(screen, (100, 200, 255),
                              [(mid_x - 5, y + size + 10), (mid_x + 5, y + size + 10),
                               (mid_x, y + size + 5)])

    # === 모든 파츠 결합 ===
    def draw_all_combined(self, screen, x, y, size):
        """모든 파츠를 결합한 완전체"""
        offset = self.get_floating_offset()
        y_with_offset = y + offset

        # 레이어 순서대로 그리기
        self.draw_part1_blue_glow(screen, x, y_with_offset, size)
        self.draw_part2_red_inner_borders(screen, x, y_with_offset, size)
        self.draw_part6_png_frames(screen, x, y_with_offset, size)
        self.draw_part3_silver_blue_frame(screen, x, y_with_offset, size)
        self.draw_part4_golden_corners(screen, x, y_with_offset, size)
        self.draw_part5_corner_dots(screen, x, y_with_offset, size)
        self.draw_part7_lightning_effect(screen, x, y_with_offset, size)

def main():
    """메인 실행 함수"""
    ragnarok_parts = RagnarokParts()
    clock = pygame.time.Clock()
    running = True

    # 파츠별 위치
    part_size = 80
    start_x = 50
    start_y = 100
    spacing_x = 180
    spacing_y = 150

    parts = [
        ("1. Blue Glow (3층)", ragnarok_parts.draw_part1_blue_glow),
        ("2. Red Borders (3중)", ragnarok_parts.draw_part2_red_inner_borders),
        ("3. Silver-Blue Frame", ragnarok_parts.draw_part3_silver_blue_frame),
        ("4. Golden L-Corners", ragnarok_parts.draw_part4_golden_corners),
        ("5. Corner Dots", ragnarok_parts.draw_part5_corner_dots),
        ("6. PNG Frames (8장)", ragnarok_parts.draw_part6_png_frames),
        ("7. Lightning Effect", ragnarok_parts.draw_part7_lightning_effect),
        ("8. Floating Motion", ragnarok_parts.draw_part8_floating_motion),
    ]

    while running:
        dt = clock.tick(60)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

        # 화면 클리어
        SCREEN.fill((20, 20, 30))

        # 제목
        title = font_title.render("라그나로크 해머 - 모든 파츠 완전 분리", True, WHITE)
        title_rect = title.get_rect(center=(WIDTH // 2, 30))
        SCREEN.blit(title, title_rect)

        # 애니메이션 업데이트
        ragnarok_parts.update(dt)

        # 개별 파츠 그리기
        for i, (name, drawer) in enumerate(parts):
            row = i // 4
            col = i % 4
            x = start_x + col * spacing_x
            y = start_y + row * spacing_y

            # 배경 박스
            pygame.draw.rect(SCREEN, (40, 40, 50),
                           (x - 10, y - 10, part_size + 20, part_size + 40), 1)

            # 파츠 그리기
            drawer(SCREEN, x, y, part_size)

            # 라벨
            label = font_label.render(name, True, WHITE)
            label_rect = label.get_rect(center=(x + part_size // 2, y + part_size + 15))
            SCREEN.blit(label, label_rect)

        # 결합된 결과 (큰 크기)
        combined_x = WIDTH - 350
        combined_y = 150
        combined_size = 200

        # 결합 섹션 배경
        pygame.draw.rect(SCREEN, (50, 50, 60),
                       (combined_x - 20, combined_y - 50,
                        combined_size + 40, combined_size + 100), 2)

        # 결합 제목
        combined_title = font_label.render("COMPLETE RAGNAROK", True, YELLOW)
        combined_title_rect = combined_title.get_rect(center=(combined_x + combined_size // 2, combined_y - 25))
        SCREEN.blit(combined_title, combined_title_rect)

        # 결합된 아이콘
        ragnarok_parts.draw_all_combined(SCREEN, combined_x, combined_y, combined_size)

        # 레이어 순서 설명
        layer_title = font_label.render("Layer Order (Bottom → Top):", True, WHITE)
        SCREEN.blit(layer_title, (50, HEIGHT - 320))

        layers = [
            "1. Blue Glow (파란색 3층 원형 글로우)",
            "2. Red Inner Borders (붉은색 3중 그라데이션)",
            "3. PNG Animation Frame (해머 PNG 8장)",
            "4. Silver-Blue Frame (은색-파란색 외곽)",
            "5. Golden L-Corners (황금색 L자 코너)",
            "6. Corner Dots (황금색 모서리 점 4개)",
            "7. Lightning Effect (번개 - 프레임 0, 4)",
            "8. Floating Motion (상하 2픽셀 움직임)"
        ]

        for i, layer in enumerate(layers):
            color = (200, 200, 200) if i < 6 else (255, 255, 100)
            layer_text = font_small.render(layer, True, color)
            SCREEN.blit(layer_text, (70, HEIGHT - 290 + i * 30))

        # 현재 상태
        status_lines = [
            f"Frame: {ragnarok_parts.current_frame + 1}/8",
            f"Animation Time: {ragnarok_parts.animation_time:.2f}",
            f"Float Offset: {ragnarok_parts.get_floating_offset()}px",
            f"Lightning Active: {'Yes' if ragnarok_parts.current_frame in [0, 4] else 'No'}"
        ]

        for i, line in enumerate(status_lines):
            status_text = font_small.render(line, True, (180, 180, 180))
            SCREEN.blit(status_text, (WIDTH // 2 + 100, HEIGHT - 200 + i * 25))

        # 조작 안내
        info = font_small.render("ESC: Exit | Animation running at 60 FPS", True, (120, 120, 120))
        SCREEN.blit(info, (WIDTH // 2 - 150, HEIGHT - 30))

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()