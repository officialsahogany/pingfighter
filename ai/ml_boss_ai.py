"""
ML Boss AI - 머신러닝 기반 보스 AI
딥러닝 모델을 활용한 고급 AI 시스템
"""

import numpy as np
import random
import math
from typing import Dict, Any, Optional, List, Tuple
from collections import deque
from ai.boss_ai import BossAI
from core.events import EventType, emit_event
from core.global_manager import GlobalManager

# TensorFlow/PyTorch는 선택적 import
try:
    import tensorflow as tf
    ML_AVAILABLE = True
except ImportError:
    ML_AVAILABLE = False
    print("TensorFlow not available. Using rule-based AI only.")


class NeuralNetwork:
    """간단한 신경망 구현 (TensorFlow 없이도 동작)"""
    
    def __init__(self, input_size: int, hidden_sizes: List[int], output_size: int):
        self.layers = []
        
        # 레이어 초기화
        prev_size = input_size
        for hidden_size in hidden_sizes:
            self.layers.append({
                'weights': np.random.randn(prev_size, hidden_size) * 0.1,
                'bias': np.zeros(hidden_size)
            })
            prev_size = hidden_size
            
        # 출력 레이어
        self.layers.append({
            'weights': np.random.randn(prev_size, output_size) * 0.1,
            'bias': np.zeros(output_size)
        })
        
    def forward(self, x: np.ndarray) -> np.ndarray:
        """순전파"""
        for i, layer in enumerate(self.layers):
            x = np.dot(x, layer['weights']) + layer['bias']
            if i < len(self.layers) - 1:
                # ReLU 활성화 (히든 레이어)
                x = np.maximum(0, x)
            else:
                # Tanh 활성화 (출력 레이어)
                x = np.tanh(x)
        return x
        
    def predict(self, state: np.ndarray) -> np.ndarray:
        """예측"""
        return self.forward(state)


class MLBossAI(BossAI):
    """머신러닝 기반 보스 AI"""
    
    def __init__(self, stage: int = 1):
        super().__init__(stage)
        
        self.global_manager = GlobalManager.get_instance()
        
        # ML 모델
        self.model = None
        self.ml_enabled = False
        
        # 상태 기록
        self.state_history = deque(maxlen=30)  # 0.5초간의 상태
        self.action_history = deque(maxlen=30)
        
        # 학습 데이터
        self.experience_buffer = deque(maxlen=1000)
        self.training_data = []
        
        # 예측 시스템
        self.prediction_model = NeuralNetwork(
            input_size=12,  # 입력 특징 수
            hidden_sizes=[64, 32],  # 히든 레이어
            output_size=3  # 출력 (이동, 행동)
        )
        
        # 패턴 인식
        self.pattern_recognizer = PatternRecognizer()
        
        # 전략 네트워크
        self.strategy_network = StrategyNetwork()
        
        # 앙상블 시스템
        self.ensemble_weights = {
            'rule_based': 0.3,
            'ml_model': 0.4,
            'pattern': 0.3
        }
        
        # ML 모델 로드 시도
        self._load_ml_model()
        
    def _load_ml_model(self):
        """ML 모델 로드"""
        if ML_AVAILABLE:
            try:
                # TensorFlow 모델 로드
                model_path = f"models/boss_stage_{self.stage}.h5"
                self.model = tf.keras.models.load_model(model_path)
                self.ml_enabled = True
                print(f"ML model loaded for stage {self.stage}")
            except:
                # 새 모델 생성
                self.model = self._create_tensorflow_model()
                self.ml_enabled = True
                print(f"New ML model created for stage {self.stage}")
        else:
            # 내장 신경망 사용
            self.ml_enabled = False
            print("Using built-in neural network")
            
    def _create_tensorflow_model(self):
        """TensorFlow 모델 생성"""
        if not ML_AVAILABLE:
            return None
            
        model = tf.keras.Sequential([
            tf.keras.layers.Dense(128, activation='relu', input_shape=(12,)),
            tf.keras.layers.Dropout(0.2),
            tf.keras.layers.Dense(64, activation='relu'),
            tf.keras.layers.Dropout(0.2),
            tf.keras.layers.Dense(32, activation='relu'),
            tf.keras.layers.Dense(3, activation='tanh')  # 이동, 액션, 특수
        ])
        
        model.compile(
            optimizer='adam',
            loss='mse',
            metrics=['mae']
        )
        
        return model
        
    def extract_features(self, game_state: Dict[str, Any]) -> np.ndarray:
        """게임 상태에서 특징 추출"""
        features = []
        
        # 공 위치와 속도
        ball_pos = game_state.get('ball_position', [300, 400])
        ball_vel = game_state.get('ball_velocity', [0, 5])
        features.extend([
            ball_pos[0] / 600,  # 정규화
            ball_pos[1] / 750,
            ball_vel[0] / 10,
            ball_vel[1] / 10
        ])
        
        # 보스 위치
        boss_x = game_state.get('boss_x', 300) / 600
        boss_y = game_state.get('boss_y', 100) / 750
        features.extend([boss_x, boss_y])
        
        # 플레이어 위치
        player_x = game_state.get('player_x', 300) / 600
        player_y = game_state.get('player_y', 650) / 750
        features.extend([player_x, player_y])
        
        # 점수 차이
        score_diff = (game_state.get('boss_score', 0) - game_state.get('player_score', 0)) / 10
        features.append(score_diff)
        
        # 시간 정보 (게임 진행도)
        game_time = game_state.get('game_time', 0) / 300  # 5분 기준
        features.append(game_time)
        
        # 특수 능력 쿨다운
        special_cooldown = self.special_cooldown / 10
        features.append(special_cooldown)
        
        # 현재 페이즈
        phase = self.current_phase / self.max_phases
        features.append(phase)
        
        return np.array(features, dtype=np.float32)
        
    def make_decision(self, game_state: Dict[str, Any]) -> Dict[str, Any]:
        """AI 결정 (앙상블 방식)"""
        
        # 특징 추출
        features = self.extract_features(game_state)
        
        # 상태 기록
        self.state_history.append(features)
        
        # 1. 규칙 기반 결정
        rule_decision = super().make_decision(game_state)
        
        # 2. ML 모델 예측
        ml_decision = self.ml_predict(features, game_state)
        
        # 3. 패턴 기반 예측
        pattern_decision = self.pattern_predict(game_state)
        
        # 앙상블 결정
        final_decision = self.ensemble_decision(
            rule_decision,
            ml_decision,
            pattern_decision
        )
        
        # 액션 기록
        self.action_history.append(final_decision)
        
        # 경험 저장 (학습용)
        self.store_experience(features, final_decision, game_state)
        
        return final_decision
        
    def ml_predict(self, features: np.ndarray, game_state: Dict[str, Any]) -> Dict[str, Any]:
        """ML 모델 예측"""
        decision = {
            'move': 0,
            'action': None,
            'special': None
        }
        
        # 예측
        if self.ml_enabled and self.model:
            # TensorFlow 모델 사용
            prediction = self.model.predict(features.reshape(1, -1), verbose=0)[0]
        else:
            # 내장 신경망 사용
            prediction = self.prediction_model.predict(features.reshape(1, -1))[0]
            
        # 예측값 해석
        move = prediction[0] * self.movement_speed
        action_prob = prediction[1]
        special_prob = prediction[2]
        
        decision['move'] = move
        
        # 액션 결정
        if action_prob > 0.5:
            decision['action'] = 'charge' if action_prob > 0.7 else 'dash'
            
        # 특수 능력
        if special_prob > 0.6 and self.can_use_special:
            decision['special'] = self.choose_special_ability(game_state)
            
        return decision
        
    def pattern_predict(self, game_state: Dict[str, Any]) -> Dict[str, Any]:
        """패턴 기반 예측"""
        decision = {
            'move': 0,
            'action': None,
            'special': None
        }
        
        # 패턴 인식
        pattern = self.pattern_recognizer.recognize(self.state_history)
        
        if pattern:
            # 인식된 패턴에 대한 대응
            if pattern['type'] == 'player_left_bias':
                decision['move'] = -self.movement_speed * 0.7
            elif pattern['type'] == 'player_right_bias':
                decision['move'] = self.movement_speed * 0.7
            elif pattern['type'] == 'player_center':
                decision['move'] = 0
                decision['action'] = 'charge'
            elif pattern['type'] == 'player_aggressive':
                decision['action'] = 'defensive'
                
        return decision
        
    def ensemble_decision(self, rule_decision: Dict, ml_decision: Dict, 
                         pattern_decision: Dict) -> Dict[str, Any]:
        """앙상블 결정 통합"""
        final_decision = {
            'move': 0,
            'action': None,
            'special': None
        }
        
        # 이동 결정 (가중 평균)
        final_decision['move'] = (
            rule_decision['move'] * self.ensemble_weights['rule_based'] +
            ml_decision['move'] * self.ensemble_weights['ml_model'] +
            pattern_decision['move'] * self.ensemble_weights['pattern']
        )
        
        # 액션 결정 (투표)
        actions = [rule_decision['action'], ml_decision['action'], pattern_decision['action']]
        action_votes = {}
        for action in actions:
            if action:
                action_votes[action] = action_votes.get(action, 0) + 1
                
        if action_votes:
            final_decision['action'] = max(action_votes, key=action_votes.get)
            
        # 특수 능력 (OR 연산)
        final_decision['special'] = (
            rule_decision['special'] or 
            ml_decision['special'] or 
            pattern_decision['special']
        )
        
        return final_decision
        
    def store_experience(self, features: np.ndarray, action: Dict, game_state: Dict):
        """경험 저장 (학습용)"""
        experience = {
            'features': features,
            'action': action,
            'reward': 0,  # 나중에 계산
            'next_state': None
        }
        
        self.experience_buffer.append(experience)
        
    def update_rewards(self, scored: bool, conceded: bool):
        """보상 업데이트"""
        # 최근 경험들에 대한 보상 계산
        reward = 0
        if scored:
            reward = 1.0  # 득점
        elif conceded:
            reward = -1.0  # 실점
            
        # 최근 10개 액션에 보상 전파
        for i in range(max(0, len(self.experience_buffer) - 10), len(self.experience_buffer)):
            discount = 0.9 ** (len(self.experience_buffer) - i - 1)
            self.experience_buffer[i]['reward'] += reward * discount
            
    def train(self):
        """모델 학습 (오프라인)"""
        if not self.ml_enabled or len(self.experience_buffer) < 100:
            return
            
        # 학습 데이터 준비
        batch = random.sample(self.experience_buffer, 32)
        
        features = np.array([exp['features'] for exp in batch])
        targets = np.array([[exp['action']['move'] / self.movement_speed,
                           1.0 if exp['action']['action'] else 0.0,
                           1.0 if exp['action']['special'] else 0.0] 
                          for exp in batch])
                          
        # 모델 학습
        if ML_AVAILABLE:
            self.model.fit(features, targets, epochs=1, verbose=0)
            
    def adapt_weights(self, performance_metrics: Dict):
        """앙상블 가중치 적응"""
        # 성능에 따라 가중치 조정
        if performance_metrics.get('ml_accuracy', 0) > 0.7:
            self.ensemble_weights['ml_model'] = min(0.6, self.ensemble_weights['ml_model'] + 0.05)
            self.ensemble_weights['rule_based'] = max(0.2, self.ensemble_weights['rule_based'] - 0.025)
            self.ensemble_weights['pattern'] = max(0.2, self.ensemble_weights['pattern'] - 0.025)
            
        # 정규화
        total = sum(self.ensemble_weights.values())
        for key in self.ensemble_weights:
            self.ensemble_weights[key] /= total


class PatternRecognizer:
    """패턴 인식 시스템"""
    
    def __init__(self):
        self.patterns = {
            'player_left_bias': [],
            'player_right_bias': [],
            'player_center': [],
            'player_aggressive': [],
            'player_defensive': []
        }
        
    def recognize(self, state_history: deque) -> Optional[Dict]:
        """패턴 인식"""
        if len(state_history) < 10:
            return None
            
        # 최근 상태 분석
        recent_states = list(state_history)[-10:]
        
        # 플레이어 위치 편향 분석
        player_positions = [state[6] for state in recent_states]  # player_x
        avg_position = np.mean(player_positions)
        
        if avg_position < 0.4:
            return {'type': 'player_left_bias', 'confidence': 0.8}
        elif avg_position > 0.6:
            return {'type': 'player_right_bias', 'confidence': 0.8}
        elif 0.45 < avg_position < 0.55:
            return {'type': 'player_center', 'confidence': 0.7}
            
        # 플레이어 움직임 패턴
        position_changes = np.diff(player_positions)
        avg_movement = np.mean(np.abs(position_changes))
        
        if avg_movement > 0.1:
            return {'type': 'player_aggressive', 'confidence': 0.75}
        elif avg_movement < 0.03:
            return {'type': 'player_defensive', 'confidence': 0.75}
            
        return None


class StrategyNetwork:
    """전략 선택 네트워크"""
    
    def __init__(self):
        self.strategies = {
            'aggressive': {'weight': 0.25, 'success_rate': 0.5},
            'defensive': {'weight': 0.25, 'success_rate': 0.5},
            'balanced': {'weight': 0.25, 'success_rate': 0.5},
            'tricky': {'weight': 0.25, 'success_rate': 0.5}
        }
        
    def select_strategy(self, game_state: Dict, pattern: Optional[Dict]) -> str:
        """전략 선택"""
        # 점수 차이
        score_diff = game_state.get('boss_score', 0) - game_state.get('player_score', 0)
        
        # 패턴 기반 전략 조정
        if pattern:
            if pattern['type'] == 'player_aggressive':
                self.strategies['defensive']['weight'] *= 1.5
            elif pattern['type'] == 'player_defensive':
                self.strategies['aggressive']['weight'] *= 1.5
                
        # 점수 기반 조정
        if score_diff < -2:
            self.strategies['aggressive']['weight'] *= 2.0
        elif score_diff > 2:
            self.strategies['defensive']['weight'] *= 1.5
            
        # 성공률 기반 가중치 조정
        for strategy in self.strategies.values():
            strategy['weight'] *= strategy['success_rate']
            
        # 정규화
        total_weight = sum(s['weight'] for s in self.strategies.values())
        for strategy in self.strategies.values():
            strategy['weight'] /= total_weight
            
        # 확률적 선택
        rand = random.random()
        cumulative = 0
        
        for name, strategy in self.strategies.items():
            cumulative += strategy['weight']
            if rand < cumulative:
                return name
                
        return 'balanced'
        
    def update_success_rate(self, strategy: str, success: bool):
        """성공률 업데이트"""
        if strategy in self.strategies:
            # 지수 이동 평균
            alpha = 0.1
            current_rate = self.strategies[strategy]['success_rate']
            self.strategies[strategy]['success_rate'] = (
                alpha * (1.0 if success else 0.0) + (1 - alpha) * current_rate
            )


class AdvancedMLBoss(MLBossAI):
    """고급 ML 보스 (스테이지 6 전용)"""
    
    def __init__(self):
        super().__init__(stage=6)
        
        # 고급 기능 활성화
        self.meta_learning = True
        self.opponent_modeling = True
        self.multi_objective = True
        
        # 상대 모델링
        self.opponent_model = NeuralNetwork(
            input_size=8,
            hidden_sizes=[32, 16],
            output_size=4  # 플레이어 행동 예측
        )
        
        # 메타 학습 시스템
        self.meta_learner = {
            'learning_rate': 0.01,
            'adaptation_speed': 0.1,
            'strategy_memory': deque(maxlen=50)
        }
        
    def predict_player_action(self, game_state: Dict) -> Dict:
        """플레이어 행동 예측"""
        # 플레이어 특징 추출
        features = self.extract_player_features(game_state)
        
        # 예측
        prediction = self.opponent_model.predict(features.reshape(1, -1))[0]
        
        return {
            'predicted_move': prediction[0],
            'predicted_dash': prediction[1] > 0.5,
            'predicted_item': prediction[2] > 0.5,
            'confidence': prediction[3]
        }
        
    def extract_player_features(self, game_state: Dict) -> np.ndarray:
        """플레이어 특징 추출"""
        features = []
        
        # 플레이어 위치
        features.append(game_state.get('player_x', 300) / 600)
        features.append(game_state.get('player_y', 650) / 750)
        
        # 공과의 거리
        ball_pos = game_state.get('ball_position', [300, 400])
        player_x = game_state.get('player_x', 300)
        distance = abs(ball_pos[0] - player_x) / 600
        features.append(distance)
        
        # 속도
        features.append(game_state.get('player_velocity', 0) / 10)
        
        # 대시 상태
        features.append(1.0 if game_state.get('player_dashing', False) else 0.0)
        
        # 점수 상황
        score_diff = (game_state.get('player_score', 0) - game_state.get('boss_score', 0)) / 10
        features.append(score_diff)
        
        # 시간
        features.append(game_state.get('game_time', 0) / 300)
        
        # 최근 행동 패턴
        recent_action = 0.5  # 기본값
        if len(self.action_history) > 0:
            recent_action = self.action_history[-1].get('move', 0) / 10
        features.append(recent_action)
        
        return np.array(features, dtype=np.float32)