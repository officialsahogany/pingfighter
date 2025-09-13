#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Stage 1 BGM 테스트 스크립트"""

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

def test_stage1_bgm():
    """Stage 1 BGM 테스트"""
    pygame.init()
    pygame.mixer.init()
    
    menu_bgm_path = resource_path(os.path.join("bgm", "introbgm.mp3"))
    stage1_bgm_path = resource_path(os.path.join("bgm", "stage1bgm.mp3"))
    
    print("=" * 50)
    print("Stage 1 BGM 테스트")
    print("=" * 50)
    
    # 1. 메인 메뉴 BGM 재생
    print("\n1. 메인 메뉴 BGM 재생...")
    if os.path.exists(menu_bgm_path):
        pygame.mixer.music.load(menu_bgm_path)
        pygame.mixer.music.set_volume(0.5)
        pygame.mixer.music.play(-1)
        print("   ✅ 메인 메뉴 BGM 재생 시작")
    
    pygame.time.wait(1000)
    
    # 2. 게임 시작 시 메뉴 BGM 정지
    print("\n2. 게임 시작 (Stage 1)...")
    pygame.mixer.music.stop()
    print("   ✅ 메인 메뉴 BGM 정지")
    
    # 3. Stage 1 BGM 재생
    print("\n3. Stage 1 BGM 로드 및 재생...")
    if os.path.exists(stage1_bgm_path):
        try:
            pygame.mixer.music.load(stage1_bgm_path)
            pygame.mixer.music.set_volume(0.5)
            pygame.mixer.music.play(-1)
            print("   ✅ Stage 1 BGM 재생 시작")
            print(f"   ✅ 파일: {stage1_bgm_path}")
        except Exception as e:
            print(f"   ❌ Stage 1 BGM 로드 실패: {e}")
    else:
        print(f"   ❌ Stage 1 BGM 파일을 찾을 수 없음: {stage1_bgm_path}")
    
    pygame.time.wait(2000)
    
    # 4. 메인 메뉴로 복귀
    print("\n4. 메인 메뉴로 복귀...")
    pygame.mixer.music.stop()
    print("   ✅ Stage 1 BGM 정지")
    
    # 메뉴 BGM 다시 재생 (이미 재생 중이 아닌 경우)
    if not pygame.mixer.music.get_busy():
        pygame.mixer.music.load(menu_bgm_path)
        pygame.mixer.music.set_volume(0.5)
        pygame.mixer.music.play(-1)
        print("   ✅ 메인 메뉴 BGM 다시 재생")
    
    print("\n" + "=" * 50)
    print("테스트 완료!")
    print("=" * 50)

if __name__ == "__main__":
    test_stage1_bgm()
    pygame.quit()