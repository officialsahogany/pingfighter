"""
Replay System v4 — 화면 캡처 기반 리플레이 (비동기 압축)
게임 루프에서는 screen.copy()만 수행 (빠름),
압축 + 디스크 쓰기는 백그라운드 스레드가 처리 → 프레임드랍 없음.
"""

import pygame
import zlib
import struct
import pickle
import time
import os
import sys
import threading
from collections import deque
from typing import Dict, Any, List, Optional

# 파일 매직 + 버전
_MAGIC = b'PFRP'
_VERSION = 4

# 캡처 설정
CAPTURE_INTERVAL = 1    # 매 프레임 캡처 (60fps) — 비동기 압축으로 부담 없음
SCALE_FACTOR = 1.0      # 원본 해상도 (100%) — 압축은 백그라운드에서 처리
COMPRESS_LEVEL = 1      # zlib 압축 (1=빠름)
MAX_DURATION = 600      # 최대 10분
MAX_REPLAYS = 10        # 최대 리플레이 파일 수 (초과 시 가장 오래된 파일 자동 삭제)


def _replays_dir() -> str:
    try:
        base = sys._MEIPASS
    except AttributeError:
        base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base, "replays")


# ============================================================================
# 레코더 — 게임 루프에서는 copy만, 압축/쓰기는 백그라운드 스레드
# ============================================================================
class ReplayRecorder:

    def __init__(self):
        self.recording = False
        self.file = None
        self.filepath = None
        self.game_frame = 0
        self.captured_frames = 0
        self.start_time = 0.0
        self.metadata: Dict[str, Any] = {}
        self.scaled_w = 0
        self.scaled_h = 0
        self.current_frame = 0

        # 사운드 이벤트 트랙: {캡처프레임번호: [사운드ID, ...]}
        self.sound_events: Dict[int, List[str]] = {}

        # 백그라운드 압축 스레드
        self._queue: deque = deque()
        self._thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()
        self._lock = threading.Lock()

    def start(self, stage: int = 1, boss_name: str = "",
              ai_mode: str = "normal", character: str = "smasher",
              result: str = "", screen_w: int = 760, screen_h: int = 750):
        if self.recording:
            self.stop()

        self.scaled_w = int(screen_w * SCALE_FACTOR)
        self.scaled_h = int(screen_h * SCALE_FACTOR)
        self.game_frame = 0
        self.captured_frames = 0
        self.start_time = time.time()
        self.current_frame = 0
        self.sound_events = {}

        self.metadata = {
            'version': _VERSION,
            'stage': stage,
            'boss_name': boss_name,
            'ai_mode': ai_mode,
            'character': character,
            'result': result,
            'duration': 0,
            'total_frames': 0,
            'created_at': self.start_time,
            'screen_w': screen_w,
            'screen_h': screen_h,
            'scaled_w': self.scaled_w,
            'scaled_h': self.scaled_h,
            'capture_fps': 60 // CAPTURE_INTERVAL,
        }

        replay_dir = _replays_dir()
        os.makedirs(replay_dir, exist_ok=True)
        self.filepath = os.path.join(replay_dir, f"_recording_{int(self.start_time)}.tmp")
        try:
            self.file = open(self.filepath, 'wb')
            self.file.write(_MAGIC)
            self.file.write(struct.pack('I', 0))

            # 백그라운드 스레드 시작
            self._queue.clear()
            self._stop_event.clear()
            self._thread = threading.Thread(target=self._writer_loop, daemon=True)
            self._thread.start()

            self.recording = True
            print(f"[Replay] 녹화 시작 — Stage {stage}, {self.scaled_w}x{self.scaled_h} @{60//CAPTURE_INTERVAL}fps (비동기)")
        except Exception as e:
            print(f"[Replay] 녹화 파일 생성 실패: {e}")
            self.recording = False

    def capture(self, screen: pygame.Surface):
        """매 게임 프레임 호출 — copy + tostring만 수행 (빠름)"""
        if not self.recording:
            return
        self.game_frame += 1
        self.current_frame = self.game_frame

        if time.time() - self.start_time > MAX_DURATION:
            self.stop()
            return

        if self.game_frame % CAPTURE_INTERVAL != 0:
            return

        try:
            # 게임 루프에서 하는 일: scale(필요시) + tostring만
            if SCALE_FACTOR < 1.0:
                small = pygame.transform.scale(screen, (self.scaled_w, self.scaled_h))
                raw = pygame.image.tostring(small, 'RGB')
            else:
                raw = pygame.image.tostring(screen, 'RGB')
            # 큐에 넣기 (백그라운드 스레드가 압축+쓰기)
            self._queue.append(raw)
            self.captured_frames += 1
        except Exception:
            pass

    def add_sound(self, sound_id: str):
        """사운드 이벤트 기록 — 현재 캡처 프레임에 사운드 ID 추가"""
        if not self.recording:
            return
        frame = self.captured_frames
        if frame not in self.sound_events:
            self.sound_events[frame] = []
        self.sound_events[frame].append(sound_id)

    def _writer_loop(self):
        """백그라운드 스레드 — 큐에서 꺼내서 압축 + 디스크 쓰기"""
        while not self._stop_event.is_set() or len(self._queue) > 0:
            if len(self._queue) > 0:
                raw = self._queue.popleft()
                try:
                    compressed = zlib.compress(raw, COMPRESS_LEVEL)
                    with self._lock:
                        if self.file and not self.file.closed:
                            self.file.write(struct.pack('I', len(compressed)))
                            self.file.write(compressed)
                except Exception:
                    pass
            else:
                time.sleep(0.005)  # 큐 비었으면 잠깐 대기

    def stop(self, result: str = "") -> bool:
        if not self.recording:
            return False
        self.recording = False

        self.metadata['duration'] = time.time() - self.start_time
        self.metadata['total_frames'] = self.captured_frames
        self.metadata['sound_events'] = self.sound_events
        if result:
            self.metadata['result'] = result

        print(f"[Replay] 녹화 중지 — {self.captured_frames}프레임, {self.metadata['duration']:.1f}초, result={result}")

        # 백그라운드 스레드 종료 대기 (남은 큐 처리)
        self._stop_event.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=10)

        if self.captured_frames == 0 or self.file is None:
            print(f"[Replay] 프레임이 0개라 저장 건너뜀")
            self._cleanup_temp()
            return False

        return self._finalize()

    def _finalize(self) -> bool:
        try:
            meta_bytes = pickle.dumps(self.metadata, protocol=pickle.HIGHEST_PROTOCOL)
            with self._lock:
                self.file.write(struct.pack('I', len(meta_bytes)))
                self.file.write(meta_bytes)
                self.file.seek(len(_MAGIC))
                self.file.write(struct.pack('I', len(meta_bytes)))
                self.file.close()
            self.file = None

            replay_dir = _replays_dir()
            ts_str = time.strftime("%Y%m%d_%H%M%S")
            stage = self.metadata.get('stage', 0)
            final_name = f"replay_s{stage}_{ts_str}.rpl"
            final_path = os.path.join(replay_dir, final_name)
            os.rename(self.filepath, final_path)

            size_mb = os.path.getsize(final_path) / (1024 * 1024)
            print(f"[Replay] 저장 완료: {final_name} ({self.captured_frames}프레임, {size_mb:.1f}MB)")
            # 오래된 리플레이 자동 삭제 (MAX_REPLAYS 초과 시)
            _cleanup_old_replays()
            return True
        except Exception as e:
            print(f"[Replay] 저장 실패: {e}")
            import traceback; traceback.print_exc()
            self._cleanup_temp()
            return False

    def _cleanup_temp(self):
        if self.file:
            try:
                self.file.close()
            except Exception:
                pass
            self.file = None
        if self.filepath and os.path.exists(self.filepath):
            try:
                os.remove(self.filepath)
            except Exception:
                pass


# ============================================================================
# 플레이어 — .rpl 파일에서 프레임을 읽어 재생
# ============================================================================
class ReplayPlayer:

    SPEED_OPTIONS = [0.25, 0.5, 1.0, 1.5, 2.0, 4.0]

    def __init__(self):
        self.metadata: Dict[str, Any] = {}
        self.playing = False
        self.paused = False
        self.current_index = 0
        self.speed = 1.0
        self.frame_accum = 0.0
        self.total_frames = 0
        self.scaled_w = 0
        self.scaled_h = 0
        self.frame_data: List[bytes] = []
        self._current_surface: Optional[pygame.Surface] = None

    def load(self, filepath: str) -> bool:
        try:
            with open(filepath, 'rb') as f:
                magic = f.read(4)
                if magic != _MAGIC:
                    print(f"[Replay] 잘못된 파일 형식")
                    return False

                meta_len_bytes = f.read(4)
                meta_len = struct.unpack('I', meta_len_bytes)[0]

                self.frame_data = []
                while True:
                    size_bytes = f.read(4)
                    if len(size_bytes) < 4:
                        break
                    chunk_size = struct.unpack('I', size_bytes)[0]
                    chunk = f.read(chunk_size)
                    if len(chunk) < chunk_size:
                        break

                    pos = f.tell()
                    next_bytes = f.read(4)
                    if len(next_bytes) < 4:
                        self.metadata = pickle.loads(chunk)
                        break
                    else:
                        f.seek(pos)
                        self.frame_data.append(chunk)

            self.total_frames = len(self.frame_data)
            self.scaled_w = self.metadata.get('scaled_w', 380)
            self.scaled_h = self.metadata.get('scaled_h', 375)
            self.current_index = 0
            self.frame_accum = 0.0

            size_mb = os.path.getsize(filepath) / (1024 * 1024)
            print(f"[Replay] 로드: {self.total_frames}프레임, {self.scaled_w}x{self.scaled_h}, {size_mb:.1f}MB")
            return self.total_frames > 0
        except Exception as e:
            print(f"[Replay] 로드 실패: {e}")
            import traceback; traceback.print_exc()
            return False

    def start(self):
        if self.total_frames == 0:
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
        try:
            idx = self.SPEED_OPTIONS.index(self.speed)
            self.speed = self.SPEED_OPTIONS[(idx + 1) % len(self.SPEED_OPTIONS)]
        except ValueError:
            self.speed = 1.0

    def seek_relative(self, delta_frames: int):
        new_idx = max(0, min(self.total_frames - 1, self.current_index + delta_frames))
        self.current_index = new_idx
        self._current_surface = None

    def get_frame_surface(self) -> Optional[pygame.Surface]:
        if self.current_index < 0 or self.current_index >= self.total_frames:
            return self._current_surface
        try:
            compressed = self.frame_data[self.current_index]
            raw = zlib.decompress(compressed)
            surf = pygame.image.fromstring(raw, (self.scaled_w, self.scaled_h), 'RGB')
            self._current_surface = surf
            return surf
        except Exception:
            return self._current_surface

    def advance(self) -> Optional[pygame.Surface]:
        """매 프레임(60fps) 호출 — 캡처 fps에 맞춰 정속 재생"""
        if not self.playing and not self.paused:
            return None
        if self.paused:
            return self.get_frame_surface()
        if not self.playing:
            return None

        capture_fps = self.metadata.get('capture_fps', 30)
        step = self.speed * (capture_fps / 60.0)

        self.frame_accum += step
        surf = None
        while self.frame_accum >= 1.0:
            self.frame_accum -= 1.0
            if self.current_index < self.total_frames:
                surf = self.get_frame_surface()
                self.current_index += 1
            else:
                self.stop()
                break
        return surf

    @property
    def progress(self) -> float:
        if self.total_frames == 0:
            return 0.0
        return self.current_index / self.total_frames

    @property
    def current_time(self) -> float:
        if self.total_frames == 0:
            return 0.0
        capture_fps = self.metadata.get('capture_fps', 30)
        return self.current_index / capture_fps

    @property
    def total_time(self) -> float:
        return self.metadata.get('duration', 0)

    @property
    def finished(self) -> bool:
        return not self.playing and self.current_index >= self.total_frames

    @property
    def frames(self):
        return self.frame_data


# ============================================================================
# 리플레이 메타 관리 (이름 변경, 잠금) — replay_meta.json
# ============================================================================
def _meta_json_path() -> str:
    return os.path.join(_replays_dir(), "replay_meta.json")


def _load_meta_json() -> Dict[str, Dict]:
    """replay_meta.json 로드. {filename: {custom_name, locked}}"""
    path = _meta_json_path()
    if not os.path.exists(path):
        return {}
    try:
        import json
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {}


def _save_meta_json(data: Dict[str, Dict]):
    import json
    path = _meta_json_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def rename_replay(filename: str, new_name: str):
    """리플레이에 커스텀 이름 설정"""
    meta = _load_meta_json()
    if filename not in meta:
        meta[filename] = {}
    meta[filename]['custom_name'] = new_name.strip()
    _save_meta_json(meta)


def set_replay_locked(filename: str, locked: bool):
    """리플레이 잠금/해제"""
    meta = _load_meta_json()
    if filename not in meta:
        meta[filename] = {}
    meta[filename]['locked'] = locked
    _save_meta_json(meta)


def is_replay_locked(filename: str) -> bool:
    meta = _load_meta_json()
    return meta.get(filename, {}).get('locked', False)


def get_replay_custom_name(filename: str) -> str:
    meta = _load_meta_json()
    return meta.get(filename, {}).get('custom_name', '')


# ============================================================================
# 유틸: 리플레이 목록 조회 / 삭제
# ============================================================================
def list_replays() -> List[Dict[str, Any]]:
    replays = []
    replay_dir = _replays_dir()
    if not os.path.isdir(replay_dir):
        return replays
    meta = _load_meta_json()
    for fn in os.listdir(replay_dir):
        if not fn.endswith('.rpl'):
            continue
        fp = os.path.join(replay_dir, fn)
        try:
            md = _read_metadata_fast(fp)
            if md:
                file_meta = meta.get(fn, {})
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
                    'custom_name': file_meta.get('custom_name', ''),
                    'locked': file_meta.get('locked', False),
                })
        except Exception:
            pass
    replays.sort(key=lambda x: x['created_at'], reverse=True)
    return replays


def _read_metadata_fast(filepath: str) -> Optional[Dict]:
    try:
        file_size = os.path.getsize(filepath)
        if file_size < 16:
            return None
        with open(filepath, 'rb') as f:
            magic = f.read(4)
            if magic != _MAGIC:
                return None
            meta_len = struct.unpack('I', f.read(4))[0]
            if meta_len == 0 or meta_len > file_size:
                return None
            f.seek(file_size - meta_len)
            meta_bytes = f.read(meta_len)
            return pickle.loads(meta_bytes)
    except Exception:
        return None


def delete_replay(filepath: str) -> bool:
    try:
        fn = os.path.basename(filepath)
        os.remove(filepath)
        # 메타 정보도 제거
        meta = _load_meta_json()
        if fn in meta:
            del meta[fn]
            _save_meta_json(meta)
        return True
    except Exception:
        return False


def _cleanup_old_replays():
    """MAX_REPLAYS 초과 시 가장 오래된 잠금 안 된 리플레이 자동 삭제"""
    replay_dir = _replays_dir()
    if not os.path.isdir(replay_dir):
        return
    meta = _load_meta_json()
    # 잠금 안 된 파일만 삭제 대상
    unlocked_files = []
    total_count = 0
    for fn in os.listdir(replay_dir):
        if fn.endswith('.rpl'):
            total_count += 1
            if not meta.get(fn, {}).get('locked', False):
                fp = os.path.join(replay_dir, fn)
                unlocked_files.append((fp, fn, os.path.getmtime(fp)))
    if total_count <= MAX_REPLAYS:
        return
    # 오래된 순으로 정렬
    unlocked_files.sort(key=lambda x: x[2])
    to_delete = total_count - MAX_REPLAYS
    deleted = 0
    for fp, fn, _ in unlocked_files:
        if deleted >= to_delete:
            break
        try:
            os.remove(fp)
            # 메타 정보도 제거
            if fn in meta:
                del meta[fn]
            print(f"[Replay] 오래된 리플레이 삭제: {fn}")
            deleted += 1
        except Exception:
            pass
    if deleted > 0:
        _save_meta_json(meta)


# ============================================================================
# 싱글톤 레코더
# ============================================================================
_recorder: Optional[ReplayRecorder] = None


def get_recorder() -> ReplayRecorder:
    global _recorder
    if _recorder is None:
        _recorder = ReplayRecorder()
    return _recorder
