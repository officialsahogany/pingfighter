"""
플레이어 실력 분석 및 등급 시스템
Player Skill Analysis and Ranking System
"""

import time
import math
from collections import deque
from dataclasses import dataclass, field
from typing import Dict, List, Tuple, Optional

@dataclass
class PlayerStats:
    """플레이어 통계 데이터"""
    # 기본 통계
    total_hits: int = 0
    total_misses: int = 0
    total_games: int = 0
    total_rounds: int = 0
    
    # 고급 통계
    perfect_timing_hits: int = 0  # 완벽한 타이밍으로 친 횟수
    power_smash_success: int = 0  # 파워스매시 성공
    skill_usage_count: int = 0    # 스킬 사용 횟수
    skill_success_count: int = 0  # 스킬 성공 횟수
    
    # 대쉬 활용 관련
    dash_usage_count: int = 0     # 대쉬 사용 횟수
    dash_success_count: int = 0   # 대쉬 성공 횟수 (공을 성공적으로 쳤을 때)
    dash_situations: List[str] = field(default_factory=list)  # 대쉬 사용 상황 기록
    good_dash_count: int = 0      # 적절한 상황에서의 대쉬 사용
    
    # 아이템 활용 관련
    items_used_count: int = 0     # 아이템 사용 횟수
    items_effective_count: int = 0  # 효과적인 아이템 사용 횟수
    item_types_used: List[str] = field(default_factory=list)  # 사용한 아이템 종류
    item_combo_count: int = 0     # 아이템 조합 사용 횟수
    
    # 가드 능력 관련
    successful_guards: int = 0    # 성공적인 방어 횟수
    defensive_saves: int = 0      # 위험한 상황에서의 구원 타격
    close_call_recoveries: int = 0  # 아슬아슬한 상황 회복
    
    # 평가 시스템 관련 (실시간 평가로 변경)
    evaluation_stages_completed: int = 0  # 완료한 스테이지 수 (기록용)
    show_final_results: bool = False      # 게임 종료 시 결과 표시
    
    # 새로운 평가 기준들
    skill_victories: int = 0              # 스킬로 승리한 횟수 (드라이브/파워스매싱으로 득점)
    dash_life_saves: int = 0             # 대쉬로 생명을 구한 횟수
    dash_victories: int = 0              # 대쉬로 승리한 횟수
    dash_defensive_saves: int = 0        # 대쉬로 불가능한 영역에서 가드한 횟수 (신규)
    dash_clutch_victories: int = 0       # 대쉬 공격으로 직접 승리한 횟수 (신규)
    speed_adaptation_bonus: int = 0      # 공속도 증가에 따른 적응 점수 (신규)
    item_clutch_uses: int = 0            # 상황에 맞는 아이템 사용
    
    # 승부 결과 보너스 (신규)
    perfect_victories: int = 0           # 3-0 완승 횟수
    dominant_victories: int = 0          # 3-1 승리 횟수
    close_victories: int = 0             # 3-2 승리 횟수
    
    # 실수 및 페널티 기록 (신규)
    critical_misses: int = 0             # 치명적인 실수 (쉬운 공을 놓침)
    poor_timing_hits: int = 0            # 타이밍이 나쁜 히트
    wasted_skills: int = 0               # 무의미하게 낭비된 스킬 사용
    wasted_dash: int = 0                 # 무의미하게 낭비된 대쉬 사용
    missed_opportunities: int = 0        # 놓친 기회 (좋은 상황에서 실수)
    consecutive_losses: int = 0          # 연속 패배 (0-3, 1-3, 2-3)
    
    # 스테이지별 성과
    stage_clears: Dict[int, int] = field(default_factory=dict)
    stage_attempts: Dict[int, int] = field(default_factory=dict)
    
    # 연속 성공/실패
    current_hit_streak: int = 0
    max_hit_streak: int = 0
    current_miss_streak: int = 0
    
    # 반응 시간 (초 단위)
    reaction_times: deque = field(default_factory=lambda: deque(maxlen=50))
    
    # 정확도 히스토리
    accuracy_history: deque = field(default_factory=lambda: deque(maxlen=20))
    
    # 게임 세션 시간
    session_start_time: float = field(default_factory=time.time)
    total_play_time: float = 0.0

class SkillRank:
    """실력 등급 정의"""
    
    RANKS = [
        {
            "name": "초보",
            "name_en": "Beginner", 
            "icon": "🎯",
            "color": (150, 150, 150),  # 회색
            "min_score": 0,
            "description": "연습이 필요해요",
            "details": "기본기를 익히고 있는 단계"
        },
        {
            "name": "주니어",
            "name_en": "Junior",
            "icon": "🔰", 
            "color": (139, 69, 19),   # 갈색
            "min_score": 400,   # 균형잡힌 기준
            "description": "기본기를 익혔어요",
            "details": "공의 궤적을 예측할 수 있음"
        },
        {
            "name": "세미프로",
            "name_en": "Semi-Pro",
            "icon": "⭐",
            "color": (255, 215, 0),   # 금색
            "min_score": 650,   # 균형잡힌 기준
            "description": "숙련된 플레이어예요",
            "details": "스킬과 대쉬를 활용할 수 있음"
        },
        {
            "name": "프로",
            "name_en": "Pro", 
            "icon": "💎",
            "color": (0, 191, 255),   # 청색
            "min_score": 900,  # 균형잡힌 기준
            "description": "전문가 수준이에요",
            "details": "아이템과 전략을 효과적으로 활용"
        },
        {
            "name": "챔피언",
            "name_en": "Champion",
            "icon": "🏆",
            "color": (255, 20, 147),  # 핑크
            "min_score": 1300,  # 균형잡힌 기준
            "description": "거의 완벽해요",
            "details": "클러치 상황에서 뛰어난 대처 능력"
        },
        {
            "name": "신",
            "name_en": "God",
            "icon": "🌟",
            "color": (255, 215, 0),   # 황금색
            "min_score": 1700,  # 균형잡힌 기준
            "description": "완벽한 플레이어!",
            "details": "모든 면에서 뛰어난 마스터"
        }
    ]

class PlayerSkillAnalyzer:
    """플레이어 실력 분석 엔진"""
    
    def __init__(self):
        self.stats = PlayerStats()
        self.last_hit_time = None
        self._ensure_new_fields()  # 새 필드들 안전성 확보
        
    def _ensure_new_fields(self):
        """새로 추가된 필드들이 존재하는지 확인하고 없으면 추가"""
        new_fields = {
            'critical_misses': 0,
            'poor_timing_hits': 0,
            'wasted_skills': 0,
            'wasted_dash': 0,
            'missed_opportunities': 0,
            'consecutive_losses': 0,
            'perfect_victories': 0,
            'dominant_victories': 0,
            'close_victories': 0,
            'dash_defensive_saves': 0,
            'dash_clutch_victories': 0,
            'speed_adaptation_bonus': 0,
            'skill_uses': 0  # 빠진 필드 추가
        }
        
        for field_name, default_value in new_fields.items():
            if not hasattr(self.stats, field_name):
                setattr(self.stats, field_name, default_value)
        
    def record_hit(self, is_perfect_timing=False, is_power_smash=False):
        """히트 기록"""
        current_time = time.time()
        
        # 기본 통계 업데이트
        self.stats.total_hits += 1
        self.stats.current_hit_streak += 1
        self.stats.current_miss_streak = 0
        
        # 최대 연속 히트 업데이트
        if self.stats.current_hit_streak > self.stats.max_hit_streak:
            self.stats.max_hit_streak = self.stats.current_hit_streak
            
        # 특수 히트 기록
        if is_perfect_timing:
            self.stats.perfect_timing_hits += 1
            
        if is_power_smash:
            self.stats.power_smash_success += 1
            
        # 반응 시간 계산
        if self.last_hit_time:
            reaction_time = current_time - self.last_hit_time
            self.stats.reaction_times.append(reaction_time)
            
        self.last_hit_time = current_time
        
        # 정확도 히스토리 업데이트
        self._update_accuracy_history()
        
    def record_miss(self):
        """미스 기록"""
        self.stats.total_misses += 1
        self.stats.current_miss_streak += 1
        self.stats.current_hit_streak = 0
        
        # 정확도 히스토리 업데이트
        self._update_accuracy_history()
        
    def record_skill_usage(self, success=False):
        """스킬 사용 기록"""
        self.stats.skill_usage_count += 1
        if success:
            self.stats.skill_success_count += 1
            
    def record_dash_usage(self, ball_distance, ball_speed, success=False, situation="normal"):
        """대쉬 사용 기록"""
        # success=True는 이미 기록된 대쉬의 성공 여부만 업데이트
        if success:
            self.stats.dash_success_count += 1
            return  # 중복 처리 방지
            
        # success=False일 때만 새로운 대쉬 사용으로 카운트
        self.stats.dash_usage_count += 1
            
        # 대쉬 상황 분석
        if ball_distance > 150 and ball_speed > 8:
            # 멀리 있고 빠른 공 - 적절한 대쉬 사용
            self.stats.good_dash_count += 1
            situation = "urgent_rescue"
        elif ball_distance > 100:
            # 중간 거리 - 적절한 대쉬 사용
            self.stats.good_dash_count += 1
            situation = "tactical_move"
        elif ball_distance < 50:
            # 가까운 거리 - 불필요한 대쉬
            situation = "unnecessary"
        
        # 최근 10개 상황만 기록
        self.stats.dash_situations.append(situation)
        if len(self.stats.dash_situations) > 10:
            self.stats.dash_situations.pop(0)
            
    def record_item_usage(self, item_name, was_effective=False, is_combo=False):
        """아이템 사용 기록"""
        self.stats.items_used_count += 1
        
        if was_effective:
            self.stats.items_effective_count += 1
            
        if is_combo:
            self.stats.item_combo_count += 1
            
        # 사용한 아이템 종류 기록 (최근 20개만)
        if item_name not in self.stats.item_types_used:
            self.stats.item_types_used.append(item_name)
        if len(self.stats.item_types_used) > 20:
            self.stats.item_types_used.pop(0)
            
    def record_guard_action(self, ball_distance, ball_speed, is_close_call=False):
        """가드 능력 기록"""
        self.stats.successful_guards += 1
        
        # 위험한 상황 판단 (공이 매우 빠르거나 가까운 거리)
        if ball_speed > 15 or ball_distance < 30:
            self.stats.defensive_saves += 1
            
        # 아슬아슬한 상황 (매우 가까운 거리에서 성공)
        if is_close_call or ball_distance < 15:
            self.stats.close_call_recoveries += 1
            
    def record_skill_victory(self):
        """스킬로 승리한 경우 기록 (드라이브/파워스매싱으로 득점)"""
        self.stats.skill_victories += 1
        
    def record_dash_life_save(self):
        """대쉬로 생명을 구한 경우 기록"""
        self.stats.dash_life_saves += 1
        
    def record_dash_victory(self):
        """대쉬로 승리한 경우 기록"""
        self.stats.dash_victories += 1
        
    def record_dash_defensive_save(self):
        """대쉬로 불가능한 영역에서 가드한 횟수 기록"""
        self._ensure_new_fields()  # 안전성 확보
        self.stats.dash_defensive_saves += 1
        
    def record_dash_clutch_victory(self):
        """대쉬 공격으로 직접 승리한 횟수 기록"""
        self._ensure_new_fields()  # 안전성 확보
        self.stats.dash_clutch_victories += 1
        
    def record_speed_adaptation(self, ball_speed: float):
        """공속도 적응 점수 기록 - 균형잡힌 보상"""
        self._ensure_new_fields()  # 안전성 확보
        
        # 공속도가 빠를수록 더 많은 점수 (기준: 15 이상부터 보너스)
        if ball_speed >= 15:
            bonus_points = int((ball_speed - 15) * 2)  # 속도 1당 2점
            self.stats.speed_adaptation_bonus += min(bonus_points, 15)  # 최대 15점
        
        # 특별히 빠른 공 (25+ 속도)에 대한 추가 보너스
        if ball_speed >= 25:
            extra_bonus = int((ball_speed - 25) * 2)  # 초고속 보너스
            self.stats.speed_adaptation_bonus += min(extra_bonus, 10)  # 최대 10점 추가
        
    def record_item_clutch_use(self):
        """상황에 맞는 아이템 사용 기록"""
        self.stats.item_clutch_uses += 1
        
    def record_victory_result(self, player_wins: int, boss_wins: int):
        """승부 결과 기록 (3-0, 3-1, 3-2 등)"""
        self._ensure_new_fields()  # 안전성 확보
        
        if player_wins == 3:  # 플레이어 승리
            # 승리시 연속 패배 리셋
            if self.stats.consecutive_losses > 0:
                print(f"🏆 {self.stats.consecutive_losses}연패 끊기! 연속 패배 리셋!")
                self.stats.consecutive_losses = 0
            
            if boss_wins == 0:
                self.stats.perfect_victories += 1  # 3-0 완승
                print("🏆 완벽한 승리! (3-0) - 엄청난 보너스!")
            elif boss_wins == 1:
                self.stats.dominant_victories += 1  # 3-1 압승
                print("🏆 압도적인 승리! (3-1) - 높은 보너스!")
            elif boss_wins == 2:
                self.stats.close_victories += 1  # 3-2 승리
                print("🏆 치열한 승리! (3-2) - 보너스!")
        elif boss_wins == 3:  # 플레이어 패배
            self.stats.consecutive_losses += 1  # 연속 패배 기록
            
            # 연속 패배에 따른 추가 페널티
            if self.stats.consecutive_losses > 1:
                print(f"💀 연속 패배 {self.stats.consecutive_losses}회! 추가 감점!")
            
            if player_wins == 0:
                print("💀 완패 (0-3) - 큰 감점!")
                # 완패시 추가 치명적 실수 기록
                for _ in range(3):  # 0-3 완패는 3번의 치명적 실수로 처리
                    self.stats.critical_misses += 1
            elif player_wins == 1:
                print("💀 대패 (1-3) - 감점!")
                # 대패시 추가 실수 기록
                for _ in range(2):  # 1-3 대패는 2번의 기회 놓침으로 처리
                    self.stats.missed_opportunities += 1
            elif player_wins == 2:
                print("💀 아슬한 패배 (2-3) - 소폭 감점!")
                # 아슬한 패배시 1번의 기회 놓침으로 처리
                self.stats.missed_opportunities += 1
                
    def record_critical_miss(self):
        """치명적인 실수 기록 (쉬운 공을 놓침)"""
        self._ensure_new_fields()  # 안전성 확보
        self.stats.critical_misses += 1
        print("💀 치명적인 실수!")
        
    def record_poor_timing_hit(self):
        """타이밍이 나쁜 히트 기록"""
        self._ensure_new_fields()  # 안전성 확보
        self.stats.poor_timing_hits += 1
        
    def record_wasted_skill(self):
        """무의미하게 낭비된 스킬 사용 기록"""
        self._ensure_new_fields()  # 안전성 확보
        self.stats.wasted_skills += 1
        print("💀 스킬 낭비!")
        
    def record_wasted_dash(self):
        """무의미하게 낭비된 대쉬 사용 기록"""
        self._ensure_new_fields()  # 안전성 확보
        self.stats.wasted_dash += 1
        print("💀 대쉬 낭비!")
        
    def record_missed_opportunity(self):
        """놓친 기회 기록 (좋은 상황에서 실수)"""
        self._ensure_new_fields()  # 안전성 확보
        self.stats.missed_opportunities += 1
        print("💀 기회 놓침!")
            
    def record_stage_result(self, stage, cleared=False):
        """스테이지 결과 기록 및 평가 진행"""
        if stage not in self.stats.stage_attempts:
            self.stats.stage_attempts[stage] = 0
        if stage not in self.stats.stage_clears:
            self.stats.stage_clears[stage] = 0
            
        self.stats.stage_attempts[stage] += 1
        if cleared:
            self.stats.stage_clears[stage] += 1
            
        # 스테이지 완료 카운트 (기록용)
        if cleared:
            self.stats.evaluation_stages_completed = max(self.stats.evaluation_stages_completed, stage)
            
    def _update_accuracy_history(self):
        """정확도 히스토리 업데이트"""
        total_attempts = self.stats.total_hits + self.stats.total_misses
        if total_attempts > 0:
            accuracy = (self.stats.total_hits / total_attempts) * 100
            self.stats.accuracy_history.append(accuracy)
            
    def get_current_accuracy(self) -> float:
        """현재 정확도 계산"""
        total_attempts = self.stats.total_hits + self.stats.total_misses
        if total_attempts == 0:
            return 0.0
        return (self.stats.total_hits / total_attempts) * 100
        
    def get_recent_accuracy(self) -> float:
        """최근 정확도 계산 (최근 20라운드)"""
        if len(self.stats.accuracy_history) == 0:
            return 0.0
        return sum(self.stats.accuracy_history) / len(self.stats.accuracy_history)
        
    def get_average_reaction_time(self) -> float:
        """평균 반응 시간"""
        if len(self.stats.reaction_times) == 0:
            return 0.0
        return sum(self.stats.reaction_times) / len(self.stats.reaction_times)
        
    def get_skill_success_rate(self) -> float:
        """스킬 성공률"""
        if self.stats.skill_usage_count == 0:
            return 0.0
        return (self.stats.skill_success_count / self.stats.skill_usage_count) * 100
        
    def get_dash_success_rate(self) -> float:
        """대쉬 성공률"""
        if self.stats.dash_usage_count == 0:
            return 0.0
        return (self.stats.dash_success_count / self.stats.dash_usage_count) * 100
        
    def get_dash_tactical_rate(self) -> float:
        """대쉬 전술적 활용률 (적절한 상황에서 사용한 비율)"""
        if self.stats.dash_usage_count == 0:
            return 0.0
        return (self.stats.good_dash_count / self.stats.dash_usage_count) * 100
        
    def get_item_effectiveness_rate(self) -> float:
        """아이템 효과적 활용률"""
        if self.stats.items_used_count == 0:
            return 0.0
        return (self.stats.items_effective_count / self.stats.items_used_count) * 100
        
    def get_item_variety_score(self) -> float:
        """아이템 다양성 점수 (사용한 아이템 종류의 다양성)"""
        unique_items = len(set(self.stats.item_types_used))
        # 최대 10종류 아이템 사용 시 만점
        return min(100, unique_items * 10)
        
    def get_item_combo_rate(self) -> float:
        """아이템 조합 활용률"""
        if self.stats.items_used_count == 0:
            return 0.0
        return (self.stats.item_combo_count / self.stats.items_used_count) * 100
        
    # 새로운 4가지 핵심 능력 평가 메서드들
    def get_skill_mastery_score(self) -> float:
        """스킬 활용 능력 - 균형잡힌 평가"""
        total_attempts = self.stats.total_hits + self.stats.total_misses
        if total_attempts == 0:
            return 0.0  # 플레이 안 했을 때 0점
            
        # 1. 스킬 성공률 (스킬을 썼을 때 얼마나 성공적으로 활용했는가)
        skill_success_rate = self.get_skill_success_rate()  # 0-100
        
        # 2. 스킬 활용 빈도율 (전체 히트 중 스킬 사용 비율) - 적절한 보정
        skill_usage_ratio = 0
        if self.stats.total_hits > 0:
            skill_usage_ratio = min(100, (self.stats.skill_usage_count / self.stats.total_hits) * 100 * 10)  # 10%면 100점 (균형잡힌 기준)
            
        # 3. 스킬 승리 기여도 (스킬로 얻은 승리 / 전체 히트) - 균형잡힌 보정
        skill_victory_ratio = 0
        if self.stats.total_hits > 0:
            skill_victory_ratio = min(100, (self.stats.skill_victories / self.stats.total_hits) * 100 * 25)  # 4%면 100점 (현실적 기준)
            
        # 4. 고속공 대응 보너스 (공속도 적응 점수 반영) - 안전한 접근
        speed_adaptation_bonus = getattr(self.stats, 'speed_adaptation_bonus', 0)
        speed_mastery_bonus = min(20, speed_adaptation_bonus / 7)  # 최대 20점 추가 (적절한 보너스)
            
        # 가중 평균 - 균형잡힌 비중 + 고속공 대응 보너스
        base_score = skill_success_rate * 0.35 + skill_usage_ratio * 0.30 + skill_victory_ratio * 0.35  # 균형잡힌 배분
        final_score = 10 + (base_score * 0.8) + speed_mastery_bonus  # 기본 10점 + 계산점수 + 보너스
        return min(100, max(0, final_score))  # 최소 0점, 최대 100점
        
    def get_dash_mastery_score(self) -> float:
        """대쉬 활용 능력 - 균형잡힌 클러치 평가"""
        total_attempts = self.stats.total_hits + self.stats.total_misses
        if total_attempts == 0:
            return 0.0  # 플레이 안 했을 때 0점
            
        # 대쉬를 사용하지 않았다면 기본 점수
        if self.stats.dash_usage_count == 0:
            return 10.0  # 대쉬를 사용하지 않으면 낮은 기본 점수
            
        # 1. 대쉬 생명구조 효율성 - 위기 탈출
        dash_life_efficiency = 0
        if self.stats.dash_usage_count > 0:
            dash_life_efficiency = min(100, (self.stats.dash_life_saves / self.stats.dash_usage_count) * 100 * 8)  # 12.5%면 100점
            
        # 2. 대쉬 방어 구조 효율성 - 불가능한 영역 가드
        dash_defense_efficiency = 0
        if self.stats.dash_usage_count > 0:
            dash_defensive_saves = getattr(self.stats, 'dash_defensive_saves', 0)
            dash_defense_efficiency = min(100, (dash_defensive_saves / self.stats.dash_usage_count) * 100 * 10)  # 10%면 100점
            
        # 3. 대쉬 클러치 승리 - 대쉬로 직접 승리
        dash_clutch_rate = 0
        if self.stats.dash_usage_count > 0:
            dash_clutch_victories = getattr(self.stats, 'dash_clutch_victories', 0)
            dash_clutch_rate = min(100, (dash_clutch_victories / self.stats.dash_usage_count) * 100 * 15)  # 6.7%면 100점
            
        # 4. 고속공 대응 마스터리 (빠른 공을 대쉬로 처리)
        speed_adaptation_bonus = getattr(self.stats, 'speed_adaptation_bonus', 0)
        speed_mastery_bonus = min(15, speed_adaptation_bonus / 5)  # 최대 15점
            
        # 5. 대쉬 성공률 (기본 성공률)
        dash_success_rate = self.get_dash_success_rate()  # 0-100
        
        # 6. 대쉬 전술적 활용률
        dash_tactical_rate = self.get_dash_tactical_rate()  # 0-100
            
        # 균형잡힌 가중 평균
        clutch_score = dash_life_efficiency * 0.25 + dash_defense_efficiency * 0.25 + dash_clutch_rate * 0.25  # 클러치 75%
        base_score = dash_success_rate * 0.35 + dash_tactical_rate * 0.15 + clutch_score * 0.5  # 균형잡힌 배분
        
        # 대쉬 사용 보너스 (적절한 수준)
        dash_usage_bonus = min(10, self.stats.dash_usage_count * 2)  # 대쉬 사용 횟수당 2점, 최대 10점
        final_score = 15 + (base_score * 0.7) + speed_mastery_bonus + dash_usage_bonus  # 기본 15점
        return min(100, max(0, final_score))  # 최소 0점, 최대 100점
        
    def get_item_mastery_score(self) -> float:
        """아이템 활용 능력 - 균형잡힌 평가"""
        total_attempts = self.stats.total_hits + self.stats.total_misses
        if total_attempts == 0:
            return 0.0  # 플레이 안 했을 때 0점
            
        # 아이템을 사용하지 않았다면 기본 점수
        if self.stats.items_used_count == 0:
            return 5.0  # 아이템 미사용시 매우 낮은 점수
            
        # 1. 아이템 효율성 (아이템을 썼을 때 얼마나 효과적이었는가)
        item_effectiveness = self.get_item_effectiveness_rate()  # 0-100
        
        # 2. 아이템 활용 빈도 (전체 라운드 대비 아이템 사용 빈도) - 균형잡힌 기준
        item_usage_ratio = 0
        if self.stats.total_rounds > 0:
            # 라운드당 평균 0.3개 이상 사용하면 100점
            item_usage_ratio = min(100, (self.stats.items_used_count / max(1, self.stats.total_rounds)) * 333)
            
        # 3. 아이템 다양성 (사용한 아이템 종류의 다양성)
        item_variety = 0
        unique_items = len(set(self.stats.item_types_used))
        if unique_items > 0:
            item_variety = min(100, unique_items * 20)  # 5종류면 100점
            
        # 4. 아이템 콤보 활용률
        item_combo_rate = self.get_item_combo_rate()  # 0-100
            
        # 가중 평균 (효율성 40%, 활용도 25%, 다양성 20%, 콤보 15%)
        final_score = 20 + (item_effectiveness * 0.4 + item_usage_ratio * 0.25 + item_variety * 0.2 + item_combo_rate * 0.15) * 0.8
        return min(100, max(0, final_score))  # 최소 0점, 최대 100점
        
    def get_guard_ability_score(self) -> float:
        """가드 능력 - 균형잡힌 평가"""
        total_attempts = self.stats.total_hits + self.stats.total_misses
        if total_attempts == 0:
            return 0.0  # 플레이 안 했을 때 0점
            
        # 1. 기본 방어 성공률 (전체 시도 중 성공적으로 방어한 비율)
        guard_success_rate = (self.stats.successful_guards / total_attempts) * 100
        
        # 2. 위험 상황 대처 능력 (성공한 방어 중 위험 상황 구조 비율)
        danger_handling = 0
        if self.stats.successful_guards > 0:
            danger_handling = min(100, (self.stats.defensive_saves / self.stats.successful_guards) * 100 * 1.5)  # 67%면 100점
            
        # 3. 클러치 상황 회복 능력 (성공한 방어 중 아슬아슬한 상황 회복 비율)
        clutch_recovery = 0
        if self.stats.successful_guards > 0:
            clutch_recovery = min(100, (self.stats.close_call_recoveries / self.stats.successful_guards) * 100 * 2)  # 50%면 100점
            
        # 4. 정확도 보너스
        accuracy = self.get_current_accuracy()
        accuracy_bonus = min(20, accuracy / 5)  # 최대 20점 보너스
            
        # 가중 평균 (기본 성공률 50%, 위험대처 25%, 클러치회복 15%, 정확도 10%)
        base_score = (guard_success_rate * 0.5 + danger_handling * 0.25 + clutch_recovery * 0.15 + accuracy * 0.1)
        final_score = 20 + (base_score * 0.6) + accuracy_bonus  # 기본 20점
        return min(100, max(0, final_score))  # 최소 0점, 최대 100점
        
    def get_stage_difficulty_multiplier(self, stage: int) -> float:
        """스테이지별 난이도 보정 배수 - 높은 스테이지에서 훨씬 더 높은 점수 보상"""
        stage_multipliers = {
            1: 1.0,    # 기본 (100%)
            2: 1.3,    # 30% 보정 (강화)
            3: 1.6,    # 60% 보정 (강화)
            4: 2.0,    # 100% 보정 (강화)
            5: 2.5,    # 150% 보정 (강화)
            6: 3.0,    # 200% 보정 (보스 스테이지 - 강화)
            7: 3.5,    # 250% 보정 (추가)
            8: 4.0,    # 300% 보정 (추가)
        }
        return stage_multipliers.get(stage, 4.0)  # 8스테이지 이상은 최대 보정
        
    def get_stage_penalty_reduction(self, stage: int) -> float:
        """스테이지별 감점 완화 비율 - 높은 스테이지일수록 감점을 줄임"""
        penalty_reductions = {
            1: 1.0,    # 기본 감점 (100%)
            2: 0.9,    # 10% 감점 완화
            3: 0.8,    # 20% 감점 완화 
            4: 0.7,    # 30% 감점 완화
            5: 0.6,    # 40% 감점 완화
            6: 0.5,    # 50% 감점 완화 (보스 스테이지)
        }
        return penalty_reductions.get(stage, 0.5)  # 6스테이지 이상은 최대 완화
        
    def get_stage_challenge_bonus(self, stage: int) -> int:
        """스테이지별 도전 보너스 - 높은 스테이지 도달 시 추가 점수"""
        stage_bonuses = {
            1: 0,      # 보너스 없음
            2: 20,     # 20점 보너스
            3: 50,     # 50점 보너스  
            4: 100,    # 100점 보너스
            5: 180,    # 180점 보너스
            6: 300,    # 300점 보너스 (보스 스테이지)
            7: 450,    # 450점 보너스
            8: 650,    # 650점 보너스
        }
        return stage_bonuses.get(stage, 800)  # 8스테이지 이상은 800점 보너스
        
    def get_victory_bonus(self) -> int:
        """승부 결과에 따른 보너스 점수"""
        # 새 필드들 안전성 확보
        self._ensure_new_fields()
        
        victory_bonus = 0
        
        # 3-0 완승 보너스 (최고 보너스) - 안전한 접근
        perfect_victories = getattr(self.stats, 'perfect_victories', 0)
        victory_bonus += perfect_victories * 150  # 완승당 150점
        
        # 3-1 압승 보너스 (높은 보너스) - 안전한 접근
        dominant_victories = getattr(self.stats, 'dominant_victories', 0)
        victory_bonus += dominant_victories * 100  # 압승당 100점
        
        # 3-2 승리 보너스 (기본 보너스) - 안전한 접근
        close_victories = getattr(self.stats, 'close_victories', 0)
        victory_bonus += close_victories * 50  # 승리당 50점
        
        return min(victory_bonus, 500)  # 최대 500점 보너스
        
    def get_mistake_penalty(self) -> int:
        """실수에 대한 페널티 점수 계산 - 균형잡힌 감점 시스템"""
        # 새 필드들 안전성 확보
        self._ensure_new_fields()
        
        total_attempts = self.stats.total_hits + self.stats.total_misses
        if total_attempts == 0:
            return 0
            
        penalty = 0
        
        # 1. 치명적 실수 페널티 (매우 큰 감점) - 적절한 수준
        critical_misses = getattr(self.stats, 'critical_misses', 0)
        critical_miss_rate = critical_misses / max(1, total_attempts)
        penalty += critical_miss_rate * 250  # 적절한 감점
        
        # 2. 타이밍 나쁜 히트 페널티
        if self.stats.total_hits > 0:
            poor_timing_hits = getattr(self.stats, 'poor_timing_hits', 0)
            poor_timing_rate = poor_timing_hits / self.stats.total_hits
            penalty += poor_timing_rate * 150  # 적절한 감점
        
        # 3. 스킬/대쉬 낭비 페널티
        skill_uses = getattr(self.stats, 'skill_uses', 0)
        if skill_uses > 0:
            wasted_skills = getattr(self.stats, 'wasted_skills', 0)
            skill_waste_rate = wasted_skills / skill_uses
            penalty += skill_waste_rate * 200  # 적절한 감점
            
        if self.stats.dash_usage_count > 0:
            wasted_dash = getattr(self.stats, 'wasted_dash', 0)
            dash_waste_rate = wasted_dash / self.stats.dash_usage_count
            penalty += dash_waste_rate * 200  # 적절한 감점
        
        # 4. 기회 놓침 페널티
        missed_opportunities = getattr(self.stats, 'missed_opportunities', 0)
        opportunity_miss_rate = missed_opportunities / max(1, total_attempts)
        penalty += opportunity_miss_rate * 180  # 적절한 감점
        
        # 5. 연속 패배 페널티
        consecutive_losses = getattr(self.stats, 'consecutive_losses', 0)
        penalty += consecutive_losses * 70  # 적절한 감점
        
        # 6. 전체 정확도 기반 페널티
        accuracy = self.get_current_accuracy()
        if accuracy < 50:  # 기준을 50%로 낮춤
            penalty += (50 - accuracy) * 8  # 적절한 감점
        
        # 7. 연속 실수 컴보 페널티
        if self.stats.current_miss_streak > 5:  # 기준을 5로 높임
            penalty += (self.stats.current_miss_streak - 5) * 30  # 적절한 감점
        
        return min(penalty, 800)  # 최대 800점 감점 (균형잡힌 수준)

    # --- 캐릭터별 가중치/프로필 -------------------------------------------------
    def _get_character_type(self) -> Optional[str]:
        """현재 선택된 캐릭터 타입을 가져온다 (없으면 None)."""
        try:
            import pingfighter  # 지연 임포트로 순환 의존 최소화
            return getattr(pingfighter, "selected_character_type", None)
        except Exception:
            return None

    def _get_weight_profile(self) -> Dict[str, float]:
        """
        캐릭터별 능력 가중치 프로필을 반환.
        합은 1.0, 기본값은 균등 분배.
        """
        char_type = self._get_character_type() or "default"
        weight_map = {
            # 드라이브/파워스매싱이 핵심
            "smasher": {
                "skill": 0.32,
                "dash": 0.26,
                "item": 0.16,
                "guard": 0.26,
            },
            # 무기·지원 아이템 중심(솔저/코만도)
            "soldier": {
                "skill": 0.14,
                "dash": 0.24,
                "item": 0.34,
                "guard": 0.28,
            },
            # 발토르(대장장이) - 방어·아이템 비중 높음
            "blacksmith": {
                "skill": 0.16,
                "dash": 0.22,
                "item": 0.34,
                "guard": 0.28,
            },
            # 그 외 캐릭터는 균등
            "default": {
                "skill": 0.25,
                "dash": 0.25,
                "item": 0.25,
                "guard": 0.25,
            },
        }
        return weight_map.get(char_type, weight_map["default"])

    def calculate_skill_score(self, current_stage: int = 1) -> int:
        """실력 점수 계산 (0-1000점) - 스테이지별 난이도 반영"""
        weights = self._get_weight_profile()
        # 스테이지별 난이도 보정
        stage_multiplier = self.get_stage_difficulty_multiplier(current_stage)
        
        score = 0

        # 능력별 최대 캡을 가중치로 조정 (총 1000점 → 각 캡 = 1000 * weight)
        ability_caps = {
            "skill": 1000 * weights["skill"],
            "dash": 1000 * weights["dash"],
            "item": 1000 * weights["item"],
            "guard": 1000 * weights["guard"],
        }
        
        # 1. 스킬 활용 능력
        skill_score = self.get_skill_mastery_score()
        score += min(ability_caps["skill"], skill_score * 2.5 * stage_multiplier)
        
        # 2. 대쉬 활용 능력
        dash_score = self.get_dash_mastery_score()
        score += min(ability_caps["dash"], dash_score * 2.5 * stage_multiplier)
        
        # 3. 아이템 활용 능력
        item_score = self.get_item_mastery_score()
        score += min(ability_caps["item"], item_score * 2.5 * stage_multiplier)
        
        # 4. 가드 능력
        guard_score = self.get_guard_ability_score()
        score += min(ability_caps["guard"], guard_score * 2.5 * stage_multiplier)
        
        # 5. 스테이지별 특별 보너스 (높은 스테이지 도전 보상)
        stage_bonus = self.get_stage_challenge_bonus(current_stage)
        score += stage_bonus
        
        # 6. 승부 결과 보너스 (3-0, 3-1 승리 등)
        victory_bonus = self.get_victory_bonus()
        score += victory_bonus
        
        # 7. 실수 페널티 적용 (감점)
        mistake_penalty = self.get_mistake_penalty()
        score = max(0, score - mistake_penalty)  # 실수로 인한 감점
            
        return int(min(2000, max(0, score)))  # 최대 점수 조정 (2000점)
        
    def get_current_rank(self, current_stage: int = 1) -> Dict:
        """현재 등급 정보 반환 - 스테이지별 난이도 반영 (실시간 평가)"""
        # 새 필드들 안전성 확보
        self._ensure_new_fields()
        
        score = self.calculate_skill_score(current_stage)
        
        # 실시간 등급 결정 (항상 등급 표시)
        for i in range(len(SkillRank.RANKS) - 1, -1, -1):
            rank = SkillRank.RANKS[i]
            if score >= rank["min_score"]:
                return {
                    **rank,
                    "score": score,
                    "progress_to_next": self._calculate_progress_to_next_rank(score),
                    "is_evaluation": False
                }
                
        # 기본값 (초보)
        return {
            **SkillRank.RANKS[0],
            "score": score,
            "progress_to_next": self._calculate_progress_to_next_rank(score),
            "is_evaluation": False
        }
        
    def _calculate_progress_to_next_rank(self, current_score: int) -> float:
        """다음 등급까지의 진행률 계산"""
        current_rank_idx = 0
        
        # 현재 등급 찾기
        for i, rank in enumerate(SkillRank.RANKS):
            if current_score >= rank["min_score"]:
                current_rank_idx = i
                
        # 마지막 등급이면 100% 반환
        if current_rank_idx >= len(SkillRank.RANKS) - 1:
            return 100.0
            
        current_min = SkillRank.RANKS[current_rank_idx]["min_score"]
        next_min = SkillRank.RANKS[current_rank_idx + 1]["min_score"]
        
        progress = ((current_score - current_min) / (next_min - current_min)) * 100
        return min(100.0, max(0.0, progress))
        
    def get_detailed_analysis(self, current_stage: int = 1) -> Dict:
        """상세 분석 정보"""
        # 새 필드들 안전성 확보
        self._ensure_new_fields()
        
        rank_info = self.get_current_rank(current_stage)
        
        return {
            "rank": rank_info,
            "stats": {
                "accuracy": self.get_current_accuracy(),
                "recent_accuracy": self.get_recent_accuracy(),
                "hit_streak": self.stats.current_hit_streak,
                "max_hit_streak": self.stats.max_hit_streak,
                "reaction_time": self.get_average_reaction_time(),
                "skill_success_rate": self.get_skill_success_rate(),
                "perfect_timing_rate": (
                    (self.stats.perfect_timing_hits / max(1, self.stats.total_hits)) * 100
                ),
                "skill_mastery_score": self.get_skill_mastery_score(),
                "dash_mastery_score": self.get_dash_mastery_score(),
                "item_mastery_score": self.get_item_mastery_score(),
                "guard_ability_score": self.get_guard_ability_score(),
                "total_games": self.stats.total_games,
                "play_time": self.stats.total_play_time
            },
            "achievements": self._get_achievements(),
            "improvement_tips": self._get_improvement_tips()
        }

    def get_detailed_stats(self, current_stage: int = 1) -> Dict:
        """상세 통계 정보 - 스테이지별 난이도 반영"""
        # 새 필드들 안전성 확보
        self._ensure_new_fields()
        
        return {
            "rank": self.get_current_rank(current_stage),
            "stats": {
                "skill_mastery_score": self.get_skill_mastery_score(),
                "dash_mastery_score": self.get_dash_mastery_score(),
                "item_mastery_score": self.get_item_mastery_score(),
                "guard_ability_score": self.get_guard_ability_score(),
                "total_games": self.stats.total_games,
                "accuracy": self.get_current_accuracy(),
                "hit_streak": self.stats.current_hit_streak
            },
            "achievements": self._get_achievements()
        }
        
    def _get_achievements(self) -> List[str]:
        """업적 목록"""
        # 새 필드들 안전성 확보
        self._ensure_new_fields()
        
        achievements = []
        
        if self.stats.max_hit_streak >= 10:
            achievements.append("🔥 연속 10히트 달성!")
        if self.stats.max_hit_streak >= 20:
            achievements.append("⚡ 연속 20히트 달성!")
        if self.stats.max_hit_streak >= 50:
            achievements.append("💫 연속 50히트 달성!")
            
        if self.get_current_accuracy() >= 90:
            achievements.append("🎯 정확도 90% 달성!")
            
        if self.stats.perfect_timing_hits >= 100:
            achievements.append("⏱️ 퍼펙트 타이밍 100회!")
            
        if 5 in self.stats.stage_clears and self.stats.stage_clears[5] > 0:
            achievements.append("🏆 스테이지 5 클리어!")
            
        return achievements
        
    def _get_improvement_tips(self) -> List[str]:
        """개선 제안"""
        # 새 필드들 안전성 확보
        self._ensure_new_fields()
        
        tips = []
        
        accuracy = self.get_current_accuracy()
        dash_success_rate = self.get_dash_success_rate()
        dash_tactical_rate = self.get_dash_tactical_rate()
        skill_rate = self.get_skill_success_rate()
        reaction_time = self.get_average_reaction_time()
        
        # 우선순위별 개선 제안
        if accuracy < 40:
            tips.append("🎯 기본기 연습: 먼저 공의 궤적 예측을 연습하세요")
        elif accuracy < 70:
            tips.append("🎯 정확도 향상: 공의 반사각을 더 정확히 예측해보세요")
            
        if self.stats.max_hit_streak < 5:
            tips.append("🔥 집중력 향상: 짧은 랠리부터 안정적으로 유지해보세요")
        elif self.stats.max_hit_streak < 15:
            tips.append("🔥 연속 히트: 긴장하지 말고 리듬을 유지해보세요")
            
        if dash_tactical_rate < 30 and self.stats.dash_usage_count > 5:
            tips.append("🏃 대쉬 활용: 급한 상황에서만 대쉬를 사용해보세요")
        elif dash_success_rate < 50 and self.stats.dash_usage_count > 3:
            tips.append("🏃 대쉬 타이밍: 대쉬 후 공의 위치를 미리 예측해보세요")
            
        if reaction_time > 1.2:
            tips.append("⚡ 반응 속도: 공이 패들에 닿기 전에 미리 움직여보세요")
        elif reaction_time > 0.8:
            tips.append("⚡ 예측 능력: 공의 다음 위치를 미리 예상해보세요")
            
        if skill_rate < 30 and self.stats.skill_usage_count > 2:
            tips.append("🎮 스킬 타이밍: 스킬은 확실한 순간에만 사용해보세요")
        elif skill_rate < 70 and self.stats.skill_usage_count > 5:
            tips.append("🎮 스킬 정확도: 스킬 사용 후 공의 방향을 조절해보세요")
            
        # 고급 팁 (고수용)
        if accuracy > 80 and self.stats.max_hit_streak > 20:
            if dash_tactical_rate > 80:
                tips.append("🌟 완벽한 플레이! 이제 더 어려운 스테이지에 도전해보세요")
            else:
                tips.append("💎 대쉬 마스터: 대쉬를 더 전략적으로 활용해보세요")
                
        # 단계별 스테이지 추천
        current_stage = max(self.stats.stage_clears.keys()) if self.stats.stage_clears else 1
        if accuracy > 70 and current_stage < 3:
            tips.append("🚀 도전: 더 높은 스테이지에 도전해보세요!")
            
        if len(tips) == 0:
            tips.append("🌟 모든 면에서 훌륭합니다! 계속 도전해보세요!")
            
        return tips[:3]  # 최대 3개만 표시
    
    def get_detailed_feedback(self, current_stage: int = 1) -> dict:
        """등급별 상세 피드백 및 개선 조언"""
        # 문학적 피드백 시스템 사용 여부 확인
        try:
            from literary_feedback_system import LiteraryFeedbackSystem
            
            # 문학적 시스템 사용
            literary_system = LiteraryFeedbackSystem(self)
            
            # 각 능력별 점수 계산
            skill_score = self.get_skill_mastery_score()
            dash_score = self.get_dash_mastery_score()  
            item_score = self.get_item_mastery_score()
            guard_score = self.get_guard_ability_score()
            
            # 등급 계산
            skill_grade = self._score_to_grade_text(skill_score)
            dash_grade = self._score_to_grade_text(dash_score)
            item_grade = self._score_to_grade_text(item_score)
            guard_grade = self._score_to_grade_text(guard_score)
            
            # 문학적 피드백 생성
            skill_fb = literary_system.get_skill_narrative(skill_score, skill_grade)
            dash_fb = literary_system.get_dash_narrative(dash_score, dash_grade)
            item_fb = literary_system.get_item_narrative(item_score, item_grade)
            guard_fb = literary_system.get_guard_narrative(guard_score, guard_grade)
            
            # 포맷팅된 피드백 구성
            def format_feedback(fb_dict):
                """딕셔너리를 문자열로 포맷팅"""
                text = f"━━━ {fb_dict['title']} ━━━\n"
                text += f"🏆 등급: {fb_dict['grade']}\n\n"
                text += f"📖 이야기\n{fb_dict['narrative']}\n\n"
                text += f"🌟 빛나는 순간들\n{fb_dict['highlights']}\n\n"
                text += f"🌱 성장의 여정\n{fb_dict['growth']}\n\n"
                text += f"✨ 지혜의 속삭임\n{fb_dict['wisdom']}"
                return text
            
            feedback = {
                "skill_feedback": format_feedback(skill_fb),
                "dash_feedback": format_feedback(dash_fb),
                "item_feedback": format_feedback(item_fb),
                "guard_feedback": format_feedback(guard_fb),
                "overall_feedback": literary_system.generate_epic_narrative(),
                "improvement_tips": literary_system.compose_journey_ahead(skill_score, dash_score, item_score, guard_score)
            }
            
            return feedback
            
        except ImportError:
            # 기존 피드백 시스템으로 폴백
            stats = self.get_detailed_stats(current_stage)
            
            # 각 능력별 등급과 점수 (중첩된 구조에서 접근)
            skill_score = stats['stats']['skill_mastery_score']
            dash_score = stats['stats']['dash_mastery_score']  
            item_score = stats['stats']['item_mastery_score']
            guard_score = stats['stats']['guard_ability_score']
            
            # 등급 계산
            skill_grade = self._score_to_grade_text(skill_score)
            dash_grade = self._score_to_grade_text(dash_score)
            item_grade = self._score_to_grade_text(item_score)
            guard_grade = self._score_to_grade_text(guard_score)
            
            # 외부 피드백 시스템 사용
            from feedback_system import (get_skill_feedback, get_dash_feedback, 
                                         get_item_feedback, get_guard_feedback,
                                         get_overall_feedback, get_improvement_tips)
            
            feedback = {
                "skill_feedback": get_skill_feedback(skill_score, skill_grade),
                "dash_feedback": get_dash_feedback(dash_score, dash_grade),
                "item_feedback": get_item_feedback(item_score, item_grade),
                "guard_feedback": get_guard_feedback(guard_score, guard_grade),
                "overall_feedback": get_overall_feedback(skill_score, dash_score, item_score, guard_score),
                "improvement_tips": get_improvement_tips(skill_score, dash_score, item_score, guard_score)
            }
            
            return feedback
    
    def _score_to_grade_text(self, score: float) -> str:
        """점수를 등급 텍스트로 변환"""
        if score == 0:
            return "플레이 필요"
        elif score >= 90:
            return "S"
        elif score >= 80:
            return "A"
        elif score >= 70:
            return "B"
        elif score >= 60:
            return "C"
        elif score >= 50:
            return "D"
        elif score >= 30:
            return "E"
        else:
            return "F"

# 전역 인스턴스
player_analyzer = PlayerSkillAnalyzer()

def get_player_analyzer():
    """플레이어 분석기 인스턴스 반환"""
    return player_analyzer
