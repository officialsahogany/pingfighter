"""
Ball Entity - 공 엔티티
공의 모든 동작과 렌더링을 관리
"""

import pygame
import math
import random
from typing import Tuple, Optional, List
from entities.entity import Entity
from game_logic.physics import get_physics_system
from game_logic.collision import get_collision_system
from core.events import EventType, emit_event


class Ball(Entity):
    """공 엔티티 클래스"""
    
    def __init__(self, x: float = 300, y: float = 375):
        """공 초기화
        
        Args:
            x: 초기 X 좌표
            y: 초기 Y 좌표
        """
        super().__init__(x, y)
        
        # 공 속성
        self.radius = 22
        self.size = pygame.Vector2(self.radius * 2, self.radius * 2)
        
        # 물리 시스템 연결
        self.physics = get_physics_system()
        self.collision = get_collision_system()
        
        # 시각 효과
        self.color = (255, 255, 255)
        self.trail_color = (100, 100, 255)
        self.glow_color = (150, 150, 255)
        self.glow_intensity = 0
        
        # 트레일 효과
        self.trail_points = []
        self.max_trail_points = 10
        self.trail_fade_speed = 0.9
        
        # 파티클 효과
        self.particles = []
        self.particle_spawn_rate = 0
        
        # 특수 효과 상태
        self.is_power_shot = False
        self.power_shot_timer = 0
        self.is_curve_ball = False
        self.curve_direction = 0
        self.is_ghost_ball = False
        self.ghost_timer = 0
        
        # 스핀 효과
        self.spin_angle = 0
        self.spin_speed = 0
        
        # 충돌 효과
        self.hit_effect_timer = 0
        self.hit_effect_scale = 1.0
        
        # 태그 설정
        self.add_tag("ball")
        self.add_to_group("game_objects")
        
        # 초기 속도 설정
        self.reset_velocity()
        
    def reset_velocity(self):
        """속도 초기화"""
        self.velocity.x = random.uniform(-3, 3)
        self.velocity.y = random.choice([-8, 8])
        self.physics.set_velocity(self.velocity.x, self.velocity.y)
        
    def update(self, dt: float):
        """공 업데이트
        
        Args:
            dt: 델타 타임
        """
        if not self.active:
            return
            
        # 물리 시스템에서 위치 가져오기
        phys_pos = self.physics.ball_position
        self.position.x = phys_pos[0]
        self.position.y = phys_pos[1]
        
        # 물리 시스템에서 속도 가져오기
        phys_vel = self.physics.ball_velocity
        self.velocity.x = phys_vel[0]
        self.velocity.y = phys_vel[1]
        
        # 특수 효과 업데이트
        self.update_special_effects(dt)
        
        # 트레일 업데이트
        self.update_trail()
        
        # 파티클 업데이트
        self.update_particles(dt)
        
        # 스핀 업데이트
        self.update_spin(dt)
        
        # 충돌 효과 업데이트
        if self.hit_effect_timer > 0:
            self.hit_effect_timer -= dt
            self.hit_effect_scale = 1.0 + 0.3 * (self.hit_effect_timer / 0.2)
            
        # Rect 업데이트
        self.update_rect()
        
    def update_special_effects(self, dt: float):
        """특수 효과 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 파워샷 효과
        if self.is_power_shot:
            self.power_shot_timer -= dt
            if self.power_shot_timer <= 0:
                self.is_power_shot = False
                self.glow_intensity = 0
            else:
                self.glow_intensity = min(1.0, self.power_shot_timer)
                self.particle_spawn_rate = 10
                
        # 고스트 볼 효과
        if self.is_ghost_ball:
            self.ghost_timer -= dt
            if self.ghost_timer <= 0:
                self.is_ghost_ball = False
                
        # 커브볼 효과
        if self.is_curve_ball:
            curve_force = self.curve_direction * 0.5
            self.physics.add_force(curve_force, 0)
            
    def update_trail(self):
        """트레일 효과 업데이트"""
        # 현재 위치를 트레일에 추가
        self.trail_points.append({
            'pos': self.position.copy(),
            'alpha': 255,
            'radius': self.radius
        })
        
        # 트레일 포인트 수 제한
        if len(self.trail_points) > self.max_trail_points:
            self.trail_points.pop(0)
            
        # 트레일 페이드
        for point in self.trail_points:
            point['alpha'] *= self.trail_fade_speed
            point['radius'] *= 0.95
            
        # 투명도가 낮은 포인트 제거
        self.trail_points = [p for p in self.trail_points if p['alpha'] > 10]
        
    def update_particles(self, dt: float):
        """파티클 효과 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 새 파티클 생성
        if self.particle_spawn_rate > 0:
            for _ in range(int(self.particle_spawn_rate * dt)):
                self.spawn_particle()
                
        # 파티클 업데이트
        for particle in self.particles:
            particle['pos'][0] += particle['vel'][0] * dt
            particle['pos'][1] += particle['vel'][1] * dt
            particle['life'] -= dt
            particle['alpha'] = int(255 * (particle['life'] / particle['max_life']))
            
        # 죽은 파티클 제거
        self.particles = [p for p in self.particles if p['life'] > 0]
        
    def spawn_particle(self):
        """파티클 생성"""
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(50, 150)
        life = random.uniform(0.3, 0.6)
        
        particle = {
            'pos': [self.position.x, self.position.y],
            'vel': [math.cos(angle) * speed, math.sin(angle) * speed],
            'life': life,
            'max_life': life,
            'alpha': 255,
            'color': self.glow_color,
            'size': random.uniform(2, 5)
        }
        
        self.particles.append(particle)
        
    def update_spin(self, dt: float):
        """스핀 효과 업데이트
        
        Args:
            dt: 델타 타임
        """
        if abs(self.spin_speed) > 0.01:
            self.spin_angle += self.spin_speed * dt * 360
            self.spin_speed *= 0.98  # 감속
            
            # 스핀에 따른 궤적 변화
            spin_effect = self.spin_speed * 0.1
            self.physics.apply_spin(spin_effect)
            
    def render(self, screen: pygame.Surface, camera_offset: Tuple[int, int] = (0, 0)):
        """공 렌더링
        
        Args:
            screen: 렌더링할 화면
            camera_offset: 카메라 오프셋
        """
        if not self.visible:
            return
            
        # 렌더링 위치 계산
        render_x = int(self.position.x - camera_offset[0])
        render_y = int(self.position.y - camera_offset[1])
        
        # 트레일 렌더링
        self.render_trail(screen, camera_offset)
        
        # 파티클 렌더링
        self.render_particles(screen, camera_offset)
        
        # 글로우 효과 렌더링
        if self.glow_intensity > 0:
            self.render_glow(screen, render_x, render_y)
            
        # 공 본체 렌더링
        radius = int(self.radius * self.hit_effect_scale)
        
        if self.is_ghost_ball:
            # 고스트 볼 효과 (반투명)
            s = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
            pygame.draw.circle(s, (*self.color, 128), (radius, radius), radius)
            screen.blit(s, (render_x - radius, render_y - radius))
        else:
            # 일반 렌더링
            pygame.draw.circle(screen, self.color, (render_x, render_y), radius)
            
        # 스핀 효과 렌더링
        if abs(self.spin_speed) > 0.01:
            self.render_spin(screen, render_x, render_y, radius)
            
    def render_trail(self, screen: pygame.Surface, camera_offset: Tuple[int, int]):
        """트레일 효과 렌더링
        
        Args:
            screen: 렌더링할 화면
            camera_offset: 카메라 오프셋
        """
        for point in self.trail_points:
            x = int(point['pos'].x - camera_offset[0])
            y = int(point['pos'].y - camera_offset[1])
            alpha = int(point['alpha'])
            radius = int(point['radius'])
            
            if alpha > 0 and radius > 0:
                s = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
                color = (*self.trail_color, alpha)
                pygame.draw.circle(s, color, (radius, radius), radius)
                screen.blit(s, (x - radius, y - radius))
                
    def render_particles(self, screen: pygame.Surface, camera_offset: Tuple[int, int]):
        """파티클 효과 렌더링
        
        Args:
            screen: 렌더링할 화면
            camera_offset: 카메라 오프셋
        """
        for particle in self.particles:
            x = int(particle['pos'][0] - camera_offset[0])
            y = int(particle['pos'][1] - camera_offset[1])
            size = int(particle['size'])
            alpha = particle['alpha']
            
            if alpha > 0:
                s = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                color = (*particle['color'], alpha)
                pygame.draw.circle(s, color, (size, size), size)
                screen.blit(s, (x - size, y - size))
                
    def render_glow(self, screen: pygame.Surface, x: int, y: int):
        """글로우 효과 렌더링
        
        Args:
            screen: 렌더링할 화면
            x: X 좌표
            y: Y 좌표
        """
        glow_radius = int(self.radius * 2)
        alpha = int(self.glow_intensity * 100)
        
        s = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
        for i in range(3):
            r = glow_radius - i * 5
            a = alpha // (i + 1)
            if r > 0 and a > 0:
                pygame.draw.circle(s, (*self.glow_color, a), 
                                 (glow_radius, glow_radius), r)
                                 
        screen.blit(s, (x - glow_radius, y - glow_radius))
        
    def render_spin(self, screen: pygame.Surface, x: int, y: int, radius: int):
        """스핀 효과 렌더링
        
        Args:
            screen: 렌더링할 화면
            x: X 좌표
            y: Y 좌표
            radius: 반지름
        """
        # 스핀 방향 표시
        angle_rad = math.radians(self.spin_angle)
        line_length = radius * 0.7
        end_x = x + int(math.cos(angle_rad) * line_length)
        end_y = y + int(math.sin(angle_rad) * line_length)
        
        pygame.draw.line(screen, (200, 200, 200), (x, y), (end_x, end_y), 2)
        
    def on_collision(self, other: Entity):
        """충돌 이벤트 처리
        
        Args:
            other: 충돌한 엔티티
        """
        # 충돌 효과 시작
        self.hit_effect_timer = 0.2
        
        # 파티클 생성
        for _ in range(5):
            self.spawn_particle()
            
        # 충돌 사운드 이벤트
        if other.has_tag("paddle"):
            emit_event(EventType.PLAY_SOUND, {'sound': 'hit'})
        elif other.has_tag("wall"):
            emit_event(EventType.PLAY_SOUND, {'sound': 'wall_hit'})
            
    def apply_power_shot(self, duration: float = 1.0):
        """파워샷 적용
        
        Args:
            duration: 지속 시간
        """
        self.is_power_shot = True
        self.power_shot_timer = duration
        self.glow_intensity = 1.0
        self.physics.apply_power_shot(1.5)
        
    def apply_curve_ball(self, direction: int):
        """커브볼 적용
        
        Args:
            direction: -1(왼쪽) or 1(오른쪽)
        """
        self.is_curve_ball = True
        self.curve_direction = direction
        self.physics.apply_curve_ball(direction)
        
    def apply_ghost_ball(self, duration: float = 3.0):
        """고스트 볼 적용
        
        Args:
            duration: 지속 시간
        """
        self.is_ghost_ball = True
        self.ghost_timer = duration
        
    def apply_spin(self, spin: float):
        """스핀 적용
        
        Args:
            spin: 스핀 강도 (-1 ~ 1)
        """
        self.spin_speed = spin * 10
        self.physics.apply_spin(spin)
        
    def serve(self, server: str = 'player'):
        """서브
        
        Args:
            server: 'player' or 'boss'
        """
        if server == 'player':
            self.position.x = 300
            self.position.y = 600
            self.velocity.y = -8
        else:
            self.position.x = 300
            self.position.y = 150
            self.velocity.y = 8
            
        self.velocity.x = random.uniform(-3, 3)
        self.physics.serve_ball(server)
        
    def reset(self):
        """공 리셋"""
        super().reset()
        
        # 위치 리셋
        self.position.x = 300
        self.position.y = 375
        
        # 속도 리셋
        self.reset_velocity()
        
        # 효과 리셋
        self.is_power_shot = False
        self.is_curve_ball = False
        self.is_ghost_ball = False
        self.spin_speed = 0
        self.spin_angle = 0
        
        # 시각 효과 리셋
        self.trail_points.clear()
        self.particles.clear()
        self.glow_intensity = 0
        
        # 물리 시스템 리셋
        self.physics.reset(self.position.x, self.position.y)