#!/usr/bin/env python3
"""
레트로 픽셀 한글 폰트 다운로드
게임에 딱 맞는 도트 폰트들!
"""

import os
import requests
import zipfile
from pathlib import Path

# 폰트 저장 디렉토리
FONTS_DIR = Path("fonts/pixel")
FONTS_DIR.mkdir(parents=True, exist_ok=True)

# 레트로 픽셀 폰트 목록
PIXEL_FONTS = {
    "둥근모꼴": {
        "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_eight@1.0/DOSGothic.woff",
        "desc": "🕹️ 클래식 DOS 스타일 - 정통 레트로 게임 느낌"
    },
    "네오둥근모": {
        "url": "https://github.com/neodgm/neodgm/releases/download/v1.521/neodgm.ttf",
        "desc": "✨ 현대적 픽셀폰트 - 둥근모꼴의 업그레이드 버전"
    },
    "던파비트비트": {
        "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_2001@1.3/DNFBitBitv2.woff",
        "desc": "⚔️ 던전앤파이터 스타일 - RPG 게임 느낌"
    },
    "픽셀리피": {
        "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_2001@1.1/PixelSagas.woff",
        "desc": "🎮 아케이드 스타일 - 오락실 게임 느낌"
    },
    "DungGeunMo": {
        "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_six@1.2/DungGeunMo.woff",
        "desc": "💾 둥근모꼴 원본 - 90년대 PC통신 스타일"
    },
    "Sam3KRFont": {
        "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_2105_2@1.0/Sam3KRFont.woff",
        "desc": "🏛️ 삼국지 스타일 - 고전 게임 느낌"
    }
}

def download_pixel_font(name, info):
    """픽셀 폰트 다운로드"""
    print(f"\n{info['desc']}")
    print(f"📥 {name} 다운로드 중...")
    
    try:
        response = requests.get(info['url'], headers={
            'User-Agent': 'Mozilla/5.0',
            'Accept': '*/*',
            'Accept-Encoding': 'gzip, deflate, br'
        })
        response.raise_for_status()
        
        # 파일 확장자 결정
        if '.ttf' in info['url']:
            ext = 'ttf'
        elif '.otf' in info['url']:
            ext = 'otf'
        else:
            ext = 'woff'  # 기본값
        
        file_path = FONTS_DIR / f"{name}.{ext}"
        with open(file_path, 'wb') as f:
            f.write(response.content)
        
        print(f"   ✅ {name} 다운로드 완료! ({ext.upper()} 형식)")
        
        # WOFF를 TTF로 변환하는 안내
        if ext == 'woff':
            print(f"   ℹ️ WOFF 파일은 웹폰트 형식입니다.")
            print(f"   💡 TTF 변환이 필요하면 convertio.co/kr/woff-ttf/ 사용")
        
        return True
        
    except Exception as e:
        print(f"   ❌ {name} 다운로드 실패: {e}")
        return False

def download_additional_pixel_fonts():
    """추가 픽셀 폰트 직접 다운로드"""
    print("\n🎯 특별 추천: 네오둥근모 프로 다운로드 시도...")
    
    # 네오둥근모 프로 (가장 인기있는 픽셀 폰트)
    try:
        url = "https://github.com/neodgm/neodgm/releases/download/v1.521/neodgm.ttf"
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'})
        
        if response.status_code == 200:
            file_path = FONTS_DIR / "NeoDunggeunmoPro.ttf"
            with open(file_path, 'wb') as f:
                f.write(response.content)
            print("   ✅ 네오둥근모 프로 다운로드 성공! (가장 추천!)")
            return True
    except:
        pass
    
    return False

def main():
    print("=" * 60)
    print("🕹️ 레트로 픽셀 한글 폰트 다운로드")
    print("=" * 60)
    
    success_count = 0
    
    # 메인 폰트들 다운로드
    for name, info in PIXEL_FONTS.items():
        if download_pixel_font(name, info):
            success_count += 1
    
    # 추가 폰트 다운로드
    if download_additional_pixel_fonts():
        success_count += 1
    
    print("\n" + "=" * 60)
    print(f"✨ {success_count}개 픽셀 폰트 다운로드 완료!")
    print(f"📁 폰트 위치: {FONTS_DIR.absolute()}")
    
    print("\n🎮 게임에 적용하는 방법:")
    print("1. fonts/pixel 폴더에서 .ttf 파일 선택")
    print("2. 게임 폴더로 복사: cp fonts/pixel/*.ttf .")
    print("3. 코드에서 폰트 변경:")
    print('   font = pygame.font.Font("NeoDunggeunmoPro.ttf", 24)')
    
    print("\n💎 레트로 게임별 추천 조합:")
    print("🏃 액션게임: 던파비트비트 + 네온 색상")
    print("🗡️ RPG게임: 둥근모꼴 + 어두운 배경")
    print("🎮 아케이드: 픽셀리피 + 밝은 색상")
    print("💻 해킹게임: 네오둥근모 + 녹색 텍스트")
    
    print("\n🌐 더 많은 픽셀 폰트:")
    print("👉 눈누: https://noonnu.cc/index?set=pixel")
    print("👉 도트 폰트 전문: https://www.dafont.com/bitmap.php")

if __name__ == "__main__":
    main()