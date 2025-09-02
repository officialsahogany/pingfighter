import pygame
import math

# 초기화
pygame.init()

# 아이콘 크기
size = 32
icon_surface = pygame.Surface((size, size), pygame.SRCALPHA)

# 클래식 탁상시계 그리기
center = size // 2

# 시계 본체 (원형)
pygame.draw.circle(icon_surface, (180, 140, 90), (center, center + 2), 12)  # 갈색 몸체
pygame.draw.circle(icon_surface, (220, 180, 120), (center, center + 2), 12, 2)  # 밝은 테두리

# 시계 다리 (탁상시계 받침)
pygame.draw.rect(icon_surface, (140, 100, 60), (center - 8, center + 12, 16, 3))  # 받침대
pygame.draw.rect(icon_surface, (100, 70, 40), (center - 6, center + 14, 4, 4))  # 왼쪽 다리
pygame.draw.rect(icon_surface, (100, 70, 40), (center + 2, center + 14, 4, 4))  # 오른쪽 다리

# 시계 상단 벨 (알람 시계 스타일)
pygame.draw.ellipse(icon_surface, (160, 120, 80), (center - 4, center - 13, 8, 5))  # 상단 벨
pygame.draw.ellipse(icon_surface, (200, 160, 100), (center - 4, center - 13, 8, 5), 1)  # 벨 하이라이트

# 시계 문자판 (흰색)
pygame.draw.circle(icon_surface, (255, 255, 240), (center, center + 2), 8)
pygame.draw.circle(icon_surface, (80, 60, 40), (center, center + 2), 8, 1)  # 문자판 테두리

# 시계 바늘
# 시침 (짧고 굵음) - 3시 방향
end_x = center + int(4 * math.cos(0))
end_y = center + 2 + int(4 * math.sin(0))
pygame.draw.line(icon_surface, (40, 30, 20), (center, center + 2), (end_x, end_y), 2)

# 분침 (길고 얇음) - 12시 방향
end_x = center + int(6 * math.cos(-math.pi/2))
end_y = center + 2 + int(6 * math.sin(-math.pi/2))
pygame.draw.line(icon_surface, (40, 30, 20), (center, center + 2), (end_x, end_y), 1)

# 중앙 나사
pygame.draw.circle(icon_surface, (60, 40, 20), (center, center + 2), 1)

# 시계 윈딩 크라운 (태엽 감는 부분)
pygame.draw.circle(icon_surface, (140, 100, 60), (center + 12, center - 2), 2)
pygame.draw.circle(icon_surface, (180, 140, 90), (center + 12, center - 2), 2, 1)

# 반짝임 효과
pygame.draw.circle(icon_surface, (255, 255, 255, 100), (center - 3, center - 2), 2)

# 저장
pygame.image.save(icon_surface, "items/stopwatch_icon.png")
print("스탑워치 아이콘이 생성되었습니다: items/stopwatch_icon.png")