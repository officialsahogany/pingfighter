"""
라그나로크 해머 - 완전한 파츠 분리 분석
모든 시각 요소를 개별 레이어로 완전히 분리
"""
import pygame
import math
import sys
import os

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1400, 900
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("라그나로크 해머 - 완전한 파츠 분리")

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

class RagnarokHammerParts:
    """라그나로크 해머 파츠별 분리 클래스"""

    def __init__(self):
        self.animation_time = 0
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8
        self.hammer_frames = []
        self._load_hammer_frames()

    def _load_hammer_frames(self):
        """해머 프레임 로드 (시뮬레이션)"""
        # 실제로는 PNG 파일을 로드하지만, 여기서는 시뮬레이션
        for i in range(8):
            frame = pygame.Surface((60, 60), pygame.SRCALPHA)
            # 간단한 해머 그리기
            hammer_color = (200 - i*10, 100 + i*5, 50)
            # 해머 헤드
            pygame.draw.rect(frame, hammer_color, (15, 10, 30, 20))
            # 해머 손잡이
            pygame.draw.rect(frame, (100, 50, 30), (25, 25, 10, 30))
            # 번개 효과 (특정 프레임)
            if i in [0, 4]:
                pygame.draw.line(frame, (255, 255, 150), (10, 5), (20, 25), 2)
                pygame.draw.line(frame, (255, 255, 150), (40, 5), (35, 25), 2)
            self.hammer_frames.append(frame)

    def update(self, dt):
        """애니메이션 업데이트"""
        self.animation_time += dt * 0.001
        self.frame_counter += 1
        if self.frame_counter >= self.animation_speed:
            self.frame_counter = 0
            self.current_frame = (self.current_frame + 1) % 8

    def draw_part_1_hammer(self, screen, x, y, size):
        """Part 1: 해머 아이콘 (PNG)"""
        if self.hammer_frames:
            frame = self.hammer_frames[self.current_frame]
            scaled = pygame.transform.scale(frame, (size, size))
            screen.blit(scaled, (x, y))

    def draw_part_2_blue_glow(self, screen, x, y, size):
        """Part 2: 파란색 펄싱 글로우"""
        glow_intensity = 0.5 + 0.5 * math.sin(self.animation_time * 2)
        center = (x + size // 2, y + size // 2)

        # 3층 원형 글로우
        for i in range(3):
            radius = size // 2 - 2 - i * 3
            if radius > 0:
                color = (
                    min(255, 30 + i * 40),
                    min(255, 90 + i * 50),
                    min(255, 170 + i * 30)
                )
                # 투명도 적용
                s = pygame.Surface((size, size), pygame.SRCALPHA)
                pygame.draw.circle(s, (*color, int(100 * glow_intensity * (1 - i * 0.3))),
                                 (size//2, size//2), radius)
                screen.blit(s, (x, y))

    def draw_part_3_red_inner_borders(self, screen, x, y, size):
        """Part 3: 붉은색 내부 테두리 (3중)"""
        for i in range(3):
            border_alpha = 0.5 + 0.5 * math.sin(self.animation_time * 4 + i * 0.5)
            border_color = (
                int(150 + 70 * border_alpha - i * 20),
                int(20 + 20 * border_alpha - i * 10),
                int(20 + 20 * border_alpha - i * 10)
            )
            pygame.draw.rect(screen, border_color,
                           (x + 2 + i, y + 2 + i,
                            size - 4 - i * 2, size - 4 - i * 2), 1)

    def draw_part_4_silver_frame(self, screen, x, y, size):
        """Part 4: 은색-파란색 프레임"""
        frame_color = (180, 200, 255)
        pygame.draw.rect(screen, frame_color, (x, y, size, size), 2)

    def draw_part_5_golden_corners(self, screen, x, y, size):
        """Part 5: 황금색 코너 장식"""
        corner_color = (255, 215, 0)
        corner_size = 8

        # L자 형태 코너 (4개 모서리)
        corners = [
            # Top-left
            [(x, y + corner_size), (x, y), (x + corner_size, y)],
            # Top-right
            [(x + size - corner_size, y), (x + size - 1, y),
             (x + size - 1, y + corner_size)],
            # Bottom-left
            [(x, y + size - corner_size), (x, y + size - 1),
             (x + corner_size, y + size - 1)],
            # Bottom-right
            [(x + size - corner_size, y + size - 1),
             (x + size - 1, y + size - 1),
             (x + size - 1, y + size - corner_size)]
        ]

        for corner in corners:
            pygame.draw.lines(screen, corner_color, False, corner, 2)

        # 코너 장식 점
        dots = [
            (x + corner_size + 3, y + corner_size + 3),
            (x + size - corner_size - 3, y + corner_size + 3),
            (x + corner_size + 3, y + size - corner_size - 3),
            (x + size - corner_size - 3, y + size - corner_size - 3)
        ]

        for dot in dots:
            pygame.draw.circle(screen, corner_color, dot, 2)

    def draw_part_6_red_pulsing_border(self, screen, x, y, size):
        """Part 6: 빨간색 펄싱 외곽 테두리"""
        border_intensity = 0.5 + 0.5 * math.sin(self.animation_time * 3)
        border_color = (
            int(127 + 128 * border_intensity),
            0,
            0
        )
        pygame.draw.rect(screen, border_color, (x, y, size, size), 3)

    def draw_part_7_corner_dots(self, screen, x, y, size):
        """Part 7: 4개 모서리 흰점"""
        corners = [
            (x, y),
            (x + size - 1, y),
            (x, y + size - 1),
            (x + size - 1, y + size - 1)
        ]

        for cx, cy in corners:
            # 흰색 점
            pygame.draw.circle(screen, WHITE, (cx, cy), 3)
            # 빨간색 글로우
            for i in range(1, 3):
                alpha = 0.3 / i
                glow_color = (
                    int(255 * alpha),
                    int(100 * alpha),
                    int(100 * alpha)
                )
                pygame.draw.circle(screen, glow_color, (cx, cy), 3 + i, 1)

    def draw_part_8_floating_motion(self, screen, x, y, size, part_drawer):
        """Part 8: 상하 움직임 (다른 파츠에 적용)"""
        float_offset = math.sin(self.animation_time * 2) * 2
        part_drawer(screen, x, y + float_offset, size)

    def draw_all_combined(self, screen, x, y, size):
        """모든 파츠 결합"""
        # 상하 움직임 적용
        float_offset = math.sin(self.animation_time * 2) * 2
        y = y + float_offset

        # 레이어 순서대로 그리기
        self.draw_part_2_blue_glow(screen, x, y, size)
        self.draw_part_3_red_inner_borders(screen, x, y, size)
        self.draw_part_1_hammer(screen, x, y, size)
        self.draw_part_4_silver_frame(screen, x, y, size)
        self.draw_part_5_golden_corners(screen, x, y, size)
        self.draw_part_6_red_pulsing_border(screen, x, y, size)
        self.draw_part_7_corner_dots(screen, x, y, size)

def main():
    """메인 실행 함수"""
    hammer_parts = RagnarokHammerParts()
    clock = pygame.time.Clock()
    running = True

    # 파츠별 위치
    part_size = 80
    start_x = 50
    start_y = 100
    spacing_x = 150
    spacing_y = 150

    parts = [
        ("1. Hammer Icon", hammer_parts.draw_part_1_hammer),
        ("2. Blue Glow", hammer_parts.draw_part_2_blue_glow),
        ("3. Red Borders", hammer_parts.draw_part_3_red_inner_borders),
        ("4. Silver Frame", hammer_parts.draw_part_4_silver_frame),
        ("5. Golden Corners", hammer_parts.draw_part_5_golden_corners),
        ("6. Red Pulsing", hammer_parts.draw_part_6_red_pulsing_border),
        ("7. Corner Dots", hammer_parts.draw_part_7_corner_dots),
        ("8. Float Motion", None),  # 특별 처리
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
        title = font_title.render("라그나로크 해머 - 완전한 파츠 분리", True, WHITE)
        title_rect = title.get_rect(center=(WIDTH // 2, 30))
        SCREEN.blit(title, title_rect)

        # 애니메이션 업데이트
        hammer_parts.update(dt)

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
            if name == "8. Float Motion":
                # 상하 움직임은 예시로 박스만 표시
                example_y = y + math.sin(hammer_parts.animation_time * 2) * 2
                pygame.draw.rect(SCREEN, (100, 100, 255),
                               (x, example_y, part_size, part_size), 2)
            elif drawer:
                drawer(SCREEN, x, y, part_size)

            # 라벨
            label = font_label.render(name, True, WHITE)
            label_rect = label.get_rect(center=(x + part_size // 2, y + part_size + 15))
            SCREEN.blit(label, label_rect)

        # 결합된 결과
        combined_x = WIDTH - 250
        combined_y = 150
        combined_size = 150

        # 결합 섹션 배경
        pygame.draw.rect(SCREEN, (50, 50, 60),
                       (combined_x - 20, combined_y - 50,
                        combined_size + 40, combined_size + 100), 2)

        # 결합 제목
        combined_title = font_label.render("FINAL COMBINED", True, YELLOW)
        combined_title_rect = combined_title.get_rect(center=(combined_x + combined_size // 2, combined_y - 25))
        SCREEN.blit(combined_title, combined_title_rect)

        # 결합된 아이콘
        hammer_parts.draw_all_combined(SCREEN, combined_x, combined_y, combined_size)

        # 레이어 순서 설명
        layer_title = font_label.render("Layer Order (Bottom → Top):", True, WHITE)
        SCREEN.blit(layer_title, (50, HEIGHT - 280))

        layers = [
            "1. Blue Pulsing Glow (배경)",
            "2. Red Inner Borders (내부 테두리)",
            "3. Hammer Icon (해머 PNG)",
            "4. Silver-Blue Frame (은색 프레임)",
            "5. Golden Corners (황금 코너)",
            "6. Red Pulsing Border (외곽 테두리)",
            "7. Corner Dots (모서리 점)",
            "8. Floating Motion (전체 움직임)"
        ]

        for i, layer in enumerate(layers):
            color = (200, 200, 200) if i < 7 else (100, 200, 255)
            layer_text = font_small.render(layer, True, color)
            SCREEN.blit(layer_text, (70, HEIGHT - 250 + i * 25))

        # 특징 설명
        feature_title = font_label.render("Animation Features:", True, WHITE)
        SCREEN.blit(feature_title, (WIDTH // 2 + 50, HEIGHT - 280))

        features = [
            f"Frame: {hammer_parts.current_frame + 1}/8",
            f"Pulsing: {math.sin(hammer_parts.animation_time * 3):.2f}",
            f"Float Y: {math.sin(hammer_parts.animation_time * 2) * 2:.1f}px",
            "Glow: 3-layer circular",
            "Borders: 3-layer gradient",
            "Corners: L-shape + dots"
        ]

        for i, feature in enumerate(features):
            feature_text = font_small.render(feature, True, (180, 180, 180))
            SCREEN.blit(feature_text, (WIDTH // 2 + 70, HEIGHT - 250 + i * 25))

        # 조작 안내
        info = font_small.render("ESC: Exit | Animation is running at 60 FPS", True, (120, 120, 120))
        SCREEN.blit(info, (WIDTH // 2 - 150, HEIGHT - 30))

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()