#!/usr/bin/env python3
"""
모든 pygame.draw 호출을 포괄적으로 대체하는 스크립트
"""

import re
from typing import List, Tuple

def replace_all_pygame_draws(content: str) -> Tuple[str, int]:
    """
    모든 pygame.draw 호출을 대체
    """
    replacements = 0
    
    # 줄바꿈이 포함된 호출도 처리
    content = re.sub(r'\n\s+', ' ', content, flags=re.MULTILINE)  # 여러 줄에 걸친 호출 정리
    
    # pygame.draw.rect - 더 포괄적인 패턴
    patterns = [
        (r'pygame\.draw\.rect\s*\(\s*SCREEN\s*,', 'draw.rect('),
        (r'pygame\.draw\.circle\s*\(\s*SCREEN\s*,', 'draw.circle('),
        (r'pygame\.draw\.line\s*\(\s*SCREEN\s*,', 'draw.line('),
        (r'pygame\.draw\.lines\s*\(\s*SCREEN\s*,', 'draw.lines('),
        (r'pygame\.draw\.polygon\s*\(\s*SCREEN\s*,', 'draw.polygon('),
        (r'pygame\.draw\.ellipse\s*\(\s*SCREEN\s*,', 'draw.ellipse('),
        (r'pygame\.draw\.arc\s*\(\s*SCREEN\s*,', 'draw.arc('),
    ]
    
    for pattern, replacement in patterns:
        matches = re.findall(pattern, content)
        replacements += len(matches)
        content = re.sub(pattern, replacement, content)
    
    # Surface 변수들에 대한 draw 호출도 처리
    surface_vars = ['surface', 'surf', 'trajectory_surface', 'glow_surface', 
                   'text_surface', 'boss_surface', 'overlay', 'screen']
    
    for var in surface_vars:
        patterns = [
            (f'pygame\.draw\.rect\s*\(\s*{var}\s*,', f'pygame.draw.rect({var},'),  # 이건 그대로 둠
            (f'pygame\.draw\.circle\s*\(\s*{var}\s*,', f'pygame.draw.circle({var},'),
            (f'pygame\.draw\.line\s*\(\s*{var}\s*,', f'pygame.draw.line({var},'),
        ]
        # Surface 변수는 DrawHelper를 사용할 수 없으므로 그대로 둠
    
    return content, replacements

def add_ellipse_arc_methods():
    """
    DrawHelper에 ellipse와 arc 메서드 추가
    """
    return '''
    def ellipse(self, color: Tuple[int, int, int], rect: pygame.Rect, width: int = 0):
        """타원 그리기"""
        pygame.draw.ellipse(self.screen, color, rect, width)
    
    def arc(self, color: Tuple[int, int, int], rect: pygame.Rect, 
            start_angle: float, stop_angle: float, width: int = 1):
        """호 그리기"""
        pygame.draw.arc(self.screen, color, rect, start_angle, stop_angle, width)
'''

def main():
    """메인 함수"""
    
    # bosspong.py 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 원본 백업
    with open('bosspong_backup_comprehensive.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    # 변환 수행
    new_content, count = replace_all_pygame_draws(content)
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"✅ {count}개의 pygame.draw 호출을 DrawHelper로 대체했습니다.")
    print(f"📁 원본 백업: bosspong_backup_comprehensive.py")
    
    # DrawHelper에 추가할 메서드 출력
    print("\n📝 DrawHelper에 다음 메서드를 추가해야 합니다:")
    print(add_ellipse_arc_methods())
    
    # 실제 줄 수 감소 계산
    original_size = len(content)
    new_size = len(new_content)
    size_reduction = original_size - new_size
    print(f"📉 문자 수 감소: {size_reduction} ({size_reduction//80}줄 예상)")

if __name__ == "__main__":
    main()