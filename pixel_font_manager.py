# -*- coding: utf-8 -*-
"""
🎮 픽셀 폰트 매니저
네오둥근모 프로 레트로 픽셀 폰트를 전체 게임에 적용
한글/영문 모두 완벽 지원, 맥/윈도우 호환
"""

import pygame
import os
import sys

def resource_path(relative_path):
    """PyInstaller 번들과 일반 실행 모두에서 작동하는 리소스 경로 반환"""
    try:
        # PyInstaller 번들인 경우
        base_path = sys._MEIPASS
    except Exception:
        # 일반 Python 실행인 경우
        base_path = os.path.dirname(os.path.abspath(__file__))

    # 경로 구분자 통일 (크로스 플랫폼)
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

# ============================================
# 🎮 네오둥근모 프로 - 메인 픽셀 폰트
# 한글 완벽 지원, 맥/윈도우 호환, OFL 라이선스
# ============================================

# 픽셀 폰트 경로 (PF스타더스트 3.0 - 가독성 좋은 레트로 픽셀 폰트)
PIXEL_FONT_PATH = resource_path("PFStardust.ttf")

# 메인 폰트 = 픽셀 폰트 (네오둥근모 프로)
MAIN_FONT_EXTRA_BOLD = PIXEL_FONT_PATH
MAIN_FONT_BOLD = PIXEL_FONT_PATH
MAIN_FONT_REGULAR = PIXEL_FONT_PATH

# 픽셀 폰트 경로 설정
PIXEL_FONT = PIXEL_FONT_PATH

# 폴백 폰트 (픽셀 폰트 없을 때만 사용)
_fallback_nanum_bold = resource_path("NanumSquareB.ttf")
_fallback_nanum_regular = resource_path("NanumSquareR.ttf")

# 픽셀 폰트 존재 확인
if not os.path.exists(PIXEL_FONT_PATH):
    print(f"⚠️ 픽셀 폰트를 찾을 수 없음: {PIXEL_FONT_PATH}")
    print("   → NanumSquare 폴백 사용")
    MAIN_FONT_EXTRA_BOLD = _fallback_nanum_bold
    MAIN_FONT_BOLD = _fallback_nanum_bold
    MAIN_FONT_REGULAR = _fallback_nanum_regular
    PIXEL_FONT = _fallback_nanum_bold

# 폴백 폰트 (호환성 유지)
FALLBACK_FONT_BOLD = _fallback_nanum_bold
FALLBACK_FONT_REGULAR = _fallback_nanum_regular

# 픽셀 폰트 사용 여부 (항상 True)
USE_PIXEL_FONT = True

# Windows 한글 폰트 폴백 (최후의 수단)
if sys.platform == "win32":
    WINDOWS_KOREAN_FONTS = ["맑은 고딕", "굴림", "돋움", "바탕"]
else:
    WINDOWS_KOREAN_FONTS = []


# 폰트 캐시 (성능 최적화)
_font_cache = {}

# PixelColors 클래스 추가
class PixelColors:
    """픽셀 게임용 색상 팔레트"""
    # 기본 색상
    WHITE = (255, 255, 255)
    BLACK = (0, 0, 0)
    RED = (255, 0, 0)
    GREEN = (0, 255, 0)
    BLUE = (0, 0, 255)
    YELLOW = (255, 255, 0)
    CYAN = (0, 255, 255)
    MAGENTA = (255, 0, 255)
    
    # 게임 특화 색상
    HEALTH_RED = (220, 20, 60)
    MANA_BLUE = (65, 105, 225)
    GOLD_YELLOW = (255, 215, 0)
    SILVER_GRAY = (192, 192, 192)
    
    # 네온 색상 (사이버펑크 스타일)
    NEON_PINK = (255, 20, 147)
    NEON_GREEN = (57, 255, 20)
    NEON_BLUE = (77, 77, 255)
    NEON_PURPLE = (148, 0, 211)

# FontStyle 클래스 추가
class FontStyle:
    """폰트 스타일 유틸리티 클래스"""
    
    @staticmethod
    def title():
        """타이틀용 큰 폰트 (48pt)"""
        return get_font(48, style="bold")
    
    @staticmethod
    def menu():
        """메뉴용 중간 폰트 (28pt)"""
        return get_font(28, style="regular")
    
    @staticmethod
    def body():
        """본문용 작은 폰트 (24pt)"""
        return get_font(24, style="regular")
    
    @staticmethod
    def small():
        """작은 폰트 (18pt)"""
        return get_font(18, style="regular")
    
    @staticmethod
    def large():
        """큰 폰트 (36pt)"""
        return get_font(36, style="bold")
    
    @staticmethod
    def title_large():
        """매우 큰 타이틀 폰트 (72pt)"""
        return get_font(72, style="bold")
    
    @staticmethod
    def giant():
        """거대한 폰트 (140pt)"""
        return get_font(140, style="bold")
    
    @staticmethod
    def tiny():
        """아주 작은 폰트 (12pt)"""
        return get_font(12, style="regular")
    
    @staticmethod
    def subtitle():
        """부제목 폰트 (20pt)"""
        return get_font(20, style="regular")
    
    @staticmethod
    def gauge():
        """게이지용 폰트 (16pt)"""
        return get_font(16, style="regular")

    @staticmethod
    def body_small():
        """본문 소형 폰트 (16pt, UI 라벨용)"""
        return get_font(16, style="regular")
    
    @staticmethod
    def item_name():
        """아이템 이름 폰트 (22pt)"""
        return get_font(22, style="bold")
    
    @staticmethod
    def item_obtain():
        """아이템 획득 메시지 폰트 (26pt)"""
        return get_font(26, style="bold")

def get_font(size, style="regular", force_pixel=None):
    """
    폰트 가져오기 (캐싱 지원)

    Args:
        size: 폰트 크기
        style: "bold", "regular", "small" 등 (픽셀 폰트는 모두 같은 폰트 사용)
        force_pixel: True면 픽셀 폰트 강제, False면 기본 폰트 강제, None이면 설정 따름
    """
    use_pixel = force_pixel if force_pixel is not None else USE_PIXEL_FONT

    # 캐시 키 생성
    cache_key = (size, style, use_pixel)

    # 캐시에 있으면 반환
    if cache_key in _font_cache:
        return _font_cache[cache_key]

    # 픽셀 폰트 크기 조정
    adjusted_size = adjust_pixel_size(size) if use_pixel else size

    # 네오둥근모 프로 픽셀 폰트 사용
    try:
        font = pygame.font.Font(PIXEL_FONT, adjusted_size)
        _font_cache[cache_key] = font
        return font
    except Exception as e:
        print(f"⚠️ 픽셀 폰트 로드 실패: {e}")

        # 폴백 1: NanumSquare
        try:
            if style == "bold":
                font = pygame.font.Font(FALLBACK_FONT_BOLD, adjusted_size)
            else:
                font = pygame.font.Font(FALLBACK_FONT_REGULAR, adjusted_size)
            _font_cache[cache_key] = font
            return font
        except:
            pass

        # 폴백 2: Windows 시스템 폰트
        if sys.platform == "win32":
            for font_name in WINDOWS_KOREAN_FONTS:
                try:
                    font = pygame.font.SysFont(font_name, adjusted_size)
                    _font_cache[cache_key] = font
                    return font
                except:
                    continue

        # 폴백 3: macOS 시스템 폰트
        if sys.platform == "darwin":
            try:
                font = pygame.font.SysFont("AppleGothic", adjusted_size)
                _font_cache[cache_key] = font
                return font
            except:
                pass

        # 최종 폴백: pygame 기본 폰트
        font = pygame.font.Font(None, adjusted_size)
        _font_cache[cache_key] = font
        return font

def adjust_pixel_size(size):
    """픽셀 폰트용 크기 조정 (크기 감소 - 더 작고 얇게)"""
    size_map = {
        # 원본 크기: 픽셀 폰트 크기 (기존보다 20-30% 작게)
        9: 9,
        12: 11,
        14: 13,
        16: 15,
        18: 17,
        20: 19,
        24: 22,
        26: 24,
        28: 26,
        32: 29,
        36: 32,
        40: 36,
        48: 42,
        64: 56,
        72: 64,
        140: 110,  # 점수 표시용 특별 조정
    }
    
    # 매핑에 없으면 크기 조정
    if size in size_map:
        return size_map[size]
    else:
        # 기본적으로 15% 감소
        return int(size * 0.85)

def set_pixel_font_enabled(enabled):
    """픽셀 폰트 사용 여부 설정"""
    global USE_PIXEL_FONT
    USE_PIXEL_FONT = enabled
    _font_cache.clear()  # 캐시 클리어
    
    if enabled:
        print("!")
    else:
        print("!")

def clear_font_cache():
    """폰트 캐시 클리어"""
    _font_cache.clear()

# 기본 폰트 상태 확인
def check_font_status():
    """폰트 상태 확인 (디버깅용)"""
    try:
        print("[Font] Font status:")
        if os.path.exists(PIXEL_FONT):
            print(f"  [OK] Pixel font: {os.path.basename(PIXEL_FONT)}")
        else:
            print(f"  [X] Pixel font missing: {PIXEL_FONT}")

        if os.path.exists(FALLBACK_FONT_BOLD):
            print(f"  [OK] Fallback Bold: {os.path.basename(FALLBACK_FONT_BOLD)}")
        else:
            print(f"  [X] Fallback Bold missing")

        if os.path.exists(FALLBACK_FONT_REGULAR):
            print(f"  [OK] Fallback Regular: {os.path.basename(FALLBACK_FONT_REGULAR)}")
        else:
            print(f"  [X] Fallback Regular missing")
    except UnicodeEncodeError:
        pass  # Skip on encoding issues

# 프로그램 시작 시 상태 체크
check_font_status()

# 픽셀 폰트 가용 여부 확인
try:
    if os.path.exists(PIXEL_FONT):
        print(f"[Font] Dot font enabled: {os.path.basename(PIXEL_FONT).replace('.ttf', '')}")
    else:
        print("[Font] Dot font missing, using fallback")
except UnicodeEncodeError:
    pass
