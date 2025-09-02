"""
폰트 설정 파일
레트로 픽셀 폰트와 일반 폰트를 쉽게 전환
"""

import pygame
import os
import sys

# 리소스 경로 헬퍼 (PyInstaller 호환)
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)


# 폰트 스타일 선택 (pixel, modern, classic)
FONT_STYLE = "pixel"  # 레트로 픽셀 스타일!

# 폰트 파일 경로
FONTS = {
    "pixel": {
        "bold": "NeoDunggeunmoPro.ttf",  # 네오둥근모 (픽셀)
        "regular": "NeoDunggeunmoPro.ttf",  # 같은 폰트 사용
        "name": "네오둥근모 (레트로 픽셀)"
    },
    "modern": {
        "bold": "Pretendard-Bold.ttf",  # 프리텐다드 (모던)
        "regular": "Pretendard-Regular.ttf",
        "name": "프리텐다드 (깔끔한 현대적)"
    },
    "classic": {
        "bold": "NanumSquareB.ttf",  # 나눔스퀘어 (기존)
        "regular": "NanumSquareR.ttf",
        "name": "나눔스퀘어 (클래식)"
    }
}

def get_font_path(weight="regular"):
    """현재 스타일의 폰트 경로 반환"""
    style = FONTS.get(FONT_STYLE, FONTS["classic"])
    font_file = style.get(weight, style["regular"])
    
    # 파일 존재 확인
    if not os.path.exists(font_file):
        print(f"⚠️ 폰트 파일 '{font_file}'을 찾을 수 없습니다.")
        # 폴백: 나눔스퀘어
        if weight == "bold":
            return "NanumSquareB.ttf"
        return "NanumSquareR.ttf"
    
    return font_file

def load_font(size, weight="regular"):
    """폰트 로드 헬퍼 함수"""
    font_path = get_font_path(weight)
    try:
        return pygame.font.Font(font_path, size)
    except:
        # 폴백: 기본 폰트
        print(f"⚠️ 폰트 로드 실패, 기본 폰트 사용")
        return pygame.font.Font(None, size)

def get_font_info():
    """현재 폰트 정보 반환"""
    style = FONTS.get(FONT_STYLE, FONTS["classic"])
    return style["name"]

# 픽셀 폰트용 크기 조정 (픽셀 폰트는 작게 표시되므로 크기 증가)
def adjust_size_for_pixel(size):
    """픽셀 폰트일 때 크기 자동 조정"""
    if FONT_STYLE == "pixel":
        # 픽셀 폰트는 20% 크게
        return int(size * 1.2)
    return size

# 사용 예시:
# from font_config import load_font, adjust_size_for_pixel
# 
# # 기존 코드:
# font = pygame.font.Font(resource_path("NanumSquareB.ttf"), 40)
# 
# # 새로운 코드:
# font = load_font(adjust_size_for_pixel(40), "bold")

print(f"🎮 폰트 스타일: {get_font_info()}")
print(f"📁 Bold: {get_font_path('bold')}")
print(f"📁 Regular: {get_font_path('regular')}")