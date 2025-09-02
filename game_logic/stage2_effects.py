"""
Stage 2 떨어지는 잎사귀 효과 모듈
"""

import pygame
import math
import random

# 전역 변수
stage2_leaves = []  # 나뭇잎 위치 리스트

def update_stage2_leaves():
    """떨어지는 잎사귀 업데이트"""
    global stage2_leaves
    new_leaves = []
    for leaf in stage2_leaves:
        # 잎사귀 위치 업데이트
        leaf['x'] += leaf['vx']
        leaf['y'] += leaf['vy']
        leaf['rotation'] += leaf['rotation_speed']
        leaf['life'] -= 1
        
        # 생명이 남아있는 잎사귀만 유지
        if leaf['life'] > 0:
            new_leaves.append(leaf)
    
    stage2_leaves = new_leaves

def draw_stage2_leaves(screen):
    """떨어지는 잎사귀 그리기 (디테일한 버전)"""
    for leaf in stage2_leaves:
        # 투명도 계산 (페이드 아웃 효과)
        alpha = min(255, leaf['life'] * 2)
        
        # 잎사귀 표면 생성
        leaf_surface = pygame.Surface((leaf['size'] * 2, leaf['size'] * 2), pygame.SRCALPHA)
        
        # 잎사귀 타입에 따른 그리기
        if leaf['type'] == 'maple':
            # 단풍잎 모양 그리기
            points = []
            for i in range(5):
                angle = i * 72 + leaf['rotation']
                x = leaf['size'] + math.cos(math.radians(angle)) * leaf['size']
                y = leaf['size'] + math.sin(math.radians(angle)) * leaf['size']
                points.append((x, y))
                # 내부 포인트
                inner_angle = angle + 36
                inner_x = leaf['size'] + math.cos(math.radians(inner_angle)) * leaf['size'] * 0.5
                inner_y = leaf['size'] + math.sin(math.radians(inner_angle)) * leaf['size'] * 0.5
                points.append((inner_x, inner_y))
            
            # 색상에 투명도 적용
            color_with_alpha = (*leaf['color'], alpha)
            pygame.draw.polygon(leaf_surface, color_with_alpha, points)
            
        elif leaf['type'] == 'oak':
            # 참나무 잎 (타원형)
            color_with_alpha = (*leaf['color'], alpha)
            # 회전된 타원 그리기
            rect = pygame.Rect(leaf['size'] // 2, leaf['size'] // 2, leaf['size'], leaf['size'] * 1.5)
            pygame.draw.ellipse(leaf_surface, color_with_alpha, rect)
            
        else:  # tropical
            # 열대 잎 (길쭉한 타원)
            color_with_alpha = (*leaf['color'], alpha)
            rect = pygame.Rect(leaf['size'] // 2, 0, leaf['size'] // 2, leaf['size'] * 2)
            pygame.draw.ellipse(leaf_surface, color_with_alpha, rect)
        
        # 회전 적용
        rotated_surface = pygame.transform.rotate(leaf_surface, leaf['rotation'])
        
        # 화면에 그리기
        screen.blit(rotated_surface, 
                   (leaf['x'] - rotated_surface.get_width() // 2,
                    leaf['y'] - rotated_surface.get_height() // 2))

def add_falling_leaf(x, y, direction='right'):
    """떨어지는 잎사귀 추가"""
    global stage2_leaves
    
    leaf_types = ['maple', 'oak', 'tropical']
    leaf = {
        'x': x,
        'y': y,
        'vx': random.uniform(1.0, 3.0) if direction == 'right' else random.uniform(-3.0, -1.0),
        'vy': random.uniform(0.5, 2.5),
        'rotation': random.uniform(0, 360),
        'rotation_speed': random.uniform(-8, 8),
        'type': random.choice(leaf_types),
        'color': random.choice([
            (34, 139, 34),  # 숲 녹색
            (0, 128, 0),    # 중간 녹색  
            (85, 107, 47),  # 올리브 녹색
            (107, 142, 35), # 황록색
            (154, 205, 50), # 연두색
            (50, 100, 50),  # 진한 녹색
        ]),
        'size': random.randint(12, 25),
        'life': 150  # 2.5초 동안 떨어짐
    }
    stage2_leaves.append(leaf)

def clear_stage2_leaves():
    """모든 잎사귀 제거"""
    global stage2_leaves
    stage2_leaves = []

def get_stage2_leaves():
    """현재 잎사귀 리스트 반환"""
    global stage2_leaves
    return stage2_leaves