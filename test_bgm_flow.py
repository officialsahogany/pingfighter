#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""BGM 흐름 테스트 스크립트"""

import pygame
import os
import sys

def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

def test_bgm_flow():
    """BGM 재생 흐름 테스트"""
    pygame.init()
    pygame.mixer.init()
    
    bgm_path = resource_path(os.path.join("bgm", "introbgm.mp3"))
    
    print("=" * 50)
    print("BGM 흐름 테스트")
    print("=" * 50)
    
    # 1. 오프닝에서 BGM 시작 (시뮬레이션)
    print("\n1. 오프닝 애니메이션 시작...")
    if os.path.exists(bgm_path):
        pygame.mixer.music.load(bgm_path)
        pygame.mixer.music.set_volume(0.5)
        pygame.mixer.music.play(-1)
        print("   ✅ BGM 재생 시작")
    
    pygame.time.wait(1000)
    
    # 2. 메인 메뉴로 전환 시 체크
    print("\n2. 메인 메뉴로 전환...")
    if pygame.mixer.music.get_busy():
        print("   ✅ BGM이 이미 재생 중 - 재로드하지 않음")
        print("   ✅ BGM이 끊기지 않고 계속 재생됨")
    else:
        print("   ⚠️ BGM이 재생 중이 아님 - 재로드 필요")
        pygame.mixer.music.load(bgm_path)
        pygame.mixer.music.play(-1)
    
    pygame.time.wait(1000)
    
    # 3. 게임 시작 시 정지
    print("\n3. 게임 시작...")
    pygame.mixer.music.stop()
    print("   ✅ BGM 정지")
    
    print("\n" + "=" * 50)
    print("테스트 완료!")
    print("=" * 50)

if __name__ == "__main__":
    test_bgm_flow()
    pygame.quit()