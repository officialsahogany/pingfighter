"""
AI Strategy - AI 전략 패턴
다양한 AI 전략과 행동 패턴 정의
"""

from abc import ABC, abstractmethod
from typing import Dict, Any, List, Tuple
import random
import math


class AIStrategy(ABC):
    """AI 전략 베이스 클래스"""
    
    def __init__(self):
        self.name = "Base Strategy"
        self.description = ""
        
    @abstractmethod
    def calculate_move(self, game_state: Dict[str, Any]) -> float:
        """이동 계산
        
        Args:
            game_state: 게임 상태
            
        Returns:
            이동 값 (-1 ~ 1)
        """
        pass
        
    @abstractmethod
    def should_use_special(self, game_state: Dict[str, Any]) -> bool:
        """특수 능력 사용 여부
        
        Args:
            game_state: 게임 상태
            
        Returns:
            사용 여부
        """
        pass
        
    @abstractmethod
    def get_priority_target(self, game_state: Dict[str, Any]) -> Tuple[float, float]:
        """우선 목표 위치
        
        Args:
            game_state: 게임 상태
            
        Returns:
            목표 (x, y) 좌표
        """
        pass


class PredictiveStrategy(AIStrategy):
    """예측 기반 전략"""
    
    def __init__(self, prediction_depth: float = 1.0):
        super().__init__()
        self.name = "Predictive"
        self.description = "공의 미래 위치를 예측하여 이동"
        self.prediction_depth = prediction_depth
        
    def calculate_move(self, game_state: Dict[str, Any]) -> float:
        """예측 기반 이동"""
        if 'ball_position' not in game_state or 'ball_velocity' not in game_state:
            return 0
            
        ball_pos = game_state['ball_position']
        ball_vel = game_state['ball_velocity']
        paddle_y = game_state.get('boss_y', 100)
        current_x = game_state.get('boss_x', 300)
        
        # 패들까지 도달 시간 계산
        if abs(ball_vel[1]) < 0.1:
            return 0
            
        time_to_paddle = abs(paddle_y - ball_pos[1]) / abs(ball_vel[1])
        time_to_paddle *= self.prediction_depth
        
        # 예상 X 위치 (벽 반사 고려)
        predicted_x = self.predict_ball_position(ball_pos, ball_vel, time_to_paddle)
        
        # 이동 방향 결정
        diff = predicted_x - current_x
        if abs(diff) < 5:
            return 0
            
        return max(-1, min(1, diff / 100))
        
    def predict_ball_position(self, pos: Tuple, vel: Tuple, time: float) -> float:
        """공 위치 예측 (벽 반사 포함)"""
        future_x = pos[0] + vel[0] * time * 60
        
        # 벽 반사 계산
        screen_width = 600
        if future_x < 0 or future_x > screen_width:
            bounces = int(abs(future_x) / screen_width)
            if bounces % 2 == 0:
                future_x = abs(future_x) % screen_width
            else:
                future_x = screen_width - (abs(future_x) % screen_width)
                
        return future_x
        
    def should_use_special(self, game_state: Dict[str, Any]) -> bool:
        """예측이 확실할 때 특수 능력 사용"""
        # 공이 가까이 있고 예측이 정확할 때
        if 'ball_position' in game_state:
            ball_y = game_state['ball_position'][1]
            paddle_y = game_state.get('boss_y', 100)
            
            if abs(ball_y - paddle_y) < 150:
                return random.random() < 0.3
                
        return False
        
    def get_priority_target(self, game_state: Dict[str, Any]) -> Tuple[float, float]:
        """예측된 차단 지점"""
        if 'ball_position' in game_state and 'ball_velocity' in game_state:
            ball_pos = game_state['ball_position']
            ball_vel = game_state['ball_velocity']
            paddle_y = game_state.get('boss_y', 100)
            
            time_to_paddle = abs(paddle_y - ball_pos[1]) / max(abs(ball_vel[1]), 0.1)
            predicted_x = self.predict_ball_position(ball_pos, ball_vel, time_to_paddle)
            
            return (predicted_x, paddle_y)
            
        return (300, 100)


class ReactiveStrategy(AIStrategy):
    """반응형 전략"""
    
    def __init__(self, reaction_threshold: float = 200):
        super().__init__()
        self.name = "Reactive"
        self.description = "공이 가까워지면 빠르게 반응"
        self.reaction_threshold = reaction_threshold
        
    def calculate_move(self, game_state: Dict[str, Any]) -> float:
        """반응형 이동"""
        if 'ball_position' not in game_state:
            return 0
            
        ball_pos = game_state['ball_position']
        ball_vel = game_state.get('ball_velocity', (0, 0))
        current_x = game_state.get('boss_x', 300)
        paddle_y = game_state.get('boss_y', 100)
        
        # 공까지의 거리
        distance_y = abs(ball_pos[1] - paddle_y)
        
        # 가까이 있을 때만 반응
        if distance_y > self.reaction_threshold:
            # 중앙으로 천천히 이동
            center_diff = 300 - current_x
            return max(-0.3, min(0.3, center_diff / 200))
            
        # 공 위치로 빠르게 이동
        diff = ball_pos[0] - current_x
        
        # 거리에 따른 속도 조절
        urgency = 1.0 - (distance_y / self.reaction_threshold)
        
        return max(-1, min(1, diff / 50 * urgency))
        
    def should_use_special(self, game_state: Dict[str, Any]) -> bool:
        """위급할 때 특수 능력 사용"""
        if 'ball_position' in game_state:
            ball_pos = game_state['ball_position']
            paddle_y = game_state.get('boss_y', 100)
            current_x = game_state.get('boss_x', 300)
            
            distance_y = abs(ball_pos[1] - paddle_y)
            distance_x = abs(ball_pos[0] - current_x)
            
            # 가깝고 멀리 있을 때
            if distance_y < 100 and distance_x > 100:
                return random.random() < 0.5
                
        return False
        
    def get_priority_target(self, game_state: Dict[str, Any]) -> Tuple[float, float]:
        """현재 공 위치"""
        if 'ball_position' in game_state:
            return game_state['ball_position']
        return (300, 375)


class AggressiveStrategy(AIStrategy):
    """공격적 전략"""
    
    def __init__(self, aggression_level: float = 0.7):
        super().__init__()
        self.name = "Aggressive"
        self.description = "공격적으로 공을 추격"
        self.aggression_level = aggression_level
        
    def calculate_move(self, game_state: Dict[str, Any]) -> float:
        """공격적 이동"""
        if 'ball_position' not in game_state:
            return random.uniform(-0.5, 0.5)  # 랜덤 이동
            
        ball_pos = game_state['ball_position']
        current_x = game_state.get('boss_x', 300)
        
        # 공 방향으로 적극 이동
        diff = ball_pos[0] - current_x
        
        # 공격성에 따른 속도 증폭
        move = diff / 50 * (1 + self.aggression_level)
        
        # 오버슈팅 허용
        return max(-1.5, min(1.5, move))
        
    def should_use_special(self, game_state: Dict[str, Any]) -> bool:
        """자주 특수 능력 사용"""
        return random.random() < (0.2 + self.aggression_level * 0.3)
        
    def get_priority_target(self, game_state: Dict[str, Any]) -> Tuple[float, float]:
        """공 위치에서 약간 앞선 위치"""
        if 'ball_position' in game_state and 'ball_velocity' in game_state:
            ball_pos = game_state['ball_position']
            ball_vel = game_state['ball_velocity']
            
            # 공보다 앞선 위치
            lead_x = ball_pos[0] + ball_vel[0] * 10
            return (lead_x, ball_pos[1])
            
        return (300, 375)


class DefensiveStrategy(AIStrategy):
    """방어적 전략"""
    
    def __init__(self, defense_zone: float = 100):
        super().__init__()
        self.name = "Defensive"
        self.description = "중앙 위치를 유지하며 방어"
        self.defense_zone = defense_zone
        
    def calculate_move(self, game_state: Dict[str, Any]) -> float:
        """방어적 이동"""
        current_x = game_state.get('boss_x', 300)
        center = 300
        
        # 중앙에서 벗어난 정도
        offset = current_x - center
        
        # 방어 구역 내에 있으면 미세 조정
        if abs(offset) < self.defense_zone:
            if 'ball_position' in game_state:
                ball_x = game_state['ball_position'][0]
                # 공 방향으로 살짝 이동
                ball_offset = ball_x - center
                return max(-0.5, min(0.5, ball_offset / 200))
            return 0
            
        # 중앙으로 복귀
        return max(-0.8, min(0.8, -offset / 100))
        
    def should_use_special(self, game_state: Dict[str, Any]) -> bool:
        """방어적으로 특수 능력 사용"""
        # 점수가 뒤질 때만
        player_score = game_state.get('player_score', 0)
        boss_score = game_state.get('boss_score', 0)
        
        if player_score > boss_score:
            return random.random() < 0.3
            
        return random.random() < 0.1
        
    def get_priority_target(self, game_state: Dict[str, Any]) -> Tuple[float, float]:
        """중앙 위치"""
        return (300, game_state.get('boss_y', 100))


class TrickyStrategy(AIStrategy):
    """트릭키한 전략"""
    
    def __init__(self):
        super().__init__()
        self.name = "Tricky"
        self.description = "예측 불가능한 움직임"
        self.feint_timer = 0
        self.feint_direction = 0
        
    def calculate_move(self, game_state: Dict[str, Any]) -> float:
        """트릭키한 이동"""
        self.feint_timer += 1
        
        # 페인트 동작
        if self.feint_timer % 30 == 0:  # 0.5초마다
            self.feint_direction = random.choice([-1, 0, 1])
            
        if self.feint_direction != 0 and self.feint_timer % 30 < 10:
            # 페인트 실행
            return self.feint_direction * 0.7
            
        # 일반 이동
        if 'ball_position' in game_state:
            ball_x = game_state['ball_position'][0]
            current_x = game_state.get('boss_x', 300)
            
            diff = ball_x - current_x
            
            # 가끔 반대로 이동
            if random.random() < 0.15:
                diff *= -0.5
                
            # 랜덤 노이즈 추가
            noise = random.uniform(-30, 30)
            
            return max(-1, min(1, (diff + noise) / 80))
            
        return random.uniform(-0.5, 0.5)
        
    def should_use_special(self, game_state: Dict[str, Any]) -> bool:
        """랜덤하게 특수 능력 사용"""
        return random.random() < 0.25
        
    def get_priority_target(self, game_state: Dict[str, Any]) -> Tuple[float, float]:
        """랜덤한 목표 위치"""
        if 'ball_position' in game_state:
            ball_x = game_state['ball_position'][0]
            # 공 근처의 랜덤 위치
            target_x = ball_x + random.uniform(-100, 100)
            target_x = max(50, min(550, target_x))
            return (target_x, game_state.get('boss_y', 100))
            
        return (random.uniform(100, 500), 100)


class AdaptiveStrategy(AIStrategy):
    """적응형 전략"""
    
    def __init__(self):
        super().__init__()
        self.name = "Adaptive"
        self.description = "플레이어 패턴에 적응"
        self.player_tendency = {'left': 0, 'right': 0, 'center': 0}
        self.adaptation_rate = 0.1
        
    def analyze_player(self, game_state: Dict[str, Any]):
        """플레이어 분석"""
        if 'player_x' in game_state:
            player_x = game_state['player_x']
            
            if player_x < 200:
                self.player_tendency['left'] += self.adaptation_rate
            elif player_x > 400:
                self.player_tendency['right'] += self.adaptation_rate
            else:
                self.player_tendency['center'] += self.adaptation_rate
                
            # 정규화
            total = sum(self.player_tendency.values())
            if total > 0:
                for key in self.player_tendency:
                    self.player_tendency[key] /= total
                    
    def calculate_move(self, game_state: Dict[str, Any]) -> float:
        """적응형 이동"""
        self.analyze_player(game_state)
        
        current_x = game_state.get('boss_x', 300)
        
        # 플레이어가 선호하는 방향의 반대편 커버
        target_x = 300
        
        if self.player_tendency['left'] > 0.4:
            target_x = 200  # 왼쪽 커버
        elif self.player_tendency['right'] > 0.4:
            target_x = 400  # 오른쪽 커버
            
        # 공 위치도 고려
        if 'ball_position' in game_state:
            ball_x = game_state['ball_position'][0]
            # 가중 평균
            target_x = target_x * 0.3 + ball_x * 0.7
            
        diff = target_x - current_x
        return max(-1, min(1, diff / 80))
        
    def should_use_special(self, game_state: Dict[str, Any]) -> bool:
        """플레이어 패턴에 따라 특수 능력 사용"""
        # 플레이어가 한쪽에 치우쳐 있을 때
        max_tendency = max(self.player_tendency.values())
        if max_tendency > 0.5:
            return random.random() < 0.4
            
        return random.random() < 0.2
        
    def get_priority_target(self, game_state: Dict[str, Any]) -> Tuple[float, float]:
        """플레이어 반대편"""
        if 'player_x' in game_state:
            player_x = game_state['player_x']
            # 플레이어 반대편
            target_x = 600 - player_x
            return (target_x, game_state.get('boss_y', 100))
            
        return (300, 100)


class StrategyManager:
    """전략 관리자"""
    
    def __init__(self):
        self.strategies = {
            'predictive': PredictiveStrategy(),
            'reactive': ReactiveStrategy(),
            'aggressive': AggressiveStrategy(),
            'defensive': DefensiveStrategy(),
            'tricky': TrickyStrategy(),
            'adaptive': AdaptiveStrategy()
        }
        
        self.current_strategy = self.strategies['predictive']
        self.strategy_timer = 0
        self.strategy_duration = 5.0
        
    def update(self, dt: float, game_state: Dict[str, Any]):
        """전략 업데이트"""
        self.strategy_timer += dt
        
        if self.strategy_timer >= self.strategy_duration:
            self.strategy_timer = 0
            self.select_strategy(game_state)
            
    def select_strategy(self, game_state: Dict[str, Any]):
        """전략 선택"""
        # 게임 상황에 따른 전략 선택
        player_score = game_state.get('player_score', 0)
        boss_score = game_state.get('boss_score', 0)
        score_diff = boss_score - player_score
        
        if score_diff < -3:
            # 크게 지고 있을 때
            self.current_strategy = self.strategies['aggressive']
        elif score_diff > 3:
            # 크게 이기고 있을 때
            self.current_strategy = self.strategies['defensive']
        elif abs(score_diff) <= 1:
            # 접전일 때
            strategies = ['predictive', 'tricky', 'adaptive']
            self.current_strategy = self.strategies[random.choice(strategies)]
        else:
            # 일반 상황
            self.current_strategy = self.strategies['reactive']
            
        self.strategy_duration = random.uniform(3, 7)
        
    def get_current_strategy(self) -> AIStrategy:
        """현재 전략 반환"""
        return self.current_strategy
        
    def force_strategy(self, strategy_name: str):
        """전략 강제 변경"""
        if strategy_name in self.strategies:
            self.current_strategy = self.strategies[strategy_name]
            self.strategy_timer = 0