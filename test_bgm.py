#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""BGM 로딩 테스트 스크립트"""

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

def test_bgm():
    """BGM 파일 로딩 및 재생 테스트"""
    pygame.init()
    pygame.mixer.init()
    
    bgm_path = resource_path(os.path.join("bgm", "introbgm.mp3"))
    
    print(f"BGM 경로: {bgm_path}")
    print(f"파일 존재 여부: {os.path.exists(bgm_path)}")
    
    if os.path.exists(bgm_path):
        try:
            pygame.mixer.music.load(bgm_path)
            pygame.mixer.music.set_volume(0.5)
            print("✅ BGM 로드 성공!")
            
            # 짧은 재생 테스트
            pygame.mixer.music.play(-1)
            print("✅ BGM 재생 시작 (무한 루프)")
            
            # 1초 대기 후 정지
            pygame.time.wait(1000)
            pygame.mixer.music.stop()
            print("✅ BGM 정지 완료")
            
            return True
        except Exception as e:
            print(f"❌ BGM 로드 실패: {e}")
            return False
    else:
        print("❌ BGM 파일을 찾을 수 없음")
        return False

if __name__ == "__main__":
    if test_bgm():
        print("\n🎵 BGM 시스템이 정상적으로 작동합니다!")
    else:
        print("\n⚠️ BGM 시스템에 문제가 있습니다.")
    
    pygame.quit()