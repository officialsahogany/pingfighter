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
        self.wave_timer = 0
        self.dash_wave_active = False
        self.dash_wave_timer = 0
        
        # 거대한 물결 회오리 효과 속성 - 양쪽 회오리 지원
        self.vortex_active = False
        self.vortex_timer = 0
        # 왼쪽 회오리
        self.vortex_left_x = 0
        self.vortex_left_y = 0
        self.vortex_left_height = 0  # 시작 높이
        # 오른쪽 회오리
        self.vortex_right_x = 0
        self.vortex_right_y = 0
        self.vortex_right_height = 0  # 시작 높이
        # 공통 속성
        self.vortex_max_height = 400  # 최대 높이 (화면 대부분 커버)
        self.vortex_width = 200  # 회오리 너비 (대폭 증가 for better collision)
        self.vortex_spin_speed = 0  # 회전 속도
        self.vortex_particles = []  # 회오리 파티클
        
        # 공 반사 효과 속성
        self.deflection_power = 15.0  # 반사 힘
        self.spin_power = 8.0  # 드라이브 회전력
        
        # 물의 추진력 지속 효과
        self.water_momentum_active = False  # 물에서 나온 후 추진력 유지
        self.water_momentum_timer = 0  # 추진력 유지 타이머
        self.water_momentum_force_y = 0  # 유지되는 Y축 힘
        self.water_momentum_force_x = 0  # 유지되는 X축 힘
        
        # 애니메이션용 아이콘 프레임들
        self.icon_frames = []
        self.animation_frames = []  # legendary_acquisition에서 사용하는 속성
        self.current_frame = 0
        self.frame_timer = 0
        self.frame_counter = 0  # 프레임 카운터 추가
        self.animation_speed = 8  # 애니메이션 속도 (라그나로크와 동일)
        self.load_animation_frames()
        
    def load_animation_frames(self):
        """애니메이션 프레임 로드 - PNG 파일 사용 (라그나로크/헤르메스와 동일)"""
        import pygame
        import os
        
        # 포세이돈 삼지창 PNG 파일 로드
        frames_loaded = 0
        for i in range(8):
            frame_path = resource_path(f"items/legendary/poseidon_trident_frame_{i}.png")
            try:
                frame = pygame.image.load(frame_path).convert_alpha()
                self.icon_frames.append(frame)
                self.animation_frames.append(frame)  # legendary_acquisition에서 사용
                frames_loaded += 1
                print(f"✓ 포세이돈 삼지창 프레임 {i} 로드 성공")
            except Exception as e:
                print(f"✗ 프레임 {i} 로드 실패: {frame_path} - {e}")
        
        print(f"포세이돈 삼지창: PNG 프레임 {frames_loaded}/8개 로드")
        
        # 프레임이 없으면 에러만 표시 (가짜 애니메이션 생성하지 않음)
        if not self.icon_frames or len(self.icon_frames) == 0:
            print("❌ 포세이돈 삼지창: PNG 프레임을 찾을 수 없습니다!")
                
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """스테이지 7 클리어 체크"""
        return game_stats.get("highest_stage_cleared", 0) >= 7
        
    def activate(self, game_state: Dict):
        """삼지창 활성화"""
        print(f"🔱 [BEFORE] PoseidonTrident.activate 호출, self.active = {self.active}")
        super().activate(game_state)  # 부모 클래스의 activate 호출 (self.active = True 설정)
        self.wave_timer = 0
        print(f"🔱 [AFTER] {self.korean_name} 활성화!")
        print(f"   - self.active = {self.active}")
        print(f"   - 물의 파동이 공을 조작합니다!")
        
        # 강제로 active 확인
        if not self.active:
            print(f"⚠️ WARNING: self.active가 False입니다! 강제로 True로 설정합니다.")
            self.active = True
            
    def deactivate(self):
        """삼지창 비활성화"""
        self.active = False
        self.dash_wave_active = False
        
    def stop_water_momentum(self):
        """물의 추진력 즉시 중단 (보스 패들에 맞았을 때)"""
        self.water_momentum_active = False
        self.water_momentum_timer = 0
        self.water_momentum_force_y = 0
        self.water_momentum_force_x = 0
        print(f"🔱 물의 추진력 종료 - 보스 패들 충돌")
        
    def apply_trajectory_influence(self, ball_x: float, ball_y: float, 
                                  ball_vx: float, ball_vy: float, 
                                  paddle_x: float, paddle_y: float) -> Tuple[float, float]:
        """공의 궤적에 물의 파동 영향 적용 (회오리가 없을 때만)"""
        if not self.active:
            return ball_vx, ball_vy
        
        # 회오리가 활성화되어 있으면 trajectory influence 비활성화
        # (회오리가 모든 물 효과를 대체함)
        if self.vortex_active:
            return ball_vx, ball_vy
            
        # 패들과의 거리 계산
        distance = math.sqrt((ball_x - paddle_x) ** 2 + (ball_y - paddle_y) ** 2)
        
        # 영향 범위를 200픽셀로 축소 (기존 400에서 감소)
        reduced_radius = 200  # 더 가까운 범위에서만 작동
        
        # 영향 범위 내에 있을 때만
        if distance < reduced_radius:
            # 거리에 따른 영향력 계산 (가까울수록 강함)
            influence = (1 - distance / reduced_radius) * self.trajectory_influence * 0.5  # 영향력도 반으로 감소
            
            # 물결 효과로 미세한 궤적 변경 (사인파)
            wave_effect_x = math.sin(self.wave_timer * 0.1) * influence
            wave_effect_y = math.cos(self.wave_timer * 0.1) * influence * 0.5
            
            # 속도에 물결 효과 적용
            new_vx = ball_vx * (1 + wave_effect_x)
            new_vy = ball_vy * (1 + wave_effect_y)
            
            return new_vx, new_vy
            
        return ball_vx, ball_vy
        
    def trigger_dash_wave(self, paddle_x: float, paddle_y: float, direction: int = 0):
        """대시 후 통제불능 시 양쪽에 거대한 물결 회오리 발동"""
        print(f"🔱 [trigger_dash_wave] 호출됨!")
        print(f"   - self.active: {self.active}")
        print(f"   - paddle_pos: ({paddle_x:.0f}, {paddle_y:.0f})")
        if not self.active:
            print(f"⚠️ 포세이돈 삼지창이 비활성화 상태입니다!")
            return
            
        self.dash_wave_active = True
        self.dash_wave_timer = 0
        
        # 거대한 물결 회오리 활성화 - 양쪽에 생성
        self.vortex_active = True
        self.vortex_timer = 0
        
        # 왼쪽 회오리 (패들 왼쪽 150픽셀)
        self.vortex_left_x = paddle_x - 150
        self.vortex_left_y = paddle_y
        self.vortex_left_height = 0
        
        # 오른쪽 회오리 (패들 오른쪽 150픽셀)
        self.vortex_right_x = paddle_x + 150
        self.vortex_right_y = paddle_y
        self.vortex_right_height = 0
        
        self.vortex_spin_speed = 0
        
        print(f"🔱 포세이돈 양쪽 회오리 발동! 중심: ({paddle_x:.0f}, {paddle_y:.0f})")
        print(f"   왼쪽: ({self.vortex_left_x:.0f}, {self.vortex_left_y:.0f})")
        print(f"   오른쪽: ({self.vortex_right_x:.0f}, {self.vortex_right_y:.0f})")
        print(f"   Active: {self.active}, Vortex: {self.vortex_active}")
        
        # 양쪽 회오리에 대한 파티클 대량 생성 (용솟음치는 효과)
        # 왼쪽 회오리 파티클
        for i in range(30):  # 각 회오리당 30개
            angle = (i / 10) * math.pi * 2
            height_offset = random.uniform(0, 200)
            particle = {
                "x": self.vortex_left_x + random.uniform(-30, 30),
                "y": self.vortex_left_y - height_offset,
                "vx": math.cos(angle) * random.uniform(2, 8),
                "vy": random.uniform(-8, -3),  # 위로 솟구치는 속도
                "life": random.randint(40, 80),
                "color": (50, 150 + random.randint(0, 100), 255),
                "size": random.uniform(3, 10),
                "spiral_angle": angle,
                "spiral_radius": random.uniform(20, 60),
                "vortex_side": "left"  # 왼쪽 회오리 표시
            }
            self.vortex_particles.append(particle)
        
        # 오른쪽 회오리 파티클
        for i in range(30):  # 각 회오리당 30개
            angle = (i / 10) * math.pi * 2
            height_offset = random.uniform(0, 200)
            particle = {
                "x": self.vortex_right_x + random.uniform(-30, 30),
                "y": self.vortex_right_y - height_offset,
                "vx": math.cos(angle) * random.uniform(2, 8),
                "vy": random.uniform(-8, -3),  # 위로 솟구치는 속도
                "life": random.randint(40, 80),
                "color": (50, 150 + random.randint(0, 100), 255),
                "size": random.uniform(3, 10),
                "spiral_angle": angle,
                "spiral_radius": random.uniform(20, 60),
                "vortex_side": "right"  # 오른쪽 회오리 표시
            }
            self.vortex_particles.append(particle)
                
    def apply_dash_wave_to_ball(self, ball_x: float, ball_y: float,
                               ball_vx: float, ball_vy: float,
                               paddle_x: float, paddle_y: float,
                               player_x: float = None, player_y: float = None) -> Tuple[float, float]:
        """거대한 물결 회오리가 공에 미치는 굴절 효과 (Stage 4 자기장과 동일한 메커니즘)"""
        
        # 디버그: 함수 진입
        print(f"🔍 [apply_dash_wave_to_ball] 진입")
        print(f"   - ball_pos: ({ball_x:.0f}, {ball_y:.0f})")
        print(f"   - ball_vel: ({ball_vx:.1f}, {ball_vy:.1f})")
        print(f"   - vortex_active: {self.vortex_active}")
        print(f"   - dash_wave_active: {self.dash_wave_active}")
        print(f"   - water_momentum_active: {self.water_momentum_active}")
        
        # 물 추진력이 남아있으면 계속 적용
        if self.water_momentum_active:
            print(f"💧 [WATER MOMENTUM] 활성화됨!")
            # 추진력 타이머 감소
            self.water_momentum_timer -= 0.016  # 60fps 기준
            
            if self.water_momentum_timer <= 0:
                # 추진력 종료
                print(f"💧 [WATER MOMENTUM] 종료")
                self.water_momentum_active = False
                self.water_momentum_force_y = 0
                self.water_momentum_force_x = 0
            else:
                # 추진력 적용 (시간이 지나면서 약해짐)
                fade_factor = self.water_momentum_timer / 2.0  # 2초 동안 서서히 감소
                new_vx = ball_vx + self.water_momentum_force_x * fade_factor
                new_vy = ball_vy + self.water_momentum_force_y * fade_factor
                print(f"💧 [WATER MOMENTUM] 적용: ({ball_vx:.1f}, {ball_vy:.1f}) → ({new_vx:.1f}, {new_vy:.1f})")
                return (new_vx, new_vy)
        
        if not self.dash_wave_active and not self.vortex_active:
            print(f"🔍 [apply_dash_wave_to_ball] 비활성 상태 - 원래 속도 반환")
            return ball_vx, ball_vy
            
        # 거대한 회오리 효과 (우선 처리) - 양쪽 회오리 체크
        if self.vortex_active:
            # 회오리의 Y축 범위 (시간에 따라 확장)
            left_vortex_height = min(self.vortex_left_height, self.vortex_max_height)
            right_vortex_height = min(self.vortex_right_height, self.vortex_max_height)
            
            # 왼쪽 회오리 충돌 체크
            x_distance_left = abs(ball_x - self.vortex_left_x)
            x_in_left_vortex = x_distance_left <= (self.vortex_width / 2 + 10)  # 범위를 더 넓게 설정 (+10픽셀)
            # Y축 체크: 회오리는 아래에서 위로 올라가므로, 공이 회오리 높이 범위 안에 있는지 체크
            # 회오리 아래쪽(패들 위치)부터 위로 솟은 높이까지 + 여유 공간
            y_in_left_vortex = (self.vortex_left_y - left_vortex_height - 20) <= ball_y <= (self.vortex_left_y + 100)
            
            # 오른쪽 회오리 충돌 체크
            x_distance_right = abs(ball_x - self.vortex_right_x)
            x_in_right_vortex = x_distance_right <= (self.vortex_width / 2 + 10)  # 범위를 더 넓게 설정 (+10픽셀)
            # Y축 체크: 회오리는 아래에서 위로 올라가므로, 공이 회오리 높이 범위 안에 있는지 체크
            y_in_right_vortex = (self.vortex_right_y - right_vortex_height - 20) <= ball_y <= (self.vortex_right_y + 100)
            
            # 어느 쪽 회오리에든 들어갔는지 확인
            in_left = x_in_left_vortex and y_in_left_vortex
            in_right = x_in_right_vortex and y_in_right_vortex
            
            # 디버그: 회오리 위치와 크기 (최초 1회만)
            if not hasattr(self, '_vortex_debug_shown'):
                print(f"🌊 [VORTEX INFO]")
                print(f"   왼쪽 회오리: X={self.vortex_left_x:.0f}, Y={self.vortex_left_y:.0f}, 너비={self.vortex_width:.0f}")
                print(f"   오른쪽 회오리: X={self.vortex_right_x:.0f}, Y={self.vortex_right_y:.0f}, 너비={self.vortex_width:.0f}")
                print(f"   최대 높이: {self.vortex_max_height:.0f}")
                self._vortex_debug_shown = True
            in_any_vortex = in_left or in_right
            
            # 어느 회오리에 들어갔는지에 따라 중심점 결정
            if in_left:
                vortex_x = self.vortex_left_x
                vortex_y = self.vortex_left_y
                current_vortex_height = left_vortex_height
                vortex_side = "왼쪽"
            elif in_right:
                vortex_x = self.vortex_right_x
                vortex_y = self.vortex_right_y
                current_vortex_height = right_vortex_height
                vortex_side = "오른쪽"
            else:
                vortex_x = 0
                vortex_y = 0
                current_vortex_height = 0
                vortex_side = "없음"
            
            # 디버그: 충돌 체크 상태 (항상 출력)
            if pygame.time.get_ticks() % 100 < 16:  # 0.1초마다 한 번
                print(f"🎯 [VORTEX CHECK] Ball=({ball_x:.0f},{ball_y:.0f}), vy={ball_vy:.1f}")
                print(f"   왼쪽 회오리: 중심X={self.vortex_left_x:.0f}, Y범위=[{self.vortex_left_y - left_vortex_height - 20:.0f} ~ {self.vortex_left_y + 100:.0f}]")
                print(f"   오른쪽 회오리: 중심X={self.vortex_right_x:.0f}, Y범위=[{self.vortex_right_y - right_vortex_height - 20:.0f} ~ {self.vortex_right_y + 100:.0f}]")
                print(f"   왼쪽: X거리={x_distance_left:.0f}, X범위={x_in_left_vortex}, Y범위={y_in_left_vortex}, 충돌={in_left}")
                print(f"   오른쪽: X거리={x_distance_right:.0f}, X범위={x_in_right_vortex}, Y범위={y_in_right_vortex}, 충돌={in_right}")
                if in_left:
                    print(f"   💫 왼쪽 회오리 충돌! 중심=({vortex_x:.0f},{vortex_y:.0f}), 높이={current_vortex_height:.0f}")
                elif in_right:
                    print(f"   💫 오른쪽 회오리 충돌! 중심=({vortex_x:.0f},{vortex_y:.0f}), 높이={current_vortex_height:.0f}")
            print(f"🌊 [VORTEX 충돌체크]")
            print(f"   - 공 위치: ({ball_x:.0f}, {ball_y:.0f})")
            print(f"   - 왼쪽 회오리: 중심=({self.vortex_left_x:.0f}, {self.vortex_left_y:.0f}), 높이={left_vortex_height:.0f}")
            print(f"   - 오른쪽 회오리: 중심=({self.vortex_right_x:.0f}, {self.vortex_right_y:.0f}), 높이={right_vortex_height:.0f}")
            print(f"   - 왼쪽 충돌: {in_left}, 오른쪽 충돌: {in_right}")
            print(f"   - 최종 결과: 회오리 안={'예 (' + vortex_side + ')' if in_any_vortex else '아니오'}")
            
            if in_any_vortex:
                print(f"⭐ 공이 물회오리 안에 있음!")
                print(f"   - 공 위치: ({ball_x:.0f}, {ball_y:.0f})")
                print(f"   - 공 속도: vx={ball_vx:.1f}, vy={ball_vy:.1f}")
                print(f"   - 회오리 중심: ({vortex_x:.0f}, {vortex_y:.0f}) [{vortex_side}]")
                print(f"   - 회오리 크기: width={self.vortex_width}, height={current_vortex_height:.0f}")
                
                # 회오리 효과는 모든 공에 적용
                # (이전에는 방향으로 필터링했지만, 회오리는 모든 공에 영향을 줌)
                print(f"✅ 회오리 효과 적용 시작: vx={ball_vx:.1f}, vy={ball_vy:.1f}")
                
                # === Stage 4 굴절자기장과 동일한 메커니즘 적용 ===
                # 회오리 중심과의 거리 계산
                # 회오리는 패들 위치에서 위로 솟아오르므로, Y축 거리는 회오리 범위 내에서만 계산
                vortex_center_y = vortex_y - current_vortex_height/2  # 회오리의 실제 중심
                # 공이 회오리 Y 범위 내에 있으면 Y축 거리는 0으로 처리
                if vortex_y - current_vortex_height <= ball_y <= vortex_y:
                    y_distance = 0  # 회오리 Y 범위 내에 있음
                else:
                    y_distance = abs(ball_y - vortex_center_y)
                
                distance = math.sqrt((ball_x - vortex_x) ** 2 + y_distance ** 2)
                
                # 회오리 반경 (충돌 범위를 더 크게 설정)
                # 시각 효과와 동일하게 설정하여 보이는 대로 작동하도록 함
                vortex_radius = min(self.vortex_width / 2, 100)  # 최대 반경 100
                
                
                print(f"   - 거리: {distance:.1f}, 반경: {vortex_radius:.1f}")
                
                if distance < vortex_radius:
                    print(f"🎯 회오리 영향 범위 내!")
                    print(f"   - 공 위치: ({ball_x:.0f}, {ball_y:.0f})")
                    print(f"   - 회오리 중심: ({vortex_x:.0f}, {vortex_y:.0f})")
                    print(f"   - 거리: {distance:.1f} < 반경: {vortex_radius:.1f}")
                    
                    # 거리 기반 굴절 강도 계산 (중심에 가까울수록 강함)
                    refraction_strength = 1.0 - (distance / vortex_radius)
                    # 굴절 강도 대폭 증가 (최소 0.7 보장)
                    refraction_strength = max(0.7, refraction_strength)  # 최소 70% 강도 보장
                    
                    print(f"   - 굴절 강도: {refraction_strength:.3f}")
                    print(f"   - 원래 속도: vx={ball_vx:.1f}, vy={ball_vy:.1f}")
                    
                    # 현재 속도 벡터의 각도와 속력
                    current_angle = math.atan2(ball_vy, ball_vx)
                    current_speed = math.sqrt(ball_vx ** 2 + ball_vy ** 2)
                    
                    # 목표 방향 계산
                    # 보스가 친 공(아래로 가는 공)은 위로(보스 방향으로) 반사
                    # 플레이어 위치 사용 (전달되지 않으면 기본값 사용)
                    if player_x is None:
                        player_x = 400  # 화면 중앙 기본값
                    if player_y is None:
                        player_y = 550  # 화면 하단 기본값
                    
                    if ball_vy > 0:  # 보스가 친 공 (아래로 향하는)
                        # 보스 방향으로 반사 (위로)
                        boss_x = 400  # 보스는 화면 중앙
                        boss_y = 50   # 보스는 화면 상단
                        
                        print(f"📍 보스 방향으로 반사 설정")
                        print(f"   - 보스 위치: ({boss_x}, {boss_y})")
                        
                        direction_to_target_x = boss_x - ball_x
                        direction_to_target_y = boss_y - ball_y
                        distance_to_target = math.sqrt(direction_to_target_x ** 2 + direction_to_target_y ** 2)
                        
                        if distance_to_target > 0:
                            direction_to_target_x /= distance_to_target
                            direction_to_target_y /= distance_to_target
                            print(f"   - 정규화된 방향: ({direction_to_target_x:.3f}, {direction_to_target_y:.3f})")
                    else:
                        # 플레이어가 친 공은 원래대로 (하지만 이미 위에서 걸러짐)
                        direction_to_target_x = player_x - ball_x
                        direction_to_target_y = player_y - ball_y
                        distance_to_target = math.sqrt(direction_to_target_x ** 2 + direction_to_target_y ** 2)
                        
                        if distance_to_target > 0:
                            direction_to_target_x /= distance_to_target
                            direction_to_target_y /= distance_to_target
                    
                    # 목표 각도
                    target_angle = math.atan2(direction_to_target_y, direction_to_target_x)
                    
                    # 각도 차이 계산
                    angle_diff = target_angle - current_angle
                    # 각도를 -π ~ π 범위로 정규화 (최적화)
                    angle_diff = math.atan2(math.sin(angle_diff), math.cos(angle_diff))
                    
                    # 굴절 적용 (강력한 굴절 효과)
                    # 보스가 친 공은 강하게 반사
                    if ball_vy > 0:  # 보스가 친 공
                        # 매우 강력한 굴절 (거의 직각으로 반사)
                        max_refraction = 3.14  # π radians (180도 - 완전 역방향)
                        refraction_amount = angle_diff * refraction_strength * 1.5  # 150% 굴절
                    else:
                        max_refraction = 0.52  # 약 30도 in radians
                        refraction_amount = angle_diff * refraction_strength * 0.3
                    refraction_amount = max(-max_refraction, min(max_refraction, refraction_amount))
                    
                    # 새로운 각도 계산
                    new_angle = current_angle + refraction_amount
                    
                    # 회전 효과 추가 (물 회오리 특성)
                    spin_effect = math.sin(self.vortex_timer * 8) * 0.1 * refraction_strength
                    new_angle += spin_effect
                    
                    # 물 회오리 내부에서 포물선 움직임 (감속 → 정점 → 가속)
                    # 공이 들어와서 천천히 감속했다가 다시 가속하며 반사
                    if ball_vy > 0:  # 보스가 친 공
                        # 회오리 중심까지의 수직 거리 비율 계산 (0: 진입, 1: 중심)
                        vertical_progress = 1.0 - ((ball_y - (vortex_y - current_vortex_height)) / current_vortex_height)
                        vertical_progress = max(0.0, min(1.0, vertical_progress))  # 0~1 범위로 제한
                        
                        # 포물선 곡선: 처음엔 빠르게 감속, 중간에 최저점, 이후 가속
                        # 사인 곡선을 사용하여 부드러운 감속-가속 패턴 생성
                        decel_curve = math.sin(vertical_progress * math.pi)  # 0→1→0 곡선
                        
                        # 속도 변화: 진입시 100% → 중간 30% → 반사시 다시 증가
                        speed_factor = 1.0 - (decel_curve * 0.7)  # 최대 70% 감속
                        speed_reduction = decel_curve * 0.7  # 디버그용 변수 추가
                        new_speed = current_speed * speed_factor
                        
                        # 최소 속도 보장
                        min_speed = 3.0
                        if new_speed < min_speed:
                            new_speed = min_speed
                        
                        print(f"   💧 포물선 움직임: 진행도={vertical_progress:.2f}, 곡선={decel_curve:.2f}, 속도비={speed_factor:.2f}")
                        print(f"   💧 속도 변화: {current_speed:.1f} → {new_speed:.1f}")
                    else:
                        # 플레이어가 친 공은 약간 증폭
                        speed_boost = 1.0 + refraction_strength * 0.3  # 최대 30% 속도 증가
                        new_speed = current_speed * speed_boost
                        # 속도 상한
                        max_speed = 30
                        if new_speed > max_speed:
                            new_speed = max_speed
                    
                    # 새로운 속도 벡터 계산
                    new_vx = math.cos(new_angle) * new_speed
                    new_vy = math.sin(new_angle) * new_speed
                    
                    # X축 속도도 부드럽게 조절 (자연스러운 궤적 유지)
                    # 원래 X속도와 새로운 X속도를 보간하여 급격한 변화 방지
                    x_blend_factor = 0.6  # 60%만 새로운 속도 적용
                    new_vx = ball_vx * (1.0 - x_blend_factor) + new_vx * x_blend_factor
                    
                    # X축 속도 상한 설정 (너무 빠른 횡방향 이동 방지)
                    max_x_speed = 12.0
                    if abs(new_vx) > max_x_speed:
                        new_vx = max_x_speed if new_vx > 0 else -max_x_speed
                    
                    # 상승 효과 추가 (물 회오리 특성)
                    if ball_vy > 0:  # 보스가 친 공은 부드럽게 위로 반사
                        print(f"🔄 보스 공 반사 처리")
                        print(f"   - 굴절 후 속도: vx={new_vx:.1f}, vy={new_vy:.1f}")
                        
                        # 포물선 움직임의 반사 부분 - 가속하면서 튕겨나감
                        # vertical_progress가 1에 가까울수록 (중심에 가까울수록) 더 강한 반사
                        
                        # 1. 반사 시점의 가속도 계산
                        # 중심에서 멀어질수록 가속 (역포물선)
                        acceleration_factor = 1.0 + (vertical_progress * 0.8)  # 최대 180% 속도로 가속
                        
                        # 2. Y축 반사 - 가속하면서 위로
                        # 감속된 속도가 아닌 가속된 속도로 반사
                        reflected_speed = new_speed * acceleration_factor
                        new_vy = -reflected_speed * 0.9  # 90% 반사 (강력한 반사)
                        
                        # 3. 추가 추진력 (물 회오리의 밀어내는 힘)
                        push_force = -5.0 * vertical_progress  # 중심에 가까울수록 강한 추진 (3.0 -> 5.0 증가)
                        new_vy += push_force
                        
                        print(f"   🚀 가속 반사: 진행도={vertical_progress:.2f}, 가속비={acceleration_factor:.2f}")
                        print(f"   🚀 반사 속도: 감속={new_speed:.1f} → 가속={reflected_speed:.1f} → Y속도={new_vy:.1f}")
                        print(f"   🚀 추진력: {push_force:.1f}")
                        
                        # 4. 최대 반사 속도 제한 (너무 빠르면 안됨)
                        max_reflect_speed = -20.0
                        if new_vy < max_reflect_speed:
                            new_vy = max_reflect_speed
                        
                        print(f"   - 최종 Y속도: {new_vy:.1f}")
                        
                        # 디버그: 공 굴절 성공 알림
                        print(f"")
                        print(f"=" * 60)
                        print(f"⚡⚡⚡ 회오리가 보스 공을 성공적으로 튕겨냈습니다! ⚡⚡⚡")
                        print(f"   원래 속도: ({ball_vx:.1f}, {ball_vy:.1f})")
                        print(f"   변경 속도: ({new_vx:.1f}, {new_vy:.1f})")
                        print(f"   굴절각도: {math.degrees(math.atan2(new_vy, new_vx)):.1f}도")
                        print(f"   회오리 위치: {vortex_side}")
                        print(f"=" * 60)
                        print(f"")
                    else:
                        # 플레이어가 친 공은 기존 상승 효과
                        upward_boost = -8.0 * refraction_strength * (1 - self.vortex_timer / 2.0)
                        new_vy += upward_boost
                    
                    # 물 추진력 비활성화 (회오리 밖에서 영향을 주지 않도록)
                    # 원래는 물에서 나온 후에도 추진력이 지속되었지만, 이제는 회오리 안에서만 작동
                    self.water_momentum_active = False
                    self.water_momentum_timer = 0
                    self.water_momentum_force_y = 0
                    self.water_momentum_force_x = 0
                    
                    print(f"🌊 포세이돈 굴절 최종 결과:")
                    print(f"   - 원래 속도: vx={ball_vx:.1f}, vy={ball_vy:.1f}")
                    print(f"   - 최종 속도: vx={new_vx:.1f}, vy={new_vy:.1f}")
                    print(f"   - 굴절 강도: {refraction_strength:.3f}")
                    print(f"   - 각도 변화: {math.degrees(refraction_amount):.1f}°")
                    if ball_vy > 0:
                        if 'speed_reduction' in locals():
                            print(f"   - 속도 감속: {(1.0 - speed_reduction):.2f}x (감속률: {speed_reduction:.1%})")
                    else:
                        if 'speed_boost' in locals():
                            print(f"   - 속도 증폭: {speed_boost:.2f}x")
                    print(f"   - 반환값: new_vx={new_vx:.1f}, new_vy={new_vy:.1f}")
                    print("=" * 50)
                    
                    return new_vx, new_vy
                else:
                    # 회오리 범위 밖
                    print(f"🌊 [VORTEX] 거리 범위 밖 - 효과 없음 (거리={distance:.0f} >= 반경={vortex_radius:.0f})")
                    return ball_vx, ball_vy
            else:
                # 회오리 충돌 범위 밖
                print(f"🌊 [VORTEX] 충돌 범위 밖 - 효과 없음")
                print(f"   - 왼쪽 회오리 밖: {not in_left}, 오른쪽 회오리 밖: {not in_right}")
                # 추진력이 활성화되어 있으면 위의 코드에서 이미 처리됨
                pass
        
        # 기존 물결 효과는 회오리가 없을 때만 작동
        # (회오리가 활성화되면 회오리가 모든 물 효과를 대체)
        if self.dash_wave_active and not self.vortex_active:
            print(f"💦 [DASH WAVE] 활성화 (회오리 없음)")
            # 플레이어가 발사한 공 (위로 향하는 공)은 영향받지 않음
            if ball_vy < 0:  # 공이 위로 향하고 있으면 (플레이어가 친 공)
                print(f"💦 [DASH WAVE] 플레이어 공 무시 (vy={ball_vy:.1f} < 0)")
                return ball_vx, ball_vy  # 물결 효과 무시
                
            distance = math.sqrt((ball_x - paddle_x) ** 2 + (ball_y - paddle_y) ** 2)
            wave_radius = 50 + self.dash_wave_timer * 10
            
            print(f"💦 [DASH WAVE] 거리={distance:.0f}, 반경={wave_radius:.0f}")
            
            if distance < wave_radius and distance > 0:
                push_x = (ball_x - paddle_x) / distance * self.dash_wave_force
                push_y = (ball_y - paddle_y) / distance * self.dash_wave_force * 0.5
                attenuation = 1 - (distance / wave_radius)
                
                new_vx = ball_vx + push_x * attenuation
                new_vy = ball_vy + push_y * attenuation
                print(f"💦 [DASH WAVE] 적용: ({ball_vx:.1f}, {ball_vy:.1f}) → ({new_vx:.1f}, {new_vy:.1f})")
                return new_vx, new_vy
            else:
                print(f"💦 [DASH WAVE] 범위 밖 - 효과 없음")
        
        print(f"🔍 [apply_dash_wave_to_ball] 종료 - 원래 속도 반환")
        return ball_vx, ball_vy
        
    def update(self, dt: float, ui_mode: bool = False):
        """업데이트
        Args:
            dt: 델타 타임
            ui_mode: UI 모드 여부 (True면 게임플레이 효과 비활성화)
        """
        # 디버그: 업데이트 호출 확인
        if not hasattr(self, '_update_debug_counter'):
            self._update_debug_counter = 0
        self._update_debug_counter += 1
        
        if self._update_debug_counter <= 3:
            print(f"🔱 PoseidonTrident.update 호출: dt={dt:.4f}, ui_mode={ui_mode}, active={self.active}")
        
        # 부모 클래스의 update 호출 (animation_offset 업데이트 포함)
        super().update(dt, ui_mode)
        
        # 라그나로크 해머와 동일한 애니메이션 프레임 카운터 업데이트
        if self.icon_frames and len(self.icon_frames) > 1:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.icon_frames)
        
        if not self.active:
            if self._update_debug_counter <= 3:
                print(f"🔱 PoseidonTrident.update: active=False, 리턴")
            return
            
        # UI 모드에서는 아이콘 애니메이션만 업데이트하고 게임플레이 효과는 스킵
        if ui_mode:
            if self._update_debug_counter <= 3:
                print(f"🔱 PoseidonTrident.update: ui_mode=True, 게임플레이 효과 스킵")
            return
            
        # 물결 타이머 (게임플레이에서만)
        self.wave_timer += dt * 60
        
        # 거대한 회오리 업데이트 (게임플레이에서만) - 양쪽 회오리
        if self.vortex_active:
            # 타이머와 높이 업데이트 디버그
            old_timer = self.vortex_timer
            old_left_height = self.vortex_left_height
            
            self.vortex_timer += dt
            
            # 디버그: 업데이트 확인
            if self._update_debug_counter <= 10:
                print(f"🌀 Vortex UPDATE: dt={dt:.4f}, timer={old_timer:.3f}→{self.vortex_timer:.3f}")
                print(f"   왼쪽 높이: {old_left_height:.1f} → ", end="")
            
            # 왼쪽 회오리 높이 급속 확장 (용솟음치는 효과)
            if self.vortex_left_height < self.vortex_max_height:
                self.vortex_left_height += 800 * dt  # 빠르게 상승
                if self._update_debug_counter <= 10:
                    print(f"{self.vortex_left_height:.1f} (증가: {800 * dt:.1f})")
            elif self._update_debug_counter <= 10:
                print(f"{self.vortex_left_height:.1f} (최대값 도달)")
            
            # 오른쪽 회오리 높이 급속 확장 (용솟음치는 효과)
            if self.vortex_right_height < self.vortex_max_height:
                self.vortex_right_height += 800 * dt  # 빠르게 상승
                
            # 매 0.5초마다 업데이트 상태 출력
            if int(self.vortex_timer * 2) != int((self.vortex_timer - dt) * 2):
                print(f"📈 Vortex Update: timer={self.vortex_timer:.2f}s, 왼쪽={self.vortex_left_height:.0f}, 오른쪽={self.vortex_right_height:.0f}")
            
            # 회전 속도 증가
            self.vortex_spin_speed += dt * 10
            
            # 회오리 파티클 업데이트 - 각 회오리별로 처리
            particle_count = 0
            for particle in self.vortex_particles[:]:
                particle_count += 1
                # 나선형 움직임 (dt를 프레임 단위로 변환: dt * 60 = 1프레임)
                old_angle = particle["spiral_angle"]
                particle["spiral_angle"] += dt * 60 * 0.3  # 프레임당 0.3 라디안 회전
                
                # 첫 번째 파티클의 움직임 디버그
                if particle_count == 1 and int(self.vortex_timer * 10) != int((self.vortex_timer - dt) * 10):
                    print(f"🔄 Particle 1: angle {old_angle:.2f} → {particle['spiral_angle']:.2f}, y={particle['y']:.0f}")
                
                # 파티클이 어느 회오리에 속하는지에 따라 중심 결정
                if "vortex_side" in particle:
                    if particle["vortex_side"] == "left":
                        center_x = self.vortex_left_x
                        center_y = self.vortex_left_y
                    else:  # right
                        center_x = self.vortex_right_x
                        center_y = self.vortex_right_y
                else:
                    # 기본값 (호환성)
                    center_x = self.vortex_left_x
                    center_y = self.vortex_left_y
                
                particle["x"] = center_x + math.cos(particle["spiral_angle"]) * particle["spiral_radius"]
                particle["y"] -= dt * 60 * 3.5  # 프레임당 3.5픽셀 위로 상승
                
                particle["spiral_radius"] += dt * 60 * 0.5  # 프레임당 0.5픽셀 반경 확대
                particle["life"] -= dt * 60  # 프레임당 1씩 감소
                
                if particle["life"] <= 0:
                    self.vortex_particles.remove(particle)
                    
            # 새로운 파티클 지속적으로 생성 - 양쪽 회오리에 각각
            if self.vortex_timer < 1.0 and len(self.vortex_particles) < 150:  # 양쪽이니까 150개까지
                # 왼쪽 회오리 파티클
                for _ in range(2):
                    particle = {
                        "x": self.vortex_left_x + random.uniform(-30, 30),
                        "y": self.vortex_left_y,
                        "vx": random.uniform(-5, 5),
                        "vy": random.uniform(-10, -5),
                        "life": random.randint(30, 60),
                        "color": (50, 150 + random.randint(0, 100), 255),
                        "size": random.uniform(5, 15),
                        "spiral_angle": random.uniform(0, math.pi * 2),
                        "spiral_radius": random.uniform(10, 30),
                        "vortex_side": "left"
                    }
                    self.vortex_particles.append(particle)
                
                # 오른쪽 회오리 파티클
                for _ in range(2):
                    particle = {
                        "x": self.vortex_right_x + random.uniform(-30, 30),
                        "y": self.vortex_right_y,
                        "vx": random.uniform(-5, 5),
                        "vy": random.uniform(-10, -5),
                        "life": random.randint(30, 60),
                        "color": (50, 150 + random.randint(0, 100), 255),
                        "size": random.uniform(5, 15),
                        "spiral_angle": random.uniform(0, math.pi * 2),
                        "spiral_radius": random.uniform(10, 30),
                        "vortex_side": "right"
                    }
                    self.vortex_particles.append(particle)
            
            # 회오리 종료 체크 (2초 후)
            if self.vortex_timer > 2.0:
                self.vortex_active = False
                self.vortex_left_height = 0
                self.vortex_right_height = 0
                self.vortex_particles.clear()
                # 물의 추진력은 유지! (회오리가 끝나도 공의 추진력은 계속됨)
                # 추진력은 자체 타이머로 관리되므로 여기서 리셋하지 않음
        
        # 대시 물결 타이머
        if self.dash_wave_active:
            self.dash_wave_timer += dt * 60
            if self.dash_wave_timer > 60:  # 1초 후 종료
                self.dash_wave_active = False
                self.dash_wave_timer = 0
                
    def draw_effects(self, screen: pygame.Surface):
        """거대한 물결 회오리 효과 그리기"""
        if not self.active:
            return
            
        # 거대한 회오리 그리기
        if self.vortex_active:
            # 디버그 출력 추가
            if len(self.vortex_particles) > 0:
                print(f"🌊 Drawing {len(self.vortex_particles)} particles, timer: {self.vortex_timer:.2f}")
            # 물기둥 효과 제거 - 파티클만 표시
            # 두 회오리 중 더 높은 것 사용 (시각적 효과용)
            current_height = int(min(max(self.vortex_left_height, self.vortex_right_height), self.vortex_max_height))
            # 시각 효과는 제거하고 물리 효과만 유지
            
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
            
    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """애니메이션 아이콘 그리기 - 라그나로크 해머와 완전 동일"""
        import pygame
        import math
        
        # 포세이돈도 라그나로크와 동일한 글로우 설정
        self.trident_glow_multiplier = 1.8  # 라그나로크와 동일한 글로우
        
        # 글로우 효과 (라그나로크 해머와 완전히 동일)
        glow_size = int(size * (self.trident_glow_multiplier + self.glow_intensity * 0.15))
        glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
        for i in range(5):  # 더 많은 레이어로 강렬한 효과
            alpha = 80 - i * 12  # 더 진한 글로우
            pygame.draw.circle(glow_surf, (*LEGENDARY_COLOR, alpha), 
                             (glow_size//2, glow_size//2), 
                             glow_size//2 - i * 4)  # 더 촘촘한 간격
        screen.blit(glow_surf, (x - (glow_size - size)//2, y - (glow_size - size)//2))
        
        # 이중 테두리 애니메이션 (프레임마다 색상 변화)
        # 외부 테두리 - 프레임에 따라 색상 변화
        if self.current_frame % 4 == 0:
            outer_border_color = (255, 215, 0)  # 황금색
        elif self.current_frame % 4 == 1:
            outer_border_color = (255, 0, 0)    # 빨간색
        elif self.current_frame % 4 == 2:
            outer_border_color = (0, 150, 255)  # 파란색
        else:
            outer_border_color = (255, 100, 0)  # 주황색
        
        # 외부 테두리 그리기
        outer_rect = pygame.Rect(x-4, y-4, size+8, size+8)
        pygame.draw.rect(screen, outer_border_color, outer_rect, 3)
        
        # 내부 테두리 - 프레임에 따라 색상 변화 (외부와 반대)
        if self.current_frame % 4 == 0:
            inner_border_color = (255, 0, 0)    # 빨간색
        elif self.current_frame % 4 == 1:
            inner_border_color = (0, 150, 255)  # 파란색
        elif self.current_frame % 4 == 2:
            inner_border_color = (255, 215, 0)  # 황금색
        else:
            inner_border_color = (150, 0, 255)  # 보라색
        
        # 내부 테두리 그리기
        border_thickness = 2 + int(self.glow_intensity * 2)
        border_rect = pygame.Rect(x-2, y-2, size+4, size+4)
        pygame.draw.rect(screen, inner_border_color, border_rect, border_thickness)
        
        # 꼭지점 디테일 (코너 장식) - 라그나로크와 동일
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
        
        # 코너 점 장식 (더 화려하게) - 라그나로크와 동일
        for cx, cy in [(x, y), (x+size, y), (x, y+size), (x+size, y+size)]:
            pygame.draw.circle(screen, LEGENDARY_COLOR, (cx, cy), 3)  # 빨간색
            pygame.draw.circle(screen, corner_color, (cx, cy), 2)
        
        # 애니메이션 프레임 그리기 (라그나로크 해머와 동일한 프레임 사용)
        if self.icon_frames and len(self.icon_frames) > 0:
            # 현재 프레임 그리기 (위아래 움직임 효과 포함)
            icon_y = y + int(self.animation_offset)
            current_icon = self.icon_frames[self.current_frame % len(self.icon_frames)]
            scaled_icon = pygame.transform.scale(current_icon, (size, size))
            screen.blit(scaled_icon, (x, icon_y))
            
            # 번개 효과 추가 (프레임 0, 4에서) - 라그나로크와 동일
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
    
    def update(self, dt: float, ui_mode: bool = False):
        """애니메이션 업데이트 - 프레임 카운터 업데이트 포함
        
        Args:
            dt: 델타 타임
            ui_mode: UI 모드 여부 (True면 게임플레이 효과 비활성화)
        """
        super().update(dt, ui_mode)  # 부모 클래스의 update 호출 (animation_offset 등 업데이트)
        
        # 애니메이션 프레임 카운터 업데이트
        if self.icon_frames and len(self.icon_frames) > 1:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.icon_frames)
        
        # 회오리 애니메이션 업데이트 (ui_mode가 아닐 때만)
        if not ui_mode and self.vortex_active:
            # 타이머 업데이트 
            self.vortex_timer += dt * 60  # 60fps 기준으로 변환
            
            # 회오리 성장 단계 (0.5초 동안 성장)
            if self.vortex_timer < 30:  # 0.5초 * 60fps = 30 프레임
                growth_rate = self.vortex_timer / 30
                self.vortex_left_height = self.vortex_max_height * growth_rate
                self.vortex_right_height = self.vortex_max_height * growth_rate
                self.vortex_spin_speed = 10 * growth_rate
            # 회오리 유지 단계 (2초 동안 유지)
            elif self.vortex_timer < 150:  # 2.5초 * 60fps = 150 프레임
                self.vortex_left_height = self.vortex_max_height
                self.vortex_right_height = self.vortex_max_height
                self.vortex_spin_speed = 10
            # 회오리 소멸 단계 (0.5초 동안 소멸)
            elif self.vortex_timer < 180:  # 3초 * 60fps = 180 프레임
                fade_rate = 1 - (self.vortex_timer - 150) / 30
                self.vortex_left_height = self.vortex_max_height * fade_rate
                self.vortex_right_height = self.vortex_max_height * fade_rate
                self.vortex_spin_speed = 10 * fade_rate
            else:
                # 회오리 종료
                self.vortex_active = False
                self.vortex_left_height = 0
                self.vortex_right_height = 0
                self.vortex_particles.clear()
            
            # 파티클 업데이트
            for particle in self.vortex_particles[:]:
                particle["life"] -= 1
                if particle["life"] <= 0:
                    self.vortex_particles.remove(particle)
                    continue
                
                # 회오리 회전 움직임
                if "vortex_side" in particle:
                    if particle["vortex_side"] == "left":
                        center_x = self.vortex_left_x
                        center_y = self.vortex_left_y
                    else:
                        center_x = self.vortex_right_x
                        center_y = self.vortex_right_y
                    
                    # 나선형 움직임
                    particle["spiral_angle"] += self.vortex_spin_speed * 0.1
                    particle["spiral_radius"] *= 0.98  # 서서히 중심으로
                    particle["x"] = center_x + math.cos(particle["spiral_angle"]) * particle["spiral_radius"]
                    particle["y"] -= 3  # 위로 상승
                    
                    # 크기 감소
                    particle["size"] *= 0.98
                
            # 새 파티클 추가 (회오리가 활성화된 동안)
            if self.vortex_timer < 150 and len(self.vortex_particles) < 100:
                # 왼쪽 회오리 파티클
                for _ in range(2):
                    angle = random.uniform(0, math.pi * 2)
                    particle = {
                        "x": self.vortex_left_x + math.cos(angle) * random.uniform(10, 50),
                        "y": self.vortex_left_y + random.uniform(-20, 20),
                        "vx": math.cos(angle) * random.uniform(1, 3),
                        "vy": random.uniform(-5, -2),
                        "life": random.randint(30, 60),
                        "color": (50, 150 + random.randint(0, 100), 255),
                        "size": random.uniform(3, 8),
                        "spiral_angle": angle,
                        "spiral_radius": random.uniform(20, 60),
                        "vortex_side": "left"
                    }
                    self.vortex_particles.append(particle)
                
                # 오른쪽 회오리 파티클
                for _ in range(2):
                    angle = random.uniform(0, math.pi * 2)
                    particle = {
                        "x": self.vortex_right_x + math.cos(angle) * random.uniform(10, 50),
                        "y": self.vortex_right_y + random.uniform(-20, 20),
                        "vx": math.cos(angle) * random.uniform(1, 3),
                        "vy": random.uniform(-5, -2),
                        "life": random.randint(30, 60),
                        "color": (50, 150 + random.randint(0, 100), 255),
                        "size": random.uniform(3, 8),
                        "spiral_angle": angle,
                        "spiral_radius": random.uniform(20, 60),
                        "vortex_side": "right"
                    }
                    self.vortex_particles.append(particle)
        
        # 물결 타이머 업데이트
        if self.active and not ui_mode:
            self.wave_timer += dt * 60


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
        print(f"🎮 activate_item 호출: name={name}")
        print(f"   - items에 있음: {name in self.items}")
        print(f"   - unlocked_items에 있음: {name in self.unlocked_items}")
        print(f"   - unlocked_items: {self.unlocked_items}")
        
        if name in self.items:
            # 아이템이 해금되지 않았으면 자동으로 해금
            if name not in self.unlocked_items:
                print(f"   ⚠️ {name}이 unlocked_items에 없음! 자동 추가")
                self.unlocked_items.append(name)
                self.items[name].unlocked = True
            
            item = self.items[name]
            item.activate(game_state)
            if name not in self.active_items:
                self.active_items.append(name)
                print(f"   ✅ {name}을 active_items에 추가: {self.active_items}")
            else:
                print(f"   ℹ️ {name}은 이미 active_items에 있음")
                
    def deactivate_item(self, name: str):
        """아이템 비활성화"""
        if name in self.items:
            self.items[name].deactivate()
            if name in self.active_items:
                self.active_items.remove(name)
                
    def update(self, dt: float, ui_mode: bool = False):
        """모든 활성 아이템 업데이트
        Args:
            dt: 델타 타임
            ui_mode: UI 모드 여부 (True면 게임플레이 효과 비활성화)
        """
        # 디버그: 첫 프레임에만 출력
        if hasattr(self, '_debug_counter'):
            self._debug_counter += 1
        else:
            self._debug_counter = 0
            
        if self._debug_counter == 1:
            print(f"🔍 LegendaryManager.update: active_items={self.active_items}, ui_mode={ui_mode}")
            
        for name in self.active_items:
            if name in self.items:
                # PoseidonTrident는 ui_mode 파라미터를 받음
                if name == "poseidon_trident":
                    self.items[name].update(dt, ui_mode)
                else:
                    # 다른 아이템들도 ui_mode를 받을 수 있도록 처리
                    try:
                        self.items[name].update(dt, ui_mode)
                    except TypeError:
                        # ui_mode 파라미터를 받지 않는 아이템은 dt만 전달
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