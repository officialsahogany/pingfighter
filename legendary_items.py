"""
전설 아이템 시스템
- 필드에서 스폰되지 않음
- 가챠에서 등장하지 않음
- 해금 조건 필요
- 붉은색 테두리와 움직이는 아이콘 효과
"""

import pygame
import math
import random
import os
import sys
from typing import Dict, List, Optional, Tuple

# 리소스 경로 헬퍼 (PyInstaller 호환)
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

# 전설 아이템 티어 정의
LEGENDARY_TIER = "legendary"
LEGENDARY_COLOR = (255, 50, 50)  # 붉은색
LEGENDARY_GLOW_COLOR = (255, 100, 100, 128)  # 반투명 붉은색 글로우

class LegendaryItem:
    """전설 아이템 베이스 클래스"""
    def __init__(self, name: str, korean_name: str, description: str, 
                 unlock_condition: str, icon_path: Optional[str] = None):
        self.name = name
        self.korean_name = korean_name
        self.description = description
        self.unlock_condition = unlock_condition
        self.icon_path = icon_path
        self.unlocked = False
        self.active = False
        self.animation_offset = 0
        self.animation_time = 0
        self.glow_intensity = 0
        self.particle_timer = 0
        
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """해금 조건 체크 - 각 아이템별로 오버라이드"""
        return False
        
    def activate(self, game_state: Dict):
        """아이템 활성화 - 각 아이템별로 오버라이드"""
        self.active = True
        print(f"   [{self.korean_name}] !")
        
    def deactivate(self):
        """아이템 비활성화"""
        self.active = False
        
    def update(self, dt: float, ui_mode: bool = False):
        """애니메이션 업데이트
        Args:
            dt: 델타 타임
            ui_mode: UI 모드 여부 (True면 게임플레이 효과 비활성화)
        """
        self.animation_time += dt
        # 아이콘 흔들림 효과
        self.animation_offset = math.sin(self.animation_time * 0.003) * 2
        # 글로우 펄싱 효과
        self.glow_intensity = (math.sin(self.animation_time * 0.002) + 1) / 2
        # 파티클 타이머
        self.particle_timer += dt
        
    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """아이콘 그리기 with 전설 효과"""
        # 글로우 효과
        glow_size = int(size * (1.2 + self.glow_intensity * 0.1))
        glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
        for i in range(3):
            alpha = 50 - i * 15
            pygame.draw.circle(glow_surf, (*LEGENDARY_COLOR, alpha), 
                             (glow_size//2, glow_size//2), 
                             glow_size//2 - i * 5)
        screen.blit(glow_surf, (x - (glow_size - size)//2, y - (glow_size - size)//2))
        
        # 붉은색 테두리
        border_rect = pygame.Rect(x-2, y-2, size+4, size+4)
        pygame.draw.rect(screen, LEGENDARY_COLOR, border_rect, 3)
        
        # 아이콘 (움직임 효과 적용)
        icon_y = y + int(self.animation_offset)
        if self.icon_path:
            try:
                icon = pygame.image.load(self.icon_path).convert_alpha()
                icon = pygame.transform.scale(icon, (size, size))
                screen.blit(icon, (x, icon_y))
            except:
                # 아이콘 로드 실패시 에러 표시
                pass
        else:
            # 아이콘 경로가 없으면 에러 표시
            pass
            
        # 파티클 효과 (가끔씩)
        if self.particle_timer > 1000:  # 1초마다
            self._spawn_particle(screen, x + size//2, y + size//2)
            self.particle_timer = 0
            
        
    def _spawn_particle(self, screen: pygame.Surface, x: int, y: int):
        """파티클 스폰"""
        for _ in range(3):
            px = x + random.randint(-20, 20)
            py = y + random.randint(-20, 20)
            pygame.draw.circle(screen, LEGENDARY_COLOR, (px, py), random.randint(1, 3))


# 전설 아이템 정의
class InfinityGauntlet(LegendaryItem):
    """무한의 건틀릿 - 모든 스킬 쿨다운 50% 감소"""
    def __init__(self):
        super().__init__(
            name="infinity_gauntlet",
            korean_name="무한의 건틀릿",
            description="모든 스킬 쿨다운이 50% 감소합니다",
            unlock_condition="모든 스테이지를 노데미지로 클리어",
            icon_path="items/legendary/infinity_gauntlet.png"  # 아이콘 경로 추가
        )
        self.cooldown_reduction = 0.5
        
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """노데미지 올클리어 체크"""
        return game_stats.get("perfect_all_stages", False)
        
    def activate(self, game_state: Dict):
        super().activate(game_state)
        # 쿨다운 감소 적용
        if 'cooldown_multiplier' in game_state:
            game_state['cooldown_multiplier'] *= (1 - self.cooldown_reduction)


class PhoenixFeather(LegendaryItem):
    """불사조의 깃털 - 체력이 0이 되어도 한 번 부활"""
    def __init__(self):
        super().__init__(
            name="phoenix_feather",
            korean_name="불사조의 깃털",
            description="게임 오버 시 체력 50%로 한 번 부활합니다",
            unlock_condition="연속 100라운드 승리",
            icon_path="items/legendary/phoenix_feather.png"  # 아이콘 경로 추가
        )
        self.revival_used = False
        self.revival_health = 0.5
        
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """연속 100승 체크"""
        return game_stats.get("consecutive_wins", 0) >= 100
        
    def try_revive(self, current_health: int, max_health: int) -> Optional[int]:
        """부활 시도"""
        if self.active and not self.revival_used and current_health <= 0:
            self.revival_used = True
            new_health = int(max_health * self.revival_health)
            print(f"   !  {new_health} !")
            return new_health
        return None


class ChronosClock(LegendaryItem):
    """크로노스의 시계 - 시간 조작 능력"""
    def __init__(self):
        super().__init__(
            name="chronos_clock",
            korean_name="크로노스의 시계",
            description="스페이스바로 3초간 시간을 느리게 만듭니다 (쿨다운 30초)",
            unlock_condition="단일 게임에서 10,000점 이상 획득",
            icon_path="items/legendary/chronos_clock.png"  # 아이콘 경로 추가
        )
        self.time_slow_duration = 3000  # 3초
        self.time_slow_cooldown = 30000  # 30초
        self.time_slow_active = False
        self.time_slow_timer = 0
        self.cooldown_timer = 0
        self.time_scale = 0.3  # 30% 속도
        
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """고득점 체크"""
        return game_stats.get("max_score", 0) >= 10000
        
    def activate_time_slow(self) -> bool:
        """시간 감속 발동"""
        if self.active and self.cooldown_timer <= 0:
            self.time_slow_active = True
            self.time_slow_timer = self.time_slow_duration
            self.cooldown_timer = self.time_slow_cooldown
            print(f"   !  ...")
            return True
        return False
        
    def update_time_slow(self, dt: float) -> float:
        """시간 배율 업데이트"""
        if self.time_slow_active:
            self.time_slow_timer -= dt
            if self.time_slow_timer <= 0:
                self.time_slow_active = False
                print(f"")
            return self.time_scale
        
        if self.cooldown_timer > 0:
            self.cooldown_timer -= dt
            
        return 1.0  # 정상 속도


class ExcaliburBlade(LegendaryItem):
    """엑스칼리버 - 공격력 대폭 증가"""
    def __init__(self):
        super().__init__(
            name="excalibur_blade",
            korean_name="엑스칼리버",
            description="모든 공격의 데미지가 2배가 됩니다",
            unlock_condition="단일 라운드에서 적을 30초 내에 처치",
            icon_path="items/legendary/excalibur_blade.png"  # 아이콘 경로 추가
        )
        self.damage_multiplier = 2.0
        
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """스피드런 체크"""
        return game_stats.get("fastest_round_time", float('inf')) <= 30
        
    def apply_damage(self, base_damage: float) -> float:
        """데미지 배율 적용"""
        if self.active:
            return base_damage * self.damage_multiplier
        return base_damage


class PoseidonTrident(LegendaryItem):
    """포세이돈의 삼지창 - 물의 신의 무기"""
    def __init__(self):
        super().__init__(
            name="poseidon_trident",
            korean_name="포세이돈의 삼지창",
            description="물의 파동으로 공의 궤적을 조작하고, 대시 시 거대한 물결 회오리를 생성합니다",
            unlock_condition="스테이지 7 클리어",
            icon_path="items/legendary/poseidon_trident.png"
        )
        self.wave_effect_radius = 100  # 물결 효과 반경
        self.trajectory_influence = 0.15  # 궤적 영향력 (15%)
        self.dash_wave_force = 5.0  # 대시 시 물결 힘
        self.wave_particles = []  # 물결 파티클
        self.wave_timer = 0
        self.dash_wave_active = False
        self.dash_wave_timer = 0
        
        # 거대한 물결 회오리 효과 속성
        self.vortex_active = False
        self.vortex_timer = 0
        self.vortex_x = 0
        self.vortex_y = 0
        self.vortex_height = 0  # 시작 높이
        self.vortex_max_height = 400  # 최대 높이 (화면 대부분 커버)
        self.vortex_width = 200  # 회오리 너비 (대폭 증가 for better collision)
        self.vortex_spin_speed = 0  # 회전 속도
        self.vortex_particles = []  # 회오리 파티클
        
        # 공 반사 효과 속성
        self.deflection_power = 15.0  # 반사 힘
        self.spin_power = 8.0  # 드라이브 회전력
        
        # 애니메이션용 아이콘 프레임들
        self.icon_frames = []
        self.current_frame = 0
        self.frame_timer = 0
        self.load_animation_frames()
        
    def load_animation_frames(self):
        """애니메이션 프레임 로드"""
        for i in range(8):  # 8프레임 애니메이션
            try:
                frame_path = resource_path(f"items/legendary/poseidon_trident_frame_{i}.png")
                frame = pygame.image.load(frame_path).convert_alpha()
                self.icon_frames.append(frame)
            except:
                # 프레임 로드 실패 시 기본 아이콘 사용
                pass
                
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """스테이지 7 클리어 체크"""
        return game_stats.get("highest_stage_cleared", 0) >= 7
        
    def activate(self, game_state: Dict):
        """삼지창 활성화"""
        if not self.active:
            self.active = True
            self.wave_timer = 0
            print(f"🔱 {self.korean_name} 활성화! 물의 파동이 공을 조작합니다!")
            
    def deactivate(self):
        """삼지창 비활성화"""
        self.active = False
        self.wave_particles.clear()
        self.dash_wave_active = False
        
    def apply_trajectory_influence(self, ball_x: float, ball_y: float, 
                                  ball_vx: float, ball_vy: float, 
                                  paddle_x: float, paddle_y: float) -> Tuple[float, float]:
        """공의 궤적에 물의 파동 영향 적용"""
        if not self.active:
            return ball_vx, ball_vy
            
        # 패들과의 거리 계산
        distance = math.sqrt((ball_x - paddle_x) ** 2 + (ball_y - paddle_y) ** 2)
        
        # 영향 범위 내에 있을 때만
        if distance < self.wave_effect_radius:
            # 거리에 따른 영향력 계산 (가까울수록 강함)
            influence = (1 - distance / self.wave_effect_radius) * self.trajectory_influence
            
            # 물결 효과로 미세한 궤적 변경 (사인파)
            wave_effect_x = math.sin(self.wave_timer * 0.1) * influence
            wave_effect_y = math.cos(self.wave_timer * 0.1) * influence * 0.5
            
            # 속도에 물결 효과 적용
            new_vx = ball_vx * (1 + wave_effect_x)
            new_vy = ball_vy * (1 + wave_effect_y)
            
            return new_vx, new_vy
            
        return ball_vx, ball_vy
        
    def trigger_dash_wave(self, paddle_x: float, paddle_y: float, direction: int):
        """대시 시 거대한 물결 회오리 발동"""
        if self.active:
            self.dash_wave_active = True
            self.dash_wave_timer = 0
            
            # 거대한 물결 회오리 활성화
            self.vortex_active = True
            self.vortex_timer = 0
            self.vortex_x = paddle_x
            self.vortex_y = paddle_y
            self.vortex_height = 0
            self.vortex_spin_speed = 0
            
            print(f"🔱 포세이돈 회오리 발동! 위치: ({paddle_x:.0f}, {paddle_y:.0f}), 방향: {direction}")
            print(f"   Active: {self.active}, Vortex: {self.vortex_active}, Height: {self.vortex_height}")
            
            # 회오리 파티클 대량 생성 (용솟음치는 효과)
            for i in range(50):  # 많은 파티클로 거대한 효과
                # 나선형 상승 파티클
                angle = (i / 10) * math.pi * 2
                height_offset = random.uniform(0, 200)
                particle = {
                    "x": paddle_x + random.uniform(-30, 30),
                    "y": paddle_y - height_offset,
                    "vx": math.cos(angle) * random.uniform(2, 8) * direction,
                    "vy": random.uniform(-8, -3),  # 위로 솟구치는 속도
                    "life": random.randint(40, 80),
                    "color": (50, 150 + random.randint(0, 100), 255),
                    "size": random.uniform(3, 10),
                    "spiral_angle": angle,
                    "spiral_radius": random.uniform(20, 60)
                }
                self.vortex_particles.append(particle)
                
            # 기존 물결 파티클도 생성 (바닥 효과)
            for i in range(20):
                angle = (i / 20) * math.pi * 2
                particle = {
                    "x": paddle_x,
                    "y": paddle_y,
                    "vx": math.cos(angle) * 5 * direction,
                    "vy": math.sin(angle) * 3,
                    "life": 40,
                    "color": (100, 200, 255)
                }
                self.wave_particles.append(particle)
                
    def apply_dash_wave_to_ball(self, ball_x: float, ball_y: float,
                               ball_vx: float, ball_vy: float,
                               paddle_x: float, paddle_y: float) -> Tuple[float, float]:
        """거대한 물결 회오리가 공에 미치는 부드러운 물리 효과"""
        
        if not self.dash_wave_active and not self.vortex_active:
            return ball_vx, ball_vy
            
        # 거대한 회오리 효과 (우선 처리)
        if self.vortex_active:
            # 회오리의 Y축 범위 (시간에 따라 확장)
            current_vortex_height = min(self.vortex_height, self.vortex_max_height)
            
            # 회오리 충돌 체크 - 시각적 효과와 정확히 일치
            x_in_vortex = abs(ball_x - self.vortex_x) <= (self.vortex_width / 2 + 50)
            y_in_vortex = (self.vortex_y - current_vortex_height - 50) <= ball_y <= (self.vortex_y + 100)
            
            if x_in_vortex and y_in_vortex:
                # 공이 물에 들어왔을 때 - 부드러운 물리 효과
                print(f"🌊 포세이돈의 물결이 공을 감쌉니다!")
                
                # 1. 부드러운 감속 효과 (물의 저항)
                # 회오리 중심으로부터의 거리 계산
                distance_from_center = abs(ball_x - self.vortex_x)
                depth_factor = 1.0 - (distance_from_center / (self.vortex_width / 2 + 50))
                
                # 물속 깊이에 따른 감속 (중심에 가까울수록 강함)
                water_resistance = 0.7 + (0.25 * depth_factor)  # 0.7 ~ 0.95 사이의 감속
                
                # 현재 속도를 부드럽게 감속
                new_vx = ball_vx * water_resistance
                new_vy = ball_vy * water_resistance
                
                # 2. 물의 흐름에 따른 방향 전환 (보스 쪽으로)
                # 회오리가 공을 위로 밀어올리는 효과
                upward_current = -8.0 * depth_factor  # 중심에 가까울수록 강한 상승류
                new_vy += upward_current
                
                # 3. 나선형 회전 효과 (물의 소용돌이)
                spin_effect = math.sin(self.vortex_timer * 5) * 3.0 * depth_factor
                new_vx += spin_effect
                
                # 4. 점진적인 가속 (물에서 튕겨나가는 효과)
                if new_vy < 0:  # 위로 향할 때만
                    push_multiplier = 1.2 + (0.3 * depth_factor)  # 1.2 ~ 1.5배 가속
                    new_vy *= push_multiplier
                
                # 5. 부드러운 좌우 흔들림
                wave_motion = math.sin(self.vortex_timer * 8) * 2.0
                new_vx += wave_motion
                
                # 속도 제한 (적절한 게임플레이를 위해)
                max_speed = 25  # 더 적절한 최대 속도
                speed = math.sqrt(new_vx ** 2 + new_vy ** 2)
                if speed > max_speed:
                    new_vx = new_vx / speed * max_speed
                    new_vy = new_vy / speed * max_speed
                
                return new_vx, new_vy
        
        # 기존 물결 효과 (보조 효과)
        if self.dash_wave_active:
            distance = math.sqrt((ball_x - paddle_x) ** 2 + (ball_y - paddle_y) ** 2)
            wave_radius = 50 + self.dash_wave_timer * 10
            
            if distance < wave_radius and distance > 0:
                push_x = (ball_x - paddle_x) / distance * self.dash_wave_force
                push_y = (ball_y - paddle_y) / distance * self.dash_wave_force * 0.5
                attenuation = 1 - (distance / wave_radius)
                
                return ball_vx + push_x * attenuation, ball_vy + push_y * attenuation
                
        return ball_vx, ball_vy
        
    def update(self, dt: float, ui_mode: bool = False):
        """업데이트
        Args:
            dt: 델타 타임
            ui_mode: UI 모드 여부 (True면 게임플레이 효과 비활성화)
        """
        if not self.active and not ui_mode:
            return
            
        # 애니메이션 업데이트 (UI 모드에서도 동작)
        self.animation_time += dt
        self.frame_timer += dt
        
        # 프레임 전환 (8fps)
        if self.frame_timer >= 0.125 and self.icon_frames:
            self.frame_timer = 0
            self.current_frame = (self.current_frame + 1) % len(self.icon_frames)
            
        # UI 모드에서는 게임플레이 효과 스킵
        if ui_mode:
            return
            
        # 물결 타이머 (게임플레이에서만)
        self.wave_timer += dt * 60
        
        # 거대한 회오리 업데이트 (게임플레이에서만)
        if self.vortex_active:
            self.vortex_timer += dt
            
            # 회오리 높이 급속 확장 (용솟음치는 효과)
            if self.vortex_height < self.vortex_max_height:
                self.vortex_height += 800 * dt  # 빠르게 상승
                # 매 0.5초마다 업데이트 상태 출력
            if int(self.vortex_timer * 2) != int((self.vortex_timer - dt) * 2):
                print(f"📈 Vortex Update: timer={self.vortex_timer:.2f}s, height={self.vortex_height:.0f}, dt={dt:.4f}")
            
            # 회전 속도 증가
            self.vortex_spin_speed += dt * 10
            
            # 회오리 파티클 업데이트
            for particle in self.vortex_particles[:]:
                # 나선형 움직임
                particle["spiral_angle"] += dt * 5
                particle["x"] = self.vortex_x + math.cos(particle["spiral_angle"]) * particle["spiral_radius"]
                particle["y"] -= dt * 200  # 위로 상승
                
                particle["spiral_radius"] += dt * 30  # 반경 확대
                particle["life"] -= dt * 60
                
                if particle["life"] <= 0:
                    self.vortex_particles.remove(particle)
                    
            # 새로운 파티클 지속적으로 생성
            if self.vortex_timer < 1.0 and len(self.vortex_particles) < 100:
                for _ in range(3):
                    particle = {
                        "x": self.vortex_x + random.uniform(-30, 30),
                        "y": self.vortex_y,
                        "vx": random.uniform(-5, 5),
                        "vy": random.uniform(-10, -5),
                        "life": random.randint(30, 60),
                        "color": (50, 150 + random.randint(0, 100), 255),
                        "size": random.uniform(5, 15),
                        "spiral_angle": random.uniform(0, math.pi * 2),
                        "spiral_radius": random.uniform(10, 30)
                    }
                    self.vortex_particles.append(particle)
            
            # 회오리 종료 체크 (3초 후 - 테스트를 위해 증가)
            if self.vortex_timer > 3.0:
                self.vortex_active = False
                self.vortex_height = 0
                self.vortex_particles.clear()
        
        # 대시 물결 타이머
        if self.dash_wave_active:
            self.dash_wave_timer += dt * 60
            if self.dash_wave_timer > 60:  # 1초 후 종료
                self.dash_wave_active = False
                self.dash_wave_timer = 0
                
        # 파티클 업데이트
        for particle in self.wave_particles[:]:
            particle["x"] += particle["vx"]
            particle["y"] += particle["vy"]
            particle["life"] -= 1
            particle["vy"] += 0.1  # 중력
            
            if particle["life"] <= 0:
                self.wave_particles.remove(particle)
                
    def draw_effects(self, screen: pygame.Surface):
        """거대한 물결 회오리 효과 그리기"""
        if not self.active:
            return
            
        # 거대한 회오리 그리기
        if self.vortex_active:
            # 회오리 기둥 효과 (반투명 거대한 물기둥)
            current_height = int(min(self.vortex_height, self.vortex_max_height))
            if current_height > 0:
                # 여러 레이어로 회오리 표현
                for i in range(5):
                    alpha = 60 + i * 20  # 레이어별 투명도 (더 진하게)
                    width = self.vortex_width - i * 10
                    
                    # 회오리 기둥
                    vortex_surf = pygame.Surface((width, current_height), pygame.SRCALPHA)
                    
                    # 그라데이션 효과
                    for y in range(0, current_height, 5):
                        gradient_alpha = alpha * (1 - y / current_height)
                        color = (50, 150 + int(50 * (1 - y / current_height)), 255, int(gradient_alpha))
                        pygame.draw.rect(vortex_surf, color, (0, y, width, 5))
                    
                    # 회오리 중심에 그리기
                    screen.blit(vortex_surf, 
                              (self.vortex_x - width // 2, 
                               self.vortex_y - current_height))
                
                # 회오리 윤곽선 효과
                for i in range(3):
                    pygame.draw.lines(screen, (100, 200, 255, 100), False,
                                    [(self.vortex_x - self.vortex_width // 2 + i * 20, 
                                      self.vortex_y),
                                     (self.vortex_x - self.vortex_width // 3 + i * 15, 
                                      self.vortex_y - current_height // 2),
                                     (self.vortex_x - self.vortex_width // 4 + i * 10, 
                                      self.vortex_y - current_height)], 2)
                
                # 디버그 테두리 제거됨 - 실제 게임에서는 표시하지 않음
            
            # 회오리 파티클 그리기
            for particle in self.vortex_particles:
                if "size" in particle:
                    size = particle["size"]
                    alpha = min(255, int(particle["life"] * 5))
                    
                    # 거대한 물방울 효과
                    water_surf = pygame.Surface((int(size * 2), int(size * 2)), pygame.SRCALPHA)
                    color = (*particle["color"], alpha)
                    pygame.draw.circle(water_surf, color, (int(size), int(size)), int(size))
                    
                    # 하이라이트 효과
                    highlight_color = (200, 230, 255, alpha // 2)
                    pygame.draw.circle(water_surf, highlight_color, 
                                     (int(size - size // 3), int(size - size // 3)), 
                                     int(size // 3))
                    
                    screen.blit(water_surf, (particle["x"] - size, particle["y"] - size))
        
        # 기존 물결 파티클 그리기
        for particle in self.wave_particles:
            alpha = particle["life"] * 8  # 투명도
            size = 3 + (30 - particle["life"]) / 5
            
            # 물방울 효과
            water_surf = pygame.Surface((int(size * 2), int(size * 2)), pygame.SRCALPHA)
            color = (*particle["color"], min(alpha, 255))
            pygame.draw.circle(water_surf, color, (int(size), int(size)), int(size))
            screen.blit(water_surf, (particle["x"] - size, particle["y"] - size))
            
    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int):
        """아이콘 그리기 (애니메이션)"""
        if self.icon_frames and self.current_frame < len(self.icon_frames):
            # 애니메이션 프레임 그리기
            icon = pygame.transform.scale(self.icon_frames[self.current_frame], (size, size))
        elif self.icon_path and os.path.exists(resource_path(self.icon_path)):
            # 기본 아이콘 그리기
            icon = pygame.image.load(resource_path(self.icon_path)).convert_alpha()
            icon = pygame.transform.scale(icon, (size, size))
        else:
            # 아이콘이 없으면 기본 도형
            icon = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.rect(icon, LEGENDARY_COLOR, (0, 0, size, size), 3)
            
        # 글로우 효과
        if self.active:
            glow_size = int(size * 1.3)
            glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, LEGENDARY_GLOW_COLOR,
                             (glow_size // 2, glow_size // 2), glow_size // 2)
            screen.blit(glow_surf, (x - (glow_size - size) // 2, y - (glow_size - size) // 2))
            
        screen.blit(icon, (x, y))


class HermesShoes(LegendaryItem):
    """헤르메스의 신발 - 이동속도 50% 증가"""
    def __init__(self):
        super().__init__(
            name="hermes_shoes",
            korean_name="헤르메스의 신발",
            description="패들 이동속도가 50% 증가합니다",
            unlock_condition="누적 이동 거리 100,000 픽셀 달성",
            icon_path="items/legendary/hermes_shoes.png"  # 아이콘 경로 추가
        )
        self.speed_multiplier = 1.5  # 50% 속도 증가
        self.speed_trails = []  # 속도 잔상 효과
        self.wing_effects = []  # 날개 효과
        
        # 애니메이션 프레임 로드
        self.animation_frames = []
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 4  # 프레임당 틱 수 (12프레임에 맞춰 더 빠르게)
        self._load_animation_frames()
        
        # 헤르메스의 신발도 라그나로크 해머와 동일한 글로우 효과
        self.hermes_glow_multiplier = 1.8  # 라그나로크와 동일한 글로우 크기
        
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """누적 이동 거리 체크"""
        return game_stats.get("total_movement_distance", 0) >= 100000
        
    def activate(self, game_state: Dict):
        """헤르메스의 신발 활성화"""
        super().activate(game_state)
        # pingfighter.py의 전역 변수 설정
        import pingfighter
        import items
        pingfighter.hermes_shoes_obtained = True
        items.hermes_shoes_obtained = True
        print(f"헤르메스의 신발 활성화! 이동속도 50% 증가!")
        
    def apply_speed(self, base_speed: float) -> float:
        """이동속도 배율 적용"""
        if self.active:
            return base_speed * self.speed_multiplier
        return base_speed
        
    def add_speed_trail(self, paddle_x: int, paddle_y: int, paddle_width: int, paddle_height: int):
        """속도 잔상 추가"""
        if self.active:
            import time
            self.speed_trails.append({
                'x': paddle_x,
                'y': paddle_y,
                'width': paddle_width,
                'height': paddle_height,
                'time': time.time(),
                'alpha': 100
            })
            # 최대 5개의 잔상만 유지
            if len(self.speed_trails) > 5:
                self.speed_trails.pop(0)
                
    def draw_special_effects(self, screen, paddle_x: int, paddle_y: int, paddle_width: int, paddle_height: int):
        """특수 효과 그리기 (속도 잔상, 날개 효과)"""
        if not self.active:
            return
            
        import pygame
        import math
        import time
        
        current_time = time.time()
        
        # 속도 잔상 그리기
        for trail in self.speed_trails[:]:
            elapsed = current_time - trail['time']
            if elapsed > 0.5:  # 0.5초 후 제거
                self.speed_trails.remove(trail)
                continue
                
            alpha = int(trail['alpha'] * (1 - elapsed / 0.5))
            trail_surf = pygame.Surface((trail['width'], trail['height']), pygame.SRCALPHA)
            trail_surf.fill((255, 215, 0, alpha))  # 황금색 잔상
            screen.blit(trail_surf, (trail['x'], trail['y']))
        
        # 날개 효과 그리기 (패들 양옆)
        wing_offset = math.sin(current_time * 10) * 3  # 날개 펄럭임
        
        # 왼쪽 날개
        wing_points_left = [
            (paddle_x - 15 + wing_offset, paddle_y + paddle_height // 2 - 10),
            (paddle_x - 25 + wing_offset, paddle_y + paddle_height // 2),
            (paddle_x - 15 + wing_offset, paddle_y + paddle_height // 2 + 10),
            (paddle_x, paddle_y + paddle_height // 2)
        ]
        pygame.draw.polygon(screen, (255, 255, 255, 180), wing_points_left)
        pygame.draw.polygon(screen, (255, 215, 0), wing_points_left, 2)
        
        # 오른쪽 날개
        wing_points_right = [
            (paddle_x + paddle_width + 15 - wing_offset, paddle_y + paddle_height // 2 - 10),
            (paddle_x + paddle_width + 25 - wing_offset, paddle_y + paddle_height // 2),
            (paddle_x + paddle_width + 15 - wing_offset, paddle_y + paddle_height // 2 + 10),
            (paddle_x + paddle_width, paddle_y + paddle_height // 2)
        ]
        pygame.draw.polygon(screen, (255, 255, 255, 180), wing_points_right)
        pygame.draw.polygon(screen, (255, 215, 0), wing_points_right, 2)
        
        # 속도선 효과
        if abs(paddle_x - getattr(self, 'last_paddle_x', paddle_x)) > 5:
            for i in range(3):
                line_y = paddle_y + paddle_height // 4 + i * paddle_height // 4
                line_start = paddle_x - 30 if paddle_x > getattr(self, 'last_paddle_x', paddle_x) else paddle_x + paddle_width + 30
                line_end = paddle_x if paddle_x > getattr(self, 'last_paddle_x', paddle_x) else paddle_x + paddle_width
                pygame.draw.line(screen, (255, 255, 100, 150), (line_start, line_y), (line_end, line_y), 2)
        
        self.last_paddle_x = paddle_x
    
    def _load_animation_frames(self):
        """애니메이션 프레임 로드 - 라그나로크 해머 PNG 사용"""
        import pygame
        import os
        
        # 헤르메스 신발 전용 PNG 파일 사용
        frames_loaded = 0
        for i in range(8):
            # 헤르메스 신발 프레임을 로드
            frame_path = resource_path(f"items/legendary/hermes_shoes_frame_{i}.png")
            try:
                frame = pygame.image.load(frame_path).convert_alpha()
                self.animation_frames.append(frame)
                frames_loaded += 1
                print(f"✓ 헤르메스 신발 프레임 {i} 로드 성공")
            except Exception as e:
                print(f"✗ 프레임 {i} 로드 실패: {frame_path} - {e}")
        
        print(f"헤르메스 신발: 전용 프레임 {frames_loaded}/8개 로드")
        
        # 프레임이 없으면 에러만 표시 (가짜 애니메이션 생성하지 않음)
        if not self.animation_frames or len(self.animation_frames) == 0:
            print("❌ 헤르메스 신발: PNG 프레임을 찾을 수 없습니다!")
            # 가짜 애니메이션 생성 코드 완전 제거
    
    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """애니메이션 아이콘 그리기"""
        import pygame
        import math
        
        # 글로우 효과 (라그나로크 해머와 완전히 동일하게)
        glow_size = int(size * (self.hermes_glow_multiplier + self.glow_intensity * 0.15))
        glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
        for i in range(5):  # 더 많은 레이어로 강렬한 효과
            alpha = 80 - i * 12  # 더 진한 글로우
            pygame.draw.circle(glow_surf, (*LEGENDARY_COLOR, alpha), 
                             (glow_size//2, glow_size//2), 
                             glow_size//2 - i * 4)  # 더 촘촘한 간격
        screen.blit(glow_surf, (x - (glow_size - size)//2, y - (glow_size - size)//2))
        
        # 붉은색 테두리 (펄싱 효과 - 더 두껍게)
        border_thickness = 3 + int(self.glow_intensity * 3)  # 더 두꺼운 테두리
        border_rect = pygame.Rect(x-2, y-2, size+4, size+4)
        pygame.draw.rect(screen, LEGENDARY_COLOR, border_rect, border_thickness)
        
        # 꼭지점 디테일 (코너 장식)
        corner_size = 8  # 더 큰 코너
        corner_color = (255, 215, 0)  # 황금색 (신의 무기)
        # 왼쪽 위
        pygame.draw.lines(screen, corner_color, False, 
                         [(x-2, y+corner_size), (x-2, y-2), (x+corner_size, y-2)], 2)
        # 오른쪽 위
        pygame.draw.lines(screen, corner_color, False,
                         [(x+size-corner_size+2, y-2), (x+size+2, y-2), (x+size+2, y+corner_size)], 2)
        # 왼쪽 아래
        pygame.draw.lines(screen, corner_color, False,
                         [(x-2, y+size-corner_size+2), (x-2, y+size+2), (x+corner_size, y+size+2)], 2)
        # 오른쪽 아래
        pygame.draw.lines(screen, corner_color, False,
                         [(x+size-corner_size+2, y+size+2), (x+size+2, y+size+2), (x+size+2, y+size-corner_size+2)], 2)
        
        # 코너 점 장식 (더 화려하게)
        for cx, cy in [(x, y), (x+size, y), (x, y+size), (x+size, y+size)]:
            pygame.draw.circle(screen, LEGENDARY_COLOR, (cx, cy), 3)
            pygame.draw.circle(screen, corner_color, (cx, cy), 2)
        
        # 애니메이션 프레임 그리기
        if self.animation_frames and len(self.animation_frames) > 0:
            # 프레임 업데이트 (항상 진행)
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)
            
            # 현재 프레임 그리기 (위아래 움직임 효과 포함)
            icon_y = y + int(self.animation_offset)
            current_icon = self.animation_frames[self.current_frame % len(self.animation_frames)]
            scaled_icon = pygame.transform.scale(current_icon, (size, size))
            screen.blit(scaled_icon, (x, icon_y))
            
            # 헤르메스 특수 효과 없음 (번개 효과 대신)
        else:
            # 프레임이 없으면 기본 신발 아이콘 그리기
            icon_y = y + int(self.animation_offset)
            shoe_color = (100, 200, 255)  # 하늘색
            wing_color = (255, 255, 255)  # 흰색
            
            # 신발 본체
            pygame.draw.ellipse(screen, shoe_color, (x + size//4, y + size//2, size//2, size//4))
            pygame.draw.ellipse(screen, (50, 150, 200), (x + size//4, y + size//2, size//2, size//4), 2)
            
            # 날개 (왼쪽)
            wing_points = [
                (x + size//4 - 5, y + size//2 + 5),
                (x + size//4 - 15, y + size//2),
                (x + size//4 - 10, y + size//2 + 10),
                (x + size//4, y + size//2 + 8)
            ]
            pygame.draw.polygon(screen, wing_color, wing_points)
            pygame.draw.polygon(screen, shoe_color, wing_points, 1)
            
            # 날개 (오른쪽)
            wing_points = [
                (x + size*3//4 + 5, y + size//2 + 5),
                (x + size*3//4 + 15, y + size//2),
                (x + size*3//4 + 10, y + size//2 + 10),
                (x + size*3//4, y + size//2 + 8)
            ]
            pygame.draw.polygon(screen, wing_color, wing_points)
            pygame.draw.polygon(screen, shoe_color, wing_points, 1)
        
        # 파티클 효과
        if self.particle_timer > 1000:
            self._spawn_particle(screen, x + size//2, y + size//2)
            self.particle_timer = 0
    


class RagnarokHammer(LegendaryItem):
    """라그나로크 해머 - 강력한 넉백 효과"""
    def __init__(self):
        super().__init__(
            name="ragnarok_hammer",
            korean_name="라그나로크 해머",
            description="보스가 공을 받을 때 공속에 비례한 강력한 넉백을 받고 0.6초간 스턴됩니다",
            unlock_condition="누적 넉백 거리 10,000 픽셀 달성",
            icon_path="items/legendary/ragnarok_hammer.png"  # 아이콘 경로 추가
        )
        self.knockback_multiplier = 5.0  # 넉백 배율 (3.0 -> 5.0 증가)
        self.max_knockback = 250  # 최대 넉백 거리 (150 -> 250 증가)
        self.thunder_effects = []  # 번개 효과 리스트
        self.impact_particles = []  # 충격 파티클
        self.stun_duration = 0.6  # 넉백 후 스턴 시간 (초)
        
        # 애니메이션 프레임 로드
        self.animation_frames = []
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8  # 프레임당 틱 수
        self._load_animation_frames()
        
        # 라그나로크 해머 전용 더 큰 글로우
        self.hammer_glow_multiplier = 1.8  # 헤르메스보다 더 큰 글로우
        
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """누적 넉백 거리 체크"""
        return game_stats.get("total_knockback_distance", 0) >= 10000
        
    def calculate_knockback(self, ball_speed: float, boss_x: float = 300) -> tuple:
        """
        공속에 비례한 수평 넉백 계산 (수류탄 방식)
        Returns: (horizontal_knockback_velocity, stun_duration)
        """
        if not self.active:
            return 0, 0
            
        import random
        
        # 수평 넉백 속도 계산 (수류탄 방식)
        horizontal_power = 10  # 기본 파워 (더 약하게 조정)
        
        # 공속에 비례하여 수평 넉백 강화
        speed_bonus = abs(ball_speed) * 0.5  # 공속의 0.5배를 보너스로 (감소)
        horizontal_power += speed_bonus
        
        # 보스 위치에 따라 방향 결정
        center_x = 300  # 화면 중앙
        if boss_x + 50 < center_x:  # 보스가 왼쪽에 있으면
            horizontal_velocity = horizontal_power  # 오른쪽으로 넉백
        else:  # 보스가 오른쪽에 있으면
            horizontal_velocity = -horizontal_power  # 왼쪽으로 넉백
        
        # 공속이 높을수록 수평 넉백 추가 강화 (더 약하게)
        if abs(ball_speed) >= 25:
            horizontal_velocity *= 1.15
        elif abs(ball_speed) >= 20:
            horizontal_velocity *= 1.1
        elif abs(ball_speed) >= 15:
            horizontal_velocity *= 1.05
            
        # 랜덤 추가 넉백 (10-30%)
        random_factor = 1.0 + random.uniform(0.1, 0.3)
        horizontal_velocity *= random_factor
            
        # 번개 효과 추가
        self._spawn_thunder_effect()
        
        print(f"    : {horizontal_velocity:.1f}, : {self.stun_duration:.1f}")
        
        # 넉백 속도와 스턴 시간을 함께 반환
        return horizontal_velocity, self.stun_duration
        
    def _spawn_thunder_effect(self):
        """번개 효과 생성"""
        import random
        import time
        self.thunder_effects.append({
            'time': time.time(),
            'duration': 0.5,
            'intensity': random.uniform(0.7, 1.0)
        })
        
    def draw_special_effects(self, screen, boss_x: int, boss_y: int):
        """특수 효과 그리기"""
        if not self.active:
            return
            
        import pygame
        import math
        import random
        import time
        
        current_time = time.time()
        
        # 번개 효과 그리기
        for effect in self.thunder_effects[:]:
            elapsed = current_time - effect['time']
            if elapsed > effect['duration']:
                self.thunder_effects.remove(effect)
                continue
                
            alpha = int(255 * (1 - elapsed / effect['duration']))
            
            # 번개 가지 그리기
            for _ in range(3):
                start_x = boss_x + random.randint(-30, 30)
                start_y = boss_y - 50
                end_x = boss_x + random.randint(-50, 50)
                end_y = boss_y + random.randint(-20, 20)
                
                # 지그재그 번개
                points = [(start_x, start_y)]
                segments = 5
                for i in range(segments):
                    t = (i + 1) / segments
                    x = start_x + (end_x - start_x) * t + random.randint(-20, 20)
                    y = start_y + (end_y - start_y) * t
                    points.append((x, y))
                points.append((end_x, end_y))
                
                # 번개 그리기 (두께 변화)
                for i in range(len(points) - 1):
                    thickness = max(1, int(5 * (1 - i / len(points)) * effect['intensity']))
                    color = (255, 255, min(255, 100 + alpha), alpha)
                    pygame.draw.line(screen, color[:3], points[i], points[i+1], thickness)
        
        # 충격파 효과
        if hasattr(self, 'last_impact_time'):
            elapsed = current_time - self.last_impact_time
            if elapsed < 0.3:  # 0.3초 동안 충격파 표시
                radius = int(elapsed * 500)  # 충격파 확산
                alpha = int(255 * (1 - elapsed / 0.3))
                
                # 여러 개의 충격파 원
                for i in range(3):
                    r = radius - i * 20
                    if r > 0:
                        pygame.draw.circle(screen, (255, 200, 100), 
                                         (boss_x, boss_y), r, 2)
        
    def on_boss_hit(self, boss_x: int, boss_y: int):
        """보스가 공을 맞았을 때"""
        if self.active:
            import time
            self.last_impact_time = time.time()
            
            # 화면 흔들림 효과 추가 (선택사항)
            # 파티클 효과 추가
            import random
            for _ in range(10):
                self.impact_particles.append({
                    'x': boss_x + random.randint(-20, 20),
                    'y': boss_y + random.randint(-20, 20),
                    'vx': random.uniform(-5, 5),
                    'vy': random.uniform(-5, 5),
                    'life': 30
                })
    
    def _load_animation_frames(self):
        """애니메이션 프레임 로드"""
        import pygame
        import os
        
        # 8개 프레임 로드 시도
        frames_loaded = 0
        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                frame = pygame.image.load(frame_path).convert_alpha()
                self.animation_frames.append(frame)
                frames_loaded += 1
                print(f"✓ 프레임 {i} 로드 성공: {frame_path}")
            except Exception as e:
                print(f"✗ 프레임 {i} 로드 실패: {frame_path} - {e}")
        
        print(f"라그나로크 해머 프레임 {frames_loaded}/8개 로드")
        
        # 프레임이 없으면 에러만 표시 (가짜 애니메이션 생성하지 않음)
        if not self.animation_frames:
            print(f"❌ 라그나로크 해머: PNG 프레임을 찾을 수 없습니다!")
    
    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """애니메이션 아이콘 그리기"""
        import pygame
        import math
        
        # 글로우 효과 (라그나로크 해머는 더 크고 강렬하게)
        glow_size = int(size * (self.hammer_glow_multiplier + self.glow_intensity * 0.15))
        glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
        for i in range(5):  # 더 많은 레이어로 강렬한 효과
            alpha = 80 - i * 12  # 더 진한 글로우
            pygame.draw.circle(glow_surf, (*LEGENDARY_COLOR, alpha), 
                             (glow_size//2, glow_size//2), 
                             glow_size//2 - i * 4)  # 더 촘촘한 간격
        screen.blit(glow_surf, (x - (glow_size - size)//2, y - (glow_size - size)//2))
        
        # 붉은색 테두리 (펄싱 효과 - 더 두껍게)
        border_thickness = 3 + int(self.glow_intensity * 3)  # 더 두꺼운 테두리
        border_rect = pygame.Rect(x-2, y-2, size+4, size+4)
        pygame.draw.rect(screen, LEGENDARY_COLOR, border_rect, border_thickness)
        
        # 꼭지점 디테일 (코너 장식)
        corner_size = 8  # 더 큰 코너
        corner_color = (255, 215, 0)  # 황금색 (신의 무기)
        # 왼쪽 위
        pygame.draw.lines(screen, corner_color, False, 
                         [(x-2, y+corner_size), (x-2, y-2), (x+corner_size, y-2)], 2)
        # 오른쪽 위
        pygame.draw.lines(screen, corner_color, False,
                         [(x+size-corner_size+2, y-2), (x+size+2, y-2), (x+size+2, y+corner_size)], 2)
        # 왼쪽 아래
        pygame.draw.lines(screen, corner_color, False,
                         [(x-2, y+size-corner_size+2), (x-2, y+size+2), (x+corner_size, y+size+2)], 2)
        # 오른쪽 아래
        pygame.draw.lines(screen, corner_color, False,
                         [(x+size-corner_size+2, y+size+2), (x+size+2, y+size+2), (x+size+2, y+size-corner_size+2)], 2)
        
        # 코너 점 장식 (더 화려하게)
        for cx, cy in [(x, y), (x+size, y), (x, y+size), (x+size, y+size)]:
            pygame.draw.circle(screen, LEGENDARY_COLOR, (cx, cy), 3)
            pygame.draw.circle(screen, corner_color, (cx, cy), 2)
        
        # 애니메이션 프레임 그리기
        if self.animation_frames and len(self.animation_frames) > 0:
            # 프레임 업데이트 (항상 진행)
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)
            
            # 현재 프레임 그리기 (위아래 움직임 효과 포함)
            icon_y = y + int(self.animation_offset)
            current_icon = self.animation_frames[self.current_frame % len(self.animation_frames)]
            scaled_icon = pygame.transform.scale(current_icon, (size, size))
            screen.blit(scaled_icon, (x, icon_y))
            
            # 번개 효과 추가 (프레임 0, 4에서)
            if self.current_frame in [0, 4]:
                # 작은 번개 이펙트
                bolt_color = (255, 255, 150)
                pygame.draw.line(screen, bolt_color, 
                               (x + size//4, y - 5), 
                               (x + size//3, y + size//4), 2)
                pygame.draw.line(screen, bolt_color,
                               (x + size*3//4, y - 5),
                               (x + size*2//3, y + size//4), 2)
        
        # 파티클 효과
        if self.particle_timer > 1000:
            self._spawn_particle(screen, x + size//2, y + size//2)
            self.particle_timer = 0
    
    def update(self, dt: float):
        """애니메이션 업데이트"""
        super().update(dt)
        
        # 애니메이션 프레임 카운터 업데이트 (draw_icon에서도 처리하지만 여기서도 추가)
        if self.animation_frames and len(self.animation_frames) > 1:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)
        
        # 파티클 업데이트
        for particle in self.impact_particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1
            particle['vy'] += 0.3  # 중력
            
            if particle['life'] <= 0:
                self.impact_particles.remove(particle)
    
    def draw_particles(self, screen):
        """파티클 그리기"""
        if not self.active:
            return
            
        import pygame
        for particle in self.impact_particles:
            alpha = particle['life'] * 8
            color = (255, 200, 100)
            size = max(1, particle['life'] // 10)
            pygame.draw.circle(screen, color, 
                             (int(particle['x']), int(particle['y'])), size)


# 전설 아이템 관리자
class LegendaryItemManager:
    """전설 아이템 시스템 관리"""
    def __init__(self):
        self.items: Dict[str, LegendaryItem] = {}
        self.unlocked_items: List[str] = []
        self.active_items: List[str] = []
        self._initialize_items()
        
    def _initialize_items(self):
        """전설 아이템 초기화"""
        # 모든 전설 아이템 등록
        self.items["infinity_gauntlet"] = InfinityGauntlet()
        self.items["phoenix_feather"] = PhoenixFeather()
        self.items["chronos_clock"] = ChronosClock()
        self.items["excalibur_blade"] = ExcaliburBlade()
        self.items["ragnarok_hammer"] = RagnarokHammer()
        self.items["hermes_shoes"] = HermesShoes()
        self.items["poseidon_trident"] = PoseidonTrident()
        
        # 테스트용: 전설 아이템 강제 해금
        self.items["ragnarok_hammer"].unlocked = True
        if "ragnarok_hammer" not in self.unlocked_items:
            self.unlocked_items.append("ragnarok_hammer")
        
        self.items["hermes_shoes"].unlocked = True
        if "hermes_shoes" not in self.unlocked_items:
            self.unlocked_items.append("hermes_shoes")
            
        self.items["poseidon_trident"].unlocked = True
        if "poseidon_trident" not in self.unlocked_items:
            self.unlocked_items.append("poseidon_trident")
    
    def _init_legendary_items(self):
        """전설 아이템 초기화 (애니메이션용)"""
        # 라그나로크 해머 초기화
        if "ragnarok_hammer" not in self.items:
            self.items["ragnarok_hammer"] = RagnarokHammer()
        # 헤르메스 신발 초기화
        if "hermes_shoes" not in self.items:
            self.items["hermes_shoes"] = HermesShoes()
        # 포세이돈의 삼지창 초기화
        if "poseidon_trident" not in self.items:
            self.items["poseidon_trident"] = PoseidonTrident()
        
    def check_unlocks(self, game_stats: Dict):
        """해금 조건 체크"""
        for item_name, item in self.items.items():
            if not item.unlocked and item.check_unlock_condition(game_stats):
                item.unlocked = True
                self.unlocked_items.append(item_name)
                print(f"   [{item.korean_name}] !")
                
    def get_unlocked_items(self) -> List[LegendaryItem]:
        """해금된 아이템 목록 반환"""
        return [self.items[name] for name in self.unlocked_items]
        
    def get_item(self, name: str) -> Optional[LegendaryItem]:
        """아이템 가져오기"""
        return self.items.get(name)
        
    def activate_item(self, name: str, game_state: Dict):
        """아이템 활성화"""
        if name in self.items and name in self.unlocked_items:
            item = self.items[name]
            item.activate(game_state)
            if name not in self.active_items:
                self.active_items.append(name)
                
    def deactivate_item(self, name: str):
        """아이템 비활성화"""
        if name in self.items:
            self.items[name].deactivate()
            if name in self.active_items:
                self.active_items.remove(name)
                
    def update(self, dt: float):
        """모든 활성 아이템 업데이트"""
        for name in self.active_items:
            if name in self.items:
                self.items[name].update(dt)
                
    def draw_active_items(self, screen: pygame.Surface, x: int, y: int):
        """활성 아이템 표시"""
        for i, name in enumerate(self.active_items):
            if name in self.items:
                item = self.items[name]
                item.draw_icon(screen, x + i * 70, y, 60)
                
    def save_state(self) -> Dict:
        """상태 저장"""
        return {
            "unlocked_items": self.unlocked_items,
            "active_items": self.active_items
        }
        
    def load_state(self, state: Dict):
        """상태 로드"""
        self.unlocked_items = state.get("unlocked_items", [])
        self.active_items = state.get("active_items", [])
        # 해금 상태 복원
        for name in self.unlocked_items:
            if name in self.items:
                self.items[name].unlocked = True
        # 활성 상태 복원
        for name in self.active_items:
            if name in self.items:
                self.items[name].active = True


# 싱글톤 인스턴스
_legendary_manager = None

def get_legendary_manager() -> LegendaryItemManager:
    """전설 아이템 매니저 싱글톤 반환"""
    global _legendary_manager
    if _legendary_manager is None:
        _legendary_manager = LegendaryItemManager()
    return _legendary_manager

def reset_legendary_manager():
    """전설 아이템 매니저 리셋"""
    global _legendary_manager
    _legendary_manager = None