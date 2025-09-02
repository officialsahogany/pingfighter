#!/usr/bin/env python3
"""
BossPong 성능 분석 도구
병목 지점 찾기 및 최적화 기회 탐색
"""

import cProfile
import pstats
import io
import pygame
import sys
from contextlib import contextmanager
import time

@contextmanager
def profile_section(name):
    """특정 섹션 프로파일링"""
    start = time.perf_counter()
    yield
    end = time.perf_counter()
    print(f"  {name}: {(end - start) * 1000:.2f}ms")

def analyze_imports():
    """임포트 시간 분석"""
    print("\n=== 임포트 시간 분석 ===")
    
    with profile_section("pygame 초기화"):
        pygame.init()
    
    with profile_section("core 모듈"):
        from core.global_manager import GlobalManager
        from core.events import EventManager
    
    with profile_section("managers 모듈"):
        from managers.sound_manager import get_sound_manager
        from managers.effects_manager import get_effects_manager
    
    with profile_section("game_logic 모듈"):
        from game_logic.round_manager import get_round_manager
        from game_logic.stage_features import get_stage_features
    
    with profile_section("ai 모듈"):
        from ai.boss_ai import BossAI
        from ai.boss_skills import get_boss_skill_manager
    
    pygame.quit()

def profile_game_loop():
    """게임 루프 프로파일링"""
    print("\n=== 게임 루프 프로파일링 ===")
    
    pygame.init()
    
    from bosspong import BossPongGame
    
    # 프로파일러 설정
    pr = cProfile.Profile()
    
    # 게임 인스턴스
    game = BossPongGame()
    
    # 짧은 게임 루프 실행 (100 프레임)
    pr.enable()
    
    clock = pygame.time.Clock()
    for i in range(100):
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                break
        
        # 간단한 업데이트 시뮬레이션
        dt = clock.tick(60) / 1000.0
        
        # 화면 클리어 및 플립
        game.screen.fill((0, 0, 0))
        pygame.display.flip()
    
    pr.disable()
    
    # 통계 출력
    s = io.StringIO()
    ps = pstats.Stats(pr, stream=s).sort_stats('cumulative')
    ps.print_stats(20)  # 상위 20개 함수
    
    print(s.getvalue())
    
    pygame.quit()

def find_bottlenecks():
    """병목 지점 찾기"""
    print("\n=== 병목 지점 분석 ===")
    
    pygame.init()
    
    # 각 주요 시스템의 초기화 시간 측정
    timings = {}
    
    with profile_section("GlobalManager"):
        from core.global_manager import GlobalManager
        gm = GlobalManager.get_instance()
        gm.init_pygame_objects()
    
    with profile_section("EventManager"):
        from core.events import EventManager
        em = EventManager.get_instance()
    
    with profile_section("SoundManager"):
        from managers.sound_manager import get_sound_manager
        sm = get_sound_manager()
    
    with profile_section("EffectsManager"):
        from managers.effects_manager import get_effects_manager
        efm = get_effects_manager()
    
    with profile_section("RoundManager"):
        from game_logic.round_manager import get_round_manager
        rm = get_round_manager()
    
    with profile_section("StageFeatures"):
        from game_logic.stage_features import get_stage_features
        sf = get_stage_features()
    
    with profile_section("BossAI"):
        from ai.boss_ai import BossAI
        ai = BossAI()
    
    pygame.quit()

def check_memory_leaks():
    """메모리 누수 체크"""
    print("\n=== 메모리 사용량 분석 ===")
    
    import psutil
    import gc
    
    process = psutil.Process()
    
    # 초기 메모리
    gc.collect()
    initial = process.memory_info().rss / 1024 / 1024
    print(f"초기 메모리: {initial:.2f} MB")
    
    # 게임 생성 및 삭제 반복
    pygame.init()
    
    for i in range(5):
        from bosspong import BossPongGame
        game = BossPongGame()
        del game
        gc.collect()
        
        current = process.memory_info().rss / 1024 / 1024
        print(f"  반복 {i+1}: {current:.2f} MB (증가: {current - initial:.2f} MB)")
    
    pygame.quit()
    
    # 최종 메모리
    gc.collect()
    final = process.memory_info().rss / 1024 / 1024
    print(f"최종 메모리: {final:.2f} MB")
    print(f"총 증가량: {final - initial:.2f} MB")
    
    if final - initial > 10:
        print("⚠️  메모리 누수 가능성 있음")
    else:
        print("✅ 메모리 관리 양호")

def optimization_suggestions():
    """최적화 제안"""
    print("\n=== 최적화 제안 ===")
    
    suggestions = [
        "1. 지연 로딩: 사용하지 않는 모듈은 필요할 때 로드",
        "2. 캐싱: 자주 사용하는 계산 결과 캐싱",
        "3. 오브젝트 풀링: 엔티티 재사용으로 GC 부담 감소",
        "4. 이벤트 배칭: 여러 이벤트를 모아서 처리",
        "5. 렌더링 최적화: 변경된 부분만 다시 그리기",
        "6. 리소스 압축: 이미지/사운드 파일 최적화",
        "7. 프로파일 기반 최적화: 실제 병목 지점에 집중"
    ]
    
    for suggestion in suggestions:
        print(f"  {suggestion}")
    
    print("\n현재 구조 평가:")
    print("  ✅ 모듈화로 유지보수성 극대화")
    print("  ✅ 싱글톤 패턴으로 메모리 효율성")
    print("  ✅ 이벤트 시스템으로 느슨한 결합")
    print("  ⚠️  일부 순환 임포트 가능성")
    print("  ⚠️  초기 로딩 시간 개선 여지")

def main():
    """메인 실행"""
    print("=" * 60)
    print("BossPong 성능 분석")
    print("=" * 60)
    
    try:
        analyze_imports()
        find_bottlenecks()
        check_memory_leaks()
        # profile_game_loop()  # 시간이 오래 걸림
        optimization_suggestions()
        
        print("\n" + "=" * 60)
        print("분석 완료")
        print("=" * 60)
        
    except Exception as e:
        print(f"\n❌ 오류 발생: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()