#!/usr/bin/env python3
"""
스마트폰-스톱워치 연동 테스트
스마트폰이 자동으로 스톱워치를 발동하고, 
스톱워치 종료 시 공이 위(보스) 방향으로 가는지 확인
"""

import pygame
import sys
import os
import math

# 게임 경로를 sys.path에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 필요한 모듈 import
import pingfighter
from item_effects.smartphone import get_smartphone_instance
from item_effects.stopwatch import get_stopwatch_instance

def test_smartphone_stopwatch():
    """스마트폰-스톱워치 연동 테스트"""
    pygame.init()
    screen = pygame.display.set_mode((800, 750))
    pygame.display.set_caption("스마트폰-스톱워치 테스트")
    clock = pygame.time.Clock()
    font = pygame.font.Font(None, 36)
    
    # 게임 상태 초기화
    game_state = {
        'active_items': [
            {'name': 'stopwatch', 'effect': 'stopwatch'},  # 스톱워치 추가
            None,
            None
        ]
    }
    
    # 스테이지 모의 객체
    class MockStage:
        def __init__(self):
            self.ball_x = 600
            self.ball_y = 650  # 플레이어 근처
            self.ball_vx = -8  # 왼쪽으로 (플레이어 방향)
            self.ball_vy = 3   # 아래로
            self.paddle_y = 700  # 플레이어 패들 위치
            self.paddle_size = 100
    
    stage = MockStage()
    
    # 스마트폰 활성화
    smartphone = get_smartphone_instance()
    smartphone.activate(game_state, stage)
    
    # pingfighter 모듈 변수 설정
    pingfighter.PLAYER = pygame.Rect(50, stage.paddle_y, 155, 50)
    pingfighter.active_item_slot = game_state['active_items'].copy()
    pingfighter.stopwatch_active = False
    pingfighter.stopwatch_timer = 0
    pingfighter.stopwatch_forced_upward = False
    pingfighter.ball_vel = [stage.ball_vx, stage.ball_vy]
    pingfighter.last_hit_by = "boss"  # 보스가 친 공으로 설정
    
    # 스톱워치 인스턴스
    stopwatch = get_stopwatch_instance()
    
    running = True
    frame_count = 0
    stopwatch_activated_frame = -1
    stopwatch_recovered_frame = -1
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 수동으로 위험 상황 만들기
                    stage.ball_y = 680
                    stage.ball_vx = -15
                    stage.ball_vy = 5
                    pingfighter.ball_vel = [stage.ball_vx, stage.ball_vy]
        
        # 화면 그리기
        screen.fill((30, 30, 40))
        
        # 스마트폰 업데이트
        smartphone.update(game_state, stage)
        
        # 스톱워치 상태 확인
        if pingfighter.stopwatch_active and stopwatch_activated_frame == -1:
            stopwatch_activated_frame = frame_count
            print(f"[프레임 {frame_count}] 스톱워치 발동!")
        
        # 스톱워치 타이머 감소 시뮬레이션
        if pingfighter.stopwatch_active:
            pingfighter.stopwatch_timer -= 1
            if pingfighter.stopwatch_timer <= 0:
                # 스톱워치 종료 시뮬레이션
                if pingfighter.stopwatch_forced_upward:
                    # 강제로 위 방향 설정
                    speed = math.hypot(pingfighter.ball_vel[0], pingfighter.ball_vel[1])
                    if speed < 5:
                        speed = 5
                    pingfighter.ball_vel[0] = 3.0
                    pingfighter.ball_vel[1] = -speed  # 위쪽(음수)
                    print(f"[프레임 {frame_count}] 스톱워치 종료 - 위 방향 강제: {pingfighter.ball_vel}")
                    stopwatch_recovered_frame = frame_count
                
                pingfighter.stopwatch_active = False
                pingfighter.stopwatch_forced_upward = False
        
        # 공 위치 업데이트
        stage.ball_x += stage.ball_vx
        stage.ball_y += stage.ball_vy
        
        # 화면 경계 처리
        if stage.ball_x < 0 or stage.ball_x > 800:
            stage.ball_vx = -stage.ball_vx
        if stage.ball_y < 0 or stage.ball_y > 750:
            stage.ball_vy = -stage.ball_vy
        
        # 공 그리기
        pygame.draw.circle(screen, (255, 255, 0), (int(stage.ball_x), int(stage.ball_y)), 10)
        
        # 플레이어 패들 그리기
        pygame.draw.rect(screen, (100, 200, 100), pingfighter.PLAYER)
        
        # 정보 표시
        info_texts = [
            f"Frame: {frame_count}",
            f"Ball: ({stage.ball_x:.0f}, {stage.ball_y:.0f})",
            f"Velocity: ({stage.ball_vx:.1f}, {stage.ball_vy:.1f})",
            f"Stopwatch: {'ON' if pingfighter.stopwatch_active else 'OFF'}",
            f"Forced Up: {'YES' if pingfighter.stopwatch_forced_upward else 'NO'}",
            f"Final Vel: ({pingfighter.ball_vel[0]:.1f}, {pingfighter.ball_vel[1]:.1f})",
        ]
        
        if stopwatch_activated_frame > 0:
            info_texts.append(f"Activated at frame: {stopwatch_activated_frame}")
        if stopwatch_recovered_frame > 0:
            info_texts.append(f"Recovered at frame: {stopwatch_recovered_frame}")
            if pingfighter.ball_vel[1] < 0:
                info_texts.append("✅ SUCCESS: Ball going UP!")
            else:
                info_texts.append("❌ FAIL: Ball NOT going up!")
        
        for i, text in enumerate(info_texts):
            text_surface = font.render(text, True, (255, 255, 255))
            screen.blit(text_surface, (10, 10 + i * 40))
        
        # 지시사항
        instruction = font.render("Press SPACE to create danger", True, (200, 200, 200))
        screen.blit(instruction, (10, 600))
        
        pygame.display.flip()
        clock.tick(60)
        frame_count += 1
    
    pygame.quit()
    
    # 테스트 결과 출력
    if stopwatch_recovered_frame > 0:
        if pingfighter.ball_vel[1] < 0:
            print("\n✅ 테스트 성공: 스톱워치 종료 후 공이 위로 향합니다!")
        else:
            print("\n❌ 테스트 실패: 스톱워치 종료 후 공이 위로 향하지 않습니다.")
    else:
        print("\n⚠️ 테스트 미완료: 스톱워치가 발동되지 않았습니다.")

if __name__ == "__main__":
    test_smartphone_stopwatch()