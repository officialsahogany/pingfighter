#!/usr/bin/env python3
"""
Stage 3 멘헤라 월드 맵 연동 패치
ui/stage3_menhera_world.py를 pingfighter.py에 연동
"""

import sys
import shutil
from datetime import datetime

def integrate_stage3():
    """Stage 3 멘헤라 월드 맵 연동"""
    
    print("\n" + "="*60)
    print("💗 Stage 3 멘헤라 월드 맵 연동 패치")
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
    
    # 1. import 문 수정
    print(f"\n3️⃣ Import 문 수정 중...")
    import_added = False
    for i, line in enumerate(lines):
        if 'from backgrounds.animated_background_stage3 import AnimatedBackgroundStage3' in line:
            # 기존 import를 주석 처리하고 새로운 import 추가
            lines[i] = '# ' + line  # 기존 라인 주석 처리
            lines.insert(i + 1, 'from ui.stage3_menhera_world import Stage3MenheraWorld  # 💗 멘헤라 월드 맵\n')
            print(f"   ✅ Import 문 수정 완료 (Line {i+1})")
            import_added = True
            break
    
    if not import_added:
        print("   ⚠️ 기존 Stage3 import를 찾을 수 없어 새로 추가...")
        for i, line in enumerate(lines):
            if 'from backgrounds.animated_background_stage2' in line:
                lines.insert(i + 1, 'from ui.stage3_menhera_world import Stage3MenheraWorld  # 💗 멘헤라 월드 맵\n')
                print(f"   ✅ Import 문 추가 완료 (Line {i+2})")
                import_added = True
                break
    
    # 2. animated_bg_stage3 초기화 부분 수정
    print(f"\n4️⃣ Stage3 초기화 코드 수정 중...")
    for i, line in enumerate(lines):
        if 'animated_bg_stage3 = AnimatedBackgroundStage3("stage3_field.png")' in line:
            lines[i] = '    animated_bg_stage3 = Stage3MenheraWorld()  # 💗 멘헤라 월드 맵 사용\n'
            print(f"   ✅ Stage3 초기화 수정 완료 (Line {i+1})")
            break
    
    # 3. draw_field 함수에서 Stage3 그리기 부분 수정
    print(f"\n5️⃣ draw_field 함수 수정 중...")
    in_stage3_block = False
    stage3_start = -1
    stage3_end = -1
    
    for i, line in enumerate(lines):
        if 'elif current_stage == 3 and animated_bg_stage3 is not None and not emotional_overdrive_active:' in line:
            stage3_start = i
            in_stage3_block = True
            print(f"   ✅ Stage3 그리기 블록 시작 발견 (Line {i+1})")
        elif in_stage3_block and 'elif current_stage ==' in line:
            stage3_end = i
            in_stage3_block = False
            print(f"   ✅ Stage3 그리기 블록 끝 발견 (Line {i+1})")
            break
    
    if stage3_start != -1:
        # 새로운 Stage3 그리기 코드
        new_stage3_code = """    elif current_stage == 3 and animated_bg_stage3 is not None and not emotional_overdrive_active:
        # 스테이지3에서는 멘헤라 월드 맵 사용 (감정 폭주 시 제외)
        animated_bg_stage3.update(clock.get_time())
        if FULLSCREEN_MODE:
            SCREEN.fill(BLACK)
            temp_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            animated_bg_stage3.draw(temp_surface)
            SCREEN.blit(temp_surface, (GAME_OFFSET_X + screen_shake_offset_x, GAME_OFFSET_Y + screen_shake_offset_y))
        else:
            animated_bg_stage3.draw(SCREEN)
"""
        
        # 기존 코드 제거하고 새 코드 삽입
        if stage3_end == -1:
            # elif가 없으면 다음 조건문까지
            for j in range(stage3_start + 1, len(lines)):
                if lines[j].strip() and not lines[j].startswith(' '):
                    stage3_end = j
                    break
        
        # 기존 코드 블록 제거
        del lines[stage3_start:stage3_end]
        
        # 새 코드 삽입
        for j, new_line in enumerate(new_stage3_code.split('\n')):
            if new_line or j < len(new_stage3_code.split('\n')) - 1:
                lines.insert(stage3_start + j, new_line + '\n')
        
        print(f"   ✅ draw_field 함수 수정 완료")
    
    # 파일 저장
    print(f"\n6️⃣ 수정된 파일 저장 중...")
    try:
        with open(source_file, 'w', encoding='utf-8') as f:
            f.writelines(lines)
        print(f"   ✅ 파일 저장 완료")
    except Exception as e:
        print(f"   ❌ 파일 저장 실패: {e}")
        return False
    
    print("\n" + "="*60)
    print("✅ Stage 3 멘헤라 월드 맵 연동 완료!")
    print("="*60)
    print("\n변경사항:")
    print("• Stage3MenheraWorld import 추가")
    print("• animated_bg_stage3 초기화를 Stage3MenheraWorld()로 변경")
    print("• draw_field에서 Stage3 그리기 코드 유지")
    print("\n게임을 실행하여 Stage 3에서 멘헤라 월드 맵이 표시되는지 확인하세요!")
    
    return True


if __name__ == "__main__":
    success = integrate_stage3()
    if not success:
        print("\n⚠️ 패치 적용에 실패했습니다. 백업 파일을 확인하세요.")
        sys.exit(1)