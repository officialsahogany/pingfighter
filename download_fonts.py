#!/usr/bin/env python3
"""
한글 폰트 다운로드 스크립트
인기 있는 무료 한글 폰트들을 자동으로 다운로드합니다
"""

import os
import requests
import zipfile
from pathlib import Path

# 폰트 저장 디렉토리
FONTS_DIR = Path("fonts")
FONTS_DIR.mkdir(exist_ok=True)

# 다운로드할 폰트 목록
FONTS = {
    "프리텐다드": {
        "url": "https://github.com/orioncactus/pretendard/releases/download/v1.3.9/Pretendard-1.3.9.zip",
        "desc": "가장 인기 있는 깔끔한 한글 폰트"
    },
    "네오둥근모": {
        "url": "https://github.com/Dalgona/neodgm/releases/download/v1.530/neodgm_1.530.zip", 
        "desc": "현대적인 픽셀 게임 폰트"
    },
    "둥근모꼴": {
        "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_two@1.0/DungGeunMo.woff",
        "desc": "클래식 레트로 게임 폰트"
    }
}

def download_font(name, info):
    """폰트 다운로드 함수"""
    print(f"\n📥 {name} 다운로드 중...")
    print(f"   {info['desc']}")
    
    try:
        response = requests.get(info['url'], stream=True)
        response.raise_for_status()
        
        # 파일 확장자 결정
        if info['url'].endswith('.zip'):
            file_path = FONTS_DIR / f"{name}.zip"
            with open(file_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            
            # ZIP 파일 압축 해제
            with zipfile.ZipFile(file_path, 'r') as zip_ref:
                extract_dir = FONTS_DIR / name
                extract_dir.mkdir(exist_ok=True)
                zip_ref.extractall(extract_dir)
            
            # ZIP 파일 삭제
            file_path.unlink()
            print(f"   ✅ {name} 다운로드 및 압축 해제 완료!")
            
        else:
            # 단일 파일 다운로드
            ext = info['url'].split('.')[-1]
            file_path = FONTS_DIR / f"{name}.{ext}"
            with open(file_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            print(f"   ✅ {name} 다운로드 완료!")
            
    except Exception as e:
        print(f"   ❌ {name} 다운로드 실패: {e}")

def main():
    print("🎨 한글 폰트 다운로드 시작!")
    print("=" * 50)
    
    for name, info in FONTS.items():
        download_font(name, info)
    
    print("\n" + "=" * 50)
    print("✨ 폰트 다운로드 완료!")
    print(f"📁 폰트 위치: {FONTS_DIR.absolute()}")
    print("\n게임에 적용하려면:")
    print("1. fonts 폴더에서 원하는 .ttf 파일을 선택")
    print("2. 게임 폴더로 복사")
    print("3. 코드에서 폰트 파일명 변경")
    
    # 추가 추천 사이트
    print("\n🌐 더 많은 무료 폰트:")
    print("- 눈누: https://noonnu.cc")
    print("- 구글 폰트: https://fonts.google.com/?subset=korean")
    print("- 네이버 나눔폰트: https://hangeul.naver.com/font")

if __name__ == "__main__":
    main()