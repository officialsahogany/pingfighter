"""
Performance Optimizer - 성능 최적화 시스템
메모리 관리, 리소스 최적화, 성능 모니터링
"""

import pygame
import psutil
import gc
import sys
import weakref
import time
from typing import Dict, Any, List, Optional, Set
from dataclasses import dataclass
from collections import defaultdict
from core.global_manager import GlobalManager


@dataclass
class PerformanceMetrics:
    """성능 메트릭"""
    fps: float
    frame_time: float
    cpu_usage: float
    memory_usage: float
    memory_mb: float
    gc_collections: Dict[int, int]
    object_counts: Dict[str, int]
    texture_memory: float
    audio_memory: float
    
    
class MemoryTracker:
    """메모리 추적기"""
    
    def __init__(self):
        self.tracked_objects: Set[weakref.ref] = set()
        self.object_types = defaultdict(int)
        self.peak_memory = 0
        self.last_gc_time = time.time()
        self.gc_interval = 5.0  # 5초마다 GC
        
        # 프로세스 정보
        self.process = psutil.Process()
        
    def track_object(self, obj: Any, obj_type: str = None):
        """객체 추적
        
        Args:
            obj: 추적할 객체
            obj_type: 객체 타입
        """
        try:
            # weak reference로 추적
            ref = weakref.ref(obj, self._on_object_deleted)
            self.tracked_objects.add(ref)
            
            # 타입별 카운트
            if obj_type is None:
                obj_type = type(obj).__name__
            self.object_types[obj_type] += 1
            
        except TypeError:
            # weak reference를 만들 수 없는 객체는 스킵
            pass
            
    def _on_object_deleted(self, ref):
        """객체 삭제 콜백"""
        self.tracked_objects.discard(ref)
        
    def get_memory_usage(self) -> Dict[str, Any]:
        """메모리 사용량 조회
        
        Returns:
            메모리 정보
        """
        memory_info = self.process.memory_info()
        memory_percent = self.process.memory_percent()
        
        # MB 단위로 변환
        memory_mb = memory_info.rss / 1024 / 1024
        
        # Peak memory 업데이트
        if memory_mb > self.peak_memory:
            self.peak_memory = memory_mb
            
        return {
            'current_mb': memory_mb,
            'peak_mb': self.peak_memory,
            'percent': memory_percent,
            'tracked_objects': len(self.tracked_objects),
            'object_types': dict(self.object_types)
        }
        
    def check_memory_leaks(self) -> List[str]:
        """메모리 누수 체크
        
        Returns:
            경고 메시지 리스트
        """
        warnings = []
        
        # 추적 중인 객체가 너무 많은 경우
        if len(self.tracked_objects) > 10000:
            warnings.append(f"⚠️ 추적 객체 과다: {len(self.tracked_objects)}개")
            
        # 특정 타입의 객체가 너무 많은 경우
        for obj_type, count in self.object_types.items():
            if count > 1000:
                warnings.append(f"⚠️ {obj_type} 객체 과다: {count}개")
                
        # 메모리 사용량이 너무 높은 경우
        memory_info = self.get_memory_usage()
        if memory_info['percent'] > 80:
            warnings.append(f"⚠️ 메모리 사용률 높음: {memory_info['percent']:.1f}%")
            
        return warnings
        
    def force_cleanup(self):
        """강제 정리"""
        # 죽은 참조 제거
        dead_refs = [ref for ref in self.tracked_objects if ref() is None]
        for ref in dead_refs:
            self.tracked_objects.discard(ref)
            
        # 가비지 컬렉션 실행
        gc.collect()
        
        # 타입 카운트 재계산
        self.object_types.clear()
        for ref in self.tracked_objects:
            obj = ref()
            if obj is not None:
                self.object_types[type(obj).__name__] += 1
                

class TextureCache:
    """텍스처 캐시 관리"""
    
    def __init__(self, max_size_mb: float = 100):
        self.cache: Dict[str, pygame.Surface] = {}
        self.access_times: Dict[str, float] = {}
        self.max_size_mb = max_size_mb
        self.current_size_mb = 0
        
    def add(self, key: str, surface: pygame.Surface):
        """텍스처 추가
        
        Args:
            key: 캐시 키
            surface: Surface 객체
        """
        # 크기 계산 (대략적)
        size_mb = (surface.get_width() * surface.get_height() * 4) / 1024 / 1024
        
        # 캐시 크기 초과 시 오래된 것 제거
        while self.current_size_mb + size_mb > self.max_size_mb and self.cache:
            self._evict_oldest()
            
        # 캐시에 추가
        self.cache[key] = surface
        self.access_times[key] = time.time()
        self.current_size_mb += size_mb
        
    def get(self, key: str) -> Optional[pygame.Surface]:
        """텍스처 가져오기
        
        Args:
            key: 캐시 키
            
        Returns:
            Surface 객체 또는 None
        """
        if key in self.cache:
            self.access_times[key] = time.time()
            return self.cache[key]
        return None
        
    def _evict_oldest(self):
        """가장 오래된 텍스처 제거"""
        if not self.cache:
            return
            
        oldest_key = min(self.access_times, key=self.access_times.get)
        surface = self.cache.pop(oldest_key)
        del self.access_times[oldest_key]
        
        # 크기 업데이트
        size_mb = (surface.get_width() * surface.get_height() * 4) / 1024 / 1024
        self.current_size_mb -= size_mb
        
    def clear(self):
        """캐시 초기화"""
        self.cache.clear()
        self.access_times.clear()
        self.current_size_mb = 0
        

class DrawCallBatcher:
    """드로우 콜 배처"""
    
    def __init__(self):
        self.batches: Dict[str, List] = defaultdict(list)
        
    def add_rect(self, color: tuple, rect: pygame.Rect, width: int = 0):
        """사각형 추가
        
        Args:
            color: 색상
            rect: 사각형
            width: 선 두께 (0이면 채움)
        """
        key = f"rect_{color}_{width}"
        self.batches[key].append(rect)
        
    def add_circle(self, color: tuple, pos: tuple, radius: int):
        """원 추가
        
        Args:
            color: 색상
            pos: 위치
            radius: 반지름
        """
        key = f"circle_{color}"
        self.batches[key].append((pos, radius))
        
    def add_sprite(self, surface: pygame.Surface, pos: tuple):
        """스프라이트 추가
        
        Args:
            surface: Surface 객체
            pos: 위치
        """
        key = f"sprite_{id(surface)}"
        self.batches[key].append(pos)
        
    def render(self, screen: pygame.Surface):
        """배치 렌더링
        
        Args:
            screen: 화면 Surface
        """
        for key, items in self.batches.items():
            if key.startswith("rect_"):
                # 사각형 배치 렌더링
                parts = key.split("_")
                color = eval(parts[1])  # 안전하지 않음, 실제로는 다른 방법 사용
                width = int(parts[2])
                
                for rect in items:
                    pygame.draw.rect(screen, color, rect, width)
                    
            elif key.startswith("circle_"):
                # 원 배치 렌더링
                color = eval(key.split("_")[1])
                
                for pos, radius in items:
                    pygame.draw.circle(screen, color, pos, radius)
                    
        # 배치 초기화
        self.batches.clear()
        

class PerformanceOptimizer:
    """성능 최적화 매니저"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        
        # 서브시스템
        self.memory_tracker = MemoryTracker()
        self.texture_cache = TextureCache()
        self.draw_batcher = DrawCallBatcher()
        
        # 성능 설정
        self.target_fps = 60
        self.auto_optimize = True
        self.quality_level = 1.0  # 0.5 ~ 1.0
        
        # 메트릭
        self.frame_times = []
        self.max_frame_history = 60
        
        # 최적화 플래그
        self.reduce_particles = False
        self.reduce_effects = False
        self.reduce_shadows = False
        self.batch_rendering = True
        
        # CPU 사용률 추적
        self.last_cpu_check = time.time()
        self.cpu_check_interval = 1.0
        self.last_cpu_usage = 0
        
    def update(self, dt: float):
        """업데이트
        
        Args:
            dt: 델타 타임
        """
        # 프레임 시간 기록
        self.frame_times.append(dt)
        if len(self.frame_times) > self.max_frame_history:
            self.frame_times.pop(0)
            
        # CPU 사용률 체크
        current_time = time.time()
        if current_time - self.last_cpu_check >= self.cpu_check_interval:
            self.last_cpu_check = current_time
            self.last_cpu_usage = psutil.cpu_percent(interval=0)
            
        # 자동 최적화
        if self.auto_optimize:
            self._auto_adjust_quality()
            
        # 주기적 메모리 정리
        if current_time - self.memory_tracker.last_gc_time >= self.memory_tracker.gc_interval:
            self.memory_tracker.last_gc_time = current_time
            self.memory_tracker.force_cleanup()
            
    def _auto_adjust_quality(self):
        """품질 자동 조정"""
        if not self.frame_times:
            return
            
        # 평균 FPS 계산
        avg_frame_time = sum(self.frame_times) / len(self.frame_times)
        if avg_frame_time > 0:
            current_fps = 1.0 / avg_frame_time
        else:
            current_fps = self.target_fps
            
        # FPS가 목표치보다 낮으면 품질 감소
        if current_fps < self.target_fps * 0.9:
            self.decrease_quality()
        # FPS가 충분히 높으면 품질 증가
        elif current_fps > self.target_fps * 1.1:
            self.increase_quality()
            
    def decrease_quality(self):
        """품질 감소"""
        self.quality_level = max(0.5, self.quality_level - 0.1)
        
        # 단계별 최적화
        if self.quality_level < 0.9:
            self.reduce_particles = True
            self.global_manager.set('particles_enabled', False)
            
        if self.quality_level < 0.7:
            self.reduce_effects = True
            self.global_manager.set('effects_quality', 'low')
            
        if self.quality_level < 0.6:
            self.reduce_shadows = True
            self.global_manager.set('shadows_enabled', False)
            
        print(f"⚡ 품질 감소: {self.quality_level:.1f}")
        
    def increase_quality(self):
        """품질 증가"""
        self.quality_level = min(1.0, self.quality_level + 0.05)
        
        # 단계별 복원
        if self.quality_level >= 0.6:
            self.reduce_shadows = False
            self.global_manager.set('shadows_enabled', True)
            
        if self.quality_level >= 0.7:
            self.reduce_effects = False
            self.global_manager.set('effects_quality', 'high')
            
        if self.quality_level >= 0.9:
            self.reduce_particles = False
            self.global_manager.set('particles_enabled', True)
            
    def get_metrics(self) -> PerformanceMetrics:
        """성능 메트릭 조회
        
        Returns:
            성능 메트릭
        """
        # FPS 계산
        if self.frame_times:
            avg_frame_time = sum(self.frame_times) / len(self.frame_times)
            fps = 1.0 / avg_frame_time if avg_frame_time > 0 else 0
        else:
            fps = 0
            avg_frame_time = 0
            
        # 메모리 정보
        memory_info = self.memory_tracker.get_memory_usage()
        
        # GC 정보
        gc_stats = {}
        for i in range(gc.get_count().__len__()):
            gc_stats[i] = gc.get_count()[i]
            
        # 객체 카운트
        object_counts = memory_info.get('object_types', {})
        
        return PerformanceMetrics(
            fps=fps,
            frame_time=avg_frame_time * 1000,  # ms
            cpu_usage=self.last_cpu_usage,
            memory_usage=memory_info['percent'],
            memory_mb=memory_info['current_mb'],
            gc_collections=gc_stats,
            object_counts=object_counts,
            texture_memory=self.texture_cache.current_size_mb,
            audio_memory=0  # TODO: 오디오 메모리 추적
        )
        
    def optimize_surface(self, surface: pygame.Surface) -> pygame.Surface:
        """Surface 최적화
        
        Args:
            surface: 원본 Surface
            
        Returns:
            최적화된 Surface
        """
        # 품질에 따라 크기 조정
        if self.quality_level < 1.0:
            width = int(surface.get_width() * self.quality_level)
            height = int(surface.get_height() * self.quality_level)
            if width > 0 and height > 0:
                surface = pygame.transform.scale(surface, (width, height))
                
        # convert() 또는 convert_alpha() 적용
        if surface.get_flags() & pygame.SRCALPHA:
            return surface.convert_alpha()
        else:
            return surface.convert()
            
    def should_skip_frame(self) -> bool:
        """프레임 스킵 여부
        
        Returns:
            스킵 여부
        """
        # 심각한 성능 저하 시 프레임 스킵
        if self.frame_times and len(self.frame_times) >= 2:
            last_frame_time = self.frame_times[-1]
            target_frame_time = 1.0 / self.target_fps
            
            # 마지막 프레임이 목표 시간의 2배 이상 걸렸으면 스킵
            return last_frame_time > target_frame_time * 2
            
        return False
        
    def cleanup(self):
        """정리"""
        # 캐시 정리
        self.texture_cache.clear()
        
        # 강제 GC
        self.memory_tracker.force_cleanup()
        
        print("🧹 성능 최적화 시스템 정리 완료")


# 싱글톤 인스턴스
_performance_optimizer = None

def get_performance_optimizer() -> PerformanceOptimizer:
    """성능 최적화 매니저 싱글톤 반환"""
    global _performance_optimizer
    if _performance_optimizer is None:
        _performance_optimizer = PerformanceOptimizer()
    return _performance_optimizer