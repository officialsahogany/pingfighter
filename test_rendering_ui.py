#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
렌더링 및 UI 시스템 테스트
화면 그리기와 UI 요소 테스트
"""

import sys
import os
import pygame
import time

# 프로젝트 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from rendering.render_system import RenderSystem, RenderLayer, RenderObject, BlendMode
from ui.ui_system import UISystem, Button, Label, ProgressBar, UIStyle


def test_render_system():
    """렌더링 시스템 테스트"""
    print("\n🎨 렌더링 시스템 테스트...")
    
    # 화면 생성
    screen = pygame.display.set_mode((600, 400))
    pygame.display.set_caption("Render System Test")
    
    # 렌더링 시스템 초기화
    render_system = RenderSystem(screen)
    
    print("  ✅ 렌더링 시스템 초기화 성공")
    
    # 파티클 효과 테스트
    print("\n1. 파티클 효과 테스트:")
    
    # 폭발 효과 생성
    render_system.create_explosion((300, 200), count=20)
    if len(render_system.particles) > 0:
        print(f"  ✅ 폭발 효과 생성: {len(render_system.particles)}개 파티클")
    else:
        print("  ❌ 폭발 효과 생성 실패")
    
    # 궤적 효과 생성
    render_system.create_trail((200, 200), (1, 0))
    print("  ✅ 궤적 효과 생성")
    
    # 카메라 효과 테스트
    print("\n2. 카메라 효과 테스트:")
    render_system.shake_camera(intensity=5, duration=0.5)
    print("  ✅ 카메라 흔들기 시작")
    
    render_system.flash_screen(color=(255, 255, 255), duration=0.2)
    print("  ✅ 화면 플래시 효과")
    
    # 렌더링 객체 추가 테스트
    print("\n3. 렌더링 객체 테스트:")
    
    def draw_test_circle(screen, pos):
        pygame.draw.circle(screen, (255, 0, 0), (int(pos[0]), int(pos[1])), 20)
    
    test_obj = RenderObject(
        layer=RenderLayer.ENTITIES,
        position=(100, 100),
        draw_func=draw_test_circle,
        z_order=1
    )
    
    render_system.add_render_object(test_obj)
    print("  ✅ 렌더링 객체 추가")
    
    # 업데이트 테스트
    print("\n4. 업데이트 사이클 테스트:")
    dt = 0.016  # 60 FPS
    
    for _ in range(5):
        render_system.update(dt)
    
    print("  ✅ 업데이트 사이클 정상 작동")
    
    # 리셋 테스트
    render_system.reset()
    if len(render_system.particles) == 0:
        print("  ✅ 시스템 리셋 성공")
    
    return True


def test_ui_system():
    """UI 시스템 테스트"""
    print("\n🎮 UI 시스템 테스트...")
    
    # UI 시스템 초기화
    ui_system = UISystem()
    
    print("  ✅ UI 시스템 초기화 성공")
    
    # 버튼 생성 테스트
    print("\n1. UI 요소 생성 테스트:")
    
    # 버튼 생성
    button = Button(
        id="test_button",
        text="Test Button",
        position=(100, 100),
        size=(150, 50)
    )
    
    def on_button_click(btn):
        print(f"    버튼 클릭됨: {btn.id}")
    
    button.on_click = on_button_click
    ui_system.add_element(button)
    
    if ui_system.get_element("test_button"):
        print("  ✅ 버튼 생성 및 추가 성공")
    else:
        print("  ❌ 버튼 생성 실패")
    
    # 라벨 생성
    label = Label(
        id="test_label",
        text="Test Label",
        position=(100, 200)
    )
    ui_system.add_element(label)
    print("  ✅ 라벨 생성 및 추가")
    
    # 진행률 바 생성
    progress_bar = ProgressBar(
        id="test_progress",
        position=(100, 250),
        size=(200, 30),
        max_value=100
    )
    progress_bar.set_value(75)
    ui_system.add_element(progress_bar)
    print("  ✅ 진행률 바 생성 (75%)")
    
    # HUD 생성 테스트
    print("\n2. HUD 생성 테스트:")
    hud = ui_system.create_hud()
    ui_system.add_element(hud)
    
    if ui_system.get_element("hud"):
        print("  ✅ HUD 생성 성공")
        if ui_system.get_element("score_label"):
            print("    - 점수 라벨 포함")
        if ui_system.get_element("hp_bar"):
            print("    - HP 바 포함")
    
    # 이벤트 처리 테스트
    print("\n3. 이벤트 처리 테스트:")
    
    # 가상 마우스 이벤트 생성
    test_event = pygame.event.Event(
        pygame.MOUSEMOTION,
        {'pos': (150, 125)}  # 버튼 위치
    )
    
    handled = ui_system.handle_event(test_event)
    if handled:
        print("  ✅ 마우스 호버 이벤트 처리")
    
    # 애니메이션 테스트
    print("\n4. 애니메이션 테스트:")
    ui_system.animate(
        button,
        'position',
        (200, 100),
        duration=1.0,
        easing='ease_out'
    )
    
    if len(ui_system.animations) > 0:
        print("  ✅ 애니메이션 시작")
    
    # 업데이트 테스트
    dt = 0.016
    for _ in range(5):
        ui_system.update(dt)
    
    print("  ✅ 업데이트 사이클 정상 작동")
    
    # 리셋 테스트
    ui_system.reset()
    if len(ui_system.elements) == 0:
        print("  ✅ 시스템 리셋 성공")
    
    return True


def test_integration():
    """렌더링-UI 통합 테스트"""
    print("\n🔗 렌더링-UI 통합 테스트...")
    
    # 화면 생성
    screen = pygame.display.set_mode((600, 400))
    clock = pygame.time.Clock()
    
    # 시스템 초기화
    render_system = RenderSystem(screen)
    ui_system = UISystem()
    
    # UI 요소 생성
    button = Button(
        id="play_button",
        text="Play",
        position=(250, 175),
        size=(100, 50)
    )
    ui_system.add_element(button)
    
    print("  ✅ 통합 시스템 초기화")
    
    # 렌더링 루프 테스트 (짧은 시간)
    print("\n렌더링 루프 테스트:")
    running = True
    frames = 0
    max_frames = 10
    
    while running and frames < max_frames:
        dt = clock.tick(60) / 1000.0
        
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            ui_system.handle_event(event)
        
        # 업데이트
        render_system.update(dt)
        ui_system.update(dt)
        
        # 렌더링
        render_system.clear()
        render_system.render()
        ui_system.draw(screen)
        
        pygame.display.flip()
        frames += 1
    
    print(f"  ✅ {frames}프레임 렌더링 완료")
    
    return True


def run_all_tests():
    """모든 테스트 실행"""
    print("\n" + "="*60)
    print("🎨 렌더링 및 UI 시스템 종합 테스트")
    print("="*60)
    
    pygame.init()
    
    results = []
    
    # 1. 렌더링 시스템 테스트
    results.append(("렌더링 시스템", test_render_system()))
    
    # 2. UI 시스템 테스트
    results.append(("UI 시스템", test_ui_system()))
    
    # 3. 통합 테스트
    results.append(("렌더링-UI 통합", test_integration()))
    
    # 결과 출력
    print("\n" + "="*60)
    print("📊 테스트 결과")
    print("="*60)
    
    for name, result in results:
        icon = "✅" if result else "❌"
        print(f"{icon} {name}: {'통과' if result else '실패'}")
    
    all_passed = all(result for _, result in results)
    
    if all_passed:
        print("\n🎉 모든 렌더링/UI 테스트 통과!")
    else:
        print("\n⚠️ 일부 테스트 실패")
    
    pygame.quit()
    return all_passed


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)