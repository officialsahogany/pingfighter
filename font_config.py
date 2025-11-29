"""
폰트 설정 파일
네오둥근모 프로 도트 폰트 전역 설정
맥/윈도우 모두 호환, 한글 완벽 지원
"""

import pygame
import os
import sys

# 리소스 경로 헬퍼 (PyInstaller 호환)
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    # 크로스 플랫폼 경로 구분자
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)


# 폰트 스타일 선택 (pixel, modern, classic)
FONT_STYLE = "pixel"  # 레트로 픽셀 스타일!

# 픽셀 폰트 경로 (PF스타더스트 3.0 - 가독성 좋은 레트로 픽셀 폰트)
PIXEL_FONT_FILE = resource_path("PFStardust.ttf")

# 폰트 파일 경로
FONTS = {
    "pixel": {
        "bold": PIXEL_FONT_FILE,
        "regular": PIXEL_FONT_FILE,
        "name": "PF스타더스트 3.0 (도트 픽셀)"
    },
    "modern": {
        "bold": resource_path(os.path.join("fonts", "프리텐다드", "public", "static", "alternative", "Pretendard-Bold.ttf")),
        "regular": resource_path(os.path.join("fonts", "프리텐다드", "public", "static", "alternative", "Pretendard-Regular.ttf")),
        "name": "프리텐다드 (모던)"
    },
    "classic": {
        "bold": resource_path("NanumSquareB.ttf"),
        "regular": resource_path("NanumSquareR.ttf"),
        "name": "나눔스퀘어 (클래식)"
    }
}

def get_font_path(weight="regular"):
    """현재 스타일의 폰트 경로 반환"""
    style = FONTS.get(FONT_STYLE, FONTS["classic"])
    font_path = style.get(weight, style["regular"])

    # 파일 존재 확인
    if os.path.exists(font_path):
        return font_path

    print(f"⚠️ 폰트 파일을 찾을 수 없음: {font_path}")

    # 폴백: 나눔스퀘어
    fallback = resource_path("NanumSquareB.ttf" if weight == "bold" else "NanumSquareR.ttf")
    if os.path.exists(fallback):
        return fallback

    return None

def load_font(size, weight="regular"):
    """폰트 로드 헬퍼 함수"""
    font_path = get_font_path(weight)

    # 픽셀 폰트면 크기 조정
    adjusted_size = adjust_size_for_pixel(size)

    try:
        if font_path:
            return pygame.font.Font(font_path, adjusted_size)
    except Exception as e:
        print(f"⚠️ 폰트 로드 실패: {e}")

    # 폴백: 시스템 폰트
    if sys.platform == "win32":
        try:
            return pygame.font.SysFont("맑은 고딕", adjusted_size)
        except:
            pass
    elif sys.platform == "darwin":
        try:
            return pygame.font.SysFont("AppleGothic", adjusted_size)
        except:
            pass

    # 최종 폴백: pygame 기본 폰트
    return pygame.font.Font(None, adjusted_size)

def get_font_info():
    """현재 폰트 정보 반환"""
    style = FONTS.get(FONT_STYLE, FONTS["classic"])
    return style["name"]

# 픽셀 폰트용 크기 조정
def adjust_size_for_pixel(size):
    """픽셀 폰트일 때 크기 자동 조정 (도트 폰트는 약간 키움)"""
    if FONT_STYLE == "pixel":
        return int(size * 1.1)  # 10% 크게
    return size

# 상태 출력
_font_path = get_font_path('bold')
if _font_path and os.path.exists(_font_path):
    print(f"🎮 폰트 스타일: {get_font_info()}")
    print(f"📁 경로: {os.path.basename(_font_path)}")
else:
    print(f"⚠️ 폰트 파일을 찾을 수 없음")