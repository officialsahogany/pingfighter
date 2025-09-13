#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""BGM 모듈 테스트 스크립트"""

import pygame
import bgm_manager

def test_bgm_module():
    """BGM 모듈 기능 테스트"""
    pygame.init()
    
    print("=" * 50)
    print("BGM 모듈 테스트")
    print("=" * 50)
    
    # 1. BGM 매니저 초기화
    print("\n1. BGM 매니저 초기화...")
    bgm_manager.bgm_manager.initialize()
    
    # 2. 인트로 BGM 재생
    print("\n2. 인트로 BGM 재생...")
    bgm_manager.play_intro_bgm()
    pygame.time.wait(1000)
    
    # 3. 메뉴 BGM (이미 재생 중이므로 다시 로드하지 않아야 함)
    print("\n3. 메뉴 BGM 재생 시도...")
    bgm_manager.play_menu_bgm()
    pygame.time.wait(1000)
    
    # 4. 게임 시작 - BGM 정지
    print("\n4. 게임 시작 - BGM 정지...")
    bgm_manager.stop_bgm()
    pygame.time.wait(500)
    
    # 5. Stage 1 BGM 재생
    print("\n5. Stage 1 BGM 재생...")
    bgm_manager.play_stage_bgm(1)
    pygame.time.wait(1500)
    
    # 6. 볼륨 조절
    print("\n6. 볼륨 조절 테스트...")
    print("   볼륨 25%로 설정")
    bgm_manager.set_bgm_volume(0.25)
    pygame.time.wait(1000)
    
    print("   볼륨 75%로 설정")
    bgm_manager.set_bgm_volume(0.75)
    pygame.time.wait(1000)
    
    # 7. 메인 메뉴로 복귀
    print("\n7. 메인 메뉴로 복귀...")
    bgm_manager.bgm_manager.handle_return_to_menu()
    pygame.time.wait(1000)
    
    # 8. 최종 정지
    print("\n8. BGM 최종 정지...")
    bgm_manager.stop_bgm()
    
    print("\n" + "=" * 50)
    print("✅ 모든 테스트 완료!")
    print("=" * 50)

if __name__ == "__main__":
    test_bgm_module()
    pygame.quit()