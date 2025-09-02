"""
Round Manager - 라운드 및 스테이지 관리
라운드 진행, 스테이지 전환, 승리 조건 관리
"""

from typing import Dict, Optional
from core.game_state import GameState
from core.global_manager import GlobalManager
from core.events import EventType, emit_event
from game_logic.scoring import get_scoring_system


class RoundManager:
    """라운드 관리 시스템"""
    
    def __init__(self):
        self.game_state = GameState.get_instance()
        self.global_manager = GlobalManager.get_instance()
        self.scoring_system = get_scoring_system()
        
        # 라운드 상태
        self.current_round = 1
        self.rounds_to_win = 3  # Best of 5
        self.round_active = False
        
        # 스테이지 설정
        self.stage_configs = {
            1: {
                'name': 'Training',
                'rounds_to_win': 1,
                'boss_name': 'Training Dummy',
                'background': 'bg_stage1.png'
            },
            2: {
                'name': 'Speed Demon',
                'rounds_to_win': 2,
                'boss_name': 'Speed Demon',
                'background': 'bg_stage2.png'
            },
            3: {
                'name': 'Menhera Girl',
                'rounds_to_win': 2,
                'boss_name': 'Menhera Girl',
                'background': 'bg_stage3.png'
            },
            4: {
                'name': 'Zen Master',
                'rounds_to_win': 3,
                'boss_name': 'Zen Master',
                'background': 'bg_stage4.png'
            },
            5: {
                'name': 'Crimson Flame',
                'rounds_to_win': 3,
                'boss_name': 'Crimson Flame',
                'background': 'bg_stage5.png'
            },
            6: {
                'name': 'Battlecruiser',
                'rounds_to_win': 3,
                'boss_name': 'Battlecruiser Yamato',
                'background': 'bg_stage6.png'
            }
        }
        
        self.current_stage = 1
        self.stage_complete = False
        
    def set_stage_config(self, stage: int):
        """스테이지 설정
        
        Args:
            stage: 스테이지 번호
        """
        self.current_stage = stage
        config = self.stage_configs.get(stage, self.stage_configs[1])
        self.rounds_to_win = config['rounds_to_win']
        
        # 스코어링 시스템에도 알림
        self.scoring_system.set_stage_config(stage)
        
        # GlobalManager 업데이트
        self.global_manager.set('current_stage', stage)
        self.global_manager.set('boss_name', config['boss_name'])
        
    def start_round(self):
        """라운드 시작"""
        self.round_active = True
        self.scoring_system.reset()
        
        # 이벤트 발생
        emit_event(EventType.ROUND_START, {
            'stage': self.current_stage,
            'round': self.current_round,
            'rounds_to_win': self.rounds_to_win
        })
        
    def end_round(self, player_won: bool):
        """라운드 종료
        
        Args:
            player_won: 플레이어 승리 여부
        """
        self.round_active = False
        
        if player_won:
            # 라운드 승리 처리는 이미 scoring_system에서 했음
            
            # 스테이지 클리어 체크
            if self.scoring_system.round_wins >= self.rounds_to_win:
                self.complete_stage()
        else:
            # 라운드 패배 처리는 이미 scoring_system에서 했음
            
            # 게임 오버 체크
            if self.scoring_system.round_losses >= self.rounds_to_win:
                self.game_over()
                
        # 다음 라운드 준비
        if not self.stage_complete:
            self.current_round += 1
            
    def complete_stage(self):
        """스테이지 완료"""
        self.stage_complete = True
        
        # 메달 보너스
        bonus_medals = self.stage_configs[self.current_stage]['rounds_to_win'] * 20
        self.scoring_system.add_medals(bonus_medals)
        
        # 이벤트 발생
        emit_event(EventType.BOSS_DEFEATED, {
            'stage': self.current_stage,
            'total_rounds': self.current_round,
            'bonus_medals': bonus_medals
        })
        
        # 다음 스테이지로
        if self.current_stage < 6:
            self.next_stage()
        else:
            # 게임 클리어
            self.game_complete()
            
    def next_stage(self):
        """다음 스테이지로 이동"""
        self.current_stage += 1
        self.stage_complete = False
        self.current_round = 1
        
        # 설정 초기화
        self.set_stage_config(self.current_stage)
        self.scoring_system.reset_stage()
        
        # 이벤트 발생
        emit_event(EventType.BOSS_PHASE_CHANGED, {
            'new_stage': self.current_stage
        })
        
    def game_over(self):
        """게임 오버"""
        # 이벤트 발생
        emit_event(EventType.GAME_OVER, {
            'stage': self.current_stage,
            'rounds_won': self.scoring_system.round_wins,
            'rounds_lost': self.scoring_system.round_losses,
            'winner': 'boss'
        })
        
    def game_complete(self):
        """게임 완료 (모든 스테이지 클리어)"""
        # 특별 보너스
        completion_bonus = 1000
        self.scoring_system.add_medals(completion_bonus)
        
        # 이벤트 발생
        emit_event(EventType.GAME_OVER, {
            'stage': 6,
            'game_complete': True,
            'total_medals': self.scoring_system.medal_score,
            'winner': 'player'
        })
        
    def check_score_update(self, scorer: str) -> bool:
        """득점 처리
        
        Args:
            scorer: 득점한 쪽 ('player' or 'boss')
            
        Returns:
            라운드 종료 여부
        """
        if not self.round_active:
            return False
            
        round_ended = False
        
        if scorer == 'player':
            round_ended = self.scoring_system.add_player_score()
        else:
            round_ended = self.scoring_system.add_boss_score()
            
        if round_ended:
            self.end_round(scorer == 'player')
            
        return round_ended
        
    def get_stage_info(self) -> Dict:
        """현재 스테이지 정보 반환"""
        config = self.stage_configs.get(self.current_stage, self.stage_configs[1])
        return {
            'stage': self.current_stage,
            'name': config['name'],
            'boss_name': config['boss_name'],
            'round': self.current_round,
            'rounds_to_win': self.rounds_to_win,
            'player_rounds': self.scoring_system.round_wins,
            'boss_rounds': self.scoring_system.round_losses
        }
        
    def reset(self):
        """라운드 매니저 리셋"""
        self.current_round = 1
        self.round_active = False
        self.stage_complete = False
        
    def reset_game(self):
        """전체 게임 리셋"""
        self.reset()
        self.current_stage = 1
        self.set_stage_config(1)
        self.scoring_system.reset_stage()
        
    def restart_round(self):
        """현재 라운드 재시작"""
        # 점수는 유지하고 라운드만 재시작
        self.round_active = False
        
        # 공 위치 리셋을 위한 이벤트
        emit_event(EventType.ROUND_START, {
            'stage': self.current_stage,
            'round': self.current_round,
            'rounds_to_win': self.rounds_to_win,
            'restart': True
        })
        
        # 라운드 재활성화
        self.round_active = True


# 싱글톤 인스턴스
_round_manager = None

def get_round_manager() -> RoundManager:
    """라운드 매니저 싱글톤 반환"""
    global _round_manager
    if _round_manager is None:
        _round_manager = RoundManager()
    return _round_manager