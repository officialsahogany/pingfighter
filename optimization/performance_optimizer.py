#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
⚡ 성능 최적화 도구
게임 성능을 측정하고 최적화합니다
"""

import pygame
import time
import sys
import os
import cProfile
import pstats
from typing import Dict, List, Tuple, Any
from dataclasses import dataclass
from enum import Enum

# 프로젝트 경로 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class OptimizationLevel(Enum):
    """최적화 레벨"""
    NONE = 0        # 최적화 없음
    BASIC = 1       # 기본 최적화
    MODERATE = 2    # 중간 최적화
    AGGRESSIVE = 3  # 공격적 최적화
    EXTREME = 4     # 극한 최적화


@dataclass
class PerformanceMetrics:
    """성능 측정 지표"""
    fps: float
    frame_time_ms: float
    update_time_ms: float
    render_time_ms: float
    memory_usage_mb: float
    cpu_usage_percent: float
    draw_calls: int
    particle_count: int
    entity_count: int


class PerformanceOptimizer:
    """
    ⚡ 성능 최적화 관리자
    
    게임 성능을 측정하고 병목 지점을 찾아 최적화합니다.
    """
    
    def __init__(self):
        """성능 최적화 도구 초기화"""
        self.optimization_level = OptimizationLevel.BASIC
        self.metrics_history: List[PerformanceMetrics] = []
        self.profiler = None
        self.frame_times: List[float] = []
        self.optimization_settings = self._get_default_settings()
        
        print("⚡ 성능 최적화 도구 초기화")
    
    def _get_default_settings(self) -> Dict[str, Any]:
        """기본 최적화 설정"""
        return {
            # 렌더링 최적화
            'use_dirty_rects': False,
            'enable_vsync': True,
            'max_particles': 500,
            'particle_pool_size': 1000,
            'texture_cache_size': 100,
            
            # 물리 최적화
            'physics_substeps': 1,
            'collision_broad_phase': True,
            'spatial_grid_size': 50,
            
            # AI 최적화
            'ai_update_frequency': 10,  # 10 프레임마다 업데이트
            'prediction_cache_size': 20,
            
            # 메모리 최적화
            'object_pooling': True,
            'max_entities': 100,
            'cache_enabled': True,
            
            # 프레임 제한
            'target_fps': 60,
            'frame_skip': False,
            'max_frame_skip': 3,
        }
    
    def apply_optimization_level(self, level: OptimizationLevel):
        """
        최적화 레벨 적용
        
        Args:
            level: 적용할 최적화 레벨
        """
        self.optimization_level = level
        
        if level == OptimizationLevel.NONE:
            # 최적화 없음
            self.optimization_settings = self._get_default_settings()
            
        elif level == OptimizationLevel.BASIC:
            # 기본 최적화
            self.optimization_settings.update({
                'use_dirty_rects': False,
                'max_particles': 500,
                'physics_substeps': 1,
                'ai_update_frequency': 10,
            })
            
        elif level == OptimizationLevel.MODERATE:
            # 중간 최적화
            self.optimization_settings.update({
                'use_dirty_rects': True,
                'max_particles': 300,
                'physics_substeps': 1,
                'ai_update_frequency': 15,
                'frame_skip': True,
                'max_frame_skip': 2,
            })
            
        elif level == OptimizationLevel.AGGRESSIVE:
            # 공격적 최적화
            self.optimization_settings.update({
                'use_dirty_rects': True,
                'max_particles': 200,
                'physics_substeps': 1,
                'ai_update_frequency': 20,
                'frame_skip': True,
                'max_frame_skip': 3,
                'texture_cache_size': 50,
            })
            
        elif level == OptimizationLevel.EXTREME:
            # 극한 최적화
            self.optimization_settings.update({
                'use_dirty_rects': True,
                'enable_vsync': False,
                'max_particles': 100,
                'physics_substeps': 1,
                'ai_update_frequency': 30,
                'frame_skip': True,
                'max_frame_skip': 5,
                'texture_cache_size': 30,
                'max_entities': 50,
            })
        
        print(f"⚡ 최적화 레벨 적용: {level.name}")
    
    def start_profiling(self):
        """프로파일링 시작"""
        self.profiler = cProfile.Profile()
        self.profiler.enable()
        print("📊 프로파일링 시작...")
    
    def stop_profiling(self, output_file: str = "profile_results.txt"):
        """
        프로파일링 중지 및 결과 저장
        
        Args:
            output_file: 결과 파일 경로
        """
        if self.profiler:
            self.profiler.disable()
            
            # 통계 생성
            stats = pstats.Stats(self.profiler)
            stats.sort_stats('cumulative')
            
            # 파일로 저장
            with open(output_file, 'w') as f:
                stats.stream = f
                stats.print_stats(30)  # 상위 30개 함수
            
            print(f"📊 프로파일링 결과 저장: {output_file}")
            
            # 콘솔 출력
            print("\n🔥 성능 병목 지점 (상위 10개):")
            stats.print_stats(10)
            
            self.profiler = None
    
    def measure_frame_performance(self, 
                                 update_time: float,
                                 render_time: float,
                                 entities: Dict[str, Any]) -> PerformanceMetrics:
        """
        프레임 성능 측정
        
        Args:
            update_time: 업데이트 시간
            render_time: 렌더링 시간
            entities: 엔티티 정보
            
        Returns:
            성능 지표
        """
        # FPS 계산
        frame_time = update_time + render_time
        fps = 1.0 / frame_time if frame_time > 0 else 0
        
        # 메모리 사용량 (대략적 추정)
        import psutil
        process = psutil.Process()
        memory_mb = process.memory_info().rss / 1024 / 1024
        cpu_percent = process.cpu_percent()
        
        # 엔티티 수 계산
        entity_count = sum(len(v) if isinstance(v, list) else 1 
                          for v in entities.values())
        
        metrics = PerformanceMetrics(
            fps=fps,
            frame_time_ms=frame_time * 1000,
            update_time_ms=update_time * 1000,
            render_time_ms=render_time * 1000,
            memory_usage_mb=memory_mb,
            cpu_usage_percent=cpu_percent,
            draw_calls=0,  # 렌더링 시스템에서 가져와야 함
            particle_count=entities.get('particles', 0),
            entity_count=entity_count
        )
        
        self.metrics_history.append(metrics)
        
        # 최근 60프레임만 유지
        if len(self.metrics_history) > 60:
            self.metrics_history.pop(0)
        
        return metrics
    
    def get_average_metrics(self) -> PerformanceMetrics:
        """평균 성능 지표 계산"""
        if not self.metrics_history:
            return PerformanceMetrics(0, 0, 0, 0, 0, 0, 0, 0, 0)
        
        n = len(self.metrics_history)
        
        return PerformanceMetrics(
            fps=sum(m.fps for m in self.metrics_history) / n,
            frame_time_ms=sum(m.frame_time_ms for m in self.metrics_history) / n,
            update_time_ms=sum(m.update_time_ms for m in self.metrics_history) / n,
            render_time_ms=sum(m.render_time_ms for m in self.metrics_history) / n,
            memory_usage_mb=sum(m.memory_usage_mb for m in self.metrics_history) / n,
            cpu_usage_percent=sum(m.cpu_usage_percent for m in self.metrics_history) / n,
            draw_calls=sum(m.draw_calls for m in self.metrics_history) / n,
            particle_count=sum(m.particle_count for m in self.metrics_history) / n,
            entity_count=sum(m.entity_count for m in self.metrics_history) / n
        )
    
    def optimize_render_system(self, render_system: Any):
        """
        렌더링 시스템 최적화
        
        Args:
            render_system: 렌더링 시스템 인스턴스
        """
        settings = self.optimization_settings
        
        # Dirty Rect 최적화
        render_system.use_dirty_rects = settings['use_dirty_rects']
        
        # 파티클 제한
        render_system.max_particles = settings['max_particles']
        
        print("🎨 렌더링 시스템 최적화 적용")
    
    def optimize_physics_engine(self, physics_engine: Any):
        """
        물리 엔진 최적화
        
        Args:
            physics_engine: 물리 엔진 인스턴스
        """
        settings = self.optimization_settings
        
        # Broad Phase 충돌 감지
        if hasattr(physics_engine, 'use_broad_phase'):
            physics_engine.use_broad_phase = settings['collision_broad_phase']
        
        print("⚡ 물리 엔진 최적화 적용")
    
    def optimize_ai_system(self, ai_system: Any):
        """
        AI 시스템 최적화
        
        Args:
            ai_system: AI 시스템 인스턴스
        """
        settings = self.optimization_settings
        
        # AI 업데이트 빈도 조절
        if hasattr(ai_system, 'update_frequency'):
            ai_system.update_frequency = settings['ai_update_frequency']
        
        print("🤖 AI 시스템 최적화 적용")
    
    def generate_optimization_report(self) -> str:
        """최적화 보고서 생성"""
        avg_metrics = self.get_average_metrics()
        
        report = []
        report.append("="*60)
        report.append("⚡ 성능 최적화 보고서")
        report.append("="*60)
        
        report.append(f"\n📊 현재 최적화 레벨: {self.optimization_level.name}")
        
        report.append("\n🎮 평균 성능 지표:")
        report.append(f"  FPS: {avg_metrics.fps:.1f}")
        report.append(f"  프레임 시간: {avg_metrics.frame_time_ms:.2f}ms")
        report.append(f"  업데이트 시간: {avg_metrics.update_time_ms:.2f}ms")
        report.append(f"  렌더링 시간: {avg_metrics.render_time_ms:.2f}ms")
        report.append(f"  메모리 사용량: {avg_metrics.memory_usage_mb:.1f}MB")
        report.append(f"  CPU 사용률: {avg_metrics.cpu_usage_percent:.1f}%")
        
        report.append("\n⚙️ 최적화 설정:")
        for key, value in self.optimization_settings.items():
            report.append(f"  {key}: {value}")
        
        # 권장사항
        report.append("\n💡 권장사항:")
        
        if avg_metrics.fps < 30:
            report.append("  🔴 FPS가 30 미만입니다. 더 높은 최적화 레벨을 권장합니다.")
        elif avg_metrics.fps < 60:
            report.append("  ⚠️ FPS가 60 미만입니다. 중간 최적화를 고려하세요.")
        else:
            report.append("  ✅ FPS가 양호합니다.")
        
        if avg_metrics.memory_usage_mb > 500:
            report.append("  ⚠️ 메모리 사용량이 높습니다. 객체 풀링을 활성화하세요.")
        
        if avg_metrics.render_time_ms > 10:
            report.append("  ⚠️ 렌더링 시간이 깁니다. Dirty Rect 최적화를 활성화하세요.")
        
        report.append("="*60)
        
        return "\n".join(report)


def benchmark_game():
    """게임 벤치마크 실행"""
    print("\n🎮 게임 성능 벤치마크 시작...")
    
    optimizer = PerformanceOptimizer()
    
    # 각 최적화 레벨 테스트
    for level in OptimizationLevel:
        print(f"\n테스트: {level.name} 레벨")
        optimizer.apply_optimization_level(level)
        
        # 간단한 시뮬레이션 (실제로는 게임 루프 실행)
        for _ in range(60):  # 60프레임 시뮬레이션
            update_time = 0.008  # 8ms
            render_time = 0.006  # 6ms
            entities = {'particles': 100, 'enemies': 5}
            
            optimizer.measure_frame_performance(
                update_time, render_time, entities
            )
        
        # 평균 성능 출력
        avg = optimizer.get_average_metrics()
        print(f"  평균 FPS: {avg.fps:.1f}")
        print(f"  평균 프레임 시간: {avg.frame_time_ms:.2f}ms")
    
    # 최종 보고서
    report = optimizer.generate_optimization_report()
    print(report)
    
    return optimizer


if __name__ == "__main__":
    # psutil 설치 확인
    try:
        import psutil
    except ImportError:
        print("⚠️ psutil이 설치되지 않았습니다.")
        print("   pip install psutil")
        sys.exit(1)
    
    benchmark_game()