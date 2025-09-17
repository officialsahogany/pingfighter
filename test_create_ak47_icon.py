#!/usr/bin/env python3
"""
AK-47 아이콘 생성기
"""
import pygame
import sys
import os

def resource_path(relative_path):
    """파일 경로 처리 함수"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

def create_ak47_icon():
    """AK-47 아이콘 생성 (32x32)"""
    # pygame 초기화
    pygame.init()
    
    # 32x32 투명 배경 아이콘 생성
    icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    icon.fill((0, 0, 0, 0))  # 완전 투명
    
    # AK-47 색상들
    gun_color = (60, 60, 60)        # 진회색 (총몸)
    barrel_color = (40, 40, 40)     # 어두운 회색 (총열)
    wood_color = (139, 69, 19)      # 나무색 (개머리판)
    metal_color = (100, 100, 100)   # 밝은 회색 (금속부품)
    
    # 총 개요 그리기 (간단한 AK-47 실루엣)
    
    # 개머리판 (나무색)
    pygame.draw.rect(icon, wood_color, (2, 12, 8, 8))
    
    # 총몸 메인 (회색)
    pygame.draw.rect(icon, gun_color, (8, 10, 16, 12))
    
    # 총열 (어두운 회색)
    pygame.draw.rect(icon, barrel_color, (20, 12, 10, 8))
    
    # 손잡이 (나무색)
    pygame.draw.rect(icon, wood_color, (12, 20, 4, 8))
    
    # 방아쇠 보호대
    pygame.draw.rect(icon, metal_color, (14, 18, 6, 3))
    
    # 탄창 (검은색)
    pygame.draw.rect(icon, (20, 20, 20), (16, 22, 4, 8))
    
    # 조준기 (밝은 회색)
    pygame.draw.rect(icon, metal_color, (22, 10, 2, 2))
    pygame.draw.rect(icon, metal_color, (26, 10, 2, 2))
    
    # 가스 실린더 (상단 돌출부)
    pygame.draw.rect(icon, gun_color, (18, 8, 8, 2))
    
    # 총구 화염 억제기 (선택사항)
    pygame.draw.rect(icon, barrel_color, (28, 13, 3, 6))
    
    # 하이라이트 추가 (입체감)
    pygame.draw.line(icon, (120, 120, 120), (9, 11), (23, 11), 1)  # 상단 하이라이트
    pygame.draw.line(icon, (80, 80, 80), (9, 21), (23, 21), 1)     # 하단 그림자
    
    # 아이콘 저장
    icon_path = resource_path("items/ak47.png")
    
    # items 디렉터리가 없으면 생성
    os.makedirs(os.path.dirname(icon_path), exist_ok=True)
    
    pygame.image.save(icon, icon_path)
    print(f"✅ AK-47 아이콘 생성 완료: {icon_path}")
    
    # 결과 화면에 표시
    screen = pygame.display.set_mode((200, 200))
    pygame.display.set_caption("AK-47 아이콘 미리보기")
    
    # 배경 체크무늬 (투명도 확인용)
    for x in range(0, 200, 10):
        for y in range(0, 200, 10):
            color = (220, 220, 220) if (x//10 + y//10) % 2 == 0 else (255, 255, 255)
            pygame.draw.rect(screen, color, (x, y, 10, 10))
    
    # 아이콘을 크게 확대해서 표시 (32x32 → 128x128)
    large_icon = pygame.transform.scale(icon, (128, 128))
    screen.blit(large_icon, (36, 36))
    
    # 원본 크기도 표시
    screen.blit(icon, (10, 10))
    
    pygame.display.flip()
    
    print("아이콘 미리보기가 표시됩니다. 아무 키나 누르면 종료됩니다.")
    
    # 키 입력 대기
    waiting = True
    clock = pygame.time.Clock()
    while waiting:
        for event in pygame.event.get():
            if event.type == pygame.QUIT or event.type == pygame.KEYDOWN:
                waiting = False
        clock.tick(60)
    
    pygame.quit()
    return icon_path

if __name__ == "__main__":
    print("🎨 AK-47 아이콘 생성기")
    print("=" * 30)
    
    try:
        icon_path = create_ak47_icon()
        print(f"🎯 아이콘이 성공적으로 생성되었습니다: {icon_path}")
        print("게임에서 AK-47 아이템의 아이콘을 확인할 수 있습니다!")
    except Exception as e:
        print(f"❌ 아이콘 생성 실패: {e}")