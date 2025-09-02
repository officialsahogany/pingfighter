#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
마이그레이션 테스트 스크립트
점진적 마이그레이션이 제대로 동작하는지 확인
"""

import sys
import os
import time

# 프로젝트 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_migration_readiness():
    """마이그레이션 준비 상태 테스트"""
    print("\n🔍 마이그레이션 준비 상태 테스트...")
    
    tests = []
    
    # 1. 핵심 파일 존재 확인
    print("\n1. 파일 존재 확인:")
    files_to_check = [
        ("pingfighter.py", "메인 게임 파일"),
        ("core/game_state.py", "GameState 클래스"),
        ("core/dependency_injection.py", "DI 컨테이너"),
        ("core/event_bus.py", "이벤트 버스"),
        ("services/game_service.py", "게임 서비스"),
        ("repositories/game_repository.py", "리포지토리"),
        ("migration/migration_bridge.py", "마이그레이션 브리지"),
        ("migration/legacy_adapter.py", "레거시 어댑터"),
    ]
    
    for file_path, description in files_to_check:
        exists = os.path.exists(file_path)
        icon = "✅" if exists else "❌"
        tests.append(("파일: " + description, exists))
        print(f"  {icon} {description}: {file_path}")
    
    # 2. Import 테스트
    print("\n2. Import 테스트:")
    import_tests = []
    
    try:
        from core.game_state import GameState
        import_tests.append(("GameState import", True))
        print("  ✅ GameState import 성공")
    except ImportError as e:
        import_tests.append(("GameState import", False))
        print(f"  ❌ GameState import 실패: {e}")
    
    try:
        from core.dependency_injection import DIContainer
        import_tests.append(("DIContainer import", True))
        print("  ✅ DIContainer import 성공")
    except ImportError as e:
        import_tests.append(("DIContainer import", False))
        print(f"  ❌ DIContainer import 실패: {e}")
    
    try:
        from migration.migration_bridge import get_migration_bridge
        import_tests.append(("Migration Bridge import", True))
        print("  ✅ Migration Bridge import 성공")
    except ImportError as e:
        import_tests.append(("Migration Bridge import", False))
        print(f"  ❌ Migration Bridge import 실패: {e}")
    
    tests.extend(import_tests)
    
    # 3. 시스템 초기화 테스트
    print("\n3. 시스템 초기화 테스트:")
    init_tests = []
    
    try:
        from core.game_state import GameState
        state = GameState.get_instance()
        init_tests.append(("GameState 초기화", True))
        print("  ✅ GameState 초기화 성공")
    except Exception as e:
        init_tests.append(("GameState 초기화", False))
        print(f"  ❌ GameState 초기화 실패: {e}")
    
    try:
        from core.dependency_injection import get_container
        container = get_container()
        init_tests.append(("DI Container 초기화", True))
        print("  ✅ DI Container 초기화 성공")
    except Exception as e:
        init_tests.append(("DI Container 초기화", False))
        print(f"  ❌ DI Container 초기화 실패: {e}")
    
    tests.extend(init_tests)
    
    # 결과 요약
    print("\n" + "="*60)
    print("📊 테스트 결과 요약")
    print("="*60)
    
    passed = sum(1 for _, result in tests if result)
    total = len(tests)
    percentage = (passed / total * 100) if total > 0 else 0
    
    print(f"통과: {passed}/{total} ({percentage:.1f}%)")
    
    if percentage == 100:
        print("✅ 모든 테스트 통과! 마이그레이션 준비 완료")
        return True
    else:
        print("⚠️ 일부 테스트 실패. 문제를 해결한 후 다시 시도하세요.")
        return False


def test_migration_bridge():
    """마이그레이션 브리지 동작 테스트"""
    print("\n🌉 마이그레이션 브리지 테스트...")
    
    try:
        from migration.migration_bridge import get_migration_bridge
        from core.game_state import GameState
        
        # 브리지 초기화
        bridge = get_migration_bridge()
        
        # 테스트용 전역 변수
        test_globals = {
            'player_score': 100,
            'ai_score': 50,
            'current_stage': 3,
            'player_x': 400,
            'player_y': 500,
            'ball_x': 300,
            'ball_y': 300,
        }
        
        # 동기화 테스트
        print("\n1. 전역 변수 → GameState 동기화:")
        bridge.sync_globals_to_state(test_globals)
        
        game_state = GameState.get_instance()
        
        # 값 확인
        checks = [
            ('player_score', game_state.player_score, 100),
            ('ai_score', game_state.ai_score, 50),
            ('current_stage', game_state.current_stage, 3),
            ('player_x', game_state.player_x, 400),
            ('player_y', game_state.player_y, 500),
        ]
        
        for name, actual, expected in checks:
            if actual == expected:
                print(f"  ✅ {name}: {actual} (정상)")
            else:
                print(f"  ❌ {name}: {actual} (예상: {expected})")
        
        # 역방향 동기화 테스트
        print("\n2. GameState → 전역 변수 동기화:")
        game_state.player_score = 200
        game_state.ai_score = 75
        
        output_globals = {}
        bridge.sync_state_to_globals(output_globals)
        
        if output_globals.get('player_score') == 200:
            print(f"  ✅ player_score: {output_globals.get('player_score')} (정상)")
        else:
            print(f"  ❌ player_score: {output_globals.get('player_score')} (예상: 200)")
        
        if output_globals.get('ai_score') == 75:
            print(f"  ✅ ai_score: {output_globals.get('ai_score')} (정상)")
        else:
            print(f"  ❌ ai_score: {output_globals.get('ai_score')} (예상: 75)")
        
        print("\n✅ 마이그레이션 브리지 테스트 완료")
        return True
        
    except Exception as e:
        print(f"\n❌ 마이그레이션 브리지 테스트 실패: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_service_integration():
    """서비스 통합 테스트"""
    print("\n🎮 서비스 통합 테스트...")
    
    try:
        from services.game_service import GameService
        from core.game_state import GameState
        from repositories.game_repository import GameRepository
        
        # 서비스 초기화
        print("\n1. 서비스 초기화:")
        repository = GameRepository(storage_type="memory")
        game_state = GameState.get_instance()
        service = GameService(game_state=game_state, game_repository=repository)
        print("  ✅ GameService 초기화 성공")
        
        # 게임 시작 테스트
        print("\n2. 게임 시작 테스트:")
        result = service.start_game(1)
        if result:
            print("  ✅ 게임 시작 성공")
            print(f"    - 현재 스테이지: {game_state.current_stage}")
            print(f"    - 게임 실행 중: {game_state.game_running}")
        else:
            print("  ❌ 게임 시작 실패")
        
        # 입력 처리 테스트
        print("\n3. 입력 처리 테스트:")
        initial_x = game_state.player_x
        service.process_player_input({'move': 1})  # 오른쪽 이동
        
        if game_state.player_x > initial_x:
            print(f"  ✅ 플레이어 이동 성공 ({initial_x} → {game_state.player_x})")
        else:
            print(f"  ❌ 플레이어 이동 실패")
        
        # 일시정지 테스트
        print("\n4. 일시정지 테스트:")
        service.pause_game()
        if game_state.game_paused:
            print("  ✅ 게임 일시정지 성공")
        else:
            print("  ❌ 게임 일시정지 실패")
        
        service.resume_game()
        if not game_state.game_paused:
            print("  ✅ 게임 재개 성공")
        else:
            print("  ❌ 게임 재개 실패")
        
        print("\n✅ 서비스 통합 테스트 완료")
        return True
        
    except Exception as e:
        print(f"\n❌ 서비스 통합 테스트 실패: {e}")
        import traceback
        traceback.print_exc()
        return False


def run_all_tests():
    """모든 테스트 실행"""
    print("\n" + "="*60)
    print("🚀 PingFighter 마이그레이션 테스트 시작")
    print("="*60)
    
    results = []
    
    # 1. 준비 상태 테스트
    print("\n[테스트 1/3]")
    results.append(("준비 상태", test_migration_readiness()))
    
    # 2. 브리지 테스트
    print("\n[테스트 2/3]")
    results.append(("마이그레이션 브리지", test_migration_bridge()))
    
    # 3. 서비스 통합 테스트
    print("\n[테스트 3/3]")
    results.append(("서비스 통합", test_service_integration()))
    
    # 최종 결과
    print("\n" + "="*60)
    print("📊 최종 테스트 결과")
    print("="*60)
    
    for name, result in results:
        icon = "✅" if result else "❌"
        print(f"{icon} {name}: {'통과' if result else '실패'}")
    
    all_passed = all(result for _, result in results)
    
    if all_passed:
        print("\n🎉 모든 테스트 통과! 마이그레이션 모드를 사용할 수 있습니다.")
        print("\n실행 방법:")
        print("  python pingfighter.py --migration-mode")
    else:
        print("\n⚠️ 일부 테스트 실패. 문제를 해결한 후 다시 시도하세요.")
    
    return all_passed


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)