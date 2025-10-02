"""
라그나로크 해머 - PNG 프레임 8장만 개별 표시
붉은 배경 제거된 순수 해머 이미지만 표시
"""
import pygame
import sys
import os

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1200, 700
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("라그나로크 해머 - PNG 프레임 8장")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
YELLOW = (255, 215, 0)
GRAY = (100, 100, 100)

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

class RagnarokFrames:
    """라그나로크 PNG 프레임 관리"""

    def __init__(self):
        self.frames_original = []  # 원본 프레임
        self.frames_cleaned = []   # 붉은 배경 제거된 프레임
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8  # 8틱마다 프레임 변경
        self._load_frames()

    def _load_frames(self):
        """PNG 프레임 로드"""
        print("라그나로크 해머 PNG 프레임 로딩 중...")

        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                # 원본 로드
                original = pygame.image.load(frame_path).convert_alpha()
                self.frames_original.append(original)

                # 붉은 배경 제거
                cleaned = self._remove_red_background(original)
                self.frames_cleaned.append(cleaned)

                print(f"✓ 프레임 {i} 로드 성공: {frame_path}")

            except Exception as e:
                print(f"✗ 프레임 {i} 로드 실패: {e}")

                # 대체 프레임 생성
                fallback = self._create_fallback_frame(i)
                self.frames_original.append(fallback)
                self.frames_cleaned.append(fallback)

        print(f"총 {len(self.frames_cleaned)}/8 프레임 로드 완료")

    def _remove_red_background(self, surface):
        """붉은색 배경 제거"""
        cleaned = pygame.Surface(surface.get_size(), pygame.SRCALPHA)
        width, height = surface.get_size()

        for y in range(height):
            for x in range(width):
                color = surface.get_at((x, y))

                # 투명 픽셀은 그대로
                if color.a == 0:
                    continue

                # 붉은색 배경 판별 (더 정교한 조건)
                is_red_bg = False

                # 순수 붉은색 배경
                if color.r > 150 and color.g < 100 and color.b < 100:
                    is_red_bg = True

                # 붉은색 링 효과 (가장자리)
                if (x < 8 or x >= width - 8 or y < 8 or y >= height - 8):
                    if color.r > color.g + 30 and color.r > color.b + 30:
                        is_red_bg = True

                # 배경이 아니면 복사
                if not is_red_bg:
                    cleaned.set_at((x, y), color)

        return cleaned

    def _create_fallback_frame(self, frame_idx):
        """대체 프레임 생성"""
        surface = pygame.Surface((60, 60), pygame.SRCALPHA)

        # 프레임별로 다른 색상
        colors = [
            (200, 100, 50),   # Frame 0
            (210, 105, 55),   # Frame 1
            (190, 95, 45),    # Frame 2
            (205, 110, 60),   # Frame 3
            (195, 100, 50),   # Frame 4
            (185, 90, 40),    # Frame 5
            (215, 115, 65),   # Frame 6
            (180, 85, 35),    # Frame 7
        ]

        hammer_color = colors[frame_idx % len(colors)]

        # 해머 헤드 그리기
        pygame.draw.rect(surface, hammer_color, (15, 10, 30, 20))
        pygame.draw.rect(surface, (150, 75, 37), (15, 10, 30, 20), 2)

        # 해머 손잡이
        handle_color = (100, 50, 30)
        pygame.draw.rect(surface, handle_color, (25, 25, 10, 30))
        pygame.draw.rect(surface, (80, 40, 20), (25, 25, 10, 30), 1)

        # 프레임 번호 표시
        font = pygame.font.Font(None, 12)
        num_text = font.render(str(frame_idx), True, WHITE)
        surface.blit(num_text, (5, 5))

        return surface

    def update(self):
        """애니메이션 업데이트"""
        self.frame_counter += 1
        if self.frame_counter >= self.animation_speed:
            self.frame_counter = 0
            self.current_frame = (self.current_frame + 1) % 8

def main():
    """메인 실행 함수"""
    frames = RagnarokFrames()
    clock = pygame.time.Clock()
    running = True

    # 표시 모드
    show_original = False  # False: 붉은 배경 제거, True: 원본

    while running:
        clock.tick(60)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    show_original = not show_original

        # 화면 클리어
        SCREEN.fill((30, 30, 50))

        # 제목
        title_text = font_large.render("라그나로크 해머 - PNG 애니메이션 프레임 (8장)", True, WHITE)
        title_rect = title_text.get_rect(center=(WIDTH // 2, 40))
        SCREEN.blit(title_text, title_rect)

        # 모드 표시
        mode_text = font_medium.render(
            f"모드: {'원본' if show_original else '붉은 배경 제거됨'} (SPACE키로 전환)",
            True, YELLOW
        )
        mode_rect = mode_text.get_rect(center=(WIDTH // 2, 80))
        SCREEN.blit(mode_text, mode_rect)

        # 애니메이션 업데이트
        frames.update()

        # 8개 프레임 개별 표시
        frame_size = 100
        spacing = 140
        start_x = (WIDTH - spacing * 4) // 2

        for i in range(8):
            row = i // 4
            col = i % 4
            x = start_x + col * spacing
            y = 150 + row * 180

            # 프레임 배경
            bg_color = (60, 60, 70) if i == frames.current_frame else (40, 40, 50)
            pygame.draw.rect(SCREEN, bg_color, (x - 10, y - 10, frame_size + 20, frame_size + 20))
            pygame.draw.rect(SCREEN, GRAY, (x - 10, y - 10, frame_size + 20, frame_size + 20), 1)

            # PNG 프레임 그리기
            frame_list = frames.frames_original if show_original else frames.frames_cleaned
            if i < len(frame_list):
                frame_img = frame_list[i]
                # 크기 조정
                scaled = pygame.transform.scale(frame_img, (frame_size, frame_size))
                SCREEN.blit(scaled, (x, y))

            # 프레임 번호
            frame_label = f"Frame {i}"
            if i == frames.current_frame:
                frame_label += " ◀"

            label_color = YELLOW if i == frames.current_frame else WHITE
            label_text = font_small.render(frame_label, True, label_color)
            label_rect = label_text.get_rect(center=(x + frame_size // 2, y + frame_size + 15))
            SCREEN.blit(label_text, label_rect)

        # 큰 애니메이션 미리보기
        preview_size = 200
        preview_x = WIDTH // 2 - preview_size // 2
        preview_y = HEIGHT - preview_size - 80

        # 미리보기 배경
        pygame.draw.rect(SCREEN, (50, 50, 60),
                        (preview_x - 20, preview_y - 20, preview_size + 40, preview_size + 60))
        pygame.draw.rect(SCREEN, (100, 100, 120),
                        (preview_x - 20, preview_y - 20, preview_size + 40, preview_size + 60), 2)

        # 현재 프레임 큰 크기로 표시
        frame_list = frames.frames_original if show_original else frames.frames_cleaned
        if frames.current_frame < len(frame_list):
            current = frame_list[frames.current_frame]
            scaled_preview = pygame.transform.scale(current, (preview_size, preview_size))
            SCREEN.blit(scaled_preview, (preview_x, preview_y))

        preview_label = font_medium.render("Animation Preview", True, WHITE)
        preview_rect = preview_label.get_rect(center=(preview_x + preview_size // 2, preview_y - 35))
        SCREEN.blit(preview_label, preview_rect)

        # 정보 표시
        info_y = HEIGHT - 40
        info_lines = [
            f"현재 프레임: {frames.current_frame}/7",
            f"로드된 프레임: {len(frames.frames_cleaned)}개",
            f"애니메이션 속도: {60/frames.animation_speed:.1f} FPS"
        ]

        for i, line in enumerate(info_lines):
            info_text = font_small.render(line, True, (180, 180, 180))
            SCREEN.blit(info_text, (50 + i * 200, info_y))

        # 조작 안내
        control_text = font_small.render("ESC: 종료 | SPACE: 원본/제거 전환", True, (150, 150, 150))
        control_rect = control_text.get_rect(right=WIDTH - 20, bottom=HEIGHT - 10)
        SCREEN.blit(control_text, control_rect)

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()