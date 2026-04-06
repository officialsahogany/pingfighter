"""
Replay System - 게임 리플레이 녹화 및 재생
매 프레임 핵심 게임 상태(공, 패들, 점수 등)를 경량 기록하고,
gzip 압축된 .rpg 파일로 자동 저장한다.
"""

import pickle
import gzip
import time
import os
import sys
from typing import Dict, Any, List, Optional
from dataclasses import dataclass


def _replays_dir() -> str:
    """replays 폴더 절대 경로 반환 (PyInstaller 대응)"""
    try:
        base = sys._MEIPASS
    except AttributeError:
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base, "replays")


# ============================================================================
# 프레임 데이터 구조
# ============================================================================
@dataclass
class ReplayFrame:
    """한 프레임의 게임 상태 스냅샷 (경량)"""
    fn: int              # frame_number
    ts: float            # timestamp (초)
    bx: int              # ball center x
    by: int              # ball center y
    bvx: float           # ball vel x
    bvy: float           # ball vel y
    px: int              # player paddle center x
    py: int              # player paddle center y
    pw: int              # player paddle width
    ox: int              # boss paddle center x
    oy: int              # boss paddle center y
    ow: int              # boss paddle width
    ps: int              # player score
    bs: int              # boss score
    sg: int              # special gauge (0-400)
    ev: List[Dict]       # events this frame (score, item, etc.)

    def to_tuple(self):
        return (
            self.fn, self.ts,
            self.bx, self.by, self.bvx, self.bvy,
            self.px, self.py, self.pw,
            self.ox, self.oy, self.ow,
            self.ps, self.bs, self.sg,
            self.ev,
        )

    @classmethod
    def from_tuple(cls, t):
        return cls(*t)


# ============================================================================
# 레코더 — pingfighter.py 게임 루프에서 직접 호출
# ============================================================================
class ReplayRecorder:
    """매 프레임 호출하여 게임 상태를 기록하는 레코더"""

    MAX_FRAMES = 36000  # 60fps × 10분

    def __init__(self):
        self.recording = False
        self.frames: List[tuple] = []
        self.event_buffer: List[Dict] = []
        self.start_time = 0.0
        self.current_frame = 0
        self.metadata: Dict[str, Any] = {}

    # ------------------------------------------------------------------
    def start(self, stage: int = 1, boss_name: str = "",
              ai_mode: str = "normal", character: str = "smasher",
              result: str = ""):
        """녹화 시작 — main() 함수 진입 시 호출"""
        self.recording = True
        self.frames = []
        self.event_buffer = []
        self.current_frame = 0
        self.start_time = time.time()
        self.metadata = {
            'version': '2.0.0',
            'stage': stage,
            'boss_name': boss_name,
            'ai_mode': ai_mode,
            'character': character,
            'result': result,
            'duration': 0,
            'total_frames': 0,
            'created_at': self.start_time,
        }
        print(f"[Replay] 녹화 시작 — Stage {stage}, boss={boss_name}, char={character}")

    def stop(self, result: str = "") -> bool:
        """녹화 중지 + 자동 저장. result: 'win' / 'lose' / ''"""
        if not self.recording:
            print(f"[Replay] stop() 호출됐으나 recording=False (이미 중지됨)")
            return False
        self.recording = False
        self.metadata['duration'] = time.time() - self.start_time
        self.metadata['total_frames'] = len(self.frames)
        if result:
            self.metadata['result'] = result
        print(f"[Replay] 녹화 중지 — {len(self.frames)}프레임, result={result}")
        if len(self.frames) == 0:
            print(f"[Replay] 프레임이 0개라 저장 건너뜀")
            return False
        return self._save()

    def record(self, ball, player, boss, ball_vel,
               player_score: int, boss_score: int,
               special_gauge: int = 0):
        """매 프레임 호출 — pygame.Rect 객체와 게임 변수를 직접 전달받음"""
        if not self.recording:
            return
        if len(self.frames) >= self.MAX_FRAMES:
            self.stop()
            return
        ts = time.time() - self.start_time
        frame = (
            self.current_frame, ts,
            int(ball.centerx), int(ball.centery),
            float(ball_vel[0]), float(ball_vel[1]),
            int(player.centerx), int(player.centery), int(player.width),
            int(boss.centerx), int(boss.centery), int(boss.width),
            int(player_score), int(boss_score), int(special_gauge),
            self.event_buffer.copy(),
        )
        self.frames.append(frame)
        self.event_buffer.clear()
        self.current_frame += 1

    def add_event(self, event_type: str, data: Dict = None):
        """이벤트 기록 (득점, 아이템 획득 등)"""
        if not self.recording:
            return
        self.event_buffer.append({'t': event_type, 'd': data or {}})

    # ------------------------------------------------------------------
    def _save(self) -> bool:
        """replays/ 폴더에 압축 저장"""
        try:
            replay_dir = _replays_dir()
            os.makedirs(replay_dir, exist_ok=True)
            ts_str = time.strftime("%Y%m%d_%H%M%S")
            stage = self.metadata.get('stage', 0)
            filename = f"replay_s{stage}_{ts_str}.rpg"
            filepath = os.path.join(replay_dir, filename)

            data = {
                'metadata': self.metadata,
                'frames': self.frames,  # List[tuple] — 매우 경량
            }
            with gzip.open(filepath, 'wb', compresslevel=4) as f:
                pickle.dump(data, f, protocol=pickle.HIGHEST_PROTOCOL)

            size_kb = os.path.getsize(filepath) / 1024
            print(f"[Replay] 저장 완료: {filename} ({len(self.frames)}프레임, {size_kb:.0f}KB)")
            return True
        except Exception as e:
            print(f"[Replay] 저장 실패: {e}")
            import traceback; traceback.print_exc()
            return False


# ============================================================================
# 플레이어 — 리플레이 재생 엔진
# ============================================================================
class ReplayPlayer:
    """저장된 리플레이를 프레임 단위로 재생"""

    SPEED_OPTIONS = [0.25, 0.5, 1.0, 1.5, 2.0, 4.0]

    def __init__(self):
        self.frames: List[tuple] = []
        self.metadata: Dict[str, Any] = {}
        self.playing = False
        self.paused = False
        self.current_index = 0
        self.speed = 1.0
        self.frame_accum = 0.0

    def load(self, filepath: str) -> bool:
        """리플레이 파일 로드"""
        try:
            with gzip.open(filepath, 'rb') as f:
                data = pickle.load(f)
            self.metadata = data['metadata']
            self.frames = data['frames']
            self.current_index = 0
            self.frame_accum = 0.0
            return True
        except Exception as e:
            print(f"[Replay] 로드 실패: {e}")
            return False

    def start(self):
        if not self.frames:
            return
        self.playing = True
        self.paused = False
        self.current_index = 0
        self.frame_accum = 0.0

    def stop(self):
        self.playing = False
        self.paused = False

    def toggle_pause(self):
        self.paused = not self.paused

    def cycle_speed(self):
        """다음 배속으로 전환"""
        try:
            idx = self.SPEED_OPTIONS.index(self.speed)
            self.speed = self.SPEED_OPTIONS[(idx + 1) % len(self.SPEED_OPTIONS)]
        except ValueError:
            self.speed = 1.0

    def seek_relative(self, delta_frames: int):
        """현재 위치에서 상대적 이동"""
        new_idx = max(0, min(len(self.frames) - 1, self.current_index + delta_frames))
        self.current_index = new_idx

    def advance(self) -> Optional[tuple]:
        """매 게임 프레임(60fps) 호출. 현재 재생할 프레임 데이터를 반환."""
        if not self.playing or self.paused or not self.frames:
            if self.paused and self.frames and 0 <= self.current_index < len(self.frames):
                return self.frames[self.current_index]
            return None

        self.frame_accum += self.speed
        result = None
        while self.frame_accum >= 1.0:
            self.frame_accum -= 1.0
            if self.current_index < len(self.frames):
                result = self.frames[self.current_index]
                self.current_index += 1
            else:
                self.stop()
                break
        return result

    def get_current_frame(self) -> Optional[tuple]:
        """현재 인덱스의 프레임 반환 (렌더링용)"""
        if self.frames and 0 <= self.current_index < len(self.frames):
            return self.frames[self.current_index]
        return None

    @property
    def progress(self) -> float:
        if not self.frames:
            return 0.0
        return self.current_index / len(self.frames)

    @property
    def current_time(self) -> float:
        if self.frames and 0 <= self.current_index < len(self.frames):
            return self.frames[self.current_index][1]
        return 0.0

    @property
    def total_time(self) -> float:
        return self.metadata.get('duration', 0)

    @property
    def finished(self) -> bool:
        return not self.playing and self.current_index >= len(self.frames)


# ============================================================================
# 유틸: 리플레이 목록 조회 / 삭제
# ============================================================================
def list_replays() -> List[Dict[str, Any]]:
    """replays/ 폴더의 리플레이 목록 반환 (최신순)"""
    replays = []
    replay_dir = _replays_dir()
    if not os.path.isdir(replay_dir):
        return replays
    for fn in os.listdir(replay_dir):
        if not fn.endswith('.rpg'):
            continue
        fp = os.path.join(replay_dir, fn)
        try:
            with gzip.open(fp, 'rb') as f:
                data = pickle.load(f)
            md = data.get('metadata', {})
            replays.append({
                'filename': fn,
                'filepath': fp,
                'stage': md.get('stage', 0),
                'boss_name': md.get('boss_name', ''),
                'ai_mode': md.get('ai_mode', ''),
                'character': md.get('character', ''),
                'result': md.get('result', ''),
                'duration': md.get('duration', 0),
                'total_frames': md.get('total_frames', 0),
                'created_at': md.get('created_at', 0),
            })
        except Exception:
            pass
    replays.sort(key=lambda x: x['created_at'], reverse=True)
    return replays


def delete_replay(filepath: str) -> bool:
    try:
        os.remove(filepath)
        return True
    except Exception:
        return False


# ============================================================================
# 싱글톤 레코더 (전역 접근용)
# ============================================================================
_recorder: Optional[ReplayRecorder] = None


def get_recorder() -> ReplayRecorder:
    global _recorder
    if _recorder is None:
        _recorder = ReplayRecorder()
    return _recorder
