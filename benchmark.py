#!/usr/bin/env python3
"""
BossPong 성능 벤치마크 스크립트
레거시와 모듈화 버전의 성능 비교
"""

import time
import psutil
import os
import sys
import gc
from pathlib import Path

def measure_import_time():
    """모듈 임포트 시간 측정"""
    print("\n=== 임포트 시간 측정 ===")
    
    # 모듈화 버전 임포트
    start = time.perf_counter()
    import bosspong
    modular_time = time.perf_counter() - start
    
    print(f"모듈화 버전: {modular_time:.3f}초")
    
    # 메모리 정리
    del sys.modules['bosspong']
    gc.collect()
    
    return modular_time

def measure_memory_usage():
    """메모리 사용량 측정"""
    print("\n=== 메모리 사용량 측정 ===")
    
    process = psutil.Process(os.getpid())
    
    # 초기 메모리
    initial_memory = process.memory_info().rss / 1024 / 1024  # MB
    
    # 모듈 임포트
    import bosspong
    
    # 임포트 후 메모리
    after_import = process.memory_info().rss / 1024 / 1024  # MB
    
    print(f"초기 메모리: {initial_memory:.2f} MB")
    print(f"임포트 후: {after_import:.2f} MB")
    print(f"증가량: {after_import - initial_memory:.2f} MB")
    
    return after_import - initial_memory

def measure_startup_time():
    """게임 초기화 시간 측정"""
    print("\n=== 초기화 시간 측정 ===")
    
    import pygame
    pygame.init()
    
    start = time.perf_counter()
    
    # 주요 매니저 초기화
    from core.global_manager import GlobalManager
    from core.events import EventManager
    from managers.sound_manager import get_sound_manager
    from managers.effects_manager import get_effects_manager
    from game_logic.round_manager import get_round_manager
    from game_logic.stage_features import get_stage_features
    from ai.boss_ai import BossAI
    
    # 싱글톤 인스턴스 생성
    global_manager = GlobalManager.get_instance()
    event_manager = EventManager.get_instance()
    sound_manager = get_sound_manager()
    effects_manager = get_effects_manager()
    round_manager = get_round_manager()
    stage_features = get_stage_features()
    boss_ai = BossAI()
    
    init_time = time.perf_counter() - start
    
    print(f"초기화 시간: {init_time:.3f}초")
    
    pygame.quit()
    
    return init_time

def count_code_metrics():
    """코드 메트릭스 계산"""
    print("\n=== 코드 메트릭스 ===")
    
    # 모듈 파일 수 계산
    module_dirs = ['core', 'game_logic', 'entities', 'ai', 'managers', 'network', 'ui', 'config']
    total_files = 0
    total_lines = 0
    
    for dir_name in module_dirs:
        dir_path = Path(dir_name)
        if dir_path.exists():
            py_files = list(dir_path.glob('*.py'))
            total_files += len(py_files)
            
            for py_file in py_files:
                with open(py_file, 'r', encoding='utf-8') as f:
                    lines = len(f.readlines())
                    total_lines += lines
    
    # 메인 파일
    if Path('bosspong.py').exists():
        with open('bosspong.py', 'r', encoding='utf-8') as f:
            main_lines = len(f.readlines())
            total_lines += main_lines
            total_files += 1
            print(f"메인 파일: bosspong.py ({main_lines} 줄)")
    
    print(f"총 모듈 수: {len(module_dirs)}")
    print(f"총 파일 수: {total_files}")
    print(f"총 코드 줄: {total_lines:,}")
    
    # 레거시 파일 크기 (참고용)
    legacy_lines = 22275
    reduction = (1 - total_lines / legacy_lines) * 100
    print(f"\n레거시 대비:")
    print(f"  - 원본: {legacy_lines:,} 줄")
    print(f"  - 현재: {total_lines:,} 줄")
    print(f"  - 감소율: {reduction:.1f}%")
    
    return total_files, total_lines

def run_benchmark():
    """전체 벤치마크 실행"""
    print("=" * 50)
    print("BossPong 성능 벤치마크")
    print("=" * 50)
    
    results = {}
    
    # 코드 메트릭스
    files, lines = count_code_metrics()
    results['files'] = files
    results['lines'] = lines
    
    # 임포트 시간
    import_time = measure_import_time()
    results['import_time'] = import_time
    
    # 메모리 사용량
    memory_increase = measure_memory_usage()
    results['memory'] = memory_increase
    
    # 초기화 시간
    init_time = measure_startup_time()
    results['init_time'] = init_time
    
    # 결과 요약
    print("\n" + "=" * 50)
    print("벤치마크 결과 요약")
    print("=" * 50)
    print(f"📁 파일 수: {results['files']}")
    print(f"📝 코드 줄: {results['lines']:,}")
    print(f"⏱️  임포트: {results['import_time']:.3f}초")
    print(f"💾 메모리: +{results['memory']:.2f} MB")
    print(f"🚀 초기화: {results['init_time']:.3f}초")
    
    # 성능 등급
    print("\n성능 평가:")
    if results['import_time'] < 0.5 and results['init_time'] < 1.0:
        print("⭐⭐⭐⭐⭐ 우수")
    elif results['import_time'] < 1.0 and results['init_time'] < 2.0:
        print("⭐⭐⭐⭐ 양호")
    else:
        print("⭐⭐⭐ 보통")
    
    return results

if __name__ == "__main__":
    try:
        results = run_benchmark()
    except Exception as e:
        print(f"\n❌ 벤치마크 실행 중 오류: {e}")
        import traceback
        traceback.print_exc()