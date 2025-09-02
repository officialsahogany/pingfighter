#!/usr/bin/env python3
"""
사용하지 않는 코드를 찾는 스크립트
"""

import re
import ast

def find_unused_functions(filename):
    """사용하지 않는 함수 찾기"""
    
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 함수 정의 찾기
    function_defs = re.findall(r'^def\s+(\w+)\s*\(', content, re.MULTILINE)
    
    # 클래스 메서드는 제외
    class_methods = re.findall(r'^\s+def\s+(\w+)\s*\(', content, re.MULTILINE)
    
    # 순수 함수만 남기기
    pure_functions = [f for f in function_defs if f not in class_methods]
    
    print(f"전체 함수 정의: {len(function_defs)}개")
    print(f"클래스 메서드: {len(class_methods)}개")
    print(f"순수 함수: {len(pure_functions)}개\n")
    
    # 각 함수의 사용 횟수 확인
    unused_functions = []
    rarely_used = []
    
    for func in pure_functions:
        # 함수 정의 자체는 제외하고 호출 찾기
        # func( 또는 func ( 형태로 호출되는 경우
        pattern = rf'\b{func}\s*\('
        matches = re.findall(pattern, content)
        
        # 정의 자체를 제외
        call_count = len(matches) - 1
        
        if call_count == 0:
            unused_functions.append(func)
        elif call_count == 1:
            rarely_used.append((func, call_count))
    
    return unused_functions, rarely_used, pure_functions

def find_unused_variables(filename):
    """사용하지 않는 전역 변수 찾기"""
    
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # 전역 변수 정의 찾기 (대문자로 시작하는 상수들)
    global_vars = []
    
    for i, line in enumerate(lines):
        # 상수 정의 패턴
        if re.match(r'^[A-Z_][A-Z0-9_]*\s*=', line):
            var_name = line.split('=')[0].strip()
            global_vars.append((var_name, i+1))
    
    # 각 변수의 사용 횟수 확인
    content = ''.join(lines)
    unused_vars = []
    rarely_used_vars = []
    
    for var_name, line_num in global_vars:
        # 변수 사용 횟수 (정의 제외)
        pattern = rf'\b{var_name}\b'
        matches = re.findall(pattern, content)
        
        # 정의 자체를 제외
        usage_count = len(matches) - 1
        
        if usage_count == 0:
            unused_vars.append((var_name, line_num))
        elif usage_count == 1:
            rarely_used_vars.append((var_name, line_num, usage_count))
    
    return unused_vars, rarely_used_vars

def find_duplicate_imports(filename):
    """중복되거나 사용하지 않는 import 찾기"""
    
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
        lines = content.split('\n')
    
    imports = []
    imported_names = set()
    
    for i, line in enumerate(lines):
        if line.startswith('import ') or line.startswith('from '):
            imports.append((i+1, line))
            
            # import된 이름 추출
            if line.startswith('import '):
                # import module
                # import module as alias
                parts = line.replace('import ', '').split(' as ')
                if len(parts) == 2:
                    imported_names.add(parts[1].strip())
                else:
                    imported_names.add(parts[0].strip().split('.')[0])
            else:
                # from module import name
                # from module import name as alias
                if ' import ' in line:
                    import_part = line.split(' import ')[1]
                    for item in import_part.split(','):
                        item = item.strip()
                        if ' as ' in item:
                            imported_names.add(item.split(' as ')[1].strip())
                        else:
                            imported_names.add(item.strip())
    
    # 사용되지 않는 import 찾기
    unused_imports = []
    
    for name in imported_names:
        # import 문 자체는 제외하고 사용 찾기
        pattern = rf'\b{name}\b'
        matches = re.findall(pattern, content)
        
        # import 문에서의 사용은 제외
        actual_usage = 0
        for match_line in content.split('\n'):
            if pattern in match_line and not ('import' in match_line):
                actual_usage += 1
        
        if actual_usage == 0:
            unused_imports.append(name)
    
    return imports, unused_imports

def main():
    filename = "../bosspong.py"
    
    print("=== 사용하지 않는 코드 분석 ===\n")
    
    # 사용하지 않는 함수 찾기
    print("1. 함수 분석:")
    unused_funcs, rarely_used_funcs, all_funcs = find_unused_functions(filename)
    
    if unused_funcs:
        print(f"\n   사용하지 않는 함수 ({len(unused_funcs)}개):")
        for func in unused_funcs[:10]:  # 처음 10개만 표시
            print(f"   - {func}()")
        if len(unused_funcs) > 10:
            print(f"   ... 외 {len(unused_funcs)-10}개")
    
    if rarely_used_funcs:
        print(f"\n   1번만 사용되는 함수 ({len(rarely_used_funcs)}개):")
        for func, count in rarely_used_funcs[:5]:
            print(f"   - {func}() : {count}회")
    
    # 사용하지 않는 변수 찾기
    print("\n2. 전역 변수 분석:")
    unused_vars, rarely_used_vars = find_unused_variables(filename)
    
    if unused_vars:
        print(f"\n   사용하지 않는 변수 ({len(unused_vars)}개):")
        for var, line in unused_vars[:10]:
            print(f"   - {var} (Line {line})")
    
    if rarely_used_vars:
        print(f"\n   1번만 사용되는 변수 ({len(rarely_used_vars)}개):")
        for var, line, count in rarely_used_vars[:5]:
            print(f"   - {var} (Line {line}): {count}회")
    
    # import 분석
    print("\n3. Import 분석:")
    imports, unused_imports = find_duplicate_imports(filename)
    
    print(f"   전체 import: {len(imports)}개")
    if unused_imports:
        print(f"\n   사용하지 않는 import ({len(unused_imports)}개):")
        for imp in unused_imports:
            print(f"   - {imp}")
    
    # 요약
    print("\n=== 제거 가능한 코드 요약 ===")
    print(f"- 사용하지 않는 함수: {len(unused_funcs)}개")
    print(f"- 사용하지 않는 변수: {len(unused_vars)}개")
    print(f"- 사용하지 않는 import: {len(unused_imports)}개")
    
    potential_lines = len(unused_funcs) * 5 + len(unused_vars) + len(unused_imports)
    print(f"\n예상 제거 가능 라인: 약 {potential_lines}줄")

if __name__ == "__main__":
    main()