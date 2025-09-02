"""
Performance Optimization Report Generator
성능 프로파일링 결과를 분석하여 최적화 제안을 생성하는 도구
"""

import json
import os
from datetime import datetime
from typing import List, Dict, Any


class OptimizationReporter:
    """성능 최적화 리포터"""
    
    def __init__(self, log_file: str = "performance_log.json"):
        self.log_file = log_file
        self.report = []
        
    def load_performance_data(self) -> List[Dict[str, Any]]:
        """성능 로그 파일 로드"""
        if not os.path.exists(self.log_file):
            print(f"로그 파일 {self.log_file}을 찾을 수 없습니다.")
            return []
            
        try:
            with open(self.log_file, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"로그 파일 로드 실패: {e}")
            return []
            
    def analyze_fps(self, data: List[Dict]) -> Dict:
        """FPS 분석"""
        if not data:
            return {}
            
        fps_values = []
        for entry in data:
            if 'fps' in entry and 'current' in entry['fps']:
                fps_values.append(entry['fps']['current'])
                
        if not fps_values:
            return {}
            
        avg_fps = sum(fps_values) / len(fps_values)
        min_fps = min(fps_values)
        max_fps = max(fps_values)
        
        # FPS 저하 횟수 계산
        low_fps_count = sum(1 for fps in fps_values if fps < 30)
        critical_fps_count = sum(1 for fps in fps_values if fps < 20)
        
        return {
            'average': avg_fps,
            'min': min_fps,
            'max': max_fps,
            'low_count': low_fps_count,
            'critical_count': critical_fps_count,
            'stability': (max_fps - min_fps) / avg_fps if avg_fps > 0 else 0
        }
        
    def analyze_memory(self, data: List[Dict]) -> Dict:
        """메모리 사용량 분석"""
        if not data:
            return {}
            
        memory_values = []
        for entry in data:
            if 'memory' in entry and 'current_mb' in entry['memory']:
                memory_values.append(entry['memory']['current_mb'])
                
        if not memory_values:
            return {}
            
        avg_memory = sum(memory_values) / len(memory_values)
        max_memory = max(memory_values)
        min_memory = min(memory_values)
        
        # 메모리 증가 추세 분석
        if len(memory_values) > 10:
            early_avg = sum(memory_values[:10]) / 10
            late_avg = sum(memory_values[-10:]) / 10
            memory_growth = late_avg - early_avg
        else:
            memory_growth = 0
            
        return {
            'average': avg_memory,
            'max': max_memory,
            'min': min_memory,
            'growth': memory_growth,
            'leak_suspected': memory_growth > 50
        }
        
    def analyze_sections(self, data: List[Dict]) -> Dict:
        """섹션별 성능 분석"""
        if not data:
            return {}
            
        section_times = {}
        section_counts = {}
        
        for entry in data:
            if 'sections' in entry:
                for section, time_ms in entry['sections'].items():
                    if section not in section_times:
                        section_times[section] = []
                        section_counts[section] = 0
                    section_times[section].append(time_ms)
                    section_counts[section] += 1
                    
        section_stats = {}
        for section, times in section_times.items():
            if times:
                section_stats[section] = {
                    'average': sum(times) / len(times),
                    'max': max(times),
                    'min': min(times),
                    'count': section_counts[section]
                }
                
        return section_stats
        
    def generate_recommendations(self, fps_stats: Dict, memory_stats: Dict, 
                                section_stats: Dict) -> List[str]:
        """최적화 제안 생성"""
        recommendations = []
        
        # FPS 최적화 제안
        if fps_stats:
            if fps_stats.get('average', 60) < 30:
                recommendations.append({
                    'priority': 'CRITICAL',
                    'category': 'FPS',
                    'issue': f"평균 FPS가 {fps_stats['average']:.1f}로 매우 낮음",
                    'suggestions': [
                        "렌더링 최적화 필요 - draw call 감소",
                        "파티클 시스템 최적화",
                        "불필요한 그래픽 효과 제거",
                        "스프라이트 배칭 구현"
                    ]
                })
            elif fps_stats.get('average', 60) < 50:
                recommendations.append({
                    'priority': 'HIGH',
                    'category': 'FPS',
                    'issue': f"평균 FPS가 {fps_stats['average']:.1f}로 낮음",
                    'suggestions': [
                        "복잡한 계산을 여러 프레임에 분산",
                        "업데이트 빈도 최적화",
                        "충돌 감지 최적화"
                    ]
                })
                
            if fps_stats.get('stability', 0) > 0.5:
                recommendations.append({
                    'priority': 'MEDIUM',
                    'category': 'FPS',
                    'issue': "FPS 변동이 심함",
                    'suggestions': [
                        "일정한 프레임 타임 유지",
                        "가변적인 작업 분산",
                        "프레임 스킵 로직 구현"
                    ]
                })
                
        # 메모리 최적화 제안
        if memory_stats:
            if memory_stats.get('leak_suspected', False):
                recommendations.append({
                    'priority': 'CRITICAL',
                    'category': 'MEMORY',
                    'issue': f"메모리 누수 의심 (증가량: {memory_stats['growth']:.1f}MB)",
                    'suggestions': [
                        "순환 참조 확인",
                        "이벤트 리스너 정리",
                        "사용하지 않는 객체 제거",
                        "텍스처/이미지 캐시 관리"
                    ]
                })
            elif memory_stats.get('max', 0) > 500:
                recommendations.append({
                    'priority': 'HIGH',
                    'category': 'MEMORY',
                    'issue': f"최대 메모리 사용량이 {memory_stats['max']:.1f}MB로 높음",
                    'suggestions': [
                        "리소스 로딩 최적화",
                        "필요시 로딩 구현",
                        "텍스처 압축 사용",
                        "객체 풀링 구현"
                    ]
                })
                
        # 섹션별 최적화 제안
        if section_stats:
            slow_sections = []
            for section, stats in section_stats.items():
                if stats['average'] > 10:
                    slow_sections.append((section, stats['average']))
                    
            if slow_sections:
                slow_sections.sort(key=lambda x: x[1], reverse=True)
                for section, time_ms in slow_sections[:3]:  # 상위 3개만
                    recommendations.append({
                        'priority': 'HIGH' if time_ms > 15 else 'MEDIUM',
                        'category': 'PERFORMANCE',
                        'issue': f"{section} 섹션이 평균 {time_ms:.1f}ms 소요",
                        'suggestions': [
                            f"{section} 로직 최적화",
                            "알고리즘 개선",
                            "캐싱 구현",
                            "불필요한 계산 제거"
                        ]
                    })
                    
        return recommendations
        
    def generate_report(self) -> str:
        """최적화 리포트 생성"""
        data = self.load_performance_data()
        if not data:
            return "성능 데이터가 없습니다. 게임을 실행하고 프로파일링을 활성화해주세요."
            
        # 분석 수행
        fps_stats = self.analyze_fps(data)
        memory_stats = self.analyze_memory(data)
        section_stats = self.analyze_sections(data)
        
        # 제안 생성
        recommendations = self.generate_recommendations(fps_stats, memory_stats, section_stats)
        
        # 리포트 작성
        report = []
        report.append("=" * 70)
        report.append("           BOSSPONG 성능 최적화 리포트")
        report.append("=" * 70)
        report.append(f"생성 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        report.append(f"분석 데이터: {len(data)} 프레임")
        report.append("")
        
        # FPS 통계
        report.append("-" * 70)
        report.append("📊 FPS 분석")
        report.append("-" * 70)
        if fps_stats:
            report.append(f"평균 FPS: {fps_stats['average']:.1f}")
            report.append(f"최소 FPS: {fps_stats['min']:.1f}")
            report.append(f"최대 FPS: {fps_stats['max']:.1f}")
            report.append(f"30 FPS 미만 횟수: {fps_stats['low_count']}")
            report.append(f"20 FPS 미만 횟수: {fps_stats['critical_count']}")
        report.append("")
        
        # 메모리 통계
        report.append("-" * 70)
        report.append("💾 메모리 분석")
        report.append("-" * 70)
        if memory_stats:
            report.append(f"평균 메모리: {memory_stats['average']:.1f} MB")
            report.append(f"최대 메모리: {memory_stats['max']:.1f} MB")
            report.append(f"최소 메모리: {memory_stats['min']:.1f} MB")
            report.append(f"메모리 증가량: {memory_stats['growth']:.1f} MB")
            if memory_stats['leak_suspected']:
                report.append("⚠️ 메모리 누수 의심됨!")
        report.append("")
        
        # 섹션별 성능
        if section_stats:
            report.append("-" * 70)
            report.append("⏱️ 섹션별 성능")
            report.append("-" * 70)
            sorted_sections = sorted(section_stats.items(), 
                                    key=lambda x: x[1]['average'], 
                                    reverse=True)
            for section, stats in sorted_sections[:5]:  # 상위 5개만
                report.append(f"{section:20s}: 평균 {stats['average']:6.2f}ms, "
                            f"최대 {stats['max']:6.2f}ms")
        report.append("")
        
        # 최적화 제안
        report.append("=" * 70)
        report.append("🚀 최적화 제안")
        report.append("=" * 70)
        
        if recommendations:
            # 우선순위별 정렬
            priority_order = {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3}
            recommendations.sort(key=lambda x: priority_order.get(x['priority'], 99))
            
            for i, rec in enumerate(recommendations, 1):
                report.append("")
                report.append(f"{i}. [{rec['priority']}] {rec['category']}: {rec['issue']}")
                report.append("   제안사항:")
                for suggestion in rec['suggestions']:
                    report.append(f"   - {suggestion}")
        else:
            report.append("특별한 최적화가 필요하지 않습니다. 성능이 양호합니다!")
            
        report.append("")
        report.append("=" * 70)
        report.append("리포트 종료")
        report.append("=" * 70)
        
        return "\n".join(report)
        
    def save_report(self, filename: str = "optimization_report.txt"):
        """리포트를 파일로 저장"""
        report = self.generate_report()
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(report)
        print(f"최적화 리포트가 {filename}에 저장되었습니다.")
        return report


if __name__ == "__main__":
    # 리포터 생성 및 실행
    reporter = OptimizationReporter()
    
    # 리포트 생성 및 출력
    report = reporter.generate_report()
    print(report)
    
    # 파일로 저장
    reporter.save_report()
    
    print("\n최적화 리포트 생성이 완료되었습니다!")