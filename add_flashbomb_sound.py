#!/usr/bin/env python3
"""
조명탄 폭발 시 flashbomb.wav 사운드 재생 패치
"""

import sys
import shutil
from datetime import datetime


def add_flashbomb_sound():
    """조명탄 폭발 사운드 추가"""
    
    print("\n" + "="*60)
    print("💡 조명탄 폭발 사운드 추가 패치")
    print("="*60)
    
    # 백업 생성
    source_file = "pingfighter.py"
    backup_file = f"pingfighter_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.py"
    
    print(f"\n1️⃣ 백업 생성 중...")
    try:
        shutil.copy(source_file, backup_file)
        print(f"   ✅ 백업 완료: {backup_file}")
    except Exception as e:
        print(f"   ❌ 백업 실패: {e}")
        return False
    
    # pingfighter.py 읽기
    print(f"\n2️⃣ {source_file} 읽는 중...")
    try:
        with open(source_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        print(f"   ✅ 파일 읽기 완료 ({len(lines)} 줄)")
    except Exception as e:
        print(f"   ❌ 파일 읽기 실패: {e}")
        return False
    
    # 1. 사운드 로드 추가
    print(f"\n3️⃣ SOUND_FLASHBOMB 로드 코드 추가 중...")
    
    sound_added = False
    for i, line in enumerate(lines):
        if 'SOUND_SMOKEBOMB = pygame.mixer.Sound("sounds/smokebomb.wav")' in line:
            # SOUND_SMOKEBOMB 다음 줄에 SOUND_FLASHBOMB 추가
            lines.insert(i + 1, 'SOUND_FLASHBOMB = pygame.mixer.Sound("sounds/flashbomb.wav")  # 💡 조명탄 폭발 효과음\n')
            print(f"   ✅ SOUND_FLASHBOMB 로드 코드 추가 (Line {i+2})")
            sound_added = True
            break
    
    if not sound_added:
        print("   ❌ SOUND_SMOKEBOMB를 찾을 수 없습니다")
        return False
    
    # 2. 조명탄 폭발 시 사운드 재생 코드 추가
    print(f"\n4️⃣ 조명탄 폭발 시 사운드 재생 코드 추가 중...")
    
    explosion_fixed = False
    for i, line in enumerate(lines):
        # 조명탄 폭발 부분 찾기
        if 'if flare["timer"] >= 90:' in line:
            # flare["exploded"] = True 다음에 사운드 재생 코드 추가
            for j in range(i, min(i+20, len(lines))):
                if 'flare["exploded"] = True' in lines[j]:
                    # 다음 줄에 사운드 재생 코드 추가
                    indent = "                "  # 들여쓰기 맞추기
                    lines.insert(j + 1, f'{indent}# 💡 조명탄 폭발 사운드 재생\n')
                    lines.insert(j + 2, f'{indent}try:\n')
                    lines.insert(j + 3, f'{indent}    SOUND_FLASHBOMB.play()\n')
                    lines.insert(j + 4, f'{indent}except:\n')
                    lines.insert(j + 5, f'{indent}    pass  # 사운드 재생 실패 시 무시\n')
                    print(f"   ✅ 조명탄 폭발 사운드 재생 코드 추가 (Line {j+2})")
                    explosion_fixed = True
                    break
            if explosion_fixed:
                break
    
    if not explosion_fixed:
        print("   ⚠️ 조명탄 폭발 코드를 찾을 수 없어 대체 방법 시도...")
        # 대체 방법: "조명탄 폭발!" 메시지 근처에 추가
        for i, line in enumerate(lines):
            if '조명탄 폭발! 보스가' in line:
                # 이 줄 앞에 사운드 재생 코드 추가
                indent = "                "
                lines.insert(i, f'{indent}# 💡 조명탄 폭발 사운드 재생\n')
                lines.insert(i + 1, f'{indent}try:\n')
                lines.insert(i + 2, f'{indent}    SOUND_FLASHBOMB.play()\n')
                lines.insert(i + 3, f'{indent}except:\n')
                lines.insert(i + 4, f'{indent}    pass\n')
                print(f"   ✅ 대체 방법으로 사운드 재생 코드 추가 (Line {i+1})")
                explosion_fixed = True
                break
    
    if not explosion_fixed:
        print("   ❌ 조명탄 폭발 코드를 찾을 수 없습니다")
        return False
    
    # 파일 저장
    print(f"\n5️⃣ 수정된 파일 저장 중...")
    try:
        with open(source_file, 'w', encoding='utf-8') as f:
            f.writelines(lines)
        print(f"   ✅ 파일 저장 완료")
    except Exception as e:
        print(f"   ❌ 파일 저장 실패: {e}")
        return False
    
    print("\n" + "="*60)
    print("✅ 조명탄 폭발 사운드 추가 완료!")
    print("="*60)
    print("\n다음 변경사항이 적용되었습니다:")
    print("• SOUND_FLASHBOMB 로드 추가")
    print("• 조명탄 폭발 시 flashbomb.wav 재생")
    print("\n게임을 실행하여 테스트해보세요!")
    
    return True


if __name__ == "__main__":
    success = add_flashbomb_sound()
    if not success:
        print("\n⚠️ 패치 적용에 실패했습니다. 백업 파일을 확인하세요.")
        sys.exit(1)