"""
Replay System - 게임 리플레이 시스템
게임 녹화 및 재생 기능
"""

import pickle
import gzip
import json
import time
import os
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, asdict
from enum import Enum
from core.events import EventType, emit_event, subscribe
from core.global_manager import GlobalManager


class ReplayEventType(Enum):
    """리플레이 이벤트 타입"""
    INPUT = "input"
    GAME_STATE = "game_state"
    COLLISION = "collision"
    SCORE = "score"
    ITEM = "item"
    SPECIAL = "special"
    POSITION = "position"
    FRAME = "frame"


@dataclass
class ReplayFrame:
    """리플레이 프레임 데이터"""
    frame_number: int
    timestamp: float
    events: List[Dict[str, Any]]
    game_state: Dict[str, Any]
    
    def to_dict(self) -> Dict[str, Any]:
        """딕셔너리로 변환"""
        return {
            'frame_number': self.frame_number,
            'timestamp': self.timestamp,
            'events': self.events,
            'game_state': self.game_state
        }
        
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'ReplayFrame':
        """딕셔너리에서 생성"""
        return cls(
            frame_number=data['frame_number'],
            timestamp=data['timestamp'],
            events=data['events'],
            game_state=data['game_state']
        )


class ReplayRecorder:
    """리플레이 레코더"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        
        # 녹화 상태
        self.recording = False
        self.frames: List[ReplayFrame] = []
        self.start_time = 0
        self.current_frame = 0
        
        # 이벤트 버퍼
        self.event_buffer: List[Dict[str, Any]] = []
        
        # 녹화 설정
        self.max_frames = 36000  # 60fps * 10분 = 36000 프레임
        self.record_interval = 1  # 매 프레임 기록
        
        # 메타데이터
        self.metadata = {
            'version': '1.0.0',
            'stage': 1,
            'player_name': 'Player',
            'difficulty': 'normal',
            'duration': 0,
            'total_frames': 0,
            'created_at': 0
        }
        
    def start_recording(self, metadata: Optional[Dict[str, Any]] = None):
        """녹화 시작
        
        Args:
            metadata: 메타데이터
        """
        if self.recording:
            return
            
        self.recording = True
        self.frames = []
        self.current_frame = 0
        self.start_time = time.time()
        self.event_buffer = []
        
        # 메타데이터 업데이트
        if metadata:
            self.metadata.update(metadata)
        self.metadata['created_at'] = self.start_time
        
        print("🔴 녹화 시작")
        emit_event(EventType.MENU_OPENED, {'type': 'replay_recording'})
        
    def stop_recording(self) -> bool:
        """녹화 중지
        
        Returns:
            성공 여부
        """
        if not self.recording:
            return False
            
        self.recording = False
        
        # 메타데이터 업데이트
        self.metadata['duration'] = time.time() - self.start_time
        self.metadata['total_frames'] = len(self.frames)
        
        print(f"⏹️ 녹화 중지 - {len(self.frames)} 프레임 저장됨")
        
        # 자동 저장
        filename = self.generate_filename()
        return self.save_replay(filename)
        
    def record_frame(self):
        """현재 프레임 기록"""
        if not self.recording:
            return
            
        # 프레임 제한 체크
        if len(self.frames) >= self.max_frames:
            self.stop_recording()
            return
            
        # 현재 게임 상태 캡처
        game_state = self.capture_game_state()
        
        # 프레임 생성
        frame = ReplayFrame(
            frame_number=self.current_frame,
            timestamp=time.time() - self.start_time,
            events=self.event_buffer.copy(),
            game_state=game_state
        )
        
        self.frames.append(frame)
        self.event_buffer.clear()
        self.current_frame += 1
        
    def record_event(self, event_type: ReplayEventType, data: Dict[str, Any]):
        """이벤트 기록
        
        Args:
            event_type: 이벤트 타입
            data: 이벤트 데이터
        """
        if not self.recording:
            return
            
        event = {
            'type': event_type.value,
            'data': data,
            'frame': self.current_frame,
            'timestamp': time.time() - self.start_time
        }
        
        self.event_buffer.append(event)
        
    def capture_game_state(self) -> Dict[str, Any]:
        """현재 게임 상태 캡처
        
        Returns:
            게임 상태 딕셔너리
        """
        # 주요 오브젝트 위치
        ball_rect = self.global_manager.get('BALL')
        player_rect = self.global_manager.get('PLAYER')
        boss_rect = self.global_manager.get('BOSS')
        
        state = {
            'ball': {
                'x': ball_rect.centerx if ball_rect else 0,
                'y': ball_rect.centery if ball_rect else 0,
                'dx': self.global_manager.get('ball_dx', 0),
                'dy': self.global_manager.get('ball_dy', 5)
            },
            'player': {
                'x': player_rect.centerx if player_rect else 300,
                'y': player_rect.centery if player_rect else 650
            },
            'boss': {
                'x': boss_rect.centerx if boss_rect else 300,
                'y': boss_rect.centery if boss_rect else 50
            },
            'score': {
                'player': self.global_manager.get('player_score', 0),
                'boss': self.global_manager.get('boss_score', 0)
            },
            'stage': self.global_manager.get('current_stage', 1)
        }
        
        return state
        
    def save_replay(self, filename: str) -> bool:
        """리플레이 저장
        
        Args:
            filename: 파일명
            
        Returns:
            성공 여부
        """
        try:
            # 리플레이 디렉토리 생성
            os.makedirs('replays', exist_ok=True)
            filepath = os.path.join('replays', filename)
            
            # 데이터 준비
            replay_data = {
                'metadata': self.metadata,
                'frames': [frame.to_dict() for frame in self.frames]
            }
            
            # 압축 저장
            with gzip.open(filepath, 'wb') as f:
                pickle.dump(replay_data, f)
                
            print(f"💾 리플레이 저장됨: {filepath}")
            return True
            
        except Exception as e:
            print(f"❌ 리플레이 저장 실패: {e}")
            return False
            
    def generate_filename(self) -> str:
        """파일명 생성
        
        Returns:
            파일명
        """
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        stage = self.metadata.get('stage', 1)
        return f"replay_stage{stage}_{timestamp}.rpg"


class ReplayPlayer:
    """리플레이 플레이어"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        
        # 재생 상태
        self.playing = False
        self.paused = False
        self.frames: List[ReplayFrame] = []
        self.current_frame_index = 0
        self.playback_speed = 1.0
        
        # 메타데이터
        self.metadata = {}
        
        # 재생 타이머
        self.frame_timer = 0
        self.frame_interval = 1/60  # 60fps
        
    def load_replay(self, filename: str) -> bool:
        """리플레이 로드
        
        Args:
            filename: 파일명
            
        Returns:
            성공 여부
        """
        try:
            filepath = os.path.join('replays', filename)
            
            # 압축 파일 읽기
            with gzip.open(filepath, 'rb') as f:
                replay_data = pickle.load(f)
                
            # 데이터 로드
            self.metadata = replay_data['metadata']
            self.frames = [ReplayFrame.from_dict(frame) for frame in replay_data['frames']]
            
            print(f"📂 리플레이 로드됨: {filename}")
            print(f"   프레임: {len(self.frames)}")
            print(f"   시간: {self.metadata.get('duration', 0):.1f}초")
            
            return True
            
        except Exception as e:
            print(f"❌ 리플레이 로드 실패: {e}")
            return False
            
    def start_playback(self):
        """재생 시작"""
        if not self.frames:
            print("❌ 재생할 리플레이가 없습니다")
            return
            
        self.playing = True
        self.paused = False
        self.current_frame_index = 0
        self.frame_timer = 0
        
        print("▶️ 리플레이 재생 시작")
        emit_event(EventType.MENU_OPENED, {'type': 'replay_playing'})
        
    def stop_playback(self):
        """재생 중지"""
        self.playing = False
        self.paused = False
        
        print("⏹️ 리플레이 재생 중지")
        
    def pause_playback(self):
        """재생 일시정지"""
        self.paused = not self.paused
        
        if self.paused:
            print("⏸️ 리플레이 일시정지")
        else:
            print("▶️ 리플레이 재생 재개")
            
    def update(self, dt: float):
        """재생 업데이트
        
        Args:
            dt: 델타 타임
        """
        if not self.playing or self.paused:
            return
            
        # 타이머 업데이트
        self.frame_timer += dt * self.playback_speed
        
        # 프레임 재생
        while self.frame_timer >= self.frame_interval:
            self.frame_timer -= self.frame_interval
            
            if self.current_frame_index < len(self.frames):
                self.play_frame(self.frames[self.current_frame_index])
                self.current_frame_index += 1
            else:
                # 재생 완료
                self.stop_playback()
                break
                
    def play_frame(self, frame: ReplayFrame):
        """프레임 재생
        
        Args:
            frame: 재생할 프레임
        """
        # 게임 상태 복원
        self.restore_game_state(frame.game_state)
        
        # 이벤트 재생
        for event in frame.events:
            self.replay_event(event)
            
    def restore_game_state(self, state: Dict[str, Any]):
        """게임 상태 복원
        
        Args:
            state: 게임 상태
        """
        # 공 위치 복원
        ball_rect = self.global_manager.get('BALL')
        if ball_rect and 'ball' in state:
            ball_rect.centerx = state['ball']['x']
            ball_rect.centery = state['ball']['y']
            self.global_manager.set('ball_dx', state['ball']['dx'])
            self.global_manager.set('ball_dy', state['ball']['dy'])
            
        # 플레이어 위치 복원
        player_rect = self.global_manager.get('PLAYER')
        if player_rect and 'player' in state:
            player_rect.centerx = state['player']['x']
            player_rect.centery = state['player']['y']
            
        # 보스 위치 복원
        boss_rect = self.global_manager.get('BOSS')
        if boss_rect and 'boss' in state:
            boss_rect.centerx = state['boss']['x']
            boss_rect.centery = state['boss']['y']
            
        # 점수 복원
        if 'score' in state:
            self.global_manager.set('player_score', state['score']['player'])
            self.global_manager.set('boss_score', state['score']['boss'])
            
    def replay_event(self, event: Dict[str, Any]):
        """이벤트 재생
        
        Args:
            event: 이벤트 데이터
        """
        event_type = event['type']
        data = event['data']
        
        # 이벤트 타입별 처리
        if event_type == ReplayEventType.INPUT.value:
            # 입력 이벤트는 이미 상태로 복원됨
            pass
        elif event_type == ReplayEventType.COLLISION.value:
            # 충돌 이펙트 재생
            emit_event(EventType.COLLISION, data)
        elif event_type == ReplayEventType.ITEM.value:
            # 아이템 이펙트 재생
            emit_event(EventType.ITEM_COLLECTED, data)
            
    def seek(self, frame_index: int):
        """특정 프레임으로 이동
        
        Args:
            frame_index: 프레임 인덱스
        """
        if 0 <= frame_index < len(self.frames):
            self.current_frame_index = frame_index
            self.play_frame(self.frames[frame_index])
            
    def get_playback_info(self) -> Dict[str, Any]:
        """재생 정보 반환
        
        Returns:
            재생 정보
        """
        total_frames = len(self.frames)
        current_time = 0
        total_time = self.metadata.get('duration', 0)
        
        if total_frames > 0 and self.current_frame_index < total_frames:
            current_time = self.frames[self.current_frame_index].timestamp
            
        return {
            'playing': self.playing,
            'paused': self.paused,
            'current_frame': self.current_frame_index,
            'total_frames': total_frames,
            'current_time': current_time,
            'total_time': total_time,
            'playback_speed': self.playback_speed,
            'progress': self.current_frame_index / total_frames if total_frames > 0 else 0
        }
        
    def set_playback_speed(self, speed: float):
        """재생 속도 설정
        
        Args:
            speed: 재생 속도 (0.25 ~ 4.0)
        """
        self.playback_speed = max(0.25, min(4.0, speed))


class ReplayManager:
    """리플레이 매니저"""
    
    def __init__(self):
        self.recorder = ReplayRecorder()
        self.player = ReplayPlayer()
        
        # 리플레이 목록
        self.replays: List[str] = []
        
        # 이벤트 핸들러 등록
        self.setup_event_handlers()
        
    def setup_event_handlers(self):
        """이벤트 핸들러 설정"""
        # 게임 이벤트 구독
        subscribe(EventType.GAME_START, self.on_game_start)
        subscribe(EventType.GAME_OVER, self.on_game_over)
        subscribe(EventType.COLLISION, self.on_collision)
        subscribe(EventType.ITEM_COLLECTED, self.on_item_collected)
        
    def on_game_start(self, event):
        """게임 시작 이벤트 처리"""
        # 자동 녹화 시작
        metadata = {
            'stage': event.data.get('stage', 1),
            'player_name': GlobalManager.get_instance().get('player_name', 'Player'),
            'difficulty': GlobalManager.get_instance().get_setting('difficulty', 'normal')
        }
        self.recorder.start_recording(metadata)
        
    def on_game_over(self, event):
        """게임 오버 이벤트 처리"""
        # 녹화 중지
        if self.recorder.recording:
            self.recorder.stop_recording()
            
    def on_collision(self, event):
        """충돌 이벤트 처리"""
        if self.recorder.recording:
            self.recorder.record_event(ReplayEventType.COLLISION, event.data)
            
    def on_item_collected(self, event):
        """아이템 수집 이벤트 처리"""
        if self.recorder.recording:
            self.recorder.record_event(ReplayEventType.ITEM, event.data)
            
    def update(self, dt: float):
        """업데이트
        
        Args:
            dt: 델타 타임
        """
        # 녹화 중이면 프레임 기록
        if self.recorder.recording:
            self.recorder.record_frame()
            
        # 재생 중이면 재생 업데이트
        if self.player.playing:
            self.player.update(dt)
            
    def get_replay_list(self) -> List[Dict[str, Any]]:
        """리플레이 목록 반환
        
        Returns:
            리플레이 목록
        """
        replays = []
        
        try:
            # 리플레이 디렉토리 스캔
            if os.path.exists('replays'):
                for filename in os.listdir('replays'):
                    if filename.endswith('.rpg'):
                        filepath = os.path.join('replays', filename)
                        
                        # 메타데이터 읽기
                        try:
                            with gzip.open(filepath, 'rb') as f:
                                data = pickle.load(f)
                                metadata = data['metadata']
                                
                            replays.append({
                                'filename': filename,
                                'stage': metadata.get('stage', 1),
                                'duration': metadata.get('duration', 0),
                                'created_at': metadata.get('created_at', 0),
                                'player_name': metadata.get('player_name', 'Unknown')
                            })
                        except:
                            pass
                            
        except Exception as e:
            print(f"리플레이 목록 로드 실패: {e}")
            
        # 날짜 순으로 정렬
        replays.sort(key=lambda x: x['created_at'], reverse=True)
        
        return replays


# 싱글톤 인스턴스
_replay_manager = None

def get_replay_manager() -> ReplayManager:
    """리플레이 매니저 싱글톤 반환"""
    global _replay_manager
    if _replay_manager is None:
        _replay_manager = ReplayManager()
    return _replay_manager