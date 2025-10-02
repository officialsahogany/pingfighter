"""
라그나로크 해머 PNG 프레임 간단 표시
"""
import pygame
import sys
import os

pygame.init()

WIDTH, HEIGHT = 800, 600
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("라그나로크 해머 PNG 프레임")

def resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

# PNG 프레임 로드
frames = []
for i in range(8):
    frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
    try:
        frame = pygame.image.load(frame_path).convert_alpha()
        frames.append(frame)
        print(f"✓ Frame {i} loaded")
    except:
        print(f"✗ Frame {i} failed")
        # 빈 프레임
        frame = pygame.Surface((60, 60), pygame.SRCALPHA)
        frames.append(frame)

clock = pygame.time.Clock()
running = True
current_frame = 0
frame_timer = 0

font = pygame.font.Font(None, 24)

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
    title = font.render("Ragnarok Hammer PNG Frames (8 frames)", True, (255, 255, 255))
    SCREEN.blit(title, (WIDTH // 2 - title.get_width() // 2, 30))

    # 애니메이션 업데이트
    frame_timer += 1
    if frame_timer >= 8:  # 8틱마다 프레임 변경
        frame_timer = 0
        current_frame = (current_frame + 1) % 8

    # 8개 프레임 표시
    for i in range(8):
        x = 100 + (i % 4) * 150
        y = 150 + (i // 4) * 150

        # 배경 박스
        if i == current_frame:
            pygame.draw.rect(SCREEN, (70, 70, 80), (x - 5, y - 5, 70, 70))
        else:
            pygame.draw.rect(SCREEN, (40, 40, 50), (x - 5, y - 5, 70, 70))

        # PNG 프레임
        if i < len(frames):
            SCREEN.blit(frames[i], (x, y))

        # 프레임 번호
        label = font.render(f"{i}", True, (255, 215, 0) if i == current_frame else (150, 150, 150))
        SCREEN.blit(label, (x + 25, y + 75))

    # 큰 미리보기
    if current_frame < len(frames):
        big = pygame.transform.scale(frames[current_frame], (120, 120))
        SCREEN.blit(big, (WIDTH // 2 - 60, 400))

    # 현재 프레임 정보
    info = font.render(f"Current: Frame {current_frame}", True, (255, 255, 255))
    SCREEN.blit(info, (WIDTH // 2 - info.get_width() // 2, 540))

    # 조작법
    controls = font.render("← →: Frame select | ESC: Exit", True, (150, 150, 150))
    SCREEN.blit(controls, (WIDTH // 2 - controls.get_width() // 2, HEIGHT - 30))

    pygame.display.flip()

pygame.quit()
sys.exit()