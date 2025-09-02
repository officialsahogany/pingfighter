"""
PingFighter Performance Optimization Patch
즉시 적용 가능한 성능 최적화 패치
"""

import pygame
import functools

class PerformanceOptimizer:
    """성능 최적화 도구 모음"""
    
    def __init__(self):
        self.surface_cache = {}
        self.dirty_rects = []
        self.frame_skip_counter = 0
        
    @functools.lru_cache(maxsize=128)
    def cache_surface(self, key, generator_func, *args):
        """Surface 캐싱"""
        if key not in self.surface_cache:
            self.surface_cache[key] = generator_func(*args)
        return self.surface_cache[key]
    
    def add_dirty_rect(self, rect):
        """더티 렉트 추가"""
        self.dirty_rects.append(rect)
    
    def get_dirty_rects(self):
        """더티 렉트 반환 및 초기화"""
        rects = self.dirty_rects.copy()
        self.dirty_rects.clear()
        return rects
    
    def should_skip_frame(self, skip_rate=2):
        """프레임 스킵 여부 결정"""
        self.frame_skip_counter += 1
        if self.frame_skip_counter >= skip_rate:
            self.frame_skip_counter = 0
            return False
        return True

# 배경 캐싱 최적화
def optimize_background_loading():
    """배경 로딩 최적화"""
    backgrounds = {}
    
    def load_or_create_background(stage_num, width, height):
        cache_key = f"stage{stage_num}_bg"
        
        if cache_key in backgrounds:
            return backgrounds[cache_key]
        
        # 파일 로드 시도
        try:
            bg = pygame.image.load(f"stage{stage_num}_field.png").convert()
            bg = pygame.transform.scale(bg, (width, height))
        except:
            # 폴백: 간단한 그라데이션만 생성
            bg = create_simple_gradient(width, height, stage_num)
        
        backgrounds[cache_key] = bg
        return bg
    
    return load_or_create_background

def create_simple_gradient(width, height, stage_num):
    """간단한 그라데이션 배경 생성 (고속)"""
    surface = pygame.Surface((width, height))
    
    # 스테이지별 색상
    colors = {
        1: ((10, 50, 20), (30, 100, 50)),  # 청록
        2: ((5, 10, 40), (15, 30, 100)),   # 심해
        3: ((80, 10, 80), (120, 30, 120)), # 네온
        4: ((60, 50, 20), (120, 90, 40)),  # 황금
        5: ((100, 20, 0), (155, 40, 10)),  # 용암
        6: ((10, 20, 50), (30, 40, 100)),  # 우주
    }
    
    start_color, end_color = colors.get(stage_num, ((0, 0, 0), (50, 50, 50)))
    
    # 10픽셀 단위로 그라데이션 (성능 최적화)
    for y in range(0, height, 10):
        ratio = y / height
        r = int(start_color[0] + (end_color[0] - start_color[0]) * ratio)
        g = int(start_color[1] + (end_color[1] - start_color[1]) * ratio)
        b = int(start_color[2] + (end_color[2] - start_color[2]) * ratio)
        pygame.draw.rect(surface, (r, g, b), (0, y, width, 10))
    
    return surface

# 파티클 시스템 최적화
class OptimizedParticleSystem:
    """최적화된 파티클 시스템"""
    
    def __init__(self, max_particles=100):
        self.particles = []
        self.max_particles = max_particles
        self.particle_surface = pygame.Surface((10, 10), pygame.SRCALPHA)
        pygame.draw.circle(self.particle_surface, (255, 255, 255), (5, 5), 5)
    
    def add_particle(self, x, y, vel_x, vel_y, color, lifetime):
        """파티클 추가 (최대 개수 제한)"""
        if len(self.particles) >= self.max_particles:
            # 가장 오래된 파티클 제거
            self.particles.pop(0)
        
        self.particles.append({
            'x': x, 'y': y,
            'vel_x': vel_x, 'vel_y': vel_y,
            'color': color,
            'lifetime': lifetime,
            'max_lifetime': lifetime
        })
    
    def update(self):
        """파티클 업데이트 (최적화)"""
        # 리스트 컴프리헨션으로 한 번에 처리
        self.particles = [
            {
                **p,
                'x': p['x'] + p['vel_x'],
                'y': p['y'] + p['vel_y'],
                'lifetime': p['lifetime'] - 1
            }
            for p in self.particles
            if p['lifetime'] > 0
        ]
    
    def draw(self, screen):
        """파티클 그리기 (배치 렌더링)"""
        for p in self.particles:
            alpha = int(255 * (p['lifetime'] / p['max_lifetime']))
            colored_surface = self.particle_surface.copy()
            colored_surface.fill((*p['color'], alpha), special_flags=pygame.BLEND_RGBA_MULT)
            screen.blit(colored_surface, (p['x'] - 5, p['y'] - 5))

# 충돌 감지 최적화
class SpatialHash:
    """공간 해싱을 이용한 충돌 감지 최적화"""
    
    def __init__(self, cell_size=100):
        self.cell_size = cell_size
        self.cells = {}
    
    def clear(self):
        """해시 테이블 초기화"""
        self.cells.clear()
    
    def add_object(self, obj, rect):
        """객체 추가"""
        cells = self._get_cells(rect)
        for cell in cells:
            if cell not in self.cells:
                self.cells[cell] = []
            self.cells[cell].append((obj, rect))
    
    def get_nearby_objects(self, rect):
        """근처 객체 가져오기"""
        cells = self._get_cells(rect)
        nearby = []
        seen = set()
        
        for cell in cells:
            if cell in self.cells:
                for obj, obj_rect in self.cells[cell]:
                    if obj not in seen:
                        seen.add(obj)
                        nearby.append((obj, obj_rect))
        
        return nearby
    
    def _get_cells(self, rect):
        """렉트가 속한 셀들 계산"""
        left = rect.left // self.cell_size
        right = rect.right // self.cell_size
        top = rect.top // self.cell_size
        bottom = rect.bottom // self.cell_size
        
        cells = []
        for x in range(left, right + 1):
            for y in range(top, bottom + 1):
                cells.append((x, y))
        
        return cells

# 메모리 풀링
class ObjectPool:
    """객체 재사용을 위한 메모리 풀"""
    
    def __init__(self, create_func, reset_func, initial_size=10):
        self.create_func = create_func
        self.reset_func = reset_func
        self.available = []
        self.in_use = []
        
        # 초기 객체 생성
        for _ in range(initial_size):
            self.available.append(create_func())
    
    def acquire(self):
        """객체 획득"""
        if not self.available:
            obj = self.create_func()
        else:
            obj = self.available.pop()
        
        self.in_use.append(obj)
        return obj
    
    def release(self, obj):
        """객체 반환"""
        if obj in self.in_use:
            self.in_use.remove(obj)
            self.reset_func(obj)
            self.available.append(obj)

# 프로파일링 도구
class SimpleProfiler:
    """간단한 성능 프로파일러"""
    
    def __init__(self):
        self.timings = {}
        self.counts = {}
    
    def start(self, name):
        """타이밍 시작"""
        self.timings[name] = pygame.time.get_ticks()
    
    def end(self, name):
        """타이밍 종료 및 기록"""
        if name in self.timings:
            elapsed = pygame.time.get_ticks() - self.timings[name]
            
            if name not in self.counts:
                self.counts[name] = {'total': 0, 'count': 0}
            
            self.counts[name]['total'] += elapsed
            self.counts[name]['count'] += 1
    
    def get_report(self):
        """성능 리포트 생성"""
        report = []
        for name, data in self.counts.items():
            avg = data['total'] / data['count'] if data['count'] > 0 else 0
            report.append(f"{name}: {avg:.2f}ms avg ({data['count']} calls)")
        return "\n".join(report)

# 전역 최적화 인스턴스
optimizer = PerformanceOptimizer()
particle_system = OptimizedParticleSystem()
spatial_hash = SpatialHash()
profiler = SimpleProfiler()

print("✅ Performance Optimization Patch 로드 완료!")
print("사용법:")
print("  from optimization_patch import optimizer, particle_system, spatial_hash, profiler")
print("  background = optimizer.cache_surface('stage1', create_stage1_bg, width, height)")