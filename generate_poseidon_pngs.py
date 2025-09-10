#!/usr/bin/env python3
"""
포세이돈 삼지창 PNG 파일 생성 스크립트
라그나로크 해머/헤르메스 신발과 동일한 테두리 + 이전 삼지창 디자인
"""

import pygame
import os
import math

pygame.init()

def create_poseidon_frame(frame_num):
    """포세이돈 삼지창 프레임 생성"""
    frame = pygame.Surface((64, 64), pygame.SRCALPHA)
    
    # 애니메이션 진행도 (0.0 ~ 1.0)
    progress = frame_num / 8.0
    
    # 회색 배경 (라그나로크 해머와 동일)
    background_color = (80, 80, 80, 200)  # 어두운 회색 배경
    pygame.draw.rect(frame, background_color, (4, 4, 56, 56))  # 배경 채우기
    
    # 에너지 필드 효과 (라그나로크 해머와 동일)
    energy_alpha = 60 + int(30 * math.sin(progress * math.pi * 2))
    for ring in range(2):  # 2개의 링
        ring_size = 28 - ring * 8
        ring_alpha = energy_alpha - ring * 20
        if ring_alpha > 0:
            energy_color = (255, 50, 50, ring_alpha)
            pygame.draw.circle(frame, energy_color, (32, 32), ring_size, 2)
    
    # 이중 테두리 애니메이션 (프레임마다 색상 변화)
    # 외부 테두리 - 프레임에 따라 색상 변화
    if frame_num % 4 == 0:
        outer_border_color = (255, 215, 0, 255)  # 황금색
    elif frame_num % 4 == 1:
        outer_border_color = (255, 0, 0, 255)    # 빨간색
    elif frame_num % 4 == 2:
        outer_border_color = (0, 150, 255, 255)  # 파란색
    else:
        outer_border_color = (255, 100, 0, 255)  # 주황색
    
    # 외부 테두리 그리기
    pygame.draw.rect(frame, outer_border_color, (0, 0, 64, 64), 3)  # 외부 테두리
    
    # 내부 테두리 - 프레임에 따라 색상 변화 (외부와 반대)
    if frame_num % 4 == 0:
        inner_border_color = (255, 0, 0, 255)    # 빨간색
    elif frame_num % 4 == 1:
        inner_border_color = (0, 150, 255, 255)  # 파란색
    elif frame_num % 4 == 2:
        inner_border_color = (255, 215, 0, 255)  # 황금색
    else:
        inner_border_color = (150, 0, 255, 255)  # 보라색
    
    pygame.draw.rect(frame, inner_border_color, (2, 2, 60, 60), 2)  # 내부 테두리
    
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
    
    # 백업 디렉토리 생성
    backup_dir = os.path.join(output_dir, "backup")
    if not os.path.exists(backup_dir):
        os.makedirs(backup_dir)
    
    # 기존 파일 백업
    for i in range(8):
        original_file = os.path.join(output_dir, f"poseidon_trident_frame_{i}.png")
        backup_file = os.path.join(backup_dir, f"poseidon_trident_frame_{i}_backup.png")
        if os.path.exists(original_file):
            try:
                # 백업
                import shutil
                shutil.copy2(original_file, backup_file)
                print(f"백업됨: {backup_file}")
            except Exception as e:
                print(f"백업 실패: {e}")
    
    # 새 PNG 파일 생성
    for i in range(8):
        frame = create_poseidon_frame(i)
        filename = os.path.join(output_dir, f"poseidon_trident_frame_{i}.png")
        pygame.image.save(frame, filename)
        print(f"생성됨: {filename}")
    
    # 메인 아이콘도 생성 (frame_0과 동일)
    main_frame = create_poseidon_frame(0)
    main_filename = os.path.join(output_dir, "poseidon_trident.png")
    pygame.image.save(main_frame, main_filename)
    print(f"생성됨: {main_filename}")
    
    print("\n✅ 포세이돈 삼지창 PNG 파일 생성 완료!")
    print("   - 이중 테두리 애니메이션 (라그나로크/헤르메스와 동일)")
    print("   - 이전 삼지창 디자인 복원")


if __name__ == "__main__":
    main()