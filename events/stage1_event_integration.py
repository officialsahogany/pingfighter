"""
🎮 Stage 1 Event Integration Module
스테이지 1의 특별 이벤트를 메인 게임과 연동
"""

import pygame
from events.balloon_machine_event import BalloonMachineEvent

class Stage1EventManager:
    """스테이지 1 이벤트 관리자"""
    
    def __init__(self):
        # 풍선 기계 이벤트
        self.balloon_machine = BalloonMachineEvent()
        
        # 이벤트 활성 상태
        self.event_active = False
        self.event_type = None
        
        # 게임 일시정지 상태
        self.pause_game = False
        
        # 대기 중인 이벤트 정보
        self.pending_event = None  # {'score': int, 'deuce_mode': bool, 'deuce_wins': int}
        self.pending_event_delay = 0  # 대기 이벤트 시작 지연
        
    def check_timer_events(self, current_stage: int) -> bool:
        """
        타이머 기반 이벤트 발동 체크
        Returns: True if an event should trigger
        """
        if current_stage == 1:
            # 타이머 업데이트 및 발동 체크
            if self.balloon_machine.update_timer():
                return True
        return False
    
    def check_events(self, player_score: int, boss_score: int, current_stage: int, round_count: int) -> bool:
        """
        이벤트 발동 조건 체크 (이제는 사용하지 않음 - 타이머 기반으로 변경)
        Returns: True if an event should trigger
        """
        # 타이머 기반으로 변경되어 이 메서드는 더 이상 사용하지 않음
        return False
    
    def check_events_deuce(self, player_score: int, boss_score: int, current_stage: int, round_count: int, 
                           deuce_mode: bool = False, deuce_wins: int = 0) -> bool:
        """
        듀스 모드를 고려한 이벤트 발동 조건 체크 (이제는 사용하지 않음 - 타이머 기반으로 변경)
        Returns: True if an event should trigger
        """
        # 타이머 기반으로 변경되어 이 메서드는 더 이상 사용하지 않음
        return False
    
    def trigger_event_timer(self, screen: pygame.Surface = None, current_stage: int = 1,
                           sound_balloon=None, sound_door=None, sound_machine=None):
        """타이머 기반 이벤트 발동"""
        if self.event_active:
            return False
        
        # 풍선 기계 활성화
        if self.balloon_machine.activate(screen, sound_balloon, sound_door, sound_machine, 0):
            self.event_active = True
            self.event_type = "balloon_machine"
            self.pause_game = False
            print(f"[Stage1EventManager] 타이머 기반 풍선 기계 이벤트 발동!")
            return True
        return False
    
    def trigger_event(self, screen: pygame.Surface, player_score: int, current_stage: int, 
                      sound_balloon=None, sound_door=None, sound_machine=None, deuce_mode: bool = False, deuce_wins: int = 0):
        """이벤트 발동 (더 이상 사용하지 않음)"""
        # player_score는 이미 올바른 값 (듀스 모드에서는 deuce_wins, 일반 모드에서는 round_wins)
        effective_score = player_score
        
        # 현재 이벤트가 활성 중이면 대기 큐에 저장
        if self.event_active:
            print(f" [trigger_event]    -")
            print(f" [trigger_event] score: {effective_score}, deuce_mode: {deuce_mode}, deuce_wins: {deuce_wins}")
            print(f" [trigger_event] balloon_machine.triggered_at_1: {self.balloon_machine.triggered_at_1}")
            print(f" [trigger_event] balloon_machine.triggered_at_3: {self.balloon_machine.triggered_at_3}")
            # 풍선 기계가 이 점수에서 트리거 가능한지 확인
            if self.balloon_machine.should_trigger(effective_score, current_stage):
                self.pending_event = {
                    'screen': screen,
                    'score': effective_score,
                    'stage': current_stage,
                    'sound_balloon': sound_balloon,
                    'sound_door': sound_door,
                    'sound_machine': sound_machine
                }
                print(f" [trigger_event]    : {effective_score}")
            else:
                print(f" [trigger_event] should_trigger False  -")
            return False
        
        # 이벤트가 활성 중이 아니면 즉시 시작
        if self.balloon_machine.should_trigger(effective_score, current_stage):
            if self.balloon_machine.activate(screen, sound_balloon, sound_door, sound_machine, effective_score):
                self.event_active = True
                self.event_type = "balloon_machine"
                self.pause_game = False  # 게임 진행 계속 (일시정지 없음)
                print(f" [trigger_event]   : {effective_score}")
                return True
        
        return False
    
    def update(self, screen: pygame.Surface = None, sound_balloon=None, sound_door=None, sound_machine=None) -> bool:
        """
        활성 이벤트 업데이트 및 타이머 체크
        Returns: True if event is still active
        """
        # 타이머 업데이트 (이벤트가 활성화되지 않았을 때만)
        if not self.event_active:
            # 타이머가 0이 되면 이벤트 발동
            if self.balloon_machine.update_timer():
                # 자동으로 이벤트 트리거
                return self.trigger_event_timer(screen, 1, sound_balloon, sound_door, sound_machine)
        
        # 이벤트가 활성화되어 있을 때
        if self.event_active:
            # 풍선 기계 이벤트 업데이트
            if self.event_type == "balloon_machine":
                still_active = self.balloon_machine.update()
                
                if not still_active:
                    self.event_active = False
                    self.event_type = None
                    self.pause_game = False
                    
                    # 대기 중인 이벤트가 있으면 지연 타이머 시작
                    if self.pending_event:
                        self.pending_event_delay = 5  # 5프레임 지연 (약 0.08초)
                        print(f" [update]     (5 )")
                    
                    return False
            return True
        else:
            # 대기 중인 이벤트 처리
            if self.pending_event_delay > 0:
                self.pending_event_delay -= 1
                if self.pending_event_delay == 0 and self.pending_event:
                    print(f" [update]    : {self.pending_event['score']}")
                    print(f" [update] balloon_machine.active: {self.balloon_machine.active}")
                    print(f" [update] balloon_machine.triggered_at_1: {self.balloon_machine.triggered_at_1}")
                    print(f" [update] balloon_machine.triggered_at_3: {self.balloon_machine.triggered_at_3}")
                    pending = self.pending_event
                    self.pending_event = None  # 대기 큐 비우기
                    
                    # 대기 중이던 이벤트 시작
                    if self.balloon_machine.activate(
                        pending['screen'],
                        pending['sound_balloon'],
                        pending['sound_door'],
                        pending['sound_machine'],
                        pending['score']
                    ):
                        self.event_active = True
                        self.event_type = "balloon_machine"
                        self.pause_game = False
                        print(f" [update]     !")
                        return True
                    else:
                        print(f" [update]     !")
            
            # 이벤트가 끝났어도 풍선은 계속 업데이트
            if self.balloon_machine.balloons:
                self.balloon_machine._update_balloons()
            return False
    
    def draw_background(self, screen: pygame.Surface):
        """배경 요소 그리기 (공 아래에 그려질 요소들)"""
        if self.event_active:
            if self.event_type == "balloon_machine":
                self.balloon_machine.draw_background(screen)
    
    def draw(self, screen: pygame.Surface):
        """활성 이벤트 그리기 (공 위에 그려질 요소들)"""
        if self.event_active:
            if self.event_type == "balloon_machine":
                self.balloon_machine.draw(screen)
        else:
            # 이벤트가 끝났어도 풍선은 계속 그리기
            if self.balloon_machine.balloons:
                self.balloon_machine._draw_balloons(screen)
    
    def should_pause_game(self) -> bool:
        """게임을 일시정지해야 하는지 확인"""
        return self.pause_game
    
    def get_active_balloons(self):
        """활성화된 풍선 리스트 반환 (충돌 감지용)"""
        return self.balloon_machine.get_balloons()
    
    def check_balloon_collisions(self, ball_rect, ball_radius, ball_vel, effects_manager=None, sound_balloon=None, whip_active=False, trade_point_system=None):
        """
        풍선과 공의 충돌 체크 (풍선파티 스킬과 동일한 로직)
        이벤트가 끝나도 남은 풍선과 충돌 체크
        """
        return self.balloon_machine.check_balloon_collisions(
            ball_rect, ball_radius, ball_vel, effects_manager, sound_balloon, whip_active, trade_point_system
        )

    def pop_balloon_with_projectile(self, x: float, y: float, radius: float = 0.0,
                                     effects_manager=None, sound_balloon=None, trade_point_system=None) -> bool:
        """
        외부 투사체(예: 코만도 권총 탄환)가 풍선을 맞췄는지 확인하고 처리한다.
        """
        return self.balloon_machine.pop_balloon_at_point(
            x, y, radius, effects_manager, sound_balloon, trade_point_system
        )
    
    def reset(self):
        """모든 이벤트 리셋 (새 게임 시작 시)"""
        self.balloon_machine.reset()
        self.event_active = False
        self.event_type = None
        self.pause_game = False
        self.pending_event = None  # 대기 큐도 리셋
    
    def reset_for_deuce(self):
        """듀스 재시작 시 이벤트 부분 리셋"""
        self.balloon_machine.reset_for_deuce()
        print("Stage 1  -")
    
    def is_event_active(self) -> bool:
        """이벤트가 활성화되어 있는지 확인"""
        return self.event_active
    
    def get_event_info(self) -> dict:
        """현재 이벤트 정보 반환"""
        if self.event_active:
            return {
                "type": self.event_type,
                "pause_game": self.pause_game,
                "phase": self.balloon_machine.phase if self.event_type == "balloon_machine" else None
            }
        return {"type": None, "pause_game": False, "phase": None}
