#!/usr/bin/env python3
"""
Phase 12: Extract remaining magic numbers to constants
Focuses on commonly used numbers that appear multiple times
"""

import re
from collections import Counter

def analyze_magic_numbers():
    with open('../bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find all numbers in the code
    numbers = re.findall(r'\b\d+\b', content)
    
    # Count occurrences
    number_counts = Counter(numbers)
    
    # Filter for numbers that appear frequently and are not 0,1,2
    significant_numbers = {
        num: count for num, count in number_counts.items()
        if count > 5 and int(num) > 2 and int(num) < 10000
    }
    
    # Sort by frequency
    sorted_numbers = sorted(significant_numbers.items(), key=lambda x: x[1], reverse=True)
    
    print("=== Magic Numbers Analysis ===")
    print(f"Total unique numbers: {len(number_counts)}")
    print(f"\nFrequently used numbers (>5 occurrences):")
    
    for num, count in sorted_numbers[:30]:
        print(f"  {num}: {count} occurrences")
    
    return sorted_numbers

def extract_common_constants():
    """Extract the most common magic numbers as constants"""
    
    with open('../bosspong.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Constants to add based on analysis
    new_constants = {
        # Animation and timing
        '10': 'DEFAULT_TIMER',
        '20': 'DEFAULT_COOLDOWN', 
        '30': 'MEDIUM_TIMER',
        '60': 'LONG_TIMER',
        '100': 'PERCENT_MAX',
        '180': 'HALF_CIRCLE_DEGREES',
        '360': 'FULL_CIRCLE_DEGREES',
        
        # Sizes and distances
        '50': 'SMALL_RADIUS',
        '80': 'MEDIUM_RADIUS',
        '200': 'LARGE_DISTANCE',
        '300': 'MAX_DISTANCE',
        '400': 'SCREEN_BOUNDARY',
        '500': 'LARGE_BOUNDARY',
        
        # Game mechanics
        '1000': 'MILLISECOND_MULTIPLIER',
        '3000': 'THREE_SECONDS_MS',
        '5000': 'FIVE_SECONDS_MS',
        
        # Colors (RGB values)
        '255': 'MAX_COLOR_VALUE',
        '128': 'HALF_COLOR_VALUE',
    }
    
    # Find where to insert constants (after existing constants)
    insert_line = 0
    for i, line in enumerate(lines):
        if 'COLOR_20 =' in line:
            insert_line = i + 1
            break
    
    if insert_line == 0:
        print("Could not find insertion point!")
        return
    
    # Create constant definitions
    constant_lines = ["\n# === Phase 12: Extracted Magic Numbers ===\n"]
    
    # Group constants by category
    constant_lines.append("# Animation and Timing\n")
    for value, name in sorted(new_constants.items()):
        if 'TIMER' in name or 'COOLDOWN' in name or 'DEGREES' in name:
            constant_lines.append(f"{name} = {value}\n")
    
    constant_lines.append("\n# Sizes and Distances\n")
    for value, name in sorted(new_constants.items()):
        if 'RADIUS' in name or 'DISTANCE' in name or 'BOUNDARY' in name:
            constant_lines.append(f"{name} = {value}\n")
    
    constant_lines.append("\n# Game Mechanics\n")
    for value, name in sorted(new_constants.items()):
        if 'MILLISECOND' in name or 'SECONDS_MS' in name:
            constant_lines.append(f"{name} = {value}\n")
    
    constant_lines.append("\n# Color Values\n")
    for value, name in sorted(new_constants.items()):
        if 'COLOR_VALUE' in name:
            constant_lines.append(f"{name} = {value}\n")
    
    constant_lines.append("# === End Phase 12 Constants ===\n\n")
    
    # Insert constants
    lines[insert_line:insert_line] = constant_lines
    
    # Now replace common patterns
    content = ''.join(lines)
    
    # Replace common patterns (carefully to avoid breaking things)
    replacements = [
        # Timer patterns
        (r'\b10\b(?=\s*[,\)])(?!.*COLOR)', 'DEFAULT_TIMER'),
        (r'range\(360\)', 'range(FULL_CIRCLE_DEGREES)'),
        (r'random\.randint\(0,\s*360\)', 'random.randint(0, FULL_CIRCLE_DEGREES)'),
        
        # Distance patterns  
        (r'math\.hypot\([^)]+\)\s*<\s*50\b', lambda m: m.group(0).replace('50', 'SMALL_RADIUS')),
        (r'math\.hypot\([^)]+\)\s*<\s*80\b', lambda m: m.group(0).replace('80', 'MEDIUM_RADIUS')),
        
        # Time patterns (milliseconds)
        (r'\b1000\b(?=\s*[*/])', 'MILLISECOND_MULTIPLIER'),
        (r'\b3000\b(?!.*COLOR)', 'THREE_SECONDS_MS'),
        (r'\b5000\b(?!.*COLOR)', 'FIVE_SECONDS_MS'),
    ]
    
    replace_count = 0
    for pattern, replacement in replacements:
        if callable(replacement):
            matches = list(re.finditer(pattern, content))
            replace_count += len(matches)
            content = re.sub(pattern, replacement, content)
        else:
            matches = re.findall(pattern, content)
            replace_count += len(matches)
            content = re.sub(pattern, replacement, content)
    
    # Write back
    with open('../bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"\n✅ Added {len(constant_lines)-4} new constants")
    print(f"✅ Replaced {replace_count} magic number occurrences")
    
    return len(constant_lines), replace_count

if __name__ == "__main__":
    # First analyze
    print("Analyzing magic numbers in bosspong.py...")
    sorted_numbers = analyze_magic_numbers()
    
    print("\n" + "="*50)
    print("Extracting common constants...")
    
    # Extract and replace
    constants_added, replacements_made = extract_common_constants()
    
    print("\n" + "="*50)
    print("Phase 12 Complete!")
    print(f"Total constants added: {constants_added}")
    print(f"Total replacements: {replacements_made}")
