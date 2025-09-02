"""
블루투스링 아이콘 생성 스크립트
32x32 픽셀 아이콘을 생성합니다.
"""

import pygame
import math

# Pygame 초기화
pygame.init()

# 32x32 서페이스 생성
icon_size = 32
icon = pygame.Surface((icon_size, icon_size), pygame.SRCALPHA)

# 배경 투명
icon.fill((0, 0, 0, 0))

# 색상 정의
RING_COLOR = (150, 150, 150)  # 실버 메탈릭
RING_DARK = (100, 100, 100)  # 어두운 메탈릭 (그림자)
RING_LIGHT = (200, 200, 200)  # 밝은 메탈릭 (하이라이트)
BLUETOOTH_BLUE = (100, 150, 255)  # 블루투스 블루
BLUETOOTH_DARK = (70, 100, 200)  # 어두운 블루
BLUETOOTH_LIGHT = (150, 200, 255)  # 밝은 블루
GLOW_COLOR = (200, 220, 255)  # 블루 글로우

# 링 그리기 (도넛 모양)
center_x, center_y = 16, 16
outer_radius = 12
inner_radius = 8

# 외부 링
pygame.draw.circle(icon, RING_COLOR, (center_x, center_y), outer_radius)
pygame.draw.circle(icon, RING_DARK, (center_x, center_y), outer_radius, 2)

# 내부 홀
pygame.draw.circle(icon, (0, 0, 0, 0), (center_x, center_y), inner_radius)

# 블루투스 심볼 그리기 (중앙에)
# B 모양의 블루투스 로고
bt_x, bt_y = center_x, center_y
bt_size = 6

# 블루투스 메인 라인
pygame.draw.line(icon, BLUETOOTH_BLUE, (bt_x, bt_y - bt_size), (bt_x, bt_y + bt_size), 2)

# 블루투스 V 모양 (위)
pygame.draw.line(icon, BLUETOOTH_BLUE, (bt_x - 3, bt_y - 3), (bt_x + 3, bt_y), 2)
pygame.draw.line(icon, BLUETOOTH_BLUE, (bt_x + 3, bt_y), (bt_x - 3, bt_y + 3), 2)

# 블루투스 V 모양 (아래)
pygame.draw.line(icon, BLUETOOTH_BLUE, (bt_x - 3, bt_y + 3), (bt_x + 3, bt_y), 2)
pygame.draw.line(icon, BLUETOOTH_BLUE, (bt_x + 3, bt_y), (bt_x - 3, bt_y - 3), 2)

# 글로우 효과 (작은 점들)
for angle in range(0, 360, 60):
    rad = math.radians(angle)
    glow_x = int(center_x + (outer_radius - 2) * math.cos(rad))
    glow_y = int(center_y + (outer_radius - 2) * math.sin(rad))
    pygame.draw.circle(icon, GLOW_COLOR, (glow_x, glow_y), 1)

# 하이라이트 추가 (입체감)
pygame.draw.arc(icon, RING_LIGHT, (center_x - outer_radius, center_y - outer_radius, 
                                   outer_radius * 2, outer_radius * 2), 
                3.14, 4.71, 2)

# 작은 보석 효과 (블루투스 활성 표시)
pygame.draw.circle(icon, BLUETOOTH_LIGHT, (center_x + 8, center_y - 8), 2)
pygame.draw.circle(icon, (255, 255, 255), (center_x + 8, center_y - 8), 1)

# 아이콘 저장
pygame.image.save(icon, "items/bluetooth_ring.png")
print("블루투스링 아이콘이 items/bluetooth_ring.png로 저장되었습니다.")