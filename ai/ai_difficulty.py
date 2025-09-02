"""
AI Difficulty - 난이도 조절 시스템
동적 난이도 조절과 플레이어 스킬 분석
"""

import math
import json
import os
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, asdict
from core.events import EventType, emit_event, subscribe


@dataclass
class DifficultyProfile:
    """난이도 프로필"""
    name: str
    level: float  # 0.0 ~ 1.0
    reaction_time: float
    prediction_accuracy: float
    movement_speed: float
    mistake_rate: float
    special_frequency: float
    aggression: float
    adaptation_rate: float
    
    def to_dict(self) -> Dict:
        return asdict(self)


class DifficultyPresets:
    """난이도 프리셋"""
    
    EASY = DifficultyProfile(
        name="Easy",
        level=0.3,
        reaction_time=0.35,  # 더 느린 반응
        prediction_accuracy=0.35,  # 더 낮은 예측
        movement_speed=4.5,  # 더 느린 이동
        mistake_rate=0.3,  # 더 많은 실수
        special_frequency=0.03,  # 더 적은 특수 능력
        aggression=0.15,  # 더 수비적
        adaptation_rate=0.0
    )
    
    NORMAL = DifficultyProfile(
        name="Normal",
        level=0.5,
        reaction_time=0.25,  # 균형잡힌 반응
        prediction_accuracy=0.55,  # 적당한 예측
        movement_speed=6.5,  # 중간 속도
        mistake_rate=0.18,  # 간헐적인 실수
        special_frequency=0.12,  # 적당한 특수 능력
        aggression=0.35,  # 균형잡힌 공격성
        adaptation_rate=0.05  # 약간의 적응
    )
    
    HARD = DifficultyProfile(
        name="Hard",
        level=0.7,
        reaction_time=0.15,  # 빠른 반응
        prediction_accuracy=0.75,  # 높은 예측
        movement_speed=8.0,  # 빠른 이동
        mistake_rate=0.1,  # 적은 실수
        special_frequency=0.2,  # 자주 사용하는 특수 능력
        aggression=0.55,  # 공격적
        adaptation_rate=0.15  # 적응형 AI
    )
    
    EXPERT = DifficultyProfile(
        name="Expert",
        level=0.9,
        reaction_time=0.08,  # 매우 빠른 반응 (인간 한계 고려)
        prediction_accuracy=0.9,  # 뛰어난 예측
        movement_speed=10.0,  # 매우 빠른 이동
        mistake_rate=0.05,  # 거의 실수 없음
        special_frequency=0.3,  # 빈번한 특수 능력
        aggression=0.75,  # 매우 공격적
        adaptation_rate=0.25  # 빠른 적응
    )
    
    ADAPTIVE = DifficultyProfile(
        name="Adaptive",
        level=0.5,  # 시작 레벨
        reaction_time=0.2,
        prediction_accuracy=0.6,
        movement_speed=7.0,
        mistake_rate=0.15,
        special_frequency=0.15,
        aggression=0.4,
        adaptation_rate=0.5  # 높은 적응률
    )


class PlayerSkillAnalyzer:
    """플레이어 스킬 분석기"""
    
    def __init__(self):
        self.metrics = {
            'rally_count': [],
            'hit_accuracy': [],
            'reaction_times': [],
            'score_ratio': [],
            'special_usage': [],
            'movement_patterns': []
        }
        
        self.skill_level = 0.5  # 0.0 ~ 1.0
        self.consistency = 0.5
        self.playstyle = 'balanced'
        
        # 이벤트 구독
        self.setup_event_handlers()
        
    def setup_event_handlers(self):
        """이벤트 핸들러 설정"""
        subscribe(EventType.BALL_HIT_PLAYER, self.on_player_hit)
        subscribe(EventType.PLAYER_SCORE, self.on_player_score)
        subscribe(EventType.SPECIAL_ACTIVATED, self.on_special_used)
        
    def on_player_hit(self, event):
        """플레이어 히트 이벤트"""
        # 히트 정확도 기록
        hit_pos = event.data.get('hit_pos', 0)
        self.metrics['hit_accuracy'].append(abs(hit_pos))
        
    def on_player_score(self, event):
        """플레이어 득점 이벤트"""
        # 득점 기록
        self.metrics['score_ratio'].append(1)
        
    def on_special_used(self, event):
        """특수 능력 사용 이벤트"""
        if event.data.get('user') == 'player':
            self.metrics['special_usage'].append(1)
            
    def analyze_skill(self) -> float:
        """플레이어 스킬 분석
        
        Returns:
            스킬 레벨 (0.0 ~ 1.0)
        """
        skill_factors = []
        
        # 히트 정확도 분석
        if self.metrics['hit_accuracy']:
            avg_accuracy = sum(self.metrics['hit_accuracy'][-20:]) / len(self.metrics['hit_accuracy'][-20:])
            accuracy_skill = 1.0 - min(avg_accuracy, 1.0)
            skill_factors.append(accuracy_skill)
            
        # 득점률 분석
        if self.metrics['score_ratio']:
            recent_scores = self.metrics['score_ratio'][-10:]
            score_rate = sum(recent_scores) / max(len(recent_scores), 1)
            skill_factors.append(score_rate)
            
        # 특수 능력 사용 빈도
        if self.metrics['special_usage']:
            special_rate = len(self.metrics['special_usage']) / max(len(self.metrics['hit_accuracy']), 1)
            skill_factors.append(min(special_rate * 2, 1.0))
            
        # 스킬 레벨 계산
        if skill_factors:
            self.skill_level = sum(skill_factors) / len(skill_factors)
        else:
            self.skill_level = 0.5
            
        return self.skill_level
        
    def analyze_playstyle(self) -> str:
        """플레이 스타일 분석
        
        Returns:
            플레이 스타일
        """
        if not self.metrics['movement_patterns']:
            return 'balanced'
            
        # 이동 패턴 분석
        recent_moves = self.metrics['movement_patterns'][-50:]
        avg_movement = sum(abs(m) for m in recent_moves) / len(recent_moves)
        
        if avg_movement > 0.7:
            self.playstyle = 'aggressive'
        elif avg_movement < 0.3:
            self.playstyle = 'defensive'
        else:
            self.playstyle = 'balanced'
            
        return self.playstyle
        
    def get_consistency(self) -> float:
        """일관성 분석
        
        Returns:
            일관성 점수 (0.0 ~ 1.0)
        """
        if not self.metrics['hit_accuracy'] or len(self.metrics['hit_accuracy']) < 10:
            return 0.5
            
        # 최근 히트의 표준편차
        recent_hits = self.metrics['hit_accuracy'][-20:]
        avg = sum(recent_hits) / len(recent_hits)
        variance = sum((x - avg) ** 2 for x in recent_hits) / len(recent_hits)
        std_dev = math.sqrt(variance)
        
        # 낮은 표준편차 = 높은 일관성
        self.consistency = max(0, 1 - std_dev)
        
        return self.consistency
        
    def reset(self):
        """분석기 리셋"""
        for key in self.metrics:
            self.metrics[key].clear()
        self.skill_level = 0.5
        self.consistency = 0.5
        self.playstyle = 'balanced'


class DynamicDifficulty:
    """동적 난이도 조절 시스템"""
    
    def __init__(self):
        self.current_difficulty = DifficultyPresets.NORMAL
        self.base_difficulty = DifficultyPresets.NORMAL
        
        self.player_analyzer = PlayerSkillAnalyzer()
        
        # 난이도 조절 설정
        self.adjustment_rate = 0.1  # 더 빠른 조절
        self.min_difficulty = 0.25  # 최소 난이도 상향
        self.max_difficulty = 0.85  # 최대 난이도 하향 (너무 어려워지지 않게)
        
        # 조절 히스토리
        self.adjustment_history = []
        self.last_adjustment_time = 0
        self.adjustment_cooldown = 5.0  # 5초 쿨다운 (더 빠른 반응)
        
        # 밸런싱 설정
        self.balance_config = {
            'score_gap_threshold': 3,  # 점수 차이 임계값
            'win_streak_threshold': 3,  # 연속 승/패 임계값
            'rally_balance_factor': 0.02,  # 랠리 길이에 따른 난이도 조절
            'comeback_boost': 0.15  # 컴백 메커니즘 강도
        }
        
        # 게임 플로우 상태
        self.flow_state = 'normal'  # easy, normal, hard
        self.consecutive_wins = 0
        self.consecutive_losses = 0
        
    def update(self, dt: float, game_state: Dict[str, Any]):
        """난이도 업데이트
        
        Args:
            dt: 델타 타임
            game_state: 게임 상태
        """
        self.last_adjustment_time += dt
        
        # 쿨다운 체크
        if self.last_adjustment_time < self.adjustment_cooldown:
            return
            
        # 플레이어 스킬 분석
        player_skill = self.player_analyzer.analyze_skill()
        
        # 게임 플로우 분석
        self.analyze_game_flow(game_state)
        
        # 난이도 조절 필요 여부 판단
        if self.should_adjust_difficulty(player_skill):
            self.adjust_difficulty(player_skill)
            self.last_adjustment_time = 0
            
    def analyze_game_flow(self, game_state: Dict[str, Any]):
        """게임 플로우 분석
        
        Args:
            game_state: 게임 상태
        """
        player_score = game_state.get('player_score', 0)
        ai_score = game_state.get('ai_score', 0)
        
        # 연속 승/패 추적
        if 'round_winner' in game_state:
            if game_state['round_winner'] == 'player':
                self.consecutive_wins += 1
                self.consecutive_losses = 0
            else:
                self.consecutive_losses += 1
                self.consecutive_wins = 0
                
        # 플로우 상태 결정 (개선된 로직)
        score_diff = player_score - ai_score
        threshold = self.balance_config['score_gap_threshold']
        streak_threshold = self.balance_config['win_streak_threshold']
        
        if score_diff > threshold or self.consecutive_wins > streak_threshold:
            self.flow_state = 'easy'
        elif score_diff < -threshold or self.consecutive_losses > streak_threshold:
            self.flow_state = 'hard'
        else:
            self.flow_state = 'normal'
            
        # 랠리 길이에 따른 추가 조정
        rally_count = game_state.get('rally_count', 0)
        if rally_count > 10:  # 긴 랠리는 플레이어가 잘하고 있음
            self.flow_state = 'easy' if self.flow_state == 'normal' else self.flow_state
            
    def should_adjust_difficulty(self, player_skill: float) -> bool:
        """난이도 조절 필요 여부
        
        Args:
            player_skill: 플레이어 스킬 레벨
            
        Returns:
            조절 필요 여부
        """
        # 스킬과 난이도 차이
        skill_diff = abs(player_skill - self.current_difficulty.level)
        
        # 차이가 크면 조절 필요
        if skill_diff > 0.2:
            return True
            
        # 게임 플로우가 극단적이면 조절
        if self.flow_state in ['easy', 'hard']:
            return True
            
        # 연속 승/패가 많으면 조절
        if self.consecutive_wins > 5 or self.consecutive_losses > 5:
            return True
            
        return False
        
    def adjust_difficulty(self, player_skill: float):
        """난이도 조절
        
        Args:
            player_skill: 플레이어 스킬 레벨
        """
        old_level = self.current_difficulty.level
        
        # 목표 난이도 계산
        target_difficulty = player_skill
        
        # 게임 플로우에 따른 조정
        if self.flow_state == 'easy':
            target_difficulty = min(1.0, target_difficulty + 0.1)
        elif self.flow_state == 'hard':
            target_difficulty = max(0.0, target_difficulty - 0.1)
            
        # 컴백 메커니즘
        if self.consecutive_losses > 5:
            # 플레이어가 계속 지고 있으면 더 큰 난이도 하향
            target_difficulty -= self.balance_config['comeback_boost']
        elif self.consecutive_wins > 5:
            # 플레이어가 계속 이기고 있으면 더 큰 난이도 상향
            target_difficulty += self.balance_config['comeback_boost']
        
        # 부드러운 전환
        new_level = old_level + (target_difficulty - old_level) * self.adjustment_rate
        new_level = max(self.min_difficulty, min(self.max_difficulty, new_level))
        
        # 새 난이도 프로필 생성
        self.current_difficulty = self.create_custom_difficulty(new_level)
        
        # 히스토리 기록
        self.adjustment_history.append({
            'time': self.last_adjustment_time,
            'old_level': old_level,
            'new_level': new_level,
            'player_skill': player_skill,
            'flow_state': self.flow_state
        })
        
        # 이벤트 발생
        emit_event(EventType.DIFFICULTY_CHANGED, {
            'new_level': new_level,
            'reason': self.flow_state
        })
        
        # 연속 승/패 리셋
        self.consecutive_wins = 0
        self.consecutive_losses = 0
        
    def create_custom_difficulty(self, level: float) -> DifficultyProfile:
        """커스텀 난이도 프로필 생성
        
        Args:
            level: 난이도 레벨 (0.0 ~ 1.0)
            
        Returns:
            난이도 프로필
        """
        # 개선된 비선형 보간 (더 자연스러운 난이도 커브)
        # S자 커브를 사용하여 중간 레벨에서 더 많은 변화
        curved_level = 0.5 + 0.5 * math.sin((level - 0.5) * math.pi)
        
        return DifficultyProfile(
            name="Custom",
            level=level,
            reaction_time=0.4 - 0.32 * curved_level,  # 0.4 ~ 0.08 (더 자연스러운 커브)
            prediction_accuracy=0.35 + 0.55 * level,  # 0.35 ~ 0.9 (너무 완벽하지 않게)
            movement_speed=4.0 + 6.0 * level,  # 4 ~ 10 (최대 속도 제한)
            mistake_rate=0.35 * (1 - curved_level),  # 0.35 ~ 0 (중간 레벨에서 더 많은 변화)
            special_frequency=0.03 + 0.27 * level,  # 0.03 ~ 0.3 (너무 많지 않게)
            aggression=0.15 + 0.6 * curved_level,  # 0.15 ~ 0.75 (중간 레벨에서 더 공격적)
            adaptation_rate=0.0 + 0.25 * level  # 0 ~ 0.25 (적당한 적응)
        )
        
    def set_preset_difficulty(self, preset_name: str):
        """프리셋 난이도 설정
        
        Args:
            preset_name: 프리셋 이름
        """
        presets = {
            'easy': DifficultyPresets.EASY,
            'normal': DifficultyPresets.NORMAL,
            'hard': DifficultyPresets.HARD,
            'expert': DifficultyPresets.EXPERT,
            'adaptive': DifficultyPresets.ADAPTIVE
        }
        
        if preset_name.lower() in presets:
            self.current_difficulty = presets[preset_name.lower()]
            self.base_difficulty = self.current_difficulty
            
    def get_current_difficulty(self) -> DifficultyProfile:
        """현재 난이도 반환"""
        return self.current_difficulty
        
    def save_stats(self, filepath: str = "difficulty_stats.json"):
        """난이도 통계 저장
        
        Args:
            filepath: 저장 파일 경로
        """
        stats = {
            'current_difficulty': self.current_difficulty.to_dict(),
            'player_skill': self.player_analyzer.skill_level,
            'playstyle': self.player_analyzer.playstyle,
            'consistency': self.player_analyzer.consistency,
            'adjustment_history': self.adjustment_history[-50:]  # 최근 50개
        }
        
        with open(filepath, 'w') as f:
            json.dump(stats, f, indent=2)
            
    def load_stats(self, filepath: str = "difficulty_stats.json"):
        """난이도 통계 로드
        
        Args:
            filepath: 로드 파일 경로
        """
        if not os.path.exists(filepath):
            return
            
        try:
            with open(filepath, 'r') as f:
                stats = json.load(f)
                
            # 난이도 복원
            if 'current_difficulty' in stats:
                diff_data = stats['current_difficulty']
                self.current_difficulty = DifficultyProfile(**diff_data)
                
            # 플레이어 데이터 복원
            if 'player_skill' in stats:
                self.player_analyzer.skill_level = stats['player_skill']
            if 'playstyle' in stats:
                self.player_analyzer.playstyle = stats['playstyle']
            if 'consistency' in stats:
                self.player_analyzer.consistency = stats['consistency']
                
        except Exception as e:
            print(f"Failed to load difficulty stats: {e}")
            
    def reset(self):
        """난이도 시스템 리셋"""
        self.current_difficulty = self.base_difficulty
        self.player_analyzer.reset()
        self.adjustment_history.clear()
        self.last_adjustment_time = 0
        self.flow_state = 'normal'
        self.consecutive_wins = 0
        self.consecutive_losses = 0


# 커스텀 이벤트 타입 추가
if not hasattr(EventType, 'DIFFICULTY_CHANGED'):
    EventType.DIFFICULTY_CHANGED = "difficulty_changed"