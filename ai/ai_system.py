"""
AI System - AI 베이스 시스템
모든 AI의 기본 클래스와 공통 기능
"""

import math
import random
from typing import Tuple, Optional, Dict, Any, List
from abc import ABC, abstractmethod
from core.game_state import GameState
from core.events import EventType, emit_event, subscribe


class AISystem(ABC):
    """AI 시스템 베이스 클래스"""
    
    def __init__(self):
        """AI 시스템 초기화"""
        self.game_state = GameState.get_instance()
        
        # AI 상태
        self.enabled = True
        self.update_rate = 60  # Hz
        self.update_timer = 0
        
        # 예측 설정
        self.prediction_enabled = True
        self.prediction_time = 0.5  # 초 단위 예측
        self.prediction_accuracy = 0.8  # 예측 정확도
        
        # 반응 시간
        self.reaction_time = 0.1  # 기본 반응 시간
        self.reaction_timer = 0
        
        # 목표 추적
        self.target_position = None
        self.target_velocity = None
        
        # 결정 히스토리
        self.decision_history = []
        self.max_history_size = 100
        
        # 성능 메트릭
        self.metrics = {
            'decisions_made': 0,
            'successful_hits': 0,
            'missed_balls': 0,
            'prediction_accuracy': 0,
            'avg_reaction_time': 0
        }
        
        # 이벤트 구독
        self.setup_event_handlers()
        
    def setup_event_handlers(self):
        """이벤트 핸들러 설정"""
        subscribe(EventType.BALL_HIT_BOSS, self.on_ball_hit)
        subscribe(EventType.BALL_OUT_OF_BOUNDS, self.on_ball_missed)
        
    def on_ball_hit(self, event):
        """공 히트 이벤트 처리"""
        self.metrics['successful_hits'] += 1
        
    def on_ball_missed(self, event):
        """공 놓침 이벤트 처리"""
        if event.data.get('side') == 'boss':
            self.metrics['missed_balls'] += 1
            
    @abstractmethod
    def make_decision(self, game_state: Dict[str, Any]) -> Dict[str, Any]:
        """AI 결정 만들기 (추상 메서드)
        
        Args:
            game_state: 현재 게임 상태
            
        Returns:
            AI 결정 (이동 방향, 특수 능력 사용 등)
        """
        pass
        
    @abstractmethod
    def update_strategy(self, game_state: Dict[str, Any]):
        """전략 업데이트 (추상 메서드)
        
        Args:
            game_state: 현재 게임 상태
        """
        pass
        
    def update(self, dt: float, game_state: Dict[str, Any]) -> Dict[str, Any]:
        """AI 업데이트
        
        Args:
            dt: 델타 타임
            game_state: 현재 게임 상태
            
        Returns:
            AI 결정
        """
        if not self.enabled:
            return {'move': 0, 'action': None}
            
        # 업데이트 타이머
        self.update_timer += dt
        if self.update_timer < 1.0 / self.update_rate:
            return self.get_last_decision()
            
        self.update_timer = 0
        
        # 반응 시간 체크
        self.reaction_timer += dt
        if self.reaction_timer < self.reaction_time:
            return self.get_last_decision()
            
        # 전략 업데이트
        self.update_strategy(game_state)
        
        # 예측 수행
        if self.prediction_enabled:
            predicted_state = self.predict_future_state(game_state)
            decision = self.make_decision(predicted_state)
        else:
            decision = self.make_decision(game_state)
            
        # 결정 기록
        self.record_decision(decision)
        
        # 메트릭 업데이트
        self.metrics['decisions_made'] += 1
        
        return decision
        
    def predict_future_state(self, game_state: Dict[str, Any]) -> Dict[str, Any]:
        """미래 상태 예측
        
        Args:
            game_state: 현재 게임 상태
            
        Returns:
            예측된 미래 상태
        """
        predicted_state = game_state.copy()
        
        # 공 위치 예측
        if 'ball_position' in game_state and 'ball_velocity' in game_state:
            ball_pos = game_state['ball_position']
            ball_vel = game_state['ball_velocity']
            
            # 물리 기반 예측
            future_x = ball_pos[0] + ball_vel[0] * self.prediction_time * 60
            future_y = ball_pos[1] + ball_vel[1] * self.prediction_time * 60
            
            # 벽 반사 예측
            if future_x < 0 or future_x > 600:
                future_x = max(0, min(600, future_x))
                ball_vel = (-ball_vel[0], ball_vel[1])
                
            # 예측 정확도 적용 (노이즈 추가)
            if self.prediction_accuracy < 1.0:
                noise_factor = 1.0 - self.prediction_accuracy
                future_x += random.uniform(-50, 50) * noise_factor
                future_y += random.uniform(-50, 50) * noise_factor
                
            predicted_state['ball_position'] = (future_x, future_y)
            predicted_state['ball_velocity'] = ball_vel
            
        return predicted_state
        
    def calculate_intercept_point(self, ball_pos: Tuple[float, float], 
                                 ball_vel: Tuple[float, float],
                                 paddle_y: float) -> float:
        """공 차단 지점 계산
        
        Args:
            ball_pos: 공 위치
            ball_vel: 공 속도
            paddle_y: 패들 Y 위치
            
        Returns:
            예상 차단 X 좌표
        """
        if abs(ball_vel[1]) < 0.1:  # 수직 속도가 거의 없음
            return ball_pos[0]
            
        # 패들까지 도달 시간 계산
        time_to_paddle = abs(paddle_y - ball_pos[1]) / abs(ball_vel[1])
        
        # 예상 X 위치
        intercept_x = ball_pos[0] + ball_vel[0] * time_to_paddle
        
        # 벽 반사 고려
        screen_width = 600
        if intercept_x < 0 or intercept_x > screen_width:
            # 반사 횟수 계산
            bounces = int(abs(intercept_x) / screen_width)
            
            if bounces % 2 == 0:
                intercept_x = abs(intercept_x) % screen_width
            else:
                intercept_x = screen_width - (abs(intercept_x) % screen_width)
                
        return intercept_x
        
    def calculate_optimal_position(self, game_state: Dict[str, Any]) -> float:
        """최적 위치 계산
        
        Args:
            game_state: 게임 상태
            
        Returns:
            최적 X 좌표
        """
        if 'ball_position' not in game_state or 'ball_velocity' not in game_state:
            return 300  # 중앙 위치
            
        ball_pos = game_state['ball_position']
        ball_vel = game_state['ball_velocity']
        paddle_y = game_state.get('paddle_y', 100)
        
        # 차단 지점 계산
        intercept_x = self.calculate_intercept_point(ball_pos, ball_vel, paddle_y)
        
        # 화면 경계 내로 제한
        intercept_x = max(50, min(550, intercept_x))
        
        return intercept_x
        
    def add_decision_noise(self, decision: Dict[str, Any], noise_level: float = 0.1):
        """결정에 노이즈 추가 (더 인간적인 행동)
        
        Args:
            decision: AI 결정
            noise_level: 노이즈 레벨 (0~1)
        """
        if 'move' in decision and random.random() < noise_level:
            # 가끔 잘못된 방향으로 이동
            if random.random() < 0.1:
                decision['move'] *= -1
            # 또는 이동하지 않음
            elif random.random() < 0.2:
                decision['move'] = 0
                
        return decision
        
    def record_decision(self, decision: Dict[str, Any]):
        """결정 기록
        
        Args:
            decision: AI 결정
        """
        self.decision_history.append({
            'decision': decision,
            'timestamp': self.game_state.game_time,
            'reaction_time': self.reaction_timer
        })
        
        # 히스토리 크기 제한
        if len(self.decision_history) > self.max_history_size:
            self.decision_history.pop(0)
            
        # 반응 시간 리셋
        self.reaction_timer = 0
        
    def get_last_decision(self) -> Dict[str, Any]:
        """마지막 결정 반환"""
        if self.decision_history:
            return self.decision_history[-1]['decision']
        return {'move': 0, 'action': None}
        
    def analyze_player_pattern(self, player_history: List[Dict]) -> Dict[str, Any]:
        """플레이어 패턴 분석
        
        Args:
            player_history: 플레이어 행동 히스토리
            
        Returns:
            분석된 패턴
        """
        if not player_history:
            return {}
            
        pattern = {
            'preferred_side': None,
            'avg_reaction_time': 0,
            'dash_frequency': 0,
            'charge_frequency': 0,
            'movement_style': 'balanced'
        }
        
        # 선호 방향 분석
        left_moves = sum(1 for h in player_history if h.get('move', 0) < 0)
        right_moves = sum(1 for h in player_history if h.get('move', 0) > 0)
        
        if left_moves > right_moves * 1.2:
            pattern['preferred_side'] = 'left'
        elif right_moves > left_moves * 1.2:
            pattern['preferred_side'] = 'right'
            
        # 대시 빈도
        dash_count = sum(1 for h in player_history if h.get('action') == 'dash')
        pattern['dash_frequency'] = dash_count / len(player_history) if player_history else 0
        
        # 차지 빈도
        charge_count = sum(1 for h in player_history if h.get('action') == 'charge')
        pattern['charge_frequency'] = charge_count / len(player_history) if player_history else 0
        
        # 이동 스타일
        if pattern['dash_frequency'] > 0.2:
            pattern['movement_style'] = 'aggressive'
        elif pattern['dash_frequency'] < 0.05:
            pattern['movement_style'] = 'defensive'
            
        return pattern
        
    def adjust_difficulty(self, difficulty: float):
        """난이도 조정
        
        Args:
            difficulty: 난이도 (0~1, 1이 가장 어려움)
        """
        # 반응 시간 조정
        self.reaction_time = 0.3 - (0.25 * difficulty)  # 0.05 ~ 0.3초
        
        # 예측 정확도 조정
        self.prediction_accuracy = 0.5 + (0.5 * difficulty)  # 0.5 ~ 1.0
        
        # 업데이트 레이트 조정
        self.update_rate = 30 + (30 * difficulty)  # 30 ~ 60 Hz
        
    def get_metrics(self) -> Dict[str, Any]:
        """성능 메트릭 반환"""
        # 평균 반응 시간 계산
        if self.decision_history:
            avg_reaction = sum(d['reaction_time'] for d in self.decision_history) / len(self.decision_history)
            self.metrics['avg_reaction_time'] = avg_reaction
            
        # 예측 정확도 계산
        if self.metrics['successful_hits'] + self.metrics['missed_balls'] > 0:
            self.metrics['prediction_accuracy'] = (
                self.metrics['successful_hits'] / 
                (self.metrics['successful_hits'] + self.metrics['missed_balls'])
            )
            
        return self.metrics.copy()
        
    def reset(self):
        """AI 시스템 리셋"""
        self.target_position = None
        self.target_velocity = None
        self.decision_history.clear()
        self.reaction_timer = 0
        self.update_timer = 0
        
        # 메트릭 리셋
        for key in self.metrics:
            self.metrics[key] = 0