"""
Boss AI - 보스 AI 로직
각 스테이지별 보스 AI 구현
"""

import math
import random
from typing import Dict, Any, Optional, Tuple
from ai.ai_system import AISystem
from core.events import EventType, emit_event

# ML AI 선택적 import
try:
    from ai.ml_boss_ai import MLBossAI, AdvancedMLBoss
    ML_AI_AVAILABLE = True
except ImportError:
    ML_AI_AVAILABLE = False


class BossAI(AISystem):
    """보스 AI 클래스"""
    
    def __init__(self, stage: int = 1):
        """보스 AI 초기화
        
        Args:
            stage: 스테이지 번호
        """
        super().__init__()
        
        self.stage = stage
        self.boss_name = self.get_boss_name(stage)
        
        # 스테이지 특수 기능 연결
        from game_logic.stage_features import get_stage_features
        self.stage_features = get_stage_features()
        self.stage_features.set_stage(stage)
        
        # 스테이지별 AI 특성
        self.setup_stage_characteristics()
        
        # 전략 상태
        self.current_strategy = 'balanced'
        self.strategy_timer = 0
        self.strategy_duration = 5.0
        
        # 특수 능력
        self.special_cooldown = 0
        self.special_charge = 0
        self.can_use_special = False
        
        # 행동 패턴
        self.behavior_pattern = 'normal'
        self.pattern_timer = 0
        
        # 페이즈 시스템 (체력 기반)
        self.current_phase = 1
        self.max_phases = min(3, stage)
        
        # 학습 시스템
        self.player_analysis = {}
        self.adaptation_level = 0
        
    def get_boss_name(self, stage: int) -> str:
        """보스 이름 반환
        
        Args:
            stage: 스테이지 번호
            
        Returns:
            보스 이름
        """
        boss_names = {
            1: "Training Bot",
            2: "Speed Demon",
            3: "Trickster",
            4: "Guardian",
            5: "Destroyer",
            6: "Final Boss"
        }
        return boss_names.get(stage, f"Boss {stage}")
        
    def setup_stage_characteristics(self):
        """스테이지별 특성 설정"""
        characteristics = {
            1: {  # Training Bot - 초보자용
                'reaction_time': 0.3,
                'prediction_accuracy': 0.5,
                'movement_speed': 5.0,
                'aggression': 0.2,
                'special_frequency': 0.1,
                'mistake_rate': 0.2
            },
            2: {  # Speed Demon - 빠른 반응
                'reaction_time': 0.2,
                'prediction_accuracy': 0.6,
                'movement_speed': 7.0,
                'aggression': 0.4,
                'special_frequency': 0.15,
                'mistake_rate': 0.15
            },
            3: {  # Trickster - 예측 불가능
                'reaction_time': 0.15,
                'prediction_accuracy': 0.7,
                'movement_speed': 6.0,
                'aggression': 0.5,
                'special_frequency': 0.25,
                'mistake_rate': 0.1,
                'uses_feints': True
            },
            4: {  # Guardian - 방어적
                'reaction_time': 0.1,
                'prediction_accuracy': 0.8,
                'movement_speed': 5.5,
                'aggression': 0.3,
                'special_frequency': 0.2,
                'mistake_rate': 0.08,
                'defensive_bonus': 1.2
            },
            5: {  # Destroyer - 공격적
                'reaction_time': 0.08,
                'prediction_accuracy': 0.85,
                'movement_speed': 8.0,
                'aggression': 0.7,
                'special_frequency': 0.3,
                'mistake_rate': 0.05,
                'power_bonus': 1.3
            },
            6: {  # Final Boss - 모든 능력
                'reaction_time': 0.05,
                'prediction_accuracy': 0.9,
                'movement_speed': 9.0,
                'aggression': 0.6,
                'special_frequency': 0.35,
                'mistake_rate': 0.02,
                'adaptive_learning': True,
                'all_abilities': True
            }
        }
        
        if self.stage in characteristics:
            char = characteristics[self.stage]
            self.reaction_time = char['reaction_time']
            self.prediction_accuracy = char['prediction_accuracy']
            self.movement_speed = char['movement_speed']
            self.aggression = char['aggression']
            self.special_frequency = char['special_frequency']
            self.mistake_rate = char.get('mistake_rate', 0.1)
            
            # 특수 능력
            self.uses_feints = char.get('uses_feints', False)
            self.defensive_bonus = char.get('defensive_bonus', 1.0)
            self.power_bonus = char.get('power_bonus', 1.0)
            self.adaptive_learning = char.get('adaptive_learning', False)
            self.all_abilities = char.get('all_abilities', False)
            
    def make_decision(self, game_state: Dict[str, Any]) -> Dict[str, Any]:
        """AI 결정 만들기
        
        Args:
            game_state: 현재 게임 상태
            
        Returns:
            AI 결정
        """
        decision = {
            'move': 0,
            'action': None,
            'special': None
        }
        
        # 실수 확률
        if random.random() < self.mistake_rate:
            return self.make_mistake(decision)
            
        # 현재 전략에 따른 결정
        if self.current_strategy == 'aggressive':
            decision = self.aggressive_decision(game_state)
        elif self.current_strategy == 'defensive':
            decision = self.defensive_decision(game_state)
        elif self.current_strategy == 'tricky':
            decision = self.tricky_decision(game_state)
        else:
            decision = self.balanced_decision(game_state)
            
        # 특수 능력 체크
        if self.can_use_special and random.random() < self.special_frequency:
            decision['special'] = self.choose_special_ability(game_state)
            
        # 페인트 동작 (Trickster)
        if self.uses_feints and random.random() < 0.2:
            decision = self.add_feint(decision)
            
        return decision
        
    def balanced_decision(self, game_state: Dict[str, Any]) -> Dict[str, Any]:
        """균형잡힌 결정
        
        Args:
            game_state: 게임 상태
            
        Returns:
            결정
        """
        # 최적 위치 계산
        target_x = self.calculate_optimal_position(game_state)
        current_x = game_state.get('boss_x', 300)
        
        # 이동 결정
        diff = target_x - current_x
        move = 0
        
        if abs(diff) > 5:
            move = 1 if diff > 0 else -1
            
            # 속도 조절
            if abs(diff) > 50:
                move *= 1.5  # 빠른 이동
            elif abs(diff) < 20:
                move *= 0.5  # 느린 이동
                
        return {
            'move': move * self.movement_speed,
            'action': None,
            'special': None
        }
        
    def aggressive_decision(self, game_state: Dict[str, Any]) -> Dict[str, Any]:
        """공격적인 결정
        
        Args:
            game_state: 게임 상태
            
        Returns:
            결정
        """
        decision = self.balanced_decision(game_state)
        
        # 더 빠른 이동
        decision['move'] *= 1.3 * self.power_bonus
        
        # 공격적인 위치 선정 (공을 향해 더 적극적으로 이동)
        if 'ball_position' in game_state:
            ball_x = game_state['ball_position'][0]
            current_x = game_state.get('boss_x', 300)
            
            # 공 방향으로 선제 이동
            if abs(ball_x - current_x) > 30:
                decision['move'] = (1 if ball_x > current_x else -1) * self.movement_speed * 1.5
                
        # 차지샷 시도
        if random.random() < 0.3:
            decision['action'] = 'charge'
            
        return decision
        
    def defensive_decision(self, game_state: Dict[str, Any]) -> Dict[str, Any]:
        """방어적인 결정
        
        Args:
            game_state: 게임 상태
            
        Returns:
            결정
        """
        decision = self.balanced_decision(game_state)
        
        # 중앙 위치 선호
        current_x = game_state.get('boss_x', 300)
        center_bias = (300 - current_x) * 0.1
        decision['move'] += center_bias
        
        # 느린 이동
        decision['move'] *= 0.8 * self.defensive_bonus
        
        # 안전한 위치 유지
        if abs(current_x - 300) < 50:
            decision['move'] *= 0.5
            
        return decision
        
    def tricky_decision(self, game_state: Dict[str, Any]) -> Dict[str, Any]:
        """트릭키한 결정
        
        Args:
            game_state: 게임 상태
            
        Returns:
            결정
        """
        decision = self.balanced_decision(game_state)
        
        # 랜덤한 움직임 추가
        if random.random() < 0.3:
            decision['move'] += random.uniform(-3, 3) * self.movement_speed
            
        # 가짜 움직임
        if random.random() < 0.2:
            decision['move'] *= -0.5  # 반대 방향으로 살짝
            
        # 갑작스런 대시
        if random.random() < 0.15:
            decision['action'] = 'dash'
            decision['move'] *= 2
            
        return decision
        
    def make_mistake(self, decision: Dict[str, Any]) -> Dict[str, Any]:
        """실수 만들기 (더 인간적인 AI)
        
        Args:
            decision: 원래 결정
            
        Returns:
            실수가 포함된 결정
        """
        mistake_type = random.choice(['wrong_direction', 'no_move', 'overshoot'])
        
        if mistake_type == 'wrong_direction':
            decision['move'] = random.choice([-1, 1]) * self.movement_speed * 0.5
        elif mistake_type == 'no_move':
            decision['move'] = 0
        elif mistake_type == 'overshoot':
            decision['move'] = random.choice([-1, 1]) * self.movement_speed * 2
            
        return decision
        
    def add_feint(self, decision: Dict[str, Any]) -> Dict[str, Any]:
        """페인트 동작 추가
        
        Args:
            decision: 원래 결정
            
        Returns:
            페인트가 추가된 결정
        """
        # 짧은 반대 방향 움직임
        feint_decision = decision.copy()
        feint_decision['move'] *= -0.3
        feint_decision['feint'] = True
        
        return feint_decision
        
    def choose_special_ability(self, game_state: Dict[str, Any]) -> str:
        """특수 능력 선택
        
        Args:
            game_state: 게임 상태
            
        Returns:
            특수 능력 이름
        """
        # 스테이지별 고유 능력 우선 사용
        if self.stage == 1 and random.random() < 0.3:
            if self.stage_features.activate_whip():
                return 'whip'
                
        elif self.stage == 2 and random.random() < 0.25:
            if self.stage_features.activate_speed_defense():
                return 'speed_defense'
                
        elif self.stage == 3:
            # 감정 게이지 체크
            stats = self.stage_features.get_stats()
            if stats.get('emotional_gauge', 0) >= 100:
                if self.stage_features.activate_emotional_overdrive():
                    return 'emotional_overdrive'
                    
        elif self.stage == 4 and random.random() < 0.3:
            if self.stage_features.activate_magnetic_field():
                return 'magnetic_field'
                
        elif self.stage == 5 and random.random() < 0.35:
            if self.stage_features.activate_flame_throw():
                return 'flame_throw'
                
        elif self.stage == 6:
            # 야마토 캐논 또는 미사일 포격
            if random.random() < 0.2:
                if self.stage_features.charge_yamato_cannon():
                    return 'yamato_cannon'
            elif random.random() < 0.3:
                if self.stage_features.activate_missile_barrage():
                    return 'missile_barrage'
        
        # 기본 능력들
        available_abilities = []
        
        if self.stage >= 2:
            available_abilities.append('speed_boost')
        if self.stage >= 3:
            available_abilities.append('curve_shot')
        if self.stage >= 4:
            available_abilities.append('shield')
        if self.stage >= 5:
            available_abilities.append('power_shot')
        if self.stage >= 6 or self.all_abilities:
            available_abilities.extend(['multi_ball', 'slow_motion', 'teleport'])
            
        if available_abilities and random.random() < 0.5:
            return random.choice(available_abilities)
            
        return None
        
    def update_strategy(self, game_state: Dict[str, Any]):
        """전략 업데이트
        
        Args:
            game_state: 게임 상태
        """
        self.strategy_timer += 1/60  # 60 FPS 가정
        
        # 전략 변경 시간
        if self.strategy_timer >= self.strategy_duration:
            self.strategy_timer = 0
            self.choose_new_strategy(game_state)
            
        # 적응형 학습 (Final Boss)
        if self.adaptive_learning:
            self.adapt_to_player(game_state)
            
        # 페이즈 체크
        self.check_phase_change(game_state)
        
    def choose_new_strategy(self, game_state: Dict[str, Any]):
        """새로운 전략 선택
        
        Args:
            game_state: 게임 상태
        """
        # 점수 차이에 따른 전략
        score_diff = game_state.get('boss_score', 0) - game_state.get('player_score', 0)
        
        if score_diff < -3:
            # 뒤지고 있을 때 - 공격적
            self.current_strategy = 'aggressive'
            self.aggression = min(1.0, self.aggression + 0.1)
        elif score_diff > 3:
            # 이기고 있을 때 - 방어적
            self.current_strategy = 'defensive'
            self.aggression = max(0.2, self.aggression - 0.1)
        else:
            # 비슷할 때 - 다양한 전략
            strategies = ['balanced', 'tricky']
            if self.stage >= 3:
                strategies.append('aggressive')
            if self.stage >= 4:
                strategies.append('defensive')
                
            self.current_strategy = random.choice(strategies)
            
        # 전략 변경 이벤트
        emit_event(EventType.BOSS_PHASE_CHANGED, {
            'strategy': self.current_strategy,
            'phase': self.current_phase
        })
        
    def adapt_to_player(self, game_state: Dict[str, Any]):
        """플레이어에 적응
        
        Args:
            game_state: 게임 상태
        """
        # 플레이어 패턴 분석
        if 'player_history' in game_state:
            self.player_analysis = self.analyze_player_pattern(game_state['player_history'])
            
            # 적응 레벨 증가
            self.adaptation_level = min(1.0, self.adaptation_level + 0.01)
            
            # 플레이어 스타일에 따른 대응
            if self.player_analysis.get('movement_style') == 'aggressive':
                self.defensive_bonus *= 1.1
            elif self.player_analysis.get('movement_style') == 'defensive':
                self.aggression = min(1.0, self.aggression + 0.05)
                
            # 플레이어 선호 방향 대응
            preferred_side = self.player_analysis.get('preferred_side')
            if preferred_side:
                # 선호 방향을 막는 위치 선정
                self.position_bias = -0.2 if preferred_side == 'left' else 0.2
                
    def check_phase_change(self, game_state: Dict[str, Any]):
        """페이즈 변경 체크
        
        Args:
            game_state: 게임 상태
        """
        # 점수 기반 페이즈 (간단한 구현)
        total_points = game_state.get('boss_score', 0) + game_state.get('player_score', 0)
        
        if total_points > 15 and self.current_phase < 3:
            self.current_phase = 3
            self.enter_new_phase(3)
        elif total_points > 10 and self.current_phase < 2:
            self.current_phase = 2
            self.enter_new_phase(2)
            
    def enter_new_phase(self, phase: int):
        """새로운 페이즈 진입
        
        Args:
            phase: 페이즈 번호
        """
        # 페이즈별 능력 강화
        if phase == 2:
            self.reaction_time *= 0.8
            self.prediction_accuracy = min(1.0, self.prediction_accuracy + 0.1)
            self.movement_speed *= 1.2
        elif phase == 3:
            self.reaction_time *= 0.7
            self.prediction_accuracy = min(1.0, self.prediction_accuracy + 0.15)
            self.movement_speed *= 1.3
            self.special_frequency *= 1.5
            
        # 페이즈 변경 이벤트
        emit_event(EventType.BOSS_PHASE_CHANGED, {
            'phase': phase,
            'boss_name': self.boss_name
        })
        
    def apply_difficulty(self, difficulty_profile):
        """난이도 프로필 적용
        
        Args:
            difficulty_profile: 난이도 프로필
        """
        if hasattr(difficulty_profile, 'reaction_time'):
            self.reaction_time = difficulty_profile.reaction_time
        if hasattr(difficulty_profile, 'prediction_accuracy'):
            self.prediction_accuracy = difficulty_profile.prediction_accuracy
        if hasattr(difficulty_profile, 'movement_speed'):
            self.movement_speed = difficulty_profile.movement_speed
        if hasattr(difficulty_profile, 'mistake_rate'):
            self.mistake_rate = difficulty_profile.mistake_rate
        if hasattr(difficulty_profile, 'special_frequency'):
            self.special_frequency = difficulty_profile.special_frequency
        if hasattr(difficulty_profile, 'aggression'):
            self.aggression = difficulty_profile.aggression
            
    def reset(self):
        """AI 리셋"""
        super().reset()
        
        self.current_strategy = 'balanced'
        self.strategy_timer = 0
        self.special_cooldown = 0
        self.special_charge = 0
        self.current_phase = 1
        self.adaptation_level = 0
        self.player_analysis.clear()
        
        # 스테이지 특성 재설정
        self.setup_stage_characteristics()


class StageSpecificBossAI:
    """스테이지별 특화 보스 AI 팩토리"""
    
    @staticmethod
    def create_boss(stage: int, use_ml: bool = True) -> BossAI:
        """스테이지에 맞는 보스 AI 생성
        
        Args:
            stage: 스테이지 번호
            use_ml: ML AI 사용 여부
            
        Returns:
            보스 AI 인스턴스
        """
        # ML AI 사용 가능하고 활성화된 경우
        if use_ml and ML_AI_AVAILABLE:
            if stage == 6:
                # 스테이지 6은 고급 ML 보스
                return AdvancedMLBoss()
            elif stage >= 4:
                # 스테이지 4 이상은 ML 보스
                return MLBossAI(stage)
        
        # 특수 보스 클래스가 있으면 여기서 생성
        special_bosses = {
            # 추가 특수 보스 구현 가능
        }
        
        if stage in special_bosses:
            return special_bosses[stage](stage)
            
        return BossAI(stage)