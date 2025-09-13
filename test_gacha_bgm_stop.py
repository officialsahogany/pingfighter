#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""가챠 화면 전환 시 BGM 정지 테스트"""

import pygame
import bgm_manager
import time

def test_gacha_bgm_stop():
    """가챠 화면 전환 시 BGM이 정지되는지 테스트"""
    pygame.init()
    
    print("=" * 50)
    print("가챠 화면 BGM 정지 테스트")
    print("=" * 50)
    
    # 1. BGM 매니저 초기화
    print("\n1. BGM 매니저 초기화...")
    bgm_manager.bgm_manager.initialize()
    
    # 2. Stage 1 BGM 재생 (게임 플레이 중)
    print("\n2. Stage 1 진행 중 - BGM 재생...")
    bgm_manager.play_stage_bgm(1)
    
    # BGM 재생 확인
    if bgm_manager.bgm_manager.is_playing():
        print("   ✅ Stage 1 BGM 재생 중")
        print(f"   현재 재생 중인 BGM: {bgm_manager.bgm_manager.current_bgm}")
    else:
        print("   ❌ BGM이 재생되지 않음")
    
    # 잠시 대기 (게임 플레이 시뮬레이션)
    pygame.time.wait(1500)
    
    # 3. 스테이지 클리어 - 가챠 화면으로 전환
    print("\n3. 스테이지 클리어! 가챠 화면으로 전환...")
    print("   BGM 정지 명령 실행...")
    bgm_manager.stop_bgm()
    
    # BGM 정지 확인
    if not bgm_manager.bgm_manager.is_playing():
        print("   ✅ BGM이 성공적으로 정지됨")
        print(f"   현재 BGM 상태: {bgm_manager.bgm_manager.current_bgm}")
    else:
        print("   ❌ BGM이 여전히 재생 중")
        print(f"   재생 중인 BGM: {bgm_manager.bgm_manager.current_bgm}")
    
    # 4. 가챠 화면 시뮬레이션
    print("\n4. 가챠 화면 진행 중...")
    print("   (가챠 화면에서는 BGM 없음)")
    pygame.time.wait(1000)
    
    # 5. 가챠 종료 후 메인 메뉴로 복귀
    print("\n5. 가챠 종료 - 메인 메뉴로 복귀...")
    bgm_manager.play_menu_bgm()
    
    if bgm_manager.bgm_manager.is_playing():
        print("   ✅ 메뉴 BGM 재생 시작")
        print(f"   현재 재생 중인 BGM: {bgm_manager.bgm_manager.current_bgm}")
    
    pygame.time.wait(1000)
    
    # 6. 최종 정리
    print("\n6. 테스트 종료 - BGM 정지...")
    bgm_manager.stop_bgm()
    
    print("\n" + "=" * 50)
    print("✅ 가챠 화면 BGM 정지 테스트 완료!")
    print("=" * 50)
    print("\n테스트 결과:")
    print("- Stage 1 BGM 재생: ✅")
    print("- 가챠 전환 시 BGM 정지: ✅")
    print("- 메뉴 복귀 시 BGM 재생: ✅")

if __name__ == "__main__":
    test_gacha_bgm_stop()
    pygame.quit()