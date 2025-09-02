#!/usr/bin/env python3
"""
추가 인기 한글 폰트 다운로드 스크립트
게임에 잘 어울리는 예쁜 한글 폰트들
"""

import os
import requests
import zipfile
import tarfile
from pathlib import Path

# 폰트 저장 디렉토리
FONTS_DIR = Path("fonts")
FONTS_DIR.mkdir(exist_ok=True)

# 인기 한글 폰트 목록
FONTS = {
    "SUITE": {
        "url": "https://github.com/sunn-us/SUITE/releases/download/v1.0.0/SUITE-v1.0.0.zip",
        "desc": "깔끔하고 모던한 스타일, 가독성 최고"
    },
    "GmarketSans": {
        "url": "https://img1.daumcdn.net/thumb/R1280x0/?scode=mtistory2&fname=https%3A%2F%2Fcdn.jsdelivr.net%2Fgh%2Fprojectnoonnu%2Fnoonfonts_2001%2F1%2FGmarketSansTTFBold.ttf",
        "desc": "지마켓 산스 - 귀엽고 둥글둥글한 느낌",
        "direct": True
    },
    "PyeongChangPeace": {
        "url": "https://www.pyeongchang.go.kr/fonts/pyeongchangpeace/pyeongchangpeace.css",
        "desc": "평창 평화체 - 올림픽 공식 폰트, 깔끔하고 세련됨"
    },
    "DOSGothic": { 
        "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_eight@1.0/DOSGothic.woff",
        "desc": "도스 고딕 - 레트로 게임 스타일",
        "direct": True
    },
    "BMHANNAPro": {
        "url": "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_seven@1.0/BMHANNAPro.woff",
        "desc": "배민 한나체 Pro - 귀엽고 친근한 느낌",
        "direct": True
    }
}

def download_direct_font(name, url, desc):
    """직접 폰트 파일 다운로드"""
    print(f"\n📥 {name} 다운로드 중...")
    print(f"   {desc}")
    
    try:
        # 파일 확장자 추출
        ext = url.split('.')[-1]
        if '?' in ext:
            ext = 'ttf'  # 기본값
            
        response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'})
        response.raise_for_status()
        
        file_path = FONTS_DIR / f"{name}.{ext}"
        with open(file_path, 'wb') as f:
            f.write(response.content)
        
        print(f"   ✅ {name} 다운로드 완료!")
        return True
        
    except Exception as e:
        print(f"   ❌ {name} 다운로드 실패: {e}")
        return False

def main():
    print("🎨 인기 한글 폰트 다운로드!")
    print("=" * 50)
    
    success_count = 0
    
    for name, info in FONTS.items():
        if info.get('direct'):
            if download_direct_font(name, info['url'], info['desc']):
                success_count += 1
        else:
            # ZIP 파일 처리 (기존 코드와 유사)
            print(f"\n📥 {name} 다운로드 중...")
            print(f"   {info['desc']}")
            try:
                response = requests.get(info['url'], stream=True, headers={'User-Agent': 'Mozilla/5.0'})
                if response.status_code == 200:
                    file_path = FONTS_DIR / f"{name}.zip"
                    with open(file_path, 'wb') as f:
                        for chunk in response.iter_content(chunk_size=8192):
                            f.write(chunk)
                    
                    # ZIP 압축 해제
                    try:
                        with zipfile.ZipFile(file_path, 'r') as zip_ref:
                            extract_dir = FONTS_DIR / name
                            extract_dir.mkdir(exist_ok=True)
                            zip_ref.extractall(extract_dir)
                        file_path.unlink()
                        print(f"   ✅ {name} 다운로드 완료!")
                        success_count += 1
                    except:
                        print(f"   ⚠️ {name} 압축 해제 실패")
                else:
                    print(f"   ❌ {name} 다운로드 실패")
            except Exception as e:
                print(f"   ❌ {name} 다운로드 실패: {e}")
    
    print("\n" + "=" * 50)
    print(f"✨ {success_count}개 폰트 다운로드 완료!")
    print(f"📁 폰트 위치: {FONTS_DIR.absolute()}")
    
    # 웹사이트에서 직접 다운로드할 수 있는 폰트들
    print("\n🌟 추가 추천 폰트 (웹사이트에서 다운로드):")
    print("\n1. 🎮 게임 전용 폰트:")
    print("   - 던파 비트비트체 V2: 던전앤파이터 스타일")
    print("   - 메이플스토리체: 귀여운 게임 스타일")
    print("   - 쿠키런 폰트: 달콤한 쿠키런 스타일")
    
    print("\n2. 💪 임팩트 있는 폰트:")
    print("   - 잘풀리는집: 강하고 굵은 폰트")
    print("   - 카페24 써라운드: 입체감 있는 폰트")
    print("   - 에스코어 드림: 현대적이고 깔끔함")
    
    print("\n3. 🎨 개성 있는 폰트:")
    print("   - 오뮤 다예쁨체: 손글씨 느낌")
    print("   - 교보 손글씨: 다양한 손글씨체")
    print("   - 마포 꽃섬: 부드러운 느낌")
    
    print("\n👉 눈누(noonnu.cc)에서 더 많은 폰트를 찾아보세요!")

if __name__ == "__main__":
    main()