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
    eye_white = (200, 200, 210)         # 눈 흰자
    eye_pupil = (60, 60, 80)            # 눈동자
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
                       (cx - 140 + shadow_offset, cy - 100 + shadow_offset, 280, 200))

    # === 몸통 (탑뷰 - 어깨와 등이 보임) ===
    # 어깨/등 부분 (타원형)
    body_rect = pygame.Rect(cx - 120, cy - 80, 240, 160)
    pygame.draw.ellipse(surface, ninja_black, body_rect)

    # 어깨 하이라이트
    for i in range(3):
        highlight_rect = pygame.Rect(cx - 100 + i*5, cy - 60 + i*5, 200 - i*10, 100 - i*10)
        alpha = 30 - i * 10
        highlight_surf = pygame.Surface((200, 100), pygame.SRCALPHA)
        pygame.draw.ellipse(highlight_surf, (*ninja_highlight, alpha), (0, 0, 200 - i*10, 100 - i*10))
        surface.blit(highlight_surf, (cx - 100 + i*5, cy - 60 + i*5))

    # === 머리 (탑뷰 - 복면 쓴 머리 위에서 봄) ===
    head_y = cy - 100
    head_radius = 75

    # 머리 기본
    pygame.draw.circle(surface, ninja_black, (cx, head_y), head_radius)

    # 머리 위 하이라이트
    for i in range(3):
        r = head_radius - 15 - i * 10
        alpha = 40 - i * 12
        pygame.draw.circle(surface, (*ninja_highlight, alpha), (cx - 10, head_y - 15), r)

    # === 복면 띠 (눈 가리는 부분 - 위에서 보면 띠처럼 보임) ===
    band_rect = pygame.Rect(cx - 85, head_y - 15, 170, 30)
    pygame.draw.rect(surface, mask_band, band_rect, border_radius=5)

    # 띠 끝 (뒤로 나부끼는 부분)
    # 왼쪽 띠 끝
    band_end_points_l = [
        (cx - 85, head_y - 5),
        (cx - 120, head_y + 20),
        (cx - 150, head_y + 30),
        (cx - 145, head_y + 40),
        (cx - 110, head_y + 25),
        (cx - 85, head_y + 10),
    ]
    pygame.draw.polygon(surface, mask_band, band_end_points_l)

    # 오른쪽 띠 끝
    band_end_points_r = [
        (cx + 85, head_y - 5),
        (cx + 115, head_y + 15),
        (cx + 140, head_y + 25),
        (cx + 135, head_y + 35),
        (cx + 105, head_y + 20),
        (cx + 85, head_y + 10),
    ]
    pygame.draw.polygon(surface, mask_band, band_end_points_r)

    # === 눈 (위에서 보면 띠 안에 눈이 살짝 보임) ===
    eye_y = head_y
    eye_spacing = 30
    eye_width = 25
    eye_height = 12

    # 왼쪽 눈
    pygame.draw.ellipse(surface, eye_white, (cx - eye_spacing - eye_width//2, eye_y - eye_height//2,
                                             eye_width, eye_height))
    pygame.draw.circle(surface, eye_pupil, (cx - eye_spacing, eye_y), 5)

    # 오른쪽 눈
    pygame.draw.ellipse(surface, eye_white, (cx + eye_spacing - eye_width//2, eye_y - eye_height//2,
                                             eye_width, eye_height))
    pygame.draw.circle(surface, eye_pupil, (cx + eye_spacing, eye_y), 5)

    # === 왼팔 (표창 들고 있음) ===
    # 어깨에서 팔꿈치
    left_shoulder = (cx - 110, cy - 40)
    left_elbow = (cx - 170, cy + 20)
    left_hand = (cx - 200, cy - 30)

    # 팔 (위에서 보는 시점)
    pygame.draw.line(surface, ninja_dark, left_shoulder, left_elbow, 28)
    pygame.draw.line(surface, ninja_dark, left_elbow, left_hand, 24)

    # 팔 관절
    pygame.draw.circle(surface, ninja_black, left_elbow, 14)

    # 손
    pygame.draw.circle(surface, skin_color, left_hand, 18)

    # === 표창 (왼손에) ===
    shuriken_x, shuriken_y = left_hand[0] - 25, left_hand[1] - 25
    shuriken_size = 50

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
    pygame.draw.circle(surface, shuriken_dark, (int(shuriken_x), int(shuriken_y)), 8)
    pygame.draw.circle(surface, (40, 40, 50), (int(shuriken_x), int(shuriken_y)), 5)

    # === 오른팔 (탁구채 들고 있음) ===
    right_shoulder = (cx + 110, cy - 40)
    right_elbow = (cx + 160, cy + 30)
    right_hand = (cx + 190, cy - 20)

    # 팔
    pygame.draw.line(surface, ninja_dark, right_shoulder, right_elbow, 28)
    pygame.draw.line(surface, ninja_dark, right_elbow, right_hand, 24)

    # 팔 관절
    pygame.draw.circle(surface, ninja_black, right_elbow, 14)

    # 손
    pygame.draw.circle(surface, skin_color, right_hand, 18)

    # === 탁구채 (오른손에) ===
    paddle_cx = right_hand[0] + 50
    paddle_cy = right_hand[1] - 30
    paddle_width = 70
    paddle_height = 85

    # 손잡이
    handle_start = right_hand
    handle_end = (paddle_cx - paddle_width//2 + 10, paddle_cy + paddle_height//2 - 5)
    pygame.draw.line(surface, paddle_handle, handle_start, handle_end, 14)
    pygame.draw.line(surface, (100, 70, 50), handle_start, handle_end, 10)

    # 탁구채 머리 (위에서 보면 원형에 가까움)
    # 나무 부분
    paddle_rect = pygame.Rect(paddle_cx - paddle_width//2, paddle_cy - paddle_height//2,
                              paddle_width, paddle_height)
    pygame.draw.ellipse(surface, paddle_wood, paddle_rect)

    # 러버 부분 (빨강)
    rubber_rect = pygame.Rect(paddle_cx - paddle_width//2 + 5, paddle_cy - paddle_height//2 + 5,
                              paddle_width - 10, paddle_height - 10)
    pygame.draw.ellipse(surface, paddle_rubber_red, rubber_rect)

    # 러버 하이라이트
    highlight_rect = pygame.Rect(paddle_cx - paddle_width//2 + 15, paddle_cy - paddle_height//2 + 10,
                                 25, 35)
    pygame.draw.ellipse(surface, (200, 80, 80, 150), highlight_rect)

    # === 다리 (탑뷰 - 아래쪽에 살짝 보임) ===
    # 왼다리
    left_leg_points = [
        (cx - 50, cy + 60),
        (cx - 70, cy + 130),
        (cx - 50, cy + 140),
        (cx - 30, cy + 70),
    ]
    pygame.draw.polygon(surface, ninja_dark, left_leg_points)

    # 오른다리
    right_leg_points = [
        (cx + 50, cy + 60),
        (cx + 70, cy + 130),
        (cx + 50, cy + 140),
        (cx + 30, cy + 70),
    ]
    pygame.draw.polygon(surface, ninja_dark, right_leg_points)

    # 발 (검은색 닌자 신발)
    pygame.draw.ellipse(surface, ninja_black, (cx - 80, cy + 125, 35, 25))
    pygame.draw.ellipse(surface, ninja_black, (cx + 45, cy + 125, 35, 25))

    # === 등에 칼집 ===
    sword_sheath_points = [
        (cx + 20, cy - 50),
        (cx + 30, cy - 55),
        (cx + 60, cy + 80),
        (cx + 50, cy + 85),
    ]
    pygame.draw.polygon(surface, (50, 40, 35), sword_sheath_points)
    pygame.draw.polygon(surface, (70, 55, 45), sword_sheath_points, 2)

    # 칼 손잡이 (등에서 삐져나옴)
    pygame.draw.rect(surface, (80, 60, 40), (cx + 15, cy - 65, 20, 20), border_radius=3)
    pygame.draw.rect(surface, (120, 90, 60), (cx + 18, cy - 62, 14, 14), border_radius=2)

    # === 허리띠 ===
    belt_rect = pygame.Rect(cx - 90, cy + 45, 180, 20)
    pygame.draw.rect(surface, (60, 50, 45), belt_rect, border_radius=5)

    # 허리띠 버클
    pygame.draw.rect(surface, (150, 140, 100), (cx - 15, cy + 47, 30, 16), border_radius=3)

    # === 최종 테두리/윤곽 강조 ===
    # 머리 윤곽
    pygame.draw.circle(surface, (15, 15, 20), (cx, head_y), head_radius, 3)

    # 저장
    output_path = os.path.join(os.path.dirname(__file__), "boss_stage8.png")
    pygame.image.save(surface, output_path)
    print(f"Boss Stage 8 image saved to: {output_path}")

    pygame.quit()
    return output_path

if __name__ == "__main__":
    generate_boss_stage8()
