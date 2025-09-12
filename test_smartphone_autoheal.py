#!/usr/bin/env python3
"""
스마트폰 자동 치유 기능 테스트
게이지가 120 이하일 때 생명수/에너지드링크 자동 사용
"""

import pygame
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from item_effects.smartphone import get_smartphone_instance

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((800, 750))
pygame.display.set_caption("스마트폰 자동 치유 테스트")
clock = pygame.time.Clock()

# 게임 상태 모의
class MockGameState:
    def __init__(self):
        self.active_items = []
        
    def get(self, key, default=None):
        if key == 'active_items':
            return self.active_items
        return default

# 메인 모듈 모의
class MockMainModule:
    def __init__(self):
        self.special_gauge = 100  # 초기 게이지
        self.special_ready = False
        self.active_item_slot = []
        self.selected_item_index = 0
        self.SOUND_DRINK = None  # 사운드는 테스트에서 제외
        
    def get_max_gauge(self):
        return 550  # 기본 최대 게이지

# 모의 모듈 설정
main_module = MockMainModule()
sys.modules['__main__'] = main_module

# 스마트폰 인스턴스 가져오기
smartphone = get_smartphone_instance()
game_state = MockGameState()

# 스마트폰 활성화
smartphone.activate(game_state, None)

# 폰트 설정
font = pygame.font.Font(None, 36)
small_font = pygame.font.Font(None, 24)

# 테스트 시나리오
test_scenarios = [
    {"gauge": 150, "items": [], "expected": "아이템 없음 - 발동 안함"},
    {"gauge": 100, "items": [{"name": "life_elixir"}], "expected": "생명수 자동 사용"},
    {"gauge": 80, "items": [{"name": "gauge_charge"}], "expected": "에너지드링크 자동 사용"},
    {"gauge": 50, "items": [{"name": "life_elixir"}, {"name": "gauge_charge"}], "expected": "생명수 우선 사용"},
    {"gauge": 120, "items": [{"name": "life_elixir"}], "expected": "게이지 120 - 자동 사용"},
    {"gauge": 121, "items": [{"name": "life_elixir"}], "expected": "게이지 121 - 발동 안함"},
]

current_scenario = 0
scenario_changed = True
frame_count = 0

running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                # 다음 시나리오로 전환
                current_scenario = (current_scenario + 1) % len(test_scenarios)
                scenario_changed = True
                frame_count = 0
                # 쿨타임 리셋
                smartphone.last_activation_time = 0
                smartphone.auto_activated = False
            elif event.key == pygame.K_r:
                # 현재 시나리오 리셋
                scenario_changed = True
                frame_count = 0
                smartphone.last_activation_time = 0
                smartphone.auto_activated = False
    
    # 현재 시나리오 설정
    if scenario_changed:
        scenario = test_scenarios[current_scenario]
        main_module.special_gauge = scenario["gauge"]
        main_module.active_item_slot = scenario["items"].copy()
        game_state.active_items = scenario["items"].copy()
        scenario_changed = False
        print(f"\n=== 시나리오 {current_scenario + 1} ===")
        print(f"게이지: {scenario['gauge']}")
        print(f"아이템: {[item.get('name') for item in scenario['items']]}")
        print(f"예상: {scenario['expected']}")
    
    # 화면 그리기
    screen.fill((30, 30, 40))
    
    # 타이틀
    title_text = font.render("스마트폰 자동 치유 테스트", True, (255, 255, 255))
    screen.blit(title_text, (200, 30))
    
    # 현재 시나리오 정보
    scenario = test_scenarios[current_scenario]
    info_text = small_font.render(f"시나리오 {current_scenario + 1}/{len(test_scenarios)}", True, (200, 200, 200))
    screen.blit(info_text, (50, 100))
    
    # 게이지 표시
    gauge_text = small_font.render(f"현재 게이지: {main_module.special_gauge}", True, (100, 255, 100))
    screen.blit(gauge_text, (50, 140))
    
    # 게이지 바
    gauge_width = 300
    gauge_height = 20
    gauge_x = 50
    gauge_y = 170
    
    # 게이지 배경
    pygame.draw.rect(screen, (50, 50, 50), (gauge_x, gauge_y, gauge_width, gauge_height))
    
    # 120 기준선 (자동 치유 발동 기준)
    threshold_x = gauge_x + (120 / 550) * gauge_width
    pygame.draw.line(screen, (255, 100, 100), (threshold_x, gauge_y - 5), (threshold_x, gauge_y + gauge_height + 5), 2)
    threshold_text = small_font.render("120", True, (255, 100, 100))
    screen.blit(threshold_text, (threshold_x - 15, gauge_y - 25))
    
    # 현재 게이지
    current_width = min((main_module.special_gauge / 550) * gauge_width, gauge_width)
    gauge_color = (255, 100, 100) if main_module.special_gauge <= 120 else (100, 255, 100)
    pygame.draw.rect(screen, gauge_color, (gauge_x, gauge_y, current_width, gauge_height))
    
    # 아이템 슬롯 표시
    items_text = small_font.render("아이템 슬롯:", True, (200, 200, 200))
    screen.blit(items_text, (50, 220))
    
    for i, item in enumerate(main_module.active_item_slot):
        if item:
            item_name = item.get('name', 'Unknown')
            item_display = {
                'life_elixir': '생명수 (500)',
                'gauge_charge': '에너지드링크 (220)',
                'stopwatch': '스탑워치',
                'aipill': 'AI알약'
            }.get(item_name, item_name)
            
            item_text = small_font.render(f"[{i+1}] {item_display}", True, (255, 255, 100))
            screen.blit(item_text, (70, 250 + i * 30))
    
    if not main_module.active_item_slot:
        no_item_text = small_font.render("(아이템 없음)", True, (100, 100, 100))
        screen.blit(no_item_text, (70, 250))
    
    # 예상 결과
    expected_text = small_font.render(f"예상: {scenario['expected']}", True, (200, 200, 255))
    screen.blit(expected_text, (50, 380))
    
    # 스마트폰 상태
    status_text = small_font.render(f"스마트폰: {'활성' if smartphone.active else '비활성'}", True, (255, 200, 100))
    screen.blit(status_text, (50, 420))
    
    cooldown_text = small_font.render(f"쿨타임: {max(0, smartphone.last_activation_time)}", True, (200, 200, 200))
    screen.blit(cooldown_text, (50, 450))
    
    # 스마트폰 update 호출 (자동 치유 체크)
    if frame_count > 30:  # 0.5초 후에 실행 (시나리오 변경 직후 바로 발동 방지)
        smartphone.update(game_state, None)
    
    # 조작 안내
    help_text1 = small_font.render("SPACE: 다음 시나리오", True, (150, 150, 150))
    screen.blit(help_text1, (50, 550))
    
    help_text2 = small_font.render("R: 현재 시나리오 리셋", True, (150, 150, 150))
    screen.blit(help_text2, (50, 580))
    
    help_text3 = small_font.render("ESC: 종료", True, (150, 150, 150))
    screen.blit(help_text3, (50, 610))
    
    # 실시간 결과 표시
    if frame_count > 30:
        result_color = (100, 255, 100)
        if len(game_state.active_items) < len(scenario["items"]):
            result_text = "✓ 아이템이 자동 사용되었습니다!"
        elif main_module.special_gauge <= 120 and not scenario["items"]:
            result_text = "✓ 아이템이 없어 발동하지 않았습니다"
        elif main_module.special_gauge > 120:
            result_text = "✓ 게이지가 충분하여 발동하지 않았습니다"
        else:
            result_text = "대기 중..."
            result_color = (200, 200, 200)
        
        result_display = small_font.render(result_text, True, result_color)
        screen.blit(result_display, (50, 500))
    
    pygame.display.flip()
    clock.tick(60)
    frame_count += 1
    
    # ESC로 종료
    keys = pygame.key.get_pressed()
    if keys[pygame.K_ESCAPE]:
        running = False

pygame.quit()
print("\n테스트 종료")