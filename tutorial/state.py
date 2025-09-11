"""
튜토리얼 상태 관리 모듈
튜토리얼 진행 상태와 데이터를 중앙 집중식으로 관리
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any
from enum import Enum
import logging

logger = logging.getLogger(__name__)


class TutorialChapter(Enum):
    """튜토리얼 챕터 열거형"""
    INTRO = 0
    CHAPTER_1_SERVE = 1
    CHAPTER_2_DASH = 2  
    CHAPTER_3_DRIVE = 3
    CHAPTER_4_POWER = 4
    COMPLETE = 5


@dataclass
class ChapterState:
    """각 챕터별 상태 관리"""
    completed: bool = False
    started: bool = False
    progress: float = 0.0  # 0.0 ~ 1.0
    
    # 챕터별 카운터
    hit_count: int = 0
    miss_count: int = 0
    success_count: int = 0
    
    # 챕터별 플래그
    intro_shown: bool = False
    helper_shown: bool = False
    completion_shown: bool = False
    
    # 챕터별 설정
    target_count: int = 3  # 목표 달성 횟수
    
    def reset(self):
        """챕터 상태 초기화"""
        self.hit_count = 0
        self.miss_count = 0
        self.success_count = 0
        self.progress = 0.0
        
    def is_complete(self) -> bool:
        """챕터 완료 여부"""
        return self.completed or self.success_count >= self.target_count


@dataclass
class DashChapterState(ChapterState):
    """대쉬 챕터 전용 상태"""
    dash_count: int = 0
    half_dash_count: int = 0
    consecutive_dash_count: int = 0
    dash_token_dialogue_shown: bool = False
    
    # 대쉬 미션 목표
    target_dash: int = 3
    target_half_dash: int = 2
    target_consecutive: int = 1
    
    def is_complete(self) -> bool:
        return (self.dash_count >= self.target_dash and
                self.half_dash_count >= self.target_half_dash and
                self.consecutive_dash_count >= self.target_consecutive)


@dataclass
class DriveChapterState(ChapterState):
    """드라이브 챕터 전용 상태"""
    drive_count: int = 0
    gauge_reached_160: bool = False
    gauge_dialogue_shown: bool = False
    target_drives: int = 3
    
    def is_complete(self) -> bool:
        return self.drive_count >= self.target_drives


@dataclass
class PowerChapterState(ChapterState):
    """파워스매싱 챕터 전용 상태"""
    power_count: int = 0
    gauge_reached_500: bool = False
    demonstration_shown: bool = False
    target_power: int = 3
    
    def is_complete(self) -> bool:
        return self.power_count >= self.target_power


class TutorialState:
    """튜토리얼 전체 상태 관리 클래스"""
    
    def __init__(self):
        """초기화"""
        # 현재 챕터
        self.current_chapter = TutorialChapter.INTRO
        
        # 전체 진행도
        self.overall_progress = 0.0
        
        # 튜토리얼 활성화 상태
        self.is_active = False
        self.is_paused = False
        
        # 챕터별 상태
        self.chapter_states: Dict[TutorialChapter, ChapterState] = {
            TutorialChapter.INTRO: ChapterState(),
            TutorialChapter.CHAPTER_1_SERVE: ChapterState(target_count=10),
            TutorialChapter.CHAPTER_2_DASH: DashChapterState(),
            TutorialChapter.CHAPTER_3_DRIVE: DriveChapterState(),
            TutorialChapter.CHAPTER_4_POWER: PowerChapterState(),
            TutorialChapter.COMPLETE: ChapterState(),
        }
        
        # UI 표시 상태
        self.ui_states = {
            'progress_bar_visible': True,
            'counter_visible': False,
            'helper_visible': False,
            'feedback_active': False,
            'feedback_message': '',
            'feedback_level': 'normal',
            'feedback_timer': 0,
        }
        
        # 대화 상태
        self.dialogue_states = {
            'current_dialogue': None,
            'dialogue_queue': [],
            'dialogue_blocking': False,
        }
        
        # 애니메이션 상태
        self.animation_states = {
            'counter_animation': 0.0,
            'progress_animation': 0.0,
            'celebration_active': False,
            'celebration_timer': 0,
        }
        
        logger.info("TutorialState initialized")
    
    def start_tutorial(self):
        """튜토리얼 시작"""
        self.is_active = True
        self.current_chapter = TutorialChapter.INTRO
        logger.info("Tutorial started")
    
    def end_tutorial(self):
        """튜토리얼 종료"""
        self.is_active = False
        self.current_chapter = TutorialChapter.COMPLETE
        logger.info("Tutorial ended")
    
    def advance_chapter(self):
        """다음 챕터로 진행"""
        if self.current_chapter.value < TutorialChapter.COMPLETE.value:
            old_chapter = self.current_chapter
            self.current_chapter = TutorialChapter(self.current_chapter.value + 1)
            
            # 새 챕터 시작
            new_state = self.get_current_chapter_state()
            new_state.started = True
            
            # 진행도 업데이트
            self.update_overall_progress()
            
            logger.info(f"Advanced from {old_chapter.name} to {self.current_chapter.name}")
    
    def get_current_chapter_state(self) -> ChapterState:
        """현재 챕터 상태 반환"""
        return self.chapter_states.get(self.current_chapter, ChapterState())
    
    def update_chapter_progress(self, progress: float):
        """챕터 진행도 업데이트"""
        state = self.get_current_chapter_state()
        state.progress = min(1.0, max(0.0, progress))
        self.update_overall_progress()
    
    def update_overall_progress(self):
        """전체 진행도 계산"""
        total_chapters = len(TutorialChapter) - 2  # INTRO와 COMPLETE 제외
        completed_chapters = sum(
            1 for chapter, state in self.chapter_states.items()
            if state.completed and chapter not in [TutorialChapter.INTRO, TutorialChapter.COMPLETE]
        )
        
        current_progress = 0.0
        if self.current_chapter not in [TutorialChapter.INTRO, TutorialChapter.COMPLETE]:
            current_state = self.get_current_chapter_state()
            current_progress = current_state.progress
        
        self.overall_progress = (completed_chapters + current_progress) / total_chapters
    
    def mark_chapter_complete(self):
        """현재 챕터를 완료로 표시"""
        state = self.get_current_chapter_state()
        state.completed = True
        state.progress = 1.0
        self.update_overall_progress()
        logger.info(f"Chapter {self.current_chapter.name} marked as complete")
    
    def reset(self):
        """전체 상태 초기화"""
        self.__init__()
        logger.info("Tutorial state reset")
    
    def get_save_data(self) -> Dict[str, Any]:
        """저장용 데이터 반환"""
        return {
            'current_chapter': self.current_chapter.value,
            'overall_progress': self.overall_progress,
            'is_active': self.is_active,
            'chapter_states': {
                chapter.name: {
                    'completed': state.completed,
                    'progress': state.progress,
                    'success_count': state.success_count,
                }
                for chapter, state in self.chapter_states.items()
            }
        }
    
    def load_save_data(self, data: Dict[str, Any]):
        """저장된 데이터 로드"""
        try:
            self.current_chapter = TutorialChapter(data.get('current_chapter', 0))
            self.overall_progress = data.get('overall_progress', 0.0)
            self.is_active = data.get('is_active', False)
            
            # 챕터 상태 복원
            saved_states = data.get('chapter_states', {})
            for chapter_name, state_data in saved_states.items():
                try:
                    chapter = TutorialChapter[chapter_name]
                    if chapter in self.chapter_states:
                        state = self.chapter_states[chapter]
                        state.completed = state_data.get('completed', False)
                        state.progress = state_data.get('progress', 0.0)
                        state.success_count = state_data.get('success_count', 0)
                except KeyError:
                    logger.warning(f"Unknown chapter in save data: {chapter_name}")
                    
            logger.info("Tutorial state loaded from save data")
        except Exception as e:
            logger.error(f"Failed to load tutorial save data: {e}")
            self.reset()
    
    def should_show_helper(self) -> bool:
        """도우미 표시 여부 결정"""
        state = self.get_current_chapter_state()
        
        # 각 챕터별 도우미 표시 조건
        if self.current_chapter == TutorialChapter.CHAPTER_1_SERVE:
            return state.hit_count < 3 and not state.helper_shown
        elif self.current_chapter == TutorialChapter.CHAPTER_2_DASH:
            dash_state = state if isinstance(state, DashChapterState) else None
            if dash_state:
                return (dash_state.dash_count == 0 or 
                       dash_state.half_dash_count == 0) and not state.helper_shown
        elif self.current_chapter == TutorialChapter.CHAPTER_3_DRIVE:
            drive_state = state if isinstance(state, DriveChapterState) else None
            if drive_state:
                return not drive_state.gauge_reached_160 and not state.helper_shown
        elif self.current_chapter == TutorialChapter.CHAPTER_4_POWER:
            power_state = state if isinstance(state, PowerChapterState) else None
            if power_state:
                return not power_state.gauge_reached_500 and not state.helper_shown
        
        return False
    
    def __str__(self) -> str:
        """상태 문자열 표현"""
        return (f"TutorialState(chapter={self.current_chapter.name}, "
               f"progress={self.overall_progress:.1%}, active={self.is_active})")