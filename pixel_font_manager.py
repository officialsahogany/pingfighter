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

# CJK 폰트 (일본어/중국어용)
# Pretendard는 한국어 전용이라 ja/zh는 시스템 폰트 사용
CJK_FONT_BOLD = resource_path("Pretendard-Bold.ttf")
CJK_FONT_REGULAR = resource_path("Pretendard-Regular.ttf")

# 일본어/중국어 시스템 폰트 목록 (SysFont 이름)
if sys.platform == "win32":
    _JA_SYSTEM_FONTS = ["Yu Gothic", "Meiryo", "MS Gothic", "MS PGothic"]
    _ZH_SYSTEM_FONTS = ["Microsoft YaHei", "SimHei", "SimSun", "FangSong"]
elif sys.platform == "darwin":
    _JA_SYSTEM_FONTS = ["Hiragino Sans", "Hiragino Kaku Gothic Pro"]
    _ZH_SYSTEM_FONTS = ["PingFang SC", "STHeiti", "Heiti SC"]
else:
    _JA_SYSTEM_FONTS = ["Noto Sans CJK JP", "TakaoGothic"]
    _ZH_SYSTEM_FONTS = ["Noto Sans CJK SC", "WenQuanYi Micro Hei"]

# CJK 시스템 폰트 파일 경로 (pygame.font.Font에서 직접 로드용)
_CJK_FONT_FILE_PATHS = {
    "ja": {
        "win32": [
            "C:/Windows/Fonts/YuGothM.ttc",
            "C:/Windows/Fonts/YuGothR.ttc",
            "C:/Windows/Fonts/meiryo.ttc",
            "C:/Windows/Fonts/msgothic.ttc",
        ],
        "darwin": [
            "/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc",
            "/Library/Fonts/Hiragino Sans GB W3.otf",
        ],
        "linux": ["/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"],
    },
    "zh": {
        "win32": [
            "C:/Windows/Fonts/msyh.ttc",
            "C:/Windows/Fonts/simhei.ttf",
            "C:/Windows/Fonts/simsun.ttc",
        ],
        "darwin": [
            "/System/Library/Fonts/PingFang.ttc",
            "/Library/Fonts/Arial Unicode.ttf",
        ],
        "linux": ["/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"],
    },
}

def _find_cjk_font_path(lang_code):
    """CJK 언어용 시스템 폰트 파일 경로 탐색"""
    platform = sys.platform
    if platform not in ("win32", "darwin"):
        platform = "linux"
    paths = _CJK_FONT_FILE_PATHS.get(lang_code, {}).get(platform, [])
    for p in paths:
        if os.path.exists(p):
            return p
    return None

# 픽셀 폰트 사용 여부 (항상 True)
USE_PIXEL_FONT = True

# 현재 폰트 언어 (ko/en은 픽셀폰트, ja/zh는 시스템 폰트)
_current_font_language = "ko"

def set_font_language(lang_code):
    """언어 변경 시 폰트 경로 교체 + 캐시 초기화

    ja/zh → CJK 시스템 폰트 파일로 PIXEL_FONT 등 전역 경로를 교체.
    이렇게 하면 게임 전체에서 pygame.font.Font(PIXEL_FONT, size) 로
    폰트를 생성하는 모든 코드가 자동으로 CJK 폰트를 사용하게 됨.
    """
    global _current_font_language, _font_cache
    global PIXEL_FONT, MAIN_FONT_BOLD, MAIN_FONT_REGULAR, MAIN_FONT_EXTRA_BOLD
    if lang_code != _current_font_language:
        _current_font_language = lang_code
        _font_cache.clear()  # 언어 변경 시 캐시 무효화
        # CJK 언어: 전역 폰트 경로를 시스템 CJK 폰트로 교체
        if lang_code in ("ja", "zh"):
            cjk_path = _find_cjk_font_path(lang_code)
            if cjk_path:
                PIXEL_FONT = cjk_path
                MAIN_FONT_BOLD = cjk_path
                MAIN_FONT_REGULAR = cjk_path
                MAIN_FONT_EXTRA_BOLD = cjk_path
        else:
            # ko/en: 원래 픽셀 폰트로 복원
            PIXEL_FONT = PIXEL_FONT_PATH
            MAIN_FONT_BOLD = PIXEL_FONT_PATH
            MAIN_FONT_REGULAR = PIXEL_FONT_PATH
            MAIN_FONT_EXTRA_BOLD = PIXEL_FONT_PATH

def get_font_language():
    return _current_font_language

def get_pixel_font_path():
    """현재 언어에 맞는 폰트 파일 경로 반환 (CJK 자동 전환)

    resource_path("PFStardust.ttf") 대신 사용하면
    ja/zh에서 자동으로 시스템 CJK 폰트 경로를 반환.
    """
    return PIXEL_FONT

def get_cjk_font(size, style="regular"):
    """CJK 문자 렌더링용 폰트 (언어 설정과 무관하게 항상 CJK 지원 폰트 반환)"""
    cache_key = ("_cjk_always", size, style)
    if cache_key in _font_cache:
        return _font_cache[cache_key]
    is_bold = (style == "bold")
    # 일본어 시스템 폰트 우선 (한자+가나+한글+중문 모두 지원하는 경우 많음)
    for font_name in _JA_SYSTEM_FONTS + _ZH_SYSTEM_FONTS:
        try:
            font = pygame.font.SysFont(font_name, size, bold=is_bold)
            _font_cache[cache_key] = font
            return font
        except Exception:
            continue
    # 폴백: Pretendard
    try:
        cjk_path = CJK_FONT_BOLD if is_bold else CJK_FONT_REGULAR
        font = pygame.font.Font(cjk_path, size)
        _font_cache[cache_key] = font
        return font
    except Exception:
        pass
    # 최종 폴백
    font = pygame.font.Font(None, size)
    _font_cache[cache_key] = font
    return font

# Windows 한글 폰트 폴백 (최후의 수단)
if sys.platform == "win32":
    WINDOWS_KOREAN_FONTS = ["맑은 고딕", "굴림", "돋움", "바탕"]
else:
    WINDOWS_KOREAN_FONTS = []


# 폰트 캐시 (성능 최적화)
_font_cache = {}

# 전체화면 스케일링 보정 비율 (rotozoom 축소로 인한 글자 번짐 방지)
# 비활성화됨 - 폰트 크기 변경 시 UI 레이아웃 문제 발생
_fullscreen_font_scale = 1.0

def set_fullscreen_font_scale(scale_factor):
    """전체화면 스케일링 비율 설정 - 현재 비활성화됨"""
    global _fullscreen_font_scale
    # 비활성화: 폰트 크기 변경 시 UI 요소들이 잘리는 문제 발생
    # rotozoom 화질로 유지
    _fullscreen_font_scale = 1.0

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

def get_font(size, style="regular", force_pixel=None, no_scale=False):
    """
    폰트 가져오기 (캐싱 지원)

    Args:
        size: 폰트 크기
        style: "bold", "regular", "small" 등 (픽셀 폰트는 모두 같은 폰트 사용)
        force_pixel: True면 픽셀 폰트 강제, False면 기본 폰트 강제, None이면 설정 따름
        no_scale: True면 전체화면 스케일 보정 안함 (REAL_SCREEN에 직접 그릴 때)
    """
    use_pixel = force_pixel if force_pixel is not None else USE_PIXEL_FONT

    # 전체화면 스케일 보정 적용 (축소로 인한 번짐 방지)
    if not no_scale and _fullscreen_font_scale > 1.0:
        size = int(size * _fullscreen_font_scale)

    # 일본어/중국어는 CJK 폰트(Pretendard) 사용 (픽셀폰트 미지원)
    is_cjk = _current_font_language in ("ja", "zh")

    # 캐시 키 생성 (언어별 분리)
    cache_key = (size, style, use_pixel, no_scale, _current_font_language)

    # 캐시에 있으면 반환
    if cache_key in _font_cache:
        return _font_cache[cache_key]

    # ja/zh → 시스템 폰트 사용 (PFStardust/Pretendard는 ja/zh 미지원)
    if is_cjk:
        sys_fonts = _JA_SYSTEM_FONTS if _current_font_language == "ja" else _ZH_SYSTEM_FONTS
        is_bold = (style == "bold")
        for font_name in sys_fonts:
            try:
                font = pygame.font.SysFont(font_name, size, bold=is_bold)
                _font_cache[cache_key] = font
                return font
            except Exception:
                continue
        # 시스템 폰트 실패 시 Pretendard 시도
        try:
            cjk_path = CJK_FONT_BOLD if is_bold else CJK_FONT_REGULAR
            font = pygame.font.Font(cjk_path, size)
            _font_cache[cache_key] = font
            return font
        except Exception as e:
            print(f"⚠️ CJK 폰트 로드 실패: {e}")

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
    """픽셀 폰트용 크기 조정 (rotozoom 스케일링 보정 포함)

    rotozoom 0.8x 스케일링 후 선명도 유지를 위해 폰트 크기를 약간 증가
    (기존 대비 +10% 정도로 레이아웃 영향 최소화)
    """
    size_map = {
        # 원본 크기: 픽셀 폰트 크기 (rotozoom 보정 적용)
        9: 10,
        12: 13,
        14: 15,
        16: 17,
        18: 19,
        20: 21,
        24: 25,
        26: 27,
        28: 29,
        32: 33,
        36: 37,
        40: 41,
        48: 50,
        64: 66,
        72: 74,
        140: 130,  # 점수 표시용 특별 조정
    }

    # 매핑에 없으면 크기 조정
    if size in size_map:
        return size_map[size]
    else:
        # 기본적으로 원본 크기 유지 + 약간 증가 (rotozoom 보정)
        return int(size * 1.05)

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
