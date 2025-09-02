#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PingFighter 점진적 마이그레이션 실행 스크립트
기존 코드를 유지하면서 새 아키텍처로 점진적 전환
"""

import sys
import os
import importlib
import pygame

# 프로젝트 경로 설정
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from migration.legacy_adapter import IncrementalMigrator, MigrationPlan
from migration.migration_bridge import get_migration_bridge, init_migration
from core.dependency_injection import get_container


def check_migration_readiness():
    """마이그레이션 준비 상태 확인"""
    print("\n🔍 마이그레이션 준비 상태 확인 중...")
    
    checks = {
        "pingfighter.py 존재": os.path.exists("pingfighter.py"),
        "새 아키텍처 모듈": all([
            os.path.exists("core/game_state.py"),
            os.path.exists("core/dependency_injection.py"),
            os.path.exists("core/event_bus.py"),
            os.path.exists("services/game_service.py"),
            os.path.exists("repositories/game_repository.py")
        ]),
        "마이그레이션 도구": all([
            os.path.exists("migration/migration_bridge.py"),
            os.path.exists("migration/legacy_adapter.py")
        ])
    }
    
    all_ready = all(checks.values())
    
    print("\n체크리스트:")
    for item, status in checks.items():
        icon = "✅" if status else "❌"
        print(f"  {icon} {item}")
    
    return all_ready


def run_migration_phase1():
    """Phase 1: 기본 시스템 연결"""
    print("\n" + "="*60)
    print("🚀 Phase 1: 기본 시스템 연결")
    print("="*60)
    
    # pingfighter 모듈 동적 로드
    try:
        # 기존 pingfighter를 모듈로 임포트
        spec = importlib.util.spec_from_file_location("pingfighter_legacy", "pingfighter.py")
        legacy_module = importlib.util.module_from_spec(spec)
        
        # 모듈 실행 전 마이그레이션 설정
        print("\n1️⃣ 마이그레이션 브리지 초기화...")
        bridge = get_migration_bridge()
        
        print("2️⃣ DI 컨테이너 설정...")
        container = get_container()
        
        print("3️⃣ 레거시 어댑터 설정...")
        migrator = IncrementalMigrator(legacy_module)
        
        # 전역 변수 캡처를 위한 프록시 설정
        original_globals = {}
        
        def capture_globals():
            """전역 변수 캡처"""
            for name, value in vars(legacy_module).items():
                if not name.startswith('__') and not callable(value):
                    original_globals[name] = value
        
        print("4️⃣ 전역 변수 마이그레이션...")
        # 모듈 로드 (전역 변수 생성)
        spec.loader.exec_module(legacy_module)
        capture_globals()
        
        # 마이그레이션 실행
        bridge.sync_globals_to_state(original_globals)
        migrator._migrate_global_variables()
        
        print("\n✅ Phase 1 완료!")
        return migrator, bridge
        
    except Exception as e:
        print(f"\n❌ Phase 1 실패: {e}")
        import traceback
        traceback.print_exc()
        return None, None


def run_migration_phase2(migrator, bridge):
    """Phase 2: 함수 마이그레이션"""
    print("\n" + "="*60)
    print("🔧 Phase 2: 함수 마이그레이션")
    print("="*60)
    
    try:
        print("\n1️⃣ 핵심 함수 래핑...")
        migrator._migrate_core_functions()
        
        print("2️⃣ 이벤트 시스템 연결...")
        migrator._connect_event_systems()
        
        print("3️⃣ 서비스 레이어 연결...")
        # 게임 서비스 초기화
        from services.game_service import GameService
        game_service = GameService()
        
        print("\n✅ Phase 2 완료!")
        return True
        
    except Exception as e:
        print(f"\n❌ Phase 2 실패: {e}")
        import traceback
        traceback.print_exc()
        return False


def run_migration_phase3():
    """Phase 3: 점진적 실행"""
    print("\n" + "="*60)
    print("🎮 Phase 3: 하이브리드 모드 실행")
    print("="*60)
    
    print("""
    이제 게임을 하이브리드 모드로 실행할 수 있습니다:
    
    1. 기존 코드는 그대로 작동
    2. 새 시스템이 백그라운드에서 동작
    3. 점진적으로 기능 이전
    
    실행 방법:
    python pingfighter.py --migration-mode
    """)


def show_migration_dashboard(migrator):
    """마이그레이션 대시보드 표시"""
    print("\n" + "="*60)
    print("📊 마이그레이션 대시보드")
    print("="*60)
    
    if migrator:
        migrator.plan.print_status()
        
        status = migrator.get_migration_status()
        print("\n📈 통계:")
        print(f"  - 레거시 함수: {status['adapter_stats']['legacy_functions']}")
        print(f"  - 마이그레이션된 함수: {status['adapter_stats']['migrated_functions']}")
        
        overall_progress = sum(status['progress'].values()) / len(status['progress'])
        print(f"\n전체 진행률: {overall_progress:.1f}%")
        
        # 진행률 바
        bar_length = 40
        filled = int(bar_length * overall_progress / 100)
        bar = "█" * filled + "░" * (bar_length - filled)
        print(f"[{bar}] {overall_progress:.1f}%")


def interactive_migration():
    """대화형 마이그레이션"""
    print("\n" + "="*60)
    print("🎯 PingFighter 점진적 마이그레이션")
    print("="*60)
    
    # 준비 상태 확인
    if not check_migration_readiness():
        print("\n⚠️ 마이그레이션 준비가 완료되지 않았습니다.")
        return
    
    migrator = None
    bridge = None
    
    while True:
        print("\n메뉴:")
        print("1. Phase 1 실행 (기본 시스템 연결)")
        print("2. Phase 2 실행 (함수 마이그레이션)")
        print("3. Phase 3 실행 (하이브리드 모드)")
        print("4. 대시보드 보기")
        print("5. 자동 마이그레이션")
        print("0. 종료")
        
        choice = input("\n선택: ")
        
        if choice == "1":
            migrator, bridge = run_migration_phase1()
        elif choice == "2":
            if migrator and bridge:
                run_migration_phase2(migrator, bridge)
            else:
                print("⚠️ Phase 1을 먼저 실행하세요.")
        elif choice == "3":
            run_migration_phase3()
        elif choice == "4":
            show_migration_dashboard(migrator)
        elif choice == "5":
            print("\n🤖 자동 마이그레이션 시작...")
            migrator, bridge = run_migration_phase1()
            if migrator and bridge:
                if run_migration_phase2(migrator, bridge):
                    run_migration_phase3()
                    show_migration_dashboard(migrator)
        elif choice == "0":
            break
        else:
            print("잘못된 선택입니다.")
    
    print("\n마이그레이션 도구를 종료합니다.")


def quick_migration():
    """빠른 마이그레이션 (자동)"""
    print("\n⚡ 빠른 마이그레이션 모드")
    
    if not check_migration_readiness():
        return False
    
    # Phase 1
    migrator, bridge = run_migration_phase1()
    if not migrator or not bridge:
        return False
    
    # Phase 2
    if not run_migration_phase2(migrator, bridge):
        return False
    
    # 결과 표시
    show_migration_dashboard(migrator)
    
    print("\n✅ 마이그레이션 준비 완료!")
    print("이제 pingfighter.py를 하이브리드 모드로 실행할 수 있습니다.")
    
    return True


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="PingFighter 마이그레이션 도구")
    parser.add_argument("--quick", action="store_true", help="빠른 자동 마이그레이션")
    parser.add_argument("--interactive", action="store_true", help="대화형 모드")
    
    args = parser.parse_args()
    
    if args.quick:
        success = quick_migration()
        sys.exit(0 if success else 1)
    else:
        interactive_migration()