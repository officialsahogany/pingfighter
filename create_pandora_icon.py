"""
판도라의 상자 아이콘 생성 스크립트
무지개빛 상자에 물음표가 있는 아이콘
"""

import pygame
import math

pygame.init()

# 아이콘 크기
ICON_SIZE = 32

# 아이콘 생성
surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)

# 상자 그리기
box_size = 24
box_x = (ICON_SIZE - box_size) // 2
box_y = (ICON_SIZE - box_size) // 2 + 2

# 무지개 그라데이션 색상
rainbow_colors = [
    (255, 0, 0),     # 빨강
    (255, 127, 0),   # 주황
    (255, 255, 0),   # 노랑
    (0, 255, 0),     # 초록
    (0, 0, 255),     # 파랑
    (75, 0, 130),    # 남색
    (148, 0, 211)    # 보라
]

# 상자 본체 - 무지개 그라데이션
for i in range(box_size):
    # 색상 인덱스 계산
    color_idx = int((i / box_size) * len(rainbow_colors))
    if color_idx >= len(rainbow_colors):
        color_idx = len(rainbow_colors) - 1
    
    color = rainbow_colors[color_idx]
    # 상자의 각 수평선을 그라데이션으로 그리기
    pygame.draw.line(surface, color, 
                     (box_x, box_y + i), 
                     (box_x + box_size - 1, box_y + i))

# 상자 테두리 - 밝은 금색
border_color = (255, 215, 0)
pygame.draw.rect(surface, border_color, 
                 (box_x, box_y, box_size, box_size), 2)

# 상자 뚜껑 효과 - 상단에 더 밝은 선
pygame.draw.line(surface, (255, 255, 200), 
                 (box_x + 2, box_y + 2), 
                 (box_x + box_size - 3, box_y + 2), 2)

# 물음표 그리기 - 흰색에 검은 테두리
question_mark_color = (255, 255, 255)
question_mark_outline = (0, 0, 0)

# 물음표 위치
qm_x = ICON_SIZE // 2
qm_y = ICON_SIZE // 2 + 1

# 물음표 본체 (곡선 부분)
# 외곽선 (검은색)
pygame.draw.arc(surface, question_mark_outline,
                (qm_x - 7, qm_y - 9, 14, 12), 
                math.pi * 0.2, math.pi * 1.5, 3)
# 내부 (흰색)
pygame.draw.arc(surface, question_mark_color,
                (qm_x - 6, qm_y - 8, 12, 10), 
                math.pi * 0.2, math.pi * 1.5, 2)

# 물음표 아래 직선 부분
pygame.draw.line(surface, question_mark_outline,
                 (qm_x - 1, qm_y + 1), (qm_x - 1, qm_y + 4), 3)
pygame.draw.line(surface, question_mark_color,
                 (qm_x, qm_y + 2), (qm_x, qm_y + 4), 2)

# 물음표 점
pygame.draw.circle(surface, question_mark_outline, (qm_x, qm_y + 8), 3)
pygame.draw.circle(surface, question_mark_color, (qm_x, qm_y + 8), 2)

# 반짝임 효과 추가
sparkle_positions = [
    (box_x - 2, box_y - 2),
    (box_x + box_size + 1, box_y - 1),
    (box_x + box_size, box_y + box_size),
    (box_x - 1, box_y + box_size - 1)
]

for pos in sparkle_positions:
    # 작은 별 모양 반짝임
    pygame.draw.circle(surface, (255, 255, 255, 200), pos, 1)
    # 십자 모양으로 빛나는 효과
    pygame.draw.line(surface, (255, 255, 255, 150), 
                     (pos[0] - 2, pos[1]), (pos[0] + 2, pos[1]), 1)
    pygame.draw.line(surface, (255, 255, 255, 150), 
                     (pos[0], pos[1] - 2), (pos[0], pos[1] + 2), 1)

# 파일로 저장
pygame.image.save(surface, "items/pandora_box.png")
print("판도라의 상자 아이콘이 생성되었습니다: items/pandora_box.png")