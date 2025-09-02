# -*- coding: utf-8 -*-
"""
충돌 감지 시스템
모든 게임 객체 간의 충돌을 감지하고 처리
"""

import pygame
import math
from typing import List, Tuple, Optional, Dict, Any
from enum import Enum


class CollisionType(Enum):
    """충돌 타입"""
    BALL_PADDLE = "ball_paddle"
    BALL_BOSS = "ball_boss"
    BALL_WALL = "ball_wall"
    BALL_ITEM = "ball_item"
    PADDLE_ITEM = "paddle_item"
    BALL_PROJECTILE = "ball_projectile"


class CollisionSystem:
    """충돌 감지 및 처리 시스템
    
    게임 내 모든 객체 간의 충돌을 효율적으로 감지하고
    충돌 이벤트를 생성합니다.
    """
    
    def __init__(self):
        """충돌 시스템 초기화"""
        self.collision_callbacks = {}
        self.collision_layers = {}
        self.active_collisions = set()
        
        # 충돌 감지 최적화
        self.spatial_grid = None
        self.grid_size = 50
        
    def register_callback(self, collision_type: CollisionType, callback):
        """충돌 콜백 등록
        
        Args:
            collision_type: 충돌 타입
            callback: 충돌 시 호출될 콜백 함수
        """
        if collision_type not in self.collision_callbacks:
            self.collision_callbacks[collision_type] = []
        self.collision_callbacks[collision_type].append(callback)
    
    def check_collisions(self, entities: Dict[str, List[Any]]):
        """모든 충돌 검사
        
        Args:
            entities: 엔티티 딕셔너리 {"balls": [...], "paddles": [...], ...}
        """
        # 공과 패들 충돌
        if "balls" in entities and "paddles" in entities:
            for ball in entities["balls"]:
                for paddle in entities["paddles"]:
                    if self.check_ball_paddle_collision(ball, paddle):
                        self._trigger_collision(CollisionType.BALL_PADDLE, ball, paddle)
        
        # 공과 보스 충돌
        if "balls" in entities and "boss" in entities:
            for ball in entities["balls"]:
                if self.check_ball_paddle_collision(ball, entities["boss"]):
                    self._trigger_collision(CollisionType.BALL_BOSS, ball, entities["boss"])
        
        # 공과 아이템 충돌
        if "balls" in entities and "items" in entities:
            for ball in entities["balls"]:
                for item in entities["items"]:
                    if self.check_circle_rect_collision(ball, item):
                        self._trigger_collision(CollisionType.BALL_ITEM, ball, item)
        
        # 패들과 아이템 충돌
        if "paddles" in entities and "items" in entities:
            for paddle in entities["paddles"]:
                for item in entities["items"]:
                    if self.check_rect_rect_collision(paddle, item):
                        self._trigger_collision(CollisionType.PADDLE_ITEM, paddle, item)
    
    def check_ball_paddle_collision(self, ball, paddle) -> bool:
        """공과 패들 충돌 검사
        
        Args:
            ball: 공 객체
            paddle: 패들 객체
            
        Returns:
            bool: 충돌 여부
        """
        if not hasattr(ball, 'x') or not hasattr(paddle, 'rect'):
            return False
        
        # 공의 바운딩 박스
        ball_rect = pygame.Rect(
            ball.x - ball.radius,
            ball.y - ball.radius,
            ball.radius * 2,
            ball.radius * 2
        )
        
        # 초기 충돌 검사
        if not ball_rect.colliderect(paddle.rect):
            return False
        
        # 정밀 충돌 검사 (원과 사각형)
        return self._circle_rect_collision(
            ball.x, ball.y, ball.radius,
            paddle.rect.x, paddle.rect.y, paddle.rect.width, paddle.rect.height
        )
    
    def check_circle_rect_collision(self, circle_obj, rect_obj) -> bool:
        """원과 사각형 충돌 검사
        
        Args:
            circle_obj: 원형 객체 (x, y, radius 속성 필요)
            rect_obj: 사각형 객체 (rect 속성 필요)
            
        Returns:
            bool: 충돌 여부
        """
        if not hasattr(circle_obj, 'x') or not hasattr(rect_obj, 'rect'):
            return False
        
        return self._circle_rect_collision(
            circle_obj.x, circle_obj.y, circle_obj.radius,
            rect_obj.rect.x, rect_obj.rect.y, 
            rect_obj.rect.width, rect_obj.rect.height
        )
    
    def check_rect_rect_collision(self, obj1, obj2) -> bool:
        """사각형과 사각형 충돌 검사
        
        Args:
            obj1: 첫 번째 사각형 객체
            obj2: 두 번째 사각형 객체
            
        Returns:
            bool: 충돌 여부
        """
        if not hasattr(obj1, 'rect') or not hasattr(obj2, 'rect'):
            return False
        
        return obj1.rect.colliderect(obj2.rect)
    
    def check_circle_circle_collision(self, obj1, obj2) -> bool:
        """원과 원 충돌 검사
        
        Args:
            obj1: 첫 번째 원형 객체
            obj2: 두 번째 원형 객체
            
        Returns:
            bool: 충돌 여부
        """
        if not all(hasattr(obj, 'x') and hasattr(obj, 'y') and hasattr(obj, 'radius') 
                  for obj in [obj1, obj2]):
            return False
        
        distance = math.sqrt((obj1.x - obj2.x)**2 + (obj1.y - obj2.y)**2)
        return distance < (obj1.radius + obj2.radius)
    
    def _circle_rect_collision(self, cx, cy, radius, rx, ry, rw, rh) -> bool:
        """원과 사각형 충돌 검사 (정밀)
        
        Args:
            cx, cy: 원의 중심
            radius: 원의 반지름
            rx, ry: 사각형의 좌상단 좌표
            rw, rh: 사각형의 너비와 높이
            
        Returns:
            bool: 충돌 여부
        """
        # 원의 중심에서 가장 가까운 사각형 내부의 점 찾기
        closest_x = max(rx, min(cx, rx + rw))
        closest_y = max(ry, min(cy, ry + rh))
        
        # 원의 중심과 가장 가까운 점 사이의 거리
        distance = math.sqrt((cx - closest_x)**2 + (cy - closest_y)**2)
        
        return distance < radius
    
    def get_collision_point(self, obj1, obj2) -> Optional[Tuple[float, float]]:
        """충돌 지점 계산
        
        Args:
            obj1: 첫 번째 객체
            obj2: 두 번째 객체
            
        Returns:
            충돌 지점 좌표 또는 None
        """
        # 원과 사각형 충돌
        if hasattr(obj1, 'radius') and hasattr(obj2, 'rect'):
            cx, cy = obj1.x, obj1.y
            rect = obj2.rect
            
            # 가장 가까운 점 찾기
            closest_x = max(rect.x, min(cx, rect.x + rect.width))
            closest_y = max(rect.y, min(cy, rect.y + rect.height))
            
            return (closest_x, closest_y)
        
        # 원과 원 충돌
        elif hasattr(obj1, 'radius') and hasattr(obj2, 'radius'):
            # 두 원의 중심을 잇는 선상의 충돌점
            dx = obj2.x - obj1.x
            dy = obj2.y - obj1.y
            distance = math.sqrt(dx**2 + dy**2)
            
            if distance > 0:
                ratio = obj1.radius / distance
                return (obj1.x + dx * ratio, obj1.y + dy * ratio)
        
        return None
    
    def get_collision_normal(self, obj1, obj2) -> Optional[Tuple[float, float]]:
        """충돌 법선 벡터 계산
        
        Args:
            obj1: 첫 번째 객체
            obj2: 두 번째 객체
            
        Returns:
            정규화된 충돌 법선 벡터 또는 None
        """
        collision_point = self.get_collision_point(obj1, obj2)
        if not collision_point:
            return None
        
        # obj1 중심에서 충돌점으로의 벡터
        if hasattr(obj1, 'x') and hasattr(obj1, 'y'):
            dx = collision_point[0] - obj1.x
            dy = collision_point[1] - obj1.y
            length = math.sqrt(dx**2 + dy**2)
            
            if length > 0:
                return (dx / length, dy / length)
        
        return None
    
    def _trigger_collision(self, collision_type: CollisionType, obj1, obj2):
        """충돌 이벤트 트리거
        
        Args:
            collision_type: 충돌 타입
            obj1: 첫 번째 객체
            obj2: 두 번째 객체
        """
        # 중복 충돌 방지
        collision_id = (id(obj1), id(obj2))
        if collision_id in self.active_collisions:
            return
        
        self.active_collisions.add(collision_id)
        
        # 콜백 호출
        if collision_type in self.collision_callbacks:
            for callback in self.collision_callbacks[collision_type]:
                callback(obj1, obj2)
    
    def clear_frame(self):
        """프레임 초기화 (매 프레임 시작 시 호출)"""
        self.active_collisions.clear()
    
    def resolve_collision(self, obj1, obj2):
        """충돌 해결 (겹침 제거)
        
        Args:
            obj1: 첫 번째 객체
            obj2: 두 번째 객체
        """
        if hasattr(obj1, 'x') and hasattr(obj2, 'x'):
            # 두 객체 사이의 거리와 방향
            dx = obj1.x - obj2.x
            dy = obj1.y - obj2.y
            distance = math.sqrt(dx**2 + dy**2)
            
            if distance == 0:
                # 같은 위치에 있으면 임의 방향으로 밀어냄
                dx, dy = 1, 0
                distance = 1
            
            # 최소 거리 계산
            min_distance = getattr(obj1, 'radius', 20) + getattr(obj2, 'radius', 20)
            
            if distance < min_distance:
                # 겹침 해결
                overlap = min_distance - distance
                push_x = (dx / distance) * overlap * 0.5
                push_y = (dy / distance) * overlap * 0.5
                
                # 두 객체를 서로 밀어냄
                if hasattr(obj1, 'x'):
                    obj1.x += push_x
                    obj1.y += push_y
                if hasattr(obj2, 'x'):
                    obj2.x -= push_x
                    obj2.y -= push_y