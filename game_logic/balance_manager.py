"""
Balance Manager - 게임 밸런싱 매니저
실시간 밸런스 조정 및 난이도 관리
"""

import math
from typing import Dict, Any, Optional
from config.balance_config import StageBalance, ItemBalance, GameBalance
from ai.ai_difficulty import DynamicDifficulty, DifficultyProfile
from core.events import EventType, emit_event, subscribe
from core.global_manager import GlobalManager


class BalanceManager:
    """게임 밸런싱 관리자"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        self.difficulty_system = DynamicDifficulty()
        
        # 현재 스테이지 설정
        self.current_stage = 1
        self.stage_config = StageBalance.get_stage_balance(1)
        
        # 게임 상태 추적
        self.game_stats = {
            'total_rallies': 0,
            'average_rally_length': 0,
            'player_wins': 0,
            'ai_wins': 0,
            'current_streak': 0,
            'longest_rally': 0,
            'items_collected': 0,
            'specials_used': 0
        }
        
        # 밸런싱 상태
        self.balance_state = {
            'ball_speed_modifier': 1.0,
            'paddle_size_modifier': 1.0,
            'item_spawn_modifier': 1.0,
            'ai_difficulty_modifier': 1.0,
            'score_momentum': 0.0  # -1.0 ~ 1.0 (음수는 AI 우세, 양수는 플레이어 우세)
        }
        
        # 실시간 조정 설정
        self.auto_balance = True
        self.balance_update_timer = 0
        self.balance_update_interval = 2.0  # 2초마다 업데이트
        
        # 이벤트 핸들러 등록
        self.setup_event_handlers()
        
    def setup_event_handlers(self):
        """이벤트 핸들러 설정"""
        subscribe(EventType.ROUND_WIN, self.on_round_result)
        subscribe(EventType.ROUND_LOSE, self.on_round_result)
        subscribe(EventType.BALL_HIT_PLAYER, self.on_rally_hit)
        subscribe(EventType.BALL_HIT_BOSS, self.on_rally_hit)
        subscribe(EventType.ITEM_COLLECTED, self.on_item_collected)
        subscribe(EventType.SPECIAL_ACTIVATED, self.on_special_used)
        
    def set_stage(self, stage: int):
        """스테이지 설정
        
        Args:
            stage: 스테이지 번호
        """
        self.current_stage = stage
        self.stage_config = StageBalance.get_stage_balance(stage)
        
        # 스테이지별 난이도 적용
        stage_difficulty = self.stage_config['difficulty_multiplier']
        self.apply_stage_difficulty(stage_difficulty)
        
        # 스테이지 시작 이벤트
        emit_event(EventType.GAME_START, {
            'stage': stage,
            'stage_name': self.stage_config['name'],
            'difficulty': stage_difficulty
        })
        
    def apply_stage_difficulty(self, difficulty: float):
        """스테이지 난이도 적용
        
        Args:
            difficulty: 난이도 배율
        """
        # AI 난이도 조정
        self.balance_state['ai_difficulty_modifier'] = difficulty
        
        # 공 속도 조정
        ball_config = self.stage_config['ball_speed']
        self.global_manager.set('BALL_SPEED_INITIAL', ball_config['initial'])
        self.global_manager.set('BALL_SPEED_MAX', ball_config['max'])
        self.global_manager.set('BALL_ACCELERATION', ball_config['acceleration'])
        
        # 패들 크기 조정
        paddle_config = self.stage_config['paddle_size']
        self.global_manager.set('PLAYER_WIDTH', paddle_config['player'])
        self.global_manager.set('BOSS_WIDTH', paddle_config['boss'])
        
    def update(self, dt: float, game_state: Dict[str, Any]):
        """밸런싱 업데이트
        
        Args:
            dt: 델타 타임
            game_state: 게임 상태
        """
        self.balance_update_timer += dt
        
        # 정기적인 밸런스 업데이트
        if self.balance_update_timer >= self.balance_update_interval:
            self.balance_update_timer = 0
            
            if self.auto_balance:
                self.update_balance(game_state)
                
        # 난이도 시스템 업데이트
        self.difficulty_system.update(dt, game_state)
        
        # 모멘텀 업데이트
        self.update_momentum(game_state)
        
    def update_balance(self, game_state: Dict[str, Any]):
        """밸런스 업데이트
        
        Args:
            game_state: 게임 상태
        """
        # 점수 차이 분석
        player_score = game_state.get('player_score', 0)
        ai_score = game_state.get('ai_score', 0) 
        score_diff = player_score - ai_score
        
        # 모멘텀 계산
        if abs(score_diff) > 0:
            self.balance_state['score_momentum'] = max(-1.0, min(1.0, score_diff / 5.0))
        
        # 플레이어가 너무 우세한 경우
        if self.balance_state['score_momentum'] > 0.5:
            # AI 강화
            self.balance_state['ai_difficulty_modifier'] = min(1.3, 
                self.balance_state['ai_difficulty_modifier'] + 0.05)
            # 공 속도 증가
            self.balance_state['ball_speed_modifier'] = min(1.2,
                self.balance_state['ball_speed_modifier'] + 0.02)
            # 아이템 스폰 감소
            self.balance_state['item_spawn_modifier'] = max(0.5,
                self.balance_state['item_spawn_modifier'] - 0.05)
                
        # AI가 너무 우세한 경우
        elif self.balance_state['score_momentum'] < -0.5:
            # AI 약화
            self.balance_state['ai_difficulty_modifier'] = max(0.7,
                self.balance_state['ai_difficulty_modifier'] - 0.05)
            # 공 속도 감소
            self.balance_state['ball_speed_modifier'] = max(0.8,
                self.balance_state['ball_speed_modifier'] - 0.02)
            # 아이템 스폰 증가
            self.balance_state['item_spawn_modifier'] = min(1.5,
                self.balance_state['item_spawn_modifier'] + 0.05)
                
        # 밸런스 상태 적용
        self.apply_balance_modifiers()
        
    def apply_balance_modifiers(self):
        """밸런스 수정자 적용"""
        # AI 난이도 적용
        current_difficulty = self.difficulty_system.get_current_difficulty()
        modified_difficulty = self.modify_difficulty(
            current_difficulty,
            self.balance_state['ai_difficulty_modifier']
        )
        
        # 공 속도 적용
        base_speed = self.stage_config['ball_speed']['initial']
        modified_speed = base_speed * self.balance_state['ball_speed_modifier']
        self.global_manager.set('BALL_SPEED_CURRENT', modified_speed)
        
        # 아이템 스폰율 적용
        base_spawn = self.stage_config['item_spawn']['frequency']
        modified_spawn = base_spawn * self.balance_state['item_spawn_modifier']
        self.global_manager.set('ITEM_SPAWN_RATE', modified_spawn)
        
    def modify_difficulty(self, difficulty: DifficultyProfile, modifier: float) -> DifficultyProfile:
        """난이도 프로필 수정
        
        Args:
            difficulty: 기본 난이도 프로필
            modifier: 수정자
            
        Returns:
            수정된 난이도 프로필
        """
        # 난이도 속성 수정
        difficulty.reaction_time = max(0.05, difficulty.reaction_time / modifier)
        difficulty.prediction_accuracy = min(0.95, difficulty.prediction_accuracy * modifier)
        difficulty.movement_speed = difficulty.movement_speed * modifier
        difficulty.mistake_rate = max(0.01, difficulty.mistake_rate / modifier)
        difficulty.special_frequency = min(0.5, difficulty.special_frequency * modifier)
        difficulty.aggression = min(1.0, difficulty.aggression * modifier)
        
        return difficulty
        
    def update_momentum(self, game_state: Dict[str, Any]):
        """게임 모멘텀 업데이트
        
        Args:
            game_state: 게임 상태
        """
        # 랠리 길이에 따른 모멘텀
        rally_count = game_state.get('rally_count', 0)
        if rally_count > self.game_stats['longest_rally']:
            self.game_stats['longest_rally'] = rally_count
            
        # 긴 랠리는 긴장감 증가
        if rally_count > 10:
            # 공 속도 점진적 증가
            speed_boost = 1.0 + (rally_count - 10) * 0.01
            self.balance_state['ball_speed_modifier'] = min(1.5, speed_boost)
            
    def on_round_result(self, event):
        """라운드 결과 처리"""
        winner = event.data.get('winner')
        
        if winner == 'player':
            self.game_stats['player_wins'] += 1
            self.game_stats['current_streak'] = max(1, self.game_stats['current_streak'] + 1)
        else:
            self.game_stats['ai_wins'] += 1
            self.game_stats['current_streak'] = min(-1, self.game_stats['current_streak'] - 1)
            
        # 연승/연패에 따른 조정
        if abs(self.game_stats['current_streak']) >= 3:
            self.trigger_comeback_mechanism()
            
    def trigger_comeback_mechanism(self):
        """컴백 메커니즘 발동"""
        streak = self.game_stats['current_streak']
        
        if streak >= 3:  # 플레이어 연승
            # AI 강화
            self.balance_state['ai_difficulty_modifier'] += 0.1
            emit_event(EventType.DIFFICULTY_CHANGED, {
                'reason': 'player_streak',
                'modifier': self.balance_state['ai_difficulty_modifier']
            })
            
        elif streak <= -3:  # AI 연승
            # 플레이어 지원
            self.balance_state['item_spawn_modifier'] += 0.2
            self.balance_state['paddle_size_modifier'] = 1.1  # 패들 크기 10% 증가
            
            emit_event(EventType.DIFFICULTY_CHANGED, {
                'reason': 'ai_streak',
                'modifier': self.balance_state['ai_difficulty_modifier']
            })
            
        # 연승 리셋
        self.game_stats['current_streak'] = 0
        
    def on_rally_hit(self, event):
        """랠리 히트 처리"""
        self.game_stats['total_rallies'] += 1
        
    def on_item_collected(self, event):
        """아이템 수집 처리"""
        self.game_stats['items_collected'] += 1
        
    def on_special_used(self, event):
        """특수 능력 사용 처리"""
        self.game_stats['specials_used'] += 1
        
    def get_stage_progress(self) -> float:
        """스테이지 진행도 반환
        
        Returns:
            진행도 (0.0 ~ 1.0)
        """
        total_rounds = self.stage_config['scoring']['rounds_to_win']
        rounds_played = self.game_stats['player_wins'] + self.game_stats['ai_wins']
        
        return min(1.0, rounds_played / (total_rounds * 2))
        
    def get_dynamic_difficulty(self) -> float:
        """동적 난이도 반환
        
        Returns:
            현재 난이도 레벨
        """
        # 스테이지 난이도
        stage_difficulty = self.stage_config['difficulty_multiplier']
        
        # 진행도에 따른 난이도
        progress = self.get_stage_progress()
        progress_difficulty = StageBalance.get_difficulty_curve(self.current_stage, progress)
        
        # AI 난이도 수정자
        ai_modifier = self.balance_state['ai_difficulty_modifier']
        
        # 최종 난이도
        return stage_difficulty * progress_difficulty * ai_modifier
        
    def calculate_rewards(self, won: bool, perfect: bool = False) -> Dict[str, int]:
        """보상 계산
        
        Args:
            won: 승리 여부
            perfect: 퍼펙트 승리 여부
            
        Returns:
            보상 딕셔너리
        """
        rewards = {
            'medals': 0,
            'exp': 0,
            'bonus': []
        }
        
        if won:
            reward_config = self.stage_config['rewards']
            rewards['medals'] = reward_config['medal_per_win']
            rewards['exp'] = reward_config['exp_per_win']
            
            if perfect:
                rewards['medals'] += reward_config['bonus_perfect']
                rewards['bonus'].append('perfect_victory')
                
            # 연승 보너스
            if self.game_stats['current_streak'] >= 3:
                bonus = int(rewards['medals'] * 0.5)
                rewards['medals'] += bonus
                rewards['bonus'].append(f'streak_x{self.game_stats["current_streak"]}')
                
            # 긴 랠리 보너스
            if self.game_stats['longest_rally'] > 20:
                bonus = int(rewards['exp'] * 0.3)
                rewards['exp'] += bonus
                rewards['bonus'].append('long_rally')
                
        return rewards
        
    def get_balance_stats(self) -> Dict[str, Any]:
        """밸런스 통계 반환"""
        return {
            'stage': self.current_stage,
            'difficulty': self.get_dynamic_difficulty(),
            'game_stats': self.game_stats.copy(),
            'balance_state': self.balance_state.copy(),
            'momentum': self.balance_state['score_momentum'],
            'progress': self.get_stage_progress()
        }
        
    def reset(self):
        """밸런스 매니저 리셋"""
        self.game_stats = {
            'total_rallies': 0,
            'average_rally_length': 0,
            'player_wins': 0,
            'ai_wins': 0,
            'current_streak': 0,
            'longest_rally': 0,
            'items_collected': 0,
            'specials_used': 0
        }
        
        self.balance_state = {
            'ball_speed_modifier': 1.0,
            'paddle_size_modifier': 1.0,
            'item_spawn_modifier': 1.0,
            'ai_difficulty_modifier': 1.0,
            'score_momentum': 0.0
        }
        
        self.difficulty_system.reset()


# 싱글톤 인스턴스
_balance_manager = None

def get_balance_manager() -> BalanceManager:
    """밸런스 매니저 싱글톤 반환"""
    global _balance_manager
    if _balance_manager is None:
        _balance_manager = BalanceManager()
    return _balance_manager