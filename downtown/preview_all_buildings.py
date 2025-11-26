#!/usr/bin/env python3
"""
번화가 건물 디자인 미리보기 생성기
여러 StarBank 디자인 옵션을 시각적으로 비교
"""

import sys
import os
import pygame
import math
import random

# 프로젝트 루트를 path에 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from downtown.constants import *
from downtown.building_designs import BuildingRenderer

# 5가지 StarBank 디자인 옵션
DESIGN_OPTIONS = {
    "1. 현재 (우아한 대리석)": "현재 적용된 디자인 - 대리석 건축 + 황금 악센트",
    "2. 네온 사이버": "사이버펑크 스타일 - 네온 글로우 + 홀로그램 효과",
    "3. 크리스탈 궁전": "판타지 스타일 - 크리스탈 구조 + 마법 효과",
    "4. 황금 신전": "고대 신전 스타일 - 황금 피라미드 + 별빛 장식",
    "5. 미래 은행": "미래적 스타일 - 유리 + 홀로그램 + 에너지 필드"
}

def create_preview_image():
    """5가지 디자인 미리보기 이미지 생성"""
    pygame.init()

    # 전체 캔버스 크기 (5개를 가로로 배치)
    preview_width = 600
    preview_height = 200
    screen = pygame.Surface((preview_width, preview_height))
    screen.fill((20, 20, 30))

    # 건물 렌더러 초기화
    renderer = BuildingRenderer()
    renderer.animation_timer = 0

    # 각 디자인별 미리보기 생성
    design_width = preview_width // 5

    for i in range(5):
        x_offset = i * design_width

        # 디자인 번호 표시
        font = pygame.font.Font(None, 24)
        title = font.render(f"Option {i+1}", True, (255, 215, 0))
        screen.blit(title, (x_offset + 10, 10))

        # 건물 미리보기 (작은 크기)
        building_x = x_offset + design_width // 2 - 40
        building_y = 60

        # 임시 건물 객체
        class TempBuilding:
            def __init__(self):
                self.width = 85
                self.height = 80

        temp_building = TempBuilding()

        # 현재는 모두 같은 디자인 (나중에 각각 다른 함수로 변경)
        renderer._draw_bank(screen, temp_building, building_x, building_y, i)

        # 설명 텍스트
        desc_font = pygame.font.Font(None, 16)
        desc_lines = list(DESIGN_OPTIONS.values())[i].split(" - ")
        for idx, line in enumerate(desc_lines):
            desc_text = desc_font.render(line, True, (200, 200, 200))
            screen.blit(desc_text, (x_offset + 5, 150 + idx * 18))

    # 이미지 저장
    output_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                               "..", "downtown_buildings_preview.png")
    pygame.image.save(screen, output_path)
    print(f"✅ 미리보기 이미지 저장: {output_path}")

    return output_path

def print_design_options():
    """디자인 옵션 출력"""
    print("\n" + "="*80)
    print("🏦 StarBank 디자인 옵션")
    print("="*80 + "\n")

    for i, (title, desc) in enumerate(DESIGN_OPTIONS.items(), 1):
        print(f"{title}")
        print(f"   └─ {desc}")
        print()

    print("="*80)
    print("각 디자인의 시각적 미리보기를 생성하려면 이미지를 확인하세요.")
    print("="*80 + "\n")

if __name__ == "__main__":
    print_design_options()
    create_preview_image()
