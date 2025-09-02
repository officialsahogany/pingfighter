"""
🎈 Balloon Machine Event - Main Game Integration Helper
이 스크립트는 pingfighter.py에 풍선 기계 이벤트를 통합하는 방법을 보여줍니다.
"""

import sys
import os

def create_integration_code():
    """pingfighter.py에 추가할 코드를 생성합니다."""
    
    print("=" * 60)
    print("🎈 BALLOON MACHINE EVENT INTEGRATION")
    print("=" * 60)
    print("\n다음 코드를 pingfighter.py에 추가하세요:\n")
    
    # 1. Import 섹션
    print("### 1. IMPORT 섹션에 추가 (파일 상단, 다른 import 문들과 함께):")
    print("-" * 40)
    print("""
# 🎈 Stage 1 풍선 기계 이벤트
from events.stage1_event_integration import Stage1EventManager
    """)
    
    # 2. 초기화 섹션
    print("\n### 2. 초기화 섹션에 추가 (pygame.init() 이후):")
    print("-" * 40)
    print("""
# 🎈 Stage 1 이벤트 매니저 초기화
stage1_events = Stage1EventManager()
balloon_event_delay = 0  # 이벤트 발동 지연 타이머
    """)
    
    # 3. go_to_next_round 함수 수정
    print("\n### 3. go_to_next_round() 함수 시작 부분에 추가 (line ~1677):")
    print("-" * 40)
    print("""
def go_to_next_round():
    global balloon_event_delay
    
    # 🎈 Stage 1 이벤트 체크 (플레이어가 2점 달성 시)
    if current_stage == 1 and game_state.player_score >= 2:
        if stage1_events.check_events(game_state.player_score, game_state.boss_score, current_stage, round_count):
            balloon_event_delay = 60  # 1초 후에 이벤트 발동
    
    # ... 기존 코드 계속 ...
    """)
    
    # 4. 메인 게임 루프에 추가
    print("\n### 4. main() 함수의 메인 게임 루프에 추가 (while running: 안에):")
    print("-" * 40)
    print("""
    # === 메인 게임 루프 안에 추가 ===
    
    # 🎈 풍선 이벤트 지연 처리 (라운드 시작 후 잠시 대기)
    if balloon_event_delay > 0:
        balloon_event_delay -= 1
        if balloon_event_delay == 0:
            stage1_events.trigger_event(SCREEN, game_state.player_score, current_stage)
    
    # 🎈 Stage 1 이벤트 업데이트
    if current_stage == 1:
        stage1_events.update()
        
        # 이벤트 중에는 게임 일시정지
        if stage1_events.should_pause_game():
            # 공과 패들 업데이트를 건너뛰기
            pass
        else:
            # 정상적인 게임 업데이트 (기존 코드)
            # ... physics_manager.update_ball_position() 등 ...
            pass
    """)
    
    # 5. 렌더링 섹션에 추가
    print("\n### 5. 화면 그리기 섹션에 추가 (pygame.display.flip() 전에):")
    print("-" * 40)
    print("""
    # 🎈 Stage 1 이벤트 그리기 (다른 UI 요소들 위에)
    if current_stage == 1:
        stage1_events.draw(SCREEN)
    """)
    
    # 6. 게임 리셋 시 추가
    print("\n### 6. 새 게임 시작 또는 스테이지 변경 시 추가:")
    print("-" * 40)
    print("""
    # 게임 초기화 또는 스테이지 변경 시
    stage1_events.reset()
    balloon_event_delay = 0
    """)
    
    print("\n" + "=" * 60)
    print("통합 완료!")
    print("=" * 60)

def find_line_numbers():
    """pingfighter.py에서 수정할 위치의 라인 번호를 찾습니다."""
    
    try:
        with open('pingfighter.py', 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        print("\n📍 수정 위치 찾기:")
        print("-" * 40)
        
        # Import 섹션 찾기
        for i, line in enumerate(lines[:100], 1):
            if 'import pygame' in line:
                print(f"  Import 섹션: Line {i} 근처")
                break
        
        # go_to_next_round 찾기
        for i, line in enumerate(lines, 1):
            if 'def go_to_next_round():' in line:
                print(f"  go_to_next_round 함수: Line {i}")
                break
        
        # main 함수 찾기
        for i, line in enumerate(lines, 1):
            if 'def main(stage_num' in line:
                print(f"  main 함수: Line {i}")
                break
        
        # while running 찾기
        for i, line in enumerate(lines, 1):
            if 'while running:' in line:
                print(f"  메인 게임 루프: Line {i}")
                
    except FileNotFoundError:
        print("  ⚠️ pingfighter.py 파일을 찾을 수 없습니다.")

def test_balloon_event():
    """이벤트가 제대로 설치되었는지 테스트합니다."""
    
    print("\n🧪 테스트 방법:")
    print("-" * 40)
    print("""
1. 먼저 독립 테스트 실행:
   python test_balloon_machine_event.py

2. pingfighter.py에 통합 후:
   - Stage 1에서 플레이
   - 플레이어가 2점 획득
   - 다음 라운드 시작 시 이벤트 발동 확인

3. 디버깅:
   - console에 "🎈 Balloon Machine Event Activated!" 메시지 확인
   - 이벤트가 발동하지 않으면 stage1_events.check_events() 호출 확인
    """)

if __name__ == "__main__":
    create_integration_code()
    find_line_numbers()
    test_balloon_event()
    
    print("\n💡 TIP: 이 스크립트의 출력을 참고하여 pingfighter.py를 수정하세요.")
    print("   또는 test_balloon_machine_event.py로 독립적으로 테스트할 수 있습니다.")