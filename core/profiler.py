"""
Performance Profiler - 성능 프로파일링 시스템
게임 성능 모니터링 및 최적화를 위한 프로파일러
"""

import time
import pygame
import gc
import sys
from typing import Dict, List, Optional, Tuple
from collections import deque, defaultdict
import json


class PerformanceMetrics:
    """성능 메트릭 수집 클래스"""
    
    def __init__(self, max_samples: int = 120):
        self.max_samples = max_samples
        
        # FPS 메트릭
        self.fps_history = deque(maxlen=max_samples)
        self.frame_times = deque(maxlen=max_samples)
        self.current_fps = 0
        self.average_fps = 0
        self.min_fps = float('inf')
        self.max_fps = 0
        
        # 프레임 타이밍
        self.last_frame_time = time.perf_counter()
        self.delta_time = 0
        self.frame_count = 0
        
        # 메모리 메트릭
        self.memory_usage = deque(maxlen=max_samples)
        self.gc_collections = [0, 0, 0]  # Gen 0, 1, 2
        
        # 렌더링 메트릭
        self.draw_calls = 0
        self.particles_rendered = 0
        self.ui_elements_rendered = 0
        
        # 이벤트 메트릭
        self.events_processed = 0
        self.event_processing_time = 0
        
        # 섹션별 타이밍
        self.section_times = defaultdict(lambda: deque(maxlen=max_samples))
        self.current_section_start = {}
        
    def update_frame(self):
        """프레임 업데이트"""
        current_time = time.perf_counter()
        self.delta_time = current_time - self.last_frame_time
        self.last_frame_time = current_time
        
        # FPS 계산
        if self.delta_time > 0:
            self.current_fps = 1.0 / self.delta_time
            self.fps_history.append(self.current_fps)
            self.frame_times.append(self.delta_time * 1000)  # ms로 변환
            
            # 통계 업데이트
            if len(self.fps_history) > 0:
                self.average_fps = sum(self.fps_history) / len(self.fps_history)
                self.min_fps = min(self.fps_history)
                self.max_fps = max(self.fps_history)
                
        self.frame_count += 1
        
        # 메모리 사용량 추적
        if self.frame_count % 30 == 0:  # 0.5초마다
            self.update_memory_metrics()
            
    def update_memory_metrics(self):
        """메모리 메트릭 업데이트"""
        # Python 메모리 사용량
        try:
            import psutil
            import os
            
            process = psutil.Process(os.getpid())
            memory_mb = process.memory_info().rss / 1024 / 1024
            self.memory_usage.append(memory_mb)
        except ImportError:
            # psutil이 없는 경우 기본값 사용
            import sys
            # sys.getsizeof로 대략적인 메모리 추정
            self.memory_usage.append(100.0)  # 기본값
        except:
            pass
            
        # GC 컬렉션 횟수
        self.gc_collections = gc.get_count()
        
    def start_section(self, name: str):
        """섹션 타이밍 시작"""
        self.current_section_start[name] = time.perf_counter()
        
    def end_section(self, name: str):
        """섹션 타이밍 종료"""
        if name in self.current_section_start:
            elapsed = (time.perf_counter() - self.current_section_start[name]) * 1000
            self.section_times[name].append(elapsed)
            del self.current_section_start[name]
            
    def get_section_average(self, name: str) -> float:
        """섹션 평균 시간 반환"""
        if name in self.section_times and len(self.section_times[name]) > 0:
            return sum(self.section_times[name]) / len(self.section_times[name])
        return 0.0
        
    def get_metrics_summary(self) -> Dict:
        """메트릭 요약 반환"""
        return {
            'fps': {
                'current': round(self.current_fps, 1),
                'average': round(self.average_fps, 1),
                'min': round(self.min_fps, 1),
                'max': round(self.max_fps, 1)
            },
            'frame_time': {
                'current': round(self.delta_time * 1000, 2),
                'average': round(sum(self.frame_times) / len(self.frame_times), 2) if self.frame_times else 0
            },
            'memory': {
                'current_mb': round(self.memory_usage[-1], 1) if self.memory_usage else 0,
                'gc_collections': self.gc_collections
            },
            'rendering': {
                'draw_calls': self.draw_calls,
                'particles': self.particles_rendered,
                'ui_elements': self.ui_elements_rendered
            },
            'sections': {
                name: round(self.get_section_average(name), 2)
                for name in self.section_times
            }
        }


class GameProfiler:
    """게임 프로파일러"""
    
    def __init__(self, screen: pygame.Surface, enabled: bool = True):
        self.screen = screen
        self.enabled = enabled
        self.visible = False
        self.metrics = PerformanceMetrics()
        
        # 디스플레이 설정
        self.font_size = 12
        self.font = pygame.font.Font(None, self.font_size)
        self.overlay_alpha = 200
        self.text_color = (0, 255, 0)
        self.warning_color = (255, 255, 0)
        self.critical_color = (255, 0, 0)
        
        # 성능 임계값
        self.fps_warning = 50
        self.fps_critical = 30
        self.frame_time_warning = 20  # ms
        self.frame_time_critical = 33  # ms
        
        # 그래프 설정
        self.graph_width = 200
        self.graph_height = 60
        self.graph_padding = 5
        
        # 로깅
        self.log_file = None
        self.log_interval = 60  # 프레임
        self.frames_since_log = 0
        
    def toggle_visibility(self):
        """프로파일러 표시 토글"""
        self.visible = not self.visible
        
    def set_enabled(self, enabled: bool):
        """프로파일러 활성화/비활성화"""
        self.enabled = enabled
        
    def begin_frame(self):
        """프레임 시작"""
        if not self.enabled:
            return
            
        self.metrics.update_frame()
        self.metrics.draw_calls = 0
        self.metrics.particles_rendered = 0
        self.metrics.ui_elements_rendered = 0
        
    def end_frame(self):
        """프레임 종료"""
        if not self.enabled:
            return
            
        # 로깅
        if self.log_file:
            self.frames_since_log += 1
            if self.frames_since_log >= self.log_interval:
                self.log_metrics()
                self.frames_since_log = 0
                
    def start_section(self, name: str):
        """섹션 프로파일링 시작"""
        if self.enabled:
            self.metrics.start_section(name)
            
    def end_section(self, name: str):
        """섹션 프로파일링 종료"""
        if self.enabled:
            self.metrics.end_section(name)
            
    def count_draw_call(self):
        """드로우 콜 카운트"""
        if self.enabled:
            self.metrics.draw_calls += 1
            
    def count_particle(self, count: int = 1):
        """파티클 카운트"""
        if self.enabled:
            self.metrics.particles_rendered += count
            
    def count_ui_element(self, count: int = 1):
        """UI 요소 카운트"""
        if self.enabled:
            self.metrics.ui_elements_rendered += count
            
    def draw(self):
        """프로파일러 오버레이 그리기"""
        if not self.enabled or not self.visible:
            return
            
        # 배경 오버레이
        overlay = pygame.Surface((400, 500), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, self.overlay_alpha))
        self.screen.blit(overlay, (10, 10))
        
        y = 20
        x = 20
        
        # 타이틀
        self.draw_text("=== PERFORMANCE PROFILER ===", x, y, self.text_color)
        y += 25
        
        # FPS 정보
        metrics = self.metrics.get_metrics_summary()
        fps_color = self.get_fps_color(metrics['fps']['current'])
        self.draw_text(f"FPS: {metrics['fps']['current']} (avg: {metrics['fps']['average']})", 
                      x, y, fps_color)
        y += 20
        self.draw_text(f"    Min: {metrics['fps']['min']} Max: {metrics['fps']['max']}", 
                      x, y, self.text_color)
        y += 25
        
        # 프레임 타임
        frame_color = self.get_frame_time_color(metrics['frame_time']['current'])
        self.draw_text(f"Frame Time: {metrics['frame_time']['current']}ms (avg: {metrics['frame_time']['average']}ms)", 
                      x, y, frame_color)
        y += 25
        
        # 메모리 정보
        self.draw_text(f"Memory: {metrics['memory']['current_mb']}MB", x, y, self.text_color)
        y += 20
        gc_info = metrics['memory']['gc_collections']
        self.draw_text(f"GC: Gen0:{gc_info[0]} Gen1:{gc_info[1]} Gen2:{gc_info[2]}", 
                      x, y, self.text_color)
        y += 25
        
        # 렌더링 정보
        self.draw_text("=== RENDERING ===", x, y, self.text_color)
        y += 20
        self.draw_text(f"Draw Calls: {metrics['rendering']['draw_calls']}", x, y, self.text_color)
        y += 20
        self.draw_text(f"Particles: {metrics['rendering']['particles']}", x, y, self.text_color)
        y += 20
        self.draw_text(f"UI Elements: {metrics['rendering']['ui_elements']}", x, y, self.text_color)
        y += 25
        
        # 섹션 타이밍
        if metrics['sections']:
            self.draw_text("=== SECTION TIMING (ms) ===", x, y, self.text_color)
            y += 20
            
            for section, time_ms in sorted(metrics['sections'].items(), 
                                          key=lambda x: x[1], reverse=True):
                color = self.get_section_color(time_ms)
                self.draw_text(f"{section}: {time_ms}ms", x + 10, y, color)
                y += 20
                
        # FPS 그래프
        self.draw_fps_graph(220, 20)
        
        # 메모리 그래프
        self.draw_memory_graph(220, 100)
        
    def draw_text(self, text: str, x: int, y: int, color: Tuple[int, int, int]):
        """텍스트 그리기"""
        text_surface = self.font.render(text, True, color)
        self.screen.blit(text_surface, (x, y))
        
    def draw_fps_graph(self, x: int, y: int):
        """FPS 그래프 그리기"""
        if len(self.metrics.fps_history) < 2:
            return
            
        # 그래프 배경
        graph_rect = pygame.Rect(x, y, self.graph_width, self.graph_height)
        pygame.draw.rect(self.screen, (40, 40, 40), graph_rect)
        pygame.draw.rect(self.screen, (100, 100, 100), graph_rect, 1)
        
        # FPS 데이터 그리기
        points = []
        for i, fps in enumerate(self.metrics.fps_history):
            px = x + (i * self.graph_width // len(self.metrics.fps_history))
            py = y + self.graph_height - int((fps / 120) * self.graph_height)
            py = max(y, min(y + self.graph_height, py))
            points.append((px, py))
            
        if len(points) > 1:
            pygame.draw.lines(self.screen, (0, 255, 0), False, points, 1)
            
        # 임계값 라인
        warning_y = y + self.graph_height - int((self.fps_warning / 120) * self.graph_height)
        pygame.draw.line(self.screen, self.warning_color, 
                        (x, warning_y), (x + self.graph_width, warning_y), 1)
                        
        critical_y = y + self.graph_height - int((self.fps_critical / 120) * self.graph_height)
        pygame.draw.line(self.screen, self.critical_color,
                        (x, critical_y), (x + self.graph_width, critical_y), 1)
                        
        # 라벨
        self.draw_text("FPS Graph", x, y - 15, self.text_color)
        
    def draw_memory_graph(self, x: int, y: int):
        """메모리 그래프 그리기"""
        if len(self.metrics.memory_usage) < 2:
            return
            
        # 그래프 배경
        graph_rect = pygame.Rect(x, y, self.graph_width, self.graph_height)
        pygame.draw.rect(self.screen, (40, 40, 40), graph_rect)
        pygame.draw.rect(self.screen, (100, 100, 100), graph_rect, 1)
        
        # 메모리 데이터 그리기
        if self.metrics.memory_usage:
            max_memory = max(self.metrics.memory_usage)
            min_memory = min(self.metrics.memory_usage)
            memory_range = max_memory - min_memory if max_memory != min_memory else 1
            
            points = []
            for i, memory in enumerate(self.metrics.memory_usage):
                px = x + (i * self.graph_width // len(self.metrics.memory_usage))
                normalized = (memory - min_memory) / memory_range
                py = y + self.graph_height - int(normalized * self.graph_height)
                points.append((px, py))
                
            if len(points) > 1:
                pygame.draw.lines(self.screen, (255, 255, 0), False, points, 1)
                
        # 라벨
        self.draw_text("Memory (MB)", x, y - 15, self.text_color)
        
    def get_fps_color(self, fps: float) -> Tuple[int, int, int]:
        """FPS에 따른 색상 반환"""
        if fps < self.fps_critical:
            return self.critical_color
        elif fps < self.fps_warning:
            return self.warning_color
        return self.text_color
        
    def get_frame_time_color(self, frame_time: float) -> Tuple[int, int, int]:
        """프레임 타임에 따른 색상 반환"""
        if frame_time > self.frame_time_critical:
            return self.critical_color
        elif frame_time > self.frame_time_warning:
            return self.warning_color
        return self.text_color
        
    def get_section_color(self, time_ms: float) -> Tuple[int, int, int]:
        """섹션 시간에 따른 색상 반환"""
        if time_ms > 10:
            return self.critical_color
        elif time_ms > 5:
            return self.warning_color
        return self.text_color
        
    def start_logging(self, filename: str = "performance_log.json"):
        """로깅 시작"""
        self.log_file = filename
        self.frames_since_log = 0
        
    def stop_logging(self):
        """로깅 중지"""
        if self.log_file:
            self.log_metrics()
            self.log_file = None
            
    def log_metrics(self):
        """메트릭 로깅"""
        if not self.log_file:
            return
            
        metrics = self.metrics.get_metrics_summary()
        metrics['timestamp'] = time.time()
        metrics['frame'] = self.metrics.frame_count
        
        try:
            # 기존 로그 읽기
            try:
                with open(self.log_file, 'r') as f:
                    logs = json.load(f)
            except:
                logs = []
                
            # 새 메트릭 추가
            logs.append(metrics)
            
            # 최대 1000개 항목 유지
            if len(logs) > 1000:
                logs = logs[-1000:]
                
            # 저장
            with open(self.log_file, 'w') as f:
                json.dump(logs, f, indent=2)
                
        except Exception as e:
            print(f"로깅 실패: {e}")
            
    def get_optimization_suggestions(self) -> List[str]:
        """최적화 제안 반환"""
        suggestions = []
        metrics = self.metrics.get_metrics_summary()
        
        # FPS 체크
        if metrics['fps']['average'] < self.fps_critical:
            suggestions.append("심각한 FPS 저하 - 렌더링 최적화 필요")
        elif metrics['fps']['average'] < self.fps_warning:
            suggestions.append("FPS 저하 감지 - 성능 점검 필요")
            
        # 프레임 타임 체크
        if metrics['frame_time']['average'] > self.frame_time_critical:
            suggestions.append("프레임 타임이 너무 높음 - 무거운 연산 최적화 필요")
            
        # 드로우 콜 체크
        if metrics['rendering']['draw_calls'] > 100:
            suggestions.append("드로우 콜이 많음 - 배치 렌더링 고려")
            
        # 파티클 체크
        if metrics['rendering']['particles'] > 500:
            suggestions.append("파티클이 너무 많음 - 파티클 수 제한 필요")
            
        # 섹션별 체크
        for section, time_ms in metrics['sections'].items():
            if time_ms > 10:
                suggestions.append(f"{section} 섹션 최적화 필요 ({time_ms}ms)")
                
        # 메모리 체크
        if metrics['memory']['current_mb'] > 500:
            suggestions.append("메모리 사용량이 높음 - 메모리 누수 점검 필요")
            
        return suggestions


# 싱글톤 인스턴스
_profiler = None

def get_profiler() -> Optional[GameProfiler]:
    """프로파일러 인스턴스 반환"""
    return _profiler
    
def init_profiler(screen: pygame.Surface, enabled: bool = True) -> GameProfiler:
    """프로파일러 초기화"""
    global _profiler
    _profiler = GameProfiler(screen, enabled)
    return _profiler