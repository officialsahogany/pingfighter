#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
마이그레이션 진행 상황 모니터링
현재 마이그레이션 진행률과 완료된 모듈을 시각화
"""

import os
import sys
from typing import Dict, List, Tuple
from dataclasses import dataclass
from enum import Enum


class MigrationStatus(Enum):
    """마이그레이션 상태"""
    NOT_STARTED = "❌"
    IN_PROGRESS = "🔄"
    COMPLETED = "✅"
    TESTING = "🧪"


@dataclass
class MigrationModule:
    """마이그레이션 모듈"""
    name: str
    korean_name: str
    status: MigrationStatus
    progress: float
    files: List[str]
    description: str


def get_migration_modules() -> List[MigrationModule]:
    """마이그레이션 모듈 목록 반환"""
    modules = [
        # Phase 1: 기초 시스템
        MigrationModule(
            name="Core Systems",
            korean_name="핵심 시스템",
            status=MigrationStatus.COMPLETED,
            progress=100,
            files=["core/game_state.py", "core/dependency_injection.py", "core/event_bus.py"],
            description="게임 상태, DI 컨테이너, 이벤트 시스템"
        ),
        
        MigrationModule(
            name="Service Layer",
            korean_name="서비스 레이어",
            status=MigrationStatus.COMPLETED,
            progress=100,
            files=["services/game_service.py", "repositories/game_repository.py"],
            description="게임 서비스, 리포지토리 패턴"
        ),
        
        MigrationModule(
            name="Migration Bridge",
            korean_name="마이그레이션 브리지",
            status=MigrationStatus.COMPLETED,
            progress=100,
            files=["migration/migration_bridge.py", "migration/legacy_adapter.py"],
            description="레거시 코드 연결 브리지"
        ),
        
        # Phase 2: 물리/로직 시스템
        MigrationModule(
            name="Physics Engine",
            korean_name="물리 엔진",
            status=MigrationStatus.COMPLETED,
            progress=100,
            files=["game_logic/physics_engine.py"],
            description="공 움직임, 물리 시뮬레이션"
        ),
        
        MigrationModule(
            name="Collision System",
            korean_name="충돌 시스템",
            status=MigrationStatus.COMPLETED,
            progress=100,
            files=["game_logic/collision_system.py"],
            description="충돌 감지 및 처리"
        ),
        
        # Phase 3: AI 시스템
        MigrationModule(
            name="AI System",
            korean_name="AI 시스템",
            status=MigrationStatus.COMPLETED,
            progress=100,
            files=["ai/boss_ai_system.py"],
            description="보스 AI 행동 패턴"
        ),
        
        # Phase 3: 게임 메커니즘
        MigrationModule(
            name="Item System",
            korean_name="아이템 시스템",
            status=MigrationStatus.COMPLETED,
            progress=100,
            files=["game_mechanics/item_system.py"],
            description="아이템 생성, 효과, 관리"
        ),
        
        MigrationModule(
            name="Skill System",
            korean_name="스킬 시스템",
            status=MigrationStatus.COMPLETED,
            progress=100,
            files=["game_mechanics/skill_system.py"],
            description="플레이어/보스 특수 능력"
        ),
        
        # Phase 4: 렌더링 (완료)
        MigrationModule(
            name="Rendering System",
            korean_name="렌더링 시스템",
            status=MigrationStatus.COMPLETED,
            progress=100,
            files=["rendering/render_system.py"],
            description="화면 그리기, 이펙트 렌더링"
        ),
        
        MigrationModule(
            name="UI System",
            korean_name="UI 시스템",
            status=MigrationStatus.COMPLETED,
            progress=100,
            files=["ui/ui_system.py"],
            description="메뉴, HUD, 다이얼로그"
        ),
        
        # Phase 5: 통합 (완료)
        MigrationModule(
            name="Integration & Cleanup",
            korean_name="통합 및 정리",
            status=MigrationStatus.COMPLETED,
            progress=100,
            files=["migration/final_integration.py", "migration/cleanup_manager.py"],
            description="레거시 코드 제거, 최종 통합"
        ),
    ]
    
    return modules


def calculate_total_progress(modules: List[MigrationModule]) -> float:
    """전체 진행률 계산"""
    if not modules:
        return 0
    
    total_progress = sum(module.progress for module in modules)
    return total_progress / len(modules)


def print_progress_bar(progress: float, width: int = 40) -> str:
    """진행률 바 생성"""
    filled = int(width * progress / 100)
    empty = width - filled
    bar = "█" * filled + "░" * empty
    return f"[{bar}] {progress:.1f}%"


def print_migration_report():
    """마이그레이션 진행 상황 보고서 출력"""
    modules = get_migration_modules()
    total_progress = calculate_total_progress(modules)
    
    print("\n" + "=" * 70)
    print("🚀 PingFighter 아키텍처 마이그레이션 진행 상황")
    print("=" * 70)
    
    # 전체 진행률
    print(f"\n📊 전체 진행률: {print_progress_bar(total_progress)}")
    
    # Phase별 그룹핑
    phases = {
        "Phase 1 - 기초 인프라": [],
        "Phase 2 - 게임 로직": [],
        "Phase 3 - 게임 메커니즘": [],
        "Phase 4 - UI/렌더링": [],
        "Phase 5 - 최종 통합": []
    }
    
    # 모듈 분류
    for module in modules:
        if module.name in ["Core Systems", "Service Layer", "Migration Bridge"]:
            phases["Phase 1 - 기초 인프라"].append(module)
        elif module.name in ["Physics Engine", "Collision System"]:
            phases["Phase 2 - 게임 로직"].append(module)
        elif module.name in ["AI System", "Item System", "Skill System"]:
            phases["Phase 3 - 게임 메커니즘"].append(module)
        elif module.name in ["Rendering System", "UI System"]:
            phases["Phase 4 - UI/렌더링"].append(module)
        else:
            phases["Phase 5 - 최종 통합"].append(module)
    
    # Phase별 출력
    for phase_name, phase_modules in phases.items():
        if not phase_modules:
            continue
        
        phase_progress = calculate_total_progress(phase_modules)
        print(f"\n### {phase_name} ({phase_progress:.0f}%)")
        print("-" * 60)
        
        for module in phase_modules:
            status_icon = module.status.value
            print(f"{status_icon} {module.korean_name:15} {print_progress_bar(module.progress, 20)}")
            print(f"   └─ {module.description}")
            if module.files:
                print(f"      파일: {', '.join(module.files[:2])}" + 
                      (f" 외 {len(module.files)-2}개" if len(module.files) > 2 else ""))
    
    # 통계
    print("\n" + "=" * 70)
    print("📈 통계:")
    print("-" * 60)
    
    completed = sum(1 for m in modules if m.status == MigrationStatus.COMPLETED)
    in_progress = sum(1 for m in modules if m.status == MigrationStatus.IN_PROGRESS)
    not_started = sum(1 for m in modules if m.status == MigrationStatus.NOT_STARTED)
    
    print(f"  ✅ 완료: {completed}/{len(modules)} 모듈")
    print(f"  🔄 진행중: {in_progress}/{len(modules)} 모듈")
    print(f"  ❌ 미시작: {not_started}/{len(modules)} 모듈")
    
    # 생성된 파일 수
    total_files = sum(len(m.files) for m in modules)
    print(f"  📁 생성된 파일: {total_files}개")
    
    # 다음 단계
    print("\n" + "=" * 70)
    print("🎯 다음 단계:")
    print("-" * 60)
    
    next_modules = [m for m in modules if m.status != MigrationStatus.COMPLETED]
    if next_modules:
        for module in next_modules[:3]:  # 최대 3개까지만 표시
            print(f"  • {module.korean_name}: {module.description}")
    else:
        print("  🎉 모든 모듈 마이그레이션 완료!")
    
    # 실행 방법
    print("\n" + "=" * 70)
    print("💡 실행 방법:")
    print("-" * 60)
    print("  1. 마이그레이션 모드로 실행:")
    print("     python3 pingfighter.py --migration-mode")
    print()
    print("  2. 테스트 실행:")
    print("     python3 test_migration.py")
    print("     python3 test_collision_system.py")
    print("     python3 test_game_mechanics.py")
    print()
    print("  3. 다음 단계 진행:")
    print("     '다음단계' 명령으로 계속 진행")
    print("=" * 70)


def check_file_existence():
    """마이그레이션된 파일 존재 확인"""
    modules = get_migration_modules()
    print("\n📁 파일 존재 확인:")
    print("-" * 60)
    
    for module in modules:
        if module.files:
            for file_path in module.files:
                full_path = os.path.join("/Volumes/T7/윈도우용최신/game/bosspong", file_path)
                exists = os.path.exists(full_path)
                icon = "✅" if exists else "❌"
                print(f"  {icon} {file_path}")


if __name__ == "__main__":
    print_migration_report()
    
    # 상세 정보 옵션
    if "--verbose" in sys.argv or "-v" in sys.argv:
        check_file_existence()