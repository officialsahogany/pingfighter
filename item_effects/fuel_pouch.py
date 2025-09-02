"""
연료파우치 아이템 효과
획득 시 최대 스킬 게이지가 100 증가합니다.
"""

import pygame

class FuelPouch:
    def __init__(self):
        self.active = False
        self.gauge_bonus = 100  # 최대 게이지 증가량
        self.original_max_gauge = None  # 원래 최대 게이지 저장
        
    def activate(self, game_state, current_stage):
        """연료파우치 아이템 활성화"""
        if not self.active:
            self.active = True
            # 게임 상태에서 최대 게이지 증가
            if 'max_gauge' in game_state:
                if self.original_max_gauge is None:
                    self.original_max_gauge = game_state['max_gauge']
                game_state['max_gauge'] += self.gauge_bonus
                # 현재 게이지도 비율에 맞게 조정
                if 'gauge' in game_state:
                    gauge_ratio = game_state['gauge'] / self.original_max_gauge
                    game_state['gauge'] = int(gauge_ratio * game_state['max_gauge'])
        
    def deactivate(self):
        """연료파우치 비활성화 (스테이지 종료 시)"""
        self.active = False
        # 최대 게이지 원래대로 복원은 메인 게임에서 처리
        
    def update(self, current_stage):
        """상태 업데이트 (패시브 아이템이므로 특별한 업데이트 없음)"""
        pass
    
    def draw_effects(self, screen, **kwargs):
        """시각 효과 그리기 (패시브 아이템이므로 특별한 효과 없음)"""
        pass
    
    def get_gauge_bonus(self):
        """게이지 보너스 반환"""
        return self.gauge_bonus if self.active else 0

# 싱글톤 인스턴스
fuel_pouch_instance = None

def get_fuel_pouch_instance():
    global fuel_pouch_instance
    if fuel_pouch_instance is None:
        fuel_pouch_instance = FuelPouch()
    return fuel_pouch_instance

def activate_fuel_pouch(game_state, current_stage):
    """연료파우치 활성화"""
    pouch = get_fuel_pouch_instance()
    pouch.activate(game_state, current_stage)
    return pouch.get_gauge_bonus()

def deactivate_fuel_pouch():
    """연료파우치 비활성화"""
    pouch = get_fuel_pouch_instance()
    pouch.deactivate()

def update_fuel_pouch(current_stage):
    """연료파우치 업데이트"""
    pouch = get_fuel_pouch_instance()
    pouch.update(current_stage)

def draw_fuel_pouch_effects(screen, **kwargs):
    """연료파우치 효과 그리기"""
    pouch = get_fuel_pouch_instance()
    pouch.draw_effects(screen, **kwargs)

def get_fuel_pouch_gauge_bonus():
    """현재 연료파우치의 게이지 보너스 반환"""
    pouch = get_fuel_pouch_instance()
    return pouch.get_gauge_bonus()