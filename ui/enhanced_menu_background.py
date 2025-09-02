"""
울트라 고급 사이버펑크 메인 메뉴 배경 - 향상된 파티클 효과와 디테일
"""
import pygame
import math
import random
from typing import List, Tuple, Dict, Any
from ui.simple_menu_background import SimpleMenuBackground

class EnhancedMenuBackground(SimpleMenuBackground):
    """초고급 파티클 효과와 디테일이 추가된 메뉴 배경"""
    
    def __init__(self, width: int, height: int):
        super().__init__(width, height)
        
        # 추가 파티클 시스템들
        self.cosmic_dust = []           # 우주 먼지
        self.shooting_stars = []        # 별똥별
        self.comets = []                # 혜성
        self.asteroids = []             # 소행성
        self.nebula_particles = []      # 성운 입자
        self.energy_fields = []         # 에너지 필드
        self.satellite_debris = []      # 위성 파편
        self.aurora_particles = []      # 오로라 입자
        self.solar_winds = []           # 태양풍
        self.quantum_particles = []     # 양자 입자
        self.crystalline_shards = []    # 수정 조각
        self.plasma_streams = []        # 플라즈마 흐름
        self.gravitational_waves = []   # 중력파
        self.light_beams = []           # 빛줄기
        self.energy_orbs = []           # 에너지 구체
        
        # 초기화
        self._init_cosmic_dust()
        self._init_shooting_stars()
        self._init_comets()
        self._init_asteroids()
        self._init_nebula()
        self._init_energy_fields()
        self._init_satellites()
        self._init_aurora()
        self._init_solar_winds()
        self._init_quantum_particles()
        self._init_crystalline_shards()
        self._init_plasma_streams()
        self._init_light_beams()
        self._init_energy_orbs()
        
        # 행성별 추가 장식
        self._enhance_planets()
        
    def _init_cosmic_dust(self):
        """우주 먼지 초기화 - 수천 개의 미세 입자"""
        for _ in range(500):
            self.cosmic_dust.append({
                'x': random.randint(0, self.width),
                'y': random.randint(0, self.height),
                'z': random.uniform(0.1, 1.0),  # 깊이
                'vx': random.uniform(-0.05, 0.05),
                'vy': random.uniform(-0.05, 0.05),
                'size': random.uniform(0.5, 2),
                'brightness': random.uniform(0.3, 1.0),
                'color': random.choice([
                    (200, 200, 255),  # 파란빛
                    (255, 200, 200),  # 붉은빛
                    (255, 255, 200),  # 노란빛
                    (200, 255, 200),  # 초록빛
                ]),
                'twinkle': random.uniform(0, math.pi * 2)
            })
    
    def _init_shooting_stars(self):
        """별똥별 초기화"""
        for _ in range(3):
            self.shooting_stars.append({
                'x': random.randint(-100, self.width + 100),
                'y': random.randint(-100, 200),
                'vx': random.uniform(3, 8),
                'vy': random.uniform(1, 3),
                'length': random.randint(30, 80),
                'life': random.randint(60, 120),
                'max_life': random.randint(60, 120),
                'trail': [],
                'color': (255, 255, 200),
                'active': random.random() < 0.3
            })
    
    def _init_comets(self):
        """혜성 초기화"""
        self.comets.append({
            'x': -50,
            'y': random.randint(100, 300),
            'vx': 0.5,
            'vy': 0.1,
            'radius': 5,
            'tail_particles': [],
            'angle': 0,
            'active': True
        })
    
    def _init_asteroids(self):
        """소행성 초기화"""
        for _ in range(8):
            self.asteroids.append({
                'x': random.randint(0, self.width),
                'y': random.randint(0, self.height),
                'vx': random.uniform(-0.2, 0.2),
                'vy': random.uniform(-0.2, 0.2),
                'rotation': random.uniform(0, math.pi * 2),
                'rotation_speed': random.uniform(-0.02, 0.02),
                'size': random.randint(3, 8),
                'vertices': self._generate_asteroid_shape(random.randint(5, 8)),
                'color': (random.randint(100, 150), random.randint(100, 150), random.randint(100, 150))
            })
    
    def _generate_asteroid_shape(self, num_vertices: int) -> List[Tuple[float, float]]:
        """소행성 모양 생성"""
        vertices = []
        for i in range(num_vertices):
            angle = (math.pi * 2 / num_vertices) * i
            radius = random.uniform(0.7, 1.3)
            vertices.append((math.cos(angle) * radius, math.sin(angle) * radius))
        return vertices
    
    def _init_nebula(self):
        """성운 입자 초기화"""
        # 중심부 성운
        center_x = self.width // 2
        center_y = self.height // 2
        for _ in range(200):
            angle = random.uniform(0, math.pi * 2)
            distance = random.uniform(150, 400)
            self.nebula_particles.append({
                'x': center_x + math.cos(angle) * distance,
                'y': center_y + math.sin(angle) * distance,
                'vx': random.uniform(-0.02, 0.02),
                'vy': random.uniform(-0.02, 0.02),
                'size': random.uniform(1, 4),
                'color': random.choice([
                    (255, 100, 150, 30),  # 핑크
                    (100, 150, 255, 30),  # 파랑
                    (150, 100, 255, 30),  # 보라
                    (100, 255, 150, 30),  # 청록
                ]),
                'pulse': random.uniform(0, math.pi * 2)
            })
    
    def _init_energy_fields(self):
        """에너지 필드 초기화"""
        for planet in self.planets:
            if planet['type'] in ['sun', 'earth', 'jupiter', 'saturn']:
                self.energy_fields.append({
                    'planet': planet,
                    'radius': planet['radius'] * 1.5,
                    'rotation': 0,
                    'particles': [],
                    'color': planet.get('glow_color', (100, 200, 255))
                })
                
                # 에너지 필드 파티클 생성
                for _ in range(50):
                    angle = random.uniform(0, math.pi * 2)
                    self.energy_fields[-1]['particles'].append({
                        'angle': angle,
                        'distance': random.uniform(0.8, 1.2),
                        'speed': random.uniform(0.01, 0.03),
                        'size': random.uniform(1, 3),
                        'brightness': random.uniform(0.5, 1.0)
                    })
    
    def _init_satellites(self):
        """위성 파편 초기화"""
        for planet in self.planets:
            if planet['type'] in ['earth', 'mars', 'jupiter']:
                # 각 행성에 작은 위성들 추가
                num_satellites = random.randint(1, 3)
                for _ in range(num_satellites):
                    self.satellite_debris.append({
                        'parent': planet,
                        'orbit_radius': planet['radius'] + random.randint(20, 40),
                        'orbit_speed': random.uniform(0.02, 0.05),
                        'orbit_angle': random.uniform(0, math.pi * 2),
                        'size': random.randint(2, 4),
                        'color': (random.randint(150, 200), random.randint(150, 200), random.randint(150, 200))
                    })
    
    def _init_aurora(self):
        """오로라 입자 초기화"""
        # 지구와 목성 주변에 오로라 효과
        for planet in self.planets:
            if planet['type'] in ['earth', 'jupiter']:
                for _ in range(100):
                    self.aurora_particles.append({
                        'planet': planet,
                        'offset_angle': random.uniform(0, math.pi * 2),
                        'height': random.uniform(1.2, 1.8),
                        'wave_phase': random.uniform(0, math.pi * 2),
                        'color': random.choice([
                            (100, 255, 150),  # 초록
                            (150, 100, 255),  # 보라
                            (100, 150, 255),  # 파랑
                            (255, 100, 150),  # 핑크
                        ]),
                        'alpha': random.randint(20, 60)
                    })
    
    def _init_solar_winds(self):
        """태양풍 초기화"""
        # 태양에서 방출되는 입자들
        sun = next((p for p in self.planets if p['type'] == 'sun'), None)
        if sun:
            for _ in range(150):
                angle = random.uniform(0, math.pi * 2)
                self.solar_winds.append({
                    'x': sun['x'],
                    'y': sun['y'],
                    'angle': angle,
                    'speed': random.uniform(0.5, 2),
                    'distance': 0,
                    'max_distance': random.uniform(200, 400),
                    'size': random.uniform(1, 3),
                    'color': (255, random.randint(150, 200), random.randint(50, 100)),
                    'life': 1.0
                })
    
    def _init_quantum_particles(self):
        """양자 입자 초기화 - 텔레포트하는 입자들"""
        for _ in range(30):
            self.quantum_particles.append({
                'x': random.randint(0, self.width),
                'y': random.randint(0, self.height),
                'target_x': random.randint(0, self.width),
                'target_y': random.randint(0, self.height),
                'teleport_timer': random.randint(30, 90),
                'size': random.uniform(1, 3),
                'color': (random.randint(150, 255), random.randint(150, 255), 255),
                'trail': []
            })
    
    def _init_crystalline_shards(self):
        """수정 조각 초기화 - 반짝이는 결정체"""
        for _ in range(20):
            self.crystalline_shards.append({
                'x': random.randint(0, self.width),
                'y': random.randint(0, self.height),
                'vx': random.uniform(-0.1, 0.1),
                'vy': random.uniform(-0.1, 0.1),
                'rotation': random.uniform(0, math.pi * 2),
                'rotation_speed': random.uniform(-0.02, 0.02),
                'size': random.randint(5, 15),
                'color': random.choice([
                    (255, 200, 255),  # 핑크
                    (200, 255, 255),  # 시안
                    (255, 255, 200),  # 노랑
                    (200, 200, 255),  # 라벤더
                ]),
                'sparkle': random.uniform(0, math.pi * 2),
                'facets': self._generate_crystal_facets()
            })
    
    def _generate_crystal_facets(self) -> List[Dict]:
        """수정 면 생성"""
        facets = []
        for _ in range(random.randint(3, 6)):
            facets.append({
                'angle': random.uniform(0, math.pi * 2),
                'length': random.uniform(0.5, 1.0),
                'brightness': random.uniform(0.5, 1.0)
            })
        return facets
    
    def _init_plasma_streams(self):
        """플라즈마 흐름 초기화"""
        # 태양 주변 플라즈마 스트림
        sun = next((p for p in self.planets if p['type'] == 'sun'), None)
        if sun:
            for _ in range(8):
                self.plasma_streams.append({
                    'start_angle': random.uniform(0, math.pi * 2),
                    'end_angle': random.uniform(0, math.pi * 2),
                    'phase': random.uniform(0, math.pi * 2),
                    'amplitude': random.uniform(20, 50),
                    'frequency': random.uniform(0.01, 0.03),
                    'color': (255, random.randint(100, 200), random.randint(0, 100)),
                    'particles': []
                })
    
    def _init_light_beams(self):
        """빛줄기 초기화"""
        # 태양에서 나오는 빛줄기
        sun = next((p for p in self.planets if p['type'] == 'sun'), None)
        if sun:
            for _ in range(6):
                angle = random.uniform(0, math.pi * 2)
                self.light_beams.append({
                    'angle': angle,
                    'length': random.uniform(300, 500),
                    'width': random.uniform(2, 8),
                    'pulse': random.uniform(0, math.pi * 2),
                    'color': (255, 255, random.randint(200, 255)),
                    'alpha': random.randint(20, 50)
                })
    
    def _init_energy_orbs(self):
        """에너지 구체 초기화"""
        for _ in range(10):
            self.energy_orbs.append({
                'x': random.randint(0, self.width),
                'y': random.randint(0, self.height),
                'vx': random.uniform(-0.5, 0.5),
                'vy': random.uniform(-0.5, 0.5),
                'radius': random.uniform(3, 8),
                'pulse': random.uniform(0, math.pi * 2),
                'color': random.choice([
                    (100, 200, 255),  # 파랑
                    (255, 100, 200),  # 핑크
                    (200, 255, 100),  # 라임
                    (255, 200, 100),  # 주황
                ]),
                'energy_rings': []
            })
            
            # 에너지 링 생성
            for i in range(3):
                self.energy_orbs[-1]['energy_rings'].append({
                    'radius': (i + 1) * 5,
                    'rotation': random.uniform(0, math.pi * 2),
                    'speed': random.uniform(-0.02, 0.02) * (i + 1)
                })
    
    def _enhance_planets(self):
        """행성별 추가 장식 효과"""
        for planet in self.planets:
            # 행성 주변 입자 고리
            planet['particle_ring'] = []
            if planet['type'] in ['earth', 'mars', 'jupiter', 'saturn']:
                for _ in range(30):
                    planet['particle_ring'].append({
                        'angle': random.uniform(0, math.pi * 2),
                        'distance': random.uniform(1.3, 1.8),
                        'speed': random.uniform(0.01, 0.03),
                        'size': random.uniform(1, 2),
                        'color': planet.get('glow_color', (200, 200, 255))
                    })
            
            # 회전하는 고리 추가 (토성, 목성, 지구 등)
            if planet['type'] in ['saturn', 'jupiter', 'earth']:
                planet['rotating_rings'] = []
                ring_count = 3 if planet['type'] == 'saturn' else 2
                for i in range(ring_count):
                    planet['rotating_rings'].append({
                        'radius': planet['radius'] * (1.5 + i * 0.3),
                        'width': random.uniform(3, 8),
                        'rotation': random.uniform(0, math.pi * 2),
                        'rotation_speed': random.uniform(0.01, 0.03) * (1 if random.random() > 0.5 else -1),
                        'tilt': random.uniform(-0.3, 0.3),  # 기울기
                        'color': self._get_ring_color(planet['type']),
                        'particles': self._create_ring_particles(planet['radius'] * (1.5 + i * 0.3))
                    })
            
            # 에너지 펄스
            planet['energy_pulse'] = {
                'active': planet['type'] in ['sun', 'jupiter', 'earth'],
                'phase': random.uniform(0, math.pi * 2),
                'frequency': random.uniform(0.02, 0.05),
                'amplitude': random.uniform(5, 15)
            }
            
            # 홀로그램 정보
            planet['hologram'] = {
                'show': False,
                'alpha': 0,
                'target_alpha': 0
            }
    
    def _get_ring_color(self, planet_type: str) -> Tuple[int, int, int, int]:
        """행성 타입에 따른 고리 색상 반환"""
        colors = {
            'saturn': (220, 200, 170, 120),  # 황금색
            'jupiter': (200, 150, 100, 100),  # 갈색
            'earth': (150, 200, 255, 80),    # 하늘색
        }
        return colors.get(planet_type, (200, 200, 200, 100))
    
    def _create_ring_particles(self, radius: float) -> List[Dict]:
        """고리 파티클 생성"""
        particles = []
        for _ in range(20):
            particles.append({
                'angle': random.uniform(0, math.pi * 2),
                'offset': random.uniform(-5, 5),
                'size': random.uniform(1, 3),
                'brightness': random.uniform(0.5, 1.0)
            })
        return particles
    
    def update(self, dt: float):
        """업데이트"""
        super().update(dt)
        
        # 우주 먼지 업데이트
        for dust in self.cosmic_dust:
            dust['x'] += dust['vx'] * dust['z']
            dust['y'] += dust['vy'] * dust['z']
            dust['twinkle'] += 0.1
            
            # 화면 순환
            if dust['x'] < 0: dust['x'] = self.width
            elif dust['x'] > self.width: dust['x'] = 0
            if dust['y'] < 0: dust['y'] = self.height
            elif dust['y'] > self.height: dust['y'] = 0
        
        # 별똥별 업데이트
        for star in self.shooting_stars:
            if star['active']:
                star['x'] += star['vx']
                star['y'] += star['vy']
                star['life'] -= 1
                
                # 궤적 추가
                star['trail'].append((star['x'], star['y']))
                if len(star['trail']) > star['length']:
                    star['trail'].pop(0)
                
                # 재생성
                if star['life'] <= 0 or star['x'] > self.width + 100 or star['y'] > self.height:
                    star['x'] = random.randint(-100, 0)
                    star['y'] = random.randint(-100, 200)
                    star['life'] = star['max_life']
                    star['trail'] = []
                    star['active'] = random.random() < 0.1
            else:
                # 비활성 상태에서 가끔 활성화
                if random.random() < 0.002:
                    star['active'] = True
        
        # 혜성 업데이트
        for comet in self.comets:
            if comet['active']:
                comet['x'] += comet['vx']
                comet['y'] += comet['vy']
                comet['angle'] += 0.02
                
                # 꼬리 입자 생성
                for _ in range(3):
                    comet['tail_particles'].append({
                        'x': comet['x'],
                        'y': comet['y'],
                        'vx': -comet['vx'] * random.uniform(0.5, 1.5) + random.uniform(-0.5, 0.5),
                        'vy': -comet['vy'] * random.uniform(0.5, 1.5) + random.uniform(-0.5, 0.5),
                        'life': 60,
                        'size': random.uniform(1, 3)
                    })
                
                # 꼬리 입자 업데이트
                for particle in comet['tail_particles'][:]:
                    particle['x'] += particle['vx']
                    particle['y'] += particle['vy']
                    particle['life'] -= 1
                    if particle['life'] <= 0:
                        comet['tail_particles'].remove(particle)
                
                # 재생성
                if comet['x'] > self.width + 100:
                    comet['x'] = -50
                    comet['y'] = random.randint(100, 300)
                    comet['tail_particles'] = []
        
        # 소행성 업데이트
        for asteroid in self.asteroids:
            asteroid['x'] += asteroid['vx']
            asteroid['y'] += asteroid['vy']
            asteroid['rotation'] += asteroid['rotation_speed']
            
            # 화면 순환
            if asteroid['x'] < -20: asteroid['x'] = self.width + 20
            elif asteroid['x'] > self.width + 20: asteroid['x'] = -20
            if asteroid['y'] < -20: asteroid['y'] = self.height + 20
            elif asteroid['y'] > self.height + 20: asteroid['y'] = -20
        
        # 에너지 필드 업데이트
        for field in self.energy_fields:
            field['rotation'] += 0.01
            planet = field['planet']
            
            # 파티클 업데이트
            for particle in field['particles']:
                particle['angle'] += particle['speed']
                particle['brightness'] = 0.5 + math.sin(self.time * 3 + particle['angle']) * 0.5
        
        # 위성 업데이트
        for satellite in self.satellite_debris:
            satellite['orbit_angle'] += satellite['orbit_speed']
            parent = satellite['parent']
            satellite['x'] = parent.get('x', self.width // 2) + math.cos(satellite['orbit_angle']) * satellite['orbit_radius']
            satellite['y'] = parent.get('y', self.height // 2) + math.sin(satellite['orbit_angle']) * satellite['orbit_radius'] * 0.5
        
        # 오로라 업데이트
        for aurora in self.aurora_particles:
            aurora['wave_phase'] += 0.03
        
        # 태양풍 업데이트
        sun = next((p for p in self.planets if p['type'] == 'sun'), None)
        if sun:
            for wind in self.solar_winds[:]:
                wind['distance'] += wind['speed']
                wind['x'] = sun['x'] + math.cos(wind['angle']) * wind['distance']
                wind['y'] = sun['y'] + math.sin(wind['angle']) * wind['distance']
                wind['life'] = 1.0 - (wind['distance'] / wind['max_distance'])
                
                if wind['distance'] >= wind['max_distance']:
                    # 재생성
                    wind['distance'] = 0
                    wind['angle'] = random.uniform(0, math.pi * 2)
                    wind['x'] = sun['x']
                    wind['y'] = sun['y']
        
        # 양자 입자 업데이트
        for quantum in self.quantum_particles:
            quantum['teleport_timer'] -= 1
            
            # 궤적 추가
            quantum['trail'].append((quantum['x'], quantum['y']))
            if len(quantum['trail']) > 10:
                quantum['trail'].pop(0)
            
            if quantum['teleport_timer'] <= 0:
                # 텔레포트
                quantum['x'] = quantum['target_x']
                quantum['y'] = quantum['target_y']
                quantum['target_x'] = random.randint(0, self.width)
                quantum['target_y'] = random.randint(0, self.height)
                quantum['teleport_timer'] = random.randint(30, 90)
                quantum['trail'] = []
            else:
                # 목표로 이동
                dx = quantum['target_x'] - quantum['x']
                dy = quantum['target_y'] - quantum['y']
                quantum['x'] += dx * 0.05
                quantum['y'] += dy * 0.05
        
        # 수정 조각 업데이트
        for crystal in self.crystalline_shards:
            crystal['x'] += crystal['vx']
            crystal['y'] += crystal['vy']
            crystal['rotation'] += crystal['rotation_speed']
            crystal['sparkle'] += 0.1
            
            # 화면 순환
            if crystal['x'] < 0: crystal['x'] = self.width
            elif crystal['x'] > self.width: crystal['x'] = 0
            if crystal['y'] < 0: crystal['y'] = self.height
            elif crystal['y'] > self.height: crystal['y'] = 0
        
        # 에너지 구체 업데이트
        for orb in self.energy_orbs:
            orb['x'] += orb['vx']
            orb['y'] += orb['vy']
            orb['pulse'] += 0.05
            
            # 화면 순환
            if orb['x'] < -10: orb['x'] = self.width + 10
            elif orb['x'] > self.width + 10: orb['x'] = -10
            if orb['y'] < -10: orb['y'] = self.height + 10
            elif orb['y'] > self.height + 10: orb['y'] = -10
            
            # 에너지 링 회전
            for ring in orb['energy_rings']:
                ring['rotation'] += ring['speed']
        
        # 행성 추가 효과 업데이트
        for planet in self.planets:
            # 입자 고리 업데이트
            if 'particle_ring' in planet:
                for particle in planet['particle_ring']:
                    particle['angle'] += particle['speed']
            
            # 회전하는 고리 업데이트
            if 'rotating_rings' in planet:
                for ring in planet['rotating_rings']:
                    ring['rotation'] += ring['rotation_speed']
                    # 고리 파티클 업데이트
                    for particle in ring['particles']:
                        particle['angle'] += ring['rotation_speed'] * 0.5
                        particle['brightness'] = 0.5 + math.sin(self.time * 2 + particle['angle']) * 0.5
            
            # 에너지 펄스 업데이트
            if 'energy_pulse' in planet and planet['energy_pulse']['active']:
                planet['energy_pulse']['phase'] += planet['energy_pulse']['frequency']
    
    def draw(self, surface: pygame.Surface):
        """그리기"""
        # 임시 서페이스에 부모 클래스 그리기
        temp_surface = pygame.Surface((self.width, self.height))
        super().draw(temp_surface)
        
        # 배경과 별만 그리기 (행성은 제외하고 다시 그릴 예정)
        surface.blit(temp_surface, (0, 0))
        
        # 성운과 우주 먼지
        self._draw_nebula(surface)
        self._draw_cosmic_dust(surface)
        
        # 행성들 그리기 (고리 레이어링 포함)
        for planet in self.planets:
            x = planet.get('x', self.width // 2)
            y = planet.get('y', self.height // 2)
            
            # 회전하는 고리 뒤쪽 부분
            if 'rotating_rings' in planet:
                for ring in planet['rotating_rings']:
                    self._draw_rotating_ring_back(surface, x, y, ring, planet['radius'])
            
            # 행성 본체 그리기
            self._draw_planet_body(surface, planet)
            
            # 회전하는 고리 앞쪽 부분
            if 'rotating_rings' in planet:
                for ring in planet['rotating_rings']:
                    self._draw_rotating_ring_front(surface, x, y, ring, planet['radius'])
        
        # 추가 효과들
        self._draw_crystalline_shards(surface)
        self._draw_energy_orbs(surface)
        self._draw_asteroids(surface)
        self._draw_satellite_debris(surface)
        self._draw_planet_enhancements(surface)
        self._draw_energy_fields(surface)
        self._draw_aurora(surface)
        self._draw_solar_winds(surface)
        self._draw_light_beams(surface)
        self._draw_quantum_particles(surface)
        self._draw_shooting_stars(surface)
        self._draw_comets(surface)
    
    def _draw_planet_body(self, surface: pygame.Surface, planet: Dict):
        """행성 본체만 그리기 (부모 클래스의 행성 그리기 로직 사용)"""
        x = planet.get('x', self.width // 2)
        y = planet.get('y', self.height // 2)
        
        # 간단한 행성 그리기 (상세한 렌더링은 부모 클래스에서 처리)
        if planet['type'] == 'sun':
            # 태양 그리기
            for i in range(int(planet['radius'])):
                alpha = int(255 * (1 - i / planet['radius']))
                color = (min(255, planet['color'][0] + i),
                        min(255, planet['color'][1]),
                        planet['color'][2])
                pygame.draw.circle(surface, color, (int(x), int(y)), 
                                 int(planet['radius'] - i))
        else:
            # 일반 행성 그리기
            pygame.draw.circle(surface, planet['color'], 
                             (int(x), int(y)), 
                             int(planet['radius']))
    
    def _draw_nebula(self, surface: pygame.Surface):
        """성운 그리기"""
        nebula_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        for particle in self.nebula_particles:
            # 펄스 효과
            pulse = math.sin(particle['pulse'] + self.time * 2) * 0.3 + 0.7
            size = particle['size'] * pulse
            
            # 부드러운 그라데이션
            for i in range(int(size * 3)):
                alpha = particle['color'][3] * (1 - i / (size * 3))
                color = (*particle['color'][:3], int(alpha))
                pygame.draw.circle(nebula_surf, color,
                                 (int(particle['x']), int(particle['y'])),
                                 int(size * 3 - i))
        
        surface.blit(nebula_surf, (0, 0))
    
    def _draw_cosmic_dust(self, surface: pygame.Surface):
        """우주 먼지 그리기"""
        for dust in self.cosmic_dust:
            # 반짝임 효과
            twinkle = math.sin(dust['twinkle']) * 0.5 + 0.5
            brightness = dust['brightness'] * twinkle
            
            # 깊이에 따른 크기와 밝기
            size = dust['size'] * dust['z']
            alpha = int(brightness * 255 * dust['z'])
            
            if alpha > 0:
                color = (*dust['color'], alpha)
                # 글로우 효과
                glow_surf = pygame.Surface((int(size * 4), int(size * 4)), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, color, (int(size * 2), int(size * 2)), int(size))
                surface.blit(glow_surf, (dust['x'] - size * 2, dust['y'] - size * 2))
    
    def _draw_shooting_stars(self, surface: pygame.Surface):
        """별똥별 그리기"""
        for star in self.shooting_stars:
            if star['active'] and len(star['trail']) > 1:
                # 궤적 그리기
                trail_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
                for i in range(len(star['trail']) - 1):
                    alpha = int(255 * (i / len(star['trail'])) * (star['life'] / star['max_life']))
                    if alpha > 0:
                        start = star['trail'][i]
                        end = star['trail'][i + 1]
                        # 그라데이션 선
                        for j in range(3):
                            line_alpha = alpha - j * 50
                            if line_alpha > 0:
                                pygame.draw.line(trail_surf, (*star['color'], line_alpha),
                                               start, end, 3 - j)
                surface.blit(trail_surf, (0, 0))
                
                # 머리 부분 밝은 빛
                if star['life'] > 0:
                    head_glow = pygame.Surface((20, 20), pygame.SRCALPHA)
                    pygame.draw.circle(head_glow, (*star['color'], 150), (10, 10), 8)
                    surface.blit(head_glow, (star['x'] - 10, star['y'] - 10))
    
    def _draw_comets(self, surface: pygame.Surface):
        """혜성 그리기"""
        for comet in self.comets:
            if comet['active']:
                comet_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
                
                # 혜성 꼬리
                for particle in comet['tail_particles']:
                    alpha = int(100 * (particle['life'] / 60))
                    if alpha > 0:
                        pygame.draw.circle(comet_surf, (200, 200, 255, alpha),
                                         (int(particle['x']), int(particle['y'])),
                                         int(particle['size']))
                
                # 혜성 본체
                # 글로우
                for i in range(3):
                    glow_radius = comet['radius'] + i * 3
                    glow_alpha = 60 - i * 20
                    if glow_alpha > 0:
                        pygame.draw.circle(comet_surf, (100, 200, 255, glow_alpha),
                                         (int(comet['x']), int(comet['y'])),
                                         glow_radius)
                
                surface.blit(comet_surf, (0, 0))
                
                # 중심 (불투명하므로 직접 그리기)
                pygame.draw.circle(surface, (255, 255, 255),
                                 (int(comet['x']), int(comet['y'])),
                                 comet['radius'])
    
    def _draw_asteroids(self, surface: pygame.Surface):
        """소행성 그리기"""
        for asteroid in self.asteroids:
            # 변환된 정점 계산
            points = []
            for vertex in asteroid['vertices']:
                # 회전 변환
                x = vertex[0] * math.cos(asteroid['rotation']) - vertex[1] * math.sin(asteroid['rotation'])
                y = vertex[0] * math.sin(asteroid['rotation']) + vertex[1] * math.cos(asteroid['rotation'])
                # 크기와 위치 적용
                x = asteroid['x'] + x * asteroid['size']
                y = asteroid['y'] + y * asteroid['size']
                points.append((int(x), int(y)))
            
            if len(points) >= 3:
                # 소행성 본체
                pygame.draw.polygon(surface, asteroid['color'], points)
                # 테두리
                pygame.draw.polygon(surface, 
                                  (min(255, asteroid['color'][0] + 50),
                                   min(255, asteroid['color'][1] + 50),
                                   min(255, asteroid['color'][2] + 50)),
                                  points, 1)
    
    def _draw_energy_fields(self, surface: pygame.Surface):
        """에너지 필드 그리기"""
        for field in self.energy_fields:
            planet = field['planet']
            x = planet.get('x', self.width // 2)
            y = planet.get('y', self.height // 2)
            
            field_surf = pygame.Surface((int(field['radius'] * 3), int(field['radius'] * 3)), pygame.SRCALPHA)
            
            # 에너지 파티클
            for particle in field['particles']:
                px = field['radius'] * 1.5 + math.cos(particle['angle'] + field['rotation']) * field['radius'] * particle['distance']
                py = field['radius'] * 1.5 + math.sin(particle['angle'] + field['rotation']) * field['radius'] * particle['distance'] * 0.5
                
                alpha = int(particle['brightness'] * 100)
                if alpha > 0:
                    pygame.draw.circle(field_surf, (*field['color'], alpha),
                                     (int(px), int(py)), int(particle['size']))
            
            surface.blit(field_surf, (int(x - field['radius'] * 1.5), int(y - field['radius'] * 1.5)))
    
    def _draw_satellite_debris(self, surface: pygame.Surface):
        """위성 파편 그리기"""
        for satellite in self.satellite_debris:
            if 'x' in satellite and 'y' in satellite:
                # 위성 본체
                pygame.draw.circle(surface, satellite['color'],
                                 (int(satellite['x']), int(satellite['y'])),
                                 satellite['size'])
                
                # 작은 글로우
                pygame.draw.circle(surface, (*satellite['color'], 50),
                                 (int(satellite['x']), int(satellite['y'])),
                                 satellite['size'] + 2)
    
    def _draw_aurora(self, surface: pygame.Surface):
        """오로라 그리기"""
        aurora_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        for aurora in self.aurora_particles:
            planet = aurora['planet']
            x = planet.get('x', self.width // 2)
            y = planet.get('y', self.height // 2)
            
            # 웨이브 형태의 오로라
            wave_offset = math.sin(aurora['wave_phase']) * 10
            ax = x + math.cos(aurora['offset_angle']) * planet['radius'] * aurora['height'] + wave_offset
            ay = y + math.sin(aurora['offset_angle']) * planet['radius'] * aurora['height'] * 0.5
            
            # 부드러운 그라데이션
            for i in range(5):
                alpha = aurora['alpha'] - i * 10
                if alpha > 0:
                    size = 5 - i
                    pygame.draw.circle(aurora_surf, (*aurora['color'], alpha),
                                     (int(ax), int(ay)), size)
        
        surface.blit(aurora_surf, (0, 0))
    
    def _draw_solar_winds(self, surface: pygame.Surface):
        """태양풍 그리기"""
        wind_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        for wind in self.solar_winds:
            if wind['life'] > 0:
                alpha = int(wind['life'] * 100)
                color = (*wind['color'], alpha)
                pygame.draw.circle(wind_surf, color,
                                 (int(wind['x']), int(wind['y'])),
                                 int(wind['size']))
        
        surface.blit(wind_surf, (0, 0))
    
    def _draw_light_beams(self, surface: pygame.Surface):
        """빛줄기 그리기"""
        sun = next((p for p in self.planets if p['type'] == 'sun'), None)
        if not sun:
            return
        
        beam_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        for beam in self.light_beams:
            # 펄스 효과
            pulse = math.sin(beam['pulse'] + self.time * 2) * 0.3 + 0.7
            alpha = int(beam['alpha'] * pulse)
            
            if alpha > 0:
                # 빛줄기 끝점
                end_x = sun['x'] + math.cos(beam['angle']) * beam['length']
                end_y = sun['y'] + math.sin(beam['angle']) * beam['length']
                
                # 그라데이션 빛줄기
                for i in range(int(beam['width'])):
                    line_alpha = alpha - i * 5
                    if line_alpha > 0:
                        pygame.draw.line(beam_surf, (*beam['color'], line_alpha),
                                       (sun['x'], sun['y']), (end_x, end_y),
                                       int(beam['width'] - i))
        
        surface.blit(beam_surf, (0, 0))
    
    def _draw_quantum_particles(self, surface: pygame.Surface):
        """양자 입자 그리기"""
        for quantum in self.quantum_particles:
            # 궤적
            if len(quantum['trail']) > 1:
                for i in range(len(quantum['trail']) - 1):
                    alpha = int(100 * (i / len(quantum['trail'])))
                    if alpha > 0:
                        pygame.draw.line(surface, (*quantum['color'], alpha),
                                       quantum['trail'][i], quantum['trail'][i + 1], 1)
            
            # 입자 본체
            # 텔레포트 직전 효과
            if quantum['teleport_timer'] < 10:
                for i in range(3):
                    flash_alpha = 150 - i * 50
                    flash_size = quantum['size'] + i * 2
                    pygame.draw.circle(surface, (*quantum['color'], flash_alpha),
                                     (int(quantum['x']), int(quantum['y'])),
                                     int(flash_size))
            else:
                pygame.draw.circle(surface, quantum['color'],
                                 (int(quantum['x']), int(quantum['y'])),
                                 int(quantum['size']))
    
    def _draw_crystalline_shards(self, surface: pygame.Surface):
        """수정 조각 그리기"""
        for crystal in self.crystalline_shards:
            # 반짝임 효과
            sparkle = math.sin(crystal['sparkle']) * 0.5 + 0.5
            
            # 수정 면들
            for facet in crystal['facets']:
                # 면 끝점 계산
                fx = crystal['x'] + math.cos(crystal['rotation'] + facet['angle']) * crystal['size'] * facet['length']
                fy = crystal['y'] + math.sin(crystal['rotation'] + facet['angle']) * crystal['size'] * facet['length']
                
                # 면 밝기
                brightness = facet['brightness'] * sparkle
                color = tuple(int(c * brightness) for c in crystal['color'])
                
                # 삼각형 면 그리기
                points = [
                    (crystal['x'], crystal['y']),
                    (fx, fy),
                    (fx + crystal['size'] * 0.3, fy + crystal['size'] * 0.3)
                ]
                pygame.draw.polygon(surface, color, points)
                
                # 테두리
                edge_color = tuple(min(255, int(c * 1.3)) for c in color)
                pygame.draw.polygon(surface, edge_color, points, 1)
            
            # 중심 빛
            for i in range(3):
                glow_alpha = int((100 - i * 30) * sparkle)
                if glow_alpha > 0:
                    glow_size = 3 + i
                    pygame.draw.circle(surface, (*crystal['color'], glow_alpha),
                                     (int(crystal['x']), int(crystal['y'])),
                                     glow_size)
    
    def _draw_energy_orbs(self, surface: pygame.Surface):
        """에너지 구체 그리기"""
        for orb in self.energy_orbs:
            # 펄스 효과
            pulse = math.sin(orb['pulse']) * 0.2 + 0.8
            
            # 에너지 링
            for ring in orb['energy_rings']:
                ring_surf = pygame.Surface((int(ring['radius'] * 2.5), int(ring['radius'] * 2.5)), pygame.SRCALPHA)
                
                # 회전하는 링
                for i in range(8):
                    angle = ring['rotation'] + i * (math.pi / 4)
                    x1 = ring['radius'] * 1.25 + math.cos(angle) * ring['radius']
                    y1 = ring['radius'] * 1.25 + math.sin(angle) * ring['radius']
                    x2 = ring['radius'] * 1.25 + math.cos(angle + math.pi) * ring['radius']
                    y2 = ring['radius'] * 1.25 + math.sin(angle + math.pi) * ring['radius']
                    
                    pygame.draw.line(ring_surf, (*orb['color'], 50), (x1, y1), (x2, y2), 1)
                
                surface.blit(ring_surf, (int(orb['x'] - ring['radius'] * 1.25), 
                                        int(orb['y'] - ring['radius'] * 1.25)))
            
            # 구체 본체
            radius = orb['radius'] * pulse
            
            # 글로우
            for i in range(3):
                glow_radius = radius + i * 3
                glow_alpha = 80 - i * 25
                pygame.draw.circle(surface, (*orb['color'], glow_alpha),
                                 (int(orb['x']), int(orb['y'])),
                                 int(glow_radius))
            
            # 중심
            pygame.draw.circle(surface, orb['color'],
                             (int(orb['x']), int(orb['y'])),
                             int(radius))
            
            # 하이라이트
            pygame.draw.circle(surface, (255, 255, 255, 100),
                             (int(orb['x'] - radius * 0.3), int(orb['y'] - radius * 0.3)),
                             int(radius * 0.3))
    
    def _draw_planet_enhancements(self, surface: pygame.Surface):
        """행성 추가 장식 그리기"""
        for planet in self.planets:
            if planet['type'] == 'sun':
                continue  # 태양은 이미 충분히 화려함
            
            x = planet.get('x', self.width // 2)
            y = planet.get('y', self.height // 2)
            
            # 입자 고리 (회전하는 고리와는 별도)
            if 'particle_ring' in planet and planet['particle_ring']:
                ring_surf = pygame.Surface((int(planet['radius'] * 4), int(planet['radius'] * 4)), pygame.SRCALPHA)
                
                for particle in planet['particle_ring']:
                    px = planet['radius'] * 2 + math.cos(particle['angle']) * planet['radius'] * particle['distance']
                    py = planet['radius'] * 2 + math.sin(particle['angle']) * planet['radius'] * particle['distance'] * 0.5
                    
                    # 입자 그리기
                    pygame.draw.circle(ring_surf, (*particle['color'], 50),
                                     (int(px), int(py)), int(particle['size']))
                
                surface.blit(ring_surf, (int(x - planet['radius'] * 2), int(y - planet['radius'] * 2)))
            
            # 에너지 펄스
            if 'energy_pulse' in planet and planet['energy_pulse']['active']:
                pulse_radius = planet['radius'] + planet['energy_pulse']['amplitude'] * math.sin(planet['energy_pulse']['phase'])
                pulse_alpha = int(30 * (1 - abs(math.sin(planet['energy_pulse']['phase']))))
                
                if pulse_alpha > 0:
                    pygame.draw.circle(surface, (*planet.get('glow_color', (200, 200, 255)), pulse_alpha),
                                     (int(x), int(y)), int(pulse_radius))
    
    def _draw_rotating_ring_back(self, surface: pygame.Surface, x: float, y: float, ring: Dict, planet_radius: float):
        """회전하는 고리의 뒤쪽 부분 그리기"""
        # 고리 서페이스 생성
        ring_size = int(ring['radius'] * 2.5)
        ring_surf = pygame.Surface((ring_size, ring_size), pygame.SRCALPHA)
        center = ring_size // 2
        
        # 회전과 기울기를 적용한 타원 그리기
        for i in range(int(ring['width'])):
            # 뒤쪽 절반만 그리기 (180도 ~ 360도)
            for angle in range(180, 360, 2):
                rad = math.radians(angle + math.degrees(ring['rotation']))
                
                # 타원 좌표 계산
                rx = ring['radius'] + i
                ry = (ring['radius'] + i) * 0.4 * (1 + ring['tilt'])
                
                px = center + rx * math.cos(rad)
                py = center + ry * math.sin(rad)
                
                # 깊이에 따른 알파값 조정
                depth = math.sin(rad) * 0.5 + 0.5
                alpha = int(ring['color'][3] * depth * 0.5)  # 뒤쪽은 더 어둡게
                
                if alpha > 0:
                    pygame.draw.circle(ring_surf, (*ring['color'][:3], alpha),
                                     (int(px), int(py)), 2)
        
        # 파티클 그리기
        for particle in ring['particles']:
            if math.sin(particle['angle'] + ring['rotation']) < 0:  # 뒤쪽 파티클만
                px = center + ring['radius'] * math.cos(particle['angle'] + ring['rotation'])
                py = center + ring['radius'] * 0.4 * math.sin(particle['angle'] + ring['rotation']) * (1 + ring['tilt'])
                
                alpha = int(particle['brightness'] * 100 * 0.5)
                if alpha > 0:
                    pygame.draw.circle(ring_surf, (*ring['color'][:3], alpha),
                                     (int(px), int(py)), int(particle['size']))
        
        surface.blit(ring_surf, (int(x - center), int(y - center)))
    
    def _draw_rotating_ring_front(self, surface: pygame.Surface, x: float, y: float, ring: Dict, planet_radius: float):
        """회전하는 고리의 앞쪽 부분 그리기"""
        # 고리 서페이스 생성
        ring_size = int(ring['radius'] * 2.5)
        ring_surf = pygame.Surface((ring_size, ring_size), pygame.SRCALPHA)
        center = ring_size // 2
        
        # 회전과 기울기를 적용한 타원 그리기
        for i in range(int(ring['width'])):
            # 앞쪽 절반만 그리기 (0도 ~ 180도)
            for angle in range(0, 180, 2):
                rad = math.radians(angle + math.degrees(ring['rotation']))
                
                # 타원 좌표 계산
                rx = ring['radius'] + i
                ry = (ring['radius'] + i) * 0.4 * (1 + ring['tilt'])
                
                px = center + rx * math.cos(rad)
                py = center + ry * math.sin(rad)
                
                # 깊이에 따른 알파값 조정
                depth = math.sin(rad) * 0.5 + 0.5
                alpha = int(ring['color'][3] * (0.5 + depth * 0.5))  # 앞쪽은 더 밝게
                
                if alpha > 0:
                    pygame.draw.circle(ring_surf, (*ring['color'][:3], alpha),
                                     (int(px), int(py)), 2)
        
        # 파티클 그리기
        for particle in ring['particles']:
            if math.sin(particle['angle'] + ring['rotation']) >= 0:  # 앞쪽 파티클만
                px = center + ring['radius'] * math.cos(particle['angle'] + ring['rotation'])
                py = center + ring['radius'] * 0.4 * math.sin(particle['angle'] + ring['rotation']) * (1 + ring['tilt'])
                
                alpha = int(particle['brightness'] * 150)
                if alpha > 0:
                    # 밝은 글로우 효과
                    pygame.draw.circle(ring_surf, (*ring['color'][:3], min(255, alpha + 50)),
                                     (int(px), int(py)), int(particle['size'] * 1.5))
                    pygame.draw.circle(ring_surf, (255, 255, 255, min(255, alpha)),
                                     (int(px), int(py)), int(particle['size'] * 0.5))
        
        surface.blit(ring_surf, (int(x - center), int(y - center)))