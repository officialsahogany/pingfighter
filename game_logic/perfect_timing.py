"""
Perfect Timing System - 퍼펙트 타이밍 시스템
프레임 단위 정밀 입력 처리
"""

import pygame
import time
from typing import Dict, Any, Optional, Tuple, List
from enum import Enum
from dataclasses import dataclass
from core.events import EventType, emit_event
from core.global_manager import GlobalManager

class TimingGrade(Enum):
    """타이밍 등급"""
    PERFECT = "perfect"
    GREAT = "great"
    GOOD = "good"
    MISS = "miss"

@dataclass
class TimingWindow:
    """타이밍 윈도우"""
    perfect_frames: int = 3   # ±3 프레임
    great_frames: int = 6     # ±6 프레임
    good_frames: int = 10     # ±10 프레임

@dataclass
class InputFrame:
    """입력 프레임 정보"""
    key: int
    frame: int
    time: float
    processed: bool = False

class PerfectTimingManager:
    """퍼펙트 타이밍 매니저"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        
        # 프레임 카운터
        self.frame_counter = 0
        
        # 입력 상태
        self.input_buffer: List[InputFrame] = []
        self.last_key_states: Dict[int, bool] = {}
        
        # 타이밍 윈도우
        self.timing_window = TimingWindow()
        
        # 퍼펙트 타이밍 상태
        self.perfect_timing_active = False
        self.perfect_timing_cooldown = 0.0
        self.perfect_timing_duration = 0.0
        
        # 콤보 시스템
        self.combo_count = 0
        self.max_combo = 0
        self.combo_timer = 0.0
        
        # 특수 입력 패턴
        self.special_patterns = {
            'hadoken': [pygame.K_DOWN, pygame.K_RIGHT, pygame.K_SPACE],  # ↓→ + Space
            'shoryuken': [pygame.K_RIGHT, pygame.K_DOWN, pygame.K_RIGHT, pygame.K_SPACE],  # →↓→ + Space
            'sonic_boom': [pygame.K_LEFT, pygame.K_RIGHT, pygame.K_SPACE],  # ←→ + Space
            'flash_kick': [pygame.K_DOWN, pygame.K_UP, pygame.K_SPACE]  # ↓↑ + Space
        }
        
        # 입력 시퀀스 버퍼
        self.input_sequence: List[int] = []
        self.sequence_timer = 0.0
        
        # 통계
        self.stats = {
            'perfect_count': 0,
            'great_count': 0,
            'good_count': 0,
            'miss_count': 0,
            'total_attempts': 0,
            'best_combo': 0
        }
        
    def update(self, dt: float):
        """업데이트"""
        self.frame_counter += 1
        
        # 쿨다운 업데이트
        if self.perfect_timing_cooldown > 0:
            self.perfect_timing_cooldown -= dt
            
        # 지속시간 업데이트
        if self.perfect_timing_duration > 0:
            self.perfect_timing_duration -= dt
            if self.perfect_timing_duration <= 0:
                self.deactivate_perfect_timing()
                
        # 콤보 타이머 업데이트
        if self.combo_timer > 0:
            self.combo_timer -= dt
            if self.combo_timer <= 0:
                self.reset_combo()
                
        # 시퀀스 타이머 업데이트
        if self.sequence_timer > 0:
            self.sequence_timer -= dt
            if self.sequence_timer <= 0:
                self.input_sequence.clear()
                
        # 오래된 입력 제거
        current_frame = self.frame_counter
        self.input_buffer = [inp for inp in self.input_buffer 
                           if current_frame - inp.frame < 60]  # 1초 이내
                           
    def handle_input(self, keys):
        """입력 처리
        
        Args:
            keys: pygame.key.get_pressed() 결과
        """
        current_frame = self.frame_counter
        current_time = time.time()
        
        # 주요 키들 체크
        check_keys = [
            pygame.K_SPACE, pygame.K_LEFT, pygame.K_RIGHT,
            pygame.K_UP, pygame.K_DOWN, pygame.K_a, pygame.K_d
        ]
        
        for key in check_keys:
            # Just pressed 감지
            if keys[key] and not self.last_key_states.get(key, False):
                # 입력 버퍼에 추가
                self.input_buffer.append(
                    InputFrame(key, current_frame, current_time)
                )
                
                # 시퀀스에 추가
                self.input_sequence.append(key)
                self.sequence_timer = 0.5  # 0.5초 내에 다음 입력
                
                # 특수 패턴 체크
                self.check_special_patterns()
                
                # 스페이스바 특별 처리
                if key == pygame.K_SPACE:
                    self.check_perfect_timing()
                    
            # 키 상태 업데이트
            self.last_key_states[key] = keys[key]
            
    def check_perfect_timing(self) -> TimingGrade:
        """퍼펙트 타이밍 체크
        
        Returns:
            타이밍 등급
        """
        if self.perfect_timing_cooldown > 0:
            return TimingGrade.MISS
            
        # 공과 패들의 거리 체크
        ball_rect = self.global_manager.get('BALL')
        player_rect = self.global_manager.get('PLAYER')
        
        if not ball_rect or not player_rect:
            return TimingGrade.MISS
            
        # 공이 플레이어에게 접근하는지 체크
        ball_dy = self.global_manager.get('ball_dy', 0)
        if ball_dy <= 0:  # 공이 위로 가고 있음
            return TimingGrade.MISS
            
        # 거리 계산
        distance = abs(ball_rect.centery - player_rect.centery)
        ball_speed = abs(ball_dy)
        
        if ball_speed <= 0:
            return TimingGrade.MISS
            
        # 프레임 단위로 도달 시간 계산
        frames_to_hit = distance / (ball_speed * 60 / 1000)  # 60 FPS 기준
        
        # 타이밍 등급 판정
        grade = TimingGrade.MISS
        
        if abs(frames_to_hit) <= self.timing_window.perfect_frames:
            grade = TimingGrade.PERFECT
        elif abs(frames_to_hit) <= self.timing_window.great_frames:
            grade = TimingGrade.GREAT
        elif abs(frames_to_hit) <= self.timing_window.good_frames:
            grade = TimingGrade.GOOD
            
        # 통계 업데이트
        self.stats['total_attempts'] += 1
        
        if grade == TimingGrade.PERFECT:
            self.stats['perfect_count'] += 1
            self.activate_perfect_timing()
            self.add_combo(3)
        elif grade == TimingGrade.GREAT:
            self.stats['great_count'] += 1
            self.add_combo(2)
        elif grade == TimingGrade.GOOD:
            self.stats['good_count'] += 1
            self.add_combo(1)
        else:
            self.stats['miss_count'] += 1
            self.reset_combo()
            
        # 이벤트 발생
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'perfect_timing',
            'grade': grade.value,
            'combo': self.combo_count
        })
        
        return grade
        
    def activate_perfect_timing(self):
        """퍼펙트 타이밍 발동"""
        self.perfect_timing_active = True
        self.perfect_timing_duration = 3.0  # 3초간 지속
        self.perfect_timing_cooldown = 5.0  # 5초 쿨다운
        
        # 효과 적용
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'perfect_timing_active',
            'duration': self.perfect_timing_duration
        })
        
        # 화면 효과
        emit_event(EventType.SCREEN_SHAKE, {
            'intensity': 5,
            'duration': 20
        })
        
    def deactivate_perfect_timing(self):
        """퍼펙트 타이밍 비활성화"""
        self.perfect_timing_active = False
        
    def check_special_patterns(self):
        """특수 패턴 체크"""
        if len(self.input_sequence) < 3:
            return
            
        # 각 패턴 체크
        for pattern_name, pattern in self.special_patterns.items():
            pattern_len = len(pattern)
            
            if len(self.input_sequence) >= pattern_len:
                # 최근 입력이 패턴과 일치하는지 체크
                recent_inputs = self.input_sequence[-pattern_len:]
                
                if recent_inputs == pattern:
                    self.execute_special_pattern(pattern_name)
                    self.input_sequence.clear()
                    break
                    
    def execute_special_pattern(self, pattern_name: str):
        """특수 패턴 실행
        
        Args:
            pattern_name: 패턴 이름
        """
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'special_pattern',
            'pattern': pattern_name
        })
        
        # 패턴별 효과
        if pattern_name == 'hadoken':
            # 파동권: 강력한 공격
            emit_event(EventType.SPECIAL_ACTIVATED, {
                'type': 'hadoken',
                'damage': 3.0
            })
        elif pattern_name == 'shoryuken':
            # 승룡권: 위로 강한 타격
            emit_event(EventType.SPECIAL_ACTIVATED, {
                'type': 'shoryuken',
                'damage': 2.5,
                'knockback': 10.0
            })
        elif pattern_name == 'sonic_boom':
            # 소닉붐: 음파 공격
            emit_event(EventType.SPECIAL_ACTIVATED, {
                'type': 'sonic_boom',
                'damage': 2.0,
                'range': 300
            })
        elif pattern_name == 'flash_kick':
            # 플래시킥: 빠른 반격
            emit_event(EventType.SPECIAL_ACTIVATED, {
                'type': 'flash_kick',
                'damage': 2.0,
                'speed': 2.0
            })
            
        # 콤보 추가
        self.add_combo(5)
        
    def add_combo(self, count: int):
        """콤보 추가
        
        Args:
            count: 추가할 콤보 수
        """
        self.combo_count += count
        self.combo_timer = 2.0  # 2초 내에 다음 콤보
        
        if self.combo_count > self.max_combo:
            self.max_combo = self.combo_count
            self.stats['best_combo'] = self.max_combo
            
        # 콤보 보너스
        if self.combo_count >= 10:
            emit_event(EventType.SPECIAL_ACTIVATED, {
                'type': 'combo_bonus',
                'combo': self.combo_count,
                'bonus': self.combo_count * 0.1
            })
            
    def reset_combo(self):
        """콤보 리셋"""
        self.combo_count = 0
        self.combo_timer = 0
        
    def get_frame_input(self, key: int, frame_window: int = 3) -> Optional[InputFrame]:
        """특정 프레임 윈도우 내의 입력 가져오기
        
        Args:
            key: 키 코드
            frame_window: 프레임 윈도우
            
        Returns:
            입력 프레임 또는 None
        """
        current_frame = self.frame_counter
        
        for inp in self.input_buffer:
            if inp.key == key and not inp.processed:
                frame_diff = abs(current_frame - inp.frame)
                if frame_diff <= frame_window:
                    inp.processed = True
                    return inp
                    
        return None
        
    def is_perfect_timing_active(self) -> bool:
        """퍼펙트 타이밍 활성 상태 확인"""
        return self.perfect_timing_active
        
    def get_combo_multiplier(self) -> float:
        """콤보 배율 반환"""
        if self.combo_count <= 0:
            return 1.0
        elif self.combo_count < 5:
            return 1.0 + self.combo_count * 0.1
        elif self.combo_count < 10:
            return 1.5 + (self.combo_count - 5) * 0.2
        else:
            return 2.5 + (self.combo_count - 10) * 0.05
            
    def get_stats(self) -> Dict[str, Any]:
        """통계 반환"""
        return self.stats.copy()
        
    def render_ui(self, screen: pygame.Surface):
        """UI 렌더링"""
        font = pygame.font.Font(None, 24)
        
        # 콤보 표시
        if self.combo_count > 0:
            combo_text = f"COMBO x{self.combo_count}"
            color = (255, 255, 255)
            
            if self.combo_count >= 10:
                color = (255, 215, 0)  # 금색
            elif self.combo_count >= 5:
                color = (0, 255, 255)  # 청록색
                
            text_surface = font.render(combo_text, True, color)
            text_rect = text_surface.get_rect(center=(300, 100))
            
            # 콤보 타이머 바
            if self.combo_timer > 0:
                bar_width = int(100 * (self.combo_timer / 2.0))
                pygame.draw.rect(screen, (100, 100, 100),
                               (250, 115, 100, 5))
                pygame.draw.rect(screen, color,
                               (250, 115, bar_width, 5))
                               
            screen.blit(text_surface, text_rect)
            
        # 퍼펙트 타이밍 활성 표시
        if self.perfect_timing_active:
            pt_text = "PERFECT TIMING!"
            text_surface = font.render(pt_text, True, (255, 255, 0))
            text_rect = text_surface.get_rect(center=(300, 150))
            
            # 깜빡임 효과
            if self.frame_counter % 20 < 10:
                screen.blit(text_surface, text_rect)
                
        # 타이밍 가이드 (디버그용)
        if self.global_manager.get('debug_mode', False):
            ball_rect = self.global_manager.get('BALL')
            player_rect = self.global_manager.get('PLAYER')
            
            if ball_rect and player_rect:
                # 타이밍 존 표시
                perfect_zone = player_rect.centery - 50
                great_zone = player_rect.centery - 80
                good_zone = player_rect.centery - 120
                
                pygame.draw.line(screen, (0, 255, 0), (0, perfect_zone), (600, perfect_zone), 1)
                pygame.draw.line(screen, (255, 255, 0), (0, great_zone), (600, great_zone), 1)
                pygame.draw.line(screen, (255, 100, 0), (0, good_zone), (600, good_zone), 1)

# 싱글톤 인스턴스
_perfect_timing_manager = None

def get_perfect_timing_manager() -> PerfectTimingManager:
    """퍼펙트 타이밍 매니저 싱글톤 반환"""
    global _perfect_timing_manager
    if _perfect_timing_manager is None:
        _perfect_timing_manager = PerfectTimingManager()
    return _perfect_timing_manager