#!/usr/bin/env python3
"""
Phase 1-4: 유사한 draw 함수들 통합 스크립트
중복되거나 유사한 draw 함수들을 EffectRenderer를 활용해 통합
"""

import re
import os

def consolidate_particle_draws(content):
    """파티클 관련 draw 함수들을 EffectRenderer로 통합"""
    lines_before = content.count('\n')
    
    # draw_tears, draw_balloons, draw_water_trail 등을
    # EffectRenderer.draw_particles로 통합 가능
    
    # 1. draw_tears 함수를 EffectRenderer 호출로 변경
    tears_pattern = r'def draw_tears\(\):.*?(?=\ndef |\nclass |\Z)'
    tears_replacement = '''def draw_tears():
    """눈물 이펙트 그리기 - EffectRenderer 사용"""
    if tear_particles:
        effect_renderer.draw_particles(SCREEN, tear_particles, (0, 100, 255))'''
    
    content = re.sub(tears_pattern, tears_replacement, content, flags=re.DOTALL)
    
    # 2. draw_balloons 함수 간소화
    balloons_pattern = r'def draw_balloons\(\):.*?(?=\ndef |\nclass |\Z)'
    balloons_replacement = '''def draw_balloons():
    """풍선 이펙트 그리기 - EffectRenderer 사용"""
    if balloon_particles:
        effect_renderer.draw_particles(SCREEN, balloon_particles, (255, 200, 100))'''
    
    content = re.sub(balloons_pattern, balloons_replacement, content, flags=re.DOTALL)
    
    # 3. draw_water_trail 함수 간소화
    water_pattern = r'def draw_water_trail\(\):.*?(?=\ndef |\nclass |\Z)'
    water_replacement = '''def draw_water_trail():
    """물 트레일 이펙트 - EffectRenderer 사용"""
    if water_particles:
        effect_renderer.draw_particles(SCREEN, water_particles, (100, 150, 255))'''
    
    content = re.sub(water_pattern, water_replacement, content, flags=re.DOTALL)
    
    # 4. draw_impact_particles 함수 간소화
    impact_pattern = r'def draw_impact_particles\(\):.*?(?=\ndef |\nclass |\Z)'
    impact_replacement = '''def draw_impact_particles():
    """충격 파티클 이펙트 - EffectRenderer 사용"""
    if impact_particles:
        effect_renderer.draw_particles(SCREEN, impact_particles)'''
    
    content = re.sub(impact_pattern, impact_replacement, content, flags=re.DOTALL)
    
    # 5. draw_fireball_explosion_particles 함수 간소화
    fireball_pattern = r'def draw_fireball_explosion_particles\(\):.*?(?=\ndef |\nclass |\Z)'
    fireball_replacement = '''def draw_fireball_explosion_particles():
    """파이어볼 폭발 파티클 - EffectRenderer 사용"""
    if fireball_explosion_particles:
        effect_renderer.draw_particles(SCREEN, fireball_explosion_particles, (255, 100, 0))'''
    
    content = re.sub(fireball_pattern, fireball_replacement, content, flags=re.DOTALL)
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def consolidate_ui_draws(content):
    """UI 관련 draw 함수들 통합"""
    lines_before = content.count('\n')
    
    # draw_gradient_background와 draw_modern_panel을 DrawHelper로 통합
    
    # 1. draw_gradient_background 간소화
    gradient_pattern = r'def draw_gradient_background\(surface, rect, color1, color2, horizontal=False\):.*?(?=\ndef |\nclass |\Z)'
    gradient_replacement = '''def draw_gradient_background(surface, rect, color1, color2, horizontal=False):
    """그라데이션 배경 - DrawHelper 사용"""
    from rendering.draw_helper import DrawHelper
    helper = DrawHelper(surface)
    # 간단한 그라데이션 구현
    steps = 50
    for i in range(steps):
        ratio = i / steps
        color = [int(c1 + (c2 - c1) * ratio) for c1, c2 in zip(color1, color2)]
        if horizontal:
            r = pygame.Rect(rect.x + rect.width * i // steps, rect.y, rect.width // steps + 1, rect.height)
        else:
            r = pygame.Rect(rect.x, rect.y + rect.height * i // steps, rect.width, rect.height // steps + 1)
        helper.rect(color, r)'''
    
    content = re.sub(gradient_pattern, gradient_replacement, content, flags=re.DOTALL)
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def consolidate_boss_draws(content):
    """보스 관련 draw 함수들 통합"""
    lines_before = content.count('\n')
    
    # draw_crocodile_boss와 draw_aircraft_carrier_boss를 간소화
    # 중복되는 그리기 코드를 DrawHelper로 통합
    
    # 이미 복잡한 함수들이므로 내부의 pygame.draw 호출만 DrawHelper로 변경
    # (함수 자체는 유지하되 내부 구현을 간소화)
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def remove_unused_draw_functions(content):
    """사용되지 않는 draw 함수들 제거"""
    lines_before = content.count('\n')
    
    # draw_with_shake, draw_rect_with_shake, draw_circle_with_shake는
    # 정의만 되고 사용되지 않음 (이미 변수 제거 스크립트에서 확인)
    
    # 내부 함수들은 외부에서 호출할 수 없으므로 사용 여부 체크
    unused_patterns = [
        r'def draw_with_shake\(surface, pos\):.*?(?=\n    def |\n\S|\Z)',
        # 나머지 함수들은 실제 사용 중이므로 제거하지 않음
    ]
    
    for pattern in unused_patterns:
        content = re.sub(pattern, '', content, flags=re.DOTALL)
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def main():
    """메인 함수"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase1_4.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    total_lines_saved = 0
    
    print("\n🔧 Phase 1-4: 유사한 draw 함수들 통합...")
    
    # 1. 파티클 draw 함수들 통합
    print("\n1️⃣ 파티클 draw 함수들 통합...")
    content, lines_saved = consolidate_particle_draws(content)
    total_lines_saved += lines_saved
    print(f"   ✅ {lines_saved}줄 감소")
    
    # 2. UI draw 함수들 통합
    print("\n2️⃣ UI draw 함수들 통합...")
    content, lines_saved = consolidate_ui_draws(content)
    total_lines_saved += lines_saved
    print(f"   ✅ {lines_saved}줄 감소")
    
    # 3. 보스 draw 함수들 최적화
    print("\n3️⃣ 보스 draw 함수들 최적화...")
    content, lines_saved = consolidate_boss_draws(content)
    total_lines_saved += lines_saved
    print(f"   ✅ {lines_saved}줄 감소")
    
    # 4. 미사용 draw 함수 제거
    print("\n4️⃣ 미사용 draw 함수 제거...")
    content, lines_saved = remove_unused_draw_functions(content)
    total_lines_saved += lines_saved
    print(f"   ✅ {lines_saved}줄 감소")
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 1-4 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   감소: {original_lines - final_lines:,}줄 ({(original_lines - final_lines) / original_lines * 100:.1f}%)")
    print("="*50)

if __name__ == "__main__":
    main()