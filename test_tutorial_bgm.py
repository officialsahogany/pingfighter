#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""튜토리얼 BGM 테스트 스크립트"""

import pygame
import bgm_manager
import os
import sys

def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

def test_tutorial_bgm():
    """튜토리얼 BGM 테스트"""
    pygame.init()
    
    print("=" * 50)
    print("튜토리얼 BGM 테스트")
    print("=" * 50)
    
    # BGM 파일 확인
    tutorial_bgm_path = resource_path(os.path.join("bgm", "tutorialbgm.mp3"))
    print(f"\n튜토리얼 BGM 경로: {tutorial_bgm_path}")
    print(f"파일 존재 여부: {os.path.exists(tutorial_bgm_path)}")
    
    # 1. BGM 매니저 초기화
    print("\n1. BGM 매니저 초기화...")
    bgm_manager.bgm_manager.initialize()
    
    # 2. 메뉴 BGM 재생
    print("\n2. 메인 메뉴 BGM 재생...")
    bgm_manager.play_menu_bgm()
    pygame.time.wait(1000)
    
    # 3. 튜토리얼 시작 (Stage 50)
    print("\n3. 튜토리얼 시작 (Stage 50)...")
    bgm_manager.stop_bgm()  # 메뉴 BGM 정지
    bgm_manager.play_stage_bgm(50)  # 튜토리얼 BGM 재생
    
    # BGM 재생 확인
    if bgm_manager.bgm_manager.is_playing():
        print("   ✅ 튜토리얼 BGM 재생 중")
        print(f"   현재 재생 중인 BGM: {bgm_manager.bgm_manager.current_bgm}")
    else:
        print("   ❌ BGM이 재생되지 않음")
    
    pygame.time.wait(2000)
    
    # 4. 튜토리얼 종료 후 메인 메뉴로
    print("\n4. 튜토리얼 종료 - 메인 메뉴로 복귀...")
    bgm_manager.stop_bgm()
    bgm_manager.play_menu_bgm()
    pygame.time.wait(1000)
    
    # 5. 최종 정지
    print("\n5. BGM 최종 정지...")
    bgm_manager.stop_bgm()
    
    print("\n" + "=" * 50)
    print("✅ 튜토리얼 BGM 테스트 완료!")
    print("=" * 50)

if __name__ == "__main__":
    test_tutorial_bgm()
    pygame.quit()