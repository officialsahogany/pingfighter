#!/usr/bin/env python3
"""
pixel_font_manager.py 파일의 리소스 경로를 수정하는 스크립트
"""

import os

# 수정된 pixel_font_manager.py 내용
FIXED_CONTENT = '''"""
🎮 픽셀 폰트 매니저
네오둥근모 레트로 픽셀 폰트를 중앙에서 관리
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
    
    return os.path.join(base_path, relative_path)

# 폰트 파일 경로
# PF스타더스트 폰트 (TTF 파일이 있을 경우)
# 없으면 둥근모꼴 사용
if os.path.exists(resource_path("PFStardust.ttf")):
    PIXEL_FONT = resource_path("PFStardust.ttf")
    print("🌟 PF스타더스트 3.0 S 폰트 활성화!")
elif os.path.exists(resource_path("둥근모꼴.ttf")):
    PIXEL_FONT = resource_path("둥근모꼴.ttf")
    print("🎮 둥근모꼴 픽셀 폰트 활성화!")
elif os.path.exists(resource_path("NeoDGM.ttf")):
    PIXEL_FONT = resource_path("NeoDGM.ttf")
    print("🎮 네오둥근모 픽셀 폰트 활성화!")
else:
    PIXEL_FONT = resource_path("NeoDunggeunmoPro.ttf")
    print("🎮 네오둥근모 프로 폰트 활성화!")
    
FALLBACK_FONT_BOLD = resource_path("NanumSquareB.ttf")
FALLBACK_FONT_REGULAR = resource_path("NanumSquareR.ttf")

# 픽셀 폰트 사용 여부
USE_PIXEL_FONT = True

# 폰트 캐시 (성능 최적화)
_font_cache = {}

def get_font(size, style="regular", force_pixel=None):
    """
    폰트 가져오기 (캐싱 지원)
    
    Args:
        size: 폰트 크기
        style: "bold", "regular", "small" 등
        force_pixel: True면 픽셀 폰트 강제, False면 기본 폰트 강제, None이면 설정 따름
    """
    use_pixel = force_pixel if force_pixel is not None else USE_PIXEL_FONT
    
    # 캐시 키 생성
    cache_key = (size, style, use_pixel)
    
    # 캐시에 있으면 반환
    if cache_key in _font_cache:
        return _font_cache[cache_key]
    
    # 픽셀 폰트 사용
    if use_pixel:
        # 픽셀 폰트는 크기를 약간 늘려줘야 함
        adjusted_size = adjust_pixel_size(size)
        try:
            font = pygame.font.Font(PIXEL_FONT, adjusted_size)
            _font_cache[cache_key] = font
            return font
        except:
            print(f"⚠️ 픽셀 폰트 로드 실패, 폴백 사용")
    
    # 폴백 폰트 사용
    if style == "bold":
        font_file = FALLBACK_FONT_BOLD
    else:
        font_file = FALLBACK_FONT_REGULAR
    
    try:
        font = pygame.font.Font(font_file, size)
    except:
        # 최종 폴백: 시스템 기본 폰트
        font = pygame.font.Font(None, size)
    
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
        print("🎮 픽셀 폰트 시스템 활성화!")
    else:
        print("📝 기본 폰트 시스템 활성화!")

def clear_font_cache():
    """폰트 캐시 클리어"""
    _font_cache.clear()

# 기본 폰트 상태 확인
def check_font_status():
    """폰트 상태 확인 (디버깅용)"""
    print("📋 폰트 상태:")
    if os.path.exists(PIXEL_FONT):
        print(f"  ✅ 픽셀 폰트 ({os.path.basename(PIXEL_FONT)})")
    else:
        print(f"  ❌ 픽셀 폰트 ({os.path.basename(PIXEL_FONT)})")
    
    if os.path.exists(FALLBACK_FONT_BOLD):
        print(f"  ✅ 폴백 Bold")
    else:
        print(f"  ❌ 폴백 Bold")
        
    if os.path.exists(FALLBACK_FONT_REGULAR):
        print(f"  ✅ 폴백 Regular")
    else:
        print(f"  ❌ 폴백 Regular")

# 프로그램 시작 시 상태 체크
check_font_status()

# 픽셀 폰트 가용 여부 확인
if os.path.exists(PIXEL_FONT):
    print(f"🎮 {os.path.basename(PIXEL_FONT).replace('.ttf', '')} 픽셀 폰트 사용 가능!")
else:
    print("⚠️ 픽셀 폰트 없음, 기본 폰트 사용")
'''

def main():
    """메인 함수"""
    print("=" * 50)
    print("🔧 pixel_font_manager.py 리소스 경로 수정")
    print("=" * 50)
    
    file_path = '/Users/pika/Desktop/game/bosspong/pixel_font_manager.py'
    
    # 백업 생성
    backup_path = file_path + '.backup_font'
    with open(file_path, 'r', encoding='utf-8') as f:
        original_content = f.read()
    with open(backup_path, 'w', encoding='utf-8') as f:
        f.write(original_content)
    print(f"✅ 백업 파일 생성: {backup_path}")
    
    # 수정된 내용 저장
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(FIXED_CONTENT)
    
    print(f"✅ 파일 수정 완료: {file_path}")
    print("\n📌 다음 단계:")
    print("1. python3 pingfighter.py로 테스트")
    print("2. pyinstaller로 다시 빌드")
    print("3. 실행 파일 테스트")

if __name__ == "__main__":
    main()