"""
Test Framework - 테스트 프레임워크
단위 테스트와 통합 테스트를 위한 기본 프레임워크
"""

import unittest
import pygame
import sys
import os
from typing import Any, Dict, List

# 프로젝트 경로 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class GameTestCase(unittest.TestCase):
    """게임 테스트 케이스 베이스 클래스"""
    
    @classmethod
    def setUpClass(cls):
        """테스트 클래스 설정"""
        pygame.init()
        pygame.display.set_mode((1, 1))  # 최소 크기 윈도우
        
    @classmethod
    def tearDownClass(cls):
        """테스트 클래스 정리"""
        pygame.quit()
        
    def setUp(self):
        """각 테스트 전 설정"""
        self.test_data = {}
        
    def tearDown(self):
        """각 테스트 후 정리"""
        self.test_data.clear()
        
    def assert_in_range(self, value: float, min_val: float, max_val: float, msg: str = None):
        """값이 범위 내에 있는지 확인"""
        if msg is None:
            msg = f"{value} is not in range [{min_val}, {max_val}]"
        self.assertTrue(min_val <= value <= max_val, msg)
        
    def assert_vector_equal(self, vec1: tuple, vec2: tuple, tolerance: float = 0.01):
        """벡터가 같은지 확인 (오차 허용)"""
        self.assertEqual(len(vec1), len(vec2), "Vectors have different dimensions")
        for i, (v1, v2) in enumerate(zip(vec1, vec2)):
            self.assertAlmostEqual(v1, v2, delta=tolerance, 
                                 msg=f"Vector component {i} differs: {v1} != {v2}")


class MockGameState:
    """게임 상태 모의 객체"""
    
    def __init__(self):
        self.data = {
            'ball_position': (300, 375),
            'ball_velocity': (0, -8),
            'player_x': 300,
            'player_y': 650,
            'boss_x': 300,
            'boss_y': 100,
            'player_score': 0,
            'boss_score': 0,
            'current_stage': 1,
            'game_time': 0
        }
        
    def get(self, key: str, default: Any = None) -> Any:
        return self.data.get(key, default)
        
    def set(self, key: str, value: Any):
        self.data[key] = value
        
    def update(self, updates: Dict[str, Any]):
        self.data.update(updates)


class MockEvent:
    """이벤트 모의 객체"""
    
    def __init__(self, event_type: str, data: Dict[str, Any] = None):
        self.type = event_type
        self.data = data or {}
        self.handled = False


class TestRunner:
    """테스트 실행기"""
    
    def __init__(self, verbosity: int = 2):
        self.verbosity = verbosity
        self.test_results = []
        
    def run_tests(self, test_module: str = None):
        """테스트 실행
        
        Args:
            test_module: 특정 모듈만 테스트 (None이면 전체)
        """
        if test_module:
            suite = unittest.TestLoader().loadTestsFromName(test_module)
        else:
            suite = unittest.TestLoader().discover('tests', pattern='test_*.py')
            
        runner = unittest.TextTestRunner(verbosity=self.verbosity)
        result = runner.run(suite)
        
        self.test_results.append({
            'tests_run': result.testsRun,
            'failures': len(result.failures),
            'errors': len(result.errors),
            'success': result.wasSuccessful()
        })
        
        return result
        
    def run_specific_test(self, test_class: str, test_method: str):
        """특정 테스트 메서드 실행
        
        Args:
            test_class: 테스트 클래스 이름
            test_method: 테스트 메서드 이름
        """
        test_name = f"{test_class}.{test_method}"
        suite = unittest.TestLoader().loadTestsFromName(test_name)
        
        runner = unittest.TextTestRunner(verbosity=self.verbosity)
        return runner.run(suite)
        
    def get_summary(self) -> Dict[str, Any]:
        """테스트 요약 반환"""
        if not self.test_results:
            return {}
            
        total_tests = sum(r['tests_run'] for r in self.test_results)
        total_failures = sum(r['failures'] for r in self.test_results)
        total_errors = sum(r['errors'] for r in self.test_results)
        
        return {
            'total_tests': total_tests,
            'total_failures': total_failures,
            'total_errors': total_errors,
            'success_rate': (total_tests - total_failures - total_errors) / max(total_tests, 1) * 100
        }


class PerformanceTest:
    """성능 테스트 유틸리티"""
    
    def __init__(self):
        self.measurements = []
        
    def measure_fps(self, duration: float = 5.0) -> float:
        """FPS 측정
        
        Args:
            duration: 측정 시간 (초)
            
        Returns:
            평균 FPS
        """
        clock = pygame.time.Clock()
        frames = 0
        start_time = pygame.time.get_ticks()
        
        while (pygame.time.get_ticks() - start_time) / 1000 < duration:
            clock.tick()
            frames += 1
            
        elapsed = (pygame.time.get_ticks() - start_time) / 1000
        avg_fps = frames / elapsed
        
        self.measurements.append({
            'type': 'fps',
            'value': avg_fps,
            'duration': duration
        })
        
        return avg_fps
        
    def measure_memory(self) -> Dict[str, float]:
        """메모리 사용량 측정"""
        import psutil
        import os
        
        process = psutil.Process(os.getpid())
        memory_info = process.memory_info()
        
        memory_data = {
            'rss_mb': memory_info.rss / 1024 / 1024,
            'vms_mb': memory_info.vms / 1024 / 1024,
            'percent': process.memory_percent()
        }
        
        self.measurements.append({
            'type': 'memory',
            'value': memory_data
        })
        
        return memory_data
        
    def benchmark_function(self, func, *args, iterations: int = 1000, **kwargs) -> float:
        """함수 벤치마크
        
        Args:
            func: 테스트할 함수
            iterations: 반복 횟수
            
        Returns:
            평균 실행 시간 (ms)
        """
        import time
        
        times = []
        for _ in range(iterations):
            start = time.perf_counter()
            func(*args, **kwargs)
            end = time.perf_counter()
            times.append((end - start) * 1000)  # ms로 변환
            
        avg_time = sum(times) / len(times)
        
        self.measurements.append({
            'type': 'benchmark',
            'function': func.__name__,
            'avg_time_ms': avg_time,
            'iterations': iterations
        })
        
        return avg_time
        
    def get_report(self) -> str:
        """성능 보고서 생성"""
        if not self.measurements:
            return "No measurements available"
            
        report = ["=== Performance Report ===\n"]
        
        for measure in self.measurements:
            if measure['type'] == 'fps':
                report.append(f"FPS: {measure['value']:.1f} (measured over {measure['duration']}s)")
            elif measure['type'] == 'memory':
                mem = measure['value']
                report.append(f"Memory: RSS={mem['rss_mb']:.1f}MB, VMS={mem['vms_mb']:.1f}MB, {mem['percent']:.1f}%")
            elif measure['type'] == 'benchmark':
                report.append(f"Benchmark '{measure['function']}': {measure['avg_time_ms']:.3f}ms avg ({measure['iterations']} iterations)")
                
        return "\n".join(report)


# 테스트 실행 헬퍼
def run_all_tests(verbosity: int = 2):
    """모든 테스트 실행"""
    runner = TestRunner(verbosity)
    result = runner.run_tests()
    
    print("\n" + "="*50)
    summary = runner.get_summary()
    print(f"Tests Run: {summary['total_tests']}")
    print(f"Failures: {summary['total_failures']}")
    print(f"Errors: {summary['total_errors']}")
    print(f"Success Rate: {summary['success_rate']:.1f}%")
    print("="*50)
    
    return result.wasSuccessful()


if __name__ == "__main__":
    # 테스트 실행
    success = run_all_tests()
    sys.exit(0 if success else 1)