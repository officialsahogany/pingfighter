"""
토끼 전설 아이템 - 라그나로크 해머의 실제 내부 테두리 사용
가운데만 토끼로 변경
"""
import pygame
import math
import sys
import os

def resource_path(relative_path):
    """리소스 파일 경로를 가져오는 헬퍼 함수"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(os.path.dirname(__file__))

    result = os.path.join(base_path, relative_path)
    return result

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1200, 800
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("토끼 전설 아이템 - 라그나로크 실제 프레임 사용")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
YELLOW = (255, 215, 0)
RED = (255, 0, 0)
BLUE = (0, 100, 255)
PURPLE = (147, 0, 211)
PINK = (255, 182, 193)
ORANGE = (255, 165, 0)

# 폰트 설정
font_large = pygame.font.Font(None, 36)
font_medium = pygame.font.Font(None, 24)
font_small = pygame.font.Font(None, 18)

class RabbitLegendary:
    """토끼 전설 아이템 클래스 - 라그나로크 프레임 사용"""

    def __init__(self):
        self.animation_time = 0
        self.glow_intensity = 0
        self.animation_offset = 0
        self.frame_counter = 0
        self.animation_speed = 8
        self.current_frame = 0

        # 라그나로크 해머 프레임 로드 (내부 테두리용)
        self.ragnarok_frames = []
        self._load_ragnarok_frames()

    def _load_ragnarok_frames(self):
        """라그나로크 해머 프레임 로드 (내부 테두리로 사용)"""
        self.ragnarok_frames.clear()

        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                frame = pygame.image.load(frame_path).convert_alpha()
                # 빨간 배경 제거하지 않고 원본 그대로 사용
                self.ragnarok_frames.append(frame)
                print(f"✓ 토끼용 라그나로크 프레임 {i} 로드 성공")
            except Exception as e:
                print(f"[ERROR] 토끼용 라그나로크 프레임 {i} 로드 실패: {e}")
                # 실패 시 빈 프레임 생성
                empty_frame = pygame.Surface((60, 60), pygame.SRCALPHA)
                self.ragnarok_frames.append(empty_frame)

        print(f"토끼 아이콘: 라그나로크 프레임 {len([f for f in self.ragnarok_frames if f.get_size() != (60, 60)])}/8개 로드")

    def update(self, dt, ui_mode=True):
        """애니메이션 업데이트"""
        self.animation_time += dt

        # 글로우 효과 업데이트
        self.glow_intensity = abs(math.sin(self.animation_time * 2)) * 0.5 + 0.5

        # 상하 움직임
        if ui_mode:
            self.animation_offset = math.sin(self.animation_time * 3) * 3

        # 프레임 업데이트
        self.frame_counter += 1
        if self.frame_counter >= self.animation_speed:
            self.frame_counter = 0
            self.current_frame = (self.current_frame + 1) % 8

    def _draw_common_legendary_frame(self, surface, x, y, size,
                                    glow_color=(0, 100, 255),
                                    inner_color=(255, 0, 0),
                                    corner_color=(255, 215, 0)):
        """라그나로크 해머와 동일한 전설 프레임 그리기"""
        center_x = x + size // 2
        center_y = y + size // 2

        # 1. 파란색 원형 글로우 (3층)
        glow_alpha = int(100 * self.glow_intensity)
        for i in range(3):
            radius = size // 2 + 10 + (3-i) * 8
            glow_surf = pygame.Surface((radius*2, radius*2), pygame.SRCALPHA)
            alpha = glow_alpha // (i+1)
            color = (*glow_color, alpha)
            pygame.draw.circle(glow_surf, color, (radius, radius), radius)
            surface.blit(glow_surf, (center_x - radius, center_y - radius))

        # 2. 붉은색 내부 테두리 (3중) - 상하 움직임
        offset_y = self.animation_offset if hasattr(self, 'animation_offset') else 0
        for i in range(3):
            border_size = size - i * 4
            border_rect = pygame.Rect(
                center_x - border_size // 2,
                center_y - border_size // 2 + offset_y,
                border_size,
                border_size
            )
            alpha = 200 - i * 50
            border_color = (*inner_color, alpha)

            # 모서리가 둥근 사각형
            border_surf = pygame.Surface((border_size, border_size), pygame.SRCALPHA)
            pygame.draw.rect(border_surf, border_color,
                           (0, 0, border_size, border_size),
                           2, border_radius=8)
            surface.blit(border_surf, border_rect.topleft)

        # 3. 은색-파란색 외곽 프레임
        frame_size = size + 12
        frame_rect = pygame.Rect(
            center_x - frame_size // 2,
            center_y - frame_size // 2,
            frame_size,
            frame_size
        )

        # 은색 기본 프레임
        pygame.draw.rect(surface, (192, 192, 192), frame_rect, 3, border_radius=10)

        # 파란색 하이라이트
        highlight_surf = pygame.Surface((frame_size, frame_size), pygame.SRCALPHA)
        pygame.draw.rect(highlight_surf, (100, 150, 255, 100),
                        (0, 0, frame_size, frame_size),
                        2, border_radius=10)
        surface.blit(highlight_surf, frame_rect.topleft)

        # 4. 황금색 코너 장식
        corner_size = 12
        corners = [
            (frame_rect.left + 5, frame_rect.top + 5),      # 좌상
            (frame_rect.right - 5 - corner_size, frame_rect.top + 5),     # 우상
            (frame_rect.left + 5, frame_rect.bottom - 5 - corner_size),   # 좌하
            (frame_rect.right - 5 - corner_size, frame_rect.bottom - 5 - corner_size)  # 우하
        ]

        for corner_x, corner_y in corners:
            # L자 모양 코너
            pygame.draw.lines(surface, corner_color, False, [
                (corner_x, corner_y + corner_size),
                (corner_x, corner_y),
                (corner_x + corner_size, corner_y)
            ], 3)

            # 코너에 작은 점
            pygame.draw.circle(surface, corner_color,
                             (corner_x + corner_size//2, corner_y + corner_size//2),
                             2)

    def draw_rabbit(self, surface, x, y, size):
        """토끼 그리기"""
        center_x = x + size // 2
        center_y = y + size // 2

        # 애니메이션 오프셋 적용
        offset_y = self.animation_offset if hasattr(self, 'animation_offset') else 0

        # 토끼 몸통 (하얀색)
        body_size = int(size * 0.4)
        body_y = center_y + int(size * 0.1) + offset_y
        pygame.draw.ellipse(surface, WHITE,
                          (center_x - body_size//2, body_y - body_size//2,
                           body_size, int(body_size * 1.2)))

        # 토끼 머리
        head_size = int(size * 0.35)
        head_y = center_y - int(size * 0.15) + offset_y
        pygame.draw.circle(surface, WHITE,
                         (center_x, head_y), head_size//2)

        # 토끼 귀 (길쭉한 타원)
        ear_width = int(size * 0.08)
        ear_height = int(size * 0.25)

        # 왼쪽 귀
        left_ear_x = center_x - int(size * 0.12)
        left_ear_y = head_y - int(size * 0.2) + offset_y
        pygame.draw.ellipse(surface, WHITE,
                          (left_ear_x - ear_width//2, left_ear_y - ear_height//2,
                           ear_width, ear_height))
        # 왼쪽 귀 내부 (분홍색)
        pygame.draw.ellipse(surface, PINK,
                          (left_ear_x - ear_width//3, left_ear_y - ear_height//3,
                           ear_width//1.5, ear_height//1.5))

        # 오른쪽 귀
        right_ear_x = center_x + int(size * 0.12)
        right_ear_y = head_y - int(size * 0.2) + offset_y
        pygame.draw.ellipse(surface, WHITE,
                          (right_ear_x - ear_width//2, right_ear_y - ear_height//2,
                           ear_width, ear_height))
        # 오른쪽 귀 내부 (분홍색)
        pygame.draw.ellipse(surface, PINK,
                          (right_ear_x - ear_width//3, right_ear_y - ear_height//3,
                           ear_width//1.5, ear_height//1.5))

        # 눈 (검은색)
        eye_size = int(size * 0.04)
        eye_spacing = int(size * 0.08)
        eye_y = head_y + offset_y

        # 왼쪽 눈
        pygame.draw.circle(surface, BLACK,
                         (center_x - eye_spacing, eye_y), eye_size)
        # 눈 반짝임
        pygame.draw.circle(surface, WHITE,
                         (center_x - eye_spacing + eye_size//2, eye_y - eye_size//2),
                         eye_size//3)

        # 오른쪽 눈
        pygame.draw.circle(surface, BLACK,
                         (center_x + eye_spacing, eye_y), eye_size)
        # 눈 반짝임
        pygame.draw.circle(surface, WHITE,
                         (center_x + eye_spacing + eye_size//2, eye_y - eye_size//2),
                         eye_size//3)

        # 코 (분홍색 삼각형)
        nose_size = int(size * 0.03)
        nose_y = head_y + int(size * 0.08) + offset_y
        nose_points = [
            (center_x, nose_y - nose_size),
            (center_x - nose_size, nose_y + nose_size//2),
            (center_x + nose_size, nose_y + nose_size//2)
        ]
        pygame.draw.polygon(surface, PINK, nose_points)

        # 입 (간단한 선)
        mouth_y = nose_y + int(size * 0.03) + offset_y
        pygame.draw.arc(surface, BLACK,
                       (center_x - int(size * 0.05), mouth_y - int(size * 0.02),
                        int(size * 0.1), int(size * 0.04)),
                       0, math.pi, 2)

        # 발 (타원형)
        foot_size_x = int(size * 0.12)
        foot_size_y = int(size * 0.08)
        foot_y = body_y + int(body_size * 0.5) + offset_y

        # 왼발
        pygame.draw.ellipse(surface, WHITE,
                          (center_x - int(size * 0.15) - foot_size_x//2,
                           foot_y - foot_size_y//2,
                           foot_size_x, foot_size_y))
        # 오른발
        pygame.draw.ellipse(surface, WHITE,
                          (center_x + int(size * 0.15) - foot_size_x//2,
                           foot_y - foot_size_y//2,
                           foot_size_x, foot_size_y))

        # 꼬리 (둥근 원)
        tail_size = int(size * 0.1)
        tail_x = center_x + int(size * 0.25)
        tail_y = body_y + offset_y
        pygame.draw.circle(surface, WHITE, (tail_x, tail_y), tail_size)

        # 프레임별 특수 효과 (번개처럼 반짝이는 효과)
        if self.current_frame in [0, 4]:
            # 토끼 주변에 별 효과
            star_positions = [
                (center_x - size//3, head_y - size//3),
                (center_x + size//3, head_y - size//3),
                (center_x, body_y + size//3)
            ]

            for star_x, star_y in star_positions:
                self._draw_star(surface, star_x + offset_y//2, star_y + offset_y,
                              int(size * 0.08), YELLOW, alpha=150)

    def _draw_star(self, surface, x, y, size, color, alpha=255):
        """별 모양 그리기"""
        star_surf = pygame.Surface((size*2, size*2), pygame.SRCALPHA)

        # 5각 별 점 계산
        points = []
        for i in range(10):
            angle = math.pi * i / 5 - math.pi / 2
            if i % 2 == 0:
                radius = size
            else:
                radius = size * 0.5
            px = x + radius * math.cos(angle)
            py = y + radius * math.sin(angle)
            points.append((px, py))

        # 별 그리기
        color_with_alpha = (*color, alpha)
        pygame.draw.polygon(surface, color_with_alpha, points)

    def draw_icon(self, surface, x, y, size):
        """전체 아이콘 그리기 - 라그나로크 실제 프레임 사용"""
        # 프레임 오프셋 계산 (위아래 움직임)
        frame_offset = int(math.sin(self.animation_time * 2.5) * 2)
        icon_y = y + frame_offset

        # 1. 파란색 글로우 배경 (라그나로크와 동일)
        pulse = (math.sin(self.animation_time * 4.0) + 1) / 2
        glow_color = (30 + int(40 * pulse), 90 + int(50 * pulse), 170 + int(30 * pulse))

        # 여러 겹의 원으로 글로우 효과
        for i in range(3):
            radius = size // 2 - i * 3
            alpha = 80 - i * 20
            glow_surf = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*glow_color, alpha), (size // 2, size // 2), radius)
            surface.blit(glow_surf, (x, icon_y))

        # 2. 라그나로크 해머 프레임 그리기 (실제 PNG 프레임 사용)
        if self.ragnarok_frames and len(self.ragnarok_frames) > 0:
            # 프레임 애니메이션 업데이트
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.ragnarok_frames)

            # 현재 프레임 가져오기
            current_ragnarok_frame = self.ragnarok_frames[self.current_frame]

            # 프레임 크기 조정
            if current_ragnarok_frame.get_size() != (size, size):
                scaled_frame = pygame.transform.scale(current_ragnarok_frame, (size, size))
            else:
                scaled_frame = current_ragnarok_frame

            # 라그나로크 프레임에서 중앙 해머 부분을 투명하게 만들어 토끼를 그릴 공간 확보
            frame_with_hole = pygame.Surface((size, size), pygame.SRCALPHA)

            # 프레임 복사
            for py in range(size):
                for px in range(size):
                    # 중앙 원형 영역 계산
                    center_x = size // 2
                    center_y = size // 2
                    dist = math.sqrt((px - center_x) ** 2 + (py - center_y) ** 2)

                    # 중앙 반경 (토끼를 위한 공간)
                    clear_radius = size // 3

                    if dist < clear_radius:
                        # 중앙은 투명하게 (토끼를 위한 공간)
                        frame_with_hole.set_at((px, py), (0, 0, 0, 0))
                    else:
                        # 테두리 부분은 그대로 복사
                        color = scaled_frame.get_at((px, py))
                        frame_with_hole.set_at((px, py), color)

            # 프레임 그리기
            surface.blit(frame_with_hole, (x, icon_y))
        else:
            # 프레임 로드 실패 시 대체 내부 테두리 그리기
            self._draw_fallback_border(surface, x, icon_y, size)

        # 3. 토끼 그리기 (중앙에)
        self.draw_rabbit(surface, x, y, size)

        # 4. 외부 테두리와 코너 장식 (라그나로크와 동일)
        # 은색-파란색 테두리
        border_color = (150 + int(50 * pulse), 170 + int(30 * pulse), 200 + int(30 * pulse))
        border_rect = pygame.Rect(x - 1, icon_y - 1, size + 2, size + 2)
        pygame.draw.rect(surface, border_color, border_rect, 2)

        # 금색 ㄱ자 코너 장식
        corner_color = (255, 215, 0)  # 금색
        corner_size = 8

        # 좌상단
        pygame.draw.lines(surface, corner_color, False,
                         [(x - 2, icon_y + corner_size), (x - 2, icon_y - 2),
                          (x + corner_size, icon_y - 2)], 2)
        # 우상단
        pygame.draw.lines(surface, corner_color, False,
                         [(x + size - corner_size + 2, icon_y - 2),
                          (x + size + 2, icon_y - 2),
                          (x + size + 2, icon_y + corner_size)], 2)
        # 좌하단
        pygame.draw.lines(surface, corner_color, False,
                         [(x - 2, icon_y + size - corner_size + 2),
                          (x - 2, icon_y + size + 2),
                          (x + corner_size, icon_y + size + 2)], 2)
        # 우하단
        pygame.draw.lines(surface, corner_color, False,
                         [(x + size - corner_size + 2, icon_y + size + 2),
                          (x + size + 2, icon_y + size + 2),
                          (x + size + 2, icon_y + size - corner_size + 2)], 2)

        # 코너에 작은 금색 점
        for cx, cy in [(x, icon_y), (x + size, icon_y),
                       (x, icon_y + size), (x + size, icon_y + size)]:
            pygame.draw.circle(surface, corner_color, (cx, cy), 2)

    def _draw_fallback_border(self, surface, x, y, size):
        """프레임 로드 실패 시 대체 내부 테두리"""
        # 내부 빨간색 테두리 (3중 라인)
        inner_pulse = (math.sin(self.animation_time * 6.0) + 1) / 2

        outer_inner_color = (
            int(150 + 70 * inner_pulse),
            int(30 + 35 * inner_pulse),
            int(30 + 35 * inner_pulse)
        )
        inner_inner_color = (
            int(120 + 60 * inner_pulse),
            int(10 + 25 * inner_pulse),
            int(10 + 25 * inner_pulse)
        )

        inner_rect_outer = pygame.Rect(x + 2, y + 2, size - 4, size - 4)
        inner_rect_mid = inner_rect_outer.inflate(-2, -2)
        inner_rect_inner = inner_rect_outer.inflate(-4, -4)

        mid_inner_color = (
            (outer_inner_color[0] + inner_inner_color[0]) // 2,
            (outer_inner_color[1] + inner_inner_color[1]) // 2,
            (outer_inner_color[2] + inner_inner_color[2]) // 2
        )

        pygame.draw.rect(surface, outer_inner_color, inner_rect_outer, 1)
        pygame.draw.rect(surface, mid_inner_color, inner_rect_mid, 1)
        pygame.draw.rect(surface, inner_inner_color, inner_rect_inner, 1)

def main():
    """메인 실행 함수"""
    # 토끼 전설 아이템 인스턴스 생성
    rabbit = RabbitLegendary()

    clock = pygame.time.Clock()
    running = True

    # 다양한 크기로 표시할 위치
    sizes = [64, 96, 128, 160]
    positions = [
        (150, HEIGHT // 2 - 150),
        (350, HEIGHT // 2 - 150),
        (550, HEIGHT // 2 - 150),
        (800, HEIGHT // 2 - 150)
    ]

    while running:
        dt = clock.tick(60) / 1000.0  # 60 FPS, dt는 초 단위

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

        # 화면 클리어
        SCREEN.fill((30, 30, 50))

        # 제목
        title_text = font_large.render("토끼 전설 아이템 - 라그나로크 테두리 효과", True, WHITE)
        title_rect = title_text.get_rect(center=(WIDTH // 2, 50))
        SCREEN.blit(title_text, title_rect)

        # 설명
        desc_text = font_medium.render("라그나로크 해머와 동일한 테두리 + 토끼 아이콘", True, (200, 200, 200))
        desc_rect = desc_text.get_rect(center=(WIDTH // 2, 100))
        SCREEN.blit(desc_text, desc_rect)

        # 애니메이션 업데이트
        rabbit.update(dt, ui_mode=True)

        # 다양한 크기로 아이콘 그리기
        for i, (size, pos) in enumerate(zip(sizes, positions)):
            # 아이콘 그리기
            rabbit.draw_icon(SCREEN, pos[0], pos[1], size)

            # 크기 레이블
            size_text = font_small.render(f"{size}x{size}", True, WHITE)
            size_rect = size_text.get_rect(center=(pos[0] + size // 2, pos[1] + size + 20))
            SCREEN.blit(size_text, size_rect)

        # 현재 상태 정보
        info_y = HEIGHT - 250
        info_lines = [
            f"Animation Time: {rabbit.animation_time:.2f}",
            f"Current Frame: {rabbit.current_frame}/8",
            f"Frame Counter: {rabbit.frame_counter}",
            f"Animation Speed: {rabbit.animation_speed}",
            f"Glow Intensity: {rabbit.glow_intensity:.2f}",
            f"Animation Offset: {rabbit.animation_offset:.1f}px"
        ]

        for i, line in enumerate(info_lines):
            info_text = font_small.render(line, True, (180, 180, 180))
            SCREEN.blit(info_text, (50, info_y + i * 25))

        # 구성 요소 설명
        components_y = HEIGHT - 250
        components_x = WIDTH // 2 + 100
        component_lines = [
            "구성 요소:",
            "1. 라그나로크와 동일한 테두리",
            "   - 파란색 원형 글로우 (3층)",
            "   - 붉은색 내부 테두리 (3중)",
            "   - 은색-파란색 외곽 프레임",
            "   - 황금색 코너 장식 + 점",
            "2. 토끼 아이콘",
            "   - 흰색 몸통과 머리",
            "   - 분홍색 귀 내부와 코",
            "   - 별 효과 (프레임 0, 4)",
            "3. 상하 움직임 효과"
        ]

        for i, line in enumerate(component_lines):
            color = WHITE if i == 0 else (180, 180, 180)
            comp_text = font_small.render(line, True, color)
            SCREEN.blit(comp_text, (components_x, components_y + i * 22))

        # 조작 안내
        control_text = font_small.render("ESC: 종료", True, (150, 150, 150))
        SCREEN.blit(control_text, (WIDTH - 100, HEIGHT - 30))

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()