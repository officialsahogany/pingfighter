"""
HUD 디스플레이 래퍼 모듈
전역 변수들을 사용하는 원본 함수들을 위한 래퍼
"""

import pygame
import math
from ui.hud_display import HUDDisplay

# 전역 변수 참조를 위한 플레이스홀더
_globals = {}

def set_globals(globals_dict):
    """전역 변수 설정"""
    global _globals
    _globals = globals_dict

def draw_dash_spirit_lasers():
    """대쉬 스피릿 레이저 그리기 - 광선검 스타일 (원본 호환)"""
    # 전역 변수 가져오기
    dash_spirit_lasers = _globals.get('dash_spirit_lasers', [])
    WIDTH = _globals.get('WIDTH', 600)
    HEIGHT = _globals.get('HEIGHT', 750)
    SCREEN = _globals.get('SCREEN')
    DASH_SPIRIT_LASER_WIDTH = _globals.get('DASH_SPIRIT_LASER_WIDTH', 8)
    DASH_SPIRIT_LASER_COLOR = _globals.get('DASH_SPIRIT_LASER_COLOR', (100, 200, 255))
    
    if not SCREEN:
        return
        
    for laser in dash_spirit_lasers:
        # 투명도 적용을 위한 서페이스 생성
        laser_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        
        start_x, start_y = laser['start_x'], laser['start_y']
        end_x, end_y = laser['end_x'], laser['end_y']
        
        # 레이저 길이 계산
        laser_length = ((end_x - start_x)**2 + (end_y - start_y)**2)**0.5
        
        if laser_length > 0:
            # 🌟 광선검 스타일 레이저 그리기
            
            # 1. 외곽 광선 (가장 넓고 투명한 광선)
            outer_width = int(DASH_SPIRIT_LASER_WIDTH * 3)
            outer_alpha = laser['alpha'] // 6
            pygame.draw.line(laser_surface, (*DASH_SPIRIT_LASER_COLOR, outer_alpha),
                           (int(start_x), int(start_y)), (int(end_x), int(end_y)), outer_width)
            
            # 2. 중간 광선 (밝은 하늘색)
            middle_width = int(DASH_SPIRIT_LASER_WIDTH * 2)
            middle_alpha = laser['alpha'] // 3
            pygame.draw.line(laser_surface, (*DASH_SPIRIT_LASER_COLOR, middle_alpha),
                           (int(start_x), int(start_y)), (int(end_x), int(end_y)), middle_width)
            
            # 3. 내부 광선 (더 밝은 하늘색)
            inner_width = DASH_SPIRIT_LASER_WIDTH
            inner_alpha = laser['alpha'] // 2
            pygame.draw.line(laser_surface, (200, 230, 255, inner_alpha),
                           (int(start_x), int(start_y)), (int(end_x), int(end_y)), inner_width)
            
            # 4. 핵심 광선 (밝은 흰색 코어)
            core_width = max(2, DASH_SPIRIT_LASER_WIDTH // 3)
            core_alpha = min(255, laser['alpha'])
            pygame.draw.line(laser_surface, (255, 255, 255, core_alpha),
                           (int(start_x), int(start_y)), (int(end_x), int(end_y)), core_width)
            
            # 🌟 광선검 특유의 에너지 파티클 효과
            for i in range(3):
                particle_x = start_x + (end_x - start_x) * (i + 1) / 4
                particle_y = start_y + (end_y - start_y) * (i + 1) / 4
                particle_radius = max(3, inner_width // 2)
                particle_alpha = laser['alpha'] // 4
                pygame.draw.circle(laser_surface, (255, 255, 255, particle_alpha),
                                 (int(particle_x), int(particle_y)), particle_radius)
            
            # 시작점 광원 효과
            start_glow_radius = DASH_SPIRIT_LASER_WIDTH * 2
            pygame.draw.circle(laser_surface, (*DASH_SPIRIT_LASER_COLOR, laser['alpha'] // 4),
                             (int(start_x), int(start_y)), start_glow_radius)
            
            # 끝점 충격 효과
            end_impact_radius = DASH_SPIRIT_LASER_WIDTH * 3
            for i in range(3):
                impact_alpha = laser['alpha'] // (6 + i * 2)
                impact_radius = end_impact_radius + i * 5
                pygame.draw.circle(laser_surface, (*DASH_SPIRIT_LASER_COLOR, impact_alpha),
                                 (int(end_x), int(end_y)), impact_radius, 2)
            
            # 화면에 블렌딩
            SCREEN.blit(laser_surface, (0, 0), special_flags=pygame.BLEND_ADD)