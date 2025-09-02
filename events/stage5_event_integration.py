"""
🔥 Stage 5 Event Integration Module
스테이지 5의 특별 이벤트를 메인 게임과 연동
10~20초마다 자동으로 화염 기계 이벤트 발동
"""

import pygame
import random
from events.stage5_fire_machine_event import Stage5FireMachineEvent

class Stage5EventManager:
    """스테이지 5 이벤트 관리자"""
    
    def __init__(self):
        # 화염 기계 이벤트
        self.fire_machine = Stage5FireMachineEvent()
        
        # 이벤트 활성 상태
        self.event_active = False
        self.event_type = None
        
        # 게임 일시정지 상태
        self.pause_game = False
        
        # 대기 중인 이벤트 정보
        self.pending_event = None
        self.pending_event_delay = 0
        
        # 타이머 시스템 (10~20초마다 발동)
        self.timer_active = False  # 타이머 활성화 상태
        self.event_timer = 0  # 다음 이벤트까지 남은 프레임 수
        self.MIN_INTERVAL = 10 * 60  # 10초 = 600 프레임 (60 FPS 기준)
        self.MAX_INTERVAL = 20 * 60  # 20초 = 1200 프레임
        self.stage_started = False  # 스테이지 시작 여부
        
    def start_timer(self, current_stage: int):
        """Stage 5에서 타이머 시작"""
        if current_stage == 5 and not self.stage_started:
            self.stage_started = True
            self.timer_active = True
            # 10~20초 사이의 랜덤 간격 설정
            self.event_timer = random.randint(self.MIN_INTERVAL, self.MAX_INTERVAL)
            seconds = self.event_timer / 60
            print(f"🔥🔥🔥 Stage 5 화염 이벤트 타이머 시작! 다음 이벤트까지 {seconds:.1f}초")
            print(f"🔥 타이머 활성화 상태: {self.timer_active}, 타이머 값: {self.event_timer}")
    
    def check_timer_event(self, current_stage: int) -> bool:
        """
        타이머 기반 이벤트 발동 체크
        Returns: True if timer expired and event should trigger
        """
        if not self.timer_active or current_stage != 5:
            return False
        
        # 타이머가 만료되었는지 체크
        if self.event_timer <= 0:
            if self.fire_machine.should_trigger(current_stage):
                print(f"🔥 타이머 만료! 화염 기계 이벤트 발동")
                # 다음 타이머 설정
                self.event_timer = random.randint(self.MIN_INTERVAL, self.MAX_INTERVAL)
                seconds = self.event_timer / 60
                print(f"🔥 다음 이벤트까지 {seconds:.1f}초")
                return True
        
        return False
    
    def check_events(self, player_score: int, boss_score: int, current_stage: int, round_count: int) -> bool:
        """
        이벤트 발동 조건 체크 - 타이머 기반으로 변경
        Returns: True if an event should trigger
        """
        # 타이머 기반 체크
        return self.check_timer_event(current_stage)
    
    def check_events_deuce(self, player_score: int, boss_score: int, current_stage: int, round_count: int, 
                           deuce_mode: bool = False, deuce_wins: int = 0) -> bool:
        """
        듀스 모드를 고려한 이벤트 발동 조건 체크 - 타이머 기반으로 변경
        Returns: True if an event should trigger
        """
        # 타이머 기반 체크 (듀스 모드와 무관하게 동일)
        return self.check_timer_event(current_stage)
    
    def trigger_event(self, screen: pygame.Surface, current_stage: int, 
                      sound_door=None, sound_machine=None, sound_fire=None):
        """이벤트 발동"""
        
        # 현재 이벤트가 활성 중이면 대기 큐에 저장
        if self.event_active:
            print(f"🔥 [trigger_event] 이벤트 활성 중 - 대기 큐에 저장 체크 시작")
            if self.fire_machine.should_trigger(current_stage):
                self.pending_event = {
                    'screen': screen,
                    'stage': current_stage,
                    'sound_door': sound_door,
                    'sound_machine': sound_machine,
                    'sound_fire': sound_fire
                }
                print(f"🔥 [trigger_event] 이벤트 대기 큐에 저장됨")
            return False
        
        # 이벤트가 활성 중이 아니면 즉시 시작
        if self.fire_machine.should_trigger(current_stage):
            if self.fire_machine.activate(screen, sound_door, sound_machine, sound_fire):
                self.event_active = True
                self.event_type = "fire_machine"
                self.pause_game = False  # 게임 진행 계속
                print(f"🔥 [trigger_event] 타이머 기반 이벤트 즉시 시작!")
                return True
        
        return False
    
    def update(self) -> bool:
        """
        활성 이벤트 업데이트 및 타이머 감소
        Returns: True if event is still active
        """
        # 타이머 감소 (이벤트가 활성화되어 있지 않을 때만)
        if self.timer_active and not self.event_active:
            if self.event_timer > 0:
                self.event_timer -= 1
                # 3초마다 또는 마지막 3초에는 남은 시간 표시
                if self.event_timer % 180 == 0 or self.event_timer <= 180:
                    seconds_left = self.event_timer / 60
                    if seconds_left > 0:
                        print(f"🔥 다음 화염 이벤트까지 {seconds_left:.1f}초 남음 (timer: {self.event_timer})")
        
        # 이벤트가 활성화되어 있을 때
        if self.event_active:
            # 화염 기계 이벤트 업데이트
            if self.event_type == "fire_machine":
                still_active = self.fire_machine.update()
                
                if not still_active:
                    self.event_active = False
                    self.event_type = None
                    self.pause_game = False
                    
                    # 대기 중인 이벤트가 있으면 지연 타이머 시작
                    if self.pending_event:
                        self.pending_event_delay = 5  # 5프레임 지연
                        print(f"🔥 [update] 대기 이벤트 지연 시작 (5 프레임)")
                    
                    return False
            return True
        else:
            # 대기 중인 이벤트 처리
            if self.pending_event_delay > 0:
                self.pending_event_delay -= 1
                if self.pending_event_delay == 0 and self.pending_event:
                    print(f"🔥 [update] 대기 중인 이벤트 시작")
                    pending = self.pending_event
                    self.pending_event = None  # 대기 큐 비우기
                    
                    # 대기 중이던 이벤트 시작
                    if self.fire_machine.activate(
                        pending['screen'],
                        pending['sound_door'],
                        pending['sound_machine'],
                        pending['sound_fire']
                    ):
                        self.event_active = True
                        self.event_type = "fire_machine"
                        self.pause_game = False
                        print(f"🔥 [update] 대기 중이던 이벤트 성공적으로 시작됨!")
                        return True
            
            # 이벤트가 끝났어도 화염 스트림, 지대, 연기는 계속 업데이트
            if self.fire_machine.fire_streams or self.fire_machine.fire_zones or hasattr(self.fire_machine, 'smoke_particles') and self.fire_machine.smoke_particles:
                self.fire_machine._update_fire_streams()
                self.fire_machine._update_fire_zones()
                if hasattr(self.fire_machine, '_update_smoke_particles'):
                    self.fire_machine._update_smoke_particles()
            return False
    
    def draw_background(self, screen: pygame.Surface):
        """배경 요소 그리기 (공 아래에 그려질 요소들)"""
        if self.event_active:
            if self.event_type == "fire_machine":
                self.fire_machine.draw_background(screen)
    
    def draw(self, screen: pygame.Surface):
        """활성 이벤트 그리기 (공 위에 그려질 요소들)"""
        if self.event_active:
            if self.event_type == "fire_machine":
                self.fire_machine.draw(screen)
        else:
            # 이벤트가 끝났어도 화염 스트림, 지대, 연기는 계속 그리기
            if self.fire_machine.fire_streams or self.fire_machine.fire_zones or (hasattr(self.fire_machine, 'smoke_particles') and self.fire_machine.smoke_particles):
                self.fire_machine.draw(screen)
    
    def should_pause_game(self) -> bool:
        """게임을 일시정지해야 하는지 확인"""
        return self.pause_game
    
    def get_active_fire_zones(self):
        """활성화된 화염 지대 리스트 반환 (충돌 감지용)"""
        return self.fire_machine.fire_zones if hasattr(self.fire_machine, 'fire_zones') else []
    
    def check_fire_zone_collision(self, paddle_rect, is_rolling=False, in_smoke_grenade=False):
        """
        화염 지대와 패들의 충돌 체크
        Returns: (is_in_fire, push_direction)
        """
        return self.fire_machine.check_fire_zone_collision(paddle_rect, is_rolling, in_smoke_grenade)
    
    def reset(self):
        """모든 이벤트 리셋 (새 게임 시작 시)"""
        self.fire_machine.reset()
        self.event_active = False
        self.event_type = None
        self.pause_game = False
        self.pending_event = None
        self.timer_active = False
        self.event_timer = 0
        self.stage_started = False
    
    def reset_for_deuce(self):
        """듀스 재시작 시 이벤트 부분 리셋"""
        self.fire_machine.reset_for_deuce()
        print("🔥 Stage 5 이벤트 - 듀스 재시작 리셋")
    
    def is_event_active(self) -> bool:
        """이벤트가 활성화되어 있는지 확인"""
        return self.event_active
    
    def get_event_info(self) -> dict:
        """현재 이벤트 정보 반환"""
        if self.event_active:
            return {
                "type": self.event_type,
                "pause_game": self.pause_game,
                "phase": self.fire_machine.phase if self.event_type == "fire_machine" else None
            }
        return {"type": None, "pause_game": False, "phase": None}