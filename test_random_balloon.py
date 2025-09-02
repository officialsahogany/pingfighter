#!/usr/bin/env python3
"""
랜덤 풍선 이벤트 테스트
"""

import pygame
import sys
sys.path.append('/Users/pika/Desktop/game/bosspong')

from events.balloon_machine_event import BalloonMachineEvent

def test_random_balloons():
    """랜덤 풍선 발사 테스트"""
    pygame.init()
    screen = pygame.display.set_mode((600, 750))
    pygame.display.set_caption("Random Balloon Test")
    
    # 여러 번 이벤트 생성하여 랜덤성 확인
    for round_num in range(3):
        print(f"\n========== Round {round_num + 1} ==========")
        event = BalloonMachineEvent()
        event.activate(screen)
        
        # 발사 순서와 특별 풍선 위치 출력
        print(f"Special balloon index: {event.special_balloon_index}")
        print(f"Shoot order: {event.balloon_shoot_order}")
        print(f"Shoot angles (degrees): {[round(angle * 180 / 3.14159, 1) for angle in event.balloon_shoot_angles]}")
    
    pygame.quit()

if __name__ == "__main__":
    test_random_balloons()