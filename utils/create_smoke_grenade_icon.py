import pygame
import math

# 초기화
pygame.init()

# 아이콘 크기
SIZE = 128
surface = pygame.Surface((SIZE, SIZE), pygame.SRCALPHA)

# 연막탄 본체 그리기 (원통형)
body_width = 40
body_height = 80
body_x = SIZE // 2 - body_width // 2
body_y = SIZE // 2 - body_height // 2 + 10

# 그라데이션 효과를 위한 여러 레이어
for i in range(body_width // 2):
    color_intensity = 80 + i * 3
    color = (color_intensity, color_intensity, color_intensity)
    pygame.draw.ellipse(surface, color, 
                       (body_x + i, body_y, body_width - i*2, body_height))

# 본체 메인 색상 (어두운 회색)
pygame.draw.ellipse(surface, (60, 60, 60), 
                   (body_x + 2, body_y + 2, body_width - 4, body_height - 4))

# 상단 캡 (밝은 회색)
cap_height = 15
pygame.draw.ellipse(surface, (100, 100, 100),
                   (body_x - 2, body_y - 5, body_width + 4, cap_height))
pygame.draw.ellipse(surface, (120, 120, 120),
                   (body_x, body_y - 3, body_width, cap_height - 4))

# 하단 캡
pygame.draw.ellipse(surface, (100, 100, 100),
                   (body_x - 2, body_y + body_height - 10, body_width + 4, cap_height))
pygame.draw.ellipse(surface, (120, 120, 120),
                   (body_x, body_y + body_height - 8, body_width, cap_height - 4))

# 안전핀과 고리
pin_x = body_x + body_width - 5
pin_y = body_y + 5

# 고리 (노란색)
pygame.draw.circle(surface, (200, 180, 0), (pin_x + 8, pin_y), 8, 2)
pygame.draw.circle(surface, (255, 215, 0), (pin_x + 8, pin_y), 6, 2)

# 안전핀 연결선
pygame.draw.line(surface, (180, 180, 180), (pin_x, pin_y), (pin_x + 5, pin_y), 2)

# 중앙 라벨 (백색 띠)
label_y = body_y + body_height // 2 - 10
pygame.draw.rect(surface, (200, 200, 200),
                (body_x + 5, label_y, body_width - 10, 20))
pygame.draw.rect(surface, (150, 150, 150),
                (body_x + 5, label_y, body_width - 10, 20), 1)

# 텍스트 "SMOKE" (작은 글씨로)
try:
    font = pygame.font.Font(None, 12)
    text = font.render("SMOKE", True, (50, 50, 50))
    text_rect = text.get_rect(center=(SIZE // 2, label_y + 10))
    surface.blit(text, text_rect)
except:
    # 폰트가 없으면 작은 점들로 표시
    for i in range(3):
        pygame.draw.circle(surface, (50, 50, 50),
                         (SIZE // 2 - 8 + i * 8, label_y + 10), 2)

# 연기 효과 (반투명)
smoke_particles = []
for i in range(8):
    angle = (i * math.pi * 2) / 8
    distance = 35 + i * 2
    x = SIZE // 2 + math.cos(angle) * distance
    y = body_y + body_height - 10 + math.sin(angle) * 10
    size = 8 + i
    alpha = 80 - i * 8
    
    smoke_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
    pygame.draw.circle(smoke_surface, (150, 150, 150, alpha), (size, size), size)
    surface.blit(smoke_surface, (x - size, y - size))

# 하이라이트 효과
highlight_x = body_x + 8
highlight_y = body_y + 15
pygame.draw.ellipse(surface, (255, 255, 255, 80),
                   (highlight_x, highlight_y, 12, 20))

# 그림자 효과
shadow_surface = pygame.Surface((SIZE, SIZE), pygame.SRCALPHA)
pygame.draw.ellipse(shadow_surface, (0, 0, 0, 50),
                   (body_x + 5, body_y + body_height + 5, body_width, 10))
surface.blit(shadow_surface, (0, 0))

# 저장
pygame.image.save(surface, "items/smoke_grenade.png")
print("연막탄 아이콘이 생성되었습니다: items/smoke_grenade.png")