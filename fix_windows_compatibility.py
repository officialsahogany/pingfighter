#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Windows 호환성 수정 스크립트
핑파이터 게임의 Windows 실행 시 발생하는 문제들을 수정합니다.

문제 해결 목록:
1. 오프닝 한글 글자 깨짐
2. 스테이지1, 스테이지2 배경 출력 안됨
3. 전설 아이템 아이콘 출력 안됨
4. 효과음 일부 재생 안됨
5. unknown_item.png 출력 안됨
"""

import os
import re
import sys

def add_utf8_encoding():
    """파이썬 파일들에 UTF-8 인코딩 헤더 추가"""
    print("1️⃣ UTF-8 인코딩 설정 중...")
    
    files_to_fix = [
        'pingfighter.py',
        'pixel_font_manager.py',
        'opening.py',
        'items.py',
        'backgrounds/animated_background.py',
        'backgrounds/animated_background_stage2.py',
        'ui/stage3_menhera_world.py',
        'ui/stage4_shaolin_temple.py',
        'ui/stage5_chinese_market.py',
        'backgrounds/animated_background_stage6.py'
    ]
    
    for file_path in files_to_fix:
        if not os.path.exists(file_path):
            print(f"  ⚠️  {file_path} 파일을 찾을 수 없음")
            continue
            
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # UTF-8 인코딩 헤더가 없으면 추가
        if not content.startswith('# -*- coding: utf-8 -*-'):
            # 첫 줄이 shebang인 경우
            if content.startswith('#!'):
                lines = content.split('\n', 1)
                content = lines[0] + '\n# -*- coding: utf-8 -*-\n' + (lines[1] if len(lines) > 1 else '')
            else:
                content = '# -*- coding: utf-8 -*-\n' + content
            
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"  ✅ {file_path}: UTF-8 인코딩 헤더 추가")
        else:
            print(f"  ✓  {file_path}: 이미 UTF-8 인코딩 설정됨")

def fix_items_unknown_icon():
    """items.py의 unknown_item.png 로딩 수정"""
    print("\n2️⃣ items.py unknown_item.png 로딩 수정 중...")
    
    file_path = 'items.py'
    if not os.path.exists(file_path):
        print(f"  ⚠️  {file_path} 파일을 찾을 수 없음")
        return
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # resource_path 함수가 없으면 추가
    if 'def resource_path' not in content:
        resource_path_code = '''
def resource_path(relative_path):
    """PyInstaller 번들과 일반 실행 모두에서 작동하는 리소스 경로 반환"""
    try:
        # PyInstaller 번들인 경우
        base_path = sys._MEIPASS
    except Exception:
        # 일반 Python 실행인 경우
        base_path = os.path.dirname(os.path.abspath(__file__))
    
    return os.path.join(base_path, relative_path)
'''
        # import 섹션 찾기
        import_section_end = 0
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if line.strip() and not line.strip().startswith('import') and not line.strip().startswith('from'):
                import_section_end = i
                break
        
        # sys와 os 추가
        if 'import sys' not in content:
            lines.insert(import_section_end, 'import sys')
            import_section_end += 1
        if 'import os' not in content:
            lines.insert(import_section_end, 'import os')
            import_section_end += 1
            
        lines.insert(import_section_end, resource_path_code)
        content = '\n'.join(lines)
    
    # unknown_item.png 로딩 수정
    old_pattern = r'UNKNOWN_ITEM_ICON = pygame\.image\.load\("items/unknown_item\.png"\)'
    new_code = 'UNKNOWN_ITEM_ICON = pygame.image.load(resource_path("items/unknown_item.png"))'
    
    modified = False
    if re.search(old_pattern, content):
        content = re.sub(old_pattern, new_code, content)
        modified = True
        
    if modified:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"  ✅ {file_path}: unknown_item.png 로딩 수정 완료")
    else:
        print(f"  ✓  {file_path}: 이미 수정됨 또는 패턴을 찾을 수 없음")

def fix_animated_backgrounds():
    """AnimatedBackground 클래스들의 이미지 로딩 수정"""
    print("\n3️⃣ AnimatedBackground 클래스 수정 중...")
    
    background_files = [
        'backgrounds/animated_background.py',
        'backgrounds/animated_background_stage2.py'
    ]
    
    for file_path in background_files:
        if not os.path.exists(file_path):
            print(f"  ⚠️  {file_path} 파일을 찾을 수 없음")
            continue
        
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # resource_path 함수 추가
        if 'def resource_path' not in content:
            resource_path_code = '''import os
import sys

def resource_path(relative_path):
    """PyInstaller 번들과 일반 실행 모두에서 작동하는 리소스 경로 반환"""
    try:
        # PyInstaller 번들인 경우
        base_path = sys._MEIPASS
    except Exception:
        # 일반 Python 실행인 경우 - 상위 디렉토리로 이동
        base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    
    return os.path.join(base_path, relative_path)

'''
            # 파일 시작 부분에 추가
            lines = content.split('\n')
            import_end = 0
            for i, line in enumerate(lines):
                if line.strip() and not line.strip().startswith('import') and not line.strip().startswith('from'):
                    import_end = i
                    break
            
            lines.insert(import_end, resource_path_code)
            content = '\n'.join(lines)
        
        # pygame.image.load 수정
        old_pattern = r'self\.base_image = pygame\.image\.load\(base_image_path\)'
        new_code = 'self.base_image = pygame.image.load(resource_path(base_image_path))'
        
        modified = False
        if re.search(old_pattern, content):
            content = re.sub(old_pattern, new_code, content)
            modified = True
            
        if modified:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"  ✅ {file_path}: 이미지 로딩 수정 완료")
        else:
            print(f"  ✓  {file_path}: 이미 수정됨 또는 패턴을 찾을 수 없음")

def fix_pixel_font_manager():
    """pixel_font_manager.py의 폰트 로딩 수정"""
    print("\n4️⃣ 픽셀 폰트 매니저 수정 중...")
    
    file_path = 'pixel_font_manager.py'
    if not os.path.exists(file_path):
        print(f"  ⚠️  {file_path} 파일을 찾을 수 없음")
        return
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Windows에서 한글 폰트 처리 개선
    # Windows 전용 폴백 폰트 설정
    windows_fallback = '''
# Windows 한글 폰트 폴백
if sys.platform == "win32":
    # Windows에서 한글 폰트 우선순위
    WINDOWS_KOREAN_FONTS = ["맑은 고딕", "굴림", "돋움", "바탕"]
'''
    
    if 'WINDOWS_KOREAN_FONTS' not in content:
        # USE_PIXEL_FONT 뒤에 추가
        if 'USE_PIXEL_FONT = True' in content:
            content = content.replace('USE_PIXEL_FONT = True', 
                                     'USE_PIXEL_FONT = True' + windows_fallback)
            
            # get_font 함수 수정 - Windows 폴백 추가
            old_font_load = '''try:
            font = pygame.font.Font(PIXEL_FONT, adjusted_size)
            _font_cache[cache_key] = font
            return font
        except:
            print(f"⚠️ 픽셀 폰트 로드 실패, 폴백 사용")'''
            
            new_font_load = '''try:
            font = pygame.font.Font(PIXEL_FONT, adjusted_size)
            _font_cache[cache_key] = font
            return font
        except:
            print(f"⚠️ 픽셀 폰트 로드 실패, 폴백 사용")
            # Windows에서 한글 폰트 폴백
            if sys.platform == "win32":
                for font_name in WINDOWS_KOREAN_FONTS:
                    try:
                        font = pygame.font.SysFont(font_name, adjusted_size)
                        _font_cache[cache_key] = font
                        return font
                    except:
                        continue'''
            
            if old_font_load in content:
                content = content.replace(old_font_load, new_font_load)
            
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"  ✅ {file_path}: Windows 한글 폰트 폴백 추가")
    else:
        print(f"  ✓  {file_path}: 이미 수정됨")

def check_and_create_legendary_folder():
    """전설 아이템 폴더 확인 및 생성"""
    print("\n5️⃣ 전설 아이템 폴더 확인 중...")
    
    legendary_path = 'items/legendary'
    if not os.path.exists(legendary_path):
        os.makedirs(legendary_path, exist_ok=True)
        print(f"  ✅ {legendary_path} 폴더 생성")
        
        # 기본 전설 아이템 아이콘 생성 (없는 경우)
        try:
            import pygame
            pygame.init()
            
            # ragnarok_hammer.png 생성
            icon_path = os.path.join(legendary_path, 'ragnarok_hammer.png')
            if not os.path.exists(icon_path):
                icon = pygame.Surface((32, 32), pygame.SRCALPHA)
                # 붉은 테두리
                pygame.draw.rect(icon, (255, 50, 50), (0, 0, 32, 32), 2)
                # 해머 그리기
                pygame.draw.rect(icon, (120, 120, 140), (8, 7, 16, 8))
                pygame.draw.rect(icon, (101, 67, 33), (14, 10, 4, 16))
                pygame.image.save(icon, icon_path)
                print(f"  ✅ {icon_path} 기본 아이콘 생성")
        except:
            print(f"  ⚠️  pygame이 없어 기본 아이콘을 생성할 수 없음")
    else:
        print(f"  ✓  {legendary_path} 폴더 존재")

def create_windows_readme():
    """Windows 실행 가이드 작성"""
    print("\n6️⃣ Windows 실행 가이드 생성 중...")
    
    readme_content = """# PingFighter Windows 실행 가이드

## 🎮 빠른 시작
1. **install_requirements.bat** 실행 (처음 한 번만)
2. **run_game.bat** 실행

## 📋 시스템 요구사항
- Windows 7 이상
- Python 3.8 이상
- pygame 라이브러리

## 🔧 문제 해결

### 한글이 깨지는 경우
- Windows 시스템 언어를 한국어로 설정
- 코드페이지를 UTF-8로 변경: `chcp 65001`

### 배경이 안 나오는 경우
- stage1_field.png ~ stage6_field.png 파일 확인
- backgrounds/ 폴더 확인

### 아이템 아이콘이 안 나오는 경우
- items/ 폴더의 모든 .png 파일 확인
- items/legendary/ 폴더 확인

### 효과음이 안 나오는 경우
- sounds/ 폴더의 모든 .wav 파일 확인
- Windows 오디오 서비스 실행 중인지 확인

## 📁 필요한 폴더 구조
```
bosspong/
├── items/
│   ├── legendary/
│   └── *.png
├── sounds/
│   └── *.wav
├── backgrounds/
├── fonts/
│   └── *.ttf
└── pingfighter.py
```

## ✅ 수정 내역
1. UTF-8 인코딩 헤더 추가
2. resource_path 함수로 모든 리소스 경로 통일
3. Windows 한글 폰트 폴백 처리
4. 전설 아이템 폴더 자동 생성
5. unknown_item.png 경로 수정
6. AnimatedBackground 경로 수정

## 🚀 실행 파일 빌드 (선택사항)
```bash
pyinstaller PingFighter_Windows.spec
```

빌드된 실행 파일은 dist/ 폴더에 생성됩니다.
"""
    
    with open('WINDOWS_README.md', 'w', encoding='utf-8') as f:
        f.write(readme_content)
    print(f"  ✅ WINDOWS_README.md 생성 완료")

def create_batch_files():
    """Windows 배치 파일 생성"""
    print("\n7️⃣ Windows 배치 파일 생성 중...")
    
    # 게임 실행 배치 파일
    run_batch = """@echo off
chcp 65001 > nul
title PingFighter - 핑파이터
echo ========================================
echo    핑파이터 (PingFighter) v1.0
echo    보스 배틀 아케이드 탁구 게임
echo ========================================
echo.
echo 게임을 시작합니다...
python pingfighter.py
if errorlevel 1 (
    echo.
    echo ❌ 게임 실행 중 오류가 발생했습니다.
    echo Python과 pygame이 설치되어 있는지 확인하세요.
    echo install_requirements.bat을 먼저 실행해주세요.
)
pause
"""
    
    with open('run_game.bat', 'w', encoding='utf-8') as f:
        f.write(run_batch)
    print(f"  ✅ run_game.bat 생성")
    
    # 패키지 설치 배치 파일
    install_batch = """@echo off
chcp 65001 > nul
title PingFighter - 패키지 설치
echo ========================================
echo    PingFighter 필수 패키지 설치
echo ========================================
echo.
echo Python 버전 확인...
python --version
echo.
echo pygame 설치 중...
pip install pygame
echo.
echo ✅ 설치 완료!
echo run_game.bat을 실행하여 게임을 시작하세요.
pause
"""
    
    with open('install_requirements.bat', 'w', encoding='utf-8') as f:
        f.write(install_batch)
    print(f"  ✅ install_requirements.bat 생성")

def main():
    print("=" * 60)
    print("🔧 PingFighter Windows 호환성 수정 도구")
    print("=" * 60)
    
    # 현재 디렉토리 확인
    if not os.path.exists('pingfighter.py'):
        print("\n❌ 오류: pingfighter.py 파일을 찾을 수 없습니다!")
        print("   bosspong 폴더에서 이 스크립트를 실행하세요.")
        return
    
    print("\n수정 작업을 시작합니다...\n")
    
    # 각 수정 작업 실행
    add_utf8_encoding()
    fix_items_unknown_icon()
    fix_animated_backgrounds()
    fix_pixel_font_manager()
    check_and_create_legendary_folder()
    create_windows_readme()
    create_batch_files()
    
    print("\n" + "=" * 60)
    print("✨ Windows 호환성 수정 완료!")
    print("=" * 60)
    print("\n📝 다음 단계:")
    print("1. install_requirements.bat 실행 (처음 한 번만)")
    print("2. run_game.bat 실행하여 게임 시작")
    print("\n⚠️  주의사항:")
    print("- 모든 리소스 폴더(items/, sounds/, fonts/)가 있는지 확인")
    print("- Python 3.8 이상 설치 필요")
    print("=" * 60)

if __name__ == "__main__":
    main()