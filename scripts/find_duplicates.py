#!/usr/bin/env python3
"""
Phase 13: Find and analyze duplicate code patterns
"""

import re
from collections import defaultdict

def find_duplicate_patterns():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Find duplicate function calls
    function_calls = defaultdict(list)
    
    # Common patterns to look for
    patterns = [
        # Draw patterns
        (r'draw\.(circle|rect|line)\([^)]+\)', 'Draw calls'),
        # Collision checks
        (r'(BALL|PLAYER|BOSS)\.colliderect\([^)]+\)', 'Collision checks'),
        # Sound plays
        (r'SOUND_\w+\.play\(\)', 'Sound plays'),
        # Random patterns
        (r'random\.(randint|uniform|choice)\([^)]+\)', 'Random calls'),
        # Math patterns
        (r'math\.(cos|sin|radians|hypot)\([^)]+\)', 'Math calls'),
        # Effect spawning
        (r'effects_manager\.\w+\([^)]*\)', 'Effect spawning'),
        # Item creation
        (r'create_\w+\([^)]*\)', 'Create functions'),
    ]
    
    results = {}
    
    for pattern, name in patterns:
        matches = defaultdict(list)
        for i, line in enumerate(lines):
            for match in re.finditer(pattern, line):
                matches[match.group()].append(i + 1)
        
        # Filter for duplicates (appearing 3+ times)
        duplicates = {k: v for k, v in matches.items() if len(v) >= 3}
        if duplicates:
            results[name] = duplicates
    
    # Find duplicate code blocks (3+ consecutive lines)
    code_blocks = defaultdict(list)
    for i in range(len(lines) - 2):
        block = ''.join(lines[i:i+3])
        if len(block.strip()) > 50:  # Meaningful blocks only
            code_blocks[block].append(i + 1)
    
    duplicate_blocks = {k: v for k, v in code_blocks.items() if len(v) >= 2}
    
    return results, duplicate_blocks

def analyze_similar_functions():
    """Find functions with similar structure"""
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find all function definitions
    function_pattern = r'def (\w+)\([^)]*\):(.*?)(?=\ndef|\nclass|\Z)'
    functions = re.findall(function_pattern, content, re.DOTALL)
    
    # Group by similar patterns
    similar_groups = defaultdict(list)
    
    for name, body in functions:
        # Skip very small functions
        if len(body) < 100:
            continue
            
        # Categorize by pattern
        if 'draw.circle' in body and 'draw.rect' in body:
            similar_groups['Drawing functions'].append(name)
        elif 'colliderect' in body and 'collision' in body.lower():
            similar_groups['Collision functions'].append(name)
        elif 'random' in body and 'spawn' in body.lower():
            similar_groups['Spawn functions'].append(name)
        elif 'for i in range' in body and 'append' in body:
            similar_groups['List generation'].append(name)
    
    return similar_groups

def main():
    print("=== Phase 13: Duplicate Code Analysis ===\n")
    
    # Find duplicate patterns
    patterns, blocks = find_duplicate_patterns()
    
    if patterns:
        print("📋 Duplicate Patterns Found:")
        for category, duplicates in patterns.items():
            print(f"\n{category}:")
            # Show top 5 most duplicated
            sorted_dups = sorted(duplicates.items(), key=lambda x: len(x[1]), reverse=True)[:5]
            for code, lines in sorted_dups:
                print(f"  • {code[:60]}... ({len(lines)} occurrences)")
    
    if blocks:
        print(f"\n📦 Duplicate Code Blocks: {len(blocks)} found")
        for i, (block, lines) in enumerate(list(blocks.items())[:3], 1):
            print(f"\nBlock {i} (Lines: {lines}):")
            print("  " + block[:150].replace('\n', '\n  ') + "...")
    
    # Analyze similar functions
    similar = analyze_similar_functions()
    
    if similar:
        print("\n🔄 Similar Function Groups:")
        for category, funcs in similar.items():
            if len(funcs) > 1:
                print(f"\n{category}: {', '.join(funcs[:5])}")
    
    # Suggestions
    print("\n💡 Refactoring Suggestions:")
    print("1. Create helper functions for repeated draw patterns")
    print("2. Consolidate collision detection logic")
    print("3. Create effect spawning utility functions")
    print("4. Merge similar random generation patterns")
    
    total_potential_reduction = len(blocks) * 3 + sum(len(v) for d in patterns.values() for v in d.values())
    print(f"\n📊 Potential line reduction: ~{total_potential_reduction} lines")

if __name__ == "__main__":
    main()
