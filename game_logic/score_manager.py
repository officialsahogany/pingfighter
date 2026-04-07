"""
ScoreManager - 점수 관리
점수 계산, 듀스 모드 관리
"""

from typing import Tuple, Optional
from core.events import EventType, emit_event
from core.game_state import GameState


class ScoreManager:
    """점수 관리자"""
    
    def __init__(self):
        self.game_state = GameState.get_instance()
        
    def add_player_score(self, points: int = 1):
        """플레이어 점수 추가
        
        Args:
            points: 추가할 점수
        """
        if self.game_state.deuce_mode:
            self.game_state.deuce_wins += points
            emit_event(EventType.PLAYER_SCORE, {
                'points': points,
                'deuce_mode': True,
                'total': self.game_state.deuce_wins
            })
        else:
            self.game_state.round_wins += points  
            emit_event(EventType.PLAYER_SCORE, {
                'points': points,
                'deuce_mode': False,
                'total': self.game_state.round_wins
            })
            
    def add_boss_score(self, points: int = 1):
        """보스 점수 추가
        
        Args:
            points: 추가할 점수
        """
        if self.game_state.deuce_mode:
            self.game_state.deuce_losses += points
            emit_event(EventType.AI_SCORE, {
                'points': points,
                'deuce_mode': True,
                'total': self.game_state.deuce_losses
            })
        else:
            self.game_state.round_losses += points
            emit_event(EventType.AI_SCORE, {
                'points': points,
                'deuce_mode': False,
                'total': self.game_state.round_losses
            })
            
    def check_round_winner(self) -> Optional[str]:
        """라운드 승자 확인
        
        Returns:
            'player', 'boss', 또는 None
        """
        if self.game_state.deuce_mode:
            # 듀스 모드에서의 승리 조건
            if self.game_state.deuce_wins >= self.game_state.deuce_goal:
                return 'player'
            elif self.game_state.deuce_losses >= self.game_state.deuce_goal:
                return 'boss'
        else:
            # 일반 모드에서의 승리 조건
            win_goal = 3  # 기본 승리 목표
            if self.game_state.round_wins >= win_goal:
                return 'player'
            elif self.game_state.round_losses >= win_goal:
                return 'boss'
                
        return None
        
    def check_deuce_condition(self) -> bool:
        """듀스 조건 확인
        
        Returns:
            듀스 모드로 전환해야 하는지 여부
        """
        if self.game_state.deuce_mode:
            return False  # 이미 듀스 모드
            
        # 2-2 상황에서 듀스 모드로 전환
        if self.game_state.round_wins == 2 and self.game_state.round_losses == 2:
            return True
            
        return False
        
    def enter_deuce_mode(self):
        """듀스 모드 진입"""
        self.game_state.deuce_mode = True
        self.game_state.deuce_wins = 0
        self.game_state.deuce_losses = 0
        self.game_state.deuce_goal = 2  # 듀스에서는 2점 차이로 승리
        
        emit_event(EventType.ROUND_END, {
            'type': 'deuce_start',
            'player_score': self.game_state.round_wins,
            'boss_score': self.game_state.round_losses
        })
        
