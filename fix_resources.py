#!/usr/bin/env python3
"""
PyInstaller 리소스 경로 문제를 자동으로 수정하는 스크립트
"""

import re
import os

# 헬퍼 함수 코드
HELPER_FUNCTION = '''
# PyInstaller 리소스 경로 헬퍼 함수
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

'''

def fix_resource_paths(file_path):
    """pingfighter.py 파일의 리소스 경로를 수정"""
    
    # 파일 읽기
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # import 부분 찾기
    import_end = content.find('\n# === 하프 대쉬 시스템 ===')
    if import_end == -1:
        import_end = content.find('\npygame.init()')
        if import_end == -1:
            import_end = 1000  # 대략적인 위치
    
    # 헬퍼 함수가 이미 있는지 확인
    if 'def resource_path(' not in content:
        # 헬퍼 함수 삽입
        content = content[:import_end] + '\n' + HELPER_FUNCTION + content[import_end:]
    
    # 리소스 로딩 패턴들을 수정
    patterns = [
        # Sound 파일
        (r'pygame\.mixer\.Sound\(["\'](.*?)["\']\)', r'pygame.mixer.Sound(resource_path("\1"))'),
        # Image 파일
        (r'pygame\.image\.load\(["\'](.*?)["\']\)', r'pygame.image.load(resource_path("\1"))'),
        # Font 파일
        (r'pygame\.font\.Font\(["\'](.*?)["\'],', r'pygame.font.Font(resource_path("\1"),'),
        # JSON 파일 with open
        (r'with open\(["\'](.*?\.json)["\']', r'with open(resource_path("\1")'),
        # 일반 open 호출 (파일 확장자가 있는 경우)
        (r'open\(["\'](.*?\.\w+)["\']', r'open(resource_path("\1")'),
    ]
    
    # 패턴 적용
    for pattern, replacement in patterns:
        # resource_path가 이미 적용된 경우는 건너뛰기
        if 'resource_path' not in replacement or 'resource_path(resource_path' not in content:
            content = re.sub(pattern, replacement, content)
    
    # 중복 resource_path 호출 제거
    content = re.sub(r'resource_path\(resource_path\(', r'resource_path(', content)
    
    # 백업 파일 생성
    backup_path = file_path + '.backup_resources'
    with open(backup_path, 'w', encoding='utf-8') as f:
        with open(file_path, 'r', encoding='utf-8') as original:
            f.write(original.read())
    print(f"✅ 백업 파일 생성: {backup_path}")
    
    # 수정된 내용 저장
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✅ 파일 수정 완료: {file_path}")
    
    # 수정 통계
    sound_count = content.count('pygame.mixer.Sound(resource_path(')
    image_count = content.count('pygame.image.load(resource_path(')
    font_count = content.count('pygame.font.Font(resource_path(')
    
    print(f"📊 수정 통계:")
    print(f"  - Sound 파일: {sound_count}개")
    print(f"  - Image 파일: {image_count}개")
    print(f"  - Font 파일: {font_count}개")
    
    return True

def main():
    """메인 함수"""
    print("=" * 50)
    print("🔧 PyInstaller 리소스 경로 수정 스크립트")
    print("=" * 50)
    
    file_path = '/Users/pika/Desktop/game/bosspong/pingfighter.py'
    
    if not os.path.exists(file_path):
        print(f"❌ 파일을 찾을 수 없습니다: {file_path}")
        return False
    
    print(f"📁 대상 파일: {file_path}")
    print("🔄 수정 시작...")
    
    if fix_resource_paths(file_path):
        print("\n✅ 리소스 경로 수정 완료!")
        print("\n📌 다음 단계:")
        print("1. python3 pingfighter.py로 게임 테스트")
        print("2. pyinstaller로 다시 빌드")
        print("3. 실행 파일 테스트")
        return True
    else:
        print("❌ 수정 실패!")
        return False

if __name__ == "__main__":
    main()