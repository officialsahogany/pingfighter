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
    # PyInstaller 빌드에서는 _MEIPASS가 임시 폴더이므로 사용자 데이터 경로 사용
    if getattr(sys, 'frozen', False):
        # 패키징 빌드: 실행 파일이 있는 디렉토리에 replays 폴더 생성
        base = os.path.dirname(sys.executable)
    else:
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
        self.sound_events: Dict[int, List[Any]] = {}

        # 백그라운드 압축 스레드
        self._queue: deque = deque(maxlen=300)  # ~5초 버퍼, 초과 시 오래된 프레임 드롭
        self._thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()
        self._lock = threading.Lock()

    def start(self, stage: int = 1, boss_name: str = "",
              ai_mode: str = "normal", character: str = "smasher",
              result: str = "", screen_w: int = 760, screen_h: int = 750,
              capture_mode: str = "screen"):
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
            'capture_mode': capture_mode,
        }

        replay_dir = _replays_dir()
        os.makedirs(replay_dir, exist_ok=True)
        self.filepath = os.path.join(replay_dir, f"_recording_{int(self.start_time)}.tmp")
        try:
            self.file = open(self.filepath, 'wb')
            self.file.write(_MAGIC)
            self.file.write(struct.pack('I', 0))

            # 백그라운드 스레드 시작 (큐/이벤트/락/파일을 클로저로 바인딩)
            self._queue.clear()
            self._stop_event.clear()
            _q = self._queue
            _se = self._stop_event
            _lk = self._lock
            _f_ref = [self.file]  # list로 감싸서 mutable 참조

            def _writer(queue=_q, stop_event=_se, lock=_lk, file_ref=_f_ref):
                while not stop_event.is_set() or len(queue) > 0:
                    if len(queue) > 0:
                        raw = queue.popleft()
                        try:
                            compressed = zlib.compress(raw, COMPRESS_LEVEL)
                            with lock:
                                fh = file_ref[0]
                                if fh and not fh.closed:
                                    fh.write(struct.pack('I', len(compressed)))
                                    fh.write(compressed)
                        except Exception:
                            pass
                    else:
                        time.sleep(0.005)

            self._thread = threading.Thread(target=_writer, daemon=True)
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

    def add_sound(self, sound_id: str, volume: float | None = None):
        """사운드 이벤트 기록 — 현재 캡처 프레임에 사운드 ID 추가"""
        if not self.recording:
            return
        frame = self.captured_frames
        if frame not in self.sound_events:
            self.sound_events[frame] = []
        if volume is None:
            self.sound_events[frame].append(sound_id)
            return
        try:
            self.sound_events[frame].append({'id': sound_id, 'volume': float(volume)})
        except Exception:
            self.sound_events[frame].append({'id': sound_id})

    # _writer_loop은 start() 내 클로저로 대체됨

    def stop(self, result: str = "") -> bool:
        if not self.recording:
            return False
        self.recording = False

        self.metadata['duration'] = time.time() - self.start_time
        self.metadata['total_frames'] = self.captured_frames
        self.metadata['sound_events'] = self.sound_events
        if result:
            self.metadata['result'] = result

        remaining = len(self._queue)
        print(f"[Replay] 녹화 중지 — {self.captured_frames}프레임, {self.metadata['duration']:.1f}초, 큐 잔여: {remaining}")

        if self.captured_frames == 0 or self.file is None:
            print(f"[Replay] 프레임이 0개라 저장 건너뜀")
            self._stop_event.set()
            self._cleanup_temp()
            return False

        # 현재 상태를 로컬로 캡처 (다음 start()가 덮어쓰기 전에)
        _save_file = self.file
        _save_filepath = self.filepath
        _save_metadata = dict(self.metadata)
        _save_queue = self._queue
        _save_stop_event = self._stop_event
        _save_thread = self._thread
        _save_lock = self._lock

        # 싱글톤 필드 초기화 (다음 start()가 안전하게 새 파일을 열 수 있도록)
        self.file = None
        self.filepath = None
        self._queue = deque()
        self._stop_event = threading.Event()
        self._thread = None
        self._lock = threading.Lock()

        # 백그라운드에서 저장 완료
        def _finish():
            _save_stop_event.set()
            if _save_thread and _save_thread.is_alive():
                _save_thread.join(timeout=30)
            self._finalize_file(_save_file, _save_filepath, _save_metadata)

        threading.Thread(target=_finish, daemon=True).start()
        return True

    @staticmethod
    def _finalize_file(file_handle, filepath, metadata) -> bool:
        """파일 핸들과 메타데이터를 받아 파일 완성 (싱글톤 상태 건드리지 않음)"""
        try:
            meta_bytes = pickle.dumps(metadata, protocol=pickle.HIGHEST_PROTOCOL)
            file_handle.write(struct.pack('I', len(meta_bytes)))
            file_handle.write(meta_bytes)
            file_handle.seek(len(_MAGIC))
            file_handle.write(struct.pack('I', len(meta_bytes)))
            file_handle.close()

            replay_dir = _replays_dir()
            ts_str = time.strftime("%Y%m%d_%H%M%S")
            stage = metadata.get('stage', 0)
            final_name = f"replay_s{stage}_{ts_str}.rpl"
            final_path = os.path.join(replay_dir, final_name)
            os.rename(filepath, final_path)

            total_frames = metadata.get('total_frames', 0)
            size_mb = os.path.getsize(final_path) / (1024 * 1024)
            print(f"[Replay] 저장 완료: {final_name} ({total_frames}프레임, {size_mb:.1f}MB)")
            _cleanup_old_replays()
            return True
        except Exception as e:
            print(f"[Replay] 저장 실패: {e}")
            import traceback; traceback.print_exc()
            # 임시 파일 정리
            try:
                if filepath and os.path.exists(filepath):
                    os.remove(filepath)
            except Exception:
                pass
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
# 플레이어 — .rpl 파일에서 프레임을 스트리밍 재생 (메모리 절약)
# ============================================================================
class ReplayPlayer:
    """프레임 위치만 인덱싱하고, 재생 시 디스크에서 1프레임씩 읽어 디코딩"""

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
        self._current_surface = None
        # 스트리밍용
        self._filepath = ""
        self._frame_index: List[tuple] = []  # [(file_offset, chunk_size), ...]
        self._file = None  # 열린 파일 핸들

    def load(self, filepath: str) -> bool:
        """파일을 스캔하여 프레임 위치만 인덱싱 (메모리에 데이터 안 올림)"""
        self.close()
        try:
            f = open(filepath, 'rb')
            magic = f.read(4)
            if magic != _MAGIC:
                print(f"[Replay] 잘못된 파일 형식")
                f.close()
                return False

            f.read(4)  # meta_len (헤더)

            # 프레임 위치 인덱싱
            self._frame_index = []
            while True:
                size_bytes = f.read(4)
                if len(size_bytes) < 4:
                    break
                chunk_size = struct.unpack('I', size_bytes)[0]
                data_offset = f.tell()
                f.seek(data_offset + chunk_size)

                # 다음 청크가 있는지 확인
                next_b = f.read(4)
                if len(next_b) < 4:
                    # 마지막 청크 = 메타데이터
                    f.seek(data_offset)
                    meta_bytes = f.read(chunk_size)
                    self.metadata = pickle.loads(meta_bytes)
                    break
                else:
                    f.seek(data_offset + chunk_size)  # 되돌리기
                    self._frame_index.append((data_offset, chunk_size))

            self.total_frames = len(self._frame_index)
            self.scaled_w = self.metadata.get('scaled_w', 380)
            self.scaled_h = self.metadata.get('scaled_h', 375)
            self.current_index = 0
            self.frame_accum = 0.0
            self._filepath = filepath
            self._file = f  # 파일 핸들 유지

            size_mb = os.path.getsize(filepath) / (1024 * 1024)
            print(f"[Replay] 로드 (스트리밍): {self.total_frames}프레임, {self.scaled_w}x{self.scaled_h}, {size_mb:.1f}MB")
            return self.total_frames > 0
        except Exception as e:
            print(f"[Replay] 로드 실패: {e}")
            import traceback; traceback.print_exc()
            return False

    def close(self):
        """파일 핸들 정리"""
        if self._file:
            try:
                self._file.close()
            except Exception:
                pass
            self._file = None
        self._frame_index = []
        self.total_frames = 0

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

    def get_frame_surface(self):
        """현재 인덱스의 프레임을 디스크에서 읽어 Surface로 디코딩"""
        if self.current_index < 0 or self.current_index >= self.total_frames:
            return self._current_surface
        if not self._file:
            print(f"[Replay] 파일 핸들 없음!")
            return self._current_surface
        try:
            offset, size = self._frame_index[self.current_index]
            self._file.seek(offset)
            compressed = self._file.read(size)
            raw = zlib.decompress(compressed)
            surf = pygame.image.fromstring(raw, (self.scaled_w, self.scaled_h), 'RGB')
            self._current_surface = surf
            return surf
        except Exception as e:
            if self.current_index < 3:
                print(f"[Replay] 프레임 {self.current_index} 디코딩 실패: {e}")
            return self._current_surface

    def advance(self):
        """매 프레임(60fps) 호출 — 캡처 fps에 맞춰 정속 재생.
        Returns (surface, (start_idx, end_idx)) — 이번 호출에서 소비한 프레임 범위.
        사운드 재생 시 start_idx <= i < end_idx 범위의 이벤트를 모두 처리해야 함.
        """
        if not self.playing and not self.paused:
            return None, (-1, -1)
        if self.paused:
            return self.get_frame_surface(), (-1, -1)
        if not self.playing:
            return None, (-1, -1)

        capture_fps = self.metadata.get('capture_fps', 30)
        step = self.speed * (capture_fps / 60.0)

        self.frame_accum += step
        surf = None
        start_idx = self.current_index
        while self.frame_accum >= 1.0:
            self.frame_accum -= 1.0
            if self.current_index < self.total_frames:
                surf = self.get_frame_surface()
                self.current_index += 1
            else:
                self.stop()
                break
        end_idx = self.current_index
        return surf, (start_idx, end_idx)

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
        return self._frame_index

    def __del__(self):
        self.close()


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
    """MAX_REPLAYS 초과 시 가장 오래된 잠금 안 된 리플레이 자동 삭제 + 고아 파일 정리"""
    replay_dir = _replays_dir()
    if not os.path.isdir(replay_dir):
        return
    meta = _load_meta_json()

    # 1) 고아 .tmp 파일 정리 (10분 이상 된 녹화 임시 파일 = 비정상 종료 잔여물)
    _ORPHAN_AGE = 600  # 10분
    now = time.time()
    for fn in os.listdir(replay_dir):
        if fn.startswith('_recording_') and fn.endswith('.tmp'):
            fp = os.path.join(replay_dir, fn)
            try:
                if now - os.path.getmtime(fp) > _ORPHAN_AGE:
                    os.remove(fp)
                    print(f"[Replay] 고아 임시파일 삭제: {fn}")
            except Exception:
                pass

    # 2) .rpl 이외의 잔여 리플레이 파일 정리 (.rpg, .mp4 등 이전 포맷)
    _KEEP_EXTS = {'.rpl', '.tmp', '.json', '.mp4'}
    for fn in os.listdir(replay_dir):
        _, ext = os.path.splitext(fn)
        if ext and ext not in _KEEP_EXTS:
            fp = os.path.join(replay_dir, fn)
            try:
                os.remove(fp)
                print(f"[Replay] 잔여 파일 삭제: {fn}")
            except Exception:
                pass

    # 3) .rpl 파일 개수 제한 (MAX_REPLAYS 초과 시 오래된 것 삭제)
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
