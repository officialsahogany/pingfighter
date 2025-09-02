"""
Scoring System - 점수 및 메달 시스템
점수 계산, 메달 획득, 듀스 모드 관리
"""

import json
from typing import Dict, Optional, Tuple
from core.game_state import GameState
from core.global_manager import GlobalManager
from core.events import EventType, emit_event


class ScoringSystem:
    """점수 관리 시스템"""
    
    def __init__(self):
        self.game_state = GameState.get_instance()
        self.global_manager = GlobalManager.get_instance()
        
        # 점수 상태
        self.player_score = 0
        self.boss_score = 0
        self.round_wins = 0
        self.round_losses = 0
        
        # 듀스 모드
        self.deuce_mode = False
        self.deuce_wins = 0
        self.deuce_losses = 0
        self.deuce_goal = 2
        
        # 메달 시스템
        self.medal_score = 0
        self.session_medal_earned = 0
        self.medal_data = self.load_medal_data()
        
        # 스테이지별 설정
        self.stage_config = {
            1: {'win_score': 11, 'medal_per_win': 10},
            2: {'win_score': 11, 'medal_per_win': 15},
            3: {'win_score': 11, 'medal_per_win': 20},
            4: {'win_score': 11, 'medal_per_win': 25},
            5: {'win_score': 11, 'medal_per_win': 30},
            6: {'win_score': 11, 'medal_per_win': 40}
        }
        
        self.current_stage = 1
        
    def load_medal_data(self) -> Dict:
        """메달 데이터 로드"""
        try:
            with open('medal_data.json', 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            return {
                'total_medals': 0,
                'highest_streak': 0,
                'stages_cleared': []
            }
            
    def save_medal_data(self):
        """메달 데이터 저장"""
        with open('medal_data.json', 'w') as f:
            json.dump(self.medal_data, f, indent=2)
            
    def add_player_score(self) -> bool:
        """플레이어 득점
        
        Returns:
            라운드 승리 여부
        """
        self.player_score += 1
        
        # 듀스 모드 체크
        if self.deuce_mode:
            self.deuce_wins += 1
            
            # 듀스 승리 체크
            if self.deuce_wins >= self.deuce_goal:
                return self.win_round()
        else:
            # 일반 승리 체크
            config = self.stage_config[self.current_stage]
            
            # 10-10 상황에서 듀스 모드 진입
            if self.player_score == config['win_score'] - 1 and \
               self.boss_score == config['win_score'] - 1:
                self.enter_deuce_mode()
                
            # 일반 승리
            elif self.player_score >= config['win_score']:
                return self.win_round()
                
        # 이벤트 발생
        emit_event(EventType.PLAYER_SCORE, {
            'score': self.player_score,
            'deuce_mode': self.deuce_mode
        })
        
        # GlobalManager 동기화
        self.global_manager.set('player_score', self.player_score)
        
        return False
        
    def add_boss_score(self) -> bool:
        """보스 득점
        
        Returns:
            라운드 패배 여부
        """
        self.boss_score += 1
        
        # 듀스 모드 체크
        if self.deuce_mode:
            self.deuce_losses += 1
            
            # 듀스 패배 체크
            if self.deuce_losses >= self.deuce_goal:
                return self.lose_round()
        else:
            # 일반 패배 체크
            config = self.stage_config[self.current_stage]
            
            # 10-10 상황에서 듀스 모드 진입
            if self.player_score == config['win_score'] - 1 and \
               self.boss_score == config['win_score'] - 1:
                self.enter_deuce_mode()
                
            # 일반 패배
            elif self.boss_score >= config['win_score']:
                return self.lose_round()
                
        # 이벤트 발생
        emit_event(EventType.AI_SCORE, {
            'score': self.boss_score,
            'deuce_mode': self.deuce_mode
        })
        
        # GlobalManager 동기화
        self.global_manager.set('boss_score', self.boss_score)
        
        return False
        
    def enter_deuce_mode(self):
        """듀스 모드 진입"""
        self.deuce_mode = True
        self.deuce_wins = 0
        self.deuce_losses = 0
        
        # 이벤트 발생
        emit_event(EventType.DEUCE_MODE, {
            'player_score': self.player_score,
            'boss_score': self.boss_score
        })
        
    def win_round(self) -> bool:
        """라운드 승리 처리
        
        Returns:
            True (라운드 종료)
        """
        self.round_wins += 1
        
        # 메달 획득
        config = self.stage_config[self.current_stage]
        medals_earned = config['medal_per_win']
        
        # 보너스 메달 (무실점 승리 등)
        if self.boss_score == 0:
            medals_earned *= 2  # 퍼펙트 승리
        elif self.deuce_mode:
            medals_earned = int(medals_earned * 1.5)  # 듀스 승리
            
        self.add_medals(medals_earned)
        
        # 이벤트 발생
        emit_event(EventType.ROUND_WIN, {
            'stage': self.current_stage,
            'player_score': self.player_score,
            'boss_score': self.boss_score,
            'medals_earned': medals_earned
        })
        
        return True
        
    def lose_round(self) -> bool:
        """라운드 패배 처리
        
        Returns:
            True (라운드 종료)
        """
        self.round_losses += 1
        
        # 이벤트 발생
        emit_event(EventType.ROUND_LOSE, {
            'stage': self.current_stage,
            'player_score': self.player_score,
            'boss_score': self.boss_score
        })
        
        return True
        
    def add_medals(self, amount: int):
        """메달 추가
        
        Args:
            amount: 추가할 메달 수
        """
        self.medal_score += amount
        self.session_medal_earned += amount
        self.medal_data['total_medals'] += amount
        
        # 이벤트 발생
        emit_event(EventType.MEDAL_EARNED, {
            'amount': amount,
            'total': self.medal_score
        })
        
        # GlobalManager 동기화
        self.global_manager.set('medal_score', self.medal_score)
        
    def get_score_text(self) -> str:
        """점수 텍스트 반환"""
        if self.deuce_mode:
            return f"DEUCE {self.deuce_wins}-{self.deuce_losses}"
        else:
            return f"{self.boss_score} - {self.player_score}"
            
    def get_round_status(self) -> str:
        """라운드 상태 텍스트 반환"""
        return f"Round {self.round_wins + self.round_losses + 1}"
        
    def set_stage_config(self, stage: int):
        """스테이지 설정
        
        Args:
            stage: 스테이지 번호
        """
        self.current_stage = stage
        
    def reset(self):
        """점수 시스템 리셋"""
        self.player_score = 0
        self.boss_score = 0
        self.deuce_mode = False
        self.deuce_wins = 0
        self.deuce_losses = 0
        
        # GlobalManager 동기화
        self.global_manager.set('player_score', 0)
        self.global_manager.set('boss_score', 0)
        
    def reset_stage(self):
        """스테이지 리셋"""
        self.reset()
        self.round_wins = 0
        self.round_losses = 0
        
    def save_progress(self):
        """진행상황 저장"""
        self.save_medal_data()
        
    def get_stats(self) -> Dict:
        """통계 반환"""
        return {
            'player_score': self.player_score,
            'boss_score': self.boss_score,
            'round_wins': self.round_wins,
            'round_losses': self.round_losses,
            'medal_score': self.medal_score,
            'session_medals': self.session_medal_earned,
            'deuce_mode': self.deuce_mode
        }


# 싱글톤 인스턴스
_scoring_system = None

def get_scoring_system() -> ScoringSystem:
    """스코어링 시스템 싱글톤 반환"""
    global _scoring_system
    if _scoring_system is None:
        _scoring_system = ScoringSystem()
    return _scoring_system