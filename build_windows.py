#!/usr/bin/env python3
"""
Windows 실행파일 빌드 스크립트
macOS에서 Windows용 실행파일을 크로스 컴파일하거나
Windows에서 직접 실행할 수 있습니다.
"""

import os
import sys
import subprocess
from PIL import Image

def create_ico_from_png():
    """PNG 파일에서 ICO 파일 생성"""
    try:
        # ball.png를 ico로 변환
        if os.path.exists('ball.png'):
            img = Image.open('ball.png')
            img.save('ball.ico', format='ICO', sizes=[(16,16), (32,32), (48,48), (256,256)])
            print("✅ ball.ico 파일 생성 완료")
            return True
    except ImportError:
        print("⚠️ Pillow 라이브러리가 필요합니다: pip install Pillow")
        return False
    except Exception as e:
        print(f"❌ ICO 파일 생성 실패: {e}")
        return False

def build_windows_exe():
    """Windows 실행파일 빌드"""
    
    # ICO 파일 생성 시도
    if not os.path.exists('ball.ico'):
        print("🔧 ICO 파일이 없어서 생성을 시도합니다...")
        if not create_ico_from_png():
            print("⚠️ ICO 파일 없이 빌드를 계속합니다...")
    
    # PyInstaller 설치 확인
    try:
        import PyInstaller
    except ImportError:
        print("❌ PyInstaller가 설치되어 있지 않습니다.")
        print("설치하려면: pip install pyinstaller")
        return False
    
    # 빌드 명령어
    cmd = [
        sys.executable, '-m', 'PyInstaller',
        'PingFighter_Windows.spec',
        '--clean',  # 이전 빌드 제거
        '--noconfirm'  # 덮어쓰기 확인 없음
    ]
    
    print("🏗️ Windows 실행파일 빌드 시작...")
    print(f"명령어: {' '.join(cmd)}")
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ 빌드 성공!")
            print("📁 실행파일 위치: dist/PingFighter.exe")
            return True
        else:
            print("❌ 빌드 실패!")
            print("에러 출력:")
            print(result.stderr)
            return False
            
    except Exception as e:
        print(f"❌ 빌드 중 오류 발생: {e}")
        return False

def main():
    """메인 함수"""
    print("=" * 50)
    print("🎮 PingFighter Windows 실행파일 빌드")
    print("=" * 50)
    
    # 현재 OS 확인
    if sys.platform == 'darwin':
        print("⚠️ 경고: macOS에서 실행 중입니다.")
        print("Windows 실행파일을 크로스 컴파일하려면 wine이 필요할 수 있습니다.")
        print("최상의 결과를 위해서는 Windows에서 직접 빌드하는 것을 권장합니다.")
        print()
    elif sys.platform == 'win32':
        print("✅ Windows에서 실행 중입니다.")
        print()
    
    # 빌드 실행
    if build_windows_exe():
        print("\n🎉 빌드가 완료되었습니다!")
        print("📌 다음 단계:")
        print("1. dist/PingFighter.exe 파일을 Windows로 복사")
        print("2. Windows에서 실행하여 테스트")
        print("3. 필요한 경우 Windows Defender 예외 추가")
    else:
        print("\n❌ 빌드에 실패했습니다.")
        print("위의 에러 메시지를 확인하세요.")

if __name__ == "__main__":
    main()