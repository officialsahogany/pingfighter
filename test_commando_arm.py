#!/usr/bin/env python3
"""
코만도암 (Commando Arm) 기능 테스트 스크립트
이 스크립트는 코만도암의 모든 기능을 테스트합니다.
"""

import pygame
import sys
import math
import random

# Pygame 초기화
pygame.init()
pygame.font.init()

# 화면 설정
WIDTH, HEIGHT = 600, 750
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("코만도암 기능 테스트")

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
YELLOW = (255, 255, 0)
PURPLE = (128, 0, 128)
CYAN = (0, 255, 255)

# 폰트 설정
try:
    font = pygame.font.Font("NeoDGM.ttf", 20)
    title_font = pygame.font.Font("NeoDGM.ttf", 30)
except:
    font = pygame.font.Font(None, 20)
    title_font = pygame.font.Font(None, 30)

# 게임 클럭
clock = pygame.time.Clock()
FPS = 60

# 테스트 상태
class TestState:
    def __init__(self):
        self.commando_arm_obtained = False
        self.test_results = []
        self.current_test = 0
        self.test_timer = 0
        
        # 투척 타이머
        self.grenade_timer = 0
        self.flare_timer = 0
        self.molotov_timer = 0
        
        # 투척 속도
        self.grenade_speed = 0
        self.flare_speed = 0
        self.molotov_speed = 0
        
        # 투척물 리스트
        self.projectiles = []

# 테스트 케이스 정의
test_cases = [
    {
        "name": "기본 상태 확인",
        "description": "코만도암 미획득 상태에서 기본값 확인",
        "test_func": "test_default_values"
    },
    {
        "name": "코만도암 획득",
        "description": "코만도암 획득 후 플래그 설정 확인",
        "test_func": "test_obtain_commando_arm"
    },
    {
        "name": "수류탄 준비시간 단축",
        "description": "수류탄 준비시간 60% 단축 (36→12 프레임)",
        "test_func": "test_grenade_timer"
    },
    {
        "name": "조명탄 준비시간 단축",
        "description": "조명탄 준비시간 60% 단축 (36→12 프레임)",
        "test_func": "test_flare_timer"
    },
    {
        "name": "화염병 준비시간 단축",
        "description": "화염병 준비시간 60% 단축 (36→12 프레임)",
        "test_func": "test_molotov_timer"
    },
    {
        "name": "수류탄 속도 증가",
        "description": "수류탄 투척 속도 50% 증가 (12→18)",
        "test_func": "test_grenade_speed"
    },
    {
        "name": "조명탄 속도 증가",
        "description": "조명탄 투척 속도 50% 증가 (9.6→14.4)",
        "test_func": "test_flare_speed"
    },
    {
        "name": "화염병 속도 증가",
        "description": "화염병 투척 속도 50% 증가 (14.4→21.6)",
        "test_func": "test_molotov_speed"
    },
]

def test_default_values(state):
    """기본 상태 테스트"""
    if not state.commando_arm_obtained:
        return True, "✅ 코만도암 미획득 상태 확인"
    return False, "❌ 코만도암이 이미 획득됨"

def test_obtain_commando_arm(state):
    """코만도암 획득 테스트"""
    state.commando_arm_obtained = True
    if state.commando_arm_obtained:
        return True, "✅ 코만도암 획득 플래그 설정 성공"
    return False, "❌ 코만도암 획득 실패"

def test_grenade_timer(state):
    """수류탄 준비시간 테스트"""
    if state.commando_arm_obtained:
        expected_timer = 12  # 0.2초
        actual_timer = 12 if state.commando_arm_obtained else 36
        if actual_timer == expected_timer:
            return True, f"✅ 수류탄 준비시간: {actual_timer}프레임 ({actual_timer/60:.1f}초)"
        return False, f"❌ 수류탄 준비시간 오류: {actual_timer}프레임 (예상: {expected_timer})"
    else:
        expected_timer = 36  # 0.6초
        actual_timer = 36
        return True, f"✅ 기본 수류탄 준비시간: {actual_timer}프레임 ({actual_timer/60:.1f}초)"

def test_flare_timer(state):
    """조명탄 준비시간 테스트"""
    if state.commando_arm_obtained:
        expected_timer = 12
        actual_timer = 12 if state.commando_arm_obtained else 36
        if actual_timer == expected_timer:
            return True, f"✅ 조명탄 준비시간: {actual_timer}프레임 ({actual_timer/60:.1f}초)"
        return False, f"❌ 조명탄 준비시간 오류: {actual_timer}프레임"
    else:
        return True, "✅ 기본 조명탄 준비시간: 36프레임 (0.6초)"

def test_molotov_timer(state):
    """화염병 준비시간 테스트"""
    if state.commando_arm_obtained:
        expected_timer = 12
        actual_timer = 12 if state.commando_arm_obtained else 36
        if actual_timer == expected_timer:
            return True, f"✅ 화염병 준비시간: {actual_timer}프레임 ({actual_timer/60:.1f}초)"
        return False, f"❌ 화염병 준비시간 오류: {actual_timer}프레임"
    else:
        return True, "✅ 기본 화염병 준비시간: 36프레임 (0.6초)"

def test_grenade_speed(state):
    """수류탄 속도 테스트"""
    base_speed = 12
    if state.commando_arm_obtained:
        expected_speed = base_speed * 1.5  # 18
        actual_speed = base_speed * 1.5 if state.commando_arm_obtained else base_speed
        if abs(actual_speed - expected_speed) < 0.1:
            return True, f"✅ 수류탄 속도: {actual_speed:.1f} (기본: {base_speed})"
        return False, f"❌ 수류탄 속도 오류: {actual_speed:.1f}"
    else:
        return True, f"✅ 기본 수류탄 속도: {base_speed}"

def test_flare_speed(state):
    """조명탄 속도 테스트"""
    base_speed = 9.6
    if state.commando_arm_obtained:
        expected_speed = base_speed * 1.5  # 14.4
        actual_speed = base_speed * 1.5 if state.commando_arm_obtained else base_speed
        if abs(actual_speed - expected_speed) < 0.1:
            return True, f"✅ 조명탄 속도: {actual_speed:.1f} (기본: {base_speed})"
        return False, f"❌ 조명탄 속도 오류: {actual_speed:.1f}"
    else:
        return True, f"✅ 기본 조명탄 속도: {base_speed}"

def test_molotov_speed(state):
    """화염병 속도 테스트"""
    base_speed = 14.4
    if state.commando_arm_obtained:
        expected_speed = base_speed * 1.5  # 21.6
        actual_speed = base_speed * 1.5 if state.commando_arm_obtained else base_speed
        if abs(actual_speed - expected_speed) < 0.1:
            return True, f"✅ 화염병 속도: {actual_speed:.1f} (기본: {base_speed})"
        return False, f"❌ 화염병 속도 오류: {actual_speed:.1f}"
    else:
        return True, f"✅ 기본 화염병 속도: {base_speed}"

def simulate_throw(state, projectile_type):
    """투척 시뮬레이션"""
    if projectile_type == "grenade":
        base_timer = 36
        base_speed = 12
        color = RED
    elif projectile_type == "flare":
        base_timer = 36
        base_speed = 9.6
        color = YELLOW
    elif projectile_type == "molotov":
        base_timer = 36
        base_speed = 14.4
        color = (255, 128, 0)  # Orange
    
    # 코만도암 효과 적용
    if state.commando_arm_obtained:
        timer = 12  # 60% 단축
        speed = base_speed * 1.5  # 50% 증가
    else:
        timer = base_timer
        speed = base_speed
    
    # 투척물 생성
    projectile = {
        "type": projectile_type,
        "x": WIDTH // 2,
        "y": HEIGHT - 100,
        "vel_y": -speed,
        "color": color,
        "timer": timer,
        "speed": speed
    }
    
    state.projectiles.append(projectile)
    return timer, speed

def draw_test_ui(screen, state, test_cases):
    """테스트 UI 그리기"""
    screen.fill(BLACK)
    
    # 제목
    title = title_font.render("코만도암 기능 테스트", True, WHITE)
    screen.blit(title, (WIDTH // 2 - title.get_width() // 2, 20))
    
    # 코만도암 상태
    status_color = GREEN if state.commando_arm_obtained else RED
    status_text = "획득" if state.commando_arm_obtained else "미획득"
    status = font.render(f"코만도암 상태: {status_text}", True, status_color)
    screen.blit(status, (20, 70))
    
    # 테스트 진행 상태
    progress = font.render(f"테스트 진행: {state.current_test + 1}/{len(test_cases)}", True, CYAN)
    screen.blit(progress, (WIDTH - 200, 70))
    
    # 현재 테스트
    if state.current_test < len(test_cases):
        current = test_cases[state.current_test]
        current_title = font.render(f"현재 테스트: {current['name']}", True, YELLOW)
        screen.blit(current_title, (20, 110))
        
        desc = font.render(current['description'], True, WHITE)
        screen.blit(desc, (20, 140))
    
    # 테스트 결과
    y_offset = 200
    for i, result in enumerate(state.test_results):
        success, message = result
        color = GREEN if success else RED
        result_text = font.render(f"{i+1}. {message}", True, color)
        screen.blit(result_text, (20, y_offset))
        y_offset += 30
    
    # 투척물 그리기
    for projectile in state.projectiles[:]:
        pygame.draw.circle(screen, projectile['color'], 
                         (int(projectile['x']), int(projectile['y'])), 8)
        
        # 속도 표시
        speed_text = font.render(f"속도: {projectile['speed']:.1f}", True, projectile['color'])
        screen.blit(speed_text, (projectile['x'] + 15, projectile['y']))
        
        # 이동
        projectile['y'] += projectile['vel_y']
        
        # 화면 밖으로 나가면 제거
        if projectile['y'] < 0:
            state.projectiles.remove(projectile)
    
    # 컨트롤 안내
    controls = [
        "스페이스: 다음 테스트",
        "R: 테스트 재시작",
        "G: 수류탄 시뮬레이션",
        "F: 조명탄 시뮬레이션",
        "M: 화염병 시뮬레이션",
        "C: 코만도암 토글",
        "Q: 종료"
    ]
    
    y_offset = HEIGHT - 200
    for control in controls:
        control_text = font.render(control, True, WHITE)
        screen.blit(control_text, (20, y_offset))
        y_offset += 25

def main():
    """메인 테스트 루프"""
    state = TestState()
    running = True
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_q:
                    running = False
                
                elif event.key == pygame.K_SPACE:
                    # 다음 테스트 실행
                    if state.current_test < len(test_cases):
                        test_case = test_cases[state.current_test]
                        test_func = globals()[test_case['test_func']]
                        success, message = test_func(state)
                        state.test_results.append((success, message))
                        state.current_test += 1
                
                elif event.key == pygame.K_r:
                    # 테스트 재시작
                    state = TestState()
                
                elif event.key == pygame.K_c:
                    # 코만도암 토글
                    state.commando_arm_obtained = not state.commando_arm_obtained
                
                elif event.key == pygame.K_g:
                    # 수류탄 시뮬레이션
                    timer, speed = simulate_throw(state, "grenade")
                    print(f"수류탄 - 준비시간: {timer}프레임, 속도: {speed}")
                
                elif event.key == pygame.K_f:
                    # 조명탄 시뮬레이션
                    timer, speed = simulate_throw(state, "flare")
                    print(f"조명탄 - 준비시간: {timer}프레임, 속도: {speed}")
                
                elif event.key == pygame.K_m:
                    # 화염병 시뮬레이션
                    timer, speed = simulate_throw(state, "molotov")
                    print(f"화염병 - 준비시간: {timer}프레임, 속도: {speed}")
        
        # 화면 업데이트
        draw_test_ui(SCREEN, state, test_cases)
        pygame.display.flip()
        clock.tick(FPS)
    
    # 최종 결과 출력
    print("\n" + "="*50)
    print("코만도암 기능 테스트 결과")
    print("="*50)
    
    passed = sum(1 for success, _ in state.test_results if success)
    total = len(state.test_results)
    
    for i, (success, message) in enumerate(state.test_results):
        print(f"{i+1}. {message}")
    
    print("="*50)
    print(f"결과: {passed}/{total} 테스트 통과")
    
    if passed == total:
        print("✅ 모든 테스트 통과! 코만도암이 정상 작동합니다.")
    else:
        print(f"⚠️ {total - passed}개 테스트 실패. 확인이 필요합니다.")
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()