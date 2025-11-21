#!/usr/bin/env python3
"""Stage 8 보스 패들 이미지 생성 - 탑뷰 닌자."""

import pygame
import math
import os

def generate_boss_stage8():
    """탑뷰 시점의 복면 닌자 보스 패들 이미지 생성."""
    pygame.init()

    # 이미지 크기 (기존과 동일하게 512x512)
    SIZE = 512
    surface = pygame.Surface((SIZE, SIZE), pygame.SRCALPHA)

    # 중심점
    cx, cy = SIZE // 2, SIZE // 2

    # === 색상 정의 ===
    ninja_black = (25, 25, 30)          # 닌자 복장 검정
    ninja_dark = (35, 35, 45)           # 닌자 복장 어두운 부분
    ninja_highlight = (50, 50, 60)      # 하이라이트
    mask_band = (140, 35, 35)           # 복면 띠 (빨간색)
    eye_color = (80, 80, 100)           # 눈 (어두운 색)
    skin_color = (180, 150, 130)        # 피부색 (손)
    paddle_handle = (80, 50, 30)        # 탁구채 손잡이
    paddle_rubber_red = (180, 50, 50)   # 탁구채 러버 빨강
    paddle_wood = (160, 120, 80)        # 탁구채 나무
    shuriken_metal = (100, 100, 110)    # 표창 금속
    shuriken_dark = (60, 60, 70)        # 표창 어두운 부분
    shadow_color = (0, 0, 0, 80)        # 그림자

    # === 그림자 ===
    shadow_offset = 15
    pygame.draw.ellipse(surface, shadow_color,
                       (cx - 130 + shadow_offset, cy - 80 + shadow_offset, 260, 180))

    # === 몸통 (탑뷰 - 어깨와 등이 보임) ===
    # 어깨/등 부분 (타원형)
    body_rect = pygame.Rect(cx - 100, cy - 60, 200, 140)
    pygame.draw.ellipse(surface, ninja_black, body_rect)

    # 어깨 하이라이트
    for i in range(3):
        alpha = 25 - i * 8
        highlight_surf = pygame.Surface((180 - i*15, 90 - i*10), pygame.SRCALPHA)
        pygame.draw.ellipse(highlight_surf, (*ninja_highlight, alpha),
                          (0, 0, 180 - i*15, 90 - i*10))
        surface.blit(highlight_surf, (cx - 90 + i*7, cy - 45 + i*5))

    # === 머리 (탑뷰 - 복면 쓴 머리 위에서 봄) ===
    head_y = cy - 85
    head_radius = 65

    # 머리 기본 (검은 복면)
    pygame.draw.circle(surface, ninja_black, (cx, head_y), head_radius)

    # 머리 위 하이라이트
    for i in range(3):
        r = head_radius - 12 - i * 8
        alpha = 35 - i * 10
        pygame.draw.circle(surface, (*ninja_highlight, alpha), (cx - 8, head_y - 12), r)

    # === 복면 띠 (눈 가리는 부분) ===
    band_rect = pygame.Rect(cx - 75, head_y - 12, 150, 24)
    pygame.draw.rect(surface, mask_band, band_rect, border_radius=4)

    # 띠 끝 (뒤로 나부끼는 부분) - 더 역동적으로
    # 왼쪽 띠 끝
    band_end_points_l = [
        (cx - 75, head_y - 3),
        (cx - 105, head_y + 25),
        (cx - 135, head_y + 45),
        (cx - 130, head_y + 55),
        (cx - 100, head_y + 35),
        (cx - 75, head_y + 8),
    ]
    pygame.draw.polygon(surface, mask_band, band_end_points_l)

    # 오른쪽 띠 끝
    band_end_points_r = [
        (cx + 75, head_y - 3),
        (cx + 100, head_y + 20),
        (cx + 125, head_y + 35),
        (cx + 120, head_y + 45),
        (cx + 95, head_y + 28),
        (cx + 75, head_y + 8),
    ]
    pygame.draw.polygon(surface, mask_band, band_end_points_r)

    # === 눈 (날카로운 눈 - 복면 사이로 보임) ===
    eye_y = head_y
    eye_spacing = 25

    # 날카로운 눈 모양 (삼각형에 가까운)
    left_eye_points = [
        (cx - eye_spacing - 15, eye_y),
        (cx - eye_spacing, eye_y - 6),
        (cx - eye_spacing + 12, eye_y),
        (cx - eye_spacing, eye_y + 4),
    ]
    pygame.draw.polygon(surface, eye_color, left_eye_points)

    right_eye_points = [
        (cx + eye_spacing - 12, eye_y),
        (cx + eye_spacing, eye_y - 6),
        (cx + eye_spacing + 15, eye_y),
        (cx + eye_spacing, eye_y + 4),
    ]
    pygame.draw.polygon(surface, eye_color, right_eye_points)

    # === 왼팔 (표창 들고 있음) ===
    left_shoulder = (cx - 95, cy - 25)
    left_elbow = (cx - 150, cy + 30)
    left_hand = (cx - 175, cy - 10)

    # 팔 (위에서 보는 시점)
    pygame.draw.line(surface, ninja_dark, left_shoulder, left_elbow, 26)
    pygame.draw.line(surface, ninja_dark, left_elbow, left_hand, 22)

    # 팔 관절
    pygame.draw.circle(surface, ninja_black, left_elbow, 13)

    # 손
    pygame.draw.circle(surface, skin_color, left_hand, 16)

    # === 표창 (왼손에) ===
    shuriken_x, shuriken_y = left_hand[0] - 30, left_hand[1] - 30
    shuriken_size = 45

    # 표창 그리기 (4개 날)
    for i in range(4):
        angle = i * (math.pi / 2) + math.pi / 4  # 45도 회전

        # 바깥 뾰족점
        outer_x = shuriken_x + math.cos(angle) * shuriken_size
        outer_y = shuriken_y + math.sin(angle) * shuriken_size

        # 안쪽 점들
        left_angle = angle - 0.5
        right_angle = angle + 0.5
        inner_dist = shuriken_size * 0.25
        left_x = shuriken_x + math.cos(left_angle) * inner_dist
        left_y = shuriken_y + math.sin(left_angle) * inner_dist
        right_x = shuriken_x + math.cos(right_angle) * inner_dist
        right_y = shuriken_y + math.sin(right_angle) * inner_dist

        points = [(shuriken_x, shuriken_y), (left_x, left_y), (outer_x, outer_y), (right_x, right_y)]
        pygame.draw.polygon(surface, shuriken_metal, points)
        pygame.draw.polygon(surface, shuriken_dark, points, 2)

    # 표창 중앙 구멍
    pygame.draw.circle(surface, shuriken_dark, (int(shuriken_x), int(shuriken_y)), 7)
    pygame.draw.circle(surface, (40, 40, 50), (int(shuriken_x), int(shuriken_y)), 4)

    # === 오른팔 (탁구채 들고 있음) ===
    right_shoulder = (cx + 95, cy - 25)
    right_elbow = (cx + 145, cy + 35)
    right_hand = (cx + 170, cy - 5)

    # 팔
    pygame.draw.line(surface, ninja_dark, right_shoulder, right_elbow, 26)
    pygame.draw.line(surface, ninja_dark, right_elbow, right_hand, 22)

    # 팔 관절
    pygame.draw.circle(surface, ninja_black, right_elbow, 13)

    # 손
    pygame.draw.circle(surface, skin_color, right_hand, 16)

    # === 탁구채 (오른손에) ===
    paddle_cx = right_hand[0] + 45
    paddle_cy = right_hand[1] - 25
    paddle_width = 60
    paddle_height = 75

    # 손잡이
    handle_start = right_hand
    handle_end = (paddle_cx - paddle_width//2 + 8, paddle_cy + paddle_height//2 - 5)
    pygame.draw.line(surface, paddle_handle, handle_start, handle_end, 12)
    pygame.draw.line(surface, (100, 70, 50), handle_start, handle_end, 8)

    # 탁구채 머리 (위에서 보면 원형에 가까움)
    # 나무 부분
    paddle_rect = pygame.Rect(paddle_cx - paddle_width//2, paddle_cy - paddle_height//2,
                              paddle_width, paddle_height)
    pygame.draw.ellipse(surface, paddle_wood, paddle_rect)

    # 러버 부분 (빨강)
    rubber_rect = pygame.Rect(paddle_cx - paddle_width//2 + 4, paddle_cy - paddle_height//2 + 4,
                              paddle_width - 8, paddle_height - 8)
    pygame.draw.ellipse(surface, paddle_rubber_red, rubber_rect)

    # 러버 하이라이트
    highlight_rect = pygame.Rect(paddle_cx - paddle_width//2 + 12, paddle_cy - paddle_height//2 + 8,
                                 20, 30)
    pygame.draw.ellipse(surface, (200, 80, 80), highlight_rect)

    # === 다리 (탑뷰 - 아래쪽에 살짝 보임) ===
    # 왼다리
    left_leg_points = [
        (cx - 45, cy + 55),
        (cx - 60, cy + 115),
        (cx - 42, cy + 125),
        (cx - 28, cy + 65),
    ]
    pygame.draw.polygon(surface, ninja_dark, left_leg_points)

    # 오른다리
    right_leg_points = [
        (cx + 45, cy + 55),
        (cx + 60, cy + 115),
        (cx + 42, cy + 125),
        (cx + 28, cy + 65),
    ]
    pygame.draw.polygon(surface, ninja_dark, right_leg_points)

    # 발 (검은색 닌자 신발)
    pygame.draw.ellipse(surface, ninja_black, (cx - 70, cy + 110, 32, 22))
    pygame.draw.ellipse(surface, ninja_black, (cx + 38, cy + 110, 32, 22))

    # === 등에 칼집 ===
    sword_sheath_points = [
        (cx + 15, cy - 40),
        (cx + 25, cy - 45),
        (cx + 50, cy + 70),
        (cx + 40, cy + 75),
    ]
    pygame.draw.polygon(surface, (50, 40, 35), sword_sheath_points)
    pygame.draw.polygon(surface, (70, 55, 45), sword_sheath_points, 2)

    # 칼 손잡이 (등에서 삐져나옴)
    pygame.draw.rect(surface, (80, 60, 40), (cx + 10, cy - 55, 18, 18), border_radius=3)
    pygame.draw.rect(surface, (120, 90, 60), (cx + 13, cy - 52, 12, 12), border_radius=2)

    # === 허리띠 ===
    belt_rect = pygame.Rect(cx - 75, cy + 40, 150, 18)
    pygame.draw.rect(surface, (60, 50, 45), belt_rect, border_radius=4)

    # 허리띠 버클
    pygame.draw.rect(surface, (150, 140, 100), (cx - 12, cy + 42, 24, 14), border_radius=3)

    # === 최종 테두리/윤곽 강조 ===
    # 머리 윤곽
    pygame.draw.circle(surface, (15, 15, 20), (cx, head_y), head_radius, 2)

    # 저장
    output_path = os.path.join(os.path.dirname(__file__), "boss_stage8.png")
    pygame.image.save(surface, output_path)
    print(f"Boss Stage 8 image saved to: {output_path}")

    pygame.quit()
    return output_path

if __name__ == "__main__":
    generate_boss_stage8()
