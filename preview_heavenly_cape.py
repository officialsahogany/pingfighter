"""HeavenlyCape 프레임 시각 QA 스크립트.

신규 pygame 프리미티브 기반 망토 아이콘 8프레임을 렌더해서
preview_heavenly_cape_x8.png 로 저장. 합치면 HUD 크기 / 크게 보는 양쪽 확인 가능.
"""

import os
import sys

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import pygame

pygame.init()
pygame.display.set_mode((1, 1))

from legendary_items import HeavenlyCape  # noqa: E402

cape = HeavenlyCape()
ICON_SIZE = 32
FRAMES = 8

# 각 프레임을 HUD 크기 (32) 로 렌더 — draw_icon 호출 (공통 전설 프레임 포함)
strip = pygame.Surface((ICON_SIZE * FRAMES, ICON_SIZE), pygame.SRCALPHA)
for i in range(FRAMES):
    cape.current_frame = i
    cape.frame_counter = 0
    cape.animation_time = i * 0.4
    single = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
    cape.draw_icon(single, 0, 0, ICON_SIZE)
    strip.blit(single, (i * ICON_SIZE, 0))

# 원본 32×32 스트립
out_path = "items/legendary/_qa_heavenly_cape_preview.png"
pygame.image.save(strip, out_path)
print(f"원본 스트립: {out_path}")

# 8배 확대 스트립
big = pygame.transform.scale(strip, (ICON_SIZE * FRAMES * 8, ICON_SIZE * 8))
big_path = "items/legendary/_qa_heavenly_cape_preview_x8.png"
pygame.image.save(big, big_path)
print(f"8x 확대: {big_path}")

sys.exit(0)
