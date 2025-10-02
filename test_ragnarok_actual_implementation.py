"""
실제 아이템관리자창의 라그나로크 해머 코드 완벽 재현
legendary_items.py의 실제 RagnarokHammer 클래스 사용
"""
import pygame
import math
import sys
import os

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1200, 800
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("실제 라그나로크 해머 - 게임 코드 그대로")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
YELLOW = (255, 215, 0)
RED = (255, 0, 0)
BLUE = (0, 100, 255)

# 폰트 설정
font_large = pygame.font.Font(None, 36)
font_medium = pygame.font.Font(None, 24)
font_small = pygame.font.Font(None, 18)

# legendary_items.py에서 실제 코드 가져오기
import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')
from legendary_items import RagnarokHammer

def main():
    """메인 실행 함수"""
    # 실제 라그나로크 해머 인스턴스 생성
    ragnarok = RagnarokHammer()
    ragnarok.unlocked = True  # 언락 상태로 설정

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
        title_text = font_large.render("실제 라그나로크 해머 - legendary_items.py 코드 그대로", True, WHITE)
        title_rect = title_text.get_rect(center=(WIDTH // 2, 50))
        SCREEN.blit(title_text, title_rect)

        # 설명
        desc_text = font_medium.render("게임의 아이템관리자창과 완전히 동일한 렌더링", True, (200, 200, 200))
        desc_rect = desc_text.get_rect(center=(WIDTH // 2, 100))
        SCREEN.blit(desc_text, desc_rect)

        # 애니메이션 업데이트 (UI 모드로)
        ragnarok.update(dt, ui_mode=True)

        # 다양한 크기로 아이콘 그리기
        for i, (size, pos) in enumerate(zip(sizes, positions)):
            # 실제 draw_icon 메서드 호출
            ragnarok.draw_icon(SCREEN, pos[0], pos[1], size)

            # 크기 레이블
            size_text = font_small.render(f"{size}x{size}", True, WHITE)
            size_rect = size_text.get_rect(center=(pos[0] + size // 2, pos[1] + size + 20))
            SCREEN.blit(size_text, size_rect)

        # 현재 상태 정보
        info_y = HEIGHT - 250
        info_lines = [
            f"Animation Time: {ragnarok.animation_time:.2f}",
            f"Current Frame: {ragnarok.current_frame}/8",
            f"Frame Counter: {ragnarok.frame_counter}",
            f"Animation Speed: {ragnarok.animation_speed}",
            f"Glow Intensity: {ragnarok.glow_intensity:.2f}",
            f"Animation Offset: {ragnarok.animation_offset:.1f}px",
            f"Loaded Frames: {len(ragnarok.animation_frames)}"
        ]

        for i, line in enumerate(info_lines):
            info_text = font_small.render(line, True, (180, 180, 180))
            SCREEN.blit(info_text, (50, info_y + i * 25))

        # 구성 요소 설명
        components_y = HEIGHT - 250
        components_x = WIDTH // 2 + 100
        component_lines = [
            "구성 요소 (실제 코드):",
            "1. _draw_common_legendary_frame()",
            "   - 파란색 원형 글로우 (3층)",
            "   - 붉은색 내부 테두리 (3중)",
            "   - 은색-파란색 외곽 프레임",
            "   - 황금색 코너 장식 + 점",
            "2. PNG 애니메이션 프레임 (8장)",
            "3. 번개 효과 (프레임 0, 4)",
            "4. 상하 움직임 효과"
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