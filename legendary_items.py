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
        
    def update(self, dt: float):
        """애니메이션 업데이트"""
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
                # 아이콘 로드 실패시 기본 아이콘
                self._draw_default_icon(screen, x, icon_y, size)
        else:
            self._draw_default_icon(screen, x, icon_y, size)
            
        # 파티클 효과 (가끔씩)
        if self.particle_timer > 1000:  # 1초마다
            self._spawn_particle(screen, x + size//2, y + size//2)
            self.particle_timer = 0
            
    def _draw_default_icon(self, screen: pygame.Surface, x: int, y: int, size: int):
        """기본 전설 아이콘"""
        pygame.draw.rect(screen, (100, 0, 0), (x, y, size, size))
        # 별 모양
        star_points = []
        cx, cy = x + size//2, y + size//2
        for i in range(10):
            angle = math.pi * i / 5
            if i % 2 == 0:
                r = size // 3
            else:
                r = size // 6
            px = cx + int(r * math.cos(angle - math.pi/2))
            py = cy + int(r * math.sin(angle - math.pi/2))
            star_points.append((px, py))
        pygame.draw.polygon(screen, LEGENDARY_COLOR, star_points)
        pygame.draw.polygon(screen, (255, 255, 255), star_points, 2)
        
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
        
        # 라그나로크 해머의 PNG 파일을 그대로 사용 (진짜 애니메이션)
        frames_loaded = 0
        for i in range(8):
            # 라그나로크 해머 프레임을 로드
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                frame = pygame.image.load(frame_path).convert_alpha()
                self.animation_frames.append(frame)
                frames_loaded += 1
                print(f"✓ 헤르메스 신발 프레임 {i} 로드 성공 (라그나로크 해머 PNG 사용)")
            except Exception as e:
                print(f"✗ 프레임 {i} 로드 실패: {frame_path} - {e}")
        
        print(f"헤르메스 신발: 라그나로크 해머 스타일 프레임 {frames_loaded}/8개 로드")
        
        # 프레임이 없으면 에러만 표시 (가짜 애니메이션 생성하지 않음)
        if not self.animation_frames or len(self.animation_frames) == 0:
            print("❌ 헤르메스 신발: 라그나로크 해머 PNG를 찾을 수 없습니다!")
            # _create_default_animation을 호출하지 않음 (가짜 애니메이션 제거)
    
    def _create_default_animation(self):
        """라그나로크 해머 코드를 완전히 복사해서 신발로 변경"""
        import pygame
        import math
        
        # generate_ragnarok_hammer_icon.py에서 그대로 복사
        ICON_SIZE = 32
        FRAMES = 8
        LEGENDARY_RED = (255, 50, 50)
        SHOE_HEAD_COLOR = (120, 120, 140)  # 회색빛 금속 (해머 헤드와 동일)
        SHOE_HEAD_DARK = (80, 80, 100)
        SHOE_HEAD_LIGHT = (160, 160, 180)
        SHOE_SOLE = (101, 67, 33)  # 나무 손잡이 색상을 밑창에 사용
        SHOE_SOLE_DARK = (71, 47, 23)
        LIGHTNING_YELLOW = (255, 255, 150)
        LIGHTNING_WHITE = (255, 255, 255)
        IMPACT_GLOW = (255, 200, 100)
        
        for frame_index in range(FRAMES):
            # 라그나로크 해머와 완전히 동일한 프레임 생성
            surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
            
            # 큰 파란색 원형 배경 (라그나로크 해머 PNG처럼)
            # 중앙에 큰 파란색 원 그리기
            center_x, center_y = ICON_SIZE // 2, ICON_SIZE // 2
            # 여러 겹의 원으로 그라데이션 효과
            for i in range(3):
                radius = ICON_SIZE // 2 - i
                alpha = 200 - i * 50  # 바깥쪽이 더 진함
                color = (50 + i * 20, 70 + i * 20, 100 + i * 30, alpha)  # 점점 밝은 파란색
                pygame.draw.circle(surface, color, (center_x, center_y), radius)
            
            # 애니메이션 타이밍
            t = frame_index / FRAMES
            
            # 빨간 테두리 (전설 티어) - 라그나로크 해머와 완전히 동일
            border_thickness = 2
            border_glow = int(128 + 127 * math.sin(t * math.pi * 2))  # 펄싱 효과
            
            # 글로우 효과를 위한 여러 겹의 테두리
            for i in range(2):
                alpha = border_glow // (i + 1)
                thickness = border_thickness - i
                if thickness > 0:
                    pygame.draw.rect(surface, (*LEGENDARY_RED, alpha), 
                                   (i, i, ICON_SIZE - i*2, ICON_SIZE - i*2), thickness)
            
            # 메인 빨간 테두리
            pygame.draw.rect(surface, LEGENDARY_RED, 
                           (0, 0, ICON_SIZE, ICON_SIZE), border_thickness)
            
            # 신발 회전 애니메이션
            rotation_angle = math.sin(t * math.pi * 2) * 10  # -10도에서 +10도
            shoe_y_offset = int(math.sin(t * math.pi * 2) * 2)  # 위아래 움직임
            
            # 번개 효과 (일부 프레임에만) - 날개처럼
            if frame_index in [2, 3, 6, 7]:
                # 작은 번개 볼트 (날개 모양)
                for i in range(2):
                    start_x = 8 + i * 16
                    start_y = 5
                    segments = 3
                    prev_x, prev_y = start_x, start_y
                    
                    for seg in range(segments):
                        next_x = prev_x + (4 if i == 0 else -4)
                        next_y = prev_y + 5
                        
                        # 지그재그 효과
                        if seg % 2 == 0:
                            next_x += 2
                        else:
                            next_x -= 2
                            
                        pygame.draw.line(surface, LIGHTNING_YELLOW, 
                                       (prev_x, prev_y), (next_x, next_y), 1)
                        prev_x, prev_y = next_x, next_y
            
            # 신발 밑창 (해머 손잡이 위치)
            sole_x = 14
            sole_y = 10 + shoe_y_offset
            sole_width = 4
            sole_height = 16
            
            # 밑창 그림자
            pygame.draw.rect(surface, SHOE_SOLE_DARK, 
                           (sole_x + 1, sole_y + 1, sole_width, sole_height))
            
            # 메인 밑창
            pygame.draw.rect(surface, SHOE_SOLE, 
                           (sole_x, sole_y, sole_width, sole_height))
            
            # 밑창 하이라이트
            pygame.draw.rect(surface, SHOE_SOLE, 
                           (sole_x, sole_y, 1, sole_height))
            
            # 밑창 패턴
            for i in range(3):
                y = sole_y + 4 + i * 5
                pygame.draw.line(surface, SHOE_SOLE_DARK, 
                               (sole_x, y), (sole_x + sole_width - 1, y), 1)
            
            # 신발 본체 (해머 헤드 위치)
            shoe_x = 8
            shoe_y = 7 + shoe_y_offset
            shoe_width = 16
            shoe_height = 8
            
            # 신발 그림자
            pygame.draw.rect(surface, SHOE_HEAD_DARK, 
                           (shoe_x + 1, shoe_y + 1, shoe_width, shoe_height))
            
            # 메인 신발
            pygame.draw.rect(surface, SHOE_HEAD_COLOR, 
                           (shoe_x, shoe_y, shoe_width, shoe_height))
            
            # 신발 하이라이트 (금속 광택)
            pygame.draw.rect(surface, SHOE_HEAD_LIGHT, 
                           (shoe_x + 2, shoe_y + 1, shoe_width - 4, 2))
            
            # 신발 끝 디테일 (양쪽 끝)
            # 왼쪽 끝
            pygame.draw.rect(surface, SHOE_HEAD_COLOR, 
                           (shoe_x - 2, shoe_y + 1, 3, shoe_height - 2))
            pygame.draw.rect(surface, SHOE_HEAD_DARK, 
                           (shoe_x - 2, shoe_y + shoe_height - 2, 3, 1))
            
            # 오른쪽 끝
            pygame.draw.rect(surface, SHOE_HEAD_COLOR, 
                           (shoe_x + shoe_width - 1, shoe_y + 1, 3, shoe_height - 2))
            pygame.draw.rect(surface, SHOE_HEAD_DARK, 
                           (shoe_x + shoe_width - 1, shoe_y + shoe_height - 2, 3, 1))
            
            # 충격파 효과 (일부 프레임)
            if frame_index in [0, 4]:
                # 충격파 원
                impact_radius = 6 + (frame_index // 4) * 2
                impact_alpha = 100 - (frame_index // 4) * 30
                
                for i in range(2):
                    radius = impact_radius - i * 2
                    if radius > 0:
                        color = (*IMPACT_GLOW, impact_alpha // (i + 1))
                        # 충격파를 픽셀 단위로 그리기
                        center_x, center_y = 16, 11 + shoe_y_offset
                        for angle in range(0, 360, 30):
                            x = center_x + int(radius * math.cos(math.radians(angle)))
                            y = center_y + int(radius * math.sin(math.radians(angle)))
                            if 0 <= x < ICON_SIZE and 0 <= y < ICON_SIZE:
                                surface.set_at((x, y), color)
            
            # 파워 글로우 (신발 주변)
            if frame_index % 2 == 0:
                # 신발 주변에 붉은 광채
                glow_alpha = 40 + int(20 * math.sin(t * math.pi * 2))
                for dx in range(-1, 2):
                    for dy in range(-1, 2):
                        if dx != 0 or dy != 0:
                            glow_x = shoe_x + shoe_width // 2 + dx * 3
                            glow_y = shoe_y + shoe_height // 2 + dy * 3
                            if 0 <= glow_x < ICON_SIZE and 0 <= glow_y < ICON_SIZE:
                                surface.set_at((glow_x, glow_y), (*LEGENDARY_RED, glow_alpha))
            
            # 룬 문자 (신화적 요소)
            if frame_index in [1, 5]:
                # 작은 룬 문자를 신발에
                rune_color = (255, 100, 100, 150)
                # 간단한 V 모양 룬 (날개 모양)
                pygame.draw.lines(surface, rune_color, False, 
                                [(shoe_x + 7, shoe_y + 3), 
                                 (shoe_x + 9, shoe_y + 5), 
                                 (shoe_x + 11, shoe_y + 3)], 1)
            
            # 프레임을 리스트에 추가
            self.animation_frames.append(surface)
    
    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """애니메이션 아이콘 그리기"""
        import pygame
        import math
        
        # 글로우 효과
        glow_size = int(size * (1.2 + self.glow_intensity * 0.1))
        glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
        for i in range(3):
            alpha = 50 - i * 15
            pygame.draw.circle(glow_surf, (*LEGENDARY_COLOR, alpha), 
                             (glow_size//2, glow_size//2), 
                             glow_size//2 - i * 5)
        screen.blit(glow_surf, (x - (glow_size - size)//2, y - (glow_size - size)//2))
        
        # 붉은색 테두리 (펄싱 효과)
        border_thickness = 2 + int(self.glow_intensity * 2)
        border_rect = pygame.Rect(x-2, y-2, size+4, size+4)
        pygame.draw.rect(screen, LEGENDARY_COLOR, border_rect, border_thickness)
        
        # 꼭지점 디테일 (코너 장식)
        corner_size = 6
        corner_color = (200, 200, 200)  # 은색 (해머 테마)
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
            # 애니메이션 프레임이 없으면 헤르메스 신발 기본 아이콘
            self._draw_hermes_default_icon(screen, x, y + int(self.animation_offset), size)
        
        # 파티클 효과
        if self.particle_timer > 1000:
            self._spawn_particle(screen, x + size//2, y + size//2)
            self.particle_timer = 0
    
    def _draw_hermes_default_icon(self, screen: pygame.Surface, x: int, y: int, size: int):
        """헤르메스 신발 기본 아이콘 그리기"""
        import pygame
        
        # 신발 그리기 (황금색)
        shoe_color = (255, 215, 0)  # 황금색
        shoe_outline = (200, 170, 0)  # 어두운 황금색
        wing_color = (255, 255, 255)  # 흰색 날개
        
        # 신발 본체 (타원형)
        shoe_rect = pygame.Rect(x + size//6, y + size//3, size*2//3, size//3)
        pygame.draw.ellipse(screen, shoe_color, shoe_rect)
        pygame.draw.ellipse(screen, shoe_outline, shoe_rect, 2)
        
        # 신발 앞코
        pygame.draw.ellipse(screen, shoe_color, 
                          (x + size*2//3 - 5, y + size//3 + 2, size//4, size//4))
        
        # 신발 뒤꿈치
        pygame.draw.rect(screen, shoe_color,
                        (x + size//6, y + size//3, size//6, size//3))
        
        # 왼쪽 날개
        wing_left = [
            (x + size//8, y + size//2 - 5),
            (x, y + size//2),
            (x + size//8, y + size//2 + 5),
            (x + size//4, y + size//2)
        ]
        pygame.draw.polygon(screen, wing_color, wing_left)
        pygame.draw.polygon(screen, (200, 200, 200), wing_left, 1)
        
        # 날개 디테일 (깃털)
        for i in range(2):
            feather_y = y + size//2 - 3 + i * 6
            pygame.draw.line(screen, (220, 220, 220), 
                           (x + size//12, feather_y), 
                           (x + size//6, feather_y), 1)
        
        # 오른쪽 날개
        wing_right = [
            (x + size*7//8, y + size//2 - 5),
            (x + size, y + size//2),
            (x + size*7//8, y + size//2 + 5),
            (x + size*3//4, y + size//2)
        ]
        pygame.draw.polygon(screen, wing_color, wing_right)
        pygame.draw.polygon(screen, (200, 200, 200), wing_right, 1)
        
        # 날개 디테일 (깃털)
        for i in range(2):
            feather_y = y + size//2 - 3 + i * 6
            pygame.draw.line(screen, (220, 220, 220),
                           (x + size*5//6, feather_y),
                           (x + size*11//12, feather_y), 1)
        
        # 반짝임 효과
        sparkle_points = [
            (x + size//2, y + size//4),
            (x + size*3//4, y + size*2//5)
        ]
        for px, py in sparkle_points:
            # 작은 별 모양
            pygame.draw.line(screen, (255, 255, 200), (px-3, py), (px+3, py), 1)
            pygame.draw.line(screen, (255, 255, 200), (px, py-3), (px, py+3), 1)


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
        
        # 프레임이 없으면 기본 아이콘 사용
        if not self.animation_frames:
            icon_path = resource_path(self.icon_path)
            try:
                default_frame = pygame.image.load(icon_path).convert_alpha()
                # 8프레임 시뮬레이션 (회전 효과)
                import math
                for i in range(8):
                    angle = i * 45  # 45도씩 회전
                    rotated = pygame.transform.rotate(default_frame, angle)
                    self.animation_frames.append(rotated)
                print(f"기본 아이콘으로 회전 애니메이션 생성: {icon_path}")
            except Exception as e:
                print(f"기본 아이콘도 로드 실패: {e}")
    
    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """애니메이션 아이콘 그리기"""
        import pygame
        import math
        
        # 글로우 효과
        glow_size = int(size * (1.2 + self.glow_intensity * 0.1))
        glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
        for i in range(3):
            alpha = 50 - i * 15
            pygame.draw.circle(glow_surf, (*LEGENDARY_COLOR, alpha), 
                             (glow_size//2, glow_size//2), 
                             glow_size//2 - i * 5)
        screen.blit(glow_surf, (x - (glow_size - size)//2, y - (glow_size - size)//2))
        
        # 붉은색 테두리 (펄싱 효과)
        border_thickness = 2 + int(self.glow_intensity * 2)
        border_rect = pygame.Rect(x-2, y-2, size+4, size+4)
        pygame.draw.rect(screen, LEGENDARY_COLOR, border_rect, border_thickness)
        
        # 꼭지점 디테일 (코너 장식)
        corner_size = 6
        corner_color = (200, 200, 200)  # 은색 (해머 테마)
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
        else:
            # 애니메이션 프레임이 없으면 기본 아이콘 + 회전 효과
            self._draw_default_icon(screen, x, y + int(self.animation_offset), size)
            # 회전하는 번개 효과
            angle = (pygame.time.get_ticks() // 50) % 360
            for i in range(4):
                bolt_angle = math.radians(angle + i * 90)
                start_x = x + size//2 + int(math.cos(bolt_angle) * size//3)
                start_y = y + size//2 + int(math.sin(bolt_angle) * size//3)
                end_x = x + size//2 + int(math.cos(bolt_angle) * size//2)
                end_y = y + size//2 + int(math.sin(bolt_angle) * size//2)
                pygame.draw.line(screen, (255, 255, 150, 100), 
                               (start_x, start_y), (end_x, end_y), 1)
        
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
        
        # 테스트용: 라그나로크 해머와 헤르메스 신발 강제 해금
        self.items["ragnarok_hammer"].unlocked = True
        if "ragnarok_hammer" not in self.unlocked_items:
            self.unlocked_items.append("ragnarok_hammer")
        
        self.items["hermes_shoes"].unlocked = True
        if "hermes_shoes" not in self.unlocked_items:
            self.unlocked_items.append("hermes_shoes")
    
    def _init_legendary_items(self):
        """전설 아이템 초기화 (애니메이션용)"""
        # 라그나로크 해머 초기화
        if "ragnarok_hammer" not in self.items:
            self.items["ragnarok_hammer"] = RagnarokHammer()
        # 헤르메스 신발 초기화
        if "hermes_shoes" not in self.items:
            self.items["hermes_shoes"] = HermesShoes()
        
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