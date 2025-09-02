"""
BossPong Test Suite
테스트 스위트 초기화
"""

import sys
import os

# 프로젝트 루트를 Python 경로에 추가
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

# 테스트 환경 설정
os.environ['SDL_VIDEODRIVER'] = 'dummy'  # Pygame을 헤드리스 모드로 실행
os.environ['SDL_AUDIODRIVER'] = 'dummy'  # 오디오도 더미 드라이버 사용

# Pygame 초기화 (테스트용)
import pygame
pygame.init()

print("🧪 BossPong 테스트 스위트 초기화 완료")