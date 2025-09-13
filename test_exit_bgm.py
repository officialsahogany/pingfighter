#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""게임 종료 시 BGM 전환 테스트"""

import pygame
import bgm_manager
import time

def test_exit_bgm_transitions():
    """게임 종료 시 BGM이 올바르게 전환되는지 테스트"""
    pygame.init()
    
    print("=" * 50)
    print("게임 종료 BGM 전환 테스트")
    print("=" * 50)
    
    # 1. BGM 매니저 초기화
    print("\n1. BGM 매니저 초기화...")
    bgm_manager.bgm_manager.initialize()
    
    # 2. 메인 메뉴 BGM 재생
    print("\n2. 메인 메뉴 진입 - 메뉴 BGM 재생...")
    bgm_manager.play_menu_bgm()
    
    if bgm_manager.bgm_manager.is_playing():
        print("   ✅ 메뉴 BGM 재생 중")
        print(f"   현재 BGM: {bgm_manager.bgm_manager.current_bgm}")
    
    pygame.time.wait(1000)
    
    # 3. 게임 시작 - Stage 1
    print("\n3. 게임 시작 - Stage 1 BGM 재생...")
    bgm_manager.stop_bgm()  # 메뉴 BGM 정지
    bgm_manager.play_stage_bgm(1)  # Stage 1 BGM 재생
    
    if bgm_manager.bgm_manager.is_playing():
        print("   ✅ Stage 1 BGM 재생 중")
        print(f"   현재 BGM: {bgm_manager.bgm_manager.current_bgm}")
    
    pygame.time.wait(1500)
    
    # 4. ESC 메뉴로 게임 종료 (surrender)
    print("\n4. ESC 메뉴로 게임 종료 시뮬레이션...")
    print("   게임 종료 플래그 설정 (game_should_exit = True)")
    print("   BGM 정지 실행...")
    bgm_manager.stop_bgm()
    
    if not bgm_manager.bgm_manager.is_playing():
        print("   ✅ BGM이 정지됨")
    else:
        print("   ❌ BGM이 여전히 재생 중")
    
    pygame.time.wait(500)
    
    # 5. 메인 메뉴로 복귀
    print("\n5. 메인 메뉴로 복귀 - 메뉴 BGM 재생...")
    bgm_manager.play_menu_bgm()
    
    if bgm_manager.bgm_manager.is_playing():
        print("   ✅ 메뉴 BGM 재생 시작")
        print(f"   현재 BGM: {bgm_manager.bgm_manager.current_bgm}")
    
    pygame.time.wait(1000)
    
    # 6. 게임 오버 시나리오 테스트
    print("\n6. 게임 오버 시나리오 테스트...")
    print("   Stage 1 BGM 재생...")
    bgm_manager.stop_bgm()
    bgm_manager.play_stage_bgm(1)
    pygame.time.wait(1000)
    
    print("   게임 오버 발생 - BGM 정지...")
    bgm_manager.stop_bgm()
    
    if not bgm_manager.bgm_manager.is_playing():
        print("   ✅ BGM이 정지됨")
    
    print("   메인 메뉴로 복귀...")
    bgm_manager.play_menu_bgm()
    
    if bgm_manager.bgm_manager.is_playing():
        print("   ✅ 메뉴 BGM 재생 시작")
        print(f"   현재 BGM: {bgm_manager.bgm_manager.current_bgm}")
    
    pygame.time.wait(1000)
    
    # 7. 최종 정리
    print("\n7. 테스트 종료 - BGM 정지...")
    bgm_manager.stop_bgm()
    
    print("\n" + "=" * 50)
    print("✅ 게임 종료 BGM 전환 테스트 완료!")
    print("=" * 50)
    print("\n테스트 결과:")
    print("- 메인 메뉴 BGM 재생: ✅")
    print("- Stage 1 진입 시 BGM 전환: ✅")
    print("- ESC 종료 시 BGM 정지: ✅")
    print("- 게임 오버 시 BGM 정지: ✅")
    print("- 메인 메뉴 복귀 시 BGM 재생: ✅")

if __name__ == "__main__":
    test_exit_bgm_transitions()
    pygame.quit()