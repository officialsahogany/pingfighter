"""
전설 아이템 획득 애니메이션 시스템 - 고대 이집트 테마
- 화면 정지 효과
- 보물상자 흔들림과 빛 새어나옴
- 황금 폭발 효과
- 아이템 표시
"""

import pygame
import pygame.gfxdraw
import math
import random
import os
import sys
from typing import Optional, Tuple, List, Any
from enum import Enum

def resource_path(relative_path):
    """리소스 경로 헬퍼"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base_path, relative_path)

class LegendaryAcquisitionEffect:
    """전설 아이템 획득 시 특별 애니메이션 - 고대 이집트 테마"""
    
    def _hsv_to_rgb(self, h: float, s: float, v: float) -> tuple:
        """HSV 색상을 RGB로 변환"""
        import colorsys
        rgb = colorsys.hsv_to_rgb(h / 360.0, s, v)
        return (int(rgb[0] * 255), int(rgb[1] * 255), int(rgb[2] * 255))
    
    def __init__(self, width: int = 600, height: int = 750):
        self.width = width
        self.height = height
        self.active = False
        self.animation_time = 0
        self.total_duration = 3300  # 3.3초 (2초 빌드업 + 0.3초 폭발 + 1초 아이템)
        self.item_name = ""
        self.korean_name = ""
        self.item_icon = None
        
        # 애니메이션 페이즈
        self.phase = 0  # 0: 빌드업+점진적 빛(2초), 1: 폭발(0.3초), 2: 아이템 표시(1초)
        self.phase_timer = 0
        self.animation_complete = False
        
        # 전설 아이템 애니메이션 관련
        self.legendary_manager = None
        self.legendary_item = None
        self.icon_animation_frame = 0
        self.icon_animation_timer = 0
        
        # 사운드 관련
        self.legendafter_sound = None
        self.legendspacebar_sound = None
        self.legendending_sound = None  # legendending.wav 추가
        self.legendafter_played = False
        self.explosion_time = 0  # 폭발 시작 시간 기록
        
        # 사운드 초기 로드 시도
        self._load_sounds()
        
        # 빛줄기 생성 타이밍
        self.beam_spawn_times = [800, 1400, 1700, 1900]  # 0.8초, 1.4초, 1.7초, 1.9초
        self.next_beam_index = 0
        
        # 보물상자 관련
        self.treasure_chest = None
        self.chest_shake_amplitude = 0
        self.chest_rotation = 0
        self.chest_scale = 1.0
        
        # 빛 효과
        self.light_beams = []
        self.light_particles = []
        
        # 폭발 효과
        self.explosion_particles = []
        self.screen_flash = 0
        
        # 추가 이펙트
        self.magic_particles = []  # 마법 파티클
        self.chest_glow = 0  # 상자 주변 글로우
        self.ambient_particles = []  # 주변 떠다니는 파티클
        self.energy_rings = []  # 에너지 링
        self.lightning_bolts = []  # 전기 효과
        self.shockwave_radius = 0  # 충격파
        self.chromatic_aberration = 0  # 색수차 효과
        
        # 아이템 플로팅 애니메이션
        self.item_float_offset = 0
        self.item_float_time = 0
        self.illuminati_rotation = 0  # 일루미나티 심볼 회전 각도
        
        # 블랙홀 흡수 애니메이션
        self.black_hole_phase = 0  # 0: 없음, 1: 가속 회전, 2: 흡수, 3: 패들 빛나기
        self.black_hole_timer = 0
        self.rotation_speed = 0.00008  # 기본 회전 속도
        self.symbol_positions = []  # 심볼들의 현재 위치 저장
        self.paddle_x = width // 2  # 플레이어 패들 X 위치 (기본값)
        self.paddle_y = 650  # 플레이어 패들 Y 위치 (기본값)
        self.item_alpha = 255  # 아이템 알파값
        
        # 패들 빛나기 효과
        self.paddle_glow_timer = 0
        self.paddle_glow_intensity = 0
        
        # 사운드 페이드아웃 관련
        self.legendafter_fade_timer = 0  # legendafter 페이드아웃 타이머
        self.legendafter_fade_duration = 1500  # 1.5초 후 종료
        
        # 프리미엄 네온 색상 팔레트
        self.NEON_GOLD = (255, 215, 0)
        self.NEON_PURPLE = (147, 0, 211)
        self.NEON_CYAN = (0, 255, 255)
        self.NEON_PINK = (255, 20, 147)
        self.PURE_WHITE = (255, 255, 255)
        self.ELECTRIC_BLUE = (0, 191, 255)
        
    def _load_sounds(self):
        """사운드 파일 로드"""
        try:
            import os
            # legendafter.wav 로드
            sound_path = resource_path(os.path.join("sounds", "legendafter.wav"))
            if os.path.exists(sound_path):
                self.legendafter_sound = pygame.mixer.Sound(sound_path)
                print(f"🔊 [Init] legendafter.wav 로드 완료")
            
            # legendspacebar.wav 로드 (현재 사용하지 않음)
            spacebar_path = resource_path(os.path.join("sounds", "legendspacebar.wav"))
            if os.path.exists(spacebar_path):
                self.legendspacebar_sound = pygame.mixer.Sound(spacebar_path)
                print(f"🔊 [Init] legendspacebar.wav 로드 완료")
            
            # legendending.wav 로드 (스페이스바 누를 때 재생)
            ending_path = resource_path(os.path.join("sounds", "legendending.wav"))
            if os.path.exists(ending_path):
                self.legendending_sound = pygame.mixer.Sound(ending_path)
                print(f"🔊 [Init] legendending.wav 로드 완료")
            else:
                print(f"⚠️ legendending.wav 파일을 찾을 수 없습니다: {ending_path}")
        except Exception as e:
            print(f"[Init] 사운드 로드 실패: {e}")
    
    def trigger(self, item_name: str, korean_name: str, item_icon: Any = None, paddle_pos: tuple = None):
        """전설 아이템 획득 애니메이션 시작"""
        self.active = True
        self.animation_time = 0
        self.item_name = item_name
        self.korean_name = korean_name
        self.item_icon = item_icon
        self.phase = 0
        self.phase_timer = 0
        self.animation_complete = False
        
        # 전설 아이템 애니메이션 설정
        if item_name in ["hermes_shoes", "ragnarok_hammer"]:
            from legendary_items import get_legendary_manager
            self.legendary_manager = get_legendary_manager()
            if self.legendary_manager:
                self.legendary_item = self.legendary_manager.get_item(item_name)
                if self.legendary_item and not self.legendary_item.animation_frames:
                    self.legendary_item._create_default_animation()
        else:
            self.legendary_manager = None
            self.legendary_item = None
        
        self.icon_animation_frame = 0
        self.icon_animation_timer = 0
        
        # 패들 위치 저장 (제공되면 사용, 아니면 기본값)
        if paddle_pos:
            self.paddle_x = paddle_pos[0]
            self.paddle_y = paddle_pos[1]
        else:
            self.paddle_x = self.width // 2
            self.paddle_y = 650
        
        # 사운드가 아직 로드되지 않았다면 다시 시도
        if self.legendafter_sound is None or self.legendending_sound is None:
            self._load_sounds()
        
        # 초기화
        self.light_beams = []
        self.light_particles = []
        self.explosion_particles = []
        self.magic_particles = []
        self.ambient_particles = []
        self.energy_rings = []
        self.lightning_bolts = []
        self.chest_shake_amplitude = 0
        self.chest_rotation = 0
        self.chest_scale = 1.0
        self.screen_flash = 0
        self.chest_glow = 0
        self.shockwave_radius = 0
        self.chromatic_aberration = 0
        self.next_beam_index = 0
        self.item_float_offset = 0
        self.item_float_time = 0
        self.black_hole_phase = 0
        self.black_hole_timer = 0
        self.rotation_speed = 0.00008
        self.symbol_positions = []
        self.item_alpha = 255
        
        # 금 간 효과 변수
        self.cracks = []
        self.crack_glow_intensity = 0
        self.crack_formation_progress = 0
        
        # 화이트 페이드 효과
        self.white_fade_alpha = 0
        
        # 사운드 상태 초기화
        self.legendafter_played = False
        self.explosion_time = 0
        self.legendafter_fade_timer = 0
        
        # 프리미엄 보물상자 생성
        self._create_premium_chest()
        
        # 초기 이펙트 생성
        self._create_ambient_particles()
        self._create_energy_field()
        
    def _create_premium_chest(self):
        """울트라 프리미엄 홀로그래픽 보물상자 - 최신 모바일 게임 스타일"""
        size = 150  # 더 큰 사이즈
        self.treasure_chest = pygame.Surface((size, size), pygame.SRCALPHA)
        
        # 홀로그래픽 네온 색상
        holo_base = (20, 20, 30)  # 어두운 메탈릭 베이스
        holo_edge = (100, 200, 255)  # 홀로그래픽 엣지
        neon_core = (255, 255, 255)  # 순백색 코어
        plasma_glow = (138, 43, 226)  # 플라즈마 보라색
        energy_cyan = (0, 255, 255)  # 에너지 시안
        gold_chrome = (255, 215, 0)  # 크롬 골드
        
        # 1. 홀로그래픽 베이스 - 다이아몬드 형태
        center = size // 2
        
        # 외곽 다이아몬드 (홀로그래픽 효과)
        diamond_points = [
            (center, size * 0.15),  # 상단
            (size * 0.85, center),  # 우측
            (center, size * 0.85),   # 하단
            (size * 0.15, center)    # 좌측
        ]
        
        # 여러 레이어로 홀로그래픽 효과
        for i in range(5):
            offset = i * 2
            scaled_points = [
                (center, size * 0.15 + offset),
                (size * 0.85 - offset, center),
                (center, size * 0.85 - offset),
                (size * 0.15 + offset, center)
            ]
            alpha = 100 - i * 15
            color = (*holo_edge, alpha) if i % 2 == 0 else (*energy_cyan, alpha)
            temp_surf = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.polygon(temp_surf, color[:3], scaled_points, 2)
            self.treasure_chest.blit(temp_surf, (0, 0))
        
        # 2. 크리스탈 코어
        # 중앙 육각형 크리스탈
        hex_points = []
        for i in range(6):
            angle = i * math.pi / 3
            x = center + 35 * math.cos(angle)
            y = center + 35 * math.sin(angle)
            hex_points.append((x, y))
        
        # 크리스탈 그라데이션
        pygame.draw.polygon(self.treasure_chest, holo_base, hex_points)
        pygame.draw.polygon(self.treasure_chest, gold_chrome, hex_points, 3)
        
        # 3. 에너지 코어 - 중앙의 파워 소스
        # 플라즈마 구체
        for i in range(10, 2, -1):
            alpha = 255 - (10 - i) * 20
            radius = i * 3
            color = plasma_glow if i % 2 == 0 else energy_cyan
            glow_surf = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*color, alpha // 2), (center, center), radius)
            self.treasure_chest.blit(glow_surf, (0, 0))
        
        # 중앙 밝은 코어
        pygame.draw.circle(self.treasure_chest, neon_core, (center, center), 8)
        
        # 4. 홀로그래픽 링 장식
        for ring_radius in [50, 55, 60]:
            ring_surf = pygame.Surface((size, size), pygame.SRCALPHA)
            pygame.draw.circle(ring_surf, energy_cyan, (center, center), ring_radius, 2)
            pygame.draw.circle(ring_surf, (*gold_chrome, 100), (center, center), ring_radius + 1, 1)
            self.treasure_chest.blit(ring_surf, (0, 0))
        
        # 5. 에너지 라인 (테크 패턴)
        # 대각선 에너지 라인
        for i in range(4):
            angle = i * math.pi / 2 + math.pi / 4
            end_x = center + 60 * math.cos(angle)
            end_y = center + 60 * math.sin(angle)
            
            # 에너지 빔
            for j in range(3):
                line_alpha = 150 - j * 40
                line_width = 3 - j
                pygame.draw.line(self.treasure_chest, (*energy_cyan, line_alpha)[:3],
                               (center, center), (end_x, end_y), line_width)
        
        # 6. 홀로그래픽 심볼
        # 상단 트라이앵글 심볼
        tri_points = [
            (center, size * 0.25),
            (center - 15, size * 0.35),
            (center + 15, size * 0.35)
        ]
        pygame.draw.polygon(self.treasure_chest, gold_chrome, tri_points, 2)
        
        # 7. 네온 글로우 효과
        final_glow = pygame.Surface((size, size), pygame.SRCALPHA)
        # 외곽 글로우
        for i in range(20, 0, -2):
            alpha = 10
            pygame.draw.rect(final_glow, (*energy_cyan, alpha), 
                           (i, i, size - i*2, size - i*2), 2)
        self.treasure_chest.blit(final_glow, (0, 0))
            
    def _create_energy_field(self):
        """에너지 필드 생성"""
        center_x = self.width // 2
        center_y = self.height // 2
        
        # 에너지 링 생성
        for i in range(3):
            self.energy_rings.append({
                'radius': 30 + i * 40,
                'max_radius': 200 + i * 50,
                'expansion_speed': 8 - i * 2,  # 빠른 확장
                'alpha': 255,
                'color': self.NEON_CYAN if i % 2 == 0 else self.NEON_PURPLE,
                'width': 5 - i
            })
    
    def _create_light_beam_from_crack(self, crack_angle):
        """금에서 나오는 빛줄기 생성"""
        import random
        import math
        
        center_x = self.width // 2
        center_y = self.height // 2
        
        # 금 위치에서 약간의 변화를 준 각도로 빛 생성
        angle = crack_angle + random.uniform(-0.2, 0.2)
        
        # 화면 끝까지의 거리 계산
        max_distance = math.sqrt(self.width**2 + self.height**2)
        
        # 시간에 따라 두께가 점점 증가 (처음엔 얇고 나중엔 두껍게)
        progress = min(1.0, self.next_beam_index / len(self.beam_spawn_times))
        min_width = 1 + progress * 2  # 1 -> 3
        max_width = 3 + progress * 7  # 3 -> 10
        
        # 빛줄기 생성 - 화면 끝까지 도달
        beam = {
            'angle': angle,
            'length': 0,
            'max_length': max_distance,  # 화면 끝까지
            'width': random.uniform(min_width, max_width),  # 점진적으로 두꺼워짐
            'color': random.choice([self.NEON_GOLD, self.ELECTRIC_BLUE, self.PURE_WHITE]),
            'alpha': random.randint(150, 255),
            'speed': random.uniform(4.5, 7.5),  # 3배 더 빠르게 화면 끝까지
            'pulse': random.uniform(0, math.pi * 2),
            'glow': True,
            'from_crack': True  # 금에서 나온 빛줄기 표시
        }
        self.light_beams.append(beam)
    
    def _create_light_beam(self):
        """초고속 레이저 빔 생성"""
        angle = random.uniform(0, math.pi * 2)
        
        # 화면 끝까지의 거리 계산
        max_distance = math.sqrt(self.width**2 + self.height**2)
        
        beam = {
            'angle': angle,
            'length': 0,
            'max_length': max_distance,  # 화면 끝까지
            'width': random.uniform(3, 8),  # 더 굵게
            'brightness': 1.0,
            'pulse': random.uniform(0, math.pi * 2),
            'speed': random.uniform(15, 25),  # 매우 빠른 속도
            'color': random.choice([self.NEON_GOLD, self.ELECTRIC_BLUE, self.NEON_CYAN])
        }
        self.light_beams.append(beam)
        
    def _create_explosion_particles(self):
        """울트라 네온 폭발 파티클 생성"""
        center_x = self.width // 2
        center_y = self.height // 2
        
        # 메인 폭발 파티클 (200개)
        for _ in range(200):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(10, 35)  # 더 빠른 속도
            self.explosion_particles.append({
                'x': center_x,
                'y': center_y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': 1.0,
                'size': random.randint(2, 8),
                'color': random.choice([
                    self.NEON_GOLD, self.NEON_CYAN, self.ELECTRIC_BLUE,
                    self.NEON_PINK, self.PURE_WHITE, self.NEON_PURPLE
                ]),
                'type': 'explosion',
                'glow': True,
                'trail_length': random.randint(5, 10)
            })
        
        # 스파크 파티클 (빠른 작은 파티클)
        for _ in range(100):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(20, 40)
            self.explosion_particles.append({
                'x': center_x,
                'y': center_y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': 0.5,
                'size': random.randint(1, 3),
                'color': self.PURE_WHITE,
                'type': 'spark',
                'glow': True,
                'trail_length': 3
            })
    
    def _create_ambient_particles(self):
        """홀로그래픽 에너지 파티클 생성"""
        center_x = self.width // 2
        center_y = self.height // 2
        
        # 네온 에너지 파티클 (빠르게 회전)
        for _ in range(30):  # 더 많은 파티클
            angle = random.uniform(0, math.pi * 2)
            distance = random.uniform(40, 150)
            self.ambient_particles.append({
                'x': center_x + math.cos(angle) * distance,
                'y': center_y + math.sin(angle) * distance,
                'base_x': center_x,
                'base_y': center_y,
                'angle': angle,
                'distance': distance,
                'orbit_speed': random.uniform(0.005, 0.01),  # 더 빠른 회전
                'size': random.uniform(2, 5),
                'brightness': random.uniform(0.5, 1.0),
                'pulse': random.uniform(0, math.pi * 2),
                'pulse_speed': random.uniform(0.005, 0.01),
                'color': random.choice([
                    self.NEON_CYAN, self.ELECTRIC_BLUE, 
                    self.NEON_GOLD, self.NEON_PURPLE
                ]),
                'type': 'energy'
            })
    
    def _create_magic_particles(self):
        """마법 이펙트 파티클 생성 (상자 주변)"""
        center_x = self.width // 2
        center_y = self.height // 2
        
        # 상자에서 솟아오르는 마법 파티클
        for _ in range(5):
            self.magic_particles.append({
                'x': center_x + random.uniform(-30, 30),
                'y': center_y + random.uniform(-10, 10),
                'vx': random.uniform(-0.5, 0.5),
                'vy': random.uniform(-2, -0.5),
                'life': 1.0,
                'size': random.uniform(2, 4),
                'trail': [],
                'color': (255, 255, 220),
                'glow': True
            })
            
    def update(self, dt: float) -> bool:
        """애니메이션 업데이트"""
        if not self.active:
            return False
            
        self.animation_time += dt
        self.phase_timer += dt
        
        # 전설 아이템 애니메이션 프레임 업데이트
        if self.legendary_item and self.legendary_item.animation_frames:
            self.icon_animation_timer += dt
            if self.icon_animation_timer > 100:  # 100ms마다 프레임 변경
                self.icon_animation_timer = 0
                self.icon_animation_frame = (self.icon_animation_frame + 1) % len(self.legendary_item.animation_frames)
        
        # 폭발 후 0.5초 뒤에 legendafter.wav 재생
        if self.explosion_time > 0 and not self.legendafter_played:
            if self.animation_time - self.explosion_time >= 500:  # 폭발 후 0.5초
                if self.legendafter_sound:
                    self.legendafter_sound.play()
                    self.legendafter_played = True
                    print(f"🔊 전설 아이템 사운드 재생: legendafter.wav (폭발 후 0.5초)")
        
        # 페이즈 0에서 점진적 금 생성과 빛줄기
        if self.phase == 0:
            # 금 생성 진행도 (0~1)
            self.crack_formation_progress = min(1.0, self.animation_time / 2000)
            
            # 타이밍에 따라 금 생성하고 그 금에서 빛줄기 생성
            while self.next_beam_index < len(self.beam_spawn_times) and \
                  self.animation_time >= self.beam_spawn_times[self.next_beam_index]:
                
                # 새로운 금 생성 - 더 다양한 각도로
                crack_count = self.next_beam_index + 1
                for i in range(crack_count):
                    # 더 랜덤한 각도 분포 (전체 360도 범위에서)
                    base_angle = random.uniform(0, 360)  # 완전 랜덤
                    angle = base_angle * math.pi / 180
                    self.cracks.append({
                        'angle': angle,
                        'length': random.uniform(30, 60),
                        'width': random.uniform(1, 3),
                        'branches': [],
                        'glow': 0,
                        'formation_time': self.animation_time
                    })
                    
                    # 각 금에서 빛줄기 생성
                    for j in range(2):  # 각 금마다 2개씩
                        self._create_light_beam_from_crack(angle)
                
                self.next_beam_index += 1
                
                # 금이 갈 때마다 강도 증가
                self.crack_glow_intensity = min(1.0, self.crack_glow_intensity + 0.25)
        
        # 페이즈 전환
        if self.phase == 0 and self.phase_timer > 2000:  # 2초 빌드업
            self.phase = 1
            self.phase_timer = 0
            self.explosion_time = self.animation_time  # 폭발 시작 시간 기록
            # 마지막 대량 빛줄기 추가
            for _ in range(10):
                self._create_light_beam()
            self._create_explosion_particles()
            self.screen_flash = 200
            self.chromatic_aberration = 20
            
        elif self.phase == 1 and self.phase_timer > 300:  # 0.3초 폭발
            self.phase = 1.5  # 화이트 페이드 아웃 페이즈 추가
            self.phase_timer = 0
            self.white_fade_alpha = 255  # 완전히 흰 화면에서 시작
            
        elif self.phase == 1.5 and self.phase_timer > 1000:  # 1초간 화이트 페이드 아웃
            self.phase = 2
            self.phase_timer = 0
            
        # 페이즈 2는 스페이스바를 누를 때까지 계속 유지
            
        # 페이즈별 업데이트
        if self.phase == 0:
            # 빌드업 - 금이 가면서 빛이 새어나옴
            progress = self.phase_timer / 2000  # 2초 기준
            
            # 금이 늘어날수록 약간의 진동
            self.chest_shake_amplitude = progress * 5  # 적은 흔들림
            self.chest_rotation = math.sin(self.animation_time * 0.01) * progress * 3  # 미세한 회전
            
            # 금에서 빛이 새어나오는 효과
            for crack in self.cracks:
                age = self.animation_time - crack['formation_time']
                if age < 200:  # 금이 형성되는 애니메이션
                    crack['glow'] = min(1.0, age / 200)
                else:
                    # 펄스 효과
                    crack['glow'] = 0.7 + 0.3 * math.sin(self.animation_time * 0.005)
            
            # 빛줄기가 화면 끝까지 서서히 뻗어나감
            for beam in self.light_beams:
                if beam['length'] < beam['max_length']:
                    # 금에서 나온 빛은 빠르게 뻗어나감
                    if beam.get('from_crack'):
                        beam['length'] += beam['speed'] * dt * 1.5  # 3배 더 빠르게 (0.5 -> 1.5)
                    else:
                        beam['length'] += beam.get('speed', 20) * dt
                beam['pulse'] += dt * 0.001
            
            # 빠른 회전 파티클
            for particle in self.ambient_particles:
                particle['angle'] += particle['orbit_speed'] * dt * (1 + progress * 3)
                particle['x'] = particle['base_x'] + math.cos(particle['angle']) * particle['distance']
                particle['y'] = particle['base_y'] + math.sin(particle['angle']) * particle['distance']
                particle['pulse'] += particle['pulse_speed'] * dt
                particle['brightness'] = 0.7 + 0.3 * math.sin(particle['pulse'])
                # 점점 중앙으로 끌려옴
                particle['distance'] = max(20, particle['distance'] - dt * 0.05)
            
            # 에너지 링 수축
            for ring in self.energy_rings:
                ring['radius'] = max(10, ring['radius'] - dt * 0.1)
            
            # 마법 파티클 폭증
            if random.random() < progress * 0.1:
                self._create_magic_particles()
            
        elif self.phase == 1:
            # 폭발 - 모든 빛줄기 최대 확장
            for beam in self.light_beams:
                if beam['length'] < beam['max_length']:
                    beam['length'] += beam['speed'] * dt * 2  # 초고속 확장
                beam['pulse'] += dt * 0.02
                
            # 폭발 중 효과
            self.chest_shake_amplitude = 40
            self.chest_rotation = random.uniform(-10, 10)  # 랜덤 진동
            
            # 최대 글로우
            self.chest_glow = 255
            
            # 충격파 급속 확장
            if self.shockwave_radius < 400:
                self.shockwave_radius += dt * 2
                
        elif self.phase == 1.5:
            # 화이트 페이드 아웃 - 천천히 어두워짐
            fade_progress = self.phase_timer / 1000  # 1초에 걸쳐 페이드
            self.white_fade_alpha = max(0, 255 * (1 - fade_progress))
            
            # 폭발 파티클 천천히 사라짐
            for particle in self.explosion_particles:
                particle['life'] = max(0, particle['life'] - dt * 0.001)
                
        elif self.phase == 2:
            # legendafter.wav 페이드아웃 타이머 처리
            if self.legendafter_fade_timer > 0:
                self.legendafter_fade_timer -= dt
                if self.legendafter_fade_timer <= 0:
                    # 1.5초 후 legendafter.wav 종료
                    if self.legendafter_sound:
                        self.legendafter_sound.stop()
                        print("🔇 legendafter.wav 사운드 종료 (1.5초 후)")
                    self.legendafter_fade_timer = 0
            
            # 블랙홀 애니메이션 처리
            if self.black_hole_phase == 1:
                # 가속 회전 단계
                self.black_hole_timer += dt
                # 회전 속도 가속
                self.rotation_speed += dt * 0.00001  # 점점 빠르게
                self.illuminati_rotation += dt * self.rotation_speed
                
                # 1초 후 흡수 단계로
                if self.black_hole_timer > 1000:
                    self.black_hole_phase = 2
                    self.black_hole_timer = 0
                    # 심볼 초기 위치 저장
                    self.symbol_positions = []
                    for i in range(6):
                        angle = (2 * math.pi * i / 6) + self.illuminati_rotation
                        x = self.width // 2 + 130 * math.cos(angle)
                        y = self.height // 2 + 130 * math.sin(angle) + self.item_float_offset
                        self.symbol_positions.append({'x': x, 'y': y, 'scale': 1.0})
                        
            elif self.black_hole_phase == 2:
                # 흡수 단계 (블랙홀 효과)
                self.black_hole_timer += dt
                progress = min(1.0, self.black_hole_timer / 1500)  # 1.5초 동안 흡수
                
                # 패들 위치로 빨려들어감
                paddle_x = self.paddle_x
                paddle_y = self.paddle_y
                
                # 심볼들 위치 업데이트
                for i, pos in enumerate(self.symbol_positions):
                    # 나선형으로 빨려들어가는 효과
                    spiral_angle = self.illuminati_rotation + (2 * math.pi * i / 6) + progress * math.pi * 4
                    radius = 130 * (1 - progress * 0.9)  # 반경 감소
                    
                    # 목표 위치 (패들)로 이동
                    target_x = paddle_x
                    target_y = paddle_y
                    
                    # 현재 위치 계산 (나선형 + 직선 이동 혼합)
                    spiral_x = self.width // 2 + radius * math.cos(spiral_angle)
                    spiral_y = self.height // 2 + radius * math.sin(spiral_angle)
                    
                    # 선형 보간으로 패들로 이동
                    pos['x'] = spiral_x + (target_x - spiral_x) * progress
                    pos['y'] = spiral_y + (target_y - spiral_y) * progress
                    pos['scale'] = 1.0 - progress * 0.8  # 크기 감소
                
                # 회전 계속 가속
                self.rotation_speed += dt * 0.00005
                self.illuminati_rotation += dt * self.rotation_speed
                
                # 아이템도 서서히 사라짐
                self.item_alpha = int(255 * (1 - progress))
                
                # 흡수 완료 -> 패들 빛나기 페이즈로 전환
                if progress >= 1.0:
                    self.black_hole_phase = 3
                    self.black_hole_timer = 0
                    self.paddle_glow_timer = 0
                    self.item_alpha = 0
                    
                    # 바로크 파티클 초기화 (페이즈 3 시작 시 한 번만)
                    self.baroque_particles = []
                    for i in range(30):
                        self.baroque_particles.append({
                            'x': self.paddle_x + random.randint(-40, 40),
                            'y': self.paddle_y,
                            'vx': random.uniform(-1, 1),
                            'vy': random.uniform(-8, -3),  # 위로 튀어오름
                            'size': random.randint(3, 8),
                            'rotation': random.uniform(0, math.pi * 2),
                            'rotation_speed': random.uniform(-0.1, 0.1),
                            'type': random.choice(['fleur', 'acanthus', 'rosette', 'scroll']),
                            'color_index': random.randint(0, 3),
                            'lifetime': 0,
                            'max_lifetime': random.uniform(400, 600)
                        })
            
            elif self.black_hole_phase == 3:
                # 패들 빛나기 효과 (0.6초)
                self.paddle_glow_timer += dt
                
                # 빛나기 강도 계산 (펄스 효과)
                progress = self.paddle_glow_timer / 600  # 0.6초
                if progress < 0.3:
                    # 빠르게 밝아짐
                    self.paddle_glow_intensity = progress / 0.3
                elif progress < 0.7:
                    # 최대 밝기 유지
                    self.paddle_glow_intensity = 1.0
                else:
                    # 서서히 사라짐
                    self.paddle_glow_intensity = 1.0 - ((progress - 0.7) / 0.3)
                
                # 0.6초 후 애니메이션 완전 종료
                if self.paddle_glow_timer >= 600:
                    self.active = False
                    self.animation_complete = True
                    
            else:
                # 일반 플로팅 애니메이션
                self.item_float_time += dt
                # 부드러운 위아래 움직임 (사인파)
                self.item_float_offset = math.sin(self.item_float_time * 0.003) * 20  # 20픽셀 범위로 위아래
                # 일루미나티 심볼 회전 (매우 천천히)
                self.illuminati_rotation += dt * self.rotation_speed  # 기본 속도로 회전
            
        # 폭발 파티클 업데이트 (페이즈 1, 2에서 계속)
        if self.phase >= 1:
            new_particles = []
            for particle in self.explosion_particles:
                particle['x'] += particle['vx'] * dt * 0.1
                particle['y'] += particle['vy'] * dt * 0.1
                particle['vx'] *= 0.98
                particle['vy'] *= 0.98
                particle['life'] -= dt * 0.002
                
                if particle['life'] > 0:
                    new_particles.append(particle)
            self.explosion_particles = new_particles
            
            # 플래시 감소
            if self.screen_flash > 0:
                self.screen_flash = max(0, self.screen_flash - dt * 0.5)
        
        # 마법 파티클 업데이트 비활성화 (올라가는 기포 제거)
        # new_magic = []
        # for particle in self.magic_particles:
        #     particle['x'] += particle['vx']
        #     particle['y'] += particle['vy']
        #     particle['vy'] -= 0.02  # 위로 가속
        #     particle['life'] -= dt * 0.001
        #     
        #     # 트레일 추가
        #     if len(particle['trail']) > 8:
        #         particle['trail'].pop(0)
        #     particle['trail'].append((particle['x'], particle['y'], particle['life']))
        #     
        #     if particle['life'] > 0:
        #         new_magic.append(particle)
        # self.magic_particles = new_magic
        
        # 주변 파티클 업데이트 (페이즈 2까지만)
        if self.phase < 2:
            for particle in self.ambient_particles:
                particle['pulse'] += dt * 0.003
                particle['brightness'] = 0.5 + 0.5 * math.sin(particle['pulse'])
                
        return True
        
    def _draw_cracks(self, screen: pygame.Surface, center_x: int, center_y: int):
        """보물상자에 금 간 효과 그리기"""
        import math
        
        for crack in self.cracks:
            if crack['glow'] <= 0:
                continue
                
            # 금의 시작점 (상자 중앙)
            start_x = center_x
            start_y = center_y
            
            # 금의 끝점
            end_x = center_x + math.cos(crack['angle']) * crack['length']
            end_y = center_y + math.sin(crack['angle']) * crack['length']
            
            # 빛나는 금 효과
            glow_intensity = crack['glow'] * self.crack_glow_intensity
            
            if glow_intensity > 0:
                # 금에서 새어나오는 빛 (여러 레이어)
                for i in range(3):
                    width = crack['width'] + (3 - i) * 2
                    alpha = int(glow_intensity * 100 * (1 - i * 0.3))
                    
                    if alpha > 0:
                        # 금 라인 그리기
                        glow_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
                        
                        # 금 색상 (황금빛)
                        crack_color = self.NEON_GOLD if i == 0 else self.PURE_WHITE
                        
                        # 두꺼운 선으로 금 표현
                        pygame.draw.line(glow_surf, (*crack_color, alpha),
                                       (start_x, start_y), (end_x, end_y), int(width))
                        
                        # 금의 가지 (작은 갈라짐)
                        if i == 0 and crack['length'] > 40:
                            branch_angle = crack['angle'] + random.choice([-0.5, 0.5])
                            branch_end_x = center_x + math.cos(branch_angle) * (crack['length'] * 0.6)
                            branch_end_y = center_y + math.sin(branch_angle) * (crack['length'] * 0.6)
                            pygame.draw.line(glow_surf, (*crack_color, alpha // 2),
                                           ((start_x + end_x) // 2, (start_y + end_y) // 2),
                                           (branch_end_x, branch_end_y), max(1, int(width // 2)))
                        
                        screen.blit(glow_surf, (0, 0), special_flags=pygame.BLEND_ADD)
    
    def _draw_light_beam(self, screen: pygame.Surface, center_x: int, center_y: int, beam: dict):
        """울트라 네온 레이저 빔 - 사이버펑크 스타일"""
        end_x = center_x + math.cos(beam['angle']) * beam['length']
        end_y = center_y + math.sin(beam['angle']) * beam['length']
        
        # 펄스 효과
        pulse_factor = 1 + 0.5 * math.sin(beam['pulse'])
        width = beam['width'] * pulse_factor
        
        # 네온 레이저 레이어
        beam_color = beam.get('color', self.NEON_CYAN)
        
        # 초고속 레이저 효과
        for i in range(5):
            layer_width = width * (3 - i * 0.5)
            alpha = 255 - i * 40
            
            if i == 0:  # 가장 밝은 코어
                color = self.PURE_WHITE
            elif i == 1:  # 밝은 색상
                color = tuple(min(255, c + 100) for c in beam_color)
            else:  # 원래 색상
                color = beam_color
            
            # 레이저 그리기
            temp_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            pygame.draw.line(temp_surf, (*color, alpha)[:3],
                           (center_x, center_y), (end_x, end_y), max(1, int(layer_width)))
            screen.blit(temp_surf, (0, 0), special_flags=pygame.BLEND_ADD)
            
        # 레이저 끝부분 플레어
        if beam['length'] > 50:
            flare_surf = pygame.Surface((40, 40), pygame.SRCALPHA)
            pygame.draw.circle(flare_surf, (*beam_color, 100), (20, 20), 15)
            pygame.draw.circle(flare_surf, self.PURE_WHITE, (20, 20), 5)
            screen.blit(flare_surf, (end_x - 20, end_y - 20), special_flags=pygame.BLEND_ADD)
            
    def draw(self, screen: pygame.Surface, font_large: pygame.font.Font, font_huge: Optional[pygame.font.Font] = None):
        """애니메이션 그리기"""
        if not self.active:
            return
            
        # 어두운 오버레이
        overlay = pygame.Surface((self.width, self.height))
        overlay.set_alpha(180)
        overlay.fill((0, 0, 0))
        screen.blit(overlay, (0, 0))
        
        center_x = self.width // 2
        center_y = self.height // 2
        
        # 주변 파티클 그리기 (페이즈 0, 1)
        if self.phase <= 1:
            for particle in self.ambient_particles:
                alpha = int(particle['brightness'] * 200)
                size = int(particle['size'])
                if size > 0 and alpha > 0:
                    # 파티클 글로우
                    glow_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surf, (*particle['color'], alpha // 3),
                                     (size * 2, size * 2), size * 2)
                    screen.blit(glow_surf, (particle['x'] - size * 2, particle['y'] - size * 2),
                              special_flags=pygame.BLEND_ADD)
                    # 파티클 코어
                    pygame.draw.circle(screen, particle['color'],
                                     (int(particle['x']), int(particle['y'])), size)
        
        # 마법 파티클 그리기 비활성화 (올라가는 기포 제거)
        # if self.phase < 2:
        #     for particle in self.magic_particles:
        #         # 트레일 그리기
        #         for i, (tx, ty, tlife) in enumerate(particle['trail']):
        #             trail_alpha = int(tlife * 100 * (i / len(particle['trail'])))
        #             trail_size = max(1, int(particle['size'] * 0.5 * (i / len(particle['trail']))))
        #             if trail_alpha > 0:
        #                 trail_surf = pygame.Surface((trail_size * 4, trail_size * 4), pygame.SRCALPHA)
        #                 pygame.draw.circle(trail_surf, (*particle['color'], trail_alpha),
        #                                  (trail_size * 2, trail_size * 2), trail_size)
        #                 screen.blit(trail_surf, (tx - trail_size * 2, ty - trail_size * 2),
        #                           special_flags=pygame.BLEND_ADD)
        #         
        #         # 파티클 본체
        #         alpha = int(particle['life'] * 255)
        #         size = int(particle['size'])
        #         if size > 0 and alpha > 0:
        #             # 글로우 효과
        #             if particle.get('glow'):
        #                 glow_surf = pygame.Surface((size * 6, size * 6), pygame.SRCALPHA)
        #                 pygame.draw.circle(glow_surf, (*particle['color'], alpha // 4),
        #                                  (size * 3, size * 3), size * 3)
        #                 screen.blit(glow_surf, (particle['x'] - size * 3, particle['y'] - size * 3),
        #                           special_flags=pygame.BLEND_ADD)
        #             # 파티클 코어
        #             pygame.draw.circle(screen, particle['color'],
        #                              (int(particle['x']), int(particle['y'])), size)
        
        # 에너지 링 그리기 비활성화 - 빛줄기만 표시
        # if self.phase <= 1:
        #     for ring in self.energy_rings:
        #         if ring['radius'] > 0 and ring['alpha'] > 0:
        #             ring_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        #             # 여러 레이어로 네온 링 효과
        #             for i in range(3):
        #                 width = ring['width'] - i
        #                 alpha = ring['alpha'] - i * 50
        #                 if width > 0 and alpha > 0:
        #                     pygame.draw.circle(ring_surf, (*ring['color'], alpha)[:3],
        #                                      (center_x, center_y), int(ring['radius']), max(1, width))
        #             screen.blit(ring_surf, (0, 0), special_flags=pygame.BLEND_ADD)
        
        # 충격파 그리기 비활성화 - 빛줄기만 표시
        # if self.phase <= 1 and self.shockwave_radius > 0:
        #     wave_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        #     wave_alpha = max(0, 255 - self.shockwave_radius)
        #     pygame.draw.circle(wave_surf, (*self.ELECTRIC_BLUE, wave_alpha // 2),
        #                      (center_x, center_y), int(self.shockwave_radius), 3)
        #     pygame.draw.circle(wave_surf, (*self.PURE_WHITE, wave_alpha // 4),
        #                      (center_x, center_y), int(self.shockwave_radius - 5), 2)
        #     screen.blit(wave_surf, (0, 0), special_flags=pygame.BLEND_ADD)
        
        # 페이즈 0, 1: 홀로그래픽 보물상자
        if self.phase <= 1:
            # 네온 글로우 효과 비활성화 - 빛줄기만 표시
            # if self.chest_glow > 0:
            #     # 다층 글로우
            #     for i in range(5):
            #         glow_surf = pygame.Surface((400, 400), pygame.SRCALPHA)
            #         radius = 150 - i * 20
            #         alpha = int(self.chest_glow * (1 - i * 0.15))
            #         if i % 2 == 0:
            #             color = self.NEON_CYAN
            #         else:
            #             color = self.NEON_PURPLE
            #         pygame.draw.circle(glow_surf, (*color, alpha // 3), (200, 200), radius)
            #         screen.blit(glow_surf, (center_x - 200, center_y - 200), special_flags=pygame.BLEND_ADD)
            #     
            #     # 중앙 밝은 코어
            #     core_surf = pygame.Surface((200, 200), pygame.SRCALPHA)
            #     pygame.draw.circle(core_surf, (*self.PURE_WHITE, int(self.chest_glow // 2)),
            #                      (100, 100), 50)
            #     screen.blit(core_surf, (center_x - 100, center_y - 100), special_flags=pygame.BLEND_ADD)
            
            if self.treasure_chest:
                # 홀로그래픽 효과를 위한 색수차
                if self.phase == 1:
                    # 빨간색 채널
                    red_chest = self.treasure_chest.copy()
                    red_chest.fill((255, 0, 0, 100), special_flags=pygame.BLEND_MULT)
                    shake_x = math.sin(self.animation_time * 0.02) * self.chest_shake_amplitude
                    shake_y = math.cos(self.animation_time * 0.03) * self.chest_shake_amplitude * 0.5
                    red_rect = red_chest.get_rect(center=(center_x + shake_x - 2, center_y + shake_y))
                    screen.blit(red_chest, red_rect, special_flags=pygame.BLEND_ADD)
                    
                    # 파란색 채널  
                    blue_chest = self.treasure_chest.copy()
                    blue_chest.fill((0, 0, 255, 100), special_flags=pygame.BLEND_MULT)
                    blue_rect = blue_chest.get_rect(center=(center_x + shake_x + 2, center_y + shake_y))
                    screen.blit(blue_chest, blue_rect, special_flags=pygame.BLEND_ADD)
                
                # 메인 상자
                shake_x = math.sin(self.animation_time * 0.02) * self.chest_shake_amplitude
                shake_y = math.cos(self.animation_time * 0.03) * self.chest_shake_amplitude * 0.5
                
                # 스케일 애니메이션 (150 크기 기준)
                scale = self.chest_scale * (1 + 0.05 * math.sin(self.animation_time * 0.01))
                scaled_size = int(150 * scale)
                scaled_chest = pygame.transform.scale(self.treasure_chest, (scaled_size, scaled_size))
                
                # 회전
                rotated_chest = pygame.transform.rotate(scaled_chest, self.chest_rotation)
                
                chest_rect = rotated_chest.get_rect(center=(center_x + shake_x, center_y + shake_y))
                screen.blit(rotated_chest, chest_rect)
                
                # 페이즈 0: 금 그리기
                if self.phase == 0 and self.cracks:
                    self._draw_cracks(screen, center_x + shake_x, center_y + shake_y)
                
        # 페이즈 0, 1: 빛줄기 (빌드업과 폭발)
        if self.phase <= 1:
            for beam in self.light_beams:
                self._draw_light_beam(screen, center_x, center_y, beam)
                
        # 페이즈 1: 폭발
        if self.phase == 1:
            # 폭발 파티클 with 트레일
            for particle in self.explosion_particles:
                alpha = int(255 * particle['life'])
                size = int(particle['size'] * particle['life'])
                
                if size > 0 and alpha > 0:
                    # 파티클 트레일 효과
                    if particle.get('trail_length'):
                        trail_positions = []
                        for i in range(particle.get('trail_length', 5)):
                            trail_x = particle['x'] - particle['vx'] * i * 2
                            trail_y = particle['y'] - particle['vy'] * i * 2
                            trail_positions.append((trail_x, trail_y))
                        
                        for i, (tx, ty) in enumerate(trail_positions):
                            trail_alpha = alpha * (1 - i / len(trail_positions))
                            trail_size = size * (1 - i / len(trail_positions))
                            if trail_size > 0 and trail_alpha > 0:
                                trail_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
                                pygame.draw.circle(trail_surf, (*particle['color'], int(trail_alpha // 2)),
                                                 (10, 10), max(1, int(trail_size)))
                                screen.blit(trail_surf, (tx - 10, ty - 10), special_flags=pygame.BLEND_ADD)
                    
                    # 파티클 글로우
                    if particle.get('glow'):
                        glow_surf = pygame.Surface((size * 8, size * 8), pygame.SRCALPHA)
                        pygame.draw.circle(glow_surf, (*particle['color'], alpha // 4),
                                         (size * 4, size * 4), size * 3)
                        screen.blit(glow_surf, (particle['x'] - size * 4, particle['y'] - size * 4),
                                  special_flags=pygame.BLEND_ADD)
                    
                    # 파티클 메인
                    pygame.draw.circle(screen, particle['color'],
                                     (int(particle['x']), int(particle['y'])), size)
                    
        # 페이즈 2: 아이템 표시 (플로팅 애니메이션)
        elif self.phase == 2:
            fade_progress = min(1.0, self.phase_timer / 500)
            
            # 일루미나티 심볼 그리기 (아이템 뒤에, 은은하게)
            if fade_progress > 0.3:
                self._draw_illuminati_symbols(screen, center_x, center_y, fade_progress)
            
            # 아이템 아이콘 (플로팅)
            icon_to_draw = None
            
            # 전설 아이템 애니메이션 프레임 사용
            if self.legendary_item and self.legendary_item.animation_frames:
                icon_to_draw = self.legendary_item.animation_frames[self.icon_animation_frame]
            elif self.item_icon and isinstance(self.item_icon, pygame.Surface):
                icon_to_draw = self.item_icon
            
            if icon_to_draw:
                # 페이드인 후 일정한 크기 유지
                if fade_progress < 1.0:
                    icon_size = int(80 * (1 + 0.5 * (1 - fade_progress)))
                    alpha = int(255 * fade_progress)
                else:
                    icon_size = 80
                    alpha = self.item_alpha if self.black_hole_phase > 0 else 255
                    
                scaled_icon = pygame.transform.scale(icon_to_draw, (icon_size, icon_size))
                scaled_icon.set_alpha(alpha)
                
                # 플로팅 오프셋 적용
                icon_rect = scaled_icon.get_rect(center=(center_x, center_y + self.item_float_offset))
                screen.blit(scaled_icon, icon_rect)
                
        # 플래시 효과 (네온 스타일)
        if self.screen_flash > 0:
            flash_surf = pygame.Surface((self.width, self.height))
            flash_surf.set_alpha(int(self.screen_flash))
            # 네온 플래시 - 사이언과 화이트 믹스
            flash_surf.fill(self.NEON_CYAN if self.phase == 1 else self.PURE_WHITE)
            screen.blit(flash_surf, (0, 0), special_flags=pygame.BLEND_ADD)
            
        # 색수차 효과 (크로마틱 애버레이션)
        if self.chromatic_aberration > 0:
            # 화면 전체를 살짝 분리
            temp_surf = screen.copy()
            # 빨간 채널 이동
            red_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            red_surf.blit(temp_surf, (-self.chromatic_aberration, 0))
            red_surf.fill((255, 0, 0, 50), special_flags=pygame.BLEND_MULT)
            screen.blit(red_surf, (0, 0), special_flags=pygame.BLEND_ADD)
            
            # 파란 채널 이동
            blue_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            blue_surf.blit(temp_surf, (self.chromatic_aberration, 0))
            blue_surf.fill((0, 0, 255, 50), special_flags=pygame.BLEND_MULT)
            screen.blit(blue_surf, (0, 0), special_flags=pygame.BLEND_ADD)
            
            self.chromatic_aberration = max(0, self.chromatic_aberration - 2)
            
        # 페이즈 1.5: 화이트 페이드 효과 (폭발 후 그라데이션)
        if self.phase == 1.5 and self.white_fade_alpha > 0:
            white_surf = pygame.Surface((self.width, self.height))
            white_surf.fill((255, 255, 255))
            white_surf.set_alpha(int(self.white_fade_alpha))
            screen.blit(white_surf, (0, 0))
    
    def _draw_mystical_halo(self, screen: pygame.Surface, center_x: int, center_y: int, fade_progress: float):
        """신비로운 후광 효과 그리기 - 밝고 은은한 빛"""
        import math
        
        # 후광 알파값 (페이드인)
        halo_alpha = int(120 * min(1.0, (fade_progress - 0.1) / 0.9))
        
        # 후광 펄스 효과 (숨쉬는 듯한 빛)
        pulse = abs(math.sin(self.phase_timer * 0.002)) * 0.3 + 0.7
        
        # 플로팅 오프셋 적용
        halo_y = center_y + self.item_float_offset
        
        # 다층 후광 (큰 것부터 작은 것까지)
        halo_layers = [
            {'radius': 200, 'alpha': 15, 'color': (255, 245, 200)},  # 가장 외곽 (따뜻한 빛)
            {'radius': 160, 'alpha': 20, 'color': (255, 235, 180)},  # 
            {'radius': 130, 'alpha': 25, 'color': (255, 225, 160)},  # 
            {'radius': 100, 'alpha': 30, 'color': (255, 215, 140)},  # 
            {'radius': 75, 'alpha': 35, 'color': (255, 205, 120)},   # 
            {'radius': 50, 'alpha': 40, 'color': (255, 195, 100)},   # 가장 내부
        ]
        
        # 각 층 그리기
        for layer in halo_layers:
            # 펄스 효과 적용
            current_radius = int(layer['radius'] * pulse)
            current_alpha = int(layer['alpha'] * halo_alpha / 120 * pulse)
            
            # 부드러운 원형 그라데이션을 위한 여러 원 그리기
            for i in range(5):
                grad_radius = current_radius - i * (current_radius // 10)
                grad_alpha = current_alpha - i * 5
                if grad_radius > 0 and grad_alpha > 0:
                    # 후광 서페이스
                    halo_surf = pygame.Surface((grad_radius * 2, grad_radius * 2), pygame.SRCALPHA)
                    
                    # 방사형 그라데이션 효과
                    for r in range(grad_radius, 0, -2):
                        alpha = int(grad_alpha * (r / grad_radius))
                        if alpha > 0:
                            pygame.draw.circle(halo_surf, (*layer['color'], alpha),
                                             (grad_radius, grad_radius), r)
                    
                    # 블렌드 모드로 그리기
                    screen.blit(halo_surf, 
                              (center_x - grad_radius, halo_y - grad_radius),
                              special_flags=pygame.BLEND_ADD)
        
        # 중심부 강렬한 빛
        core_radius = int(30 * pulse)
        core_alpha = int(80 * halo_alpha / 120)
        
        # 중심 광원
        core_surf = pygame.Surface((core_radius * 2, core_radius * 2), pygame.SRCALPHA)
        for r in range(core_radius, 0, -1):
            alpha = int(core_alpha * (r / core_radius) ** 0.5)  # 제곱근으로 중심부 강조
            if alpha > 0:
                pygame.draw.circle(core_surf, (255, 255, 255, alpha),
                                 (core_radius, core_radius), r)
        
        screen.blit(core_surf, 
                  (center_x - core_radius, halo_y - core_radius),
                  special_flags=pygame.BLEND_ADD)
        
        # 빛나는 입자들 (별빛 효과)
        if fade_progress > 0.3:
            particle_count = 20
            for i in range(particle_count):
                # 원형으로 분포
                angle = (2 * math.pi * i / particle_count) + self.phase_timer * 0.0001
                distance = 60 + math.sin(angle * 3 + self.phase_timer * 0.001) * 20
                
                particle_x = center_x + distance * math.cos(angle)
                particle_y = halo_y + distance * math.sin(angle)
                
                # 반짝이는 효과
                sparkle = abs(math.sin(self.phase_timer * 0.005 + i)) 
                particle_alpha = int(50 * sparkle * halo_alpha / 120)
                particle_size = int(2 + sparkle * 2)
                
                if particle_alpha > 0:
                    # 빛나는 입자
                    particle_surf = pygame.Surface((particle_size * 4, particle_size * 4), pygame.SRCALPHA)
                    pygame.draw.circle(particle_surf, (255, 245, 220, particle_alpha),
                                     (particle_size * 2, particle_size * 2), particle_size)
                    screen.blit(particle_surf,
                              (int(particle_x - particle_size * 2), int(particle_y - particle_size * 2)),
                              special_flags=pygame.BLEND_ADD)
        
        # 빛의 광선 (방사형)
        if fade_progress > 0.5:
            ray_count = 12
            for i in range(ray_count):
                angle = (2 * math.pi * i / ray_count) + self.phase_timer * 0.0002
                
                # 광선 길이 변화
                ray_length = 150 + math.sin(self.phase_timer * 0.003 + i) * 30
                ray_alpha = int(20 * halo_alpha / 120 * pulse)
                
                if ray_alpha > 0:
                    # 광선 끝점
                    end_x = center_x + ray_length * math.cos(angle)
                    end_y = halo_y + ray_length * math.sin(angle)
                    
                    # 부드러운 광선 (여러 선으로)
                    for w in range(3):
                        width_offset = (w - 1) * 2
                        line_alpha = ray_alpha - w * 5
                        if line_alpha > 0:
                            # 광선 그리기
                            pygame.draw.line(screen, (255, 240, 200),
                                           (center_x + width_offset * math.cos(angle + math.pi/2), 
                                            halo_y + width_offset * math.sin(angle + math.pi/2)),
                                           (int(end_x), int(end_y)), 1)
    
    def _draw_illuminati_symbols(self, screen: pygame.Surface, center_x: int, center_y: int, fade_progress: float):
        """일루미나티 신비로운 심볼 그리기 - 고급스럽고 세련되게"""
        import math
        import random
        
        # 심볼 알파값 (매우 은은하게)
        symbol_alpha = int(90 * min(1.0, (fade_progress - 0.3) / 0.7))  # 최대 90으로 은은함
        
        # 회전 각도 (매우 천천히)
        rotation = self.illuminati_rotation
        
        # 고급스러운 색상 팔레트
        royal_gold = (255, 215, 0)  # 로열 골드
        deep_purple = (75, 0, 130)  # 딥 퍼플 (인디고)
        mystic_violet = (138, 43, 226)  # 미스틱 바이올렛
        ancient_silver = (192, 192, 192)  # 고대 은색
        sacred_amber = (255, 191, 0)  # 신성한 호박색
        
        
        # 고대 심볼들 (원형 배치) - 블랙홀 페이즈 3에서는 그리지 않음
        if self.black_hole_phase >= 3:
            return  # 블랙홀 흡수 완료 후에는 심볼들을 그리지 않음
            
        outer_radius = 130
        num_symbols = 6  # 6개의 심볼
        
        for i in range(num_symbols):
            angle = (2 * math.pi * i / num_symbols) + rotation  # 항상 angle 계산
            
            # 블랙홀 애니메이션 중이면 패들로 이동
            if self.black_hole_phase == 2:
                progress = min(1.0, self.black_hole_timer / 700)  # 0.7초 동안 흡수
                
                # 원래 위치
                orig_x = center_x + outer_radius * math.cos(angle)
                orig_y = center_y + outer_radius * math.sin(angle) + self.item_float_offset
                
                # 패들로 이동
                move_x = self.paddle_x - orig_x
                move_y = self.paddle_y - orig_y
                
                # 가속도 효과로 이동
                move_progress = progress * progress * progress  # 세제곱으로 가속
                symbol_x = orig_x + move_x * move_progress
                symbol_y = orig_y + move_y * move_progress
                
                # 크기 감소
                scale = 1.0 - progress * 0.9  # 10%까지 줄어듦
                
                # 알파값 감소
                if progress > 0.8:
                    symbol_alpha = int(symbol_alpha * (1 - (progress - 0.8) * 5))
                else:
                    symbol_alpha = int(symbol_alpha * (1 - progress * 0.5))
                    
                if symbol_alpha <= 0:
                    continue  # 완전히 투명해지면 그리지 않음
            else:
                # 일반 위치
                symbol_x = center_x + outer_radius * math.cos(angle)
                symbol_y = center_y + outer_radius * math.sin(angle) + self.item_float_offset
                scale = 1.0
            
            # 각 위치에 더 정교한 고대 도형 그리기 (크기 조절 적용)
            if i == 0:
                # 태양 심볼 (다층 구조)
                pygame.draw.circle(screen, royal_gold, (int(symbol_x), int(symbol_y)), max(1, int(10 * scale)), 1)
                pygame.draw.circle(screen, sacred_amber, (int(symbol_x), int(symbol_y)), max(1, int(7 * scale)), 1)
                pygame.draw.circle(screen, royal_gold, (int(symbol_x), int(symbol_y)), max(1, int(4 * scale)), 1)
                if scale > 0.2:  # 너무 작아지면 중심점은 그리지 않음
                    pygame.draw.circle(screen, sacred_amber, (int(symbol_x), int(symbol_y)), max(1, int(2 * scale)))
                # 태양 광선
                if scale > 0.3:  # 작아지면 광선은 그리지 않음
                    for r in range(8):
                        ray_angle = angle + (2 * math.pi * r / 8)
                        rx1 = symbol_x + 5 * scale * math.cos(ray_angle)
                        ry1 = symbol_y + 5 * scale * math.sin(ray_angle)
                        rx2 = symbol_x + 9 * scale * math.cos(ray_angle)
                        ry2 = symbol_y + 9 * scale * math.sin(ray_angle)
                        pygame.draw.line(screen, royal_gold, (int(rx1), int(ry1)), (int(rx2), int(ry2)), 1)
                    
            elif i == 1:
                # 달과 별 (정교한 초승달)
                if scale > 0.2:  # 너무 작으면 그리지 않음
                    # 달
                    arc_size = max(4, int(16 * scale))
                    pygame.draw.arc(screen, ancient_silver, 
                                  (int(symbol_x - arc_size/2), int(symbol_y - arc_size/2), arc_size, arc_size),
                                  math.pi * 0.3, math.pi * 1.7, max(1, int(2 * scale)))
                    if scale > 0.3:
                        arc_size2 = max(3, int(12 * scale))
                        pygame.draw.arc(screen, mystic_violet, 
                                      (int(symbol_x - arc_size2/2), int(symbol_y - arc_size2/2), arc_size2, arc_size2),
                                      math.pi * 0.4, math.pi * 1.6, 1)
                    # 작은 별
                    if scale > 0.4:
                        pygame.draw.circle(screen, ancient_silver, (int(symbol_x + 5 * scale), int(symbol_y - 3 * scale)), 1)
                        pygame.draw.circle(screen, ancient_silver, (int(symbol_x + 3 * scale), int(symbol_y + 2 * scale)), 1)
                
            elif i == 2:
                # 오각별 (더 정교하게)
                # 외부 별
                star_points_outer = []
                star_points_inner = []
                for j in range(10):
                    star_angle = angle + (2 * math.pi * j / 10) - math.pi/2
                    if j % 2 == 0:
                        star_r = 10
                        sx = symbol_x + star_r * math.cos(star_angle)
                        sy = symbol_y + star_r * math.sin(star_angle)
                        star_points_outer.append((int(sx), int(sy)))
                    else:
                        star_r = 4
                        sx = symbol_x + star_r * math.cos(star_angle)
                        sy = symbol_y + star_r * math.sin(star_angle)
                        star_points_inner.append((int(sx), int(sy)))
                
                # 별 그리기
                all_points = []
                for j in range(5):
                    all_points.append(star_points_outer[j])
                    all_points.append(star_points_inner[j])
                pygame.draw.polygon(screen, royal_gold, all_points, 2)
                # 중심부
                pygame.draw.circle(screen, sacred_amber, (int(symbol_x), int(symbol_y)), 2, 1)
                
            elif i == 3:
                # 무한대 심볼 (∞)
                # 왼쪽 원
                pygame.draw.circle(screen, deep_purple, 
                                 (int(symbol_x - 5), int(symbol_y)), 6, 2)
                # 오른쪽 원
                pygame.draw.circle(screen, deep_purple, 
                                 (int(symbol_x + 5), int(symbol_y)), 6, 2)
                # 내부 작은 원들
                pygame.draw.circle(screen, mystic_violet, 
                                 (int(symbol_x - 5), int(symbol_y)), 3, 1)
                pygame.draw.circle(screen, mystic_violet, 
                                 (int(symbol_x + 5), int(symbol_y)), 3, 1)
                # 중심점
                pygame.draw.circle(screen, sacred_amber, (int(symbol_x), int(symbol_y)), 2)
                
            elif i == 4:
                # 켈틱 십자가 (더 장식적으로)
                # 십자가 본체
                pygame.draw.line(screen, ancient_silver, 
                               (int(symbol_x - 8), int(symbol_y)),
                               (int(symbol_x + 8), int(symbol_y)), 2)
                pygame.draw.line(screen, ancient_silver,
                               (int(symbol_x), int(symbol_y - 8)),
                               (int(symbol_x), int(symbol_y + 8)), 2)
                
                # 중앙 원
                pygame.draw.circle(screen, royal_gold, (int(symbol_x), int(symbol_y)), 5, 1)
                pygame.draw.circle(screen, sacred_amber, (int(symbol_x), int(symbol_y)), 3, 1)
                
                # 끝 장식
                for dx, dy in [(-8, 0), (8, 0), (0, -8), (0, 8)]:
                    pygame.draw.circle(screen, ancient_silver, 
                                     (int(symbol_x + dx), int(symbol_y + dy)), 2, 1)
                
            else:
                # 신성한 다이아몬드 (다층 구조)
                # 외부 다이아몬드
                outer_diamond = [
                    (int(symbol_x), int(symbol_y - 10)),
                    (int(symbol_x + 8), int(symbol_y)),
                    (int(symbol_x), int(symbol_y + 10)),
                    (int(symbol_x - 8), int(symbol_y))
                ]
                pygame.draw.polygon(screen, royal_gold, outer_diamond, 2)
                
                # 내부 다이아몬드
                inner_diamond = [
                    (int(symbol_x), int(symbol_y - 6)),
                    (int(symbol_x + 5), int(symbol_y)),
                    (int(symbol_x), int(symbol_y + 6)),
                    (int(symbol_x - 5), int(symbol_y))
                ]
                pygame.draw.polygon(screen, sacred_amber, inner_diamond, 1)
                
                # 중심점
                pygame.draw.circle(screen, mystic_violet, (int(symbol_x), int(symbol_y)), 2)
            
            # 심볼 주변 장식 원 (이중 구조)
            pygame.draw.circle(screen, deep_purple, 
                             (int(symbol_x), int(symbol_y)), 18, 1)
            pygame.draw.circle(screen, mystic_violet, 
                             (int(symbol_x), int(symbol_y)), 15, 1)
            
            # 작은 장식 점들
            for d in range(4):
                dot_angle = angle + (math.pi * d / 2)
                dot_x = symbol_x + 18 * math.cos(dot_angle)
                dot_y = symbol_y + 18 * math.sin(dot_angle)
                pygame.draw.circle(screen, royal_gold, (int(dot_x), int(dot_y)), 1)
        
        # 내부 신성한 마법진 (영적이고 신비로운 육각형)
        # 블랙홀 페이즈 3에서는 육각형과 별을 그리지 않음
        if fade_progress > 0.4 and self.black_hole_phase < 3:
            inner_alpha = int(50 * min(1.0, (fade_progress - 0.4) / 0.6))
            
            # 블랙홀 흡수 중이면 육각형과 별이 패들로 빨려들어감
            if self.black_hole_phase == 2:
                progress = min(1.0, self.black_hole_timer / 700)  # 0.7초 동안 흡수
                
                # 육각형과 별의 크기 감소
                scale_factor = 1.0 - progress * 0.9  # 10% 크기까지 줄어듦
                
                # 패들 방향으로 이동
                move_x = self.paddle_x - center_x
                move_y = self.paddle_y - center_y
                
                # 이동 거리 계산 (가속도 효과)
                move_progress = progress * progress * progress  # 세제곱으로 더 강한 가속 효과
                current_x = center_x + move_x * move_progress
                current_y = center_y + move_y * move_progress
                
                # 회전 가속도 증가
                rotation = rotation * (1 + progress * 5)  # 흡수되면서 빠르게 회전
                
                # 알파값 감소 (마지막에 빠르게 사라짐)
                if progress > 0.8:
                    inner_alpha = int(inner_alpha * (1 - (progress - 0.8) * 5))
                else:
                    inner_alpha = int(inner_alpha * (1 - progress * 0.5))
            else:
                scale_factor = 1.0
                current_x = center_x
                current_y = center_y
            
            # 삼중 육각형 마법진
            for layer in range(3):
                hexagon_radius = (80 - layer * 10) * scale_factor  # 크기 조절 적용
                layer_alpha = inner_alpha - layer * 10
                
                if layer_alpha <= 0:
                    continue
                
                # 각 층의 색상 변화
                if layer == 0:
                    hex_color = mystic_violet
                elif layer == 1:
                    hex_color = deep_purple
                else:
                    hex_color = sacred_amber
                
                # 육각형 그리기
                hex_points = []
                for i in range(6):
                    angle = (2 * math.pi * i / 6) - rotation * (0.5 + layer * 0.2)
                    x = current_x + hexagon_radius * math.cos(angle)
                    y = current_y + hexagon_radius * math.sin(angle) + self.item_float_offset
                    hex_points.append((int(x), int(y)))
                
                # 육각형 외곽선
                for i in range(6):
                    pygame.draw.line(screen, hex_color,
                                   hex_points[i], hex_points[(i + 1) % 6], 1)
                
                # 육각형 꼭지점에 작은 원
                for point in hex_points:
                    pygame.draw.circle(screen, royal_gold, point, max(1, int(2 * scale_factor)), 1)
            
            # 중앙 별 (6각 별)
            star_radius = 40 * scale_factor
            star_points = []
            for i in range(12):
                angle = (2 * math.pi * i / 12) - rotation * 0.7
                if i % 2 == 0:
                    r = star_radius
                else:
                    r = star_radius * 0.5
                x = current_x + r * math.cos(angle)
                y = current_y + r * math.sin(angle) + self.item_float_offset
                star_points.append((int(x), int(y)))
            
            # 6각 별 그리기
            if inner_alpha > 0:
                pygame.draw.polygon(screen, sacred_amber, star_points, 1)
            
            # 블랙홀 흡수 중일 때 파티클 효과 추가
            if self.black_hole_phase == 2:
                # 흡수되는 파티클들
                num_particles = int(10 * (1 - progress))  # 점점 줄어드는 파티클
                for i in range(num_particles):
                    particle_angle = random.random() * 2 * math.pi
                    particle_dist = random.uniform(20, 100) * (1 - progress)
                    particle_x = current_x + particle_dist * math.cos(particle_angle)
                    particle_y = current_y + particle_dist * math.sin(particle_angle)
                    
                    # 파티클 크기와 색상
                    particle_size = random.randint(1, 3)
                    particle_color = random.choice([royal_gold, sacred_amber, mystic_violet])
                    
                    # 파티클 그리기
                    pygame.draw.circle(screen, particle_color, 
                                     (int(particle_x), int(particle_y)), 
                                     particle_size)
            
            # 블랙홀 흡수 중이 아닐 때만 나머지 장식 그리기
            if self.black_hole_phase != 2:
                # 중심에서 육각형 꼭지점으로 연결선 (은은하게)
                for i in range(6):
                    angle = (2 * math.pi * i / 6) - rotation * 0.5
                    x = center_x + 80 * math.cos(angle)
                    y = center_y + 80 * math.sin(angle) + self.item_float_offset
                    
                    # 점선으로 연결
                    for j in range(0, 80, 10):
                        if j % 20 < 10:  # 점선 효과
                            dot_x = center_x + j * math.cos(angle)
                            dot_y = center_y + j * math.sin(angle) + self.item_float_offset
                            pygame.draw.circle(screen, ancient_silver, 
                                             (int(dot_x), int(dot_y)), 1)
                
                # 육각형 사이 룬 문자 효과 (신비로운 기호)
                for i in range(6):
                    angle = (2 * math.pi * (i + 0.5) / 6) - rotation * 0.5
                    rune_x = center_x + 65 * math.cos(angle)
                    rune_y = center_y + 65 * math.sin(angle) + self.item_float_offset
                    
                    # 작은 십자 룬
                    pygame.draw.line(screen, mystic_violet,
                                   (int(rune_x - 3), int(rune_y)),
                                   (int(rune_x + 3), int(rune_y)), 1)
                    pygame.draw.line(screen, mystic_violet,
                                   (int(rune_x), int(rune_y - 3)),
                                   (int(rune_x), int(rune_y + 3)), 1)
                    # 룬 주변 점
                    pygame.draw.circle(screen, royal_gold, 
                                     (int(rune_x), int(rune_y)), 5, 1)
        
        # 별자리 연결선 (은은한 점선)
        if fade_progress > 0.6:
            constellation_alpha = int(30 * min(1.0, (fade_progress - 0.6) / 0.4))
            
            # 심볼들 사이 연결
            for i in range(num_symbols):
                for j in range(i + 1, num_symbols):
                    if (i + j) % 2 == 0:  # 일부만 연결
                        angle1 = (2 * math.pi * i / num_symbols) + rotation
                        angle2 = (2 * math.pi * j / num_symbols) + rotation
                        
                        x1 = center_x + outer_radius * math.cos(angle1)
                        y1 = center_y + outer_radius * math.sin(angle1) + self.item_float_offset
                        x2 = center_x + outer_radius * math.cos(angle2)
                        y2 = center_y + outer_radius * math.sin(angle2) + self.item_float_offset
                        
                        # 점선 효과
                        num_dots = 15
                        for k in range(num_dots):
                            if k % 3 == 0:  # 듬성듬성 점
                                t = k / num_dots
                                dot_x = x1 + (x2 - x1) * t
                                dot_y = y1 + (y2 - y1) * t
                                pygame.draw.circle(screen, ancient_silver,
                                                 (int(dot_x), int(dot_y)), 1)
    
    def _draw_egyptian_hieroglyphs(self, screen: pygame.Surface, center_x: int, center_y: int, fade_progress: float):
        """이집트 상형문자 그리기 - 파피루스 스타일"""
        import math
        
        # 상형문자 알파값 (페이드인 효과)
        hieroglyph_alpha = int(180 * min(1.0, (fade_progress - 0.2) / 0.8))
        
        # 회전 각도 (매우 천천히)
        rotation = self.hieroglyph_rotation
        
        # 파피루스 색상 (황금빛과 고대 갈색)
        papyrus_gold = (218, 165, 32)  # 골든로드
        ancient_brown = (101, 67, 33)  # 다크 브라운
        sacred_blue = (0, 0, 139)  # 다크 블루 (신성한 색)
        
        # 상형문자들 (유니코드 이집트 상형문자)
        hieroglyphs = [
            "𓀀", "𓀁", "𓁹", "𓂀", "𓃀", "𓄿", "𓅓", "𓆑",  # 사람, 눈, 새
            "𓇳", "𓈖", "𓉴", "𓊖", "𓋴", "𓌻", "𓍯", "𓎗"   # 태양, 물, 집, 앙크
        ]
        
        # 큰 원 주위의 상형문자
        outer_radius = 140
        num_glyphs = 12
        
        for i in range(num_glyphs):
            angle = (2 * math.pi * i / num_glyphs) + rotation
            
            # 상형문자 위치
            glyph_x = center_x + outer_radius * math.cos(angle)
            glyph_y = center_y + outer_radius * math.sin(angle) + self.item_float_offset
            
            # 상형문자 선택 (순환)
            glyph = hieroglyphs[i % len(hieroglyphs)]
            
            # 상형문자 렌더링
            try:
                # 큰 폰트로 상형문자 렌더링
                if hasattr(self, '_hieroglyph_font'):
                    font = self._hieroglyph_font
                else:
                    font = pygame.font.Font(None, 36)
                    self._hieroglyph_font = font
                
                # 상형문자 그리기 (황금색)
                text_surf = font.render(glyph, True, papyrus_gold)
                text_surf.set_alpha(hieroglyph_alpha)
                text_rect = text_surf.get_rect(center=(int(glyph_x), int(glyph_y)))
                screen.blit(text_surf, text_rect)
                
                # 그림자 효과 (고대 느낌)
                shadow_surf = font.render(glyph, True, ancient_brown)
                shadow_surf.set_alpha(hieroglyph_alpha // 3)
                shadow_rect = shadow_surf.get_rect(center=(int(glyph_x + 2), int(glyph_y + 2)))
                screen.blit(shadow_surf, shadow_rect)
                
            except:
                # 유니코드 렌더링 실패시 대체 심볼
                symbols = ["☥", "☉", "☾", "✦", "◈", "◉", "◊", "○", "●", "◐", "◑", "◒"]
                symbol = symbols[i % len(symbols)]
                
                if hasattr(self, '_symbol_font'):
                    font = self._symbol_font
                else:
                    font = pygame.font.Font(None, 28)
                    self._symbol_font = font
                
                text_surf = font.render(symbol, True, papyrus_gold)
                text_surf.set_alpha(hieroglyph_alpha)
                text_rect = text_surf.get_rect(center=(int(glyph_x), int(glyph_y)))
                screen.blit(text_surf, text_rect)
        
        # 내부 원 - 작은 상형문자들
        inner_radius = 90
        num_inner = 8
        
        for i in range(num_inner):
            angle = (2 * math.pi * i / num_inner) - rotation * 1.5  # 반대로 회전
            
            inner_x = center_x + inner_radius * math.cos(angle)
            inner_y = center_y + inner_radius * math.sin(angle) + self.item_float_offset
            
            # 작은 신성한 심볼
            small_symbols = ["•", "◦", "⋄", "∘"]
            symbol = small_symbols[i % len(small_symbols)]
            
            if not hasattr(self, '_small_font'):
                self._small_font = pygame.font.Font(None, 16)
            
            text_surf = self._small_font.render(symbol, True, sacred_blue)
            text_surf.set_alpha(hieroglyph_alpha // 2)
            text_rect = text_surf.get_rect(center=(int(inner_x), int(inner_y)))
            screen.blit(text_surf, text_rect)
        
        # 연결선 - 신비로운 파피루스 라인
        if fade_progress > 0.5:
            line_alpha = int(60 * min(1.0, (fade_progress - 0.5) / 0.5))
            
            for i in range(num_glyphs):
                angle1 = (2 * math.pi * i / num_glyphs) + rotation
                angle2 = (2 * math.pi * ((i + 1) % num_glyphs) / num_glyphs) + rotation
                
                x1 = center_x + outer_radius * math.cos(angle1)
                y1 = center_y + outer_radius * math.sin(angle1) + self.item_float_offset
                x2 = center_x + outer_radius * math.cos(angle2)
                y2 = center_y + outer_radius * math.sin(angle2) + self.item_float_offset
                
                # 점선 효과
                num_dots = 10
                for j in range(num_dots):
                    t = j / num_dots
                    dot_x = x1 + (x2 - x1) * t
                    dot_y = y1 + (y2 - y1) * t
                    
                    if j % 2 == 0:  # 점선
                        pygame.draw.circle(screen, papyrus_gold, 
                                         (int(dot_x), int(dot_y)), 1)
    
    def _draw_baroque_patterns(self, screen: pygame.Surface, center_x: int, center_y: int, fade_progress: float):
        """바로크 스타일 장식 패턴 그리기"""
        import math
        
        # 패턴 알파값 (페이드인 효과)
        pattern_alpha = int(200 * min(1.0, (fade_progress - 0.2) / 0.8))
        
        # 회전 각도 (천천히 회전)
        rotation = self.baroque_rotation
        
        # 바로크 패턴 색상 (금색과 은색)
        gold_color = (255, 215, 0, pattern_alpha)
        silver_color = (192, 192, 192, pattern_alpha // 2)
        accent_color = (255, 245, 230, pattern_alpha // 3)
        
        # 패턴 반경
        pattern_radius = 120
        
        # 8개의 장식 요소
        num_ornaments = 8
        
        for i in range(num_ornaments):
            angle = (2 * math.pi * i / num_ornaments) + rotation
            
            # 장식 위치
            ornament_x = center_x + pattern_radius * math.cos(angle)
            ornament_y = center_y + pattern_radius * math.sin(angle) + self.item_float_offset
            
            # 바로크 스타일 곡선 패턴
            # 메인 장식 (꽃잎 모양)
            for j in range(3):
                petal_angle = angle + (j - 1) * 0.3
                petal_size = 15 - j * 3
                
                # 꽃잎 끝 위치
                petal_end_x = ornament_x + petal_size * 2 * math.cos(petal_angle)
                petal_end_y = ornament_y + petal_size * 2 * math.sin(petal_angle)
                
                # 곡선 그리기 (베지어 커브 근사)
                curve_surf = pygame.Surface((abs(int(petal_end_x - ornament_x)) + 20, 
                                           abs(int(petal_end_y - ornament_y)) + 20), pygame.SRCALPHA)
                
                # 곡선 포인트들
                curve_points = []
                for t in range(11):
                    t_norm = t / 10.0
                    # 베지어 커브 계산
                    curve_x = ornament_x * (1 - t_norm) + petal_end_x * t_norm
                    curve_y = ornament_y * (1 - t_norm) + petal_end_y * t_norm
                    # 곡률 추가
                    curve_offset = math.sin(t_norm * math.pi) * petal_size * 0.5
                    curve_x += curve_offset * math.cos(petal_angle + math.pi/2)
                    curve_y += curve_offset * math.sin(petal_angle + math.pi/2)
                    curve_points.append((curve_x, curve_y))
                
                # 곡선 그리기
                if len(curve_points) > 1:
                    pygame.draw.lines(screen, gold_color[:3], False, curve_points, 2)
            
            # 중심 장식 (작은 원)
            pygame.draw.circle(screen, gold_color[:3], 
                             (int(ornament_x), int(ornament_y)), 4)
            pygame.draw.circle(screen, accent_color[:3], 
                             (int(ornament_x), int(ornament_y)), 2)
            
            # 연결 라인 (섬세한 실선)
            next_i = (i + 1) % num_ornaments
            next_angle = (2 * math.pi * next_i / num_ornaments) + rotation
            next_x = center_x + pattern_radius * math.cos(next_angle)
            next_y = center_y + pattern_radius * math.sin(next_angle) + self.item_float_offset
            
            # 연결선 중간점
            mid_x = (ornament_x + next_x) / 2
            mid_y = (ornament_y + next_y) / 2
            
            # 곡선 연결선
            control_radius = pattern_radius * 0.85
            control_x = center_x + control_radius * math.cos((angle + next_angle) / 2)
            control_y = center_y + control_radius * math.sin((angle + next_angle) / 2) + self.item_float_offset
            
            # 베지어 커브로 연결
            connection_points = []
            for t in range(21):
                t_norm = t / 20.0
                # 2차 베지어 커브
                bx = (1-t_norm)**2 * ornament_x + 2*(1-t_norm)*t_norm * control_x + t_norm**2 * next_x
                by = (1-t_norm)**2 * ornament_y + 2*(1-t_norm)*t_norm * control_y + t_norm**2 * next_y
                connection_points.append((bx, by))
            
            if len(connection_points) > 1:
                pygame.draw.lines(screen, silver_color[:3], False, connection_points, 1)
        
        # 내부 원형 장식
        inner_radius = 60
        for i in range(16):
            angle = (2 * math.pi * i / 16) + rotation * 2  # 더 빠르게 회전
            inner_x = center_x + inner_radius * math.cos(angle)
            inner_y = center_y + inner_radius * math.sin(angle) + self.item_float_offset
            
            # 작은 다이아몬드 모양
            diamond_points = [
                (inner_x, inner_y - 3),
                (inner_x + 2, inner_y),
                (inner_x, inner_y + 3),
                (inner_x - 2, inner_y)
            ]
            pygame.draw.polygon(screen, accent_color[:3], diamond_points)
        
        # 패들 빛나기 효과 (페이즈 3) - 더욱 신비로운 효과
        if self.black_hole_phase == 3 and self.paddle_glow_intensity > 0:
            import random
            
            # 패들 위치에 강력한 빛 효과
            glow_radius = int(150 * self.paddle_glow_intensity)  # 더 큰 반경
            glow_alpha = int(255 * self.paddle_glow_intensity)
            
            # 시간 기반 애니메이션
            time_factor = pygame.time.get_ticks() / 100.0
            
            # 여러 층의 글로우 효과 (더 많은 레이어)
            for i in range(8):
                radius = glow_radius - (i * 12)
                if radius > 0:
                    alpha = glow_alpha // (i + 1)
                    glow_surf = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
                    
                    # 무지개빛 색상 변화
                    hue = (time_factor * 50 + i * 30) % 360
                    color = self._hsv_to_rgb(hue, 0.8, 1.0)
                    
                    pygame.draw.circle(glow_surf, (*color, alpha), (radius, radius), radius)
                    screen.blit(glow_surf, 
                              (int(self.paddle_x - radius), int(self.paddle_y - radius)), 
                              special_flags=pygame.BLEND_ADD)
            
            # 신비로운 파티클 효과
            if self.paddle_glow_intensity > 0.3:
                num_particles = int(20 * self.paddle_glow_intensity)
                for i in range(num_particles):
                    # 나선형 파티클 경로
                    particle_angle = (i * 2 * math.pi / num_particles) + time_factor * 0.1
                    particle_radius = 30 + math.sin(time_factor * 0.2 + i) * 20
                    
                    px = self.paddle_x + particle_radius * math.cos(particle_angle)
                    py = self.paddle_y + particle_radius * math.sin(particle_angle) * 0.7  # 타원형
                    
                    # 파티클 크기와 색상
                    particle_size = int(3 + math.sin(time_factor * 0.3 + i) * 2)
                    particle_alpha = int(150 * self.paddle_glow_intensity)
                    
                    # 신비로운 색상 (보라-파랑-하늘색 계열)
                    colors = [(147, 112, 219), (100, 149, 237), (135, 206, 235), (221, 160, 221)]
                    color = colors[i % len(colors)]
                    
                    particle_surf = pygame.Surface((particle_size * 2, particle_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(particle_surf, (*color, particle_alpha), 
                                     (particle_size, particle_size), particle_size)
                    screen.blit(particle_surf, (int(px - particle_size), int(py - particle_size)), 
                              special_flags=pygame.BLEND_ADD)
            
            # 중앙에 밝은 플래시와 십자 빛
            if self.paddle_glow_intensity > 0.7:
                # 중앙 플래시
                flash_surf = pygame.Surface((80, 80), pygame.SRCALPHA)
                flash_alpha = int(220 * self.paddle_glow_intensity)
                pygame.draw.circle(flash_surf, (*self.PURE_WHITE, flash_alpha), (40, 40), 40)
                screen.blit(flash_surf, 
                          (int(self.paddle_x - 40), int(self.paddle_y - 40)), 
                          special_flags=pygame.BLEND_ADD)
                
                # 십자 빛줄기
                line_length = int(200 * self.paddle_glow_intensity)
                line_alpha = int(180 * self.paddle_glow_intensity)
                
                # 가로 빛줄기
                for offset in range(-2, 3):
                    pygame.draw.line(screen, (*self.NEON_GOLD, line_alpha),
                                   (int(self.paddle_x - line_length), int(self.paddle_y + offset)),
                                   (int(self.paddle_x + line_length), int(self.paddle_y + offset)), 1)
                
                # 세로 빛줄기
                for offset in range(-2, 3):
                    pygame.draw.line(screen, (*self.NEON_GOLD, line_alpha),
                                   (int(self.paddle_x + offset), int(self.paddle_y - line_length // 2)),
                                   (int(self.paddle_x + offset), int(self.paddle_y + line_length // 2)), 1)
                
                # 대각선 빛줄기 (X자)
                diagonal_length = int(100 * self.paddle_glow_intensity)
                for offset in range(-1, 2):
                    # 왼쪽 위 -> 오른쪽 아래
                    pygame.draw.line(screen, (*self.PURE_WHITE, line_alpha // 2),
                                   (int(self.paddle_x - diagonal_length + offset), int(self.paddle_y - diagonal_length)),
                                   (int(self.paddle_x + diagonal_length + offset), int(self.paddle_y + diagonal_length)), 1)
                    # 오른쪽 위 -> 왼쪽 아래
                    pygame.draw.line(screen, (*self.PURE_WHITE, line_alpha // 2),
                                   (int(self.paddle_x + diagonal_length + offset), int(self.paddle_y - diagonal_length)),
                                   (int(self.paddle_x - diagonal_length + offset), int(self.paddle_y + diagonal_length)), 1)
            
            # 신성한 룬 문자 회전
            if self.paddle_glow_intensity > 0.5:
                rune_radius = 70
                num_runes = 6
                for i in range(num_runes):
                    rune_angle = (i * 2 * math.pi / num_runes) + time_factor * 0.05
                    rx = self.paddle_x + rune_radius * math.cos(rune_angle)
                    ry = self.paddle_y + rune_radius * math.sin(rune_angle)
                    
                    # 룬 문자 그리기
                    rune_alpha = int(120 * self.paddle_glow_intensity)
                    rune_color = (255, 215, 0, rune_alpha)  # 황금색
                    
                    # 작은 원과 선으로 룬 표현
                    pygame.draw.circle(screen, rune_color[:3], (int(rx), int(ry)), 3, 1)
                    # 중앙으로 연결선
                    pygame.draw.line(screen, (*rune_color[:3], rune_alpha // 2),
                                   (int(rx), int(ry)), 
                                   (int(self.paddle_x), int(self.paddle_y)), 1)
            
            # 빛 파티클 효과
            for i in range(int(10 * self.paddle_glow_intensity)):
                angle = random.random() * math.pi * 2
                distance = random.random() * 60 * self.paddle_glow_intensity
                px = self.paddle_x + math.cos(angle) * distance
                py = self.paddle_y + math.sin(angle) * distance
                particle_alpha = int(150 * self.paddle_glow_intensity)
                pygame.draw.circle(screen, (*self.NEON_GOLD, particle_alpha), (int(px), int(py)), 2)
            
            # 바로크풍 파티클 - 위로 튀어오르는 효과 (0.6초 동안)
            # 바로크 파티클 업데이트 및 렌더링
            if hasattr(self, 'baroque_particles'):
                baroque_colors = [
                    (255, 215, 0),    # 금색
                    (218, 165, 32),   # 골든로드
                    (255, 248, 220),  # 크림색
                    (192, 192, 192)   # 은색
                ]
                
                dt = 16  # 프레임 시간 (약 60fps)
                particles_to_remove = []
                
                for particle in self.baroque_particles:
                    # 파티클 업데이트
                    particle['lifetime'] += dt
                    progress = particle['lifetime'] / particle['max_lifetime']
                    
                    if progress >= 1.0:
                        particles_to_remove.append(particle)
                        continue
                    
                    # 물리 업데이트
                    particle['x'] += particle['vx']
                    particle['y'] += particle['vy']
                    particle['vy'] += 0.15  # 중력 효과
                    particle['rotation'] += particle['rotation_speed']
                    
                    # 페이드 효과
                    alpha = int(180 * self.paddle_glow_intensity * (1 - progress))
                    if alpha <= 0:
                        continue
                    
                    # 바로크 패턴 그리기
                    px, py = int(particle['x']), int(particle['y'])
                    size = particle['size']
                    color = baroque_colors[particle['color_index']]
                    
                    # 파티클 타입에 따른 렌더링
                    if particle['type'] == 'fleur':
                        # 플뢰르 드 리스 (백합 문양)
                        for j in range(3):
                            petal_angle = particle['rotation'] + (j * 2 * math.pi / 3)
                            petal_x = px + size * math.cos(petal_angle)
                            petal_y = py + size * math.sin(petal_angle)
                            pygame.draw.circle(screen, color, (int(petal_x), int(petal_y)), size // 2)
                        pygame.draw.circle(screen, color, (px, py), size // 3)
                        
                    elif particle['type'] == 'acanthus':
                        # 아칸서스 잎 문양
                        num_leaves = 5
                        for j in range(num_leaves):
                            leaf_angle = particle['rotation'] + (j * 2 * math.pi / num_leaves)
                            for k in range(3):
                                leaf_radius = size * (1 - k * 0.3)
                                leaf_x = px + leaf_radius * math.cos(leaf_angle)
                                leaf_y = py + leaf_radius * math.sin(leaf_angle)
                                pygame.draw.circle(screen, color, (int(leaf_x), int(leaf_y)), max(1, size // 4))
                        
                    elif particle['type'] == 'rosette':
                        # 로제트 (장미 문양)
                        num_petals = 8
                        for j in range(num_petals):
                            petal_angle = particle['rotation'] + (j * 2 * math.pi / num_petals)
                            petal_x = px + size * 0.7 * math.cos(petal_angle)
                            petal_y = py + size * 0.7 * math.sin(petal_angle)
                            
                            # 꽃잎 그리기
                            petal_points = []
                            for t in range(5):
                                t_norm = t / 4.0
                                curve_x = px * (1 - t_norm) + petal_x * t_norm
                                curve_y = py * (1 - t_norm) + petal_y * t_norm
                                offset = math.sin(t_norm * math.pi) * size * 0.3
                                curve_x += offset * math.cos(petal_angle + math.pi/2)
                                curve_y += offset * math.sin(petal_angle + math.pi/2)
                                petal_points.append((int(curve_x), int(curve_y)))
                            
                            if len(petal_points) > 1:
                                pygame.draw.lines(screen, color, False, petal_points, 1)
                        
                        # 중심 장식
                        pygame.draw.circle(screen, color, (px, py), max(1, size // 3))
                        
                    elif particle['type'] == 'scroll':
                        # 스크롤 (소용돌이) 문양
                        spiral_points = []
                        for t in range(20):
                            t_norm = t / 19.0
                            spiral_radius = size * t_norm
                            spiral_angle = particle['rotation'] + t_norm * math.pi * 2
                            spiral_x = px + spiral_radius * math.cos(spiral_angle)
                            spiral_y = py + spiral_radius * math.sin(spiral_angle)
                            spiral_points.append((int(spiral_x), int(spiral_y)))
                        
                        if len(spiral_points) > 1:
                            pygame.draw.lines(screen, color, False, spiral_points, 1)
                        
                        # 끝 장식
                        pygame.draw.circle(screen, color, spiral_points[-1] if spiral_points else (px, py), 2)
                
                # 제거할 파티클 삭제
                for particle in particles_to_remove:
                    self.baroque_particles.remove(particle)
                
                # 새 파티클 생성 (지속적으로)
                if self.paddle_glow_intensity > 0.3 and len(self.baroque_particles) < 30:
                    if random.random() < 0.3:  # 30% 확률로 새 파티클 생성
                        self.baroque_particles.append({
                            'x': self.paddle_x + random.randint(-40, 40),
                            'y': self.paddle_y + random.randint(-10, 10),
                            'vx': random.uniform(-2, 2),
                            'vy': random.uniform(-10, -4),
                            'size': random.randint(4, 10),
                            'rotation': random.uniform(0, math.pi * 2),
                            'rotation_speed': random.uniform(-0.15, 0.15),
                            'type': random.choice(['fleur', 'acanthus', 'rosette', 'scroll']),
                            'color_index': random.randint(0, 3),
                            'lifetime': 0,
                            'max_lifetime': random.uniform(400, 600)
                        })
            
    def is_active(self) -> bool:
        """애니메이션이 활성 상태인지 확인"""
        return self.active
        
    def should_pause_game(self) -> bool:
        """게임을 일시정지해야 하는지 확인"""
        return self.active
        
    def handle_space_press(self):
        """스페이스바 입력 처리 - 블랙홀 애니메이션 시작"""
        # 페이즈 2(아이템 표시)에서만 스킵 가능
        if self.phase == 2 and self.phase_timer > 500:  # 0.5초 후부터 스킵 가능
            if self.black_hole_phase == 0:
                # legendending.wav 재생 (legendspacebar.wav 대신)
                if hasattr(self, 'legendending_sound') and self.legendending_sound is not None:
                    try:
                        self.legendending_sound.play()
                        print("🔊 legendending.wav 사운드 재생 성공")
                    except Exception as e:
                        print(f"❌ legendending.wav 재생 실패: {e}")
                else:
                    print("⚠️ legendending_sound가 로드되지 않았습니다")
                
                # legendafter.wav는 1.5초 후에 종료하도록 타이머 설정
                if hasattr(self, 'legendafter_sound') and self.legendafter_sound is not None:
                    self.legendafter_fade_timer = self.legendafter_fade_duration
                    print("⏱️ legendafter.wav 1.5초 후 종료 예정")
                
                # 블랙홀 애니메이션 시작
                self.black_hole_phase = 1
                self.black_hole_timer = 0
                return True
            return False
        return False
