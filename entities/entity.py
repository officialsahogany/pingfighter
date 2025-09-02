"""
Entity Manager - 엔티티 시스템
모든 게임 오브젝트 관리
"""

import pygame
from typing import Dict, List, Optional, Any
from core.global_manager import GlobalManager
from core.events import EventType, emit_event


class Entity:
    """기본 엔티티 클래스"""
    
    def __init__(self, entity_type: str, x: float, y: float):
        self.type = entity_type
        self.x = x
        self.y = y
        self.active = True
        self.components = {}
        
    def add_component(self, name: str, component: Any):
        """컴포넌트 추가"""
        self.components[name] = component
        
    def get_component(self, name: str) -> Any:
        """컴포넌트 가져오기"""
        return self.components.get(name)
        
    def update(self, dt: float):
        """엔티티 업데이트"""
        pass
        
    def render(self, screen: pygame.Surface):
        """엔티티 렌더링"""
        pass


class EntityManager:
    """엔티티 관리 시스템"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        
        # 엔티티 저장소
        self.entities = {}
        self.entity_groups = {
            'players': [],
            'bosses': [],
            'balls': [],
            'items': [],
            'effects': [],
            'walls': [],
            'projectiles': []
        }
        
        # 엔티티 ID 카운터
        self.next_id = 1
        
        # 기본 엔티티 초기화
        self.init_core_entities()
        
    def init_core_entities(self):
        """핵심 엔티티 초기화"""
        # 플레이어 엔티티
        player = self.create_entity('player', 300, 650)
        player_rect = pygame.Rect(250, 640, 100, 20)
        player.add_component('rect', player_rect)
        player.add_component('speed', 5)
        self.global_manager.set('PLAYER', player_rect)
        
        # 보스 엔티티
        boss = self.create_entity('boss', 300, 100)
        boss_rect = pygame.Rect(250, 80, 100, 20)
        boss.add_component('rect', boss_rect)
        boss.add_component('speed', 6)
        self.global_manager.set('BOSS', boss_rect)
        
        # 공 엔티티
        ball = self.create_entity('ball', 300, 375)
        ball_rect = pygame.Rect(285, 360, 30, 30)
        ball.add_component('rect', ball_rect)
        ball.add_component('velocity', [0, 5])
        self.global_manager.set('BALL', ball_rect)
        
    def create_entity(self, entity_type: str, x: float, y: float) -> Entity:
        """엔티티 생성
        
        Args:
            entity_type: 엔티티 타입
            x: X 좌표
            y: Y 좌표
            
        Returns:
            생성된 엔티티
        """
        entity = Entity(entity_type, x, y)
        entity_id = self.next_id
        self.next_id += 1
        
        # 저장소에 추가
        self.entities[entity_id] = entity
        
        # 그룹에 추가
        if entity_type == 'player':
            self.entity_groups['players'].append(entity_id)
        elif entity_type == 'boss':
            self.entity_groups['bosses'].append(entity_id)
        elif entity_type == 'ball':
            self.entity_groups['balls'].append(entity_id)
        elif entity_type == 'item':
            self.entity_groups['items'].append(entity_id)
        elif entity_type == 'effect':
            self.entity_groups['effects'].append(entity_id)
        elif entity_type == 'wall':
            self.entity_groups['walls'].append(entity_id)
        elif entity_type == 'projectile':
            self.entity_groups['projectiles'].append(entity_id)
            
        return entity
        
    def remove_entity(self, entity_id: int):
        """엔티티 제거
        
        Args:
            entity_id: 엔티티 ID
        """
        if entity_id not in self.entities:
            return
            
        entity = self.entities[entity_id]
        
        # 그룹에서 제거
        for group in self.entity_groups.values():
            if entity_id in group:
                group.remove(entity_id)
                
        # 저장소에서 제거
        del self.entities[entity_id]
        
    def get_entity(self, entity_id: int) -> Optional[Entity]:
        """엔티티 가져오기
        
        Args:
            entity_id: 엔티티 ID
            
        Returns:
            엔티티 또는 None
        """
        return self.entities.get(entity_id)
        
    def get_entities_by_type(self, entity_type: str) -> List[Entity]:
        """타입별 엔티티 목록 가져오기
        
        Args:
            entity_type: 엔티티 타입
            
        Returns:
            엔티티 목록
        """
        result = []
        
        if entity_type in ['player', 'boss', 'ball', 'item', 'effect', 'wall', 'projectile']:
            group_name = entity_type + 's'
            for entity_id in self.entity_groups.get(group_name, []):
                entity = self.entities.get(entity_id)
                if entity and entity.active:
                    result.append(entity)
                    
        return result
        
    def create_wall(self, x: float, y: float, width: float, height: float) -> Entity:
        """벽 생성
        
        Args:
            x: X 좌표
            y: Y 좌표
            width: 너비
            height: 높이
            
        Returns:
            생성된 벽 엔티티
        """
        wall = self.create_entity('wall', x, y)
        wall_rect = pygame.Rect(x, y, width, height)
        wall.add_component('rect', wall_rect)
        wall.add_component('health', 3)  # 3번 맞으면 파괴
        
        return wall
        
    def create_projectile(self, x: float, y: float, vel_x: float, vel_y: float, 
                         projectile_type: str = 'normal') -> Entity:
        """투사체 생성
        
        Args:
            x: X 좌표
            y: Y 좌표
            vel_x: X 속도
            vel_y: Y 속도
            projectile_type: 투사체 타입
            
        Returns:
            생성된 투사체 엔티티
        """
        projectile = self.create_entity('projectile', x, y)
        projectile.add_component('velocity', [vel_x, vel_y])
        projectile.add_component('projectile_type', projectile_type)
        projectile.add_component('damage', 1)
        
        # 타입별 특성
        if projectile_type == 'fireball':
            projectile.add_component('damage', 2)
            projectile.add_component('size', 20)
        elif projectile_type == 'laser':
            projectile.add_component('damage', 3)
            projectile.add_component('size', 5)
            
        return projectile
        
    def create_effect(self, x: float, y: float, effect_type: str, duration: float = 1.0) -> Entity:
        """이펙트 생성
        
        Args:
            x: X 좌표
            y: Y 좌표
            effect_type: 이펙트 타입
            duration: 지속 시간
            
        Returns:
            생성된 이펙트 엔티티
        """
        effect = self.create_entity('effect', x, y)
        effect.add_component('effect_type', effect_type)
        effect.add_component('duration', duration)
        effect.add_component('timer', 0)
        
        # 타입별 특성
        if effect_type == 'explosion':
            effect.add_component('radius', 50)
            effect.add_component('particles', [])
        elif effect_type == 'spark':
            effect.add_component('color', (255, 255, 0))
            
        return effect
        
    def update(self, dt: float):
        """모든 엔티티 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 비활성 엔티티 제거
        to_remove = []
        for entity_id, entity in self.entities.items():
            if not entity.active:
                to_remove.append(entity_id)
                
        for entity_id in to_remove:
            self.remove_entity(entity_id)
            
        # 활성 엔티티 업데이트
        for entity in self.entities.values():
            if entity.active:
                entity.update(dt)
                
                # 투사체 업데이트
                if entity.type == 'projectile':
                    self.update_projectile(entity, dt)
                    
                # 이펙트 업데이트
                elif entity.type == 'effect':
                    self.update_effect(entity, dt)
                    
    def update_projectile(self, projectile: Entity, dt: float):
        """투사체 업데이트
        
        Args:
            projectile: 투사체 엔티티
            dt: 델타 타임
        """
        velocity = projectile.get_component('velocity')
        if velocity:
            projectile.x += velocity[0] * dt * 60
            projectile.y += velocity[1] * dt * 60
            
            # 화면 밖으로 나가면 비활성화
            if projectile.x < 0 or projectile.x > self.global_manager.get('WIDTH', 600) or \
               projectile.y < 0 or projectile.y > self.global_manager.get('HEIGHT', 750):
                projectile.active = False
                
    def update_effect(self, effect: Entity, dt: float):
        """이펙트 업데이트
        
        Args:
            effect: 이펙트 엔티티
            dt: 델타 타임
        """
        timer = effect.get_component('timer')
        duration = effect.get_component('duration')
        
        if timer is not None and duration is not None:
            timer += dt
            effect.components['timer'] = timer
            
            # 지속 시간이 끝나면 비활성화
            if timer >= duration:
                effect.active = False
                
    def render(self, screen: pygame.Surface):
        """모든 엔티티 렌더링
        
        Args:
            screen: 화면 Surface
        """
        # 렌더링 순서: 벽 -> 아이템 -> 투사체 -> 이펙트
        for group_name in ['walls', 'items', 'projectiles', 'effects']:
            for entity_id in self.entity_groups[group_name]:
                entity = self.entities.get(entity_id)
                if entity and entity.active:
                    self.render_entity(screen, entity)
                    
    def render_entity(self, screen: pygame.Surface, entity: Entity):
        """개별 엔티티 렌더링
        
        Args:
            screen: 화면 Surface
            entity: 엔티티
        """
        if entity.type == 'wall':
            rect = entity.get_component('rect')
            if rect:
                pygame.draw.rect(screen, (128, 128, 128), rect)
                
        elif entity.type == 'projectile':
            projectile_type = entity.get_component('projectile_type')
            size = entity.get_component('size', 10)
            
            if projectile_type == 'fireball':
                pygame.draw.circle(screen, (255, 100, 0), (int(entity.x), int(entity.y)), size)
            elif projectile_type == 'laser':
                pygame.draw.circle(screen, (0, 255, 255), (int(entity.x), int(entity.y)), size)
            else:
                pygame.draw.circle(screen, (255, 255, 255), (int(entity.x), int(entity.y)), size)
                
        elif entity.type == 'effect':
            effect_type = entity.get_component('effect_type')
            timer = entity.get_component('timer', 0)
            
            if effect_type == 'explosion':
                radius = entity.get_component('radius', 50)
                alpha = max(0, 255 - int(timer * 500))  # 페이드 아웃
                color = (*[255, 100, 0], alpha)
                
                # 투명도가 있는 원 그리기
                s = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(s, color, (radius, radius), radius)
                screen.blit(s, (entity.x - radius, entity.y - radius))
                
    def clear(self):
        """모든 엔티티 제거"""
        self.entities.clear()
        for group in self.entity_groups.values():
            group.clear()
        self.next_id = 1
        
        # 핵심 엔티티 재초기화
        self.init_core_entities()
        
    def get_stats(self) -> Dict:
        """엔티티 통계 반환"""
        return {
            'total_entities': len(self.entities),
            'players': len(self.entity_groups['players']),
            'bosses': len(self.entity_groups['bosses']),
            'balls': len(self.entity_groups['balls']),
            'items': len(self.entity_groups['items']),
            'effects': len(self.entity_groups['effects']),
            'walls': len(self.entity_groups['walls']),
            'projectiles': len(self.entity_groups['projectiles'])
        }


# 싱글톤 인스턴스
_entity_manager = None

def get_entity_manager() -> EntityManager:
    """엔티티 매니저 싱글톤 반환"""
    global _entity_manager
    if _entity_manager is None:
        _entity_manager = EntityManager()
    return _entity_manager