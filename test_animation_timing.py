#!/usr/bin/env python3
"""
아카데미 스킬 레벨업 애니메이션 타이밍 테스트
"""

import pygame
import sys
import os
import math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from academy import AcademyUI, skill_system

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((600, 750))
pygame.display.set_caption("Animation Timing Test")
clock = pygame.time.Clock()

# 아카데미 인스턴스 생성
academy = AcademyUI(screen)
academy.academy_active = True

# 스킬 포인트 추가 (테스트용)
skill_system.skill_points = 100

# 테스트할 스킬 선택
test_skill = "dash_lightweight"  # 첫 번째 스킬

def run_test():
    """애니메이션 타이밍 테스트 실행"""
    running = True
    animation_started = False
    start_time = 0
    last_print_time = 0
    
    while running:
        current_time = pygame.time.get_ticks()
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE and not animation_started:
                    # 스페이스바를 누르면 스킬 업그레이드 및 애니메이션 시작
                    print("\n=== 스킬 업그레이드 시작 ===")
                    old_level = skill_system.get_skill_level(test_skill)
                    
                    if skill_system.can_upgrade_skill(test_skill):
                        skill_system.upgrade_skill(test_skill)
                        new_level = skill_system.get_skill_level(test_skill)
                        print(f"스킬 레벨: {old_level} -> {new_level}")
                        
                        # 애니메이션 시작
                        academy.start_levelup_animation(test_skill)
                        animation_started = True
                        start_time = current_time
                        print(f"애니메이션 시작 시간: {start_time}ms")
                    else:
                        print("스킬을 업그레이드할 수 없습니다.")
                elif event.key == pygame.K_r:
                    # R키로 리셋
                    animation_started = False
                    academy.skill_levelup_animations.clear()
                    print("\n애니메이션 리셋")
                elif event.key == pygame.K_ESCAPE:
                    running = False
        
        # 화면 그리기
        screen.fill((30, 30, 30))
        
        # 아카데미 화면 그리기
        academy.draw()
        
        # 애니메이션 상태 확인 (100ms마다)
        if animation_started and current_time - last_print_time > 100:
            elapsed = current_time - start_time
            if test_skill in academy.skill_levelup_animations:
                anim_data = academy.skill_levelup_animations[test_skill]
                actual_elapsed = current_time - anim_data["start_time"]
                print(f"Time: {elapsed}ms, Actual: {actual_elapsed}ms, Duration: {anim_data['duration']}ms, Active: True")
            else:
                print(f"Time: {elapsed}ms, Animation DELETED!")
                animation_started = False
            last_print_time = current_time
        
        # 설명 텍스트
        font = pygame.font.Font(None, 24)
        text1 = font.render("Press SPACE to trigger skill upgrade animation", True, (255, 255, 255))
        text2 = font.render("Press R to reset, ESC to quit", True, (200, 200, 200))
        text3 = font.render(f"Animation active: {test_skill in academy.skill_levelup_animations}", True, (255, 255, 0))
        
        screen.blit(text1, (50, 20))
        screen.blit(text2, (50, 45))
        screen.blit(text3, (50, 70))
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()

if __name__ == "__main__":
    print("=== 애니메이션 타이밍 테스트 ===")
    print("스페이스바: 스킬 업그레이드 및 애니메이션 시작")
    print("R: 리셋")
    print("ESC: 종료")
    print("=" * 40)
    run_test()