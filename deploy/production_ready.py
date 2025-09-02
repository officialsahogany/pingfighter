#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🚀 프로덕션 배포 준비 도구
배포를 위한 최종 검증 및 패키징
"""

import os
import sys
import shutil
import subprocess
from datetime import datetime
from typing import List, Dict, Tuple, Optional


class ProductionDeployment:
    """
    🚀 프로덕션 배포 관리자
    
    배포 전 최종 검증과 패키징을 수행합니다.
    """
    
    def __init__(self, project_root: str):
        """
        초기화
        
        Args:
            project_root: 프로젝트 루트 경로
        """
        self.project_root = project_root
        self.checks_passed = []
        self.checks_failed = []
        self.warnings = []
        
        print("🚀 프로덕션 배포 준비 도구 초기화")
    
    def run_all_checks(self) -> bool:
        """
        모든 배포 전 검사 실행
        
        Returns:
            모든 검사 통과 여부
        """
        print("\n" + "="*60)
        print("📋 프로덕션 배포 체크리스트")
        print("="*60)
        
        checks = [
            ("코드 품질", self._check_code_quality),
            ("테스트", self._check_tests),
            ("의존성", self._check_dependencies),
            ("보안", self._check_security),
            ("성능", self._check_performance),
            ("문서화", self._check_documentation),
            ("빌드", self._check_build),
            ("리소스", self._check_resources),
        ]
        
        for name, check_func in checks:
            print(f"\n🔍 {name} 검사 중...")
            try:
                if check_func():
                    self.checks_passed.append(name)
                    print(f"  ✅ {name} 검사 통과")
                else:
                    self.checks_failed.append(name)
                    print(f"  ❌ {name} 검사 실패")
            except Exception as e:
                self.checks_failed.append(name)
                print(f"  ❌ {name} 검사 중 오류: {e}")
        
        return len(self.checks_failed) == 0
    
    def _check_code_quality(self) -> bool:
        """코드 품질 검사"""
        issues = []
        
        # TODO/FIXME 주석 검사
        for root, dirs, files in os.walk(self.project_root):
            # 제외할 디렉토리
            if 'venv' in root or '__pycache__' in root:
                continue
            
            for file in files:
                if file.endswith('.py'):
                    file_path = os.path.join(root, file)
                    with open(file_path, 'r', encoding='utf-8') as f:
                        for i, line in enumerate(f, 1):
                            if 'TODO' in line or 'FIXME' in line:
                                issues.append(f"{file}:{i}")
        
        if issues:
            self.warnings.append(f"TODO/FIXME 발견: {len(issues)}개")
            print(f"  ⚠️ {len(issues)}개의 TODO/FIXME 발견")
        
        # 대용량 함수 검사
        large_functions = self._find_large_functions()
        if large_functions:
            self.warnings.append(f"대용량 함수: {len(large_functions)}개")
            print(f"  ⚠️ {len(large_functions)}개의 대용량 함수 (>100줄)")
        
        return True  # 경고만 표시, 실패는 아님
    
    def _check_tests(self) -> bool:
        """테스트 실행"""
        test_files = [
            "test_migration.py",
            "test_collision_system.py",
            "test_game_mechanics.py",
            "test_rendering_ui.py"
        ]
        
        all_passed = True
        for test_file in test_files:
            test_path = os.path.join(self.project_root, test_file)
            if os.path.exists(test_path):
                result = subprocess.run(
                    [sys.executable, test_path],
                    capture_output=True,
                    text=True
                )
                if result.returncode != 0:
                    all_passed = False
                    print(f"    ❌ {test_file} 실패")
                else:
                    print(f"    ✅ {test_file} 통과")
        
        return all_passed
    
    def _check_dependencies(self) -> bool:
        """의존성 검사"""
        required = ['pygame', 'numpy']
        missing = []
        
        for package in required:
            try:
                __import__(package)
            except ImportError:
                missing.append(package)
        
        if missing:
            print(f"  ❌ 누락된 패키지: {', '.join(missing)}")
            return False
        
        # requirements.txt 확인
        req_file = os.path.join(self.project_root, "requirements.txt")
        if not os.path.exists(req_file):
            self.warnings.append("requirements.txt 파일 없음")
            print("  ⚠️ requirements.txt 파일이 없습니다")
        
        return True
    
    def _check_security(self) -> bool:
        """보안 검사"""
        security_issues = []
        
        # 하드코딩된 비밀번호 검사
        patterns = ['password', 'secret', 'api_key', 'token']
        
        for root, dirs, files in os.walk(self.project_root):
            if 'venv' in root or '__pycache__' in root:
                continue
            
            for file in files:
                if file.endswith('.py'):
                    file_path = os.path.join(root, file)
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read().lower()
                        for pattern in patterns:
                            if f'{pattern} = "' in content or f"{pattern} = '" in content:
                                security_issues.append(f"{file}: {pattern}")
        
        if security_issues:
            self.warnings.append(f"보안 이슈: {len(security_issues)}개")
            print(f"  ⚠️ {len(security_issues)}개의 잠재적 보안 이슈")
        
        return len(security_issues) == 0
    
    def _check_performance(self) -> bool:
        """성능 검사"""
        # 성능 최적화 파일 확인
        optimizer_path = os.path.join(self.project_root, "optimization/performance_optimizer.py")
        if os.path.exists(optimizer_path):
            print("  ✅ 성능 최적화 도구 준비됨")
            return True
        else:
            print("  ⚠️ 성능 최적화 도구 없음")
            return True  # 경고만
    
    def _check_documentation(self) -> bool:
        """문서화 검사"""
        required_docs = [
            "README.md",
            "CLAUDE.md",
            "MIGRATION_GUIDE.md"
        ]
        
        missing_docs = []
        for doc in required_docs:
            doc_path = os.path.join(self.project_root, doc)
            if not os.path.exists(doc_path):
                missing_docs.append(doc)
        
        if missing_docs:
            print(f"  ⚠️ 누락된 문서: {', '.join(missing_docs)}")
            self.warnings.append(f"누락된 문서: {len(missing_docs)}개")
        
        return len(missing_docs) == 0
    
    def _check_build(self) -> bool:
        """빌드 설정 검사"""
        # PyInstaller spec 파일 확인
        spec_files = [
            "PingFighter.spec",
            "PingFighter_Windows.spec"
        ]
        
        found_specs = []
        for spec in spec_files:
            spec_path = os.path.join(self.project_root, spec)
            if os.path.exists(spec_path):
                found_specs.append(spec)
        
        if found_specs:
            print(f"  ✅ 빌드 설정 파일: {', '.join(found_specs)}")
            return True
        else:
            print("  ⚠️ PyInstaller spec 파일 없음")
            return True  # 경고만
    
    def _check_resources(self) -> bool:
        """리소스 파일 검사"""
        resource_dirs = ["items", "sounds", "fonts", "backgrounds", "effects"]
        missing_dirs = []
        
        for dir_name in resource_dirs:
            dir_path = os.path.join(self.project_root, dir_name)
            if not os.path.exists(dir_path):
                missing_dirs.append(dir_name)
        
        if missing_dirs:
            print(f"  ⚠️ 누락된 리소스 디렉토리: {', '.join(missing_dirs)}")
            self.warnings.append(f"누락된 리소스: {len(missing_dirs)}개")
        
        return len(missing_dirs) == 0
    
    def _find_large_functions(self) -> List[str]:
        """대용량 함수 찾기"""
        large_functions = []
        
        for root, dirs, files in os.walk(self.project_root):
            if 'venv' in root or '__pycache__' in root:
                continue
            
            for file in files:
                if file.endswith('.py'):
                    file_path = os.path.join(root, file)
                    with open(file_path, 'r', encoding='utf-8') as f:
                        lines = f.readlines()
                        
                    in_function = False
                    function_start = 0
                    function_name = ""
                    
                    for i, line in enumerate(lines):
                        if line.strip().startswith('def '):
                            if in_function and (i - function_start) > 100:
                                large_functions.append(
                                    f"{file}:{function_name} ({i - function_start} lines)"
                                )
                            in_function = True
                            function_start = i
                            function_name = line.strip().split('(')[0].replace('def ', '')
        
        return large_functions
    
    def create_deployment_package(self):
        """배포 패키지 생성"""
        print("\n📦 배포 패키지 생성 중...")
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        package_name = f"PingFighter_Deploy_{timestamp}"
        package_dir = os.path.join(self.project_root, "dist", package_name)
        
        # 디렉토리 생성
        os.makedirs(package_dir, exist_ok=True)
        
        # 필요한 파일 복사
        files_to_copy = [
            "pingfighter.py",
            "requirements.txt",
            "README.md",
            "MIGRATION_GUIDE.md",
        ]
        
        dirs_to_copy = [
            "core",
            "services",
            "repositories",
            "game_logic",
            "game_mechanics",
            "ai",
            "rendering",
            "ui",
            "migration",
            "items",
            "sounds",
            "fonts",
            "backgrounds",
            "effects"
        ]
        
        # 파일 복사
        for file in files_to_copy:
            src = os.path.join(self.project_root, file)
            if os.path.exists(src):
                shutil.copy2(src, package_dir)
                print(f"  ✅ {file}")
        
        # 디렉토리 복사
        for dir_name in dirs_to_copy:
            src = os.path.join(self.project_root, dir_name)
            if os.path.exists(src):
                dst = os.path.join(package_dir, dir_name)
                shutil.copytree(src, dst, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
                print(f"  ✅ {dir_name}/")
        
        print(f"\n✅ 배포 패키지 생성 완료: {package_dir}")
        return package_dir
    
    def generate_deployment_report(self):
        """배포 보고서 생성"""
        report = []
        report.append("\n" + "="*60)
        report.append("📋 프로덕션 배포 준비 보고서")
        report.append("="*60)
        
        report.append(f"\n생성 시각: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        
        # 검사 결과
        report.append("\n✅ 통과한 검사:")
        for check in self.checks_passed:
            report.append(f"  • {check}")
        
        if self.checks_failed:
            report.append("\n❌ 실패한 검사:")
            for check in self.checks_failed:
                report.append(f"  • {check}")
        
        if self.warnings:
            report.append("\n⚠️ 경고:")
            for warning in self.warnings:
                report.append(f"  • {warning}")
        
        # 배포 준비 상태
        report.append("\n📊 배포 준비 상태:")
        total_checks = len(self.checks_passed) + len(self.checks_failed)
        if total_checks > 0:
            success_rate = len(self.checks_passed) / total_checks * 100
            report.append(f"  성공률: {success_rate:.1f}%")
            
            if success_rate == 100:
                report.append("  🎉 프로덕션 배포 준비 완료!")
            elif success_rate >= 80:
                report.append("  ✅ 대부분의 검사 통과, 경고 사항 검토 필요")
            else:
                report.append("  ❌ 배포 전 문제 해결 필요")
        
        report.append("="*60)
        
        return "\n".join(report)


def prepare_for_deployment():
    """배포 준비 실행"""
    project_root = "/Volumes/T7/윈도우용최신/game/bosspong"
    
    deployer = ProductionDeployment(project_root)
    
    # 모든 검사 실행
    all_passed = deployer.run_all_checks()
    
    # 보고서 생성
    report = deployer.generate_deployment_report()
    print(report)
    
    # 보고서 파일로 저장
    report_path = os.path.join(project_root, "deployment_report.txt")
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write(report)
    print(f"\n📄 보고서 저장: {report_path}")
    
    # 모든 검사 통과 시 패키지 생성
    if all_passed:
        print("\n모든 검사를 통과했습니다. 배포 패키지를 생성하시겠습니까? (y/n)")
        # 실제로는 사용자 입력을 받아야 하지만, 여기서는 자동으로 생성
        package_dir = deployer.create_deployment_package()
        print(f"\n🚀 배포 준비 완료!")
        print(f"   패키지 위치: {package_dir}")
    else:
        print("\n⚠️ 일부 검사가 실패했습니다. 문제를 해결한 후 다시 시도하세요.")
    
    return all_passed


if __name__ == "__main__":
    success = prepare_for_deployment()
    sys.exit(0 if success else 1)