"""
BossAI - 보스 AI 시스템
스테이지별 보스 AI 패턴 및 행동 관리
"""

import random
import math
from typing import Tuple, Optional, Dict, Any
from core.game_state import GameState
from core.events import EventType, emit_event


class BossAI:
    """보스 AI 관리자"""
    
    def __init__(self, screen_width: int = 600):
        self.game_state = GameState.get_instance()
        self.screen_width = screen_width
        
        # AI 설정
        self.reaction_time = 0  # 반응 시간 (프레임)
        self.prediction_accuracy = 0.8  # 예측 정확도
        self.aggression_level = 0.5  # 공격성
        
        # 스테이지별 AI 설정
        self.stage_configs = {
            1: {'speed': 6, 'reaction': 10, 'accuracy': 0.7, 'aggression': 0.3},
            2: {'speed': 7, 'reaction': 8, 'accuracy': 0.75, 'aggression': 0.4},
            3: {'speed': 8, 'reaction': 6, 'accuracy': 0.8, 'aggression': 0.5},
            4: {'speed': 9, 'reaction': 5, 'accuracy': 0.85, 'aggression': 0.6},
            5: {'speed': 10, 'reaction': 4, 'accuracy': 0.9, 'aggression': 0.7},
            6: {'speed': 11, 'reaction': 3, 'accuracy': 0.95, 'aggression': 0.8},
        }
        
    def get_stage_config(self, stage: int) -> Dict[str, Any]:
        """스테이지별 AI 설정 반환
        
        Args:
            stage: 스테이지 번호
            
        Returns:
            AI 설정 딕셔너리
        """
        if stage in self.stage_configs:
            return self.stage_configs[stage]
        else:
            # 6 스테이지 이후는 점진적으로 어려워짐
            base = self.stage_configs[6]
            return {
                'speed': base['speed'] + (stage - 6) * 0.5,
                'reaction': max(1, base['reaction'] - (stage - 6) * 0.2),
                'accuracy': min(1.0, base['accuracy'] + (stage - 6) * 0.01),
                'aggression': min(1.0, base['aggression'] + (stage - 6) * 0.05)
            }
            
    def calculate_boss_movement(self, boss_x: float, boss_width: float, 
                              ball_x: float, ball_y: float, 
                              ball_vx: float, ball_vy: float) -> float:
        """보스 움직임 계산
        
        Args:
            boss_x: 보스 패들 X 위치
            boss_width: 보스 패들 너비
            ball_x: 공 X 위치
            ball_y: 공 Y 위치
            ball_vx: 공 X 속도
            ball_vy: 공 Y 속도
            
        Returns:
            보스 이동 속도 (음수: 왼쪽, 양수: 오른쪽)
        """
        stage = self.game_state.current_stage
        config = self.get_stage_config(stage)
        
        # 공이 보스 쪽으로 오는지 확인
        if ball_vy >= 0:  # 공이 아래로 가는 중
            return 0
            
        # 공의 예상 도착 위치 계산
        if ball_vy != 0:
            time_to_reach = abs((100 - ball_y) / ball_vy)  # 보스 Y 위치까지 시간
            predicted_x = ball_x + ball_vx * time_to_reach
            
            # 벽 반사 고려
            if predicted_x < 0:
                predicted_x = -predicted_x
            elif predicted_x > self.screen_width:
                predicted_x = 2 * self.screen_width - predicted_x
        else:
            predicted_x = ball_x
            
        # 예측 정확도 적용 (약간의 오차 추가)
        accuracy = config['accuracy']
        error_range = (1 - accuracy) * boss_width
        predicted_x += random.uniform(-error_range, error_range)
        
        # 보스 중심과 예측 위치의 차이
        boss_center = boss_x + boss_width / 2
        diff = predicted_x - boss_center
        
        # 반응 시간 적용
        if abs(diff) < config['reaction']:
            return 0
            
        # 이동 속도 계산
        move_speed = config['speed']
        if diff > 0:
            return min(move_speed, diff)
        else:
            return max(-move_speed, diff)
            
    def should_use_special_ability(self, ball_y: float, ball_vy: float) -> bool:
        """특수 능력 사용 여부 결정
        
        Args:
            ball_y: 공 Y 위치
            ball_vy: 공 Y 속도
            
        Returns:
            특수 능력 사용 여부
        """
        stage = self.game_state.current_stage
        config = self.get_stage_config(stage)
        
        # 공이 보스에게 다가올 때만
        if ball_vy >= 0:
            return False
            
        # 공이 가까이 있을 때
        if ball_y > 300:
            return False
            
        # 공격성에 따른 확률
        use_chance = config['aggression']
        return random.random() < use_chance
        
    def get_boss_behavior_pattern(self, stage: int) -> str:
        """스테이지별 보스 행동 패턴 반환
        
        Args:
            stage: 스테이지 번호
            
        Returns:
            행동 패턴 이름
        """
        patterns = {
            1: 'basic',      # 기본 패턴
            2: 'defensive',  # 수비적
            3: 'emotional',  # 감정적 (멘헤라)
            4: 'magnetic',   # 자기장 사용
            5: 'random',     # 슬롯머신 (무작위)
            6: 'aggressive'  # 공격적 (체력형)
        }
        
        if stage in patterns:
            return patterns[stage]
        else:
            # 6 스테이지 이후는 혼합 패턴
            return 'mixed'
            
    def execute_special_pattern(self, pattern: str, game_context: Dict[str, Any]) -> Dict[str, Any]:
        """특수 패턴 실행
        
        Args:
            pattern: 패턴 이름
            game_context: 게임 컨텍스트 (공 위치, 속도 등)
            
        Returns:
            실행 결과 (이동 방향, 특수 능력 사용 등)
        """
        result = {
            'move_direction': 0,
            'use_special': False,
            'special_type': None
        }
        
        if pattern == 'defensive':
            # 수비적 패턴: 공을 따라가되 중앙 선호
            center_bias = (self.screen_width / 2 - game_context['boss_x']) * 0.1
            result['move_direction'] = game_context['base_move'] + center_bias
            
        elif pattern == 'emotional':
            # 감정적 패턴: 급격한 움직임
            if random.random() < 0.1:  # 10% 확률로 급전환
                result['move_direction'] = random.choice([-10, 10])
            else:
                result['move_direction'] = game_context['base_move'] * 1.5
                
        elif pattern == 'magnetic':
            # 자기장 패턴: 특수 능력 자주 사용
            result['use_special'] = random.random() < 0.3
            result['special_type'] = 'magnetic_field'
            result['move_direction'] = game_context['base_move']
            
        elif pattern == 'random':
            # 무작위 패턴: 예측 불가능한 움직임
            result['move_direction'] = random.uniform(-8, 8)
            result['use_special'] = random.random() < 0.2
            
        elif pattern == 'aggressive':
            # 공격적 패턴: 빠른 움직임과 특수 능력
            result['move_direction'] = game_context['base_move'] * 1.3
            result['use_special'] = random.random() < 0.4
            result['special_type'] = 'power_shot'
            
        else:
            # 기본 패턴
            result['move_direction'] = game_context['base_move']
            
        # 이벤트 발생
        if result['use_special']:
            emit_event(EventType.BOSS_SPECIAL_ATTACK, {
                'stage': self.game_state.current_stage,
                'special_type': result['special_type'],
                'pattern': pattern
            })
            
        return result
        
    def adapt_to_player_skill(self, player_performance: Dict[str, Any]):
        """플레이어 실력에 따른 AI 조정
        
        Args:
            player_performance: 플레이어 성과 데이터
        """
        # 플레이어가 너무 잘하면 AI 강화
        if player_performance.get('win_rate', 0.5) > 0.7:
            self.prediction_accuracy = min(1.0, self.prediction_accuracy + 0.05)
            self.aggression_level = min(1.0, self.aggression_level + 0.05)
            
        # 플레이어가 너무 못하면 AI 약화
        elif player_performance.get('win_rate', 0.5) < 0.3:
            self.prediction_accuracy = max(0.5, self.prediction_accuracy - 0.05)
            self.aggression_level = max(0.2, self.aggression_level - 0.05)