import pygame
import sys
import math

# Pygame 초기화
pygame.init()

# 아이콘 크기
ICON_SIZE = 60
surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)

# 중앙 위치
center = ICON_SIZE // 2

# 레이더 디스플레이 배경 (원형 스크린)
# 다중 원 그리기 (레이더 느낌)
pygame.draw.circle(surface, (20, 30, 40), (center, center), 25)
pygame.draw.circle(surface, (30, 40, 50), (center, center), 25, 2)

# 레이더 격자선
grid_color = (50, 80, 100, 150)
# 동심원들
for radius in [8, 16, 24]:
    pygame.draw.circle(surface, grid_color, (center, center), radius, 1)

# 십자선
pygame.draw.line(surface, grid_color, (center, center - 24), (center, center + 24), 1)
pygame.draw.line(surface, grid_color, (center - 24, center), (center + 24, center), 1)

# 대각선
for angle in [45, 135, 225, 315]:
    rad = math.radians(angle)
    end_x = center + int(24 * math.cos(rad))
    end_y = center + int(24 * math.sin(rad))
    pygame.draw.line(surface, grid_color, (center, center), (end_x, end_y), 1)

# 레이더 스윕 효과 (회전하는 스캔 라인)
sweep_angle = -45  # 북동쪽 방향
sweep_rad = math.radians(sweep_angle)
sweep_end_x = center + int(24 * math.cos(sweep_rad))
sweep_end_y = center + int(24 * math.sin(sweep_rad))

# 스윕 라인 그라데이션 효과
for i in range(5):
    alpha = 150 - i * 25
    offset_angle = sweep_angle - i * 5
    offset_rad = math.radians(offset_angle)
    offset_end_x = center + int(24 * math.cos(offset_rad))
    offset_end_y = center + int(24 * math.sin(offset_rad))
    sweep_color = (100, 255, 150, alpha)
    pygame.draw.line(surface, sweep_color, (center, center), 
                    (offset_end_x, offset_end_y), 2 - i // 2)

# 감지된 위험 표시 (빨간 점들)
dangers = [
    (center + 15, center - 10),
    (center - 12, center - 8),
    (center + 8, center + 14)
]

for dx, dy in dangers:
    # 위험 점 펄스 효과
    pygame.draw.circle(surface, (255, 100, 100, 100), (dx, dy), 4)
    pygame.draw.circle(surface, (255, 50, 50), (dx, dy), 2)
    pygame.draw.circle(surface, (255, 200, 200), (dx, dy), 1)

# 안전 구역 표시 (초록 점)
safe_point = (center - 10, center + 12)
pygame.draw.circle(surface, (100, 255, 100, 100), safe_point, 3)
pygame.draw.circle(surface, (50, 200, 50), safe_point, 1)

# 센서 외곽 프레임
# 메탈릭 베젤
pygame.draw.circle(surface, (120, 130, 140), (center, center), 27, 3)
pygame.draw.circle(surface, (160, 170, 180), (center, center), 28, 1)

# 안테나 (위쪽에 작은 송신기)
antenna_base = pygame.Rect(center - 3, 2, 6, 8)
pygame.draw.rect(surface, (150, 160, 170), antenna_base)
pygame.draw.rect(surface, (100, 110, 120), antenna_base, 1)

# 안테나 팁
pygame.draw.line(surface, (200, 210, 220), (center, 6), (center, 2), 2)
pygame.draw.circle(surface, (255, 255, 255), (center, 2), 2)

# 신호 전파 효과 (안테나에서 나오는 전파)
for i in range(3):
    wave_radius = 4 + i * 3
    alpha = 100 - i * 30
    wave_color = (150, 200, 255, alpha)
    pygame.draw.arc(surface, wave_color, 
                   (center - wave_radius, 2 - wave_radius, 
                    wave_radius * 2, wave_radius * 2),
                   math.radians(200), math.radians(340), 1)

# LED 인디케이터 (아래쪽)
led_y = 52
# 활성 LED (초록색)
pygame.draw.circle(surface, (0, 255, 0), (center - 8, led_y), 2)
pygame.draw.circle(surface, (150, 255, 150), (center - 8, led_y), 1)

# 경고 LED (노란색)
pygame.draw.circle(surface, (255, 200, 0), (center, led_y), 2)
pygame.draw.circle(surface, (255, 255, 150), (center, led_y), 1)

# 위험 LED (빨간색)
pygame.draw.circle(surface, (255, 0, 0), (center + 8, led_y), 2)
pygame.draw.circle(surface, (255, 150, 150), (center + 8, led_y), 1)

# 하이라이트 효과
pygame.draw.arc(surface, (255, 255, 255, 120), 
                (center - 25, center - 25, 50, 50), 
                math.radians(-60), math.radians(0), 2)

# 파일로 저장
pygame.image.save(surface, "items/sensor.png")
print("위험감지센서 아이콘이 items/sensor.png에 저장되었습니다!")

pygame.quit()
sys.exit()