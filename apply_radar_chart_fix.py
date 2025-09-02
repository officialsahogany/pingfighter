#!/usr/bin/env python3
"""
레이더 차트 UI 겹침 문제 수정 패치
pingfighter.py의 레이더 차트 함수를 개선된 버전으로 교체
"""

import sys
import os
import shutil
from datetime import datetime


def apply_radar_chart_fix():
    """레이더 차트 UI 개선 적용"""
    
    print("\n" + "="*60)
    print("🎯 레이더 차트 UI 겹침 문제 수정 패치")
    print("="*60)
    
    # 백업 생성
    source_file = "pingfighter.py"
    backup_file = f"pingfighter_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.py"
    
    print(f"\n1️⃣ 백업 생성 중...")
    try:
        shutil.copy(source_file, backup_file)
        print(f"   ✅ 백업 완료: {backup_file}")
    except Exception as e:
        print(f"   ❌ 백업 실패: {e}")
        return False
    
    # pingfighter.py 읽기
    print(f"\n2️⃣ {source_file} 읽는 중...")
    try:
        with open(source_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        print(f"   ✅ 파일 읽기 완료 ({len(lines)} 줄)")
    except Exception as e:
        print(f"   ❌ 파일 읽기 실패: {e}")
        return False
    
    # draw_ability_radar_chart 함수 찾기
    print(f"\n3️⃣ draw_ability_radar_chart 함수 찾는 중...")
    
    start_line = -1
    end_line = -1
    
    for i, line in enumerate(lines):
        if 'def draw_ability_radar_chart(' in line:
            start_line = i
            print(f"   ✅ 함수 시작 위치: Line {i+1}")
            
            # 함수 끝 찾기 (다음 def 또는 클래스 정의까지)
            for j in range(i+1, len(lines)):
                # 들여쓰기가 없는 def를 찾으면 함수 끝
                if lines[j].startswith('def ') or lines[j].startswith('class '):
                    end_line = j - 1
                    # 빈 줄 제거
                    while end_line > start_line and lines[end_line].strip() == '':
                        end_line -= 1
                    print(f"   ✅ 함수 끝 위치: Line {end_line+1}")
                    break
            break
    
    if start_line == -1 or end_line == -1:
        print("   ❌ draw_ability_radar_chart 함수를 찾을 수 없습니다.")
        return False
    
    # 개선된 함수 코드
    improved_function = '''def draw_ability_radar_chart(stats, center_x, center_y, radius=120):
    """능력치 레이더 차트 그리기 - UI 겹침 문제 수정 버전"""
    import math
    
    # 능력치 데이터 (0-100 범위로 정규화)
    abilities = {
        "스킬 활용": stats['skill_mastery_score'],
        "대쉬 활용": stats['dash_mastery_score'], 
        "아이템 활용": stats['item_mastery_score'],
        "가드 능력": stats['guard_ability_score']
    }
    
    # 능력치 수
    num_abilities = len(abilities)
    angle_step = 2 * math.pi / num_abilities
    
    # 배경 원형 그리드 그리기 (20, 40, 60, 80, 100%)
    for i in range(1, 6):
        grid_radius = radius * (i / 5)
        draw.circle((50, 50, 50), (center_x, center_y), int(grid_radius), 1)
    
    # 축 선 그리기
    ability_names = list(abilities.keys())
    points = []
    
    for i, ability_name in enumerate(ability_names):
        angle = -math.pi / 2 + i * angle_step  # -90도부터 시작 (위쪽)
        
        # 축 선 그리기
        end_x = center_x + math.cos(angle) * radius
        end_y = center_y + math.sin(angle) * radius
        draw.line((100, 100, 100), (center_x, center_y), (end_x, end_y), 1)
        
        # 능력치 값에 따른 점 위치 계산
        value = abilities[ability_name]
        value_radius = radius * (value / 100)
        point_x = center_x + math.cos(angle) * value_radius
        point_y = center_y + math.sin(angle) * value_radius
        points.append((point_x, point_y))
        
        # 능력명 텍스트 표시 - 개선된 위치 계산
        text_font = FontStyle.tiny()  # 16pt 픽셀 폰트
        
        # 라벨 거리를 동적으로 조정 (기존 30에서 25로 축소)
        label_distance = radius + 25
        text_x = center_x + math.cos(angle) * label_distance
        text_y = center_y + math.sin(angle) * label_distance
        
        # 등급 색상 적용
        grade, color = score_to_grade(value)
        ability_text = text_font.render(f"{ability_name}", True, WHITE)
        grade_text = text_font.render(f"({grade})", True, color)
        
        # 각 방향에 따른 정밀한 위치 조정
        ability_rect = ability_text.get_rect()
        grade_rect = grade_text.get_rect()
        
        # 위쪽 (스킬 활용) - 인덱스 0
        if i == 0:
            ability_rect.centerx = text_x
            ability_rect.bottom = text_y - 5
            grade_rect.centerx = text_x
            grade_rect.top = text_y - 3
        
        # 오른쪽 (대쉬 활용) - 인덱스 1, 문제가 되는 부분 수정
        elif i == 1:
            # 더 왼쪽으로 이동하고 위아래 간격 조정
            ability_rect.left = text_x + 5
            ability_rect.centery = text_y - 10
            grade_rect.left = text_x + 5
            grade_rect.centery = text_y + 6
        
        # 아래쪽 (아이템 활용) - 인덱스 2
        elif i == 2:
            ability_rect.centerx = text_x
            ability_rect.top = text_y + 5
            grade_rect.centerx = text_x
            grade_rect.top = text_y + 20
        
        # 왼쪽 (가드 능력) - 인덱스 3
        elif i == 3:
            ability_rect.right = text_x - 5
            ability_rect.centery = text_y - 10
            grade_rect.right = text_x - 5
            grade_rect.centery = text_y + 6
        
        # 화면 경계 체크 및 자동 조정
        if ability_rect.right > WIDTH - 10:
            offset = ability_rect.right - (WIDTH - 10)
            ability_rect.x -= offset
            grade_rect.x -= offset
        
        if ability_rect.left < 10:
            offset = 10 - ability_rect.left
            ability_rect.x += offset
            grade_rect.x += offset
        
        SCREEN.blit(ability_text, ability_rect)
        SCREEN.blit(grade_text, grade_rect)
    
    # 능력치 영역 채우기 (반투명)
    if len(points) >= 3:
        # 반투명 서페이스 생성
        overlay = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
        
        # 중심을 기준으로 좌표 변환
        relative_points = [(x - center_x + radius, y - center_y + radius) for x, y in points]
        pygame.draw.polygon(overlay, (100, 150, 255, 80), relative_points)
        SCREEN.blit(overlay, (center_x - radius, center_y - radius))
    
    # 능력치 점들을 선으로 연결
    if len(points) >= 2:
        draw.polygon((100, 150, 255), points, 2)
    
    # 능력치 점 표시
    for point in points:
        draw.circle(WHITE, (int(point[0]), int(point[1])), 4)
        draw.circle((100, 150, 255), (int(point[0]), int(point[1])), 3)
    
    # 중심점 표시
    draw.circle((200, 200, 200), (center_x, center_y), 3)
    
    # 퍼센트 표시 - 우측 상단 대각선 방향으로 이동
    percent_font = get_font(10)  # 더 작은 폰트
    for i in range(1, 6):
        percent = i * 20
        # 우측 상단 대각선 (45도)에 배치
        angle = -math.pi / 4
        percent_x = center_x + math.cos(angle) * (radius * (i / 5))
        percent_y = center_y + math.sin(angle) * (radius * (i / 5))
        
        percent_text = percent_font.render(f"{percent}", True, (150, 150, 150))
        percent_rect = percent_text.get_rect(center=(percent_x + 10, percent_y - 5))
        SCREEN.blit(percent_text, percent_rect)
'''
    
    # 함수 교체
    print(f"\n4️⃣ 함수 교체 중...")
    
    # 새로운 라인 리스트 생성
    new_lines = lines[:start_line] + [improved_function + '\n'] + lines[end_line+1:]
    
    # 파일 쓰기
    print(f"\n5️⃣ 수정된 파일 저장 중...")
    try:
        with open(source_file, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        print(f"   ✅ 파일 저장 완료")
    except Exception as e:
        print(f"   ❌ 파일 저장 실패: {e}")
        return False
    
    print("\n" + "="*60)
    print("✅ 레이더 차트 UI 수정 완료!")
    print("="*60)
    print("\n다음 변경사항이 적용되었습니다:")
    print("• 라벨 거리 조정: radius + 30 → radius + 25")
    print("• 오른쪽 라벨 위치 미세 조정")
    print("• 화면 경계 자동 체크 및 조정")
    print("• 퍼센트 표시 위치를 우측 상단 대각선으로 이동")
    print("• 폰트 크기 최적화")
    print("\n게임을 실행하여 확인해보세요!")
    
    return True


if __name__ == "__main__":
    success = apply_radar_chart_fix()
    if not success:
        print("\n⚠️ 패치 적용에 실패했습니다. 백업 파일을 확인하세요.")
        sys.exit(1)