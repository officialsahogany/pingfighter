"""
튜토리얼 마이그레이션 헬퍼
기존 pingfighter.py의 튜토리얼 코드를 새 모듈로 연결하는 어댑터
"""

import pygame
import logging
from typing import Optional, Dict, Any
from tutorial_integration import (
    get_tutorial_integration,
    init_tutorial_system,
    update_tutorial,
    render_tutorial,
    handle_tutorial_event,
    notify_tutorial_event
)

logger = logging.getLogger(__name__)

# ============================================================
# 기존 전역 변수 호환성 레이어
# ============================================================

class TutorialGlobalsAdapter:
    """기존 전역 변수를 새 시스템으로 매핑"""
    
    def __init__(self):
        # 기존 전역 변수 매핑
        self.tutorial_current_chapter = 0
        self.tutorial_power_counter_active = False
        self.tutorial_power_count = 0
        self.tutorial_displayed_power_count = 0
        self.tutorial_power_completion_dialogue_shown = False
        self.tutorial_needs_power_practice = False
        self.tutorial_power_reminder_active = False
        self.tutorial_power_practice_shown = False
        self.tutorial_chapter4_just_started = False
        self.tutorial_power_helper_dialogue_shown = False
        
        # 대쉬 관련
        self.tutorial_dash_count = 0
        self.tutorial_half_dash_count = 0
        self.tutorial_consecutive_dash_count = 0
        self.tutorial_displayed_dash_count = 0.0
        self.tutorial_dash_counter_active = False
        self.tutorial_dash_helper_active = False
        self.tutorial_dash_completion_dialogue_shown = False
        self.tutorial_dash_token_dialogue_shown = False
        
        # 드라이브 관련
        self.tutorial_drive_count = 0
        self.tutorial_displayed_drive_count = 0.0
        self.tutorial_drive_counter_active = False
        self.tutorial_drive_helper_dialogue_shown = False
        self.tutorial_drive_completion_dialogue_shown = False
        self.tutorial_drive_reminder_active = False
        
        # 서브 관련
        self.tutorial_serve_reminder_active = False
        
        # 피드백 관련
        self.tutorial_success_feedback_active = False
        self.tutorial_success_feedback_message = ""
        self.tutorial_success_feedback_timer = 0
        self.tutorial_success_feedback_level = "normal"
        
        # 기타
        self.tutorial_practice_mode = False
        self.tutorial_hit_count = 0
        self.tutorial_displayed_hit_count = 0.0
        
    def sync_with_new_system(self, tutorial_manager):
        """새 시스템과 동기화"""
        if not tutorial_manager:
            return
            
        state = tutorial_manager.state
        
        # 챕터 동기화
        self.tutorial_current_chapter = state.current_chapter.value
        
        # 현재 챕터 상태 가져오기
        chapter_state = state.get_current_chapter_state()
        
        # 카운터 동기화
        if hasattr(chapter_state, 'hit_count'):
            self.tutorial_hit_count = chapter_state.hit_count
            
        if hasattr(chapter_state, 'dash_count'):
            self.tutorial_dash_count = chapter_state.dash_count
            self.tutorial_half_dash_count = chapter_state.half_dash_count
            self.tutorial_consecutive_dash_count = chapter_state.consecutive_dash_count
            
        if hasattr(chapter_state, 'drive_count'):
            self.tutorial_drive_count = chapter_state.drive_count
            
        if hasattr(chapter_state, 'power_count'):
            self.tutorial_power_count = chapter_state.power_count
            
        # UI 상태 동기화
        ui_states = state.ui_states
        self.tutorial_success_feedback_active = ui_states.get('feedback_active', False)
        self.tutorial_success_feedback_message = ui_states.get('feedback_message', '')
        self.tutorial_success_feedback_timer = ui_states.get('feedback_timer', 0)

# 전역 어댑터 인스턴스
_globals_adapter = TutorialGlobalsAdapter()

# ============================================================
# 기존 함수 대체 (pingfighter.py에서 호출되는 함수들)
# ============================================================

def show_tutorial_dialog():
    """기존 튜토리얼 대화 함수 대체"""
    # pingfighter.py의 globals()를 전달해야 함
    import sys
    frame = sys._getframe(1)  # 호출한 함수의 프레임
    globals_dict = frame.f_globals
    
    integration = get_tutorial_integration(globals_dict)
    if integration:
        return integration.start_tutorial()
    return False

def show_tutorial_intro_dialogue():
    """기존 인트로 대화 함수 대체"""
    integration = get_tutorial_integration()
    if integration and integration.tutorial_manager:
        # 인트로 챕터 시작
        integration.tutorial_manager.state.current_chapter = 0
        return True
    return False

def show_tutorial_miss_dialogue():
    """기존 실수 대화 함수 대체"""
    integration = get_tutorial_integration()
    if integration and integration.tutorial_manager:
        integration.tutorial_manager.show_feedback("다시 시도해보세요", "warning")

def show_tutorial_boss_return_dialogue():
    """보스 리턴 대화 대체"""
    pass  # 새 시스템에서는 자동 처리

def show_tutorial_dash_dialogue():
    """대쉬 대화 대체"""
    return True

def show_tutorial_dash_helper():
    """대쉬 도우미 대체"""
    integration = get_tutorial_integration()
    if integration and integration.tutorial_manager:
        integration.tutorial_manager.state.ui_states['helper_visible'] = True
    return True

def show_tutorial_dash_completion_dialogue():
    """대쉬 완료 대화 대체"""
    pass

def show_tutorial_drive_dialogue():
    """드라이브 대화 대체"""
    return True

def show_tutorial_drive_helper_dialogue():
    """드라이브 도우미 대화 대체"""
    return True

def show_tutorial_drive_completion_dialogue():
    """드라이브 완료 대화 대체"""
    return "proceed_to_chapter4"

def show_tutorial_power_practice_dialogue():
    """파워 연습 대화 대체"""
    return True

def show_tutorial_power_demonstration():
    """파워 시범 대체"""
    return True

def show_tutorial_power_helper_dialogue():
    """파워 도우미 대화 대체"""
    return True

def show_tutorial_power_completion_dialogue():
    """파워 완료 대화 대체"""
    return "tutorial_complete"

def show_tutorial_speed_dialogue():
    """속도 대화 대체"""
    return True

def show_tutorial_angle_dialogue():
    """각도 대화 대체"""
    return True

def show_tutorial_gauge_dialogue():
    """게이지 대화 대체"""
    return True

def show_tutorial_dash_token_dialogue():
    """대쉬 토큰 대화 대체"""
    return True

def show_tutorial_serve_helper():
    """서브 도우미 대체"""
    return True

def show_tutorial_success_feedback(message, level="normal"):
    """성공 피드백 대체"""
    integration = get_tutorial_integration()
    if integration and integration.tutorial_manager:
        integration.tutorial_manager.show_feedback(message, level)

def show_tutorial_success_feedback_blocking(message, level="normal"):
    """블로킹 피드백 대체"""
    show_tutorial_success_feedback(message, level)

def init_tutorial_success_feedback(message, level="normal"):
    """피드백 초기화 대체"""
    _globals_adapter.tutorial_success_feedback_active = True
    _globals_adapter.tutorial_success_feedback_message = message
    _globals_adapter.tutorial_success_feedback_level = level
    _globals_adapter.tutorial_success_feedback_timer = 2.0

# ============================================================
# UI 그리기 함수 대체
# ============================================================

def draw_tutorial_ui():
    """튜토리얼 UI 그리기 대체"""
    # 새 시스템의 render_tutorial이 처리
    pass

def draw_tutorial_progress_bar():
    """진행도 바 그리기 대체"""
    pass

def draw_tutorial_success_feedback():
    """피드백 그리기 대체"""
    pass

def draw_tutorial_dash_counter():
    """대쉬 카운터 그리기 대체"""
    pass

def draw_tutorial_drive_counter():
    """드라이브 카운터 그리기 대체"""
    pass

def draw_tutorial_power_counter():
    """파워 카운터 그리기 대체"""
    pass

def draw_tutorial_practice_room():
    """연습장 배경 그리기 대체"""
    # 기본 배경만 그리기
    pass

def draw_tutorial_dash_helper():
    """대쉬 도우미 오버레이 대체"""
    pass

def draw_tutorial_serve_reminder():
    """서브 알림 오버레이 대체"""
    pass

def draw_tutorial_drive_reminder():
    """드라이브 알림 오버레이 대체"""
    pass

# ============================================================
# 체크 함수 대체
# ============================================================

def check_tutorial_dash_missions_complete():
    """대쉬 미션 완료 체크 대체"""
    integration = get_tutorial_integration()
    if integration and integration.tutorial_manager:
        state = integration.tutorial_manager.state
        chapter_state = state.get_current_chapter_state()
        if hasattr(chapter_state, 'is_complete'):
            return chapter_state.is_complete()
    return False

def check_tutorial_special_missions_complete():
    """특수 미션 완료 체크 대체"""
    return check_tutorial_dash_missions_complete()

# ============================================================
# 전역 변수 접근 함수
# ============================================================

def get_tutorial_globals():
    """전역 변수 어댑터 반환"""
    return _globals_adapter

def sync_tutorial_globals(globals_dict):
    """기존 전역 변수와 동기화"""
    integration = get_tutorial_integration()
    if integration and integration.tutorial_manager:
        _globals_adapter.sync_with_new_system(integration.tutorial_manager)
        
        # globals_dict에 값 복사
        for key, value in vars(_globals_adapter).items():
            if key.startswith('tutorial_'):
                globals_dict[key] = value

# ============================================================
# 메인 통합 함수
# ============================================================

def initialize_tutorial_migration(globals_dict):
    """튜토리얼 마이그레이션 초기화"""
    logger.info("Initializing tutorial migration...")
    
    # 새 시스템 초기화
    if init_tutorial_system(globals_dict):
        logger.info("Tutorial system initialized successfully")
        
        # 기존 전역 변수 동기화
        sync_tutorial_globals(globals_dict)
        
        return True
    
    logger.error("Failed to initialize tutorial system")
    return False

def update_tutorial_migration(dt, globals_dict):
    """튜토리얼 업데이트 (메인 루프에서 호출)"""
    # 새 시스템 업데이트
    update_tutorial(dt)
    
    # 전역 변수 동기화
    sync_tutorial_globals(globals_dict)

def render_tutorial_migration(screen, globals_dict):
    """튜토리얼 렌더링 (메인 루프에서 호출)"""
    # 새 시스템 렌더링
    render_tutorial(screen)

def handle_tutorial_event_migration(event, globals_dict):
    """튜토리얼 이벤트 처리"""
    result = handle_tutorial_event(event)
    
    # 전역 변수 동기화
    sync_tutorial_globals(globals_dict)
    
    return result

def notify_tutorial_game_event(event_type, data=None):
    """게임 이벤트를 튜토리얼에 알림"""
    notify_tutorial_event(event_type, data)

def show_chapter_title(chapter_num, title, subtitle=None):
    """챕터 타이틀 표시 (페이드 효과 포함)"""
    # 간단한 구현 - 실제 구현은 나중에 추가 가능
    print(f"🎬 Chapter {chapter_num}: {title} - {subtitle}")
    return True

def show_chapter_completion_summary(chapter_num, stats=None):
    """챕터 완료 요약 표시"""
    # 간단한 구현 - 실제 구현은 나중에 추가 가능
    print(f"✅ Chapter {chapter_num} 완료!")
    return True

# Trade point 관련 함수들 (스테이지 UI)
def update_trade_point_stars():
    """트레이드 포인트 별 업데이트"""
    pass

def draw_trade_point_stars():
    """트레이드 포인트 별 그리기"""
    pass

def update_trade_point_texts():
    """트레이드 포인트 텍스트 업데이트"""
    pass

def draw_trade_point_texts():
    """트레이드 포인트 텍스트 그리기"""
    pass

# Stage 2, 3 관련 함수들
def draw_stage2_jungle_border():
    """스테이지 2 정글 테두리 그리기"""
    pass

def update_stage2_leaves():
    """스테이지 2 나뭇잎 업데이트"""
    pass

def draw_stage2_leaves():
    """스테이지 2 나뭇잎 그리기"""
    pass

def draw_stage3_border():
    """스테이지 3 테두리 그리기"""
    pass