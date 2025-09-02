#!/usr/bin/env python3
"""
🎈 PingFighter with Balloon Machine Event
Stage 1에서 플레이어가 2점 획득 시 풍선 기계 이벤트가 발동되는 버전
"""

import pygame
import sys
import os

# pingfighter 모듈 임포트
import pingfighter
from events.stage1_event_integration import Stage1EventManager

# 원본 main 함수 백업
original_main = pingfighter.main
original_go_to_next_round = pingfighter.go_to_next_round

# 이벤트 매니저 초기화
stage1_events = Stage1EventManager()
balloon_event_delay = 0
event_check_done = False

def patched_go_to_next_round():
    """패치된 go_to_next_round 함수"""
    global balloon_event_delay, event_check_done
    
    # 원본 함수 호출
    original_go_to_next_round()
    
    # Stage 1 이벤트 체크 (플레이어가 2점 달성 시)
    if (pingfighter.current_stage == 1 and 
        pingfighter.game_state.player_score >= 2 and 
        not event_check_done):
        
        if stage1_events.check_events(
            pingfighter.game_state.player_score, 
            pingfighter.game_state.boss_score, 
            pingfighter.current_stage, 
            pingfighter.round_count
        ):
            balloon_event_delay = 90  # 1.5초 후에 이벤트 발동
            event_check_done = True
            print("🎈 풍선 기계 이벤트 준비 중...")

def patched_main(stage_num, new_boss_mode=False):
    """패치된 main 함수"""
    global balloon_event_delay, event_check_done
    
    # 이벤트 초기화
    stage1_events.reset()
    balloon_event_delay = 0
    event_check_done = False
    
    # 원본 main 실행 전 설정
    pingfighter.go_to_next_round = patched_go_to_next_round
    
    # 프레임 카운터
    frame_counter = 0
    
    # 원본 게임 시작
    print("🎮 Starting PingFighter with Balloon Event...")
    print("🎈 Get 2 points in Stage 1 to trigger the special event!")
    
    # 게임 루프를 후킹하기 위해 직접 실행
    result = run_game_with_events(stage_num, new_boss_mode)
    
    return result

def run_game_with_events(stage_num, new_boss_mode=False):
    """이벤트가 통합된 게임 루프 실행"""
    global balloon_event_delay
    
    # pingfighter 초기화 코드 실행
    pingfighter.current_stage = stage_num
    pingfighter.initialize_game_for_stage(stage_num)
    
    if stage_num == 1:
        pingfighter.show_stage1_intro()
    elif stage_num == 2:
        pingfighter.show_stage2_intro()
    elif stage_num == 3:
        pingfighter.show_stage3_intro()
    elif stage_num == 4:
        pingfighter.show_stage4_intro()
    elif stage_num == 5:
        pingfighter.show_stage5_intro()
    elif stage_num == 6:
        pingfighter.show_stage6_intro()
    
    clock = pygame.time.Clock()
    running = True
    
    while running:
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
                return "quit"
            
            # 원본 이벤트 처리
            pingfighter.handle_events(event)
        
        # 🎈 풍선 이벤트 지연 처리
        if balloon_event_delay > 0:
            balloon_event_delay -= 1
            if balloon_event_delay == 0:
                stage1_events.trigger_event(
                    pingfighter.SCREEN, 
                    pingfighter.game_state.player_score, 
                    pingfighter.current_stage
                )
                print("🎈 풍선 기계 이벤트 발동!")
        
        # 🎈 Stage 1 이벤트 업데이트
        if pingfighter.current_stage == 1:
            stage1_events.update()
            
            # 이벤트 중에는 게임 일시정지
            if stage1_events.should_pause_game():
                # 화면 그리기만 하고 물리 업데이트는 건너뛰기
                pingfighter.draw_game()
                stage1_events.draw(pingfighter.SCREEN)
            else:
                # 정상적인 게임 업데이트
                pingfighter.update_game()
                pingfighter.draw_game()
                
                # 이벤트 그리기
                stage1_events.draw(pingfighter.SCREEN)
        else:
            # 다른 스테이지는 정상 실행
            pingfighter.update_game()
            pingfighter.draw_game()
        
        pygame.display.flip()
        clock.tick(60)
        
        # 게임 종료 조건 체크
        if pingfighter.check_game_end():
            running = False
    
    return "main_menu"

# 실제 실행을 위한 간단한 래퍼
def run_with_balloon_event():
    """풍선 이벤트가 포함된 게임 실행"""
    pygame.init()
    
    # 화면 초기화
    pingfighter.SCREEN = pygame.display.set_mode((pingfighter.WIDTH, pingfighter.HEIGHT))
    pygame.display.set_caption("PingFighter - With Balloon Event")
    
    # Stage 1로 시작
    result = patched_main(1, False)
    
    pygame.quit()
    return result

if __name__ == "__main__":
    print("=" * 60)
    print("🎈 PINGFIGHTER WITH BALLOON MACHINE EVENT")
    print("=" * 60)
    print("Stage 1에서 플레이어가 2점을 획득하면")
    print("특별한 풍선 기계 이벤트가 발동됩니다!")
    print("=" * 60)
    
    # 실제로는 pingfighter.py의 전체 플로우를 사용해야 하므로
    # 이 파일은 통합 방법을 보여주는 예시입니다.
    
    print("\n⚠️ 주의: 이 파일은 통합 예시입니다.")
    print("실제 통합을 위해서는 integrate_balloon_event.py의 가이드를 따라")
    print("pingfighter.py를 직접 수정하거나,")
    print("test_balloon_machine_event.py로 독립적으로 테스트하세요.\n")
    
    # 통합 가이드 실행
    os.system("python integrate_balloon_event.py")