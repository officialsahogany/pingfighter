#!/usr/bin/env python3
"""
PF스타더스트 3.0 S 폰트 다운로드 및 설치 스크립트
"""

import os
import requests
import sys

def download_font():
    """PF스타더스트 폰트 다운로드"""
    
    # 폰트 URL (눈누에서 제공하는 CDN)
    font_urls = {
        'PFStardust': 'https://fastly.jsdelivr.net/gh/projectnoonnu/noonfonts_2307-1@1.1/PFStardust3.0S.woff2',
        'PFStardust_bold': 'https://fastly.jsdelivr.net/gh/projectnoonnu/noonfonts_2307-1@1.1/PFStardust3.0B.woff2'
    }
    
    print("🎮 PF스타더스트 3.0 S 폰트 다운로드를 시작합니다...")
    print("=" * 50)
    
    # 먼저 TTF 변환된 버전이 있는지 확인
    # 대체 방법: 직접 TTF 파일 찾기
    ttf_url = "https://cdn.jsdelivr.net/gh/projectnoonnu/noonfonts_2307-1@1.1/PFStardust.ttf"
    
    try:
        # TTF 직접 다운로드 시도
        print("📥 TTF 형식 폰트 다운로드 중...")
        response = requests.get(ttf_url, verify=False)
        
        if response.status_code == 200:
            with open("PFStardust.ttf", "wb") as f:
                f.write(response.content)
            print("✅ PFStardust.ttf 다운로드 완료!")
            return True
    except:
        pass
    
    # WOFF2 다운로드 (브라우저용)
    for name, url in font_urls.items():
        try:
            print(f"📥 {name} 다운로드 중...")
            response = requests.get(url, verify=False)
            
            if response.status_code == 200:
                filename = f"{name}.woff2"
                with open(filename, "wb") as f:
                    f.write(response.content)
                print(f"✅ {filename} 다운로드 완료!")
            else:
                print(f"❌ {name} 다운로드 실패: {response.status_code}")
                
        except Exception as e:
            print(f"❌ 다운로드 오류: {e}")
    
    print("\n⚠️  주의: WOFF2 형식은 pygame에서 직접 사용할 수 없습니다.")
    print("💡 해결 방법:")
    print("1. 온라인 변환기 사용: https://cloudconvert.com/woff2-to-ttf")
    print("2. 또는 아래 사이트에서 직접 TTF 다운로드:")
    print("   https://m.blog.naver.com/campanula913/221366697603")
    print("\n3. TTF 파일을 'PFStardust.ttf'로 저장한 후 게임을 실행하세요.")
    
    return False

if __name__ == "__main__":
    success = download_font()
    
    if success:
        print("\n🎉 폰트 설치 완료!")
        print("이제 pixel_font_manager.py를 업데이트하여 적용할 수 있습니다.")
    else:
        print("\n📝 수동 설치가 필요합니다.")
        print("위의 안내를 따라 TTF 파일을 다운로드해주세요.")