import pygame
import sys
import os

def resource_path(relative_path):
    """PyInstaller 번들과 일반 실행 모두에서 작동하는 리소스 경로 반환"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

# Pygame 초기화
pygame.init()

# 32x32 크기의 아이콘 생성
icon_surface = pygame.Surface((32, 32), pygame.SRCALPHA)
icon_surface.fill((0, 0, 0, 0))  # 투명 배경

# 탄약상자 그리기
# 상자 본체 (갈색)
box_rect = pygame.Rect(4, 8, 24, 20)
pygame.draw.rect(icon_surface, (139, 69, 19), box_rect)  # 진한 갈색
pygame.draw.rect(icon_surface, (101, 67, 33), box_rect, 2)  # 더 어두운 테두리

# 상자 뚜껑 (약간 밝은 갈색)
lid_rect = pygame.Rect(3, 6, 26, 4)
pygame.draw.rect(icon_surface, (160, 82, 45), lid_rect)  # 밝은 갈색
pygame.draw.rect(icon_surface, (101, 67, 33), lid_rect, 1)  # 테두리

# 십자 표시 (의료용 상자처럼)
cross_color = (255, 255, 255)  # 흰색
# 가로선
pygame.draw.rect(icon_surface, cross_color, (12, 15, 8, 3))
# 세로선  
pygame.draw.rect(icon_surface, cross_color, (15, 12, 3, 8))

# 탄약 표시 (상자 옆에 작은 탄환들)
bullet_color = (100, 100, 100)  # 회색
# 왼쪽 탄환
pygame.draw.rect(icon_surface, bullet_color, (2, 20, 2, 5))
pygame.draw.rect(icon_surface, (200, 50, 50), (2, 19, 2, 2))  # 빨간 탄두
# 오른쪽 탄환
pygame.draw.rect(icon_surface, bullet_color, (28, 20, 2, 5))
pygame.draw.rect(icon_surface, (200, 50, 50), (28, 19, 2, 2))  # 빨간 탄두

# 하이라이트 효과
pygame.draw.line(icon_surface, (200, 150, 100), (5, 9), (15, 9), 1)  # 밝은 선

# 아이콘 저장
try:
    pygame.image.save(icon_surface, resource_path("items/ammo_box.png"))
    print("✅ 탄약상자 아이콘이 성공적으로 생성되었습니다: items/ammo_box.png")
except Exception as e:
    print(f"❌ 아이콘 저장 실패: {e}")

pygame.quit()