"""
라그나로크 해머 애니메이션 프레임 체크
"""

import pygame
import sys
import os

# 현재 디렉토리를 모듈 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def resource_path(relative_path):
    """리소스 파일의 절대 경로 반환"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("라그나로크 해머 애니메이션 테스트")
clock = pygame.time.Clock()

# 전설 아이템 매니저 임포트
from legendary_items import get_legendary_manager

# 아이템 매니저 초기화
legendary_manager = get_legendary_manager()

# 라그나로크 해머 가져오기
hammer = legendary_manager.get_item("ragnarok_hammer")
if hammer:
    print(f"라그나로크 해머 로드 성공!")
    print(f"애니메이션 프레임 수: {len(hammer.animation_frames)}")
    print(f"현재 프레임: {hammer.current_frame}")
    print(f"애니메이션 속도: {hammer.animation_speed}")
else:
    print("라그나로크 해머를 찾을 수 없습니다!")
    sys.exit(1)

# 수동으로 프레임 로드 확인
frame_count = 0
for i in range(8):
    frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
    if os.path.exists(frame_path):
        print(f"✓ 프레임 {i} 파일 존재: {frame_path}")
        frame_count += 1
    else:
        print(f"✗ 프레임 {i} 파일 없음: {frame_path}")

print(f"\n총 {frame_count}/8 프레임 파일 발견")

# 메인 루프
running = True
frame_counter = 0
manual_frame = 0

while running:
    dt = clock.tick(60) / 1000.0  # 60 FPS
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                # 수동으로 프레임 전환
                manual_frame = (manual_frame + 1) % 8
                print(f"수동 프레임 전환: {manual_frame}")
    
    # 화면 초기화
    screen.fill((30, 30, 50))
    
    # 격자 그리기
    for x in range(0, 800, 100):
        pygame.draw.line(screen, (50, 50, 70), (x, 0), (x, 600), 1)
    for y in range(0, 600, 100):
        pygame.draw.line(screen, (50, 50, 70), (0, y), (800, y), 1)
    
    # 라그나로크 해머 애니메이션 업데이트
    hammer.update(dt)
    
    # 세 가지 방식으로 아이콘 그리기
    
    # 1. draw_icon 메서드 사용 (왼쪽)
    hammer.draw_icon(screen, 100, 250, 100)
    
    # 2. 현재 프레임 직접 그리기 (중앙)
    if hammer.animation_frames:
        current_icon = hammer.animation_frames[hammer.current_frame]
        scaled_icon = pygame.transform.scale(current_icon, (100, 100))
        screen.blit(scaled_icon, (350, 250))
    
    # 3. 수동 프레임 그리기 (오른쪽)
    if hammer.animation_frames and manual_frame < len(hammer.animation_frames):
        manual_icon = hammer.animation_frames[manual_frame]
        scaled_icon = pygame.transform.scale(manual_icon, (100, 100))
        screen.blit(scaled_icon, (600, 250))
    
    # 정보 표시
    font = pygame.font.Font(None, 24)
    texts = [
        f"Frame Counter: {frame_counter}",
        f"Current Frame: {hammer.current_frame}/{len(hammer.animation_frames)}",
        f"Frame Counter (Hammer): {hammer.frame_counter}",
        f"Animation Speed: {hammer.animation_speed}",
        f"Manual Frame: {manual_frame}",
        "",
        "Left: draw_icon method",
        "Center: Direct current frame",
        "Right: Manual frame (SPACE to change)",
        "",
        "Press ESC to exit"
    ]
    
    for i, text in enumerate(texts):
        text_surface = font.render(text, True, (200, 200, 200))
        screen.blit(text_surface, (10, 10 + i * 25))
    
    # 프레임 카운터 증가
    frame_counter += 1
    
    # 화면 업데이트
    pygame.display.flip()

# 종료
pygame.quit()
print("테스트 종료")