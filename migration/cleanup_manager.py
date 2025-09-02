#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🧹 레거시 코드 정리 매니저
기존 코드를 새 아키텍처로 완전히 전환하는 도구
"""

import os
import sys
import re
from typing import List, Dict, Tuple, Set, Any
from dataclasses import dataclass
from enum import Enum


class CodeSection(Enum):
    """코드 섹션 분류"""
    IMPORTS = "imports"
    GLOBALS = "globals"
    GAME_LOGIC = "game_logic"
    RENDERING = "rendering"
    UI = "ui"
    EVENT_HANDLING = "event_handling"
    MAIN_LOOP = "main_loop"
    UTILITY = "utility"


@dataclass
class LegacyCode:
    """레거시 코드 정보"""
    section: CodeSection
    start_line: int
    end_line: int
    function_name: str
    dependencies: List[str]
    migrated: bool = False
    new_module: str = ""


class CleanupManager:
    """
    🧹 레거시 코드 정리 관리자
    
    pingfighter.py의 레거시 코드를 분석하고
    새 모듈로 마이그레이션된 부분을 표시합니다.
    """
    
    def __init__(self, legacy_file_path: str):
        """
        초기화
        
        Args:
            legacy_file_path: 레거시 파일 경로
        """
        self.legacy_file_path = legacy_file_path
        self.legacy_code: List[LegacyCode] = []
        self.migration_map: Dict[str, str] = {}
        self.statistics = {
            'total_lines': 0,
            'migrated_lines': 0,
            'remaining_lines': 0,
            'functions_total': 0,
            'functions_migrated': 0,
        }
        
        # 마이그레이션 매핑 정의
        self._init_migration_map()
        
        print("🧹 레거시 코드 정리 매니저 초기화")
    
    def _init_migration_map(self):
        """마이그레이션 매핑 초기화"""
        self.migration_map = {
            # 물리 관련
            'update_ball_position': 'game_logic/physics_engine.py',
            'apply_gravity': 'game_logic/physics_engine.py',
            'apply_friction': 'game_logic/physics_engine.py',
            'calculate_bounce': 'game_logic/physics_engine.py',
            
            # 충돌 관련
            'check_collision': 'game_logic/collision_system.py',
            'check_ball_paddle_collision': 'game_logic/collision_system.py',
            'check_ball_boss_collision': 'game_logic/collision_system.py',
            'handle_collision': 'game_logic/collision_system.py',
            
            # AI 관련
            'update_boss_ai': 'ai/boss_ai_system.py',
            'calculate_ai_move': 'ai/boss_ai_system.py',
            'predict_ball_position': 'ai/boss_ai_system.py',
            'boss_make_decision': 'ai/boss_ai_system.py',
            
            # 아이템 관련
            'spawn_item': 'game_mechanics/item_system.py',
            'collect_item': 'game_mechanics/item_system.py',
            'activate_item': 'game_mechanics/item_system.py',
            'update_items': 'game_mechanics/item_system.py',
            
            # 스킬 관련
            'use_skill': 'game_mechanics/skill_system.py',
            'update_skills': 'game_mechanics/skill_system.py',
            'handle_dash': 'game_mechanics/skill_system.py',
            'handle_special': 'game_mechanics/skill_system.py',
            
            # 렌더링 관련
            'draw_game': 'rendering/render_system.py',
            'draw_ball': 'rendering/render_system.py',
            'draw_paddle': 'rendering/render_system.py',
            'draw_boss': 'rendering/render_system.py',
            'draw_effects': 'rendering/render_system.py',
            
            # UI 관련
            'draw_menu': 'ui/ui_system.py',
            'draw_hud': 'ui/ui_system.py',
            'draw_score': 'ui/ui_system.py',
            'handle_menu_click': 'ui/ui_system.py',
            'show_dialog': 'ui/ui_system.py',
        }
    
    def analyze_legacy_code(self) -> Dict[str, Any]:
        """
        레거시 코드 분석
        
        Returns:
            분석 결과
        """
        print("\n📊 레거시 코드 분석 중...")
        
        if not os.path.exists(self.legacy_file_path):
            print(f"  ❌ 파일을 찾을 수 없음: {self.legacy_file_path}")
            return {}
        
        with open(self.legacy_file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        self.statistics['total_lines'] = len(lines)
        
        # 함수 찾기
        function_pattern = re.compile(r'^def\s+(\w+)\s*\(')
        current_function = None
        function_start = 0
        
        for i, line in enumerate(lines):
            match = function_pattern.match(line)
            if match:
                # 이전 함수 저장
                if current_function:
                    self._save_function(
                        current_function, 
                        function_start, 
                        i - 1,
                        lines[function_start:i]
                    )
                
                # 새 함수 시작
                current_function = match.group(1)
                function_start = i
                self.statistics['functions_total'] += 1
        
        # 마지막 함수 저장
        if current_function:
            self._save_function(
                current_function,
                function_start,
                len(lines) - 1,
                lines[function_start:]
            )
        
        # 마이그레이션 상태 확인
        self._check_migration_status()
        
        return self._generate_report()
    
    def _save_function(self, name: str, start: int, end: int, lines: List[str]):
        """함수 정보 저장"""
        # 섹션 분류
        section = self._classify_function(name, lines)
        
        # 의존성 찾기
        dependencies = self._find_dependencies(lines)
        
        # 마이그레이션 여부 확인
        migrated = name in self.migration_map
        new_module = self.migration_map.get(name, "")
        
        legacy_code = LegacyCode(
            section=section,
            start_line=start,
            end_line=end,
            function_name=name,
            dependencies=dependencies,
            migrated=migrated,
            new_module=new_module
        )
        
        self.legacy_code.append(legacy_code)
        
        if migrated:
            self.statistics['functions_migrated'] += 1
            self.statistics['migrated_lines'] += (end - start + 1)
    
    def _classify_function(self, name: str, lines: List[str]) -> CodeSection:
        """함수 섹션 분류"""
        # 이름 기반 분류
        if 'draw' in name or 'render' in name:
            return CodeSection.RENDERING
        elif 'handle' in name or 'event' in name:
            return CodeSection.EVENT_HANDLING
        elif 'update' in name or 'physics' in name or 'collision' in name:
            return CodeSection.GAME_LOGIC
        elif 'menu' in name or 'hud' in name or 'ui' in name:
            return CodeSection.UI
        elif name in ['main', 'game_loop']:
            return CodeSection.MAIN_LOOP
        else:
            return CodeSection.UTILITY
    
    def _find_dependencies(self, lines: List[str]) -> List[str]:
        """함수 의존성 찾기"""
        dependencies = []
        
        # 전역 변수 접근
        global_pattern = re.compile(r'global\s+(\w+)')
        
        # 함수 호출
        call_pattern = re.compile(r'(\w+)\s*\(')
        
        for line in lines:
            # 전역 변수
            global_match = global_pattern.search(line)
            if global_match:
                dependencies.append(f"global:{global_match.group(1)}")
            
            # 함수 호출
            call_matches = call_pattern.findall(line)
            for func in call_matches:
                if func not in ['print', 'int', 'float', 'str', 'len', 'range']:
                    dependencies.append(f"func:{func}")
        
        return list(set(dependencies))
    
    def _check_migration_status(self):
        """마이그레이션 상태 확인"""
        self.statistics['remaining_lines'] = (
            self.statistics['total_lines'] - 
            self.statistics['migrated_lines']
        )
    
    def _generate_report(self) -> Dict[str, Any]:
        """분석 보고서 생성"""
        report = {
            'statistics': self.statistics,
            'sections': {},
            'migration_progress': {},
            'recommendations': []
        }
        
        # 섹션별 통계
        for section in CodeSection:
            section_funcs = [lc for lc in self.legacy_code if lc.section == section]
            migrated = sum(1 for lc in section_funcs if lc.migrated)
            
            report['sections'][section.value] = {
                'total': len(section_funcs),
                'migrated': migrated,
                'remaining': len(section_funcs) - migrated
            }
        
        # 마이그레이션 진행률
        if self.statistics['functions_total'] > 0:
            report['migration_progress']['functions'] = (
                self.statistics['functions_migrated'] / 
                self.statistics['functions_total'] * 100
            )
        
        if self.statistics['total_lines'] > 0:
            report['migration_progress']['lines'] = (
                self.statistics['migrated_lines'] / 
                self.statistics['total_lines'] * 100
            )
        
        # 권장사항
        report['recommendations'] = self._generate_recommendations()
        
        return report
    
    def _generate_recommendations(self) -> List[str]:
        """권장사항 생성"""
        recommendations = []
        
        # 마이그레이션되지 않은 중요 함수
        unmigrated = [lc for lc in self.legacy_code if not lc.migrated]
        
        if unmigrated:
            critical = [lc for lc in unmigrated if lc.section in [
                CodeSection.GAME_LOGIC, 
                CodeSection.RENDERING
            ]]
            
            if critical:
                recommendations.append(
                    f"🔴 {len(critical)}개의 핵심 함수가 아직 마이그레이션되지 않았습니다"
                )
        
        # 의존성이 많은 함수
        high_deps = [lc for lc in self.legacy_code 
                    if len(lc.dependencies) > 10 and not lc.migrated]
        
        if high_deps:
            recommendations.append(
                f"⚠️ {len(high_deps)}개 함수가 높은 의존성을 가지고 있습니다"
            )
        
        # 성공적으로 마이그레이션된 부분
        if self.statistics['functions_migrated'] > 0:
            recommendations.append(
                f"✅ {self.statistics['functions_migrated']}개 함수가 성공적으로 마이그레이션되었습니다"
            )
        
        return recommendations
    
    def generate_cleanup_script(self) -> str:
        """정리 스크립트 생성"""
        script = []
        script.append("#!/usr/bin/env python3")
        script.append("# -*- coding: utf-8 -*-")
        script.append('"""')
        script.append("자동 생성된 레거시 코드 정리 스크립트")
        script.append('"""')
        script.append("")
        script.append("import os")
        script.append("import shutil")
        script.append("from datetime import datetime")
        script.append("")
        script.append("def cleanup_legacy_code():")
        script.append('    """레거시 코드 정리"""')
        script.append('    print("🧹 레거시 코드 정리 시작...")')
        script.append("")
        
        # 백업 생성
        script.append("    # 백업 생성")
        script.append('    backup_name = f"pingfighter_backup_{datetime.now().strftime(\'%Y%m%d_%H%M%S\')}.py"')
        script.append('    shutil.copy("pingfighter.py", backup_name)')
        script.append('    print(f"  ✅ 백업 생성: {backup_name}")')
        script.append("")
        
        # 마이그레이션된 함수 제거
        script.append("    # 마이그레이션된 함수 표시")
        script.append("    migrated_functions = [")
        
        for lc in self.legacy_code:
            if lc.migrated:
                script.append(f'        "{lc.function_name}",  # -> {lc.new_module}')
        
        script.append("    ]")
        script.append("")
        script.append('    print(f"  📦 {len(migrated_functions)}개 함수가 새 모듈로 이동되었습니다")')
        script.append("")
        script.append('if __name__ == "__main__":')
        script.append("    cleanup_legacy_code()")
        
        return "\n".join(script)
    
    def print_report(self, report: Dict[str, Any]):
        """보고서 출력"""
        print("\n" + "="*60)
        print("📊 레거시 코드 분석 보고서")
        print("="*60)
        
        # 전체 통계
        stats = report['statistics']
        print("\n📈 전체 통계:")
        print(f"  총 라인 수: {stats['total_lines']:,}")
        print(f"  마이그레이션된 라인: {stats['migrated_lines']:,}")
        print(f"  남은 라인: {stats['remaining_lines']:,}")
        print(f"  총 함수 수: {stats['functions_total']}")
        print(f"  마이그레이션된 함수: {stats['functions_migrated']}")
        
        # 진행률
        progress = report['migration_progress']
        if 'functions' in progress:
            print(f"\n📊 마이그레이션 진행률:")
            print(f"  함수: {progress['functions']:.1f}%")
            print(f"  코드 라인: {progress.get('lines', 0):.1f}%")
        
        # 섹션별 상태
        print("\n📁 섹션별 마이그레이션 상태:")
        for section, data in report['sections'].items():
            if data['total'] > 0:
                percent = data['migrated'] / data['total'] * 100
                status = "✅" if percent == 100 else "🔄" if percent > 0 else "❌"
                print(f"  {status} {section:15} - {data['migrated']}/{data['total']} ({percent:.0f}%)")
        
        # 권장사항
        if report['recommendations']:
            print("\n💡 권장사항:")
            for rec in report['recommendations']:
                print(f"  {rec}")
        
        print("="*60)


def analyze_pingfighter():
    """pingfighter.py 분석 실행"""
    manager = CleanupManager("/Volumes/T7/윈도우용최신/game/bosspong/pingfighter.py")
    report = manager.analyze_legacy_code()
    manager.print_report(report)
    
    # 정리 스크립트 생성
    cleanup_script = manager.generate_cleanup_script()
    
    script_path = "/Volumes/T7/윈도우용최신/game/bosspong/auto_cleanup.py"
    with open(script_path, 'w', encoding='utf-8') as f:
        f.write(cleanup_script)
    
    print(f"\n✅ 정리 스크립트 생성: {script_path}")
    
    return report


if __name__ == "__main__":
    report = analyze_pingfighter()
    
    # 마이그레이션 완료 여부 확인
    if report['migration_progress'].get('functions', 0) > 80:
        print("\n🎉 마이그레이션이 거의 완료되었습니다!")
        print("   레거시 코드를 안전하게 제거할 수 있습니다.")
    else:
        print("\n⚠️ 아직 마이그레이션할 코드가 남아있습니다.")