#!/usr/bin/env python3
"""
포세이돈 삼지창 아이콘만 포함된 PNG 파일 생성 스크립트
(테두리 없이 아이콘만)
"""

import pygame
import os
import math

pygame.init()

def create_poseidon_icon_only(frame_num):
    """포세이돈 삼지창 아이콘만 생성 (테두리 제외)"""
    frame = pygame.Surface((64, 64), pygame.SRCALPHA)
    
    # 애니메이션 진행도 (0.0 ~ 1.0)
    progress = frame_num / 8.0
    
    # 회색 배경 (라그나로크 해머와 동일) - 약간 작게
    background_color = (80, 80, 80, 200)  # 어두운 회색 배경
    pygame.draw.rect(frame, background_color, (6, 6, 52, 52))  # 테두리 공간 확보
    
    # 에너지 필드 효과 (라그나로크 해머와 동일)
    energy_alpha = 60 + int(30 * math.sin(progress * math.pi * 2))
    for ring in range(2):  # 2개의 링
        ring_size = 26 - ring * 8  # 살짝 작게
        ring_alpha = energy_alpha - ring * 20
        if ring_alpha > 0:
            energy_color = (255, 50, 50, ring_alpha)
            pygame.draw.circle(frame, energy_color, (32, 32), ring_size, 2)
    
    # 포세이돈의 삼지창 그리기 (중앙에)
    # 삼지창 색상 - 바다의 푸른색과 금속 실버
    trident_color = (100, 180, 255)  # 바다색
    metal_color = (200, 220, 240)    # 은빛 금속
    highlight_color = (255, 255, 255)  # 하이라이트
    
    # 삼지창 손잡이 (아래쪽)
    handle_width = 4
    handle_height = 35
    handle_x = 32 - handle_width // 2
    handle_y = 32 - 5
    
    # 손잡이 그리기 (그라데이션 효과)
    for offset in range(handle_width):
        color_intensity = 1.0 - (abs(offset - handle_width/2) / (handle_width/2))
        color_r = int(metal_color[0] * color_intensity + trident_color[0] * (1-color_intensity))
        color_g = int(metal_color[1] * color_intensity + trident_color[1] * (1-color_intensity))
        color_b = int(metal_color[2] * color_intensity + trident_color[2] * (1-color_intensity))
        pygame.draw.line(frame, (color_r, color_g, color_b),
                       (handle_x + offset, handle_y),
                       (handle_x + offset, handle_y + handle_height), 1)
    
    # 삼지창 머리 부분 (3개의 창)
    prong_length = 20
    prong_base_y = handle_y - 2
    
    # 중앙 창 (더 길게)
    center_x = 32
    pygame.draw.polygon(frame, trident_color, [
        (center_x - 2, prong_base_y),
        (center_x + 2, prong_base_y),
        (center_x + 1, prong_base_y - prong_length - 3),
        (center_x, prong_base_y - prong_length - 5),  # 뾰족한 끝
        (center_x - 1, prong_base_y - prong_length - 3)
    ])
    
    # 왼쪽 창 (약간 짧고 바깥쪽으로 휘어짐)
    left_x = center_x - 8
    pygame.draw.polygon(frame, trident_color, [
        (left_x, prong_base_y),
        (left_x + 3, prong_base_y),
        (left_x + 2, prong_base_y - prong_length + 2),
        (left_x - 1, prong_base_y - prong_length),  # 뾰족한 끝
        (left_x - 2, prong_base_y - prong_length + 3)
    ])
    
    # 오른쪽 창 (약간 짧고 바깥쪽으로 휘어짐)
    right_x = center_x + 5
    pygame.draw.polygon(frame, trident_color, [
        (right_x, prong_base_y),
        (right_x + 3, prong_base_y),
        (right_x + 4, prong_base_y - prong_length + 3),
        (right_x + 3, prong_base_y - prong_length),  # 뾰족한 끝
        (right_x, prong_base_y - prong_length + 2)
    ])
    
    # 창 연결 부분 (가로 막대)
    pygame.draw.rect(frame, metal_color, 
                   (center_x - 10, prong_base_y - 3, 20, 4))
    
    # 하이라이트 효과 (반짝임)
    if frame_num % 3 == 0:  # 3프레임마다 반짝임
        # 중앙 창 하이라이트
        pygame.draw.line(frame, highlight_color,
                       (center_x, prong_base_y - 2),
                       (center_x, prong_base_y - prong_length - 3), 1)
        # 좌우 창 하이라이트
        pygame.draw.line(frame, highlight_color,
                       (left_x + 1, prong_base_y - 2),
                       (left_x, prong_base_y - prong_length + 2), 1)
        pygame.draw.line(frame, highlight_color,
                       (right_x + 2, prong_base_y - 2),
                       (right_x + 3, prong_base_y - prong_length + 2), 1)
    
    # 물의 효과 (작은 물방울들)
    if frame_num % 2 == 0:
        for bubble in range(2):
            bubble_x = 32 + (bubble - 1) * 15
            bubble_y = 40 + (frame_num % 4) * 3
            pygame.draw.circle(frame, (150, 200, 255, 100), 
                             (bubble_x, bubble_y), 2)
    
    return frame


def main():
    """메인 함수"""
    output_dir = "items/legendary"
    
    # 디렉토리 확인
    if not os.path.exists(output_dir):
        print(f"디렉토리 생성: {output_dir}")
        os.makedirs(output_dir)
    
    # 새 PNG 파일 생성 (아이콘만)
    for i in range(8):
        frame = create_poseidon_icon_only(i)
        filename = os.path.join(output_dir, f"poseidon_trident_frame_{i}.png")
        pygame.image.save(frame, filename)
        print(f"생성됨: {filename} (아이콘만)")
    
    # 메인 아이콘도 생성 (frame_0과 동일)
    main_frame = create_poseidon_icon_only(0)
    main_filename = os.path.join(output_dir, "poseidon_trident.png")
    pygame.image.save(main_frame, main_filename)
    print(f"생성됨: {main_filename} (아이콘만)")
    
    print("\n✅ 포세이돈 삼지창 PNG 파일 생성 완료!")
    print("   - 아이콘만 포함 (테두리 제외)")
    print("   - 테두리는 draw_icon 메서드에서 별도로 그려야 함")


if __name__ == "__main__":
    main()