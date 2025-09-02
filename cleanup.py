#!/usr/bin/env python3
"""
프로젝트 정리 스크립트
불필요한 파일들을 제거하고 프로젝트를 정리
"""
import os
import shutil
from pathlib import Path

def cleanup_project():
    """프로젝트 정리 실행"""
    
    # 정리할 패턴들
    cleanup_patterns = [
        '__pycache__',
        '*.pyc',
        '*.pyo',
        '*.pyd',
        '.DS_Store',
        'Thumbs.db',
        '.pytest_cache',
        '*.egg-info',
        'dist',
        'build',
        '.coverage',
        'htmlcov',
        '.tox',
        '.mypy_cache',
        '.ruff_cache'
    ]
    
    project_root = Path('.')
    removed_count = 0
    
    print("🧹 프로젝트 정리 시작...")
    print("-" * 50)
    
    # __pycache__ 디렉토리 삭제
    for pycache in project_root.rglob('__pycache__'):
        if pycache.is_dir():
            print(f"삭제: {pycache}")
            shutil.rmtree(pycache)
            removed_count += 1
    
    # .pyc, .pyo, .pyd 파일 삭제
    for pattern in ['*.pyc', '*.pyo', '*.pyd']:
        for file in project_root.rglob(pattern):
            print(f"삭제: {file}")
            file.unlink()
            removed_count += 1
    
    # .DS_Store 파일 삭제 (macOS)
    for ds_store in project_root.rglob('.DS_Store'):
        print(f"삭제: {ds_store}")
        ds_store.unlink()
        removed_count += 1
    
    # Thumbs.db 파일 삭제 (Windows)
    for thumbs in project_root.rglob('Thumbs.db'):
        print(f"삭제: {thumbs}")
        thumbs.unlink()
        removed_count += 1
    
    # 빌드 관련 디렉토리 삭제
    for dir_name in ['dist', 'build', '.pytest_cache', '.tox', '.mypy_cache', '.ruff_cache']:
        dir_path = project_root / dir_name
        if dir_path.exists() and dir_path.is_dir():
            print(f"삭제: {dir_path}")
            shutil.rmtree(dir_path)
            removed_count += 1
    
    # egg-info 디렉토리 삭제
    for egg_info in project_root.glob('*.egg-info'):
        if egg_info.is_dir():
            print(f"삭제: {egg_info}")
            shutil.rmtree(egg_info)
            removed_count += 1
    
    print("-" * 50)
    print(f"✅ 정리 완료! {removed_count}개 항목 삭제됨")
    
    # 현재 디렉토리 구조 표시
    print("\n📁 현재 프로젝트 구조:")
    print("-" * 50)
    show_tree('.', max_depth=2)

def show_tree(path, prefix="", max_depth=3, current_depth=0):
    """디렉토리 트리 표시"""
    if current_depth >= max_depth:
        return
        
    path = Path(path)
    
    # 제외할 디렉토리/파일
    exclude = {'.git', '.venv', 'venv', '__pycache__', '.idea', '.vscode'}
    
    if path.is_dir():
        contents = sorted(path.iterdir(), key=lambda x: (x.is_file(), x.name))
        
        for i, item in enumerate(contents):
            if item.name in exclude:
                continue
                
            is_last = i == len(contents) - 1
            current_prefix = "└── " if is_last else "├── "
            print(f"{prefix}{current_prefix}{item.name}")
            
            if item.is_dir() and item.name not in exclude:
                extension = "    " if is_last else "│   "
                show_tree(item, prefix + extension, max_depth, current_depth + 1)

def analyze_code_usage():
    """코드 사용 분석"""
    print("\n📊 코드 분석:")
    print("-" * 50)
    
    # 파이썬 파일 수 계산
    py_files = list(Path('.').rglob('*.py'))
    
    # pingfighter.py 제외한 파일들
    modular_files = [f for f in py_files if f.name != 'pingfighter.py']
    
    # 라인 수 계산
    total_lines = 0
    modular_lines = 0
    
    for py_file in py_files:
        try:
            with open(py_file, 'r', encoding='utf-8') as f:
                lines = len(f.readlines())
                total_lines += lines
                if py_file.name != 'pingfighter.py':
                    modular_lines += lines
        except:
            pass
    
    print(f"총 Python 파일 수: {len(py_files)}개")
    print(f"모듈화된 파일 수: {len(modular_files)}개")
    print(f"총 코드 라인 수: {total_lines:,}줄")
    print(f"모듈화된 코드 라인 수: {modular_lines:,}줄")
    print(f"pingfighter.py 라인 수: {total_lines - modular_lines:,}줄")
    
    # 디렉토리별 파일 수
    print("\n📁 디렉토리별 파일 수:")
    dirs = {}
    for py_file in modular_files:
        dir_name = py_file.parent.name if py_file.parent.name != '.' else 'root'
        dirs[dir_name] = dirs.get(dir_name, 0) + 1
    
    for dir_name, count in sorted(dirs.items()):
        print(f"  {dir_name}: {count}개")

if __name__ == "__main__":
    cleanup_project()
    analyze_code_usage()